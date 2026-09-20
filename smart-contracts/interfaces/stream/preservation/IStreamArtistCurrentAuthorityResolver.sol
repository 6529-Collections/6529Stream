// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCurrentAuthorityTypes as C
} from "../artist/StreamArtistCurrentAuthorityTypes.sol";

/// @notice Pinned original anchors with authenticated, dynamically Core-selected successors.
interface IStreamArtistCurrentAuthorityResolver {
    function currentAuthorityProfile() external view returns (bytes32);
    function anchors() external view returns (C.Anchors memory);
    function currentSelection() external view returns (C.Selection memory);
    // Nonrecursive: validates Finality's fixed capability, never calls its dynamic route.
    function currentFinalityRoute(uint256 collectionId) external view returns (C.Route memory);
}
