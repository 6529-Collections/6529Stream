// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RefundWindowTestBase.sol";

contract StreamRefundWindowUnlocksTest is RefundWindowTestBase {
    function testPhaseExpiryAndPolicyGraceUseStrictAndInclusiveBoundaries() public {
        bytes32 first = _purchase(1, 1100);
        bytes32 second = _purchase(2, 1100);
        refundManager.setPhase(false, 2000, true);
        vm.warp(2000);
        _unavailable(first, 1);
        vm.warp(2001);
        refundSale.unlockRefund(first, 1);
        require(refundSale.refundCredit(payer) == 1100, "phase expiry strictly after end");
        refundManager.setPhase(false, 20_000_000, true);
        refundManager.setPolicy(keccak256("new policy"), keccak256("refund phase policy"), 3000);
        vm.warp(3000);
        _unavailable(second, 3);
        vm.warp(3001);
        refundSale.unlockRefund(second, 3);
        require(
            refundSale.refundCredit(payer) == 2200
                && recorder.totalOfficialSettled(address(0)) == 0,
            "inclusive grace expires into full refund credit"
        );
    }

    function testAttributionUnlockUsesSavedGenerationAndNeverIdentityContest() public {
        bytes32 id = _purchase(1, 1100);
        refundArtist.setAssociation(
            2, 1, keccak256("refund artist identity"), 4, keccak256("refund artist binding")
        );
        _unavailable(id, 4);
        refundArtist.setAssociation(
            4, 2, keccak256("refund artist identity"), 1, keccak256("refund artist binding")
        );
        _unavailable(id, 4);
        refundArtist.setAssociation(
            5, 1, keccak256("refund artist identity"), 1, keccak256("refund artist binding")
        );
        refundSale.unlockRefund(id, 4);
        require(
            refundSale.refundPurchaseRecord(id).status == 4
                && refundSale.refundCredit(payer) == 1100,
            "exact original attribution revoked"
        );
    }

    function testIncidentUnlockUsesPurchaseCapturedGateNotLaterReplacement() public {
        refundManager.setGate(address(payment));
        bytes32 id = _purchase(1, 1100);
        require(
            refundSale.refundPurchaseRecord(id).referencedGate == address(payment),
            "purchase gate captured"
        );
        refundManager.setGate(address(sale));
        _status(address(sale), ModuleRegistryStatus.INCIDENT_REVOKED);
        _unavailable(id, 5);
        _status(address(payment), ModuleRegistryStatus.INCIDENT_REVOKED);
        refundSale.unlockRefund(id, 5);
        require(
            refundSale.refundCredit(payer) == 1100 && refundManager.nonce() == 0,
            "saved module incident unlocks without mint/fund"
        );
    }

    function testRetainedModuleDeprecationAllowsFinalizeButBlocksNewPurchases() public {
        bytes32 id = _purchase(1, 1100);
        IStreamNativeRefundWindowSale.RefundPurchaseData memory next =
            _purchaseData(2, payer, payer);
        vm.warp(1001);
        _status(address(refundSale), ModuleRegistryStatus.DEPRECATED);
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamDeferredNativeSettlementAdmission.SettlementModuleNotAdmitted.selector,
                address(refundSale)
            )
        );
        refundSale.purchaseRefundWindow{ value: 1100 }(next);
        _atRefundEnd(id);
        refundSale.finalizeRefundWindow(id);
        require(
            wallet.balance == 1000 && refundManager.nonce() == 1,
            "prior lifecycle permits retained finalize"
        );
    }

    function _unavailable(bytes32 id, uint8 reason) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeRefundWindowSale.RefundUnlockNotAvailable.selector, id, reason
            )
        );
        refundSale.unlockRefund(id, reason);
    }
}
