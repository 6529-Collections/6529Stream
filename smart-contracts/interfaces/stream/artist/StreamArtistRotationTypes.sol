// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Typed current-principal rotation facts; canonical records keep their frozen preimages.
library StreamArtistRotationTypes {
    struct GuardianSet {
        bytes32 artistId;
        address[] guardians;
        uint32 approvalThreshold;
        uint64 minContestSeconds;
    }

    struct Rotation {
        bytes32 artistId;
        address oldAddress;
        address newAddress;
        bytes32 reasonHash;
        // Checked concurrency guard, not a field in either permanent signed schema.
        bytes32 expectedPreviousTransitionRecordHash;
    }

    struct StandingRevocation {
        bytes32 artistId;
        address revokedAddress;
        bytes32 reasonHash;
        // Checked against actual retirement, outside the permanent signed schema.
        bytes32 retiredTransitionRecordHash;
    }

    /// @notice Immutable association captured when a provisional record is written.
    struct ProvisionalAssociation {
        bytes32 transitionRecordHash;
        uint64 windowEndsAt;
    }

    /// @notice Actual Identity-owned state, never a caller's readiness assertion.
    /// @dev phase: 0 absent, 1 staged, 2 executed, 3 vetoed. Contest does not time out.
    struct TransitionState {
        bytes32 artistId;
        bytes32 recordHash;
        uint64 stagedAt;
        uint64 contestEndsAt;
        uint64 executedAt;
        uint64 postWindowEndsAt;
        uint64 contestedAt;
        uint8 phase;
    }

    struct GuardianRecord {
        bytes32 recordHash;
        GuardianSet terms;
        address signer;
        uint8 authorityClass;
        uint256 nonce;
        uint64 signedAt;
        bytes32 previousOperativeRecordHash;
        ProvisionalAssociation provisional;
    }

    struct RotationRecord {
        bytes32 recordHash;
        Rotation terms;
        bytes32 guardianSetRecordHash;
        uint32 approvalThreshold;
        uint32 guardianApprovals;
        uint256 oldNonce;
        uint256 newNonce;
        uint64 effectiveWindow;
        uint64 standingTail;
        uint64 timingRevision;
        TransitionState transition;
    }

    struct StandingRecord {
        bytes32 recordHash;
        StandingRevocation terms;
        address signer;
        uint8 authorityClass;
        uint256 nonce;
        uint64 signedAt;
    }

    /// @notice Coordinator-snapshotted operative authority, separate from historical Binding.
    struct AuthorityFact {
        bytes32 artistId;
        address authorityAddress;
        uint8 authorityClass;
        uint8 status;
    }

    function eligible(
        bytes32 artistId,
        ProvisionalAssociation memory a,
        TransitionState memory t,
        uint256 timestamp
    ) internal pure returns (bool) {
        if (a.transitionRecordHash == bytes32(0)) {
            return a.windowEndsAt == 0;
        }
        return t.artistId == artistId && t.recordHash == a.transitionRecordHash && t.phase == 2
            && t.executedAt != 0 && t.postWindowEndsAt == a.windowEndsAt
            && (t.contestedAt == 0 || t.contestedAt >= a.windowEndsAt)
            && timestamp >= a.windowEndsAt;
    }

    error InvalidGuardianSet();
    error InvalidRotation(bytes32 rotationRecordHash);
    error ActiveAuthorityWindow(bytes32 transitionRecordHash, uint64 windowEndsAt);
    error RotationNotExecutable(bytes32 rotationRecordHash);
    error InvalidPriorStanding(address priorAddress);
    error ProvisionalChainOccupied(bytes32 recordHash);
    error PayoutRequiresAuthorityContext(bytes32 artistId);
    error InvalidArtistWindow(bytes32 parameter);
    error InvalidArtistWindowContext();
}
