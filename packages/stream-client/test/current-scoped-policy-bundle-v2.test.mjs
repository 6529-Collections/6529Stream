import assert from "node:assert/strict";
import test from "node:test";
import { AbiCoder, ZeroAddress, ZeroHash, id, keccak256, sha256 } from "ethers";
import * as p from "../dist/current-scoped-policy-bundle-v2.js";
import * as inventory from "../dist/current-scoped-policy-inventory-v2.js";
import { fixture, compiledInterfaces as abi } from "./current-scoped-policy-inventory-archive-v2-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder(), z = ZeroHash;
const h = n => `0x${n.toString(16).padStart(64, "0")}`;
const a = n => `0x${n.toString(16).padStart(40, "0")}`;
const c = { chainId: 1n << 128n, core: a(1), bundle: a(2) };
const scope = { scopeType: 1n, collectionId: 7n, tokenId: 9n, scopeId: z };
const raw = id("RAW_BYTES"), jcs = id("RFC8785_JCS");
function zero(t) {
  if (t.baseType === "tuple") return Object.fromEntries(t.components.map(f => [f.name, zero(f)]));
  if (t.baseType === "array") return Array.from({ length: Math.max(t.arrayLength, 0) }, () => zero(t.arrayChildren));
  if (t.type.startsWith("uint")) return 0n;
  if (t.type === "address") return ZeroAddress;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  return t.type === "bytes" ? "0x" : `0x${"00".repeat(Number(t.type.slice(5)))}`;
}
const itemType = abi.bundle.getFunction("coverNext").inputs[1];
const proofType = abi.bundle.getFunction("coverNext").inputs[3];
const admissionType = abi.bundle.getFunction("admittedItem").outputs[1];
const inventoryType = abi.inventory.getFunction("inventoryEvidence").outputs[0];
const evidenceType = abi.bundle.getFunction("bundleEvidence").outputs[0];
const row = () => ({ ...zero(itemType), kind: 7n, role: h(1), source: a(3), sourceRecord: h(2) });
const noProof = { backend: 0n, coverageHash: z, objectHash: z };
const deps = () => ({ targets: [c.core, a(4), a(5), a(6), a(7), a(8)],
  codeHashes: [h(1), h(2), h(3), h(4), h(5), h(6)], chainId: c.chainId, readGas: 50000n, archiveGas: 60000n });

test("bundle scope exposes exactly five original nonpayable writes and keeps its own profile", () => {
  assert.equal(p.SCOPED_POLICY_BUNDLE_V2_SOURCE, fixture.sourceCommit);
  assert.equal(p.SCOPED_POLICY_BUNDLE_V2_PROFILE, id("6529STREAM_SCOPED_POLICY_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V2"));
  const writes = p.scopedPolicyBundleV2Interface().fragments.filter(f => f.type === "function" && f.stateMutability === "nonpayable");
  assert.deepEqual(writes.map(f => f.name).sort(), ["beginCoverage", "beginRefresh", "coverEmptySegment", "coverNext", "refreshNext"].sort());
  assert.throws(() => p.prepareScopedPolicyBundleV2Call(c, a(9), { kind: "requireCoverage", id: h(1) }), /Unknown/);
});

test("raw codecs retain empty admissions/progress and reject dirty or trailing encodings", () => {
  for (const [name, type] of [
    ["Admission", admissionType], ["Proof", proofType], ["Evidence", evidenceType],
    ["Progress", abi.bundle.getFunction("progress").outputs[0]], ["Refresh", abi.bundle.getFunction("refresh").outputs[0]],
  ]) {
    const value = zero(type), bytes = coder.encode([type], [value]);
    assert.deepEqual(p[`decodeScopedPolicyBundleV2${name}`](bytes), value);
    assert.throws(() => p[`decodeScopedPolicyBundleV2${name}`](`${bytes}${"00".repeat(32)}`), /Noncanonical/);
  }
  const type = abi.bundle.getFunction("progress").outputs[0], value = zero(type);
  value.itemCount = (1n << 64n) - 1n;
  assert.equal(p.normalizeScopedPolicyBundleV2Progress(value).itemCount, value.itemCount);
  assert.throws(() => p.normalizeScopedPolicyBundleV2Progress({ ...value, itemCount: 1n << 64n }), /uint64/);
  const bytes = coder.encode([type], [value]);
  assert.throws(() => p.decodeScopedPolicyBundleV2Progress(`${bytes.slice(0, -2)}02`), /Noncanonical/);
});

test("absent, empty bytes, empty package members and OS prerequisites retain separate applicability", () => {
  const examples = [row(), { ...row(), kind: 9n, algorithm: 1n, canonicalizationId: raw, digest: keccak256("0x") },
    { ...row(), kind: 11n, algorithm: 2n, canonicalizationId: raw, digest: sha256("0x"), uri: "empty.bin" },
    { ...row(), kind: 8n, algorithm: 2n, canonicalizationId: raw, digest: h(3), byteSize: 10n, uri: "runtime.os" }];
  const hashes = new Set();
  for (const item of examples) {
    const admission = p.scopedPolicyBundleV2IntrinsicAdmission(item, noProof);
    const expected = keccak256(coder.encode(["bytes32", itemType], [id("EXPLICIT_INVENTORY_APPLICABILITY"), item]));
    assert.equal(admission.originalBundleHash, expected); hashes.add(expected);
    assert.deepEqual(p.validateScopedPolicyBundleV2Admission(h(8), item, admission), admission);
    assert.throws(() => p.validateScopedPolicyBundleV2Proof({ ...item, catalogId: h(7) }, noProof), /catalog/);
    assert.throws(() => p.validateScopedPolicyBundleV2Proof(item, { ...noProof, coverageHash: h(3) }), /no-proof/);
  }
  assert.equal(hashes.size, 4);
  assert.throws(() => p.validateScopedPolicyBundleV2Proof({ ...examples[2], digest: keccak256("0x") }, noProof), /EMPTY_PACKAGE/);
  assert.throws(() => p.validateScopedPolicyBundleV2Proof({ ...examples[3], byteSize: 0n }, noProof), /NATIVE_OS/);
});

test("state bundle admission commits supplied immutable parts and cannot stand in for their readback", () => {
  const item = { ...row(), kind: 6n, sourceIndex: 1n, algorithm: 1n, canonicalizationId: raw, digest: h(4), byteSize: 20n };
  const parts = h(5);
  const result = p.scopedPolicyBundleV2IntrinsicAdmission(item, noProof, parts);
  assert.equal(result.originalBundleHash, keccak256(coder.encode(["bytes32", itemType, "bytes32"],
    [id("STATE_RETAINED_ORIGINAL_AUTHORIZATION"), item, parts])));
  assert.throws(() => p.validateScopedPolicyBundleV2Proof({ ...item, sourceIndex: 0n }, noProof), /STATE_BUNDLE/);
  assert.throws(() => p.validateScopedPolicyBundleV2Admission(h(8), item, { ...result, originalBundleHash: h(6) }), /differs/);
});

test("original backend and digest restrictions are distinct from structural Item encoding", () => {
  const item = { ...row(), kind: 4n, algorithm: 2n, canonicalizationId: raw, digest: h(4), byteSize: 20n };
  const external = { backend: 1n, objectHash: h(5), coverageHash: h(6) };
  assert.deepEqual(p.validateScopedPolicyBundleV2Proof(item, external), external);
  assert.throws(() => p.validateScopedPolicyBundleV2Proof(item, { ...external, backend: 2n }), /correspondence/);
  assert.throws(() => p.validateScopedPolicyBundleV2Proof({ ...item, kind: 10n }, external), /backend/);
  assert.throws(() => p.validateScopedPolicyBundleV2Proof({ ...item, algorithm: 6n }, external), /correspondence/);
  assert.throws(() => p.validateScopedPolicyBundleV2Proof({ ...item, objectHash: h(7) }, external), /differs/);
  assert.equal(inventory.normalizeScopedPolicyInventoryV2Item({ ...item, algorithm: 6n }).algorithm, 6n);
});

test("correspondence supports only the original full digest, size and canonicalization relationships", () => {
  const item = { ...row(), kind: 4n, algorithm: 1n, canonicalizationId: jcs, digest: h(4), byteSize: 0n };
  const object = { contentHash: h(4), sha256Digest: h(5), canonicalizationId: jcs, byteSize: 999n };
  assert.deepEqual(p.validateScopedPolicyBundleV2Correspondence(item, object), item);
  assert.throws(() => p.validateScopedPolicyBundleV2Correspondence({ ...item, byteSize: 20n }, object), /differs/);
  assert.throws(() => p.validateScopedPolicyBundleV2Correspondence(item, { ...object, byteSize: 0n }), /differs/);
  assert.throws(() => p.validateScopedPolicyBundleV2Correspondence({ ...item, canonicalizationId: h(7) }, { ...object, canonicalizationId: h(7) }), /differs/);
  assert.doesNotThrow(() => p.validateScopedPolicyBundleV2Correspondence({ ...item, kind: 5n, canonicalizationId: h(7) }, { ...object, canonicalizationId: h(7) }));
});

test("per-occurrence links prevent duplicate collapse, skipping and false empty-segment consumption", () => {
  const item = row(), key = h(7), segment = inventory.scopedPolicyInventoryV2Segment(key, h(8), [item, item]);
  const tail = inventory.scopedPolicyInventoryV2Link(key, 2n, 1n, item, z);
  const progress = { ...zero(abi.bundle.getFunction("progress").outputs[0]), nextLink: segment.firstLink };
  assert.doesNotThrow(() => p.validateScopedPolicyBundleV2NextItem(progress, segment, item, tail));
  assert.throws(() => p.validateScopedPolicyBundleV2NextItem(progress, segment, item, z), /link/);
  assert.throws(() => p.validateScopedPolicyBundleV2EmptySegment(progress, segment), /empty/);
  // Consumer-only generic case; no assertion that concrete ABI129 inventory produces an empty segment.
  const empty = inventory.scopedPolicyInventoryV2Segment(key, h(8), []);
  assert.doesNotThrow(() => p.validateScopedPolicyBundleV2EmptySegment({ ...progress, nextLink: z }, empty));
});

test("environment and refresh preimages include full dependencies and retain zero external revision", () => {
  const d = deps(), dependencyHash = p.scopedPolicyBundleV2DependencyHash(d);
  p.validateScopedPolicyBundleV2Dependencies(c, d);
  const environment = p.scopedPolicyBundleV2EnvironmentHash(d, h(1), 1n, h(2), 0n);
  const expected = keccak256(coder.encode(["bytes32", abi.bundle.getFunction("dependencies").outputs[0], "bytes32", "uint64", "bytes32", "uint64"],
    [id("6529STREAM_BUNDLE_IMMUTABLE_STOP_ENVIRONMENT_V1"), d, h(1), 1n, h(2), 0n]));
  assert.equal(environment, expected);
  assert.equal(p.scopedPolicyBundleV2RefreshId(c, dependencyHash, h(3), environment), keccak256(coder.encode(
    ["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_SCOPED_POLICY_BUNDLE_REFRESH_V2"), c.chainId, c.bundle, dependencyHash, h(3), environment])));
  assert.throws(() => p.scopedPolicyBundleV2EnvironmentHash(d, h(1), 0n, h(2), 0n), /epoch/);
  assert.throws(() => p.validateScopedPolicyBundleV2Dependencies(c, { ...d, archiveGas: 49999n }), /floors/);
  assert.equal(p.normalizeScopedPolicyBundleV2Progress({ ...zero(abi.bundle.getFunction("progress").outputs[0]), environmentHash: z }).environmentHash, z);
});

test("coverage commits full source inventory and zeroes only the resulting coverage hash", () => {
  const original = zero(inventoryType), e = zero(evidenceType);
  original.scope = { ...scope }; e.scope = { ...scope };
  Object.assign(original.inventory, { planId: h(1), renderCriticalEvidenceHash: h(2), itemCount: 3n });
  Object.assign(e.coverage, { inventoryPlan: h(1), renderCriticalEvidenceHash: h(2), itemCount: 3n, evidenceChainHash: h(3) });
  const dependency = p.scopedPolicyBundleV2DependencyHash(deps());
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "bytes32", inventoryType, evidenceType],
    [id("6529STREAM_SCOPED_POLICY_BUNDLE_ARCHIVE_COVERAGE_V2"), c.chainId, c.bundle, dependency, p.SCOPED_POLICY_BUNDLE_V2_PROFILE, original, e]));
  e.coverage.bundleCoverageHash = expected;
  assert.equal(p.validateScopedPolicyBundleV2Evidence(c, dependency, original, e).coverage.bundleCoverageHash, expected);
  const bad = structuredClone(e); bad.scope.collectionId++;
  bad.coverage.bundleCoverageHash = p.scopedPolicyBundleV2CoverageHash(c, dependency, original, bad);
  assert.throws(() => p.validateScopedPolicyBundleV2Evidence(c, dependency, original, bad), /differs/);
  assert.notEqual(p.scopedPolicyBundleV2CoverageHash(c, dependency, { ...original, inventory: { ...original.inventory, artistId: h(9) } }, e), expected);
});

test("current external pair refresh changes fixity observations without replacing original receipts", () => {
  const original = zero(admissionType.components[3]);
  for (const key of Object.keys(original)) original[key] = key === "byteSize" ? 100n : h(1);
  const current = { ...original, firstFixityHash: h(2), secondFixityHash: h(3) }; delete current.coverageHash;
  assert.equal(p.scopedPolicyBundleV2CurrentPairHash(original, current), keccak256(coder.encode([abi.externalCoverage.getFunction("currentReceiptPair").outputs[0]], [current])));
  assert.throws(() => p.scopedPolicyBundleV2CurrentPairHash(original, { ...current, firstReceiptHash: h(4) }), /immutable/);
  assert.throws(() => p.scopedPolicyBundleV2CurrentPairHash(original, { ...current, firstFixityHash: z }), /nonzero/);
});

test("all five calls preserve exact original ABI and immutable caller/value independently of proofs", () => {
  const requests = [
    { kind: "beginCoverage", id: h(1) }, { kind: "coverEmptySegment", id: h(1) }, { kind: "beginRefresh", id: h(1) },
    { kind: "coverNext", id: h(1), item: row(), nextLink: z, proof: { ...noProof } },
    { kind: "refreshNext", id: h(1), expectedIndex: (1n << 64n) - 1n },
  ];
  for (const q of requests) {
    const call = p.prepareScopedPolicyBundleV2Call(c, a(9), q);
    const args = q.kind === "coverNext" ? [q.id, q.item, q.nextLink, q.proof] : q.kind === "refreshNext" ? [q.id, q.expectedIndex] : [q.id];
    assert.equal(call.call.data, abi.bundle.encodeFunctionData(q.kind, args));
    assert.equal(call.call.value, 0n); assert.equal(call.call.to, c.bundle); assert.equal(call.factsVerified, false);
    assert.deepEqual(p.normalizeScopedPolicyBundleV2Call(call), call);
    assert.throws(() => p.normalizeScopedPolicyBundleV2Call({ ...call, call: { ...call.call, to: a(99) } }), /reconstruction/);
  }
  const request = requests[3], copy = p.prepareScopedPolicyBundleV2Call(c, a(9), request);
  request.item.role = h(99); request.proof.backend = 2n;
  assert.equal(copy.request.item.role, h(1)); assert.equal(copy.request.proof.backend, 0n);
  assert(Object.isFrozen(copy.request.item));
});

test("closed reads, complete calldata limits and strict supplied record objects are enforced", () => {
  const read = p.prepareScopedPolicyBundleV2Read(c, ZeroAddress, { kind: "admittedItem", id: z, index: 0n });
  assert.equal(read.call.data, abi.bundle.encodeFunctionData("admittedItem", [z, 0n]));
  assert.deepEqual(p.normalizeScopedPolicyBundleV2Read(read), read);
  assert.throws(() => p.prepareScopedPolicyBundleV2Read(c, a(1), { kind: "requireCurrent", scope }), /Unknown/);
  assert.throws(() => p.prepareScopedPolicyBundleV2Read(c, a(1), { kind: "requireCoverage", scope: { ...scope, scopeType: 4n }, id: h(1), expectedHash: h(2) }));
  const item = { ...row(), kind: 4n, algorithm: 1n, canonicalizationId: raw, digest: h(4), uri: "x".repeat(p.SCOPED_POLICY_BUNDLE_V2_MAX_BYTES) };
  assert.throws(() => p.prepareScopedPolicyBundleV2Call(c, a(1), { kind: "coverNext", id: h(1), item, nextLink: z, proof: { backend: 1n, objectHash: h(5), coverageHash: h(6) } }), /oversized/);
  assert.throws(() => p.normalizeScopedPolicyBundleV2Proof({ ...noProof, backend: 0 }), /bigint/);
});
