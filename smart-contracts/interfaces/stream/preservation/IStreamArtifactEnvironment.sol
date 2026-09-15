// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact complete mutable invalidation context used by requireArtifactCoverage.
/// @dev This is not coverage or per-part liveness. Immutable-STOP aggregates must first
/// check every complete artifact and part under this same environment and epoch.
interface IStreamArtifactEnvironment {
    function currentArtifactEnvironment()
        external
        view
        returns (bytes32 environmentHash, uint64 validationEpoch);
}
