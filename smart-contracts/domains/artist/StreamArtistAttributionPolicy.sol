// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Attribution lifecycle eligibility only; Identity and authority capabilities remain separate.
library StreamArtistAttributionPolicy {
    function acceptedOrSanctioned(uint8 attributionState) internal pure returns (bool) {
        return attributionState == 2 || attributionState == 3;
    }
}
