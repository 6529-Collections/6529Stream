// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

contract StreamNativeClearingConservationTest is ClearingSaleTestBase {
    function testFuzzRealTwoPurchaseClaimsPartialReceiptAndUnlockPreserveSurplus(
        uint256 rawFirst,
        uint256 rawSecond,
        uint8 elapsedSeed
    ) external {
        uint256 ceiling1 = 100 + rawFirst % 901;
        uint256 ceiling2 = rawSecond % 2 == 0
            ? 100 + rawSecond % 901
            : rawSecond < 100 ? 100 : rawSecond;
        uint256 paid1 = ceiling1;
        uint256 paid2 = ceiling2 < 1000 ? ceiling2 : 1000;
        uint256 payerBefore = payer.balance;
        vm.deal(address(clearingSale), 77); // Explicit unsolicited surplus, excluded from buyer basis.
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        d.authorization.hasPriceOverride = true;
        d.authorization.priceOverride = ceiling1;
        _signClearing(d);
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory first =
            clearingSale.purchase{ value: paid1 + 27 }(d);
        vm.prank(payer); // Claim the first excess while still OPEN.
        clearingSale.claimRefund(clearingId, payer);
        d = _clearingData(2, payer, payer);
        d.authorization.hasPriceOverride = true;
        d.authorization.priceOverride = ceiling2;
        _signClearing(d);
        vm.prank(payer);
        clearingSale.purchase{ value: paid2 + 23 }(d);
        uint256 elapsed = uint256(elapsedSeed) % 100;
        vm.warp(1000 + elapsed);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        uint256 clearing = 1000 - 9 * elapsed;
        uint256 u1 = ceiling1 < clearing ? ceiling1 : clearing;
        uint256 u2 = ceiling2 < clearing ? ceiling2 : clearing;
        uint256 rebate = paid1 - u1 + paid2 - u2;
        require(
            clearingSale.refundableBalance(clearingId, payer) == rebate + 3
                && clearingSale.financialSale(clearingId).scheduledSupplement == u1 + u2 - 200,
            "independent per-buyer and aggregate sums"
        );
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        uint256 settled;
        if (u1 > 100) {
            clearingSale.settlePurchaseSupplement(first.purchaseId);
            settled = u1 - 100;
        }
        if (clearingSale.financialSale(clearingId).status != 3) {
            vm.warp(1501);
            clearingSale.unlockRefunds(clearingId, 0);
        }
        uint256 remaining = u2 - 100;
        require(
            clearingSale.refundableBalance(clearingId, payer) == remaining,
            "only second unsettled financial principal"
        );
        if (remaining != 0) {
            vm.prank(payer);
            clearingSale.claimRefund(clearingId, payer);
        }
        require(
            clearingSale.totalBuyerLiabilities() == 0 && address(clearingSale).balance == 77
                && wallet.balance == 200 + settled
                && recorder.totalOfficialSettled(address(0)) == 200 + settled
                && refundEntropy.revealFeeEscrow(1) == 40
                && payerBefore - payer.balance == 240 + settled
                && clearingSale.nextPurchaseNonce(clearingId, payer) == 3,
            "complete payer/revenue/fee/credit/surplus conservation"
        );
    }

    function testMissingSaleAndDeclaredZeroAreDistinctFromValidPositiveFlatSchedule() external {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingSaleUnavailable.selector, bytes32(uint256(999))
            )
        );
        clearingSale.currentPrice(bytes32(uint256(999)));
        IStreamNativeClearingSale.ClearingSaleConfig memory c = _clearingConfig();
        c.schedule.restingPrice = 0;
        (bool ok,) =
            address(clearingSale).call(abi.encodeCall(clearingSale.registerClearingSale, (c)));
        require(
            !ok && clearingSale.nextSaleNonce() == 2, "clearing requires positive official floor"
        );
        c.schedule.restingPrice = 1000;
        clearingId = clearingSale.registerClearingSale(c);
        IStreamNativeClearingSale.ClearingPurchaseResult memory p = _buy(1, 1020);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        require(
            p.floorRevenue == 1000 && p.heldOverage == 0
                && clearingSale.financialSale(clearingId).status == 3
                && clearingSale.financialSale(clearingId).scheduledSupplement == 0,
            "valid positive flat schedule has no fabricated zero receipt"
        );
        (ok,) = address(clearingSale)
            .call(abi.encodeCall(clearingSale.settlePurchaseSupplement, (p.purchaseId)));
        require(
            !ok && wallet.balance == 1000 && recorder.totalOfficialSettled(address(0)) == 1000,
            "zero financial leg remains outside official settlement"
        );
    }
}
