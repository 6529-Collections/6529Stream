import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { Interface, ZeroHash, id, keccak256, toBeHex, toUtf8Bytes, zeroPadValue } from "ethers";
import {
  CURRENT_ARTIST_CEREMONY_TOOL,
  assertCurrentArtistConsentCurrent,
  captureCurrentArtistCeremony,
  inspectCurrentArtistCeremony,
  prepareCurrentArtistCeremonySubmission,
  recomputeCurrentArtistCeremony,
} from "../dist/current-artist-ceremony.js";
import { walletTypedData } from "../dist/signing.js";
import { artistCeremonyFixture } from "../scripts/generate-current-artist-ceremony-fixture.mjs";

const operationFixture = JSON.parse(await readFile(new URL("./fixtures/current-artist-operation-abi.json", import.meta.url), "utf8"));
const ceremonyFixture = JSON.parse(await readFile(new URL("./fixtures/current-artist-ceremony-abi.json", import.meta.url), "utf8"));
const operations = new Interface(operationFixture.abi), replay = new Interface(ceremonyFixture.abi);
const registry = "0x0000000000000000000000000000000000000011";
const signer = "0x0000000000000000000000000000000000000022";
const chainId = 31337n, artistId = id("artistId"), document = "0x1234", statement = "0x5678", statementURI = "urn:stream:test:statement";
const types = {
  artistAcceptance: "StreamArtistAcceptance", artistPolicyConsent: "StreamArtistPolicyConsent",
  artistEconomicsConsent: "StreamArtistEconomicsConsent", artistPayoutDesignation: "StreamArtistPayoutDesignation",
  artistAttestation: "StreamArtistAttestation", artistContentRatification: "StreamArtistContentRatification",
  collaboratorIdentityAcceptance: "StreamCollaboratorIdentityAcceptance", collaboratorAcceptance: "StreamCollaboratorAcceptance",
};
const declarations = {
  artistAcceptance: "address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 identityRecordHash,uint256 nonce,uint64 deadline",
  artistPolicyConsent: "address core,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 policyHash,uint256 nonce,uint64 deadline",
  artistEconomicsConsent: "address core,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash,uint256 nonce,uint64 deadline",
  artistPayoutDesignation: "bytes32 artistId,address payoutAccount,bytes32 previousDesignationRecordHash,uint256 nonce,uint64 signedAt",
  artistAttestation: "address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt",
  artistContentRatification: "address core,address metadataContract,uint256 collectionId,bytes32 contentStateHash,uint256 nonce,uint64 deadline",
  collaboratorIdentityAcceptance: "address account,bytes32 identityRecordHash,uint256 nonce,uint64 deadline",
  collaboratorAcceptance: "address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,address collaborator,bytes32 role,bytes32 shareLabelId,uint256 nonce,uint64 deadline",
};
const commitmentFields = {
  artistAcceptance: ["bindingHash", "identityRecordHash"], artistPolicyConsent: ["policyHash"],
  artistEconomicsConsent: ["assignmentHash"], artistPayoutDesignation: ["previousDesignationRecordHash"],
  artistAttestation: ["subjectStateHash", "statementHash", "statementURIHash"], artistContentRatification: ["contentStateHash"],
  collaboratorIdentityAcceptance: ["identityRecordHash"], collaboratorAcceptance: ["bindingHash"],
};
function fields(kind) { return declarations[kind].split(",").map(value => { const [type, name] = value.split(" "); return { type, name }; }); }
function message(kind, time = 1_100n) {
  return Object.fromEntries(fields(kind).map(({ name, type }) => [name,
    type === "address" ? signer : name === "identityRecordHash" ? keccak256(document)
      : name === "statementHash" ? keccak256(statement) : name === "statementURIHash" ? keccak256(toUtf8Bytes(statementURI))
      : name === "previousDesignationRecordHash" ? ZeroHash : type === "bytes32" ? id(name)
        : name === "deadline" ? time : name === "signedAt" ? time - 101n : type === "uint8" ? 1n : 9007199254740993n]));
}
function details(kind) {
  return { ...(kind === "artistEconomicsConsent" ? { collectionId: 1n } : {}),
    ...(kind === "artistAttestation" ? { statementURI, statement } : {}),
    ...(kind === "collaboratorIdentityAcceptance" ? { document, displayName: "Collaborator" } : {}) };
}
function facts(kind, m) {
  return fields(kind).map(({ name, type }) => ({ field: name, label: `Reviewed ${name}`, meaning: `Resolved ${name} for ${kind}`,
    source: `public fixture ${kind}.${name}`,
    ...(type === "bytes32" && commitmentFields[kind].includes(name) && m[name] !== ZeroHash ? { preimage: name === "identityRecordHash" ? { encoding: "hex", value: document }
      : name === "statementHash" ? { encoding: "hex", value: statement }
        : name === "statementURIHash" ? { encoding: "utf8", value: statementURI } : { encoding: "utf8", value: name } }
      : type === "bytes32" && !commitmentFields[kind].includes(name) ? { representation: `Protocol identifier ${name}` } : {}) }));
}
function capture(kind, options = {}) {
  const m = options.message ?? message(kind);
  return captureCurrentArtistCeremony(kind, chainId, registry, m, details(kind), {
    signer, walletClass: options.walletClass ?? "eoa", executionMode: options.executionMode ?? "relayed",
    authority: kind === "collaboratorIdentityAcceptance" ? { kind: "collaborator-registration", account: signer } : { kind: "artist", artistId: options.authorityArtistId ?? artistId },
    facts: options.facts ?? facts(kind, m),
  });
}
class RPC {
  chainId = chainId; number = 100; timestamp = 1_000; reorg = false; malformed = false;
  state = { digestObserved: false, digestRevoked: false, nonceConsumed: false, nonceRevoked: false, nextUnusedNonce: 9007199254740993n };
  calls = []; digest;
  async getNetwork() { return { chainId: this.chainId }; }
  async getBlock() { return { number: this.number, timestamp: this.timestamp, hash: id(this.reorg && this.calls.length ? "changed block" : "block") }; }
  async call(tx) {
    this.calls.push(tx);
    const parsed = replay.parseTransaction(tx) ?? operations.parseTransaction(tx);
    assert(parsed, "known current Artist read");
    let raw;
    if (parsed.name === "artistAuthorizationState") raw = replay.encodeFunctionResult(parsed.name, [this.state]);
    else if (parsed.name === "collaboratorRegistrationNonceState") raw = replay.encodeFunctionResult(parsed.name, [this.state.nonceConsumed, this.state.nextUnusedNonce]);
    else raw = operations.encodeFunctionResult(parsed.name, [this.digest]);
    return this.malformed && parsed.name.includes("AuthorizationState") ? raw + "00".repeat(32) : raw;
  }
}

test("selected replay reads retain reviewed compiler provenance and exact current ABI selectors", () => {
  assert.equal(ceremonyFixture.sourceCommit, "0d7c1b57");
  assert.deepEqual(ceremonyFixture.provenance, {
    sourceSha256: "d662c96043e4fd1809bba76da045e05ce8df921b2e8c6dc2fe05b05ed22fe994",
    compilerInputSha256: "6b5a36b391f91187447d38e77939ca882df43ccb978924b8d69e7c2a5abb8012",
    compilerOutputSha256: "0719df2601b45dbb79e65d41d0b378a7e858677390062ab4307a2441cc97a9eb",
  });
  assert.deepEqual(ceremonyFixture.abi.map(item => item.name), ["artistAuthorizationState", "collaboratorRegistrationNonceState"]);
  assert.equal(replay.getFunction("artistAuthorizationState").selector, "0xee6d7475");
  assert.equal(replay.getFunction("collaboratorRegistrationNonceState").selector, "0xe3d4143b");
  const encoded = replay.encodeFunctionResult("artistAuthorizationState", [{ digestObserved: true, digestRevoked: false, nonceConsumed: true, nonceRevoked: false, nextUnusedNonce: 2n ** 200n }]);
  assert.equal(replay.decodeFunctionResult("artistAuthorizationState", encoded)[0].nextUnusedNonce, 2n ** 200n);
});

test("fixture extraction is compiler-selected and rejects incomplete or failed artifacts", () => {
  const source = ceremonyFixture.source, input = JSON.stringify({ language: "Solidity", sources: { [source]: { content: "source bytes\n" } } });
  const output = JSON.stringify({ contracts: { [source]: { StreamArtistOnboardingRegistry: { abi: ceremonyFixture.abi } } } });
  const selected = artistCeremonyFixture(input, output, "0d7c1b57");
  assert.deepEqual(selected.abi, ceremonyFixture.abi);
  assert.throws(() => artistCeremonyFixture(input, JSON.stringify({ errors: [{ severity: "error" }] }), "0d7c1b57"), /successful/);
  assert.throws(() => artistCeremonyFixture(input, JSON.stringify({ contracts: { [source]: { StreamArtistOnboardingRegistry: { abi: ceremonyFixture.abi.slice(1) } } } }), "0d7c1b57"), /Incomplete/);
  assert.throws(() => artistCeremonyFixture(input, output, "NOT-A-COMMIT"), /source commit/);
});

test("all eight supported families capture named facts, independently recompute hashes and attach exact relayed bytes", () => {
  assert.deepEqual(CURRENT_ARTIST_CEREMONY_TOOL.supportedWalletClasses, ["eoa", "safe-erc1271"]);
  for (const kind of Object.keys(types)) {
    const ceremony = capture(kind);
    assert.equal(ceremony.tool.name, "6529 Stream Artist Ceremony"); assert.equal(ceremony.payload.primaryType, types[kind]);
    assert.equal(ceremony.facts.length, fields(kind).length); assert.equal(recomputeCurrentArtistCeremony(ceremony), ceremony.payload.digest);
    assert(ceremony.facts.every(fact => fact.label && fact.meaning && fact.source));
    assert(ceremony.facts.filter(fact => commitmentFields[kind].includes(fact.field) && fact.signedValue !== ZeroHash).every(fact => fact.recomputedValue === fact.signedValue));
    assert(ceremony.facts.filter(fact => fact.solidityType === "bytes32" && !commitmentFields[kind].includes(fact.field)).every(fact => fact.representation));
    const prepared = prepareCurrentArtistCeremonySubmission(ceremony, "0x1234");
    assert.equal(operations.parseTransaction(prepared.call).name, prepared.method);
    assert.equal(prepared.payload.digest, ceremony.payload.digest);
    assert.throws(() => prepareCurrentArtistCeremonySubmission(ceremony, "0x"), /execution mode/);
  }
});

test("fact capture rejects omissions, duplicates, bare commitments, incorrect preimages and raw-hash meanings", () => {
  const kind = "artistPolicyConsent", m = message(kind), complete = facts(kind, m);
  assert.throws(() => capture(kind, { message: m, facts: complete.slice(1) }), /cover every/);
  assert.throws(() => capture(kind, { message: m, facts: [...complete.slice(1), complete[1]] }), /cover every/);
  assert.throws(() => capture(kind, { message: m, facts: complete.map(f => f.field === "policyHash" ? { ...f, preimage: undefined } : f) }), /requires/);
  assert.throws(() => capture(kind, { message: m, facts: complete.map(f => f.field === "policyHash" ? { ...f, preimage: { encoding: "utf8", value: "changed" } } : f) }), /differs/);
  assert.throws(() => capture(kind, { message: m, facts: complete.map(f => f.field === "policyHash" ? { ...f, meaning: m.policyHash } : f) }), /must resolve/);
  assert.throws(() => captureCurrentArtistCeremony(kind, chainId, registry, m, { unexpected: true }, {
    signer, walletClass: "eoa", executionMode: "relayed", authority: { kind: "artist", artistId }, facts: complete,
  }), /operation details/);
});

test("raw bytes32 identifiers are disclosed without inventing keccak preimages", () => {
  const policyMessage = { ...message("artistPolicyConsent"), phaseId: zeroPadValue(toBeHex(123n), 32) };
  const policy = capture("artistPolicyConsent", { message: policyMessage });
  assert.equal(policy.facts.find(f => f.field === "phaseId").representation, "Protocol identifier phaseId");
  assert.equal(recomputeCurrentArtistCeremony(policy), policy.payload.digest);
  const attestationMessage = { ...message("artistAttestation"), subjectId: zeroPadValue(toBeHex(42n), 32) };
  const attestation = capture("artistAttestation", { message: attestationMessage });
  assert.equal(attestation.facts.find(f => f.field === "subjectId").signedValue, zeroPadValue(toBeHex(42n), 32));
  assert.equal(recomputeCurrentArtistCeremony(attestation), attestation.payload.digest);
  const invalid = facts("artistPolicyConsent", policyMessage).map(f => f.field === "phaseId" ? { ...f, representation: undefined, preimage: { encoding: "utf8", value: "phaseId" } } : f);
  assert.throws(() => capture("artistPolicyConsent", { message: policyMessage, facts: invalid }), /raw identifier/);
});

test("recomputation rejects substituted authority context, details, and unsigned operation bytes", () => {
  const ceremony = capture("artistPolicyConsent");
  assert.throws(() => recomputeCurrentArtistCeremony({ ...ceremony, authority: { kind: "artist", artistId: id("other artist") } }), /reviewed context/);
  assert.throws(() => recomputeCurrentArtistCeremony({ ...ceremony, details: { unexpected: true } }), /operation details/);
  assert.throws(() => recomputeCurrentArtistCeremony({ ...ceremony, unsignedOperation: { ...ceremony.unsignedOperation,
    digestCall: { ...ceremony.unsignedOperation.digestCall, data: "0x1234" } } }), /operation differs/);
});

test("pinned freshness checks the facade digest and each distinct replay lane without making a write call", async () => {
  for (const kind of Object.keys(types)) {
    const ceremony = capture(kind), rpc = new RPC(); rpc.digest = ceremony.payload.digest;
    const observed = await inspectCurrentArtistCeremony(rpc, ceremony);
    assert.equal(observed.authorization.nextUnusedNonce, 9007199254740993n);
    const names = rpc.calls.map(tx => (replay.parseTransaction(tx) ?? operations.parseTransaction(tx)).name);
    assert(names.includes(ceremony.unsignedOperation.digestMethod));
    assert(names.includes(kind === "collaboratorIdentityAcceptance" ? "collaboratorRegistrationNonceState" : "artistAuthorizationState"));
    assert(!names.includes(ceremony.unsignedOperation.method));
  }
});

test("collaborator acceptance checks the collaborator identity nonce lane supplied by the caller", async () => {
  const collaboratorArtistId = id("collaborator artist identity"), ceremony = capture("collaboratorAcceptance", { authorityArtistId: collaboratorArtistId }), rpc = new RPC();
  rpc.digest = ceremony.payload.digest;
  await inspectCurrentArtistCeremony(rpc, ceremony);
  const stateCall = rpc.calls.map(tx => replay.parseTransaction(tx)).find(parsed => parsed?.name === "artistAuthorizationState");
  assert.equal(stateCall.args.artistId, collaboratorArtistId);
  assert.notEqual(stateCall.args.artistId, id("collection artist identity"));
});

test("wrong domain, stale/revoked authorization, expiry, dated-record timing and direct allocator drift fail closed", async () => {
  const policy = capture("artistPolicyConsent"), rpc = new RPC(); rpc.digest = policy.payload.digest;
  rpc.chainId = 1n; await assert.rejects(inspectCurrentArtistCeremony(rpc, policy), /chain/); rpc.chainId = chainId;
  for (const key of ["digestObserved", "digestRevoked", "nonceConsumed", "nonceRevoked"]) {
    const stale = new RPC(); stale.digest = policy.payload.digest; stale.state[key] = true;
    await assert.rejects(inspectCurrentArtistCeremony(stale, policy), /used or revoked/);
  }
  const wrongDigest = new RPC(); wrongDigest.digest = id("foreign domain");
  await assert.rejects(inspectCurrentArtistCeremony(wrongDigest, policy), /differs/);
  const reorg = new RPC(); reorg.digest = policy.payload.digest; reorg.reorg = true;
  await assert.rejects(inspectCurrentArtistCeremony(reorg, policy), /block changed/);
  const expired = capture("artistPolicyConsent", { message: message("artistPolicyConsent", 999n) }), expiredRpc = new RPC(); expiredRpc.digest = expired.payload.digest;
  await assert.rejects(inspectCurrentArtistCeremony(expiredRpc, expired), /expired/);
  const dated = capture("artistPayoutDesignation", { message: message("artistPayoutDesignation", 1_102n) }), datedRpc = new RPC(); datedRpc.digest = dated.payload.digest;
  await assert.rejects(inspectCurrentArtistCeremony(datedRpc, dated), /signedAt/);
  const direct = capture("artistPolicyConsent", { executionMode: "direct" }), directRpc = new RPC(); directRpc.digest = direct.payload.digest; directRpc.state.nextUnusedNonce++;
  await assert.rejects(inspectCurrentArtistCeremony(directRpc, direct), /allocator hint/);
  assert.doesNotThrow(() => prepareCurrentArtistCeremonySubmission(direct, "0x"));
});

test("direct dated operations preserve the zero execution-time sentinel without claiming the future digest", async () => {
  for (const kind of ["artistPayoutDesignation", "artistAttestation"]) {
    const m = { ...message(kind), signedAt: 0n }, ceremony = capture(kind, { message: m, executionMode: "direct" }), rpc = new RPC();
    rpc.digest = ceremony.payload.digest;
    const observed = await inspectCurrentArtistCeremony(rpc, ceremony);
    assert.equal(observed.digestSemantics, "execution-time-sentinel");
    assert.equal(ceremony.payload.message.signedAt, 0n);
    assert.equal(operations.parseTransaction(prepareCurrentArtistCeremonySubmission(ceremony, "0x").call).args[1].time, 0n);
    rpc.state.digestObserved = true; rpc.state.digestRevoked = true;
    assert.equal((await inspectCurrentArtistCeremony(rpc, ceremony)).digestSemantics, "execution-time-sentinel", "submitted zero-time digest is not the execution-time digest");
  }
  assert.throws(() => capture("artistPayoutDesignation", { executionMode: "direct" }), /zero execution-time sentinel/);
  assert.throws(() => capture("artistAttestation", { message: { ...message("artistAttestation"), signedAt: 0n } }), /explicit signedAt/);
});

test("policy and economics churn requires a newly presented ceremony", () => {
  const policy = capture("artistPolicyConsent"), economics = capture("artistEconomicsConsent");
  assert.doesNotThrow(() => assertCurrentArtistConsentCurrent(policy, policy.payload.message.policyHash));
  assert.throws(() => assertCurrentArtistConsentCurrent(policy, id("changed policy")), /discard the stale ceremony/);
  assert.doesNotThrow(() => assertCurrentArtistConsentCurrent(economics, economics.payload.message.assignmentHash));
  assert.throws(() => assertCurrentArtistConsentCurrent(economics, id("changed assignment")), /discard the stale ceremony/);
  assert.throws(() => assertCurrentArtistConsentCurrent(capture("artistAcceptance"), id("unused")), /not a policy/);
});

test("example returns a wallet payload plus read-only observation and preserves reviewed signature attachment", async () => {
  const { reviewCurrentArtistCeremony, attachReviewedArtistSignature } = await import("../examples/current-artist-ceremony.mjs");
  const kind = "artistPolicyConsent", m = message(kind), request = { kind, chainId: chainId.toString(), registry, message: m, details: details(kind),
    context: { signer, walletClass: "eoa", executionMode: "relayed", authority: { kind: "artist", artistId }, facts: facts(kind, m) } };
  const expected = capture(kind), rpc = new RPC(); rpc.digest = expected.payload.digest;
  const reviewed = await reviewCurrentArtistCeremony(rpc, request);
  assert.equal(reviewed.walletPayload.primaryType, types[kind]);
  assert.equal(reviewed.walletPayload.message.nonce, m.nonce.toString());
  const attached = attachReviewedArtistSignature(reviewed.ceremony, "0x1234");
  assert.equal(attached.payload.digest, reviewed.ceremony.payload.digest);
  assert.deepEqual(walletTypedData(reviewed.ceremony.payload), reviewed.walletPayload);
});
