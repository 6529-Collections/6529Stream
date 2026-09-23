// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Supplemental adjudication coordinates; original record hashes stay permanent.
library StreamArtistGuardianSupersessionTypes {
    struct IndexHead {
        uint64 count;
        bytes32 historyCommitment;
    }

    struct Plan {
        bytes32 artistId;
        bytes32 associationHash;
        bytes32 contextCommitment;
        uint64 count;
        bytes32 historyCommitment;
        bytes32[] excluded;
    }

    struct Status {
        bytes32 artistId;
        bytes32 recoveryRecordHash;
        bytes32 actionId;
    }

    error InvalidGuardianSupersession(bytes32 recordHash);
    error IncompleteGuardianMembershipIndex(bytes32 artistId);
}
