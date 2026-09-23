// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

contract StreamNativeClearingWindowsTest is ClearingSaleTestBase {
    function _soldOut() private returns (IStreamNativeClearingSale.ClearingPurchaseResult memory) {
        IStreamNativeClearingSale.ClearingSaleConfig memory c = _clearingConfig();
        c.maxSaleQuantity = 1;
        clearingId = clearingSale.registerClearingSale(c);
        return _buy(1, 1020);
    }

    function testUnattendedConfiguredCloseUsesHistoricalPauseUnionAndTerminalSnapshot() external {
        _buy(1, 1020);
        vm.warp(1080);
        vm.prank(guardian);
        clearingSale.pauseAdapter(bytes32(uint256(1)));
        vm.warp(1090);
        vm.prank(guardian);
        clearingSale.pauseSale(clearingId, bytes32(uint256(2)));
        // No transaction at the configured close1100.
        vm.warp(1110);
        vm.prank(unpauser);
        clearingSale.unpauseAdapter(bytes32(uint256(3)));
        vm.warp(1120);
        vm.prank(guardian);
        clearingSale.pauseAdapter(bytes32(uint256(4)));
        vm.warp(1130);
        vm.prank(unpauser);
        clearingSale.unpauseSale(clearingId, bytes32(uint256(5)));
        vm.warp(1140);
        vm.prank(unpauser);
        clearingSale.unpauseAdapter(bytes32(uint256(6)));
        (uint64 refTime, uint64 nominal, uint64 effective, uint64 toll) =
            clearingSale.saleDeadlines(clearingId);
        require(
            refTime == 1100 && nominal == 1200 && toll == 40 && effective == 1240,
            "only union after exact close"
        );
        clearingSale.fixClearingPrice(clearingId); // At configured end all supplement zero; rebate terminal.
        bytes32 before = keccak256(abi.encode(clearingSale.saleRecord(clearingId)));
        vm.warp(1150);
        vm.prank(guardian);
        clearingSale.pauseAdapter(bytes32(uint256(7)));
        vm.warp(1400);
        (,, effective, toll) = clearingSale.saleDeadlines(clearingId);
        require(
            effective == 1240 && toll == 40
                && keccak256(abi.encode(clearingSale.saleRecord(clearingId))) == before,
            "terminal clock immutable"
        );
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        require(
            clearingSale.totalBuyerLiabilities() == 0 && wallet.balance == 100,
            "claims live under pause"
        );
    }

    function testPausedEscapeEqualityAndStrictlyAfterNeedNoExternalDependency() external {
        _soldOut();
        clearingSale.fixClearingPrice(clearingId);
        vm.warp(1050);
        vm.prank(guardian);
        clearingSale.pauseAdapter(bytes32(uint256(1)));
        vm.warp(1499);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingUnlockUnavailable.selector, clearingId, uint8(0)
            )
        );
        clearingSale.unlockRefunds(clearingId, 0);
        refundCore.setPointer(keccak256("ARTIST_REGISTRY"), address(0));
        refundCore.setPointer(keccak256("MODULE_REGISTRY"), address(0));
        vm.warp(1500);
        clearingSale.unlockRefunds(clearingId, 0);
        require(clearingSale.refundableBalance(clearingId, payer) == 900, "paused equality escape");
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        vm.warp(1501);
        clearingSale.unlockRefunds(clearingId, 0);
        require(
            clearingSale.totalBuyerLiabilities() == 0 && wallet.balance == 100,
            "terminal repeat and floor retained"
        );
    }

    function testUnpausedAbsoluteEqualityCanFinalizeAndLaterRepeatIgnoresCurrentAuthority()
        external
    {
        IStreamNativeClearingSale.ClearingPurchaseResult memory p = _soldOut();
        clearingSale.fixClearingPrice(clearingId);
        vm.warp(1050);
        vm.prank(guardian);
        clearingSale.pauseAdapter(bytes32(uint256(1)));
        vm.warp(1490);
        vm.prank(unpauser);
        clearingSale.unpauseAdapter(bytes32(uint256(2)));
        vm.warp(1500);
        StreamNativeSupplementalTypes.NativeSupplementalResult memory r =
            clearingSale.settlePurchaseSupplement(p.purchaseId);
        require(r.amount == 900 && wallet.balance == 1000, "unpaused equality executable");
        refundCore.setPointer(keccak256("ARTIST_REGISTRY"), address(0));
        vm.warp(1600);
        require(
            keccak256(abi.encode(clearingSale.settlePurchaseSupplement(p.purchaseId)))
                == keccak256(abi.encode(r)),
            "stored terminal result"
        );
    }

    function testPauseStartedAfterOrdinaryDeadlineCannotReviveFinancialWindow() external {
        IStreamNativeClearingSale.ClearingPurchaseResult memory p = _soldOut();
        clearingSale.fixClearingPrice(clearingId);
        vm.warp(1101);
        vm.prank(guardian);
        clearingSale.pauseAdapter(bytes32(uint256(1)));
        vm.warp(1300);
        clearingSale.unlockRefunds(clearingId, 0);
        vm.prank(unpauser);
        clearingSale.unpauseAdapter(bytes32(uint256(2)));
        (bool ok,) = address(clearingSale)
            .call(abi.encodeCall(clearingSale.settlePurchaseSupplement, (p.purchaseId)));
        require(
            !ok && wallet.balance == 100
                && clearingSale.refundableBalance(clearingId, payer) == 900,
            "late pause no revival"
        );
    }
}
