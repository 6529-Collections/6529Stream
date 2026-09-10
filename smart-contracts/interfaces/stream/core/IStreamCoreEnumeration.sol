// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Global live supply and current allocation frontiers.
interface IStreamCoreEnumeration {
    /// @notice Returns the live ERC-721 supply, excluding prepared and burned tokens.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the current token allocation frontier; aborting a preparation can rewind it.
    function lastAllocatedTokenId() external view returns (uint256);

    /// @notice Returns the highest collection identifier allocated by Core.
    function lastAllocatedCollectionId() external view returns (uint256);
}
