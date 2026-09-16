// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

/// @dev The same qualified domain composition as functional32199, with a compressed aggregate.
contract StreamClearingCompressedGasTest is ClearingSaleTestBase {
    event log_named_uint(string key, uint256 value);

    function testMeasureCompressedComposedPurchaseAndExistingBuyerWithExactMoney() external {
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        SafeFixtureVm(address(vm)).cool(address(clearingSale));
        SafeFixtureVm(address(vm)).cool(address(recorder));
        SafeFixtureVm(address(vm)).cool(wallet);
        SafeFixtureVm(address(vm)).cool(address(clearingManager));
        vm.prank(payer);
        uint256 beforeGas = gasleft();
        IStreamNativeClearingSale.ClearingPurchaseResult memory first =
            clearingSale.purchase{ value: 1020 }(d);
        uint256 firstGas = beforeGas - gasleft();
        emit log_named_uint("COMPRESSED_COMPOSED_FIRST_PARTIALLY_COOLED", firstGas);
        d = _clearingData(2, payer, payer);
        vm.prank(payer);
        beforeGas = gasleft();
        IStreamNativeClearingSale.ClearingPurchaseResult memory second =
            clearingSale.purchase{ value: 1020 }(d);
        uint256 repeatGas = beforeGas - gasleft();
        emit log_named_uint("COMPRESSED_COMPOSED_REPEAT_WARM", repeatGas);
        require(
            firstGas < 6843542 && repeatGas < 2084997,
            "improves the exact prior qualified measurements"
        );
        require(
            first.tokenId != second.tokenId && first.purchaseId != second.purchaseId,
            "independent purchases"
        );
        require(
            wallet.balance == 200 && clearingManager.nonce() == 2 && first.floorRevenue == 100
                && second.floorRevenue == 100 && clearingSale.totalBuyerLiabilities() == 1800,
            "same exact native accounting"
        );
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        require(
            clearingSale.refundableBalance(clearingId, payer) == 720,
            "exact paired compressed entitlements"
        );
        clearingSale.settlePurchaseSupplement(first.purchaseId);
        vm.warp(1501);
        clearingSale.unlockRefunds(clearingId, 0);
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        require(
            wallet.balance == 740 && clearingSale.totalBuyerLiabilities() == 0,
            "partial receipt and terminal refund conserved"
        );
    }
}
