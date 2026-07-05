// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Host surface for Governed Time Parameters per
///         `docs/stream-long-term-architecture.md` [LTA-GTP]: storage-backed
///         block-count windows with immutable block floors, pinned wall-clock
///         floors binding in both directions, cadence-probe-gated lowering, and
///         governance-only change discipline — no emergency path and no
///         permissionless conditional path exists for GTPs (change discipline 1).
interface IStreamTimeParameterHost {
    /// @notice Per-parameter registration input, fixed at deployment.
    /// @dev    `name` is the bare constant name (for example
    ///         "ENTROPY_REQUEST_TIMEOUT_BLOCKS"); the host derives
    ///         `parameterId = keccak256("6529STREAM_GTP_" || name)` per
    ///         [LTA-GTP] definition item 3.
    struct TimeParameterConfig {
        string name;
        uint256 genesisValue;
        uint256 floorBlocks;
        uint64 wallClockFloorSeconds;
        address cadenceProbe;
        uint64 probeMaxAgeBlocks;
    }

    /// @notice Canonical GTP change event ([LTA-GTP] change discipline 4).
    event TimeParameterUpdated(
        uint16 schemaVersion,
        bytes32 indexed parameterId,
        address indexed host,
        bytes32 indexed actionId,
        uint256 oldValue,
        uint256 newValue,
        uint256 floor
    );

    /// @notice Registration record for indexers: genesis value, both floors, the
    ///         cadence-probe binding, and the recency bound.
    event TimeParameterRegistered(
        uint16 schemaVersion,
        bytes32 indexed parameterId,
        string name,
        uint256 genesisValue,
        uint256 floorBlocks,
        uint64 wallClockFloorSeconds,
        address cadenceProbe,
        uint64 probeMaxAgeBlocks
    );

    /// @notice Emitted when a parameter's cadence-probe binding moves to a
    ///         successor Permanent-class probe through governance
    ///         ([LTA-GGP-PROBES] rule 3, inherited by GTP cadence probes).
    event TimeParameterProbeRebound(
        uint16 schemaVersion,
        bytes32 indexed parameterId,
        address indexed host,
        bytes32 indexed actionId,
        address oldCadenceProbe,
        address newCadenceProbe
    );

    /// @notice Reverts when a parameterId is not registered on this host.
    error TimeParameterUnknown(bytes32 parameterId);
    /// @notice Reverts when a parameter name is registered twice.
    error TimeParameterAlreadyRegistered(bytes32 parameterId);
    /// @notice Reverts when a registration config violates [LTA-GTP] invariants.
    error TimeParameterInvalidConfig(bytes32 parameterId);
    /// @notice Reverts when a bound cadence probe does not pin the parameter's
    ///         wall-clock floor.
    error TimeParameterProbeMismatch(bytes32 parameterId, address cadenceProbe);
    /// @notice Reverts when a governed entry point is called by anyone but the
    ///         governance authority.
    error TimeParameterNotAuthority(address caller);
    /// @notice Reverts when the configured authority fails the wiring marker check.
    error TimeParameterInvalidAuthority(address authority);
    /// @notice Reverts when a raise receives a value at or below current.
    error TimeParameterNotARaise(bytes32 parameterId, uint256 currentValue, uint256 newValue);
    /// @notice Reverts when a raise exceeds the 2x per-action bound
    ///         ([LTA-GTP] change discipline 2).
    error TimeParameterRaiseBoundExceeded(
        bytes32 parameterId, uint256 currentValue, uint256 newValue
    );
    /// @notice Reverts when a lower receives a value at or above current.
    error TimeParameterNotALower(bytes32 parameterId, uint256 currentValue, uint256 newValue);
    /// @notice Reverts when a lower steps below half the current value per action
    ///         ([LTA-GTP] change discipline 2).
    error TimeParameterLowerBoundExceeded(
        bytes32 parameterId, uint256 currentValue, uint256 newValue
    );
    /// @notice Reverts when a lower would cross the immutable block floor.
    error TimeParameterBelowFloor(bytes32 parameterId, uint256 newValue, uint256 floorBlocks);
    /// @notice Reverts when a cadence-gated lower finds no recorded run at the
    ///         proposed value.
    error TimeParameterProbeRecordMissing(bytes32 parameterId, uint256 probedValue);
    /// @notice Reverts when the recorded cadence run is older than
    ///         `probeMaxAgeBlocks`.
    error TimeParameterProbeRecordStale(
        bytes32 parameterId, uint256 probedValue, uint64 probedAtBlock, uint64 probeMaxAgeBlocks
    );
    /// @notice Reverts when the recorded cadence run at the proposed value failed
    ///         the wall-clock-floor coverage check ([LTA-GTP] change discipline 3).
    error TimeParameterProbeNotPassing(bytes32 parameterId, uint256 probedValue);

    /// @notice Canonical pinned host introspection ([LTA-GTP] definition item 7).
    ///         Returns the zeroed tuple for an unregistered parameterId.
    function timeParameterInfo(bytes32 parameterId)
        external
        view
        returns (
            uint256 value,
            uint256 floorBlocks,
            uint64 wallClockFloorSeconds,
            address cadenceProbe,
            uint64 probeMaxAgeBlocks
        );

    /// @notice Live storage-backed window read for guarded paths
    ///         ([LTA-GTP] definition item 1). Reverts for an unregistered id.
    function timeParameter(bytes32 parameterId) external view returns (uint256 value);

    /// @notice All parameterIds registered on this host, registration order.
    function timeParameterIds() external view returns (bytes32[] memory);

    /// @notice The governance action executor wired at deployment; address(0)
    ///         means no governance (both change paths permanently revert).
    function governanceAuthority() external view returns (address);

    /// @notice Staged raise on the normal delay class ([LTA-GTP] change
    ///         discipline 1-2). Authority-only; at most 2x current per action.
    function raiseTimeParameter(bytes32 parameterId, uint256 newValue, bytes32 actionId) external;

    /// @notice Staged lower on the normal delay class ([LTA-GTP] change
    ///         discipline 1-3). Authority-only; no less than half current per
    ///         action; reverts below the immutable block floor; execution recheck
    ///         requires a recorded passing cadence run at exactly `newValue`
    ///         within `probeMaxAgeBlocks` proving the proposed count still covers
    ///         the pinned wall-clock floor at the observed cadence.
    function lowerTimeParameter(bytes32 parameterId, uint256 newValue, bytes32 actionId) external;

    /// @notice Moves the parameter's cadence-probe binding to a successor
    ///         Permanent-class probe on the normal delay class
    ///         ([LTA-GGP-PROBES] rule 3). Authority-only — with governance lost
    ///         the binding is frozen. The successor must pin the identical
    ///         wall-clock floor for this row (`pinnedWallClockFloorSeconds`
    ///         recheck), so a rebind can never change the width a candidate must
    ///         prove.
    function rebindTimeParameterProbe(
        bytes32 parameterId,
        address newCadenceProbe,
        bytes32 actionId
    ) external;
}
