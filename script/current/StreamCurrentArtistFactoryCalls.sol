// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice The fixed Artist factory calls used by the current graph recipe.
/// @dev Keeps the recipe independent of the factory's construction import graph.
/// The concrete factory and every constructed product remain required artifacts.
interface StreamCurrentArtistFactoryCalls {
    function deployIdentity(uint8 kind, address[6] calldata pins) external returns (address child);

    function deployRegistry(uint8 kind, address host, address coordinator)
        external
        returns (address child);
}
