import { AbiCoder, ParamType, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { ArtistHydrationQuery, ArtistHydrationOwnerIndex, ArtistHydrationSuite } from "./current-artist-authority-hydration.js";
import { ARTIST_HYDRATION_QUERY_TUPLE, ARTIST_HYDRATION_SNAPSHOT_TUPLE, ARTIST_HYDRATION_NONCE_WORD_TUPLE, ARTIST_HYDRATION_OWNER_DATA_TUPLE, ARTIST_HYDRATION_CHECKPOINT_TUPLE } from "./current-artist-authority-hydration.js";
import * as shared from "./internal/artist-recovered-hydration-codec.js";

export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_SOURCE = "99e9503020ea713b558835ac6fe1a034e36994a2";
export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_BASE = 262144n;
export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_ALLOWED_FEATURES = 262175n;
export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_KNOWN_FEATURES = 524287n;
export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_SCHEMA = id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_BASE_V1") as Hex;

export type {
  ArtistRecoveredHydrationCapability as ArtistRecoveredMultipleHydrationCapability,
  ArtistRecoveredHydrationEconomicsConsent as ArtistRecoveredMultipleHydrationEconomicsConsent,
  ArtistRecoveredHydrationAttestation as ArtistRecoveredMultipleHydrationAttestation,
  ArtistRecoveredHydrationAttestationInput as ArtistRecoveredMultipleHydrationAttestationInput,
  ArtistRecoveredHydrationCollectionWitness as ArtistRecoveredMultipleHydrationCollectionWitness,
  ArtistRecoveredHydrationRecordsRequest as ArtistRecoveredMultipleHydrationRecordsRequest,
  ArtistRecoveredHydrationRequest as ArtistRecoveredMultipleHydrationRequest,
  ArtistRecoveredHydrationExportHeader as ArtistRecoveredMultipleHydrationExportHeader,
  ArtistRecoveredHydrationOriginEnvironment as ArtistRecoveredMultipleHydrationOriginEnvironment,
  ArtistRecoveredHydrationEra as ArtistRecoveredMultipleHydrationEra,
  ArtistRecoveredHydrationPoint as ArtistRecoveredMultipleHydrationPoint,
  ArtistRecoveredHydrationPosition as ArtistRecoveredMultipleHydrationPosition,
  ArtistRecoveredHydrationJournalEntry as ArtistRecoveredMultipleHydrationJournalEntry,
  ArtistRecoveredHydrationReplayAlias as ArtistRecoveredMultipleHydrationReplayAlias,
  ArtistRecoveredHydrationProvenance as ArtistRecoveredMultipleHydrationProvenance,
  ArtistRecoveredHydrationOwnerEra as ArtistRecoveredMultipleHydrationOwnerEra,
  ArtistRecoveredHydrationOwnerProvenance as ArtistRecoveredMultipleHydrationOwnerProvenance,
  ArtistRecoveredHydrationNonceInventory as ArtistRecoveredMultipleHydrationNonceInventory,
  ArtistRecoveredHydrationEnvelope as ArtistRecoveredMultipleHydrationEnvelope,
  ArtistRecoveredHydrationPublication as ArtistRecoveredMultipleHydrationPublication,
  ArtistRecoveredHydrationOwnerPayload as ArtistRecoveredMultipleHydrationOwnerPayload,
  ArtistRecoveredHydrationTimingConfiguration as ArtistRecoveredMultipleHydrationTimingConfiguration,
  ArtistRecoveredHydrationTimingInput as ArtistRecoveredMultipleHydrationTimingInput,
  ArtistRecoveredHydrationTimingEntry as ArtistRecoveredMultipleHydrationTimingEntry,
  ArtistRecoveredHydrationTimingCheckpoint as ArtistRecoveredMultipleHydrationTimingCheckpoint,
  ArtistRecoveredHydrationTimingBundle as ArtistRecoveredMultipleHydrationTimingBundle,
  ArtistRecoveredHydrationActionWitness as ArtistRecoveredMultipleHydrationActionWitness,
  ArtistRecoveredHydrationActionFacts as ArtistRecoveredMultipleHydrationActionFacts,
  ArtistRecoveredHydrationActionGuard as ArtistRecoveredMultipleHydrationActionGuard,
  ArtistRecoveredHydrationFinalityScope as ArtistRecoveredMultipleHydrationFinalityScope,
  ArtistRecoveredHydrationFinalityComponent as ArtistRecoveredMultipleHydrationFinalityComponent,
  ArtistRecoveredHydrationFinalityManifest as ArtistRecoveredMultipleHydrationFinalityManifest,
  ArtistRecoveredHydrationFinalityEvidence as ArtistRecoveredMultipleHydrationFinalityEvidence,
  ArtistRecoveredHydrationFinalityRecord as ArtistRecoveredMultipleHydrationFinalityRecord,
  ArtistRecoveredHydrationFinalityTarget as ArtistRecoveredMultipleHydrationFinalityTarget,
  ArtistRecoveredHydrationFinalityGuard as ArtistRecoveredMultipleHydrationFinalityGuard,
  ArtistRecoveredHydrationEntropyReceipt as ArtistRecoveredMultipleHydrationEntropyReceipt,
  ArtistRecoveredHydrationEntropyEvidence as ArtistRecoveredMultipleHydrationEntropyEvidence,
  ArtistRecoveredHydrationEntropyGuard as ArtistRecoveredMultipleHydrationEntropyGuard,
  ArtistRecoveredHydrationExternalGuards as ArtistRecoveredMultipleHydrationExternalGuards,
  ArtistRecoveredHydrationCertificate as ArtistRecoveredMultipleHydrationCertificate,
  ArtistRecoveredHydrationPrepared as ArtistRecoveredMultipleHydrationPrepared,
  ArtistRecoveredHydrationEvidenceDescriptor as ArtistRecoveredMultipleHydrationEvidenceDescriptor,
  ArtistRecoveredHydrationCoordinates as ArtistRecoveredMultipleHydrationCoordinates,
  ArtistRecoveredHydrationCall as ArtistRecoveredMultipleHydrationCall,
  ArtistRecoveredHydrationProfileEvidence as ArtistRecoveredMultipleHydrationProfileEvidence,
  ArtistRecoveredHydrationOperationEvidence as ArtistRecoveredMultipleHydrationOperationEvidence,
  ArtistRecoveredHydrationHistoricalCell as ArtistRecoveredMultipleHydrationHistoricalCell,
  ArtistRecoveredHydrationFeatureFacts as ArtistRecoveredMultipleHydrationFeatureFacts
} from "./internal/artist-recovered-hydration-codec.js";

export {
  ARTIST_RECOVERED_HYDRATION_PROFILE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_PROFILE,
  ARTIST_RECOVERED_HYDRATION_PAGE_BYTES as ARTIST_RECOVERED_MULTIPLE_HYDRATION_PAGE_BYTES,
  ARTIST_RECOVERED_HYDRATION_MAX_BYTES as ARTIST_RECOVERED_MULTIPLE_HYDRATION_MAX_BYTES,
  ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES as ARTIST_RECOVERED_MULTIPLE_HYDRATION_MAX_PREPARED_BYTES,
  ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA as ARTIST_RECOVERED_MULTIPLE_HYDRATION_CHECKPOINT_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_PAYLOAD_SCHEMA as ARTIST_RECOVERED_MULTIPLE_HYDRATION_PAYLOAD_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_EVIDENCE_SCHEMA as ARTIST_RECOVERED_MULTIPLE_HYDRATION_EVIDENCE_SCHEMA,
  ARTIST_RECOVERED_HYDRATION_CAPABILITY_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_CAPABILITY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_ECONOMICS_CONSENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ATTESTATION_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_ATTESTATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ATTESTATION_INPUT_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_ATTESTATION_INPUT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_COLLECTION_WITNESS_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_COLLECTION_WITNESS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_RECORDS_REQUEST_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_RECORDS_REQUEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_REQUEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EXPORT_HEADER_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_EXPORT_HEADER_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ERA_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_ERA_TUPLE,
  ARTIST_RECOVERED_HYDRATION_POINT_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_POINT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_POSITION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_JOURNAL_ENTRY_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_JOURNAL_ENTRY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_REPLAY_ALIAS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PROVENANCE_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_PROVENANCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_ERA_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_OWNER_ERA_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_OWNER_PROVENANCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_NONCE_INVENTORY_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_NONCE_INVENTORY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_ENVELOPE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PUBLICATION_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_PUBLICATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_OWNER_PAYLOAD_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_OWNER_PAYLOAD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_CONFIGURATION_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_TIMING_CONFIGURATION_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_INPUT_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_TIMING_INPUT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_ENTRY_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_TIMING_ENTRY_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_TIMING_CHECKPOINT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_TIMING_BUNDLE_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_TIMING_BUNDLE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_WITNESS_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_ACTION_WITNESS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_FACTS_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_ACTION_FACTS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ACTION_GUARD_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_ACTION_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_SCOPE_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_FINALITY_SCOPE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_COMPONENT_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_FINALITY_COMPONENT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_MANIFEST_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_FINALITY_MANIFEST_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_EVIDENCE_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_FINALITY_EVIDENCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_RECORD_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_FINALITY_RECORD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_TARGET_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_FINALITY_TARGET_TUPLE,
  ARTIST_RECOVERED_HYDRATION_FINALITY_GUARD_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_FINALITY_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_RECEIPT_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_ENTROPY_RECEIPT_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_EVIDENCE_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_ENTROPY_EVIDENCE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_ENTROPY_GUARD_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_ENTROPY_GUARD_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_EXTERNAL_GUARDS_TUPLE,
  ARTIST_RECOVERED_HYDRATION_CERTIFICATE_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_CERTIFICATE_TUPLE,
  ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_PREPARED_TUPLE,
  ARTIST_RECOVERED_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE as ARTIST_RECOVERED_MULTIPLE_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE
} from "./internal/artist-recovered-hydration-codec.js";

const codec = shared.createArtistRecoveredHydrationCodec(262175n);
export const {
  artistRecoveredHydrationOwnerDomain: artistRecoveredMultipleHydrationOwnerDomain,
  artistRecoveredHydrationOwnerTag: artistRecoveredMultipleHydrationOwnerTag,
  normalizeArtistRecoveredHydrationCoordinates: normalizeArtistRecoveredMultipleHydrationCoordinates,
  normalizeArtistRecoveredHydrationCapability: normalizeArtistRecoveredMultipleHydrationCapability,
  validateArtistRecoveredHydrationCapability: validateArtistRecoveredMultipleHydrationCapability,
  normalizeArtistRecoveredHydrationRequestDraft: normalizeArtistRecoveredMultipleHydrationRequestDraft,
  normalizeArtistRecoveredHydrationRequest: normalizeArtistRecoveredMultipleHydrationRequest,
  encodeArtistRecoveredHydrationRequest: encodeArtistRecoveredMultipleHydrationRequest,
  CURRENT_ARTIST_RECOVERED_HYDRATION_ABI: CURRENT_ARTIST_RECOVERED_MULTIPLE_HYDRATION_ABI,
  ARTIST_RECOVERED_HYDRATION_CAPABILITY_ID: ARTIST_RECOVERED_MULTIPLE_HYDRATION_CAPABILITY_ID,
  prepareArtistRecoveredHydrationCall: prepareArtistRecoveredMultipleHydrationCall,
  normalizeArtistRecoveredHydrationCall: normalizeArtistRecoveredMultipleHydrationCall,
  normalizeArtistRecoveredHydrationOriginEnvironment: normalizeArtistRecoveredMultipleHydrationOriginEnvironment,
  artistRecoveredHydrationOriginHash: artistRecoveredMultipleHydrationOriginHash,
  artistRecoveredHydrationReplayKey: artistRecoveredMultipleHydrationReplayKey,
  normalizeArtistRecoveredHydrationOwnerProvenance: normalizeArtistRecoveredMultipleHydrationOwnerProvenance,
  artistRecoveredHydrationOwnerProvenance: artistRecoveredMultipleHydrationOwnerProvenance,
  normalizeArtistRecoveredHydrationProvenance: normalizeArtistRecoveredMultipleHydrationProvenance,
  artistRecoveredHydrationProvenanceHash: artistRecoveredMultipleHydrationProvenanceHash,
  artistRecoveredHydrationOwnerProvenanceHash: artistRecoveredMultipleHydrationOwnerProvenanceHash,
  artistRecoveredHydrationAliasesHash: artistRecoveredMultipleHydrationAliasesHash,
  compareArtistRecoveredHydrationPoints: compareArtistRecoveredMultipleHydrationPoints,
  normalizeArtistRecoveredHydrationNonceInventory: normalizeArtistRecoveredMultipleHydrationNonceInventory,
  normalizeArtistRecoveredHydrationPublications: normalizeArtistRecoveredMultipleHydrationPublications,
  normalizeArtistRecoveredHydrationTimingCheckpoint: normalizeArtistRecoveredMultipleHydrationTimingCheckpoint,
  normalizeArtistRecoveredHydrationExternalGuards: normalizeArtistRecoveredMultipleHydrationExternalGuards,
  ARTIST_RECOVERED_HYDRATION_PREPARE_SELECTOR: ARTIST_RECOVERED_MULTIPLE_HYDRATION_PREPARE_SELECTOR,
  ARTIST_RECOVERED_HYDRATION_PREPARE_ABI: ARTIST_RECOVERED_MULTIPLE_HYDRATION_PREPARE_ABI,
  artistRecoveredHydrationPreparationCalldata: artistRecoveredMultipleHydrationPreparationCalldata,
  normalizeArtistRecoveredHydrationEvidenceDescriptor: normalizeArtistRecoveredMultipleHydrationEvidenceDescriptor,
  artistRecoveredHydrationEvidenceDescriptor: artistRecoveredMultipleHydrationEvidenceDescriptor,
  artistRecoveredHydrationEvidencePages: artistRecoveredMultipleHydrationEvidencePages,
  assembleArtistRecoveredHydrationEvidence: assembleArtistRecoveredMultipleHydrationEvidence,
  artistRecoveredHydrationPageId: artistRecoveredMultipleHydrationPageId,
  artistRecoveredHydrationEvidenceId: artistRecoveredMultipleHydrationEvidenceId,
  encodeArtistRecoveredHydrationEvidenceCarrier: encodeArtistRecoveredMultipleHydrationEvidenceCarrier,
  decodeArtistRecoveredHydrationEvidenceCarrier: decodeArtistRecoveredMultipleHydrationEvidenceCarrier,
  encodeArtistRecoveredHydrationOperationEvidence: encodeArtistRecoveredMultipleHydrationOperationEvidence,
  decodeArtistRecoveredHydrationOperationEvidence: decodeArtistRecoveredMultipleHydrationOperationEvidence,
  artistRecoveredHydrationOwnerReplayDelta: artistRecoveredMultipleHydrationOwnerReplayDelta,
  artistRecoveredHydrationOwnerAfter: artistRecoveredMultipleHydrationOwnerAfter
} = codec;

export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_IDENTITY_TUPLE = `tuple(bytes32 artistId,tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip) sourceSnapshot,uint256 nextRegistrationNonce,tuple(address authorityAddress,uint8 authorityClass,uint8 status,uint64 registeredAt,uint64 lastAuthorityActionAt,bytes32 identityRecordHash,string identityRecordURI,string displayName,uint256 nonceHint) identity,bytes identityDocument,tuple(bytes32 documentHash,bytes document)[] documents,tuple(bytes32 latestTransition,bytes32 latestExecution,bytes32 pendingRotation,bytes32 latestContest,bytes32 currentCause,bytes32 latestDismissal,bytes32 originalRevisionContinuation,bytes32 latestRecovery,bytes32 pendingRecoveryAction,bytes32 latestVesting,bytes32 pendingEstate,bytes32 estateActivation,bytes32 dormancyActivation,bytes32 latestNotice,uint256 livingActivity,uint256 dormancyActivity,uint256 findingActivity,bool hasUncancelledFindings,uint64 delegationEpoch,uint64 guardianRecordsSeen,tuple(uint64 count,uint64 ownerRevision,bytes32 commitment) guardianHistory,tuple(uint64 count,bytes32 historyCommitment) guardianIndex,tuple(tuple(bytes32 stable,bytes32 candidate) guardians,tuple(bytes32 stable,bytes32 candidate) designations,tuple(bytes32 stable,bytes32 candidate) directives,tuple(bytes32 stable,bytes32 candidate) revisions,tuple(bytes32 stable,bytes32 candidate) sanctionGrants,bytes32 revisionContinuationHash,bytes32 supersessionStateCommitment) inventory,bytes32 capabilityContinuation) heads,tuple(tuple(uint64[7] values,uint64[5] revisions) configuration,tuple(uint256 chainId,address owner,uint256 index,tuple(bytes32 parameter,bytes32 actionId,bytes32 actionKey,bytes32 oldHash,bytes32 newHash,uint64 oldValue,uint64 newValue,uint64 floor,uint64 oldRevision,uint64 newRevision) change,bytes32 previousCommitment,bytes32 commitment)[] entries,tuple(bytes32 schema,uint16 version,uint256 count,bytes32 root,bytes32 configurationHash) checkpoint) timing,tuple(bytes32 recordHash,bytes signature)[] signatures,tuple(uint8 kind,bytes32 key,uint256 hint,tuple(uint256 prefix,uint256[32] words,bool exhausted)[] words)[] nonces,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,bytes32 previousRevisionRecord,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,string identityRecordURI,string displayName) record,bytes document,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) association,tuple(bytes32 artistId,uint8 kind,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment) status,bytes32 rewindContinuation)[] revisions,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,bytes32 recordHash,tuple(tuple(bytes32 artistId,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash) grant,address grantor,uint256 nonce,uint256 uses,bool revoked,bytes32 revocationRecordHash) record,bytes32 current,uint64 epoch)[] delegations,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 previousOperativeRecordHash,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional) record,tuple(bytes32 artistId,uint64 index,uint64 ownerRevision,bytes32 recordHash,bytes32 recordDataHash,bytes32 previousCommitment,bytes32 commitment) entry,tuple(bytes32 artistId,bytes32 recoveryRecordHash,bytes32 actionId) status)[] guardians,tuple(address actor,uint64 first,uint64[] indices)[] memberships,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address oldAddress,address newAddress,bytes32 reasonHash,bytes32 expectedPreviousTransitionRecordHash) terms,bytes32 guardianSetRecordHash,uint32 approvalThreshold,uint32 guardianApprovals,uint256 oldNonce,uint256 newNonce,uint64 effectiveWindow,uint64 standingTail,uint64 timingRevision,tuple(bytes32 artistId,bytes32 recordHash,uint64 stagedAt,uint64 contestEndsAt,uint64 executedAt,uint64 postWindowEndsAt,uint64 contestedAt,uint8 phase) transition) record,bool[] approvals)[] rotations,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,bytes32 subjectRecordHash,bytes32 evidenceHash,bytes32 reasonHash) terms,address contester,uint64 contestedAt,uint8 priorStatus,bytes32 guardianSetRecordHash,bytes32 capturedGuardianSetRecordHash,bytes32 pendingTransitionRecordHash,bytes32 executedTransitionRecordHash,bytes32 governanceWitnessHash) record)[] contests,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 causeHash,tuple(bytes32 artistId,uint8 kind,bytes32 referenceHash,address actor,bytes32 reasonHash,bytes32 evidenceHash,uint64 enteredAt,address incumbent,uint8 authorityClass,uint8 priorStatus,bytes32 pendingTransitionHash,bytes32 executedTransitionHash,bytes32 previousCauseHash,bytes32 previousResolutionHash,bytes32 actorRetirementHash) facts) cause,bytes32 notice)[] causes,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,bytes32 expectedCauseHash,bytes32 expectedResolutionHash,bytes32 evidenceHash,bytes32 reasonHash,bool removePriorStanding,bytes32 expectedRetirementHash) terms,address executor,address proposer,uint8 actionClass,bytes32 actionId,address incumbent,uint8 authorityClass,uint8 restoredStatus,uint64 dismissedAt,bytes32 cohortHash,bytes32 governanceWitnessHash,bytes32 revisionContinuationHead) record)[] dismissals,tuple(bytes32 transition,tuple(bytes32 artistId,bytes32 transitionRecordHash,bytes32 dismissalRecordHash,uint64 windowEndsAt,uint64 contestedAt,bool abandoned) closure)[] closures,tuple(address account,bytes32 retirement,bytes32 revocation,tuple(bytes32 retirementHash,bytes32 dismissalRecordHash) judgment)[] standing,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address revokedAddress,bytes32 reasonHash,bytes32 retiredTransitionRecordHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt) record,tuple(bytes32 artistId,uint8 kind,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment) status,bytes32 rewindContinuation)[] standingRecords,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address oldAddress,address newAddress,uint8 vestedAuthorityClass,bytes32 evidenceHash,bytes32 reasonHash,bytes32 supersededRecordsHash,bytes32 governanceActionId,uint64 recoveredAt) fields,tuple(bytes32 artistId,address newAddress,uint8 vestedAuthorityClass,bytes32 expectedCauseHash,bytes32 expectedResolutionHash,bytes32 evidenceHash,bytes32 reasonHash,bytes32[] supersededRecordHashes) terms,address executor,address proposer,bytes32 governanceWitnessHash,bytes32 contextHash,bytes32 acceptanceDigest,uint256 acceptanceNonce,uint64 acceptanceDeadline,uint64 postContestSeconds,uint64 standingTailSeconds,uint64 timingRevision,uint64 delegationEpoch,tuple(bytes32 artistId,bytes32 recordHash,uint64 stagedAt,uint64 contestEndsAt,uint64 executedAt,uint64 postWindowEndsAt,uint64 contestedAt,uint8 phase) abandonedTransition) record,tuple(bytes32 artistId,bytes32 recordHash,uint64 stagedAt,uint64 contestEndsAt,uint64 executedAt,uint64 postWindowEndsAt,uint64 contestedAt,uint8 phase) transition,bytes32 guardian,bytes32 primaryReceipt,bytes32 secondaryOccurrence,bytes32 secondaryReceipt)[] recoveries,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 artistId,bytes32 transitionRecordHash,uint16 operationId,uint64 ownerRevision,uint64 executedAt,address oldAddress,address newAddress,uint8 authorityClass,tuple(uint64 count,uint64 ownerRevision,bytes32 commitment) guardians,bytes32 previousTransitionRecordHash,bytes32 previousCommitment,bytes32 commitment) snapshot)[] vestings,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 associationHash,bytes32 artistId,bytes32 requestHash,bytes32 acceptanceHash,bytes32 contextHash,tuple(bytes32 actionId,bytes32 callsHash,uint256 callIndex,bytes32 callDataHash,address executor,bytes32 executorCodeHash,address proposer,bytes32 roleMutationHash,uint64 roleRevision,uint64 notBefore,uint64 expiresAfter,uint64 minimumDelay,bytes32 manifestHash) action,tuple(bytes32 recordHash,tuple(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 previousOperativeRecordHash,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional) guardian,address preparedBy,uint64 preparedAt,uint64 ownerRevision) association,tuple(address vetoer,bytes32 reasonHash,uint64 vetoedAt) veto,bytes32 execution,tuple(bytes32 artistId,uint64 count,bytes32 historyCommitment,bytes32 associationHash) guardianSnapshot,tuple(bytes32 artistId,bytes32 associationHash,bytes32 contextCommitment,uint64 count,bytes32 historyCommitment,bytes32[] excluded) plan,tuple(bytes32 sourceKey,bytes32 selectedRecordHash,bytes32 selectedDataHash,uint256 selectedNonce,bytes32 commitment) election,tuple(bytes32 recordHash,tuple(bytes32 artistId,address[] guardians,uint32 approvalThreshold,uint64 minContestSeconds) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,bytes32 previousOperativeRecordHash,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional) restoredGuardian,uint64[] excludedMemberships,tuple(bytes32 manifestHash,bytes32 basisCommitment,bytes32 selectionCommitment,bytes32 requiredRole,uint64 preparedFromOwnerRevision,bytes32 associationHash) evidenceV2,tuple(bytes32 manifestHash,bytes32 sourceKey,bytes32 sourceCommitment,bytes32 selectionCommitment,bytes32 policyCommitment,bytes32 requiredRole,uint32 effectiveCapabilities,bytes32 associationHash,tuple(tuple(tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip) snapshot,uint256 receiptCount) identityBefore,tuple(tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip) snapshot,uint256 receiptCount) payout,bytes32 associationHash) sources) evidenceV3,bytes32 manifestActionV2,bytes32 manifestActionV3)[] actions,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address successor,uint8 successorKind,uint32 grantedCapabilities,bytes32 conditionsHash,bytes32 directiveHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional) record,tuple(bytes32 artistId,uint8 kind,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment) status)[] designations,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,uint32 grantedCapabilities,uint32 forbiddenCapabilities,bytes32 directivePayloadHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional) record,bytes payload,tuple(bytes32 artistId,uint8 kind,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment) status)[] directives,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,bool granted,bytes32 statementHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) provisional) record,tuple(bytes32 artistId,uint8 kind,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment) status)[] sanctionGrants,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address successor,bytes32 evidenceHash,bytes32 expectedDesignationRecordHash,bytes32 selectedCoverageHash) terms,tuple(uint256 nonce,uint64 time,bytes signature) authorization,address incumbent,bytes32 designationRecordHash,bytes32 pairedDirectiveRecordHash,bytes32 forbiddenDirectiveRecordHash,bytes32 guardianRecordHash,bytes32 envelopeHash,uint64 requestedAt,uint64 noticeEndsAt,uint64 noticeSeconds,uint64 noticeRevision,uint64 postContestSeconds,uint64 standingTailSeconds,uint64 rotationTimingRevision,uint256 livingActivity) request,uint8 phase,tuple(bytes32 activationRecordHash,bytes32 coverageRecordHash,uint32 effectiveCapabilities,uint64 executedAt,bytes32 governanceActionId,bytes32 governanceWitnessHash,uint64 delegationEpoch) execution,tuple(bytes32 artistId,bytes32 recordHash,uint64 stagedAt,uint64 contestEndsAt,uint64 executedAt,uint64 postWindowEndsAt,uint64 contestedAt,uint8 phase) transition)[] estates,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,bytes32 evidenceHash,string reasonURI) terms,address incumbent,uint64 initiatedAt,uint64 noticeEndsAt,uint64 inactivitySeconds,uint64 noticeSeconds,uint64 timingRevision,uint64 priorLivenessAt,uint256 priorActivity,bytes32 actionId,bytes32 witnessHash) notice,uint8 phase,tuple(bytes32 recordHash,bytes32 noticeHash,address actor,uint8 authorityClass,uint64 observedAt,uint64 appointmentBlock,tuple(address authority,uint8 authorityClass,uint32 capabilities,bytes32 designation,bytes32 directive,bytes32 guardian,bytes32 stewardGrantRecordHash,uint64 postSeconds,uint64 standingTail) plan,bytes32 evidenceHash,bytes32 actionId,bytes32 witnessHash,uint64 delegationEpoch) terminal,tuple(bytes32 artistId,bytes32 recordHash,uint64 stagedAt,uint64 contestEndsAt,uint64 executedAt,uint64 postWindowEndsAt,uint64 contestedAt,uint8 phase) transition)[] notices,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,uint256 collectionId,bytes32 evidenceHash,bytes32 reasonHash) terms,bytes32 governanceActionId,uint64 noticeEndsAt,uint64 recordedAt,uint64 noticeSeconds,uint64 timingRevision,uint64 bindingGeneration,bytes32 bindingHash) record,tuple(tuple(address recoveryRegistry,bytes32 recoveryActionId,tuple(uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId) scope,bytes32 originalFinalityRecordHash,bytes32 recoveryManifestHash) target,bytes32 recoveryRegistryCodeHash,bytes32 recoveryIntentFactsHash,uint256 activityEpoch,bytes32 governanceWitnessHash) admission,tuple(tuple(address coordinator,tuple(bytes32 oldRequestKey,string reasonURI,bytes32 providerEvidenceHash) recovery,bytes32 intentHash,bytes32 unavailableEvidenceHash) target,tuple(uint256 collectionId,uint256 tokenId,bytes32 scopeId,bytes32 oldRequestKey,bytes32 newRequestKey,bytes32 priorJournalHead,bytes32 journalHead,bytes32 currentContentStateHash,bytes32 contentStateHash,bytes32 requestPolicyHash,bytes32 incidentEvidenceHash,bytes32 providerEvidenceHash,bytes32 reasonHash) intent,bytes32 coordinatorCodeHash,uint256 activityEpoch,bytes32 governanceWitnessHash) entropyAdmission,address entropyOrigin,bytes32 latestForCollection)[] findings,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 continuationHash,bytes32 artistId,bytes32 dismissalRecordHash,bytes32 previousContinuationHash,bytes32 stableRevisionRecordHash,bytes32 stableDocumentHash,bytes32 abandonedRevisionRecordHash) continuation)[] originalContinuations,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 artistId,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment,bytes32 stableRevisionRecordHash,bytes32 stableDocumentHash,bytes32 resolvedChildRecordHash,uint64 ownerRevision,bytes32 continuationHash) continuation)[] revisionContinuations,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 artistId,address priorAddress,bytes32 retirementHash,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment,bytes32 retainedRevocationRecordHash,bytes32 supersededRevocationRecordHash,uint64 ownerRevision,bytes32 continuationHash) continuation,bytes32 scopeHead)[] standingContinuations,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 artistId,bytes32 originalActivationRecordHash,uint32 originalActivationCapabilities,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 manifestHash,bytes32 planCommitment,bytes32 designationRecordHash,bytes32 pairedDirectiveRecordHash,bytes32 forbiddenDirectiveRecordHash,address authorityAddress,uint32 effectiveCapabilities,bytes32 commitment) continuation)[] capabilityContinuations)`;
export type ArtistRecoveredMultipleHydrationIdentity = { readonly artistId: Hex; readonly sourceSnapshot: { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }; readonly nextRegistrationNonce: bigint; readonly identity: { readonly authorityAddress: Address; readonly authorityClass: bigint; readonly status: bigint; readonly registeredAt: bigint; readonly lastAuthorityActionAt: bigint; readonly identityRecordHash: Hex; readonly identityRecordURI: string; readonly displayName: string; readonly nonceHint: bigint; }; readonly identityDocument: Hex; readonly documents: readonly ({ readonly documentHash: Hex; readonly document: Hex; })[]; readonly heads: { readonly latestTransition: Hex; readonly latestExecution: Hex; readonly pendingRotation: Hex; readonly latestContest: Hex; readonly currentCause: Hex; readonly latestDismissal: Hex; readonly originalRevisionContinuation: Hex; readonly latestRecovery: Hex; readonly pendingRecoveryAction: Hex; readonly latestVesting: Hex; readonly pendingEstate: Hex; readonly estateActivation: Hex; readonly dormancyActivation: Hex; readonly latestNotice: Hex; readonly livingActivity: bigint; readonly dormancyActivity: bigint; readonly findingActivity: bigint; readonly hasUncancelledFindings: boolean; readonly delegationEpoch: bigint; readonly guardianRecordsSeen: bigint; readonly guardianHistory: { readonly count: bigint; readonly ownerRevision: bigint; readonly commitment: Hex; }; readonly guardianIndex: { readonly count: bigint; readonly historyCommitment: Hex; }; readonly inventory: { readonly guardians: { readonly stable: Hex; readonly candidate: Hex; }; readonly designations: { readonly stable: Hex; readonly candidate: Hex; }; readonly directives: { readonly stable: Hex; readonly candidate: Hex; }; readonly revisions: { readonly stable: Hex; readonly candidate: Hex; }; readonly sanctionGrants: { readonly stable: Hex; readonly candidate: Hex; }; readonly revisionContinuationHash: Hex; readonly supersessionStateCommitment: Hex; }; readonly capabilityContinuation: Hex; }; readonly timing: { readonly configuration: { readonly values: readonly (bigint)[]; readonly revisions: readonly (bigint)[]; }; readonly entries: readonly ({ readonly chainId: bigint; readonly owner: Address; readonly index: bigint; readonly change: { readonly parameter: Hex; readonly actionId: Hex; readonly actionKey: Hex; readonly oldHash: Hex; readonly newHash: Hex; readonly oldValue: bigint; readonly newValue: bigint; readonly floor: bigint; readonly oldRevision: bigint; readonly newRevision: bigint; }; readonly previousCommitment: Hex; readonly commitment: Hex; })[]; readonly checkpoint: { readonly schema: Hex; readonly version: bigint; readonly count: bigint; readonly root: Hex; readonly configurationHash: Hex; }; }; readonly signatures: readonly ({ readonly recordHash: Hex; readonly signature: Hex; })[]; readonly nonces: readonly ({ readonly kind: bigint; readonly key: Hex; readonly hint: bigint; readonly words: readonly ({ readonly prefix: bigint; readonly words: readonly (bigint)[]; readonly exhausted: boolean; })[]; })[]; readonly revisions: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly artistId: Hex; readonly previousRecordHash: Hex; readonly revisedRecordHash: Hex; readonly previousRevisionRecord: Hex; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly identityRecordURI: string; readonly displayName: string; }; readonly document: Hex; readonly association: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; readonly status: { readonly artistId: Hex; readonly kind: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; }; readonly rewindContinuation: Hex; })[]; readonly delegations: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly recordHash: Hex; readonly record: { readonly grant: { readonly artistId: Hex; readonly delegate: Address; readonly collectionId: bigint; readonly capabilities: bigint; readonly notBefore: bigint; readonly expiresAt: bigint; readonly maxUses: bigint; readonly constraintsHash: Hex; }; readonly grantor: Address; readonly nonce: bigint; readonly uses: bigint; readonly revoked: boolean; readonly revocationRecordHash: Hex; }; readonly current: Hex; readonly epoch: bigint; })[]; readonly guardians: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly guardians: readonly (Address)[]; readonly approvalThreshold: bigint; readonly minContestSeconds: bigint; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly previousOperativeRecordHash: Hex; readonly provisional: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; }; readonly entry: { readonly artistId: Hex; readonly index: bigint; readonly ownerRevision: bigint; readonly recordHash: Hex; readonly recordDataHash: Hex; readonly previousCommitment: Hex; readonly commitment: Hex; }; readonly status: { readonly artistId: Hex; readonly recoveryRecordHash: Hex; readonly actionId: Hex; }; })[]; readonly memberships: readonly ({ readonly actor: Address; readonly first: bigint; readonly indices: readonly (bigint)[]; })[]; readonly rotations: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly oldAddress: Address; readonly newAddress: Address; readonly reasonHash: Hex; readonly expectedPreviousTransitionRecordHash: Hex; }; readonly guardianSetRecordHash: Hex; readonly approvalThreshold: bigint; readonly guardianApprovals: bigint; readonly oldNonce: bigint; readonly newNonce: bigint; readonly effectiveWindow: bigint; readonly standingTail: bigint; readonly timingRevision: bigint; readonly transition: { readonly artistId: Hex; readonly recordHash: Hex; readonly stagedAt: bigint; readonly contestEndsAt: bigint; readonly executedAt: bigint; readonly postWindowEndsAt: bigint; readonly contestedAt: bigint; readonly phase: bigint; }; }; readonly approvals: readonly (boolean)[]; })[]; readonly contests: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly subjectRecordHash: Hex; readonly evidenceHash: Hex; readonly reasonHash: Hex; }; readonly contester: Address; readonly contestedAt: bigint; readonly priorStatus: bigint; readonly guardianSetRecordHash: Hex; readonly capturedGuardianSetRecordHash: Hex; readonly pendingTransitionRecordHash: Hex; readonly executedTransitionRecordHash: Hex; readonly governanceWitnessHash: Hex; }; })[]; readonly causes: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly cause: { readonly causeHash: Hex; readonly facts: { readonly artistId: Hex; readonly kind: bigint; readonly referenceHash: Hex; readonly actor: Address; readonly reasonHash: Hex; readonly evidenceHash: Hex; readonly enteredAt: bigint; readonly incumbent: Address; readonly authorityClass: bigint; readonly priorStatus: bigint; readonly pendingTransitionHash: Hex; readonly executedTransitionHash: Hex; readonly previousCauseHash: Hex; readonly previousResolutionHash: Hex; readonly actorRetirementHash: Hex; }; }; readonly notice: Hex; })[]; readonly dismissals: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly expectedCauseHash: Hex; readonly expectedResolutionHash: Hex; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly removePriorStanding: boolean; readonly expectedRetirementHash: Hex; }; readonly executor: Address; readonly proposer: Address; readonly actionClass: bigint; readonly actionId: Hex; readonly incumbent: Address; readonly authorityClass: bigint; readonly restoredStatus: bigint; readonly dismissedAt: bigint; readonly cohortHash: Hex; readonly governanceWitnessHash: Hex; readonly revisionContinuationHead: Hex; }; })[]; readonly closures: readonly ({ readonly transition: Hex; readonly closure: { readonly artistId: Hex; readonly transitionRecordHash: Hex; readonly dismissalRecordHash: Hex; readonly windowEndsAt: bigint; readonly contestedAt: bigint; readonly abandoned: boolean; }; })[]; readonly standing: readonly ({ readonly account: Address; readonly retirement: Hex; readonly revocation: Hex; readonly judgment: { readonly retirementHash: Hex; readonly dismissalRecordHash: Hex; }; })[]; readonly standingRecords: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly revokedAddress: Address; readonly reasonHash: Hex; readonly retiredTransitionRecordHash: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; }; readonly status: { readonly artistId: Hex; readonly kind: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; }; readonly rewindContinuation: Hex; })[]; readonly recoveries: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly fields: { readonly artistId: Hex; readonly oldAddress: Address; readonly newAddress: Address; readonly vestedAuthorityClass: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly supersededRecordsHash: Hex; readonly governanceActionId: Hex; readonly recoveredAt: bigint; }; readonly terms: { readonly artistId: Hex; readonly newAddress: Address; readonly vestedAuthorityClass: bigint; readonly expectedCauseHash: Hex; readonly expectedResolutionHash: Hex; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly supersededRecordHashes: readonly (Hex)[]; }; readonly executor: Address; readonly proposer: Address; readonly governanceWitnessHash: Hex; readonly contextHash: Hex; readonly acceptanceDigest: Hex; readonly acceptanceNonce: bigint; readonly acceptanceDeadline: bigint; readonly postContestSeconds: bigint; readonly standingTailSeconds: bigint; readonly timingRevision: bigint; readonly delegationEpoch: bigint; readonly abandonedTransition: { readonly artistId: Hex; readonly recordHash: Hex; readonly stagedAt: bigint; readonly contestEndsAt: bigint; readonly executedAt: bigint; readonly postWindowEndsAt: bigint; readonly contestedAt: bigint; readonly phase: bigint; }; }; readonly transition: { readonly artistId: Hex; readonly recordHash: Hex; readonly stagedAt: bigint; readonly contestEndsAt: bigint; readonly executedAt: bigint; readonly postWindowEndsAt: bigint; readonly contestedAt: bigint; readonly phase: bigint; }; readonly guardian: Hex; readonly primaryReceipt: Hex; readonly secondaryOccurrence: Hex; readonly secondaryReceipt: Hex; })[]; readonly vestings: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly snapshot: { readonly artistId: Hex; readonly transitionRecordHash: Hex; readonly operationId: bigint; readonly ownerRevision: bigint; readonly executedAt: bigint; readonly oldAddress: Address; readonly newAddress: Address; readonly authorityClass: bigint; readonly guardians: { readonly count: bigint; readonly ownerRevision: bigint; readonly commitment: Hex; }; readonly previousTransitionRecordHash: Hex; readonly previousCommitment: Hex; readonly commitment: Hex; }; })[]; readonly actions: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly association: { readonly associationHash: Hex; readonly artistId: Hex; readonly requestHash: Hex; readonly acceptanceHash: Hex; readonly contextHash: Hex; readonly action: { readonly actionId: Hex; readonly callsHash: Hex; readonly callIndex: bigint; readonly callDataHash: Hex; readonly executor: Address; readonly executorCodeHash: Hex; readonly proposer: Address; readonly roleMutationHash: Hex; readonly roleRevision: bigint; readonly notBefore: bigint; readonly expiresAfter: bigint; readonly minimumDelay: bigint; readonly manifestHash: Hex; }; readonly guardian: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly guardians: readonly (Address)[]; readonly approvalThreshold: bigint; readonly minContestSeconds: bigint; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly previousOperativeRecordHash: Hex; readonly provisional: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; }; readonly preparedBy: Address; readonly preparedAt: bigint; readonly ownerRevision: bigint; }; readonly veto: { readonly vetoer: Address; readonly reasonHash: Hex; readonly vetoedAt: bigint; }; readonly execution: Hex; readonly guardianSnapshot: { readonly artistId: Hex; readonly count: bigint; readonly historyCommitment: Hex; readonly associationHash: Hex; }; readonly plan: { readonly artistId: Hex; readonly associationHash: Hex; readonly contextCommitment: Hex; readonly count: bigint; readonly historyCommitment: Hex; readonly excluded: readonly (Hex)[]; }; readonly election: { readonly sourceKey: Hex; readonly selectedRecordHash: Hex; readonly selectedDataHash: Hex; readonly selectedNonce: bigint; readonly commitment: Hex; }; readonly restoredGuardian: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly guardians: readonly (Address)[]; readonly approvalThreshold: bigint; readonly minContestSeconds: bigint; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly previousOperativeRecordHash: Hex; readonly provisional: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; }; readonly excludedMemberships: readonly (bigint)[]; readonly evidenceV2: { readonly manifestHash: Hex; readonly basisCommitment: Hex; readonly selectionCommitment: Hex; readonly requiredRole: Hex; readonly preparedFromOwnerRevision: bigint; readonly associationHash: Hex; }; readonly evidenceV3: { readonly manifestHash: Hex; readonly sourceKey: Hex; readonly sourceCommitment: Hex; readonly selectionCommitment: Hex; readonly policyCommitment: Hex; readonly requiredRole: Hex; readonly effectiveCapabilities: bigint; readonly associationHash: Hex; readonly sources: { readonly identityBefore: { readonly snapshot: { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }; readonly receiptCount: bigint; }; readonly payout: { readonly snapshot: { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }; readonly receiptCount: bigint; }; readonly associationHash: Hex; }; }; readonly manifestActionV2: Hex; readonly manifestActionV3: Hex; })[]; readonly designations: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly successor: Address; readonly successorKind: bigint; readonly grantedCapabilities: bigint; readonly conditionsHash: Hex; readonly directiveHash: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly provisional: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; }; readonly status: { readonly artistId: Hex; readonly kind: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; }; })[]; readonly directives: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly grantedCapabilities: bigint; readonly forbiddenCapabilities: bigint; readonly directivePayloadHash: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly provisional: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; }; readonly payload: Hex; readonly status: { readonly artistId: Hex; readonly kind: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; }; })[]; readonly sanctionGrants: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly granted: boolean; readonly statementHash: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; readonly provisional: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; }; readonly status: { readonly artistId: Hex; readonly kind: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; }; })[]; readonly estates: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly request: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly successor: Address; readonly evidenceHash: Hex; readonly expectedDesignationRecordHash: Hex; readonly selectedCoverageHash: Hex; }; readonly authorization: { readonly nonce: bigint; readonly time: bigint; readonly signature: Hex; }; readonly incumbent: Address; readonly designationRecordHash: Hex; readonly pairedDirectiveRecordHash: Hex; readonly forbiddenDirectiveRecordHash: Hex; readonly guardianRecordHash: Hex; readonly envelopeHash: Hex; readonly requestedAt: bigint; readonly noticeEndsAt: bigint; readonly noticeSeconds: bigint; readonly noticeRevision: bigint; readonly postContestSeconds: bigint; readonly standingTailSeconds: bigint; readonly rotationTimingRevision: bigint; readonly livingActivity: bigint; }; readonly phase: bigint; readonly execution: { readonly activationRecordHash: Hex; readonly coverageRecordHash: Hex; readonly effectiveCapabilities: bigint; readonly executedAt: bigint; readonly governanceActionId: Hex; readonly governanceWitnessHash: Hex; readonly delegationEpoch: bigint; }; readonly transition: { readonly artistId: Hex; readonly recordHash: Hex; readonly stagedAt: bigint; readonly contestEndsAt: bigint; readonly executedAt: bigint; readonly postWindowEndsAt: bigint; readonly contestedAt: bigint; readonly phase: bigint; }; })[]; readonly notices: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly notice: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly evidenceHash: Hex; readonly reasonURI: string; }; readonly incumbent: Address; readonly initiatedAt: bigint; readonly noticeEndsAt: bigint; readonly inactivitySeconds: bigint; readonly noticeSeconds: bigint; readonly timingRevision: bigint; readonly priorLivenessAt: bigint; readonly priorActivity: bigint; readonly actionId: Hex; readonly witnessHash: Hex; }; readonly phase: bigint; readonly terminal: { readonly recordHash: Hex; readonly noticeHash: Hex; readonly actor: Address; readonly authorityClass: bigint; readonly observedAt: bigint; readonly appointmentBlock: bigint; readonly plan: { readonly authority: Address; readonly authorityClass: bigint; readonly capabilities: bigint; readonly designation: Hex; readonly directive: Hex; readonly guardian: Hex; readonly stewardGrantRecordHash: Hex; readonly postSeconds: bigint; readonly standingTail: bigint; }; readonly evidenceHash: Hex; readonly actionId: Hex; readonly witnessHash: Hex; readonly delegationEpoch: bigint; }; readonly transition: { readonly artistId: Hex; readonly recordHash: Hex; readonly stagedAt: bigint; readonly contestEndsAt: bigint; readonly executedAt: bigint; readonly postWindowEndsAt: bigint; readonly contestedAt: bigint; readonly phase: bigint; }; })[]; readonly findings: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly record: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly collectionId: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex; }; readonly governanceActionId: Hex; readonly noticeEndsAt: bigint; readonly recordedAt: bigint; readonly noticeSeconds: bigint; readonly timingRevision: bigint; readonly bindingGeneration: bigint; readonly bindingHash: Hex; }; readonly admission: { readonly target: { readonly recoveryRegistry: Address; readonly recoveryActionId: Hex; readonly scope: { readonly scopeType: bigint; readonly collectionId: bigint; readonly tokenId: bigint; readonly scopeId: Hex; }; readonly originalFinalityRecordHash: Hex; readonly recoveryManifestHash: Hex; }; readonly recoveryRegistryCodeHash: Hex; readonly recoveryIntentFactsHash: Hex; readonly activityEpoch: bigint; readonly governanceWitnessHash: Hex; }; readonly entropyAdmission: { readonly target: { readonly coordinator: Address; readonly recovery: { readonly oldRequestKey: Hex; readonly reasonURI: string; readonly providerEvidenceHash: Hex; }; readonly intentHash: Hex; readonly unavailableEvidenceHash: Hex; }; readonly intent: { readonly collectionId: bigint; readonly tokenId: bigint; readonly scopeId: Hex; readonly oldRequestKey: Hex; readonly newRequestKey: Hex; readonly priorJournalHead: Hex; readonly journalHead: Hex; readonly currentContentStateHash: Hex; readonly contentStateHash: Hex; readonly requestPolicyHash: Hex; readonly incidentEvidenceHash: Hex; readonly providerEvidenceHash: Hex; readonly reasonHash: Hex; }; readonly coordinatorCodeHash: Hex; readonly activityEpoch: bigint; readonly governanceWitnessHash: Hex; }; readonly entropyOrigin: Address; readonly latestForCollection: Hex; })[]; readonly originalContinuations: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly continuation: { readonly continuationHash: Hex; readonly artistId: Hex; readonly dismissalRecordHash: Hex; readonly previousContinuationHash: Hex; readonly stableRevisionRecordHash: Hex; readonly stableDocumentHash: Hex; readonly abandonedRevisionRecordHash: Hex; }; })[]; readonly revisionContinuations: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly continuation: { readonly artistId: Hex; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; readonly stableRevisionRecordHash: Hex; readonly stableDocumentHash: Hex; readonly resolvedChildRecordHash: Hex; readonly ownerRevision: bigint; readonly continuationHash: Hex; }; })[]; readonly standingContinuations: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly continuation: { readonly artistId: Hex; readonly priorAddress: Address; readonly retirementHash: Hex; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; readonly retainedRevocationRecordHash: Hex; readonly supersededRevocationRecordHash: Hex; readonly ownerRevision: bigint; readonly continuationHash: Hex; }; readonly scopeHead: Hex; })[]; readonly capabilityContinuations: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly continuation: { readonly artistId: Hex; readonly originalActivationRecordHash: Hex; readonly originalActivationCapabilities: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly manifestHash: Hex; readonly planCommitment: Hex; readonly designationRecordHash: Hex; readonly pairedDirectiveRecordHash: Hex; readonly forbiddenDirectiveRecordHash: Hex; readonly authorityAddress: Address; readonly effectiveCapabilities: bigint; readonly commitment: Hex; }; })[]; };

export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_PAYOUT_TUPLE = `tuple(bytes32 artistId,tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip) sourceSnapshot,tuple(tuple(address account,bytes32 recordHash) stable,tuple(address account,bytes32 recordHash) candidate,bytes32 supersessionStateCommitment,bytes32 continuationCommitment) inventory,tuple(tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,uint256 nativeIndex) position,tuple(bytes32 recordHash,tuple(bytes32 artistId,address payoutAccount,bytes32 previousDesignationRecordHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 signedAt) original,bytes32 evidenceHash,tuple(bytes32 transitionRecordHash,uint64 windowEndsAt) association,bytes32 abandonedUnder,tuple(bytes32 artistId,uint8 kind,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 planCommitment) status,bytes32 continuationHash)[] records,tuple(tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision) point,tuple(bytes32 artistId,bytes32 recoveryRecordHash,bytes32 actionId,bytes32 manifestHash,bytes32 planCommitment,uint64 identityOwnerRevision,tuple(address account,bytes32 recordHash) stable,tuple(address account,bytes32 recordHash) candidate,bytes32 releasedChildRecordHash,bytes32 previousContinuationHash,uint64 payoutOwnerRevision,bytes32 continuationHash) continuation,bytes32 appliedCommitment)[] continuations)`;
export type ArtistRecoveredMultipleHydrationPayout = { readonly artistId: Hex; readonly sourceSnapshot: { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }; readonly inventory: { readonly stable: { readonly account: Address; readonly recordHash: Hex; }; readonly candidate: { readonly account: Address; readonly recordHash: Hex; }; readonly supersessionStateCommitment: Hex; readonly continuationCommitment: Hex; }; readonly records: readonly ({ readonly position: { readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly nativeIndex: bigint; }; readonly original: { readonly recordHash: Hex; readonly terms: { readonly artistId: Hex; readonly payoutAccount: Address; readonly previousDesignationRecordHash: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly signedAt: bigint; }; readonly evidenceHash: Hex; readonly association: { readonly transitionRecordHash: Hex; readonly windowEndsAt: bigint; }; readonly abandonedUnder: Hex; readonly status: { readonly artistId: Hex; readonly kind: bigint; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly planCommitment: Hex; }; readonly continuationHash: Hex; })[]; readonly continuations: readonly ({ readonly point: { readonly environmentHash: Hex; readonly ownerIndex: bigint; readonly ownerRevision: bigint; }; readonly continuation: { readonly artistId: Hex; readonly recoveryRecordHash: Hex; readonly actionId: Hex; readonly manifestHash: Hex; readonly planCommitment: Hex; readonly identityOwnerRevision: bigint; readonly stable: { readonly account: Address; readonly recordHash: Hex; }; readonly candidate: { readonly account: Address; readonly recordHash: Hex; }; readonly releasedChildRecordHash: Hex; readonly previousContinuationHash: Hex; readonly payoutOwnerRevision: bigint; readonly continuationHash: Hex; }; readonly appliedCommitment: Hex; })[]; };

export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_BINDING_TUPLE = `tuple(tuple(bytes32 artistId,uint256 collectionId,bytes32 bindingHash) scope,bytes32 provenanceCommitment,tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) item,tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) history,tuple(bytes32 collaboratorSetHash,bytes32 capabilityPolicySetHash,uint8 mode,uint32 threshold,uint32 count) terms,tuple(uint8 kind,bytes32 reasonHash,bytes32 recordHash) terminal)`;
export type ArtistRecoveredMultipleHydrationBinding = { readonly scope: { readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex; }; readonly provenanceCommitment: Hex; readonly item: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly history: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly terms: { readonly collaboratorSetHash: Hex; readonly capabilityPolicySetHash: Hex; readonly mode: bigint; readonly threshold: bigint; readonly count: bigint; }; readonly terminal: { readonly kind: bigint; readonly reasonHash: Hex; readonly recordHash: Hex; }; };

export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_ACCEPTANCE_TUPLE = `tuple(tuple(bytes32 artistId,uint256 collectionId,bytes32 bindingHash) scope,bytes32 provenanceCommitment,bytes32 record,uint64 acceptedAt)`;
export type ArtistRecoveredMultipleHydrationAcceptance = { readonly scope: { readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex; }; readonly provenanceCommitment: Hex; readonly record: Hex; readonly acceptedAt: bigint; };

export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_ATTRIBUTION_STATE_TUPLE = `tuple(bytes32 provenance,bytes32 artistId,uint256 collectionId,bytes32 bindingHash,tuple(uint8 state,uint64 generation) item)`;
export type ArtistRecoveredMultipleHydrationAttributionState = { readonly provenance: Hex; readonly artistId: Hex; readonly collectionId: bigint; readonly bindingHash: Hex; readonly item: { readonly state: bigint; readonly generation: bigint; }; };

export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_POLICY_TUPLE = `tuple(bytes32 provenance,bytes32 artistId,uint256 collectionId,tuple(bytes32 phaseId,bytes32 policyHash)[] policies,bytes32[] records)`;
export type ArtistRecoveredMultipleHydrationPolicy = { readonly provenance: Hex; readonly artistId: Hex; readonly collectionId: bigint; readonly policies: readonly ({ readonly phaseId: Hex; readonly policyHash: Hex; })[]; readonly records: readonly (Hex)[]; };

export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_ATTRIBUTION_TUPLE = `tuple(${ARTIST_RECOVERED_MULTIPLE_HYDRATION_ATTRIBUTION_STATE_TUPLE} state,bytes32 proposalOrigin)`;
export interface ArtistRecoveredMultipleHydrationAttribution { readonly state: ArtistRecoveredMultipleHydrationAttributionState; readonly proposalOrigin: Hex; }
export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_STATE_TUPLE = `tuple(${ARTIST_HYDRATION_QUERY_TUPLE}[] artists,${ARTIST_HYDRATION_QUERY_TUPLE}[] collections,bytes[] rows)`;
export interface ArtistRecoveredMultipleHydrationState { readonly artists: readonly ArtistHydrationQuery[]; readonly collections: readonly ArtistHydrationQuery[]; readonly rows: readonly Hex[]; }

const coder = AbiCoder.defaultAbiCoder();
const Z = ZeroHash as Hex;
const hash = (types: readonly string[], values: readonly unknown[]): Hex => keccak256(coder.encode(types, values)) as Hex;
const same = (type: string, a: unknown, b: unknown): boolean => hash([type], [a]) === hash([type], [b]);
const stateType = ParamType.from(ARTIST_RECOVERED_MULTIPLE_HYDRATION_STATE_TUPLE);
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
  visit(ParamType.from(`tuple(${types.join(",")})`), 0, 0);
  return input;
}

function plain(t: ParamType, value: any): unknown {
  if (t.baseType === "array") return Array.from(value, v => plain(t.arrayChildren!, v));
  if (t.baseType === "tuple") return Object.fromEntries(t.components!.map((c, i) => [c.name, plain(c, value[i])]));
  return value;
}

function decode<T>(type: string, raw: Hex): T {
  const bytes = preflight([type], raw);
  const result = coder.decode([type], bytes);
  if (coder.encode([type], result) !== bytes) throw Error("Noncanonical multiple row");
  return codec.normalizeTuple(type, plain(ParamType.from(type), result[0]) as T);
}

/** Structural tuple only. validateState adds the original complete membership predicates. */
export function normalizeArtistRecoveredMultipleHydrationState(value: ArtistRecoveredMultipleHydrationState): ArtistRecoveredMultipleHydrationState {
  return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_HYDRATION_STATE_TUPLE, value);
}

export function validateArtistRecoveredMultipleHydrationState(
  index: ArtistHydrationOwnerIndex,
  value: ArtistRecoveredMultipleHydrationState,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistRecoveredMultipleHydrationState {
  const s = normalizeArtistRecoveredMultipleHydrationState(value);
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

export function artistRecoveredMultipleHydrationAnchor(value: ArtistRecoveredMultipleHydrationState): ArtistHydrationQuery {
  const s = normalizeArtistRecoveredMultipleHydrationState(value);
  const first = s.collections[0], artist = first && s.artists.find(a => a.artistId === first.artistId);
  if (!first || !artist) throw Error("Missing multiple anchor");
  return Object.freeze({ ...first, records: artist.records });
}

export function encodeArtistRecoveredMultipleHydrationState(
  value: ArtistRecoveredMultipleHydrationState, index: ArtistHydrationOwnerIndex,
  provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): Hex {
  const s = validateArtistRecoveredMultipleHydrationState(index, value, provenance);
  return codec.encodeTupleValues(["bytes32", "uint16", "uint8", ARTIST_RECOVERED_MULTIPLE_HYDRATION_STATE_TUPLE],
    [ARTIST_RECOVERED_MULTIPLE_HYDRATION_SCHEMA, 1n, BigInt(index), s]);
}

export function decodeArtistRecoveredMultipleHydrationState(
  raw: Hex, index: ArtistHydrationOwnerIndex, provenance: shared.ArtistRecoveredHydrationOwnerProvenance,
): ArtistRecoveredMultipleHydrationState {
  const types = ["bytes32", "uint16", "uint8", ARTIST_RECOVERED_MULTIPLE_HYDRATION_STATE_TUPLE];
  const bytes = preflight(types, raw), result = coder.decode(types, bytes);
  if (result[0] !== ARTIST_RECOVERED_MULTIPLE_HYDRATION_SCHEMA || result[1] !== 1n || result[2] !== BigInt(index)
    || coder.encode(types, result) !== bytes) throw Error("Noncanonical multiple State tag/version/owner");
  return validateArtistRecoveredMultipleHydrationState(index, plain(stateType, result[3]) as ArtistRecoveredMultipleHydrationState, provenance);
}

export function normalizeArtistRecoveredMultipleHydrationIdentity(value: ArtistRecoveredMultipleHydrationIdentity): ArtistRecoveredMultipleHydrationIdentity {
  return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_HYDRATION_IDENTITY_TUPLE, value);
}
export function encodeArtistRecoveredMultipleHydrationIdentity(value: ArtistRecoveredMultipleHydrationIdentity): Hex {
  return codec.encodeTupleValues([ARTIST_RECOVERED_MULTIPLE_HYDRATION_IDENTITY_TUPLE], [normalizeArtistRecoveredMultipleHydrationIdentity(value)]);
}
export function decodeArtistRecoveredMultipleHydrationIdentity(raw: Hex): ArtistRecoveredMultipleHydrationIdentity {
  return decode(ARTIST_RECOVERED_MULTIPLE_HYDRATION_IDENTITY_TUPLE, raw);
}
export function encodeArtistRecoveredMultipleHydrationPayout(value: ArtistRecoveredMultipleHydrationPayout): Hex {
  return codec.encodeTupleValues(["bytes32", ARTIST_RECOVERED_MULTIPLE_HYDRATION_PAYOUT_TUPLE],
    [payoutSchema, codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_HYDRATION_PAYOUT_TUPLE, value)]);
}
export function decodeArtistRecoveredMultipleHydrationPayout(raw: Hex): ArtistRecoveredMultipleHydrationPayout {
  const types = ["bytes32", ARTIST_RECOVERED_MULTIPLE_HYDRATION_PAYOUT_TUPLE];
  const bytes = preflight(types, raw), v = coder.decode(types, bytes);
  if (v[0] !== payoutSchema || coder.encode(types, v) !== bytes) throw Error("Noncanonical recovered Payout row");
  return codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_HYDRATION_PAYOUT_TUPLE,
    plain(ParamType.from(ARTIST_RECOVERED_MULTIPLE_HYDRATION_PAYOUT_TUPLE), v[1]) as ArtistRecoveredMultipleHydrationPayout);
}

export type ArtistRecoveredMultipleHydrationNonceLane = ArtistRecoveredMultipleHydrationIdentity["nonces"][number];

/** Exact global-index bijection; local lanes retain increasing global positions. Empty local sets are valid. */
export function artistRecoveredMultipleHydrationNonceUnion(
  value: ArtistRecoveredMultipleHydrationState,
  inventory: readonly shared.ArtistRecoveredHydrationNonceInventory[],
  checkpoint: Parameters<typeof codec.normalizeArtistRecoveredHydrationNonceInventory>[1],
): readonly ArtistRecoveredMultipleHydrationNonceLane[] {
  const s = normalizeArtistRecoveredMultipleHydrationState(value);
  const rows = codec.normalizeArtistRecoveredHydrationNonceInventory(inventory, checkpoint);
  if (s.rows.length !== s.artists.length || !s.artists.length || s.artists.length > 128) throw Error("Invalid Identity row partition");
  const result: ArtistRecoveredMultipleHydrationNonceLane[] = new Array(rows.length);
  const seen = new Set<number>(), authorities = new Set<Address>();
  let timing: Hex | undefined;
  for (let i = 0; i < s.rows.length; i++) {
    const b = decodeArtistRecoveredMultipleHydrationIdentity(s.rows[i]!);
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

export function normalizeArtistRecoveredMultipleHydrationOwnerPayload(
  value: shared.ArtistRecoveredHydrationOwnerPayload, index: ArtistHydrationOwnerIndex,
): shared.ArtistRecoveredHydrationOwnerPayload {
  const p = codec.normalizeArtistRecoveredHydrationOwnerPayload(value, index);
  decodeArtistRecoveredMultipleHydrationState(p.semanticState, index, p.provenance);
  if (index !== 2 && p.nonces.length) throw Error("Only Identity carries multiple nonce inventory");
  return p;
}
export function encodeArtistRecoveredMultipleHydrationOwnerPayload(
  value: shared.ArtistRecoveredHydrationOwnerPayload, index: ArtistHydrationOwnerIndex, features: bigint,
): Hex {
  return codec.encodeArtistRecoveredHydrationOwnerPayload(normalizeArtistRecoveredMultipleHydrationOwnerPayload(value, index), index, features);
}
export function decodeArtistRecoveredMultipleHydrationOwnerPayload(raw: Hex, index: ArtistHydrationOwnerIndex) {
  preflight(["bytes32", "uint16", shared.ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE], raw);
  const v = codec.decodeArtistRecoveredHydrationOwnerPayload(raw, index);
  normalizeArtistRecoveredMultipleHydrationOwnerPayload(v.payload, index);
  return v;
}

function occurrence(p: shared.ArtistRecoveredHydrationOwnerProvenance, q: ArtistHydrationQuery, op: bigint, key: Hex) {
  const rows = p.journal.filter(j => j.receipt.recordHash === key);
  if (key === Z || rows.length !== 1 || rows[0]!.receipt.operation !== op || rows[0]!.receipt.artistId !== q.artistId
    || rows[0]!.receipt.collectionId !== q.collectionId) throw Error("Multiple row native occurrence mismatch");
  return rows[0]!;
}

/** Supplied Binding preimage under its original era, never the destination Registry. */
export function artistRecoveredMultipleHydrationBindingHash(
  origin: shared.ArtistRecoveredHydrationOriginEnvironment, collectionId: bigint,
  value: ArtistRecoveredMultipleHydrationBinding["item"],
): Hex {
  const o = codec.normalizeArtistRecoveredHydrationOriginEnvironment(origin);
  const itemType = ParamType.from(ARTIST_RECOVERED_MULTIPLE_HYDRATION_BINDING_TUPLE).components!.find(c => c.name === "item")!;
  const b = codec.normalizeTuple(itemType.format("full"), value);
  if (typeof collectionId !== "bigint" || collectionId < 0n || collectionId >= 1n << 256n) throw Error("Expected collection uint256");
  return hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_BINDING_V1"), o.chainId, o.registry, o.core, collectionId, b.generation, b.artistId,
      b.artistAddress, b.identityRecordHash, b.consentMode, b.saleConsentScope, b.registryImmutabilityElection,
      hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), []]),
      hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []])]);
}

function collectionRows(index: ArtistHydrationOwnerIndex, s: ArtistRecoveredMultipleHydrationState, p: shared.ArtistRecoveredHydrationOwnerProvenance): void {
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
      const b = decode<ArtistRecoveredMultipleHydrationBinding>(ARTIST_RECOVERED_MULTIPLE_HYDRATION_BINDING_TUPLE, s.rows[i]!);
      const j = occurrence(p, q, 1n, q.bindingHash), e = era(j.position.point.environmentHash);
      counts[e] = counts[e]! + 1n; records++;
      const fields = ParamType.from(ARTIST_RECOVERED_MULTIPLE_HYDRATION_BINDING_TUPLE).components!;
      if (!same(fields[0]!.format("full"), b.scope, scope) || b.provenanceCommitment !== commitment
        || b.item.artistId !== q.artistId || b.item.bindingHash !== q.bindingHash || b.item.artistAddress === ZeroAddress
        || b.item.identityRecordHash === Z || b.item.proposer === ZeroAddress || b.item.generation !== 1n || !b.item.accepted
        || b.item.consentMode !== 1n || b.item.saleConsentScope > 1n || b.item.registryImmutabilityElection > 1n
        || !same(fields[2]!.format("full"), b.item, b.history) || b.terminal.kind !== 0n || b.terminal.reasonHash !== Z || b.terminal.recordHash !== Z
        || b.terms.count !== 0n || b.terms.mode !== 0n || b.terms.threshold !== 0n
        || b.terms.collaboratorSetHash !== hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), []])
        || b.terms.capabilityPolicySetHash !== hash(["bytes32", "bytes32[]"], [id("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []])
        || artistRecoveredMultipleHydrationBindingHash(p.origins[e]!, q.collectionId, b.item) !== q.bindingHash) {
        throw Error("Multiple Binding requires accepted generation1 PRIMARY_ONLY without collaborators");
      }
      guards(j, id("binding_lifecycle.replay.proposal_key") as Hex, hash(["uint256", "uint64"], [q.collectionId, 1n]));
    } else if (index === 3) {
      const b = decode<ArtistRecoveredMultipleHydrationAcceptance>(ARTIST_RECOVERED_MULTIPLE_HYDRATION_ACCEPTANCE_TUPLE, s.rows[i]!);
      if (b.scope.artistId !== q.artistId || b.scope.collectionId !== q.collectionId || b.scope.bindingHash !== q.bindingHash
        || b.provenanceCommitment !== commitment || !b.acceptedAt || b.record === Z) throw Error("Multiple Acceptance scope mismatch");
      const j = occurrence(p, q, 2n, b.record), e = era(j.position.point.environmentHash);
      counts[e] = counts[e]! + 1n; records++;
      guards(j, id("acceptance_lifecycle.replay.record_uniqueness") as Hex, Z);
    } else if (index === 4) {
      const b = decode<ArtistRecoveredMultipleHydrationAttribution>(ARTIST_RECOVERED_MULTIPLE_HYDRATION_ATTRIBUTION_TUPLE, s.rows[i]!);
      if (b.state.provenance !== commitment || b.state.artistId !== q.artistId || b.state.collectionId !== q.collectionId
        || b.state.bindingHash !== q.bindingHash || b.state.item.state !== 2n || b.state.item.generation !== 1n) throw Error("Multiple Attribution must be accepted generation1");
      const e = era(b.proposalOrigin); counts[e] = counts[e]! + 1n;
    } else if (index === 6) {
      const b = decode<ArtistRecoveredMultipleHydrationPolicy>(ARTIST_RECOVERED_MULTIPLE_HYDRATION_POLICY_TUPLE, s.rows[i]!);
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
export function artistRecoveredMultipleHydrationRequiredFeatures(
  identities: readonly ArtistRecoveredMultipleHydrationIdentity[],
  payouts: readonly ArtistRecoveredMultipleHydrationPayout[], eraCount: bigint,
): bigint {
  codec.boundedArray(identities, 128); codec.boundedArray(payouts, 128, identities.length);
  if (!identities.length || typeof eraCount !== "bigint" || eraCount < 1n || eraCount > 16n) throw Error("Invalid multiple feature scope");
  let result = 262144n;
  for (let i = 0; i < identities.length; i++) {
    const b = normalizeArtistRecoveredMultipleHydrationIdentity(identities[i]!);
    const p = codec.normalizeTuple(ARTIST_RECOVERED_MULTIPLE_HYDRATION_PAYOUT_TUPLE, payouts[i]!);
    if (b.artistId !== p.artistId || b.delegations.length) throw Error("Multiple delegated profile unsupported");
    result |= codec.artistRecoveredHydrationRequiredFeatures({ currentAuthorityClass: b.identity.authorityClass,
      recoveryAuthorityClasses: b.recoveries.map(r => r.record.fields.vestedAuthorityClass),
      hasAdjudicationV2: b.actions.some(a => a.evidenceV2.manifestHash !== Z),
      hasRewindsV3: b.actions.some(a => a.evidenceV3.manifestHash !== Z) || !!(b.revisionContinuations.length
        + b.standingContinuations.length + b.capabilityContinuations.length + p.continuations.length),
      eraCount, economicsCount: 0n, hasDelegations: false, bindingConsentMode: 1n, saleConsentCount: 0n, attestationCount: 0n });
  }
  return result;
}

/** Checks canonical rows, closed profile, complete partitions and nonce union.
 * Full Identity/Payout record semantics and external authority remain the original producer's job.
 */
export function normalizeArtistRecoveredMultipleHydrationPrepared(value: shared.ArtistRecoveredHydrationPrepared): shared.ArtistRecoveredHydrationPrepared {
  const p = codec.normalizeArtistRecoveredHydrationPrepared(value);
  const states: ArtistRecoveredMultipleHydrationState[] = [];
  const identities: ArtistRecoveredMultipleHydrationIdentity[] = [], payouts: ArtistRecoveredMultipleHydrationPayout[] = [];
  let features = 0n;
  for (let owner = 0; owner < 7; owner++) {
    const index = owner as ArtistHydrationOwnerIndex;
    const { header, payload } = decodeArtistRecoveredMultipleHydrationOwnerPayload(p.data[index].typedState, index);
    const s = decodeArtistRecoveredMultipleHydrationState(payload.semanticState, index, payload.provenance);
    if (!same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.artists, p.admission.artists)
      || !same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.collections, p.admission.collections)
      || !same(ARTIST_HYDRATION_QUERY_TUPLE, artistRecoveredMultipleHydrationAnchor(s), p.query)) throw Error("Multiple owner scope differs from full certificate");
    states.push(s); features = header.requiredFeatures;
    if (index === 2) {
      artistRecoveredMultipleHydrationNonceUnion(s, payload.nonces, payload.provenance.eras.at(-1)!.checkpoint);
      for (let i = 0; i < s.rows.length; i++) {
        const b = decodeArtistRecoveredMultipleHydrationIdentity(s.rows[i]!);
        if (!b.recoveries.length || b.identity.status === 0n || ![1n, 3n].includes(b.identity.authorityClass)
          || !same(ARTIST_HYDRATION_SNAPSHOT_TUPLE, b.sourceSnapshot, payload.provenance.eras.at(-1)!.checkpoint.ownerState)
          || !same(shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, b.timing.checkpoint, p.timing)) throw Error("Multiple Identity requires retained class1/3 recovery and global source clock");
        const rows = payload.provenance.journal.filter(j => j.receipt.artistId === b.artistId);
        if (rows.filter(j => j.receipt.operation === 35n).length !== b.recoveries.length * 2
          || rows.some(j => [26n, 27n, 44n, 45n, 46n, 47n, 49n, 50n, 59n].includes(j.receipt.operation))) throw Error("Unsupported multiple Identity journal profile");
        identities.push(b);
      }
    } else if (index === 5) {
      for (let i = 0; i < s.rows.length; i++) {
        const b = decodeArtistRecoveredMultipleHydrationPayout(s.rows[i]!);
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
  for (let i = 0; i < p.admission.collections.length; i++) {
    const q = p.admission.collections[i]!;
    const binding = occurrence(codec.artistRecoveredHydrationOwnerProvenance(p.admission.provenance, 0), q, 1n, q.bindingHash);
    const accepted = decode<ArtistRecoveredMultipleHydrationAcceptance>(ARTIST_RECOVERED_MULTIPLE_HYDRATION_ACCEPTANCE_TUPLE, states[3]!.rows[i]!);
    const acceptance = occurrence(codec.artistRecoveredHydrationOwnerProvenance(p.admission.provenance, 3), q, 2n, accepted.record);
    const attribution = decode<ArtistRecoveredMultipleHydrationAttribution>(ARTIST_RECOVERED_MULTIPLE_HYDRATION_ATTRIBUTION_TUPLE, states[4]!.rows[i]!);
    if (binding.position.point.environmentHash !== acceptance.position.point.environmentHash
      || attribution.proposalOrigin !== binding.position.point.environmentHash) throw Error("Multiple proposal/acceptance/attribution origin mismatch");
  }
  if (features !== artistRecoveredMultipleHydrationRequiredFeatures(identities, payouts, BigInt(p.admission.provenance.eras.length))) {
    throw Error("Multiple required features differ from original Identity union");
  }
  return p;
}

export function encodeArtistRecoveredMultipleHydrationPrepared(value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.encodeArtistRecoveredHydrationPrepared(normalizeArtistRecoveredMultipleHydrationPrepared(value));
}
export function decodeArtistRecoveredMultipleHydrationPrepared(raw: Hex): shared.ArtistRecoveredHydrationPrepared {
  preflight([shared.ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE], raw, shared.ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES);
  return normalizeArtistRecoveredMultipleHydrationPrepared(codec.decodeArtistRecoveredHydrationPrepared(raw));
}
export function artistRecoveredMultipleHydrationSemanticInventory(value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.artistRecoveredHydrationSemanticInventory(normalizeArtistRecoveredMultipleHydrationPrepared(value));
}
export function artistRecoveredMultipleHydrationCommitment(c: shared.ArtistRecoveredHydrationCoordinates, request: shared.ArtistRecoveredHydrationRequest, value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.artistRecoveredHydrationCommitment(c, request, normalizeArtistRecoveredMultipleHydrationPrepared(value));
}
export function encodeArtistRecoveredMultipleHydrationProfileEvidence(request: shared.ArtistRecoveredHydrationRequest, value: shared.ArtistRecoveredHydrationPrepared): Hex {
  return codec.encodeArtistRecoveredHydrationProfileEvidence(request, normalizeArtistRecoveredMultipleHydrationPrepared(value));
}

export const ARTIST_RECOVERED_MULTIPLE_HYDRATION_VALIDATION = Object.freeze({
  canonicalRowsChecked: true, completeProvenanceAndNoncePartitionChecked: true,
  completeIdentityAndPayoutSemanticsIndependentlyVerified: false,
  sourceAdmissionIndependentlyVerified: false, actualRegistrySimulationRequired: true,
});

export function decodeArtistRecoveredMultipleHydrationRequest(raw: Hex): shared.ArtistRecoveredHydrationRequest {
  preflight([shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE], raw);
  return codec.decodeArtistRecoveredHydrationRequest(raw);
}

/** Retained evidence has no destination before-state or live suite. It proves these
 * supplied partitions and commitments, not the original preparation admission. */
export function decodeArtistRecoveredMultipleHydrationProfileEvidence(raw: Hex): shared.ArtistRecoveredHydrationProfileEvidence {
  const types = ["bytes32", "uint16", "address", "address", shared.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE,
    `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, ARTIST_HYDRATION_QUERY_TUPLE,
    `${ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`,
    shared.ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, shared.ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE];
  preflight(types, raw);
  const e = codec.decodeArtistRecoveredHydrationProfileEvidence(raw);
  codec.normalizeArtistRecoveredHydrationRequest(e.request);
  const locals = e.data.map((d, i) => decodeArtistRecoveredMultipleHydrationOwnerPayload(d.typedState, i as ArtistHydrationOwnerIndex));
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
    const s = decodeArtistRecoveredMultipleHydrationState(local.payload.semanticState, index, local.payload.provenance);
    if (!same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.artists, e.artists) || !same(`${ARTIST_HYDRATION_QUERY_TUPLE}[]`, s.collections, e.collections)
      || !same(ARTIST_HYDRATION_QUERY_TUPLE, artistRecoveredMultipleHydrationAnchor(s), e.query)) throw Error("Evidence owner partitions differ");
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
  return e;
}
