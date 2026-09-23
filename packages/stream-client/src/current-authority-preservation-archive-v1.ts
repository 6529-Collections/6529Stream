import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, sha256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import * as inventory from "./current-authority-preservation-inventory-v1.js";

/** Original immutable-STOP archive profile. Archive liveness and source currentness are separate. */
export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SOURCE = "e93cb09169dd90fe3b63cb32e93fe1a8955a0ee1";
/** Client allocation bounds, not original item-count limits. */
export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_MAX_BYTES = 2097152;
export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_MAX_ROWS = 8192;

export interface CurrentAuthorityPreservationArchiveV1Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly archive: Address;
  readonly scopeKind: CurrentAuthorityPreservationArchiveV1Kind;
}

export type CurrentAuthorityPreservationArchiveV1Item = inventory.CurrentAuthorityPreservationInventoryV1Item;
export type CurrentAuthorityPreservationArchiveV1Segment = inventory.CurrentAuthorityPreservationInventoryV1Segment;
export type CurrentAuthorityPreservationArchiveV1InventoryEvidence = inventory.CurrentAuthorityPreservationInventoryV1Evidence;

export interface CurrentAuthorityPreservationArchiveV1Dependencies {
  readonly targets: readonly [Address, Address, Address, Address, Address, Address];
  readonly codeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex];
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly archiveGas: bigint;
}

export interface CurrentAuthorityPreservationArchiveV1Proof {
  readonly backend: bigint;
  readonly coverageHash: Hex;
  readonly objectHash: Hex;
}

export interface CurrentAuthorityPreservationArchiveV1Admission {
  readonly proof: CurrentAuthorityPreservationArchiveV1Proof;
  readonly originalBundleHash: Hex;
  readonly immutablePartsHash: Hex;
  readonly externalOriginal: CurrentAuthorityPreservationArchiveV1ExternalCoverage;
  readonly onchainOriginal: CurrentAuthorityPreservationArchiveV1OnchainCoverage;
}

export interface CurrentAuthorityPreservationArchiveV1ExternalCoverage {
  readonly coverageHash: Hex;
  readonly objectHash: Hex;
  readonly artistId: Hex;
  readonly contentHash: Hex;
  readonly sha256Digest: Hex;
  readonly arweaveDataRoot: Hex;
  readonly byteSize: bigint;
  readonly firstFamilyRecordHash: Hex;
  readonly secondFamilyRecordHash: Hex;
  readonly firstReceiptHash: Hex;
  readonly secondReceiptHash: Hex;
  readonly firstFixityHash: Hex;
  readonly secondFixityHash: Hex;
  readonly checkpointHash: Hex;
  readonly profileHash: Hex;
}

export interface CurrentAuthorityPreservationArchiveV1OnchainCoverage {
  readonly completionHash: Hex;
  readonly artifactHash: Hex;
  readonly artistId: Hex;
  readonly schemaId: Hex;
  readonly canonicalizationId: Hex;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
  readonly chunkCount: bigint;
  readonly firstFamilyRecordHash: Hex;
  readonly secondFamilyRecordHash: Hex;
  readonly validationEpoch: bigint;
  readonly evidenceChainHash: Hex;
}

export interface CurrentAuthorityPreservationArchiveV1Progress {
  readonly segmentIndex: bigint;
  readonly segmentItemIndex: bigint;
  readonly itemCount: bigint;
  readonly nextLink: Hex;
  readonly segmentChainHash: Hex;
  readonly evidenceChainHash: Hex;
  readonly environmentHash: Hex;
  readonly complete: boolean;
}

export interface CurrentAuthorityPreservationArchiveV1Refresh {
  readonly environmentHash: Hex;
  readonly nextIndex: bigint;
  readonly currentObservationChain: Hex;
  readonly complete: boolean;
}

export interface CurrentAuthorityPreservationArchiveV1ScopedEvidence {
  readonly scope: CurrentAuthorityPreservationArchiveV1Scope;
  readonly coverage: CurrentAuthorityPreservationArchiveV1CollectionEvidence;
}
export type CurrentAuthorityPreservationArchiveV1Scope = inventory.CurrentAuthorityPreservationInventoryV1Scope;

export interface CurrentAuthorityPreservationArchiveV1CollectionEvidence {
  readonly inventoryPlan: Hex;
  readonly renderCriticalEvidenceHash: Hex;
  readonly itemCount: bigint;
  readonly evidenceChainHash: Hex;
  readonly bundleCoverageHash: Hex;
}

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_DEPENDENCIES_TUPLE = "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)";

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_PROOF_TUPLE = "(uint8 backend, bytes32 coverageHash, bytes32 objectHash)";

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ADMISSION_TUPLE = "((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal)";

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_PROGRESS_TUPLE = "(uint64 segmentIndex, uint64 segmentItemIndex, uint64 itemCount, bytes32 nextLink, bytes32 segmentChainHash, bytes32 evidenceChainHash, bytes32 environmentHash, bool complete)";

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_REFRESH_TUPLE = "(bytes32 environmentHash, uint64 nextIndex, bytes32 currentObservationChain, bool complete)";

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPED_EVIDENCE_TUPLE = "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage)";

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_COLLECTION_EVIDENCE_TUPLE = "(bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash)";

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_EXTERNAL_COVERAGE_TUPLE = "(bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash)";

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ONCHAIN_COVERAGE_TUPLE = "(bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash)";

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ITEM_TUPLE = inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ITEM_TUPLE;
export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SEGMENT_TUPLE = inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SEGMENT_TUPLE;
export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPE_TUPLE = inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPE_TUPLE;

export type CurrentAuthorityPreservationArchiveV1Kind = "collection" | "scoped";
export type CurrentAuthorityPreservationArchiveV1Evidence = CurrentAuthorityPreservationArchiveV1CollectionEvidence | CurrentAuthorityPreservationArchiveV1ScopedEvidence;

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_COLLECTION_ABI = Object.freeze([
  "error InvalidArchiveOrigin()",
  "error InvalidInventorySegment()",
  "error InventoryIncomplete()",
  "error InventoryRead(address target)",
  "error InventorySourceChanged()",
  "event BundleCoverageCompleted(bytes32 indexed inventoryPlan, bytes32 indexed bundleCoverageHash, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) evidence)",
  "event BundleCoverageStarted(bytes32 indexed inventoryPlan, bytes32 indexed renderCriticalEvidenceHash)",
  "event BundleItemAdmitted(bytes32 indexed inventoryPlan, uint64 indexed index, bytes32 itemHash, ((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal) admission)",
  "event BundleRefreshAdvanced(bytes32 indexed inventoryPlan, bytes32 indexed refreshId, uint64 nextIndex, bytes32 observationChain, bool complete)",
  "function INVENTORY_PROFILE() view returns (bytes32)",
  "function PROFILE() view returns (bytes32)",
  "function admittedItem(bytes32 id, uint64 index) view returns ((uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash), ((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal))",
  "function admittedOriginHash(bytes32 id, uint64 index) view returns (bytes32)",
  "function artifactCoverage() view returns (address)",
  "function authorityDependencies() view returns ((address resolver, bytes32 resolverCodeHash, uint256 resolverGas))",
  "function beginCoverage(bytes32 id)",
  "function beginRefresh(bytes32 id) returns (bytes32 key)",
  "function bundleEvidence(bytes32 id) view returns ((bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash))",
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function coverEmptySegment(bytes32 id)",
  "function coverNext(bytes32 id, (uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash) item, bytes32 nextLink, (uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof)",
  "function dependencies() view returns ((address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas))",
  "function dependencyHash() view returns (bytes32)",
  "function deploymentChainId() view returns (uint256)",
  "function externalCoverage() view returns (address)",
  "function inventoryCodeHash() view returns (bytes32)",
  "function metadataCodeHash() view returns (bytes32)",
  "function metadataHost() view returns (address)",
  "function originDependencies() view returns ((address worker, bytes32 workerCodeHash, uint256 originGas, bytes32 profile))",
  "function originProfile() pure returns (bytes32)",
  "function preservationPolicyBundleArchiveProfile() pure returns (bytes32)",
  "function progress(bytes32 id) view returns ((uint64 segmentIndex, uint64 segmentItemIndex, uint64 itemCount, bytes32 nextLink, bytes32 segmentChainHash, bytes32 evidenceChainHash, bytes32 environmentHash, bool complete))",
  "function refresh(bytes32 key) view returns ((bytes32 environmentHash, uint64 nextIndex, bytes32 currentObservationChain, bool complete))",
  "function refreshNext(bytes32 id, uint64 expectedIndex)",
  "function renderCriticalInventory() view returns (address)",
  "function requireCoverage(bytes32 id, bytes32 expectedHash) view returns ((bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) result)",
  "function requireFullCurrentCoverage(bytes32 id) view returns ((bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash))",
  "function supportsInterface(bytes4 id) pure returns (bool)"
]);
export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_COLLECTION_PROFILE = id("6529STREAM_CURRENT_AUTHORITY_PRESERVATION_POLICY_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1") as Hex;

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPED_ABI = Object.freeze([
  "error InvalidArchiveOrigin()",
  "error InvalidInventorySegment()",
  "error InvalidMetadataScope()",
  "error InventoryIncomplete()",
  "error InventoryRead(address target)",
  "error InventorySourceChanged()",
  "event ScopedBundleCoverageCompleted(uint16 schemaVersion, bytes32 indexed inventoryPlan, bytes32 indexed bundleCoverageHash, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage) evidence)",
  "event ScopedBundleCoverageStarted(uint16 schemaVersion, bytes32 indexed inventoryPlan, bytes32 indexed renderCriticalEvidenceHash)",
  "event ScopedBundleItemAdmitted(uint16 schemaVersion, bytes32 indexed inventoryPlan, uint64 indexed index, bytes32 itemHash, ((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal) admission)",
  "event ScopedBundleRefreshAdvanced(uint16 schemaVersion, bytes32 indexed inventoryPlan, bytes32 indexed refreshId, uint64 nextIndex, bytes32 observationChain, bool complete)",
  "function INVENTORY_PROFILE() view returns (bytes32)",
  "function PROFILE() view returns (bytes32)",
  "function admittedItem(bytes32 id, uint64 index) view returns ((uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash), ((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal))",
  "function admittedOriginHash(bytes32 id, uint64 index) view returns (bytes32)",
  "function artifactCoverage() view returns (address)",
  "function authorityDependencies() view returns ((address resolver, bytes32 resolverCodeHash, uint256 resolverGas))",
  "function beginCoverage(bytes32 id)",
  "function beginRefresh(bytes32 id) returns (bytes32 key)",
  "function bundleEvidence(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage))",
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function coverEmptySegment(bytes32 id)",
  "function coverNext(bytes32 id, (uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash) item, bytes32 nextLink, (uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof)",
  "function dependencies() view returns ((address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas))",
  "function dependencyHash() view returns (bytes32)",
  "function deploymentChainId() view returns (uint256)",
  "function externalCoverage() view returns (address)",
  "function inventoryCodeHash() view returns (bytes32)",
  "function metadataCodeHash() view returns (bytes32)",
  "function metadataHost() view returns (address)",
  "function originDependencies() view returns ((address worker, bytes32 workerCodeHash, uint256 originGas, bytes32 profile))",
  "function originProfile() pure returns (bytes32)",
  "function progress(bytes32 id) view returns ((uint64 segmentIndex, uint64 segmentItemIndex, uint64 itemCount, bytes32 nextLink, bytes32 segmentChainHash, bytes32 evidenceChainHash, bytes32 environmentHash, bool complete))",
  "function refresh(bytes32 key) view returns ((bytes32 environmentHash, uint64 nextIndex, bytes32 currentObservationChain, bool complete))",
  "function refreshNext(bytes32 id, uint64 expectedIndex)",
  "function renderCriticalInventory() view returns (address)",
  "function requireCoverage((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 id, bytes32 expectedHash) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage) result)",
  "function requireFullCurrentCoverage(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage))",
  "function scopedPreservationPolicyBundleArchiveProfile() pure returns (bytes32)",
  "function supportsInterface(bytes4 id) pure returns (bool)"
]);
export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPED_PROFILE = id("6529STREAM_CURRENT_AUTHORITY_SCOPED_PRESERVATION_POLICY_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1") as Hex;

const enumFields: Readonly<Record<string, Readonly<Record<string, number>>>> = {
  [ParamType.from(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPE_TUPLE).format("full")]: { scopeType: 4 },
};
const coder = AbiCoder.defaultAbiCoder();
const ZERO = ZeroHash as Hex;

function exact(value: unknown, keys: readonly string[], label: string): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Reflect.ownKeys(value).length !== keys.length || keys.some(key => !Object.hasOwn(value, key))) {
    throw Error(`${label}: missing or unknown fields`);
  }
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`);
  return value;
}

function address(value: unknown, required = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (required && result === ZeroAddress) throw Error("Expected nonzero address");
  return result;
}

function bytes(value: unknown, fixed?: number): Hex {
  if (typeof value !== "string" || !isHexString(value, fixed ?? true)
    || (value.length - 2) / 2 > CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_MAX_BYTES) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}

function nonzero(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === ZERO) throw Error("Expected nonzero commitment");
  return result;
}

function list(value: unknown, fixed?: number): readonly unknown[] {
  if (!Array.isArray(value) || value.length > CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_MAX_ROWS
    || (fixed !== undefined && value.length !== fixed)
    || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.hasOwn(value, i))) {
    throw Error("Expected dense bounded array");
  }
  return value;
}

function valueOf(type: ParamType, value: unknown, decoded = false, enumMaximum?: number): unknown {
  if (type.baseType === "tuple") {
    if (!decoded) exact(value, type.components!.map(field => field.name), "Tuple");
    const enums = enumFields[ParamType.from({
      type: "tuple", components: type.components!.map(field => JSON.parse(field.format("json"))),
    }).format("full")];
    return Object.freeze(Object.fromEntries(type.components!.map((field, i) => [field.name,
      valueOf(field, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[field.name],
        decoded, enums?.[field.name])])));
  }
  if (type.baseType === "array") {
    const rows = list(decoded ? Array.from(value as readonly unknown[]) : value,
      type.arrayLength! < 0 ? undefined : type.arrayLength!);
    return Object.freeze(rows.map(row => valueOf(type.arrayChildren!, row, decoded, enumMaximum)));
  }
  if (type.type.startsWith("uint")) {
    const result = uint(value, Number(type.type.slice(4)));
    if (enumMaximum !== undefined && result > BigInt(enumMaximum)) throw Error("Unknown original enum value");
    return result;
  }
  if (type.type === "address") return address(value);
  if (type.type.startsWith("bytes")) return bytes(value, type.type === "bytes" ? undefined : Number(type.type.slice(5)));
  if (type.type === "string") {
    if (typeof value !== "string" || /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(value)
      || toUtf8Bytes(value).length > CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_MAX_BYTES) throw Error("Invalid UTF8 text or bound");
    return value;
  }
  if (type.type === "bool" && typeof value === "boolean") return value;
  throw Error(`Invalid ABI value ${type.type}`);
}

function normalized<T>(tuple: string, value: unknown): T {
  return valueOf(ParamType.from(tuple), value) as T;
}

function encode(tuple: string, value: unknown): Hex {
  return bytes(coder.encode([tuple], [normalized(tuple, value)]));
}

function decode<T>(tuple: string, value: Hex): T {
  const raw = bytes(value);
  const result = valueOf(ParamType.from(tuple), coder.decode([tuple], raw)[0], true) as T;
  if (encode(tuple, result) !== raw) throw Error("Noncanonical ABI encoding");
  return result;
}

function hash(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}

function stable(value: unknown): string {
  return JSON.stringify(value, (_, v: unknown) => typeof v === "bigint" ? { uint: v.toString() }
    : v && typeof v === "object" && !Array.isArray(v)
      ? Object.fromEntries(Object.entries(v).sort(([a], [b]) => a.localeCompare(b))) : v);
}


export function normalizeCurrentAuthorityPreservationArchiveV1Dependencies(value: CurrentAuthorityPreservationArchiveV1Dependencies): CurrentAuthorityPreservationArchiveV1Dependencies {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_DEPENDENCIES_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationArchiveV1Dependencies(value: CurrentAuthorityPreservationArchiveV1Dependencies): Hex {
  return encode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_DEPENDENCIES_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1Dependencies(value: Hex): CurrentAuthorityPreservationArchiveV1Dependencies {
  return decode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_DEPENDENCIES_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationArchiveV1Proof(value: CurrentAuthorityPreservationArchiveV1Proof): CurrentAuthorityPreservationArchiveV1Proof {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_PROOF_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationArchiveV1Proof(value: CurrentAuthorityPreservationArchiveV1Proof): Hex {
  return encode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_PROOF_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1Proof(value: Hex): CurrentAuthorityPreservationArchiveV1Proof {
  return decode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_PROOF_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationArchiveV1Admission(value: CurrentAuthorityPreservationArchiveV1Admission): CurrentAuthorityPreservationArchiveV1Admission {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ADMISSION_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationArchiveV1Admission(value: CurrentAuthorityPreservationArchiveV1Admission): Hex {
  return encode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ADMISSION_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1Admission(value: Hex): CurrentAuthorityPreservationArchiveV1Admission {
  return decode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ADMISSION_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationArchiveV1Progress(value: CurrentAuthorityPreservationArchiveV1Progress): CurrentAuthorityPreservationArchiveV1Progress {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_PROGRESS_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationArchiveV1Progress(value: CurrentAuthorityPreservationArchiveV1Progress): Hex {
  return encode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_PROGRESS_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1Progress(value: Hex): CurrentAuthorityPreservationArchiveV1Progress {
  return decode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_PROGRESS_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationArchiveV1Refresh(value: CurrentAuthorityPreservationArchiveV1Refresh): CurrentAuthorityPreservationArchiveV1Refresh {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_REFRESH_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationArchiveV1Refresh(value: CurrentAuthorityPreservationArchiveV1Refresh): Hex {
  return encode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_REFRESH_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1Refresh(value: Hex): CurrentAuthorityPreservationArchiveV1Refresh {
  return decode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_REFRESH_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationArchiveV1ScopedEvidence(value: CurrentAuthorityPreservationArchiveV1ScopedEvidence): CurrentAuthorityPreservationArchiveV1ScopedEvidence {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPED_EVIDENCE_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationArchiveV1ScopedEvidence(value: CurrentAuthorityPreservationArchiveV1ScopedEvidence): Hex {
  return encode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPED_EVIDENCE_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1ScopedEvidence(value: Hex): CurrentAuthorityPreservationArchiveV1ScopedEvidence {
  return decode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPED_EVIDENCE_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationArchiveV1CollectionEvidence(value: CurrentAuthorityPreservationArchiveV1CollectionEvidence): CurrentAuthorityPreservationArchiveV1CollectionEvidence {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_COLLECTION_EVIDENCE_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationArchiveV1CollectionEvidence(value: CurrentAuthorityPreservationArchiveV1CollectionEvidence): Hex {
  return encode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_COLLECTION_EVIDENCE_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1CollectionEvidence(value: Hex): CurrentAuthorityPreservationArchiveV1CollectionEvidence {
  return decode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_COLLECTION_EVIDENCE_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationArchiveV1ExternalCoverage(value: CurrentAuthorityPreservationArchiveV1ExternalCoverage): CurrentAuthorityPreservationArchiveV1ExternalCoverage {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_EXTERNAL_COVERAGE_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationArchiveV1ExternalCoverage(value: CurrentAuthorityPreservationArchiveV1ExternalCoverage): Hex {
  return encode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_EXTERNAL_COVERAGE_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1ExternalCoverage(value: Hex): CurrentAuthorityPreservationArchiveV1ExternalCoverage {
  return decode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_EXTERNAL_COVERAGE_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationArchiveV1OnchainCoverage(value: CurrentAuthorityPreservationArchiveV1OnchainCoverage): CurrentAuthorityPreservationArchiveV1OnchainCoverage {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ONCHAIN_COVERAGE_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationArchiveV1OnchainCoverage(value: CurrentAuthorityPreservationArchiveV1OnchainCoverage): Hex {
  return encode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ONCHAIN_COVERAGE_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1OnchainCoverage(value: Hex): CurrentAuthorityPreservationArchiveV1OnchainCoverage {
  return decode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ONCHAIN_COVERAGE_TUPLE, value);
}



export type CurrentAuthorityPreservationArchiveV1OriginDependencies = inventory.CurrentAuthorityPreservationInventoryV1OriginDependencies;
export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ORIGIN_DEPENDENCIES_TUPLE = inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_DEPENDENCIES_TUPLE;
export const normalizeCurrentAuthorityPreservationArchiveV1OriginDependencies = inventory.normalizeCurrentAuthorityPreservationInventoryV1OriginDependencies;
export const encodeCurrentAuthorityPreservationArchiveV1OriginDependencies = inventory.encodeCurrentAuthorityPreservationInventoryV1OriginDependencies;
export const decodeCurrentAuthorityPreservationArchiveV1OriginDependencies = inventory.decodeCurrentAuthorityPreservationInventoryV1OriginDependencies;
export type CurrentAuthorityPreservationArchiveV1AuthorityDependencies = inventory.CurrentAuthorityPreservationInventoryV1AuthorityDependencies;
export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_AUTHORITY_DEPENDENCIES_TUPLE = inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_DEPENDENCIES_TUPLE;
export const normalizeCurrentAuthorityPreservationArchiveV1AuthorityDependencies = inventory.normalizeCurrentAuthorityPreservationInventoryV1AuthorityDependencies;
export const encodeCurrentAuthorityPreservationArchiveV1AuthorityDependencies = inventory.encodeCurrentAuthorityPreservationInventoryV1AuthorityDependencies;
export const decodeCurrentAuthorityPreservationArchiveV1AuthorityDependencies = inventory.decodeCurrentAuthorityPreservationInventoryV1AuthorityDependencies;
export type CurrentAuthorityPreservationArchiveV1Origin = inventory.CurrentAuthorityPreservationInventoryV1Origin;
export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ORIGIN_TUPLE = inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_TUPLE;
export const normalizeCurrentAuthorityPreservationArchiveV1Origin = inventory.normalizeCurrentAuthorityPreservationInventoryV1Origin;
export const encodeCurrentAuthorityPreservationArchiveV1Origin = inventory.encodeCurrentAuthorityPreservationInventoryV1Origin;
export const decodeCurrentAuthorityPreservationArchiveV1Origin = inventory.decodeCurrentAuthorityPreservationInventoryV1Origin;
export type CurrentAuthorityPreservationArchiveV1RecordOrigin = inventory.CurrentAuthorityPreservationInventoryV1RecordOrigin;
export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_RECORD_ORIGIN_TUPLE = inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RECORD_ORIGIN_TUPLE;
export const normalizeCurrentAuthorityPreservationArchiveV1RecordOrigin = inventory.normalizeCurrentAuthorityPreservationInventoryV1RecordOrigin;
export const encodeCurrentAuthorityPreservationArchiveV1RecordOrigin = inventory.encodeCurrentAuthorityPreservationInventoryV1RecordOrigin;
export const decodeCurrentAuthorityPreservationArchiveV1RecordOrigin = inventory.decodeCurrentAuthorityPreservationInventoryV1RecordOrigin;
export type CurrentAuthorityPreservationArchiveV1AuthorityCapture = inventory.CurrentAuthorityPreservationInventoryV1Capture;
export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_AUTHORITY_CAPTURE_TUPLE = inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_CAPTURE_TUPLE;
export const normalizeCurrentAuthorityPreservationArchiveV1AuthorityCapture = inventory.normalizeCurrentAuthorityPreservationInventoryV1Capture;
export const encodeCurrentAuthorityPreservationArchiveV1AuthorityCapture = inventory.encodeCurrentAuthorityPreservationInventoryV1Capture;
export const decodeCurrentAuthorityPreservationArchiveV1AuthorityCapture = inventory.decodeCurrentAuthorityPreservationInventoryV1Capture;

const RAW = id("RAW_BYTES") as Hex;
const JCS = id("RFC8785_JCS") as Hex;
const intrinsic = (kind: bigint): boolean => kind === 6n || kind === 7n || kind === 8n || kind === 9n || kind === 11n;

function applicability(item: CurrentAuthorityPreservationArchiveV1Item): void {
  if ([item.objectHash, item.originalCoverageHash, item.schemaId, item.formatId, item.catalogId, item.catalogHash]
    .some(value => value !== ZERO)) throw Error("Applicability row contains object/catalog fields");
  if (item.kind === 7n) {
    if (item.byteSize !== 0n || item.algorithm !== 0n || item.canonicalizationId !== ZERO
      || item.digest !== "0x" || item.uri !== "") throw Error("Malformed ABSENT row");
  } else if (item.kind === 9n) {
    if (item.byteSize !== 0n || item.algorithm !== 1n || item.canonicalizationId !== RAW
      || item.uri !== "" || item.digest !== keccak256("0x")) throw Error("Malformed EMPTY_BYTES row");
  } else if (item.kind === 11n) {
    if (item.byteSize !== 0n || item.algorithm !== 2n || item.canonicalizationId !== RAW
      || item.uri === "" || item.digest !== sha256("0x")) throw Error("Malformed EMPTY_PACKAGE_MEMBER row");
  } else if (item.algorithm !== 2n || item.canonicalizationId !== RAW || item.digest.length !== 66
    || item.uri === "" || (item.byteSize === 0n && item.digest !== sha256("0x"))) {
    throw Error("Malformed NATIVE_OS_PREREQUISITE row");
  }
}

/** Structural correspondence eligibility only; original archive/state readers prove the object. */
export function validateCurrentAuthorityPreservationArchiveV1Proof(
  item: CurrentAuthorityPreservationArchiveV1Item,
  proof: CurrentAuthorityPreservationArchiveV1Proof,
): CurrentAuthorityPreservationArchiveV1Proof {
  const row = inventory.normalizeCurrentAuthorityPreservationInventoryV1Item(item);
  const p = normalizeCurrentAuthorityPreservationArchiveV1Proof(proof);
  nonzero(row.role); address(row.source, true); nonzero(row.sourceRecord);
  if (intrinsic(row.kind)) {
    if (p.backend !== 0n || p.objectHash !== ZERO || p.coverageHash !== ZERO) throw Error("Intrinsic row requires canonical no-proof");
    if (row.kind === 6n) {
      if (row.sourceIndex !== 1n || row.algorithm !== 1n || row.canonicalizationId !== RAW) throw Error("Malformed STATE_BUNDLE row");
    } else applicability(row);
  } else {
    if ((p.backend !== 1n && p.backend !== 2n) || (p.backend === 1n && row.kind === 10n)
      || (p.backend === 2n && row.kind === 5n)) throw Error("Unsupported archive backend for item kind");
    nonzero(p.coverageHash); nonzero(p.objectHash);
    if ((row.objectHash !== ZERO && row.objectHash !== p.objectHash)
      || (row.originalCoverageHash !== ZERO && row.originalCoverageHash !== p.coverageHash)) throw Error("Proof original object/coverage differs");
    if (row.digest.length !== 66 || (row.algorithm !== 1n && row.algorithm !== 2n)
      || (p.backend === 2n && row.algorithm !== 1n)
      || (row.kind !== 5n && row.kind !== 10n && row.canonicalizationId !== RAW && row.canonicalizationId !== JCS
        && !currentAuthorityPreservationArchiveV1SupportedAbiCorrespondence(row))) {
      throw Error("Unsupported original inventory correspondence");
    }
  }
  return p;
}

export interface CurrentAuthorityPreservationArchiveV1Correspondence {
  readonly contentHash: Hex;
  readonly sha256Digest: Hex;
  readonly canonicalizationId: Hex;
  readonly byteSize: bigint;
}

export function validateCurrentAuthorityPreservationArchiveV1Correspondence(
  item: CurrentAuthorityPreservationArchiveV1Item,
  value: CurrentAuthorityPreservationArchiveV1Correspondence,
): CurrentAuthorityPreservationArchiveV1Item {
  const row = inventory.normalizeCurrentAuthorityPreservationInventoryV1Item(item);
  exact(value, ["contentHash", "sha256Digest", "canonicalizationId", "byteSize"], "Object correspondence");
  const size = uint(value.byteSize, 64), canon = bytes(value.canonicalizationId, 32);
  const keccak = bytes(value.contentHash, 32), sha = bytes(value.sha256Digest, 32);
  if (row.digest.length !== 66 || row.canonicalizationId !== canon || size === 0n
    || (row.byteSize !== 0n && row.byteSize !== size)
    || (row.kind !== 5n && row.kind !== 10n && canon !== RAW && canon !== JCS
      && !currentAuthorityPreservationArchiveV1SupportedAbiCorrespondence(row))) throw Error("Object correspondence differs");
  const expected = row.algorithm === 1n ? keccak : row.algorithm === 2n ? sha : ZERO;
  if (expected === ZERO || row.digest !== expected) throw Error("Unsupported algorithm or mismatched object digest");
  return row;
}

function empty<T>(tuple: string): T {
  const type = ParamType.from(tuple);
  return decode<T>(tuple, `0x${"00".repeat(type.components!.length * 32)}` as Hex);
}

export function currentAuthorityPreservationArchiveV1IntrinsicAdmission(
  item: CurrentAuthorityPreservationArchiveV1Item,
  proof: CurrentAuthorityPreservationArchiveV1Proof,
  immutablePartsHash: Hex = ZERO,
): CurrentAuthorityPreservationArchiveV1Admission {
  const row = inventory.normalizeCurrentAuthorityPreservationInventoryV1Item(item);
  const p = validateCurrentAuthorityPreservationArchiveV1Proof(row, proof);
  if (!intrinsic(row.kind)) throw Error("Item requires original archive admission");
  const parts = bytes(immutablePartsHash, 32);
  if (row.kind !== 6n && parts !== ZERO) throw Error("Incorrect intrinsic parts commitment");
  const bundle = row.kind === 6n
    ? hash(["bytes32", CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ITEM_TUPLE, "bytes32"], [id("STATE_RETAINED_ORIGINAL_AUTHORIZATION"), row, parts])
    : hash(["bytes32", CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ITEM_TUPLE], [id("EXPLICIT_INVENTORY_APPLICABILITY"), row]);
  return Object.freeze({ proof: p, originalBundleHash: bundle, immutablePartsHash: parts,
    externalOriginal: empty<CurrentAuthorityPreservationArchiveV1ExternalCoverage>(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_EXTERNAL_COVERAGE_TUPLE),
    onchainOriginal: empty<CurrentAuthorityPreservationArchiveV1OnchainCoverage>(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ONCHAIN_COVERAGE_TUPLE) });
}

/** Checks the supplied retained Admission, without asserting original archive-byte or current-pair readback. */
export function validateCurrentAuthorityPreservationArchiveV1Admission(
  artistId: Hex,
  item: CurrentAuthorityPreservationArchiveV1Item,
  admission: CurrentAuthorityPreservationArchiveV1Admission,
): CurrentAuthorityPreservationArchiveV1Admission {
  const artist = nonzero(artistId), row = inventory.normalizeCurrentAuthorityPreservationInventoryV1Item(item);
  const a = normalizeCurrentAuthorityPreservationArchiveV1Admission(admission);
  validateCurrentAuthorityPreservationArchiveV1Proof(row, a.proof);
  nonzero(a.originalBundleHash);
  if (intrinsic(row.kind)) {
    if (encodeCurrentAuthorityPreservationArchiveV1Admission(a) !== encodeCurrentAuthorityPreservationArchiveV1Admission(
      currentAuthorityPreservationArchiveV1IntrinsicAdmission(row, a.proof, a.immutablePartsHash))) throw Error("Intrinsic admission differs");
  } else if (a.proof.backend === 1n) {
    const c = a.externalOriginal;
    if (c.coverageHash !== a.proof.coverageHash || c.objectHash !== a.proof.objectHash || c.artistId !== artist
      || a.immutablePartsHash !== ZERO
      || encodeCurrentAuthorityPreservationArchiveV1OnchainCoverage(a.onchainOriginal) !== encodeCurrentAuthorityPreservationArchiveV1OnchainCoverage(
        empty<CurrentAuthorityPreservationArchiveV1OnchainCoverage>(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ONCHAIN_COVERAGE_TUPLE))) throw Error("External admission fields differ");
    [c.firstReceiptHash, c.secondReceiptHash, c.firstFixityHash, c.secondFixityHash].forEach(nonzero);
    validateCurrentAuthorityPreservationArchiveV1Correspondence(row, { contentHash: c.contentHash, sha256Digest: c.sha256Digest,
      canonicalizationId: row.canonicalizationId, byteSize: c.byteSize });
  } else {
    const c = a.onchainOriginal;
    if (c.completionHash !== a.proof.coverageHash || c.artifactHash !== a.proof.objectHash || c.artistId !== artist
      || (row.schemaId !== ZERO && row.schemaId !== c.schemaId)
      || encodeCurrentAuthorityPreservationArchiveV1ExternalCoverage(a.externalOriginal) !== encodeCurrentAuthorityPreservationArchiveV1ExternalCoverage(
        empty<CurrentAuthorityPreservationArchiveV1ExternalCoverage>(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_EXTERNAL_COVERAGE_TUPLE))) throw Error("Onchain admission fields differ");
    validateCurrentAuthorityPreservationArchiveV1Correspondence(row, { contentHash: c.contentHash, sha256Digest: ZERO,
      canonicalizationId: c.canonicalizationId, byteSize: c.byteLength });
  }
  return a;
}

export function validateCurrentAuthorityPreservationArchiveV1NextItem(
  progress: CurrentAuthorityPreservationArchiveV1Progress,
  segment: CurrentAuthorityPreservationArchiveV1Segment,
  item: CurrentAuthorityPreservationArchiveV1Item,
  nextLink: Hex,
): void {
  const p = normalizeCurrentAuthorityPreservationArchiveV1Progress(progress);
  const s = inventory.validateCurrentAuthorityPreservationInventoryV1Segment(segment);
  if (p.complete || inventory.currentAuthorityPreservationInventoryV1Link(s.key, s.itemCount, p.segmentItemIndex, item, nextLink) !== p.nextLink) {
    throw Error("Item does not match the original next occurrence");
  }
}

export function validateCurrentAuthorityPreservationArchiveV1EmptySegment(
  progress: CurrentAuthorityPreservationArchiveV1Progress,
  segment: CurrentAuthorityPreservationArchiveV1Segment,
): void {
  const p = normalizeCurrentAuthorityPreservationArchiveV1Progress(progress);
  const s = inventory.validateCurrentAuthorityPreservationInventoryV1Segment(segment);
  if (p.complete || s.itemCount !== 0n || s.firstLink !== ZERO || p.segmentItemIndex !== 0n || p.nextLink !== ZERO) {
    throw Error("Original empty segment is not ready");
  }
}


export interface CurrentAuthorityPreservationArchiveV1Artifact {
  readonly artistId: Hex;
  readonly schemaId: Hex;
  readonly canonicalizationId: Hex;
  readonly hashAlgorithm: bigint;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
  readonly chunkHashes: readonly Hex[];
  readonly chunkLengths: readonly bigint[];
}

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ARTIFACT_TUPLE = "(bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, uint16 hashAlgorithm, bytes32 contentHash, uint64 byteLength, bytes32[] chunkHashes, uint32[] chunkLengths)";
export function normalizeCurrentAuthorityPreservationArchiveV1Artifact(value: CurrentAuthorityPreservationArchiveV1Artifact): CurrentAuthorityPreservationArchiveV1Artifact {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ARTIFACT_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationArchiveV1Artifact(value: CurrentAuthorityPreservationArchiveV1Artifact): Hex {
  return encode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ARTIFACT_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1Artifact(value: Hex): CurrentAuthorityPreservationArchiveV1Artifact {
  return decode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ARTIFACT_TUPLE, value);
}

export interface CurrentAuthorityPreservationArchiveV1ObjectIdentity {
  readonly artistId: Hex;
  readonly schemaId: Hex;
  readonly canonicalizationId: Hex;
  readonly contentHash: Hex;
  readonly sha256Digest: Hex;
  readonly arweaveDataRoot: Hex;
  readonly byteSize: bigint;
  readonly formatId: Hex;
  readonly formatCatalogId: Hex;
  readonly formatCatalogHash: Hex;
}

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_OBJECT_IDENTITY_TUPLE = "(bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 formatId, bytes32 formatCatalogId, bytes32 formatCatalogHash)";
export function normalizeCurrentAuthorityPreservationArchiveV1ObjectIdentity(value: CurrentAuthorityPreservationArchiveV1ObjectIdentity): CurrentAuthorityPreservationArchiveV1ObjectIdentity {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_OBJECT_IDENTITY_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationArchiveV1ObjectIdentity(value: CurrentAuthorityPreservationArchiveV1ObjectIdentity): Hex {
  return encode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_OBJECT_IDENTITY_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1ObjectIdentity(value: Hex): CurrentAuthorityPreservationArchiveV1ObjectIdentity {
  return decode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_OBJECT_IDENTITY_TUPLE, value);
}

export interface CurrentAuthorityPreservationArchiveV1CurrentPair {
  readonly objectHash: Hex;
  readonly artistId: Hex;
  readonly contentHash: Hex;
  readonly sha256Digest: Hex;
  readonly arweaveDataRoot: Hex;
  readonly byteSize: bigint;
  readonly firstFamilyRecordHash: Hex;
  readonly secondFamilyRecordHash: Hex;
  readonly firstReceiptHash: Hex;
  readonly secondReceiptHash: Hex;
  readonly firstFixityHash: Hex;
  readonly secondFixityHash: Hex;
  readonly checkpointHash: Hex;
  readonly profileHash: Hex;
}

export const CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_CURRENT_PAIR_TUPLE = "(bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash)";
export function normalizeCurrentAuthorityPreservationArchiveV1CurrentPair(value: CurrentAuthorityPreservationArchiveV1CurrentPair): CurrentAuthorityPreservationArchiveV1CurrentPair {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_CURRENT_PAIR_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationArchiveV1CurrentPair(value: CurrentAuthorityPreservationArchiveV1CurrentPair): Hex {
  return encode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_CURRENT_PAIR_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1CurrentPair(value: Hex): CurrentAuthorityPreservationArchiveV1CurrentPair {
  return decode(CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_CURRENT_PAIR_TUPLE, value);
}

export function currentAuthorityPreservationArchiveV1CurrentPairHash(
  original: CurrentAuthorityPreservationArchiveV1ExternalCoverage,
  current: CurrentAuthorityPreservationArchiveV1CurrentPair,
): Hex {
  const o = normalizeCurrentAuthorityPreservationArchiveV1ExternalCoverage(original);
  const c = normalizeCurrentAuthorityPreservationArchiveV1CurrentPair(current);
  for (const key of Object.keys(c) as (keyof CurrentAuthorityPreservationArchiveV1CurrentPair)[]) {
    if (key !== "firstFixityHash" && key !== "secondFixityHash" && c[key] !== o[key]) {
      throw Error("Current pair changes an immutable original field");
    }
  }
  nonzero(c.firstFixityHash); nonzero(c.secondFixityHash);
  return keccak256(encodeCurrentAuthorityPreservationArchiveV1CurrentPair(c)) as Hex;
}

export function currentAuthorityPreservationArchiveV1ExternalOriginalHash(
  dependencies: CurrentAuthorityPreservationArchiveV1Dependencies,
  original: CurrentAuthorityPreservationArchiveV1ExternalCoverage,
  originalBundleHashes: readonly [Hex, Hex, Hex, Hex, Hex],
): Hex {
  const d = normalizeCurrentAuthorityPreservationArchiveV1Dependencies(dependencies);
  const hashes = list(originalBundleHashes, 5).map(value => bytes(value, 32));
  return hash(["address", "bytes32", CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_EXTERNAL_COVERAGE_TUPLE, "bytes32[5]"],
    [d.targets[4], d.codeHashes[4], normalizeCurrentAuthorityPreservationArchiveV1ExternalCoverage(original), hashes]);
}

export function currentAuthorityPreservationArchiveV1OnchainOriginalHash(
  dependencies: CurrentAuthorityPreservationArchiveV1Dependencies,
  original: CurrentAuthorityPreservationArchiveV1OnchainCoverage,
  artifact: CurrentAuthorityPreservationArchiveV1Artifact,
  immutablePartsHash: Hex,
  originalPartsChain: Hex,
): Hex {
  const d = normalizeCurrentAuthorityPreservationArchiveV1Dependencies(dependencies);
  return hash(["address", "bytes32", CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ONCHAIN_COVERAGE_TUPLE,
    CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ARTIFACT_TUPLE, "bytes32", "bytes32"],
  [d.targets[3], d.codeHashes[3], normalizeCurrentAuthorityPreservationArchiveV1OnchainCoverage(original),
    normalizeCurrentAuthorityPreservationArchiveV1Artifact(artifact), bytes(immutablePartsHash, 32), bytes(originalPartsChain, 32)]);
}

export function currentAuthorityPreservationArchiveV1PartChain(
  previous: Hex, index: bigint, pointer: Address, codeHash: Hex, chunkHash: Hex, chunkLength: bigint,
): Hex {
  return hash(["bytes32", "uint32", "address", "bytes32", "bytes32", "uint32"],
    [bytes(previous, 32), uint(index, 32), address(pointer), bytes(codeHash, 32), bytes(chunkHash, 32), uint(chunkLength, 32)]);
}

export function currentAuthorityPreservationArchiveV1OriginalPartChain(previous: Hex, index: bigint, originalBundleHash: Hex): Hex {
  return hash(["bytes32", "uint32", "bytes32"], [bytes(previous, 32), uint(index, 32), bytes(originalBundleHash, 32)]);
}

export interface CurrentAuthorityPreservationArchiveV1StateParts {
  readonly source: Address;
  readonly sourceCodeHash: Hex;
  readonly sourceRecord: Hex;
  readonly pointer: Address;
  readonly pointerCodeHash: Hex;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
  readonly blockNumber: bigint;
}

export function currentAuthorityPreservationArchiveV1StatePartsHash(value: CurrentAuthorityPreservationArchiveV1StateParts): Hex {
  exact(value, ["source", "sourceCodeHash", "sourceRecord", "pointer", "pointerCodeHash", "contentHash", "byteLength", "blockNumber"], "Retained state parts");
  return hash(["address", "bytes32", "bytes32", "address", "bytes32", "bytes32", "uint32", "uint64"],
    [address(value.source), bytes(value.sourceCodeHash, 32), bytes(value.sourceRecord, 32), address(value.pointer),
      bytes(value.pointerCodeHash, 32), bytes(value.contentHash, 32), uint(value.byteLength, 32), uint(value.blockNumber, 64)]);
}


function kind(value: unknown): CurrentAuthorityPreservationArchiveV1Kind {
  if (value !== "collection" && value !== "scoped") throw Error("Unknown archive host kind");
  return value;
}
function domain(scopeKind: CurrentAuthorityPreservationArchiveV1Kind, suffix: string): Hex {
  return id("6529STREAM_CURRENT_AUTHORITY_" + (kind(scopeKind) === "scoped" ? "SCOPED_" : "")
    + "PRESERVATION_POLICY_BUNDLE_" + suffix) as Hex;
}
export function currentAuthorityPreservationArchiveV1Profile(scopeKind: CurrentAuthorityPreservationArchiveV1Kind): Hex {
  return kind(scopeKind) === "collection" ? CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_COLLECTION_PROFILE
    : CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPED_PROFILE;
}
export function currentAuthorityPreservationArchiveV1InventoryProfile(scopeKind: CurrentAuthorityPreservationArchiveV1Kind): Hex {
  return kind(scopeKind) === "collection" ? inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_PROFILE
    : inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_PROFILE;
}
export function currentAuthorityPreservationArchiveV1Interface(scopeKind: CurrentAuthorityPreservationArchiveV1Kind): Interface {
  return new Interface(kind(scopeKind) === "collection" ? CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_COLLECTION_ABI
    : CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPED_ABI);
}
export function normalizeCurrentAuthorityPreservationArchiveV1Coordinates(
  value: CurrentAuthorityPreservationArchiveV1Coordinates,
): CurrentAuthorityPreservationArchiveV1Coordinates {
  exact(value, ["chainId", "core", "archive", "scopeKind"], "Archive coordinates");
  const chainId = uint(value.chainId);
  if (chainId === 0n) throw Error("Nonzero chain required");
  return Object.freeze({ chainId, core: address(value.core, true), archive: address(value.archive, true), scopeKind: kind(value.scopeKind) });
}
export function normalizeCurrentAuthorityPreservationArchiveV1Evidence(
  scopeKind: CurrentAuthorityPreservationArchiveV1Kind,
  value: CurrentAuthorityPreservationArchiveV1Evidence,
): CurrentAuthorityPreservationArchiveV1Evidence {
  return kind(scopeKind) === "collection"
    ? normalizeCurrentAuthorityPreservationArchiveV1CollectionEvidence(value as CurrentAuthorityPreservationArchiveV1CollectionEvidence)
    : normalizeCurrentAuthorityPreservationArchiveV1ScopedEvidence(value as CurrentAuthorityPreservationArchiveV1ScopedEvidence);
}
export function encodeCurrentAuthorityPreservationArchiveV1Evidence(
  scopeKind: CurrentAuthorityPreservationArchiveV1Kind,
  value: CurrentAuthorityPreservationArchiveV1Evidence,
): Hex {
  return encode(kind(scopeKind) === "collection" ? CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_COLLECTION_EVIDENCE_TUPLE
    : CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPED_EVIDENCE_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationArchiveV1Evidence(
  scopeKind: CurrentAuthorityPreservationArchiveV1Kind,
  value: Hex,
): CurrentAuthorityPreservationArchiveV1Evidence {
  return decode(kind(scopeKind) === "collection" ? CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_COLLECTION_EVIDENCE_TUPLE
    : CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPED_EVIDENCE_TUPLE, value);
}
function coreEvidence(scopeKind: CurrentAuthorityPreservationArchiveV1Kind, value: CurrentAuthorityPreservationArchiveV1Evidence): CurrentAuthorityPreservationArchiveV1CollectionEvidence {
  const e = normalizeCurrentAuthorityPreservationArchiveV1Evidence(scopeKind, value);
  return scopeKind === "collection" ? e as CurrentAuthorityPreservationArchiveV1CollectionEvidence
    : (e as CurrentAuthorityPreservationArchiveV1ScopedEvidence).coverage;
}
function coreInventory(scopeKind: CurrentAuthorityPreservationArchiveV1Kind, value: CurrentAuthorityPreservationArchiveV1InventoryEvidence): inventory.CurrentAuthorityPreservationInventoryV1CollectionEvidence {
  const e = inventory.normalizeCurrentAuthorityPreservationInventoryV1Evidence(scopeKind, value);
  return scopeKind === "collection" ? e as inventory.CurrentAuthorityPreservationInventoryV1CollectionEvidence
    : (e as inventory.CurrentAuthorityPreservationInventoryV1ScopedEvidence).inventory;
}

/** Exact e93 closed vocabulary. This checks byte correspondence eligibility, not producer authority. */
export function currentAuthorityPreservationArchiveV1SupportedAbiCorrespondence(value: CurrentAuthorityPreservationArchiveV1Item): boolean {
  const row = inventory.normalizeCurrentAuthorityPreservationInventoryV1Item(value);
  const abi = id("STREAM_SOLIDITY_ABI_V1");
  if (row.kind === 4n) return row.role === id("SIGNIFICANT_PROPERTIES") && row.sourceIndex === 8n
    && row.schemaId === ZERO && row.byteSize === 0n && row.canonicalizationId === abi
    && (row.algorithm === 1n || row.algorithm === 2n);
  if (row.algorithm !== 1n || row.byteSize === 0n) return false;
  const cases: readonly (readonly [bigint, string, string, string])[] = [
    [0n, "COMPLETE_SIGNIFICANT_PROPERTIES", "STREAM_REFERENCE_SIGNIFICANT_PROPERTIES_ABI_V1", "STREAM_SOLIDITY_ABI_V1"],
    [0n, "METRIC_SUPPLEMENT_PAYLOAD", "STREAM_REFERENCE_METRIC_SUPPLEMENT_ABI_V1", "STREAM_SOLIDITY_ABI_V1"],
    [2n, "REFERENCE_MANIFEST", "STREAM_REFERENCE_MODE_ABI_V1", "STREAM_SOLIDITY_ABI_V1"],
    [2n, "CURATED_CONDITION_ORIGINAL_PAYLOAD", "STREAM_REFERENCE_CURATED_CONDITION_ABI_V1", "STREAM_SOLIDITY_ABI_V1"],
    [2n, "SCOPED_SNAPSHOT_MANIFEST", "STREAM_SCOPED_STATIC_SNAPSHOT_ABI_V1", "STREAM_SOLIDITY_ABI_V1"],
    [2n, "SCOPED_REFERENCE_MANIFEST", "STREAM_SCOPED_REFERENCE_RENDER_ABI_V1", "STREAM_SOLIDITY_ABI_V1"],
    [2n, "POLICY_SNAPSHOT_MANIFEST_V2", "STREAM_POLICY_COLLECTION_SNAPSHOT_ABI_V2", "STREAM_ABI_POLICY_COLLECTION_SNAPSHOT_V2"],
    [2n, "POLICY_SNAPSHOT_MANIFEST_V2", "STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V1", "STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V1"],
    [2n, "POLICY_SNAPSHOT_MANIFEST_V2", "STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V2", "STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V2"],
    [2n, "REFERENCE_MANIFEST", "STREAM_POLICY_COLLECTION_REFERENCE_ABI_V2", "STREAM_ABI_POLICY_COLLECTION_REFERENCE_V2"],
    [2n, "REFERENCE_MANIFEST", "STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V1", "STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V1"],
    [2n, "REFERENCE_MANIFEST", "STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V2", "STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V2"],
    [2n, "SCOPED_POLICY_SNAPSHOT_MANIFEST_V2", "STREAM_SCOPED_POLICY_SNAPSHOT_ABI_V2", "STREAM_ABI_SCOPED_POLICY_SNAPSHOT_V2"],
    [2n, "SCOPED_POLICY_SNAPSHOT_MANIFEST_V2", "STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V1", "STREAM_ABI_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1"],
    [2n, "SCOPED_POLICY_SNAPSHOT_MANIFEST_V2", "STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V2", "STREAM_ABI_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2"],
    [2n, "SCOPED_POLICY_REFERENCE_MANIFEST", "STREAM_SCOPED_POLICY_REFERENCE_ABI_V2", "STREAM_ABI_SCOPED_POLICY_REFERENCE_V2"],
    [2n, "SCOPED_PRESERVATION_POLICY_REFERENCE_MANIFEST", "STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V1", "STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V1"],
    [2n, "SCOPED_PRESERVATION_POLICY_REFERENCE_MANIFEST", "STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V2", "STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V2"],
  ];
  return cases.some(([k, role, schema, canon]) => row.kind === k && row.role === id(role)
    && row.schemaId === id(schema) && row.canonicalizationId === id(canon));
}

export function currentAuthorityPreservationArchiveV1DependencyHash(
  scopeKind: CurrentAuthorityPreservationArchiveV1Kind,
  dependencies: CurrentAuthorityPreservationArchiveV1Dependencies,
  origin: CurrentAuthorityPreservationArchiveV1OriginDependencies,
  authority: CurrentAuthorityPreservationArchiveV1AuthorityDependencies,
): Hex {
  return hash(["bytes32", "bytes32", CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_DEPENDENCIES_TUPLE,
    CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ORIGIN_DEPENDENCIES_TUPLE,
    CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_AUTHORITY_DEPENDENCIES_TUPLE],
  [currentAuthorityPreservationArchiveV1Profile(scopeKind), currentAuthorityPreservationArchiveV1InventoryProfile(scopeKind),
    normalizeCurrentAuthorityPreservationArchiveV1Dependencies(dependencies), normalizeCurrentAuthorityPreservationArchiveV1OriginDependencies(origin),
    normalizeCurrentAuthorityPreservationArchiveV1AuthorityDependencies(authority)]);
}
export function validateCurrentAuthorityPreservationArchiveV1Dependencies(
  coordinates: CurrentAuthorityPreservationArchiveV1Coordinates,
  dependencies: CurrentAuthorityPreservationArchiveV1Dependencies,
  origin: CurrentAuthorityPreservationArchiveV1OriginDependencies,
  authority: CurrentAuthorityPreservationArchiveV1AuthorityDependencies,
): CurrentAuthorityPreservationArchiveV1Dependencies {
  const c = normalizeCurrentAuthorityPreservationArchiveV1Coordinates(coordinates);
  const d = normalizeCurrentAuthorityPreservationArchiveV1Dependencies(dependencies);
  const o = normalizeCurrentAuthorityPreservationArchiveV1OriginDependencies(origin);
  const a = normalizeCurrentAuthorityPreservationArchiveV1AuthorityDependencies(authority);
  if (d.chainId !== c.chainId || d.targets[0] !== c.core || d.readGas < 50000n || d.archiveGas < d.readGas) throw Error("Archive dependencies or gas floors differ");
  d.targets.forEach(v => address(v, true));
  d.codeHashes.forEach(nonzero);
  address(o.worker, true); nonzero(o.workerCodeHash);
  address(a.resolver, true); nonzero(a.resolverCodeHash);
  if (o.profile !== inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_PROFILE
    || o.originGas < 50000n || o.originGas >= 1n << 64n
    || a.resolverGas < 50000n || a.resolverGas >= 1n << 64n) throw Error("Origin or authority dependency profile/gas differs");
  return d;
}
/** Hashes supplied observations only; does not perform runtime, authority or liveness reads. */
export function currentAuthorityPreservationArchiveV1BaseEnvironmentHash(
  dependencies: CurrentAuthorityPreservationArchiveV1Dependencies,
  onchainHash: Hex, epoch: bigint, externalHash: Hex, revision: bigint,
): Hex {
  if (uint(epoch, 64) === 0n) throw Error("Nonzero onchain epoch required");
  return hash(["bytes32", CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_DEPENDENCIES_TUPLE, "bytes32", "uint64", "bytes32", "uint64"],
    [id("6529STREAM_BUNDLE_IMMUTABLE_STOP_ENVIRONMENT_V1"), normalizeCurrentAuthorityPreservationArchiveV1Dependencies(dependencies),
      nonzero(onchainHash), epoch, nonzero(externalHash), uint(revision, 64)]);
}
export function currentAuthorityPreservationArchiveV1MultiOriginEnvironmentHash(
  base: Hex, origin: CurrentAuthorityPreservationArchiveV1OriginDependencies,
  scopeKind: CurrentAuthorityPreservationArchiveV1Kind, planId: Hex, originRoot: Hex, count: bigint,
): Hex {
  if (uint(count) === 0n || count > 17n) throw Error("Origin count must be 1..17");
  return hash(["bytes32", "bytes32", CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ORIGIN_DEPENDENCIES_TUPLE, "bytes32", "bytes32", "bytes32", "uint256"],
    [id("6529STREAM_MULTI_ORIGIN_BUNDLE_ENVIRONMENT_V1"), bytes(base, 32), normalizeCurrentAuthorityPreservationArchiveV1OriginDependencies(origin),
      currentAuthorityPreservationArchiveV1InventoryProfile(scopeKind), nonzero(planId), nonzero(originRoot), count]);
}
export function currentAuthorityPreservationArchiveV1EnvironmentHash(
  multiOrigin: Hex, authority: CurrentAuthorityPreservationArchiveV1AuthorityDependencies,
  capture: CurrentAuthorityPreservationArchiveV1AuthorityCapture,
): Hex {
  return hash(["bytes32", "bytes32", CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_AUTHORITY_DEPENDENCIES_TUPLE,
    CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_AUTHORITY_CAPTURE_TUPLE],
  [id("6529STREAM_CURRENT_AUTHORITY_BUNDLE_ENVIRONMENT_V1"), bytes(multiOrigin, 32),
    normalizeCurrentAuthorityPreservationArchiveV1AuthorityDependencies(authority), normalizeCurrentAuthorityPreservationArchiveV1AuthorityCapture(capture)]);
}
export function currentAuthorityPreservationArchiveV1ItemChain(
  scopeKind: CurrentAuthorityPreservationArchiveV1Kind, previous: Hex, planId: Hex,
  index: bigint, itemHash: Hex, admission: CurrentAuthorityPreservationArchiveV1Admission, originHash: Hex,
): Hex {
  return hash(["bytes32", "bytes32", "bytes32", "uint64", "bytes32", CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_ADMISSION_TUPLE, "bytes32"],
    [domain(scopeKind, "COVERED_ITEM_V1"), bytes(previous, 32), bytes(planId, 32), uint(index, 64), bytes(itemHash, 32),
      normalizeCurrentAuthorityPreservationArchiveV1Admission(admission), bytes(originHash, 32)]);
}
export function currentAuthorityPreservationArchiveV1ObservationChain(
  scopeKind: CurrentAuthorityPreservationArchiveV1Kind, previous: Hex, index: bigint, itemHash: Hex, observation: Hex,
): Hex {
  return hash(["bytes32", "bytes32", "uint64", "bytes32", "bytes32"],
    [domain(scopeKind, "CURRENT_OBSERVATION_V1"), bytes(previous, 32), uint(index, 64), bytes(itemHash, 32), bytes(observation, 32)]);
}
export function currentAuthorityPreservationArchiveV1RefreshId(
  coordinates: CurrentAuthorityPreservationArchiveV1Coordinates, dependencyHash: Hex, planId: Hex, environment: Hex,
): Hex {
  const c = normalizeCurrentAuthorityPreservationArchiveV1Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32"],
    [domain(c.scopeKind, "REFRESH_V1"), c.chainId, c.archive, bytes(dependencyHash, 32), bytes(planId, 32), bytes(environment, 32)]);
}
export function currentAuthorityPreservationArchiveV1CoverageHash(
  coordinates: CurrentAuthorityPreservationArchiveV1Coordinates, dependencyHash: Hex, originRoot: Hex, originCount: bigint,
  inventoryEvidence: CurrentAuthorityPreservationArchiveV1InventoryEvidence, bundleEvidence: CurrentAuthorityPreservationArchiveV1Evidence,
): Hex {
  const c = normalizeCurrentAuthorityPreservationArchiveV1Coordinates(coordinates);
  const i = inventory.normalizeCurrentAuthorityPreservationInventoryV1Evidence(c.scopeKind, inventoryEvidence);
  const e = normalizeCurrentAuthorityPreservationArchiveV1Evidence(c.scopeKind, bundleEvidence);
  const copy = c.scopeKind === "collection" ? { ...e, bundleCoverageHash: ZERO }
    : { ...e, coverage: { ...(e as CurrentAuthorityPreservationArchiveV1ScopedEvidence).coverage, bundleCoverageHash: ZERO } };
  return hash(["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32", "uint256",
    c.scopeKind === "collection" ? inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_EVIDENCE_TUPLE
      : inventory.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_EVIDENCE_TUPLE,
    c.scopeKind === "collection" ? CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_COLLECTION_EVIDENCE_TUPLE
      : CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPED_EVIDENCE_TUPLE],
  [domain(c.scopeKind, "ARCHIVE_COVERAGE_V1"), c.chainId, c.archive, bytes(dependencyHash, 32),
    currentAuthorityPreservationArchiveV1Profile(c.scopeKind), bytes(originRoot, 32), uint(originCount), i, copy]);
}
export function currentAuthorityPreservationArchiveV1Evidence(
  coordinates: CurrentAuthorityPreservationArchiveV1Coordinates, dependencyHash: Hex, originRoot: Hex, originCount: bigint,
  inventoryEvidence: CurrentAuthorityPreservationArchiveV1InventoryEvidence, evidenceChainHash: Hex,
): CurrentAuthorityPreservationArchiveV1Evidence {
  const c = normalizeCurrentAuthorityPreservationArchiveV1Coordinates(coordinates);
  const i = inventory.normalizeCurrentAuthorityPreservationInventoryV1Evidence(c.scopeKind, inventoryEvidence);
  const core = coreInventory(c.scopeKind, i);
  const coverage = { inventoryPlan: core.planId, renderCriticalEvidenceHash: core.renderCriticalEvidenceHash,
    itemCount: core.itemCount, evidenceChainHash: bytes(evidenceChainHash, 32), bundleCoverageHash: ZERO };
  const e = c.scopeKind === "collection" ? coverage : { scope: (i as inventory.CurrentAuthorityPreservationInventoryV1ScopedEvidence).scope, coverage };
  const h = currentAuthorityPreservationArchiveV1CoverageHash(c, dependencyHash, originRoot, originCount, i, e);
  return normalizeCurrentAuthorityPreservationArchiveV1Evidence(c.scopeKind,
    c.scopeKind === "collection" ? { ...coverage, bundleCoverageHash: h }
      : { ...(e as CurrentAuthorityPreservationArchiveV1ScopedEvidence), coverage: { ...coverage, bundleCoverageHash: h } });
}
export function validateCurrentAuthorityPreservationArchiveV1Evidence(
  coordinates: CurrentAuthorityPreservationArchiveV1Coordinates, dependencyHash: Hex, originRoot: Hex, originCount: bigint,
  inventoryEvidence: CurrentAuthorityPreservationArchiveV1InventoryEvidence, bundleEvidence: CurrentAuthorityPreservationArchiveV1Evidence,
): CurrentAuthorityPreservationArchiveV1Evidence {
  const c = normalizeCurrentAuthorityPreservationArchiveV1Coordinates(coordinates);
  const e = normalizeCurrentAuthorityPreservationArchiveV1Evidence(c.scopeKind, bundleEvidence);
  const core = coreEvidence(c.scopeKind, e);
  const i = coreInventory(c.scopeKind, inventoryEvidence);
  nonzero(dependencyHash); nonzero(originRoot); nonzero(i.planId); nonzero(i.renderCriticalEvidenceHash);
  [i.artistId, i.scopeSubject, i.sourceContextHash, i.segmentChainHash].forEach(nonzero);
  if (i.collectionId === 0n) throw Error("Original inventory collection is nonzero");
  if (uint(originCount) < 1n || originCount > 17n || i.itemCount === 0n || i.segmentCount === 0n) throw Error("Incomplete original inventory/origin evidence");
  if (c.scopeKind === "scoped") inventory.validateCurrentAuthorityPreservationInventoryV1Scope(
    "scoped", (e as CurrentAuthorityPreservationArchiveV1ScopedEvidence).scope);
  const expected = currentAuthorityPreservationArchiveV1Evidence(c, dependencyHash, originRoot, originCount, inventoryEvidence, core.evidenceChainHash);
  if (encodeCurrentAuthorityPreservationArchiveV1Evidence(c.scopeKind, e) !== encodeCurrentAuthorityPreservationArchiveV1Evidence(c.scopeKind, expected)) throw Error("Archive evidence differs from original inventory/scope/coverage commitment");
  return e;
}


/** Validates the finite retained table; repeated environment identities are forbidden even with equal pins. */
export function currentAuthorityPreservationArchiveV1OriginSetHash(
  dependencies: CurrentAuthorityPreservationArchiveV1Dependencies,
  values: readonly CurrentAuthorityPreservationArchiveV1Origin[],
): Hex {
  const d = normalizeCurrentAuthorityPreservationArchiveV1Dependencies(dependencies);
  const rows = list(values);
  if (rows.length === 0 || rows.length > 17) throw Error("Origin count must be 1..17");
  const seen = new Set<Hex>();
  let chain = ZERO;
  for (let i = 0; i < rows.length; i++) {
    const o = normalizeCurrentAuthorityPreservationArchiveV1Origin(rows[i] as CurrentAuthorityPreservationArchiveV1Origin);
    if (o.environment.chainId !== d.chainId || o.environment.core !== d.targets[0]) throw Error("Origin coordinates differ");
    address(o.environment.registry, true); address(o.environment.coordinator, true); address(o.environment.archive, true);
    nonzero(o.registryCodeHash); nonzero(o.coordinatorCodeHash); nonzero(o.archiveCodeHash); nonzero(o.environment.suiteConfigurationHash);
    const identity = inventory.currentAuthorityPreservationInventoryV1OriginEnvironmentHash(o.environment);
    if (seen.has(identity)) throw Error("Duplicate retained origin identity");
    seen.add(identity);
    chain = inventory.currentAuthorityPreservationInventoryV1AppendOrigin(chain, BigInt(i), o);
  }
  return inventory.currentAuthorityPreservationInventoryV1SealedOriginSetHash(BigInt(rows.length), chain);
}
/** Supplied original route only. Runtime pins, occurrence provenance and current reads remain external. */
export function validateCurrentAuthorityPreservationArchiveV1OriginRoute(
  dependencies: CurrentAuthorityPreservationArchiveV1Dependencies,
  planId: Hex,
  evidence: inventory.CurrentAuthorityPreservationInventoryV1CollectionEvidence,
  item: CurrentAuthorityPreservationArchiveV1Item,
  recordOrigin: CurrentAuthorityPreservationArchiveV1RecordOrigin | null,
  origins: readonly CurrentAuthorityPreservationArchiveV1Origin[],
): Readonly<{ dependencies: CurrentAuthorityPreservationArchiveV1Dependencies; originHash: Hex }> {
  const d = normalizeCurrentAuthorityPreservationArchiveV1Dependencies(dependencies);
  const row = inventory.normalizeCurrentAuthorityPreservationInventoryV1Item(item);
  if (row.kind !== 6n) {
    if (recordOrigin !== null) throw Error("Non-state item has no retained origin fact");
    return Object.freeze({ dependencies: d, originHash: ZERO });
  }
  if (recordOrigin === null) throw Error("State item requires retained origin fact");
  const e = inventory.normalizeCurrentAuthorityPreservationInventoryV1CollectionEvidence(evidence);
  const fact = normalizeCurrentAuthorityPreservationArchiveV1RecordOrigin(recordOrigin);
  const op = fact.occurrence.receipt.operation;
  if (bytes(planId, 32) !== e.planId || fact.role !== row.role || fact.role === ZERO
    || fact.sourceContextHash !== e.sourceContextHash || fact.sourceContextHash === ZERO
    || fact.occurrence.receipt.artistId !== e.artistId || fact.occurrence.receipt.collectionId !== e.collectionId
    || fact.occurrence.receipt.recordHash === ZERO || fact.semanticRecordHash === ZERO
    || fact.occurrence.position.point.ownerRevision === 0n || (op !== 17n && op !== 24n)
    || fact.occurrence.position.point.ownerIndex !== (op === 17n ? 6n : 4n)
    || fact.occurrence.position.point.environmentHash !== inventory.currentAuthorityPreservationInventoryV1OriginEnvironmentHash(fact.producer.environment)
    || (fact.importCommitment === ZERO) !== (fact.importedAtRevision === 0n)
    || fact.actor === ZeroAddress || inventory.currentAuthorityPreservationInventoryV1EvidenceId(fact) !== row.sourceRecord
    || fact.producer.environment.archive !== row.source) throw Error("Original archive occurrence differs");
  currentAuthorityPreservationArchiveV1OriginSetHash(d, origins);
  const pin = inventory.currentAuthorityPreservationInventoryV1OriginPinHash(fact.producer);
  if (!origins.some(o => inventory.currentAuthorityPreservationInventoryV1OriginPinHash(o) === pin)) throw Error("Archive origin is absent from sealed table");
  const targets = [...d.targets], codeHashes = [...d.codeHashes];
  targets[5] = row.source; codeHashes[5] = fact.producer.archiveCodeHash;
  return Object.freeze({ dependencies: normalizeCurrentAuthorityPreservationArchiveV1Dependencies({ ...d,
    targets: targets as unknown as CurrentAuthorityPreservationArchiveV1Dependencies["targets"],
    codeHashes: codeHashes as unknown as CurrentAuthorityPreservationArchiveV1Dependencies["codeHashes"] }),
    originHash: inventory.currentAuthorityPreservationInventoryV1RecordOriginHash(fact) });
}

export type CurrentAuthorityPreservationArchiveV1Request =
  | { readonly kind: "beginCoverage" | "coverEmptySegment" | "beginRefresh"; readonly id: Hex }
  | { readonly kind: "coverNext"; readonly id: Hex; readonly item: CurrentAuthorityPreservationArchiveV1Item;
      readonly nextLink: Hex; readonly proof: CurrentAuthorityPreservationArchiveV1Proof }
  | { readonly kind: "refreshNext"; readonly id: Hex; readonly expectedIndex: bigint };
export interface CurrentAuthorityPreservationArchiveV1Call {
  readonly coordinates: CurrentAuthorityPreservationArchiveV1Coordinates;
  readonly caller: Address;
  readonly request: CurrentAuthorityPreservationArchiveV1Request;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}
export function normalizeCurrentAuthorityPreservationArchiveV1Request(
  value: CurrentAuthorityPreservationArchiveV1Request,
): CurrentAuthorityPreservationArchiveV1Request {
  switch (value?.kind) {
    case "beginCoverage": case "coverEmptySegment": case "beginRefresh":
      exact(value, ["kind", "id"], "Archive step");
      return Object.freeze({ kind: value.kind, id: nonzero(value.id) });
    case "coverNext": {
      exact(value, ["kind", "id", "item", "nextLink", "proof"], "Archive occurrence");
      const item = inventory.normalizeCurrentAuthorityPreservationInventoryV1Item(value.item);
      return Object.freeze({ kind: value.kind, id: nonzero(value.id), item, nextLink: bytes(value.nextLink, 32),
        proof: validateCurrentAuthorityPreservationArchiveV1Proof(item, value.proof) });
    }
    case "refreshNext":
      exact(value, ["kind", "id", "expectedIndex"], "Archive refresh");
      return Object.freeze({ kind: value.kind, id: nonzero(value.id), expectedIndex: uint(value.expectedIndex, 64) });
    default: throw Error("Unknown original archive write");
  }
}
export function prepareCurrentAuthorityPreservationArchiveV1Call(
  coordinates: CurrentAuthorityPreservationArchiveV1Coordinates, caller: Address, request: CurrentAuthorityPreservationArchiveV1Request,
): CurrentAuthorityPreservationArchiveV1Call {
  const c = normalizeCurrentAuthorityPreservationArchiveV1Coordinates(coordinates);
  const q = normalizeCurrentAuthorityPreservationArchiveV1Request(request);
  const args = q.kind === "coverNext" ? [q.id, q.item, q.nextLink, q.proof]
    : q.kind === "refreshNext" ? [q.id, q.expectedIndex] : [q.id];
  return Object.freeze({ coordinates: c, caller: address(caller, true), request: q, factsVerified: false,
    call: Object.freeze({ to: c.archive, value: 0n, data: bytes(currentAuthorityPreservationArchiveV1Interface(c.scopeKind).encodeFunctionData(q.kind, args)) }) });
}
export function normalizeCurrentAuthorityPreservationArchiveV1Call(value: CurrentAuthorityPreservationArchiveV1Call): CurrentAuthorityPreservationArchiveV1Call {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Archive call");
  exact(value.call, ["to", "value", "data"], "CALL");
  const rebuilt = prepareCurrentAuthorityPreservationArchiveV1Call(value.coordinates, value.caller, value.request);
  if (stable(value) !== stable(rebuilt)) throw Error("Archive call differs from reconstruction");
  return rebuilt;
}
export type CurrentAuthorityPreservationArchiveV1ReadRequest =
  | { readonly kind: "PROFILE" | "INVENTORY_PROFILE" | "preservationPolicyBundleArchiveProfile" | "scopedPreservationPolicyBundleArchiveProfile"
      | "core" | "metadataHost" | "renderCriticalInventory" | "artifactCoverage" | "externalCoverage" | "deploymentChainId"
      | "coreCodeHash" | "metadataCodeHash" | "inventoryCodeHash" | "dependencies" | "dependencyHash" | "originDependencies" | "authorityDependencies" | "originProfile" }
  | { readonly kind: "supportsInterface"; readonly interfaceId: Hex }
  | { readonly kind: "bundleEvidence" | "progress" | "requireFullCurrentCoverage"; readonly id: Hex }
  | { readonly kind: "refresh"; readonly key: Hex }
  | { readonly kind: "admittedItem" | "admittedOriginHash"; readonly id: Hex; readonly index: bigint }
  | { readonly kind: "requireCoverage"; readonly id: Hex; readonly expectedHash: Hex; readonly scope?: CurrentAuthorityPreservationArchiveV1Scope };
export interface CurrentAuthorityPreservationArchiveV1Read {
  readonly coordinates: CurrentAuthorityPreservationArchiveV1Coordinates;
  readonly caller: Address;
  readonly request: CurrentAuthorityPreservationArchiveV1ReadRequest;
  readonly call: UnsignedCall;
  readonly requiresCurrentObservations: boolean;
}
export function prepareCurrentAuthorityPreservationArchiveV1Read(
  coordinates: CurrentAuthorityPreservationArchiveV1Coordinates, caller: Address, request: CurrentAuthorityPreservationArchiveV1ReadRequest,
): CurrentAuthorityPreservationArchiveV1Read {
  const c = normalizeCurrentAuthorityPreservationArchiveV1Coordinates(coordinates);
  let q: CurrentAuthorityPreservationArchiveV1ReadRequest, args: readonly unknown[];
  switch (request?.kind) {
    case "PROFILE": case "INVENTORY_PROFILE": case "preservationPolicyBundleArchiveProfile": case "scopedPreservationPolicyBundleArchiveProfile":
    case "core": case "metadataHost": case "renderCriticalInventory": case "artifactCoverage": case "externalCoverage": case "deploymentChainId":
    case "coreCodeHash": case "metadataCodeHash": case "inventoryCodeHash": case "dependencies": case "dependencyHash":
    case "originDependencies": case "authorityDependencies": case "originProfile":
      exact(request, ["kind"], "Archive getter");
      if (request.kind === (c.scopeKind === "collection" ? "scopedPreservationPolicyBundleArchiveProfile" : "preservationPolicyBundleArchiveProfile")) throw Error("Getter belongs to other host");
      q = Object.freeze({ kind: request.kind }); args = []; break;
    case "supportsInterface":
      exact(request, ["kind", "interfaceId"], "Capability read");
      q = Object.freeze({ kind: request.kind, interfaceId: bytes(request.interfaceId, 4) }); args = [q.interfaceId]; break;
    case "bundleEvidence": case "progress": case "requireFullCurrentCoverage":
      exact(request, ["kind", "id"], "Archive retained read");
      q = Object.freeze({ kind: request.kind, id: bytes(request.id, 32) }); args = [q.id]; break;
    case "refresh":
      exact(request, ["kind", "key"], "Refresh read");
      q = Object.freeze({ kind: request.kind, key: bytes(request.key, 32) }); args = [q.key]; break;
    case "admittedItem": case "admittedOriginHash":
      exact(request, ["kind", "id", "index"], "Archive occurrence read");
      q = Object.freeze({ kind: request.kind, id: bytes(request.id, 32), index: uint(request.index, 64) }); args = [q.id, q.index]; break;
    case "requireCoverage":
      exact(request, c.scopeKind === "collection" ? ["kind", "id", "expectedHash"] : ["kind", "scope", "id", "expectedHash"], "Current archive read");
      q = c.scopeKind === "collection" ? Object.freeze({ kind: request.kind, id: bytes(request.id, 32), expectedHash: bytes(request.expectedHash, 32) })
        : Object.freeze({ kind: request.kind, id: bytes(request.id, 32), expectedHash: bytes(request.expectedHash, 32),
          scope: inventory.validateCurrentAuthorityPreservationInventoryV1Scope("scoped", request.scope!) });
      args = c.scopeKind === "collection" ? [q.id, q.expectedHash] : [q.scope, q.id, q.expectedHash]; break;
    default: throw Error("Unknown original archive read");
  }
  return Object.freeze({ coordinates: c, caller: address(caller), request: q,
    call: Object.freeze({ to: c.archive, value: 0n, data: bytes(currentAuthorityPreservationArchiveV1Interface(c.scopeKind).encodeFunctionData(q.kind, args)) }),
    requiresCurrentObservations: q.kind === "requireCoverage" || q.kind === "requireFullCurrentCoverage" });
}
export function normalizeCurrentAuthorityPreservationArchiveV1Read(value: CurrentAuthorityPreservationArchiveV1Read): CurrentAuthorityPreservationArchiveV1Read {
  exact(value, ["coordinates", "caller", "request", "call", "requiresCurrentObservations"], "Archive read");
  exact(value.call, ["to", "value", "data"], "Read CALL");
  const rebuilt = prepareCurrentAuthorityPreservationArchiveV1Read(value.coordinates, value.caller, value.request);
  if (stable(value) !== stable(rebuilt)) throw Error("Archive read differs from reconstruction");
  return rebuilt;
}

export interface CurrentAuthorityPreservationArchiveV1HistoryRow {
  readonly item: CurrentAuthorityPreservationArchiveV1Item;
  readonly admission: CurrentAuthorityPreservationArchiveV1Admission;
  readonly originHash: Hex;
  readonly recordOrigin: CurrentAuthorityPreservationArchiveV1RecordOrigin | null;
}
export interface CurrentAuthorityPreservationArchiveV1HistoryInput {
  readonly coordinates: CurrentAuthorityPreservationArchiveV1Coordinates;
  readonly dependencies: CurrentAuthorityPreservationArchiveV1Dependencies;
  readonly originDependencies: CurrentAuthorityPreservationArchiveV1OriginDependencies;
  readonly authorityDependencies: CurrentAuthorityPreservationArchiveV1AuthorityDependencies;
  readonly inventory: inventory.CurrentAuthorityPreservationInventoryV1HistoryInput;
  readonly progress: CurrentAuthorityPreservationArchiveV1Progress;
  readonly evidence: CurrentAuthorityPreservationArchiveV1Evidence;
  readonly rows: readonly CurrentAuthorityPreservationArchiveV1HistoryRow[];
}
/** Reconstructs supplied local commitments, not RPC provenance, original archive bytes or present liveness.
 * The private automatic admission-observation chain is deliberately not inferred from retained rows. */
export function authenticateCurrentAuthorityPreservationArchiveV1History(
  value: CurrentAuthorityPreservationArchiveV1HistoryInput,
): Readonly<{ planId: Hex; dependencyHash: Hex; originRoot: Hex; evidenceChainHash: Hex; coverageHash: Hex; initialObservationChainIndependentlyReconstructed: false }> {
  exact(value, ["coordinates", "dependencies", "originDependencies", "authorityDependencies", "inventory", "progress", "evidence", "rows"], "Archive history");
  const c = normalizeCurrentAuthorityPreservationArchiveV1Coordinates(value.coordinates);
  const d = validateCurrentAuthorityPreservationArchiveV1Dependencies(c, value.dependencies, value.originDependencies, value.authorityDependencies);
  const old = inventory.authenticateCurrentAuthorityPreservationInventoryV1History(value.inventory);
  const ic = value.inventory.coordinates, anchor = inventory.normalizeCurrentAuthorityPreservationInventoryV1Dependencies(value.inventory.dependencies);
  if (ic.scopeKind !== c.scopeKind || ic.chainId !== c.chainId || address(ic.core) !== c.core || address(ic.inventory) !== d.targets[2]
    || anchor.chainId !== c.chainId) throw Error("Retained inventory deployment differs");
  for (const [i, j] of [[0, 0], [1, 1], [2, 10], [3, 11]] as const) {
    const archiveIndex = i < 2 ? i : i + 1;
    if (anchor.targets[j] !== d.targets[archiveIndex] || anchor.codeHashes[j] !== d.codeHashes[archiveIndex]) throw Error("Original archive dependency projection differs");
  }
  if (anchor.artistTargets[4] !== d.targets[5] || anchor.artistCodeHashes[4] !== d.codeHashes[5]
    || encodeCurrentAuthorityPreservationArchiveV1OriginDependencies(value.originDependencies) !== encodeCurrentAuthorityPreservationArchiveV1OriginDependencies(value.inventory.originDependencies)
    || encodeCurrentAuthorityPreservationArchiveV1AuthorityDependencies(value.authorityDependencies) !== encodeCurrentAuthorityPreservationArchiveV1AuthorityDependencies(value.inventory.authorityDependencies)) throw Error("Retained authority/origin configuration differs");
  const root = currentAuthorityPreservationArchiveV1OriginSetHash(d, value.inventory.origins);
  if (root !== old.originRoot) throw Error("Origin root differs");
  const i = coreInventory(c.scopeKind, value.inventory.evidence);
  const rows = list(value.rows);
  let offset = 0, chain = ZERO;
  for (const segment of value.inventory.segments) {
    const s = inventory.validateCurrentAuthorityPreservationInventoryV1Segment(segment);
    if (s.itemCount > BigInt(rows.length - offset)) throw Error("Missing retained occurrences or client row bound");
    let link = ZERO;
    for (let j = Number(s.itemCount) - 1; j >= 0; j--) {
      const entry = rows[offset + j] as CurrentAuthorityPreservationArchiveV1HistoryRow | undefined;
      if (!entry) throw Error("Missing retained occurrence");
      link = inventory.currentAuthorityPreservationInventoryV1Link(s.key, s.itemCount, BigInt(j), entry.item, link);
    }
    if (link !== s.firstLink) throw Error("Retained occurrence link differs");
    for (let j = 0; j < Number(s.itemCount); j++) {
      const entry = rows[offset + j] as CurrentAuthorityPreservationArchiveV1HistoryRow;
      exact(entry, ["item", "admission", "originHash", "recordOrigin"], "Retained archive row");
      const item = inventory.normalizeCurrentAuthorityPreservationInventoryV1Item(entry.item);
      const admitted = validateCurrentAuthorityPreservationArchiveV1Admission(i.artistId, item, entry.admission);
      const route = validateCurrentAuthorityPreservationArchiveV1OriginRoute(d, old.planId, i, item, entry.recordOrigin, value.inventory.origins);
      if (route.originHash !== bytes(entry.originHash, 32)) throw Error("Retained origin hash differs");
      chain = currentAuthorityPreservationArchiveV1ItemChain(c.scopeKind, chain, old.planId, BigInt(offset + j),
        inventory.currentAuthorityPreservationInventoryV1ItemHash(item), admitted, route.originHash);
    }
    offset += Number(s.itemCount);
  }
  if (offset !== rows.length) throw Error("Unexpected retained occurrences");
  const p = normalizeCurrentAuthorityPreservationArchiveV1Progress(value.progress);
  if (!p.complete || p.segmentIndex !== i.segmentCount || p.segmentItemIndex !== 0n || p.nextLink !== ZERO
    || p.itemCount !== i.itemCount || p.segmentChainHash !== i.segmentChainHash || p.evidenceChainHash !== chain) throw Error("Completed archive progress differs");
  const dependencyHash = currentAuthorityPreservationArchiveV1DependencyHash(c.scopeKind, d, value.originDependencies, value.authorityDependencies);
  const e = validateCurrentAuthorityPreservationArchiveV1Evidence(c, dependencyHash, root, BigInt(value.inventory.origins.length), value.inventory.evidence, value.evidence);
  const core = coreEvidence(c.scopeKind, e);
  if (core.evidenceChainHash !== chain) throw Error("Coverage item chain differs");
  return Object.freeze({ planId: old.planId, dependencyHash, originRoot: root, evidenceChainHash: chain,
    coverageHash: core.bundleCoverageHash, initialObservationChainIndependentlyReconstructed: false });
}


/** Supplied external object/coverage joins. Original signature bundles and current pair remain separate reads. */
export function validateCurrentAuthorityPreservationArchiveV1ExternalObject(
  artistId: Hex, item: CurrentAuthorityPreservationArchiveV1Item, proof: CurrentAuthorityPreservationArchiveV1Proof,
  object: CurrentAuthorityPreservationArchiveV1ObjectIdentity, coverage: CurrentAuthorityPreservationArchiveV1ExternalCoverage,
): CurrentAuthorityPreservationArchiveV1ExternalCoverage {
  const artist = nonzero(artistId), row = inventory.normalizeCurrentAuthorityPreservationInventoryV1Item(item);
  const p = validateCurrentAuthorityPreservationArchiveV1Proof(row, proof);
  const o = normalizeCurrentAuthorityPreservationArchiveV1ObjectIdentity(object), c = normalizeCurrentAuthorityPreservationArchiveV1ExternalCoverage(coverage);
  if (p.backend !== 1n) throw Error("External object requires external proof");
  validateCurrentAuthorityPreservationArchiveV1Correspondence(row, {
    contentHash: o.contentHash, sha256Digest: o.sha256Digest,
    canonicalizationId: o.canonicalizationId, byteSize: o.byteSize,
  });
  if (o.artistId !== artist || (row.schemaId !== ZERO && row.schemaId !== o.schemaId)
    || (row.formatId !== ZERO && row.formatId !== o.formatId)
    || (row.kind !== 3n && row.catalogId !== ZERO && (row.catalogId !== o.formatCatalogId || row.catalogHash !== o.formatCatalogHash))
    || c.coverageHash !== p.coverageHash || c.objectHash !== p.objectHash || c.artistId !== artist
    || c.contentHash !== o.contentHash || c.sha256Digest !== o.sha256Digest || c.arweaveDataRoot !== o.arweaveDataRoot
    || c.byteSize !== o.byteSize) throw Error("Original external object/coverage differs");
  [c.firstReceiptHash, c.secondReceiptHash, c.firstFixityHash, c.secondFixityHash].forEach(nonzero);
  return c;
}
/** Replays the source current() decision from supplied read results, never performs a live read. */
export function currentAuthorityPreservationArchiveV1CurrentObservation(
  artistId: Hex, item: CurrentAuthorityPreservationArchiveV1Item, original: CurrentAuthorityPreservationArchiveV1Admission,
  current: CurrentAuthorityPreservationArchiveV1CurrentPair | CurrentAuthorityPreservationArchiveV1Admission,
): Hex {
  const old = validateCurrentAuthorityPreservationArchiveV1Admission(artistId, item, original);
  if (old.proof.backend === 1n) return currentAuthorityPreservationArchiveV1CurrentPairHash(old.externalOriginal, current as CurrentAuthorityPreservationArchiveV1CurrentPair);
  const now = validateCurrentAuthorityPreservationArchiveV1Admission(artistId, item, current as CurrentAuthorityPreservationArchiveV1Admission);
  if (encodeCurrentAuthorityPreservationArchiveV1Admission(old) !== encodeCurrentAuthorityPreservationArchiveV1Admission(now)) throw Error("Current admission changes original evidence");
  return ZERO;
}
export function validateCurrentAuthorityPreservationArchiveV1RefreshStep(
  scopeKind: CurrentAuthorityPreservationArchiveV1Kind,
  previous: CurrentAuthorityPreservationArchiveV1Refresh, next: CurrentAuthorityPreservationArchiveV1Refresh,
  expectedIndex: bigint, itemCount: bigint, itemHash: Hex, observation: Hex,
): CurrentAuthorityPreservationArchiveV1Refresh {
  const before = normalizeCurrentAuthorityPreservationArchiveV1Refresh(previous), after = normalizeCurrentAuthorityPreservationArchiveV1Refresh(next);
  const index = uint(expectedIndex, 64), count = uint(itemCount, 64);
  if (before.complete || before.environmentHash === ZERO || before.nextIndex !== index || index >= count
    || after.environmentHash !== before.environmentHash || after.nextIndex !== index + 1n
    || after.complete !== (index + 1n === count)
    || after.currentObservationChain !== currentAuthorityPreservationArchiveV1ObservationChain(scopeKind, before.currentObservationChain, index, itemHash, observation)) throw Error("Original refresh transition differs");
  return after;
}
