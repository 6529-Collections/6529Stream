// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";

/// @notice Additive full-scope facts from the actual selected immutable evidence provider.
/// @dev Scope identity is never recovered from an untyped subject or scopeId. The original
/// COLLECTION metadata reads remain unchanged; no source list or descriptor is caller-selected.
interface IStreamFinalityScopedMetadataReads {
    function scopedContentRoot(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32 root, uint64 leafCount, bytes32 schemaId);
    function scopedSnapshotHash(StreamFinalityScope calldata scope) external view returns (bytes32);
    function scopedManifest(StreamFinalityScope calldata scope)
        external
        view
        returns (bool published, bytes32 manifestHash);
}
