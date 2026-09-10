// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Collection existence, supply accounting, status, and freeze reads.
interface IStreamCoreCollectionView {
    /// @notice Returns whether the collection identifier has been allocated.
    function collectionExists(uint256 collectionId) external view returns (bool);

    /// @notice Returns the collection supply-mode code fixed at creation.
    function collectionSupplyMode(uint256 collectionId) external view returns (uint8);

    /// @notice Returns the current collection lifecycle/status code.
    function collectionStatus(uint256 collectionId) external view returns (uint8);

    /// @notice Returns whether a finite maximum applies to this collection.
    function collectionHasMaxSupply(uint256 collectionId) external view returns (bool);

    /// @notice Returns the configured lifetime mint cap in tokens.
    function collectionMaxSupply(uint256 collectionId) external view returns (uint256);

    /// @notice Returns the number of completed mints; burns do not reduce this count.
    function collectionMintedEver(uint256 collectionId) external view returns (uint256);

    /// @notice Returns the next collection-local serial available for allocation.
    function collectionNextSerial(uint256 collectionId) external view returns (uint256);

    /// @notice Returns the collection live token count, excluding burned tokens.
    function totalSupplyOfCollection(uint256 collectionId) external view returns (uint256);

    /// @notice Returns whether collection configuration has been permanently frozen.
    function collectionFreezeStatus(uint256 collectionId) external view returns (bool);
}
