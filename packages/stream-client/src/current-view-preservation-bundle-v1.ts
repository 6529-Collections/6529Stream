import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes, hexlify, sha256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import * as original from "./current-scoped-policy-inventory-v2.js";
import * as retrieval from "./current-view-retrieval-v1.js";
import * as inventory from "./current-view-preservation-inventory-v1.js";

/** Original ABI157. Supplied values do not prove live source or archive authority. */
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_SOURCE = "a2973d360f6ab18881c04d58193f855704ec56d3";
/** Client allocation ceilings, not protocol item-count limits. */
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_MAX_BYTES = 2097152;
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_MAX_ROWS = 8192;
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_MAX_HISTORY_BYTES = 16777216;
export interface CurrentViewPreservationBundleV1Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly bundle: Address;
}

export interface CurrentViewPreservationBundleV1Dependencies {
  readonly targets: readonly [Address, Address, Address, Address, Address, Address];
  readonly codeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex];
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly archiveGas: bigint;
}

export interface CurrentViewPreservationBundleV1Evidence {
  readonly scope: CurrentViewPreservationBundleV1Scope;
  readonly coverage: CurrentViewPreservationBundleV1Coverage;
}

export interface CurrentViewPreservationBundleV1Scope {
  readonly scopeType: bigint;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly scopeId: Hex;
}

export interface CurrentViewPreservationBundleV1Coverage {
  readonly inventoryPlan: Hex;
  readonly renderCriticalEvidenceHash: Hex;
  readonly itemCount: bigint;
  readonly evidenceChainHash: Hex;
  readonly bundleCoverageHash: Hex;
}

export interface CurrentViewPreservationBundleV1Admission {
  readonly proof: CurrentViewPreservationBundleV1Proof;
  readonly originalBundleHash: Hex;
  readonly immutablePartsHash: Hex;
  readonly externalOriginal: CurrentViewPreservationBundleV1ExternalCoverage;
  readonly onchainOriginal: CurrentViewPreservationBundleV1OnchainCoverage;
}

export interface CurrentViewPreservationBundleV1Proof {
  readonly backend: bigint;
  readonly coverageHash: Hex;
  readonly objectHash: Hex;
}

export interface CurrentViewPreservationBundleV1ExternalCoverage {
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

export interface CurrentViewPreservationBundleV1OnchainCoverage {
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

export interface CurrentViewPreservationBundleV1Item {
  readonly kind: bigint;
  readonly role: Hex;
  readonly source: Address;
  readonly sourceRecord: Hex;
  readonly sourceIndex: bigint;
  readonly algorithm: bigint;
  readonly canonicalizationId: Hex;
  readonly digest: Hex;
  readonly uri: string;
  readonly byteSize: bigint;
  readonly schemaId: Hex;
  readonly formatId: Hex;
  readonly catalogId: Hex;
  readonly catalogHash: Hex;
  readonly objectHash: Hex;
  readonly originalCoverageHash: Hex;
  readonly provenanceHash: Hex;
}

export interface CurrentViewPreservationBundleV1Progress {
  readonly segmentIndex: bigint;
  readonly segmentItemIndex: bigint;
  readonly itemCount: bigint;
  readonly nextLink: Hex;
  readonly segmentChainHash: Hex;
  readonly evidenceChainHash: Hex;
  readonly environmentHash: Hex;
  readonly complete: boolean;
}

export interface CurrentViewPreservationBundleV1Refresh {
  readonly environmentHash: Hex;
  readonly nextIndex: bigint;
  readonly currentObservationChain: Hex;
  readonly complete: boolean;
}

export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_DEPENDENCIES_TUPLE = "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)";
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_EVIDENCE_TUPLE = "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage)";
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_SCOPE_TUPLE = "(uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)";
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_COVERAGE_TUPLE = "(bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash)";
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ADMISSION_TUPLE = "((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal)";
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROOF_TUPLE = "(uint8 backend, bytes32 coverageHash, bytes32 objectHash)";
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_EXTERNAL_COVERAGE_TUPLE = "(bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash)";
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ONCHAIN_COVERAGE_TUPLE = "(bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash)";
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ITEM_TUPLE = "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)";
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROGRESS_TUPLE = "(uint64 segmentIndex, uint64 segmentItemIndex, uint64 itemCount, bytes32 nextLink, bytes32 segmentChainHash, bytes32 evidenceChainHash, bytes32 environmentHash, bool complete)";
export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_REFRESH_TUPLE = "(bytes32 environmentHash, uint64 nextIndex, bytes32 currentObservationChain, bool complete)";

export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ABI = Object.freeze([
  "error InvalidInventorySegment()",
  "error InvalidMetadataScope()",
  "error InvalidViewRetrieval()",
  "error InventoryIncomplete()",
  "error InventoryRead(address target)",
  "error InventorySourceChanged()",
  "event ViewPreservationBundleCoverageCompleted(uint16 schemaVersion, bytes32 indexed inventoryPlan, bytes32 indexed bundleCoverageHash, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage) evidence)",
  "event ViewPreservationBundleCoverageStarted(uint16 schemaVersion, bytes32 indexed inventoryPlan, bytes32 indexed renderCriticalEvidenceHash)",
  "event ViewPreservationBundleItemAdmitted(uint16 schemaVersion, bytes32 indexed inventoryPlan, uint64 indexed index, bytes32 itemHash, ((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal) admission)",
  "event ViewPreservationBundleRefreshAdvanced(uint16 schemaVersion, bytes32 indexed inventoryPlan, bytes32 indexed refreshId, uint64 nextIndex, bytes32 observationChain, bool complete)",
  "function PROFILE() view returns (bytes32)",
  "function admittedItem(bytes32 id, uint64 index) view returns ((uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash), ((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal))",
  "function artifactCoverage() view returns (address)",
  "function beginCoverage(bytes32 id)",
  "function beginRefresh(bytes32 id) returns (bytes32 key)",
  "function bundleEvidence(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 inventoryPlan, bytes32 renderCriticalEvidenceHash, uint64 itemCount, bytes32 evidenceChainHash, bytes32 bundleCoverageHash) coverage))",
  "function bundleProfile() pure returns (bytes32)",
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function coverEmptySegment(bytes32 id)",
  "function coverNext(bytes32 id, (uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash) item, bytes32 nextLink, (uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof)",
  "function coverRetrievalNext(bytes32 id, (uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash) item, bytes32 nextLink, bytes32 witnessHash)",
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
  "function retrievalWitnessForItem(bytes32 id, uint64 index) view returns (bytes32)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
] as const);
export function currentViewPreservationBundleV1Interface(): Interface {
  return new Interface(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ABI);
}

export function normalizeCurrentViewPreservationBundleV1Dependencies(value: CurrentViewPreservationBundleV1Dependencies): CurrentViewPreservationBundleV1Dependencies {
  return normalize(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_DEPENDENCIES_TUPLE, value);
}
export function encodeCurrentViewPreservationBundleV1Dependencies(value: CurrentViewPreservationBundleV1Dependencies): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_DEPENDENCIES_TUPLE, value);
}
export function decodeCurrentViewPreservationBundleV1Dependencies(value: Hex): CurrentViewPreservationBundleV1Dependencies {
  return decode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_DEPENDENCIES_TUPLE, value);
}

export function normalizeCurrentViewPreservationBundleV1Evidence(value: CurrentViewPreservationBundleV1Evidence): CurrentViewPreservationBundleV1Evidence {
  return normalize(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_EVIDENCE_TUPLE, value);
}
export function encodeCurrentViewPreservationBundleV1Evidence(value: CurrentViewPreservationBundleV1Evidence): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_EVIDENCE_TUPLE, value);
}
export function decodeCurrentViewPreservationBundleV1Evidence(value: Hex): CurrentViewPreservationBundleV1Evidence {
  return decode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_EVIDENCE_TUPLE, value);
}

export function normalizeCurrentViewPreservationBundleV1Scope(value: CurrentViewPreservationBundleV1Scope): CurrentViewPreservationBundleV1Scope {
  return normalize(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_SCOPE_TUPLE, value);
}
export function encodeCurrentViewPreservationBundleV1Scope(value: CurrentViewPreservationBundleV1Scope): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_SCOPE_TUPLE, value);
}
export function decodeCurrentViewPreservationBundleV1Scope(value: Hex): CurrentViewPreservationBundleV1Scope {
  return decode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_SCOPE_TUPLE, value);
}

export function normalizeCurrentViewPreservationBundleV1Coverage(value: CurrentViewPreservationBundleV1Coverage): CurrentViewPreservationBundleV1Coverage {
  return normalize(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_COVERAGE_TUPLE, value);
}
export function encodeCurrentViewPreservationBundleV1Coverage(value: CurrentViewPreservationBundleV1Coverage): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_COVERAGE_TUPLE, value);
}
export function decodeCurrentViewPreservationBundleV1Coverage(value: Hex): CurrentViewPreservationBundleV1Coverage {
  return decode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_COVERAGE_TUPLE, value);
}

export function normalizeCurrentViewPreservationBundleV1Admission(value: CurrentViewPreservationBundleV1Admission): CurrentViewPreservationBundleV1Admission {
  return normalize(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ADMISSION_TUPLE, value);
}
export function encodeCurrentViewPreservationBundleV1Admission(value: CurrentViewPreservationBundleV1Admission): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ADMISSION_TUPLE, value);
}
export function decodeCurrentViewPreservationBundleV1Admission(value: Hex): CurrentViewPreservationBundleV1Admission {
  return decode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ADMISSION_TUPLE, value);
}

export function normalizeCurrentViewPreservationBundleV1Proof(value: CurrentViewPreservationBundleV1Proof): CurrentViewPreservationBundleV1Proof {
  return normalize(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROOF_TUPLE, value);
}
export function encodeCurrentViewPreservationBundleV1Proof(value: CurrentViewPreservationBundleV1Proof): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROOF_TUPLE, value);
}
export function decodeCurrentViewPreservationBundleV1Proof(value: Hex): CurrentViewPreservationBundleV1Proof {
  return decode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROOF_TUPLE, value);
}

export function normalizeCurrentViewPreservationBundleV1ExternalCoverage(value: CurrentViewPreservationBundleV1ExternalCoverage): CurrentViewPreservationBundleV1ExternalCoverage {
  return normalize(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_EXTERNAL_COVERAGE_TUPLE, value);
}
export function encodeCurrentViewPreservationBundleV1ExternalCoverage(value: CurrentViewPreservationBundleV1ExternalCoverage): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_EXTERNAL_COVERAGE_TUPLE, value);
}
export function decodeCurrentViewPreservationBundleV1ExternalCoverage(value: Hex): CurrentViewPreservationBundleV1ExternalCoverage {
  return decode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_EXTERNAL_COVERAGE_TUPLE, value);
}

export function normalizeCurrentViewPreservationBundleV1OnchainCoverage(value: CurrentViewPreservationBundleV1OnchainCoverage): CurrentViewPreservationBundleV1OnchainCoverage {
  return normalize(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ONCHAIN_COVERAGE_TUPLE, value);
}
export function encodeCurrentViewPreservationBundleV1OnchainCoverage(value: CurrentViewPreservationBundleV1OnchainCoverage): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ONCHAIN_COVERAGE_TUPLE, value);
}
export function decodeCurrentViewPreservationBundleV1OnchainCoverage(value: Hex): CurrentViewPreservationBundleV1OnchainCoverage {
  return decode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ONCHAIN_COVERAGE_TUPLE, value);
}

export function normalizeCurrentViewPreservationBundleV1Item(value: CurrentViewPreservationBundleV1Item): CurrentViewPreservationBundleV1Item {
  return normalize(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ITEM_TUPLE, value);
}
export function encodeCurrentViewPreservationBundleV1Item(value: CurrentViewPreservationBundleV1Item): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ITEM_TUPLE, value);
}
export function decodeCurrentViewPreservationBundleV1Item(value: Hex): CurrentViewPreservationBundleV1Item {
  return decode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ITEM_TUPLE, value);
}

export function normalizeCurrentViewPreservationBundleV1Progress(value: CurrentViewPreservationBundleV1Progress): CurrentViewPreservationBundleV1Progress {
  return normalize(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROGRESS_TUPLE, value);
}
export function encodeCurrentViewPreservationBundleV1Progress(value: CurrentViewPreservationBundleV1Progress): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROGRESS_TUPLE, value);
}
export function decodeCurrentViewPreservationBundleV1Progress(value: Hex): CurrentViewPreservationBundleV1Progress {
  return decode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROGRESS_TUPLE, value);
}

export function normalizeCurrentViewPreservationBundleV1Refresh(value: CurrentViewPreservationBundleV1Refresh): CurrentViewPreservationBundleV1Refresh {
  return normalize(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_REFRESH_TUPLE, value);
}
export function encodeCurrentViewPreservationBundleV1Refresh(value: CurrentViewPreservationBundleV1Refresh): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_REFRESH_TUPLE, value);
}
export function decodeCurrentViewPreservationBundleV1Refresh(value: Hex): CurrentViewPreservationBundleV1Refresh {
  return decode(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_REFRESH_TUPLE, value);
}

const coder = AbiCoder.defaultAbiCoder();
const Z = ZeroHash as Hex;
function exact(value: unknown, keys: readonly string[]): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Reflect.ownKeys(value).length !== keys.length
    || keys.some(k => !Object.prototype.hasOwnProperty.call(value, k))) throw Error("Invalid exact shape");
}
function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`Invalid uint${bits}`);
  return value;
}
function address(value: unknown, required = false): Address {
  if (typeof value !== "string" || !isHexString(value, 20)) throw Error("Invalid address");
  const result = getAddress(value) as Address;
  if (required && result === ZeroAddress) throw Error("Zero address");
  return result;
}
function bytes(value: unknown, length?: number, maximum = CURRENT_VIEW_PRESERVATION_BUNDLE_V1_MAX_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, length ?? true)
    || (value.length - 2) / 2 > maximum) throw Error("Invalid bytes or allocation bound");
  return value.toLowerCase() as Hex;
}
function nonzero(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === Z) throw Error("Zero commitment");
  return result;
}
function list(value: unknown, maximum = CURRENT_VIEW_PRESERVATION_BUNDLE_V1_MAX_ROWS): readonly unknown[] {
  if (!Array.isArray(value) || value.length > maximum || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.prototype.hasOwnProperty.call(value, i))) throw Error("Invalid dense array");
  return value;
}
function utf8(value: unknown): Uint8Array {
  if (typeof value !== "string" || value.length > CURRENT_VIEW_PRESERVATION_BUNDLE_V1_MAX_BYTES) throw Error("Invalid string");
  for (let i = 0; i < value.length; ++i) {
    const code = value.charCodeAt(i);
    if (code >= 0xdc00 && code <= 0xdfff) throw Error("Invalid Unicode scalar");
    if (code >= 0xd800 && code <= 0xdbff) {
      const next = value.charCodeAt(++i);
      if (!(next >= 0xdc00 && next <= 0xdfff)) throw Error("Invalid Unicode scalar");
    }
  }
  return toUtf8Bytes(value);
}
const enumFields: Readonly<Record<string, Readonly<Record<string, number>>>> = {
  "(uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)": {
    "scopeType": 4
  },
  "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)": {
    "kind": 11
  }
};
function valueOf(t: ParamType, value: unknown, decoded: boolean, enumMaximum?: number): unknown {
  if (t.baseType === "array") {
    const rows = list(decoded ? Array.from(value as readonly unknown[]) : value);
    if (t.arrayLength !== -1 && rows.length !== t.arrayLength) throw Error("Invalid fixed array");
    return Object.freeze(rows.map(x => valueOf(t.arrayChildren!, x, decoded)));
  }
  if (t.type === "bool") { if (typeof value !== "boolean") throw Error("Invalid bool"); return value; }
  if (t.baseType === "tuple") {
    if (!decoded) exact(value, t.components!.map(c => c.name));
    const tupleKey = ParamType.from({ type: "tuple", components: t.components!.map(c => JSON.parse(c.format("json"))) }).format("full");
    const result = Object.fromEntries(t.components!.map((c, i) => [c.name,
      valueOf(c, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[c.name], decoded, enumFields[tupleKey]?.[c.name])]));
    if ("scopeType" in result && (result.scopeType as bigint) > 4n) throw Error("Invalid original scope enum");
    return Object.freeze(result);
  }
  if (t.type.startsWith("uint")) {
    const result = uint(value, Number(t.type.slice(4)));
    if (enumMaximum !== undefined && result > BigInt(enumMaximum)) throw Error("Unknown original enum");
    return result;
  }
  if (t.type === "address") return address(value);
  if (t.type === "string") {
    if (utf8(value).length > CURRENT_VIEW_PRESERVATION_BUNDLE_V1_MAX_BYTES) throw Error("Invalid UTF-8 string bound");
    return value;
  }
  if (t.type.startsWith("bytes")) return bytes(value, t.type === "bytes" ? undefined : Number(t.type.slice(5)));
  throw Error("Unsupported original ABI type");
}
function normalize<T>(tuple: string, value: unknown, decoded = false): T {
  const p = ParamType.from(tuple);
  if (preflight(p, value, decoded) + (isDynamic(p) ? 32 : 0) > CURRENT_VIEW_PRESERVATION_BUNDLE_V1_MAX_BYTES) throw Error("ABI allocation bound");
  const result = valueOf(p, value, decoded) as T;
  if (encodedSize(p, result) + (isDynamic(p) ? 32 : 0) > CURRENT_VIEW_PRESERVATION_BUNDLE_V1_MAX_BYTES) throw Error("ABI allocation bound");
  return result;
}
function encode(tuple: string, value: unknown): Hex {
  return bytes(coder.encode([tuple], [normalize(tuple, value)]));
}
function decode<T>(tuple: string, value: Hex): T {
  const raw = bytes(value);
  const result = normalize<T>(tuple, coder.decode([tuple], raw)[0], true);
  if (encode(tuple, result) !== raw) throw Error("Noncanonical original ABI");
  return result;
}
function hash(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}
function same(actual: unknown, expected: unknown, label: string): void {
  if (actual !== expected) throw Error(`${label} mismatch`);
}
function equalTuple(tuple: string, actual: unknown, expected: unknown, label: string): void {
  same(encode(tuple, actual), encode(tuple, expected), label);
}
function isDynamic(p: ParamType): boolean {
  return p.type === "bytes" || p.type === "string"
    || (p.baseType === "array" && (p.arrayLength === -1 || isDynamic(p.arrayChildren!)))
    || (p.baseType === "tuple" && p.components!.some(isDynamic));
}
function encodedSize(p: ParamType, value: unknown): number {
  let size: number;
  if (p.baseType === "array") {
    size = (p.arrayLength === -1 ? 32 : 0) + (value as readonly unknown[]).reduce<number>((sum, v) =>
      sum + (isDynamic(p.arrayChildren!) ? 32 : 0) + encodedSize(p.arrayChildren!, v), 0);
  } else if (p.baseType === "tuple") {
    size = p.components!.reduce((sum, c) => sum + (isDynamic(c) ? 32 : 0)
      + encodedSize(c, (value as Record<string, unknown>)[c.name]), 0);
  } else if (p.type === "bytes" || p.type === "string") {
    const n = p.type === "bytes" ? ((value as string).length - 2) / 2 : utf8(value).length;
    size = 32 + Math.ceil(n / 32) * 32;
  } else size = 32;
  if (size > 2097152) throw Error("ABI allocation bound");
  return size;
}
/** Traverses caller values before copying arrays, objects or UTF-8 buffers. */
function preflight(p: ParamType, value: unknown, decoded: boolean, budget = { nodes: 0 }): number {
  if (++budget.nodes > 65536) throw Error("Client structure bound");
  let total = 0;
  const add = (n: number): void => {
    total += n;
    if (total > 2097152) throw Error("ABI allocation bound");
  };
  if (p.baseType === "array") {
    if (!Array.isArray(value) || value.length > 8192
      || (p.arrayLength !== -1 && value.length !== p.arrayLength)) throw Error("Invalid array bound");
    if (!decoded) list(value);
    if (p.arrayLength === -1) add(32);
    for (let i = 0; i < value.length; ++i) {
      if (isDynamic(p.arrayChildren!)) add(32);
      add(preflight(p.arrayChildren!, value[i], decoded, budget));
    }
  } else if (p.baseType === "tuple") {
    if (!decoded) exact(value, p.components!.map(c => c.name));
    for (let i = 0; i < p.components!.length; ++i) {
      const c = p.components![i]!;
      if (isDynamic(c)) add(32);
      add(preflight(c, decoded ? (value as readonly unknown[])[i]
        : (value as Record<string, unknown>)[c.name], decoded, budget));
    }
  } else if (p.type === "bytes" || p.type === "string") {
    let length = 0;
    if (p.type === "bytes") length = (bytes(value).length - 2) / 2;
    else {
      if (typeof value !== "string" || value.length > 2097152) throw Error("Invalid string bound");
      for (let i = 0; i < value.length; ++i) {
        const code = value.charCodeAt(i);
        if (code >= 0xdc00 && code <= 0xdfff) throw Error("Invalid Unicode scalar");
        if (code >= 0xd800 && code <= 0xdbff) {
          const low = value.charCodeAt(++i);
          if (!(low >= 0xdc00 && low <= 0xdfff)) throw Error("Invalid Unicode scalar");
          length += 4;
        } else length += code < 128 ? 1 : code < 2048 ? 2 : 3;
        if (length > 2097152) throw Error("UTF-8 allocation bound");
      }
    }
    add(32 + Math.ceil(length / 32) * 32);
  } else add(32);
  return total;
}

export type CurrentViewPreservationBundleV1Request =
  | Readonly<{ method: "beginCoverage"; id: Hex; }>
  | Readonly<{ method: "beginRefresh"; id: Hex; }>
  | Readonly<{ method: "coverEmptySegment"; id: Hex; }>
  | Readonly<{ method: "coverNext"; id: Hex; item: CurrentViewPreservationBundleV1Item; nextLink: Hex; proof: CurrentViewPreservationBundleV1Proof; }>
  | Readonly<{ method: "coverRetrievalNext"; id: Hex; item: CurrentViewPreservationBundleV1Item; nextLink: Hex; witnessHash: Hex; }>
  | Readonly<{ method: "refreshNext"; id: Hex; expectedIndex: bigint; }>;
const writeFields = Object.freeze({
  "beginCoverage": [
    "id"
  ],
  "beginRefresh": [
    "id"
  ],
  "coverEmptySegment": [
    "id"
  ],
  "coverNext": [
    "id",
    "item",
    "nextLink",
    "proof"
  ],
  "coverRetrievalNext": [
    "id",
    "item",
    "nextLink",
    "witnessHash"
  ],
  "refreshNext": [
    "id",
    "expectedIndex"
  ]
});

export type CurrentViewPreservationBundleV1ReadRequest =
  | Readonly<{ method: "PROFILE";  }>
  | Readonly<{ method: "admittedItem"; id: Hex; index: bigint; }>
  | Readonly<{ method: "artifactCoverage";  }>
  | Readonly<{ method: "bundleEvidence"; id: Hex; }>
  | Readonly<{ method: "bundleProfile";  }>
  | Readonly<{ method: "core";  }>
  | Readonly<{ method: "coreCodeHash";  }>
  | Readonly<{ method: "dependencies";  }>
  | Readonly<{ method: "dependencyHash";  }>
  | Readonly<{ method: "deploymentChainId";  }>
  | Readonly<{ method: "externalCoverage";  }>
  | Readonly<{ method: "inventoryCodeHash";  }>
  | Readonly<{ method: "metadataCodeHash";  }>
  | Readonly<{ method: "metadataHost";  }>
  | Readonly<{ method: "progress"; id: Hex; }>
  | Readonly<{ method: "refresh"; key: Hex; }>
  | Readonly<{ method: "renderCriticalInventory";  }>
  | Readonly<{ method: "requireCoverage"; scope: CurrentViewPreservationBundleV1Scope; id: Hex; expectedHash: Hex; }>
  | Readonly<{ method: "requireFullCurrentCoverage"; id: Hex; }>
  | Readonly<{ method: "retrievalWitnessForItem"; id: Hex; index: bigint; }>
  | Readonly<{ method: "supportsInterface"; id: Hex; }>;
const readFields = Object.freeze({
  "PROFILE": [],
  "admittedItem": [
    "id",
    "index"
  ],
  "artifactCoverage": [],
  "bundleEvidence": [
    "id"
  ],
  "bundleProfile": [],
  "core": [],
  "coreCodeHash": [],
  "dependencies": [],
  "dependencyHash": [],
  "deploymentChainId": [],
  "externalCoverage": [],
  "inventoryCodeHash": [],
  "metadataCodeHash": [],
  "metadataHost": [],
  "progress": [
    "id"
  ],
  "refresh": [
    "key"
  ],
  "renderCriticalInventory": [],
  "requireCoverage": [
    "scope",
    "id",
    "expectedHash"
  ],
  "requireFullCurrentCoverage": [
    "id"
  ],
  "retrievalWitnessForItem": [
    "id",
    "index"
  ],
  "supportsInterface": [
    "id"
  ]
});

function requestValue<T extends { readonly method: string }>(value: T, fields: Readonly<Record<string, readonly string[]>>): T {
  if (!value || typeof value !== "object" || !Object.prototype.hasOwnProperty.call(fields, value.method)) throw Error("Unsupported original method");
  const names = fields[value.method]!;
  exact(value, ["method", ...names]);
  const fragment = currentViewPreservationBundleV1Interface().getFunction(value.method)!;
  const tuple = ParamType.from({ type: "tuple", components: fragment.inputs.map((p, i) => ({ ...JSON.parse(p.format("json")), name: names[i] })) });
  const supplied = Object.fromEntries(names.map(n => [n, (value as unknown as Record<string, unknown>)[n]]));
  const normalized = normalize<Record<string, unknown>>(tuple.format("full"), supplied);
  if (encodedSize(tuple, normalized) + 4 > CURRENT_VIEW_PRESERVATION_BUNDLE_V1_MAX_BYTES) throw Error("Whole calldata bound");
  return Object.freeze({ method: value.method, ...normalized }) as T;
}

export function normalizeCurrentViewPreservationBundleV1Request(value: CurrentViewPreservationBundleV1Request): CurrentViewPreservationBundleV1Request {
  const r = requestValue(value, writeFields);
  nonzero(r.id);
  if (r.method === "coverRetrievalNext") nonzero(r.witnessHash);
  if (r.method === "coverNext" && r.item.role === inventory.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RETRIEVAL_ROLE) throw Error("Retrieval role requires witness");
  return r;
}

export interface CurrentViewPreservationBundleV1Call {
  readonly coordinates: CurrentViewPreservationBundleV1Coordinates;
  readonly caller: Address;
  readonly request: CurrentViewPreservationBundleV1Request;
  readonly call: UnsignedCall;
}
export function prepareCurrentViewPreservationBundleV1Call(coordinates: CurrentViewPreservationBundleV1Coordinates, caller: Address, request: CurrentViewPreservationBundleV1Request): CurrentViewPreservationBundleV1Call {
  const c = normalizeCurrentViewPreservationBundleV1Coordinates(coordinates), r = normalizeCurrentViewPreservationBundleV1Request(request);
  const fields = writeFields[r.method] as readonly string[];
  const data = bytes(currentViewPreservationBundleV1Interface().encodeFunctionData(r.method, fields.map(k => (r as unknown as Record<string, unknown>)[k])));
  return Object.freeze({ coordinates: c, caller: address(caller, true), request: r, call: Object.freeze({ to: c.bundle, data, value: 0n }) });
}
export const currentViewPreservationBundleV1Call = prepareCurrentViewPreservationBundleV1Call;
export function normalizeCurrentViewPreservationBundleV1Call(value: CurrentViewPreservationBundleV1Call): CurrentViewPreservationBundleV1Call {
  exact(value, ["coordinates", "caller", "request", "call"]);
  exact(value.call, ["to", "data", "value"]);
  const r = prepareCurrentViewPreservationBundleV1Call(value.coordinates, value.caller, value.request);
  same(address(value.call.to), r.call.to, "Call target");
  same(bytes(value.call.data), r.call.data, "Call data");
  same(uint(value.call.value), 0n, "Call value");
  return r;
}
export interface CurrentViewPreservationBundleV1Read {
  readonly coordinates: CurrentViewPreservationBundleV1Coordinates;
  readonly request: CurrentViewPreservationBundleV1ReadRequest;
  readonly call: UnsignedCall;
}
export function prepareCurrentViewPreservationBundleV1Read(coordinates: CurrentViewPreservationBundleV1Coordinates, request: CurrentViewPreservationBundleV1ReadRequest): CurrentViewPreservationBundleV1Read {
  const c = normalizeCurrentViewPreservationBundleV1Coordinates(coordinates), r = requestValue(request, readFields);
  const fields = readFields[r.method] as readonly string[];
  return Object.freeze({ coordinates: c, request: r, call: Object.freeze({ to: c.bundle, value: 0n, data: bytes(currentViewPreservationBundleV1Interface().encodeFunctionData(r.method, fields.map(k => (r as unknown as Record<string, unknown>)[k]))) }) });
}
export const currentViewPreservationBundleV1Read = prepareCurrentViewPreservationBundleV1Read;
export function normalizeCurrentViewPreservationBundleV1Read(value: CurrentViewPreservationBundleV1Read): CurrentViewPreservationBundleV1Read {
  exact(value, ["coordinates", "request", "call"]);
  exact(value.call, ["to", "data", "value"]);
  const r = prepareCurrentViewPreservationBundleV1Read(value.coordinates, value.request);
  same(address(value.call.to), r.call.to, "Read target");
  same(bytes(value.call.data), r.call.data, "Read data");
  same(uint(value.call.value), 0n, "Read value");
  return r;
}

export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROFILE = id("6529STREAM_VIEW_PRESERVATION_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1") as Hex;
export type CurrentViewPreservationBundleV1InventoryEvidence = inventory.CurrentViewPreservationInventoryV1Evidence;
export type CurrentViewPreservationBundleV1Context = inventory.CurrentViewPreservationInventoryV1Context;
export type CurrentViewPreservationBundleV1Segment = inventory.CurrentViewPreservationInventoryV1Segment;

export function normalizeCurrentViewPreservationBundleV1Coordinates(value: CurrentViewPreservationBundleV1Coordinates): CurrentViewPreservationBundleV1Coordinates {
  exact(value, ["chainId", "core", "bundle"]);
  if (uint(value.chainId) === 0n) throw Error("Zero chain");
  return Object.freeze({ chainId: value.chainId, core: address(value.core, true), bundle: address(value.bundle, true) });
}
export function currentViewPreservationBundleV1DependencyHash(value: CurrentViewPreservationBundleV1Dependencies): Hex {
  return keccak256(encodeCurrentViewPreservationBundleV1Dependencies(value)) as Hex;
}
export function validateCurrentViewPreservationBundleV1Dependencies(
  coordinates: CurrentViewPreservationBundleV1Coordinates, value: CurrentViewPreservationBundleV1Dependencies,
): CurrentViewPreservationBundleV1Dependencies {
  const c = normalizeCurrentViewPreservationBundleV1Coordinates(coordinates);
  const d = normalizeCurrentViewPreservationBundleV1Dependencies(value);
  same(d.chainId, c.chainId, "Chain");
  same(d.targets[0], c.core, "Core");
  if (d.readGas < 50000n || d.archiveGas < d.readGas) throw Error("Original gas ordering");
  d.targets.forEach(a => address(a, true));
  d.codeHashes.forEach(nonzero);
  return d;
}

export function currentViewPreservationBundleV1BaseEnvironmentHash(
  dependencies: CurrentViewPreservationBundleV1Dependencies,
  onchainHash: Hex, onchainEpoch: bigint, externalHash: Hex, externalRevision: bigint,
): Hex {
  const d = normalizeCurrentViewPreservationBundleV1Dependencies(dependencies);
  return hash(["bytes32", CURRENT_VIEW_PRESERVATION_BUNDLE_V1_DEPENDENCIES_TUPLE, "bytes32", "uint64", "bytes32", "uint64"],
    [id("6529STREAM_BUNDLE_IMMUTABLE_STOP_ENVIRONMENT_V1"), d, bytes(onchainHash, 32), uint(onchainEpoch, 64), bytes(externalHash, 32), uint(externalRevision, 64)]);
}
export function currentViewPreservationBundleV1EnvironmentHash(
  originalEnvironment: Hex, witness: Address, witnessCodeHash: Hex,
  scope: CurrentViewPreservationBundleV1Scope, revocationEpoch: bigint,
): Hex {
  return hash(["bytes32", "bytes32", "address", "bytes32", CURRENT_VIEW_PRESERVATION_BUNDLE_V1_SCOPE_TUPLE, "uint64"],
    [id("6529STREAM_VIEW_RETRIEVAL_ARCHIVE_ENVIRONMENT_V1"), bytes(originalEnvironment, 32),
      address(witness), bytes(witnessCodeHash, 32), normalizeCurrentViewPreservationBundleV1Scope(scope), uint(revocationEpoch, 64)]);
}
export function currentViewPreservationBundleV1CoveredItemChain(
  previous: Hex, plan: Hex, index: bigint, itemHash: Hex, admission: CurrentViewPreservationBundleV1Admission,
): Hex {
  return hash(["bytes32", "bytes32", "bytes32", "uint64", "bytes32", CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ADMISSION_TUPLE],
    [id("6529STREAM_VIEW_PRESERVATION_BUNDLE_COVERED_ITEM_V1"), bytes(previous, 32), bytes(plan, 32),
      uint(index, 64), bytes(itemHash, 32), normalizeCurrentViewPreservationBundleV1Admission(admission)]);
}
export function currentViewPreservationBundleV1ObservationChain(previous: Hex, index: bigint, itemHash: Hex, observation: Hex): Hex {
  return hash(["bytes32", "bytes32", "uint64", "bytes32", "bytes32"],
    [id("6529STREAM_VIEW_PRESERVATION_BUNDLE_CURRENT_OBSERVATION_V1"), bytes(previous, 32), uint(index, 64),
      bytes(itemHash, 32), bytes(observation, 32)]);
}
export function currentViewPreservationBundleV1CoverageHash(
  coordinates: CurrentViewPreservationBundleV1Coordinates, dependencyHash: Hex,
  inventoryEvidence: CurrentViewPreservationBundleV1InventoryEvidence, value: CurrentViewPreservationBundleV1Evidence,
): Hex {
  const c = normalizeCurrentViewPreservationBundleV1Coordinates(coordinates);
  const e = normalizeCurrentViewPreservationBundleV1Evidence(value);
  return hash(["bytes32", "uint256", "address", "bytes32", "bytes32",
    inventory.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_EVIDENCE_TUPLE, CURRENT_VIEW_PRESERVATION_BUNDLE_V1_EVIDENCE_TUPLE],
  [id("6529STREAM_VIEW_PRESERVATION_BUNDLE_ARCHIVE_COVERAGE_V1"), c.chainId, c.bundle, bytes(dependencyHash, 32),
    CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROFILE, inventory.normalizeCurrentViewPreservationInventoryV1Evidence(inventoryEvidence),
    { ...e, coverage: { ...e.coverage, bundleCoverageHash: Z } }]);
}
export function currentViewPreservationBundleV1Evidence(
  coordinates: CurrentViewPreservationBundleV1Coordinates, dependencyHash: Hex,
  inventoryEvidence: CurrentViewPreservationBundleV1InventoryEvidence, evidenceChainHash: Hex,
): CurrentViewPreservationBundleV1Evidence {
  const i = inventory.normalizeCurrentViewPreservationInventoryV1Evidence(inventoryEvidence);
  const e: CurrentViewPreservationBundleV1Evidence = { scope: i.scope, coverage: {
    inventoryPlan: i.inventory.planId, renderCriticalEvidenceHash: i.inventory.renderCriticalEvidenceHash,
    itemCount: i.inventory.itemCount, evidenceChainHash: bytes(evidenceChainHash, 32), bundleCoverageHash: Z,
  } };
  return normalizeCurrentViewPreservationBundleV1Evidence({ ...e, coverage: {
    ...e.coverage, bundleCoverageHash: currentViewPreservationBundleV1CoverageHash(coordinates, dependencyHash, i, e),
  } });
}
export function currentViewPreservationBundleV1RefreshId(
  coordinates: CurrentViewPreservationBundleV1Coordinates, dependencyHash: Hex, plan: Hex, environment: Hex,
): Hex {
  const c = normalizeCurrentViewPreservationBundleV1Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_VIEW_PRESERVATION_BUNDLE_REFRESH_V1"), c.chainId, c.bundle, bytes(dependencyHash, 32),
      bytes(plan, 32), bytes(environment, 32)]);
}
export function currentViewPreservationBundleV1AdmittedBundleHash(
  originalBundleHash: Hex, witness: Address, witnessCodeHash: Hex,
  configuration: retrieval.CurrentViewRetrievalV1Configuration, recordHash: Hex, payloadHash: Hex,
): Hex {
  return hash(["bytes32", "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_VIEW_RETRIEVAL_ADMITTED_BUNDLE_V1"), bytes(originalBundleHash, 32), address(witness),
      bytes(witnessCodeHash, 32), retrieval.currentViewRetrievalV1ConfigurationHash(configuration),
      bytes(recordHash, 32), bytes(payloadHash, 32)]);
}
export function currentViewPreservationBundleV1CurrentObservationHash(
  source: retrieval.CurrentViewRetrievalV1Source, receipt: retrieval.CurrentViewRetrievalV1Receipt, pairObservation: Hex,
): Hex {
  return hash(["bytes32", retrieval.CURRENT_VIEW_RETRIEVAL_V1_SOURCE_TUPLE, retrieval.CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE, "bytes32"],
    [id("6529STREAM_VIEW_RETRIEVAL_CURRENT_OBSERVATION_V1"), retrieval.normalizeCurrentViewRetrievalV1Source(source),
      retrieval.normalizeCurrentViewRetrievalV1Receipt(receipt), bytes(pairObservation, 32)]);
}

/** Binding predicates only; successful return does not attest deployed runtimes or current source. */
export function validateCurrentViewPreservationBundleV1Binding(
  dependencies: CurrentViewPreservationBundleV1Dependencies,
  source: inventory.CurrentViewPreservationInventoryV1Dependencies,
  configuration: retrieval.CurrentViewRetrievalV1Configuration,
  snapshot: inventory.CurrentViewPreservationInventoryV1SnapshotDependencies,
): Readonly<{ configurationHash: Hex; runtimeVerified: false }> {
  const d = normalizeCurrentViewPreservationBundleV1Dependencies(dependencies);
  const s = inventory.normalizeCurrentViewPreservationInventoryV1Dependencies(source);
  same(s.chainId, d.chainId, "Inventory chain");
  for (const [si, di] of [[0, 0], [1, 1], [10, 3], [11, 4]] as const) {
    same(s.targets[si], d.targets[di], "Inventory target");
    same(s.codeHashes[si], d.codeHashes[di], "Inventory runtime");
  }
  same(s.artistTargets[4], d.targets[5], "Artist Archive");
  same(s.artistCodeHashes[4], d.codeHashes[5], "Artist Archive runtime");
  return inventory.validateCurrentViewPreservationInventoryV1RetrievalBinding(s, configuration, snapshot);
}

/** Source/record/item relations read by the original consumer; current pair validity stays external. */
export function validateCurrentViewPreservationBundleV1Retrieval(
  dependencies: CurrentViewPreservationBundleV1Dependencies, context: CurrentViewPreservationBundleV1Context,
  item: CurrentViewPreservationBundleV1Item, witness: Address, witnessCodeHash: Hex,
  configuration: retrieval.CurrentViewRetrievalV1Configuration, recordHash: Hex,
  source: retrieval.CurrentViewRetrievalV1Source, receipt: retrieval.CurrentViewRetrievalV1Receipt,
  actual: CurrentViewPreservationBundleV1Admission, pairObservation: Hex,
): Readonly<{ admission: CurrentViewPreservationBundleV1Admission; observation: Hex; currentnessVerified: false }> {
  const d = normalizeCurrentViewPreservationBundleV1Dependencies(dependencies);
  const c = inventory.normalizeCurrentViewPreservationInventoryV1Context(context);
  const i = normalizeCurrentViewPreservationBundleV1Item(item);
  const config = retrieval.normalizeCurrentViewRetrievalV1Configuration(configuration);
  const s = retrieval.normalizeCurrentViewRetrievalV1Source(source);
  const r = retrieval.normalizeCurrentViewRetrievalV1Receipt(receipt);
  const a = normalizeCurrentViewPreservationBundleV1Admission(actual);
  nonzero(recordHash);
  if (i.role !== inventory.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RETRIEVAL_ROLE
    && i.role !== inventory.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_LOCATOR_ROLE) throw Error("No retrieval obligation");
  same(r.recordHash, bytes(recordHash, 32), "Witness record");
  same(r.sourceKey, retrieval.currentViewRetrievalV1SourceKey(s), "Witness source");
  same(r.objectHash, a.proof.objectHash, "Witness object");
  same(r.coverageHash, a.proof.coverageHash, "Witness coverage");
  same(a.proof.backend, 1n, "External retrieval backend");
  nonzero(r.payloadHash);
  same(s.core, d.targets[0], "Core");
  same(s.router, config.router, "Router");
  same(s.adoptionRecord, c.adoptionRecord, "Adoption");
  same(s.payloadHash, c.payloadHash, "Payload");
  same(s.checkpointContextHash, c.sourceContextHash, "Checkpoint context");
  same(s.artistId, c.artistId, "Artist");
  same(a.externalOriginal.artistId, c.artistId, "Archive artist");
  validateRetainedExternal(c.artistId, a);
  equalTuple(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_SCOPE_TUPLE, s.scope, c.scope, "Full VIEW scope");
  equalTuple(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ITEM_TUPLE, i, inventory.currentViewPreservationInventoryV1Obligation(s), "Exact obligation");
  const admission = normalizeCurrentViewPreservationBundleV1Admission({ ...a,
    originalBundleHash: currentViewPreservationBundleV1AdmittedBundleHash(a.originalBundleHash, witness, witnessCodeHash, config, recordHash, r.payloadHash),
  });
  return Object.freeze({ admission, observation: currentViewPreservationBundleV1CurrentObservationHash(s, r, pairObservation), currentnessVerified: false });
}

const RAW = id("RAW_BYTES") as Hex;
const JCS = id("RFC8785_JCS") as Hex;
const intrinsic = (kind: bigint): boolean => kind === 6n || kind === 7n || kind === 8n || kind === 9n || kind === 11n;

function applicability(item: CurrentViewPreservationBundleV1Item): void {
  if ([item.objectHash, item.originalCoverageHash, item.schemaId, item.formatId, item.catalogId, item.catalogHash]
    .some(value => value !== Z)) throw Error("Applicability row contains object/catalog fields");
  if (item.kind === 7n) {
    if (item.byteSize !== 0n || item.algorithm !== 0n || item.canonicalizationId !== Z
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
export function validateCurrentViewPreservationBundleV1Proof(
  item: CurrentViewPreservationBundleV1Item,
  proof: CurrentViewPreservationBundleV1Proof,
): CurrentViewPreservationBundleV1Proof {
  const row = normalizeCurrentViewPreservationBundleV1Item(item);
  const p = normalizeCurrentViewPreservationBundleV1Proof(proof);
  nonzero(row.role); address(row.source, true); nonzero(row.sourceRecord);
  if (row.role === inventory.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RETRIEVAL_ROLE) throw Error("Retrieval obligation requires stored witness");
  if (row.role === inventory.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_LOCATOR_ROLE) {
    validateLocator(row);
    if (p.backend !== 1n) throw Error("Locator requires external Archive");
    nonzero(p.objectHash);
    nonzero(p.coverageHash);
    return p;
  }
  if (intrinsic(row.kind)) {
    if (p.backend !== 0n || p.objectHash !== Z || p.coverageHash !== Z) throw Error("Intrinsic row requires canonical no-proof");
    if (row.kind === 6n) {
      if (row.sourceIndex !== 1n || row.algorithm !== 1n || row.canonicalizationId !== RAW) throw Error("Malformed STATE_BUNDLE row");
    } else applicability(row);
  } else {
    if ((p.backend !== 1n && p.backend !== 2n) || (p.backend === 1n && row.kind === 10n)
      || (p.backend === 2n && row.kind === 5n)) throw Error("Unsupported archive backend for item kind");
    nonzero(p.coverageHash); nonzero(p.objectHash);
    if ((row.objectHash !== Z && row.objectHash !== p.objectHash)
      || (row.originalCoverageHash !== Z && row.originalCoverageHash !== p.coverageHash)) throw Error("Proof original object/coverage differs");
    if (row.digest.length !== 66 || (row.algorithm !== 1n && row.algorithm !== 2n)
      || (p.backend === 2n && row.algorithm !== 1n)
      || (row.kind !== 5n && row.kind !== 10n && row.canonicalizationId !== RAW && row.canonicalizationId !== JCS
        && !currentViewPreservationBundleV1SupportedAbiCorrespondence(row))) {
      throw Error("Unsupported original inventory correspondence");
    }
  }
  return p;
}

export interface CurrentViewPreservationBundleV1Correspondence {
  readonly contentHash: Hex;
  readonly sha256Digest: Hex;
  readonly canonicalizationId: Hex;
  readonly byteSize: bigint;
}

export function validateCurrentViewPreservationBundleV1Correspondence(
  item: CurrentViewPreservationBundleV1Item,
  value: CurrentViewPreservationBundleV1Correspondence,
): CurrentViewPreservationBundleV1Item {
  const row = normalizeCurrentViewPreservationBundleV1Item(item);
  exact(value, ["contentHash", "sha256Digest", "canonicalizationId", "byteSize"]);
  const size = uint(value.byteSize, 64), canon = bytes(value.canonicalizationId, 32);
  const keccak = bytes(value.contentHash, 32), sha = bytes(value.sha256Digest, 32);
  if (row.digest.length !== 66 || row.canonicalizationId !== canon || size === 0n
    || (row.byteSize !== 0n && row.byteSize !== size)
    || (row.kind !== 5n && row.kind !== 10n && canon !== RAW && canon !== JCS
      && !currentViewPreservationBundleV1SupportedAbiCorrespondence(row))) throw Error("Object correspondence differs");
  const expected = row.algorithm === 1n ? keccak : row.algorithm === 2n ? sha : Z;
  if (expected === Z || row.digest !== expected) throw Error("Unsupported algorithm or mismatched object digest");
  return row;
}

function empty<T>(tuple: string): T {
  const type = ParamType.from(tuple);
  return decode<T>(tuple, `0x${"00".repeat(type.components!.length * 32)}` as Hex);
}

export function currentViewPreservationBundleV1IntrinsicAdmission(
  item: CurrentViewPreservationBundleV1Item,
  proof: CurrentViewPreservationBundleV1Proof,
  immutablePartsHash: Hex = Z,
): CurrentViewPreservationBundleV1Admission {
  const row = normalizeCurrentViewPreservationBundleV1Item(item);
  const p = validateCurrentViewPreservationBundleV1Proof(row, proof);
  if (!intrinsic(row.kind)) throw Error("Item requires original archive admission");
  const parts = bytes(immutablePartsHash, 32);
  if (row.kind !== 6n && parts !== Z) throw Error("Incorrect intrinsic parts commitment");
  const bundle = row.kind === 6n
    ? hash(["bytes32", CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ITEM_TUPLE, "bytes32"], [id("STATE_RETAINED_ORIGINAL_AUTHORIZATION"), row, parts])
    : hash(["bytes32", CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ITEM_TUPLE], [id("EXPLICIT_INVENTORY_APPLICABILITY"), row]);
  return Object.freeze({ proof: p, originalBundleHash: bundle, immutablePartsHash: parts,
    externalOriginal: empty<CurrentViewPreservationBundleV1ExternalCoverage>(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_EXTERNAL_COVERAGE_TUPLE),
    onchainOriginal: empty<CurrentViewPreservationBundleV1OnchainCoverage>(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ONCHAIN_COVERAGE_TUPLE) });
}

/** Checks the supplied retained Admission, without asserting original archive-byte or current-pair readback. */
export function validateCurrentViewPreservationBundleV1Admission(
  artistId: Hex,
  item: CurrentViewPreservationBundleV1Item,
  admission: CurrentViewPreservationBundleV1Admission,
): CurrentViewPreservationBundleV1Admission {
  const artist = nonzero(artistId), row = normalizeCurrentViewPreservationBundleV1Item(item);
  const a = normalizeCurrentViewPreservationBundleV1Admission(admission);
  validateCurrentViewPreservationBundleV1Proof(row, a.proof);
  nonzero(a.originalBundleHash);
  if (intrinsic(row.kind)) {
    if (encodeCurrentViewPreservationBundleV1Admission(a) !== encodeCurrentViewPreservationBundleV1Admission(
      currentViewPreservationBundleV1IntrinsicAdmission(row, a.proof, a.immutablePartsHash))) throw Error("Intrinsic admission differs");
  } else if (a.proof.backend === 1n) {
    const c = a.externalOriginal;
    if (c.coverageHash !== a.proof.coverageHash || c.objectHash !== a.proof.objectHash || c.artistId !== artist
      || a.immutablePartsHash !== Z
      || encodeCurrentViewPreservationBundleV1OnchainCoverage(a.onchainOriginal) !== encodeCurrentViewPreservationBundleV1OnchainCoverage(
        empty<CurrentViewPreservationBundleV1OnchainCoverage>(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ONCHAIN_COVERAGE_TUPLE))) throw Error("External admission fields differ");
    [c.firstReceiptHash, c.secondReceiptHash, c.firstFixityHash, c.secondFixityHash].forEach(nonzero);
    validateCurrentViewPreservationBundleV1Correspondence(
      row.role === inventory.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_LOCATOR_ROLE
        ? { ...row, algorithm: 1n, digest: c.contentHash, byteSize: c.byteSize } : row,
      { contentHash: c.contentHash, sha256Digest: c.sha256Digest,
      canonicalizationId: row.canonicalizationId, byteSize: c.byteSize });
  } else {
    const c = a.onchainOriginal;
    if (c.completionHash !== a.proof.coverageHash || c.artifactHash !== a.proof.objectHash || c.artistId !== artist
      || (row.schemaId !== Z && row.schemaId !== c.schemaId)
      || encodeCurrentViewPreservationBundleV1ExternalCoverage(a.externalOriginal) !== encodeCurrentViewPreservationBundleV1ExternalCoverage(
        empty<CurrentViewPreservationBundleV1ExternalCoverage>(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_EXTERNAL_COVERAGE_TUPLE))) throw Error("Onchain admission fields differ");
    validateCurrentViewPreservationBundleV1Correspondence(row, { contentHash: c.contentHash, sha256Digest: Z,
      canonicalizationId: c.canonicalizationId, byteSize: c.byteLength });
  }
  return a;
}

export function validateCurrentViewPreservationBundleV1NextItem(
  progress: CurrentViewPreservationBundleV1Progress,
  segment: CurrentViewPreservationBundleV1Segment,
  item: CurrentViewPreservationBundleV1Item,
  nextLink: Hex,
): void {
  const p = normalizeCurrentViewPreservationBundleV1Progress(progress);
  const s = original.validateScopedPolicyInventoryV2Segment(segment);
  if (p.complete || inventory.currentViewPreservationInventoryV1Link(s.key, s.itemCount, p.segmentItemIndex, item, nextLink) !== p.nextLink) {
    throw Error("Item does not match the original next occurrence");
  }
}

export function validateCurrentViewPreservationBundleV1EmptySegment(
  progress: CurrentViewPreservationBundleV1Progress,
  segment: CurrentViewPreservationBundleV1Segment,
): void {
  const p = normalizeCurrentViewPreservationBundleV1Progress(progress);
  const s = original.validateScopedPolicyInventoryV2Segment(segment);
  if (p.complete || s.itemCount !== 0n || s.firstLink !== Z || p.segmentItemIndex !== 0n || p.nextLink !== Z) {
    throw Error("Original empty segment is not ready");
  }
}



/** Exact a297 closed vocabulary from unchanged StreamInventoryAbiCorrespondence. This checks byte correspondence eligibility, not producer authority. */
export function currentViewPreservationBundleV1SupportedAbiCorrespondence(value: CurrentViewPreservationBundleV1Item): boolean {
  const row = normalizeCurrentViewPreservationBundleV1Item(value);
  const abi = id("STREAM_SOLIDITY_ABI_V1");
  if (row.kind === 4n) return row.role === id("SIGNIFICANT_PROPERTIES") && row.sourceIndex === 8n
    && row.schemaId === Z && row.byteSize === 0n && row.canonicalizationId === abi
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

function validateLocator(item: CurrentViewPreservationBundleV1Item): void {
  // Only the original Media.item coordinates are used on this branch.
  const source: retrieval.CurrentViewRetrievalV1Source = {
    scope: { scopeType: 4n, collectionId: 0n, tokenId: 0n, scopeId: Z },
    core: ZeroAddress as Address, router: ZeroAddress as Address, adoptionRecord: Z,
    adoptionSourceHash: Z, declaration: item.source, declarationRecord: item.sourceRecord,
    payloadHash: Z, checkpointContextHash: Z, requestedURI: item.uri, artistId: Z, artistPresentationHash: Z,
  };
  const expected = inventory.currentViewPreservationInventoryV1Obligation(source);
  if (expected.role !== inventory.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_LOCATOR_ROLE) throw Error("Not an original exact locator");
  equalTuple(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ITEM_TUPLE, item, expected, "Locator shape");
}

/** Available original external-admission identities; no current pair or byte reads. */
function validateRetainedExternal(artist: Hex, a: CurrentViewPreservationBundleV1Admission): void {
  same(a.proof.backend, 1n, "External backend");
  same(a.externalOriginal.artistId, nonzero(artist), "Retained archive artist");
  same(a.externalOriginal.coverageHash, nonzero(a.proof.coverageHash), "Retained coverage");
  same(a.externalOriginal.objectHash, nonzero(a.proof.objectHash), "Retained object");
  same(a.immutablePartsHash, Z, "External parts");
  nonzero(a.originalBundleHash);
  nonzero(a.externalOriginal.contentHash);
  if (a.externalOriginal.byteSize === 0n) throw Error("Empty retained external object");
  [a.externalOriginal.firstReceiptHash, a.externalOriginal.secondReceiptHash,
    a.externalOriginal.firstFixityHash, a.externalOriginal.secondFixityHash].forEach(nonzero);
  equalTuple(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ONCHAIN_COVERAGE_TUPLE, a.onchainOriginal,
    empty<CurrentViewPreservationBundleV1OnchainCoverage>(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ONCHAIN_COVERAGE_TUPLE), "External onchain fields");
}

/** A nonzero stored mapping, including for a legacy locator, selects retrieval replay. */
export function currentViewPreservationBundleV1CurrentRoute(witnessHash: Hex): "generic" | "retrieval" {
  return bytes(witnessHash, 32) === Z ? "generic" : "retrieval";
}

export function validateCurrentViewPreservationBundleV1RetainedAdmission(
  artistId: Hex, item: CurrentViewPreservationBundleV1Item,
  admission: CurrentViewPreservationBundleV1Admission, witnessHash: Hex,
): CurrentViewPreservationBundleV1Admission {
  const row = normalizeCurrentViewPreservationBundleV1Item(item);
  const a = normalizeCurrentViewPreservationBundleV1Admission(admission);
  if (bytes(witnessHash, 32) === Z) return validateCurrentViewPreservationBundleV1Admission(artistId, row, a);
  if (row.role !== inventory.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RETRIEVAL_ROLE
    && row.role !== inventory.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_LOCATOR_ROLE) throw Error("Unexpected witness mapping");
  validateRetainedExternal(artistId, a);
  return a;
}

export function validateCurrentViewPreservationBundleV1Evidence(
  coordinates: CurrentViewPreservationBundleV1Coordinates, dependencyHash: Hex,
  originalEvidence: CurrentViewPreservationBundleV1InventoryEvidence, value: CurrentViewPreservationBundleV1Evidence,
): CurrentViewPreservationBundleV1Evidence {
  const i = inventory.normalizeCurrentViewPreservationInventoryV1Evidence(originalEvidence);
  const e = normalizeCurrentViewPreservationBundleV1Evidence(value);
  inventory.validateCurrentViewPreservationInventoryV1Scope(i.scope);
  equalTuple(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_SCOPE_TUPLE, e.scope, i.scope, "Bundle full scope");
  same(e.coverage.inventoryPlan, nonzero(i.inventory.planId), "Inventory plan");
  same(e.coverage.renderCriticalEvidenceHash, nonzero(i.inventory.renderCriticalEvidenceHash), "Inventory evidence");
  if (i.inventory.itemCount === 0n) throw Error("Empty complete coverage");
  same(e.coverage.itemCount, i.inventory.itemCount, "Item count");
  same(e.coverage.bundleCoverageHash, currentViewPreservationBundleV1CoverageHash(coordinates, dependencyHash, i, e), "Coverage hash");
  return e;
}

export interface CurrentViewPreservationBundleV1StoredItem {
  readonly item: CurrentViewPreservationBundleV1Item;
  readonly admission: CurrentViewPreservationBundleV1Admission;
  readonly witnessHash: Hex;
}

/** Immutable row/mapping commitments; this does not re-run source, pair, signature or revocation checks. */
export function authenticateCurrentViewPreservationBundleV1History(
  coordinates: CurrentViewPreservationBundleV1Coordinates,
  dependencies: CurrentViewPreservationBundleV1Dependencies,
  inventoryDependencyHash: Hex,
  originalEvidence: CurrentViewPreservationBundleV1InventoryEvidence,
  evidence: CurrentViewPreservationBundleV1Evidence,
  segments: readonly Readonly<{ segment: CurrentViewPreservationBundleV1Segment; items: readonly CurrentViewPreservationBundleV1Item[] }>[],
  rows: readonly CurrentViewPreservationBundleV1StoredItem[],
): Readonly<{ evidence: CurrentViewPreservationBundleV1Evidence; rows: readonly CurrentViewPreservationBundleV1StoredItem[];
  currentnessVerified: false; retrievalCorrespondenceIndependentlyReconstructed: false;
  itemProductionIndependentlyReconstructed: false; initialObservationIndependentlyReconstructed: false }> {
  inventory.validateCurrentViewPreservationInventoryV1Segments(segments);
  list(rows);
  let historyBytes = 0;
  for (const row of rows) {
    exact(row, ["item", "admission", "witnessHash"]);
    historyBytes += 32 + preflight(ParamType.from(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ITEM_TUPLE), row.item, false)
      + preflight(ParamType.from(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ADMISSION_TUPLE), row.admission, false);
    if (historyBytes > CURRENT_VIEW_PRESERVATION_BUNDLE_V1_MAX_HISTORY_BYTES) throw Error("History allocation bound");
  }
  const c = normalizeCurrentViewPreservationBundleV1Coordinates(coordinates);
  const d = validateCurrentViewPreservationBundleV1Dependencies(c, dependencies);
  const ic = { chainId: c.chainId, core: c.core, inventory: d.targets[2] };
  const i = inventory.validateCurrentViewPreservationInventoryV1Evidence(ic, inventoryDependencyHash, originalEvidence);
  const e = validateCurrentViewPreservationBundleV1Evidence(c, currentViewPreservationBundleV1DependencyHash(d), i, evidence);
  list(segments);
  list(rows);
  same(BigInt(segments.length), i.inventory.segmentCount, "Segment count");
  same(BigInt(rows.length), i.inventory.itemCount, "Item count");
  let segmentChain = Z, itemChain = Z, cursor = 0;
  const owned: CurrentViewPreservationBundleV1StoredItem[] = [];
  segments.forEach((part, index) => {
    exact(part, ["segment", "items"]);
    const s = inventory.normalizeCurrentViewPreservationInventoryV1Segment(part.segment);
    same(s.key, inventory.currentViewPreservationInventoryV1SegmentKey(i.inventory.planId, BigInt(index)), "Segment key");
    equalTuple(inventory.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SEGMENT_TUPLE, s,
      inventory.currentViewPreservationInventoryV1Segment(s.key, s.sourceWitnessHash, part.items), "Segment rows");
    segmentChain = inventory.currentViewPreservationInventoryV1AppendSegment(segmentChain, BigInt(index), s);
    for (const item of part.items) {
      const stored = rows[cursor];
      if (!stored) throw Error("Missing stored row");
      exact(stored, ["item", "admission", "witnessHash"]);
      const row = normalizeCurrentViewPreservationBundleV1Item(stored.item);
      const admission = normalizeCurrentViewPreservationBundleV1Admission(stored.admission);
      const witnessHash = bytes(stored.witnessHash, 32);
      equalTuple(CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ITEM_TUPLE, row, item, "Stored item occurrence");
      validateCurrentViewPreservationBundleV1RetainedAdmission(i.inventory.artistId, row, admission, witnessHash);
      itemChain = currentViewPreservationBundleV1CoveredItemChain(itemChain, i.inventory.planId, BigInt(cursor),
        inventory.currentViewPreservationInventoryV1ItemHash(row), admission);
      owned.push(Object.freeze({ item: row, admission, witnessHash }));
      ++cursor;
    }
  });
  same(cursor, rows.length, "Stored rows exhausted");
  same(segmentChain, i.inventory.segmentChainHash, "Segment chain");
  same(itemChain, e.coverage.evidenceChainHash, "Covered item chain");
  return Object.freeze({ evidence: e, rows: Object.freeze(owned), currentnessVerified: false,
    retrievalCorrespondenceIndependentlyReconstructed: false,
    itemProductionIndependentlyReconstructed: false, initialObservationIndependentlyReconstructed: false });
}

/** Supplied public refresh prestate plus the original reader's observation, not a currentness proof. */
export function currentViewPreservationBundleV1RefreshStep(
  before: CurrentViewPreservationBundleV1Refresh, expectedIndex: bigint, itemCount: bigint,
  item: CurrentViewPreservationBundleV1Item, observation: Hex,
): CurrentViewPreservationBundleV1Refresh {
  const r = normalizeCurrentViewPreservationBundleV1Refresh(before);
  const index = uint(expectedIndex, 64), count = uint(itemCount, 64);
  if (r.environmentHash === Z || r.complete || r.nextIndex !== index || index >= count) throw Error("Refresh prestate");
  return normalizeCurrentViewPreservationBundleV1Refresh({ ...r, nextIndex: index + 1n,
    currentObservationChain: currentViewPreservationBundleV1ObservationChain(r.currentObservationChain, index,
      inventory.currentViewPreservationInventoryV1ItemHash(item), bytes(observation, 32)), complete: index + 1n === count });
}

export const CURRENT_VIEW_PRESERVATION_BUNDLE_V1_INTERFACE_ID = "0xafce9e0d" as Hex;
