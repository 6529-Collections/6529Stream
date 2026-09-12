// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

contract StreamNativeClearingLifecycleTest is ClearingSaleTestBase {
    function _registerRecorder() private {
        _register(
            address(recorder),
            keccak256("PRIMARY_SALE_SETTLEMENT"),
            type(IStreamPrimarySaleSettlement).interfaceId
        );
    }

    function blockRecorderDuringCallback() external {
        require(msg.sender == address(refundEntropy), "fixture callback caller");
        _status(address(recorder), ModuleRegistryStatus.INCIDENT_REVOKED);
    }

    function testKnownRecorderIncidentStopsPurchaseAndPendingLegWithSameProofAndLegRetries()
        external
    {
        _registerRecorder();
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        vm.warp(1001);
        _status(address(recorder), ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingRecorderIncident.selector, address(recorder)
            )
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        require(
            wallet.balance == 0 && clearingManager.nonce() == 0
                && clearingSale.nextPurchaseNonce(clearingId, payer) == 1,
            "known incident before effects"
        );
        _status(address(recorder), ModuleRegistryStatus.ACTIVE);
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory p =
            clearingSale.purchase{ value: 1020 }(d);
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        _status(address(recorder), ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingRecorderIncident.selector, address(recorder)
            )
        );
        clearingSale.settlePurchaseSupplement(p.purchaseId);
        require(
            wallet.balance == 100 && clearingSale.totalBuyerLiabilities() == 900
                && !recorder.supplementalPurchaseConsumed(
                    recorder.supplementalPurchaseKey(address(clearingSale), p.purchaseId)
                ),
            "pending leg and excess unaffected"
        );
        _status(address(recorder), ModuleRegistryStatus.ACTIVE);
        clearingSale.settlePurchaseSupplement(p.purchaseId);
        require(
            wallet.balance == 640 && clearingSale.totalBuyerLiabilities() == 360
                && clearingManager.nonce() == 1,
            "same financial identity after authorized registry restoration"
        );
    }

    function testLateFeeCallbackRecorderIncidentRollsBackRegistryAndEntirePurchaseThenRetries()
        external
    {
        _registerRecorder();
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        refundEntropy.setCallback(
            address(this), abi.encodeCall(this.blockRecorderDuringCallback, ())
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingRecorderIncident.selector, address(recorder)
            )
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        require(
            registry.moduleRecord(address(recorder)).status == ModuleRegistryStatus.ACTIVE
                && wallet.balance == 0 && clearingManager.nonce() == 0
                && refundEntropy.revealFeeEscrow(1) == 0
                && clearingSale.totalBuyerLiabilities() == 0,
            "actual registry callback and all money reverted"
        );
        refundEntropy.setCallback(address(0), "");
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        require(
            wallet.balance == 100 && clearingSale.totalBuyerLiabilities() == 900,
            "same proof healthy callback control"
        );
    }

    function testRecorderIncidentUnlockAndClaimsRemainLiveWithoutRestoration() external {
        _registerRecorder();
        _buy(1, 1027);
        vm.warp(1001);
        _status(address(recorder), ModuleRegistryStatus.INCIDENT_REVOKED);
        vm.prank(payer); // OPEN excess, independent of recorder.
        clearingSale.claimRefund(clearingId, payer);
        clearingSale.unlockRefunds(clearingId, 2);
        require(
            clearingSale.refundableBalance(clearingId, payer) == 900,
            "typed actual recorder incident unlock"
        );
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        require(
            clearingSale.totalBuyerLiabilities() == 0 && wallet.balance == 100
                && registry.moduleRecord(address(recorder)).status
                    == ModuleRegistryStatus.INCIDENT_REVOKED,
            "credit exit never requires restoring incident module"
        );
    }

    function testDeprecatedOldSaleStillWorksNewConfigurationRejectsAndBoundAttributionUnlockIsExact()
        external
    {
        vm.warp(1001);
        _status(address(clearingSale), ModuleRegistryStatus.DEPRECATED);
        IStreamNativeClearingSale.ClearingSaleConfig memory config = _clearingConfig();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamNativeSettlementAdmission.SettlementModuleNotAdmitted.selector,
                address(clearingSale)
            )
        );
        clearingSale.registerClearingSale(config);
        _buy(1, 1020);
        require(wallet.balance == 100, "prior registered sale remains admitted");
        refundArtist.setAssociation(
            4, 2, keccak256("refund artist identity"), 1, keccak256("refund artist binding")
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamNativeClearingSale.ClearingUnlockUnavailable.selector, clearingId, uint8(1)
            )
        );
        clearingSale.unlockRefunds(clearingId, 1);
        refundArtist.setAssociation(
            4, 1, keccak256("refund artist identity"), 1, keccak256("refund artist binding")
        );
        clearingSale.unlockRefunds(clearingId, 1);
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        require(
            wallet.balance == 100 && clearingSale.totalBuyerLiabilities() == 0,
            "only exact saved association stopped, UNKNOWN recorder profile not changed"
        );
    }
}
