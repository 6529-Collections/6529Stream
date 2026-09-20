import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import * as c from "../dist/current-metadata-citation.js";

const fixture = JSON.parse(fs.readFileSync(new URL("./fixtures/current-metadata-citation-abi.json", import.meta.url), "utf8"));
const coder = AbiCoder.defaultAbiCoder(), registry = new Interface(fixture.abis.registry), renderer = new Interface(fixture.abis.currentRenderer), executor = new Interface(fixture.abis.executor);
const a = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`, h = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
const max = (1n << 256n) - 1n;
const emptyRegistration = () => ({ versionKey: ZeroHash, profile: ZeroHash, selector: "0x00000000", encoding: ZeroAddress, encodingRuntimeHash: ZeroHash, analysisDocument: ZeroHash, goldenDocument: ZeroHash });
const emptyRecord = () => ({ registration: emptyRegistration(), registrationHash: ZeroHash, readSetHash: ZeroHash, analysisHash: ZeroHash, goldenHash: ZeroHash, actionId: ZeroHash });
const request = () => ({ core: a(1), tokenId: max, collectionId: (1n << 100n) + 19n, collectionSerial: 0n, tokenHash: h(3), state: 3n, mode: 2n,
  collectionSupplyMode: 255n, collectionStatus: 255n, viewId: ZeroHash, viewManifestHash: ZeroHash, metadataSnapshotHash: h(9) });
function inputs() {
  const targets = [{ target: a(100), codeHash: h(100), role: id("CORE") }, { target: a(200), codeHash: h(200), role: id("METADATA_COMPANION") }];
  const originalReads = [{ targetIndex: 0n, selector: "0x12345678", maxReturnBytes: 32n, exact: true }];
  const snapshot = { chainId: (1n << 100n) + 1n, registry: a(2), schemaRegistry: a(3), schemaRegistryCodeHash: h(4), governanceExecutor: a(5), targets,
    originalVersion: { exists: true, deprecated: false, renderer: a(6), runtimeHash: h(6), registrationHash: h(7), readSetHash: c.metadataCitationReadSetHash(targets, originalReads), analysisHash: h(8), goldenHash: h(9), actionId: h(10) },
    originalReads, currentRecord: emptyRecord() };
  const registration = { versionKey: h(12), profile: c.METADATA_CITATION_PROFILE, selector: c.METADATA_CITATION_RENDER_SELECTOR, encoding: a(200), encodingRuntimeHash: h(200), analysisDocument: h(13), goldenDocument: h(14) };
  const reads = [...originalReads, { targetIndex: 1n, selector: c.METADATA_CITATION_ENCODING_SELECTOR, maxReturnBytes: 64n, exact: false }];
  return { snapshot, registration, reads };
}
function prepared() { const v = inputs(); return c.prepareMetadataCitationRegistration(v.snapshot, v.registration, v.reads); }
function evidence(plan = prepared()) {
  return { analysis: { analysisProfile: c.METADATA_CITATION_ANALYSIS_PROFILE, outputProfile: plan.registration.profile, selector: plan.registration.selector,
    renderer: plan.snapshot.originalVersion.renderer, runtimeHash: plan.snapshot.originalVersion.runtimeHash, encoding: plan.registration.encoding,
    encodingRuntimeHash: plan.registration.encodingRuntimeHash, readSetHash: plan.readSetHash, originalRegistrationHash: plan.snapshot.originalVersion.registrationHash,
    toolHash: h(50), findingsHash: h(51), passed: true }, goldens: [0n, 1n, 2n].map(mode => ({ request: request(), mode, outputHash: h(52n + mode) })) };
}
const window = () => ({ notBefore: 1000n + 172800n, expiresAfter: 1000n + 172800n + 604800n, reasonHash: ZeroHash, reasonURI: "ipfs://citation/\u{1f5bc}", manifestHash: ZeroHash });

test("work citation is the literal fullwidth original work identity including source-allowed zeros", () => {
  assert.equal(c.metadataWorkCitation(max, `0x${"AB".repeat(20)}`, max), `eip155:${max}/erc721:0x${"ab".repeat(20)}/${max}`);
  assert.equal(c.metadataWorkCitation(0n, ZeroAddress, 0n), "eip155:0/erc721:0x0000000000000000000000000000000000000000/0");
  for (const value of [-1n, 1n << 256n, 1, "1"]) assert.throws(() => c.metadataWorkCitation(value, a(1), 1n));
  assert.throws(() => c.metadataWorkCitation(1n, a(1), 1n << 256n));
});

test("current contract tuples/selectors match compiler witnesses; nominal encoder selector has separate retained evidence", () => {
  const ours = new Interface(c.CURRENT_METADATA_CITATION_ABI);
  ours.forEachFunction(f => assert.equal(f.format("sighash"), registry.getFunction(f.name).format("sighash")));
  assert.equal(c.METADATA_CITATION_RENDER_SELECTOR, renderer.getFunction("renderCurrent").selector);
  assert.equal(c.METADATA_CITATION_ENCODING_SELECTOR, "0x" + fixture.librarySelectorEvidence.methodIdentifiers["renderCurrent(IStreamRenderer.RenderRequest,StreamStaticRenderEncoding.Prepared,string,address,uint8)"]);
  assert.notEqual(c.METADATA_CITATION_ENCODING_SELECTOR, c.METADATA_CITATION_RENDER_SELECTOR);
  const xor = entries => { let n = 0n; new Interface(entries).forEachFunction(f => { n ^= BigInt(f.selector); }); return `0x${n.toString(16).padStart(8, "0")}`; };
  assert.equal(c.METADATA_CITATION_REGISTRY_INTERFACE_ID, xor(fixture.abis.currentRegistry));
  assert.equal(c.METADATA_CITATION_RENDERER_INTERFACE_ID, xor(fixture.abis.currentRenderer));
});

test("render request retains uint8 structural fields, original enum bounds and distinct mode3 HTML transport", () => {
  const q = request(), call = c.prepareMetadataCitationRenderCall(a(6), q, 3n);
  assert.equal(call.data, renderer.encodeFunctionData("renderCurrent", [q, 3n])); assert.equal(call.value, 0n);
  c.normalizeMetadataCitationRenderRequest({ ...q, core: ZeroAddress, tokenId: 0n, tokenHash: ZeroHash, viewId: h(1), viewManifestHash: h(2) });
  for (const patch of [{ state: 4n }, { mode: 3n }, { collectionSupplyMode: 256n }, { collectionStatus: -1n }, { tokenId: Number.MAX_SAFE_INTEGER }, { extra: true }]) assert.throws(() => c.normalizeMetadataCitationRenderRequest({ ...q, ...patch }));
  assert.throws(() => c.prepareMetadataCitationRenderCall(a(6), q, 4n));
  assert.throws(() => c.normalizeMetadataCitationGoldenVectors([{ request: q, mode: 3n, outputHash: h(1) }, ...evidence().goldens]));
});

test("target/read inventories require source ordering, finite roles, widths and exact-return alignment", () => {
  const { snapshot: s, reads } = inputs();
  for (const ts of [[], [...s.targets].reverse(), [s.targets[0], s.targets[0]], [{ ...s.targets[0], role: h(999) }], [{ ...s.targets[0], target: ZeroAddress }]]) assert.throws(() => c.normalizeMetadataCitationTargets(ts));
  for (const rs of [[...reads].reverse(), [reads[0], reads[0]], [{ ...reads[0], selector: "0x00000000" }], [{ ...reads[0], maxReturnBytes: 31n }], [{ ...reads[1], maxReturnBytes: 16777217n }], [{ ...reads[0], targetIndex: 65536n }]]) assert.throws(() => c.normalizeMetadataCitationReads(rs));
  assert.throws(() => c.metadataCitationReadSetHash(s.targets, [{ ...reads[0], targetIndex: 2n }]));
  assert.throws(() => c.normalizeMetadataCitationReads(Array(1)));
  const extra = [...reads]; extra.note = true; assert.throws(() => c.normalizeMetadataCitationReads(extra));
  assert.equal(c.metadataCitationReadSetHash(s.targets, []), keccak256(coder.encode(["bytes32", "bytes32", "tuple(uint16,bytes4,uint32,bool)[]"], [id("6529STREAM_RENDERER_READ_SET_V1"), c.metadataCitationTargetSetHash(s.targets), []])));
});

test("declaration uses all original coordinates and exact current tuples; empty previous hashes the zero declaration", () => {
  const v = inputs(), p = prepared(), regType = registry.getFunction("registerCurrentCitation").inputs[0], readType = registry.getFunction("registerCurrentCitation").inputs[1];
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "bytes32", regType, readType],
    [id("6529STREAM_CURRENT_CITATION_REGISTRATION_V1"), v.snapshot.chainId, v.snapshot.registry, v.snapshot.schemaRegistry, v.snapshot.schemaRegistryCodeHash,
      c.metadataCitationTargetSetHash(v.snapshot.targets), v.snapshot.originalVersion.registrationHash, v.registration, v.reads]));
  assert.equal(p.registrationHash, expected); assert.notEqual(p.transition.oldValueHash, ZeroHash);
  assert.equal(p.transition.oldValueHash, keccak256(coder.encode(["bytes32", "bytes32"], [id("6529STREAM_CURRENT_CITATION_STATE_V1"), ZeroHash])));
  assert.equal(p.targetCall.data, registry.encodeFunctionData("registerCurrentCitation", [v.registration, v.reads]));
  for (const field of ["chainId", "registry", "schemaRegistry", "schemaRegistryCodeHash"]) {
    const value = field === "chainId" ? 1n : field.endsWith("Hash") ? h(999) : a(999);
    assert.notEqual(c.metadataCitationDeclarationHash({ ...v.snapshot, [field]: value }, v.registration, v.reads), expected);
  }
  assert.equal(c.metadataCitationDeclarationHash({ ...v.snapshot, governanceExecutor: a(999) }, v.registration, v.reads), expected);
  assert.notEqual(c.metadataCitationDeclarationHash({ ...v.snapshot, originalVersion: { ...v.snapshot.originalVersion, registrationHash: h(888) } }, v.registration, v.reads), expected);
});

test("registration preserves original reads byte-for-byte and requires the separate encoder read", () => {
  const v = inputs(), run = (s = v.snapshot, r = v.registration, reads = v.reads) => c.prepareMetadataCitationRegistration(s, r, reads);
  for (const reads of [[v.reads[1]], [v.reads[0]], [{ ...v.reads[0], maxReturnBytes: 64n }, v.reads[1]], [v.reads[0], { ...v.reads[1], exact: true }], [v.reads[0], { ...v.reads[1], maxReturnBytes: 63n }], [v.reads[0], { ...v.reads[1], selector: c.METADATA_CITATION_RENDER_SELECTOR }]]) assert.throws(() => run(v.snapshot, v.registration, reads));
  for (const patch of [{ encodingRuntimeHash: h(400) }, { encoding: a(400) }, { selector: "0xc992b4e4" }, { profile: id("6529STREAM_STATIC_RENDERER_ANALYSIS_ABI_V1") }, { analysisDocument: ZeroHash }, { goldenDocument: ZeroHash }]) assert.throws(() => run(v.snapshot, { ...v.registration, ...patch }));
  for (const patch of [{ exists: false }, { deprecated: true }, { readSetHash: h(999) }]) assert.throws(() => run({ ...v.snapshot, originalVersion: { ...v.snapshot.originalVersion, ...patch } }));
  assert.throws(() => run({ ...v.snapshot, currentRecord: { ...emptyRecord(), registrationHash: h(1) } }));
  // The transition getter remains a state observation; admission is enforced by the planner.
  const existing = { ...v.snapshot, originalVersion: { ...v.snapshot.originalVersion, deprecated: true }, currentRecord: { ...emptyRecord(), registrationHash: h(1) } };
  assert.equal(c.metadataCitationTransition(existing, v.registration, v.reads).oldValueHash, c.metadataCitationStateHash(h(1)));
});

test("analysis codec is source-derived canonical ABI with exact finite declaration joins", () => {
  const p = prepared(), { analysis, goldens } = evidence(p), result = c.validateMetadataCitationEvidence(p, analysis, goldens);
  assert.deepEqual(c.decodeMetadataCitationAnalysis(result.analysisBytes), analysis);
  assert.equal(result.analysisBytes.length, 2 + 384 * 2); assert.equal(result.analysisHash, keccak256(result.analysisBytes)); assert.equal(result.factsVerified, false);
  assert.throws(() => c.decodeMetadataCitationAnalysis(result.analysisBytes + "00".repeat(32)));
  for (const field of Object.keys(analysis)) {
    const value = field === "passed" ? false : field === "selector" ? "0x11223344" : field === "renderer" || field === "encoding" ? a(700) : h(700);
    if (field === "toolHash" || field === "findingsHash") { assert.throws(() => c.validateMetadataCitationEvidence(p, { ...analysis, [field]: ZeroHash }, goldens)); continue; }
    assert.throws(() => c.validateMetadataCitationEvidence(p, { ...analysis, [field]: value }, goldens), field);
  }
  const assertion = { ...analysis, passed: false, toolHash: ZeroHash, findingsHash: ZeroHash };
  assert.deepEqual(c.decodeMetadataCitationAnalysis(c.encodeMetadataCitationAnalysis(assertion)), assertion);
});

test("golden vectors retain complete requests and supplied output commitments; exact modes, bounds and ABI canonicality", () => {
  const { goldens } = evidence(), raw = c.encodeMetadataCitationGoldenVectors(goldens);
  assert.deepEqual(c.decodeMetadataCitationGoldenVectors(raw), goldens);
  assert.equal(c.encodeMetadataCitationGoldenVectors(Array.from({ length: 16 }, (_, i) => goldens[i % 3])).length, 2 + 7232 * 2);
  for (const vectors of [goldens.slice(1), [goldens[0], goldens[0], goldens[1]], [...goldens, ...Array(14).fill(goldens[0])], [goldens[0], goldens[1], { ...goldens[2], outputHash: ZeroHash }], Array(3)]) assert.throws(() => c.encodeMetadataCitationGoldenVectors(vectors));
  assert.throws(() => c.decodeMetadataCitationGoldenVectors(raw + "00".repeat(32)));
  const badOffset = "0x" + h(64).slice(2) + raw.slice(66, 130) + raw.slice(66); assert.throws(() => c.decodeMetadataCitationGoldenVectors(badOffset));
  const changed = goldens.map((v, i) => i ? v : { ...v, request: { ...v.request, tokenId: 1n } });
  assert.notEqual(keccak256(c.encodeMetadataCitationGoldenVectors(changed)), keccak256(raw));
  assert.equal(c.validateMetadataCitationEvidence(prepared(), evidence().analysis, changed).factsVerified, false);
});

test("current record canonical codec retains the empty sentinel and every original retained fact", () => {
  const p = prepared(), e = c.validateMetadataCitationEvidence(p, evidence(p).analysis, evidence(p).goldens);
  const record = { registration: p.registration, registrationHash: p.registrationHash, readSetHash: p.readSetHash, analysisHash: e.analysisHash, goldenHash: e.goldenHash, actionId: h(88) };
  for (const value of [emptyRecord(), record]) assert.deepEqual(c.decodeMetadataCitationRecord(c.encodeMetadataCitationRecord(value)), value);
  assert.throws(() => c.decodeMetadataCitationRecord(c.encodeMetadataCitationRecord(record) + "00".repeat(32)));
  assert.throws(() => c.normalizeMetadataCitationRecord({ ...record, current: true }));
});

test("class1 plan and original GovV2 publication/schedule/execution are exact zero-value calls", () => {
  const p = prepared(), batch = c.metadataCitationGovernanceBatch(p, max, window()), calls = [p.governanceCall], datas = [p.targetCall.data];
  assert.equal(batch.publicationCall.data, executor.encodeFunctionData("publishGovernanceCallData", [datas]));
  assert.equal(batch.scheduleCall.data, executor.encodeFunctionData("scheduleGovernanceBatch", [1n, calls, batch.scopeHash, batch.oldValueHash, batch.newValueHash,
    window().notBefore, window().expiresAfter, window().reasonHash, window().reasonURI, window().manifestHash]));
  assert.equal(batch.executionCall.data, executor.encodeFunctionData("executeGovernanceBatch", [batch.actionId, calls, datas]));
  for (const call of [batch.publicationCall, batch.scheduleCall, batch.executionCall]) { assert.equal(call.to, p.snapshot.governanceExecutor); assert.equal(call.value, 0n); }
  assert.equal(batch.publicationKey, keccak256(p.governanceCall.callDataHash));
  assert.notEqual(batch.scopeHash, p.transition.scopeHash); assert.notEqual(batch.oldValueHash, p.transition.oldValueHash);
  assert.equal(batch.callsHash, keccak256(coder.encode(["bytes32", "tuple(address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32)[]"], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls.map(v => [v.target, v.value, v.selector, v.callDataHash, v.scopeHash, v.oldValueHash, v.newValueHash])])));
  assert.equal(c.metadataCitationGovernanceBatch(p, max, { ...window(), reasonURI: "different unsigned prose" }).actionId, batch.actionId);
  assert.notEqual(c.metadataCitationGovernanceBatch(p, 0n, window()).actionId, batch.actionId);
});

test("governance timing preserves original class1 boundaries without current-time inference", () => {
  const w = window(); c.assertMetadataCitationGovernanceWindow(w, 1000n);
  c.assertMetadataCitationGovernanceWindow({ ...w, expiresAfter: 1000n + 31536000n }, 1000n);
  for (const value of [{ ...w, notBefore: w.notBefore - 1n }, { ...w, expiresAfter: 1000n + 31536001n }, { ...w, expiresAfter: w.notBefore + 604799n }]) assert.throws(() => c.assertMetadataCitationGovernanceWindow(value, 1000n));
  assert.throws(() => c.assertMetadataCitationGovernanceWindow(w, (1n << 64n) - 31536000n));
  for (const patch of [{ reasonURI: "\ud800" }, { reasonURI: "\udfff" }, { notBefore: 1 }, { expiresAfter: 1n << 64n }, { extra: true }]) assert.throws(() => c.normalizeMetadataCitationGovernanceWindow({ ...w, ...patch }));
  assert.throws(() => c.metadataCitationGovernanceBatch(prepared(), 1n << 256n, w));
});

test("snapshots and canonical plans reconstruct immutable nested values and reject escaped calldata or facts claims", () => {
  const v = inputs(), p = c.prepareMetadataCitationRegistration(v.snapshot, v.registration, v.reads), before = p.registrationHash;
  v.snapshot.targets[0].codeHash = h(999); v.reads[0].maxReturnBytes = 64n; v.registration.analysisDocument = h(999);
  assert.equal(p.registrationHash, before); assert.equal(p.reads[0].maxReturnBytes, 32n);
  assert.throws(() => { p.reads[0].maxReturnBytes = 64n; }); assert.throws(() => { p.snapshot.targets.push(p.snapshot.targets[0]); });
  assert.notEqual(c.normalizeMetadataCitationPlan(p), p);
  for (const patch of [{ factsVerified: true }, { targetCall: { ...p.targetCall, to: a(999) } }, { targetCall: { ...p.targetCall, data: "0x" } }, { registrationHash: h(999) }, { actionClass: 3n }]) assert.throws(() => c.normalizeMetadataCitationPlan({ ...p, ...patch }));
  const batch = c.metadataCitationGovernanceBatch(p, 0n, window()); assert.deepEqual(c.normalizeMetadataCitationGovernanceBatch(batch), batch);
  assert.throws(() => c.normalizeMetadataCitationGovernanceBatch({ ...batch, executionCall: { ...batch.executionCall, value: 1n } }));
  const { analysis, goldens } = evidence(p), e = c.validateMetadataCitationEvidence(p, analysis, goldens); goldens[0].request.core = a(999); analysis.toolHash = h(999);
  assert.notEqual(e.goldens[0].request.core, a(999)); assert.throws(() => { e.goldens[0].request.core = a(999); });
});
