// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreservationInventoryTypes.sol";

/// @notice Deterministic complete native collection inventory derived from eight actual originals.
interface IStreamRenderCriticalInventory {
    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function metadataRouter() external view returns (address);
    function snapshots() external view returns (address);
    function referencePublisher() external view returns (address);
    function artifactCoverage() external view returns (address);
    function externalCoverage() external view returns (address);
    function deploymentChainId() external view returns (uint256);
    function coreCodeHash() external view returns (bytes32);
    function metadataCodeHash() external view returns (bytes32);
    /// @notice Historical complete evidence, with no assertion of present input/archive liveness.
    function inventoryEvidence(bytes32 planId)
        external
        view
        returns (StreamPreservationInventoryTypes.Evidence memory);
    function inventorySegment(bytes32 planId, uint64 index)
        external
        view
        returns (StreamPreservationInventoryTypes.Segment memory);
    /// @notice Re-derive all current sources and require that exact canonical inventory completed.
    /// @dev No final manifest, sanction or whole provider dependency occurs in this derivation.
    function requireCurrent(uint256 collectionId)
        external
        view
        returns (StreamPreservationInventoryTypes.Evidence memory);
}
