import { AbiCoder, Interface, getAddress, ParamType, ZeroAddress, ZeroHash, id, keccak256, toUtf8Bytes, toUtf8String } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { ArtistHydrationQuery, ArtistHydrationOwnerIndex, ArtistHydrationSuite, ArtistHydrationSale, ArtistHydrationPolicyKey } from "./current-artist-authority-hydration.js";
import { ARTIST_HYDRATION_SUITE_TUPLE, ARTIST_HYDRATION_POLICY_TUPLE, ARTIST_HYDRATION_QUERY_TUPLE, ARTIST_HYDRATION_SNAPSHOT_TUPLE, ARTIST_HYDRATION_NONCE_WORD_TUPLE, ARTIST_HYDRATION_OWNER_DATA_TUPLE, ARTIST_HYDRATION_CHECKPOINT_TUPLE } from "./current-artist-authority-hydration.js";
import type { UnsignedCall } from "./binding.js";
import * as base from "./current-artist-recovered-multiple-hydration.js";
import * as shared from "./internal/artist-recovered-hydration-codec.js";

export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_SOURCE = "45828ad0db2a6d52c6b0c7aad8d25dd4ba866c65";
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BASE = 2097152n;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ALLOWED_FEATURES = 2276351n;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_KNOWN_FEATURES = 4194303n;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_SCHEMA = id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_GENERATIONS_V1") as Hex;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_GENERATIONS = 2097152n;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CREDENTIAL_SCHEMA = id("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1") as Hex;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_EVIDENCE_SCHEMA = id("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1") as Hex;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_WAIVER_SCHEMA = id("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1") as Hex;

export type {
  ArtistRecoveredHydrationCapability as ArtistRecoveredMultipleGenerationHydrationCapability,
  ArtistRecoveredHydrationEconomicsConsent as ArtistRecoveredMultipleGenerationHydrationEconomicsConsent,
  ArtistRecoveredHydrationAttestation as ArtistRecoveredMultipleGenerationHydrationAttestation,
  ArtistRecoveredHydrationAttestationInput as ArtistRecoveredMultipleGenerationHydrationAttestationInput,
  ArtistRecoveredHydrationCollectionWitness as ArtistRecoveredMultipleGenerationHydrationCollectionWitness,
  ArtistRecoveredHydrationRecordsRequest as ArtistRecoveredMultipleGenerationHydrationRecordsRequest,
  ArtistRecoveredHydrationRequest as ArtistRecoveredMultipleGenerationHydrationRequest,
  ArtistRecoveredHydrationExportHeader as ArtistRecoveredMultipleGenerationHydrationExportHeader,
  ArtistRecoveredHydrationOriginEnvironment as ArtistRecoveredMultipleGenerationHydrationOriginEnvironment,
  ArtistRecoveredHydrationEra as ArtistRecoveredMultipleGenerationHydrationEra,
  ArtistRecoveredHydrationPoint as ArtistRecoveredMultipleGenerationHydrationPoint,
  ArtistRecoveredHydrationPosition as ArtistRecoveredMultipleGenerationHydrationPosition,
  ArtistRecoveredHydrationJournalEntry as ArtistRecoveredMultipleGenerationHydrationJournalEntry,
  ArtistRecoveredHydrationReplayAlias as ArtistRecoveredMultipleGenerationHydrationReplayAlias,
  ArtistRecoveredHydrationProvenance as ArtistRecoveredMultipleGenerationHydrationProvenance,
  ArtistRecoveredHydrationOwnerEra as ArtistRecoveredMultipleGenerationHydrationOwnerEra,
  ArtistRecoveredHydrationOwnerProvenance as ArtistRecoveredMultipleGenerationHydrationOwnerProvenance,
  ArtistRecoveredHydrationNonceInventory as ArtistRecoveredMultipleGenerationHydrationNonceInventory,
  ArtistRecoveredHydrationEnvelope as ArtistRecoveredMultipleGenerationHydrationEnvelope,
  ArtistRecoveredHydrationPublication as ArtistRecoveredMultipleGenerationHydrationPublication,
  ArtistRecoveredHydrationOwnerPayload as ArtistRecoveredMultipleGenerationHydrationOwnerPayload,
  ArtistRecoveredHydrationTimingConfiguration as ArtistRecoveredMultipleGenerationHydrationTimingConfiguration,
  ArtistRecoveredHydrationTimingInput as ArtistRecoveredMultipleGenerationHydrationTimingInput,
  ArtistRecoveredHydrationTimingEntry as ArtistRecoveredMultipleGenerationHydrationTimingEntry,
  ArtistRecoveredHydrationTimingCheckpoint as ArtistRecoveredMultipleGenerationHydrationTimingCheckpoint,
  ArtistRecoveredHydrationTimingBundle as ArtistRecoveredMultipleGenerationHydrationTimingBundle,
  ArtistRecoveredHydrationActionWitness as ArtistRecoveredMultipleGenerationHydrationActionWitness,
  ArtistRecoveredHydrationActionFacts as ArtistRecoveredMultipleGenerationHydrationActionFacts,
  ArtistRecoveredHydrationActionGuard as ArtistRecoveredMultipleGenerationHydrationActionGuard,
  ArtistRecoveredHydrationFinalityScope as ArtistRecoveredMultipleGenerationHydrationFinalityScope,
  ArtistRecoveredHydrationFinalityComponent as ArtistRecoveredMultipleGenerationHydrationFinalityComponent,
  ArtistRecoveredHydrationFinalityManifest as ArtistRecoveredMultipleGenerationHydrationFinalityManifest,
  ArtistRecoveredHydrationFinalityEvidence as ArtistRecoveredMultipleGenerationHydrationFinalityEvidence,
  ArtistRecoveredHydrationFinalityRecord as ArtistRecoveredMultipleGenerationHydrationFinalityRecord,
  ArtistRecoveredHydrationFinalityTarget as ArtistRecoveredMultipleGenerationHydrationFinalityTarget,
  ArtistRecoveredHydrationFinalityGuard as ArtistRecoveredMultipleGenerationHydrationFinalityGuard,
  ArtistRecoveredHydrationEntropyReceipt as ArtistRecoveredMultipleGenerationHydrationEntropyReceipt,
  ArtistRecoveredHydrationEntropyEvidence as ArtistRecoveredMultipleGenerationHydrationEntropyEvidence,
  ArtistRecoveredHydrationEntropyGuard as ArtistRecoveredMultipleGenerationHydrationEntropyGuard,
  ArtistRecoveredHydrationExternalGuards as ArtistRecoveredMultipleGenerationHydrationExternalGuards,
  ArtistRecoveredHydrationCertificate as ArtistRecoveredMultipleGenerationHydrationCertificate,
  ArtistRecoveredHydrationPrepared as ArtistRecoveredMultipleGenerationHydrationPrepared,
  ArtistRecoveredHydrationEvidenceDescriptor as ArtistRecoveredMultipleGenerationHydrationEvidenceDescriptor,
  ArtistRecoveredHydrationCoordinates as ArtistRecoveredMultipleGenerationHydrationCoordinates,
  ArtistRecoveredHydrationProfileEvidence as ArtistRecoveredMultipleGenerationHydrationProfileEvidence,
  ArtistRecoveredHydrationOperationEvidence as ArtistRecoveredMultipleGenerationHydrationOperationEvidence,
  ArtistRecoveredHydrationHistoricalCell as ArtistRecoveredMultipleGenerationHydrationHistoricalCell,
  ArtistRecoveredHydrationFeatureFacts as ArtistRecoveredMultipleGenerationHydrationFeatureFacts
} from "./internal/artist-recovered-hydration-codec.js";

export {
  ARTIST_RECOVERED_HYDRATION_PROFILE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PROFILE,
  ARTIST_RECOVERED_HYDRATION_PAGE_BYTES as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PAGE_BYTES,
  ARTIST_RECOVERED_HYDRATION_MAX_BYTES as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_MAX_BYTES,
  ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_MAX_PREPARED_BYTES,
  ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CHECKPOINT_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_PAYLOAD_SCHEMA as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PAYLOAD_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_EVIDENCE_SCHEMA as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_EVIDENCE_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_CAPABILITY_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CAPABILITY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ECONOMICS_CONSENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ATTESTATION_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ATTESTATION_INPUT_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_INPUT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_COLLECTION_WITNESS_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_COLLECTION_WITNESS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_RECORDS_REQUEST_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_RECORDS_REQUEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_REQUEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EXPORT_HEADER_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_EXPORT_HEADER_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ERA_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ERA_TUPLE,
  ARTIST_RECOVERED_HYDRATION_POINT_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_POINT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_POSITION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_JOURNAL_ENTRY_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_JOURNAL_ENTRY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_REPLAY_ALIAS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PROVENANCE_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PROVENANCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_ERA_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_OWNER_ERA_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_OWNER_PROVENANCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_NONCE_INVENTORY_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_NONCE_INVENTORY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ENVELOPE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PUBLICATION_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PUBLICATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_PAYLOAD_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_OWNER_PAYLOAD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_CONFIGURATION_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_TIMING_CONFIGURATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_INPUT_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_TIMING_INPUT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_ENTRY_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_TIMING_ENTRY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_TIMING_CHECKPOINT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_BUNDLE_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_TIMING_BUNDLE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_WITNESS_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACTION_WITNESS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_FACTS_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACTION_FACTS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_GUARD_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACTION_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_SCOPE_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_FINALITY_SCOPE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_COMPONENT_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_FINALITY_COMPONENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_MANIFEST_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_FINALITY_MANIFEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_EVIDENCE_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_FINALITY_EVIDENCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_RECORD_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_FINALITY_RECORD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_TARGET_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_FINALITY_TARGET_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_GUARD_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_FINALITY_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_RECEIPT_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ENTROPY_RECEIPT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_EVIDENCE_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ENTROPY_EVIDENCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_GUARD_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ENTROPY_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_EXTERNAL_GUARDS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_CERTIFICATE_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CERTIFICATE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PREPARED_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE as ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE
} from "./internal/artist-recovered-hydration-codec.js";

const codec = shared.createArtistRecoveredHydrationCodec(2276351n);
export const {
  artistRecoveredHydrationOwnerDomain: artistRecoveredMultipleGenerationHydrationOwnerDomain,
  artistRecoveredHydrationOwnerTag: artistRecoveredMultipleGenerationHydrationOwnerTag,
  normalizeArtistRecoveredHydrationCoordinates: normalizeArtistRecoveredMultipleGenerationHydrationCoordinates,
  normalizeArtistRecoveredHydrationCapability: normalizeArtistRecoveredMultipleGenerationHydrationCapability,
  validateArtistRecoveredHydrationCapability: validateArtistRecoveredMultipleGenerationHydrationCapability,
  normalizeArtistRecoveredHydrationRequestDraft: normalizeArtistRecoveredMultipleGenerationHydrationRequestDraft,
  normalizeArtistRecoveredHydrationRequest: normalizeArtistRecoveredMultipleGenerationHydrationRequest,
  encodeArtistRecoveredHydrationRequest: encodeArtistRecoveredMultipleGenerationHydrationRequest,
  normalizeArtistRecoveredHydrationOriginEnvironment: normalizeArtistRecoveredMultipleGenerationHydrationOriginEnvironment,
  artistRecoveredHydrationOriginHash: artistRecoveredMultipleGenerationHydrationOriginHash,
  artistRecoveredHydrationReplayKey: artistRecoveredMultipleGenerationHydrationReplayKey,
  normalizeArtistRecoveredHydrationOwnerProvenance: normalizeArtistRecoveredMultipleGenerationHydrationOwnerProvenance,
  artistRecoveredHydrationOwnerProvenance: artistRecoveredMultipleGenerationHydrationOwnerProvenance,
  normalizeArtistRecoveredHydrationProvenance: normalizeArtistRecoveredMultipleGenerationHydrationProvenance,
  artistRecoveredHydrationProvenanceHash: artistRecoveredMultipleGenerationHydrationProvenanceHash,
  artistRecoveredHydrationOwnerProvenanceHash: artistRecoveredMultipleGenerationHydrationOwnerProvenanceHash,
  artistRecoveredHydrationAliasesHash: artistRecoveredMultipleGenerationHydrationAliasesHash,
  compareArtistRecoveredHydrationPoints: compareArtistRecoveredMultipleGenerationHydrationPoints,
  normalizeArtistRecoveredHydrationNonceInventory: normalizeArtistRecoveredMultipleGenerationHydrationNonceInventory,
  normalizeArtistRecoveredHydrationPublications: normalizeArtistRecoveredMultipleGenerationHydrationPublications,
  normalizeArtistRecoveredHydrationTimingCheckpoint: normalizeArtistRecoveredMultipleGenerationHydrationTimingCheckpoint,
  normalizeArtistRecoveredHydrationExternalGuards: normalizeArtistRecoveredMultipleGenerationHydrationExternalGuards,
  normalizeArtistRecoveredHydrationEvidenceDescriptor: normalizeArtistRecoveredMultipleGenerationHydrationEvidenceDescriptor,
  artistRecoveredHydrationEvidenceDescriptor: artistRecoveredMultipleGenerationHydrationEvidenceDescriptor,
  artistRecoveredHydrationEvidencePages: artistRecoveredMultipleGenerationHydrationEvidencePages,
  assembleArtistRecoveredHydrationEvidence: assembleArtistRecoveredMultipleGenerationHydrationEvidence,
  artistRecoveredHydrationPageId: artistRecoveredMultipleGenerationHydrationPageId,
  artistRecoveredHydrationEvidenceId: artistRecoveredMultipleGenerationHydrationEvidenceId,
  encodeArtistRecoveredHydrationEvidenceCarrier: encodeArtistRecoveredMultipleGenerationHydrationEvidenceCarrier,
  decodeArtistRecoveredHydrationEvidenceCarrier: decodeArtistRecoveredMultipleGenerationHydrationEvidenceCarrier,
  encodeArtistRecoveredHydrationOperationEvidence: encodeArtistRecoveredMultipleGenerationHydrationOperationEvidence,
  decodeArtistRecoveredHydrationOperationEvidence: decodeArtistRecoveredMultipleGenerationHydrationOperationEvidence,
  artistRecoveredHydrationOwnerReplayDelta: artistRecoveredMultipleGenerationHydrationOwnerReplayDelta,
  artistRecoveredHydrationOwnerAfter: artistRecoveredMultipleGenerationHydrationOwnerAfter
} = codec;

// These original complete structural declarations retain their pinned original field shapes.
// No BASE admission normalizer, semantic value or computed hash is reused.
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_IDENTITY_TUPLE = base.ARTIST_RECOVERED_MULTIPLE_HYDRATION_IDENTITY_TUPLE;
export type ArtistRecoveredMultipleGenerationHydrationIdentity = base.ArtistRecoveredMultipleHydrationIdentity;

export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PAYOUT_TUPLE = base.ARTIST_RECOVERED_MULTIPLE_HYDRATION_PAYOUT_TUPLE;
export type ArtistRecoveredMultipleGenerationHydrationPayout = base.ArtistRecoveredMultipleHydrationPayout;

export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_TUPLE = base.ARTIST_RECOVERED_MULTIPLE_HYDRATION_BINDING_TUPLE;
export type ArtistRecoveredMultipleGenerationHydrationBinding = base.ArtistRecoveredMultipleHydrationBinding;

export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACCEPTANCE_TUPLE = base.ARTIST_RECOVERED_MULTIPLE_HYDRATION_ACCEPTANCE_TUPLE;
export type ArtistRecoveredMultipleGenerationHydrationAcceptance = base.ArtistRecoveredMultipleHydrationAcceptance;

export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_POLICY_TUPLE = base.ARTIST_RECOVERED_MULTIPLE_HYDRATION_POLICY_TUPLE;
export type ArtistRecoveredMultipleGenerationHydrationPolicy = base.ArtistRecoveredMultipleHydrationPolicy;

export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_STATE_TUPLE = `tuple(${ARTIST_HYDRATION_QUERY_TUPLE}[] artists,${ARTIST_HYDRATION_QUERY_TUPLE}[] collections,bytes[] rows)`;
export interface ArtistRecoveredMultipleGenerationHydrationState { readonly artists: readonly ArtistHydrationQuery[]; readonly collections: readonly ArtistHydrationQuery[]; readonly rows: readonly Hex[]; }

const coder = AbiCoder.defaultAbiCoder();
const schemaTypes = new Map<string, ParamType>();
// Preserve complete named schemas. Only immutable ABI types are retained; supplied
// values, encoded payloads, hashes and contextual observations are always checked.
function schemaType(tuple: string): ParamType {
  if (typeof tuple !== "string" || tuple.length > 65_536) return ParamType.from(tuple);
  const existing = schemaTypes.get(tuple);
  if (existing) return existing;
  const parsed = ParamType.from(tuple);
  if (schemaTypes.size < 128) schemaTypes.set(tuple, parsed);
  return parsed;
}
const Z = ZeroHash as Hex;
const hash = (types: readonly string[], values: readonly unknown[]): Hex => keccak256(coder.encode(types.map(schemaType), values)) as Hex;
const same = (type: string, a: unknown, b: unknown): boolean => hash([type], [a]) === hash([type], [b]);
const stateType = schemaType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_STATE_TUPLE);
const payoutSchema = id("6529STREAM_ARTIST_RECOVERED_PAYOUT_HYDRATION_V1");
function zeroValue(t: ParamType): unknown {
  if (t.baseType === "array") return Array.from({ length: Math.max(0, t.arrayLength!) }, () => zeroValue(t.arrayChildren!));
  if (t.baseType === "tuple") return Object.fromEntries(t.components!.map(c => [c.name, zeroValue(c)]));
  if (t.type === "address") return ZeroAddress;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  if (t.type.startsWith("bytes")) return "0x" + "00".repeat(Number(t.type.slice(5)) || 0);
  return 0n;
}
function childType(tuple: string, name: string): string {
  const t = schemaType(tuple).components!.find(c => c.name === name)!;
  return t.format("full").replace(new RegExp(` ${name}$`), "");
}
function originalTypedDigest(o: shared.ArtistRecoveredHydrationOriginEnvironment, body: Hex): Hex {
  const domain = hash(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamArtistRegistry"), id("1"), o.chainId, o.registry]);
  return keccak256(`0x1901${domain.slice(2)}${body.slice(2)}`) as Hex;
}

/** Before ABI decoding, bound every dynamic allocation, including repeated offset aliases. */
function preflight(types: readonly string[], raw: Hex, maximum = shared.ARTIST_RECOVERED_HYDRATION_MAX_BYTES): Hex {
  const input = codec.boundedBytes(raw, undefined, maximum);
  const bytes = (input.length - 2) / 2;
  let materialized = 0, nodes = 0;
  const word = (at: number): number => {
    if (!Number.isSafeInteger(at) || at < 0 || at + 32 > bytes) throw Error("Invalid recovered ABI offset");
    const n = BigInt("0x" + input.slice(2 + at * 2, 66 + at * 2));
    if (n > BigInt(maximum)) throw Error("Recovered ABI allocation capacity");
    return Number(n);
  };
  const fixed = (t: ParamType): number | undefined => {
    if (t.type === "bytes" || t.type === "string") return undefined;
    if (t.baseType === "array") {
      const child = fixed(t.arrayChildren!);
      return t.arrayLength === -1 || child === undefined ? undefined : t.arrayLength! * child;
    }
    if (t.baseType === "tuple") {
      let n = 0;
      for (const c of t.components!) { const s = fixed(c); if (s === undefined) return undefined; n += s; }
      return n;
    }
    return 32;
  };
  const visit = (t: ParamType, at: number, depth: number): void => {
    if (++nodes > 262_144 || depth > 64 || at < 0 || at > bytes) throw Error("Recovered ABI allocation capacity");
    materialized += 32;
    if (t.type === "bytes" || t.type === "string") {
      const n = word(at); materialized += n;
      if (at + 32 + Math.ceil(n / 32) * 32 > bytes) throw Error("Truncated recovered ABI bytes");
    } else if (t.baseType === "array") {
      const n = t.arrayLength === -1 ? word(at) : t.arrayLength!;
      if (n > 16_384) throw Error("Recovered ABI array capacity");
      const base = at + (t.arrayLength === -1 ? 32 : 0), child = t.arrayChildren!;
      const size = fixed(child);
      if (base + n * (size ?? 32) > bytes) throw Error("Truncated recovered ABI array");
      for (let i = 0; i < n; i++) visit(child, size === undefined ? base + word(base + 32 * i) : base + size * i, depth + 1);
    } else if (t.baseType === "tuple") {
      let offset = at;
      for (const child of t.components!) {
        const size = fixed(child);
        visit(child, size === undefined ? at + word(offset) : offset, depth + 1);
        offset += size ?? 32;
      }
    } else if (at + 32 > bytes) throw Error("Truncated recovered ABI word");
    if (materialized > maximum) throw Error("Recovered ABI cumulative allocation capacity");
  };
  visit(schemaType(`tuple(${types.join(",")})`), 0, 0);
  return input;
}

function plain(t: ParamType, value: any): unknown {
  if (t.baseType === "array") return Array.from(value, v => plain(t.arrayChildren!, v));
  if (t.baseType === "tuple") return Object.fromEntries(t.components!.map((c, i) => [c.name, plain(c, value[i])]));
  return value;
}

function decode<T>(type: string, raw: Hex): T {
  const bytes = preflight([type], raw);
  const parsed = schemaType(type);
  const result = coder.decode([parsed], bytes);
  if (coder.encode([parsed], result) !== bytes) throw Error("Noncanonical multiple row");
  return codec.normalizeTuple(type, plain(parsed, result[0]) as T);
}

/** Structural tuple only. The admitted State validator adds the original complete membership predicates. */
export function normalizeArtistRecoveredMultipleGenerationHydrationState(value: ArtistRecoveredMultipleGenerationHydrationState): ArtistRecoveredMultipleGenerationHydrationState {
  return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_STATE_TUPLE, value);
}

export function validateArtistRecoveredMultipleGenerationHydrationState(
  index: ArtistHydrationOwnerIndex,
  value: ArtistRecoveredMultipleGenerationHydrationState,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistRecoveredMultipleGenerationHydrationState {
  const s = normalizeArtistRecoveredMultipleGenerationHydrationState(value);
  const p = codec.normalizeArtistRecoveredHydrationOwnerProvenance(provenance, index);
  if (!s.artists.length || s.artists.length > 128 || !s.collections.length || s.collections.length > 128
    || s.artists.length === 1 && s.collections.length === 1
    || s.rows.length !== (index === 1 ? 0 : index === 2 || index === 5 ? s.artists.length : s.collections.length)) {
    throw Error("Invalid complete multiple State cardinality");
  }
  for (let i = 0; i < s.artists.length; i++) {
    const q = s.artists[i]!;
    if (q.artistId === Z || q.collectionId !== 0n || q.bindingHash !== Z || q.policies.length
      || i > 0 && BigInt(q.artistId) <= BigInt(s.artists[i - 1]!.artistId)
      || !s.collections.some(c => c.artistId === q.artistId)) throw Error("Invalid multiple Artist query");
  }
  let policies = 0;
  for (let i = 0; i < s.collections.length; i++) {
    const q = s.collections[i]!;
    if (!q.collectionId || q.bindingHash === Z || q.policies.length > 128
      || i > 0 && q.collectionId <= s.collections[i - 1]!.collectionId
      || !s.artists.some(a => a.artistId === q.artistId)) throw Error("Invalid multiple collection query");
    const keys = new Set<string>(); policies += q.policies.length;
    for (const policy of q.policies) {
      const key = policy.phaseId + policy.policyHash;
      if (policy.phaseId === Z || policy.policyHash === Z || keys.has(key)) throw Error("Invalid multiple policy selectors");
      keys.add(key);
    }
  }
  if (policies > 128) throw Error("Multiple policy inventory exceeds capacity");
  for (const j of p.journal) {
    if (!s.artists.some(a => a.artistId === j.receipt.artistId)
      || j.receipt.collectionId !== 0n && !s.collections.some(c => c.collectionId === j.receipt.collectionId && c.artistId === j.receipt.artistId)) {
      throw Error("Native journal lies outside complete multiple State");
    }
  }
  return s;
}

export function artistRecoveredMultipleGenerationHydrationAnchor(value: ArtistRecoveredMultipleGenerationHydrationState): ArtistHydrationQuery {
  const s = normalizeArtistRecoveredMultipleGenerationHydrationState(value);
  const first = s.collections[0], artist = first && s.artists.find(a => a.artistId === first.artistId);
  if (!first || !artist) throw Error("Missing multiple anchor");
  return Object.freeze({ ...first, records: artist.records });
}

export function encodeArtistRecoveredMultipleGenerationHydrationState(
  value: ArtistRecoveredMultipleGenerationHydrationState, index: ArtistHydrationOwnerIndex,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): Hex {
  if (index === 0 || index === 3 || index === 4) throw Error("Generation owners0/3/4 require complete auxiliary evidence");
  const s = validateArtistRecoveredMultipleGenerationHydrationState(index, value, provenance);
  return codec.encodeTupleValues(["bytes32", "uint16", "uint8", ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_STATE_TUPLE, "bytes"],
    [ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_SCHEMA, 1n, BigInt(index), s, "0x"]);
}
export function encodeArtistRecoveredMultipleGenerationHydrationAttributionState(
  value: ArtistRecoveredMultipleGenerationHydrationState, provenance: shared.ArtistRecoveredHydrationOwnerProvenance, auxiliary: Hex,
): Hex {
  const s = validateArtistRecoveredMultipleGenerationHydrationState(4, value, provenance);
  validateArtistRecoveredMultipleGenerationHydrationInventory(s, provenance, decodeArtistRecoveredMultipleGenerationHydrationInventory(auxiliary));
  return codec.encodeTupleValues(["bytes32", "uint16", "uint8", ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_STATE_TUPLE, "bytes"],
    [ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_SCHEMA, 1n, 4n, s, auxiliary]);
}
export function decodeArtistRecoveredMultipleGenerationHydrationAuxiliary(
  raw: Hex, index: ArtistHydrationOwnerIndex, provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): Readonly<{ state: ArtistRecoveredMultipleGenerationHydrationState; auxiliary: Hex }> {
  const types = ["bytes32", "uint16", "uint8", ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_STATE_TUPLE, "bytes"];
  const parsed = types.map(schemaType), bytes = preflight(types, raw), result = coder.decode(parsed, bytes);
  if (result[0] !== ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_SCHEMA || result[1] !== 1n || result[2] !== BigInt(index)
    || coder.encode(parsed, result) !== bytes || ([0, 3, 4].includes(index) ? result[4] === "0x" : result[4] !== "0x")) throw Error("Noncanonical multiple State tag/version/owner/auxiliary");
  const state = validateArtistRecoveredMultipleGenerationHydrationState(index, plain(stateType, result[3]) as ArtistRecoveredMultipleGenerationHydrationState, provenance);
  const auxiliary = result[4] as Hex;
  if (index === 0 || index === 4) validateArtistRecoveredMultipleGenerationHydrationInventory(state, provenance, decodeArtistRecoveredMultipleGenerationHydrationInventory(auxiliary));
  if (index === 3) decode(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_GENERATION_TUPLE}[][]`, auxiliary);
  return Object.freeze({ state, auxiliary });
}
export function decodeArtistRecoveredMultipleGenerationHydrationState(
  raw: Hex, index: ArtistHydrationOwnerIndex, provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistRecoveredMultipleGenerationHydrationState {
  return decodeArtistRecoveredMultipleGenerationHydrationAuxiliary(raw, index, provenance).state;
}

/** Only collection record arrays are projected; all Artist records, policies and row bytes remain complete. */
export function artistRecoveredMultipleGenerationHydrationProjectQueries(
  value: ArtistRecoveredMultipleGenerationHydrationState, provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistRecoveredMultipleGenerationHydrationState {
  const s = normalizeArtistRecoveredMultipleGenerationHydrationState(value), p = codec.normalizeArtistRecoveredHydrationOwnerProvenance(provenance, 4);
  if (p.journal.filter(j => j.receipt.operation === 24n).length > 128) throw Error("Client op24 inventory capacity");
  const records = s.collections.map(() => [] as Hex[]), seen = new Set<Hex>();
  for (const j of p.journal) {
    if (j.receipt.operation === 44n) continue;
    const r = j.receipt, at = s.collections.findIndex(q => q.collectionId === r.collectionId);
    if (r.operation !== 24n || r.recordHash === Z || seen.has(r.recordHash) || at < 0
      || s.collections[at]!.artistId !== r.artistId || s.artists.filter(a => a.artistId === r.artistId).length !== 1) throw Error("Invalid op24 query projection");
    seen.add(r.recordHash); records[at]!.push(r.recordHash);
  }
  return normalizeArtistRecoveredMultipleGenerationHydrationState({ ...s, collections: s.collections.map((q, i) => ({ ...q, records: records[i]! })) });
}

export function normalizeArtistRecoveredMultipleGenerationHydrationIdentity(value: ArtistRecoveredMultipleGenerationHydrationIdentity): ArtistRecoveredMultipleGenerationHydrationIdentity {
  return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_IDENTITY_TUPLE, value);
}
export function encodeArtistRecoveredMultipleGenerationHydrationIdentity(value: ArtistRecoveredMultipleGenerationHydrationIdentity): Hex {
  return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_IDENTITY_TUPLE], [normalizeArtistRecoveredMultipleGenerationHydrationIdentity(value)]);
}
export function decodeArtistRecoveredMultipleGenerationHydrationIdentity(raw: Hex): ArtistRecoveredMultipleGenerationHydrationIdentity {
  return decode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_IDENTITY_TUPLE, raw);
}
export function encodeArtistRecoveredMultipleGenerationHydrationPayout(value: ArtistRecoveredMultipleGenerationHydrationPayout): Hex {
  return codec.encodeTupleValues(["bytes32", ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PAYOUT_TUPLE],
    [payoutSchema, codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PAYOUT_TUPLE, value)]);
}
export function decodeArtistRecoveredMultipleGenerationHydrationPayout(raw: Hex): ArtistRecoveredMultipleGenerationHydrationPayout {
  const types = ["bytes32", ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PAYOUT_TUPLE];
  const parsed = types.map(schemaType);
  const bytes = preflight(types, raw), v = coder.decode(parsed, bytes);
  if (v[0] !== payoutSchema || coder.encode(parsed, v) !== bytes) throw Error("Noncanonical recovered Payout row");
  return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PAYOUT_TUPLE,
    plain(schemaType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PAYOUT_TUPLE), v[1]) as ArtistRecoveredMultipleGenerationHydrationPayout);
}

export type ArtistRecoveredMultipleGenerationHydrationNonceLane = ArtistRecoveredMultipleGenerationHydrationIdentity["nonces"][number];

/** Exact global-index bijection; local lanes retain increasing global positions. Empty local sets are valid. */
export function artistRecoveredMultipleGenerationHydrationNonceUnion(
  value: ArtistRecoveredMultipleGenerationHydrationState,
  inventory: readonly shared.ArtistRecoveredHydrationNonceInventory[],
  checkpoint: Parameters<typeof codec.normalizeArtistRecoveredHydrationNonceInventory>[1],
): readonly ArtistRecoveredMultipleGenerationHydrationNonceLane[] {
  const s = normalizeArtistRecoveredMultipleGenerationHydrationState(value);
  const rows = codec.normalizeArtistRecoveredHydrationNonceInventory(inventory, checkpoint);
  if (s.rows.length !== s.artists.length || !s.artists.length || s.artists.length > 128) throw Error("Invalid Identity row partition");
  const result: ArtistRecoveredMultipleGenerationHydrationNonceLane[] = new Array(rows.length);
  const seen = new Set<number>(), authorities = new Set<Address>();
  let timing: Hex | undefined;
  for (let i = 0; i < s.rows.length; i++) {
    const b = decodeArtistRecoveredMultipleGenerationHydrationIdentity(s.rows[i]!);
    const current = hash([shared.ARTIST_RECOVERED_HYDRATION_TIMING_BUNDLE_TUPLE], [b.timing]);
    if (b.artistId !== s.artists[i]!.artistId || b.identity.authorityAddress === ZeroAddress
      || b.nextRegistrationNonce !== BigInt(s.artists.length) || authorities.has(b.identity.authorityAddress)
      || timing !== undefined && current !== timing || b.nonces.length > 128) {
      throw Error("Multiple Identity authority, registration, timing or delegation mismatch");
    }
    timing = current; authorities.add(b.identity.authorityAddress);
    let previous = -1;
    for (const lane of b.nonces) {
      const belongs = lane.kind === 1n ? lane.key === b.artistId : lane.kind === 2n
        ? b.delegations.some(d => lane.key === artistRecoveredMultipleGenerationHydrationDelegateLane(b.artistId, d.record.grant.delegate)) : lane.kind === 4n
        ? [...b.rotations.map(r => r.record.terms.newAddress), ...b.recoveries.map(r => r.record.terms.newAddress)]
          .some(a => lane.key === hash(["bytes32", "bytes32", "address"], [id("rotation_acceptance"), b.artistId, a]))
        : lane.kind === 5n && b.estates.some(e => lane.key === hash(["string", "bytes32", "address"], ["estate_activation", b.artistId, e.request.terms.successor]));
      const at = rows.findIndex(row => row.index.kind === lane.kind && row.index.key === lane.key);
      if (!belongs || lane.key === Z || at < 0 || seen.has(at) || at <= previous
        || !same(`${ARTIST_HYDRATION_NONCE_WORD_TUPLE}[]`, lane.words, rows[at]!.words)) {
        throw Error("Incomplete or reordered global nonce union");
      }
      previous = at; seen.add(at); result[at] = lane;
    }
  }
  if (seen.size !== rows.length) throw Error("Incomplete global nonce union");
  return Object.freeze(result);
}

export function normalizeArtistRecoveredMultipleGenerationHydrationOwnerPayload(
  value: shared.ArtistRecoveredHydrationOwnerPayload, index: ArtistHydrationOwnerIndex,
): shared.ArtistRecoveredHydrationOwnerPayload {
  const p = codec.normalizeArtistRecoveredHydrationOwnerPayload(value, index);
  decodeArtistRecoveredMultipleGenerationHydrationState(p.semanticState, index, p.provenance);
  if (index !== 2 && p.nonces.length) throw Error("Only Identity carries multiple nonce inventory");
  return p;
}
export function encodeArtistRecoveredMultipleGenerationHydrationOwnerPayload(
  value: shared.ArtistRecoveredHydrationOwnerPayload, index: ArtistHydrationOwnerIndex, features: bigint,
): Hex {
  return codec.encodeArtistRecoveredHydrationOwnerPayload(normalizeArtistRecoveredMultipleGenerationHydrationOwnerPayload(value, index), index, features);
}
export function decodeArtistRecoveredMultipleGenerationHydrationOwnerPayload(raw: Hex, index: ArtistHydrationOwnerIndex) {
  preflight(["bytes32", "uint16", shared.ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE], raw);
  const v = codec.decodeArtistRecoveredHydrationOwnerPayload(raw, index);
  normalizeArtistRecoveredMultipleGenerationHydrationOwnerPayload(v.payload, index);
  return v;
}

function occurrence(p: shared.ArtistRecoveredHydrationOwnerProvenance, q: ArtistHydrationQuery, op: bigint, key: Hex) {
  const rows = p.journal.filter(j => j.receipt.recordHash === key);
  if (key === Z || rows.length !== 1 || rows[0]!.receipt.operation !== op || rows[0]!.receipt.artistId !== q.artistId
    || rows[0]!.receipt.collectionId !== q.collectionId) throw Error("Multiple row native occurrence mismatch");
  return rows[0]!;
}

/** Supplied Binding preimage under its original era, never the destination Registry. */
export function artistRecoveredMultipleGenerationHydrationBindingHash(
  origin: shared.ArtistRecoveredHydrationOriginEnvironment, collectionId: bigint,
  value: ArtistRecoveredMultipleGenerationHydrationBinding["item"],
): Hex {
  const o = codec.normalizeArtistRecoveredHydrationOriginEnvironment(origin);
  const itemType = schemaType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_TUPLE).components!.find(c => c.name === "item")!;
  const b = codec.normalizeTuple(itemType.format("full"), value);
  if (typeof collectionId !== "bigint" || collectionId < 0n || collectionId >= 1n << 256n) throw Error("Expected collection uint256");
  return hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_BINDING_V1"), o.chainId, o.registry, o.core, collectionId, b.generation, b.artistId,
      b.artistAddress, b.identityRecordHash, b.consentMode, b.saleConsentScope, b.registryImmutabilityElection,
      hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), []]),
      hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []])]);
}

function collectionRows(index: ArtistHydrationOwnerIndex, s: ArtistRecoveredMultipleGenerationHydrationState, p: shared.ArtistRecoveredHydrationOwnerProvenance): void {
  if (index !== 1) throw Error("Generation collection validation requires its complete bundles");
  if (s.rows.length || p.journal.length || p.aliases.length) throw Error("Collaborator multiple graph unsupported");
  const o = p.origins[0]!, initial = p.eras[0]!.checkpoint.ownerState;
  for (const [domain, actual] of [["STATE", initial.stateRoot], ["RECORD", initial.recordChainTip]] as const) {
    if (actual !== hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32"],
      [id(`6529STREAM_ARTIST_OWNER_${domain}_GENESIS_V2`), o.chainId, o.registry, o.coordinator, o.archive, o.owners[1], codec.artistRecoveredHydrationOwnerDomain(1)])) throw Error("Collaborator genesis mismatch");
  }
  for (let i = 0; i < p.eras.length; i++) {
    const e = p.eras[i]!;
    if (e.lowerRevision !== (i ? 1n : 0n) || e.checkpoint.ownerState.revision !== e.lowerRevision || e.nativeCount || e.checkpoint.replayCount || e.checkpoint.replayRoot !== Z || e.checkpoint.nonceIndexCount || e.checkpoint.nonceRoot !== Z) throw Error("Collaborator source clock mismatch");
  }
}

/** Original feature union. Advertisement supersets do not authorize new semantic profiles. */
export function artistRecoveredMultipleGenerationHydrationRequiredFeatures(
  identities: readonly ArtistRecoveredMultipleGenerationHydrationIdentity[],
  payouts: readonly ArtistRecoveredMultipleGenerationHydrationPayout[], eraCount: bigint,
  bindings: readonly ArtistRecoveredMultipleGenerationHydrationBindingBundle[],
  contents: readonly ArtistRecoveredMultipleGenerationHydrationConsents[],
  attribution: readonly ArtistRecoveredMultipleGenerationHydrationAttribution[],
): bigint {
  codec.boundedArray(identities, 128); codec.boundedArray(payouts, 128, identities.length);
  codec.boundedArray(bindings, 128); codec.boundedArray(contents, 128, bindings.length); codec.boundedArray(attribution, 128, bindings.length);
  identities = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_IDENTITY_TUPLE}[]`, identities);
  payouts = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PAYOUT_TUPLE}[]`, payouts);
  bindings = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_BUNDLE_TUPLE}[]`, bindings);
  contents = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONSENTS_TUPLE}[]`, contents);
  attribution = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_TUPLE}[]`, attribution);
  if (!identities.length || !bindings.length || typeof eraCount !== "bigint" || eraCount < 1n || eraCount > 16n) throw Error("Invalid generation feature scope");
  let result = 2097152n | 512n;
  for (let i = 0; i < identities.length; i++) {
    const b = normalizeArtistRecoveredMultipleGenerationHydrationIdentity(identities[i]!), p = codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PAYOUT_TUPLE, payouts[i]!);
    if (b.artistId !== p.artistId) throw Error("Generation Artist/Payout partition mismatch");
    result |= codec.artistRecoveredHydrationRequiredFeatures({ currentAuthorityClass: b.identity.authorityClass,
      recoveryAuthorityClasses: b.recoveries.map(r => r.record.fields.vestedAuthorityClass), hasAdjudicationV2: b.actions.some(a => a.evidenceV2.manifestHash !== Z),
      hasRewindsV3: b.actions.some(a => a.evidenceV3.manifestHash !== Z) || !!(b.revisionContinuations.length + b.standingContinuations.length + b.capabilityContinuations.length + p.continuations.length),
      eraCount, economicsCount: 0n, hasDelegations: b.delegations.length !== 0, bindingConsentMode: 1n, saleConsentCount: 0n, attestationCount: 0n });
  }
  let economics = 0, royalties = 0, attestations = 0;
  for (let i = 0; i < bindings.length; i++) {
    const b = normalizeArtistRecoveredMultipleGenerationHydrationBindingBundle(bindings[i]!), c = normalizeArtistRecoveredMultipleGenerationHydrationConsents(contents[i]!), a = normalizeArtistRecoveredMultipleGenerationHydrationAttribution(attribution[i]!);
    if (c.rows.original.artistId !== b.bindings.artistId || c.rows.original.collectionId !== b.bindings.collectionId || c.rows.original.bindingHash !== b.bindings.bindingHash) throw Error("Generation feature scope mismatch");
    if (b.corrections.some(r => r.recordHash !== Z)) result |= 2048n;
    if (a.history.revocations.length) result |= 4096n | 8192n;
    if (a.records.records.length) result |= 128n | 131072n;
    if (c.rows.original.economics.length) result |= 32n;
    if (b.bindings.rows.some(r => r.item.consentMode === 2n) || c.rows.original.sales.length) result |= 64n;
    if (c.rows.consents.length || c.rows.royalties.length || c.rows.freezes.length) result |= 256n | 32768n;
    economics += c.rows.original.economics.length; royalties += c.rows.royalties.length; attestations += a.records.records.length;
  }
  if (economics > 128 || royalties > 128 || attestations > 128) throw Error("Generation witness inventory exceeds client capacity");
  if (result & ~2276351n) throw Error("Unsupported generation feature");
  return result;
}

/** Checks canonical rows, closed profile, complete partitions and nonce union.
 * Full Identity/Payout record semantics and external authority remain the original producer's job.
 */
export function normalizeArtistRecoveredMultipleGenerationHydrationPrepared(value: shared.ArtistRecoveredHydrationPrepared): shared.ArtistRecoveredHydrationPrepared {
  const p = codec.normalizeArtistRecoveredHydrationPrepared(value);
  validateSemanticGraph(p);
  return p;
}

function validateSemanticGraph(p: Pick<shared.ArtistRecoveredHydrationPrepared, "query" | "data" | "timing"> & {
  readonly admission: Pick<shared.ArtistRecoveredHydrationCertificate, "artists" | "collections" | "provenance">;
}): void {
  const states: ArtistRecoveredMultipleGenerationHydrationState[] = [];
  const identities: ArtistRecoveredMultipleGenerationHydrationIdentity[] = [], payouts: ArtistRecoveredMultipleGenerationHydrationPayout[] = [];
  let features = 0n;
  for (let owner = 0; owner < 7; owner++) {
    const index = owner as ArtistHydrationOwnerIndex;
    const { header, payload } = decodeArtistRecoveredMultipleGenerationHydrationOwnerPayload(p.data[index].typedState, index);
    const decoded = decodeArtistRecoveredMultipleGenerationHydrationAuxiliary(payload.semanticState, index, payload.provenance);
    const s = decoded.state;
    if (index === 0 || index === 4) validateClockCutoffs(decodeArtistRecoveredMultipleGenerationHydrationInventory(decoded.auxiliary), p.admission.provenance);
    if (!same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.artists, p.admission.artists)
      || !same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.collections, index === 4 ? artistRecoveredMultipleGenerationHydrationProjectQueries({ artists: p.admission.artists, collections: p.admission.collections, rows: [] }, payload.provenance).collections : p.admission.collections)
      || !same(ARTIST_HYDRATION_QUERY_TUPLE, artistRecoveredMultipleGenerationHydrationAnchor(s), p.query)) throw Error("Multiple owner scope differs from full certificate");
    states.push(s); features = header.requiredFeatures;
    if (index === 2) {
      artistRecoveredMultipleGenerationHydrationNonceUnion(s, payload.nonces, payload.provenance.eras.at(-1)!.checkpoint);
      for (let i = 0; i < s.rows.length; i++) {
        const b = decodeArtistRecoveredMultipleGenerationHydrationIdentity(s.rows[i]!);
        if (!b.recoveries.length || b.identity.status === 0n || ![1n, 3n].includes(b.identity.authorityClass)
          || !same(ARTIST_HYDRATION_SNAPSHOT_TUPLE, b.sourceSnapshot, payload.provenance.eras.at(-1)!.checkpoint.ownerState)
          || !same(shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, b.timing.checkpoint, p.timing)) throw Error("Multiple Identity requires retained class1/3 recovery and global source clock");
        const rows = payload.provenance.journal.filter(j => j.receipt.artistId === b.artistId);
        if (rows.filter(j => j.receipt.operation === 35n).length !== b.recoveries.length * 2
          || rows.some(j => [2n, 3n, 4n, 44n, 45n, 47n].includes(j.receipt.operation))) throw Error("Unsupported multiple Identity journal profile");
        identities.push(b);
      }
    } else if (index === 5) {
      for (let i = 0; i < s.rows.length; i++) {
        const b = decodeArtistRecoveredMultipleGenerationHydrationPayout(s.rows[i]!);
        if (b.artistId !== s.artists[i]!.artistId
          || !same(ARTIST_HYDRATION_SNAPSHOT_TUPLE, b.sourceSnapshot, payload.provenance.eras.at(-1)!.checkpoint.ownerState)
          || payload.provenance.journal.some(j => j.receipt.operation !== 18n || j.receipt.collectionId !== 0n)) throw Error("Multiple Payout scope mismatch");
        const rows = payload.provenance.journal.filter(j => j.receipt.artistId === b.artistId);
        if (rows.length !== b.records.length || b.records.some((r, j) => r.original.recordHash !== rows[j]!.receipt.recordHash
          || r.original.terms.artistId !== b.artistId || ![1n, 3n].includes(r.original.authorityClass)
          || !same(shared.ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE, r.position, rows[j]!.position))) throw Error("Multiple Payout occurrence mismatch");
        payouts.push(b);
      }
    } else if (index === 1) collectionRows(index, s, payload.provenance);
  }
  const locals = p.data.map((d, i) => decodeArtistRecoveredMultipleGenerationHydrationOwnerPayload(d.typedState, i as ArtistHydrationOwnerIndex));
  const auxiliary0 = decodeArtistRecoveredMultipleGenerationHydrationAuxiliary(locals[0]!.payload.semanticState, 0, locals[0]!.payload.provenance).auxiliary;
  const auxiliary4 = decodeArtistRecoveredMultipleGenerationHydrationAuxiliary(locals[4]!.payload.semanticState, 4, locals[4]!.payload.provenance).auxiliary;
  if (auxiliary0 !== auxiliary4) throw Error("Generation owners0/4 must retain the same complete inventory");
  const inventory = decodeArtistRecoveredMultipleGenerationHydrationInventory(auxiliary0);
  const bindings = states[0]!.rows.map(decodeArtistRecoveredMultipleGenerationHydrationBindingBundle);
  const accepted = states[3]!.rows.map(decodeArtistRecoveredMultipleGenerationHydrationAcceptanceBundle);
  const attributed = states[4]!.rows.map(decodeArtistRecoveredMultipleGenerationHydrationAttribution);
  const contents = states[6]!.rows.map(decodeArtistRecoveredMultipleGenerationHydrationConsents);
  const generations = decodeArtistRecoveredMultipleGenerationHydrationAuxiliary(locals[3]!.payload.semanticState, 3, locals[3]!.payload.provenance).auxiliary;
  if (!same(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_BUNDLE_TUPLE}[]`, bindings, inventory.bindings)
    || generations !== codec.encodeTupleValues([`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_GENERATION_TUPLE}[][]`], [inventory.generations])) throw Error("Generation owner row/auxiliary projection mismatch");
  validateGenerationBindings(states[0]!, p.admission.provenance, inventory, accepted, attributed);
  validateArtistRecoveredMultipleGenerationHydrationGrantUses(identities, p.admission.collections, contents, inventory, p.admission.provenance, attributed.map(a => a.records));
  validateGenerationIdentityFacts(identities, states[0]!, p.admission.provenance, inventory, accepted);
  if (features !== artistRecoveredMultipleGenerationHydrationRequiredFeatures(identities, payouts, BigInt(p.admission.provenance.eras.length), bindings, contents, attributed)) throw Error("Generation required feature union differs");
}

export function encodeArtistRecoveredMultipleGenerationHydrationPrepared(value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.encodeArtistRecoveredHydrationPrepared(normalizeArtistRecoveredMultipleGenerationHydrationPrepared(value));
}
export function decodeArtistRecoveredMultipleGenerationHydrationPrepared(raw: Hex): shared.ArtistRecoveredHydrationPrepared {
  preflight([shared.ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE], raw, shared.ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES);
  return normalizeArtistRecoveredMultipleGenerationHydrationPrepared(codec.decodeArtistRecoveredHydrationPrepared(raw));
}
export function artistRecoveredMultipleGenerationHydrationSemanticInventory(value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.artistRecoveredHydrationSemanticInventory(normalizeArtistRecoveredMultipleGenerationHydrationPrepared(value));
}
export function artistRecoveredMultipleGenerationHydrationCommitment(c: shared.ArtistRecoveredHydrationCoordinates, request: shared.ArtistRecoveredHydrationRequest, value: shared.ArtistRecoveredHydrationPrepared): Hex {
  const p = normalizeArtistRecoveredMultipleGenerationHydrationPrepared(value);
  validateWitnessRows(request, p.data[6].typedState, p.data[4].typedState);
  return codec.artistRecoveredHydrationCommitment(c, request, p);
}
export function encodeArtistRecoveredMultipleGenerationHydrationProfileEvidence(request: shared.ArtistRecoveredHydrationRequest, value: shared.ArtistRecoveredHydrationPrepared): Hex {
  const p = normalizeArtistRecoveredMultipleGenerationHydrationPrepared(value);
  validateWitnessRows(request, p.data[6].typedState, p.data[4].typedState);
  return codec.encodeArtistRecoveredHydrationProfileEvidence(request, p);
}

export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_VALIDATION = Object.freeze({
  canonicalRowsChecked: true, completeProvenanceAndNoncePartitionChecked: true,
  consentAndAttestationPartitionsAndRetainedGrantUsesChecked: true, originalArchiveReadbackIndependentlyVerified: false, originalAcceptanceClockProofsRequireSuppliedFacts: true, signatureExecutionIndependentlyVerified: false,
  completeIdentityAndPayoutSemanticsIndependentlyVerified: false,
  sourceAdmissionIndependentlyVerified: false, actualRegistrySimulationRequired: true,
});

export function decodeArtistRecoveredMultipleGenerationHydrationRequest(raw: Hex): shared.ArtistRecoveredHydrationRequest {
  preflight([shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE], raw);
  return codec.decodeArtistRecoveredHydrationRequest(raw);
}

/** Retained evidence has no destination before-state or live suite. It proves these
 * supplied partitions and commitments, not the original preparation admission. */
export function decodeArtistRecoveredMultipleGenerationHydrationProfileEvidence(raw: Hex): shared.ArtistRecoveredHydrationProfileEvidence {
  const types = ["bytes32", "uint16", "address", "address", shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE,
    `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, ARTIST_HYDRATION_QUERY_TUPLE,
    `${ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`,
    shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, shared.ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE];
  preflight(types, raw);
  const e = codec.decodeArtistRecoveredHydrationProfileEvidence(raw);
  codec.normalizeArtistRecoveredHydrationRequest(e.request);
  const locals = e.data.map((d, i) => decodeArtistRecoveredMultipleGenerationHydrationOwnerPayload(d.typedState, i as ArtistHydrationOwnerIndex));
  const origin = locals[0]!.payload.provenance;
  const provenance = codec.normalizeArtistRecoveredHydrationProvenance({ origins: origin.origins,
    eras: origin.eras.map((era, j) => ({ originHash: era.originHash, priorImportCommitment: era.priorImportCommitment,
      checkpoints: locals.map(l => l.payload.provenance.eras[j]!.checkpoint), nativeCounts: locals.map(l => l.payload.provenance.eras[j]!.nativeCount),
      lowerRevisions: locals.map(l => l.payload.provenance.eras[j]!.lowerRevision) })),
    journals: locals.map(l => l.payload.provenance.journal), aliases: locals.map(l => l.payload.provenance.aliases) } as unknown as shared.ArtistRecoveredHydrationProvenance);
  const last = provenance.eras.at(-1)!, deployment = provenance.origins.at(-1)!;
  const a = e.request.records.authority;
  if (!same("bytes32[]", a.artistIds, e.artists.map(q => q.artistId)) || a.collections.length !== e.collections.length
    || a.collections.some((q, i) => q.artistId !== e.collections[i]!.artistId || q.collectionId !== e.collections[i]!.collectionId
      || !same("tuple(bytes32 phaseId,bytes32 policyHash)[]", q.policies, e.collections[i]!.policies))) throw Error("Evidence request selectors differ");
  for (let i = 0; i < 7; i++) {
    const index = i as ArtistHydrationOwnerIndex, local = locals[index]!;
    if (!same(shared.ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE, local.payload.provenance, codec.artistRecoveredHydrationOwnerProvenance(provenance, index))
      || local.header.requiredFeatures !== locals[0]!.header.requiredFeatures) throw Error("Evidence owner provenance disagrees");
    const s = decodeArtistRecoveredMultipleGenerationHydrationState(local.payload.semanticState, index, local.payload.provenance);
    if (!same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.artists, e.artists) || !same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.collections, index === 4 ? artistRecoveredMultipleGenerationHydrationProjectQueries({ artists: e.artists, collections: e.collections, rows: [] }, local.payload.provenance).collections : e.collections)
      || !same(ARTIST_HYDRATION_QUERY_TUPLE, artistRecoveredMultipleGenerationHydrationAnchor(s), e.query)) throw Error("Evidence owner partitions differ");
    codec.validateArtistRecoveredHydrationCapability(e.request.expectedCapabilities[index], index, local.header.requiredFeatures);
    const data = e.data[index];
    if (data.nonces.length || BigInt(data.origins.length) !== last.checkpoints[index].replayCount
      || data.sourceKeys.length !== data.origins.length || data.cells.length !== data.origins.length) throw Error("Evidence guard inventory length mismatch");
    if (!same("tuple(bytes32 surface,bytes32 scope)[]", a.replayOrigins[index], data.origins)) throw Error("Evidence replay preimages differ from submitted insertion order");
    const seen = new Set<Hex>(), aliases = new Map(provenance.aliases[index].map(alias => [alias.originalKey, alias]));
    for (let j = 0; j < data.origins.length; j++) {
      const logical = data.origins[j]!, key = codec.artistRecoveredHydrationReplayKey(deployment, index, logical);
      const alias = aliases.get(key), cell = data.cells[j]!;
      if (seen.has(key) || data.sourceKeys[j] !== key || !alias || alias.originHash !== last.originHash
        || alias.surface !== logical.surface || alias.scope !== logical.scope || alias.cell.commitment !== cell.commitment
        || alias.cell.touchedRevision !== cell.touchedRevision || alias.cell.kind !== cell.kind || alias.cell.status !== cell.status) {
        throw Error("Evidence guard inventory differs from retained current-origin aliases");
      }
      seen.add(key);
    }
  }
  for (const q of e.artists) {
    const rows = provenance.journals.flat().filter(j => j.receipt.artistId === q.artistId);
    if (!same("bytes32[]", q.records, rows.map(j => j.receipt.recordHash))
      || provenance.journals[2].filter(j => j.receipt.artistId === q.artistId && j.receipt.operation === 1n && j.receipt.recordHash === q.artistId && j.receipt.collectionId === 0n).length !== 1) throw Error("Evidence Artist occurrence partition differs");
  }
  for (const q of e.collections) {
    const rows = provenance.journals.flat().filter(j => j.receipt.collectionId === q.collectionId);
    if (!rows.length || rows.some(j => j.receipt.artistId !== q.artistId) || !same("bytes32[]", q.records, rows.map(j => j.receipt.recordHash))) throw Error("Evidence collection occurrence partition differs");
  }
  codec.normalizeArtistRecoveredHydrationTimingCheckpoint(e.timing);
  codec.normalizeArtistRecoveredHydrationExternalGuards(e.externalGuards);
  if (e.externalGuards.artistId !== e.artists[0]!.artistId
    || e.externalGuards.provenanceCommitment !== codec.artistRecoveredHydrationProvenanceHash(provenance)) throw Error("Evidence external guards belong to another inventory");
  const inventory = hash(["bytes32", "uint16", "bytes32", ARTIST_HYDRATION_QUERY_TUPLE, types[8]!, shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, shared.ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE],
    [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, codec.artistRecoveredHydrationProvenanceHash(provenance), e.query, e.data, e.timing, e.externalGuards]);
  if (e.prior !== deployment.registry || e.sourceCoordinator !== deployment.coordinator || e.request.expectedSourceImportCommitment !== last.priorImportCommitment
    || e.request.expectedSemanticInventory !== inventory || !same(`${ARTIST_HYDRATION_CHECKPOINT_TUPLE}[7]`, a.expectedSource, last.checkpoints)) throw Error("Evidence source commitments differ");
  validateSemanticGraph({ query: e.query, data: e.data, timing: e.timing,
    admission: { artists: e.artists, collections: e.collections, provenance } });
  validateWitnessRows(e.request, e.data[6].typedState, e.data[4].typedState);
  return e;
}

export interface ArtistRecoveredMultipleGenerationHydrationRoyaltyFreeze {
  readonly resolver: Address;
  readonly collectionId: bigint;
  readonly revenueClass: Hex;
  readonly expectedAssignmentHash: Hex;
}

export interface ArtistRecoveredMultipleGenerationHydrationInput {
  readonly request: shared.ArtistRecoveredHydrationRequest;
  readonly royaltyFreezes: readonly ArtistRecoveredMultipleGenerationHydrationRoyaltyFreeze[];
}

export interface ArtistRecoveredMultipleGenerationHydrationCall {
  readonly registry: Address;
  readonly caller: Address;
  readonly request: shared.ArtistRecoveredHydrationRequest;
  readonly royaltyFreezes: readonly ArtistRecoveredMultipleGenerationHydrationRoyaltyFreeze[];
  readonly profile: Hex;
  readonly capabilityId: Hex;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export interface ArtistRecoveredMultipleGenerationHydrationContentTerms {
  readonly collectionId: bigint;
  readonly metadataContract: Address;
  readonly familyId: Hex;
  readonly newStateHash: Hex;
}

export interface ArtistRecoveredMultipleGenerationHydrationContentRecord {
  readonly recordHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly terms: ArtistRecoveredMultipleGenerationHydrationContentTerms;
  readonly authorityClass: bigint;
}

export interface ArtistRecoveredMultipleGenerationHydrationRoyaltyRecord {
  readonly recordHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
}

export interface ArtistRecoveredMultipleGenerationHydrationRoyalty {
  readonly terms: ArtistRecoveredMultipleGenerationHydrationRoyaltyFreeze;
  readonly item: ArtistRecoveredMultipleGenerationHydrationRoyaltyRecord;
  readonly grant: Hex;
}

export interface ArtistRecoveredMultipleGenerationHydrationFreezeRecord {
  readonly recordHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly metadataContract: Address;
  readonly lockClasses: readonly Hex[];
  readonly expectedStateHash: Hex;
  readonly authorityClass: bigint;
}

export interface ArtistRecoveredMultipleGenerationHydrationEconomicsAssociation {
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly payloadHash: Hex;
  readonly originalRecord: Hex;
}

export interface ArtistRecoveredMultipleGenerationHydrationEconomics {
  readonly item: {
    readonly recordHash: Hex;
    readonly terms: shared.ArtistRecoveredHydrationEconomicsConsent;
    readonly association: ArtistRecoveredMultipleGenerationHydrationEconomicsAssociation;
  };
  readonly grant: Hex;
}

export interface ArtistRecoveredMultipleGenerationHydrationOriginalBundle {
  readonly provenance: Hex;
  readonly artistId: Hex;
  readonly collectionId: bigint;
  readonly bindingHash: Hex;
  readonly keys: readonly ArtistHydrationPolicyKey[];
  readonly policies: readonly { readonly recordHash: Hex; readonly grant: Hex }[];
  readonly economics: readonly ArtistRecoveredMultipleGenerationHydrationEconomics[];
  readonly sales: readonly ArtistHydrationSale[];
}

export interface ArtistRecoveredMultipleGenerationHydrationContentBundle {
  readonly original: ArtistRecoveredMultipleGenerationHydrationOriginalBundle;
  readonly consents: readonly ArtistRecoveredMultipleGenerationHydrationContentRecord[];
  readonly royalties: readonly ArtistRecoveredMultipleGenerationHydrationRoyalty[];
  readonly freezes: readonly ArtistRecoveredMultipleGenerationHydrationFreezeRecord[];
}

export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_FREEZE_TUPLE = "tuple(address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash)";
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONTENT_TERMS_TUPLE = "tuple(uint256 collectionId,address metadataContract,bytes32 familyId,bytes32 newStateHash)";
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONTENT_RECORD_TUPLE = `tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONTENT_TERMS_TUPLE} terms,uint8 authorityClass)`;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_RECORD_TUPLE = "tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration)";
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_TUPLE = `tuple(${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_FREEZE_TUPLE} terms,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_RECORD_TUPLE} item,bytes32 grant)`;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_FREEZE_RECORD_TUPLE = "tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,address metadataContract,bytes32[] lockClasses,bytes32 expectedStateHash,uint8 authorityClass)";
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ECONOMICS_ASSOCIATION_TUPLE = "tuple(bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 payloadHash,bytes32 originalRecord)";
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ECONOMICS_TUPLE = `tuple(tuple(bytes32 recordHash,${shared.ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE} terms,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ECONOMICS_ASSOCIATION_TUPLE} association) item,bytes32 grant)`;
const saleTuple = "tuple(tuple(bytes32 recordHash,tuple(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash) terms,bytes32 artistId,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,uint64 bindingGeneration,bytes32 bindingHash) item,bytes32 grant,bytes32 current)";
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ORIGINAL_BUNDLE_TUPLE = `tuple(bytes32 provenance,bytes32 artistId,uint256 collectionId,bytes32 bindingHash,${ARTIST_HYDRATION_POLICY_TUPLE}[] keys,tuple(bytes32 recordHash,bytes32 grant)[] policies,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ECONOMICS_TUPLE}[] economics,${saleTuple}[] sales)`;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONTENT_BUNDLE_TUPLE = `tuple(${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ORIGINAL_BUNDLE_TUPLE} original,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONTENT_RECORD_TUPLE}[] consents,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_TUPLE}[] royalties,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_FREEZE_RECORD_TUPLE}[] freezes)`;


function saleLookup(terms: ArtistHydrationSale["item"]["terms"]): Hex {
  return hash(["uint256", "bytes32", "bytes32"], [terms.collectionId, terms.saleId, terms.saleConfigHash]);
}

function validateBaseRows(value: ArtistRecoveredMultipleGenerationHydrationOriginalBundle, bindings: readonly ArtistRecoveredMultipleGenerationHydrationBinding["item"][]): void {
  const policyScopes = new Set<Hex>();
  const policyRecords = new Set<Hex>();
  for (let i = 0; i < value.policies.length; i++) {
    const key = value.keys[i]!;
    const row = value.policies[i]!;
    const scope = hash(["uint256", "bytes32", "bytes32"], [value.collectionId, key.phaseId, key.policyHash]);
    if (row.recordHash === Z || key.phaseId === Z || key.policyHash === Z
      || policyScopes.has(scope) || policyRecords.has(row.recordHash)) throw Error("Invalid original policy row");
    policyScopes.add(scope); policyRecords.add(row.recordHash);
  }
  const economicRecords = new Set<Hex>();
  const payloads = new Set<string>();
  for (let index = 0; index < value.economics.length; index++) {
    const row = value.economics[index]!.item;
    const t = row.terms;
    const a = row.association;
    if (row.recordHash === Z || t.collectionId !== value.collectionId || t.resolver === ZeroAddress || t.revenueClass === Z
      || t.scope > 2n || t.scope === 0n && (t.scopeId !== 0n || t.assignmentHash === Z)
      || t.scope === 1n && t.scopeId !== value.collectionId || t.scope === 2n && t.scopeId === 0n
      || a.artistId !== value.artistId || !acceptedBinding(bindings, a.bindingGeneration, a.bindingHash)
      || a.payloadHash !== hash([shared.ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE], [t])
      || economicRecords.has(row.recordHash) || payloads.has(`${a.payloadHash}:${a.bindingGeneration}`)) throw Error("Invalid original economics row");
    const first = value.economics.slice(0, index).find(r => r.item.association.payloadHash === a.payloadHash)?.item;
    if (a.originalRecord !== (first?.recordHash ?? row.recordHash) || first && a.bindingGeneration <= first.association.bindingGeneration) throw Error("Original economics continuation must retain first record");
    economicRecords.add(row.recordHash); payloads.add(`${a.payloadHash}:${a.bindingGeneration}`);
  }
  const saleRecords = new Set<Hex>();
  const saleTerms = new Set<Hex>();
  for (let i = 0; i < value.sales.length; i++) {
    const row = value.sales[i]!;
    const r = row.item;
    const termsHash = hash(["tuple(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash)", "uint64", "bytes32"], [r.terms, r.bindingGeneration, r.bindingHash]);
    if (r.recordHash === Z || r.artistId !== value.artistId || r.terms.collectionId !== value.collectionId
      || r.terms.saleAdapter === ZeroAddress || r.terms.saleId === Z || r.terms.saleConfigHash === Z
      || r.signer === ZeroAddress || !r.signedAt || !acceptedBinding(bindings, r.bindingGeneration, r.bindingHash, row.grant !== Z)
      || (row.grant === Z ? r.authorityClass !== 1n && r.authorityClass !== 3n : r.authorityClass !== 2n)
      || saleRecords.has(r.recordHash) || saleTerms.has(termsHash)) throw Error("Invalid original sale row");
    saleRecords.add(r.recordHash); saleTerms.add(termsHash);
    let current = r.recordHash;
    for (let j = i + 1; j < value.sales.length; j++) {
      if (saleLookup(value.sales[j]!.item.terms) === saleLookup(r.terms)) current = value.sales[j]!.item.recordHash;
    }
    if (row.current !== current) throw Error("Sale head differs from original receipt order");
  }
}

function validateContentRows(value: ArtistRecoveredMultipleGenerationHydrationContentBundle, bindings: readonly ArtistRecoveredMultipleGenerationHydrationBinding["item"][]): void {
  const original = value.original;
  for (const r of value.consents) {
    if (r.recordHash === Z || r.artistId !== original.artistId || !acceptedBinding(bindings, r.bindingGeneration)
      || r.authorityClass !== 1n && r.authorityClass !== 3n || r.terms.collectionId !== original.collectionId
      || r.terms.metadataContract === ZeroAddress || r.terms.familyId === Z || r.terms.newStateHash === Z) {
      throw Error("Invalid retained content consent");
    }
  }
  normalizeArtistRecoveredMultipleGenerationHydrationRoyaltyFreezes(value.royalties.map(row => row.terms), original.collectionId);
  const royaltyScopes = new Set<Hex>();
  for (const row of value.royalties) {
    if (row.item.recordHash === Z || row.item.artistId !== original.artistId || !acceptedBinding(bindings, row.item.bindingGeneration)) {
      throw Error("Invalid retained royalty-freeze record");
    }
    const scope = artistRecoveredMultipleGenerationHydrationRoyaltyScope(row.terms, original.artistId, row.item.bindingGeneration);
    if (royaltyScopes.has(scope)) throw Error("Duplicate original generation royalty replay scope"); royaltyScopes.add(scope);
  }
  for (const r of value.freezes) {
    if (r.recordHash === Z || r.artistId !== original.artistId || !acceptedBinding(bindings, r.bindingGeneration)
      || r.authorityClass !== 1n && r.authorityClass !== 3n || r.metadataContract === ZeroAddress
      || r.expectedStateHash === Z || !r.lockClasses.length || r.lockClasses.length > 16) {
      throw Error("Invalid retained content-freeze record");
    }
    let previous = 0n;
    for (const lock of r.lockClasses) {
      if (BigInt(lock) <= previous) throw Error("Lock classes must be nonzero strictly ordered");
      previous = BigInt(lock);
    }
  }
}

/** The two original Registry routes; no new request or commitment fields. */
export const CURRENT_ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ABI = Object.freeze([
  ...codec.CURRENT_ARTIST_RECOVERED_HYDRATION_ABI,
  `function hydrateRecoveredArtistAuthorityWithConsents(${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_FREEZE_TUPLE}[] royaltyFreezes) returns(bytes32)`,
]);
const registryInterface = new Interface(CURRENT_ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ABI);
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CAPABILITY_ID = codec.ARTIST_RECOVERED_HYDRATION_CAPABILITY_ID;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_WITH_CONSENTS_CAPABILITY_ID = registryInterface.getFunction("hydrateRecoveredArtistAuthorityWithConsents")!.selector as Hex;
/** Original compiler nominal library identifiers, never expanded tuple selectors. */
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PREPARE_SELECTOR = "0x72c84763" as Hex;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PREPARE_WITH_CONSENTS_SELECTOR = "0x4925300f" as Hex;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PREPARE_ABI = Object.freeze([
  ...codec.ARTIST_RECOVERED_HYDRATION_PREPARE_ABI,
  `function prepare(${ARTIST_HYDRATION_SUITE_TUPLE} destination,${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_FREEZE_TUPLE}[] royaltyFreezes) view returns(${shared.ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE} prepared)`,
]);

export function normalizeArtistRecoveredMultipleGenerationHydrationRoyaltyFreezes(
  value: readonly ArtistRecoveredMultipleGenerationHydrationRoyaltyFreeze[], collectionId?: bigint,
): readonly ArtistRecoveredMultipleGenerationHydrationRoyaltyFreeze[] {
  codec.boundedArray(value, 128);
  const rows = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_FREEZE_TUPLE}[]`, value);
  const seen = new Set<Hex>();
  for (const row of rows) {
    const key = hash([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_FREEZE_TUPLE], [row]);
    if (!row.collectionId || collectionId !== undefined && row.collectionId !== collectionId
      || row.resolver === ZeroAddress || row.revenueClass !== id("ROYALTY_ERC2981")
      || row.expectedAssignmentHash === Z) throw Error("Invalid or duplicate original royalty selector");
    seen.add(key);
  }
  return rows;
}
export function normalizeArtistRecoveredMultipleGenerationHydrationInputDraft(value: ArtistRecoveredMultipleGenerationHydrationInput): ArtistRecoveredMultipleGenerationHydrationInput {
  value = codec.normalizeTuple(`tuple(${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_FREEZE_TUPLE}[] royaltyFreezes)`, value);
  const request = codec.normalizeArtistRecoveredHydrationRequestDraft(value.request);
  const royaltyFreezes = normalizeArtistRecoveredMultipleGenerationHydrationRoyaltyFreezes(value.royaltyFreezes);
  if (royaltyFreezes.some(r => !request.records.authority.collections.some(c => c.collectionId === r.collectionId))) throw Error("Royalty selector outside complete collection selection");
  return Object.freeze({ request, royaltyFreezes });
}
export function normalizeArtistRecoveredMultipleGenerationHydrationInput(value: ArtistRecoveredMultipleGenerationHydrationInput): ArtistRecoveredMultipleGenerationHydrationInput {
  const input = normalizeArtistRecoveredMultipleGenerationHydrationInputDraft(value);
  codec.normalizeArtistRecoveredHydrationRequest(input.request);
  return input;
}
export function prepareArtistRecoveredMultipleGenerationHydrationCall(registry: Address, caller: Address, value: ArtistRecoveredMultipleGenerationHydrationInput): ArtistRecoveredMultipleGenerationHydrationCall {
  const target = getAddress(registry) as Address, actor = getAddress(caller) as Address;
  if (target === ZeroAddress || actor === ZeroAddress) throw Error("Expected actual Registry and caller");
  const input = normalizeArtistRecoveredMultipleGenerationHydrationInput(value);
  const withConsents = input.royaltyFreezes.length !== 0;
  const method = withConsents ? "hydrateRecoveredArtistAuthorityWithConsents" : "hydrateRecoveredArtistAuthority";
  const data = codec.boundedBytes(registryInterface.encodeFunctionData(method, withConsents ? [input.request, input.royaltyFreezes] : [input.request]));
  return Object.freeze({ registry: target, caller: actor, ...input, profile: shared.ARTIST_RECOVERED_HYDRATION_PROFILE,
    capabilityId: registryInterface.getFunction(method)!.selector as Hex,
    call: Object.freeze({ to: target, value: 0n, data }), factsVerified: false });
}
export function normalizeArtistRecoveredMultipleGenerationHydrationCall(value: ArtistRecoveredMultipleGenerationHydrationCall): ArtistRecoveredMultipleGenerationHydrationCall {
  value = codec.normalizeTuple(`tuple(address registry,address caller,${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_FREEZE_TUPLE}[] royaltyFreezes,bytes32 profile,bytes4 capabilityId,tuple(address to,uint256 value,bytes data) call,bool factsVerified)`, value);
  const rebuilt = prepareArtistRecoveredMultipleGenerationHydrationCall(value.registry, value.caller, { request: value.request, royaltyFreezes: value.royaltyFreezes });
  if (value.profile !== rebuilt.profile || value.capabilityId !== rebuilt.capabilityId || value.factsVerified !== false
    || getAddress(value.call.to) !== rebuilt.call.to || value.call.value !== 0n || codec.boundedBytes(value.call.data) !== rebuilt.call.data) throw Error("Multiple consent call differs from immutable input");
  return rebuilt;
}
export function artistRecoveredMultipleGenerationHydrationPreparationCalldata(destination: ArtistHydrationSuite, value: ArtistRecoveredMultipleGenerationHydrationInput): Hex {
  const input = normalizeArtistRecoveredMultipleGenerationHydrationInputDraft(value);
  if (!input.royaltyFreezes.length) return codec.artistRecoveredHydrationPreparationCalldata(destination, input.request);
  const suite = codec.normalizeTuple(ARTIST_HYDRATION_SUITE_TUPLE, destination);
  const data = codec.encodeTupleValues([ARTIST_HYDRATION_SUITE_TUPLE, shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE,
    `${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_FREEZE_TUPLE}[]`], [suite, input.request, input.royaltyFreezes]);
  return codec.boundedBytes(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PREPARE_WITH_CONSENTS_SELECTOR}${data.slice(2)}`);
}

/** Raw canonical per-collection row. Complete whole-owner validation is separate. */
export function normalizeArtistRecoveredMultipleGenerationHydrationContentBundle(value: ArtistRecoveredMultipleGenerationHydrationContentBundle): ArtistRecoveredMultipleGenerationHydrationContentBundle {
  return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONTENT_BUNDLE_TUPLE, value);
}
export function encodeArtistRecoveredMultipleGenerationHydrationContentBundle(value: ArtistRecoveredMultipleGenerationHydrationContentBundle): Hex {
  return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONTENT_BUNDLE_TUPLE], [normalizeArtistRecoveredMultipleGenerationHydrationContentBundle(value)]);
}
export function decodeArtistRecoveredMultipleGenerationHydrationContentBundle(raw: Hex): ArtistRecoveredMultipleGenerationHydrationContentBundle {
  return decode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONTENT_BUNDLE_TUPLE, raw);
}
export function artistRecoveredMultipleGenerationHydrationContentScope(terms: ArtistRecoveredMultipleGenerationHydrationContentTerms, generation: bigint): Hex {
  return hash([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONTENT_TERMS_TUPLE, "uint64"],
    [codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONTENT_TERMS_TUPLE, terms), generation]);
}
export function artistRecoveredMultipleGenerationHydrationRoyaltyScope(terms: ArtistRecoveredMultipleGenerationHydrationRoyaltyFreeze, artistId: Hex, generation: bigint): Hex {
  return hash([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_FREEZE_TUPLE, "bytes32", "uint64"],
    [codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_FREEZE_TUPLE, terms), codec.boundedBytes(artistId, 32), generation]);
}
const replaySurfaces = Object.freeze({ policy: id("consent_finality.replay.policy_consent_key"), economics: id("consent_finality.replay.consent_key"),
  sale: id("consent_finality.replay.sale_consent_key"), content: id("consent_finality.replay.content_consent_key"), freeze: id("consent_finality.replay.freeze_key") });

/** Full journal stays unfiltered; only per-family cursors are partitioned by collection. */
export function validateArtistRecoveredMultipleGenerationHydrationContentBundles(
  values: readonly ArtistRecoveredMultipleGenerationHydrationConsents[], queries: readonly ArtistHydrationQuery[],
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): readonly ArtistRecoveredMultipleGenerationHydrationContentBundle[] {
  codec.boundedArray(values, 128); codec.boundedArray(queries, 128, values.length);
  if (!values.length) throw Error("Empty multiple consent collection partition");
  const wrappers = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONSENTS_TUPLE}[]`, values);
  const all = Object.freeze(wrappers.map(v => v.rows));
  const qs = codec.normalizeTuple(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, queries);
  const p = codec.normalizeArtistRecoveredHydrationOwnerProvenance(provenance, 6);
  const commitment = codec.artistRecoveredHydrationOwnerProvenanceHash(p, 6);
  let count = 0;
  const cursors = all.map(() => ({ economics: 0, sales: 0, consents: 0, royalties: 0, freezes: 0 }));
  for (let i = 0; i < all.length; i++) {
    const b = all[i]!, q = qs[i]!, o = b.original;
    for (const rows of [o.keys, o.policies, o.economics, o.sales, b.consents, b.royalties, b.freezes]) codec.boundedArray(rows, 128);
    if (q.artistId === Z || !q.collectionId || q.bindingHash === Z || o.provenance !== commitment
      || o.artistId !== q.artistId || o.collectionId !== q.collectionId || o.bindingHash !== q.bindingHash
      || o.keys.length !== o.policies.length || !same(`${ARTIST_HYDRATION_POLICY_TUPLE}[]`, o.keys, q.policies)
      || qs.slice(0, i).some(v => v.collectionId === q.collectionId)) throw Error("Invalid multiple consent collection partition");
    const bindings = wrappers[i]!.bindings; validateHistoricalBindings(bindings, q);
    validateBaseRows(o, bindings); validateContentRows(b, bindings);
    count += o.policies.length + o.economics.length + o.sales.length + b.consents.length + b.royalties.length + b.freezes.length;
  }
  if (count !== p.journal.length) throw Error("Incomplete global Consent journal partition");
  const seen = new Set<Hex>();
  const admitted: { surface: string; scope: Hex; record: Hex; point: shared.ArtistRecoveredHydrationPoint }[] = [];
  for (const row of p.journal) {
    const r = row.receipt, at = qs.findIndex(q => q.collectionId === r.collectionId && q.artistId === r.artistId);
    if (at < 0 || r.recordHash === Z || seen.has(r.recordHash)) throw Error("Invalid or duplicate global Consent occurrence");
    seen.add(r.recordHash);
    const b = all[at]!, o = b.original, cursor = cursors[at]!;
    let record: Hex, surface: string, scope: Hex;
    if (r.operation === 14n) {
      const k = o.policies.findIndex(v => v.recordHash === r.recordHash);
      if (k < 0) throw Error("Missing policy occurrence");
      record = o.policies[k]!.recordHash; surface = replaySurfaces.policy;
      scope = hash(["uint256", "bytes32", "bytes32"], [o.collectionId, o.keys[k]!.phaseId, o.keys[k]!.policyHash]);
    } else if (r.operation === 15n) {
      const v = o.economics[cursor.economics++]?.item;
      if (!v) throw Error("Missing economics occurrence");
      record = v.recordHash; surface = replaySurfaces.economics; scope = v.association.originalRecord === v.recordHash ? v.association.payloadHash : hash(["bytes32", "bytes32", shared.ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE, "bytes32", "uint64", "bytes32"], [id("6529STREAM_ARTIST_ECONOMICS_BINDING_CONTINUATION_V1"), v.association.originalRecord, v.terms, v.association.artistId, v.association.bindingGeneration, v.association.bindingHash]);
    } else if (r.operation === 16n) {
      const v = o.sales[cursor.sales++]?.item;
      if (!v) throw Error("Missing sale occurrence");
      const origin = p.origins[p.eras.findIndex(e => e.originHash === row.position.point.environmentHash)]!;
      const actual = hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
        [id("6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1"), origin.chainId, origin.registry, v.terms.saleAdapter, origin.core,
          v.terms.collectionId, v.terms.saleId, v.terms.saleConfigHash, v.artistId, v.signer, v.authorityClass, v.nonce, v.signedAt]);
      if (actual !== v.recordHash) throw Error("Original sale record preimage mismatch");
      record = v.recordHash; surface = replaySurfaces.sale;
      scope = hash(["tuple(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash)", "uint64", "bytes32"], [v.terms, v.bindingGeneration, v.bindingHash]);
    } else if (r.operation === 17n) {
      const v = b.consents[cursor.consents++]; if (!v) throw Error("Missing content occurrence");
      record = v.recordHash; surface = replaySurfaces.content; scope = hash(["bytes32", "bytes32"], [artistRecoveredMultipleGenerationHydrationContentScope(v.terms, v.bindingGeneration), record]);
    } else if (r.operation === 20n) {
      const v = b.royalties[cursor.royalties++]; if (!v) throw Error("Missing royalty occurrence");
      record = v.item.recordHash; surface = replaySurfaces.freeze; scope = artistRecoveredMultipleGenerationHydrationRoyaltyScope(v.terms, o.artistId, v.item.bindingGeneration);
    } else if (r.operation === 21n) {
      const v = b.freezes[cursor.freezes++]; if (!v) throw Error("Missing freeze occurrence");
      record = v.recordHash; surface = replaySurfaces.freeze; scope = hash(["bytes32", "uint256", "uint64", "bytes32"], [id("CONTENT"), o.collectionId, v.bindingGeneration, record]);
    } else throw Error("Unsupported multiple Consent operation");
    if (record !== r.recordHash) throw Error("Consent family order differs from original global journal");
    admitted.push({ record, surface, scope, point: row.position.point });
  }
  for (let i = 0; i < all.length; i++) {
    const b = all[i]!, c = cursors[i]!;
    if (c.economics !== b.original.economics.length || c.sales !== b.original.sales.length || c.consents !== b.consents.length
      || c.royalties !== b.royalties.length || c.freezes !== b.freezes.length) throw Error("Trailing consent rows");
  }
  let total = 0n, cursor = 0;
  for (let i = 0; i < p.eras.length; i++) {
    const e = p.eras[i]!; total += e.nativeCount;
    if (e.lowerRevision !== (i ? 1n : 0n) || e.checkpoint.ownerState.revision !== e.lowerRevision + e.nativeCount
      || e.checkpoint.nonceIndexCount !== 0n || e.checkpoint.nonceRoot !== Z || e.checkpoint.replayCount !== total
      || !total && e.checkpoint.replayRoot !== Z) throw Error("Multiple Consent era counts mismatch");
    for (let n = 0n; n < e.nativeCount; n++) if (p.journal[cursor++]!.position.point.ownerRevision !== e.lowerRevision + n + 1n) throw Error("Consent revision order mismatch");
  }
  for (const alias of p.aliases) {
    const a = admitted.find(v => v.surface === alias.surface && v.scope === alias.scope && v.record === alias.cell.commitment);
    if (!a || alias.cell.kind !== 1n || alias.cell.status !== 2n || !same(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, alias.admittedAt, a.point)) throw Error("Consent replay alias differs from original admission");
  }
  return all;
}

export function artistRecoveredMultipleGenerationHydrationDelegateLane(artistId: Hex, delegate: Address): Hex {
  return hash(["bytes32", "bytes32", "address"], [id("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), codec.boundedBytes(artistId, 32), getAddress(delegate)]);
}
export function artistRecoveredMultipleGenerationHydrationGrantRecordHash(
  origin: shared.ArtistRecoveredHydrationOriginEnvironment,
  value: ArtistRecoveredMultipleGenerationHydrationIdentity["delegations"][number]["record"],
): Hex {
  const o = codec.normalizeArtistRecoveredHydrationOriginEnvironment(origin);
  const r = normalizeDelegationRecord(value), g = r.grant;
  return hash(["bytes32", "uint256", "address", "bytes32", "address", "uint256", "uint32", "uint64", "uint64", "uint64", "bytes32", "uint256"],
    [id("6529STREAM_ARTIST_DELEGATION_RECORD_V1"), o.chainId, o.registry, g.artistId, g.delegate, g.collectionId, g.capabilities, g.notBefore, g.expiresAt, g.maxUses, g.constraintsHash, r.nonce]);
}
const delegationRecordType = "tuple(tuple(bytes32 artistId,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash) grant,address grantor,uint256 nonce,uint256 uses,bool revoked,bytes32 revocationRecordHash)";
function normalizeDelegationRecord(value: ArtistRecoveredMultipleGenerationHydrationIdentity["delegations"][number]["record"]) {
  return codec.normalizeTuple(delegationRecordType, value);
}
export function artistRecoveredMultipleGenerationHydrationGrantDigest(origin: shared.ArtistRecoveredHydrationOriginEnvironment,
  value: ArtistRecoveredMultipleGenerationHydrationIdentity["delegations"][number]["record"]): Hex {
  const o = codec.normalizeArtistRecoveredHydrationOriginEnvironment(origin), r = normalizeDelegationRecord(value), g = r.grant;
  const domain = hash(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamArtistRegistry"), id("1"), o.chainId, o.registry]);
  const struct = hash(["bytes32", "address", "address", "uint256", "uint32", "uint64", "uint64", "uint64", "bytes32", "uint256"],
    [id("StreamArtistDelegation(address core,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash,uint256 nonce)"),
      o.core, g.delegate, g.collectionId, g.capabilities, g.notBefore, g.expiresAt, g.maxUses, g.constraintsHash, r.nonce]);
  return keccak256(`0x1901${domain.slice(2)}${struct.slice(2)}`) as Hex;
}
function eraOf(p: shared.ArtistRecoveredHydrationOwnerProvenance, point: shared.ArtistRecoveredHydrationPoint): number {
  const at = p.eras.findIndex(e => e.originHash === point.environmentHash);
  if (at < 0) throw Error("Unknown original era");
  return at;
}
function before(p: shared.ArtistRecoveredHydrationOwnerProvenance, a: shared.ArtistRecoveredHydrationPoint, b: shared.ArtistRecoveredHydrationPoint): boolean {
  return codec.compareArtistRecoveredHydrationPoints(p, a, b) === -1;
}
function identityOccurrence(p: shared.ArtistRecoveredHydrationOwnerProvenance, artist: Hex, operation: bigint, record: Hex) {
  const rows = p.journal.filter(j => j.receipt.recordHash === record && j.receipt.operation === operation);
  if (record === Z || rows.length !== 1 || rows[0]!.receipt.artistId !== artist || rows[0]!.receipt.collectionId !== 0n
    || rows[0]!.position.point.ownerIndex !== 2n) throw Error("Invalid original delegation occurrence");
  return rows[0]!;
}

/** Complete retained grant versions and original delegate consumption, without current grant liveness. */
export function validateArtistRecoveredMultipleGenerationHydrationDelegations(
  value: ArtistRecoveredMultipleGenerationHydrationIdentity, provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistRecoveredMultipleGenerationHydrationIdentity {
  const b = normalizeArtistRecoveredMultipleGenerationHydrationIdentity(value), p = codec.normalizeArtistRecoveredHydrationOwnerProvenance(provenance, 2);
  const alias = (point: shared.ArtistRecoveredHydrationPoint, surface: string, scope: Hex, commitment: Hex): void => {
    const rows = p.aliases.filter(a => a.originHash === point.environmentHash && a.surface === id(surface) && a.scope === scope);
    if (rows.length !== 1 || rows[0]!.ownerIndex !== 2n || rows[0]!.cell.kind !== 1n || rows[0]!.cell.status !== 2n
      || rows[0]!.cell.commitment !== commitment || rows[0]!.cell.touchedRevision !== point.ownerRevision
      || !same(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, rows[0]!.admittedAt, point)) throw Error("Original delegation replay guard mismatch");
  };
  const native = p.journal.filter(j => j.receipt.artistId === b.artistId);
  if (native.filter(j => j.receipt.operation === 26n).length !== b.delegations.length) throw Error("Incomplete original delegation grants");
  const revocations = native.filter(j => j.receipt.operation === 27n);
  if (new Set(revocations.map(j => j.receipt.recordHash)).size !== revocations.length) throw Error("Duplicate delegation revocation");
  for (const j of revocations) {
    const rows = b.delegations.filter(d => d.record.revoked && d.record.revocationRecordHash === j.receipt.recordHash);
    if (rows.length !== 1 || j.receipt.recordHash === Z || j.receipt.collectionId !== 0n
      || !before(p, rows[0]!.position.point, j.position.point)) throw Error("Unmatched original delegation revocation");
    alias(j.position.point, "identity_authority.replay.one_way_delegation_revocation", rows[0]!.recordHash, j.receipt.recordHash);
  }
  let revoked = 0;
  const seen = new Set<Hex>();
  for (let i = 0; i < b.delegations.length; i++) {
    const d = b.delegations[i]!, r = d.record, g = r.grant;
    if (d.recordHash === Z || seen.has(d.recordHash) || g.artistId !== b.artistId || r.grantor === ZeroAddress
      || g.delegate === ZeroAddress || g.delegate === r.grantor || !g.capabilities || (g.capabilities & ~1143n) !== 0n
      || g.expiresAt <= g.notBefore || g.maxUses !== 0n && r.uses > g.maxUses || r.revoked !== (r.revocationRecordHash !== Z)
      || d.epoch > b.heads.delegationEpoch || i > 0 && (d.epoch < b.delegations[i - 1]!.epoch || !before(p, b.delegations[i - 1]!.position.point, d.position.point))) throw Error("Invalid retained delegation grant");
    seen.add(d.recordHash);
    const j = identityOccurrence(p, b.artistId, 26n, d.recordHash);
    if (!same(shared.ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE, d.position, j.position)) throw Error("Delegation position mismatch");
    const o = p.origins[eraOf(p, d.position.point)]!;
    if (artistRecoveredMultipleGenerationHydrationGrantRecordHash(o, r) !== d.recordHash) throw Error("Original delegation record preimage mismatch");
    const digest = artistRecoveredMultipleGenerationHydrationGrantDigest(o, r);
    alias(d.position.point, "identity_authority.replay.delegation_key", d.recordHash, d.recordHash);
    alias(d.position.point, "identity_authority.replay.nonce_allocator", hash(["bytes32", "uint256"], [b.artistId, r.nonce]), digest);
    alias(d.position.point, "identity_authority.replay.authorization_consumed_digest", hash(["bytes32", "bytes32"], [b.artistId, digest]), digest);
    let latest = d.recordHash;
    for (let k = i + 1; k < b.delegations.length; k++) if (b.delegations[k]!.record.grant.delegate === g.delegate) latest = b.delegations[k]!.recordHash;
    if (d.current !== latest) throw Error("Delegation current head differs from original version order");
    if (r.revoked) revoked++;
  }
  if (revoked !== revocations.length) throw Error("Incomplete original revocations");
  codec.boundedArray(b.nonces, 128);
  const keys = new Set<string>();
  for (const n of b.nonces) {
    const key = `${n.kind}:${n.key}`;
    if (n.key === Z || ![1n, 2n, 4n, 5n].includes(n.kind) || keys.has(key) || !n.words.length || n.words.length > 256) throw Error("Invalid retained nonce lane");
    keys.add(key);
    const prefixes = new Set<bigint>();
    let consumed = 0n;
    for (const w of n.words) {
      if (prefixes.has(w.prefix) || w.exhausted !== n.words[0]!.exhausted) throw Error("Invalid original nonce prefix");
      prefixes.add(w.prefix);
      if (n.kind === 2n) {
        if (w.prefix >= 1n << 248n || !w.words[0]) throw Error("Invalid delegated nonce consumption");
        let word = w.words[0]!;
        while (word) { word &= word - 1n; consumed++; }
      }
    }
    if (n.kind === 2n) {
      const uses = b.delegations.filter(d => artistRecoveredMultipleGenerationHydrationDelegateLane(b.artistId, d.record.grant.delegate) === n.key).reduce((sum, d) => sum + d.record.uses, 0n);
      if (!uses || consumed !== uses) throw Error("Delegate nonce bits differ from complete grant uses");
    }
  }
  for (const d of b.delegations) if (d.record.uses && !b.nonces.some(n => n.kind === 2n && n.key === artistRecoveredMultipleGenerationHydrationDelegateLane(b.artistId, d.record.grant.delegate))) throw Error("Missing used delegate nonce lane");
  return b;
}

/** Reconcile every retained grant once across every selected collection and supported family. */
export function validateArtistRecoveredMultipleGenerationHydrationGrantUses(
  identities: readonly ArtistRecoveredMultipleGenerationHydrationIdentity[], collections: readonly ArtistHydrationQuery[],
  values: readonly ArtistRecoveredMultipleGenerationHydrationConsents[], inventory: ArtistRecoveredMultipleGenerationHydrationInventory,
  provenance: shared.ArtistRecoveredHydrationProvenance,
  attestations: readonly ArtistRecoveredMultipleGenerationHydrationAttestationBundle[],
): void {
  codec.boundedArray(identities, 128); codec.boundedArray(collections, 128); codec.boundedArray(values, 128, collections.length); inventory = normalizeArtistRecoveredMultipleGenerationHydrationInventory(inventory); codec.boundedArray(inventory.bindings, 128, collections.length);
  identities = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_IDENTITY_TUPLE}[]`, identities);
  values = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONSENTS_TUPLE}[]`, values);
  attestations = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_BUNDLE_TUPLE}[]`, attestations);
  const p = codec.normalizeArtistRecoveredHydrationProvenance(provenance), ip = codec.artistRecoveredHydrationOwnerProvenance(p, 2), cp = codec.artistRecoveredHydrationOwnerProvenance(p, 6);
  const qs = codec.normalizeTuple(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, collections);
  const rows = validateArtistRecoveredMultipleGenerationHydrationContentBundles(values, qs, cp);
  const bs = inventory.bindings.map(normalizeArtistRecoveredMultipleGenerationHydrationBindingBundle);
  for (let i = 0; i < bs.length; i++) if (!same(`${bindingItemType()}[]`, values[i]!.bindings, bs[i]!.bindings.rows.map(r => r.item))) throw Error("Consent bindings differ from complete inventory");
  const artists = identities.map(v => validateArtistRecoveredMultipleGenerationHydrationDelegations(v, ip));
  if (new Set(artists.map(v => v.artistId)).size !== artists.length || qs.some(q => !artists.some(a => a.artistId === q.artistId))) throw Error("Incomplete grant Artist partition");
  const increments = validateArtistRecoveredMultipleGenerationHydrationAttestations(artists, qs, attestations, p, inventory).uses;
  for (let artistIndex = 0; artistIndex < artists.length; artistIndex++) {
    const identity = artists[artistIndex]!;
    const total = [...increments[artistIndex]!];
    for (let c = 0; c < qs.length; c++) {
      const q = qs[c]!; if (q.artistId !== identity.artistId) continue;
      const b = rows[c]!, bindings = bs[c]!.bindings.rows.map(r => r.item), binding = bindings.at(-1)!;
      if (binding.artistId !== q.artistId || binding.bindingHash !== q.bindingHash || ![1n, 2n].includes(binding.consentMode)) throw Error("Grant facts binding mismatch");
      const use = (grant: Hex, capability: bigint, record: Hex, royalty = false): number => {
        const at = identity.delegations.findIndex(d => d.recordHash === grant);
        if (at < 0) throw Error("Consent references an absent original grant");
        const d = identity.delegations[at]!, g = d.record.grant;
        const consent = cp.journal.find(j => j.receipt.recordHash === record);
        if (!consent || consent.receipt.artistId !== q.artistId || consent.receipt.collectionId !== q.collectionId) throw Error("Grant consent occurrence mismatch");
        const useEra = eraOf(cp, consent.position.point);
        if (g.artistId !== identity.artistId || g.collectionId !== 0n && g.collectionId !== q.collectionId
          || !(g.capabilities & capability) || eraOf(ip, d.position.point) > useEra
          || d.record.revoked && eraOf(ip, identityOccurrence(ip, identity.artistId, 27n, d.record.revocationRecordHash).position.point) < useEra) throw Error("Grant scope or historical era mismatch");
        if (royalty && identity.delegations.slice(at + 1).some(next => next.record.grant.delegate === g.delegate && eraOf(ip, next.position.point) < useEra)) throw Error("Royalty use follows an earlier-era replacement");
        total[at] = total[at]! + 1n; return at;
      };
      for (const r of b.original.policies) if (r.grant !== Z) {
        if (!bindings.some(b => b.accepted && b.consentMode === 2n)) throw Error("Delegated policy requires an accepted historical mode2");
        use(r.grant, 2n, r.recordHash);
      }
      for (const r of b.original.economics) if (r.grant !== Z) use(r.grant, 4n, r.item.recordHash);
      for (const r of b.original.sales) if (r.grant !== Z) {
        if (!acceptedBinding(bindings, r.item.bindingGeneration, r.item.bindingHash, true)) throw Error("Delegated sale requires its exact accepted mode2 binding");
        const at = use(r.grant, 1024n, r.item.recordHash), d = identity.delegations[at]!;
        if (r.item.authorityClass !== 2n || r.item.signer !== d.record.grant.delegate) throw Error("Sale delegate identity mismatch");
        const sale = cp.journal.find(j => j.receipt.recordHash === r.item.recordHash)!;
        const scope = hash(["bytes32", "uint256"], [artistRecoveredMultipleGenerationHydrationDelegateLane(identity.artistId, d.record.grant.delegate), r.item.nonce]);
        const aliases = ip.aliases.filter(a => a.surface === id("identity_authority.replay.delegated_nonce") && a.scope === scope);
        if (!aliases.length) throw Error("Missing original delegated sale nonce");
        const admitted = aliases[0]!.admittedAt;
        if (aliases.some(a => a.cell.kind !== 1n || a.cell.status !== 2n || a.cell.commitment === Z || a.admittedAt.environmentHash !== sale.position.point.environmentHash
          || !same(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, a.admittedAt, admitted)) || !before(ip, d.position.point, admitted)
          || d.record.revoked && !before(ip, admitted, identityOccurrence(ip, identity.artistId, 27n, d.record.revocationRecordHash).position.point)
          || identity.delegations.slice(at + 1).some(next => next.record.grant.delegate === d.record.grant.delegate && !before(ip, admitted, next.position.point))) throw Error("Delegated sale nonce chronology mismatch");
      }
      for (const r of b.royalties) if (r.grant !== Z) use(r.grant, 32n, r.item.recordHash, true);
      for (const record of [...b.consents.map(r => r.recordHash), ...b.royalties.map(r => r.item.recordHash), ...b.freezes.map(r => r.recordHash)]) {
        const signatures = identity.signatures.filter(s => s.recordHash === record);
        if (signatures.length !== 1 || (signatures[0]!.signature.length - 2) / 2 > 4096) throw Error("Content occurrence requires exactly one original signature row");
      }
    }
    if (total.some((uses, i) => uses !== identity.delegations[i]!.record.uses)) throw Error("Grant uses differ from complete cross-collection consent occurrences");
  }
}

/** Binds caller-supplied economics witnesses and royalty terms to the complete retained rows. */
export function validateArtistRecoveredMultipleGenerationHydrationInput(
  value: ArtistRecoveredMultipleGenerationHydrationInput, prepared: shared.ArtistRecoveredHydrationPrepared,
): ArtistRecoveredMultipleGenerationHydrationInput {
  const input = normalizeArtistRecoveredMultipleGenerationHydrationInput(value);
  const p = normalizeArtistRecoveredMultipleGenerationHydrationPrepared(prepared);
  codec.encodeArtistRecoveredHydrationProfileEvidence(input.request, p);
  const { payload } = decodeArtistRecoveredMultipleGenerationHydrationOwnerPayload(p.data[6].typedState, 6);
  const state = decodeArtistRecoveredMultipleGenerationHydrationState(payload.semanticState, 6, payload.provenance);
  const all = state.rows.map(raw => decodeArtistRecoveredMultipleGenerationHydrationConsents(raw).rows);
  validateWitnessRows(input.request, p.data[6].typedState, p.data[4].typedState);
  const terms: ArtistRecoveredMultipleGenerationHydrationRoyaltyFreeze[] = [];
  for (const j of payload.provenance.journal) if (j.receipt.operation === 20n) {
    const b = all.find(v => v.original.collectionId === j.receipt.collectionId && v.original.artistId === j.receipt.artistId)!;
    const row = b.royalties.find(r => r.item.recordHash === j.receipt.recordHash);
    if (!row) throw Error("Missing original royalty occurrence");
    terms.push(row.terms);
  }
  if (!same(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ROYALTY_FREEZE_TUPLE}[]`, input.royaltyFreezes, terms)) throw Error("Royalty selectors differ from original global operation20 order");
  return input;
}

function validateWitnessRows(request: shared.ArtistRecoveredHydrationRequest, consentRaw: Hex, attestationRaw: Hex): void {
  const r = codec.normalizeArtistRecoveredHydrationRequest(request);
  const { payload } = decodeArtistRecoveredMultipleGenerationHydrationOwnerPayload(consentRaw, 6);
  const consent = decodeArtistRecoveredMultipleGenerationHydrationState(payload.semanticState, 6, payload.provenance).rows.map(raw => decodeArtistRecoveredMultipleGenerationHydrationConsents(raw).rows);
  const { payload: ap } = decodeArtistRecoveredMultipleGenerationHydrationOwnerPayload(attestationRaw, 4);
  const attestations = decodeArtistRecoveredMultipleGenerationHydrationState(ap.semanticState, 4, ap.provenance).rows.map(raw => decodeArtistRecoveredMultipleGenerationHydrationAttribution(raw).records);
  let cursor = 0;
  for (let i = 0; i < consent.length; i++) {
    const b = consent[i]!, a = attestations[i]!;
    if (b.original.collectionId !== a.collectionId) throw Error("Witness owner partitions differ");
    if (!b.original.economics.length && !a.records.length) continue;
    const w = r.records.witnesses[cursor++];
    if (!w || w.collectionId !== a.collectionId
      || !same(`${shared.ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE}[]`, w.economics, b.original.economics.map(row => row.item.terms))
      || !same(`${shared.ARTIST_RECOVERED_HYDRATION_ATTESTATION_INPUT_TUPLE}[]`, w.attestations, a.records.map(row => row.attestation.input))) throw Error("Witnesses differ from complete original collection occurrence order");
  }
  if (cursor !== r.records.witnesses.length) throw Error("Incomplete or extra witness selection");
}

// Complete value-only schemas retained from the pinned compiler declarations.
// These tuple codecs do not derive public library selectors.
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_BUNDLE_TUPLE = "tuple(bytes32 provenance,bytes32 artistId,uint256 collectionId,bytes32 bindingHash,tuple(uint8 state,uint64 generation) item,tuple(tuple(tuple(tuple(uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,string statementURI) terms,uint256 nonce) input,tuple(bytes32 recordHash,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,uint64 generation,uint64 signedAt,address signer) record,uint8 authorityClass,tuple(bytes32 artistId,bytes32 bindingHash,uint64 generation,bytes32 delegation,tuple(address owner,bytes32 ownerCodeHash,bytes32 subjectId,bytes32 stateHash) fact) association,bytes statement) attestation,tuple(tuple(address metadataHost,address recorder,uint256 collectionId,bytes32 subjectId,bytes32 recordType,bytes32 schemaId,bytes32 canonicalizationId,uint16 payloadAlgorithm,bytes32 payloadHash,bytes32 uriHash,uint64 effectiveAt,bytes32 candidateRecordHash) publication,tuple(bytes32 attestationRecordHash,bytes32 artistId,bytes32 bindingHash,uint64 bindingGeneration,address signer,uint8 authorityClass,uint32 requiredCapability,uint64 signedAt,bytes32 publicationHash) evidence,bytes32 metadataHostCodeHash) publication)[] records,tuple(bytes32 recordHash,address originalRegistry,tuple(uint16 version,uint256 chainId,bytes32 nativeRecordHash,bytes32 statementHash,bytes32 artistId,bytes32 bindingHash,uint64 generation,uint256 collectionId,bytes32 identityRecordHash,tuple(uint16 version,bytes32 profileHash,address artistRegistry,bytes32 artistId,bytes32 operativeIdentityRecordHash,address notarizationHost,bytes32 notarizationRuntimeHash,bytes32 notarizationRecordHash) evidenceReference,bytes32 originalRegistryCodeHash,address core,bytes32 coreCodeHash,address moduleRegistry,bytes32 moduleRegistryCodeHash,address schemaRegistry,bytes32 schemaRegistryCodeHash,address chunkStore,bytes32 chunkStoreCodeHash,bytes32[4] definitionFactsHashes,uint256 notarizationCollectionId,bytes32 attestationType,bytes32 subjectId,address recorder,bytes32 documentaryHash,bytes32 moduleIdentityHash,address[6] carriers,bytes32[6] carrierCodeHashes) summary,bytes32 summaryHash)[] personhood)";
export type ArtistRecoveredMultipleGenerationHydrationAttestationBundle = { readonly provenance: Hex; readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex; readonly item: { readonly state: bigint; readonly generation: bigint; }; readonly records: readonly ({ readonly attestation: { readonly input: { readonly terms: { readonly collectionId: bigint; readonly subjectKind: bigint; readonly subjectId: Hex; readonly subjectStateHash: Hex; readonly schemaId: Hex; readonly statementHash: Hex; readonly statementURI: string; }; readonly nonce: bigint; }; readonly record: { readonly recordHash: Hex; readonly subjectStateHash: Hex; readonly schemaId: Hex; readonly statementHash: Hex; readonly generation: bigint; readonly signedAt: bigint; readonly signer: Address; }; readonly authorityClass: bigint; readonly association: { readonly artistId: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly delegation: Hex; readonly fact: { readonly owner: Address; readonly ownerCodeHash: Hex; readonly subjectId: Hex; readonly stateHash: Hex; }; }; readonly statement: Hex; }; readonly publication: { readonly publication: { readonly metadataHost: Address; readonly recorder: Address; readonly collectionId: bigint; readonly subjectId: Hex; readonly recordType: Hex; readonly schemaId: Hex; readonly canonicalizationId: Hex; readonly payloadAlgorithm: bigint; readonly payloadHash: Hex; readonly uriHash: Hex; readonly effectiveAt: bigint; readonly candidateRecordHash: Hex; }; readonly evidence: { readonly attestationRecordHash: Hex; readonly artistId: Hex; readonly bindingHash: Hex; readonly bindingGeneration: bigint; readonly signer: Address; readonly authorityClass: bigint; readonly requiredCapability: bigint; readonly signedAt: bigint; readonly publicationHash: Hex; }; readonly metadataHostCodeHash: Hex; }; })[]; readonly personhood: readonly ({ readonly recordHash: Hex; readonly originalRegistry: Address; readonly summary: { readonly version: bigint; readonly chainId: bigint; readonly nativeRecordHash: Hex; readonly statementHash: Hex; readonly artistId: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly collectionId: bigint; readonly identityRecordHash: Hex; readonly evidenceReference: { readonly version: bigint; readonly profileHash: Hex; readonly artistRegistry: Address; readonly artistId: Hex; readonly operativeIdentityRecordHash: Hex; readonly notarizationHost: Address; readonly notarizationRuntimeHash: Hex; readonly notarizationRecordHash: Hex; }; readonly originalRegistryCodeHash: Hex; readonly core: Address; readonly coreCodeHash: Hex; readonly moduleRegistry: Address; readonly moduleRegistryCodeHash: Hex; readonly schemaRegistry: Address; readonly schemaRegistryCodeHash: Hex; readonly chunkStore: Address; readonly chunkStoreCodeHash: Hex; readonly definitionFactsHashes: readonly [Hex,Hex,Hex,Hex]; readonly notarizationCollectionId: bigint; readonly attestationType: Hex; readonly subjectId: Hex; readonly recorder: Address; readonly documentaryHash: Hex; readonly moduleIdentityHash: Hex; readonly carriers: readonly [Address,Address,Address,Address,Address,Address]; readonly carrierCodeHashes: readonly [Hex,Hex,Hex,Hex,Hex,Hex]; }; readonly summaryHash: Hex; })[]; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_ROW_TUPLE = "tuple(tuple(tuple(uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,string statementURI) terms,uint256 nonce) input,tuple(bytes32 recordHash,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,uint64 generation,uint64 signedAt,address signer) record,uint8 authorityClass,tuple(bytes32 artistId,bytes32 bindingHash,uint64 generation,bytes32 delegation,tuple(address owner,bytes32 ownerCodeHash,bytes32 subjectId,bytes32 stateHash) fact) association,bytes statement)";
export type ArtistRecoveredMultipleGenerationHydrationAttestationRow = { readonly input: { readonly terms: { readonly collectionId: bigint; readonly subjectKind: bigint; readonly subjectId: Hex; readonly subjectStateHash: Hex; readonly schemaId: Hex; readonly statementHash: Hex; readonly statementURI: string; }; readonly nonce: bigint; }; readonly record: { readonly recordHash: Hex; readonly subjectStateHash: Hex; readonly schemaId: Hex; readonly statementHash: Hex; readonly generation: bigint; readonly signedAt: bigint; readonly signer: Address; }; readonly authorityClass: bigint; readonly association: { readonly artistId: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly delegation: Hex; readonly fact: { readonly owner: Address; readonly ownerCodeHash: Hex; readonly subjectId: Hex; readonly stateHash: Hex; }; }; readonly statement: Hex; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PUBLICATION_ROW_TUPLE = "tuple(tuple(tuple(tuple(uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,string statementURI) terms,uint256 nonce) input,tuple(bytes32 recordHash,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,uint64 generation,uint64 signedAt,address signer) record,uint8 authorityClass,tuple(bytes32 artistId,bytes32 bindingHash,uint64 generation,bytes32 delegation,tuple(address owner,bytes32 ownerCodeHash,bytes32 subjectId,bytes32 stateHash) fact) association,bytes statement) attestation,tuple(tuple(address metadataHost,address recorder,uint256 collectionId,bytes32 subjectId,bytes32 recordType,bytes32 schemaId,bytes32 canonicalizationId,uint16 payloadAlgorithm,bytes32 payloadHash,bytes32 uriHash,uint64 effectiveAt,bytes32 candidateRecordHash) publication,tuple(bytes32 attestationRecordHash,bytes32 artistId,bytes32 bindingHash,uint64 bindingGeneration,address signer,uint8 authorityClass,uint32 requiredCapability,uint64 signedAt,bytes32 publicationHash) evidence,bytes32 metadataHostCodeHash) publication)";
export type ArtistRecoveredMultipleGenerationHydrationPublicationRow = { readonly attestation: { readonly input: { readonly terms: { readonly collectionId: bigint; readonly subjectKind: bigint; readonly subjectId: Hex; readonly subjectStateHash: Hex; readonly schemaId: Hex; readonly statementHash: Hex; readonly statementURI: string; }; readonly nonce: bigint; }; readonly record: { readonly recordHash: Hex; readonly subjectStateHash: Hex; readonly schemaId: Hex; readonly statementHash: Hex; readonly generation: bigint; readonly signedAt: bigint; readonly signer: Address; }; readonly authorityClass: bigint; readonly association: { readonly artistId: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly delegation: Hex; readonly fact: { readonly owner: Address; readonly ownerCodeHash: Hex; readonly subjectId: Hex; readonly stateHash: Hex; }; }; readonly statement: Hex; }; readonly publication: { readonly publication: { readonly metadataHost: Address; readonly recorder: Address; readonly collectionId: bigint; readonly subjectId: Hex; readonly recordType: Hex; readonly schemaId: Hex; readonly canonicalizationId: Hex; readonly payloadAlgorithm: bigint; readonly payloadHash: Hex; readonly uriHash: Hex; readonly effectiveAt: bigint; readonly candidateRecordHash: Hex; }; readonly evidence: { readonly attestationRecordHash: Hex; readonly artistId: Hex; readonly bindingHash: Hex; readonly bindingGeneration: bigint; readonly signer: Address; readonly authorityClass: bigint; readonly requiredCapability: bigint; readonly signedAt: bigint; readonly publicationHash: Hex; }; readonly metadataHostCodeHash: Hex; }; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_ROW_TUPLE = "tuple(bytes32 recordHash,address originalRegistry,tuple(uint16 version,uint256 chainId,bytes32 nativeRecordHash,bytes32 statementHash,bytes32 artistId,bytes32 bindingHash,uint64 generation,uint256 collectionId,bytes32 identityRecordHash,tuple(uint16 version,bytes32 profileHash,address artistRegistry,bytes32 artistId,bytes32 operativeIdentityRecordHash,address notarizationHost,bytes32 notarizationRuntimeHash,bytes32 notarizationRecordHash) evidenceReference,bytes32 originalRegistryCodeHash,address core,bytes32 coreCodeHash,address moduleRegistry,bytes32 moduleRegistryCodeHash,address schemaRegistry,bytes32 schemaRegistryCodeHash,address chunkStore,bytes32 chunkStoreCodeHash,bytes32[4] definitionFactsHashes,uint256 notarizationCollectionId,bytes32 attestationType,bytes32 subjectId,address recorder,bytes32 documentaryHash,bytes32 moduleIdentityHash,address[6] carriers,bytes32[6] carrierCodeHashes) summary,bytes32 summaryHash)";
export type ArtistRecoveredMultipleGenerationHydrationPersonhoodRow = { readonly recordHash: Hex; readonly originalRegistry: Address; readonly summary: { readonly version: bigint; readonly chainId: bigint; readonly nativeRecordHash: Hex; readonly statementHash: Hex; readonly artistId: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly collectionId: bigint; readonly identityRecordHash: Hex; readonly evidenceReference: { readonly version: bigint; readonly profileHash: Hex; readonly artistRegistry: Address; readonly artistId: Hex; readonly operativeIdentityRecordHash: Hex; readonly notarizationHost: Address; readonly notarizationRuntimeHash: Hex; readonly notarizationRecordHash: Hex; }; readonly originalRegistryCodeHash: Hex; readonly core: Address; readonly coreCodeHash: Hex; readonly moduleRegistry: Address; readonly moduleRegistryCodeHash: Hex; readonly schemaRegistry: Address; readonly schemaRegistryCodeHash: Hex; readonly chunkStore: Address; readonly chunkStoreCodeHash: Hex; readonly definitionFactsHashes: readonly [Hex,Hex,Hex,Hex]; readonly notarizationCollectionId: bigint; readonly attestationType: Hex; readonly subjectId: Hex; readonly recorder: Address; readonly documentaryHash: Hex; readonly moduleIdentityHash: Hex; readonly carriers: readonly [Address,Address,Address,Address,Address,Address]; readonly carrierCodeHashes: readonly [Hex,Hex,Hex,Hex,Hex,Hex]; }; readonly summaryHash: Hex; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_REFERENCE_TUPLE = "tuple(uint16 version,bytes32 profileHash,address artistRegistry,bytes32 artistId,bytes32 operativeIdentityRecordHash,address notarizationHost,bytes32 notarizationRuntimeHash,bytes32 notarizationRecordHash)";
export type ArtistRecoveredMultipleGenerationHydrationPersonhoodReference = { readonly version: bigint; readonly profileHash: Hex; readonly artistRegistry: Address; readonly artistId: Hex; readonly operativeIdentityRecordHash: Hex; readonly notarizationHost: Address; readonly notarizationRuntimeHash: Hex; readonly notarizationRecordHash: Hex; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_SUMMARY_TUPLE = "tuple(uint16 version,uint256 chainId,bytes32 nativeRecordHash,bytes32 statementHash,bytes32 artistId,bytes32 bindingHash,uint64 generation,uint256 collectionId,bytes32 identityRecordHash,tuple(uint16 version,bytes32 profileHash,address artistRegistry,bytes32 artistId,bytes32 operativeIdentityRecordHash,address notarizationHost,bytes32 notarizationRuntimeHash,bytes32 notarizationRecordHash) evidenceReference,bytes32 originalRegistryCodeHash,address core,bytes32 coreCodeHash,address moduleRegistry,bytes32 moduleRegistryCodeHash,address schemaRegistry,bytes32 schemaRegistryCodeHash,address chunkStore,bytes32 chunkStoreCodeHash,bytes32[4] definitionFactsHashes,uint256 notarizationCollectionId,bytes32 attestationType,bytes32 subjectId,address recorder,bytes32 documentaryHash,bytes32 moduleIdentityHash,address[6] carriers,bytes32[6] carrierCodeHashes)";
export type ArtistRecoveredMultipleGenerationHydrationPersonhoodSummary = { readonly version: bigint; readonly chainId: bigint; readonly nativeRecordHash: Hex; readonly statementHash: Hex; readonly artistId: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly collectionId: bigint; readonly identityRecordHash: Hex; readonly evidenceReference: { readonly version: bigint; readonly profileHash: Hex; readonly artistRegistry: Address; readonly artistId: Hex; readonly operativeIdentityRecordHash: Hex; readonly notarizationHost: Address; readonly notarizationRuntimeHash: Hex; readonly notarizationRecordHash: Hex; }; readonly originalRegistryCodeHash: Hex; readonly core: Address; readonly coreCodeHash: Hex; readonly moduleRegistry: Address; readonly moduleRegistryCodeHash: Hex; readonly schemaRegistry: Address; readonly schemaRegistryCodeHash: Hex; readonly chunkStore: Address; readonly chunkStoreCodeHash: Hex; readonly definitionFactsHashes: readonly [Hex,Hex,Hex,Hex]; readonly notarizationCollectionId: bigint; readonly attestationType: Hex; readonly subjectId: Hex; readonly recorder: Address; readonly documentaryHash: Hex; readonly moduleIdentityHash: Hex; readonly carriers: readonly [Address,Address,Address,Address,Address,Address]; readonly carrierCodeHashes: readonly [Hex,Hex,Hex,Hex,Hex,Hex]; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CREDENTIAL_PAYLOAD_TUPLE = "tuple(uint16 schemaVersion,bytes32 artistId,bytes32 identityRecordHash,bytes32 previousRecordHash,tuple(uint8 kind,bytes32 fingerprint,bytes32 keyId,uint64 validFrom,uint64 validUntil)[] credentials)";
export type ArtistRecoveredMultipleGenerationHydrationCredentialPayload = { readonly schemaVersion: bigint; readonly artistId: Hex; readonly identityRecordHash: Hex; readonly previousRecordHash: Hex; readonly credentials: readonly ({ readonly kind: bigint; readonly fingerprint: Hex; readonly keyId: Hex; readonly validFrom: bigint; readonly validUntil: bigint; })[]; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CREDENTIAL_HEAD_TUPLE = "tuple(uint64 revision,bytes32 recordHash,bytes32 previousRecordHash,bytes32 artistId,uint256 collectionId,bytes32 bindingHash,uint64 generation,bytes32 identityRecordHash,bytes32 statementHash,address sourceRegistry)";
export type ArtistRecoveredMultipleGenerationHydrationCredentialHead = { readonly revision: bigint; readonly recordHash: Hex; readonly previousRecordHash: Hex; readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex; readonly generation: bigint; readonly identityRecordHash: Hex; readonly statementHash: Hex; readonly sourceRegistry: Address; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CATALOGUE_TUPLE = "tuple(bytes32 originHash,bytes32 archiveCodeHash,bytes32 configurationHash,uint256 count,bytes32 rowsHash,uint64[7] lower,uint64[7] upper)";
export type ArtistRecoveredMultipleGenerationHydrationCatalogue = { readonly originHash: Hex; readonly archiveCodeHash: Hex; readonly configurationHash: Hex; readonly count: bigint; readonly rowsHash: Hex; readonly lower: readonly [bigint,bigint,bigint,bigint,bigint,bigint,bigint]; readonly upper: readonly [bigint,bigint,bigint,bigint,bigint,bigint,bigint]; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ARCHIVE_EVIDENCE_TUPLE = "tuple(uint256 catalogueIndex,address pointer,bytes32 payloadHash,bytes32 evidenceId)";
export type ArtistRecoveredMultipleGenerationHydrationArchiveEvidence = { readonly catalogueIndex: bigint; readonly pointer: Address; readonly payloadHash: Hex; readonly evidenceId: Hex; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ARCHIVE_OPERATION_TUPLE = "tuple(bytes32 originHash,uint16 operation,tuple(uint256 catalogueIndex,address pointer,bytes32 payloadHash,bytes32 evidenceId) evidence)";
export type ArtistRecoveredMultipleGenerationHydrationArchiveOperation = { readonly originHash: Hex; readonly operation: bigint; readonly evidence: { readonly catalogueIndex: bigint; readonly pointer: Address; readonly payloadHash: Hex; readonly evidenceId: Hex; }; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ARCHIVE_ENVELOPE_TUPLE = "tuple(uint16 version,bytes32 configurationHash,uint16 operation,address actor,bytes32 value,tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)[7] before_,tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)[7] after_,bytes payload)";
export type ArtistRecoveredMultipleGenerationHydrationArchiveEnvelope = { readonly version: bigint; readonly configurationHash: Hex; readonly operation: bigint; readonly actor: Address; readonly value: Hex; readonly before_: readonly [{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }]; readonly after_: readonly [{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }]; readonly payload: Hex; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PROPOSAL_PAYLOAD_TUPLE = "tuple(uint256 id,tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,string identityRecordURI,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,uint8 collabPolicyMode,uint32 collabThreshold,tuple(address account,bytes32 role,bytes32 shareLabelId)[] collaborators,tuple(uint32 capabilityMask,uint8 mode,uint32 threshold)[] capabilityPolicyOverrides,bytes32 reasonHash,string reasonURI) proposal,bytes document,string displayName,bool reused,bytes32 roleHash,uint64 roleRevision)";
export type ArtistRecoveredMultipleGenerationHydrationProposalPayload = { readonly id: bigint; readonly proposal: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly identityRecordURI: string; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly collabPolicyMode: bigint; readonly collabThreshold: bigint; readonly collaborators: readonly ({ readonly account: Address; readonly role: Hex; readonly shareLabelId: Hex; })[]; readonly capabilityPolicyOverrides: readonly ({ readonly capabilityMask: bigint; readonly mode: bigint; readonly threshold: bigint; })[]; readonly reasonHash: Hex; readonly reasonURI: string; }; readonly document: Hex; readonly displayName: string; readonly reused: boolean; readonly roleHash: Hex; readonly roleRevision: bigint; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACCEPTANCE_PAYLOAD_TUPLE = "tuple(uint256 id,tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) binding_,tuple(uint256 nonce,uint64 time,bytes signature) authorization,tuple(address signer,bytes32 digest,bool direct) proof)";
export type ArtistRecoveredMultipleGenerationHydrationAcceptancePayload = { readonly id: bigint; readonly binding_: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly authorization: { readonly nonce: bigint; readonly time: bigint; readonly signature: Hex; }; readonly proof: { readonly signer: Address; readonly digest: Hex; readonly direct: boolean; }; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_AUTHORITY_FACT_TUPLE = "tuple(bytes32 artistId,address authorityAddress,uint8 authorityClass,uint8 status)";
export type ArtistRecoveredMultipleGenerationHydrationAuthorityFact = { readonly artistId: Hex; readonly authorityAddress: Address; readonly authorityClass: bigint; readonly status: bigint; };
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_RECORD_PUBLICATION_TUPLE = "tuple(address metadataHost,address recorder,uint256 collectionId,bytes32 subjectId,bytes32 recordType,bytes32 schemaId,bytes32 canonicalizationId,uint16 payloadAlgorithm,bytes32 payloadHash,bytes32 uriHash,uint64 effectiveAt,bytes32 candidateRecordHash)";
export type ArtistRecoveredMultipleGenerationHydrationRecordPublication = { readonly metadataHost: Address; readonly recorder: Address; readonly collectionId: bigint; readonly subjectId: Hex; readonly recordType: Hex; readonly schemaId: Hex; readonly canonicalizationId: Hex; readonly payloadAlgorithm: bigint; readonly payloadHash: Hex; readonly uriHash: Hex; readonly effectiveAt: bigint; readonly candidateRecordHash: Hex; };

export function normalizeArtistRecoveredMultipleGenerationHydrationAttestationBundle(value: ArtistRecoveredMultipleGenerationHydrationAttestationBundle): ArtistRecoveredMultipleGenerationHydrationAttestationBundle {
  return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_BUNDLE_TUPLE, value);
}
export function encodeArtistRecoveredMultipleGenerationHydrationAttestationBundle(value: ArtistRecoveredMultipleGenerationHydrationAttestationBundle): Hex {
  return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_BUNDLE_TUPLE], [normalizeArtistRecoveredMultipleGenerationHydrationAttestationBundle(value)]);
}
export function decodeArtistRecoveredMultipleGenerationHydrationAttestationBundle(raw: Hex): ArtistRecoveredMultipleGenerationHydrationAttestationBundle {
  return decode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_BUNDLE_TUPLE, raw);
}
export function artistRecoveredMultipleGenerationHydrationAttestationRecordHash(origin: shared.ArtistRecoveredHydrationOriginEnvironment,
  artistId: Hex, value: ArtistRecoveredMultipleGenerationHydrationAttestationRow): Hex {
  const o = codec.normalizeArtistRecoveredHydrationOriginEnvironment(origin), r = codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_ROW_TUPLE, value), t = r.input.terms;
  return hash(["bytes32", "uint256", "address", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"), o.chainId, o.registry, o.core, t.collectionId, t.subjectKind, t.subjectId, t.subjectStateHash,
      t.schemaId, t.statementHash, keccak256(toUtf8Bytes(t.statementURI)), codec.boundedBytes(artistId, 32), r.record.signer, r.authorityClass, r.input.nonce, r.record.signedAt]);
}
export function artistRecoveredMultipleGenerationHydrationAttestationDigest(origin: shared.ArtistRecoveredHydrationOriginEnvironment,
  value: ArtistRecoveredMultipleGenerationHydrationAttestationRow): Hex {
  const o = codec.normalizeArtistRecoveredHydrationOriginEnvironment(origin), r = codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_ROW_TUPLE, value), t = r.input.terms;
  return originalTypedDigest(o, hash(["bytes32", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64"],
    [id("StreamArtistAttestation(address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt)"),
      o.core, t.collectionId, t.subjectKind, t.subjectId, t.subjectStateHash, t.schemaId, t.statementHash, keccak256(toUtf8Bytes(t.statementURI)), r.input.nonce, r.record.signedAt]));
}
export function decodeArtistRecoveredMultipleGenerationHydrationCredentialPayload(raw: Hex, artistId: Hex, identityRecordHash: Hex): ArtistRecoveredMultipleGenerationHydrationCredentialPayload {
  const p = decode<ArtistRecoveredMultipleGenerationHydrationCredentialPayload>(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CREDENTIAL_PAYLOAD_TUPLE, codec.boundedBytes(raw, undefined, 8192));
  if (p.schemaVersion !== 1n || p.artistId !== artistId || artistId === Z || p.identityRecordHash !== identityRecordHash || identityRecordHash === Z || p.credentials.length > 48) throw Error("Invalid original C2PA payload");
  const credential = schemaType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CREDENTIAL_PAYLOAD_TUPLE).components!.find(c => c.name === "credentials")!.arrayChildren!.format("full");
  let previous = 0n;
  for (let i = 0; i < p.credentials.length; i++) {
    const c = p.credentials[i]!, key = BigInt(hash([credential], [c]));
    if (!c.kind || c.fingerprint === Z || c.keyId === Z || c.validUntil !== 0n && c.validUntil <= c.validFrom || i > 0 && key <= previous) throw Error("Invalid original ordered credential enumeration");
    previous = key;
  }
  return p;
}
function personhood(schema: Hex): boolean { return schema === ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_EVIDENCE_SCHEMA || schema === ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_WAIVER_SCHEMA; }
export function artistRecoveredMultipleGenerationHydrationPersonhoodReference(raw: Hex): ArtistRecoveredMultipleGenerationHydrationPersonhoodReference | null {
  const bytes = codec.boundedBytes(raw, undefined, 8192);
  if ((bytes.length - 2) / 2 !== 590) return null;
  let text: string; try { text = toUtf8String(bytes); } catch { return null; }
  const offsets = [15, 101, 165, 235, 330, 429, 512];
  const values = offsets.map((offset, i) => text.slice(offset, offset + (i === 1 || i === 2 ? 40 : 64)));
  if (values.some((s, i) => !(i === 1 || i === 2 ? /^[0-9a-f]{40}$/ : /^[0-9a-f]{64}$/).test(s))) return null;
  const ref = codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_REFERENCE_TUPLE, {
    version: 1n, artistId: `0x${values[0]}`, artistRegistry: `0x${values[1]}`, notarizationHost: `0x${values[2]}`, notarizationRecordHash: `0x${values[3]}`,
    notarizationRuntimeHash: `0x${values[4]}`, operativeIdentityRecordHash: `0x${values[5]}`, profileHash: `0x${values[6]}`,
  }) as ArtistRecoveredMultipleGenerationHydrationPersonhoodReference;
  if (ref.profileHash !== "0x06eaf449a0abe6a4305706d589bc597f14f7d23f62acc661b4b1fff128b921c3" || ref.artistId === Z || ref.artistRegistry === ZeroAddress
    || ref.notarizationHost === ZeroAddress || ref.notarizationRecordHash === Z || ref.notarizationRuntimeHash === Z || ref.operativeIdentityRecordHash === Z) return null;
  const canonical = `{"artistId":"${ref.artistId}","artistRegistry":"${ref.artistRegistry.toLowerCase()}","notarizationHost":"${ref.notarizationHost.toLowerCase()}","notarizationRecordHash":"${ref.notarizationRecordHash}","notarizationRuntimeHash":"${ref.notarizationRuntimeHash}","operativeIdentityRecordHash":"${ref.operativeIdentityRecordHash}","profileHash":"${ref.profileHash}","version":1}`;
  return text === canonical ? ref : null;
}
function validateAttestationRow(q: ArtistHydrationQuery, o: shared.ArtistRecoveredHydrationOriginEnvironment, row: ArtistRecoveredMultipleGenerationHydrationPublicationRow, generation: bigint): void {
  const r = row.attestation, t = r.input.terms, saved = r.record, a = r.association, publication = t.subjectKind === 7n || t.subjectKind === 8n;
  if (t.collectionId !== q.collectionId || t.subjectKind < 1n || t.subjectKind > 10n || ![1n, 2n, 3n].includes(r.authorityClass)
    || saved.recordHash === Z || saved.generation !== generation || saved.signer === ZeroAddress || !saved.signedAt || r.statement === "0x"
    || (r.statement.length - 2) / 2 > 8192 || toUtf8Bytes(t.statementURI).length > 2048 || keccak256(r.statement) !== t.statementHash
    || saved.statementHash !== t.statementHash || saved.schemaId !== t.schemaId || saved.subjectStateHash !== t.subjectStateHash
    || artistRecoveredMultipleGenerationHydrationAttestationRecordHash(o, q.artistId, r) !== saved.recordHash) throw Error("Invalid original attestation row/preimage");
  const associationType = childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_ROW_TUPLE, "association");
  if (a.artistId === Z) {
    if ((!publication && t.subjectKind !== 9n && t.subjectKind !== 10n) || r.authorityClass === 2n || !same(associationType, a, zeroValue(schemaType(associationType)))) throw Error("Invalid original empty attestation association");
  } else if (a.artistId !== q.artistId || a.bindingHash !== q.bindingHash || a.generation !== generation || (r.authorityClass === 2n) !== (a.delegation !== Z)
    || a.fact.owner === ZeroAddress || a.fact.ownerCodeHash === Z || a.fact.subjectId !== t.subjectId || a.fact.stateHash !== t.subjectStateHash) throw Error("Attestation association differs from original scope");
  if (t.subjectKind <= 6n && (t.subjectStateHash === Z || t.schemaId === Z)) throw Error("Invalid original resolved subject");
  if (t.subjectKind === 9n && (a.artistId !== Z && a.fact.owner !== o.core || BigInt(t.subjectId) !== BigInt(o.core)
    || t.schemaId !== id("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1") || t.subjectStateHash !== hash(["bytes32", "uint256", "address", "uint256", "bytes32", "uint64", "bytes32"],
      [id("6529STREAM_ARTIST_DEPLOYMENT_FACTS_V1"), o.chainId, o.core, q.collectionId, q.artistId, generation, q.bindingHash]))) throw Error("Invalid original deployment facts");
  if (t.subjectKind === 10n) {
    if (a.artistId !== Z && (a.fact.owner !== o.owners[2] || a.fact.ownerCodeHash !== o.ownerCodeHashes[2]) || t.subjectId !== q.artistId || t.subjectStateHash === Z
      || !personhood(t.schemaId) && t.schemaId !== ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CREDENTIAL_SCHEMA) throw Error("Invalid original identity subject");
    if (t.schemaId === ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CREDENTIAL_SCHEMA) decodeArtistRecoveredMultipleGenerationHydrationCredentialPayload(r.statement, q.artistId, t.subjectStateHash);
  }
  const publicationType = childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PUBLICATION_ROW_TUPLE, "publication");
  if (!publication) {
    if (!same(publicationType, row.publication, zeroValue(schemaType(publicationType)))) throw Error("Unexpected original publication carrier");
    return;
  }
  if ((r.statement.length - 2) / 2 !== 416 || t.schemaId !== id("6529STREAM_ARTIST_RECORD_PUBLICATION_V1")) throw Error("Invalid original publication statement");
  const decoded = coder.decode(["uint16", ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_RECORD_PUBLICATION_TUPLE], r.statement);
  if (decoded[0] !== 1n || coder.encode(["uint16", ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_RECORD_PUBLICATION_TUPLE], decoded) !== r.statement) throw Error("Noncanonical original publication");
  const p = plain(schemaType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_RECORD_PUBLICATION_TUPLE), decoded[1]) as ArtistRecoveredMultipleGenerationHydrationRecordPublication;
  let kind = 0n, capability = 0n;
  if (p.recordType === id("ARTIST_INTENT") && p.schemaId === id("STREAM_ARTIST_INTENT_V1") || p.recordType === id("ARTIST_INTENT_WAIVER") && p.schemaId === id("STREAM_ARTIST_INTENT_WAIVER_V1")) { kind = 7n; capability = 64n; }
  else if (p.recordType === id("ARTIST_SEMANTIC_ASSERTION") && p.schemaId === id("STREAM_SEMANTIC_ASSERTION_V1") || p.recordType === id("WORK_DESCRIPTION") && p.schemaId === id("STREAM_WORK_DESCRIPTION_V1")
    || p.recordType === id("ARTIST_STATEMENT") && p.schemaId !== Z && p.schemaId !== id("STREAM_ARTIST_INTENT_V1") && p.schemaId !== id("STREAM_ARTIST_INTENT_WAIVER_V1")) { kind = 8n; capability = 1n; }
  if (!kind || kind !== t.subjectKind || p.metadataHost === ZeroAddress || p.recorder === ZeroAddress || p.collectionId !== q.collectionId || p.subjectId === Z || p.subjectId !== t.subjectId
    || p.schemaId === Z || p.canonicalizationId === Z || p.payloadAlgorithm !== 1n || p.payloadHash === Z || p.candidateRecordHash === Z
    || p.uriHash !== keccak256(toUtf8Bytes(t.statementURI)) || t.subjectStateHash !== (kind === 7n ? p.candidateRecordHash : Z)) throw Error("Invalid original publication family");
  const stored = row.publication, e = stored.evidence;
  if (stored.metadataHostCodeHash === Z || !same(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_RECORD_PUBLICATION_TUPLE, stored.publication, p)
    || e.attestationRecordHash !== saved.recordHash || e.artistId !== q.artistId || e.bindingHash !== q.bindingHash || e.bindingGeneration !== generation
    || e.signer !== saved.signer || e.signer !== p.recorder || e.authorityClass !== r.authorityClass || e.requiredCapability !== capability || e.signedAt !== saved.signedAt
    || e.publicationHash !== hash([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_RECORD_PUBLICATION_TUPLE], [p])
    || a.artistId !== Z && (a.fact.owner !== p.metadataHost || a.fact.ownerCodeHash !== stored.metadataHostCodeHash)) throw Error("Original publication evidence mismatch");
}
function validatePersonhood(q: ArtistHydrationQuery, o: shared.ArtistRecoveredHydrationOriginEnvironment, r: ArtistRecoveredMultipleGenerationHydrationAttestationRow,
  row: ArtistRecoveredMultipleGenerationHydrationPersonhoodRow, generation: bigint): void {
  if (row.recordHash !== r.record.recordHash || row.originalRegistry !== o.registry) throw Error("Original personhood record/Registry mismatch");
  const ref = r.input.terms.schemaId === ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_EVIDENCE_SCHEMA ? artistRecoveredMultipleGenerationHydrationPersonhoodReference(r.statement) : null;
  if (!ref) {
    if (row.summaryHash !== Z || !same(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_SUMMARY_TUPLE, row.summary, zeroValue(schemaType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_SUMMARY_TUPLE)))) throw Error("Opaque personhood must retain an empty derived summary");
    return;
  }
  const s = row.summary;
  if (s.version !== 1n || s.chainId !== o.chainId || s.nativeRecordHash !== r.record.recordHash || s.statementHash !== r.record.statementHash || s.artistId !== q.artistId
    || s.bindingHash !== q.bindingHash || s.generation !== generation || s.collectionId !== q.collectionId || s.identityRecordHash !== r.record.subjectStateHash
    || ref.artistRegistry !== o.registry || ref.artistId !== q.artistId || ref.operativeIdentityRecordHash !== r.record.subjectStateHash
    || !same(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_REFERENCE_TUPLE, s.evidenceReference, ref) || s.originalRegistryCodeHash === Z || s.core !== o.core || s.coreCodeHash === Z
    || s.documentaryHash === Z || row.summaryHash === Z || row.summaryHash !== hash(["bytes32", ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PERSONHOOD_SUMMARY_TUPLE], [id("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"), s])) throw Error("Original personhood summary mismatch");
}

/** Complete op24 increments and derived documentary heads from supplied original rows. No current signer/source authority is inferred. */
export function validateArtistRecoveredMultipleGenerationHydrationAttestations(
  identities: readonly ArtistRecoveredMultipleGenerationHydrationIdentity[], collections: readonly ArtistHydrationQuery[],
  values: readonly ArtistRecoveredMultipleGenerationHydrationAttestationBundle[], provenance: shared.ArtistRecoveredHydrationProvenance,
  inventory: ArtistRecoveredMultipleGenerationHydrationInventory, clocks?: ArtistRecoveredMultipleGenerationHydrationClockResult,
): Readonly<{ uses: readonly (readonly bigint[])[]; credentialRecords: readonly ArtistRecoveredMultipleGenerationHydrationCredentialHead[];
  credentialHeads: readonly ArtistRecoveredMultipleGenerationHydrationCredentialHead[]; personhoodHeads: readonly Readonly<{ artistId: Hex; collectionId: bigint; recordHash: Hex }>[]; factsVerified: false }> {
  codec.boundedArray(identities, 128); codec.boundedArray(collections, 128); codec.boundedArray(values, 128, collections.length);
  const p = codec.normalizeArtistRecoveredHydrationProvenance(provenance), op = codec.artistRecoveredHydrationOwnerProvenance(p, 4), ip = codec.artistRecoveredHydrationOwnerProvenance(p, 2);
  inventory = normalizeArtistRecoveredMultipleGenerationHydrationInventory(inventory);
  if (clocks) clocks = normalizeGenerationClockResult(clocks, inventory);
  const artists = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_IDENTITY_TUPLE}[]`, identities), qs = codec.normalizeTuple(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, collections);
  const scope = artistRecoveredMultipleGenerationHydrationProjectQueries({ artists: artists.map(b => ({ artistId: b.artistId, collectionId: 0n, bindingHash: Z, policies: [], records: [] })), collections: qs, rows: [] }, op);
  validateArtistRecoveredMultipleGenerationHydrationState(4, { ...scope, rows: scope.collections.map(() => "0x" as Hex) }, op);
  const all = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_BUNDLE_TUPLE}[]`, values), commitment = codec.artistRecoveredHydrationOwnerProvenanceHash(op, 4);
  if (op.journal.filter(j => j.receipt.operation === 24n).length > 128 || inventory.bindings.length !== qs.length) throw Error("Invalid complete generation attestation journal");
  const counts = all.map(() => 0), summaries = all.map(() => 0);
  let total = 0;
  for (let i = 0; i < all.length; i++) {
    const b = all[i]!, q = scope.collections[i]!;
    if (b.provenance !== commitment || b.artistId !== q.artistId || b.collectionId !== q.collectionId || b.bindingHash !== q.bindingHash || b.item.state !== 2n || b.item.generation !== BigInt(inventory.bindings[i]!.bindings.rows.length)
      || b.records.length > 128 || b.personhood.length > 128 || !same("bytes32[]", q.records, b.records.map(row => row.attestation.record.recordHash))) throw Error("Original attestation partition mismatch");
    total += b.records.length;
  }
  if (total !== op.journal.filter(j => j.receipt.operation === 24n).length) throw Error("Incomplete op24 row partition");
  const uses = artists.map(a => a.delegations.map(() => 0n)), heads = artists.map(() => zeroValue(schemaType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CREDENTIAL_HEAD_TUPLE)) as ArtistRecoveredMultipleGenerationHydrationCredentialHead);
  const records: ArtistRecoveredMultipleGenerationHydrationCredentialHead[] = [], personhoodHeads = scope.collections.map(q => ({ artistId: q.artistId, collectionId: q.collectionId, recordHash: Z }));
  const seen = new Set<Hex>();
  const alias = (surface: string, scope: Hex, commitment: Hex): shared.ArtistRecoveredHydrationPoint => {
    const rows = ip.aliases.filter(a => a.surface === id(surface) && a.scope === scope);
    if (!rows.length) throw Error("Missing original attestation Identity replay alias");
    const point = rows[0]!.admittedAt;
    if (rows.some(a => a.cell.kind !== 1n || a.cell.status !== 2n || a.cell.commitment !== commitment || a.admittedAt.ownerIndex !== 2n
      || a.cell.touchedRevision !== a.admittedAt.ownerRevision || !same(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, point, a.admittedAt))) throw Error("Original attestation Identity alias mismatch");
    return point;
  };
  for (const j of op.journal) {
    if (j.receipt.operation === 44n) continue;
    const k = qs.findIndex(q => q.collectionId === j.receipt.collectionId), a = artists.findIndex(v => v.artistId === j.receipt.artistId);
    if (k < 0 || a < 0 || j.receipt.operation !== 24n || qs[k]!.artistId !== j.receipt.artistId || seen.has(j.receipt.recordHash)) throw Error("Invalid global op24 occurrence");
    seen.add(j.receipt.recordHash);
    const b = all[k]!, row = b.records[counts[k]!]!, era = eraOf(op, j.position.point); counts[k] = counts[k]! + 1;
    if (!row || row.attestation.record.recordHash !== j.receipt.recordHash) throw Error("Original op24 occurrence order mismatch");
    const o = op.origins[era]!, r = row.attestation, t = r.input.terms, artist = artists[a]!, generation = r.record.generation;
    const bs = inventory.bindings[k]!.bindings.rows;
    if (generation < 1n || generation > BigInt(bs.length) || !bs[Number(generation - 1n)]!.item.accepted || bs[Number(generation - 1n)]!.item.generation !== generation || bs[Number(generation - 1n)]!.item.artistId !== j.receipt.artistId) throw Error("Attestation requires its original accepted generation");
    const q = { ...qs[k]!, bindingHash: bs[Number(generation - 1n)]!.item.bindingHash };
    if (clocks) {
      const timeline = clocks.collections[k]!, g = Number(generation - 1n);
      if (!before(op, timeline.attributionCompletions[g]!, j.position.point) || g + 1 < bs.length && !before(op, j.position.point, timeline.attributionProposals[g + 1]!)) throw Error("Original op24 is outside its accepted generation window");
    }
    validateAttestationRow(q, o, row, generation);
    const signatures = artist.signatures.filter(s => s.recordHash === r.record.recordHash);
    if (signatures.length !== 1 || (signatures[0]!.signature.length - 2) / 2 > 4096) throw Error("Original op24 requires exactly one bounded signature");
    const digest = artistRecoveredMultipleGenerationHydrationAttestationDigest(o, r);
    let admitted: shared.ArtistRecoveredHydrationPoint;
    if (r.authorityClass === 2n) {
      admitted = alias("identity_authority.replay.delegated_nonce", hash(["bytes32", "uint256"], [artistRecoveredMultipleGenerationHydrationDelegateLane(q.artistId, r.record.signer), r.input.nonce]), digest);
      const gi = artist.delegations.findIndex(d => d.recordHash === r.association.delegation);
      if (gi < 0) throw Error("Missing original op24 grant");
      const d = artist.delegations[gi]!, g = d.record.grant;
      if (g.artistId !== q.artistId || g.delegate !== r.record.signer || g.collectionId !== 0n && g.collectionId !== q.collectionId
        || !(g.capabilities & (t.subjectKind === 7n ? 64n : 1n)) || !before(ip, d.position.point, admitted)
        || d.record.revoked && !before(ip, admitted, identityOccurrence(ip, q.artistId, 27n, d.record.revocationRecordHash).position.point)
        || artist.delegations.slice(gi + 1).some(next => next.record.grant.delegate === g.delegate && !before(ip, admitted, next.position.point))) throw Error("Original op24 grant scope or chronology mismatch");
      uses[a]![gi] = uses[a]![gi]! + 1n;
    } else {
      admitted = alias("identity_authority.replay.nonce_allocator", hash(["bytes32", "uint256"], [q.artistId, r.input.nonce]), digest);
      const keyed = alias("identity_authority.replay.attestation_key", hash(["bytes32"], [r.record.recordHash]), r.record.recordHash);
      if (!same(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, keyed, admitted)) throw Error("Original op24 attestation key clock mismatch");
    }
    if (admitted.environmentHash !== j.position.point.environmentHash) throw Error("Original op24 Identity/native era mismatch");
    const observed = alias("identity_authority.replay.authorization_consumed_digest", hash(["bytes32", "bytes32"], [q.artistId, digest]), digest);
    if (observed.environmentHash !== admitted.environmentHash || codec.compareArtistRecoveredHydrationPoints(ip, observed, admitted) > 0) throw Error("Original op24 first observed digest clock mismatch");
    if (t.subjectKind === 10n && personhood(t.schemaId)) {
      const summary = b.personhood[summaries[k]!]!; summaries[k] = summaries[k]! + 1;
      if (!summary) throw Error("Missing original personhood summary"); validatePersonhood(q, o, r, summary, generation);
      personhoodHeads[k] = { artistId: q.artistId, collectionId: q.collectionId, recordHash: r.record.recordHash };
    }
    if (t.subjectKind === 10n && t.schemaId === ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CREDENTIAL_SCHEMA) {
      const c = decodeArtistRecoveredMultipleGenerationHydrationCredentialPayload(r.statement, q.artistId, t.subjectStateHash), previous = heads[a]!;
      if (c.previousRecordHash !== previous.recordHash) throw Error("Original global Artist C2PA predecessor mismatch");
      const head = codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CREDENTIAL_HEAD_TUPLE, { revision: previous.revision + 1n, recordHash: r.record.recordHash,
        previousRecordHash: previous.recordHash, artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash, generation,
        identityRecordHash: t.subjectStateHash, statementHash: t.statementHash, sourceRegistry: o.registry }) as ArtistRecoveredMultipleGenerationHydrationCredentialHead;
      heads[a] = head; records.push(head);
    }
  }
  if (all.some((b, i) => counts[i] !== b.records.length || summaries[i] !== b.personhood.length)) throw Error("Trailing original op24 or personhood rows");
  return Object.freeze({ uses: Object.freeze(uses.map(v => Object.freeze(v))), credentialRecords: Object.freeze(records), credentialHeads: Object.freeze(heads), personhoodHeads: Object.freeze(personhoodHeads.map(v => Object.freeze(v))), factsVerified: false });
}

function flatEncode(tuple: string, value: unknown): Hex {
  const v = codec.normalizeTuple(tuple, value) as Record<string, unknown>, components = schemaType(tuple).components!;
  return codec.encodeTupleValues(components.map(c => c.format("full")), components.map(c => v[c.name]));
}
function flatDecode<T>(tuple: string, raw: Hex): T {
  const components = schemaType(tuple).components!, types = components.map(c => c.format("full")), bytes = preflight(types, raw);
  const v = coder.decode(components, bytes);
  if (coder.encode(components, v) !== bytes) throw Error("Noncanonical original flat Archive payload");
  return codec.normalizeTuple(tuple, Object.fromEntries(components.map((c, i) => [c.name, plain(c, v[i])])) as T);
}
export function encodeArtistRecoveredMultipleGenerationHydrationArchiveEnvelope(value: ArtistRecoveredMultipleGenerationHydrationArchiveEnvelope): Hex {
  return codec.boundedBytes(flatEncode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ARCHIVE_ENVELOPE_TUPLE, value), undefined, 24575);
}
export function decodeArtistRecoveredMultipleGenerationHydrationArchiveEnvelope(raw: Hex): ArtistRecoveredMultipleGenerationHydrationArchiveEnvelope {
  return flatDecode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ARCHIVE_ENVELOPE_TUPLE, codec.boundedBytes(raw, undefined, 24575));
}
export function decodeArtistRecoveredMultipleGenerationHydrationProposalPayload(raw: Hex): ArtistRecoveredMultipleGenerationHydrationProposalPayload {
  return flatDecode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PROPOSAL_PAYLOAD_TUPLE, raw);
}
export function decodeArtistRecoveredMultipleGenerationHydrationAcceptancePayload(raw: Hex): Readonly<{
  acceptance: ArtistRecoveredMultipleGenerationHydrationAcceptancePayload; authority: ArtistRecoveredMultipleGenerationHydrationAuthorityFact;
}> {
  const types = ["bytes", ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_AUTHORITY_FACT_TUPLE], input = preflight(types, raw), v = coder.decode(types, input);
  if (coder.encode(types, v) !== input) throw Error("Noncanonical original acceptance authority wrapper");
  const authority = codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_AUTHORITY_FACT_TUPLE, plain(schemaType(types[1]!), v[1])) as ArtistRecoveredMultipleGenerationHydrationAuthorityFact;
  const components = schemaType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACCEPTANCE_PAYLOAD_TUPLE).components!;
  const inner = preflight(components.map(c => c.format("full")), v[0] as Hex), common = coder.decode(components, inner);
  const acceptance = codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACCEPTANCE_PAYLOAD_TUPLE, Object.fromEntries(components.map((c, i) => [c.name, plain(c, common[i])]))) as ArtistRecoveredMultipleGenerationHydrationAcceptancePayload;
  if (coder.encode(components, common) !== inner) {
    const extendedTypes = [...components.map(c => c.format("full")), "uint64", "bytes32"];
    const extended = coder.decode(extendedTypes, preflight(extendedTypes, inner));
    if (coder.encode(extendedTypes, extended) !== inner || extended[4] !== acceptance.binding_.generation || extended[5] !== acceptance.binding_.bindingHash) throw Error("Noncanonical original expected acceptance payload");
  }
  return Object.freeze({ acceptance, authority });
}

function validateClockCutoffs(v: ArtistRecoveredMultipleGenerationHydrationInventory, p: shared.ArtistRecoveredHydrationProvenance): void {
  if (v.catalogues.length !== p.eras.length) throw Error("Archive catalogue era count mismatch");
  for (let i = 0; i < v.catalogues.length; i++) if (!same("uint64[7]", v.catalogues[i]!.lower, p.eras[i]!.lowerRevisions)
    || !same("uint64[7]", v.catalogues[i]!.upper, p.eras[i]!.checkpoints.map(c => c.ownerState.revision))) throw Error("Archive catalogue differs from all seven original cutoffs");
}

// Original ABI178 structural value witnesses; no nominal library call selectors.
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_INVENTORY_TUPLE = "tuple(tuple(bytes32 originHash,bytes32 archiveCodeHash,bytes32 configurationHash,uint256 count,bytes32 rowsHash,uint64[7] lower,uint64[7] upper)[] catalogues,tuple(bytes32 originHash,uint16 operation,tuple(uint256 catalogueIndex,address pointer,bytes32 payloadHash,bytes32 evidenceId) evidence)[] operations,tuple(tuple(bytes32 artistId,uint256 collectionId,bytes32 bindingHash,bytes32 provenanceCommitment,tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) current,tuple(tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) item,tuple(bytes32 collaboratorSetHash,bytes32 capabilityPolicySetHash,uint8 mode,uint32 threshold,uint32 count) terms,tuple(uint8 kind,bytes32 reasonHash,bytes32 recordHash) terminal)[] rows) bindings,tuple(tuple(tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) previous,uint8 cause,bytes32 causeRecord,bytes causeData,bytes32 proposalHash,bytes32 proposedArtistId,uint256 registrationNonce,tuple(bytes32 actionId,address proposer,uint8 actionClass,bytes32 roleMutationHash,uint64 roleRevision,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash) governance,uint64 approvedAt) approval,bytes32 recordHash)[] corrections)[] bindings,tuple(bytes32 bindingHash,uint64 generation,bool accepted,tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) proposal)[][] generations)";
export type ArtistRecoveredMultipleGenerationHydrationInventory = { readonly catalogues: readonly ({ readonly originHash: Hex; readonly archiveCodeHash: Hex; readonly configurationHash: Hex; readonly count: bigint; readonly rowsHash: Hex; readonly lower: readonly [bigint, bigint, bigint, bigint, bigint, bigint, bigint]; readonly upper: readonly [bigint, bigint, bigint, bigint, bigint, bigint, bigint]; })[]; readonly operations: readonly ({ readonly originHash: Hex; readonly operation: bigint; readonly evidence: { readonly catalogueIndex: bigint; readonly pointer: Address; readonly payloadHash: Hex; readonly evidenceId: Hex; }; })[]; readonly bindings: readonly ({ readonly bindings: { readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex; readonly provenanceCommitment: Hex; readonly current: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly rows: readonly ({ readonly item: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly terms: { readonly collaboratorSetHash: Hex; readonly capabilityPolicySetHash: Hex; readonly mode: bigint; readonly threshold: bigint; readonly count: bigint; }; readonly terminal: { readonly kind: bigint; readonly reasonHash: Hex; readonly recordHash: Hex; }; })[]; }; readonly corrections: readonly ({ readonly approval: { readonly previous: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly cause: bigint; readonly causeRecord: Hex; readonly causeData: Hex; readonly proposalHash: Hex; readonly proposedArtistId: Hex; readonly registrationNonce: bigint; readonly governance: { readonly actionId: Hex; readonly proposer: Address; readonly actionClass: bigint; readonly roleMutationHash: Hex; readonly roleRevision: bigint; readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex; }; readonly approvedAt: bigint; }; readonly recordHash: Hex; })[]; })[]; readonly generations: readonly (readonly ({ readonly bindingHash: Hex; readonly generation: bigint; readonly accepted: boolean; readonly proposal: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; })[])[]; };
export function normalizeArtistRecoveredMultipleGenerationHydrationInventory(value: ArtistRecoveredMultipleGenerationHydrationInventory): ArtistRecoveredMultipleGenerationHydrationInventory { return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_INVENTORY_TUPLE, value); }
export function encodeArtistRecoveredMultipleGenerationHydrationInventory(value: ArtistRecoveredMultipleGenerationHydrationInventory): Hex { return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_INVENTORY_TUPLE], [normalizeArtistRecoveredMultipleGenerationHydrationInventory(value)]); }
export function decodeArtistRecoveredMultipleGenerationHydrationInventory(raw: Hex): ArtistRecoveredMultipleGenerationHydrationInventory { return decode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_INVENTORY_TUPLE, raw); }
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_BUNDLE_TUPLE = "tuple(tuple(bytes32 artistId,uint256 collectionId,bytes32 bindingHash,bytes32 provenanceCommitment,tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) current,tuple(tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) item,tuple(bytes32 collaboratorSetHash,bytes32 capabilityPolicySetHash,uint8 mode,uint32 threshold,uint32 count) terms,tuple(uint8 kind,bytes32 reasonHash,bytes32 recordHash) terminal)[] rows) bindings,tuple(tuple(tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) previous,uint8 cause,bytes32 causeRecord,bytes causeData,bytes32 proposalHash,bytes32 proposedArtistId,uint256 registrationNonce,tuple(bytes32 actionId,address proposer,uint8 actionClass,bytes32 roleMutationHash,uint64 roleRevision,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash) governance,uint64 approvedAt) approval,bytes32 recordHash)[] corrections)";
export type ArtistRecoveredMultipleGenerationHydrationBindingBundle = { readonly bindings: { readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex; readonly provenanceCommitment: Hex; readonly current: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly rows: readonly ({ readonly item: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly terms: { readonly collaboratorSetHash: Hex; readonly capabilityPolicySetHash: Hex; readonly mode: bigint; readonly threshold: bigint; readonly count: bigint; }; readonly terminal: { readonly kind: bigint; readonly reasonHash: Hex; readonly recordHash: Hex; }; })[]; }; readonly corrections: readonly ({ readonly approval: { readonly previous: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly cause: bigint; readonly causeRecord: Hex; readonly causeData: Hex; readonly proposalHash: Hex; readonly proposedArtistId: Hex; readonly registrationNonce: bigint; readonly governance: { readonly actionId: Hex; readonly proposer: Address; readonly actionClass: bigint; readonly roleMutationHash: Hex; readonly roleRevision: bigint; readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex; }; readonly approvedAt: bigint; }; readonly recordHash: Hex; })[]; };
export function normalizeArtistRecoveredMultipleGenerationHydrationBindingBundle(value: ArtistRecoveredMultipleGenerationHydrationBindingBundle): ArtistRecoveredMultipleGenerationHydrationBindingBundle { return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_BUNDLE_TUPLE, value); }
export function encodeArtistRecoveredMultipleGenerationHydrationBindingBundle(value: ArtistRecoveredMultipleGenerationHydrationBindingBundle): Hex { return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_BUNDLE_TUPLE], [normalizeArtistRecoveredMultipleGenerationHydrationBindingBundle(value)]); }
export function decodeArtistRecoveredMultipleGenerationHydrationBindingBundle(raw: Hex): ArtistRecoveredMultipleGenerationHydrationBindingBundle { return decode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_BUNDLE_TUPLE, raw); }
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CORRECTION_TUPLE = "tuple(tuple(tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) previous,uint8 cause,bytes32 causeRecord,bytes causeData,bytes32 proposalHash,bytes32 proposedArtistId,uint256 registrationNonce,tuple(bytes32 actionId,address proposer,uint8 actionClass,bytes32 roleMutationHash,uint64 roleRevision,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash) governance,uint64 approvedAt) approval,bytes32 recordHash)";
export type ArtistRecoveredMultipleGenerationHydrationCorrection = { readonly approval: { readonly previous: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly cause: bigint; readonly causeRecord: Hex; readonly causeData: Hex; readonly proposalHash: Hex; readonly proposedArtistId: Hex; readonly registrationNonce: bigint; readonly governance: { readonly actionId: Hex; readonly proposer: Address; readonly actionClass: bigint; readonly roleMutationHash: Hex; readonly roleRevision: bigint; readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex; }; readonly approvedAt: bigint; }; readonly recordHash: Hex; };
export function normalizeArtistRecoveredMultipleGenerationHydrationCorrection(value: ArtistRecoveredMultipleGenerationHydrationCorrection): ArtistRecoveredMultipleGenerationHydrationCorrection { return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CORRECTION_TUPLE, value); }
export function encodeArtistRecoveredMultipleGenerationHydrationCorrection(value: ArtistRecoveredMultipleGenerationHydrationCorrection): Hex { return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CORRECTION_TUPLE], [normalizeArtistRecoveredMultipleGenerationHydrationCorrection(value)]); }
export function decodeArtistRecoveredMultipleGenerationHydrationCorrection(raw: Hex): ArtistRecoveredMultipleGenerationHydrationCorrection { return decode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CORRECTION_TUPLE, raw); }
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_GENERATION_TUPLE = "tuple(bytes32 bindingHash,uint64 generation,bool accepted,tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) proposal)";
export type ArtistRecoveredMultipleGenerationHydrationGeneration = { readonly bindingHash: Hex; readonly generation: bigint; readonly accepted: boolean; readonly proposal: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; };
export function normalizeArtistRecoveredMultipleGenerationHydrationGeneration(value: ArtistRecoveredMultipleGenerationHydrationGeneration): ArtistRecoveredMultipleGenerationHydrationGeneration { return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_GENERATION_TUPLE, value); }
export function encodeArtistRecoveredMultipleGenerationHydrationGeneration(value: ArtistRecoveredMultipleGenerationHydrationGeneration): Hex { return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_GENERATION_TUPLE], [normalizeArtistRecoveredMultipleGenerationHydrationGeneration(value)]); }
export function decodeArtistRecoveredMultipleGenerationHydrationGeneration(raw: Hex): ArtistRecoveredMultipleGenerationHydrationGeneration { return decode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_GENERATION_TUPLE, raw); }
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACCEPTANCE_BUNDLE_TUPLE = "tuple(bytes32 provenance,bytes32 artistId,uint256 collectionId,bytes32 bindingHash,tuple(bytes32 bindingHash,uint64 generation,bytes32 recordHash,uint64 acceptedAt)[] rows)";
export type ArtistRecoveredMultipleGenerationHydrationAcceptanceBundle = { readonly provenance: Hex; readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex; readonly rows: readonly ({ readonly bindingHash: Hex; readonly generation: bigint; readonly recordHash: Hex; readonly acceptedAt: bigint; })[]; };
export function normalizeArtistRecoveredMultipleGenerationHydrationAcceptanceBundle(value: ArtistRecoveredMultipleGenerationHydrationAcceptanceBundle): ArtistRecoveredMultipleGenerationHydrationAcceptanceBundle { return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACCEPTANCE_BUNDLE_TUPLE, value); }
export function encodeArtistRecoveredMultipleGenerationHydrationAcceptanceBundle(value: ArtistRecoveredMultipleGenerationHydrationAcceptanceBundle): Hex { return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACCEPTANCE_BUNDLE_TUPLE], [normalizeArtistRecoveredMultipleGenerationHydrationAcceptanceBundle(value)]); }
export function decodeArtistRecoveredMultipleGenerationHydrationAcceptanceBundle(raw: Hex): ArtistRecoveredMultipleGenerationHydrationAcceptanceBundle { return decode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACCEPTANCE_BUNDLE_TUPLE, raw); }
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_HISTORY_TUPLE = "tuple(bytes32 provenance,bytes32 artistId,uint256 collectionId,bytes32 bindingHash,tuple(uint8 state,uint64 generation) current,tuple(bytes32 bindingHash,uint64 generation,bool accepted,tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) proposal)[] generations,tuple(tuple(bytes32 disputeRecordHash,bytes32 counterStatementRecordHash,bytes32 resolutionActionId,uint8 restoreState,uint8 revocationReason,bool open,bool reopened) head,tuple(bytes32 recordHash,tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 recordedAt,bytes32 artistId,bytes32 bindingHash,bytes32 disputeRecordHash,bytes32 previousRecordHash,tuple(bytes32 artistId,uint64 bindingGeneration,uint32 collaboratorIndex,bytes32 delegation) standing,bytes32 governanceActionId) opening,tuple(tuple(uint256 collectionId,uint64 bindingGeneration,bytes32 disputeRecordHash,uint8 resolution,bytes32 evidenceHash,bytes32 reasonHash,bytes32 counterStatementRecordHash) terms,bytes32 actionId,address actor,address proposer,uint8 actionClass,uint8 restoredState,uint64 resolvedAt,bytes32 previousResolutionActionId,bytes32 witnessHash) resolution)[] revocations)";
export type ArtistRecoveredMultipleGenerationHydrationAttributionHistory = { readonly provenance: Hex; readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex; readonly current: { readonly state: bigint; readonly generation: bigint; }; readonly generations: readonly ({ readonly bindingHash: Hex; readonly generation: bigint; readonly accepted: boolean; readonly proposal: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; })[]; readonly revocations: readonly ({ readonly head: { readonly disputeRecordHash: Hex; readonly counterStatementRecordHash: Hex; readonly resolutionActionId: Hex; readonly restoreState: bigint; readonly revocationReason: bigint; readonly open: boolean; readonly reopened: boolean; }; readonly opening: { readonly recordHash: Hex; readonly terms: { readonly collectionId: bigint; readonly bindingGeneration: bigint; readonly disputeAction: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly recordedAt: bigint; readonly artistId: Hex; readonly bindingHash: Hex; readonly disputeRecordHash: Hex; readonly previousRecordHash: Hex; readonly standing: { readonly artistId: Hex; readonly bindingGeneration: bigint; readonly collaboratorIndex: bigint; readonly delegation: Hex; }; readonly governanceActionId: Hex; }; readonly resolution: { readonly terms: { readonly collectionId: bigint; readonly bindingGeneration: bigint; readonly disputeRecordHash: Hex; readonly resolution: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly counterStatementRecordHash: Hex; }; readonly actionId: Hex; readonly actor: Address; readonly proposer: Address; readonly actionClass: bigint; readonly restoredState: bigint; readonly resolvedAt: bigint; readonly previousResolutionActionId: Hex; readonly witnessHash: Hex; }; })[]; };
export function normalizeArtistRecoveredMultipleGenerationHydrationAttributionHistory(value: ArtistRecoveredMultipleGenerationHydrationAttributionHistory): ArtistRecoveredMultipleGenerationHydrationAttributionHistory { return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_HISTORY_TUPLE, value); }
export function encodeArtistRecoveredMultipleGenerationHydrationAttributionHistory(value: ArtistRecoveredMultipleGenerationHydrationAttributionHistory): Hex { return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_HISTORY_TUPLE], [normalizeArtistRecoveredMultipleGenerationHydrationAttributionHistory(value)]); }
export function decodeArtistRecoveredMultipleGenerationHydrationAttributionHistory(raw: Hex): ArtistRecoveredMultipleGenerationHydrationAttributionHistory { return decode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_HISTORY_TUPLE, raw); }
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_TUPLE = `tuple(${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_HISTORY_TUPLE} history,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTESTATION_BUNDLE_TUPLE} records)`;
export type ArtistRecoveredMultipleGenerationHydrationAttribution = Readonly<{ history: ArtistRecoveredMultipleGenerationHydrationAttributionHistory; records: ArtistRecoveredMultipleGenerationHydrationAttestationBundle }>;
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONSENTS_TUPLE = `tuple(${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONTENT_BUNDLE_TUPLE} rows,${childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_TUPLE, "item")}[] bindings)`;
export type ArtistRecoveredMultipleGenerationHydrationConsents = Readonly<{ rows: ArtistRecoveredMultipleGenerationHydrationContentBundle; bindings: readonly ArtistRecoveredMultipleGenerationHydrationBinding["item"][] }>;
export function normalizeArtistRecoveredMultipleGenerationHydrationAttribution(value: ArtistRecoveredMultipleGenerationHydrationAttribution): ArtistRecoveredMultipleGenerationHydrationAttribution { return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_TUPLE, value); }
export function encodeArtistRecoveredMultipleGenerationHydrationAttribution(value: ArtistRecoveredMultipleGenerationHydrationAttribution): Hex { return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_TUPLE], [normalizeArtistRecoveredMultipleGenerationHydrationAttribution(value)]); }
export function decodeArtistRecoveredMultipleGenerationHydrationAttribution(raw: Hex): ArtistRecoveredMultipleGenerationHydrationAttribution { return decode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_TUPLE, raw); }
export function normalizeArtistRecoveredMultipleGenerationHydrationConsents(value: ArtistRecoveredMultipleGenerationHydrationConsents): ArtistRecoveredMultipleGenerationHydrationConsents { return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONSENTS_TUPLE, value); }
export function encodeArtistRecoveredMultipleGenerationHydrationConsents(value: ArtistRecoveredMultipleGenerationHydrationConsents): Hex { return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONSENTS_TUPLE], [normalizeArtistRecoveredMultipleGenerationHydrationConsents(value)]); }
export function decodeArtistRecoveredMultipleGenerationHydrationConsents(raw: Hex): ArtistRecoveredMultipleGenerationHydrationConsents { return decode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CONSENTS_TUPLE, raw); }
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CORRECTION_PAYLOAD_TUPLE = "tuple(bytes32 tag,uint16 version,uint256 id,tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,string identityRecordURI,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,uint8 collabPolicyMode,uint32 collabThreshold,tuple(address account,bytes32 role,bytes32 shareLabelId)[] collaborators,tuple(uint32 capabilityMask,uint8 mode,uint32 threshold)[] capabilityPolicyOverrides,bytes32 reasonHash,string reasonURI) proposal,bytes document,string displayName,bool reused,bytes32 roleHash,uint64 roleRevision,bytes32 repudiation,tuple(bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash) context,tuple(tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) previous,uint8 cause,bytes32 causeRecord,bytes causeData,bytes32 proposalHash,bytes32 proposedArtistId,uint256 registrationNonce,tuple(bytes32 actionId,address proposer,uint8 actionClass,bytes32 roleMutationHash,uint64 roleRevision,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash) governance,uint64 approvedAt) approval)";
export type ArtistRecoveredMultipleGenerationHydrationCorrectionPayload = { readonly tag: Hex; readonly version: bigint; readonly id: bigint; readonly proposal: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly identityRecordURI: string; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly collabPolicyMode: bigint; readonly collabThreshold: bigint; readonly collaborators: readonly ({ readonly account: Address; readonly role: Hex; readonly shareLabelId: Hex; })[]; readonly capabilityPolicyOverrides: readonly ({ readonly capabilityMask: bigint; readonly mode: bigint; readonly threshold: bigint; })[]; readonly reasonHash: Hex; readonly reasonURI: string; }; readonly document: Hex; readonly displayName: string; readonly reused: boolean; readonly roleHash: Hex; readonly roleRevision: bigint; readonly repudiation: Hex; readonly context: { readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex; }; readonly approval: { readonly previous: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly cause: bigint; readonly causeRecord: Hex; readonly causeData: Hex; readonly proposalHash: Hex; readonly proposedArtistId: Hex; readonly registrationNonce: bigint; readonly governance: { readonly actionId: Hex; readonly proposer: Address; readonly actionClass: bigint; readonly roleMutationHash: Hex; readonly roleRevision: bigint; readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex; }; readonly approvedAt: bigint; }; };
export function decodeArtistRecoveredMultipleGenerationHydrationCorrectionPayload(raw: Hex): ArtistRecoveredMultipleGenerationHydrationCorrectionPayload { return flatDecode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CORRECTION_PAYLOAD_TUPLE, raw); }
export function encodeArtistRecoveredMultipleGenerationHydrationCorrectionPayload(value: ArtistRecoveredMultipleGenerationHydrationCorrectionPayload): Hex { return flatEncode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CORRECTION_PAYLOAD_TUPLE, value); }
export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_REFUSAL_PAYLOAD_TUPLE = "tuple(tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) binding_,tuple(uint256 collectionId,uint64 generation,bytes32 bindingHash,bytes32 reasonHash,string reasonURI) terms,tuple(uint256 nonce,uint64 time,bytes signature) authorization,tuple(address signer,bytes32 digest,bool direct) proof,tuple(bytes32 artistId,address authorityAddress,uint8 authorityClass,uint8 status) authority)";
export type ArtistRecoveredMultipleGenerationHydrationRefusalPayload = { readonly binding_: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly terms: { readonly collectionId: bigint; readonly generation: bigint; readonly bindingHash: Hex; readonly reasonHash: Hex; readonly reasonURI: string; }; readonly authorization: { readonly nonce: bigint; readonly time: bigint; readonly signature: Hex; }; readonly proof: { readonly signer: Address; readonly digest: Hex; readonly direct: boolean; }; readonly authority: { readonly artistId: Hex; readonly authorityAddress: Address; readonly authorityClass: bigint; readonly status: bigint; }; };
export function decodeArtistRecoveredMultipleGenerationHydrationRefusalPayload(raw: Hex): ArtistRecoveredMultipleGenerationHydrationRefusalPayload { return flatDecode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_REFUSAL_PAYLOAD_TUPLE, raw); }
export function encodeArtistRecoveredMultipleGenerationHydrationRefusalPayload(value: ArtistRecoveredMultipleGenerationHydrationRefusalPayload): Hex { return flatEncode(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_REFUSAL_PAYLOAD_TUPLE, value); }

export function encodeArtistRecoveredMultipleGenerationHydrationAuxiliaryState(
  value: ArtistRecoveredMultipleGenerationHydrationState, index: ArtistHydrationOwnerIndex,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance, auxiliary: Hex,
): Hex {
  const state = validateArtistRecoveredMultipleGenerationHydrationState(index, value, provenance);
  const raw = codec.encodeTupleValues(["bytes32", "uint16", "uint8", ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_STATE_TUPLE, "bytes"],
    [ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_SCHEMA, 1n, BigInt(index), state, auxiliary]);
  decodeArtistRecoveredMultipleGenerationHydrationAuxiliary(raw, index, provenance);
  return raw;
}

/** Complete supplied catalogue metadata and selected operation identities. Bytes/read provenance are separate facts. */
export function validateArtistRecoveredMultipleGenerationHydrationInventory(
  scope: ArtistRecoveredMultipleGenerationHydrationState, provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
  inventory: ArtistRecoveredMultipleGenerationHydrationInventory,
): ArtistRecoveredMultipleGenerationHydrationInventory {
  const s = normalizeArtistRecoveredMultipleGenerationHydrationState(scope), raw = codec.normalizeTuple(shared.ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE, provenance);
  if (!raw.eras.length) throw Error("Missing original generation provenance");
  const p = codec.normalizeArtistRecoveredHydrationOwnerProvenance(raw, raw.eras[0]!.checkpoint.ownerState.domainId === codec.artistRecoveredHydrationOwnerDomain(0) ? 0 : 4);
  const v = normalizeArtistRecoveredMultipleGenerationHydrationInventory(inventory);
  if (v.catalogues.length !== p.eras.length || v.bindings.length !== s.collections.length || v.generations.length !== s.collections.length) throw Error("Incomplete generation inventory partitions");
  const owner = p.eras[0]!.checkpoint.ownerState.domainId === codec.artistRecoveredHydrationOwnerDomain(0) ? 0 : 4;
  let total = 0n, generations = 0;
  for (let i = 0; i < v.catalogues.length; i++) {
    const c = v.catalogues[i]!, e = p.eras[i]!; total += c.count;
    if (c.originHash !== e.originHash || c.archiveCodeHash === Z || c.configurationHash === Z || c.count > 16384n
      || c.lower[owner] !== e.lowerRevision || c.upper[owner] !== e.checkpoint.ownerState.revision || c.lower.some((n, j) => n > c.upper[j]!)) throw Error("Original Archive catalogue cutoff mismatch");
  }
  if (total > 16384n) throw Error("Complete original Archive catalogue capacity");
  for (let k = 0; k < v.bindings.length; k++) {
    const b = v.bindings[k]!, q = s.collections[k]!, n = b.bindings.rows.length;
    if (!n || n > 128 || b.corrections.length !== n || v.generations[k]!.length !== n || b.bindings.artistId !== q.artistId || b.bindings.collectionId !== q.collectionId
      || b.bindings.bindingHash !== q.bindingHash || !b.bindings.current.accepted || b.bindings.current.bindingHash !== q.bindingHash
      || !same(bindingItemType(), b.bindings.current, b.bindings.rows[n - 1]!.item)) throw Error("Incomplete generation binding rows");
    generations += n;
  }
  if (generations <= s.collections.length || v.operations.length !== 2 * generations) throw Error("MULTIPLE_GENERATIONS needs complete generation2+ proposal/completion inventory");
  let previousEra = -1, previousIndex = -1n; const evidence = new Set<Hex>();
  for (const row of v.operations) {
    const era = p.eras.findIndex(e => e.originHash === row.originHash), e = row.evidence;
    if (era < 0 || ![1n, 2n, 3n, 4n].includes(row.operation) || era < previousEra || era === previousEra && e.catalogueIndex <= previousIndex
      || e.catalogueIndex >= v.catalogues[era]!.count || e.pointer === ZeroAddress || e.payloadHash === Z || e.evidenceId === Z || evidence.has(e.evidenceId)) throw Error("Invalid selected original Archive operation");
    evidence.add(e.evidenceId); previousEra = era; previousIndex = e.catalogueIndex;
  }
  return v;
}
function bindingItemType(): string { return childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_TUPLE, "item"); }
function terminalType(): string { return childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_TUPLE, "terminal"); }
function empty(type: string, value: unknown): boolean { return same(type, value, zeroValue(schemaType(type))); }
function generationRow(value: ArtistRecoveredMultipleGenerationHydrationBindingBundle["bindings"]["rows"][number], query: ArtistHydrationQuery,
  generation: bigint, origin: shared.ArtistRecoveredHydrationOriginEnvironment): void {
  const b = value.item, t = value.terms;
  if (b.artistId !== query.artistId || b.artistAddress === ZeroAddress || b.identityRecordHash === Z || b.proposer === ZeroAddress || b.generation !== generation
    || ![1n, 2n].includes(b.consentMode) || b.saleConsentScope > 1n || b.registryImmutabilityElection > 1n || t.count || t.mode || t.threshold
    || t.collaboratorSetHash !== hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), []])
    || t.capabilityPolicySetHash !== hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []])
    || artistRecoveredMultipleGenerationHydrationBindingHash(origin, query.collectionId, b) !== b.bindingHash) throw Error("Invalid original generation binding preimage");
}
export function artistRecoveredMultipleGenerationHydrationCorrectionHash(origin: shared.ArtistRecoveredHydrationOriginEnvironment, collectionId: bigint, bindingHash: Hex,
  approval: ArtistRecoveredMultipleGenerationHydrationCorrection["approval"]): Hex {
  const o = codec.normalizeArtistRecoveredHydrationOriginEnvironment(origin), type = childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CORRECTION_TUPLE, "approval");
  return hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", type], [id("6529STREAM_ARTIST_BINDING_CORRECTION_RECORD_V1"), o.chainId, o.registry, o.core, o.manager, collectionId, bindingHash, codec.normalizeTuple(type, approval)]);
}
function correctionRow(bundle: ArtistRecoveredMultipleGenerationHydrationBindingBundle, q: ArtistHydrationQuery, at: number, origin: shared.ArtistRecoveredHydrationOriginEnvironment): void {
  const row = bundle.corrections[at]!, a = row.approval, previous = at ? bundle.bindings.rows[at - 1]! : undefined;
  if (row.recordHash === Z) {
    if (!empty(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CORRECTION_TUPLE, row) || previous?.item.accepted) throw Error("Missing or dirty original correction approval");
    return;
  }
  if (!previous || !same(bindingItemType(), a.previous, previous.item) || a.proposalHash === Z || a.proposedArtistId !== q.artistId || a.registrationNonce
    || !a.approvedAt || a.governance.actionId === Z || a.governance.proposer === ZeroAddress || a.governance.actionClass !== 2n) throw Error("Invalid original correction identity");
  const revocationType = childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_HISTORY_TUPLE, "revocations");
  const rt = schemaType(revocationType).arrayChildren!.components!;
  if (previous.item.accepted) {
    const types = [terminalType(), ...rt.map(t => t.format("full"))], raw = preflight(types, a.causeData), d = coder.decode(types, raw);
    if (coder.encode(types, d) !== raw || a.cause !== 4n || !same(terminalType(), plain(schemaType(types[0]!), d[0]), previous.terminal)) throw Error("Invalid accepted-generation correction cause");
    const r = codec.normalizeTuple(revocationType.slice(0, -2), { head: plain(rt[0]!, d[1]), opening: plain(rt[1]!, d[2]), resolution: plain(rt[2]!, d[3]) }) as ArtistRecoveredMultipleGenerationHydrationAttributionHistory["revocations"][number];
    revocationLeaf(r, { bindingHash: previous.item.bindingHash, generation: previous.item.generation, accepted: true, proposal: { environmentHash: Z, ownerIndex: 0n, ownerRevision: 0n } }, q, origin);
    if (a.causeRecord !== r.resolution.actionId) throw Error("Correction cause differs from original resolution");
  } else {
    if (a.cause !== previous.terminal.kind || a.causeRecord !== (a.cause === 1n ? previous.terminal.recordHash : previous.item.bindingHash)
      || a.causeData !== codec.encodeTupleValues([terminalType(), rt[0]!.format("full")], [previous.terminal, zeroValue(rt[0]!)])) throw Error("Pending-generation correction cause mismatch");
  }
  const scope = hash(["bytes32", "uint256", "address", "address", "address", "uint256", "uint64"], [id("6529STREAM_ARTIST_BINDING_CORRECTION_SCOPE_V1"), origin.chainId, origin.registry, origin.core, origin.manager, q.collectionId, previous.item.generation]);
  const old = hash([bindingItemType(), "uint8", "uint8", "bytes32", "bytes"], [a.previous, 5n, a.cause, a.causeRecord, a.causeData]);
  const next = hash(["bytes32", "bytes32", "bytes32", "bytes32", "uint256"], [scope, old, a.proposalHash, a.proposedArtistId, a.registrationNonce]);
  if (a.governance.scopeHash !== scope || a.governance.oldValueHash !== old || a.governance.newValueHash !== next
    || row.recordHash !== artistRecoveredMultipleGenerationHydrationCorrectionHash(origin, q.collectionId, bundle.bindings.rows[at]!.item.bindingHash, a)
    || bundle.corrections.slice(0, at).some(r => r.recordHash === row.recordHash || r.approval.governance.actionId === a.governance.actionId)) throw Error("Original correction governance/hash mismatch");
}
function markGenerationAliases(p: shared.ArtistRecoveredHydrationOwnerProvenance, used: Set<number>, surface: string, scope: Hex, commitment: Hex, point: shared.ArtistRecoveredHydrationPoint): void {
  const start = eraOf(p, point);
  for (let e = start; e < p.eras.length; e++) {
    const found = p.aliases.map((a, i) => ({ a, i })).filter(({ a }) => a.originHash === p.eras[e]!.originHash && a.surface === id(surface) && a.scope === scope);
    if (found.length !== 1) throw Error("Incomplete generation replay alias history");
    const { a, i } = found[0]!;
    if (used.has(i) || a.cell.kind !== 1n || a.cell.status !== 2n || a.cell.commitment !== commitment || !same(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, a.admittedAt, point)) throw Error("Generation replay alias identity mismatch");
    used.add(i);
  }
}
function resolvedPoint(p: shared.ArtistRecoveredHydrationOwnerProvenance, surface: string, scope: Hex, commitment: Hex): shared.ArtistRecoveredHydrationPoint {
  const found = p.aliases.filter(a => a.surface === id(surface) && a.scope === scope && a.cell.commitment === commitment);
  if (!found.length || found.some(a => !same(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, a.admittedAt, found[0]!.admittedAt))) throw Error("Missing or conflicting original resolution coordinate");
  codec.compareArtistRecoveredHydrationPoints(p, found[0]!.admittedAt, found[0]!.admittedAt);
  return found[0]!.admittedAt;
}
function revocationLeaf(r: ArtistRecoveredMultipleGenerationHydrationAttributionHistory["revocations"][number], generation: ArtistRecoveredMultipleGenerationHydrationGeneration,
  q: ArtistHydrationQuery, o: shared.ArtistRecoveredHydrationOriginEnvironment): void {
  const a = r.opening, d = r.resolution, h = r.head;
  const openingType = childType(schemaType(childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_HISTORY_TUPLE, "revocations")).arrayChildren!.format("full"), "opening");
  const expected = hash(["bytes32", "uint256", "address", "uint256", "uint64", "uint8", "address", "uint8", "bytes32", "bytes32", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_DISPUTE_RECORD_V1"), o.chainId, o.registry, a.terms.collectionId, a.terms.bindingGeneration, a.terms.disputeAction, a.signer, 0n, a.terms.evidenceHash, a.terms.reasonHash, 0n, a.recordedAt]);
  if (a.recordHash === Z || a.recordHash !== expected || a.terms.collectionId !== q.collectionId || a.terms.bindingGeneration !== generation.generation || a.terms.disputeAction !== 1n
    || a.terms.evidenceHash === Z || a.terms.reasonHash === Z || a.signer === ZeroAddress || a.authorityClass || a.nonce || !a.recordedAt || a.artistId !== q.artistId || a.bindingHash !== generation.bindingHash
    || a.disputeRecordHash !== a.recordHash || a.previousRecordHash !== Z || !empty(childType(openingType, "standing"), a.standing) || a.governanceActionId === Z) throw Error("Invalid governed44 opening preimage");
  if (h.disputeRecordHash !== a.recordHash || h.counterStatementRecordHash !== Z || h.resolutionActionId !== d.actionId || h.restoreState !== 2n || h.revocationReason !== 4n || h.open || h.reopened
    || d.actionId === Z || d.actionId === a.governanceActionId || d.actor === ZeroAddress || d.proposer === ZeroAddress || d.actionClass !== 2n || d.restoredState !== 5n || d.resolvedAt < a.recordedAt
    || d.previousResolutionActionId !== Z || d.witnessHash === Z || d.terms.collectionId !== q.collectionId || d.terms.bindingGeneration !== generation.generation || d.terms.disputeRecordHash !== a.recordHash
    || d.terms.resolution !== 2n || d.terms.evidenceHash === Z || d.terms.reasonHash === Z || d.terms.counterStatementRecordHash !== Z) throw Error("Invalid original class2 revoke46 history");
}

function validateGenerationBindings(s: ArtistRecoveredMultipleGenerationHydrationState, full: shared.ArtistRecoveredHydrationProvenance, inventory: ArtistRecoveredMultipleGenerationHydrationInventory,
  accepted: readonly ArtistRecoveredMultipleGenerationHydrationAcceptanceBundle[], attributed: readonly ArtistRecoveredMultipleGenerationHydrationAttribution[]): void {
  const bp = codec.artistRecoveredHydrationOwnerProvenance(full, 0), ap = codec.artistRecoveredHydrationOwnerProvenance(full, 3), op = codec.artistRecoveredHydrationOwnerProvenance(full, 4);
  const used0 = new Set<number>(), used3 = new Set<number>(), used4 = new Set<number>();
  const counts0 = bp.eras.map(() => 0n), native0 = bp.eras.map(() => 0n), guards0 = bp.eras.map(() => 0n), revokes = op.eras.map(() => 0n), seenResolutions = new Set<string>();
  let acceptanceCount = 0, openingCount = 0;
  for (let k = 0; k < s.collections.length; k++) {
    const q = s.collections[k]!, b = inventory.bindings[k]!, generations = inventory.generations[k]!, a = accepted[k]!, history = attributed[k]!.history;
    if (b.bindings.provenanceCommitment !== codec.artistRecoveredHydrationOwnerProvenanceHash(bp, 0) || a.provenance !== codec.artistRecoveredHydrationOwnerProvenanceHash(ap, 3)
      || a.artistId !== q.artistId || a.collectionId !== q.collectionId || a.bindingHash !== q.bindingHash || !a.rows.length || a.rows.length > 128
      || a.rows.at(-1)!.bindingHash !== q.bindingHash || history.provenance !== codec.artistRecoveredHydrationOwnerProvenanceHash(op, 4)
      || history.artistId !== q.artistId || history.collectionId !== q.collectionId || history.bindingHash !== q.bindingHash || history.current.state !== 2n || history.current.generation !== BigInt(generations.length)
      || !same(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_GENERATION_TUPLE}[]`, history.generations, generations)) throw Error("Generation owner partition mismatch");
    let acceptedCursor = 0, revokeCursor = 0;
    for (let g = 0; g < generations.length; g++) {
      const generation = generations[g]!, row = b.bindings.rows[g]!, point = generation.proposal, e = eraOf(bp, point), origin = bp.origins[e]!;
      if (generation.generation !== BigInt(g + 1) || generation.bindingHash !== row.item.bindingHash || generation.accepted !== row.item.accepted || point.ownerIndex !== 0n
        || g && !before(bp, generations[g - 1]!.proposal, point)) throw Error("Invalid original generation proposal chronology");
      const native = occurrence(bp, q, 1n, generation.bindingHash);
      if (!same(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, native.position.point, point)) throw Error("Proposal differs from native original owner0 coordinate");
      generationRow(row, q, BigInt(g + 1), origin); correctionRow(b, q, g, origin);
      const logical = hash(["uint256", "uint64"], [q.collectionId, generation.generation]);
      markGenerationAliases(bp, used0, "binding_lifecycle.replay.proposal_key", logical, generation.bindingHash, point);
      guards0[e] = guards0[e]! + 1n; native0[e] = native0[e]! + 1n; counts0[e] = counts0[e]! + 2n;
      if (b.corrections[g]!.recordHash !== Z) { markGenerationAliases(bp, used0, "binding_lifecycle.replay.correction_action", b.corrections[g]!.approval.governance.actionId, b.corrections[g]!.recordHash, point); guards0[e] = guards0[e]! + 1n; }
      if (generation.accepted) {
        if (!empty(terminalType(), row.terminal)) throw Error("Accepted generation has a terminal refusal/withdrawal");
        const r = a.rows[acceptedCursor++];
        if (!r || r.bindingHash !== generation.bindingHash || r.generation !== generation.generation || r.recordHash === Z || !r.acceptedAt) throw Error("Incomplete generation acceptance history");
        const n = occurrence(ap, q, 2n, r.recordHash);
        if (n.position.point.environmentHash !== point.environmentHash) throw Error("Acceptance and proposal origins differ");
        const scopeAliases = ap.aliases.filter(v => v.surface === id("acceptance_lifecycle.replay.record_uniqueness") && v.cell.commitment === r.recordHash);
        if (!scopeAliases.length || scopeAliases[0]!.scope === Z || scopeAliases.some(v => v.scope !== scopeAliases[0]!.scope)) throw Error("Invalid acceptance replay scope");
        markGenerationAliases(ap, used3, "acceptance_lifecycle.replay.record_uniqueness", scopeAliases[0]!.scope, r.recordHash, n.position.point); acceptanceCount++;
        if (g + 1 < generations.length) {
          const r = history.revocations[revokeCursor++]; if (!r) throw Error("Missing accepted-generation revocation");
          const opening = occurrence(op, q, 44n, r.opening.recordHash), opened = opening.position.point, resolved = resolvedPoint(op, "attribution_lifecycle.replay.dispute_resolution_key", r.opening.recordHash, r.resolution.actionId);
          revocationLeaf(r, generation, q, op.origins[eraOf(op, opened)]!);
          const key = `${resolved.environmentHash}:${resolved.ownerRevision}`;
          if (resolved.ownerIndex !== 4n || resolved.environmentHash !== opened.environmentHash || resolved.environmentHash !== generations[g + 1]!.proposal.environmentHash || !before(op, opened, resolved)
            || seenResolutions.has(key) || op.journal.some(n => n.position.point.environmentHash === resolved.environmentHash && n.position.point.ownerRevision === resolved.ownerRevision)) throw Error("Invalid unique original resolution coordinate");
          seenResolutions.add(key); const re = eraOf(op, resolved); revokes[re] = revokes[re]! + 1n; openingCount++;
          markGenerationAliases(op, used4, "attribution_lifecycle.replay.dispute_key", hash(["uint256", "uint64", "bytes32", "address", "bytes32", "bytes32"], [q.collectionId, generation.generation, Z, r.opening.signer, r.opening.terms.evidenceHash, r.opening.terms.reasonHash]), r.opening.recordHash, opened);
          markGenerationAliases(op, used4, "attribution_lifecycle.replay.governance_action", r.opening.governanceActionId, r.opening.recordHash, opened);
          markGenerationAliases(op, used4, "attribution_lifecycle.replay.dispute_resolution_key", r.opening.recordHash, r.resolution.actionId, resolved);
          markGenerationAliases(op, used4, "attribution_lifecycle.replay.governance_action", r.resolution.actionId, r.opening.recordHash, resolved);
          const revType = schemaType(childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_HISTORY_TUPLE, "revocations")).arrayChildren!;
          if (b.corrections[g + 1]!.approval.causeData !== codec.encodeTupleValues([terminalType(), ...revType.components!.map(t => t.format("full"))], [row.terminal, r.head, r.opening, r.resolution])) throw Error("Correction does not retain exact governed revoke history");
        }
      } else {
        if (g + 1 === generations.length || row.terminal.reasonHash === Z || ![1n, 2n].includes(row.terminal.kind) || row.terminal.kind === 2n && row.terminal.recordHash !== Z) throw Error("Invalid pending terminal generation");
        const terminal = row.terminal.kind === 1n ? occurrence(bp, q, 3n, row.terminal.recordHash).position.point : resolvedPoint(bp, "binding_lifecycle.replay.proposal_terminal_transition_key", logical, generation.bindingHash);
        if (terminal.environmentHash !== point.environmentHash || !before(bp, point, terminal) || !before(bp, terminal, generations[g + 1]!.proposal)) throw Error("Pending generation terminal chronology mismatch");
        markGenerationAliases(bp, used0, row.terminal.kind === 1n ? "binding_lifecycle.replay.refusal_uniqueness" : "binding_lifecycle.replay.proposal_terminal_transition_key", logical, row.terminal.kind === 1n ? row.terminal.recordHash : generation.bindingHash, terminal);
        guards0[e] = guards0[e]! + 1n; if (row.terminal.kind === 1n) native0[e] = native0[e]! + 1n;
      }
    }
    if (acceptedCursor !== a.rows.length || revokeCursor !== history.revocations.length) throw Error("Trailing generation acceptance/revocation rows");
  }
  if (used0.size !== bp.aliases.length || used3.size !== ap.aliases.length || used4.size !== op.aliases.length || acceptanceCount !== ap.journal.length
    || openingCount !== op.journal.filter(j => j.receipt.operation === 44n).length || bp.journal.length !== Number(native0.reduce((a,b) => a+b, 0n))) throw Error("Incomplete generation original journal/alias union");
  let g0 = 0n, g3 = 0n, g4 = 0n, cursor3 = 0;
  for (let e = 0; e < bp.eras.length; e++) {
    g0 += guards0[e]!; g3 += ap.eras[e]!.nativeCount; g4 += revokes[e]!;
    for (const [p, count, replay] of [[bp, counts0[e]!, g0], [ap, ap.eras[e]!.nativeCount, g3]] as const) {
      const era = p.eras[e]!;
      if (era.lowerRevision !== (e ? 1n : 0n) || era.checkpoint.ownerState.revision !== era.lowerRevision + count || era.checkpoint.replayCount !== replay
        || !replay && era.checkpoint.replayRoot !== Z || era.checkpoint.nonceIndexCount || era.checkpoint.nonceRoot !== Z) throw Error("Generation owner0/3 era accounting mismatch");
    }
    if (bp.eras[e]!.nativeCount !== native0[e]) throw Error("Generation owner0 native counts mismatch");
    for (let n = 0n; n < ap.eras[e]!.nativeCount; n++) if (ap.journal[cursor3++]!.position.point.ownerRevision !== ap.eras[e]!.lowerRevision + n + 1n) throw Error("Generation acceptance revision order mismatch");
    const era = op.eras[e]!, count = BigInt(inventory.operations.filter(r => r.originHash === era.originHash).length);
    if (era.lowerRevision !== (e ? 1n : 0n) || era.checkpoint.ownerState.revision !== era.lowerRevision + count + era.nativeCount + revokes[e]!
      || era.checkpoint.replayCount !== 4n * g4 || !g4 && era.checkpoint.replayRoot !== Z || era.checkpoint.nonceIndexCount || era.checkpoint.nonceRoot !== Z) throw Error("Generation owner4 era accounting mismatch");
  }
  for (const j of op.journal) if (![24n, 44n].includes(j.receipt.operation)) throw Error("Unsupported generation owner4 operation");
}
function validateGenerationIdentityFacts(identities: readonly ArtistRecoveredMultipleGenerationHydrationIdentity[], s: ArtistRecoveredMultipleGenerationHydrationState,
  full: shared.ArtistRecoveredHydrationProvenance, inventory: ArtistRecoveredMultipleGenerationHydrationInventory, accepted: readonly ArtistRecoveredMultipleGenerationHydrationAcceptanceBundle[]): void {
  for (let k = 0; k < s.collections.length; k++) {
    const q = s.collections[k]!, identity = identities.find(i => i.artistId === q.artistId); if (!identity) throw Error("Missing generation Artist Identity");
    let cursor = 0;
    for (let g = 0; g < inventory.generations[k]!.length; g++) {
      const r = inventory.bindings[k]!.bindings.rows[g]!, docs = identity.documents.filter(d => d.documentHash === r.item.identityRecordHash);
      if (docs.length !== 1 || r.item.identityRecordHash === Z || keccak256(docs[0]!.document) !== r.item.identityRecordHash) throw Error("Generation binding document missing from original Identity");
      const record = r.item.accepted ? accepted[k]!.rows[cursor++]!.recordHash : r.terminal.kind === 1n ? r.terminal.recordHash : Z;
      if (record !== Z) { const sig = identity.signatures.filter(s => s.recordHash === record); if (sig.length !== 1 || (sig[0]!.signature.length - 2) / 2 > 4096) throw Error("Generation completion requires exactly one retained original signature"); }
    }
  }
  if (full.journals[2].some(j => [2n, 3n, 4n, 44n, 45n, 47n].includes(j.receipt.operation))) throw Error("Unsupported generation Identity collection operation");
}

export interface ArtistRecoveredMultipleGenerationHydrationTimeline {
  readonly proposals: readonly shared.ArtistRecoveredHydrationPoint[];
  readonly completions: readonly shared.ArtistRecoveredHydrationPoint[];
  readonly attributionProposals: readonly shared.ArtistRecoveredHydrationPoint[];
  readonly attributionCompletions: readonly shared.ArtistRecoveredHydrationPoint[];
}
export interface ArtistRecoveredMultipleGenerationHydrationClockFacts {
  readonly envelopes: readonly Hex[];
  readonly bindings: readonly ArtistRecoveredMultipleGenerationHydrationBindingBundle[];
  readonly acceptances: readonly ArtistRecoveredMultipleGenerationHydrationAcceptanceBundle[];
}
export interface ArtistRecoveredMultipleGenerationHydrationClockResult {
  readonly collections: readonly ArtistRecoveredMultipleGenerationHydrationTimeline[];
  readonly counts: readonly bigint[];
  readonly factsVerified: false;
}
/** Validates the original supplied Archive bytes and completion facts. Does not authenticate an RPC read or execute signatures. */
export function validateArtistRecoveredMultipleGenerationHydrationClocks(
  value: ArtistRecoveredMultipleGenerationHydrationState, provenance: shared.ArtistRecoveredHydrationProvenance,
  inventory: ArtistRecoveredMultipleGenerationHydrationInventory, facts: ArtistRecoveredMultipleGenerationHydrationClockFacts,
): ArtistRecoveredMultipleGenerationHydrationClockResult {
  const s = normalizeArtistRecoveredMultipleGenerationHydrationState(value), p = codec.normalizeArtistRecoveredHydrationProvenance(provenance), op = codec.artistRecoveredHydrationOwnerProvenance(p, 4), bp = codec.artistRecoveredHydrationOwnerProvenance(p, 0);
  const v = validateArtistRecoveredMultipleGenerationHydrationInventory(s, op, inventory);
  facts = codec.normalizeTuple(`tuple(bytes[] envelopes,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_BUNDLE_TUPLE}[] bindings,${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACCEPTANCE_BUNDLE_TUPLE}[] acceptances)`, facts); codec.boundedArray(facts.envelopes, 32768, v.operations.length);
  codec.boundedArray(facts.bindings, 128, s.collections.length); codec.boundedArray(facts.acceptances, 128, s.collections.length);
  const bindings = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_BUNDLE_TUPLE}[]`, facts.bindings), accepted = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ACCEPTANCE_BUNDLE_TUPLE}[]`, facts.acceptances);
  if (!same(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_BINDING_BUNDLE_TUPLE}[]`, bindings, v.bindings)) throw Error("Clock supplied bindings differ from original inventory");
  validateClockCutoffs(v, p);
  const timelines = v.generations.map(() => ({ proposals: [] as shared.ArtistRecoveredHydrationPoint[], completions: [] as shared.ArtistRecoveredHydrationPoint[], attributionProposals: [] as shared.ArtistRecoveredHydrationPoint[], attributionCompletions: [] as shared.ArtistRecoveredHydrationPoint[] }));
  const cursors = s.collections.map(() => 0), completed = s.collections.map(() => true), counts = op.eras.map(() => 0n), bindingCounts = bp.eras.map(() => 0n);
  let previousEra = -1, previousRevision = 0n, aggregateBytes = 0;
  for (let i = 0; i < v.operations.length; i++) {
    const row = v.operations[i]!, era = op.eras.findIndex(e => e.originHash === row.originHash), c = v.catalogues[era]!, o = op.origins[era]!;
    const raw = codec.boundedBytes(facts.envelopes[i]!, undefined, 24575); aggregateBytes += (raw.length - 2) / 2;
    if (aggregateBytes > shared.ARTIST_RECOVERED_HYDRATION_MAX_BYTES) throw Error("Supplied Archive envelope bytes exceed client capacity");
    const e = decodeArtistRecoveredMultipleGenerationHydrationArchiveEnvelope(raw);
    if (keccak256(raw) !== row.evidence.payloadHash || e.version !== 1n || e.configurationHash !== c.configurationHash || e.actor === ZeroAddress || e.value === Z || e.operation !== row.operation
      || row.evidence.evidenceId !== hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"], [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), o.chainId, o.registry, o.coordinator, e.operation, e.actor, e.value])
      || era < previousEra || era === previousEra && e.after_[4].revision <= previousRevision) throw Error("Original Archive envelope identity or clock order mismatch");
    previousEra = era; previousRevision = e.after_[4].revision;
    const mask = e.operation === 2n ? 0x1f : e.operation === 4n ? 0x11 : 0x15;
    for (let owner = 0; owner < 7; owner++) {
      const n = owner as ArtistHydrationOwnerIndex, a = e.before_[n], b = e.after_[n];
      if (!(mask & 1 << owner)) {
        if (!empty(ARTIST_HYDRATION_SNAPSHOT_TUPLE, a) || !empty(ARTIST_HYDRATION_SNAPSHOT_TUPLE, b)) throw Error("Unexpected original Archive snapshot slot");
      } else {
        if (a.domainId !== codec.artistRecoveredHydrationOwnerDomain(n) || b.domainId !== a.domainId || a.stateRoot === Z || b.stateRoot === Z || a.recordChainTip === Z || b.recordChainTip === Z
          || a.revision < c.lower[n] || b.revision > c.upper[n] || b.revision < a.revision || b.revision > a.revision + 1n) throw Error("Original Archive snapshot cutoff mismatch");
        if (owner === 1 || owner === 2 && e.operation === 1n && b.revision === a.revision) {
          if (!same(ARTIST_HYDRATION_SNAPSHOT_TUPLE, a, b)) throw Error("Unchanged original Archive snapshot differs");
        } else if (b.revision !== a.revision + 1n) throw Error("Original Archive snapshot increment mismatch");
      }
    }
    const candidates: { k: number; g: number }[] = [];
    for (let k = 0; k < bindings.length; k++) for (let g = 0; g < bindings[k]!.bindings.rows.length; g++) {
      const r = bindings[k]!.bindings.rows[g]!;
      const key = e.operation === 2n ? accepted[k]!.rows.find(a => a.bindingHash === r.item.bindingHash)?.recordHash : e.operation === 3n ? r.terminal.recordHash : r.item.bindingHash;
      if (key !== Z && key === e.value) candidates.push({ k, g });
    }
    if (candidates.length !== 1) throw Error("Archive operation must identify exactly one original generation");
    const { k, g } = candidates[0]!, q = s.collections[k]!, bundle = bindings[k]!, retained = bundle.bindings.rows[g]!, generation = v.generations[k]![g]!, binding = { ...retained.item, accepted: false };
    const point0 = Object.freeze({ environmentHash: row.originHash, ownerIndex: 0n, ownerRevision: e.after_[0].revision });
    const point4 = Object.freeze({ environmentHash: row.originHash, ownerIndex: 4n, ownerRevision: e.after_[4].revision });
    bindingCounts[era] = bindingCounts[era]! + 1n;
    if (e.after_[0].revision !== bp.eras[era]!.lowerRevision + bindingCounts[era]!) throw Error("Archive owner0 global clock has a hole or duplicate");
    let action: Hex, state: Hex;
    if (e.operation === 1n) {
      if (g !== cursors[k] || !completed[k] || !same(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, point0, generation.proposal)) throw Error("Original generation proposal order mismatch");
      generationRow(retained, q, BigInt(g + 1), o); correctionRow(bundle, q, g, o);
      const correction = bundle.corrections[g]!, data = correction.recordHash === Z ? decodeArtistRecoveredMultipleGenerationHydrationProposalPayload(e.payload) : decodeArtistRecoveredMultipleGenerationHydrationCorrectionPayload(e.payload);
      if (correction.recordHash !== Z) {
        const d = data as ArtistRecoveredMultipleGenerationHydrationCorrectionPayload, a = correction.approval;
        if (d.tag !== id("6529STREAM_ARTIST_BINDING_CORRECTION_EVIDENCE_V1") || d.version !== 1n || !same(childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CORRECTION_TUPLE, "approval"), d.approval, a)
          || a.proposalHash !== hash(["uint256", childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PROPOSAL_PAYLOAD_TUPLE, "proposal"), "bytes", "string"], [d.id, d.proposal, d.document, d.displayName])
          || d.context.scopeHash !== a.governance.scopeHash || d.context.oldValueHash !== a.governance.oldValueHash || d.context.newValueHash !== a.governance.newValueHash || d.repudiation !== Z) throw Error("Original correction envelope differs from retained approval");
      }
      const b = data.proposal;
      if (data.id !== q.collectionId || e.value !== binding.bindingHash || e.actor !== binding.proposer || data.reused !== (b.artistId !== Z) || b.artistId !== Z && b.artistId !== binding.artistId
        || b.artistAddress !== binding.artistAddress || b.identityRecordHash !== binding.identityRecordHash || b.consentMode !== binding.consentMode || b.saleConsentScope !== binding.saleConsentScope
        || b.registryImmutabilityElection !== binding.registryImmutabilityElection || b.collabPolicyMode || b.collabThreshold || b.collaborators.length || b.capabilityPolicyOverrides.length || toUtf8Bytes(b.reasonURI).length > 2048) throw Error("Original proposal payload differs from retained binding");
      action = hash(["uint256", bindingItemType(), "bytes32", "string"], [q.collectionId, binding, b.reasonHash, b.reasonURI]);
      state = hash(["uint256", "uint8", "uint64"], [q.collectionId, 1n, binding.generation]);
      cursors[k] = cursors[k]! + 1; completed[k] = false; timelines[k]!.proposals[g] = point0; timelines[k]!.attributionProposals[g] = point4;
    } else {
      if (g + 1 !== cursors[k] || completed[k] || generation.proposal.environmentHash !== row.originHash || e.before_[0].revision < generation.proposal.ownerRevision
        || !before(op, timelines[k]!.attributionProposals[g]!, point4)) throw Error("Original completion precedes its collection proposal");
      if (e.operation === 2n) {
        const { acceptance: a, authority } = decodeArtistRecoveredMultipleGenerationHydrationAcceptancePayload(e.payload), at = accepted[k]!.rows.find(r => r.bindingHash === binding.bindingHash);
        const principal = authority.authorityClass === 1n && [1n, 2n].includes(authority.status) || [3n, 4n].includes(authority.authorityClass) && authority.status === 3n;
        const digest = originalTypedDigest(o, hash(["bytes32", "address", "uint256", "uint64", "bytes32", "bytes32", "uint256", "uint64"], [id("StreamArtistAcceptance(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 identityRecordHash,uint256 nonce,uint64 deadline)"), o.core, q.collectionId, binding.generation, binding.bindingHash, binding.identityRecordHash, a.authorization.nonce, a.authorization.time]));
        const record = at && hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "uint8", "address", "uint8", "uint256", "uint64"], [id("6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1"), o.chainId, o.registry, o.core, q.collectionId, binding.generation, binding.bindingHash, 1n, a.proof.signer, authority.authorityClass, a.authorization.nonce, at.acceptedAt]);
        if (!generation.accepted || !at?.acceptedAt || at.recordHash !== e.value || a.id !== q.collectionId || !same(bindingItemType(), a.binding_, binding) || authority.artistId !== q.artistId || authority.authorityAddress !== a.proof.signer || a.proof.signer === ZeroAddress || !principal
          || a.proof.digest !== digest || a.proof.direct !== (e.actor === a.proof.signer && a.authorization.signature === "0x") || record !== e.value) throw Error("Original accepted-completion facts mismatch");
        action = hash(["uint256", bindingItemType(), "bytes32"], [q.collectionId, binding, e.value]);
        state = hash(["uint256", "tuple(uint8 state,uint64 generation)"], [q.collectionId, { state: 2n, generation: binding.generation }]);
      } else {
        if (generation.accepted) throw Error("Accepted generation cannot complete with refusal/withdrawal");
        let terms: ArtistRecoveredMultipleGenerationHydrationRefusalPayload["terms"], signer: Address, authority = 0n, nonce = 0n;
        if (e.operation === 3n) {
          const r = decodeArtistRecoveredMultipleGenerationHydrationRefusalPayload(e.payload), a = r.authority;
          const principal = a.authorityClass === 1n && [1n, 2n].includes(a.status) || [3n, 4n].includes(a.authorityClass) && a.status === 3n;
          if (!same(bindingItemType(), r.binding_, binding) || retained.terminal.kind !== 1n || retained.terminal.recordHash !== e.value || a.artistId !== q.artistId || a.authorityAddress !== r.proof.signer || r.proof.signer === ZeroAddress || !principal) throw Error("Original refusal payload mismatch");
          terms = r.terms; signer = r.proof.signer; authority = a.authorityClass; nonce = r.authorization.nonce;
        } else {
          const type = childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_REFUSAL_PAYLOAD_TUPLE, "terms"), types = [bindingItemType(), type], bytes = preflight(types, e.payload), d = coder.decode(types, bytes);
          if (coder.encode(types, d) !== bytes || !same(bindingItemType(), plain(schemaType(types[0]!), d[0]), binding) || retained.terminal.kind !== 2n || e.actor !== binding.proposer || e.value !== binding.bindingHash) throw Error("Original withdrawal payload mismatch");
          terms = codec.normalizeTuple(type, plain(schemaType(type), d[1])) as ArtistRecoveredMultipleGenerationHydrationRefusalPayload["terms"]; signer = e.actor;
        }
        if (terms.collectionId !== q.collectionId || terms.generation !== binding.generation || terms.bindingHash !== binding.bindingHash || terms.reasonHash === Z || terms.reasonHash !== retained.terminal.reasonHash) throw Error("Original termination terms mismatch");
        action = hash([bindingItemType(), childType(ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_REFUSAL_PAYLOAD_TUPLE, "terms"), "address", "uint8", "uint256", "bytes32"], [binding, terms, signer, authority, nonce, e.value]);
        state = hash(["uint256", "tuple(uint8 state,uint64 generation)"], [q.collectionId, { state: 5n, generation: binding.generation }]);
      }
      completed[k] = true; timelines[k]!.completions[g] = point0; timelines[k]!.attributionCompletions[g] = point4;
    }
    const a = e.before_[4], b = e.after_[4];
    const root = hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "uint64", "uint64", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"), o.chainId, o.registry, o.coordinator, o.archive, o.owners[4], codec.artistRecoveredHydrationOwnerDomain(4), a.revision, b.revision, a.stateRoot, hash(["uint16", "address", "bytes32"], [e.operation, e.actor, action]), state, Z, hash(["bytes32"], [Z])]);
    if (b.stateRoot !== root || b.recordChainTip !== a.recordChainTip) throw Error("Original owner4 transition preimage mismatch");
    counts[era] = counts[era]! + 1n;
    if (op.journal.some(j => j.position.point.environmentHash === point4.environmentHash && j.position.point.ownerRevision === point4.ownerRevision)) throw Error("Original clock overlaps native owner4 occurrence");
    if (e.operation !== 4n) {
      const owner = e.operation === 2n ? 3 : 0, native = occurrence(codec.artistRecoveredHydrationOwnerProvenance(p, owner), q, e.operation, e.value);
      if (native.position.point.environmentHash !== row.originHash || native.position.point.ownerRevision !== e.after_[owner].revision) throw Error("Archive envelope differs from original native occurrence");
    }
  }
  for (let k = 0; k < timelines.length; k++) if (cursors[k] !== v.generations[k]!.length || !completed[k]) throw Error("Incomplete original generation clock sequence");
  for (let e = 0; e < bp.eras.length; e++) if (bp.eras[e]!.checkpoint.ownerState.revision !== bp.eras[e]!.lowerRevision + bindingCounts[e]!) throw Error("Uncovered original owner0 completion clock");
  return Object.freeze({ collections: Object.freeze(timelines.map(t => Object.freeze({ proposals: Object.freeze(t.proposals), completions: Object.freeze(t.completions), attributionProposals: Object.freeze(t.attributionProposals), attributionCompletions: Object.freeze(t.attributionCompletions) }))), counts: Object.freeze(counts), factsVerified: false });
}

/** Joins original owner4 native/alias coordinates to supplied, unverified clock facts. */
export function validateArtistRecoveredMultipleGenerationHydrationRevocations(
  scope: ArtistRecoveredMultipleGenerationHydrationState, provenance: shared.ArtistRecoveredHydrationProvenance,
  inventory: ArtistRecoveredMultipleGenerationHydrationInventory, histories: readonly ArtistRecoveredMultipleGenerationHydrationAttributionHistory[],
  clock: ArtistRecoveredMultipleGenerationHydrationClockResult,
): void {
  const s = normalizeArtistRecoveredMultipleGenerationHydrationState(scope), full = codec.normalizeArtistRecoveredHydrationProvenance(provenance), p = codec.artistRecoveredHydrationOwnerProvenance(full, 4);
  inventory = normalizeArtistRecoveredMultipleGenerationHydrationInventory(inventory); clock = normalizeGenerationClockResult(clock, inventory);
  codec.boundedArray(histories, 128, s.collections.length); codec.boundedArray(clock.collections, 128, s.collections.length);
  histories = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_ATTRIBUTION_HISTORY_TUPLE}[]`, histories);
  const points = clock.collections.flatMap(t => [...t.attributionProposals, ...t.attributionCompletions]);
  const seen = new Set<string>();
  for (let k = 0; k < s.collections.length; k++) {
    const q = s.collections[k]!, h = normalizeArtistRecoveredMultipleGenerationHydrationAttributionHistory(histories[k]!), t = clock.collections[k]!; let cursor = 0;
    for (let g = 0; g + 1 < inventory.generations[k]!.length; g++) {
      if (!inventory.generations[k]![g]!.accepted) continue;
      const r = h.revocations[cursor++]; if (!r) throw Error("Missing original revocation");
      const opened = occurrence(p, q, 44n, r.opening.recordHash).position.point, resolved = resolvedPoint(p, "attribution_lifecycle.replay.dispute_resolution_key", r.opening.recordHash, r.resolution.actionId);
      const key = `${resolved.environmentHash}:${resolved.ownerRevision}`;
      if (resolved.ownerIndex !== 4n || opened.environmentHash !== resolved.environmentHash || resolved.environmentHash !== t.attributionProposals[g + 1]!.environmentHash
        || !before(p, t.attributionCompletions[g]!, opened) || !before(p, opened, resolved) || !before(p, resolved, t.attributionProposals[g + 1]!)
        || seen.has(key) || points.some(v => v.environmentHash === resolved.environmentHash && v.ownerRevision === resolved.ownerRevision)
        || p.journal.some(j => j.position.point.environmentHash === resolved.environmentHash && j.position.point.ownerRevision === resolved.ownerRevision)) throw Error("Original revocation fails owner4 generation chronology");
      seen.add(key);
    }
    if (cursor !== h.revocations.length) throw Error("Trailing original revocations");
  }
}

function acceptedBinding(bindings: readonly ArtistRecoveredMultipleGenerationHydrationBinding["item"][], generation: bigint, hash?: Hex, delegated = false): boolean {
  if (generation < 1n || generation > BigInt(bindings.length)) return false;
  const b = bindings[Number(generation - 1n)]!;
  return b.accepted && b.generation === generation && (hash === undefined || b.bindingHash === hash) && (!delegated || b.consentMode === 2n);
}
function validateHistoricalBindings(bindings: readonly ArtistRecoveredMultipleGenerationHydrationBinding["item"][], q: ArtistHydrationQuery): void {
  codec.boundedArray(bindings, 128);
  if (!bindings.length || !bindings.at(-1)!.accepted || bindings.at(-1)!.bindingHash !== q.bindingHash) throw Error("Missing current accepted generation");
  for (let i = 0; i < bindings.length; i++) if (bindings[i]!.generation !== BigInt(i + 1) || bindings[i]!.artistId !== q.artistId || bindings[i]!.bindingHash === Z || ![1n, 2n].includes(bindings[i]!.consentMode)) throw Error("Invalid complete historical binding inventory");
}

export const ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_TIMELINE_TUPLE = `tuple(${shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE}[] proposals,${shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE}[] completions,${shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE}[] attributionProposals,${shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE}[] attributionCompletions)`;
function normalizeGenerationClockResult(value: ArtistRecoveredMultipleGenerationHydrationClockResult, inventory: ArtistRecoveredMultipleGenerationHydrationInventory): ArtistRecoveredMultipleGenerationHydrationClockResult {
  value = codec.normalizeTuple(`tuple(${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_TIMELINE_TUPLE}[] collections,uint256[] counts,bool factsVerified)`, value);
  if (value.factsVerified !== false) throw Error("Clock result cannot claim independently verified facts");
  codec.boundedArray(value.collections, 128, inventory.bindings.length); codec.boundedArray(value.counts, 16, inventory.catalogues.length);
  const collections = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_TIMELINE_TUPLE}[]`, value.collections);
  const counts = codec.normalizeTuple("uint256[]", value.counts);
  for (let k = 0; k < collections.length; k++) {
    const t = collections[k]!; const n = inventory.generations[k]!.length;
    for (const a of [t.proposals, t.completions, t.attributionProposals, t.attributionCompletions]) codec.boundedArray(a, 128, n);
  }
  return Object.freeze({ collections, counts, factsVerified: false });
}
