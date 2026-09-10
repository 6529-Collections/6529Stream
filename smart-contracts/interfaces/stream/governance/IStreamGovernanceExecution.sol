// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGovernanceTypes.sol";

/// @notice Publish, schedule, execute, and terminate atomic governance actions.
/// @dev Caller ABI for the same Executor address. Discovery continues to use
///      IStreamGovernanceExecutor; this caller subset is not a new ERC165 claim.
interface IStreamGovernanceExecution {
    /// @notice Publishes the exact ordered calldata preimages for a batch as an
    ///         SSTORE2 blob ([GOV-BATCH] rule 5; ADR 0013 decision U5).
    /// @dev Permissionless and content-addressed: the key is
    ///     `keccak256(abi.encodePacked(keccak256(callDatas[0]), ...))`, so a
    ///     published blob can never disagree with the `callDataHash` entries of
    ///     a batch that resolves to it. Republishing an existing set is
    ///     idempotent. Scheduling requires the batch's preimages to be
    ///     published so the stored action record carries the pointer for the
    ///     full open-to-execute window.
    function publishGovernanceCallData(bytes[] calldata callDatas)
        external
        returns (address pointer);

    /// @notice Schedules a batch of calls as one atomic governance action
    ///         ([GOV-ACTION-ID] explicit batch ABI; ADR 0011 decision R10).
    /// @dev Reverts with `CallDataNotPublished` unless the exact calldata
    ///     preimages for `calls` were published via `publishGovernanceCallData`
    ///     (same transaction is fine); the stored action record then carries
    ///     the SSTORE2 pointer ([GOV-BATCH] rule 5).
    function scheduleGovernanceBatch(
        uint8 actionClass,
        GovernanceCall[] calldata calls,
        bytes32 scopeHash,
        bytes32 oldValueHash,
        bytes32 newValueHash,
        uint64 notBefore,
        uint64 expiresAfter,
        bytes32 reasonHash,
        string calldata reasonURI,
        bytes32 manifestHash
    ) external returns (bytes32 actionId);

    /// @notice Executes a scheduled batch; atomic, payable-value pinned
    ///         (`msg.value == sum(calls[].value)`), permissionless after
    ///         `notBefore` ([GOV-BATCH] rules 1-2).
    function executeGovernanceBatch(
        bytes32 actionId,
        GovernanceCall[] calldata calls,
        bytes[] calldata callDatas
    ) external payable;

    /// @notice Single-call wrapper producing a byte-identical action ID to the
    ///         equivalent one-call batch.
    function scheduleGovernanceAction(GovernanceActionRequest calldata request)
        external
        returns (bytes32 actionId);

    /// @notice Single-call execution wrapper over the stored first-call fields.
    function executeGovernanceAction(bytes32 actionId, bytes calldata callData) external payable;

    /// @notice Cancels a scheduled action before execution.
    function cancelGovernanceAction(bytes32 actionId, bytes32 reasonHash) external;

    /// @notice Materializes `EXPIRED` for a scheduled action past `expiresAfter`.
    function materializeExpiredAction(bytes32 actionId) external;

    /// @notice Permissionlessly removes memberships whose veto deadline has
    ///         elapsed. This does not mutate action status or pending counts.
    function pruneElapsedTerminalFreezeActions(bytes32 scopeHash)
        external
        returns (uint256 prunedCount);

    /// @notice Vetoes a scheduled terminal-freeze action before its veto
    ///         deadline. A global holder or a holder for any distinct affected
    ///         per-call scope may veto the whole atomic batch.
    function vetoTerminalFreeze(bytes32 actionId, bytes32 reasonHash) external;
}
