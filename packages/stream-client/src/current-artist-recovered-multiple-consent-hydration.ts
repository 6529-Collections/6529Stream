import { AbiCoder, Interface, getAddress, ParamType, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { ArtistHydrationQuery, ArtistHydrationOwnerIndex, ArtistHydrationSuite, ArtistHydrationSale, ArtistHydrationPolicyKey } from "./current-artist-authority-hydration.js";
import { ARTIST_HYDRATION_SUITE_TUPLE, ARTIST_HYDRATION_POLICY_TUPLE, ARTIST_HYDRATION_QUERY_TUPLE, ARTIST_HYDRATION_SNAPSHOT_TUPLE, ARTIST_HYDRATION_NONCE_WORD_TUPLE, ARTIST_HYDRATION_OWNER_DATA_TUPLE, ARTIST_HYDRATION_CHECKPOINT_TUPLE } from "./current-artist-authority-hydration.js";
import type { UnsignedCall } from "./binding.js";
import * as base from "./current-artist-recovered-multiple-hydration.js";
import * as shared from "./internal/artist-recovered-hydration-codec.js";

export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_SOURCE = "c636a5f176c5765d80d15ee20f41355a8911ea9c";
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_BASE = 524288n;
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ALLOWED_FEATURES = 524671n;
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_KNOWN_FEATURES = 1048575n;
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_SCHEMA = id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_CONSENTS_V1") as Hex;
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CONSENTS = 524288n;

export type {
  ArtistRecoveredHydrationCapability as ArtistRecoveredMultipleConsentHydrationCapability,
  ArtistRecoveredHydrationEconomicsConsent as ArtistRecoveredMultipleConsentHydrationEconomicsConsent,
  ArtistRecoveredHydrationAttestation as ArtistRecoveredMultipleConsentHydrationAttestation,
  ArtistRecoveredHydrationAttestationInput as ArtistRecoveredMultipleConsentHydrationAttestationInput,
  ArtistRecoveredHydrationCollectionWitness as ArtistRecoveredMultipleConsentHydrationCollectionWitness,
  ArtistRecoveredHydrationRecordsRequest as ArtistRecoveredMultipleConsentHydrationRecordsRequest,
  ArtistRecoveredHydrationRequest as ArtistRecoveredMultipleConsentHydrationRequest,
  ArtistRecoveredHydrationExportHeader as ArtistRecoveredMultipleConsentHydrationExportHeader,
  ArtistRecoveredHydrationOriginEnvironment as ArtistRecoveredMultipleConsentHydrationOriginEnvironment,
  ArtistRecoveredHydrationEra as ArtistRecoveredMultipleConsentHydrationEra,
  ArtistRecoveredHydrationPoint as ArtistRecoveredMultipleConsentHydrationPoint,
  ArtistRecoveredHydrationPosition as ArtistRecoveredMultipleConsentHydrationPosition,
  ArtistRecoveredHydrationJournalEntry as ArtistRecoveredMultipleConsentHydrationJournalEntry,
  ArtistRecoveredHydrationReplayAlias as ArtistRecoveredMultipleConsentHydrationReplayAlias,
  ArtistRecoveredHydrationProvenance as ArtistRecoveredMultipleConsentHydrationProvenance,
  ArtistRecoveredHydrationOwnerEra as ArtistRecoveredMultipleConsentHydrationOwnerEra,
  ArtistRecoveredHydrationOwnerProvenance as ArtistRecoveredMultipleConsentHydrationOwnerProvenance,
  ArtistRecoveredHydrationNonceInventory as ArtistRecoveredMultipleConsentHydrationNonceInventory,
  ArtistRecoveredHydrationEnvelope as ArtistRecoveredMultipleConsentHydrationEnvelope,
  ArtistRecoveredHydrationPublication as ArtistRecoveredMultipleConsentHydrationPublication,
  ArtistRecoveredHydrationOwnerPayload as ArtistRecoveredMultipleConsentHydrationOwnerPayload,
  ArtistRecoveredHydrationTimingConfiguration as ArtistRecoveredMultipleConsentHydrationTimingConfiguration,
  ArtistRecoveredHydrationTimingInput as ArtistRecoveredMultipleConsentHydrationTimingInput,
  ArtistRecoveredHydrationTimingEntry as ArtistRecoveredMultipleConsentHydrationTimingEntry,
  ArtistRecoveredHydrationTimingCheckpoint as ArtistRecoveredMultipleConsentHydrationTimingCheckpoint,
  ArtistRecoveredHydrationTimingBundle as ArtistRecoveredMultipleConsentHydrationTimingBundle,
  ArtistRecoveredHydrationActionWitness as ArtistRecoveredMultipleConsentHydrationActionWitness,
  ArtistRecoveredHydrationActionFacts as ArtistRecoveredMultipleConsentHydrationActionFacts,
  ArtistRecoveredHydrationActionGuard as ArtistRecoveredMultipleConsentHydrationActionGuard,
  ArtistRecoveredHydrationFinalityScope as ArtistRecoveredMultipleConsentHydrationFinalityScope,
  ArtistRecoveredHydrationFinalityComponent as ArtistRecoveredMultipleConsentHydrationFinalityComponent,
  ArtistRecoveredHydrationFinalityManifest as ArtistRecoveredMultipleConsentHydrationFinalityManifest,
  ArtistRecoveredHydrationFinalityEvidence as ArtistRecoveredMultipleConsentHydrationFinalityEvidence,
  ArtistRecoveredHydrationFinalityRecord as ArtistRecoveredMultipleConsentHydrationFinalityRecord,
  ArtistRecoveredHydrationFinalityTarget as ArtistRecoveredMultipleConsentHydrationFinalityTarget,
  ArtistRecoveredHydrationFinalityGuard as ArtistRecoveredMultipleConsentHydrationFinalityGuard,
  ArtistRecoveredHydrationEntropyReceipt as ArtistRecoveredMultipleConsentHydrationEntropyReceipt,
  ArtistRecoveredHydrationEntropyEvidence as ArtistRecoveredMultipleConsentHydrationEntropyEvidence,
  ArtistRecoveredHydrationEntropyGuard as ArtistRecoveredMultipleConsentHydrationEntropyGuard,
  ArtistRecoveredHydrationExternalGuards as ArtistRecoveredMultipleConsentHydrationExternalGuards,
  ArtistRecoveredHydrationCertificate as ArtistRecoveredMultipleConsentHydrationCertificate,
  ArtistRecoveredHydrationPrepared as ArtistRecoveredMultipleConsentHydrationPrepared,
  ArtistRecoveredHydrationEvidenceDescriptor as ArtistRecoveredMultipleConsentHydrationEvidenceDescriptor,
  ArtistRecoveredHydrationCoordinates as ArtistRecoveredMultipleConsentHydrationCoordinates,
  ArtistRecoveredHydrationProfileEvidence as ArtistRecoveredMultipleConsentHydrationProfileEvidence,
  ArtistRecoveredHydrationOperationEvidence as ArtistRecoveredMultipleConsentHydrationOperationEvidence,
  ArtistRecoveredHydrationHistoricalCell as ArtistRecoveredMultipleConsentHydrationHistoricalCell,
  ArtistRecoveredHydrationFeatureFacts as ArtistRecoveredMultipleConsentHydrationFeatureFacts
} from "./internal/artist-recovered-hydration-codec.js";

export {
  ARTIST_RECOVERED_HYDRATION_PROFILE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PROFILE,
  ARTIST_RECOVERED_HYDRATION_PAGE_BYTES as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PAGE_BYTES,
  ARTIST_RECOVERED_HYDRATION_MAX_BYTES as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_MAX_BYTES,
  ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_MAX_PREPARED_BYTES,
  ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CHECKPOINT_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_PAYLOAD_SCHEMA as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PAYLOAD_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_EVIDENCE_SCHEMA as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_EVIDENCE_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_CAPABILITY_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CAPABILITY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ECONOMICS_CONSENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ATTESTATION_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ATTESTATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ATTESTATION_INPUT_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ATTESTATION_INPUT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_COLLECTION_WITNESS_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_COLLECTION_WITNESS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_RECORDS_REQUEST_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_RECORDS_REQUEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_REQUEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EXPORT_HEADER_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_EXPORT_HEADER_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ERA_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ERA_TUPLE,
  ARTIST_RECOVERED_HYDRATION_POINT_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_POINT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_POSITION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_JOURNAL_ENTRY_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_JOURNAL_ENTRY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_REPLAY_ALIAS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PROVENANCE_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PROVENANCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_ERA_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_OWNER_ERA_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_OWNER_PROVENANCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_NONCE_INVENTORY_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_NONCE_INVENTORY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ENVELOPE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PUBLICATION_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PUBLICATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_PAYLOAD_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_OWNER_PAYLOAD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_CONFIGURATION_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_TIMING_CONFIGURATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_INPUT_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_TIMING_INPUT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_ENTRY_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_TIMING_ENTRY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_TIMING_CHECKPOINT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_BUNDLE_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_TIMING_BUNDLE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_WITNESS_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ACTION_WITNESS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_FACTS_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ACTION_FACTS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_GUARD_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ACTION_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_SCOPE_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_FINALITY_SCOPE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_COMPONENT_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_FINALITY_COMPONENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_MANIFEST_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_FINALITY_MANIFEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_EVIDENCE_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_FINALITY_EVIDENCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_RECORD_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_FINALITY_RECORD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_TARGET_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_FINALITY_TARGET_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_GUARD_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_FINALITY_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_RECEIPT_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ENTROPY_RECEIPT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_EVIDENCE_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ENTROPY_EVIDENCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_GUARD_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ENTROPY_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_EXTERNAL_GUARDS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_CERTIFICATE_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CERTIFICATE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PREPARED_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE as ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE
} from "./internal/artist-recovered-hydration-codec.js";

const codec = shared.createArtistRecoveredHydrationCodec(524671n);
export const {
  artistRecoveredHydrationOwnerDomain: artistRecoveredMultipleConsentHydrationOwnerDomain,
  artistRecoveredHydrationOwnerTag: artistRecoveredMultipleConsentHydrationOwnerTag,
  normalizeArtistRecoveredHydrationCoordinates: normalizeArtistRecoveredMultipleConsentHydrationCoordinates,
  normalizeArtistRecoveredHydrationCapability: normalizeArtistRecoveredMultipleConsentHydrationCapability,
  validateArtistRecoveredHydrationCapability: validateArtistRecoveredMultipleConsentHydrationCapability,
  normalizeArtistRecoveredHydrationRequestDraft: normalizeArtistRecoveredMultipleConsentHydrationRequestDraft,
  normalizeArtistRecoveredHydrationRequest: normalizeArtistRecoveredMultipleConsentHydrationRequest,
  encodeArtistRecoveredHydrationRequest: encodeArtistRecoveredMultipleConsentHydrationRequest,
  normalizeArtistRecoveredHydrationOriginEnvironment: normalizeArtistRecoveredMultipleConsentHydrationOriginEnvironment,
  artistRecoveredHydrationOriginHash: artistRecoveredMultipleConsentHydrationOriginHash,
  artistRecoveredHydrationReplayKey: artistRecoveredMultipleConsentHydrationReplayKey,
  normalizeArtistRecoveredHydrationOwnerProvenance: normalizeArtistRecoveredMultipleConsentHydrationOwnerProvenance,
  artistRecoveredHydrationOwnerProvenance: artistRecoveredMultipleConsentHydrationOwnerProvenance,
  normalizeArtistRecoveredHydrationProvenance: normalizeArtistRecoveredMultipleConsentHydrationProvenance,
  artistRecoveredHydrationProvenanceHash: artistRecoveredMultipleConsentHydrationProvenanceHash,
  artistRecoveredHydrationOwnerProvenanceHash: artistRecoveredMultipleConsentHydrationOwnerProvenanceHash,
  artistRecoveredHydrationAliasesHash: artistRecoveredMultipleConsentHydrationAliasesHash,
  compareArtistRecoveredHydrationPoints: compareArtistRecoveredMultipleConsentHydrationPoints,
  normalizeArtistRecoveredHydrationNonceInventory: normalizeArtistRecoveredMultipleConsentHydrationNonceInventory,
  normalizeArtistRecoveredHydrationPublications: normalizeArtistRecoveredMultipleConsentHydrationPublications,
  normalizeArtistRecoveredHydrationTimingCheckpoint: normalizeArtistRecoveredMultipleConsentHydrationTimingCheckpoint,
  normalizeArtistRecoveredHydrationExternalGuards: normalizeArtistRecoveredMultipleConsentHydrationExternalGuards,
  normalizeArtistRecoveredHydrationEvidenceDescriptor: normalizeArtistRecoveredMultipleConsentHydrationEvidenceDescriptor,
  artistRecoveredHydrationEvidenceDescriptor: artistRecoveredMultipleConsentHydrationEvidenceDescriptor,
  artistRecoveredHydrationEvidencePages: artistRecoveredMultipleConsentHydrationEvidencePages,
  assembleArtistRecoveredHydrationEvidence: assembleArtistRecoveredMultipleConsentHydrationEvidence,
  artistRecoveredHydrationPageId: artistRecoveredMultipleConsentHydrationPageId,
  artistRecoveredHydrationEvidenceId: artistRecoveredMultipleConsentHydrationEvidenceId,
  encodeArtistRecoveredHydrationEvidenceCarrier: encodeArtistRecoveredMultipleConsentHydrationEvidenceCarrier,
  decodeArtistRecoveredHydrationEvidenceCarrier: decodeArtistRecoveredMultipleConsentHydrationEvidenceCarrier,
  encodeArtistRecoveredHydrationOperationEvidence: encodeArtistRecoveredMultipleConsentHydrationOperationEvidence,
  decodeArtistRecoveredHydrationOperationEvidence: decodeArtistRecoveredMultipleConsentHydrationOperationEvidence,
  artistRecoveredHydrationOwnerReplayDelta: artistRecoveredMultipleConsentHydrationOwnerReplayDelta,
  artistRecoveredHydrationOwnerAfter: artistRecoveredMultipleConsentHydrationOwnerAfter
} = codec;

// These original complete structural declarations are byte-identical at 99e9503 and c636a5f.
// No BASE admission normalizer, semantic value or computed hash is reused.
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_IDENTITY_TUPLE = base.ARTIST_RECOVERED_MULTIPLE_HYDRATION_IDENTITY_TUPLE;
export type ArtistRecoveredMultipleConsentHydrationIdentity = base.ArtistRecoveredMultipleHydrationIdentity;

export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PAYOUT_TUPLE = base.ARTIST_RECOVERED_MULTIPLE_HYDRATION_PAYOUT_TUPLE;
export type ArtistRecoveredMultipleConsentHydrationPayout = base.ArtistRecoveredMultipleHydrationPayout;

export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_BINDING_TUPLE = base.ARTIST_RECOVERED_MULTIPLE_HYDRATION_BINDING_TUPLE;
export type ArtistRecoveredMultipleConsentHydrationBinding = base.ArtistRecoveredMultipleHydrationBinding;

export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ACCEPTANCE_TUPLE = base.ARTIST_RECOVERED_MULTIPLE_HYDRATION_ACCEPTANCE_TUPLE;
export type ArtistRecoveredMultipleConsentHydrationAcceptance = base.ArtistRecoveredMultipleHydrationAcceptance;

export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ATTRIBUTION_STATE_TUPLE = base.ARTIST_RECOVERED_MULTIPLE_HYDRATION_ATTRIBUTION_STATE_TUPLE;
export type ArtistRecoveredMultipleConsentHydrationAttributionState = base.ArtistRecoveredMultipleHydrationAttributionState;

export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_POLICY_TUPLE = base.ARTIST_RECOVERED_MULTIPLE_HYDRATION_POLICY_TUPLE;
export type ArtistRecoveredMultipleConsentHydrationPolicy = base.ArtistRecoveredMultipleHydrationPolicy;

export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ATTRIBUTION_TUPLE = `tuple(${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ATTRIBUTION_STATE_TUPLE} state,bytes32 proposalOrigin)`;
export interface ArtistRecoveredMultipleConsentHydrationAttribution { readonly state: ArtistRecoveredMultipleConsentHydrationAttributionState; readonly proposalOrigin: Hex; }
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_STATE_TUPLE = `tuple(${ARTIST_HYDRATION_QUERY_TUPLE}[] artists,${ARTIST_HYDRATION_QUERY_TUPLE}[] collections,bytes[] rows)`;
export interface ArtistRecoveredMultipleConsentHydrationState { readonly artists: readonly ArtistHydrationQuery[]; readonly collections: readonly ArtistHydrationQuery[]; readonly rows: readonly Hex[]; }

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
const stateType = schemaType(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_STATE_TUPLE);
const payoutSchema = id("6529STREAM_ARTIST_RECOVERED_PAYOUT_HYDRATION_V1");

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

/** Structural tuple only. validateState adds the original complete membership predicates. */
export function normalizeArtistRecoveredMultipleConsentHydrationState(value: ArtistRecoveredMultipleConsentHydrationState): ArtistRecoveredMultipleConsentHydrationState {
  return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_STATE_TUPLE, value);
}

export function validateArtistRecoveredMultipleConsentHydrationState(
  index: ArtistHydrationOwnerIndex,
  value: ArtistRecoveredMultipleConsentHydrationState,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistRecoveredMultipleConsentHydrationState {
  const s = normalizeArtistRecoveredMultipleConsentHydrationState(value);
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

export function artistRecoveredMultipleConsentHydrationAnchor(value: ArtistRecoveredMultipleConsentHydrationState): ArtistHydrationQuery {
  const s = normalizeArtistRecoveredMultipleConsentHydrationState(value);
  const first = s.collections[0], artist = first && s.artists.find(a => a.artistId === first.artistId);
  if (!first || !artist) throw Error("Missing multiple anchor");
  return Object.freeze({ ...first, records: artist.records });
}

export function encodeArtistRecoveredMultipleConsentHydrationState(
  value: ArtistRecoveredMultipleConsentHydrationState, index: ArtistHydrationOwnerIndex,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): Hex {
  const s = validateArtistRecoveredMultipleConsentHydrationState(index, value, provenance);
  return codec.encodeTupleValues(["bytes32", "uint16", "uint8", ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_STATE_TUPLE],
    [ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_SCHEMA, 1n, BigInt(index), s]);
}

export function decodeArtistRecoveredMultipleConsentHydrationState(
  raw: Hex, index: ArtistHydrationOwnerIndex, provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistRecoveredMultipleConsentHydrationState {
  const types = ["bytes32", "uint16", "uint8", ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_STATE_TUPLE];
  const parsed = types.map(schemaType);
  const bytes = preflight(types, raw), result = coder.decode(parsed, bytes);
  if (result[0] !== ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_SCHEMA || result[1] !== 1n || result[2] !== BigInt(index)
    || coder.encode(parsed, result) !== bytes) throw Error("Noncanonical multiple State tag/version/owner");
  return validateArtistRecoveredMultipleConsentHydrationState(index, plain(stateType, result[3]) as ArtistRecoveredMultipleConsentHydrationState, provenance);
}

export function normalizeArtistRecoveredMultipleConsentHydrationIdentity(value: ArtistRecoveredMultipleConsentHydrationIdentity): ArtistRecoveredMultipleConsentHydrationIdentity {
  return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_IDENTITY_TUPLE, value);
}
export function encodeArtistRecoveredMultipleConsentHydrationIdentity(value: ArtistRecoveredMultipleConsentHydrationIdentity): Hex {
  return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_IDENTITY_TUPLE], [normalizeArtistRecoveredMultipleConsentHydrationIdentity(value)]);
}
export function decodeArtistRecoveredMultipleConsentHydrationIdentity(raw: Hex): ArtistRecoveredMultipleConsentHydrationIdentity {
  return decode(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_IDENTITY_TUPLE, raw);
}
export function encodeArtistRecoveredMultipleConsentHydrationPayout(value: ArtistRecoveredMultipleConsentHydrationPayout): Hex {
  return codec.encodeTupleValues(["bytes32", ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PAYOUT_TUPLE],
    [payoutSchema, codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PAYOUT_TUPLE, value)]);
}
export function decodeArtistRecoveredMultipleConsentHydrationPayout(raw: Hex): ArtistRecoveredMultipleConsentHydrationPayout {
  const types = ["bytes32", ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PAYOUT_TUPLE];
  const parsed = types.map(schemaType);
  const bytes = preflight(types, raw), v = coder.decode(parsed, bytes);
  if (v[0] !== payoutSchema || coder.encode(parsed, v) !== bytes) throw Error("Noncanonical recovered Payout row");
  return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PAYOUT_TUPLE,
    plain(schemaType(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PAYOUT_TUPLE), v[1]) as ArtistRecoveredMultipleConsentHydrationPayout);
}

export type ArtistRecoveredMultipleConsentHydrationNonceLane = ArtistRecoveredMultipleConsentHydrationIdentity["nonces"][number];

/** Exact global-index bijection; local lanes retain increasing global positions. Empty local sets are valid. */
export function artistRecoveredMultipleConsentHydrationNonceUnion(
  value: ArtistRecoveredMultipleConsentHydrationState,
  inventory: readonly shared.ArtistRecoveredHydrationNonceInventory[],
  checkpoint: Parameters<typeof codec.normalizeArtistRecoveredHydrationNonceInventory>[1],
): readonly ArtistRecoveredMultipleConsentHydrationNonceLane[] {
  const s = normalizeArtistRecoveredMultipleConsentHydrationState(value);
  const rows = codec.normalizeArtistRecoveredHydrationNonceInventory(inventory, checkpoint);
  if (s.rows.length !== s.artists.length || !s.artists.length || s.artists.length > 128) throw Error("Invalid Identity row partition");
  const result: ArtistRecoveredMultipleConsentHydrationNonceLane[] = new Array(rows.length);
  const seen = new Set<number>(), authorities = new Set<Address>();
  let timing: Hex | undefined;
  for (let i = 0; i < s.rows.length; i++) {
    const b = decodeArtistRecoveredMultipleConsentHydrationIdentity(s.rows[i]!);
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
        ? b.delegations.some(d => lane.key === artistRecoveredMultipleConsentHydrationDelegateLane(b.artistId, d.record.grant.delegate)) : lane.kind === 4n
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

export function normalizeArtistRecoveredMultipleConsentHydrationOwnerPayload(
  value: shared.ArtistRecoveredHydrationOwnerPayload, index: ArtistHydrationOwnerIndex,
): shared.ArtistRecoveredHydrationOwnerPayload {
  const p = codec.normalizeArtistRecoveredHydrationOwnerPayload(value, index);
  decodeArtistRecoveredMultipleConsentHydrationState(p.semanticState, index, p.provenance);
  if (index !== 2 && p.nonces.length) throw Error("Only Identity carries multiple nonce inventory");
  return p;
}
export function encodeArtistRecoveredMultipleConsentHydrationOwnerPayload(
  value: shared.ArtistRecoveredHydrationOwnerPayload, index: ArtistHydrationOwnerIndex, features: bigint,
): Hex {
  return codec.encodeArtistRecoveredHydrationOwnerPayload(normalizeArtistRecoveredMultipleConsentHydrationOwnerPayload(value, index), index, features);
}
export function decodeArtistRecoveredMultipleConsentHydrationOwnerPayload(raw: Hex, index: ArtistHydrationOwnerIndex) {
  preflight(["bytes32", "uint16", shared.ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE], raw);
  const v = codec.decodeArtistRecoveredHydrationOwnerPayload(raw, index);
  normalizeArtistRecoveredMultipleConsentHydrationOwnerPayload(v.payload, index);
  return v;
}

function occurrence(p: shared.ArtistRecoveredHydrationOwnerProvenance, q: ArtistHydrationQuery, op: bigint, key: Hex) {
  const rows = p.journal.filter(j => j.receipt.recordHash === key);
  if (key === Z || rows.length !== 1 || rows[0]!.receipt.operation !== op || rows[0]!.receipt.artistId !== q.artistId
    || rows[0]!.receipt.collectionId !== q.collectionId) throw Error("Multiple row native occurrence mismatch");
  return rows[0]!;
}

/** Supplied Binding preimage under its original era, never the destination Registry. */
export function artistRecoveredMultipleConsentHydrationBindingHash(
  origin: shared.ArtistRecoveredHydrationOriginEnvironment, collectionId: bigint,
  value: ArtistRecoveredMultipleConsentHydrationBinding["item"],
): Hex {
  const o = codec.normalizeArtistRecoveredHydrationOriginEnvironment(origin);
  const itemType = schemaType(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_BINDING_TUPLE).components!.find(c => c.name === "item")!;
  const b = codec.normalizeTuple(itemType.format("full"), value);
  if (typeof collectionId !== "bigint" || collectionId < 0n || collectionId >= 1n << 256n) throw Error("Expected collection uint256");
  return hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_BINDING_V1"), o.chainId, o.registry, o.core, collectionId, b.generation, b.artistId,
      b.artistAddress, b.identityRecordHash, b.consentMode, b.saleConsentScope, b.registryImmutabilityElection,
      hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), []]),
      hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []])]);
}

function collectionRows(index: ArtistHydrationOwnerIndex, s: ArtistRecoveredMultipleConsentHydrationState, p: shared.ArtistRecoveredHydrationOwnerProvenance): void {
  const commitment = codec.artistRecoveredHydrationOwnerProvenanceHash(p, index);
  const counts = p.eras.map(() => 0n);
  const era = (origin: Hex): number => {
    const at = p.eras.findIndex(e => e.originHash === origin);
    if (at < 0) throw Error("Unknown multiple row era");
    return at;
  };
  const guards = (j: shared.ArtistRecoveredHydrationJournalEntry, surface: Hex, expectedScope: Hex): void => {
    let scope = expectedScope;
    for (let e = era(j.position.point.environmentHash); e < p.eras.length; e++) {
      const aliases = p.aliases.filter(a => a.originHash === p.eras[e]!.originHash && a.surface === surface && a.cell.commitment === j.receipt.recordHash);
      if (aliases.length !== 1) throw Error("Incomplete multiple replay scope");
      const a = aliases[0]!;
      if (scope === Z) scope = a.scope;
      if (scope === Z || a.scope !== scope || a.cell.kind !== 1n || a.cell.status !== 2n
        || !same(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, a.admittedAt, j.position.point)) throw Error("Multiple replay chronology mismatch");
    }
  };
  let records = 0;
  if (index === 1) {
    if (p.journal.length || p.aliases.length) throw Error("Collaborator multiple graph unsupported");
    const o = p.origins[0]!, initial = p.eras[0]!.checkpoint.ownerState;
    for (const [domain, actual] of [["STATE", initial.stateRoot], ["RECORD", initial.recordChainTip]] as const) {
      if (actual !== hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32"],
        [id(`6529STREAM_ARTIST_OWNER_${domain}_GENESIS_V2`), o.chainId, o.registry, o.coordinator, o.archive, o.owners[1], codec.artistRecoveredHydrationOwnerDomain(1)])) {
        throw Error("Collaborator genesis mismatch");
      }
    }
  }
  for (let i = 0; i < s.rows.length; i++) {
    const q = s.collections[i]!;
    const scope = { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash };
    if (index === 0) {
      const b = decode<ArtistRecoveredMultipleConsentHydrationBinding>(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_BINDING_TUPLE, s.rows[i]!);
      const j = occurrence(p, q, 1n, q.bindingHash), e = era(j.position.point.environmentHash);
      counts[e] = counts[e]! + 1n; records++;
      const fields = schemaType(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_BINDING_TUPLE).components!;
      if (!same(fields[0]!.format("full"), b.scope, scope) || b.provenanceCommitment !== commitment
        || b.item.artistId !== q.artistId || b.item.bindingHash !== q.bindingHash || b.item.artistAddress === ZeroAddress
        || b.item.identityRecordHash === Z || b.item.proposer === ZeroAddress || b.item.generation !== 1n || !b.item.accepted
        || ![1n, 2n].includes(b.item.consentMode) || b.item.saleConsentScope > 1n || b.item.registryImmutabilityElection > 1n
        || !same(fields[2]!.format("full"), b.item, b.history) || b.terminal.kind !== 0n || b.terminal.reasonHash !== Z || b.terminal.recordHash !== Z
        || b.terms.count !== 0n || b.terms.mode !== 0n || b.terms.threshold !== 0n
        || b.terms.collaboratorSetHash !== hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), []])
        || b.terms.capabilityPolicySetHash !== hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []])
        || artistRecoveredMultipleConsentHydrationBindingHash(p.origins[e]!, q.collectionId, b.item) !== q.bindingHash) {
        throw Error("Multiple Binding requires accepted generation1 PRIMARY_ONLY without collaborators");
      }
      guards(j, id("binding_lifecycle.replay.proposal_key") as Hex, hash(["uint256", "uint64"], [q.collectionId, 1n]));
    } else if (index === 3) {
      const b = decode<ArtistRecoveredMultipleConsentHydrationAcceptance>(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ACCEPTANCE_TUPLE, s.rows[i]!);
      if (b.scope.artistId !== q.artistId || b.scope.collectionId !== q.collectionId || b.scope.bindingHash !== q.bindingHash
        || b.provenanceCommitment !== commitment || !b.acceptedAt || b.record === Z) throw Error("Multiple Acceptance scope mismatch");
      const j = occurrence(p, q, 2n, b.record), e = era(j.position.point.environmentHash);
      counts[e] = counts[e]! + 1n; records++;
      guards(j, id("acceptance_lifecycle.replay.record_uniqueness") as Hex, Z);
    } else if (index === 4) {
      const b = decode<ArtistRecoveredMultipleConsentHydrationAttribution>(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ATTRIBUTION_TUPLE, s.rows[i]!);
      if (b.state.provenance !== commitment || b.state.artistId !== q.artistId || b.state.collectionId !== q.collectionId
        || b.state.bindingHash !== q.bindingHash || b.state.item.state !== 2n || b.state.item.generation !== 1n) throw Error("Multiple Attribution must be accepted generation1");
      const e = era(b.proposalOrigin); counts[e] = counts[e]! + 1n;
    }
  }
  if (p.journal.length !== records || index === 4 && p.aliases.length) throw Error("Unexpected multiple collection native history");
  let total = 0n, aliases = 0n;
  for (let i = 0; i < p.eras.length; i++) {
    const e = p.eras[i]!, count = counts[i]!; total += count;
    const replay = index === 4 ? 0n : total;
    if (e.lowerRevision !== (i ? 1n : 0n) || e.nativeCount !== (index === 4 ? 0n : count)
      || e.checkpoint.ownerState.revision !== e.lowerRevision + (index === 0 || index === 4 ? 2n : 1n) * count
      || e.checkpoint.replayCount !== replay || !replay && e.checkpoint.replayRoot !== Z
      || e.checkpoint.nonceIndexCount !== 0n || e.checkpoint.nonceRoot !== Z) throw Error("Multiple owner global clocks/counts mismatch");
    aliases += replay;
  }
  if (BigInt(p.aliases.length) !== aliases) throw Error("Incomplete multiple collection aliases");
}

/** Original feature union. Advertisement supersets do not authorize new semantic profiles. */
export function artistRecoveredMultipleConsentHydrationRequiredFeatures(
  identities: readonly ArtistRecoveredMultipleConsentHydrationIdentity[],
  payouts: readonly ArtistRecoveredMultipleConsentHydrationPayout[], eraCount: bigint,
  bindings: readonly ArtistRecoveredMultipleConsentHydrationBinding[],
  contents: readonly ArtistRecoveredMultipleConsentHydrationContentBundle[],
): bigint {
  codec.boundedArray(identities, 128); codec.boundedArray(payouts, 128, identities.length);
  codec.boundedArray(bindings, 128); codec.boundedArray(contents, 128, bindings.length);
  if (!identities.length || !bindings.length || typeof eraCount !== "bigint" || eraCount < 1n || eraCount > 16n) throw Error("Invalid multiple consent feature scope");
  let result = 524288n;
  for (let i = 0; i < identities.length; i++) {
    const b = normalizeArtistRecoveredMultipleConsentHydrationIdentity(identities[i]!);
    const p = codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PAYOUT_TUPLE, payouts[i]!);
    if (b.artistId !== p.artistId) throw Error("Multiple recovered Artist/Payout partition mismatch");
    result |= codec.artistRecoveredHydrationRequiredFeatures({ currentAuthorityClass: b.identity.authorityClass,
      recoveryAuthorityClasses: b.recoveries.map(r => r.record.fields.vestedAuthorityClass),
      hasAdjudicationV2: b.actions.some(a => a.evidenceV2.manifestHash !== Z),
      hasRewindsV3: b.actions.some(a => a.evidenceV3.manifestHash !== Z) || !!(b.revisionContinuations.length
        + b.standingContinuations.length + b.capabilityContinuations.length + p.continuations.length),
      eraCount, economicsCount: 0n, hasDelegations: b.delegations.length !== 0, bindingConsentMode: 1n, saleConsentCount: 0n, attestationCount: 0n });
  }
  let economics = 0, royalties = 0;
  for (let i = 0; i < bindings.length; i++) {
    const binding = codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_BINDING_TUPLE, bindings[i]!);
    const b = normalizeArtistRecoveredMultipleConsentHydrationContentBundle(contents[i]!);
    if (![1n, 2n].includes(binding.item.consentMode) || binding.item.artistId !== b.original.artistId
      || binding.scope.collectionId !== b.original.collectionId || binding.item.bindingHash !== b.original.bindingHash) throw Error("Multiple feature collection mismatch");
    economics += b.original.economics.length; royalties += b.royalties.length;
    if (b.original.economics.length) result |= 32n;
    if (binding.item.consentMode === 2n || b.original.sales.length) result |= 64n;
    if (b.consents.length || b.royalties.length || b.freezes.length) result |= 256n;
  }
  if (economics > 128 || royalties > 128 || !(result & (32n | 64n | 256n))) throw Error("Original selection requires MULTIPLE_BASE, not MULTIPLE_CONSENTS");
  return result;
}

/** Checks canonical rows, closed profile, complete partitions and nonce union.
 * Full Identity/Payout record semantics and external authority remain the original producer's job.
 */
export function normalizeArtistRecoveredMultipleConsentHydrationPrepared(value: shared.ArtistRecoveredHydrationPrepared): shared.ArtistRecoveredHydrationPrepared {
  const p = codec.normalizeArtistRecoveredHydrationPrepared(value);
  validateSemanticGraph(p);
  return p;
}

function validateSemanticGraph(p: Pick<shared.ArtistRecoveredHydrationPrepared, "query" | "data" | "timing"> & {
  readonly admission: Pick<shared.ArtistRecoveredHydrationCertificate, "artists" | "collections" | "provenance">;
}): void {
  const states: ArtistRecoveredMultipleConsentHydrationState[] = [];
  const identities: ArtistRecoveredMultipleConsentHydrationIdentity[] = [], payouts: ArtistRecoveredMultipleConsentHydrationPayout[] = [];
  let features = 0n;
  for (let owner = 0; owner < 7; owner++) {
    const index = owner as ArtistHydrationOwnerIndex;
    const { header, payload } = decodeArtistRecoveredMultipleConsentHydrationOwnerPayload(p.data[index].typedState, index);
    const s = decodeArtistRecoveredMultipleConsentHydrationState(payload.semanticState, index, payload.provenance);
    if (!same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.artists, p.admission.artists)
      || !same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.collections, p.admission.collections)
      || !same(ARTIST_HYDRATION_QUERY_TUPLE, artistRecoveredMultipleConsentHydrationAnchor(s), p.query)) throw Error("Multiple owner scope differs from full certificate");
    states.push(s); features = header.requiredFeatures;
    if (index === 2) {
      artistRecoveredMultipleConsentHydrationNonceUnion(s, payload.nonces, payload.provenance.eras.at(-1)!.checkpoint);
      for (let i = 0; i < s.rows.length; i++) {
        const b = decodeArtistRecoveredMultipleConsentHydrationIdentity(s.rows[i]!);
        if (!b.recoveries.length || b.identity.status === 0n || ![1n, 3n].includes(b.identity.authorityClass)
          || !same(ARTIST_HYDRATION_SNAPSHOT_TUPLE, b.sourceSnapshot, payload.provenance.eras.at(-1)!.checkpoint.ownerState)
          || !same(shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, b.timing.checkpoint, p.timing)) throw Error("Multiple Identity requires retained class1/3 recovery and global source clock");
        const rows = payload.provenance.journal.filter(j => j.receipt.artistId === b.artistId);
        if (rows.filter(j => j.receipt.operation === 35n).length !== b.recoveries.length * 2
          || rows.some(j => [44n, 45n, 46n, 47n, 49n, 50n, 59n].includes(j.receipt.operation))) throw Error("Unsupported multiple Identity journal profile");
        identities.push(b);
      }
    } else if (index === 5) {
      for (let i = 0; i < s.rows.length; i++) {
        const b = decodeArtistRecoveredMultipleConsentHydrationPayout(s.rows[i]!);
        if (b.artistId !== s.artists[i]!.artistId
          || !same(ARTIST_HYDRATION_SNAPSHOT_TUPLE, b.sourceSnapshot, payload.provenance.eras.at(-1)!.checkpoint.ownerState)
          || payload.provenance.journal.some(j => j.receipt.operation !== 18n || j.receipt.collectionId !== 0n)) throw Error("Multiple Payout scope mismatch");
        const rows = payload.provenance.journal.filter(j => j.receipt.artistId === b.artistId);
        if (rows.length !== b.records.length || b.records.some((r, j) => r.original.recordHash !== rows[j]!.receipt.recordHash
          || r.original.terms.artistId !== b.artistId || ![1n, 3n].includes(r.original.authorityClass)
          || !same(shared.ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE, r.position, rows[j]!.position))) throw Error("Multiple Payout occurrence mismatch");
        payouts.push(b);
      }
    } else if (index !== 6) collectionRows(index, s, payload.provenance);
  }
  for (let i = 0; i < p.admission.collections.length; i++) {
    const q = p.admission.collections[i]!;
    const binding = occurrence(codec.artistRecoveredHydrationOwnerProvenance(p.admission.provenance, 0), q, 1n, q.bindingHash);
    const accepted = decode<ArtistRecoveredMultipleConsentHydrationAcceptance>(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ACCEPTANCE_TUPLE, states[3]!.rows[i]!);
    const acceptance = occurrence(codec.artistRecoveredHydrationOwnerProvenance(p.admission.provenance, 3), q, 2n, accepted.record);
    const attribution = decode<ArtistRecoveredMultipleConsentHydrationAttribution>(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ATTRIBUTION_TUPLE, states[4]!.rows[i]!);
    if (binding.position.point.environmentHash !== acceptance.position.point.environmentHash
      || attribution.proposalOrigin !== binding.position.point.environmentHash) throw Error("Multiple proposal/acceptance/attribution origin mismatch");
  }
  const bindings = states[0]!.rows.map(raw => decode<ArtistRecoveredMultipleConsentHydrationBinding>(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_BINDING_TUPLE, raw));
  const contents = states[6]!.rows.map(decodeArtistRecoveredMultipleConsentHydrationContentBundle);
  validateArtistRecoveredMultipleConsentHydrationGrantUses(identities, p.admission.collections, contents, bindings, p.admission.provenance);
  if (features !== artistRecoveredMultipleConsentHydrationRequiredFeatures(identities, payouts, BigInt(p.admission.provenance.eras.length), bindings, contents)) {
    throw Error("Multiple required features differ from original Identity union");
  }
}

export function encodeArtistRecoveredMultipleConsentHydrationPrepared(value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.encodeArtistRecoveredHydrationPrepared(normalizeArtistRecoveredMultipleConsentHydrationPrepared(value));
}
export function decodeArtistRecoveredMultipleConsentHydrationPrepared(raw: Hex): shared.ArtistRecoveredHydrationPrepared {
  preflight([shared.ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE], raw, shared.ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES);
  return normalizeArtistRecoveredMultipleConsentHydrationPrepared(codec.decodeArtistRecoveredHydrationPrepared(raw));
}
export function artistRecoveredMultipleConsentHydrationSemanticInventory(value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.artistRecoveredHydrationSemanticInventory(normalizeArtistRecoveredMultipleConsentHydrationPrepared(value));
}
export function artistRecoveredMultipleConsentHydrationCommitment(c: shared.ArtistRecoveredHydrationCoordinates, request: shared.ArtistRecoveredHydrationRequest, value: shared.ArtistRecoveredHydrationPrepared): Hex {
  const p = normalizeArtistRecoveredMultipleConsentHydrationPrepared(value);
  validateEconomicsRows(request, p.data[6].typedState);
  return codec.artistRecoveredHydrationCommitment(c, request, p);
}
export function encodeArtistRecoveredMultipleConsentHydrationProfileEvidence(request: shared.ArtistRecoveredHydrationRequest, value: shared.ArtistRecoveredHydrationPrepared): Hex {
  const p = normalizeArtistRecoveredMultipleConsentHydrationPrepared(value);
  validateEconomicsRows(request, p.data[6].typedState);
  return codec.encodeArtistRecoveredHydrationProfileEvidence(request, p);
}

export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_VALIDATION = Object.freeze({
  canonicalRowsChecked: true, completeProvenanceAndNoncePartitionChecked: true,
  consentPartitionsAndRetainedGrantUsesChecked: true, signatureExecutionIndependentlyVerified: false,
  completeIdentityAndPayoutSemanticsIndependentlyVerified: false,
  sourceAdmissionIndependentlyVerified: false, actualRegistrySimulationRequired: true,
});

export function decodeArtistRecoveredMultipleConsentHydrationRequest(raw: Hex): shared.ArtistRecoveredHydrationRequest {
  preflight([shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE], raw);
  return codec.decodeArtistRecoveredHydrationRequest(raw);
}

/** Retained evidence has no destination before-state or live suite. It proves these
 * supplied partitions and commitments, not the original preparation admission. */
export function decodeArtistRecoveredMultipleConsentHydrationProfileEvidence(raw: Hex): shared.ArtistRecoveredHydrationProfileEvidence {
  const types = ["bytes32", "uint16", "address", "address", shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE,
    `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, ARTIST_HYDRATION_QUERY_TUPLE,
    `${ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`,
    shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, shared.ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE];
  preflight(types, raw);
  const e = codec.decodeArtistRecoveredHydrationProfileEvidence(raw);
  codec.normalizeArtistRecoveredHydrationRequest(e.request);
  const locals = e.data.map((d, i) => decodeArtistRecoveredMultipleConsentHydrationOwnerPayload(d.typedState, i as ArtistHydrationOwnerIndex));
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
    const s = decodeArtistRecoveredMultipleConsentHydrationState(local.payload.semanticState, index, local.payload.provenance);
    if (!same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.artists, e.artists) || !same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.collections, e.collections)
      || !same(ARTIST_HYDRATION_QUERY_TUPLE, artistRecoveredMultipleConsentHydrationAnchor(s), e.query)) throw Error("Evidence owner partitions differ");
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
  validateEconomicsRows(e.request, e.data[6].typedState);
  return e;
}

export interface ArtistRecoveredMultipleConsentHydrationRoyaltyFreeze {
  readonly resolver: Address;
  readonly collectionId: bigint;
  readonly revenueClass: Hex;
  readonly expectedAssignmentHash: Hex;
}

export interface ArtistRecoveredMultipleConsentHydrationInput {
  readonly request: shared.ArtistRecoveredHydrationRequest;
  readonly royaltyFreezes: readonly ArtistRecoveredMultipleConsentHydrationRoyaltyFreeze[];
}

export interface ArtistRecoveredMultipleConsentHydrationCall {
  readonly registry: Address;
  readonly caller: Address;
  readonly request: shared.ArtistRecoveredHydrationRequest;
  readonly royaltyFreezes: readonly ArtistRecoveredMultipleConsentHydrationRoyaltyFreeze[];
  readonly profile: Hex;
  readonly capabilityId: Hex;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export interface ArtistRecoveredMultipleConsentHydrationContentTerms {
  readonly collectionId: bigint;
  readonly metadataContract: Address;
  readonly familyId: Hex;
  readonly newStateHash: Hex;
}

export interface ArtistRecoveredMultipleConsentHydrationContentRecord {
  readonly recordHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly terms: ArtistRecoveredMultipleConsentHydrationContentTerms;
  readonly authorityClass: bigint;
}

export interface ArtistRecoveredMultipleConsentHydrationRoyaltyRecord {
  readonly recordHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
}

export interface ArtistRecoveredMultipleConsentHydrationRoyalty {
  readonly terms: ArtistRecoveredMultipleConsentHydrationRoyaltyFreeze;
  readonly item: ArtistRecoveredMultipleConsentHydrationRoyaltyRecord;
  readonly grant: Hex;
}

export interface ArtistRecoveredMultipleConsentHydrationFreezeRecord {
  readonly recordHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly metadataContract: Address;
  readonly lockClasses: readonly Hex[];
  readonly expectedStateHash: Hex;
  readonly authorityClass: bigint;
}

export interface ArtistRecoveredMultipleConsentHydrationEconomicsAssociation {
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly payloadHash: Hex;
  readonly originalRecord: Hex;
}

export interface ArtistRecoveredMultipleConsentHydrationEconomics {
  readonly item: {
    readonly recordHash: Hex;
    readonly terms: shared.ArtistRecoveredHydrationEconomicsConsent;
    readonly association: ArtistRecoveredMultipleConsentHydrationEconomicsAssociation;
  };
  readonly grant: Hex;
}

export interface ArtistRecoveredMultipleConsentHydrationOriginalBundle {
  readonly provenance: Hex;
  readonly artistId: Hex;
  readonly collectionId: bigint;
  readonly bindingHash: Hex;
  readonly keys: readonly ArtistHydrationPolicyKey[];
  readonly policies: readonly { readonly recordHash: Hex; readonly grant: Hex }[];
  readonly economics: readonly ArtistRecoveredMultipleConsentHydrationEconomics[];
  readonly sales: readonly ArtistHydrationSale[];
}

export interface ArtistRecoveredMultipleConsentHydrationContentBundle {
  readonly original: ArtistRecoveredMultipleConsentHydrationOriginalBundle;
  readonly consents: readonly ArtistRecoveredMultipleConsentHydrationContentRecord[];
  readonly royalties: readonly ArtistRecoveredMultipleConsentHydrationRoyalty[];
  readonly freezes: readonly ArtistRecoveredMultipleConsentHydrationFreezeRecord[];
}

export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE = "tuple(address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash)";
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CONTENT_TERMS_TUPLE = "tuple(uint256 collectionId,address metadataContract,bytes32 familyId,bytes32 newStateHash)";
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CONTENT_RECORD_TUPLE = `tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CONTENT_TERMS_TUPLE} terms,uint8 authorityClass)`;
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_RECORD_TUPLE = "tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration)";
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_TUPLE = `tuple(${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE} terms,${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_RECORD_TUPLE} item,bytes32 grant)`;
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_FREEZE_RECORD_TUPLE = "tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,address metadataContract,bytes32[] lockClasses,bytes32 expectedStateHash,uint8 authorityClass)";
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ECONOMICS_ASSOCIATION_TUPLE = "tuple(bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 payloadHash,bytes32 originalRecord)";
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ECONOMICS_TUPLE = `tuple(tuple(bytes32 recordHash,${shared.ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE} terms,${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ECONOMICS_ASSOCIATION_TUPLE} association) item,bytes32 grant)`;
const saleTuple = "tuple(tuple(bytes32 recordHash,tuple(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash) terms,bytes32 artistId,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,uint64 bindingGeneration,bytes32 bindingHash) item,bytes32 grant,bytes32 current)";
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ORIGINAL_BUNDLE_TUPLE = `tuple(bytes32 provenance,bytes32 artistId,uint256 collectionId,bytes32 bindingHash,${ARTIST_HYDRATION_POLICY_TUPLE}[] keys,tuple(bytes32 recordHash,bytes32 grant)[] policies,${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ECONOMICS_TUPLE}[] economics,${saleTuple}[] sales)`;
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CONTENT_BUNDLE_TUPLE = `tuple(${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ORIGINAL_BUNDLE_TUPLE} original,${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CONTENT_RECORD_TUPLE}[] consents,${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_TUPLE}[] royalties,${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_FREEZE_RECORD_TUPLE}[] freezes)`;


function saleLookup(terms: ArtistHydrationSale["item"]["terms"]): Hex {
  return hash(["uint256", "bytes32", "bytes32"], [terms.collectionId, terms.saleId, terms.saleConfigHash]);
}

function validateBaseRows(value: ArtistRecoveredMultipleConsentHydrationOriginalBundle): void {
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
  const payloads = new Set<Hex>();
  for (const { item: row } of value.economics) {
    const t = row.terms;
    const a = row.association;
    if (row.recordHash === Z || t.collectionId !== value.collectionId || t.resolver === ZeroAddress || t.revenueClass === Z
      || t.scope > 2n || t.scope === 0n && (t.scopeId !== 0n || t.assignmentHash === Z)
      || t.scope === 1n && t.scopeId !== value.collectionId || t.scope === 2n && t.scopeId === 0n
      || a.artistId !== value.artistId || a.bindingGeneration !== 1n || a.bindingHash !== value.bindingHash
      || a.payloadHash !== hash([shared.ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE], [t]) || a.originalRecord !== row.recordHash
      || economicRecords.has(row.recordHash) || payloads.has(a.payloadHash)) throw Error("Invalid original economics row");
    economicRecords.add(row.recordHash); payloads.add(a.payloadHash);
  }
  const saleRecords = new Set<Hex>();
  const saleTerms = new Set<Hex>();
  for (let i = 0; i < value.sales.length; i++) {
    const row = value.sales[i]!;
    const r = row.item;
    const termsHash = hash(["tuple(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash)"], [r.terms]);
    if (r.recordHash === Z || r.artistId !== value.artistId || r.terms.collectionId !== value.collectionId
      || r.terms.saleAdapter === ZeroAddress || r.terms.saleId === Z || r.terms.saleConfigHash === Z
      || r.signer === ZeroAddress || !r.signedAt || r.bindingGeneration !== 1n || r.bindingHash !== value.bindingHash
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

function validateContentRows(value: ArtistRecoveredMultipleConsentHydrationContentBundle): void {
  const original = value.original;
  for (const r of value.consents) {
    if (r.recordHash === Z || r.artistId !== original.artistId || r.bindingGeneration !== 1n
      || r.authorityClass !== 1n && r.authorityClass !== 3n || r.terms.collectionId !== original.collectionId
      || r.terms.metadataContract === ZeroAddress || r.terms.familyId === Z || r.terms.newStateHash === Z) {
      throw Error("Invalid retained content consent");
    }
  }
  normalizeArtistRecoveredMultipleConsentHydrationRoyaltyFreezes(value.royalties.map(row => row.terms), original.collectionId);
  for (const row of value.royalties) {
    if (row.item.recordHash === Z || row.item.artistId !== original.artistId || row.item.bindingGeneration !== 1n) {
      throw Error("Invalid retained royalty-freeze record");
    }
  }
  for (const r of value.freezes) {
    if (r.recordHash === Z || r.artistId !== original.artistId || r.bindingGeneration !== 1n
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
export const CURRENT_ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ABI = Object.freeze([
  ...codec.CURRENT_ARTIST_RECOVERED_HYDRATION_ABI,
  `function hydrateRecoveredArtistAuthorityWithConsents(${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE}[] royaltyFreezes) returns(bytes32)`,
]);
const registryInterface = new Interface(CURRENT_ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ABI);
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CAPABILITY_ID = codec.ARTIST_RECOVERED_HYDRATION_CAPABILITY_ID;
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_WITH_CONSENTS_CAPABILITY_ID = registryInterface.getFunction("hydrateRecoveredArtistAuthorityWithConsents")!.selector as Hex;
/** Original compiler nominal library identifiers, never expanded tuple selectors. */
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PREPARE_SELECTOR = "0x72c84763" as Hex;
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PREPARE_WITH_CONSENTS_SELECTOR = "0x4925300f" as Hex;
export const ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PREPARE_ABI = Object.freeze([
  ...codec.ARTIST_RECOVERED_HYDRATION_PREPARE_ABI,
  `function prepare(${ARTIST_HYDRATION_SUITE_TUPLE} destination,${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE}[] royaltyFreezes) view returns(${shared.ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE} prepared)`,
]);

export function normalizeArtistRecoveredMultipleConsentHydrationRoyaltyFreezes(
  value: readonly ArtistRecoveredMultipleConsentHydrationRoyaltyFreeze[], collectionId?: bigint,
): readonly ArtistRecoveredMultipleConsentHydrationRoyaltyFreeze[] {
  codec.boundedArray(value, 128);
  const rows = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE}[]`, value);
  const seen = new Set<Hex>();
  for (const row of rows) {
    const key = hash([ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE], [row]);
    if (!row.collectionId || collectionId !== undefined && row.collectionId !== collectionId
      || row.resolver === ZeroAddress || row.revenueClass !== id("ROYALTY_ERC2981")
      || row.expectedAssignmentHash === Z || seen.has(key)) throw Error("Invalid or duplicate original royalty selector");
    seen.add(key);
  }
  return rows;
}
export function normalizeArtistRecoveredMultipleConsentHydrationInputDraft(value: ArtistRecoveredMultipleConsentHydrationInput): ArtistRecoveredMultipleConsentHydrationInput {
  codec.exactFields(value, ["request", "royaltyFreezes"]);
  const request = codec.normalizeArtistRecoveredHydrationRequestDraft(value.request);
  const royaltyFreezes = normalizeArtistRecoveredMultipleConsentHydrationRoyaltyFreezes(value.royaltyFreezes);
  if (royaltyFreezes.some(r => !request.records.authority.collections.some(c => c.collectionId === r.collectionId))) throw Error("Royalty selector outside complete collection selection");
  return Object.freeze({ request, royaltyFreezes });
}
export function normalizeArtistRecoveredMultipleConsentHydrationInput(value: ArtistRecoveredMultipleConsentHydrationInput): ArtistRecoveredMultipleConsentHydrationInput {
  const input = normalizeArtistRecoveredMultipleConsentHydrationInputDraft(value);
  codec.normalizeArtistRecoveredHydrationRequest(input.request);
  return input;
}
export function prepareArtistRecoveredMultipleConsentHydrationCall(registry: Address, caller: Address, value: ArtistRecoveredMultipleConsentHydrationInput): ArtistRecoveredMultipleConsentHydrationCall {
  const target = getAddress(registry) as Address, actor = getAddress(caller) as Address;
  if (target === ZeroAddress || actor === ZeroAddress) throw Error("Expected actual Registry and caller");
  const input = normalizeArtistRecoveredMultipleConsentHydrationInput(value);
  const withConsents = input.royaltyFreezes.length !== 0;
  const method = withConsents ? "hydrateRecoveredArtistAuthorityWithConsents" : "hydrateRecoveredArtistAuthority";
  const data = codec.boundedBytes(registryInterface.encodeFunctionData(method, withConsents ? [input.request, input.royaltyFreezes] : [input.request]));
  return Object.freeze({ registry: target, caller: actor, ...input, profile: shared.ARTIST_RECOVERED_HYDRATION_PROFILE,
    capabilityId: registryInterface.getFunction(method)!.selector as Hex,
    call: Object.freeze({ to: target, value: 0n, data }), factsVerified: false });
}
export function normalizeArtistRecoveredMultipleConsentHydrationCall(value: ArtistRecoveredMultipleConsentHydrationCall): ArtistRecoveredMultipleConsentHydrationCall {
  codec.exactFields(value, ["registry", "caller", "request", "royaltyFreezes", "profile", "capabilityId", "call", "factsVerified"]);
  codec.exactFields(value.call, ["to", "value", "data"]);
  const rebuilt = prepareArtistRecoveredMultipleConsentHydrationCall(value.registry, value.caller, { request: value.request, royaltyFreezes: value.royaltyFreezes });
  if (value.profile !== rebuilt.profile || value.capabilityId !== rebuilt.capabilityId || value.factsVerified !== false
    || getAddress(value.call.to) !== rebuilt.call.to || value.call.value !== 0n || codec.boundedBytes(value.call.data) !== rebuilt.call.data) throw Error("Multiple consent call differs from immutable input");
  return rebuilt;
}
export function artistRecoveredMultipleConsentHydrationPreparationCalldata(destination: ArtistHydrationSuite, value: ArtistRecoveredMultipleConsentHydrationInput): Hex {
  const input = normalizeArtistRecoveredMultipleConsentHydrationInputDraft(value);
  if (!input.royaltyFreezes.length) return codec.artistRecoveredHydrationPreparationCalldata(destination, input.request);
  const suite = codec.normalizeTuple(ARTIST_HYDRATION_SUITE_TUPLE, destination);
  const data = codec.encodeTupleValues([ARTIST_HYDRATION_SUITE_TUPLE, shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE,
    `${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE}[]`], [suite, input.request, input.royaltyFreezes]);
  return codec.boundedBytes(`${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PREPARE_WITH_CONSENTS_SELECTOR}${data.slice(2)}`);
}

/** Raw canonical per-collection row. Complete whole-owner validation is separate. */
export function normalizeArtistRecoveredMultipleConsentHydrationContentBundle(value: ArtistRecoveredMultipleConsentHydrationContentBundle): ArtistRecoveredMultipleConsentHydrationContentBundle {
  return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CONTENT_BUNDLE_TUPLE, value);
}
export function encodeArtistRecoveredMultipleConsentHydrationContentBundle(value: ArtistRecoveredMultipleConsentHydrationContentBundle): Hex {
  return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CONTENT_BUNDLE_TUPLE], [normalizeArtistRecoveredMultipleConsentHydrationContentBundle(value)]);
}
export function decodeArtistRecoveredMultipleConsentHydrationContentBundle(raw: Hex): ArtistRecoveredMultipleConsentHydrationContentBundle {
  return decode(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CONTENT_BUNDLE_TUPLE, raw);
}
export function artistRecoveredMultipleConsentHydrationContentScope(terms: ArtistRecoveredMultipleConsentHydrationContentTerms): Hex {
  return hash([ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CONTENT_TERMS_TUPLE, "uint64"],
    [codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CONTENT_TERMS_TUPLE, terms), 1n]);
}
export function artistRecoveredMultipleConsentHydrationRoyaltyScope(terms: ArtistRecoveredMultipleConsentHydrationRoyaltyFreeze, artistId: Hex): Hex {
  return hash([ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE, "bytes32", "uint64"],
    [codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE, terms), codec.boundedBytes(artistId, 32), 1n]);
}
const replaySurfaces = Object.freeze({ policy: id("consent_finality.replay.policy_consent_key"), economics: id("consent_finality.replay.consent_key"),
  sale: id("consent_finality.replay.sale_consent_key"), content: id("consent_finality.replay.content_consent_key"), freeze: id("consent_finality.replay.freeze_key") });

/** Full journal stays unfiltered; only per-family cursors are partitioned by collection. */
export function validateArtistRecoveredMultipleConsentHydrationContentBundles(
  values: readonly ArtistRecoveredMultipleConsentHydrationContentBundle[], queries: readonly ArtistHydrationQuery[],
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): readonly ArtistRecoveredMultipleConsentHydrationContentBundle[] {
  codec.boundedArray(values, 128); codec.boundedArray(queries, 128, values.length);
  if (!values.length) throw Error("Empty multiple consent collection partition");
  const all = Object.freeze(values.map(normalizeArtistRecoveredMultipleConsentHydrationContentBundle));
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
    validateBaseRows(o); validateContentRows(b);
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
      record = v.recordHash; surface = replaySurfaces.economics; scope = v.association.payloadHash;
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
      record = v.recordHash; surface = replaySurfaces.content; scope = hash(["bytes32", "bytes32"], [artistRecoveredMultipleConsentHydrationContentScope(v.terms), record]);
    } else if (r.operation === 20n) {
      const v = b.royalties[cursor.royalties++]; if (!v) throw Error("Missing royalty occurrence");
      record = v.item.recordHash; surface = replaySurfaces.freeze; scope = artistRecoveredMultipleConsentHydrationRoyaltyScope(v.terms, o.artistId);
    } else if (r.operation === 21n) {
      const v = b.freezes[cursor.freezes++]; if (!v) throw Error("Missing freeze occurrence");
      record = v.recordHash; surface = replaySurfaces.freeze; scope = hash(["bytes32", "uint256", "uint64", "bytes32"], [id("CONTENT"), o.collectionId, 1n, record]);
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

export function artistRecoveredMultipleConsentHydrationDelegateLane(artistId: Hex, delegate: Address): Hex {
  return hash(["bytes32", "bytes32", "address"], [id("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), codec.boundedBytes(artistId, 32), getAddress(delegate)]);
}
export function artistRecoveredMultipleConsentHydrationGrantRecordHash(
  origin: shared.ArtistRecoveredHydrationOriginEnvironment,
  value: ArtistRecoveredMultipleConsentHydrationIdentity["delegations"][number]["record"],
): Hex {
  const o = codec.normalizeArtistRecoveredHydrationOriginEnvironment(origin);
  const r = normalizeDelegationRecord(value), g = r.grant;
  return hash(["bytes32", "uint256", "address", "bytes32", "address", "uint256", "uint32", "uint64", "uint64", "uint64", "bytes32", "uint256"],
    [id("6529STREAM_ARTIST_DELEGATION_RECORD_V1"), o.chainId, o.registry, g.artistId, g.delegate, g.collectionId, g.capabilities, g.notBefore, g.expiresAt, g.maxUses, g.constraintsHash, r.nonce]);
}
const delegationRecordType = "tuple(tuple(bytes32 artistId,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash) grant,address grantor,uint256 nonce,uint256 uses,bool revoked,bytes32 revocationRecordHash)";
function normalizeDelegationRecord(value: ArtistRecoveredMultipleConsentHydrationIdentity["delegations"][number]["record"]) {
  return codec.normalizeTuple(delegationRecordType, value);
}
export function artistRecoveredMultipleConsentHydrationGrantDigest(origin: shared.ArtistRecoveredHydrationOriginEnvironment,
  value: ArtistRecoveredMultipleConsentHydrationIdentity["delegations"][number]["record"]): Hex {
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
export function validateArtistRecoveredMultipleConsentHydrationDelegations(
  value: ArtistRecoveredMultipleConsentHydrationIdentity, provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistRecoveredMultipleConsentHydrationIdentity {
  const b = normalizeArtistRecoveredMultipleConsentHydrationIdentity(value), p = codec.normalizeArtistRecoveredHydrationOwnerProvenance(provenance, 2);
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
    if (artistRecoveredMultipleConsentHydrationGrantRecordHash(o, r) !== d.recordHash) throw Error("Original delegation record preimage mismatch");
    const digest = artistRecoveredMultipleConsentHydrationGrantDigest(o, r);
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
      const uses = b.delegations.filter(d => artistRecoveredMultipleConsentHydrationDelegateLane(b.artistId, d.record.grant.delegate) === n.key).reduce((sum, d) => sum + d.record.uses, 0n);
      if (!uses || consumed !== uses) throw Error("Delegate nonce bits differ from complete grant uses");
    }
  }
  for (const d of b.delegations) if (d.record.uses && !b.nonces.some(n => n.kind === 2n && n.key === artistRecoveredMultipleConsentHydrationDelegateLane(b.artistId, d.record.grant.delegate))) throw Error("Missing used delegate nonce lane");
  return b;
}

/** Reconcile every retained grant once across every selected collection and supported family. */
export function validateArtistRecoveredMultipleConsentHydrationGrantUses(
  identities: readonly ArtistRecoveredMultipleConsentHydrationIdentity[], collections: readonly ArtistHydrationQuery[],
  values: readonly ArtistRecoveredMultipleConsentHydrationContentBundle[], bindings: readonly ArtistRecoveredMultipleConsentHydrationBinding[],
  provenance: shared.ArtistRecoveredHydrationProvenance,
): void {
  codec.boundedArray(identities, 128); codec.boundedArray(collections, 128); codec.boundedArray(values, 128, collections.length); codec.boundedArray(bindings, 128, collections.length);
  const p = codec.normalizeArtistRecoveredHydrationProvenance(provenance), ip = codec.artistRecoveredHydrationOwnerProvenance(p, 2), cp = codec.artistRecoveredHydrationOwnerProvenance(p, 6);
  const qs = codec.normalizeTuple(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, collections);
  const rows = validateArtistRecoveredMultipleConsentHydrationContentBundles(values, qs, cp);
  const bs = codec.normalizeTuple(`${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_BINDING_TUPLE}[]`, bindings);
  const artists = identities.map(v => validateArtistRecoveredMultipleConsentHydrationDelegations(v, ip));
  if (new Set(artists.map(v => v.artistId)).size !== artists.length || qs.some(q => !artists.some(a => a.artistId === q.artistId))) throw Error("Incomplete grant Artist partition");
  for (const identity of artists) {
    const total = identity.delegations.map(() => 0n);
    for (let c = 0; c < qs.length; c++) {
      const q = qs[c]!; if (q.artistId !== identity.artistId) continue;
      const b = rows[c]!, binding = bs[c]!.item;
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
        if (binding.consentMode !== 2n) throw Error("Delegated policy requires mode2");
        use(r.grant, 2n, r.recordHash);
      }
      for (const r of b.original.economics) if (r.grant !== Z) use(r.grant, 4n, r.item.recordHash);
      for (const r of b.original.sales) if (r.grant !== Z) {
        if (binding.consentMode !== 2n) throw Error("Delegated sale requires mode2");
        const at = use(r.grant, 1024n, r.item.recordHash), d = identity.delegations[at]!;
        if (r.item.authorityClass !== 2n || r.item.signer !== d.record.grant.delegate) throw Error("Sale delegate identity mismatch");
        const sale = cp.journal.find(j => j.receipt.recordHash === r.item.recordHash)!;
        const scope = hash(["bytes32", "uint256"], [artistRecoveredMultipleConsentHydrationDelegateLane(identity.artistId, d.record.grant.delegate), r.item.nonce]);
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
export function validateArtistRecoveredMultipleConsentHydrationInput(
  value: ArtistRecoveredMultipleConsentHydrationInput, prepared: shared.ArtistRecoveredHydrationPrepared,
): ArtistRecoveredMultipleConsentHydrationInput {
  const input = normalizeArtistRecoveredMultipleConsentHydrationInput(value);
  const p = normalizeArtistRecoveredMultipleConsentHydrationPrepared(prepared);
  codec.encodeArtistRecoveredHydrationProfileEvidence(input.request, p);
  const { payload } = decodeArtistRecoveredMultipleConsentHydrationOwnerPayload(p.data[6].typedState, 6);
  const state = decodeArtistRecoveredMultipleConsentHydrationState(payload.semanticState, 6, payload.provenance);
  const all = state.rows.map(decodeArtistRecoveredMultipleConsentHydrationContentBundle);
  validateEconomicsRows(input.request, p.data[6].typedState);
  const terms: ArtistRecoveredMultipleConsentHydrationRoyaltyFreeze[] = [];
  for (const j of payload.provenance.journal) if (j.receipt.operation === 20n) {
    const b = all.find(v => v.original.collectionId === j.receipt.collectionId && v.original.artistId === j.receipt.artistId)!;
    const row = b.royalties.find(r => r.item.recordHash === j.receipt.recordHash);
    if (!row) throw Error("Missing original royalty occurrence");
    terms.push(row.terms);
  }
  if (!same(`${ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE}[]`, input.royaltyFreezes, terms)) throw Error("Royalty selectors differ from original global operation20 order");
  return input;
}

function validateEconomicsRows(request: shared.ArtistRecoveredHydrationRequest, raw: Hex): void {
  const r = codec.normalizeArtistRecoveredHydrationRequest(request);
  const { payload } = decodeArtistRecoveredMultipleConsentHydrationOwnerPayload(raw, 6);
  const state = decodeArtistRecoveredMultipleConsentHydrationState(payload.semanticState, 6, payload.provenance);
  const economic = state.rows.map(decodeArtistRecoveredMultipleConsentHydrationContentBundle).filter(b => b.original.economics.length);
  if (economic.length !== r.records.witnesses.length) throw Error("Incomplete economics witness selection");
  for (let i = 0; i < economic.length; i++) {
    const b = economic[i]!, w = r.records.witnesses[i]!;
    if (w.collectionId !== b.original.collectionId || w.attestations.length
      || !same(`${shared.ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE}[]`, w.economics, b.original.economics.map(row => row.item.terms))) throw Error("Economics witnesses differ from original collection occurrence order");
  }
}
