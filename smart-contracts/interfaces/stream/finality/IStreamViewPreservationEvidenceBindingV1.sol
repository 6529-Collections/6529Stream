// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Constructor-owned root-free VIEW snapshot source on the actually selected provider.
/// @dev This capability does not assert VIEW reference, finality or complete profile readiness.
interface IStreamViewPreservationEvidenceBindingV1 {
    function viewPreservationSnapshotHost() external view returns (address);
    function viewPreservationSnapshotCodeHash() external view returns (bytes32);
    function viewPreservationSnapshotValidationGas() external view returns (uint256);
}
