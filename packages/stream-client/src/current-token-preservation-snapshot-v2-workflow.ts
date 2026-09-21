import { Interface, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as p from "./current-token-preservation-snapshot-v2.js";
import * as output from "./current-token-preservation-output-v2.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";

const metadataAbi = new Interface([
  "function core() view returns (address)",
  "function schemaRegistry() view returns (address)",
  "function chunkStore() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function schemaRegistryCodeHash() view returns (bytes32)",
  "function chunkStoreCodeHash() view returns (bytes32)",
  "function familyWriter(uint256 collectionId, bytes32 family, uint8 authClass, address account) view returns (bool, uint64)"
]);

const coreAbi = new Interface([
  "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)"
]);

const routerAbi = new Interface([
  "function core() view returns (address)",
  "function artistPresentation(uint256 collectionId) view returns ((bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash))",
  "function collectionContentRootHead(uint256 collectionId) view returns (bytes32)",
  "function contentRootRecord(bytes32 hash) view returns (((uint256 collectionId, bytes32 expectedPredecessor, bytes32 verifiedManifestRecordHash, string manifestURI) publication, bytes32 contentRoot, uint64 leafCount, bytes32 manifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt))",
  "function preservationPolicyContentRootBinding(bytes32 recordHash) view returns ((bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address metadataRouter, bytes32 preservationOutputProfile))"
]);

const schemaAbi = new Interface([
  "function documentFacts(bytes32 id) view returns ((bool exists, uint8 kind, uint8 status, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, uint32 totalBytes, uint256 chunkCount, bytes32 declarationHash) facts)",
  "function documentChunkHashAt(bytes32 id, uint256 index) view returns (bytes32)",
  "function chunkStore() view returns (address)",
  "function document(bytes32 id) view returns ((bool exists, uint8 status, bytes32 declarationHash, (string name, uint8 kind, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, string uri, uint32 totalBytes) specification, bytes32[] chunkHashes))",
  "function documentBytes(bytes32 id) view returns (bytes payload)"
]);

const storeAbi = new Interface([
  "function readChunk(bytes32 hash) view returns (bytes payload)",
  "function chunk(bytes32) view returns (address pointer, uint32 length)"
]);

const membershipAbi = new Interface([
  "function core() view returns (address)",
  "function metadataHost() view returns (address)",
  "function requireScopeMembership((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash))"
]);

const selectionAbi = new Interface([
  "function core() view returns (address)",
  "function metadataHost() view returns (address)",
  "function metadataRouter() view returns (address)",
  "function scopeMembership() view returns (address)",
  "function checkpoint(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot))"
]);

const checkpointAbi = new Interface([
  "function core() view returns (address)",
  "function metadataRouter() view returns (address)",
  "function selectionCheckpoint() view returns (address)",
  "function entropySourceSet() view returns (address)",
  "function entropySourceSetCodeHash() view returns (bytes32)",
  "function preservationPolicyProfile() view returns (bytes32)",
  "function preservationOutputProfile() pure returns (bytes32)",
  "function sourceFactory() view returns (address)",
  "function sourceFactoryCodeHash() view returns (bytes32)",
  "function factoryDependenciesHash() view returns (bytes32)",
  "function checkpoint(bytes32 id) view returns ((bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot, bytes32 preservationProfile))"
]);

const outputAbi = new Interface([
  "function core() view returns (address)",
  "function contentCheckpoint() view returns (address)",
  "function artifactCoverage() view returns (address)",
  "function schemaRegistry() view returns (address)",
  "function outputProfile() view returns (bytes32)",
  "function requireCurrentManifest(bytes32 recordHash, bytes32 artistId) view returns ((bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, address metadataRouter, bytes32 preservationProfile, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) m)"
]);

const coverageAbi = new Interface([
  "function core() view returns (address)",
  "function schemaRegistry() view returns (address)",
  "function chunkStore() view returns (address)"
]);

const sourceAbi = new Interface([
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function SOURCE_SET_PROFILE() view returns (bytes32)",
  "function factory() view returns (address)",
  "function requireCurrentSourceSet() view",
  "function sourceScope() view returns ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId))",
  "function scopeMembershipFacts() view returns ((bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash))",
  "function inventoryPlan() view returns (bytes32)",
  "function originalInventoryHash() view returns (bytes32)",
  "function originalPolicyChainHash() view returns (bytes32)",
  "function sourceCount() view returns (uint256)",
  "function sourcePolicyAt(uint256 index) view returns ((address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy))"
]);

const factoryAbi = new Interface([
  "function core() view returns (address)",
  "function metadataHost() view returns (address)",
  "function scopeMembershipHost() view returns (address)",
  "function coordinatorInventory() view returns (address)",
  "function dependencies() view returns ((address[4] targets, bytes32[4] codeHashes, uint256 chainId, uint32 readGas, uint32 inventoryGas))",
  "function scopedPolicyFactoryProfile() pure returns (bytes32)",
  "function currentInventoryPlan((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (bytes32)",
  "function sourceSetForPlan(bytes32 plan) view returns (address sourceSet, bytes32 codeHash)",
  "function requireCurrentRoute((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bytes32 componentType, address component, bytes4 interfaceId, bytes32 codeHash))"
]);

const moduleRegistryAbi = new Interface([
  "function isModuleEligible(address module, bytes32 expectedModuleType, bytes4 expectedInterfaceId) view returns (bool)"
]);

// Original Solidity interfaces exclude inherited IERC165 selectors.
const CAPABILITIES = {
  "IStreamCollectionMetadataV1": "0x7e8260f8",
  "IStreamMetadataRouter": "0x222d4427",
  "IStreamPreservationPolicyContentCheckpointV1": "0x3082ba40",
  "IStreamPreservationPolicyOutputManifestV1": "0x80210de4",
  "IStreamFinalityEntropyPolicySourceSet": "0xeabbdeae",
  "IStreamFinalityScopedEntropyPolicySourceFactoryV2": "0x744da5f2"
} as const;
const moduleAbi = new Interface([
  "function supportsInterface(bytes4 interfaceId) view returns (bool)",
  "function streamModuleType() pure returns (bytes32)",
  "function streamModuleInterfaceId() pure returns (bytes4)"
]);
export type TokenPreservationSnapshotV2CodePin = io.CodePin;
export type TokenPreservationSnapshotV2ReceiptOptions = io.ReceiptOptions;
export interface TokenPreservationSnapshotV2Deployment {
  readonly chainId: bigint;
  readonly scopeKind: "collection" | "scoped";
  readonly snapshot: io.CodePin;
  /** Reviewed complete transitive release/link roster for fresh source and publication calls. */
  readonly linkedDependencies: readonly io.CodePin[];
  /** Reviewed local host/history-byte helper roster; excludes upstream admission dependencies. */
  readonly historyLinkedDependencies: readonly io.CodePin[];
}
type Reader = io.Reader;
type ReceiptReader = io.ReceiptReader;
type Publication = p.TokenPreservationSnapshotV2CollectionPublication | p.TokenPreservationSnapshotV2ScopedPublication;
type Source = p.TokenPreservationSnapshotV2CollectionSource | p.TokenPreservationSnapshotV2ScopedSource;
type Coordinates = p.TokenPreservationSnapshotV2Coordinates;
type Dependencies = p.TokenPreservationSnapshotV2Dependencies;
type Receipt = p.TokenPreservationSnapshotV2Receipt;
const { ZERO, ZERO_ADDRESS, coder, equal, same, address, hash, bytes, freeze, read, rpc } = io;
const FAMILY = id("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2") as Hex;
const SNAPSHOT = id("6529STREAM_RECORD_FAMILY_SNAPSHOT_V1") as Hex;
const IDENTITY = id("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1") as Hex;
const RAW = id("RAW_BYTES") as Hex;
const MAX_PAYLOAD = 524288;
function iface(kind: "collection" | "scoped") { return p.tokenPreservationSnapshotV2Interface(kind); }
function deployment(value: TokenPreservationSnapshotV2Deployment): TokenPreservationSnapshotV2Deployment {
  io.keys(value, ["chainId", "scopeKind", "snapshot", "linkedDependencies", "historyLinkedDependencies"]);
  if (io.uint(value.chainId) === 0n || !["collection", "scoped"].includes(value.scopeKind)) throw Error("Unsupported snapshot deployment");
  return freeze({ chainId: value.chainId, scopeKind: value.scopeKind, snapshot: io.codePin(value.snapshot),
    linkedDependencies: io.pinList(value.linkedDependencies), historyLinkedDependencies: io.pinList(value.historyLinkedDependencies) });
}
function encode(ifc: Interface, method: string, value: unknown): Hex {
  return coder.encode([ifc.getFunction(method)!.outputs[0]!], [value]) as Hex;
}
function pins(deps: { readonly targets: readonly Address[]; readonly codeHashes: readonly Hex[] }): readonly io.CodePin[] {
  return deps.targets.map((target, i) => ({ address: target, codeHash: deps.codeHashes[i]! }));
}
interface Context {
  readonly coordinates: Coordinates;
  readonly dependencies: Dependencies;
  readonly extraPins: readonly io.CodePin[];
  readonly factoryDependencies: Readonly<{ targets: readonly Address[]; codeHashes: readonly Hex[];
    chainId: bigint; readGas: bigint; inventoryGas: bigint }> | null;
}
async function supports(provider: Reader, target: Address, capability: string, tag: number, cap: bigint) {
  equal(await read(provider, target, moduleAbi, "supportsInterface", [capability], tag, undefined, cap), true, "Original capability unavailable");
}
async function selectedHost(provider: Reader, deps: Dependencies, at: number, capability: string, key: string, tag: number) {
  type Pointer = { target: Address; codeHash: Hex; frozen: boolean; moduleType: Hex; interfaceId: Hex; registry: Address; registryStatus: bigint; moduleManifestHash: Hex; deploymentManifestHash: Hex; revision: bigint };
  const pointerAt = async (name: string): Promise<Pointer> => {
    const values = await rpc(provider, deps.targets[0], coreAbi, "getSatellitePointer", [id(name)], tag, undefined, 150000n);
    return Object.fromEntries(coreAbi.getFunction("getSatellitePointer")!.outputs.map((field, index) => [field.name, values[index]])) as unknown as Pointer;
  };
  const pointer = await pointerAt(key);
  equal([pointer.target, pointer.codeHash, pointer.moduleType, pointer.interfaceId],
    [deps.targets[at], deps.codeHashes[at], id(key), capability], "Current Metadata/Router selection differs");
  if (![1n, 2n].includes(pointer.registryStatus) || pointer.revision === 0n) throw Error("Current module admission differs");
  hash(pointer.moduleManifestHash); hash(pointer.deploymentManifestHash); address(pointer.registry);
  const registry = await pointerAt("MODULE_REGISTRY");
  equal(registry.target, pointer.registry, "Selected ModuleRegistry differs");
  const pin = io.codePin({ address: registry.target, codeHash: registry.codeHash });
  await io.runtime(provider, pin, tag);
  equal(await read(provider, pin.address, moduleRegistryAbi, "isModuleEligible",
    [pointer.target, id(key), capability], tag, undefined, 150000n), true, "Current module is ineligible");
  equal([await read(provider, pointer.target, moduleAbi, "streamModuleType", [], tag, undefined, 150000n),
    await read(provider, pointer.target, moduleAbi, "streamModuleInterfaceId", [], tag, undefined, 150000n)],
  [id(key), capability], "Module self-description differs");
  await supports(provider, pointer.target, capability, tag, 150000n);
  await supports(provider, pointer.target, "0x01ffc9a7", tag, 150000n);
  equal(await read(provider, pointer.target, moduleAbi, "supportsInterface", ["0xffffffff"], tag, undefined, 150000n), false);
  return pin;
}
async function context(provider: Reader, d: TokenPreservationSnapshotV2Deployment, tag: number, current: boolean): Promise<Context> {
  await io.runtimes(provider, [d.snapshot, ...(current ? d.linkedDependencies : d.historyLinkedDependencies)], tag);
  const host = iface(d.scopeKind);
  const deps = p.normalizeTokenPreservationSnapshotV2Dependencies(await read(provider, d.snapshot.address, host, "dependencies", [], tag));
  equal([deps.chainId, await read(provider, d.snapshot.address, host, "core", [], tag),
    await read(provider, d.snapshot.address, host, "metadataHost", [], tag)], [d.chainId, deps.targets[0], deps.targets[1]], "Fixed snapshot deployment differs");
  const coordinates = p.normalizeTokenPreservationSnapshotV2Coordinates({ chainId: d.chainId, core: deps.targets[0],
    metadata: deps.targets[1], snapshot: d.snapshot.address, scopeKind: d.scopeKind });
  const profileMethod = d.scopeKind === "collection" ? "preservationPolicySnapshotProfile" : "scopedPreservationPolicySnapshotProfile";
  equal(await read(provider, d.snapshot.address, host, profileMethod, [], tag),
    id(d.scopeKind === "collection" ? "6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V2" : "6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2"), "Fixed snapshot profile differs");
  if (!current) return freeze({ coordinates, dependencies: deps, extraPins: [], factoryDependencies: null });
  if (deps.readGas < 50000n || deps.sourceGas < deps.readGas || deps.inventoryGas < deps.readGas
    || [deps.readGas, deps.sourceGas, deps.inventoryGas].some(x => x > 0xffffffffn)) throw Error("Original snapshot gas bounds differ");
  await io.runtimes(provider, pins(deps), tag);
  const extraPins = [await selectedHost(provider, deps, 1, CAPABILITIES.IStreamCollectionMetadataV1, "COLLECTION_METADATA", tag),
    await selectedHost(provider, deps, 4, CAPABILITIES.IStreamMetadataRouter, "METADATA_ROUTER", tag)];
  const tables: readonly (readonly [number, Interface, readonly (readonly [string, number])[]])[] = [
    [1, metadataAbi, [["core", 0], ["schemaRegistry", 2], ["chunkStore", 3]]],
    [2, schemaAbi, [["chunkStore", 3]]], [4, routerAbi, [["core", 0]]],
    [5, membershipAbi, [["core", 0], ["metadataHost", 1]]],
    [6, selectionAbi, [["core", 0], ["metadataHost", 1], ["metadataRouter", 4], ["scopeMembership", 5]]],
    [7, checkpointAbi, [["core", 0], ["metadataRouter", 4], ["selectionCheckpoint", 6], ["entropySourceSet", 10]]],
    [8, outputAbi, [["core", 0], ["contentCheckpoint", 7], ["artifactCoverage", 9], ["schemaRegistry", 2]]],
    [9, coverageAbi, [["core", 0], ["schemaRegistry", 2], ["chunkStore", 3]]], [10, sourceAbi, [["core", 0]]]
  ];
  for (const [at, abi, rows] of tables) for (const [method, expected] of rows)
    equal(await read(provider, deps.targets[at]!, abi, method, [], tag, undefined, deps.readGas), deps.targets[expected], "Reciprocal snapshot dependency differs");
  for (const [method, index] of [["coreCodeHash", 0], ["schemaRegistryCodeHash", 2], ["chunkStoreCodeHash", 3]] as const)
    equal(await read(provider, deps.targets[1], metadataAbi, method, [], tag, undefined, deps.readGas), deps.codeHashes[index], "Captured Metadata dependency pin differs");
  equal([await read(provider, deps.targets[10], sourceAbi, "coreCodeHash", [], tag, undefined, deps.readGas),
    await read(provider, deps.targets[7], checkpointAbi, "entropySourceSetCodeHash", [], tag, undefined, deps.readGas),
    await read(provider, deps.targets[7], checkpointAbi, "preservationPolicyProfile", [], tag, undefined, deps.readGas),
    await read(provider, deps.targets[7], checkpointAbi, "preservationOutputProfile", [], tag, undefined, deps.readGas),
    await read(provider, deps.targets[8], outputAbi, "outputProfile", [], tag, undefined, deps.readGas),
    await read(provider, deps.targets[10], sourceAbi, "SOURCE_SET_PROFILE", [], tag, undefined, deps.readGas)],
  [deps.codeHashes[0], deps.codeHashes[10], id(d.scopeKind === "collection" ? "6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2" : "6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2"),
    FAMILY, id("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2"), id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")], "Original producer family or runtime binding differs");
  for (const [at, capability] of [[7, CAPABILITIES.IStreamPreservationPolicyContentCheckpointV1],
    [8, CAPABILITIES.IStreamPreservationPolicyOutputManifestV1], [10, CAPABILITIES.IStreamFinalityEntropyPolicySourceSet]] as const)
    await supports(provider, deps.targets[at], capability, tag, deps.readGas);
  let factoryDependencies: Context["factoryDependencies"] = null;
  if (d.scopeKind === "scoped") {
    const factory = { address: address(await read(provider, deps.targets[10], sourceAbi, "factory", [], tag, undefined, deps.readGas)),
      codeHash: hash(await read(provider, deps.targets[7], checkpointAbi, "sourceFactoryCodeHash", [], tag, undefined, deps.readGas)) };
    equal(await read(provider, deps.targets[7], checkpointAbi, "sourceFactory", [], tag, undefined, deps.readGas), factory.address, "Scoped factory differs");
    await io.runtime(provider, factory, tag); extraPins.push(factory);
    factoryDependencies = await read(provider, factory.address, factoryAbi, "dependencies", [], tag, undefined, deps.readGas);
    const fd = factoryDependencies!;
    equal(keccak256(encode(factoryAbi, "dependencies", fd)), await read(provider, deps.targets[7], checkpointAbi, "factoryDependenciesHash", [], tag, undefined, deps.readGas), "Factory dependencies hash differs");
    equal([fd.chainId, fd.targets.slice(0, 3), fd.codeHashes.slice(0, 3)],
      [d.chainId, [deps.targets[0], deps.targets[1], deps.targets[5]], [deps.codeHashes[0], deps.codeHashes[1], deps.codeHashes[5]]], "Scoped factory original dependencies differ");
    if (fd.readGas < 50000n || fd.inventoryGas < fd.readGas) throw Error("Scoped factory gas bounds differ");
    for (let i = 0; i < 4; i++) {
      const pin = { address: address(fd.targets[i]), codeHash: hash(fd.codeHashes[i]) };
      await io.runtime(provider, pin, tag); extraPins.push(pin);
      equal(await read(provider, factory.address, factoryAbi, ["core", "metadataHost", "scopeMembershipHost", "coordinatorInventory"][i]!, [], tag, undefined, deps.readGas), pin.address, "Scoped factory getter differs");
    }
    equal(await read(provider, factory.address, factoryAbi, "scopedPolicyFactoryProfile", [], tag, undefined, deps.readGas), id("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2"));
    // The derived interface contributes only its two own selectors, excluding inherited generic factory methods.
    const factoryID = `0x${(BigInt(factoryAbi.getFunction("dependencies")!.selector) ^ BigInt(factoryAbi.getFunction("scopedPolicyFactoryProfile")!.selector)).toString(16).padStart(8, "0")}`;
    await supports(provider, factory.address, factoryID, tag, deps.readGas);
    await supports(provider, factory.address, factoryAbi.getFunction("requireCurrentRoute")!.selector, tag, deps.readGas);
  }
  return freeze({ coordinates, dependencies: deps, extraPins, factoryDependencies });
}
async function definitions(provider: Reader, c: Context, tag: number) {
  const d = c.dependencies;
  const snapshot = p.tokenPreservationSnapshotV2Definitions(c.coordinates.scopeKind);
  const expected = [...(c.coordinates.scopeKind === "collection"
    ? p.tokenPreservationSnapshotV2RootDefinitions().map((row, i) => ({ ...row, kind: i === 0 ? 0n : 1n })) : []),
  ...snapshot.map((row, i) => ({ ...row, kind: i === 0 ? 0n : i === 1 ? 2n : 1n }))];
  const observed = [];
  for (const def of expected) {
    const facts = await read(provider, d.targets[2], schemaAbi, "documentFacts", [def.id], tag, undefined, d.readGas) as {
      exists: boolean; status: bigint; kind: bigint; contentHash: Hex; canonicalizationId: Hex;
      supersedesId: Hex; totalBytes: bigint; declarationHash: Hex; chunkCount: bigint };
    equal([facts.exists, facts.status, facts.kind, facts.contentHash, facts.canonicalizationId, facts.supersedesId, facts.totalBytes],
      [true, 0n, def.kind, def.hash, RAW, ZERO, BigInt(def.byteLength)], "Required RAW definition differs");
    hash(facts.declarationHash);
    if (facts.chunkCount === 0n || facts.chunkCount > 64n) throw Error("Definition chunk count differs");
    let payload = "0x";
    const chunkHashes: Hex[] = [];
    for (let i = 0n; i < facts.chunkCount; i++) {
      const key = hash(await read(provider, d.targets[2], schemaAbi, "documentChunkHashAt", [def.id, i], tag, undefined, d.readGas));
      const chunk = bytes(await read(provider, d.targets[3], storeAbi, "readChunk", [key], tag, undefined, d.readGas), 8192);
      if (chunk.length === 2 || (i + 1n < facts.chunkCount && chunk.length !== 16386)) throw Error("Definition chunk length differs");
      equal(keccak256(chunk), key, "Definition chunk hash differs"); payload += chunk.slice(2); chunkHashes.push(key);
      bytes(payload, MAX_PAYLOAD);
    }
    equal([BigInt((payload.length - 2) / 2), keccak256(payload)], [BigInt(def.byteLength), def.hash], "Definition full bytes differ");
    observed.push({ id: def.id, facts, chunkHashes });
  }
  return freeze(observed);
}
async function source(provider: Reader, c: Context, publication: Publication, tag: number): Promise<Source> {
  const d = c.dependencies;
  const at = <T>(index: number, abi: Interface, method: string, args: readonly unknown[] = [], cap = d.readGas) =>
    read<T>(provider, d.targets[index]!, abi, method, args, tag, c.coordinates.snapshot, cap);
  const membership = p.normalizeTokenPreservationSnapshotV2Membership(await at(5, membershipAbi, "requireScopeMembership", [publication.scope], d.inventoryGas));
  const artist = p.normalizeTokenPreservationSnapshotV2ArtistPresentation(await at(4, routerAbi, "artistPresentation", [publication.scope.collectionId]));
  const outputs = p.normalizeTokenPreservationSnapshotV2Manifest(await at(8, outputAbi, "requireCurrentManifest", [publication.outputManifestRecord, artist.artistId], d.sourceGas));
  const content = p.normalizeTokenPreservationSnapshotV2ContentPlan(await at(7, checkpointAbi, "checkpoint", [outputs.checkpointHash]));
  const selection = p.normalizeTokenPreservationSnapshotV2SelectionPlan(await at(6, selectionAbi, "checkpoint", [content.selectionId]));
  await rpc(provider, d.targets[10], sourceAbi, "requireCurrentSourceSet", [], tag, c.coordinates.snapshot, d.inventoryGas);
  equal(await at(10, sourceAbi, "sourceScope"), publication.scope, "Original source full scope differs");
  equal(await at(10, sourceAbi, "scopeMembershipFacts"), membership, "Original source membership differs");
  const planId = hash(await at(10, sourceAbi, "inventoryPlan"));
  const inventoryHash = hash(await at(10, sourceAbi, "originalInventoryHash"));
  const policyChainHash = hash(await at(10, sourceAbi, "originalPolicyChainHash"));
  const policyCount = io.uint(await at(10, sourceAbi, "sourceCount"));
  if (policyCount === 0n || policyCount > 630n || policyCount > membership.tokenCount) throw Error("Original frozen policy count differs");
  const policies: p.TokenPreservationSnapshotV2CoordinatorPolicy[] = [];
  for (let i = 0n; i < policyCount; i++) policies.push(p.normalizeTokenPreservationSnapshotV2CoordinatorPolicy(await at(10, sourceAbi, "sourcePolicyAt", [i])));
  const base = { scope: publication.scope, membership, artist, outputs, content, selection,
    entropy: { planId, inventoryHash, policyChainHash, policyCount, allFrozen: true, policies } };
  let facts: Source;
  if (c.coordinates.scopeKind === "collection") {
    const rootKey = (publication as p.TokenPreservationSnapshotV2CollectionPublication).contentRootRecord;
    equal(await at(4, routerAbi, "collectionContentRootHead", [publication.scope.collectionId]), rootKey, "Current collection root differs");
    facts = { ...base, root: p.normalizeTokenPreservationSnapshotV2RootRecord(await at(4, routerAbi, "contentRootRecord", [rootKey])),
      rootBinding: p.normalizeTokenPreservationSnapshotV2RootBinding(await at(4, routerAbi, "preservationPolicyContentRootBinding", [rootKey])) };
  } else {
    const factory = address(await at(10, sourceAbi, "factory"));
    const factoryHash = hash(await at(7, checkpointAbi, "sourceFactoryCodeHash"));
    const factoryDependenciesHash = hash(await at(7, checkpointAbi, "factoryDependenciesHash"));
    equal(await read(provider, factory, factoryAbi, "currentInventoryPlan", [publication.scope], tag, c.coordinates.snapshot, d.inventoryGas), planId, "Current factory plan differs");
    equal(await rpc(provider, factory, factoryAbi, "sourceSetForPlan", [planId], tag, c.coordinates.snapshot, d.readGas),
      [d.targets[10], d.codeHashes[10]], "Scoped source registration differs");
    equal(await read(provider, factory, factoryAbi, "requireCurrentRoute", [publication.scope], tag, c.coordinates.snapshot, d.inventoryGas),
      { componentType: id("ENTROPY_COORDINATOR"), component: d.targets[10], interfaceId: "0x8004d4f5", codeHash: d.codeHashes[10] }, "Current scoped entropy route differs");
    facts = { ...base, sourceFactory: factory, sourceFactoryCodeHash: factoryHash, factoryDependenciesHash };
  }
  return freeze(p.validateTokenPreservationSnapshotV2Source(c.coordinates, d, publication, facts));
}
async function authority(provider: Reader, c: Context, publication: Publication, caller: Address, family: Hex, tag: number) {
  for (const authorizationClass of [7n, 8n] as const) {
    const [enabled, revision] = await rpc(provider, c.coordinates.metadata, metadataAbi, "familyWriter",
      [authorizationClass === 7n ? publication.scope.collectionId : 0n, family, authorizationClass, caller], tag, c.coordinates.snapshot, c.dependencies.readGas);
    if (enabled === true && typeof revision === "bigint" && revision !== 0n) return { authorizationClass, grantRevision: revision };
  }
  throw Error("Publisher lacks an independent original family grant");
}
async function chunks(provider: Reader, store: Address, canonical: Hex, tag: number) {
  const results: { readonly hash: Hex; readonly pointer: Address; readonly length: bigint }[] = [];
  for (let offset = 2; offset < canonical.length; offset += 16384) {
    const data = `0x${canonical.slice(offset, offset + 16384)}` as Hex;
    const key = keccak256(data) as Hex;
    const [pointer_, length] = await rpc(provider, store, storeAbi, "chunk", [key], tag);
    const pointer = address(pointer_);
    equal(length, BigInt((data.length - 2) / 2), "Snapshot chunk must already be uploaded");
    equal(bytes(await provider.getCode(pointer, tag), 8193), `0x00${data.slice(2)}`, "Snapshot STOP carrier differs");
    results.push({ hash: key, pointer, length: length as bigint });
  }
  return freeze(results);
}
async function lineage(provider: Reader, c: Context, publication: Publication, observed: io.Block, fresh: boolean) {
  const host = iface(c.coordinates.scopeKind);
  const current = p.normalizeTokenPreservationSnapshotV2Receipt(await read(provider, c.coordinates.snapshot, host, "currentSnapshot", [publication.scope], observed.blockNumber));
  const count = io.uint(await read(provider, c.coordinates.snapshot, host, "snapshotCount", [publication.scope], observed.blockNumber));
  const lock = p.normalizeTokenPreservationSnapshotV2Lock(await read(provider, c.coordinates.snapshot, host, "snapshotLock", [publication.scope], observed.blockNumber));
  if (fresh && lock.actionId !== ZERO) throw Error("Snapshot is governed-locked");
  if (fresh && (publication.effectiveAt > observed.timestamp || publication.expectedRevision !== count || publication.expectedHead !== current.recordHash)) throw Error("Snapshot lineage or effective time differs");
  if (current.recordHash === ZERO) {
    if (!/^0x0+$/.test(p.encodeTokenPreservationSnapshotV2Receipt(current)) || count !== 0n) throw Error("Noncanonical absent snapshot");
  } else {
    if (current.revision !== count) throw Error("Current snapshot count differs");
    const [savedP, savedR] = await rpc(provider, c.coordinates.snapshot, host, "snapshotRecord", [current.recordHash], observed.blockNumber);
    equal((savedP as Publication).scope, publication.scope, "Current snapshot full scope differs"); equal(savedR, current);
  }
  return freeze({ current, count, lock });
}
async function stage(provider: Reader, c: Context, publication: Publication, caller: Address, observed: io.Block, stored: boolean) {
  const before = await lineage(provider, c, publication, observed, true);
  const docs = await definitions(provider, c, observed.blockNumber);
  const facts = await source(provider, c, publication, observed.blockNumber);
  const sourceHash = p.tokenPreservationSnapshotV2SourceHash(c.coordinates, c.dependencies, facts);
  const snapshotGrant = await authority(provider, c, publication, caller, SNAPSHOT, observed.blockNumber);
  const displayGrant = await authority(provider, c, publication, caller, IDENTITY, observed.blockNumber);
  const receipt = p.tokenPreservationSnapshotV2PreviewReceipt(c.coordinates, publication, caller, {
    ...snapshotGrant, displayAuthorizationClass: displayGrant.authorizationClass, displayGrantRevision: displayGrant.grantRevision }, sourceHash);
  const canonical = p.tokenPreservationSnapshotV2SnapshotBytes(c.coordinates, c.dependencies, publication, receipt, facts);
  equal(await rpc(provider, c.coordinates.snapshot, iface(c.coordinates.scopeKind), "previewSnapshot", [publication, caller], observed.blockNumber, caller),
    [sourceHash, canonical], "Original preview/source/canonical payload differs");
  if (stored) equal(publication.expectedSourceHash, sourceHash, "Expected snapshot source differs");
  const carriers = stored ? await chunks(provider, c.dependencies.targets[3], canonical, observed.blockNumber) : null;
  return freeze({ before, definitions: docs, source: facts, sourceHash, receipt, canonical, carriers });
}
export async function previewTokenPreservationSnapshotV2(provider: Reader, inputDeployment: TokenPreservationSnapshotV2Deployment,
  inputPublication: Publication, inputPublisher: Address, options: { readonly blockTag: number }) {
  const d = deployment(inputDeployment); const publication = p.validateTokenPreservationSnapshotV2Publication(d.scopeKind, inputPublication, false);
  const publisher = address(inputPublisher); io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  const observed = await io.chain(provider, d.chainId, tag); const c = await context(provider, d, tag, true);
  const result = await stage(provider, c, publication, publisher, observed, false); await io.unchanged(provider, observed);
  return freeze({ deployment: d, observed, context: c, publication, publisher, ...result,
    readyPublication: { ...publication, expectedSourceHash: result.sourceHash }, storeAvailabilityChecked: false as const,
    finalityEstablished: false as const });
}
type Immutable<T> = T extends readonly (infer Item)[] ? readonly Immutable<Item>[]
  : T extends object ? { readonly [K in keyof T]: Immutable<T[K]> } : T;
export interface TokenPreservationSnapshotV2Capture {
  readonly deployment: TokenPreservationSnapshotV2Deployment;
  readonly prepared: p.TokenPreservationSnapshotV2Call;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly context: Immutable<Context>;
  readonly stage: Immutable<Awaited<ReturnType<typeof stage>>>;
  readonly captureHash: Hex;
}
export async function captureTokenPreservationSnapshotV2(provider: Reader, inputDeployment: TokenPreservationSnapshotV2Deployment,
  inputCaller: Address, inputRequest: p.TokenPreservationSnapshotV2Request,
  options: { readonly blockTag: number; readonly gasLimit: bigint }): Promise<TokenPreservationSnapshotV2Capture> {
  const d = deployment(inputDeployment); const caller = address(inputCaller);
  io.keys(inputRequest, ["kind", "publication"]); if (inputRequest.kind !== "publishSnapshot") throw Error("Unsupported snapshot write");
  const publication = p.validateTokenPreservationSnapshotV2Publication(d.scopeKind, inputRequest.publication, true);
  io.keys(options, ["blockTag", "gasLimit"]); const tag = io.number(options.blockTag); const gasLimit = io.gas(options.gasLimit);
  const observed = await io.chain(provider, d.chainId, tag); const c = await context(provider, d, tag, true);
  const prepared = p.prepareTokenPreservationSnapshotV2Call(c.coordinates, caller, { kind: "publishSnapshot", publication });
  const captured = await stage(provider, c, publication, caller, observed, true); await io.unchanged(provider, observed);
  const fields = { deployment: d, prepared, observed, gasLimit, context: c, stage: captured };
  return freeze({ ...fields, captureHash: io.fingerprint(fields) });
}
function snapshotCapture(value: TokenPreservationSnapshotV2Capture): TokenPreservationSnapshotV2Capture {
  io.keys(value, ["deployment", "prepared", "observed", "gasLimit", "context", "stage", "captureHash"]);
  const saved = structuredClone(value); const { captureHash, ...fields } = saved;
  equal(io.fingerprint(fields), hash(captureHash), "Capture fingerprint differs"); deployment(saved.deployment); io.gas(saved.gasLimit);
  equal(p.normalizeTokenPreservationSnapshotV2Call(saved.prepared), saved.prepared, "Prepared call differs");
  equal(saved.prepared.coordinates, saved.context.coordinates, "Captured coordinates differ");
  equal([saved.prepared.coordinates.chainId, saved.prepared.coordinates.snapshot, saved.prepared.coordinates.scopeKind],
    [saved.deployment.chainId, saved.deployment.snapshot.address, saved.deployment.scopeKind]);
  return freeze(saved);
}
function comparable(value: TokenPreservationSnapshotV2Capture) {
  const { observed: _observed, captureHash: _hash, ...rest } = value; return rest;
}
async function revalidate(provider: Reader, saved: TokenPreservationSnapshotV2Capture, tag: number) {
  if (tag < saved.observed.blockNumber) throw Error("Cannot revalidate before captured block");
  await io.unchanged(provider, saved.observed);
  const original = await captureTokenPreservationSnapshotV2(provider, saved.deployment, saved.prepared.caller, saved.prepared.request,
    { blockTag: saved.observed.blockNumber, gasLimit: saved.gasLimit }); equal(original, saved, "Original capture reconstruction differs");
  const current = tag === saved.observed.blockNumber ? original : await captureTokenPreservationSnapshotV2(provider,
    saved.deployment, saved.prepared.caller, saved.prepared.request, { blockTag: tag, gasLimit: saved.gasLimit });
  equal(comparable(current), comparable(saved), "Snapshot facts changed; recapture"); return current;
}
function atTime(saved: TokenPreservationSnapshotV2Capture, timestamp: bigint): Receipt {
  const publication = saved.prepared.request.publication;
  if (timestamp >= 1n << 64n || publication.effectiveAt > timestamp) throw Error("Snapshot mined time differs");
  const receipt = { ...saved.stage.receipt, manifestHash: keccak256(saved.stage.canonical) as Hex,
    manifestBytes: BigInt((saved.stage.canonical.length - 2) / 2), recordedAt: timestamp };
  const recordHash = p.tokenPreservationSnapshotV2RecordHash(saved.context.coordinates, publication, receipt);
  const chainHash = p.tokenPreservationSnapshotV2ChainHash(saved.context.coordinates, publication.scope,
    saved.stage.before.current.chainHash, receipt.revision, recordHash);
  return freeze({ ...receipt, recordHash, chainHash });
}
export async function simulateTokenPreservationSnapshotV2(provider: Reader, input: TokenPreservationSnapshotV2Capture,
  options: { readonly blockTag: number }) {
  const saved = snapshotCapture(input); io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  const current = await revalidate(provider, saved, tag);
  const values = await rpc(provider, current.prepared.call.to, iface(current.deployment.scopeKind), "publishSnapshot",
    [current.prepared.request.publication], tag, current.prepared.caller, current.gasLimit);
  equal(values, [atTime(current, current.observed.timestamp).recordHash], "Simulated snapshot result differs"); await io.unchanged(provider, current.observed);
  return freeze({ capture: current, result: hash(values[0]), simulated: true as const, persisted: false as const, finalityEstablished: false as const });
}
async function localRecord(provider: Reader, c: Context, key: Hex, tag: number) {
  const host = iface(c.coordinates.scopeKind);
  const [publication_, receipt_] = await rpc(provider, c.coordinates.snapshot, host, "snapshotRecord", [key], tag);
  const publication = p.normalizeTokenPreservationSnapshotV2Publication(c.coordinates.scopeKind, publication_ as Publication);
  const receipt = p.normalizeTokenPreservationSnapshotV2Receipt(receipt_ as Receipt);
  equal(receipt.recordHash, key, "Retained record key differs");
  const canonical = bytes(await read(provider, c.coordinates.snapshot, host, "snapshotPayload", [key], tag), MAX_PAYLOAD);
  let previousChain = ZERO;
  if (receipt.predecessor !== ZERO) {
    const [previousP, previousR] = await rpc(provider, c.coordinates.snapshot, host, "snapshotRecord", [receipt.predecessor], tag);
    const predecessor = p.normalizeTokenPreservationSnapshotV2Receipt(previousR as Receipt);
    const previous = p.normalizeTokenPreservationSnapshotV2Publication(c.coordinates.scopeKind, previousP as Publication);
    equal(previous.scope, publication.scope, "Retained predecessor full scope differs");
    equal([predecessor.recordHash, predecessor.revision + 1n], [receipt.predecessor, receipt.revision], "Retained predecessor lineage differs");
    equal(p.tokenPreservationSnapshotV2RecordHash(c.coordinates, previous, predecessor), receipt.predecessor, "Retained predecessor record hash differs");
    previousChain = hash(predecessor.chainHash);
  }
  const payload = p.authenticateTokenPreservationSnapshotV2History(c.coordinates, c.dependencies, publication, receipt, canonical, previousChain);
  if (c.coordinates.scopeKind === "collection") {
    const chunkCount = io.uint(await read(provider, c.coordinates.snapshot, host, "snapshotChunkCount", [key], tag));
    equal(chunkCount, BigInt(Math.ceil((canonical.length - 2) / 16384)), "Retained chunk count differs");
    for (let i = 0; i < Number(chunkCount); i++) {
      const part = `0x${canonical.slice(2 + i * 16384, 2 + (i + 1) * 16384)}` as Hex;
      const [pointer, chunkHash, length] = await rpc(provider, c.coordinates.snapshot, host, "snapshotChunkAt", [key, BigInt(i)], tag);
      equal([chunkHash, length], [keccak256(part), BigInt((part.length - 2) / 2)], "Retained chunk metadata differs");
      equal(bytes(await provider.getCode(address(pointer), tag), 8193), `0x00${part.slice(2)}`, "Retained STOP carrier differs");
    }
  }
  return freeze({ publication, receipt, canonical, payload });
}
export async function inspectTokenPreservationSnapshotV2History(provider: Reader, inputDeployment: TokenPreservationSnapshotV2Deployment,
  inputRecordHash: Hex, options: { readonly blockTag: number }) {
  const d = deployment(inputDeployment); const recordHash = hash(inputRecordHash);
  io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  const observed = await io.chain(provider, d.chainId, tag); const c = await context(provider, d, tag, false);
  const retained = await localRecord(provider, c, recordHash, tag); await io.unchanged(provider, observed);
  return freeze({ deployment: d, observed, coordinates: c.coordinates, ...retained,
    immutableHistoryAuthenticated: true as const, currentEligibilityChecked: false as const, finalityEstablished: false as const });
}
/** Original requireCurrent retains the recorded publisher grants; no fresh familyWriter authorization is performed. */
export async function inspectTokenPreservationSnapshotV2Current(provider: Reader, inputDeployment: TokenPreservationSnapshotV2Deployment,
  inputScope: p.TokenPreservationSnapshotV2Scope, options: { readonly blockTag: number }) {
  const d = deployment(inputDeployment); const scope = p.validateTokenPreservationSnapshotV2Scope(d.scopeKind, inputScope);
  io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  const observed = await io.chain(provider, d.chainId, tag); const c = await context(provider, d, tag, true);
  const host = iface(d.scopeKind);
  const current = p.normalizeTokenPreservationSnapshotV2Receipt(await read(provider, d.snapshot.address, host, "currentSnapshot", [scope], tag));
  if (current.recordHash === ZERO) {
    equal(p.encodeTokenPreservationSnapshotV2Receipt(current), coder.encode([p.TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE],
      [Object.fromEntries(Object.entries(current).map(([key, value]) => [key, typeof value === "bigint" ? 0n : key === "publisher" ? ZERO_ADDRESS : ZERO]))]));
    equal(await read(provider, d.snapshot.address, host, "snapshotCount", [scope], tag), 0n, "Empty snapshot count differs");
    await io.unchanged(provider, observed);
    return freeze({ deployment: d, observed, scope, exists: false as const, current: null, source: null, currentEligibilityChecked: false as const, finalityEstablished: false as const });
  }
  const retained = await localRecord(provider, c, current.recordHash, tag);
  equal(retained.publication.scope, scope, "Current snapshot full scope differs"); equal(retained.receipt, current);
  equal(await read(provider, d.snapshot.address, host, "snapshotCount", [scope], tag), current.revision, "Current snapshot count differs");
  await definitions(provider, c, tag);
  const facts = await source(provider, c, retained.publication, tag);
  equal(p.tokenPreservationSnapshotV2SourceHash(c.coordinates, c.dependencies, facts), current.sourceHash, "Current snapshot source changed");
  equal(p.tokenPreservationSnapshotV2SnapshotBytes(c.coordinates, c.dependencies, retained.publication, current, facts), retained.canonical,
    "Current canonical snapshot changed");
  equal(await read(provider, d.snapshot.address, host, "requireCurrent", [scope, current.recordHash, current.revision], tag), current,
    "Original requireCurrent result differs");
  await io.unchanged(provider, observed);
  return freeze({ deployment: d, observed, scope, exists: true as const, current: retained, source: facts,
    currentEligibilityChecked: true as const, publisherReauthorized: false as const, finalityEstablished: false as const });
}
export async function reconcileTokenPreservationSnapshotV2Receipt(provider: ReceiptReader, input: TokenPreservationSnapshotV2Capture,
  inputTransactionHash: Hex, inputOptions: TokenPreservationSnapshotV2ReceiptOptions) {
  const saved = snapshotCapture(input); const transactionHash = hash(inputTransactionHash);
  const options = structuredClone(inputOptions);
  const t = await io.transport(provider, { chainId: saved.deployment.chainId, caller: saved.prepared.caller,
    call: saved.prepared.call, observed: saved.observed }, transactionHash, options);
  const prior = await revalidate(provider, saved, t.observed.blockNumber - 1);
  const d = saved.deployment;
  await io.runtimes(provider, [d.snapshot, ...d.linkedDependencies, ...d.historyLinkedDependencies,
    ...pins(prior.context.dependencies), ...prior.context.extraPins], t.observed.blockNumber);
  const expected = atTime(prior, t.observed.timestamp); const host = iface(d.scopeKind);
  const eventName = d.scopeKind === "collection" ? "PolicySnapshotPublished" : "ScopedPolicySnapshotPublished";
  const event = io.one(t.logs, d.snapshot.address, host, eventName,
    [2n, expected.scopeSubject, prior.prepared.request.publication.snapshotId, expected.recordHash, prior.prepared.request.publication, expected]);
  // The original write emits only the snapshot event; Store bytes were uploaded earlier.
  if (t.logs.filter(log => same(log.address, d.snapshot.address)).length !== 1
    || t.logs.some(log => same(log.address, prior.context.dependencies.targets[3]))) throw Error("Unexpected snapshot or Store write event");
  io.finish(t.logs, [d.snapshot.address], t.safeIndex);
  const c = await context(provider, d, t.observed.blockNumber, false);
  equal([c.coordinates, c.dependencies.targets, c.dependencies.codeHashes],
    [prior.context.coordinates, prior.context.dependencies.targets, prior.context.dependencies.codeHashes], "Mined snapshot deployment differs");
  const retained = await localRecord(provider, c, expected.recordHash, t.observed.blockNumber);
  equal([retained.publication, retained.receipt, retained.canonical], [prior.prepared.request.publication, expected, prior.stage.canonical], "Mined snapshot retained bytes differ");
  const publication = prior.prepared.request.publication;
  equal(await read(provider, d.snapshot.address, host, "currentSnapshot", [publication.scope], t.observed.blockNumber), expected, "End-block snapshot head differs");
  equal(await read(provider, d.snapshot.address, host, "snapshotCount", [publication.scope], t.observed.blockNumber), expected.revision, "End-block snapshot count differs");
  equal(await read(provider, d.snapshot.address, host, "snapshotAt", [publication.scope, expected.revision - 1n], t.observed.blockNumber), expected.recordHash, "Snapshot history append differs");
  await io.unchanged(provider, t.observed);
  return freeze({ capture: prior, observed: t.observed, transactionHash, eventIndex: event.index, ...retained,
    receiptAttribution: "unchanged-preceding-block-and-exact-end-block" as const,
    currentEligibilityCheckedAtReceipt: false as const, finalityEstablished: false as const });
}
async function retainedState(provider: Reader, saved: TokenPreservationSnapshotV2Capture, tag: number) {
  const host = iface(saved.deployment.scopeKind); const target = saved.deployment.snapshot.address;
  const scope = saved.prepared.request.publication.scope;
  return { current: await read(provider, target, host, "currentSnapshot", [scope], tag),
    count: await read(provider, target, host, "snapshotCount", [scope], tag),
    lock: await read(provider, target, host, "snapshotLock", [scope], tag) };
}
export async function observeTokenPreservationSnapshotV2Refusal(provider: Reader, input: TokenPreservationSnapshotV2Capture,
  options: { readonly blockTag: number }) {
  const saved = snapshotCapture(input); io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  if (tag < saved.observed.blockNumber) throw Error("Cannot observe refusal before capture");
  await revalidate(provider, saved, saved.observed.blockNumber);
  const observed = await io.chain(provider, saved.deployment.chainId, tag);
  await io.runtimes(provider, [saved.deployment.snapshot, ...saved.deployment.historyLinkedDependencies], tag);
  const before = await retainedState(provider, saved, tag);
  let outcome: "execution-reverted" | "rpc-failed" | "succeeded" = "succeeded";
  let error: unknown = null; let returnData: Hex | null = null;
  try { returnData = bytes(await provider.call({ ...saved.prepared.call, from: saved.prepared.caller,
    blockTag: tag, gasLimit: saved.gasLimit })); }
  catch (cause) { error = cause; outcome = cause && typeof cause === "object" && "code" in cause && cause.code === "CALL_EXCEPTION" ? "execution-reverted" : "rpc-failed"; }
  const after = await retainedState(provider, saved, tag); equal(after, before, "Retained refusal observations changed");
  await io.unchanged(provider, observed);
  return { observed, before: freeze(before), after: freeze(after), outcome, error, returnData,
    retainedStateUnchanged: true as const, nativeRollbackProven: false as const };
}
