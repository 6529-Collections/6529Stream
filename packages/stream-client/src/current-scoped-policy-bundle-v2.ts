import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, sha256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import * as inventory from "./current-scoped-policy-inventory-v2.js";

/** Original immutable-STOP archive profile. Archive liveness and source currentness are separate. */
export const SCOPED_POLICY_BUNDLE_V2_SOURCE = "896899f7ca4130f86e066587f780a3b1f755a25d";
export const SCOPED_POLICY_BUNDLE_V2_PROFILE = id("6529STREAM_SCOPED_POLICY_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V2") as Hex;
/** Client allocation bounds, not original item-count limits. */
export const SCOPED_POLICY_BUNDLE_V2_MAX_BYTES = 2097152;
export const SCOPED_POLICY_BUNDLE_V2_MAX_ROWS = 8192;

export interface ScopedPolicyBundleV2Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly bundle: Address;
}

export type ScopedPolicyBundleV2Item = inventory.ScopedPolicyInventoryV2Item;
export type ScopedPolicyBundleV2Segment = inventory.ScopedPolicyInventoryV2Segment;
export type ScopedPolicyBundleV2InventoryEvidence = inventory.ScopedPolicyInventoryV2Evidence;

export interface ScopedPolicyBundleV2Dependencies {
  readonly targets: readonly [Address, Address, Address, Address, Address, Address];
  readonly codeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex];
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly archiveGas: bigint;
}

export interface ScopedPolicyBundleV2Proof {
  readonly backend: bigint;
  readonly coverageHash: Hex;
  readonly objectHash: Hex;
}

export interface ScopedPolicyBundleV2Admission {
  readonly proof: ScopedPolicyBundleV2Proof;
  readonly originalBundleHash: Hex;
  readonly immutablePartsHash: Hex;
  readonly externalOriginal: ScopedPolicyBundleV2ExternalCoverage;
  readonly onchainOriginal: ScopedPolicyBundleV2OnchainCoverage;
}

export interface ScopedPolicyBundleV2ExternalCoverage {
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

export interface ScopedPolicyBundleV2OnchainCoverage {
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

export interface ScopedPolicyBundleV2Progress {
  readonly segmentIndex: bigint;
  readonly segmentItemIndex: bigint;
  readonly itemCount: bigint;
  readonly nextLink: Hex;
  readonly segmentChainHash: Hex;
  readonly evidenceChainHash: Hex;
  readonly environmentHash: Hex;
  readonly complete: boolean;
}

export interface ScopedPolicyBundleV2Refresh {
  readonly environmentHash: Hex;
  readonly nextIndex: bigint;
  readonly currentObservationChain: Hex;
  readonly complete: boolean;
}

export interface ScopedPolicyBundleV2Evidence {
  readonly scope: ScopedPolicyBundleV2Scope;
  readonly coverage: ScopedPolicyBundleV2OriginalEvidence;
}
export type ScopedPolicyBundleV2Scope = inventory.ScopedPolicyInventoryV2Scope;

export interface ScopedPolicyBundleV2OriginalEvidence {
  readonly inventoryPlan: Hex;
  readonly renderCriticalEvidenceHash: Hex;
  readonly itemCount: bigint;
  readonly evidenceChainHash: Hex;
  readonly bundleCoverageHash: Hex;
}

export const SCOPED_POLICY_BUNDLE_V2_DEPENDENCIES_TUPLE = "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)";

export const SCOPED_POLICY_BUNDLE_V2_PROOF_TUPLE = "(uint8 backend, bytes32 coverageHash, bytes32 objectHash)";

export const SCOPED_POLICY_BUNDLE_V2_ADMISSION_TUPLE = "((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal)";

export const SCOPED_POLICY_BUNDLE_V2_PROGRESS_TUPLE = "(uint64 segmentIndex, uint64 segmentItemIndex, uint64 itemCount, bytes32 nextLink, bytes32 segmentChainHash, bytes32 evidenceChainHash, bytes32 environmentHash, bool complete)";

export const SCOPED_POLICY_BUNDLE_V2_REFRESH_TUPLE = "(bytes32 environmentHash, uint64 nextIndex, bytes32 currentObservationChain, bool complete)";

export const SCOPED_POLICY_BUNDLE_V2_EVIDENCE_TUPLE = "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage)";

export const SCOPED_POLICY_BUNDLE_V2_ORIGINAL_EVIDENCE_TUPLE = "(bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash)";

export const SCOPED_POLICY_BUNDLE_V2_EXTERNAL_COVERAGE_TUPLE = "(bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash)";

export const SCOPED_POLICY_BUNDLE_V2_ONCHAIN_COVERAGE_TUPLE = "(bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash)";

export const SCOPED_POLICY_BUNDLE_V2_ITEM_TUPLE = inventory.SCOPED_POLICY_INVENTORY_V2_ITEM_TUPLE;
export const SCOPED_POLICY_BUNDLE_V2_SEGMENT_TUPLE = inventory.SCOPED_POLICY_INVENTORY_V2_SEGMENT_TUPLE;
export const SCOPED_POLICY_BUNDLE_V2_SCOPE_TUPLE = inventory.SCOPED_POLICY_INVENTORY_V2_SCOPE_TUPLE;

export const SCOPED_POLICY_BUNDLE_V2_ABI = Object.freeze([
  "error InvalidInventorySegment()",
  "error InvalidMetadataScope()",
  "error InventoryIncomplete()",
  "error InventoryRead(address target)",
  "error InventorySourceChanged()",
  "event ScopedBundleCoverageCompleted(uint16 schemaVersion, bytes32 indexed inventoryPlan, bytes32 indexed bundleCoverageHash, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage) evidence)",
  "event ScopedBundleCoverageStarted(uint16 schemaVersion, bytes32 indexed inventoryPlan, bytes32 indexed renderCriticalEvidenceHash)",
  "event ScopedBundleItemAdmitted(uint16 schemaVersion, bytes32 indexed inventoryPlan, uint64 indexed index, bytes32 itemHash, ((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal) admission)",
  "event ScopedBundleRefreshAdvanced(uint16 schemaVersion, bytes32 indexed inventoryPlan, bytes32 indexed refreshId, uint64 nextIndex, bytes32 observationChain, bool complete)",
  "function PROFILE() view returns (bytes32)",
  "function admittedItem(bytes32 id, uint64 index) view returns ((uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash), ((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal))",
  "function artifactCoverage() view returns (address)",
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
  "function progress(bytes32 id) view returns ((uint64 segmentIndex, uint64 segmentItemIndex, uint64 itemCount, bytes32 nextLink, bytes32 segmentChainHash, bytes32 evidenceChainHash, bytes32 environmentHash, bool complete))",
  "function refresh(bytes32 key) view returns ((bytes32 environmentHash, uint64 nextIndex, bytes32 currentObservationChain, bool complete))",
  "function refreshNext(bytes32 id, uint64 expectedIndex)",
  "function renderCriticalInventory() view returns (address)",
  "function requireCoverage((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 id, bytes32 expectedHash) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage) result)",
  "function requireFullCurrentCoverage(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage))",
  "function scopedPolicyBundleArchiveProfile() pure returns (bytes32)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
]);

/** Own capability excludes IERC165 and does not imply any additional writer methods. */
export const SCOPED_POLICY_BUNDLE_V2_INTERFACE_ID = "0x45cf3c47" as Hex;

const enumFields: Readonly<Record<string, Readonly<Record<string, number>>>> = {
  [ParamType.from(SCOPED_POLICY_BUNDLE_V2_SCOPE_TUPLE).format("full")]: { scopeType: 4 },
};
const coder = AbiCoder.defaultAbiCoder();
const ZERO = ZeroHash as Hex;
const bundleInterface = new Interface(SCOPED_POLICY_BUNDLE_V2_ABI);

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
    || (value.length - 2) / 2 > SCOPED_POLICY_BUNDLE_V2_MAX_BYTES) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}

function nonzero(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === ZERO) throw Error("Expected nonzero commitment");
  return result;
}

function list(value: unknown, fixed?: number): readonly unknown[] {
  if (!Array.isArray(value) || value.length > SCOPED_POLICY_BUNDLE_V2_MAX_ROWS
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
      || toUtf8Bytes(value).length > SCOPED_POLICY_BUNDLE_V2_MAX_BYTES) throw Error("Invalid UTF8 text or bound");
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

export function scopedPolicyBundleV2Interface(): Interface {
  return new Interface(SCOPED_POLICY_BUNDLE_V2_ABI);
}

export function normalizeScopedPolicyBundleV2Dependencies(value: ScopedPolicyBundleV2Dependencies): ScopedPolicyBundleV2Dependencies {
  return normalized(SCOPED_POLICY_BUNDLE_V2_DEPENDENCIES_TUPLE, value);
}
export function encodeScopedPolicyBundleV2Dependencies(value: ScopedPolicyBundleV2Dependencies): Hex {
  return encode(SCOPED_POLICY_BUNDLE_V2_DEPENDENCIES_TUPLE, value);
}
export function decodeScopedPolicyBundleV2Dependencies(value: Hex): ScopedPolicyBundleV2Dependencies {
  return decode(SCOPED_POLICY_BUNDLE_V2_DEPENDENCIES_TUPLE, value);
}

export function normalizeScopedPolicyBundleV2Proof(value: ScopedPolicyBundleV2Proof): ScopedPolicyBundleV2Proof {
  return normalized(SCOPED_POLICY_BUNDLE_V2_PROOF_TUPLE, value);
}
export function encodeScopedPolicyBundleV2Proof(value: ScopedPolicyBundleV2Proof): Hex {
  return encode(SCOPED_POLICY_BUNDLE_V2_PROOF_TUPLE, value);
}
export function decodeScopedPolicyBundleV2Proof(value: Hex): ScopedPolicyBundleV2Proof {
  return decode(SCOPED_POLICY_BUNDLE_V2_PROOF_TUPLE, value);
}

export function normalizeScopedPolicyBundleV2Admission(value: ScopedPolicyBundleV2Admission): ScopedPolicyBundleV2Admission {
  return normalized(SCOPED_POLICY_BUNDLE_V2_ADMISSION_TUPLE, value);
}
export function encodeScopedPolicyBundleV2Admission(value: ScopedPolicyBundleV2Admission): Hex {
  return encode(SCOPED_POLICY_BUNDLE_V2_ADMISSION_TUPLE, value);
}
export function decodeScopedPolicyBundleV2Admission(value: Hex): ScopedPolicyBundleV2Admission {
  return decode(SCOPED_POLICY_BUNDLE_V2_ADMISSION_TUPLE, value);
}

export function normalizeScopedPolicyBundleV2Progress(value: ScopedPolicyBundleV2Progress): ScopedPolicyBundleV2Progress {
  return normalized(SCOPED_POLICY_BUNDLE_V2_PROGRESS_TUPLE, value);
}
export function encodeScopedPolicyBundleV2Progress(value: ScopedPolicyBundleV2Progress): Hex {
  return encode(SCOPED_POLICY_BUNDLE_V2_PROGRESS_TUPLE, value);
}
export function decodeScopedPolicyBundleV2Progress(value: Hex): ScopedPolicyBundleV2Progress {
  return decode(SCOPED_POLICY_BUNDLE_V2_PROGRESS_TUPLE, value);
}

export function normalizeScopedPolicyBundleV2Refresh(value: ScopedPolicyBundleV2Refresh): ScopedPolicyBundleV2Refresh {
  return normalized(SCOPED_POLICY_BUNDLE_V2_REFRESH_TUPLE, value);
}
export function encodeScopedPolicyBundleV2Refresh(value: ScopedPolicyBundleV2Refresh): Hex {
  return encode(SCOPED_POLICY_BUNDLE_V2_REFRESH_TUPLE, value);
}
export function decodeScopedPolicyBundleV2Refresh(value: Hex): ScopedPolicyBundleV2Refresh {
  return decode(SCOPED_POLICY_BUNDLE_V2_REFRESH_TUPLE, value);
}

export function normalizeScopedPolicyBundleV2Evidence(value: ScopedPolicyBundleV2Evidence): ScopedPolicyBundleV2Evidence {
  return normalized(SCOPED_POLICY_BUNDLE_V2_EVIDENCE_TUPLE, value);
}
export function encodeScopedPolicyBundleV2Evidence(value: ScopedPolicyBundleV2Evidence): Hex {
  return encode(SCOPED_POLICY_BUNDLE_V2_EVIDENCE_TUPLE, value);
}
export function decodeScopedPolicyBundleV2Evidence(value: Hex): ScopedPolicyBundleV2Evidence {
  return decode(SCOPED_POLICY_BUNDLE_V2_EVIDENCE_TUPLE, value);
}

export function normalizeScopedPolicyBundleV2OriginalEvidence(value: ScopedPolicyBundleV2OriginalEvidence): ScopedPolicyBundleV2OriginalEvidence {
  return normalized(SCOPED_POLICY_BUNDLE_V2_ORIGINAL_EVIDENCE_TUPLE, value);
}
export function encodeScopedPolicyBundleV2OriginalEvidence(value: ScopedPolicyBundleV2OriginalEvidence): Hex {
  return encode(SCOPED_POLICY_BUNDLE_V2_ORIGINAL_EVIDENCE_TUPLE, value);
}
export function decodeScopedPolicyBundleV2OriginalEvidence(value: Hex): ScopedPolicyBundleV2OriginalEvidence {
  return decode(SCOPED_POLICY_BUNDLE_V2_ORIGINAL_EVIDENCE_TUPLE, value);
}

export function normalizeScopedPolicyBundleV2ExternalCoverage(value: ScopedPolicyBundleV2ExternalCoverage): ScopedPolicyBundleV2ExternalCoverage {
  return normalized(SCOPED_POLICY_BUNDLE_V2_EXTERNAL_COVERAGE_TUPLE, value);
}
export function encodeScopedPolicyBundleV2ExternalCoverage(value: ScopedPolicyBundleV2ExternalCoverage): Hex {
  return encode(SCOPED_POLICY_BUNDLE_V2_EXTERNAL_COVERAGE_TUPLE, value);
}
export function decodeScopedPolicyBundleV2ExternalCoverage(value: Hex): ScopedPolicyBundleV2ExternalCoverage {
  return decode(SCOPED_POLICY_BUNDLE_V2_EXTERNAL_COVERAGE_TUPLE, value);
}

export function normalizeScopedPolicyBundleV2OnchainCoverage(value: ScopedPolicyBundleV2OnchainCoverage): ScopedPolicyBundleV2OnchainCoverage {
  return normalized(SCOPED_POLICY_BUNDLE_V2_ONCHAIN_COVERAGE_TUPLE, value);
}
export function encodeScopedPolicyBundleV2OnchainCoverage(value: ScopedPolicyBundleV2OnchainCoverage): Hex {
  return encode(SCOPED_POLICY_BUNDLE_V2_ONCHAIN_COVERAGE_TUPLE, value);
}
export function decodeScopedPolicyBundleV2OnchainCoverage(value: Hex): ScopedPolicyBundleV2OnchainCoverage {
  return decode(SCOPED_POLICY_BUNDLE_V2_ONCHAIN_COVERAGE_TUPLE, value);
}

export function normalizeScopedPolicyBundleV2Coordinates(value: ScopedPolicyBundleV2Coordinates): ScopedPolicyBundleV2Coordinates {
  exact(value, ["chainId", "core", "bundle"], "Bundle coordinates");
  return Object.freeze({ chainId: uint(value.chainId), core: address(value.core, true), bundle: address(value.bundle, true) });
}

export function scopedPolicyBundleV2DependencyHash(value: ScopedPolicyBundleV2Dependencies): Hex {
  return keccak256(encodeScopedPolicyBundleV2Dependencies(value)) as Hex;
}

export function validateScopedPolicyBundleV2Dependencies(
  coordinates: ScopedPolicyBundleV2Coordinates,
  value: ScopedPolicyBundleV2Dependencies,
): ScopedPolicyBundleV2Dependencies {
  const c = normalizeScopedPolicyBundleV2Coordinates(coordinates);
  const d = normalizeScopedPolicyBundleV2Dependencies(value);
  if (d.chainId !== c.chainId || d.targets[0] !== c.core || d.readGas < 50000n || d.archiveGas < d.readGas) {
    throw Error("Bundle dependency coordinates or gas floors differ");
  }
  d.targets.forEach(value => address(value, true)); d.codeHashes.forEach(nonzero);
  return d;
}

/** Hash of supplied original archive environments. This does not pin runtime code or read an environment. */
export function scopedPolicyBundleV2EnvironmentHash(
  dependencies: ScopedPolicyBundleV2Dependencies,
  onchainHash: Hex,
  epoch: bigint,
  externalHash: Hex,
  revision: bigint,
): Hex {
  const d = normalizeScopedPolicyBundleV2Dependencies(dependencies);
  const e = uint(epoch, 64);
  if (e === 0n) throw Error("Original onchain validation epoch is nonzero");
  return hash(["bytes32", SCOPED_POLICY_BUNDLE_V2_DEPENDENCIES_TUPLE, "bytes32", "uint64", "bytes32", "uint64"],
    [id("6529STREAM_BUNDLE_IMMUTABLE_STOP_ENVIRONMENT_V1"), d, nonzero(onchainHash), e, nonzero(externalHash), uint(revision, 64)]);
}

export function scopedPolicyBundleV2ItemChain(
  previous: Hex, planId: Hex, index: bigint, itemHash: Hex, admission: ScopedPolicyBundleV2Admission,
): Hex {
  return hash(["bytes32", "bytes32", "bytes32", "uint64", "bytes32", SCOPED_POLICY_BUNDLE_V2_ADMISSION_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_BUNDLE_COVERED_ITEM_V2"), bytes(previous, 32), bytes(planId, 32), uint(index, 64),
      bytes(itemHash, 32), normalizeScopedPolicyBundleV2Admission(admission)]);
}

export function scopedPolicyBundleV2ObservationChain(
  previous: Hex, index: bigint, itemHash: Hex, observation: Hex,
): Hex {
  return hash(["bytes32", "bytes32", "uint64", "bytes32", "bytes32"],
    [id("6529STREAM_SCOPED_POLICY_BUNDLE_CURRENT_OBSERVATION_V2"), bytes(previous, 32), uint(index, 64),
      bytes(itemHash, 32), bytes(observation, 32)]);
}

export function scopedPolicyBundleV2RefreshId(
  coordinates: ScopedPolicyBundleV2Coordinates,
  dependencyHash: Hex,
  planId: Hex,
  environment: Hex,
): Hex {
  const c = normalizeScopedPolicyBundleV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_SCOPED_POLICY_BUNDLE_REFRESH_V2"), c.chainId, c.bundle,
      bytes(dependencyHash, 32), bytes(planId, 32), bytes(environment, 32)]);
}

export function scopedPolicyBundleV2CoverageHash(
  coordinates: ScopedPolicyBundleV2Coordinates,
  dependencyHash: Hex,
  inventoryEvidence: ScopedPolicyBundleV2InventoryEvidence,
  bundleEvidence: ScopedPolicyBundleV2Evidence,
): Hex {
  const c = normalizeScopedPolicyBundleV2Coordinates(coordinates);
  const original = inventory.normalizeScopedPolicyInventoryV2Evidence(inventoryEvidence);
  const e = normalizeScopedPolicyBundleV2Evidence(bundleEvidence);
  return hash(["bytes32", "uint256", "address", "bytes32", "bytes32",
    inventory.SCOPED_POLICY_INVENTORY_V2_EVIDENCE_TUPLE, SCOPED_POLICY_BUNDLE_V2_EVIDENCE_TUPLE],
  [id("6529STREAM_SCOPED_POLICY_BUNDLE_ARCHIVE_COVERAGE_V2"), c.chainId, c.bundle,
    bytes(dependencyHash, 32), SCOPED_POLICY_BUNDLE_V2_PROFILE, original,
    { ...e, coverage: { ...e.coverage, bundleCoverageHash: ZERO } }]);
}

export function validateScopedPolicyBundleV2Evidence(
  coordinates: ScopedPolicyBundleV2Coordinates,
  dependencyHash: Hex,
  inventoryEvidence: ScopedPolicyBundleV2InventoryEvidence,
  bundleEvidence: ScopedPolicyBundleV2Evidence,
): ScopedPolicyBundleV2Evidence {
  const c = normalizeScopedPolicyBundleV2Coordinates(coordinates);
  const original = inventory.normalizeScopedPolicyInventoryV2Evidence(inventoryEvidence);
  const e = normalizeScopedPolicyBundleV2Evidence(bundleEvidence);
  inventory.validateScopedPolicyInventoryV2Scope(e.scope);
  const p = e.coverage, old = original.inventory;
  [dependencyHash, old.planId, old.renderCriticalEvidenceHash].forEach(nonzero);
  if (encode(SCOPED_POLICY_BUNDLE_V2_SCOPE_TUPLE, original.scope) !== encode(SCOPED_POLICY_BUNDLE_V2_SCOPE_TUPLE, e.scope)
    || p.inventoryPlan !== old.planId || p.renderCriticalEvidenceHash !== old.renderCriticalEvidenceHash
    || p.itemCount !== old.itemCount || p.itemCount === 0n
    || p.bundleCoverageHash !== scopedPolicyBundleV2CoverageHash(c, dependencyHash, original, e)) {
    throw Error("Bundle evidence differs from supplied inventory/commitment");
  }
  return e;
}

const RAW = id("RAW_BYTES") as Hex;
const JCS = id("RFC8785_JCS") as Hex;
const intrinsic = (kind: bigint): boolean => kind === 6n || kind === 7n || kind === 8n || kind === 9n || kind === 11n;

function applicability(item: ScopedPolicyBundleV2Item): void {
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
export function validateScopedPolicyBundleV2Proof(
  item: ScopedPolicyBundleV2Item,
  proof: ScopedPolicyBundleV2Proof,
): ScopedPolicyBundleV2Proof {
  const row = inventory.normalizeScopedPolicyInventoryV2Item(item);
  const p = normalizeScopedPolicyBundleV2Proof(proof);
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
      || (row.kind !== 5n && row.kind !== 10n && row.canonicalizationId !== RAW && row.canonicalizationId !== JCS)) {
      throw Error("Unsupported original inventory correspondence");
    }
  }
  return p;
}

export interface ScopedPolicyBundleV2Correspondence {
  readonly contentHash: Hex;
  readonly sha256Digest: Hex;
  readonly canonicalizationId: Hex;
  readonly byteSize: bigint;
}

export function validateScopedPolicyBundleV2Correspondence(
  item: ScopedPolicyBundleV2Item,
  value: ScopedPolicyBundleV2Correspondence,
): ScopedPolicyBundleV2Item {
  const row = inventory.normalizeScopedPolicyInventoryV2Item(item);
  exact(value, ["contentHash", "sha256Digest", "canonicalizationId", "byteSize"], "Object correspondence");
  const size = uint(value.byteSize, 64), canon = bytes(value.canonicalizationId, 32);
  const keccak = bytes(value.contentHash, 32), sha = bytes(value.sha256Digest, 32);
  if (row.digest.length !== 66 || row.canonicalizationId !== canon || size === 0n
    || (row.byteSize !== 0n && row.byteSize !== size)
    || (row.kind !== 5n && row.kind !== 10n && canon !== RAW && canon !== JCS)) throw Error("Object correspondence differs");
  const expected = row.algorithm === 1n ? keccak : row.algorithm === 2n ? sha : ZERO;
  if (expected === ZERO || row.digest !== expected) throw Error("Unsupported algorithm or mismatched object digest");
  return row;
}

function empty<T>(tuple: string): T {
  const type = ParamType.from(tuple);
  return decode<T>(tuple, `0x${"00".repeat(type.components!.length * 32)}` as Hex);
}

export function scopedPolicyBundleV2IntrinsicAdmission(
  item: ScopedPolicyBundleV2Item,
  proof: ScopedPolicyBundleV2Proof,
  immutablePartsHash: Hex = ZERO,
): ScopedPolicyBundleV2Admission {
  const row = inventory.normalizeScopedPolicyInventoryV2Item(item);
  const p = validateScopedPolicyBundleV2Proof(row, proof);
  if (!intrinsic(row.kind)) throw Error("Item requires original archive admission");
  const parts = bytes(immutablePartsHash, 32);
  if (row.kind !== 6n && parts !== ZERO) throw Error("Incorrect intrinsic parts commitment");
  const bundle = row.kind === 6n
    ? hash(["bytes32", SCOPED_POLICY_BUNDLE_V2_ITEM_TUPLE, "bytes32"], [id("STATE_RETAINED_ORIGINAL_AUTHORIZATION"), row, parts])
    : hash(["bytes32", SCOPED_POLICY_BUNDLE_V2_ITEM_TUPLE], [id("EXPLICIT_INVENTORY_APPLICABILITY"), row]);
  return Object.freeze({ proof: p, originalBundleHash: bundle, immutablePartsHash: parts,
    externalOriginal: empty<ScopedPolicyBundleV2ExternalCoverage>(SCOPED_POLICY_BUNDLE_V2_EXTERNAL_COVERAGE_TUPLE),
    onchainOriginal: empty<ScopedPolicyBundleV2OnchainCoverage>(SCOPED_POLICY_BUNDLE_V2_ONCHAIN_COVERAGE_TUPLE) });
}

/** Checks the supplied retained Admission, without asserting original archive-byte or current-pair readback. */
export function validateScopedPolicyBundleV2Admission(
  artistId: Hex,
  item: ScopedPolicyBundleV2Item,
  admission: ScopedPolicyBundleV2Admission,
): ScopedPolicyBundleV2Admission {
  const artist = nonzero(artistId), row = inventory.normalizeScopedPolicyInventoryV2Item(item);
  const a = normalizeScopedPolicyBundleV2Admission(admission);
  validateScopedPolicyBundleV2Proof(row, a.proof);
  nonzero(a.originalBundleHash);
  if (intrinsic(row.kind)) {
    if (encodeScopedPolicyBundleV2Admission(a) !== encodeScopedPolicyBundleV2Admission(
      scopedPolicyBundleV2IntrinsicAdmission(row, a.proof, a.immutablePartsHash))) throw Error("Intrinsic admission differs");
  } else if (a.proof.backend === 1n) {
    const c = a.externalOriginal;
    if (c.coverageHash !== a.proof.coverageHash || c.objectHash !== a.proof.objectHash || c.artistId !== artist
      || a.immutablePartsHash !== ZERO
      || encodeScopedPolicyBundleV2OnchainCoverage(a.onchainOriginal) !== encodeScopedPolicyBundleV2OnchainCoverage(
        empty<ScopedPolicyBundleV2OnchainCoverage>(SCOPED_POLICY_BUNDLE_V2_ONCHAIN_COVERAGE_TUPLE))) throw Error("External admission fields differ");
    [c.firstReceiptHash, c.secondReceiptHash, c.firstFixityHash, c.secondFixityHash].forEach(nonzero);
    validateScopedPolicyBundleV2Correspondence(row, { contentHash: c.contentHash, sha256Digest: c.sha256Digest,
      canonicalizationId: row.canonicalizationId, byteSize: c.byteSize });
  } else {
    const c = a.onchainOriginal;
    if (c.completionHash !== a.proof.coverageHash || c.artifactHash !== a.proof.objectHash || c.artistId !== artist
      || (row.schemaId !== ZERO && row.schemaId !== c.schemaId)
      || encodeScopedPolicyBundleV2ExternalCoverage(a.externalOriginal) !== encodeScopedPolicyBundleV2ExternalCoverage(
        empty<ScopedPolicyBundleV2ExternalCoverage>(SCOPED_POLICY_BUNDLE_V2_EXTERNAL_COVERAGE_TUPLE))) throw Error("Onchain admission fields differ");
    validateScopedPolicyBundleV2Correspondence(row, { contentHash: c.contentHash, sha256Digest: ZERO,
      canonicalizationId: c.canonicalizationId, byteSize: c.byteLength });
  }
  return a;
}

export function validateScopedPolicyBundleV2NextItem(
  progress: ScopedPolicyBundleV2Progress,
  segment: ScopedPolicyBundleV2Segment,
  item: ScopedPolicyBundleV2Item,
  nextLink: Hex,
): void {
  const p = normalizeScopedPolicyBundleV2Progress(progress);
  const s = inventory.validateScopedPolicyInventoryV2Segment(segment);
  if (p.complete || inventory.scopedPolicyInventoryV2Link(s.key, s.itemCount, p.segmentItemIndex, item, nextLink) !== p.nextLink) {
    throw Error("Item does not match the original next occurrence");
  }
}

export function validateScopedPolicyBundleV2EmptySegment(
  progress: ScopedPolicyBundleV2Progress,
  segment: ScopedPolicyBundleV2Segment,
): void {
  const p = normalizeScopedPolicyBundleV2Progress(progress);
  const s = inventory.validateScopedPolicyInventoryV2Segment(segment);
  if (p.complete || s.itemCount !== 0n || s.firstLink !== ZERO || p.segmentItemIndex !== 0n || p.nextLink !== ZERO) {
    throw Error("Original empty segment is not ready");
  }
}

export type ScopedPolicyBundleV2Request =
  | { readonly kind: "beginCoverage" | "coverEmptySegment" | "beginRefresh"; readonly id: Hex }
  | {
    readonly kind: "coverNext";
    readonly id: Hex;
    readonly item: ScopedPolicyBundleV2Item;
    readonly nextLink: Hex;
    readonly proof: ScopedPolicyBundleV2Proof;
  }
  | { readonly kind: "refreshNext"; readonly id: Hex; readonly expectedIndex: bigint };

export interface ScopedPolicyBundleV2Call {
  readonly coordinates: ScopedPolicyBundleV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyBundleV2Request;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export function normalizeScopedPolicyBundleV2Request(value: ScopedPolicyBundleV2Request): ScopedPolicyBundleV2Request {
  switch (value?.kind) {
    case "beginCoverage": case "coverEmptySegment": case "beginRefresh":
      exact(value, ["kind", "id"], "Bundle step");
      return Object.freeze({ kind: value.kind, id: nonzero(value.id) });
    case "coverNext": {
      exact(value, ["kind", "id", "item", "nextLink", "proof"], "Bundle occurrence");
      const item = inventory.normalizeScopedPolicyInventoryV2Item(value.item);
      return Object.freeze({ kind: value.kind, id: nonzero(value.id), item,
        nextLink: bytes(value.nextLink, 32), proof: validateScopedPolicyBundleV2Proof(item, value.proof) });
    }
    case "refreshNext":
      exact(value, ["kind", "id", "expectedIndex"], "Bundle refresh");
      return Object.freeze({ kind: value.kind, id: nonzero(value.id), expectedIndex: uint(value.expectedIndex, 64) });
    default: throw Error("Unknown original bundle write kind");
  }
}

export function prepareScopedPolicyBundleV2Call(
  coordinates: ScopedPolicyBundleV2Coordinates,
  caller: Address,
  request: ScopedPolicyBundleV2Request,
): ScopedPolicyBundleV2Call {
  const c = normalizeScopedPolicyBundleV2Coordinates(coordinates);
  const q = normalizeScopedPolicyBundleV2Request(request);
  const args = q.kind === "coverNext" ? [q.id, q.item, q.nextLink, q.proof]
    : q.kind === "refreshNext" ? [q.id, q.expectedIndex] : [q.id];
  return Object.freeze({ coordinates: c, caller: address(caller, true), request: q, factsVerified: false,
    call: Object.freeze({ to: c.bundle, value: 0n, data: bytes(bundleInterface.encodeFunctionData(q.kind, args)) }) });
}

export function normalizeScopedPolicyBundleV2Call(value: ScopedPolicyBundleV2Call): ScopedPolicyBundleV2Call {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Bundle call");
  exact(value.call, ["to", "value", "data"], "CALL");
  const rebuilt = prepareScopedPolicyBundleV2Call(value.coordinates, value.caller, value.request);
  if (stable(value) !== stable(rebuilt)) throw Error("Bundle call differs from reconstruction");
  return rebuilt;
}

export type ScopedPolicyBundleV2ReadRequest =
  | {
    readonly kind: "PROFILE" | "scopedPolicyBundleArchiveProfile" | "core" | "metadataHost" | "renderCriticalInventory"
      | "artifactCoverage" | "externalCoverage" | "deploymentChainId" | "coreCodeHash" | "metadataCodeHash"
      | "inventoryCodeHash" | "dependencies" | "dependencyHash";
  }
  | { readonly kind: "supportsInterface"; readonly interfaceId: Hex }
  | { readonly kind: "bundleEvidence" | "progress" | "requireFullCurrentCoverage"; readonly id: Hex }
  | { readonly kind: "refresh"; readonly key: Hex }
  | { readonly kind: "admittedItem"; readonly id: Hex; readonly index: bigint }
  | { readonly kind: "requireCoverage"; readonly scope: ScopedPolicyBundleV2Scope; readonly id: Hex; readonly expectedHash: Hex };

export interface ScopedPolicyBundleV2Read {
  readonly coordinates: ScopedPolicyBundleV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyBundleV2ReadRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export function prepareScopedPolicyBundleV2Read(
  coordinates: ScopedPolicyBundleV2Coordinates,
  caller: Address,
  request: ScopedPolicyBundleV2ReadRequest,
): ScopedPolicyBundleV2Read {
  const c = normalizeScopedPolicyBundleV2Coordinates(coordinates);
  let q: ScopedPolicyBundleV2ReadRequest, args: readonly unknown[];
  switch (request?.kind) {
    case "PROFILE": case "scopedPolicyBundleArchiveProfile": case "core": case "metadataHost": case "renderCriticalInventory":
    case "artifactCoverage": case "externalCoverage": case "deploymentChainId": case "coreCodeHash": case "metadataCodeHash":
    case "inventoryCodeHash": case "dependencies": case "dependencyHash":
      exact(request, ["kind"], "Bundle getter"); q = Object.freeze({ kind: request.kind }); args = []; break;
    case "supportsInterface":
      exact(request, ["kind", "interfaceId"], "Interface getter");
      q = Object.freeze({ kind: request.kind, interfaceId: bytes(request.interfaceId, 4) }); args = [q.interfaceId]; break;
    case "bundleEvidence": case "progress": case "requireFullCurrentCoverage":
      exact(request, ["kind", "id"], "Bundle retained getter");
      q = Object.freeze({ kind: request.kind, id: bytes(request.id, 32) }); args = [q.id]; break;
    case "refresh":
      exact(request, ["kind", "key"], "Refresh getter");
      q = Object.freeze({ kind: request.kind, key: bytes(request.key, 32) }); args = [q.key]; break;
    case "admittedItem":
      exact(request, ["kind", "id", "index"], "Admission getter");
      q = Object.freeze({ kind: request.kind, id: bytes(request.id, 32), index: uint(request.index, 64) }); args = [q.id, q.index]; break;
    case "requireCoverage":
      exact(request, ["kind", "scope", "id", "expectedHash"], "Bundle coverage getter");
      q = Object.freeze({ kind: request.kind, scope: inventory.validateScopedPolicyInventoryV2Scope(request.scope),
        id: bytes(request.id, 32), expectedHash: bytes(request.expectedHash, 32) }); args = [q.scope, q.id, q.expectedHash]; break;
    default: throw Error("Unknown original bundle read kind");
  }
  return Object.freeze({ coordinates: c, caller: address(caller), request: q, factsVerified: false,
    call: Object.freeze({ to: c.bundle, value: 0n, data: bytes(bundleInterface.encodeFunctionData(q.kind, args)) }) });
}

export function normalizeScopedPolicyBundleV2Read(value: ScopedPolicyBundleV2Read): ScopedPolicyBundleV2Read {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Bundle read");
  exact(value.call, ["to", "value", "data"], "Read CALL");
  const rebuilt = prepareScopedPolicyBundleV2Read(value.coordinates, value.caller, value.request);
  if (stable(value) !== stable(rebuilt)) throw Error("Bundle read differs from reconstruction");
  return rebuilt;
}

export interface ScopedPolicyBundleV2Artifact {
  readonly artistId: Hex;
  readonly schemaId: Hex;
  readonly canonicalizationId: Hex;
  readonly hashAlgorithm: bigint;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
  readonly chunkHashes: readonly Hex[];
  readonly chunkLengths: readonly bigint[];
}

export const SCOPED_POLICY_BUNDLE_V2_ARTIFACT_TUPLE = "(bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, uint16 hashAlgorithm, bytes32 contentHash, uint64 byteLength, bytes32[] chunkHashes, uint32[] chunkLengths)";
export function normalizeScopedPolicyBundleV2Artifact(value: ScopedPolicyBundleV2Artifact): ScopedPolicyBundleV2Artifact {
  return normalized(SCOPED_POLICY_BUNDLE_V2_ARTIFACT_TUPLE, value);
}
export function encodeScopedPolicyBundleV2Artifact(value: ScopedPolicyBundleV2Artifact): Hex {
  return encode(SCOPED_POLICY_BUNDLE_V2_ARTIFACT_TUPLE, value);
}
export function decodeScopedPolicyBundleV2Artifact(value: Hex): ScopedPolicyBundleV2Artifact {
  return decode(SCOPED_POLICY_BUNDLE_V2_ARTIFACT_TUPLE, value);
}

export interface ScopedPolicyBundleV2ObjectIdentity {
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

export const SCOPED_POLICY_BUNDLE_V2_OBJECT_IDENTITY_TUPLE = "(bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 formatId, bytes32 formatCatalogId, bytes32 formatCatalogHash)";
export function normalizeScopedPolicyBundleV2ObjectIdentity(value: ScopedPolicyBundleV2ObjectIdentity): ScopedPolicyBundleV2ObjectIdentity {
  return normalized(SCOPED_POLICY_BUNDLE_V2_OBJECT_IDENTITY_TUPLE, value);
}
export function encodeScopedPolicyBundleV2ObjectIdentity(value: ScopedPolicyBundleV2ObjectIdentity): Hex {
  return encode(SCOPED_POLICY_BUNDLE_V2_OBJECT_IDENTITY_TUPLE, value);
}
export function decodeScopedPolicyBundleV2ObjectIdentity(value: Hex): ScopedPolicyBundleV2ObjectIdentity {
  return decode(SCOPED_POLICY_BUNDLE_V2_OBJECT_IDENTITY_TUPLE, value);
}

export interface ScopedPolicyBundleV2CurrentPair {
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

export const SCOPED_POLICY_BUNDLE_V2_CURRENT_PAIR_TUPLE = "(bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash)";
export function normalizeScopedPolicyBundleV2CurrentPair(value: ScopedPolicyBundleV2CurrentPair): ScopedPolicyBundleV2CurrentPair {
  return normalized(SCOPED_POLICY_BUNDLE_V2_CURRENT_PAIR_TUPLE, value);
}
export function encodeScopedPolicyBundleV2CurrentPair(value: ScopedPolicyBundleV2CurrentPair): Hex {
  return encode(SCOPED_POLICY_BUNDLE_V2_CURRENT_PAIR_TUPLE, value);
}
export function decodeScopedPolicyBundleV2CurrentPair(value: Hex): ScopedPolicyBundleV2CurrentPair {
  return decode(SCOPED_POLICY_BUNDLE_V2_CURRENT_PAIR_TUPLE, value);
}

export function scopedPolicyBundleV2CurrentPairHash(
  original: ScopedPolicyBundleV2ExternalCoverage,
  current: ScopedPolicyBundleV2CurrentPair,
): Hex {
  const o = normalizeScopedPolicyBundleV2ExternalCoverage(original);
  const c = normalizeScopedPolicyBundleV2CurrentPair(current);
  for (const key of Object.keys(c) as (keyof ScopedPolicyBundleV2CurrentPair)[]) {
    if (key !== "firstFixityHash" && key !== "secondFixityHash" && c[key] !== o[key]) {
      throw Error("Current pair changes an immutable original field");
    }
  }
  nonzero(c.firstFixityHash); nonzero(c.secondFixityHash);
  return keccak256(encodeScopedPolicyBundleV2CurrentPair(c)) as Hex;
}

export function scopedPolicyBundleV2ExternalOriginalHash(
  dependencies: ScopedPolicyBundleV2Dependencies,
  original: ScopedPolicyBundleV2ExternalCoverage,
  originalBundleHashes: readonly [Hex, Hex, Hex, Hex, Hex],
): Hex {
  const d = normalizeScopedPolicyBundleV2Dependencies(dependencies);
  const hashes = list(originalBundleHashes, 5).map(value => bytes(value, 32));
  return hash(["address", "bytes32", SCOPED_POLICY_BUNDLE_V2_EXTERNAL_COVERAGE_TUPLE, "bytes32[5]"],
    [d.targets[4], d.codeHashes[4], normalizeScopedPolicyBundleV2ExternalCoverage(original), hashes]);
}

export function scopedPolicyBundleV2OnchainOriginalHash(
  dependencies: ScopedPolicyBundleV2Dependencies,
  original: ScopedPolicyBundleV2OnchainCoverage,
  artifact: ScopedPolicyBundleV2Artifact,
  immutablePartsHash: Hex,
  originalPartsChain: Hex,
): Hex {
  const d = normalizeScopedPolicyBundleV2Dependencies(dependencies);
  return hash(["address", "bytes32", SCOPED_POLICY_BUNDLE_V2_ONCHAIN_COVERAGE_TUPLE,
    SCOPED_POLICY_BUNDLE_V2_ARTIFACT_TUPLE, "bytes32", "bytes32"],
  [d.targets[3], d.codeHashes[3], normalizeScopedPolicyBundleV2OnchainCoverage(original),
    normalizeScopedPolicyBundleV2Artifact(artifact), bytes(immutablePartsHash, 32), bytes(originalPartsChain, 32)]);
}

export function scopedPolicyBundleV2PartChain(
  previous: Hex, index: bigint, pointer: Address, codeHash: Hex, chunkHash: Hex, chunkLength: bigint,
): Hex {
  return hash(["bytes32", "uint32", "address", "bytes32", "bytes32", "uint32"],
    [bytes(previous, 32), uint(index, 32), address(pointer), bytes(codeHash, 32), bytes(chunkHash, 32), uint(chunkLength, 32)]);
}

export function scopedPolicyBundleV2OriginalPartChain(previous: Hex, index: bigint, originalBundleHash: Hex): Hex {
  return hash(["bytes32", "uint32", "bytes32"], [bytes(previous, 32), uint(index, 32), bytes(originalBundleHash, 32)]);
}

export interface ScopedPolicyBundleV2StateParts {
  readonly source: Address;
  readonly sourceCodeHash: Hex;
  readonly sourceRecord: Hex;
  readonly pointer: Address;
  readonly pointerCodeHash: Hex;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
  readonly blockNumber: bigint;
}

export function scopedPolicyBundleV2StatePartsHash(value: ScopedPolicyBundleV2StateParts): Hex {
  exact(value, ["source", "sourceCodeHash", "sourceRecord", "pointer", "pointerCodeHash", "contentHash", "byteLength", "blockNumber"], "Retained state parts");
  return hash(["address", "bytes32", "bytes32", "address", "bytes32", "bytes32", "uint32", "uint64"],
    [address(value.source), bytes(value.sourceCodeHash, 32), bytes(value.sourceRecord, 32), address(value.pointer),
      bytes(value.pointerCodeHash, 32), bytes(value.contentHash, 32), uint(value.byteLength, 32), uint(value.blockNumber, 64)]);
}
