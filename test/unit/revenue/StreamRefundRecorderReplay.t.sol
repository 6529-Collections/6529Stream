// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RefundWindowTestBase.sol";

/// @dev Admitted hostile producer deliberately omits normal consumer terminal/replay guards.
///      Its positive call proves recorder admission/funding only, never an authorized real mint.
contract RefundHostileConsumer is IERC165 {
    address public immutable core;
    address public immutable moduleRegistry;
    address public immutable revenueResolver;
    address public immutable primarySaleSettlement;
    address public immutable mintManager;
    bytes32 private _active;
    StreamNativeSettlementTypes.SaleLifecycleBinding private _lifecycle;

    constructor(StreamPrimarySaleSettlement recorder, address manager) {
        core = recorder.core();
        moduleRegistry = recorder.moduleRegistry();
        revenueResolver = address(recorder.revenueResolver());
        primarySaleSettlement = address(recorder);
        mintManager = manager;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamDeferredNativeSaleBinding).interfaceId
            || id == type(IStreamNativeSaleBinding).interfaceId;
    }

    function capture() external {
        _lifecycle = StreamDeferredNativeSettlementAdmission.capture(moduleRegistry, address(this));
    }

    function nativeSaleLifecycleBinding(bytes32)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        return _lifecycle;
    }

    function activeDeferredNativeSettlement(bytes32) external view returns (bytes32) {
        return _active;
    }

    function settle(StreamDeferredNativeSettlementTypes.DeferredNativeCandidate calldata d)
        external
        payable
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory r)
    {
        _active = keccak256(
            abi.encode(
                keccak256("6529STREAM_DEFERRED_NATIVE_SETTLEMENT_CANDIDATE_V1"),
                block.chainid,
                primarySaleSettlement,
                d
            )
        );
        r = IStreamDeferredNativePrimarySaleSettlement(primarySaleSettlement)
        .settleDeferredNativePrimarySaleFromAdapter{ value: msg.value }(
            d
        );
        delete _active;
    }
}

contract StreamRefundRecorderReplayTest is RefundWindowTestBase {
    function testRecorderRejectsSamePurchaseWithChangedExecutorPolicyAndExecutionDespiteHostileProducer()
        public
    {
        RefundHostileConsumer hostile = new RefundHostileConsumer(recorder, address(refundManager));
        _register(
            address(hostile),
            keccak256("NATIVE_REFUND_WINDOW_SALE_ADAPTER"),
            type(IStreamDeferredNativeSaleBinding).interfaceId
        );
        hostile.capture();
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory d = _candidate(hostile);
        vm.deal(address(this), 3000);
        bytes32 firstExecution = d.execution.executionBinding.executionId;
        StreamPrimarySettlementTypes.PrimarySettlementResult memory first =
            hostile.settle{ value: 1000 }(d);
        require(
            first.amount == 1000 && wallet.balance == 1000 && refundManager.nonce() == 0,
            "hostile positive is recorder funding only"
        );
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_DEFERRED_PURCHASE_SETTLEMENT_V1"),
                block.chainid,
                address(recorder),
                address(hostile),
                d.purchaseId
            )
        );
        require(
            recorder.deferredPurchaseKey(address(hostile), d.purchaseId) == key
                && recorder.deferredPurchaseConsumed(key),
            "independent asset/executor/policy-free purchase key"
        );
        d.execution.executor = address(0xABCD);
        d.execution.currentPolicyHash = keccak256("later current mint policy");
        d.execution.operationIdentityCommitment = keccak256("later root");
        d.execution.operationId = keccak256("later operation");
        d.execution.executionBinding.executionId = _executionId(d);
        bytes32 secondKey =
            recorder.settlementKey(address(hostile), d.execution.executionBinding.executionId);
        require(
            d.execution.executionBinding.executionId != firstExecution
                && !recorder.settlementConsumed(secondKey),
            "ordinary official key alone would be fresh"
        );
        uint256 beforeBalance = address(this).balance;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamPrimarySaleSettlement.SettlementAlreadyConsumed.selector, key
            )
        );
        hostile.settle{ value: 1000 }(d);
        require(
            address(this).balance == beforeBalance && wallet.balance == 1000
                && recorder.totalOfficialSettled(address(0)) == 1000
                && !recorder.settlementConsumed(secondKey)
                && hostile.activeDeferredNativeSettlement(d.purchaseId) == 0,
            "same-purchase failure rolls back new latch/value/key"
        );
        d.purchaseId = keccak256("genuinely distinct purchase");
        d.purchaseRecordHash = keccak256("distinct immutable record");
        d.execution.saleExecutionHash = d.purchaseRecordHash;
        d.execution.executionBinding.executionId = _executionId(d);
        hostile.settle{ value: 1000 }(d);
        require(
            wallet.balance == 2000 && recorder.totalOfficialSettled(address(0)) == 2000,
            "same changed-policy context valid for new purchase"
        );
    }

    function _candidate(RefundHostileConsumer hostile)
        private
        view
        returns (StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory d)
    {
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(resolver, 1);
        d.execution.saleAdapter = address(hostile);
        d.execution.executor = address(this);
        d.execution.sale = StreamPrimarySettlementTypes.PrimarySale(
            keccak256("hostile sale"),
            CLASS,
            1,
            1,
            0,
            1,
            payer,
            address(0),
            payer,
            1000,
            StreamSaleTemplate.policyHash(resolver, 1, rights)
        );
        d.execution.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            0, 1, 1, keccak256("authenticated purchase digest")
        );
        d.execution.lifecycleBinding = hostile.nativeSaleLifecycleBinding(0);
        d.execution.rights = StreamPrimarySettlementTypes.PrimaryRights(
            rights.profileId,
            rights.wallet,
            rights.templateId,
            rights.assignmentHash,
            rights.entriesHash
        );
        d.execution.orchestrationOrder = 1;
        d.execution.mintManager = address(refundManager);
        d.execution.currentPolicyHash = refundManager.currentPolicy();
        d.execution.boundPolicyHash = refundManager.currentPolicy();
        d.execution.operationIdentityCommitment = keccak256("original root");
        d.execution.operationId = keccak256("original operation");
        d.purchaseId = keccak256("hostile purchase");
        d.purchaseRecordHash = keccak256("immutable purchase record");
        d.execution.saleExecutionHash = d.purchaseRecordHash;
        d.originalPrimaryPolicyHash = d.execution.sale.expectedPrimaryPolicyHash;
        d.nominalRefundDeadline = 998;
        d.nominalFinalizeBy = 1100;
        d.maximumNominalFinalizeBy = 1100;
        d.absoluteEscapeDeadline = 1200;
        d.effectiveRefundDeadline = 998;
        d.effectiveFinalizeBy = 1100;
        d.execution.executionBinding.executionId = _executionId(d);
    }

    function _executionId(StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory d)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_DEFERRED_NATIVE_SALE_EXECUTION_V1"),
                block.chainid,
                d.execution.saleAdapter,
                d.purchaseId,
                d.purchaseRecordHash,
                d.execution.executor,
                d.execution.executionBinding.saleAuthorizationDigest,
                d.execution.currentPolicyHash,
                d.execution.boundPolicyHash,
                d.execution.operationIdentityCommitment
            )
        );
    }
}
