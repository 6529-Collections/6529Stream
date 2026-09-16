// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

contract StreamNativeClearingSaleTest is ClearingSaleTestBase {
    function testActualFloorMintThenPriceFixOneSupplementAndPermanentRebate() external {
        IStreamNativeClearingSale.ClearingPurchaseResult memory p = _buy(1, 1027);
        require(
            p.chargedAmount == 1000 && p.floorRevenue == 100 && p.heldOverage == 900
                && p.revealFeeForwarded == 20 && p.excessCredited == 7,
            "purchase exact parts"
        );
        require(
            wallet.balance == 100
                && recorder.officialSettled(CLASS, profile, wallet, address(0)) == 100,
            "only floor official"
        );
        require(
            clearingManager.nonce() == 1 && clearingManager.ownerOf(p.tokenId) == payer,
            "actual mock mint"
        );
        require(
            clearingSale.refundableBalance(clearingId, payer) == 7
                && clearingSale.totalBuyerLiabilities() == 907,
            "OPEN excess"
        );
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        vm.warp(1050);
        clearingSale.fixClearingPrice(clearingId);
        require(
            clearingSale.financialSale(clearingId).clearingPrice == 640,
            "close reference not keeper550"
        );
        require(
            clearingSale.refundableBalance(clearingId, payer) == 367,
            "rebate before synchronization"
        );
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        require(address(clearingSale).balance == 540, "only supplement held");
        StreamNativeSupplementalTypes.NativeSupplementalResult memory r =
            clearingSale.settlePurchaseSupplement(p.purchaseId);
        require(
            r.amount == 540 && r.originalOperationId == p.operationId && r.tokenId == p.tokenId,
            "exact financial association"
        );
        require(
            wallet.balance == 640 && clearingManager.nonce() == 1
                && refundEntropy.revealFeeEscrow(1) == 20,
            "no second mint or fee"
        );
        require(
            clearingSale.totalBuyerLiabilities() == 0 && address(clearingSale).balance == 0,
            "conservation"
        );
        require(
            keccak256(abi.encode(clearingSale.settlePurchaseSupplement(p.purchaseId)))
                == keccak256(abi.encode(r)),
            "stored repeat"
        );
    }

    function testDiscountCeilingDoesNotChangeSoldOutScheduleAndPartialUnlockConserves() external {
        IStreamNativeClearingSale.ClearingSaleConfig memory config = _clearingConfig();
        config.maxSaleQuantity = 2;
        clearingId = clearingSale.registerClearingSale(config);
        IStreamNativeClearingSale.ClearingPurchaseResult memory first = _buy(1, 1020);
        vm.warp(1040);
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(2, payer, payer);
        d.authorization.hasPriceOverride = true;
        d.authorization.priceOverride = 400;
        _signClearing(d);
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory second =
            clearingSale.purchase{ value: 420 }(d);
        vm.warp(1050);
        clearingSale.fixClearingPrice(clearingId);
        require(
            clearingSale.financialSale(clearingId).clearingPrice == 640,
            "sold out uses schedule640 not discounted400"
        );
        require(clearingSale.financialSale(clearingId).scheduledSupplement == 840, "540 plus300");
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        clearingSale.settlePurchaseSupplement(first.purchaseId);
        vm.warp(1501);
        clearingSale.unlockRefunds(clearingId, 0);
        require(
            clearingSale.refundableBalance(clearingId, payer) == 300,
            "only unsettled purchase refundable"
        );
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        require(
            wallet.balance == 740 && clearingSale.totalBuyerLiabilities() == 0,
            "floors200 plus540 retained"
        );
        (bool ok,) = address(clearingSale)
            .call(abi.encodeCall(clearingSale.settlePurchaseSupplement, (second.purchaseId)));
        require(!ok && wallet.balance == 740, "terminal no payment reopen");
    }

    function testLateMintFailureRollsBackPairedTreesNonceFloorFeeAndSameProofRetries() external {
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        clearingManager.setMode(1);
        vm.prank(payer);
        (bool ok,) =
            address(clearingSale).call{ value: 1020 }(abi.encodeCall(clearingSale.purchase, (d)));
        require(!ok && wallet.balance == 0 && clearingManager.nonce() == 0, "late mint rollback");
        require(
            clearingSale.nextPurchaseNonce(clearingId, payer) == 1
                && clearingSale.financialSale(clearingId).purchasedQuantity == 0
                && clearingSale.totalBuyerLiabilities() == 0
                && !clearingSale.authorizationUsed(artist, bytes32(uint256(1))),
            "all state restored"
        );
        clearingManager.setMode(0);
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        require(
            wallet.balance == 100 && clearingSale.nextPurchaseNonce(clearingId, payer) == 2,
            "identical proof retry"
        );
    }
}
