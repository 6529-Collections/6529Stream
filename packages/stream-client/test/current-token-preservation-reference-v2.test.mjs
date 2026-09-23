import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, sha256, toUtf8Bytes, hexlify } from "ethers";
import * as p from "../dist/current-token-preservation-reference-v2.js";
import * as environment from "../dist/current-reference-environment.js";
import * as inventory from "../dist/current-reference-inventory.js";
import { toSafeCall } from "../dist/safe.js";
import { fixture, compiledInterfaces as ci } from "./current-preservation-v2-fixture.mjs";
const coder = AbiCoder.defaultAbiCoder(), Z = ZeroHash;
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = n => id(String(n));
const copy = structuredClone;
const hash = (types, values) => keccak256(coder.encode(types, values));
const hex = s => hexlify(toUtf8Bytes(s));
const host = { collection: ci.StreamPreservationPolicyReferencePublicationV2, scoped: ci.StreamScopedPreservationPolicyReferencePublicationV2 };
const field = (t, n) => t.components.find(c => c.name === n);
const T = {
  Publication: host.collection.getFunction("publishReference").inputs[0],
  Dependencies: host.collection.getFunction("dependencies").outputs[0],
  Receipt: host.collection.getFunction("currentReference").outputs[0],
  Lock: host.collection.getFunction("referenceLock").outputs[0],
  CollectionSource: host.collection.getFunction("referenceSource").outputs[0],
  ScopedSource: host.scoped.getFunction("referenceSource").outputs[0],
};
T.Scope = field(T.Publication, "scope");
T.ObservationPublication = field(T.Publication, "observation");
T.ObservationReceipt = field(T.Receipt, "observation");
T.Environment = field(T.ObservationPublication, "environment");
T.Capture = field(T.ObservationPublication, "captures").arrayChildren;
T.PackageFile = field(T.Environment, "packageFiles").arrayChildren;
T.Sample = field(T.ScopedSource, "samples").arrayChildren;
T.SampleFacts = field(T.Sample, "observation");
T.Coverage = field(T.ScopedSource, "environmentCoverage");
for (const k of ["Collection", "Scoped"]) {
  T[`${k}RootRecord`] = field(T[`${k}Source`], "contentRoot");
  T[`${k}RootBinding`] = field(T[`${k}Source`], "contentRootBinding");
}
const srcType = kind => T[kind === "collection" ? "CollectionSource" : "ScopedSource"];
const snapshotDepsType = ci.StreamPreservationPolicySnapshotPublicationV2.getFunction("dependencies").outputs[0];
function zero(t) {
  if (t.baseType === "tuple") return Object.fromEntries(t.components.map(c => [c.name, zero(c)]));
  if (t.baseType === "array") return Array.from({ length: Math.max(0, t.arrayLength) }, () => zero(t.arrayChildren));
  if (t.type.startsWith("uint")) return 0n;
  if (t.type === "address") return ZeroAddress;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  return t.type === "bytes" ? "0x" : `0x${"00".repeat(Number(t.type.slice(5)))}`;
}
const domain = (kind, purpose) => id(`6529STREAM_${kind === "scoped" ? "SCOPED_" : ""}PRESERVATION_POLICY_REFERENCE_${purpose}_V2`);
const subject = (c, s) => s.scopeType < 2n
  ? hash(["bytes32", "uint256", "address", "uint256"], [id(s.scopeType === 0n ? "6529STREAM_SUBJECT_COLLECTION_V1" : "6529STREAM_SUBJECT_TOKEN_V1"), c.chainId, c.core, s.scopeType === 0n ? s.collectionId : s.tokenId])
  : hash(["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"], [id("6529STREAM_SUBJECT_SCOPE_V1"), c.chainId, c.core, s.collectionId, s.scopeType, s.scopeId]);
const docs = kind => ["schema", "profile", "abi"].map(suffix => fixture.documents[`docs/schemas/preservation/${kind === "collection" ? "preservation-policy-collection" : "scoped-preservation-policy"}-reference-v2.${suffix}.json`].text);
const sourceLiteral = name => Object.entries(fixture.sourceTexts).find(([path]) => path.endsWith(`/${name}.sol`))[1];
const rootDocs = [...sourceLiteral("StreamScopedPreservationPolicyContentRootSchemasV2").matchAll(/return bytes\(\s*'([^']*)'\s*\)/g)].map(x => x[1]);
const outputDocs = [...sourceLiteral("StreamPreservationPolicyOutputSchemasV2").matchAll(/return bytes\(\s*'((?:[^'\\]|\\.)*)'\s*\)/g)].map(x => x[1].replaceAll("\\'", "'"));
function runtime() {
  const e = { objectHash: H(11), coverageHash: H(12), manifestHash: ZeroHash, manifestBytes: 0n,
    engineName: "Browser", engineVersion: "1", engineExecutableSha256: H(13), toolchainName: "Capture",
    toolchainVersion: "1", toolchainSha256: H(14), engineExecutablePath: "engine.exe", toolchainPath: "tool.exe",
    packageFiles: [{ path: "engine.exe", byteSize: 2n, sha256Digest: H(13) }, { path: "tool.exe", byteSize: 3n, sha256Digest: H(14) }],
    platformPrerequisites: [{ path: "C:\\Windows\\é.dll", byteSize: 0n, sha256Digest: H(15) }],
    operatingSystem: "Windows", operatingSystemVersion: "Server", architecture: "AMD64", viewportWidth: 4096n,
    viewportHeight: 1n, devicePixelRatio: 1n, colorSpace: "srgb", softwareRasterization: true,
    captureProfile: id("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1"), licenseNote: "undetermined" };
  const canonical = environment.referenceEnvironmentCanonicalBytes(e);
  return { ...e, manifestHash: keccak256(canonical), manifestBytes: BigInt((canonical.length - 2) / 2) };
}

// These are supplied, compiler-shaped facts. They do not claim an executed native lifecycle.
function example(scopeType = 0n, count = scopeType === 1n ? 1n : 5n) {
  const kind = scopeType === 0n ? "collection" : "scoped";
  const c = { chainId: 1n << 230n, core: A(1), metadata: A(2), reference: A(90), scopeKind: kind };
  const d = { targets: Array.from({ length: 7 }, (_, i) => A(i + 1)), codeHashes: Array.from({ length: 7 }, (_, i) => H(i + 1)), chainId: c.chainId, readGas: 50000n, sourceGas: 200000n, snapshotGas: 400000n, archiveGas: 90000n };
  const sd = { ...zero(snapshotDepsType), chainId: c.chainId, targets: [...d.targets.slice(0, 5), ...Array.from({ length: 6 }, (_, i) => A(30 + i))], codeHashes: [...d.codeHashes.slice(0, 5), ...Array.from({ length: 6 }, (_, i) => H(30 + i))] };
  const scope = { scopeType, collectionId: (1n << 200n) + 12n, tokenId: scopeType === 1n ? (1n << 220n) + 99n : 0n, scopeId: scopeType > 1n ? H(scopeType) : Z };
  const env = runtime(), html = hex("<html>作品</html>");
  const captures = Array.from({ length: count === 1n ? 1 : 2 }, (_, i) => ({ tokenId: scopeType === 1n ? scope.tokenId : BigInt(i + 9), collectionSerial: BigInt(i + 1), metadataJSONHash: H(`json${i}`), htmlHash: keccak256(html), htmlBytes: BigInt((html.length - 2) / 2), animationHTML: html, objectHash: H(`obj${i}`), coverageHash: H(`coverage${i}`), sourceSha256: sha256(html), repeatCaptureSha256: [H(`repeat${i}`), H(`repeat${i}`)], environmentManifestHash: env.manifestHash, capturedAt: 10n }));
  const publication = { scope, observation: { collectionId: scope.collectionId, referenceId: H("referenceId"), expectedHead: Z, expectedRevision: 0n, snapshotRecordHash: H("snapshot"), snapshotRevision: 1n, expectedSourcesHash: Z, captures, environment: env, manifestURI: "ipfs://reference", effectiveAt: 10n, reasonHash: H("reason") } };
  const f = zero(srcType(kind)), s = f.snapshotSource;
  f.scopeSubject = subject(c, scope);
  Object.assign(f.snapshot, { scopeSubject: f.scopeSubject, recordHash: publication.observation.snapshotRecordHash, revision: 1n, manifestHash: H("snapshotPayload"), schemaHash: H("snapshotSchema"), profileHash: H("snapshotProfile"), canonicalizationHash: H("snapshotCanon") });
  s.scope = copy(scope); s.membership.scopeSubject = f.scopeSubject; s.membership.tokenCount = count;
  for (const row of [s.selection, s.content, s.outputs]) row.scope = copy(scope);
  s.content.preservationProfile = id("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
  const snapPrefix = kind === "collection" ? "preservation-policy-collection" : "scoped-preservation-policy";
  const snapDocs = ["schema", "profile", "abi"].map(suffix => keccak256(hex(fixture.documents[`docs/schemas/preservation/${snapPrefix}-snapshot-v2.${suffix}.json`].text)));
  [f.snapshot.schemaHash, f.snapshot.profileHash, f.snapshot.canonicalizationHash] = snapDocs;
  Object.assign(s.outputs, { contentRoot: H("content"), manifestHash: H("manifest"), tokenCount: count, outputRoot: H("output"), metadataRouter: d.targets[4], preservationProfile: id("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2") });
  Object.assign(s.artist, { artistId: H("Artist"), bindingGeneration: 1n, bindingHash: H("binding") });
  if (kind === "collection") {
    s.rootBinding.profileId = id("6529STREAM_PRESERVATION_POLICY_CONTENT_V2");
    s.rootBinding.preservationOutputProfile = id("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
    s.root.publication.collectionId = scope.collectionId;
    s.root.publication.verifiedManifestRecordHash = H("outputRecord");
    s.root.contentRoot = s.outputs.contentRoot;
    f.contentRoot = copy(s.root); f.contentRootBinding = copy(s.rootBinding);
    f.contentRootRecordHash = hash(["bytes32", "uint256", "address", T.CollectionRootRecord, T.CollectionRootBinding], [id("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"), c.chainId, d.targets[4], f.contentRoot, f.contentRootBinding]);
  } else {
    s.sourceFactory = A(40); s.sourceFactoryCodeHash = H(40); s.factoryDependenciesHash = H("factory");
  }
  const st = field(srcType(kind), "snapshotSource");
  f.snapshot.sourceHash = hash(["bytes32", "uint256", "address", "address[11]", "bytes32[11]", st], [id(`6529STREAM_${kind === "scoped" ? "SCOPED_" : ""}PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2`), c.chainId, d.targets[5], sd.targets, sd.codeHashes, s]);
  if (kind === "scoped") {
    const m = s.outputs;
    f.contentRootRecordHash = H("scopedRootRecord");
    f.contentRootBinding = { profileId: id("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V2"), outputManifest: sd.targets[8], outputManifestCodeHash: sd.codeHashes[8], checkpoint: sd.targets[7], checkpointCodeHash: sd.codeHashes[7], checkpointHash: m.checkpointHash, checkpointStateHash: m.checkpointStateHash, entropySourceSet: sd.targets[10], entropySourceSetCodeHash: sd.codeHashes[10], inventoryHash: m.inventoryHash, policyChainHash: m.policyChainHash, outputRoot: m.outputRoot, outputSchemaHash: keccak256(hex(outputDocs[0])), outputCanonicalizationHash: keccak256(hex(outputDocs[1])), leafSchemaHash: keccak256(hex(outputDocs[2])), rootSchemaHash: keccak256(hex(rootDocs[0])), rootCanonicalizationHash: keccak256(hex(rootDocs[1])), sourceFactory: s.sourceFactory, sourceFactoryCodeHash: s.sourceFactoryCodeHash, factoryDependenciesHash: s.factoryDependenciesHash, snapshotSchemaHash: f.snapshot.schemaHash, snapshotProfileHash: f.snapshot.profileHash, snapshotCanonicalizationHash: f.snapshot.canonicalizationHash, metadataRouter: m.metadataRouter, preservationOutputProfile: m.preservationProfile };
    const r = f.contentRoot;
    Object.assign(r, { publication: { scope: copy(scope), expectedPredecessor: Z, snapshotRecordHash: f.snapshot.recordHash, snapshotRevision: 1n, manifestURI: "ipfs://root" }, snapshotHost: d.targets[5], snapshotCodeHash: d.codeHashes[5], snapshotManifestHash: f.snapshot.manifestHash, snapshotSourceHash: f.snapshot.sourceHash, contentRoot: m.contentRoot, leafCount: count, outputManifestHash: m.manifestHash, artistId: s.artist.artistId, bindingGeneration: 1n, bindingHash: s.artist.bindingHash, publisher: A(45), authorizationClass: 7n, grantRevision: 1n, routeHash: H("route"), artistConsent: H("consent"), publishedAt: 8n });
    r.stateHash = hash(["bytes32", "uint256", "address", "address", T.ScopedRootRecord, T.ScopedRootBinding], [id("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V2"), c.chainId, d.targets[4], c.core, { ...r, stateHash: Z, artistConsent: Z, publishedAt: 0n }, f.contentRootBinding]);
  }
  Object.assign(f.environmentCoverage, { coverageHash: env.coverageHash, objectHash: env.objectHash, artistId: s.artist.artistId });
  f.samples = captures.map((capture, i) => {
    const row = zero(T.Sample); row.membershipIndex = i === 0 ? 0n : count - 1n;
    Object.assign(row.observation, { tokenId: capture.tokenId, collectionSerial: capture.collectionSerial, originalCoordinator: A(50), tokenDataBytes: 16384n, metadataJSONHash: capture.metadataJSONHash, htmlHash: capture.htmlHash, htmlBytes: capture.htmlBytes });
    Object.assign(row.observation.captureCoverage, { coverageHash: capture.coverageHash, objectHash: capture.objectHash, artistId: s.artist.artistId, sha256Digest: capture.repeatCaptureSha256[0] });
    row.selection.tokenId = capture.tokenId; row.selection.sources[0] = c.core; row.selection.sources[1] = d.targets[4]; row.selection.sources[3] = A(50); row.selection.sourceCodeHashes[3] = H(50);
    Object.assign(row.selection.selection, { renderer: A(51 + i), rendererCodeHash: H(51 + i), registry: A(55), registryCodeHash: H(55), versionKey: H(`version${i}`) });
    row.preservation = { producer: A(60 + i), producerCodeHash: H(60 + i), profile: id(i ? "6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1" : "6529STREAM_PRESERVATION_RENDER_V1"), core: c.core, metadataRouter: d.targets[4], liveRenderer: A(51 + i), liveRendererCodeHash: H(51 + i), attribution: A(65 + i), attributionCodeHash: H(65 + i) };
    row.preservationAdmission = { registry: A(55), registryCodeHash: H(55), versionKey: H(`version${i}`), registrationHash: H("reg"), readSetHash: H("readSet"), analysisHash: H("analysis"), goldenHash: H("golden") };
    Object.assign(row.entropy, { coordinator: A(50), coordinatorCodeHash: H(50), status: 5n, mode: 2n, finalized: true });
    return row;
  });
  return { c, d, sd, publication, source: f };
}

const payloadTypes = kind => ["bytes32", "uint256", "address", T.Publication, T.Receipt, srcType(kind), "bytes"];
function completed(f, previousChainHash = Z) {
  const { c, d, source } = f, kind = c.scopeKind;
  const sourceHash = hash(["bytes32", "uint256", "address", "address[7]", "bytes32[7]", srcType(kind)], [domain(kind, "SOURCES"), c.chainId, c.reference, d.targets, d.codeHashes, source]);
  const publication = copy(f.publication); publication.observation.expectedSourcesHash = sourceHash;
  const o = publication.observation, definitions = docs(kind);
  const preview = { scopeSubject: subject(c, publication.scope), observation: { ...zero(T.ObservationReceipt), collectionId: o.collectionId, referenceId: o.referenceId, predecessor: o.expectedHead, revision: o.expectedRevision + 1n, sourcesHash: sourceHash, snapshotRecordHash: o.snapshotRecordHash, snapshotRevision: o.snapshotRevision, recorder: A(70), authorizationClass: 3n, grantRevision: 1n, effectiveAt: o.effectiveAt, reasonHash: o.reasonHash, schemaHash: keccak256(hex(definitions[0])), profileHash: keccak256(hex(definitions[1])), canonicalizationHash: keccak256(hex(definitions[2])) } };
  const environmentBytes = environment.referenceEnvironmentCanonicalBytes(o.environment);
  const canonical = coder.encode(payloadTypes(kind), [domain(kind, "PAYLOAD"), c.chainId, c.reference, { ...publication, observation: { ...o, expectedSourcesHash: Z } }, preview, source, environmentBytes]);
  const receipt = copy(preview);
  Object.assign(receipt.observation, { payloadHash: keccak256(canonical), payloadBytes: BigInt((canonical.length - 2) / 2), recordedAt: 12n });
  receipt.observation.recordHash = hash(["bytes32", "uint256", "address", "address", "address", T.Publication, T.Receipt], [domain(kind, "RECORD"), c.chainId, c.reference, c.core, c.metadata, publication, receipt]);
  receipt.observation.recordChainHash = hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "uint64", "bytes32"], [domain(kind, "CHAIN"), c.chainId, c.reference, c.core, preview.scopeSubject, previousChainHash, receipt.observation.revision, receipt.observation.recordHash]);
  return { ...f, publication, preview, receipt, canonical, environmentBytes, previousChainHash };
}
const auth = f => p.authenticateTokenPreservationReferenceV2History(f.c, f.d, f.publication, f.receipt, f.canonical, f.previousChainHash);

test("nineteen exact compiler tuple codecs preserve structural zero getters", () => {
  const shape = t => ({ type: t.format("sighash"), names: t.components?.map(c => [c.name, shape(c)]), child: t.arrayChildren ? shape(t.arrayChildren) : undefined });
  for (const [name, t] of Object.entries(T)) {
    const key = `TOKEN_PRESERVATION_REFERENCE_V2_${name.replace(/([a-z])([A-Z])/g, "$1_$2").toUpperCase()}_TUPLE`;
    assert.deepEqual(shape(ParamType.from(p[key])), shape(t), name);
    const raw = coder.encode([t], [zero(t)]);
    assert.equal(p[`encodeTokenPreservationReferenceV2${name}`](zero(t)), raw);
    assert.deepEqual(p[`decodeTokenPreservationReferenceV2${name}`](raw), zero(t));
    assert.throws(() => p[`decodeTokenPreservationReferenceV2${name}`](`${raw}${"00".repeat(32)}`), /canonical/);
  }
  assert.equal((p.encodeTokenPreservationReferenceV2Dependencies(zero(T.Dependencies)).length - 2) / 2, 608);
  assert.equal((p.encodeTokenPreservationReferenceV2ScopedRootBinding(zero(T.ScopedRootBinding)).length - 2) / 2, 800);
  assert.equal((p.encodeTokenPreservationReferenceV2CollectionRootBinding(zero(T.CollectionRootBinding)).length - 2) / 2, 608);
});

test("both concrete ABIs preserve five exact writes, own interface ids and distinct read availability", () => {
  for (const kind of ["collection", "scoped"]) {
    const actual = p.tokenPreservationReferenceV2Interface(kind);
    for (const f of actual.fragments) {
      const expected = f.type === "function" ? host[kind].getFunction(f.format("sighash")) : host[kind].getEvent(f.format("sighash"));
      assert.equal(f.format("full"), expected.format("full"));
    }
    assert.deepEqual(actual.fragments.filter(f => f.type === "function" && f.stateMutability === "nonpayable").map(f => f.name).sort(), ["prepareEnvironment", "prepareFileInventory", "prepareFileInventoryFromParts", "prepareFileInventoryPart", "publishReference"]);
    for (const method of ["lockReference", "raiseGasParameter"]) assert.equal(actual.getFunction(method), null);
    const iface = `IStream${kind === "scoped" ? "Scoped" : ""}PreservationPolicyReferencePublicationV1`;
    const names = [...sourceLiteral(iface).matchAll(/function\s+(\w+)/g)].map(m => m[1]);
    const own = names.reduce((acc, name) => acc ^ BigInt(ci[iface].getFunction(name).selector), 0n);
    assert.equal(p[`TOKEN_PRESERVATION_REFERENCE_V2_${kind.toUpperCase()}_INTERFACE_ID`], `0x${own.toString(16).padStart(8, "0")}`);
  }
  assert.equal(p.tokenPreservationReferenceV2Interface("scoped").getFunction("referenceChunkAt"), null);
});

test("ten exact retained definitions include both large schemas and original newline bytes", () => {
  for (const kind of ["collection", "scoped"]) {
    const defs = p.tokenPreservationReferenceV2Definitions(kind);
    assert.deepEqual(defs.map(d => d.kind), [0n, 2n, 1n, 0n, 0n, 0n, 2n]);
    const text = [...docs(kind), ...["STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1", "STREAM_REFERENCE_PNG_OBJECT_V1", "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1", "STREAM_REFERENCE_NATIVE_FORMATS_V1"].map(name => fixture.documents[Object.keys(fixture.documents).find(path => path.endsWith(`/${name}.json`))].text)];
    const commonNames = ["STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1", "STREAM_REFERENCE_PNG_OBJECT_V1", "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1", "STREAM_REFERENCE_NATIVE_FORMATS_V1"];
    text.forEach((s, i) => { assert.equal(defs[i].data, hex(s)); assert.equal(defs[i].hash, keccak256(hex(s))); assert.equal(defs[i].byteLength, BigInt(Buffer.byteLength(s))); assert.equal(defs[i].id, id(i < 3 ? JSON.parse(s).name : commonNames[i - 3])); });
    assert.equal(defs[0].byteLength, kind === "collection" ? 29589n : 28358n);
  }
});

test("source hashes independently retain both original domains, supplied roster and gas exclusions", () => {
  for (const type of [0n, 1n, 2n, 3n]) {
    const f = completed(example(type));
    assert.equal(p.tokenPreservationReferenceV2SourceHash(f.c, f.d, f.source), f.publication.observation.expectedSourcesHash);
    assert.equal(p.tokenPreservationReferenceV2SourceHash(f.c, { ...f.d, readGas: 0n, sourceGas: (1n << 256n) - 1n, snapshotGas: 0n, archiveGas: 0n }, f.source), f.publication.observation.expectedSourcesHash);
    assert.notEqual(p.tokenPreservationReferenceV2SourceHash({ ...f.c, reference: A(99) }, f.d, f.source), f.publication.observation.expectedSourcesHash);
    assert.notEqual(p.tokenPreservationReferenceV2SourceHash(f.c, { ...f.d, codeHashes: f.d.codeHashes.map((v, i) => i === 6 ? H(999) : v) }, f.source), f.publication.observation.expectedSourcesHash);
  }
});

test("current source joins exact inner snapshot, first/last endpoints, two row profiles and roots", () => {
  for (const type of [0n, 1n, 2n, 3n]) {
    const f = example(type);
    assert.deepEqual(p.validateTokenPreservationReferenceV2Source(f.c, f.d, f.publication, f.source, f.sd), f.source);
    for (const mutation of [s => s.snapshot.sourceHash = H(999), s => s.samples[0].preservation.profile = id("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2"), s => s.samples[0].preservationAdmission.registry = A(999), s => s.samples[0].preservation.liveRenderer = A(999), s => s.snapshotSource.outputs.scope.collectionId = 999n, s => s.environmentCoverage.artistId = H(999)]) {
      const bad = copy(f.source); mutation(bad);
      assert.throws(() => p.validateTokenPreservationReferenceV2Source(f.c, f.d, f.publication, bad, f.sd));
    }
    if (type !== 1n) {
      const bad = copy(f.source); bad.samples[1].membershipIndex = 1n;
      assert.throws(() => p.validateTokenPreservationReferenceV2Source(f.c, f.d, f.publication, bad, f.sd), /order/);
    }
    if (type === 0n) {
      const bad = copy(f.source); bad.contentRootRecordHash = H(999);
      assert.throws(() => p.validateTokenPreservationReferenceV2Source(f.c, f.d, f.publication, bad, f.sd), /root/);
    } else {
      assert.deepEqual(p.tokenPreservationReferenceV2ScopedRootBindingFromSnapshot(f.sd, f.source.snapshotSource, f.source.snapshot), f.source.contentRootBinding);
      for (const field of ["sourceFactory", "outputManifest", "metadataRouter"]) {
        const bad = copy(f.source); bad.contentRootBinding[field] = A(999);
        bad.contentRoot.stateHash = p.tokenPreservationReferenceV2ScopedRootStateHash(f.c.chainId, f.d.targets[4], f.c.core, bad.contentRoot, bad.contentRootBinding);
        assert.throws(() => p.validateTokenPreservationReferenceV2Source(f.c, f.d, f.publication, bad, f.sd), /binding/);
      }
    }
  }
});

test("terminal DISABLED/NOT_REQUIRED and finalized zero seed remain distinct", () => {
  for (const [status, mode] of [[1n, 0n], [2n, 2n], [5n, 2n]]) {
    const f = example(1n), sample = f.source.samples[0];
    Object.assign(sample.entropy, { status, mode, terminal: status !== 5n, finalized: status === 5n, renderRequirement: status === 5n ? 0n : 1n });
    sample.terminalAdmissionHash = status === 5n ? Z : H("readiness608");
    assert.doesNotThrow(() => p.validateTokenPreservationReferenceV2Source(f.c, f.d, f.publication, f.source, f.sd));
    sample.terminalAdmissionHash = status === 5n ? H(999) : Z;
    assert.throws(() => p.validateTokenPreservationReferenceV2Source(f.c, f.d, f.publication, f.source, f.sd));
  }
});

test("preview draft, CURATOR authority and one-plus-five canonical normalization preserve exact bytes", () => {
  for (const type of [0n, 1n, 2n, 3n]) {
    const f = completed(example(type));
    assert.deepEqual(p.tokenPreservationReferenceV2PreviewReceipt(f.c, f.publication, A(70), { authorizationClass: 3n, grantRevision: 1n }, f.publication.observation.expectedSourcesHash), f.preview);
    assert.equal(p.tokenPreservationReferenceV2ReferenceBytes(f.c, f.d, f.publication, f.receipt, f.source, f.environmentBytes), f.canonical);
    const changed = copy(f.receipt); Object.assign(changed.observation, { recordHash: H(1), recordChainHash: H(2), payloadHash: H(3), payloadBytes: 20n, recordedAt: 50n });
    assert.equal(p.tokenPreservationReferenceV2PayloadBytes(f.c, { ...f.publication, observation: { ...f.publication.observation, expectedSourcesHash: H(999) } }, changed, f.source, f.environmentBytes), f.canonical);
    assert.deepEqual(p.decodeTokenPreservationReferenceV2ReferenceBytes(f.c.scopeKind, f.canonical).receipt, f.preview);
    assert.throws(() => p.tokenPreservationReferenceV2PreviewReceipt(f.c, f.publication, A(70), { authorizationClass: 7n, grantRevision: 1n }, H(1)));
  }
});

test("independent record and subject-chain preimages bind actual source hash and mined time", () => {
  for (const type of [0n, 1n, 2n, 3n]) {
    const f = completed(example(type)), r = f.receipt.observation;
    assert.equal(p.tokenPreservationReferenceV2RecordHash(f.c, f.publication, f.receipt), r.recordHash);
    assert.equal(p.tokenPreservationReferenceV2ChainHash(f.c, f.publication.scope, Z, r.revision, r.recordHash), r.recordChainHash);
    assert.doesNotThrow(() => auth(f));
    assert.notEqual(p.tokenPreservationReferenceV2RecordHash(f.c, f.publication, { ...f.receipt, observation: { ...r, recordedAt: 13n } }), r.recordHash);
    assert.notEqual(p.tokenPreservationReferenceV2RecordHash(f.c, { ...f.publication, observation: { ...f.publication.observation, expectedSourcesHash: H(999) } }, f.receipt), r.recordHash);
    assert.doesNotThrow(() => auth({ ...f, d: { ...f.d, readGas: 0n, sourceGas: 0n, archiveGas: 0n, snapshotGas: 0n } }));
  }
});

test("fully rehashed history rejects TOKEN same-subject different collection and nested snapshot/root aliases", () => {
  for (const type of [0n, 1n, 2n, 3n]) {
    const f = example(type);
    for (const mutate of [s => s.scopeSubject = H(999), s => s.snapshotSource.content.scope.collectionId++, s => s.snapshotSource.selection.scope.collectionId++, s => s.snapshotSource.outputs.scope.collectionId++, s => s.snapshotSource.membership.scopeSubject = H(999), s => s.snapshot.recordHash = H(999)]) {
      const bad = copy(f); mutate(bad.source); assert.throws(() => auth(completed(bad)), /scope|snapshot/i);
    }
    const bad = copy(f); bad.source.contentRoot.publication[type === 0n ? "collectionId" : "snapshotRevision"]++;
    assert.throws(() => auth(completed(bad)), /root/i);
    const next = copy(f); next.publication.observation.expectedHead = H("prior"); next.publication.observation.expectedRevision = 7n;
    assert.doesNotThrow(() => auth(completed(next, H("priorChain"))));
    assert.throws(() => auth({ ...completed(f), previousChainHash: H("wrongFirst") }));
  }
});

test("fully rehashed old or unknown family, snapshot definitions and VIEW producers cannot enter V2 history", () => {
  for (const type of [0n, 1n]) {
    for (const mutate of [s => s.snapshotSource.content.preservationProfile = id("6529STREAM_PRESERVATION_RENDER_V1"), s => s.snapshotSource.outputs.preservationProfile = H("unknown"), s => s.snapshot.schemaHash = H("oldSchema"), s => s.snapshot.profileHash = H("oldProfile"), s => s.snapshot.canonicalizationHash = H("oldCanon"), s => s.samples[0].preservation.profile = id("6529STREAM_PRESERVATION_VIEW_V2"), s => s.contentRootBinding.profileId = H("oldRoot"), s => s.contentRootBinding.preservationOutputProfile = H("unknownFamily")]) {
      const bad = example(type), { c, d, sd, source: f } = bad, k = c.scopeKind;
      mutate(f);
      if (k === "collection") {
        f.snapshotSource.rootBinding = copy(f.contentRootBinding);
        f.contentRootRecordHash = hash(["bytes32", "uint256", "address", T.CollectionRootRecord, T.CollectionRootBinding], [id("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"), c.chainId, d.targets[4], f.contentRoot, f.contentRootBinding]);
      }
      f.snapshot.sourceHash = hash(["bytes32", "uint256", "address", "address[11]", "bytes32[11]", field(srcType(k), "snapshotSource")], [id(`6529STREAM_${k === "scoped" ? "SCOPED_" : ""}PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2`), c.chainId, d.targets[5], sd.targets, sd.codeHashes, f.snapshotSource]);
      if (k === "scoped") {
        Object.assign(f.contentRootBinding, { snapshotSchemaHash: f.snapshot.schemaHash, snapshotProfileHash: f.snapshot.profileHash, snapshotCanonicalizationHash: f.snapshot.canonicalizationHash });
        f.contentRoot.snapshotSourceHash = f.snapshot.sourceHash;
        f.contentRoot.stateHash = hash(["bytes32", "uint256", "address", "address", T.ScopedRootRecord, T.ScopedRootBinding], [id("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V2"), c.chainId, d.targets[4], c.core, { ...f.contentRoot, stateHash: Z, artistConsent: Z, publishedAt: 0n }, f.contentRootBinding]);
      }
      assert.throws(() => auth(completed(bad)), /family|profile/i);
    }
  }
});

test("raw getters, closed scopes and supplied candidate checks avoid invented uint32 gas bounds", () => {
  const f = example(0n), o = f.publication.observation;
  assert.doesNotThrow(() => p.validateTokenPreservationReferenceV2Dependencies(f.c, { ...f.d, readGas: 1n << 200n, sourceGas: 1n << 201n, snapshotGas: 1n << 202n, archiveGas: 1n << 200n }));
  assert.throws(() => p.validateTokenPreservationReferenceV2Dependencies(f.c, { ...f.d, archiveGas: 49999n }));
  assert.doesNotThrow(() => p.validateTokenPreservationReferenceV2Publication("collection", f.publication, "preview"));
  assert.throws(() => p.validateTokenPreservationReferenceV2Publication("collection", f.publication, "publish"));
  const state = { timestamp: 10n, head: Z, count: 0n, referenceIdUsed: false, lock: zero(T.Lock) };
  assert.doesNotThrow(() => p.validateTokenPreservationReferenceV2Candidate("collection", f.publication, state, "preview"));
  for (const change of [{ timestamp: 9n }, { count: 1n }, { head: H(1) }, { referenceIdUsed: true }, { lock: { ...state.lock, actionId: H(1) } }, { timestamp: 1n << 64n }]) assert.throws(() => p.validateTokenPreservationReferenceV2Candidate("collection", f.publication, { ...state, ...change }, "preview"));
  assert.doesNotThrow(() => p.validateTokenPreservationReferenceV2Candidate("collection", f.publication, { ...state, lock: { ...state.lock, recordHash: H(1) } }, "preview"));
  for (const scope of [{ ...f.publication.scope, scopeType: 4n }, { ...f.publication.scope, tokenId: 1n }]) assert.throws(() => p.validateTokenPreservationReferenceV2Publication("collection", { ...f.publication, scope }, "preview"));
  assert.throws(() => p.validateTokenPreservationReferenceV2Publication("collection", { ...f.publication, observation: { ...o, expectedRevision: 1n } }, "preview"));
});

test("five original calls and unchanged V1 preparation identities roundtrip direct and generic Safe", () => {
  for (const type of [0n, 1n]) {
    const f = completed(example(type));
    const rows = f.publication.observation.environment.packageFiles;
    const requests = [{ kind: "prepareEnvironment", environment: f.publication.observation.environment }, ...["prepareFileInventory", "prepareFileInventoryPart", "prepareFileInventoryFromParts"].map(kind => ({ kind, rows, relative: true })), { kind: "publishReference", publication: f.publication }];
    for (const request of requests) {
      const plan = p.prepareTokenPreservationReferenceV2Call(f.c, A(70), request);
      assert.deepEqual(p.normalizeTokenPreservationReferenceV2Call(plan), plan);
      const args = request.kind === "prepareEnvironment" ? [request.environment] : request.kind === "publishReference" ? [request.publication] : [request.rows, request.relative];
      assert.equal(plan.call.data, host[f.c.scopeKind].encodeFunctionData(request.kind, args));
      assert.equal(toSafeCall(plan.call).operation, 0); assert.equal(toSafeCall(plan.call).value, "0");
      assert.equal(toSafeCall(plan.call).data, plan.call.data);
      if (request.kind === "prepareEnvironment") assert.equal(plan.preparation.id, environment.prepareReferenceEnvironment(f.c.chainId, f.c.reference, request.environment).environmentId);
      else if (request.kind !== "publishReference") assert.equal(plan.preparation.id, request.kind === "prepareFileInventoryPart" ? inventory.referenceInventoryPartId(f.c.chainId, f.c.reference, true, rows) : inventory.prepareReferenceInventory(f.c.chainId, f.c.reference, true, rows).inventoryId);
      for (const call of [{ ...plan.call, value: 1n }, { ...plan.call, to: A(999) }, { ...plan.call, data: `${plan.call.data}00` }]) assert.throws(() => p.normalizeTokenPreservationReferenceV2Call({ ...plan, call }));
    }
    assert.throws(() => p.prepareTokenPreservationReferenceV2Call(f.c, A(70), { kind: "lockReference", scope: f.publication.scope }));
  }
});

test("read plans distinguish head from current and preserve collection-only chunk getters", () => {
  for (const type of [0n, 1n]) {
    const f = completed(example(type));
    for (const request of [{ kind: "dependencies" }, { kind: "deploymentChainId" }, { kind: "previewReference", publication: { ...f.publication, observation: { ...f.publication.observation, expectedSourcesHash: Z } }, recorder: A(70) }, { kind: "currentReference", scope: f.publication.scope }, { kind: "requireCurrent", scope: f.publication.scope, hash: H(1), revision: 1n }, { kind: "referenceSource", hash: H(1) }, { kind: "referenceAt", scope: f.publication.scope, index: 0n }]) {
      const plan = p.prepareTokenPreservationReferenceV2Read(f.c, A(70), request);
      assert.deepEqual(p.normalizeTokenPreservationReferenceV2Read(plan), plan);
      assert.equal(host[f.c.scopeKind].parseTransaction({ data: plan.call.data }).name, request.kind);
    }
    const request = { kind: "referenceChunkAt", hash: H(1), index: 0n };
    if (type === 0n) assert.doesNotThrow(() => p.prepareTokenPreservationReferenceV2Read(f.c, A(70), request));
    else assert.throws(() => p.prepareTokenPreservationReferenceV2Read(f.c, A(70), request), /chunk/);
    assert.throws(() => p.prepareTokenPreservationReferenceV2Read(f.c, A(70), { kind: type === 0n ? "scopedPreservationPolicyReferenceProfile" : "preservationPolicyReferenceProfile" }));
  }
});

test("strict arrays, scalars and detached normalized graphs reject mutation and surplus fields", () => {
  const f = example(1n), saved = p.normalizeTokenPreservationReferenceV2Publication(f.publication);
  f.publication.observation.captures[0].capturedAt = 999n;
  assert.equal(saved.observation.captures[0].capturedAt, 10n); assert.ok(Object.isFrozen(saved.observation.environment.packageFiles[0]));
  for (const value of [-1n, 1n << 64n, 1]) assert.throws(() => p.normalizeTokenPreservationReferenceV2Publication({ ...saved, observation: { ...saved.observation, effectiveAt: value } }));
  for (const uri of ["\ud800", "\udfff"]) assert.throws(() => p.normalizeTokenPreservationReferenceV2Publication({ ...saved, observation: { ...saved.observation, manifestURI: uri } }));
  for (const alter of [a => delete a[0], a => a.extra = true, a => Object.defineProperty(a, "hidden", { value: true }), a => a[Symbol("x")] = 1]) {
    const rows = [...saved.observation.captures]; alter(rows);
    assert.throws(() => p.normalizeTokenPreservationReferenceV2Publication({ ...saved, observation: { ...saved.observation, captures: rows } }));
  }
  assert.throws(() => p.normalizeTokenPreservationReferenceV2Publication({ ...saved, [Symbol("extra")]: 1 }));
});

test("literal capture and URI bounds, byte/hash predicates and duplicate inventory constraints", () => {
  const f = example(1n);
  for (const mutate of [o => o.captures[0].sourceSha256 = H(9), o => o.captures[0].repeatCaptureSha256[1] = H(9), o => o.captures[0].environmentManifestHash = H(9), o => o.captures[0].animationHTML = "0x", o => o.captures[0].htmlBytes++, o => o.manifestURI = "https:///bad", o => o.manifestURI = `ipfs://${"é".repeat(1024)}`]) {
    const bad = copy(f.publication); mutate(bad.observation);
    assert.throws(() => p.validateTokenPreservationReferenceV2Publication("scoped", bad, "preview"));
  }
  for (const count of [40960, 40961]) {
    const good = copy(f.publication), html = `0x${"61".repeat(count)}`;
    Object.assign(good.observation.captures[0], { animationHTML: html, htmlHash: keccak256(html), sourceSha256: sha256(html), htmlBytes: BigInt(count) });
    if (count === 40960) assert.doesNotThrow(() => p.validateTokenPreservationReferenceV2Publication("scoped", good, "preview"));
    else assert.throws(() => p.validateTokenPreservationReferenceV2Publication("scoped", good, "preview"));
  }
  const rows = Array.from({ length: 65 }, (_, i) => ({ path: `f${String(i).padStart(2, "0")}`, byteSize: 0n, sha256Digest: H(i) }));
  assert.throws(() => p.prepareTokenPreservationReferenceV2Call(f.c, A(70), { kind: "prepareFileInventoryPart", relative: true, rows }));
});

test("canonical payload and submitted publication have independent 524288-byte chunk bounds", () => {
  const f = completed(example(1n));
  const original = p.encodeTokenPreservationReferenceV2Publication(f.publication);
  assert.notEqual(original, f.canonical);
  for (const raw of [original, f.canonical, `0x${"ab".repeat(524288)}`]) {
    const chunks = p.tokenPreservationReferenceV2Chunks(raw);
    assert.equal(`0x${chunks.map(c => c.data.slice(2)).join("")}`, raw);
    chunks.slice(0, -1).forEach(c => assert.equal(c.byteLength, 8192n));
  }
  assert.throws(() => p.tokenPreservationReferenceV2Chunks(`0x${"ab".repeat(524289)}`));
  assert.throws(() => p.decodeTokenPreservationReferenceV2Payload("collection", f.canonical));
  assert.throws(() => p.decodeTokenPreservationReferenceV2Payload("scoped", `${f.canonical}${"00".repeat(32)}`));
  const large = copy(f.publication); large.observation.environment.licenseNote = "a".repeat(524288);
  assert.throws(() => p.encodeTokenPreservationReferenceV2Publication(large), /oversized/);
});
