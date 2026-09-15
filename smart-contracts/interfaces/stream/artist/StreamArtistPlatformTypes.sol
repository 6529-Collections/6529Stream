// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice AA-PLATFORM history, separate from every Artist binding and signature domain.
library StreamArtistPlatformTypes {
    error InvalidPlatformWorks(uint256 collectionId);
    error InvalidPlatformEvidence(bytes32 evidenceHash);

    // Numeric contest vocabulary: zero NONE, one CONTESTED, two DISMISSED, three SUSTAINED.
    struct Declaration {
        bytes32 recordHash;
        bytes32 statementHash;
        address actor;
        uint64 declaredAt;
    }

    struct Claim {
        uint256 collectionId;
        address claimant;
        address proposedArtist;
        bytes32 evidenceHash;
        bytes32 reasonHash;
        uint64 filedAt;
        bytes32 recordHash;
    }

    struct Contest {
        uint256 collectionId;
        address adjudicatedArtist;
        uint8 state;
        bytes32 claimRecordHash;
        bytes32 evidenceHash;
        bytes32 reasonHash;
        bytes32 actionId;
        bytes32 previousRecordHash;
        uint64 changedAt;
        bytes32 recordHash;
    }

    struct Correction {
        uint256 collectionId;
        address proposedArtist;
        bytes32 claimRecordHash;
        bytes32 sustainedContestRecordHash;
        bytes32 evidenceHash;
        bytes32 reasonHash;
        bytes32 approvalActionId;
        uint64 approvedAt;
        uint64 correctiveGeneration;
        bool accepted;
        bytes32 recordHash;
    }

    /// @dev Canonical fixed binary document. Publication does not establish truth or authority.
    struct Evidence {
        uint16 schemaVersion;
        uint256 collectionId;
        address proposedArtist;
        bytes32 claimRecordHash;
        bytes32 narrativeHash;
    }

    struct State {
        Declaration declaration;
        uint8 contestState;
        bytes32 contestClaim;
        bytes32 contestRecord;
        uint256 claimCount;
        bytes32 latestClaim;
        Correction correction;
    }

    struct Admission {
        bytes32 declarationHash;
        uint8 contestState;
        uint64 correctiveGeneration;
        bool corrected;
    }

    struct Context {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
    }
}
