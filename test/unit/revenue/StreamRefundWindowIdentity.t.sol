// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/RefundWindowTestBase.sol";

contract StreamRefundWindowIdentityTest is RefundWindowTestBase {
    function testPermanentRefundKindSevenAndCompleteConfigWindowAndSaleGoldenPreimages() public {
        uint256 nonce = refundSale.nextSaleNonce();
        IStreamNativeRefundWindowSale.RefundSaleConfig memory c = _refundConfig();
        c.price = 1234;
        c.maxSaleQuantity = 37;
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(1, 0, keccak256("PRIMARY_SALE"));
        bytes32 baseline = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                keccak256("PRIMARY_SALE"),
                uint256(1),
                uint256(0),
                bytes32(0),
                profile,
                wallet,
                a.assignmentHash
            )
        );
        bytes32 expectedId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(refundSale),
                uint8(7),
                uint256(1),
                PHASE,
                nonce
            )
        );
        bytes32 expectedConfig = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_REFUND_SALE_CONFIG_V1"),
                expectedId,
                c.collectionId,
                c.phaseId,
                c.price,
                c.maxSaleQuantity,
                c.startsAt,
                c.endsAt,
                c.refundWindowSeconds,
                c.finalizationWindowSeconds,
                c.primaryPolicyMode,
                c.mintPolicyHash,
                baseline
            )
        );
        bytes32 expectedWindow = keccak256(
            abi.encode(
                keccak256("6529STREAM_REFUND_WINDOW_POLICY_V1"),
                uint64(3600),
                uint64(86400),
                keccak256("OBSERVED_GLOBAL_OR_LOCAL_PAUSE_UNION"),
                keccak256("ABSOLUTE_ESCAPE_PAUSED_EQUALITY_UNPAUSED_FINALIZE_EQUALITY")
            )
        );
        uint256 profiles = factory.profileCount();
        vm.recordLogs();
        bytes32 id = refundSale.registerRefundSale(c);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        IStreamNativeRefundWindowSale.RefundSaleRecord memory s = refundSale.refundSaleRecord(id);
        require(
            id == expectedId && s.configHash == expectedConfig
                && s.windowPolicyHash == expectedWindow && s.expectedPrimaryPolicyHash == baseline
                && s.saleNonce == nonce && refundSale.nextSaleNonce() == nonce + 1,
            "independent complete identity commitment"
        );
        require(
            id
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SALE_V1"),
                        block.chainid,
                        address(refundSale),
                        uint8(2),
                        uint256(1),
                        PHASE,
                        nonce
                    )
                ),
            "English kind2 cannot label refund kind7"
        );
        require(
            factory.profileCount() == profiles && refundManager.nonce() == 0
                && recorder.totalOfficialSettled(address(0)) == 0,
            "baseline is read-only evidence"
        );
        uint256 count;
        bytes32 topic = keccak256(
            "SaleConfigured(uint16,bytes32,uint256,bytes32,uint8,address,bytes32,bytes32,uint8)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(refundSale) || logs[i].topics.length == 0
                    || logs[i].topics[0] != topic
            ) continue;
            ++count;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == id
                    && logs[i].topics[2] == bytes32(uint256(1)) && logs[i].topics[3] == PHASE
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1), uint8(7), address(0), expectedConfig, baseline, uint8(1)
                            )
                        ),
                "exact canonical configuration event"
            );
        }
        require(count == 1, "one canonical configuration event");
        c.price = 0;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeRefundWindowSale.InvalidRefundSale.selector)
        );
        refundSale.registerRefundSale(c);
        require(
            refundSale.nextSaleNonce() == nonce + 1
                && refundSale.refundSaleRecord(id).configHash == expectedConfig,
            "failed config cannot skip or erase identity"
        );
    }

    function testPurchaseCounterIsExactPerSaleBuyerAndRollsBackFailedPurchase() public {
        bytes32 firstSale = refundId;
        require(refundSale.nextPurchaseNonce(firstSale, payer) == 1, "absent starts1");
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _purchaseData(1, payer, payer);
        d.authorization.purchaseNonce = 2;
        _signPurchase(d);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundPurchaseNonceMismatch.selector,
                firstSale,
                payer,
                uint256(1),
                uint256(2)
            )
        );
        refundSale.purchaseRefundWindow{ value: 1100 }(d);
        require(
            refundSale.nextPurchaseNonce(firstSale, payer) == 1
                && refundSale.totalBuyerLiabilities() == 0,
            "gap rejects before persistent deposit"
        );
        d.authorization.purchaseNonce = 1;
        _signPurchase(d);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.SaleRevealFeeBelowRequired.selector,
                uint256(99),
                uint256(100)
            )
        );
        refundSale.purchaseRefundWindow{ value: 1099 }(d);
        require(
            refundSale.nextPurchaseNonce(firstSale, payer) == 1
                && !refundSale.purchaseAuthorizationUsed(artist, d.authorization.nonce),
            "failed same proof preserves both lanes"
        );
        vm.prank(payer);
        bytes32 first = refundSale.purchaseRefundWindow{ value: 1100 }(d);
        require(
            first
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SALE_PURCHASE_V1"),
                            block.chainid,
                            address(refundSale),
                            firstSale,
                            payer,
                            uint256(1)
                        )
                    ) && refundSale.nextPurchaseNonce(firstSale, payer) == 2,
            "independent purchase identity and next counter"
        );
        vm.recordLogs();
        vm.prank(payer);
        refundSale.refundPurchase(first);
        _checkRefundEvent(vm.getRecordedLogs(), firstSale, first);
        require(refundSale.nextPurchaseNonce(firstSale, payer) == 2, "refund never rewinds");
        bytes32 secondSale = refundSale.registerRefundSale(_refundConfig());
        refundId = secondSale;
        bytes32 second = _purchase(2, 1100);
        address otherBuyer = address(0xABBA);
        vm.deal(otherBuyer, 1100);
        d = _purchaseData(3, otherBuyer, otherBuyer);
        vm.prank(otherBuyer);
        refundSale.purchaseRefundWindow{ value: 1100 }(d);
        require(
            refundSale.nextPurchaseNonce(firstSale, payer) == 2
                && refundSale.nextPurchaseNonce(secondSale, payer) == 2
                && refundSale.nextPurchaseNonce(secondSale, otherBuyer) == 2
                && refundSale.nextPurchaseNonce(firstSale, otherBuyer) == 1,
            "sales and buyers independent"
        );
        refundId = firstSale;
        bytes32 later = _purchase(4, 1100);
        _atRefundEnd(later);
        refundSale.finalizeRefundWindow(later);
        require(refundSale.nextPurchaseNonce(firstSale, payer) == 3, "finalize never rewinds");
        vm.warp(refundSale.refundPurchaseRecord(second).authorization.absoluteEscapeDeadline + 1);
        vm.recordLogs();
        refundSale.unlockRefund(second, 0);
        _checkUnlockEvent(vm.getRecordedLogs(), secondSale, second);
        require(refundSale.nextPurchaseNonce(secondSale, payer) == 2, "unlock never rewinds");
    }

    function _checkRefundEvent(Vm.Log[] memory logs, bytes32 saleId, bytes32 purchaseId)
        private
        view
    {
        bytes32 topic = keccak256("RefundWindowRefunded(uint16,bytes32,bytes32,address,uint256)");
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(refundSale) || logs[i].topics.length == 0
                    || logs[i].topics[0] != topic
            ) continue;
            ++count;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == saleId
                    && logs[i].topics[2] == purchaseId
                    && logs[i].topics[3] == bytes32(uint256(uint160(payer)))
                    && keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), uint256(1100))),
                "exact canonical refund event includes principal and saved fee"
            );
        }
        require(count == 1, "one canonical refund event");
    }

    function _checkUnlockEvent(Vm.Log[] memory logs, bytes32 saleId, bytes32 purchaseId)
        private
        view
    {
        bytes32 topic = keccak256("RefundWindowRefundUnlocked(uint16,bytes32,bytes32,bytes32)");
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(refundSale) || logs[i].topics.length == 0
                    || logs[i].topics[0] != topic
            ) continue;
            ++count;
            require(
                logs[i].topics.length == 3 && logs[i].topics[1] == saleId
                    && logs[i].topics[2] == purchaseId
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(uint16(1), keccak256("REFUND_FINALIZATION_DEADLINE"))
                        ),
                "exact canonical unlock event and time reason"
            );
        }
        require(count == 1, "one canonical unlock event");
    }
}
