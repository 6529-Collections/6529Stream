// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Complete current external-pair validation environment for incremental consumers.
/// @dev This does not assert any pair passes. Consumers must validate every exact original
/// pair under one unchanged environment and health revision before using an aggregate.
interface IStreamExternalArtifactEnvironment {
    /// @notice Reuses the host's current graph/profile/configuration checks and returns its
    /// exact identity plus the global family-status/latest-fixity mutation revision.
    /// @dev Current pair semantics preserve original role admission; role revocation alone is
    /// not newly made a failure. No cadence, time expiry or offchain service uptime claim.
    function currentExternalArtifactEnvironment()
        external
        view
        returns (bytes32 environmentHash, uint64 healthRevision);
}
