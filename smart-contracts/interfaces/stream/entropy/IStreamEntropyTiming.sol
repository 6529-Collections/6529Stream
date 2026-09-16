// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Live escalation windows, each bounded by the collection's frozen promise.
interface IStreamEntropyTiming {
    function effectiveRequestTimeoutBlocks(uint256 collectionId) external view returns (uint256);
    function effectiveRevealSLOBlocks(uint256 collectionId) external view returns (uint256);
}
