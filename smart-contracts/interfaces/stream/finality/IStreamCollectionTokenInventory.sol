// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Append-only enumeration of completed collection mints, including burned tokens.
/// @dev An inventory prefix is historical evidence, not a claim of current completeness or finality.
interface IStreamCollectionTokenInventory {
    error InvalidInventoryConfiguration();
    error InventoryCoreChanged();
    error InventoryCoreReadFailed(bytes4 selector);
    error InventoryCollectionUnknown(uint256 collectionId);
    error InventoryBatchSize(uint256 size);
    error InventoryTokenMismatch(uint256 tokenId, uint256 expectedCollectionSerial);
    error InventoryIncomplete(uint256 collectionId, uint256 indexedCount, uint256 mintedCount);
    error InventoryIndexOutOfBounds(uint256 collectionId, uint256 index);

    event CollectionTokenIndexed(
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        uint256 collectionSerial,
        bytes32 prefixHash
    );

    function core() external view returns (address);

    /// @notice Index the next consecutive collection serials from the actual Core.
    /// @dev Anyone, including a Safe, may submit 1..256 token IDs. The complete batch is atomic.
    function appendCollectionTokens(uint256 collectionId, uint256[] calldata tokenIds) external;

    /// @notice Retained prefix length and hash; does not read current Core state.
    function collectionInventoryState(uint256 collectionId)
        external
        view
        returns (uint256 indexedCount, bytes32 prefixHash);

    /// @notice Token ID at a zero-based index; collection serial is index + 1.
    function collectionTokenAt(uint256 collectionId, uint256 index)
        external
        view
        returns (uint256 tokenId);

    /// @notice Require a known collection and an inventory of every completed mint at this call.
    /// @dev Later mints invalidate completeness until indexed. Burns never remove membership.
    function requireCompleteCollection(uint256 collectionId)
        external
        view
        returns (uint256 tokenCount, bytes32 prefixHash);
}
