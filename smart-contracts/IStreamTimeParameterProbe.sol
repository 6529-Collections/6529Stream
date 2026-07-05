// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Canonical cadence-probe surface for Governed Time Parameters.
///         `docs/stream-long-term-architecture.md` [LTA-GTP] definition item 6:
///         a Permanent-class probe contract under the [LTA-GGP-PROBES] rules that
///         anyone can call to record observed block cadence onchain over a
///         sampling window and to record pass/fail for a candidate block count
///         against a parameter's pinned wall-clock floor at that observed cadence.
interface IStreamTimeParameterProbe {
    /// @notice Canonical cadence probe-record event — same field shape as
    ///         `GasParameterProbed` ([LTA-GTP] change discipline 4).
    event TimeParameterProbed(
        uint16 schemaVersion,
        bytes32 indexed parameterId,
        bytes32 indexed probeRunId,
        bool passed,
        uint256 probedValue,
        bytes32 evidenceHash
    );

    /// @notice Canonical probe-record read consumed by host execution rechecks;
    ///         zeroed tuple when no run exists for `(parameterId, probedValue)`.
    function lastProbeRun(bytes32 parameterId, uint256 probedValue)
        external
        view
        returns (bytes32 probeRunId, bool passed, uint64 probedAtBlock);

    /// @notice The wall-clock floor (seconds) pinned in this probe for a GTP row it
    ///         serves; zero when the row is not pinned here.
    /// @dev    Hosts cross-check this pin against their own immutable wall-clock
    ///         floor at parameter registration, so probe and host can never
    ///         disagree about the width a candidate must cover.
    function pinnedWallClockFloorSeconds(bytes32 parameterId) external view returns (uint64);
}
