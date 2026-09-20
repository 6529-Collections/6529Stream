import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import { REFERENCE_ENVIRONMENT_ABI_TUPLE, normalizeReferenceEnvironment, prepareReferenceEnvironment,
  type ReferenceEnvironment, type ReferenceEnvironmentSnapshot } from "./current-reference-environment.js";

/** The original enum includes INVALID. Preparation retains bytes; it does not admit a Mode publication. */
export type ReferenceModeKind = 0n | 1n | 2n;
export interface ReferenceModeCapture {
  readonly tokenId: bigint; readonly collectionSerial: bigint;
  readonly metadataJSONHash: Hex; readonly htmlHash: Hex; readonly htmlBytes: bigint; readonly animationHTML: Hex;
  readonly objectHash: Hex; readonly coverageHash: Hex; readonly sourceSha256: Hex;
  readonly repeatCaptureSha256: readonly [Hex, Hex]; readonly environmentManifestHash: Hex; readonly capturedAt: bigint;
}
export interface ReferenceModePublication {
  readonly collectionId: bigint; readonly referenceId: Hex; readonly expectedHead: Hex; readonly expectedRevision: bigint;
  readonly snapshotRecordHash: Hex; readonly snapshotRevision: bigint; readonly expectedSourcesHash: Hex;
  readonly captures: readonly ReferenceModeCapture[]; readonly environment: ReferenceEnvironment;
  readonly manifestURI: string; readonly effectiveAt: bigint; readonly reasonHash: Hex;
}
export interface ReferenceModeReceipt {
  readonly recordHash: Hex; readonly recordChainHash: Hex; readonly collectionId: bigint; readonly referenceId: Hex;
  readonly predecessor: Hex; readonly revision: bigint; readonly payloadHash: Hex; readonly payloadBytes: bigint;
  readonly sourcesHash: Hex; readonly snapshotRecordHash: Hex; readonly snapshotRevision: bigint; readonly recorder: Address;
  readonly authorizationClass: bigint; readonly grantRevision: bigint; readonly effectiveAt: bigint; readonly recordedAt: bigint;
  readonly reasonHash: Hex; readonly schemaHash: Hex; readonly profileHash: Hex; readonly canonicalizationHash: Hex;
}
export interface ReferenceModeCoverage {
  readonly coverageHash: Hex; readonly objectHash: Hex; readonly artistId: Hex; readonly contentHash: Hex;
  readonly sha256Digest: Hex; readonly arweaveDataRoot: Hex; readonly byteSize: bigint;
  readonly firstFamilyRecordHash: Hex; readonly secondFamilyRecordHash: Hex; readonly firstReceiptHash: Hex;
  readonly secondReceiptHash: Hex; readonly firstFixityHash: Hex; readonly secondFixityHash: Hex;
  readonly checkpointHash: Hex; readonly profileHash: Hex;
}
export interface ReferenceModeSnapshotBinding {
  readonly recordHash: Hex; readonly manifestHash: Hex; readonly sourceHash: Hex; readonly inventoryPlan: Hex;
  readonly revision: bigint; readonly schemaHash: Hex; readonly profileHash: Hex; readonly canonicalizationHash: Hex;
}
export interface ReferenceModeRendererDeclaration {
  readonly renderer: Address; readonly rendererCodeHash: Hex; readonly routerVersion: Hex; readonly routerManifestHash: Hex;
  readonly presentationProfile: Hex; readonly rendererContext: Hex; readonly dependencyReadSet: Hex; readonly rendererClass: Hex;
}
export interface ReferenceModeSampleFacts {
  readonly tokenId: bigint; readonly collectionSerial: bigint; readonly originalCoordinator: Address; readonly seed: Hex;
  readonly tokenDataHash: Hex; readonly tokenDataBytes: bigint; readonly metadataJSONHash: Hex;
  readonly htmlHash: Hex; readonly htmlBytes: bigint; readonly captureCoverage: ReferenceModeCoverage;
}
export interface ReferenceModeSourceFacts {
  readonly subject: Hex; readonly mintedEver: bigint; readonly artistId: Hex; readonly snapshot: ReferenceModeSnapshotBinding;
  readonly renderer: ReferenceModeRendererDeclaration; readonly environmentCoverage: ReferenceModeCoverage;
  readonly samples: readonly ReferenceModeSampleFacts[];
}
export interface ReferenceModeRepeat { readonly objectHash: Hex; readonly coverageHash: Hex }
export interface ReferenceModeMetric {
  readonly metricId: Hex; readonly algorithm: Hex; readonly tool: string; readonly version: string;
  readonly implementationHash: Hex; readonly parametersHash: Hex; readonly scale: bigint;
}
export interface ReferenceModePerceptual {
  readonly metric: ReferenceModeMetric; readonly threshold: bigint; readonly scores: readonly bigint[];
  readonly reportHash: Hex; readonly reportURI: string; readonly evaluatedAt: bigint;
}
export interface ReferenceModeConservationReference {
  readonly algorithm: bigint; readonly canonicalizationId: Hex; readonly digest: Hex; readonly uri: string;
}
export interface ReferenceModeArtistClaim {
  readonly artistId: Hex; readonly bindingGeneration: bigint; readonly bindingHash: Hex; readonly origin: 0n | 1n;
}
export interface ReferenceModeInterviewRecord {
  readonly chainId: bigint; readonly core: Address; readonly host: Address; readonly recordHash: Hex;
  readonly schemaId: Hex; readonly profileHash: Hex; readonly payload: ReferenceModeConservationReference;
}
export interface ReferenceModeInterviewEntry {
  readonly status: 0n | 1n; readonly record: ReferenceModeInterviewRecord; readonly waiverStatement: ReferenceModeConservationReference;
}
export interface ReferenceModeDisplay {
  readonly scale: ReferenceModeConservationReference; readonly timing: ReferenceModeConservationReference;
  readonly color: ReferenceModeConservationReference; readonly interaction: ReferenceModeConservationReference;
  readonly motion: ReferenceModeConservationReference; readonly frameRate: ReferenceModeConservationReference;
}
export interface ReferenceModeIntent {
  readonly subjectId: Hex; readonly profileHash: Hex; readonly predecessor: Hex; readonly artist: ReferenceModeArtistClaim;
  readonly display: ReferenceModeDisplay; readonly variabilityTolerances: ReferenceModeConservationReference;
  readonly dependencyAging: ReferenceModeConservationReference; readonly significantProperties: ReferenceModeConservationReference;
  readonly interview: ReferenceModeInterviewEntry;
}
export interface ReferenceModeProperty { readonly id: Hex; readonly name: string; readonly significantValue: string }
export interface ReferenceModeAssessment { readonly propertyId: Hex; readonly conforms: boolean; readonly observation: string }
export interface ReferenceModeCondition {
  readonly contextHash: Hex; readonly intentRecordHash: Hex; readonly intentSelectionHash: Hex; readonly propertiesHash: Hex;
  readonly examiner: Address; readonly examinerName: string; readonly institution: ReferenceModeConservationReference;
  readonly credentials: ReferenceModeConservationReference; readonly examinedAt: bigint; readonly assessments: readonly ReferenceModeAssessment[];
}
export interface ReferenceModeCurated {
  readonly conditionRecordHash: Hex; readonly intentRecordHash: Hex; readonly intentRevision: bigint;
  readonly intent: ReferenceModeIntent; readonly properties: readonly ReferenceModeProperty[]; readonly condition: ReferenceModeCondition;
}
export interface ReferenceModeEvidence {
  readonly mode: ReferenceModeKind; readonly repeats: readonly ReferenceModeRepeat[];
  readonly perceptual: ReferenceModePerceptual; readonly curated: ReferenceModeCurated;
}
export interface ReferenceModeFacts {
  readonly mode: ReferenceModeKind; readonly evidenceHash: Hex; readonly interpretationHash: Hex;
  readonly conditionRecordHash: Hex; readonly conditionReceiptHash: Hex; readonly intentSelectionHash: Hex;
  readonly repeats: readonly ReferenceModeCoverage[];
}
export interface ReferenceModePublicationDescriptor {
  readonly publicationHash: Hex; readonly publicationBytes: bigint; readonly environmentId: Hex;
  readonly environmentHash: Hex; readonly environmentBytes: bigint;
}
export interface ReferenceModePayloadComponents {
  readonly publicationHash: Hex; readonly publicationBytes: bigint; readonly receiptHash: Hex; readonly receiptBytes: bigint;
  readonly sourceHash: Hex; readonly sourceBytes: bigint; readonly evidenceHash: Hex; readonly evidenceBytes: bigint;
  readonly factsHash: Hex; readonly factsBytes: bigint; readonly environmentHash: Hex; readonly environmentBytes: bigint;
}
/** Full supplied facts. No cache, source, writer, grant, head or finality is authenticated here. */
export interface ReferenceModePayloadInput {
  readonly receipt: ReferenceModeReceipt; readonly source: ReferenceModeSourceFacts;
  readonly evidence: ReferenceModeEvidence; readonly facts: ReferenceModeFacts;
}
export interface ReferenceModePublicationSnapshot {
  readonly chainId: bigint; readonly publicationHost: Address; readonly publication: ReferenceModePublication;
  readonly environment: ReferenceEnvironmentSnapshot; readonly canonical: Hex; readonly contentHash: Hex;
  readonly byteLength: bigint; readonly publicationPreparationId: Hex; readonly descriptor: ReferenceModePublicationDescriptor;
}
export interface ReferenceModePayloadSnapshot {
  readonly publication: ReferenceModePublicationSnapshot; readonly input: ReferenceModePayloadInput;
  readonly canonical: Hex; readonly contentHash: Hex; readonly byteLength: bigint;
  readonly payloadPreparationId: Hex; readonly components: ReferenceModePayloadComponents;
}
export type ReferenceModePreparationCall = Readonly<
  { kind: "publication"; caller: Address; snapshot: ReferenceModePublicationSnapshot; identity: Hex; call: UnsignedCall }
  | { kind: "payload"; caller: Address; snapshot: ReferenceModePayloadSnapshot; identity: Hex; call: UnsignedCall }>;

export const REFERENCE_MODE_MAX_BYTES = 524288;
export const REFERENCE_MODE_PAYLOAD_PREPARATION_INTERFACE_ID = "0x3092a6e0" as Hex;
export const REFERENCE_MODE_PUBLICATION_PREPARATION_DOMAIN = id("6529STREAM_REFERENCE_MODE_PUBLICATION_PREPARATION_V1") as Hex;
export const REFERENCE_MODE_PAYLOAD_PREPARATION_DOMAIN = id("6529STREAM_REFERENCE_MODE_PAYLOAD_PREPARATION_V1") as Hex;
export const REFERENCE_MODE_PAYLOAD_DOMAIN = id("6529STREAM_REFERENCE_MODE_PAYLOAD_V1") as Hex;
export const REFERENCE_MODE_CAPTURE_TUPLE = "tuple(uint256 tokenId,uint256 collectionSerial,bytes32 metadataJSONHash,bytes32 htmlHash,uint32 htmlBytes,bytes animationHTML,bytes32 objectHash,bytes32 coverageHash,bytes32 sourceSha256,bytes32[2] repeatCaptureSha256,bytes32 environmentManifestHash,uint64 capturedAt)";
export const REFERENCE_MODE_PUBLICATION_TUPLE = `tuple(uint256 collectionId,bytes32 referenceId,bytes32 expectedHead,uint64 expectedRevision,bytes32 snapshotRecordHash,uint64 snapshotRevision,bytes32 expectedSourcesHash,${REFERENCE_MODE_CAPTURE_TUPLE}[] captures,${REFERENCE_ENVIRONMENT_ABI_TUPLE} environment,string manifestURI,uint64 effectiveAt,bytes32 reasonHash)`;
export const REFERENCE_MODE_RECEIPT_TUPLE = "tuple(bytes32 recordHash,bytes32 recordChainHash,uint256 collectionId,bytes32 referenceId,bytes32 predecessor,uint64 revision,bytes32 payloadHash,uint32 payloadBytes,bytes32 sourcesHash,bytes32 snapshotRecordHash,uint64 snapshotRevision,address recorder,uint8 authorizationClass,uint64 grantRevision,uint64 effectiveAt,uint64 recordedAt,bytes32 reasonHash,bytes32 schemaHash,bytes32 profileHash,bytes32 canonicalizationHash)";
export const REFERENCE_MODE_COVERAGE_TUPLE = "tuple(bytes32 coverageHash,bytes32 objectHash,bytes32 artistId,bytes32 contentHash,bytes32 sha256Digest,bytes32 arweaveDataRoot,uint64 byteSize,bytes32 firstFamilyRecordHash,bytes32 secondFamilyRecordHash,bytes32 firstReceiptHash,bytes32 secondReceiptHash,bytes32 firstFixityHash,bytes32 secondFixityHash,bytes32 checkpointHash,bytes32 profileHash)";
export const REFERENCE_MODE_SNAPSHOT_BINDING_TUPLE = "tuple(bytes32 recordHash,bytes32 manifestHash,bytes32 sourceHash,bytes32 inventoryPlan,uint64 revision,bytes32 schemaHash,bytes32 profileHash,bytes32 canonicalizationHash)";
export const REFERENCE_MODE_RENDERER_DECLARATION_TUPLE = "tuple(address renderer,bytes32 rendererCodeHash,bytes32 routerVersion,bytes32 routerManifestHash,bytes32 presentationProfile,bytes32 rendererContext,bytes32 dependencyReadSet,bytes32 rendererClass)";
export const REFERENCE_MODE_SAMPLE_FACTS_TUPLE = `tuple(uint256 tokenId,uint256 collectionSerial,address originalCoordinator,bytes32 seed,bytes32 tokenDataHash,uint32 tokenDataBytes,bytes32 metadataJSONHash,bytes32 htmlHash,uint32 htmlBytes,${REFERENCE_MODE_COVERAGE_TUPLE} captureCoverage)`;
export const REFERENCE_MODE_SOURCE_FACTS_TUPLE = `tuple(bytes32 subject,uint256 mintedEver,bytes32 artistId,${REFERENCE_MODE_SNAPSHOT_BINDING_TUPLE} snapshot,${REFERENCE_MODE_RENDERER_DECLARATION_TUPLE} renderer,${REFERENCE_MODE_COVERAGE_TUPLE} environmentCoverage,${REFERENCE_MODE_SAMPLE_FACTS_TUPLE}[] samples)`;
export const REFERENCE_MODE_REPEAT_TUPLE = "tuple(bytes32 objectHash,bytes32 coverageHash)";
export const REFERENCE_MODE_METRIC_TUPLE = "tuple(bytes32 metricId,bytes32 algorithm,string tool,string version,bytes32 implementationHash,bytes32 parametersHash,uint64 scale)";
export const REFERENCE_MODE_PERCEPTUAL_TUPLE = `tuple(${REFERENCE_MODE_METRIC_TUPLE} metric,int64 threshold,int64[] scores,bytes32 reportHash,string reportURI,uint64 evaluatedAt)`;
export const REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE = "tuple(uint16 algorithm,bytes32 canonicalizationId,bytes digest,string uri)";
export const REFERENCE_MODE_ARTIST_CLAIM_TUPLE = "tuple(bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,uint8 origin)";
export const REFERENCE_MODE_INTERVIEW_RECORD_TUPLE = `tuple(uint256 chainId,address core,address host,bytes32 recordHash,bytes32 schemaId,bytes32 profileHash,${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} payload)`;
export const REFERENCE_MODE_INTERVIEW_ENTRY_TUPLE = `tuple(uint8 status,${REFERENCE_MODE_INTERVIEW_RECORD_TUPLE} record,${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} waiverStatement)`;
export const REFERENCE_MODE_DISPLAY_TUPLE = `tuple(${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} scale,${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} timing,${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} color,${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} interaction,${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} motion,${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} frameRate)`;
export const REFERENCE_MODE_INTENT_TUPLE = `tuple(bytes32 subjectId,bytes32 profileHash,bytes32 predecessor,${REFERENCE_MODE_ARTIST_CLAIM_TUPLE} artist,${REFERENCE_MODE_DISPLAY_TUPLE} display,${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} variabilityTolerances,${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} dependencyAging,${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} significantProperties,${REFERENCE_MODE_INTERVIEW_ENTRY_TUPLE} interview)`;
export const REFERENCE_MODE_PROPERTY_TUPLE = "tuple(bytes32 id,string name,string significantValue)";
export const REFERENCE_MODE_ASSESSMENT_TUPLE = "tuple(bytes32 propertyId,bool conforms,string observation)";
export const REFERENCE_MODE_CONDITION_TUPLE = `tuple(bytes32 contextHash,bytes32 intentRecordHash,bytes32 intentSelectionHash,bytes32 propertiesHash,address examiner,string examinerName,${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} institution,${REFERENCE_MODE_CONSERVATION_REFERENCE_TUPLE} credentials,uint64 examinedAt,${REFERENCE_MODE_ASSESSMENT_TUPLE}[] assessments)`;
export const REFERENCE_MODE_CURATED_TUPLE = `tuple(bytes32 conditionRecordHash,bytes32 intentRecordHash,uint64 intentRevision,${REFERENCE_MODE_INTENT_TUPLE} intent,${REFERENCE_MODE_PROPERTY_TUPLE}[] properties,${REFERENCE_MODE_CONDITION_TUPLE} condition)`;
export const REFERENCE_MODE_EVIDENCE_TUPLE = `tuple(uint8 mode,${REFERENCE_MODE_REPEAT_TUPLE}[] repeats,${REFERENCE_MODE_PERCEPTUAL_TUPLE} perceptual,${REFERENCE_MODE_CURATED_TUPLE} curated)`;
export const REFERENCE_MODE_FACTS_TUPLE = `tuple(uint8 mode,bytes32 evidenceHash,bytes32 interpretationHash,bytes32 conditionRecordHash,bytes32 conditionReceiptHash,bytes32 intentSelectionHash,${REFERENCE_MODE_COVERAGE_TUPLE}[] repeats)`;
export const REFERENCE_MODE_PUBLICATION_DESCRIPTOR_TUPLE = "tuple(bytes32 publicationHash,uint32 publicationBytes,bytes32 environmentId,bytes32 environmentHash,uint32 environmentBytes)";
export const REFERENCE_MODE_PAYLOAD_COMPONENTS_TUPLE = "tuple(bytes32 publicationHash,uint32 publicationBytes,bytes32 receiptHash,uint32 receiptBytes,bytes32 sourceHash,uint32 sourceBytes,bytes32 evidenceHash,uint32 evidenceBytes,bytes32 factsHash,uint32 factsBytes,bytes32 environmentHash,uint32 environmentBytes)";
export const REFERENCE_MODE_PAYLOAD_TYPES = Object.freeze(["bytes32", REFERENCE_MODE_PUBLICATION_TUPLE, REFERENCE_MODE_RECEIPT_TUPLE,
  REFERENCE_MODE_SOURCE_FACTS_TUPLE, REFERENCE_MODE_EVIDENCE_TUPLE, REFERENCE_MODE_FACTS_TUPLE, "bytes"]);
export const CURRENT_REFERENCE_MODE_PAYLOAD_ABI = Object.freeze([
  `function prepareModePublication(${REFERENCE_MODE_PUBLICATION_TUPLE} publication) returns (bytes32)`,
  `function prepareModePayload(bytes32 publicationPreparationId,${REFERENCE_MODE_RECEIPT_TUPLE} receipt,${REFERENCE_MODE_SOURCE_FACTS_TUPLE} source,${REFERENCE_MODE_EVIDENCE_TUPLE} evidence,${REFERENCE_MODE_FACTS_TUPLE} facts) returns (bytes32)`,
  `function preparedModePublication(bytes32 id) view returns (${REFERENCE_MODE_PUBLICATION_DESCRIPTOR_TUPLE} descriptor,bytes canonical)`,
  "function preparedModePayload(bytes32 id) view returns (bytes canonical)",
  `event ReferenceModePublicationPrepared(uint16 schemaVersion,bytes32 indexed preparationId,${REFERENCE_MODE_PUBLICATION_DESCRIPTOR_TUPLE} descriptor)`,
  "event ReferenceModePayloadPrepared(uint16 schemaVersion,bytes32 indexed preparationId,bytes32 indexed publicationPreparationId,bytes32 payloadHash,uint32 payloadBytes)",
]);

const coder = AbiCoder.defaultAbiCoder(), preparationInterface = new Interface(CURRENT_REFERENCE_MODE_PAYLOAD_ABI);
const publicationType = ParamType.from(REFERENCE_MODE_PUBLICATION_TUPLE), receiptType = ParamType.from(REFERENCE_MODE_RECEIPT_TUPLE);
const sourceType = ParamType.from(REFERENCE_MODE_SOURCE_FACTS_TUPLE), evidenceType = ParamType.from(REFERENCE_MODE_EVIDENCE_TUPLE), factsType = ParamType.from(REFERENCE_MODE_FACTS_TUPLE);
const payloadInputKeys = ["receipt", "source", "evidence", "facts"];
function exact(value: unknown, keys: readonly string[], label: string): asserts value is Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Reflect.ownKeys(value).some(key => typeof key !== "string")
    || Object.getOwnPropertyNames(value).sort().join(",") !== [...keys].sort().join(",")) throw Error(`${label} contains missing or unknown properties`);
}
function address(value: unknown, label: string, nonzero = false): Address {
  if (typeof value !== "string") throw Error(`${label} must be an address`);
  const result = getAddress(value) as Address;
  if (nonzero && result === ZeroAddress) throw Error(`${label} must be nonzero`);
  return result;
}
function integer(value: unknown, bits: number, label: string, signed = false): bigint {
  const max = 1n << BigInt(signed ? bits - 1 : bits), min = signed ? -max : 0n;
  if (typeof value !== "bigint" || value < min || value >= max) throw Error(`${label} must be ${signed ? "int" : "uint"}${bits} bigint`);
  return value;
}
function byteString(value: unknown, label: string, size?: number): Hex {
  if (typeof value !== "string" || !isHexString(value, size === undefined ? true : size)) throw Error(`${label} must be ${size === undefined ? "even-length hex bytes" : `bytes${size}`}`);
  if (size === undefined && (value.length - 2) / 2 > REFERENCE_MODE_MAX_BYTES) throw Error(`${label} exceeds the 524288-byte retention limit`);
  return value.toLowerCase() as Hex;
}
function dense(value: unknown, label: string): asserts value is unknown[] {
  if (!Array.isArray(value) || value.length > REFERENCE_MODE_MAX_BYTES / 32
    || Reflect.ownKeys(value).length !== value.length + 1
    || !Array.from({ length: value.length }, (_, index) => Object.hasOwn(value, index)).every(Boolean)) {
    throw Error(`${label} must be a dense bounded array without additional properties`);
  }
}
/** Strings are Unicode text, not an arbitrary non-UTF-8 Solidity string transport. No normalization is applied. */
function text(value: unknown, label: string): string {
  if (typeof value !== "string") throw Error(`${label} must be text`);
  for (const character of value) {
    const scalar = character.codePointAt(0)!;
    if (scalar >= 0xd800 && scalar <= 0xdfff) throw Error(`${label} must contain valid UTF-8 scalar values`);
  }
  if (toUtf8Bytes(value).length > REFERENCE_MODE_MAX_BYTES) throw Error(`${label} exceeds the 524288-byte retention limit`);
  return value;
}
function normalize(type: ParamType, value: unknown, label: string): unknown {
  if (label === "Publication.environment") return normalizeReferenceEnvironment(normalize(type, value, "Environment") as ReferenceEnvironment);
  if (type.baseType === "tuple") {
    const fields = type.components!; exact(value, fields.map(field => field.name), label);
    return Object.freeze(Object.fromEntries(fields.map(field => [field.name, normalize(field, value[field.name], `${label}.${field.name}`)])));
  }
  if (type.baseType === "array") {
    dense(value, label);
    if (type.arrayLength !== -1 && value.length !== type.arrayLength) throw Error(`${label} must contain exactly ${type.arrayLength} elements`);
    return Object.freeze(value.map((item, index) => normalize(type.arrayChildren!, item, `${label}[${index}]`)));
  }
  if (type.type === "address") return address(value, label);
  if (type.type === "bool") {
    if (typeof value !== "boolean") throw Error(`${label} must be boolean`);
    return value;
  }
  if (type.type === "string") return text(value, label);
  if (type.type === "bytes") return byteString(value, label);
  if (type.type.startsWith("bytes")) return byteString(value, label, Number(type.type.slice(5)));
  const signed = type.type.startsWith("int"), bits = Number(type.type.slice(signed ? 3 : 4));
  const result = integer(value, bits, label, signed);
  const maximum = label === "Evidence.mode" || label === "Facts.mode" ? 2n
    : label === "Evidence.curated.intent.artist.origin" || label === "Evidence.curated.intent.interview.status" ? 1n : null;
  if (maximum !== null && result > maximum) throw Error(`${label} is outside the original enum`);
  return result;
}
function encoded(type: ParamType, value: unknown, label: string): Hex {
  const result = coder.encode([type], [value]) as Hex;
  if (byteLength(result) > BigInt(REFERENCE_MODE_MAX_BYTES)) throw Error(`${label} exceeds the 524288-byte retention limit`);
  return result;
}
function byteLength(raw: Hex): bigint { return BigInt((raw.length - 2) / 2); }
function hash(raw: Hex): Hex { return keccak256(raw) as Hex; }

/** Structural tuple normalization only; no candidate/lineage, capture/source or authority admission. */
export function normalizeReferenceModePublication(input: ReferenceModePublication): ReferenceModePublication {
  const result = normalize(publicationType, input, "Publication") as ReferenceModePublication;
  encoded(publicationType, result, "Publication"); return result;
}
/** Exact source normalization: only the five fields excluded by StreamReferenceModePayloadEncoding. */
export function normalizeReferenceModeReceipt(input: ReferenceModeReceipt): ReferenceModeReceipt {
  const result = normalize(receiptType, input, "Receipt") as ReferenceModeReceipt;
  return Object.freeze({ ...result, recordHash: ZeroHash as Hex, recordChainHash: ZeroHash as Hex,
    payloadHash: ZeroHash as Hex, payloadBytes: 0n, recordedAt: 0n });
}
export function normalizeReferenceModeSourceFacts(input: ReferenceModeSourceFacts): ReferenceModeSourceFacts {
  const result = normalize(sourceType, input, "SourceFacts") as ReferenceModeSourceFacts;
  encoded(sourceType, result, "SourceFacts"); return result;
}
export function normalizeReferenceModeEvidence(input: ReferenceModeEvidence): ReferenceModeEvidence {
  const result = normalize(evidenceType, input, "Evidence") as ReferenceModeEvidence;
  encoded(evidenceType, result, "Evidence"); return result;
}
export function normalizeReferenceModeFacts(input: ReferenceModeFacts): ReferenceModeFacts {
  const result = normalize(factsType, input, "Facts") as ReferenceModeFacts;
  encoded(factsType, result, "Facts"); return result;
}
export function normalizeReferenceModePayloadInput(input: ReferenceModePayloadInput): ReferenceModePayloadInput {
  exact(input, payloadInputKeys, "Mode payload input");
  return Object.freeze({ receipt: normalizeReferenceModeReceipt(input.receipt), source: normalizeReferenceModeSourceFacts(input.source),
    evidence: normalizeReferenceModeEvidence(input.evidence), facts: normalizeReferenceModeFacts(input.facts) });
}
/** Build the original full Publication bytes and descriptor; retained prerequisites are checked by the workflow/host. */
export function prepareReferenceModePublication(chainId: bigint, publicationHost: Address, input: ReferenceModePublication): ReferenceModePublicationSnapshot {
  const chain = integer(chainId, 256, "Chain ID");
  if (chain === 0n) throw Error("Chain ID must be positive");
  const target = address(publicationHost, "Publication host", true), publication = normalizeReferenceModePublication(input);
  const environment = prepareReferenceEnvironment(chain, target, publication.environment);
  for (const capture of publication.captures) {
    if (capture.environmentManifestHash !== environment.contentHash) throw Error("Capture environment manifest differs from the original retained Environment");
  }
  const canonical = encoded(publicationType, publication, "Publication"), contentHash = hash(canonical), length = byteLength(canonical);
  const descriptor = Object.freeze({ publicationHash: contentHash, publicationBytes: length, environmentId: environment.environmentId,
    environmentHash: environment.contentHash, environmentBytes: environment.byteLength });
  const publicationPreparationId = hash(coder.encode(["bytes32", "uint256", "address", "bytes32", "uint32"],
    [REFERENCE_MODE_PUBLICATION_PREPARATION_DOMAIN, chain, target, contentHash, length]) as Hex);
  return Object.freeze({ chainId: chain, publicationHost: target, publication, environment, canonical, contentHash,
    byteLength: length, publicationPreparationId, descriptor });
}
function payloadFrom(publication: ReferenceModePublicationSnapshot, input: ReferenceModePayloadInput): ReferenceModePayloadSnapshot {
  const receiptRaw = encoded(receiptType, input.receipt, "Receipt"), sourceRaw = encoded(sourceType, input.source, "SourceFacts");
  const evidenceRaw = encoded(evidenceType, input.evidence, "Evidence"), factsRaw = encoded(factsType, input.facts, "Facts");
  if (byteLength(receiptRaw) !== 640n) throw Error("Original Receipt must encode to exactly 640 bytes");
  const components: ReferenceModePayloadComponents = Object.freeze({ publicationHash: publication.contentHash, publicationBytes: publication.byteLength,
    receiptHash: hash(receiptRaw), receiptBytes: byteLength(receiptRaw), sourceHash: hash(sourceRaw), sourceBytes: byteLength(sourceRaw),
    evidenceHash: hash(evidenceRaw), evidenceBytes: byteLength(evidenceRaw), factsHash: hash(factsRaw), factsBytes: byteLength(factsRaw),
    environmentHash: publication.environment.contentHash, environmentBytes: publication.environment.byteLength });
  const canonical = coder.encode(REFERENCE_MODE_PAYLOAD_TYPES, [REFERENCE_MODE_PAYLOAD_DOMAIN, publication.publication,
    input.receipt, input.source, input.evidence, input.facts, publication.environment.canonical]) as Hex;
  const length = byteLength(canonical);
  if (length > BigInt(REFERENCE_MODE_MAX_BYTES)) throw Error("Original Mode payload exceeds the 524288-byte retention limit");
  const payloadPreparationId = hash(coder.encode(["bytes32", "uint256", "address", REFERENCE_MODE_PAYLOAD_COMPONENTS_TUPLE],
    [REFERENCE_MODE_PAYLOAD_PREPARATION_DOMAIN, publication.chainId, publication.publicationHost, components]) as Hex);
  return Object.freeze({ publication, input, canonical, contentHash: hash(canonical), byteLength: length, payloadPreparationId, components });
}
/** Retains complete supplied inactive branches too. This is not proof of source validity or publication readiness. */
export function prepareReferenceModePayload(publication: ReferenceModePublicationSnapshot, input: ReferenceModePayloadInput): ReferenceModePayloadSnapshot {
  return payloadFrom(normalizeReferenceModePublicationSnapshot(publication), normalizeReferenceModePayloadInput(input));
}
function same(input: unknown, rebuilt: unknown, label: string): void {
  if (Array.isArray(rebuilt)) {
    dense(input, label);
    if (input.length !== rebuilt.length) throw Error(`${label} differs from exact typed input reconstruction`);
    rebuilt.forEach((value, index) => same(input[index], value, `${label}[${index}]`));
  } else if (rebuilt !== null && typeof rebuilt === "object") {
    const keys = Object.keys(rebuilt); exact(input, keys, label);
    for (const key of keys) same(input[key], (rebuilt as Record<string, unknown>)[key], `${label}.${key}`);
  } else if (input !== rebuilt) throw Error(`${label} differs from exact typed input reconstruction`);
}
export function normalizeReferenceModePublicationSnapshot(input: ReferenceModePublicationSnapshot): ReferenceModePublicationSnapshot {
  exact(input, ["chainId", "publicationHost", "publication", "environment", "canonical", "contentHash", "byteLength", "publicationPreparationId", "descriptor"], "Mode publication snapshot");
  const rebuilt = prepareReferenceModePublication(input.chainId, input.publicationHost, input.publication);
  same(input, rebuilt, "Mode publication snapshot"); return rebuilt;
}
export function normalizeReferenceModePayloadSnapshot(input: ReferenceModePayloadSnapshot): ReferenceModePayloadSnapshot {
  exact(input, ["publication", "input", "canonical", "contentHash", "byteLength", "payloadPreparationId", "components"], "Mode payload snapshot");
  const rebuilt = prepareReferenceModePayload(input.publication, input.input);
  same(input, rebuilt, "Mode payload snapshot"); return rebuilt;
}
function decoded(type: ParamType, input: unknown): unknown {
  if (type.baseType === "tuple") return Object.fromEntries(type.components!.map((field, index) => [field.name, decoded(field, (input as readonly unknown[])[index])]));
  if (type.baseType === "array") return (input as readonly unknown[]).map(value => decoded(type.arrayChildren!, value));
  return input;
}
/** Decode a preview or retained payload; reject alternate offsets/padding, trailing bytes and changed normalized fields. */
export function decodeReferenceModePayload(chainId: bigint, publicationHost: Address, canonicalInput: Hex): ReferenceModePayloadSnapshot {
  const raw = byteString(canonicalInput, "Canonical Mode payload"), values = coder.decode(REFERENCE_MODE_PAYLOAD_TYPES, raw);
  if (values[0] !== REFERENCE_MODE_PAYLOAD_DOMAIN) throw Error("Canonical Mode payload has the wrong original domain");
  const publication = prepareReferenceModePublication(chainId, publicationHost, decoded(publicationType, values[1]) as ReferenceModePublication);
  const input = normalizeReferenceModePayloadInput({ receipt: decoded(receiptType, values[2]) as ReferenceModeReceipt,
    source: decoded(sourceType, values[3]) as ReferenceModeSourceFacts, evidence: decoded(evidenceType, values[4]) as ReferenceModeEvidence,
    facts: decoded(factsType, values[5]) as ReferenceModeFacts });
  if (values[6] !== publication.environment.canonical) throw Error("Payload Environment bytes differ from the complete original Environment");
  const result = payloadFrom(publication, input);
  if (result.canonical !== raw) throw Error("Mode payload is not the original canonical normalized seven-field encoding");
  return result;
}
export function prepareReferenceModePublicationCall(snapshot: ReferenceModePublicationSnapshot, caller: Address): Extract<ReferenceModePreparationCall, { kind: "publication" }> {
  const saved = normalizeReferenceModePublicationSnapshot(snapshot), actor = address(caller, "Preparation caller", true);
  const call = Object.freeze({ to: saved.publicationHost, value: 0n, data: preparationInterface.encodeFunctionData("prepareModePublication", [saved.publication]) as Hex });
  return Object.freeze({ kind: "publication", caller: actor, snapshot: saved, identity: saved.publicationPreparationId, call });
}
export function prepareReferenceModePayloadCall(snapshot: ReferenceModePayloadSnapshot, caller: Address): Extract<ReferenceModePreparationCall, { kind: "payload" }> {
  const saved = normalizeReferenceModePayloadSnapshot(snapshot), actor = address(caller, "Preparation caller", true);
  const call = Object.freeze({ to: saved.publication.publicationHost, value: 0n, data: preparationInterface.encodeFunctionData("prepareModePayload",
    [saved.publication.publicationPreparationId, saved.input.receipt, saved.input.source, saved.input.evidence, saved.input.facts]) as Hex });
  return Object.freeze({ kind: "payload", caller: actor, snapshot: saved, identity: saved.payloadPreparationId, call });
}
export function normalizeReferenceModePreparationCall(input: ReferenceModePreparationCall): ReferenceModePreparationCall {
  exact(input, ["kind", "caller", "snapshot", "identity", "call"], "Mode preparation call");
  let rebuilt: ReferenceModePreparationCall;
  if (input.kind === "publication") rebuilt = prepareReferenceModePublicationCall(input.snapshot, input.caller);
  else if (input.kind === "payload") rebuilt = prepareReferenceModePayloadCall(input.snapshot, input.caller);
  else throw Error("Unknown Mode preparation call kind");
  same(input, rebuilt, "Mode preparation call"); return rebuilt;
}
