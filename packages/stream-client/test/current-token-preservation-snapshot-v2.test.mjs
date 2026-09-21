import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as p from "../dist/current-token-preservation-snapshot-v2.js";
import { toSafeCall } from "../dist/safe.js";
import { fixture, compiledInterfaces as ci } from "./current-preservation-v2-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder(), Z = ZeroHash;
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = n => id(String(n));
const copy = structuredClone;
const hash = (types, values) => keccak256(coder.encode(types, values));
const host = { collection: ci.StreamPreservationPolicySnapshotPublicationV2, scoped: ci.StreamScopedPreservationPolicySnapshotPublicationV2 };
// Value tuples only: original nominal-library selectors never enter an ethers Interface.
const enumWidths = new Map();
function visit(value) {
  if (value?.internalType?.startsWith("enum ") && /^uint\d+$/.test(value.type)) enumWidths.set(value.internalType, value.type);
  for (const child of value?.components ?? []) visit(child);
}
Object.values(fixture.abis).flat().forEach(f => [...f.inputs ?? [], ...f.outputs ?? []].forEach(visit));
function valueTuple(value) {
  const type = value.internalType?.startsWith("enum ") ? enumWidths.get(value.internalType) : value.type;
  assert.ok(type, `ordinary compiler enum witness ${value.internalType}`);
  return { ...value, type, ...(value.components ? { components: value.components.map(valueTuple) } : {}) };
}
const sourceType = kind => ParamType.from(valueTuple(fixture.libraryAbis[kind === "collection"
  ? "StreamPreservationPolicySnapshotSourceReadsV1" : "StreamScopedPreservationPolicySnapshotSourceReadsV1"]
  .find(f => f.name === "current" && f.inputs.length === 3).outputs[0]));
const field = (t, n) => t.components.find(c => c.name === n);
const T = {
  Dependencies: host.collection.getFunction("dependencies").outputs[0],
  Receipt: host.collection.getFunction("currentSnapshot").outputs[0],
  Lock: host.collection.getFunction("snapshotLock").outputs[0],
  CollectionPublication: host.collection.getFunction("publishSnapshot").inputs[0],
  ScopedPublication: host.scoped.getFunction("publishSnapshot").inputs[0],
  CollectionSource: sourceType("collection"), ScopedSource: sourceType("scoped"),
};
for (const [name, key] of [["Scope", "scope"], ["Membership", "membership"], ["ArtistPresentation", "artist"], ["SelectionPlan", "selection"], ["ContentPlan", "content"], ["Manifest", "outputs"], ["PolicyEvidence", "entropy"]]) T[name] = field(T.ScopedSource, key);
T.RootRecord = field(T.CollectionSource, "root");
T.RootPublication = field(T.RootRecord, "publication");
T.RootBinding = field(T.CollectionSource, "rootBinding");
T.CoordinatorPolicy = field(T.PolicyEvidence, "policies").arrayChildren;
T.Policy = field(T.CoordinatorPolicy, "collectionPolicy");
function zero(t) {
  if (t.baseType === "tuple") return Object.fromEntries(t.components.map(c => [c.name, zero(c)]));
  if (t.baseType === "array") return Array.from({ length: Math.max(0, t.arrayLength) }, () => zero(t.arrayChildren));
  if (t.type.startsWith("uint")) return 0n;
  if (t.type === "address") return ZeroAddress;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  return t.type === "bytes" ? "0x" : `0x${"00".repeat(Number(t.type.slice(5)))}`;
}
const pubType = kind => kind === "collection" ? T.CollectionPublication : T.ScopedPublication;
const srcType = kind => kind === "collection" ? T.CollectionSource : T.ScopedSource;
const domain = (kind, purpose) => id(`6529STREAM_${kind === "scoped" ? "SCOPED_" : ""}PRESERVATION_POLICY_SNAPSHOT_${purpose}_V2`);
const subject = (c, s) => s.scopeType < 2n
  ? hash(["bytes32", "uint256", "address", "uint256"], [id(s.scopeType === 0n ? "6529STREAM_SUBJECT_COLLECTION_V1" : "6529STREAM_SUBJECT_TOKEN_V1"), c.chainId, c.core, s.scopeType === 0n ? s.collectionId : s.tokenId])
  : hash(["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"], [id("6529STREAM_SUBJECT_SCOPE_V1"), c.chainId, c.core, s.collectionId, s.scopeType, s.scopeId]);
function documents(kind) {
  const prefix = kind === "collection" ? "preservation-policy-collection-snapshot-v2" : "scoped-preservation-policy-snapshot-v2";
  return ["schema", "profile", "abi"].map(s => fixture.documents[`docs/schemas/preservation/${prefix}.${s}.json`].text);
}
const rootDocuments = [...fixture.sourceTexts["smart-contracts/domains/finality/StreamPreservationPolicyContentRootSchemasV2.sol"].matchAll(/return bytes\(\s*'([^']+)'\s*\);/g)].map(m => m[1]);
const outputDocuments = [...fixture.sourceTexts["smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV2.sol"].matchAll(/return bytes\(\s*'((?:[^'\\]|\\.)*)'\s*\)/g)].map(m => m[1].replaceAll("\\'", "'"));
assert.equal(outputDocuments.length, 3);
const hex = s => `0x${Buffer.from(s, "utf8").toString("hex")}`;
function example(scopeType = 0n) {
  const kind = scopeType === 0n ? "collection" : "scoped";
  const c = { chainId: 1n, core: A(1), metadata: A(2), snapshot: A(100), scopeKind: kind };
  const d = { targets: Array.from({ length: 11 }, (_, i) => A(i + 1)), codeHashes: Array.from({ length: 11 }, (_, i) => H(i + 1)), chainId: 1n, readGas: 100000n, sourceGas: 3000000n, inventoryGas: 2000000n };
  const scope = { scopeType, collectionId: 12n, tokenId: scopeType === 1n ? 99n : 0n, scopeId: scopeType > 1n ? H(scopeType) : Z };
  const count = scopeType === 1n ? 1n : 2n;
  const source = zero(srcType(kind));
  source.scope = scope;
  source.membership = { ...source.membership, scopeSubject: subject(c, scope), membershipHash: H("membership"), tokenListHash: H("tokens"), tokenCount: count };
  source.artist = { locked: true, registry: A(20), registryCodeHash: H(20), artistId: H("Artist"), bindingGeneration: 2n, bindingHash: H("binding"), nominatedArtist: A(21), identityRecordHash: H("identity"), acceptanceRecordHash: H("acceptance"), acceptedAt: 1n, lockedAt: 2n, snapshotHash: H("artistSnapshot") };
  source.selection = { scope, membershipHash: source.membership.membershipHash, collectionStateHash: H("collection"), tokenCount: count, nextIndex: count, selectionRoot: H("selection") };
  source.content = { selectionId: H("selectionId"), selectionHash: hash([T.SelectionPlan], [source.selection]), inventoryHash: H("inventory"), policyChainHash: H("policies"), scope, tokenCount: count, nextIndex: count, leafChainHash: H("leaves"), contentRoot: H("content"), outputRoot: H("output"), preservationProfile: id("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2") };
  const row = { ...zero(T.CoordinatorPolicy), coordinator: A(22), indexedCodeHash: H(22), frozen: true, policyHash: H("policy"), componentDataHash: H("component") };
  source.entropy = { planId: H("plan"), inventoryHash: source.content.inventoryHash, policyChainHash: source.content.policyChainHash, policyCount: 1n, allFrozen: true, policies: [row] };
  source.outputs = { checkpointHash: H("checkpoint"), checkpointStateHash: hash([T.ContentPlan], [source.content]), entropySourceSet: d.targets[10], inventoryHash: source.entropy.inventoryHash, policyChainHash: source.entropy.policyChainHash, metadataRouter: d.targets[4], preservationProfile: source.content.preservationProfile, artifactHash: H("artifact"), coverageHash: H("coverage"), artistId: source.artist.artistId, contentRoot: source.content.contentRoot, outputRoot: source.content.outputRoot, manifestHash: H("archive"), scope, tokenCount: count, byteLength: 640n + 1152n * count };
  const planHash = hash(["bytes32", "uint256", "address", "address", "address", "address", T.Manifest], [id("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_PLAN_V2"), c.chainId, d.targets[8], c.core, d.targets[7], d.targets[9], source.outputs]);
  const publication = { ...zero(pubType(kind)), scope, snapshotId: H("snapshotId"), outputManifestRecord: hash(["bytes32", "bytes32"], [id("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_VERIFIED_V2"), planHash]), coordinatorInventoryPlan: source.entropy.planId, manifestURI: "ipfs://snapshot", effectiveAt: 10n, reasonHash: H("reason") };
  if (kind === "collection") {
    const m = source.outputs;
    source.rootBinding = { profileId: id("6529STREAM_PRESERVATION_POLICY_CONTENT_V2"), outputManifest: d.targets[8], outputManifestCodeHash: d.codeHashes[8], checkpoint: d.targets[7], checkpointCodeHash: d.codeHashes[7], checkpointHash: m.checkpointHash, checkpointStateHash: m.checkpointStateHash, entropySourceSet: d.targets[10], entropySourceSetCodeHash: d.codeHashes[10], inventoryHash: m.inventoryHash, policyChainHash: m.policyChainHash, outputRoot: m.outputRoot, outputSchemaHash: keccak256(hex(outputDocuments[0])), outputCanonicalizationHash: keccak256(hex(outputDocuments[1])), leafSchemaHash: keccak256(hex(outputDocuments[2])), rootSchemaHash: keccak256(hex(rootDocuments[0])), rootCanonicalizationHash: keccak256(hex(rootDocuments[1])), metadataRouter: d.targets[4], preservationOutputProfile: m.preservationProfile };
    source.root = { publication: { collectionId: scope.collectionId, expectedPredecessor: Z, verifiedManifestRecordHash: publication.outputManifestRecord, manifestURI: "https://example.com/root" }, contentRoot: m.contentRoot, leafCount: count, manifestHash: m.manifestHash, artistId: source.artist.artistId, bindingGeneration: source.artist.bindingGeneration, bindingHash: source.artist.bindingHash, publisher: A(50), authorizationClass: 7n, grantRevision: 4n, routeHash: H("route"), stateHash: H("state"), artistConsent: H("consent"), publishedAt: 8n };
    publication.contentRootRecord = hash(["bytes32", "uint256", "address", T.RootRecord, T.RootBinding], [id("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"), c.chainId, d.targets[4], source.root, source.rootBinding]);
  } else {
    source.sourceFactory = A(30); source.sourceFactoryCodeHash = H(30); source.factoryDependenciesHash = H("factory");
  }
  return { c, d, publication, source };
}
const payloadTypes = kind => ["bytes32", "uint256", "address", "address[11]", "bytes32[11]", pubType(kind), T.Receipt, srcType(kind)];
function completed(f, predecessorChainHash = Z) {
  const { c, d, source } = f, k = c.scopeKind;
  const sourceHash = hash(["bytes32", "uint256", "address", "address[11]", "bytes32[11]", srcType(k)], [domain(k, "SOURCES"), c.chainId, c.snapshot, d.targets, d.codeHashes, source]);
  const publication = { ...f.publication, expectedSourceHash: sourceHash };
  const docs = documents(k);
  const preview = { ...zero(T.Receipt), scopeSubject: subject(c, publication.scope), predecessor: publication.expectedHead, revision: publication.expectedRevision + 1n, sourceHash, publisher: A(70), authorizationClass: 7n, grantRevision: 4n, displayAuthorizationClass: 8n, displayGrantRevision: 6n, schemaHash: keccak256(hex(docs[0])), profileHash: keccak256(hex(docs[1])), canonicalizationHash: keccak256(hex(docs[2])) };
  const canonical = coder.encode(payloadTypes(k), [domain(k, "PAYLOAD"), c.chainId, c.snapshot, d.targets, d.codeHashes, { ...publication, expectedSourceHash: Z }, preview, source]);
  const receipt = { ...preview, manifestHash: keccak256(canonical), manifestBytes: BigInt((canonical.length - 2) / 2), recordedAt: 12n };
  receipt.recordHash = hash(["bytes32", "uint256", "address", "address", "address", pubType(k), T.Receipt], [domain(k, "RECORD"), c.chainId, c.snapshot, c.core, c.metadata, publication, receipt]);
  receipt.chainHash = hash(["bytes32", "uint256", "address", "address", T.Scope, "bytes32", "uint64", "bytes32"], [domain(k, "CHAIN"), c.chainId, c.snapshot, c.core, publication.scope, predecessorChainHash, receipt.revision, receipt.recordHash]);
  return { ...f, publication, preview, canonical, receipt, predecessorChainHash };
}
const auth = f => p.authenticateTokenPreservationSnapshotV2History(f.c, f.d, f.publication, f.receipt, f.canonical, f.predecessorChainHash);

test("all19 value tuples match original compiler witnesses and structural zero codecs", () => {
  const shape = t => ({ type: t.format("sighash"), fields: t.components?.map(c => ({ name: c.name, ...shape(c) })), child: t.arrayChildren ? shape(t.arrayChildren) : undefined });
  for (const [name, type] of Object.entries(T)) {
    const key = `TOKEN_PRESERVATION_SNAPSHOT_V2_${name.replace(/([a-z])([A-Z])/g, "$1_$2").toUpperCase()}_TUPLE`;
    assert.deepEqual(shape(ParamType.from(p[key])), shape(type), name);
    const raw = coder.encode([type], [zero(type)]);
    assert.equal(p[`encodeTokenPreservationSnapshotV2${name}`](zero(type)), raw);
    assert.deepEqual(p[`decodeTokenPreservationSnapshotV2${name}`](raw), zero(type));
    assert.throws(() => p[`decodeTokenPreservationSnapshotV2${name}`](`${raw}${"00".repeat(32)}`), /canonical/);
  }
  assert.equal((p.encodeTokenPreservationSnapshotV2Dependencies(zero(T.Dependencies)).length - 2) / 2, 832);
  assert.equal((p.encodeTokenPreservationSnapshotV2Receipt(zero(T.Receipt)).length - 2) / 2, 544);
  assert.equal((p.encodeTokenPreservationSnapshotV2Lock(zero(T.Lock)).length - 2) / 2, 128);
});

test("both genuine concrete ABIs preserve exact methods, tuples, events and the sole write", () => {
  for (const kind of ["collection", "scoped"]) {
    const own = p.tokenPreservationSnapshotV2Interface(kind);
    for (const f of own.fragments) {
      const witness = f.type === "function" ? host[kind].getFunction(f.format("sighash")) : host[kind].getEvent(f.format("sighash"));
      assert.ok(witness);
      if (f.type === "function") {
        assert.equal(f.selector, witness.selector); assert.equal(f.stateMutability, witness.stateMutability);
        assert.deepEqual(f.outputs.map(x => x.format("sighash")), witness.outputs.map(x => x.format("sighash")));
      } else assert.deepEqual(f.inputs.map(x => Boolean(x.indexed)), witness.inputs.map(x => Boolean(x.indexed)));
    }
    assert.deepEqual(own.fragments.filter(f => f.type === "function" && f.stateMutability === "nonpayable").map(f => f.name), ["publishSnapshot"]);
    for (const name of ["lockSnapshot", "raiseGasParameter"]) assert.equal(own.getFunction(name), null);
  }
  assert.equal(host.collection.getFunction("publishSnapshot").selector, "0xc0d79bd7");
  assert.equal(host.scoped.getFunction("publishSnapshot").selector, "0x178cc408");
  assert.equal(p.tokenPreservationSnapshotV2Interface("scoped").getFunction("snapshotChunkAt"), null);
});

test("six exact V2 documents and collection two-root prerequisite bytes retain original enums and large schema", () => {
  for (const kind of ["collection", "scoped"]) {
    const defs = p.tokenPreservationSnapshotV2Definitions(kind);
    assert.deepEqual(defs.map(d => d.kind), [0n, 2n, 1n]);
    for (const [i, doc] of documents(kind).entries()) {
      assert.equal(defs[i].data, hex(doc)); assert.equal(defs[i].hash, keccak256(hex(doc)));
      assert.equal(defs[i].id, id(JSON.parse(doc).name)); assert.equal(defs[i].byteLength, BigInt(Buffer.byteLength(doc)));
    }
  }
  assert.equal(p.tokenPreservationSnapshotV2Definitions("collection")[0].byteLength, 15067n);
  assert.deepEqual(p.tokenPreservationSnapshotV2RootDefinitions().map(d => d.data), rootDocuments.map(hex));
  assert.deepEqual(p.tokenPreservationSnapshotV2RootDefinitions().map(d => d.kind), [0n, 1n]);
  assert.throws(() => p.tokenPreservationSnapshotV2Definitions("view"));
});

test("closed scope variants and supplied current dependencies preserve raw zero/gas distinctions", () => {
  for (const type of [0n, 1n, 2n, 3n]) {
    const f = example(type);
    assert.deepEqual(p.validateTokenPreservationSnapshotV2Scope(f.c.scopeKind, f.publication.scope), f.publication.scope);
    assert.equal(p.tokenPreservationSnapshotV2ScopeSubject(f.c.chainId, f.c.core, f.publication.scope), subject(f.c, f.publication.scope));
    assert.doesNotThrow(() => p.validateTokenPreservationSnapshotV2Dependencies(f.c, f.d));
    assert.throws(() => p.validateTokenPreservationSnapshotV2Scope(f.c.scopeKind === "collection" ? "scoped" : "collection", f.publication.scope));
  }
  const f = example(1n);
  for (const scope of [{ ...f.publication.scope, scopeType: 4n }, { ...f.publication.scope, scopeId: H(8) }, { ...f.publication.scope, collectionId: 0n }]) assert.throws(() => p.validateTokenPreservationSnapshotV2Scope("scoped", scope));
  assert.throws(() => p.validateTokenPreservationSnapshotV2Dependencies(f.c, { ...f.d, readGas: 49999n }));
  assert.throws(() => p.validateTokenPreservationSnapshotV2Dependencies(f.c, { ...f.d, sourceGas: 1n << 32n }));
  assert.doesNotThrow(() => p.normalizeTokenPreservationSnapshotV2Dependencies(zero(T.Dependencies)));
});

test("source hashes independently encode original variant domains and omit only mutable gas caps", () => {
  for (const type of [0n, 1n, 2n, 3n]) {
    const f = completed(example(type));
    assert.equal(p.tokenPreservationSnapshotV2SourceHash(f.c, f.d, f.source), f.publication.expectedSourceHash);
    assert.equal(p.tokenPreservationSnapshotV2SourceHash(f.c, { ...f.d, readGas: 0n, sourceGas: (1n << 256n) - 1n, inventoryGas: 1n }, f.source), f.publication.expectedSourceHash);
    assert.notEqual(p.tokenPreservationSnapshotV2SourceHash({ ...f.c, snapshot: A(999) }, f.d, f.source), f.publication.expectedSourceHash);
    assert.notEqual(p.tokenPreservationSnapshotV2SourceHash(f.c, { ...f.d, codeHashes: f.d.codeHashes.map((h, i) => i === 10 ? H(999) : h) }, f.source), f.publication.expectedSourceHash);
    assert.notEqual(p.tokenPreservationSnapshotV2SourceHash(f.c, f.d, { ...f.source, artist: { ...f.source.artist, snapshotHash: H(999) } }), f.publication.expectedSourceHash);
    assert.throws(() => p.normalizeTokenPreservationSnapshotV2Source(type === 0n ? "scoped" : "collection", f.source));
  }
});

test("complete source joins bind original covered output, entropy partitions and collection root", () => {
  for (const type of [0n, 1n, 2n, 3n]) {
    const f = example(type);
    assert.doesNotThrow(() => p.validateTokenPreservationSnapshotV2Source(f.c, f.d, f.publication, f.source));
    for (const mutate of [s => s.content.nextIndex = 0n, s => s.outputs.artistId = H(999), s => s.outputs.preservationProfile = id("6529STREAM_PRESERVATION_RENDER_V1"), s => s.selection.scope.collectionId = 999n, s => s.entropy.policies[0].frozen = false, s => s.entropy.allFrozen = false, s => s.entropy.policyCount = 2n, s => s.content.selectionHash = H(999)]) {
      const altered = copy(f.source); mutate(altered);
      assert.throws(() => p.validateTokenPreservationSnapshotV2Source(f.c, f.d, f.publication, altered));
    }
    assert.throws(() => p.validateTokenPreservationSnapshotV2Source(f.c, f.d, { ...f.publication, outputManifestRecord: H(999) }, f.source), /manifest hash/i);
    if (type === 0n) {
      assert.equal(p.tokenPreservationSnapshotV2RootRecordHash(f.c.chainId, f.d.targets[4], f.source.root, f.source.rootBinding), f.publication.contentRootRecord);
      const changed = copy(f.source); changed.rootBinding.outputManifest = A(999);
      assert.throws(() => p.validateTokenPreservationSnapshotV2Source(f.c, f.d, f.publication, changed), /binding/);
    } else assert.throws(() => p.validateTokenPreservationSnapshotV2Source(f.c, f.d, f.publication, { ...f.source, sourceFactory: ZeroAddress }));
  }
});

test("preview admits unset expected source, independent grants, and canonical normalization matches compiler bytes", () => {
  for (const type of [0n, 1n, 2n, 3n]) {
    const f = completed(example(type)), grants = { authorizationClass: 7n, grantRevision: 4n, displayAuthorizationClass: 8n, displayGrantRevision: 6n };
    const preview = p.tokenPreservationSnapshotV2PreviewReceipt(f.c, { ...f.publication, expectedSourceHash: Z }, A(70), grants, f.publication.expectedSourceHash);
    assert.deepEqual(preview, f.preview);
    assert.equal(p.tokenPreservationSnapshotV2SnapshotBytes(f.c, f.d, f.publication, f.receipt, f.source), f.canonical);
    assert.deepEqual(p.decodeTokenPreservationSnapshotV2SnapshotBytes(f.c.scopeKind, f.canonical).receipt, preview);
    assert.equal(p.tokenPreservationSnapshotV2SnapshotBytes(f.c, f.d, { ...f.publication, expectedSourceHash: H(999) }, { ...f.receipt, recordHash: H(1), chainHash: H(2), recordedAt: 999n, manifestBytes: 99n, manifestHash: H(3), sourceHash: H(4) }, f.source), f.canonical);
    assert.throws(() => p.tokenPreservationSnapshotV2PreviewReceipt(f.c, f.publication, A(70), { ...grants, displayGrantRevision: 0n }, H(1)));
    assert.throws(() => p.tokenPreservationSnapshotV2PreviewReceipt(f.c, f.publication, A(70), { ...grants, authorizationClass: 3n }, H(1)));
  }
});

test("record and chain preimages retain actual expectedSourceHash and mined time", () => {
  for (const type of [0n, 1n]) {
    const f = completed(example(type));
    assert.equal(p.tokenPreservationSnapshotV2RecordHash(f.c, f.publication, f.receipt), f.receipt.recordHash);
    assert.equal(p.tokenPreservationSnapshotV2ChainHash(f.c, f.publication.scope, Z, f.receipt.revision, f.receipt.recordHash), f.receipt.chainHash);
    assert.equal(p.tokenPreservationSnapshotV2RecordHash(f.c, f.publication, { ...f.receipt, recordHash: H(998), chainHash: H(999) }), f.receipt.recordHash);
    for (const key of ["sourceHash", "manifestHash", "schemaHash", "profileHash", "canonicalizationHash", "scopeSubject", "predecessor"]) assert.notEqual(p.tokenPreservationSnapshotV2RecordHash(f.c, f.publication, { ...f.receipt, [key]: H(999) }), f.receipt.recordHash);
    assert.notEqual(p.tokenPreservationSnapshotV2RecordHash(f.c, f.publication, { ...f.receipt, recordedAt: 13n }), f.receipt.recordHash);
    assert.notEqual(p.tokenPreservationSnapshotV2RecordHash(f.c, { ...f.publication, expectedSourceHash: Z }, f.receipt), f.receipt.recordHash);
    assert.notEqual(p.tokenPreservationSnapshotV2ChainHash(f.c, f.publication.scope, H("previous"), 1n, f.receipt.recordHash), f.receipt.chainHash);
  }
});

test("immutable history authenticates full scope, lineage and exact payload without live gas or authority", () => {
  for (const type of [0n, 1n, 2n, 3n]) {
    const f = completed(example(type));
    const checked = auth(f);
    assert.equal(checked.currentnessChecked, false); assert.equal(checked.authorityChecked, false); assert.equal(checked.factsVerified, false);
    assert.doesNotThrow(() => auth({ ...f, d: { ...f.d, readGas: 0n, sourceGas: 0n, inventoryGas: 0n } }));
    const later = example(type); later.publication.expectedHead = H("old"); later.publication.expectedRevision = 9n;
    assert.doesNotThrow(() => auth(completed(later, H("oldChain"))));
    for (const mutate of [x => x.publication.expectedHead = H("old"), x => x.publication.expectedRevision = 1n, x => x.receipt.revision = 2n, x => x.receipt.displayGrantRevision = 0n, x => x.receipt.recordedAt = 9n]) {
      const altered = copy(f); mutate(altered); assert.throws(() => auth(altered));
    }
  }
});

test("fully rehashed TOKEN subject aliases and substituted inner commitments still fail history", () => {
  const f = example(1n);
  f.publication.scope = { ...f.publication.scope, collectionId: 999n };
  assert.equal(subject(f.c, f.publication.scope), f.source.membership.scopeSubject);
  assert.throws(() => auth(completed(f)), /scope/);
  for (const mutate of [x => x.source.content.selectionHash = H(999), x => x.source.outputs.checkpointStateHash = H(999), x => x.publication.outputManifestRecord = H(999)]) {
    const x = example(2n); mutate(x); assert.throws(() => auth(completed(x)));
  }
  const col = example(); col.source.rootBinding.rootSchemaHash = H(999);
  col.publication.contentRootRecord = hash(["bytes32", "uint256", "address", T.RootRecord, T.RootBinding], [id("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"), col.c.chainId, col.d.targets[4], col.source.root, col.source.rootBinding]);
  assert.throws(() => auth(completed(col)), /binding/);
});

test("candidate timing/lineage/used ID and URI rules are separate from raw publication codecs", () => {
  const f = completed(example()), state = { timestamp: 10n, head: Z, count: 0n, snapshotIdUsed: false, lock: zero(T.Lock) };
  assert.doesNotThrow(() => p.validateTokenPreservationSnapshotV2Candidate("collection", f.publication, state));
  for (const change of [{ timestamp: 9n }, { timestamp: 1n << 64n }, { head: H(1) }, { count: 1n }, { snapshotIdUsed: true }, { lock: { ...state.lock, actionId: H(1) } }]) assert.throws(() => p.validateTokenPreservationSnapshotV2Candidate("collection", f.publication, { ...state, ...change }));
  assert.doesNotThrow(() => p.validateTokenPreservationSnapshotV2Publication("collection", { ...f.publication, expectedSourceHash: Z }, false));
  assert.throws(() => p.validateTokenPreservationSnapshotV2Publication("collection", { ...f.publication, expectedSourceHash: Z }));
  for (const uri of ["", "ar://abc", "ipfs://abc", "https://example.com/a", "ipfs://" + "é".repeat(1020)]) assert.doesNotThrow(() => p.validateTokenPreservationSnapshotV2Publication("collection", { ...f.publication, manifestURI: uri }));
  for (const uri of ["https:///a", "ipfs://", "http://a", "ar://x\n", "ar://\ud800", "ipfs://" + "é".repeat(1021)]) assert.throws(() => p.validateTokenPreservationSnapshotV2Publication("collection", { ...f.publication, manifestURI: uri }));
  assert.doesNotThrow(() => p.normalizeTokenPreservationSnapshotV2CollectionPublication(zero(T.CollectionPublication)));
});

test("canonical decoding refuses dirty words, alternate tails, wrong domains and normalized-field substitutions", () => {
  const f = completed(example(1n)), values = coder.decode(payloadTypes("scoped"), f.canonical);
  const fields = [domain("scoped", "PAYLOAD"), f.c.chainId, f.c.snapshot, f.d.targets, f.d.codeHashes, { ...f.publication, expectedSourceHash: Z }, f.preview, f.source];
  assert.equal(values.length, 8);
  for (const mutate of [v => v[0] = domain("collection", "PAYLOAD"), v => v[5].expectedSourceHash = H(1), v => v[6].recordedAt = 1n, v => v[6].sourceHash = H(1)]) {
    const altered = copy(fields); mutate(altered);
    assert.throws(() => p.decodeTokenPreservationSnapshotV2SnapshotBytes("scoped", coder.encode(payloadTypes("scoped"), altered)));
  }
  assert.throws(() => p.decodeTokenPreservationSnapshotV2SnapshotBytes("scoped", `${f.canonical}00`));
  const receiptRaw = coder.encode([T.Receipt], [f.receipt]);
  const dirty = receiptRaw.slice(0, 2 + 9 * 64) + "01" + receiptRaw.slice(2 + 9 * 64 + 2);
  assert.throws(() => p.decodeTokenPreservationSnapshotV2Receipt(dirty));
});

test("original payload and policy bounds plus exact64 Store chunks are finite and immutable", () => {
  const raw = `0x${"ab".repeat(524288)}`;
  const chunks = p.tokenPreservationSnapshotV2Chunks(raw);
  assert.equal(chunks.length, 64); assert.equal(chunks.at(-1).byteLength, 8192n);
  assert.equal(`0x${chunks.map(c => c.data.slice(2)).join("")}`, raw);
  chunks.forEach(c => { assert.equal(c.hash, keccak256(c.data)); assert.equal(c.runtime, `0x00${c.data.slice(2)}`); assert.equal(c.runtimeHash, keccak256(c.runtime)); });
  assert.equal(p.tokenPreservationSnapshotV2Chunks("0x" + "ab".repeat(8193))[1].byteLength, 1n);
  assert.throws(() => p.tokenPreservationSnapshotV2Chunks(`${raw}ab`)); assert.throws(() => p.tokenPreservationSnapshotV2Chunks("0x"));
  const f = example(2n), row = f.source.entropy.policies[0];
  const max = { ...f.source, entropy: { ...f.source.entropy, policyCount: 630n, policies: Array(630).fill(row) } };
  assert.doesNotThrow(() => p.normalizeTokenPreservationSnapshotV2ScopedSource(max));
  assert.throws(() => p.normalizeTokenPreservationSnapshotV2ScopedSource({ ...max, entropy: { ...max.entropy, policies: Array(631).fill(row) } }));
  assert.throws(() => p.tokenPreservationSnapshotV2SnapshotBytes(f.c, f.d, f.publication, zero(T.Receipt), max), /bound/);
  assert.throws(() => p.decodeTokenPreservationSnapshotV2SnapshotBytes("scoped", raw + "00"), /bound/);
});

test("strict widths, dense own arrays, nested ownership and surplus fields reject before encoding", () => {
  const f = example(1n), normalized = p.normalizeTokenPreservationSnapshotV2ScopedSource(f.source);
  f.source.entropy.policies[0].policyHash = H(999);
  assert.notEqual(normalized.entropy.policies[0].policyHash, f.source.entropy.policies[0].policyHash);
  assert.ok(Object.isFrozen(normalized.entropy.policies)); assert.ok(Object.isFrozen(normalized.entropy.policies[0]));
  for (const mutate of [a => delete a[0], a => a.push(H(999)), a => Object.defineProperty(a, "extra", { value: 1 }), a => a[Symbol("extra")] = 1]) {
    const d = copy(f.d); mutate(d.codeHashes); assert.throws(() => p.normalizeTokenPreservationSnapshotV2Dependencies(d));
  }
  assert.throws(() => p.normalizeTokenPreservationSnapshotV2Receipt({ ...zero(T.Receipt), revision: 1n << 64n }));
  assert.throws(() => p.normalizeTokenPreservationSnapshotV2Receipt({ ...zero(T.Receipt), manifestBytes: 1n << 32n }));
  assert.throws(() => p.normalizeTokenPreservationSnapshotV2Coordinates({ ...f.c, chainId: 1 }));
  assert.throws(() => p.normalizeTokenPreservationSnapshotV2Coordinates({ ...f.c, extra: 1 }));
  assert.throws(() => p.normalizeTokenPreservationSnapshotV2ScopedSource({ ...normalized, sourceFactoryExtra: A(999) }));
});

test("closed publish/read planners round-trip original calldata, Safe CALL and caller/target/value ownership", () => {
  for (const type of [0n, 1n, 2n, 3n]) {
    const f = completed(example(type)), call = p.prepareTokenPreservationSnapshotV2Call(f.c, A(70), { kind: "publishSnapshot", publication: f.publication });
    assert.equal(call.call.data, host[f.c.scopeKind].encodeFunctionData("publishSnapshot", [f.publication]));
    assert.deepEqual(p.normalizeTokenPreservationSnapshotV2Call(call), call);
    assert.deepEqual(toSafeCall(call.call), { to: f.c.snapshot, value: "0", data: call.call.data, operation: 0 });
    for (const mutation of [{ to: A(999) }, { data: call.call.data + "00" }, { value: 1n }]) assert.throws(() => p.normalizeTokenPreservationSnapshotV2Call({ ...call, call: { ...call.call, ...mutation } }));
    const requests = [
      { kind: "previewSnapshot", publication: { ...f.publication, expectedSourceHash: Z }, publisher: A(70) },
      ...["currentSnapshot", "snapshotCount", "snapshotLock"].map(kind => ({ kind, scope: f.publication.scope })),
      { kind: "snapshotAt", scope: f.publication.scope, index: 0n },
      { kind: "requireCurrent", scope: f.publication.scope, recordHash: f.receipt.recordHash, revision: 1n },
      ...["snapshotRecord", "snapshotPayload"].map(kind => ({ kind, recordHash: f.receipt.recordHash })),
      ...["dependencies", "core", "metadataHost", "authorityCodeHash", "governanceAuthority", type === 0n ? "preservationPolicySnapshotProfile" : "scopedPreservationPolicySnapshotProfile"].map(kind => ({ kind })),
      { kind: "supportsInterface", interfaceId: "0x01ffc9a7" },
    ];
    if (type === 0n) requests.push({ kind: "snapshotChunkAt", recordHash: f.receipt.recordHash, index: 1n }, { kind: "snapshotChunkCount", recordHash: f.receipt.recordHash });
    for (const request of requests) {
      const read = p.prepareTokenPreservationSnapshotV2Read(f.c, ZeroAddress, request);
      assert.deepEqual(p.normalizeTokenPreservationSnapshotV2Read(read), read);
      assert.equal(host[f.c.scopeKind].parseTransaction({ data: read.call.data }).name, request.kind);
      assert.throws(() => p.normalizeTokenPreservationSnapshotV2Read({ ...read, call: { ...read.call, value: 1n } }));
    }
    assert.throws(() => p.prepareTokenPreservationSnapshotV2Call(f.c, A(70), { kind: "lockSnapshot", publication: f.publication }));
    assert.throws(() => p.prepareTokenPreservationSnapshotV2Read(f.c, A(70), { kind: "raiseGasParameter" }));
    if (type !== 0n) assert.throws(() => p.prepareTokenPreservationSnapshotV2Read(f.c, A(70), { kind: "snapshotChunkCount", recordHash: f.receipt.recordHash }));
  }
});
