// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistGuardianHistoryTypes as H } from "./StreamArtistGuardianHistoryTypes.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";

/// @notice Complete guardian election over one immutable, temporally stable history prefix.
library StreamArtistGuardianSelectionTypes {
    struct Basis {
        bytes32 artistId;
        bytes32 ownerCodeHash;
        H.Head history;
        R.TransitionState transition;
        bytes32 excludedRecordsHash;
    }

    struct Progress {
        uint64 processed;
        uint64 lastOwnerRevision;
        bytes32 historyTip;
        uint64 excludedSeen;
        bytes32 selectedRecordHash;
        bytes32 selectedDataHash;
        uint256 selectedNonce;
        bool complete;
    }

    struct Result {
        bytes32 sourceKey;
        bytes32 selectedRecordHash;
        bytes32 selectedDataHash;
        uint256 selectedNonce;
        bytes32 commitment;
    }

    error InvalidGuardianSelection(bytes32 key);
    error IncompleteGuardianSelection(bytes32 key, uint64 processed, uint64 required);
}
