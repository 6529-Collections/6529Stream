// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistGuardianHistoryTypes as H } from "./StreamArtistGuardianHistoryTypes.sol";

/// @notice Owner-authenticated recovery adjudication and its exact guardian admission prefix.
library StreamArtistRecoverySelectionTypesV2 {
    struct Basis {
        bytes32 manifestHash;
        bytes32 artistId;
        bytes32 ownerCodeHash;
        H.Head history;
        bytes32 sourceCommitment;
    }
}
