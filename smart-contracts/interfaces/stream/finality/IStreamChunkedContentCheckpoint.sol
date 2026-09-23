// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Explicit checkpoint profile for complete immutable chunk-backed artwork.
/// @dev Original inline begin/plan/leaf interfaces and domains remain unchanged.
interface IStreamChunkedContentCheckpoint {
    function beginChunkedCollectionCheckpoint(uint256 collectionId) external returns (bytes32);
    function checkpointProfile(bytes32 planHash) external view returns (bytes32);
}
