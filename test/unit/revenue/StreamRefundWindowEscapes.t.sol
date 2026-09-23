// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RefundWindowTestBase.sol";

contract StreamRefundWindowEscapesTest is RefundWindowTestBase {
    function testRefundAndFinalizationMeetAtExactRefundDeadline() public {
        bytes32 id = _purchase(1, 1100);
        (uint64 deadline,,) = refundSale.purchaseDeadlines(id);
        vm.warp(deadline - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundWindowStillOpen.selector, id, deadline
            )
        );
        refundSale.finalizeRefundWindow(id);
        vm.warp(deadline);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundWindowClosed.selector, id, deadline
            )
        );
        refundSale.refundPurchase(id);
        refundSale.finalizeRefundWindow(id);
        require(refundManager.nonce() == 1 && wallet.balance == 1000, "finalize at boundary");
    }

    function testPausedEscapeEqualityUnlocksAndAfterEscapeIgnoresEveryProvider() public {
        bytes32 id = _purchase(1, 1100);
        uint64 escape = refundSale.refundPurchaseRecord(id).authorization.absoluteEscapeDeadline;
        _pauseGlobal(true);
        vm.warp(escape - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundUnlockNotAvailable.selector, id, uint8(0)
            )
        );
        refundSale.unlockRefund(id, 0);
        vm.warp(escape);
        refundSale.unlockRefund(id, 0);
        require(
            refundSale.refundCredit(payer) == 1100
                && refundSale.refundPurchaseRecord(id).status == 4,
            "paused equality no gap"
        );
    }

    function testStrictlyAfterEscapeRefundIgnoresUnavailableProvidersAndModuleIncident() public {
        bytes32 id = _purchase(1, 1100);
        uint64 escape = refundSale.refundPurchaseRecord(id).authorization.absoluteEscapeDeadline;
        _pauseGlobal(true);
        _status(address(refundSale), ModuleRegistryStatus.INCIDENT_REVOKED);
        refundCore.setPointer(keccak256("ARTIST_REGISTRY"), address(0));
        refundCore.setPointer(keccak256("MODULE_REGISTRY"), address(0));
        refundCore.setPointer(keccak256("ENTROPY_COORDINATOR"), address(0));
        refundManager.setUnavailable(true);
        refundEntropy.setPolicy(false, 9, type(uint256).max);
        vm.warp(escape + 1);
        refundSale.unlockRefund(id, 0);
        vm.prank(payer);
        refundSale.claimRefund(refundId, payable(payer));
        require(
            refundSale.totalBuyerLiabilities() == 0 && address(refundSale).balance == 0
                && wallet.balance == 0,
            "escape independent of all dependencies"
        );
    }

    function testUnpausedFinalizationSucceedsThroughAbsoluteEscapeEquality() public {
        bytes32 id = _purchase(1, 1100);
        uint64 escape = refundSale.refundPurchaseRecord(id).authorization.absoluteEscapeDeadline;
        _pauseGlobal(true);
        vm.warp(20_000);
        _pauseGlobal(false);
        vm.warp(escape);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundUnlockNotAvailable.selector, id, uint8(0)
            )
        );
        refundSale.unlockRefund(id, 0);
        refundSale.finalizeRefundWindow(id);
        require(
            refundSale.refundPurchaseRecord(id).status == 2 && wallet.balance == 1000,
            "unpaused equality has finalization outcome"
        );
    }

    function testLatePauseCannotReviveExpiredOrdinaryFinalizationWindow() public {
        bytes32 id = _purchase(1, 1100);
        (, uint64 end,) = refundSale.purchaseDeadlines(id);
        vm.warp(end + 1);
        _pauseGlobal(true);
        vm.warp(end + 100);
        refundSale.unlockRefund(id, 0);
        require(
            refundSale.refundCredit(payer) == 1100, "elapsed unpaused time already exceeded window"
        );
    }

    function testActualPauseUnionExcludesPriorHistoryAndFreezesTerminalToll() public {
        _pauseGlobal(true);
        vm.warp(1010);
        _pauseLocal(true);
        vm.warp(1020);
        _pauseGlobal(false);
        vm.warp(1030);
        _pauseLocal(false);
        bytes32 id = _purchase(1, 1100);
        require(
            refundSale.refundPurchaseRecord(id).pauseBaseline == 30, "prior union history captured"
        );
        vm.warp(1040);
        _pauseGlobal(true);
        vm.warp(1050);
        _pauseLocal(true);
        vm.warp(1060);
        _pauseGlobal(false);
        vm.warp(1080);
        _pauseLocal(false);
        (uint64 refundDeadline, uint64 end, uint64 toll) = refundSale.purchaseDeadlines(id);
        require(
            toll == 40 && refundDeadline == 4670 && end == 91070,
            "independent interval union after baseline"
        );
        vm.prank(payer);
        refundSale.refundPurchase(id);
        _pauseLocal(true);
        vm.warp(2000);
        _pauseLocal(false);
        (uint64 againR, uint64 againE, uint64 againT) = refundSale.purchaseDeadlines(id);
        require(
            againR == refundDeadline && againE == end && againT == toll,
            "terminal observed clocks immutable"
        );
    }
}
