// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCoreConservationTier.sol";

/// @notice Closed CMC-MUSEUM-GRADE vocabulary. The effective default uses completed mints only.
library StreamConservationTiers {
    bytes32 internal constant MUSEUM_GRADE = keccak256("MUSEUM_GRADE");
    bytes32 internal constant MUSEUM_GRADE_LITE = keccak256("MUSEUM_GRADE_LITE");
    bytes32 internal constant CONSERVATION_WAIVED = keccak256("CONSERVATION_WAIVED");

    function requireKnown(bytes32 tier) internal pure {
        if (tier != MUSEUM_GRADE && tier != MUSEUM_GRADE_LITE && tier != CONSERVATION_WAIVED) {
            revert IStreamCoreConservationTier.InvalidConservationTier(tier);
        }
    }

    function effective(bytes32 declared, uint256 completedMints) internal pure returns (bytes32) {
        if (declared != 0) {
            requireKnown(declared);
            return declared;
        }
        return completedMints == 0 ? bytes32(0) : MUSEUM_GRADE_LITE;
    }
}
