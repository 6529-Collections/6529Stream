// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IStreamGovernanceExecutor.sol";
import "../smart-contracts/StreamGovernanceExecutor.sol";
import "../smart-contracts/StreamRoleRegistry.sol";
import "../smart-contracts/StreamRoles.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";

contract GovernedTargetMock {
    uint256 public value;
    uint256 public lastPaidValue;
    address public lastSender;
    bool public shouldRevert;

    function setShouldRevert(bool shouldRevert_) external {
        shouldRevert = shouldRevert_;
    }

    function setValue(uint256 newValue) external payable {
        if (shouldRevert) {
            revert("target revert");
        }
        value = newValue;
        lastPaidValue = msg.value;
        lastSender = msg.sender;
    }
}

contract GovernedContextProbeMock {
    IStreamGovernanceExecutor public immutable executor;
    bool public sawExecuting;
    bytes32 public sawActionId;
    uint8 public sawActionClass;

    constructor(IStreamGovernanceExecutor executor_) {
        executor = executor_;
    }

    function probe() external {
        (sawExecuting, sawActionId, sawActionClass) = executor.currentAction();
    }
}

contract GovernedRefundingMock {
    function refund() external payable {
        selfdestruct(payable(msg.sender));
    }
}

contract StreamGovernanceExecutorTest is CharacterizationTestBase {
    using Assertions for address;
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for string;
    using Assertions for uint256;

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

    event GovernanceActionExpired(
        uint16 schemaVersion,
        bytes32 indexed actionId,
        uint8 indexed actionClass,
        address materializer
    );

    bytes32 private constant SCOPE = keccak256("test-scope");
    bytes32 private constant OLD_VALUE = keccak256("old-value");
    bytes32 private constant NEW_VALUE = keccak256("new-value");
    bytes32 private constant REASON = keccak256("reason");
    bytes32 private constant MANIFEST = keccak256("manifest");
    string private constant REASON_URI = "ipfs://governance-reason";
    uint64 private constant BASE_TIME = 1_000_000;

    StreamRoleRegistry private roleRegistry;
    StreamGovernanceExecutor private executor;
    GovernedTargetMock private target;

    address private proposer = address(0xA11CE);
    address private canceller = address(0xCA4C);
    address private guardian = address(0x6A0D);
    address private stranger = address(0x5719);

    function setUp() public {
        vm.warp(BASE_TIME);
        roleRegistry = new StreamRoleRegistry();
        executor = new StreamGovernanceExecutor(roleRegistry);
        target = new GovernedTargetMock();
        vm.deal(address(this), 1_000 ether);
    }

    // ---------------------------------------------------------------- helpers

    function _singleCall(uint256 callValue, bytes memory callData)
        private
        view
        returns (GovernanceCall[] memory calls, bytes[] memory callDatas)
    {
        calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall({
            target: address(target),
            value: callValue,
            selector: _selectorOf(callData),
            callDataHash: keccak256(callData)
        });
        callDatas = new bytes[](1);
        callDatas[0] = callData;
    }

    function _selectorOf(bytes memory callData) private pure returns (bytes4 selector) {
        if (callData.length < 4) {
            return bytes4(0);
        }
        assembly {
            selector := mload(add(callData, 0x20))
        }
    }

    function _defaultWindow() private view returns (uint64 notBefore, uint64 expiresAfter) {
        notBefore = uint64(block.timestamp) + 48 hours;
        expiresAfter = notBefore + 7 days;
    }

    function _schedule(
        uint8 actionClass,
        GovernanceCall[] memory calls,
        bytes[] memory callDatas,
        uint64 notBefore,
        uint64 expiresAfter
    ) private returns (bytes32 actionId) {
        executor.publishGovernanceCallData(callDatas);
        return executor.scheduleGovernanceBatch(
            actionClass,
            calls,
            SCOPE,
            OLD_VALUE,
            NEW_VALUE,
            notBefore,
            expiresAfter,
            REASON,
            REASON_URI,
            MANIFEST
        );
    }

    function _scheduleDefault(bytes memory callData) private returns (bytes32 actionId) {
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        return _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );
    }

    function _expectedActionId(
        uint8 actionClass,
        GovernanceCall[] memory calls,
        uint256 nonce,
        uint64 notBefore,
        uint64 expiresAfter
    ) private view returns (bytes32) {
        bytes32 callsHash = keccak256(abi.encode(executor.STREAM_GOVERNANCE_CALLS_V1(), calls));
        return keccak256(
            abi.encode(
                executor.STREAM_GOVERNANCE_ACTION_V1(),
                uint256(block.chainid),
                address(executor),
                actionClass,
                callsHash,
                SCOPE,
                OLD_VALUE,
                NEW_VALUE,
                nonce,
                notBefore,
                expiresAfter,
                REASON,
                MANIFEST
            )
        );
    }

    // ------------------------------------------------------------- scheduling

    function testScheduleStoresActionAndPublishesCallData() public {
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (42));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        uint256 nonceBefore = executor.governanceNonce();

        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );

        actionId.assertEq(
            _expectedActionId(
                StreamGovernanceActionClasses.DELAYED_LOOSENING,
                calls,
                nonceBefore,
                notBefore,
                expiresAfter
            ),
            "canonical action id preimage"
        );
        executor.governanceNonce().assertEq(nonceBefore + 1, "nonce consumed");

        GovernanceAction memory action = executor.governanceAction(actionId);
        (uint256(uint8(action.status)))
        .assertEq(uint256(uint8(GovernanceActionStatus.SCHEDULED)), "status scheduled");
        action.target.assertEq(address(target), "stored first-call target");
        action.value.assertEq(0, "stored batch value");
        bytes32(action.selector)
            .assertEq(bytes32(GovernedTargetMock.setValue.selector), "stored first-call selector");
        action.callHash
            .assertEq(
                keccak256(abi.encode(executor.STREAM_GOVERNANCE_CALLS_V1(), calls)),
                "stored callsHash"
            );
        action.scopeHash.assertEq(SCOPE, "stored scope");
        action.oldValueHash.assertEq(OLD_VALUE, "stored old value hash");
        action.newValueHash.assertEq(NEW_VALUE, "stored new value hash");
        uint256(action.notBefore).assertEq(uint256(notBefore), "stored notBefore");
        uint256(action.expiresAfter).assertEq(uint256(expiresAfter), "stored expiresAfter");
        action.proposer.assertEq(address(this), "stored proposer");
        action.reasonHash.assertEq(REASON, "stored reason hash");
        action.reasonURI.assertEq(REASON_URI, "stored reason URI");
        action.manifestHash.assertEq(MANIFEST, "stored manifest hash");

        // [GOV-BATCH] rule 5: the exact preimages are readable from state.
        address pointer = executor.scheduledCallDataPointer(actionId);
        (pointer != address(0)).assertTrue("calldata pointer stored");
        bytes[] memory readBack = executor.scheduledCallData(actionId);
        readBack.length.assertEq(1, "one preimage");
        keccak256(readBack[0]).assertEq(keccak256(callData), "preimage bytes readable");
    }

    function testScheduleEmitsCanonicalEventBytes() public {
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (7));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        uint256 nonceBefore = executor.governanceNonce();

        vm.recordLogs();
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();

        Vm.Log memory scheduled = logs[logs.length - 1];
        scheduled.emitter.assertEq(address(executor), "scheduled event emitter");
        scheduled.topics.length.assertEq(4, "scheduled topic count");
        scheduled.topics[0].assertEq(
            executor.GOVERNANCE_ACTION_SCHEDULED_TOPIC(), "scheduled topic0"
        );
        scheduled.topics[1].assertEq(actionId, "scheduled topic1 actionId");
        scheduled.topics[2].assertEq(
            bytes32(uint256(StreamGovernanceActionClasses.DELAYED_LOOSENING)),
            "scheduled topic2 class"
        );
        scheduled.topics[3].assertEq(
            bytes32(uint256(uint160(address(target)))), "scheduled topic3 target"
        );
        _assertScheduledEventData(scheduled.data, calls, nonceBefore, notBefore, expiresAfter);
    }

    function _assertScheduledEventData(
        bytes memory data,
        GovernanceCall[] memory calls,
        uint256 nonce,
        uint64 notBefore,
        uint64 expiresAfter
    ) private {
        _word(data, 0).assertEq(bytes32(uint256(1)), "data schemaVersion");
        _word(data, 1).assertEq(bytes32(uint256(0)), "data value");
        _word(data, 2).assertEq(bytes32(calls[0].selector), "data selector");
        _word(data, 3)
            .assertEq(
                keccak256(abi.encode(executor.STREAM_GOVERNANCE_CALLS_V1(), calls)), "data callHash"
            );
        _word(data, 4).assertEq(SCOPE, "data scopeHash");
        _word(data, 5).assertEq(OLD_VALUE, "data oldValueHash");
        _word(data, 6).assertEq(NEW_VALUE, "data newValueHash");
        _word(data, 7).assertEq(bytes32(uint256(notBefore)), "data notBefore");
        _word(data, 8).assertEq(bytes32(uint256(expiresAfter)), "data expiresAfter");
        _word(data, 9).assertEq(bytes32(nonce), "data nonce");
        _word(data, 10).assertEq(bytes32(uint256(uint160(address(this)))), "data proposer");
        _word(data, 11).assertEq(REASON, "data reasonHash");
        _word(data, 12).assertEq(bytes32(uint256(0x1C0)), "data string offset");
        _word(data, 13).assertEq(MANIFEST, "data manifestHash");
        _word(data, 14).assertEq(bytes32(bytes(REASON_URI).length), "data string length");
        uint256 padded = ((bytes(REASON_URI).length + 31) / 32) * 32;
        data.length.assertEq(15 * 32 + padded, "data total length");
        bytes memory uriBytes = new bytes(bytes(REASON_URI).length);
        for (uint256 i = 0; i < uriBytes.length; i++) {
            uriBytes[i] = data[15 * 32 + i];
        }
        keccak256(uriBytes).assertEq(keccak256(bytes(REASON_URI)), "data string bytes");
    }

    function _word(bytes memory data, uint256 index) private pure returns (bytes32 word) {
        assembly {
            word := mload(add(add(data, 0x20), mul(index, 0x20)))
        }
    }

    function testScheduleRequiresPublishedCallData() public {
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (1));
        (GovernanceCall[] memory calls,) = _singleCall(0, callData);
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        bytes32 expectedKey = keccak256(abi.encodePacked(keccak256(callData)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.CallDataNotPublished.selector, expectedKey
            )
        );
        executor.scheduleGovernanceBatch(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            SCOPE,
            OLD_VALUE,
            NEW_VALUE,
            notBefore,
            expiresAfter,
            REASON,
            REASON_URI,
            MANIFEST
        );
    }

    function testPublishCallDataIsIdempotentAndContentAddressed() public {
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = abi.encodeCall(GovernedTargetMock.setValue, (9));
        address pointer = executor.publishGovernanceCallData(callDatas);
        (pointer != address(0)).assertTrue("pointer minted");
        executor.publishGovernanceCallData(callDatas).assertEq(pointer, "idempotent republish");
        bytes32 key = keccak256(abi.encodePacked(keccak256(callDatas[0])));
        executor.publishedCallData(key).assertEq(pointer, "content-addressed lookup");

        bytes[] memory empty = new bytes[](0);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.EmptyGovernanceBatch.selector)
        );
        executor.publishGovernanceCallData(empty);
    }

    function testScheduleUnauthorizedReverts() public {
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (1));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        executor.publishGovernanceCallData(callDatas);
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActorNotAuthorized.selector, stranger
            )
        );
        vm.prank(stranger);
        executor.scheduleGovernanceBatch(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            SCOPE,
            OLD_VALUE,
            NEW_VALUE,
            notBefore,
            expiresAfter,
            REASON,
            REASON_URI,
            MANIFEST
        );
    }

    function testRegisteredProposerCanSchedule() public {
        executor.registerProposer(proposer, true);
        executor.isProposer(proposer).assertTrue("proposer registered");
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (1));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        executor.publishGovernanceCallData(callDatas);
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        vm.prank(proposer);
        bytes32 actionId = executor.scheduleGovernanceBatch(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            SCOPE,
            OLD_VALUE,
            NEW_VALUE,
            notBefore,
            expiresAfter,
            REASON,
            REASON_URI,
            MANIFEST
        );
        executor.governanceAction(actionId).proposer.assertEq(proposer, "proposer recorded");
    }

    function testScheduleWindowFloors() public {
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (1));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        executor.publishGovernanceCallData(callDatas);

        // Delay below the 48h DELAYED floor.
        _expectDelayRevert(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            uint64(block.timestamp) + 48 hours - 1,
            uint64(block.timestamp) + 48 hours - 1 + 7 days
        );
        // Terminal freeze below the 72h veto floor ([GOV-WINDOWS] rule 2).
        _expectDelayRevert(
            StreamGovernanceActionClasses.TERMINAL_FREEZE,
            calls,
            uint64(block.timestamp) + 72 hours - 1,
            uint64(block.timestamp) + 72 hours - 1 + 7 days
        );
        // Funds recovery below its 14-day launch floor.
        _expectDelayRevert(
            StreamGovernanceActionClasses.FUNDS_RECOVERY,
            calls,
            uint64(block.timestamp) + 14 days - 1,
            uint64(block.timestamp) + 14 days - 1 + 7 days
        );
        // Successor declaration below its 30-day launch floor.
        _expectDelayRevert(
            StreamGovernanceActionClasses.SUCCESSOR_DECLARATION,
            calls,
            uint64(block.timestamp) + 30 days - 1,
            uint64(block.timestamp) + 30 days - 1 + 7 days
        );

        // Open-to-execute window below the 7-day floor ([GOV-WINDOWS] rule 1).
        uint64 notBefore = uint64(block.timestamp) + 48 hours;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.OpenWindowBelowFloor.selector,
                notBefore,
                notBefore + 7 days - 1
            )
        );
        _scheduleWindow(calls, notBefore, notBefore + 7 days - 1);

        // expiresAfter must exceed notBefore.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.InvalidActionWindow.selector, notBefore, notBefore
            )
        );
        _scheduleWindow(calls, notBefore, notBefore);

        // Maximum action lifetime bound.
        uint64 tooLate = uint64(block.timestamp) + 365 days + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.InvalidActionWindow.selector, notBefore, tooLate
            )
        );
        _scheduleWindow(calls, notBefore, tooLate);

        // Unknown action class.
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.UnknownActionClass.selector, 6)
        );
        _scheduleClass(6, calls, notBefore, notBefore + 7 days);
    }

    function _expectDelayRevert(
        uint8 actionClass,
        GovernanceCall[] memory calls,
        uint64 notBefore,
        uint64 expiresAfter
    ) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.DelayBelowClassMinimum.selector,
                actionClass,
                notBefore,
                uint64(block.timestamp) + executor.minimumDelay(actionClass)
            )
        );
        _scheduleClass(actionClass, calls, notBefore, expiresAfter);
    }

    function _scheduleWindow(GovernanceCall[] memory calls, uint64 notBefore, uint64 expiresAfter)
        private
        returns (bytes32)
    {
        return _scheduleClass(
            StreamGovernanceActionClasses.DELAYED_LOOSENING, calls, notBefore, expiresAfter
        );
    }

    function _scheduleClass(
        uint8 actionClass,
        GovernanceCall[] memory calls,
        uint64 notBefore,
        uint64 expiresAfter
    ) private returns (bytes32) {
        return executor.scheduleGovernanceBatch(
            actionClass,
            calls,
            SCOPE,
            OLD_VALUE,
            NEW_VALUE,
            notBefore,
            expiresAfter,
            REASON,
            REASON_URI,
            MANIFEST
        );
    }

    function testScheduleValidatesCallShape() public {
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();

        // Zero target.
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (1));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        calls[0].target = address(0);
        executor.publishGovernanceCallData(callDatas);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.ZeroGovernanceTarget.selector, 0)
        );
        _scheduleWindow(calls, notBefore, expiresAfter);

        // 1-3 byte calldata cannot carry a selector.
        bytes memory shortData = hex"beef";
        (calls, callDatas) = _singleCall(0, shortData);
        executor.publishGovernanceCallData(callDatas);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.CallDataTooShort.selector, 0)
        );
        _scheduleWindow(calls, notBefore, expiresAfter);

        // Leading selector mismatch.
        (calls, callDatas) = _singleCall(0, callData);
        calls[0].selector = GovernedTargetMock.setShouldRevert.selector;
        executor.publishGovernanceCallData(callDatas);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.CallSelectorMismatch.selector, 0)
        );
        _scheduleWindow(calls, notBefore, expiresAfter);

        // Empty calldata with a nonzero selector.
        (calls, callDatas) = _singleCall(0, "");
        calls[0].selector = GovernedTargetMock.setValue.selector;
        executor.publishGovernanceCallData(callDatas);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.CallSelectorMismatch.selector, 0)
        );
        _scheduleWindow(calls, notBefore, expiresAfter);
    }

    function testImmediateTighteningRequiresClassifier() public {
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (5));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        executor.publishGovernanceCallData(callDatas);
        uint64 notBefore = uint64(block.timestamp);
        uint64 expiresAfter = notBefore + 1 days;

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.NotClassifiedTightening.selector,
                address(target),
                GovernedTargetMock.setValue.selector
            )
        );
        _scheduleClass(
            StreamGovernanceActionClasses.IMMEDIATE_TIGHTENING, calls, notBefore, expiresAfter
        );

        // Register the tightening classifier entry and execute with no delay.
        executor.setTighteningCall(address(target), GovernedTargetMock.setValue.selector, true);
        executor.isTighteningCall(address(target), GovernedTargetMock.setValue.selector)
            .assertTrue("classifier entry");
        bytes32 actionId = _scheduleClass(
            StreamGovernanceActionClasses.IMMEDIATE_TIGHTENING, calls, notBefore, expiresAfter
        );
        executor.executeGovernanceBatch(actionId, calls, callDatas);
        target.value().assertEq(5, "immediate tightening executed with zero delay");
    }

    // -------------------------------------------------------------- execution

    function testExecuteLifecycle() public {
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (42));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );

        // Negative gate: early execution reverts.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                actionId,
                notBefore
            )
        );
        executor.executeGovernanceBatch(actionId, calls, callDatas);

        vm.warp(notBefore);
        vm.expectEmit(true, true, true, true);
        emit GovernanceActionExecuted(
            1,
            actionId,
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            address(target),
            0,
            GovernedTargetMock.setValue.selector,
            keccak256(abi.encode(executor.STREAM_GOVERNANCE_CALLS_V1(), calls)),
            SCOPE,
            OLD_VALUE,
            NEW_VALUE,
            address(this),
            MANIFEST
        );
        executor.executeGovernanceBatch(actionId, calls, callDatas);

        target.value().assertEq(42, "target mutated");
        target.lastSender().assertEq(address(executor), "call arrived from executor");
        GovernanceAction memory action = executor.governanceAction(actionId);
        uint256(uint8(action.status))
            .assertEq(uint256(uint8(GovernanceActionStatus.EXECUTED)), "status executed");
        action.executor.assertEq(address(this), "executor recorded");

        // Executed actions cannot replay.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotScheduled.selector, actionId
            )
        );
        executor.executeGovernanceBatch(actionId, calls, callDatas);
    }

    function testExecuteUnknownActionReverts() public {
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, "");
        calls[0].selector = bytes4(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionUnknown.selector, keccak256("nope")
            )
        );
        executor.executeGovernanceBatch(keccak256("nope"), calls, callDatas);
    }

    function testExecuteVerifiesCallIntegrity() public {
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (42));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );
        vm.warp(notBefore);

        // Tampered call target changes the calls hash.
        GovernanceCall[] memory tamperedCalls = new GovernanceCall[](1);
        tamperedCalls[0] = GovernanceCall({
            target: address(0xBAD),
            value: calls[0].value,
            selector: calls[0].selector,
            callDataHash: calls[0].callDataHash
        });
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.CallsHashMismatch.selector, actionId)
        );
        executor.executeGovernanceBatch(actionId, tamperedCalls, callDatas);

        // Tampered calldata fails the per-call hash recheck.
        bytes[] memory tamperedDatas = new bytes[](1);
        tamperedDatas[0] = abi.encodeCall(GovernedTargetMock.setValue, (43));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.CallDataHashMismatch.selector, 0)
        );
        executor.executeGovernanceBatch(actionId, calls, tamperedDatas);

        // Wrong calldata count.
        bytes[] memory wrongCount = new bytes[](2);
        wrongCount[0] = callData;
        wrongCount[1] = callData;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.CallDataCountMismatch.selector, 1, 2)
        );
        executor.executeGovernanceBatch(actionId, calls, wrongCount);
    }

    function testBatchValueSemantics() public {
        GovernedTargetMock second = new GovernedTargetMock();
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeCall(GovernedTargetMock.setValue, (1));
        callDatas[1] = abi.encodeCall(GovernedTargetMock.setValue, (2));
        calls[0] = GovernanceCall({
            target: address(target),
            value: 1 ether,
            selector: GovernedTargetMock.setValue.selector,
            callDataHash: keccak256(callDatas[0])
        });
        calls[1] = GovernanceCall({
            target: address(second),
            value: 2 ether,
            selector: GovernedTargetMock.setValue.selector,
            callDataHash: keccak256(callDatas[1])
        });
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );
        executor.governanceAction(actionId).value.assertEq(3 ether, "stored value sum");
        vm.warp(notBefore);

        // [GOV-BATCH] rule 2: msg.value must equal the exact batch value sum.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.BatchValueMismatch.selector, 3 ether, 1 ether
            )
        );
        executor.executeGovernanceBatch{ value: 1 ether }(actionId, calls, callDatas);

        executor.executeGovernanceBatch{ value: 3 ether }(actionId, calls, callDatas);
        target.lastPaidValue().assertEq(1 ether, "first call exact wei");
        second.lastPaidValue().assertEq(2 ether, "second call exact wei");
        address(target).balance.assertEq(1 ether, "first target balance");
        address(second).balance.assertEq(2 ether, "second target balance");
        address(executor).balance.assertEq(0, "no value stranded in executor");
    }

    function testBatchRefundSurplusReverts() public {
        GovernedRefundingMock refunder = new GovernedRefundingMock();
        bytes memory callData = abi.encodeCall(GovernedRefundingMock.refund, ());
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall({
            target: address(refunder),
            value: 1 ether,
            selector: GovernedRefundingMock.refund.selector,
            callDataHash: keccak256(callData)
        });
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = callData;
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );
        vm.warp(notBefore);
        // The target force-refunds its value to the executor; the surplus must
        // revert the batch rather than strand in the governance contract.
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.BatchValueSurplus.selector, 1 ether)
        );
        executor.executeGovernanceBatch{ value: 1 ether }(actionId, calls, callDatas);
    }

    function testBatchExecutionIsAtomic() public {
        GovernedTargetMock second = new GovernedTargetMock();
        second.setShouldRevert(true);
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeCall(GovernedTargetMock.setValue, (11));
        callDatas[1] = abi.encodeCall(GovernedTargetMock.setValue, (22));
        calls[0] = GovernanceCall({
            target: address(target),
            value: 0,
            selector: GovernedTargetMock.setValue.selector,
            callDataHash: keccak256(callDatas[0])
        });
        calls[1] = GovernanceCall({
            target: address(second),
            value: 0,
            selector: GovernedTargetMock.setValue.selector,
            callDataHash: keccak256(callDatas[1])
        });
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );
        vm.warp(notBefore);

        // The second call reverts, and the inner revert reason bubbles.
        vm.expectRevert(bytes("target revert"));
        executor.executeGovernanceBatch(actionId, calls, callDatas);

        // Partial application is never observable.
        target.value().assertEq(0, "first call rolled back");
        uint256(uint8(executor.governanceAction(actionId).status))
            .assertEq(uint256(uint8(GovernanceActionStatus.SCHEDULED)), "action still scheduled");

        // The batch stays executable once the failure cause clears.
        second.setShouldRevert(false);
        executor.executeGovernanceBatch(actionId, calls, callDatas);
        target.value().assertEq(11, "first call applied");
        second.value().assertEq(22, "second call applied");
    }

    function testNativeTransferRequiresApprovedReceiver() public {
        address payable receiver = payable(address(0xE0A));
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall({
            target: receiver, value: 1 ether, selector: bytes4(0), callDataHash: keccak256("")
        });
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = "";
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );
        vm.warp(notBefore);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.NativeReceiverNotApproved.selector, receiver
            )
        );
        executor.executeGovernanceBatch{ value: 1 ether }(actionId, calls, callDatas);

        executor.setApprovedNativeReceiver(receiver, true);
        executor.isApprovedNativeReceiver(receiver).assertTrue("receiver approved");
        executor.executeGovernanceBatch{ value: 1 ether }(actionId, calls, callDatas);
        receiver.balance.assertEq(1 ether, "native transfer delivered");
    }

    function testExecuteCodelessTargetWithCalldataReverts() public {
        address codeless = address(0xDEAD01);
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (1));
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall({
            target: codeless,
            value: 0,
            selector: GovernedTargetMock.setValue.selector,
            callDataHash: keccak256(callData)
        });
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = callData;
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );
        vm.warp(notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.TargetHasNoCode.selector, 0, codeless)
        );
        executor.executeGovernanceBatch(actionId, calls, callDatas);
    }

    // ---------------------------------------------------------- cancellation

    function testCancelLifecycle() public {
        bytes32 actionId = _scheduleDefault(abi.encodeCall(GovernedTargetMock.setValue, (1)));

        // Unauthorized cancellation reverts.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActorNotAuthorized.selector, stranger
            )
        );
        vm.prank(stranger);
        executor.cancelGovernanceAction(actionId, keccak256("cancel-reason"));

        GovernanceAction memory before = executor.governanceAction(actionId);
        vm.expectEmit(true, true, true, true);
        emit GovernanceActionCancelled(
            1,
            actionId,
            before.actionClass,
            before.target,
            before.selector,
            before.callHash,
            before.scopeHash,
            address(this),
            keccak256("cancel-reason"),
            ""
        );
        executor.cancelGovernanceAction(actionId, keccak256("cancel-reason"));

        GovernanceAction memory action = executor.governanceAction(actionId);
        uint256(uint8(action.status))
            .assertEq(uint256(uint8(GovernanceActionStatus.CANCELLED)), "status cancelled");
        action.canceller.assertEq(address(this), "canceller recorded");

        // Cancelled actions cannot execute or re-cancel.
        (GovernanceCall[] memory calls, bytes[] memory callDatas) =
            _singleCall(0, abi.encodeCall(GovernedTargetMock.setValue, (1)));
        vm.warp(action.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotScheduled.selector, actionId
            )
        );
        executor.executeGovernanceBatch(actionId, calls, callDatas);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotScheduled.selector, actionId
            )
        );
        executor.cancelGovernanceAction(actionId, keccak256("again"));
    }

    function testProposerAndRegisteredCancellerCanCancel() public {
        executor.registerProposer(proposer, true);
        executor.registerCanceller(canceller, true);
        executor.isCanceller(canceller).assertTrue("canceller registered");

        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (1));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        executor.publishGovernanceCallData(callDatas);
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();

        vm.prank(proposer);
        bytes32 first = _scheduleClass(
            StreamGovernanceActionClasses.DELAYED_LOOSENING, calls, notBefore, expiresAfter
        );
        vm.prank(proposer);
        executor.cancelGovernanceAction(first, keccak256("own action"));
        executor.governanceAction(first).canceller.assertEq(proposer, "proposer cancelled own");

        vm.prank(proposer);
        bytes32 second = _scheduleClass(
            StreamGovernanceActionClasses.DELAYED_LOOSENING, calls, notBefore, expiresAfter
        );
        vm.prank(canceller);
        executor.cancelGovernanceAction(second, keccak256("guardian cancel"));
        executor.governanceAction(second).canceller
            .assertEq(canceller, "registered canceller cancelled");
    }

    // ------------------------------------------------------------------ veto

    function testTerminalFreezeVeto() public {
        roleRegistry.grantRole(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, guardian);
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (99));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        uint64 notBefore = uint64(block.timestamp) + 72 hours;
        uint64 expiresAfter = notBefore + 7 days;
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.TERMINAL_FREEZE, calls, callDatas, notBefore, expiresAfter
        );

        (address resolvedGuardian, uint64 vetoDeadline) = executor.terminalFreezeVetoGuardian(SCOPE);
        resolvedGuardian.assertEq(guardian, "guardian resolved through role registry");
        uint256(vetoDeadline).assertEq(uint256(notBefore), "veto deadline is notBefore");

        // Only the role holder may veto.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.NotTerminalFreezeVetoGuardian.selector, stranger
            )
        );
        vm.prank(stranger);
        executor.vetoTerminalFreeze(actionId, keccak256("veto"));

        // Veto lands inside the window.
        vm.expectEmit(true, true, true, true);
        emit GovernanceActionVetoed(
            1,
            actionId,
            StreamGovernanceActionClasses.TERMINAL_FREEZE,
            guardian,
            SCOPE,
            keccak256("veto")
        );
        vm.prank(guardian);
        executor.vetoTerminalFreeze(actionId, keccak256("veto"));

        GovernanceAction memory action = executor.governanceAction(actionId);
        uint256(uint8(action.status))
            .assertEq(uint256(uint8(GovernanceActionStatus.VETOED)), "status vetoed");
        action.vetoer.assertEq(guardian, "vetoer recorded");

        // Vetoed terminal freezes never execute.
        vm.warp(notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotScheduled.selector, actionId
            )
        );
        executor.executeGovernanceBatch(actionId, calls, callDatas);

        (, uint64 clearedDeadline) = executor.terminalFreezeVetoGuardian(SCOPE);
        uint256(clearedDeadline).assertEq(0, "veto deadline cleared after veto");
    }

    function testVetoAfterDeadlineReverts() public {
        roleRegistry.grantRole(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, guardian);
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (99));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        uint64 notBefore = uint64(block.timestamp) + 72 hours;
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.TERMINAL_FREEZE,
            calls,
            callDatas,
            notBefore,
            notBefore + 7 days
        );
        vm.warp(notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.VetoDeadlinePassed.selector, actionId, notBefore
            )
        );
        vm.prank(guardian);
        executor.vetoTerminalFreeze(actionId, keccak256("late"));
    }

    function testVetoNonTerminalFreezeReverts() public {
        roleRegistry.grantRole(StreamRoles.ROLE_TERMINAL_FREEZE_VETO, guardian);
        bytes32 actionId = _scheduleDefault(abi.encodeCall(GovernedTargetMock.setValue, (1)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.NotTerminalFreezeAction.selector, actionId
            )
        );
        vm.prank(guardian);
        executor.vetoTerminalFreeze(actionId, keccak256("wrong class"));
    }

    // ---------------------------------------------------------------- expiry

    function testExpiryLifecycle() public {
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (1));
        (GovernanceCall[] memory calls, bytes[] memory callDatas) = _singleCall(0, callData);
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );

        // Materializing before expiry reverts.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExpired.selector,
                actionId,
                expiresAfter
            )
        );
        executor.materializeExpiredAction(actionId);

        vm.warp(uint256(expiresAfter) + 1);

        // Virtual expiry through the read before materialization.
        uint256(uint8(executor.governanceAction(actionId).status))
            .assertEq(uint256(uint8(GovernanceActionStatus.EXPIRED)), "virtual expired status");

        // Expired actions cannot execute.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionExpiredWindow.selector,
                actionId,
                expiresAfter
            )
        );
        executor.executeGovernanceBatch(actionId, calls, callDatas);

        // Anyone may materialize the expiry.
        vm.expectEmit(true, true, true, true);
        emit GovernanceActionExpired(
            1, actionId, StreamGovernanceActionClasses.DELAYED_LOOSENING, stranger
        );
        vm.prank(stranger);
        executor.materializeExpiredAction(actionId);
        uint256(uint8(executor.governanceAction(actionId).status))
            .assertEq(uint256(uint8(GovernanceActionStatus.EXPIRED)), "materialized expired status");

        // Terminal state: no re-materialize, no cancel.
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotScheduled.selector, actionId
            )
        );
        executor.materializeExpiredAction(actionId);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotScheduled.selector, actionId
            )
        );
        executor.cancelGovernanceAction(actionId, keccak256("too late"));
    }

    function testExpiredButUnmaterializedActionCanBeCancelled() public {
        bytes32 actionId = _scheduleDefault(abi.encodeCall(GovernedTargetMock.setValue, (1)));
        GovernanceAction memory action = executor.governanceAction(actionId);
        vm.warp(uint256(action.expiresAfter) + 1);
        executor.cancelGovernanceAction(actionId, keccak256("cancel expired"));
        uint256(uint8(executor.governanceAction(actionId).status))
            .assertEq(uint256(uint8(GovernanceActionStatus.CANCELLED)), "expired action cancelled");
    }

    // ------------------------------------------------- single-call wrappers

    function testSingleCallWrapperProducesByteIdenticalActionId() public {
        bytes memory callData = abi.encodeCall(GovernedTargetMock.setValue, (77));
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        uint256 nonceBefore = executor.governanceNonce();

        GovernanceActionRequest memory request;
        request.actionClass = StreamGovernanceActionClasses.DELAYED_LOOSENING;
        request.target = address(target);
        request.value = 0;
        request.selector = GovernedTargetMock.setValue.selector;
        request.callData = callData;
        request.scopeHash = SCOPE;
        request.oldValueHash = OLD_VALUE;
        request.newValueHash = NEW_VALUE;
        request.notBefore = notBefore;
        request.expiresAfter = expiresAfter;
        request.reasonHash = REASON;
        request.reasonURI = REASON_URI;
        request.manifestHash = MANIFEST;

        bytes32 actionId = executor.scheduleGovernanceAction(request);

        // Byte-identical to the equivalent batch of one ([GOV-ACTION-ID]).
        (GovernanceCall[] memory calls,) = _singleCall(0, callData);
        actionId.assertEq(
            _expectedActionId(
                StreamGovernanceActionClasses.DELAYED_LOOSENING,
                calls,
                nonceBefore,
                notBefore,
                expiresAfter
            ),
            "wrapper action id equals batch-of-one preimage"
        );

        // The wrapper also published the preimage blob.
        bytes[] memory readBack = executor.scheduledCallData(actionId);
        keccak256(readBack[0]).assertEq(keccak256(callData), "wrapper published preimage");

        // Single-call execution wrapper completes the lifecycle.
        vm.warp(notBefore);
        executor.executeGovernanceAction(actionId, callData);
        target.value().assertEq(77, "wrapper executed");
    }

    function testSingleCallExecuteWrapperRejectsMultiCallBatch() public {
        GovernedTargetMock second = new GovernedTargetMock();
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeCall(GovernedTargetMock.setValue, (1));
        callDatas[1] = abi.encodeCall(GovernedTargetMock.setValue, (2));
        calls[0] = GovernanceCall({
            target: address(target),
            value: 0,
            selector: GovernedTargetMock.setValue.selector,
            callDataHash: keccak256(callDatas[0])
        });
        calls[1] = GovernanceCall({
            target: address(second),
            value: 0,
            selector: GovernedTargetMock.setValue.selector,
            callDataHash: keccak256(callDatas[1])
        });
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );
        vm.warp(notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.CallsHashMismatch.selector, actionId)
        );
        executor.executeGovernanceAction(actionId, callDatas[0]);
    }

    // ------------------------------------------------------- governed config

    function testGovernedSelfCallManagesExecutorConfig() public {
        // Executor configuration is itself governable through a staged batch.
        bytes memory callData =
            abi.encodeCall(StreamGovernanceExecutor.registerProposer, (proposer, true));
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall({
            target: address(executor),
            value: 0,
            selector: StreamGovernanceExecutor.registerProposer.selector,
            callDataHash: keccak256(callData)
        });
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = callData;
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );
        vm.warp(notBefore);
        executor.executeGovernanceBatch(actionId, calls, callDatas);
        executor.isProposer(proposer).assertTrue("governed self-call registered proposer");
    }

    function testConfigFunctionsRejectStrangers() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActorNotAuthorized.selector, stranger
            )
        );
        vm.prank(stranger);
        executor.registerProposer(stranger, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActorNotAuthorized.selector, stranger
            )
        );
        vm.prank(stranger);
        executor.registerCanceller(stranger, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActorNotAuthorized.selector, stranger
            )
        );
        vm.prank(stranger);
        executor.setTighteningCall(address(target), GovernedTargetMock.setValue.selector, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActorNotAuthorized.selector, stranger
            )
        );
        vm.prank(stranger);
        executor.setApprovedNativeReceiver(stranger, true);
    }

    function testCurrentActionContextDuringExecution() public {
        GovernedContextProbeMock probe = new GovernedContextProbeMock(executor);
        bytes memory callData = abi.encodeCall(GovernedContextProbeMock.probe, ());
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall({
            target: address(probe),
            value: 0,
            selector: GovernedContextProbeMock.probe.selector,
            callDataHash: keccak256(callData)
        });
        bytes[] memory callDatas = new bytes[](1);
        callDatas[0] = callData;
        (uint64 notBefore, uint64 expiresAfter) = _defaultWindow();
        bytes32 actionId = _schedule(
            StreamGovernanceActionClasses.DELAYED_LOOSENING,
            calls,
            callDatas,
            notBefore,
            expiresAfter
        );
        vm.warp(notBefore);
        executor.executeGovernanceBatch(actionId, calls, callDatas);

        probe.sawExecuting().assertTrue("executing context visible to target");
        probe.sawActionId().assertEq(actionId, "action id visible to target");
        uint256(probe.sawActionClass())
            .assertEq(
                uint256(StreamGovernanceActionClasses.DELAYED_LOOSENING),
                "action class visible to target"
            );

        (bool executing, bytes32 idAfter, uint8 classAfter) = executor.currentAction();
        executing.assertFalse("context cleared after execution");
        idAfter.assertEq(bytes32(0), "action id cleared");
        uint256(classAfter).assertEq(0, "action class cleared");
    }
}
