import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { CurrentArtistDeployment } from "./current-artist-workflow.js";
import type { ArtistHydrationSnapshot } from "./current-artist-authority-hydration.js";
import { ARTIST_HYDRATION_SNAPSHOT_TUPLE } from "./current-artist-authority-hydration.js";
import * as recovery from "./current-artist-recovery-adjudication.js";
import * as rewind from "./current-artist-recovery-rewind.js";

// Frozen 898669e5 V3 workflow. The V2 workflow and its retained ABI remain separate.
const abi = new Interface([
  "function identityDocumentBytes(bytes32 documentHash) view returns (bytes)",
  "event ArtistPayoutRecoveryRewindApplied(uint16 schemaVersion, bytes32 indexed artistId, bytes32 indexed recoveryRecordHash, bytes32 indexed actionId, bytes32 planCommitment, bytes32 continuationHash, bytes32 mutationCommitment)",
  "event ArtistIdentityRecoveryPrepared(uint16 schemaVersion, bytes32 indexed artistId, bytes32 indexed governanceActionId, bytes32 associationHash, bytes32 guardianRecordHash, address preparedBy, uint64 preparedAt)",
  "function reads() view returns (address)",
  "event ArtistDormancyCancelled(uint16 schemaVersion, bytes32 indexed artistId, bytes32 indexed noticeHash, address canceller, uint8 authorityClass, bytes32 cancellationHash)",
  "event ArtistIdentityRecovered(uint16 schemaVersion, bytes32 indexed artistId, address indexed oldAddress, address indexed newAddress, uint8 vestedAuthorityClass, bytes32 evidenceHash, bytes32 reasonHash, bytes32 supersededRecordsHash, uint64 recoveredAt, bytes32 recoveryRecordHash, bytes32 governanceActionId, bytes32[] supersededRecordHashes)",
  "event ArtistStoredPayload(uint16 schemaVersion, uint256 indexed index, bytes32 indexed payloadType, bytes32 indexed payloadHash, address pointer)",
  "function artistRegistryCutover() view returns (bool, address, uint64)",
  "function core() view returns (address)",
  "function dormancyRecord(bytes32 hash) view returns ((bytes32 recordHash, (bytes32 artistId, bytes32 evidenceHash, string reasonURI) terms, address incumbent, uint64 initiatedAt, uint64 noticeEndsAt, uint64 inactivitySeconds, uint64 noticeSeconds, uint64 timingRevision, uint64 priorLivenessAt, uint256 priorActivity, bytes32 actionId, bytes32 witnessHash), uint8, (bytes32 recordHash, bytes32 noticeHash, address actor, uint8 authorityClass, uint64 observedAt, uint64 appointmentBlock, (address authority, uint8 authorityClass, uint32 capabilities, bytes32 designation, bytes32 directive, bytes32 guardian, bytes32 stewardGrantRecordHash, uint64 postSeconds, uint64 standingTail) plan, bytes32 evidenceHash, bytes32 actionId, bytes32 witnessHash, uint64 delegationEpoch))",
  "function estateDirectiveRecord(bytes32 record) view returns ((bytes32 recordHash, (bytes32 artistId, uint32 grantedCapabilities, uint32 forbiddenCapabilities, bytes32 directivePayloadHash) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt, (bytes32 transitionRecordHash, uint64 windowEndsAt) provisional))",
  "function governanceAuthority() view returns (address)",
  "function guardianSetRecord(bytes32 record) view returns ((bytes32 recordHash, (bytes32 artistId, address[] guardians, uint32 approvalThreshold, uint64 minContestSeconds) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt, bytes32 previousOperativeRecordHash, (bytes32 transitionRecordHash, uint64 windowEndsAt) provisional))",
  "function identityContestCause(bytes32 causeHash) view returns ((bytes32 causeHash, (bytes32 artistId, uint8 kind, bytes32 referenceHash, address actor, bytes32 reasonHash, bytes32 evidenceHash, uint64 enteredAt, address incumbent, uint8 authorityClass, uint8 priorStatus, bytes32 pendingTransitionHash, bytes32 executedTransitionHash, bytes32 previousCauseHash, bytes32 previousResolutionHash, bytes32 actorRetirementHash) facts))",
  "function identityRecoveryActionState(bytes32 artistId, bytes32 actionId) view returns ((bytes32 associationHash, bytes32 artistId, bytes32 requestHash, bytes32 acceptanceHash, bytes32 contextHash, (bytes32 actionId, bytes32 callsHash, uint256 callIndex, bytes32 callDataHash, address executor, bytes32 executorCodeHash, address proposer, bytes32 roleMutationHash, uint64 roleRevision, uint64 notBefore, uint64 expiresAfter, uint64 minimumDelay, bytes32 manifestHash) action, (bytes32 recordHash, (bytes32 artistId, address[] guardians, uint32 approvalThreshold, uint64 minContestSeconds) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt, bytes32 previousOperativeRecordHash, (bytes32 transitionRecordHash, uint64 windowEndsAt) provisional) guardian, address preparedBy, uint64 preparedAt, uint64 ownerRevision), (address vetoer, bytes32 reasonHash, uint64 vetoedAt), bytes32, uint64)",
  "function identityRecoveryContextV3((bytes32 artistId, address newAddress, uint8 vestedAuthorityClass, bytes32 expectedCauseHash, bytes32 expectedResolutionHash, bytes32 evidenceHash, bytes32 reasonHash, bytes32[] supersededRecordHashes) p, (uint256 nonce, uint64 time, bytes signature) a, bytes32 manifestHash) view returns ((bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, bytes32 causeHash, address incumbent, uint64 postContestSeconds, uint64 standingTailSeconds, uint64 timingRevision, uint64 delegationEpoch, (bytes32 artistId, bytes32 recordHash, uint64 stagedAt, uint64 contestEndsAt, uint64 executedAt, uint64 postWindowEndsAt, uint64 contestedAt, uint8 phase) abandonedTransition))",
  "function identityRecoveryEvidenceStateV3(bytes32 artistId, bytes32 actionId) view returns ((bytes32 manifestHash, bytes32 sourceKey, bytes32 sourceCommitment, bytes32 selectionCommitment, bytes32 policyCommitment, bytes32 requiredRole, uint32 effectiveCapabilities, bytes32 associationHash, (((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip) snapshot, uint256 receiptCount) identityBefore, ((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip) snapshot, uint256 receiptCount) payout, bytes32 associationHash) sources))",
  "function identityRecoveryRecord(bytes32 record) view returns ((bytes32 recordHash, (bytes32 artistId, address oldAddress, address newAddress, uint8 vestedAuthorityClass, bytes32 evidenceHash, bytes32 reasonHash, bytes32 supersededRecordsHash, bytes32 governanceActionId, uint64 recoveredAt) fields, (bytes32 artistId, address newAddress, uint8 vestedAuthorityClass, bytes32 expectedCauseHash, bytes32 expectedResolutionHash, bytes32 evidenceHash, bytes32 reasonHash, bytes32[] supersededRecordHashes) terms, address executor, address proposer, bytes32 governanceWitnessHash, bytes32 contextHash, bytes32 acceptanceDigest, uint256 acceptanceNonce, uint64 acceptanceDeadline, uint64 postContestSeconds, uint64 standingTailSeconds, uint64 timingRevision, uint64 delegationEpoch, (bytes32 artistId, bytes32 recordHash, uint64 stagedAt, uint64 contestEndsAt, uint64 executedAt, uint64 postWindowEndsAt, uint64 contestedAt, uint8 phase) abandonedTransition))",
  "function mintManager() view returns (address)",
  "function operationCoordinator() view returns (address)",
  "function operativeEstateDirective(bytes32 artistId) view returns (bytes32)",
  "function rotationAcceptanceNonceState(bytes32 artistId, address account, uint256 nonce) view returns (bool, uint256)",
  "function storedPayloadAt(uint256 index) view returns (address, bytes32, bytes32)",
  "function storedPayloadCount() view returns (uint256)",
  "function configurationHash() view returns (bytes32)",
  "function deploymentChainId() view returns (uint256)",
  "function suiteConfiguration() view returns ((address registry, address archive, address[7] owners, address core, address mintManager, address roleRegistry, address metadata, address primaryResolver, address royaltyResolver, bytes32 primaryRevenueClass, address validator))",
  "function archiveV2() view returns (address)",
  "function artistNativeReceiptAt(uint256 index) view returns ((uint16 operation, bytes32 artistId, uint256 collectionId, bytes32 recordHash))",
  "function artistNativeReceiptCount() view returns (uint256)",
  "function artistRegistry() view returns (address)",
  "function artistWindowAuthority() view returns (address)",
  "function domainId() view returns (bytes32)",
  "function dormancyResolutionState(bytes32 id, bytes32 cause) view returns (bytes32, uint8, bytes32)",
  "function guardianHistoryState(bytes32 artistId, uint64 index, address actor, bytes32 actionId) view returns ((uint64 count, uint64 ownerRevision, bytes32 commitment), (bytes32 artistId, uint64 index, uint64 ownerRevision, bytes32 recordHash, bytes32 recordDataHash, bytes32 previousCommitment, bytes32 commitment), (bytes32 artistId, uint64 count, bytes32 historyCommitment, bytes32 associationHash), uint64)",
  "function guardianRecoveryAuthorityRoleV3((bytes32 artistId, address newAddress, uint8 vestedAuthorityClass, bytes32 expectedCauseHash, bytes32 expectedResolutionHash, bytes32 evidenceHash, bytes32 reasonHash, bytes32[] supersededRecordHashes) p, (uint256 nonce, uint64 time, bytes signature) a, bytes32 manifestHash, (((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip) snapshot, uint256 receiptCount) payout, ((address account, bytes32 recordHash) stable, (address account, bytes32 recordHash) candidate, bytes32 supersessionStateCommitment, bytes32 continuationCommitment) payoutInventory, (bytes32 sourceKey, bytes32 manifestHash, bytes32 sourceCommitment, bytes32 inventoryCommitment, (bytes32 sourceKey, bytes32 selectedRecordHash, bytes32 selectedDataHash, uint256 selectedNonce, bytes32 commitment) guardians, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) designation, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) directive, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) identityRevision, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) payout, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) sanctionGrant, (address priorAddress, bytes32 retirementHash, bytes32 expectedRevocationRecordHash, (bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) retainedRevocation, bytes32 independentJudgmentHash, bytes32 continuationCommitment)[] standing, bytes32 commitment) selection) facts) view returns (bytes32)",
  "function guardianRecoverySelection(bytes32 actionId) view returns ((bytes32 sourceKey, bytes32 selectedRecordHash, bytes32 selectedDataHash, uint256 selectedNonce, bytes32 commitment), (bytes32 recordHash, (bytes32 artistId, address[] guardians, uint32 approvalThreshold, uint64 minContestSeconds) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt, bytes32 previousOperativeRecordHash, (bytes32 transitionRecordHash, uint64 windowEndsAt) provisional))",
  "function guardianVestingSnapshot(bytes32 artistId, bytes32 recordHash) view returns ((bytes32 artistId, bytes32 transitionRecordHash, uint16 operationId, uint64 ownerRevision, uint64 executedAt, address oldAddress, address newAddress, uint8 authorityClass, (uint64 count, uint64 ownerRevision, bytes32 commitment) guardians, bytes32 previousTransitionRecordHash, bytes32 previousCommitment, bytes32 commitment))",
  "function identityRecoveryReceipts(bytes32 record) view returns (bytes32, bytes32, bytes32)",
  "function ownerStateSnapshotV2() view returns ((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip))",
  "function recoveryRewindEvidenceBinding() view returns (address, bytes32)",
  "function recoveryExecutorBinding() view returns (address, bytes32)",
  "function recoveryRewindBasisV3(bytes32 manifestHash) view returns ((bytes32 manifestHash, bytes32 artistId, bytes32 ownerCodeHash, ((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip) snapshot, uint256 receiptCount) identity, ((bytes32 stable, bytes32 candidate) guardians, (bytes32 stable, bytes32 candidate) designations, (bytes32 stable, bytes32 candidate) directives, (bytes32 stable, bytes32 candidate) revisions, (bytes32 stable, bytes32 candidate) sanctionGrants, bytes32 revisionContinuationHash, bytes32 supersessionStateCommitment) inventory, (uint64 count, uint64 ownerRevision, bytes32 commitment) guardianHistory, bytes32 sourceCommitment))",
  "function recoveryRewindSelectionBinding() view returns (address, bytes32)",
  "function replayCell(bytes32 key) view returns ((bytes32 commitment, uint64 touchedRevision, uint8 kind, uint8 status))",
  "function appealEvidenceV3(bytes32 hash) view returns ((bytes32 resolutionManifestHash, bytes32 hostileFindingsHash, (bytes32 guardianRecordHash, address[] parties)[] findings), bytes32, bytes32)",
  "function archive() view returns (address)",
  "function coordinator() view returns (address)",
  "function owner() view returns (address)",
  "function resolutionManifestV3(bytes32 hash) view returns ((bytes32 artistId, ((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip) snapshot, uint256 receiptCount) identity, ((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip) snapshot, uint256 receiptCount) payout, bytes32 causeHash, bytes32 resolutionHash, bytes32 executedHead, uint8 basis, bytes32 requestCommitment, bytes32 resolutionEvidenceHash, (bytes32 transitionRecordHash, bytes32 vestingCommitment)[] contestedVestings, (uint8 kind, bytes32 recordHash)[] supersededRecords), bytes32, bytes32)",
  "function requireSelectionV3(bytes32 manifestHash) view returns ((bytes32 sourceKey, bytes32 manifestHash, bytes32 sourceCommitment, bytes32 inventoryCommitment, (bytes32 sourceKey, bytes32 selectedRecordHash, bytes32 selectedDataHash, uint256 selectedNonce, bytes32 commitment) guardians, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) designation, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) directive, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) identityRevision, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) payout, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) sanctionGrant, (address priorAddress, bytes32 retirementHash, bytes32 expectedRevocationRecordHash, (bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) retainedRevocation, bytes32 independentJudgmentHash, bytes32 continuationCommitment)[] standing, bytes32 commitment))",
  "function retainedMemberV3(bytes32 key, address actor) view returns (bool)",
  "function selectionV3(bytes32 key) view returns (((bytes32 manifestHash, bytes32 artistId, bytes32 ownerCodeHash, ((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip) snapshot, uint256 receiptCount) identity, ((bytes32 stable, bytes32 candidate) guardians, (bytes32 stable, bytes32 candidate) designations, (bytes32 stable, bytes32 candidate) directives, (bytes32 stable, bytes32 candidate) revisions, (bytes32 stable, bytes32 candidate) sanctionGrants, bytes32 revisionContinuationHash, bytes32 supersessionStateCommitment) inventory, (uint64 count, uint64 ownerRevision, bytes32 commitment) guardianHistory, bytes32 sourceCommitment) identity, bytes32 payoutCodeHash, ((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip) snapshot, uint256 receiptCount) payout, ((address account, bytes32 recordHash) stable, (address account, bytes32 recordHash) candidate, bytes32 supersessionStateCommitment, bytes32 continuationCommitment) payoutInventory, bytes32 sourceCommitment), (uint256 identityProcessed, uint256 payoutProcessed, uint64 guardiansProcessed, uint256 seenExclusions, bytes32 identityScanCommitment, bytes32 payoutScanCommitment, bool complete, bytes32 resultCommitment))",
  "event ArtistArchiveEvidenceAppendedV2(bytes32 indexed evidenceId, uint64 indexed evidenceVersion, bytes32 indexed contentHash, address pointer, uint256 payloadSize)",
  "function artistArchiveMaxEvidenceBytesV2() pure returns (uint256)",
  "function artistEvidenceBytesV2(bytes32 evidenceId, uint64 evidenceVersion) view returns (bytes evidence)",
  "function artistEvidenceMetadataV2(bytes32 evidenceId, uint64 evidenceVersion) view returns (bytes32 contentHash, address pointer, uint32 payloadSize, uint64 appendedAtBlock)",
  "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)",
  "event GovernanceActionExecuted(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, address executor, bytes32 manifestHash)",
  "event GovernanceActionPolicyValidated(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed phase, bytes32 indexed candidateProfileHash, bytes32 catalogHash)",
  "event GovernanceActionScheduled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, uint256 nonce, address proposer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash)",
  "event GovernanceCallDataPublished(uint16 schemaVersion, bytes32 indexed callDataKey, address pointer, address publisher)",
  "event TerminalFreezeActionMembershipUpdated(uint16 schemaVersion, bytes32 indexed scopeHash, bytes32 indexed actionId, address indexed proposer, bool present, uint8 mutationCause, bool usesRootCapacity, uint64 vetoDeadline, uint256 rawIndex, uint256 remainingCount)",
  "event TerminalFreezeGuardianConfigCommitted(uint16 schemaVersion, bytes32 indexed actionId, bytes32 indexed commitment)",
  "function currentAction() view returns (bool executing, bytes32 actionId, uint8 actionClass, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)",
  "function governanceAction(bytes32 actionId) view returns ((uint8 status, uint8 actionClass, address target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, address proposer, address executor, address canceller, address vetoer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash))",
  "function governanceActionFacts(bytes32 id) view returns ((uint8 status, uint8 actionClass, bytes32 callHash, uint64 notBefore, uint64 expiresAfter) facts)",
  "function governanceActionPolicyState() view returns (bytes32 candidateProfileHash, bytes32 catalogHash, uint256 entryCount, uint64 revision)",
  "function governanceNonce() view returns (uint256)",
  "function governanceRootState() view returns (address governanceRoot_, bytes32 codeHash, uint64 revision)",
  "function isProposer(address account) view returns (bool)",
  "function minimumDelay(uint8 actionClass) pure returns (uint64)",
  "function publishedCallData(bytes32 callDataKey) view returns (address)",
  "function roleRegistry() view returns (address)",
  "function scheduledCallData(bytes32 actionId) view returns (bytes[])",
  "function scheduledCallDataPointer(bytes32 actionId) view returns (address)",
  "function systemManifestBootstrapState() view returns (bool, bool, address, bytes32, address, bytes32, uint64, bytes32, uint256, bytes32, uint64, address, bytes32, address, bytes32, bytes32, uint256, bytes32, uint256, bytes32, bytes32, uint256, bytes32, uint256, address, address, bytes32, bytes32, uint256)",
  "function terminalFreezeGuardianConfigCommitment(bytes32 actionId) view returns (bytes32 commitment)",
  "function hasRole(bytes32 role, address account) view returns (bool)",
  "function isRoleRedundant(bytes32 role) view returns (bool)",
  "function roleMutationState(bytes32 role) view returns (bytes32 chainHash, uint64 revision)",
  "event ArtistDormancyCancellationContext(uint16 schemaVersion, bytes32 indexed artistId, bytes32 indexed recordHash, (uint256 chainId, address registry, address identityOwner, address recorder, uint8 recorderAuthorityClass) context, (bytes32 recordHash, bytes32 noticeHash, address actor, uint8 authorityClass, uint64 observedAt, uint64 appointmentBlock, (address authority, uint8 authorityClass, uint32 capabilities, bytes32 designation, bytes32 directive, bytes32 guardian, bytes32 stewardGrantRecordHash, uint64 postSeconds, uint64 standingTail) plan, bytes32 evidenceHash, bytes32 actionId, bytes32 witnessHash, uint64 delegationEpoch) terminal, uint256 activityCount)",
  "function payoutOwner() view returns (address)",
  "function publishPayoutOriginalV3((bytes32 recordHash, (bytes32 artistId, address payoutAccount, bytes32 previousDesignationRecordHash) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt) original) returns (bytes32 hash)",
  "function payoutOriginalV3(bytes32 recordHash) view returns ((bytes32 recordHash, (bytes32 artistId, address payoutAccount, bytes32 previousDesignationRecordHash) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt), bytes32, bytes32, bytes32)",
  "event RecoveryRewindManifestPublished(bytes32 indexed manifestHash, bytes32 indexed artistId, bytes32 indexed causeHash, bytes32 identityCodeHash, bytes32 payoutCodeHash)",
  "event RecoveryRewindAppealPublished(bytes32 indexed documentHash, bytes32 indexed manifestHash, bytes32 identityCodeHash, bytes32 payoutCodeHash)",
  "event RecoveryPayoutOriginalPublished(bytes32 indexed evidenceHash, bytes32 indexed recordHash, bytes32 indexed artistId, bytes32 identityCodeHash, bytes32 payoutCodeHash)",
  "event RecoveryRewindSelectionBegun(bytes32 indexed key, bytes32 indexed manifestHash)",
  "event RecoveryRewindSelectionProgress(bytes32 indexed key, uint256 identityProcessed, uint256 payoutProcessed, bool complete)",
  "event RecoveryRewindPreparationSealed(bytes32 indexed key, bytes32 indexed actionId, bytes32 commitment)",
  "error InvalidRecoveryRewindManifest(bytes32 manifestHash)",
  "error InvalidRecoveryRewindAppeal(bytes32 documentHash)",
  "error InvalidRecoveryPayoutOriginal(bytes32 recordHash)",
  "function selectionResultV3(bytes32 key) view returns ((bytes32 sourceKey, bytes32 manifestHash, bytes32 sourceCommitment, bytes32 inventoryCommitment, (bytes32 sourceKey, bytes32 selectedRecordHash, bytes32 selectedDataHash, uint256 selectedNonce, bytes32 commitment) guardians, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) designation, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) directive, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) identityRevision, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) payout, ((bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) operative, bytes32 retainedCandidateRecordHash, bytes32 branchCommitment) sanctionGrant, (address priorAddress, bytes32 retirementHash, bytes32 expectedRevocationRecordHash, (bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex) retainedRevocation, bytes32 independentJudgmentHash, bytes32 continuationCommitment)[] standing, bytes32 commitment))",
  "function selectionRecordV3(bytes32 key, bytes32 recordHash) view returns (uint8, (bytes32 recordHash, bytes32 originalDataHash, bytes32 admissionProof, uint256 nonce, uint256 nativeIndex), bool retained, bool eligible)",
  "function preparationSealV3(bytes32 key) view returns ((bytes32 manifestHash, bytes32 sourceKey, bytes32 actionId, bytes32 associationHash, ((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip) snapshot, uint256 receiptCount) identityBefore, (bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip) identityAfterPreparation, ((bytes32 domainId, uint64 revision, bytes32 stateRoot, bytes32 recordChainTip) snapshot, uint256 receiptCount) payout, bytes32 evidenceStateHash, bytes32 commitment))",
  "function recoveryRewindInventoryV3(bytes32 artistId) view returns (((bytes32 stable, bytes32 candidate) guardians, (bytes32 stable, bytes32 candidate) designations, (bytes32 stable, bytes32 candidate) directives, (bytes32 stable, bytes32 candidate) revisions, (bytes32 stable, bytes32 candidate) sanctionGrants, bytes32 revisionContinuationHash, bytes32 supersessionStateCommitment))",
  "function payoutRewindInventoryV3(bytes32 artistId) view returns (((address account, bytes32 recordHash) stable, (address account, bytes32 recordHash) candidate, bytes32 supersessionStateCommitment, bytes32 continuationCommitment))",
  "function recoveryRecordStatusV3(uint8 kind, bytes32 recordHash) view returns ((bytes32 artistId, uint8 kind, bytes32 recoveryRecordHash, bytes32 actionId, bytes32 planCommitment))",
  "function payoutRecoveryRecordStatusV3(bytes32 recordHash) view returns ((bytes32 artistId, uint8 kind, bytes32 recoveryRecordHash, bytes32 actionId, bytes32 planCommitment))",
  "function recoveryStandingScopeV3(bytes32 artistId, address priorAddress) view returns (bytes32, bytes32, bytes32, bytes32)",
  "function latestRecoveryCapabilityContinuationV3(bytes32 artistId) view returns (bytes32)",
  "function recoveryCapabilityContinuationV3(bytes32 record) view returns ((bytes32 artistId, bytes32 originalActivationRecordHash, uint32 originalActivationCapabilities, bytes32 recoveryRecordHash, bytes32 actionId, bytes32 manifestHash, bytes32 planCommitment, bytes32 designationRecordHash, bytes32 pairedDirectiveRecordHash, bytes32 forbiddenDirectiveRecordHash, address authorityAddress, uint32 effectiveCapabilities, bytes32 commitment))",
  "function identityRevisionRecoveryContinuationV3(bytes32 record) view returns (bytes32)",
  "function recoveryRevisionContinuationV3(bytes32 hash) view returns ((bytes32 artistId, bytes32 recoveryRecordHash, bytes32 actionId, bytes32 planCommitment, bytes32 stableRevisionRecordHash, bytes32 stableDocumentHash, bytes32 resolvedChildRecordHash, uint64 ownerRevision, bytes32 continuationHash))",
  "function standingRevocationRecoveryContinuationV3(bytes32 record) view returns (bytes32)",
  "function recoveryStandingContinuationV3(bytes32 hash) view returns ((bytes32 artistId, address priorAddress, bytes32 retirementHash, bytes32 recoveryRecordHash, bytes32 actionId, bytes32 planCommitment, bytes32 retainedRevocationRecordHash, bytes32 supersededRevocationRecordHash, uint64 ownerRevision, bytes32 continuationHash))",
  "function payoutDesignationRecoveryContinuationV3(bytes32 recordHash) view returns (bytes32)",
  "function payoutRecoveryContinuationV3(bytes32 continuationHash) view returns ((bytes32 artistId, bytes32 recoveryRecordHash, bytes32 actionId, bytes32 manifestHash, bytes32 planCommitment, uint64 identityOwnerRevision, (address account, bytes32 recordHash) stable, (address account, bytes32 recordHash) candidate, bytes32 releasedChildRecordHash, bytes32 previousContinuationHash, uint64 payoutOwnerRevision, bytes32 continuationHash))",
  "function identityRevisionRecord(bytes32 record) view returns ((bytes32 recordHash, bytes32 artistId, bytes32 previousRecordHash, bytes32 revisedRecordHash, bytes32 previousRevisionRecord, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt, string identityRecordURI, string displayName))",
  "function identity(bytes32 artistId) view returns ((address authorityAddress, uint8 authorityClass, uint8 status, uint64 registeredAt, uint64 lastAuthorityActionAt, bytes32 identityRecordHash, string identityRecordURI, string displayName, uint256 nonceHint))",
  "function designationRecord(bytes32 record) view returns ((bytes32 artistId, address payoutAccount, bytes32 previousDesignationRecordHash))",
  "function successorDesignationRecord(bytes32 record) view returns ((bytes32 recordHash, (bytes32 artistId, address successor, uint8 successorKind, uint32 grantedCapabilities, bytes32 conditionsHash, bytes32 directiveHash) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt, (bytes32 transitionRecordHash, uint64 windowEndsAt) provisional))",
  "function estateDirectivePayload(bytes32 record) view returns (bytes)",
  "function stewardSanctionGrantRecord(bytes32 hash) view returns ((bytes32 recordHash, (bytes32 artistId, bool granted, bytes32 statementHash) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt, (bytes32 transitionRecordHash, uint64 windowEndsAt) provisional))",
  "function standingRevocationRecord(bytes32 record) view returns ((bytes32 recordHash, (bytes32 artistId, address revokedAddress, bytes32 reasonHash, bytes32 retiredTransitionRecordHash) terms, address signer, uint8 authorityClass, uint256 nonce, uint64 signedAt))"
]);
const coder = AbiCoder.defaultAbiCoder();
function keys(v: unknown, required: readonly string[], optional: readonly string[] = []): void {
  if (!v || typeof v !== "object" || Array.isArray(v) || Reflect.ownKeys(v).some(k => typeof k !== "string" || ![...required, ...optional].includes(k))
    || required.some(k => !Object.hasOwn(v, k))) throw Error("Missing/unknown properties");
}
function address(v: unknown): Address {
  if (typeof v !== "string") throw Error("Expected address");
  const a = getAddress(v) as Address;
  if (a === ZeroAddress) throw Error("Zero address");
  return a;
}
function hash(v: unknown, zero = false): Hex {
  if (typeof v !== "string" || !isHexString(v, 32) || (!zero && v.toLowerCase() === ZeroHash)) throw Error("Expected bytes32");
  return v.toLowerCase() as Hex;
}
function uint(v: unknown, bits = 256): bigint {
  if (typeof v !== "bigint" || v < 0n || v >= 1n << BigInt(bits)) throw Error("Expected bounded unsigned bigint");
  return v;
}
function number(v: unknown): number {
  if (typeof v !== "number" || !Number.isSafeInteger(v) || v < 0) throw Error("Expected concrete block/index");
  return v;
}
function bytes(v: unknown, max = 32768): Hex {
  if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > max) throw Error("Malformed or oversized bytes");
  return v.toLowerCase() as Hex;
}
function same(a: unknown, b: unknown): boolean {
  return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
}
function stable(v: unknown): string {
  const tagged = (x: unknown): unknown => {
    if (x === null) return ["null"];
    if (typeof x === "string" || typeof x === "boolean") return [typeof x, x];
    if (typeof x === "bigint") return ["bigint", x.toString()];
    if (typeof x === "number" && Number.isFinite(x)) return ["number", x];
    if (Array.isArray(x)) return ["array", x.map(tagged)];
    if (x && typeof x === "object") return ["object", Object.keys(x).sort().map(k => [k, tagged((x as Record<string, unknown>)[k])])];
    throw Error("Unsupported canonical value");
  };
  return JSON.stringify(tagged(v));
}
function equal(a: unknown, b: unknown, reason = "Prepared facts differ; recapture and review"): void {
  if (stable(a) !== stable(b)) throw Error(reason);
}
function freeze<T>(v: T): T {
  if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); }
  return v;
}
async function header(p: Reader, tag: number) {
  const b = await p.getBlock(tag);
  if (!b || b.number !== tag || !Number.isSafeInteger(b.timestamp) || b.timestamp < 0) throw Error("Missing/mismatched block");
  return { blockNumber: tag, blockHash: hash(b.hash), timestamp: BigInt(b.timestamp) };
}
async function unchanged(p: Reader, h: { blockNumber: number; blockHash: Hex; timestamp: bigint }): Promise<void> {
  equal(await header(p, h.blockNumber), { blockNumber: h.blockNumber, blockHash: h.blockHash, timestamp: h.timestamp }, "Pinned block changed");
}
async function runtime(p: Reader, v: ArtistRecoveryRewindCodePin, tag: number): Promise<void> {
  const code = bytes(await p.getCode(v.address, tag), 65536);
  if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), v.codeHash)) throw Error("Pinned runtime differs");
}

function plain(t: ParamType, value: any): any {
  if (t.baseType === "array") return Array.from(value, item => plain(t.arrayChildren!, item));
  if (t.baseType === "tuple") return Object.fromEntries(t.components!.map((part, i) => [part.name, plain(part, value[i])]));
  return value;
}
async function read(p: Reader, to: Address, name: string, args: readonly unknown[], tag: number, from?: Address, maximum = 32768): Promise<any[]> {
  const raw = bytes(await p.call({ to, data: abi.encodeFunctionData(name, args), value: 0n, blockTag: tag, ...(from ? { from } : {}) }), maximum);
  const decoded = abi.decodeFunctionResult(name, raw);
  if (!same(abi.encodeFunctionResult(name, decoded), raw)) throw Error(`Noncanonical ${name} return`);
  return abi.getFunction(name)!.outputs!.map((part, i) => plain(part, decoded[i]));
}

const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"].map(n => id(`domain:${n}`));
function digest(v: unknown): Hex { return keccak256(toUtf8Bytes(stable(v))) as Hex; }
function pin(v: ArtistRecoveryRewindCodePin): ArtistRecoveryRewindCodePin {
  keys(v, ["address", "codeHash"]);
  return { address: address(v.address), codeHash: hash(v.codeHash) };
}

export interface ArtistRecoveryRewindCodePin { readonly address: Address; readonly codeHash: Hex }
export interface ArtistRecoveryRewindDeployment {
  readonly artist: CurrentArtistDeployment;
  readonly evidence: ArtistRecoveryRewindCodePin;
  readonly selection: ArtistRecoveryRewindCodePin;
  readonly governance: ArtistRecoveryRewindCodePin;
}
type Reader = Pick<import("ethers").Provider, "getNetwork" | "getBlock" | "getCode" | "call">;
type ReceiptReader = Reader & Pick<import("ethers").Provider, "getTransaction" | "getTransactionReceipt">;
interface Block { readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint }
function deployment(v: ArtistRecoveryRewindDeployment): ArtistRecoveryRewindDeployment {
  keys(v, ["artist", "evidence", "selection", "governance"]);
  const a = v.artist;
  keys(a, ["chainId", "registry", "coordinator", "components"], ["reads"]);
  if (!Array.isArray(a.components) || a.components.length !== 16 || Reflect.ownKeys(a.components).length !== 17) throw Error("Expected exactly16 component pins");
  const components = a.components.map(pin), registry = pin(a.registry);
  if (!same(components[7]!.address, registry.address) || !same(components[7]!.codeHash, registry.codeHash)
    || new Set(components.map(x => x.address)).size !== 16) throw Error("Distinct suite pins required");
  return freeze({ artist: { chainId: uint(a.chainId), registry, coordinator: pin(a.coordinator), components,
    ...(a.reads ? { reads: pin(a.reads) } : {}) }, evidence: pin(v.evidence), selection: pin(v.selection), governance: pin(v.governance) });
}
function coordinates(d: ArtistRecoveryRewindDeployment): rewind.ArtistRecoveryRewindCoordinates {
  return { chainId: d.artist.chainId, registry: d.artist.registry.address, coordinator: d.artist.coordinator.address,
    identityOwner: d.artist.components[2]!.address, identityCodeHash: d.artist.components[2]!.codeHash,
    payoutOwner: d.artist.components[5]!.address, payoutCodeHash: d.artist.components[5]!.codeHash,
    archive: d.artist.components[8]!.address, core: d.artist.components[9]!.address,
    manager: d.artist.components[10]!.address, evidencePublisher: d.evidence.address, selectionPreparation: d.selection.address };
}
function legacy(c: rewind.ArtistRecoveryRewindCoordinates): recovery.ArtistRecoveryAdjudicationCoordinates {
  return { chainId: c.chainId, registry: c.registry, coordinator: c.coordinator, owner: c.identityOwner,
    ownerCodeHash: c.identityCodeHash, archive: c.archive, core: c.core, mintManager: c.manager,
    evidencePublisher: c.evidencePublisher, selectionPreparation: c.selectionPreparation };
}
async function artistContext(p: Reader, d: CurrentArtistDeployment, tag: number, current: boolean) {
  if ((await p.getNetwork()).chainId !== d.chainId) {
    throw Error("RPC chain mismatch");
  }
  const h = await header(p, tag);
  await Promise.all([d.coordinator, ...d.components, ...(d.reads ? [d.reads] : [])].map(async (x) => {
    const code = bytes(await p.getCode(x.address, tag), 65536);
    if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), x.codeHash)) {
      throw Error("Pinned Artist runtime differs");
    }
  }));
  const [suite] = await read(p, d.coordinator.address, "suiteConfiguration", [], tag);
  const ordered = [...suite.owners, suite.registry, suite.archive, suite.core, suite.mintManager, suite.roleRegistry, suite.metadata, suite.primaryResolver, suite.royaltyResolver, suite.validator];
  equal(ordered.map(address), d.components.map(p => p.address), "Suite component pins differ");
  if (d.reads && !same((await read(p, d.coordinator.address, "reads", [], tag))[0], d.reads.address)) {
    throw Error("Coordinator Reads binding differs");
  }
  if ((await read(p, d.coordinator.address, "deploymentChainId", [], tag))[0] !== d.chainId) {
    throw Error("Coordinator chain differs");
  }
  const core = d.components[9]!.address;
  const manager = d.components[10]!.address;
  for (const [name, expected] of [["core", core], ["mintManager", manager], ["operationCoordinator", d.coordinator.address]]) {
    if (!same((await read(p, d.registry.address, name!, [], tag))[0], expected)) {
      throw Error("Facade binding differs");
    }
  }
  for (let i = 0; i < 7; i++) {
    const owner = d.components[i]!.address;
    for (const [name, expected] of [["core", core], ["mintManager", manager], ["artistRegistry", d.registry.address], ["operationCoordinator", d.coordinator.address], ["archiveV2", d.components[8]!.address], ["domainId", domains[i]!]]) {
      if (!same((await read(p, owner, name!, [], tag))[0], expected)) {
        throw Error("Owner binding differs");
      }
    }
    if ((await read(p, owner, "deploymentChainId", [], tag))[0] !== d.chainId) {
      throw Error("Owner chain differs");
    }
  }
  if (current) {
    const pointer = await read(p, core, "getSatellitePointer", [id("ARTIST_REGISTRY")], tag);
    if (!same(pointer[0], d.registry.address) || !same(pointer[1], d.registry.codeHash) || (await read(p, d.registry.address, "artistRegistryCutover", [], tag))[0] !== false) {
      throw Error("Artist registry is not current");
    }
  }
  return {
    ...h, configurationHash: hash((await read(p, d.coordinator.address, "configurationHash", [], tag))[0])
  };
}


async function context(p: Reader, d: ArtistRecoveryRewindDeployment, tag: number, current: boolean) {
  const h = await artistContext(p, d.artist, tag, current), c = coordinates(d);
  await Promise.all([d.evidence, d.selection, d.governance].map(v => runtime(p, v, tag)));
  for (const [method, expected] of [["recoveryRewindEvidenceBinding", d.evidence], ["recoveryRewindSelectionBinding", d.selection], ["recoveryExecutorBinding", d.governance]] as const) {
    equal(await read(p, c.identityOwner, method, [], tag), [expected.address, expected.codeHash], "Identity helper binding differs");
  }
  for (const helper of [c.evidencePublisher, c.selectionPreparation]) {
    for (const [name, value] of [["owner", c.identityOwner], ["payoutOwner", c.payoutOwner], ["coordinator", c.coordinator], ["artistRegistry", c.registry], ["deploymentChainId", c.chainId]] as const) {
      equal((await read(p, helper, name, [], tag))[0], value, "Helper reciprocal binding differs");
    }
  }
  for (const [name, value] of [["coordinator", c.coordinator], ["archive", c.archive], ["core", c.core], ["mintManager", c.manager]] as const) {
    equal((await read(p, c.evidencePublisher, name, [], tag))[0], value, "Evidence publisher binding differs");
  }
  equal((await read(p, c.identityOwner, "artistWindowAuthority", [], tag))[0], d.governance.address);
  equal((await read(p, d.governance.address, "roleRegistry", [], tag))[0], d.artist.components[11]!.address);
  return h;
}
function encoded(types: readonly string[], values: readonly unknown[]): Hex { return coder.encode(types, values) as Hex; }
function hashEncoded(types: readonly string[], values: readonly unknown[]): Hex { return keccak256(encoded(types, values)) as Hex; }
function zeros(type: string): any {
  const walk = (p: ParamType): any => p.baseType === "tuple" ? Object.fromEntries(p.components!.map(x => [x.name, walk(x)]))
    : p.baseType === "array" ? Array.from({ length: Math.max(p.arrayLength!, 0) }, () => walk(p.arrayChildren!))
    : p.type === "address" ? ZeroAddress : p.type === "bool" ? false : p.type === "bytes" ? "0x" : p.type === "string" ? "" : p.type.startsWith("bytes") ? "0x" + "00".repeat(Number(p.type.slice(5))) : 0n;
  return walk(ParamType.from(type));
}
function bounded(value: bigint, max: number, label: string): number {
  uint(value); if (value > BigInt(max)) throw Error(label + " exceeds client bound"); return Number(value);
}
export interface ArtistRecoveryRewindNativeRow {
  readonly operation: bigint; readonly artistId: Hex; readonly collectionId: bigint; readonly recordHash: Hex;
}
export interface ArtistRecoveryRewindRecordObservation {
  readonly kind: bigint; readonly record: rewind.ArtistRecoveryRewindSelectedRecord;
  readonly retained: boolean; readonly eligible: boolean; readonly originalData: Hex;
  readonly observedStatus: rewind.ArtistRecoveryRewindStatus;
}
export interface ArtistRecoveryRewindSelectionObservation {
  readonly key: Hex;
  readonly basis: rewind.ArtistRecoveryRewindSelectionBasis;
  readonly progress: rewind.ArtistRecoveryRewindSelectionProgress;
  readonly result: rewind.ArtistRecoveryRewindSelectionResult | null;
  readonly seal: rewind.ArtistRecoveryRewindPreparationSeal;
  readonly identityJournal: readonly ArtistRecoveryRewindNativeRow[];
  readonly payoutJournal: readonly ArtistRecoveryRewindNativeRow[];
  readonly records: readonly ArtistRecoveryRewindRecordObservation[];
}
export interface ArtistRecoveryRewindPayloadRow { readonly pointer: Address; readonly payloadType: Hex; readonly payloadHash: Hex }
export interface ArtistRecoveryRewindPayloadCatalog { readonly host: Address; readonly rows: readonly ArtistRecoveryRewindPayloadRow[] }
export interface ArtistRecoveryRewindFacts {
  readonly manifest: rewind.ArtistRecoveryRewindResolutionManifest;
  readonly selection: ArtistRecoveryRewindSelectionObservation;
  readonly context: recovery.ArtistRecoveryContext;
  readonly role: Hex;
  readonly evidence: rewind.ArtistRecoveryRewindEvidence;
  readonly notice: recovery.ArtistRecoveryNoticeEvidence | null;
  readonly association: recovery.ArtistRecoveryActionAssociation;
  readonly veto: { readonly vetoer: Address; readonly reasonHash: Hex; readonly vetoedAt: bigint };
  readonly executed: Hex;
  readonly state: rewind.ArtistRecoveryRewindEvidenceState;
  readonly acceptanceDigest: Hex;
  readonly acceptanceConsumed: boolean;
  readonly acceptanceHint: bigint;
  readonly digestDenied: boolean;
  readonly nativeCount: bigint;
  readonly payloads: readonly ArtistRecoveryRewindPayloadCatalog[];
}
export interface ArtistRecoveryRewindCapture extends Block {
  readonly deployment: ArtistRecoveryRewindDeployment;
  readonly prepared: rewind.ArtistRecoveryRewindCall;
  readonly configurationHash: Hex;
  readonly ownerSnapshot: ArtistHydrationSnapshot;
  readonly payoutSnapshot: ArtistHydrationSnapshot;
  readonly retained: readonly unknown[] | null;
  readonly selection: ArtistRecoveryRewindSelectionObservation | null;
  readonly recovery: ArtistRecoveryRewindFacts | null;
  readonly result: readonly unknown[];
  readonly captureHash: Hex;
  readonly simulationRequired: true;
}
// Every dispatch is an original V3 selector; governed methods are admitted only through their operation wrapper.
const callAbi = new Interface([...abi.fragments, ...rewind.CURRENT_ARTIST_RECOVERY_REWIND_ABI]);
async function originalCall(p: Reader, call: UnsignedCall, caller: Address, tag: number, intf = callAbi): Promise<readonly unknown[]> {
  const raw = bytes(await p.call({ ...call, from: caller, blockTag: tag }), 524288);
  const f = intf.getFunction(call.data.slice(0, 10))!;
  const decoded = intf.decodeFunctionResult(f, raw);
  equal(intf.encodeFunctionResult(f, decoded).toLowerCase(), raw, "Noncanonical original call result");
  return f.outputs.map((v, i) => plain(v, decoded[i]));
}
type EvidenceGetter = "resolutionManifestV3" | "appealEvidenceV3" | "payoutOriginalV3";
async function retained(p: Reader, d: ArtistRecoveryRewindDeployment, kind: EvidenceGetter, identity: Hex, tag: number, optional = false): Promise<any[] | null> {
  let result;
  try { result = await read(p, d.evidence.address, kind, [identity], tag, undefined, 65536); }
  catch (error) {
    const e = error as { code?: string; data?: string };
    const name = kind === "resolutionManifestV3" ? "InvalidRecoveryRewindManifest" : kind === "appealEvidenceV3" ? "InvalidRecoveryRewindAppeal" : "InvalidRecoveryPayoutOriginal";
    if (optional && e.code === "CALL_EXCEPTION" && typeof e.data === "string" && same(e.data, abi.encodeErrorResult(name, [identity]))) return null;
    throw error;
  }
  const c = coordinates(d), offset = kind === "payoutOriginalV3" ? 2 : 1;
  equal(result.slice(offset), [c.identityCodeHash, c.payoutCodeHash], "Retained evidence owner pins differ");
  const computed = kind === "resolutionManifestV3" ? rewind.artistRecoveryRewindManifestHash(c, result[0])
    : kind === "appealEvidenceV3" ? rewind.artistRecoveryRewindAppealHash(c, result[0]) : rewind.artistRecoveryRewindPayoutOriginalHash(c, result[0]);
  equal(computed, kind === "payoutOriginalV3" ? result[1] : identity, "Retained evidence hash differs");
  if (kind === "payoutOriginalV3") equal(result[0].recordHash, identity);
  return result;
}
async function nativePrefix(p: Reader, host: Address, count: bigint, tag: number): Promise<readonly ArtistRecoveryRewindNativeRow[]> {
  const length = bounded(count, 4096, "Complete native journal"), rows = [];
  const current = uint((await read(p, host, "artistNativeReceiptCount", [], tag))[0]);
  if (current < count) throw Error("Native prefix is incomplete");
  for (let i = 0; i < length; i++) {
    const [row] = await read(p, host, "artistNativeReceiptAt", [BigInt(i)], tag);
    uint(row.operation, 16); hash(row.artistId); uint(row.collectionId); hash(row.recordHash);
    rows.push(row);
  }
  return rows;
}
async function liveBasis(p: Reader, d: ArtistRecoveryRewindDeployment, manifestHash: Hex, tag: number): Promise<rewind.ArtistRecoveryRewindSelectionBasis> {
  const c = coordinates(d), manifest = (await retained(p, d, "resolutionManifestV3", manifestHash, tag))![0];
  const identity = rewind.normalizeArtistRecoveryRewindIdentityBasis((await read(p, c.identityOwner, "recoveryRewindBasisV3", [manifestHash], tag))[0]);
  equal([identity.manifestHash, identity.artistId, identity.ownerCodeHash, identity.identity], [manifestHash, manifest.artistId, c.identityCodeHash, manifest.identity]);
  const [head] = await read(p, c.identityOwner, "guardianHistoryState", [identity.artistId, 0n, ZeroAddress, ZeroHash], tag);
  equal(head, identity.guardianHistory, "Guardian checkpoint differs");
  equal((await read(p, c.identityOwner, "recoveryRewindInventoryV3", [identity.artistId], tag))[0], identity.inventory);
  const payoutInventory = (await read(p, c.payoutOwner, "payoutRewindInventoryV3", [identity.artistId], tag))[0];
  const basis = { identity, payoutCodeHash: c.payoutCodeHash, payout: manifest.payout, payoutInventory, sourceCommitment: ZeroHash as Hex };
  basis.sourceCommitment = rewind.artistRecoveryRewindSelectionSourceHash(c, basis);
  return rewind.normalizeArtistRecoveryRewindSelectionBasis(basis);
}
async function originalRecordData(p: Reader, d: ArtistRecoveryRewindDeployment, kind: bigint, artistId: Hex, recordHash: Hex, tag: number): Promise<Hex> {
  const c = coordinates(d);
  const names = ["guardianSetRecord", "successorDesignationRecord", "estateDirectiveRecord", "identityRevisionRecord", "designationRecord", "stewardSanctionGrantRecord", "standingRevocationRecord"];
  const name = names[Number(kind)]!, owner = kind === 4n ? c.payoutOwner : c.identityOwner;
  const [record] = await read(p, owner, name, [recordHash], tag);
  equal(kind === 3n ? record.artistId : kind === 4n ? record.artistId : record.terms.artistId, artistId);
  if (kind !== 4n) equal(record.recordHash, recordHash);
  const type = abi.getFunction(name)!.outputs[0]!.format("full");
  if (kind === 4n) {
    const retainedOriginal = (await retained(p, d, "payoutOriginalV3", recordHash, tag))!;
    equal(retainedOriginal[0].terms, record);
    return encoded([type, rewind.ARTIST_RECOVERY_REWIND_PAYOUT_ORIGINAL_TUPLE, "bytes32"], [record, retainedOriginal[0], retainedOriginal[1]]);
  }
  if (kind === 2n || kind === 3n) {
    const data = bytes((await read(p, owner, kind === 2n ? "estateDirectivePayload" : "identityDocumentBytes", [kind === 2n ? recordHash : record.revisedRecordHash], tag))[0], 8192);
    if (data === "0x") throw Error("Original record document missing");
    equal(keccak256(data), kind === 2n ? record.terms.directivePayloadHash : record.revisedRecordHash);
    if (kind === 3n) {
      const hashes = [1n, 3n].map(authorityClass => hashEncoded(["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
        [id("6529STREAM_ARTIST_IDENTITY_REVISION_RECORD_V1"), c.chainId, c.registry, artistId, record.previousRecordHash, record.revisedRecordHash, record.signer, authorityClass, record.nonce, record.signedAt]));
      if (hashes.filter(h => h === recordHash).length !== 1 || ![1n, 3n].includes(record.authorityClass)
        || (hashes[0] === recordHash && record.authorityClass !== 1n)) throw Error("Historical revision authority/preimage differs");
    }
    return encoded([type, "bytes"], [record, data]);
  }
  return encoded([type], [record]);
}
async function selected(p: Reader, d: ArtistRecoveryRewindDeployment, tag: number, manifestHash?: Hex, key?: Hex, live = true): Promise<ArtistRecoveryRewindSelectionObservation> {
  const c = coordinates(d);
  let basis = manifestHash && live ? await liveBasis(p, d, manifestHash, tag) : null;
  if (basis) key = rewind.artistRecoveryRewindSelectionKey(c, basis);
  const [saved, rawProgress] = await read(p, c.selectionPreparation, "selectionV3", [key!], tag);
  if (basis && saved.identity.manifestHash !== ZeroHash) equal(saved, basis, "Selection basis changed");
  basis ??= rewind.normalizeArtistRecoveryRewindSelectionBasis(saved);
  const progress = rewind.normalizeArtistRecoveryRewindSelectionProgress(rawProgress);
  const seal = rewind.normalizeArtistRecoveryRewindPreparationSeal((await read(p, c.selectionPreparation, "preparationSealV3", [key!], tag))[0]);
  if (basis.identity.manifestHash === ZeroHash) {
    equal(progress, zeros(rewind.ARTIST_RECOVERY_REWIND_SELECTION_PROGRESS_TUPLE));
    equal(seal, zeros(rewind.ARTIST_RECOVERY_REWIND_PREPARATION_SEAL_TUPLE));
    return freeze({ key: hash(key, true), basis, progress, seal, result: null, identityJournal: [], payoutJournal: [], records: [] });
  }
  equal(rewind.artistRecoveryRewindSelectionKey(c, basis), key);
  equal(rewind.artistRecoveryRewindSelectionSourceHash(c, basis), basis.sourceCommitment);
  equal([basis.identity.ownerCodeHash, basis.payoutCodeHash], [c.identityCodeHash, c.payoutCodeHash]);
  if (progress.identityProcessed > basis.identity.identity.receiptCount || progress.payoutProcessed > basis.payout.receiptCount
    || (progress.payoutProcessed !== 0n && progress.identityProcessed !== basis.identity.identity.receiptCount)) throw Error("Selection violates complete ordered prefixes");
  if (seal.commitment !== ZeroHash) {
    equal(rewind.artistRecoveryRewindPreparationSealHash(c, seal), seal.commitment);
    equal([seal.manifestHash, seal.sourceKey, seal.identityBefore, seal.payout], [basis.identity.manifestHash, key, basis.identity.identity, basis.payout]);
    if (seal.identityAfterPreparation.revision !== basis.identity.identity.snapshot.revision + 1n
      || seal.identityAfterPreparation.domainId !== domains[2] || seal.identityAfterPreparation.recordChainTip !== basis.identity.identity.snapshot.recordChainTip) throw Error("Preparation seal revision/tip differs");
    hash(seal.identityAfterPreparation.stateRoot); hash(seal.associationHash); hash(seal.actionId); hash(seal.evidenceStateHash);
  } else equal(seal, zeros(rewind.ARTIST_RECOVERY_REWIND_PREPARATION_SEAL_TUPLE));
  if (live) {
    const expected = seal.commitment === ZeroHash ? basis.identity.identity.snapshot : seal.identityAfterPreparation;
    equal((await read(p, c.identityOwner, "ownerStateSnapshotV2", [], tag))[0], expected, "Identity source snapshot changed");
    equal((await read(p, c.payoutOwner, "ownerStateSnapshotV2", [], tag))[0], basis.payout.snapshot, "Payout source snapshot changed");
    equal((await read(p, c.identityOwner, "artistNativeReceiptCount", [], tag))[0], basis.identity.identity.receiptCount);
    equal((await read(p, c.payoutOwner, "artistNativeReceiptCount", [], tag))[0], basis.payout.receiptCount);
  }
  const identityJournal = await nativePrefix(p, c.identityOwner, basis.identity.identity.receiptCount, tag);
  const payoutJournal = await nativePrefix(p, c.payoutOwner, basis.payout.receiptCount, tag);
  // Authenticate the entire guardian checkpoint chain against its native rows, including unselected memberships.
  const guardianData = new Map<Hex, Hex>();
  let checkpoint = ZeroHash as Hex, guardianRevision = 0n, guardians = 0n;
  for (const row of identityJournal) {
    if (row.artistId !== basis.identity.artistId || row.operation !== 28n) continue;
    guardians++;
    const [head, entry] = await read(p, c.identityOwner, "guardianHistoryState", [basis.identity.artistId, guardians, ZeroAddress, ZeroHash], tag);
    if (live) equal(head, basis.identity.guardianHistory);
    else if (head.count < basis.identity.guardianHistory.count) throw Error("Guardian history prefix is incomplete");
    equal([entry.artistId, entry.index, entry.recordHash, entry.previousCommitment, row.collectionId], [basis.identity.artistId, guardians, row.recordHash, checkpoint, 0n]);
    if (entry.ownerRevision <= guardianRevision || entry.ownerRevision > basis.identity.identity.snapshot.revision) throw Error("Guardian checkpoint revision differs");
    const expected = hashEncoded(["bytes32", "uint256", "address", "address", "bytes32", "uint64", "uint64", "bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1"), c.chainId, c.registry, c.identityOwner, entry.artistId, entry.index, entry.ownerRevision, entry.recordHash, entry.recordDataHash, entry.previousCommitment]);
    equal(entry.commitment, expected); guardianData.set(entry.recordHash, entry.recordDataHash); checkpoint = expected; guardianRevision = entry.ownerRevision;
  }
  equal([guardians, guardianRevision, checkpoint], [basis.identity.guardianHistory.count, basis.identity.guardianHistory.ownerRevision, basis.identity.guardianHistory.commitment]);
  let result: rewind.ArtistRecoveryRewindSelectionResult | null = null;
  const records: ArtistRecoveryRewindRecordObservation[] = [];
  if (progress.complete) {
    result = rewind.normalizeArtistRecoveryRewindSelectionResult((await read(p, c.selectionPreparation, "selectionResultV3", [key!], tag, undefined, 65536))[0]);
    const manifest = (await retained(p, d, "resolutionManifestV3", basis.identity.manifestHash, tag))![0];
    equal([progress.identityProcessed, progress.payoutProcessed, progress.guardiansProcessed, progress.seenExclusions],
      [basis.identity.identity.receiptCount, basis.payout.receiptCount, basis.identity.guardianHistory.count, (1n << BigInt(manifest.supersededRecords.length)) - 1n]);
    equal([result.sourceKey, result.manifestHash, result.sourceCommitment, result.inventoryCommitment, result.commitment],
      [key, basis.identity.manifestHash, basis.sourceCommitment, rewind.artistRecoveryRewindSelectionInventoryHash(c, basis.identity.inventory, basis.payoutInventory), progress.resultCommitment]);
    rewind.validateArtistRecoveryRewindSelection(c, manifest, basis, progress, result);
    equal(rewind.artistRecoveryRewindSelectionResultHash(c, result), result.commitment); hash(result.commitment);
    equal(rewind.artistRecoveryRewindGuardianResultHash(c, basis.identity.guardianHistory, result.guardians), result.guardians.commitment);
    const operations = [28n, 36n, 37n, 25n, 18n, 19n, 51n];
    for (const [journal, payout] of [[identityJournal, false], [payoutJournal, true]] as const) {
      for (let i = 0; i < journal.length; i++) {
        const row = journal[i]!, kind = operations.indexOf(row.operation);
        if (row.artistId !== basis.identity.artistId || kind < 0 || (payout ? kind !== 4 : kind === 4)) continue;
        const [actualKind, record, retained, eligible] = await read(p, c.selectionPreparation, "selectionRecordV3", [key!, row.recordHash], tag);
        equal([actualKind, record.recordHash, record.nativeIndex, row.collectionId], [BigInt(kind), row.recordHash, BigInt(i), 0n]);
        hash(record.originalDataHash); hash(record.admissionProof);
        if (actualKind === 0n) equal(guardianData.get(row.recordHash), record.originalDataHash, "Guardian checkpoint record bytes differ");
        if (records.some(x => x.record.recordHash === row.recordHash)) throw Error("Duplicate selected native record");
        const originalData = await originalRecordData(p, d, actualKind, basis.identity.artistId, row.recordHash, tag);
        equal(keccak256(originalData), record.originalDataHash, "Original selected record bytes differ");
        const observedStatus = actualKind === 4n ? (await read(p, c.payoutOwner, "payoutRecoveryRecordStatusV3", [row.recordHash], tag))[0]
          : (await read(p, c.identityOwner, "recoveryRecordStatusV3", [actualKind, row.recordHash], tag))[0];
        if (observedStatus.recoveryRecordHash === ZeroHash) equal(observedStatus, zeros(rewind.ARTIST_RECOVERY_REWIND_STATUS_TUPLE));
        else {
          equal([observedStatus.artistId, observedStatus.kind], [basis.identity.artistId, actualKind]);
          hash(observedStatus.actionId);
          if (actualKind !== 0n) hash(observedStatus.planCommitment);
        }
        records.push({ kind: actualKind, record, retained, eligible, originalData, observedStatus });
      }
    }
    for (const ref of manifest.supersededRecords) {
      const row = records.find(x => x.record.recordHash === ref.recordHash);
      if (!row || row.kind !== ref.kind || row.retained) throw Error("Typed exclusions do not partition the complete selection");
    }
    for (const [kind, family] of [[1n, result.designation], [2n, result.directive], [3n, result.identityRevision], [4n, result.payout], [5n, result.sanctionGrant]] as const) {
      if (family.operative.recordHash !== ZeroHash) {
        const row = records.find(x => x.record.recordHash === family.operative.recordHash);
        if (!row || row.kind !== kind || !row.retained || !row.eligible) throw Error("Operative selection is not retained and eligible");
        equal(row.record, family.operative);
      } else equal(family.operative, zeros(rewind.ARTIST_RECOVERY_REWIND_SELECTED_RECORD_TUPLE));
      if (family.retainedCandidateRecordHash !== ZeroHash) {
        const row = records.find(x => x.record.recordHash === family.retainedCandidateRecordHash);
        if (!row || row.kind !== kind || !row.retained || row.eligible) throw Error("Candidate occupancy differs");
      }
    }
    if (result.guardians.selectedRecordHash !== ZeroHash) {
      const row = records.find(x => x.record.recordHash === result!.guardians.selectedRecordHash);
      if (!row || row.kind !== 0n || !row.retained || !row.eligible) throw Error("Guardian selection record differs");
      equal([row.record.originalDataHash, row.record.nonce], [result.guardians.selectedDataHash, result.guardians.selectedNonce]);
    }
    if (live) equal((await read(p, c.selectionPreparation, "requireSelectionV3", [basis.identity.manifestHash], tag, undefined, 65536))[0], result);
  }
  return freeze({ key: hash(key), basis, progress, result, seal, identityJournal, payoutJournal, records });
}
async function notice(p: Reader, c: rewind.ArtistRecoveryRewindCoordinates, causeHash: Hex, tag: number): Promise<recovery.ArtistRecoveryNoticeEvidence | null> {
  const [cause] = await read(p, c.identityOwner, "identityContestCause", [causeHash], tag);
  equal(cause.causeHash, causeHash);
  if (cause.facts.priorStatus !== 2n) return null;
  const [noticeHash, phase, terminalHash] = await read(p, c.identityOwner, "dormancyResolutionState", [cause.facts.artistId, causeHash], tag);
  const [n, observedPhase, terminal] = await read(p, c.identityOwner, "dormancyRecord", [noticeHash], tag);
  if (!same(n.recordHash, hash(noticeHash)) || !same(n.terms.artistId, cause.facts.artistId)
    || phase !== observedPhase || ![1n, 2n].includes(phase) || !same(terminal.recordHash, terminalHash)) throw Error("Current notice provenance differs");
  if (phase === 1n) equal(terminal, zeros(recovery.ARTIST_RECOVERY_TERMINAL_TUPLE));
  return recovery.normalizeArtistRecoveryNoticeEvidence({ cause, notice: n, phase, terminal });
}
function replayKey(c: rewind.ArtistRecoveryRewindCoordinates, surface: string, scope: Hex): Hex {
  return hashEncoded(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), c.chainId, c.registry, c.coordinator, c.archive, c.identityOwner, domains[2], id(surface), scope]);
}
async function appealAuthority(p: Reader, d: ArtistRecoveryRewindDeployment, tag: number): Promise<recovery.ArtistRecoveryAppealAuthority> {
  const executor = d.governance.address, roles = d.artist.components[11]!.address;
  equal((await read(p, roles, "owner", [], tag))[0], executor);
  const [root, rootCodeHash, rootRevision] = await read(p, executor, "governanceRootState", [], tag);
  await runtime(p, { address: address(root), codeHash: hash(rootCodeHash) }, tag);
  equal((await read(p, executor, "owner", [], tag))[0], root);
  if (!rootRevision || (await read(p, roles, "hasRole", [recovery.ARTIST_RECOVERY_APPEAL_ROLE, root], tag))[0] !== true) throw Error("Canonical APPEAL root unavailable");
  const [roleMutationHash, roleRevision] = await read(p, roles, "roleMutationState", [recovery.ARTIST_RECOVERY_APPEAL_ROLE], tag);
  hash(roleMutationHash); if (!roleRevision) throw Error("APPEAL role has no revision");
  return { executor, roles, root, rootCodeHash, rootRevision, roleMutationHash, roleRevision };
}
async function catalogs(p: Reader, c: rewind.ArtistRecoveryRewindCoordinates, tag: number): Promise<ArtistRecoveryRewindPayloadCatalog[]> {
  const result = [];
  for (const host of [c.identityOwner, c.archive]) {
    const count = bounded((await read(p, host, "storedPayloadCount", [], tag))[0], 1024, "Payload catalog"), rows = [];
    const seen = new Set<string>();
    for (let i = 0; i < count; i++) {
      const [pointer, payloadType, payloadHash] = await read(p, host, "storedPayloadAt", [BigInt(i)], tag);
      const code = bytes(await p.getCode(address(pointer), tag), 24576);
      if (!code.startsWith("0x00") || !same(keccak256(`0x${code.slice(4)}`), payloadHash)) throw Error("Payload carrier differs");
      const key = `${payloadType}:${payloadHash}`;
      if (seen.has(key)) throw Error("Duplicate payload catalog key"); seen.add(key);
      rows.push({ pointer: address(pointer), payloadType: hash(payloadType), payloadHash: hash(payloadHash) });
    }
    result.push({ host, rows });
  }
  const archive = new Set(result[1]!.rows.map(r => `${r.payloadType}:${r.payloadHash}`));
  if (result[0]!.rows.some(r => !archive.has(`${r.payloadType}:${r.payloadHash}`))) throw Error("Payload sync incomplete");
  return result;
}
async function recoveryFacts(p: Reader, d: ArtistRecoveryRewindDeployment, input: Extract<rewind.ArtistRecoveryRewindInput, { request: recovery.ArtistRecoveryRequest }>, tag: number): Promise<ArtistRecoveryRewindFacts> {
  const c = coordinates(d), request = input.request, acceptance = input.acceptance;
  const manifest = (await retained(p, d, "resolutionManifestV3", input.manifestHash, tag))![0];
  equal(manifest.requestCommitment, recovery.artistRecoveryRequestCommitment(request));
  equal(manifest.artistId, request.artistId);
  const selection = await selected(p, d, tag, input.manifestHash);
  if (!selection.result) throw Error("Complete original selection is required");
  const ctx = recovery.normalizeArtistRecoveryContext((await read(p, c.registry, "identityRecoveryContextV3", [request, acceptance, input.manifestHash], tag))[0]);
  equal(ctx.scopeHash, rewind.artistRecoveryRewindScopeHash(c, request.artistId));
  equal(ctx.newValueHash, rewind.artistRecoveryRewindIntentHash(ctx, request, acceptance));
  const cross = { payout: selection.basis.payout, payoutInventory: selection.basis.payoutInventory, selection: selection.result };
  const [role] = await read(p, c.identityOwner, "guardianRecoveryAuthorityRoleV3", [request, acceptance, input.manifestHash, cross], tag);
  if (![recovery.ARTIST_RECOVERY_ARBITER_ROLE, recovery.ARTIST_RECOVERY_APPEAL_ROLE].includes(role)) throw Error("Unknown original recovery role");
  let appeal = zeros(rewind.ARTIST_RECOVERY_REWIND_APPEAL_DOCUMENT_TUPLE), authority = zeros(recovery.ARTIST_RECOVERY_APPEAL_AUTHORITY_TUPLE);
  if (role === recovery.ARTIST_RECOVERY_APPEAL_ROLE) {
    appeal = (await retained(p, d, "appealEvidenceV3", request.evidenceHash, tag))![0];
    equal(appeal.resolutionManifestHash, input.manifestHash);
    authority = await appealAuthority(p, d, tag);
  }
  const [association, veto, executed] = await read(p, c.identityOwner, "identityRecoveryActionState", [request.artistId, "actionId" in input ? input.actionId : ZeroHash], tag);
  const [state] = await read(p, c.identityOwner, "identityRecoveryEvidenceStateV3", [request.artistId, association.action.actionId], tag);
  const [consumed, hint] = await read(p, c.identityOwner, "rotationAcceptanceNonceState", [request.artistId, request.newAddress, acceptance.nonce], tag);
  const acceptanceDigest = recovery.artistRecoveryAcceptancePayload(c.chainId, c.registry, request, ctx.incumbent, acceptance).digest;
  const [denied] = await read(p, c.identityOwner, "replayCell", [replayKey(c, "identity_authority.replay.digest_revocation", hashEncoded(["bytes32", "bytes32"], [request.artistId, acceptanceDigest]))], tag);
  return freeze({ manifest, selection, context: ctx, role, evidence: { manifestHash: input.manifestHash, manifest, appeal, appealAuthority: authority, facts: cross },
    notice: await notice(p, c, request.expectedCauseHash, tag), association, veto, executed, state,
    acceptanceDigest, acceptanceConsumed: consumed, acceptanceHint: hint, digestDenied: denied.status !== 0n,
    nativeCount: uint((await read(p, c.identityOwner, "artistNativeReceiptCount", [], tag))[0]), payloads: await catalogs(p, c, tag) });
}
/** Pinned original reads and exact caller simulation. Private ancestry admission remains the original contracts' responsibility. */
export async function captureArtistRecoveryRewind(p: Reader, rawDeployment: ArtistRecoveryRewindDeployment, rawCall: rewind.ArtistRecoveryRewindCall, options: { readonly blockTag: number }): Promise<ArtistRecoveryRewindCapture> {
  const d = deployment(rawDeployment), prepared = rewind.normalizeArtistRecoveryRewindCall(rawCall);
  equal(prepared.coordinates, coordinates(d)); keys(options, ["blockTag"]); const tag = number(options.blockTag), input = prepared.input;
  if (prepared.protocolOnly || input.kind === "recoverArtistIdentityV3") throw Error("Recovery executes through the prepared Governance operation");
  if (input.kind === "continueSelectionV3" && input.maximumRecords > 64n) throw Error("Selection chunk exceeds64 records");
  const h = await context(p, d, tag, input.kind === "registerIdentityRecoveryActionV3");
  const [ownerSnapshot] = await read(p, prepared.coordinates.identityOwner, "ownerStateSnapshotV2", [], tag);
  const [payoutSnapshot] = await read(p, prepared.coordinates.payoutOwner, "ownerStateSnapshotV2", [], tag);
  let saved = null, selection = null, facts = null;
  if (input.kind === "publishResolutionManifestV3" || input.kind === "publishAppealV3" || input.kind === "publishPayoutOriginalV3") {
    const getter = input.kind === "publishResolutionManifestV3" ? "resolutionManifestV3" : input.kind === "publishAppealV3" ? "appealEvidenceV3" : "payoutOriginalV3";
    const identity = input.kind === "publishPayoutOriginalV3" ? input.original.recordHash : prepared.expectedReturnHash!;
    saved = await retained(p, d, getter, identity, tag, true);
  } else if (input.kind === "beginSelectionV3" || input.kind === "requireSelectionV3") {
    saved = await retained(p, d, "resolutionManifestV3", input.manifestHash, tag);
    selection = await selected(p, d, tag, input.manifestHash);
  } else if (["continueSelectionV3", "selectionV3", "selectionResultV3", "selectionRecordV3", "retainedMemberV3", "preparationSealV3"].includes(input.kind)) {
    const key = (input as { key: Hex }).key;
    selection = await selected(p, d, tag, undefined, key, false);
    if (input.kind === "continueSelectionV3") {
      saved = await retained(p, d, "resolutionManifestV3", selection.basis.identity.manifestHash, tag);
      selection = await selected(p, d, tag, selection.basis.identity.manifestHash);
    }
  } else if (input.kind === "identityRecoveryContextV3" || input.kind === "registerIdentityRecoveryActionV3") {
    facts = await recoveryFacts(p, d, input, tag);
  }
  const result = await originalCall(p, prepared.call, prepared.caller, tag);
  if (prepared.expectedReturnHash) equal(result[0], prepared.expectedReturnHash);
  if (input.kind === "beginSelectionV3") equal(result[0], selection!.key);
  if (input.kind === "identityRecoveryContextV3") equal(result[0], facts!.context);
  if (input.kind === "continueSelectionV3") {
    const before = selection!, after = rewind.normalizeArtistRecoveryRewindSelectionProgress(result[0] as rewind.ArtistRecoveryRewindSelectionProgress);
    const identityRemaining = before.basis.identity.identity.receiptCount - before.progress.identityProcessed;
    const identityStep = identityRemaining < input.maximumRecords ? identityRemaining : input.maximumRecords;
    const payoutRemaining = before.basis.payout.receiptCount - before.progress.payoutProcessed;
    const budget = input.maximumRecords - identityStep, payoutStep = payoutRemaining < budget ? payoutRemaining : budget;
    if (before.progress.complete) equal(after, before.progress);
    else if (after.identityProcessed !== before.progress.identityProcessed + identityStep
      || after.payoutProcessed !== before.progress.payoutProcessed + payoutStep
      || after.complete !== (identityRemaining === identityStep && payoutRemaining === payoutStep)) throw Error("Selection progress return differs");
  }
  await unchanged(p, h);
  const body = { ...h, deployment: d, prepared, ownerSnapshot, payoutSnapshot, retained: saved, selection, recovery: facts, result, simulationRequired: true as const };
  return freeze({ ...body, captureHash: digest(body) });
}
function savedCapture(raw: ArtistRecoveryRewindCapture): ArtistRecoveryRewindCapture {
  const copy = structuredClone(raw), { captureHash, ...body } = copy;
  keys(copy, ["blockNumber", "blockHash", "timestamp", "configurationHash", "deployment", "prepared", "ownerSnapshot", "payoutSnapshot", "retained", "selection", "recovery", "result", "simulationRequired", "captureHash"]);
  if (copy.simulationRequired !== true || !same(hash(captureHash), digest(body))) throw Error("Capture changed");
  deployment(copy.deployment); rewind.normalizeArtistRecoveryRewindCall(copy.prepared);
  number(copy.blockNumber); hash(copy.blockHash); uint(copy.timestamp, 64);
  return freeze(copy);
}
async function historical(p: Reader, c: ArtistRecoveryRewindCapture): Promise<void> {
  equal(await captureArtistRecoveryRewind(p, c.deployment, c.prepared, { blockTag: c.blockNumber }), c, "Historical capture changed");
}
export async function simulateArtistRecoveryRewind(p: Reader, raw: ArtistRecoveryRewindCapture, options: { readonly blockTag: number }): Promise<ArtistRecoveryRewindCapture> {
  const c = savedCapture(raw); keys(options, ["blockTag"]); const tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  await historical(p, c);
  return captureArtistRecoveryRewind(p, c.deployment, c.prepared, { blockTag: tag });
}
export interface ArtistRecoveryRewindGovernance {
  readonly capture: ArtistRecoveryRewindCapture;
  readonly proposer: Address;
  readonly batch: rewind.ArtistRecoveryRewindGovernanceBatch;
}
export interface ArtistRecoveryRewindOperation {
  readonly prepared: ArtistRecoveryRewindGovernance;
  readonly stage: "publish" | "schedule" | "register" | "execute";
  readonly caller: Address;
  readonly call: UnsignedCall;
}
export function prepareArtistRecoveryRewindGovernance(raw: ArtistRecoveryRewindCapture, proposer: Address, nonce: bigint, window: recovery.ArtistRecoveryGovernanceWindow): ArtistRecoveryRewindGovernance {
  const c = savedCapture(raw), input = c.prepared.input;
  if (input.kind !== "identityRecoveryContextV3" || !c.recovery) throw Error("Governance requires the complete context capture");
  const batch = rewind.artistRecoveryRewindGovernanceBatch(coordinates(c.deployment), input.request, input.acceptance, input.manifestHash,
    c.recovery.context, c.deployment.governance.address, nonce, window);
  return freeze({ capture: c, proposer: address(proposer), batch });
}
export function prepareArtistRecoveryRewindOperation(raw: ArtistRecoveryRewindGovernance, stage: ArtistRecoveryRewindOperation["stage"], caller: Address): ArtistRecoveryRewindOperation {
  keys(raw, ["capture", "proposer", "batch"]);
  const prepared = prepareArtistRecoveryRewindGovernance(raw.capture, raw.proposer, raw.batch.nonce, raw.batch.window);
  equal(prepared, raw); const actor = address(caller), b = prepared.batch;
  if (!["publish", "schedule", "register", "execute"].includes(stage)) throw Error("Unknown governance stage");
  if (stage === "schedule" && actor !== prepared.proposer) throw Error("Schedule caller differs from proposer");
  const call = stage === "publish" ? b.publicationCall : stage === "schedule" ? b.scheduleCall : stage === "execute" ? b.executionCall
    : rewind.prepareArtistRecoveryRewindCall(b.coordinates, actor, { kind: "registerIdentityRecoveryActionV3", actionId: b.actionId,
      calls: [b.governanceCall], request: b.request, acceptance: b.acceptance, manifestHash: b.manifestHash }).call;
  return freeze({ prepared, stage, caller: actor, call });
}
function operation(raw: ArtistRecoveryRewindOperation): ArtistRecoveryRewindOperation {
  keys(raw, ["prepared", "stage", "caller", "call"]);
  const value = prepareArtistRecoveryRewindOperation(raw.prepared, raw.stage, raw.caller); equal(value, raw); return value;
}
async function governance(p: Reader, o: ArtistRecoveryRewindOperation, tag: number) {
  const d = o.prepared.capture.deployment, g = d.governance.address;
  const state = await read(p, g, "systemManifestBootstrapState", [], tag);
  if (state[0] !== true || state[1] !== true) throw Error("Only sealed ordinary governance is supported");
  const policy = await read(p, g, "governanceActionPolicyState", [], tag);
  hash(policy[0]); hash(policy[1]); if (!policy[2]) throw Error("Governance catalog missing");
  const [delay] = await read(p, g, "minimumDelay", [2n], tag);
  if (delay < 259200n) throw Error("Original recovery delay below72 hours");
  return { candidateProfileHash: policy[0] as Hex, catalogHash: policy[1] as Hex, minimumDelay: delay as bigint };
}
async function publication(p: Reader, b: rewind.ArtistRecoveryRewindGovernanceBatch, tag: number): Promise<Address | null> {
  const [ptr] = await read(p, b.executor, "publishedCallData", [b.publicationKey], tag);
  if (ptr === ZeroAddress) return null;
  const pointer = address(ptr), expected = encoded(["bytes[]"], [[b.targetCall.data]]);
  equal(bytes(await p.getCode(pointer, tag), 24576), `0x00${expected.slice(2)}`);
  return pointer;
}
async function action(p: Reader, o: ArtistRecoveryRewindOperation, tag: number) {
  const b = o.prepared.batch, [a] = await read(p, b.executor, "governanceAction", [b.actionId], tag);
  const expected = { actionClass: 2n, target: b.targetCall.to, value: 0n, selector: b.governanceCall.selector, callHash: b.callsHash,
    scopeHash: b.scopeHash, oldValueHash: b.oldValueHash, newValueHash: b.newValueHash, notBefore: b.window.notBefore,
    expiresAfter: b.window.expiresAfter, proposer: o.prepared.proposer, reasonHash: b.window.reasonHash,
    reasonURI: b.window.reasonURI, manifestHash: b.window.manifestHash };
  for (const [key, value] of Object.entries(expected)) equal(a[key], value, `Scheduled ${key} differs`);
  equal((await read(p, b.executor, "scheduledCallData", [b.actionId], tag))[0], [b.targetCall.data]);
  const pointer = await publication(p, b, tag);
  if (!pointer) throw Error("Scheduled call publication missing");
  equal((await read(p, b.executor, "scheduledCallDataPointer", [b.actionId], tag))[0], pointer);
  return a;
}
async function proposerRole(p: Reader, o: ArtistRecoveryRewindOperation, tag: number): Promise<void> {
  const d = o.prepared.capture.deployment, f = o.prepared.capture.recovery!;
  if (f.role === recovery.ARTIST_RECOVERY_APPEAL_ROLE) {
    equal((await appealAuthority(p, d, tag)).root, o.prepared.proposer, "APPEAL requires actual root proposer");
  } else if ((await read(p, d.artist.components[11]!.address, "hasRole", [f.role, o.prepared.proposer], tag))[0] !== true) {
    throw Error("Proposer lacks original recovery role");
  }
  const [commitment, revision] = await read(p, d.artist.components[11]!.address, "roleMutationState", [f.role], tag);
  hash(commitment); if (!revision) throw Error("Role mutation revision missing");
}
export interface ArtistRecoveryRewindSimulation extends Block {
  readonly operation: ArtistRecoveryRewindOperation;
  readonly facts: ArtistRecoveryRewindFacts | null;
  readonly result: readonly unknown[];
  readonly catalog: { readonly candidateProfileHash: Hex; readonly catalogHash: Hex; readonly minimumDelay: bigint };
}
/** The original governance call establishes selected-row, guardian, signature and private ancestry admission. */
export async function simulateArtistRecoveryRewindOperation(p: Reader, raw: ArtistRecoveryRewindOperation, options: { readonly blockTag: number }): Promise<ArtistRecoveryRewindSimulation> {
  const o = operation(raw), c = o.prepared.capture, b = o.prepared.batch;
  keys(options, ["blockTag"]); const tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  await historical(p, c);
  const h = await context(p, c.deployment, tag, o.stage === "register" || o.stage === "execute");
  const catalog = await governance(p, o, tag);
  let facts: ArtistRecoveryRewindFacts | null = null;
  if (o.stage !== "publish") {
    facts = await recoveryFacts(p, c.deployment, { kind: "identityRecoveryContextV3", request: b.request, acceptance: b.acceptance, manifestHash: b.manifestHash }, tag);
    equal(facts.context, b.context, "Scheduled recovery context changed; prepare a new action");
    equal(facts.evidence, c.recovery!.evidence, "Scheduled evidence changed");
    await proposerRole(p, o, tag);
  }
  if (o.stage === "schedule") {
    if ((await read(p, b.executor, "isProposer", [o.caller], tag))[0] !== true) throw Error("Caller is not an ordinary proposer");
    equal((await read(p, b.executor, "governanceNonce", [], tag))[0], b.nonce);
    if (!await publication(p, b, tag)) throw Error("Publish original call bytes before scheduling");
    if (h.timestamp > (1n << 64n) - 1n - 31536000n || b.window.notBefore < h.timestamp + catalog.minimumDelay
      || b.window.expiresAfter > h.timestamp + 31536000n) throw Error("Original scheduling window differs");
  }
  if (o.stage === "register" || o.stage === "execute") {
    const a = await action(p, o, tag);
    if (a.status !== 1n) throw Error("Action is not scheduled");
    if (o.stage === "register") {
      recovery.assertArtistRecoveryRegistrationWindow(b.acceptance, b.window, h.timestamp, catalog.minimumDelay);
    } else {
      if (h.timestamp < b.window.notBefore || h.timestamp > b.window.expiresAfter || h.timestamp > b.acceptance.time) throw Error("Execution outside original deadline/window");
      const f = facts!;
      if (f.association.associationHash === ZeroHash || f.veto.vetoer !== ZeroAddress || f.executed !== ZeroHash
        || f.state.manifestHash !== b.manifestHash || f.state.associationHash !== f.association.associationHash
        || f.association.action.actionId !== b.actionId || f.state.sources.identityBefore.snapshot.revision !== f.manifest.identity.snapshot.revision
        || f.association.ownerRevision !== f.manifest.identity.snapshot.revision + 1n) throw Error("Recovery registration is missing/stale/terminal");
      const [snapshot] = await read(p, b.coordinates.identityOwner, "ownerStateSnapshotV2", [], tag);
      if (snapshot.revision !== f.association.ownerRevision) throw Error("Owner changed after registration");
      if (f.acceptanceConsumed || f.digestDenied || (b.executor === b.request.newAddress && b.acceptance.signature === "0x" && b.acceptance.nonce !== f.acceptanceHint)) throw Error("New-side acceptance replay/nonce differs");
    }
  }
  const intf = o.stage === "register" ? callAbi : new Interface(recovery.CURRENT_ARTIST_RECOVERY_GOVERNANCE_ABI);
  const result = await originalCall(p, o.call, o.caller, tag, intf);
  if (o.stage === "schedule") equal(result[0], b.actionId);
  if (o.stage === "publish") {
    const pointer = await publication(p, b, tag);
    if (pointer) equal(result[0], pointer);
    else address(result[0]);
  }
  if (o.stage === "register") hash(result[0]);
  await unchanged(p, h);
  return freeze({ ...h, operation: o, facts, result, catalog });
}

export interface ArtistRecoveryRewindEventReference {
  readonly address: Address; readonly event: string; readonly logIndex: number;
  readonly transactionHash: Hex; readonly blockHash: Hex;
}
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safePlain = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
interface Log { address: Address; topics: Hex[]; data: Hex; index: number }
interface ReceiptOptions { readonly transactionHash: Hex; readonly execution: "direct" | "safe" }
async function mined(p: ReceiptReader, d: ArtistRecoveryRewindDeployment, caller: Address, call: UnsignedCall, before: number,
  options: ReceiptOptions) {
  const transactionHash = options.transactionHash, execution = options.execution;
  const [r, tx] = await Promise.all([p.getTransactionReceipt(transactionHash), p.getTransaction(transactionHash)]);
  if (!r || !tx || r.status !== 1 || !same(r.hash, transactionHash) || !same(tx.hash, transactionHash)
    || tx.chainId !== d.artist.chainId || tx.value !== (execution === "direct" ? call.value : 0n) || r.blockNumber <= before || tx.blockNumber !== r.blockNumber
    || !same(tx.blockHash, r.blockHash) || !same(tx.to, r.to) || !same(tx.from, r.from)) throw Error("Receipt/transaction identity or chronology differs");
  const data = bytes(tx.data, 524288);
  if (execution === "direct") {
    if (!same(tx.from, caller) || !same(tx.to, call.to) || !same(data, call.data)) throw Error("Direct call differs");
  } else {
    const decoded = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(tx.to, caller) || !same(safeAbi.encodeFunctionData("execTransaction", decoded), data)
      || !same(decoded[0], call.to) || decoded[1] !== call.value || !same(decoded[2], call.data) || decoded[3] !== 0n) throw Error("Safe requires exact ordinary CALL");
  }
  const tag = number(r.blockNumber), h = await context(p, d, tag, false);
  if (!same(h.blockHash, r.blockHash)) throw Error("Receipt block differs");
  if (!Array.isArray(r.logs) || r.logs.length > 256) throw Error("Receipt exceeds256 logs");
  const logs: Log[] = r.logs.map(l => {
    if (l.removed || !same(l.transactionHash, transactionHash) || l.blockNumber !== tag || !same(l.blockHash, h.blockHash)
      || !Array.isArray(l.topics) || l.topics.length > 4) throw Error("Malformed receipt log identity");
    return { address: address(l.address), topics: l.topics.map((x: string) => hash(x, true)), data: bytes(l.data, 65536), index: number(l.index) };
  });
  if (logs.some((l, n) => n > 0 && l.index <= logs[n - 1]!.index)) throw Error("Duplicate/unordered receipt logs");
  const refs: ArtistRecoveryRewindEventReference[] = [];
  const found = (target: Address, name: string, iface = abi) => {
    const f = iface.getEvent(name)!;
    return logs.filter(l => same(l.address, target) && same(l.topics[0], f.topicHash)).map(log => {
      const args = iface.decodeEventLog(f, log.data, log.topics), encoded = iface.encodeEventLog(f, args);
      if (!same(encoded.data, log.data)) throw Error(`Noncanonical ${name} event data`);
      equal(encoded.topics.map(v => v.toLowerCase()), log.topics, `Noncanonical ${name} topics`);
      return { log, args };
    });
  };
  const reference = (log: Log, name: string) => {
    refs.push({ address: log.address, event: name, logIndex: log.index, transactionHash, blockHash: h.blockHash });
  };
  const one = (target: Address, name: string, expected: readonly unknown[]) => {
    const list = found(target, name);
    if (list.length !== 1) throw Error(`Expected exactly one ${name}`);
    const encoded = abi.encodeEventLog(abi.getEvent(name)!, expected);
    if (!same(encoded.data, list[0]!.log.data)) throw Error(`${name} fields differ`);
    equal(encoded.topics.map(v => v.toLowerCase()), list[0]!.log.topics, `${name} indexed fields differ`);
    reference(list[0]!.log, name);
    return list[0]!.log.index;
  };
  const finish = async () => {
    if (execution === "safe") {
      const successes = logs.filter(l => same(l.address, caller) && same(l.topics[0], safePlain.getEvent("ExecutionSuccess")!.topicHash));
      if (successes.length !== 1 || logs.some(l => same(l.address, caller) && same(l.topics[0], safePlain.getEvent("ExecutionFailure")!.topicHash))) throw Error("Safe requires one success and no failure");
      const log = successes[0]!, iface = log.topics.length === 2 ? safeIndexed : safePlain;
      const parsed = found(caller, "ExecutionSuccess", iface);
      hash(parsed[0]!.args[0]);
      if (refs.some(v => v.logIndex >= log.index)) throw Error("Safe success must follow protocol events");
      reference(log, "ExecutionSuccess");
    }
    await unchanged(p, h);
    return refs.sort((a, b) => a.logIndex - b.logIndex);
  };
  return { tag, h, transactionHash, found, reference, one, finish };
}
function receiptOptions(v: ReceiptOptions): ReceiptOptions {
  keys(v, ["transactionHash", "execution"]);
  if (v.execution !== "direct" && v.execution !== "safe") throw Error("Unsupported receipt execution");
  return freeze({ transactionHash: hash(v.transactionHash), execution: v.execution });
}

export interface ArtistRecoveryRewindReceipt extends Block {
  readonly capture: ArtistRecoveryRewindCapture;
  readonly transactionHash: Hex;
  readonly events: readonly ArtistRecoveryRewindEventReference[];
  readonly retained: readonly unknown[] | null;
  readonly selection: ArtistRecoveryRewindSelectionObservation | null;
  readonly attribution: "exact original event or prior-block reuse proof";
}
/** Publisher and selection writes only. Selection progress reconciliation requires the observed exact step. */
export async function inspectArtistRecoveryRewindReceipt(p: ReceiptReader, raw: ArtistRecoveryRewindCapture, supplied: ReceiptOptions): Promise<ArtistRecoveryRewindReceipt> {
  const c = savedCapture(raw), options = receiptOptions(supplied), input = c.prepared.input, d = c.deployment;
  if (!["publishResolutionManifestV3", "publishAppealV3", "publishPayoutOriginalV3", "beginSelectionV3", "continueSelectionV3"].includes(input.kind)) throw Error("This receipt helper covers evidence and selection writes");
  await historical(p, c);
  const m = await mined(p, d, c.prepared.caller, c.prepared.call, c.blockNumber, options), { tag, h } = m;
  let saved = null, selection = null;
  const prior = await context(p, d, tag - 1, false), env = coordinates(d);
  if (input.kind === "publishResolutionManifestV3" || input.kind === "publishAppealV3" || input.kind === "publishPayoutOriginalV3") {
    const getter = input.kind === "publishResolutionManifestV3" ? "resolutionManifestV3" : input.kind === "publishAppealV3" ? "appealEvidenceV3" : "payoutOriginalV3";
    const identity = input.kind === "publishPayoutOriginalV3" ? input.original.recordHash : c.prepared.expectedReturnHash!;
    saved = await retained(p, d, getter, identity, tag);
    equal(saved![0], input.kind === "publishResolutionManifestV3" ? input.manifest : input.kind === "publishAppealV3" ? input.document : input.original);
    const before = await retained(p, d, getter, identity, tag - 1, true);
    const event = input.kind === "publishResolutionManifestV3" ? "RecoveryRewindManifestPublished" : input.kind === "publishAppealV3" ? "RecoveryRewindAppealPublished" : "RecoveryPayoutOriginalPublished";
    if (before) {
      if (m.found(d.evidence.address, event).length) throw Error("Retained evidence retry emitted a new publication");
      equal(before, saved);
    } else if (input.kind === "publishResolutionManifestV3") {
      m.one(d.evidence.address, event, [identity, input.manifest.artistId, input.manifest.causeHash, env.identityCodeHash, env.payoutCodeHash]);
    } else if (input.kind === "publishAppealV3") {
      m.one(d.evidence.address, event, [identity, input.document.resolutionManifestHash, env.identityCodeHash, env.payoutCodeHash]);
    } else {
      m.one(d.evidence.address, event, [c.prepared.expectedReturnHash!, identity, input.original.terms.artistId, env.identityCodeHash, env.payoutCodeHash]);
    }
  } else if (input.kind === "beginSelectionV3") {
    const old = await selected(p, d, tag - 1, input.manifestHash);
    selection = await selected(p, d, tag, input.manifestHash);
    equal(selection.key, old.key); equal(selection.basis, old.basis);
    const [priorSaved] = await read(p, d.selection.address, "selectionV3", [old.key], tag - 1);
    if (priorSaved.identity.manifestHash !== ZeroHash) {
      if (m.found(d.selection.address, "RecoveryRewindSelectionBegun").length) throw Error("Selection retry unexpectedly emitted begin");
      equal(selection.progress, old.progress);
    } else {
      m.one(d.selection.address, "RecoveryRewindSelectionBegun", [old.key, input.manifestHash]);
      equal(selection.progress, zeros(rewind.ARTIST_RECOVERY_REWIND_SELECTION_PROGRESS_TUPLE), "Later same-block progress is outside this receipt profile");
    }
  } else if (input.kind === "continueSelectionV3") {
    const old = await selected(p, d, tag - 1, undefined, input.key, false);
    const prediction = await originalCall(p, c.prepared.call, c.prepared.caller, tag - 1);
    selection = await selected(p, d, tag, undefined, input.key, false);
    equal(selection.basis, old.basis); equal(selection.progress, prediction[0], "Observed progress differs from the exact prior-block step");
    if (old.progress.complete) {
      if (m.found(d.selection.address, "RecoveryRewindSelectionProgress").length) throw Error("Complete retry unexpectedly emitted progress");
    } else {
      m.one(d.selection.address, "RecoveryRewindSelectionProgress", [input.key, selection.progress.identityProcessed, selection.progress.payoutProcessed, selection.progress.complete]);
    }
  }
  await unchanged(p, prior);
  return freeze({ ...h, capture: c, transactionHash: m.transactionHash, events: await m.finish(), retained: saved, selection,
    attribution: "exact original event or prior-block reuse proof" });
}
export interface ArtistRecoveryRewindGovernanceReceipt extends Block {
  readonly operation: ArtistRecoveryRewindOperation;
  readonly transactionHash: Hex;
  readonly events: readonly ArtistRecoveryRewindEventReference[];
  readonly association: recovery.ArtistRecoveryActionAssociation | null;
  readonly record: recovery.ArtistRecoveryRecord | null;
  readonly evidenceId: Hex | null;
  readonly archiveBytes: Hex | null;
  readonly nativeRecords: readonly { readonly operation: bigint; readonly artistId: Hex; readonly collectionId: bigint; readonly recordHash: Hex }[];
  readonly attribution: "immutable operation evidence; block-end observations may include later operations";
}
type Mined = Awaited<ReturnType<typeof mined>>;
async function archiveEvidence(p: Reader, m: Mined, o: ArtistRecoveryRewindOperation, op: 35n | 65534n, actor: Address, commitment: Hex, before: ArtistHydrationSnapshot) {
  const c = coordinates(o.prepared.capture.deployment), evidenceId = recovery.artistRecoveryOperationEvidenceId(legacy(c), op, actor, commitment);
  const metadata = await read(p, c.archive, "artistEvidenceMetadataV2", [evidenceId, 1n], m.tag);
  const [raw] = await read(p, c.archive, "artistEvidenceBytesV2", [evidenceId, 1n], m.tag, undefined, 32768);
  const archiveBytes = bytes(raw, 24575);
  if (metadata[3] !== BigInt(m.tag) || metadata[2] !== BigInt((archiveBytes.length - 2) / 2) || metadata[0] !== keccak256(archiveBytes)) throw Error("Archive metadata differs");
  const pointer = address(metadata[1]);
  equal(bytes(await p.getCode(pointer, m.tag), 24576), `0x00${archiveBytes.slice(2)}`);
  const index = m.one(c.archive, "ArtistArchiveEvidenceAppendedV2", [evidenceId, 1n, metadata[0], pointer, metadata[2]]);
  const e = recovery.decodeArtistRecoveryOperationEvidence(archiveBytes);
  equal([e.schemaVersion, e.configurationHash, e.operation, e.actor, e.primaryRecordHash],
    [1n, o.prepared.capture.configurationHash, op, actor, op === 35n ? commitment : ZeroHash]);
  for (let i = 0; i < 7; i++) {
    if (i !== 2 && i !== 5) { equal(e.before[i], zeros(ARTIST_HYDRATION_SNAPSHOT_TUPLE)); equal(e.after[i], zeros(ARTIST_HYDRATION_SNAPSHOT_TUPLE)); }
  }
  equal(e.before[2], before, "Archive pre-operation owner state differs from prior-block evidence");
  const after = e.after[2]!;
  if (after.domainId !== domains[2] || after.revision !== before.revision + 1n) throw Error("Archive Identity revision differs");
  hash(after.stateRoot); hash(after.recordChainTip);
  if (op === 65534n) equal(after.recordChainTip, before.recordChainTip, "Preparation cannot append semantic receipts");
  const payoutBefore = o.prepared.capture.recovery!.manifest.payout.snapshot;
  equal(e.before[5], payoutBefore, "Archive Payout pre-state differs");
  const payoutAfter = e.after[5]!;
  const changed = op === 35n && o.prepared.capture.recovery!.manifest.supersededRecords.some(r => r.kind === 4n);
  if (!changed) equal(payoutAfter, payoutBefore, "Payout must remain unchanged");
  else {
    if (payoutAfter.domainId !== domains[5] || payoutAfter.revision !== payoutBefore.revision + 1n
      || payoutAfter.recordChainTip !== payoutBefore.recordChainTip) throw Error("Payout rewind cannot append a semantic receipt");
    hash(payoutAfter.stateRoot);
  }
  for (const [owner, expected] of [[c.identityOwner, after], [c.payoutOwner, payoutAfter]] as const) {
    const [observed] = await read(p, owner, "ownerStateSnapshotV2", [], m.tag);
    if (observed.revision < expected.revision) throw Error("Receipt owner revision regressed");
    if (observed.revision === expected.revision) equal(observed, expected);
  }
  return { evidenceId, archiveBytes, e, index, after, payoutAfter };
}

async function consumed(p: Reader, c: rewind.ArtistRecoveryRewindCoordinates, surface: string, scope: Hex, commitment: Hex, revision: bigint, tag: number, exactRevision = true) {
  const [cell] = await read(p, c.identityOwner, "replayCell", [replayKey(c, surface, scope)], tag);
  if (cell.status !== 2n || cell.kind !== 1n || cell.commitment !== commitment || !cell.touchedRevision
    || (exactRevision ? cell.touchedRevision !== revision : cell.touchedRevision > revision)) throw Error("Original replay evidence differs");
}
async function payloadEvidence(p: Reader, m: Mined, c: rewind.ArtistRecoveryRewindCoordinates, before: readonly ArtistRecoveryRewindPayloadCatalog[], payloads: readonly { kind: Hex; bytes: Hex }[], archived: number) {
  let lastRequired = archived;
  for (const catalog of before) {
    const keys = new Set(catalog.rows.map(r => `${r.payloadType}:${r.payloadHash}`));
    const expected: { kind: Hex; bytes: Hex; hash: Hex }[] = [];
    for (const payload of payloads) {
      const hash = keccak256(payload.bytes) as Hex, key = `${payload.kind}:${hash}`;
      if (!keys.has(key)) { expected.push({ ...payload, hash }); keys.add(key); }
    }
    const count = (await read(p, catalog.host, "storedPayloadCount", [], m.tag))[0];
    if (count < BigInt(catalog.rows.length + expected.length)) throw Error("Stored payload inventory incomplete");
    const events = m.found(catalog.host, "ArtistStoredPayload");
    if (events.length !== expected.length) throw Error("Exact payload additions missing");
    let last = -1;
    for (let i = 0; i < catalog.rows.length; i++) {
      const r = catalog.rows[i]!;
      equal(await read(p, catalog.host, "storedPayloadAt", [BigInt(i)], m.tag), [r.pointer, r.payloadType, r.payloadHash]);
    }
    for (let i = 0; i < expected.length; i++) {
      const item = expected[i]!, rowIndex = BigInt(catalog.rows.length + i);
      const [pointer, kind, hash] = await read(p, catalog.host, "storedPayloadAt", [rowIndex], m.tag);
      equal([kind, hash], [item.kind, item.hash]);
      equal(bytes(await p.getCode(address(pointer), m.tag), 24576), `0x00${item.bytes.slice(2)}`);
      const event = events[i]!;
      equal(Array.from(event.args), [1n, rowIndex, kind, hash, pointer]);
      if (event.log.index <= last || (catalog.host === c.identityOwner ? event.log.index >= archived : event.log.index <= archived)) throw Error("Payload store/sync order differs");
      last = event.log.index; lastRequired = Math.max(lastRequired, last); m.reference(event.log, "ArtistStoredPayload");
    }
  }
  return lastRequired;
}
function compareAssociation(a: recovery.ArtistRecoveryActionAssociation, o: ArtistRecoveryRewindOperation, role: { hash: Hex; revision: bigint }, timestamp: bigint, revision: bigint): void {
  const b = o.prepared.batch, d = o.prepared.capture.deployment;
  equal({ artistId: a.artistId, requestHash: a.requestHash, acceptanceHash: a.acceptanceHash, contextHash: a.contextHash,
    preparedBy: a.preparedBy, preparedAt: a.preparedAt, ownerRevision: a.ownerRevision },
  { artistId: b.request.artistId, requestHash: keccak256(recovery.encodeArtistRecoveryRequest(b.request)),
    acceptanceHash: keccak256(recovery.encodeArtistRecoveryAuthorization(b.acceptance)), contextHash: keccak256(recovery.encodeArtistRecoveryContext(b.context)),
    preparedBy: o.caller, preparedAt: timestamp, ownerRevision: revision });
  equal(a.action, { actionId: b.actionId, callsHash: b.callsHash, callIndex: 0n, callDataHash: b.governanceCall.callDataHash,
    executor: b.executor, executorCodeHash: d.governance.codeHash, proposer: o.prepared.proposer, roleMutationHash: role.hash,
    roleRevision: role.revision, notBefore: b.window.notBefore, expiresAfter: b.window.expiresAfter,
    minimumDelay: a.action.minimumDelay, manifestHash: b.window.manifestHash });
  if (a.action.minimumDelay < 259200n) throw Error("Preparation has invalid minimum delay");
}
function noticeBytes(v: recovery.ArtistRecoveryNoticeEvidence | null): Hex {
  return v ? recovery.encodeArtistRecoveryNoticeEvidence(v) : "0x";
}
function noticeFromBytes(v: Hex): recovery.ArtistRecoveryNoticeEvidence | null {
  return v === "0x" ? null : recovery.decodeArtistRecoveryNoticeEvidence(v);
}
async function registrationReceipt(p: ReceiptReader, m: Mined, o: ArtistRecoveryRewindOperation, before: ArtistHydrationSnapshot, f: ArtistRecoveryRewindFacts) {
  const b = o.prepared.batch, c = b.coordinates;
  const [a] = await read(p, c.identityOwner, "identityRecoveryActionState", [b.request.artistId, b.actionId], m.tag);
  const [state] = await read(p, c.identityOwner, "identityRecoveryEvidenceStateV3", [b.request.artistId, b.actionId], m.tag);
  const roleState = await read(p, o.prepared.capture.deployment.artist.components[11]!.address, "roleMutationState", [f.role], m.tag - 1);
  compareAssociation(a, o, { hash: roleState[0], revision: roleState[1] }, m.h.timestamp, before.revision + 1n);
  recovery.assertArtistRecoveryRegistrationWindow(b.acceptance, b.window, m.h.timestamp, a.action.minimumDelay);
  equal(f.manifest.identity.snapshot, before);
  equal([state.manifestHash, state.requiredRole, state.associationHash, state.selectionCommitment, state.sourceKey, state.sourceCommitment, state.sources],
    [b.manifestHash, f.role, a.associationHash, f.selection.result!.commitment, f.selection.key, f.selection.basis.sourceCommitment,
      { identityBefore: f.manifest.identity, payout: f.manifest.payout, associationHash: a.associationHash }]);
  hash(state.policyCommitment);
  if (state.effectiveCapabilities > 4095n) throw Error("Invalid restored capabilities");
  equal(a.associationHash, rewind.artistRecoveryRewindPreparationHash(c, f.association.action.actionId, b.manifestHash, state.policyCommitment, f.selection.result!, a));
  const [guardians, restored] = await read(p, c.identityOwner, "guardianRecoverySelection", [b.actionId], m.tag);
  equal(guardians, f.selection.result!.guardians); equal(restored, a.guardian);
  const [, , history] = await read(p, c.identityOwner, "guardianHistoryState", [b.request.artistId, 0n, ZeroAddress, b.actionId], m.tag);
  equal(history, { artistId: b.request.artistId, count: f.selection.basis.identity.guardianHistory.count,
    historyCommitment: f.selection.basis.identity.guardianHistory.commitment, associationHash: a.associationHash });
  const prepared = m.one(c.identityOwner, "ArtistIdentityRecoveryPrepared", [1n, b.request.artistId, b.actionId, a.associationHash, a.guardian.recordHash, o.caller, m.h.timestamp]);
  const archive = await archiveEvidence(p, m, o, 65534n, o.caller, a.associationHash, before);
  const seal = rewind.normalizeArtistRecoveryRewindPreparationSeal((await read(p, c.selectionPreparation, "preparationSealV3", [f.selection.key], m.tag))[0]);
  equal({ ...seal, commitment: ZeroHash }, { manifestHash: b.manifestHash, sourceKey: f.selection.key, actionId: b.actionId,
    associationHash: a.associationHash, identityBefore: f.manifest.identity, identityAfterPreparation: archive.after,
    payout: f.manifest.payout, evidenceStateHash: hashEncoded([rewind.ARTIST_RECOVERY_REWIND_EVIDENCE_STATE_TUPLE], [state]), commitment: ZeroHash });
  equal(rewind.artistRecoveryRewindPreparationSealHash(c, seal), seal.commitment); hash(seal.commitment);
  const sealed = m.one(c.selectionPreparation, "RecoveryRewindPreparationSealed", [f.selection.key, b.actionId, seal.commitment]);
  if (prepared >= sealed || sealed >= archive.index) throw Error("Preparation seal/Archive order differs");
  await consumed(p, c, "identity_authority.replay.recovery_preparation", b.actionId, a.associationHash, archive.after.revision, m.tag);
  const evidence = rewind.decodeArtistRecoveryRewindPreparationPayload(archive.e.payload);
  equal(evidence, { tag: id("6529STREAM_ARTIST_RECOVERY_REWIND_PREPARATION_EVIDENCE_V3"), request: b.request,
    acceptance: b.acceptance, context: b.context, association: a, state, evidence: f.evidence, preparationSeal: seal, notice: noticeBytes(f.notice) });
  if (m.found(c.identityOwner, "ArtistStoredPayload").length || m.found(c.payoutOwner, "ArtistStoredPayload").length
    || m.found(c.archive, "ArtistStoredPayload").length) throw Error("Preparation cannot add payloads");
  equal((await read(p, c.identityOwner, "artistNativeReceiptCount", [], m.tag))[0], f.manifest.identity.receiptCount, "Preparation cannot append native records");
  equal((await read(p, c.payoutOwner, "artistNativeReceiptCount", [], m.tag))[0], f.manifest.payout.receiptCount);
  return { association: a as recovery.ArtistRecoveryActionAssociation, record: null, evidenceId: archive.evidenceId,
    archiveBytes: archive.archiveBytes, nativeRecords: [], last: archive.index };
}
function payoutReplayKey(c: rewind.ArtistRecoveryRewindCoordinates, surface: string, scope: Hex): Hex {
  return hashEncoded(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), c.chainId, c.registry, c.coordinator, c.archive, c.payoutOwner, domains[5], id(surface), scope]);
}
async function payoutValue(p: Reader, c: rewind.ArtistRecoveryRewindCoordinates, artistId: Hex, recordHash: Hex, tag: number): Promise<rewind.ArtistRecoveryRewindPayout> {
  if (recordHash === ZeroHash) return { account: ZeroAddress as Address, recordHash };
  const [terms] = await read(p, c.payoutOwner, "designationRecord", [recordHash], tag);
  equal(terms.artistId, artistId); return { account: address(terms.payoutAccount), recordHash };
}
async function rewoundEffects(p: Reader, m: Mined, o: ArtistRecoveryRewindOperation, f: ArtistRecoveryRewindFacts,
  recordHash: Hex, identityAfter: ArtistHydrationSnapshot, payoutAfter: ArtistHydrationSnapshot, mutation: Hex, identityEvent: number, archiveIndex: number): Promise<void> {
  const b = o.prepared.batch, c = b.coordinates, artistId = b.request.artistId, result = f.selection.result!;
  const env = rewind.artistRecoveryRewindEnvironment(c), E = rewind.ARTIST_RECOVERY_REWIND_ENVIRONMENT_TUPLE;
  const statusType = rewind.ARTIST_RECOVERY_REWIND_STATUS_TUPLE;
  let identityStatuses = f.selection.basis.identity.inventory.supersessionStateCommitment;
  let payoutStatuses = f.selection.basis.payoutInventory.supersessionStateCommitment;
  for (const ref of f.manifest.supersededRecords) {
    const expected = { artistId, kind: ref.kind, recoveryRecordHash: recordHash, actionId: b.actionId, planCommitment: result.commitment };
    const value = ref.kind === 4n ? (await read(p, c.payoutOwner, "payoutRecoveryRecordStatusV3", [ref.recordHash], m.tag))[0]
      : (await read(p, c.identityOwner, "recoveryRecordStatusV3", [ref.kind, ref.recordHash], m.tag))[0];
    equal(value, expected, "Typed supersession status differs");
    if (ref.kind === 4n) payoutStatuses = hashEncoded(["bytes32", "uint16", E, "bytes32", "bytes32", statusType],
      [id("6529STREAM_ARTIST_RECOVERY_PAYOUT_STATUS_V3"), 3n, env, payoutStatuses, ref.recordHash, expected]);
    else if (ref.kind !== 0n) identityStatuses = hashEncoded(["bytes32", "bytes32", statusType], [identityStatuses, ref.recordHash, expected]);
  }
  identityStatuses = hashEncoded(["bytes32", "uint16", E, "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_ARTIST_RECOVERY_REWIND_IDENTITY_STATUSES_V3"), 3n, env, artistId, recordHash, b.actionId, result.commitment, identityStatuses]);
  const beforeInventory = f.selection.basis.identity.inventory;
  let revisionHead = beforeInventory.revisionContinuationHash;
  const tip = beforeInventory.revisions.candidate === ZeroHash ? beforeInventory.revisions.stable : beforeInventory.revisions.candidate;
  if (tip !== ZeroHash && tip !== result.identityRevision.operative.recordHash && result.identityRevision.retainedCandidateRecordHash === ZeroHash
    && f.manifest.supersededRecords.some(r => r.kind === 3n && r.recordHash === tip)) {
    const stable = result.identityRevision.operative.recordHash;
    const document = stable === ZeroHash ? (await read(p, c.identityOwner, "identity", [artistId], m.tag))[0].identityRecordHash
      : (await read(p, c.identityOwner, "identityRevisionRecord", [stable], m.tag))[0].revisedRecordHash;
    const value = { artistId, recoveryRecordHash: recordHash, actionId: b.actionId, planCommitment: result.commitment,
      stableRevisionRecordHash: stable, stableDocumentHash: document, resolvedChildRecordHash: tip,
      ownerRevision: identityAfter.revision, continuationHash: ZeroHash as Hex };
    value.continuationHash = rewind.artistRecoveryRewindRevisionContinuationHash(c, value);
    equal((await read(p, c.identityOwner, "recoveryRevisionContinuationV3", [value.continuationHash], m.tag))[0], value);
    revisionHead = value.continuationHash;
  }
  for (const selected of result.standing) {
    const prior = await read(p, c.identityOwner, "recoveryStandingScopeV3", [artistId, selected.priorAddress], m.tag - 1);
    if (prior[0] !== selected.retirementHash || selected.priorAddress === b.context.incumbent) continue;
    equal([prior[1], prior[2], prior[3]], [selected.expectedRevocationRecordHash, selected.independentJudgmentHash, selected.continuationCommitment]);
    if (selected.retainedRevocation.recordHash !== selected.expectedRevocationRecordHash) {
      const value = { artistId, priorAddress: selected.priorAddress, retirementHash: selected.retirementHash,
        recoveryRecordHash: recordHash, actionId: b.actionId, planCommitment: result.commitment,
        retainedRevocationRecordHash: selected.retainedRevocation.recordHash, supersededRevocationRecordHash: selected.expectedRevocationRecordHash,
        ownerRevision: identityAfter.revision, continuationHash: ZeroHash as Hex };
      value.continuationHash = rewind.artistRecoveryRewindStandingContinuationHash(c, value);
      equal((await read(p, c.identityOwner, "recoveryStandingContinuationV3", [value.continuationHash], m.tag))[0], value);
    }
  }
  if (b.request.vestedAuthorityClass === 3n) {
    const [value] = await read(p, c.identityOwner, "recoveryCapabilityContinuationV3", [recordHash], m.tag);
    equal([value.artistId, value.recoveryRecordHash, value.actionId, value.manifestHash, value.planCommitment, value.designationRecordHash,
      value.forbiddenDirectiveRecordHash, value.authorityAddress, value.effectiveCapabilities],
    [artistId, recordHash, b.actionId, b.manifestHash, result.commitment, result.designation.operative.recordHash,
      result.directive.operative.recordHash, b.request.newAddress, f.state.effectiveCapabilities]);
    const [designation] = await read(p, c.identityOwner, "successorDesignationRecord", [value.designationRecordHash], m.tag);
    equal(value.pairedDirectiveRecordHash, designation.terms.directiveHash);
    if (!f.selection.identityJournal.some(r => [40n, 43n].includes(r.operation) && r.artistId === artistId && r.recordHash === value.originalActivationRecordHash)
      || value.originalActivationCapabilities > 4095n) throw Error("Capability continuation origin differs");
    equal(rewind.artistRecoveryRewindCapabilityContinuationHash(c, value), value.commitment); hash(value.commitment);
  }
  const [observedIdentity] = await read(p, c.identityOwner, "ownerStateSnapshotV2", [], m.tag);
  if (observedIdentity.revision === identityAfter.revision) {
    const [inventory] = await read(p, c.identityOwner, "recoveryRewindInventoryV3", [artistId], m.tag);
    equal(inventory, { guardians: { stable: result.guardians.selectedRecordHash, candidate: ZeroHash },
      designations: { stable: result.designation.operative.recordHash, candidate: result.designation.retainedCandidateRecordHash },
      directives: { stable: result.directive.operative.recordHash, candidate: result.directive.retainedCandidateRecordHash },
      revisions: { stable: result.identityRevision.operative.recordHash, candidate: result.identityRevision.retainedCandidateRecordHash },
      sanctionGrants: { stable: result.sanctionGrant.operative.recordHash, candidate: result.sanctionGrant.retainedCandidateRecordHash },
      revisionContinuationHash: revisionHead, supersessionStateCommitment: identityStatuses });
  }
  const excluded = f.manifest.supersededRecords.filter(r => r.kind === 4n).map(r => r.recordHash);
  equal((await read(p, c.payoutOwner, "artistNativeReceiptCount", [], m.tag))[0], f.manifest.payout.receiptCount, "Rewind cannot create a Payout native receipt");
  if (!excluded.length) {
    equal(mutation, ZeroHash);
    if (m.found(c.payoutOwner, "ArtistPayoutRecoveryRewindApplied").length) throw Error("Unexpected Payout apply event");
    return;
  }
  const stable = await payoutValue(p, c, artistId, result.payout.operative.recordHash, m.tag);
  const candidate = await payoutValue(p, c, artistId, result.payout.retainedCandidateRecordHash, m.tag);
  const previous = f.selection.basis.payoutInventory;
  const continuation: { -readonly [K in keyof rewind.ArtistRecoveryRewindPayoutContinuation]: rewind.ArtistRecoveryRewindPayoutContinuation[K] } = { artistId, recoveryRecordHash: recordHash, actionId: b.actionId, manifestHash: b.manifestHash,
    planCommitment: result.commitment, identityOwnerRevision: identityAfter.revision, stable, candidate,
    releasedChildRecordHash: excluded.includes(previous.candidate.recordHash) ? previous.candidate.recordHash
      : excluded.includes(previous.stable.recordHash) ? previous.stable.recordHash : ZeroHash as Hex,
    previousContinuationHash: previous.continuationCommitment, payoutOwnerRevision: payoutAfter.revision, continuationHash: ZeroHash as Hex };
  continuation.continuationHash = rewind.artistRecoveryRewindPayoutContinuationHash(c, continuation);
  equal((await read(p, c.payoutOwner, "payoutRecoveryContinuationV3", [continuation.continuationHash], m.tag))[0], continuation);
  const chainKey = payoutReplayKey(c, "payout_lifecycle.replay.designation_chain", hashEncoded(["bytes32"], [artistId]));
  const recoveryKey = payoutReplayKey(c, "payout_lifecycle.replay.recovery_rewind", recordHash);
  const [prior] = await read(p, c.payoutOwner, "replayCell", [chainKey], m.tag - 1);
  const [cell] = await read(p, c.payoutOwner, "replayCell", [chainKey], m.tag);
  const [recoveryCell] = await read(p, c.payoutOwner, "replayCell", [recoveryKey], m.tag);
  equal(cell, { commitment: candidate.recordHash === ZeroHash ? stable.recordHash : candidate.recordHash,
    touchedRevision: payoutAfter.revision, kind: 3n, status: 1n });
  equal(recoveryCell, { commitment: result.commitment, touchedRevision: payoutAfter.revision, kind: 1n, status: 2n });
  const apply = { artistId, manifestHash: b.manifestHash, actionId: b.actionId, associationHash: f.association.associationHash,
    contextHash: hashEncoded([recovery.ARTIST_RECOVERY_CONTEXT_TUPLE], [b.context]), recoveryRecordHash: recordHash, planCommitment: result.commitment,
    source: f.manifest.payout, beforeInventory: previous, selected: result.payout, supersededPayoutRecordHashes: excluded };
  const actionHash = hashEncoded(["bytes32", "uint16", E, rewind.ARTIST_RECOVERY_REWIND_PAYOUT_APPLY_TUPLE], [id("6529STREAM_ARTIST_RECOVERY_PAYOUT_APPLY_V3"), 3n, env, apply]);
  const stateHash = hashEncoded([rewind.ARTIST_RECOVERY_REWIND_PAYOUT_TUPLE, rewind.ARTIST_RECOVERY_REWIND_PAYOUT_TUPLE, "bytes32", rewind.ARTIST_RECOVERY_REWIND_PAYOUT_CONTINUATION_TUPLE], [stable, candidate, payoutStatuses, continuation]);
  const cellType = "(bytes32 commitment,uint64 touchedRevision,uint8 kind,uint8 status)";
  const replayHash = hashEncoded(["bytes32", cellType, cellType, "bytes32", cellType], [chainKey, prior, cell, recoveryKey, recoveryCell]);
  equal(mutation, hashEncoded(["bytes32", "bytes32", "bytes32"], [actionHash, stateHash, replayHash]));
  const event = m.one(c.payoutOwner, "ArtistPayoutRecoveryRewindApplied", [3n, artistId, recordHash, b.actionId, result.commitment, continuation.continuationHash, mutation]);
  if (event <= identityEvent || event >= archiveIndex) throw Error("Atomic Identity/Payout/Archive ordering differs");
  equal((await read(p, c.payoutOwner, "payoutRewindInventoryV3", [artistId], m.tag))[0],
    { stable, candidate, supersessionStateCommitment: payoutStatuses, continuationCommitment: continuation.continuationHash });
}
async function executionReceipt(p: ReceiptReader, m: Mined, o: ArtistRecoveryRewindOperation, before: ArtistHydrationSnapshot, f: ArtistRecoveryRewindFacts) {
  const b = o.prepared.batch, c = b.coordinates, q = b.request, a = b.acceptance;
  if (m.h.timestamp < b.window.notBefore || m.h.timestamp > b.window.expiresAfter || m.h.timestamp > a.time) throw Error("Recovery executed outside signed/governance window");
  if (before.revision !== f.manifest.identity.snapshot.revision + 1n || f.association.ownerRevision !== before.revision || f.association.action.actionId !== b.actionId
    || f.state.manifestHash !== b.manifestHash || f.state.associationHash !== f.association.associationHash || f.veto.vetoer !== ZeroAddress || f.executed !== ZeroHash) throw Error("Prepared recovery was not live in the previous block");
  const fields: recovery.ArtistRecoveryRecordFields = { artistId: q.artistId, oldAddress: b.context.incumbent, newAddress: q.newAddress,
    vestedAuthorityClass: q.vestedAuthorityClass, evidenceHash: q.evidenceHash, reasonHash: q.reasonHash,
    supersededRecordsHash: recovery.artistRecoverySupersededRecordsHash(q.supersededRecordHashes), governanceActionId: b.actionId, recoveredAt: m.h.timestamp };
  const recordHash = recovery.artistRecoveryRecordHash(c.chainId, c.registry, fields);
  const [record] = await read(p, c.identityOwner, "identityRecoveryRecord", [recordHash], m.tag);
  const [association, , executed] = await read(p, c.identityOwner, "identityRecoveryActionState", [q.artistId, b.actionId], m.tag);
  equal(association, f.association); equal(executed, recordHash);
  const [state] = await read(p, c.identityOwner, "identityRecoveryEvidenceStateV3", [q.artistId, b.actionId], m.tag); equal(state, f.state);
  const event = m.one(c.identityOwner, "ArtistIdentityRecovered", [2n, q.artistId, b.context.incumbent, q.newAddress, q.vestedAuthorityClass,
    q.evidenceHash, q.reasonHash, fields.supersededRecordsHash, m.h.timestamp, recordHash, b.actionId, q.supersededRecordHashes]);
  const archive = await archiveEvidence(p, m, o, 35n, b.executor, recordHash, before);
  if (archive.index <= event) throw Error("Recovery Archive precedes owner event");
  const targetStart = Math.min(event, ...["ArtistStoredPayload", "ArtistDormancyCancelled", "ArtistDormancyCancellationContext"]
    .flatMap(name => m.found(c.identityOwner, name).map(v => v.log.index)));
  const memberships = m.found(b.executor, "TerminalFreezeActionMembershipUpdated").filter(v => v.args[2] === b.actionId);
  if (memberships.length > 1) throw Error("Duplicate terminal membership cleanup");
  for (const entry of memberships) {
    const a = entry.args;
    if (a[0] !== 1n || a[1] !== b.context.scopeHash || a[3] !== o.prepared.proposer || a[4] !== false || a[5] !== 3n
      || a[7] !== b.window.notBefore || a[8] > a[9] || a[9] >= 64n || entry.log.index >= targetStart) throw Error("Terminal cleanup fields/order differ");
    m.reference(entry.log, "TerminalFreezeActionMembershipUpdated");
  }
  const e = rewind.decodeArtistRecoveryRewindExecutionPayload(archive.e.payload);
  const decoded = { noticeBefore: noticeFromBytes(e.noticeBefore), noticeAfter: noticeFromBytes(e.noticeAfter) };
  equal(e.request, q); equal(e.acceptance, a); equal(e.context, b.context); equal(e.state, f.state); equal(e.evidence, f.evidence);
  const direct = b.executor === q.newAddress && a.signature === "0x";
  equal(e.proof, { signer: q.newAddress, digest: f.acceptanceDigest, direct });
  equal(e.governance, { actionId: b.actionId, proposer: o.prepared.proposer, actionClass: 2n,
    roleMutationHash: f.association.action.roleMutationHash, roleRevision: f.association.action.roleRevision,
    scopeHash: b.context.scopeHash, oldValueHash: b.context.oldValueHash, newValueHash: b.context.newValueHash });
  const expected: recovery.ArtistRecoveryRecord = { recordHash, fields, terms: q, executor: b.executor, proposer: o.prepared.proposer,
    governanceWitnessHash: keccak256(recovery.encodeArtistRecoveryGovernanceWitness(e.governance)) as Hex,
    contextHash: keccak256(recovery.encodeArtistRecoveryContext(b.context)) as Hex, acceptanceDigest: f.acceptanceDigest,
    acceptanceNonce: a.nonce, acceptanceDeadline: a.time, postContestSeconds: b.context.postContestSeconds,
    standingTailSeconds: b.context.standingTailSeconds, timingRevision: b.context.timingRevision,
    delegationEpoch: b.context.delegationEpoch + 1n, abandonedTransition: b.context.abandonedTransition };
  equal(record, expected); equal(e.record, expected);
  await rewoundEffects(p, m, o, f, recordHash, archive.after, archive.payoutAfter, e.payoutMutation, event, archive.index);
  const afterRevision = archive.after.revision;
  await consumed(p, c, "identity_authority.replay.recovery_action", hashEncoded(["bytes32", "bytes32", "bytes32", "bytes32"], [b.actionId, b.context.scopeHash, b.context.oldValueHash, b.context.newValueHash]), recordHash, afterRevision, m.tag);
  await consumed(p, c, "identity_authority.replay.standing_retirement", hashEncoded(["bytes32", "address", "bytes32"], [q.artistId, b.context.incumbent, recordHash]), recordHash, afterRevision, m.tag);
  await consumed(p, c, "identity_authority.replay.contest_resolution", hashEncoded(["bytes32", "bytes32"], [q.artistId, q.expectedCauseHash]), recordHash, afterRevision, m.tag);
  await consumed(p, c, "identity_authority.replay.nonce_allocator", hashEncoded(["bytes32", "bytes32", "address", "uint256"], [id("rotation_acceptance"), q.artistId, q.newAddress, a.nonce]), f.acceptanceDigest, afterRevision, m.tag);
  await consumed(p, c, "identity_authority.replay.authorization_consumed_digest", hashEncoded(["bytes32", "bytes32"], [q.artistId, f.acceptanceDigest]), f.acceptanceDigest, afterRevision, m.tag, false);
  const [denied] = await read(p, c.identityOwner, "replayCell", [replayKey(c, "identity_authority.replay.digest_revocation", hashEncoded(["bytes32", "bytes32"], [q.artistId, f.acceptanceDigest]))], m.tag);
  if (denied.status !== 0n) throw Error("Accepted digest was revoked");
  const [vesting] = await read(p, c.identityOwner, "guardianVestingSnapshot", [q.artistId, recordHash], m.tag);
  equal([vesting.artistId, vesting.transitionRecordHash, vesting.operationId, vesting.ownerRevision, vesting.executedAt,
    vesting.oldAddress, vesting.newAddress, vesting.authorityClass, vesting.guardians, vesting.previousTransitionRecordHash],
  [q.artistId, recordHash, 35n, afterRevision, m.h.timestamp, b.context.incumbent, q.newAddress, q.vestedAuthorityClass,
    f.selection.basis.identity.guardianHistory, f.manifest.executedHead]);
  equal(vesting.commitment, recovery.artistRecoveryVestingCommitment(legacy(c), vesting));
  if (f.manifest.executedHead === ZeroHash) equal(vesting.previousCommitment, ZeroHash);
  else equal(vesting.previousCommitment, (await read(p, c.identityOwner, "guardianVestingSnapshot", [q.artistId, f.manifest.executedHead], m.tag))[0].commitment);
  const pair = await read(p, c.identityOwner, "identityRecoveryReceipts", [recordHash], m.tag);
  hash(pair[0]); hash(pair[2]);
  equal(pair[1], hashEncoded(["bytes32", "uint16", "bytes32", "bytes32", "bytes32"], ["0x05c1b33dc3307a69a2b02b1fdcc96323c6c2dcb072805ca38ec6462ded34ce09", 2n, recordHash,
    "0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae", fields.supersededRecordsHash]));
  equal(decoded.noticeBefore, f.notice);
  const nativeRecords = [];
  let offset = 0n;
  if (f.notice) {
    const n = decoded.noticeAfter;
    if (!n) throw Error("Current notice post-evidence missing");
    equal(n.cause, f.notice.cause); equal(n.notice, f.notice.notice);
    if (f.notice.phase === 1n) {
      const terminal = { ...zeros(recovery.ARTIST_RECOVERY_TERMINAL_TUPLE), noticeHash: n.notice.recordHash, actor: q.newAddress, authorityClass: 1n, observedAt: m.h.timestamp };
      terminal.recordHash = recovery.artistRecoveryCancellationHash(legacy(c), terminal, n.notice.priorActivity + 1n);
      equal(n.phase, 2n); equal(n.terminal, terminal);
      const cancelled = m.one(c.identityOwner, "ArtistDormancyCancelled", [1n, q.artistId, n.notice.recordHash, q.newAddress, 1n, terminal.recordHash]);
      const contextual = m.one(c.identityOwner, "ArtistDormancyCancellationContext", [1n, q.artistId, terminal.recordHash,
        { chainId: c.chainId, registry: c.registry, identityOwner: c.identityOwner, recorder: q.newAddress, recorderAuthorityClass: 1n }, terminal, n.notice.priorActivity + 1n]);
      if (cancelled >= contextual || contextual >= event) throw Error("Genuine42 cancellation must precede recovery35");
      await consumed(p, c, "identity_authority.replay.dormancy_cancellation_key", n.notice.recordHash, terminal.recordHash, afterRevision, m.tag);
      nativeRecords.push({ operation: 42n, artistId: q.artistId, collectionId: 0n, recordHash: terminal.recordHash }); offset = 1n;
    } else {
      equal(n, f.notice);
      if (m.found(c.identityOwner, "ArtistDormancyCancelled").length || m.found(c.identityOwner, "ArtistDormancyCancellationContext").length) throw Error("Phase2 notice cannot be cancelled again");
    }
    const retainedNotice = await notice(p, c, q.expectedCauseHash, m.tag); equal(retainedNotice, n);
  } else if (decoded.noticeAfter) throw Error("Unexpected notice wrapper");
  nativeRecords.push({ operation: 35n, artistId: q.artistId, collectionId: 0n, recordHash },
    { operation: 35n, artistId: q.artistId, collectionId: 0n, recordHash: fields.supersededRecordsHash });
  const count = (await read(p, c.identityOwner, "artistNativeReceiptCount", [], m.tag))[0];
  if (count < f.nativeCount + 2n + offset) throw Error("Native recovery journal incomplete");
  for (let i = 0; i < nativeRecords.length; i++) equal((await read(p, c.identityOwner, "artistNativeReceiptAt", [f.nativeCount + BigInt(i)], m.tag))[0], nativeRecords[i]);
  const preimage = encoded(["bytes32", "uint256", "address", recovery.ARTIST_RECOVERY_RECORD_FIELDS_TUPLE],
    ["0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff", c.chainId, c.registry, fields]);
  const last = await payloadEvidence(p, m, c, f.payloads, [{ kind: id("ARTIST_SIGNATURE_BUNDLE") as Hex, bytes: a.signature },
    { kind: id("ARTIST_RECORD_PREIMAGE") as Hex, bytes: preimage }], archive.index);
  return { association: f.association, record: expected, evidenceId: archive.evidenceId, archiveBytes: archive.archiveBytes, nativeRecords, last };
}
/** Exact singleton original governance transport, plus immutable auxiliary/operation35 evidence. */
export async function inspectArtistRecoveryRewindOperationReceipt(p: ReceiptReader, raw: ArtistRecoveryRewindOperation, supplied: ReceiptOptions): Promise<ArtistRecoveryRewindGovernanceReceipt> {
  const o = operation(raw), c = o.prepared.capture, b = o.prepared.batch, d = c.deployment, options = receiptOptions(supplied);
  await historical(p, c);
  const m = await mined(p, d, o.caller, o.call, c.blockNumber, options), { h, tag } = m;
  let detail: { association: recovery.ArtistRecoveryActionAssociation | null; record: recovery.ArtistRecoveryRecord | null; evidenceId: Hex | null; archiveBytes: Hex | null; nativeRecords: { operation: bigint; artistId: Hex; collectionId: bigint; recordHash: Hex }[]; last: number }
    = { association: null, record: null, evidenceId: null, archiveBytes: null, nativeRecords: [], last: -1 };
  const prior = await context(p, d, tag - 1, false);
  if (o.stage === "publish") {
    const now = await publication(p, b, tag), old = await publication(p, b, tag - 1);
    if (!now) throw Error("Publication not retained");
    if (old) {
      equal(now, old); if (m.found(b.executor, "GovernanceCallDataPublished").length) throw Error("Publication retry emitted first event");
    } else m.one(b.executor, "GovernanceCallDataPublished", [1n, b.publicationKey, now, o.caller]);
  } else {
    const catalog = await governance(p, o, tag);
    const a = await action(p, o, tag);
    if (o.stage === "schedule") {
      if (![1n, 2n, 5n].includes(a.status) || b.window.notBefore < h.timestamp + catalog.minimumDelay
        || h.timestamp > (1n << 64n) - 1n - 31536000n || b.window.expiresAfter > h.timestamp + 31536000n) throw Error("Schedule state/window contradiction");
      if ((await read(p, b.executor, "governanceNonce", [], tag))[0] < b.nonce + 1n) throw Error("Governance nonce did not advance");
      const membership = m.one(b.executor, "TerminalFreezeGuardianConfigCommitted", [1n, b.actionId,
        hash((await read(p, b.executor, "terminalFreezeGuardianConfigCommitment", [b.actionId], tag))[0])]);
      const entries = m.found(b.executor, "TerminalFreezeActionMembershipUpdated").filter(v => v.args[2] === b.actionId);
      if (entries.length !== 1) throw Error("Original terminal membership append missing");
      const entry = entries[0]!, args = entry.args;
      if (args[0] !== 1n || args[1] !== b.context.scopeHash || args[3] !== o.caller || args[4] !== true || args[5] !== 1n
        || args[7] !== b.window.notBefore || args[9] !== args[8] + 1n || args[9] > 64n || entry.log.index >= membership) throw Error("Terminal membership fields/order differ");
      m.reference(entry.log, "TerminalFreezeActionMembershipUpdated");
      const scheduled = m.one(b.executor, "GovernanceActionScheduled", [1n, b.actionId, 2n, b.targetCall.to, 0n, b.governanceCall.selector,
        b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash, b.window.notBefore, b.window.expiresAfter, b.nonce,
        o.caller, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash]);
      const validated = m.one(b.executor, "GovernanceActionPolicyValidated", [1n, b.actionId, 1n, catalog.candidateProfileHash, catalog.catalogHash]);
      if (membership >= scheduled || scheduled >= validated) throw Error("Schedule source event order differs");
    } else {
      const input = { kind: "identityRecoveryContextV3" as const, request: b.request, acceptance: b.acceptance, manifestHash: b.manifestHash };
      const f = await recoveryFacts(p, d, input, tag - 1);
      equal(f.context, b.context); equal(f.evidence, c.recovery!.evidence);
      const [before] = await read(p, b.coordinates.identityOwner, "ownerStateSnapshotV2", [], tag - 1);
      detail = o.stage === "register" ? await registrationReceipt(p, m, o, before, f) : await executionReceipt(p, m, o, before, f);
      if (o.stage === "execute") {
        if (a.status !== 3n || !same(a.executor, o.caller)) throw Error("Governance execution state differs");
        const executed = m.one(b.executor, "GovernanceActionExecuted", [1n, b.actionId, 2n, b.targetCall.to, 0n, b.governanceCall.selector,
          b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash, o.caller, b.window.manifestHash]);
        const validated = m.one(b.executor, "GovernanceActionPolicyValidated", [1n, b.actionId, 2n, catalog.candidateProfileHash, catalog.catalogHash]);
        if (detail.last >= executed || executed >= validated) throw Error("Execution source event order differs");
      }
    }
  }
  await unchanged(p, prior);
  const { last: _, ...result } = detail;
  return freeze({ ...h, operation: o, transactionHash: m.transactionHash, events: await m.finish(), ...result,
    attribution: "immutable operation evidence; block-end observations may include later operations" });
}
