import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as client from "../dist/current-entropy-instant.js";
import * as earlier from "../dist/current-entropy-collection-policy.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-entropy-instant-abi.json", import.meta.url), "utf8"));
const original = JSON.parse(readFileSync(new URL("./fixtures/current-entropy-collection-policy-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([k, v]) => [k, new Interface(v)]));
const coder = AbiCoder.defaultAbiCoder(), hash = (types, values) => keccak256(coder.encode(types, values));
const address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const source = name => fixture.sourceTexts[`smart-contracts/domains/entropy/${name}.sol`];
const inputType = abi.policy.getFunction("configureCollectionEntropyPolicy").inputs[1];
const recordType = abi.policy.getFunction("collectionEntropyPolicy").outputs[0];
const configType = ParamType.from({ type: "tuple", components: abi.entropy.getFunction("collectionEntropyConfig").outputs });
const revealType = abi.entropy.getFunction("collectionRevealPolicy").outputs[0];
const content = (policyHash, frozen) => hash(["bytes32", "bytes32", "bool"], [id("6529STREAM_ENTROPY_CONFIGURATION_V1"), policyHash, frozen]);

function sample() {
  const snapshot = { chainId: (1n << 230n) + 1n, coordinator: address(10), core: address(20), governanceExecutor: address(30), collectionId: (1n << 250n) + 3n,
    config: { provider: ZeroAddress, publicRequests: false, locked: false, timeoutBlocks: 0n, providerConfigHash: ZeroHash, providerCodeHash: ZeroHash, collectionSalt: ZeroHash },
    providerEpoch: 0n, reveal: { declared: false, requestMode: 0n, revealOwnerRole: ZeroHash, requestSLOBlocks: 0n, revealFeePerTokenWei: 0n },
    recovery: { policyId: ZeroHash, policyHash: ZeroHash, maxFreshRecoveryAttempts: 0n, revision: 0n, lastActionId: ZeroHash },
    entry: { revision: 0n, mode: 0n, securityClass: 0n, renderRequirement: 0n, policyHash: ZeroHash, lastActionId: ZeroHash, artistConsentRecord: ZeroHash },
    collectionExists: true, collectionFrozen: false, collectionMintedEver: 0n, revealEscrow: 0n };
  const input = { mode: 1n, securityClass: 1n, renderRequirement: 0n, provider: address(40), collectionSalt: id("instant salt"), publicRequests: true, timeoutBlocks: 0n,
    reveal: structuredClone(snapshot.reveal), maxFreshRecoveryAttempts: 0n, recoveryPolicyId: ZeroHash };
  const resolution = { providerCodeHash: id("instant runtime"), providerConfigHash: id("instant configuration"), recoveryPolicyHash: ZeroHash, instantMode: 1n, assumptionsHash: id("declared delayed assumptions") };
  return { snapshot, input, resolution };
}
function semantic(c, s) {
  const { config: p, reveal: r, recovery: b, entry: e } = s;
  return hash(["bytes32", "uint256", "address", "address", "uint256", "uint8", "uint8", "uint8", "address", "bytes32", "bytes32", "uint32", "bytes32", "bool", "uint64", "bool", "uint8", "bytes32", "uint64", "bytes32", "bytes32", "uint16"],
    [id("6529STREAM_ENTROPY_COLLECTION_POLICY_V2"), c.chainId, c.coordinator, c.core, c.collectionId, e.mode, e.securityClass, e.renderRequirement, p.provider, p.providerCodeHash, p.providerConfigHash, s.providerEpoch, p.collectionSalt, p.publicRequests, p.timeoutBlocks,
      r.declared, r.requestMode, r.revealOwnerRole, r.requestSLOBlocks, b.policyId, b.policyHash, b.maxFreshRecoveryAttempts]);
}
function scope(c, kind) {
  return hash(["bytes32", "uint256", "address", "address", "uint256", "bytes4"], [id("6529STREAM_ENTROPY_COLLECTION_POLICY_SCOPE_V1"), c.chainId, c.coordinator, c.core, c.collectionId,
    abi.policy.getFunction(kind === "configure" ? "configureCollectionEntropyPolicy" : "freezeCollectionEntropyPolicy").selector]);
}
function stateHash(key, s) {
  const { recovery: r, entry: e } = s;
  return hash(["bytes32", "bytes32", configType, "uint32", revealType, "bytes32", "bytes32", "uint16", "uint64", "uint64", "uint8", "uint8", "uint8", "bytes32"],
    [id("6529STREAM_ENTROPY_COLLECTION_POLICY_STATE_V1"), key, s.config, s.providerEpoch, s.reveal, r.policyId, r.policyHash, r.maxFreshRecoveryAttempts, r.revision, e.revision, e.mode, e.securityClass, e.renderRequirement, e.policyHash]);
}
function independentNext(s, p, r) {
  const changedRecovery = s.recovery.policyId !== ZeroHash || s.recovery.policyHash !== ZeroHash || s.recovery.maxFreshRecoveryAttempts !== 0n;
  const changedProvider = s.config.provider !== p.provider || s.config.providerConfigHash !== r.providerConfigHash;
  const next = { config: { provider: p.provider, publicRequests: p.publicRequests, locked: false, timeoutBlocks: 0n, providerConfigHash: r.providerConfigHash, providerCodeHash: r.providerCodeHash, collectionSalt: p.collectionSalt },
    providerEpoch: s.providerEpoch + (changedProvider || changedRecovery ? 1n : 0n), reveal: structuredClone(p.reveal),
    recovery: { policyId: ZeroHash, policyHash: ZeroHash, maxFreshRecoveryAttempts: 0n, revision: s.recovery.revision + (changedRecovery ? 1n : 0n), lastActionId: s.recovery.lastActionId },
    entry: { ...s.entry, revision: s.entry.revision + 1n, mode: 1n, securityClass: 1n, renderRequirement: p.renderRequirement } };
  next.entry.policyHash = semantic(s, next); return next;
}

test("INSTANT fixture keeps exact independent capture, selected source and supplemental governance provenance", () => {
  assert.equal(fixture.sourceCommit, "b4bbd262a77d122d35065a6b7b8b9606323361e5"); assert.equal(fixture.sourceCount, 1044);
  assert.equal(fixture.inputSha256, "816f8c9049f617a15d50a36a3c2cb72ef2e9578877edc6131c261642df522e22");
  assert.equal(fixture.outputSha256, "29694f71f7fdfdc5338da4dd2bee485b14ffde62d70b3136d64d230ef080631e");
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 578); assert.equal(Object.keys(fixture.abis).length, 33);
  assert.equal(Object.keys(fixture.sourceHashes).length, 426); assert.equal(Object.keys(fixture.sourceTexts).length, 65);
  assert.equal(Object.keys(fixture.governanceWitness.sourceHashes).length, 35);
  for (const [path, text] of Object.entries(fixture.sourceTexts)) assert.equal(createHash("sha256").update(text).digest("hex"), fixture.sourceHashes[path]);
  for (const [path, expected] of Object.entries(fixture.governanceWitness.sourceHashes)) assert.equal(fixture.sourceHashes[path], expected);
  assert.equal(fixture.selections.executor.capture, "governance"); assert.equal(fixture.selections.instant.capture, "policy");
  assert.equal(original.sourceCommit, "d7fb42128cdef9dd9716d1f955ee3aba610f085b"); assert.equal(original.sourceCount, 1034);
  assert.deepEqual(fixture.abis.policy, original.abis.policy); // Interface compatibility does not imply identical mode admission.
});

test("compiler witnesses pin all three additive capabilities and exact sixteen-word direct read", () => {
  const interfaceId = (group, excluded = []) => {
    let value = 0n;
    abi[group].forEachFunction(f => { if (!excluded.includes(f.name)) value ^= BigInt(f.selector); });
    return `0x${value.toString(16).padStart(8, "0")}`;
  };
  assert.equal(interfaceId("instantProvider"), "0x5d42f023");
  assert.equal(interfaceId("instantIdentity", ["supportsInterface"]), "0xb8bedf9e");
  assert.equal(interfaceId("terminalFacts", ["supportsInterface"]), "0x40016975");
  const f = abi.terminalFacts.getFunction("staticTerminalEntropyFacts");
  assert.equal(f.selector, "0x40016975"); assert.equal(f.outputs.length, 5);
  assert.equal(f.outputs[1].format("sighash"), recordType.format("sighash")); assert.equal(recordType.components.length, 12);
  const s = source("StreamEntropyCoordinator");
  const getter = s.slice(s.indexOf("function staticTerminalEntropyFacts("), s.indexOf("function tokenEntropy(", s.indexOf("function staticTerminalEntropyFacts(")));
  assert.match(getter, /entry\.revision == 0/); assert.match(getter, /status = uint8\(subject\.status\)/);
  assert.doesNotMatch(getter, /require.*FINALIZED|status !=.*FINALIZED|_subjectRead\(|_auxiliaryRead\(/);
});

test("INSTANT policy preimages retain original hashes, exact fourth-word consent and independent recovery clearing", () => {
  const { snapshot: initial, input: p, resolution: r } = sample();
  for (const s of [initial, { ...initial, providerEpoch: 7n, recovery: { policyId: id("old recovery"), policyHash: id("old frozen hash"), maxFreshRecoveryAttempts: 2n, revision: 9n, lastActionId: id("old action") } }]) {
    const plan = client.prepareEntropyInstantPolicyConfigure(s, p, r), next = independentNext(s, p, r), key = scope(s, "configure");
    assert.deepEqual(plan.next, next);
    assert.deepEqual(plan.transition, { scopeHash: key, oldValueHash: stateHash(key, s), newValueHash: stateHash(key, next), artistContentStateHash: content(next.entry.policyHash, false) });
    assert.equal(plan.targetCall.data, abi.policy.encodeFunctionData("configureCollectionEntropyPolicy", [s.collectionId, p]));
    assert.equal(plan.previewCall.data, abi.policy.encodeFunctionData("collectionEntropyPolicyTransition", [s.collectionId, p]));
    assert.equal(plan.actionClass, 1n); assert.equal(plan.factsVerified, false);
    const frozen = client.prepareEntropyInstantPolicyFreeze({ ...s, ...next }), freezeKey = scope(s, "freeze");
    const frozenState = { ...next, config: { ...next.config, locked: true }, entry: { ...next.entry, revision: next.entry.revision + 1n } };
    assert.deepEqual(frozen.next, frozenState); assert.equal(frozen.actionClass, 2n);
    assert.deepEqual(frozen.transition, { scopeHash: freezeKey, oldValueHash: stateHash(freezeKey, next), newValueHash: stateHash(freezeKey, frozenState), artistContentStateHash: content(next.entry.policyHash, true) });
    assert.notEqual(frozen.transition.artistContentStateHash, plan.transition.artistContentStateHash);
  }
});

test("LOW_SECURITY admission rejects every ASYNC-only input while preserving the older unsupported profile", () => {
  const { snapshot: s, input: p, resolution: r } = sample();
  for (const patch of [{ securityClass: 0n }, { mode: 2n }, { timeoutBlocks: 1n }, { maxFreshRecoveryAttempts: 1n }, { recoveryPolicyId: id("forbidden") },
    ...[{ declared: true }, { requestMode: 1n }, { revealOwnerRole: id("ROLE_ENTROPY_REVEAL_OWNER") }, { requestSLOBlocks: 1n }, { revealFeePerTokenWei: 1n }].map(v => ({ reveal: { ...p.reveal, ...v } }))]) {
    assert.throws(() => client.prepareEntropyInstantPolicyConfigure(s, { ...p, ...patch }, r));
  }
  assert.throws(() => client.prepareEntropyInstantPolicyConfigure({ ...s, revealEscrow: 1n }, p, r));
  assert.throws(() => client.prepareEntropyInstantPolicyConfigure({ ...s, collectionMintedEver: 1n }, p, r));
  assert.throws(() => earlier.prepareEntropyCollectionPolicyConfigure(s, p, { providerCodeHash: r.providerCodeHash, providerConfigHash: r.providerConfigHash, recoveryPolicyHash: r.recoveryPolicyHash }), earlier.EntropyCollectionPolicyUnsupportedModeError);
  const nr = client.prepareEntropyInstantPolicyConfigure(s, { ...p, renderRequirement: 1n }, r);
  assert.equal(nr.next.entry.renderRequirement, 1n); assert.equal(nr.next.entry.mode, 1n);
  assert.equal(nr.next.reveal.declared, false); assert.equal(nr.next.recovery.maxFreshRecoveryAttempts, 0n);
});

test("original op17 typed signature and two governance action classes retain compiler identities", () => {
  const { snapshot: s, input: p, resolution: r } = sample(), configure = client.prepareEntropyInstantPolicyConfigure(s, p, r);
  const freeze = client.prepareEntropyInstantPolicyFreeze({ ...s, ...configure.next }), registry = address(50), signer = address(60), caller = address(70);
  const authorization = { nonce: (1n << 240n) + 3n, deadline: 900000n, signature: "0x1234" };
  const fields = "address core,address metadataContract,uint256 collectionId,bytes32 familyId,bytes32 newStateHash,uint256 nonce,uint64 deadline".split(",").map(v => { const [type, name] = v.split(" "); return { type, name }; });
  for (const plan of [configure, freeze]) {
    const prepared = client.prepareEntropyInstantPolicyArtistConsent(plan, registry, caller, signer, authorization);
    const message = { core: s.core, metadataContract: s.coordinator, collectionId: s.collectionId, familyId: id("6529STREAM_ENTROPY_CONFIGURATION_V1"), newStateHash: plan.transition.artistContentStateHash, nonce: authorization.nonce, deadline: authorization.deadline };
    assert.equal(prepared.payload.digest, TypedDataEncoder.hash({ name: "6529StreamArtistRegistry", version: "1", chainId: s.chainId, verifyingContract: registry }, { StreamArtistContentConsent: fields }, message));
    assert.equal(prepared.call.data, abi.artist.encodeFunctionData("recordContentConsent", [[s.collectionId, s.coordinator, message.familyId, message.newStateHash], [authorization.nonce, authorization.deadline, authorization.signature]]));
    const window = { notBefore: plan.actionClass === 1n ? 172801n : 259201n, expiresAfter: 900000n, reasonHash: id("review"), reasonURI: "ipfs://instant-review", manifestHash: id("manifest") };
    const batch = client.entropyInstantPolicyGovernanceBatch(plan, 123n, window), calls = [plan.governanceCall];
    const callsType = abi.executor.getFunction("scheduleGovernanceBatch").inputs[1];
    const callsHash = hash(["bytes32", callsType], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
    const aggregate = (domain, field) => hash(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, [plan.governanceCall[field]]]);
    const scopeHash = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash"), oldValueHash = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash"), newValueHash = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash");
    const identity = { actionClass: plan.actionClass, callsHash, scopeHash, oldValueHash, newValueHash, nonce: 123n, notBefore: window.notBefore, expiresAfter: window.expiresAfter, reasonHash: window.reasonHash, manifestHash: window.manifestHash };
    assert.equal(batch.actionId, hash(["bytes32", "uint256", "address", abi.governanceIdentity.getFunction("governanceActionId").inputs[0]], ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", s.chainId, s.governanceExecutor, identity]));
    assert.equal(batch.executionCall.data, abi.executor.encodeFunctionData("executeGovernanceBatch", [batch.actionId, calls, [plan.targetCall.data]]));
  }
});

function requestSample() {
  const { snapshot: s, input: p, resolution: r } = sample(), next = independentNext(s, p, r);
  const policy = { configured: true, explicitPolicy: true, frozen: true, mode: 1n, securityClass: 1n, renderRequirement: 0n, revision: 1n,
    providerEpoch: next.providerEpoch, policyHash: next.entry.policyHash, contentStateHash: content(next.entry.policyHash, true), lastActionId: id("accepted action"), artistConsentRecord: id("accepted consent") };
  return { chainId: s.chainId, coordinator: s.coordinator, core: s.core, collectionId: s.collectionId, tokenId: (1n << 256n) - 1n,
    config: { ...next.config, locked: true }, policy,
    subject: { collectionId: s.collectionId, inputsHash: id("original audited mint commitment"), requestKey: ZeroHash, seed: ZeroHash, status: 3n },
    registeredAtBlock: 99n, blockNumber: 100n, tokenLifecycle: 2n, coordinatorAtMint: s.coordinator };
}
function requestPreimages(s) {
  const q = { provider: s.config.provider, providerCodeHash: s.config.providerCodeHash, providerEpoch: s.policy.providerEpoch, providerConfigHash: s.config.providerConfigHash, collectionSalt: s.config.collectionSalt, inputsHash: ZeroHash, requestAttempt: 1n };
  const context = coder.encode(["uint16", "address", "uint256", "uint256", "bytes32", "uint32", "bytes32", "uint16", "bytes32"], [1n, s.core, s.collectionId, s.tokenId, ZeroHash, q.providerEpoch, q.providerConfigHash, 1n, ZeroHash]);
  const requestKey = hash(["bytes32", "uint256", "address", "address", "uint256", "uint256", "address", "uint32", "bytes32", "uint16"], [id("6529STREAM_ENTROPY_REQUEST_V1"), s.chainId, s.coordinator, s.core, s.collectionId, s.tokenId, q.provider, q.providerEpoch, q.providerConfigHash, 1n]);
  const providerRequestId = BigInt(hash(["bytes32", "bytes32", "uint16", "address", "uint32", "bytes32"], [id("6529STREAM_INSTANT_PROVIDER_REQUEST_V1"), requestKey, 1n, q.provider, q.providerEpoch, q.providerConfigHash]));
  return { q, context, requestKey, providerRequestId };
}
function seed(s, q, key, providerRequestId, raw) {
  return hash(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "address", "uint32", "bytes32", "bytes32", "uint256", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ENTROPY_SEED_V1"), s.chainId, s.coordinator, s.core, s.collectionId, `0x${s.tokenId.toString(16).padStart(64, "0")}`, q.provider, q.providerEpoch, q.providerConfigHash, key, providerRequestId, raw, q.collectionSalt, ZeroHash]);
}

test("original full-width request identities, context and seed keep zero request inputs with the audited mint commitment", () => {
  const s = requestSample(), actor = address(100), value = (1n << 210n) + 9n, expected = requestPreimages(s);
  const p = client.prepareEntropyInstantRequest(s, actor, value);
  assert.deepEqual(p.requestPolicy, expected.q); assert.equal(p.context, expected.context);
  assert.equal(p.requestKey, expected.requestKey); assert.equal(p.providerRequestId, expected.providerRequestId);
  assert.equal(p.subjectKey, hash(["string", "uint256"], ["TOKEN", s.tokenId]));
  assert.equal(p.call.data, abi.entropy.encodeFunctionData("requestEntropy", [s.tokenId]));
  assert.equal(p.call.value, value); assert.equal(p.callerCredit, value); assert.equal(p.providerFee, 0n); assert.equal(p.factsVerified, false);
  assert.equal(p.snapshot.subject.inputsHash, s.subject.inputsHash); assert.equal(p.requestPolicy.inputsHash, ZeroHash);
  const qtype = abi.epochs.getFunction("requestPolicySnapshot").outputs[0];
  assert.equal(client.encodeEntropyInstantRequestPolicySnapshot(p.requestPolicy), coder.encode([qtype], [expected.q]));
  for (const raw of [ZeroHash, id("raw entropy")]) {
    assert.equal(client.entropyInstantSeed(p, raw), seed(s, expected.q, expected.requestKey, expected.providerRequestId, raw));
    const changed = client.prepareEntropyInstantRequest({ ...s, subject: { ...s.subject, inputsHash: id("changed mint commitment") }, blockNumber: s.blockNumber + 1n }, actor, 0n);
    assert.equal(changed.context, p.context); assert.equal(changed.requestKey, p.requestKey); assert.equal(changed.providerRequestId, p.providerRequestId);
    assert.equal(client.entropyInstantSeed(changed, raw), client.entropyInstantSeed(p, raw));
  }
  assert.match(source("StreamEntropyRequestPlan"), /\? bytes32\(0\)\s*: subject\.inputsHash/);
  assert.match(source("StreamEntropyCoordinatorReads"), /inputs\.inputsHash = policy\.inputsHash/);
});

test("request admission preserves strict later-block delivery, original host, lifecycle and REQUIRED status", () => {
  const s = requestSample(), actor = address(100);
  for (const patch of [{ blockNumber: s.registeredAtBlock }, { blockNumber: s.registeredAtBlock - 1n }, { blockNumber: 1n << 64n },
    { coordinatorAtMint: address(999) }, { tokenLifecycle: 3n }, { policy: { ...s.policy, renderRequirement: 1n } },
    ...[0n, 1n, 2n, 4n, 5n, 6n, 7n].map(status => ({ subject: { ...s.subject, status } }))]) {
    assert.throws(() => client.prepareEntropyInstantRequest({ ...s, ...patch }, actor, 0n));
  }
  const plan = client.prepareEntropyInstantRequest(s, actor, 0n), c = { chainId: s.chainId, coordinator: s.coordinator, core: s.core, collectionId: s.collectionId, tokenId: s.tokenId };
  assert.throws(() => client.entropyInstantContext(c, { ...plan.requestPolicy, inputsHash: s.subject.inputsHash }));
  assert.throws(() => client.entropyInstantRequestKey(c, { ...plan.requestPolicy, requestAttempt: 2n }));
  assert.equal(plan.callerCredit, 0n); assert.equal(plan.call.value, 0n);
  assert.match(source("StreamEntropyRequestPlan"), /block\.number <= registeredAt/);
  assert.match(source("StreamEntropyRequestPlan"), /instant \|\| !_role\(a, reveal\.revealOwnerRole\)/);
  assert.match(source("StreamEntropyScopeRegistration"), /requireAsync/);
});

test("concrete delayed provider formulas bind mined predecessor evidence and declared assumptions independently", () => {
  const s = requestSample(), p = client.prepareEntropyInstantRequest(s, address(100), 0n), assumptionsText = "LOW_SECURITY: previous-block hash; validator influence; publicly simulatable; request-timing selection; not VRF; mintCommitment excluded";
  const assumptions = id(assumptionsText), configHash = hash(["bytes32", "address", "uint8", "bytes32"], [id("6529STREAM_INSTANT_BLOCKHASH_CONFIG_V1"), s.coordinator, 1n, assumptions]);
  assert.equal(client.ENTROPY_INSTANT_ASSUMPTIONS, assumptionsText); assert.equal(client.ENTROPY_INSTANT_ASSUMPTIONS_HASH, assumptions);
  assert.equal(client.ENTROPY_INSTANT_PROVIDER_FAMILY, id("STREAM_INSTANT_DELAYED_BLOCKHASH"));
  assert.equal(client.ENTROPY_INSTANT_PROVIDER_VERSION, id("6529stream.entropy-provider-instant-blockhash.v1"));
  assert.equal(client.entropyInstantProviderConfigHash(s.coordinator), configHash);
  const sourceBlock = 123456n, sourceHash = id("mined predecessor"), contextHash = keccak256(p.context);
  const rawRandomness = hash(["bytes32", "bytes32", "bytes32", "uint256", "bytes32"], [id("6529STREAM_INSTANT_BLOCKHASH_RAW_V1"), p.requestKey, contextHash, sourceBlock, sourceHash]);
  const provenanceHash = hash(["bytes32", "bytes32", "bytes32", "bytes32", "uint256", "bytes32", "bytes32"], [id("6529STREAM_INSTANT_BLOCKHASH_PROVENANCE_V1"), configHash, p.requestKey, contextHash, sourceBlock, sourceHash, assumptions]);
  const observed = client.entropyInstantRawResult(p.requestKey, p.context, sourceBlock, sourceHash, configHash, assumptions);
  assert.deepEqual(observed, { rawRandomness, provenanceHash });
  for (const [block, blockHash] of [[sourceBlock + 1n, sourceHash], [sourceBlock, id("different predecessor")]]) {
    const changed = client.entropyInstantRawResult(p.requestKey, p.context, block, blockHash, configHash, assumptions);
    assert.notEqual(changed.rawRandomness, rawRandomness); assert.notEqual(changed.provenanceHash, provenanceHash);
    assert.notEqual(client.entropyInstantSeed(p, changed.rawRandomness), client.entropyInstantSeed(p, rawRandomness));
  }
  for (const mode of [0n, 2n, 3n]) assert.throws(() => client.normalizeEntropyInstantProviderProfile({ mode, assumptionsHash: assumptions }));
  assert.throws(() => client.normalizeEntropyInstantProviderProfile({ mode: 1n, assumptionsHash: ZeroHash }));
  assert.match(source("StreamEntropyProviderInstant"), /sourceBlock = block\.number - 1/);
  assert.match(source("StreamEntropyInstantProviderReads"), /returned != size/);
  assert.match(source("StreamEntropyInstantProviderReads"), /\(available - 10000\) \/ 64 \* 63 < cap/);
});

test("sixteen-word codec keeps every actual status and rejects truncation, extension and noncanonical words", () => {
  const s = requestSample(), f = abi.terminalFacts.getFunction("staticTerminalEntropyFacts");
  for (const status of [0n, 1n, 2n, 3n, 4n, 5n, 6n, 7n]) {
    const facts = { collectionId: s.collectionId, policy: s.policy, status, seed: ZeroHash, requestKey: ZeroHash };
    const encoded = abi.terminalFacts.encodeFunctionResult(f, [facts.collectionId, facts.policy, status, facts.seed, facts.requestKey]);
    assert.equal((encoded.length - 2) / 2, 512); assert.equal(client.encodeEntropyInstantTerminalFacts(facts), encoded);
    assert.deepEqual(client.decodeEntropyInstantTerminalFacts(encoded), facts);
    assert.throws(() => client.decodeEntropyInstantTerminalFacts(encoded.slice(0, -64)));
    assert.throws(() => client.decodeEntropyInstantTerminalFacts(encoded + "00".repeat(32)));
  }
  const data = client.encodeEntropyInstantTerminalFacts({ collectionId: s.collectionId, policy: s.policy, status: 3n, seed: ZeroHash, requestKey: ZeroHash });
  const replaceWord = (index, value) => data.slice(0, 2 + index * 64) + value.toString(16).padStart(64, "0") + data.slice(2 + (index + 1) * 64);
  assert.throws(() => client.decodeEntropyInstantTerminalFacts(replaceWord(1, 2n))); // configured bool
  assert.throws(() => client.decodeEntropyInstantTerminalFacts(replaceWord(4, 3n))); // policy mode
  assert.throws(() => client.decodeEntropyInstantTerminalFacts(replaceWord(13, 256n))); // uint8 status
});
