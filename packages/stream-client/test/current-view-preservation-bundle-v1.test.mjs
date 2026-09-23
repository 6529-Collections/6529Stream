import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, ZeroHash, getAddress, id, keccak256, sha256 } from "ethers";
import * as api from "../dist/current-view-preservation-bundle-v1.js";
import * as inventory from "../dist/current-view-preservation-inventory-v1.js";
import * as retrieval from "../dist/current-view-retrieval-v1.js";
import { toSafeCall } from "../dist/safe.js";
import { compiledInterfaces } from "./current-view-preservation-consumers-v1-fixture.mjs";

const host = compiledInterfaces.StreamViewPreservationBundleArchiveCoverageV1;
const ihost = compiledInterfaces.StreamViewPreservationRenderCriticalInventoryV1;
const whost = compiledInterfaces.IStreamViewRetrievalWitnessV1;
const coder = AbiCoder.defaultAbiCoder(), Z = ZeroHash;
const A = n => getAddress("0x" + n.toString(16).padStart(40, "0"));
const H = s => id("view-bundle-test:" + s);
const c = { chainId: 1n, core: A(1), bundle: A(30) };
const scope = { scopeType: 4n, collectionId: 9n, tokenId: 0n, scopeId: H("scope") };
const dType = host.getFunction("dependencies").outputs[0];
const eType = host.getFunction("bundleEvidence").outputs[0];
const aType = host.getFunction("admittedItem").outputs[1];
const itemType = host.getFunction("coverNext").inputs[1];
const iType = ihost.getFunction("inventoryEvidence").outputs[0];
const sourceType = whost.getFunction("requireCorrespondence").outputs[0];
const receiptType = whost.getFunction("record").outputs[0];
const configType = whost.getFunction("configuration").outputs[0];
const clone = structuredClone;
const hash = (types, values) => keccak256(coder.encode(types, values));
function zero(p) {
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(q => [q.name, zero(q)]));
  if (p.baseType === "array") return p.arrayLength < 0 ? [] : Array.from({ length: p.arrayLength }, () => zero(p.arrayChildren));
  if (p.type === "address") return ZeroAddress;
  if (p.type === "string") return "";
  if (p.type === "bytes") return "0x";
  if (p.type.startsWith("bytes")) return "0x" + "00".repeat(Number(p.type.slice(5)));
  if (p.type === "bool") return false;
  return 0n;
}
function sample(uri = "https://Archive.example/item%2f") {
  const d = zero(dType);
  d.targets = d.targets.map((_, i) => A(i + 1));
  d.codeHashes = d.codeHashes.map((_, i) => H("runtime" + i));
  Object.assign(d, { chainId: 1n, readGas: 50000n, archiveGas: 200000n });
  const source = { ...zero(sourceType), scope: clone(scope), core: c.core, router: A(40),
    declaration: A(41), declarationRecord: H("declaration"), adoptionRecord: H("adoption"),
    adoptionSourceHash: H("adoption-source"), payloadHash: H("payload"), checkpointContextHash: H("context"),
    requestedURI: uri, artistId: H("artist"), artistPresentationHash: H("presentation") };
  const context = zero(ihost.getFunction("sourceContext").outputs[0]);
  Object.assign(context, { scope: clone(scope), artistId: source.artistId, adoptionRecord: source.adoptionRecord,
    payloadHash: source.payloadHash, sourceContextHash: source.checkpointContextHash });
  const config = { ...zero(configType), core: d.targets[0], coreCodeHash: d.codeHashes[0],
    router: source.router, routerCodeHash: H("router-code"), checkpoint: A(45), checkpointCodeHash: H("checkpoint-code"),
    archive: d.targets[4], archiveCodeHash: d.codeHashes[4], chainId: 1n, readGas: 50000n,
    sourceGas: 100000n, archiveGas: 200000n, signatureGas: 100000n };
  const item = inventory.currentViewPreservationInventoryV1Obligation(source);
  const admission = zero(aType);
  Object.assign(admission, { proof: { backend: 1n, objectHash: H("object"), coverageHash: H("coverage") },
    originalBundleHash: H("original-bundle") });
  Object.assign(admission.externalOriginal, { artistId: source.artistId, objectHash: H("object"),
    coverageHash: H("coverage"), contentHash: H("content"), sha256Digest: H("sha"), arweaveDataRoot: H("root"),
    byteSize: 12n, firstReceiptHash: H("receipt1"), secondReceiptHash: H("receipt2"),
    firstFixityHash: H("fixity1"), secondFixityHash: H("fixity2") });
  const receipt = { ...zero(receiptType), recordHash: H("witness"), sourceKey: retrieval.currentViewRetrievalV1SourceKey(source),
    objectHash: admission.proof.objectHash, coverageHash: admission.proof.coverageHash, payloadHash: H("witness-payload") };
  const i = zero(iType), inventoryDependency = H("inventory-dependency"), plan = H("plan");
  i.scope = clone(scope);
  Object.assign(i.inventory, { planId: plan, collectionId: scope.collectionId, artistId: source.artistId,
    scopeSubject: hash(["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"],
      [id("6529STREAM_SUBJECT_SCOPE_V1"), 1n, c.core, scope.collectionId, 4n, scope.scopeId]),
    sourceContextHash: H("full-context"), tokenInventoryHash: H("tokens"), tokenCount: 1n, segmentCount: 1n, itemCount: 1n });
  const segment = inventory.currentViewPreservationInventoryV1Segment(
    inventory.currentViewPreservationInventoryV1SegmentKey(plan, 0n), H("source-witness"), [item]);
  i.inventory.segmentChainHash = inventory.currentViewPreservationInventoryV1AppendSegment(Z, 0n, segment);
  i.inventory.renderCriticalEvidenceHash = inventory.currentViewPreservationInventoryV1EvidenceHash(
    { chainId: 1n, core: c.core, inventory: d.targets[2] }, inventoryDependency, i);
  const dependency = hash([dType], [d]);
  const wrapped = api.validateCurrentViewPreservationBundleV1Retrieval(d, context, item, A(60), H("witness-code"),
    config, receipt.recordHash, source, receipt, admission, H("pair-observation")).admission;
  const chain = api.currentViewPreservationBundleV1CoveredItemChain(Z, plan, 0n,
    inventory.currentViewPreservationInventoryV1ItemHash(item), wrapped);
  const evidence = api.currentViewPreservationBundleV1Evidence(c, dependency, i, chain);
  return { d, source, context, config, item, admission, receipt, i, inventoryDependency, plan, segment, dependency, wrapped, evidence };
}

test("all original public ABI fragments and six ordinary zero-value calls match the compiler", () => {
  assert.deepEqual(api.currentViewPreservationBundleV1Interface().fragments.map(f => f.format("full")).sort(),
    host.fragments.filter(f => f.type !== "constructor").map(f => f.format("full")).sort());
  const s = sample(), requests = [
    { method: "beginCoverage", id: s.plan }, { method: "coverNext", id: s.plan,
      item: { ...zero(itemType), kind: 7n, source: A(4), sourceRecord: H("record"), role: H("role") },
      nextLink: Z, proof: { backend: 0n, coverageHash: Z, objectHash: Z } },
    { method: "coverRetrievalNext", id: s.plan, item: s.item, nextLink: Z, witnessHash: s.receipt.recordHash },
    { method: "coverEmptySegment", id: s.plan }, { method: "beginRefresh", id: s.plan },
    { method: "refreshNext", id: s.plan, expectedIndex: 0n },
  ];
  for (const request of requests) {
    const call = api.prepareCurrentViewPreservationBundleV1Call(c, A(8), request);
    const values = host.getFunction(request.method).inputs.map(p => request[p.name]);
    assert.equal(call.call.data, host.encodeFunctionData(request.method, values));
    assert.equal(toSafeCall(call.call).value, "0");
    assert.equal(toSafeCall(call.call).operation, 0);
    assert.deepEqual(api.normalizeCurrentViewPreservationBundleV1Call(call), call);
  }
});

test("all raw zero codecs preserve absent state and canonical narrow-width decoding", () => {
  const p = zero(host.getFunction("progress").outputs[0]);
  assert.deepEqual(api.decodeCurrentViewPreservationBundleV1Progress(api.encodeCurrentViewPreservationBundleV1Progress(p)), p);
  assert.throws(() => api.decodeCurrentViewPreservationBundleV1Progress(api.encodeCurrentViewPreservationBundleV1Progress(p) + "00"));
  assert.throws(() => api.normalizeCurrentViewPreservationBundleV1Progress({ ...p, complete: 1n }));
  assert.throws(() => api.normalizeCurrentViewPreservationBundleV1Item({ ...zero(itemType), kind: 12n }));
});

test("base and retrieval environment hashes use exact dependency and full-scope revocation inputs", () => {
  const s = sample();
  const expected = hash(["bytes32", dType, "bytes32", "uint64", "bytes32", "uint64"],
    [id("6529STREAM_BUNDLE_IMMUTABLE_STOP_ENVIRONMENT_V1"), s.d, H("onchain"), 2n, H("external"), 3n]);
  assert.equal(api.currentViewPreservationBundleV1BaseEnvironmentHash(s.d, H("onchain"), 2n, H("external"), 3n), expected);
  const scopeType = iType.components[0];
  const wrapped = hash(["bytes32", "bytes32", "address", "bytes32", scopeType, "uint64"],
    [id("6529STREAM_VIEW_RETRIEVAL_ARCHIVE_ENVIRONMENT_V1"), expected, A(60), H("witness-code"), scope, 0n]);
  assert.equal(api.currentViewPreservationBundleV1EnvironmentHash(expected, A(60), H("witness-code"), scope, 0n), wrapped);
  assert.notEqual(api.currentViewPreservationBundleV1EnvironmentHash(expected, A(60), H("witness-code"), scope, 1n), wrapped);
  assert.notEqual(api.currentViewPreservationBundleV1EnvironmentHash(expected, A(60), H("witness-code"), { ...scope, collectionId: 10n }, 0n), wrapped);
});

test("covered-item, observation, coverage and refresh preimages are independently compiler-encoded", () => {
  const s = sample(), itemHash = inventory.currentViewPreservationInventoryV1ItemHash(s.item);
  const chain = hash(["bytes32", "bytes32", "bytes32", "uint64", "bytes32", aType],
    [id("6529STREAM_VIEW_PRESERVATION_BUNDLE_COVERED_ITEM_V1"), Z, s.plan, 0n, itemHash, s.wrapped]);
  assert.equal(s.evidence.coverage.evidenceChainHash, chain);
  const e = clone(s.evidence); e.coverage.bundleCoverageHash = Z;
  assert.equal(s.evidence.coverage.bundleCoverageHash,
    hash(["bytes32", "uint256", "address", "bytes32", "bytes32", iType, eType],
      [id("6529STREAM_VIEW_PRESERVATION_BUNDLE_ARCHIVE_COVERAGE_V1"), 1n, c.bundle, s.dependency,
        id("6529STREAM_VIEW_PRESERVATION_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1"), s.i, e]));
  assert.equal(api.currentViewPreservationBundleV1RefreshId(c, s.dependency, s.plan, H("environment")),
    hash(["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_VIEW_PRESERVATION_BUNDLE_REFRESH_V1"), 1n, c.bundle, s.dependency, s.plan, H("environment")]));
  assert.equal(api.currentViewPreservationBundleV1ObservationChain(Z, 0n, itemHash, Z),
    hash(["bytes32", "bytes32", "uint64", "bytes32", "bytes32"],
      [id("6529STREAM_VIEW_PRESERVATION_BUNDLE_CURRENT_OBSERVATION_V1"), Z, 0n, itemHash, Z]));
});

test("retrieval wrapping and observation bind original witness record and full checkpoint context", () => {
  const s = sample();
  const configurationHash = hash(["bytes32", configType], [id("6529STREAM_VIEW_ATTRIBUTED_RETRIEVAL_V1"), s.config]);
  const expected = hash(["bytes32", "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_VIEW_RETRIEVAL_ADMITTED_BUNDLE_V1"), s.admission.originalBundleHash, A(60), H("witness-code"),
      configurationHash, s.receipt.recordHash, s.receipt.payloadHash]);
  assert.equal(s.wrapped.originalBundleHash, expected);
  assert.equal(api.currentViewPreservationBundleV1CurrentObservationHash(s.source, s.receipt, H("pair")),
    hash(["bytes32", sourceType, receiptType, "bytes32"],
      [id("6529STREAM_VIEW_RETRIEVAL_CURRENT_OBSERVATION_V1"), s.source, s.receipt, H("pair")]));
  const bad = { ...s.source, checkpointContextHash: H("other") };
  assert.equal(retrieval.currentViewRetrievalV1SourceKey(bad), s.receipt.sourceKey);
  assert.throws(() => api.validateCurrentViewPreservationBundleV1Retrieval(s.d, s.context, s.item, A(60), H("witness-code"),
    s.config, s.receipt.recordHash, bad, s.receipt, s.admission, H("pair")), /Checkpoint/);
});

test("supplied retrieval relation rejects altered scope, artist, object, payload and role", () => {
  const s = sample();
  const run = (source = s.source, receipt = s.receipt, admission = s.admission, item = s.item) =>
    api.validateCurrentViewPreservationBundleV1Retrieval(s.d, s.context, item, A(60), H("witness-code"),
      s.config, s.receipt.recordHash, source, receipt, admission, H("pair"));
  for (const mutate of [v => { v.scope.collectionId++; }, v => { v.artistId = H("other"); }, v => { v.adoptionRecord = H("other"); }]) {
    const value = clone(s.source); mutate(value); assert.throws(() => run(value));
  }
  assert.throws(() => run(s.source, { ...s.receipt, payloadHash: Z }));
  assert.throws(() => run(s.source, { ...s.receipt, objectHash: H("other") }));
  assert.throws(() => run(s.source, s.receipt, s.admission, { ...s.item, role: H("other") }));
});

test("stored witness mapping chooses replay even for original exact-locator items", () => {
  const s = sample("https://archive.example/object");
  assert.equal(s.item.role, id("VIEW_ARCHIVE_LOCATOR_IMAGE"));
  assert.equal(api.currentViewPreservationBundleV1CurrentRoute(Z), "generic");
  assert.equal(api.currentViewPreservationBundleV1CurrentRoute(s.receipt.recordHash), "retrieval");
  api.validateCurrentViewPreservationBundleV1Admission(s.source.artistId, s.item, s.admission);
  assert.throws(() => api.validateCurrentViewPreservationBundleV1Proof(sample().item, s.admission.proof), /Retrieval/);
});

test("intrinsic absent and empty byte rows use canonical no-proof and original applicability hashes", () => {
  const row = { ...zero(itemType), kind: 7n, role: H("optional"), source: A(4), sourceRecord: H("record") };
  const proof = { backend: 0n, coverageHash: Z, objectHash: Z };
  for (const item of [row, { ...row, kind: 9n, algorithm: 1n, canonicalizationId: id("RAW_BYTES"), digest: keccak256("0x") },
    { ...row, kind: 11n, algorithm: 2n, canonicalizationId: id("RAW_BYTES"), digest: sha256("0x"), uri: "member" }]) {
    const result = api.currentViewPreservationBundleV1IntrinsicAdmission(item, proof);
    assert.equal(result.originalBundleHash, hash(["bytes32", itemType], [id("EXPLICIT_INVENTORY_APPLICABILITY"), item]));
  }
  assert.throws(() => api.currentViewPreservationBundleV1IntrinsicAdmission({ ...row, byteSize: 1n }, proof));
  assert.throws(() => api.currentViewPreservationBundleV1IntrinsicAdmission(row, { ...proof, backend: 1n }));
});

test("generic empty segments remain explicit consumer shapes and do not assert producer reachability", () => {
  const s = inventory.currentViewPreservationInventoryV1Segment(H("key"), H("source-empty"), []);
  const p = zero(host.getFunction("progress").outputs[0]);
  api.validateCurrentViewPreservationBundleV1EmptySegment(p, s);
  assert.throws(() => api.validateCurrentViewPreservationBundleV1EmptySegment({ ...p, nextLink: H("next") }, s));
  assert.throws(() => api.validateCurrentViewPreservationBundleV1EmptySegment({ ...p, complete: true }, s));
});

test("local history verifies stored row order and leaves currentness and initial private chain unclaimed", () => {
  const s = sample(), rows = [{ item: s.item, admission: s.wrapped, witnessHash: s.receipt.recordHash }];
  const result = api.authenticateCurrentViewPreservationBundleV1History(c, s.d, s.inventoryDependency, s.i, s.evidence,
    [{ segment: s.segment, items: [s.item] }], rows);
  assert.equal(result.currentnessVerified, false);
  assert.equal(result.initialObservationIndependentlyReconstructed, false);
  assert.equal(result.retrievalCorrespondenceIndependentlyReconstructed, false);
  assert.throws(() => { result.rows[0].witnessHash = Z; }, TypeError);
  assert.throws(() => api.authenticateCurrentViewPreservationBundleV1History(c, s.d, s.inventoryDependency, s.i, s.evidence,
    [{ segment: s.segment, items: [s.item] }], [{ ...rows[0], witnessHash: Z }]), /Retrieval/);
});

test("fully rehashed retrieval and old-locator histories reject impossible retained external fields", () => {
  for (const uri of ["https://Archive.example/a%20", "https://archive.example/a"]) {
    const s = sample(uri);
    for (const mutate of [
      a => { a.externalOriginal.artistId = H("wrong"); },
      a => { a.externalOriginal.objectHash = H("wrong"); },
      a => { a.externalOriginal.coverageHash = H("wrong"); },
      a => { a.immutablePartsHash = H("wrong"); },
      a => { a.onchainOriginal.byteLength = 1n; },
      a => { a.externalOriginal.firstFixityHash = Z; },
    ]) {
      const admission = clone(s.wrapped); mutate(admission);
      const chain = api.currentViewPreservationBundleV1CoveredItemChain(Z, s.plan, 0n,
        inventory.currentViewPreservationInventoryV1ItemHash(s.item), admission);
      const evidence = api.currentViewPreservationBundleV1Evidence(c, s.dependency, s.i, chain);
      assert.throws(() => api.authenticateCurrentViewPreservationBundleV1History(c, s.d, s.inventoryDependency, s.i, evidence,
        [{ segment: s.segment, items: [s.item] }], [{ item: s.item, admission, witnessHash: s.receipt.recordHash }]));
    }
  }
});

test("refresh uses exact public prestate and zero observations remain meaningful original values", () => {
  const s = sample(), before = { environmentHash: H("environment"), nextIndex: 0n, currentObservationChain: Z, complete: false };
  const after = api.currentViewPreservationBundleV1RefreshStep(before, 0n, 1n, s.item, Z);
  assert.equal(after.complete, true);
  assert.equal(after.nextIndex, 1n);
  assert.notEqual(after.currentObservationChain, Z);
  assert.throws(() => api.currentViewPreservationBundleV1RefreshStep(before, 1n, 2n, s.item, Z));
  assert.throws(() => api.currentViewPreservationBundleV1RefreshStep(after, 1n, 2n, s.item, Z));
});

test("bounded call ownership and exact read plans reject substituted transport values", () => {
  const s = sample(), call = api.prepareCurrentViewPreservationBundleV1Call(c, A(8),
    { method: "coverRetrievalNext", id: s.plan, item: s.item, nextLink: Z, witnessHash: s.receipt.recordHash });
  for (const delta of [{ value: 1n }, { data: "0x" }, { to: A(90) }]) {
    assert.throws(() => api.normalizeCurrentViewPreservationBundleV1Call({ ...call, call: { ...call.call, ...delta } }));
  }
  assert.throws(() => api.prepareCurrentViewPreservationBundleV1Call(c, A(8), { method: "publish", id: s.plan }));
  assert.throws(() => api.prepareCurrentViewPreservationBundleV1Call(c, A(8),
    { method: "coverRetrievalNext", id: s.plan, item: { ...s.item, uri: "x".repeat(2097000) }, nextLink: Z, witnessHash: s.receipt.recordHash }), /bound/);
  const read = api.prepareCurrentViewPreservationBundleV1Read(c, { method: "retrievalWitnessForItem", id: s.plan, index: 0n });
  assert.equal(read.call.data, host.encodeFunctionData("retrievalWitnessForItem", [s.plan, 0n]));
});
