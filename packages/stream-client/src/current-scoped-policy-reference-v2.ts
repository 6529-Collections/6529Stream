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
import * as snapshot from "./current-scoped-policy-publication-v2.js";
import * as root from "./current-scoped-policy-root-v2.js";

/** Original ABI129 scoped BYTE_EXACT observation profile. No renderer execution or authority is proved here. */
export const SCOPED_POLICY_REFERENCE_V2_SOURCE = "896899f7ca4130f86e066587f780a3b1f755a25d";
export const SCOPED_POLICY_REFERENCE_V2_PROFILE = id("6529STREAM_SCOPED_POLICY_REFERENCE_V2") as Hex;
export const SCOPED_POLICY_REFERENCE_V2_SCHEMA = id("STREAM_SCOPED_POLICY_REFERENCE_ABI_V2") as Hex;
export const SCOPED_POLICY_REFERENCE_V2_PROFILE_DOCUMENT = id("STREAM_SCOPED_POLICY_REFERENCE_PROFILE_V2") as Hex;
export const SCOPED_POLICY_REFERENCE_V2_CANONICALIZATION = id("STREAM_ABI_SCOPED_POLICY_REFERENCE_V2") as Hex;
export const SCOPED_POLICY_REFERENCE_V2_SCHEMA_HASH = "0x66d9b03f9b6c4aa37c55df3f47a5d21a964a419bd93a83130bbf0487a0a26715" as Hex;
export const SCOPED_POLICY_REFERENCE_V2_PROFILE_HASH = "0x4351690bd9597070d7de6a17071c7103d46a52efc757954a567fe542ecb64a47" as Hex;
export const SCOPED_POLICY_REFERENCE_V2_CANONICALIZATION_HASH = "0xfd2a277aa777a57d09d19665f0c73a2a9ace95f4fa3c3b9b8340917e53c79028" as Hex;
export const SCOPED_POLICY_REFERENCE_V2_SCHEMA_BYTES = 26018n;
export const SCOPED_POLICY_REFERENCE_V2_PROFILE_BYTES = 2114n;
export const SCOPED_POLICY_REFERENCE_V2_CANONICALIZATION_BYTES = 1412n;
export const SCOPED_POLICY_REFERENCE_V2_MAX_BYTES = 524288;
export const SCOPED_POLICY_REFERENCE_V2_PART_ROWS = 64;
export const SCOPED_POLICY_REFERENCE_V2_MAX_HTML_BYTES = 40960;
/** Client allocation bounds, distinct from each original retained-byte limit. */
export const SCOPED_POLICY_REFERENCE_V2_MAX_CALL_BYTES = 2097152;
export const SCOPED_POLICY_REFERENCE_V2_MAX_ARRAY_ROWS = 8192;

export type ScopedPolicyReferenceV2Scope = graph.ScopedPolicyGraphV2Scope;
export type ScopedPolicyReferenceV2Environment = ReferenceEnvironment;
export type ScopedPolicyReferenceV2PackageFile = ReferenceInventoryPackageFile;
export type ScopedPolicyReferenceV2Lock = snapshot.ScopedPolicyPublicationV2Lock;

export interface ScopedPolicyReferenceV2Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly metadata: Address;
  readonly reference: Address;
}

export interface ScopedPolicyReferenceV2Dependencies {
  readonly targets: readonly [Address, Address, Address, Address, Address, Address, Address];
  readonly codeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex, Hex];
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly snapshotGas: bigint;
  readonly archiveGas: bigint;
}

export interface ScopedPolicyReferenceV2Capture {
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

export interface ScopedPolicyReferenceV2ObservationPublication {
  readonly collectionId: bigint;
  readonly referenceId: Hex;
  readonly expectedHead: Hex;
  readonly expectedRevision: bigint;
  readonly snapshotRecordHash: Hex;
  readonly snapshotRevision: bigint;
  readonly expectedSourcesHash: Hex;
  readonly captures: readonly ScopedPolicyReferenceV2Capture[];
  readonly environment: ScopedPolicyReferenceV2Environment;
  readonly manifestURI: string;
  readonly effectiveAt: bigint;
  readonly reasonHash: Hex;
}

export interface ScopedPolicyReferenceV2Publication {
  readonly scope: ScopedPolicyReferenceV2Scope;
  readonly observation: ScopedPolicyReferenceV2ObservationPublication;
}

export interface ScopedPolicyReferenceV2ObservationReceipt {
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

export interface ScopedPolicyReferenceV2Receipt {
  readonly scopeSubject: Hex;
  readonly observation: ScopedPolicyReferenceV2ObservationReceipt;
}

export interface ScopedPolicyReferenceV2Coverage {
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

export interface ScopedPolicyReferenceV2SampleFacts {
  readonly tokenId: bigint;
  readonly collectionSerial: bigint;
  readonly originalCoordinator: Address;
  readonly seed: Hex;
  readonly tokenDataHash: Hex;
  readonly tokenDataBytes: bigint;
  readonly metadataJSONHash: Hex;
  readonly htmlHash: Hex;
  readonly htmlBytes: bigint;
  readonly captureCoverage: ScopedPolicyReferenceV2Coverage;
}

export interface ScopedPolicyReferenceV2Sample {
  readonly membershipIndex: bigint;
  readonly observation: ScopedPolicyReferenceV2SampleFacts;
  readonly selection: snapshot.ScopedPolicyPublicationV2TokenSelection;
  readonly entropy: snapshot.ScopedPolicyPublicationV2TokenReadiness;
  readonly terminalAdmissionHash: Hex;
}

export interface ScopedPolicyReferenceV2SourceFacts {
  readonly scopeSubject: Hex;
  readonly snapshot: snapshot.ScopedPolicyPublicationV2Receipt;
  readonly snapshotSource: snapshot.ScopedPolicyPublicationV2Source;
  readonly contentRootRecordHash: Hex;
  readonly contentRoot: root.ScopedPolicyRootV2Record;
  readonly contentRootBinding: root.ScopedPolicyRootV2Binding;
  readonly environmentCoverage: ScopedPolicyReferenceV2Coverage;
  readonly samples: readonly ScopedPolicyReferenceV2Sample[];
}

export const SCOPED_POLICY_REFERENCE_V2_SCOPE_TUPLE = graph.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE;
export const SCOPED_POLICY_REFERENCE_V2_ENVIRONMENT_TUPLE = REFERENCE_ENVIRONMENT_ABI_TUPLE;
export const SCOPED_POLICY_REFERENCE_V2_PACKAGE_FILE_TUPLE = "tuple(string path,uint64 byteSize,bytes32 sha256Digest)";
export const SCOPED_POLICY_REFERENCE_V2_DEPENDENCIES_TUPLE = "tuple(address[7] targets,bytes32[7] codeHashes,uint256 chainId,uint256 readGas,uint256 sourceGas,uint256 snapshotGas,uint256 archiveGas)";
export const SCOPED_POLICY_REFERENCE_V2_CAPTURE_TUPLE = "tuple(uint256 tokenId,uint256 collectionSerial,bytes32 metadataJSONHash,bytes32 htmlHash,uint32 htmlBytes,bytes animationHTML,bytes32 objectHash,bytes32 coverageHash,bytes32 sourceSha256,bytes32[2] repeatCaptureSha256,bytes32 environmentManifestHash,uint64 capturedAt)";
export const SCOPED_POLICY_REFERENCE_V2_OBSERVATION_PUBLICATION_TUPLE = `tuple(uint256 collectionId,bytes32 referenceId,bytes32 expectedHead,uint64 expectedRevision,bytes32 snapshotRecordHash,uint64 snapshotRevision,bytes32 expectedSourcesHash,${SCOPED_POLICY_REFERENCE_V2_CAPTURE_TUPLE}[] captures,${SCOPED_POLICY_REFERENCE_V2_ENVIRONMENT_TUPLE} environment,string manifestURI,uint64 effectiveAt,bytes32 reasonHash)`;
export const SCOPED_POLICY_REFERENCE_V2_PUBLICATION_TUPLE = `tuple(${SCOPED_POLICY_REFERENCE_V2_SCOPE_TUPLE} scope,${SCOPED_POLICY_REFERENCE_V2_OBSERVATION_PUBLICATION_TUPLE} observation)`;
export const SCOPED_POLICY_REFERENCE_V2_OBSERVATION_RECEIPT_TUPLE = "tuple(bytes32 recordHash,bytes32 recordChainHash,uint256 collectionId,bytes32 referenceId,bytes32 predecessor,uint64 revision,bytes32 payloadHash,uint32 payloadBytes,bytes32 sourcesHash,bytes32 snapshotRecordHash,uint64 snapshotRevision,address recorder,uint8 authorizationClass,uint64 grantRevision,uint64 effectiveAt,uint64 recordedAt,bytes32 reasonHash,bytes32 schemaHash,bytes32 profileHash,bytes32 canonicalizationHash)";
export const SCOPED_POLICY_REFERENCE_V2_RECEIPT_TUPLE = `tuple(bytes32 scopeSubject,${SCOPED_POLICY_REFERENCE_V2_OBSERVATION_RECEIPT_TUPLE} observation)`;
export const SCOPED_POLICY_REFERENCE_V2_COVERAGE_TUPLE = "tuple(bytes32 coverageHash,bytes32 objectHash,bytes32 artistId,bytes32 contentHash,bytes32 sha256Digest,bytes32 arweaveDataRoot,uint64 byteSize,bytes32 firstFamilyRecordHash,bytes32 secondFamilyRecordHash,bytes32 firstReceiptHash,bytes32 secondReceiptHash,bytes32 firstFixityHash,bytes32 secondFixityHash,bytes32 checkpointHash,bytes32 profileHash)";
export const SCOPED_POLICY_REFERENCE_V2_SAMPLE_FACTS_TUPLE = `tuple(uint256 tokenId,uint256 collectionSerial,address originalCoordinator,bytes32 seed,bytes32 tokenDataHash,uint32 tokenDataBytes,bytes32 metadataJSONHash,bytes32 htmlHash,uint32 htmlBytes,${SCOPED_POLICY_REFERENCE_V2_COVERAGE_TUPLE} captureCoverage)`;
export const SCOPED_POLICY_REFERENCE_V2_SAMPLE_TUPLE = `tuple(uint64 membershipIndex,${SCOPED_POLICY_REFERENCE_V2_SAMPLE_FACTS_TUPLE} observation,${snapshot.SCOPED_POLICY_PUBLICATION_V2_TOKEN_SELECTION_TUPLE} selection,${snapshot.SCOPED_POLICY_PUBLICATION_V2_TOKEN_READINESS_TUPLE} entropy,bytes32 terminalAdmissionHash)`;
export const SCOPED_POLICY_REFERENCE_V2_SOURCE_FACTS_TUPLE = `tuple(bytes32 scopeSubject,${snapshot.SCOPED_POLICY_PUBLICATION_V2_RECEIPT_TUPLE} snapshot,${snapshot.SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE} snapshotSource,bytes32 contentRootRecordHash,${root.SCOPED_POLICY_ROOT_V2_RECORD_TUPLE} contentRoot,${root.SCOPED_POLICY_ROOT_V2_BINDING_TUPLE} contentRootBinding,${SCOPED_POLICY_REFERENCE_V2_COVERAGE_TUPLE} environmentCoverage,${SCOPED_POLICY_REFERENCE_V2_SAMPLE_TUPLE}[] samples)`;
export const SCOPED_POLICY_REFERENCE_V2_LOCK_TUPLE = snapshot.SCOPED_POLICY_PUBLICATION_V2_LOCK_TUPLE;
export const SCOPED_POLICY_REFERENCE_V2_PAYLOAD_TYPES = Object.freeze([
  "bytes32", "uint256", "address", SCOPED_POLICY_REFERENCE_V2_PUBLICATION_TUPLE,
  SCOPED_POLICY_REFERENCE_V2_RECEIPT_TUPLE, SCOPED_POLICY_REFERENCE_V2_SOURCE_FACTS_TUPLE, "bytes",
]);

export interface ScopedPolicyReferenceV2Document {
  readonly id: Hex;
  readonly kind: 0n | 1n | 2n;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
}

/** Exact seven ACTIVE RAW_BYTES documents read by the original reference producer. */
export const SCOPED_POLICY_REFERENCE_V2_DOCUMENTS: readonly ScopedPolicyReferenceV2Document[] = Object.freeze([
  { id: SCOPED_POLICY_REFERENCE_V2_SCHEMA, kind: 0n, contentHash: SCOPED_POLICY_REFERENCE_V2_SCHEMA_HASH, byteLength: 26018n },
  { id: SCOPED_POLICY_REFERENCE_V2_PROFILE_DOCUMENT, kind: 2n, contentHash: SCOPED_POLICY_REFERENCE_V2_PROFILE_HASH, byteLength: 2114n },
  { id: SCOPED_POLICY_REFERENCE_V2_CANONICALIZATION, kind: 1n, contentHash: SCOPED_POLICY_REFERENCE_V2_CANONICALIZATION_HASH, byteLength: 1412n },
  { id: id("STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1") as Hex, kind: 0n, contentHash: "0xe09ea65b22dccf9a9528b0ec4c940a831be48a060f0a095157a65aff5b290b90" as Hex, byteLength: 2236n },
  { id: id("STREAM_REFERENCE_PNG_OBJECT_V1") as Hex, kind: 0n, contentHash: "0x06dacccbad9218d04f77cbfdd597dfa61e2cab5b58c0fb8f5a1344ce301cb489" as Hex, byteLength: 286n },
  { id: id("STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1") as Hex, kind: 0n, contentHash: "0xb3cedd289be34a31fcd20d1941c86e28f31723e4c61f11ddf87894cda4903cac" as Hex, byteLength: 351n },
  { id: id("STREAM_REFERENCE_NATIVE_FORMATS_V1") as Hex, kind: 2n, contentHash: "0x91a426d25d6e00c056cea336611731171bfe84e1b90bf10f7e2e0d0edc6d8c03" as Hex, byteLength: 422n },
].map(value => Object.freeze(value as ScopedPolicyReferenceV2Document)));

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

function bytes(value: unknown, fixed?: number, maximum = SCOPED_POLICY_REFERENCE_V2_MAX_CALL_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, fixed ?? true)
    || (value.length - 2) / 2 > maximum) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}

function nonzero(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === ZERO) throw Error("Expected nonzero commitment");
  return result;
}

function text(value: unknown, maximum = SCOPED_POLICY_REFERENCE_V2_MAX_BYTES): string {
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
    const rows = list(decoded ? Array.from(value as readonly unknown[]) : value, SCOPED_POLICY_REFERENCE_V2_MAX_ARRAY_ROWS,
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

function encode(tuple: string, value: unknown, maximum = SCOPED_POLICY_REFERENCE_V2_MAX_BYTES): Hex {
  return bytes(coder.encode([tuple], [normalized(tuple, value)]), undefined, maximum);
}

function decode<T>(tuple: string, value: Hex, maximum = SCOPED_POLICY_REFERENCE_V2_MAX_BYTES): T {
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

export function normalizeScopedPolicyReferenceV2Coordinates(value: ScopedPolicyReferenceV2Coordinates): ScopedPolicyReferenceV2Coordinates {
  exact(value, ["chainId", "core", "metadata", "reference"], "Coordinates");
  return Object.freeze({ chainId: uint(value.chainId), core: address(value.core, true),
    metadata: address(value.metadata, true), reference: address(value.reference, true) });
}

/** Structural codecs preserve empty historical getter values; admission checks are separate. */
export function normalizeScopedPolicyReferenceV2Dependencies(value: ScopedPolicyReferenceV2Dependencies): ScopedPolicyReferenceV2Dependencies {
  return normalized(SCOPED_POLICY_REFERENCE_V2_DEPENDENCIES_TUPLE, value);
}
export function encodeScopedPolicyReferenceV2Dependencies(value: ScopedPolicyReferenceV2Dependencies): Hex {
  return encode(SCOPED_POLICY_REFERENCE_V2_DEPENDENCIES_TUPLE, value);
}
export function decodeScopedPolicyReferenceV2Dependencies(value: Hex): ScopedPolicyReferenceV2Dependencies {
  return decode(SCOPED_POLICY_REFERENCE_V2_DEPENDENCIES_TUPLE, value);
}
export function normalizeScopedPolicyReferenceV2Publication(value: ScopedPolicyReferenceV2Publication): ScopedPolicyReferenceV2Publication {
  return normalized(SCOPED_POLICY_REFERENCE_V2_PUBLICATION_TUPLE, value);
}
export function encodeScopedPolicyReferenceV2Publication(value: ScopedPolicyReferenceV2Publication): Hex {
  return encode(SCOPED_POLICY_REFERENCE_V2_PUBLICATION_TUPLE, value);
}
export function decodeScopedPolicyReferenceV2Publication(value: Hex): ScopedPolicyReferenceV2Publication {
  return decode(SCOPED_POLICY_REFERENCE_V2_PUBLICATION_TUPLE, value);
}
export function normalizeScopedPolicyReferenceV2Receipt(value: ScopedPolicyReferenceV2Receipt): ScopedPolicyReferenceV2Receipt {
  return normalized(SCOPED_POLICY_REFERENCE_V2_RECEIPT_TUPLE, value);
}
export function encodeScopedPolicyReferenceV2Receipt(value: ScopedPolicyReferenceV2Receipt): Hex {
  return encode(SCOPED_POLICY_REFERENCE_V2_RECEIPT_TUPLE, value);
}
export function decodeScopedPolicyReferenceV2Receipt(value: Hex): ScopedPolicyReferenceV2Receipt {
  return decode(SCOPED_POLICY_REFERENCE_V2_RECEIPT_TUPLE, value);
}
export function normalizeScopedPolicyReferenceV2SourceFacts(value: ScopedPolicyReferenceV2SourceFacts): ScopedPolicyReferenceV2SourceFacts {
  return normalized(SCOPED_POLICY_REFERENCE_V2_SOURCE_FACTS_TUPLE, value);
}
export function encodeScopedPolicyReferenceV2SourceFacts(value: ScopedPolicyReferenceV2SourceFacts): Hex {
  return encode(SCOPED_POLICY_REFERENCE_V2_SOURCE_FACTS_TUPLE, value);
}
export function decodeScopedPolicyReferenceV2SourceFacts(value: Hex): ScopedPolicyReferenceV2SourceFacts {
  return decode(SCOPED_POLICY_REFERENCE_V2_SOURCE_FACTS_TUPLE, value);
}
export function normalizeScopedPolicyReferenceV2Capture(value: ScopedPolicyReferenceV2Capture): ScopedPolicyReferenceV2Capture {
  return normalized(SCOPED_POLICY_REFERENCE_V2_CAPTURE_TUPLE, value);
}
export function normalizeScopedPolicyReferenceV2Coverage(value: ScopedPolicyReferenceV2Coverage): ScopedPolicyReferenceV2Coverage {
  return normalized(SCOPED_POLICY_REFERENCE_V2_COVERAGE_TUPLE, value);
}
export function normalizeScopedPolicyReferenceV2Sample(value: ScopedPolicyReferenceV2Sample): ScopedPolicyReferenceV2Sample {
  return normalized(SCOPED_POLICY_REFERENCE_V2_SAMPLE_TUPLE, value);
}
export function normalizeScopedPolicyReferenceV2Lock(value: ScopedPolicyReferenceV2Lock): ScopedPolicyReferenceV2Lock {
  return normalized(SCOPED_POLICY_REFERENCE_V2_LOCK_TUPLE, value);
}

export function validateScopedPolicyReferenceV2Dependencies(
  coordinates: ScopedPolicyReferenceV2Coordinates,
  value: ScopedPolicyReferenceV2Dependencies,
): ScopedPolicyReferenceV2Dependencies {
  const c = normalizeScopedPolicyReferenceV2Coordinates(coordinates);
  const d = normalizeScopedPolicyReferenceV2Dependencies(value);
  if (d.chainId !== c.chainId || d.targets[0] !== c.core || d.targets[1] !== c.metadata
    || d.readGas < 50000n || d.sourceGas < d.readGas || d.snapshotGas < d.sourceGas || d.archiveGas < d.readGas) throw Error("Invalid original reference dependencies");
  for (let i = 0; i < 7; i++) { address(d.targets[i], true); nonzero(d.codeHashes[i]); }
  return d;
}

/** `preview` admits the original zero expectedSourcesHash draft, while `publish` requires its commitment. */
export function validateScopedPolicyReferenceV2Publication(
  value: ScopedPolicyReferenceV2Publication,
  mode: "preview" | "publish",
): ScopedPolicyReferenceV2Publication {
  if (mode !== "preview" && mode !== "publish") throw Error("Unknown publication mode");
  const p = normalizeScopedPolicyReferenceV2Publication(value);
  const scope = graph.validateScopedPolicyGraphV2Scope(p.scope);
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
    const html = bytes(capture.animationHTML, undefined, SCOPED_POLICY_REFERENCE_V2_MAX_HTML_BYTES);
    if (html === "0x" || capture.htmlBytes !== BigInt((html.length - 2) / 2)
      || keccak256(html) !== capture.htmlHash || sha256(html) !== capture.sourceSha256
      || capture.capturedAt === 0n || capture.tokenId === 0n || capture.collectionSerial === 0n
      || capture.environmentManifestHash !== environment.manifestHash
      || capture.repeatCaptureSha256[0] !== capture.repeatCaptureSha256[1]) throw Error("Invalid original capture");
    nonzero(capture.repeatCaptureSha256[0]); nonzero(capture.objectHash); nonzero(capture.coverageHash);
  }
  // The original complete ABI Publication is retained independently from the canonical payload.
  encodeScopedPolicyReferenceV2Publication(p);
  return p;
}

/** Checks source-visible joins in supplied facts, not renderer execution, archive fixity or live authority. */
export function validateScopedPolicyReferenceV2Source(
  coordinates: ScopedPolicyReferenceV2Coordinates,
  dependencies: ScopedPolicyReferenceV2Dependencies,
  publication: ScopedPolicyReferenceV2Publication,
  source: ScopedPolicyReferenceV2SourceFacts,
  snapshotDependencies: graph.ScopedPolicyGraphV2SnapshotDependencies,
): ScopedPolicyReferenceV2SourceFacts {
  const c = normalizeScopedPolicyReferenceV2Coordinates(coordinates);
  const d = validateScopedPolicyReferenceV2Dependencies(c, dependencies);
  const p = validateScopedPolicyReferenceV2Publication(publication, "preview");
  const f = normalizeScopedPolicyReferenceV2SourceFacts(source);
  const sd = graph.normalizeScopedPolicyGraphV2SnapshotDependencies(snapshotDependencies);
  if (sd.chainId !== c.chainId || d.targets.slice(0, 5).some((target, i) =>
    target !== sd.targets[i] || d.codeHashes[i] !== sd.codeHashes[i])) throw Error("Snapshot dependency identity differs");
  const subject = graph.scopedPolicyGraphV2ScopeSubject(c.chainId, c.core, p.scope);
  const s = f.snapshotSource;
  const r = f.contentRoot;
  const count = s.membership.tokenCount;
  if (f.scopeSubject !== subject || f.snapshot.scopeSubject !== subject || s.membership.scopeSubject !== subject
    || !same(SCOPED_POLICY_REFERENCE_V2_SCOPE_TUPLE, s.scope, p.scope)
    || !same(SCOPED_POLICY_REFERENCE_V2_SCOPE_TUPLE, r.publication.scope, p.scope)
    || f.snapshot.recordHash !== p.observation.snapshotRecordHash || f.snapshot.revision !== p.observation.snapshotRevision
    || count === 0n || count >= 1n << 64n || f.samples.length !== (count === 1n ? 1 : 2)
    || f.samples.length !== p.observation.captures.length) throw Error("Source scope, snapshot or sample count differs");
  const snapshotSourceHash = hash(["bytes32", "uint256", "address", "address[11]", "bytes32[11]",
    snapshot.SCOPED_POLICY_PUBLICATION_V2_SOURCE_TUPLE], [id("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"),
    c.chainId, d.targets[5], sd.targets, sd.codeHashes, s]);
  if (f.snapshot.sourceHash !== snapshotSourceHash) throw Error("Original snapshot source commitment differs");
  const expectedBinding = root.scopedPolicyRootV2BindingFromSnapshot(sd, s, f.snapshot);
  if (!same(root.SCOPED_POLICY_ROOT_V2_BINDING_TUPLE, f.contentRootBinding, expectedBinding)
    || r.publication.snapshotRecordHash !== f.snapshot.recordHash || r.publication.snapshotRevision !== f.snapshot.revision
    || r.snapshotHost !== d.targets[5] || r.snapshotCodeHash !== d.codeHashes[5]
    || r.snapshotManifestHash !== f.snapshot.manifestHash || r.snapshotSourceHash !== f.snapshot.sourceHash
    || r.contentRoot !== s.outputs.contentRoot || r.leafCount !== count
    || r.outputManifestHash !== s.outputs.manifestHash || r.artistId !== s.artist.artistId
    || r.bindingGeneration !== s.artist.bindingGeneration || r.bindingHash !== s.artist.bindingHash
    || (r.authorizationClass !== 7n && r.authorizationClass !== 8n) || r.grantRevision === 0n || r.publishedAt === 0n) {
    throw Error("Original content root and full policy binding differ");
  }
  address(r.publisher, true);
  for (const word of [f.contentRootRecordHash, r.contentRoot, r.routeHash, r.stateHash, r.artistConsent]) nonzero(word);
  const rootState = hash(["bytes32", "uint256", "address", "address", root.SCOPED_POLICY_ROOT_V2_RECORD_TUPLE,
    root.SCOPED_POLICY_ROOT_V2_BINDING_TUPLE], [id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_STATE_V2"), c.chainId,
    d.targets[4], c.core, { ...r, stateHash: ZERO, artistConsent: ZERO, publishedAt: 0n }, f.contentRootBinding]);
  if (rootState !== r.stateHash) throw Error("Original root state commitment differs");
  const environment = p.observation.environment;
  if (f.environmentCoverage.coverageHash !== environment.coverageHash
    || f.environmentCoverage.objectHash !== environment.objectHash
    || f.environmentCoverage.artistId !== s.artist.artistId) throw Error("Environment coverage identity differs");
  for (let i = 0; i < f.samples.length; i++) {
    const sample = f.samples[i]!;
    const capture = p.observation.captures[i]!;
    const facts = sample.observation;
    const entropy = sample.entropy;
    if (sample.membershipIndex !== (i === 0 ? 0n : count - 1n)
      || facts.tokenId !== capture.tokenId || facts.collectionSerial !== capture.collectionSerial
      || sample.selection.tokenId !== capture.tokenId || facts.originalCoordinator !== sample.selection.sources[3]
      || entropy.coordinator !== facts.originalCoordinator || entropy.coordinatorCodeHash !== sample.selection.sourceCodeHashes[3]
      || facts.seed !== entropy.seed || facts.tokenDataBytes > 16384n
      || facts.metadataJSONHash !== capture.metadataJSONHash || facts.htmlHash !== capture.htmlHash
      || facts.htmlBytes !== capture.htmlBytes || facts.captureCoverage.coverageHash !== capture.coverageHash
      || facts.captureCoverage.objectHash !== capture.objectHash || facts.captureCoverage.artistId !== s.artist.artistId
      || facts.captureCoverage.sha256Digest !== capture.repeatCaptureSha256[0]) throw Error("Sample order, content or coverage differs");
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

export interface ScopedPolicyReferenceV2Authority {
  readonly authorizationClass: 3n | 8n;
  readonly grantRevision: bigint;
}

export function scopedPolicyReferenceV2PreviewReceipt(
  coordinates: ScopedPolicyReferenceV2Coordinates,
  publication: ScopedPolicyReferenceV2Publication,
  recorder: Address,
  authority: ScopedPolicyReferenceV2Authority,
  sourceHash: Hex,
): ScopedPolicyReferenceV2Receipt {
  const c = normalizeScopedPolicyReferenceV2Coordinates(coordinates);
  const p = validateScopedPolicyReferenceV2Publication(publication, "preview");
  exact(authority, ["authorizationClass", "grantRevision"], "Authority");
  if ((authority.authorizationClass !== 3n && authority.authorizationClass !== 8n)
    || uint(authority.grantRevision, 64) === 0n) throw Error("Expected original CURATOR class 3 or 8 grant");
  const o = p.observation;
  return normalizeScopedPolicyReferenceV2Receipt({
    scopeSubject: graph.scopedPolicyGraphV2ScopeSubject(c.chainId, c.core, p.scope),
    observation: {
      recordHash: ZERO, recordChainHash: ZERO, collectionId: o.collectionId, referenceId: o.referenceId,
      predecessor: o.expectedHead, revision: o.expectedRevision + 1n, payloadHash: ZERO, payloadBytes: 0n,
      sourcesHash: bytes(sourceHash, 32), snapshotRecordHash: o.snapshotRecordHash, snapshotRevision: o.snapshotRevision,
      recorder: address(recorder, true), authorizationClass: authority.authorizationClass, grantRevision: authority.grantRevision,
      effectiveAt: o.effectiveAt, recordedAt: 0n, reasonHash: o.reasonHash,
      schemaHash: SCOPED_POLICY_REFERENCE_V2_SCHEMA_HASH, profileHash: SCOPED_POLICY_REFERENCE_V2_PROFILE_HASH,
      canonicalizationHash: SCOPED_POLICY_REFERENCE_V2_CANONICALIZATION_HASH,
    },
  });
}

/** Structural preimage. Gas caps are deliberately not part of the original source hash. */
export function scopedPolicyReferenceV2SourceHash(
  coordinates: ScopedPolicyReferenceV2Coordinates,
  dependencies: ScopedPolicyReferenceV2Dependencies,
  source: ScopedPolicyReferenceV2SourceFacts,
): Hex {
  const c = normalizeScopedPolicyReferenceV2Coordinates(coordinates);
  const d = normalizeScopedPolicyReferenceV2Dependencies(dependencies);
  if (d.chainId !== c.chainId) throw Error("Source chain differs");
  return hash(["bytes32", "uint256", "address", "address[7]", "bytes32[7]", SCOPED_POLICY_REFERENCE_V2_SOURCE_FACTS_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_REFERENCE_SOURCES_V2"), c.chainId, c.reference, d.targets, d.codeHashes,
      normalizeScopedPolicyReferenceV2SourceFacts(source)]);
}

function canonicalPublication(p: ScopedPolicyReferenceV2Publication): ScopedPolicyReferenceV2Publication {
  return normalizeScopedPolicyReferenceV2Publication({ ...p, observation: { ...p.observation, expectedSourcesHash: ZERO } });
}

function canonicalReceipt(r: ScopedPolicyReferenceV2Receipt): ScopedPolicyReferenceV2Receipt {
  return normalizeScopedPolicyReferenceV2Receipt({ ...r, observation: { ...r.observation,
    recordHash: ZERO, recordChainHash: ZERO, payloadHash: ZERO, payloadBytes: 0n, recordedAt: 0n } });
}

/** Exact seven-field retained payload, clearing only the original one + five derived fields. */
export function scopedPolicyReferenceV2PayloadBytes(
  coordinates: ScopedPolicyReferenceV2Coordinates,
  publication: ScopedPolicyReferenceV2Publication,
  receipt: ScopedPolicyReferenceV2Receipt,
  source: ScopedPolicyReferenceV2SourceFacts,
  environmentBytes: Hex,
): Hex {
  const c = normalizeScopedPolicyReferenceV2Coordinates(coordinates);
  return bytes(coder.encode(SCOPED_POLICY_REFERENCE_V2_PAYLOAD_TYPES, [id("6529STREAM_SCOPED_POLICY_REFERENCE_PAYLOAD_V2"),
    c.chainId, c.reference, canonicalPublication(normalizeScopedPolicyReferenceV2Publication(publication)),
    canonicalReceipt(normalizeScopedPolicyReferenceV2Receipt(receipt)), normalizeScopedPolicyReferenceV2SourceFacts(source),
    bytes(environmentBytes, undefined, SCOPED_POLICY_REFERENCE_V2_MAX_BYTES)]), undefined, SCOPED_POLICY_REFERENCE_V2_MAX_BYTES);
}

export interface ScopedPolicyReferenceV2Payload {
  readonly chainId: bigint;
  readonly reference: Address;
  readonly publication: ScopedPolicyReferenceV2Publication;
  readonly receipt: ScopedPolicyReferenceV2Receipt;
  readonly source: ScopedPolicyReferenceV2SourceFacts;
  readonly environmentBytes: Hex;
}

/** Decodes the original tag and canonical ABI form; field admission and currentness are separate. */
export function decodeScopedPolicyReferenceV2Payload(raw: Hex): ScopedPolicyReferenceV2Payload {
  const input = bytes(raw, undefined, SCOPED_POLICY_REFERENCE_V2_MAX_BYTES);
  const values = coder.decode(SCOPED_POLICY_REFERENCE_V2_PAYLOAD_TYPES, input);
  if (values[0] !== id("6529STREAM_SCOPED_POLICY_REFERENCE_PAYLOAD_V2")
    || coder.encode(SCOPED_POLICY_REFERENCE_V2_PAYLOAD_TYPES, values) !== input) throw Error("Invalid scoped reference payload tag or canonical bytes");
  return Object.freeze({ chainId: uint(values[1]), reference: address(values[2]),
    publication: valueOf(ParamType.from(SCOPED_POLICY_REFERENCE_V2_PUBLICATION_TUPLE), values[3], true) as ScopedPolicyReferenceV2Publication,
    receipt: valueOf(ParamType.from(SCOPED_POLICY_REFERENCE_V2_RECEIPT_TUPLE), values[4], true) as ScopedPolicyReferenceV2Receipt,
    source: valueOf(ParamType.from(SCOPED_POLICY_REFERENCE_V2_SOURCE_FACTS_TUPLE), values[5], true) as ScopedPolicyReferenceV2SourceFacts,
    environmentBytes: bytes(values[6], undefined, SCOPED_POLICY_REFERENCE_V2_MAX_BYTES) });
}

export function scopedPolicyReferenceV2RecordHash(
  coordinates: ScopedPolicyReferenceV2Coordinates,
  publication: ScopedPolicyReferenceV2Publication,
  minedReceipt: ScopedPolicyReferenceV2Receipt,
): Hex {
  const c = normalizeScopedPolicyReferenceV2Coordinates(coordinates);
  const r = normalizeScopedPolicyReferenceV2Receipt(minedReceipt);
  return hash(["bytes32", "uint256", "address", "address", "address", SCOPED_POLICY_REFERENCE_V2_PUBLICATION_TUPLE,
    SCOPED_POLICY_REFERENCE_V2_RECEIPT_TUPLE], [id("6529STREAM_SCOPED_POLICY_REFERENCE_RECORD_V2"),
    c.chainId, c.reference, c.core, c.metadata, normalizeScopedPolicyReferenceV2Publication(publication),
    { ...r, observation: { ...r.observation, recordHash: ZERO, recordChainHash: ZERO } }]);
}

export function scopedPolicyReferenceV2ChainHash(
  coordinates: ScopedPolicyReferenceV2Coordinates,
  scope: ScopedPolicyReferenceV2Scope,
  previousChainHash: Hex,
  revision: bigint,
  recordHash: Hex,
): Hex {
  const c = normalizeScopedPolicyReferenceV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "uint64", "bytes32"],
    [id("6529STREAM_SCOPED_POLICY_REFERENCE_CHAIN_V2"), c.chainId, c.reference, c.core,
      graph.scopedPolicyGraphV2ScopeSubject(c.chainId, c.core, scope), bytes(previousChainHash, 32), uint(revision, 64), bytes(recordHash, 32)]);
}

/** Authenticates retained bytes and supplied history linkage; does not establish a live head or upstream availability. */
export function authenticateScopedPolicyReferenceV2History(
  coordinates: ScopedPolicyReferenceV2Coordinates,
  dependencies: ScopedPolicyReferenceV2Dependencies,
  publication: ScopedPolicyReferenceV2Publication,
  receipt: ScopedPolicyReferenceV2Receipt,
  canonical: Hex,
  previousChainHash: Hex,
): ScopedPolicyReferenceV2Payload {
  const c = normalizeScopedPolicyReferenceV2Coordinates(coordinates);
  const p = validateScopedPolicyReferenceV2Publication(publication, "publish");
  const r = normalizeScopedPolicyReferenceV2Receipt(receipt);
  const o = r.observation;
  const payload = decodeScopedPolicyReferenceV2Payload(canonical);
  const f = payload.source;
  const subject = graph.scopedPolicyGraphV2ScopeSubject(c.chainId, c.core, p.scope);
  if (f.scopeSubject !== subject || f.snapshot.scopeSubject !== subject
    || f.snapshotSource.membership.scopeSubject !== subject
    || !same(SCOPED_POLICY_REFERENCE_V2_SCOPE_TUPLE, f.snapshotSource.scope, p.scope)
    || !same(SCOPED_POLICY_REFERENCE_V2_SCOPE_TUPLE, f.snapshotSource.outputs.scope, p.scope)
    || !same(SCOPED_POLICY_REFERENCE_V2_SCOPE_TUPLE, f.contentRoot.publication.scope, p.scope)
    || f.snapshot.recordHash !== p.observation.snapshotRecordHash
    || f.snapshot.revision !== p.observation.snapshotRevision
    || f.contentRoot.publication.snapshotRecordHash !== f.snapshot.recordHash
    || f.contentRoot.publication.snapshotRevision !== f.snapshot.revision) {
    throw Error("Retained reference source scope or snapshot differs from its publication");
  }
  const sourceHash = scopedPolicyReferenceV2SourceHash(c, dependencies, payload.source);
  const expected = scopedPolicyReferenceV2PreviewReceipt(c, p, o.recorder,
    { authorizationClass: o.authorizationClass as 3n | 8n, grantRevision: o.grantRevision }, sourceHash);
  if (payload.chainId !== c.chainId || payload.reference !== c.reference
    || !same(SCOPED_POLICY_REFERENCE_V2_RECEIPT_TUPLE, canonicalReceipt(r), expected)
    || p.observation.expectedSourcesHash !== sourceHash || o.recordedAt === 0n || o.effectiveAt > o.recordedAt
    || p.observation.captures.some(capture => capture.capturedAt > o.recordedAt)
    || o.payloadHash !== keccak256(canonical) || o.payloadBytes !== BigInt((canonical.length - 2) / 2)
    || payload.environmentBytes !== referenceEnvironmentCanonicalBytes(p.observation.environment)
    || canonical !== scopedPolicyReferenceV2PayloadBytes(c, p, r, payload.source, payload.environmentBytes)
    || (p.observation.expectedHead === ZERO && bytes(previousChainHash, 32) !== ZERO)
    || scopedPolicyReferenceV2RecordHash(c, p, r) !== nonzero(o.recordHash)
    || scopedPolicyReferenceV2ChainHash(c, p.scope, previousChainHash, o.revision, o.recordHash) !== o.recordChainHash) {
    throw Error("Retained scoped reference history differs from original commitments");
  }
  return payload;
}

/** Original fixed Store chunks; presence and STOP-prefixed runtime must be checked separately. */
export const scopedPolicyReferenceV2Chunks = snapshot.scopedPolicyPublicationV2Chunks;

export const SCOPED_POLICY_REFERENCE_V2_ABI = Object.freeze([
  `function prepareEnvironment(${SCOPED_POLICY_REFERENCE_V2_ENVIRONMENT_TUPLE} environment) returns (bytes32 environmentId)`,
  `function prepareFileInventory(${SCOPED_POLICY_REFERENCE_V2_PACKAGE_FILE_TUPLE}[] rows,bool relative) returns (bytes32)`,
  `function prepareFileInventoryPart(${SCOPED_POLICY_REFERENCE_V2_PACKAGE_FILE_TUPLE}[] rows,bool relative) returns (bytes32 partId)`,
  `function prepareFileInventoryFromParts(${SCOPED_POLICY_REFERENCE_V2_PACKAGE_FILE_TUPLE}[] fullOriginalRows,bool relative) returns (bytes32 inventoryId)`,
  `function publishReference(${SCOPED_POLICY_REFERENCE_V2_PUBLICATION_TUPLE} p) returns (bytes32)`,
  `function previewReference(${SCOPED_POLICY_REFERENCE_V2_PUBLICATION_TUPLE} p,address recorder) view returns (bytes32 sourceHash,bytes canonical)`,
  `function dependencies() view returns (${SCOPED_POLICY_REFERENCE_V2_DEPENDENCIES_TUPLE})`,
  "function scopedPolicyReferenceProfile() pure returns (bytes32)",
  "function core() view returns (address)",
  "function metadataHost() view returns (address)",
  "function metadataRouter() view returns (address)",
  "function snapshots() view returns (address)",
  "function archiveCoverage() view returns (address)",
  "function supportsInterface(bytes4 interfaceId) pure returns (bool)",
  "function preparedFileInventory(bytes32 id) view returns (bytes)",
  `function referenceRecord(bytes32 hash) view returns (${SCOPED_POLICY_REFERENCE_V2_PUBLICATION_TUPLE},${SCOPED_POLICY_REFERENCE_V2_RECEIPT_TUPLE})`,
  "function referencePayload(bytes32 hash) view returns (bytes)",
  `function referenceSource(bytes32 hash) view returns (${SCOPED_POLICY_REFERENCE_V2_SOURCE_FACTS_TUPLE})`,
  `function currentReference(${SCOPED_POLICY_REFERENCE_V2_SCOPE_TUPLE} scope) view returns (${SCOPED_POLICY_REFERENCE_V2_RECEIPT_TUPLE})`,
  `function requireCurrent(${SCOPED_POLICY_REFERENCE_V2_SCOPE_TUPLE} scope,bytes32 hash,uint64 revision) view returns (${SCOPED_POLICY_REFERENCE_V2_RECEIPT_TUPLE})`,
  `function referenceCount(${SCOPED_POLICY_REFERENCE_V2_SCOPE_TUPLE} scope) view returns (uint256)`,
  `function referenceAt(${SCOPED_POLICY_REFERENCE_V2_SCOPE_TUPLE} scope,uint256 index) view returns (bytes32)`,
  `function referenceLock(${SCOPED_POLICY_REFERENCE_V2_SCOPE_TUPLE} scope) view returns (${SCOPED_POLICY_REFERENCE_V2_LOCK_TUPLE})`,
  `event ScopedPolicyReferencePublished(uint16 schemaVersion,bytes32 indexed scopeSubject,bytes32 indexed referenceId,bytes32 indexed recordHash,${SCOPED_POLICY_REFERENCE_V2_RECEIPT_TUPLE} receipt,string manifestURI)`,
  "event ReferenceEnvironmentPrepared(uint16 schemaVersion,bytes32 indexed environmentId,bytes32 contentHash,uint32 byteLength)",
  "event ReferenceInventoryPartPrepared(uint16 schemaVersion,bytes32 indexed partId,bool relative,uint16 rowCount,bytes32 contentHash,uint32 byteLength)",
  "event ReferenceInventoryAssembled(uint16 schemaVersion,bytes32 indexed inventoryId,bool relative,uint256 rowCount,bytes32 contentHash,uint32 byteLength)",
]);

const referenceInterface = new Interface(SCOPED_POLICY_REFERENCE_V2_ABI);
/** Own selectors of the original complete interface, including its separately governed lock surface. */
export const SCOPED_POLICY_REFERENCE_V2_INTERFACE_ID = "0xc6e43ef2" as Hex;
export const SCOPED_POLICY_REFERENCE_V2_ENVIRONMENT_INTERFACE_ID = "0xe5dc1cfc" as Hex;
export const SCOPED_POLICY_REFERENCE_V2_INVENTORY_INTERFACE_ID = "0x08e1f36a" as Hex;

export function scopedPolicyReferenceV2Interface(): Interface {
  return new Interface(SCOPED_POLICY_REFERENCE_V2_ABI);
}

export type ScopedPolicyReferenceV2Request =
  | { readonly kind: "prepareEnvironment"; readonly environment: ScopedPolicyReferenceV2Environment }
  | {
    readonly kind: "prepareFileInventory" | "prepareFileInventoryPart" | "prepareFileInventoryFromParts";
    readonly rows: readonly ScopedPolicyReferenceV2PackageFile[];
    readonly relative: boolean;
  }
  | { readonly kind: "publishReference"; readonly publication: ScopedPolicyReferenceV2Publication };

export interface ScopedPolicyReferenceV2Preparation {
  readonly id: Hex;
  readonly canonical: Hex;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
}

export interface ScopedPolicyReferenceV2Call {
  readonly coordinates: ScopedPolicyReferenceV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyReferenceV2Request;
  readonly call: UnsignedCall;
  readonly preparation: ScopedPolicyReferenceV2Preparation | null;
  readonly factsVerified: false;
}

export function normalizeScopedPolicyReferenceV2Request(value: ScopedPolicyReferenceV2Request): ScopedPolicyReferenceV2Request {
  if (value?.kind === "prepareEnvironment") {
    exact(value, ["kind", "environment"], "Environment preparation");
    return Object.freeze({ kind: value.kind, environment: normalized<ScopedPolicyReferenceV2Environment>(
      SCOPED_POLICY_REFERENCE_V2_ENVIRONMENT_TUPLE, value.environment) });
  }
  if (value?.kind === "prepareFileInventory" || value?.kind === "prepareFileInventoryPart" || value?.kind === "prepareFileInventoryFromParts") {
    exact(value, ["kind", "rows", "relative"], "Inventory preparation");
    if (typeof value.relative !== "boolean") throw Error("Expected relative boolean");
    return Object.freeze({ kind: value.kind, relative: value.relative,
      rows: normalized<readonly ScopedPolicyReferenceV2PackageFile[]>(`${SCOPED_POLICY_REFERENCE_V2_PACKAGE_FILE_TUPLE}[]`, value.rows) });
  }
  if (value?.kind === "publishReference") {
    exact(value, ["kind", "publication"], "Reference publication");
    return Object.freeze({ kind: value.kind, publication: validateScopedPolicyReferenceV2Publication(value.publication, "publish") });
  }
  throw Error("Unknown scoped reference write kind");
}

/** Permissionless preparations confer no publication authority; all five original writes are nonpayable CALLs. */
export function prepareScopedPolicyReferenceV2Call(
  coordinates: ScopedPolicyReferenceV2Coordinates,
  caller: Address,
  request: ScopedPolicyReferenceV2Request,
): ScopedPolicyReferenceV2Call {
  const c = normalizeScopedPolicyReferenceV2Coordinates(coordinates);
  const actor = address(caller, true);
  const q = normalizeScopedPolicyReferenceV2Request(request);
  let preparation: ScopedPolicyReferenceV2Preparation | null = null;
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
  const data = bytes(referenceInterface.encodeFunctionData(q.kind, arguments_), undefined, SCOPED_POLICY_REFERENCE_V2_MAX_CALL_BYTES);
  return Object.freeze({ coordinates: c, caller: actor, request: q,
    call: Object.freeze({ to: c.reference, data, value: 0n }), preparation, factsVerified: false });
}

function stable(value: unknown): string {
  return JSON.stringify(value, (_, v: unknown) => typeof v === "bigint" ? { uint: v.toString() }
    : v && typeof v === "object" && !Array.isArray(v)
      ? Object.fromEntries(Object.entries(v).sort(([a], [b]) => a.localeCompare(b))) : v);
}

export function normalizeScopedPolicyReferenceV2Call(value: ScopedPolicyReferenceV2Call): ScopedPolicyReferenceV2Call {
  exact(value, ["coordinates", "caller", "request", "call", "preparation", "factsVerified"], "Prepared reference call");
  exact(value.call, ["to", "data", "value"], "CALL");
  if (value.preparation !== null) exact(value.preparation, ["id", "canonical", "contentHash", "byteLength"], "Preparation");
  const rebuilt = prepareScopedPolicyReferenceV2Call(value.coordinates, value.caller, value.request);
  if (stable(value) !== stable(rebuilt)) throw Error("Prepared reference call differs from exact reconstruction");
  return rebuilt;
}

export type ScopedPolicyReferenceV2ReadRequest =
  | { readonly kind: "dependencies" | "scopedPolicyReferenceProfile" | "core" | "metadataHost" | "metadataRouter" | "snapshots" | "archiveCoverage" }
  | { readonly kind: "supportsInterface"; readonly interfaceId: Hex }
  | { readonly kind: "previewReference"; readonly publication: ScopedPolicyReferenceV2Publication; readonly recorder: Address }
  | { readonly kind: "preparedFileInventory"; readonly id: Hex }
  | { readonly kind: "referenceRecord" | "referencePayload" | "referenceSource"; readonly hash: Hex }
  | { readonly kind: "currentReference" | "referenceCount" | "referenceLock"; readonly scope: ScopedPolicyReferenceV2Scope }
  | { readonly kind: "referenceAt"; readonly scope: ScopedPolicyReferenceV2Scope; readonly index: bigint }
  | { readonly kind: "requireCurrent"; readonly scope: ScopedPolicyReferenceV2Scope; readonly hash: Hex; readonly revision: bigint };

export interface ScopedPolicyReferenceV2Read {
  readonly coordinates: ScopedPolicyReferenceV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyReferenceV2ReadRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export function prepareScopedPolicyReferenceV2Read(
  coordinates: ScopedPolicyReferenceV2Coordinates,
  caller: Address,
  request: ScopedPolicyReferenceV2ReadRequest,
): ScopedPolicyReferenceV2Read {
  const c = normalizeScopedPolicyReferenceV2Coordinates(coordinates);
  const actor = address(caller);
  let q: ScopedPolicyReferenceV2ReadRequest;
  let arguments_: readonly unknown[];
  switch (request?.kind) {
    case "dependencies": case "scopedPolicyReferenceProfile": case "core": case "metadataHost":
    case "metadataRouter": case "snapshots": case "archiveCoverage":
      exact(request, ["kind"], "Reference getter");
      q = Object.freeze({ kind: request.kind }); arguments_ = []; break;
    case "supportsInterface":
      exact(request, ["kind", "interfaceId"], "Interface getter");
      q = Object.freeze({ kind: request.kind, interfaceId: bytes(request.interfaceId, 4) });
      arguments_ = [q.interfaceId]; break;
    case "previewReference":
      exact(request, ["kind", "publication", "recorder"], "Reference preview");
      q = Object.freeze({ kind: request.kind, publication: validateScopedPolicyReferenceV2Publication(request.publication, "preview"),
        recorder: address(request.recorder, true) }); arguments_ = [q.publication, q.recorder]; break;
    case "preparedFileInventory":
      exact(request, ["kind", "id"], "Prepared inventory getter");
      q = Object.freeze({ kind: request.kind, id: bytes(request.id, 32) }); arguments_ = [q.id]; break;
    case "referenceRecord": case "referencePayload": case "referenceSource":
      exact(request, ["kind", "hash"], "Reference history getter");
      q = Object.freeze({ kind: request.kind, hash: bytes(request.hash, 32) }); arguments_ = [q.hash]; break;
    case "currentReference": case "referenceCount": case "referenceLock":
      exact(request, ["kind", "scope"], "Reference scope getter");
      q = Object.freeze({ kind: request.kind, scope: graph.validateScopedPolicyGraphV2Scope(request.scope) });
      arguments_ = [q.scope]; break;
    case "referenceAt":
      exact(request, ["kind", "scope", "index"], "Reference index getter");
      q = Object.freeze({ kind: request.kind, scope: graph.validateScopedPolicyGraphV2Scope(request.scope), index: uint(request.index) });
      arguments_ = [q.scope, q.index]; break;
    case "requireCurrent":
      exact(request, ["kind", "scope", "hash", "revision"], "Reference currentness getter");
      q = Object.freeze({ kind: request.kind, scope: graph.validateScopedPolicyGraphV2Scope(request.scope),
        hash: bytes(request.hash, 32), revision: uint(request.revision, 64) });
      arguments_ = [q.scope, q.hash, q.revision]; break;
    default: throw Error("Unknown scoped reference read kind");
  }
  return Object.freeze({ coordinates: c, caller: actor, request: q, factsVerified: false,
    call: Object.freeze({ to: c.reference, value: 0n,
      data: bytes(referenceInterface.encodeFunctionData(q.kind, arguments_), undefined, SCOPED_POLICY_REFERENCE_V2_MAX_CALL_BYTES) }) });
}

export function normalizeScopedPolicyReferenceV2Read(value: ScopedPolicyReferenceV2Read): ScopedPolicyReferenceV2Read {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Prepared reference read");
  exact(value.call, ["to", "data", "value"], "Read CALL");
  const rebuilt = prepareScopedPolicyReferenceV2Read(value.coordinates, value.caller, value.request);
  if (stable(value) !== stable(rebuilt)) throw Error("Reference read differs from exact reconstruction");
  return rebuilt;
}
