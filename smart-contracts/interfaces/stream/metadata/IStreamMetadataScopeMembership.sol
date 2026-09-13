// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../finality/StreamArtworkFinalityTypes.sol";

/// @notice Scope membership from this Router's original provider's fixed authoritative host.
/// @dev Read-only membership grants no view-content adoption, artist approval or new finality.
interface IStreamMetadataScopeMembership {
    function scopeCoversToken(StreamFinalityScope calldata scope, uint256 tokenId)
        external
        view
        returns (bool);
    function scopeTokenAt(StreamFinalityScope calldata scope, uint256 index)
        external
        view
        returns (uint256);
}
