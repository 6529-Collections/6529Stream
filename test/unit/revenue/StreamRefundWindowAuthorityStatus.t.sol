// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRefundWindowCallbacks.t.sol";

contract StreamRefundWindowAuthorityStatusTest is RefundWindowTestBase {
    function _status(uint8 status) private {
        refundArtist.setAssociation(
            2, 1, keccak256("refund artist identity"), status, keccak256("refund artist binding")
        );
    }

    function _contestCall() private pure returns (bytes memory) {
        return abi.encodeCall(
            RefundRuntimeArtist.setAssociation,
            (
                uint8(2),
                uint64(1),
                keccak256("refund artist identity"),
                uint8(4),
                keccak256("refund artist binding")
            )
        );
    }

    function testNonactiveAuthorityCannotAcceptNewDepositAndIdenticalActiveProofSucceeds() public {
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _purchaseData(1, payer, payer);
        uint8[5] memory statuses = [uint8(0), 2, 3, 4, 255];
        uint256 balance = payer.balance;
        for (uint256 i; i < statuses.length; ++i) {
            _status(statuses[i]);
            require(
                artists.acceptedArtist(1) == artist, "address remains while authority is nonactive"
            );
            vm.prank(payer);
            vm.expectRevert(
                abi.encodeWithSelector(IStreamNativeRefundWindowSale.InvalidRefundSale.selector)
            );
            refundSale.purchaseRefundWindow{ value: 1100 }(d);
            require(
                payer.balance == balance && address(refundSale).balance == 0
                    && refundSale.nextPurchaseNonce(refundId, payer) == 1
                    && !refundSale.purchaseAuthorizationUsed(artist, d.authorization.nonce)
                    && refundSale.totalBuyerLiabilities() == 0
                    && refundSale.totalPendingDeposits() == 0
                    && recorder.totalOfficialSettled(address(0)) == 0 && refundManager.nonce() == 0,
                "nonactive admission preserves both replay lanes and all funds"
            );
        }
        _status(1);
        vm.prank(payer);
        bytes32 id = refundSale.purchaseRefundWindow{ value: 1100 }(d);
        _pending(id, 1100, 0);
        require(
            refundSale.nextPurchaseNonce(refundId, payer) == 2,
            "identical proof accepted once active"
        );
    }

    function testPendingPurchaseCannotFinalizeWhileContestedAndSamePurchaseRetries() public {
        bytes32 id = _purchase(1, 1100);
        _atRefundEnd(id);
        vm.warp(block.timestamp + 1);
        require(
            refundSale.refundPurchaseRecord(id).authorization.deadline < block.timestamp,
            "original purchase proof expired before pending finalization"
        );
        _status(4);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeRefundWindowSale.InvalidRefundSale.selector)
        );
        refundSale.finalizeRefundWindow(id);
        _pending(id, 1100, 0);
        require(
            !recorder.deferredPurchaseConsumed(
                recorder.deferredPurchaseKey(address(refundSale), id)
            ),
            "purchase key untouched"
        );
        _status(1);
        refundSale.finalizeRefundWindow(id);
        require(
            wallet.balance == 1000 && refundManager.nonce() == 1
                && refundEntropy.revealFeeEscrow(1) == 100,
            "same expired original proof finalizes after active status restored"
        );
    }

    function testLateNFTAndFeeAuthorityContestRollBackThenSamePurchaseFinalizes() public {
        RefundWindowReceiver receiver = new RefundWindowReceiver();
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d =
            _purchaseData(1, payer, address(receiver));
        vm.prank(payer);
        bytes32 id = refundSale.purchaseRefundWindow{ value: 1100 }(d);
        _atRefundEnd(id);
        receiver.configure(false, address(refundArtist), _contestCall(), wallet);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeRefundWindowSale.InvalidRefundSale.selector)
        );
        refundSale.finalizeRefundWindow(id);
        _pending(id, 1100, 0);
        require(
            refundArtist.authorityStatus() == 1 && receiver.observedFunds() == 0,
            "NFT contest and funded observation reverted"
        );
        receiver.configure(false, address(0), "", wallet);
        refundEntropy.setCallback(address(refundArtist), _contestCall());
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeRefundWindowSale.InvalidRefundSale.selector)
        );
        refundSale.finalizeRefundWindow(id);
        _pending(id, 1100, 0);
        require(
            refundArtist.authorityStatus() == 1 && refundEntropy.revealFeeEscrow(1) == 0
                && !recorder.deferredPurchaseConsumed(
                    recorder.deferredPurchaseKey(address(refundSale), id)
                ),
            "fee callback authority and both custody/official effects reverted"
        );
        refundEntropy.setCallback(address(0), "");
        refundSale.finalizeRefundWindow(id);
        require(
            receiver.observedFunds() == 1000 && refundManager.ownerOf(1) == address(receiver)
                && refundEntropy.revealFeeEscrow(1) == 100,
            "same purchase final healthy control"
        );
    }

    function testContestedAuthorityCannotBlockRefundClaimOrUnconditionalEscape() public {
        bytes32 first = _purchase(1, 1100);
        bytes32 second = _purchase(2, 1100);
        _status(4);
        vm.prank(payer);
        refundSale.refundPurchase(first);
        vm.prank(payer);
        refundSale.claimRefund(refundId, payable(payer));
        require(
            refundSale.totalPendingDeposits() == 1100 && refundSale.totalBuyerLiabilities() == 1100,
            "contested ordinary refund and pull claim preserve other purchase"
        );
        vm.warp(refundSale.refundPurchaseRecord(second).authorization.absoluteEscapeDeadline + 1);
        refundCore.setPointer(keccak256("ARTIST_REGISTRY"), address(0));
        refundCore.setPointer(keccak256("ENTROPY_COORDINATOR"), address(0));
        refundManager.setUnavailable(true);
        refundSale.unlockRefund(second, 0);
        vm.prank(payer);
        refundSale.claimRefund(refundId, payable(payer));
        require(
            address(refundSale).balance == 0 && refundSale.totalBuyerLiabilities() == 0
                && refundSale.totalPendingDeposits() == 0
                && refundSale.refundableBalance(refundId, payer) == 0
                && recorder.totalOfficialSettled(address(0)) == 0 && wallet.balance == 0,
            "contested escape/claim independent of unavailable current providers"
        );
    }
}
