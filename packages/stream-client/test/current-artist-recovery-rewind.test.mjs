import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as p from "../dist/current-artist-recovery-rewind.js";
import * as v2 from "../dist/current-artist-recovery-adjudication.js";

const fixture = JSON.parse(fs.readFileSync(new URL("./fixtures/current-artist-recovery-rewind-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(["evidence", "selection", "recoveryV3", "recoveryOwnerV3", "payoutOwnerV3", "executor"].map(k => [k, new Interface(fixture.abis[k])])), coder = AbiCoder.defaultAbiCoder();
const h = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`, a = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`), max64 = (1n << 64n) - 1n, max256 = (1n << 256n) - 1n;
const coords = () => ({ chainId: max256, registry: a(1), identityOwner: a(2), identityCodeHash: h(3), payoutOwner: a(4), payoutCodeHash: h(5), coordinator: a(6), archive: a(7), core: a(8), manager: a(9), evidencePublisher: a(10), selectionPreparation: a(11) });
const request = () => ({ artistId: h(100), newAddress: a(12), vestedAuthorityClass: 1n, expectedCauseHash: h(102), expectedResolutionHash: ZeroHash, evidenceHash: h(103), reasonHash: h(104), supersededRecordHashes: Array.from({ length: 7 }, (_, i) => h(i + 1)) });
const authorization = () => ({ nonce: max256, time: max64, signature: "0x" });
function zero(type) { const q = typeof type === "string" ? ParamType.from(type) : type; if (q.baseType === "tuple") return Object.fromEntries(q.components.map(f => [f.name, zero(f)])); if (q.baseType === "array") return q.arrayLength === -1 ? [] : Array.from({ length: q.arrayLength }, () => zero(q.arrayChildren)); if (q.type === "address") return ZeroAddress; if (q.type === "bool") return false; if (q.type === "string") return ""; if (q.type === "bytes") return "0x"; if (q.type.startsWith("bytes")) return `0x${"00".repeat(Number(q.type.slice(5)))}`; return 0n; }
function manifest() { const r = request(); return { artistId: r.artistId, identity: { snapshot: { domainId: id("domain:identity_authority"), revision: 1n, stateRoot: h(110), recordChainTip: h(111) }, receiptCount: 9n }, payout: { snapshot: { domainId: id("domain:payout_lifecycle"), revision: 0n, stateRoot: h(112), recordChainTip: h(113) }, receiptCount: max256 }, causeHash: r.expectedCauseHash, resolutionHash: r.expectedResolutionHash, executedHead: ZeroHash, basis: 0n, requestCommitment: p.artistRecoveryRewindRequestCommitment(r), resolutionEvidenceHash: r.evidenceHash, contestedVestings: [], supersededRecords: r.supersededRecordHashes.map((recordHash, i) => ({ kind: BigInt(6 - i), recordHash })) }; }
function original() { const v = { recordHash: ZeroHash, terms: { artistId: h(100), payoutAccount: a(20), previousDesignationRecordHash: ZeroHash }, signer: a(21), authorityClass: 3n, nonce: 0n, signedAt: max64 }; v.recordHash = p.artistRecoveryRewindPayoutRecordHash(coords(), v); return v; }
function context() { const c = zero(v2.ARTIST_RECOVERY_CONTEXT_TUPLE); Object.assign(c, { scopeHash: p.artistRecoveryRewindScopeHash(coords(), request().artistId), oldValueHash: h(200), causeHash: request().expectedCauseHash, incumbent: a(22), postContestSeconds: 259200n, standingTailSeconds: 2592000n, timingRevision: 1n, delegationEpoch: 2n }); c.newValueHash = p.artistRecoveryRewindIntentHash(c, request(), authorization()); return c; }
const window = () => ({ notBefore: 300000n, expiresAfter: 904800n, reasonHash: request().reasonHash, reasonURI: "ipfs://reason/雪", manifestHash: h(201) });
const hash = (types, values) => keccak256(coder.encode(types, values));
function selected() {
  const c = coords(), m = manifest(), b = zero(p.ARTIST_RECOVERY_REWIND_SELECTION_BASIS_TUPLE);
  Object.assign(b.identity, { manifestHash: p.artistRecoveryRewindManifestHash(c, m), artistId: m.artistId, ownerCodeHash: c.identityCodeHash, identity: m.identity, sourceCommitment: h(210) });
  b.payoutCodeHash = c.payoutCodeHash; b.payout = m.payout; b.sourceCommitment = p.artistRecoveryRewindSelectionSourceHash(c, b);
  const key = p.artistRecoveryRewindSelectionKey(c, b), r = zero(p.ARTIST_RECOVERY_REWIND_SELECTION_RESULT_TUPLE);
  Object.assign(r, { sourceKey: key, manifestHash: b.identity.manifestHash, sourceCommitment: b.sourceCommitment, inventoryCommitment: p.artistRecoveryRewindSelectionInventoryHash(c, b.identity.inventory, b.payoutInventory) });
  r.guardians.sourceKey = key; r.guardians.commitment = p.artistRecoveryRewindGuardianResultHash(c, b.identity.guardianHistory, r.guardians); r.commitment = p.artistRecoveryRewindSelectionResultHash(c, r);
  const progress = { identityProcessed: m.identity.receiptCount, payoutProcessed: m.payout.receiptCount, guardiansProcessed: 0n, seenExclusions: 127n, identityScanCommitment: h(211), payoutScanCommitment: h(212), complete: true, resultCommitment: r.commitment };
  return { c, m, b, r, progress, key };
}

test("seven family exclusions preserve global original order and all original35 commitments", () => {
  const m = manifest(), r = request(), partitions = p.artistRecoveryRewindPartition(r, m.supersededRecords);
  assert.deepEqual(partitions, [[h(7)], [h(6)], [h(5)], [h(4)], [h(3)], [h(2)], [h(1)]]);
  assert.equal(p.artistRecoveryRewindSupersededRecordsHash(r.supersededRecordHashes), v2.artistRecoverySupersededRecordsHash(r.supersededRecordHashes));
  assert.equal(p.artistRecoveryRewindRequestCommitment({ ...r, evidenceHash: h(900) }), p.artistRecoveryRewindRequestCommitment(r));
  assert.throws(() => p.artistRecoveryRewindPartition(r, m.supersededRecords.slice(1)));
  assert.throws(() => p.artistRecoveryRewindPartition(r, [...m.supersededRecords].reverse()));
  assert.throws(() => p.artistRecoveryRewindPartition(r, [{ kind: 7n, recordHash: h(1) }, ...m.supersededRecords.slice(1)]));
  assert.throws(() => partitions[0].push(h(3)), TypeError);
  const nonGuardian = { ...r, supersededRecordHashes: [h(1)] };
  assert.deepEqual(p.artistRecoveryRewindPartition(nonGuardian, [{ kind: 4n, recordHash: h(1) }])[0], []);
});

test("manifest permits untouched Payout revision0/full receipt widths and preserves chronological vestings", () => {
  const m = manifest(), d = { ...m, basis: 1n, executedHead: h(302), contestedVestings: [{ transitionRecordHash: h(302), vestingCommitment: h(304) }, { transitionRecordHash: h(301), vestingCommitment: h(303) }] };
  assert.deepEqual(p.decodeArtistRecoveryRewindResolutionManifest(p.encodeArtistRecoveryRewindResolutionManifest(m)), m);
  assert.deepEqual(p.normalizeArtistRecoveryRewindResolutionManifest(d).contestedVestings, d.contestedVestings);
  assert.notEqual(p.artistRecoveryRewindManifestHash(coords(), d), p.artistRecoveryRewindManifestHash(coords(), { ...d, contestedVestings: [...d.contestedVestings].reverse() }));
  for (const bad of [{ ...m, identity: { ...m.identity, snapshot: { ...m.identity.snapshot, revision: 0n } } }, { ...m, payout: { ...m.payout, snapshot: { ...m.payout.snapshot, domainId: m.identity.snapshot.domainId } } }, { ...m, payout: { ...m.payout, snapshot: { ...m.payout.snapshot, stateRoot: ZeroHash } } }, { ...m, basis: 1n }, { ...d, contestedVestings: [d.contestedVestings[0], d.contestedVestings[0]] }, { ...m, supersededRecords: [...m.supersededRecords].sort((x, y) => Number(x.kind - y.kind)) }]) assert.throws(() => p.normalizeArtistRecoveryRewindResolutionManifest(bad));
  assert.throws(() => p.normalizeArtistRecoveryRewindResolutionManifest({ ...m, payout: { ...m.payout, receiptCount: max256 + 1n } }));
});

test("complete Environment including both owner runtimes binds V3 identity while helper addresses do not", () => {
  const c = coords(), e = p.artistRecoveryRewindEnvironment(c), m = manifest(), computed = p.artistRecoveryRewindManifestHash(e, m), witness = abi.evidence.getFunction("publishResolutionManifestV3").inputs[0];
  assert.equal(computed, hash(["bytes32", "uint16", p.ARTIST_RECOVERY_REWIND_ENVIRONMENT_TUPLE, witness], [id("6529STREAM_ARTIST_RECOVERY_RESOLUTION_MANIFEST_V3"), 3n, e, m]));
  assert.equal(computed, p.artistRecoveryRewindManifestHash({ ...c, evidencePublisher: a(99), selectionPreparation: a(98) }, m));
  for (const patch of [{ chainId: c.chainId - 1n }, { identityCodeHash: h(999) }, { payoutCodeHash: h(999) }, { payoutOwner: a(99) }, { coordinator: a(99) }, { registry: a(99) }]) assert.notEqual(computed, p.artistRecoveryRewindManifestHash({ ...e, ...patch }, m));
  assert.throws(() => p.normalizeArtistRecoveryRewindCoordinates({ ...c, payoutOwner: c.identityOwner }));
  assert.throws(() => p.artistRecoveryRewindManifestHash({ ...c, surprise: 1n }, m));
});

test("original payout publication uses original18 signer/class/time and separate recordHash lookup", () => {
  const c = coords(), o = original(), expected = hash(["bytes32", "uint256", "address", "bytes32", "address", "bytes32", "address", "uint8", "uint256", "uint64"], [id("6529STREAM_ARTIST_PAYOUT_DESIGNATION_RECORD_V1"), c.chainId, c.registry, o.terms.artistId, o.terms.payoutAccount, o.terms.previousDesignationRecordHash, o.signer, o.authorityClass, 0n, max64]);
  assert.equal(o.recordHash, expected);
  const write = p.prepareArtistRecoveryRewindCall(c, a(50), { kind: "publishPayoutOriginalV3", original: o });
  assert.notEqual(write.expectedReturnHash, o.recordHash); assert.equal(write.call.to, c.evidencePublisher);
  assert.equal(write.call.data, abi.evidence.encodeFunctionData("publishPayoutOriginalV3", [o]));
  const read = p.prepareArtistRecoveryRewindCall(c, a(50), { kind: "payoutOriginalV3", recordHash: o.recordHash });
  assert.equal(read.call.data, abi.evidence.encodeFunctionData("payoutOriginalV3", [expected]));
  for (const patch of [{ recordHash: h(1) }, { authorityClass: 2n }, { signedAt: 0n }, { signer: ZeroAddress }, { nonce: 1n }]) assert.throws(() => p.artistRecoveryRewindPayoutOriginalHash(c, { ...o, ...patch }));
});

test("appeal publication grammar retains sorted findings/parties without implying stored manifest or findings semantics", () => {
  const d = { resolutionManifestHash: h(999), hostileFindingsHash: h(998), findings: [{ guardianRecordHash: h(1), parties: [a(1), a(2)] }] };
  assert.deepEqual(p.decodeArtistRecoveryRewindAppealDocument(p.encodeArtistRecoveryRewindAppealDocument(d)), d);
  assert.equal(p.prepareArtistRecoveryRewindCall(coords(), a(20), { kind: "publishAppealV3", document: d }).factsVerified, false);
  for (const patch of [{ findings: [] }, { hostileFindingsHash: ZeroHash }, { findings: [{ guardianRecordHash: h(1), parties: [a(2), a(1)] }] }, { findings: [d.findings[0], d.findings[0]] }]) assert.throws(() => p.normalizeArtistRecoveryRewindAppealDocument({ ...d, ...patch }));
});

test("complete two-owner checkpoint joins include all counts and a nonzero empty guardian result", () => {
  const { c, m, b, r, progress, key } = selected();
  assert.deepEqual(p.validateArtistRecoveryRewindSelection(c, m, b, progress, r), { key, commitment: r.commitment, factsVerified: false });
  assert.equal(r.guardians.selectedRecordHash, ZeroHash); assert.notEqual(r.guardians.commitment, ZeroHash);
  assert.equal(p.artistRecoveryRewindSelectionSourceHash(c, { ...b, sourceCommitment: h(77) }), b.sourceCommitment);
  assert.notEqual(p.artistRecoveryRewindSelectionKey(c, { ...b, sourceCommitment: h(77) }), key);
  for (const patch of [{ complete: false }, { payoutProcessed: 0n }, { identityProcessed: progress.identityProcessed - 1n }, { guardiansProcessed: 1n }, { seenExclusions: 126n }, { resultCommitment: ZeroHash }]) assert.throws(() => p.validateArtistRecoveryRewindSelection(c, m, b, { ...progress, ...patch }, r));
  assert.throws(() => p.validateArtistRecoveryRewindSelection(c, m, b, progress, { ...r, guardians: { ...r.guardians, commitment: ZeroHash } }));
  assert.throws(() => p.validateArtistRecoveryRewindSelection(c, m, { ...b, payoutCodeHash: h(70) }, progress, r));
});

test("standing scope canonical order is address/retirement, while immutable original records retain historical classes", () => {
  const { c, m, b, r, progress } = selected();
  const row = zero(p.ARTIST_RECOVERY_REWIND_STANDING_SELECTION_TUPLE);
  const valid = { ...r, standing: [{ ...row, priorAddress: a(2), retirementHash: h(9) }, { ...row, priorAddress: a(3), retirementHash: h(1) }] };
  valid.commitment = p.artistRecoveryRewindSelectionResultHash(c, valid);
  p.validateArtistRecoveryRewindSelection(c, m, b, { ...progress, resultCommitment: valid.commitment }, valid);
  const wrong = { ...valid, standing: [...valid.standing].reverse() }; wrong.commitment = p.artistRecoveryRewindSelectionResultHash(c, wrong);
  assert.throws(() => p.validateArtistRecoveryRewindSelection(c, m, b, { ...progress, resultCommitment: wrong.commitment }, wrong));
  const revision = { ...zero(p.ARTIST_RECOVERY_REWIND_IDENTITY_REVISION_RECORD_TUPLE), recordHash: h(5), authorityClass: 1n };
  assert.equal(p.decodeArtistRecoveryRewindIdentityRevisionRecord(p.encodeArtistRecoveryRewindIdentityRevisionRecord(revision)).authorityClass, 1n);
  const grant = zero(p.ARTIST_RECOVERY_REWIND_SANCTION_GRANT_RECORD_TUPLE); grant.recordHash = h(8); grant.terms.granted = false;
  assert.equal(p.decodeArtistRecoveryRewindSanctionGrantRecord(p.encodeArtistRecoveryRewindSanctionGrantRecord(grant)).recordHash, h(8));
});

test("continuations retain distinct zero-own-field versus flattened-omission recipes", () => {
  const e = p.artistRecoveryRewindEnvironment(coords());
  for (const [kind, domain, own] of [["Revision", "REVISION", "continuationHash"], ["Standing", "STANDING", "continuationHash"], ["Capability", "CAPABILITY", "commitment"]]) {
    const type = p[`ARTIST_RECOVERY_REWIND_${domain}_CONTINUATION_TUPLE`], c = zero(type); c.artistId = h(1); c[own] = h(99); if ("ownerRevision" in c) c.ownerRevision = max64;
    const fields = ParamType.from(type).components.filter(f => f.name !== own);
    const expected = hash(["bytes32", "uint16", p.ARTIST_RECOVERY_REWIND_ENVIRONMENT_TUPLE, ...fields], [id(`6529STREAM_ARTIST_RECOVERY_${domain}_CONTINUATION_V3`), 3n, e, ...fields.map(f => c[f.name])]);
    assert.equal(p[`artistRecoveryRewind${kind}ContinuationHash`](e, c), expected);
    assert.equal(p[`artistRecoveryRewind${kind}ContinuationHash`](e, { ...c, [own]: h(100) }), expected);
  }
  const c = zero(p.ARTIST_RECOVERY_REWIND_PAYOUT_CONTINUATION_TUPLE); c.artistId = h(1); c.continuationHash = h(99); c.payoutOwnerRevision = max64;
  const expected = hash(["bytes32", "uint16", p.ARTIST_RECOVERY_REWIND_ENVIRONMENT_TUPLE, p.ARTIST_RECOVERY_REWIND_PAYOUT_CONTINUATION_TUPLE], [id("6529STREAM_ARTIST_RECOVERY_PAYOUT_CONTINUATION_V3"), 3n, e, { ...c, continuationHash: ZeroHash }]);
  assert.equal(p.artistRecoveryRewindPayoutContinuationHash(e, c), expected);
  assert.notEqual(p.artistRecoveryRewindPayoutContinuationHash(e, { ...c, releasedChildRecordHash: h(11) }), expected);
});

test("source-owned preparation seal binds exact post-preparation Identity and unchanged Payout prefix", () => {
  const { c, b, r, key } = selected(), state = zero(p.ARTIST_RECOVERY_REWIND_EVIDENCE_STATE_TUPLE);
  Object.assign(state, { manifestHash: b.identity.manifestHash, sourceKey: key, sourceCommitment: b.sourceCommitment, selectionCommitment: r.commitment, policyCommitment: h(1), requiredRole: h(2), associationHash: h(3), sources: { identityBefore: b.identity.identity, payout: b.payout, associationHash: h(3) } });
  const seal = { manifestHash: b.identity.manifestHash, sourceKey: key, actionId: h(4), associationHash: h(3), identityBefore: b.identity.identity, identityAfterPreparation: { ...b.identity.identity.snapshot, revision: 2n, stateRoot: h(5), recordChainTip: h(6) }, payout: b.payout, evidenceStateHash: keccak256(p.encodeArtistRecoveryRewindEvidenceState(state)), commitment: ZeroHash };
  seal.commitment = p.artistRecoveryRewindPreparationSealHash(c, seal);
  assert.equal(p.validateArtistRecoveryRewindPreparationSeal(c, b, state, seal).factsVerified, false);
  for (const patch of [{ commitment: ZeroHash }, { payout: { ...seal.payout, receiptCount: 0n } }, { identityAfterPreparation: { ...seal.identityAfterPreparation, revision: 3n } }, { associationHash: h(99) }, { evidenceStateHash: h(9) }]) assert.throws(() => p.validateArtistRecoveryRewindPreparationSeal(c, b, state, { ...seal, ...patch }));
});

test("every exposed original method retains compiled calldata, actor/target and source-owned hook distinction", () => {
  const c = coords(), r = request(), acceptance = authorization(), manifestHash = h(400), prepared = [];
  const catalog = new Interface(p.CURRENT_ARTIST_RECOVERY_REWIND_ABI);
  catalog.forEachFunction(f => { const matching = Object.values(abi).map(i => { try { return i.getFunction(f.format("sighash")); } catch { return null; } }).filter(Boolean); assert.ok(matching.some(g => g.format("sighash") === f.format("sighash"))); });
  const cases = [
    ["evidence", c.evidencePublisher, { kind: "publishResolutionManifestV3", manifest: manifest() }],
    ["evidence", c.evidencePublisher, { kind: "resolutionManifestV3", manifestHash }],
    ["selection", c.selectionPreparation, { kind: "beginSelectionV3", manifestHash }],
    ["selection", c.selectionPreparation, { kind: "continueSelectionV3", key: h(1), maximumRecords: max64 }],
    ["selection", c.selectionPreparation, { kind: "selectionRecordV3", key: h(1), recordHash: h(2) }],
    ["selection", c.selectionPreparation, { kind: "preparationSealV3", key: h(1) }],
    ["recoveryV3", c.registry, { kind: "identityRecoveryContextV3", request: r, acceptance, manifestHash }],
    ["recoveryV3", c.registry, { kind: "recoverArtistIdentityV3", request: r, acceptance, manifestHash }],
    ["recoveryOwnerV3", c.identityOwner, { kind: "recoveryRecordStatusV3", recordKind: 6n, recordHash: h(2) }],
    ["recoveryOwnerV3", c.identityOwner, { kind: "recoveryStandingScopeV3", artistId: r.artistId, priorAddress: a(9) }],
    ["payoutOwnerV3", c.payoutOwner, { kind: "payoutRewindInventoryV3", artistId: r.artistId }],
  ];
  for (const [segment, target, input] of cases) { const plan = p.prepareArtistRecoveryRewindCall(c, a(50), input); assert.equal(plan.call.to, target); assert.equal(plan.call.value, 0n); assert.equal(plan.caller, a(50)); assert.equal(plan.factsVerified, false); assert.equal(plan.protocolOnly, false); const args = Object.entries(input).filter(([k]) => k !== "kind").map(([, v]) => v); assert.equal(plan.call.data, abi[segment].encodeFunctionData(input.kind, args)); prepared.push(plan); }
  const hook = { kind: "sealPreparationV3", manifestHash, actionId: h(1), associationHash: h(2) };
  assert.throws(() => p.prepareArtistRecoveryRewindCall(c, a(50), hook));
  assert.equal(p.prepareArtistRecoveryRewindCall(c, c.coordinator, hook).protocolOnly, true);
  const apply = { kind: "applyRecoveryRewindV3", context: zero(p.ARTIST_RECOVERY_REWIND_ACTION_CONTEXT_TUPLE), plan: zero(p.ARTIST_RECOVERY_REWIND_PAYOUT_APPLY_TUPLE) };
  assert.throws(() => p.prepareArtistRecoveryRewindCall(c, a(50), apply));
  assert.equal(p.prepareArtistRecoveryRewindCall(c, c.coordinator, apply).call.to, c.payoutOwner);
  assert.throws(() => p.prepareArtistRecoveryRewindCall(c, a(50), { kind: "continueSelectionV3", key: h(1), maximumRecords: 0n }));
  assert.throws(() => p.prepareArtistRecoveryRewindCall(c, a(50), { kind: "recoverArtistIdentityV2", request: r, acceptance, manifestHash }));
});

test("class2 publication/schedule/execution retain original governance identities and V3 exact context", () => {
  const c = coords(), x = context(), w = window(), batch = p.artistRecoveryRewindGovernanceBatch(c, request(), authorization(), h(400), x, a(60), max256, w);
  assert.equal(batch.actionClass, 2n); assert.equal(batch.factsVerified, false);
  assert.equal(batch.publicationCall.data, abi.executor.encodeFunctionData("publishGovernanceCallData", [[batch.targetCall.data]]));
  assert.equal(batch.scheduleCall.data, abi.executor.encodeFunctionData("scheduleGovernanceBatch", [2n, [batch.governanceCall], batch.scopeHash, batch.oldValueHash, batch.newValueHash, w.notBefore, w.expiresAfter, w.reasonHash, w.reasonURI, w.manifestHash]));
  assert.equal(batch.executionCall.data, abi.executor.encodeFunctionData("executeGovernanceBatch", [batch.actionId, [batch.governanceCall], [batch.targetCall.data]]));
  assert.equal(batch.publicationKey, keccak256(batch.governanceCall.callDataHash));
  const actionIdentity = fixture.abis.governanceIdentity.find(f => f.name === "governanceActionId").inputs.at(-1);
  const original = hash(["bytes32", "uint256", "address", actionIdentity], ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", c.chainId, a(60), [2n, batch.callsHash, batch.scopeHash, batch.oldValueHash, batch.newValueHash, max256, w.notBefore, w.expiresAfter, w.reasonHash, w.manifestHash]]);
  assert.equal(batch.actionId, original); assert.deepEqual(p.normalizeArtistRecoveryRewindGovernanceBatch(batch), batch);
  assert.throws(() => p.artistRecoveryRewindGovernanceBatch(c, request(), authorization(), h(400), { ...x, newValueHash: h(1) }, a(60), 0n, w));
  assert.throws(() => p.artistRecoveryRewindGovernanceBatch(c, request(), authorization(), h(400), x, a(60), 0n, { ...w, reasonHash: h(2) }));
  p.assertArtistRecoveryRewindRegistrationWindow(authorization(), w, w.notBefore - 259200n, 259200n);
  assert.throws(() => p.assertArtistRecoveryRewindRegistrationWindow(authorization(), w, w.notBefore - 259199n, 259200n));
  const input = { kind: "registerIdentityRecoveryActionV3", actionId: batch.actionId, calls: [batch.governanceCall], request: request(), acceptance: authorization(), manifestHash: h(400) };
  assert.equal(p.prepareArtistRecoveryRewindCall(c, a(99), input).call.data, abi.recoveryV3.encodeFunctionData(input.kind, [input.actionId, input.calls, input.request, input.acceptance, input.manifestHash]));
});

test("original acceptance stays Registry-bound and excludes reason/manifest from its unchanged schema", () => {
  const r = request(), auth = authorization(), payload = p.artistRecoveryRewindAcceptancePayload(coords().chainId, coords().registry, r, a(99), auth);
  assert.deepEqual(payload, v2.artistRecoveryAcceptancePayload(coords().chainId, coords().registry, r, a(99), auth));
  assert.equal(payload.digest, p.artistRecoveryRewindAcceptancePayload(coords().chainId, coords().registry, { ...r, reasonHash: h(444), evidenceHash: h(445) }, a(99), auth).digest);
  assert.notEqual(payload.digest, p.artistRecoveryRewindAcceptancePayload(coords().chainId, coords().identityOwner, r, a(99), auth).digest);
});

test("flat tagged V3 Archive payloads preserve both owner facts and all notice bytes", () => {
  const prep = zero(p.ARTIST_RECOVERY_REWIND_PREPARATION_PAYLOAD_TUPLE); prep.tag = p.ARTIST_RECOVERY_REWIND_PREPARATION_TAG; prep.request = request(); prep.acceptance = authorization(); prep.evidence.manifest = manifest(); prep.state.sources.payout = manifest().payout;
  const notice = zero(v2.ARTIST_RECOVERY_NOTICE_EVIDENCE_TUPLE); notice.notice.recordHash = h(40); notice.notice.terms.reasonURI = "current living notice"; prep.notice = v2.encodeArtistRecoveryNoticeEvidence(notice);
  const raw = p.encodeArtistRecoveryRewindPreparationPayload(prep), fields = ParamType.from(p.ARTIST_RECOVERY_REWIND_PREPARATION_PAYLOAD_TUPLE).components;
  assert.equal(raw, coder.encode(fields, fields.map(f => prep[f.name]))); assert.notEqual(raw, coder.encode([p.ARTIST_RECOVERY_REWIND_PREPARATION_PAYLOAD_TUPLE], [prep]));
  assert.deepEqual(p.decodeArtistRecoveryRewindPreparationPayload(raw), prep);
  const exec = zero(p.ARTIST_RECOVERY_REWIND_EXECUTION_PAYLOAD_TUPLE); exec.tag = p.ARTIST_RECOVERY_REWIND_EXECUTION_TAG; exec.request = request(); exec.acceptance = authorization(); exec.noticeBefore = prep.notice; exec.noticeAfter = prep.notice; exec.payoutMutation = h(55);
  assert.deepEqual(p.decodeArtistRecoveryRewindExecutionPayload(p.encodeArtistRecoveryRewindExecutionPayload(exec)), exec);
  assert.throws(() => p.decodeArtistRecoveryRewindPreparationPayload(`${raw}00`));
  assert.throws(() => p.encodeArtistRecoveryRewindPreparationPayload({ ...prep, tag: p.ARTIST_RECOVERY_REWIND_EXECUTION_TAG }));
  assert.throws(() => p.encodeArtistRecoveryRewindExecutionPayload({ ...exec, noticeBefore: "0x12" }));
  assert.throws(() => p.decodeArtistRecoveryRewindExecutionPayload(`0x${"00".repeat(p.ARTIST_RECOVERY_REWIND_CODEC_MAX_BYTES + 1)}`), /bound/);
});

test("reused original eight-field envelope enforces full outer allocation cap and exact seven slots", () => {
  const snapshot = manifest().identity.snapshot, before = Array.from({ length: 7 }, () => zero("tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)")); before[2] = snapshot; before[5] = manifest().payout.snapshot;
  const envelope = { schemaVersion: 1n, configurationHash: h(1), operation: 65534n, actor: a(50), primaryRecordHash: ZeroHash, before, after: before, payload: "0x" };
  const overhead = (p.encodeArtistRecoveryRewindOperationEvidence(envelope).length - 2) / 2, payload = `0x${"00".repeat(p.ARTIST_RECOVERY_REWIND_CODEC_MAX_BYTES - overhead)}`;
  const encoded = p.encodeArtistRecoveryRewindOperationEvidence({ ...envelope, payload }); assert.equal((encoded.length - 2) / 2, p.ARTIST_RECOVERY_REWIND_CODEC_MAX_BYTES);
  assert.equal(p.decodeArtistRecoveryRewindOperationEvidence(encoded).before[5].domainId, id("domain:payout_lifecycle"));
  assert.throws(() => p.encodeArtistRecoveryRewindOperationEvidence({ ...envelope, payload: `${payload}00` }), /bound/);
  assert.throws(() => p.encodeArtistRecoveryRewindOperationEvidence({ ...envelope, before: before.slice(1) }));
  assert.throws(() => p.encodeArtistRecoveryRewindOperationEvidence({ ...envelope, primaryRecordHash: h(1) }));
});

test("strict inputs snapshot nested data and reject escaped mutation, sparse arrays and wrong widths", () => {
  const c = coords(), m = manifest(), plan = p.prepareArtistRecoveryRewindCall(c, a(50), { kind: "publishResolutionManifestV3", manifest: m });
  c.chainId = 1n; m.identity.snapshot.stateRoot = h(77); m.supersededRecords[0].recordHash = h(88);
  assert.equal(plan.coordinates.chainId, max256); assert.notEqual(plan.input.manifest.identity.snapshot.stateRoot, m.identity.snapshot.stateRoot); assert.deepEqual(p.normalizeArtistRecoveryRewindCall(plan), plan);
  assert.throws(() => { plan.input.manifest.payout.snapshot.revision = 1n; }, TypeError);
  assert.throws(() => p.normalizeArtistRecoveryRewindCall({ ...plan, call: { ...plan.call, value: 1n } }));
  assert.throws(() => p.normalizeArtistRecoveryRewindCall({ ...plan, protocolOnly: true }));
  assert.throws(() => p.prepareArtistRecoveryRewindCall(coords(), a(50), { kind: "selectionV3", key: h(1), target: a(99) }));
  assert.throws(() => p.normalizeArtistRecoveryRewindReceiptPrefix({ ...manifest().identity, receiptCount: Number.MAX_SAFE_INTEGER + 1 }));
  assert.throws(() => p.normalizeArtistRecoveryRewindReceiptPrefix({ ...manifest().identity, snapshot: { ...manifest().identity.snapshot, revision: max64 + 1n } }));
  const sparse = Array(1); assert.throws(() => p.normalizeArtistRecoveryRewindResolutionManifest({ ...manifest(), contestedVestings: sparse }));
  const attached = []; attached.x = 1; assert.throws(() => p.normalizeArtistRecoveryRewindResolutionManifest({ ...manifest(), contestedVestings: attached }));
  assert.throws(() => p.normalizeArtistRecoveryRewindIdentity({ ...zero(p.ARTIST_RECOVERY_REWIND_IDENTITY_TUPLE), displayName: "\udc00" }));
});

test("source and context preimages retain inactive notice facts and separate timed context wrapper", () => {
  const c = coords(), f = zero(p.ARTIST_RECOVERY_REWIND_SOURCE_FACTS_TUPLE); f.manifest = manifest(); f.manifestHash = p.artistRecoveryRewindManifestHash(c, f.manifest); f.historyProof = h(500); f.delegationEpoch = max64;
  const e = p.artistRecoveryRewindEnvironment(c), fields = ParamType.from(p.ARTIST_RECOVERY_REWIND_SOURCE_FACTS_TUPLE).components;
  assert.equal(p.artistRecoveryRewindIdentitySourceHash(c, f), hash(["bytes32", "uint16", p.ARTIST_RECOVERY_REWIND_ENVIRONMENT_TUPLE, ...fields], [id("6529STREAM_ARTIST_RECOVERY_REWIND_IDENTITY_SOURCE_V3"), 3n, e, ...fields.map(q => f[q.name])]));
  const unusedNotice = { ...f, notice: { ...f.notice, activity: max256 } };
  assert.notEqual(p.artistRecoveryRewindIdentitySourceHash(c, unusedNotice), p.artistRecoveryRewindIdentitySourceHash(c, f));
  const cf = { source: f, guardianPolicyCommitment: h(501), selection: zero(p.ARTIST_RECOVERY_REWIND_SELECTION_RESULT_TUPLE), payoutInventory: zero(p.ARTIST_RECOVERY_REWIND_PAYOUT_INVENTORY_TUPLE), effectiveCapabilities: 4095n, selectedGuardian: zero(v2.ARTIST_RECOVERY_GUARDIAN_RECORD_TUPLE), postContestSeconds: 1n, standingTailSeconds: 2n, timingRevision: 3n, delegationEpoch: 4n };
  const initial = p.artistRecoveryRewindContextOldValueHash(h(502), cf);
  assert.equal(initial, p.artistRecoveryRewindContextOldValueHash(h(502), { ...cf, source: unusedNotice }));
  const live = { ...f, notice: { ...f.notice, notice: { ...f.notice.notice, recordHash: h(503) } } };
  assert.equal(p.artistRecoveryRewindContextOldValueHash(h(502), { ...cf, source: live }), v2.artistRecoveryCurrentNoticeContextHash(initial, live.notice));
  assert.notEqual(initial, p.artistRecoveryRewindContextOldValueHash(h(502), { ...cf, delegationEpoch: 5n }));
});
