// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../metadata/StreamTokenContentTypes.sol";

/// @notice Reproducible candidate content roots for the explicit inline ONCHAIN profile.
/// @dev Computation proves current content, not publication authority, archival coverage or finality.
interface IStreamOnchainContentCheckpoint {
    struct Plan {
        uint256 collectionId;
        uint64 tokenCount;
        uint64 nextIndex;
        bytes32 inventoryHash;
        bytes32 servingStateHash;
        bytes32 contentRoot;
        bytes32 leafChainHash;
    }

    struct TokenPayload {
        uint256 tokenId;
        bytes image;
        bytes animation;
    }

    error InvalidCheckpointConfiguration();
    error CheckpointDependencyChanged(address dependency);
    error CheckpointReadFailed(address dependency, bytes4 selector);
    error CheckpointRouterNotSelected();
    error CheckpointUnsupportedPresentation();
    error CheckpointContentUnlocked();
    error CheckpointUnknown(bytes32 planHash);
    error CheckpointInputChanged(bytes32 planHash);
    error CheckpointBatchSize(uint256 size);
    error CheckpointTokenMismatch(uint256 expected, uint256 supplied);
    error CheckpointPayloadMismatch(uint256 tokenId);
    error CheckpointIndexOutOfBounds(bytes32 planHash, uint256 index);

    event ContentCheckpointStarted(bytes32 indexed planHash, Plan plan);
    event ContentCheckpointLeafVerified(
        bytes32 indexed planHash,
        uint64 indexed index,
        StreamTokenContentLeaf leaf,
        bytes32 leafHash
    );
    event ContentCheckpointCompleted(
        bytes32 indexed planHash, bytes32 contentRoot, uint64 tokenCount
    );

    function core() external view returns (address);
    function metadataRouter() external view returns (address);
    function tokenInventory() external view returns (address);
    function beginCollectionCheckpoint(uint256 collectionId) external returns (bytes32 planHash);
    function appendCheckpointTokens(bytes32 planHash, TokenPayload[] calldata payloads) external;
    function checkpoint(bytes32 planHash) external view returns (Plan memory);
    function checkpointLeaf(bytes32 planHash, uint256 index)
        external
        view
        returns (StreamTokenContentLeaf memory);
    /// @notice Revalidate complete current inventory, serving state and selected deployment.
    function requireCurrentCheckpoint(bytes32 planHash) external view returns (Plan memory);
}
