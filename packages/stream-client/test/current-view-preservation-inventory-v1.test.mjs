import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as api from "../dist/current-view-preservation-inventory-v1.js";
import { toSafeCall } from "../dist/safe.js";
import { fixture, compiledInterfaces } from "./current-view-preservation-consumers-v1-fixture.mjs";

const host = compiledInterfaces.StreamViewPreservationRenderCriticalInventoryV1;
const coder = AbiCoder.defaultAbiCoder(), Z = ZeroHash;
const A = n => getAddress("0x" + n.toString(16).padStart(40, "0"));
const H = label => id("view-inventory-test:" + label);
const c = { chainId: 1n, core: A(1), inventory: A(20) };
const scope = { scopeType: 4n, collectionId: 7n, tokenId: 0n, scopeId: H("scope") };
const types = Object.fromEntries(["dependencies", "sourceContext", "plan", "tokenProgress", "inventoryEvidence", "inventorySegment"]
  .map(name => [name, host.getFunction(name).outputs[0]]));
const itemType = host.getEvent("ViewPreservationInventorySegmentRecorded").inputs[4].arrayChildren;
const hash = (ts, vs) => keccak256(coder.encode(ts, vs));
const clone = structuredClone;
function zero(p) {
  if (p.baseType === "array") return p.arrayLength < 0 ? [] : Array.from({ length: p.arrayLength }, () => zero(p.arrayChildren));
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(q => [q.name, zero(q)]));
  if (p.type === "address") return ZeroAddress;
  if (p.type === "string") return "";
  if (p.type === "bytes") return "0x";
  if (p.type.startsWith("bytes")) return "0x" + "00".repeat(Number(p.type.slice(5)));
  if (p.type === "bool") return false;
  return 0n;
}
function sample() {
  const d = zero(types.dependencies);
  d.targets = d.targets.map((_, i) => A(i + 1));
  d.codeHashes = d.codeHashes.map((_, i) => H("runtime" + i));
  d.artistTargets = d.artistTargets.map((_, i) => A(100 + i));
  d.artistCodeHashes = d.artistCodeHashes.map((_, i) => H("artist-runtime" + i));
  Object.assign(d, { artistContentOwner: A(110), artistContentOwnerCodeHash: H("content-runtime"),
    chainId: 1n, readGas: 50000n, sourceGas: 90000n, selectionGas: 100000n, snapshotGas: 200000n, referenceGas: 300000n });
  const context = zero(types.sourceContext);
  const subject = hash(["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"],
    [id("6529STREAM_SUBJECT_SCOPE_V1"), c.chainId, c.core, scope.collectionId, 4n, scope.scopeId]);
  Object.assign(context, { scope: clone(scope), subject, artistId: H("artist"), nativeHash: H("native"),
    rootRecordHash: H("root"), tokenInventoryHash: H("inventory"), checkpointHash: H("checkpoint"),
    outputManifestRecord: H("outputs"), adoptionRecord: H("adoption"), viewId: H("view"), payloadHash: H("payload"),
    sourceContextHash: H("source-context"), policyChainHash: H("policy"), outputRoot: H("output-root"),
    manifestIndexHash: H("index"), tokenCount: 1n, interviewEvidenceHash: H("interview") });
  Object.assign(context.snapshot, { scopeSubject: subject, recordHash: H("snapshot"), revision: 2n });
  context.referenceRender.scopeSubject = subject;
  Object.assign(context.referenceRender.observation, { collectionId: 7n, recordHash: H("reference"),
    snapshotRecordHash: H("snapshot"), snapshotRevision: 2n });
  context.descriptions.scopeSubject = subject;
  context.conservation.association.artistId = context.artistId;
  context.conservation.record.recordHash = H("intent");
  const row = { ...zero(itemType), kind: 7n, role: H("absent-role"), source: A(4), sourceRecord: H("record") };
  const dependency = hash([types.dependencies], [d]);
  const planId = hash(["bytes32", "uint256", "address", "bytes32", types.sourceContext],
    [id("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_PLAN_V1"), 1n, c.inventory, dependency, context]);
  const segment = api.currentViewPreservationInventoryV1Segment(
    api.currentViewPreservationInventoryV1SegmentKey(planId, 0n), H("source-witness"), [row]);
  const plan = zero(types.plan);
  plan.scope = clone(scope);
  Object.assign(plan, { nativeCursor: 1n, nativeCount: 1n, referenceCursor: 1n, referenceCount: 1n });
  Object.assign(plan.progress, { collectionId: 7n, subject, artistId: context.artistId,
    sourceContextHash: hash([types.sourceContext], [context]), tokenCount: 1n, nextToken: 1n,
    segmentCount: 1n, itemCount: 1n, completedStages: 11n,
    segmentChainHash: api.currentViewPreservationInventoryV1AppendSegment(Z, 0n, segment) });
  const evidence = api.currentViewPreservationInventoryV1Evidence(c, dependency, context, plan.progress);
  plan.progress.renderCriticalEvidenceHash = evidence.inventory.renderCriticalEvidenceHash;
  const source = {
    scope: clone(scope), core: c.core, router: A(5), adoptionRecord: context.adoptionRecord,
    adoptionSourceHash: H("adoption-source"), declaration: A(30), declarationRecord: H("declaration"),
    payloadHash: context.payloadHash, checkpointContextHash: context.sourceContextHash,
    requestedURI: "", artistId: context.artistId, artistPresentationHash: H("presentation"),
  };
  return { d, context, dependency, planId, plan, evidence, row, segment, source };
}

test("all original public shapes and sixteen closed calls retain exact compiler calldata", () => {
  const iface = api.currentViewPreservationInventoryV1Interface();
  assert.deepEqual(iface.fragments.map(f => f.format("full")).sort(), host.fragments.filter(f => f.type !== "constructor").map(f => f.format("full")).sort());
  const names = { appendWork: ["id", "witness", "originalActor"], appendRights: ["id", "witness"],
    appendIntent: ["id", "witness", "originalActor"], appendIntentWaiver: ["id", "witness", "originalActor"],
    appendInterview: ["id", "witness", "originalActor"] };
  let count = 0;
  for (const fn of host.fragments.filter(f => f.type === "function" && f.stateMutability === "nonpayable")) {
    const values = fn.inputs.map(p => p.baseType === "tuple" ? zero(p) : p.type === "address" ? A(9) : p.type === "bytes32" ? H("id") : 1n);
    if (fn.name === "beginInventory") values[0] = clone(scope);
    if (fn.name === "appendRootAuthorization") values[3] = { revision: 1n, transitionChain: H("chain") };
    const fields = names[fn.name] ?? fn.inputs.map(p => p.name);
    const request = { method: fn.name, ...Object.fromEntries(fields.map((n, i) => [n, values[i]])) };
    const call = api.prepareCurrentViewPreservationInventoryV1Call(c, A(9), request);
    assert.equal(call.call.data, host.encodeFunctionData(fn.name, values));
    assert.equal(call.call.value, 0n);
    assert.equal(toSafeCall(call.call).operation, 0);
    assert.deepEqual(api.normalizeCurrentViewPreservationInventoryV1Call(call), call);
    count++;
  }
  assert.equal(count, 16);
});

test("raw codecs retain zero values while admitted scopes are exactly VIEW", () => {
  const raw = zero(types.sourceContext);
  assert.deepEqual(api.decodeCurrentViewPreservationInventoryV1Context(coder.encode([types.sourceContext], [raw])), raw);
  assert.throws(() => api.validateCurrentViewPreservationInventoryV1Context(c, raw));
  for (const scopeType of [0n, 1n, 2n, 3n]) assert.throws(() => api.validateCurrentViewPreservationInventoryV1Scope({ ...scope, scopeType }));
  assert.throws(() => api.normalizeCurrentViewPreservationInventoryV1Scope({ ...scope, scopeType: 5n }));
  assert.throws(() => api.normalizeCurrentViewPreservationInventoryV1Item({ ...sample().row, kind: 12n }));
  const bad = sample().context; bad.conservation.record.kind = 3n;
  assert.throws(() => api.normalizeCurrentViewPreservationInventoryV1Context(bad), /enum/);
});

test("dirty narrow words, trailing bytes, sparse arrays and surrogate text reject canonically", () => {
  const s = sample(), encoded = api.encodeCurrentViewPreservationInventoryV1Plan(s.plan);
  assert.throws(() => api.decodeCurrentViewPreservationInventoryV1Plan(encoded + "00"));
  assert.throws(() => api.decodeCurrentViewPreservationInventoryV1Scope(coder.encode(["uint256", "uint256", "uint256", "bytes32"], [256n, 7n, 0n, scope.scopeId])));
  const sparse = [...s.d.targets]; delete sparse[1];
  assert.throws(() => api.normalizeCurrentViewPreservationInventoryV1Dependencies({ ...s.d, targets: sparse }));
  const extra = [...s.d.targets]; Object.defineProperty(extra, "hidden", { value: 1 });
  assert.throws(() => api.normalizeCurrentViewPreservationInventoryV1Dependencies({ ...s.d, targets: extra }));
  assert.throws(() => api.normalizeCurrentViewPreservationInventoryV1Item({ ...s.row, uri: "\udc00" }));
  const decoded = api.decodeCurrentViewPreservationInventoryV1Dependencies(api.encodeCurrentViewPreservationInventoryV1Dependencies(s.d));
  assert.throws(() => { decoded.targets[0] = A(40); }, TypeError);
});

test("whole nested allocations and history aggregation are rejected before array copies", () => {
  const s = sample(), large = { ...s.row, uri: "x".repeat(32768) };
  assert.throws(() => api.currentViewPreservationInventoryV1Segment(H("key"), H("w"), Array(65).fill(large)), /bound/);
  const part = { segment: s.segment, items: Array(30).fill(large) };
  assert.throws(() => api.validateCurrentViewPreservationInventoryV1Segments(Array(18).fill(part)), /bound/);
  const bad = zero(host.getFunction("appendInterview").inputs[1]);
  bad.languages = Array(65).fill("x".repeat(32768));
  assert.throws(() => api.prepareCurrentViewPreservationInventoryV1Call(c, A(9),
    { method: "appendInterview", id: H("id"), witness: bad, originalActor: A(9) }), /bound/);
});

test("context and original plan hashes use independent compiler tuple preimages", () => {
  const s = sample();
  assert.equal(api.currentViewPreservationInventoryV1DependencyHash(s.d), s.dependency);
  assert.equal(api.currentViewPreservationInventoryV1ContextHash(s.context), hash([types.sourceContext], [s.context]));
  assert.equal(api.currentViewPreservationInventoryV1PlanId(c, s.dependency, s.context), s.planId);
  const e = clone(s.evidence); e.inventory.renderCriticalEvidenceHash = Z;
  assert.equal(s.evidence.inventory.renderCriticalEvidenceHash, hash(["bytes32", "uint256", "address", "bytes32", types.inventoryEvidence],
    [id("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_EVIDENCE_V1"), 1n, c.inventory, s.dependency, e]));
  assert.notEqual(api.currentViewPreservationInventoryV1PlanId({ ...c, inventory: A(99) }, s.dependency, s.context), s.planId);
});

test("INTENT zero and WAIVER one project to different original fields", () => {
  const s = sample();
  assert.equal(s.evidence.inventory.originals.intentRecordHash, s.context.conservation.record.recordHash);
  assert.equal(s.evidence.inventory.originals.intentWaiverRecordHash, Z);
  s.context.conservation.record.kind = 1n;
  const e = api.currentViewPreservationInventoryV1Evidence(c, s.dependency, s.context, s.plan.progress);
  assert.equal(e.inventory.originals.intentRecordHash, Z);
  assert.equal(e.inventory.originals.intentWaiverRecordHash, s.context.conservation.record.recordHash);
});

test("immutable context joins retain full VIEW scope, artist and snapshot identities", () => {
  const s = sample();
  api.validateCurrentViewPreservationInventoryV1Context(c, s.context);
  for (const change of [
    v => { v.scope.collectionId++; },
    v => { v.snapshot.scopeSubject = H("other"); },
    v => { v.referenceRender.observation.snapshotRevision++; },
    v => { v.conservation.association.artistId = H("other"); },
  ]) {
    const bad = clone(s.context); change(bad);
    assert.throws(() => api.validateCurrentViewPreservationInventoryV1Context(c, bad));
  }
});

test("original reverse links bind occurrence order, count and explicit empty segments", () => {
  const s = sample(), key = H("key"), itemHash = hash(["bytes32", itemType], [id("6529STREAM_PRESERVATION_ITEM_V1"), s.row]);
  assert.equal(api.currentViewPreservationInventoryV1ItemHash(s.row), itemHash);
  const last = hash(["bytes32", "bytes32", "uint64", "uint64", "bytes32", "bytes32"],
    [id("6529STREAM_PRESERVATION_ITEM_LINK_V1"), key, 2n, 1n, itemHash, Z]);
  assert.equal(api.currentViewPreservationInventoryV1Link(key, 2n, 1n, s.row, Z), last);
  assert.throws(() => api.currentViewPreservationInventoryV1Link(key, 2n, 0n, s.row, Z));
  const empty = api.currentViewPreservationInventoryV1Segment(key, H("explicit-source"), []);
  assert.equal(empty.firstLink, Z);
  assert.equal(empty.itemCount, 0n); // Generic consumer shape; not a reachable empty producer stage claim.
});

function rawCID() {
  const input = Buffer.concat([Buffer.from([1, 0x55, 0x12, 0x20]), Buffer.alloc(32, 7)]);
  let accumulator = 0, bits = 0, out = "";
  for (const byte of input) {
    accumulator = (accumulator << 8) | byte; bits += 8;
    while (bits >= 5) { bits -= 5; out += "abcdefghijklmnopqrstuvwxyz234567"[(accumulator >>> bits) & 31]; }
  }
  if (bits) out += "abcdefghijklmnopqrstuvwxyz234567"[(accumulator << (5 - bits)) & 31];
  return "ipfs://b" + out;
}
test("absent, raw CID, exact HTTPS and Arweave locators preserve original roles", () => {
  const s = sample().source;
  assert.equal(api.currentViewPreservationInventoryV1Obligation(s).kind, 7n);
  const cid = api.currentViewPreservationInventoryV1Obligation({ ...s, requestedURI: rawCID() });
  assert.equal(cid.algorithm, 2n);
  assert.equal(cid.digest, "0x" + "07".repeat(32));
  for (const requestedURI of ["https://archive.example/object", "ar://" + Buffer.alloc(32, 7).toString("base64url")]) {
    const row = api.currentViewPreservationInventoryV1Obligation({ ...s, requestedURI });
    assert.equal(row.role, id("VIEW_ARCHIVE_LOCATOR_IMAGE"));
    assert.equal(row.source, s.declaration);
    assert.equal(row.digest, "0x");
  }
  assert.throws(() => api.currentViewPreservationInventoryV1Obligation({ ...s, requestedURI: rawCID() + "/path" }));
});

test("broader literal HTTPS and Arweave paths require full-source retrieval without URL normalization", () => {
  const s = sample().source;
  for (const requestedURI of ["https://Archive.example/a", "https://a.example", "https://a.example/a%2f?x=1#f", "https://a.example/作品",
    "ar://" + Buffer.alloc(32, 7).toString("base64url") + "/path"]) {
    const row = api.currentViewPreservationInventoryV1Obligation({ ...s, requestedURI });
    assert.equal(row.role, id("VIEW_ATTRIBUTED_RETRIEVAL_IMAGE"));
    assert.equal(row.source, s.router);
    assert.equal(row.uri, requestedURI);
  }
  const a = api.currentViewPreservationInventoryV1Obligation({ ...s, requestedURI: "https://a.example/a%20" });
  const b = api.currentViewPreservationInventoryV1Obligation({ ...s, requestedURI: "https://a.example/a%20", checkpointContextHash: H("new") });
  assert.equal(a.provenanceHash, b.provenanceHash); // Deliberate sourceKey exclusion.
});

test("companion binding is separate from dependencyHash and checks exact snapshot checkpoint roster", () => {
  const { d } = sample();
  const snapType = compiledInterfaces.IStreamViewPreservationSnapshotPublicationV1.getFunction("dependencies").outputs[0];
  const snap = zero(snapType);
  snap.chainId = 1n;
  for (const i of [0, 4]) { snap.targets[i] = d.targets[i]; snap.codeHashes[i] = d.codeHashes[i]; }
  snap.targets[6] = A(80); snap.codeHashes[6] = H("checkpoint-runtime");
  const config = { core: d.targets[0], coreCodeHash: d.codeHashes[0], router: d.targets[4], routerCodeHash: d.codeHashes[4],
    checkpoint: snap.targets[6], checkpointCodeHash: snap.codeHashes[6], archive: d.targets[11], archiveCodeHash: d.codeHashes[11],
    chainId: 1n, readGas: 50000n, sourceGas: 100000n, archiveGas: 200000n, signatureGas: 90000n };
  assert.equal(api.validateCurrentViewPreservationInventoryV1RetrievalBinding(d, config, snap).runtimeVerified, false);
  assert.throws(() => api.validateCurrentViewPreservationInventoryV1RetrievalBinding(d, { ...config, checkpoint: A(81) }, snap));
  assert.equal(api.currentViewPreservationInventoryV1DependencyHash(d), hash([types.dependencies], [d]));
});

test("local history authenticates rows and original commitments while explicitly leaving currentness unproved", () => {
  const s = sample(), parts = [{ segment: s.segment, items: [s.row] }];
  const result = api.authenticateCurrentViewPreservationInventoryV1History(c, s.d, s.context, s.plan, s.evidence, parts);
  assert.equal(result.current, false);
  assert.equal(result.itemProductionIndependentlyReconstructed, false);
  assert.throws(() => api.authenticateCurrentViewPreservationInventoryV1History(c, s.d, s.context, s.plan, s.evidence,
    [{ segment: s.segment, items: [{ ...s.row, sourceRecord: H("substituted") }] }]));
  for (const field of ["nativeCursor", "referenceCursor"]) {
    assert.throws(() => api.authenticateCurrentViewPreservationInventoryV1History(c, s.d, s.context,
      { ...s.plan, [field]: 0n }, s.evidence, parts), /cursors/);
  }
  const bad = clone(s.evidence); bad.scope.collectionId++;
  bad.inventory.renderCriticalEvidenceHash = api.currentViewPreservationInventoryV1EvidenceHash(c, s.dependency, bad);
  assert.throws(() => api.authenticateCurrentViewPreservationInventoryV1History(c, s.d, s.context, s.plan, bad, parts), /Collection|scope/);
});

test("stage guard preserves eventless begin retry and exact legacy Work actor branch", () => {
  const s = sample(), t = { phase: 0n, row: 0n, count: 0n };
  api.validateCurrentViewPreservationInventoryV1Stage({ method: "beginInventory", scope }, s.plan, t);
  assert.throws(() => api.validateCurrentViewPreservationInventoryV1Stage({ method: "sealInventory", id: s.planId }, s.plan, t));
  s.plan.progress.renderCriticalEvidenceHash = Z;
  api.validateCurrentViewPreservationInventoryV1Stage({ method: "sealInventory", id: s.planId }, s.plan, t);
  assert.throws(() => api.validateCurrentViewPreservationInventoryV1Stage({ method: "sealInventory", id: s.planId }, s.plan, { ...t, row: 1n }));
  assert.equal(api.validateCurrentViewPreservationInventoryV1WorkActor(ZeroAddress, Z), ZeroAddress);
  assert.throws(() => api.validateCurrentViewPreservationInventoryV1WorkActor(A(8), Z));
});

test("the closed thirty-six-definition roster retains VIEW documents and original fixed ordering", () => {
  assert.equal(api.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DEFINITIONS.length, 36);
  assert.equal(api.currentViewPreservationInventoryV1Definition(0n).id, id("STREAM_WORK_DESCRIPTION_V1"));
  assert.equal(api.currentViewPreservationInventoryV1Definition(21n).id, id("STREAM_VIEW_PRESERVATION_SNAPSHOT_ABI_V1"));
  assert.equal(api.currentViewPreservationInventoryV1Definition(35n).id, id("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1"));
  const source = fixture.sourceTexts["smart-contracts/domains/records/StreamViewPreservationSnapshotDefinitionsV1.sol"];
  const text = typeof source === "string" ? source : source.text;
  assert.equal(api.currentViewPreservationInventoryV1Definition(21n).hash, text.match(/SCHEMA_HASH\s*=\s*(0x[0-9a-f]+)/)[1]);
  assert.throws(() => api.currentViewPreservationInventoryV1Definition(36n));
});

test("call/read ownership and closed methods reject surplus fields and substituted envelopes", () => {
  const input = { method: "beginInventory", scope: clone(scope) };
  const call = api.prepareCurrentViewPreservationInventoryV1Call(c, A(9), input);
  input.scope.collectionId++;
  assert.equal(call.request.scope.collectionId, 7n);
  for (const delta of [{ value: 1n }, { to: A(90) }, { data: "0x" }]) {
    assert.throws(() => api.normalizeCurrentViewPreservationInventoryV1Call({ ...call, call: { ...call.call, ...delta } }));
  }
  assert.throws(() => api.prepareCurrentViewPreservationInventoryV1Call(c, A(9), { method: "setGas", id: H("id") }));
  const read = api.prepareCurrentViewPreservationInventoryV1Read(c, { method: "plan", id: Z });
  assert.equal(read.call.data, host.encodeFunctionData("plan", [Z]));
  assert.throws(() => api.normalizeCurrentViewPreservationInventoryV1Read({ ...read, extra: 1 }));
});
