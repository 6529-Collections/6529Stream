// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "../preservation/IStreamPreservationRecords.sol";

/// @notice Retained alternate-view declarations. Selection never changes a renderer or tokenURI.
interface IStreamCollectionViews is IERC165 {
    struct CollectionViewManifest {
        bytes32 viewId;
        bytes32 schemaId;
        string uri;
        bytes32 contentHash;
        string mimeType;
        bool defaultForView;
    }

    struct ViewReceipt {
        uint256 collectionId;
        bytes32 viewId;
        uint64 revision;
        bytes32 previousRecordHash;
        address recorder;
        uint8 authorizationClass;
        uint256 grantCollectionId;
        uint64 grantRevision;
        uint64 recordedAt;
        uint64 recordIndex;
        bytes32 recordChainHash;
        bytes32 viewSchemaDefinitionHash;
        bytes32 manifestSchemaDefinitionHash;
        bytes32 canonicalizationDefinitionHash;
    }
    error InvalidViewConfiguration();
    error InvalidViewManifest();
    error ViewDependencyChanged(address dependency);
    error ViewReadFailed(address dependency);
    error ViewHostNotSelected();
    error ViewAuthorityRequired();
    error ViewSchemaUnavailable(bytes32 schemaId);
    error ViewRevisionMismatch(bytes32 expected, bytes32 actual);
    error ViewLocked(uint256 collectionId, bytes32 viewId);
    error UnknownViewRecord(bytes32 recordHash);
    error ViewIndexOutOfBounds();

    event CollectionRecordRecorded(
        uint256 indexed collectionId,
        bytes32 indexed recordType,
        bytes32 indexed subjectId,
        IStreamPreservationRecords.CollectionRecord record,
        bytes32 recordHash,
        bytes32 recordChainHash,
        address recorder,
        bytes32 authorizationClass,
        uint16 schemaVersion
    );
    event CollectionViewManifestSet(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed viewId,
        bytes32 indexed schemaId,
        bytes32 contentHash,
        bytes32 recordHash,
        CollectionViewManifest manifest,
        ViewReceipt receipt
    );
    event CollectionViewLocked(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed viewId,
        bytes32 indexed recordHash,
        address actor,
        uint8 authorizationClass,
        uint256 grantCollectionId,
        uint64 grantRevision
    );
    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function schemaRegistry() external view returns (address);
    function chunkStore() external view returns (address);
    function viewSchema() external pure returns (bytes32 id, bytes32 hash, bytes memory definition);
    /// @dev Uses exact already-published referenced bytes. Upload alone confers no authority.
    function setCollectionViewManifest(
        uint256 collectionId,
        bytes32 viewId,
        CollectionViewManifest calldata manifest
    ) external returns (bytes32);
    /// @dev Publishes exact referenced bytes atomically and protects against stale edits.
    function setCollectionViewManifestWithPayload(
        uint256 collectionId,
        bytes32 viewId,
        CollectionViewManifest calldata manifest,
        bytes calldata payload,
        bytes32 expectedPrevious
    ) external returns (bytes32);
    function lockCollectionView(uint256 collectionId, bytes32 viewId) external;
    function collectionViewManifest(uint256 collectionId, bytes32 viewId)
        external
        view
        returns (CollectionViewManifest memory);
    function selectedViewRecord(uint256 collectionId, bytes32 viewId)
        external
        view
        returns (bytes32 recordHash, bool locked);
    function viewIdCount(uint256 collectionId) external view returns (uint256);
    function viewIdAt(uint256 collectionId, uint256 index) external view returns (bytes32);
    function viewRecord(bytes32 recordHash)
        external
        view
        returns (
            CollectionViewManifest memory manifest,
            ViewReceipt memory receipt,
            IStreamPreservationRecords.CollectionRecord memory record
        );
    function viewPayload(bytes32 recordHash)
        external
        view
        returns (address pointer, bytes memory payload);
    function viewChunkCount(bytes32 recordHash) external view returns (uint256);
    function viewChunk(bytes32 recordHash, uint256 index)
        external
        view
        returns (bytes32 hash, bytes memory payload);
    function manifestPayload(bytes32 recordHash)
        external
        view
        returns (address pointer, bytes memory payload);
    function recordChainHash(uint256 collectionId)
        external
        view
        returns (bytes32 hash, uint64 count);
    function recordHashAt(uint256 collectionId, uint256 index) external view returns (bytes32);
    function payloadPointerCount(uint256 collectionId) external view returns (uint256);
    function payloadPointerAt(uint256 collectionId, uint256 index)
        external
        view
        returns (address pointer, bytes32 family, bytes32 hash);
}
