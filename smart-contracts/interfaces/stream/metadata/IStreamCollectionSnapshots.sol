// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSnapshotTypes.sol";
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Original attributed native snapshots, immutable bytes and explicit current adoption.
/// @dev These heads never select token rendering. Locks apply to this snapshot host only.
interface IStreamCollectionSnapshots is IERC165 {
    event CollectionSnapshotPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed snapshotId,
        bytes32 indexed recordHash,
        StreamSnapshotTypes.Receipt receipt,
        string manifestURI,
        address firstManifestPointer
    );
    event CollectionSnapshotLocked(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed lockId,
        bytes32 indexed actionId,
        bytes32 recordHash,
        uint64 revision
    );

    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function metadataRouter() external view returns (address);
    function schemaRegistry() external view returns (address);
    function chunkStore() external view returns (address);
    function dependencies() external view returns (StreamSnapshotTypes.Dependencies memory);
    function previewSnapshot(
        StreamSnapshotTypes.Publication calldata publication,
        address publisher
    ) external view returns (bytes32 sourceHash, bytes memory canonicalManifest);
    function publishSnapshot(StreamSnapshotTypes.Publication calldata publication)
        external
        returns (bytes32 recordHash);
    function currentSnapshot(uint256 collectionId)
        external
        view
        returns (StreamSnapshotTypes.Receipt memory);
    function snapshotRecord(bytes32 recordHash)
        external
        view
        returns (StreamSnapshotTypes.Publication memory, StreamSnapshotTypes.Receipt memory);
    function snapshotHash(uint256 collectionId, bytes32 snapshotId) external view returns (bytes32);
    function latestSnapshotHash(uint256 collectionId) external view returns (bytes32);
    function snapshotCount(uint256 collectionId) external view returns (uint256);
    function snapshotRecordAt(uint256 collectionId, uint256 index) external view returns (bytes32);
    function snapshotManifestBytes(bytes32 recordHash) external view returns (bytes memory);
    /// @notice First immutable segment; use chunkCount/chunkAt to reconstruct multi-segment bytes.
    function snapshotManifestPointer(uint256 collectionId, bytes32 snapshotId)
        external
        view
        returns (address);
    function snapshotManifestChunkCount(bytes32 recordHash) external view returns (uint256);
    function snapshotManifestChunkAt(bytes32 recordHash, uint256 index)
        external
        view
        returns (bytes32 chunkHash, address pointer, uint32 length);
    function requireCurrent(uint256 collectionId, bytes32 recordHash, uint64 revision)
        external
        view
        returns (StreamSnapshotTypes.Receipt memory);
    function requireLocked(uint256 collectionId, bytes32 recordHash, uint64 revision)
        external
        view
        returns (StreamSnapshotTypes.Receipt memory);
    function lockTransition(uint256 collectionId, bytes32 lockId)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function lockSnapshots(uint256 collectionId, bytes32 lockId) external;
    function snapshotLock(uint256 collectionId, bytes32 lockId)
        external
        view
        returns (StreamSnapshotTypes.Lock memory);
}
