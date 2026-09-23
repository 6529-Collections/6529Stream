import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { AbiCoder, Interface, ParamType, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as p from "../dist/current-artist-recovery-adjudication.js";

const fixture = JSON.parse(fs.readFileSync(new URL("./fixtures/current-artist-recovery-adjudication-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(["evidenceInterface", "selectionInterface", "recoveryV2", "executor", "evidence", "recoveryOwner", "actionOwner", "selectionOwner", "dormancy", "selection"].map(k => [k, new Interface(fixture.abis[k])])), coder = AbiCoder.defaultAbiCoder();
const h = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`, a = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const max256 = (1n << 256n) - 1n, max64 = (1n << 64n) - 1n;
const c = () => ({ chainId: max256, registry: a(1), owner: a(2), ownerCodeHash: h(3), coordinator: a(4), archive: a(5), core: a(6), mintManager: a(7), evidencePublisher: a(8), selectionPreparation: a(9) });
const request = () => ({ artistId: h(10), newAddress: a(11), vestedAuthorityClass: 1n, expectedCauseHash: h(12), expectedResolutionHash: ZeroHash, evidenceHash: h(13), reasonHash: h(14), supersededRecordHashes: [h(1), h(2)] });
const authorization = () => ({ nonce: max256, time: max64, signature: "0x" });
function manifest() { const r = request(); return { artistId: r.artistId, ownerRevision: max64, causeHash: r.expectedCauseHash, resolutionHash: r.expectedResolutionHash, executedHead: ZeroHash, basis: 0n,
  requestCommitment: p.artistRecoveryRequestCommitment(r), resolutionEvidenceHash: r.evidenceHash, contestedVestings: [], supersededRecordHashes: [...r.supersededRecordHashes] }; }
const appeal = () => ({ resolutionManifestHash: h(90), hostileFindingsHash: h(91), findings: [{ guardianRecordHash: h(1), parties: [a(10), a(11)] }, { guardianRecordHash: h(2), parties: [a(12)] }] });
function zero(type) { const q = typeof type === "string" ? ParamType.from(type) : type; if (q.baseType === "tuple") return Object.fromEntries(q.components.map(f => [f.name, zero(f)])); if (q.baseType === "array") return q.arrayLength === -1 ? [] : Array.from({ length: q.arrayLength }, () => zero(q.arrayChildren)); if (q.type === "address") return ZeroAddress; if (q.type === "bool") return false; if (q.type === "string") return ""; if (q.type === "bytes") return "0x"; if (q.type.startsWith("bytes")) return "0x" + "00".repeat(Number(q.type.slice(5))); return 0n; }
function context() { const x = zero(abi.recoveryV2.getFunction("identityRecoveryContextV2").outputs[0]); Object.assign(x, { scopeHash: p.artistRecoveryScopeHash(c(), request().artistId), oldValueHash: h(100), causeHash: request().expectedCauseHash, incumbent: a(99), postContestSeconds: 259200n, standingTailSeconds: 2592000n, timingRevision: 1n, delegationEpoch: 2n }); x.newValueHash = p.artistRecoveryIntentHash(x, request(), authorization()); return x; }
const window = () => ({ notBefore: 259300n, expiresAfter: 259300n + 604800n, reasonHash: request().reasonHash, reasonURI: "ipfs://review/☃", manifestHash: h(105) });
const hash = (types, values) => keccak256(coder.encode(types, values));

test("all explicit V2 public method shapes match their original compiler interfaces", () => {
  for (const [source, group] of [[p.CURRENT_ARTIST_RECOVERY_EVIDENCE_ABI, "evidenceInterface"], [p.CURRENT_ARTIST_RECOVERY_SELECTION_ABI, "selectionInterface"], [p.CURRENT_ARTIST_RECOVERY_ADJUDICATION_ABI, "recoveryV2"], [p.CURRENT_ARTIST_RECOVERY_GOVERNANCE_ABI, "executor"]]) new Interface(source).forEachFunction(f => assert.equal(f.format("sighash"), abi[group].getFunction(f.name).format("sighash")));
  for (const [type, witness] of [[p.ARTIST_RECOVERY_REQUEST_TUPLE, abi.recoveryV2.getFunction("recoverArtistIdentityV2").inputs[0]], [p.ARTIST_RECOVERY_CONTEXT_TUPLE, abi.recoveryV2.getFunction("identityRecoveryContextV2").outputs[0]], [p.ARTIST_RECOVERY_RECORD_TUPLE, abi.recoveryOwner.getFunction("identityRecoveryRecord").outputs[0]], [p.ARTIST_RECOVERY_ACTION_ASSOCIATION_TUPLE, abi.actionOwner.getFunction("identityRecoveryActionState").outputs[0]], [p.ARTIST_RECOVERY_SELECTION_BASIS_TUPLE, abi.selectionOwner.getFunction("recoverySelectionBasisV2").outputs[0]], [p.ARTIST_RECOVERY_NOTICE_TUPLE, abi.dormancy.getFunction("dormancyRecord").outputs[0]], [p.ARTIST_RECOVERY_TERMINAL_TUPLE, abi.dormancy.getFunction("dormancyRecord").outputs[2]]]) assert.equal(ParamType.from(type).format("sighash"), witness.format("sighash"));
});

test("request commitment omits only evidenceHash and keeps full-width original request terms", () => {
  const r = request(), expected = hash(["bytes32", "uint16", "bytes32", "address", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_GUARDIAN_APPEAL_REQUEST_V1"), 1n, r.artistId, r.newAddress, r.vestedAuthorityClass, r.expectedCauseHash, r.expectedResolutionHash, ZeroHash, r.reasonHash, r.supersededRecordHashes]);
  assert.equal(p.artistRecoveryRequestCommitment(r), expected); assert.equal(p.artistRecoveryRequestCommitment({ ...r, evidenceHash: h(999) }), expected);
  for (const patch of [{ artistId: h(99) }, { newAddress: a(99) }, { vestedAuthorityClass: 3n }, { expectedCauseHash: h(99) }, { expectedResolutionHash: h(99) }, { reasonHash: h(99) }, { supersededRecordHashes: [] }]) assert.notEqual(p.artistRecoveryRequestCommitment({ ...r, ...patch }), expected);
  assert.equal(p.encodeArtistRecoveryRequest(r), coder.encode([abi.recoveryV2.getFunction("recoverArtistIdentityV2").inputs[0]], [r]));
  assert.deepEqual(p.decodeArtistRecoveryRequest(p.encodeArtistRecoveryRequest(r)), r);
});

test("manifest grammar preserves declared execution order rather than sorting hashes", () => {
  const m = manifest(); assert.equal(p.normalizeArtistRecoveryResolutionManifest(m).executedHead, ZeroHash);
  const refs = [{ transitionRecordHash: h(9), vestingCommitment: h(8) }, { transitionRecordHash: h(4), vestingCommitment: h(3) }], declared = { ...m, basis: 1n, executedHead: h(4), contestedVestings: refs };
  assert.deepEqual(p.normalizeArtistRecoveryResolutionManifest(declared).contestedVestings, refs);
  assert.notEqual(p.artistRecoveryResolutionManifestHash(c(), declared), p.artistRecoveryResolutionManifestHash(c(), { ...declared, contestedVestings: [...refs].reverse() }));
  for (const patch of [{ artistId: ZeroHash }, { ownerRevision: 0n }, { causeHash: ZeroHash }, { requestCommitment: ZeroHash }, { resolutionEvidenceHash: ZeroHash }, { basis: 2n }, { basis: 1n }, { contestedVestings: refs }, { supersededRecordHashes: [h(2), h(1)] }, { supersededRecordHashes: [ZeroHash] }]) assert.throws(() => p.normalizeArtistRecoveryResolutionManifest({ ...m, ...patch }));
  for (const refs of [[{ transitionRecordHash: h(9), vestingCommitment: h(8) }, { transitionRecordHash: h(9), vestingCommitment: h(7) }], [{ transitionRecordHash: h(9), vestingCommitment: h(8) }, { transitionRecordHash: h(7), vestingCommitment: h(8) }], [{ transitionRecordHash: ZeroHash, vestingCommitment: h(8) }]]) assert.throws(() => p.normalizeArtistRecoveryResolutionManifest({ ...declared, contestedVestings: refs }));
  assert.throws(() => p.normalizeArtistRecoveryResolutionManifest({ ...declared, executedHead: ZeroHash }));
  const rows = Array.from({ length: 64 }, (_, i) => ({ transitionRecordHash: h(i + 1), vestingCommitment: h(i + 100) }));
  assert.equal(p.normalizeArtistRecoveryResolutionManifest({ ...declared, contestedVestings: rows }).contestedVestings.length, 64);
  assert.throws(() => p.normalizeArtistRecoveryResolutionManifest({ ...declared, contestedVestings: [...rows, { transitionRecordHash: h(999), vestingCommitment: h(999) }] }));
});

test("manifest identity binds owner runtime and full suite while appeal retains its different original preimage", () => {
  const m = manifest(), coords = c(), t = abi.evidence.getFunction("publishResolutionManifest").inputs[0];
  const expected = hash(["bytes32", "uint16", "uint256", "address", "address", "bytes32", "address", "address", "address", "address", t], [id("6529STREAM_ARTIST_RECOVERY_RESOLUTION_MANIFEST_V1"), 1n, coords.chainId, coords.registry, coords.owner, coords.ownerCodeHash, coords.coordinator, coords.archive, coords.core, coords.mintManager, m]);
  assert.equal(p.artistRecoveryResolutionManifestHash(coords, m), expected);
  for (const field of ["registry", "owner", "coordinator", "archive", "core", "mintManager"]) assert.notEqual(p.artistRecoveryResolutionManifestHash({ ...coords, [field]: a(300) }, m), expected);
  assert.notEqual(p.artistRecoveryResolutionManifestHash({ ...coords, ownerCodeHash: h(300) }, m), expected);
  assert.equal(p.artistRecoveryResolutionManifestHash({ ...coords, evidencePublisher: a(300), selectionPreparation: a(301) }, m), expected);
  const d = appeal(), appealHash = p.artistRecoveryAppealHash(coords, d);
  assert.equal(appealHash, hash(["bytes32", "uint16", "uint256", "address", "address", abi.evidence.getFunction("publishAppealV2").inputs[0]], [id("6529STREAM_ARTIST_HOSTILE_GUARDIAN_EVIDENCE_V2"), 2n, coords.chainId, coords.registry, coords.owner, d]));
  assert.equal(p.artistRecoveryAppealHash({ ...coords, ownerCodeHash: h(300), coordinator: a(302) }, d), appealHash);
});

test("appeal publication checks sorted bounded grammar without inventing a retained-manifest or semantic finding requirement", () => {
  const d = appeal(); assert.deepEqual(p.decodeArtistRecoveryAppealDocument(p.encodeArtistRecoveryAppealDocument(d)), d);
  assert.equal(p.prepareArtistRecoveryAdjudicationCall(c(), a(90), { kind: "publishAppealV2", document: d }).factsVerified, false);
  for (const patch of [{ resolutionManifestHash: ZeroHash }, { hostileFindingsHash: ZeroHash }, { findings: [] }, { findings: [...d.findings].reverse() }, { findings: [{ guardianRecordHash: h(1), parties: [] }] }, { findings: [{ guardianRecordHash: h(1), parties: [a(2), a(1)] }] }, { findings: [{ guardianRecordHash: h(1), parties: [a(1), a(1)] }] }, { findings: [{ guardianRecordHash: h(1), parties: [ZeroAddress] }] }, { findings: [{ guardianRecordHash: h(1), parties: Array.from({ length: 9 }, (_, i) => a(i + 1)) }] }]) assert.throws(() => p.normalizeArtistRecoveryAppealDocument({ ...d, ...patch }));
  const sparse = Array(1); assert.throws(() => p.normalizeArtistRecoveryAppealDocument({ ...d, findings: sparse }));
});

test("completed empty selection is explicit and has nonzero original commitment", () => {
  const basis = { manifestHash: h(1), artistId: h(2), ownerCodeHash: c().ownerCodeHash, history: { count: 0n, ownerRevision: 0n, commitment: ZeroHash }, sourceCommitment: h(3) }, progress = { ...zero(p.ARTIST_RECOVERY_SELECTION_PROGRESS_TUPLE), complete: true };
  const result = p.artistRecoverySelectionResult(c(), basis, progress), key = hash(["bytes32", "uint256", "address", "address", abi.selectionOwner.getFunction("recoverySelectionBasisV2").outputs[0]], [id("6529STREAM_ARTIST_GUARDIAN_SELECTION_SOURCE_V2"), c().chainId, c().registry, c().owner, basis]);
  assert.equal(result.sourceKey, key); assert.notEqual(result.commitment, ZeroHash); assert.equal(result.selectedRecordHash, ZeroHash);
  assert.equal(result.commitment, hash(["bytes32", "bytes32", p.ARTIST_RECOVERY_SELECTION_BASIS_TUPLE, p.ARTIST_RECOVERY_SELECTION_PROGRESS_TUPLE], [id("6529STREAM_ARTIST_GUARDIAN_SELECTION_RESULT_V2"), key, basis, progress]));
  assert.throws(() => p.artistRecoverySelectionResult(c(), basis, { ...progress, complete: false }));
  assert.throws(() => p.artistRecoverySelectionResult(c(), basis, { ...progress, selectedNonce: 1n }));
  assert.throws(() => p.artistRecoverySelectionResult(c(), { ...basis, history: { ...basis.history, ownerRevision: 1n } }, progress));
  const completed = { ...basis, history: { count: 20n, ownerRevision: 100n, commitment: h(8) } }, scanned = { ...progress, processed: 20n, lastOwnerRevision: 100n, historyTip: h(8), selectedRecordHash: h(9), selectedDataHash: h(10), selectedNonce: max256 };
  assert.equal(p.artistRecoverySelectionResult(c(), completed, scanned).selectedNonce, max256);
});

test("every public stage retains its actual target/caller and exact original calldata", () => {
  const r = request(), acceptance = authorization(), mh = h(90), ctx = context(), batch = p.artistRecoveryGovernanceBatch(c(), r, acceptance, mh, ctx, a(50), max256, window());
  const rows = [
    [{ kind: "publishResolutionManifest", manifest: manifest() }, "evidence", c().evidencePublisher, [manifest()]],
    [{ kind: "resolutionManifest", manifestHash: mh }, "evidence", c().evidencePublisher, [mh]],
    [{ kind: "publishAppealV2", document: appeal() }, "evidence", c().evidencePublisher, [appeal()]],
    [{ kind: "appealEvidenceV2", documentHash: h(91) }, "evidence", c().evidencePublisher, [h(91)]],
    [{ kind: "beginSelectionV2", manifestHash: mh }, "selection", c().selectionPreparation, [mh]],
    [{ kind: "continueSelectionV2", key: h(92), maximumRecords: max64 }, "selection", c().selectionPreparation, [h(92), max64]],
    [{ kind: "requireSelectionV2", manifestHash: mh }, "selection", c().selectionPreparation, [mh]],
    [{ kind: "selectionV2", key: ZeroHash }, "selection", c().selectionPreparation, [ZeroHash]],
    [{ kind: "retainedMemberV2", key: h(92), actor: ZeroAddress }, "selection", c().selectionPreparation, [h(92), ZeroAddress]],
    [{ kind: "identityRecoveryContextV2", request: r, acceptance, manifestHash: mh }, "recoveryV2", c().registry, [r, acceptance, mh]],
    [{ kind: "recoverArtistIdentityV2", request: r, acceptance, manifestHash: mh }, "recoveryV2", c().registry, [r, acceptance, mh]],
    [{ kind: "registerIdentityRecoveryActionV2", actionId: batch.actionId, calls: [batch.governanceCall], request: r, acceptance, manifestHash: mh }, "recoveryV2", c().registry, [batch.actionId, [batch.governanceCall], r, acceptance, mh]],
    [{ kind: "identityRecoveryEvidenceState", artistId: r.artistId, actionId: ZeroHash }, "recoveryV2", c().registry, [r.artistId, ZeroHash]],
  ];
  for (const [input, group, target, args] of rows) { const call = p.prepareArtistRecoveryAdjudicationCall(c(), a(70), input); assert.equal(call.caller, a(70)); assert.equal(call.call.to, target); assert.equal(call.call.value, 0n); assert.equal(call.call.data, abi[group].encodeFunctionData(input.kind, args)); assert.equal(call.factsVerified, false); assert.deepEqual(p.normalizeArtistRecoveryAdjudicationCall(call), call); }
  assert.throws(() => p.prepareArtistRecoveryAdjudicationCall(c(), a(70), { kind: "continueSelectionV2", key: h(92), maximumRecords: 0n }));
  assert.throws(() => p.prepareArtistRecoveryAdjudicationCall(c(), a(70), { kind: "recoverArtistIdentity", request: r, acceptance }));
});

test("new-side acceptance keeps the exact original Registry domain and excludes reason, evidence and manifest", () => {
  const r = request(), auth = authorization(), oldAddress = context().incumbent;
  const payload = p.artistRecoveryAcceptancePayload(c().chainId, c().registry, r, oldAddress, auth), fields = "bytes32 artistId,address oldAddress,address newAddress,uint256 nonce,uint64 deadline".split(",").map(x => { const [type, name] = x.split(" "); return { type, name }; });
  assert.equal(payload.digest, TypedDataEncoder.hash({ name: "6529StreamArtistRegistry", version: "1", chainId: c().chainId, verifyingContract: c().registry }, { StreamArtistRotationAcceptance: fields }, { artistId: r.artistId, oldAddress, newAddress: r.newAddress, nonce: auth.nonce, deadline: auth.time }));
  assert.equal(TypedDataEncoder.from({ StreamArtistRotationAcceptance: fields }).encodeType("StreamArtistRotationAcceptance"), "StreamArtistRotationAcceptance(bytes32 artistId,address oldAddress,address newAddress,uint256 nonce,uint64 deadline)");
  for (const patch of [{ reasonHash: h(99) }, { evidenceHash: h(99) }, { expectedCauseHash: h(99) }, { supersededRecordHashes: [] }]) assert.equal(p.artistRecoveryAcceptancePayload(c().chainId, c().registry, { ...r, ...patch }, oldAddress, auth).digest, payload.digest);
  assert.notEqual(p.artistRecoveryAcceptancePayload(c().chainId, c().owner, r, oldAddress, auth).digest, payload.digest);
  for (const signature of ["0x", "0x12", "0x" + "11".repeat(64), "0x" + "11".repeat(65), "0x" + "11".repeat(4096)]) assert.equal(p.artistRecoveryAcceptancePayload(c().chainId, c().registry, r, oldAddress, { ...auth, signature }).digest, payload.digest);
  assert.throws(() => p.normalizeArtistRecoveryAuthorization({ ...auth, signature: "0x" + "11".repeat(4097) }));
});

test("original operation35 record, supersessions and vesting commitments preserve their separate preimages", () => {
  const fields = { artistId: h(10), oldAddress: a(99), newAddress: a(11), vestedAuthorityClass: 1n, evidenceHash: h(13), reasonHash: h(14), supersededRecordsHash: p.artistRecoverySupersededRecordsHash([]), governanceActionId: h(30), recoveredAt: max64 };
  assert.notEqual(fields.supersededRecordsHash, ZeroHash);
  assert.equal(fields.supersededRecordsHash, hash(["bytes32", "bytes32[]"], ["0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae", []]));
  assert.equal(p.artistRecoveryRecordHash(c().chainId, c().registry, fields), hash(["bytes32", "uint256", "address", abi.recoveryOwner.getFunction("identityRecoveryRecord").outputs[0].components[1]], ["0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff", c().chainId, c().registry, fields]));
  const v = { ...zero(p.ARTIST_RECOVERY_VESTING_TUPLE), artistId: fields.artistId, transitionRecordHash: h(40), operationId: 35n, ownerRevision: max64, executedAt: max64, oldAddress: fields.oldAddress, newAddress: fields.newAddress, authorityClass: 1n };
  const expected = hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "uint16", "uint64", "uint64", "address", "address", "uint8", p.ARTIST_RECOVERY_HISTORY_HEAD_TUPLE, "bytes32", "bytes32"], [id("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"), c().chainId, c().registry, c().owner, v.artistId, v.transitionRecordHash, v.operationId, v.ownerRevision, v.executedAt, v.oldAddress, v.newAddress, v.authorityClass, v.guardians, v.previousTransitionRecordHash, v.previousCommitment]);
  assert.equal(p.artistRecoveryVestingCommitment(c(), v), expected); assert.equal(p.artistRecoveryVestingCommitment(c(), { ...v, commitment: h(999) }), expected);
});

test("current notice tags preserve the old no-notice bytes and distinguish source from context", () => {
  const empty = zero(p.ARTIST_RECOVERY_CURRENT_NOTICE_FACTS_TUPLE), original = h(90);
  assert.equal(p.artistRecoveryCurrentNoticeContextHash(original, empty), original); assert.equal(p.artistRecoveryCurrentNoticeSourceHash(original, empty), original);
  const facts = { ...empty, notice: { ...empty.notice, recordHash: h(99), terms: { artistId: h(10), evidenceHash: h(20), reasonURI: "original notice ☃" } }, phase: 1n, activity: max256, proof: h(200) };
  const expected = hash(["bytes32", "bytes32", p.ARTIST_RECOVERY_CURRENT_NOTICE_FACTS_TUPLE], [id("6529STREAM_ARTIST_RECOVERY_CURRENT_NOTICE_CONTEXT_V1"), original, facts]);
  assert.equal(p.artistRecoveryCurrentNoticeContextHash(original, facts), expected); assert.notEqual(p.artistRecoveryCurrentNoticeSourceHash(original, facts), expected);
  assert.notEqual(p.artistRecoveryCurrentNoticeContextHash(original, { ...facts, activity: max256 - 1n }), expected);
  const terminal = { ...empty.cancellation, noticeHash: facts.notice.recordHash, actor: a(11), authorityClass: 1n, observedAt: 900n };
  const cancellation = p.artistRecoveryCancellationHash(c(), terminal, 3n);
  assert.equal(cancellation, hash(["bytes32", "uint256", "address", "address", p.ARTIST_RECOVERY_TERMINAL_TUPLE, "uint256"], [id("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"), c().chainId, c().registry, c().owner, terminal, 3n]));
  assert.equal(p.artistRecoveryCancellationHash(c(), { ...terminal, recordHash: cancellation }, 3n), cancellation);
  assert.throws(() => p.artistRecoveryCancellationHash(c(), { ...terminal, actionId: h(55) }, 3n));
});

test("base and tagged Archive codecs preserve inactive branches and all original before/after notice observations", () => {
  const prep = zero(p.ARTIST_RECOVERY_PREPARATION_PAYLOAD_TUPLE), exec = zero(p.ARTIST_RECOVERY_EXECUTION_PAYLOAD_TUPLE), notice = zero(p.ARTIST_RECOVERY_NOTICE_EVIDENCE_TUPLE);
  prep.request = request(); prep.acceptance = authorization(); prep.evidence.manifest = manifest(); exec.request = request(); exec.acceptance = authorization(); exec.evidence.manifest = manifest();
  const prepType = ParamType.from(p.ARTIST_RECOVERY_PREPARATION_PAYLOAD_TUPLE), prepBytes = p.encodeArtistRecoveryPreparationPayload(prep);
  assert.equal(prepBytes, coder.encode(prepType.components, prepType.components.map(f => prep[f.name]))); // Original multi-argument encoding, no extra dynamic tuple offset.
  assert.deepEqual(p.decodeArtistRecoveryPreparationPayload(prepBytes), prep);
  assert.equal(p.encodeArtistRecoveryPreparationEvidence({ payload: prep, notice: null }), prepBytes);
  const withNotice = p.encodeArtistRecoveryPreparationEvidence({ payload: prep, notice });
  assert.equal(withNotice, coder.encode(["bytes32", "bytes", "bytes"], [p.ARTIST_RECOVERY_PREPARATION_NOTICE_TAG, prepBytes, p.encodeArtistRecoveryNoticeEvidence(notice)]));
  assert.deepEqual(p.decodeArtistRecoveryPreparationEvidence(withNotice), { payload: prep, notice });
  const after = { ...notice, phase: 2n, terminal: { ...notice.terminal, recordHash: h(101), actor: a(11), observedAt: max64 } }, wrapped = { payload: exec, noticeBefore: notice, noticeAfter: after };
  assert.deepEqual(p.decodeArtistRecoveryExecutionEvidence(p.encodeArtistRecoveryExecutionEvidence(wrapped)), wrapped);
  assert.equal(p.encodeArtistRecoveryExecutionEvidence({ payload: exec, noticeBefore: null, noticeAfter: null }), p.encodeArtistRecoveryExecutionPayload(exec));
  assert.throws(() => p.encodeArtistRecoveryExecutionEvidence({ payload: exec, noticeBefore: notice, noticeAfter: null }));
  assert.throws(() => p.decodeArtistRecoveryPreparationEvidence(withNotice + "00".repeat(32)));
  const ownerSnapshot = { domainId: h(3), revision: max64, stateRoot: h(4), recordChainTip: h(5) }, envelope = { schemaVersion: 1n, configurationHash: h(1), operation: 65534n, actor: a(50), primaryRecordHash: ZeroHash, before: Array(7).fill(ownerSnapshot), after: Array(7).fill(ownerSnapshot), payload: withNotice };
  assert.deepEqual(p.decodeArtistRecoveryOperationEvidence(p.encodeArtistRecoveryOperationEvidence(envelope)), envelope);
  assert.throws(() => p.encodeArtistRecoveryOperationEvidence({ ...envelope, primaryRecordHash: h(1) }));
  assert.throws(() => p.encodeArtistRecoveryOperationEvidence({ ...envelope, before: [ownerSnapshot] }));
});

test("original class2 governance binds V2 manifest and supplemental reason, including registration-time delay", () => {
  const r = request(), a_ = authorization(), x = context(), m = h(90), b = p.artistRecoveryGovernanceBatch(c(), r, a_, m, x, a(50), max256, window());
  assert.equal(b.targetCall.data, abi.recoveryV2.encodeFunctionData("recoverArtistIdentityV2", [r, a_, m]));
  assert.equal(b.actionClass, 2n); assert.equal(b.factsVerified, false);
  assert.equal(b.publicationCall.data, abi.executor.encodeFunctionData("publishGovernanceCallData", [[b.targetCall.data]]));
  assert.equal(b.executionCall.data, abi.executor.encodeFunctionData("executeGovernanceBatch", [b.actionId, [b.governanceCall], [b.targetCall.data]]));
  assert.notEqual(p.artistRecoveryGovernanceBatch(c(), r, a_, h(91), x, a(50), max256, window()).actionId, b.actionId);
  assert.notEqual(b.scopeHash, x.scopeHash); assert.equal(b.governanceCall.scopeHash, x.scopeHash);
  assert.deepEqual(p.normalizeArtistRecoveryGovernanceBatch(b), b);
  p.assertArtistRecoveryRegistrationWindow(a_, window(), 100n, 259200n);
  assert.throws(() => p.assertArtistRecoveryRegistrationWindow(a_, window(), 101n, 259200n));
  assert.throws(() => p.assertArtistRecoveryRegistrationWindow({ ...a_, time: window().notBefore - 1n }, window(), 100n, 259200n));
  assert.throws(() => p.assertArtistRecoveryRegistrationWindow(a_, window(), 100n, 259199n));
  assert.throws(() => p.artistRecoveryGovernanceBatch(c(), r, a_, m, { ...x, newValueHash: h(2) }, a(50), 0n, window()));
  assert.throws(() => p.artistRecoveryGovernanceBatch(c(), r, a_, m, x, a(50), 0n, { ...window(), reasonHash: h(2) }));
});

test("strict source widths, bounded canonical decoding and nested snapshots reject mutable or manufactured plans", () => {
  const coords = c(), m = manifest(), input = { kind: "publishResolutionManifest", manifest: m }, plan = p.prepareArtistRecoveryAdjudicationCall(coords, a(50), input);
  coords.ownerCodeHash = h(900); m.supersededRecordHashes.push(h(999)); m.causeHash = h(900);
  assert.equal(plan.coordinates.ownerCodeHash, h(3)); assert.equal(plan.input.manifest.causeHash, h(12)); assert.equal(plan.input.manifest.supersededRecordHashes.length, 2);
  assert.throws(() => { plan.input.manifest.supersededRecordHashes.push(h(999)); });
  for (const patch of [{ factsVerified: true }, { expectedReturnHash: h(999) }, { call: { ...plan.call, value: 1n } }, { caller: a(999), call: { ...plan.call, to: a(999) } }]) assert.throws(() => p.normalizeArtistRecoveryAdjudicationCall({ ...plan, ...patch }));
  for (const patch of [{ ownerRevision: 1 }, { ownerRevision: max64 + 1n }, { injected: true }]) assert.throws(() => p.normalizeArtistRecoveryResolutionManifest({ ...manifest(), ...patch }));
  assert.throws(() => p.normalizeArtistRecoveryAdjudicationCoordinates({ ...c(), chainId: 1 }));
  assert.throws(() => p.normalizeArtistRecoveryAdjudicationCoordinates({ ...c(), owner: c().registry }));
  const encoded = p.encodeArtistRecoveryResolutionManifest(manifest()); assert.throws(() => p.decodeArtistRecoveryResolutionManifest(encoded + "00".repeat(32))); assert.throws(() => p.decodeArtistRecoveryResolutionManifest(encoded.slice(0, -2)));
  const notice = zero(p.ARTIST_RECOVERY_NOTICE_TUPLE); assert.throws(() => p.normalizeArtistRecoveryNotice({ ...notice, terms: { ...notice.terms, reasonURI: "\udc00" } }));
  assert.throws(() => p.normalizeArtistRecoveryNotice({ ...notice, terms: { ...notice.terms, reasonURI: "😀".repeat(513) } }));
});

test("the explicit client byte ceiling applies to the complete envelope and precedes tagged ABI decoding", () => {
  const snapshot = { domainId: h(1), revision: 0n, stateRoot: h(2), recordChainTip: h(3) }, envelope = { schemaVersion: 1n, configurationHash: h(4), operation: 35n, actor: a(5), primaryRecordHash: h(6), before: Array(7).fill(snapshot), after: Array(7).fill(snapshot), payload: "0x" };
  const overhead = (p.encodeArtistRecoveryOperationEvidence(envelope).length - 2) / 2, maximumPayload = p.ARTIST_RECOVERY_CODEC_MAX_BYTES - overhead;
  const exact = { ...envelope, payload: "0x" + "00".repeat(maximumPayload) }, encoded = p.encodeArtistRecoveryOperationEvidence(exact);
  assert.equal((encoded.length - 2) / 2, p.ARTIST_RECOVERY_CODEC_MAX_BYTES); assert.deepEqual(p.decodeArtistRecoveryOperationEvidence(encoded), exact);
  assert.throws(() => p.encodeArtistRecoveryOperationEvidence({ ...exact, payload: exact.payload + "00" }), /Complete encoding exceeds client bound/);
  for (const [tag, decode] of [[p.ARTIST_RECOVERY_PREPARATION_NOTICE_TAG, p.decodeArtistRecoveryPreparationEvidence], [p.ARTIST_RECOVERY_EXECUTION_NOTICE_TAG, p.decodeArtistRecoveryExecutionEvidence]]) assert.throws(() => decode(tag + "00".repeat(p.ARTIST_RECOVERY_CODEC_MAX_BYTES - 31)), /Complete encoding exceeds client bound/);
});
