// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed discovery-to-typed-evidence binding, never a mutable provider lookup table.
interface IStreamFinalityEvidenceDiscoveryBinding {
    function scopeEvidenceProvider() external view returns (address);
}
