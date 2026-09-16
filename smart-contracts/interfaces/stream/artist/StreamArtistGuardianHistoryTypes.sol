// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Supplemental owner-authenticated admission order; permanent guardian hashes are unchanged.
library StreamArtistGuardianHistoryTypes {
    struct Head {
        uint64 count;
        uint64 ownerRevision;
        bytes32 commitment;
    }

    struct Entry {
        bytes32 artistId;
        uint64 index;
        uint64 ownerRevision;
        bytes32 recordHash;
        bytes32 recordDataHash;
        bytes32 previousCommitment;
        bytes32 commitment;
    }

    struct Snapshot {
        bytes32 artistId;
        uint64 count;
        bytes32 historyCommitment;
        bytes32 associationHash;
    }
    error InvalidGuardianHistory(bytes32 artistId);
    error InvalidGuardianHistorySnapshot(bytes32 actionId);
}
