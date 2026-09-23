// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistRecoveryEvidenceTypes as E } from "./StreamArtistRecoveryEvidenceTypes.sol";
import { StreamArtistGuardianAppealTypes as Appeal } from "./StreamArtistGuardianAppealTypes.sol";
import { StreamArtistGuardianHistoryTypes as GH } from "./StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistGuardianSelectionTypes as Selection
} from "./StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "./StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Additive typed adjudication of original records; V1/V2 encodings are unchanged.
library StreamArtistRecoveryRewindTypes {
    uint256 internal constant MAX_DECLARED_VESTINGS = 64;
    uint256 internal constant MAX_SUPERSESSIONS = 64;
    uint256 internal constant MAX_FINDING_PARTIES = 8;

    enum RecordKind {
        GUARDIAN_SET,
        SUCCESSOR_DESIGNATION,
        ESTATE_DIRECTIVE,
        IDENTITY_REVISION,
        PAYOUT_DESIGNATION,
        STEWARD_SANCTION_GRANT,
        PRIOR_ADDRESS_STANDING_REVOCATION
    }

    struct EnvironmentV3 {
        uint256 chainId;
        address registry;
        address identityOwner;
        bytes32 identityCodeHash;
        address payoutOwner;
        bytes32 payoutCodeHash;
        address coordinator;
        address archive;
        address core;
        address manager;
    }

    struct RecordReference {
        RecordKind kind;
        bytes32 recordHash;
    }

    struct ReceiptPrefix {
        T.Snapshot snapshot;
        uint256 receiptCount;
    }

    struct ResolutionManifestV3 {
        bytes32 artistId;
        ReceiptPrefix identity;
        ReceiptPrefix payout;
        bytes32 causeHash;
        bytes32 resolutionHash;
        bytes32 executedHead;
        E.VestingBasis basis;
        bytes32 requestCommitment;
        bytes32 resolutionEvidenceHash;
        E.VestingReference[] contestedVestings;
        // Strict record-hash order, independently of kind; exactly the original Request list.
        RecordReference[] supersededRecords;
    }

    struct AppealDocumentV3 {
        bytes32 resolutionManifestHash;
        bytes32 hostileFindingsHash;
        Appeal.Finding[] findings;
    }

    /// @notice Original op18 fields omitted from the Payout owner's retained terms.
    /// @dev This is content evidence, never a caller-selected replacement payout.
    struct PayoutOriginalV3 {
        bytes32 recordHash;
        T.PayoutDesignation terms;
        address signer;
        uint8 authorityClass;
        uint256 nonce;
        uint64 signedAt;
    }

    struct FamilyPointers {
        bytes32 stable;
        bytes32 candidate;
    }

    struct IdentityInventoryV3 {
        FamilyPointers guardians;
        FamilyPointers designations;
        FamilyPointers directives;
        FamilyPointers revisions;
        FamilyPointers sanctionGrants;
        bytes32 revisionContinuationHash;
        bytes32 supersessionStateCommitment;
    }

    struct PayoutInventoryV3 {
        T.Payout stable;
        T.Payout candidate;
        bytes32 supersessionStateCommitment;
        bytes32 continuationCommitment;
    }

    struct StatusV3 {
        bytes32 artistId;
        RecordKind kind;
        bytes32 recoveryRecordHash;
        bytes32 actionId;
        bytes32 planCommitment;
    }

    struct IdentityBasisV3 {
        bytes32 manifestHash;
        bytes32 artistId;
        bytes32 ownerCodeHash;
        ReceiptPrefix identity;
        IdentityInventoryV3 inventory;
        GH.Head guardianHistory;
        bytes32 sourceCommitment;
    }

    struct BasisV3 {
        IdentityBasisV3 identity;
        bytes32 payoutCodeHash;
        ReceiptPrefix payout;
        PayoutInventoryV3 payoutInventory;
        bytes32 sourceCommitment;
    }

    struct ProgressV3 {
        uint256 identityProcessed;
        uint256 payoutProcessed;
        uint64 guardiansProcessed;
        uint256 seenExclusions;
        bytes32 identityScanCommitment;
        bytes32 payoutScanCommitment;
        bool complete;
        bytes32 resultCommitment;
    }

    struct SelectedRecordV3 {
        bytes32 recordHash;
        bytes32 originalDataHash;
        bytes32 admissionProof;
        uint256 nonce;
        uint256 nativeIndex;
    }

    struct FamilySelectionV3 {
        SelectedRecordV3 operative;
        bytes32 retainedCandidateRecordHash;
        bytes32 branchCommitment;
    }

    struct StandingSelectionV3 {
        address priorAddress;
        bytes32 retirementHash;
        bytes32 expectedRevocationRecordHash;
        SelectedRecordV3 retainedRevocation;
        bytes32 independentJudgmentHash;
        bytes32 continuationCommitment;
    }

    struct ResultV3 {
        bytes32 sourceKey;
        bytes32 manifestHash;
        bytes32 sourceCommitment;
        bytes32 inventoryCommitment;
        Selection.Result guardians;
        FamilySelectionV3 designation;
        FamilySelectionV3 directive;
        FamilySelectionV3 identityRevision;
        FamilySelectionV3 payout;
        FamilySelectionV3 sanctionGrant;
        StandingSelectionV3[] standing;
        bytes32 commitment;
    }

    struct PreparedSourcesV3 {
        ReceiptPrefix identityBefore;
        ReceiptPrefix payout;
        bytes32 associationHash;
    }

    /// @notice Selector-owned post-commit anchor; never included in its own owner-root preimage.
    struct PreparationSealV3 {
        bytes32 manifestHash;
        bytes32 sourceKey;
        bytes32 actionId;
        bytes32 associationHash;
        ReceiptPrefix identityBefore;
        T.Snapshot identityAfterPreparation;
        ReceiptPrefix payout;
        bytes32 evidenceStateHash;
        bytes32 commitment;
    }

    struct EvidenceStateV3 {
        bytes32 manifestHash;
        bytes32 sourceKey;
        bytes32 sourceCommitment;
        bytes32 selectionCommitment;
        bytes32 policyCommitment;
        bytes32 requiredRole;
        uint32 effectiveCapabilities;
        bytes32 associationHash;
        PreparedSourcesV3 sources;
    }

    struct CrossOwnerFactsV3 {
        ReceiptPrefix payout;
        PayoutInventoryV3 payoutInventory;
        ResultV3 selection;
    }

    struct PayoutApplyV3 {
        bytes32 artistId;
        bytes32 manifestHash;
        bytes32 actionId;
        bytes32 associationHash;
        bytes32 contextHash;
        bytes32 recoveryRecordHash;
        bytes32 planCommitment;
        ReceiptPrefix source;
        PayoutInventoryV3 beforeInventory;
        FamilySelectionV3 selected;
        bytes32[] supersededPayoutRecordHashes;
    }

    struct PayoutContinuationV3 {
        bytes32 artistId;
        bytes32 recoveryRecordHash;
        bytes32 actionId;
        bytes32 manifestHash;
        bytes32 planCommitment;
        uint64 identityOwnerRevision;
        T.Payout stable;
        T.Payout candidate;
        bytes32 releasedChildRecordHash;
        bytes32 previousContinuationHash;
        uint64 payoutOwnerRevision;
        bytes32 continuationHash;
    }

    struct CapabilityContinuationV3 {
        bytes32 artistId;
        bytes32 originalActivationRecordHash;
        uint32 originalActivationCapabilities;
        bytes32 recoveryRecordHash;
        bytes32 actionId;
        bytes32 manifestHash;
        bytes32 planCommitment;
        bytes32 designationRecordHash;
        bytes32 pairedDirectiveRecordHash;
        bytes32 forbiddenDirectiveRecordHash;
        address authorityAddress;
        uint32 effectiveCapabilities;
        bytes32 commitment;
    }

    /// @notice Exact new branch scope; original revision records and consumed cells remain intact.
    struct RevisionContinuationV3 {
        bytes32 artistId;
        bytes32 recoveryRecordHash;
        bytes32 actionId;
        bytes32 planCommitment;
        bytes32 stableRevisionRecordHash;
        bytes32 stableDocumentHash;
        bytes32 resolvedChildRecordHash;
        uint64 ownerRevision;
        bytes32 continuationHash;
    }

    /// @notice Fresh op51 branch for one actual retirement, never a cleared original replay cell.
    struct StandingContinuationV3 {
        bytes32 artistId;
        address priorAddress;
        bytes32 retirementHash;
        bytes32 recoveryRecordHash;
        bytes32 actionId;
        bytes32 planCommitment;
        bytes32 retainedRevocationRecordHash;
        bytes32 supersededRevocationRecordHash;
        uint64 ownerRevision;
        bytes32 continuationHash;
    }

    error InvalidRecoveryRewindManifest(bytes32 manifestHash);
    error InvalidRecoveryRewindAppeal(bytes32 documentHash);
    error InvalidRecoveryPayoutOriginal(bytes32 recordHash);
    error RecoveryRewindDependencyChanged(address target);
    error InvalidRecoveryRewindRecord(bytes32 recordHash);
    error InvalidRecoveryRewindSelection(bytes32 key);
    error InvalidRecoveryRewindPreparation(bytes32 actionId);

    function requestCommitment(Recovery.Request memory request) internal pure returns (bytes32) {
        return Appeal.requestCommitment(request);
    }

    function selectionSourceHash(EnvironmentV3 memory e, BasisV3 memory b)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_SOURCE_V3"),
                uint16(3),
                e,
                b.identity,
                b.payoutCodeHash,
                b.payout,
                b.payoutInventory
            )
        );
    }

    function selectionKey(EnvironmentV3 memory e, BasisV3 memory b)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_SELECTION_KEY_V3"), uint16(3), e, b
            )
        );
    }

    function selectionInventoryHash(
        EnvironmentV3 memory e,
        IdentityInventoryV3 memory identity,
        PayoutInventoryV3 memory payout
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_INVENTORY_V3"),
                uint16(3),
                e,
                identity,
                payout
            )
        );
    }

    function selectionResultHash(EnvironmentV3 memory e, ResultV3 memory r)
        internal
        pure
        returns (bytes32)
    {
        ResultV3 memory value = ResultV3(
            r.sourceKey,
            r.manifestHash,
            r.sourceCommitment,
            r.inventoryCommitment,
            r.guardians,
            r.designation,
            r.directive,
            r.identityRevision,
            r.payout,
            r.sanctionGrant,
            r.standing,
            bytes32(0)
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_SELECTION_RESULT_V3"),
                uint16(3),
                e,
                value
            )
        );
    }

    function preparationSealHash(EnvironmentV3 memory e, PreparationSealV3 memory s)
        internal
        pure
        returns (bytes32)
    {
        PreparationSealV3 memory value = PreparationSealV3(
            s.manifestHash,
            s.sourceKey,
            s.actionId,
            s.associationHash,
            s.identityBefore,
            s.identityAfterPreparation,
            s.payout,
            s.evidenceStateHash,
            bytes32(0)
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REWIND_PREPARATION_SEAL_V3"),
                uint16(3),
                e,
                value
            )
        );
    }

    function manifestHash(EnvironmentV3 memory e, ResolutionManifestV3 memory manifest)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_RESOLUTION_MANIFEST_V3"),
                uint16(3),
                e,
                manifest
            )
        );
    }

    function appealHash(EnvironmentV3 memory e, AppealDocumentV3 memory document)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_HOSTILE_GUARDIAN_EVIDENCE_V3"), uint16(3), e, document
            )
        );
    }

    function payoutOriginalHash(EnvironmentV3 memory e, PayoutOriginalV3 memory original)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_PAYOUT_ORIGINAL_V3"), uint16(3), e, original
            )
        );
    }

    /// @dev The hash field itself is omitted; ownerRevision is the actual recovery write revision.
    function revisionContinuationHash(EnvironmentV3 memory e, RevisionContinuationV3 memory c)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_REVISION_CONTINUATION_V3"),
                uint16(3),
                e,
                c.artistId,
                c.recoveryRecordHash,
                c.actionId,
                c.planCommitment,
                c.stableRevisionRecordHash,
                c.stableDocumentHash,
                c.resolvedChildRecordHash,
                c.ownerRevision
            )
        );
    }

    function standingContinuationHash(EnvironmentV3 memory e, StandingContinuationV3 memory c)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_STANDING_CONTINUATION_V3"),
                uint16(3),
                e,
                c.artistId,
                c.priorAddress,
                c.retirementHash,
                c.recoveryRecordHash,
                c.actionId,
                c.planCommitment,
                c.retainedRevocationRecordHash,
                c.supersededRevocationRecordHash,
                c.ownerRevision
            )
        );
    }

    function payoutContinuationHash(EnvironmentV3 memory e, PayoutContinuationV3 memory c)
        internal
        pure
        returns (bytes32)
    {
        PayoutContinuationV3 memory value = PayoutContinuationV3(
            c.artistId,
            c.recoveryRecordHash,
            c.actionId,
            c.manifestHash,
            c.planCommitment,
            c.identityOwnerRevision,
            c.stable,
            c.candidate,
            c.releasedChildRecordHash,
            c.previousContinuationHash,
            c.payoutOwnerRevision,
            bytes32(0)
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_PAYOUT_CONTINUATION_V3"), uint16(3), e, value
            )
        );
    }

    function capabilityContinuationHash(EnvironmentV3 memory e, CapabilityContinuationV3 memory c)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_CAPABILITY_CONTINUATION_V3"),
                uint16(3),
                e,
                c.artistId,
                c.originalActivationRecordHash,
                c.originalActivationCapabilities,
                c.recoveryRecordHash,
                c.actionId,
                c.manifestHash,
                c.planCommitment,
                c.designationRecordHash,
                c.pairedDirectiveRecordHash,
                c.forbiddenDirectiveRecordHash,
                c.authorityAddress,
                c.effectiveCapabilities
            )
        );
    }
}
