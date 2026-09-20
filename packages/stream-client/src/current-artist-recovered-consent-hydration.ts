import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { ArtistHydrationQuery, ArtistHydrationSuite, ArtistHydrationSale, ArtistHydrationPolicyKey } from "./current-artist-authority-hydration.js";
import { ARTIST_HYDRATION_SUITE_TUPLE, ARTIST_HYDRATION_POLICY_TUPLE, ARTIST_HYDRATION_QUERY_TUPLE } from "./current-artist-authority-hydration.js";
import * as shared from "./internal/artist-recovered-hydration-codec.js";

export const ARTIST_RECOVERED_CONSENT_HYDRATION_SOURCE = "836b9c64e1f0630d4e79e6cee831450059616fd7";
export const ARTIST_RECOVERED_CONSENT_HYDRATION_SHAPES = Object.freeze({ ...shared.ARTIST_RECOVERED_HYDRATION_SHAPES, content: 511n });
export type {
  ArtistRecoveredHydrationCapability as ArtistRecoveredConsentHydrationCapability,
  ArtistRecoveredHydrationEconomicsConsent as ArtistRecoveredConsentHydrationEconomicsConsent,
  ArtistRecoveredHydrationAttestation as ArtistRecoveredConsentHydrationAttestation,
  ArtistRecoveredHydrationAttestationInput as ArtistRecoveredConsentHydrationAttestationInput,
  ArtistRecoveredHydrationCollectionWitness as ArtistRecoveredConsentHydrationCollectionWitness,
  ArtistRecoveredHydrationRecordsRequest as ArtistRecoveredConsentHydrationRecordsRequest,
  ArtistRecoveredHydrationRequest as ArtistRecoveredConsentHydrationRequest,
  ArtistRecoveredHydrationExportHeader as ArtistRecoveredConsentHydrationExportHeader,
  ArtistRecoveredHydrationOriginEnvironment as ArtistRecoveredConsentHydrationOriginEnvironment,
  ArtistRecoveredHydrationEra as ArtistRecoveredConsentHydrationEra,
  ArtistRecoveredHydrationPoint as ArtistRecoveredConsentHydrationPoint,
  ArtistRecoveredHydrationPosition as ArtistRecoveredConsentHydrationPosition,
  ArtistRecoveredHydrationJournalEntry as ArtistRecoveredConsentHydrationJournalEntry,
  ArtistRecoveredHydrationReplayAlias as ArtistRecoveredConsentHydrationReplayAlias,
  ArtistRecoveredHydrationProvenance as ArtistRecoveredConsentHydrationProvenance,
  ArtistRecoveredHydrationOwnerEra as ArtistRecoveredConsentHydrationOwnerEra,
  ArtistRecoveredHydrationOwnerProvenance as ArtistRecoveredConsentHydrationOwnerProvenance,
  ArtistRecoveredHydrationNonceInventory as ArtistRecoveredConsentHydrationNonceInventory,
  ArtistRecoveredHydrationEnvelope as ArtistRecoveredConsentHydrationEnvelope,
  ArtistRecoveredHydrationPublication as ArtistRecoveredConsentHydrationPublication,
  ArtistRecoveredHydrationOwnerPayload as ArtistRecoveredConsentHydrationOwnerPayload,
  ArtistRecoveredHydrationTimingConfiguration as ArtistRecoveredConsentHydrationTimingConfiguration,
  ArtistRecoveredHydrationTimingInput as ArtistRecoveredConsentHydrationTimingInput,
  ArtistRecoveredHydrationTimingEntry as ArtistRecoveredConsentHydrationTimingEntry,
  ArtistRecoveredHydrationTimingCheckpoint as ArtistRecoveredConsentHydrationTimingCheckpoint,
  ArtistRecoveredHydrationTimingBundle as ArtistRecoveredConsentHydrationTimingBundle,
  ArtistRecoveredHydrationActionWitness as ArtistRecoveredConsentHydrationActionWitness,
  ArtistRecoveredHydrationActionFacts as ArtistRecoveredConsentHydrationActionFacts,
  ArtistRecoveredHydrationActionGuard as ArtistRecoveredConsentHydrationActionGuard,
  ArtistRecoveredHydrationFinalityScope as ArtistRecoveredConsentHydrationFinalityScope,
  ArtistRecoveredHydrationFinalityComponent as ArtistRecoveredConsentHydrationFinalityComponent,
  ArtistRecoveredHydrationFinalityManifest as ArtistRecoveredConsentHydrationFinalityManifest,
  ArtistRecoveredHydrationFinalityEvidence as ArtistRecoveredConsentHydrationFinalityEvidence,
  ArtistRecoveredHydrationFinalityRecord as ArtistRecoveredConsentHydrationFinalityRecord,
  ArtistRecoveredHydrationFinalityTarget as ArtistRecoveredConsentHydrationFinalityTarget,
  ArtistRecoveredHydrationFinalityGuard as ArtistRecoveredConsentHydrationFinalityGuard,
  ArtistRecoveredHydrationEntropyReceipt as ArtistRecoveredConsentHydrationEntropyReceipt,
  ArtistRecoveredHydrationEntropyEvidence as ArtistRecoveredConsentHydrationEntropyEvidence,
  ArtistRecoveredHydrationEntropyGuard as ArtistRecoveredConsentHydrationEntropyGuard,
  ArtistRecoveredHydrationExternalGuards as ArtistRecoveredConsentHydrationExternalGuards,
  ArtistRecoveredHydrationCertificate as ArtistRecoveredConsentHydrationCertificate,
  ArtistRecoveredHydrationPrepared as ArtistRecoveredConsentHydrationPrepared,
  ArtistRecoveredHydrationEvidenceDescriptor as ArtistRecoveredConsentHydrationEvidenceDescriptor,
  ArtistRecoveredHydrationCoordinates as ArtistRecoveredConsentHydrationCoordinates,
  ArtistRecoveredHydrationProfileEvidence as ArtistRecoveredConsentHydrationProfileEvidence,
  ArtistRecoveredHydrationOperationEvidence as ArtistRecoveredConsentHydrationOperationEvidence,
  ArtistRecoveredHydrationHistoricalCell as ArtistRecoveredConsentHydrationHistoricalCell,
  ArtistRecoveredHydrationFeatureFacts as ArtistRecoveredConsentHydrationFeatureFacts
} from "./internal/artist-recovered-hydration-codec.js";
export {
  ARTIST_RECOVERED_HYDRATION_PROFILE as ARTIST_RECOVERED_CONSENT_HYDRATION_PROFILE,
  ARTIST_RECOVERED_HYDRATION_PAGE_BYTES as ARTIST_RECOVERED_CONSENT_HYDRATION_PAGE_BYTES,
  ARTIST_RECOVERED_HYDRATION_MAX_BYTES as ARTIST_RECOVERED_CONSENT_HYDRATION_MAX_BYTES,
  ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES as ARTIST_RECOVERED_CONSENT_HYDRATION_MAX_PREPARED_BYTES,
  ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA as ARTIST_RECOVERED_CONSENT_HYDRATION_CHECKPOINT_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_PAYLOAD_SCHEMA as ARTIST_RECOVERED_CONSENT_HYDRATION_PAYLOAD_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_EVIDENCE_SCHEMA as ARTIST_RECOVERED_CONSENT_HYDRATION_EVIDENCE_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_CAPABILITY_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_CAPABILITY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_ECONOMICS_CONSENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ATTESTATION_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_ATTESTATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ATTESTATION_INPUT_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_ATTESTATION_INPUT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_COLLECTION_WITNESS_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_COLLECTION_WITNESS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_RECORDS_REQUEST_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_RECORDS_REQUEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_REQUEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EXPORT_HEADER_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_EXPORT_HEADER_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ERA_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_ERA_TUPLE,
  ARTIST_RECOVERED_HYDRATION_POINT_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_POINT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_POSITION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_JOURNAL_ENTRY_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_JOURNAL_ENTRY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_REPLAY_ALIAS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PROVENANCE_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_PROVENANCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_ERA_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_OWNER_ERA_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_OWNER_PROVENANCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_NONCE_INVENTORY_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_NONCE_INVENTORY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_ENVELOPE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PUBLICATION_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_PUBLICATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_PAYLOAD_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_OWNER_PAYLOAD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_CONFIGURATION_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_TIMING_CONFIGURATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_INPUT_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_TIMING_INPUT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_ENTRY_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_TIMING_ENTRY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_TIMING_CHECKPOINT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_BUNDLE_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_TIMING_BUNDLE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_WITNESS_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_ACTION_WITNESS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_FACTS_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_ACTION_FACTS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_GUARD_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_ACTION_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_SCOPE_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_FINALITY_SCOPE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_COMPONENT_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_FINALITY_COMPONENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_MANIFEST_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_FINALITY_MANIFEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_EVIDENCE_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_FINALITY_EVIDENCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_RECORD_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_FINALITY_RECORD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_TARGET_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_FINALITY_TARGET_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_GUARD_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_FINALITY_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_RECEIPT_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_ENTROPY_RECEIPT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_EVIDENCE_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_ENTROPY_EVIDENCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_GUARD_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_ENTROPY_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_EXTERNAL_GUARDS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_CERTIFICATE_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_CERTIFICATE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_PREPARED_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE as ARTIST_RECOVERED_CONSENT_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE
} from "./internal/artist-recovered-hydration-codec.js";

const codec: ReturnType<typeof shared.createArtistRecoveredHydrationCodec> = shared.createArtistRecoveredHydrationCodec(511n);
export const {
  artistRecoveredHydrationOwnerDomain: artistRecoveredConsentHydrationOwnerDomain,
  artistRecoveredHydrationOwnerTag: artistRecoveredConsentHydrationOwnerTag,
  normalizeArtistRecoveredHydrationCoordinates: normalizeArtistRecoveredConsentHydrationCoordinates,
  normalizeArtistRecoveredHydrationCapability: normalizeArtistRecoveredConsentHydrationCapability,
  validateArtistRecoveredHydrationCapability: validateArtistRecoveredConsentHydrationCapability,
  normalizeArtistRecoveredHydrationRequestDraft: normalizeArtistRecoveredConsentHydrationRequestDraft,
  normalizeArtistRecoveredHydrationRequest: normalizeArtistRecoveredConsentHydrationRequest,
  encodeArtistRecoveredHydrationRequest: encodeArtistRecoveredConsentHydrationRequest,
  decodeArtistRecoveredHydrationRequest: decodeArtistRecoveredConsentHydrationRequest,
  normalizeArtistRecoveredHydrationOriginEnvironment: normalizeArtistRecoveredConsentHydrationOriginEnvironment,
  artistRecoveredHydrationOriginHash: artistRecoveredConsentHydrationOriginHash,
  artistRecoveredHydrationReplayKey: artistRecoveredConsentHydrationReplayKey,
  normalizeArtistRecoveredHydrationOwnerProvenance: normalizeArtistRecoveredConsentHydrationOwnerProvenance,
  artistRecoveredHydrationOwnerProvenance: artistRecoveredConsentHydrationOwnerProvenance,
  normalizeArtistRecoveredHydrationProvenance: normalizeArtistRecoveredConsentHydrationProvenance,
  artistRecoveredHydrationProvenanceHash: artistRecoveredConsentHydrationProvenanceHash,
  artistRecoveredHydrationOwnerProvenanceHash: artistRecoveredConsentHydrationOwnerProvenanceHash,
  artistRecoveredHydrationAliasesHash: artistRecoveredConsentHydrationAliasesHash,
  compareArtistRecoveredHydrationPoints: compareArtistRecoveredConsentHydrationPoints,
  normalizeArtistRecoveredHydrationNonceInventory: normalizeArtistRecoveredConsentHydrationNonceInventory,
  normalizeArtistRecoveredHydrationPublications: normalizeArtistRecoveredConsentHydrationPublications,
  normalizeArtistRecoveredHydrationOwnerPayload: normalizeArtistRecoveredConsentHydrationOwnerPayload,
  encodeArtistRecoveredHydrationOwnerPayload: encodeArtistRecoveredConsentHydrationOwnerPayload,
  decodeArtistRecoveredHydrationOwnerPayload: decodeArtistRecoveredConsentHydrationOwnerPayload,
  normalizeArtistRecoveredHydrationTimingCheckpoint: normalizeArtistRecoveredConsentHydrationTimingCheckpoint,
  normalizeArtistRecoveredHydrationExternalGuards: normalizeArtistRecoveredConsentHydrationExternalGuards,
  decodeArtistRecoveredHydrationProfileEvidence: decodeArtistRecoveredConsentHydrationProfileEvidence,
  normalizeArtistRecoveredHydrationEvidenceDescriptor: normalizeArtistRecoveredConsentHydrationEvidenceDescriptor,
  artistRecoveredHydrationEvidenceDescriptor: artistRecoveredConsentHydrationEvidenceDescriptor,
  artistRecoveredHydrationEvidencePages: artistRecoveredConsentHydrationEvidencePages,
  assembleArtistRecoveredHydrationEvidence: assembleArtistRecoveredConsentHydrationEvidence,
  artistRecoveredHydrationPageId: artistRecoveredConsentHydrationPageId,
  artistRecoveredHydrationEvidenceId: artistRecoveredConsentHydrationEvidenceId,
  encodeArtistRecoveredHydrationEvidenceCarrier: encodeArtistRecoveredConsentHydrationEvidenceCarrier,
  decodeArtistRecoveredHydrationEvidenceCarrier: decodeArtistRecoveredConsentHydrationEvidenceCarrier,
  encodeArtistRecoveredHydrationOperationEvidence: encodeArtistRecoveredConsentHydrationOperationEvidence,
  decodeArtistRecoveredHydrationOperationEvidence: decodeArtistRecoveredConsentHydrationOperationEvidence,
  artistRecoveredHydrationOwnerReplayDelta: artistRecoveredConsentHydrationOwnerReplayDelta,
  artistRecoveredHydrationOwnerAfter: artistRecoveredConsentHydrationOwnerAfter
} = codec;

export interface ArtistRecoveredConsentHydrationRoyaltyFreeze {
  readonly resolver: Address;
  readonly collectionId: bigint;
  readonly revenueClass: Hex;
  readonly expectedAssignmentHash: Hex;
}

export interface ArtistRecoveredConsentHydrationInput {
  readonly request: shared.ArtistRecoveredHydrationRequest;
  readonly royaltyFreezes: readonly ArtistRecoveredConsentHydrationRoyaltyFreeze[];
}

export interface ArtistRecoveredConsentHydrationCall {
  readonly registry: Address;
  readonly caller: Address;
  readonly request: shared.ArtistRecoveredHydrationRequest;
  readonly royaltyFreezes: readonly ArtistRecoveredConsentHydrationRoyaltyFreeze[];
  readonly profile: Hex;
  readonly capabilityId: Hex;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export interface ArtistRecoveredConsentHydrationContentTerms {
  readonly collectionId: bigint;
  readonly metadataContract: Address;
  readonly familyId: Hex;
  readonly newStateHash: Hex;
}

export interface ArtistRecoveredConsentHydrationContentRecord {
  readonly recordHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly terms: ArtistRecoveredConsentHydrationContentTerms;
  readonly authorityClass: bigint;
}

export interface ArtistRecoveredConsentHydrationRoyaltyRecord {
  readonly recordHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
}

export interface ArtistRecoveredConsentHydrationRoyalty {
  readonly terms: ArtistRecoveredConsentHydrationRoyaltyFreeze;
  readonly item: ArtistRecoveredConsentHydrationRoyaltyRecord;
  readonly grant: Hex;
}

export interface ArtistRecoveredConsentHydrationFreezeRecord {
  readonly recordHash: Hex;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly metadataContract: Address;
  readonly lockClasses: readonly Hex[];
  readonly expectedStateHash: Hex;
  readonly authorityClass: bigint;
}

export interface ArtistRecoveredConsentHydrationEconomicsAssociation {
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly payloadHash: Hex;
  readonly originalRecord: Hex;
}

export interface ArtistRecoveredConsentHydrationEconomics {
  readonly item: {
    readonly recordHash: Hex;
    readonly terms: shared.ArtistRecoveredHydrationEconomicsConsent;
    readonly association: ArtistRecoveredConsentHydrationEconomicsAssociation;
  };
  readonly grant: Hex;
}

export interface ArtistRecoveredConsentHydrationOriginalBundle {
  readonly provenance: Hex;
  readonly artistId: Hex;
  readonly collectionId: bigint;
  readonly bindingHash: Hex;
  readonly keys: readonly ArtistHydrationPolicyKey[];
  readonly policies: readonly { readonly recordHash: Hex; readonly grant: Hex }[];
  readonly economics: readonly ArtistRecoveredConsentHydrationEconomics[];
  readonly sales: readonly ArtistHydrationSale[];
}

export interface ArtistRecoveredConsentHydrationContentBundle {
  readonly original: ArtistRecoveredConsentHydrationOriginalBundle;
  readonly consents: readonly ArtistRecoveredConsentHydrationContentRecord[];
  readonly royalties: readonly ArtistRecoveredConsentHydrationRoyalty[];
  readonly freezes: readonly ArtistRecoveredConsentHydrationFreezeRecord[];
}

export const ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE = "tuple(address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash)";
export const ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_TERMS_TUPLE = "tuple(uint256 collectionId,address metadataContract,bytes32 familyId,bytes32 newStateHash)";
export const ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_RECORD_TUPLE = `tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,${ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_TERMS_TUPLE} terms,uint8 authorityClass)`;
export const ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_RECORD_TUPLE = "tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration)";
export const ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_TUPLE = `tuple(${ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE} terms,${ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_RECORD_TUPLE} item,bytes32 grant)`;
export const ARTIST_RECOVERED_CONSENT_HYDRATION_FREEZE_RECORD_TUPLE = "tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,address metadataContract,bytes32[] lockClasses,bytes32 expectedStateHash,uint8 authorityClass)";
export const ARTIST_RECOVERED_CONSENT_HYDRATION_ECONOMICS_ASSOCIATION_TUPLE = "tuple(bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 payloadHash,bytes32 originalRecord)";
export const ARTIST_RECOVERED_CONSENT_HYDRATION_ECONOMICS_TUPLE = `tuple(tuple(bytes32 recordHash,${shared.ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE} terms,${ARTIST_RECOVERED_CONSENT_HYDRATION_ECONOMICS_ASSOCIATION_TUPLE} association) item,bytes32 grant)`;
const saleTuple = "tuple(tuple(bytes32 recordHash,tuple(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash) terms,bytes32 artistId,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,uint64 bindingGeneration,bytes32 bindingHash) item,bytes32 grant,bytes32 current)";
export const ARTIST_RECOVERED_CONSENT_HYDRATION_ORIGINAL_BUNDLE_TUPLE = `tuple(bytes32 provenance,bytes32 artistId,uint256 collectionId,bytes32 bindingHash,${ARTIST_HYDRATION_POLICY_TUPLE}[] keys,tuple(bytes32 recordHash,bytes32 grant)[] policies,${ARTIST_RECOVERED_CONSENT_HYDRATION_ECONOMICS_TUPLE}[] economics,${saleTuple}[] sales)`;
export const ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_BUNDLE_TUPLE = `tuple(${ARTIST_RECOVERED_CONSENT_HYDRATION_ORIGINAL_BUNDLE_TUPLE} original,${ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_RECORD_TUPLE}[] consents,${ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_TUPLE}[] royalties,${ARTIST_RECOVERED_CONSENT_HYDRATION_FREEZE_RECORD_TUPLE}[] freezes)`;
export const ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_SCHEMA = id("6529STREAM_ARTIST_RECOVERED_CONTENT_CONSENTS_V1") as Hex;
export const ARTIST_RECOVERED_CONSENT_HYDRATION_PREPARE_SELECTOR = "0x4925300f" as Hex;
export const CURRENT_ARTIST_RECOVERED_CONSENT_HYDRATION_ABI = Object.freeze([
  `function hydrateRecoveredArtistAuthorityWithConsents(${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,${ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE}[] royaltyFreezes) returns(bytes32)`,
]);
export const ARTIST_RECOVERED_CONSENT_HYDRATION_PREPARE_ABI = Object.freeze([
  `function prepare(${ARTIST_HYDRATION_SUITE_TUPLE} destination,${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,${ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE}[] royaltyFreezes) view returns(${shared.ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE} prepared)`,
]);
const abi = new Interface(CURRENT_ARTIST_RECOVERED_CONSENT_HYDRATION_ABI);
export const ARTIST_RECOVERED_CONSENT_HYDRATION_CAPABILITY_ID = abi.getFunction("hydrateRecoveredArtistAuthorityWithConsents")!.selector as Hex;
const coder = AbiCoder.defaultAbiCoder();
const ZERO = ZeroHash as Hex;
const hash = (types: readonly string[], values: readonly unknown[]): Hex => keccak256(coder.encode(types, values)) as Hex;
const equal = (type: string, a: unknown, b: unknown): boolean => hash([type], [a]) === hash([type], [b]);

export function normalizeArtistRecoveredConsentHydrationRoyaltyFreezes(
  value: readonly ArtistRecoveredConsentHydrationRoyaltyFreeze[],
  collectionId: bigint,
): readonly ArtistRecoveredConsentHydrationRoyaltyFreeze[] {
  codec.boundedArray(value, 128);
  const rows = codec.normalizeTuple(`${ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE}[]`, value);
  const seen = new Set<Hex>();
  for (const row of rows) {
    if (row.resolver === ZeroAddress || row.collectionId !== collectionId || !row.collectionId
      || row.revenueClass !== id("ROYALTY_ERC2981") || row.expectedAssignmentHash === ZERO) {
      throw Error("Invalid original royalty-freeze selector");
    }
    const key = hash([ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE], [row]);
    if (seen.has(key)) throw Error("Duplicate original royalty-freeze scope");
    seen.add(key);
  }
  return rows;
}

export function normalizeArtistRecoveredConsentHydrationInputDraft(
  value: ArtistRecoveredConsentHydrationInput,
): ArtistRecoveredConsentHydrationInput {
  codec.exactFields(value, ["request", "royaltyFreezes"]);
  const request = codec.normalizeArtistRecoveredHydrationRequestDraft(value.request);
  const royaltyFreezes = normalizeArtistRecoveredConsentHydrationRoyaltyFreezes(value.royaltyFreezes, request.records.authority.collections[0]!.collectionId);
  return Object.freeze({ request, royaltyFreezes });
}

export function normalizeArtistRecoveredConsentHydrationInput(
  value: ArtistRecoveredConsentHydrationInput,
): ArtistRecoveredConsentHydrationInput {
  const result = normalizeArtistRecoveredConsentHydrationInputDraft(value);
  codec.normalizeArtistRecoveredHydrationRequest(result.request);
  return result;
}

export function prepareArtistRecoveredConsentHydrationCall(
  registry: Address,
  caller: Address,
  input: ArtistRecoveredConsentHydrationInput,
): ArtistRecoveredConsentHydrationCall {
  const target = getAddress(registry) as Address;
  const actor = getAddress(caller) as Address;
  if (target === ZeroAddress || actor === ZeroAddress) throw Error("Expected actual Registry and actor");
  const value = normalizeArtistRecoveredConsentHydrationInput(input);
  const data = codec.boundedBytes(abi.encodeFunctionData("hydrateRecoveredArtistAuthorityWithConsents", [value.request, value.royaltyFreezes]));
  return Object.freeze({ registry: target, caller: actor, ...value, profile: shared.ARTIST_RECOVERED_HYDRATION_PROFILE,
    capabilityId: ARTIST_RECOVERED_CONSENT_HYDRATION_CAPABILITY_ID,
    call: Object.freeze({ to: target, value: 0n, data }), factsVerified: false });
}

export function normalizeArtistRecoveredConsentHydrationCall(
  value: ArtistRecoveredConsentHydrationCall,
): ArtistRecoveredConsentHydrationCall {
  codec.exactFields(value, ["registry", "caller", "request", "royaltyFreezes", "profile", "capabilityId", "call", "factsVerified"]);
  const rebuilt = prepareArtistRecoveredConsentHydrationCall(value.registry, value.caller, { request: value.request, royaltyFreezes: value.royaltyFreezes });
  codec.exactFields(value.call, ["to", "value", "data"]);
  if (value.profile !== rebuilt.profile || value.capabilityId !== rebuilt.capabilityId || value.factsVerified !== false
    || getAddress(value.call.to) !== rebuilt.call.to || value.call.value !== 0n || codec.boundedBytes(value.call.data) !== rebuilt.call.data) {
    throw Error("WithConsents call differs from immutable input");
  }
  return rebuilt;
}

export function artistRecoveredConsentHydrationPreparationCalldata(
  destination: ArtistHydrationSuite,
  inputDraft: ArtistRecoveredConsentHydrationInput,
): Hex {
  const suite = codec.normalizeTuple(ARTIST_HYDRATION_SUITE_TUPLE, destination);
  const input = normalizeArtistRecoveredConsentHydrationInputDraft(inputDraft);
  const encoded = coder.encode([ARTIST_HYDRATION_SUITE_TUPLE, shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE,
    `${ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE}[]`], [suite, input.request, input.royaltyFreezes]);
  return codec.boundedBytes(`${ARTIST_RECOVERED_CONSENT_HYDRATION_PREPARE_SELECTOR}${encoded.slice(2)}`);
}

export function artistRecoveredConsentHydrationContentScope(terms: ArtistRecoveredConsentHydrationContentTerms): Hex {
  return hash([ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_TERMS_TUPLE, "uint64"],
    [codec.normalizeTuple(ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_TERMS_TUPLE, terms), 1n]);
}

export function artistRecoveredConsentHydrationRoyaltyScope(
  terms: ArtistRecoveredConsentHydrationRoyaltyFreeze,
  artistId: Hex,
): Hex {
  return hash([ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE, "bytes32", "uint64"],
    [codec.normalizeTuple(ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE, terms), codec.boundedBytes(artistId, 32), 1n]);
}

const replaySurfaces = Object.freeze({
  policy: id("consent_finality.replay.policy_consent_key"),
  economics: id("consent_finality.replay.consent_key"),
  sale: id("consent_finality.replay.sale_consent_key"),
  content: id("consent_finality.replay.content_consent_key"),
  freeze: id("consent_finality.replay.freeze_key"),
});

function saleLookup(terms: ArtistHydrationSale["item"]["terms"]): Hex {
  return hash(["uint256", "bytes32", "bytes32"], [terms.collectionId, terms.saleId, terms.saleConfigHash]);
}

function validateBaseRows(value: ArtistRecoveredConsentHydrationOriginalBundle): void {
  const policyScopes = new Set<Hex>();
  const policyRecords = new Set<Hex>();
  for (let i = 0; i < value.policies.length; i++) {
    const key = value.keys[i]!;
    const row = value.policies[i]!;
    const scope = hash(["uint256", "bytes32", "bytes32"], [value.collectionId, key.phaseId, key.policyHash]);
    if (row.recordHash === ZERO || key.phaseId === ZERO || key.policyHash === ZERO
      || policyScopes.has(scope) || policyRecords.has(row.recordHash)) throw Error("Invalid original policy row");
    policyScopes.add(scope); policyRecords.add(row.recordHash);
  }
  const economicRecords = new Set<Hex>();
  const payloads = new Set<Hex>();
  for (const { item: row } of value.economics) {
    const t = row.terms;
    const a = row.association;
    if (row.recordHash === ZERO || t.collectionId !== value.collectionId || t.resolver === ZeroAddress || t.revenueClass === ZERO
      || t.scope > 2n || t.scope === 0n && (t.scopeId !== 0n || t.assignmentHash === ZERO)
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
    if (r.recordHash === ZERO || r.artistId !== value.artistId || r.terms.collectionId !== value.collectionId
      || r.terms.saleAdapter === ZeroAddress || r.terms.saleId === ZERO || r.terms.saleConfigHash === ZERO
      || r.signer === ZeroAddress || !r.signedAt || r.bindingGeneration !== 1n || r.bindingHash !== value.bindingHash
      || (row.grant === ZERO ? r.authorityClass !== 1n && r.authorityClass !== 3n : r.authorityClass !== 2n)
      || saleRecords.has(r.recordHash) || saleTerms.has(termsHash)) throw Error("Invalid original sale row");
    saleRecords.add(r.recordHash); saleTerms.add(termsHash);
    let current = r.recordHash;
    for (let j = i + 1; j < value.sales.length; j++) {
      if (saleLookup(value.sales[j]!.item.terms) === saleLookup(r.terms)) current = value.sales[j]!.item.recordHash;
    }
    if (row.current !== current) throw Error("Sale head differs from original receipt order");
  }
}

function validateContentRows(value: ArtistRecoveredConsentHydrationContentBundle): void {
  const original = value.original;
  for (const r of value.consents) {
    if (r.recordHash === ZERO || r.artistId !== original.artistId || r.bindingGeneration !== 1n
      || r.authorityClass !== 1n && r.authorityClass !== 3n || r.terms.collectionId !== original.collectionId
      || r.terms.metadataContract === ZeroAddress || r.terms.familyId === ZERO || r.terms.newStateHash === ZERO) {
      throw Error("Invalid retained content consent");
    }
  }
  normalizeArtistRecoveredConsentHydrationRoyaltyFreezes(value.royalties.map(row => row.terms), original.collectionId);
  for (const row of value.royalties) {
    if (row.item.recordHash === ZERO || row.item.artistId !== original.artistId || row.item.bindingGeneration !== 1n) {
      throw Error("Invalid retained royalty-freeze record");
    }
  }
  for (const r of value.freezes) {
    if (r.recordHash === ZERO || r.artistId !== original.artistId || r.bindingGeneration !== 1n
      || r.authorityClass !== 1n && r.authorityClass !== 3n || r.metadataContract === ZeroAddress
      || r.expectedStateHash === ZERO || !r.lockClasses.length || r.lockClasses.length > 16) {
      throw Error("Invalid retained content-freeze record");
    }
    let previous = 0n;
    for (const lock of r.lockClasses) {
      if (BigInt(lock) <= previous) throw Error("Lock classes must be nonzero strictly ordered");
      previous = BigInt(lock);
    }
  }
}

/** Full public content-codec checks. Original absent signer/nonce/time fields are never fabricated. */
export function normalizeArtistRecoveredConsentHydrationContentBundle(
  value: ArtistRecoveredConsentHydrationContentBundle,
  query: ArtistHydrationQuery,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistRecoveredConsentHydrationContentBundle {
  const b = codec.normalizeTuple(ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_BUNDLE_TUPLE, value);
  const q = codec.normalizeTuple(ARTIST_HYDRATION_QUERY_TUPLE, query);
  const p = codec.normalizeArtistRecoveredHydrationOwnerProvenance(provenance, 6);
  const original = b.original;
  for (const rows of [original.keys, original.policies, original.economics, original.sales, b.consents, b.royalties, b.freezes]) {
    codec.boundedArray(rows, 128);
  }
  if (original.provenance !== codec.artistRecoveredHydrationOwnerProvenanceHash(p, 6) || q.artistId === ZERO
    || original.artistId !== q.artistId || !q.collectionId || original.collectionId !== q.collectionId
    || q.bindingHash === ZERO || original.bindingHash !== q.bindingHash || original.policies.length !== original.keys.length
    || !equal(`${ARTIST_HYDRATION_POLICY_TUPLE}[]`, original.keys, q.policies)
    || !(b.consents.length + b.royalties.length + b.freezes.length)
    || p.journal.length !== original.policies.length + original.economics.length + original.sales.length + b.consents.length + b.royalties.length + b.freezes.length) {
    throw Error("Content bundle is not the complete original owner6 inventory");
  }
  validateBaseRows(original);
  validateContentRows(b);
  const seen = new Set<Hex>();
  const admitted: { surface: string; scope: Hex; recordHash: Hex; point: shared.ArtistRecoveredHydrationPoint }[] = [];
  let economics = 0, sales = 0, consents = 0, royalties = 0, freezes = 0;
  for (const row of p.journal) {
    const native = row.receipt;
    if (native.artistId !== original.artistId || native.collectionId !== original.collectionId || seen.has(native.recordHash)) {
      throw Error("Invalid or duplicate original Consent occurrence");
    }
    seen.add(native.recordHash);
    let record: Hex;
    let surface: string;
    let scope: Hex;
    if (native.operation === 14n) {
      const at = original.policies.findIndex(policy => policy.recordHash === native.recordHash);
      if (at < 0) throw Error("Missing original policy row");
      record = original.policies[at]!.recordHash; surface = replaySurfaces.policy;
      scope = hash(["uint256", "bytes32", "bytes32"], [original.collectionId, original.keys[at]!.phaseId, original.keys[at]!.policyHash]);
    } else if (native.operation === 15n) {
      const r = original.economics[economics++]?.item;
      if (!r) throw Error("Missing original economics row");
      record = r.recordHash; surface = replaySurfaces.economics; scope = r.association.payloadHash;
    } else if (native.operation === 16n) {
      const r = original.sales[sales++]?.item;
      if (!r) throw Error("Missing original sale row");
      const origin = p.origins[p.eras.findIndex(era => era.originHash === row.position.point.environmentHash)]!;
      const actual = hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
        [id("6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1"), origin.chainId, origin.registry, r.terms.saleAdapter, origin.core,
          r.terms.collectionId, r.terms.saleId, r.terms.saleConfigHash, r.artistId, r.signer, r.authorityClass, r.nonce, r.signedAt]);
      if (actual !== r.recordHash) throw Error("Original sale record hash mismatch");
      record = r.recordHash; surface = replaySurfaces.sale;
      scope = hash(["tuple(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash)", "uint64", "bytes32"], [r.terms, r.bindingGeneration, r.bindingHash]);
    } else if (native.operation === 17n) {
      const r = b.consents[consents++];
      if (!r) throw Error("Missing original content consent");
      record = r.recordHash; surface = replaySurfaces.content;
      scope = hash(["bytes32", "bytes32"], [artistRecoveredConsentHydrationContentScope(r.terms), r.recordHash]);
    } else if (native.operation === 20n) {
      const r = b.royalties[royalties++];
      if (!r) throw Error("Missing original royalty-freeze row");
      record = r.item.recordHash; surface = replaySurfaces.freeze;
      scope = artistRecoveredConsentHydrationRoyaltyScope(r.terms, original.artistId);
    } else if (native.operation === 21n) {
      const r = b.freezes[freezes++];
      if (!r) throw Error("Missing original content-freeze row");
      record = r.recordHash; surface = replaySurfaces.freeze;
      scope = hash(["bytes32", "uint256", "uint64", "bytes32"], [id("CONTENT"), original.collectionId, 1n, r.recordHash]);
    } else throw Error("Unsupported original Consent operation");
    if (record !== native.recordHash) throw Error("Content-family rows are not in original native order");
    admitted.push({ recordHash: record, surface, scope, point: row.position.point });
  }
  if (economics !== original.economics.length || sales !== original.sales.length || consents !== b.consents.length
    || royalties !== b.royalties.length || freezes !== b.freezes.length) throw Error("Trailing content-family rows");
  let total = 0n, cursor = 0;
  for (let i = 0; i < p.eras.length; i++) {
    const era = p.eras[i]!;
    total += era.nativeCount;
    if (era.lowerRevision !== (i === 0 ? 0n : 1n) || era.checkpoint.ownerState.revision !== era.lowerRevision + era.nativeCount
      || era.checkpoint.nonceIndexCount !== 0n || era.checkpoint.nonceRoot !== ZERO || era.checkpoint.replayCount !== total
      || !total && era.checkpoint.replayRoot !== ZERO) throw Error("Original Consent era accounting mismatch");
    for (let j = 0n; j < era.nativeCount; j++) {
      if (p.journal[cursor++]!.position.point.ownerRevision !== era.lowerRevision + j + 1n) throw Error("Original Consent revision order mismatch");
    }
  }
  for (const alias of p.aliases) {
    const admission = admitted.find(row => row.surface === alias.surface && row.scope === alias.scope && row.recordHash === alias.cell.commitment);
    if (alias.cell.kind !== 1n || alias.cell.status !== 2n || !admission
      || !equal(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, admission.point, alias.admittedAt)) {
      throw Error("Content replay alias does not match original admission");
    }
  }
  return b;
}

export function encodeArtistRecoveredConsentHydrationContentBundle(
  value: ArtistRecoveredConsentHydrationContentBundle,
  query: ArtistHydrationQuery,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): Hex {
  return codec.encodeTupleValues(["bytes32", "uint16", ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_BUNDLE_TUPLE],
    [ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_SCHEMA, 1n, normalizeArtistRecoveredConsentHydrationContentBundle(value, query, provenance)]);
}

export function decodeArtistRecoveredConsentHydrationContentBundle(
  raw: Hex,
  query: ArtistHydrationQuery,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistRecoveredConsentHydrationContentBundle {
  const input = codec.boundedBytes(raw);
  const types = ["bytes32", "uint16", ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_BUNDLE_TUPLE];
  const values = coder.decode(types, input);
  if (values[0] !== ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_SCHEMA || values[1] !== 1n || coder.encode(types, values) !== input) {
    throw Error("Noncanonical original content bundle");
  }
  const value = codec.decodeTuple<ArtistRecoveredConsentHydrationContentBundle>(ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_BUNDLE_TUPLE,
    coder.encode([ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_BUNDLE_TUPLE], [values[2]]) as Hex);
  return normalizeArtistRecoveredConsentHydrationContentBundle(value, query, provenance);
}

export function normalizeArtistRecoveredConsentHydrationPrepared(
  value: shared.ArtistRecoveredHydrationPrepared,
): shared.ArtistRecoveredHydrationPrepared {
  const p = codec.normalizeArtistRecoveredHydrationPrepared(value);
  const hasContent = p.admission.provenance.journals[6].some(row => [17n, 20n, 21n].includes(row.receipt.operation));
  for (let i = 0; i < 7; i++) {
    const decoded = codec.decodeArtistRecoveredHydrationOwnerPayload(p.data[i]!.typedState, i as 0 | 1 | 2 | 3 | 4 | 5 | 6);
    if (((decoded.header.requiredFeatures & 256n) !== 0n) !== hasContent) throw Error("Content feature must follow complete source journal");
    if (i === 6 && hasContent) decodeArtistRecoveredConsentHydrationContentBundle(decoded.payload.semanticState, p.query, decoded.payload.provenance);
  }
  return p;
}

export function encodeArtistRecoveredConsentHydrationPrepared(value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.encodeArtistRecoveredHydrationPrepared(normalizeArtistRecoveredConsentHydrationPrepared(value));
}

export function decodeArtistRecoveredConsentHydrationPrepared(raw: Hex): shared.ArtistRecoveredHydrationPrepared {
  return normalizeArtistRecoveredConsentHydrationPrepared(codec.decodeArtistRecoveredHydrationPrepared(raw));
}

export function artistRecoveredConsentHydrationSemanticInventory(value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.artistRecoveredHydrationSemanticInventory(normalizeArtistRecoveredConsentHydrationPrepared(value));
}

export function artistRecoveredConsentHydrationCommitment(
  coordinates: shared.ArtistRecoveredHydrationCoordinates,
  request: shared.ArtistRecoveredHydrationRequest,
  prepared: shared.ArtistRecoveredHydrationPrepared,
): Hex {
  return codec.artistRecoveredHydrationCommitment(coordinates, request, normalizeArtistRecoveredConsentHydrationPrepared(prepared));
}

export function encodeArtistRecoveredConsentHydrationProfileEvidence(
  request: shared.ArtistRecoveredHydrationRequest,
  prepared: shared.ArtistRecoveredHydrationPrepared,
): Hex {
  return codec.encodeArtistRecoveredHydrationProfileEvidence(request, normalizeArtistRecoveredConsentHydrationPrepared(prepared));
}

export function validateArtistRecoveredConsentHydrationInput(
  value: ArtistRecoveredConsentHydrationInput,
  prepared: shared.ArtistRecoveredHydrationPrepared,
): ArtistRecoveredConsentHydrationInput {
  const input = normalizeArtistRecoveredConsentHydrationInput(value);
  const p = normalizeArtistRecoveredConsentHydrationPrepared(prepared);
  // The original profile encoder authenticates all unchanged Request and witness-family joins.
  codec.encodeArtistRecoveredHydrationProfileEvidence(input.request, p);
  const count = p.admission.provenance.journals[6].filter(row => row.receipt.operation === 20n).length;
  if (input.royaltyFreezes.length !== count) throw Error("Royalty selectors must cover every original operation20");
  if (p.admission.provenance.journals[6].some(row => [17n, 20n, 21n].includes(row.receipt.operation))) {
    const { payload } = codec.decodeArtistRecoveredHydrationOwnerPayload(p.data[6].typedState, 6);
    const bundle = decodeArtistRecoveredConsentHydrationContentBundle(payload.semanticState, p.query, payload.provenance);
    if (!equal(`${ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE}[]`, input.royaltyFreezes, bundle.royalties.map(row => row.terms))) {
      throw Error("Royalty selectors differ from original retained order and terms");
    }
  }
  return input;
}

export function artistRecoveredConsentHydrationRequiredFeatures(
  facts: shared.ArtistRecoveredHydrationFeatureFacts,
  operations: readonly bigint[],
): bigint {
  codec.boundedArray(operations, 4096);
  for (const operation of operations) {
    if (typeof operation !== "bigint" || ![14n, 15n, 16n, 17n, 20n, 21n].includes(operation)) throw Error("Unsupported Consent journal operation");
  }
  return codec.artistRecoveredHydrationRequiredFeatures(facts) | (operations.some(op => [17n, 20n, 21n].includes(op)) ? 256n : 0n);
}
