// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamGovernanceExecutor.sol";
import "./IStreamRoleRegistry.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./SSTORE2.sol";
import "./StreamRoles.sol";

/// @notice Staged governance executor for 6529Stream implementing ADR 0004
///         [GOV-ACTION-ID] canonical action identity, [GOV-BATCH] atomic
///         payable batches, [GOV-WINDOWS] delay/window floors and the
///         terminal-freeze veto surface, with scheduled calldata preimages
///         published onchain via SSTORE2 (ADR 0013 decision U5).
/// @dev The owner is `GovernanceRoot`. Scheduling and cancellation are
///     role-gated (owner, registered proposers/cancellers, and the action's
///     proposer for cancellation); execution is permissionless inside the
///     open-to-execute window. Executor configuration is mutable by the owner
///     or by a governed self-call so post-bootstrap operation can run fully
///     through the staged model.
contract StreamGovernanceExecutor is IStreamGovernanceExecutor, Ownable, ReentrancyGuard {
    /// @notice Batch calls-hash domain pinned by ADR 0004 [GOV-ACTION-ID].
    bytes32 public constant STREAM_GOVERNANCE_CALLS_V1 =
        keccak256("6529STREAM_GOVERNANCE_CALLS_V1");
    /// @notice Action identity domain pinned by ADR 0004 [GOV-ACTION-ID].
    bytes32 public constant STREAM_GOVERNANCE_ACTION_V1 =
        keccak256("6529STREAM_GOVERNANCE_ACTION_V1");

    /// @notice Schema version carried by governance events.
    uint16 public constant SCHEMA_VERSION = 1;
    /// @notice Minimum delay for delayed loosening and pointer replacement
    ///         (two-tier model DELAYED floor, ADR 0004).
    uint64 public constant MINIMUM_DELAY_DELAYED = 48 hours;
    /// @notice Terminal-freeze guardian/veto window floor ([GOV-WINDOWS] rule 2).
    uint64 public constant TERMINAL_FREEZE_VETO_FLOOR = 72 hours;
    /// @notice Funds recovery launch floor (ADR 0004 exception floors).
    uint64 public constant MINIMUM_DELAY_FUNDS_RECOVERY = 14 days;
    /// @notice Successor declaration launch floor (ADR 0004 exception floors).
    uint64 public constant MINIMUM_DELAY_SUCCESSOR_DECLARATION = 30 days;
    /// @notice Open-to-execute window floor for delayed classes ([GOV-WINDOWS] rule 1).
    uint64 public constant OPEN_TO_EXECUTE_WINDOW_FLOOR = 7 days;
    /// @notice Emergency coordination latency assumption ([GOV-WINDOWS] rule 2);
    ///         consumed by conformance-matrix gates with the role registry's
    ///         redundancy views, not enforced as an onchain delay.
    uint64 public constant EMERGENCY_ASSUMPTION_LATENCY = 4 hours;
    /// @notice Launch-pinned maximum action lifetime bound on `expiresAfter`.
    uint64 public constant MAX_ACTION_LIFETIME = 365 days;

    /// @notice `keccak256` of the `GovernanceActionScheduled` signature.
    /// @dev The scheduling event carries 17 pinned fields, beyond what legacy
    ///     codegen can stack for a Solidity `emit`, so `_emitActionScheduled`
    ///     emits it via `log4` with hand-laid ABI data; golden tests assert
    ///     topic and data byte layout against this constant.
    bytes32 public constant GOVERNANCE_ACTION_SCHEDULED_TOPIC = keccak256(
        "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
    );

    /// @notice Role registry resolving [GOV-ROLES] constants, including
    ///         ROLE_TERMINAL_FREEZE_VETO for the veto surface.
    IStreamRoleRegistry public immutable roleRegistry;

    mapping(bytes32 => GovernanceAction) private _actions;
    mapping(bytes32 => uint256) private _actionNonces;
    mapping(bytes32 => address) private _callDataPointers;
    // content-addressed published calldata preimage blobs ([GOV-BATCH] rule 5)
    mapping(bytes32 => address) private _publishedCallData;
    mapping(address => bool) private _proposers;
    mapping(address => bool) private _cancellers;
    mapping(address => mapping(bytes4 => bool)) private _tighteningCalls;
    mapping(address => bool) private _approvedNativeReceivers;
    // scopeHash => action ID of the latest scheduled terminal-freeze action.
    mapping(bytes32 => bytes32) private _latestTerminalFreezeAction;

    uint256 private _nonce;
    bool private _executing;
    bytes32 private _currentActionId;
    uint8 private _currentActionClass;

    /// @dev Internal scheduling context; not part of any pinned surface.
    struct ScheduleContext {
        uint8 actionClass;
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
        uint64 notBefore;
        uint64 expiresAfter;
        bytes32 reasonHash;
        string reasonURI;
        bytes32 manifestHash;
    }

    modifier onlyOwnerOrSelf() {
        if (msg.sender != owner() && msg.sender != address(this)) {
            revert GovernanceActorNotAuthorized(msg.sender);
        }
        _;
    }

    constructor(IStreamRoleRegistry roleRegistry_) {
        require(address(roleRegistry_) != address(0), "Zero role registry");
        roleRegistry = roleRegistry_;
    }

    /// @notice Registers or removes a scheduling proposer.
    function registerProposer(address account, bool enabled) external onlyOwnerOrSelf {
        require(account != address(0), "Zero proposer");
        _proposers[account] = enabled;
        emit GovernanceProposerUpdated(account, enabled, msg.sender);
    }

    /// @notice Registers or removes a canceller (for example a guardian module).
    function registerCanceller(address account, bool enabled) external onlyOwnerOrSelf {
        require(account != address(0), "Zero canceller");
        _cancellers[account] = enabled;
        emit GovernanceCancellerUpdated(account, enabled, msg.sender);
    }

    /// @notice Tightening classifier: registers `(target, selector)` pairs
    ///         proven unable to loosen policy, eligible for zero-delay
    ///         IMMEDIATE_TIGHTENING scheduling (ADR 0004 execution rule 2).
    function setTighteningCall(address target, bytes4 selector, bool tightening)
        external
        onlyOwnerOrSelf
    {
        require(target != address(0), "Zero target");
        _tighteningCalls[target][selector] = tightening;
        emit TighteningCallUpdated(target, selector, tightening, msg.sender);
    }

    /// @notice Approves a receiver for empty-calldata native ETH transfer calls
    ///         (ADR 0004 execution rule 4).
    function setApprovedNativeReceiver(address receiver, bool approved) external onlyOwnerOrSelf {
        require(receiver != address(0), "Zero receiver");
        _approvedNativeReceivers[receiver] = approved;
        emit ApprovedNativeReceiverUpdated(receiver, approved, msg.sender);
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function publishGovernanceCallData(bytes[] calldata callDatas)
        external
        override
        returns (address pointer)
    {
        return _publishCallData(callDatas);
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function publishedCallData(bytes32 callDataKey) external view override returns (address) {
        return _publishedCallData[callDataKey];
    }

    /// @inheritdoc IStreamGovernanceExecutor
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
    ) external override returns (bytes32 actionId) {
        ScheduleContext memory ctx;
        ctx.actionClass = actionClass;
        ctx.scopeHash = scopeHash;
        ctx.oldValueHash = oldValueHash;
        ctx.newValueHash = newValueHash;
        ctx.notBefore = notBefore;
        ctx.expiresAfter = expiresAfter;
        ctx.reasonHash = reasonHash;
        ctx.reasonURI = reasonURI;
        ctx.manifestHash = manifestHash;
        return _schedule(ctx, calls);
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function scheduleGovernanceAction(GovernanceActionRequest calldata request)
        external
        override
        returns (bytes32 actionId)
    {
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall({
            target: request.target,
            value: request.value,
            selector: request.selector,
            callDataHash: keccak256(request.callData)
        });
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = request.callData;
        // The single-call wrapper carries the preimage, so it publishes
        // directly before scheduling the equivalent batch of one.
        _publishCallData(callDatas);
        ScheduleContext memory ctx;
        ctx.actionClass = request.actionClass;
        ctx.scopeHash = request.scopeHash;
        ctx.oldValueHash = request.oldValueHash;
        ctx.newValueHash = request.newValueHash;
        ctx.notBefore = request.notBefore;
        ctx.expiresAfter = request.expiresAfter;
        ctx.reasonHash = request.reasonHash;
        ctx.reasonURI = request.reasonURI;
        ctx.manifestHash = request.manifestHash;
        return _schedule(ctx, calls);
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function executeGovernanceBatch(
        bytes32 actionId,
        GovernanceCall[] calldata calls,
        bytes[] calldata callDatas
    ) external payable override nonReentrant {
        _execute(actionId, calls, callDatas);
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function executeGovernanceAction(bytes32 actionId, bytes calldata callData)
        external
        payable
        override
        nonReentrant
    {
        GovernanceAction storage action = _actions[actionId];
        if (action.status == GovernanceActionStatus.NONE) {
            revert GovernanceActionUnknown(actionId);
        }
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall({
            target: action.target,
            value: action.value,
            selector: action.selector,
            callDataHash: keccak256(callData)
        });
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = callData;
        _execute(actionId, calls, callDatas);
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function cancelGovernanceAction(bytes32 actionId, bytes32 reasonHash) external override {
        GovernanceAction storage action = _actions[actionId];
        if (action.status == GovernanceActionStatus.NONE) {
            revert GovernanceActionUnknown(actionId);
        }
        if (action.status != GovernanceActionStatus.SCHEDULED) {
            revert GovernanceActionNotScheduled(actionId);
        }
        if (msg.sender != owner() && !_cancellers[msg.sender] && msg.sender != action.proposer) {
            revert GovernanceActorNotAuthorized(msg.sender);
        }
        action.status = GovernanceActionStatus.CANCELLED;
        action.canceller = msg.sender;
        emit GovernanceActionCancelled(
            SCHEMA_VERSION,
            actionId,
            action.actionClass,
            action.target,
            action.selector,
            action.callHash,
            action.scopeHash,
            msg.sender,
            reasonHash,
            ""
        );
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function vetoTerminalFreeze(bytes32 actionId, bytes32 reasonHash) external override {
        GovernanceAction storage action = _actions[actionId];
        if (action.status == GovernanceActionStatus.NONE) {
            revert GovernanceActionUnknown(actionId);
        }
        if (action.actionClass != StreamGovernanceActionClasses.TERMINAL_FREEZE) {
            revert NotTerminalFreezeAction(actionId);
        }
        if (action.status != GovernanceActionStatus.SCHEDULED) {
            revert GovernanceActionNotScheduled(actionId);
        }
        if (block.timestamp >= action.notBefore) {
            revert VetoDeadlinePassed(actionId, action.notBefore);
        }
        if (!roleRegistry.hasRole(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, msg.sender)) {
            revert NotTerminalFreezeVetoGuardian(msg.sender);
        }
        action.status = GovernanceActionStatus.VETOED;
        action.vetoer = msg.sender;
        emit GovernanceActionVetoed(
            SCHEMA_VERSION, actionId, action.actionClass, msg.sender, action.scopeHash, reasonHash
        );
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function materializeExpiredAction(bytes32 actionId) external override {
        GovernanceAction storage action = _actions[actionId];
        if (action.status == GovernanceActionStatus.NONE) {
            revert GovernanceActionUnknown(actionId);
        }
        if (action.status != GovernanceActionStatus.SCHEDULED) {
            revert GovernanceActionNotScheduled(actionId);
        }
        if (block.timestamp <= action.expiresAfter) {
            revert GovernanceActionNotExpired(actionId, action.expiresAfter);
        }
        action.status = GovernanceActionStatus.EXPIRED;
        emit GovernanceActionExpired(SCHEMA_VERSION, actionId, action.actionClass, msg.sender);
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function governanceAction(bytes32 actionId)
        external
        view
        override
        returns (GovernanceAction memory)
    {
        GovernanceAction memory action = _actions[actionId];
        if (
            action.status == GovernanceActionStatus.SCHEDULED
                && block.timestamp > action.expiresAfter
        ) {
            action.status = GovernanceActionStatus.EXPIRED;
        }
        return action;
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function governanceNonce() external view override returns (uint256) {
        return _nonce;
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function minimumDelay(uint8 actionClass) public view override returns (uint64) {
        if (actionClass == StreamGovernanceActionClasses.IMMEDIATE_TIGHTENING) {
            return 0;
        }
        if (
            actionClass == StreamGovernanceActionClasses.DELAYED_LOOSENING
                || actionClass == StreamGovernanceActionClasses.POINTER_REPLACEMENT
        ) {
            return MINIMUM_DELAY_DELAYED;
        }
        if (actionClass == StreamGovernanceActionClasses.TERMINAL_FREEZE) {
            return TERMINAL_FREEZE_VETO_FLOOR;
        }
        if (actionClass == StreamGovernanceActionClasses.FUNDS_RECOVERY) {
            return MINIMUM_DELAY_FUNDS_RECOVERY;
        }
        if (actionClass == StreamGovernanceActionClasses.SUCCESSOR_DECLARATION) {
            return MINIMUM_DELAY_SUCCESSOR_DECLARATION;
        }
        revert UnknownActionClass(actionClass);
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function terminalFreezeVetoGuardian(bytes32 scopeHash)
        external
        view
        override
        returns (address guardian, uint64 vetoDeadline)
    {
        if (roleRegistry.roleHolderCount(StreamRoles.ROLE_TERMINAL_FREEZE_VETO) > 0) {
            guardian = roleRegistry.roleHolderAt(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, 0);
        }
        bytes32 actionId = _latestTerminalFreezeAction[scopeHash];
        if (actionId != bytes32(0)) {
            GovernanceAction storage action = _actions[actionId];
            if (
                action.status == GovernanceActionStatus.SCHEDULED
                    && block.timestamp < action.notBefore
            ) {
                vetoDeadline = action.notBefore;
            }
        }
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function currentAction()
        external
        view
        override
        returns (bool executing, bytes32 actionId, uint8 actionClass)
    {
        return (_executing, _currentActionId, _currentActionClass);
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function scheduledCallDataPointer(bytes32 actionId) external view override returns (address) {
        return _callDataPointers[actionId];
    }

    /// @inheritdoc IStreamGovernanceExecutor
    function scheduledCallData(bytes32 actionId) external view override returns (bytes[] memory) {
        address pointer = _callDataPointers[actionId];
        if (pointer == address(0)) {
            revert GovernanceActionUnknown(actionId);
        }
        return abi.decode(SSTORE2.read(pointer), (bytes[]));
    }

    /// @notice Returns true when `(target, selector)` is classified tightening.
    function isTighteningCall(address target, bytes4 selector) external view returns (bool) {
        return _tighteningCalls[target][selector];
    }

    /// @notice Returns true when `account` is a registered proposer.
    function isProposer(address account) external view returns (bool) {
        return _proposers[account];
    }

    /// @notice Returns true when `account` is a registered canceller.
    function isCanceller(address account) external view returns (bool) {
        return _cancellers[account];
    }

    /// @notice Returns true when `receiver` may receive empty-calldata native transfers.
    function isApprovedNativeReceiver(address receiver) external view returns (bool) {
        return _approvedNativeReceivers[receiver];
    }

    function _schedule(ScheduleContext memory ctx, GovernanceCall[] memory calls)
        private
        returns (bytes32 actionId)
    {
        if (msg.sender != owner() && !_proposers[msg.sender]) {
            revert GovernanceActorNotAuthorized(msg.sender);
        }
        // [GOV-BATCH] rule 5: the exact calldata preimages must already be
        // published onchain; the action record stores the pointer for the
        // full open-to-execute window.
        address callDataPointer = _requirePublishedCallData(calls);
        uint256 totalValue = _validateCalls(
            ctx.actionClass, calls, abi.decode(SSTORE2.read(callDataPointer), (bytes[]))
        );
        _validateWindow(ctx.actionClass, ctx.notBefore, ctx.expiresAfter);

        bytes32 callsHash = keccak256(abi.encode(STREAM_GOVERNANCE_CALLS_V1, calls));
        uint256 nonceUsed = _nonce;
        _nonce = nonceUsed + 1;
        actionId = _computeActionId(ctx, callsHash, nonceUsed);

        GovernanceAction storage action = _actions[actionId];
        if (action.status != GovernanceActionStatus.NONE) {
            revert GovernanceActionNotScheduled(actionId);
        }
        action.status = GovernanceActionStatus.SCHEDULED;
        action.actionClass = ctx.actionClass;
        action.target = calls[0].target;
        action.value = totalValue;
        action.selector = calls[0].selector;
        action.callHash = callsHash;
        action.scopeHash = ctx.scopeHash;
        action.oldValueHash = ctx.oldValueHash;
        action.newValueHash = ctx.newValueHash;
        action.notBefore = ctx.notBefore;
        action.expiresAfter = ctx.expiresAfter;
        action.proposer = msg.sender;
        action.reasonHash = ctx.reasonHash;
        action.reasonURI = ctx.reasonURI;
        action.manifestHash = ctx.manifestHash;

        _actionNonces[actionId] = nonceUsed;
        _callDataPointers[actionId] = callDataPointer;

        if (ctx.actionClass == StreamGovernanceActionClasses.TERMINAL_FREEZE) {
            _latestTerminalFreezeAction[ctx.scopeHash] = actionId;
        }

        _emitActionScheduled(
            actionId, ctx, calls[0].target, calls[0].selector, totalValue, callsHash, nonceUsed
        );
    }

    function _publishCallData(bytes[] memory callDatas) private returns (address pointer) {
        if (callDatas.length == 0) {
            revert EmptyGovernanceBatch();
        }
        bytes32[] memory hashes = new bytes32[](callDatas.length);
        for (uint256 i = 0; i < callDatas.length; i++) {
            hashes[i] = keccak256(callDatas[i]);
        }
        bytes32 callDataKey = keccak256(abi.encodePacked(hashes));
        pointer = _publishedCallData[callDataKey];
        if (pointer != address(0)) {
            return pointer;
        }
        pointer = SSTORE2.write(abi.encode(callDatas));
        _publishedCallData[callDataKey] = pointer;
        emit GovernanceCallDataPublished(callDataKey, pointer, msg.sender);
    }

    function _requirePublishedCallData(GovernanceCall[] memory calls)
        private
        view
        returns (address pointer)
    {
        if (calls.length == 0) {
            revert EmptyGovernanceBatch();
        }
        bytes32[] memory hashes = new bytes32[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            hashes[i] = calls[i].callDataHash;
        }
        bytes32 callDataKey = keccak256(abi.encodePacked(hashes));
        pointer = _publishedCallData[callDataKey];
        if (pointer == address(0)) {
            revert CallDataNotPublished(callDataKey);
        }
    }

    /// @dev Emits `GovernanceActionScheduled` via `log4`. Non-indexed data is
    ///     ABI-encoded in word chunks: 14 head words (the string head slot at
    ///     index 13 points to offset 0x1C0), then the string length, raw
    ///     bytes, and canonical zero padding.
    function _emitActionScheduled(
        bytes32 actionId,
        ScheduleContext memory ctx,
        address target,
        bytes4 selector,
        uint256 totalValue,
        bytes32 callsHash,
        uint256 nonceUsed
    ) private {
        bytes memory raw = bytes(ctx.reasonURI);
        bytes memory data = bytes.concat(
            abi.encode(
                uint256(SCHEMA_VERSION),
                totalValue,
                bytes32(selector),
                callsHash,
                ctx.scopeHash,
                ctx.oldValueHash,
                ctx.newValueHash
            ),
            abi.encode(
                uint256(ctx.notBefore),
                uint256(ctx.expiresAfter),
                nonceUsed,
                uint256(uint160(msg.sender)),
                ctx.reasonHash,
                uint256(0x1C0),
                ctx.manifestHash
            ),
            abi.encode(raw.length),
            raw,
            new bytes((32 - (raw.length % 32)) % 32)
        );
        bytes32 topic0 = GOVERNANCE_ACTION_SCHEDULED_TOPIC;
        uint256 topic2 = uint256(ctx.actionClass);
        uint256 topic3 = uint256(uint160(target));
        assembly {
            log4(add(data, 0x20), mload(data), topic0, actionId, topic2, topic3)
        }
    }

    function _execute(bytes32 actionId, GovernanceCall[] memory calls, bytes[] memory callDatas)
        private
    {
        uint256 startBalance = address(this).balance;
        GovernanceAction storage action = _actions[actionId];
        if (action.status == GovernanceActionStatus.NONE) {
            revert GovernanceActionUnknown(actionId);
        }
        if (action.status != GovernanceActionStatus.SCHEDULED) {
            revert GovernanceActionNotScheduled(actionId);
        }
        if (block.timestamp < action.notBefore) {
            revert GovernanceActionNotExecutable(actionId, action.notBefore);
        }
        if (block.timestamp > action.expiresAfter) {
            revert GovernanceActionExpiredWindow(actionId, action.expiresAfter);
        }

        // [GOV-BATCH] rule 1: recompute callsHash and actionId from the
        // supplied batch and require both to match the stored action.
        bytes32 callsHash = keccak256(abi.encode(STREAM_GOVERNANCE_CALLS_V1, calls));
        if (callsHash != action.callHash) {
            revert CallsHashMismatch(actionId);
        }
        if (_recomputeActionId(action, callsHash, _actionNonces[actionId]) != actionId) {
            revert ActionIdMismatch(actionId);
        }
        if (callDatas.length != calls.length) {
            revert CallDataCountMismatch(calls.length, callDatas.length);
        }

        uint256 totalValue;
        for (uint256 i = 0; i < calls.length; i++) {
            if (keccak256(callDatas[i]) != calls[i].callDataHash) {
                revert CallDataHashMismatch(i);
            }
            totalValue += calls[i].value;
        }
        // [GOV-BATCH] rule 2: msg.value equals the exact batch value sum.
        if (msg.value != totalValue) {
            revert BatchValueMismatch(totalValue, msg.value);
        }

        action.status = GovernanceActionStatus.EXECUTED;
        action.executor = msg.sender;
        _executing = true;
        _currentActionId = actionId;
        _currentActionClass = action.actionClass;

        for (uint256 i = 0; i < calls.length; i++) {
            _executeCall(actionId, i, calls[i], callDatas[i]);
        }

        _executing = false;
        _currentActionId = bytes32(0);
        _currentActionClass = 0;

        // [GOV-BATCH] rule 2: refunded surplus reverts the batch rather than
        // stranding value in the governance contract.
        uint256 expectedBalance = startBalance - totalValue;
        if (address(this).balance != expectedBalance) {
            revert BatchValueSurplus(address(this).balance - expectedBalance);
        }

        emit GovernanceActionExecuted(
            SCHEMA_VERSION,
            actionId,
            action.actionClass,
            action.target,
            action.value,
            action.selector,
            action.callHash,
            action.scopeHash,
            action.oldValueHash,
            action.newValueHash,
            msg.sender,
            action.manifestHash
        );
    }

    function _executeCall(
        bytes32 actionId,
        uint256 callIndex,
        GovernanceCall memory call_,
        bytes memory callData
    ) private {
        if (callData.length == 0) {
            if (call_.target.code.length == 0 && !_approvedNativeReceivers[call_.target]) {
                revert NativeReceiverNotApproved(call_.target);
            }
        } else if (call_.target.code.length == 0) {
            revert TargetHasNoCode(callIndex, call_.target);
        }
        (bool success, bytes memory returnData) = call_.target.call{ value: call_.value }(callData);
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(returnData, 0x20), mload(returnData))
                }
            }
            revert GovernanceCallFailed(actionId, callIndex);
        }
    }

    function _validateCalls(
        uint8 actionClass,
        GovernanceCall[] memory calls,
        bytes[] memory callDatas
    ) private view returns (uint256 totalValue) {
        if (calls.length == 0) {
            revert EmptyGovernanceBatch();
        }
        if (callDatas.length != calls.length) {
            revert CallDataCountMismatch(calls.length, callDatas.length);
        }
        bool immediate = actionClass == StreamGovernanceActionClasses.IMMEDIATE_TIGHTENING;
        for (uint256 i = 0; i < calls.length; i++) {
            GovernanceCall memory call_ = calls[i];
            bytes memory callData = callDatas[i];
            if (call_.target == address(0)) {
                revert ZeroGovernanceTarget(i);
            }
            if (keccak256(callData) != call_.callDataHash) {
                revert CallDataHashMismatch(i);
            }
            if (callData.length == 0) {
                if (call_.selector != bytes4(0)) {
                    revert CallSelectorMismatch(i);
                }
            } else if (callData.length < 4) {
                revert CallDataTooShort(i);
            } else if (_firstSelector(callData) != call_.selector) {
                revert CallSelectorMismatch(i);
            }
            if (immediate && !_tighteningCalls[call_.target][call_.selector]) {
                revert NotClassifiedTightening(call_.target, call_.selector);
            }
            totalValue += call_.value;
        }
    }

    function _validateWindow(uint8 actionClass, uint64 notBefore, uint64 expiresAfter)
        private
        view
    {
        uint64 delayFloor = minimumDelay(actionClass);
        uint64 earliest = uint64(block.timestamp) + delayFloor;
        if (notBefore < earliest) {
            revert DelayBelowClassMinimum(actionClass, notBefore, earliest);
        }
        if (expiresAfter <= notBefore) {
            revert InvalidActionWindow(notBefore, expiresAfter);
        }
        // [GOV-WINDOWS] rule 1: delayed classes keep a 7-day open-to-execute window.
        if (delayFloor > 0 && expiresAfter - notBefore < OPEN_TO_EXECUTE_WINDOW_FLOOR) {
            revert OpenWindowBelowFloor(notBefore, expiresAfter);
        }
        if (expiresAfter > uint64(block.timestamp) + MAX_ACTION_LIFETIME) {
            revert InvalidActionWindow(notBefore, expiresAfter);
        }
    }

    function _computeActionId(ScheduleContext memory ctx, bytes32 callsHash, uint256 nonceUsed)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                STREAM_GOVERNANCE_ACTION_V1,
                uint256(block.chainid),
                address(this),
                uint8(ctx.actionClass),
                callsHash,
                bytes32(ctx.scopeHash),
                bytes32(ctx.oldValueHash),
                bytes32(ctx.newValueHash),
                uint256(nonceUsed),
                uint64(ctx.notBefore),
                uint64(ctx.expiresAfter),
                bytes32(ctx.reasonHash),
                bytes32(ctx.manifestHash)
            )
        );
    }

    function _recomputeActionId(
        GovernanceAction storage action,
        bytes32 callsHash,
        uint256 nonceUsed
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                STREAM_GOVERNANCE_ACTION_V1,
                uint256(block.chainid),
                address(this),
                uint8(action.actionClass),
                callsHash,
                bytes32(action.scopeHash),
                bytes32(action.oldValueHash),
                bytes32(action.newValueHash),
                uint256(nonceUsed),
                uint64(action.notBefore),
                uint64(action.expiresAfter),
                bytes32(action.reasonHash),
                bytes32(action.manifestHash)
            )
        );
    }

    function _firstSelector(bytes memory callData) private pure returns (bytes4 selector) {
        assembly {
            selector := mload(add(callData, 0x20))
        }
    }
}
