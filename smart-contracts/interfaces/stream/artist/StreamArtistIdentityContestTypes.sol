// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Direct compromise filings and exact staged-governance evidence for operation 33.
library StreamArtistIdentityContestTypes {
    struct Request {
        bytes32 artistId;
        bytes32 subjectRecordHash;
        bytes32 evidenceHash;
        bytes32 reasonHash;
    }

    struct GovernanceWitness {
        bytes32 actionId;
        address proposer;
        uint8 actionClass;
        bytes32 roleMutationHash;
        uint64 roleRevision;
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
    }

    /// @dev Supplemental fields do not change the permanent contest record preimage.
    struct Record {
        bytes32 recordHash;
        Request terms;
        address contester;
        uint64 contestedAt;
        uint8 priorStatus;
        bytes32 guardianSetRecordHash;
        bytes32 capturedGuardianSetRecordHash;
        bytes32 pendingTransitionRecordHash;
        bytes32 executedTransitionRecordHash;
        bytes32 governanceWitnessHash;
    }

    error InvalidIdentityContest(bytes32 artistId);
    error InvalidContestSubject(bytes32 subjectRecordHash);
    error InvalidContestGovernance();
}
