import {
  AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id,
  isHexString, keccak256, sha256, toUtf8Bytes,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import {
  REFERENCE_ENVIRONMENT_ABI_TUPLE, prepareReferenceEnvironment,
  normalizeReferenceEnvironment, referenceEnvironmentCanonicalBytes,
  type ReferenceEnvironment,
} from "./current-reference-environment.js";
import {
  prepareReferenceInventory, referenceInventoryPartId,
  type ReferenceInventoryPackageFile,
} from "./current-reference-inventory.js";
import * as graph from "./current-scoped-policy-graph-v2.js";
import * as snapshot from "./current-token-preservation-snapshot-v2.js";
import * as output from "./current-token-preservation-output-v2.js";
import * as root from "./current-scoped-policy-root-v2.js";

/** Exact ABI146 token-preservation reference family. Supplied facts do not prove live admission. */
export const TOKEN_PRESERVATION_REFERENCE_V2_SOURCE = "9381dd999075693a4f63092d9924856a0dd72834";
export const TOKEN_PRESERVATION_REFERENCE_V2_FAMILY = output.TOKEN_PRESERVATION_OUTPUT_V2_FAMILY;
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_PROFILE = id("6529STREAM_PRESERVATION_POLICY_REFERENCE_V2") as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_PROFILE = id("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V2") as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_MAX_BYTES = 524288;
export const TOKEN_PRESERVATION_REFERENCE_V2_PART_ROWS = 64;
export const TOKEN_PRESERVATION_REFERENCE_V2_MAX_HTML_BYTES = 40960;
/** Client allocation bounds, distinct from each original retained-byte limit. */
export const TOKEN_PRESERVATION_REFERENCE_V2_MAX_CALL_BYTES = 2097152;
export const TOKEN_PRESERVATION_REFERENCE_V2_MAX_ARRAY_ROWS = 8192;

export type TokenPreservationReferenceV2ScopeKind = output.TokenPreservationOutputV2ScopeKind;
export type TokenPreservationReferenceV2Scope = output.TokenPreservationOutputV2Scope;
export type TokenPreservationReferenceV2Environment = ReferenceEnvironment;
export type TokenPreservationReferenceV2PackageFile = ReferenceInventoryPackageFile;
export type TokenPreservationReferenceV2Lock = snapshot.TokenPreservationSnapshotV2Lock;

export interface TokenPreservationReferenceV2Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly metadata: Address;
  readonly reference: Address;
  readonly scopeKind: TokenPreservationReferenceV2ScopeKind;
}

export interface TokenPreservationReferenceV2Dependencies {
  readonly targets: readonly [Address, Address, Address, Address, Address, Address, Address];
  readonly codeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex, Hex];
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly snapshotGas: bigint;
  readonly archiveGas: bigint;
}

export interface TokenPreservationReferenceV2Capture {
  readonly tokenId: bigint;
  readonly collectionSerial: bigint;
  readonly metadataJSONHash: Hex;
  readonly htmlHash: Hex;
  readonly htmlBytes: bigint;
  readonly animationHTML: Hex;
  readonly objectHash: Hex;
  readonly coverageHash: Hex;
  readonly sourceSha256: Hex;
  readonly repeatCaptureSha256: readonly [Hex, Hex];
  readonly environmentManifestHash: Hex;
  readonly capturedAt: bigint;
}

export interface TokenPreservationReferenceV2ObservationPublication {
  readonly collectionId: bigint;
  readonly referenceId: Hex;
  readonly expectedHead: Hex;
  readonly expectedRevision: bigint;
  readonly snapshotRecordHash: Hex;
  readonly snapshotRevision: bigint;
  readonly expectedSourcesHash: Hex;
  readonly captures: readonly TokenPreservationReferenceV2Capture[];
  readonly environment: TokenPreservationReferenceV2Environment;
  readonly manifestURI: string;
  readonly effectiveAt: bigint;
  readonly reasonHash: Hex;
}

export interface TokenPreservationReferenceV2Publication {
  readonly scope: TokenPreservationReferenceV2Scope;
  readonly observation: TokenPreservationReferenceV2ObservationPublication;
}

export interface TokenPreservationReferenceV2ObservationReceipt {
  readonly recordHash: Hex;
  readonly recordChainHash: Hex;
  readonly collectionId: bigint;
  readonly referenceId: Hex;
  readonly predecessor: Hex;
  readonly revision: bigint;
  readonly payloadHash: Hex;
  readonly payloadBytes: bigint;
  readonly sourcesHash: Hex;
  readonly snapshotRecordHash: Hex;
  readonly snapshotRevision: bigint;
  readonly recorder: Address;
  readonly authorizationClass: bigint;
  readonly grantRevision: bigint;
  readonly effectiveAt: bigint;
  readonly recordedAt: bigint;
  readonly reasonHash: Hex;
  readonly schemaHash: Hex;
  readonly profileHash: Hex;
  readonly canonicalizationHash: Hex;
}

export interface TokenPreservationReferenceV2Receipt {
  readonly scopeSubject: Hex;
  readonly observation: TokenPreservationReferenceV2ObservationReceipt;
}

export interface TokenPreservationReferenceV2Coverage {
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

export interface TokenPreservationReferenceV2SampleFacts {
  readonly tokenId: bigint;
  readonly collectionSerial: bigint;
  readonly originalCoordinator: Address;
  readonly seed: Hex;
  readonly tokenDataHash: Hex;
  readonly tokenDataBytes: bigint;
  readonly metadataJSONHash: Hex;
  readonly htmlHash: Hex;
  readonly htmlBytes: bigint;
  readonly captureCoverage: TokenPreservationReferenceV2Coverage;
}

export interface TokenPreservationReferenceV2Sample {
  readonly membershipIndex: bigint;
  readonly observation: TokenPreservationReferenceV2SampleFacts;
  readonly selection: output.TokenPreservationOutputV2TokenSelection;
  readonly entropy: output.TokenPreservationOutputV2TokenReadiness;
  readonly terminalAdmissionHash: Hex;
  readonly preservation: output.TokenPreservationOutputV2Binding;
  readonly preservationAdmission: output.TokenPreservationOutputV2Admission;
}

export type TokenPreservationReferenceV2CollectionRootRecord = snapshot.TokenPreservationSnapshotV2RootRecord;
export type TokenPreservationReferenceV2CollectionRootBinding = snapshot.TokenPreservationSnapshotV2RootBinding;
export type TokenPreservationReferenceV2ScopedRootRecord = root.ScopedPolicyRootV2Record;
export interface TokenPreservationReferenceV2ScopedRootBinding extends root.ScopedPolicyRootV2Binding {
  readonly metadataRouter: Address;
  readonly preservationOutputProfile: Hex;
}
interface SourceBase {
  readonly scopeSubject: Hex;
  readonly snapshot: snapshot.TokenPreservationSnapshotV2Receipt;
  readonly contentRootRecordHash: Hex;
  readonly environmentCoverage: TokenPreservationReferenceV2Coverage;
  readonly samples: readonly TokenPreservationReferenceV2Sample[];
}
export interface TokenPreservationReferenceV2CollectionSource extends SourceBase {
  readonly snapshotSource: snapshot.TokenPreservationSnapshotV2CollectionSource;
  readonly contentRoot: TokenPreservationReferenceV2CollectionRootRecord;
  readonly contentRootBinding: TokenPreservationReferenceV2CollectionRootBinding;
}
export interface TokenPreservationReferenceV2ScopedSource extends SourceBase {
  readonly snapshotSource: snapshot.TokenPreservationSnapshotV2ScopedSource;
  readonly contentRoot: TokenPreservationReferenceV2ScopedRootRecord;
  readonly contentRootBinding: TokenPreservationReferenceV2ScopedRootBinding;
}
export type TokenPreservationReferenceV2Source = TokenPreservationReferenceV2CollectionSource | TokenPreservationReferenceV2ScopedSource;
export type TokenPreservationReferenceV2SourceFacts = TokenPreservationReferenceV2Source;

export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPE_TUPLE = graph.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE;
export const TOKEN_PRESERVATION_REFERENCE_V2_ENVIRONMENT_TUPLE = REFERENCE_ENVIRONMENT_ABI_TUPLE;
export const TOKEN_PRESERVATION_REFERENCE_V2_PACKAGE_FILE_TUPLE = "tuple(string path,uint64 byteSize,bytes32 sha256Digest)";
export const TOKEN_PRESERVATION_REFERENCE_V2_DEPENDENCIES_TUPLE = "tuple(address[7] targets,bytes32[7] codeHashes,uint256 chainId,uint256 readGas,uint256 sourceGas,uint256 snapshotGas,uint256 archiveGas)";
export const TOKEN_PRESERVATION_REFERENCE_V2_CAPTURE_TUPLE = "tuple(uint256 tokenId,uint256 collectionSerial,bytes32 metadataJSONHash,bytes32 htmlHash,uint32 htmlBytes,bytes animationHTML,bytes32 objectHash,bytes32 coverageHash,bytes32 sourceSha256,bytes32[2] repeatCaptureSha256,bytes32 environmentManifestHash,uint64 capturedAt)";
export const TOKEN_PRESERVATION_REFERENCE_V2_OBSERVATION_PUBLICATION_TUPLE = `tuple(uint256 collectionId,bytes32 referenceId,bytes32 expectedHead,uint64 expectedRevision,bytes32 snapshotRecordHash,uint64 snapshotRevision,bytes32 expectedSourcesHash,${TOKEN_PRESERVATION_REFERENCE_V2_CAPTURE_TUPLE}[] captures,${TOKEN_PRESERVATION_REFERENCE_V2_ENVIRONMENT_TUPLE} environment,string manifestURI,uint64 effectiveAt,bytes32 reasonHash)`;
export const TOKEN_PRESERVATION_REFERENCE_V2_PUBLICATION_TUPLE = `tuple(${TOKEN_PRESERVATION_REFERENCE_V2_SCOPE_TUPLE} scope,${TOKEN_PRESERVATION_REFERENCE_V2_OBSERVATION_PUBLICATION_TUPLE} observation)`;
export const TOKEN_PRESERVATION_REFERENCE_V2_OBSERVATION_RECEIPT_TUPLE = "tuple(bytes32 recordHash,bytes32 recordChainHash,uint256 collectionId,bytes32 referenceId,bytes32 predecessor,uint64 revision,bytes32 payloadHash,uint32 payloadBytes,bytes32 sourcesHash,bytes32 snapshotRecordHash,uint64 snapshotRevision,address recorder,uint8 authorizationClass,uint64 grantRevision,uint64 effectiveAt,uint64 recordedAt,bytes32 reasonHash,bytes32 schemaHash,bytes32 profileHash,bytes32 canonicalizationHash)";
export const TOKEN_PRESERVATION_REFERENCE_V2_RECEIPT_TUPLE = `tuple(bytes32 scopeSubject,${TOKEN_PRESERVATION_REFERENCE_V2_OBSERVATION_RECEIPT_TUPLE} observation)`;
export const TOKEN_PRESERVATION_REFERENCE_V2_COVERAGE_TUPLE = "tuple(bytes32 coverageHash,bytes32 objectHash,bytes32 artistId,bytes32 contentHash,bytes32 sha256Digest,bytes32 arweaveDataRoot,uint64 byteSize,bytes32 firstFamilyRecordHash,bytes32 secondFamilyRecordHash,bytes32 firstReceiptHash,bytes32 secondReceiptHash,bytes32 firstFixityHash,bytes32 secondFixityHash,bytes32 checkpointHash,bytes32 profileHash)";
export const TOKEN_PRESERVATION_REFERENCE_V2_SAMPLE_FACTS_TUPLE = `tuple(uint256 tokenId,uint256 collectionSerial,address originalCoordinator,bytes32 seed,bytes32 tokenDataHash,uint32 tokenDataBytes,bytes32 metadataJSONHash,bytes32 htmlHash,uint32 htmlBytes,${TOKEN_PRESERVATION_REFERENCE_V2_COVERAGE_TUPLE} captureCoverage)`;
export const TOKEN_PRESERVATION_REFERENCE_V2_SAMPLE_TUPLE = `tuple(uint64 membershipIndex,${TOKEN_PRESERVATION_REFERENCE_V2_SAMPLE_FACTS_TUPLE} observation,${output.TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_SELECTION_TUPLE} selection,${output.TOKEN_PRESERVATION_OUTPUT_V2_TOKEN_READINESS_TUPLE} entropy,bytes32 terminalAdmissionHash,${output.TOKEN_PRESERVATION_OUTPUT_V2_BINDING_TUPLE} preservation,${output.TOKEN_PRESERVATION_OUTPUT_V2_ADMISSION_TUPLE} preservationAdmission)`;
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ROOT_RECORD_TUPLE = snapshot.TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_RECORD_TUPLE;
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ROOT_BINDING_TUPLE = snapshot.TOKEN_PRESERVATION_SNAPSHOT_V2_ROOT_BINDING_TUPLE;
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_RECORD_TUPLE = root.SCOPED_POLICY_ROOT_V2_RECORD_TUPLE;
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_BINDING_TUPLE = root.SCOPED_POLICY_ROOT_V2_BINDING_TUPLE.slice(0, -1) + ",address metadataRouter,bytes32 preservationOutputProfile)";
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_SOURCE_TUPLE = `tuple(bytes32 scopeSubject,${snapshot.TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE} snapshot,${snapshot.TOKEN_PRESERVATION_SNAPSHOT_V2_COLLECTION_SOURCE_TUPLE} snapshotSource,bytes32 contentRootRecordHash,${TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ROOT_RECORD_TUPLE} contentRoot,${TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ROOT_BINDING_TUPLE} contentRootBinding,${TOKEN_PRESERVATION_REFERENCE_V2_COVERAGE_TUPLE} environmentCoverage,${TOKEN_PRESERVATION_REFERENCE_V2_SAMPLE_TUPLE}[] samples)`;
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_SOURCE_TUPLE = `tuple(bytes32 scopeSubject,${snapshot.TOKEN_PRESERVATION_SNAPSHOT_V2_RECEIPT_TUPLE} snapshot,${snapshot.TOKEN_PRESERVATION_SNAPSHOT_V2_SCOPED_SOURCE_TUPLE} snapshotSource,bytes32 contentRootRecordHash,${TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_RECORD_TUPLE} contentRoot,${TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_BINDING_TUPLE} contentRootBinding,${TOKEN_PRESERVATION_REFERENCE_V2_COVERAGE_TUPLE} environmentCoverage,${TOKEN_PRESERVATION_REFERENCE_V2_SAMPLE_TUPLE}[] samples)`;
export const TOKEN_PRESERVATION_REFERENCE_V2_LOCK_TUPLE = snapshot.TOKEN_PRESERVATION_SNAPSHOT_V2_LOCK_TUPLE;

function kind(value: TokenPreservationReferenceV2ScopeKind): TokenPreservationReferenceV2ScopeKind {
  if (value !== "collection" && value !== "scoped") throw Error("Unknown reference host kind");
  return value;
}
function sourceTuple(value: TokenPreservationReferenceV2ScopeKind): string {
  return kind(value) === "collection" ? TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_SOURCE_TUPLE : TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_SOURCE_TUPLE;
}
function payloadTypes(value: TokenPreservationReferenceV2ScopeKind): readonly string[] {
  return ["bytes32", "uint256", "address", TOKEN_PRESERVATION_REFERENCE_V2_PUBLICATION_TUPLE,
    TOKEN_PRESERVATION_REFERENCE_V2_RECEIPT_TUPLE, sourceTuple(value), "bytes"];
}
function domain(value: TokenPreservationReferenceV2ScopeKind, suffix: string): Hex {
  return id(`6529STREAM_${kind(value) === "scoped" ? "SCOPED_" : ""}PRESERVATION_POLICY_REFERENCE_${suffix}_V2`) as Hex;
}
export function tokenPreservationReferenceV2Profile(value: TokenPreservationReferenceV2ScopeKind): Hex {
  return kind(value) === "collection" ? TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_PROFILE : TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_PROFILE;
}

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

function bytes(value: unknown, fixed?: number, maximum = TOKEN_PRESERVATION_REFERENCE_V2_MAX_CALL_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, fixed ?? true)
    || (value.length - 2) / 2 > maximum) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}

function nonzero(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === ZERO) throw Error("Expected nonzero commitment");
  return result;
}

function text(value: unknown, maximum = TOKEN_PRESERVATION_REFERENCE_V2_MAX_BYTES): string {
  if (typeof value !== "string"
    || /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(value)
    || toUtf8Bytes(value).length > maximum) throw Error("Invalid UTF8 text or byte bound");
  return value;
}

function list(value: unknown, maximum: number, fixed?: number): readonly unknown[] {
  if (!Array.isArray(value) || value.length > maximum || (fixed !== undefined && value.length !== fixed)
    || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.hasOwn(value, i))) throw Error("Expected dense bounded array");
  return value;
}

function valueOf(type: ParamType, value: unknown, decoded = false): unknown {
  if (type.baseType === "tuple") {
    if (!decoded) exact(value, type.components!.map(field => field.name), "Tuple");
    return Object.freeze(Object.fromEntries(type.components!.map((field, i) => [field.name,
      valueOf(field, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[field.name], decoded)])));
  }
  if (type.baseType === "array") {
    const rows = list(decoded ? Array.from(value as readonly unknown[]) : value, TOKEN_PRESERVATION_REFERENCE_V2_MAX_ARRAY_ROWS,
      type.arrayLength! < 0 ? undefined : type.arrayLength!);
    return Object.freeze(rows.map(item => valueOf(type.arrayChildren!, item, decoded)));
  }
  if (type.type.startsWith("uint")) {
    const result = uint(value, Number(type.type.slice(4)));
    if (type.name === "scopeType" && result > 4n) throw Error("Unknown original scope enum");
    return result;
  }
  if (type.type === "address") return address(value);
  if (type.type.startsWith("bytes")) return bytes(value, type.type === "bytes" ? undefined : Number(type.type.slice(5)));
  if (type.type === "string") return text(value);
  if (type.type === "bool" && typeof value === "boolean") return value;
  throw Error(`Invalid ABI value ${type.type}`);
}

function normalized<T>(tuple: string, value: unknown): T {
  return valueOf(ParamType.from(tuple), value) as T;
}

function encode(tuple: string, value: unknown, maximum = TOKEN_PRESERVATION_REFERENCE_V2_MAX_BYTES): Hex {
  return bytes(coder.encode([tuple], [normalized(tuple, value)]), undefined, maximum);
}

function decode<T>(tuple: string, value: Hex, maximum = TOKEN_PRESERVATION_REFERENCE_V2_MAX_BYTES): T {
  const raw = bytes(value, undefined, maximum);
  const result = valueOf(ParamType.from(tuple), coder.decode([tuple], raw)[0], true) as T;
  if (encode(tuple, result, maximum) !== raw) throw Error("Noncanonical ABI encoding");
  return result;
}

function hash(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}

function same(tuple: string, left: unknown, right: unknown): boolean {
  return encode(tuple, left) === encode(tuple, right);
}

export function normalizeTokenPreservationReferenceV2Coordinates(value: TokenPreservationReferenceV2Coordinates): TokenPreservationReferenceV2Coordinates {
  exact(value, ["chainId", "core", "metadata", "reference", "scopeKind"], "Coordinates");
  return Object.freeze({ chainId: uint(value.chainId), core: address(value.core, true),
    metadata: address(value.metadata, true), reference: address(value.reference, true), scopeKind: kind(value.scopeKind) });
}

/** Structural codecs preserve empty historical getter values; admission checks are separate. */
export function normalizeTokenPreservationReferenceV2Dependencies(value: TokenPreservationReferenceV2Dependencies): TokenPreservationReferenceV2Dependencies {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_DEPENDENCIES_TUPLE, value);
}
export function encodeTokenPreservationReferenceV2Dependencies(value: TokenPreservationReferenceV2Dependencies): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_DEPENDENCIES_TUPLE, value);
}
export function decodeTokenPreservationReferenceV2Dependencies(value: Hex): TokenPreservationReferenceV2Dependencies {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_DEPENDENCIES_TUPLE, value);
}
export function normalizeTokenPreservationReferenceV2Publication(value: TokenPreservationReferenceV2Publication): TokenPreservationReferenceV2Publication {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_PUBLICATION_TUPLE, value);
}
export function encodeTokenPreservationReferenceV2Publication(value: TokenPreservationReferenceV2Publication): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_PUBLICATION_TUPLE, value);
}
export function decodeTokenPreservationReferenceV2Publication(value: Hex): TokenPreservationReferenceV2Publication {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_PUBLICATION_TUPLE, value);
}
export function normalizeTokenPreservationReferenceV2Receipt(value: TokenPreservationReferenceV2Receipt): TokenPreservationReferenceV2Receipt {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_RECEIPT_TUPLE, value);
}
export function encodeTokenPreservationReferenceV2Receipt(value: TokenPreservationReferenceV2Receipt): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_RECEIPT_TUPLE, value);
}
export function decodeTokenPreservationReferenceV2Receipt(value: Hex): TokenPreservationReferenceV2Receipt {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_RECEIPT_TUPLE, value);
}
export function normalizeTokenPreservationReferenceV2Source(
  scopeKind: TokenPreservationReferenceV2ScopeKind, value: TokenPreservationReferenceV2Source,
): TokenPreservationReferenceV2Source { return normalized(sourceTuple(scopeKind), value); }
export function encodeTokenPreservationReferenceV2Source(
  scopeKind: TokenPreservationReferenceV2ScopeKind, value: TokenPreservationReferenceV2Source,
): Hex { return encode(sourceTuple(scopeKind), value); }
export function decodeTokenPreservationReferenceV2Source(
  scopeKind: TokenPreservationReferenceV2ScopeKind, value: Hex,
): TokenPreservationReferenceV2Source { return decode(sourceTuple(scopeKind), value); }
export function normalizeTokenPreservationReferenceV2Capture(value: TokenPreservationReferenceV2Capture): TokenPreservationReferenceV2Capture {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_CAPTURE_TUPLE, value);
}
export function normalizeTokenPreservationReferenceV2Coverage(value: TokenPreservationReferenceV2Coverage): TokenPreservationReferenceV2Coverage {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_COVERAGE_TUPLE, value);
}
export function normalizeTokenPreservationReferenceV2Sample(value: TokenPreservationReferenceV2Sample): TokenPreservationReferenceV2Sample {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_SAMPLE_TUPLE, value);
}
export function normalizeTokenPreservationReferenceV2Lock(value: TokenPreservationReferenceV2Lock): TokenPreservationReferenceV2Lock {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_LOCK_TUPLE, value);
}

export function validateTokenPreservationReferenceV2Dependencies(
  coordinates: TokenPreservationReferenceV2Coordinates,
  value: TokenPreservationReferenceV2Dependencies,
): TokenPreservationReferenceV2Dependencies {
  const c = normalizeTokenPreservationReferenceV2Coordinates(coordinates);
  const d = normalizeTokenPreservationReferenceV2Dependencies(value);
  if (d.chainId !== c.chainId || d.targets[0] !== c.core || d.targets[1] !== c.metadata
    || d.readGas < 50000n || d.sourceGas < d.readGas || d.snapshotGas < d.sourceGas || d.archiveGas < d.readGas) throw Error("Invalid original reference dependencies");
  for (let i = 0; i < 7; i++) { address(d.targets[i], true); nonzero(d.codeHashes[i]); }
  return d;
}

/** `preview` admits the original zero expectedSourcesHash draft, while `publish` requires its commitment. */
export function validateTokenPreservationReferenceV2Publication(
  scopeKind: TokenPreservationReferenceV2ScopeKind,
  value: TokenPreservationReferenceV2Publication,
  mode: "preview" | "publish",
): TokenPreservationReferenceV2Publication {
  if (mode !== "preview" && mode !== "publish") throw Error("Unknown publication mode");
  const p = normalizeTokenPreservationReferenceV2Publication(value);
  const scope = output.validateTokenPreservationOutputV2Scope(scopeKind, p.scope);
  const o = p.observation;
  if (o.collectionId !== scope.collectionId || o.effectiveAt === 0n || o.snapshotRevision === 0n
    || o.expectedRevision === (1n << 64n) - 1n || o.captures.length < 1 || o.captures.length > 2
    || (o.expectedHead === ZERO) !== (o.expectedRevision === 0n)) throw Error("Invalid reference candidate or head/revision lineage");
  nonzero(o.referenceId); nonzero(o.reasonHash); nonzero(o.snapshotRecordHash);
  if (mode === "publish") nonzero(o.expectedSourcesHash);
  const uri = text(o.manifestURI, 2048);
  if (uri !== "") {
    const valid = uri.startsWith("https://") ? uri.length > 8 && !"/?#".includes(uri[8]!)
      : uri.startsWith("ipfs://") ? uri.length > 7 : uri.startsWith("ar://") && uri.length > 5;
    if (!valid || /[\u0000-\u0020\u007f]/u.test(uri)) throw Error("Invalid original content URI");
  }
  // Both file inventories and the whole Environment are validated by the unchanged original codec.
  const environment = normalizeReferenceEnvironment(o.environment);
  const environmentBytes = referenceEnvironmentCanonicalBytes(environment);
  if (keccak256(environmentBytes) !== environment.manifestHash
    || BigInt((environmentBytes.length - 2) / 2) !== environment.manifestBytes) throw Error("Environment manifest differs from canonical JSON");
  for (const capture of o.captures) {
    const html = bytes(capture.animationHTML, undefined, TOKEN_PRESERVATION_REFERENCE_V2_MAX_HTML_BYTES);
    if (html === "0x" || capture.htmlBytes !== BigInt((html.length - 2) / 2)
      || keccak256(html) !== capture.htmlHash || sha256(html) !== capture.sourceSha256
      || capture.capturedAt === 0n || capture.tokenId === 0n || capture.collectionSerial === 0n
      || capture.environmentManifestHash !== environment.manifestHash
      || capture.repeatCaptureSha256[0] !== capture.repeatCaptureSha256[1]) throw Error("Invalid original capture");
    nonzero(capture.repeatCaptureSha256[0]); nonzero(capture.objectHash); nonzero(capture.coverageHash);
  }
  // The original complete ABI Publication is retained independently from the canonical payload.
  encodeTokenPreservationReferenceV2Publication(p);
  return p;
}

export const tokenPreservationReferenceV2ScopeSubject = snapshot.tokenPreservationSnapshotV2ScopeSubject;
export const validateTokenPreservationReferenceV2Scope = output.validateTokenPreservationOutputV2Scope;

export interface TokenPreservationReferenceV2CandidateState {
  readonly timestamp: bigint;
  readonly head: Hex;
  readonly count: bigint;
  readonly referenceIdUsed: boolean;
  readonly lock: TokenPreservationReferenceV2Lock;
}

/** Supplied candidate facts only. An original call must establish their authoritative source. */
export function validateTokenPreservationReferenceV2Candidate(
  scopeKind: TokenPreservationReferenceV2ScopeKind,
  publication: TokenPreservationReferenceV2Publication,
  state: TokenPreservationReferenceV2CandidateState,
  mode: "preview" | "publish" = "publish",
): TokenPreservationReferenceV2Publication {
  const p = validateTokenPreservationReferenceV2Publication(scopeKind, publication, mode);
  exact(state, ["timestamp", "head", "count", "referenceIdUsed", "lock"], "Candidate state");
  const lock = normalizeTokenPreservationReferenceV2Lock(state.lock);
  if (typeof state.referenceIdUsed !== "boolean" || state.referenceIdUsed
    || p.observation.effectiveAt > uint(state.timestamp, 64)
    || p.observation.expectedHead !== bytes(state.head, 32)
    || p.observation.expectedRevision !== uint(state.count)
    || lock.actionId !== ZERO
    || p.observation.captures.some(row => row.capturedAt > state.timestamp)) throw Error("Candidate is not currently publishable");
  return p;
}

/** Original scoped preservation companion projection; it is not a proof of source admission. */
export function tokenPreservationReferenceV2ScopedRootBindingFromSnapshot(
  dependencies: snapshot.TokenPreservationSnapshotV2Dependencies,
  source: snapshot.TokenPreservationSnapshotV2ScopedSource,
  receipt: snapshot.TokenPreservationSnapshotV2Receipt,
): TokenPreservationReferenceV2ScopedRootBinding {
  const d = snapshot.normalizeTokenPreservationSnapshotV2Dependencies(dependencies);
  const f = snapshot.normalizeTokenPreservationSnapshotV2ScopedSource(source);
  const r = snapshot.normalizeTokenPreservationSnapshotV2Receipt(receipt);
  return normalizeTokenPreservationReferenceV2ScopedRootBinding({
    profileId: id("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V2") as Hex,
    outputManifest: d.targets[8], outputManifestCodeHash: d.codeHashes[8],
    checkpoint: d.targets[7], checkpointCodeHash: d.codeHashes[7],
    checkpointHash: f.outputs.checkpointHash, checkpointStateHash: f.outputs.checkpointStateHash,
    entropySourceSet: d.targets[10], entropySourceSetCodeHash: d.codeHashes[10],
    inventoryHash: f.outputs.inventoryHash, policyChainHash: f.outputs.policyChainHash, outputRoot: f.outputs.outputRoot,
    outputSchemaHash: output.TOKEN_PRESERVATION_OUTPUT_V2_SCHEMA_HASH,
    outputCanonicalizationHash: output.TOKEN_PRESERVATION_OUTPUT_V2_CANONICALIZATION_HASH,
    leafSchemaHash: output.TOKEN_PRESERVATION_OUTPUT_V2_LEAF_SCHEMA_HASH,
    rootSchemaHash: TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_SCHEMA_HASH,
    rootCanonicalizationHash: TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_CANONICALIZATION_HASH,
    sourceFactory: f.sourceFactory, sourceFactoryCodeHash: f.sourceFactoryCodeHash,
    factoryDependenciesHash: f.factoryDependenciesHash,
    snapshotSchemaHash: r.schemaHash, snapshotProfileHash: r.profileHash,
    snapshotCanonicalizationHash: r.canonicalizationHash,
    metadataRouter: f.outputs.metadataRouter, preservationOutputProfile: f.outputs.preservationProfile,
  });
}

export function tokenPreservationReferenceV2ScopedRootStateHash(
  chainId: bigint, router: Address, core: Address,
  record: TokenPreservationReferenceV2ScopedRootRecord,
  binding: TokenPreservationReferenceV2ScopedRootBinding,
): Hex {
  const r = normalizeTokenPreservationReferenceV2ScopedRootRecord(record);
  return hash(["bytes32", "uint256", "address", "address", TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_RECORD_TUPLE,
    TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_BINDING_TUPLE],
  [id("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V2"), uint(chainId), address(router), address(core),
    { ...r, stateHash: ZERO, artistConsent: ZERO, publishedAt: 0n }, normalizeTokenPreservationReferenceV2ScopedRootBinding(binding)]);
}

function immutableSourceJoins(
  c: TokenPreservationReferenceV2Coordinates,
  p: TokenPreservationReferenceV2Publication,
  f: TokenPreservationReferenceV2Source,
  d: TokenPreservationReferenceV2Dependencies,
): void {
  const subject = tokenPreservationReferenceV2ScopeSubject(c.chainId, c.core, p.scope);
  const s = f.snapshotSource;
  const definitions = snapshot.tokenPreservationSnapshotV2Definitions(c.scopeKind);
  if (s.content.preservationProfile !== TOKEN_PRESERVATION_REFERENCE_V2_FAMILY
    || s.outputs.preservationProfile !== TOKEN_PRESERVATION_REFERENCE_V2_FAMILY
    || f.snapshot.schemaHash !== definitions[0]!.hash || f.snapshot.profileHash !== definitions[1]!.hash
    || f.snapshot.canonicalizationHash !== definitions[2]!.hash
    || f.contentRootBinding.profileId !== id(c.scopeKind === "collection"
      ? "6529STREAM_PRESERVATION_POLICY_CONTENT_V2" : "6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V2")
    || f.contentRootBinding.preservationOutputProfile !== TOKEN_PRESERVATION_REFERENCE_V2_FAMILY) {
    throw Error("Retained source is not the closed V2 token preservation family");
  }
  f.samples.forEach(sample => output.validateTokenPreservationOutputV2Admission(
    sample.preservation, sample.preservationAdmission, sample.selection));
  if (f.scopeSubject !== subject || f.snapshot.scopeSubject !== subject || s.membership.scopeSubject !== subject
    || [s.scope, s.outputs.scope, s.content.scope, s.selection.scope].some(scope => !same(TOKEN_PRESERVATION_REFERENCE_V2_SCOPE_TUPLE, scope, p.scope))
    || f.snapshot.recordHash !== p.observation.snapshotRecordHash || f.snapshot.revision !== p.observation.snapshotRevision) {
    throw Error("Retained reference source full scope or snapshot differs from publication");
  }
  if (c.scopeKind === "collection") {
    const source = f as TokenPreservationReferenceV2CollectionSource;
    if (source.contentRoot.publication.collectionId !== p.scope.collectionId
      || !same(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ROOT_RECORD_TUPLE, source.contentRoot, source.snapshotSource.root)
      || !same(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ROOT_BINDING_TUPLE, source.contentRootBinding, source.snapshotSource.rootBinding)
      || source.contentRootRecordHash !== snapshot.tokenPreservationSnapshotV2RootRecordHash(c.chainId, d.targets[4], source.contentRoot, source.contentRootBinding)) {
      throw Error("Retained collection root differs from snapshot root");
    }
  } else {
    const source = f as TokenPreservationReferenceV2ScopedSource;
    const r = source.contentRoot;
    if (!same(TOKEN_PRESERVATION_REFERENCE_V2_SCOPE_TUPLE, r.publication.scope, p.scope)
      || r.publication.snapshotRecordHash !== f.snapshot.recordHash || r.publication.snapshotRevision !== f.snapshot.revision
      || r.snapshotManifestHash !== f.snapshot.manifestHash || r.snapshotSourceHash !== f.snapshot.sourceHash
      || r.snapshotHost !== d.targets[5] || r.snapshotCodeHash !== d.codeHashes[5]
      || r.stateHash !== tokenPreservationReferenceV2ScopedRootStateHash(c.chainId, d.targets[4], c.core, r, source.contentRootBinding)) {
      throw Error("Retained scoped root differs from snapshot identity");
    }
  }
}

/** Checks only immutable joins in supplied facts. Original calls own render, Registry, grant and archive admission. */
export function validateTokenPreservationReferenceV2Source(
  coordinates: TokenPreservationReferenceV2Coordinates,
  dependencies: TokenPreservationReferenceV2Dependencies,
  publication: TokenPreservationReferenceV2Publication,
  source: TokenPreservationReferenceV2Source,
  snapshotDependencies: snapshot.TokenPreservationSnapshotV2Dependencies,
): TokenPreservationReferenceV2Source {
  const c = normalizeTokenPreservationReferenceV2Coordinates(coordinates);
  const d = validateTokenPreservationReferenceV2Dependencies(c, dependencies);
  const p = validateTokenPreservationReferenceV2Publication(c.scopeKind, publication, "preview");
  const f = normalizeTokenPreservationReferenceV2Source(c.scopeKind, source);
  const sd = snapshot.normalizeTokenPreservationSnapshotV2Dependencies(snapshotDependencies);
  immutableSourceJoins(c, p, f, d);
  if (sd.chainId !== c.chainId || d.targets.slice(0, 5).some((target, i) => target !== sd.targets[i]
    || d.codeHashes[i] !== sd.codeHashes[i])) throw Error("Snapshot dependency identity differs");
  const expectedSource = snapshot.tokenPreservationSnapshotV2SourceHash({ chainId: c.chainId, core: c.core,
    metadata: c.metadata, snapshot: d.targets[5], scopeKind: c.scopeKind }, sd, f.snapshotSource);
  if (f.snapshot.sourceHash !== expectedSource) throw Error("Original snapshot source commitment differs");
  const s = f.snapshotSource;
  const count = s.membership.tokenCount;
  if (!count || count >= 1n << 64n || (p.scope.scopeType === 1n && count !== 1n)
    || f.samples.length !== (count === 1n ? 1 : 2) || f.samples.length !== p.observation.captures.length) {
    throw Error("Source sample count differs from complete membership");
  }
  nonzero(f.contentRootRecordHash);
  if (c.scopeKind === "collection") {
    const fc = f as TokenPreservationReferenceV2CollectionSource;
    if (snapshot.tokenPreservationSnapshotV2RootRecordHash(c.chainId, d.targets[4], fc.contentRoot, fc.contentRootBinding)
      !== f.contentRootRecordHash) throw Error("Collection root record commitment differs");
  } else {
    const fs = f as TokenPreservationReferenceV2ScopedSource;
    const r = fs.contentRoot;
    const expectedBinding = tokenPreservationReferenceV2ScopedRootBindingFromSnapshot(sd, fs.snapshotSource, f.snapshot);
    if (!same(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_BINDING_TUPLE, fs.contentRootBinding, expectedBinding)
      || r.snapshotHost !== d.targets[5] || r.snapshotCodeHash !== d.codeHashes[5]
      || r.contentRoot !== s.outputs.contentRoot || r.leafCount !== count
      || r.outputManifestHash !== s.outputs.manifestHash || r.artistId !== s.artist.artistId
      || r.bindingGeneration !== s.artist.bindingGeneration || r.bindingHash !== s.artist.bindingHash
      || ![7n, 8n].includes(r.authorizationClass) || !r.grantRevision || !r.publishedAt
      || r.stateHash !== tokenPreservationReferenceV2ScopedRootStateHash(c.chainId, d.targets[4], c.core, r, fs.contentRootBinding)) {
      throw Error("Original scoped content root or full preservation binding differs");
    }
    address(r.publisher, true);
    [r.contentRoot, r.routeHash, r.stateHash, r.artistConsent].forEach(nonzero);
  }
  const environment = p.observation.environment;
  if (f.environmentCoverage.coverageHash !== environment.coverageHash || f.environmentCoverage.objectHash !== environment.objectHash
    || f.environmentCoverage.artistId !== s.artist.artistId) throw Error("Environment coverage identity differs");
  for (let i = 0; i < f.samples.length; i++) {
    const sample = f.samples[i]!;
    const capture = p.observation.captures[i]!;
    const facts = sample.observation;
    const entropy = sample.entropy;
    if (sample.membershipIndex !== (i === 0 ? 0n : count - 1n)
      || facts.tokenId !== capture.tokenId || facts.collectionSerial !== capture.collectionSerial
      || (p.scope.scopeType === 1n && facts.tokenId !== p.scope.tokenId)
      || sample.selection.tokenId !== capture.tokenId || sample.selection.sources[0] !== c.core
      || sample.selection.sources[1] !== d.targets[4] || facts.originalCoordinator !== sample.selection.sources[3]
      || entropy.coordinator !== facts.originalCoordinator || entropy.coordinatorCodeHash !== sample.selection.sourceCodeHashes[3]
      || facts.seed !== entropy.seed || facts.tokenDataBytes > 16384n
      || facts.metadataJSONHash !== capture.metadataJSONHash || facts.htmlHash !== capture.htmlHash
      || facts.htmlBytes !== capture.htmlBytes || facts.captureCoverage.coverageHash !== capture.coverageHash
      || facts.captureCoverage.objectHash !== capture.objectHash || facts.captureCoverage.artistId !== s.artist.artistId
      || facts.captureCoverage.sha256Digest !== capture.repeatCaptureSha256[0]) throw Error("Sample order, content or coverage differs");
    output.validateTokenPreservationOutputV2Admission(sample.preservation, sample.preservationAdmission, sample.selection);
    address(facts.originalCoordinator, true);
    nonzero(sample.selection.sourceCodeHashes[3]);
    if (entropy.terminal) {
      if (entropy.finalized || entropy.seed !== ZERO || entropy.renderRequirement !== 1n
        || !((entropy.status === 1n && entropy.mode === 0n) || (entropy.status === 2n && entropy.mode === 2n))
        || sample.terminalAdmissionHash === ZERO) throw Error("Invalid original terminal reference sample");
    } else if (!entropy.finalized || entropy.status !== 5n || sample.terminalAdmissionHash !== ZERO) {
      throw Error("Invalid original finalized reference sample");
    }
  }
  return f;
}

export interface TokenPreservationReferenceV2Authority {
  readonly authorizationClass: 3n | 8n;
  readonly grantRevision: bigint;
}

export function tokenPreservationReferenceV2PreviewReceipt(
  coordinates: TokenPreservationReferenceV2Coordinates,
  publication: TokenPreservationReferenceV2Publication,
  recorder: Address,
  authority: TokenPreservationReferenceV2Authority,
  sourceHash: Hex,
): TokenPreservationReferenceV2Receipt {
  const c = normalizeTokenPreservationReferenceV2Coordinates(coordinates);
  const p = validateTokenPreservationReferenceV2Publication(c.scopeKind, publication, "preview");
  exact(authority, ["authorizationClass", "grantRevision"], "Authority");
  if ((authority.authorizationClass !== 3n && authority.authorizationClass !== 8n)
    || uint(authority.grantRevision, 64) === 0n) throw Error("Expected original CURATOR class 3 or 8 grant");
  const o = p.observation;
  return normalizeTokenPreservationReferenceV2Receipt({
    scopeSubject: snapshot.tokenPreservationSnapshotV2ScopeSubject(c.chainId, c.core, p.scope),
    observation: {
      recordHash: ZERO, recordChainHash: ZERO, collectionId: o.collectionId, referenceId: o.referenceId,
      predecessor: o.expectedHead, revision: o.expectedRevision + 1n, payloadHash: ZERO, payloadBytes: 0n,
      sourcesHash: bytes(sourceHash, 32), snapshotRecordHash: o.snapshotRecordHash, snapshotRevision: o.snapshotRevision,
      recorder: address(recorder, true), authorizationClass: authority.authorizationClass, grantRevision: authority.grantRevision,
      effectiveAt: o.effectiveAt, recordedAt: 0n, reasonHash: o.reasonHash,
      schemaHash: tokenPreservationReferenceV2Definitions(c.scopeKind)[0]!.hash,
      profileHash: tokenPreservationReferenceV2Definitions(c.scopeKind)[1]!.hash,
      canonicalizationHash: tokenPreservationReferenceV2Definitions(c.scopeKind)[2]!.hash,
    },
  });
}

/** Structural preimage. Gas caps are deliberately not part of the original source hash. */
export function tokenPreservationReferenceV2SourceHash(
  coordinates: TokenPreservationReferenceV2Coordinates,
  dependencies: TokenPreservationReferenceV2Dependencies,
  source: TokenPreservationReferenceV2SourceFacts,
): Hex {
  const c = normalizeTokenPreservationReferenceV2Coordinates(coordinates);
  const d = normalizeTokenPreservationReferenceV2Dependencies(dependencies);
  if (d.chainId !== c.chainId) throw Error("Source chain differs");
  return hash(["bytes32", "uint256", "address", "address[7]", "bytes32[7]", sourceTuple(c.scopeKind)],
    [domain(c.scopeKind, "SOURCES"), c.chainId, c.reference, d.targets, d.codeHashes,
      normalizeTokenPreservationReferenceV2Source(c.scopeKind, source)]);
}

function canonicalPublication(p: TokenPreservationReferenceV2Publication): TokenPreservationReferenceV2Publication {
  return normalizeTokenPreservationReferenceV2Publication({ ...p, observation: { ...p.observation, expectedSourcesHash: ZERO } });
}

function canonicalReceipt(r: TokenPreservationReferenceV2Receipt): TokenPreservationReferenceV2Receipt {
  return normalizeTokenPreservationReferenceV2Receipt({ ...r, observation: { ...r.observation,
    recordHash: ZERO, recordChainHash: ZERO, payloadHash: ZERO, payloadBytes: 0n, recordedAt: 0n } });
}

/** Exact seven-field retained payload, clearing only the original one + five derived fields. */
export function tokenPreservationReferenceV2PayloadBytes(
  coordinates: TokenPreservationReferenceV2Coordinates,
  publication: TokenPreservationReferenceV2Publication,
  receipt: TokenPreservationReferenceV2Receipt,
  source: TokenPreservationReferenceV2SourceFacts,
  environmentBytes: Hex,
): Hex {
  const c = normalizeTokenPreservationReferenceV2Coordinates(coordinates);
  return bytes(coder.encode(payloadTypes(c.scopeKind), [domain(c.scopeKind, "PAYLOAD"),
    c.chainId, c.reference, canonicalPublication(normalizeTokenPreservationReferenceV2Publication(publication)),
    canonicalReceipt(normalizeTokenPreservationReferenceV2Receipt(receipt)), normalizeTokenPreservationReferenceV2Source(c.scopeKind, source),
    bytes(environmentBytes, undefined, TOKEN_PRESERVATION_REFERENCE_V2_MAX_BYTES)]), undefined, TOKEN_PRESERVATION_REFERENCE_V2_MAX_BYTES);
}

/** Original payload using the supplied seven-host roster. Both retained streams are independently bounded. */
export function tokenPreservationReferenceV2ReferenceBytes(
  coordinates: TokenPreservationReferenceV2Coordinates,
  dependencies: TokenPreservationReferenceV2Dependencies,
  publication: TokenPreservationReferenceV2Publication,
  receipt: TokenPreservationReferenceV2Receipt,
  source: TokenPreservationReferenceV2Source,
  environmentBytes: Hex,
): Hex {
  const c = normalizeTokenPreservationReferenceV2Coordinates(coordinates);
  const d = normalizeTokenPreservationReferenceV2Dependencies(dependencies);
  if (d.chainId !== c.chainId || d.targets[0] !== c.core || d.targets[1] !== c.metadata) throw Error("Reference dependency coordinates differ");
  const r = normalizeTokenPreservationReferenceV2Receipt(receipt);
  if (r.observation.sourcesHash !== tokenPreservationReferenceV2SourceHash(c, d, source)) throw Error("Receipt source hash differs");
  encodeTokenPreservationReferenceV2Publication(publication);
  return tokenPreservationReferenceV2PayloadBytes(c, publication, r, source, environmentBytes);
}

export interface TokenPreservationReferenceV2Payload {
  readonly chainId: bigint;
  readonly reference: Address;
  readonly publication: TokenPreservationReferenceV2Publication;
  readonly receipt: TokenPreservationReferenceV2Receipt;
  readonly source: TokenPreservationReferenceV2SourceFacts;
  readonly environmentBytes: Hex;
}

/** Decodes the original tag and canonical ABI form; field admission and currentness are separate. */
export function decodeTokenPreservationReferenceV2Payload(scopeKind: TokenPreservationReferenceV2ScopeKind, raw: Hex): TokenPreservationReferenceV2Payload {
  const input = bytes(raw, undefined, TOKEN_PRESERVATION_REFERENCE_V2_MAX_BYTES);
  const values = coder.decode(payloadTypes(scopeKind), input);
  if (values[0] !== domain(scopeKind, "PAYLOAD")
    || coder.encode(payloadTypes(scopeKind), values) !== input) throw Error("Invalid scoped reference payload tag or canonical bytes");
  return Object.freeze({ chainId: uint(values[1]), reference: address(values[2]),
    publication: valueOf(ParamType.from(TOKEN_PRESERVATION_REFERENCE_V2_PUBLICATION_TUPLE), values[3], true) as TokenPreservationReferenceV2Publication,
    receipt: valueOf(ParamType.from(TOKEN_PRESERVATION_REFERENCE_V2_RECEIPT_TUPLE), values[4], true) as TokenPreservationReferenceV2Receipt,
    source: valueOf(ParamType.from(sourceTuple(scopeKind)), values[5], true) as TokenPreservationReferenceV2SourceFacts,
    environmentBytes: bytes(values[6], undefined, TOKEN_PRESERVATION_REFERENCE_V2_MAX_BYTES) });
}
export const decodeTokenPreservationReferenceV2ReferenceBytes = decodeTokenPreservationReferenceV2Payload;

export function tokenPreservationReferenceV2RecordHash(
  coordinates: TokenPreservationReferenceV2Coordinates,
  publication: TokenPreservationReferenceV2Publication,
  minedReceipt: TokenPreservationReferenceV2Receipt,
): Hex {
  const c = normalizeTokenPreservationReferenceV2Coordinates(coordinates);
  const r = normalizeTokenPreservationReferenceV2Receipt(minedReceipt);
  return hash(["bytes32", "uint256", "address", "address", "address", TOKEN_PRESERVATION_REFERENCE_V2_PUBLICATION_TUPLE,
    TOKEN_PRESERVATION_REFERENCE_V2_RECEIPT_TUPLE], [domain(c.scopeKind, "RECORD"),
    c.chainId, c.reference, c.core, c.metadata, normalizeTokenPreservationReferenceV2Publication(publication),
    { ...r, observation: { ...r.observation, recordHash: ZERO, recordChainHash: ZERO } }]);
}

export function tokenPreservationReferenceV2ChainHash(
  coordinates: TokenPreservationReferenceV2Coordinates,
  scope: TokenPreservationReferenceV2Scope,
  previousChainHash: Hex,
  revision: bigint,
  recordHash: Hex,
): Hex {
  const c = normalizeTokenPreservationReferenceV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "uint64", "bytes32"],
    [domain(c.scopeKind, "CHAIN"), c.chainId, c.reference, c.core,
      snapshot.tokenPreservationSnapshotV2ScopeSubject(c.chainId, c.core, scope), bytes(previousChainHash, 32), uint(revision, 64), bytes(recordHash, 32)]);
}

/** Authenticates retained bytes and supplied history linkage; does not establish a live head or upstream availability. */
export function authenticateTokenPreservationReferenceV2History(
  coordinates: TokenPreservationReferenceV2Coordinates,
  dependencies: TokenPreservationReferenceV2Dependencies,
  publication: TokenPreservationReferenceV2Publication,
  receipt: TokenPreservationReferenceV2Receipt,
  canonical: Hex,
  previousChainHash: Hex,
): TokenPreservationReferenceV2Payload {
  const c = normalizeTokenPreservationReferenceV2Coordinates(coordinates);
  const p = validateTokenPreservationReferenceV2Publication(c.scopeKind, publication, "publish");
  const r = normalizeTokenPreservationReferenceV2Receipt(receipt);
  const o = r.observation;
  const payload = decodeTokenPreservationReferenceV2Payload(c.scopeKind, canonical);
  const f = payload.source;
  const d = normalizeTokenPreservationReferenceV2Dependencies(dependencies);
  if (d.chainId !== c.chainId || d.targets[0] !== c.core || d.targets[1] !== c.metadata) throw Error("Retained dependency coordinates differ");
  immutableSourceJoins(c, p, f, d);
  const sourceHash = tokenPreservationReferenceV2SourceHash(c, dependencies, payload.source);
  const expected = tokenPreservationReferenceV2PreviewReceipt(c, p, o.recorder,
    { authorizationClass: o.authorizationClass as 3n | 8n, grantRevision: o.grantRevision }, sourceHash);
  if (payload.chainId !== c.chainId || payload.reference !== c.reference
    || !same(TOKEN_PRESERVATION_REFERENCE_V2_RECEIPT_TUPLE, canonicalReceipt(r), expected)
    || p.observation.expectedSourcesHash !== sourceHash || o.recordedAt === 0n || o.effectiveAt > o.recordedAt
    || p.observation.captures.some(capture => capture.capturedAt > o.recordedAt)
    || o.payloadHash !== keccak256(canonical) || o.payloadBytes !== BigInt((canonical.length - 2) / 2)
    || payload.environmentBytes !== referenceEnvironmentCanonicalBytes(p.observation.environment)
    || canonical !== tokenPreservationReferenceV2PayloadBytes(c, p, r, payload.source, payload.environmentBytes)
    || (p.observation.expectedHead === ZERO && bytes(previousChainHash, 32) !== ZERO)
    || tokenPreservationReferenceV2RecordHash(c, p, r) !== nonzero(o.recordHash)
    || tokenPreservationReferenceV2ChainHash(c, p.scope, previousChainHash, o.revision, o.recordHash) !== o.recordChainHash) {
    throw Error("Retained scoped reference history differs from original commitments");
  }
  return payload;
}

/** Original fixed Store chunks; presence and STOP-prefixed runtime must be checked separately. */
export const tokenPreservationReferenceV2Chunks = snapshot.tokenPreservationSnapshotV2Chunks;

export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ABI = Object.freeze([
  "function deploymentChainId() view returns (uint256)",
  "event PolicyReferencePublished(uint16 schemaVersion, bytes32 indexed scopeSubject, bytes32 indexed referenceId, bytes32 indexed recordHash, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) receipt, string manifestURI)",
  "event ReferenceEnvironmentPrepared(uint16 schemaVersion, bytes32 indexed environmentId, bytes32 contentHash, uint32 byteLength)",
  "event ReferenceInventoryAssembled(uint16 schemaVersion, bytes32 indexed inventoryId, bool relative, uint256 rowCount, bytes32 contentHash, uint32 byteLength)",
  "event ReferenceInventoryPartPrepared(uint16 schemaVersion, bytes32 indexed partId, bool relative, uint16 rowCount, bytes32 contentHash, uint32 byteLength)",
  "function archiveCoverage() view returns (address)",
  "function core() view returns (address)",
  "function currentReference((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation))",
  "function dependencies() view returns ((address[7] targets, bytes32[7] codeHashes, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 snapshotGas, uint256 archiveGas) d)",
  "function metadataHost() view returns (address)",
  "function metadataRouter() view returns (address)",
  "function prepareEnvironment((bytes32 objectHash, bytes32 coverageHash, bytes32 manifestHash, uint32 manifestBytes, string engineName, string engineVersion, bytes32 engineExecutableSha256, string toolchainName, string toolchainVersion, bytes32 toolchainSha256, string engineExecutablePath, string toolchainPath, (string path, uint64 byteSize, bytes32 sha256Digest)[] packageFiles, (string path, uint64 byteSize, bytes32 sha256Digest)[] platformPrerequisites, string operatingSystem, string operatingSystemVersion, string architecture, uint16 viewportWidth, uint16 viewportHeight, uint8 devicePixelRatio, string colorSpace, bool softwareRasterization, bytes32 captureProfile, string licenseNote)) returns (bytes32)",
  "function prepareFileInventory((string path, uint64 byteSize, bytes32 sha256Digest)[] rows, bool relative) returns (bytes32)",
  "function prepareFileInventoryFromParts((string path, uint64 byteSize, bytes32 sha256Digest)[], bool) returns (bytes32)",
  "function prepareFileInventoryPart((string path, uint64 byteSize, bytes32 sha256Digest)[], bool) returns (bytes32)",
  "function preparedFileInventory(bytes32 id) view returns (bytes)",
  "function preservationPolicyReferenceProfile() pure returns (bytes32)",
  "function previewReference(((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 referenceId, bytes32 expectedHead, uint64 expectedRevision, bytes32 snapshotRecordHash, uint64 snapshotRevision, bytes32 expectedSourcesHash, (uint256 tokenId, uint256 collectionSerial, bytes32 metadataJSONHash, bytes32 htmlHash, uint32 htmlBytes, bytes animationHTML, bytes32 objectHash, bytes32 coverageHash, bytes32 sourceSha256, bytes32[2] repeatCaptureSha256, bytes32 environmentManifestHash, uint64 capturedAt)[] captures, (bytes32 objectHash, bytes32 coverageHash, bytes32 manifestHash, uint32 manifestBytes, string engineName, string engineVersion, bytes32 engineExecutableSha256, string toolchainName, string toolchainVersion, bytes32 toolchainSha256, string engineExecutablePath, string toolchainPath, (string path, uint64 byteSize, bytes32 sha256Digest)[] packageFiles, (string path, uint64 byteSize, bytes32 sha256Digest)[] platformPrerequisites, string operatingSystem, string operatingSystemVersion, string architecture, uint16 viewportWidth, uint16 viewportHeight, uint8 devicePixelRatio, string colorSpace, bool softwareRasterization, bytes32 captureProfile, string licenseNote) environment, string manifestURI, uint64 effectiveAt, bytes32 reasonHash) observation) p, address recorder) view returns (bytes32 sourceHash, bytes canonical)",
  "function publishReference(((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 referenceId, bytes32 expectedHead, uint64 expectedRevision, bytes32 snapshotRecordHash, uint64 snapshotRevision, bytes32 expectedSourcesHash, (uint256 tokenId, uint256 collectionSerial, bytes32 metadataJSONHash, bytes32 htmlHash, uint32 htmlBytes, bytes animationHTML, bytes32 objectHash, bytes32 coverageHash, bytes32 sourceSha256, bytes32[2] repeatCaptureSha256, bytes32 environmentManifestHash, uint64 capturedAt)[] captures, (bytes32 objectHash, bytes32 coverageHash, bytes32 manifestHash, uint32 manifestBytes, string engineName, string engineVersion, bytes32 engineExecutableSha256, string toolchainName, string toolchainVersion, bytes32 toolchainSha256, string engineExecutablePath, string toolchainPath, (string path, uint64 byteSize, bytes32 sha256Digest)[] packageFiles, (string path, uint64 byteSize, bytes32 sha256Digest)[] platformPrerequisites, string operatingSystem, string operatingSystemVersion, string architecture, uint16 viewportWidth, uint16 viewportHeight, uint8 devicePixelRatio, string colorSpace, bool softwareRasterization, bytes32 captureProfile, string licenseNote) environment, string manifestURI, uint64 effectiveAt, bytes32 reasonHash) observation) p) returns (bytes32 hash)",
  "function referenceAt((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint256 index) view returns (bytes32)",
  "function referenceChunkAt(bytes32 hash, uint256 index) view returns (address pointer, bytes32 chunkHash, uint32 byteSize)",
  "function referenceChunkCount(bytes32 hash) view returns (uint256)",
  "function referenceCount((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (uint256)",
  "function referenceLock((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bytes32 recordHash, uint64 revision, bytes32 actionId, uint64 lockedAt))",
  "function referencePayload(bytes32 hash) view returns (bytes)",
  "function referenceRecord(bytes32 hash) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 referenceId, bytes32 expectedHead, uint64 expectedRevision, bytes32 snapshotRecordHash, uint64 snapshotRevision, bytes32 expectedSourcesHash, (uint256 tokenId, uint256 collectionSerial, bytes32 metadataJSONHash, bytes32 htmlHash, uint32 htmlBytes, bytes animationHTML, bytes32 objectHash, bytes32 coverageHash, bytes32 sourceSha256, bytes32[2] repeatCaptureSha256, bytes32 environmentManifestHash, uint64 capturedAt)[] captures, (bytes32 objectHash, bytes32 coverageHash, bytes32 manifestHash, uint32 manifestBytes, string engineName, string engineVersion, bytes32 engineExecutableSha256, string toolchainName, string toolchainVersion, bytes32 toolchainSha256, string engineExecutablePath, string toolchainPath, (string path, uint64 byteSize, bytes32 sha256Digest)[] packageFiles, (string path, uint64 byteSize, bytes32 sha256Digest)[] platformPrerequisites, string operatingSystem, string operatingSystemVersion, string architecture, uint16 viewportWidth, uint16 viewportHeight, uint8 devicePixelRatio, string colorSpace, bool softwareRasterization, bytes32 captureProfile, string licenseNote) environment, string manifestURI, uint64 effectiveAt, bytes32 reasonHash) observation), (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation))",
  "function referenceSource(bytes32 hash) view returns ((bytes32 scopeSubject, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot, bytes32 preservationProfile) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, address metadataRouter, bytes32 preservationProfile, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, ((uint256 collectionId, bytes32 expectedPredecessor, bytes32 verifiedManifestRecordHash, string manifestURI) publication, bytes32 contentRoot, uint64 leafCount, bytes32 manifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt) root, (bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address metadataRouter, bytes32 preservationOutputProfile) rootBinding, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, bytes32 contentRootRecordHash, ((uint256 collectionId, bytes32 expectedPredecessor, bytes32 verifiedManifestRecordHash, string manifestURI) publication, bytes32 contentRoot, uint64 leafCount, bytes32 manifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt) contentRoot, (bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address metadataRouter, bytes32 preservationOutputProfile) contentRootBinding, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) environmentCoverage, (uint64 membershipIndex, (uint256 tokenId, uint256 collectionSerial, address originalCoordinator, bytes32 seed, bytes32 tokenDataHash, uint32 tokenDataBytes, bytes32 metadataJSONHash, bytes32 htmlHash, uint32 htmlBytes, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) captureCoverage) observation, (uint256 tokenId, bytes32 configRecordHash, bytes32 configHash, bytes32 sourceSnapshotHash, bytes32 rawSourceHash, (address registry, bytes32 registryCodeHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 schemaHash, bytes32 readSetHash, bytes32 registrationHash) selection, address[6] sources, bytes32[6] sourceCodeHashes) selection, (address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) entropy, bytes32 terminalAdmissionHash, (address producer, bytes32 producerCodeHash, bytes32 profile, address core, address metadataRouter, address liveRenderer, bytes32 liveRendererCodeHash, address attribution, bytes32 attributionCodeHash) preservation, (address registry, bytes32 registryCodeHash, bytes32 versionKey, bytes32 registrationHash, bytes32 readSetHash, bytes32 analysisHash, bytes32 goldenHash) preservationAdmission)[] samples))",
  "function requireCurrent((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 hash, uint64 revision) view returns ((bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) r)",
  "function snapshots() view returns (address)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
]);
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_INTERFACE_ID = "0xa004b728" as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ABI = Object.freeze([
  "function deploymentChainId() view returns (uint256)",
  "event ReferenceEnvironmentPrepared(uint16 schemaVersion, bytes32 indexed environmentId, bytes32 contentHash, uint32 byteLength)",
  "event ReferenceInventoryAssembled(uint16 schemaVersion, bytes32 indexed inventoryId, bool relative, uint256 rowCount, bytes32 contentHash, uint32 byteLength)",
  "event ReferenceInventoryPartPrepared(uint16 schemaVersion, bytes32 indexed partId, bool relative, uint16 rowCount, bytes32 contentHash, uint32 byteLength)",
  "event ScopedPolicyReferencePublished(uint16 schemaVersion, bytes32 indexed scopeSubject, bytes32 indexed referenceId, bytes32 indexed recordHash, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) receipt, string manifestURI)",
  "function archiveCoverage() view returns (address)",
  "function core() view returns (address)",
  "function currentReference((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation))",
  "function dependencies() view returns ((address[7] targets, bytes32[7] codeHashes, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 snapshotGas, uint256 archiveGas) d)",
  "function metadataHost() view returns (address)",
  "function metadataRouter() view returns (address)",
  "function prepareEnvironment((bytes32 objectHash, bytes32 coverageHash, bytes32 manifestHash, uint32 manifestBytes, string engineName, string engineVersion, bytes32 engineExecutableSha256, string toolchainName, string toolchainVersion, bytes32 toolchainSha256, string engineExecutablePath, string toolchainPath, (string path, uint64 byteSize, bytes32 sha256Digest)[] packageFiles, (string path, uint64 byteSize, bytes32 sha256Digest)[] platformPrerequisites, string operatingSystem, string operatingSystemVersion, string architecture, uint16 viewportWidth, uint16 viewportHeight, uint8 devicePixelRatio, string colorSpace, bool softwareRasterization, bytes32 captureProfile, string licenseNote)) returns (bytes32)",
  "function prepareFileInventory((string path, uint64 byteSize, bytes32 sha256Digest)[] rows, bool relative) returns (bytes32)",
  "function prepareFileInventoryFromParts((string path, uint64 byteSize, bytes32 sha256Digest)[], bool) returns (bytes32)",
  "function prepareFileInventoryPart((string path, uint64 byteSize, bytes32 sha256Digest)[], bool) returns (bytes32)",
  "function preparedFileInventory(bytes32 id) view returns (bytes)",
  "function previewReference(((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 referenceId, bytes32 expectedHead, uint64 expectedRevision, bytes32 snapshotRecordHash, uint64 snapshotRevision, bytes32 expectedSourcesHash, (uint256 tokenId, uint256 collectionSerial, bytes32 metadataJSONHash, bytes32 htmlHash, uint32 htmlBytes, bytes animationHTML, bytes32 objectHash, bytes32 coverageHash, bytes32 sourceSha256, bytes32[2] repeatCaptureSha256, bytes32 environmentManifestHash, uint64 capturedAt)[] captures, (bytes32 objectHash, bytes32 coverageHash, bytes32 manifestHash, uint32 manifestBytes, string engineName, string engineVersion, bytes32 engineExecutableSha256, string toolchainName, string toolchainVersion, bytes32 toolchainSha256, string engineExecutablePath, string toolchainPath, (string path, uint64 byteSize, bytes32 sha256Digest)[] packageFiles, (string path, uint64 byteSize, bytes32 sha256Digest)[] platformPrerequisites, string operatingSystem, string operatingSystemVersion, string architecture, uint16 viewportWidth, uint16 viewportHeight, uint8 devicePixelRatio, string colorSpace, bool softwareRasterization, bytes32 captureProfile, string licenseNote) environment, string manifestURI, uint64 effectiveAt, bytes32 reasonHash) observation) p, address recorder) view returns (bytes32 sourceHash, bytes canonical)",
  "function publishReference(((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 referenceId, bytes32 expectedHead, uint64 expectedRevision, bytes32 snapshotRecordHash, uint64 snapshotRevision, bytes32 expectedSourcesHash, (uint256 tokenId, uint256 collectionSerial, bytes32 metadataJSONHash, bytes32 htmlHash, uint32 htmlBytes, bytes animationHTML, bytes32 objectHash, bytes32 coverageHash, bytes32 sourceSha256, bytes32[2] repeatCaptureSha256, bytes32 environmentManifestHash, uint64 capturedAt)[] captures, (bytes32 objectHash, bytes32 coverageHash, bytes32 manifestHash, uint32 manifestBytes, string engineName, string engineVersion, bytes32 engineExecutableSha256, string toolchainName, string toolchainVersion, bytes32 toolchainSha256, string engineExecutablePath, string toolchainPath, (string path, uint64 byteSize, bytes32 sha256Digest)[] packageFiles, (string path, uint64 byteSize, bytes32 sha256Digest)[] platformPrerequisites, string operatingSystem, string operatingSystemVersion, string architecture, uint16 viewportWidth, uint16 viewportHeight, uint8 devicePixelRatio, string colorSpace, bool softwareRasterization, bytes32 captureProfile, string licenseNote) environment, string manifestURI, uint64 effectiveAt, bytes32 reasonHash) observation) p) returns (bytes32 hash)",
  "function referenceAt((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint256 index) view returns (bytes32)",
  "function referenceCount((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (uint256)",
  "function referenceLock((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns ((bytes32 recordHash, uint64 revision, bytes32 actionId, uint64 lockedAt))",
  "function referencePayload(bytes32 hash) view returns (bytes)",
  "function referenceRecord(bytes32 hash) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 referenceId, bytes32 expectedHead, uint64 expectedRevision, bytes32 snapshotRecordHash, uint64 snapshotRevision, bytes32 expectedSourcesHash, (uint256 tokenId, uint256 collectionSerial, bytes32 metadataJSONHash, bytes32 htmlHash, uint32 htmlBytes, bytes animationHTML, bytes32 objectHash, bytes32 coverageHash, bytes32 sourceSha256, bytes32[2] repeatCaptureSha256, bytes32 environmentManifestHash, uint64 capturedAt)[] captures, (bytes32 objectHash, bytes32 coverageHash, bytes32 manifestHash, uint32 manifestBytes, string engineName, string engineVersion, bytes32 engineExecutableSha256, string toolchainName, string toolchainVersion, bytes32 toolchainSha256, string engineExecutablePath, string toolchainPath, (string path, uint64 byteSize, bytes32 sha256Digest)[] packageFiles, (string path, uint64 byteSize, bytes32 sha256Digest)[] platformPrerequisites, string operatingSystem, string operatingSystemVersion, string architecture, uint16 viewportWidth, uint16 viewportHeight, uint8 devicePixelRatio, string colorSpace, bool softwareRasterization, bytes32 captureProfile, string licenseNote) environment, string manifestURI, uint64 effectiveAt, bytes32 reasonHash) observation), (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation))",
  "function referenceSource(bytes32 hash) view returns ((bytes32 scopeSubject, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot, bytes32 preservationProfile) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, address metadataRouter, bytes32 preservationProfile, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, bytes32 contentRootRecordHash, (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 expectedPredecessor, bytes32 snapshotRecordHash, uint64 snapshotRevision, string manifestURI) publication, address snapshotHost, bytes32 snapshotCodeHash, bytes32 snapshotManifestHash, bytes32 snapshotSourceHash, bytes32 contentRoot, uint64 leafCount, bytes32 outputManifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt) contentRoot, (bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, bytes32 snapshotSchemaHash, bytes32 snapshotProfileHash, bytes32 snapshotCanonicalizationHash, address metadataRouter, bytes32 preservationOutputProfile) contentRootBinding, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) environmentCoverage, (uint64 membershipIndex, (uint256 tokenId, uint256 collectionSerial, address originalCoordinator, bytes32 seed, bytes32 tokenDataHash, uint32 tokenDataBytes, bytes32 metadataJSONHash, bytes32 htmlHash, uint32 htmlBytes, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) captureCoverage) observation, (uint256 tokenId, bytes32 configRecordHash, bytes32 configHash, bytes32 sourceSnapshotHash, bytes32 rawSourceHash, (address registry, bytes32 registryCodeHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 schemaHash, bytes32 readSetHash, bytes32 registrationHash) selection, address[6] sources, bytes32[6] sourceCodeHashes) selection, (address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) entropy, bytes32 terminalAdmissionHash, (address producer, bytes32 producerCodeHash, bytes32 profile, address core, address metadataRouter, address liveRenderer, bytes32 liveRendererCodeHash, address attribution, bytes32 attributionCodeHash) preservation, (address registry, bytes32 registryCodeHash, bytes32 versionKey, bytes32 registrationHash, bytes32 readSetHash, bytes32 analysisHash, bytes32 goldenHash) preservationAdmission)[] samples))",
  "function requireCurrent((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 hash, uint64 revision) view returns ((bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) r)",
  "function scopedPreservationPolicyReferenceProfile() pure returns (bytes32)",
  "function snapshots() view returns (address)",
  "function supportsInterface(bytes4 id) pure returns (bool)",
]);
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_INTERFACE_ID = "0xa0d44c1f" as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_ENVIRONMENT_INTERFACE_ID = "0xe5dc1cfc" as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_INVENTORY_INTERFACE_ID = "0x08e1f36a" as Hex;
export function tokenPreservationReferenceV2Interface(scopeKind: TokenPreservationReferenceV2ScopeKind): Interface {
  return new Interface(kind(scopeKind) === "collection" ? TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ABI : TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ABI);
}


export type TokenPreservationReferenceV2Request =
  | { readonly kind: "prepareEnvironment"; readonly environment: TokenPreservationReferenceV2Environment }
  | {
    readonly kind: "prepareFileInventory" | "prepareFileInventoryPart" | "prepareFileInventoryFromParts";
    readonly rows: readonly TokenPreservationReferenceV2PackageFile[];
    readonly relative: boolean;
  }
  | { readonly kind: "publishReference"; readonly publication: TokenPreservationReferenceV2Publication };

export interface TokenPreservationReferenceV2Preparation {
  readonly id: Hex;
  readonly canonical: Hex;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
}

export interface TokenPreservationReferenceV2Call {
  readonly coordinates: TokenPreservationReferenceV2Coordinates;
  readonly caller: Address;
  readonly request: TokenPreservationReferenceV2Request;
  readonly call: UnsignedCall;
  readonly preparation: TokenPreservationReferenceV2Preparation | null;
  readonly factsVerified: false;
}

export function normalizeTokenPreservationReferenceV2Request(scopeKind: TokenPreservationReferenceV2ScopeKind, value: TokenPreservationReferenceV2Request): TokenPreservationReferenceV2Request {
  if (value?.kind === "prepareEnvironment") {
    exact(value, ["kind", "environment"], "Environment preparation");
    return Object.freeze({ kind: value.kind, environment: normalized<TokenPreservationReferenceV2Environment>(
      TOKEN_PRESERVATION_REFERENCE_V2_ENVIRONMENT_TUPLE, value.environment) });
  }
  if (value?.kind === "prepareFileInventory" || value?.kind === "prepareFileInventoryPart" || value?.kind === "prepareFileInventoryFromParts") {
    exact(value, ["kind", "rows", "relative"], "Inventory preparation");
    if (typeof value.relative !== "boolean") throw Error("Expected relative boolean");
    return Object.freeze({ kind: value.kind, relative: value.relative,
      rows: normalized<readonly TokenPreservationReferenceV2PackageFile[]>(`${TOKEN_PRESERVATION_REFERENCE_V2_PACKAGE_FILE_TUPLE}[]`, value.rows) });
  }
  if (value?.kind === "publishReference") {
    exact(value, ["kind", "publication"], "Reference publication");
    return Object.freeze({ kind: value.kind, publication: validateTokenPreservationReferenceV2Publication(scopeKind, value.publication, "publish") });
  }
  throw Error("Unknown scoped reference write kind");
}

/** Permissionless preparations confer no publication authority; all five original writes are nonpayable CALLs. */
export function prepareTokenPreservationReferenceV2Call(
  coordinates: TokenPreservationReferenceV2Coordinates,
  caller: Address,
  request: TokenPreservationReferenceV2Request,
): TokenPreservationReferenceV2Call {
  const c = normalizeTokenPreservationReferenceV2Coordinates(coordinates);
  const actor = address(caller, true);
  const q = normalizeTokenPreservationReferenceV2Request(c.scopeKind, request);
  let preparation: TokenPreservationReferenceV2Preparation | null = null;
  let arguments_: readonly unknown[];
  if (q.kind === "prepareEnvironment") {
    const prepared = prepareReferenceEnvironment(c.chainId, c.reference, q.environment);
    preparation = Object.freeze({ id: prepared.environmentId, canonical: prepared.canonical,
      contentHash: prepared.contentHash, byteLength: prepared.byteLength });
    arguments_ = [prepared.environment];
  } else if (q.kind === "publishReference") {
    arguments_ = [q.publication];
  } else {
    const prepared = prepareReferenceInventory(c.chainId, c.reference, q.relative, q.rows);
    const inventoryId = q.kind === "prepareFileInventoryPart"
      ? referenceInventoryPartId(c.chainId, c.reference, q.relative, q.rows) : prepared.inventoryId;
    preparation = Object.freeze({ id: inventoryId, canonical: prepared.canonical,
      contentHash: prepared.contentHash, byteLength: prepared.byteLength });
    arguments_ = [prepared.rows, q.relative];
  }
  const data = bytes(tokenPreservationReferenceV2Interface(c.scopeKind).encodeFunctionData(q.kind, arguments_), undefined, TOKEN_PRESERVATION_REFERENCE_V2_MAX_CALL_BYTES);
  return Object.freeze({ coordinates: c, caller: actor, request: q,
    call: Object.freeze({ to: c.reference, data, value: 0n }), preparation, factsVerified: false });
}

function stable(value: unknown): string {
  return JSON.stringify(value, (_, v: unknown) => typeof v === "bigint" ? { uint: v.toString() }
    : v && typeof v === "object" && !Array.isArray(v)
      ? Object.fromEntries(Object.entries(v).sort(([a], [b]) => a.localeCompare(b))) : v);
}

export function normalizeTokenPreservationReferenceV2Call(value: TokenPreservationReferenceV2Call): TokenPreservationReferenceV2Call {
  exact(value, ["coordinates", "caller", "request", "call", "preparation", "factsVerified"], "Prepared reference call");
  exact(value.call, ["to", "data", "value"], "CALL");
  if (value.preparation !== null) exact(value.preparation, ["id", "canonical", "contentHash", "byteLength"], "Preparation");
  const rebuilt = prepareTokenPreservationReferenceV2Call(value.coordinates, value.caller, value.request);
  if (stable(value) !== stable(rebuilt)) throw Error("Prepared reference call differs from exact reconstruction");
  return rebuilt;
}

export type TokenPreservationReferenceV2ReadRequest =
  | { readonly kind: "deploymentChainId" | "dependencies" | "preservationPolicyReferenceProfile" | "scopedPreservationPolicyReferenceProfile" | "core" | "metadataHost" | "metadataRouter" | "snapshots" | "archiveCoverage" }
  | { readonly kind: "supportsInterface"; readonly interfaceId: Hex }
  | { readonly kind: "previewReference"; readonly publication: TokenPreservationReferenceV2Publication; readonly recorder: Address }
  | { readonly kind: "preparedFileInventory"; readonly id: Hex }
  | { readonly kind: "referenceRecord" | "referencePayload" | "referenceSource"; readonly hash: Hex }
  | { readonly kind: "currentReference" | "referenceCount" | "referenceLock"; readonly scope: TokenPreservationReferenceV2Scope }
  | { readonly kind: "referenceChunkCount"; readonly hash: Hex }
  | { readonly kind: "referenceChunkAt"; readonly hash: Hex; readonly index: bigint }
  | { readonly kind: "referenceAt"; readonly scope: TokenPreservationReferenceV2Scope; readonly index: bigint }
  | { readonly kind: "requireCurrent"; readonly scope: TokenPreservationReferenceV2Scope; readonly hash: Hex; readonly revision: bigint };

export interface TokenPreservationReferenceV2Read {
  readonly coordinates: TokenPreservationReferenceV2Coordinates;
  readonly caller: Address;
  readonly request: TokenPreservationReferenceV2ReadRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export function prepareTokenPreservationReferenceV2Read(
  coordinates: TokenPreservationReferenceV2Coordinates,
  caller: Address,
  request: TokenPreservationReferenceV2ReadRequest,
): TokenPreservationReferenceV2Read {
  const c = normalizeTokenPreservationReferenceV2Coordinates(coordinates);
  const actor = address(caller);
  let q: TokenPreservationReferenceV2ReadRequest;
  let arguments_: readonly unknown[];
  switch (request?.kind) {
    case "deploymentChainId": case "dependencies": case "preservationPolicyReferenceProfile": case "scopedPreservationPolicyReferenceProfile": case "core": case "metadataHost":
    case "metadataRouter": case "snapshots": case "archiveCoverage":
      exact(request, ["kind"], "Reference getter");
      if ((request.kind === "preservationPolicyReferenceProfile" && c.scopeKind !== "collection")
        || (request.kind === "scopedPreservationPolicyReferenceProfile" && c.scopeKind !== "scoped")) throw Error("Profile getter belongs to other host kind");
      q = Object.freeze({ kind: request.kind }); arguments_ = []; break;
    case "supportsInterface":
      exact(request, ["kind", "interfaceId"], "Interface getter");
      q = Object.freeze({ kind: request.kind, interfaceId: bytes(request.interfaceId, 4) });
      arguments_ = [q.interfaceId]; break;
    case "previewReference":
      exact(request, ["kind", "publication", "recorder"], "Reference preview");
      q = Object.freeze({ kind: request.kind, publication: validateTokenPreservationReferenceV2Publication(c.scopeKind, request.publication, "preview"),
        recorder: address(request.recorder, true) }); arguments_ = [q.publication, q.recorder]; break;
    case "preparedFileInventory":
      exact(request, ["kind", "id"], "Prepared inventory getter");
      q = Object.freeze({ kind: request.kind, id: bytes(request.id, 32) }); arguments_ = [q.id]; break;
    case "referenceRecord": case "referencePayload": case "referenceSource":
      exact(request, ["kind", "hash"], "Reference history getter");
      q = Object.freeze({ kind: request.kind, hash: bytes(request.hash, 32) }); arguments_ = [q.hash]; break;
    case "currentReference": case "referenceCount": case "referenceLock":
      exact(request, ["kind", "scope"], "Reference scope getter");
      q = Object.freeze({ kind: request.kind, scope: output.validateTokenPreservationOutputV2Scope(c.scopeKind, request.scope) });
      arguments_ = [q.scope]; break;
    case "referenceChunkCount":
      if (c.scopeKind !== "collection") throw Error("Scoped reference has no chunk getter");
      exact(request, ["kind", "hash"], "Reference chunks");
      q = Object.freeze({ kind: request.kind, hash: bytes(request.hash, 32) }); arguments_ = [q.hash]; break;
    case "referenceChunkAt":
      if (c.scopeKind !== "collection") throw Error("Scoped reference has no chunk getter");
      exact(request, ["kind", "hash", "index"], "Reference chunk");
      q = Object.freeze({ kind: request.kind, hash: bytes(request.hash, 32), index: uint(request.index) });
      arguments_ = [q.hash, q.index]; break;
    case "referenceAt":
      exact(request, ["kind", "scope", "index"], "Reference index getter");
      q = Object.freeze({ kind: request.kind, scope: output.validateTokenPreservationOutputV2Scope(c.scopeKind, request.scope), index: uint(request.index) });
      arguments_ = [q.scope, q.index]; break;
    case "requireCurrent":
      exact(request, ["kind", "scope", "hash", "revision"], "Reference currentness getter");
      q = Object.freeze({ kind: request.kind, scope: output.validateTokenPreservationOutputV2Scope(c.scopeKind, request.scope),
        hash: bytes(request.hash, 32), revision: uint(request.revision, 64) });
      arguments_ = [q.scope, q.hash, q.revision]; break;
    default: throw Error("Unknown scoped reference read kind");
  }
  return Object.freeze({ coordinates: c, caller: actor, request: q, factsVerified: false,
    call: Object.freeze({ to: c.reference, value: 0n,
      data: bytes(tokenPreservationReferenceV2Interface(c.scopeKind).encodeFunctionData(q.kind, arguments_), undefined, TOKEN_PRESERVATION_REFERENCE_V2_MAX_CALL_BYTES) }) });
}

export function normalizeTokenPreservationReferenceV2Read(value: TokenPreservationReferenceV2Read): TokenPreservationReferenceV2Read {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Prepared reference read");
  exact(value.call, ["to", "data", "value"], "Read CALL");
  const rebuilt = prepareTokenPreservationReferenceV2Read(value.coordinates, value.caller, value.request);
  if (stable(value) !== stable(rebuilt)) throw Error("Reference read differs from exact reconstruction");
  return rebuilt;
}

export interface TokenPreservationReferenceV2Definition {
  readonly id: Hex;
  readonly kind: 0n | 1n | 2n;
  readonly hash: Hex;
  readonly byteLength: bigint;
  readonly data: Hex;
}

const COLLECTION_SCHEMA_DOCUMENT = "{\"name\":\"STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V2\",\"version\":2,\"encoding\":\"Solidity ABI\",\"payloadDomain\":\"6529STREAM_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V2\",\"payload\":[\"bytes32 domain\",\"uint256 chainId\",\"address referenceHost\",\"Publication publication\",\"Receipt receipt\",\"SourceFacts source\",\"bytes canonicalEnvironment\"],\"types\":[{\"components\":[{\"internalType\":\"address[7]\",\"name\":\"targets\",\"type\":\"address[7]\"},{\"internalType\":\"bytes32[7]\",\"name\":\"codeHashes\",\"type\":\"bytes32[7]\"},{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"readGas\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"sourceGas\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"snapshotGas\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"archiveGas\",\"type\":\"uint256\"}],\"internalType\":\"struct StreamPreservationPolicyReferenceTypesV1.Dependencies\",\"name\":\"dependencies\",\"type\":\"tuple\"},{\"components\":[{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"referenceId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"expectedHead\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"expectedRevision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"snapshotRevision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"expectedSourcesHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"collectionSerial\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"metadataJSONHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"htmlHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"htmlBytes\",\"type\":\"uint32\"},{\"internalType\":\"bytes\",\"name\":\"animationHTML\",\"type\":\"bytes\"},{\"internalType\":\"bytes32\",\"name\":\"objectHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"coverageHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"sourceSha256\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32[2]\",\"name\":\"repeatCaptureSha256\",\"type\":\"bytes32[2]\"},{\"internalType\":\"bytes32\",\"name\":\"environmentManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"capturedAt\",\"type\":\"uint64\"}],\"internalType\":\"struct StreamReferenceRenderTypes.Capture[]\",\"name\":\"captures\",\"type\":\"tuple[]\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"objectHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"coverageHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"manifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"manifestBytes\",\"type\":\"uint32\"},{\"internalType\":\"string\",\"name\":\"engineName\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"engineVersion\",\"type\":\"string\"},{\"internalType\":\"bytes32\",\"name\":\"engineExecutableSha256\",\"type\":\"bytes32\"},{\"internalType\":\"string\",\"name\":\"toolchainName\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"toolchainVersion\",\"type\":\"string\"},{\"internalType\":\"bytes32\",\"name\":\"toolchainSha256\",\"type\":\"bytes32\"},{\"internalType\":\"string\",\"name\":\"engineExecutablePath\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"toolchainPath\",\"type\":\"string\"},{\"components\":[{\"internalType\":\"string\",\"name\":\"path\",\"type\":\"string\"},{\"internalType\":\"uint64\",\"name\":\"byteSize\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"sha256Digest\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamReferenceRenderTypes.PackageFile[]\",\"name\":\"packageFiles\",\"type\":\"tuple[]\"},{\"components\":[{\"internalType\":\"string\",\"name\":\"path\",\"type\":\"string\"},{\"internalType\":\"uint64\",\"name\":\"byteSize\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"sha256Digest\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamReferenceRenderTypes.PackageFile[]\",\"name\":\"platformPrerequisites\",\"type\":\"tuple[]\"},{\"internalType\":\"string\",\"name\":\"operatingSystem\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"operatingSystemVersion\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"architecture\",\"type\":\"string\"},{\"internalType\":\"uint16\",\"name\":\"viewportWidth\",\"type\":\"uint16\"},{\"internalType\":\"uint16\",\"name\":\"viewportHeight\",\"type\":\"uint16\"},{\"internalType\":\"uint8\",\"name\":\"devicePixelRatio\",\"type\":\"uint8\"},{\"internalType\":\"string\",\"name\":\"colorSpace\",\"type\":\"string\"},{\"internalType\":\"bool\",\"name\":\"softwareRasterization\",\"type\":\"bool\"},{\"internalType\":\"bytes32\",\"name\":\"captureProfile\",\"type\":\"bytes32\"},{\"internalType\":\"string\",\"name\":\"licenseNote\",\"type\":\"string\"}],\"internalType\":\"struct StreamReferenceRenderTypes.Environment\",\"name\":\"environment\",\"type\":\"tuple\"},{\"internalType\":\"string\",\"name\":\"manifestURI\",\"type\":\"string\"},{\"internalType\":\"uint64\",\"name\":\"effectiveAt\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"reasonHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamReferenceRenderTypes.Publication\",\"name\":\"observation\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamPreservationPolicyReferenceTypesV1.Publication\",\"name\":\"publication\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"scopeSubject\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"recordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"recordChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"referenceId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"predecessor\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"revision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"payloadHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"payloadBytes\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"sourcesHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"snapshotRevision\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"recorder\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"authorizationClass\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"grantRevision\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"effectiveAt\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"recordedAt\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"reasonHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"schemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"profileHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"canonicalizationHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamReferenceRenderTypes.Receipt\",\"name\":\"observation\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamPreservationPolicyReferenceTypesV1.Receipt\",\"name\":\"receipt\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"scopeSubject\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"recordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"scopeSubject\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"predecessor\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"revision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"chainHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"manifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"manifestBytes\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"sourceHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"publisher\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"authorizationClass\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"grantRevision\",\"type\":\"uint64\"},{\"internalType\":\"uint8\",\"name\":\"displayAuthorizationClass\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"displayGrantRevision\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"recordedAt\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"schemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"profileHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"canonicalizationHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamPreservationPolicySnapshotTypesV1.Receipt\",\"name\":\"snapshot\",\"type\":\"tuple\"},{\"components\":[{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"scopeSubject\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"scopeManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"sourceRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"tokenCount\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"tokenListHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"membershipHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"inventoryCount\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryPrefixHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamScopeMembershipFacts\",\"name\":\"membership\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bool\",\"name\":\"locked\",\"type\":\"bool\"},{\"internalType\":\"address\",\"name\":\"registry\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"registryCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"bindingGeneration\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"bindingHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"nominatedArtist\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"identityRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"acceptanceRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"acceptedAt\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"lockedAt\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamMetadataServingFacts.ArtistPresentation\",\"name\":\"artist\",\"type\":\"tuple\"},{\"components\":[{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"internalType\":\"bytes32\",\"name\":\"membershipHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"collectionStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"tokenCount\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nextIndex\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"selectionRoot\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamStaticSelectionCheckpoint.Plan\",\"name\":\"selection\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"selectionId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"selectionHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"internalType\":\"uint64\",\"name\":\"tokenCount\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nextIndex\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"leafChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"preservationProfile\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamPreservationPolicyContentCheckpointV1.Plan\",\"name\":\"content\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"checkpointHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"entropySourceSet\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"metadataRouter\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"preservationProfile\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artifactHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"coverageHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"manifestHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"internalType\":\"uint64\",\"name\":\"tokenCount\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"byteLength\",\"type\":\"uint64\"}],\"internalType\":\"struct IStreamPreservationPolicyOutputManifestV1.Manifest\",\"name\":\"outputs\",\"type\":\"tuple\"},{\"components\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"expectedPredecessor\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"verifiedManifestRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"string\",\"name\":\"manifestURI\",\"type\":\"string\"}],\"internalType\":\"struct IStreamContentRootPublication.Publication\",\"name\":\"publication\",\"type\":\"tuple\"},{\"internalType\":\"bytes32\",\"name\":\"contentRoot\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"leafCount\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"manifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"bindingGeneration\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"bindingHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"publisher\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"authorizationClass\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"grantRevision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"routeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"stateHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistConsent\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"publishedAt\",\"type\":\"uint64\"}],\"internalType\":\"struct IStreamContentRootPublication.Record\",\"name\":\"root\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"profileId\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"outputManifest\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"outputManifestCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"checkpoint\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"entropySourceSet\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"entropySourceSetCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputCanonicalizationHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"leafSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rootSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rootCanonicalizationHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"metadataRouter\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"preservationOutputProfile\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamPreservationPolicyContentRootPublicationV1.Binding\",\"name\":\"rootBinding\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"planId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"policyCount\",\"type\":\"uint256\"},{\"internalType\":\"bool\",\"name\":\"allFrozen\",\"type\":\"bool\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"coordinator\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"indexedCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"firstTokenIndex\",\"type\":\"uint256\"},{\"internalType\":\"bool\",\"name\":\"frozen\",\"type\":\"bool\"},{\"internalType\":\"bytes32\",\"name\":\"moduleVersion\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"moduleManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"moduleSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"deploymentManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"provider\",\"type\":\"address\"},{\"internalType\":\"uint32\",\"name\":\"epoch\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"salt\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"componentDataHash\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"explicitPolicy\",\"type\":\"bool\"},{\"components\":[{\"internalType\":\"bool\",\"name\":\"configured\",\"type\":\"bool\"},{\"internalType\":\"bool\",\"name\":\"explicitPolicy\",\"type\":\"bool\"},{\"internalType\":\"bool\",\"name\":\"frozen\",\"type\":\"bool\"},{\"internalType\":\"uint8\",\"name\":\"mode\",\"type\":\"uint8\"},{\"internalType\":\"uint8\",\"name\":\"securityClass\",\"type\":\"uint8\"},{\"internalType\":\"uint8\",\"name\":\"renderRequirement\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"revision\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"providerEpoch\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"policyHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"lastActionId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistConsentRecord\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamEntropyPolicyConsumerTypes.Policy\",\"name\":\"collectionPolicy\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamFinalityCoordinatorPolicyV2[]\",\"name\":\"policies\",\"type\":\"tuple[]\"}],\"internalType\":\"struct StreamFinalityCoordinatorPolicyEvidenceV2\",\"name\":\"entropy\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamPreservationPolicySnapshotTypesV1.Source\",\"name\":\"snapshotSource\",\"type\":\"tuple\"},{\"internalType\":\"bytes32\",\"name\":\"contentRootRecordHash\",\"type\":\"bytes32\"},{\"components\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"expectedPredecessor\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"verifiedManifestRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"string\",\"name\":\"manifestURI\",\"type\":\"string\"}],\"internalType\":\"struct IStreamContentRootPublication.Publication\",\"name\":\"publication\",\"type\":\"tuple\"},{\"internalType\":\"bytes32\",\"name\":\"contentRoot\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"leafCount\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"manifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"bindingGeneration\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"bindingHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"publisher\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"authorizationClass\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"grantRevision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"routeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"stateHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistConsent\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"publishedAt\",\"type\":\"uint64\"}],\"internalType\":\"struct IStreamContentRootPublication.Record\",\"name\":\"contentRoot\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"profileId\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"outputManifest\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"outputManifestCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"checkpoint\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"entropySourceSet\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"entropySourceSetCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputCanonicalizationHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"leafSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rootSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rootCanonicalizationHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"metadataRouter\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"preservationOutputProfile\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamPreservationPolicyContentRootPublicationV1.Binding\",\"name\":\"contentRootBinding\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"coverageHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"objectHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"sha256Digest\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"arweaveDataRoot\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"byteSize\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"firstFamilyRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"secondFamilyRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"firstReceiptHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"secondReceiptHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"firstFixityHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"secondFixityHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"profileHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamExternalArtifactTypes.Coverage\",\"name\":\"environmentCoverage\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"uint64\",\"name\":\"membershipIndex\",\"type\":\"uint64\"},{\"components\":[{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"collectionSerial\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"originalCoordinator\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"seed\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"tokenDataHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"tokenDataBytes\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"metadataJSONHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"htmlHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"htmlBytes\",\"type\":\"uint32\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"coverageHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"objectHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"sha256Digest\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"arweaveDataRoot\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"byteSize\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"firstFamilyRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"secondFamilyRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"firstReceiptHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"secondReceiptHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"firstFixityHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"secondFixityHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"profileHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamExternalArtifactTypes.Coverage\",\"name\":\"captureCoverage\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamReferenceRenderTypes.SampleFacts\",\"name\":\"observation\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"configRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"configHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"sourceSnapshotHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rawSourceHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"registry\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"registryCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"versionKey\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"renderer\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"rendererCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rendererId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rendererVersion\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contextVersion\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"schemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"readSetHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"registrationHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamStaticMetadataRouter.Selection\",\"name\":\"selection\",\"type\":\"tuple\"},{\"internalType\":\"address[6]\",\"name\":\"sources\",\"type\":\"address[6]\"},{\"internalType\":\"bytes32[6]\",\"name\":\"sourceCodeHashes\",\"type\":\"bytes32[6]\"}],\"internalType\":\"struct IStreamStaticSelectionCheckpoint.TokenSelection\",\"name\":\"selection\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"coordinator\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"coordinatorCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint8\",\"name\":\"status\",\"type\":\"uint8\"},{\"internalType\":\"uint8\",\"name\":\"mode\",\"type\":\"uint8\"},{\"internalType\":\"uint8\",\"name\":\"securityClass\",\"type\":\"uint8\"},{\"internalType\":\"uint8\",\"name\":\"renderRequirement\",\"type\":\"uint8\"},{\"internalType\":\"bool\",\"name\":\"terminal\",\"type\":\"bool\"},{\"internalType\":\"bool\",\"name\":\"finalized\",\"type\":\"bool\"},{\"internalType\":\"bytes32\",\"name\":\"seed\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamFinalityEntropyPolicySourceSet.TokenReadiness\",\"name\":\"entropy\",\"type\":\"tuple\"},{\"internalType\":\"bytes32\",\"name\":\"terminalAdmissionHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"producer\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"producerCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"profile\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"core\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"metadataRouter\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"liveRenderer\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"liveRendererCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"attribution\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"attributionCodeHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamPreservationPolicyOutputTypesV1.Binding\",\"name\":\"preservation\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"registry\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"registryCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"versionKey\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"registrationHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"readSetHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"analysisHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"goldenHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamPreservationPolicyOutputTypesV1.Admission\",\"name\":\"preservationAdmission\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamPreservationPolicyReferenceTypesV1.Sample[]\",\"name\":\"samples\",\"type\":\"tuple[]\"}],\"internalType\":\"struct StreamPreservationPolicyReferenceTypesV1.SourceFacts\",\"name\":\"source\",\"type\":\"tuple\"}],\"canonical\":\"Exact compiler ABI, no alternate offset/padding/trailing bytes; publication.observation.expectedSourcesHash is zero. Receipt observation recordHash,recordChainHash,payloadHash,payloadBytes,recordedAt are zero. sourcesHash holds full source commitment. Each sample retains the exact member-specific preservation Binding and governed Admission. Snapshot source includes the canonical original preservation CONTENT_ROOT record and all nineteen binding words. Complete membership is carried by the snapshot, never inferred from samples.\",\"producerFamily\":\"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2: complete Plan and Manifest marker. Each output retains its actual producer profile, either 6529STREAM_PRESERVATION_RENDER_V1 or 6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1, and exact governed selected Registry/version admission. No VIEW or caller-defined profile. Original V1 documents and entrypoints remain strict.\"}\n";
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_SCHEMA_ID = id("STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V2") as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_SCHEMA_HASH = keccak256(toUtf8Bytes(COLLECTION_SCHEMA_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_SCHEMA_BYTES = 29589;

const COLLECTION_PROFILE_DOCUMENT = "{\"name\":\"STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_PROFILE_V2\",\"version\":2,\"scope\":\"COLLECTION only; BYTE_EXACT repeated first/last authoritative membership ordinal captures with complete current preservation snapshot, canonical Router preservation CONTENT_ROOT and full original-source entropy policies. No VIEW or other scope reinterpretation.\",\"authority\":\"Actual selected Metadata CURATOR class3 collection or class8 global; exact class2 lock. Snapshot separately requires SNAPSHOT+IDENTITY7/8. No Artist authority from observation.\",\"entropy\":\"Exact original coordinatorAtMint. Terminal DISABLED or ASYNC NOT_REQUIRED status and full policy H remain explicit with seed0/finalized=false and independently admitted terminal STATIC output; finalized status5 retains exact seed. Never substitute an old finalized-only receipt.\",\"outputs\":\"Exact saved per-member admitted preservation producer JSON/HTML and actual tokenData. Authenticate full Binding and governed Admission against current Registry.requirePreservation; live Router bytes are not substituted. The complete covered preservation output manifest is checked independently of first/last observations.\",\"environment\":\"Original STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1 complete package/runtime/prerequisite membership and current attributed external coverage. Same environment commitment for every sample.\",\"limits\":{\"payloadBytes\":524288,\"chunkBytes\":8192},\"unproven\":\"Repeated sample images do not prove complete artifact availability or all-token rendering conformance. Selected-provider input/component admission and complete archival coverage remain independent requirements.\",\"producerFamily\":\"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2: complete Plan and Manifest marker. Each output retains its actual producer profile, either 6529STREAM_PRESERVATION_RENDER_V1 or 6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1, and exact governed selected Registry/version admission. No VIEW or caller-defined profile. Original V1 documents and entrypoints remain strict.\"}\n";
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_PROFILE_ID = id("STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_PROFILE_V2") as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_PROFILE_HASH = keccak256(toUtf8Bytes(COLLECTION_PROFILE_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_PROFILE_BYTES = 2029;

const COLLECTION_CANONICALIZATION_DOCUMENT = "{\"name\":\"STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V2\",\"version\":2,\"encoding\":\"abi.encode(payloadDomain,chainId,referenceHost,publication,receipt,source,canonicalEnvironment)\",\"payloadDomain\":\"keccak256(6529STREAM_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V2)\",\"sourceHash\":\"keccak256(abi.encode(keccak256(6529STREAM_PRESERVATION_POLICY_REFERENCE_SOURCES_V2),chainId,referenceHost,targets,codeHashes,source))\",\"recordHash\":\"keccak256(abi.encode(keccak256(6529STREAM_PRESERVATION_POLICY_REFERENCE_RECORD_V2),chainId,referenceHost,Core,Metadata,publication,receiptWithObservationRecordHashAndChainHashZero))\",\"chainHash\":\"keccak256(abi.encode(keccak256(6529STREAM_PRESERVATION_POLICY_REFERENCE_CHAIN_V2),chainId,referenceHost,Core,scopeSubject,previousChainHash,revision,recordHash))\",\"canonical\":\"Exact compiler ABI with original UTF8 strings. Environment bytes retain original JCS recipe; this outer payload is not JCS. All ordered chunks plus full payload Keccak are required.\",\"producerFamily\":\"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2: complete Plan and Manifest marker. Each output retains its actual producer profile, either 6529STREAM_PRESERVATION_RENDER_V1 or 6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1, and exact governed selected Registry/version admission. No VIEW or caller-defined profile. Original V1 documents and entrypoints remain strict.\"}\n";
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_CANONICALIZATION_ID = id("STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V2") as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_CANONICALIZATION_HASH = keccak256(toUtf8Bytes(COLLECTION_CANONICALIZATION_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_CANONICALIZATION_BYTES = 1368;

const SCOPED_SCHEMA_DOCUMENT = "{\"name\":\"STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V2\",\"version\":2,\"encoding\":\"Solidity ABI\",\"payloadDomain\":\"6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V2\",\"payload\":[\"bytes32 domain\",\"uint256 chainId\",\"address referenceHost\",\"Publication publication\",\"Receipt receipt\",\"SourceFacts source\",\"bytes canonicalEnvironment\"],\"types\":[{\"components\":[{\"internalType\":\"address[7]\",\"name\":\"targets\",\"type\":\"address[7]\"},{\"internalType\":\"bytes32[7]\",\"name\":\"codeHashes\",\"type\":\"bytes32[7]\"},{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"readGas\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"sourceGas\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"snapshotGas\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"archiveGas\",\"type\":\"uint256\"}],\"internalType\":\"struct StreamScopedPreservationPolicyReferenceTypesV1.Dependencies\",\"name\":\"dependencies\",\"type\":\"tuple\"},{\"components\":[{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"referenceId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"expectedHead\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"expectedRevision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"snapshotRevision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"expectedSourcesHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"collectionSerial\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"metadataJSONHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"htmlHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"htmlBytes\",\"type\":\"uint32\"},{\"internalType\":\"bytes\",\"name\":\"animationHTML\",\"type\":\"bytes\"},{\"internalType\":\"bytes32\",\"name\":\"objectHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"coverageHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"sourceSha256\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32[2]\",\"name\":\"repeatCaptureSha256\",\"type\":\"bytes32[2]\"},{\"internalType\":\"bytes32\",\"name\":\"environmentManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"capturedAt\",\"type\":\"uint64\"}],\"internalType\":\"struct StreamReferenceRenderTypes.Capture[]\",\"name\":\"captures\",\"type\":\"tuple[]\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"objectHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"coverageHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"manifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"manifestBytes\",\"type\":\"uint32\"},{\"internalType\":\"string\",\"name\":\"engineName\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"engineVersion\",\"type\":\"string\"},{\"internalType\":\"bytes32\",\"name\":\"engineExecutableSha256\",\"type\":\"bytes32\"},{\"internalType\":\"string\",\"name\":\"toolchainName\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"toolchainVersion\",\"type\":\"string\"},{\"internalType\":\"bytes32\",\"name\":\"toolchainSha256\",\"type\":\"bytes32\"},{\"internalType\":\"string\",\"name\":\"engineExecutablePath\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"toolchainPath\",\"type\":\"string\"},{\"components\":[{\"internalType\":\"string\",\"name\":\"path\",\"type\":\"string\"},{\"internalType\":\"uint64\",\"name\":\"byteSize\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"sha256Digest\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamReferenceRenderTypes.PackageFile[]\",\"name\":\"packageFiles\",\"type\":\"tuple[]\"},{\"components\":[{\"internalType\":\"string\",\"name\":\"path\",\"type\":\"string\"},{\"internalType\":\"uint64\",\"name\":\"byteSize\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"sha256Digest\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamReferenceRenderTypes.PackageFile[]\",\"name\":\"platformPrerequisites\",\"type\":\"tuple[]\"},{\"internalType\":\"string\",\"name\":\"operatingSystem\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"operatingSystemVersion\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"architecture\",\"type\":\"string\"},{\"internalType\":\"uint16\",\"name\":\"viewportWidth\",\"type\":\"uint16\"},{\"internalType\":\"uint16\",\"name\":\"viewportHeight\",\"type\":\"uint16\"},{\"internalType\":\"uint8\",\"name\":\"devicePixelRatio\",\"type\":\"uint8\"},{\"internalType\":\"string\",\"name\":\"colorSpace\",\"type\":\"string\"},{\"internalType\":\"bool\",\"name\":\"softwareRasterization\",\"type\":\"bool\"},{\"internalType\":\"bytes32\",\"name\":\"captureProfile\",\"type\":\"bytes32\"},{\"internalType\":\"string\",\"name\":\"licenseNote\",\"type\":\"string\"}],\"internalType\":\"struct StreamReferenceRenderTypes.Environment\",\"name\":\"environment\",\"type\":\"tuple\"},{\"internalType\":\"string\",\"name\":\"manifestURI\",\"type\":\"string\"},{\"internalType\":\"uint64\",\"name\":\"effectiveAt\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"reasonHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamReferenceRenderTypes.Publication\",\"name\":\"observation\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamScopedPreservationPolicyReferenceTypesV1.Publication\",\"name\":\"publication\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"scopeSubject\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"recordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"recordChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"referenceId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"predecessor\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"revision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"payloadHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"payloadBytes\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"sourcesHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"snapshotRevision\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"recorder\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"authorizationClass\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"grantRevision\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"effectiveAt\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"recordedAt\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"reasonHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"schemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"profileHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"canonicalizationHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamReferenceRenderTypes.Receipt\",\"name\":\"observation\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamScopedPreservationPolicyReferenceTypesV1.Receipt\",\"name\":\"receipt\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"scopeSubject\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"recordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"scopeSubject\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"predecessor\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"revision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"chainHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"manifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"manifestBytes\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"sourceHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"publisher\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"authorizationClass\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"grantRevision\",\"type\":\"uint64\"},{\"internalType\":\"uint8\",\"name\":\"displayAuthorizationClass\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"displayGrantRevision\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"recordedAt\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"schemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"profileHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"canonicalizationHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamScopedPreservationPolicySnapshotTypesV1.Receipt\",\"name\":\"snapshot\",\"type\":\"tuple\"},{\"components\":[{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"scopeSubject\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"scopeManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"sourceRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"tokenCount\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"tokenListHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"membershipHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"inventoryCount\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryPrefixHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamScopeMembershipFacts\",\"name\":\"membership\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bool\",\"name\":\"locked\",\"type\":\"bool\"},{\"internalType\":\"address\",\"name\":\"registry\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"registryCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"bindingGeneration\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"bindingHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"nominatedArtist\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"identityRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"acceptanceRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"acceptedAt\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"lockedAt\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamMetadataServingFacts.ArtistPresentation\",\"name\":\"artist\",\"type\":\"tuple\"},{\"components\":[{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"internalType\":\"bytes32\",\"name\":\"membershipHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"collectionStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"tokenCount\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nextIndex\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"selectionRoot\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamStaticSelectionCheckpoint.Plan\",\"name\":\"selection\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"selectionId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"selectionHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"internalType\":\"uint64\",\"name\":\"tokenCount\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nextIndex\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"leafChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"preservationProfile\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamPreservationPolicyContentCheckpointV1.Plan\",\"name\":\"content\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"checkpointHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"entropySourceSet\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"metadataRouter\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"preservationProfile\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artifactHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"coverageHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"manifestHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"internalType\":\"uint64\",\"name\":\"tokenCount\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"byteLength\",\"type\":\"uint64\"}],\"internalType\":\"struct IStreamPreservationPolicyOutputManifestV1.Manifest\",\"name\":\"outputs\",\"type\":\"tuple\"},{\"internalType\":\"address\",\"name\":\"sourceFactory\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"sourceFactoryCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"factoryDependenciesHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"planId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"policyCount\",\"type\":\"uint256\"},{\"internalType\":\"bool\",\"name\":\"allFrozen\",\"type\":\"bool\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"coordinator\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"indexedCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"firstTokenIndex\",\"type\":\"uint256\"},{\"internalType\":\"bool\",\"name\":\"frozen\",\"type\":\"bool\"},{\"internalType\":\"bytes32\",\"name\":\"moduleVersion\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"moduleManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"moduleSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"deploymentManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"provider\",\"type\":\"address\"},{\"internalType\":\"uint32\",\"name\":\"epoch\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"salt\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"componentDataHash\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"explicitPolicy\",\"type\":\"bool\"},{\"components\":[{\"internalType\":\"bool\",\"name\":\"configured\",\"type\":\"bool\"},{\"internalType\":\"bool\",\"name\":\"explicitPolicy\",\"type\":\"bool\"},{\"internalType\":\"bool\",\"name\":\"frozen\",\"type\":\"bool\"},{\"internalType\":\"uint8\",\"name\":\"mode\",\"type\":\"uint8\"},{\"internalType\":\"uint8\",\"name\":\"securityClass\",\"type\":\"uint8\"},{\"internalType\":\"uint8\",\"name\":\"renderRequirement\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"revision\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"providerEpoch\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"policyHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"lastActionId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistConsentRecord\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamEntropyPolicyConsumerTypes.Policy\",\"name\":\"collectionPolicy\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamFinalityCoordinatorPolicyV2[]\",\"name\":\"policies\",\"type\":\"tuple[]\"}],\"internalType\":\"struct StreamFinalityCoordinatorPolicyEvidenceV2\",\"name\":\"entropy\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamScopedPreservationPolicySnapshotTypesV1.Source\",\"name\":\"snapshotSource\",\"type\":\"tuple\"},{\"internalType\":\"bytes32\",\"name\":\"contentRootRecordHash\",\"type\":\"bytes32\"},{\"components\":[{\"components\":[{\"components\":[{\"internalType\":\"enum StreamFinalityScopeType\",\"name\":\"scopeType\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"collectionId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"scopeId\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamFinalityScope\",\"name\":\"scope\",\"type\":\"tuple\"},{\"internalType\":\"bytes32\",\"name\":\"expectedPredecessor\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"snapshotRevision\",\"type\":\"uint64\"},{\"internalType\":\"string\",\"name\":\"manifestURI\",\"type\":\"string\"}],\"internalType\":\"struct IStreamScopedContentRootPublication.Publication\",\"name\":\"publication\",\"type\":\"tuple\"},{\"internalType\":\"address\",\"name\":\"snapshotHost\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotSourceHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentRoot\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"leafCount\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"outputManifestHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"bindingGeneration\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"bindingHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"publisher\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"authorizationClass\",\"type\":\"uint8\"},{\"internalType\":\"uint64\",\"name\":\"grantRevision\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"routeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"stateHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistConsent\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"publishedAt\",\"type\":\"uint64\"}],\"internalType\":\"struct IStreamScopedContentRootPublication.Record\",\"name\":\"contentRoot\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"profileId\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"outputManifest\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"outputManifestCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"checkpoint\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointStateHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"entropySourceSet\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"entropySourceSetCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"inventoryHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyChainHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"outputCanonicalizationHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"leafSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rootSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rootCanonicalizationHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"sourceFactory\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"sourceFactoryCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"factoryDependenciesHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotSchemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotProfileHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"snapshotCanonicalizationHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"metadataRouter\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"preservationOutputProfile\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamScopedPreservationPolicyContentRootPublicationV1.Binding\",\"name\":\"contentRootBinding\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"coverageHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"objectHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"sha256Digest\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"arweaveDataRoot\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"byteSize\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"firstFamilyRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"secondFamilyRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"firstReceiptHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"secondReceiptHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"firstFixityHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"secondFixityHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"profileHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamExternalArtifactTypes.Coverage\",\"name\":\"environmentCoverage\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"uint64\",\"name\":\"membershipIndex\",\"type\":\"uint64\"},{\"components\":[{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"collectionSerial\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"originalCoordinator\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"seed\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"tokenDataHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"tokenDataBytes\",\"type\":\"uint32\"},{\"internalType\":\"bytes32\",\"name\":\"metadataJSONHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"htmlHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint32\",\"name\":\"htmlBytes\",\"type\":\"uint32\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"coverageHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"objectHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"artistId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contentHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"sha256Digest\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"arweaveDataRoot\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"byteSize\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"firstFamilyRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"secondFamilyRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"firstReceiptHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"secondReceiptHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"firstFixityHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"secondFixityHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"checkpointHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"profileHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamExternalArtifactTypes.Coverage\",\"name\":\"captureCoverage\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamReferenceRenderTypes.SampleFacts\",\"name\":\"observation\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"uint256\",\"name\":\"tokenId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"configRecordHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"configHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"sourceSnapshotHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rawSourceHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"registry\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"registryCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"versionKey\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"renderer\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"rendererCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rendererId\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"rendererVersion\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"contextVersion\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"schemaHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"readSetHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"registrationHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamStaticMetadataRouter.Selection\",\"name\":\"selection\",\"type\":\"tuple\"},{\"internalType\":\"address[6]\",\"name\":\"sources\",\"type\":\"address[6]\"},{\"internalType\":\"bytes32[6]\",\"name\":\"sourceCodeHashes\",\"type\":\"bytes32[6]\"}],\"internalType\":\"struct IStreamStaticSelectionCheckpoint.TokenSelection\",\"name\":\"selection\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"coordinator\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"coordinatorCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"policyHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint8\",\"name\":\"status\",\"type\":\"uint8\"},{\"internalType\":\"uint8\",\"name\":\"mode\",\"type\":\"uint8\"},{\"internalType\":\"uint8\",\"name\":\"securityClass\",\"type\":\"uint8\"},{\"internalType\":\"uint8\",\"name\":\"renderRequirement\",\"type\":\"uint8\"},{\"internalType\":\"bool\",\"name\":\"terminal\",\"type\":\"bool\"},{\"internalType\":\"bool\",\"name\":\"finalized\",\"type\":\"bool\"},{\"internalType\":\"bytes32\",\"name\":\"seed\",\"type\":\"bytes32\"}],\"internalType\":\"struct IStreamFinalityEntropyPolicySourceSet.TokenReadiness\",\"name\":\"entropy\",\"type\":\"tuple\"},{\"internalType\":\"bytes32\",\"name\":\"terminalAdmissionHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"producer\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"producerCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"profile\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"core\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"metadataRouter\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"liveRenderer\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"liveRendererCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"attribution\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"attributionCodeHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamPreservationPolicyOutputTypesV1.Binding\",\"name\":\"preservation\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"registry\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"registryCodeHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"versionKey\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"registrationHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"readSetHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"analysisHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"goldenHash\",\"type\":\"bytes32\"}],\"internalType\":\"struct StreamPreservationPolicyOutputTypesV1.Admission\",\"name\":\"preservationAdmission\",\"type\":\"tuple\"}],\"internalType\":\"struct StreamScopedPreservationPolicyReferenceTypesV1.Sample[]\",\"name\":\"samples\",\"type\":\"tuple[]\"}],\"internalType\":\"struct StreamScopedPreservationPolicyReferenceTypesV1.SourceFacts\",\"name\":\"source\",\"type\":\"tuple\"}],\"canonical\":\"Exact compiler ABI, no alternate offset/padding/trailing bytes; publication.observation.expectedSourcesHash is zero. Receipt observation recordHash,recordChainHash,payloadHash,payloadBytes,recordedAt are zero. sourcesHash holds full source commitment. Snapshot source is root-free. The separate matched original scoped root and complete V2 binding authenticate adopted state; snapshot publication outputManifestRecord names the original output receipt, not its manifest payload hash.\",\"scope\":\"Complete exact TOKEN, RELEASE or SEASON. No COLLECTION or VIEW reinterpretation. Samples retain the exact member-specific preservation producer Binding and original governed Admission; full membership remains in the authenticated snapshot and covered outputRoot.\",\"producerFamily\":\"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2: complete Plan and Manifest marker. Each output retains its actual producer profile, either 6529STREAM_PRESERVATION_RENDER_V1 or 6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1, and exact governed selected Registry/version admission. No VIEW or caller-defined profile. Original V1 documents and entrypoints remain strict.\"}\n";
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_SCHEMA_ID = id("STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V2") as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_SCHEMA_HASH = keccak256(toUtf8Bytes(SCOPED_SCHEMA_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_SCHEMA_BYTES = 28358;

const SCOPED_PROFILE_DOCUMENT = "{\"name\":\"STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_PROFILE_V2\",\"version\":2,\"profile\":\"6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V2\",\"scope\":\"TOKEN, RELEASE and SEASON only; BYTE_EXACT repeated first/last authoritative membership ordinal captures with complete current scoped preservation-policy snapshot, original Router CONTENT_ROOT and full original-source entropy policy set. COLLECTION, VIEW and other reference modes retain their separate profiles.\",\"authority\":\"Actual selected Metadata CURATOR class3 collection or class8 global; exact class2 lock. Snapshot separately requires SNAPSHOT and IDENTITY class7/8. Root separately retains original Artist operation17 CONTENT_ROOT authority. No Artist authority from observation.\",\"entropy\":\"Exact original coordinatorAtMint. Terminal DISABLED or ASYNC NOT_REQUIRED remains seed0/finalized=false with independently admitted terminal STATIC output; finalized status5 retains actual seed. Complete1152-byte output rows retain full policy readiness,9word per-member producer Binding and7word governed Admission.\",\"sources\":\"Exact preservation snapshot capability/profile/domains, actual immutable scoped policy source factory and dependencies, complete output receipt, common current scoped root and canonical25word preservation binding. No legacy decoder or profile alias.\",\"outputs\":\"Observe the exact saved per-member producer preservationTokenJSON/preservationTokenHTML and actual retained tokenData. Independently rejoin the512-byte original Registry.requirePreservation result to the selected registry/runtime/version, complete saved producer binding and all seven admission words before reading bytes. Binding.requireCurrent pins actual producer,Core,Router,selected live renderer and attribution companion. Mixed selected renderers remain complete members.\",\"environment\":\"Original STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1 complete package/runtime/prerequisite membership and attributed external coverage. Same environment commitment for every sample. Preparation binds original coverage; current revalidation requires the original current-pair semantics.\",\"history\":\"Retained originals do not depend on the current snapshot/root head. New preparation, current revalidation and mutating locks require the exact current full scope.\",\"limits\":{\"payloadBytes\":524288,\"chunkBytes\":8192},\"unproven\":\"Repeated sample images do not prove all-token rendering conformance or complete artifact availability. Immutable inventory, provider admission and finality remain independent requirements.\",\"projection\":\"Explicit ADR0054 preservation output excludes only sanction lookup and its derived display state,record hash and authority. Artwork,executable code,media,token data,citation,C2PA,original entropy and all other Artist facts remain current. Live tokenURI and original profiles keep their original meanings.\",\"producerFamily\":\"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2: complete Plan and Manifest marker. Each output retains its actual producer profile, either 6529STREAM_PRESERVATION_RENDER_V1 or 6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1, and exact governed selected Registry/version admission. No VIEW or caller-defined profile. Original V1 documents and entrypoints remain strict.\"}\n";
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_PROFILE_ID = id("STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_PROFILE_V2") as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_PROFILE_HASH = keccak256(toUtf8Bytes(SCOPED_PROFILE_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_PROFILE_BYTES = 3250;

const SCOPED_CANONICALIZATION_DOCUMENT = "{\"name\":\"STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V2\",\"version\":2,\"encoding\":\"abi.encode(payloadDomain,chainId,referenceHost,publication,receipt,source,canonicalEnvironment)\",\"payloadDomain\":\"keccak256(6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V2)\",\"sourceHash\":\"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V2),chainId,referenceHost,targets,codeHashes,source))\",\"recordHash\":\"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_RECORD_V2),chainId,referenceHost,Core,Metadata,publication,receiptWithObservationRecordHashAndChainHashZero))\",\"chainHash\":\"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_CHAIN_V2),chainId,referenceHost,Core,scopeSubject,previousChainHash,revision,recordHash))\",\"lockScope\":\"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_LOCK_SCOPE_V2),chainId,referenceHost,Core,scope,scopeSubject))\",\"normalization\":\"Payload publication.observation.expectedSourcesHash and receipt.observation recordHash,recordChainHash,payloadHash,payloadBytes,recordedAt are zero; sourcesHash remains populated. Record hash instead binds original expectedSourcesHash and completed payload/timestamp fields.\",\"canonical\":\"Exact Solidity ABI, validated UTF8 strings, no alternate offsets/padding/trailing bytes. Environment bytes retain original JCS recipe; outer payload is not JCS. All ordered chunks and full payload Keccak required.\",\"sample\":\"Sample is exactly2560 ABI bytes: original2048-byte scoped full-policy sample then Binding288 bytes and Admission224 bytes. Per-member producer/read admission is never replaced with one global producer.\",\"sourceJoins\":\"Snapshot dependencies832 bytes; checkpoint448 bytes; covered output manifest608 bytes; output1152 bytes; scoped root Binding800 bytes. Every typed object uses its new profile and exact tuple, with full original scope/factory/policy joins.\",\"producerFamily\":\"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2: complete Plan and Manifest marker. Each output retains its actual producer profile, either 6529STREAM_PRESERVATION_RENDER_V1 or 6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1, and exact governed selected Registry/version admission. No VIEW or caller-defined profile. Original V1 documents and entrypoints remain strict.\"}\n";
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_CANONICALIZATION_ID = id("STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V2") as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_CANONICALIZATION_HASH = keccak256(toUtf8Bytes(SCOPED_CANONICALIZATION_DOCUMENT)) as Hex;
export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_CANONICALIZATION_BYTES = 2341;

const STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1_DOCUMENT = "{\"$id\":\"STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1\",\"$schema\":\"https://json-schema.org/draft/2020-12/schema\",\"additionalProperties\":false,\"properties\":{\"architecture\":{\"type\":\"string\"},\"captureProfile\":{\"pattern\":\"^0x[0-9a-f]{64}$\",\"type\":\"string\"},\"colorSpace\":{\"type\":\"string\"},\"devicePixelRatio\":{\"maxLength\":78,\"pattern\":\"^(0|[1-9][0-9]*)$\",\"type\":\"string\"},\"engineExecutablePath\":{\"type\":\"string\"},\"engineExecutableSha256\":{\"pattern\":\"^0x[0-9a-f]{64}$\",\"type\":\"string\"},\"engineName\":{\"type\":\"string\"},\"engineVersion\":{\"type\":\"string\"},\"licenseBasis\":{\"const\":\"undetermined\"},\"licenseNote\":{\"type\":\"string\"},\"operatingSystem\":{\"type\":\"string\"},\"operatingSystemVersion\":{\"type\":\"string\"},\"packageFiles\":{\"items\":{\"additionalProperties\":false,\"properties\":{\"byteSize\":{\"maxLength\":78,\"pattern\":\"^(0|[1-9][0-9]*)$\",\"type\":\"string\"},\"path\":{\"type\":\"string\"},\"sha256Digest\":{\"pattern\":\"^0x[0-9a-f]{64}$\",\"type\":\"string\"}},\"required\":[\"byteSize\",\"path\",\"sha256Digest\"],\"type\":\"object\"},\"minItems\":1,\"type\":\"array\"},\"platformPrerequisites\":{\"items\":{\"additionalProperties\":false,\"properties\":{\"byteSize\":{\"maxLength\":78,\"pattern\":\"^(0|[1-9][0-9]*)$\",\"type\":\"string\"},\"path\":{\"type\":\"string\"},\"sha256Digest\":{\"pattern\":\"^0x[0-9a-f]{64}$\",\"type\":\"string\"}},\"required\":[\"byteSize\",\"path\",\"sha256Digest\"],\"type\":\"object\"},\"minItems\":1,\"type\":\"array\"},\"runtimeObjectHash\":{\"pattern\":\"^0x[0-9a-f]{64}$\",\"type\":\"string\"},\"softwareRasterization\":{\"const\":true},\"toolchainName\":{\"type\":\"string\"},\"toolchainPath\":{\"type\":\"string\"},\"toolchainSha256\":{\"pattern\":\"^0x[0-9a-f]{64}$\",\"type\":\"string\"},\"toolchainVersion\":{\"type\":\"string\"},\"version\":{\"const\":1},\"viewportHeight\":{\"maxLength\":78,\"pattern\":\"^(0|[1-9][0-9]*)$\",\"type\":\"string\"},\"viewportWidth\":{\"maxLength\":78,\"pattern\":\"^(0|[1-9][0-9]*)$\",\"type\":\"string\"}},\"required\":[\"engineExecutablePath\",\"engineName\",\"engineVersion\",\"licenseNote\",\"operatingSystem\",\"operatingSystemVersion\",\"architecture\",\"colorSpace\",\"toolchainName\",\"toolchainPath\",\"toolchainVersion\",\"captureProfile\",\"engineExecutableSha256\",\"runtimeObjectHash\",\"toolchainSha256\",\"devicePixelRatio\",\"viewportWidth\",\"viewportHeight\",\"licenseBasis\",\"softwareRasterization\",\"version\",\"packageFiles\",\"platformPrerequisites\"],\"type\":\"object\"}\n";

const STREAM_REFERENCE_PNG_OBJECT_V1_DOCUMENT = "{\"encoding\":\"BINARY_EXACT\",\"formatId\":\"IANA:image/png\",\"meaning\":\"Full PNG capture object. Byte identity and independently attested full retrieval are distinct from semantic PNG decoding, performed by the capture/offline validator.\",\"name\":\"STREAM_REFERENCE_PNG_OBJECT_V1\",\"version\":1}\n";

const STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1_DOCUMENT = "{\"encoding\":\"BINARY_EXACT\",\"formatId\":\"IANA:application/zip\",\"meaning\":\"Full runnable native browser/toolchain ZIP. Whole object coverage never substitutes an inventory descriptor; package execution and containment are independently checked offline and attributed by the original curator.\",\"name\":\"STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1\",\"version\":1}\n";

const STREAM_REFERENCE_NATIVE_FORMATS_V1_DOCUMENT = "{\"entries\":[{\"id\":\"IANA:application/zip\",\"mediaType\":\"application/zip\",\"objectSchema\":\"STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1\"},{\"id\":\"IANA:image/png\",\"mediaType\":\"image/png\",\"objectSchema\":\"STREAM_REFERENCE_PNG_OBJECT_V1\"}],\"meaning\":\"Exact media-type interpretation labels, not a claim that format identification or all runtime dependencies were proved onchain.\",\"name\":\"STREAM_REFERENCE_NATIVE_FORMATS_V1\",\"version\":1}\n";

export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_SCHEMA_HASH = "0x613048a84803f3c00cd6df4016029d02bd1464d27192c9102d820d2da4524a51" as Hex;

export const TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_CANONICALIZATION_HASH = "0x9a5b21a4397b2be60a25f467250ccb4a0b818d776819c48b24925e82eef2cc21" as Hex;

function definition(documentId: Hex, documentKind: 0n | 1n | 2n, text: string): TokenPreservationReferenceV2Definition {
  const raw = toUtf8Bytes(text);
  return Object.freeze({ id: documentId, kind: documentKind, hash: keccak256(raw) as Hex, byteLength: BigInt(raw.length), data: ("0x" + Array.from(raw, byte => byte.toString(16).padStart(2, "0")).join("")) as Hex });
}
const COLLECTION_DEFINITIONS = Object.freeze([
  definition(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_SCHEMA_ID, 0n, COLLECTION_SCHEMA_DOCUMENT),
  definition(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_PROFILE_ID, 2n, COLLECTION_PROFILE_DOCUMENT),
  definition(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_CANONICALIZATION_ID, 1n, COLLECTION_CANONICALIZATION_DOCUMENT),
  definition(id("STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1") as Hex, 0n, STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1_DOCUMENT),
  definition(id("STREAM_REFERENCE_PNG_OBJECT_V1") as Hex, 0n, STREAM_REFERENCE_PNG_OBJECT_V1_DOCUMENT),
  definition(id("STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1") as Hex, 0n, STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1_DOCUMENT),
  definition(id("STREAM_REFERENCE_NATIVE_FORMATS_V1") as Hex, 2n, STREAM_REFERENCE_NATIVE_FORMATS_V1_DOCUMENT)
]);
const SCOPED_DEFINITIONS = Object.freeze([
  definition(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_SCHEMA_ID, 0n, SCOPED_SCHEMA_DOCUMENT),
  definition(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_PROFILE_ID, 2n, SCOPED_PROFILE_DOCUMENT),
  definition(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_CANONICALIZATION_ID, 1n, SCOPED_CANONICALIZATION_DOCUMENT),
  definition(id("STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1") as Hex, 0n, STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1_DOCUMENT),
  definition(id("STREAM_REFERENCE_PNG_OBJECT_V1") as Hex, 0n, STREAM_REFERENCE_PNG_OBJECT_V1_DOCUMENT),
  definition(id("STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1") as Hex, 0n, STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1_DOCUMENT),
  definition(id("STREAM_REFERENCE_NATIVE_FORMATS_V1") as Hex, 2n, STREAM_REFERENCE_NATIVE_FORMATS_V1_DOCUMENT)
]);
/** Seven exact original ACTIVE RAW_BYTES definitions; source availability is checked by workflows. */
export function tokenPreservationReferenceV2Definitions(scopeKind: TokenPreservationReferenceV2ScopeKind): readonly TokenPreservationReferenceV2Definition[] {
  return kind(scopeKind) === "collection" ? COLLECTION_DEFINITIONS : SCOPED_DEFINITIONS;
}

export function normalizeTokenPreservationReferenceV2Scope(
  value: TokenPreservationReferenceV2Scope,
): TokenPreservationReferenceV2Scope {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_SCOPE_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2Scope(
  value: TokenPreservationReferenceV2Scope,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_SCOPE_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2Scope(
  value: Hex,
): TokenPreservationReferenceV2Scope {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_SCOPE_TUPLE, value);
}

export function normalizeTokenPreservationReferenceV2Environment(
  value: TokenPreservationReferenceV2Environment,
): TokenPreservationReferenceV2Environment {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_ENVIRONMENT_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2Environment(
  value: TokenPreservationReferenceV2Environment,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_ENVIRONMENT_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2Environment(
  value: Hex,
): TokenPreservationReferenceV2Environment {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_ENVIRONMENT_TUPLE, value);
}

export function normalizeTokenPreservationReferenceV2PackageFile(
  value: TokenPreservationReferenceV2PackageFile,
): TokenPreservationReferenceV2PackageFile {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_PACKAGE_FILE_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2PackageFile(
  value: TokenPreservationReferenceV2PackageFile,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_PACKAGE_FILE_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2PackageFile(
  value: Hex,
): TokenPreservationReferenceV2PackageFile {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_PACKAGE_FILE_TUPLE, value);
}

export function normalizeTokenPreservationReferenceV2ObservationPublication(
  value: TokenPreservationReferenceV2ObservationPublication,
): TokenPreservationReferenceV2ObservationPublication {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_OBSERVATION_PUBLICATION_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2ObservationPublication(
  value: TokenPreservationReferenceV2ObservationPublication,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_OBSERVATION_PUBLICATION_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2ObservationPublication(
  value: Hex,
): TokenPreservationReferenceV2ObservationPublication {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_OBSERVATION_PUBLICATION_TUPLE, value);
}

export function normalizeTokenPreservationReferenceV2ObservationReceipt(
  value: TokenPreservationReferenceV2ObservationReceipt,
): TokenPreservationReferenceV2ObservationReceipt {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_OBSERVATION_RECEIPT_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2ObservationReceipt(
  value: TokenPreservationReferenceV2ObservationReceipt,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_OBSERVATION_RECEIPT_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2ObservationReceipt(
  value: Hex,
): TokenPreservationReferenceV2ObservationReceipt {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_OBSERVATION_RECEIPT_TUPLE, value);
}

export function normalizeTokenPreservationReferenceV2SampleFacts(
  value: TokenPreservationReferenceV2SampleFacts,
): TokenPreservationReferenceV2SampleFacts {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_SAMPLE_FACTS_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2SampleFacts(
  value: TokenPreservationReferenceV2SampleFacts,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_SAMPLE_FACTS_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2SampleFacts(
  value: Hex,
): TokenPreservationReferenceV2SampleFacts {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_SAMPLE_FACTS_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2Capture(
  value: TokenPreservationReferenceV2Capture,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_CAPTURE_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2Capture(
  value: Hex,
): TokenPreservationReferenceV2Capture {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_CAPTURE_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2Coverage(
  value: TokenPreservationReferenceV2Coverage,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_COVERAGE_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2Coverage(
  value: Hex,
): TokenPreservationReferenceV2Coverage {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_COVERAGE_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2Sample(
  value: TokenPreservationReferenceV2Sample,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_SAMPLE_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2Sample(
  value: Hex,
): TokenPreservationReferenceV2Sample {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_SAMPLE_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2Lock(
  value: TokenPreservationReferenceV2Lock,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_LOCK_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2Lock(
  value: Hex,
): TokenPreservationReferenceV2Lock {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_LOCK_TUPLE, value);
}

export function normalizeTokenPreservationReferenceV2CollectionRootRecord(
  value: TokenPreservationReferenceV2CollectionRootRecord,
): TokenPreservationReferenceV2CollectionRootRecord {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ROOT_RECORD_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2CollectionRootRecord(
  value: TokenPreservationReferenceV2CollectionRootRecord,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ROOT_RECORD_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2CollectionRootRecord(
  value: Hex,
): TokenPreservationReferenceV2CollectionRootRecord {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ROOT_RECORD_TUPLE, value);
}

export function normalizeTokenPreservationReferenceV2CollectionRootBinding(
  value: TokenPreservationReferenceV2CollectionRootBinding,
): TokenPreservationReferenceV2CollectionRootBinding {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ROOT_BINDING_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2CollectionRootBinding(
  value: TokenPreservationReferenceV2CollectionRootBinding,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ROOT_BINDING_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2CollectionRootBinding(
  value: Hex,
): TokenPreservationReferenceV2CollectionRootBinding {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_ROOT_BINDING_TUPLE, value);
}

export function normalizeTokenPreservationReferenceV2ScopedRootRecord(
  value: TokenPreservationReferenceV2ScopedRootRecord,
): TokenPreservationReferenceV2ScopedRootRecord {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_RECORD_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2ScopedRootRecord(
  value: TokenPreservationReferenceV2ScopedRootRecord,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_RECORD_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2ScopedRootRecord(
  value: Hex,
): TokenPreservationReferenceV2ScopedRootRecord {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_RECORD_TUPLE, value);
}

export function normalizeTokenPreservationReferenceV2ScopedRootBinding(
  value: TokenPreservationReferenceV2ScopedRootBinding,
): TokenPreservationReferenceV2ScopedRootBinding {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_BINDING_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2ScopedRootBinding(
  value: TokenPreservationReferenceV2ScopedRootBinding,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_BINDING_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2ScopedRootBinding(
  value: Hex,
): TokenPreservationReferenceV2ScopedRootBinding {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_BINDING_TUPLE, value);
}

export function normalizeTokenPreservationReferenceV2CollectionSource(
  value: TokenPreservationReferenceV2CollectionSource,
): TokenPreservationReferenceV2CollectionSource {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_SOURCE_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2CollectionSource(
  value: TokenPreservationReferenceV2CollectionSource,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_SOURCE_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2CollectionSource(
  value: Hex,
): TokenPreservationReferenceV2CollectionSource {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_COLLECTION_SOURCE_TUPLE, value);
}

export function normalizeTokenPreservationReferenceV2ScopedSource(
  value: TokenPreservationReferenceV2ScopedSource,
): TokenPreservationReferenceV2ScopedSource {
  return normalized(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_SOURCE_TUPLE, value);
}

export function encodeTokenPreservationReferenceV2ScopedSource(
  value: TokenPreservationReferenceV2ScopedSource,
): Hex {
  return encode(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_SOURCE_TUPLE, value);
}

export function decodeTokenPreservationReferenceV2ScopedSource(
  value: Hex,
): TokenPreservationReferenceV2ScopedSource {
  return decode(TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_SOURCE_TUPLE, value);
}
