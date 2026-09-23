// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationFloorTypes.sol";

/// @notice Actual current release sources, before prospective evidence is prepared.
/// @dev A diagnostic only: it neither certifies a floor nor consumes reference evidence.
/// Source/profile pins and full semantic membership are checked by the original provider.
interface IStreamConservationReleaseContext {
    function currentReleaseContext(uint256 collectionId)
        external
        view
        returns (StreamConservationFloorTypes.ReleaseContext memory);
}
