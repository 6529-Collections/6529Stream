// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Constructor-fixed entropy policy and scope sources for the serving adapter.
interface IStreamFinalityEntropyEvidenceBinding {
    function entropyCoordinator() external view returns (address);
    function entropyCoordinatorCodeHash() external view returns (bytes32);
    function scopeMembershipHost() external view returns (address);
    function scopeMembershipHostCodeHash() external view returns (bytes32);
    /// @notice Current eligible Core pointers; historical policy reads do not use this gate.
    function requireCurrentEntropySelection() external view;
}
