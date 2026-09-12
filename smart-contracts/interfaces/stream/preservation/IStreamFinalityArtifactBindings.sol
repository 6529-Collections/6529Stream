// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed counterpart facts; no mutable adapter or caller-chosen readiness target.
interface IStreamFinalityArtifactBindings {
    function core() external view returns (address);
    function artifactCoverage() external view returns (address);
    function chunkStore() external view returns (address);
    function chunk(bytes32 contentHash) external view returns (address pointer, uint32 length);
}
