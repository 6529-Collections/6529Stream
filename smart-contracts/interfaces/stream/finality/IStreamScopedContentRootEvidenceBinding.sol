// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Additive fixed-provider capability; original COLLECTION configuration is unchanged.
/// @dev The selected, pinned finality provider supplies these values. A writer cannot nominate
/// a source or validation budget. Existence of this getter alone does not prove full scope readiness.
interface IStreamScopedContentRootEvidenceBinding {
    function scopedSnapshotHost() external view returns (address);
    function scopedSnapshotCodeHash() external view returns (bytes32);
    function scopedSnapshotValidationGas() external view returns (uint256);
}
