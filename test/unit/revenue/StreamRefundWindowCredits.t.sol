// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RefundWindowTestBase.sol";

contract RefundCreditReceiver {
    IStreamNativeRefundWindowSale public target;
    bytes32 public nestedSale;
    bool public attemptNested;
    bool public rejectValue;
    bool public nestedSucceeded;
    bytes public nestedReason;

    function configure(IStreamNativeRefundWindowSale t, bytes32 id, bool nested, bool reject)
        external
    {
        target = t;
        nestedSale = id;
        attemptNested = nested;
        rejectValue = reject;
    }

    function claim(bytes32 id) external returns (uint256) {
        return target.claimRefund(id, payable(address(this)));
    }

    receive() external payable {
        if (rejectValue) revert("recipient refuses");
        if (attemptNested) {
            (nestedSucceeded, nestedReason) = address(target)
                .call(
                    abi.encodeCall(
                        IStreamNativeRefundWindowSale.claimRefund,
                        (nestedSale, payable(address(this)))
                    )
                );
        }
    }
}

contract StreamRefundWindowCreditsTest is RefundWindowTestBase {
    function testTwoSalesKeepExcessRefundFeeRemainderAndClaimsIndependentlyConserved() public {
        bytes32 firstSale = refundId;
        vm.deal(address(refundSale), 77);
        bytes32 first = _purchase(1, 1150);
        IStreamNativeRefundWindowSale.RefundSaleConfig memory c = _refundConfig();
        c.price = 2000;
        bytes32 secondSale = refundSale.registerRefundSale(c);
        refundId = secondSale;
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _purchaseData(2, payer, payer);
        d.authorization.price = 2000;
        _signPurchase(d);
        vm.prank(payer);
        bytes32 second = refundSale.purchaseRefundWindow{ value: 2200 }(d);
        _credits(firstSale, secondSale, 50, 100, 3200);

        vm.prank(payer);
        refundSale.refundPurchase(first);
        _credits(firstSale, secondSale, 1150, 100, 2100);
        RefundCreditReceiver rejector = new RefundCreditReceiver();
        rejector.configure(refundSale, 0, false, true);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundTransferFailed.selector, address(rejector)
            )
        );
        refundSale.claimRefund(firstSale, payable(address(rejector)));
        _credits(firstSale, secondSale, 1150, 100, 2100);
        vm.prank(address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundCreditEmpty.selector, address(0xBAD)
            )
        );
        refundSale.claimRefund(firstSale, payable(address(0xBAD)));
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeRefundWindowSale.RefundCreditEmpty.selector, payer)
        );
        refundSale.claimRefund(bytes32(uint256(0xBAD)), payable(payer));
        _credits(firstSale, secondSale, 1150, 100, 2100);

        vm.recordLogs();
        uint256 before = payer.balance;
        vm.prank(payer);
        require(
            refundSale.claimRefund(firstSale, payable(payer)) == 1150, "claim only selected sale"
        );
        require(payer.balance == before + 1150, "exact first payout");
        _claimEvent(vm.getRecordedLogs(), firstSale, payer, payer, 1150);
        _credits(firstSale, secondSale, 0, 100, 2100);
        vm.prank(payer);
        refundSale.refundPurchase(first);
        _credits(firstSale, secondSale, 0, 100, 2100);

        refundEntropy.setPolicy(true, 1, 40);
        _atRefundEnd(second);
        refundSale.finalizeRefundWindow(second);
        _credits(firstSale, secondSale, 0, 160, 0);
        require(
            wallet.balance == 2000 && refundEntropy.revealFeeEscrow(1) == 40,
            "price and live fee separate from credits"
        );
        vm.recordLogs();
        vm.prank(payer);
        require(
            refundSale.claimRefund(secondSale, payable(payer)) == 160,
            "only second excess and fee remainder"
        );
        _claimEvent(vm.getRecordedLogs(), secondSale, payer, payer, 160);
        _credits(firstSale, secondSale, 0, 0, 0);
    }

    function testCreditorCallbackCannotClaimAnotherSaleUntilOuterClaimCompletes() public {
        RefundCreditReceiver creditor = new RefundCreditReceiver();
        vm.deal(address(creditor), 2200);
        bytes32 firstSale = refundId;
        IStreamNativeRefundWindowSale.RefundPurchaseData memory a =
            _purchaseData(1, address(creditor), address(creditor));
        vm.prank(address(creditor));
        bytes32 first = refundSale.purchaseRefundWindow{ value: 1100 }(a);
        bytes32 secondSale = refundSale.registerRefundSale(_refundConfig());
        refundId = secondSale;
        a = _purchaseData(2, address(creditor), address(creditor));
        vm.prank(address(creditor));
        bytes32 second = refundSale.purchaseRefundWindow{ value: 1100 }(a);
        vm.prank(address(creditor));
        refundSale.refundPurchase(first);
        vm.prank(address(creditor));
        refundSale.refundPurchase(second);
        creditor.configure(refundSale, secondSale, true, false);
        require(creditor.claim(firstSale) == 1100, "outer selected claim succeeds");
        require(
            !creditor.nestedSucceeded()
                && keccak256(creditor.nestedReason())
                    == keccak256(abi.encodeWithSignature("ReentrancyGuardReentrantCall()")),
            "same creditor valid second-sale claim blocked by exact guard"
        );
        require(
            refundSale.refundableBalance(firstSale, address(creditor)) == 0
                && refundSale.refundableBalance(secondSale, address(creditor)) == 1100
                && refundSale.refundCredit(address(creditor)) == 1100
                && refundSale.totalBuyerLiabilities() == 1100,
            "nested attempt leaves second sale owed"
        );
        creditor.configure(refundSale, secondSale, false, false);
        require(
            creditor.claim(secondSale) == 1100 && address(creditor).balance == 2200
                && refundSale.totalBuyerLiabilities() == 0
                && refundSale.refundCredit(address(creditor)) == 0,
            "same second sale claim succeeds after callback"
        );
    }

    function _credits(bytes32 a, bytes32 b, uint256 x, uint256 y, uint256 pending) private view {
        require(
            refundSale.refundableBalance(a, payer) == x
                && refundSale.refundableBalance(b, payer) == y
                && refundSale.refundCredit(payer) == x + y,
            "per-sale credits sum exactly"
        );
        require(
            refundSale.totalPendingDeposits() == pending
                && refundSale.totalBuyerLiabilities() == x + y + pending
                && address(refundSale).balance == x + y + pending + 77,
            "pending credits and forced surplus independently conserved"
        );
    }

    function _claimEvent(
        Vm.Log[] memory logs,
        bytes32 saleId,
        address account,
        address recipient,
        uint256 amount
    ) private view {
        uint256 count;
        bytes32 topic = keccak256("RefundCreditClaimed(uint16,bytes32,address,address,uint256)");
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(refundSale) || logs[i].topics.length == 0
                    || logs[i].topics[0] != topic
            ) continue;
            ++count;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == saleId
                    && logs[i].topics[2] == bytes32(uint256(uint160(account)))
                    && logs[i].topics[3] == bytes32(uint256(uint160(recipient)))
                    && keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), amount)),
                "exact sale-scoped claim event"
            );
        }
        require(count == 1, "one exact claim event");
    }
}
