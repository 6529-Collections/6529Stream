import {
  AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress,
  id, isHexString, keccak256, recoverAddress, sha256, toUtf8Bytes,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";

/** Original attributed claim. Supplied values do not establish live source or Archive admission. */
export const CURRENT_VIEW_RETRIEVAL_V1_SOURCE = "a2973d360f6ab18881c04d58193f855704ec56d3";
export const CURRENT_VIEW_RETRIEVAL_V1_PROFILE = id("6529STREAM_VIEW_ATTRIBUTED_RETRIEVAL_V1") as Hex;
export const CURRENT_VIEW_RETRIEVAL_V1_ROLE = id("VIEW_ATTRIBUTED_RETRIEVAL_IMAGE") as Hex;
export const CURRENT_VIEW_RETRIEVAL_V1_MAX_PAYLOAD_BYTES = 524288;
export const CURRENT_VIEW_RETRIEVAL_V1_MAX_SIGNATURE_BYTES = 4096;
export const CURRENT_VIEW_RETRIEVAL_V1_MAX_URI_BYTES = 2048;
export const CURRENT_VIEW_RETRIEVAL_V1_SEGMENT_BYTES = 8192;
/** Client allocation ceilings, not additional original protocol row limits. */
export const CURRENT_VIEW_RETRIEVAL_V1_MAX_CODEC_BYTES = 1048576;
export const CURRENT_VIEW_RETRIEVAL_V1_MAX_CODEC_ROWS = 16384;

export interface CurrentViewRetrievalV1Coordinates {
  readonly chainId: bigint;
  readonly witness: Address;
}
export interface CurrentViewRetrievalV1Scope {
  readonly scopeType: bigint;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly scopeId: Hex;
}
export interface CurrentViewRetrievalV1Configuration {
  readonly core: Address;
  readonly coreCodeHash: Hex;
  readonly router: Address;
  readonly routerCodeHash: Hex;
  readonly checkpoint: Address;
  readonly checkpointCodeHash: Hex;
  readonly archive: Address;
  readonly archiveCodeHash: Hex;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly archiveGas: bigint;
  readonly signatureGas: bigint;
}
export interface CurrentViewRetrievalV1Source {
  readonly scope: CurrentViewRetrievalV1Scope;
  readonly core: Address;
  readonly router: Address;
  readonly adoptionRecord: Hex;
  readonly adoptionSourceHash: Hex;
  readonly declaration: Address;
  readonly declarationRecord: Hex;
  readonly payloadHash: Hex;
  readonly checkpointContextHash: Hex;
  readonly requestedURI: string;
  readonly artistId: Hex;
  readonly artistPresentationHash: Hex;
}
export interface CurrentViewRetrievalV1Step {
  readonly kind: bigint;
  readonly fromURI: string;
  readonly toURI: string;
  readonly status: bigint;
  readonly manifestObject: Hex;
  readonly manifestCoverage: Hex;
  readonly manifestBytes: Hex;
}
/** Original Request, not an unsigned transaction discriminator. */
export interface CurrentViewRetrievalV1Request {
  readonly scope: CurrentViewRetrievalV1Scope;
  readonly coverageHash: Hex;
  readonly steps: readonly CurrentViewRetrievalV1Step[];
  readonly resolvedURI: string;
  readonly observedAt: bigint;
  readonly nonce: bigint;
  readonly deadline: bigint;
}
export interface CurrentViewRetrievalV1Object {
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
export interface CurrentViewRetrievalV1Coverage {
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
export interface CurrentViewRetrievalV1CurrentPair {
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
export interface CurrentViewRetrievalV1Proof {
  readonly backend: bigint;
  readonly coverageHash: Hex;
  readonly objectHash: Hex;
}
export interface CurrentViewRetrievalV1OnchainCoverage {
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
export interface CurrentViewRetrievalV1Admission {
  readonly proof: CurrentViewRetrievalV1Proof;
  readonly originalBundleHash: Hex;
  readonly immutablePartsHash: Hex;
  readonly externalOriginal: CurrentViewRetrievalV1Coverage;
  readonly onchainOriginal: CurrentViewRetrievalV1OnchainCoverage;
}
export interface CurrentViewRetrievalV1Observation {
  readonly source: CurrentViewRetrievalV1Source;
  readonly object: CurrentViewRetrievalV1Object;
  readonly coverage: CurrentViewRetrievalV1Coverage;
  readonly steps: readonly CurrentViewRetrievalV1Step[];
  readonly resolvedURI: string;
  readonly writer: Address;
  readonly observedAt: bigint;
  readonly nonce: bigint;
  readonly deadline: bigint;
}
export interface CurrentViewRetrievalV1Receipt {
  readonly recordHash: Hex;
  readonly sourceKey: Hex;
  readonly observationHash: Hex;
  readonly objectHash: Hex;
  readonly coverageHash: Hex;
  readonly writer: Address;
  readonly recordedAt: bigint;
  readonly payloadHash: Hex;
  readonly payloadBytes: bigint;
}
export interface CurrentViewRetrievalV1ArchiveReceipt {
  readonly objectHash: Hex;
  readonly familyRecordHash: Hex;
  readonly storageIdentifierHash: Hex;
  readonly evidenceClass: Hex;
  readonly proofProfileHash: Hex;
  readonly proofRecordHash: Hex;
  readonly writer: Address;
  readonly observedAt: bigint;
  readonly nonce: bigint;
  readonly deadline: bigint;
}

export const CURRENT_VIEW_RETRIEVAL_V1_SCOPE_TUPLE = "(uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId)";
export const CURRENT_VIEW_RETRIEVAL_V1_CONFIGURATION_TUPLE = "(address core,bytes32 coreCodeHash,address router,bytes32 routerCodeHash,address checkpoint,bytes32 checkpointCodeHash,address archive,bytes32 archiveCodeHash,uint256 chainId,uint32 readGas,uint32 sourceGas,uint32 archiveGas,uint32 signatureGas)";
export const CURRENT_VIEW_RETRIEVAL_V1_SOURCE_TUPLE = "((uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId) scope,address core,address router,bytes32 adoptionRecord,bytes32 adoptionSourceHash,address declaration,bytes32 declarationRecord,bytes32 payloadHash,bytes32 checkpointContextHash,string requestedURI,bytes32 artistId,bytes32 artistPresentationHash)";
export const CURRENT_VIEW_RETRIEVAL_V1_STEP_TUPLE = "(uint8 kind,string fromURI,string toURI,uint16 status,bytes32 manifestObject,bytes32 manifestCoverage,bytes manifestBytes)";
export const CURRENT_VIEW_RETRIEVAL_V1_REQUEST_TUPLE = `(${CURRENT_VIEW_RETRIEVAL_V1_SCOPE_TUPLE} scope,bytes32 coverageHash,${CURRENT_VIEW_RETRIEVAL_V1_STEP_TUPLE}[] steps,string resolvedURI,uint64 observedAt,uint256 nonce,uint64 deadline)`;
export const CURRENT_VIEW_RETRIEVAL_V1_OBJECT_TUPLE = "(bytes32 artistId,bytes32 schemaId,bytes32 canonicalizationId,bytes32 contentHash,bytes32 sha256Digest,bytes32 arweaveDataRoot,uint64 byteSize,bytes32 formatId,bytes32 formatCatalogId,bytes32 formatCatalogHash)";
export const CURRENT_VIEW_RETRIEVAL_V1_COVERAGE_TUPLE = "(bytes32 coverageHash,bytes32 objectHash,bytes32 artistId,bytes32 contentHash,bytes32 sha256Digest,bytes32 arweaveDataRoot,uint64 byteSize,bytes32 firstFamilyRecordHash,bytes32 secondFamilyRecordHash,bytes32 firstReceiptHash,bytes32 secondReceiptHash,bytes32 firstFixityHash,bytes32 secondFixityHash,bytes32 checkpointHash,bytes32 profileHash)";
export const CURRENT_VIEW_RETRIEVAL_V1_CURRENT_PAIR_TUPLE = "(bytes32 objectHash,bytes32 artistId,bytes32 contentHash,bytes32 sha256Digest,bytes32 arweaveDataRoot,uint64 byteSize,bytes32 firstFamilyRecordHash,bytes32 secondFamilyRecordHash,bytes32 firstReceiptHash,bytes32 secondReceiptHash,bytes32 firstFixityHash,bytes32 secondFixityHash,bytes32 checkpointHash,bytes32 profileHash)";
export const CURRENT_VIEW_RETRIEVAL_V1_PROOF_TUPLE = "(uint8 backend,bytes32 coverageHash,bytes32 objectHash)";
export const CURRENT_VIEW_RETRIEVAL_V1_ONCHAIN_COVERAGE_TUPLE = "(bytes32 completionHash,bytes32 artifactHash,bytes32 artistId,bytes32 schemaId,bytes32 canonicalizationId,bytes32 contentHash,uint64 byteLength,uint32 chunkCount,bytes32 firstFamilyRecordHash,bytes32 secondFamilyRecordHash,uint64 validationEpoch,bytes32 evidenceChainHash)";
export const CURRENT_VIEW_RETRIEVAL_V1_ADMISSION_TUPLE = `(${CURRENT_VIEW_RETRIEVAL_V1_PROOF_TUPLE} proof,bytes32 originalBundleHash,bytes32 immutablePartsHash,${CURRENT_VIEW_RETRIEVAL_V1_COVERAGE_TUPLE} externalOriginal,${CURRENT_VIEW_RETRIEVAL_V1_ONCHAIN_COVERAGE_TUPLE} onchainOriginal)`;
export const CURRENT_VIEW_RETRIEVAL_V1_OBSERVATION_TUPLE = `(${CURRENT_VIEW_RETRIEVAL_V1_SOURCE_TUPLE} source,${CURRENT_VIEW_RETRIEVAL_V1_OBJECT_TUPLE} object,${CURRENT_VIEW_RETRIEVAL_V1_COVERAGE_TUPLE} coverage,${CURRENT_VIEW_RETRIEVAL_V1_STEP_TUPLE}[] steps,string resolvedURI,address writer,uint64 observedAt,uint256 nonce,uint64 deadline)`;
export const CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE = "(bytes32 recordHash,bytes32 sourceKey,bytes32 observationHash,bytes32 objectHash,bytes32 coverageHash,address writer,uint64 recordedAt,bytes32 payloadHash,uint32 payloadBytes)";
export const CURRENT_VIEW_RETRIEVAL_V1_ARCHIVE_RECEIPT_TUPLE = "(bytes32 objectHash,bytes32 familyRecordHash,bytes32 storageIdentifierHash,bytes32 evidenceClass,bytes32 proofProfileHash,bytes32 proofRecordHash,address writer,uint64 observedAt,uint256 nonce,uint64 deadline)";

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
function bytes(value: unknown, length?: number, maximum = CURRENT_VIEW_RETRIEVAL_V1_MAX_CODEC_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, length ?? true)
    || (value.length - 2) / 2 > maximum) throw Error("Invalid bytes or allocation bound");
  return value.toLowerCase() as Hex;
}
function nonzero(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === Z) throw Error("Zero commitment");
  return result;
}
function list(value: unknown, maximum = CURRENT_VIEW_RETRIEVAL_V1_MAX_CODEC_ROWS): readonly unknown[] {
  if (!Array.isArray(value) || value.length > maximum || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.prototype.hasOwnProperty.call(value, i))) throw Error("Invalid dense array");
  return value;
}
function utf8(value: unknown): Uint8Array {
  if (typeof value !== "string") throw Error("Invalid string");
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
function valueOf(t: ParamType, value: unknown, decoded: boolean): unknown {
  if (t.baseType === "array") return Object.freeze(list(value).map(x => valueOf(t.arrayChildren!, x, decoded)));
  if (t.baseType === "tuple") {
    if (!decoded) exact(value, t.components!.map(c => c.name));
    const result = Object.fromEntries(t.components!.map((c, i) => [c.name,
      valueOf(c, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[c.name], decoded)]));
    if ("scopeType" in result && (result.scopeType as bigint) > 4n) throw Error("Invalid original scope enum");
    return Object.freeze(result);
  }
  if (t.type.startsWith("uint")) return uint(value, Number(t.type.slice(4)));
  if (t.type === "address") return address(value);
  if (t.type === "string") {
    if (utf8(value).length > CURRENT_VIEW_RETRIEVAL_V1_MAX_CODEC_BYTES) throw Error("Invalid UTF-8 string bound");
    return value;
  }
  if (t.type.startsWith("bytes")) return bytes(value, t.type === "bytes" ? undefined : Number(t.type.slice(5)));
  throw Error("Unsupported original ABI type");
}
function normalize<T>(tuple: string, value: unknown, decoded = false): T {
  return valueOf(ParamType.from(tuple), value, decoded) as T;
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

export function normalizeCurrentViewRetrievalV1Coordinates(value: CurrentViewRetrievalV1Coordinates): CurrentViewRetrievalV1Coordinates {
  exact(value, ["chainId", "witness"]);
  if (uint(value.chainId) === 0n) throw Error("Zero chain ID");
  return Object.freeze({ chainId: value.chainId, witness: address(value.witness, true) });
}

export function normalizeCurrentViewRetrievalV1Scope(value: CurrentViewRetrievalV1Scope): CurrentViewRetrievalV1Scope {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_SCOPE_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1Scope(value: CurrentViewRetrievalV1Scope): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_SCOPE_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1Scope(value: Hex): CurrentViewRetrievalV1Scope {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_SCOPE_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1Configuration(value: CurrentViewRetrievalV1Configuration): CurrentViewRetrievalV1Configuration {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_CONFIGURATION_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1Configuration(value: CurrentViewRetrievalV1Configuration): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_CONFIGURATION_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1Configuration(value: Hex): CurrentViewRetrievalV1Configuration {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_CONFIGURATION_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1Source(value: CurrentViewRetrievalV1Source): CurrentViewRetrievalV1Source {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_SOURCE_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1Source(value: CurrentViewRetrievalV1Source): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_SOURCE_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1Source(value: Hex): CurrentViewRetrievalV1Source {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_SOURCE_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1Step(value: CurrentViewRetrievalV1Step): CurrentViewRetrievalV1Step {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_STEP_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1Step(value: CurrentViewRetrievalV1Step): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_STEP_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1Step(value: Hex): CurrentViewRetrievalV1Step {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_STEP_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1Request(value: CurrentViewRetrievalV1Request): CurrentViewRetrievalV1Request {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_REQUEST_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1Request(value: CurrentViewRetrievalV1Request): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_REQUEST_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1Request(value: Hex): CurrentViewRetrievalV1Request {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_REQUEST_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1Object(value: CurrentViewRetrievalV1Object): CurrentViewRetrievalV1Object {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_OBJECT_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1Object(value: CurrentViewRetrievalV1Object): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_OBJECT_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1Object(value: Hex): CurrentViewRetrievalV1Object {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_OBJECT_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1Coverage(value: CurrentViewRetrievalV1Coverage): CurrentViewRetrievalV1Coverage {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_COVERAGE_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1Coverage(value: CurrentViewRetrievalV1Coverage): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_COVERAGE_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1Coverage(value: Hex): CurrentViewRetrievalV1Coverage {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_COVERAGE_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1CurrentPair(value: CurrentViewRetrievalV1CurrentPair): CurrentViewRetrievalV1CurrentPair {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_CURRENT_PAIR_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1CurrentPair(value: CurrentViewRetrievalV1CurrentPair): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_CURRENT_PAIR_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1CurrentPair(value: Hex): CurrentViewRetrievalV1CurrentPair {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_CURRENT_PAIR_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1Proof(value: CurrentViewRetrievalV1Proof): CurrentViewRetrievalV1Proof {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_PROOF_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1Proof(value: CurrentViewRetrievalV1Proof): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_PROOF_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1Proof(value: Hex): CurrentViewRetrievalV1Proof {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_PROOF_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1OnchainCoverage(value: CurrentViewRetrievalV1OnchainCoverage): CurrentViewRetrievalV1OnchainCoverage {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_ONCHAIN_COVERAGE_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1OnchainCoverage(value: CurrentViewRetrievalV1OnchainCoverage): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_ONCHAIN_COVERAGE_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1OnchainCoverage(value: Hex): CurrentViewRetrievalV1OnchainCoverage {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_ONCHAIN_COVERAGE_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1Admission(value: CurrentViewRetrievalV1Admission): CurrentViewRetrievalV1Admission {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_ADMISSION_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1Admission(value: CurrentViewRetrievalV1Admission): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_ADMISSION_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1Admission(value: Hex): CurrentViewRetrievalV1Admission {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_ADMISSION_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1Observation(value: CurrentViewRetrievalV1Observation): CurrentViewRetrievalV1Observation {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_OBSERVATION_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1Observation(value: CurrentViewRetrievalV1Observation): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_OBSERVATION_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1Observation(value: Hex): CurrentViewRetrievalV1Observation {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_OBSERVATION_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1Receipt(value: CurrentViewRetrievalV1Receipt): CurrentViewRetrievalV1Receipt {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1Receipt(value: CurrentViewRetrievalV1Receipt): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1Receipt(value: Hex): CurrentViewRetrievalV1Receipt {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1ArchiveReceipt(value: CurrentViewRetrievalV1ArchiveReceipt): CurrentViewRetrievalV1ArchiveReceipt {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_ARCHIVE_RECEIPT_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1ArchiveReceipt(value: CurrentViewRetrievalV1ArchiveReceipt): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_ARCHIVE_RECEIPT_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1ArchiveReceipt(value: Hex): CurrentViewRetrievalV1ArchiveReceipt {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_ARCHIVE_RECEIPT_TUPLE, value);
}

export function normalizeCurrentViewRetrievalV1Family(value: CurrentViewRetrievalV1Family): CurrentViewRetrievalV1Family {
  return normalize(CURRENT_VIEW_RETRIEVAL_V1_FAMILY_TUPLE, value);
}
export function encodeCurrentViewRetrievalV1Family(value: CurrentViewRetrievalV1Family): Hex {
  return encode(CURRENT_VIEW_RETRIEVAL_V1_FAMILY_TUPLE, value);
}
export function decodeCurrentViewRetrievalV1Family(value: Hex): CurrentViewRetrievalV1Family {
  return decode(CURRENT_VIEW_RETRIEVAL_V1_FAMILY_TUPLE, value);
}


/** Original literal URI grammar. No URL normalization, JSON interpretation or network assertion. */
export function currentViewRetrievalV1URI(value: string): Readonly<{ kind: 1n | 2n | 3n; transactionId: Hex }> {
  if (typeof value !== "string") throw Error("Invalid URI");
  const raw = utf8(value);
  if (!raw.length || raw.length > CURRENT_VIEW_RETRIEVAL_V1_MAX_URI_BYTES
    || raw.some(x => x <= 32 || x === 127)) throw Error("Invalid retrieval URI bytes");
  if (value.startsWith("https://")) {
    if (raw.length <= 8 || [47, 63, 35].includes(raw[8]!)) throw Error("Invalid HTTPS host");
    return Object.freeze({ kind: 1n, transactionId: Z });
  }
  if (!value.startsWith("ar://") || raw.length < 48) throw Error("Invalid retrieval URI scheme");
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
  let accumulator = 0n;
  for (let i = 5; i < 48; ++i) {
    const digit = alphabet.indexOf(String.fromCharCode(raw[i]!));
    if (digit < 0) throw Error("Invalid Arweave transaction encoding");
    accumulator = (accumulator << 6n) | BigInt(digit);
  }
  if ((accumulator & 3n) !== 0n || accumulator >> 2n === 0n) throw Error("Noncanonical or zero Arweave transaction");
  const transactionId = (`0x${(accumulator >> 2n).toString(16).padStart(64, "0")}`) as Hex;
  if (raw.length === 48) return Object.freeze({ kind: 2n, transactionId });
  if (raw[48] !== 47 || raw.length === 49) throw Error("Invalid Arweave path");
  return Object.freeze({ kind: 3n, transactionId });
}

export function validateCurrentViewRetrievalV1Scope(value: CurrentViewRetrievalV1Scope): CurrentViewRetrievalV1Scope {
  const scope = normalize<CurrentViewRetrievalV1Scope>(CURRENT_VIEW_RETRIEVAL_V1_SCOPE_TUPLE, value);
  if (scope.scopeType !== 4n || scope.collectionId === 0n || scope.tokenId !== 0n || scope.scopeId === Z) throw Error("Retrieval requires a VIEW scope");
  return scope;
}
/** Supplied deployment bounds and pins only; no runtime or interface assertion. */
export function validateCurrentViewRetrievalV1Configuration(
  coordinates: CurrentViewRetrievalV1Coordinates,
  value: CurrentViewRetrievalV1Configuration,
): CurrentViewRetrievalV1Configuration {
  const c = normalizeCurrentViewRetrievalV1Coordinates(coordinates);
  const d = normalize<CurrentViewRetrievalV1Configuration>(CURRENT_VIEW_RETRIEVAL_V1_CONFIGURATION_TUPLE, value);
  same(d.chainId, c.chainId, "Configuration chain");
  for (const name of ["core", "router", "checkpoint", "archive"] as const) {
    address(d[name], true);
    nonzero(d[`${name}CodeHash`]);
  }
  if (d.readGas < 50000n || d.sourceGas < d.readGas || d.archiveGas < d.readGas || d.signatureGas < 90000n
    || d.sourceGas > 16777216n || d.archiveGas > 16777216n || d.signatureGas > 16777216n) throw Error("Invalid original gas bounds");
  return d;
}
export function validateCurrentViewRetrievalV1Source(value: CurrentViewRetrievalV1Source): CurrentViewRetrievalV1Source {
  const s = normalize<CurrentViewRetrievalV1Source>(CURRENT_VIEW_RETRIEVAL_V1_SOURCE_TUPLE, value);
  validateCurrentViewRetrievalV1Scope(s.scope);
  address(s.core, true);
  address(s.router, true);
  address(s.declaration, true);
  for (const name of ["adoptionRecord", "adoptionSourceHash", "declarationRecord", "payloadHash", "checkpointContextHash", "artistId", "artistPresentationHash"] as const) nonzero(s[name]);
  currentViewRetrievalV1URI(s.requestedURI);
  return s;
}
function routes(requested: string, steps: readonly CurrentViewRetrievalV1Step[], resolved: string): void {
  currentViewRetrievalV1URI(requested);
  if (currentViewRetrievalV1URI(resolved).kind === 3n) throw Error("Unresolved final Arweave path");
  let previous = requested;
  for (const step of steps) {
    const from = currentViewRetrievalV1URI(step.fromURI);
    const to = currentViewRetrievalV1URI(step.toURI);
    if (step.fromURI !== previous || step.toURI === previous) throw Error("Disconnected or repeated route step");
    if (step.kind === 1n) {
      if (from.kind !== 1n || ![301n, 302n, 303n, 307n, 308n].includes(step.status)) throw Error("Invalid HTTP redirect");
    } else if (step.kind === 2n) {
      if (from.kind === 3n || step.status !== 0n) throw Error("Invalid attributed mirror");
    } else if (step.kind === 3n) {
      if (from.kind !== 3n || to.kind === 1n || step.status !== 0n || step.manifestObject === Z
        || step.manifestCoverage === Z || step.manifestBytes === "0x") throw Error("Invalid Arweave manifest route");
    } else throw Error("Unknown retrieval route kind");
    if (step.kind !== 3n && (step.manifestObject !== Z || step.manifestCoverage !== Z || step.manifestBytes !== "0x")) throw Error("Unexpected manifest fields");
    previous = step.toURI;
  }
  same(previous, resolved, "Final literal URI");
}
export function validateCurrentViewRetrievalV1Request(value: CurrentViewRetrievalV1Request): CurrentViewRetrievalV1Request {
  const r = normalize<CurrentViewRetrievalV1Request>(CURRENT_VIEW_RETRIEVAL_V1_REQUEST_TUPLE, value);
  validateCurrentViewRetrievalV1Scope(r.scope);
  nonzero(r.coverageHash);
  if (r.observedAt === 0n || r.deadline < r.observedAt) throw Error("Invalid observation time interval");
  routes(r.steps.length ? r.steps[0]!.fromURI : r.resolvedURI, r.steps, r.resolvedURI);
  return r;
}
/** Exact Codec.shape checks. Archive evidence and fresh authorization are separate. */
export function validateCurrentViewRetrievalV1Observation(value: CurrentViewRetrievalV1Observation): CurrentViewRetrievalV1Observation {
  const o = normalize<CurrentViewRetrievalV1Observation>(CURRENT_VIEW_RETRIEVAL_V1_OBSERVATION_TUPLE, value);
  validateCurrentViewRetrievalV1Source(o.source);
  same(o.object.artistId, o.source.artistId, "Object Artist");
  address(o.writer, true);
  if (o.observedAt === 0n || o.deadline < o.observedAt || o.object.byteSize === 0n) throw Error("Invalid observation time or size");
  for (const value of [o.coverage.objectHash, o.coverage.coverageHash, o.object.contentHash, o.object.sha256Digest]) nonzero(value);
  routes(o.source.requestedURI, o.steps, o.resolvedURI);
  bytes(coder.encode([CURRENT_VIEW_RETRIEVAL_V1_OBSERVATION_TUPLE, "bytes"], [o, "0x"]), undefined, CURRENT_VIEW_RETRIEVAL_V1_MAX_PAYLOAD_BYTES);
  return o;
}

export function currentViewRetrievalV1ConfigurationHash(value: CurrentViewRetrievalV1Configuration): Hex {
  return hash(["bytes32", CURRENT_VIEW_RETRIEVAL_V1_CONFIGURATION_TUPLE], [CURRENT_VIEW_RETRIEVAL_V1_PROFILE,
    normalize(CURRENT_VIEW_RETRIEVAL_V1_CONFIGURATION_TUPLE, value)]);
}
/** Deliberately omits checkpointContextHash, exactly as the original sourceKey. */
export function currentViewRetrievalV1SourceKey(value: CurrentViewRetrievalV1Source): Hex {
  const s = normalize<CurrentViewRetrievalV1Source>(CURRENT_VIEW_RETRIEVAL_V1_SOURCE_TUPLE, value);
  return hash(["bytes32", CURRENT_VIEW_RETRIEVAL_V1_SCOPE_TUPLE, "address", "address", "bytes32", "bytes32", "address", "bytes32", "bytes32", "string", "bytes32", "bytes32"],
    [id("6529STREAM_VIEW_RETRIEVAL_SOURCE_V1"), s.scope, s.core, s.router, s.adoptionRecord, s.adoptionSourceHash,
      s.declaration, s.declarationRecord, s.payloadHash, s.requestedURI, s.artistId, s.artistPresentationHash]);
}
/** Raw original digest. Do not apply an EIP-712 or personal-sign envelope. */
export function currentViewRetrievalV1Digest(
  coordinates: CurrentViewRetrievalV1Coordinates,
  configuration: CurrentViewRetrievalV1Configuration,
  observation: CurrentViewRetrievalV1Observation,
): Hex {
  const c = normalizeCurrentViewRetrievalV1Coordinates(coordinates);
  const d = normalize<CurrentViewRetrievalV1Configuration>(CURRENT_VIEW_RETRIEVAL_V1_CONFIGURATION_TUPLE, configuration);
  same(d.chainId, c.chainId, "Digest chain");
  return hash(["bytes32", "uint256", "address", "bytes32", CURRENT_VIEW_RETRIEVAL_V1_OBSERVATION_TUPLE],
    [id("6529STREAM_VIEW_RETRIEVAL_OBSERVATION_V1"), c.chainId, c.witness, currentViewRetrievalV1ConfigurationHash(d),
      normalize(CURRENT_VIEW_RETRIEVAL_V1_OBSERVATION_TUPLE, observation)]);
}
export function currentViewRetrievalV1NonceKey(writer: Address, nonce: bigint): Hex {
  return hash(["bytes32", "address", "uint256"], [id("6529STREAM_VIEW_RETRIEVAL_NONCE_V1"), address(writer), uint(nonce)]);
}
export function currentViewRetrievalV1ScopeKey(scope: CurrentViewRetrievalV1Scope): Hex {
  return hash(["bytes32", CURRENT_VIEW_RETRIEVAL_V1_SCOPE_TUPLE],
    [id("6529STREAM_VIEW_RETRIEVAL_REVOCATION_SCOPE_V1"), validateCurrentViewRetrievalV1Scope(scope)]);
}
/** The original record preimage always clears its own recordHash field. */
export function currentViewRetrievalV1RecordHash(
  coordinates: CurrentViewRetrievalV1Coordinates,
  configuration: CurrentViewRetrievalV1Configuration,
  receipt: CurrentViewRetrievalV1Receipt,
): Hex {
  const c = normalizeCurrentViewRetrievalV1Coordinates(coordinates);
  const d = normalize<CurrentViewRetrievalV1Configuration>(CURRENT_VIEW_RETRIEVAL_V1_CONFIGURATION_TUPLE, configuration);
  same(d.chainId, c.chainId, "Record chain");
  const r = normalize<CurrentViewRetrievalV1Receipt>(CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE, receipt);
  return hash(["bytes32", "uint256", "address", "bytes32", CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE],
    [id("6529STREAM_VIEW_RETRIEVAL_RECORD_V1"), c.chainId, c.witness, currentViewRetrievalV1ConfigurationHash(d), { ...r, recordHash: Z }]);
}
export function currentViewRetrievalV1Payload(observation: CurrentViewRetrievalV1Observation, signature: Hex): Hex {
  return bytes(coder.encode([CURRENT_VIEW_RETRIEVAL_V1_OBSERVATION_TUPLE, "bytes"],
    [validateCurrentViewRetrievalV1Observation(observation), bytes(signature, undefined, CURRENT_VIEW_RETRIEVAL_V1_MAX_SIGNATURE_BYTES)]),
  undefined, CURRENT_VIEW_RETRIEVAL_V1_MAX_PAYLOAD_BYTES);
}
export function decodeCurrentViewRetrievalV1Payload(value: Hex): Readonly<{ observation: CurrentViewRetrievalV1Observation; signature: Hex }> {
  const raw = bytes(value, undefined, CURRENT_VIEW_RETRIEVAL_V1_MAX_PAYLOAD_BYTES);
  if (raw === "0x") throw Error("Empty retrieval payload");
  const decoded = coder.decode([CURRENT_VIEW_RETRIEVAL_V1_OBSERVATION_TUPLE, "bytes"], raw);
  const observation = normalize<CurrentViewRetrievalV1Observation>(CURRENT_VIEW_RETRIEVAL_V1_OBSERVATION_TUPLE, decoded[0], true);
  const signature = bytes(decoded[1], undefined, CURRENT_VIEW_RETRIEVAL_V1_MAX_SIGNATURE_BYTES);
  same(currentViewRetrievalV1Payload(observation, signature), raw, "Canonical retrieval payload");
  return Object.freeze({ observation, signature });
}
export interface CurrentViewRetrievalV1Times {
  readonly timestamp: bigint;
  readonly adoptedAt: bigint;
  readonly institutionalObservedAt: bigint;
}
/** Supplied original prepare return and times only. Does not verify nonce, signature, runtime or Store. */
export function validateCurrentViewRetrievalV1Prepared(
  coordinates: CurrentViewRetrievalV1Coordinates,
  configuration: CurrentViewRetrievalV1Configuration,
  request: CurrentViewRetrievalV1Request,
  observation: CurrentViewRetrievalV1Observation,
  digest: Hex,
  times: CurrentViewRetrievalV1Times,
): CurrentViewRetrievalV1Observation {
  const d = validateCurrentViewRetrievalV1Configuration(coordinates, configuration);
  const r = validateCurrentViewRetrievalV1Request(request);
  const o = validateCurrentViewRetrievalV1Observation(observation);
  immutableObservation(o);
  exact(times, ["timestamp", "adoptedAt", "institutionalObservedAt"]);
  const now = uint(times.timestamp, 64);
  if (o.observedAt < uint(times.adoptedAt, 64) || o.observedAt < uint(times.institutionalObservedAt, 64)
    || o.observedAt > now || o.deadline < now) throw Error("Original preparation time bounds");
  equalTuple(CURRENT_VIEW_RETRIEVAL_V1_REQUEST_TUPLE, r, {
    scope: o.source.scope, coverageHash: o.coverage.coverageHash, steps: o.steps,
    resolvedURI: o.resolvedURI, observedAt: o.observedAt, nonce: o.nonce, deadline: o.deadline,
  }, "Prepared request");
  same(o.source.core, d.core, "Source Core");
  same(o.source.router, d.router, "Source Router");
  same(bytes(digest, 32), currentViewRetrievalV1Digest(coordinates, d, o), "Prepared digest");
  return o;
}
/** Predicts the original event receipt for a supplied mined timestamp, without claiming execution. */
export function currentViewRetrievalV1PreviewReceipt(
  coordinates: CurrentViewRetrievalV1Coordinates,
  configuration: CurrentViewRetrievalV1Configuration,
  observation: CurrentViewRetrievalV1Observation,
  signature: Hex,
  recordedAt: bigint,
): CurrentViewRetrievalV1Receipt {
  const o = validateCurrentViewRetrievalV1Observation(observation);
  const timestamp = uint(recordedAt, 64);
  if (timestamp < o.observedAt || timestamp > o.deadline) throw Error("Original publication time bounds");
  const payload = currentViewRetrievalV1Payload(o, signature);
  const receipt: CurrentViewRetrievalV1Receipt = {
    recordHash: Z, sourceKey: currentViewRetrievalV1SourceKey(o.source),
    observationHash: currentViewRetrievalV1Digest(coordinates, configuration, o),
    objectHash: o.coverage.objectHash, coverageHash: o.coverage.coverageHash, writer: o.writer,
    recordedAt: timestamp, payloadHash: keccak256(payload) as Hex, payloadBytes: BigInt((payload.length - 2) / 2),
  };
  return Object.freeze({ ...receipt, recordHash: currentViewRetrievalV1RecordHash(coordinates, configuration, receipt) });
}
/** Immutable commitments only; no fresh signature, current deadline, grant, pair or source reauthorization. */
export function authenticateCurrentViewRetrievalV1History(
  coordinates: CurrentViewRetrievalV1Coordinates,
  configuration: CurrentViewRetrievalV1Configuration,
  receipt: CurrentViewRetrievalV1Receipt,
  payload: Hex,
): Readonly<{ receipt: CurrentViewRetrievalV1Receipt; observation: CurrentViewRetrievalV1Observation; signature: Hex; currentnessVerified: false; signatureVerified: false }> {
  const r = normalize<CurrentViewRetrievalV1Receipt>(CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE, receipt);
  nonzero(r.recordHash);
  const decoded = decodeCurrentViewRetrievalV1Payload(payload);
  const d = normalize<CurrentViewRetrievalV1Configuration>(CURRENT_VIEW_RETRIEVAL_V1_CONFIGURATION_TUPLE, configuration);
  same(decoded.observation.source.core, d.core, "Historical source Core");
  same(decoded.observation.source.router, d.router, "Historical source Router");
  immutableObservation(decoded.observation);
  const expected = currentViewRetrievalV1PreviewReceipt(coordinates, configuration, decoded.observation, decoded.signature, r.recordedAt);
  equalTuple(CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE, r, expected, "Historical receipt");
  return Object.freeze({ receipt: r, ...decoded, currentnessVerified: false, signatureVerified: false });
}

export interface CurrentViewRetrievalV1Chunk {
  readonly index: bigint;
  readonly data: Hex;
  readonly hash: Hex;
  readonly byteLength: bigint;
  readonly runtime: Hex;
  readonly runtimeHash: Hex;
}
/** Existing STOP carriers required by publish. This planner does not establish Store availability. */
export function currentViewRetrievalV1Chunks(payload: Hex): readonly CurrentViewRetrievalV1Chunk[] {
  const raw = bytes(payload, undefined, CURRENT_VIEW_RETRIEVAL_V1_MAX_PAYLOAD_BYTES);
  if (raw === "0x") throw Error("Empty retained bytes");
  const result: CurrentViewRetrievalV1Chunk[] = [];
  for (let offset = 2; offset < raw.length; offset += 16384) {
    const data = (`0x${raw.slice(offset, offset + 16384)}`) as Hex;
    const runtime = (`0x00${data.slice(2)}`) as Hex;
    result.push(Object.freeze({ index: BigInt(result.length), data, hash: keccak256(data) as Hex,
      byteLength: BigInt((data.length - 2) / 2), runtime, runtimeHash: keccak256(runtime) as Hex }));
  }
  return Object.freeze(result);
}

export interface CurrentViewRetrievalV1Family {
  readonly familyId: Hex;
  readonly networkId: Hex;
  readonly protocolLineage: Hex;
  readonly addressingLineage: Hex;
  readonly custodianId: Hex;
  readonly fundingDependency: Hex;
  readonly retrievalDependency: Hex;
  readonly jurisdiction: Hex;
  readonly economics: bigint;
  readonly storingAgent: Address;
  readonly verifierProfileHash: Hex;
}
export const CURRENT_VIEW_RETRIEVAL_V1_FAMILY_TUPLE = "(bytes32 familyId,bytes32 networkId,bytes32 protocolLineage,bytes32 addressingLineage,bytes32 custodianId,bytes32 fundingDependency,bytes32 retrievalDependency,bytes32 jurisdiction,uint8 economics,address storingAgent,bytes32 verifierProfileHash)";

export function currentViewRetrievalV1ArchiveReceiptHash(
  configuration: CurrentViewRetrievalV1Configuration,
  value: CurrentViewRetrievalV1ArchiveReceipt,
): Hex {
  const c = normalize<CurrentViewRetrievalV1Configuration>(CURRENT_VIEW_RETRIEVAL_V1_CONFIGURATION_TUPLE, configuration);
  return hash(["bytes32", "uint256", "address", CURRENT_VIEW_RETRIEVAL_V1_ARCHIVE_RECEIPT_TUPLE],
    [id("6529STREAM_EXTERNAL_RECEIPT_V1"), c.chainId, c.archive,
      normalize(CURRENT_VIEW_RETRIEVAL_V1_ARCHIVE_RECEIPT_TUPLE, value)]);
}
/** Available immutable pair identities only; actual same-pair liveness still requires original Archive reads. */
export function validateCurrentViewRetrievalV1CurrentPair(
  original: CurrentViewRetrievalV1Coverage,
  value: CurrentViewRetrievalV1CurrentPair,
): CurrentViewRetrievalV1CurrentPair {
  const saved = normalize<CurrentViewRetrievalV1Coverage>(CURRENT_VIEW_RETRIEVAL_V1_COVERAGE_TUPLE, original);
  const pair = normalize<CurrentViewRetrievalV1CurrentPair>(CURRENT_VIEW_RETRIEVAL_V1_CURRENT_PAIR_TUPLE, value);
  for (const key of Object.keys(pair) as (keyof CurrentViewRetrievalV1CurrentPair)[]) {
    if (key === "firstFixityHash" || key === "secondFixityHash") nonzero(pair[key]);
    else same(pair[key], saved[key], `Original pair ${key}`);
  }
  return pair;
}
function admissionJoins(
  artistId: Hex,
  object: CurrentViewRetrievalV1Object,
  coverage: CurrentViewRetrievalV1Coverage,
  value: CurrentViewRetrievalV1Admission,
): CurrentViewRetrievalV1Admission {
  const a = normalize<CurrentViewRetrievalV1Admission>(CURRENT_VIEW_RETRIEVAL_V1_ADMISSION_TUPLE, value);
  if (a.proof.backend !== 1n || a.proof.objectHash !== coverage.objectHash || a.proof.coverageHash !== coverage.coverageHash) throw Error("Original external proof differs");
  equalTuple(CURRENT_VIEW_RETRIEVAL_V1_COVERAGE_TUPLE, a.externalOriginal, coverage, "Original coverage");
  same(object.artistId, nonzero(artistId), "Original object Artist");
  for (const key of ["artistId", "contentHash", "sha256Digest", "arweaveDataRoot", "byteSize"] as const) same(object[key], coverage[key], `Original object ${key}`);
  same(object.canonicalizationId, id("RAW_BYTES"), "Original object canonicalization");
  for (const key of ["firstReceiptHash", "secondReceiptHash", "firstFixityHash", "secondFixityHash"] as const) nonzero(coverage[key]);
  return a;
}
function immutableObservation(o: CurrentViewRetrievalV1Observation): void {
  same(o.object.canonicalizationId, id("RAW_BYTES"), "Original object canonicalization");
  for (const key of ["artistId", "contentHash", "sha256Digest", "arweaveDataRoot", "byteSize"] as const) same(o.object[key], o.coverage[key], `Original object ${key}`);
  for (const key of ["firstReceiptHash", "secondReceiptHash", "firstFixityHash", "secondFixityHash"] as const) nonzero(o.coverage[key]);
}
/** Joins supplied original return fields. Does not authenticate receipt signatures, native proofs or live families. */
export function validateCurrentViewRetrievalV1ArchiveAdmission(
  observation: CurrentViewRetrievalV1Observation,
  admission: CurrentViewRetrievalV1Admission,
): CurrentViewRetrievalV1Admission {
  const o = validateCurrentViewRetrievalV1Observation(observation);
  return admissionJoins(o.source.artistId, o.object, o.coverage, admission);
}
export interface CurrentViewRetrievalV1WriterEvidence {
  readonly receipt: CurrentViewRetrievalV1ArchiveReceipt;
  readonly identifier: Hex;
  readonly family: CurrentViewRetrievalV1Family;
  readonly status: bigint;
  readonly revision: bigint;
}
/** The writer is derived from the second original institutional receipt, never caller-selected. */
export function validateCurrentViewRetrievalV1WriterEvidence(
  configuration: CurrentViewRetrievalV1Configuration,
  coverage: CurrentViewRetrievalV1Coverage,
  value: CurrentViewRetrievalV1WriterEvidence,
): Readonly<{ writer: Address; observedAt: bigint; originalAdmissionVerified: false }> {
  exact(value, ["receipt", "identifier", "family", "status", "revision"]);
  const c = normalize<CurrentViewRetrievalV1Coverage>(CURRENT_VIEW_RETRIEVAL_V1_COVERAGE_TUPLE, coverage);
  const r = normalize<CurrentViewRetrievalV1ArchiveReceipt>(CURRENT_VIEW_RETRIEVAL_V1_ARCHIVE_RECEIPT_TUPLE, value.receipt);
  const family = normalize<CurrentViewRetrievalV1Family>(CURRENT_VIEW_RETRIEVAL_V1_FAMILY_TUPLE, value.family);
  if (r.objectHash !== c.objectHash || r.familyRecordHash !== c.secondFamilyRecordHash
    || r.writer !== family.storingAgent || family.economics !== 2n || uint(value.status, 8) !== 1n
    || uint(value.revision, 64) === 0n || r.observedAt === 0n
    || r.evidenceClass !== id("ATTESTED_POSSESSION")
    || r.proofProfileHash !== id("STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1")) throw Error("Original institutional writer evidence differs");
  address(r.writer, true);
  same(keccak256(bytes(value.identifier, undefined, 65536)), r.storageIdentifierHash, "Institutional identifier");
  same(currentViewRetrievalV1ArchiveReceiptHash(configuration, r), c.secondReceiptHash, "Institutional receipt hash");
  return Object.freeze({ writer: r.writer, observedAt: r.observedAt, originalAdmissionVerified: false });
}
export interface CurrentViewRetrievalV1TransactionEvidence {
  readonly receipt: CurrentViewRetrievalV1ArchiveReceipt;
  readonly locator: Hex;
}
export function validateCurrentViewRetrievalV1TransactionEvidence(
  configuration: CurrentViewRetrievalV1Configuration,
  coverage: CurrentViewRetrievalV1Coverage,
  transactionId: Hex,
  value: CurrentViewRetrievalV1TransactionEvidence,
): CurrentViewRetrievalV1TransactionEvidence {
  exact(value, ["receipt", "locator"]);
  const c = normalize<CurrentViewRetrievalV1Coverage>(CURRENT_VIEW_RETRIEVAL_V1_COVERAGE_TUPLE, coverage);
  const r = normalize<CurrentViewRetrievalV1ArchiveReceipt>(CURRENT_VIEW_RETRIEVAL_V1_ARCHIVE_RECEIPT_TUPLE, value.receipt);
  const locator = bytes(value.locator, 32);
  same(locator, nonzero(transactionId), "Original Arweave transaction locator");
  if (r.objectHash !== c.objectHash || r.familyRecordHash !== c.firstFamilyRecordHash
    || r.proofRecordHash !== c.checkpointHash || r.storageIdentifierHash !== keccak256(locator)
    || currentViewRetrievalV1ArchiveReceiptHash(configuration, r) !== c.firstReceiptHash) throw Error("Original endowed transaction receipt differs");
  return Object.freeze({ receipt: r, locator });
}
export interface CurrentViewRetrievalV1ManifestEvidence {
  readonly stepIndex: bigint;
  readonly object: CurrentViewRetrievalV1Object;
  readonly admission: CurrentViewRetrievalV1Admission;
  readonly transaction: CurrentViewRetrievalV1TransactionEvidence;
}
/** Checks complete supplied manifest bytes/locators; original Archive admission remains a separate authority. */
export function validateCurrentViewRetrievalV1RouteEvidence(
  configuration: CurrentViewRetrievalV1Configuration,
  observation: CurrentViewRetrievalV1Observation,
  manifests: readonly CurrentViewRetrievalV1ManifestEvidence[],
  finalTransaction: CurrentViewRetrievalV1TransactionEvidence | null,
): Readonly<{ manifests: readonly CurrentViewRetrievalV1ManifestEvidence[]; finalTransaction: CurrentViewRetrievalV1TransactionEvidence | null; originalAdmissionVerified: false }> {
  const o = validateCurrentViewRetrievalV1Observation(observation);
  const rows = list(manifests);
  const indices = o.steps.flatMap((step, index) => step.kind === 3n ? [index] : []);
  if (rows.length !== indices.length) throw Error("Incomplete manifest route evidence");
  const normalized = rows.map((input, index) => {
    exact(input, ["stepIndex", "object", "admission", "transaction"]);
    const stepIndex = uint(input.stepIndex);
    same(stepIndex, BigInt(indices[index]!), "Ordered manifest step");
    const step = o.steps[indices[index]!]!;
    const object = normalize<CurrentViewRetrievalV1Object>(CURRENT_VIEW_RETRIEVAL_V1_OBJECT_TUPLE, input.object);
    const a = normalize<CurrentViewRetrievalV1Admission>(CURRENT_VIEW_RETRIEVAL_V1_ADMISSION_TUPLE, input.admission);
    admissionJoins(o.source.artistId, object, a.externalOriginal, a);
    if (a.proof.coverageHash !== step.manifestCoverage || a.proof.objectHash !== step.manifestObject
      || object.byteSize !== BigInt((step.manifestBytes.length - 2) / 2)
      || object.contentHash !== keccak256(step.manifestBytes) || object.sha256Digest !== sha256(step.manifestBytes)) throw Error("Full manifest bytes differ");
    const transaction = validateCurrentViewRetrievalV1TransactionEvidence(configuration, a.externalOriginal,
      currentViewRetrievalV1URI(step.fromURI).transactionId, input.transaction as unknown as CurrentViewRetrievalV1TransactionEvidence);
    return Object.freeze({ stepIndex, object, admission: a, transaction });
  });
  const resolved = currentViewRetrievalV1URI(o.resolvedURI);
  if ((resolved.kind === 2n) !== (finalTransaction !== null)) throw Error("Unexpected or missing final transaction evidence");
  const final = finalTransaction === null ? null
    : validateCurrentViewRetrievalV1TransactionEvidence(configuration, o.coverage, resolved.transactionId, finalTransaction);
  return Object.freeze({ manifests: Object.freeze(normalized), finalTransaction: final, originalAdmissionVerified: false });
}

export interface CurrentViewRetrievalV1SignatureRoute {
  readonly route: "direct-writer" | "own-key" | "erc1271";
  readonly writer: Address;
  readonly caller: Address;
  readonly digest: Hex;
  readonly signature: Hex;
  readonly designated: boolean;
  readonly requiresContractValidation: boolean;
  readonly runtimeVerified: false;
}
/** Supplied code classification only. Contract paths require the original bounded ERC-1271 staticcall. */
export function currentViewRetrievalV1SignatureRoute(
  caller: Address,
  writer: Address,
  digest: Hex,
  signature: Hex,
  writerCode: Hex,
): CurrentViewRetrievalV1SignatureRoute {
  const from = address(caller, true);
  const signer = address(writer, true);
  const h = bytes(digest, 32);
  const sig = bytes(signature, undefined, CURRENT_VIEW_RETRIEVAL_V1_MAX_SIGNATURE_BYTES);
  const code = bytes(writerCode);
  const designated = code.length === 48 && code.startsWith("0xef0100");
  let route: CurrentViewRetrievalV1SignatureRoute["route"] = "erc1271";
  if (from === signer && sig === "0x") route = "direct-writer";
  else if (code === "0x" || designated) {
    let matched = false;
    const length = (sig.length - 2) / 2;
    if (length === 64 || length === 65) {
      const r = (`0x${sig.slice(2, 66)}`) as Hex;
      const encodedS = BigInt(`0x${sig.slice(66, 130)}`);
      const s = length === 64 ? encodedS & ((1n << 255n) - 1n) : encodedS;
      const v = length === 64 ? Number(encodedS >> 255n) + 27 : Number.parseInt(sig.slice(130, 132), 16);
      if (s <= 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0n && (v === 27 || v === 28)) {
        try { matched = getAddress(recoverAddress(h, { r, s: `0x${s.toString(16).padStart(64, "0")}`, v })) === signer; }
        catch { matched = false; }
      }
    }
    if (matched) route = "own-key";
    else if (!designated) throw Error("Invalid original own-key signature");
  }
  return Object.freeze({ route, writer: signer, caller: from, digest: h, signature: sig, designated,
    requiresContractValidation: route === "erc1271", runtimeVerified: false });
}
/** Original exact 32-byte left-aligned magic return. This does not establish that a call occurred. */
export function validateCurrentViewRetrievalV1ERC1271Result(success: boolean, returnData: Hex): Hex {
  if (success !== true) throw Error("ERC-1271 call failed");
  const raw = bytes(returnData, 32);
  if (raw !== `0x1626ba7e${"00".repeat(28)}`) throw Error("Invalid original ERC-1271 return");
  return raw;
}
/** Exact original caller-only revoke predicate, based on supplied local record and epoch. */
export function validateCurrentViewRetrievalV1Revocation(
  caller: Address,
  receipt: CurrentViewRetrievalV1Receipt,
  reasonHash: Hex,
  revoked: boolean,
  epoch: bigint,
): Readonly<{ recordHash: Hex; writer: Address; reasonHash: Hex; nextEpoch: bigint; factsVerified: false }> {
  const r = normalize<CurrentViewRetrievalV1Receipt>(CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE, receipt);
  nonzero(r.recordHash);
  if (address(caller, true) !== r.writer || revoked !== false || uint(epoch, 64) === (1n << 64n) - 1n) throw Error("Original revoke is not admissible");
  return Object.freeze({ recordHash: r.recordHash, writer: r.writer, reasonHash: nonzero(reasonHash), nextEpoch: epoch + 1n, factsVerified: false });
}

export const CURRENT_VIEW_RETRIEVAL_V1_ABI = Object.freeze([
  "error ArchivalParentGas(uint256 available,uint256 required)",
  "error InvalidArchivalSignature(address signer)",
  "error InvalidViewRetrieval()",
  "error ViewRetrievalChanged(bytes32 record)",
  "error ViewRetrievalNonce(bytes32 key)",
  "error ViewRetrievalRevoked(bytes32 record)",
  "error ViewRetrievalUnknown(bytes32 record)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  `function configuration() view returns (${CURRENT_VIEW_RETRIEVAL_V1_CONFIGURATION_TUPLE})`,
  "function configurationHash() view returns (bytes32)",
  "function retrievalProfile() pure returns (bytes32)",
  `function prepare(${CURRENT_VIEW_RETRIEVAL_V1_REQUEST_TUPLE} r) view returns (${CURRENT_VIEW_RETRIEVAL_V1_OBSERVATION_TUPLE} o,bytes32 digest)`,
  `function publish(${CURRENT_VIEW_RETRIEVAL_V1_REQUEST_TUPLE} request,bytes signature) returns (bytes32 hash)`,
  `function record(bytes32 hash) view returns (${CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE} r)`,
  "function encoded(bytes32 hash) view returns (bytes)",
  `function requireCurrent(bytes32 hash) view returns (${CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE} r,${CURRENT_VIEW_RETRIEVAL_V1_ADMISSION_TUPLE} a)`,
  `function requireCorrespondence(bytes32 hash) view returns (${CURRENT_VIEW_RETRIEVAL_V1_SOURCE_TUPLE} source,${CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE} r,${CURRENT_VIEW_RETRIEVAL_V1_ADMISSION_TUPLE} a)`,
  "function revoke(bytes32 hash,bytes32 reasonHash)",
  "function revoked(bytes32) view returns (bool)",
  `function revocationEpoch(${CURRENT_VIEW_RETRIEVAL_V1_SCOPE_TUPLE} scope) view returns (uint64)`,
  "function nonceUsed(bytes32) view returns (bool)",
  `event ViewRetrievalRecorded(bytes32 indexed recordHash,bytes32 indexed sourceKey,address indexed writer,${CURRENT_VIEW_RETRIEVAL_V1_RECEIPT_TUPLE} receipt)`,
  "event ViewRetrievalRevoked(bytes32 indexed recordHash,address indexed writer,bytes32 reasonHash)",
]);
export function currentViewRetrievalV1Interface(): Interface {
  return new Interface(CURRENT_VIEW_RETRIEVAL_V1_ABI);
}
/** Own declared interface selectors; supportsInterface belongs only to the concrete host. */
export function currentViewRetrievalV1InterfaceId(): Hex {
  const iface = currentViewRetrievalV1Interface();
  let result = 0n;
  iface.forEachFunction(f => { if (f.name !== "supportsInterface") result ^= BigInt(f.selector); });
  return (`0x${result.toString(16).padStart(8, "0")}`) as Hex;
}
export type CurrentViewRetrievalV1CallRequest =
  | { readonly kind: "publish"; readonly request: CurrentViewRetrievalV1Request; readonly signature: Hex }
  | { readonly kind: "revoke"; readonly recordHash: Hex; readonly reasonHash: Hex };
export interface CurrentViewRetrievalV1Call {
  readonly coordinates: CurrentViewRetrievalV1Coordinates;
  readonly caller: Address;
  readonly request: CurrentViewRetrievalV1CallRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}
export function prepareCurrentViewRetrievalV1Call(
  coordinates: CurrentViewRetrievalV1Coordinates,
  caller: Address,
  input: CurrentViewRetrievalV1CallRequest,
): CurrentViewRetrievalV1Call {
  const c = normalizeCurrentViewRetrievalV1Coordinates(coordinates);
  let request: CurrentViewRetrievalV1CallRequest;
  let args: readonly unknown[];
  if (input.kind === "publish") {
    exact(input, ["kind", "request", "signature"]);
    request = Object.freeze({ kind: input.kind, request: validateCurrentViewRetrievalV1Request(input.request),
      signature: bytes(input.signature, undefined, CURRENT_VIEW_RETRIEVAL_V1_MAX_SIGNATURE_BYTES) });
    args = [request.request, request.signature];
  } else if (input.kind === "revoke") {
    exact(input, ["kind", "recordHash", "reasonHash"]);
    request = Object.freeze({ kind: input.kind, recordHash: nonzero(input.recordHash), reasonHash: nonzero(input.reasonHash) });
    args = [request.recordHash, request.reasonHash];
  } else throw Error("Unsupported retrieval mutation");
  return Object.freeze({ coordinates: c, caller: address(caller, true), request,
    call: Object.freeze({ to: c.witness, data: bytes(currentViewRetrievalV1Interface().encodeFunctionData(request.kind, args)), value: 0n }),
    factsVerified: false });
}
export function normalizeCurrentViewRetrievalV1Call(value: CurrentViewRetrievalV1Call): CurrentViewRetrievalV1Call {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"]);
  exact(value.call, ["to", "data", "value"]);
  const result = prepareCurrentViewRetrievalV1Call(value.coordinates, value.caller, value.request);
  if (address(value.call.to) !== result.call.to || bytes(value.call.data) !== result.call.data
    || uint(value.call.value) !== 0n || value.factsVerified !== false) throw Error("Retrieval call reconstruction differs");
  return result;
}
export type CurrentViewRetrievalV1ReadRequest =
  | { readonly kind: "configuration" | "configurationHash" | "retrievalProfile" }
  | { readonly kind: "supportsInterface"; readonly interfaceId: Hex }
  | { readonly kind: "prepare"; readonly request: CurrentViewRetrievalV1Request }
  | { readonly kind: "record" | "encoded" | "requireCurrent" | "requireCorrespondence" | "revoked"; readonly recordHash: Hex }
  | { readonly kind: "nonceUsed"; readonly nonceKey: Hex }
  | { readonly kind: "revocationEpoch"; readonly scope: CurrentViewRetrievalV1Scope };
export interface CurrentViewRetrievalV1Read {
  readonly coordinates: CurrentViewRetrievalV1Coordinates;
  readonly caller: Address;
  readonly request: CurrentViewRetrievalV1ReadRequest;
  readonly call: UnsignedCall;
}
export function prepareCurrentViewRetrievalV1Read(
  coordinates: CurrentViewRetrievalV1Coordinates,
  caller: Address,
  input: CurrentViewRetrievalV1ReadRequest,
): CurrentViewRetrievalV1Read {
  const c = normalizeCurrentViewRetrievalV1Coordinates(coordinates);
  let request: CurrentViewRetrievalV1ReadRequest;
  let args: readonly unknown[] = [];
  switch (input.kind) {
    case "configuration": case "configurationHash": case "retrievalProfile":
      exact(input, ["kind"]);
      request = Object.freeze({ kind: input.kind });
      break;
    case "supportsInterface":
      exact(input, ["kind", "interfaceId"]);
      request = Object.freeze({ kind: input.kind, interfaceId: bytes(input.interfaceId, 4) });
      args = [request.interfaceId];
      break;
    case "prepare":
      exact(input, ["kind", "request"]);
      request = Object.freeze({ kind: input.kind, request: validateCurrentViewRetrievalV1Request(input.request) });
      args = [request.request];
      break;
    case "record": case "encoded": case "requireCurrent": case "requireCorrespondence": case "revoked":
      exact(input, ["kind", "recordHash"]);
      request = Object.freeze({ kind: input.kind, recordHash: bytes(input.recordHash, 32) });
      args = [request.recordHash];
      break;
    case "nonceUsed":
      exact(input, ["kind", "nonceKey"]);
      request = Object.freeze({ kind: input.kind, nonceKey: bytes(input.nonceKey, 32) });
      args = [request.nonceKey];
      break;
    case "revocationEpoch":
      exact(input, ["kind", "scope"]);
      request = Object.freeze({ kind: input.kind, scope: validateCurrentViewRetrievalV1Scope(input.scope) });
      args = [request.scope];
      break;
    default: throw Error("Unsupported retrieval read");
  }
  return Object.freeze({ coordinates: c, caller: address(caller), request,
    call: Object.freeze({ to: c.witness, data: bytes(currentViewRetrievalV1Interface().encodeFunctionData(request.kind, args)), value: 0n }) });
}
export function normalizeCurrentViewRetrievalV1Read(value: CurrentViewRetrievalV1Read): CurrentViewRetrievalV1Read {
  exact(value, ["coordinates", "caller", "request", "call"]);
  exact(value.call, ["to", "data", "value"]);
  const result = prepareCurrentViewRetrievalV1Read(value.coordinates, value.caller, value.request);
  if (address(value.call.to) !== result.call.to || bytes(value.call.data) !== result.call.data || uint(value.call.value) !== 0n) throw Error("Retrieval read reconstruction differs");
  return result;
}
