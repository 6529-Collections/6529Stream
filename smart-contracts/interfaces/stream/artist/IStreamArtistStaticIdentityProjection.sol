// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Permissionless display projection, separate from signed authority and Archive operations.
interface IStreamArtistStaticIdentityProjection {
    error StaticIdentityMaturityUnavailable(bytes32 artistId, bytes32 candidate);
    function checkpointStaticIdentityMaturity(bytes32 artistId)
        external
        returns (bytes32 checkpoint);
}
