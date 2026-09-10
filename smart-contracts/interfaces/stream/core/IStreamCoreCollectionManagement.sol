// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamCoreCollectionView.sol";

/// @notice Governed creation and lifecycle changes for permanent collections.
interface IStreamCoreCollectionManagement is IStreamCoreCollectionView {
    event StreamCollectionCreated(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed actionId,
        uint8 supplyMode,
        bool hasMaxSupply,
        uint256 maxSupply,
        uint8 initialStatus
    );

    event StreamCollectionStatusUpdated(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed actionId,
        uint8 oldStatus,
        uint8 newStatus
    );

    event StreamCollectionMaxSupplyUpdated(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed actionId,
        uint256 oldMaxSupply,
        uint256 newMaxSupply
    );

    event CollectionFrozen(
        uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed actionId
    );

    /// @notice Creates a collection through an authorized governance action.
    function createCollection(
        uint8 supplyMode,
        bool hasMaxSupply,
        uint256 maxSupply,
        uint8 initialStatus
    ) external returns (uint256 collectionId);

    /// @notice Applies the governed lifecycle transition for a collection.
    function setCollectionStatus(uint256 collectionId, uint8 status) external;

    /// @notice Applies a governed change to the collection lifetime mint cap.
    function setCollectionMaxSupply(uint256 collectionId, uint256 newMaxSupply) external;

    /// @notice Permanently freezes collection configuration through terminal governance.
    function freezeCollection(uint256 collectionId) external;
}
