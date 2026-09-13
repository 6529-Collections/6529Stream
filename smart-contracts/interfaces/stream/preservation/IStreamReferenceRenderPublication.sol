// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamReferenceRenderTypes } from "./StreamReferenceRenderTypes.sol";
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Original curator reference observations; publishing never changes rendered content.
interface IStreamReferenceRenderPublication is IERC165 {
    event ReferenceRenderPublished(
        bytes32 indexed recordHash,
        uint256 indexed collectionId,
        bytes32 indexed referenceId,
        StreamReferenceRenderTypes.Receipt receipt,
        string manifestURI
    );
    event ReferenceRenderLocked(
        bytes32 indexed recordHash,
        uint256 indexed collectionId,
        bytes32 indexed actionId,
        uint64 revision
    );

    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function metadataRouter() external view returns (address);
    function snapshots() external view returns (address);
    function archiveCoverage() external view returns (address);
    function dependencies() external view returns (StreamReferenceRenderTypes.Dependencies memory);
    /// @notice Permissionless exact inventory preparation; it confers no reference authority.
    function prepareFileInventory(
        StreamReferenceRenderTypes.PackageFile[] calldata rows,
        bool relative
    ) external returns (bytes32 inventoryId);
    function preparedFileInventory(bytes32 inventoryId) external view returns (bytes memory);
    function previewReference(
        StreamReferenceRenderTypes.Publication calldata publication,
        address recorder
    ) external view returns (bytes32 sourcesHash, bytes memory canonicalPayload);
    function publishReference(StreamReferenceRenderTypes.Publication calldata publication)
        external
        returns (bytes32);
    function currentReference(uint256 collectionId)
        external
        view
        returns (StreamReferenceRenderTypes.Receipt memory);
    function referenceRecord(bytes32 hash)
        external
        view
        returns (
            StreamReferenceRenderTypes.Publication memory,
            StreamReferenceRenderTypes.Receipt memory
        );
    function referencePayload(bytes32 hash) external view returns (bytes memory);
    function referenceCount(uint256 collectionId) external view returns (uint256);
    function referenceAt(uint256 collectionId, uint256 index) external view returns (bytes32);
    function requireCurrent(uint256 collectionId, bytes32 hash, uint64 revision)
        external
        view
        returns (StreamReferenceRenderTypes.Receipt memory);
    function referenceLock(uint256 collectionId)
        external
        view
        returns (StreamReferenceRenderTypes.Lock memory);
    function lockTransition(uint256 collectionId)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function lockReference(uint256 collectionId) external;
}
