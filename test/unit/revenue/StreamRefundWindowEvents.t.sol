// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RefundWindowTestBase.sol";

contract StreamRefundWindowEventsTest is RefundWindowTestBase {
    function testExactPurchaseAndOfficialTranscriptRetainsOriginalProofAcrossCurrentPolicyGrace()
        public
    {
        vm.recordLogs();
        bytes32 id = _purchase(1, 1100);
        Vm.Log[] memory purchaseLogs = vm.getRecordedLogs();
        IStreamNativeRefundWindowSale.RefundPurchaseRecord memory p =
            refundSale.refundPurchaseRecord(id);
        _exact(
            purchaseLogs,
            address(refundSale),
            _topics(
                keccak256(
                    "RefundWindowPurchase(uint16,bytes32,bytes32,address,uint256,uint256,uint64)"
                ),
                refundId,
                id,
                bytes32(uint256(uint160(payer)))
            ),
            abi.encode(uint16(1), uint256(1), uint256(1000), uint64(4600))
        );
        _exact(
            purchaseLogs,
            address(refundSale),
            _topic2(
                keccak256(
                    "RefundPurchaseEnvelopeBound(uint16,bytes32,bytes32,bytes32,uint256,uint64,uint64,uint64,uint64,uint64)"
                ),
                id
            ),
            abi.encode(
                uint16(1),
                p.purchaseRecordHash,
                p.authorizationDigest,
                uint256(100),
                uint64(4600),
                uint64(91000),
                uint64(91000),
                uint64(101000),
                uint64(0)
            )
        );
        bytes32 current = keccak256("new phase policy within old grace");
        refundManager.setPolicy(current, keccak256("refund phase policy"), 100_000);
        vm.warp(5000); // Original commercial proof expired; stored purchase proof remains authoritative.
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory expected =
            _expected(id, p);
        bytes32 commitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_DEFERRED_NATIVE_SETTLEMENT_CANDIDATE_V1"),
                block.chainid,
                address(recorder),
                expected
            )
        );
        vm.recordLogs();
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory r =
            refundSale.finalizeRefundWindow(id);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            r.executionId == expected.execution.executionBinding.executionId
                && r.operationRoot == expected.execution.operationIdentityCommitment
                && r.operationId == expected.execution.operationId,
            "independently reconstructed deferred execution and manager root"
        );
        StreamPrimarySettlementTypes.PrimarySettlementResult memory official =
            recorder.settlementResult(r.settlementKey);
        require(
            official.candidateCommitment == commitment && official.executionId == r.executionId,
            "full deferred candidate is official binding"
        );
        _exact(
            logs,
            address(recorder),
            _topics(
                keccak256(
                    "PrimaryRevenueSettled(bytes32,bytes32,bytes32,uint16,address,address,address,uint256,bytes32,bool,uint8)"
                ),
                r.settlementKey,
                CLASS,
                profile
            ),
            abi.encode(
                uint16(1),
                wallet,
                address(0),
                payer,
                uint256(1000),
                keccak256(abi.encode(expected.execution.sale)),
                false,
                uint8(1)
            )
        );
        _exact(
            logs,
            address(recorder),
            _topics(
                keccak256(
                    "PrimaryRevenueSettlementContext(bytes32,bytes32,bytes32,uint16,address,bytes32,uint8,uint256,uint256,bytes32,bytes32,uint256,address,address,bytes32)"
                ),
                r.settlementKey,
                CLASS,
                profile
            ),
            abi.encode(
                uint16(1),
                address(refundSale),
                refundId,
                uint8(1),
                uint256(1),
                uint256(0),
                r.operationRoot,
                r.operationId,
                uint256(1),
                address(0),
                payer,
                bytes32(0)
            )
        );
        _exact(
            logs,
            address(recorder),
            _topics(
                keccak256(
                    "PrimaryRevenueSettlementPolicy(bytes32,bytes32,bytes32,uint16,bytes32,bytes32,bytes32,bytes32)"
                ),
                r.settlementKey,
                CLASS,
                profile
            ),
            abi.encode(
                uint16(1),
                p.authorization.expectedPrimaryPolicyHash,
                expected.execution.sale.expectedPrimaryPolicyHash,
                expected.execution.rights.assignmentHash,
                bytes32(0)
            )
        );
        _exact(
            logs,
            address(recorder),
            _topics(
                keccak256(
                    "PrimaryRevenueExecutionBound(bytes32,address,bytes32,uint16,address,address,bytes32,bytes32,bytes32)"
                ),
                r.settlementKey,
                bytes32(uint256(uint160(address(refundSale)))),
                r.executionId
            ),
            abi.encode(
                uint16(1),
                address(this),
                address(0),
                commitment,
                current,
                keccak256("refund phase policy")
            )
        );
        _exact(
            logs,
            address(refundSale),
            _topic2(
                keccak256("RefundPurchaseWindowObserved(uint16,bytes32,uint64,uint64,uint64)"), id
            ),
            abi.encode(uint16(1), uint64(0), uint64(4600), uint64(91000))
        );
        bytes32[] memory finalized = new bytes32[](3);
        finalized[0] = keccak256("RefundWindowFinalized(uint16,bytes32,bytes32,uint256,uint256)");
        finalized[1] = refundId;
        finalized[2] = id;
        _exact(logs, address(refundSale), finalized, abi.encode(uint16(1), uint256(1), uint256(1)));
    }

    function _expected(bytes32 id, IStreamNativeRefundWindowSale.RefundPurchaseRecord memory p)
        private
        view
        returns (StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory d)
    {
        IStreamMintManager.MintBatch memory b;
        b.collectionId = 1;
        b.phaseId = PHASE;
        b.payer = payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = payer;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = payer;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = p.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = p.authorization.mintCommitment;
        b.expectedPolicyHash = keccak256("refund phase policy");
        b.authorizationId = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), p.authorizationDigest)
        );
        b.contextHash = p.authorizationDigest;
        d.execution.operationIdentityCommitment =
            keccak256(abi.encode(b, address(refundSale), uint256(0)));
        d.execution.operationId =
            keccak256(abi.encode(d.execution.operationIdentityCommitment, uint256(0)));
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(resolver, 1);
        d.execution.saleAdapter = address(refundSale);
        d.execution.executor = address(this);
        d.execution.sale = StreamPrimarySettlementTypes.PrimarySale(
            refundId,
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
        d.execution.rights = StreamPrimarySettlementTypes.PrimaryRights(
            rights.profileId,
            rights.wallet,
            rights.templateId,
            rights.assignmentHash,
            rights.entriesHash
        );
        d.execution.lifecycleBinding = refundSale.nativeSaleLifecycleBinding(refundId);
        d.execution.executionBinding =
            StreamPrimarySettlementTypes.SaleExecutionBinding(0, 1, 1, p.authorizationDigest);
        d.execution.orchestrationOrder = 1;
        d.execution.mintManager = address(refundManager);
        d.execution.currentPolicyHash = refundManager.currentPolicy();
        d.execution.boundPolicyHash = b.expectedPolicyHash;
        d.execution.saleExecutionHash = p.purchaseRecordHash;
        d.purchaseId = id;
        d.purchaseRecordHash = p.purchaseRecordHash;
        d.originalPrimaryPolicyHash = p.authorization.expectedPrimaryPolicyHash;
        d.nominalRefundDeadline = 4600;
        d.nominalFinalizeBy = 91000;
        d.maximumNominalFinalizeBy = 91000;
        d.absoluteEscapeDeadline = 101000;
        d.effectiveRefundDeadline = 4600;
        d.effectiveFinalizeBy = 91000;
        d.execution.executionBinding.executionId = keccak256(
            abi.encode(
                keccak256("6529STREAM_DEFERRED_NATIVE_SALE_EXECUTION_V1"),
                block.chainid,
                address(refundSale),
                id,
                p.purchaseRecordHash,
                address(this),
                p.authorizationDigest,
                d.execution.currentPolicyHash,
                b.expectedPolicyHash,
                d.execution.operationIdentityCommitment
            )
        );
    }

    function _topics(bytes32 eventId, bytes32 a, bytes32 b, bytes32 c)
        private
        pure
        returns (bytes32[] memory t)
    {
        t = new bytes32[](4);
        t[0] = eventId;
        t[1] = a;
        t[2] = b;
        t[3] = c;
    }

    function _topic2(bytes32 eventId, bytes32 a) private pure returns (bytes32[] memory t) {
        t = new bytes32[](2);
        t[0] = eventId;
        t[1] = a;
    }

    function _exact(
        Vm.Log[] memory logs,
        address emitter,
        bytes32[] memory topics,
        bytes memory data
    ) private pure {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == emitter && logs[i].topics[0] == topics[0]) {
                ++count;
                require(
                    keccak256(abi.encode(logs[i].topics)) == keccak256(abi.encode(topics))
                        && keccak256(logs[i].data) == keccak256(data),
                    "exact golden event topics and full payload"
                );
            }
        }
        require(count == 1, "exactly one golden event");
    }
}
