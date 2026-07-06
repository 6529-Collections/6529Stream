// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamTimeParameterHost.sol";
import "./IStreamTimeParameterProbe.sol";
import "./IStreamGovernedParameterAuthority.sol";

/// @notice Reusable Governed Time Parameter host machinery per
///         `docs/stream-long-term-architecture.md` [LTA-GTP]. Hosts of
///         block-denominated liveness windows (the entropy coordinator's
///         `ENTROPY_REQUEST_TIMEOUT_BLOCKS`, `ENTROPY_REVEAL_SLO_BLOCKS`, and
///         `ENTROPY_RECOVERY_STEP_DELAY_BLOCKS` genesis rows) embed this base;
///         standalone stores deploy `StreamTimeParameterStore`.
/// @dev    Change discipline pins ([LTA-GTP] change discipline 1-4):
///         - every change is governance-only through the canonical action
///           executor seam — by construction this contract has no emergency path
///           and no permissionless conditional raise or re-lower (the
///           lost-governance machinery exists for `FORWARDING_CAP` gas reads
///           only, ADR 0012 decision T1);
///         - raises are bounded to at most 2x current per action, lowers to no
///           less than half current per action, and lowers revert below the
///           immutable block floor;
///         - a lower's execution recheck verifies through the bound cadence probe
///           a recorded passing run at exactly the proposed value within
///           `probeMaxAgeBlocks`, proving the proposed count still covers the
///           parameter's pinned wall-clock floor at the observed cadence — the
///           wall-clock floor thereby binds in both directions (change
///           discipline 7);
///         - `timeParameterInfo` is the canonical host introspection read
///           (definition item 7).
abstract contract StreamTimeParameterHost is IStreamTimeParameterHost {
    /// @notice Schema version carried by every canonical GTP event.
    uint16 public constant TIME_PARAMETER_SCHEMA_VERSION = 1;

    /// @notice Planning floor for `probeMaxAgeBlocks` — cadence probes are
    ///         [LTA-GGP-PROBES] members and inherit rule 6's floor.
    uint64 public constant PROBE_MAX_AGE_FLOOR_BLOCKS = 50_400;

    struct TimeParameterData {
        uint256 value;
        uint256 floorBlocks;
        uint64 wallClockFloorSeconds;
        address cadenceProbe;
        uint64 probeMaxAgeBlocks;
    }

    /// @inheritdoc IStreamTimeParameterHost
    address public immutable override governanceAuthority;

    mapping(bytes32 => TimeParameterData) private _timeParameters;
    bytes32[] private _timeParameterIds;

    /// @param authority The canonical governance action executor
    ///        (`IStreamGovernedParameterAuthority` wiring seam), or address(0) for
    ///        a host with no governance whose change paths permanently revert.
    constructor(address authority) {
        if (authority != address(0)) {
            if (!IStreamGovernedParameterAuthority(authority).isStreamGovernedParameterAuthority())
            {
                revert TimeParameterInvalidAuthority(authority);
            }
        }
        governanceAuthority = authority;
    }

    // ---------------------------------------------------------------------
    // Registration (deployment-time only)
    // ---------------------------------------------------------------------

    /// @dev Registers one Governed Time Parameter. Callable only from constructors
    ///      of embedding hosts; the parameter set, both floors, the cadence-probe
    ///      binding, and the recency bound are fixed at deployment ([LTA-GTP]
    ///      definition items 1-3 and 6).
    function _registerTimeParameter(TimeParameterConfig memory config)
        internal
        returns (bytes32 parameterId)
    {
        if (bytes(config.name).length == 0) {
            revert TimeParameterInvalidConfig(bytes32(0));
        }
        parameterId = keccak256(abi.encodePacked("6529STREAM_GTP_", config.name));

        TimeParameterData storage parameter = _timeParameters[parameterId];
        if (parameter.cadenceProbe != address(0)) {
            revert TimeParameterAlreadyRegistered(parameterId);
        }
        if (
            config.floorBlocks == 0 || config.genesisValue < config.floorBlocks
                || config.wallClockFloorSeconds == 0
                || config.probeMaxAgeBlocks < PROBE_MAX_AGE_FLOOR_BLOCKS
        ) {
            revert TimeParameterInvalidConfig(parameterId);
        }
        if (config.cadenceProbe == address(0)) {
            revert TimeParameterProbeMismatch(parameterId, config.cadenceProbe);
        }
        // Cross-check the probe's pinned wall-clock floor against the host's
        // immutable registration so the coverage width a candidate must prove can
        // never diverge between probe and host.
        if (
            IStreamTimeParameterProbe(config.cadenceProbe).pinnedWallClockFloorSeconds(parameterId)
                != config.wallClockFloorSeconds
        ) {
            revert TimeParameterProbeMismatch(parameterId, config.cadenceProbe);
        }

        parameter.value = config.genesisValue;
        parameter.floorBlocks = config.floorBlocks;
        parameter.wallClockFloorSeconds = config.wallClockFloorSeconds;
        parameter.cadenceProbe = config.cadenceProbe;
        parameter.probeMaxAgeBlocks = config.probeMaxAgeBlocks;

        _timeParameterIds.push(parameterId);

        emit TimeParameterRegistered(
            TIME_PARAMETER_SCHEMA_VERSION,
            parameterId,
            config.name,
            config.genesisValue,
            config.floorBlocks,
            config.wallClockFloorSeconds,
            config.cadenceProbe,
            config.probeMaxAgeBlocks
        );
    }

    // ---------------------------------------------------------------------
    // Introspection ([LTA-GTP] definition item 7)
    // ---------------------------------------------------------------------

    /// @inheritdoc IStreamTimeParameterHost
    function timeParameterInfo(bytes32 parameterId)
        external
        view
        override
        returns (
            uint256 value,
            uint256 floorBlocks,
            uint64 wallClockFloorSeconds,
            address cadenceProbe,
            uint64 probeMaxAgeBlocks
        )
    {
        TimeParameterData storage parameter = _timeParameters[parameterId];
        return (
            parameter.value,
            parameter.floorBlocks,
            parameter.wallClockFloorSeconds,
            parameter.cadenceProbe,
            parameter.probeMaxAgeBlocks
        );
    }

    /// @inheritdoc IStreamTimeParameterHost
    function timeParameter(bytes32 parameterId) public view override returns (uint256 value) {
        TimeParameterData storage parameter = _timeParameters[parameterId];
        if (parameter.cadenceProbe == address(0)) {
            revert TimeParameterUnknown(parameterId);
        }
        return parameter.value;
    }

    /// @inheritdoc IStreamTimeParameterHost
    function timeParameterIds() external view override returns (bytes32[] memory) {
        return _timeParameterIds;
    }

    // ---------------------------------------------------------------------
    // Governed change paths (the only change paths — [LTA-GTP] discipline 1)
    // ---------------------------------------------------------------------

    /// @inheritdoc IStreamTimeParameterHost
    function raiseTimeParameter(bytes32 parameterId, uint256 newValue, bytes32 actionId)
        external
        override
    {
        _requireAuthority();
        TimeParameterData storage parameter = _requireRegistered(parameterId);
        uint256 currentValue = parameter.value;
        if (newValue <= currentValue) {
            revert TimeParameterNotARaise(parameterId, currentValue, newValue);
        }
        if (newValue - currentValue > currentValue) {
            revert TimeParameterRaiseBoundExceeded(parameterId, currentValue, newValue);
        }
        _setValue(parameterId, parameter, newValue, actionId);
    }

    /// @inheritdoc IStreamTimeParameterHost
    function lowerTimeParameter(bytes32 parameterId, uint256 newValue, bytes32 actionId)
        external
        override
    {
        _requireAuthority();
        TimeParameterData storage parameter = _requireRegistered(parameterId);
        uint256 currentValue = parameter.value;
        if (newValue >= currentValue) {
            revert TimeParameterNotALower(parameterId, currentValue, newValue);
        }
        // No less than half the current value per action
        // (newValue >= currentValue - newValue avoids overflow).
        if (newValue < currentValue - newValue) {
            revert TimeParameterLowerBoundExceeded(parameterId, currentValue, newValue);
        }
        if (newValue < parameter.floorBlocks) {
            revert TimeParameterBelowFloor(parameterId, newValue, parameter.floorBlocks);
        }
        _requireFreshPassingCadenceRun(parameterId, parameter, newValue);
        _setValue(parameterId, parameter, newValue, actionId);
    }

    /// @inheritdoc IStreamTimeParameterHost
    function rebindTimeParameterProbe(
        bytes32 parameterId,
        address newCadenceProbe,
        bytes32 actionId
    ) external override {
        // [LTA-GGP-PROBES] rule 3 (cadence probes are members of that rule set):
        // while governance functions, the binding may move to a successor
        // Permanent-class probe through the normal delay class; with governance
        // lost (zero authority) this path is dead and the binding is frozen.
        _requireAuthority();
        TimeParameterData storage parameter = _requireRegistered(parameterId);
        if (newCadenceProbe == address(0)) {
            revert TimeParameterProbeMismatch(parameterId, newCadenceProbe);
        }
        // The successor must pin the identical wall-clock floor, so the width a
        // candidate must prove can never drift across a rebind.
        if (
            IStreamTimeParameterProbe(newCadenceProbe).pinnedWallClockFloorSeconds(parameterId)
                != parameter.wallClockFloorSeconds
        ) {
            revert TimeParameterProbeMismatch(parameterId, newCadenceProbe);
        }
        address oldCadenceProbe = parameter.cadenceProbe;
        parameter.cadenceProbe = newCadenceProbe;
        emit TimeParameterProbeRebound(
            TIME_PARAMETER_SCHEMA_VERSION,
            parameterId,
            address(this),
            actionId,
            oldCadenceProbe,
            newCadenceProbe
        );
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    /// @dev Live window read for embedding hosts' liveness/recovery gates.
    function _timeParameterValue(bytes32 parameterId) internal view returns (uint256) {
        return timeParameter(parameterId);
    }

    function _requireAuthority() private view {
        if (governanceAuthority == address(0) || msg.sender != governanceAuthority) {
            revert TimeParameterNotAuthority(msg.sender);
        }
    }

    function _requireRegistered(bytes32 parameterId)
        private
        view
        returns (TimeParameterData storage parameter)
    {
        parameter = _timeParameters[parameterId];
        if (parameter.cadenceProbe == address(0)) {
            revert TimeParameterUnknown(parameterId);
        }
    }

    /// @dev Lower gate ([LTA-GTP] change discipline 3): a recorded passing cadence
    ///      run at exactly the proposed value, no older than `probeMaxAgeBlocks`,
    ///      through the cadence probe bound at registration.
    function _requireFreshPassingCadenceRun(
        bytes32 parameterId,
        TimeParameterData storage parameter,
        uint256 proposedValue
    ) private view {
        (bytes32 probeRunId, bool passed, uint64 probedAtBlock) = IStreamTimeParameterProbe(
                parameter.cadenceProbe
            ).lastProbeRun(parameterId, proposedValue);
        if (probeRunId == bytes32(0)) {
            revert TimeParameterProbeRecordMissing(parameterId, proposedValue);
        }
        if (block.number - probedAtBlock > parameter.probeMaxAgeBlocks) {
            revert TimeParameterProbeRecordStale(
                parameterId, proposedValue, probedAtBlock, parameter.probeMaxAgeBlocks
            );
        }
        if (!passed) {
            revert TimeParameterProbeNotPassing(parameterId, proposedValue);
        }
    }

    function _setValue(
        bytes32 parameterId,
        TimeParameterData storage parameter,
        uint256 newValue,
        bytes32 actionId
    ) private {
        uint256 oldValue = parameter.value;
        parameter.value = newValue;
        emit TimeParameterUpdated(
            TIME_PARAMETER_SCHEMA_VERSION,
            parameterId,
            address(this),
            actionId,
            oldValue,
            newValue,
            parameter.floorBlocks
        );
    }
}
