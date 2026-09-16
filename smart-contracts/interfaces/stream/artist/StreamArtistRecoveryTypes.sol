// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Permanent artist recovery approval and unavailability finding records.
/// @dev Admission evidence is stored separately from the permanently specified hash preimages.
library StreamArtistRecoveryTypes {
    struct ApprovalTerms {
        address finalityRegistry;
        uint256 collectionId;
        bytes32 finalityRecordHash;
        bytes32 recoveryManifestHash;
    }

    /// @notice The saved authority and association describe admission, not future signer readiness.
    struct ApprovalRecord {
        bytes32 recordHash;
        ApprovalTerms terms;
        bytes32 artistId;
        address signer;
        uint8 authorityClass;
        uint256 nonce;
        uint64 signedAt;
        uint64 deadline;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        bytes32 digest;
    }

    struct FindingRequest {
        bytes32 artistId;
        uint256 collectionId;
        bytes32 evidenceHash;
        bytes32 reasonHash;
    }

    /// @notice Observed times and captured timing configuration remain immutable.
    /// @dev Only terms, governanceActionId, noticeEndsAt and recordedAt enter the ten-word record.
    struct FindingRecord {
        bytes32 recordHash;
        FindingRequest terms;
        bytes32 governanceActionId;
        uint64 noticeEndsAt;
        uint64 recordedAt;
        uint64 noticeSeconds;
        uint64 timingRevision;
        uint64 bindingGeneration;
        bytes32 bindingHash;
    }

    error InvalidRecoveryApproval();
    error InvalidUnavailabilityFinding();
}
