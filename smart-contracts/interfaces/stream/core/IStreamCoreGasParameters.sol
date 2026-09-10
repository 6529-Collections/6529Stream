// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Raise-only gas budgets for bounded Core external calls.
interface IStreamCoreGasParameters {
    event GasParameterUpdated(
        uint16 schemaVersion,
        bytes32 indexed parameterId,
        address indexed host,
        bytes32 indexed actionId,
        uint256 oldValue,
        uint256 newValue,
        uint256 floor
    );

    /// @notice Returns the configured call budget and its lower bound in gas units.
    /// @param parameterId Domain-defined identifier for the bounded external call.
    /// @return value Current call budget in gas units.
    /// @return floor Permanent lower bound in gas units.
    /// @return failureClass Protocol failure-behavior classification for this call.
    /// @return revision Monotonic configuration revision.
    function gasParameterInfo(bytes32 parameterId)
        external
        view
        returns (uint256 value, uint256 floor, uint8 failureClass, uint64 revision);

    /// @notice Raises a governed external-call budget without lowering its current value or floor.
    /// @dev Requires the exact governed transition; callers cannot use this to lower a budget.
    /// @param newValue Requested call budget in gas units.
    function raiseGasParameter(bytes32 parameterId, uint256 newValue) external;
}
