import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { ArtistHydrationOwnerIndex, ArtistHydrationQuery, ArtistHydrationSuite } from "./current-artist-authority-hydration.js";
import { ARTIST_HYDRATION_SUITE_TUPLE, ARTIST_HYDRATION_QUERY_TUPLE, ARTIST_HYDRATION_POLICY_TUPLE, ARTIST_HYDRATION_OWNER_DATA_TUPLE, ARTIST_HYDRATION_CHECKPOINT_TUPLE, ARTIST_HYDRATION_SNAPSHOT_TUPLE } from "./current-artist-authority-hydration.js";
import type { UnsignedCall } from "./binding.js";
import * as shared from "./internal/artist-recovered-hydration-codec.js";
import { ARTIST_COMPLETE_HISTORY_TUPLES as T } from "./generated/artist-complete-history.js";
import type { ArtistCompleteHistoryTypes as Types } from "./generated/artist-complete-history.js";

export const ARTIST_COMPLETE_HISTORY_HYDRATION_SOURCE = "5104c901b5bb348829c62a5638291c1bf2fb0e5b";
export const ARTIST_COMPLETE_HISTORY_HYDRATION_BASE = 33554432n;
export const ARTIST_COMPLETE_HISTORY_HYDRATION_ALLOWED_FEATURES = 33816575n;
export const ARTIST_COMPLETE_HISTORY_HYDRATION_KNOWN_FEATURES = 67108863n;
export const ARTIST_COMPLETE_HISTORY_HYDRATION_SCHEMA = id("6529STREAM_ARTIST_COMPLETE_HISTORY_V1") as Hex;
export const ARTIST_COMPLETE_HISTORY_HYDRATION_SUPPLEMENT_SCHEMA = id("6529STREAM_ARTIST_AGGREGATE_CONSENT_SUPPLEMENT_V1") as Hex;
export const ARTIST_COMPLETE_HISTORY_HYDRATION_VALIDATION = Object.freeze({
  canonicalCarriersChecked: true, suppliedScopeAndOwnerJoinsChecked: true,
  originalCompositionAdmissionIndependentlyVerified: false,
  originalArchiveReadbackIndependentlyVerified: false,
  completeIdentityAndPayoutSemanticsIndependentlyVerified: false,
  signatureExecutionIndependentlyVerified: false, sourceAdmissionIndependentlyVerified: false,
  actualRegistrySimulationRequired: true,
});

export type {
  ArtistRecoveredHydrationCapability as ArtistCompleteHistoryHydrationCapability,
  ArtistRecoveredHydrationEconomicsConsent as ArtistCompleteHistoryHydrationEconomicsConsent,
  ArtistRecoveredHydrationAttestation as ArtistCompleteHistoryHydrationAttestation,
  ArtistRecoveredHydrationAttestationInput as ArtistCompleteHistoryHydrationAttestationInput,
  ArtistRecoveredHydrationCollectionWitness as ArtistCompleteHistoryHydrationCollectionWitness,
  ArtistRecoveredHydrationRecordsRequest as ArtistCompleteHistoryHydrationRecordsRequest,
  ArtistRecoveredHydrationRequest as ArtistCompleteHistoryHydrationRequest,
  ArtistRecoveredHydrationExportHeader as ArtistCompleteHistoryHydrationExportHeader,
  ArtistRecoveredHydrationOriginEnvironment as ArtistCompleteHistoryHydrationOriginEnvironment,
  ArtistRecoveredHydrationEra as ArtistCompleteHistoryHydrationEra,
  ArtistRecoveredHydrationPoint as ArtistCompleteHistoryHydrationPoint,
  ArtistRecoveredHydrationPosition as ArtistCompleteHistoryHydrationPosition,
  ArtistRecoveredHydrationJournalEntry as ArtistCompleteHistoryHydrationJournalEntry,
  ArtistRecoveredHydrationReplayAlias as ArtistCompleteHistoryHydrationReplayAlias,
  ArtistRecoveredHydrationProvenance as ArtistCompleteHistoryHydrationProvenance,
  ArtistRecoveredHydrationOwnerEra as ArtistCompleteHistoryHydrationOwnerEra,
  ArtistRecoveredHydrationOwnerProvenance as ArtistCompleteHistoryHydrationOwnerProvenance,
  ArtistRecoveredHydrationNonceInventory as ArtistCompleteHistoryHydrationNonceInventory,
  ArtistRecoveredHydrationEnvelope as ArtistCompleteHistoryHydrationEnvelope,
  ArtistRecoveredHydrationPublication as ArtistCompleteHistoryHydrationPublication,
  ArtistRecoveredHydrationOwnerPayload as ArtistCompleteHistoryHydrationOwnerPayload,
  ArtistRecoveredHydrationTimingConfiguration as ArtistCompleteHistoryHydrationTimingConfiguration,
  ArtistRecoveredHydrationTimingInput as ArtistCompleteHistoryHydrationTimingInput,
  ArtistRecoveredHydrationTimingEntry as ArtistCompleteHistoryHydrationTimingEntry,
  ArtistRecoveredHydrationTimingCheckpoint as ArtistCompleteHistoryHydrationTimingCheckpoint,
  ArtistRecoveredHydrationTimingBundle as ArtistCompleteHistoryHydrationTimingBundle,
  ArtistRecoveredHydrationActionWitness as ArtistCompleteHistoryHydrationActionWitness,
  ArtistRecoveredHydrationActionFacts as ArtistCompleteHistoryHydrationActionFacts,
  ArtistRecoveredHydrationActionGuard as ArtistCompleteHistoryHydrationActionGuard,
  ArtistRecoveredHydrationFinalityScope as ArtistCompleteHistoryHydrationFinalityScope,
  ArtistRecoveredHydrationFinalityComponent as ArtistCompleteHistoryHydrationFinalityComponent,
  ArtistRecoveredHydrationFinalityManifest as ArtistCompleteHistoryHydrationFinalityManifest,
  ArtistRecoveredHydrationFinalityEvidence as ArtistCompleteHistoryHydrationFinalityEvidence,
  ArtistRecoveredHydrationFinalityRecord as ArtistCompleteHistoryHydrationFinalityRecord,
  ArtistRecoveredHydrationFinalityTarget as ArtistCompleteHistoryHydrationFinalityTarget,
  ArtistRecoveredHydrationFinalityGuard as ArtistCompleteHistoryHydrationFinalityGuard,
  ArtistRecoveredHydrationEntropyReceipt as ArtistCompleteHistoryHydrationEntropyReceipt,
  ArtistRecoveredHydrationEntropyEvidence as ArtistCompleteHistoryHydrationEntropyEvidence,
  ArtistRecoveredHydrationEntropyGuard as ArtistCompleteHistoryHydrationEntropyGuard,
  ArtistRecoveredHydrationExternalGuards as ArtistCompleteHistoryHydrationExternalGuards,
  ArtistRecoveredHydrationCertificate as ArtistCompleteHistoryHydrationCertificate,
  ArtistRecoveredHydrationPrepared as ArtistCompleteHistoryHydrationPrepared,
  ArtistRecoveredHydrationEvidenceDescriptor as ArtistCompleteHistoryHydrationEvidenceDescriptor,
  ArtistRecoveredHydrationCoordinates as ArtistCompleteHistoryHydrationCoordinates,
  ArtistRecoveredHydrationProfileEvidence as ArtistCompleteHistoryHydrationProfileEvidence,
  ArtistRecoveredHydrationOperationEvidence as ArtistCompleteHistoryHydrationOperationEvidence,
  ArtistRecoveredHydrationHistoricalCell as ArtistCompleteHistoryHydrationHistoricalCell,
  ArtistRecoveredHydrationFeatureFacts as ArtistCompleteHistoryHydrationFeatureFacts
} from "./internal/artist-recovered-hydration-codec.js";

export {
  ARTIST_RECOVERED_HYDRATION_PROFILE as ARTIST_COMPLETE_HISTORY_HYDRATION_PROFILE,
  ARTIST_RECOVERED_HYDRATION_PAGE_BYTES as ARTIST_COMPLETE_HISTORY_HYDRATION_PAGE_BYTES,
  ARTIST_RECOVERED_HYDRATION_MAX_BYTES as ARTIST_COMPLETE_HISTORY_HYDRATION_MAX_BYTES,
  ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES as ARTIST_COMPLETE_HISTORY_HYDRATION_MAX_PREPARED_BYTES,
  ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA as ARTIST_COMPLETE_HISTORY_HYDRATION_CHECKPOINT_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_PAYLOAD_SCHEMA as ARTIST_COMPLETE_HISTORY_HYDRATION_PAYLOAD_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_EVIDENCE_SCHEMA as ARTIST_COMPLETE_HISTORY_HYDRATION_EVIDENCE_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_CAPABILITY_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_CAPABILITY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_ECONOMICS_CONSENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ATTESTATION_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_ATTESTATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ATTESTATION_INPUT_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_ATTESTATION_INPUT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_COLLECTION_WITNESS_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_COLLECTION_WITNESS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_RECORDS_REQUEST_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_RECORDS_REQUEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_REQUEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EXPORT_HEADER_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_EXPORT_HEADER_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ERA_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_ERA_TUPLE,
  ARTIST_RECOVERED_HYDRATION_POINT_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_POINT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_POSITION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_JOURNAL_ENTRY_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_JOURNAL_ENTRY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_REPLAY_ALIAS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PROVENANCE_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_PROVENANCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_ERA_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_OWNER_ERA_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_OWNER_PROVENANCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_NONCE_INVENTORY_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_NONCE_INVENTORY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_ENVELOPE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PUBLICATION_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_PUBLICATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_PAYLOAD_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_OWNER_PAYLOAD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_CONFIGURATION_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_TIMING_CONFIGURATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_INPUT_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_TIMING_INPUT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_ENTRY_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_TIMING_ENTRY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_TIMING_CHECKPOINT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_BUNDLE_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_TIMING_BUNDLE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_WITNESS_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_ACTION_WITNESS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_FACTS_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_ACTION_FACTS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_GUARD_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_ACTION_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_SCOPE_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_FINALITY_SCOPE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_COMPONENT_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_FINALITY_COMPONENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_MANIFEST_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_FINALITY_MANIFEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_EVIDENCE_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_FINALITY_EVIDENCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_RECORD_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_FINALITY_RECORD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_TARGET_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_FINALITY_TARGET_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_GUARD_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_FINALITY_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_RECEIPT_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_ENTROPY_RECEIPT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_EVIDENCE_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_ENTROPY_EVIDENCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_GUARD_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_ENTROPY_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_EXTERNAL_GUARDS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_CERTIFICATE_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_CERTIFICATE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_PREPARED_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE as ARTIST_COMPLETE_HISTORY_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE
} from "./internal/artist-recovered-hydration-codec.js";

const codec = shared.createArtistRecoveredHydrationCodec(33816575n);
export const {
  artistRecoveredHydrationOwnerDomain: artistCompleteHistoryHydrationOwnerDomain,
  artistRecoveredHydrationOwnerTag: artistCompleteHistoryHydrationOwnerTag,
  normalizeArtistRecoveredHydrationCoordinates: normalizeArtistCompleteHistoryHydrationCoordinates,
  normalizeArtistRecoveredHydrationCapability: normalizeArtistCompleteHistoryHydrationCapability,
  validateArtistRecoveredHydrationCapability: validateArtistCompleteHistoryHydrationCapability,
  normalizeArtistRecoveredHydrationRequestDraft: normalizeArtistCompleteHistoryHydrationRequestDraft,
  normalizeArtistRecoveredHydrationRequest: normalizeArtistCompleteHistoryHydrationRequest,
  encodeArtistRecoveredHydrationRequest: encodeArtistCompleteHistoryHydrationRequest,
  normalizeArtistRecoveredHydrationOriginEnvironment: normalizeArtistCompleteHistoryHydrationOriginEnvironment,
  artistRecoveredHydrationOriginHash: artistCompleteHistoryHydrationOriginHash,
  artistRecoveredHydrationReplayKey: artistCompleteHistoryHydrationReplayKey,
  normalizeArtistRecoveredHydrationOwnerProvenance: normalizeArtistCompleteHistoryHydrationOwnerProvenance,
  artistRecoveredHydrationOwnerProvenance: artistCompleteHistoryHydrationOwnerProvenance,
  normalizeArtistRecoveredHydrationProvenance: normalizeArtistCompleteHistoryHydrationProvenance,
  artistRecoveredHydrationProvenanceHash: artistCompleteHistoryHydrationProvenanceHash,
  artistRecoveredHydrationOwnerProvenanceHash: artistCompleteHistoryHydrationOwnerProvenanceHash,
  artistRecoveredHydrationAliasesHash: artistCompleteHistoryHydrationAliasesHash,
  compareArtistRecoveredHydrationPoints: compareArtistCompleteHistoryHydrationPoints,
  normalizeArtistRecoveredHydrationNonceInventory: normalizeArtistCompleteHistoryHydrationNonceInventory,
  normalizeArtistRecoveredHydrationPublications: normalizeArtistCompleteHistoryHydrationPublications,
  normalizeArtistRecoveredHydrationTimingCheckpoint: normalizeArtistCompleteHistoryHydrationTimingCheckpoint,
  normalizeArtistRecoveredHydrationExternalGuards: normalizeArtistCompleteHistoryHydrationExternalGuards,
  normalizeArtistRecoveredHydrationEvidenceDescriptor: normalizeArtistCompleteHistoryHydrationEvidenceDescriptor,
  artistRecoveredHydrationEvidenceDescriptor: artistCompleteHistoryHydrationEvidenceDescriptor,
  artistRecoveredHydrationEvidencePages: artistCompleteHistoryHydrationEvidencePages,
  assembleArtistRecoveredHydrationEvidence: assembleArtistCompleteHistoryHydrationEvidence,
  artistRecoveredHydrationPageId: artistCompleteHistoryHydrationPageId,
  artistRecoveredHydrationEvidenceId: artistCompleteHistoryHydrationEvidenceId,
  encodeArtistRecoveredHydrationEvidenceCarrier: encodeArtistCompleteHistoryHydrationEvidenceCarrier,
  decodeArtistRecoveredHydrationEvidenceCarrier: decodeArtistCompleteHistoryHydrationEvidenceCarrier,
  encodeArtistRecoveredHydrationOperationEvidence: encodeArtistCompleteHistoryHydrationOperationEvidence,
  decodeArtistRecoveredHydrationOperationEvidence: decodeArtistCompleteHistoryHydrationOperationEvidence,
  artistRecoveredHydrationOwnerReplayDelta: artistCompleteHistoryHydrationOwnerReplayDelta,
  artistRecoveredHydrationOwnerAfter: artistCompleteHistoryHydrationOwnerAfter
} = codec;


// Genuine ABI198 structural schemas; admission is separate from raw canonical codecs.
export type ArtistCompleteHistoryHydrationState = Types["StreamArtistRecoveredMultipleTypes.State"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_STATE_TUPLE = T["StreamArtistRecoveredMultipleTypes.State"];
export type ArtistCompleteHistoryHydrationInventory = Types["StreamArtistCompleteHistoryTypes.Inventory"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_INVENTORY_TUPLE = T["StreamArtistCompleteHistoryTypes.Inventory"];
export type ArtistCompleteHistoryHydrationPrincipals = Types["StreamArtistCompleteHistoryTypes.Principals"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_PRINCIPALS_TUPLE = T["StreamArtistCompleteHistoryTypes.Principals"];
export type ArtistCompleteHistoryHydrationBindingInventory = Types["StreamArtistPrimaryCollaboratorTypes.BindingInventory"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_BINDING_INVENTORY_TUPLE = T["StreamArtistPrimaryCollaboratorTypes.BindingInventory"];
export type ArtistCompleteHistoryHydrationArchiveInventory = Types["StreamArtistPrimaryCollaboratorTypes.Inventory"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_INVENTORY_TUPLE = T["StreamArtistPrimaryCollaboratorTypes.Inventory"];
export type ArtistCompleteHistoryHydrationProposal = Types["StreamArtistPrimaryCollaboratorTypes.Proposal"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_PROPOSAL_TUPLE = T["StreamArtistPrimaryCollaboratorTypes.Proposal"];
export type ArtistCompleteHistoryHydrationAcceptedRow = Types["StreamArtistPrimaryCollaboratorTypes.AcceptedRow"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_ACCEPTED_ROW_TUPLE = T["StreamArtistPrimaryCollaboratorTypes.AcceptedRow"];
export type ArtistCompleteHistoryHydrationPrimaryReceipt = Types["StreamArtistPrimaryCollaboratorTypes.PrimaryReceipt"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_PRIMARY_RECEIPT_TUPLE = T["StreamArtistPrimaryCollaboratorTypes.PrimaryReceipt"];
export type ArtistCompleteHistoryHydrationClocksResult = Types["StreamArtistPrimaryCollaboratorClocks.Result"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_CLOCKS_RESULT_TUPLE = T["StreamArtistPrimaryCollaboratorClocks.Result"];
export type ArtistCompleteHistoryHydrationBindingBundle = Types["StreamArtistRecoveredBindingCorrectionTypes.Bundle"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_BINDING_BUNDLE_TUPLE = T["StreamArtistRecoveredBindingCorrectionTypes.Bundle"];
export type ArtistCompleteHistoryHydrationAcceptanceBundle = Types["StreamArtistRecoveredAcceptedGenerationTypes.AcceptanceBundle"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_ACCEPTANCE_BUNDLE_TUPLE = T["StreamArtistRecoveredAcceptedGenerationTypes.AcceptanceBundle"];
export type ArtistCompleteHistoryHydrationGeneration = Types["StreamArtistRecoveredAcceptedGenerationTypes.Generation"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_GENERATION_TUPLE = T["StreamArtistRecoveredAcceptedGenerationTypes.Generation"];
export type ArtistCompleteHistoryHydrationPlatform = Types["StreamArtistRecoveredPlatformTypes.Platform"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_PLATFORM_TUPLE = T["StreamArtistRecoveredPlatformTypes.Platform"];
export type ArtistCompleteHistoryHydrationArchiveOperation = Types["StreamArtistRecoveredSanctionHistoryTypes.OperationEvidence"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_OPERATION_TUPLE = T["StreamArtistRecoveredSanctionHistoryTypes.OperationEvidence"];
export type ArtistCompleteHistoryHydrationArchiveEnvelope = Types["StreamArtistRecoveredSanctionHistoryTypes.Envelope"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_ENVELOPE_TUPLE = T["StreamArtistRecoveredSanctionHistoryTypes.Envelope"];
export type ArtistCompleteHistoryHydrationCatalogue = Types["StreamArtistRecoveredPlatformTypes.Catalogue"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_CATALOGUE_TUPLE = T["StreamArtistRecoveredPlatformTypes.Catalogue"];
export type ArtistCompleteHistoryHydrationIdentity = Types["StreamArtistRecoveredIdentityHydrationTypes.Bundle"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_IDENTITY_TUPLE = T["StreamArtistRecoveredIdentityHydrationTypes.Bundle"];
export type ArtistCompleteHistoryHydrationPayout = Types["StreamArtistRecoveredPayoutTypes.Bundle"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_PAYOUT_TUPLE = T["StreamArtistRecoveredPayoutTypes.Bundle"];
export type ArtistCompleteHistoryHydrationConsents = Types["StreamArtistRecoveredMultipleGenerationTypes.Consents"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_CONSENTS_TUPLE = T["StreamArtistRecoveredMultipleGenerationTypes.Consents"];
export type ArtistCompleteHistoryHydrationConsentsSupplement = Types["StreamArtistAggregateConsentSupplementTypes.Bundle"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_CONSENTS_SUPPLEMENT_TUPLE = T["StreamArtistAggregateConsentSupplementTypes.Bundle"];
export type ArtistCompleteHistoryHydrationAttributionHistory = Types["StreamArtistRecoveredDisputeHistoryTypes.Bundle"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_ATTRIBUTION_HISTORY_TUPLE = T["StreamArtistRecoveredDisputeHistoryTypes.Bundle"];
export type ArtistCompleteHistoryHydrationAttestationBundle = Types["StreamArtistRecoveredAttestationHydration.Bundle"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_ATTESTATION_BUNDLE_TUPLE = T["StreamArtistRecoveredAttestationHydration.Bundle"];
export type ArtistCompleteHistoryHydrationSanctionInventory = Types["StreamArtistRecoveredSanctionHistoryTypes.Inventory"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_SANCTION_INVENTORY_TUPLE = T["StreamArtistRecoveredSanctionHistoryTypes.Inventory"];
export type ArtistCompleteHistoryHydrationCredentialHead = Types["StreamArtistC2PATypes.Head"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_CREDENTIAL_HEAD_TUPLE = T["StreamArtistC2PATypes.Head"];
export type ArtistCompleteHistoryHydrationCredentialPayload = Types["StreamArtistC2PATypes.Payload"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_CREDENTIAL_PAYLOAD_TUPLE = T["StreamArtistC2PATypes.Payload"];
export type ArtistCompleteHistoryHydrationPersonhoodSummary = Types["StreamArtistPersonhoodTypes.Summary"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_PERSONHOOD_SUMMARY_TUPLE = T["StreamArtistPersonhoodTypes.Summary"];
export type ArtistCompleteHistoryHydrationNonceLane = Types["StreamArtistRecoveredIdentityHydrationTypes.NonceLane"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_NONCE_LANE_TUPLE = T["StreamArtistRecoveredIdentityHydrationTypes.NonceLane"];
export type ArtistCompleteHistoryHydrationRoyaltyFreeze = Types["StreamArtistOnboardingTypes.RoyaltyFreeze"];
export const ARTIST_COMPLETE_HISTORY_HYDRATION_ROYALTY_FREEZE_TUPLE = T["StreamArtistOnboardingTypes.RoyaltyFreeze"];
export interface ArtistCompleteHistoryHydrationAttribution { readonly history: ArtistCompleteHistoryHydrationAttributionHistory; readonly records: ArtistCompleteHistoryHydrationAttestationBundle; }
// Exact source-defined wrapper; nested members have compiler witnesses.
export const ARTIST_COMPLETE_HISTORY_HYDRATION_ATTRIBUTION_TUPLE = `tuple(${ARTIST_COMPLETE_HISTORY_HYDRATION_ATTRIBUTION_HISTORY_TUPLE} history,${ARTIST_COMPLETE_HISTORY_HYDRATION_ATTESTATION_BUNDLE_TUPLE} records)`;
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
const stateType = schemaType(ARTIST_COMPLETE_HISTORY_HYDRATION_STATE_TUPLE);
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

export function normalizeArtistCompleteHistoryHydrationState(value: ArtistCompleteHistoryHydrationState): ArtistCompleteHistoryHydrationState { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_STATE_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationStateTuple(value: ArtistCompleteHistoryHydrationState): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_STATE_TUPLE], [normalizeArtistCompleteHistoryHydrationState(value)]); }
export function decodeArtistCompleteHistoryHydrationStateTuple(raw: Hex): ArtistCompleteHistoryHydrationState { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_STATE_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationInventory(value: ArtistCompleteHistoryHydrationInventory): ArtistCompleteHistoryHydrationInventory { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_INVENTORY_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationInventory(value: ArtistCompleteHistoryHydrationInventory): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_INVENTORY_TUPLE], [normalizeArtistCompleteHistoryHydrationInventory(value)]); }
export function decodeArtistCompleteHistoryHydrationInventory(raw: Hex): ArtistCompleteHistoryHydrationInventory { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_INVENTORY_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationPrincipals(value: ArtistCompleteHistoryHydrationPrincipals): ArtistCompleteHistoryHydrationPrincipals { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_PRINCIPALS_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationPrincipals(value: ArtistCompleteHistoryHydrationPrincipals): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_PRINCIPALS_TUPLE], [normalizeArtistCompleteHistoryHydrationPrincipals(value)]); }
export function decodeArtistCompleteHistoryHydrationPrincipals(raw: Hex): ArtistCompleteHistoryHydrationPrincipals { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_PRINCIPALS_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationBindingInventory(value: ArtistCompleteHistoryHydrationBindingInventory): ArtistCompleteHistoryHydrationBindingInventory { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_BINDING_INVENTORY_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationBindingInventory(value: ArtistCompleteHistoryHydrationBindingInventory): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_BINDING_INVENTORY_TUPLE], [normalizeArtistCompleteHistoryHydrationBindingInventory(value)]); }
export function decodeArtistCompleteHistoryHydrationBindingInventory(raw: Hex): ArtistCompleteHistoryHydrationBindingInventory { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_BINDING_INVENTORY_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationArchiveInventory(value: ArtistCompleteHistoryHydrationArchiveInventory): ArtistCompleteHistoryHydrationArchiveInventory { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_INVENTORY_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationArchiveInventory(value: ArtistCompleteHistoryHydrationArchiveInventory): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_INVENTORY_TUPLE], [normalizeArtistCompleteHistoryHydrationArchiveInventory(value)]); }
export function decodeArtistCompleteHistoryHydrationArchiveInventory(raw: Hex): ArtistCompleteHistoryHydrationArchiveInventory { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_INVENTORY_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationProposal(value: ArtistCompleteHistoryHydrationProposal): ArtistCompleteHistoryHydrationProposal { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_PROPOSAL_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationProposal(value: ArtistCompleteHistoryHydrationProposal): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_PROPOSAL_TUPLE], [normalizeArtistCompleteHistoryHydrationProposal(value)]); }
export function decodeArtistCompleteHistoryHydrationProposal(raw: Hex): ArtistCompleteHistoryHydrationProposal { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_PROPOSAL_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationAcceptedRow(value: ArtistCompleteHistoryHydrationAcceptedRow): ArtistCompleteHistoryHydrationAcceptedRow { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_ACCEPTED_ROW_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationAcceptedRow(value: ArtistCompleteHistoryHydrationAcceptedRow): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_ACCEPTED_ROW_TUPLE], [normalizeArtistCompleteHistoryHydrationAcceptedRow(value)]); }
export function decodeArtistCompleteHistoryHydrationAcceptedRow(raw: Hex): ArtistCompleteHistoryHydrationAcceptedRow { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_ACCEPTED_ROW_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationPrimaryReceipt(value: ArtistCompleteHistoryHydrationPrimaryReceipt): ArtistCompleteHistoryHydrationPrimaryReceipt { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_PRIMARY_RECEIPT_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationPrimaryReceipt(value: ArtistCompleteHistoryHydrationPrimaryReceipt): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_PRIMARY_RECEIPT_TUPLE], [normalizeArtistCompleteHistoryHydrationPrimaryReceipt(value)]); }
export function decodeArtistCompleteHistoryHydrationPrimaryReceipt(raw: Hex): ArtistCompleteHistoryHydrationPrimaryReceipt { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_PRIMARY_RECEIPT_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationClocksResult(value: ArtistCompleteHistoryHydrationClocksResult): ArtistCompleteHistoryHydrationClocksResult { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_CLOCKS_RESULT_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationClocksResult(value: ArtistCompleteHistoryHydrationClocksResult): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_CLOCKS_RESULT_TUPLE], [normalizeArtistCompleteHistoryHydrationClocksResult(value)]); }
export function decodeArtistCompleteHistoryHydrationClocksResult(raw: Hex): ArtistCompleteHistoryHydrationClocksResult { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_CLOCKS_RESULT_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationBindingBundle(value: ArtistCompleteHistoryHydrationBindingBundle): ArtistCompleteHistoryHydrationBindingBundle { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_BINDING_BUNDLE_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationBindingBundle(value: ArtistCompleteHistoryHydrationBindingBundle): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_BINDING_BUNDLE_TUPLE], [normalizeArtistCompleteHistoryHydrationBindingBundle(value)]); }
export function decodeArtistCompleteHistoryHydrationBindingBundle(raw: Hex): ArtistCompleteHistoryHydrationBindingBundle { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_BINDING_BUNDLE_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationAcceptanceBundle(value: ArtistCompleteHistoryHydrationAcceptanceBundle): ArtistCompleteHistoryHydrationAcceptanceBundle { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_ACCEPTANCE_BUNDLE_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationAcceptanceBundle(value: ArtistCompleteHistoryHydrationAcceptanceBundle): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_ACCEPTANCE_BUNDLE_TUPLE], [normalizeArtistCompleteHistoryHydrationAcceptanceBundle(value)]); }
export function decodeArtistCompleteHistoryHydrationAcceptanceBundle(raw: Hex): ArtistCompleteHistoryHydrationAcceptanceBundle { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_ACCEPTANCE_BUNDLE_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationGeneration(value: ArtistCompleteHistoryHydrationGeneration): ArtistCompleteHistoryHydrationGeneration { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_GENERATION_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationGeneration(value: ArtistCompleteHistoryHydrationGeneration): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_GENERATION_TUPLE], [normalizeArtistCompleteHistoryHydrationGeneration(value)]); }
export function decodeArtistCompleteHistoryHydrationGeneration(raw: Hex): ArtistCompleteHistoryHydrationGeneration { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_GENERATION_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationPlatform(value: ArtistCompleteHistoryHydrationPlatform): ArtistCompleteHistoryHydrationPlatform { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_PLATFORM_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationPlatform(value: ArtistCompleteHistoryHydrationPlatform): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_PLATFORM_TUPLE], [normalizeArtistCompleteHistoryHydrationPlatform(value)]); }
export function decodeArtistCompleteHistoryHydrationPlatform(raw: Hex): ArtistCompleteHistoryHydrationPlatform { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_PLATFORM_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationArchiveOperation(value: ArtistCompleteHistoryHydrationArchiveOperation): ArtistCompleteHistoryHydrationArchiveOperation { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_OPERATION_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationArchiveOperation(value: ArtistCompleteHistoryHydrationArchiveOperation): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_OPERATION_TUPLE], [normalizeArtistCompleteHistoryHydrationArchiveOperation(value)]); }
export function decodeArtistCompleteHistoryHydrationArchiveOperation(raw: Hex): ArtistCompleteHistoryHydrationArchiveOperation { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_OPERATION_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationCatalogue(value: ArtistCompleteHistoryHydrationCatalogue): ArtistCompleteHistoryHydrationCatalogue { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_CATALOGUE_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationCatalogue(value: ArtistCompleteHistoryHydrationCatalogue): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_CATALOGUE_TUPLE], [normalizeArtistCompleteHistoryHydrationCatalogue(value)]); }
export function decodeArtistCompleteHistoryHydrationCatalogue(raw: Hex): ArtistCompleteHistoryHydrationCatalogue { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_CATALOGUE_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationIdentity(value: ArtistCompleteHistoryHydrationIdentity): ArtistCompleteHistoryHydrationIdentity { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_IDENTITY_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationIdentity(value: ArtistCompleteHistoryHydrationIdentity): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_IDENTITY_TUPLE], [normalizeArtistCompleteHistoryHydrationIdentity(value)]); }
export function decodeArtistCompleteHistoryHydrationIdentity(raw: Hex): ArtistCompleteHistoryHydrationIdentity { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_IDENTITY_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationConsents(value: ArtistCompleteHistoryHydrationConsents): ArtistCompleteHistoryHydrationConsents { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_CONSENTS_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationConsents(value: ArtistCompleteHistoryHydrationConsents): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_CONSENTS_TUPLE], [normalizeArtistCompleteHistoryHydrationConsents(value)]); }
export function decodeArtistCompleteHistoryHydrationConsents(raw: Hex): ArtistCompleteHistoryHydrationConsents { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_CONSENTS_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationAttributionHistory(value: ArtistCompleteHistoryHydrationAttributionHistory): ArtistCompleteHistoryHydrationAttributionHistory { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_ATTRIBUTION_HISTORY_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationAttributionHistory(value: ArtistCompleteHistoryHydrationAttributionHistory): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_ATTRIBUTION_HISTORY_TUPLE], [normalizeArtistCompleteHistoryHydrationAttributionHistory(value)]); }
export function decodeArtistCompleteHistoryHydrationAttributionHistory(raw: Hex): ArtistCompleteHistoryHydrationAttributionHistory { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_ATTRIBUTION_HISTORY_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationAttestationBundle(value: ArtistCompleteHistoryHydrationAttestationBundle): ArtistCompleteHistoryHydrationAttestationBundle { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_ATTESTATION_BUNDLE_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationAttestationBundle(value: ArtistCompleteHistoryHydrationAttestationBundle): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_ATTESTATION_BUNDLE_TUPLE], [normalizeArtistCompleteHistoryHydrationAttestationBundle(value)]); }
export function decodeArtistCompleteHistoryHydrationAttestationBundle(raw: Hex): ArtistCompleteHistoryHydrationAttestationBundle { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_ATTESTATION_BUNDLE_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationSanctionInventory(value: ArtistCompleteHistoryHydrationSanctionInventory): ArtistCompleteHistoryHydrationSanctionInventory { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_SANCTION_INVENTORY_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationSanctionInventory(value: ArtistCompleteHistoryHydrationSanctionInventory): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_SANCTION_INVENTORY_TUPLE], [normalizeArtistCompleteHistoryHydrationSanctionInventory(value)]); }
export function decodeArtistCompleteHistoryHydrationSanctionInventory(raw: Hex): ArtistCompleteHistoryHydrationSanctionInventory { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_SANCTION_INVENTORY_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationCredentialHead(value: ArtistCompleteHistoryHydrationCredentialHead): ArtistCompleteHistoryHydrationCredentialHead { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_CREDENTIAL_HEAD_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationCredentialHead(value: ArtistCompleteHistoryHydrationCredentialHead): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_CREDENTIAL_HEAD_TUPLE], [normalizeArtistCompleteHistoryHydrationCredentialHead(value)]); }
export function decodeArtistCompleteHistoryHydrationCredentialHead(raw: Hex): ArtistCompleteHistoryHydrationCredentialHead { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_CREDENTIAL_HEAD_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationCredentialPayload(value: ArtistCompleteHistoryHydrationCredentialPayload): ArtistCompleteHistoryHydrationCredentialPayload { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_CREDENTIAL_PAYLOAD_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationCredentialPayload(value: ArtistCompleteHistoryHydrationCredentialPayload): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_CREDENTIAL_PAYLOAD_TUPLE], [normalizeArtistCompleteHistoryHydrationCredentialPayload(value)]); }
export function decodeArtistCompleteHistoryHydrationCredentialPayload(raw: Hex): ArtistCompleteHistoryHydrationCredentialPayload { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_CREDENTIAL_PAYLOAD_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationPersonhoodSummary(value: ArtistCompleteHistoryHydrationPersonhoodSummary): ArtistCompleteHistoryHydrationPersonhoodSummary { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_PERSONHOOD_SUMMARY_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationPersonhoodSummary(value: ArtistCompleteHistoryHydrationPersonhoodSummary): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_PERSONHOOD_SUMMARY_TUPLE], [normalizeArtistCompleteHistoryHydrationPersonhoodSummary(value)]); }
export function decodeArtistCompleteHistoryHydrationPersonhoodSummary(raw: Hex): ArtistCompleteHistoryHydrationPersonhoodSummary { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_PERSONHOOD_SUMMARY_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationNonceLane(value: ArtistCompleteHistoryHydrationNonceLane): ArtistCompleteHistoryHydrationNonceLane { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_NONCE_LANE_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationNonceLane(value: ArtistCompleteHistoryHydrationNonceLane): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_NONCE_LANE_TUPLE], [normalizeArtistCompleteHistoryHydrationNonceLane(value)]); }
export function decodeArtistCompleteHistoryHydrationNonceLane(raw: Hex): ArtistCompleteHistoryHydrationNonceLane { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_NONCE_LANE_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationRoyaltyFreeze(value: ArtistCompleteHistoryHydrationRoyaltyFreeze): ArtistCompleteHistoryHydrationRoyaltyFreeze { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_ROYALTY_FREEZE_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationRoyaltyFreeze(value: ArtistCompleteHistoryHydrationRoyaltyFreeze): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_ROYALTY_FREEZE_TUPLE], [normalizeArtistCompleteHistoryHydrationRoyaltyFreeze(value)]); }
export function decodeArtistCompleteHistoryHydrationRoyaltyFreeze(raw: Hex): ArtistCompleteHistoryHydrationRoyaltyFreeze { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_ROYALTY_FREEZE_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationAttribution(value: ArtistCompleteHistoryHydrationAttribution): ArtistCompleteHistoryHydrationAttribution { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_ATTRIBUTION_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationAttribution(value: ArtistCompleteHistoryHydrationAttribution): Hex { return codec.encodeTupleValues([ARTIST_COMPLETE_HISTORY_HYDRATION_ATTRIBUTION_TUPLE], [normalizeArtistCompleteHistoryHydrationAttribution(value)]); }
export function decodeArtistCompleteHistoryHydrationAttribution(raw: Hex): ArtistCompleteHistoryHydrationAttribution { return decode(ARTIST_COMPLETE_HISTORY_HYDRATION_ATTRIBUTION_TUPLE, raw); }

function flatEncode(tuple: string, value: unknown): Hex {
  const v = codec.normalizeTuple(tuple, value) as Record<string, unknown>;
  const fields = schemaType(tuple).components!;
  return codec.encodeTupleValues(fields.map(t => t.format("full")), fields.map(t => v[t.name]));
}
function flatDecode<TValue>(tuple: string, raw: Hex): TValue {
  const fields = schemaType(tuple).components!, types = fields.map(t => t.format("full"));
  const input = preflight(types, raw), result = coder.decode(fields, input);
  if (coder.encode(fields, result) !== input) throw Error("Noncanonical complete-history flat carrier");
  return codec.normalizeTuple(tuple, Object.fromEntries(fields.map((t, i) => [t.name, plain(t, result[i])]))) as TValue;
}
export function normalizeArtistCompleteHistoryHydrationArchiveEnvelope(value: ArtistCompleteHistoryHydrationArchiveEnvelope): ArtistCompleteHistoryHydrationArchiveEnvelope { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_ENVELOPE_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationArchiveEnvelope(value: ArtistCompleteHistoryHydrationArchiveEnvelope): Hex { return flatEncode(ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_ENVELOPE_TUPLE, value); }
export function decodeArtistCompleteHistoryHydrationArchiveEnvelope(raw: Hex): ArtistCompleteHistoryHydrationArchiveEnvelope { return flatDecode(ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_ENVELOPE_TUPLE, raw); }
export function normalizeArtistCompleteHistoryHydrationPayout(value: ArtistCompleteHistoryHydrationPayout): ArtistCompleteHistoryHydrationPayout { return codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_PAYOUT_TUPLE, value); }
export function encodeArtistCompleteHistoryHydrationPayout(value: ArtistCompleteHistoryHydrationPayout): Hex {
  return codec.encodeTupleValues(["bytes32", ARTIST_COMPLETE_HISTORY_HYDRATION_PAYOUT_TUPLE], [payoutSchema, normalizeArtistCompleteHistoryHydrationPayout(value)]);
}
export function decodeArtistCompleteHistoryHydrationPayout(raw: Hex): ArtistCompleteHistoryHydrationPayout {
  const types = ["bytes32", ARTIST_COMPLETE_HISTORY_HYDRATION_PAYOUT_TUPLE], input = preflight(types, raw), result = coder.decode(types.map(schemaType), input);
  if (result[0] !== payoutSchema || coder.encode(types.map(schemaType), result) !== input) throw Error("Noncanonical complete-history Payout");
  return normalizeArtistCompleteHistoryHydrationPayout(plain(schemaType(types[1]!), result[1]) as ArtistCompleteHistoryHydrationPayout);
}
export function normalizeArtistCompleteHistoryHydrationConsentsSupplement(value: ArtistCompleteHistoryHydrationConsentsSupplement): ArtistCompleteHistoryHydrationConsentsSupplement {
  const v = codec.normalizeTuple(ARTIST_COMPLETE_HISTORY_HYDRATION_CONSENTS_SUPPLEMENT_TUPLE, value);
  if (v.ratifications.length > 128) throw Error("Ratification inventory exceeds original capacity");
  if (v.sanctionInventory !== "0x") decodeArtistCompleteHistoryHydrationSanctionInventory(v.sanctionInventory);
  return v;
}
export function encodeArtistCompleteHistoryHydrationConsentsSupplement(value: ArtistCompleteHistoryHydrationConsentsSupplement): Hex {
  const v = normalizeArtistCompleteHistoryHydrationConsentsSupplement(value);
  return !v.ratifications.length && v.sanctionInventory === "0x" ? encodeArtistCompleteHistoryHydrationConsents(v.original)
    : codec.encodeTupleValues(["bytes32", "uint16", ARTIST_COMPLETE_HISTORY_HYDRATION_CONSENTS_SUPPLEMENT_TUPLE], [ARTIST_COMPLETE_HISTORY_HYDRATION_SUPPLEMENT_SCHEMA, 1n, v]);
}
export function decodeArtistCompleteHistoryHydrationConsentsSupplement(raw: Hex): ArtistCompleteHistoryHydrationConsentsSupplement {
  const input = codec.boundedBytes(raw);
  if (input.slice(0, 66) !== ARTIST_COMPLETE_HISTORY_HYDRATION_SUPPLEMENT_SCHEMA) return normalizeArtistCompleteHistoryHydrationConsentsSupplement({ original: decodeArtistCompleteHistoryHydrationConsents(input), ratifications: [], sanctionInventory: "0x" });
  const types = ["bytes32", "uint16", ARTIST_COMPLETE_HISTORY_HYDRATION_CONSENTS_SUPPLEMENT_TUPLE], bytes = preflight(types, input), result = coder.decode(types.map(schemaType), bytes);
  const v = normalizeArtistCompleteHistoryHydrationConsentsSupplement(plain(schemaType(types[2]!), result[2]) as ArtistCompleteHistoryHydrationConsentsSupplement);
  if (result[1] !== 1n || encodeArtistCompleteHistoryHydrationConsentsSupplement(v) !== bytes) throw Error("Noncanonical or empty tagged consent supplement");
  return v;
}

const platformOperation = (op: bigint): boolean => [8n, 9n, 10n, 11n, 53n].includes(op);
const archiveOperation = (op: bigint): boolean => op >= 1n && op <= 13n || op >= 44n && op <= 50n || [52n, 53n, 61n].includes(op);
function scopeEqual(a: ArtistCompleteHistoryHydrationState, b: ArtistCompleteHistoryHydrationState): boolean {
  return same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, a.artists, b.artists) && same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, a.collections, b.collections);
}
function samePoint(a: shared.ArtistRecoveredHydrationPoint, b: shared.ArtistRecoveredHydrationPoint): boolean { return same(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, a, b); }
function owner(index: number): ArtistHydrationOwnerIndex {
  if (!Number.isInteger(index) || index < 0 || index > 6) throw Error("Invalid complete-history owner");
  return index as ArtistHydrationOwnerIndex;
}
function empty(type: string, value: unknown): boolean { return same(type, value, zeroValue(schemaType(type))); }
function child(type: string, name: string): string {
  const field = schemaType(type).components!.find(v => v.name === name);
  if (!field) throw Error("Unknown exact schema field");
  const unnamed = (t: ParamType): string => t.baseType === "tuple" ? `tuple(${t.components!.map(c => c.format("full")).join(",")})`
    : t.baseType === "array" ? `${unnamed(t.arrayChildren!)}[${t.arrayLength === -1 ? "" : t.arrayLength}]` : t.type;
  return unnamed(field);
}

/** Original whole-scope occurrence order. Platform receipts have no invented Artist. */
export function artistCompleteHistoryHydrationScope(
  artists: readonly Hex[], collections: shared.ArtistRecoveredHydrationRequest["records"]["authority"]["collections"],
  heads: readonly Types["StreamArtistOnboardingTypes.Binding"][], provenance: shared.ArtistRecoveredHydrationProvenance,
): ArtistCompleteHistoryHydrationState {
  const input = codec.normalizeTuple(`tuple(bytes32[] artists,tuple(bytes32 artistId,uint256 collectionId,${ARTIST_HYDRATION_POLICY_TUPLE}[] policies)[] collections)`, { artists, collections });
  const ids = input.artists, selected = input.collections;
  const h = codec.normalizeTuple(`${T["StreamArtistOnboardingTypes.Binding"]}[]`, heads), p = codec.normalizeArtistRecoveredHydrationProvenance(provenance);
  if (ids.length > 128 || !selected.length || selected.length > 128 || h.length !== selected.length) throw Error("Invalid complete-history selector cardinality");
  let policies = 0;
  for (let i = 0; i < ids.length; i++) if (ids[i] === Z || i > 0 && BigInt(ids[i]!) <= BigInt(ids[i - 1]!)) throw Error("Complete Artist IDs must be nonzero and ordered");
  for (let i = 0; i < selected.length; i++) {
    const c = selected[i]!, b = h[i]!;
    policies += c.policies.length;
    if (!c.collectionId || i > 0 && c.collectionId <= selected[i - 1]!.collectionId || policies > 128 || b.artistId !== c.artistId
      || (c.artistId === Z ? c.policies.length !== 0 || !empty(T["StreamArtistOnboardingTypes.Binding"], b) : !ids.includes(c.artistId) || b.bindingHash === Z || !b.generation)) throw Error("Invalid complete collection head/selector");
    const seen = new Set<string>();
    for (const key of c.policies) { const k = `${key.phaseId}:${key.policyHash}`; if (key.phaseId === Z || key.policyHash === Z || seen.has(k)) throw Error("Invalid policy selector"); seen.add(k); }
  }
  const ar: Hex[][] = ids.map(() => []), cr: Hex[][] = selected.map(() => []), registrations = ids.map(() => 0);
  for (let i = 0; i < 7; i++) for (const row of p.journals[owner(i)]) {
    const r = row.receipt, platform = i === 4 && r.artistId === Z && r.collectionId !== 0n && platformOperation(r.operation);
    if (!platform) {
      const a = ids.indexOf(r.artistId); if (a < 0) throw Error("Native receipt principal outside complete scope");
      ar[a]!.push(r.recordHash);
      if (i === 2 && (r.operation === 1n || r.operation === 6n)) {
        if (r.collectionId !== 0n || r.recordHash !== r.artistId) throw Error("Invalid original registration occurrence");
        registrations[a] = registrations[a]! + 1;
      }
    }
    if (r.collectionId) { const k = selected.findIndex(c => c.collectionId === r.collectionId); if (k < 0) throw Error("Native receipt collection outside complete scope"); cr[k]!.push(r.recordHash); }
  }
  if (registrations.some(n => n !== 1) || cr.some(rows => !rows.length)) throw Error("Incomplete original principal or collection occurrence partition");
  return normalizeArtistCompleteHistoryHydrationState({ artists: ids.map((artistId, i) => ({ artistId, collectionId: 0n, bindingHash: Z, policies: [], records: ar[i]! })),
    collections: selected.map((c, i) => ({ ...c, bindingHash: h[i]!.bindingHash, records: cr[i]! })), rows: [] });
}

export function artistCompleteHistoryHydrationAnchor(value: ArtistCompleteHistoryHydrationState): ArtistHydrationQuery {
  const s = normalizeArtistCompleteHistoryHydrationState(value), first = s.collections[0];
  if (!first) throw Error("Missing complete-history anchor");
  const principal = first.artistId === Z ? undefined : s.artists.find(a => a.artistId === first.artistId);
  if (first.artistId !== Z && !principal) throw Error("Missing anchor principal");
  return codec.normalizeTuple(ARTIST_HYDRATION_QUERY_TUPLE, { ...first, records: principal?.records ?? first.records });
}

/** Available immutable joins only. This does not authenticate Archive bytes or source calls. */
export function validateArtistCompleteHistoryHydrationInventory(
  value: ArtistCompleteHistoryHydrationInventory,
): ArtistCompleteHistoryHydrationInventory {
  const v = normalizeArtistCompleteHistoryHydrationInventory(value), p = codec.normalizeArtistRecoveredHydrationProvenance(v.provenance);
  if (v.archive.catalogues.length !== p.eras.length || v.archive.operations.length > 16_384 || v.accounts.length > 128) throw Error("Incomplete common catalogue/nonce roster");
  for (let e = 0; e < p.eras.length; e++) {
    const c = v.archive.catalogues[e]!, era = p.eras[e]!;
    if (c.originHash !== era.originHash || c.archiveCodeHash === Z || c.configurationHash === Z || c.rowsHash === Z || c.count > 16_384n) throw Error("Common catalogue origin/identity mismatch");
    for (let i = 0; i < 7; i++) if (c.lower[i] !== era.lowerRevisions[owner(i)] || c.upper[i] !== era.checkpoints[owner(i)].ownerState.revision) throw Error("Common catalogue seven-owner cutoff mismatch");
  }
  let priorEra = -1, priorIndex = -1n;
  const seen = new Set<Hex>();
  for (const op of v.archive.operations) {
    const era = p.eras.findIndex(e => e.originHash === op.originHash), e = op.evidence;
    if (era < 0 || era < priorEra || era === priorEra && e.catalogueIndex <= priorIndex || !archiveOperation(op.operation)
      || e.catalogueIndex >= v.archive.catalogues[era]!.count || e.pointer === ZeroAddress || e.payloadHash === Z || e.evidenceId === Z || seen.has(e.evidenceId)) throw Error("Invalid ordered original Archive operation selection");
    seen.add(e.evidenceId); priorEra = era; priorIndex = e.catalogueIndex;
  }
  for (const row of v.archive.proposals) if (row.proposalOperation >= BigInt(v.archive.operations.length) || row.identityOperationPlusOne > BigInt(v.archive.operations.length)) throw Error("Collaborator proposal references missing Archive operation");
  for (const row of v.archive.accepted) if (row.operationIndex >= BigInt(v.archive.operations.length)) throw Error("Collaborator acceptance references missing Archive operation");
  return v;
}

export function validateArtistCompleteHistoryHydrationState(
  index: ArtistHydrationOwnerIndex, value: ArtistCompleteHistoryHydrationState,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance, inventory: ArtistCompleteHistoryHydrationInventory,
): ArtistCompleteHistoryHydrationState {
  owner(index);
  const supplied = codec.normalizeTuple(`tuple(${ARTIST_COMPLETE_HISTORY_HYDRATION_STATE_TUPLE} state,${ARTIST_COMPLETE_HISTORY_HYDRATION_INVENTORY_TUPLE} inventory)`, { state: value, inventory });
  const s = supplied.state, v = validateArtistCompleteHistoryHydrationInventory(supplied.inventory), p = codec.normalizeArtistRecoveredHydrationOwnerProvenance(provenance, index);
  if (!same(shared.ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE, p, codec.artistRecoveredHydrationOwnerProvenance(v.provenance, index))) throw Error("Complete auxiliary provenance differs from owner slice");
  const n = s.collections.length, b = v.bindings;
  if (s.artists.length > 128 || !n || n > 128 || s.rows.length !== (index === 1 ? 0 : index === 2 || index === 5 ? s.artists.length : n)
    || b.bindings.length !== n || b.generations.length !== n || b.collaborators.length !== n || v.platforms.length !== n || v.accepted.length !== n) throw Error("Complete owner row/collection cardinality mismatch");
  const expected = artistCompleteHistoryHydrationScope(s.artists.map(a => a.artistId), s.collections.map(c => ({ artistId: c.artistId, collectionId: c.collectionId, policies: c.policies })), b.bindings.map(c => c.bindings.current), v.provenance);
  if (!scopeEqual(s, expected)) throw Error("Complete semantic scope omits or reorders original native occurrences");
  const bindingHash = codec.artistRecoveredHydrationOwnerProvenanceHash(codec.artistRecoveredHydrationOwnerProvenance(v.provenance, 0), 0),
    acceptanceHash = codec.artistRecoveredHydrationOwnerProvenanceHash(codec.artistRecoveredHydrationOwnerProvenance(v.provenance, 3), 3),
    attributionHash = codec.artistRecoveredHydrationOwnerProvenanceHash(codec.artistRecoveredHydrationOwnerProvenance(v.provenance, 4), 4);
  for (let k = 0; k < n; k++) {
    const q = s.collections[k]!, c = b.bindings[k]!, rows = c.bindings.rows, m = rows.length, generations = b.generations[k]!, collaborators = b.collaborators[k]!;
    if (m > 128 || generations.length !== m || c.corrections.length !== m || collaborators.length !== m
      || c.bindings.provenanceCommitment !== bindingHash || c.bindings.artistId !== q.artistId || c.bindings.collectionId !== q.collectionId || c.bindings.bindingHash !== q.bindingHash
      || c.bindings.current.generation !== BigInt(m) || c.bindings.current.artistId !== q.artistId || c.bindings.current.bindingHash !== q.bindingHash
      || (m === 0 ? q.artistId !== Z || q.bindingHash !== Z || !empty(T["StreamArtistOnboardingTypes.Binding"], c.bindings.current)
        : q.artistId === Z || q.bindingHash === Z || !same(T["StreamArtistOnboardingTypes.Binding"], c.bindings.current, rows[m - 1]!.item))) throw Error("Complete binding scope/current-head mismatch");
    for (let g = 0; g < m; g++) {
      const r = rows[g]!.item, generation = generations[g]!;
      if (!s.artists.some(a => a.artistId === r.artistId) || r.generation !== BigInt(g + 1) || r.bindingHash === Z
        || generation.generation !== BigInt(g + 1) || generation.bindingHash !== r.bindingHash || generation.accepted !== r.accepted) throw Error("Historical binding principal/generation mismatch");
    }
    const platform = v.platforms[k]!, a = v.accepted[k]!;
    if (platform.provenance !== attributionHash || platform.collectionId !== q.collectionId || platform.catalogues.length || platform.operations.length || platform.continuations.length > 128
      || a.provenance !== acceptanceHash || a.artistId !== q.artistId || a.collectionId !== q.collectionId || a.bindingHash !== q.bindingHash || a.rows.length !== m) throw Error("Complete Platform/Acceptance partition mismatch");
    const count = (platform.state.declaration.recordHash === Z ? 0 : 1) + (platform.state.correction.recordHash === Z ? 0 : 1) + platform.claims.length + platform.contests.length + platform.allegations.length;
    if (q.artistId === Z && (!count || platform.state.correction.correctiveGeneration !== 0n || platform.state.correction.accepted || platform.continuations.length)) throw Error("Invalid unbound Platform history");
    for (let g = 0; g < m; g++) if (a.rows[g]!.bindingHash !== generations[g]!.bindingHash || a.rows[g]!.generation !== BigInt(g + 1) || (a.rows[g]!.recordHash === Z) !== (a.rows[g]!.acceptedAt === 0n)) throw Error("Acceptance generation/record-time mismatch");
  }
  return s;
}

export function encodeArtistCompleteHistoryHydrationState(index: ArtistHydrationOwnerIndex, value: ArtistCompleteHistoryHydrationState, provenance: shared.ArtistRecoveredHydrationOwnerProvenance, auxiliary: Hex): Hex {
  const inventory = decodeArtistCompleteHistoryHydrationInventory(auxiliary), s = validateArtistCompleteHistoryHydrationState(index, value, provenance, inventory);
  return codec.encodeTupleValues(["bytes32", "uint16", "uint8", ARTIST_COMPLETE_HISTORY_HYDRATION_STATE_TUPLE, "bytes"], [ARTIST_COMPLETE_HISTORY_HYDRATION_SCHEMA, 1n, BigInt(index), s, auxiliary]);
}
export function decodeArtistCompleteHistoryHydrationAuxiliary(raw: Hex, index: ArtistHydrationOwnerIndex, provenance: shared.ArtistRecoveredHydrationOwnerProvenance): Readonly<{ state: ArtistCompleteHistoryHydrationState; auxiliary: Hex }> {
  owner(index);
  const types = ["bytes32", "uint16", "uint8", ARTIST_COMPLETE_HISTORY_HYDRATION_STATE_TUPLE, "bytes"], input = preflight(types, raw), result = coder.decode(types.map(schemaType), input);
  if (result[0] !== ARTIST_COMPLETE_HISTORY_HYDRATION_SCHEMA || result[1] !== 1n || result[2] !== BigInt(index) || result[4] === "0x" || coder.encode(types.map(schemaType), result) !== input) throw Error("Noncanonical complete semantic schema/version/owner/auxiliary");
  const auxiliary = result[4] as Hex, inventory = decodeArtistCompleteHistoryHydrationInventory(auxiliary);
  const state = validateArtistCompleteHistoryHydrationState(index, plain(stateType, result[3]) as ArtistCompleteHistoryHydrationState, provenance, inventory);
  return Object.freeze({ state, auxiliary });
}
export function decodeArtistCompleteHistoryHydrationState(raw: Hex, index: ArtistHydrationOwnerIndex, provenance: shared.ArtistRecoveredHydrationOwnerProvenance): ArtistCompleteHistoryHydrationState { return decodeArtistCompleteHistoryHydrationAuxiliary(raw, index, provenance).state; }
export function normalizeArtistCompleteHistoryHydrationOwnerPayload(value: shared.ArtistRecoveredHydrationOwnerPayload, index: ArtistHydrationOwnerIndex): shared.ArtistRecoveredHydrationOwnerPayload {
  const payload = codec.normalizeArtistRecoveredHydrationOwnerPayload(value, index);
  decodeArtistCompleteHistoryHydrationState(payload.semanticState, index, payload.provenance);
  if (index !== 2 && payload.nonces.length) throw Error("Nonce inventory is exclusive to Identity owner");
  return payload;
}
export function encodeArtistCompleteHistoryHydrationOwnerPayload(payload: shared.ArtistRecoveredHydrationOwnerPayload, index: ArtistHydrationOwnerIndex, features: bigint): Hex {
  return codec.encodeArtistRecoveredHydrationOwnerPayload(normalizeArtistCompleteHistoryHydrationOwnerPayload(payload, index), index, features);
}
export function decodeArtistCompleteHistoryHydrationOwnerPayload(raw: Hex, index: ArtistHydrationOwnerIndex) {
  preflight(["bytes32", "uint16", shared.ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE], raw);
  const decoded = codec.decodeArtistRecoveredHydrationOwnerPayload(raw, index);
  decodeArtistCompleteHistoryHydrationState(decoded.payload.semanticState, index, decoded.payload.provenance);
  if (index !== 2 && decoded.payload.nonces.length) throw Error("Nonce inventory is exclusive to Identity owner");
  return decoded;
}

export interface ArtistCompleteHistoryHydrationInput { readonly request: shared.ArtistRecoveredHydrationRequest; readonly royaltyFreezes: readonly ArtistCompleteHistoryHydrationRoyaltyFreeze[]; }
export interface ArtistCompleteHistoryHydrationCall {
 readonly registry: Address; readonly caller: Address; readonly request: shared.ArtistRecoveredHydrationRequest;
 readonly royaltyFreezes: readonly ArtistCompleteHistoryHydrationRoyaltyFreeze[]; readonly profile: Hex; readonly capabilityId: Hex;
 readonly call: UnsignedCall; readonly factsVerified: false;
}
/** The two original Registry routes; no new request or commitment fields. */
export const CURRENT_ARTIST_COMPLETE_HISTORY_HYDRATION_ABI = Object.freeze([
  ...codec.CURRENT_ARTIST_RECOVERED_HYDRATION_ABI,
  `function hydrateRecoveredArtistAuthorityWithConsents(${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,${ARTIST_COMPLETE_HISTORY_HYDRATION_ROYALTY_FREEZE_TUPLE}[] royaltyFreezes) returns(bytes32)`,
]);
const registryInterface = new Interface(CURRENT_ARTIST_COMPLETE_HISTORY_HYDRATION_ABI);
export const ARTIST_COMPLETE_HISTORY_HYDRATION_CAPABILITY_ID = codec.ARTIST_RECOVERED_HYDRATION_CAPABILITY_ID;
export const ARTIST_COMPLETE_HISTORY_HYDRATION_WITH_CONSENTS_CAPABILITY_ID = registryInterface.getFunction("hydrateRecoveredArtistAuthorityWithConsents")!.selector as Hex;
/** Original compiler nominal library identifiers, never expanded tuple selectors. */
export const ARTIST_COMPLETE_HISTORY_HYDRATION_PREPARE_SELECTOR = "0x72c84763" as Hex;
export const ARTIST_COMPLETE_HISTORY_HYDRATION_PREPARE_WITH_CONSENTS_SELECTOR = "0x4925300f" as Hex;
export const ARTIST_COMPLETE_HISTORY_HYDRATION_PREPARE_ABI = Object.freeze([
  ...codec.ARTIST_RECOVERED_HYDRATION_PREPARE_ABI,
  `function prepare(${ARTIST_HYDRATION_SUITE_TUPLE} destination,${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,${ARTIST_COMPLETE_HISTORY_HYDRATION_ROYALTY_FREEZE_TUPLE}[] royaltyFreezes) view returns(${shared.ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE} prepared)`,
]);

export function normalizeArtistCompleteHistoryHydrationRoyaltyFreezes(
  value: readonly ArtistCompleteHistoryHydrationRoyaltyFreeze[], collectionId?: bigint,
): readonly ArtistCompleteHistoryHydrationRoyaltyFreeze[] {
  codec.boundedArray(value, 128);
  const rows = codec.normalizeTuple(`${ARTIST_COMPLETE_HISTORY_HYDRATION_ROYALTY_FREEZE_TUPLE}[]`, value);
  for (const row of rows) {
    if (!row.collectionId || collectionId !== undefined && row.collectionId !== collectionId
      || row.resolver === ZeroAddress || row.revenueClass !== id("ROYALTY_ERC2981")
      || row.expectedAssignmentHash === Z) throw Error("Invalid original royalty selector");
  }
  return rows;
}
export function normalizeArtistCompleteHistoryHydrationInputDraft(value: ArtistCompleteHistoryHydrationInput): ArtistCompleteHistoryHydrationInput {
  value = codec.normalizeTuple(`tuple(${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,${ARTIST_COMPLETE_HISTORY_HYDRATION_ROYALTY_FREEZE_TUPLE}[] royaltyFreezes)`, value);
  const request = codec.normalizeArtistRecoveredHydrationRequestDraft(value.request);
  const royaltyFreezes = normalizeArtistCompleteHistoryHydrationRoyaltyFreezes(value.royaltyFreezes);
  if (royaltyFreezes.some(r => !request.records.authority.collections.some(c => c.collectionId === r.collectionId))) throw Error("Royalty selector outside complete collection selection");
  return Object.freeze({ request, royaltyFreezes });
}
export function normalizeArtistCompleteHistoryHydrationInput(value: ArtistCompleteHistoryHydrationInput): ArtistCompleteHistoryHydrationInput {
  const input = normalizeArtistCompleteHistoryHydrationInputDraft(value);
  codec.normalizeArtistRecoveredHydrationRequest(input.request);
  return input;
}
export function prepareArtistCompleteHistoryHydrationCall(registry: Address, caller: Address, value: ArtistCompleteHistoryHydrationInput): ArtistCompleteHistoryHydrationCall {
  const target = getAddress(registry) as Address, actor = getAddress(caller) as Address;
  if (target === ZeroAddress || actor === ZeroAddress) throw Error("Expected actual Registry and caller");
  const input = normalizeArtistCompleteHistoryHydrationInput(value);
  const withConsents = input.royaltyFreezes.length !== 0;
  const method = withConsents ? "hydrateRecoveredArtistAuthorityWithConsents" : "hydrateRecoveredArtistAuthority";
  const data = codec.boundedBytes(registryInterface.encodeFunctionData(method, withConsents ? [input.request, input.royaltyFreezes] : [input.request]));
  return Object.freeze({ registry: target, caller: actor, ...input, profile: shared.ARTIST_RECOVERED_HYDRATION_PROFILE,
    capabilityId: registryInterface.getFunction(method)!.selector as Hex,
    call: Object.freeze({ to: target, value: 0n, data }), factsVerified: false });
}
export function normalizeArtistCompleteHistoryHydrationCall(value: ArtistCompleteHistoryHydrationCall): ArtistCompleteHistoryHydrationCall {
  value = codec.normalizeTuple(`tuple(address registry,address caller,${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,${ARTIST_COMPLETE_HISTORY_HYDRATION_ROYALTY_FREEZE_TUPLE}[] royaltyFreezes,bytes32 profile,bytes4 capabilityId,tuple(address to,uint256 value,bytes data) call,bool factsVerified)`, value);
  const rebuilt = prepareArtistCompleteHistoryHydrationCall(value.registry, value.caller, { request: value.request, royaltyFreezes: value.royaltyFreezes });
  if (value.profile !== rebuilt.profile || value.capabilityId !== rebuilt.capabilityId || value.factsVerified !== false
    || getAddress(value.call.to) !== rebuilt.call.to || value.call.value !== 0n || codec.boundedBytes(value.call.data) !== rebuilt.call.data) throw Error("Complete-history call differs from immutable input");
  return rebuilt;
}
export function artistCompleteHistoryHydrationPreparationCalldata(destination: ArtistHydrationSuite, value: ArtistCompleteHistoryHydrationInput): Hex {
  const input = normalizeArtistCompleteHistoryHydrationInputDraft(value);
  if (!input.royaltyFreezes.length) return codec.artistRecoveredHydrationPreparationCalldata(destination, input.request);
  const suite = codec.normalizeTuple(ARTIST_HYDRATION_SUITE_TUPLE, destination);
  const data = codec.encodeTupleValues([ARTIST_HYDRATION_SUITE_TUPLE, shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE,
    `${ARTIST_COMPLETE_HISTORY_HYDRATION_ROYALTY_FREEZE_TUPLE}[]`], [suite, input.request, input.royaltyFreezes]);
  return codec.boundedBytes(`${ARTIST_COMPLETE_HISTORY_HYDRATION_PREPARE_WITH_CONSENTS_SELECTOR}${data.slice(2)}`);
}

/** Original disjoint principal/delegate/account union, in global insertion order. */
export function artistCompleteHistoryHydrationNonceUnion(
  value: ArtistCompleteHistoryHydrationState, inventory: readonly shared.ArtistRecoveredHydrationNonceInventory[],
  checkpoint: Parameters<typeof codec.normalizeArtistRecoveredHydrationNonceInventory>[1], accounts: readonly ArtistCompleteHistoryHydrationNonceLane[],
): readonly ArtistCompleteHistoryHydrationNonceLane[] {
  const supplied = codec.normalizeTuple(`tuple(${ARTIST_COMPLETE_HISTORY_HYDRATION_STATE_TUPLE} state,${ARTIST_COMPLETE_HISTORY_HYDRATION_NONCE_LANE_TUPLE}[] accounts)`, { state: value, accounts });
  const s = supplied.state, global = codec.normalizeArtistRecoveredHydrationNonceInventory(inventory, checkpoint), result: ArtistCompleteHistoryHydrationNonceLane[] = new Array(global.length);
  if (s.rows.length !== s.artists.length || s.artists.length > 128 || supplied.accounts.length > 128) throw Error("Invalid Complete Identity/account partition");
  const used = new Set<number>(), addresses = new Set<Address>(); let timing: Hex | undefined;
  const take = (lanes: readonly ArtistCompleteHistoryHydrationNonceLane[]): void => {
    let previous = -1;
    for (const lane of lanes) {
      const at = global.findIndex(r => r.index.kind === lane.kind && r.index.key === lane.key);
      if (at < 0 || at <= previous || used.has(at) || !same(child(ARTIST_COMPLETE_HISTORY_HYDRATION_NONCE_LANE_TUPLE, "words"), lane.words, global[at]!.words)) throw Error("Complete global nonce bijection mismatch");
      previous = at; used.add(at); result[at] = lane;
    }
  };
  for (let a = 0; a < s.rows.length; a++) {
    const b = decodeArtistCompleteHistoryHydrationIdentity(s.rows[a]!), current = hash([child(ARTIST_COMPLETE_HISTORY_HYDRATION_IDENTITY_TUPLE, "timing")], [b.timing]);
    if (b.artistId !== s.artists[a]!.artistId || b.identity.authorityAddress === ZeroAddress || addresses.has(b.identity.authorityAddress)
      || b.nextRegistrationNonce !== BigInt(s.artists.length) || timing !== undefined && timing !== current || b.nonces.length > 128) throw Error("Complete Identity nonce principal/global timing mismatch");
    addresses.add(b.identity.authorityAddress); timing = current;
    const keys = new Set<string>();
    for (const lane of b.nonces) {
      const belongs = lane.kind === 1n ? lane.key === b.artistId
        : lane.kind === 2n ? b.delegations.some(d => lane.key === hash(["bytes32", "bytes32", "address"], [id("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), b.artistId, d.record.grant.delegate]))
          : lane.kind === 4n ? [...b.rotations, ...b.recoveries].some(r => lane.key === hash(["bytes32", "bytes32", "address"], [id("rotation_acceptance"), b.artistId, r.record.terms.newAddress]))
            : lane.kind === 5n && b.estates.some(e => lane.key === hash(["string", "bytes32", "address"], ["estate_activation", b.artistId, e.request.terms.successor]));
      const key = `${lane.kind}:${lane.key}`;
      if (!belongs || lane.key === Z || keys.has(key) || !lane.words.length || lane.words.length > 256
        || new Set(lane.words.map(w => w.prefix)).size !== lane.words.length || lane.words.some(w => w.exhausted !== lane.words[0]!.exhausted)) throw Error("Invalid complete principal/delegate nonce lane");
      keys.add(key);
    }
    take(b.nonces);
  }
  for (const lane of supplied.accounts) if (lane.kind !== 3n || lane.key === Z || BigInt(lane.key) >= 1n << 160n) throw Error("Invalid collaborator account nonce lane");
  take(supplied.accounts);
  if (used.size !== global.length) throw Error("Incomplete global nonce partition");
  return Object.freeze(result);
}

export interface ArtistCompleteHistoryHydrationComposition {
  readonly states: readonly ArtistCompleteHistoryHydrationState[];
  readonly inventory: ArtistCompleteHistoryHydrationInventory;
  readonly identities: readonly ArtistCompleteHistoryHydrationIdentity[];
  readonly payouts: readonly ArtistCompleteHistoryHydrationPayout[];
  readonly attributions: readonly ArtistCompleteHistoryHydrationAttribution[];
  readonly consents: readonly ArtistCompleteHistoryHydrationConsentsSupplement[];
  readonly requiredFeatures: bigint;
  readonly factsVerified: false;
  readonly originalCompositionAdmissionIndependentlyVerified: false;
}

function principalFeatures(identities: readonly ArtistCompleteHistoryHydrationIdentity[], payouts: readonly ArtistCompleteHistoryHydrationPayout[], eras: number): bigint {
  let features = ARTIST_COMPLETE_HISTORY_HYDRATION_BASE | (eras > 1 ? 16n : 0n);
  const classFeature = (c: bigint): bigint => { if (c === 1n) return 1n; if (c === 3n) return 2n; throw Error("Complete profile supports only original Class1/3 Identity"); };
  for (let i = 0; i < identities.length; i++) {
    const b = identities[i]!; features |= classFeature(b.identity.authorityClass);
    for (const r of b.recoveries) features |= classFeature(r.record.fields.vestedAuthorityClass);
    for (const a of b.actions) { if (a.evidenceV2.manifestHash !== Z) features |= 4n; if (a.evidenceV3.manifestHash !== Z) features |= 8n; }
    if (b.revisionContinuations.length || b.standingContinuations.length || b.capabilityContinuations.length || payouts[i]!.continuations.length) features |= 8n;
    if (b.delegations.length) features |= 64n;
  }
  return features;
}
export function artistCompleteHistoryHydrationRequiredFeatures(
  identities: readonly ArtistCompleteHistoryHydrationIdentity[], payouts: readonly ArtistCompleteHistoryHydrationPayout[],
  inventory: ArtistCompleteHistoryHydrationInventory, attributions: readonly ArtistCompleteHistoryHydrationAttribution[], consents: readonly ArtistCompleteHistoryHydrationConsentsSupplement[],
): bigint {
  const s = codec.normalizeTuple(`tuple(${ARTIST_COMPLETE_HISTORY_HYDRATION_IDENTITY_TUPLE}[] identities,${ARTIST_COMPLETE_HISTORY_HYDRATION_PAYOUT_TUPLE}[] payouts,${ARTIST_COMPLETE_HISTORY_HYDRATION_INVENTORY_TUPLE} inventory,${ARTIST_COMPLETE_HISTORY_HYDRATION_ATTRIBUTION_TUPLE}[] attributions,${ARTIST_COMPLETE_HISTORY_HYDRATION_CONSENTS_SUPPLEMENT_TUPLE}[] consents)`, { identities, payouts, inventory, attributions, consents });
  const v = validateArtistCompleteHistoryHydrationInventory(s.inventory), n = v.bindings.bindings.length;
  if (s.identities.length > 128 || s.identities.length !== s.payouts.length || s.attributions.length !== n || s.consents.length !== n) throw Error("Complete feature partition mismatch");
  let features = principalFeatures(s.identities, s.payouts, v.provenance.eras.length);
  for (let k = 0; k < n; k++) {
    const a = s.attributions[k]!, c = s.consents[k]!;
    if (c.sanctionInventory !== "0x" && decodeArtistCompleteHistoryHydrationSanctionInventory(c.sanctionInventory).sanctions.length) features |= 16384n;
    if (c.ratifications.length) features |= 1024n;
    if (a.records.records.length) features |= 128n | 131072n;
    if (a.history.disputes.length + a.history.repudiations.length + a.history.resolutions.length) features |= 8192n;
    if (c.original.rows.original.economics.length) features |= 32n;
    if (c.original.rows.original.sales.length) features |= 64n;
    if (c.original.rows.consents.length + c.original.rows.royalties.length + c.original.rows.freezes.length) features |= 256n | 32768n;
    if (v.bindings.generations[k]!.length) features |= 512n;
    for (let g = 0; g < v.bindings.generations[k]!.length; g++) {
      if (v.bindings.generations[k]![g]!.accepted) features |= 4096n;
      if (v.bindings.bindings[k]!.corrections[g]!.recordHash !== Z) features |= 2048n;
      if (v.bindings.bindings[k]!.bindings.rows[g]!.item.consentMode === 2n) features |= 64n;
    }
  }
  if (v.archive.operations.some(o => platformOperation(o.operation))) features |= 65536n;
  if (features & ~ARTIST_COMPLETE_HISTORY_HYDRATION_ALLOWED_FEATURES) throw Error("Unsupported complete semantic feature union");
  return features;
}

type Graph = Pick<shared.ArtistRecoveredHydrationPrepared, "query" | "data" | "timing"> & { readonly admission: Pick<shared.ArtistRecoveredHydrationCertificate, "artists" | "collections" | "provenance"> };
function compose(p: Graph): ArtistCompleteHistoryHydrationComposition {
  const states: ArtistCompleteHistoryHydrationState[] = [], identities: ArtistCompleteHistoryHydrationIdentity[] = [], payouts: ArtistCompleteHistoryHydrationPayout[] = [];
  let auxiliary: Hex | undefined, features: bigint | undefined;
  const locals = p.data.map((d, i) => decodeArtistCompleteHistoryHydrationOwnerPayload(d.typedState, owner(i)));
  for (let i = 0; i < 7; i++) {
    const index = owner(i), local = locals[i]!, decoded = decodeArtistCompleteHistoryHydrationAuxiliary(local.payload.semanticState, index, local.payload.provenance), s = decoded.state;
    if (auxiliary !== undefined && auxiliary !== decoded.auxiliary || features !== undefined && features !== local.header.requiredFeatures
      || !same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.artists, p.admission.artists) || !same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.collections, p.admission.collections)
      || !same(ARTIST_HYDRATION_QUERY_TUPLE, artistCompleteHistoryHydrationAnchor(s), p.query)
      || !same(shared.ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE, local.payload.provenance, codec.artistRecoveredHydrationOwnerProvenance(p.admission.provenance, index))) throw Error("Complete all-seven scope, auxiliary, feature or provenance mismatch");
    auxiliary = decoded.auxiliary; features = local.header.requiredFeatures; states.push(s);
    if (i === 2) for (let a = 0; a < s.rows.length; a++) {
      const b = decodeArtistCompleteHistoryHydrationIdentity(s.rows[a]!);
      if (b.artistId !== s.artists[a]!.artistId || ![1n, 3n].includes(b.identity.authorityClass) || b.identity.status === 0n
        || !same(ARTIST_HYDRATION_SNAPSHOT_TUPLE, b.sourceSnapshot, local.payload.provenance.eras.at(-1)!.checkpoint.ownerState)
        || !same(shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, b.timing.checkpoint, p.timing)) throw Error("Complete Identity principal/source/timing mismatch");
      identities.push(b);
    }
    if (i === 5) for (let a = 0; a < s.rows.length; a++) {
      const b = decodeArtistCompleteHistoryHydrationPayout(s.rows[a]!);
      if (b.artistId !== s.artists[a]!.artistId || !same(ARTIST_HYDRATION_SNAPSHOT_TUPLE, b.sourceSnapshot, local.payload.provenance.eras.at(-1)!.checkpoint.ownerState)) throw Error("Complete Payout principal/source mismatch");
      payouts.push(b);
    }
  }
  const inventory = decodeArtistCompleteHistoryHydrationInventory(auxiliary!);
  if (!same(shared.ARTIST_RECOVERED_HYDRATION_PROVENANCE_TUPLE, inventory.provenance, p.admission.provenance)) throw Error("Complete inventory differs from full admission provenance");
  const attributions = states[4]!.rows.map(decodeArtistCompleteHistoryHydrationAttribution), consents = states[6]!.rows.map(decodeArtistCompleteHistoryHydrationConsentsSupplement);
  artistCompleteHistoryHydrationNonceUnion(states[2]!, locals[2]!.payload.nonces, locals[2]!.payload.provenance.eras.at(-1)!.checkpoint, inventory.accounts);
  validateFamilyRows(states, inventory, attributions, consents);
  const requiredFeatures = artistCompleteHistoryHydrationRequiredFeatures(identities, payouts, inventory, attributions, consents);
  if (features !== requiredFeatures) throw Error("Complete required-feature union differs from supplied original families");
  return Object.freeze({ states: Object.freeze(states), inventory, identities: Object.freeze(identities), payouts: Object.freeze(payouts), attributions: Object.freeze(attributions), consents: Object.freeze(consents), requiredFeatures, factsVerified: false, originalCompositionAdmissionIndependentlyVerified: false });
}

/** Bounded immutable joins; original live composition and signature admission are not inferred. */
export function validateArtistCompleteHistoryHydrationComposition(value: shared.ArtistRecoveredHydrationPrepared): ArtistCompleteHistoryHydrationComposition {
  return compose(codec.normalizeArtistRecoveredHydrationPrepared(value));
}
export function normalizeArtistCompleteHistoryHydrationPrepared(value: shared.ArtistRecoveredHydrationPrepared): shared.ArtistRecoveredHydrationPrepared {
  const p = codec.normalizeArtistRecoveredHydrationPrepared(value); compose(p); return p;
}
export function encodeArtistCompleteHistoryHydrationPrepared(value: shared.ArtistRecoveredHydrationPrepared): Hex { return codec.encodeArtistRecoveredHydrationPrepared(normalizeArtistCompleteHistoryHydrationPrepared(value)); }
export function decodeArtistCompleteHistoryHydrationPrepared(raw: Hex): shared.ArtistRecoveredHydrationPrepared {
  preflight([shared.ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE], raw, shared.ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES);
  return normalizeArtistCompleteHistoryHydrationPrepared(codec.decodeArtistRecoveredHydrationPrepared(raw));
}
export function artistCompleteHistoryHydrationSemanticInventory(value: shared.ArtistRecoveredHydrationPrepared): Hex { return codec.artistRecoveredHydrationSemanticInventory(normalizeArtistCompleteHistoryHydrationPrepared(value)); }
export function artistCompleteHistoryHydrationCommitment(c: shared.ArtistRecoveredHydrationCoordinates, request: shared.ArtistRecoveredHydrationRequest, value: shared.ArtistRecoveredHydrationPrepared): Hex {
  const p = normalizeArtistCompleteHistoryHydrationPrepared(value); validateWitnessRows(request, compose(p)); return codec.artistRecoveredHydrationCommitment(c, request, p);
}
export function encodeArtistCompleteHistoryHydrationProfileEvidence(request: shared.ArtistRecoveredHydrationRequest, value: shared.ArtistRecoveredHydrationPrepared): Hex {
  const p = normalizeArtistCompleteHistoryHydrationPrepared(value); validateWitnessRows(request, compose(p)); return codec.encodeArtistRecoveredHydrationProfileEvidence(request, p);
}
export function decodeArtistCompleteHistoryHydrationRequest(raw: Hex): shared.ArtistRecoveredHydrationRequest { preflight([shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE], raw); return codec.decodeArtistRecoveredHydrationRequest(raw); }

function validateFamilyRows(states: readonly ArtistCompleteHistoryHydrationState[], v: ArtistCompleteHistoryHydrationInventory,
  attributions: readonly ArtistCompleteHistoryHydrationAttribution[], consents: readonly ArtistCompleteHistoryHydrationConsentsSupplement[]): void {
  const p = v.provenance, scope = states[0]!, owner4 = codec.artistRecoveredHydrationOwnerProvenanceHash(codec.artistRecoveredHydrationOwnerProvenance(p, 4), 4),
    owner6 = codec.artistRecoveredHydrationOwnerProvenanceHash(codec.artistRecoveredHydrationOwnerProvenance(p, 6), 6);
  const sanctionRaw = consents[0]!.sanctionInventory, sanctions = sanctionRaw === "0x" ? undefined : decodeArtistCompleteHistoryHydrationSanctionInventory(sanctionRaw);
  const selectedSanctions = v.archive.operations.filter(o => o.operation === 12n || o.operation === 13n);
  if (sanctions ? !sanctions.sanctions.length || !same(`${ARTIST_COMPLETE_HISTORY_HYDRATION_ARCHIVE_OPERATION_TUPLE}[]`, sanctions.operations, selectedSanctions) : selectedSanctions.length !== 0) throw Error("Missing or substituted common sanction projection");
  if (sanctions) {
    if (sanctions.catalogues.length !== p.eras.length) throw Error("Incomplete sanction catalogue roster");
    for (let e = 0; e < p.eras.length; e++) {
      const c = sanctions.catalogues[e]!, era = p.eras[e]!;
      if (c.originHash !== era.originHash || c.attributionLower !== era.lowerRevisions[4] || c.attributionUpper !== era.checkpoints[4].ownerState.revision
        || c.consentLower !== era.lowerRevisions[6] || c.consentUpper !== era.checkpoints[6].ownerState.revision || c.archiveCodeHash !== v.archive.catalogues[e]!.archiveCodeHash
        || c.configurationHash !== v.archive.catalogues[e]!.configurationHash || c.count !== v.archive.catalogues[e]!.count) throw Error("Sanction catalogue retained cutoff/identity mismatch");
    }
  }
  let vetoes = 0;
  for (let k = 0; k < scope.collections.length; k++) {
    const q = scope.collections[k]!, bindings = v.bindings.bindings[k]!, a = attributions[k]!, d = a.history, c = consents[k]!, original = c.original.rows.original, m = bindings.bindings.rows.length;
    if (states[0]!.rows[k] !== encodeArtistCompleteHistoryHydrationBindingBundle(bindings) || states[3]!.rows[k] !== encodeArtistCompleteHistoryHydrationAcceptanceBundle(v.accepted[k]!)) throw Error("Complete Binding/Acceptance rows differ from common inventory");
    if (d.provenance !== owner4 || d.artistId !== q.artistId || d.collectionId !== q.collectionId || d.bindingHash !== q.bindingHash
      || d.current.generation !== BigInt(m) || d.heads.length !== m || !same(`${ARTIST_COMPLETE_HISTORY_HYDRATION_GENERATION_TUPLE}[]`, d.generations, v.bindings.generations[k])
      || !same(child(ARTIST_COMPLETE_HISTORY_HYDRATION_ATTRIBUTION_HISTORY_TUPLE, "current"), d.current, a.records.item)
      || a.records.provenance !== owner4 || a.records.artistId !== q.artistId || a.records.collectionId !== q.collectionId || a.records.bindingHash !== q.bindingHash
      || a.records.item.state > 5n || (q.artistId === Z ? a.records.item.state !== 0n : a.records.item.state === 0n)
      || a.records.records.length > 128 || a.records.personhood.length > 128) throw Error("Complete Attribution family scope/current identity mismatch");
    if (original.provenance !== owner6 || original.artistId !== q.artistId || original.collectionId !== q.collectionId || original.bindingHash !== q.bindingHash
      || !same(`${ARTIST_HYDRATION_POLICY_TUPLE}[]`, original.keys, q.policies) || original.keys.length !== original.policies.length
      || !same(`${T["StreamArtistOnboardingTypes.Binding"]}[]`, c.original.bindings, bindings.bindings.rows.map(r => r.item))
      || k > 0 && c.sanctionInventory !== "0x") throw Error("Complete Consent supplement scope or shared sanction placement mismatch");
    const native = p.journals[4].filter(j => j.receipt.collectionId === q.collectionId), records = native.filter(j => j.receipt.operation === 24n);
    if (records.length !== a.records.records.length) throw Error("Incomplete original op24 occurrence partition");
    for (let i = 0; i < records.length; i++) {
      const row = a.records.records[i]!, r = row.attestation.record, occurrence = records[i]!, g = Number(r.generation) - 1, b = bindings.bindings.rows[g]?.item;
      if (r.recordHash !== occurrence.receipt.recordHash || !b || !b.accepted || b.artistId !== occurrence.receipt.artistId || b.generation !== r.generation) throw Error("Historical attestation binding/Artist occurrence mismatch");
    }
    const disputes = native.filter(j => [44n, 45n, 61n].includes(j.receipt.operation)), repudiations = native.filter(j => j.receipt.operation === 47n);
    if (disputes.length !== d.disputes.length || repudiations.length !== d.repudiations.length) throw Error("Incomplete dispute/repudiation native partition");
    for (let i = 0; i < disputes.length; i++) {
      const r = d.disputes[i]!, j = disputes[i]!, action = r.record.terms.disputeAction, g = Number(r.record.terms.bindingGeneration) - 1, b = bindings.bindings.rows[g]?.item;
      if (!b || r.record.artistId !== b.artistId || r.record.bindingHash !== b.bindingHash || j.receipt.recordHash !== r.record.recordHash || j.receipt.artistId !== r.record.artistId
        || j.receipt.operation !== (action === 1n ? 44n : action === 2n ? 61n : action === 3n ? 45n : 0n) || !samePoint(j.position.point, r.point)
        || r.record.governanceActionId === Z && !scope.artists.some(a => a.artistId === r.record.standing.artistId)) throw Error("Original dispute principal/standing/occurrence mismatch");
    }
    for (let i = 0; i < repudiations.length; i++) {
      const r = d.repudiations[i]!, j = repudiations[i]!, b = bindings.bindings.rows[Number(r.record.terms.bindingGeneration) - 1]?.item;
      if (!b || r.record.artistId !== b.artistId || r.record.bindingHash !== b.bindingHash || j.receipt.recordHash !== r.record.recordHash || j.receipt.artistId !== r.record.artistId || !samePoint(j.position.point, r.point)) throw Error("Original repudiation principal/occurrence mismatch");
      if (r.terminal.phase === 2n) vetoes++;
    }
    const platform = v.platforms[k]!, platformRows: { hash: Hex; op: bigint; point: shared.ArtistRecoveredHydrationPoint }[] = [];
    if (platform.state.declaration.recordHash !== Z) platformRows.push({ hash: platform.state.declaration.recordHash, op: 8n, point: platform.declarationPoint });
    if (platform.state.correction.recordHash !== Z) platformRows.push({ hash: platform.state.correction.recordHash, op: 53n, point: platform.correctionPoint });
    platformRows.push(...platform.claims.map(r => ({ hash: r.record.recordHash, op: 9n, point: r.point })), ...platform.contests.map(r => ({ hash: r.record.recordHash, op: 11n, point: r.point })), ...platform.allegations.map(r => ({ hash: r.record.recordHash, op: 10n, point: r.point })));
    const nativePlatform = native.filter(j => platformOperation(j.receipt.operation));
    if (native.some(j => ![24n, 44n, 45n, 47n, 61n].includes(j.receipt.operation) && !platformOperation(j.receipt.operation)) || nativePlatform.length !== platformRows.length) throw Error("Unsupported or incomplete owner4 native family");
    for (const r of platformRows) if (nativePlatform.filter(j => j.receipt.recordHash === r.hash && j.receipt.operation === r.op && j.receipt.artistId === Z && samePoint(j.position.point, r.point)).length !== 1) throw Error("Original Platform native occurrence mismatch");
    validateConsentOccurrences(c, q, bindings, p.journals[6].filter(j => j.receipt.collectionId === q.collectionId), sanctions);
  }
  if (p.journals[2].filter(j => j.receipt.operation === 48n).length !== 2 * vetoes) throw Error("Global Identity veto-pair count mismatch");
}

function validateConsentOccurrences(c: ArtistCompleteHistoryHydrationConsentsSupplement, q: ArtistHydrationQuery, bindings: ArtistCompleteHistoryHydrationBindingBundle,
  journal: readonly shared.ArtistRecoveredHydrationJournalEntry[], sanctions: ArtistCompleteHistoryHydrationSanctionInventory | undefined): void {
  const b = c.original.rows, old = b.original, families = [old.policies, old.economics, old.sales, b.consents, b.royalties, b.freezes, c.ratifications];
  if (families.some(rows => rows.length > 128)) throw Error("Consent family exceeds original row capacity");
  const seen = new Set<Hex>(), counters = new Map<bigint, number>();
  const historical = (artist: Hex): boolean => bindings.bindings.rows.some(r => r.item.artistId === artist);
  const accepted = (artist: Hex, generation: bigint): boolean => { const r = bindings.bindings.rows[Number(generation) - 1]?.item; return !!r && r.accepted && r.artistId === artist; };
  for (const j of journal) {
    const r = j.receipt, i = counters.get(r.operation) ?? 0; counters.set(r.operation, i + 1);
    if (seen.has(r.recordHash) || !historical(r.artistId)) throw Error("Consent native principal or duplicate record mismatch"); seen.add(r.recordHash);
    let hash_: Hex | undefined, artist: Hex | undefined;
    switch (r.operation) {
      case 12n: { const s = sanctions?.sanctions.find(s => s.record.recordHash === r.recordHash); hash_ = s?.record.recordHash; artist = s?.record.artistId; if (s && !samePoint(s.point, j.position.point)) throw Error("Sanction native point mismatch"); break; }
      case 14n: hash_ = old.policies.find(p => p.recordHash === r.recordHash)?.recordHash; break;
      case 15n: { const e = old.economics[i]?.item; hash_ = e?.recordHash; artist = e?.association.artistId;
        if (e && (e.terms.collectionId !== q.collectionId || !accepted(e.association.artistId, e.association.bindingGeneration)
          || e.association.bindingHash !== bindings.bindings.rows[Number(e.association.bindingGeneration) - 1]?.item.bindingHash || e.association.payloadHash !== hash([shared.ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE], [e.terms]))) throw Error("Economics original historical binding/payload mismatch"); break; }
      case 16n: { const s = old.sales[i]?.item; hash_ = s?.recordHash; artist = s?.artistId; if (s && (s.terms.collectionId !== q.collectionId || !accepted(s.artistId, s.bindingGeneration) || s.bindingHash !== bindings.bindings.rows[Number(s.bindingGeneration) - 1]?.item.bindingHash)) throw Error("Sale historical binding mismatch"); break; }
      case 17n: { const s = b.consents[i]; hash_ = s?.recordHash; artist = s?.artistId; if (s && (!accepted(s.artistId, s.bindingGeneration) || s.terms.collectionId !== q.collectionId)) throw Error("Content historical binding mismatch"); break; }
      case 20n: { const s = b.royalties[i]; hash_ = s?.item.recordHash; artist = s?.item.artistId; if (s && (!accepted(s.item.artistId, s.item.bindingGeneration) || s.terms.collectionId !== q.collectionId)) throw Error("Royalty historical binding mismatch"); break; }
      case 21n: { const s = b.freezes[i]; hash_ = s?.recordHash; artist = s?.artistId; if (s && !accepted(s.artistId, s.bindingGeneration)) throw Error("Freeze historical binding mismatch"); break; }
      case 52n: { const s = c.ratifications[i]; hash_ = s?.recordHash; if (s && (s.contentStateHash === Z || s.metadataContract === ZeroAddress)) throw Error("Invalid original ratification record"); break; }
      default: throw Error("Unsupported complete owner6 native family");
    }
    if (hash_ !== r.recordHash || artist !== undefined && artist !== r.artistId) throw Error("Complete consent native record/Artist partition mismatch");
  }
  for (const [op, rows] of [[14n, old.policies], [15n, old.economics], [16n, old.sales], [17n, b.consents], [20n, b.royalties], [21n, b.freezes], [52n, c.ratifications]] as const) if ((counters.get(op) ?? 0) !== rows.length) throw Error("Trailing or missing consent occurrence rows");
}

function validateWitnessRows(request: shared.ArtistRecoveredHydrationRequest, composition: ArtistCompleteHistoryHydrationComposition): void {
  const r = codec.normalizeArtistRecoveredHydrationRequest(request), p = composition.inventory.provenance;
  const selected = composition.states[0]!.collections.filter(q => p.journals[6].some(j => j.receipt.collectionId === q.collectionId && j.receipt.operation === 15n) || p.journals[4].some(j => j.receipt.collectionId === q.collectionId && j.receipt.operation === 24n));
  if (r.records.witnesses.length !== selected.length) throw Error("Complete witness selection count mismatch");
  for (let i = 0; i < selected.length; i++) {
    const q = selected[i]!, k = composition.states[0]!.collections.findIndex(c => c.collectionId === q.collectionId), w = r.records.witnesses[i]!;
    if (w.collectionId !== q.collectionId || !same(`${shared.ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE}[]`, w.economics, composition.consents[k]!.original.rows.original.economics.map(e => e.item.terms))
      || !same(`${shared.ARTIST_RECOVERED_HYDRATION_ATTESTATION_INPUT_TUPLE}[]`, w.attestations, composition.attributions[k]!.records.records.map(a => a.attestation.input))) throw Error("Submitted witnesses differ from original collection occurrence order");
  }
}
export function validateArtistCompleteHistoryHydrationInput(value: ArtistCompleteHistoryHydrationInput, prepared: shared.ArtistRecoveredHydrationPrepared): ArtistCompleteHistoryHydrationInput {
  const input = normalizeArtistCompleteHistoryHydrationInput(value), p = codec.normalizeArtistRecoveredHydrationPrepared(prepared), composition = compose(p);
  codec.encodeArtistRecoveredHydrationProfileEvidence(input.request, p); validateWitnessRows(input.request, composition);
  const terms: ArtistCompleteHistoryHydrationRoyaltyFreeze[] = [];
  for (const j of composition.inventory.provenance.journals[6]) if (j.receipt.operation === 20n) {
    const k = composition.states[6]!.collections.findIndex(c => c.collectionId === j.receipt.collectionId), row = composition.consents[k]!.original.rows.royalties.find(r => r.item.recordHash === j.receipt.recordHash);
    if (!row) throw Error("Missing original royalty witness"); terms.push(row.terms);
  }
  if (!same(`${ARTIST_COMPLETE_HISTORY_HYDRATION_ROYALTY_FREEZE_TUPLE}[]`, terms, input.royaltyFreezes)) throw Error("Royalty witnesses differ from full global operation20 order");
  return input;
}

/** Local historical carrier authentication. Current source and private family admission remain unverified. */
export function decodeArtistCompleteHistoryHydrationProfileEvidence(raw: Hex): shared.ArtistRecoveredHydrationProfileEvidence {
  const types = ["bytes32", "uint16", "address", "address", shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE, `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, ARTIST_HYDRATION_QUERY_TUPLE, `${ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`, shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, shared.ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE];
  preflight(types, raw);
  const e = codec.decodeArtistRecoveredHydrationProfileEvidence(raw), r = codec.normalizeArtistRecoveredHydrationRequest(e.request), first = decodeArtistCompleteHistoryHydrationOwnerPayload(e.data[0].typedState, 0),
    decoded = decodeArtistCompleteHistoryHydrationAuxiliary(first.payload.semanticState, 0, first.payload.provenance), inventory = decodeArtistCompleteHistoryHydrationInventory(decoded.auxiliary), p = inventory.provenance;
  const graph = { query: e.query, data: e.data, timing: e.timing, admission: { artists: e.artists, collections: e.collections, provenance: p } }, composition = compose(graph);
  const last = p.eras.at(-1)!, source = p.origins.at(-1)!, a = r.records.authority;
  if (e.prior !== source.registry || e.sourceCoordinator !== source.coordinator || r.expectedSourceImportCommitment !== last.priorImportCommitment
    || !same(`${ARTIST_HYDRATION_CHECKPOINT_TUPLE}[7]`, a.expectedSource, last.checkpoints) || !same("bytes32[]", a.artistIds, e.artists.map(a => a.artistId))
    || a.collections.length !== e.collections.length || a.collections.some((c, i) => c.artistId !== e.collections[i]!.artistId || c.collectionId !== e.collections[i]!.collectionId || !same(`${ARTIST_HYDRATION_POLICY_TUPLE}[]`, c.policies, e.collections[i]!.policies))) throw Error("Retained evidence request/source selection mismatch");
  for (let i = 0; i < 7; i++) {
    const index = owner(i), data = e.data[index], local = decodeArtistCompleteHistoryHydrationOwnerPayload(data.typedState, index);
    codec.validateArtistRecoveredHydrationCapability(r.expectedCapabilities[index], index, local.header.requiredFeatures);
    if (data.nonces.length || BigInt(data.origins.length) !== last.checkpoints[index].replayCount || data.sourceKeys.length !== data.origins.length || data.cells.length !== data.origins.length
      || !same("tuple(bytes32 surface,bytes32 scope)[]", data.origins, a.replayOrigins[index])) throw Error("Retained evidence guard insertion-order mismatch");
    const seen = new Set<Hex>();
    for (let j = 0; j < data.origins.length; j++) {
      const logical = data.origins[j]!, key = codec.artistRecoveredHydrationReplayKey(source, index, logical), alias = p.aliases[index].find(x => x.originalKey === key);
      if (!alias || seen.has(key) || alias.originHash !== last.originHash || data.sourceKeys[j] !== key || alias.surface !== logical.surface || alias.scope !== logical.scope
        || !same("tuple(bytes32 commitment,uint64 touchedRevision,uint8 kind,uint8 status)", alias.cell, data.cells[j])) throw Error("Retained evidence guard differs from original replay alias");
      seen.add(key);
    }
  }
  codec.normalizeArtistRecoveredHydrationTimingCheckpoint(e.timing); codec.normalizeArtistRecoveredHydrationExternalGuards(e.externalGuards);
  if (e.externalGuards.artistId !== (e.artists[0]?.artistId ?? Z) || e.externalGuards.provenanceCommitment !== codec.artistRecoveredHydrationProvenanceHash(p)) throw Error("Retained external guards belong to another complete scope");
  const expected = hash(["bytes32", "uint16", "bytes32", ARTIST_HYDRATION_QUERY_TUPLE, `${ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`, shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, shared.ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE], [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, codec.artistRecoveredHydrationProvenanceHash(p), e.query, e.data, e.timing, e.externalGuards]);
  if (expected !== r.expectedSemanticInventory) throw Error("Retained semantic inventory commitment mismatch");
  validateWitnessRows(r, composition);
  return e;
}
