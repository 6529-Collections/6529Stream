// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Typed content operations; Core and registry identity come from the immutable artist suite.
library StreamArtistContentTypes {
    struct Consent {
        uint256 collectionId;
        address metadataContract;
        bytes32 familyId;
        bytes32 newStateHash;
    }

    struct Freeze {
        uint256 collectionId;
        address metadataContract;
        bytes32[] lockClasses;
        bytes32 expectedStateHash;
    }

    /// @notice Permanent authorization facts, distinct from the host's later one-way lock application.
    struct FreezeRecord {
        bytes32 recordHash;
        bytes32 artistId;
        uint64 bindingGeneration;
        address metadataContract;
        bytes32[] lockClasses;
        bytes32 expectedStateHash;
        uint8 authorityClass;
    }
}
