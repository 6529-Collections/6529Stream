import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, hexlify, id, isHexString, keccak256, toUtf8Bytes, toUtf8String } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import { CURRENT_ARTIST_RECOVERY_GOVERNANCE_ABI, ARTIST_RECOVERY_GOVERNANCE_CALL_TUPLE } from "./current-artist-recovery-adjudication.js";
import { normalizeMintFallbackGovernanceWindow, type MintFallbackGovernanceWindow, type MintFallbackGovernanceCall } from "./current-mint-fallback.js";
import { CURRENT_ARTIST_ATTESTATION_PUBLICATION_TUPLE } from "./current-artist-operation.js";

/** Additive ABI94 profile. Native51 evidence does not qualify the later Core floor anchor. */
export const MUSEUM_ANCHOR_MASTER_SOURCE = "e558addd5ce1aee15d7ac327482b3822289d3dc7";
export const MUSEUM_ANCHOR_MASTER_MAX_PAYLOAD_BYTES = 8192;
/** Client allocation ceiling for complete nested ABI witnesses, not a new protocol limit. */
export const MUSEUM_ANCHOR_MASTER_MAX_ABI_BYTES = 262144;
export const MUSEUM_GRADE = id("MUSEUM_GRADE") as Hex;
export const MUSEUM_GRADE_LITE = id("MUSEUM_GRADE_LITE") as Hex;
export const MUSEUM_CONSERVATION_WAIVED = id("CONSERVATION_WAIVED") as Hex;
export const MUSEUM_MASTER_PROFILE_HASH = "0x77133c55381ef35de45e4824c63983ae7ff021a4fb2b8da2a036ec06c0126ff2" as Hex;
export const MUSEUM_MASTER_SCHEMA_ID = id("STREAM_MEDIA_MASTER_ASSOCIATION_V1") as Hex;
export const MUSEUM_MASTER_SCHEMA_HASH = "0xffa74f87b27c73aced2cf2e9f9da7d8255b947b1a7627b0a71536c2a35b8f0e5" as Hex;
export const MUSEUM_MASTER_WAIVER_SCHEMA_ID = id("STREAM_MASTER_WAIVER_V1") as Hex;
export const MUSEUM_MASTER_WAIVER_SCHEMA_HASH = "0x7e437d7591cb009ab71fbdf006e3286e64a74846d66bac9eabef46840d0eb069" as Hex;
export const MUSEUM_MASTER_CANONICALIZATION_ID = id("RFC8785_JCS") as Hex;
export const MUSEUM_MASTER_CANONICALIZATION_HASH = "0xbc33af15c6b6374052871a5fdfa255f900f56fa594f650b2d0814c681fdb35a9" as Hex;
export const MUSEUM_MASTER_SCHEMA_BYTES = 1042n;
export const MUSEUM_MASTER_WAIVER_SCHEMA_BYTES = 2121n;
export const MUSEUM_MASTER_PROFILE_ID = id("STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1") as Hex;
export const MUSEUM_MASTER_PROFILE_BYTES = 2039n;
export const MUSEUM_MASTER_CANONICALIZATION_BYTES = 362n;
export const MUSEUM_CORE_CONDITION_INTERFACE_ID = "0x02d968bb" as Hex;
export const MUSEUM_CORE_FLOOR_INTERFACE_ID = "0x5243bb3a" as Hex;
export const MUSEUM_CORE_TIER_INTERFACE_ID = "0xc10ccea9" as Hex;
export const MUSEUM_CONSERVATION_TIER_INTERFACE_ID = "0x76484197" as Hex;
export const MUSEUM_MASTER_SELECTION_INTERFACE_ID = "0xe3481c95" as Hex;
export const MUSEUM_CONDITION_SOURCES_INTERFACE_ID = "0xa621c1b7" as Hex;
/** Binding capability only. This module exposes no pending sale-floor receipt writer. */
export const MUSEUM_CONSERVATION_FLOOR_INTERFACE_ID = "0xaf0adf33" as Hex;

export interface MuseumAnchorMasterCoordinates { readonly chainId: bigint; readonly core: Address; readonly executor: Address; readonly metadata: Address; readonly masterSelection: Address; readonly schemaRegistry: Address; readonly externalCoverage: Address }
export interface MuseumAnchorCoordinates { readonly chainId: bigint; readonly core: Address; readonly executor: Address }
export interface MuseumMasterRecordPolicy { readonly family: Hex; readonly authorizationMask: bigint; readonly admitted: boolean }
export interface MuseumAnchorBindingState { readonly target: Address; readonly runtimeCodeHash: Hex }
export interface MuseumMasterHashRef { readonly algorithm: bigint; readonly digest: Hex; readonly canonicalizationId: Hex }
export interface MuseumMasterCollectionRecord { readonly recordType: Hex; readonly subjectId: Hex; readonly contentHash: MuseumMasterHashRef; readonly uri: string; readonly schemaId: Hex; readonly signatureScheme: Hex; readonly signatureHash: MuseumMasterHashRef; readonly effectiveAt: bigint }
export interface MuseumMasterReference { readonly algorithm: bigint; readonly canonicalizationId: Hex; readonly digest: Hex; readonly uri: string }
export interface MuseumMasterArtist { readonly artistId: Hex; readonly bindingGeneration: bigint; readonly bindingHash: Hex }
export interface MuseumMasterWaivedObject { readonly objectId: Hex; readonly mediaClass: 0n | 1n | 2n | 3n | 4n; readonly masterRoles: readonly (0n | 1n)[] }
export interface MuseumMasterWaiver { readonly subjectId: Hex; readonly artist: MuseumMasterArtist; readonly scopeSubjectId: Hex; readonly mediaObjects: readonly MuseumMasterWaivedObject[]; readonly waiverStatement: MuseumMasterReference; readonly reason: string; readonly predecessor: Hex }
export interface MuseumMaster { readonly subjectId: Hex; readonly selectedMediaManifestHash: Hex; readonly mediaSlot: bigint; readonly displayHash: Hex; readonly masterRole: 0n | 1n; readonly masterObjectHash: Hex; readonly coverageHash: Hex; readonly predecessor: Hex }
export interface MuseumMasterPublicationEvidence { readonly attestationRecordHash: Hex; readonly artistId: Hex; readonly bindingHash: Hex; readonly bindingGeneration: bigint; readonly signer: Address; readonly authorityClass: bigint; readonly requiredCapability: bigint; readonly signedAt: bigint; readonly publicationHash: Hex }
export interface MuseumMasterAssociation { readonly artistId: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly identityRecordHash: Hex }
export interface MuseumMasterRecordEvidence { readonly recordHash: Hex; readonly payloadHash: Hex; readonly recorder: Address; readonly authorizationClass: bigint; readonly recordedAt: bigint; readonly recordIndex: bigint; readonly recordChainHash: Hex; readonly receiptHash: Hex; readonly publication: MuseumMasterPublicationEvidence; readonly publicationEvidenceHash: Hex }
export interface MuseumMasterSelection { readonly status: 0n | 1n | 2n; readonly subjectId: Hex; readonly manifestHash: Hex; readonly mediaSlot: bigint; readonly displayHash: Hex; readonly objectId: Hex; readonly original: MuseumMasterRecordEvidence; readonly association: MuseumMasterAssociation; readonly masterObjectHash: Hex; readonly coverageHash: Hex; readonly masterRole: 0n | 1n; readonly predecessor: Hex; readonly revision: bigint; readonly selectionHash: Hex }
export interface MuseumMasterRecordReceipt { readonly collectionId: bigint; readonly recorder: Address; readonly authorizationClass: bigint; readonly recordedAt: bigint; readonly recordIndex: bigint; readonly recordChainHash: Hex; readonly schemaDefinitionHash: Hex; readonly canonicalizationDefinitionHash: Hex; readonly artistAuthorization: Hex }
export interface MuseumMasterMediaContext { readonly subjectId: Hex; readonly manifestHash: Hex; readonly inventoryHash: Hex; readonly occupiedMask: bigint }
export interface MuseumMasterCanonicalPayload { readonly canonical: Hex; readonly contentHash: Hex; readonly byteLength: bigint }
export interface MuseumMasterPublication { readonly metadataHost: Address; readonly recorder: Address; readonly collectionId: bigint; readonly subjectId: Hex; readonly recordType: Hex; readonly schemaId: Hex; readonly canonicalizationId: Hex; readonly payloadAlgorithm: bigint; readonly payloadHash: Hex; readonly uriHash: Hex; readonly effectiveAt: bigint; readonly candidateRecordHash: Hex }

export const MUSEUM_MASTER_HASH_REF_TUPLE = "tuple(uint16 algorithm,bytes digest,bytes32 canonicalizationId)";
export const MUSEUM_MASTER_COLLECTION_RECORD_TUPLE = `tuple(bytes32 recordType,bytes32 subjectId,${MUSEUM_MASTER_HASH_REF_TUPLE} contentHash,string uri,bytes32 schemaId,bytes32 signatureScheme,${MUSEUM_MASTER_HASH_REF_TUPLE} signatureHash,uint64 effectiveAt)`;
export const MUSEUM_MASTER_REFERENCE_TUPLE = "tuple(uint16 algorithm,bytes32 canonicalizationId,bytes digest,string uri)";
export const MUSEUM_MASTER_ARTIST_TUPLE = "tuple(bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash)";
export const MUSEUM_MASTER_WAIVED_OBJECT_TUPLE = "tuple(bytes32 objectId,uint8 mediaClass,uint8[] masterRoles)";
export const MUSEUM_MASTER_WAIVER_TUPLE = `tuple(bytes32 subjectId,${MUSEUM_MASTER_ARTIST_TUPLE} artist,bytes32 scopeSubjectId,${MUSEUM_MASTER_WAIVED_OBJECT_TUPLE}[] mediaObjects,${MUSEUM_MASTER_REFERENCE_TUPLE} waiverStatement,string reason,bytes32 predecessor)`;
export const MUSEUM_MASTER_TUPLE = "tuple(bytes32 subjectId,bytes32 selectedMediaManifestHash,uint8 mediaSlot,bytes32 displayHash,uint8 masterRole,bytes32 masterObjectHash,bytes32 coverageHash,bytes32 predecessor)";
export const MUSEUM_MASTER_PUBLICATION_EVIDENCE_TUPLE = "tuple(bytes32 attestationRecordHash,bytes32 artistId,bytes32 bindingHash,uint64 bindingGeneration,address signer,uint8 authorityClass,uint32 requiredCapability,uint64 signedAt,bytes32 publicationHash)";
export const MUSEUM_MASTER_ASSOCIATION_TUPLE = "tuple(bytes32 artistId,bytes32 bindingHash,uint64 generation,bytes32 identityRecordHash)";
export const MUSEUM_MASTER_RECORD_EVIDENCE_TUPLE = `tuple(bytes32 recordHash,bytes32 payloadHash,address recorder,uint8 authorizationClass,uint64 recordedAt,uint64 recordIndex,bytes32 recordChainHash,bytes32 receiptHash,${MUSEUM_MASTER_PUBLICATION_EVIDENCE_TUPLE} publication,bytes32 publicationEvidenceHash)`;
export const MUSEUM_MASTER_SELECTION_TUPLE = `tuple(uint8 status,bytes32 subjectId,bytes32 manifestHash,uint8 mediaSlot,bytes32 displayHash,bytes32 objectId,${MUSEUM_MASTER_RECORD_EVIDENCE_TUPLE} original,${MUSEUM_MASTER_ASSOCIATION_TUPLE} association,bytes32 masterObjectHash,bytes32 coverageHash,uint8 masterRole,bytes32 predecessor,uint64 revision,bytes32 selectionHash)`;
export const MUSEUM_MASTER_RECORD_RECEIPT_TUPLE = "tuple(uint256 collectionId,address recorder,uint8 authorizationClass,uint64 recordedAt,uint64 recordIndex,bytes32 recordChainHash,bytes32 schemaDefinitionHash,bytes32 canonicalizationDefinitionHash,bytes32 artistAuthorization)";
export const MUSEUM_MASTER_MEDIA_CONTEXT_TUPLE = "tuple(bytes32 subjectId,bytes32 manifestHash,bytes32 inventoryHash,uint8 occupiedMask)";
export const MUSEUM_MASTER_RECORD_POLICY_TUPLE = "tuple(bytes32 family,uint16 authorizationMask,bool admitted)";
export const MUSEUM_MASTER_PUBLICATION_TUPLE = CURRENT_ARTIST_ATTESTATION_PUBLICATION_TUPLE;
const coder = AbiCoder.defaultAbiCoder(), zero = ZeroHash as Hex;
function exact(v: unknown, keys: readonly string[]): void { if (!v || typeof v !== "object" || Array.isArray(v) || Reflect.ownKeys(v).length !== keys.length || Reflect.ownKeys(v).some(k => typeof k !== "string" || !keys.includes(k))) throw Error("Missing or unknown fields"); }
function uint(v: unknown, bits: number, positive = false): bigint { if (typeof v !== "bigint" || v < (positive ? 1n : 0n) || v >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`); return v; }
function bytes(v: unknown, width?: number): Hex { if (typeof v !== "string" || !isHexString(v, width) || v.length % 2 || width === undefined && v.length > 2 + 2 * MUSEUM_ANCHOR_MASTER_MAX_ABI_BYTES) throw Error("Expected bounded hex bytes"); return v.toLowerCase() as Hex; }
function nz(v: Hex): Hex { if (v === ZeroHash) throw Error("Expected nonzero hash"); return v; }
function address(v: unknown, nonzero = false): Address { if (typeof v !== "string") throw Error("Expected address"); const a = getAddress(v) as Address; if (nonzero && a === ZeroAddress) throw Error("Expected nonzero address"); return a; }
function text(v: unknown, maximum: number, empty = true): string { if (typeof v !== "string" || /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(v) || (!empty && !v.length) || toUtf8Bytes(v).length > maximum) throw Error("Expected bounded Unicode text"); return v; }
function dense(v: unknown, max: number): readonly unknown[] { if (!Array.isArray(v) || v.length > max || Reflect.ownKeys(v).length !== v.length + 1 || Array.from({ length: v.length }, (_, i) => i).some(i => !Object.hasOwn(v, i))) throw Error("Expected bounded dense array"); return v; }
function normal(p: ParamType, v: unknown, decode = false): unknown {
  if (p.baseType === "tuple") { if (!decode) exact(v, p.components!.map(c => c.name)); return Object.freeze(Object.fromEntries(p.components!.map((c, i) => [c.name, normal(c, decode ? (v as readonly unknown[])[i] : Reflect.get(v as object, c.name), decode)]))); }
  if (p.baseType === "array") return Object.freeze(dense(v, p.name === "masterRoles" ? 2 : 512).map(x => { const n = normal(p.arrayChildren!, x, decode); if (p.name === "masterRoles" && (n as bigint) > 1n) throw Error("Unknown master role"); return n; }));
  if (p.type === "address") return address(v);
  if (p.type === "bool") { if (typeof v !== "boolean") throw Error("Expected boolean"); return v; }
  if (p.type.startsWith("uint")) { const n = uint(v, Number(p.type.slice(4))); if (p.name === "status" && n > 2n || p.name === "masterRole" && n > 1n || p.name === "mediaClass" && n > 4n) throw Error("Unknown original enum"); return n; }
  if (p.type === "string") return text(v, p.name === "reason" ? 16384 : 2048);
  if (p.type.startsWith("bytes")) return bytes(v, Number(p.type.slice(5)) || undefined);
  throw Error("Unsupported original field");
}
function normalize<T>(tuple: string, v: T): T { return normal(ParamType.from(tuple), v) as T; }
function encode(tuple: string, v: unknown): Hex { const encoded = coder.encode([tuple], [normalize(tuple, v)]) as Hex; if ((encoded.length - 2) / 2 > MUSEUM_ANCHOR_MASTER_MAX_ABI_BYTES) throw Error("Encoded witness exceeds client allocation bound"); return encoded; }
function decode<T>(tuple: string, v: Hex): T { const raw = bytes(v), decoded = normal(ParamType.from(tuple), coder.decode([tuple], raw)[0], true) as T; if (encode(tuple, decoded) !== raw) throw Error("Noncanonical ABI witness"); return decoded; }
function hash(types: readonly (string | ParamType)[], values: readonly unknown[]): Hex { return keccak256(coder.encode(types, values)) as Hex; }
function same(a: unknown, b: unknown): boolean { if (a === b) return true; if (!a || !b || typeof a !== "object" || typeof b !== "object") return false; const keys = Reflect.ownKeys(a), other = Reflect.ownKeys(b); return keys.length === other.length && keys.every(k => other.includes(k) && same(Reflect.get(a, k), Reflect.get(b, k))); }
export function normalizeMuseumAnchorMasterCoordinates(v: MuseumAnchorMasterCoordinates): MuseumAnchorMasterCoordinates { exact(v, ["chainId", "core", "executor", "metadata", "masterSelection", "schemaRegistry", "externalCoverage"]); return Object.freeze({ chainId: uint(v.chainId, 256), core: address(v.core, true), executor: address(v.executor, true), metadata: address(v.metadata, true), masterSelection: address(v.masterSelection, true), schemaRegistry: address(v.schemaRegistry, true), externalCoverage: address(v.externalCoverage, true) }); }
export function normalizeMuseumAnchorBindingState(v: MuseumAnchorBindingState): MuseumAnchorBindingState { exact(v, ["target", "runtimeCodeHash"]); const target = address(v.target), runtimeCodeHash = bytes(v.runtimeCodeHash, 32); if ((target === ZeroAddress) !== (runtimeCodeHash === ZeroHash)) throw Error("Anchor address/code hash pair differs"); return Object.freeze({ target, runtimeCodeHash }); }
export function normalizeMuseumAnchorCoordinates(v: MuseumAnchorCoordinates): MuseumAnchorCoordinates { exact(v, ["chainId", "core", "executor"]); return Object.freeze({ chainId: uint(v.chainId, 256), core: address(v.core, true), executor: address(v.executor, true) }); }
export function normalizeMuseumMasterRecordPolicy(v: MuseumMasterRecordPolicy): MuseumMasterRecordPolicy { return normalize(MUSEUM_MASTER_RECORD_POLICY_TUPLE, v); }
export function encodeMuseumMasterRecordPolicy(v: MuseumMasterRecordPolicy): Hex { return encode(MUSEUM_MASTER_RECORD_POLICY_TUPLE, v); }
export function decodeMuseumMasterRecordPolicy(v: Hex): MuseumMasterRecordPolicy { return decode(MUSEUM_MASTER_RECORD_POLICY_TUPLE, v); }

export function normalizeMuseumMasterHashRef(v: MuseumMasterHashRef): MuseumMasterHashRef { return normalize(MUSEUM_MASTER_HASH_REF_TUPLE, v); }
export function encodeMuseumMasterHashRef(v: MuseumMasterHashRef): Hex { return encode(MUSEUM_MASTER_HASH_REF_TUPLE, v); }
export function decodeMuseumMasterHashRef(v: Hex): MuseumMasterHashRef { return decode(MUSEUM_MASTER_HASH_REF_TUPLE, v); }
export function normalizeMuseumMasterCollectionRecord(v: MuseumMasterCollectionRecord): MuseumMasterCollectionRecord { return normalize(MUSEUM_MASTER_COLLECTION_RECORD_TUPLE, v); }
export function encodeMuseumMasterCollectionRecord(v: MuseumMasterCollectionRecord): Hex { return encode(MUSEUM_MASTER_COLLECTION_RECORD_TUPLE, v); }
export function decodeMuseumMasterCollectionRecord(v: Hex): MuseumMasterCollectionRecord { return decode(MUSEUM_MASTER_COLLECTION_RECORD_TUPLE, v); }
export function normalizeMuseumMasterReference(v: MuseumMasterReference): MuseumMasterReference { return normalize(MUSEUM_MASTER_REFERENCE_TUPLE, v); }
export function encodeMuseumMasterReference(v: MuseumMasterReference): Hex { return encode(MUSEUM_MASTER_REFERENCE_TUPLE, v); }
export function decodeMuseumMasterReference(v: Hex): MuseumMasterReference { return decode(MUSEUM_MASTER_REFERENCE_TUPLE, v); }
export function normalizeMuseumMasterArtist(v: MuseumMasterArtist): MuseumMasterArtist { return normalize(MUSEUM_MASTER_ARTIST_TUPLE, v); }
export function encodeMuseumMasterArtist(v: MuseumMasterArtist): Hex { return encode(MUSEUM_MASTER_ARTIST_TUPLE, v); }
export function decodeMuseumMasterArtist(v: Hex): MuseumMasterArtist { return decode(MUSEUM_MASTER_ARTIST_TUPLE, v); }
export function normalizeMuseumMasterWaivedObject(v: MuseumMasterWaivedObject): MuseumMasterWaivedObject { return normalize(MUSEUM_MASTER_WAIVED_OBJECT_TUPLE, v); }
export function encodeMuseumMasterWaivedObject(v: MuseumMasterWaivedObject): Hex { return encode(MUSEUM_MASTER_WAIVED_OBJECT_TUPLE, v); }
export function decodeMuseumMasterWaivedObject(v: Hex): MuseumMasterWaivedObject { return decode(MUSEUM_MASTER_WAIVED_OBJECT_TUPLE, v); }
export function normalizeMuseumMasterWaiver(v: MuseumMasterWaiver): MuseumMasterWaiver { return normalize(MUSEUM_MASTER_WAIVER_TUPLE, v); }
export function encodeMuseumMasterWaiver(v: MuseumMasterWaiver): Hex { return encode(MUSEUM_MASTER_WAIVER_TUPLE, v); }
export function decodeMuseumMasterWaiver(v: Hex): MuseumMasterWaiver { return decode(MUSEUM_MASTER_WAIVER_TUPLE, v); }
export function normalizeMuseumMaster(v: MuseumMaster): MuseumMaster { return normalize(MUSEUM_MASTER_TUPLE, v); }
export function encodeMuseumMaster(v: MuseumMaster): Hex { return encode(MUSEUM_MASTER_TUPLE, v); }
export function decodeMuseumMaster(v: Hex): MuseumMaster { return decode(MUSEUM_MASTER_TUPLE, v); }
export function normalizeMuseumMasterPublicationEvidence(v: MuseumMasterPublicationEvidence): MuseumMasterPublicationEvidence { return normalize(MUSEUM_MASTER_PUBLICATION_EVIDENCE_TUPLE, v); }
export function encodeMuseumMasterPublicationEvidence(v: MuseumMasterPublicationEvidence): Hex { return encode(MUSEUM_MASTER_PUBLICATION_EVIDENCE_TUPLE, v); }
export function decodeMuseumMasterPublicationEvidence(v: Hex): MuseumMasterPublicationEvidence { return decode(MUSEUM_MASTER_PUBLICATION_EVIDENCE_TUPLE, v); }
export function normalizeMuseumMasterAssociation(v: MuseumMasterAssociation): MuseumMasterAssociation { return normalize(MUSEUM_MASTER_ASSOCIATION_TUPLE, v); }
export function encodeMuseumMasterAssociation(v: MuseumMasterAssociation): Hex { return encode(MUSEUM_MASTER_ASSOCIATION_TUPLE, v); }
export function decodeMuseumMasterAssociation(v: Hex): MuseumMasterAssociation { return decode(MUSEUM_MASTER_ASSOCIATION_TUPLE, v); }
export function normalizeMuseumMasterRecordEvidence(v: MuseumMasterRecordEvidence): MuseumMasterRecordEvidence { return normalize(MUSEUM_MASTER_RECORD_EVIDENCE_TUPLE, v); }
export function encodeMuseumMasterRecordEvidence(v: MuseumMasterRecordEvidence): Hex { return encode(MUSEUM_MASTER_RECORD_EVIDENCE_TUPLE, v); }
export function decodeMuseumMasterRecordEvidence(v: Hex): MuseumMasterRecordEvidence { return decode(MUSEUM_MASTER_RECORD_EVIDENCE_TUPLE, v); }
export function normalizeMuseumMasterSelection(v: MuseumMasterSelection): MuseumMasterSelection { return normalize(MUSEUM_MASTER_SELECTION_TUPLE, v); }
export function encodeMuseumMasterSelection(v: MuseumMasterSelection): Hex { return encode(MUSEUM_MASTER_SELECTION_TUPLE, v); }
export function decodeMuseumMasterSelection(v: Hex): MuseumMasterSelection { return decode(MUSEUM_MASTER_SELECTION_TUPLE, v); }
export function normalizeMuseumMasterRecordReceipt(v: MuseumMasterRecordReceipt): MuseumMasterRecordReceipt { return normalize(MUSEUM_MASTER_RECORD_RECEIPT_TUPLE, v); }
export function encodeMuseumMasterRecordReceipt(v: MuseumMasterRecordReceipt): Hex { return encode(MUSEUM_MASTER_RECORD_RECEIPT_TUPLE, v); }
export function decodeMuseumMasterRecordReceipt(v: Hex): MuseumMasterRecordReceipt { return decode(MUSEUM_MASTER_RECORD_RECEIPT_TUPLE, v); }
export function normalizeMuseumMasterMediaContext(v: MuseumMasterMediaContext): MuseumMasterMediaContext { return normalize(MUSEUM_MASTER_MEDIA_CONTEXT_TUPLE, v); }
export function encodeMuseumMasterMediaContext(v: MuseumMasterMediaContext): Hex { return encode(MUSEUM_MASTER_MEDIA_CONTEXT_TUPLE, v); }
export function decodeMuseumMasterMediaContext(v: Hex): MuseumMasterMediaContext { return decode(MUSEUM_MASTER_MEDIA_CONTEXT_TUPLE, v); }
export function normalizeMuseumMasterPublication(v: MuseumMasterPublication): MuseumMasterPublication { return normalize(MUSEUM_MASTER_PUBLICATION_TUPLE, v); }
export function encodeMuseumMasterPublication(v: MuseumMasterPublication): Hex { return encode(MUSEUM_MASTER_PUBLICATION_TUPLE, v); }
export function decodeMuseumMasterPublication(v: Hex): MuseumMasterPublication { return decode(MUSEUM_MASTER_PUBLICATION_TUPLE, v); }

const roles = ["SOURCE_MASTER", "PRINT_MASTER"] as const, classes = ["still_image", "print_destined", "audio", "video", "interactive_capture"] as const;
function json(v: string): string { return JSON.stringify(v); }
function safeUri(v: string): string { const uri = text(v, 2048, false); if (/[\u0000-\u0020\u007f]/u.test(uri) || !(uri.startsWith("ipfs://") && toUtf8Bytes(uri).length > 7 || uri.startsWith("ar://") && toUtf8Bytes(uri).length > 5 || uri.startsWith("https://") && uri.length > 8 && !["/", "?", "#"].includes(uri[8]!))) throw Error("Original content URI profile rejected"); return uri; }
function referenceJSON(v: MuseumMasterReference): string { const r = normalizeMuseumMasterReference(v), len = (r.digest.length - 2) / 2; if (r.algorithm < 1n || r.algorithm > 6n || r.canonicalizationId === ZeroHash || ((r.algorithm === 4n || r.algorithm === 5n) ? len === 0 || len > 128 : len !== 32)) throw Error("Invalid original reference"); return `{"hash":{"algorithm":${r.algorithm},"canonicalizationId":${json(r.canonicalizationId)},"digest":${json(r.digest)}},"uri":${json(safeUri(r.uri))}}`; }
function payload(value: string): MuseumMasterCanonicalPayload { const raw = toUtf8Bytes(value); if (!raw.length || raw.length > MUSEUM_ANCHOR_MASTER_MAX_PAYLOAD_BYTES) throw Error("Original JSON payload must be 1..8192 bytes"); const canonical = hexlify(raw) as Hex; return Object.freeze({ canonical, contentHash: keccak256(canonical) as Hex, byteLength: BigInt(raw.length) }); }
/** Full original fixed-key JSON, retaining witness order and exact Unicode scalars. */
export function museumMasterCanonical(value: MuseumMaster): MuseumMasterCanonicalPayload {
  const v = normalizeMuseumMaster(value); if (v.subjectId === ZeroHash || v.selectedMediaManifestHash === ZeroHash || v.mediaSlot < 1n || v.mediaSlot > 3n || v.displayHash === ZeroHash || v.masterObjectHash === ZeroHash || v.coverageHash === ZeroHash) throw Error("Invalid original master witness");
  return payload(`{"coverageHash":${json(v.coverageHash)},"displayHash":${json(v.displayHash)},"masterObjectHash":${json(v.masterObjectHash)},"masterRole":${json(roles[Number(v.masterRole)]!)},"mediaSlot":${v.mediaSlot},"predecessor":${v.predecessor === ZeroHash ? "null" : json(v.predecessor)},"selectedMediaManifestHash":${json(v.selectedMediaManifestHash)},"subjectId":${json(v.subjectId)},"version":1}`);
}
export function museumMasterWaiverCanonical(value: MuseumMasterWaiver): MuseumMasterCanonicalPayload {
  const v = normalizeMuseumMasterWaiver(value), a = v.artist; if (v.subjectId === ZeroHash || v.scopeSubjectId !== v.subjectId || a.artistId === ZeroHash || a.bindingGeneration === 0n || a.bindingHash === ZeroHash || v.mediaObjects.length === 0) throw Error("Invalid original waiver witness");
  const seen = new Set<string>(); const rows = v.mediaObjects.map(r => { if (r.objectId === ZeroHash || seen.has(r.objectId) || !r.masterRoles.length || r.masterRoles.length === 2 && r.masterRoles[0] === r.masterRoles[1]) throw Error("Invalid or duplicate waived object"); seen.add(r.objectId); return `{"masterRoles":[${r.masterRoles.map(x => json(roles[Number(x)]!)).join(",")}],"mediaClass":${json(classes[Number(r.mediaClass)]!)},"objectId":${json(r.objectId)}}`; });
  return payload(`{"artist":{"artistId":${json(a.artistId)},"bindingGeneration":${json(a.bindingGeneration.toString())},"bindingHash":${json(a.bindingHash)}},"predecessor":${v.predecessor === ZeroHash ? "null" : json(v.predecessor)},"reason":${json(text(v.reason, 16384, false))},"scope":{"mediaObjects":[${rows.join(",")}],"subjectId":${json(v.scopeSubjectId)}},"subjectId":${json(v.subjectId)},"version":1,"waiverStatement":${referenceJSON(v.waiverStatement)}}`);
}
function parsePayload(value: Hex): Record<string, unknown> { const raw = bytes(value); if ((raw.length - 2) / 2 > 8192) throw Error("Payload exceeds original bound"); const parsed: unknown = JSON.parse(toUtf8String(raw)); if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw Error("Expected complete original JSON object"); return parsed as Record<string, unknown>; }
function decimal(v: unknown): bigint { if (typeof v !== "string" || !/^(0|[1-9][0-9]*)$/u.test(v)) throw Error("Expected canonical decimal string"); return BigInt(v); }
function enumeration(v: unknown, values: readonly string[]): bigint { const n = values.indexOf(v as string); if (n < 0) throw Error("Unknown JSON vocabulary"); return BigInt(n); }
export function decodeMuseumMasterCanonical(raw: Hex): MuseumMaster {
  const p = parsePayload(raw); exact(p, ["coverageHash", "displayHash", "masterObjectHash", "masterRole", "mediaSlot", "predecessor", "selectedMediaManifestHash", "subjectId", "version"]); if (p.version !== 1 || !Number.isInteger(p.mediaSlot)) throw Error("Invalid original JSON version/slot");
  const v = normalizeMuseumMaster({ subjectId: p.subjectId as Hex, selectedMediaManifestHash: p.selectedMediaManifestHash as Hex, mediaSlot: BigInt(p.mediaSlot as number), displayHash: p.displayHash as Hex, masterRole: enumeration(p.masterRole, roles) as 0n | 1n, masterObjectHash: p.masterObjectHash as Hex, coverageHash: p.coverageHash as Hex, predecessor: p.predecessor === null ? zero : p.predecessor as Hex }); if (museumMasterCanonical(v).canonical !== bytes(raw)) throw Error("Noncanonical original master JSON"); return v;
}
export function decodeMuseumMasterWaiverCanonical(raw: Hex): MuseumMasterWaiver {
  const p = parsePayload(raw); exact(p, ["artist", "predecessor", "reason", "scope", "subjectId", "version", "waiverStatement"]); if (p.version !== 1) throw Error("Invalid original JSON version");
  exact(p.artist, ["artistId", "bindingGeneration", "bindingHash"]); exact(p.scope, ["mediaObjects", "subjectId"]); exact(p.waiverStatement, ["hash", "uri"]);
  const artist = p.artist as Record<string, unknown>, scope = p.scope as Record<string, unknown>, statement = p.waiverStatement as Record<string, unknown>; exact(statement.hash, ["algorithm", "canonicalizationId", "digest"]); const r = statement.hash as Record<string, unknown>; if (!Number.isInteger(r.algorithm)) throw Error("Invalid reference algorithm");
  const mediaObjects = dense(scope.mediaObjects, 512).map(row => { exact(row, ["masterRoles", "mediaClass", "objectId"]); const q = row as Record<string, unknown>; return { objectId: q.objectId as Hex, mediaClass: enumeration(q.mediaClass, classes) as MuseumMasterWaivedObject["mediaClass"], masterRoles: dense(q.masterRoles, 2).map(role => enumeration(role, roles) as 0n | 1n) }; });
  const v = normalizeMuseumMasterWaiver({ subjectId: p.subjectId as Hex, artist: { artistId: artist.artistId as Hex, bindingGeneration: decimal(artist.bindingGeneration), bindingHash: artist.bindingHash as Hex }, scopeSubjectId: scope.subjectId as Hex, mediaObjects, waiverStatement: { algorithm: BigInt(r.algorithm as number), canonicalizationId: r.canonicalizationId as Hex, digest: r.digest as Hex, uri: statement.uri as string }, reason: p.reason as string, predecessor: p.predecessor === null ? zero : p.predecessor as Hex });
  if (museumMasterWaiverCanonical(v).canonical !== bytes(raw)) throw Error("Noncanonical original waiver JSON"); return v;
}
export function museumConservationTier(declared: Hex, completedMints: bigint): Readonly<{ declared: Hex; effective: Hex }> { const d = bytes(declared, 32), completed = uint(completedMints, 256); if (d !== ZeroHash && d !== MUSEUM_GRADE && d !== MUSEUM_GRADE_LITE && d !== MUSEUM_CONSERVATION_WAIVED) throw Error("Unknown original conservation tier"); return Object.freeze({ declared: d, effective: d === ZeroHash ? completed === 0n ? zero : MUSEUM_GRADE_LITE : d }); }
export function museumMasterCollectionSubject(chainId: bigint, core: Address, collectionId: bigint): Hex { return hash(["bytes32", "uint256", "address", "uint256"], [id("6529STREAM_SUBJECT_COLLECTION_V1"), uint(chainId, 256), address(core, true), uint(collectionId, 256, true)]); }
export function museumMasterObjectId(coordinates: MuseumAnchorMasterCoordinates, collectionId: bigint, subjectId: Hex, manifestHash: Hex, slot: bigint, displayHash: Hex): Hex { const c = normalizeMuseumAnchorMasterCoordinates(coordinates), s = uint(slot, 8); if (s < 1n || s > 3n) throw Error("Original slot must be 1..3"); return hash(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "uint8", "bytes32"], [id("6529STREAM_MEDIA_MASTER_SLOT_V1"), c.chainId, c.core, c.metadata, uint(collectionId, 256, true), nz(bytes(subjectId, 32)), nz(bytes(manifestHash, 32)), s, nz(bytes(displayHash, 32))]); }
export function museumMasterRecordHash(coordinates: MuseumAnchorMasterCoordinates, recorder: Address, collectionId: bigint, original: MuseumMasterCollectionRecord): Hex {
  const c = normalizeMuseumAnchorMasterCoordinates(coordinates), r = normalizeMuseumMasterCollectionRecord(original), ref = (v: MuseumMasterHashRef) => hash(["uint16", "bytes32", "bytes32"], [v.algorithm, keccak256(v.digest), v.canonicalizationId]);
  return hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"], [id("6529stream.preservation-record.v2"), c.chainId, c.metadata, c.core, address(recorder, true), uint(collectionId, 256, true), r.recordType, r.subjectId, ref(r.contentHash), keccak256(toUtf8Bytes(r.uri)), r.schemaId, r.signatureScheme, ref(r.signatureHash), r.effectiveAt]);
}
export function museumMasterRecordChainHash(coordinates: MuseumAnchorMasterCoordinates, collectionId: bigint, recordType: Hex, previous: Hex, recordHash: Hex, index: bigint): Hex { const c = normalizeMuseumAnchorMasterCoordinates(coordinates); return hash(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint64"], ["0x0e7a0feb85d4a4a3e90074703c19de35786e11afaae8f9868aa2a911bcfa1609", c.chainId, c.metadata, uint(collectionId, 256), bytes(recordType, 32), bytes(previous, 32), bytes(recordHash, 32), uint(index, 64)]); }
/** The original selection hashes the complete struct with its own commitment field zero. */
export function museumMasterSelectionHash(coordinates: MuseumAnchorMasterCoordinates, collectionId: bigint, value: MuseumMasterSelection): Hex { const c = normalizeMuseumAnchorMasterCoordinates(coordinates), v = normalizeMuseumMasterSelection(value); return hash(["bytes32", "uint256", "address", "address", "address", "address", "address", "bytes32", "uint256", MUSEUM_MASTER_SELECTION_TUPLE], [id("6529STREAM_MEDIA_MASTER_SELECTION_V1"), c.chainId, c.masterSelection, c.core, c.metadata, c.schemaRegistry, c.externalCoverage, MUSEUM_MASTER_PROFILE_HASH, uint(collectionId, 256), { ...v, selectionHash: zero }]); }
export function museumMasterFactsHash(coordinates: MuseumAnchorMasterCoordinates, collectionId: bigint, context: MuseumMasterMediaContext, displayHashes: readonly [Hex, Hex, Hex], association: MuseumMasterAssociation): Hex { const c = normalizeMuseumAnchorMasterCoordinates(coordinates), m = normalizeMuseumMasterMediaContext(context), a = normalizeMuseumMasterAssociation(association), hashes = dense(displayHashes, 3).map(x => bytes(x, 32)); if (hashes.length !== 3) throw Error("Exactly three native display slots required"); return hash(["bytes32", "uint256", "address", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32[3]", MUSEUM_MASTER_ASSOCIATION_TUPLE], [MUSEUM_MASTER_PROFILE_HASH, c.chainId, c.masterSelection, c.core, c.metadata, c.externalCoverage, uint(collectionId, 256), m.subjectId, m.manifestHash, m.inventoryHash, hashes, a]); }
export function museumMasterAppendFactsHash(previous: Hex, slot: bigint, selectionHash: Hex, archiveHash: Hex): Hex { const n = uint(slot, 8); if (n < 1n || n > 3n) throw Error("Original slot must be 1..3"); return hash(["bytes32", "uint8", "bytes32", "bytes32"], [bytes(previous, 32), n, bytes(selectionHash, 32), bytes(archiveHash, 32)]); }
function makeRecord(witness: MuseumMaster | MuseumMasterWaiver, uri: string, effectiveAt: bigint, waiver: boolean): MuseumMasterCollectionRecord { const p = waiver ? museumMasterWaiverCanonical(witness as MuseumMasterWaiver) : museumMasterCanonical(witness as MuseumMaster); return normalizeMuseumMasterCollectionRecord({ recordType: id(waiver ? "ARTIST_STATEMENT" : "MEDIA_RELATIONSHIP") as Hex, subjectId: witness.subjectId, contentHash: { algorithm: 1n, digest: p.contentHash, canonicalizationId: MUSEUM_MASTER_CANONICALIZATION_ID }, uri: text(uri, 2048), schemaId: waiver ? MUSEUM_MASTER_WAIVER_SCHEMA_ID : MUSEUM_MASTER_SCHEMA_ID, signatureScheme: zero, signatureHash: { algorithm: 0n, digest: "0x", canonicalizationId: zero }, effectiveAt: uint(effectiveAt, 64, true) }); }
export function museumMasterRecord(witness: MuseumMaster, uri: string, effectiveAt: bigint): MuseumMasterCollectionRecord { return makeRecord(normalizeMuseumMaster(witness), uri, effectiveAt, false); }
export function museumMasterWaiverRecord(witness: MuseumMasterWaiver, uri: string, effectiveAt: bigint): MuseumMasterCollectionRecord { return makeRecord(normalizeMuseumMasterWaiver(witness), uri, effectiveAt, true); }
/** Original 416-byte op24 publication statement; it is not a new signature domain. */
export function museumMasterPublication(coordinates: MuseumAnchorMasterCoordinates, recorder: Address, collectionId: bigint, original: MuseumMasterCollectionRecord): Readonly<{ publication: MuseumMasterPublication; statement: Hex; statementHash: Hex }> { const c = normalizeMuseumAnchorMasterCoordinates(coordinates), r = normalizeMuseumMasterCollectionRecord(original); if (r.contentHash.algorithm !== 1n || !isHexString(r.contentHash.digest, 32) || r.signatureScheme !== ZeroHash || r.signatureHash.algorithm !== 0n || r.signatureHash.digest !== "0x" || r.signatureHash.canonicalizationId !== ZeroHash) throw Error("Original publication requires unsigned keccak256 payload"); const publication = normalizeMuseumMasterPublication({ metadataHost: c.metadata, recorder: address(recorder, true), collectionId: uint(collectionId, 256, true), subjectId: r.subjectId, recordType: r.recordType, schemaId: r.schemaId, canonicalizationId: r.contentHash.canonicalizationId, payloadAlgorithm: r.contentHash.algorithm, payloadHash: r.contentHash.digest, uriHash: keccak256(toUtf8Bytes(r.uri)) as Hex, effectiveAt: r.effectiveAt, candidateRecordHash: museumMasterRecordHash(c, recorder, collectionId, r) }); const statement = coder.encode(["uint16", MUSEUM_MASTER_PUBLICATION_TUPLE], [1n, publication]) as Hex; return Object.freeze({ publication, statement, statementHash: keccak256(statement) as Hex }); }

export const CURRENT_MUSEUM_ANCHOR_MASTER_ABI = Object.freeze([
  "function conditionSources() view returns(address catalog,bytes32 runtimeCodeHash)",
  "function conditionSourcesTransition(address candidate) view returns(bytes32 scope,bytes32 oldHash,bytes32 newHash)",
  "function bindConditionSources(address candidate)",
  "function conservationFloor() view returns(address ledger,bytes32 runtimeCodeHash)",
  "function conservationFloorTransition(address candidate) view returns(bytes32 scope,bytes32 oldHash,bytes32 newHash)",
  "function bindConservationFloor(address candidate)",
  "function declaredConservationTier(uint256 collectionId) view returns(bytes32)",
  "function declareConservationTier(uint256 collectionId,bytes32 tier)",
  "function conservationTier(uint256 collectionId) view returns(bytes32 declared,bytes32 effective)",
  "function mediaObjectId(uint256 collectionId,bytes32 subjectId,bytes32 manifestHash,uint8 slot,bytes32 displayHash) view returns(bytes32)",
  "function collectionMediaContext(uint256 collectionId) view returns(bytes32 subjectId,bytes32 manifestHash,bytes32 inventoryHash,uint8 occupiedMask)",
  `function adoptMaster(uint256 collectionId,bytes32 recordHash,uint64 expectedRevision,${MUSEUM_MASTER_COLLECTION_RECORD_TUPLE} original,${MUSEUM_MASTER_TUPLE} witness) returns(${MUSEUM_MASTER_SELECTION_TUPLE})`,
  `function adoptWaiver(uint256 collectionId,uint8 slot,bytes32 manifestHash,bytes32 recordHash,uint64 expectedRevision,${MUSEUM_MASTER_COLLECTION_RECORD_TUPLE} original,${MUSEUM_MASTER_WAIVER_TUPLE} witness) returns(${MUSEUM_MASTER_SELECTION_TUPLE})`,
  `function currentMaster(uint256 collectionId,bytes32 subjectId,uint8 slot) view returns(${MUSEUM_MASTER_SELECTION_TUPLE})`,
  `function masterSelectionAt(uint256 collectionId,bytes32 subjectId,uint8 slot,uint64 revision) view returns(${MUSEUM_MASTER_SELECTION_TUPLE})`,
  "function requireCollectionMasters(uint256 collectionId,bytes32 subjectId) view returns(bytes32 factsHash)",
  `function recordCollectionRecordWithPayload(uint256 collectionId,${MUSEUM_MASTER_COLLECTION_RECORD_TUPLE} record,bytes payload) returns(bytes32)`,
  `function recordArtistCollectionRecordWithPayload(address recorder,uint256 collectionId,${MUSEUM_MASTER_COLLECTION_RECORD_TUPLE} record,bytes payload,bytes32 authorization) returns(bytes32)`,
]);
const abi = new Interface(CURRENT_MUSEUM_ANCHOR_MASTER_ABI), governanceAbi = new Interface(CURRENT_ARTIST_RECOVERY_GOVERNANCE_ABI);
function call(to: Address, method: string, args: readonly unknown[]): UnsignedCall { return Object.freeze({ to, value: 0n, data: abi.encodeFunctionData(method, args) as Hex }); }
export type MuseumAnchorMasterRequest =
  | { readonly kind: "declareConservationTier"; readonly collectionId: bigint; readonly tier: Hex }
  | { readonly kind: "recordCollectionRecordWithPayload"; readonly collectionId: bigint; readonly record: MuseumMasterCollectionRecord; readonly witness: MuseumMaster }
  | { readonly kind: "recordArtistCollectionRecordWithPayload"; readonly recorder: Address; readonly collectionId: bigint; readonly record: MuseumMasterCollectionRecord; readonly authorization: Hex; readonly witness: MuseumMasterWaiver }
  | { readonly kind: "adoptMaster"; readonly collectionId: bigint; readonly recordHash: Hex; readonly expectedRevision: bigint; readonly original: MuseumMasterCollectionRecord; readonly witness: MuseumMaster }
  | { readonly kind: "adoptWaiver"; readonly collectionId: bigint; readonly slot: bigint; readonly manifestHash: Hex; readonly recordHash: Hex; readonly expectedRevision: bigint; readonly original: MuseumMasterCollectionRecord; readonly witness: MuseumMasterWaiver };
export interface MuseumAnchorMasterCall { readonly coordinates: MuseumAnchorMasterCoordinates; readonly caller: Address; readonly request: MuseumAnchorMasterRequest; readonly call: UnsignedCall; readonly payload: MuseumMasterCanonicalPayload | null; readonly recordHash: Hex | null; readonly factsVerified: false }
/** No current authority, payload retention or archive coverage is inferred from these supplied fields. */
export function prepareMuseumAnchorMasterCall(coordinates: MuseumAnchorMasterCoordinates, caller: Address, input: MuseumAnchorMasterRequest): MuseumAnchorMasterCall {
  const c = normalizeMuseumAnchorMasterCoordinates(coordinates), actor = address(caller, true), collectionId = uint(input.collectionId, 256, true); let request: MuseumAnchorMasterRequest, target: UnsignedCall, canonical: MuseumMasterCanonicalPayload | null = null, recordHash: Hex | null = null;
  if (input.kind === "declareConservationTier") {
    exact(input, ["kind", "collectionId", "tier"]); const tier = museumConservationTier(input.tier, 0n).declared; if (tier === ZeroHash) throw Error("A declaration cannot be the undeclared sentinel"); request = Object.freeze({ kind: input.kind, collectionId, tier }); target = call(c.metadata, input.kind, [collectionId, tier]);
  } else if (input.kind === "recordCollectionRecordWithPayload" || input.kind === "recordArtistCollectionRecordWithPayload") {
    const waiver = input.kind === "recordArtistCollectionRecordWithPayload"; exact(input, waiver ? ["kind", "recorder", "collectionId", "record", "authorization", "witness"] : ["kind", "collectionId", "record", "witness"]);
    const witness = waiver ? normalizeMuseumMasterWaiver(input.witness as MuseumMasterWaiver) : normalizeMuseumMaster(input.witness as MuseumMaster), record = normalizeMuseumMasterCollectionRecord(input.record);
    canonical = waiver ? museumMasterWaiverCanonical(witness as MuseumMasterWaiver) : museumMasterCanonical(witness as MuseumMaster);
    if (!same(record, makeRecord(witness, record.uri, record.effectiveAt, waiver)) || witness.subjectId !== museumMasterCollectionSubject(c.chainId, c.core, collectionId)) throw Error("Record differs from complete canonical collection witness");
    if (input.kind === "recordArtistCollectionRecordWithPayload") { const recorder = address(input.recorder, true), authorization = nz(bytes(input.authorization, 32)); request = Object.freeze({ kind: input.kind, recorder, collectionId, record, authorization, witness: witness as MuseumMasterWaiver }); target = call(c.metadata, input.kind, [recorder, collectionId, record, canonical.canonical, authorization]); recordHash = museumMasterRecordHash(c, recorder, collectionId, record); }
    else { request = Object.freeze({ kind: input.kind, collectionId, record, witness: witness as MuseumMaster }); target = call(c.metadata, input.kind, [collectionId, record, canonical.canonical]); recordHash = museumMasterRecordHash(c, actor, collectionId, record); }
  } else if (input.kind === "adoptMaster" || input.kind === "adoptWaiver") {
    const waiver = input.kind === "adoptWaiver"; exact(input, waiver ? ["kind", "collectionId", "slot", "manifestHash", "recordHash", "expectedRevision", "original", "witness"] : ["kind", "collectionId", "recordHash", "expectedRevision", "original", "witness"]);
    const witness = waiver ? normalizeMuseumMasterWaiver(input.witness as MuseumMasterWaiver) : normalizeMuseumMaster(input.witness as MuseumMaster), original = normalizeMuseumMasterCollectionRecord(input.original), expectedRevision = uint(input.expectedRevision, 64); recordHash = nz(bytes(input.recordHash, 32));
    if (expectedRevision === (1n << 64n) - 1n || !same(original, makeRecord(witness, original.uri, original.effectiveAt, waiver)) || witness.subjectId !== museumMasterCollectionSubject(c.chainId, c.core, collectionId)) throw Error("Invalid original adoption witness or exhausted revision");
    canonical = waiver ? museumMasterWaiverCanonical(witness as MuseumMasterWaiver) : museumMasterCanonical(witness as MuseumMaster);
    if (input.kind === "adoptWaiver") { const slot = uint(input.slot, 8), manifestHash = nz(bytes(input.manifestHash, 32)); if (slot < 1n || slot > 3n) throw Error("Original slot must be 1..3"); request = Object.freeze({ kind: input.kind, collectionId, slot, manifestHash, recordHash, expectedRevision, original, witness: witness as MuseumMasterWaiver }); target = call(c.masterSelection, input.kind, [collectionId, slot, manifestHash, recordHash, expectedRevision, original, witness]); }
    else { request = Object.freeze({ kind: input.kind, collectionId, recordHash, expectedRevision, original, witness: witness as MuseumMaster }); target = call(c.masterSelection, input.kind, [collectionId, recordHash, expectedRevision, original, witness]); }
  } else throw Error("Unknown Museum operation");
  return Object.freeze({ coordinates: c, caller: actor, request, call: target, payload: canonical, recordHash, factsVerified: false });
}
export function normalizeMuseumAnchorMasterCall(v: MuseumAnchorMasterCall): MuseumAnchorMasterCall { exact(v, ["coordinates", "caller", "request", "call", "payload", "recordHash", "factsVerified"]); const expected = prepareMuseumAnchorMasterCall(v.coordinates, v.caller, v.request); if (!same(v, expected)) throw Error("Museum call differs from reconstruction"); return expected; }

export type MuseumAnchorReadRequest = { readonly kind: "conditionSources" | "conservationFloor" } | { readonly kind: "conditionSourcesTransition" | "conservationFloorTransition"; readonly candidate: Address };
export function prepareMuseumAnchorRead(coordinates: MuseumAnchorCoordinates, request: MuseumAnchorReadRequest): UnsignedCall { const c = normalizeMuseumAnchorCoordinates(coordinates); if (request.kind === "conditionSources" || request.kind === "conservationFloor") { exact(request, ["kind"]); return call(c.core, request.kind, []); } if (request.kind === "conditionSourcesTransition" || request.kind === "conservationFloorTransition") { exact(request, ["kind", "candidate"]); return call(c.core, request.kind, [address(request.candidate, true)]); } throw Error("Unknown anchor read"); }
export type MuseumMasterReadRequest =
  | { readonly kind: "declaredConservationTier" | "conservationTier" | "collectionMediaContext"; readonly collectionId: bigint }
  | { readonly kind: "currentMaster"; readonly collectionId: bigint; readonly subjectId: Hex; readonly slot: bigint }
  | { readonly kind: "masterSelectionAt"; readonly collectionId: bigint; readonly subjectId: Hex; readonly slot: bigint; readonly revision: bigint }
  | { readonly kind: "requireCollectionMasters"; readonly collectionId: bigint; readonly subjectId: Hex }
  | { readonly kind: "mediaObjectId"; readonly collectionId: bigint; readonly subjectId: Hex; readonly manifestHash: Hex; readonly slot: bigint; readonly displayHash: Hex };
/** Raw currentMaster lookup may return an empty selection; it is not a fresh eligibility check. */
export function prepareMuseumMasterRead(coordinates: MuseumAnchorMasterCoordinates, request: MuseumMasterReadRequest): UnsignedCall {
  const c = normalizeMuseumAnchorMasterCoordinates(coordinates), collectionId = uint(request.collectionId, 256);
  switch (request.kind) {
    case "declaredConservationTier": case "conservationTier": case "collectionMediaContext": exact(request, ["kind", "collectionId"]); return call(request.kind === "declaredConservationTier" ? c.core : request.kind === "conservationTier" ? c.metadata : c.masterSelection, request.kind, [collectionId]);
    case "currentMaster": exact(request, ["kind", "collectionId", "subjectId", "slot"]); return call(c.masterSelection, request.kind, [collectionId, bytes(request.subjectId, 32), uint(request.slot, 8)]);
    case "masterSelectionAt": exact(request, ["kind", "collectionId", "subjectId", "slot", "revision"]); return call(c.masterSelection, request.kind, [collectionId, bytes(request.subjectId, 32), uint(request.slot, 8), uint(request.revision, 64, true)]);
    case "requireCollectionMasters": exact(request, ["kind", "collectionId", "subjectId"]); return call(c.masterSelection, request.kind, [collectionId, bytes(request.subjectId, 32)]);
    case "mediaObjectId": exact(request, ["kind", "collectionId", "subjectId", "manifestHash", "slot", "displayHash"]); museumMasterObjectId(c, collectionId, request.subjectId, request.manifestHash, request.slot, request.displayHash); return call(c.masterSelection, request.kind, [collectionId, bytes(request.subjectId, 32), bytes(request.manifestHash, 32), request.slot, bytes(request.displayHash, 32)]);
    default: throw Error("Unknown Museum read");
  }
}

export interface MuseumAnchorTransition { readonly scope: Hex; readonly oldHash: Hex; readonly newHash: Hex }
export interface MuseumAnchorBindingRequest { readonly kind: "conditionSources" | "conservationFloor"; readonly candidate: Address; readonly runtimeCodeHash: Hex; readonly previous: MuseumAnchorBindingState }
export interface MuseumAnchorBindingPlan { readonly coordinates: MuseumAnchorCoordinates; readonly request: MuseumAnchorBindingRequest; readonly actionClass: 1n; readonly transition: MuseumAnchorTransition; readonly call: UnsignedCall; readonly governanceCall: MintFallbackGovernanceCall; readonly factsVerified: false }
export function prepareMuseumAnchorBinding(coordinates: MuseumAnchorCoordinates, input: MuseumAnchorBindingRequest): MuseumAnchorBindingPlan {
  const c = normalizeMuseumAnchorCoordinates(coordinates); exact(input, ["kind", "candidate", "runtimeCodeHash", "previous"]); if (input.kind !== "conditionSources" && input.kind !== "conservationFloor") throw Error("Unknown permanent anchor"); const candidate = address(input.candidate, true), runtimeCodeHash = nz(bytes(input.runtimeCodeHash, 32)), previous = normalizeMuseumAnchorBindingState(input.previous); if (previous.target !== ZeroAddress) throw Error("Permanent anchor already bound");
  const family = input.kind === "conditionSources" ? "CONDITION_SOURCES" : "CONSERVATION_FLOOR", scope = hash(["bytes32", "uint256", "address"], [id(`6529STREAM_CORE_${family}_SCOPE_V1`), c.chainId, c.core]);
  const state = (target: Address, pin: Hex) => hash(["bytes32", "bytes32", "address", "bytes32"], [id(`6529STREAM_CORE_${family}_STATE_V1`), scope, target, pin]); const transition = Object.freeze({ scope, oldHash: state(ZeroAddress as Address, zero), newHash: state(candidate, runtimeCodeHash) }), target = call(c.core, input.kind === "conditionSources" ? "bindConditionSources" : "bindConservationFloor", [candidate]);
  return Object.freeze({ coordinates: c, request: Object.freeze({ kind: input.kind, candidate, runtimeCodeHash, previous }), actionClass: 1n, transition, call: target, governanceCall: Object.freeze({ target: c.core, value: 0n, selector: target.data.slice(0, 10) as Hex, callDataHash: keccak256(target.data) as Hex, scopeHash: scope, oldValueHash: transition.oldHash, newValueHash: transition.newHash }), factsVerified: false });
}
export function normalizeMuseumAnchorBindingPlan(v: MuseumAnchorBindingPlan): MuseumAnchorBindingPlan { exact(v, ["coordinates", "request", "actionClass", "transition", "call", "governanceCall", "factsVerified"]); const expected = prepareMuseumAnchorBinding(v.coordinates, v.request); if (!same(v, expected)) throw Error("Anchor binding differs from reconstruction"); return expected; }
export type MuseumAnchorGovernanceWindow = MintFallbackGovernanceWindow;
export const normalizeMuseumAnchorGovernanceWindow = normalizeMintFallbackGovernanceWindow;
export interface MuseumAnchorGovernanceBatch { readonly plan: MuseumAnchorBindingPlan; readonly nonce: bigint; readonly window: MuseumAnchorGovernanceWindow; readonly callsHash: Hex; readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex; readonly actionId: Hex; readonly publicationKey: Hex; readonly publicationCall: UnsignedCall; readonly scheduleCall: UnsignedCall; readonly executionCall: UnsignedCall; readonly factsVerified: false }
export function assertMuseumAnchorGovernanceWindow(window: MuseumAnchorGovernanceWindow, scheduleTimestamp: bigint): void { const w = normalizeMuseumAnchorGovernanceWindow(window), now = uint(scheduleTimestamp, 64); if (now > (1n << 64n) - 1n - 31536000n || w.notBefore < now + 172800n || w.expiresAfter - w.notBefore < 604800n || w.expiresAfter > now + 31536000n) throw Error("Original class1 governance window rejected"); }
export function museumAnchorGovernanceBatch(input: MuseumAnchorBindingPlan, nonce: bigint, window: MuseumAnchorGovernanceWindow): MuseumAnchorGovernanceBatch {
  const plan = normalizeMuseumAnchorBindingPlan(input), c = plan.coordinates, n = uint(nonce, 256), w = normalizeMuseumAnchorGovernanceWindow(window), calls = [plan.governanceCall], data = [plan.call.data]; if (w.expiresAfter - w.notBefore < 604800n) throw Error("Original seven-day open window required");
  const callsHash = hash(["bytes32", `${ARTIST_RECOVERY_GOVERNANCE_CALL_TUPLE}[]`], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
  const aggregate = (domain: string, field: "scopeHash" | "oldValueHash" | "newValueHash") => hash(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, calls.map(call => call[field])]);
  const scopeHash = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash"), oldValueHash = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash"), newValueHash = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash");
  const actionId = hash(["bytes32", "uint256", "address", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64", "uint64", "bytes32", "bytes32"], ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", c.chainId, c.executor, 1n, callsHash, scopeHash, oldValueHash, newValueHash, n, w.notBefore, w.expiresAfter, w.reasonHash, w.manifestHash]);
  const gov = (method: string, args: readonly unknown[]): UnsignedCall => Object.freeze({ to: c.executor, value: 0n, data: governanceAbi.encodeFunctionData(method, args) as Hex });
  return Object.freeze({ plan, nonce: n, window: w, callsHash, scopeHash, oldValueHash, newValueHash, actionId, publicationKey: keccak256(plan.governanceCall.callDataHash) as Hex, publicationCall: gov("publishGovernanceCallData", [data]), scheduleCall: gov("scheduleGovernanceBatch", [1n, calls, scopeHash, oldValueHash, newValueHash, w.notBefore, w.expiresAfter, w.reasonHash, w.reasonURI, w.manifestHash]), executionCall: gov("executeGovernanceBatch", [actionId, calls, data]), factsVerified: false });
}
export function normalizeMuseumAnchorGovernanceBatch(v: MuseumAnchorGovernanceBatch): MuseumAnchorGovernanceBatch { exact(v, ["plan", "nonce", "window", "callsHash", "scopeHash", "oldValueHash", "newValueHash", "actionId", "publicationKey", "publicationCall", "scheduleCall", "executionCall", "factsVerified"]); const expected = museumAnchorGovernanceBatch(v.plan, v.nonce, v.window); if (!same(v, expected)) throw Error("Anchor governance batch differs from reconstruction"); return expected; }
