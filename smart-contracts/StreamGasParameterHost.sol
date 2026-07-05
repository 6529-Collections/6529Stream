// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamGasParameterHost.sol";
import "./IStreamGasParameterProbe.sol";
import "./IStreamGovernedParameterAuthority.sol";

/// @notice Reusable Governed Gas Parameter host machinery per
///         `docs/stream-long-term-architecture.md` [LTA-GGP] requirements 1-12.
///         Consumers (Core, factories, coordinators, registries, adapters) embed
///         this base and register their inventory rows in their constructors;
///         standalone parameter stores (for example the split factory parameter
///         store) deploy `StreamGasParameterStore`.
/// @dev    Design pins:
///         - values are storage-backed reads, never immutables or compiled-in
///           constants (definition item 1; ADR 0010 decision D1);
///         - per-parameter floors are fixed at registration and can never be
///           crossed (definition item 2);
///         - `parameterId = keccak256("6529STREAM_GGP_" || name)` is derived from
///           the registered name, never supplied (definition item 5);
///         - every raise (staged, emergency, conditional) is bounded to at most
///           2x current per action (requirement 1);
///         - the emergency raise is raise-only and admitted only against a fresh
///           failing probe run at the current value (requirement 1);
///         - governed lowers recheck a fresh passing probe run at exactly the
///           proposed value and revert below the floor (requirement 2);
///         - permissionless conditional raise/re-lower standing actions exist for
///           `FORWARDING_CAP` rows only and are registered at deployment — there
///           is no path that registers them for any other class (requirements
///           10-11; ADR 0012 decision T1; ADR 0014 decision V7);
///         - `gasParameterInfo` introspection is the normative lost-governance
///           source of floor, probe, class, and recency bound (requirement 12).
abstract contract StreamGasParameterHost is IStreamGasParameterHost {
    /// @notice Schema version carried by every canonical GGP event.
    uint16 public constant GAS_PARAMETER_SCHEMA_VERSION = 1;

    /// @notice Failure-direction class ids pinned by [LTA-GGP] requirement 12.
    uint8 public constant FAILURE_CLASS_NONE = 0;
    uint8 public constant FAILURE_CLASS_FORWARDING_CAP = 1;
    uint8 public constant FAILURE_CLASS_FAIL_CLOSED_PRECHECK = 2;
    uint8 public constant FAILURE_CLASS_MIN_GAS_GATE = 3;

    /// @notice Planning floor for `probeMaxAgeBlocks` ([LTA-GGP-PROBES] rule 6):
    ///         roughly seven days at twelve-second cadence, generous by design so
    ///         a lost-governance recency bound never strands the conditional paths.
    uint64 public constant PROBE_MAX_AGE_FLOOR_BLOCKS = 50_400;

    /// @dev Standing-action id domains for the pre-registered conditional raise and
    ///      re-lower ([LTA-GGP] requirement 11). These identify permissionless
    ///      standing actions in the guardian-module spirit ([LTA-GUARDIAN]); they are
    ///      not staged-operation preimages, which remain owned solely by
    ///      [GOV-ACTION-ID]. keccak256("6529STREAM_GGP_CONDITIONAL_RAISE_V1") and
    ///      keccak256("6529STREAM_GGP_CONDITIONAL_RELOWER_V1").
    bytes32 private constant _CONDITIONAL_RAISE_DOMAIN_V1 =
        0x88d201cde2efee286ecd558414d10dd0599848f47e6dcdfa51a2e0287e4fb2eb;
    bytes32 private constant _CONDITIONAL_RELOWER_DOMAIN_V1 =
        0xb30115be75ee59eeed3fa156242dc7c0eda20b383f4f251c8adcfa616b2276a1;

    struct GasParameterData {
        uint256 value;
        uint256 floor;
        address probe;
        uint8 failureClass;
        uint64 probeMaxAgeBlocks;
        bytes32 conditionalRaiseActionId;
        bytes32 conditionalRelowerActionId;
    }

    /// @inheritdoc IStreamGasParameterHost
    address public immutable override governanceAuthority;

    mapping(bytes32 => GasParameterData) private _gasParameters;
    bytes32[] private _gasParameterIds;

    /// @param authority The canonical governance action executor
    ///        (`IStreamGovernedParameterAuthority` wiring seam), or address(0) for a
    ///        host with no governance whose governed entry points permanently revert.
    constructor(address authority) {
        if (authority != address(0)) {
            if (
                !IStreamGovernedParameterAuthority(authority)
                    .isStreamGovernedParameterAuthority()
            ) {
                revert GasParameterInvalidAuthority(authority);
            }
        }
        governanceAuthority = authority;
    }

    // ---------------------------------------------------------------------
    // Registration (deployment-time only)
    // ---------------------------------------------------------------------

    /// @dev Registers one Governed Gas Parameter. Callable only from constructors
    ///      of embedding hosts — there is no external registration surface, so the
    ///      parameter set and every floor, probe binding, class, and standing
    ///      conditional action are fixed at deployment ([LTA-GGP] definition
    ///      items 2 and 6; requirement 11).
    function _registerGasParameter(GasParameterConfig memory config)
        internal
        returns (bytes32 parameterId)
    {
        if (bytes(config.name).length == 0) {
            revert GasParameterInvalidConfig(bytes32(0));
        }
        parameterId = keccak256(abi.encodePacked("6529STREAM_GGP_", config.name));

        GasParameterData storage parameter = _gasParameters[parameterId];
        if (parameter.failureClass != FAILURE_CLASS_NONE) {
            revert GasParameterAlreadyRegistered(parameterId);
        }
        if (
            config.floor == 0
                || config.genesisValue < config.floor
                || config.failureClass < FAILURE_CLASS_FORWARDING_CAP
                || config.failureClass > FAILURE_CLASS_MIN_GAS_GATE
                || config.probeMaxAgeBlocks < PROBE_MAX_AGE_FLOOR_BLOCKS
        ) {
            revert GasParameterInvalidConfig(parameterId);
        }
        if (config.probe == address(0)) {
            revert GasParameterProbeMismatch(parameterId, config.probe);
        }
        if (IStreamGasParameterProbe(config.probe).probedParameterId() != parameterId) {
            revert GasParameterProbeMismatch(parameterId, config.probe);
        }

        parameter.value = config.genesisValue;
        parameter.floor = config.floor;
        parameter.probe = config.probe;
        parameter.failureClass = config.failureClass;
        parameter.probeMaxAgeBlocks = config.probeMaxAgeBlocks;

        // Requirement 11: the standing conditional raise and re-lower are
        // registered here, at deployment, for FORWARDING_CAP rows and only for
        // FORWARDING_CAP rows. No code path registers them for
        // FAIL_CLOSED_PRECHECK or MIN_GAS_GATE, so their existence for those
        // classes is impossible by construction (ADR 0012 decision T1).
        if (config.failureClass == FAILURE_CLASS_FORWARDING_CAP) {
            parameter.conditionalRaiseActionId = keccak256(
                abi.encode(
                    _CONDITIONAL_RAISE_DOMAIN_V1, block.chainid, address(this), parameterId
                )
            );
            parameter.conditionalRelowerActionId = keccak256(
                abi.encode(
                    _CONDITIONAL_RELOWER_DOMAIN_V1, block.chainid, address(this), parameterId
                )
            );
        }

        _gasParameterIds.push(parameterId);

        emit GasParameterRegistered(
            GAS_PARAMETER_SCHEMA_VERSION,
            parameterId,
            config.name,
            config.genesisValue,
            config.floor,
            config.probe,
            config.failureClass,
            config.probeMaxAgeBlocks,
            parameter.conditionalRaiseActionId,
            parameter.conditionalRelowerActionId
        );
    }

    // ---------------------------------------------------------------------
    // Introspection ([LTA-GGP] requirement 12)
    // ---------------------------------------------------------------------

    /// @inheritdoc IStreamGasParameterHost
    function gasParameterInfo(bytes32 parameterId)
        external
        view
        override
        returns (
            uint256 value,
            uint256 floor,
            address probe,
            uint8 failureClass,
            uint64 probeMaxAgeBlocks
        )
    {
        GasParameterData storage parameter = _gasParameters[parameterId];
        return (
            parameter.value,
            parameter.floor,
            parameter.probe,
            parameter.failureClass,
            parameter.probeMaxAgeBlocks
        );
    }

    /// @inheritdoc IStreamGasParameterHost
    function gasParameter(bytes32 parameterId) public view override returns (uint256 value) {
        GasParameterData storage parameter = _gasParameters[parameterId];
        if (parameter.failureClass == FAILURE_CLASS_NONE) {
            revert GasParameterUnknown(parameterId);
        }
        return parameter.value;
    }

    /// @inheritdoc IStreamGasParameterHost
    function gasParameterIds() external view override returns (bytes32[] memory) {
        return _gasParameterIds;
    }

    /// @inheritdoc IStreamGasParameterHost
    function conditionalGasParameterActions(bytes32 parameterId)
        external
        view
        override
        returns (bytes32 conditionalRaiseActionId, bytes32 conditionalRelowerActionId)
    {
        GasParameterData storage parameter = _gasParameters[parameterId];
        return (parameter.conditionalRaiseActionId, parameter.conditionalRelowerActionId);
    }

    // ---------------------------------------------------------------------
    // Governed paths (authority-only; delay classes live in the executor)
    // ---------------------------------------------------------------------

    /// @inheritdoc IStreamGasParameterHost
    function raiseGasParameter(bytes32 parameterId, uint256 newValue, bytes32 actionId)
        external
        override
    {
        _requireAuthority();
        GasParameterData storage parameter = _requireRegistered(parameterId);
        _checkRaiseBound(parameterId, parameter.value, newValue);
        _setValue(parameterId, parameter, newValue, actionId);
    }

    /// @inheritdoc IStreamGasParameterHost
    function emergencyRaiseGasParameter(bytes32 parameterId, uint256 newValue, bytes32 actionId)
        external
        override
    {
        _requireAuthority();
        GasParameterData storage parameter = _requireRegistered(parameterId);
        // Raise-only + 2x bound first: an emergency action can never lower.
        _checkRaiseBound(parameterId, parameter.value, newValue);
        // Health-probe gate: only a fresh failing run at the current value —
        // genuine degradation proof under [LTA-GGP-PROBES] rule 5 — admits the
        // raise; a healthy parameter can never be emergency-raised.
        _requireFreshFailingRunAtCurrent(parameterId, parameter);
        _setValue(parameterId, parameter, newValue, actionId);
    }

    /// @inheritdoc IStreamGasParameterHost
    function lowerGasParameter(bytes32 parameterId, uint256 newValue, bytes32 actionId)
        external
        override
    {
        _requireAuthority();
        GasParameterData storage parameter = _requireRegistered(parameterId);
        if (newValue >= parameter.value) {
            revert GasParameterNotALower(parameterId, parameter.value, newValue);
        }
        if (newValue < parameter.floor) {
            revert GasParameterBelowFloor(parameterId, newValue, parameter.floor);
        }
        _requireFreshPassingRunAtExactValue(parameterId, parameter, newValue);
        _setValue(parameterId, parameter, newValue, actionId);
    }

    /// @inheritdoc IStreamGasParameterHost
    function rebindGasParameterProbe(bytes32 parameterId, address newProbe, bytes32 actionId)
        external
        override
    {
        // [LTA-GGP-PROBES] rule 3: while governance functions, the binding may
        // move to a successor Permanent-class probe through the normal delay
        // class; with governance lost (zero authority) this path is dead and the
        // binding is frozen.
        _requireAuthority();
        GasParameterData storage parameter = _requireRegistered(parameterId);
        if (newProbe == address(0)) {
            revert GasParameterProbeMismatch(parameterId, newProbe);
        }
        if (IStreamGasParameterProbe(newProbe).probedParameterId() != parameterId) {
            revert GasParameterProbeMismatch(parameterId, newProbe);
        }
        address oldProbe = parameter.probe;
        parameter.probe = newProbe;
        emit GasParameterProbeRebound(
            GAS_PARAMETER_SCHEMA_VERSION, parameterId, address(this), actionId, oldProbe, newProbe
        );
    }

    // ---------------------------------------------------------------------
    // Permissionless conditional paths ([LTA-GGP] requirement 11,
    // FORWARDING_CAP only)
    // ---------------------------------------------------------------------

    /// @inheritdoc IStreamGasParameterHost
    function conditionalRaiseGasParameter(bytes32 parameterId, uint256 newValue)
        external
        override
    {
        GasParameterData storage parameter = _requireRegistered(parameterId);
        bytes32 standingActionId = parameter.conditionalRaiseActionId;
        if (standingActionId == bytes32(0)) {
            revert GasParameterConditionalActionUnavailable(parameterId, parameter.failureClass);
        }
        _checkRaiseBound(parameterId, parameter.value, newValue);
        _requireFreshFailingRunAtCurrent(parameterId, parameter);
        _setValue(parameterId, parameter, newValue, standingActionId);
    }

    /// @inheritdoc IStreamGasParameterHost
    function conditionalRelowerGasParameter(bytes32 parameterId, uint256 newValue)
        external
        override
    {
        GasParameterData storage parameter = _requireRegistered(parameterId);
        bytes32 standingActionId = parameter.conditionalRelowerActionId;
        if (standingActionId == bytes32(0)) {
            revert GasParameterConditionalActionUnavailable(parameterId, parameter.failureClass);
        }
        uint256 currentValue = parameter.value;
        if (newValue >= currentValue) {
            revert GasParameterNotALower(parameterId, currentValue, newValue);
        }
        // Symmetric per-action bound: no lower than half the current value
        // (newValue >= currentValue - newValue avoids overflow).
        if (newValue < currentValue - newValue) {
            revert GasParameterLowerBoundExceeded(parameterId, currentValue, newValue);
        }
        if (newValue < parameter.floor) {
            revert GasParameterBelowFloor(parameterId, newValue, parameter.floor);
        }
        _requireFreshPassingRunAtExactValue(parameterId, parameter, newValue);
        _setValue(parameterId, parameter, newValue, standingActionId);
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    /// @dev Live value read for embedding hosts' guarded paths and EIP-150 63/64
    ///      prechecks ([LTA-GGP] requirement 5): always the current storage value.
    function _gasParameterValue(bytes32 parameterId) internal view returns (uint256) {
        return gasParameter(parameterId);
    }

    function _requireAuthority() private view {
        if (governanceAuthority == address(0) || msg.sender != governanceAuthority) {
            revert GasParameterNotAuthority(msg.sender);
        }
    }

    function _requireRegistered(bytes32 parameterId)
        private
        view
        returns (GasParameterData storage parameter)
    {
        parameter = _gasParameters[parameterId];
        if (parameter.failureClass == FAILURE_CLASS_NONE) {
            revert GasParameterUnknown(parameterId);
        }
    }

    function _checkRaiseBound(bytes32 parameterId, uint256 currentValue, uint256 newValue)
        private
        pure
    {
        if (newValue <= currentValue) {
            revert GasParameterNotARaise(parameterId, currentValue, newValue);
        }
        // At most 2x per action (newValue - currentValue <= currentValue avoids
        // overflow) — [LTA-GGP] requirement 1.
        if (newValue - currentValue > currentValue) {
            revert GasParameterRaiseBoundExceeded(parameterId, currentValue, newValue);
        }
    }

    /// @dev Emergency/conditional raise gate: a recorded failing run at the current
    ///      value, no older than `probeMaxAgeBlocks`, through the probe bound at
    ///      registration ([LTA-GGP] requirement 1).
    function _requireFreshFailingRunAtCurrent(
        bytes32 parameterId,
        GasParameterData storage parameter
    ) private view {
        uint256 currentValue = parameter.value;
        (bytes32 probeRunId, bool passed, uint64 probedAtBlock) =
            IStreamGasParameterProbe(parameter.probe).lastProbeRun(parameterId, currentValue);
        if (probeRunId == bytes32(0)) {
            revert GasParameterProbeRecordMissing(parameterId, currentValue);
        }
        if (block.number - probedAtBlock > parameter.probeMaxAgeBlocks) {
            revert GasParameterProbeRecordStale(
                parameterId, currentValue, probedAtBlock, parameter.probeMaxAgeBlocks
            );
        }
        if (passed) {
            revert GasParameterProbeHealthy(parameterId, currentValue);
        }
    }

    /// @dev Lower/re-lower gate: a recorded passing run at exactly the proposed
    ///      value, no older than `probeMaxAgeBlocks` ([LTA-GGP] requirement 2).
    function _requireFreshPassingRunAtExactValue(
        bytes32 parameterId,
        GasParameterData storage parameter,
        uint256 proposedValue
    ) private view {
        (bytes32 probeRunId, bool passed, uint64 probedAtBlock) =
            IStreamGasParameterProbe(parameter.probe).lastProbeRun(parameterId, proposedValue);
        if (probeRunId == bytes32(0)) {
            revert GasParameterProbeRecordMissing(parameterId, proposedValue);
        }
        if (block.number - probedAtBlock > parameter.probeMaxAgeBlocks) {
            revert GasParameterProbeRecordStale(
                parameterId, proposedValue, probedAtBlock, parameter.probeMaxAgeBlocks
            );
        }
        if (!passed) {
            revert GasParameterProbeNotPassing(parameterId, proposedValue);
        }
    }

    function _setValue(
        bytes32 parameterId,
        GasParameterData storage parameter,
        uint256 newValue,
        bytes32 actionId
    ) private {
        uint256 oldValue = parameter.value;
        parameter.value = newValue;
        emit GasParameterUpdated(
            GAS_PARAMETER_SCHEMA_VERSION,
            parameterId,
            address(this),
            actionId,
            oldValue,
            newValue,
            parameter.floor
        );
    }
}
