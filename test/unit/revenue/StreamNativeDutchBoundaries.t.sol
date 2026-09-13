// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/DutchSaleTestBase.sol";

contract StreamNativeDutchBoundariesTest is DutchSaleTestBase {
    function testQuoteBeforeStartDoesNotAuthorizePurchaseAndStartEqualityWorks() public {
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        vm.warp(999);
        require(dutchSale.currentPrice(dutchId) == 1000, "read-only pre-start quote");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeDutchSale.DutchSaleUnavailable.selector, dutchId)
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        vm.warp(1000);
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        require(wallet.balance == 1000, "start equality executable");
    }

    function testDelayedSteppedPurchaseUsesOldMaximumProofAndFinalPartialStepPrice() public {
        IStreamNativeDutchSale.DutchSaleConfig memory c = _dutchConfig();
        c.schedule = IStreamDutchPriceSchedule.DutchPriceSchedule(1000, 200, 1000, 1010, 1, 4, 300);
        dutchId = dutchSale.registerDutchSale(c);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        vm.warp(1008);
        vm.prank(payer);
        IStreamNativeDutchSale.DutchPurchaseResult memory first = dutchSale.purchase{ value: 1100 }(
            d
        );
        require(
            first.chargedAmount == 400 && first.excessCredited == 600,
            "old proof lower executed step"
        );
        d = _dutchData(2, payer, payer);
        vm.warp(1010);
        vm.prank(payer);
        IStreamNativeDutchSale.DutchPurchaseResult memory last = dutchSale.purchase{ value: 1100 }(
            d
        );
        require(
            last.chargedAmount == 200 && last.excessCredited == 800 && wallet.balance == 600,
            "partial final interval reaches rest"
        );
    }

    function testQuantityAndClosePreserveHistoryAndPerSaleClaimsSurviveUnavailableProviders()
        public
    {
        IStreamNativeDutchSale.DutchSaleConfig memory c = _dutchConfig();
        c.maxSaleQuantity = 1;
        dutchId = dutchSale.registerDutchSale(c);
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        vm.prank(payer);
        dutchSale.purchase{ value: 1200 }(d);
        d = _dutchData(2, payer, payer);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeDutchSale.DutchSaleUnavailable.selector, dutchId)
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 1200 }(d);
        bytes32 first = dutchId;
        dutchId = dutchSale.registerDutchSale(_dutchConfig());
        d = _dutchData(2, payer, payer);
        vm.prank(payer);
        dutchSale.purchase{ value: 1300 }(d);
        dutchSale.closeSale(first);
        dutchSale.closeSale(dutchId);
        vm.prank(guardian);
        dutchSale.pauseAdapter(keccak256("paused"));
        refundCore.setPointer(keccak256("ARTIST_REGISTRY"), address(0));
        refundCore.setPointer(keccak256("ENTROPY_COORDINATOR"), address(0));
        refundManager.setUnavailable(true);
        require(
            dutchSale.saleRecord(first).mintedQuantity == 1 && dutchSale.saleRecord(first).closed,
            "immutable history survives exhaustion and close"
        );
        vm.prank(payer);
        dutchSale.claimRefund(first, payer);
        require(
            dutchSale.refundableBalance(first, payer) == 0
                && dutchSale.refundableBalance(dutchId, payer) == 200
                && dutchSale.refundCredit(payer) == 200 && dutchSale.refundLiability() == 200,
            "one sale debit only"
        );
        vm.prank(payer);
        dutchSale.claimRefund(dutchId, payer);
        require(
            dutchSale.refundLiability() == 0 && address(dutchSale).balance == 0,
            "unconditional independent second claim"
        );
    }

    function testCommercialAndExecutionReplayLanesRejectAlteredContextWithoutNewMoney() public {
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        d.authorization.nonce = bytes32(uint256(2));
        d.authorization.recipient = address(0xCAFE);
        _signDutch(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchExecutionUsed.selector, dutchId, uint256(1)
            )
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        d.authorization.executionNonce = 2;
        d.authorization.nonce = bytes32(uint256(1));
        _signDutch(d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeDutchSale.DutchAuthorizationUsed.selector, artist, bytes32(uint256(1))
            )
        );
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        require(wallet.balance == 1000 && refundManager.nonce() == 1, "no second money or mint");
        d.authorization.nonce = bytes32(uint256(2));
        _signDutch(d);
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        require(
            wallet.balance == 2000 && refundManager.ownerOf(2) == address(0xCAFE),
            "fresh both lanes control"
        );
    }
}
