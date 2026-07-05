// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Scheduled governance action lifecycle states pinned by ADR 0004
///         (`docs/adr/0004-admin-governance.md`, Scheduled Action State).
enum GovernanceActionStatus {
    NONE,
    SCHEDULED,
    CANCELLED,
    EXECUTED,
    EXPIRED,
    VETOED
}

/// @notice One call inside a governance action batch ([GOV-ACTION-ID]).
struct GovernanceCall {
    address target;
    uint256 value;
    bytes4 selector;
    bytes32 callDataHash; // keccak256(callData)
}

/// @notice Stored governance action record pinned by ADR 0004.
/// @dev For batches, `callHash` stores the [GOV-ACTION-ID] `callsHash` and
///     `target`/`selector` are those of the first call for indexing; `value`
///     is the batch value sum ([GOV-BATCH] rule 3).
struct GovernanceAction {
    GovernanceActionStatus status;
    uint8 actionClass;
    address target;
    uint256 value;
    bytes4 selector;
    bytes32 callHash;
    bytes32 scopeHash;
    bytes32 oldValueHash;
    bytes32 newValueHash;
    uint64 notBefore;
    uint64 expiresAfter;
    address proposer;
    address executor;
    address canceller;
    address vetoer;
    bytes32 reasonHash;
    string reasonURI;
    bytes32 manifestHash;
}

/// @notice Single-call scheduling request pinned by ADR 0004; the wrapper must
///         produce a byte-identical action ID to the equivalent one-call batch.
struct GovernanceActionRequest {
    uint8 actionClass;
    address target;
    uint256 value;
    bytes4 selector;
    bytes callData;
    bytes32 scopeHash;
    bytes32 oldValueHash;
    bytes32 newValueHash;
    uint64 notBefore;
    uint64 expiresAfter;
    bytes32 reasonHash;
    string reasonURI;
    bytes32 manifestHash;
}

/// @notice Long-term governance action classes (ADR 0004, Future-Proof
///         Governance Extensions). Numeric IDs follow the pinned list order.
library StreamGovernanceActionClasses {
    uint8 internal constant IMMEDIATE_TIGHTENING = 0;
    uint8 internal constant DELAYED_LOOSENING = 1;
    uint8 internal constant TERMINAL_FREEZE = 2;
    uint8 internal constant POINTER_REPLACEMENT = 3;
    uint8 internal constant FUNDS_RECOVERY = 4;
    uint8 internal constant SUCCESSOR_DECLARATION = 5;
}

/// @notice Staged governance executor implementing the canonical action
///         identity, batch execution, window floors, and veto surface of
///         ADR 0004 [GOV-ACTION-ID], [GOV-BATCH], and [GOV-WINDOWS].
interface IStreamGovernanceExecutor {
    /// @notice Reverts when the caller may not schedule or cancel actions.
    error GovernanceActorNotAuthorized(address actor);
    /// @notice Reverts on scheduling with an action class outside the pinned set.
    error UnknownActionClass(uint8 actionClass);
    /// @notice Reverts on scheduling an empty batch.
    error EmptyGovernanceBatch();
    /// @notice Reverts when `callDatas` does not pair one-to-one with `calls`.
    error CallDataCountMismatch(uint256 callCount, uint256 callDataCount);
    /// @notice Reverts when scheduling a batch whose exact calldata preimages
    ///         have not been published onchain ([GOV-BATCH] rule 5).
    error CallDataNotPublished(bytes32 callDataKey);
    /// @notice Reverts when a supplied calldata blob does not hash to `callDataHash`.
    error CallDataHashMismatch(uint256 callIndex);
    /// @notice Reverts when calldata is 1-3 bytes and cannot carry a selector.
    error CallDataTooShort(uint256 callIndex);
    /// @notice Reverts when calldata's leading selector differs from the pinned selector.
    error CallSelectorMismatch(uint256 callIndex);
    /// @notice Reverts on zero-address call targets.
    error ZeroGovernanceTarget(uint256 callIndex);
    /// @notice Reverts when an IMMEDIATE_TIGHTENING call is not registered as
    ///         tightening by the classifier.
    error NotClassifiedTightening(address target, bytes4 selector);
    /// @notice Reverts when `notBefore` is earlier than the class minimum delay.
    error DelayBelowClassMinimum(uint8 actionClass, uint64 notBefore, uint64 earliest);
    /// @notice Reverts when the open-to-execute window is below the 7-day floor.
    error OpenWindowBelowFloor(uint64 notBefore, uint64 expiresAfter);
    /// @notice Reverts when `expiresAfter` is not after `notBefore` or exceeds
    ///         the launch-pinned maximum action lifetime.
    error InvalidActionWindow(uint64 notBefore, uint64 expiresAfter);
    /// @notice Reverts when acting on an action ID with no stored record.
    error GovernanceActionUnknown(bytes32 actionId);
    /// @notice Reverts when the action is not in the required lifecycle status.
    error GovernanceActionNotScheduled(bytes32 actionId);
    /// @notice Reverts on executing before `notBefore`.
    error GovernanceActionNotExecutable(bytes32 actionId, uint64 notBefore);
    /// @notice Reverts on executing or materializing against the expiry boundary.
    error GovernanceActionExpiredWindow(bytes32 actionId, uint64 expiresAfter);
    /// @notice Reverts when the recomputed calls hash differs from the stored action.
    error CallsHashMismatch(bytes32 actionId);
    /// @notice Reverts when the recomputed action ID differs from the stored action.
    error ActionIdMismatch(bytes32 actionId);
    /// @notice Reverts when `msg.value` does not equal the batch value sum.
    error BatchValueMismatch(uint256 expected, uint256 supplied);
    /// @notice Reverts when a non-native-transfer call targets an address without code.
    error TargetHasNoCode(uint256 callIndex, address target);
    /// @notice Reverts when an empty-calldata value transfer targets an
    ///         unapproved native receiver.
    error NativeReceiverNotApproved(address target);
    /// @notice Reverts when a batch call fails without revert data.
    error GovernanceCallFailed(bytes32 actionId, uint256 callIndex);
    /// @notice Reverts when execution leaves surplus value in the executor.
    error BatchValueSurplus(uint256 surplus);
    /// @notice Reverts when the veto caller does not hold ROLE_TERMINAL_FREEZE_VETO.
    error NotTerminalFreezeVetoGuardian(address actor);
    /// @notice Reverts when vetoing a non-terminal-freeze action.
    error NotTerminalFreezeAction(bytes32 actionId);
    /// @notice Reverts when vetoing after the veto deadline.
    error VetoDeadlinePassed(bytes32 actionId, uint64 vetoDeadline);
    /// @notice Reverts when materializing expiry before `expiresAfter`.
    error GovernanceActionNotExpired(bytes32 actionId, uint64 expiresAfter);

    event GovernanceActionScheduled(
        uint16 schemaVersion,
        bytes32 indexed actionId,
        uint8 indexed actionClass,
        address indexed target,
        uint256 value,
        bytes4 selector,
        bytes32 callHash,
        bytes32 scopeHash,
        bytes32 oldValueHash,
        bytes32 newValueHash,
        uint64 notBefore,
        uint64 expiresAfter,
        uint256 nonce,
        address proposer,
        bytes32 reasonHash,
        string reasonURI,
        bytes32 manifestHash
    );

    event GovernanceActionExecuted(
        uint16 schemaVersion,
        bytes32 indexed actionId,
        uint8 indexed actionClass,
        address indexed target,
        uint256 value,
        bytes4 selector,
        bytes32 callHash,
        bytes32 scopeHash,
        bytes32 oldValueHash,
        bytes32 newValueHash,
        address executor,
        bytes32 manifestHash
    );

    event GovernanceActionCancelled(
        uint16 schemaVersion,
        bytes32 indexed actionId,
        uint8 indexed actionClass,
        address indexed target,
        bytes4 selector,
        bytes32 callHash,
        bytes32 scopeHash,
        address canceller,
        bytes32 reasonHash,
        string reasonURI
    );

    event GovernanceActionVetoed(
        uint16 schemaVersion,
        bytes32 indexed actionId,
        uint8 indexed actionClass,
        address indexed vetoer,
        bytes32 scopeHash,
        bytes32 reasonHash
    );

    /// @notice Emitted when a virtual expiry is materialized into storage.
    event GovernanceActionExpired(
        uint16 schemaVersion,
        bytes32 indexed actionId,
        uint8 indexed actionClass,
        address materializer
    );

    /// @notice Emitted when a calldata preimage set is published onchain.
    event GovernanceCallDataPublished(
        bytes32 indexed callDataKey, address pointer, address publisher
    );

    event GovernanceProposerUpdated(address indexed account, bool enabled, address indexed admin);
    event GovernanceCancellerUpdated(address indexed account, bool enabled, address indexed admin);
    event TighteningCallUpdated(
        address indexed target, bytes4 indexed selector, bool tightening, address indexed admin
    );
    event ApprovedNativeReceiverUpdated(
        address indexed receiver, bool approved, address indexed admin
    );

    /// @notice Returns the stored action; while `SCHEDULED` and past
    ///         `expiresAfter`, the returned status is virtually `EXPIRED`.
    function governanceAction(bytes32 actionId) external view returns (GovernanceAction memory);

    /// @notice Returns the next nonce consumed by scheduling.
    function governanceNonce() external view returns (uint256);

    /// @notice Returns the launch-pinned minimum delay for `actionClass`.
    function minimumDelay(uint8 actionClass) external view returns (uint64);

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

    /// @notice Returns the published SSTORE2 pointer for a calldata key, or
    ///         the zero address when unpublished.
    function publishedCallData(bytes32 callDataKey) external view returns (address pointer);

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

    /// @notice Returns the veto guardian resolved through the role registry and
    ///         the veto deadline of the scope's live terminal-freeze action.
    function terminalFreezeVetoGuardian(bytes32 scopeHash)
        external
        view
        returns (address guardian, uint64 vetoDeadline);

    /// @notice Vetoes a scheduled terminal-freeze action before its veto deadline.
    function vetoTerminalFreeze(bytes32 actionId, bytes32 reasonHash) external;

    /// @notice Returns the in-flight action context during batch execution so
    ///         governed targets can verify the executing action class.
    function currentAction()
        external
        view
        returns (bool executing, bytes32 actionId, uint8 actionClass);

    /// @notice Returns the SSTORE2 pointer holding the scheduled calldata
    ///         preimages for `actionId` ([LTA-PAYLOAD-DISCOVERY] typed pointer).
    function scheduledCallDataPointer(bytes32 actionId) external view returns (address);

    /// @notice Reads back the exact scheduled calldata preimages for `actionId`.
    function scheduledCallData(bytes32 actionId) external view returns (bytes[] memory);
}
