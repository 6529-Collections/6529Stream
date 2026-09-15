// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Live AA-DISPLAY profile. It does not encode selected historical rendering inputs.
library StreamArtistDisplayTypes {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_LIVE_ARTIST_DISPLAY_V1");

    struct Collaborator {
        address account;
        bytes32 artistId;
        bytes32 role;
        string name;
        bytes32 identityRecord;
    }

    struct Facts {
        uint8 state;
        bool platform;
        uint8 consentMode;
        bytes32 artistId;
        address artist;
        string name;
        bytes32 identityRecord;
        uint64 generation;
        bool corrected;
        bytes32 deploymentRecord;
        Collaborator[] collaborators;
        uint8 attestationStatus;
        bytes32 attestationRecord;
        bytes32 attestedHash;
        uint8 attestationClass;
        bytes32 sanctionRecord;
        uint8 sanctionClass;
        bool hasPlatformHistory;
        bool contested;
        bytes32 contestRecord;
        uint256 claimCount;
        bytes32 latestClaim;
    }
    error DisplayFactsUnavailable();
}
