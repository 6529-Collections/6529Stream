// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/GovernedParameterTestMocks.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol";

/// @dev Deliberate upstream fault injector, not a model claiming ARRNG oracle correctness.
contract ARRNGControllerFaults {
    address public owner = address(0xA11CE);
    address public oracleAddress = address(0xA22CE);
    uint64 public arrngRequestId;
    uint128 public minimumNativeToken = 100;
    uint8 public mode;
    address public refundAddress;

    function setMode(uint8 next) external {
        mode = next;
    }

    function setOwner(address next) external {
        owner = next;
    }

    function setOracle(address next) external {
        oracleAddress = next;
    }

    function setMinimum(uint128 next) external {
        minimumNativeToken = next;
    }

    function setCounter(uint64 next) external {
        arrngRequestId = next;
    }

    function requestRandomWords(uint256 count, address refund) external payable returns (uint256) {
        require(
            count == 1 && refund == msg.sender && msg.value >= minimumNativeToken,
            "request boundary"
        );
        if (mode == 1) revert("upstream request failed");
        arrngRequestId += mode == 2 ? 2 : 1;
        refundAddress = refund;
        if (mode == 3) return 0;
        if (mode == 4) {
            uint256[] memory words = new uint256[](1);
            IStreamEntropyProviderARRNG(msg.sender).receiveRandomness(arrngRequestId, words);
        }
        if (mode == 5) {
            (bool ok, bytes memory result) = msg.sender.call{ value: 1 }("");
            if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        }
        if (mode == 6) owner = address(0xBAD);
        return arrngRequestId;
    }

    function deliver(
        StreamEntropyProviderARRNG adapter,
        uint256 id,
        uint256[] memory words,
        uint256 refund,
        uint256 gasLimit
    ) external returns (bool, bytes memory) {
        return address(adapter).call{ value: refund, gas: gasLimit }(
            abi.encodeCall(adapter.receiveRandomness, (id, words))
        );
    }

    function sendRefund(StreamEntropyProviderARRNG adapter, uint256 amount) external {
        (bool ok,) = address(adapter).call{ value: amount }("");
        require(ok, "refund");
    }
}

contract ARRNGDeliveryTarget {
    uint8 public mode;
    bytes32 public deliveredKey;
    bytes32 public deliveredRaw;
    uint256 public deliveries;

    function setMode(uint8 next) external {
        mode = next;
    }

    function request(StreamEntropyProviderARRNG adapter, bytes32 key)
        external
        payable
        returns (uint256)
    {
        return adapter.requestEntropy{ value: msg.value }(key, abi.encode("ARRNG fixture context"));
    }

    function fulfillEntropy(bytes32 key, bytes32 raw) external returns (uint8) {
        if (mode == 10) revert("delivery failed");
        if (mode == 11) assembly ("memory-safe") { for { } 1 { } { } }
        if (mode == 12) {
            assembly ("memory-safe") {
                mstore(0, 256)
                return(0, 32)
            }
        }
        if (mode == 13) {
            assembly ("memory-safe") {
                mstore(0, 0)
                mstore(32, 0)
                return(0, 64)
            }
        }
        if (mode == 14) require(gasleft() > 600_000, "larger delivery envelope");
        deliveredKey = key;
        deliveredRaw = raw;
        ++deliveries;
        return mode == 14 ? 0 : mode;
    }
}

contract ARRNGForceEther {
    constructor(address payable destination) payable {
        selfdestruct(destination);
    }
}

contract ARRNGRejectingTreasury {
    bool public rejecting = true;

    function acceptPayments() external {
        rejecting = false;
    }

    receive() external payable {
        require(!rejecting, "treasury unavailable");
    }
}

/// @notice Adapter domain tests; real current Core/Executor composition is a separate suite.
contract StreamEntropyProviderARRNGTest is CharacterizationTestBase, OfficialSafeFixture {
    ARRNGControllerFaults private upstream;
    ARRNGDeliveryTarget private target;
    MockGovernedParameterAuthority private authority;
    StreamEntropyProviderARRNG private adapter;
    OfficialSafe private treasury;
    uint256[] private keys;
    bytes32 private constant KEY = keccak256("ARRNG fixture key");
    bytes32 private constant MANIFEST = keccak256("ARRNG fixture manifest");
    uint256 private constant FEE = 100;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        treasury =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 141);
        upstream = new ARRNGControllerFaults();
        target = new ARRNGDeliveryTarget();
        authority = new MockGovernedParameterAuthority(true);
        adapter = _deploy(address(treasury));
        vm.deal(address(this), 10 ether);
        vm.deal(address(upstream), 1 ether);
    }

    function _deploy(address custody) private returns (StreamEntropyProviderARRNG) {
        return new StreamEntropyProviderARRNG(
            StreamEntropyProviderARRNG.Config(
                address(target),
                address(authority),
                address(upstream),
                address(upstream).codehash,
                upstream.owner(),
                upstream.oracleAddress(),
                custody,
                FEE,
                500_000
            ),
            MANIFEST,
            "urn:stream:fixture:arrng",
            MANIFEST
        );
    }

    function testFuzzTypedFeeEqualsEveryContextAndSafeCanCallGetter(bytes calldata context) public {
        require(
            adapter.supportsInterface(type(IStreamEntropyProviderFeeQuote).interfaceId)
                && !adapter.supportsInterface(0xffffffff)
                && adapter.contextIndependentRequestFee() == FEE
                && adapter.quoteRequest(context) == FEE
                && adapter.quoteRequest(abi.encode(KEY, uint256(1), address(target))) == FEE,
            "optional capability matches actual per-request quote"
        );
        require(
            executeSafe(
                treasury,
                keys,
                address(adapter),
                0,
                abi.encodeCall(adapter.contextIndependentRequestFee, ()),
                0
            ),
            "threshold Safe executes typed getter"
        );
    }

    function testTypedAndRequestQuoteFailIdenticallyOnOwnerAndMinimumDrift() public {
        upstream.setOwner(address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEntropyProviderARRNG.ARRNGUpstreamDrift.selector)
        );
        adapter.contextIndependentRequestFee();
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEntropyProviderARRNG.ARRNGUpstreamDrift.selector)
        );
        adapter.quoteRequest(abi.encode(KEY));
        upstream.setOwner(address(0xA11CE));
        upstream.setMinimum(101);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEntropyProviderARRNG.ARRNGPaymentBelowMinimum.selector, FEE, uint256(101)
            )
        );
        adapter.contextIndependentRequestFee();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEntropyProviderARRNG.ARRNGPaymentBelowMinimum.selector, FEE, uint256(101)
            )
        );
        adapter.quoteRequest(abi.encode(KEY, uint256(42)));
        upstream.setMinimum(100);
        require(
            adapter.contextIndependentRequestFee() == FEE && adapter.quoteRequest("") == FEE,
            "both recover from minimum drift"
        );
    }

    function testLifecycleEventsReconstructExactRequestRawBudgetAndOutcome() public {
        vm.recordLogs();
        uint256 id = _request(KEY);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 3, "exact request event inventory");
        _assertLog(
            logs[0],
            abi.encode(
                keccak256("ARRNGEntropyRequested(uint16,bytes32,uint256,uint32,uint256)"), KEY, id
            ),
            abi.encode(uint16(1), uint32(1), FEE)
        );
        _assertLog(
            logs[1],
            abi.encode(
                keccak256("ARRNGRequestContext(uint16,uint256,uint256,bytes32,address)"), id
            ),
            abi.encode(
                    uint16(1),
                    uint256(500_000),
                    keccak256(abi.encode("ARRNG fixture context")),
                    address(0xA11CE)
                )
        );
        _assertLog(
            logs[2],
            abi.encode(
                keccak256("ProviderEntropyRequested(uint16,bytes32,uint256,address,uint32)"),
                KEY,
                id,
                address(target)
            ),
            abi.encode(uint16(1), uint32(1))
        );

        bytes32 raw =
            keccak256(abi.encode(keccak256("6529STREAM_ARRNG_RAW_V1"), KEY, id, _words(42)));
        vm.recordLogs();
        (bool ok,) = upstream.deliver(adapter, id, _words(42), 7, 1_000_000);
        require(ok, "callback completed");
        logs = vm.getRecordedLogs();
        require(logs.length == 5, "exact callback event inventory");
        _assertLog(
            logs[0],
            abi.encode(keccak256("ProviderRefundReceived(uint16,uint256)")),
            abi.encode(uint16(1), uint256(7))
        );
        _assertLog(
            logs[1],
            abi.encode(keccak256("ARRNGEntropyReceived(uint16,bytes32,uint256,bytes32)"), KEY, id),
            abi.encode(uint16(1), raw)
        );
        _assertLog(
            logs[2],
            abi.encode(
                keccak256("ProviderEntropyReceived(uint16,bytes32,uint256,bytes32)"), KEY, id
            ),
            abi.encode(uint16(1), raw)
        );
        _assertLog(
            logs[3],
            abi.encode(
                keccak256("ARRNGDeliveryBudgetUsed(uint16,uint256,bool,uint256,uint256)"), id
            ),
            abi.encode(uint16(1), false, uint256(500_000), uint256(500_000))
        );
        _assertLog(
            logs[4],
            abi.encode(
                keccak256(
                    "ProviderCoordinatorFulfillmentAttempted(uint16,bytes32,uint256,bool,bytes)"
                ),
                KEY,
                id
            ),
            abi.encode(uint16(1), true, abi.encode(uint8(0)))
        );
    }

    function testConflictingDuplicateWhileRawCannotReplaceOutputBeforeSafeRetry() public {
        uint256 id = _request(KEY);
        target.setMode(10);
        (bool ok,) = upstream.deliver(adapter, id, _words(42), 0, 1_000_000);
        require(ok, "first raw persisted");
        bytes32 expected =
            keccak256(abi.encode(keccak256("6529STREAM_ARRNG_RAW_V1"), KEY, id, _words(42)));
        vm.recordLogs();
        (ok,) = upstream.deliver(adapter, id, _words(99), 0, 1_000_000);
        require(ok, "duplicate acknowledged without replacement");
        _assertLog(
            _soleAdapterLog(),
            abi.encode(keccak256("ARRNGCallbackIgnored(uint16,uint256)"), id),
            abi.encode(uint16(1))
        );
        (StreamProviderResultStatus status,, bytes32 hash, bool received, bool delivered) =
            adapter.providerResultStatus(id);
        require(
            status == StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED && received && !delivered
                && hash == keccak256(abi.encode(expected)) && target.deliveries() == 0,
            "first raw remains pending"
        );
        target.setMode(0);
        vm.recordLogs();
        require(
            executeSafe(
                treasury,
                keys,
                address(adapter),
                0,
                abi.encodeCall(adapter.retryCoordinatorFulfillment, (id)),
                0
            ),
            "Safe retries original raw"
        );
        require(
            target.deliveredRaw() == expected && target.deliveries() == 1,
            "first word delivered exactly once"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        // The Safe also emits ExecutionSuccess; adapter logs remain first and complete.
        require(logs.length == 3, "two adapter events and Safe receipt");
        _assertLog(
            logs[0],
            abi.encode(
                keccak256("ARRNGDeliveryBudgetUsed(uint16,uint256,bool,uint256,uint256)"), id
            ),
            abi.encode(uint16(1), true, uint256(500_000), uint256(500_000))
        );
        _assertLog(
            logs[1],
            abi.encode(
                keccak256(
                    "ProviderCoordinatorFulfillmentAttempted(uint16,bytes32,uint256,bool,bytes)"
                ),
                KEY,
                id
            ),
            abi.encode(uint16(1), true, abi.encode(uint8(0)))
        );
    }

    function testRejectingTreasuryRollsBackAndSameAuthorizedWithdrawalCanRetry() public {
        ARRNGRejectingTreasury receiver = new ARRNGRejectingTreasury();
        adapter = _deploy(address(receiver));
        upstream.sendRefund(adapter, 18);
        (bytes32 scope, bytes32 old_, bytes32 next_) = adapter.withdrawalTransitionHashes(18);
        bytes32 actionId = keccak256("same withdrawal authorization");
        authority.setCurrentAction(true, actionId, 1, scope, old_, next_);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEntropyProviderARRNG.ARRNGWithdrawalFailed.selector)
        );
        vm.prank(address(authority));
        adapter.withdrawFunds(18);
        require(
            address(adapter).balance == 18 && address(receiver).balance == 0
                && adapter.totalWithdrawn() == 0 && adapter.withdrawalRevision() == 1
                && adapter.totalRefundsReceived() == 18,
            "failed transfer rolls back all money and revision"
        );
        (bytes32 afterScope, bytes32 afterOld, bytes32 afterNext) =
            adapter.withdrawalTransitionHashes(18);
        require(
            scope == afterScope && old_ == afterOld && next_ == afterNext,
            "same exact governed transition remains valid"
        );
        receiver.acceptPayments();
        vm.recordLogs();
        vm.prank(address(authority));
        adapter.withdrawFunds(18);
        _assertWithdrawalEvents(address(receiver), actionId, 18, 2);
        require(
            address(adapter).balance == 0 && address(receiver).balance == 18
                && adapter.totalWithdrawn() == 18 && adapter.withdrawalRevision() == 2,
            "same action was not consumed by failed transfer"
        );
        upstream.sendRefund(adapter, 18);
        (scope, old_, next_) = adapter.withdrawalTransitionHashes(18);
        authority.setCurrentAction(true, actionId, 1, scope, old_, next_);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEntropyProviderARRNG.ARRNGInvalidAction.selector)
        );
        vm.prank(address(authority));
        adapter.withdrawFunds(18);
    }

    function testExactRequestPaymentRawCompressionAndRefundToAdapter() public {
        uint256 before_ = address(upstream).balance;
        uint256 id = _request(KEY);
        require(id == 1 && upstream.refundAddress() == address(adapter), "explicit request binding");
        require(
            address(upstream).balance == before_ + FEE && address(adapter).balance == 0,
            "one exact fee"
        );
        uint256[] memory words = _words(42);
        (bool ok,) = upstream.deliver(adapter, id, words, 7, 1_000_000);
        bytes32 expected =
            keccak256(abi.encode(keccak256("6529STREAM_ARRNG_RAW_V1"), KEY, id, words));
        require(
            ok && target.deliveredKey() == KEY && target.deliveredRaw() == expected,
            "independent raw digest"
        );
        (
            StreamProviderResultStatus status,
            bytes32 key,
            bytes32 hash,
            bool received,
            bool delivered
        ) = adapter.providerResultStatus(id);
        require(
            status == StreamProviderResultStatus.DELIVERED && key == KEY && received && delivered
                && hash == keccak256(abi.encode(expected)),
            "exact delivered status"
        );
        require(
            address(adapter).balance == 7 && adapter.totalRefundsReceived() == 7, "refund accounted"
        );
        upstream.deliver(adapter, id, _words(99), 0, 1_000_000);
        require(
            target.deliveries() == 1 && target.deliveredRaw() == expected, "duplicate cannot redraw"
        );
    }

    function testRequestFailuresAndReentrantSubmissionRollBackEveryBindingAndPayment() public {
        for (uint8 mode = 1; mode <= 6; ++mode) {
            upstream.setMode(mode);
            uint256 payerBefore = address(this).balance;
            uint256 upstreamBefore = address(upstream).balance;
            (bool ok,) =
                address(target).call{ value: FEE }(abi.encodeCall(target.request, (adapter, KEY)));
            require(
                !ok && upstream.arrngRequestId() == 0 && adapter.keyToArrngRequest(KEY) == 0,
                "request association rollback"
            );
            require(
                address(this).balance == payerBefore && address(upstream).balance == upstreamBefore
                    && address(adapter).balance == 0 && upstream.owner() == address(0xA11CE),
                "request money and authority rollback"
            );
        }
        upstream.setMode(0);
        require(_request(KEY) == 1, "identical key can retry after rollback");
    }

    function testExactFeeOverpaymentMinimumDriftAndDuplicateKey() public {
        for (uint256 value = 99; value <= 101; value += 2) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamEntropyProviderARRNG.ARRNGPaymentMismatch.selector, FEE, value
                )
            );
            target.request{ value: value }(adapter, KEY);
        }
        upstream.setMinimum(101);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEntropyProviderARRNG.ARRNGPaymentBelowMinimum.selector, FEE, uint256(101)
            )
        );
        adapter.quoteRequest("");
        upstream.setMinimum(100);
        _request(KEY);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEntropyProviderARRNG.ARRNGInvalidRequest.selector, KEY)
        );
        target.request{ value: FEE }(adapter, KEY);
    }

    function testWrongCallbackSourceUnknownIdAndShapeNeverReportSuccessfulLoss() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEntropyProviderARRNG.ARRNGUnauthorized.selector, address(this)
            )
        );
        adapter.receiveRandomness(1, _words(42));
        (bool ok,) = upstream.deliver(adapter, 1, _words(42), 0, 1_000_000);
        require(!ok, "unknown callback rejected");
        _request(KEY);
        (ok,) = upstream.deliver(adapter, 1, new uint256[](0), 0, 1_000_000);
        require(!ok, "missing word rejected");
        (ok,) = upstream.deliver(adapter, 1, new uint256[](2), 0, 1_000_000);
        require(!ok, "extra word rejected");
        (ok,) = upstream.deliver(adapter, 1, _words(42), 0, 5_000);
        require(!ok, "incoming gas too small cannot acknowledge success");
        (StreamProviderResultStatus status,,, bool received,) = adapter.providerResultStatus(1);
        require(
            status == StreamProviderResultStatus.REQUESTED && !received,
            "no false persisted-result claim"
        );
    }

    function testCoordinatorRevertOOGAndMalformedReturnsRetainIdenticalOutputForSafeRetry() public {
        for (uint8 mode = 10; mode <= 13; ++mode) {
            bytes32 key = keccak256(abi.encode(KEY, mode));
            uint256 id = _request(key);
            target.setMode(mode);
            (bool ok,) = upstream.deliver(adapter, id, _words(mode), 0, 1_000_000);
            require(ok, "upstream callback succeeds after persistence");
            (StreamProviderResultStatus status,, bytes32 hash, bool received, bool delivered) =
                adapter.providerResultStatus(id);
            require(
                status == StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED && received
                    && !delivered,
                "retryable stored result"
            );
            target.setMode(0);
            require(
                executeSafe(
                    treasury,
                    keys,
                    address(adapter),
                    0,
                    abi.encodeCall(adapter.retryCoordinatorFulfillment, (id)),
                    0
                ),
                "real Safe retries stored output"
            );
            bytes32 afterHash;
            (status,, afterHash,, delivered) = adapter.providerResultStatus(id);
            require(
                status == StreamProviderResultStatus.DELIVERED && delivered && afterHash == hash,
                "retry keeps exact raw output"
            );
        }
    }

    function testRevokedOutcomeRetainsRawAndStaleOutcomesAreTerminal() public {
        for (uint8 mode = 1; mode <= 5; ++mode) {
            uint256 id = _request(keccak256(abi.encode(KEY, mode)));
            target.setMode(mode);
            (bool ok,) = upstream.deliver(adapter, id, _words(mode), 0, 1_000_000);
            require(ok, "outcome callback accepted");
            (StreamProviderResultStatus status,,, bool received, bool delivered) =
                adapter.providerResultStatus(id);
            require(received, "every result retained");
            if (mode <= 2) {
                require(
                    status == StreamProviderResultStatus.TERMINAL_STALE && !delivered,
                    "stale terminal"
                );
            } else if (mode == 3) {
                require(
                    status == StreamProviderResultStatus.DELIVERED && delivered,
                    "already finalized accepted"
                );
            } else {
                require(
                    status == StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED && !delivered,
                    "other outcome retryable"
                );
            }
        }
    }

    function testInsufficientDeliveryBudgetPersistsAndRaiseOnlyChangesFutureRequestsAndRetries()
        public
    {
        uint256 id = _request(KEY);
        bytes32 configHash = adapter.streamEntropyProviderConfigHash();
        _raise(1_000_000);
        target.setMode(14);
        (bool ok,) = upstream.deliver(adapter, id, _words(42), 0, 1_700_000);
        require(ok, "old callback persists despite old cap");
        (StreamProviderResultStatus status,,,,) = adapter.providerResultStatus(id);
        require(
            status == StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED,
            "request still uses captured 500k"
        );
        adapter.retryCoordinatorFulfillment(id);
        (status,,,,) = adapter.providerResultStatus(id);
        require(status == StreamProviderResultStatus.DELIVERED, "retry uses live raised cap");
        uint256 next = _request(keccak256("next key"));
        (,,,,, uint256 nextBudget) = adapter.results(next);
        require(
            nextBudget == 1_000_000 && configHash == adapter.streamEntropyProviderConfigHash(),
            "future budget without entropy identity change"
        );
        (ok,) = upstream.deliver(adapter, next, _words(43), 0, 1_700_000);
        (status,,,,) = adapter.providerResultStatus(next);
        require(ok && status == StreamProviderResultStatus.DELIVERED, "new request uses raised cap");
    }

    function testIncomingFrameEnoughForPersistenceButTooSmallForDeliveryRemainsRetryable() public {
        uint256 id = _request(KEY);
        (bool ok,) = upstream.deliver(adapter, id, _words(42), 0, 220_000);
        (StreamProviderResultStatus status,,, bool received,) = adapter.providerResultStatus(id);
        require(
            ok && received && status == StreamProviderResultStatus.RAW_RANDOMNESS_RECEIVED
                && target.deliveries() == 0,
            "persist first, do not underforward"
        );
        adapter.retryCoordinatorFulfillment(id);
        require(target.deliveries() == 1, "retry after unattempted delivery");
    }

    function testOwnerPinRotationPreservesPendingRequestAndEntropyIdentity() public {
        uint256 id = _request(KEY);
        bytes32 hash = adapter.streamEntropyProviderConfigHash();
        upstream.setOwner(address(treasury));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEntropyProviderARRNG.ARRNGUpstreamDrift.selector)
        );
        adapter.quoteRequest("");
        (bool ok,) = upstream.deliver(adapter, id, _words(42), 0, 1_000_000);
        require(!ok, "owner drift is pending, not new randomness");
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            adapter.ownerPinTransitionHashes(address(treasury));
        authority.setCurrentAction(true, keccak256("owner refresh"), 1, scope, old_, next_);
        vm.recordLogs();
        vm.prank(address(authority));
        adapter.updateControllerOwnerPin(address(treasury));
        _assertLog(
            _soleAdapterLog(),
            abi.encode(
                keccak256("ARRNGControllerOwnerPinUpdated(uint16,bytes32,address,address,uint64)"),
                keccak256("owner refresh")
            ),
            abi.encode(uint16(1), address(0xA11CE), address(treasury), uint64(2))
        );
        require(
            adapter.ownerPinRevision() == 2 && adapter.streamEntropyProviderConfigHash() == hash,
            "operational rotation only"
        );
        (ok,) = upstream.deliver(adapter, id, _words(42), 0, 1_000_000);
        require(ok && target.deliveredKey() == KEY, "existing request survives owner refresh");
    }

    function testOracleDriftBlocksNewRandomnessButNotRetryOfAlreadyStoredOutput() public {
        uint256 id = _request(KEY);
        target.setMode(10);
        upstream.deliver(adapter, id, _words(42), 0, 1_000_000);
        upstream.setOracle(address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEntropyProviderARRNG.ARRNGUpstreamDrift.selector)
        );
        adapter.quoteRequest("");
        target.setMode(0);
        adapter.retryCoordinatorFulfillment(id);
        require(target.deliveredKey() == KEY, "stored output retry has no new upstream trust");
    }

    function testPaymentGovernanceAndSafeTreasuryWithdrawalIncludeForcedEther() public {
        bytes32 hash = adapter.streamEntropyProviderConfigHash();
        (bytes32 scope, bytes32 old_, bytes32 next_) = adapter.paymentTransitionHashes(200);
        authority.setCurrentAction(true, keccak256("payment"), 1, scope, old_, next_);
        vm.recordLogs();
        vm.prank(address(authority));
        adapter.updateRequestPayment(200);
        Vm.Log[] memory paymentLogs = _adapterLogs();
        require(paymentLogs.length == 2, "payment and operational context events");
        _assertLog(
            paymentLogs[0],
            abi.encode(keccak256("ARRNGPaymentUpdated(uint16,uint256,uint256)")),
            abi.encode(uint16(1), FEE, uint256(200))
        );
        _assertLog(
            paymentLogs[1],
            abi.encode(
                keccak256("ARRNGPaymentUpdateContext(uint16,bytes32,uint64)"), keccak256("payment")
            ),
            abi.encode(uint16(1), uint64(2))
        );
        require(
            adapter.quoteRequest("") == 200 && adapter.streamEntropyProviderConfigHash() == hash,
            "live operational quote"
        );
        upstream.sendRefund(adapter, 7);
        new ARRNGForceEther{ value: 11 }(payable(address(adapter)));
        require(
            address(adapter).balance == 18 && adapter.totalRefundsReceived() == 7,
            "forced Ether distinct from refunds"
        );
        (scope, old_, next_) = adapter.withdrawalTransitionHashes(18);
        authority.setCurrentAction(true, keccak256("withdraw"), 1, scope, old_, next_);
        vm.recordLogs();
        vm.prank(address(authority));
        adapter.withdrawFunds(18);
        _assertWithdrawalEvents(address(treasury), keccak256("withdraw"), 18, 2);
        require(
            address(adapter).balance == 0 && address(treasury).balance == 18
                && adapter.totalWithdrawn() == 18 && adapter.withdrawalRevision() == 2,
            "exact Safe custody"
        );
    }

    function testOperationalWritesRejectWrongActorContextShapeAndReplay() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEntropyProviderARRNG.ARRNGUnauthorized.selector, address(this)
            )
        );
        adapter.updateRequestPayment(200);
        (bytes32 scope, bytes32 old_, bytes32 next_) = adapter.paymentTransitionHashes(200);
        authority.setCurrentAction(true, keccak256("one action"), 0, scope, old_, next_);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEntropyProviderARRNG.ARRNGInvalidAction.selector)
        );
        vm.prank(address(authority));
        adapter.updateRequestPayment(200);
        authority.setCurrentAction(true, keccak256("one action"), 1, scope, old_, next_);
        authority.setResponseMode(MockGovernedParameterAuthority.ResponseMode.Oversized);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEntropyProviderARRNG.ARRNGInvalidAction.selector)
        );
        vm.prank(address(authority));
        adapter.updateRequestPayment(200);
        authority.setResponseMode(MockGovernedParameterAuthority.ResponseMode.Canonical);
        vm.prank(address(authority));
        adapter.updateRequestPayment(200);
        (scope, old_, next_) = adapter.paymentTransitionHashes(300);
        authority.setCurrentAction(true, keccak256("one action"), 1, scope, old_, next_);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEntropyProviderARRNG.ARRNGInvalidAction.selector)
        );
        vm.prank(address(authority));
        adapter.updateRequestPayment(300);
        require(
            adapter.requestPaymentWei() == 200 && adapter.paymentRevision() == 2,
            "no replay mutation"
        );
    }

    function testCounterOverflowAndUnauthorizedRequestsFailBeforeFunding() public {
        upstream.setCounter(type(uint64).max);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamEntropyProviderARRNG.ARRNGInvalidRequest.selector, KEY)
        );
        target.request{ value: FEE }(adapter, KEY);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEntropyProviderARRNG.ARRNGUnauthorized.selector, address(this)
            )
        );
        adapter.requestEntropy{ value: FEE }(KEY, "");
    }

    function testFuzzRawResultCannotChangeDuringSafeRetry(uint256 word) public {
        uint256 id = _request(KEY);
        target.setMode(10);
        (bool ok,) = upstream.deliver(adapter, id, _words(word), 0, 1_000_000);
        require(ok, "stored callback");
        (,, bytes32 before_,,) = adapter.providerResultStatus(id);
        target.setMode(0);
        require(
            executeSafe(
                treasury,
                keys,
                address(adapter),
                0,
                abi.encodeCall(adapter.retryCoordinatorFulfillment, (id)),
                0
            ),
            "threshold Safe retry"
        );
        (,, bytes32 after_,, bool delivered) = adapter.providerResultStatus(id);
        require(before_ == after_ && delivered, "same stored result for every input");
    }

    function _request(bytes32 key) private returns (uint256) {
        return target.request{ value: FEE }(adapter, key);
    }

    function _assertLog(Vm.Log memory entry, bytes memory topics, bytes memory data) private view {
        require(entry.emitter == address(adapter), "adapter event emitter");
        require(
            keccak256(abi.encodePacked(entry.topics)) == keccak256(topics),
            "exact signature and indexed fields"
        );
        require(keccak256(entry.data) == keccak256(data), "exact schema and event data");
    }

    function _soleAdapterLog() private returns (Vm.Log memory result) {
        Vm.Log[] memory logs = _adapterLogs();
        require(logs.length == 1, "one adapter event");
        return logs[0];
    }

    function _adapterLogs() private returns (Vm.Log[] memory logs) {
        logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(adapter)) {
                logs[count] = logs[i];
                ++count;
            }
        }
        assembly ("memory-safe") { mstore(logs, count) }
    }

    function _assertWithdrawalEvents(
        address recipient,
        bytes32 actionId,
        uint256 amount,
        uint64 revision
    ) private {
        Vm.Log[] memory logs = _adapterLogs();
        require(logs.length == 2, "withdrawal and operational context events");
        _assertLog(
            logs[0],
            abi.encode(keccak256("ProviderFundsWithdrawn(uint16,address,uint256)"), recipient),
            abi.encode(uint16(1), amount)
        );
        _assertLog(
            logs[1],
            abi.encode(keccak256("ARRNGWithdrawalContext(uint16,bytes32,uint64)"), actionId),
            abi.encode(uint16(1), revision)
        );
    }

    function _words(uint256 word) private pure returns (uint256[] memory words) {
        words = new uint256[](1);
        words[0] = word;
    }

    function _raise(uint256 next) private {
        bytes32 id = adapter.GGP_CALLBACK_GAS_LIMIT();
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(adapter),
                id
            )
        );
        bytes32 oldState;
        bytes32 newState;
        {
            (uint256 old, uint256 floor, uint8 class_, uint64 revision) =
                adapter.gasParameterInfo(id);
            bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
            oldState = keccak256(abi.encode(domain, scope, old, floor, class_, revision));
            newState = keccak256(abi.encode(domain, scope, next, floor, class_, revision + 1));
        }
        authority.setCurrentAction(true, keccak256("delivery cap"), 1, scope, oldState, newState);
        vm.prank(address(authority));
        adapter.raiseGasParameter(id, next);
    }
}
