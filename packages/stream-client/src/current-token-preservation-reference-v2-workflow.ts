import { Interface, id, keccak256, sha256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as ref from "./current-token-preservation-reference-v2.js";
import * as snap from "./current-token-preservation-snapshot-v2.js";
import * as output from "./current-token-preservation-output-v2.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";
import { inspectTokenPreservationSnapshotV2Current } from "./current-token-preservation-snapshot-v2-workflow.js";
import { prepareReferenceEnvironment } from "./current-reference-environment.js";
import { prepareReferenceInventory, referenceInventoryParts } from "./current-reference-inventory.js";
type Reader = io.Reader;
type ReceiptReader = io.ReceiptReader;
const { ZERO, ZERO_ADDRESS, coder, keys, address, hash, bytes, uint, number, same, stable, equal, freeze, fingerprint,
  codePin, pinList, header, unchanged, runtime, rpc } = io;
const MAX_PAYLOAD = 524288;
export type TokenPreservationReferenceV2CodePin = io.CodePin;
export type TokenPreservationReferenceV2Block = io.Block;
export type TokenPreservationReferenceV2ReceiptOptions = io.ReceiptOptions;
/** Roster completeness is reviewed deployment metadata, not inferred from bytecode hashes. */
export interface TokenPreservationReferenceV2Deployment {
 readonly chainId: bigint;
 readonly scopeKind: "collection" | "scoped";
 readonly core: io.CodePin;
 readonly metadata: io.CodePin;
 readonly reference: io.CodePin;
 readonly linkedDependencies: {
  readonly preparation: readonly io.CodePin[];
  readonly source: readonly io.CodePin[];
  readonly history: readonly io.CodePin[];
 };
}
export interface TokenPreservationReferenceV2HistoryDeployment {
 readonly chainId: bigint;
 readonly scopeKind: "collection" | "scoped";
 readonly core: Address;
 readonly metadata: Address;
 readonly reference: io.CodePin;
 readonly linkedDependencies: readonly io.CodePin[];
}
function hostAbi(kind: "collection" | "scoped") { return ref.tokenPreservationReferenceV2Interface(kind); }
const storeAbi = new Interface([
  "function chunk(bytes32) view returns (address pointer, uint32 length)",
  "function readChunk(bytes32 hash) view returns (bytes payload)"
]);
const schemaAbi = new Interface([
 "function documentFacts(bytes32 id) view returns ((bool exists, uint8 kind, uint8 status, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, uint32 totalBytes, uint256 chunkCount, bytes32 declarationHash) facts)",
 "function documentChunkHashAt(bytes32 id, uint256 index) view returns (bytes32)"
]);
const metadataAbi = new Interface([
  "function familyWriter(uint256 collectionId, bytes32 family, uint8 authClass, address account) view returns (bool, uint64)"
]);
const coreAbi = new Interface([
  "function tokenCollectionIdentity(uint256 tokenId) view returns (bool mappingExists, uint256 collectionId, uint256 collectionSerial, bool burned)",
  "function tokenLifecycle(uint256 tokenId) view returns (uint8 lifecycle)",
  "function coordinatorAtMint(uint256 tokenId) view returns (address)",
  "function tokenData(uint256 tokenId) view returns (bytes)"
]);
const coverageAbi = new Interface([
  "function core() view returns (address)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  "function requireCoverage(bytes32 hash, bytes32 artistId, bytes32 objectHash) view returns ((bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) saved)",
  "function coverage(bytes32 hash) view returns ((bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash))",
  "function objectIdentity(bytes32 hash) view returns ((bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 formatId, bytes32 formatCatalogId, bytes32 formatCatalogHash))",
  "function currentReceiptPair(bytes32 first, bytes32 second, bytes32 artistId, bytes32 objectHash) view returns ((bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) current)"
]);
const sampleAbi = new Interface([
  "function selectionAt(bytes32 id, uint256 index) view returns ((uint256 tokenId, bytes32 configRecordHash, bytes32 configHash, bytes32 sourceSnapshotHash, bytes32 rawSourceHash, (address registry, bytes32 registryCodeHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 schemaHash, bytes32 readSetHash, bytes32 registrationHash) selection, address[6] sources, bytes32[6] sourceCodeHashes))"
]);
const membershipAbi = new Interface([
  "function scopeTokenAt((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint256 index) view returns (uint256)"
]);
const policyAbi = new Interface([
  "function tokenEntropyReadiness(uint256 tokenId) view returns ((address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) t)"
]);
const rendererAbi = new Interface([
  "function requireRetained(bytes32 key) view returns (address renderer, bytes32 runtimeHash)",
  "function registration(bytes32 key) view returns ((address renderer, (bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 rendererClass, bytes32 schemaHash, string schemaURI, string manifestURI, bytes32 manifestHash, uint32 maxJSONBytes, uint32 maxHTMLBytes, bool deprecated) manifest, bytes32 schemaDocument, bytes32 contextDocument, bytes32 manifestDocument, bytes32 analysisDocument, bytes32 goldenDocument))"
]);
const registryAbi = new Interface([
  "function requirePreservation(bytes32 versionKey, address producer, bytes32 profile) view returns ((address producer, bytes32 producerCodeHash, bytes32 profile, address core, address router, address liveRenderer, bytes32 liveRendererCodeHash, address attribution, bytes32 attributionCodeHash), (address registry, bytes32 registryCodeHash, bytes32 versionKey, bytes32 registrationHash, bytes32 readSetHash, bytes32 analysisHash, bytes32 goldenHash))"
]);

const producerAbi = new Interface([
  "function preservationBinding() view returns (address, address, address, bytes32, address, bytes32)",
  "function preservationProfile() pure returns (bytes32)",
  "function preservationTokenJSON(uint256 token) view returns (string)",
  "function preservationTokenHTML(uint256 token) view returns (string)"
]);

const routerAbi = new Interface([
  "function supportsInterface(bytes4 id) view returns (bool)",
  "function scopedContentRootHead((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)) view returns (bytes32)",
  "function scopedContentRootRecord(bytes32) view returns ((((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 expectedPredecessor, bytes32 snapshotRecordHash, uint64 snapshotRevision, string manifestURI) publication, address snapshotHost, bytes32 snapshotCodeHash, bytes32 snapshotManifestHash, bytes32 snapshotSourceHash, bytes32 contentRoot, uint64 leafCount, bytes32 outputManifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt))",
  "function scopedPreservationPolicyContentRootBinding(bytes32 recordHash) view returns ((bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, bytes32 snapshotSchemaHash, bytes32 snapshotProfileHash, bytes32 snapshotCanonicalizationHash, address metadataRouter, bytes32 preservationOutputProfile))",
  "function collectionContentRootHead(uint256 collectionId) view returns (bytes32)"
]);
const preparationEventAbi = new Interface([
  "event ReferenceEnvironmentPrepared(uint16 schemaVersion, bytes32 indexed environmentId, bytes32 contentHash, uint32 byteLength)",
  "event ReferenceInventoryPartPrepared(uint16 schemaVersion, bytes32 indexed partId, bool relative, uint16 rowCount, bytes32 contentHash, uint32 byteLength)",
  "event ReferenceInventoryAssembled(uint16 schemaVersion, bytes32 indexed inventoryId, bool relative, uint256 rowCount, bytes32 contentHash, uint32 byteLength)",
]);

function publishedName(kind: "collection" | "scoped") { return kind === "collection" ? "PolicyReferencePublished" : "ScopedPolicyReferencePublished"; }

function deployment(input: TokenPreservationReferenceV2Deployment): TokenPreservationReferenceV2Deployment {
  keys(input, ["chainId", "scopeKind", "core", "metadata", "reference", "linkedDependencies"]);
  keys(input.linkedDependencies, ["preparation", "source", "history"]);
  const value = {
    chainId: uint(input.chainId), scopeKind: input.scopeKind, core: codePin(input.core), metadata: codePin(input.metadata), reference: codePin(input.reference),
    linkedDependencies: { preparation: pinList(input.linkedDependencies.preparation), source: pinList(input.linkedDependencies.source),
      history: pinList(input.linkedDependencies.history) }
  };
  if (!["collection", "scoped"].includes(value.scopeKind) || value.chainId === 0n) throw Error("Zero deployment chain");
  return freeze(value);
}
function coordinates(d: TokenPreservationReferenceV2Deployment): ref.TokenPreservationReferenceV2Coordinates {
  return { chainId: d.chainId, scopeKind: d.scopeKind, core: d.core.address, metadata: d.metadata.address, reference: d.reference.address };
}
async function chain(p: Reader, id_: bigint, tag: number) {
  if ((await p.getNetwork()).chainId !== id_) throw Error("RPC chain differs");
  return header(p, tag);
}
async function read<T>(p: Reader, target: Address, iface: Interface, method: string, args: readonly unknown[], tag: number,
  cap?: bigint): Promise<T> {
  const values = await rpc(p, target, iface, method, args, tag, undefined, cap);
  if (values.length !== 1) throw Error("Expected one return field");
  return values[0] as T;
}
function gas(value: bigint): bigint {
  if (uint(value) === 0n || value > 100_000_000n) throw Error("Gas exceeds client bound");
  return value;
}
async function context(p: Reader, d: TokenPreservationReferenceV2Deployment, tag: number, full: boolean) {
  await runtime(p, d.reference, tag);
  for (const pin of d.linkedDependencies[full ? "source" : "preparation"]) await runtime(p, pin, tag);
  const deps = ref.normalizeTokenPreservationReferenceV2Dependencies(await read(p, d.reference.address, hostAbi(d.scopeKind), "dependencies", [], tag));
  equal([deps.chainId, deps.targets[0], deps.codeHashes[0], deps.targets[1], deps.codeHashes[1]],
    [d.chainId, d.core.address, d.core.codeHash, d.metadata.address, d.metadata.codeHash], "Reference constructor bindings differ");
  equal(await read(p, d.reference.address, hostAbi(d.scopeKind), "deploymentChainId", [], tag), d.chainId);
  equal(await read(p, d.reference.address, hostAbi(d.scopeKind), d.scopeKind === "collection" ? "preservationPolicyReferenceProfile" : "scopedPreservationPolicyReferenceProfile", [], tag), id(d.scopeKind === "collection" ? "6529STREAM_PRESERVATION_POLICY_REFERENCE_V2" : "6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V2"));
  for (const [method, expected] of [["core", deps.targets[0]], ["metadataHost", deps.targets[1]], ["metadataRouter", deps.targets[4]],
    ["snapshots", deps.targets[5]], ["archiveCoverage", deps.targets[6]]] as const) {
    equal(await read(p, d.reference.address, hostAbi(d.scopeKind), method, [], tag), expected, "Reference immutable binding differs");
  }
  const indexes = full ? [0, 1, 2, 3, 4, 5, 6] : [3];
  for (const i of indexes) await runtime(p, { address: deps.targets[i]!, codeHash: deps.codeHashes[i]! }, tag);
  if (full) {
    if (deps.readGas < 50000n || deps.sourceGas < deps.readGas || deps.snapshotGas < deps.sourceGas || deps.archiveGas < deps.readGas) {
      throw Error("Original reference gas hierarchy differs");
    }
    for (const value of [deps.readGas, deps.sourceGas, deps.snapshotGas, deps.archiveGas]) gas(value);
  }
  return deps;
}
export interface TokenPreservationReferenceV2ChunkObservation {
  readonly hash: Hex;
  readonly pointer: Address;
  readonly byteLength: bigint;
}
async function retainedChunks(p: Reader, store: Address, payload: Hex, tag: number): Promise<readonly TokenPreservationReferenceV2ChunkObservation[]> {
  const raw = bytes(payload, 524288);
  if (raw === "0x") throw Error("Empty retained payload");
  const result: TokenPreservationReferenceV2ChunkObservation[] = [];
  for (let i = 2; i < raw.length; i += 16384) {
    const part = ("0x" + raw.slice(i, i + 16384)) as Hex;
    const hash_ = keccak256(part) as Hex;
    const value = await rpc(p, store, storeAbi, "chunk", [hash_], tag);
    const pointer = address(value[0]);
    const size = BigInt((part.length - 2) / 2);
    equal(value[1], size, "Preuploaded chunk size differs");
    equal(bytes(await p.getCode(pointer, tag), 8193), "0x00" + part.slice(2), "Preuploaded STOP carrier differs");
    result.push({ hash: hash_, pointer, byteLength: size });
  }
  return result;
}
async function preparedBytes(p: Reader, d: TokenPreservationReferenceV2Deployment | TokenPreservationReferenceV2HistoryDeployment, identity: Hex, tag: number): Promise<Hex | null> {
  try {
    return bytes(await read(p, d.reference.address, hostAbi(d.scopeKind), "preparedFileInventory", [identity], tag), 524288);
  } catch (error) {
    const e = error as { code?: string; data?: unknown };
    // Original missing and damaged private Manifest states share this error.
    // This records unavailable prior evidence, never proves private absence.
    if (e.code === "CALL_EXCEPTION" && e.data === id("InvalidSnapshotManifest()").slice(0, 10)) return null;
    throw error;
  }
}
interface PreparationEvidence {
  readonly kind: "preparation";
  readonly retainedBefore: boolean;
  readonly prerequisites: readonly { readonly identity: Hex; readonly canonical: Hex }[];
  readonly chunks: readonly TokenPreservationReferenceV2ChunkObservation[];
}
async function preparation(p: Reader, d: TokenPreservationReferenceV2Deployment, deps: ref.TokenPreservationReferenceV2Dependencies,
  plan: ref.TokenPreservationReferenceV2Call, tag: number): Promise<PreparationEvidence> {
  const saved = plan.preparation;
  if (!saved) throw Error("Expected original preparation call");
  const original = await preparedBytes(p, d, saved.id, tag);
  if (original !== null) {
    equal(original, saved.canonical, "Retained preparation bytes differ");
    return { kind: "preparation", retainedBefore: true, prerequisites: [], chunks: [] };
  }
  const q = plan.request;
  const prerequisites: { identity: Hex; canonical: Hex }[] = [];
  if (q.kind === "prepareEnvironment") {
    const environment = prepareReferenceEnvironment(d.chainId, d.reference.address, q.environment);
    for (const item of [environment.packageInventory, environment.platformInventory]) {
      prerequisites.push({ identity: item.inventoryId, canonical: item.canonical });
    }
  } else if (q.kind === "prepareFileInventoryFromParts") {
    for (const part of referenceInventoryParts(prepareReferenceInventory(d.chainId, d.reference.address, q.relative, q.rows))) {
      prerequisites.push({ identity: part.partId, canonical: part.canonical });
    }
  }
  for (const item of prerequisites) equal(await preparedBytes(p, d, item.identity, tag), item.canonical,
    "Original retained preparation prerequisite unavailable");
  return { kind: "preparation", retainedBefore: false, prerequisites,
    chunks: await retainedChunks(p, deps.targets[3], saved.canonical, tag) };
}
async function definitions(provider: Reader, d: TokenPreservationReferenceV2Deployment, deps: ref.TokenPreservationReferenceV2Dependencies, tag: number) {
  for (const def of ref.tokenPreservationReferenceV2Definitions(d.scopeKind)) {
    const facts = await read<{ exists: boolean; status: bigint; kind: bigint; contentHash: Hex; canonicalizationId: Hex;
      supersedesId: Hex; totalBytes: bigint; declarationHash: Hex; chunkCount: bigint }>(provider, deps.targets[2], schemaAbi, "documentFacts", [def.id], tag, deps.readGas);
    equal([facts.exists, facts.status, facts.kind, facts.contentHash, facts.canonicalizationId, facts.supersedesId, facts.totalBytes],
      [true, 0n, def.kind, def.hash, id("RAW_BYTES"), ZERO, def.byteLength], "Required first-version RAW definition differs");
    hash(facts.declarationHash);
    if (facts.chunkCount === 0n || facts.chunkCount > 64n) throw Error("Definition chunk count differs");
    let payload = "0x";
    for (let i = 0n; i < facts.chunkCount; i++) {
      const key = hash(await read(provider, deps.targets[2], schemaAbi, "documentChunkHashAt", [def.id, i], tag, deps.readGas));
      const chunk = bytes(await read(provider, deps.targets[3], storeAbi, "readChunk", [key], tag, deps.readGas), 8192);
      if (chunk.length === 2 || (i + 1n < facts.chunkCount && chunk.length !== 16386)) throw Error("Definition chunk length differs");
      equal(keccak256(chunk), key, "Definition chunk hash differs"); payload += chunk.slice(2); bytes(payload, MAX_PAYLOAD);
    }
    equal([BigInt((payload.length - 2) / 2), keccak256(payload)], [def.byteLength, def.hash], "Definition full bytes differ");
  }
}
const currentPairCapability = (() => {
  const fragment = coverageAbi.getFunction("currentReceiptPair")!;
  // Original IStreamExternalArtifactCurrentPair declares exactly this own method.
  return fragment.selector;
})();
interface CoverageObservation {
  readonly saved: ref.TokenPreservationReferenceV2Coverage;
  readonly currentPair: Readonly<Record<string, unknown>> | null;
}
async function coverage(p: Reader, deps: ref.TokenPreservationReferenceV2Dependencies, coverageHash: Hex, artistId: Hex,
  objectHash: Hex, format: "zip" | "png", d: TokenPreservationReferenceV2Deployment, tag: number, current: boolean): Promise<CoverageObservation> {
  const host = deps.targets[6];
  const saved = ref.normalizeTokenPreservationReferenceV2Coverage(await read(p, host, coverageAbi, current ? "coverage" : "requireCoverage",
    current ? [coverageHash] : [coverageHash, artistId, objectHash], tag, deps.archiveGas));
  equal([saved.coverageHash, saved.artistId, saved.objectHash], [coverageHash, artistId, objectHash], "Original coverage identity differs");
  hash(coverageHash);
  hash(objectHash);
  hash(saved.firstReceiptHash);
  hash(saved.secondReceiptHash);
  let pair: Readonly<Record<string, unknown>> | null = null;
  if (current) {
    pair = await read(p, host, coverageAbi, "currentReceiptPair", [saved.firstReceiptHash, saved.secondReceiptHash, artistId, objectHash], tag, deps.archiveGas);
    for (const field of ["objectHash", "artistId", "contentHash", "sha256Digest", "arweaveDataRoot", "byteSize", "firstFamilyRecordHash",
      "secondFamilyRecordHash", "firstReceiptHash", "secondReceiptHash", "checkpointHash", "profileHash"] as const) {
      equal(pair![field], saved[field], "Original receipt pair identity differs");
    }
    hash(pair!.firstFixityHash);
    hash(pair!.secondFixityHash);
  }
  const object = await read<Record<string, unknown>>(p, host, coverageAbi, "objectIdentity", [objectHash], tag, deps.archiveGas);
  for (const field of ["artistId", "contentHash", "sha256Digest", "arweaveDataRoot", "byteSize"] as const) equal(object[field], saved[field]);
  const document = ref.tokenPreservationReferenceV2Definitions(d.scopeKind).find(item => item.id === id(format === "zip" ? "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1" : "STREAM_REFERENCE_PNG_OBJECT_V1"));
  if (!document) throw Error("Original capture schema unavailable");
  const catalog = ref.tokenPreservationReferenceV2Definitions(d.scopeKind).find(item => item.kind === 2n && item.id !== ref.tokenPreservationReferenceV2Definitions(d.scopeKind)[1]!.id)!;
  equal([object.canonicalizationId, object.schemaId, object.formatId, object.formatCatalogId, object.formatCatalogHash],
    [id("RAW_BYTES"), document.id, id(format === "zip" ? "IANA:application/zip" : "IANA:image/png"), catalog.id, catalog.hash], "Original ZIP/PNG object interpretation differs");
  return { saved, currentPair: pair };
}

async function rawRender(provider: Reader, target: Address, method: string, token: bigint, tag: number, cap: bigint, maximum: number): Promise<Hex> {
  const raw = bytes(await provider.call({ to: target, data: producerAbi.encodeFunctionData(method, [token]), blockTag: tag, gasLimit: cap }), maximum + 64);
  const values = coder.decode(["bytes"], raw);
  equal(coder.encode(["bytes"], values), raw, "Noncanonical raw producer bytes");
  return bytes(values[0], maximum);
}
async function producerBinding(provider: Reader, deps: ref.TokenPreservationReferenceV2Dependencies,
  row: output.TokenPreservationOutputV2TokenSelection, value: output.TokenPreservationOutputV2Output, tag: number) {
  const b = value.preservation;
  output.validateTokenPreservationOutputV2Binding(b);
  equal([b.core, b.metadataRouter, b.liveRenderer, b.liveRendererCodeHash],
    [deps.targets[0], deps.targets[4], row.selection.renderer, row.selection.rendererCodeHash], "Retained producer binding differs");
  await io.runtimes(provider, [{ address: b.producer, codeHash: b.producerCodeHash },
    { address: b.attribution, codeHash: b.attributionCodeHash }], tag);
  equal(await read(provider, b.producer, producerAbi, "preservationProfile", [], tag, deps.readGas), b.profile);
  equal(await rpc(provider, b.producer, producerAbi, "preservationBinding", [], tag, undefined, deps.readGas),
    [b.core, b.metadataRouter, b.liveRenderer, b.liveRendererCodeHash, b.attribution, b.attributionCodeHash], "Actual producer binding differs");
  const [binding, admission] = await rpc(provider, row.selection.registry, registryAbi, "requirePreservation",
    [row.selection.versionKey, b.producer, b.profile], tag, undefined, deps.readGas);
  const { router, ...fields } = binding as output.TokenPreservationOutputV2RegistryBinding;
  equal({ ...fields, metadataRouter: router }, b, "Registry full binding differs");
  equal(admission, value.preservationAdmission, "Registry full admission differs");
  output.validateTokenPreservationOutputV2Admission(b, value.preservationAdmission, row);
}
async function snapshotSource(provider: Reader, d: TokenPreservationReferenceV2Deployment, deps: ref.TokenPreservationReferenceV2Dependencies,
  publication: ref.TokenPreservationReferenceV2Publication, tag: number) {
  const snapshot = { address: deps.targets[5], codeHash: deps.codeHashes[5] };
  const current = await inspectTokenPreservationSnapshotV2Current(provider, { chainId: d.chainId, scopeKind: d.scopeKind, snapshot,
    linkedDependencies: d.linkedDependencies.source, historyLinkedDependencies: d.linkedDependencies.source }, publication.scope, { blockTag: tag });
  if (!current.exists) throw Error("No current snapshot");
  const retained = current.current;
  equal([retained.receipt.recordHash, retained.receipt.revision], [publication.observation.snapshotRecordHash, publication.observation.snapshotRevision], "Current snapshot differs");
  const dependencies = snap.normalizeTokenPreservationSnapshotV2Dependencies(await read(provider, snapshot.address,
    snap.tokenPreservationSnapshotV2Interface(d.scopeKind), "dependencies", [], tag, deps.readGas));
  equal([dependencies.chainId, dependencies.targets.slice(0, 5), dependencies.codeHashes.slice(0, 5)],
    [deps.chainId, deps.targets.slice(0, 5), deps.codeHashes.slice(0, 5)], "Snapshot constructor graph differs");
  equal(await read(provider, deps.targets[6], coverageAbi, "core", [], tag, deps.readGas), deps.targets[0]);
  equal(await read(provider, deps.targets[6], coverageAbi, "supportsInterface", [currentPairCapability], tag, deps.readGas), true);
  return { ...retained, source: current.source, dependencies };
}
async function sourceFacts(provider: Reader, d: TokenPreservationReferenceV2Deployment, deps: ref.TokenPreservationReferenceV2Dependencies,
  publication: ref.TokenPreservationReferenceV2Publication, tag: number, timestamp: bigint, current: boolean) {
  await definitions(provider, d, deps, tag);
  const snapshot = await snapshotSource(provider, d, deps, publication, tag);
  const source = snapshot.source;
  let rootKey: Hex; let root: unknown; let binding: unknown;
  if (d.scopeKind === "collection") {
    const s = source as snap.TokenPreservationSnapshotV2CollectionSource;
    rootKey = hash((snapshot.publication as snap.TokenPreservationSnapshotV2CollectionPublication).contentRootRecord);
    equal(await read(provider, deps.targets[4], routerAbi, "collectionContentRootHead", [publication.scope.collectionId], tag, deps.readGas), rootKey, "Collection root head differs");
    root = s.root; binding = s.rootBinding;
  } else {
    rootKey = hash(await read(provider, deps.targets[4], routerAbi, "scopedContentRootHead", [publication.scope], tag, deps.readGas));
    root = await read(provider, deps.targets[4], routerAbi, "scopedContentRootRecord", [rootKey], tag, deps.sourceGas);
    binding = await read(provider, deps.targets[4], routerAbi, "scopedPreservationPolicyContentRootBinding", [rootKey], tag, deps.sourceGas);
    equal(await read(provider, snapshot.dependencies.targets[8], output.tokenPreservationOutputV2Interface("output"), "manifestRecord",
      [snapshot.publication.outputManifestRecord], tag, deps.sourceGas), source.outputs, "Original output record differs");
    const published = root as { publishedAt: bigint };
    if (published.publishedAt === 0n || published.publishedAt > timestamp) throw Error("Invalid root publication time");
  }
  const count = source.membership.tokenCount;
  if (count === 0n || count > 0xffffffffffffffffn || publication.observation.captures.length !== (count === 1n ? 1 : 2)) throw Error("First/last capture count differs");
  const environment = publication.observation.environment;
  const environmentCoverage = await coverage(provider, deps, environment.coverageHash, source.artist.artistId, environment.objectHash, "zip", d, tag, current);
  const samples: ref.TokenPreservationReferenceV2Sample[] = [];
  const coverages: CoverageObservation[] = [environmentCoverage];
  for (let i = 0; i < publication.observation.captures.length; i++) {
    const value = await sample(provider, d, deps, snapshot.dependencies, publication.scope, source, publication.observation.captures[i]!,
      i === 0 ? 0n : count - 1n, environment.manifestHash, tag, timestamp, current);
    samples.push(value.result); coverages.push(value.coverage);
  }
  const facts = ref.normalizeTokenPreservationReferenceV2Source(d.scopeKind, { scopeSubject: snapshot.receipt.scopeSubject,
    snapshot: snapshot.receipt, snapshotSource: source, contentRootRecordHash: rootKey, contentRoot: root,
    contentRootBinding: binding, environmentCoverage: environmentCoverage.saved, samples } as ref.TokenPreservationReferenceV2Source);
  ref.validateTokenPreservationReferenceV2Source(coordinates(d), deps, publication, facts, snapshot.dependencies);
  const runtimePins: io.CodePin[] = snapshot.dependencies.targets.map((target, i) => ({ address: target, codeHash: snapshot.dependencies.codeHashes[i]! }));
  if (d.scopeKind === "scoped") { const s = source as snap.TokenPreservationSnapshotV2ScopedSource; runtimePins.push({ address: s.sourceFactory, codeHash: s.sourceFactoryCodeHash }); }
  for (const row of samples) runtimePins.push({ address: row.selection.selection.registry, codeHash: row.selection.selection.registryCodeHash },
    { address: row.preservation.producer, codeHash: row.preservation.producerCodeHash }, { address: row.preservation.liveRenderer, codeHash: row.preservation.liveRendererCodeHash },
    { address: row.preservation.attribution, codeHash: row.preservation.attributionCodeHash }, { address: row.entropy.coordinator, codeHash: row.entropy.coordinatorCodeHash });
  return { facts, coverages, runtimePins };
}

async function sample(p: Reader, d: TokenPreservationReferenceV2Deployment, deps: ref.TokenPreservationReferenceV2Dependencies, sourceDeps: snap.TokenPreservationSnapshotV2Dependencies,
  scope: ref.TokenPreservationReferenceV2Scope, source: snap.TokenPreservationSnapshotV2Source, capture: ref.TokenPreservationReferenceV2Capture,
  index: bigint, environmentHash: Hex, tag: number, timestamp: bigint, current: boolean) {
  const tokenId = uint(await read(p, sourceDeps.targets[5], membershipAbi, "scopeTokenAt", [scope, index], tag, deps.readGas));
  if (tokenId === 0n || tokenId !== capture.tokenId || index >= source.membership.tokenCount) throw Error("Authoritative first/last membership differs");
  const selection = output.normalizeTokenPreservationOutputV2TokenSelection(await read(p, sourceDeps.targets[6], sampleAbi, "selectionAt", [source.content.selectionId, index], tag, deps.readGas));
  const savedOutput = output.normalizeTokenPreservationOutputV2Output(await read(p, sourceDeps.targets[7], output.tokenPreservationOutputV2Interface("checkpoint"), "outputAt", [source.outputs.checkpointHash, index], tag, deps.readGas));
  equal([selection.tokenId, savedOutput.leaf.tokenId], [tokenId, tokenId]);
  equal(savedOutput.selectionRowHash, output.tokenPreservationOutputV2SelectionRowHash(deps.chainId, deps.targets[0], deps.targets[4], selection));
  const html = bytes(capture.animationHTML, 40960);
  if (html === "0x" || BigInt((html.length - 2) / 2) !== capture.htmlBytes || keccak256(html) !== capture.htmlHash
    || sha256(html) !== capture.sourceSha256 || capture.capturedAt === 0n || capture.capturedAt > timestamp
    || capture.repeatCaptureSha256[0] === ZERO || capture.repeatCaptureSha256[0] !== capture.repeatCaptureSha256[1]
    || capture.environmentManifestHash !== environmentHash) throw Error("Original capture bytes/time/hash differs");
  equal([capture.metadataJSONHash, capture.htmlHash, savedOutput.htmlHash], [savedOutput.leaf.metadataHash, savedOutput.leaf.animationHash, capture.htmlHash]);
  await runtime(p, { address: selection.selection.registry, codeHash: selection.selection.registryCodeHash }, tag);
  await runtime(p, { address: selection.selection.renderer, codeHash: selection.selection.rendererCodeHash }, tag);
  equal(await rpc(p, selection.selection.registry, rendererAbi, "requireRetained", [selection.selection.versionKey], tag, undefined, deps.readGas),
    [selection.selection.renderer, selection.selection.rendererCodeHash]);
  const registered = await read<{ renderer: Address; manifest: { rendererClass: Hex; rendererId: Hex; rendererVersion: Hex; contextVersion: Hex; schemaHash: Hex } }>(p,
    selection.selection.registry, rendererAbi, "registration", [selection.selection.versionKey], tag, deps.readGas);
  equal([registered.renderer, registered.manifest.rendererClass, registered.manifest.rendererId, registered.manifest.rendererVersion,
    registered.manifest.contextVersion, registered.manifest.schemaHash], [selection.selection.renderer, id("STATIC"), selection.selection.rendererId,
    selection.selection.rendererVersion, selection.selection.contextVersion, selection.selection.schemaHash], "Retained STATIC registration differs");
  const identity = await rpc(p, deps.targets[0], coreAbi, "tokenCollectionIdentity", [tokenId], tag, undefined, deps.readGas);
  if (identity[0] !== true || identity[1] !== scope.collectionId || identity[2] === 0n || identity[2] !== capture.collectionSerial) throw Error("Permanent Core token identity differs");
  equal(await read(p, deps.targets[0], coreAbi, "tokenLifecycle", [tokenId], tag, deps.readGas), identity[3] ? 3n : 2n);
  const coordinator = address(await read(p, deps.targets[0], coreAbi, "coordinatorAtMint", [tokenId], tag, deps.readGas));
  equal(coordinator, selection.sources[3]);
  await runtime(p, { address: coordinator, codeHash: selection.sourceCodeHashes[3] }, tag);
  const entropy = output.normalizeTokenPreservationOutputV2TokenReadiness(await read(p, sourceDeps.targets[10], policyAbi, "tokenEntropyReadiness", [tokenId], tag, deps.sourceGas));
  equal(entropy, savedOutput.entropy);
  equal([entropy.coordinator, entropy.coordinatorCodeHash], [coordinator, selection.sourceCodeHashes[3]]);
  if (entropy.terminal) {
    if (entropy.finalized || entropy.seed !== ZERO || entropy.renderRequirement !== 1n || savedOutput.terminalAdmissionHash === ZERO
      || !(entropy.status === 1n && entropy.mode === 0n || entropy.status === 2n && entropy.mode === 2n)) throw Error("Terminal entropy evidence differs");
  } else if (!entropy.finalized || entropy.status !== 5n || savedOutput.terminalAdmissionHash !== ZERO) throw Error("Finalized entropy evidence differs");
  const data = bytes(await read(p, deps.targets[0], coreAbi, "tokenData", [tokenId], tag, deps.sourceGas), 16384);
  equal(keccak256(data), savedOutput.leaf.tokenDataHash);
  await producerBinding(p, deps, selection, savedOutput, tag);
  const json = await rawRender(p, savedOutput.preservation.producer, "preservationTokenJSON", tokenId, tag, deps.sourceGas, 65536);
  const actualHtml = await rawRender(p, savedOutput.preservation.producer, "preservationTokenHTML", tokenId, tag, deps.sourceGas, 40960);
  if (BigInt((actualHtml.length - 2) / 2) !== capture.htmlBytes
    || keccak256(json) !== savedOutput.leaf.metadataHash || keccak256(actualHtml) !== capture.htmlHash) throw Error("Actual render bytes differ");
  // Exact JSON/data embedding and capped nested execution remain original preview/call predicates.
  const retainedCoverage = await coverage(p, deps, capture.coverageHash, source.artist.artistId, capture.objectHash, "png", d, tag, current);
  equal(retainedCoverage.saved.sha256Digest, capture.repeatCaptureSha256[0], "Repeat PNG digest differs");
  const result: ref.TokenPreservationReferenceV2Sample = { membershipIndex: index, selection, entropy, preservation: savedOutput.preservation, preservationAdmission: savedOutput.preservationAdmission,
    terminalAdmissionHash: savedOutput.terminalAdmissionHash, observation: { tokenId, collectionSerial: capture.collectionSerial,
      originalCoordinator: coordinator, seed: entropy.seed, tokenDataHash: savedOutput.leaf.tokenDataHash, tokenDataBytes: BigInt((data.length - 2) / 2),
      metadataJSONHash: savedOutput.leaf.metadataHash, htmlHash: capture.htmlHash, htmlBytes: capture.htmlBytes, captureCoverage: retainedCoverage.saved } };
  return { result, coverage: retainedCoverage };
}

async function environmentBytes(p: Reader, d: TokenPreservationReferenceV2Deployment, publication: ref.TokenPreservationReferenceV2Publication, tag: number) {
  const environment = prepareReferenceEnvironment(d.chainId, d.reference.address, publication.observation.environment);
  const retained = await preparedBytes(p, d, environment.environmentId, tag);
  if (retained !== null) equal(retained, environment.canonical, "Retained environment differs");
  else for (const item of [environment.packageInventory, environment.platformInventory]) {
    equal(await preparedBytes(p, d, item.inventoryId, tag), item.canonical, "Environment original file inventories unavailable");
  }
  return environment.canonical;
}
async function candidate(p: Reader, d: TokenPreservationReferenceV2Deployment, publication: ref.TokenPreservationReferenceV2Publication,
  timestamp: bigint, tag: number) {
  const q = publication.observation;
  if (q.effectiveAt > timestamp || timestamp > 0xffffffffffffffffn) throw Error("Original publication time invalid");
  const prior = ref.normalizeTokenPreservationReferenceV2Receipt(await read(p, d.reference.address, hostAbi(d.scopeKind), "currentReference", [publication.scope], tag));
  const count = uint(await read(p, d.reference.address, hostAbi(d.scopeKind), "referenceCount", [publication.scope], tag));
  if (prior.observation.recordHash === ZERO) {
    equal(ref.encodeTokenPreservationReferenceV2Receipt(prior), ("0x" + "00".repeat(672)), "Empty current receipt is nondefault");
    if (count !== 0n) throw Error("Missing nonempty reference head");
  } else {
    const original = await rpc(p, d.reference.address, hostAbi(d.scopeKind), "referenceRecord", [prior.observation.recordHash], tag);
    const previous = ref.normalizeTokenPreservationReferenceV2Publication(original[0] as ref.TokenPreservationReferenceV2Publication);
    equal(previous.scope, publication.scope, "Prior reference full scope differs");
    equal(original[1], prior);
    equal(prior.observation.revision, count);
    equal(prior.scopeSubject, snap.tokenPreservationSnapshotV2ScopeSubject(d.chainId, d.core.address, publication.scope));
  }
  equal([prior.observation.recordHash, count], [q.expectedHead, q.expectedRevision], "Reference lineage changed");
  const lock = await read<ref.TokenPreservationReferenceV2Lock>(p, d.reference.address, hostAbi(d.scopeKind), "referenceLock", [publication.scope], tag);
  if (lock.actionId !== ZERO) throw Error("Reference scope is locked");
  // The private reference-id map has no getter. Original preview/call checks reuse.
  return { prior, count, lock };
}
async function authority(p: Reader, deps: ref.TokenPreservationReferenceV2Dependencies, cid: bigint, caller: Address, tag: number) {
  for (const cls of [3n, 8n] as const) {
    const values = await rpc(p, deps.targets[1], metadataAbi, "familyWriter", [cls === 3n ? cid : 0n, id("6529STREAM_RECORD_FAMILY_CURATOR_V1"), cls, caller], tag, undefined, deps.readGas);
    if (values[0] === true && values[1] !== 0n) return { authorizationClass: cls, grantRevision: uint(values[1], 64) };
  }
  throw Error("Original CURATOR publication grant unavailable");
}
export interface TokenPreservationReferenceV2Preview {
  readonly deployment: TokenPreservationReferenceV2Deployment;
  readonly observed: TokenPreservationReferenceV2Block;
  readonly dependencies: ref.TokenPreservationReferenceV2Dependencies;
  readonly publication: ref.TokenPreservationReferenceV2Publication;
  readonly caller: Address;
  readonly receipt: ref.TokenPreservationReferenceV2Receipt;
  readonly source: ref.TokenPreservationReferenceV2Source;
  readonly sourceHash: Hex;
  readonly runtimePins: readonly io.CodePin[];
  readonly canonical: Hex;
  readonly environmentBytes: Hex;
  readonly prior: ref.TokenPreservationReferenceV2Receipt;
  readonly count: bigint;
  readonly lock: ref.TokenPreservationReferenceV2Lock;
  readonly storeAvailabilityChecked: false;
  readonly previewHash: Hex;
}
/** Zero expectedSourcesHash is permitted only for this actual original preview. */
export async function previewTokenPreservationReferenceV2(
  p: Reader,
  input: TokenPreservationReferenceV2Deployment,
  inputCaller: Address,
  supplied: ref.TokenPreservationReferenceV2Publication,
  options: { readonly blockTag: number }
): Promise<TokenPreservationReferenceV2Preview> {
  const d = deployment(input), caller = address(inputCaller);
  const publication = ref.validateTokenPreservationReferenceV2Publication(d.scopeKind, supplied, "preview");
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag), observed = await chain(p, d.chainId, tag);
  const deps = await context(p, d, tag, true);
  const lineage = await candidate(p, d, publication, observed.timestamp, tag);
  const writer = await authority(p, deps, publication.scope.collectionId, caller, tag);
  const source = await sourceFacts(p, d, deps, publication, tag, observed.timestamp, false);
  const sourceHash = ref.tokenPreservationReferenceV2SourceHash(coordinates(d), deps, source.facts);
  const receipt = ref.tokenPreservationReferenceV2PreviewReceipt(coordinates(d), publication, caller, writer, sourceHash);
  const environment = await environmentBytes(p, d, publication, tag);
  const canonical = ref.tokenPreservationReferenceV2ReferenceBytes(coordinates(d), deps, publication, receipt, source.facts, environment);
  const original = await rpc(p, d.reference.address, hostAbi(d.scopeKind), "previewReference", [publication, caller], tag, caller);
  equal(original, [sourceHash, canonical], "Original preview source/canonical differs");
  await unchanged(p, observed);
  const value = { deployment: d, observed, dependencies: deps, publication, caller, receipt, source: source.facts, sourceHash, runtimePins: source.runtimePins,
    canonical, environmentBytes: environment, ...lineage, storeAvailabilityChecked: false as const };
  return freeze({ ...value, previewHash: fingerprint(value) });
}
interface PublicationEvidence {
  readonly kind: "publication";
  readonly preview: TokenPreservationReferenceV2Preview;
  readonly payloadChunks: readonly TokenPreservationReferenceV2ChunkObservation[];
  readonly publicationChunks: readonly TokenPreservationReferenceV2ChunkObservation[];
}
export interface TokenPreservationReferenceV2WorkflowCapture {
  readonly deployment: TokenPreservationReferenceV2Deployment;
  readonly observed: TokenPreservationReferenceV2Block;
  readonly dependencies: ref.TokenPreservationReferenceV2Dependencies;
  readonly prepared: ref.TokenPreservationReferenceV2Call;
  readonly stage: PreparationEvidence | PublicationEvidence;
  readonly captureHash: Hex;
}
export async function captureTokenPreservationReferenceV2(
  p: Reader,
  input: TokenPreservationReferenceV2Deployment,
  inputCaller: Address,
  request: ref.TokenPreservationReferenceV2Request,
  options: { readonly blockTag: number }
): Promise<TokenPreservationReferenceV2WorkflowCapture> {
  const d = deployment(input), caller = address(inputCaller);
  const prepared = ref.prepareTokenPreservationReferenceV2Call(coordinates(d), caller, request);
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag), observed = await chain(p, d.chainId, tag);
  const deps = await context(p, d, tag, prepared.request.kind === "publishReference");
  let stage: PreparationEvidence | PublicationEvidence;
  if (prepared.request.kind === "publishReference") {
    const preview = await previewTokenPreservationReferenceV2(p, d, caller, prepared.request.publication, { blockTag: tag });
    equal(prepared.request.publication.observation.expectedSourcesHash, preview.sourceHash, "Expected source changed");
    stage = { kind: "publication", preview, payloadChunks: await retainedChunks(p, deps.targets[3], preview.canonical, tag),
      publicationChunks: await retainedChunks(p, deps.targets[3], ref.encodeTokenPreservationReferenceV2Publication(prepared.request.publication), tag) };
  } else stage = await preparation(p, d, deps, prepared, tag);
  await unchanged(p, observed);
  const value = { deployment: d, observed, dependencies: deps, prepared, stage };
  return freeze({ ...value, captureHash: fingerprint(value) });
}
function savedCapture(input: TokenPreservationReferenceV2WorkflowCapture) {
  const saved = structuredClone(input);
  const { captureHash, ...body } = saved;
  equal(fingerprint(body), hash(captureHash), "Saved capture bytes changed");
  const d = deployment(saved.deployment);
  equal(ref.normalizeTokenPreservationReferenceV2Call(saved.prepared), saved.prepared);
  equal(saved.prepared.coordinates, coordinates(d), "Captured call deployment differs");
  if ((saved.prepared.request.kind === "publishReference") !== (saved.stage.kind === "publication")) throw Error("Captured stage differs");
  if (saved.stage.kind === "publication" && saved.prepared.request.kind === "publishReference") {
    equal([saved.stage.preview.publication, saved.stage.preview.caller, saved.stage.preview.deployment, saved.stage.preview.observed],
      [saved.prepared.request.publication, saved.prepared.caller, saved.deployment, saved.observed], "Captured publication preview differs");
  }
  return freeze(saved);
}
function comparable(c: TokenPreservationReferenceV2WorkflowCapture) {
  const { observed: _observed, captureHash: _hash, stage, ...body } = c;
  if (stage.kind !== "publication") return { ...body, stage };
  const { observed: _block, previewHash: _previewHash, ...preview } = stage.preview;
  return { ...body, stage: { ...stage, preview } };
}
async function revalidate(p: Reader, saved: TokenPreservationReferenceV2WorkflowCapture, tag: number) {
  if (tag < saved.observed.blockNumber) throw Error("Observation predates capture");
  await unchanged(p, saved.observed);
  const original = await captureTokenPreservationReferenceV2(p, saved.deployment, saved.prepared.caller, saved.prepared.request, { blockTag: saved.observed.blockNumber });
  equal(original, saved, "Saved original capture reconstruction differs");
  const current = tag === saved.observed.blockNumber ? original
    : await captureTokenPreservationReferenceV2(p, saved.deployment, saved.prepared.caller, saved.prepared.request, { blockTag: tag });
  equal(comparable(current), comparable(saved), "Reviewed source or preparation state changed; recapture");
  return current;
}
function completed(c: TokenPreservationReferenceV2WorkflowCapture, timestamp: bigint): ref.TokenPreservationReferenceV2Receipt {
  if (c.stage.kind !== "publication") throw Error("Expected publication stage");
  const preview = c.stage.preview, publication = preview.publication;
  if (timestamp === 0n || timestamp > 0xffffffffffffffffn || timestamp < publication.observation.effectiveAt
    || publication.observation.captures.some(row => row.capturedAt > timestamp)) throw Error("Mined original timestamps invalid");
  const fields = { ...preview.receipt, observation: { ...preview.receipt.observation, recordedAt: timestamp,
    payloadHash: keccak256(preview.canonical) as Hex, payloadBytes: BigInt((preview.canonical.length - 2) / 2) } };
  const recordHash = ref.tokenPreservationReferenceV2RecordHash(c.prepared.coordinates, publication, fields);
  const recordChainHash = ref.tokenPreservationReferenceV2ChainHash(c.prepared.coordinates, publication.scope,
    preview.prior.observation.recordChainHash, fields.observation.revision, recordHash);
  return ref.normalizeTokenPreservationReferenceV2Receipt({ ...fields, observation: { ...fields.observation, recordHash, recordChainHash } });
}
export async function simulateTokenPreservationReferenceV2(
  p: Reader,
  input: TokenPreservationReferenceV2WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }
) {
  const saved = savedCapture(input);
  keys(options, ["blockTag", "gasLimit"]);
  const cap = gas(options.gasLimit), tag = number(options.blockTag);
  const current = await revalidate(p, saved, tag);
  const raw = bytes(await p.call({ ...current.prepared.call, from: current.prepared.caller, blockTag: tag, gasLimit: cap }), 32);
  const identity = current.stage.kind === "publication" ? completed(current, current.observed.timestamp).observation.recordHash : current.prepared.preparation!.id;
  equal(raw, coder.encode(["bytes32"], [identity]), "Original call return differs");
  await unchanged(p, current.observed);
  return freeze({ capture: current, identity, persisted: false as const, scope: "original-inner-call" as const });
}

async function historical(p: Reader, d: TokenPreservationReferenceV2HistoryDeployment, inputKey: Hex, tag: number) {
  const key = hash(inputKey);
  await runtime(p, d.reference, tag);
  for (const pin of d.linkedDependencies) await runtime(p, pin, tag);
  const deps = ref.normalizeTokenPreservationReferenceV2Dependencies(await read(p, d.reference.address, hostAbi(d.scopeKind), "dependencies", [], tag));
  equal([deps.chainId, deps.targets[0], deps.targets[1]], [d.chainId, d.core, d.metadata]);
  const coords = { chainId: d.chainId, scopeKind: d.scopeKind, core: d.core, metadata: d.metadata, reference: d.reference.address };
  const raw = await rpc(p, d.reference.address, hostAbi(d.scopeKind), "referenceRecord", [key], tag);
  const publication = ref.normalizeTokenPreservationReferenceV2Publication(raw[0] as ref.TokenPreservationReferenceV2Publication);
  const receipt = ref.normalizeTokenPreservationReferenceV2Receipt(raw[1] as ref.TokenPreservationReferenceV2Receipt);
  const r = receipt.observation, q = publication.observation;
  ref.validateTokenPreservationReferenceV2Publication(d.scopeKind, publication, "publish");
  equal([r.recordHash, r.collectionId, r.referenceId, r.predecessor, r.revision, r.snapshotRecordHash, r.snapshotRevision,
    r.effectiveAt, r.reasonHash, receipt.scopeSubject], [key, q.collectionId, q.referenceId, q.expectedHead, q.expectedRevision + 1n,
    q.snapshotRecordHash, q.snapshotRevision, q.effectiveAt, q.reasonHash, snap.tokenPreservationSnapshotV2ScopeSubject(d.chainId, d.core, publication.scope)],
    "Retained publication lineage differs");
  if (r.recordedAt === 0n || r.recordedAt < q.effectiveAt || r.recorder === ZERO_ADDRESS || ![3n, 8n].includes(r.authorizationClass)
    || r.grantRevision === 0n || r.payloadHash === ZERO || r.sourcesHash === ZERO) throw Error("Incomplete retained receipt");
  equal([r.schemaHash, r.profileHash, r.canonicalizationHash], ref.tokenPreservationReferenceV2Definitions(d.scopeKind).slice(0, 3).map(item => item.hash));
  const canonical = bytes(await read(p, d.reference.address, hostAbi(d.scopeKind), "referencePayload", [key], tag), 524288);
  const decoded = ref.decodeTokenPreservationReferenceV2ReferenceBytes(d.scopeKind, canonical);
  equal([decoded.chainId, decoded.reference], [d.chainId, d.reference.address]);
  const source = ref.normalizeTokenPreservationReferenceV2Source(d.scopeKind, await read(p, d.reference.address, hostAbi(d.scopeKind), "referenceSource", [key], tag));
  equal(source, decoded.source, "Retained source getter differs from payload");
  equal(ref.tokenPreservationReferenceV2ReferenceBytes(coords, deps, publication, receipt, source, decoded.environmentBytes), canonical, "Canonical retained payload differs");
  equal([keccak256(canonical), BigInt((canonical.length - 2) / 2), ref.tokenPreservationReferenceV2SourceHash(coords, deps, source)],
    [r.payloadHash, r.payloadBytes, r.sourcesHash]);
  equal(q.expectedSourcesHash, r.sourcesHash);
  equal(ref.tokenPreservationReferenceV2RecordHash(coords, publication, receipt), key, "Original record hash differs");
  let previousChain = ZERO;
  if (r.predecessor !== ZERO) {
    const before = await rpc(p, d.reference.address, hostAbi(d.scopeKind), "referenceRecord", [r.predecessor], tag);
    const previousPublication = ref.normalizeTokenPreservationReferenceV2Publication(before[0] as ref.TokenPreservationReferenceV2Publication);
    const previousReceipt = ref.normalizeTokenPreservationReferenceV2Receipt(before[1] as ref.TokenPreservationReferenceV2Receipt);
    equal(previousPublication.scope, publication.scope, "Historical predecessor full scope differs");
    equal([previousReceipt.observation.recordHash, previousReceipt.observation.revision], [r.predecessor, q.expectedRevision]);
    equal(ref.tokenPreservationReferenceV2RecordHash(coords, previousPublication, previousReceipt), r.predecessor);
    previousChain = hash(previousReceipt.observation.recordChainHash);
  } else if (q.expectedRevision !== 0n) throw Error("Missing historical predecessor");
  equal(ref.tokenPreservationReferenceV2ChainHash(coords, publication.scope, previousChain, r.revision, key), r.recordChainHash);
  ref.authenticateTokenPreservationReferenceV2History(coords, deps, publication, receipt, canonical, previousChain);
  return { publication, receipt, source, canonical, environmentBytes: decoded.environmentBytes, dependencies: deps };
}
export async function inspectTokenPreservationReferenceV2History(
  p: Reader,
  input: TokenPreservationReferenceV2HistoryDeployment,
  inputKey: Hex,
  options: { readonly blockTag: number }
) {
  keys(input, ["chainId", "scopeKind", "core", "metadata", "reference", "linkedDependencies"]);
  keys(options, ["blockTag"]);
  const d = { chainId: uint(input.chainId), scopeKind: input.scopeKind, core: address(input.core), metadata: address(input.metadata), reference: codePin(input.reference),
    linkedDependencies: pinList(input.linkedDependencies) };
  const key = hash(inputKey), tag = number(options.blockTag), observed = await chain(p, d.chainId, tag);
  const result = await historical(p, d, key, tag);
  if (result.receipt.observation.recordedAt > observed.timestamp) throw Error("Future retained receipt");
  await unchanged(p, observed);
  return freeze({ deployment: d, observed, ...result, currentnessChecked: false as const, finalityEstablished: false as const });
}
export async function inspectTokenPreservationReferenceV2Current(
  p: Reader,
  input: TokenPreservationReferenceV2Deployment,
  suppliedScope: ref.TokenPreservationReferenceV2Scope,
  options: { readonly blockTag: number }
) {
  const d = deployment(input), scope = snap.validateTokenPreservationSnapshotV2Scope(d.scopeKind, suppliedScope);
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag), observed = await chain(p, d.chainId, tag);
  const deps = await context(p, d, tag, true);
  const current = ref.normalizeTokenPreservationReferenceV2Receipt(await read(p, d.reference.address, hostAbi(d.scopeKind), "currentReference", [scope], tag));
  if (current.observation.recordHash === ZERO) {
    equal(ref.encodeTokenPreservationReferenceV2Receipt(current), "0x" + "00".repeat(672), "Empty current receipt is nondefault");
    throw Error("No current reference exists for the requested scope");
  }
  const stored = await historical(p, { chainId: d.chainId, scopeKind: d.scopeKind, core: d.core.address, metadata: d.metadata.address, reference: d.reference,
    linkedDependencies: d.linkedDependencies.history }, current.observation.recordHash, tag);
  equal(stored.publication.scope, scope, "Current full scope differs");
  equal(stored.receipt, current);
  const actual = await sourceFacts(p, d, deps, stored.publication, tag, observed.timestamp, true);
  equal(actual.facts, stored.source, "Current source differs from retained source");
  equal(ref.tokenPreservationReferenceV2SourceHash(coordinates(d), deps, actual.facts), current.observation.sourcesHash);
  equal(await read(p, d.reference.address, hostAbi(d.scopeKind), "requireCurrent", [scope, current.observation.recordHash, current.observation.revision], tag), current,
    "Original current reference differs");
  await unchanged(p, observed);
  return freeze({ deployment: d, observed, ...stored, coverage: actual.coverages,
    currentnessChecked: true as const, finalityEstablished: false as const });
}

const preparationEvents = ["ReferenceEnvironmentPrepared", "ReferenceInventoryPartPrepared", "ReferenceInventoryAssembled"] as const;
async function preparationReceipt(p: ReceiptReader, saved: TokenPreservationReferenceV2WorkflowCapture,
  transport_: Awaited<ReturnType<typeof io.transport>>) {
  if (saved.stage.kind !== "preparation" || !saved.prepared.preparation) throw Error("Expected preparation capture");
  const d = saved.deployment, tag = transport_.observed.blockNumber, q = saved.prepared.request;
  const expected = saved.prepared.preparation;
  const deps = await context(p, d, tag, false);
  equal([deps.targets, deps.codeHashes], [saved.dependencies.targets, saved.dependencies.codeHashes]);
  equal(await preparedBytes(p, d, expected.id, tag), expected.canonical, "Mined preparation bytes differ");
  let expectedName: typeof preparationEvents[number] | null = null;
  let args: readonly unknown[] = [];
  if (!saved.stage.retainedBefore) {
    if (q.kind === "prepareEnvironment") {
      expectedName = "ReferenceEnvironmentPrepared";
      args = [1n, expected.id, expected.contentHash, expected.byteLength];
    } else if (q.kind === "prepareFileInventoryPart") {
      expectedName = "ReferenceInventoryPartPrepared";
      args = [1n, expected.id, q.relative, BigInt(q.rows.length), expected.contentHash, expected.byteLength];
    } else if (q.kind === "prepareFileInventoryFromParts") {
      expectedName = "ReferenceInventoryAssembled";
      args = [1n, expected.id, q.relative, BigInt(q.rows.length), expected.contentHash, expected.byteLength];
    }
    equal(await retainedChunks(p, deps.targets[3], expected.canonical, tag), saved.stage.chunks, "Retained preparation carriers changed");
  }
  let last = -1;
  for (const name of preparationEvents) {
    if (name === expectedName) last = io.one(transport_.logs, d.reference.address, preparationEventAbi, name, args).index;
    else if (io.events(transport_.logs, d.reference.address, preparationEventAbi, name).length) throw Error("Unexpected preparation event");
  }
  if (io.events(transport_.logs, d.reference.address, hostAbi(d.scopeKind), publishedName(d.scopeKind)).length) throw Error("Preparation cannot publish a reference");
  if (transport_.logs.filter(log => same(log.address, d.reference.address)).length !== (expectedName ? 1 : 0)
    || transport_.logs.some(log => same(log.address, deps.targets[3]))) throw Error("Unexpected preparation or Store event");
  if (transport_.safeIndex >= 0 && transport_.safeIndex <= last) throw Error("Safe success precedes preparation");
  return { kind: "preparation" as const, identity: expected.id, canonical: expected.canonical,
    priorRetained: saved.stage.retainedBefore, receiptHadPreparationEvent: expectedName !== null };
}
async function publicationReceipt(p: ReceiptReader, saved: TokenPreservationReferenceV2WorkflowCapture,
  transport_: Awaited<ReturnType<typeof io.transport>>) {
  if (saved.stage.kind !== "publication" || saved.prepared.request.kind !== "publishReference") throw Error("Expected reference publication");
  const d = saved.deployment, tag = transport_.observed.blockNumber;
  await runtime(p, d.reference, tag);
  for (const pin of [...d.linkedDependencies.source, ...d.linkedDependencies.history]) await runtime(p, pin, tag);
  await io.runtimes(p, saved.stage.preview.runtimePins, tag);
  for (let i = 0; i < 7; i++) await runtime(p, { address: saved.dependencies.targets[i]!, codeHash: saved.dependencies.codeHashes[i]! }, tag);
  const expected = completed(saved, transport_.observed.timestamp);
  const q = saved.prepared.request.publication;
  const published = io.one(transport_.logs, d.reference.address, hostAbi(d.scopeKind), publishedName(d.scopeKind),
    [2n, expected.scopeSubject, q.observation.referenceId, expected.observation.recordHash, expected, q.observation.manifestURI]);
  for (const name of preparationEvents) if (io.events(transport_.logs, d.reference.address, preparationEventAbi, name).length) throw Error("Publication cannot prepare a new environment");
  if (transport_.logs.filter(log => same(log.address, d.reference.address)).length !== 1
    || transport_.logs.some(log => same(log.address, saved.dependencies.targets[3]))) throw Error("Unexpected reference or Store event");
  if (transport_.safeIndex >= 0 && transport_.safeIndex <= published.index) throw Error("Safe success precedes publication");
  const retained = await historical(p, { chainId: d.chainId, scopeKind: d.scopeKind, core: d.core.address, metadata: d.metadata.address,
    reference: d.reference, linkedDependencies: d.linkedDependencies.history }, expected.observation.recordHash, tag);
  equal(retained.publication, q);
  equal(retained.receipt, expected);
  equal(retained.canonical, saved.stage.preview.canonical);
  equal(retained.source, saved.stage.preview.source);
  equal(await read(p, d.reference.address, hostAbi(d.scopeKind), "currentReference", [q.scope], tag), expected, "End-block reference head differs");
  equal(await read(p, d.reference.address, hostAbi(d.scopeKind), "referenceCount", [q.scope], tag), expected.observation.revision);
  equal(await read(p, d.reference.address, hostAbi(d.scopeKind), "referenceAt", [q.scope, q.observation.expectedRevision], tag), expected.observation.recordHash);
  equal(await retainedChunks(p, saved.dependencies.targets[3], retained.canonical, tag), saved.stage.payloadChunks);
  equal(await retainedChunks(p, saved.dependencies.targets[3], ref.encodeTokenPreservationReferenceV2Publication(q), tag), saved.stage.publicationChunks);
  return { kind: "publication" as const, ...retained, publicationEventIndex: published.index };
}
/** Conservative preceding/end-block attribution; later same-block head progress requires separate review. */
export async function reconcileTokenPreservationReferenceV2Receipt(
  p: ReceiptReader,
  input: TokenPreservationReferenceV2WorkflowCapture,
  inputHash: Hex,
  supplied: TokenPreservationReferenceV2ReceiptOptions
) {
  const saved = savedCapture(input), transactionHash = hash(inputHash);
  if (supplied.execution !== "direct" && supplied.execution !== "safe") throw Error("Unknown execution transport");
  keys(supplied, supplied.execution === "safe" ? ["execution", "expectedSafeTxHash"] : ["execution"]);
  const options: TokenPreservationReferenceV2ReceiptOptions = supplied.execution === "safe"
    ? { execution: "safe", expectedSafeTxHash: hash(supplied.expectedSafeTxHash) } : { execution: "direct" };
  const mined = await io.transport(p, { chainId: saved.deployment.chainId, caller: saved.prepared.caller, call: saved.prepared.call, observed: saved.observed }, transactionHash, options);
  const prior = await revalidate(p, saved, mined.observed.blockNumber - 1);
  const result = prior.stage.kind === "preparation" ? await preparationReceipt(p, prior, mined) : await publicationReceipt(p, prior, mined);
  await unchanged(p, mined.observed);
  return freeze({ transactionHash, observed: mined.observed, prior, result, execution: options.execution,
    attribution: "exact-preceding-and-end-block-observation" as const, finalityEstablished: false as const });
}
async function localState(p: Reader, saved: TokenPreservationReferenceV2WorkflowCapture, tag: number) {
  const host = saved.deployment.reference.address;
  if (saved.stage.kind === "preparation") return preparedBytes(p, saved.deployment, saved.prepared.preparation!.id, tag);
  return { receipt: await read(p, host, hostAbi(saved.deployment.scopeKind), "currentReference", [saved.stage.preview.publication.scope], tag),
    count: await read(p, host, hostAbi(saved.deployment.scopeKind), "referenceCount", [saved.stage.preview.publication.scope], tag) };
}
export async function observeTokenPreservationReferenceV2Refusal(
  p: Reader,
  input: TokenPreservationReferenceV2WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }
) {
  const saved = savedCapture(input);
  keys(options, ["blockTag", "gasLimit"]);
  const tag = number(options.blockTag), cap = gas(options.gasLimit);
  if (tag < saved.observed.blockNumber) throw Error("Refusal predates capture");
  await revalidate(p, saved, saved.observed.blockNumber);
  const observed = await chain(p, saved.deployment.chainId, tag);
  await runtime(p, saved.deployment.reference, tag);
  for (const pin of saved.deployment.linkedDependencies.history) await runtime(p, pin, tag);
  const before = await localState(p, saved, tag);
  let failure: unknown;
  try { await p.call({ ...saved.prepared.call, from: saved.prepared.caller, blockTag: tag, gasLimit: cap }); }
  catch (error) { failure = error; }
  if (failure === undefined) throw Error("Original call did not refuse");
  const after = await localState(p, saved, tag);
  await unchanged(p, observed);
  return { observed, error: failure,
    outcome: (failure as { code?: string })?.code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const,
    retainedStateUnchanged: stable(before) === stable(after), rollbackProven: false as const };
}
