// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable original per-part archive record locators retained by the artifact host.
/// @dev These are historical admission identities, never current validation/fixity heads.
interface IStreamArtifactOriginalEvidence {
    function originalArtifactChunkCoverage(bytes32 completionHash, uint32 index)
        external
        view
        returns (bytes32);
}
