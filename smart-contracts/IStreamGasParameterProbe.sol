// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Canonical probe-record surface for Governed Gas Parameters.
///         `docs/stream-long-term-architecture.md` [LTA-GGP] definition item 6 and
///         [LTA-GGP-PROBES]: the probe-run record lives on the probe contract itself,
///         never on the host, and is the only verification locus for probe-gated
///         lowering, emergency raising, and the permissionless conditional raise and
///         re-lower.
interface IStreamGasParameterProbe {
    /// @notice Canonical probe-run record event ([LTA-GGP] definition item 6).
    event GasParameterProbed(
        uint16 schemaVersion,
        bytes32 indexed parameterId,
        bytes32 indexed probeRunId,
        bool passed,
        uint256 probedValue,
        bytes32 evidenceHash
    );

    /// @notice Canonical probe-record read consumed by host execution rechecks.
    /// @dev    Returns the zeroed tuple when no run has been recorded for
    ///         `(parameterId, probedValue)` or when `parameterId` is not the
    ///         parameter this probe serves.
    function lastProbeRun(bytes32 parameterId, uint256 probedValue)
        external
        view
        returns (bytes32 probeRunId, bool passed, uint64 probedAtBlock);

    /// @notice The single [LTA-GGP] inventory-row parameterId this probe serves.
    /// @dev    Hosts verify this binding at parameter registration so a probe can
    ///         never be bound to a row it does not execute. Multi-host rows bind the
    ///         same probe (and therefore the same id) on every host.
    function probedParameterId() external view returns (bytes32);
}
