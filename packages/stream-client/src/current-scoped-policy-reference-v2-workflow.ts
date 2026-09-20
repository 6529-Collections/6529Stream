import {
  AbiCoder,
  Interface,
  ParamType,
  ZeroAddress as ETH_ZERO_ADDRESS,
  ZeroHash as ETH_ZERO_HASH,
  getAddress,
  id,
  isHexString,
  keccak256,
  sha256,
  toUtf8Bytes,
  type Provider
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as ref from "./current-scoped-policy-reference-v2.js";
import * as pub from "./current-scoped-policy-publication-v2.js";
import * as graph from "./current-scoped-policy-graph-v2.js";
import * as root from "./current-scoped-policy-root-v2.js";
import { inspectScopedPolicyPublicationV2History } from "./current-scoped-policy-publication-v2-workflow.js";
import { prepareReferenceEnvironment } from "./current-reference-environment.js";
import { prepareReferenceInventory, referenceInventoryParts } from "./current-reference-inventory.js";
import { requireSafeExecution } from "./safe.js";
type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;

export interface ScopedPolicyReferenceV2CodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}

export interface ScopedPolicyReferenceV2Block {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
}
/** Complete linked-runtime lists come from reviewed release metadata, not inferred runtime hashes. */
export interface ScopedPolicyReferenceV2Deployment {
  readonly chainId: bigint;
  readonly core: ScopedPolicyReferenceV2CodePin;
  readonly metadata: ScopedPolicyReferenceV2CodePin;
  readonly reference: ScopedPolicyReferenceV2CodePin;
  readonly linkedDependencies: {
    readonly preparation: readonly ScopedPolicyReferenceV2CodePin[];
    readonly source: readonly ScopedPolicyReferenceV2CodePin[];
    readonly history: readonly ScopedPolicyReferenceV2CodePin[];
  };
}
export interface ScopedPolicyReferenceV2HistoryDeployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly metadata: Address;
  readonly reference: ScopedPolicyReferenceV2CodePin;
  readonly linkedDependencies: readonly ScopedPolicyReferenceV2CodePin[];
}
const ZERO = ETH_ZERO_HASH as Hex;
const ZERO_ADDRESS = ETH_ZERO_ADDRESS as Address;
const coder = AbiCoder.defaultAbiCoder();
const MAX_RPC = 2097152;
const MAX_CALL = 2097152;
const MAX_RUNTIME = 131072;
const MAX_LOGS = 4096;
function keys(value: unknown, required: readonly string[], optional: readonly string[] = []): void {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || required.some(key => !Object.hasOwn(value, key))
    || Reflect.ownKeys(value).some(key => typeof key !== "string" || ![...required, ...optional].includes(key))) {
    throw Error("Missing or unknown properties");
  }
}

function address(value: unknown, zero = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (!zero && result === ZERO_ADDRESS) throw Error("Zero address");
  return result;
}

function hash(value: unknown, zero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32)
    || (!zero && value.toLowerCase() === ZERO)) throw Error("Expected bytes32");
  return value.toLowerCase() as Hex;
}

function bytes(value: unknown, maximum = MAX_RPC): Hex {
  if (typeof value !== "string" || !isHexString(value, true)
    || (value.length - 2) / 2 > maximum) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= (1n << BigInt(bits))) {
    throw Error("Expected bounded unsigned bigint");
  }
  return value;
}

function number(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw Error("Expected concrete block/index");
  }
  return value;
}

function same(a: unknown, b: unknown): boolean {
  return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
}

function stable(value: unknown): string {
  function convert(v: unknown): unknown {
    if (v === null) return ["null"];
    if (typeof v === "string" || typeof v === "boolean") return [typeof v, v];
    if (typeof v === "bigint") return ["bigint", v.toString()];
    if (typeof v === "number" && Number.isFinite(v)) return ["number", v];
    if (Array.isArray(v)) return ["array", v.map(convert)];
    if (v && typeof v === "object") {
      return ["object", Object.keys(v).sort().map(key => [key, convert((v as Record<string, unknown>)[key])])];
    }
    throw Error("Unsupported canonical value");
  }
  return JSON.stringify(convert(value));
}

function equal(a: unknown, b: unknown, reason = "Observed facts changed; recapture and review"): void {
  if (stable(a) !== stable(b)) throw Error(reason);
}

function freeze<T>(value: T): T {
  if (value && typeof value === "object") {
    Object.values(value).forEach(freeze);
    Object.freeze(value);
  }
  return value;
}

function fingerprint(value: unknown): Hex {
  return keccak256(toUtf8Bytes(stable(value))) as Hex;
}

function codePin(value: ScopedPolicyReferenceV2CodePin): ScopedPolicyReferenceV2CodePin {
  keys(value, ["address", "codeHash"]);
  return { address: address(value.address), codeHash: hash(value.codeHash) };
}

function pinList(value: readonly ScopedPolicyReferenceV2CodePin[]): readonly ScopedPolicyReferenceV2CodePin[] {
  if (!Array.isArray(value) || value.length > 256) throw Error("Linked dependency limit exceeded");
  const pins = value.map(codePin);
  if (new Set(pins.map(pin => pin.address)).size !== pins.length) throw Error("Duplicate linked dependency");
  return pins;
}

async function header(provider: Reader, tag: number): Promise<ScopedPolicyReferenceV2Block> {
  const value = await provider.getBlock(number(tag));
  if (!value || value.number !== tag) throw Error("Missing or mismatched block");
  return { blockNumber: tag, blockHash: hash(value.hash), timestamp: BigInt(number(value.timestamp)) };
}

async function unchanged(provider: Reader, block: ScopedPolicyReferenceV2Block): Promise<void> {
  equal(await header(provider, block.blockNumber), block, "Pinned block changed");
}

async function runtime(provider: Reader, pin: ScopedPolicyReferenceV2CodePin, tag: number): Promise<void> {
  const raw = bytes(await provider.getCode(pin.address, tag), MAX_RUNTIME);
  if (raw === "0x" || (raw.length === 48 && raw.startsWith("0xef0100"))
    || !same(keccak256(raw), pin.codeHash)) throw Error("Pinned runtime differs");
}

function plain(param: ParamType, value: unknown): unknown {
  if (param.baseType === "array") return (value as readonly unknown[]).map(item => plain(param.arrayChildren!, item));
  if (param.baseType === "tuple") {
    const fields = param.components!;
    if (fields.every(field => field.name !== "")) {
      return Object.fromEntries(fields.map((field, index) => [field.name, plain(field, (value as readonly unknown[])[index])]));
    }
    return fields.map((field, index) => plain(field, (value as readonly unknown[])[index]));
  }
  return value;
}

async function rpc(provider: Reader, target: Address, iface: Interface, method: string,
  args: readonly unknown[], tag: number, from?: Address, gasLimit?: bigint): Promise<readonly unknown[]> {
  const data = iface.encodeFunctionData(method, args);
  const result = bytes(await provider.call({ to: target, data, blockTag: tag, ...(from ? { from } : {}),
    ...(gasLimit ? { gasLimit } : {}) }));
  const decoded = iface.decodeFunctionResult(method, result);
  if (!same(iface.encodeFunctionResult(method, decoded), result)) throw Error("Noncanonical RPC result");
  return iface.getFunction(method)!.outputs.map((param, index) => plain(param, decoded[index]));
}

const hostAbi = new Interface([
  "function core() view returns (address)",
  "function metadataHost() view returns (address)",
  "function metadataRouter() view returns (address)",
  "function snapshots() view returns (address)",
  "function archiveCoverage() view returns (address)",
  "function deploymentChainId() view returns (uint256)",
  "function dependencies() view returns ((address[7] targets, bytes32[7] codeHashes, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 snapshotGas, uint256 archiveGas) d)",
  "function scopedPolicyReferenceProfile() pure returns (bytes32)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  "function preparedFileInventory(bytes32 id) view returns (bytes)",
  "function currentReference((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation))",
  "function referenceRecord(bytes32 hash) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 referenceId, bytes32 expectedHead, uint64 expectedRevision, bytes32 snapshotRecordHash, uint64 snapshotRevision, bytes32 expectedSourcesHash, (uint256 tokenId, uint256 collectionSerial, bytes32 metadataJSONHash, bytes32 htmlHash, uint32 htmlBytes, bytes animationHTML, bytes32 objectHash, bytes32 coverageHash, bytes32 sourceSha256, bytes32[2] repeatCaptureSha256, bytes32 environmentManifestHash, uint64 capturedAt)[] captures, (bytes32 objectHash, bytes32 coverageHash, bytes32 manifestHash, uint32 manifestBytes, string engineName, string engineVersion, bytes32 engineExecutableSha256, string toolchainName, string toolchainVersion, bytes32 toolchainSha256, string engineExecutablePath, string toolchainPath, (string path, uint64 byteSize, bytes32 sha256Digest)[] packageFiles, (string path, uint64 byteSize, bytes32 sha256Digest)[] platformPrerequisites, string operatingSystem, string operatingSystemVersion, string architecture, uint16 viewportWidth, uint16 viewportHeight, uint8 devicePixelRatio, string colorSpace, bool softwareRasterization, bytes32 captureProfile, string licenseNote) environment, string manifestURI, uint64 effectiveAt, bytes32 reasonHash) observation), (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation))",
  "function referencePayload(bytes32 hash) view returns (bytes)",
  "function referenceSource(bytes32 hash) view returns ((bytes32 scopeSubject, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, bytes32 contentRootRecordHash, (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 expectedPredecessor, bytes32 snapshotRecordHash, uint64 snapshotRevision, string manifestURI) publication, address snapshotHost, bytes32 snapshotCodeHash, bytes32 snapshotManifestHash, bytes32 snapshotSourceHash, bytes32 contentRoot, uint64 leafCount, bytes32 outputManifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt) contentRoot, (bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, bytes32 snapshotSchemaHash, bytes32 snapshotProfileHash, bytes32 snapshotCanonicalizationHash) contentRootBinding, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) environmentCoverage, (uint64 membershipIndex, (uint256 tokenId, uint256 collectionSerial, address originalCoordinator, bytes32 seed, bytes32 tokenDataHash, uint32 tokenDataBytes, bytes32 metadataJSONHash, bytes32 htmlHash, uint32 htmlBytes, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) captureCoverage) observation, (uint256 tokenId, bytes32 configRecordHash, bytes32 configHash, bytes32 sourceSnapshotHash, bytes32 rawSourceHash, (address registry, bytes32 registryCodeHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 schemaHash, bytes32 readSetHash, bytes32 registrationHash) selection, address[6] sources, bytes32[6] sourceCodeHashes) selection, (address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) entropy, bytes32 terminalAdmissionHash)[] samples))",
  "function referenceCount((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (uint256)",
  "function referenceAt((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint256 index) view returns (bytes32)",
  "function referenceLock((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bytes32 recordHash, uint64 revision, bytes32 actionId, uint64 lockedAt))",
  "function requireCurrent((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 hash, uint64 revision) view returns ((bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) r)",
  "function previewReference(((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 referenceId, bytes32 expectedHead, uint64 expectedRevision, bytes32 snapshotRecordHash, uint64 snapshotRevision, bytes32 expectedSourcesHash, (uint256 tokenId, uint256 collectionSerial, bytes32 metadataJSONHash, bytes32 htmlHash, uint32 htmlBytes, bytes animationHTML, bytes32 objectHash, bytes32 coverageHash, bytes32 sourceSha256, bytes32[2] repeatCaptureSha256, bytes32 environmentManifestHash, uint64 capturedAt)[] captures, (bytes32 objectHash, bytes32 coverageHash, bytes32 manifestHash, uint32 manifestBytes, string engineName, string engineVersion, bytes32 engineExecutableSha256, string toolchainName, string toolchainVersion, bytes32 toolchainSha256, string engineExecutablePath, string toolchainPath, (string path, uint64 byteSize, bytes32 sha256Digest)[] packageFiles, (string path, uint64 byteSize, bytes32 sha256Digest)[] platformPrerequisites, string operatingSystem, string operatingSystemVersion, string architecture, uint16 viewportWidth, uint16 viewportHeight, uint8 devicePixelRatio, string colorSpace, bool softwareRasterization, bytes32 captureProfile, string licenseNote) environment, string manifestURI, uint64 effectiveAt, bytes32 reasonHash) observation) p, address recorder) view returns (bytes32 sourceHash, bytes canonical)"
]);
const storeAbi = new Interface([
  "function chunk(bytes32) view returns (address pointer, uint32 length)"
]);
const schemaAbi = new Interface([
  "function document(bytes32 id) view returns ((bool exists, uint8 status, bytes32 declarationHash, (string name, uint8 kind, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, string uri, uint32 totalBytes) specification, bytes32[] chunkHashes))",
  "function documentBytes(bytes32 id) view returns (bytes payload)"
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
const outputAbi = new Interface([
  "function outputAt(bytes32 id, uint256 index) view returns (((uint256 tokenId, bytes32 metadataHash, bytes32 imageHash, bytes32 animationHash, bytes32 contentHash, bytes32 tokenDataHash) leaf, bytes32 selectionRowHash, bytes32 sourceFactsHash, bytes32 htmlHash, (address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) entropy, bytes32 terminalAdmissionHash))"
]);
const manifestAbi = new Interface([
  "function manifestRecord(bytes32 recordHash) view returns ((bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength))"
]);
const policyAbi = new Interface([
  "function tokenEntropyReadiness(uint256 tokenId) view returns ((address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) t)"
]);
const rendererAbi = new Interface([
  "function requireRetained(bytes32 key) view returns (address renderer, bytes32 runtimeHash)",
  "function registration(bytes32 key) view returns ((address renderer, (bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 rendererClass, bytes32 schemaHash, string schemaURI, string manifestURI, bytes32 manifestHash, uint32 maxJSONBytes, uint32 maxHTMLBytes, bool deprecated) manifest, bytes32 schemaDocument, bytes32 contextDocument, bytes32 manifestDocument, bytes32 analysisDocument, bytes32 goldenDocument))"
]);
const routerAbi = new Interface([
  "function supportsInterface(bytes4 id) view returns (bool)",
  "function scopedContentRootHead((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)) view returns (bytes32)",
  "function scopedContentRootRecord(bytes32) view returns ((((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 expectedPredecessor, bytes32 snapshotRecordHash, uint64 snapshotRevision, string manifestURI) publication, address snapshotHost, bytes32 snapshotCodeHash, bytes32 snapshotManifestHash, bytes32 snapshotSourceHash, bytes32 contentRoot, uint64 leafCount, bytes32 outputManifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt))",
  "function scopedPolicyContentRootBinding(bytes32 recordHash) view returns ((bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, bytes32 snapshotSchemaHash, bytes32 snapshotProfileHash, bytes32 snapshotCanonicalizationHash))",
  "function tokenJSON(uint256 tokenId) view returns (string)",
  "function tokenHTML(uint256 tokenId) view returns (string)"
]);
const eventAbi = new Interface([
  "event ReferenceEnvironmentPrepared(uint16 schemaVersion, bytes32 indexed environmentId, bytes32 contentHash, uint32 byteLength)",
  "event ReferenceInventoryPartPrepared(uint16 schemaVersion, bytes32 indexed partId, bool relative, uint16 rowCount, bytes32 contentHash, uint32 byteLength)",
  "event ReferenceInventoryAssembled(uint16 schemaVersion, bytes32 indexed inventoryId, bool relative, uint256 rowCount, bytes32 contentHash, uint32 byteLength)",
  "event ScopedPolicyReferencePublished(uint16 schemaVersion, bytes32 indexed scopeSubject, bytes32 indexed referenceId, bytes32 indexed recordHash, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) receipt, string manifestURI)"
]);

function deployment(input: ScopedPolicyReferenceV2Deployment): ScopedPolicyReferenceV2Deployment {
  keys(input, ["chainId", "core", "metadata", "reference", "linkedDependencies"]);
  keys(input.linkedDependencies, ["preparation", "source", "history"]);
  const value = {
    chainId: uint(input.chainId), core: codePin(input.core), metadata: codePin(input.metadata), reference: codePin(input.reference),
    linkedDependencies: { preparation: pinList(input.linkedDependencies.preparation), source: pinList(input.linkedDependencies.source),
      history: pinList(input.linkedDependencies.history) }
  };
  if (value.chainId === 0n) throw Error("Zero deployment chain");
  return freeze(value);
}
function coordinates(d: ScopedPolicyReferenceV2Deployment): ref.ScopedPolicyReferenceV2Coordinates {
  return { chainId: d.chainId, core: d.core.address, metadata: d.metadata.address, reference: d.reference.address };
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
async function context(p: Reader, d: ScopedPolicyReferenceV2Deployment, tag: number, full: boolean) {
  await runtime(p, d.reference, tag);
  for (const pin of d.linkedDependencies[full ? "source" : "preparation"]) await runtime(p, pin, tag);
  const deps = ref.normalizeScopedPolicyReferenceV2Dependencies(await read(p, d.reference.address, hostAbi, "dependencies", [], tag));
  equal([deps.chainId, deps.targets[0], deps.codeHashes[0], deps.targets[1], deps.codeHashes[1]],
    [d.chainId, d.core.address, d.core.codeHash, d.metadata.address, d.metadata.codeHash], "Reference constructor bindings differ");
  equal(await read(p, d.reference.address, hostAbi, "deploymentChainId", [], tag), d.chainId);
  equal(await read(p, d.reference.address, hostAbi, "scopedPolicyReferenceProfile", [], tag), ref.SCOPED_POLICY_REFERENCE_V2_PROFILE);
  for (const [method, expected] of [["core", deps.targets[0]], ["metadataHost", deps.targets[1]], ["metadataRouter", deps.targets[4]],
    ["snapshots", deps.targets[5]], ["archiveCoverage", deps.targets[6]]] as const) {
    equal(await read(p, d.reference.address, hostAbi, method, [], tag), expected, "Reference immutable binding differs");
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
export interface ScopedPolicyReferenceV2ChunkObservation {
  readonly hash: Hex;
  readonly pointer: Address;
  readonly byteLength: bigint;
}
async function retainedChunks(p: Reader, store: Address, payload: Hex, tag: number): Promise<readonly ScopedPolicyReferenceV2ChunkObservation[]> {
  const raw = bytes(payload, 524288);
  if (raw === "0x") throw Error("Empty retained payload");
  const result: ScopedPolicyReferenceV2ChunkObservation[] = [];
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
async function preparedBytes(p: Reader, host: Address, identity: Hex, tag: number): Promise<Hex | null> {
  try {
    return bytes(await read(p, host, hostAbi, "preparedFileInventory", [identity], tag), 524288);
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
  readonly chunks: readonly ScopedPolicyReferenceV2ChunkObservation[];
}
async function preparation(p: Reader, d: ScopedPolicyReferenceV2Deployment, deps: ref.ScopedPolicyReferenceV2Dependencies,
  plan: ref.ScopedPolicyReferenceV2Call, tag: number): Promise<PreparationEvidence> {
  const saved = plan.preparation;
  if (!saved) throw Error("Expected original preparation call");
  const original = await preparedBytes(p, d.reference.address, saved.id, tag);
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
  for (const item of prerequisites) equal(await preparedBytes(p, d.reference.address, item.identity, tag), item.canonical,
    "Original retained preparation prerequisite unavailable");
  return { kind: "preparation", retainedBefore: false, prerequisites,
    chunks: await retainedChunks(p, deps.targets[3], saved.canonical, tag) };
}
async function definitions(p: Reader, deps: ref.ScopedPolicyReferenceV2Dependencies, tag: number) {
  for (const item of ref.SCOPED_POLICY_REFERENCE_V2_DOCUMENTS) {
    const doc = await read<{ exists: boolean; status: bigint; specification: { name: string; kind: bigint;
      contentHash: Hex; totalBytes: bigint; canonicalizationId: Hex } }>(p, deps.targets[2], schemaAbi, "document", [item.id], tag, deps.readGas);
    const spec = doc.specification;
    if (!doc.exists || doc.status !== 0n || id(spec.name) !== item.id || spec.kind !== item.kind || spec.contentHash !== item.contentHash
      || spec.totalBytes !== item.byteLength || spec.canonicalizationId !== id("RAW_BYTES")) throw Error("Original ACTIVE RAW_BYTES definition differs");
    const raw = bytes(await read(p, deps.targets[2], schemaAbi, "documentBytes", [item.id], tag, deps.readGas), 65536);
    if (keccak256(raw) !== item.contentHash || BigInt((raw.length - 2) / 2) !== item.byteLength) throw Error("Definition bytes differ");
  }
}
const currentPairCapability = (() => {
  const fragment = coverageAbi.getFunction("currentReceiptPair")!;
  // Original IStreamExternalArtifactCurrentPair declares exactly this own method.
  return fragment.selector;
})();
async function snapshotSource(p: Reader, d: ScopedPolicyReferenceV2Deployment, deps: ref.ScopedPolicyReferenceV2Dependencies,
  publication: ref.ScopedPolicyReferenceV2Publication, tag: number) {
  const iface = pub.scopedPolicyPublicationV2Interface("snapshot");
  equal(await read(p, deps.targets[5], coverageAbi, "supportsInterface", [root.SCOPED_POLICY_ROOT_V2_SNAPSHOT_INTERFACE_ID], tag, deps.readGas), true);
  equal(await read(p, deps.targets[5], iface, "scopedPolicySnapshotProfile", [], tag, deps.readGas), pub.SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_PROFILE);
  equal(await read(p, deps.targets[4], routerAbi, "supportsInterface", [root.SCOPED_POLICY_ROOT_V2_INTERFACE_ID], tag, deps.readGas), true);
  equal(await read(p, deps.targets[6], coverageAbi, "core", [], tag, deps.readGas), d.core.address);
  equal(await read(p, deps.targets[6], coverageAbi, "supportsInterface", [currentPairCapability], tag, deps.readGas), true);
  const sourceDependencies = graph.normalizeScopedPolicyGraphV2SnapshotDependencies(await read(p, deps.targets[5], iface, "dependencies", [], tag, deps.readGas));
  equal(sourceDependencies.chainId, deps.chainId);
  equal(sourceDependencies.targets.slice(0, 5), deps.targets.slice(0, 5), "Snapshot first five targets differ");
  equal(sourceDependencies.codeHashes.slice(0, 5), deps.codeHashes.slice(0, 5), "Snapshot first five pins differ");
  for (let i = 0; i < 11; i++) await runtime(p, { address: sourceDependencies.targets[i]!, codeHash: sourceDependencies.codeHashes[i]! }, tag);
  const history = await inspectScopedPolicyPublicationV2History(p, { chainId: d.chainId, core: d.core.address, metadata: d.metadata.address,
    snapshot: { address: deps.targets[5], codeHash: deps.codeHashes[5] },
    checkpoint: { address: sourceDependencies.targets[7], codeHash: sourceDependencies.codeHashes[7] },
    output: { address: sourceDependencies.targets[8], codeHash: sourceDependencies.codeHashes[8] },
    linkedDependencies: d.linkedDependencies.source }, { kind: "snapshotRecord", recordHash: publication.observation.snapshotRecordHash }, { blockTag: tag });
  if (history.result.kind !== "snapshotRecord") throw Error("Unexpected retained snapshot result");
  const retained = history.result;
  equal(retained.publication.scope, publication.scope, "Snapshot full scope differs");
  equal([retained.receipt.recordHash, retained.receipt.revision], [publication.observation.snapshotRecordHash, publication.observation.snapshotRevision]);
  equal(await read(p, deps.targets[5], iface, "requireCurrent", [publication.scope, retained.receipt.recordHash, retained.receipt.revision], tag, deps.snapshotGas), retained.receipt,
    "Original current snapshot differs");
  return { dependencies: sourceDependencies, ...retained };
}
interface CoverageObservation {
  readonly saved: ref.ScopedPolicyReferenceV2Coverage;
  readonly currentPair: Readonly<Record<string, unknown>> | null;
}
async function coverage(p: Reader, deps: ref.ScopedPolicyReferenceV2Dependencies, coverageHash: Hex, artistId: Hex,
  objectHash: Hex, format: "zip" | "png", tag: number, current: boolean): Promise<CoverageObservation> {
  const host = deps.targets[6];
  const saved = ref.normalizeScopedPolicyReferenceV2Coverage(await read(p, host, coverageAbi, current ? "coverage" : "requireCoverage",
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
  const document = ref.SCOPED_POLICY_REFERENCE_V2_DOCUMENTS.find(item => item.id === id(format === "zip" ? "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1" : "STREAM_REFERENCE_PNG_OBJECT_V1"));
  if (!document) throw Error("Original capture schema unavailable");
  const catalog = ref.SCOPED_POLICY_REFERENCE_V2_DOCUMENTS.find(item => item.kind === 2n && item.id !== ref.SCOPED_POLICY_REFERENCE_V2_PROFILE_DOCUMENT)!;
  equal([object.canonicalizationId, object.schemaId, object.formatId, object.formatCatalogId, object.formatCatalogHash],
    [id("RAW_BYTES"), document.id, id(format === "zip" ? "IANA:application/zip" : "IANA:image/png"), catalog.id, catalog.contentHash], "Original ZIP/PNG object interpretation differs");
  return { saved, currentPair: pair };
}
async function sample(p: Reader, deps: ref.ScopedPolicyReferenceV2Dependencies, sourceDeps: pub.ScopedPolicyPublicationV2Dependencies,
  scope: ref.ScopedPolicyReferenceV2Scope, source: pub.ScopedPolicyPublicationV2Source, capture: ref.ScopedPolicyReferenceV2Capture,
  index: bigint, environmentHash: Hex, tag: number, timestamp: bigint, current: boolean) {
  const tokenId = uint(await read(p, sourceDeps.targets[5], membershipAbi, "scopeTokenAt", [scope, index], tag, deps.readGas));
  if (tokenId === 0n || tokenId !== capture.tokenId || index >= source.membership.tokenCount) throw Error("Authoritative first/last membership differs");
  const selection = pub.normalizeScopedPolicyPublicationV2TokenSelection(await read(p, sourceDeps.targets[6], sampleAbi, "selectionAt", [source.content.selectionId, index], tag, deps.readGas));
  const output = pub.normalizeScopedPolicyPublicationV2Output(await read(p, sourceDeps.targets[7], outputAbi, "outputAt", [source.outputs.checkpointHash, index], tag, deps.readGas));
  equal([selection.tokenId, output.leaf.tokenId], [tokenId, tokenId]);
  equal(output.selectionRowHash, pub.scopedPolicyPublicationV2SelectionRowHash(deps.chainId, deps.targets[0], deps.targets[4], selection));
  const html = bytes(capture.animationHTML, 40960);
  if (html === "0x" || BigInt((html.length - 2) / 2) !== capture.htmlBytes || keccak256(html) !== capture.htmlHash
    || sha256(html) !== capture.sourceSha256 || capture.capturedAt === 0n || capture.capturedAt > timestamp
    || capture.repeatCaptureSha256[0] === ZERO || capture.repeatCaptureSha256[0] !== capture.repeatCaptureSha256[1]
    || capture.environmentManifestHash !== environmentHash) throw Error("Original capture bytes/time/hash differs");
  equal([capture.metadataJSONHash, capture.htmlHash, output.htmlHash], [output.leaf.metadataHash, output.leaf.animationHash, capture.htmlHash]);
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
  const entropy = pub.normalizeScopedPolicyPublicationV2TokenReadiness(await read(p, sourceDeps.targets[10], policyAbi, "tokenEntropyReadiness", [tokenId], tag, deps.sourceGas));
  equal(entropy, output.entropy);
  equal([entropy.coordinator, entropy.coordinatorCodeHash], [coordinator, selection.sourceCodeHashes[3]]);
  if (entropy.terminal) {
    if (entropy.finalized || entropy.seed !== ZERO || entropy.renderRequirement !== 1n || output.terminalAdmissionHash === ZERO
      || !(entropy.status === 1n && entropy.mode === 0n || entropy.status === 2n && entropy.mode === 2n)) throw Error("Terminal entropy evidence differs");
  } else if (!entropy.finalized || entropy.status !== 5n || output.terminalAdmissionHash !== ZERO) throw Error("Finalized entropy evidence differs");
  const data = bytes(await read(p, deps.targets[0], coreAbi, "tokenData", [tokenId], tag, deps.sourceGas), 16384);
  equal(keccak256(data), output.leaf.tokenDataHash);
  const json = toUtf8Bytes(await read<string>(p, deps.targets[4], routerAbi, "tokenJSON", [tokenId], tag, deps.sourceGas));
  const actualHtml = toUtf8Bytes(await read<string>(p, deps.targets[4], routerAbi, "tokenHTML", [tokenId], tag, deps.sourceGas));
  if (json.length > 65536 || actualHtml.length > 40960 || BigInt(actualHtml.length) !== capture.htmlBytes
    || keccak256(json) !== output.leaf.metadataHash || keccak256(actualHtml) !== capture.htmlHash) throw Error("Actual render bytes differ");
  // Exact JSON/data embedding and capped nested execution remain original preview/call predicates.
  const retainedCoverage = await coverage(p, deps, capture.coverageHash, source.artist.artistId, capture.objectHash, "png", tag, current);
  equal(retainedCoverage.saved.sha256Digest, capture.repeatCaptureSha256[0], "Repeat PNG digest differs");
  const result: ref.ScopedPolicyReferenceV2Sample = { membershipIndex: index, selection, entropy,
    terminalAdmissionHash: output.terminalAdmissionHash, observation: { tokenId, collectionSerial: capture.collectionSerial,
      originalCoordinator: coordinator, seed: entropy.seed, tokenDataHash: output.leaf.tokenDataHash, tokenDataBytes: BigInt((data.length - 2) / 2),
      metadataJSONHash: output.leaf.metadataHash, htmlHash: capture.htmlHash, htmlBytes: capture.htmlBytes, captureCoverage: retainedCoverage.saved } };
  return { result, coverage: retainedCoverage };
}
async function sourceFacts(p: Reader, d: ScopedPolicyReferenceV2Deployment, deps: ref.ScopedPolicyReferenceV2Dependencies,
  publication: ref.ScopedPolicyReferenceV2Publication, tag: number, timestamp: bigint, current: boolean) {
  await definitions(p, deps, tag);
  const snapshot = await snapshotSource(p, d, deps, publication, tag);
  const source = snapshot.source;
  const scope = publication.scope;
  const key = hash(await read(p, deps.targets[4], routerAbi, "scopedContentRootHead", [scope], tag, deps.readGas));
  const record = root.normalizeScopedPolicyRootV2Record(await read(p, deps.targets[4], routerAbi, "scopedContentRootRecord", [key], tag, deps.sourceGas));
  const binding = root.normalizeScopedPolicyRootV2Binding(await read(p, deps.targets[4], routerAbi, "scopedPolicyContentRootBinding", [key], tag, deps.sourceGas));
  equal(binding, root.scopedPolicyRootV2BindingFromSnapshot(snapshot.dependencies, source, snapshot.receipt), "Original V2 root binding differs");
  const manifest = pub.normalizeScopedPolicyPublicationV2Manifest(await read(p, snapshot.dependencies.targets[8], manifestAbi, "manifestRecord",
    [snapshot.publication.outputManifestRecord], tag, deps.sourceGas));
  hash(snapshot.publication.outputManifestRecord);
  equal(manifest, source.outputs, "Original output record differs");
  equal(record.publication.scope, scope, "Root full scope differs");
  equal([record.publication.snapshotRecordHash, record.publication.snapshotRevision, record.snapshotHost, record.snapshotCodeHash,
    record.snapshotManifestHash, record.snapshotSourceHash, record.contentRoot, record.leafCount, record.outputManifestHash,
    record.artistId, record.bindingGeneration, record.bindingHash], [snapshot.receipt.recordHash, snapshot.receipt.revision, deps.targets[5],
    deps.codeHashes[5], snapshot.receipt.manifestHash, snapshot.receipt.sourceHash, source.outputs.contentRoot, source.membership.tokenCount,
    source.outputs.manifestHash, source.artist.artistId, source.artist.bindingGeneration, source.artist.bindingHash], "Root snapshot/source joins differ");
  if (record.contentRoot === ZERO || record.leafCount === 0n || record.publisher === ZERO_ADDRESS || ![7n, 8n].includes(record.authorizationClass)
    || record.grantRevision === 0n || record.artistConsent === ZERO || record.publishedAt === 0n || record.publishedAt > timestamp) throw Error("Root publication evidence incomplete");
  hash(record.routeHash);
  equal(root.scopedPolicyRootV2StateHash({ chainId: d.chainId, core: d.core.address, router: deps.targets[4], artistRegistry: source.artist.registry }, record, binding), record.stateHash);
  const count = source.membership.tokenCount;
  if (count === 0n || count > 0xffffffffffffffffn || publication.observation.captures.length !== (count === 1n ? 1 : 2)) throw Error("First/last capture count differs");
  const environment = publication.observation.environment;
  const environmentCoverage = await coverage(p, deps, environment.coverageHash, source.artist.artistId, environment.objectHash, "zip", tag, current);
  const samples: ref.ScopedPolicyReferenceV2Sample[] = [];
  const coverages: CoverageObservation[] = [environmentCoverage];
  for (let i = 0; i < publication.observation.captures.length; i++) {
    const observed = await sample(p, deps, snapshot.dependencies, scope, source, publication.observation.captures[i]!,
      i === 0 ? 0n : count - 1n, environment.manifestHash, tag, timestamp, current);
    samples.push(observed.result);
    coverages.push(observed.coverage);
  }
  const facts: ref.ScopedPolicyReferenceV2SourceFacts = {
    scopeSubject: graph.scopedPolicyGraphV2ScopeSubject(d.chainId, d.core.address, scope), snapshot: snapshot.receipt,
    snapshotSource: source, contentRootRecordHash: key, contentRoot: record, contentRootBinding: binding,
    environmentCoverage: environmentCoverage.saved, samples
  };
  ref.validateScopedPolicyReferenceV2Source(coordinates(d), deps, publication, facts, snapshot.dependencies);
  return { facts, coverages };
}
async function environmentBytes(p: Reader, d: ScopedPolicyReferenceV2Deployment, publication: ref.ScopedPolicyReferenceV2Publication, tag: number) {
  const environment = prepareReferenceEnvironment(d.chainId, d.reference.address, publication.observation.environment);
  const retained = await preparedBytes(p, d.reference.address, environment.environmentId, tag);
  if (retained !== null) equal(retained, environment.canonical, "Retained environment differs");
  else for (const item of [environment.packageInventory, environment.platformInventory]) {
    equal(await preparedBytes(p, d.reference.address, item.inventoryId, tag), item.canonical, "Environment original file inventories unavailable");
  }
  return environment.canonical;
}
async function candidate(p: Reader, d: ScopedPolicyReferenceV2Deployment, publication: ref.ScopedPolicyReferenceV2Publication,
  timestamp: bigint, tag: number) {
  const q = publication.observation;
  if (q.effectiveAt > timestamp || timestamp > 0xffffffffffffffffn) throw Error("Original publication time invalid");
  const prior = ref.normalizeScopedPolicyReferenceV2Receipt(await read(p, d.reference.address, hostAbi, "currentReference", [publication.scope], tag));
  const count = uint(await read(p, d.reference.address, hostAbi, "referenceCount", [publication.scope], tag));
  if (count > 65536n) throw Error("Reference history exceeds client read bound");
  if (prior.observation.recordHash === ZERO) {
    equal(ref.encodeScopedPolicyReferenceV2Receipt(prior), ("0x" + "00".repeat(672)), "Empty current receipt is nondefault");
    if (count !== 0n) throw Error("Missing nonempty reference head");
  } else {
    const original = await rpc(p, d.reference.address, hostAbi, "referenceRecord", [prior.observation.recordHash], tag);
    const previous = ref.normalizeScopedPolicyReferenceV2Publication(original[0] as ref.ScopedPolicyReferenceV2Publication);
    equal(previous.scope, publication.scope, "Prior reference full scope differs");
    equal(original[1], prior);
    equal(prior.observation.revision, count);
    equal(prior.scopeSubject, graph.scopedPolicyGraphV2ScopeSubject(d.chainId, d.core.address, publication.scope));
  }
  equal([prior.observation.recordHash, count], [q.expectedHead, q.expectedRevision], "Reference lineage changed");
  const lock = await read<ref.ScopedPolicyReferenceV2Lock>(p, d.reference.address, hostAbi, "referenceLock", [publication.scope], tag);
  if (lock.actionId !== ZERO) throw Error("Reference scope is locked");
  // The private reference-id map has no getter. Original preview/call checks reuse.
  return { prior, count, lock };
}
async function authority(p: Reader, deps: ref.ScopedPolicyReferenceV2Dependencies, cid: bigint, caller: Address, tag: number) {
  for (const cls of [3n, 8n] as const) {
    const values = await rpc(p, deps.targets[1], metadataAbi, "familyWriter", [cls === 3n ? cid : 0n, id("6529STREAM_RECORD_FAMILY_CURATOR_V1"), cls, caller], tag, undefined, deps.readGas);
    if (values[0] === true && values[1] !== 0n) return { authorizationClass: cls, grantRevision: uint(values[1], 64) };
  }
  throw Error("Original CURATOR publication grant unavailable");
}
export interface ScopedPolicyReferenceV2Preview {
  readonly deployment: ScopedPolicyReferenceV2Deployment;
  readonly observed: ScopedPolicyReferenceV2Block;
  readonly dependencies: ref.ScopedPolicyReferenceV2Dependencies;
  readonly publication: ref.ScopedPolicyReferenceV2Publication;
  readonly caller: Address;
  readonly receipt: ref.ScopedPolicyReferenceV2Receipt;
  readonly source: ref.ScopedPolicyReferenceV2SourceFacts;
  readonly sourceHash: Hex;
  readonly canonical: Hex;
  readonly environmentBytes: Hex;
  readonly prior: ref.ScopedPolicyReferenceV2Receipt;
  readonly count: bigint;
  readonly lock: ref.ScopedPolicyReferenceV2Lock;
  readonly storeAvailabilityChecked: false;
  readonly previewHash: Hex;
}
/** Zero expectedSourcesHash is permitted only for this actual original preview. */
export async function previewScopedPolicyReferenceV2(
  p: Reader,
  input: ScopedPolicyReferenceV2Deployment,
  inputCaller: Address,
  supplied: ref.ScopedPolicyReferenceV2Publication,
  options: { readonly blockTag: number }
): Promise<ScopedPolicyReferenceV2Preview> {
  const d = deployment(input), caller = address(inputCaller);
  const publication = ref.validateScopedPolicyReferenceV2Publication(supplied, "preview");
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag), observed = await chain(p, d.chainId, tag);
  const deps = await context(p, d, tag, true);
  const lineage = await candidate(p, d, publication, observed.timestamp, tag);
  const writer = await authority(p, deps, publication.scope.collectionId, caller, tag);
  const source = await sourceFacts(p, d, deps, publication, tag, observed.timestamp, false);
  const sourceHash = ref.scopedPolicyReferenceV2SourceHash(coordinates(d), deps, source.facts);
  const receipt = ref.scopedPolicyReferenceV2PreviewReceipt(coordinates(d), publication, caller, writer, sourceHash);
  const environment = await environmentBytes(p, d, publication, tag);
  const canonical = ref.scopedPolicyReferenceV2PayloadBytes(coordinates(d), publication, receipt, source.facts, environment);
  const original = await rpc(p, d.reference.address, hostAbi, "previewReference", [publication, caller], tag, caller);
  equal(original, [sourceHash, canonical], "Original preview source/canonical differs");
  await unchanged(p, observed);
  const value = { deployment: d, observed, dependencies: deps, publication, caller, receipt, source: source.facts, sourceHash,
    canonical, environmentBytes: environment, ...lineage, storeAvailabilityChecked: false as const };
  return freeze({ ...value, previewHash: fingerprint(value) });
}
interface PublicationEvidence {
  readonly kind: "publication";
  readonly preview: ScopedPolicyReferenceV2Preview;
  readonly payloadChunks: readonly ScopedPolicyReferenceV2ChunkObservation[];
  readonly publicationChunks: readonly ScopedPolicyReferenceV2ChunkObservation[];
}
export interface ScopedPolicyReferenceV2WorkflowCapture {
  readonly deployment: ScopedPolicyReferenceV2Deployment;
  readonly observed: ScopedPolicyReferenceV2Block;
  readonly dependencies: ref.ScopedPolicyReferenceV2Dependencies;
  readonly prepared: ref.ScopedPolicyReferenceV2Call;
  readonly stage: PreparationEvidence | PublicationEvidence;
  readonly captureHash: Hex;
}
export async function captureScopedPolicyReferenceV2(
  p: Reader,
  input: ScopedPolicyReferenceV2Deployment,
  inputCaller: Address,
  request: ref.ScopedPolicyReferenceV2Request,
  options: { readonly blockTag: number }
): Promise<ScopedPolicyReferenceV2WorkflowCapture> {
  const d = deployment(input), caller = address(inputCaller);
  const prepared = ref.prepareScopedPolicyReferenceV2Call(coordinates(d), caller, request);
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag), observed = await chain(p, d.chainId, tag);
  const deps = await context(p, d, tag, prepared.request.kind === "publishReference");
  let stage: PreparationEvidence | PublicationEvidence;
  if (prepared.request.kind === "publishReference") {
    const preview = await previewScopedPolicyReferenceV2(p, d, caller, prepared.request.publication, { blockTag: tag });
    equal(prepared.request.publication.observation.expectedSourcesHash, preview.sourceHash, "Expected source changed");
    stage = { kind: "publication", preview, payloadChunks: await retainedChunks(p, deps.targets[3], preview.canonical, tag),
      publicationChunks: await retainedChunks(p, deps.targets[3], ref.encodeScopedPolicyReferenceV2Publication(prepared.request.publication), tag) };
  } else stage = await preparation(p, d, deps, prepared, tag);
  await unchanged(p, observed);
  const value = { deployment: d, observed, dependencies: deps, prepared, stage };
  return freeze({ ...value, captureHash: fingerprint(value) });
}
function savedCapture(input: ScopedPolicyReferenceV2WorkflowCapture) {
  const saved = structuredClone(input);
  const { captureHash, ...body } = saved;
  equal(fingerprint(body), hash(captureHash), "Saved capture bytes changed");
  const d = deployment(saved.deployment);
  equal(ref.normalizeScopedPolicyReferenceV2Call(saved.prepared), saved.prepared);
  equal(saved.prepared.coordinates, coordinates(d), "Captured call deployment differs");
  if ((saved.prepared.request.kind === "publishReference") !== (saved.stage.kind === "publication")) throw Error("Captured stage differs");
  if (saved.stage.kind === "publication" && saved.prepared.request.kind === "publishReference") {
    equal([saved.stage.preview.publication, saved.stage.preview.caller, saved.stage.preview.deployment, saved.stage.preview.observed],
      [saved.prepared.request.publication, saved.prepared.caller, saved.deployment, saved.observed], "Captured publication preview differs");
  }
  return freeze(saved);
}
function comparable(c: ScopedPolicyReferenceV2WorkflowCapture) {
  const { observed: _observed, captureHash: _hash, stage, ...body } = c;
  if (stage.kind !== "publication") return { ...body, stage };
  const { observed: _block, previewHash: _previewHash, ...preview } = stage.preview;
  return { ...body, stage: { ...stage, preview } };
}
async function revalidate(p: Reader, saved: ScopedPolicyReferenceV2WorkflowCapture, tag: number) {
  if (tag < saved.observed.blockNumber) throw Error("Observation predates capture");
  await unchanged(p, saved.observed);
  const original = await captureScopedPolicyReferenceV2(p, saved.deployment, saved.prepared.caller, saved.prepared.request, { blockTag: saved.observed.blockNumber });
  equal(original, saved, "Saved original capture reconstruction differs");
  const current = tag === saved.observed.blockNumber ? original
    : await captureScopedPolicyReferenceV2(p, saved.deployment, saved.prepared.caller, saved.prepared.request, { blockTag: tag });
  equal(comparable(current), comparable(saved), "Reviewed source or preparation state changed; recapture");
  return current;
}
function completed(c: ScopedPolicyReferenceV2WorkflowCapture, timestamp: bigint): ref.ScopedPolicyReferenceV2Receipt {
  if (c.stage.kind !== "publication") throw Error("Expected publication stage");
  const preview = c.stage.preview, publication = preview.publication;
  if (timestamp === 0n || timestamp > 0xffffffffffffffffn || timestamp < publication.observation.effectiveAt
    || publication.observation.captures.some(row => row.capturedAt > timestamp)) throw Error("Mined original timestamps invalid");
  const fields = { ...preview.receipt, observation: { ...preview.receipt.observation, recordedAt: timestamp,
    payloadHash: keccak256(preview.canonical) as Hex, payloadBytes: BigInt((preview.canonical.length - 2) / 2) } };
  const recordHash = ref.scopedPolicyReferenceV2RecordHash(c.prepared.coordinates, publication, fields);
  const recordChainHash = ref.scopedPolicyReferenceV2ChainHash(c.prepared.coordinates, publication.scope,
    preview.prior.observation.recordChainHash, fields.observation.revision, recordHash);
  return ref.normalizeScopedPolicyReferenceV2Receipt({ ...fields, observation: { ...fields.observation, recordHash, recordChainHash } });
}
export async function simulateScopedPolicyReferenceV2(
  p: Reader,
  input: ScopedPolicyReferenceV2WorkflowCapture,
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

async function historical(p: Reader, d: ScopedPolicyReferenceV2HistoryDeployment, inputKey: Hex, tag: number) {
  const key = hash(inputKey);
  await runtime(p, d.reference, tag);
  for (const pin of d.linkedDependencies) await runtime(p, pin, tag);
  const deps = ref.normalizeScopedPolicyReferenceV2Dependencies(await read(p, d.reference.address, hostAbi, "dependencies", [], tag));
  equal([deps.chainId, deps.targets[0], deps.targets[1]], [d.chainId, d.core, d.metadata]);
  const coords = { chainId: d.chainId, core: d.core, metadata: d.metadata, reference: d.reference.address };
  const raw = await rpc(p, d.reference.address, hostAbi, "referenceRecord", [key], tag);
  const publication = ref.normalizeScopedPolicyReferenceV2Publication(raw[0] as ref.ScopedPolicyReferenceV2Publication);
  const receipt = ref.normalizeScopedPolicyReferenceV2Receipt(raw[1] as ref.ScopedPolicyReferenceV2Receipt);
  const r = receipt.observation, q = publication.observation;
  ref.validateScopedPolicyReferenceV2Publication(publication, "publish");
  equal([r.recordHash, r.collectionId, r.referenceId, r.predecessor, r.revision, r.snapshotRecordHash, r.snapshotRevision,
    r.effectiveAt, r.reasonHash, receipt.scopeSubject], [key, q.collectionId, q.referenceId, q.expectedHead, q.expectedRevision + 1n,
    q.snapshotRecordHash, q.snapshotRevision, q.effectiveAt, q.reasonHash, graph.scopedPolicyGraphV2ScopeSubject(d.chainId, d.core, publication.scope)],
    "Retained publication lineage differs");
  if (r.recordedAt === 0n || r.recordedAt < q.effectiveAt || r.recorder === ZERO_ADDRESS || ![3n, 8n].includes(r.authorizationClass)
    || r.grantRevision === 0n || r.payloadHash === ZERO || r.sourcesHash === ZERO) throw Error("Incomplete retained receipt");
  equal([r.schemaHash, r.profileHash, r.canonicalizationHash], [ref.SCOPED_POLICY_REFERENCE_V2_SCHEMA_HASH,
    ref.SCOPED_POLICY_REFERENCE_V2_PROFILE_HASH, ref.SCOPED_POLICY_REFERENCE_V2_CANONICALIZATION_HASH]);
  const canonical = bytes(await read(p, d.reference.address, hostAbi, "referencePayload", [key], tag), 524288);
  const decoded = ref.decodeScopedPolicyReferenceV2Payload(canonical);
  equal([decoded.chainId, decoded.reference], [d.chainId, d.reference.address]);
  const source = ref.normalizeScopedPolicyReferenceV2SourceFacts(await read(p, d.reference.address, hostAbi, "referenceSource", [key], tag));
  equal(source, decoded.source, "Retained source getter differs from payload");
  equal(ref.scopedPolicyReferenceV2PayloadBytes(coords, publication, receipt, source, decoded.environmentBytes), canonical, "Canonical retained payload differs");
  equal([keccak256(canonical), BigInt((canonical.length - 2) / 2), ref.scopedPolicyReferenceV2SourceHash(coords, deps, source)],
    [r.payloadHash, r.payloadBytes, r.sourcesHash]);
  equal(q.expectedSourcesHash, r.sourcesHash);
  equal(ref.scopedPolicyReferenceV2RecordHash(coords, publication, receipt), key, "Original record hash differs");
  let previousChain = ZERO;
  if (r.predecessor !== ZERO) {
    const before = await rpc(p, d.reference.address, hostAbi, "referenceRecord", [r.predecessor], tag);
    const previousPublication = ref.normalizeScopedPolicyReferenceV2Publication(before[0] as ref.ScopedPolicyReferenceV2Publication);
    const previousReceipt = ref.normalizeScopedPolicyReferenceV2Receipt(before[1] as ref.ScopedPolicyReferenceV2Receipt);
    equal(previousPublication.scope, publication.scope, "Historical predecessor full scope differs");
    equal([previousReceipt.observation.recordHash, previousReceipt.observation.revision], [r.predecessor, q.expectedRevision]);
    equal(ref.scopedPolicyReferenceV2RecordHash(coords, previousPublication, previousReceipt), r.predecessor);
    previousChain = hash(previousReceipt.observation.recordChainHash);
  } else if (q.expectedRevision !== 0n) throw Error("Missing historical predecessor");
  equal(ref.scopedPolicyReferenceV2ChainHash(coords, publication.scope, previousChain, r.revision, key), r.recordChainHash);
  ref.authenticateScopedPolicyReferenceV2History(coords, deps, publication, receipt, canonical, previousChain);
  return { publication, receipt, source, canonical, environmentBytes: decoded.environmentBytes, dependencies: deps };
}
export async function inspectScopedPolicyReferenceV2History(
  p: Reader,
  input: ScopedPolicyReferenceV2HistoryDeployment,
  inputKey: Hex,
  options: { readonly blockTag: number }
) {
  keys(input, ["chainId", "core", "metadata", "reference", "linkedDependencies"]);
  keys(options, ["blockTag"]);
  const d = { chainId: uint(input.chainId), core: address(input.core), metadata: address(input.metadata), reference: codePin(input.reference),
    linkedDependencies: pinList(input.linkedDependencies) };
  const key = hash(inputKey), tag = number(options.blockTag), observed = await chain(p, d.chainId, tag);
  const result = await historical(p, d, key, tag);
  if (result.receipt.observation.recordedAt > observed.timestamp) throw Error("Future retained receipt");
  await unchanged(p, observed);
  return freeze({ deployment: d, observed, ...result, currentnessChecked: false as const, finalityEstablished: false as const });
}
export async function inspectScopedPolicyReferenceV2Current(
  p: Reader,
  input: ScopedPolicyReferenceV2Deployment,
  suppliedScope: ref.ScopedPolicyReferenceV2Scope,
  options: { readonly blockTag: number }
) {
  const d = deployment(input), scope = graph.validateScopedPolicyGraphV2Scope(suppliedScope);
  keys(options, ["blockTag"]);
  const tag = number(options.blockTag), observed = await chain(p, d.chainId, tag);
  const deps = await context(p, d, tag, true);
  const current = ref.normalizeScopedPolicyReferenceV2Receipt(await read(p, d.reference.address, hostAbi, "currentReference", [scope], tag));
  if (current.observation.recordHash === ZERO) {
    equal(ref.encodeScopedPolicyReferenceV2Receipt(current), "0x" + "00".repeat(672), "Empty current receipt is nondefault");
    throw Error("No current reference exists for the requested scope");
  }
  const stored = await historical(p, { chainId: d.chainId, core: d.core.address, metadata: d.metadata.address, reference: d.reference,
    linkedDependencies: d.linkedDependencies.history }, current.observation.recordHash, tag);
  equal(stored.publication.scope, scope, "Current full scope differs");
  equal(stored.receipt, current);
  const actual = await sourceFacts(p, d, deps, stored.publication, tag, observed.timestamp, true);
  equal(actual.facts, stored.source, "Current source differs from retained source");
  equal(ref.scopedPolicyReferenceV2SourceHash(coordinates(d), deps, actual.facts), current.observation.sourcesHash);
  equal(await read(p, d.reference.address, hostAbi, "requireCurrent", [scope, current.observation.recordHash, current.observation.revision], tag), current,
    "Original current reference differs");
  await unchanged(p, observed);
  return freeze({ deployment: d, observed, ...stored, coverage: actual.coverages,
    currentnessChecked: true as const, finalityEstablished: false as const });
}

const safe = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool success)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)"
]);

export type ScopedPolicyReferenceV2ReceiptOptions = Readonly<
  { execution: "direct" } | { execution: "safe"; expectedSafeTxHash: Hex }
>;

interface CopiedLog {
  readonly address: Address;
  readonly topics: readonly Hex[];
  readonly data: Hex;
  readonly index: number;
}

async function transport(provider: ReceiptReader, saved: ScopedPolicyReferenceV2WorkflowCapture,
  transactionHash: Hex, options: ScopedPolicyReferenceV2ReceiptOptions) {
  const raw = await provider.getTransactionReceipt(transactionHash);
  if (!raw || raw.status !== 1 || !same(raw.hash, transactionHash)) throw Error("Missing or failed receipt");
  const blockNumber = number(raw.blockNumber);
  const blockHash = hash(raw.blockHash);
  const from = address(raw.from);
  const to = address(raw.to);
  if (blockNumber <= saved.observed.blockNumber) throw Error("Receipt must follow captured block");
  if (!Array.isArray(raw.logs) || raw.logs.length > MAX_LOGS) throw Error("Receipt log limit exceeded");
  let priorIndex = -1;
  let total = 0;
  const logs: CopiedLog[] = raw.logs.map(log => {
    const index = number(log.index);
    if (index <= priorIndex || log.removed !== false || !same(log.transactionHash, transactionHash)
      || log.blockNumber !== blockNumber || !same(log.blockHash, blockHash)) throw Error("Receipt log identity/order differs");
    priorIndex = index;
    if (!Array.isArray(log.topics) || log.topics.length > 4) throw Error("Malformed log topics");
    const data = bytes(log.data, 65536);
    total += (data.length - 2) / 2;
    if (total > 1_048_576) throw Error("Receipt aggregate log bound exceeded");
    return { address: address(log.address), topics: log.topics.map((topic: string) => hash(topic, true)), data, index };
  });
  const tx = await provider.getTransaction(transactionHash);
  if (!tx || !same(tx.hash, transactionHash) || !same(tx.from, from) || !same(tx.to, to)
    || tx.blockNumber !== blockNumber || !same(tx.blockHash, blockHash)
    || tx.chainId !== saved.deployment.chainId) throw Error("Transaction envelope differs");
  const data = bytes(tx.data, MAX_CALL + 16384);
  const call = saved.prepared.call;
  const caller = saved.prepared.caller;
  if (tx.value !== 0n) throw Error("Outer value must be zero");
  let safeIndex = -1;
  if (options.execution === "direct") {
    if (!same(from, caller) || !same(to, call.to) || !same(data, call.data)) throw Error("Direct caller/target/data differs");
  } else {
    if (!same(to, caller)) throw Error("Safe is not the actual publication caller");
    const decoded = safe.decodeFunctionData("execTransaction", data);
    if (!same(safe.encodeFunctionData("execTransaction", decoded), data) || !same(decoded.to, call.to)
      || decoded.value !== 0n || !same(decoded.data, call.data) || decoded.operation !== 0n) throw Error("Safe inner CALL differs");
    const executionTopics = [safe.getEvent("ExecutionSuccess")!.topicHash, safe.getEvent("ExecutionFailure")!.topicHash];
    const matches = logs.filter(log => same(log.address, caller) && executionTopics.some(topic => same(topic, log.topics[0])));
    if (matches.length !== 1) throw Error("Expected exactly one Safe execution event");
    requireSafeExecution({ status: 1, logs: logs.map(log => ({ address: log.address, topics: [...log.topics], data: log.data })) },
      caller, options.expectedSafeTxHash);
    safeIndex = matches[0]!.index;
  }
  const observed = await header(provider, blockNumber);
  if (!same(observed.blockHash, blockHash)) throw Error("Receipt block changed");
  return { observed, logs, safeIndex };
}

function events(logs: readonly CopiedLog[], target: Address, iface: Interface, name: string) {
  const fragment = iface.getEvent(name)!;
  return logs.filter(log => same(log.address, target) && same(log.topics[0], fragment.topicHash)).map(row => {
    const decoded = iface.decodeEventLog(fragment, row.data, [...row.topics]);
    const encoded = iface.encodeEventLog(fragment, decoded);
    equal(encoded.topics.map(topic => topic.toLowerCase()), row.topics, `${name} topics differ`);
    if (!same(encoded.data, row.data)) throw Error(`Noncanonical ${name}`);
    return { index: row.index, fields: Object.fromEntries(fragment.inputs.map((param, index) => [param.name, plain(param, decoded[index])])) };
  });
}


function one(logs: readonly CopiedLog[], target: Address, name: string, expected?: readonly unknown[]) {
  const matches = events(logs, target, eventAbi, name);
  if (matches.length !== 1) throw Error("Expected exactly one " + name);
  const result = matches[0]!;
  if (expected) {
    const fragment = eventAbi.getEvent(name)!;
    equal(result.fields, Object.fromEntries(fragment.inputs.map((field, i) => [field.name, expected[i]])), name + " differs");
  }
  return result;
}
const preparationEvents = ["ReferenceEnvironmentPrepared", "ReferenceInventoryPartPrepared", "ReferenceInventoryAssembled"] as const;
async function preparationReceipt(p: ReceiptReader, saved: ScopedPolicyReferenceV2WorkflowCapture,
  transport_: Awaited<ReturnType<typeof transport>>) {
  if (saved.stage.kind !== "preparation" || !saved.prepared.preparation) throw Error("Expected preparation capture");
  const d = saved.deployment, tag = transport_.observed.blockNumber, q = saved.prepared.request;
  const expected = saved.prepared.preparation;
  const deps = await context(p, d, tag, false);
  equal([deps.targets, deps.codeHashes], [saved.dependencies.targets, saved.dependencies.codeHashes]);
  equal(await preparedBytes(p, d.reference.address, expected.id, tag), expected.canonical, "Mined preparation bytes differ");
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
    if (name === expectedName) last = one(transport_.logs, d.reference.address, name, args).index;
    else if (events(transport_.logs, d.reference.address, eventAbi, name).length) throw Error("Unexpected preparation event");
  }
  if (events(transport_.logs, d.reference.address, eventAbi, "ScopedPolicyReferencePublished").length) throw Error("Preparation cannot publish a reference");
  if (transport_.safeIndex >= 0 && transport_.safeIndex <= last) throw Error("Safe success precedes preparation");
  return { kind: "preparation" as const, identity: expected.id, canonical: expected.canonical,
    priorRetained: saved.stage.retainedBefore, receiptHadPreparationEvent: expectedName !== null };
}
async function publicationReceipt(p: ReceiptReader, saved: ScopedPolicyReferenceV2WorkflowCapture,
  transport_: Awaited<ReturnType<typeof transport>>) {
  if (saved.stage.kind !== "publication" || saved.prepared.request.kind !== "publishReference") throw Error("Expected reference publication");
  const d = saved.deployment, tag = transport_.observed.blockNumber;
  await runtime(p, d.reference, tag);
  for (const pin of [...d.linkedDependencies.source, ...d.linkedDependencies.history]) await runtime(p, pin, tag);
  for (let i = 0; i < 7; i++) await runtime(p, { address: saved.dependencies.targets[i]!, codeHash: saved.dependencies.codeHashes[i]! }, tag);
  const expected = completed(saved, transport_.observed.timestamp);
  const q = saved.prepared.request.publication;
  const published = one(transport_.logs, d.reference.address, "ScopedPolicyReferencePublished",
    [2n, expected.scopeSubject, q.observation.referenceId, expected.observation.recordHash, expected, q.observation.manifestURI]);
  for (const name of preparationEvents) if (events(transport_.logs, d.reference.address, eventAbi, name).length) throw Error("Publication cannot prepare a new environment");
  if (transport_.safeIndex >= 0 && transport_.safeIndex <= published.index) throw Error("Safe success precedes publication");
  const retained = await historical(p, { chainId: d.chainId, core: d.core.address, metadata: d.metadata.address,
    reference: d.reference, linkedDependencies: d.linkedDependencies.history }, expected.observation.recordHash, tag);
  equal(retained.publication, q);
  equal(retained.receipt, expected);
  equal(retained.canonical, saved.stage.preview.canonical);
  equal(retained.source, saved.stage.preview.source);
  equal(await read(p, d.reference.address, hostAbi, "currentReference", [q.scope], tag), expected, "End-block reference head differs");
  equal(await read(p, d.reference.address, hostAbi, "referenceCount", [q.scope], tag), expected.observation.revision);
  equal(await read(p, d.reference.address, hostAbi, "referenceAt", [q.scope, q.observation.expectedRevision], tag), expected.observation.recordHash);
  equal(await retainedChunks(p, saved.dependencies.targets[3], retained.canonical, tag), saved.stage.payloadChunks);
  equal(await retainedChunks(p, saved.dependencies.targets[3], ref.encodeScopedPolicyReferenceV2Publication(q), tag), saved.stage.publicationChunks);
  return { kind: "publication" as const, ...retained, publicationEventIndex: published.index };
}
/** Conservative preceding/end-block attribution; later same-block head progress requires separate review. */
export async function reconcileScopedPolicyReferenceV2Receipt(
  p: ReceiptReader,
  input: ScopedPolicyReferenceV2WorkflowCapture,
  inputHash: Hex,
  supplied: ScopedPolicyReferenceV2ReceiptOptions
) {
  const saved = savedCapture(input), transactionHash = hash(inputHash);
  if (supplied.execution !== "direct" && supplied.execution !== "safe") throw Error("Unknown execution transport");
  keys(supplied, supplied.execution === "safe" ? ["execution", "expectedSafeTxHash"] : ["execution"]);
  const options: ScopedPolicyReferenceV2ReceiptOptions = supplied.execution === "safe"
    ? { execution: "safe", expectedSafeTxHash: hash(supplied.expectedSafeTxHash) } : { execution: "direct" };
  const mined = await transport(p, saved, transactionHash, options);
  const prior = await revalidate(p, saved, mined.observed.blockNumber - 1);
  const result = prior.stage.kind === "preparation" ? await preparationReceipt(p, prior, mined) : await publicationReceipt(p, prior, mined);
  await unchanged(p, mined.observed);
  return freeze({ transactionHash, observed: mined.observed, prior, result, execution: options.execution,
    attribution: "exact-preceding-and-end-block-observation" as const, finalityEstablished: false as const });
}
async function localState(p: Reader, saved: ScopedPolicyReferenceV2WorkflowCapture, tag: number) {
  const host = saved.deployment.reference.address;
  if (saved.stage.kind === "preparation") return preparedBytes(p, host, saved.prepared.preparation!.id, tag);
  return { receipt: await read(p, host, hostAbi, "currentReference", [saved.stage.preview.publication.scope], tag),
    count: await read(p, host, hostAbi, "referenceCount", [saved.stage.preview.publication.scope], tag) };
}
export async function observeScopedPolicyReferenceV2Refusal(
  p: Reader,
  input: ScopedPolicyReferenceV2WorkflowCapture,
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
