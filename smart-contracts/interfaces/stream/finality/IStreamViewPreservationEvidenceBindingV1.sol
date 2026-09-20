// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Root-free VIEW snapshot source, fixed after one class2 governed bind on the selected provider.
/// @dev This capability does not assert VIEW reference, finality or complete profile readiness.
interface IStreamViewPreservationEvidenceBindingV1 {
    function viewPreservationSnapshotHost() external view returns (address);
    function viewPreservationSnapshotCodeHash() external view returns (bytes32);
    function viewPreservationSnapshotValidationGas() external view returns (uint256);
}
