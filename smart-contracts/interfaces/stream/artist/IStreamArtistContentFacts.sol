// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Live content commitment supplied by the actual selected metadata router.
interface IStreamArtistContentFacts {
    /// @notice Returns the actual metadata host and its canonical current content commitment.
    /// @dev The artist coordinator separately verifies this host equals Core's active router.
    function currentArtistContentState(uint256 collectionId)
        external
        view
        returns (address metadataContract, bytes32 contentStateHash);
}
