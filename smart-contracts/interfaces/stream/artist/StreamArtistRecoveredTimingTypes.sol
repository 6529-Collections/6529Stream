// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Separate complete operational timing evidence; original owner checkpoints stay V1.
library StreamArtistRecoveredTimingTypes {
    bytes32 internal constant SCHEMA = keccak256("6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1");
    uint16 internal constant VERSION = 1;
    uint256 internal constant MAX_ENTRIES = 1024;

    // Value order: rotation contest, standing tail, estate notice, dormant inactivity,
    // dormant notice, unavailability notice, repudiation contest.
    // Revision groups: rotation, estate, dormancy, unavailability, repudiation.
    struct Configuration {
        uint64[7] values;
        uint64[5] revisions;
    }

    struct Input {
        bytes32 parameter;
        bytes32 actionId;
        bytes32 actionKey;
        bytes32 oldHash;
        bytes32 newHash;
        uint64 oldValue;
        uint64 newValue;
        uint64 floor;
        uint64 oldRevision;
        uint64 newRevision;
    }

    struct Entry {
        uint256 chainId;
        address owner;
        uint256 index;
        Input change;
        bytes32 previousCommitment;
        bytes32 commitment;
    }

    struct Checkpoint {
        bytes32 schema;
        uint16 version;
        uint256 count;
        bytes32 root;
        bytes32 configurationHash;
    }

    struct Bundle {
        Configuration configuration;
        Entry[] entries;
        Checkpoint checkpoint;
    }
    error RecoveredTimingUnavailable();
    error InvalidRecoveredTiming(bytes32 key);
}

interface IStreamArtistRecoveredTimingInventory {
    function recoveredTimingCheckpoint()
        external
        view
        returns (StreamArtistRecoveredTimingTypes.Checkpoint memory);
    function recoveredTimingEntryAt(uint256 index)
        external
        view
        returns (StreamArtistRecoveredTimingTypes.Entry memory);
}
