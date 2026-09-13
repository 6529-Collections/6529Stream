// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RefundWindowTestBase.sol";

contract StreamRefundWindowSettlementTest is RefundWindowTestBase {
    function testPurchaseRefundAndPullClaimPreservePrincipalFeeAndSurplus() public {
        vm.deal(address(refundSale), 77);
        bytes32 id = _purchase(1, 1150);
        _pending(id, 1227, 50);
        uint256 beforeBalance = payer.balance;
        vm.prank(payer);
        refundSale.refundPurchase(id);
        require(
            refundSale.refundPurchaseRecord(id).status == 3
                && refundSale.totalPendingDeposits() == 0 && refundSale.refundCredit(payer) == 1150
                && payer.balance == beforeBalance,
            "terminal refund is pull credit"
        );
        vm.prank(payer);
        refundSale.refundPurchase(id);
        vm.prank(payer);
        require(refundSale.claimRefund(refundId, payable(payer)) == 1150, "full claim");
        require(
            payer.balance == beforeBalance + 1150 && address(refundSale).balance == 77
                && refundSale.totalBuyerLiabilities() == 0,
            "forced surplus preserved"
        );
        require(
            recorder.totalOfficialSettled(address(0)) == 0 && refundManager.nonce() == 0
                && refundEntropy.revealFeeEscrow(1) == 0,
            "refund outside official transcript"
        );
    }

    function testPermissionlessFinalizeFundsPrincipalAndSavedFeeOnce() public {
        bytes32 id = _purchase(1, 1100);
        IStreamNativeRefundWindowSale.RefundPurchaseRecord memory p =
            refundSale.refundPurchaseRecord(id);
        _atRefundEnd(id);
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory r =
            refundSale.finalizeRefundWindow(id);
        require(
            r.amount == 1000 && r.revealFeeForwarded == 100 && r.revealFeeRefunded == 0
                && !r.escrowed && r.tokenId == 1,
            "exact final result"
        );
        require(
            wallet.balance == 1000 && refundEntropy.revealFeeEscrow(1) == 100
                && refundManager.ownerOf(1) == payer && address(refundSale).balance == 0,
            "actual payment and recipient"
        );
        require(
            refundSale.totalBuyerLiabilities() == 0 && refundSale.totalPendingDeposits() == 0
                && refundSale.refundPurchaseRecord(id).status == 2,
            "terminal accounting"
        );
        require(
            refundManager.lastAuthorizationId()
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),
                            p.authorizationDigest
                        )
                    ) && refundManager.lastContextHash() == p.authorizationDigest,
            "full original authorization identity"
        );
        require(
            recorder.deferredPurchaseConsumed(recorder.deferredPurchaseKey(address(refundSale), id))
                && recorder.settlementConsumed(r.settlementKey)
                && recorder.totalOfficialSettled(address(0)) == 1000,
            "two replay lanes and official total"
        );
        vm.prank(address(0x99));
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory again =
            refundSale.finalizeRefundWindow(id);
        require(
            keccak256(abi.encode(again)) == keccak256(abi.encode(r)) && refundManager.nonce() == 1
                && wallet.balance == 1000,
            "repeat returns stored success only"
        );
    }

    function testLiveFeeDecreaseCreditsOnlySavedRemainderAndIncreaseNeverPullsMore() public {
        bytes32 id = _purchase(1, 1100);
        refundEntropy.setPolicy(true, 1, 40);
        _atRefundEnd(id);
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory r =
            refundSale.finalizeRefundWindow(id);
        require(
            r.revealFeeForwarded == 40 && r.revealFeeRefunded == 60
                && refundSale.refundCredit(payer) == 60 && refundSale.totalBuyerLiabilities() == 60
                && address(refundSale).balance == 60,
            "saved minus live fee credited"
        );
        refundEntropy.setPolicy(true, 1, 100);
        bytes32 other = _purchase(2, 1100);
        refundEntropy.setPolicy(true, 1, 200);
        _atRefundEnd(other);
        r = refundSale.finalizeRefundWindow(other);
        require(
            r.revealFeeForwarded == 100 && r.revealFeeRefunded == 0
                && refundEntropy.revealFeeEscrow(1) == 140 && refundSale.refundCredit(payer) == 60,
            "higher live fee cannot debit buyer again"
        );
    }

    function testPaidMintFailureRollsBackOfficialKeyFeesAndLiabilitiesThenRetries() public {
        bytes32 id = _purchase(1, 1100);
        _atRefundEnd(id);
        refundManager.setMode(1);
        vm.expectRevert(bytes("mint rejected"));
        refundSale.finalizeRefundWindow(id);
        _pending(id, 1100, 0);
        require(
            !recorder.deferredPurchaseConsumed(
                recorder.deferredPurchaseKey(address(refundSale), id)
            ),
            "purchase replay restored"
        );
        refundManager.setMode(0);
        refundSale.finalizeRefundWindow(id);
        require(wallet.balance == 1000 && refundManager.nonce() == 1, "same purchase exact retry");
    }
}
