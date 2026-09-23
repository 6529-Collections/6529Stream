import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, hexlify, id, isHexString, keccak256, toUtf8Bytes, toUtf8String } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import { prepareCurrentArtistOperation, type CurrentArtistAttestation, type PreparedCurrentArtistOperation } from "./current-artist.js";

/** Additive ABI102 profile; earlier Artist fixtures retain their original qualifications. */
export const PERSONHOOD_SOURCE = "70c0d9c37f6435c480b87083af8d1cbd4fa7098d";
export const PERSONHOOD_PROFILE_ID = id("STREAM_ARTIST_PERSONHOOD_REFERENCE_JSON_PROFILE_V1") as Hex;
export const PERSONHOOD_PROFILE_HASH = "0x06eaf449a0abe6a4305706d589bc597f14f7d23f62acc661b4b1fff128b921c3" as Hex;
export const PERSONHOOD_EVIDENCE_SCHEMA = id("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1") as Hex;
export const PERSONHOOD_WAIVER_SCHEMA = id("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1") as Hex;
export const PERSONHOOD_SUMMARY_TAG = id("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1") as Hex;
export const PERSONHOOD_PAYLOAD_TYPE = id("ARTIST_PERSONHOOD_PROOF_SUMMARY") as Hex;
/** IStreamGeneralAttestations own selectors, excluding inherited IERC165. */
export const PERSONHOOD_GENERAL_INTERFACE_ID = "0xb4afac56" as Hex;
export const PERSONHOOD_STATUS = Object.freeze({ NONE: 0n, WAIVER: 1n, RESOLVED: 2n, STALE: 3n, UNRESOLVED: 4n });
export interface ArtistPersonhoodReference {
  readonly version: bigint; readonly profileHash: Hex; readonly artistRegistry: Address; readonly artistId: Hex;
  readonly operativeIdentityRecordHash: Hex; readonly notarizationHost: Address;
  readonly notarizationRuntimeHash: Hex; readonly notarizationRecordHash: Hex;
}
export interface ArtistPersonhoodSummary {
  readonly version: bigint; readonly chainId: bigint; readonly nativeRecordHash: Hex; readonly statementHash: Hex;
  readonly artistId: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly collectionId: bigint;
  readonly identityRecordHash: Hex; readonly evidenceReference: ArtistPersonhoodReference;
  readonly originalRegistryCodeHash: Hex; readonly core: Address; readonly coreCodeHash: Hex;
  readonly moduleRegistry: Address; readonly moduleRegistryCodeHash: Hex; readonly schemaRegistry: Address;
  readonly schemaRegistryCodeHash: Hex; readonly chunkStore: Address; readonly chunkStoreCodeHash: Hex;
  readonly definitionFactsHashes: readonly Hex[]; readonly notarizationCollectionId: bigint;
  readonly attestationType: Hex; readonly subjectId: Hex; readonly recorder: Address; readonly documentaryHash: Hex;
  readonly moduleIdentityHash: Hex; readonly carriers: readonly Address[]; readonly carrierCodeHashes: readonly Hex[];
}
export interface ArtistPersonhoodNativeRecord {
  readonly recordHash: Hex; readonly subjectStateHash: Hex; readonly schemaId: Hex; readonly statementHash: Hex;
  readonly generation: bigint; readonly signedAt: bigint; readonly signer: Address;
}
export interface ArtistPersonhoodSelection {
  readonly nativeRecord: ArtistPersonhoodNativeRecord; readonly sourceRegistry: Address;
  readonly evidenceReference: ArtistPersonhoodReference; readonly notarizationType: Hex; readonly recorder: Address;
  readonly notarizationHead: Hex; readonly identityCurrent: boolean; readonly notarizationCurrent: boolean; readonly status: bigint;
}
export interface ArtistPersonhoodRequest {
  readonly chainId: bigint; readonly registry: Address; readonly core: Address; readonly caller: Address;
  readonly collectionId: bigint; readonly reference: ArtistPersonhoodReference; readonly nonce: bigint;
  readonly signedAt: bigint; readonly signature: Hex; readonly statementURI: string;
}
export interface ArtistPersonhoodPrepared {
  readonly request: ArtistPersonhoodRequest; readonly statement: Hex; readonly message: CurrentArtistAttestation;
  readonly operation: PreparedCurrentArtistOperation<CurrentArtistAttestation>; readonly call: UnsignedCall;
  readonly factsVerified: false;
}
export const PERSONHOOD_REFERENCE_TUPLE = "(uint16 version,bytes32 profileHash,address artistRegistry,bytes32 artistId,bytes32 operativeIdentityRecordHash,address notarizationHost,bytes32 notarizationRuntimeHash,bytes32 notarizationRecordHash)";
export const PERSONHOOD_NATIVE_RECORD_TUPLE = "(bytes32 recordHash,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,uint64 generation,uint64 signedAt,address signer)";
export const PERSONHOOD_SUMMARY_TUPLE = `(uint16 version,uint256 chainId,bytes32 nativeRecordHash,bytes32 statementHash,bytes32 artistId,bytes32 bindingHash,uint64 generation,uint256 collectionId,bytes32 identityRecordHash,${PERSONHOOD_REFERENCE_TUPLE} evidenceReference,bytes32 originalRegistryCodeHash,address core,bytes32 coreCodeHash,address moduleRegistry,bytes32 moduleRegistryCodeHash,address schemaRegistry,bytes32 schemaRegistryCodeHash,address chunkStore,bytes32 chunkStoreCodeHash,bytes32[4] definitionFactsHashes,uint256 notarizationCollectionId,bytes32 attestationType,bytes32 subjectId,address recorder,bytes32 documentaryHash,bytes32 moduleIdentityHash,address[6] carriers,bytes32[6] carrierCodeHashes)`;
export const PERSONHOOD_SELECTION_TUPLE = `(${PERSONHOOD_NATIVE_RECORD_TUPLE} nativeRecord,address sourceRegistry,${PERSONHOOD_REFERENCE_TUPLE} evidenceReference,bytes32 notarizationType,address recorder,bytes32 notarizationHead,bool identityCurrent,bool notarizationCurrent,uint8 status)`;
const terms = "(uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,string statementURI)";
const authorization = "(uint256 nonce,uint64 time,bytes signature)";
export const CURRENT_ARTIST_PERSONHOOD_ABI = Object.freeze([
  `function recordArtistAttestation(${terms},${authorization},bytes statement) returns(bytes32)`,
  `function attestationDigest(${terms},${authorization}) view returns(bytes32)`,
  `function personhoodEvidence(uint256 collectionId,bytes32 artistId) view returns(${PERSONHOOD_SELECTION_TUPLE})`,
  "function personhoodEvidenceStatus(uint256 collectionId,bytes32 artistId) view returns(bytes32 nativeRecordHash,uint8 status)",
  `function personhoodProofSummary(bytes32 nativeRecordHash) view returns(${PERSONHOOD_SUMMARY_TUPLE})`,
  "function personhoodProofSummaryHash(bytes32 nativeRecordHash) view returns(bytes32)",
  "function auditPersonhoodEvidence(bytes32 nativeRecordHash) view returns(bytes32 documentaryHash,(bytes32 attestationType,address recorder,bytes32 head,bool current))",
  `event ArtistPersonhoodProofRetained(uint16 schemaVersion,bytes32 indexed nativeRecordHash,address indexed originalRegistry,bytes32 summaryHash,${PERSONHOOD_SUMMARY_TUPLE} summary)`,
]);
const abi = new Interface(CURRENT_ARTIST_PERSONHOOD_ABI), coder = AbiCoder.defaultAbiCoder();
function uint(v: unknown, bits: number, positive = false): bigint {
  if (typeof v !== "bigint" || v < (positive ? 1n : 0n) || v >= 1n << BigInt(bits)) throw Error("Expected bounded bigint");
  return v;
}
function address(v: unknown, empty = false): Address {
  if (typeof v !== "string") throw Error("Expected address");
  const a = getAddress(v) as Address;
  if (!empty && a === ZeroAddress) throw Error("Zero address");
  return a;
}
function hash(v: unknown, empty = false): Hex {
  if (typeof v !== "string" || !isHexString(v, 32) || (!empty && v.toLowerCase() === ZeroHash)) throw Error("Expected bytes32");
  return v.toLowerCase() as Hex;
}
function keys(v: unknown, names: readonly string[]): void {
  if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).sort().join(",") !== [...names].sort().join(",")) throw Error("Unexpected object fields");
}
function plain(type: ParamType, value: any): any {
  if (type.baseType === "tuple") return Object.fromEntries(type.components!.map((child, i) => [child.name, plain(child, value[i])]));
  if (type.baseType === "array") return Object.freeze(value.map((v: any) => plain(type.arrayChildren!, v)));
  return value;
}
function decoded(tuple: string, raw: Hex, bytes: number): any {
  if (!isHexString(raw, bytes)) throw Error("Unexpected canonical ABI byte length");
  const [v] = coder.decode([tuple], raw);
  if (coder.encode([tuple], [v]).toLowerCase() !== raw.toLowerCase()) throw Error("Noncanonical ABI bytes");
  return plain(ParamType.from(tuple), v);
}
function freeze<T>(value: T): T {
  if (value && typeof value === "object") { for (const item of Object.values(value)) freeze(item); Object.freeze(value); }
  return value;
}
function typedInput(type: ParamType, value: any): void {
  if (type.baseType === "tuple") {
    keys(value, type.components!.map(v => v.name));
    for (const field of type.components!) typedInput(field, value[field.name]);
  } else if (type.baseType === "array") {
    if (!Array.isArray(value) || value.length !== type.arrayLength) throw Error("Expected fixed tuple array");
    for (const item of value) typedInput(type.arrayChildren!, item);
  } else if (type.type.startsWith("uint")) uint(value, Number(type.type.slice(4)));
  else if (type.type === "address") address(value, true);
  else if (type.type === "bytes32") hash(value, true);
}
export function normalizeArtistPersonhoodReference(v: ArtistPersonhoodReference): ArtistPersonhoodReference {
  keys(v, ["version", "profileHash", "artistRegistry", "artistId", "operativeIdentityRecordHash", "notarizationHost", "notarizationRuntimeHash", "notarizationRecordHash"]);
  if (uint(v.version, 16) !== 1n || hash(v.profileHash) !== PERSONHOOD_PROFILE_HASH) throw Error("Unsupported personhood reference profile");
  return Object.freeze({ version: 1n, profileHash: PERSONHOOD_PROFILE_HASH, artistRegistry: address(v.artistRegistry), artistId: hash(v.artistId),
    operativeIdentityRecordHash: hash(v.operativeIdentityRecordHash), notarizationHost: address(v.notarizationHost),
    notarizationRuntimeHash: hash(v.notarizationRuntimeHash), notarizationRecordHash: hash(v.notarizationRecordHash) });
}
/** The source's eight keys, order, lowercase hex and exact 590 bytes; this is not general JSON canonicalization. */
export function encodeArtistPersonhoodReference(input: ArtistPersonhoodReference): Hex {
  const p = normalizeArtistPersonhoodReference(input);
  const text = JSON.stringify({ artistId: p.artistId, artistRegistry: p.artistRegistry.toLowerCase(), notarizationHost: p.notarizationHost.toLowerCase(),
    notarizationRecordHash: p.notarizationRecordHash, notarizationRuntimeHash: p.notarizationRuntimeHash,
    operativeIdentityRecordHash: p.operativeIdentityRecordHash, profileHash: p.profileHash, version: 1 });
  const bytes = toUtf8Bytes(text);
  if (bytes.length !== 590) throw Error("Personhood reference must be 590 bytes");
  return hexlify(bytes) as Hex;
}
export function decodeArtistPersonhoodReference(raw: Hex): ArtistPersonhoodReference {
  if (!isHexString(raw, 590)) throw Error("Personhood reference must be 590 bytes");
  const p = JSON.parse(toUtf8String(raw));
  keys(p, ["version", "profileHash", "artistRegistry", "artistId", "operativeIdentityRecordHash", "notarizationHost", "notarizationRuntimeHash", "notarizationRecordHash"]);
  if (p.version !== 1) throw Error("Unsupported personhood reference version");
  const normalized = normalizeArtistPersonhoodReference({ ...p, version: 1n });
  if (encodeArtistPersonhoodReference(normalized) !== raw.toLowerCase()) throw Error("Noncanonical personhood reference");
  return normalized;
}
/** Zero is an absent summary. Present summaries are joined without treating hashes as authority. */
export function normalizeArtistPersonhoodSummary(input: ArtistPersonhoodSummary): ArtistPersonhoodSummary {
  const tuple = ParamType.from(PERSONHOOD_SUMMARY_TUPLE);
  typedInput(tuple, input);
  const raw = coder.encode([tuple], [input]) as Hex;
  const s = decoded(PERSONHOOD_SUMMARY_TUPLE, raw, 1536) as ArtistPersonhoodSummary;
  if (s.version === 0n) {
    if (raw !== "0x" + "00".repeat(1536)) throw Error("Nonzero absent personhood summary");
    return freeze(s);
  }
  if (s.version !== 1n) throw Error("Unsupported personhood summary version");
  const p = normalizeArtistPersonhoodReference(s.evidenceReference);
  uint(s.chainId, 256, true); uint(s.collectionId, 256, true); uint(s.generation, 64, true);
  for (const key of ["nativeRecordHash", "statementHash", "artistId", "bindingHash", "identityRecordHash", "originalRegistryCodeHash", "coreCodeHash", "moduleRegistryCodeHash", "schemaRegistryCodeHash", "chunkStoreCodeHash", "attestationType", "subjectId", "documentaryHash", "moduleIdentityHash"] as const) hash(s[key]);
  for (const a of [s.core, s.moduleRegistry, s.schemaRegistry, s.chunkStore, s.recorder, ...s.carriers]) address(a);
  for (const h of [...s.definitionFactsHashes, ...s.carrierCodeHashes]) hash(h);
  if (s.artistId !== p.artistId || s.identityRecordHash !== p.operativeIdentityRecordHash
    || s.statementHash !== keccak256(encodeArtistPersonhoodReference(p))) throw Error("Personhood summary reference join differs");
  return freeze(s);
}
export function encodeArtistPersonhoodSummary(input: ArtistPersonhoodSummary): Hex {
  return coder.encode([PERSONHOOD_SUMMARY_TUPLE], [normalizeArtistPersonhoodSummary(input)]) as Hex;
}
export function decodeArtistPersonhoodSummary(raw: Hex): ArtistPersonhoodSummary {
  return normalizeArtistPersonhoodSummary(decoded(PERSONHOOD_SUMMARY_TUPLE, raw, 1536));
}
export function artistPersonhoodSummaryHash(input: ArtistPersonhoodSummary): Hex {
  const s = normalizeArtistPersonhoodSummary(input);
  return s.version === 0n ? ZeroHash as Hex : keccak256(coder.encode(["bytes32", PERSONHOOD_SUMMARY_TUPLE], [PERSONHOOD_SUMMARY_TAG, s])) as Hex;
}
export function decodeArtistPersonhoodSelection(raw: Hex): ArtistPersonhoodSelection {
  const s = decoded(PERSONHOOD_SELECTION_TUPLE, raw, 704) as ArtistPersonhoodSelection;
  if (s.status > 4n) throw Error("Unknown personhood status");
  if (s.status === 0n) {
    if (raw.toLowerCase() !== "0x" + "00".repeat(704)) throw Error("Nonempty NONE personhood selection");
  } else {
    hash(s.nativeRecord.recordHash); hash(s.nativeRecord.subjectStateHash); hash(s.nativeRecord.statementHash);
    uint(s.nativeRecord.generation, 64, true); address(s.nativeRecord.signer);
    if (![PERSONHOOD_EVIDENCE_SCHEMA, PERSONHOOD_WAIVER_SCHEMA].includes(s.nativeRecord.schemaId)) throw Error("Non-personhood native head");
    if (s.evidenceReference.version !== 0n) {
      const reference = normalizeArtistPersonhoodReference(s.evidenceReference);
      if (s.nativeRecord.schemaId !== PERSONHOOD_EVIDENCE_SCHEMA || reference.artistRegistry !== s.sourceRegistry
        || reference.operativeIdentityRecordHash !== s.nativeRecord.subjectStateHash
        || keccak256(encodeArtistPersonhoodReference(reference)) !== s.nativeRecord.statementHash) throw Error("Selected native reference join differs");
    } else if (coder.encode([PERSONHOOD_REFERENCE_TUPLE], [s.evidenceReference]) !== "0x" + "00".repeat(256)) throw Error("Malformed absent reference");
    if (s.status === 1n && (s.nativeRecord.schemaId !== PERSONHOOD_WAIVER_SCHEMA || !s.identityCurrent)) throw Error("Inconsistent personhood waiver");
    if (s.status === 2n && (s.nativeRecord.schemaId !== PERSONHOOD_EVIDENCE_SCHEMA || !s.identityCurrent || !s.notarizationCurrent
      || s.evidenceReference.version !== 1n || s.evidenceReference.artistRegistry !== s.sourceRegistry
      || s.evidenceReference.operativeIdentityRecordHash !== s.nativeRecord.subjectStateHash
      || s.evidenceReference.notarizationRecordHash !== s.notarizationHead)) throw Error("Inconsistent resolved personhood head");
  }
  return freeze(s);
}
export function prepareArtistPersonhoodCall(input: ArtistPersonhoodRequest): ArtistPersonhoodPrepared {
  keys(input, ["chainId", "registry", "core", "caller", "collectionId", "reference", "nonce", "signedAt", "signature", "statementURI"]);
  const reference = normalizeArtistPersonhoodReference(input.reference), registry = address(input.registry);
  if (reference.artistRegistry !== registry) throw Error("Fresh reference must use its actual Registry domain");
  if (typeof input.statementURI !== "string" || /[\u0000-\u001f\u007f]/.test(input.statementURI)
    || Array.from(input.statementURI).some(c => c.length === 1 && c.charCodeAt(0) >= 0xd800 && c.charCodeAt(0) <= 0xdfff)
    || toUtf8Bytes(input.statementURI).length > 2048) throw Error("Invalid statement URI");
  if (!isHexString(input.signature, true) || input.signature.length > 2 + 4096 * 2) throw Error("Invalid bounded signature");
  const request = Object.freeze({ chainId: uint(input.chainId, 256, true), registry, core: address(input.core), caller: address(input.caller),
    collectionId: uint(input.collectionId, 256, true), reference, nonce: uint(input.nonce, 256), signedAt: uint(input.signedAt, 64),
    signature: input.signature.toLowerCase() as Hex, statementURI: input.statementURI });
  const statement = encodeArtistPersonhoodReference(reference);
  const message = Object.freeze({ core: request.core, collectionId: request.collectionId, subjectKind: 10n, subjectId: reference.artistId,
    subjectStateHash: reference.operativeIdentityRecordHash, schemaId: PERSONHOOD_EVIDENCE_SCHEMA, statementHash: keccak256(statement) as Hex,
    statementURIHash: keccak256(toUtf8Bytes(request.statementURI)) as Hex, nonce: request.nonce, signedAt: request.signedAt });
  const operation = prepareCurrentArtistOperation("artistAttestation", request.chainId, registry, message,
    { signature: request.signature, statementURI: request.statementURI, statement });
  return freeze({ request, statement, message, operation, call: operation.call, factsVerified: false as const });
}
export function normalizeArtistPersonhoodCall(input: ArtistPersonhoodPrepared): ArtistPersonhoodPrepared {
  const clean = prepareArtistPersonhoodCall(input.request);
  const json = (v: unknown) => JSON.stringify(v, (_, item) => typeof item === "bigint" ? item.toString() : item);
  if (json(clean) !== json(input)) throw Error("Changed personhood prepared call");
  return clean;
}
/** Original op24 record identity, with its admitted principal class and effective mined time. */
export function artistPersonhoodNativeRecordHash(input: ArtistPersonhoodPrepared, signer: Address, authorityClass: bigint, effectiveTime: bigint): Hex {
  const p = normalizeArtistPersonhoodCall(input), m = p.message;
  if (![1n, 3n, 4n].includes(authorityClass)) throw Error("Unsupported principal authority class");
  return keccak256(coder.encode(
    ["bytes32", "uint256", "address", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"), p.request.chainId, p.request.registry, m.core, m.collectionId, m.subjectKind,
      m.subjectId, m.subjectStateHash, m.schemaId, m.statementHash, m.statementURIHash, p.request.reference.artistId,
      address(signer), uint(authorityClass, 8), m.nonce, uint(effectiveTime, 64, true)])) as Hex;
}
export type ArtistPersonhoodReadMethod = "personhoodEvidence" | "personhoodEvidenceStatus" | "personhoodProofSummary" | "personhoodProofSummaryHash" | "auditPersonhoodEvidence";
export function prepareArtistPersonhoodRead(target: Address, method: ArtistPersonhoodReadMethod, args: readonly unknown[]): UnsignedCall {
  if (!["personhoodEvidence", "personhoodEvidenceStatus", "personhoodProofSummary", "personhoodProofSummaryHash", "auditPersonhoodEvidence"].includes(method)) throw Error("Unsupported personhood read");
  if (method === "personhoodEvidence" || method === "personhoodEvidenceStatus") {
    if (args.length !== 2) throw Error("Expected collection and Artist"); uint(args[0], 256); hash(args[1], true);
  } else { if (args.length !== 1) throw Error("Expected native record hash"); hash(args[0], true); }
  return Object.freeze({ to: address(target), data: abi.encodeFunctionData(method, args) as Hex, value: 0n });
}
