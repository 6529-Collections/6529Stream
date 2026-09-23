// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamCollectionArtistRegistry.sol";

/// @notice Narrow attribution reads shared by the immutable-attribution and modular artist lines.
/// @dev No nomination, signature nonce or acceptance mutation API is implied by this subset.
interface IStreamArtistAttribution {
    function core() external view returns (address);
    function acceptedArtist(uint256 collectionId) external view returns (address);
    /// @notice Returns the actual binding and acceptance facts in the established read layout.
    /// @dev identityHash=document hash; nominationHash=binding hash; acceptanceHash=acceptance
    ///      record; nominationRevision=binding generation; acceptedAt=acceptance block timestamp.
    function attribution(uint256 collectionId)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory);
}
