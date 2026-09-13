// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed producers shared by the complete evidence inputs and component discovery.
/// @dev Getters do not imply those producers have complete current scope evidence.
interface IStreamFinalityDiscoverySources {
    function referenceRenderHost() external view returns (address);
    function snapshotHost() external view returns (address);
    function entropySourceFactory() external view returns (address);
}
