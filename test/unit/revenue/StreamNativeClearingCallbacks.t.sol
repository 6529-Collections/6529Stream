// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

contract ClearingCallbackReceiver is IERC721Receiver {
    address public target;
    bytes public data;
    bool public reject;
    bool public succeeded;
    bytes public returned;
    address public wallet;
    uint256 public observedFloor;

    function configure(address t, bytes calldata d, bool r, address w) external {
        target = t;
        data = d;
        reject = r;
        wallet = w;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        observedFloor = wallet.balance;
        _callback();
        return IERC721Receiver.onERC721Received.selector;
    }

    function _callback() private {
        if (target != address(0)) (succeeded, returned) = target.call(data);
        require(!reject, "clearing recipient rejected");
    }

    receive() external payable {
        _callback();
    }
}

contract StreamNativeClearingCallbacksTest is ClearingSaleTestBase {
    function _drift(uint8 status, uint64 generation) private pure returns (bytes memory) {
        return abi.encodeCall(
            RefundRuntimeArtist.setAssociation,
            (
                uint8(2),
                generation,
                keccak256("refund artist identity"),
                status,
                keccak256("refund artist binding")
            )
        );
    }

    function _emptyPurchase() private view {
        require(
            wallet.balance == 0 && recorder.totalOfficialSettled(address(0)) == 0
                && clearingManager.nonce() == 0
                && clearingSale.financialSale(clearingId).purchasedQuantity == 0
                && clearingSale.totalBuyerLiabilities() == 0
                && clearingSale.nextPurchaseNonce(clearingId, payer) == 1
                && refundEntropy.revealFeeEscrow(1) == 0,
            "all purchase effects rolled back"
        );
    }

    function testNFTAssociationDriftAndFeeContestEachRollbackThenSameProofRetries() external {
        ClearingCallbackReceiver receiver = new ClearingCallbackReceiver();
        IStreamNativeClearingSale.ClearingPurchaseData memory d =
            _clearingData(1, payer, address(receiver));
        receiver.configure(address(refundArtist), _drift(1, 2), false, wallet);
        vm.expectRevert(abi.encodeWithSelector(IStreamNativeDutchSale.InvalidDutchSale.selector));
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        _emptyPurchase();
        require(
            refundArtist.generation() == 1 && receiver.observedFloor() == 0,
            "NFT callback rolled back"
        );
        receiver.configure(address(0), "", false, wallet);
        refundEntropy.setCallback(address(refundArtist), _drift(4, 1));
        vm.expectRevert(abi.encodeWithSelector(IStreamNativeDutchSale.InvalidDutchSale.selector));
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        _emptyPurchase();
        require(refundArtist.authorityStatus() == 1, "fee callback status rolled back");
        refundEntropy.setCallback(address(0), "");
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        require(
            receiver.observedFloor() == 100 && clearingManager.ownerOf(1) == address(receiver)
                && refundEntropy.revealFeeEscrow(1) == 20,
            "same complete proof and funded-before-mint control"
        );
    }

    function testPendingFinancialAssociationDriftRejectsButConsumedProofSurvivesRotationAndExpiry()
        external
    {
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        d.authorization.deadline = 1001;
        _signClearing(d);
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory p =
            clearingSale.purchase{ value: 1020 }(d);
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        require(d.authorization.deadline < block.timestamp, "original proof expired");
        for (uint8 mode = 1; mode <= 3; ++mode) {
            refundArtist.setAssociation(
                2,
                mode == 1 ? 2 : 1,
                keccak256("refund artist identity"),
                mode == 2 ? 4 : 1,
                mode == 3 ? keccak256("different") : keccak256("refund artist binding")
            );
            vm.expectRevert(
                abi.encodeWithSelector(IStreamNativeDutchSale.InvalidDutchSale.selector)
            );
            clearingSale.settlePurchaseSupplement(p.purchaseId);
            require(
                wallet.balance == 100 && clearingSale.totalBuyerLiabilities() == 900
                    && clearingSale.financialSale(clearingId).settledSupplement == 0
                    && !recorder.supplementalPurchaseConsumed(
                        recorder.supplementalPurchaseKey(address(clearingSale), p.purchaseId)
                    ),
                "pending retained"
            );
        }
        refundArtist.setAssociation(
            2, 1, keccak256("refund artist identity"), 1, keccak256("refund artist binding")
        );
        artists.accept(address(0xAABB)); // Domain double of lawful address rotation in the same association.
        clearingManager.setUnavailable(true); // A completed mint's financial leg never rechecks phase admission.
        clearingSale.settlePurchaseSupplement(p.purchaseId);
        require(
            wallet.balance == 640 && clearingManager.nonce() == 1,
            "no old signature or mint revalidation"
        );
    }

    function testReceiverReentryPinsGuardAndClaimFailureRestoresCreditThenRetry() external {
        ClearingCallbackReceiver receiver = new ClearingCallbackReceiver();
        IStreamNativeClearingSale.ClearingPurchaseData memory d =
            _clearingData(1, payer, address(receiver));
        receiver.configure(
            address(clearingSale), abi.encodeCall(clearingSale.purchase, (d)), false, wallet
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 1027 }(d);
        require(
            !receiver.succeeded()
                && keccak256(receiver.returned())
                    == keccak256(abi.encodeWithSignature("ReentrancyGuardReentrantCall()"))
        );
        require(receiver.observedFloor() == 100, "active consumer guard with paid floor");
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        receiver.configure(address(0), "", true, wallet);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingTransferFailed.selector, address(receiver)
            )
        );
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, address(receiver));
        require(
            clearingSale.refundableBalance(clearingId, payer) == 367
                && clearingSale.totalBuyerLiabilities() == 907
                && address(clearingSale).balance == 907,
            "failed claim restores full sale and total"
        );
        receiver.configure(
            address(clearingSale),
            abi.encodeCall(clearingSale.synchronizeRebate, (clearingId, payer)),
            false,
            wallet
        );
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, address(receiver));
        require(
            address(receiver).balance == 367 && !receiver.succeeded()
                && keccak256(receiver.returned())
                    == keccak256(abi.encodeWithSignature("ReentrancyGuardReentrantCall()"))
                && clearingSale.totalBuyerLiabilities() == 540,
            "claim callback guard and exact successful retry"
        );
    }

    function testContestedAuthorityDoesNotMasqueradeAsDisputeOrBlockAbsoluteCreditEscape()
        external
    {
        _buy(1, 1027);
        refundArtist.setAssociation(
            2, 1, keccak256("refund artist identity"), 4, keccak256("refund artist binding")
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingUnlockUnavailable.selector, clearingId, uint8(1)
            )
        );
        clearingSale.unlockRefunds(clearingId, 1);
        vm.prank(payer); // OPEN excess remains live.
        clearingSale.claimRefund(clearingId, payer);
        vm.warp(1501);
        clearingSale.unlockRefunds(clearingId, 0);
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        require(
            wallet.balance == 100 && clearingSale.totalBuyerLiabilities() == 0,
            "contested deadline exit floor retained"
        );
    }
}
