// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Composes actual attribution and identity state without conflating their different enums.
interface IStreamArtistAttributionState {
    /// @dev Attribution: 0 none, 1 claimed, 2 artist accepted, 3 sanctioned, 4 disputed, 5 revoked.
    ///      Authority status is a separate Identity fact; its status4 is an authority contest.
    ///      No failed mint read or absent artist is translated into disputed/revoked state.
    function collectionArtistState(uint256 collectionId)
        external
        view
        returns (
            uint8 attributionState,
            uint64 bindingGeneration,
            bytes32 artistId,
            uint8 authorityStatus,
            bytes32 bindingHash
        );
}
