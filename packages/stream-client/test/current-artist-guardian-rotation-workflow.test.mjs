import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as pure from "../dist/current-artist-guardian-rotation.js";
import * as workflow from "../dist/current-artist-guardian-rotation-workflow.js";

// ABI responses come from the existing frozen compiler witness, never the handwritten ABI.
const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-artist-recovered-multiple-consent-hydration-abi.json", import.meta.url), "utf8"));
const abi = new Interface(Object.values(fixture.abis).flat().filter(v => v.type !== "constructor"));
const originalEvents = new Interface([...Object.values(fixture.abis).flat(), ...Object.values(fixture.libraryAbis).flat()].filter(v => v.type === "event"));
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = v => id(String(v));
const hash = (types, values) => keccak256(coder.encode(types, values));
const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"].map(v => H(`domain:${v}`));

function setup(kind = "setGuardians", options = {}) {
  const codes = new Map();
  const pin = n => { const code = `0x60${n.toString(16).padStart(2, "0")}6000`, address = A(n); codes.set(address, code); return { address, codeHash: keccak256(code) }; };
  const components = Array.from({ length: 16 }, (_, i) => pin(i + 1));
  const deployment = { chainId: 1n, registry: components[7], coordinator: pin(20), components, reads: pin(21) };
  const artistId = H("artist"), oldAddress = A(60), newAddress = A(61), guardians = [A(70), A(71)];
  const timestamp = options.timestamp ?? 1000000n;
  const caller = options.caller ?? (kind === "approveRotation" ? guardians[0] : kind === "executeRotation" ? A(90) : oldAddress);
  const guardianTerms = { artistId, guardians, approvalThreshold: 2n, minContestSeconds: 0n };
  const guardianHash = hash(["bytes32", "uint256", "address", "bytes32", "address[]", "uint32", "uint64", "uint256", "uint64"],
    ["0xfb979fce9edd361cf23ba8baee900f7054451db7b563ba0ab11a5ef3621cd297", 1n, deployment.registry.address, artistId, guardians, 2n, 0n, 2n, 500000n]);
  const guardianRecord = { recordHash: guardianHash, terms: guardianTerms, signer: oldAddress, authorityClass: 1n, nonce: 2n,
    signedAt: 500000n, previousOperativeRecordHash: ZeroHash, provisional: { transitionRecordHash: ZeroHash, windowEndsAt: 0n } };
  const rotationTerms = { artistId, oldAddress, newAddress, reasonHash: ZeroHash, expectedPreviousTransitionRecordHash: ZeroHash };
  const stagedAt = 900000n, contestEndsAt = stagedAt + 604800n;
  const rotationHash = hash(["bytes32", "uint256", "address", "bytes32", "address", "address", "bytes32", "uint256", "uint64", "uint64"],
    ["0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5", 1n, deployment.registry.address, artistId, oldAddress, newAddress, ZeroHash, 3n, stagedAt, contestEndsAt]);
  const rotationRecord = { recordHash: rotationHash, terms: rotationTerms, guardianSetRecordHash: guardianHash, approvalThreshold: 2n,
    guardianApprovals: options.approvals ?? (kind === "executeRotation" ? 2n : 0n), oldNonce: 3n, newNonce: 5n, effectiveWindow: 604800n,
    standingTail: 7776000n, timingRevision: 1n,
    transition: { artistId, recordHash: rotationHash, stagedAt, contestEndsAt, executedAt: 0n, postWindowEndsAt: 0n, contestedAt: 0n, phase: 1n } };
  const hasPending = !["setGuardians", "stageRotation"].includes(kind);
  const ctx = { chainId: 1n, registry: deployment.registry.address, caller };
  const auth = { nonce: 3n, time: kind === "setGuardians" ? options.guardianTime ?? 0n : options.deadline ?? timestamp + 100n, signature: options.oldSignature ?? "0x" };
  const request = kind === "setGuardians" ? { ...ctx, kind, terms: guardianTerms, authorization: auth }
    : kind === "stageRotation" ? { ...ctx, kind, terms: rotationTerms, oldAuthorization: auth,
      newAuthorization: { nonce: options.newNonce ?? 5n, time: options.newDeadline ?? timestamp + 100n, signature: options.newSignature ?? "0x1234" } }
    : { ...ctx, kind, artistId, expectedRotationRecordHash: rotationHash, ...(kind === "vetoRotation" ? { reasonHash: ZeroHash } : {}) };
  const state = { codes, deployment, request, artistId, oldAddress, newAddress, guardians, guardianRecord, rotationRecord,
    timestamp, hasPending, hooks: [], calls: [], blockCalls: 0, latestTransition: hasPending ? rotationHash : ZeroHash,
    authorityClass: options.authorityClass ?? 1n, status: options.status ?? ((options.authorityClass ?? 1n) === 1n ? 1n : 3n),
    capabilities: options.capabilities ?? 4095n, activationRecordHash: options.activationRecordHash ?? ((options.authorityClass ?? 1n) === 1n ? ZeroHash : H("activation")),
    principalReplay: { digestObserved: false, digestRevoked: false, nonceConsumed: false, nonceRevoked: false, nextUnusedNonce: 3n },
    acceptance: [false, 5n], activeWindow: hasPending ? [rotationHash, contestEndsAt, false] : [ZeroHash, 0n, false],
    standing: [ZeroHash, ZeroHash, ZeroHash, ZeroHash], successor: [ZeroAddress, 0n, 0n, ZeroHash, ZeroHash, 0n],
    codeHook: undefined, blockHook: undefined, failSimulation: false, tx: null, receipt: null, archive: null };
  const suite = { registry: components[7].address, archive: components[8].address, owners: components.slice(0, 7).map(v => v.address),
    core: components[9].address, mintManager: components[10].address, roleRegistry: components[11].address, metadata: components[12].address,
    primaryResolver: components[13].address, royaltyResolver: components[14].address, primaryRevenueClass: H("PRIMARY_SALE"), validator: components[15].address };
  const encode = (f, values) => abi.encodeFunctionResult(f, values);
  const provider = {
    async getNetwork() { return { chainId: 1n }; },
    async getBlock(tag) { state.blockCalls++; return state.blockHook?.(tag, state.blockCalls) ?? { number: tag, hash: H(`block${tag}`), timestamp: Number(state.timestamp) }; },
    async getCode(addr, tag) { return state.codeHook?.(getAddress(addr), tag) ?? codes.get(getAddress(addr)) ?? "0x"; },
    async getTransaction() { return state.tx; },
    async getTransactionReceipt() { return state.receipt; },
    async call(tx) {
      const parsed = abi.parseTransaction({ data: tx.data }), f = parsed.fragment, args = parsed.args, method = f.name, to = getAddress(tx.to);
      state.calls.push({ ...tx, method, args });
      for (const hook of state.hooks) { const result = await hook({ method, args, to, tx, fragment: f }); if (result !== undefined) return typeof result === "string" ? result : encode(f, result); }
      switch (method) {
        case "deploymentChainId": return encode(f, [1n]);
        case "suiteConfiguration": return encode(f, [suite]);
        case "configurationHash": return encode(f, [H("configuration")]);
        case "reads": return encode(f, [deployment.reads.address]);
        case "core": return encode(f, [components[9].address]);
        case "coreCodeHash": return encode(f, [components[9].codeHash]);
        case "mintManager": return encode(f, [components[10].address]);
        case "artistRegistry": return encode(f, [components[7].address]);
        case "operationCoordinator": return encode(f, [deployment.coordinator.address]);
        case "archiveV2": return encode(f, [components[8].address]);
        case "domainId": return encode(f, [domains[components.findIndex(v => v.address === to)]]);
        case "getSatellitePointer": return encode(f, [deployment.registry.address, deployment.registry.codeHash, false, ZeroHash, "0x00000000", ZeroAddress, 0n, ZeroHash, ZeroHash, 1n]);
        case "artistRegistryCutover": return encode(f, [false, ZeroAddress, 0n]);
        case "authorityState": return encode(f, [oldAddress, state.authorityClass, state.status, H("identity")]);
        case "currentAuthorityCapabilities": return encode(f, [{ authorityAddress: oldAddress, authorityClass: state.authorityClass, status: state.status,
          effectiveCapabilities: state.capabilities, activationRecordHash: state.activationRecordHash }]);
        case "guardianSet": return encode(f, [state.guardianRecord.terms.guardians, state.guardianRecord.terms.approvalThreshold, state.guardianRecord.terms.minContestSeconds, state.guardianRecord.recordHash]);
        case "guardianSetRecord": return encode(f, [state.guardianRecord]);
        case "pendingRotation": return encode(f, state.hasPending ? [oldAddress, newAddress, state.rotationRecord.transition.contestEndsAt, state.rotationRecord.guardianApprovals, rotationHash] : [ZeroAddress, ZeroAddress, 0n, 0n, ZeroHash]);
        case "rotationRecord": return encode(f, [state.rotationRecord]);
        case "artistTransitionState": return encode(f, [state.rotationRecord.transition]);
        case "lastArtistTransition": return encode(f, [state.latestTransition]);
        case "activeAuthorityWindow": return encode(f, state.activeWindow);
        case "artistWindowInfo": return encode(f, args[0] === H("ARTIST_ROTATION_CONTEST_SECONDS") ? [604800n, 259200n, 1n] : [7776000n, 2592000n, 1n]);
        case "activeIdentity": return encode(f, [getAddress(args[0]) === oldAddress ? artistId : ZeroHash]);
        case "guardianSetDigest": return encode(f, [pure.guardianRotationDigest("guardianSet", 1n, deployment.registry.address, state.request.terms, { nonce: args[1].nonce, time: args[1].time, signature: args[1].signature })]);
        case "rotationDigest": return encode(f, [pure.guardianRotationDigest("rotation", 1n, deployment.registry.address, state.request.terms, { nonce: args[1].nonce, time: args[1].time, signature: args[1].signature })]);
        case "rotationAcceptanceDigest": return encode(f, [pure.guardianRotationDigest("rotationAcceptance", 1n, deployment.registry.address, state.request.terms, { nonce: args[1].nonce, time: args[1].time, signature: args[1].signature })]);
        case "artistAuthorizationState": return encode(f, [state.principalReplay]);
        case "rotationAcceptanceNonceState": return encode(f, state.acceptance);
        case "successorDesignation": return encode(f, state.successor);
        case "priorAddressStandingRevoked": return encode(f, [state.standing[1] !== ZeroHash, state.standing[1]]);
        case "recoveryStandingScopeV3": return encode(f, state.standing);
        case "artistEvidenceMetadataV2": return encode(f, [state.archive.contentHash, state.archive.pointer, BigInt((state.archive.bytes.length - 2) / 2), 12n]);
        case "artistEvidenceBytesV2": return encode(f, [state.archive.bytes]);
        case "setArtistGuardians": case "rotateArtistAddress": case "approveArtistRotation": case "vetoArtistRotation": case "executeArtistRotation":
          if (state.failSimulation) throw Error("contract refused operation");
          if (method === "setArtistGuardians") return encode(f, [pure.artistGuardianRecordHash(1n, deployment.registry.address, state.request.terms, state.request.authorization.nonce, state.request.authorization.time || state.timestamp)]);
          if (method === "rotateArtistAddress") return encode(f, [pure.artistRotationRecordHash(1n, deployment.registry.address, state.request.terms, state.request.oldAuthorization.nonce, state.timestamp,
            state.timestamp + (state.guardianRecord.terms.minContestSeconds > 604800n ? state.guardianRecord.terms.minContestSeconds : 604800n))]);
          return encode(f, []);
        default: throw Error(`Unhandled fixture read ${method}`);
      }
    },
  };
  return { state, provider, deployment, prepared: pure.prepareGuardianRotationCall(request), encode };
}
const capture = s => workflow.captureGuardianRotation(s.provider, s.deployment, s.prepared, { blockTag: 10 });

function installReceipt(s, c, execution = "direct") {
  const st = s.state, q = c.prepared.request, op = c.prepared.operation, blockNumber = 12, transactionHash = H("tx"), blockHash = H("block12");
  const timestamp = st.timestamp;
  const proof = (signer, part) => ({ signer, digest: part.effectiveDigest, direct: part.direct });
  const proofType = "(address signer,bytes32 digest,bool direct)";
  const guardianType = abi.getFunction("guardianSetRecord").outputs[0].format("full");
  const rotationType = abi.getFunction("rotationRecord").outputs[0].format("full");
  const guardianTermsType = abi.getFunction("setArtistGuardians").inputs[0].format("full");
  const rotationTermsType = abi.getFunction("rotateArtistAddress").inputs[0].format("full");
  const authType = abi.getFunction("setArtistGuardians").inputs[1].format("full");
  let recordHash, payload, eventName, eventValues, archivedRecord;
  if (op === 28) {
    const a = { ...q.authorization, time: q.authorization.time || timestamp };
    recordHash = pure.artistGuardianRecordHash(1n, q.registry, q.terms, a.nonce, a.time);
    archivedRecord = { recordHash, terms: q.terms, signer: c.authority.address, authorityClass: c.authority.authorityClass, nonce: a.nonce,
      signedAt: a.time, previousOperativeRecordHash: c.guardianSet.recordHash, provisional: { transitionRecordHash: ZeroHash, windowEndsAt: 0n } };
    payload = coder.encode([guardianTermsType, authType, proofType, authType, guardianType], [q.terms, q.authorization, proof(c.authority.address, c.signing[0]), a, archivedRecord]);
    eventName = "ArtistGuardianSetUpdated";
    eventValues = [1n, st.artistId, q.terms.guardians, q.terms.approvalThreshold, q.terms.minContestSeconds, c.authority.authorityClass, a.nonce, a.time, recordHash];
  } else if (op === 29) {
    const effectiveWindow = c.windows.rotation.value > c.guardianSet.minContestSeconds ? c.windows.rotation.value : c.guardianSet.minContestSeconds;
    recordHash = pure.artistRotationRecordHash(1n, q.registry, q.terms, q.oldAuthorization.nonce, timestamp, timestamp + effectiveWindow);
    archivedRecord = { recordHash, terms: q.terms, guardianSetRecordHash: c.guardianSet.recordHash, approvalThreshold: c.guardianSet.approvalThreshold,
      guardianApprovals: 0n, oldNonce: q.oldAuthorization.nonce, newNonce: q.newAuthorization.nonce, effectiveWindow, standingTail: c.windows.standingTail.value,
      timingRevision: c.windows.rotation.revision, transition: { artistId: st.artistId, recordHash, stagedAt: timestamp,
        contestEndsAt: timestamp + effectiveWindow, executedAt: 0n, postWindowEndsAt: 0n, contestedAt: 0n, phase: 1n } };
    payload = coder.encode([rotationTermsType, authType, authType, proofType, proofType, rotationType], [q.terms, q.oldAuthorization, q.newAuthorization,
      proof(q.terms.oldAddress, c.signing[0]), proof(q.terms.newAddress, c.signing[1]), archivedRecord]);
    eventName = "ArtistRotationStaged";
    eventValues = [1n, st.artistId, q.terms.oldAddress, q.terms.newAddress, timestamp, timestamp + effectiveWindow, q.oldAuthorization.nonce, q.terms.reasonHash, recordHash];
  } else {
    recordHash = q.expectedRotationRecordHash;
    archivedRecord = structuredClone(c.rotationRecord);
    if (op === 30) {
      archivedRecord.guardianApprovals++;
      eventName = "ArtistRotationGuardianApproved";
      eventValues = [1n, st.artistId, q.caller, recordHash, archivedRecord.guardianApprovals];
    } else if (op === 32) {
      archivedRecord.transition.phase = 2n; archivedRecord.transition.executedAt = timestamp;
      archivedRecord.transition.postWindowEndsAt = timestamp + archivedRecord.effectiveWindow;
      eventName = "ArtistAddressRotated";
      eventValues = [1n, st.artistId, archivedRecord.terms.oldAddress, archivedRecord.terms.newAddress, c.authority.authorityClass, archivedRecord.terms.reasonHash, recordHash];
    } else {
      archivedRecord.transition.phase = 3n; archivedRecord.transition.contestedAt = timestamp;
      eventName = "ArtistRotationVetoed";
      eventValues = [1n, st.artistId, q.caller, recordHash, q.reasonHash];
    }
    if (op === 31) {
      const causeType = abi.getFunction("currentIdentityContestCause").outputs[0];
      const factsType = causeType.components.find(v => v.name === "facts");
      const facts = { artistId: st.artistId, kind: 2n, referenceHash: recordHash, actor: q.caller, reasonHash: q.reasonHash, evidenceHash: ZeroHash,
        enteredAt: timestamp, incumbent: c.authority.address, authorityClass: c.authority.authorityClass, priorStatus: c.authority.status,
        pendingTransitionHash: recordHash, executedTransitionHash: ZeroHash, previousCauseHash: ZeroHash, previousResolutionHash: ZeroHash, actorRetirementHash: ZeroHash };
      const cause = { causeHash: hash(["bytes32", "uint256", "address", "address", factsType],
        [H("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"), 1n, q.registry, c.deployment.components[2].address, facts]), facts };
      payload = coder.encode(["bytes32", "bytes32", "bytes32", rotationType, causeType], [st.artistId, recordHash, q.reasonHash, archivedRecord, cause]);
    } else payload = coder.encode(["bytes32", "bytes32", rotationType], [st.artistId, recordHash, archivedRecord]);
  }
  const empty = { domainId: ZeroHash, revision: 0n, stateRoot: ZeroHash, recordChainTip: ZeroHash };
  const before = Array.from({ length: 7 }, (_, i) => i === 2 ? { domainId: domains[2], revision: 7n, stateRoot: H("before"), recordChainTip: H("before tip") } : empty);
  const after = before.map((v, i) => i === 2 ? { ...v, revision: 8n, stateRoot: H("after"), recordChainTip: op < 30 ? H("after tip") : v.recordChainTip } : v);
  const snapshot = "(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)";
  const evidence = coder.encode(["uint16", "bytes32", "uint16", "address", "bytes32", `${snapshot}[7]`, `${snapshot}[7]`, "bytes"],
    [1n, c.configurationHash, op, q.caller, recordHash, before, after, payload]);
  const evidenceId = hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [H("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), 1n, q.registry, c.deployment.coordinator.address, op, q.caller, recordHash]);
  const pointer = A(150), contentHash = keccak256(evidence);
  st.archive = { bytes: evidence, evidenceId, contentHash, pointer, archivedRecord, before, after };
  st.codes.set(pointer, `0x00${evidence.slice(2)}`);
  const eventAbi = new Interface(pure.CURRENT_ARTIST_GUARDIAN_ROTATION_ABI);
  const native = eventAbi.encodeEventLog(eventAbi.getEvent(eventName), eventValues);
  const archiveEvent = abi.encodeEventLog(abi.getEvent("ArtistArchiveEvidenceAppendedV2"), [evidenceId, 1n, contentHash, pointer, BigInt((evidence.length - 2) / 2)]);
  const logs = [{ address: c.deployment.components[2].address, ...native }, { address: c.deployment.components[8].address, ...archiveEvent }]
    .map((v, index) => ({ ...v, index, transactionIndex: 0, transactionHash, blockNumber, blockHash, removed: false }));
  st.tx = { hash: transactionHash, blockHash, blockNumber, from: q.caller, to: q.registry, data: c.prepared.call.data, value: 0n, chainId: 1n };
  st.receipt = { hash: transactionHash, blockHash, blockNumber, from: q.caller, to: q.registry, status: 1, logs };
  if (execution === "safe") {
    const safe = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)",
      "event ExecutionSuccess(bytes32 txHash,uint256 payment)"]);
    const safeLog = safe.encodeEventLog(safe.getEvent("ExecutionSuccess"), [H("safe transaction"), 0n]);
    st.tx = { ...st.tx, to: q.caller, from: A(99), data: safe.encodeFunctionData("execTransaction", [q.registry, 0n, c.prepared.call.data, 0, 1000000n, 0n, 0n, ZeroAddress, ZeroAddress, "0x1234"]) };
    st.receipt = { ...st.receipt, to: q.caller, from: A(99), logs: [...logs, { ...logs[0], ...safeLog, address: q.caller, index: 2 }] };
  }
  return transactionHash;
}

test("guardian capture distinguishes submitted zero time from effective block time", async () => {
  const s = setup(), c = await capture(s);
  assert.equal(c.prepared.factsVerified, false);
  assert.equal(c.simulationRequired, true);
  assert.equal(c.signing[0].direct, true);
  assert.equal(c.signing[0].submittedTime, 0n);
  assert.equal(c.signing[0].effectiveTime, s.state.timestamp);
  assert.equal(c.signing[0].rawDigest, s.prepared.signing[0].digest);
  assert.equal(c.signing[0].effectiveDigest, pure.guardianRotationDigest("guardianSet", 1n, s.deployment.registry.address,
    s.state.request.terms, { ...s.state.request.authorization, time: s.state.timestamp }));
  assert.notEqual(c.signing[0].effectiveDigest, s.prepared.signing[0].digest);
  assert(s.state.calls.every(v => v.blockTag === 10));
  assert(Object.isFrozen(c));
});

test("rotation has independently observed old and new consent lanes", async () => {
  const s = setup("stageRotation"), c = await capture(s);
  assert.equal(c.signing.length, 2);
  assert.equal(c.signing[0].direct, true);
  assert.equal(c.signing[1].direct, false);
  const calls = s.state.calls.filter(v => v.method === "rotationAcceptanceNonceState");
  assert.equal(calls.length, 1);
  assert.deepEqual([...calls[0].args], [s.state.artistId, s.state.newAddress, 5n]);
});

test("same numeric old/new nonce is supported through separate lanes", async () => {
  const s = setup("stageRotation", { newNonce: 3n });
  s.state.acceptance = [false, 3n];
  await capture(s);
});

test("acceptance does not inherit principal nonce-consumed or nonce-revoked flags", async () => {
  const s = setup("stageRotation");
  s.state.hooks.push(({ method, args }) => method === "artistAuthorizationState" && args[2] === 5n
    ? [{ ...s.state.principalReplay, nonceConsumed: true, nonceRevoked: true }] : undefined);
  await capture(s);
});

test("observed digest alone does not revoke a valid authorization", async () => {
  const s = setup("stageRotation"); s.state.principalReplay.digestObserved = true; await capture(s);
});

test("both deadlines accept equality and reject expiry independently", async () => {
  await capture(setup("stageRotation", { deadline: 1000000n, newDeadline: 1000000n }));
  await assert.rejects(capture(setup("stageRotation", { deadline: 999999n })));
  await assert.rejects(capture(setup("stageRotation", { newDeadline: 999999n })));
});

test("guardian direct explicit time equals observed time; relay time cannot be zero or future", async () => {
  await capture(setup("setGuardians", { guardianTime: 1000000n }));
  await assert.rejects(capture(setup("setGuardians", { guardianTime: 999999n })));
  await capture(setup("setGuardians", { caller: A(91), oldSignature: "0x1234", guardianTime: 999999n }));
  await assert.rejects(capture(setup("setGuardians", { caller: A(91), oldSignature: "0x1234", guardianTime: 1000001n })));
  await assert.rejects(capture(setup("setGuardians", { caller: A(91) })));
});

test("empty ERC1271 proof remains relay proof when caller differs", async () => {
  const s = setup("setGuardians", { caller: A(91), guardianTime: 999999n });
  s.state.codes.set(s.state.oldAddress, "0x60006000");
  const c = await capture(s); assert.equal(c.signing[0].direct, false);
  await assert.rejects(capture(setup("setGuardians", { caller: A(91), guardianTime: 999999n })));
});

test("direct and signed principal nonce handling follow their respective rules", async () => {
  const direct = setup(); direct.state.principalReplay.nextUnusedNonce = 4n;
  await assert.rejects(capture(direct));
  const relay = setup("setGuardians", { caller: A(91), oldSignature: "0x1234", guardianTime: 999999n });
  relay.state.principalReplay.nextUnusedNonce = 4n; await capture(relay);
  for (const flag of ["nonceConsumed", "nonceRevoked", "digestRevoked"]) {
    const s = setup(); s.state.principalReplay[flag] = true; await assert.rejects(capture(s), undefined, flag);
  }
});

test("new direct acceptance requires its own hint; used acceptance and revoked digest fail", async () => {
  const s = setup("stageRotation", { caller: A(61), oldSignature: "0x1234", newSignature: "0x" });
  await capture(s);
  s.state.acceptance = [false, 6n]; await assert.rejects(capture(s));
  s.state.acceptance = [true, 5n]; await assert.rejects(capture(s));
  const revoked = setup("stageRotation");
  revoked.state.hooks.push(({ method, args }) => method === "artistAuthorizationState" && args[2] === 5n
    ? [{ ...revoked.state.principalReplay, digestRevoked: true }] : undefined);
  await assert.rejects(capture(revoked));
});

test("stale unsigned transition guard and occupied new address fail", async () => {
  const stale = setup("stageRotation"); stale.state.latestTransition = H("new head"); await assert.rejects(capture(stale));
  const occupied = setup("stageRotation");
  occupied.state.hooks.push(({ method, args }) => method === "activeIdentity" && getAddress(args[0]) === occupied.state.newAddress ? [H("another artist")] : undefined);
  await assert.rejects(capture(occupied));
});

test("active transition windows block a subsequent stage", async () => {
  const s = setup("stageRotation", { deadline: 2000000n, newDeadline: 2000000n });
  const prior = s.state.rotationRecord;
  const priorTerms = { ...prior.terms, oldAddress: A(59), newAddress: s.state.oldAddress };
  const priorHash = hash(["bytes32", "uint256", "address", "bytes32", "address", "address", "bytes32", "uint256", "uint64", "uint64"],
    ["0x8d7c32ae357c27253fd4480fe9d411cefc64a5634952ed8c8ebe7dcf63257ea5", 1n, s.deployment.registry.address,
      s.state.artistId, priorTerms.oldAddress, priorTerms.newAddress, ZeroHash, prior.oldNonce, prior.transition.stagedAt, prior.transition.contestEndsAt]);
  const executedAt = s.state.timestamp - 10n, postWindowEndsAt = executedAt + prior.effectiveWindow;
  s.state.rotationRecord = { ...prior, recordHash: priorHash, terms: priorTerms, guardianApprovals: 2n,
    transition: { ...prior.transition, recordHash: priorHash, executedAt, postWindowEndsAt, phase: 2n } };
  s.state.latestTransition = priorHash;
  s.state.activeWindow = [priorHash, postWindowEndsAt, false];
  s.state.request.terms.expectedPreviousTransitionRecordHash = priorHash;
  s.prepared = pure.prepareGuardianRotationCall(s.state.request);
  await assert.rejects(capture(s), { message: "Active authority window blocks rotation" });

  // The original read clears an uncontested active head at post-window equality; history remains.
  s.state.timestamp = postWindowEndsAt;
  s.state.activeWindow = [ZeroHash, 0n, false];
  const mature = await capture(s);
  assert.equal(mature.latestTransition, priorHash);
  assert.equal(mature.activeWindow.transitionRecordHash, ZeroHash);
  assert.equal(mature.activeTransition, null);
});

test("ordinary principal class/status and guardian-maintenance capability are required", async () => {
  for (const options of [{ authorityClass: 2n }, { status: 4n }, { authorityClass: 3n, capabilities: 0n }, { authorityClass: 4n, capabilities: 0n }]) {
    await assert.rejects(capture(setup("setGuardians", options)));
  }
  await capture(setup("setGuardians", { authorityClass: 3n, capabilities: 256n | 2048n }));
  await capture(setup("setGuardians", { authorityClass: 4n, capabilities: 256n | 2048n }));
});

test("approval uses captured guardians and never silently executes", async () => {
  const s = setup("approveRotation"), c = await capture(s);
  assert.equal(c.prepared.operation, 30);
  assert.equal(c.rotationRecord.transition.phase, 1n);
  assert.equal(c.prepared.call.data.slice(0, 10), "0xbcedafce");
  assert(!s.state.calls.some(v => v.method === "executeArtistRotation"));
  await assert.rejects(capture(setup("approveRotation", { caller: A(72) })));
});

test("execution is permissionless with quorum; zero or insufficient threshold cannot skip wait", async () => {
  const s = setup("executeRotation"), c = await capture(s);
  assert.equal(c.prepared.request.caller, A(90));
  assert.equal(c.rotationRecord.effectiveWindow, 604800n);
  await assert.rejects(capture(setup("executeRotation", { approvals: 1n })), { message: "Rotation is not executable" });
  const noQuorum = setup("executeRotation", { approvals: 0n });
  noQuorum.state.rotationRecord.guardianSetRecordHash = ZeroHash;
  noQuorum.state.rotationRecord.approvalThreshold = 0n;
  noQuorum.state.hooks.push(({ method }) => method === "guardianSet" ? [[], 0n, 0n, ZeroHash] : undefined);
  await assert.rejects(capture(noQuorum), { message: "Rotation is not executable" });
  noQuorum.state.timestamp = noQuorum.state.rotationRecord.transition.contestEndsAt;
  const mature = await capture(noQuorum);
  assert.equal(mature.timestamp, mature.rotationRecord.transition.contestEndsAt);
  assert.equal(mature.guardianSet.recordHash, ZeroHash);
  assert.equal(mature.capturedGuardianRecord, null);
  assert.equal(mature.rotationRecord.approvalThreshold, 0n);
  assert.equal(mature.rotationRecord.guardianApprovals, 0n);
  await capture(setup("executeRotation", { approvals: 0n, timestamp: 1504800n }));
});

test("pending and historical row must join exactly", async () => {
  for (const mutate of [s => { s.state.rotationRecord.terms.artistId = H("other"); }, s => { s.state.rotationRecord.transition.phase = 2n; },
    s => { s.state.rotationRecord.transition.contestedAt = 999999n; }, s => { s.state.rotationRecord.recordHash = H("other"); }]) {
    const s = setup("executeRotation"); mutate(s); await assert.rejects(capture(s));
  }
});

test("unrelated caller has no veto standing; current principal may veto with zero reason", async () => {
  await capture(setup("vetoRotation"));
  await assert.rejects(capture(setup("vetoRotation", { caller: A(99) })));
});

test("deployment chain, runtime, wiring, digest and canonical response drift fail closed", async () => {
  const chain = setup(); chain.provider.getNetwork = async () => ({ chainId: 2n }); await assert.rejects(capture(chain));
  const code = setup(); code.state.codes.set(code.deployment.registry.address, "0x60016001"); await assert.rejects(capture(code));
  const wired = setup(); wired.state.hooks.push(({ method }) => method === "operationCoordinator" ? [A(99)] : undefined); await assert.rejects(capture(wired));
  const digest = setup(); digest.state.hooks.push(({ method }) => method === "guardianSetDigest" ? [H("wrong")] : undefined); await assert.rejects(capture(digest));
  const bytes = setup(); bytes.state.hooks.push(({ method, fragment }) => method === "authorityState" ? `${bytes.encode(fragment, [bytes.state.oldAddress, 1n, 1n, H("identity")])}00` : undefined); await assert.rejects(capture(bytes));
});

test("capture rechecks block identity against a reorg", async () => {
  const s = setup(); s.state.blockHook = (tag, n) => ({ number: tag, hash: H(n === 1 ? "first" : "reorg"), timestamp: Number(s.state.timestamp) });
  await assert.rejects(capture(s));
});

test("simulation rechecks source facts and uses actual caller, zero value, and a bounded gas limit", async () => {
  const s = setup("stageRotation"), c = await capture(s);
  const result = await workflow.simulateGuardianRotation(s.provider, c, { gasLimit: 1000000n });
  assert(result.recordHash);
  const tx = s.state.calls.findLast(v => v.method === "rotateArtistAddress");
  assert.equal(tx.from, s.state.request.caller); assert.equal(tx.value, 0n); assert.equal(tx.gasLimit, 1000000n);
  s.state.failSimulation = true;
  await assert.rejects(workflow.simulateGuardianRotation(s.provider, c, { gasLimit: 1000000n }));
});

test("Safe plan binds the actual actor and never changes operation to delegatecall or execution", async () => {
  const s = setup("approveRotation"), c = await capture(s);
  const plan = workflow.createGuardianRotationSafePlan(c, { safe: s.state.request.caller, title: "Approve pending rotation" });
  assert.equal(plan.steps.length, 1);
  assert.equal(plan.steps[0].safe, s.state.request.caller);
  assert.equal(plan.steps[0].transaction.operation, 0);
  assert.equal(plan.steps[0].transaction.value, "0");
  assert.equal(plan.steps[0].transaction.data, s.prepared.call.data);
  assert.equal(plan.steps[0].transaction.to, s.deployment.registry.address);
  await assert.rejects(async () => workflow.createGuardianRotationSafePlan(c, { safe: A(99), title: "Wrong actor" }));
});

test("tampered prepared calldata cannot be captured", async () => {
  const s = setup(); s.prepared = { ...s.prepared, call: { ...s.prepared.call, value: 1n } }; await assert.rejects(capture(s));
});

test("workflow reads and event layouts match the same frozen compiler witness", () => {
  const current = new Interface(workflow.CURRENT_ARTIST_GUARDIAN_ROTATION_WORKFLOW_ABI);
  for (const f of current.fragments) {
    if (f.type === "function") {
      const expected = abi.getFunction(f.format("sighash"));
      assert(expected, f.name);
      assert.equal(f.stateMutability, expected.stateMutability, f.name);
      assert.deepEqual(f.inputs.map(v => v.format("sighash")), expected.inputs.map(v => v.format("sighash")), f.name);
      assert.deepEqual(f.outputs.map(v => v.format("sighash")), expected.outputs.map(v => v.format("sighash")), f.name);
    } else if (f.type === "event") {
      const expected = originalEvents.getEvent(f.format("sighash"));
      assert(expected, f.name);
      assert.deepEqual(f.inputs.map(v => !!v.indexed), expected.inputs.map(v => !!v.indexed), f.name);
    }
  }
});

test("prior-address candidate standing retains a nonzero judgment commitment for simulation", async () => {
  const s = setup("vetoRotation", { caller: A(99) });
  // Hashes commit full records, including absent or older judgments; they are not booleans.
  s.state.standing = [H("actual retirement"), ZeroHash, H("encoded standing judgment"), ZeroHash];
  const c = await capture(s);
  assert(c.standing.routes.includes("priorAddress"));
  assert.equal(c.standing.independentJudgmentHash, s.state.standing[2]);
  s.state.failSimulation = true; // The actual composed contract still controls judgment admission.
  await assert.rejects(workflow.simulateGuardianRotation(s.provider, c, { gasLimit: 1000000n }));
  s.state.standing[1] = H("revocation"); await assert.rejects(capture(s));
});

test("duplicate guardian approval and lifetime displacement remain exact-call simulation checks", async () => {
  for (const s of [setup("approveRotation"), setup("setGuardians", { authorityClass: 3n, capabilities: 256n })]) {
    const c = await capture(s); assert.equal(c.simulationRequired, true);
    s.state.failSimulation = true;
    await assert.rejects(workflow.simulateGuardianRotation(s.provider, c, { gasLimit: 1000000n }));
  }
});

test("simulation refuses modified captures, invalid gas and changed historical facts", async () => {
  const s = setup(), c = await capture(s);
  await assert.rejects(workflow.simulateGuardianRotation(s.provider, { ...c, timestamp: c.timestamp + 1n }, { gasLimit: 1000000n }));
  for (const gasLimit of [0n, -1n, 100000001n]) await assert.rejects(workflow.simulateGuardianRotation(s.provider, c, { gasLimit }));
  await assert.rejects(workflow.simulateGuardianRotation(s.provider, c, { gasLimit: 1000000n, blockTag: 9 }));
  s.state.principalReplay.nextUnusedNonce = 4n;
  await assert.rejects(workflow.simulateGuardianRotation(s.provider, c, { gasLimit: 1000000n }));
});

for (const kind of ["setGuardians", "stageRotation", "approveRotation", "vetoRotation", "executeRotation"]) {
  for (const execution of ["direct", "safe"]) test(`original ${kind} receipt joins Identity event, Archive preimage and ${execution} call`, async () => {
    const s = setup(kind), c = await capture(s), transactionHash = installReceipt(s, c, execution);
    const result = await workflow.inspectGuardianRotationReceipt(s.provider, c, { transactionHash, execution });
    assert.equal(result.historicalEvidenceOnly, true);
    assert.equal(result.archiveEvidence, s.state.archive.bytes);
    assert.equal(result.evidenceId, s.state.archive.evidenceId);
    assert.equal(result.recordHash, s.state.archive.archivedRecord.recordHash);
    assert.equal(result.events.length, execution === "safe" ? 3 : 2);
    if (kind === "approveRotation") { assert.equal(result.rotationRecord.transition.phase, 1n); assert.equal(result.rotationRecord.transition.executedAt, 0n); }
    if (kind === "executeRotation") assert.equal(result.rotationRecord.transition.postWindowEndsAt - result.timestamp, c.rotationRecord.effectiveWindow);
    if (kind === "vetoRotation") assert(result.causeHash && result.causeHash !== ZeroHash);
  });
}

test("receipt refuses missing or spoofed original events, failed status and changed submitted call", async () => {
  const mutations = [
    s => { s.state.receipt.status = 0; },
    s => { s.state.tx.value = 1n; },
    s => { s.state.tx.data = "0x"; },
    s => { s.state.receipt.logs[0].address = A(99); },
    s => { s.state.receipt.logs[1].address = A(99); },
    s => { s.state.receipt.logs[0].removed = true; },
    s => { s.state.receipt.logs[1].index = 0; },
    s => { s.state.receipt.logs.pop(); },
    s => { s.state.codes.set(s.state.archive.pointer, "0x00aabb"); },
  ];
  for (const mutate of mutations) {
    const s = setup("stageRotation"), c = await capture(s), transactionHash = installReceipt(s, c);
    mutate(s); await assert.rejects(workflow.inspectGuardianRotationReceipt(s.provider, c, { transactionHash, execution: "direct" }));
  }
});

test("Safe receipt refuses delegatecall and missing success independently of Registry evidence", async () => {
  for (const mutation of ["delegatecall", "missingSuccess"]) {
    const s = setup("approveRotation"), c = await capture(s), transactionHash = installReceipt(s, c, "safe");
    if (mutation === "missingSuccess") s.state.receipt.logs.pop();
    else {
      const safe = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
      const args = Array.from(safe.decodeFunctionData("execTransaction", s.state.tx.data)); args[3] = 1n;
      s.state.tx.data = safe.encodeFunctionData("execTransaction", args);
    }
    await assert.rejects(workflow.inspectGuardianRotationReceipt(s.provider, c, { transactionHash, execution: "safe" }));
  }
});

test("historical staged receipt is not confused with subsequent execution in the same block", async () => {
  const s = setup("stageRotation"), c = await capture(s), transactionHash = installReceipt(s, c);
  s.state.hooks.push(({ method, tx }) => method === "rotationRecord" && tx.blockTag === 12 ? (() => { throw Error("End-block record must not substitute for original staged archive"); })() : undefined);
  const result = await workflow.inspectGuardianRotationReceipt(s.provider, c, { transactionHash, execution: "direct" });
  assert.equal(result.rotationRecord.transition.phase, 1n);
  assert.equal(result.historicalEvidenceOnly, true);
});

function rewriteArchive(s, change) {
  const snapshot = "(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)";
  const types = ["uint16", "bytes32", "uint16", "address", "bytes32", `${snapshot}[7]`, `${snapshot}[7]`, "bytes"];
  const values = coder.decode(types, s.state.archive.bytes).toArray(true);
  change(values);
  const evidence = coder.encode(types, values), contentHash = keccak256(evidence), st = s.state;
  st.archive.bytes = evidence; st.archive.contentHash = contentHash;
  st.codes.set(st.archive.pointer, `0x00${evidence.slice(2)}`);
  const encoded = abi.encodeEventLog(abi.getEvent("ArtistArchiveEvidenceAppendedV2"), [st.archive.evidenceId, 1n, contentHash, st.archive.pointer, BigInt((evidence.length - 2) / 2)]);
  Object.assign(st.receipt.logs[1], encoded);
}

test("complete Archive validation catches rewritten unsigned guard, execution window and snapshots", async () => {
  const rotationType = abi.getFunction("rotationRecord").outputs[0].format("full");
  const terms = abi.getFunction("rotateArtistAddress").inputs[0].format("full"), auth = abi.getFunction("rotateArtistAddress").inputs[1].format("full");
  const proof = "(address signer,bytes32 digest,bool direct)";
  const cases = [
    ["stageRotation", values => {
      const types = [terms, auth, auth, proof, proof, rotationType], payload = coder.decode(types, values[7]).toArray(true);
      payload[5][1][4] = H("different unsigned guard"); values[7] = coder.encode(types, payload);
    }],
    ["executeRotation", values => {
      const types = ["bytes32", "bytes32", rotationType], payload = coder.decode(types, values[7]).toArray(true);
      payload[2][10][5] -= 1n; values[7] = coder.encode(types, payload);
    }],
    ["approveRotation", values => { values[6][2][3] = H("incorrect changed tip"); }],
    ["setGuardians", values => { values[6][2][3] = values[5][2][3]; }],
    ["vetoRotation", values => { values[6][2][1] = values[5][2][1]; }],
  ];
  for (const [kind, change] of cases) {
    const s = setup(kind), c = await capture(s), transactionHash = installReceipt(s, c);
    rewriteArchive(s, change);
    await assert.rejects(workflow.inspectGuardianRotationReceipt(s.provider, c, { transactionHash, execution: "direct" }), undefined, kind);
  }
});

test("higher operative guardian floor governs stage and its retained record", async () => {
  const s = setup("stageRotation"), r = s.state.guardianRecord;
  r.terms.minContestSeconds = 1209600n;
  r.recordHash = hash(["bytes32", "uint256", "address", "bytes32", "address[]", "uint32", "uint64", "uint256", "uint64"],
    ["0xfb979fce9edd361cf23ba8baee900f7054451db7b563ba0ab11a5ef3621cd297", 1n, s.deployment.registry.address,
      r.terms.artistId, r.terms.guardians, r.terms.approvalThreshold, r.terms.minContestSeconds, r.nonce, r.signedAt]);
  const c = await capture(s), sim = await workflow.simulateGuardianRotation(s.provider, c, { gasLimit: 1000000n });
  const transactionHash = installReceipt(s, c), receipt = await workflow.inspectGuardianRotationReceipt(s.provider, c, { transactionHash, execution: "direct" });
  assert.equal(receipt.rotationRecord.effectiveWindow, 1209600n);
  assert.equal(receipt.recordHash, sim.recordHash);
});
