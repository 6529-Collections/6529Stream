// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Host surface for Governed Gas Parameters per
///         `docs/stream-long-term-architecture.md` [LTA-GGP] requirements 1-12.
///         Every contract that hosts a GGP (Core, factories, stores, coordinators,
///         registries, adapters) exposes this surface for the parameters it hosts.
interface IStreamGasParameterHost {
    /// @notice Per-parameter registration input, fixed at deployment.
    /// @dev    `name` is the bare constant name (for example
    ///         "ASSET_POLICY_GAS_LIMIT"); the host derives
    ///         `parameterId = keccak256("6529STREAM_GGP_" || name)` per
    ///         [LTA-GGP] definition item 5, so a mis-derived id is impossible by
    ///         construction.
    struct GasParameterConfig {
        string name;
        uint256 genesisValue;
        uint256 floor;
        address probe;
        uint8 failureClass;
        uint64 probeMaxAgeBlocks;
    }

    /// @notice Canonical GGP change event ([LTA-GGP] requirement 4). Emitted on
    ///         every value change: staged raise, emergency raise, governed lower,
    ///         permissionless conditional raise, and permissionless conditional
    ///         re-lower.
    event GasParameterUpdated(
        uint16 schemaVersion,
        bytes32 indexed parameterId,
        address indexed host,
        bytes32 indexed actionId,
        uint256 oldValue,
        uint256 newValue,
        uint256 floor
    );

    /// @notice Registration record for indexers: the genesis value, immutable floor,
    ///         probe binding, failure class, recency bound, and — for
    ///         `FORWARDING_CAP` rows — the pre-registered standing conditional
    ///         action ids of [LTA-GGP] requirement 11.
    event GasParameterRegistered(
        uint16 schemaVersion,
        bytes32 indexed parameterId,
        string name,
        uint256 genesisValue,
        uint256 floor,
        address probe,
        uint8 failureClass,
        uint64 probeMaxAgeBlocks,
        bytes32 conditionalRaiseActionId,
        bytes32 conditionalRelowerActionId
    );

    /// @notice Reverts when a parameterId is not registered on this host.
    error GasParameterUnknown(bytes32 parameterId);
    /// @notice Reverts when a parameter name is registered twice.
    error GasParameterAlreadyRegistered(bytes32 parameterId);
    /// @notice Reverts when a registration config violates [LTA-GGP] invariants.
    error GasParameterInvalidConfig(bytes32 parameterId);
    /// @notice Reverts when a bound probe does not serve the registered parameter.
    error GasParameterProbeMismatch(bytes32 parameterId, address probe);
    /// @notice Reverts when a governed entry point is called by anyone but the
    ///         governance authority (including every caller on a zero-authority host).
    error GasParameterNotAuthority(address caller);
    /// @notice Reverts when the configured authority fails the wiring marker check.
    error GasParameterInvalidAuthority(address authority);
    /// @notice Reverts when a raise path receives a value at or below current.
    error GasParameterNotARaise(bytes32 parameterId, uint256 currentValue, uint256 newValue);
    /// @notice Reverts when a raise exceeds the 2x per-action bound
    ///         ([LTA-GGP] requirement 1).
    error GasParameterRaiseBoundExceeded(
        bytes32 parameterId, uint256 currentValue, uint256 newValue
    );
    /// @notice Reverts when a lower path receives a value at or above current.
    error GasParameterNotALower(bytes32 parameterId, uint256 currentValue, uint256 newValue);
    /// @notice Reverts when a conditional re-lower steps below half the current
    ///         value per action ([LTA-GGP] requirement 11).
    error GasParameterLowerBoundExceeded(
        bytes32 parameterId, uint256 currentValue, uint256 newValue
    );
    /// @notice Reverts when a lower would cross the immutable floor
    ///         ([LTA-GGP] requirement 2).
    error GasParameterBelowFloor(bytes32 parameterId, uint256 newValue, uint256 floor);
    /// @notice Reverts when a probe-gated path finds no recorded run at the
    ///         required value.
    error GasParameterProbeRecordMissing(bytes32 parameterId, uint256 probedValue);
    /// @notice Reverts when the recorded run is older than `probeMaxAgeBlocks`.
    error GasParameterProbeRecordStale(
        bytes32 parameterId, uint256 probedValue, uint64 probedAtBlock, uint64 probeMaxAgeBlocks
    );
    /// @notice Reverts when an emergency or conditional raise finds the guarded
    ///         path healthy at the current value ([LTA-GGP] requirement 1).
    error GasParameterProbeHealthy(bytes32 parameterId, uint256 currentValue);
    /// @notice Reverts when a lower's execution recheck finds a failing run at the
    ///         proposed value ([LTA-GGP] requirement 2).
    error GasParameterProbeNotPassing(bytes32 parameterId, uint256 probedValue);
    /// @notice Reverts when a conditional raise or re-lower is invoked for a
    ///         parameter class that has none ([LTA-GGP] requirements 10-11:
    ///         conditional actions exist for `FORWARDING_CAP` rows only).
    error GasParameterConditionalActionUnavailable(bytes32 parameterId, uint8 failureClass);

    /// @notice Canonical pinned host introspection ([LTA-GGP] requirement 12).
    ///         Returns the zeroed tuple for an unregistered parameterId.
    function gasParameterInfo(bytes32 parameterId)
        external
        view
        returns (
            uint256 value,
            uint256 floor,
            address probe,
            uint8 failureClass,
            uint64 probeMaxAgeBlocks
        );

    /// @notice Live storage-backed value read for guarded paths and EIP-150 63/64
    ///         prechecks ([LTA-GGP] definition item 1, requirement 5). Reverts for
    ///         an unregistered parameterId so a consumer can never silently run
    ///         with a zero cap.
    function gasParameter(bytes32 parameterId) external view returns (uint256 value);

    /// @notice All parameterIds registered on this host, registration order.
    function gasParameterIds() external view returns (bytes32[] memory);

    /// @notice Pre-registered standing conditional action ids
    ///         ([LTA-GGP] requirement 11). Zero for every non-`FORWARDING_CAP`
    ///         parameter and for unregistered ids.
    function conditionalGasParameterActions(bytes32 parameterId)
        external
        view
        returns (bytes32 conditionalRaiseActionId, bytes32 conditionalRelowerActionId);

    /// @notice The governance action executor wired at deployment; address(0) means
    ///         no governance (governed entry points permanently revert).
    function governanceAuthority() external view returns (address);

    /// @notice Staged raise on the normal delay class ([LTA-GGP] requirement 1).
    ///         Authority-only; bounded to at most 2x current per action.
    function raiseGasParameter(bytes32 parameterId, uint256 newValue, bytes32 actionId) external;

    /// @notice Emergency raise ([LTA-GGP] requirement 1): raise-only,
    ///         authority-only, bounded to 2x per action, and admitted only while the
    ///         bound probe has recorded a failing run at the current value within
    ///         `probeMaxAgeBlocks`. Repeatable while fresh runs keep proving failure.
    function emergencyRaiseGasParameter(bytes32 parameterId, uint256 newValue, bytes32 actionId)
        external;

    /// @notice Governed lower on the normal delay class ([LTA-GGP] requirement 2).
    ///         Authority-only; reverts below the immutable floor; execution recheck
    ///         requires a recorded passing run at exactly `newValue` within
    ///         `probeMaxAgeBlocks`.
    function lowerGasParameter(bytes32 parameterId, uint256 newValue, bytes32 actionId) external;

    /// @notice Permissionless conditional raise ([LTA-GGP] requirement 11),
    ///         `FORWARDING_CAP` rows only. Callable by anyone with no governance
    ///         signer while the bound probe has recorded a failing run at the
    ///         current value within `probeMaxAgeBlocks`; bounded to 2x per action;
    ///         emits the canonical change event with the pre-registered action id.
    function conditionalRaiseGasParameter(bytes32 parameterId, uint256 newValue) external;

    /// @notice Permissionless conditional re-lower ([LTA-GGP] requirement 11),
    ///         `FORWARDING_CAP` rows only. Callable by anyone with no governance
    ///         signer; requires a recorded passing run at exactly `newValue` within
    ///         `probeMaxAgeBlocks`; bounded to no lower than half the current value
    ///         per action; reverts below the immutable floor; emits the canonical
    ///         change event with the pre-registered action id.
    function conditionalRelowerGasParameter(bytes32 parameterId, uint256 newValue) external;
}
