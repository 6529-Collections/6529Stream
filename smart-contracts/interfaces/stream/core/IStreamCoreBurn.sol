// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Token-owner burns and the permanent collection burn block.
interface IStreamCoreBurn {
    event CollectionBurnsBlocked(
        uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed actionId
    );

    event StreamTokenBurned(
        uint256 indexed tokenId,
        uint256 indexed collectionId,
        uint256 collectionSerial,
        uint16 schemaVersion
    );

    /// @notice Burns a token for its owner or approved operator unless burns or the collection are frozen.
    function burn(uint256 tokenId) external;

    /// @notice Permanently prevents future burns in a collection through governance.
    function blockCollectionBurns(uint256 collectionId) external;

    /// @notice Returns whether the collection burn block has been set.
    function collectionBurnsBlocked(uint256 collectionId) external view returns (bool);

    /// @notice Returns the block number of the permanent burn block, or zero if unset.
    function collectionBurnsBlockedAtBlock(uint256 collectionId) external view returns (uint64);
}
