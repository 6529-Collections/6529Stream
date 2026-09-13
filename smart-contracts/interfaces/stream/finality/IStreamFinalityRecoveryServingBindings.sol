// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable companion bindings consumed by the current metadata serving router.
/// @dev Additive caller subset; it does not change the original sixteen-selector discovery ID.
interface IStreamFinalityRecoveryServingBindings {
    function core() external view returns (address);
    function governanceAuthority() external view returns (address);
    function originalFinalityRegistry() external view returns (address);
    function artistEvidence() external view returns (address);
    function ownerEvidence() external view returns (address);
}
