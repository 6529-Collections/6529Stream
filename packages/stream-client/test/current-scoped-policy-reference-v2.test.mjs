import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, ZeroHash, getAddress, id, keccak256, sha256, toUtf8Bytes, hexlify } from "ethers";
import * as ref from "../dist/current-scoped-policy-reference-v2.js";
import * as graph from "../dist/current-scoped-policy-graph-v2.js";
import * as root from "../dist/current-scoped-policy-root-v2.js";
import * as environment from "../dist/current-reference-environment.js";
import * as inventory from "../dist/current-reference-inventory.js";
import { compiledInterfaces as abi } from "./current-scoped-policy-reference-v2-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const h = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
const coordinates = { chainId: (1n << 230n) + 5n, core: address(1), metadata: address(2), reference: address(3) };
const caller = address(4);
const scope = { scopeType: 1n, collectionId: (1n << 200n) + 7n, tokenId: (1n << 220n) + 8n, scopeId: ZeroHash };
const publicationType = abi.reference.getFunction("publishReference").inputs[0];
const receiptType = abi.reference.getFunction("currentReference").outputs[0];
const sourceType = abi.reference.getFunction("referenceSource").outputs[0];
const dependencyType = abi.reference.getFunction("dependencies").outputs[0];
const payloadTypes = ["bytes32", "uint256", "address", publicationType, receiptType, sourceType, "bytes"];

function zero(type) {
  if (type.baseType === "tuple") return Object.fromEntries(type.components.map(t => [t.name, zero(t)]));
  if (type.baseType === "array") return Array.from({ length: Math.max(0, type.arrayLength) }, () => zero(type.arrayChildren));
  if (type.type.startsWith("uint")) return 0n;
  if (type.type === "address") return ZeroAddress;
  if (type.type === "bool") return false;
  if (type.type === "string") return "";
  return type.type === "bytes" ? "0x" : `0x${"00".repeat(Number(type.type.slice(5)))}`;
}

function runtime() {
  const e = { objectHash: h(11), coverageHash: h(12), manifestHash: ZeroHash, manifestBytes: 0n,
    engineName: "Browser", engineVersion: "1", engineExecutableSha256: h(13), toolchainName: "Capture",
    toolchainVersion: "1", toolchainSha256: h(14), engineExecutablePath: "engine.exe", toolchainPath: "tool.exe",
    packageFiles: [{ path: "engine.exe", byteSize: 2n, sha256Digest: h(13) }, { path: "tool.exe", byteSize: 3n, sha256Digest: h(14) }],
    platformPrerequisites: [{ path: "C:\\Windows\\é.dll", byteSize: 0n, sha256Digest: h(15) }],
    operatingSystem: "Windows", operatingSystemVersion: "Server", architecture: "AMD64", viewportWidth: 4096n,
    viewportHeight: 1n, devicePixelRatio: 1n, colorSpace: "srgb", softwareRasterization: true,
    captureProfile: id("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1"), licenseNote: "undetermined" };
  const canonical = environment.referenceEnvironmentCanonicalBytes(e);
  return { ...e, manifestHash: keccak256(canonical), manifestBytes: BigInt((canonical.length - 2) / 2) };
}

function publication() {
  const e = runtime(), html = hexlify(toUtf8Bytes("<html>作品</html>"));
  return { scope: structuredClone(scope), observation: { collectionId: scope.collectionId,
    referenceId: h(20), expectedHead: ZeroHash, expectedRevision: 0n, snapshotRecordHash: h(21), snapshotRevision: 1n,
    expectedSourcesHash: h(22), captures: [{ tokenId: scope.tokenId, collectionSerial: (1n << 200n) + 9n,
      metadataJSONHash: h(23), htmlHash: keccak256(html), htmlBytes: BigInt((html.length - 2) / 2), animationHTML: html,
      objectHash: h(24), coverageHash: h(25), sourceSha256: sha256(html), repeatCaptureSha256: [h(26), h(26)],
      environmentManifestHash: e.manifestHash, capturedAt: 10n }], environment: e, manifestURI: "",
    effectiveAt: 10n, reasonHash: h(27) } };
}

function dependencies() {
  return { targets: Array.from({ length: 7 }, (_, i) => address(i + 1)),
    codeHashes: Array.from({ length: 7 }, (_, i) => h(i + 101)), chainId: coordinates.chainId,
    readGas: 50000n, sourceGas: 100000n, snapshotGas: 200000n, archiveGas: 100000n };
}

function sourceFacts(p = publication()) {
  const d = dependencies();
  const sd = zero(abi.snapshot.getFunction("dependencies").outputs[0]);
  sd.chainId = coordinates.chainId;
  sd.targets = [...d.targets.slice(0, 5), ...Array.from({ length: 6 }, (_, i) => address(30 + i))];
  sd.codeHashes = [...d.codeHashes.slice(0, 5), ...Array.from({ length: 6 }, (_, i) => h(130 + i))];
  const f = zero(sourceType);
  f.scopeSubject = graph.scopedPolicyGraphV2ScopeSubject(coordinates.chainId, coordinates.core, scope);
  f.snapshot.scopeSubject = f.scopeSubject;
  f.snapshot.recordHash = p.observation.snapshotRecordHash;
  f.snapshot.revision = p.observation.snapshotRevision;
  f.snapshot.manifestHash = h(201); f.snapshot.sourceHash = h(202);
  const s = f.snapshotSource;
  s.scope = structuredClone(scope); s.membership.scopeSubject = f.scopeSubject; s.membership.tokenCount = 1n;
  s.outputs.scope = structuredClone(scope); s.outputs.contentRoot = h(203); s.outputs.tokenCount = 1n;
  s.outputs.manifestHash = h(204); s.artist.artistId = h(205); s.artist.bindingGeneration = 1n; s.artist.bindingHash = h(206);
  f.snapshot.sourceHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address[11]", "bytes32[11]",
    sourceType.components.find(t => t.name === "snapshotSource")], [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"),
    coordinates.chainId, d.targets[5], sd.targets, sd.codeHashes, s]));
  f.contentRootRecordHash = h(207);
  f.contentRootBinding = root.scopedPolicyRootV2BindingFromSnapshot(sd, s, f.snapshot);
  const r = f.contentRoot;
  r.publication.scope = structuredClone(scope); r.publication.snapshotRecordHash = f.snapshot.recordHash;
  r.publication.snapshotRevision = f.snapshot.revision; r.snapshotHost = d.targets[5]; r.snapshotCodeHash = d.codeHashes[5];
  r.snapshotManifestHash = f.snapshot.manifestHash; r.snapshotSourceHash = f.snapshot.sourceHash;
  r.contentRoot = s.outputs.contentRoot; r.leafCount = 1n; r.outputManifestHash = s.outputs.manifestHash;
  r.artistId = s.artist.artistId; r.bindingGeneration = 1n; r.bindingHash = s.artist.bindingHash;
  r.publisher = address(71); r.authorizationClass = 7n; r.grantRevision = 1n; r.routeHash = h(208);
  r.artistConsent = h(209); r.publishedAt = 9n;
  r.stateHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address",
    abi.router.getFunction("scopedContentRootRecord").outputs[0], abi.router.getFunction("scopedPolicyContentRootBinding").outputs[0]],
  [id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_STATE_V2"), coordinates.chainId, d.targets[4], coordinates.core,
    { ...r, stateHash: ZeroHash, artistConsent: ZeroHash, publishedAt: 0n }, f.contentRootBinding]));
  f.environmentCoverage.coverageHash = p.observation.environment.coverageHash;
  f.environmentCoverage.objectHash = p.observation.environment.objectHash; f.environmentCoverage.artistId = s.artist.artistId;
  const sampleType = sourceType.components.find(t => t.name === "samples").arrayChildren;
  const sample = zero(sampleType), capture = p.observation.captures[0];
  sample.selection.tokenId = capture.tokenId; sample.selection.sources[3] = address(80); sample.selection.sourceCodeHashes[3] = h(80);
  Object.assign(sample.observation, { tokenId: capture.tokenId, collectionSerial: capture.collectionSerial,
    originalCoordinator: address(80), tokenDataBytes: 16384n, metadataJSONHash: capture.metadataJSONHash,
    htmlHash: capture.htmlHash, htmlBytes: capture.htmlBytes });
  Object.assign(sample.observation.captureCoverage, { coverageHash: capture.coverageHash, objectHash: capture.objectHash,
    artistId: s.artist.artistId, sha256Digest: capture.repeatCaptureSha256[0] });
  Object.assign(sample.entropy, { coordinator: address(80), coordinatorCodeHash: h(80), status: 5n, mode: 2n, finalized: true });
  f.samples = [sample];
  return { p, d, sd, f };
}

function history() {
  const { p, d, f, sd } = sourceFacts();
  const sourceHash = ref.scopedPolicyReferenceV2SourceHash(coordinates, d, f);
  p.observation.expectedSourcesHash = sourceHash;
  const preview = ref.scopedPolicyReferenceV2PreviewReceipt(coordinates, p, caller,
    { authorizationClass: 3n, grantRevision: 1n }, sourceHash);
  const env = environment.referenceEnvironmentCanonicalBytes(p.observation.environment);
  const canonical = ref.scopedPolicyReferenceV2PayloadBytes(coordinates, p, preview, f, env);
  const r = structuredClone(preview);
  Object.assign(r.observation, { payloadHash: keccak256(canonical), payloadBytes: BigInt((canonical.length - 2) / 2), recordedAt: 10n });
  r.observation.recordHash = ref.scopedPolicyReferenceV2RecordHash(coordinates, p, r);
  r.observation.recordChainHash = ref.scopedPolicyReferenceV2ChainHash(coordinates, p.scope, ZeroHash, r.observation.revision, r.observation.recordHash);
  return { p, d, f, sd, r, canonical, env };
}

test("full original compiler tuples roundtrip empty getters without admission claims", () => {
  for (const [type, encode, decode] of [
    [publicationType, ref.encodeScopedPolicyReferenceV2Publication, ref.decodeScopedPolicyReferenceV2Publication],
    [receiptType, ref.encodeScopedPolicyReferenceV2Receipt, ref.decodeScopedPolicyReferenceV2Receipt],
    [sourceType, ref.encodeScopedPolicyReferenceV2SourceFacts, ref.decodeScopedPolicyReferenceV2SourceFacts],
    [dependencyType, ref.encodeScopedPolicyReferenceV2Dependencies, ref.decodeScopedPolicyReferenceV2Dependencies],
  ]) {
    const value = zero(type), canonical = coder.encode([type], [value]);
    assert.equal(encode(value), canonical); assert.deepEqual(decode(canonical), value);
    assert.throws(() => decode(canonical + "00".repeat(32)), /canonical/);
  }
  assert.throws(() => ref.validateScopedPolicyReferenceV2Publication(zero(publicationType), "publish"));
  assert.equal(ref.encodeScopedPolicyReferenceV2Publication(publication()), coder.encode([publicationType], [publication()]));
});

test("strict widths, scalar strings, dense arrays and immutable input copies", () => {
  const p = publication(), copy = ref.normalizeScopedPolicyReferenceV2Publication(p);
  p.observation.captures[0].capturedAt = 999n;
  assert.equal(copy.observation.captures[0].capturedAt, 10n);
  assert.ok(Object.isFrozen(copy.observation.environment.packageFiles[0]));
  for (const value of [-1n, 1n << 64n, 3]) assert.throws(() => ref.normalizeScopedPolicyReferenceV2Publication({ ...p,
    observation: { ...p.observation, effectiveAt: value } }));
  assert.throws(() => ref.normalizeScopedPolicyReferenceV2Publication({ ...p, scope: { ...scope, scopeType: 5n } }));
  assert.throws(() => ref.normalizeScopedPolicyReferenceV2Publication({ ...p, [Symbol("extra")]: true }));
  assert.throws(() => ref.normalizeScopedPolicyReferenceV2Publication({ ...p, observation: { ...p.observation, manifestURI: "\ud800" } }));
  const sparse = [p.observation.captures[0]]; delete sparse[0]; sparse.other = p.observation.captures[0];
  assert.throws(() => ref.normalizeScopedPolicyReferenceV2Publication({ ...p, observation: { ...p.observation, captures: sparse } }));
});

test("preview zero source draft is separate from final publication and literal URI admission", () => {
  const p = publication(); p.observation.expectedSourcesHash = ZeroHash;
  assert.deepEqual(ref.validateScopedPolicyReferenceV2Publication(p, "preview"), p);
  assert.throws(() => ref.prepareScopedPolicyReferenceV2Call(coordinates, caller, { kind: "publishReference", publication: p }));
  for (const manifestURI of ["", "https://x/作品", "ipfs://x", "ar://x", `ipfs://${"é".repeat(1020)}x`]) {
    assert.equal(ref.validateScopedPolicyReferenceV2Publication({ ...p, observation: { ...p.observation, manifestURI } }, "preview").observation.manifestURI, manifestURI);
  }
  for (const manifestURI of ["HTTPS://x", "https:///x", "https://?x", "ar://", "ipfs://a b", "https://x\u007f", `ipfs://${"é".repeat(1021)}`]) {
    assert.throws(() => ref.validateScopedPolicyReferenceV2Publication({ ...p, observation: { ...p.observation, manifestURI } }, "preview"));
  }
  for (const scopeType of [0n, 4n]) assert.throws(() => ref.validateScopedPolicyReferenceV2Publication({ ...p, scope: { ...scope, scopeType } }, "preview"));
});

test("capture validates full HTML, independent PNG repeat digest and original environment JSON", () => {
  const p = publication(), original = p.observation.captures[0];
  assert.notEqual(original.sourceSha256, original.repeatCaptureSha256[0]);
  assert.deepEqual(ref.validateScopedPolicyReferenceV2Publication(p, "publish"), p);
  for (const patch of [{ htmlBytes: original.htmlBytes + 1n }, { htmlHash: h(99) }, { sourceSha256: h(99) },
    { environmentManifestHash: h(99) }, { repeatCaptureSha256: [h(26), h(99)] }, { collectionSerial: 0n }, { capturedAt: 0n }]) {
    assert.throws(() => ref.validateScopedPolicyReferenceV2Publication({ ...p, observation: { ...p.observation, captures: [{ ...original, ...patch }] } }, "publish"));
  }
  assert.throws(() => ref.validateScopedPolicyReferenceV2Publication({ ...p, observation: { ...p.observation,
    environment: { ...p.observation.environment, manifestBytes: 1n } } }, "publish"));
});

test("fixed dependency graph preserves uint256 gas and original relative floors", () => {
  const d = dependencies();
  const wide = { ...d, readGas: 1n << 80n, sourceGas: 1n << 81n, snapshotGas: 1n << 82n, archiveGas: 1n << 80n };
  assert.deepEqual(ref.validateScopedPolicyReferenceV2Dependencies(coordinates, wide), wide);
  for (const patch of [{ readGas: 49999n }, { sourceGas: 49999n }, { snapshotGas: 99999n }, { archiveGas: 49999n }, { chainId: 1n }]) {
    assert.throws(() => ref.validateScopedPolicyReferenceV2Dependencies(coordinates, { ...d, ...patch }));
  }
  assert.throws(() => ref.validateScopedPolicyReferenceV2Dependencies(coordinates, { ...d, targets: [ZeroAddress, ...d.targets.slice(1)] }));
});

test("all five original CALLs match compiler and unchanged environment/inventory identities", () => {
  const p = publication(), e = p.observation.environment, rows = e.packageFiles;
  const requests = [{ kind: "prepareEnvironment", environment: e },
    ...["prepareFileInventory", "prepareFileInventoryPart", "prepareFileInventoryFromParts"].map(kind => ({ kind, rows, relative: true })),
    { kind: "publishReference", publication: p }];
  for (const request of requests) {
    const plan = ref.prepareScopedPolicyReferenceV2Call(coordinates, caller, request);
    const args = request.kind === "prepareEnvironment" ? [e] : request.kind === "publishReference" ? [p] : [rows, true];
    assert.deepEqual(plan.call, { to: coordinates.reference, value: 0n, data: abi.reference.encodeFunctionData(request.kind, args) });
    assert.deepEqual(ref.normalizeScopedPolicyReferenceV2Call(plan), plan);
    assert.equal(plan.factsVerified, false);
    if (request.kind === "prepareEnvironment") assert.equal(plan.preparation.id, environment.referenceEnvironmentId(coordinates.chainId, coordinates.reference, e));
    else if (request.kind === "publishReference") assert.equal(plan.preparation, null);
    else assert.equal(plan.preparation.id, request.kind === "prepareFileInventoryPart"
      ? inventory.referenceInventoryPartId(coordinates.chainId, coordinates.reference, true, rows)
      : inventory.referenceInventoryId(coordinates.chainId, coordinates.reference, true, rows));
  }
});

test("inventory part bounds and order stay distinct from complete empty arrays and assembly", () => {
  for (const kind of ["prepareFileInventory", "prepareFileInventoryFromParts"]) {
    const call = ref.prepareScopedPolicyReferenceV2Call(coordinates, caller, { kind, rows: [], relative: true });
    assert.equal(call.preparation.canonical, hexlify(toUtf8Bytes("[]")));
  }
  const rows = Array.from({ length: 65 }, (_, i) => ({ path: `${i.toString().padStart(3, "0")}.txt`, byteSize: 0n, sha256Digest: h(i + 1) }));
  ref.prepareScopedPolicyReferenceV2Call(coordinates, caller, { kind: "prepareFileInventoryPart", rows: rows.slice(0, 64), relative: true });
  for (const value of [[], rows]) assert.throws(() => ref.prepareScopedPolicyReferenceV2Call(coordinates, caller,
    { kind: "prepareFileInventoryPart", rows: value, relative: true }));
  assert.throws(() => ref.prepareScopedPolicyReferenceV2Call(coordinates, caller, { kind: "prepareFileInventory", rows: rows.slice().reverse(), relative: true }));
  const plan = ref.prepareScopedPolicyReferenceV2Call(coordinates, caller, { kind: "prepareFileInventoryFromParts", rows, relative: true });
  assert.equal(plan.preparation.id, inventory.referenceInventoryId(coordinates.chainId, coordinates.reference, true, rows));
});

test("source joins preserve terminal versus finalized sample semantics and exact first/last order", () => {
  const { p, d, sd, f } = sourceFacts();
  assert.deepEqual(ref.validateScopedPolicyReferenceV2Source(coordinates, d, p, f, sd), f);
  for (const [status, mode] of [[1n, 0n], [2n, 2n]]) {
    const terminal = structuredClone(f);
    Object.assign(terminal.samples[0].entropy, { terminal: true, finalized: false, status, mode, renderRequirement: 1n });
    terminal.samples[0].terminalAdmissionHash = h(88);
    ref.validateScopedPolicyReferenceV2Source(coordinates, d, p, terminal, sd);
    terminal.samples[0].entropy.finalized = true;
    assert.throws(() => ref.validateScopedPolicyReferenceV2Source(coordinates, d, p, terminal, sd));
  }
  for (const mutate of [x => { x.samples[0].membershipIndex = 1n; }, x => { x.samples[0].observation.captureCoverage.sha256Digest = p.observation.captures[0].sourceSha256; },
    x => { x.contentRootBinding.checkpoint = address(999); }, x => { x.contentRoot.stateHash = h(99); },
    x => { x.samples[0].entropy.status = 2n; }, x => { x.samples[0].terminalAdmissionHash = h(90); }]) {
    const bad = structuredClone(f); mutate(bad);
    assert.throws(() => ref.validateScopedPolicyReferenceV2Source(coordinates, d, p, bad, sd));
  }
  const last = structuredClone(f.samples[0]); last.membershipIndex = 8n;
  const two = structuredClone(f); two.snapshotSource.membership.tokenCount = 9n; two.contentRoot.leafCount = 9n; two.samples.push(last);
  two.snapshot.sourceHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address[11]", "bytes32[11]",
    sourceType.components.find(t => t.name === "snapshotSource")], [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"),
    coordinates.chainId, d.targets[5], sd.targets, sd.codeHashes, two.snapshotSource]));
  two.contentRoot.snapshotSourceHash = two.snapshot.sourceHash;
  two.contentRoot.stateHash = root.scopedPolicyRootV2StateHash({ chainId: coordinates.chainId, core: coordinates.core, router: d.targets[4], artistRegistry: address(999) }, two.contentRoot, two.contentRootBinding);
  const pp = structuredClone(p); pp.observation.captures.push(structuredClone(pp.observation.captures[0]));
  ref.validateScopedPolicyReferenceV2Source(coordinates, d, pp, two, sd);
  two.samples.reverse(); assert.throws(() => ref.validateScopedPolicyReferenceV2Source(coordinates, d, pp, two, sd));
});

test("rehashing the root and outer reference source cannot replace the original snapshot source commitment", () => {
  const { p, d, sd, f } = sourceFacts();
  const original = ref.scopedPolicyReferenceV2SourceHash(coordinates, d, f);
  f.snapshot.sourceHash = h(999);
  f.contentRoot.snapshotSourceHash = f.snapshot.sourceHash;
  f.contentRoot.stateHash = root.scopedPolicyRootV2StateHash({ chainId: coordinates.chainId, core: coordinates.core,
    router: d.targets[4], artistRegistry: address(999) }, f.contentRoot, f.contentRootBinding);
  p.observation.expectedSourcesHash = ref.scopedPolicyReferenceV2SourceHash(coordinates, d, f);
  assert.notEqual(p.observation.expectedSourcesHash, original);
  assert.throws(() => ref.validateScopedPolicyReferenceV2Source(coordinates, d, p, f, sd), /snapshot source commitment/);
});

test("source domain binds complete facts and all target pins but excludes gas caps", () => {
  const { d, f } = sourceFacts();
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "address[7]", "bytes32[7]", sourceType],
    [id("6529STREAM_SCOPED_POLICY_REFERENCE_SOURCES_V2"), coordinates.chainId, coordinates.reference, d.targets, d.codeHashes, f]));
  assert.equal(ref.scopedPolicyReferenceV2SourceHash(coordinates, d, f), expected);
  assert.equal(ref.scopedPolicyReferenceV2SourceHash(coordinates, { ...d, readGas: 0n, snapshotGas: 1n << 150n }, f), expected);
  assert.notEqual(ref.scopedPolicyReferenceV2SourceHash({ ...coordinates, reference: address(99) }, d, f), expected);
  const changed = structuredClone(f); changed.environmentCoverage.firstFixityHash = h(900);
  assert.notEqual(ref.scopedPolicyReferenceV2SourceHash(coordinates, d, changed), expected);
});

test("canonical seven-field payload clears only one publication and five receipt fields", () => {
  const { p, r, f, canonical, env } = history();
  const cp = { ...p, observation: { ...p.observation, expectedSourcesHash: ZeroHash } };
  const cr = { ...r, observation: { ...r.observation, recordHash: ZeroHash, recordChainHash: ZeroHash, payloadHash: ZeroHash, payloadBytes: 0n, recordedAt: 0n } };
  assert.equal(canonical, coder.encode(payloadTypes, [id("6529STREAM_SCOPED_POLICY_REFERENCE_PAYLOAD_V2"), coordinates.chainId,
    coordinates.reference, cp, cr, f, env]));
  assert.deepEqual(ref.decodeScopedPolicyReferenceV2Payload(canonical), { chainId: coordinates.chainId, reference: coordinates.reference,
    publication: cp, receipt: cr, source: f, environmentBytes: env });
  for (const patch of [{ recordHash: h(99) }, { recordChainHash: h(99) }, { payloadHash: h(99) }, { payloadBytes: 1n }, { recordedAt: 99n }]) {
    assert.equal(ref.scopedPolicyReferenceV2PayloadBytes(coordinates, p, { ...r, observation: { ...r.observation, ...patch } }, f, env), canonical);
  }
  assert.notEqual(ref.scopedPolicyReferenceV2PayloadBytes(coordinates, p, { ...r, observation: { ...r.observation, sourcesHash: h(99) } }, f, env), canonical);
  assert.throws(() => ref.decodeScopedPolicyReferenceV2Payload(canonical + "00".repeat(32)), /canonical/);
  assert.throws(() => ref.decodeScopedPolicyReferenceV2Payload(h(999) + canonical.slice(66)), /tag/);
});

test("mined history authenticates exact source, full submitted declaration, byte envelope and previous chain", () => {
  const { p, d, f, r, canonical } = history();
  assert.deepEqual(ref.authenticateScopedPolicyReferenceV2History(coordinates, d, p, r, canonical, ZeroHash).source, f);
  const pre = { ...r, observation: { ...r.observation, recordHash: ZeroHash, recordChainHash: ZeroHash } };
  assert.equal(r.observation.recordHash, keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", publicationType, receiptType],
    [id("6529STREAM_SCOPED_POLICY_REFERENCE_RECORD_V2"), coordinates.chainId, coordinates.reference, coordinates.core, coordinates.metadata, p, pre])));
  const changed = structuredClone(r); changed.observation.recordedAt++;
  assert.notEqual(ref.scopedPolicyReferenceV2RecordHash(coordinates, p, changed), r.observation.recordHash);
  for (const patch of [{ payloadBytes: r.observation.payloadBytes + 1n }, { sourcesHash: h(99) }, { authorizationClass: 7n }, { recordedAt: 9n }]) {
    assert.throws(() => ref.authenticateScopedPolicyReferenceV2History(coordinates, d, p, { ...r, observation: { ...r.observation, ...patch } }, canonical, ZeroHash));
  }
  assert.throws(() => ref.authenticateScopedPolicyReferenceV2History(coordinates, d, p, r, canonical, h(99)));
  for (const [expectedHead, expectedRevision] of [[ZeroHash, 1n], [h(88), 0n]]) {
    const badP = structuredClone(p), badR = structuredClone(r);
    Object.assign(badP.observation, { expectedHead, expectedRevision });
    Object.assign(badR.observation, { predecessor: expectedHead, revision: expectedRevision + 1n });
    const raw = ref.scopedPolicyReferenceV2PayloadBytes(coordinates, badP, badR, f,
      environment.referenceEnvironmentCanonicalBytes(p.observation.environment));
    Object.assign(badR.observation, { payloadHash: keccak256(raw), payloadBytes: BigInt((raw.length - 2) / 2) });
    badR.observation.recordHash = ref.scopedPolicyReferenceV2RecordHash(coordinates, badP, badR);
    badR.observation.recordChainHash = ref.scopedPolicyReferenceV2ChainHash(coordinates, scope, ZeroHash,
      badR.observation.revision, badR.observation.recordHash);
    assert.throws(() => ref.authenticateScopedPolicyReferenceV2History(coordinates, d, badP, badR, raw, ZeroHash), /lineage/);
  }
  assert.notEqual(ref.scopedPolicyReferenceV2ChainHash(coordinates, scope, h(44), 2n, h(45)),
    ref.scopedPolicyReferenceV2ChainHash(coordinates, scope, h(46), 2n, h(45)));
});

test("fully rehashed history cannot cross full TOKEN collection scope or retained snapshot identity", () => {
  const original = history();
  const otherScope = { ...scope, collectionId: scope.collectionId + 1n };
  assert.equal(graph.scopedPolicyGraphV2ScopeSubject(coordinates.chainId, coordinates.core, otherScope),
    graph.scopedPolicyGraphV2ScopeSubject(coordinates.chainId, coordinates.core, scope));
  const mutations = [
    f => { f.scopeSubject = h(999); },
    f => { f.snapshot.scopeSubject = h(999); },
    f => { f.snapshotSource.membership.scopeSubject = h(999); },
    f => { f.snapshotSource.scope = structuredClone(otherScope); },
    f => { f.snapshotSource.outputs.scope = structuredClone(otherScope); },
    f => { f.contentRoot.publication.scope = structuredClone(otherScope); },
    f => { f.snapshot.recordHash = h(999); },
    f => { f.snapshot.revision++; },
    f => { f.contentRoot.publication.snapshotRecordHash = h(999); },
    f => { f.contentRoot.publication.snapshotRevision++; },
    f => {
      f.snapshotSource.scope = structuredClone(otherScope);
      f.snapshotSource.outputs.scope = structuredClone(otherScope);
      f.contentRoot.publication.scope = structuredClone(otherScope);
    },
  ];
  for (const mutate of mutations) {
    const { p, d, f, r, env } = structuredClone(original);
    mutate(f);
    const sourceHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address[7]", "bytes32[7]", sourceType],
      [id("6529STREAM_SCOPED_POLICY_REFERENCE_SOURCES_V2"), coordinates.chainId, coordinates.reference, d.targets, d.codeHashes, f]));
    p.observation.expectedSourcesHash = sourceHash;
    r.observation.sourcesHash = sourceHash;
    const cp = { ...p, observation: { ...p.observation, expectedSourcesHash: ZeroHash } };
    const cr = { ...r, observation: { ...r.observation, recordHash: ZeroHash, recordChainHash: ZeroHash,
      payloadHash: ZeroHash, payloadBytes: 0n, recordedAt: 0n } };
    const canonical = coder.encode(payloadTypes,
      [id("6529STREAM_SCOPED_POLICY_REFERENCE_PAYLOAD_V2"), coordinates.chainId, coordinates.reference, cp, cr, f, env]);
    Object.assign(r.observation, { payloadHash: keccak256(canonical), payloadBytes: BigInt((canonical.length - 2) / 2) });
    r.observation.recordHash = ref.scopedPolicyReferenceV2RecordHash(coordinates, p, r);
    r.observation.recordChainHash = ref.scopedPolicyReferenceV2ChainHash(coordinates, scope, ZeroHash,
      r.observation.revision, r.observation.recordHash);
    assert.equal(ref.scopedPolicyReferenceV2SourceHash(coordinates, d, f), sourceHash);
    assert.throws(() => ref.authenticateScopedPolicyReferenceV2History(coordinates, d, p, r, canonical, ZeroHash),
      /source scope or snapshot/);
  }
  ref.authenticateScopedPolicyReferenceV2History(coordinates, original.d, original.p, original.r, original.canonical, ZeroHash);
});

test("full retained byte bounds and Store chunk identities include exact STOP prefix", () => {
  const p = publication(), r = zero(receiptType), f = zero(sourceType);
  const baseline = ref.scopedPolicyReferenceV2PayloadBytes(coordinates, p, r, f, "0x");
  const available = ref.SCOPED_POLICY_REFERENCE_V2_MAX_BYTES - (baseline.length - 2) / 2;
  const edge = ref.scopedPolicyReferenceV2PayloadBytes(coordinates, p, r, f, `0x${"01".repeat(available)}`);
  assert.equal((edge.length - 2) / 2, 524288);
  assert.throws(() => ref.scopedPolicyReferenceV2PayloadBytes(coordinates, p, r, f, `0x${"01".repeat(available + 1)}`));
  const chunks = ref.scopedPolicyReferenceV2Chunks(edge);
  assert.equal(chunks.length, 64);
  assert.equal(chunks[0].runtimeHash, keccak256(`0x00${edge.slice(2, 16386)}`));
  const huge = structuredClone(p); huge.observation.manifestURI = "x".repeat(524288);
  assert.throws(() => ref.encodeScopedPolicyReferenceV2Publication(huge));
});

test("read and write reconstruction rejects caller, target, value, bytes and cached preparation mutations", () => {
  const request = { kind: "prepareFileInventory", rows: runtime().packageFiles, relative: true };
  const call = ref.prepareScopedPolicyReferenceV2Call(coordinates, caller, request);
  request.rows[0].path = "changed.exe";
  assert.equal(call.request.rows[0].path, "engine.exe");
  for (const patch of [{ value: 1n }, { to: address(999) }, { data: "0x" }]) {
    assert.throws(() => ref.normalizeScopedPolicyReferenceV2Call({ ...call, call: { ...call.call, ...patch } }));
  }
  assert.throws(() => ref.normalizeScopedPolicyReferenceV2Call({ ...call, preparation: { ...call.preparation, id: h(999) } }));
  assert.throws(() => ref.prepareScopedPolicyReferenceV2Call(coordinates, caller, { kind: "lockReference", scope }));
  const requests = [{ kind: "dependencies" }, { kind: "referencePayload", hash: ZeroHash },
    { kind: "referenceSource", hash: h(21) }, { kind: "currentReference", scope },
    { kind: "referenceAt", scope, index: 1n << 200n }, { kind: "requireCurrent", scope, hash: h(21), revision: 1n }];
  for (const q of requests) {
    const read = ref.prepareScopedPolicyReferenceV2Read(coordinates, ZeroAddress, q);
    assert.deepEqual(ref.normalizeScopedPolicyReferenceV2Read(read), read);
    assert.throws(() => ref.normalizeScopedPolicyReferenceV2Read({ ...read, call: { ...read.call, value: 1n } }));
  }
  assert.throws(() => ref.prepareScopedPolicyReferenceV2Read(coordinates, caller, { kind: "inventedCurrentPair", scope }));
});

test("original capabilities and finite preparation/publication ABI selectors remain distinct", () => {
  for (const [key, expected] of [["referenceInterface", ref.SCOPED_POLICY_REFERENCE_V2_INTERFACE_ID],
    ["referenceEnvironmentPreparation", ref.SCOPED_POLICY_REFERENCE_V2_ENVIRONMENT_INTERFACE_ID],
    ["referenceInventoryPreparation", ref.SCOPED_POLICY_REFERENCE_V2_INVENTORY_INTERFACE_ID]]) {
    let value = 0n;
    for (const fragment of abi[key].fragments.filter(f => f.type === "function" && f.name !== "supportsInterface")) value ^= BigInt(fragment.selector);
    assert.equal(`0x${value.toString(16).padStart(8, "0")}`, expected);
  }
  const writes = ref.scopedPolicyReferenceV2Interface().fragments.filter(f => f.type === "function" && f.stateMutability === "nonpayable");
  assert.equal(writes.length, 5);
  for (const fragment of writes) assert.equal(fragment.selector, abi.reference.getFunction(fragment.name).selector);
  assert.equal(ref.SCOPED_POLICY_REFERENCE_V2_DOCUMENTS.length, 7);
  assert.equal(ref.SCOPED_POLICY_REFERENCE_V2_DOCUMENTS[0].byteLength, 26018n);
});
