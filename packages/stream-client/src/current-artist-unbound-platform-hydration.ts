import { AbiCoder, ParamType, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { ArtistHydrationSeven, ArtistHydrationQuery, ArtistHydrationOwnerIndex, ArtistHydrationSuite } from "./current-artist-authority-hydration.js";
import { ARTIST_HYDRATION_QUERY_TUPLE, ARTIST_HYDRATION_SNAPSHOT_TUPLE, ARTIST_HYDRATION_NONCE_WORD_TUPLE, ARTIST_HYDRATION_OWNER_DATA_TUPLE, ARTIST_HYDRATION_CHECKPOINT_TUPLE, ARTIST_HYDRATION_REPLAY_CELL_TUPLE } from "./current-artist-authority-hydration.js";
import * as shared from "./internal/artist-recovered-hydration-codec.js";

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_SOURCE = "66dc4a308f6a1c1b93187d7295554062d900b5fa";
export const ARTIST_UNBOUND_PLATFORM_HYDRATION_BASE = 4194304n;
export const ARTIST_UNBOUND_PLATFORM_HYDRATION_ALLOWED_FEATURES = 4194335n;
export const ARTIST_UNBOUND_PLATFORM_HYDRATION_KNOWN_FEATURES = 33554431n;
export const ARTIST_UNBOUND_PLATFORM_HYDRATION_SCHEMA = id("6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1") as Hex;

export type {
  ArtistRecoveredHydrationCapability as ArtistUnboundPlatformHydrationCapability,
  ArtistRecoveredHydrationEconomicsConsent as ArtistUnboundPlatformHydrationEconomicsConsent,
  ArtistRecoveredHydrationAttestation as ArtistUnboundPlatformHydrationAttestation,
  ArtistRecoveredHydrationAttestationInput as ArtistUnboundPlatformHydrationAttestationInput,
  ArtistRecoveredHydrationCollectionWitness as ArtistUnboundPlatformHydrationCollectionWitness,
  ArtistRecoveredHydrationRecordsRequest as ArtistUnboundPlatformHydrationRecordsRequest,
  ArtistRecoveredHydrationRequest as ArtistUnboundPlatformHydrationRequest,
  ArtistRecoveredHydrationExportHeader as ArtistUnboundPlatformHydrationExportHeader,
  ArtistRecoveredHydrationOriginEnvironment as ArtistUnboundPlatformHydrationOriginEnvironment,
  ArtistRecoveredHydrationEra as ArtistUnboundPlatformHydrationEra,
  ArtistRecoveredHydrationPoint as ArtistUnboundPlatformHydrationPoint,
  ArtistRecoveredHydrationPosition as ArtistUnboundPlatformHydrationPosition,
  ArtistRecoveredHydrationJournalEntry as ArtistUnboundPlatformHydrationJournalEntry,
  ArtistRecoveredHydrationReplayAlias as ArtistUnboundPlatformHydrationReplayAlias,
  ArtistRecoveredHydrationProvenance as ArtistUnboundPlatformHydrationProvenance,
  ArtistRecoveredHydrationOwnerEra as ArtistUnboundPlatformHydrationOwnerEra,
  ArtistRecoveredHydrationOwnerProvenance as ArtistUnboundPlatformHydrationOwnerProvenance,
  ArtistRecoveredHydrationNonceInventory as ArtistUnboundPlatformHydrationNonceInventory,
  ArtistRecoveredHydrationEnvelope as ArtistUnboundPlatformHydrationEnvelope,
  ArtistRecoveredHydrationPublication as ArtistUnboundPlatformHydrationPublication,
  ArtistRecoveredHydrationOwnerPayload as ArtistUnboundPlatformHydrationOwnerPayload,
  ArtistRecoveredHydrationTimingConfiguration as ArtistUnboundPlatformHydrationTimingConfiguration,
  ArtistRecoveredHydrationTimingInput as ArtistUnboundPlatformHydrationTimingInput,
  ArtistRecoveredHydrationTimingEntry as ArtistUnboundPlatformHydrationTimingEntry,
  ArtistRecoveredHydrationTimingCheckpoint as ArtistUnboundPlatformHydrationTimingCheckpoint,
  ArtistRecoveredHydrationTimingBundle as ArtistUnboundPlatformHydrationTimingBundle,
  ArtistRecoveredHydrationActionWitness as ArtistUnboundPlatformHydrationActionWitness,
  ArtistRecoveredHydrationActionFacts as ArtistUnboundPlatformHydrationActionFacts,
  ArtistRecoveredHydrationActionGuard as ArtistUnboundPlatformHydrationActionGuard,
  ArtistRecoveredHydrationFinalityScope as ArtistUnboundPlatformHydrationFinalityScope,
  ArtistRecoveredHydrationFinalityComponent as ArtistUnboundPlatformHydrationFinalityComponent,
  ArtistRecoveredHydrationFinalityManifest as ArtistUnboundPlatformHydrationFinalityManifest,
  ArtistRecoveredHydrationFinalityEvidence as ArtistUnboundPlatformHydrationFinalityEvidence,
  ArtistRecoveredHydrationFinalityRecord as ArtistUnboundPlatformHydrationFinalityRecord,
  ArtistRecoveredHydrationFinalityTarget as ArtistUnboundPlatformHydrationFinalityTarget,
  ArtistRecoveredHydrationFinalityGuard as ArtistUnboundPlatformHydrationFinalityGuard,
  ArtistRecoveredHydrationEntropyReceipt as ArtistUnboundPlatformHydrationEntropyReceipt,
  ArtistRecoveredHydrationEntropyEvidence as ArtistUnboundPlatformHydrationEntropyEvidence,
  ArtistRecoveredHydrationEntropyGuard as ArtistUnboundPlatformHydrationEntropyGuard,
  ArtistRecoveredHydrationExternalGuards as ArtistUnboundPlatformHydrationExternalGuards,
  ArtistRecoveredHydrationCertificate as ArtistUnboundPlatformHydrationCertificate,
  ArtistRecoveredHydrationPrepared as ArtistUnboundPlatformHydrationPrepared,
  ArtistRecoveredHydrationEvidenceDescriptor as ArtistUnboundPlatformHydrationEvidenceDescriptor,
  ArtistRecoveredHydrationCoordinates as ArtistUnboundPlatformHydrationCoordinates,
  ArtistRecoveredHydrationProfileEvidence as ArtistUnboundPlatformHydrationProfileEvidence,
  ArtistRecoveredHydrationOperationEvidence as ArtistUnboundPlatformHydrationOperationEvidence,
  ArtistRecoveredHydrationHistoricalCell as ArtistUnboundPlatformHydrationHistoricalCell,
  ArtistRecoveredHydrationFeatureFacts as ArtistUnboundPlatformHydrationFeatureFacts
} from "./internal/artist-recovered-hydration-codec.js";

export {
  ARTIST_RECOVERED_HYDRATION_PROFILE as ARTIST_UNBOUND_PLATFORM_HYDRATION_PROFILE,
  ARTIST_RECOVERED_HYDRATION_PAGE_BYTES as ARTIST_UNBOUND_PLATFORM_HYDRATION_PAGE_BYTES,
  ARTIST_RECOVERED_HYDRATION_MAX_BYTES as ARTIST_UNBOUND_PLATFORM_HYDRATION_MAX_BYTES,
  ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES as ARTIST_UNBOUND_PLATFORM_HYDRATION_MAX_PREPARED_BYTES,
  ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA as ARTIST_UNBOUND_PLATFORM_HYDRATION_CHECKPOINT_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_PAYLOAD_SCHEMA as ARTIST_UNBOUND_PLATFORM_HYDRATION_PAYLOAD_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_EVIDENCE_SCHEMA as ARTIST_UNBOUND_PLATFORM_HYDRATION_EVIDENCE_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_CAPABILITY_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_CAPABILITY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_ECONOMICS_CONSENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ATTESTATION_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTESTATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ATTESTATION_INPUT_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTESTATION_INPUT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_COLLECTION_WITNESS_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_COLLECTION_WITNESS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_RECORDS_REQUEST_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_RECORDS_REQUEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_REQUEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EXPORT_HEADER_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_EXPORT_HEADER_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ERA_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_ERA_TUPLE,
  ARTIST_RECOVERED_HYDRATION_POINT_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_POINT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_POSITION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_JOURNAL_ENTRY_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_JOURNAL_ENTRY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_REPLAY_ALIAS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PROVENANCE_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_PROVENANCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_ERA_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_OWNER_ERA_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_OWNER_PROVENANCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_NONCE_INVENTORY_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_NONCE_INVENTORY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_ENVELOPE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PUBLICATION_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_PUBLICATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_PAYLOAD_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_OWNER_PAYLOAD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_CONFIGURATION_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_TIMING_CONFIGURATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_INPUT_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_TIMING_INPUT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_ENTRY_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_TIMING_ENTRY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_TIMING_CHECKPOINT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_BUNDLE_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_TIMING_BUNDLE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_WITNESS_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_ACTION_WITNESS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_FACTS_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_ACTION_FACTS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_GUARD_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_ACTION_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_SCOPE_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_FINALITY_SCOPE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_COMPONENT_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_FINALITY_COMPONENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_MANIFEST_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_FINALITY_MANIFEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_EVIDENCE_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_FINALITY_EVIDENCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_RECORD_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_FINALITY_RECORD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_TARGET_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_FINALITY_TARGET_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_GUARD_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_FINALITY_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_RECEIPT_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_ENTROPY_RECEIPT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_EVIDENCE_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_ENTROPY_EVIDENCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_GUARD_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_ENTROPY_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_EXTERNAL_GUARDS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_CERTIFICATE_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_CERTIFICATE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_PREPARED_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE as ARTIST_UNBOUND_PLATFORM_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE
} from "./internal/artist-recovered-hydration-codec.js";

const codec = shared.createArtistRecoveredHydrationCodec(4194335n);
export const {
  artistRecoveredHydrationOwnerDomain: artistUnboundPlatformHydrationOwnerDomain,
  artistRecoveredHydrationOwnerTag: artistUnboundPlatformHydrationOwnerTag,
  normalizeArtistRecoveredHydrationCoordinates: normalizeArtistUnboundPlatformHydrationCoordinates,
  normalizeArtistRecoveredHydrationCapability: normalizeArtistUnboundPlatformHydrationCapability,
  validateArtistRecoveredHydrationCapability: validateArtistUnboundPlatformHydrationCapability,
  normalizeArtistRecoveredHydrationRequestDraft: normalizeArtistUnboundPlatformHydrationRequestDraft,
  normalizeArtistRecoveredHydrationRequest: normalizeArtistUnboundPlatformHydrationRequest,
  encodeArtistRecoveredHydrationRequest: encodeArtistUnboundPlatformHydrationRequest,
  CURRENT_ARTIST_RECOVERED_HYDRATION_ABI: CURRENT_ARTIST_UNBOUND_PLATFORM_HYDRATION_ABI,
  ARTIST_RECOVERED_HYDRATION_CAPABILITY_ID: ARTIST_UNBOUND_PLATFORM_HYDRATION_CAPABILITY_ID,
  normalizeArtistRecoveredHydrationOriginEnvironment: normalizeArtistUnboundPlatformHydrationOriginEnvironment,
  artistRecoveredHydrationOriginHash: artistUnboundPlatformHydrationOriginHash,
  artistRecoveredHydrationReplayKey: artistUnboundPlatformHydrationReplayKey,
  normalizeArtistRecoveredHydrationOwnerProvenance: normalizeArtistUnboundPlatformHydrationOwnerProvenance,
  artistRecoveredHydrationOwnerProvenance: artistUnboundPlatformHydrationOwnerProvenance,
  normalizeArtistRecoveredHydrationProvenance: normalizeArtistUnboundPlatformHydrationProvenance,
  artistRecoveredHydrationProvenanceHash: artistUnboundPlatformHydrationProvenanceHash,
  artistRecoveredHydrationOwnerProvenanceHash: artistUnboundPlatformHydrationOwnerProvenanceHash,
  artistRecoveredHydrationAliasesHash: artistUnboundPlatformHydrationAliasesHash,
  compareArtistRecoveredHydrationPoints: compareArtistUnboundPlatformHydrationPoints,
  normalizeArtistRecoveredHydrationNonceInventory: normalizeArtistUnboundPlatformHydrationNonceInventory,
  normalizeArtistRecoveredHydrationPublications: normalizeArtistUnboundPlatformHydrationPublications,
  normalizeArtistRecoveredHydrationTimingCheckpoint: normalizeArtistUnboundPlatformHydrationTimingCheckpoint,
  normalizeArtistRecoveredHydrationExternalGuards: normalizeArtistUnboundPlatformHydrationExternalGuards,
  ARTIST_RECOVERED_HYDRATION_PREPARE_SELECTOR: ARTIST_UNBOUND_PLATFORM_HYDRATION_PREPARE_SELECTOR,
  ARTIST_RECOVERED_HYDRATION_PREPARE_ABI: ARTIST_UNBOUND_PLATFORM_HYDRATION_PREPARE_ABI,
  normalizeArtistRecoveredHydrationEvidenceDescriptor: normalizeArtistUnboundPlatformHydrationEvidenceDescriptor,
  artistRecoveredHydrationEvidenceDescriptor: artistUnboundPlatformHydrationEvidenceDescriptor,
  artistRecoveredHydrationEvidencePages: artistUnboundPlatformHydrationEvidencePages,
  assembleArtistRecoveredHydrationEvidence: assembleArtistUnboundPlatformHydrationEvidence,
  artistRecoveredHydrationPageId: artistUnboundPlatformHydrationPageId,
  artistRecoveredHydrationEvidenceId: artistUnboundPlatformHydrationEvidenceId,
  encodeArtistRecoveredHydrationEvidenceCarrier: encodeArtistUnboundPlatformHydrationEvidenceCarrier,
  decodeArtistRecoveredHydrationEvidenceCarrier: decodeArtistUnboundPlatformHydrationEvidenceCarrier,
  encodeArtistRecoveredHydrationOperationEvidence: encodeArtistUnboundPlatformHydrationOperationEvidence,
  decodeArtistRecoveredHydrationOperationEvidence: decodeArtistUnboundPlatformHydrationOperationEvidence,
  artistRecoveredHydrationOwnerReplayDelta: artistUnboundPlatformHydrationOwnerReplayDelta,
  artistRecoveredHydrationOwnerAfter: artistUnboundPlatformHydrationOwnerAfter
} = codec;

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_IDENTITY_TUPLE = `tuple(bytes32 artistId,tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip) sourceSnapshot,uint256 nextRegistrationNonce,tuple(address authorityAddress,uint8 authorityClass,uint8 status,uint64 registeredAt,uint64 lastAuthorityActionAt,bytes32 identityRecordHash,string identityRecordURI,string displayName,uint256 nonceHint) identity,bytes identityDocument,tuple(bytes32 documentHash,bytes document)[] documents,tuple(bytes32 latestTransition,bytes32 latestExecution,bytes32 pendingRotation,bytes32 latestContest,bytes32 currentCause,bytes32 latestDismissal,bytes32 originalRevisionContinuation,bytes32 latestRecovery,bytes32 pendingRecoveryAction,bytes32 latestVesting,bytes32 pendingEstate,bytes32 estateActivation,bytes32 dormancyActivation,bytes32 latestNotice,uint256 livingActivity,uint256 dormancyActivity,uint256 findingActivity,bool hasUncancelledFindings,uint64 delegationEpoch,uint64 guardianRecordsSeen,tuple(uint64 count,uint64 ownerRevision,bytes32 commitment) guardianHistory,tuple(uint64 count,bytes32 historyCommitment) guardianIndex,tuple(tuple(bytes32 stable,bytes32 candidate) guardians,tuple(bytes32 stable,bytes32 candidate) designations,tuple(bytes32 stable,bytes32 candidate) directives,tuple(bytes32 stable,bytes32 candidate) revisions,tuple(bytes32 stable,bytes32 candidate) sanctionGrants,bytes32 revisionContinuationHash,bytes32 supersessionStateCommitment) inventory,bytes32 capabilityContinuation) heads,tuple(tuple(uint64[7] values,uint64[5] revisions) configuration,tuple(uint256 chainId,address owner,uint256 index,tuple(bytes32 parameter,bytes32 actionId,bytes32 actionKey,bytes32 oldHash,bytes32 newHash,uint64 oldValue,uint64 newValue,uint64 floor,uint64 oldRevision,uint64 newRevision) change,bytes32 previousCommitment,bytes32 commitment)[] entries,tuple(bytes32 schema,uint16 version,uint256 count,bytes32 root,bytes32 configurationHash) checkpoint) timing,tuple(bytes32 recordHash,bytes signature)[] signatures,tuple(uint8 kind,bytes32 key,uint256 hint,tuple(uint256 prefix,uint256[32] words,bool exhausted)[] words)[] nonces,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,bytes32 previousRevisionRecord,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,string identityRecordURI,string displayName) record,bytes document,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) association,tuple(bytes32 artistId,uint8 kind,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment) status,bytes32 rewindContinuation)[] revisions,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,bytes32 recordHash,tuple(tuple(bytes32 artistId,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash) grant,address grantor,uint256 nonce,uint256 uses,bool revoked,bytes32 revocationRecordHash) record,bytes32 current,uint64 epoch)[] delegations,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 previousOperativeRecordHash,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional) record,tuple(bytes32 artistId,uint64 index,uint64 ownerRevision,bytes32 recordHash,bytes32 recordDataHash,bytes32 previousCommitment,bytes32 commitment) entry,tuple(bytes32 artistId,bytes32 recoveryRecordHash,bytes32 actionId) status)[] guardians,tuple(address actor,uint64 first,uint64[] indices)[] memberships,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address oldAddress,address newAddress,bytes32 reasonHash,bytes32 expectedPreviousTransitionRecordHash) terms,bytes32 guardianSetRecordHash,uint32 approvalThreshold,uint32 guardianApprovals,uint256 oldNonce,uint256 newNonce,uint64 effectiveWindow,uint64 standingTail,uint64 timingRevision,tuple(bytes32 artistId,bytes32 recordHash,uint64 stagedAt,uint64 contestEndsAt,uint64 executedAt,uint64 postWindowEndsAt,uint64 contestedAt,uint8 phase) transition) record,bool[] approvals)[] rotations,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,bytes32 subjectRecordHash,bytes32 evidenceHash,bytes32 reasonHash) terms,address contester,uint64 contestedAt,uint8 priorStatus,bytes32 guardianSetRecordHash,bytes32 capturedGuardianSetRecordHash,bytes32 pendingTransitionRecordHash,bytes32 executedTransitionRecordHash,bytes32 governanceWitnessHash) record)[] contests,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 causeHash,tuple(bytes32 artistId,uint8 kind,bytes32 referenceHash,address actor,bytes32 reasonHash,bytes32 evidenceHash,uint64 enteredAt,address incumbent,uint8 authorityClass,uint8 priorStatus,bytes32 pendingTransitionHash,bytes32 executedTransitionHash,bytes32 previousCauseHash,bytes32 previousResolutionHash,bytes32 actorRetirementHash) facts) cause,bytes32 notice)[] causes,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,bytes32 expectedCauseHash,bytes32 expectedResolutionHash,bytes32 evidenceHash,bytes32 reasonHash,bool removePriorStanding,bytes32 expectedRetirementHash) terms,address executor,address proposer,uint8 actionClass,bytes32 actionId,address incumbent,uint8 authorityClass,uint8 restoredStatus,uint64 dismissedAt,bytes32 cohortHash,bytes32 governanceWitnessHash,bytes32 revisionContinuationHead) record)[] dismissals,tuple(bytes32 transition,tuple(bytes32 artistId,bytes32 transitionRecordHash,bytes32 dismissalRecordHash,uint64 windowEndsAt,uint64 contestedAt,bool abandoned) closure)[] closures,tuple(address account,bytes32 retirement,bytes32 revocation,tuple(bytes32 retirementHash,bytes32 dismissalRecordHash) judgment)[] standing,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address revokedAddress,bytes32 reasonHash,bytes32 retiredTransitionRecordHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt) record,tuple(bytes32 artistId,uint8 kind,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment) status,bytes32 rewindContinuation)[] standingRecords,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address oldAddress,address newAddress,uint8 vestedAuthorityClass,bytes32 evidenceHash,bytes32 reasonHash,bytes32 supersededRecordsHash,bytes32 governanceActionId,uint64 recoveredAt) fields,tuple(bytes32 artistId,address newAddress,uint8 vestedAuthorityClass,bytes32 expectedCauseHash,bytes32 expectedResolutionHash,bytes32 evidenceHash,bytes32 reasonHash,bytes32[] supersededRecordHashes) terms,address executor,address proposer,bytes32 governanceWitnessHash,bytes32 contextHash,bytes32 acceptanceDigest,uint256 acceptanceNonce,uint64 acceptanceDeadline,uint64 postContestSeconds,uint64 standingTailSeconds,uint64 timingRevision,uint64 delegationEpoch,tuple(bytes32 artistId,bytes32 recordHash,uint64 stagedAt,uint64 contestEndsAt,uint64 executedAt,uint64 postWindowEndsAt,uint64 contestedAt,uint8 phase) abandonedTransition) record,tuple(bytes32 artistId,bytes32 recordHash,uint64 stagedAt,uint64 contestEndsAt,uint64 executedAt,uint64 postWindowEndsAt,uint64 contestedAt,uint8 phase) transition,bytes32 guardian,bytes32 primaryReceipt,bytes32 secondaryOccurrence,bytes32 secondaryReceipt)[] recoveries,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 artistId,bytes32 transitionRecordHash,uint16 operationId,uint64 ownerRevision,uint64 executedAt,address oldAddress,address newAddress,uint8 authorityClass,tuple(uint64 count,uint64 ownerRevision,bytes32 commitment) guardians,bytes32 previousTransitionRecordHash,bytes32 previousCommitment,bytes32 commitment) snapshot)[] vestings,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 associationHash,bytes32 artistId,bytes32 requestHash,bytes32 acceptanceHash,bytes32 contextHash,tuple(bytes32 actionId,bytes32 callsHash,uint256 callIndex,bytes32 callDataHash,address executor,bytes32 executorCodeHash,address proposer,bytes32 roleMutationHash,uint64 roleRevision,uint64 notBefore,uint64 expiresAfter,uint64 minimumDelay,bytes32 manifestHash) action,tuple(bytes32 recordHash,tuple(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 previousOperativeRecordHash,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional) guardian,address preparedBy,uint64 preparedAt,uint64 ownerRevision) association,tuple(address vetoer,bytes32 reasonHash,uint64 vetoedAt) veto,bytes32 execution,tuple(bytes32 artistId,uint64 count,bytes32 historyCommitment,bytes32 associationHash) guardianSnapshot,tuple(bytes32 artistId,bytes32 associationHash,bytes32 contextCommitment,uint64 count,bytes32 historyCommitment,bytes32[] excluded) plan,tuple(bytes32 sourceKey,bytes32 selectedRecordHash,bytes32 selectedDataHash,uint256 selectedNonce,bytes32 commitment) election,tuple(bytes32 recordHash,tuple(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 previousOperativeRecordHash,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional) restoredGuardian,uint64[] excludedMemberships,tuple(bytes32 manifestHash,bytes32 basisCommitment,bytes32 selectionCommitment,bytes32 requiredRole,uint64 preparedFromOwnerRevision,bytes32 associationHash) evidenceV2,tuple(bytes32 manifestHash,bytes32 sourceKey,bytes32 sourceCommitment,bytes32 selectionCommitment,bytes32 policyCommitment,bytes32 requiredRole,uint32 effectiveCapabilities,bytes32 associationHash,tuple(tuple(tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip) snapshot,uint256 receiptCount) identityBefore,tuple(tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip) snapshot,uint256 receiptCount) payout,bytes32 associationHash) sources) evidenceV3,bytes32 manifestActionV2,bytes32 manifestActionV3)[] actions,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address successor,uint8 successorKind,uint32 grantedCapabilities,bytes32 conditionsHash,bytes32 directiveHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional) record,tuple(bytes32 artistId,uint8 kind,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment) status)[] designations,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,uint32 grantedCapabilities,uint32 forbiddenCapabilities,bytes32 directivePayloadHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional) record,bytes payload,tuple(bytes32 artistId,uint8 kind,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment) status)[] directives,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,bool granted,bytes32 statementHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional) record,tuple(bytes32 artistId,uint8 kind,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment) status)[] sanctionGrants,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address successor,bytes32 evidenceHash,bytes32 expectedDesignationRecordHash,bytes32 selectedCoverageHash) terms,tuple(uint256 nonce,uint64 time,bytes signature) authorization,address incumbent,bytes32 designationRecordHash,bytes32 pairedDirectiveRecordHash,bytes32 forbiddenDirectiveRecordHash,bytes32 guardianRecordHash,bytes32 envelopeHash,uint64 requestedAt,uint64 noticeEndsAt,uint64 noticeSeconds,uint64 noticeRevision,uint64 postContestSeconds,uint64 standingTailSeconds,uint64 rotationTimingRevision,uint256 livingActivity) request,uint8 phase,tuple(bytes32 activationRecordHash,bytes32 coverageRecordHash,uint32 effectiveCapabilities,uint64 executedAt,bytes32 governanceActionId,bytes32 governanceWitnessHash,uint64 delegationEpoch) execution,tuple(bytes32 artistId,bytes32 recordHash,uint64 stagedAt,uint64 contestEndsAt,uint64 executedAt,uint64 postWindowEndsAt,uint64 contestedAt,uint8 phase) transition)[] estates,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,bytes32 evidenceHash,string reasonURI) terms,address incumbent,uint64 initiatedAt,uint64 noticeEndsAt,uint64 inactivitySeconds,uint64 noticeSeconds,uint64 timingRevision,uint64 priorLivenessAt,uint256 priorActivity,bytes32 actionId,bytes32 witnessHash) notice,uint8 phase,tuple(bytes32 recordHash,bytes32 noticeHash,address actor,uint8 authorityClass,uint64 observedAt,uint64 appointmentBlock,tuple(address authority,uint8 authorityClass,uint32 capabilities,bytes32 designation,bytes32 directive,bytes32 guardian,bytes32 stewardGrantRecordHash,uint64 postSeconds,uint64 standingTail) plan,bytes32 evidenceHash,bytes32 actionId,bytes32 witnessHash,uint64 delegationEpoch) terminal,tuple(bytes32 artistId,bytes32 recordHash,uint64 stagedAt,uint64 contestEndsAt,uint64 executedAt,uint64 postWindowEndsAt,uint64 contestedAt,uint8 phase) transition)[] notices,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,uint256 collectionId,bytes32 evidenceHash,bytes32 reasonHash) terms,bytes32 governanceActionId,uint64 noticeEndsAt,uint64 recordedAt,uint64 noticeSeconds,uint64 timingRevision,uint64 bindingGeneration,bytes32 bindingHash) record,tuple(tuple(address recoveryRegistry,bytes32 recoveryActionId,tuple(uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId) scope,bytes32 originalFinalityRecordHash,bytes32 recoveryManifestHash) target,bytes32 recoveryRegistryCodeHash,bytes32 recoveryIntentFactsHash,uint256 activityEpoch,bytes32 governanceWitnessHash) admission,tuple(tuple(address coordinator,tuple(bytes32 oldRequestKey,string reasonURI,bytes32 providerEvidenceHash) recovery,bytes32 intentHash,bytes32 unavailableEvidenceHash) target,tuple(uint256 collectionId,uint256 tokenId,bytes32 scopeId,bytes32 oldRequestKey,bytes32 newRequestKey,bytes32 priorJournalHead,bytes32 journalHead,bytes32 currentContentStateHash,bytes32 contentStateHash,bytes32 requestPolicyHash,bytes32 incidentEvidenceHash,bytes32 providerEvidenceHash,bytes32 reasonHash) intent,bytes32 coordinatorCodeHash,uint256 activityEpoch,bytes32 governanceWitnessHash) entropyAdmission,address entropyOrigin,bytes32 latestForCollection)[] findings,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 continuationHash,bytes32 artistId,bytes32 dismissalRecordHash,bytes32 previousContinuationHash,bytes32 stableRevisionRecordHash,bytes32 stableDocumentHash,bytes32 abandonedRevisionRecordHash) continuation)[] originalContinuations,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 artistId,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment,bytes32 stableRevisionRecordHash,bytes32 stableDocumentHash,bytes32 resolvedChildRecordHash,uint64 ownerRevision,bytes32 continuationHash) continuation)[] revisionContinuations,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 artistId,address priorAddress,bytes32 retirementHash,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment,bytes32 retainedRevocationRecordHash,bytes32 supersededRevocationRecordHash,uint64 ownerRevision,bytes32 continuationHash) continuation,bytes32 scopeHead)[] standingContinuations,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 artistId,bytes32 originalActivationRecordHash,uint32 originalActivationCapabilities,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 manifestHash,bytes32 planCommitment,bytes32 designationRecordHash,bytes32 pairedDirectiveRecordHash,bytes32 forbiddenDirectiveRecordHash,address authorityAddress,uint32 effectiveCapabilities,bytes32 commitment) continuation)[] capabilityContinuations)`;
export type ArtistUnboundPlatformHydrationIdentity = { readonly artistId: Hex; readonly sourceSnapshot: { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }; readonly nextRegistrationNonce: bigint; readonly identity: { readonly authorityAddress: Address; readonly authorityClass: bigint; readonly status: bigint; readonly registeredAt: bigint; readonly lastAuthorityActionAt: bigint; readonly identityRecordHash: Hex; readonly identityRecordURI: string; readonly displayName: string; readonly nonceHint: bigint; }; readonly identityDocument: Hex; readonly documents: readonly ({ readonly documentHash: Hex; readonly document: Hex; })[]; readonly heads: { readonly latestTransition: Hex; readonly latestExecution: Hex; readonly pendingRotation: Hex; readonly latestContest: Hex; readonly currentCause: Hex; readonly latestDismissal: Hex; readonly originalRevisionContinuation: Hex; readonly latestRecovery: Hex; readonly pendingRecoveryAction: Hex; readonly latestVesting: Hex; readonly pendingEstate: Hex; readonly estateActivation: Hex; readonly dormancyActivation: Hex; readonly latestNotice: Hex; readonly livingActivity: bigint; readonly dormancyActivity: bigint; readonly findingActivity: bigint; readonly hasUncancelledFindings: boolean; readonly delegationEpoch: bigint; readonly guardianRecordsSeen: bigint; readonly guardianHistory: { readonly count: bigint; readonly ownerRevision: bigint; readonly commitment: Hex; }; readonly guardianIndex: { readonly count: bigint; readonly historyCommitment: Hex; }; readonly inventory: { readonly guardians: { readonly stable: Hex; readonly candidate: Hex; }; readonly designations: { readonly stable: Hex; readonly candidate: Hex; }; readonly directives: { readonly stable: Hex; readonly candidate: Hex; }; readonly revisions: { readonly stable: Hex; readonly candidate: Hex; }; readonly sanctionGrants: { readonly stable: Hex; readonly candidate: Hex; }; readonly revisionContinuationHash: Hex; readonly supersessionStateCommitment: Hex; }; readonly capabilityContinuation: Hex; }; readonly timing: { readonly configuration: { readonly values: readonly (bigint)[]; readonly revisions: readonly (bigint)[]; }; readonly entries: readonly ({ readonly chainId: bigint; readonly owner: Address; readonly index: bigint; readonly change: { readonly parameter: Hex; readonly actionId: Hex; readonly actionKey: Hex; readonly oldHash: Hex; readonly newHash: Hex; readonly oldValue: bigint; readonly newValue: bigint; readonly floor: bigint; readonly oldRevision: bigint; readonly newRevision: bigint; }; readonly previousCommitment: Hex; readonly commitment: Hex; })[]; readonly checkpoint: { readonly schema: Hex; readonly version: bigint; readonly count: bigint; readonly root: Hex; readonly configurationHash: Hex; }; }; readonly signatures: readonly ({ readonly recordHash: Hex; readonly signature: Hex; })[]; readonly nonces: readonly ({ readonly kind: bigint; readonly key: Hex; readonly hint: bigint; readonly words: readonly ({ readonly prefix: bigint; readonly words: readonly (bigint)[]; readonly exhausted: boolean; })[]; })[]; readonly revisions: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly artistId: Hex; readonly previousRecordHash: Hex; readonly revisedRecordHash: Hex; readonly previousRevisionRecord: Hex; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly identityRecordURI: string; readonly displayName: string; }; readonly document: Hex; readonly association: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; readonly status: { readonly artistId: Hex; readonly kind: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; }; readonly rewindContinuation: Hex; })[]; readonly delegations: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly recordHash: Hex; readonly record: { readonly grant: { readonly artistId: Hex; readonly delegate: Address; readonly collectionId: bigint; readonly capabilities: bigint; readonly notBefore: bigint; readonly expiresAt: bigint; readonly maxUses: bigint; readonly constraintsHash: Hex; }; readonly grantor: Address; readonly nonce: bigint; readonly uses: bigint; readonly revoked: boolean; readonly revocationRecordHash: Hex; }; readonly current: Hex; readonly epoch: bigint; })[]; readonly guardians: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly guardians: readonly (Address)[]; readonly approvalThreshold: bigint; readonly minContestSeconds: bigint; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly previousOperativeRecordHash: Hex; readonly provisional: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; }; readonly entry: { readonly artistId: Hex; readonly index: bigint; readonly ownerRevision: bigint; readonly recordHash: Hex; readonly recordDataHash: Hex; readonly previousCommitment: Hex; readonly commitment: Hex; }; readonly status: { readonly artistId: Hex; readonly recoveryRecordHash: Hex; readonly actionId: Hex; }; })[]; readonly memberships: readonly ({ readonly actor: Address; readonly first: bigint; readonly indices: readonly (bigint)[]; })[]; readonly rotations: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly oldAddress: Address; readonly newAddress: Address; readonly reasonHash: Hex; readonly expectedPreviousTransitionRecordHash: Hex; }; readonly guardianSetRecordHash: Hex; readonly approvalThreshold: bigint; readonly guardianApprovals: bigint; readonly oldNonce: bigint; readonly newNonce: bigint; readonly effectiveWindow: bigint; readonly standingTail: bigint; readonly timingRevision: bigint; readonly transition: { readonly artistId: Hex; readonly recordHash: Hex; readonly stagedAt: bigint; readonly contestEndsAt: bigint; readonly executedAt: bigint; readonly postWindowEndsAt: bigint; readonly contestedAt: bigint; readonly phase: bigint; }; }; readonly approvals: readonly (boolean)[]; })[]; readonly contests: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly subjectRecordHash: Hex; readonly evidenceHash: Hex; readonly reasonHash: Hex; }; readonly contester: Address; readonly contestedAt: bigint; readonly priorStatus: bigint; readonly guardianSetRecordHash: Hex; readonly capturedGuardianSetRecordHash: Hex; readonly pendingTransitionRecordHash: Hex; readonly executedTransitionRecordHash: Hex; readonly governanceWitnessHash: Hex; }; })[]; readonly causes: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly cause: { readonly causeHash: Hex; readonly facts: { readonly artistId: Hex; readonly kind: bigint; readonly referenceHash: Hex; readonly actor: Address; readonly reasonHash: Hex; readonly evidenceHash: Hex; readonly enteredAt: bigint; readonly incumbent: Address; readonly authorityClass: bigint; readonly priorStatus: bigint; readonly pendingTransitionHash: Hex; readonly executedTransitionHash: Hex; readonly previousCauseHash: Hex; readonly previousResolutionHash: Hex; readonly actorRetirementHash: Hex; }; }; readonly notice: Hex; })[]; readonly dismissals: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly expectedCauseHash: Hex; readonly expectedResolutionHash: Hex; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly removePriorStanding: boolean; readonly expectedRetirementHash: Hex; }; readonly executor: Address; readonly proposer: Address; readonly actionClass: bigint; readonly actionId: Hex; readonly incumbent: Address; readonly authorityClass: bigint; readonly restoredStatus: bigint; readonly dismissedAt: bigint; readonly cohortHash: Hex; readonly governanceWitnessHash: Hex; readonly revisionContinuationHead: Hex; }; })[]; readonly closures: readonly ({ readonly transition: Hex; readonly closure: { readonly artistId: Hex; readonly transitionRecordHash: Hex; readonly dismissalRecordHash: Hex; readonly windowEndsAt: bigint; readonly contestedAt: bigint; readonly abandoned: boolean; }; })[]; readonly standing: readonly ({ readonly account: Address; readonly retirement: Hex; readonly revocation: Hex; readonly judgment: { readonly retirementHash: Hex; readonly dismissalRecordHash: Hex; }; })[]; readonly standingRecords: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly revokedAddress: Address; readonly reasonHash: Hex; readonly retiredTransitionRecordHash: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; }; readonly status: { readonly artistId: Hex; readonly kind: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; }; readonly rewindContinuation: Hex; })[]; readonly recoveries: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly fields: { readonly artistId: Hex; readonly oldAddress: Address; readonly newAddress: Address; readonly vestedAuthorityClass: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly supersededRecordsHash: Hex; readonly governanceActionId: Hex; readonly recoveredAt: bigint; }; readonly terms: { readonly artistId: Hex; readonly newAddress: Address; readonly vestedAuthorityClass: bigint; readonly expectedCauseHash: Hex; readonly expectedResolutionHash: Hex; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly supersededRecordHashes: readonly (Hex)[]; }; readonly executor: Address; readonly proposer: Address; readonly governanceWitnessHash: Hex; readonly contextHash: Hex; readonly acceptanceDigest: Hex; readonly acceptanceNonce: bigint; readonly acceptanceDeadline: bigint; readonly postContestSeconds: bigint; readonly standingTailSeconds: bigint; readonly timingRevision: bigint; readonly delegationEpoch: bigint; readonly abandonedTransition: { readonly artistId: Hex; readonly recordHash: Hex; readonly stagedAt: bigint; readonly contestEndsAt: bigint; readonly executedAt: bigint; readonly postWindowEndsAt: bigint; readonly contestedAt: bigint; readonly phase: bigint; }; }; readonly transition: { readonly artistId: Hex; readonly recordHash: Hex; readonly stagedAt: bigint; readonly contestEndsAt: bigint; readonly executedAt: bigint; readonly postWindowEndsAt: bigint; readonly contestedAt: bigint; readonly phase: bigint; }; readonly guardian: Hex; readonly primaryReceipt: Hex; readonly secondaryOccurrence: Hex; readonly secondaryReceipt: Hex; })[]; readonly vestings: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly snapshot: { readonly artistId: Hex; readonly transitionRecordHash: Hex; readonly operationId: bigint; readonly ownerRevision: bigint; readonly executedAt: bigint; readonly oldAddress: Address; readonly newAddress: Address; readonly authorityClass: bigint; readonly guardians: { readonly count: bigint; readonly ownerRevision: bigint; readonly commitment: Hex; }; readonly previousTransitionRecordHash: Hex; readonly previousCommitment: Hex; readonly commitment: Hex; }; })[]; readonly actions: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly association: { readonly associationHash: Hex; readonly artistId: Hex; readonly requestHash: Hex; readonly acceptanceHash: Hex; readonly contextHash: Hex; readonly action: { readonly actionId: Hex; readonly callsHash: Hex; readonly callIndex: bigint; readonly callDataHash: Hex; readonly executor: Address; readonly executorCodeHash: Hex; readonly proposer: Address; readonly roleMutationHash: Hex; readonly roleRevision: bigint; readonly notBefore: bigint; readonly expiresAfter: bigint; readonly minimumDelay: bigint; readonly manifestHash: Hex; }; readonly guardian: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly guardians: readonly (Address)[]; readonly approvalThreshold: bigint; readonly minContestSeconds: bigint; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly previousOperativeRecordHash: Hex; readonly provisional: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; }; readonly preparedBy: Address; readonly preparedAt: bigint; readonly ownerRevision: bigint; }; readonly veto: { readonly vetoer: Address; readonly reasonHash: Hex; readonly vetoedAt: bigint; }; readonly execution: Hex; readonly guardianSnapshot: { readonly artistId: Hex; readonly count: bigint; readonly historyCommitment: Hex; readonly associationHash: Hex; }; readonly plan: { readonly artistId: Hex; readonly associationHash: Hex; readonly contextCommitment: Hex; readonly count: bigint; readonly historyCommitment: Hex; readonly excluded: readonly (Hex)[]; }; readonly election: { readonly sourceKey: Hex; readonly selectedRecordHash: Hex; readonly selectedDataHash: Hex; readonly selectedNonce: bigint; readonly commitment: Hex; }; readonly restoredGuardian: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly guardians: readonly (Address)[]; readonly approvalThreshold: bigint; readonly minContestSeconds: bigint; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly previousOperativeRecordHash: Hex; readonly provisional: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; }; readonly excludedMemberships: readonly (bigint)[]; readonly evidenceV2: { readonly manifestHash: Hex; readonly basisCommitment: Hex; readonly selectionCommitment: Hex; readonly requiredRole: Hex; readonly preparedFromOwnerRevision: bigint; readonly associationHash: Hex; }; readonly evidenceV3: { readonly manifestHash: Hex; readonly sourceKey: Hex; readonly sourceCommitment: Hex; readonly selectionCommitment: Hex; readonly policyCommitment: Hex; readonly requiredRole: Hex; readonly effectiveCapabilities: bigint; readonly associationHash: Hex; readonly sources: { readonly identityBefore: { readonly snapshot: { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }; readonly receiptCount: bigint; }; readonly payout: { readonly snapshot: { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }; readonly receiptCount: bigint; }; readonly associationHash: Hex; }; }; readonly manifestActionV2: Hex; readonly manifestActionV3: Hex; })[]; readonly designations: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly successor: Address; readonly successorKind: bigint; readonly grantedCapabilities: bigint; readonly conditionsHash: Hex; readonly directiveHash: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly provisional: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; }; readonly status: { readonly artistId: Hex; readonly kind: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; }; })[]; readonly directives: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly grantedCapabilities: bigint; readonly forbiddenCapabilities: bigint; readonly directivePayloadHash: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly provisional: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; }; readonly payload: Hex; readonly status: { readonly artistId: Hex; readonly kind: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; }; })[]; readonly sanctionGrants: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly granted: boolean; readonly statementHash: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly provisional: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; }; readonly status: { readonly artistId: Hex; readonly kind: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; }; })[]; readonly estates: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly request: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly successor: Address; readonly evidenceHash: Hex; readonly expectedDesignationRecordHash: Hex; readonly selectedCoverageHash: Hex; }; readonly authorization: { readonly nonce: bigint; readonly time: bigint; readonly signature: Hex; }; readonly incumbent: Address; readonly designationRecordHash: Hex; readonly pairedDirectiveRecordHash: Hex; readonly forbiddenDirectiveRecordHash: Hex; readonly guardianRecordHash: Hex; readonly envelopeHash: Hex; readonly requestedAt: bigint; readonly noticeEndsAt: bigint; readonly noticeSeconds: bigint; readonly noticeRevision: bigint; readonly postContestSeconds: bigint; readonly standingTailSeconds: bigint; readonly rotationTimingRevision: bigint; readonly livingActivity: bigint; }; readonly phase: bigint; readonly execution: { readonly activationRecordHash: Hex; readonly coverageRecordHash: Hex; readonly effectiveCapabilities: bigint; readonly executedAt: bigint; readonly governanceActionId: Hex; readonly governanceWitnessHash: Hex; readonly delegationEpoch: bigint; }; readonly transition: { readonly artistId: Hex; readonly recordHash: Hex; readonly stagedAt: bigint; readonly contestEndsAt: bigint; readonly executedAt: bigint; readonly postWindowEndsAt: bigint; readonly contestedAt: bigint; readonly phase: bigint; }; })[]; readonly notices: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly notice: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly evidenceHash: Hex; readonly reasonURI: string; }; readonly incumbent: Address; readonly initiatedAt: bigint; readonly noticeEndsAt: bigint; readonly inactivitySeconds: bigint; readonly noticeSeconds: bigint; readonly timingRevision: bigint; readonly priorLivenessAt: bigint; readonly priorActivity: bigint; readonly actionId: Hex; readonly witnessHash: Hex; }; readonly phase: bigint; readonly terminal: { readonly recordHash: Hex; readonly noticeHash: Hex; readonly actor: Address; readonly authorityClass: bigint; readonly observedAt: bigint; readonly appointmentBlock: bigint; readonly plan: { readonly authority: Address; readonly authorityClass: bigint; readonly capabilities: bigint; readonly designation: Hex; readonly directive: Hex; readonly guardian: Hex; readonly stewardGrantRecordHash: Hex; readonly postSeconds: bigint; readonly standingTail: bigint; }; readonly evidenceHash: Hex; readonly actionId: Hex; readonly witnessHash: Hex; readonly delegationEpoch: bigint; }; readonly transition: { readonly artistId: Hex; readonly recordHash: Hex; readonly stagedAt: bigint; readonly contestEndsAt: bigint; readonly executedAt: bigint; readonly postWindowEndsAt: bigint; readonly contestedAt: bigint; readonly phase: bigint; }; })[]; readonly findings: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly collectionId: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex; }; readonly governanceActionId: Hex; readonly noticeEndsAt: bigint; readonly recordedAt: bigint; readonly noticeSeconds: bigint; readonly timingRevision: bigint; readonly bindingGeneration: bigint; readonly bindingHash: Hex; }; readonly admission: { readonly target: { readonly recoveryRegistry: Address; readonly recoveryActionId: Hex; readonly scope: { readonly scopeType: bigint; readonly collectionId: bigint; readonly tokenId: bigint; readonly scopeId: Hex; }; readonly originalFinalityRecordHash: Hex; readonly recoveryManifestHash: Hex; }; readonly recoveryRegistryCodeHash: Hex; readonly recoveryIntentFactsHash: Hex; readonly activityEpoch: bigint; readonly governanceWitnessHash: Hex; }; readonly entropyAdmission: { readonly target: { readonly coordinator: Address; readonly recovery: { readonly oldRequestKey: Hex; readonly reasonURI: string; readonly providerEvidenceHash: Hex; }; readonly intentHash: Hex; readonly unavailableEvidenceHash: Hex; }; readonly intent: { readonly collectionId: bigint; readonly tokenId: bigint; readonly scopeId: Hex; readonly oldRequestKey: Hex; readonly newRequestKey: Hex; readonly priorJournalHead: Hex; readonly journalHead: Hex; readonly currentContentStateHash: Hex; readonly contentStateHash: Hex; readonly requestPolicyHash: Hex; readonly incidentEvidenceHash: Hex; readonly providerEvidenceHash: Hex; readonly reasonHash: Hex; }; readonly coordinatorCodeHash: Hex; readonly activityEpoch: bigint; readonly governanceWitnessHash: Hex; }; readonly entropyOrigin: Address; readonly latestForCollection: Hex; })[]; readonly originalContinuations: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly continuation: { readonly continuationHash: Hex; readonly artistId: Hex; readonly dismissalRecordHash: Hex; readonly previousContinuationHash: Hex; readonly stableRevisionRecordHash: Hex; readonly stableDocumentHash: Hex; readonly abandonedRevisionRecordHash: Hex; }; })[]; readonly revisionContinuations: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly continuation: { readonly artistId: Hex; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; readonly stableRevisionRecordHash: Hex; readonly stableDocumentHash: Hex; readonly resolvedChildRecordHash: Hex; readonly ownerRevision: bigint; readonly continuationHash: Hex; }; })[]; readonly standingContinuations: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly continuation: { readonly artistId: Hex; readonly priorAddress: Address; readonly retirementHash: Hex; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; readonly retainedRevocationRecordHash: Hex; readonly supersededRevocationRecordHash: Hex; readonly ownerRevision: bigint; readonly continuationHash: Hex; }; readonly scopeHead: Hex; })[]; readonly capabilityContinuations: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly continuation: { readonly artistId: Hex; readonly originalActivationRecordHash: Hex; readonly originalActivationCapabilities: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly manifestHash: Hex; readonly planCommitment: Hex; readonly designationRecordHash: Hex; readonly pairedDirectiveRecordHash: Hex; readonly forbiddenDirectiveRecordHash: Hex; readonly authorityAddress: Address; readonly effectiveCapabilities: bigint; readonly commitment: Hex; }; })[]; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_PAYOUT_TUPLE = `tuple(bytes32 artistId,tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip) sourceSnapshot,tuple(tuple(address account,bytes32 recordHash) stable,tuple(address account,bytes32 recordHash) candidate,bytes32 supersessionStateCommitment,bytes32 continuationCommitment) inventory,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address payoutAccount,bytes32 previousDesignationRecordHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt) original,bytes32 evidenceHash,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) association,bytes32 abandonedUnder,tuple(bytes32 artistId,uint8 kind,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment) status,bytes32 continuationHash)[] records,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 artistId,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 manifestHash,bytes32 planCommitment,uint64 identityOwnerRevision,tuple(address account,bytes32 recordHash) stable,tuple(address account,bytes32 recordHash) candidate,bytes32 releasedChildRecordHash,bytes32 previousContinuationHash,uint64 payoutOwnerRevision,bytes32 continuationHash) continuation,bytes32 appliedCommitment)[] continuations)`;
export type ArtistUnboundPlatformHydrationPayout = { readonly artistId: Hex; readonly sourceSnapshot: { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }; readonly inventory: { readonly stable: { readonly account: Address; readonly recordHash: Hex; }; readonly candidate: { readonly account: Address; readonly recordHash: Hex; }; readonly supersessionStateCommitment: Hex; readonly continuationCommitment: Hex; }; readonly records: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly original: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly payoutAccount: Address; readonly previousDesignationRecordHash: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; }; readonly evidenceHash: Hex; readonly association: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; readonly abandonedUnder: Hex; readonly status: { readonly artistId: Hex; readonly kind: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; }; readonly continuationHash: Hex; })[]; readonly continuations: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly continuation: { readonly artistId: Hex; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly manifestHash: Hex; readonly planCommitment: Hex; readonly identityOwnerRevision: bigint; readonly stable: { readonly account: Address; readonly recordHash: Hex; }; readonly candidate: { readonly account: Address; readonly recordHash: Hex; }; readonly releasedChildRecordHash: Hex; readonly previousContinuationHash: Hex; readonly payoutOwnerRevision: bigint; readonly continuationHash: Hex; }; readonly appliedCommitment: Hex; })[]; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_BINDING_TUPLE = `tuple(tuple(bytes32 artistId,uint256 collectionId,bytes32 bindingHash) scope,bytes32 provenanceCommitment,tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) item,tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) history,tuple(bytes32 collaboratorSetHash,bytes32 capabilityPolicySetHash,uint8 mode,uint32 threshold,uint32 count) terms,tuple(uint8 kind,bytes32 reasonHash,bytes32 recordHash) terminal)`;
export type ArtistUnboundPlatformHydrationBinding = { readonly scope: { readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex; }; readonly provenanceCommitment: Hex; readonly item: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly history: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly terms: { readonly collaboratorSetHash: Hex; readonly capabilityPolicySetHash: Hex; readonly mode: bigint; readonly threshold: bigint; readonly count: bigint; }; readonly terminal: { readonly kind: bigint; readonly reasonHash: Hex; readonly recordHash: Hex; }; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_ACCEPTANCE_TUPLE = `tuple(tuple(bytes32 artistId,uint256 collectionId,bytes32 bindingHash) scope,bytes32 provenanceCommitment,bytes32 record,uint64 acceptedAt)`;
export type ArtistUnboundPlatformHydrationAcceptance = { readonly scope: { readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex; }; readonly provenanceCommitment: Hex; readonly record: Hex; readonly acceptedAt: bigint; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTRIBUTION_STATE_TUPLE = `tuple(bytes32 provenance,bytes32 artistId,uint256 collectionId,bytes32 bindingHash,tuple(uint8 state,uint64 generation) item)`;
export type ArtistUnboundPlatformHydrationAttributionState = { readonly provenance: Hex; readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex; readonly item: { readonly state: bigint; readonly generation: bigint; }; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_POLICY_TUPLE = `tuple(bytes32 provenance,bytes32 artistId,uint256 collectionId,tuple(bytes32 phaseId,bytes32 policyHash)[] policies,bytes32[] records)`;
export type ArtistUnboundPlatformHydrationPolicy = { readonly provenance: Hex; readonly artistId: Hex; readonly collectionId: bigint; readonly policies: readonly ({ readonly phaseId: Hex; readonly policyHash: Hex; })[]; readonly records: readonly (Hex)[]; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTRIBUTION_TUPLE = `tuple(${ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTRIBUTION_STATE_TUPLE} state,bytes32 proposalOrigin)`;
export interface ArtistUnboundPlatformHydrationAttribution { readonly state: ArtistUnboundPlatformHydrationAttributionState; readonly proposalOrigin: Hex; }
export const ARTIST_UNBOUND_PLATFORM_HYDRATION_STATE_TUPLE = `tuple(${ARTIST_HYDRATION_QUERY_TUPLE}[] artists,${ARTIST_HYDRATION_QUERY_TUPLE}[] collections,bytes[] rows)`;
export interface ArtistUnboundPlatformHydrationState { readonly artists: readonly ArtistHydrationQuery[]; readonly collections: readonly ArtistHydrationQuery[]; readonly rows: readonly Hex[]; }

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
const stateType = schemaType(ARTIST_UNBOUND_PLATFORM_HYDRATION_STATE_TUPLE);
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
export function normalizeArtistUnboundPlatformHydrationState(value: ArtistUnboundPlatformHydrationState): ArtistUnboundPlatformHydrationState {
  return codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_STATE_TUPLE, value);
}

export function validateArtistUnboundPlatformHydrationState(
  index: ArtistHydrationOwnerIndex,
  value: ArtistUnboundPlatformHydrationState,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistUnboundPlatformHydrationState {
  const s = normalizeArtistUnboundPlatformHydrationState(value);
  const p = codec.normalizeArtistRecoveredHydrationOwnerProvenance(provenance, index);
  if (s.artists.length > 128 || !s.collections.length || s.collections.length > 128
    || s.rows.length !== (index === 1 ? 0 : index === 2 ? Math.max(1, s.artists.length) : index === 5 ? s.artists.length : s.collections.length)) {
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
    if (!q.collectionId || q.policies.length > 128
      || i > 0 && q.collectionId <= s.collections[i - 1]!.collectionId
      || (q.artistId === Z ? q.bindingHash !== Z || q.policies.length !== 0 : q.bindingHash === Z || !s.artists.some(a => a.artistId === q.artistId))) throw Error("Invalid multiple collection query");
    const keys = new Set<string>(); policies += q.policies.length;
    for (const policy of q.policies) {
      const key = policy.phaseId + policy.policyHash;
      if (policy.phaseId === Z || policy.policyHash === Z || keys.has(key)) throw Error("Invalid multiple policy selectors");
      keys.add(key);
    }
  }
  if (policies > 128 || !s.collections.some(q => q.artistId === Z)) throw Error("Invalid unbound Platform selection");
  for (const j of p.journal) {
    if ((j.receipt.artistId === Z ? index !== 4 || ![8n,9n,10n,11n,53n].includes(j.receipt.operation) || !j.receipt.collectionId : !s.artists.some(a => a.artistId === j.receipt.artistId))
      || j.receipt.collectionId !== 0n && !s.collections.some(c => c.collectionId === j.receipt.collectionId && c.artistId === j.receipt.artistId)) {
      throw Error("Native journal lies outside complete multiple State");
    }
  }
  return s;
}

export function artistUnboundPlatformHydrationAnchor(value: ArtistUnboundPlatformHydrationState): ArtistHydrationQuery {
  const s = normalizeArtistUnboundPlatformHydrationState(value);
  const first = s.collections[0], artist = first && s.artists.find(a => a.artistId === first.artistId);
  if (!first || first.artistId !== Z && !artist) throw Error("Missing unbound Platform anchor");
  return Object.freeze({ ...first, records: first.artistId === Z ? first.records : artist!.records });
}

export function encodeArtistUnboundPlatformHydrationState(
  value: ArtistUnboundPlatformHydrationState, index: ArtistHydrationOwnerIndex,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): Hex {
  const s = validateArtistUnboundPlatformHydrationState(index, value, provenance);
  return codec.encodeTupleValues(["bytes32", "uint16", "uint8", ARTIST_UNBOUND_PLATFORM_HYDRATION_STATE_TUPLE],
    [ARTIST_UNBOUND_PLATFORM_HYDRATION_SCHEMA, 1n, BigInt(index), s]);
}

export function decodeArtistUnboundPlatformHydrationState(
  raw: Hex, index: ArtistHydrationOwnerIndex, provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistUnboundPlatformHydrationState {
  const types = ["bytes32", "uint16", "uint8", ARTIST_UNBOUND_PLATFORM_HYDRATION_STATE_TUPLE];
  const parsed = types.map(schemaType);
  const bytes = preflight(types, raw), result = coder.decode(parsed, bytes);
  if (result[0] !== ARTIST_UNBOUND_PLATFORM_HYDRATION_SCHEMA || result[1] !== 1n || result[2] !== BigInt(index)
    || coder.encode(parsed, result) !== bytes) throw Error("Noncanonical multiple State tag/version/owner");
  return validateArtistUnboundPlatformHydrationState(index, plain(stateType, result[3]) as ArtistUnboundPlatformHydrationState, provenance);
}

export function normalizeArtistUnboundPlatformHydrationIdentity(value: ArtistUnboundPlatformHydrationIdentity): ArtistUnboundPlatformHydrationIdentity {
  return codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_IDENTITY_TUPLE, value);
}
export function encodeArtistUnboundPlatformHydrationIdentity(value: ArtistUnboundPlatformHydrationIdentity): Hex {
  return codec.encodeTupleValues([ARTIST_UNBOUND_PLATFORM_HYDRATION_IDENTITY_TUPLE], [normalizeArtistUnboundPlatformHydrationIdentity(value)]);
}
export function decodeArtistUnboundPlatformHydrationIdentity(raw: Hex): ArtistUnboundPlatformHydrationIdentity {
  return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_IDENTITY_TUPLE, raw);
}
export function encodeArtistUnboundPlatformHydrationPayout(value: ArtistUnboundPlatformHydrationPayout): Hex {
  return codec.encodeTupleValues(["bytes32", ARTIST_UNBOUND_PLATFORM_HYDRATION_PAYOUT_TUPLE],
    [payoutSchema, codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_PAYOUT_TUPLE, value)]);
}
export function decodeArtistUnboundPlatformHydrationPayout(raw: Hex): ArtistUnboundPlatformHydrationPayout {
  const types = ["bytes32", ARTIST_UNBOUND_PLATFORM_HYDRATION_PAYOUT_TUPLE];
  const parsed = types.map(schemaType);
  const bytes = preflight(types, raw), v = coder.decode(parsed, bytes);
  if (v[0] !== payoutSchema || coder.encode(parsed, v) !== bytes) throw Error("Noncanonical recovered Payout row");
  return codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_PAYOUT_TUPLE,
    plain(schemaType(ARTIST_UNBOUND_PLATFORM_HYDRATION_PAYOUT_TUPLE), v[1]) as ArtistUnboundPlatformHydrationPayout);
}

export type ArtistUnboundPlatformHydrationNonceLane = ArtistUnboundPlatformHydrationIdentity["nonces"][number];

/** Exact global-index bijection; local lanes retain increasing global positions. Empty local sets are valid. */
export function artistUnboundPlatformHydrationNonceUnion(
  value: ArtistUnboundPlatformHydrationState,
  inventory: readonly shared.ArtistRecoveredHydrationNonceInventory[],
  checkpoint: Parameters<typeof codec.normalizeArtistRecoveredHydrationNonceInventory>[1],
): readonly ArtistUnboundPlatformHydrationNonceLane[] {
  const s = normalizeArtistUnboundPlatformHydrationState(value);
  const rows = codec.normalizeArtistRecoveredHydrationNonceInventory(inventory, checkpoint);
  if (s.rows.length !== s.artists.length || !s.artists.length || s.artists.length > 128) throw Error("Invalid Identity row partition");
  const result: ArtistUnboundPlatformHydrationNonceLane[] = new Array(rows.length);
  const seen = new Set<number>(), authorities = new Set<Address>();
  let timing: Hex | undefined;
  for (let i = 0; i < s.rows.length; i++) {
    const b = decodeArtistUnboundPlatformHydrationIdentity(s.rows[i]!);
    const current = hash([shared.ARTIST_RECOVERED_HYDRATION_TIMING_BUNDLE_TUPLE], [b.timing]);
    if (b.artistId !== s.artists[i]!.artistId || b.identity.authorityAddress === ZeroAddress
      || b.nextRegistrationNonce !== BigInt(s.artists.length) || authorities.has(b.identity.authorityAddress)
      || timing !== undefined && current !== timing || b.delegations.length || b.nonces.length > 128) {
      throw Error("Multiple Identity authority, registration, timing or delegation mismatch");
    }
    timing = current; authorities.add(b.identity.authorityAddress);
    let previous = -1;
    for (const lane of b.nonces) {
      const belongs = lane.kind === 1n ? lane.key === b.artistId : lane.kind === 4n
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

export function normalizeArtistUnboundPlatformHydrationOwnerPayload(
  value: shared.ArtistRecoveredHydrationOwnerPayload, index: ArtistHydrationOwnerIndex,
): shared.ArtistRecoveredHydrationOwnerPayload {
  const p = codec.normalizeArtistRecoveredHydrationOwnerPayload(value, index);
  decodeArtistUnboundPlatformHydrationState(p.semanticState, index, p.provenance);
  if (index !== 2 && p.nonces.length) throw Error("Only Identity carries multiple nonce inventory");
  return p;
}
export function encodeArtistUnboundPlatformHydrationOwnerPayload(
  value: shared.ArtistRecoveredHydrationOwnerPayload, index: ArtistHydrationOwnerIndex, features: bigint,
): Hex {
  return codec.encodeArtistRecoveredHydrationOwnerPayload(normalizeArtistUnboundPlatformHydrationOwnerPayload(value, index), index, features);
}
export function decodeArtistUnboundPlatformHydrationOwnerPayload(raw: Hex, index: ArtistHydrationOwnerIndex) {
  preflight(["bytes32", "uint16", shared.ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE], raw);
  const v = codec.decodeArtistRecoveredHydrationOwnerPayload(raw, index);
  normalizeArtistUnboundPlatformHydrationOwnerPayload(v.payload, index);
  return v;
}

function occurrence(p: shared.ArtistRecoveredHydrationOwnerProvenance, q: ArtistHydrationQuery, op: bigint, key: Hex) {
  const rows = p.journal.filter(j => j.receipt.recordHash === key);
  if (key === Z || rows.length !== 1 || rows[0]!.receipt.operation !== op || rows[0]!.receipt.artistId !== q.artistId
    || rows[0]!.receipt.collectionId !== q.collectionId) throw Error("Multiple row native occurrence mismatch");
  return rows[0]!;
}

/** Supplied Binding preimage under its original era, never the destination Registry. */
export function artistUnboundPlatformHydrationBindingHash(
  origin: shared.ArtistRecoveredHydrationOriginEnvironment, collectionId: bigint,
  value: ArtistUnboundPlatformHydrationBinding["item"],
): Hex {
  const o = codec.normalizeArtistRecoveredHydrationOriginEnvironment(origin);
  const itemType = schemaType(ARTIST_UNBOUND_PLATFORM_HYDRATION_BINDING_TUPLE).components!.find(c => c.name === "item")!;
  const b = codec.normalizeTuple(itemType.format("full"), value);
  if (typeof collectionId !== "bigint" || collectionId < 0n || collectionId >= 1n << 256n) throw Error("Expected collection uint256");
  return hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_BINDING_V1"), o.chainId, o.registry, o.core, collectionId, b.generation, b.artistId,
      b.artistAddress, b.identityRecordHash, b.consentMode, b.saleConsentScope, b.registryImmutabilityElection,
      hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), []]),
      hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []])]);
}

function collectionRows(index: ArtistHydrationOwnerIndex, s: ArtistUnboundPlatformHydrationState, p: shared.ArtistRecoveredHydrationOwnerProvenance): void {
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
  if (index === 1) { emptyOwner(p, 1); return; }
  const platformGuards: PlatformGuard[] = [];
  for (let i = 0; i < s.rows.length; i++) {
    const q = s.collections[i]!;
    const scope = { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash };
    if (q.artistId === Z) {
      if (index !== 4) { if (s.rows[i] !== "0x") throw Error("Unbound owner row must remain empty"); }
      else {
        const b = decodeArtistUnboundPlatformHydrationPlatform(s.rows[i]!);
        if (b.collectionId !== q.collectionId) throw Error("Platform slice belongs to another collection");
        platformGuards.push(...validatePlatformRows(b, p));
      }
      continue;
    }
    if (index === 0) {
      const b = decode<ArtistUnboundPlatformHydrationBinding>(ARTIST_UNBOUND_PLATFORM_HYDRATION_BINDING_TUPLE, s.rows[i]!);
      const j = occurrence(p, q, 1n, q.bindingHash), e = era(j.position.point.environmentHash);
      counts[e] = counts[e]! + 1n; records++;
      const fields = schemaType(ARTIST_UNBOUND_PLATFORM_HYDRATION_BINDING_TUPLE).components!;
      if (!same(fields[0]!.format("full"), b.scope, scope) || b.provenanceCommitment !== commitment
        || b.item.artistId !== q.artistId || b.item.bindingHash !== q.bindingHash || b.item.artistAddress === ZeroAddress
        || b.item.identityRecordHash === Z || b.item.proposer === ZeroAddress || b.item.generation !== 1n || !b.item.accepted
        || b.item.consentMode !== 1n || b.item.saleConsentScope > 1n || b.item.registryImmutabilityElection > 1n
        || !same(fields[2]!.format("full"), b.item, b.history) || b.terminal.kind !== 0n || b.terminal.reasonHash !== Z || b.terminal.recordHash !== Z
        || b.terms.count !== 0n || b.terms.mode !== 0n || b.terms.threshold !== 0n
        || b.terms.collaboratorSetHash !== hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), []])
        || b.terms.capabilityPolicySetHash !== hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []])
        || artistUnboundPlatformHydrationBindingHash(p.origins[e]!, q.collectionId, b.item) !== q.bindingHash) {
        throw Error("Multiple Binding requires accepted generation1 PRIMARY_ONLY without collaborators");
      }
      guards(j, id("binding_lifecycle.replay.proposal_key") as Hex, hash(["uint256", "uint64"], [q.collectionId, 1n]));
    } else if (index === 3) {
      const b = decode<ArtistUnboundPlatformHydrationAcceptance>(ARTIST_UNBOUND_PLATFORM_HYDRATION_ACCEPTANCE_TUPLE, s.rows[i]!);
      if (b.scope.artistId !== q.artistId || b.scope.collectionId !== q.collectionId || b.scope.bindingHash !== q.bindingHash
        || b.provenanceCommitment !== commitment || !b.acceptedAt || b.record === Z) throw Error("Multiple Acceptance scope mismatch");
      const j = occurrence(p, q, 2n, b.record), e = era(j.position.point.environmentHash);
      counts[e] = counts[e]! + 1n; records++;
      guards(j, id("acceptance_lifecycle.replay.record_uniqueness") as Hex, Z);
    } else if (index === 4) {
      const b = decode<ArtistUnboundPlatformHydrationAttribution>(ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTRIBUTION_TUPLE, s.rows[i]!);
      if (b.state.provenance !== commitment || b.state.artistId !== q.artistId || b.state.collectionId !== q.collectionId
        || b.state.bindingHash !== q.bindingHash || b.state.item.state !== 2n || b.state.item.generation !== 1n) throw Error("Multiple Attribution must be accepted generation1");
      const e = era(b.proposalOrigin); counts[e] = counts[e]! + 1n;
    } else if (index === 6) {
      const b = decode<ArtistUnboundPlatformHydrationPolicy>(ARTIST_UNBOUND_PLATFORM_HYDRATION_POLICY_TUPLE, s.rows[i]!);
      if (b.provenance !== commitment || b.artistId !== q.artistId || b.collectionId !== q.collectionId
        || !same("tuple(bytes32 phaseId,bytes32 policyHash)[]", b.policies, q.policies)
        || b.records.length !== q.policies.length || new Set(b.records).size !== b.records.length) throw Error("Multiple policy rows mismatch");
      for (let k = 0; k < b.records.length; k++) {
        const j = occurrence(p, q, 14n, b.records[k]!), e = era(j.position.point.environmentHash);
        counts[e] = counts[e]! + 1n; records++;
        guards(j, id("consent_finality.replay.policy_consent_key") as Hex,
          hash(["uint256", "bytes32", "bytes32"], [q.collectionId, q.policies[k]!.phaseId, q.policies[k]!.policyHash]));
      }
    }
  }
  if (index === 4) { platformAccounting(p, counts, platformGuards); return; }
  if (p.journal.length !== records) throw Error("Unexpected multiple collection native history");
  let total = 0n, aliases = 0n;
  for (let i = 0; i < p.eras.length; i++) {
    const e = p.eras[i]!, count = counts[i]!; total += count;
    const replay = total;
    if (e.lowerRevision !== (i ? 1n : 0n) || e.nativeCount !== count
      || e.checkpoint.ownerState.revision !== e.lowerRevision + (index === 0 ? 2n : 1n) * count
      || e.checkpoint.replayCount !== replay || !replay && e.checkpoint.replayRoot !== Z
      || e.checkpoint.nonceIndexCount !== 0n || e.checkpoint.nonceRoot !== Z) throw Error("Multiple owner global clocks/counts mismatch");
    aliases += replay;
  }
  if (BigInt(p.aliases.length) !== aliases) throw Error("Incomplete multiple collection aliases");
}

/** Original feature union. Advertisement supersets do not authorize new semantic profiles. */
export function artistUnboundPlatformHydrationRequiredFeatures(
  identities: readonly ArtistUnboundPlatformHydrationIdentity[],
  payouts: readonly ArtistUnboundPlatformHydrationPayout[], eraCount: bigint,
): bigint {
  identities = codec.normalizeTuple(`${ARTIST_UNBOUND_PLATFORM_HYDRATION_IDENTITY_TUPLE}[]`, identities);
  payouts = codec.normalizeTuple(`${ARTIST_UNBOUND_PLATFORM_HYDRATION_PAYOUT_TUPLE}[]`, payouts);
  codec.boundedArray(identities, 128); codec.boundedArray(payouts, 128, identities.length);
  if (typeof eraCount !== "bigint" || eraCount < 1n || eraCount > 16n) throw Error("Invalid multiple feature scope");
  let result = 4194304n | (eraCount > 1n ? 16n : 0n);
  for (let i = 0; i < identities.length; i++) {
    const b = normalizeArtistUnboundPlatformHydrationIdentity(identities[i]!);
    const p = codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_PAYOUT_TUPLE, payouts[i]!);
    if (b.artistId !== p.artistId || b.delegations.length) throw Error("Multiple delegated profile unsupported");
    result |= codec.artistRecoveredHydrationRequiredFeatures({ currentAuthorityClass: b.identity.authorityClass,
      recoveryAuthorityClasses: b.recoveries.map(r => r.record.fields.vestedAuthorityClass),
      hasAdjudicationV2: b.actions.some(a => a.evidenceV2.manifestHash !== Z),
      hasRewindsV3: b.actions.some(a => a.evidenceV3.manifestHash !== Z) || !!(b.revisionContinuations.length
        + b.standingContinuations.length + b.capabilityContinuations.length + p.continuations.length),
      eraCount, economicsCount: 0n, hasDelegations: false, bindingConsentMode: 1n, saleConsentCount: 0n, attestationCount: 0n });
  }
  if ((result & ~4194335n) !== 0n) throw Error("Unsupported unbound mixed feature union");
  return result;
}

/** Checks canonical rows, closed profile, complete partitions and nonce union.
 * Full Identity/Payout record semantics and external authority remain the original producer's job.
 */
export function normalizeArtistUnboundPlatformHydrationPrepared(value: shared.ArtistRecoveredHydrationPrepared): shared.ArtistRecoveredHydrationPrepared {
  const p = codec.normalizeArtistRecoveredHydrationPrepared(value);
  validateSemantic(p);
  return p;
}
function validateSemantic(p: Pick<shared.ArtistRecoveredHydrationPrepared, "query" | "data" | "timing" | "externalGuards"> & {readonly admission: Pick<shared.ArtistRecoveredHydrationCertificate, "artists" | "collections" | "provenance">}): void {
  const states: ArtistUnboundPlatformHydrationState[] = [];
  const identities: ArtistUnboundPlatformHydrationIdentity[] = [], payouts: ArtistUnboundPlatformHydrationPayout[] = [];
  let features = 0n;
  for (let owner = 0; owner < 7; owner++) {
    const index = owner as ArtistHydrationOwnerIndex;
    const { header, payload } = decodeArtistUnboundPlatformHydrationOwnerPayload(p.data[index].typedState, index);
    const s = decodeArtistUnboundPlatformHydrationState(payload.semanticState, index, payload.provenance);
    if (!same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.artists, p.admission.artists)
      || !same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.collections, p.admission.collections)
      || !same(ARTIST_HYDRATION_QUERY_TUPLE, artistUnboundPlatformHydrationAnchor(s), p.query)) throw Error("Multiple owner scope differs from full certificate");
    states.push(s); features = header.requiredFeatures;
    if (index === 2 && !s.artists.length) {
      const checkpoint = validateArtistUnboundPlatformHydrationEmptyIdentity(payload.provenance, payload.nonces, s.collections, s.rows[0]!);
      if (!same(shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, checkpoint, p.timing)) throw Error("Empty-principal timing differs from Prepared");
    } else if (index === 2) {
      artistUnboundPlatformHydrationNonceUnion(s, payload.nonces, payload.provenance.eras.at(-1)!.checkpoint);
      for (let i = 0; i < s.rows.length; i++) {
        const b = decodeArtistUnboundPlatformHydrationIdentity(s.rows[i]!);
        if (!b.recoveries.length || b.identity.status === 0n || ![1n, 3n].includes(b.identity.authorityClass)
          || !same(ARTIST_HYDRATION_SNAPSHOT_TUPLE, b.sourceSnapshot, payload.provenance.eras.at(-1)!.checkpoint.ownerState)
          || !same(shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, b.timing.checkpoint, p.timing)) throw Error("Multiple Identity requires retained class1/3 recovery and global source clock");
        const rows = payload.provenance.journal.filter(j => j.receipt.artistId === b.artistId);
        if (rows.filter(j => j.receipt.operation === 35n).length !== b.recoveries.length * 2
          || rows.some(j => [26n, 27n, 44n, 45n, 46n, 47n, 49n, 50n, 59n].includes(j.receipt.operation))) throw Error("Unsupported multiple Identity journal profile");
        identities.push(b);
      }
    } else if (index === 5) {
      if (!s.artists.length) emptyOwner(payload.provenance, 5);
      for (let i = 0; i < s.rows.length; i++) {
        const b = decodeArtistUnboundPlatformHydrationPayout(s.rows[i]!);
        if (b.artistId !== s.artists[i]!.artistId
          || !same(ARTIST_HYDRATION_SNAPSHOT_TUPLE, b.sourceSnapshot, payload.provenance.eras.at(-1)!.checkpoint.ownerState)
          || payload.provenance.journal.some(j => j.receipt.operation !== 18n || j.receipt.collectionId !== 0n)) throw Error("Multiple Payout scope mismatch");
        const rows = payload.provenance.journal.filter(j => j.receipt.artistId === b.artistId);
        if (rows.length !== b.records.length || b.records.some((r, j) => r.original.recordHash !== rows[j]!.receipt.recordHash
          || r.original.terms.artistId !== b.artistId || ![1n, 3n].includes(r.original.authorityClass)
          || !same(shared.ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE, r.position, rows[j]!.position))) throw Error("Multiple Payout occurrence mismatch");
        payouts.push(b);
      }
    } else collectionRows(index, s, payload.provenance);
  }
  let platformInventory: ArtistUnboundPlatformHydrationPlatform | undefined;
  for (let i = 0; i < p.admission.collections.length; i++) {
    const q = p.admission.collections[i]!;
    if (q.artistId === Z) {
      const b = decodeArtistUnboundPlatformHydrationPlatform(states[4]!.rows[i]!);
      if (b.catalogues.length !== p.admission.provenance.eras.length) throw Error("Incomplete Platform catalogue roster");
      if (platformInventory && (!same(`${ARTIST_UNBOUND_PLATFORM_HYDRATION_CATALOGUE_TUPLE}[]`, platformInventory.catalogues, b.catalogues)
        || !same(`${ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_OPERATION_EVIDENCE_TUPLE}[]`, platformInventory.operations, b.operations))) throw Error("Platform slices have different complete Archive inventories");
      platformInventory = b;
      for (let e = 0; e < b.catalogues.length; e++) {
        const c = b.catalogues[e]!, era = p.admission.provenance.eras[e];
        if (!era || c.originHash !== era.originHash || !same("uint64[7]", c.lower, era.lowerRevisions) || !same("uint64[7]", c.upper, era.checkpoints.map(row => row.ownerState.revision))) throw Error("Platform catalogue differs from all seven cutoffs");
      }
      continue;
    }
    const binding = occurrence(codec.artistRecoveredHydrationOwnerProvenance(p.admission.provenance, 0), q, 1n, q.bindingHash);
    const accepted = decode<ArtistUnboundPlatformHydrationAcceptance>(ARTIST_UNBOUND_PLATFORM_HYDRATION_ACCEPTANCE_TUPLE, states[3]!.rows[i]!);
    const acceptance = occurrence(codec.artistRecoveredHydrationOwnerProvenance(p.admission.provenance, 3), q, 2n, accepted.record);
    const attribution = decode<ArtistUnboundPlatformHydrationAttribution>(ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTRIBUTION_TUPLE, states[4]!.rows[i]!);
    if (binding.position.point.environmentHash !== acceptance.position.point.environmentHash
      || attribution.proposalOrigin !== binding.position.point.environmentHash) throw Error("Multiple proposal/acceptance/attribution origin mismatch");
  }
  if (features !== artistUnboundPlatformHydrationRequiredFeatures(identities, payouts, BigInt(p.admission.provenance.eras.length))) {
    throw Error("Multiple required features differ from original Identity union");
  }
}

export function encodeArtistUnboundPlatformHydrationPrepared(value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.encodeArtistRecoveredHydrationPrepared(normalizeArtistUnboundPlatformHydrationPrepared(value));
}
export function decodeArtistUnboundPlatformHydrationPrepared(raw: Hex): shared.ArtistRecoveredHydrationPrepared {
  preflight([shared.ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE], raw, shared.ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES);
  return normalizeArtistUnboundPlatformHydrationPrepared(codec.decodeArtistRecoveredHydrationPrepared(raw));
}
export function artistUnboundPlatformHydrationSemanticInventory(value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.artistRecoveredHydrationSemanticInventory(normalizeArtistUnboundPlatformHydrationPrepared(value));
}
export function artistUnboundPlatformHydrationCommitment(c: shared.ArtistRecoveredHydrationCoordinates, request: shared.ArtistRecoveredHydrationRequest, value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.artistRecoveredHydrationCommitment(c, request, normalizeArtistUnboundPlatformHydrationPrepared(value));
}
export function encodeArtistUnboundPlatformHydrationProfileEvidence(request: shared.ArtistRecoveredHydrationRequest, value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.encodeArtistRecoveredHydrationProfileEvidence(request, normalizeArtistUnboundPlatformHydrationPrepared(value));
}

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_VALIDATION = Object.freeze({
  canonicalRowsChecked: true, completeProvenanceAndNoncePartitionChecked: true,
  completeIdentityAndPayoutSemanticsIndependentlyVerified: false,
  sourceAdmissionIndependentlyVerified: false, actualRegistrySimulationRequired: true,
});

export function decodeArtistUnboundPlatformHydrationRequest(raw: Hex): shared.ArtistRecoveredHydrationRequest {
  preflight([shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE], raw);
  return codec.decodeArtistRecoveredHydrationRequest(raw);
}

/** Retained evidence has no destination before-state or live suite. It proves these
 * supplied partitions and commitments, not the original preparation admission. */
export function decodeArtistUnboundPlatformHydrationProfileEvidence(raw: Hex): shared.ArtistRecoveredHydrationProfileEvidence {
  const types = ["bytes32", "uint16", "address", "address", shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE,
    `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, ARTIST_HYDRATION_QUERY_TUPLE,
    `${ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`,
    shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, shared.ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE];
  preflight(types, raw);
  const e = codec.decodeArtistRecoveredHydrationProfileEvidence(raw);
  codec.normalizeArtistRecoveredHydrationRequest(e.request);
  const locals = e.data.map((d, i) => decodeArtistUnboundPlatformHydrationOwnerPayload(d.typedState, i as ArtistHydrationOwnerIndex));
  const origin = locals[0]!.payload.provenance;
  const provenance = codec.normalizeArtistRecoveredHydrationProvenance({ origins: origin.origins,
    eras: origin.eras.map((era, j) => ({ originHash: era.originHash, priorImportCommitment: era.priorImportCommitment,
      checkpoints: locals.map(l => l.payload.provenance.eras[j]!.checkpoint), nativeCounts: locals.map(l => l.payload.provenance.eras[j]!.nativeCount),
      lowerRevisions: locals.map(l => l.payload.provenance.eras[j]!.lowerRevision) })),
    journals: locals.map(l => l.payload.provenance.journal), aliases: locals.map(l => l.payload.provenance.aliases) } as unknown as shared.ArtistRecoveredHydrationProvenance);
  const a = e.request.records.authority;
  if (!same("bytes32[]", a.artistIds, e.artists.map(q => q.artistId)) || a.collections.length !== e.collections.length
    || a.collections.some((q, i) => q.artistId !== e.collections[i]!.artistId || q.collectionId !== e.collections[i]!.collectionId
      || !same("tuple(bytes32 phaseId,bytes32 policyHash)[]", q.policies, e.collections[i]!.policies))) throw Error("Evidence request selectors differ");
  for (let i = 0; i < 7; i++) {
    const index = i as ArtistHydrationOwnerIndex, local = locals[index]!;
    if (!same(shared.ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE, local.payload.provenance, codec.artistRecoveredHydrationOwnerProvenance(provenance, index))
      || local.header.requiredFeatures !== locals[0]!.header.requiredFeatures) throw Error("Evidence owner provenance disagrees");
    const s = decodeArtistUnboundPlatformHydrationState(local.payload.semanticState, index, local.payload.provenance);
    if (!same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.artists, e.artists) || !same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.collections, e.collections)
      || !same(ARTIST_HYDRATION_QUERY_TUPLE, artistUnboundPlatformHydrationAnchor(s), e.query)) throw Error("Evidence owner partitions differ");
    codec.validateArtistRecoveredHydrationCapability(e.request.expectedCapabilities[index], index, local.header.requiredFeatures);
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
  const last = provenance.eras.at(-1)!, deployment = provenance.origins.at(-1)!;
  const inventory = hash(["bytes32", "uint16", "bytes32", ARTIST_HYDRATION_QUERY_TUPLE, types[8]!, shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, shared.ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE],
    [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, codec.artistRecoveredHydrationProvenanceHash(provenance), e.query, e.data, e.timing, e.externalGuards]);
  if (e.prior !== deployment.registry || e.sourceCoordinator !== deployment.coordinator || e.request.expectedSourceImportCommitment !== last.priorImportCommitment
    || e.request.expectedSemanticInventory !== inventory || !same(`${ARTIST_HYDRATION_CHECKPOINT_TUPLE}[7]`, a.expectedSource, last.checkpoints)) throw Error("Evidence source commitments differ");
  codec.normalizeArtistRecoveredHydrationTimingCheckpoint(e.timing);
  codec.normalizeArtistRecoveredHydrationExternalGuards(e.externalGuards);
  if (e.externalGuards.provenanceCommitment !== codec.artistRecoveredHydrationProvenanceHash(provenance)
    || e.externalGuards.artistId !== (e.artists[0]?.artistId ?? Z)
    || !e.artists.length && e.externalGuards.schema !== ARTIST_UNBOUND_PLATFORM_HYDRATION_SCHEMA) throw Error("Evidence external guards differ");
  for (let i = 0; i < 7; i++) {
    const index = i as ArtistHydrationOwnerIndex, d = e.data[index], cp = last.checkpoints[index];
    if (d.nonces.length || d.origins.length !== Number(cp.replayCount) || d.sourceKeys.length !== d.origins.length || d.cells.length !== d.origins.length
      || !same("tuple(bytes32 surface,bytes32 scope)[]", d.origins, a.replayOrigins[index])) throw Error("Evidence replay guard inventory differs");
    const aliases = provenance.aliases[index]; const seen = new Set<Hex>();
    d.origins.forEach((origin, k) => { const key = codec.artistRecoveredHydrationReplayKey(deployment, index, origin);
      const row = aliases.find(v => v.originalKey === key);
      if (seen.has(key) || d.sourceKeys[k] !== key || !row || row.originHash !== last.originHash || row.surface !== origin.surface || row.scope !== origin.scope
        || !same(ARTIST_HYDRATION_REPLAY_CELL_TUPLE, row.cell, d.cells[k])) throw Error("Evidence replay preimages differ");
      seen.add(key);
    });
  }
  validateSemantic({...e, admission:{artists:e.artists,collections:e.collections,provenance}});
  return e;
}

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_TUPLE = `(bytes32 provenance, uint256 collectionId, ((bytes32 recordHash, bytes32 statementHash, address actor, uint64 declaredAt) declaration, uint8 contestState, bytes32 contestClaim, bytes32 contestRecord, uint256 claimCount, bytes32 latestClaim, (uint256 collectionId, address proposedArtist, bytes32 claimRecordHash, bytes32 sustainedContestRecordHash, bytes32 evidenceHash, bytes32 reasonHash, bytes32 approvalActionId, uint64 approvedAt, uint64 correctiveGeneration, bool accepted, bytes32 recordHash) correction) state, (bytes32 environmentHash, uint8 ownerIndex, uint64 ownerRevision) declarationPoint, (bytes32 environmentHash, uint8 ownerIndex, uint64 ownerRevision) correctionPoint, ((bytes32 environmentHash, uint8 ownerIndex, uint64 ownerRevision) point, (uint256 collectionId, address claimant, address proposedArtist, bytes32 evidenceHash, bytes32 reasonHash, uint64 filedAt, bytes32 recordHash) record)[] claims, ((bytes32 environmentHash, uint8 ownerIndex, uint64 ownerRevision) point, (uint256 collectionId, address adjudicatedArtist, uint8 state, bytes32 claimRecordHash, bytes32 evidenceHash, bytes32 reasonHash, bytes32 actionId, bytes32 previousRecordHash, uint64 changedAt, bytes32 recordHash) record)[] contests, ((bytes32 environmentHash, uint8 ownerIndex, uint64 ownerRevision) point, (bytes32 recordHash, uint256 collectionId, address claimant, bytes32 evidenceHash, bytes32 reasonHash, string reasonURI, uint64 filedAt, address proposedArtist, bytes32 previousRecordHash, uint256 index) record)[] allegations, uint256 allegationCount, bytes32 latestAllegation, bytes32 latestDisplayClaim, (bytes32 originalCorrectionRecord, bytes32 latestLineageRecord, uint64 generation, uint64 count, bool effectiveAccepted, bytes32 latestAcceptanceRecord) status, ((bytes32 recordHash, uint256 collectionId, bytes32 declarationHash, bytes32 originalCorrectionRecord, bytes32 previousLineageRecord, bytes32 previousBindingHash, uint64 previousGeneration, bytes32 bindingHash, uint64 generation, bytes32 artistId, address artist, bytes32 approvalHash, bytes32 governanceActionId, uint64 recordedAt) record, (bytes32 recordHash, bytes32 lineageRecord, bytes32 acceptanceRecord, uint64 acceptedAt) acceptance)[] continuations, (bytes32 originHash, bytes32 archiveCodeHash, bytes32 configurationHash, uint256 count, bytes32 rowsHash, uint64[7] lower, uint64[7] upper)[] catalogues, (bytes32 originHash, uint16 operation, (uint256 catalogueIndex, address pointer, bytes32 payloadHash, bytes32 evidenceId) evidence)[] operations)`;
export type ArtistUnboundPlatformHydrationPlatform = { readonly provenance: Hex; readonly collectionId: bigint; readonly state: { readonly declaration: { readonly recordHash: Hex; readonly statementHash: Hex; readonly actor: Address; readonly declaredAt: bigint; }; readonly contestState: bigint; readonly contestClaim: Hex; readonly contestRecord: Hex; readonly claimCount: bigint; readonly latestClaim: Hex; readonly correction: { readonly collectionId: bigint; readonly proposedArtist: Address; readonly claimRecordHash: Hex; readonly sustainedContestRecordHash: Hex; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly approvalActionId: Hex; readonly approvedAt: bigint; readonly correctiveGeneration: bigint; readonly accepted: boolean; readonly recordHash: Hex; }; }; readonly declarationPoint: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly correctionPoint: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly claims: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly record: { readonly collectionId: bigint; readonly claimant: Address; readonly proposedArtist: Address; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly filedAt: bigint; readonly recordHash: Hex; }; })[]; readonly contests: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly record: { readonly collectionId: bigint; readonly adjudicatedArtist: Address; readonly state: bigint; readonly claimRecordHash: Hex; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly actionId: Hex; readonly previousRecordHash: Hex; readonly changedAt: bigint; readonly recordHash: Hex; }; })[]; readonly allegations: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly record: { readonly recordHash: Hex; readonly collectionId: bigint; readonly claimant: Address; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly reasonURI: string; readonly filedAt: bigint; readonly proposedArtist: Address; readonly previousRecordHash: Hex; readonly index: bigint; }; })[]; readonly allegationCount: bigint; readonly latestAllegation: Hex; readonly latestDisplayClaim: Hex; readonly status: { readonly originalCorrectionRecord: Hex; readonly latestLineageRecord: Hex; readonly generation: bigint; readonly count: bigint; readonly effectiveAccepted: boolean; readonly latestAcceptanceRecord: Hex; }; readonly continuations: readonly ({ readonly record: { readonly recordHash: Hex; readonly collectionId: bigint; readonly declarationHash: Hex; readonly originalCorrectionRecord: Hex; readonly previousLineageRecord: Hex; readonly previousBindingHash: Hex; readonly previousGeneration: bigint; readonly bindingHash: Hex; readonly generation: bigint; readonly artistId: Hex; readonly artist: Address; readonly approvalHash: Hex; readonly governanceActionId: Hex; readonly recordedAt: bigint; }; readonly acceptance: { readonly recordHash: Hex; readonly lineageRecord: Hex; readonly acceptanceRecord: Hex; readonly acceptedAt: bigint; }; })[]; readonly catalogues: readonly ({ readonly originHash: Hex; readonly archiveCodeHash: Hex; readonly configurationHash: Hex; readonly count: bigint; readonly rowsHash: Hex; readonly lower: ArtistHydrationSeven<bigint>; readonly upper: ArtistHydrationSeven<bigint>; })[]; readonly operations: readonly ({ readonly originHash: Hex; readonly operation: bigint; readonly evidence: { readonly catalogueIndex: bigint; readonly pointer: Address; readonly payloadHash: Hex; readonly evidenceId: Hex; }; })[]; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_CATALOGUE_TUPLE = `(bytes32 originHash, bytes32 archiveCodeHash, bytes32 configurationHash, uint256 count, bytes32 rowsHash, uint64[7] lower, uint64[7] upper)`;
export type ArtistUnboundPlatformHydrationCatalogue = { readonly originHash: Hex; readonly archiveCodeHash: Hex; readonly configurationHash: Hex; readonly count: bigint; readonly rowsHash: Hex; readonly lower: ArtistHydrationSeven<bigint>; readonly upper: ArtistHydrationSeven<bigint>; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_OPERATION_EVIDENCE_TUPLE = `(bytes32 originHash, uint16 operation, (uint256 catalogueIndex, address pointer, bytes32 payloadHash, bytes32 evidenceId) evidence)`;
export type ArtistUnboundPlatformHydrationPlatformOperationEvidence = { readonly originHash: Hex; readonly operation: bigint; readonly evidence: { readonly catalogueIndex: bigint; readonly pointer: Address; readonly payloadHash: Hex; readonly evidenceId: Hex; }; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_ARCHIVE_ENVELOPE_TUPLE = `(uint16 version, bytes32 configurationHash, uint16 operation, address actor, bytes32 value, (bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip)[7] before_, (bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip)[7] after_, bytes payload)`;
export type ArtistUnboundPlatformHydrationArchiveEnvelope = { readonly version: bigint; readonly configurationHash: Hex; readonly operation: bigint; readonly actor: Address; readonly value: Hex; readonly before_: ArtistHydrationSeven<{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }>; readonly after_: ArtistHydrationSeven<{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }>; readonly payload: Hex; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATE_TUPLE = `((bytes32 recordHash, bytes32 statementHash, address actor, uint64 declaredAt) declaration, uint8 contestState, bytes32 contestClaim, bytes32 contestRecord, uint256 claimCount, bytes32 latestClaim, (uint256 collectionId, address proposedArtist, bytes32 claimRecordHash, bytes32 sustainedContestRecordHash, bytes32 evidenceHash, bytes32 reasonHash, bytes32 approvalActionId, uint64 approvedAt, uint64 correctiveGeneration, bool accepted, bytes32 recordHash) correction)`;
export type ArtistUnboundPlatformHydrationPlatformState = { readonly declaration: { readonly recordHash: Hex; readonly statementHash: Hex; readonly actor: Address; readonly declaredAt: bigint; }; readonly contestState: bigint; readonly contestClaim: Hex; readonly contestRecord: Hex; readonly claimCount: bigint; readonly latestClaim: Hex; readonly correction: { readonly collectionId: bigint; readonly proposedArtist: Address; readonly claimRecordHash: Hex; readonly sustainedContestRecordHash: Hex; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly approvalActionId: Hex; readonly approvedAt: bigint; readonly correctiveGeneration: bigint; readonly accepted: boolean; readonly recordHash: Hex; }; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_CLAIM_TUPLE = `(uint256 collectionId, address claimant, address proposedArtist, bytes32 evidenceHash, bytes32 reasonHash, uint64 filedAt, bytes32 recordHash)`;
export type ArtistUnboundPlatformHydrationPlatformClaim = { readonly collectionId: bigint; readonly claimant: Address; readonly proposedArtist: Address; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly filedAt: bigint; readonly recordHash: Hex; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_CONTEST_TUPLE = `(uint256 collectionId, address adjudicatedArtist, uint8 state, bytes32 claimRecordHash, bytes32 evidenceHash, bytes32 reasonHash, bytes32 actionId, bytes32 previousRecordHash, uint64 changedAt, bytes32 recordHash)`;
export type ArtistUnboundPlatformHydrationPlatformContest = { readonly collectionId: bigint; readonly adjudicatedArtist: Address; readonly state: bigint; readonly claimRecordHash: Hex; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly actionId: Hex; readonly previousRecordHash: Hex; readonly changedAt: bigint; readonly recordHash: Hex; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTRIBUTION_CLAIM_TUPLE = `(bytes32 recordHash, uint256 collectionId, address claimant, bytes32 evidenceHash, bytes32 reasonHash, string reasonURI, uint64 filedAt, address proposedArtist, bytes32 previousRecordHash, uint256 index)`;
export type ArtistUnboundPlatformHydrationAttributionClaim = { readonly recordHash: Hex; readonly collectionId: bigint; readonly claimant: Address; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly reasonURI: string; readonly filedAt: bigint; readonly proposedArtist: Address; readonly previousRecordHash: Hex; readonly index: bigint; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATUS_TUPLE = `(bytes32 originalCorrectionRecord, bytes32 latestLineageRecord, uint64 generation, uint64 count, bool effectiveAccepted, bytes32 latestAcceptanceRecord)`;
export type ArtistUnboundPlatformHydrationPlatformStatus = { readonly originalCorrectionRecord: Hex; readonly latestLineageRecord: Hex; readonly generation: bigint; readonly count: bigint; readonly effectiveAccepted: boolean; readonly latestAcceptanceRecord: Hex; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_CLAIM_PAYLOAD_TUPLE = `(uint256 id, bytes32 evidence, bytes32 reason, string uri, (uint16 schemaVersion, uint256 collectionId, address proposedArtist, bytes32 claimRecordHash, bytes32 narrativeHash) evidenceDocument, (uint16 schemaVersion, uint256 collectionId, address proposedArtist, bytes32 claimRecordHash, bytes32 narrativeHash) reasonDocument, bytes32 evidenceProof, bytes32 reasonProof)`;
export type ArtistUnboundPlatformHydrationClaimPayload = { readonly id: bigint; readonly evidence: Hex; readonly reason: Hex; readonly uri: string; readonly evidenceDocument: { readonly schemaVersion: bigint; readonly collectionId: bigint; readonly proposedArtist: Address; readonly claimRecordHash: Hex; readonly narrativeHash: Hex; }; readonly reasonDocument: { readonly schemaVersion: bigint; readonly collectionId: bigint; readonly proposedArtist: Address; readonly claimRecordHash: Hex; readonly narrativeHash: Hex; }; readonly evidenceProof: Hex; readonly reasonProof: Hex; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_CONTEST_PAYLOAD_TUPLE = `(uint256 id, uint8 state, bytes32 claim, bytes32 evidence, bytes32 reason, bool correction, (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash) context, (bytes32 actionId, address proposer, uint8 actionClass, bytes32 roleMutationHash, uint64 roleRevision, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash) governance, (uint16 schemaVersion, uint256 collectionId, address proposedArtist, bytes32 claimRecordHash, bytes32 narrativeHash) evidenceDocument, (uint16 schemaVersion, uint256 collectionId, address proposedArtist, bytes32 claimRecordHash, bytes32 narrativeHash) reasonDocument, bytes32 evidenceProof, bytes32 reasonProof)`;
export type ArtistUnboundPlatformHydrationContestPayload = { readonly id: bigint; readonly state: bigint; readonly claim: Hex; readonly evidence: Hex; readonly reason: Hex; readonly correction: boolean; readonly context: { readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex; }; readonly governance: { readonly actionId: Hex; readonly proposer: Address; readonly actionClass: bigint; readonly roleMutationHash: Hex; readonly roleRevision: bigint; readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex; }; readonly evidenceDocument: { readonly schemaVersion: bigint; readonly collectionId: bigint; readonly proposedArtist: Address; readonly claimRecordHash: Hex; readonly narrativeHash: Hex; }; readonly reasonDocument: { readonly schemaVersion: bigint; readonly collectionId: bigint; readonly proposedArtist: Address; readonly claimRecordHash: Hex; readonly narrativeHash: Hex; }; readonly evidenceProof: Hex; readonly reasonProof: Hex; };

export const ARTIST_UNBOUND_PLATFORM_HYDRATION_FEATURE = 4194304n;
export const ARTIST_UNBOUND_PLATFORM_HYDRATION_ADVERTISED_FEATURES = 8388607n;
export interface ArtistUnboundPlatformHydrationInput { readonly request: shared.ArtistRecoveredHydrationRequest; readonly royaltyFreezes: readonly never[]; }
export type ArtistUnboundPlatformHydrationCall = shared.ArtistRecoveredHydrationCall & { readonly royaltyFreezes: readonly never[] };
export function normalizeArtistUnboundPlatformHydrationInputDraft(value: ArtistUnboundPlatformHydrationInput): ArtistUnboundPlatformHydrationInput {
  value = codec.normalizeTuple(`tuple(${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,bytes[] royaltyFreezes)`, value);
  if (value.royaltyFreezes.length) throw Error("Unbound Platform rejects royalty witnesses");
  return Object.freeze({request:codec.normalizeArtistRecoveredHydrationRequestDraft(value.request),royaltyFreezes:Object.freeze([])});
}
export function normalizeArtistUnboundPlatformHydrationInput(value: ArtistUnboundPlatformHydrationInput): ArtistUnboundPlatformHydrationInput {
  const v=normalizeArtistUnboundPlatformHydrationInputDraft(value); codec.normalizeArtistRecoveredHydrationRequest(v.request); return v;
}
export function prepareArtistUnboundPlatformHydrationCall(registry: Address, caller: Address, value: ArtistUnboundPlatformHydrationInput): ArtistUnboundPlatformHydrationCall {
  const v=normalizeArtistUnboundPlatformHydrationInput(value);
  return Object.freeze({...codec.prepareArtistRecoveredHydrationCall(registry,caller,v.request),royaltyFreezes:v.royaltyFreezes});
}
export function normalizeArtistUnboundPlatformHydrationCall(value: ArtistUnboundPlatformHydrationCall): ArtistUnboundPlatformHydrationCall {
  value=codec.normalizeTuple(`tuple(address registry,address caller,${shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request,bytes32 profile,bytes4 capabilityId,tuple(address to,uint256 value,bytes data) call,bool factsVerified,bytes[] royaltyFreezes)`,value);
  const {royaltyFreezes,...raw}=value;
  if(royaltyFreezes.length) throw Error("Unbound Platform rejects royalty witnesses");
  return Object.freeze({...codec.normalizeArtistRecoveredHydrationCall(raw),royaltyFreezes:Object.freeze([])});
}
export function artistUnboundPlatformHydrationPreparationCalldata(destination: ArtistHydrationSuite,value: ArtistUnboundPlatformHydrationInput): Hex {
  return codec.artistRecoveredHydrationPreparationCalldata(destination,normalizeArtistUnboundPlatformHydrationInputDraft(value).request);
}
export function validateArtistUnboundPlatformHydrationInput(value: ArtistUnboundPlatformHydrationInput,prepared: shared.ArtistRecoveredHydrationPrepared): ArtistUnboundPlatformHydrationInput {
  const input=normalizeArtistUnboundPlatformHydrationInput(value),p=normalizeArtistUnboundPlatformHydrationPrepared(prepared);
  codec.encodeArtistRecoveredHydrationProfileEvidence(input.request,p); return input;
}

export type ArtistUnboundPlatformHydrationAttributionRow = ArtistUnboundPlatformHydrationAttribution;
export type ArtistUnboundPlatformHydrationPolicyBundle = ArtistUnboundPlatformHydrationPolicy;
export function decodeArtistUnboundPlatformHydrationBinding(raw: Hex): ArtistUnboundPlatformHydrationBinding { return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_BINDING_TUPLE,raw); }
export function decodeArtistUnboundPlatformHydrationAcceptance(raw: Hex): ArtistUnboundPlatformHydrationAcceptance { return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_ACCEPTANCE_TUPLE,raw); }
export function decodeArtistUnboundPlatformHydrationAttributionRow(raw: Hex): ArtistUnboundPlatformHydrationAttributionRow { return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTRIBUTION_TUPLE,raw); }
export function decodeArtistUnboundPlatformHydrationPolicyBundle(raw: Hex): ArtistUnboundPlatformHydrationPolicyBundle { return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_POLICY_TUPLE,raw); }

export function normalizeArtistUnboundPlatformHydrationPlatform(value: ArtistUnboundPlatformHydrationPlatform): ArtistUnboundPlatformHydrationPlatform { return codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_TUPLE,value); }
export function encodeArtistUnboundPlatformHydrationPlatform(value: ArtistUnboundPlatformHydrationPlatform): Hex { return codec.encodeTupleValues([ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_TUPLE],[normalizeArtistUnboundPlatformHydrationPlatform(value)]); }
export function decodeArtistUnboundPlatformHydrationPlatform(raw: Hex): ArtistUnboundPlatformHydrationPlatform { return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_TUPLE,raw); }

export function normalizeArtistUnboundPlatformHydrationCatalogue(value: ArtistUnboundPlatformHydrationCatalogue): ArtistUnboundPlatformHydrationCatalogue { return codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_CATALOGUE_TUPLE,value); }
export function encodeArtistUnboundPlatformHydrationCatalogue(value: ArtistUnboundPlatformHydrationCatalogue): Hex { return codec.encodeTupleValues([ARTIST_UNBOUND_PLATFORM_HYDRATION_CATALOGUE_TUPLE],[normalizeArtistUnboundPlatformHydrationCatalogue(value)]); }
export function decodeArtistUnboundPlatformHydrationCatalogue(raw: Hex): ArtistUnboundPlatformHydrationCatalogue { return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_CATALOGUE_TUPLE,raw); }

export function normalizeArtistUnboundPlatformHydrationPlatformOperationEvidence(value: ArtistUnboundPlatformHydrationPlatformOperationEvidence): ArtistUnboundPlatformHydrationPlatformOperationEvidence { return codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_OPERATION_EVIDENCE_TUPLE,value); }
export function encodeArtistUnboundPlatformHydrationPlatformOperationEvidence(value: ArtistUnboundPlatformHydrationPlatformOperationEvidence): Hex { return codec.encodeTupleValues([ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_OPERATION_EVIDENCE_TUPLE],[normalizeArtistUnboundPlatformHydrationPlatformOperationEvidence(value)]); }
export function decodeArtistUnboundPlatformHydrationPlatformOperationEvidence(raw: Hex): ArtistUnboundPlatformHydrationPlatformOperationEvidence { return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_OPERATION_EVIDENCE_TUPLE,raw); }

export function normalizeArtistUnboundPlatformHydrationPlatformState(value: ArtistUnboundPlatformHydrationPlatformState): ArtistUnboundPlatformHydrationPlatformState { return codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATE_TUPLE,value); }
export function encodeArtistUnboundPlatformHydrationPlatformState(value: ArtistUnboundPlatformHydrationPlatformState): Hex { return codec.encodeTupleValues([ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATE_TUPLE],[normalizeArtistUnboundPlatformHydrationPlatformState(value)]); }
export function decodeArtistUnboundPlatformHydrationPlatformState(raw: Hex): ArtistUnboundPlatformHydrationPlatformState { return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATE_TUPLE,raw); }

export function normalizeArtistUnboundPlatformHydrationPlatformClaim(value: ArtistUnboundPlatformHydrationPlatformClaim): ArtistUnboundPlatformHydrationPlatformClaim { return codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_CLAIM_TUPLE,value); }
export function encodeArtistUnboundPlatformHydrationPlatformClaim(value: ArtistUnboundPlatformHydrationPlatformClaim): Hex { return codec.encodeTupleValues([ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_CLAIM_TUPLE],[normalizeArtistUnboundPlatformHydrationPlatformClaim(value)]); }
export function decodeArtistUnboundPlatformHydrationPlatformClaim(raw: Hex): ArtistUnboundPlatformHydrationPlatformClaim { return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_CLAIM_TUPLE,raw); }

export function normalizeArtistUnboundPlatformHydrationPlatformContest(value: ArtistUnboundPlatformHydrationPlatformContest): ArtistUnboundPlatformHydrationPlatformContest { return codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_CONTEST_TUPLE,value); }
export function encodeArtistUnboundPlatformHydrationPlatformContest(value: ArtistUnboundPlatformHydrationPlatformContest): Hex { return codec.encodeTupleValues([ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_CONTEST_TUPLE],[normalizeArtistUnboundPlatformHydrationPlatformContest(value)]); }
export function decodeArtistUnboundPlatformHydrationPlatformContest(raw: Hex): ArtistUnboundPlatformHydrationPlatformContest { return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_CONTEST_TUPLE,raw); }

export function normalizeArtistUnboundPlatformHydrationAttributionClaim(value: ArtistUnboundPlatformHydrationAttributionClaim): ArtistUnboundPlatformHydrationAttributionClaim { return codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTRIBUTION_CLAIM_TUPLE,value); }
export function encodeArtistUnboundPlatformHydrationAttributionClaim(value: ArtistUnboundPlatformHydrationAttributionClaim): Hex { return codec.encodeTupleValues([ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTRIBUTION_CLAIM_TUPLE],[normalizeArtistUnboundPlatformHydrationAttributionClaim(value)]); }
export function decodeArtistUnboundPlatformHydrationAttributionClaim(raw: Hex): ArtistUnboundPlatformHydrationAttributionClaim { return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTRIBUTION_CLAIM_TUPLE,raw); }

export function normalizeArtistUnboundPlatformHydrationPlatformStatus(value: ArtistUnboundPlatformHydrationPlatformStatus): ArtistUnboundPlatformHydrationPlatformStatus { return codec.normalizeTuple(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATUS_TUPLE,value); }
export function encodeArtistUnboundPlatformHydrationPlatformStatus(value: ArtistUnboundPlatformHydrationPlatformStatus): Hex { return codec.encodeTupleValues([ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATUS_TUPLE],[normalizeArtistUnboundPlatformHydrationPlatformStatus(value)]); }
export function decodeArtistUnboundPlatformHydrationPlatformStatus(raw: Hex): ArtistUnboundPlatformHydrationPlatformStatus { return decode(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATUS_TUPLE,raw); }

function flatEncode(type: string,value: unknown): Hex {
  const p=schemaType(type),v=codec.normalizeTuple(type,value) as Record<string,unknown>;
  return codec.encodeTupleValues(p.components!.map(c=>c.format("full")),p.components!.map(c=>v[c.name]));
}
function flatDecode<T>(type:string,raw:Hex):T {
  const p=schemaType(type),types=p.components!.map(c=>c.format("full")),bytes=preflight(types,raw),d=coder.decode(types,bytes);
  if(coder.encode(types,d)!==bytes) throw Error("Noncanonical flat Archive payload");
  return codec.normalizeTuple(type,plain(p,d) as T);
}
export function encodeArtistUnboundPlatformHydrationArchiveEnvelope(value:ArtistUnboundPlatformHydrationArchiveEnvelope):Hex { return flatEncode(ARTIST_UNBOUND_PLATFORM_HYDRATION_ARCHIVE_ENVELOPE_TUPLE,value); }
export function decodeArtistUnboundPlatformHydrationArchiveEnvelope(raw:Hex):ArtistUnboundPlatformHydrationArchiveEnvelope { return flatDecode(ARTIST_UNBOUND_PLATFORM_HYDRATION_ARCHIVE_ENVELOPE_TUPLE,raw); }
export function encodeArtistUnboundPlatformHydrationClaimPayload(value:ArtistUnboundPlatformHydrationClaimPayload):Hex { return flatEncode(ARTIST_UNBOUND_PLATFORM_HYDRATION_CLAIM_PAYLOAD_TUPLE,value); }
export function decodeArtistUnboundPlatformHydrationClaimPayload(raw:Hex):ArtistUnboundPlatformHydrationClaimPayload { return flatDecode(ARTIST_UNBOUND_PLATFORM_HYDRATION_CLAIM_PAYLOAD_TUPLE,raw); }
export function encodeArtistUnboundPlatformHydrationContestPayload(value:ArtistUnboundPlatformHydrationContestPayload):Hex { return flatEncode(ARTIST_UNBOUND_PLATFORM_HYDRATION_CONTEST_PAYLOAD_TUPLE,value); }
export function decodeArtistUnboundPlatformHydrationContestPayload(raw:Hex):ArtistUnboundPlatformHydrationContestPayload { return flatDecode(ARTIST_UNBOUND_PLATFORM_HYDRATION_CONTEST_PAYLOAD_TUPLE,raw); }

export function encodeArtistUnboundPlatformHydrationEmptyIdentity(value:shared.ArtistRecoveredHydrationTimingCheckpoint):Hex {
  return codec.encodeTupleValues(["bytes32","uint16",shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE],[ARTIST_UNBOUND_PLATFORM_HYDRATION_SCHEMA,1n,codec.normalizeArtistRecoveredHydrationTimingCheckpoint(value)]);
}
export function decodeArtistUnboundPlatformHydrationEmptyIdentity(raw:Hex):shared.ArtistRecoveredHydrationTimingCheckpoint {
  const types=["bytes32","uint16",shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE],b=preflight(types,raw),d=coder.decode(types,b);
  if(d[0]!==ARTIST_UNBOUND_PLATFORM_HYDRATION_SCHEMA||d[1]!==1n||coder.encode(types,d)!==b)throw Error("Invalid empty-principal timing row");
  return codec.normalizeArtistRecoveredHydrationTimingCheckpoint(plain(schemaType(types[2]!),d[2]) as shared.ArtistRecoveredHydrationTimingCheckpoint);
}
function zeroValue(p:ParamType):unknown {
  if(p.baseType==="tuple")return Object.fromEntries(p.components!.map(c=>[c.name,zeroValue(c)]));
  if(p.baseType==="array")return Array.from({length:p.arrayLength===-1?0:p.arrayLength!},()=>zeroValue(p.arrayChildren!));
  if(p.type==="address")return ZeroAddress;if(p.type==="bool")return false;if(p.type==="string")return "";
  if(p.type.startsWith("bytes"))return p.type==="bytes"?"0x":"0x"+"00".repeat(Number(p.type.slice(5)));return 0n;
}
function emptyOwner(p:shared.ArtistRecoveredHydrationOwnerProvenance,index:ArtistHydrationOwnerIndex):void {
  p=codec.normalizeArtistRecoveredHydrationOwnerProvenance(p,index);
  if(p.journal.length||p.aliases.length)throw Error("Empty owner has retained history");
  p.eras.forEach((e,i)=>{if(e.lowerRevision!==(i?1n:0n)||e.nativeCount||e.checkpoint.ownerState.revision!==e.lowerRevision||e.checkpoint.replayCount||e.checkpoint.replayRoot!==Z||e.checkpoint.nonceIndexCount||e.checkpoint.nonceRoot!==Z)throw Error("Empty owner clocks differ");});
}
export function validateArtistUnboundPlatformHydrationEmptyIdentity(
  provenance:shared.ArtistRecoveredHydrationOwnerProvenance,nonces:readonly shared.ArtistRecoveredHydrationNonceInventory[],collections:readonly ArtistHydrationQuery[],raw:Hex,
):shared.ArtistRecoveredHydrationTimingCheckpoint {
  const x=codec.normalizeTuple(`tuple(${shared.ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE} provenance,${shared.ARTIST_RECOVERED_HYDRATION_NONCE_INVENTORY_TUPLE}[] nonces,${ARTIST_HYDRATION_QUERY_TUPLE}[] collections,bytes raw)`,{provenance,nonces,collections,raw});
  const p=codec.normalizeArtistRecoveredHydrationOwnerProvenance(x.provenance,2),cp=decodeArtistUnboundPlatformHydrationEmptyIdentity(x.raw);
  const zero=zeroValue(schemaType(shared.ARTIST_RECOVERED_HYDRATION_TIMING_CONFIGURATION_TUPLE));
  if(x.nonces.length||p.journal.length||cp.count||cp.root!==Z||cp.configurationHash!==hash([shared.ARTIST_RECOVERED_HYDRATION_TIMING_CONFIGURATION_TUPLE],[zero]))throw Error("Empty-principal timing/nonces are not untouched");
  const surface=(s:string)=>id("identity_authority.replay."+s),latch=surface("one_way_cutover_latch"),lane=surface("verified_lane_key"),link=surface("import_binding"),binding=surface("import_binding_key"),action=surface("governance_action");
  let aliases=0;
  p.eras.forEach((e,index)=>{
    let lanes=0n,links=0n,roots=0n,actions=0n,cutovers=0n;
    for(const a of p.aliases){if(a.originHash!==e.originHash)continue;aliases++;
      if(a.ownerIndex!==2n||a.cell.kind!==1n||a.cell.status!==2n||a.cell.commitment===Z)throw Error("Invalid empty-principal replay cell");
      if(a.surface===latch){if(a.scope!==Z||a.admittedAt.environmentHash!==e.originHash||a.admittedAt.ownerRevision!==e.checkpoint.ownerState.revision)throw Error("Invalid original cutover latch");cutovers++;}
      else if(a.surface===lane||a.surface===link){
        if(!index||a.admittedAt.environmentHash!==e.originHash||a.admittedAt.ownerRevision<2n||a.admittedAt.ownerRevision>=e.lowerRevision||!x.collections.some(q=>a.scope===(a.surface===lane?hash(["uint8","bytes32"],[2n,word(q.collectionId)]):hash(["uint256","uint8","bytes32"],[0n,2n,word(q.collectionId)]))))throw Error("Invalid collection-only verified lane");
        if(a.surface===lane)lanes++;else links++;
      }else if(a.surface===binding){if(a.scope===Z)throw Error("Empty import root key");roots++;}
      else if(a.surface===action){if(a.scope===Z)throw Error("Empty import action key");actions++;}else throw Error("Unsupported empty-principal replay surface");
    }
    if(cutovers!==1n||lanes!==links||roots!==BigInt(index)||actions!==BigInt(index)||e.lowerRevision!==(index?2n+lanes:0n)||e.checkpoint.ownerState.revision!==e.lowerRevision+1n||e.nativeCount||e.checkpoint.nonceIndexCount||e.checkpoint.nonceRoot!==Z||e.checkpoint.replayCount!==1n+lanes+links+roots+actions)throw Error("Empty-principal era accounting mismatch");
  });
  if(aliases!==p.aliases.length)throw Error("Orphaned empty-principal replay alias");
  return cp;
}
function word(v:bigint):Hex {return codec.encodeTupleValues(["uint256"],[v]);}

type PlatformGuard=Readonly<{surface:Hex;scope:Hex;commitment:Hex;point:shared.ArtistRecoveredHydrationPoint}>;
const platformOps=[8n,9n,10n,11n,53n] as const;
const nativePlatform=(op:bigint)=>platformOps.some(x=>x===op);
const samePoint=(a:shared.ArtistRecoveredHydrationPoint,b:shared.ArtistRecoveredHydrationPoint)=>same(shared.ARTIST_RECOVERED_HYDRATION_POINT_TUPLE,a,b);
const nativeCount=(b:ArtistUnboundPlatformHydrationPlatform)=>Number(b.state.declaration.recordHash!==Z)+Number(b.state.correction.recordHash!==Z)+b.claims.length+b.contests.length+b.allegations.length;
function platformSurface(op:bigint):Hex { return op===10n?id("attribution_lifecycle.replay.claim_record_hash_uniqueness") as Hex:hash(["string","uint16"],["PLATFORM_WORKS",op]); }
function eraAt(p:shared.ArtistRecoveredHydrationOwnerProvenance,origin:Hex):number {const n=p.eras.findIndex(e=>e.originHash===origin);if(n<0)throw Error("Unknown original era");return n;}
function platformAccounting(p:shared.ArtistRecoveredHydrationOwnerProvenance,accepted:readonly bigint[],guards:readonly PlatformGuard[]):void {
  if(accepted.length!==p.eras.length||guards.length!==p.journal.length)throw Error("Incomplete global Platform journal partition");
  const mutations=p.eras.map(()=>0n);for(const g of guards){const e=eraAt(p,g.point.environmentHash);mutations[e]=mutations[e]!+1n;}
  p.eras.forEach((e,i)=>{const count=BigInt(guards.filter(g=>eraAt(p,g.point.environmentHash)<=i).length);
    if(e.lowerRevision!==(i?1n:0n)||e.checkpoint.ownerState.revision!==e.lowerRevision+2n*accepted[i]!+mutations[i]!||e.nativeCount!==mutations[i]||e.checkpoint.replayCount!==count||e.checkpoint.nonceIndexCount||e.checkpoint.nonceRoot!==Z)throw Error("Platform owner4 clocks or cumulative replay count differ");
  });
  const seen=new Set<string>();
  for(const g of guards){const key=g.surface+g.scope;if(seen.has(key))throw Error("Repeated Platform replay subject");seen.add(key);
    for(let i=eraAt(p,g.point.environmentHash);i<p.eras.length;i++){
      const rows=p.aliases.filter(a=>a.originHash===p.eras[i]!.originHash&&a.surface===g.surface&&a.scope===g.scope);
      if(rows.length!==1||rows[0]!.ownerIndex!==4n||rows[0]!.cell.kind!==1n||rows[0]!.cell.status!==2n||rows[0]!.cell.commitment!==g.commitment||!samePoint(rows[0]!.admittedAt,g.point))throw Error("Platform replay alias differs from original admission");
    }
  }
  if(p.aliases.some(a=>!guards.some(g=>a.surface===g.surface&&a.scope===g.scope&&a.cell.commitment===g.commitment&&samePoint(a.admittedAt,g.point))))throw Error("Orphaned Platform replay alias");
}
function validatePlatformRows(b:ArtistUnboundPlatformHydrationPlatform,p:shared.ArtistRecoveredHydrationOwnerProvenance):readonly PlatformGuard[]{
  if(!b.collectionId||b.provenance!==codec.artistRecoveredHydrationOwnerProvenanceHash(p,4)||!nativeCount(b)||nativeCount(b)>8192||b.state.declaration.recordHash===Z||b.state.correction.correctiveGeneration||b.state.correction.accepted||b.continuations.length)throw Error("Invalid unbound Platform slice");
  let current=zeroValue(schemaType(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATE_TUPLE)) as ArtistUnboundPlatformHydrationPlatformState;
  let claims=0,contests=0,allegations=0,allegation=Z,display=Z;const guards:PlatformGuard[]=[];
  for(const j of p.journal){const op=j.receipt.operation;if(!nativePlatform(op)||j.receipt.collectionId!==b.collectionId)continue;
    if(j.receipt.artistId!==Z||guards.length===nativeCount(b))throw Error("Invalid zero-Artist Platform journal occurrence");
    const o=p.origins[eraAt(p,j.position.point.environmentHash)]!;let scope:Hex;
    if(op===8n){const r=b.state.declaration;
      if(current.declaration.recordHash!==Z||r.recordHash===Z||r.statementHash===Z||r.actor===ZeroAddress||!samePoint(b.declarationPoint,j.position.point)||j.receipt.recordHash!==r.recordHash||r.recordHash!==hash(["bytes32","uint256","address","address","uint256","bytes32","uint64"],[id("6529STREAM_PLATFORM_WORKS_DECLARATION_V1"),o.chainId,o.registry,o.core,b.collectionId,r.statementHash,r.declaredAt]))throw Error("Invalid original Platform declaration preimage");
      current={...current,declaration:r};scope=word(b.collectionId);
    }else if(op===9n){const row=b.claims[claims++],r=row?.record;
      if(!row||!r||current.declaration.recordHash===Z||r.collectionId!==b.collectionId||r.claimant===ZeroAddress||r.evidenceHash===Z||r.reasonHash===Z||!samePoint(row.point,j.position.point)||r.recordHash!==j.receipt.recordHash||r.recordHash!==hash(["bytes32","uint256","address","address","uint256","address","bytes32","bytes32","uint64"],[id("6529STREAM_PLATFORM_WORKS_CLAIM_RECORD_V1"),o.chainId,o.registry,o.core,b.collectionId,r.claimant,r.evidenceHash,r.reasonHash,r.filedAt]))throw Error("Invalid original Platform claim preimage");
      current={...current,claimCount:current.claimCount+1n,latestClaim:r.recordHash};display=r.recordHash;scope=hash(["uint256","address","bytes32","bytes32"],[b.collectionId,r.claimant,r.evidenceHash,r.reasonHash]);
    }else if(op===10n){const row=b.allegations[allegations++],r=row?.record;
      if(!row||!r||r.collectionId!==b.collectionId||r.claimant===ZeroAddress||r.evidenceHash===Z||r.reasonHash===Z||!r.filedAt||new TextEncoder().encode(r.reasonURI).length>4096||r.index!==BigInt(allegations)||r.previousRecordHash!==allegation||!samePoint(row.point,j.position.point)||r.recordHash!==j.receipt.recordHash||r.recordHash!==hash(["bytes32","uint256","address","address","uint256","address","bytes32","bytes32","uint64"],[id("6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1"),o.chainId,o.registry,o.core,b.collectionId,r.claimant,r.evidenceHash,r.reasonHash,r.filedAt]))throw Error("Invalid original attribution allegation preimage");
      allegation=r.recordHash;display=r.recordHash;scope=hash(["uint256","address","bytes32","bytes32"],[b.collectionId,r.claimant,r.evidenceHash,r.reasonHash]);
    }else if(op===11n){const row=b.contests[contests++],r=row?.record;
      if(!row||!r||current.declaration.recordHash===Z||r.collectionId!==b.collectionId||r.evidenceHash===Z||r.reasonHash===Z||r.actionId===Z||r.previousRecordHash!==current.contestRecord||!samePoint(row.point,j.position.point)||r.recordHash!==j.receipt.recordHash||(r.state===1n?![0n,2n].includes(current.contestState):![2n,3n].includes(r.state)||current.contestState!==1n||current.contestClaim!==r.claimRecordHash)||!b.claims.slice(0,claims).some(x=>x.record.recordHash===r.claimRecordHash)||r.recordHash!==hash(["bytes32","uint256","address",ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_CONTEST_TUPLE],[id("6529STREAM_PLATFORM_WORKS_CONTEST_TRANSITION_V1"),o.chainId,o.owners[4],{...r,recordHash:Z}]))throw Error("Invalid original Platform contest transition");
      current={...current,contestState:r.state,contestClaim:r.claimRecordHash,contestRecord:r.recordHash};scope=hash(["uint256","bytes32"],[b.collectionId,r.actionId]);
    }else{const r=b.state.correction;
      if(current.correction.recordHash!==Z||current.contestState!==3n||!contests||r.collectionId!==b.collectionId||r.claimRecordHash!==current.contestClaim||r.sustainedContestRecordHash!==current.contestRecord||r.proposedArtist===ZeroAddress||r.proposedArtist!==b.contests[contests-1]!.record.adjudicatedArtist||r.evidenceHash===Z||r.reasonHash===Z||r.approvalActionId===Z||!samePoint(b.correctionPoint,j.position.point)||r.recordHash!==j.receipt.recordHash||r.recordHash!==hash(["bytes32","uint256","address","address","uint256","bytes32","bytes32","bytes32","bytes32","bytes32","uint64"],[id("6529STREAM_PLATFORM_WORKS_CORRECTION_RECORD_V1"),o.chainId,o.registry,o.core,b.collectionId,r.sustainedContestRecordHash,r.claimRecordHash,r.evidenceHash,r.reasonHash,r.approvalActionId,r.approvedAt]))throw Error("Invalid unused Platform correction preimage");
      current={...current,correction:{...r,correctiveGeneration:0n,accepted:false}};scope=hash(["uint256","bytes32"],[b.collectionId,r.approvalActionId]);
    }
    guards.push(Object.freeze({surface:platformSurface(op),scope,commitment:j.receipt.recordHash,point:j.position.point}));
  }
  if(guards.length!==nativeCount(b)||claims!==b.claims.length||contests!==b.contests.length||allegations!==b.allegations.length||BigInt(allegations)!==b.allegationCount||allegation!==b.latestAllegation||display!==b.latestDisplayClaim||!same(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATE_TUPLE,current,b.state))throw Error("Incomplete Platform rows or current display head");
  const actions=new Set<Hex>();for(const row of b.contests){const a=row.record.actionId;if(actions.has(a)||a===b.state.correction.approvalActionId)throw Error("Repeated original Platform governance action");actions.add(a);}
  const status={...(zeroValue(schemaType(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATUS_TUPLE)) as ArtistUnboundPlatformHydrationPlatformStatus),originalCorrectionRecord:b.state.correction.recordHash};
  if(!same(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATUS_TUPLE,b.status,status))throw Error("Unbound Platform cannot carry correction lineage");
  return Object.freeze(guards);
}
export function validateArtistUnboundPlatformHydrationPlatform(value:ArtistUnboundPlatformHydrationPlatform,provenance:shared.ArtistRecoveredHydrationOwnerProvenance):Readonly<{guards:readonly PlatformGuard[];factsVerified:false}> {
  const x=codec.normalizeTuple(`tuple(${ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_TUPLE} value,${shared.ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE} provenance)`,{value,provenance});
  const p=codec.normalizeArtistRecoveredHydrationOwnerProvenance(x.provenance,4);
  return Object.freeze({guards:validatePlatformRows(x.value,p),factsVerified:false});
}

/** Supplied canonical Archive bytes authenticate immutable transition preimages. This does
 * not read the Archive, authenticate its catalogue storage or execute governance authority. */
export function validateArtistUnboundPlatformHydrationPlatformTimeline(
  value:ArtistUnboundPlatformHydrationPlatform,provenance:shared.ArtistRecoveredHydrationOwnerProvenance,
  facts:Readonly<{envelopes:readonly Hex[]}>,
):Readonly<{state:ArtistUnboundPlatformHydrationPlatformState;factsVerified:false;catalogueRowsIndependentlyVerified:false}> {
  const x=codec.normalizeTuple(`tuple(${ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_TUPLE} value,${shared.ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE} provenance,tuple(bytes[] envelopes) facts)`,{value,provenance,facts});
  const b=x.value,p=codec.normalizeArtistRecoveredHydrationOwnerProvenance(x.provenance,4),raws=x.facts.envelopes;
  validatePlatformRows(b,p);
  if(b.catalogues.length!==p.eras.length||b.operations.length!==raws.length||b.operations.length>8448||raws.reduce((n,r)=>n+(r.length-2)/2,0)>shared.ARTIST_RECOVERED_HYDRATION_MAX_BYTES)throw Error("Incomplete or oversized Platform Archive inventory");
  let catalogueCount=0n;
  b.catalogues.forEach((c,i)=>{const e=p.eras[i]!,o=p.origins[i]!;catalogueCount+=c.count;
    if(c.originHash!==e.originHash||c.archiveCodeHash===Z||c.configurationHash===Z||c.rowsHash===Z||c.lower[4]!==e.lowerRevision||c.upper[4]!==e.checkpoint.ownerState.revision||c.count>16384n||catalogueCount>16384n||codec.artistRecoveredHydrationOriginHash(o)!==c.originHash)throw Error("Invalid saved Platform catalogue/cutoff");
  });
  let current=zeroValue(schemaType(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATE_TUPLE)) as ArtistUnboundPlatformHydrationPlatformState,count=0,previousEra=0,previousRevision=0n;
  const seen=new Set<string>();
  for(let i=0;i<b.operations.length;i++){
    const row=b.operations[i]!,era=eraAt(p,row.originHash),o=p.origins[era]!,c=b.catalogues[era]!,raw=raws[i]!,e=decodeArtistUnboundPlatformHydrationArchiveEnvelope(raw);
    const evidenceId=hash(["bytes32","uint256","address","address","uint16","address","bytes32"],[id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),o.chainId,o.registry,o.coordinator,e.operation,e.actor,e.value]);
    const key=row.originHash+":"+row.evidence.catalogueIndex;
    if(e.version!==1n||e.configurationHash!==c.configurationHash||e.actor===ZeroAddress||e.value===Z||e.operation!==row.operation||![1n,2n,3n,4n,8n,9n,10n,11n,53n].includes(e.operation)||row.evidence.catalogueIndex>=c.count||row.evidence.pointer===ZeroAddress||row.evidence.payloadHash!==keccak256(raw)||row.evidence.evidenceId!==evidenceId||seen.has(key)||e.after_[4]!.revision<=c.lower[4]!||e.after_[4]!.revision>c.upper[4]!||era<previousEra||i>0&&era===previousEra&&e.after_[4]!.revision<=previousRevision)throw Error("Platform Archive envelope/evidence/order mismatch");
    seen.add(key);previousEra=era;previousRevision=e.after_[4]!.revision;
    if(!nativePlatform(e.operation))continue;
    if(e.payload.length<66)throw Error("Truncated original Platform payload");
    const collection=BigInt(e.payload.slice(0,66));if(collection!==b.collectionId)continue;
    current=advancePlatform(b,current,p,era,e);count++;
  }
  if(count!==nativeCount(b)||!same(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATE_TUPLE,current,b.state))throw Error("Platform Archive timeline is incomplete");
  return Object.freeze({state:normalizeArtistUnboundPlatformHydrationPlatformState(current),factsVerified:false,catalogueRowsIndependentlyVerified:false});
}
function advancePlatform(b:ArtistUnboundPlatformHydrationPlatform,current:ArtistUnboundPlatformHydrationPlatformState,p:shared.ArtistRecoveredHydrationOwnerProvenance,era:number,e:ArtistUnboundPlatformHydrationArchiveEnvelope):ArtistUnboundPlatformHydrationPlatformState {
  const o=p.origins[era]!,point={environmentHash:p.eras[era]!.originHash,ownerIndex:4n,ownerRevision:e.after_[4]!.revision};
  let scope:Hex,action=e.value,state:Hex|undefined,record=e.operation===11n?Z:e.value;
  if(e.operation===8n){
    const types=["uint256","bytes32","bytes32","uint64"],raw=preflight(types,e.payload),d=coder.decode(types,raw);
    if(coder.encode(types,d)!==raw||d[0]!==b.collectionId||d[1]!==b.state.declaration.statementHash||e.actor!==b.state.declaration.actor||e.value!==b.state.declaration.recordHash||!samePoint(point,b.declarationPoint)||current.declaration.recordHash!==Z)throw Error("Declaration Archive fields differ");
    current={...current,declaration:b.state.declaration};scope=word(b.collectionId);
  }else if(e.operation===9n||e.operation===10n){
    const c=decodeArtistUnboundPlatformHydrationClaimPayload(e.payload);
    platformDocuments(b.collectionId,c.evidence,c.reason,Z,c.evidenceDocument,c.reasonDocument);
    if(c.id!==b.collectionId||new TextEncoder().encode(c.uri).length>4096)throw Error("Invalid original claim payload scope/URI");
    scope=hash(["uint256","address","bytes32","bytes32"],[c.id,e.actor,c.evidence,c.reason]);
    if(e.operation===9n){const r=b.claims.find(row=>samePoint(row.point,point))?.record;
      if(!r||r.recordHash!==e.value||r.claimant!==e.actor||r.evidenceHash!==c.evidence||r.reasonHash!==c.reason||r.proposedArtist!==c.evidenceDocument.proposedArtist)throw Error("Claim Archive fields differ");
      current={...current,claimCount:current.claimCount+1n,latestClaim:r.recordHash};
    }else{const r=b.allegations.find(row=>samePoint(row.point,point))?.record;
      if(!r||r.recordHash!==e.value||r.claimant!==e.actor||r.evidenceHash!==c.evidence||r.reasonHash!==c.reason||r.proposedArtist!==c.evidenceDocument.proposedArtist||r.reasonURI!==c.uri)throw Error("Allegation Archive fields differ");
      state=hash([ARTIST_UNBOUND_PLATFORM_HYDRATION_ATTRIBUTION_CLAIM_TUPLE],[r]);
      action=hash(["uint256","address","bytes32","bytes32","string","address"],[c.id,e.actor,c.evidence,c.reason,c.uri,c.evidenceDocument.proposedArtist]);
    }
  }else{
    const c=decodeArtistUnboundPlatformHydrationContestPayload(e.payload),correction=e.operation===53n;
    platformDocuments(b.collectionId,c.evidence,c.reason,c.claim,c.evidenceDocument,c.reasonDocument);
    const scopeHash=hash(["bytes32","uint256","address","address","uint256","bool"],[id("6529STREAM_PLATFORM_WORKS_GOVERNANCE_SCOPE_V1"),o.chainId,o.registry,o.core,b.collectionId,correction]);
    const shape=schemaType(ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATE_TUPLE).components!,declarationType=shape.find(c=>c.name==="declaration")!.format("full"),correctionType=shape.find(c=>c.name==="correction")!.format("full");
    const oldValueHash=hash([declarationType,"uint8","bytes32","bytes32",correctionType],[current.declaration,current.contestState,current.contestClaim,current.contestRecord,current.correction]);
    const newValueHash=hash(["bytes32","bytes32","uint8","bytes32","bytes32","bytes32"],[scopeHash,oldValueHash,c.state,c.claim,c.evidence,c.reason]);
    if(c.id!==b.collectionId||c.correction!==correction||correction&&c.state!==3n||c.context.scopeHash!==scopeHash||c.context.oldValueHash!==oldValueHash||c.context.newValueHash!==newValueHash||c.governance.scopeHash!==scopeHash||c.governance.oldValueHash!==oldValueHash||c.governance.newValueHash!==newValueHash||c.governance.actionId===Z||c.governance.proposer===ZeroAddress||c.governance.roleMutationHash===Z||!c.governance.roleRevision||c.governance.actionClass!==(correction?2n:1n))throw Error("Original Platform governance context differs");
    scope=hash(["uint256","bytes32"],[b.collectionId,c.governance.actionId]);
    if(correction){const r=b.state.correction;
      if(!samePoint(point,b.correctionPoint)||r.recordHash!==e.value||r.claimRecordHash!==c.claim||r.evidenceHash!==c.evidence||r.reasonHash!==c.reason||r.approvalActionId!==c.governance.actionId||r.proposedArtist!==c.evidenceDocument.proposedArtist||current.correction.recordHash!==Z)throw Error("Correction Archive fields differ");
      current={...current,correction:{...r,correctiveGeneration:0n,accepted:false}};
    }else{const r=b.contests.find(row=>samePoint(row.point,point))?.record;
      if(!r||r.recordHash!==e.value||r.state!==c.state||r.claimRecordHash!==c.claim||r.evidenceHash!==c.evidence||r.reasonHash!==c.reason||r.actionId!==c.governance.actionId||r.adjudicatedArtist!==c.evidenceDocument.proposedArtist)throw Error("Contest Archive fields differ");
      current={...current,contestState:r.state,contestClaim:r.claimRecordHash,contestRecord:r.recordHash};
    }
  }
  if(e.operation!==10n)state=hash(["uint256",ARTIST_UNBOUND_PLATFORM_HYDRATION_PLATFORM_STATE_TUPLE],[b.collectionId,current]);
  const zero=zeroValue(schemaType(ARTIST_HYDRATION_SNAPSHOT_TUPLE));
  for(let i=0;i<7;i++){if(i===4)continue;const before=e.before_[i]!,after=e.after_[i]!;
    if(e.operation===8n&&(i===0||i===6)){if(before.domainId!==codec.artistRecoveredHydrationOwnerDomain(i)||before.stateRoot===Z||before.recordChainTip===Z||!same(ARTIST_HYDRATION_SNAPSHOT_TUPLE,before,after))throw Error("Declaration unchanged read-owner snapshot differs");}
    else if(!same(ARTIST_HYDRATION_SNAPSHOT_TUPLE,before,zero)||!same(ARTIST_HYDRATION_SNAPSHOT_TUPLE,after,zero))throw Error("Unexpected Archive owner snapshot");
  }
  const replay=codec.artistRecoveredHydrationReplayKey(o,4,{surface:platformSurface(e.operation),scope});
  platformTransition(o,p,era,e,action,state!,replay,record);
  return current;
}
function platformDocuments(collection:bigint,evidence:Hex,reason:Hex,claim:Hex,a:ArtistUnboundPlatformHydrationClaimPayload["evidenceDocument"],b:ArtistUnboundPlatformHydrationClaimPayload["reasonDocument"]):void {
  const type=schemaType(ARTIST_UNBOUND_PLATFORM_HYDRATION_CLAIM_PAYLOAD_TUPLE).components!.find(c=>c.name==="evidenceDocument")!.format("full");
  if(evidence===Z||reason===Z||a.schemaVersion!==1n||b.schemaVersion!==1n||a.collectionId!==collection||b.collectionId!==collection||a.narrativeHash===Z||b.narrativeHash===Z||a.claimRecordHash!==claim||b.claimRecordHash!==claim||a.proposedArtist!==b.proposedArtist||hash([type],[a])!==evidence||hash([type],[b])!==reason)throw Error("Platform evidence documents differ");
}
function platformTransition(o:shared.ArtistRecoveredHydrationOriginEnvironment,p:shared.ArtistRecoveredHydrationOwnerProvenance,era:number,e:ArtistUnboundPlatformHydrationArchiveEnvelope,action:Hex,state:Hex,replay:Hex,record:Hex):void {
  const a=e.before_[4]!,b=e.after_[4]!,domain=codec.artistRecoveredHydrationOwnerDomain(4);
  if(a.domainId!==domain||b.domainId!==domain||a.stateRoot===Z||a.recordChainTip===Z||a.revision<p.eras[era]!.lowerRevision||b.revision!==a.revision+1n||b.revision>p.eras[era]!.checkpoint.ownerState.revision||e.actor===ZeroAddress)throw Error("Invalid original owner4 Archive clock");
  const h=hash(["bytes32","uint256","address","address","address","address","bytes32","uint64","uint64","bytes32","bytes32","bytes32","bytes32","bytes32"],[id("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"),o.chainId,o.registry,o.coordinator,o.archive,o.owners[4],domain,a.revision,b.revision,a.stateRoot,hash(["uint16","address","bytes32"],[e.operation,e.actor,action]),state,replay,hash(["bytes32"],[record])]);
  if(b.stateRoot!==h)throw Error("Original owner4 state transition preimage differs");
  if(record===Z){if(a.recordChainTip!==b.recordChainTip)throw Error("Original contest record tip must stay unchanged");}
  else{const n=BigInt(p.journal.filter(j=>j.position.point.environmentHash===p.eras[era]!.originHash&&j.position.point.ownerRevision<=a.revision&&[8n,9n,10n,53n,47n,61n].includes(j.receipt.operation)).length);
    if(b.recordChainTip!==hash(["bytes32","uint256","address","address","address","address","bytes32","uint64","uint64","bytes32","bytes32"],[id("6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2"),o.chainId,o.registry,o.coordinator,o.archive,o.owners[4],domain,n,n+1n,a.recordChainTip,record]))throw Error("Original owner4 record transition preimage differs");
  }
}
