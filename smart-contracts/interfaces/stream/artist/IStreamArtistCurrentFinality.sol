// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistCurrentAuthorityTypes as C } from "./StreamArtistCurrentAuthorityTypes.sol";

/// @notice Explicit reciprocal route on the current suite's actual Coordinator.
interface IStreamArtistCurrentFinality {
    function currentFinalityRoute(uint256 collectionId) external view returns (C.Route memory);
}
