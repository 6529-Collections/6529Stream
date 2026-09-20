// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./StreamMediaMasterTypes.sol";
import "../preservation/IStreamPreservationRecords.sol";

interface IStreamMediaMasterSelection is IERC165 {
    event MediaMasterSelected(uint256 indexed collectionId, bytes32 indexed subjectId,
        uint8 indexed slot, StreamMediaMasterTypes.Selection selection);

    function core() external view returns (address);
    function metadata() external view returns (address);
    function schemaRegistry() external view returns (address);
    function externalCoverage() external view returns (address);
    function profileHash() external view returns (bytes32);
    function mediaObjectId(uint256 collectionId, bytes32 subjectId, bytes32 manifestHash,
        uint8 slot, bytes32 displayHash) external view returns (bytes32);
    /// @notice Authenticated denominator before any master selection. Empty is a committed state.
    function collectionMediaContext(uint256 collectionId) external view returns (
        bytes32 subjectId, bytes32 manifestHash, bytes32 inventoryHash, uint8 occupiedMask);
    function adoptMaster(uint256 collectionId, bytes32 recordHash, uint64 expectedRevision,
        IStreamPreservationRecords.CollectionRecord calldata original,
        StreamMediaMasterTypes.Master calldata witness)
        external returns (StreamMediaMasterTypes.Selection memory);
    function adoptWaiver(uint256 collectionId, uint8 slot, bytes32 manifestHash,
        bytes32 recordHash, uint64 expectedRevision,
        IStreamPreservationRecords.CollectionRecord calldata original,
        StreamMediaMasterTypes.Waiver calldata witness)
        external returns (StreamMediaMasterTypes.Selection memory);
    function currentMaster(uint256 collectionId, bytes32 subjectId, uint8 slot)
        external view returns (StreamMediaMasterTypes.Selection memory);
    function masterSelectionAt(uint256 collectionId, bytes32 subjectId, uint8 slot, uint64 revision)
        external view returns (StreamMediaMasterTypes.Selection memory);
    /// @notice Fresh closure over all occupied native kind3 slots. Opaque/token recipes revert.
    /// @dev This is conservation master coverage, not sold-display archive/finality compliance.
    function requireCollectionMasters(uint256 collectionId, bytes32 subjectId)
        external view returns (bytes32 factsHash);
}
