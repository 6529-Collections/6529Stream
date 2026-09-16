// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact complete leaf-list bytes backed by an existing archival completion.
/// @dev This proves a manifest's contents, not authority to publish a collection's root.
interface IStreamContentLeafManifest {
    struct Manifest {
        bytes32 checkpointHash;
        bytes32 artifactHash;
        bytes32 coverageHash;
        bytes32 artistId;
        bytes32 contentRoot;
        bytes32 manifestHash;
        uint256 collectionId;
        uint64 tokenCount;
        uint64 byteLength;
    }

    struct Plan {
        Manifest manifest;
        uint64 nextIndex;
        bytes32 recordHash;
    }

    error InvalidLeafManifest();
    error LeafManifestComponentChanged(address target);
    error LeafManifestReadFailed(address target, bytes4 selector);
    error LeafManifestParentGas(uint256 available, uint256 required);
    error LeafManifestUnknown(bytes32 hash);
    error LeafManifestBatch(uint256 count);
    error LeafManifestMismatch(uint256 index);

    event LeafManifestStarted(bytes32 indexed planHash, Manifest manifest);
    event LeafManifestAdvanced(bytes32 indexed planHash, uint64 firstIndex, uint64 nextIndex);
    event LeafManifestVerified(
        bytes32 indexed recordHash, bytes32 indexed planHash, Manifest manifest
    );

    function core() external view returns (address);
    function contentCheckpoint() external view returns (address);
    function artifactCoverage() external view returns (address);
    function beginManifest(
        bytes32 checkpointHash,
        bytes32 artifactHash,
        bytes32 coverageHash,
        bytes32 artistId
    ) external returns (bytes32 planHash);
    function verifyNextLeaves(bytes32 planHash, uint256 count) external returns (bytes32 recordHash);
    function manifestPlan(bytes32 planHash) external view returns (Plan memory);
    function manifestRecord(bytes32 recordHash) external view returns (Manifest memory);
    /// @notice Rechecks complete current token membership and current archival coverage.
    /// @dev Consumers also establish collection artist association and publication authority.
    function requireCurrentManifest(bytes32 recordHash, bytes32 artistId)
        external
        view
        returns (Manifest memory);
}
