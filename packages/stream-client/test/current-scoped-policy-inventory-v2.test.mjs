import assert from "node:assert/strict";
import test from "node:test";
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, id, keccak256, toUtf8Bytes, toUtf8String, hexlify } from "ethers";
import * as p from "../dist/current-scoped-policy-inventory-v2.js";
import { fixture, compiledInterfaces as abi } from "./current-scoped-policy-inventory-archive-v2-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const z = ZeroHash;
const h = n => `0x${n.toString(16).padStart(64, "0")}`;
const a = n => `0x${n.toString(16).padStart(40, "0")}`;
const c = { chainId: 1n << 200n, core: a(1), inventory: a(2) };
const scope = { scopeType: 1n, collectionId: 7n, tokenId: 9n, scopeId: z };
function zero(t) {
  if (t.baseType === "tuple") return Object.fromEntries(t.components.map(f => [f.name, zero(f)]));
  if (t.baseType === "array") return Array.from({ length: Math.max(t.arrayLength, 0) }, () => zero(t.arrayChildren));
  if (t.type.startsWith("uint")) return 0n;
  if (t.type === "address") return ZeroAddress;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  return t.type === "bytes" ? "0x" : `0x${"00".repeat(Number(t.type.slice(5)))}`;
}
const output = name => abi.inventory.getFunction(name).outputs[0];
const input = name => abi.inventory.getFunction(name).inputs[1];
const itemType = abi.inventory.getEvent("ScopedInventorySegmentRecorded").inputs[4].arrayChildren;
const item = () => ({ ...zero(itemType), role: h(1), source: a(3), sourceRecord: h(2), algorithm: 6n, digest: h(3), byteSize: 77n });
const same = (t, x, y) => assert.equal(coder.encode([t], [x]), coder.encode([t], [y]));
function context() {
  const x = zero(output("sourceContext"));
  x.scope = { ...scope };
  return { x, source: x.snapshotSource };
}

test("the profile exposes exactly the original 17 nonpayable writes and finite reads", () => {
  assert.equal(p.SCOPED_POLICY_INVENTORY_V2_SOURCE, fixture.sourceCommit);
  const writes = p.scopedPolicyInventoryV2Interface().fragments.filter(f => f.type === "function" && f.stateMutability === "nonpayable");
  assert.equal(writes.length, 17);
  assert.equal(p.scopedPolicyInventoryV2Interface().getFunction("appendReference").selector, "0xd4dabeb0");
  assert.throws(() => p.prepareScopedPolicyInventoryV2Call(c, a(8), { kind: "lockInventory", id: h(1) }), /Unknown/);
  assert.throws(() => p.prepareScopedPolicyInventoryV2Read(c, a(8), { kind: "inventoryItem", id: h(1), index: 0n }), /Unknown/);
});

test("raw historical codecs preserve zero values and full widths, rejecting noncanonical bytes", () => {
  for (const [name, getter] of [["Plan", "plan"], ["Context", "sourceContext"], ["Evidence", "inventoryEvidence"], ["TokenProgress", "tokenProgress"]]) {
    const value = zero(output(getter));
    const raw = coder.encode([output(getter)], [value]);
    same(output(getter), p[`decodeScopedPolicyInventoryV2${name}`](raw), value);
    assert.throws(() => p[`decodeScopedPolicyInventoryV2${name}`](`${raw}${"00".repeat(32)}`), /Noncanonical/);
  }
  const row = { ...item(), sourceIndex: (1n << 256n) - 1n, byteSize: (1n << 64n) - 1n };
  same(itemType, p.decodeScopedPolicyInventoryV2Item(coder.encode([itemType], [row])), row);
  assert.throws(() => p.normalizeScopedPolicyInventoryV2Item({ ...row, byteSize: 1n << 64n }), /uint64/);
  assert.throws(() => p.normalizeScopedPolicyInventoryV2Item({ ...row, sourceIndex: 1 }), /bigint/);
  assert.throws(() => p.normalizeScopedPolicyInventoryV2Item({ ...row, ignored: true }), /fields/);
});

test("structural witnesses preserve inactive branches and enforce true Solidity enums", () => {
  const work = zero(input("appendWork"));
  work.absence.reason = "preserved inactive branch";
  work.full.measurements.width = (1n << 256n) - 1n;
  same(input("appendWork"), p.normalizeScopedPolicyInventoryV2Work(work), work);
  assert.throws(() => p.normalizeScopedPolicyInventoryV2Work({ ...work, form: 2n }), /enum/);
  const malformed = structuredClone(work); malformed.full.creator.kind = 2n;
  assert.throws(() => p.normalizeScopedPolicyInventoryV2Work(malformed), /enum/);
  assert.throws(() => p.normalizeScopedPolicyInventoryV2Item({ ...item(), kind: 12n }), /enum/);
  // Arbitrary original reference algorithms remain representable before archive correspondence.
  assert.equal(p.normalizeScopedPolicyInventoryV2Item({ ...item(), algorithm: 65535n }).algorithm, 65535n);
});

test("all 31 fixed definition IDs, byte lengths and hashes retain exact original document bytes", () => {
  assert.equal(p.SCOPED_POLICY_INVENTORY_V2_DEFINITIONS.length, 31);
  for (const d of p.SCOPED_POLICY_INVENTORY_V2_DEFINITIONS) {
    const raw = d.documentPath ? hexlify(toUtf8Bytes(fixture.documents[d.documentPath].text)) : d.literal;
    assert.equal(d.id, id(d.name));
    assert.equal(BigInt((raw.length - 2) / 2), d.byteLength);
    assert.equal(keccak256(raw), d.contentHash);
    assert.equal(p.scopedPolicyInventoryV2Definition(d.index), d);
    if (d.literal) assert.equal(JSON.parse(toUtf8String(raw)).name, d.name);
    assert(Object.isFrozen(d));
  }
  assert.throws(() => p.scopedPolicyInventoryV2Definition(31n));
  assert.equal(fixture.documents[p.scopedPolicyInventoryV2Definition(14n).documentPath].text.endsWith("\n"), true);
  assert.equal(fixture.documents[p.scopedPolicyInventoryV2Definition(0n).documentPath].text.endsWith("\n"), false);
});

test("fixed definitions admit ACTIVE0, reject DEPRECATED1 and bind ordered complete chunks", () => {
  const d = p.scopedPolicyInventoryV2Definition(0n);
  const raw = hexlify(toUtf8Bytes(fixture.documents[d.documentPath].text));
  const chunks = [raw.slice(0, 2 + 8192 * 2), `0x${raw.slice(2 + 8192 * 2)}`];
  const facts = { exists: true, kind: 0n, status: 0n, contentHash: d.contentHash,
    canonicalizationId: id("RFC8785_JCS"), supersedesId: z, totalBytes: d.byteLength,
    chunkCount: 2n, declarationHash: h(55) };
  const result = p.validateScopedPolicyInventoryV2Document(0n, facts, chunks);
  assert.equal(result.content, raw);
  assert.equal(result.factsHash, keccak256(coder.encode([abi.schemas.getFunction("documentFacts").outputs[0]], [facts])));
  assert.throws(() => p.validateScopedPolicyInventoryV2Document(0n, { ...facts, status: 1n }, chunks), /facts/);
  assert.throws(() => p.validateScopedPolicyInventoryV2Document(0n, facts, chunks.toReversed()), /bytes/);
  assert.throws(() => p.validateScopedPolicyInventoryV2Document(0n, facts, [raw]), /facts/);
});

test("original V1 item/link/segment chains preserve duplicate positions and explicit empty segments", () => {
  const row = item(), key = h(20), witness = h(21);
  const itemHash = keccak256(coder.encode(["bytes32", itemType], [id("6529STREAM_PRESERVATION_ITEM_V1"), row]));
  assert.equal(p.scopedPolicyInventoryV2ItemHash(row), itemHash);
  const tail = keccak256(coder.encode(["bytes32", "bytes32", "uint64", "uint64", "bytes32", "bytes32"],
    [id("6529STREAM_PRESERVATION_ITEM_LINK_V1"), key, 2n, 1n, itemHash, z]));
  const first = p.scopedPolicyInventoryV2Link(key, 2n, 0n, row, tail);
  assert.notEqual(first, tail);
  const s = p.scopedPolicyInventoryV2Segment(key, witness, [row, row]);
  assert.equal(s.firstLink, first); assert.equal(s.itemCount, 2n);
  const empty = p.scopedPolicyInventoryV2Segment(key, witness, []);
  assert.equal(empty.firstLink, z); assert.equal(empty.itemCount, 0n);
  assert.notEqual(p.scopedPolicyInventoryV2AppendSegment(z, 0n, empty), z);
  // Empty segment is supported by generic chains/consumer, not claimed reachable from these concrete 17 producers.
  assert.throws(() => p.scopedPolicyInventoryV2Link(key, 2n, 0n, row, z), /link/);
  assert.throws(() => p.scopedPolicyInventoryV2Link(key, 2n, 1n, row, tail), /link/);
});

async function coherentContext() {
  const graph = await import("../dist/current-scoped-policy-graph-v2.js");
  const { x, source } = context();
  const subject = graph.scopedPolicyGraphV2ScopeSubject(c.chainId, c.core, scope);
  x.subject = x.snapshot.scopeSubject = x.referenceRender.scopeSubject = x.descriptions.scopeSubject = source.membership.scopeSubject = subject;
  for (const holder of [source, source.selection, source.content, source.outputs]) holder.scope = { ...scope };
  x.artistId = source.artist.artistId = x.conservation.association.artistId = h(10);
  source.artist.bindingGeneration = x.conservation.association.generation = 1n;
  source.artist.bindingHash = x.conservation.association.bindingHash = h(11);
  source.artist.identityRecordHash = x.conservation.association.identityRecordHash = h(12);
  x.snapshot.recordHash = x.referenceRender.observation.snapshotRecordHash = h(13);
  x.snapshot.revision = x.referenceRender.observation.snapshotRevision = 1n;
  x.referenceRender.observation.collectionId = scope.collectionId;
  x.referenceRender.observation.recordHash = h(14);
  x.rootRecordHash = h(15); x.outputManifestRecord = h(16);
  x.tokenInventoryHash = source.membership.membershipHash = h(17);
  x.checkpointHash = source.outputs.checkpointHash = h(18);
  x.selectionId = source.content.selectionId = h(19); x.selectionHash = source.content.selectionHash = h(20);
  x.tokenCount = source.membership.tokenCount = source.selection.tokenCount = source.content.tokenCount = source.outputs.tokenCount = 1n;
  x.nativeHash = keccak256(coder.encode([output("sourceContext").components.find(f => f.name === "snapshotSource")], [source]));
  return x;
}

test("supplied context requires full TOKEN scope, snapshot identity, cardinality and native source commitment", async () => {
  const x = await coherentContext();
  assert.equal(p.validateScopedPolicyInventoryV2Context(c, x).tokenCount, 1n);
  for (const mutate of [
    y => { y.snapshotSource.scope.collectionId++; },
    y => { y.referenceRender.observation.snapshotRevision++; },
    y => { y.snapshotSource.outputs.tokenCount++; },
  ]) {
    const y = structuredClone(x); mutate(y);
    y.nativeHash = keccak256(coder.encode([output("sourceContext").components.find(f => f.name === "snapshotSource")], [y.snapshotSource]));
    assert.throws(() => p.validateScopedPolicyInventoryV2Context(c, y), /associations/);
  }
});

test("same artistId does not bypass original generation, binding or identity association joins", async () => {
  const x = await coherentContext();
  for (const field of ["bindingGeneration", "bindingHash", "identityRecordHash"]) {
    const y = structuredClone(x);
    y.snapshotSource.artist[field] = field === "bindingGeneration" ? 2n : h(999);
    y.nativeHash = keccak256(coder.encode([output("sourceContext").components.find(f => f.name === "snapshotSource")], [y.snapshotSource]));
    const differentId = p.scopedPolicyInventoryV2PlanId(c, h(50), y);
    assert.notEqual(differentId, p.scopedPolicyInventoryV2PlanId(c, h(50), x));
    assert.throws(() => p.validateScopedPolicyInventoryV2Context(c, y), /associations/);
  }
});

test("completed inventory evidence clears only its own hash and authenticates full scope", async () => {
  const x = await coherentContext(), dependency = h(80);
  const e = zero(output("inventoryEvidence")); e.scope = { ...scope };
  Object.assign(e.inventory, { planId: p.scopedPolicyInventoryV2PlanId(c, dependency, x), collectionId: scope.collectionId,
    scopeSubject: x.subject, artistId: x.artistId, sourceContextHash: p.scopedPolicyInventoryV2ContextHash(x),
    tokenInventoryHash: x.tokenInventoryHash, tokenCount: 1n, segmentCount: 40n, itemCount: 100n, segmentChainHash: h(90) });
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", output("inventoryEvidence")],
    [id("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_EVIDENCE_V2"), c.chainId, c.inventory, dependency, e]));
  e.inventory.renderCriticalEvidenceHash = expected;
  assert.equal(p.validateScopedPolicyInventoryV2Evidence(c, dependency, e).inventory.renderCriticalEvidenceHash, expected);
  assert.equal(p.scopedPolicyInventoryV2EvidenceHash(c, dependency, e), expected);
  const bad = structuredClone(e); bad.scope.collectionId++;
  bad.inventory.renderCriticalEvidenceHash = p.scopedPolicyInventoryV2EvidenceHash(c, dependency, bad);
  assert.throws(() => p.validateScopedPolicyInventoryV2Evidence(c, dependency, bad), /associations/);
});

test("every write uses actual original ABI, caller and zero-value CALL", () => {
  const requests = [
    { kind: "beginInventory", scope },
    ...["appendNative", "appendReference"].map(kind => ({ kind, id: h(1), maximum: 64n })),
    ...["appendWork", "appendIntent", "appendIntentWaiver", "appendInterview"].map(kind => ({ kind, id: h(1), witness: zero(input(kind)), originalActor: kind === "appendWork" ? ZeroAddress : a(9) })),
    { kind: "appendRights", id: h(1), witness: zero(input("appendRights")) },
    { kind: "appendRootAuthorization", id: h(1), actor: a(9), observedAt: 1n, originalAggregate: { revision: 1n, transitionChain: h(4) }, originalLegacyFamilyHash: h(5) },
    { kind: "appendTokenOutput", id: h(1), payload: { tokenId: 9n, image: "0x", animation: "0x1234" } },
    ...["appendInterviewWaiver", "appendDefinition", "appendTokenScript", "appendTokenLibrary", "appendTokenRenderer", "appendTokenCitation", "sealInventory"].map(kind => ({ kind, id: h(1) })),
  ];
  assert.equal(requests.length, 17);
  for (const q of requests) {
    const prepared = p.prepareScopedPolicyInventoryV2Call(c, a(88), q);
    assert.equal(prepared.call.data.slice(0, 10), abi.inventory.getFunction(q.kind).selector);
    assert.equal(prepared.call.to, c.inventory); assert.equal(prepared.call.value, 0n); assert.equal(prepared.caller, a(88));
    assert.equal(prepared.factsVerified, false); assert.deepEqual(p.normalizeScopedPolicyInventoryV2Call(prepared), prepared);
    assert.throws(() => p.normalizeScopedPolicyInventoryV2Call({ ...prepared, call: { ...prepared.call, value: 1n } }), /reconstruction/);
  }
});

test("supplied inputs are detached, strict arrays and full calldata size are bounded", () => {
  const witness = zero(input("appendWork"));
  const plan = p.prepareScopedPolicyInventoryV2Call(c, a(8), { kind: "appendWork", id: h(1), witness, originalActor: ZeroAddress });
  witness.full.title = "changed";
  assert.equal(plan.request.witness.full.title, ""); assert(Object.isFrozen(plan.request.witness.full));
  const hole = []; hole.length = 1;
  assert.throws(() => p.normalizeScopedPolicyInventoryV2Work({ ...witness, full: { ...witness.full, alternateTitles: hole } }), /dense/);
  const huge = { ...witness, absence: { ...witness.absence, reason: "x".repeat(p.SCOPED_POLICY_INVENTORY_V2_MAX_BYTES) } };
  assert.throws(() => p.prepareScopedPolicyInventoryV2Call(c, a(8), { kind: "appendWork", id: h(1), witness: huge, originalActor: ZeroAddress }), /oversized/);
  for (const maximum of [0n, 65n, 1n << 64n]) assert.throws(() => p.prepareScopedPolicyInventoryV2Call(c, a(8), { kind: "appendNative", id: h(1), maximum }));
});

test("stage and token phase checks do not skip definitions or claim an incomplete seal", () => {
  const plan = zero(output("plan")); plan.scope = { ...scope };
  Object.assign(plan.progress, { collectionId: 7n, tokenCount: 1n, completedStages: 8n });
  const t = { phase: 3n, row: 0n, count: 0n };
  assert.doesNotThrow(() => p.validateScopedPolicyInventoryV2Stage(plan, t, { kind: "appendTokenRenderer", id: h(1) }));
  assert.throws(() => p.validateScopedPolicyInventoryV2Stage(plan, t, { kind: "appendTokenCitation", id: h(1) }), /phase/);
  assert.throws(() => p.validateScopedPolicyInventoryV2Stage(plan, t, { kind: "sealInventory", id: h(1) }), /incomplete/);
  plan.progress.nextToken = 1n;
  assert.doesNotThrow(() => p.validateScopedPolicyInventoryV2Stage(plan, { phase: 0n, row: 0n, count: 0n }, { kind: "sealInventory", id: h(1) }));
});

test("legacy Work actor zero and retained empty-relay signature limitation remain distinct", () => {
  assert.equal(p.validateScopedPolicyInventoryV2WorkActor(ZeroAddress, z), ZeroAddress);
  assert.equal(p.validateScopedPolicyInventoryV2WorkActor(a(1), h(1)), a(1));
  assert.throws(() => p.validateScopedPolicyInventoryV2WorkActor(a(1), z), /branch/);
  assert.throws(() => p.validateScopedPolicyInventoryV2WorkActor(ZeroAddress, h(1)), /branch/);
  assert.doesNotThrow(() => p.validateScopedPolicyInventoryV2OriginalAuthorization(a(1), a(1), true, "0x"));
  assert.doesNotThrow(() => p.validateScopedPolicyInventoryV2OriginalAuthorization(a(2), a(1), false, "0x1234"));
  assert.throws(() => p.validateScopedPolicyInventoryV2OriginalAuthorization(a(2), a(1), false, "0x"), /authorization/);
});

test("read plans retain zero historical IDs and full uint64 indexes without inventing item getters", () => {
  const read = p.prepareScopedPolicyInventoryV2Read(c, ZeroAddress, { kind: "inventorySegment", id: z, index: (1n << 64n) - 1n });
  assert.equal(read.call.data, abi.inventory.encodeFunctionData("inventorySegment", [z, (1n << 64n) - 1n]));
  assert.deepEqual(p.normalizeScopedPolicyInventoryV2Read(read), read);
  assert.throws(() => p.normalizeScopedPolicyInventoryV2Read({ ...read, factsVerified: true }), /reconstruction/);
  assert.throws(() => p.prepareScopedPolicyInventoryV2Call(c, a(8), { kind: "beginInventory", scope: { ...scope, scopeType: 4n } }));
});
