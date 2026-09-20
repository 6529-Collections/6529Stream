// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice One-time Core anchor for the append-only canonical condition-source catalog.
interface IStreamCoreConditionSources {
    error ConditionSourcesAlreadyBound();
    error InvalidConditionSources(address candidate);

    event ConditionSourcesBound(
        uint16 schemaVersion,
        address indexed catalog,
        bytes32 runtimeCodeHash,
        bytes32 indexed actionId
    );

    function conditionSources() external view returns (address catalog, bytes32 runtimeCodeHash);
    function conditionSourcesTransition(address candidate)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function bindConditionSources(address candidate) external;
}
