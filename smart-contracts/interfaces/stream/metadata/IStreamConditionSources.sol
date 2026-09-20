// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "../parameters/IStreamGasParameterHost.sol";

/// @notice Explicit, append-only denominator for canonical condition-record discovery.
/// @dev Replacement appends a source; every predecessor remains in the denominator.
///      Canonical use additionally requires the Core's durable binding to this catalog.
interface IStreamConditionSources is IERC165, IStreamGasParameterHost {
    enum Lane {
        OWNER,
        INDEPENDENT
    }

    struct Source {
        address host;
        bytes32 codeHash;
        Lane lane;
        uint64 replacesSourceId;
        uint64 admittedAt;
        bytes32 actionId;
    }

    error InvalidConditionSourcesConfiguration();
    error InvalidConditionSource(address host);
    error ConditionSourceAlreadyAdmitted(address host, Lane lane);
    error UnknownConditionSource(uint64 sourceId);
    error InvalidConditionSourcePredecessor(uint64 sourceId);
    error ConditionSourceReadFailed(address host);
    error ConditionSourceDependencyChanged(address host);
    error ConditionSourceSetChanged(uint64 actualCount, bytes32 actualHead);

    event ConditionSourceAdded(
        uint64 indexed sourceId,
        address indexed host,
        Lane indexed lane,
        bytes32 codeHash,
        uint64 replacesSourceId,
        bytes32 previousHead,
        bytes32 nextHead,
        bytes32 actionId,
        uint16 schemaVersion
    );

    function core() external view returns (address);
    function coreCodeHash() external view returns (bytes32);
    function executorCodeHash() external view returns (bytes32);
    function deploymentChainId() external view returns (uint256);
    function sourceCount() external view returns (uint64);
    function sourceAt(uint64 sourceId) external view returns (Source memory);
    function sourceId(address host, Lane lane) external view returns (uint64);
    function sourceSetHashAt(uint64 count) external view returns (bytes32);
    function sourceSetHead() external view returns (uint64 count, bytes32 head);
    /// @notice Reject stale, partial or foreign source-set commitments.
    function requireSourceSet(uint64 expectedCount, bytes32 expectedHead) external view;
    function sourceTransition(address host, Lane lane, uint64 replacesSourceId)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function appendSource(address host, Lane lane, uint64 replacesSourceId) external;
}
