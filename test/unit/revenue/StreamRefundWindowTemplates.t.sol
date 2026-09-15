// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRefundWindowCallbacks.t.sol";

contract StreamRefundWindowTemplatesTest is RefundWindowTestBase {
    OfficialSafe private firstSafe;
    OfficialSafe private secondSafe;
    uint256[] private keys;

    function _templateFixture() private {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        SafeComponents memory components = deploySafeComponents("1.4.1");
        firstSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 9901);
        secondSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 9902);
        refundCore = new RefundRuntimeCore();
        core = UniversalCoreMock(address(refundCore));
        refundArtist = new RefundRuntimeArtist(address(core));
        artists = refundArtist;
        refundEntropy = new RefundRuntimeEntropy(address(core));
        refundCore.setPointer(keccak256("ARTIST_REGISTRY"), address(artists));
        refundCore.setPointer(keccak256("MODULE_REGISTRY"), address(registry));
        refundCore.setPointer(keccak256("ENTROPY_COORDINATOR"), address(refundEntropy));
        refundManager = new RefundRuntimeManager(address(core), address(registry));
        manager = UniversalManagerMock(address(refundManager));
        resolver = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(revenueAuthority),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        vm.prank(address(revenueAuthority));
        resolver.transferOwnership(address(this));
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 900_000, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            vm.addr(PLATFORM_KEY), 0, 100_000, keccak256("platform")
        );
        bytes32 templateId =
            resolver.createPrimaryTemplate(entries, keccak256("refund template terms"));
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, templateId, 0);
        artists.accept(artist);
        refundArtist.setPayout(address(firstSafe));
        recorder = new StreamPrimarySaleSettlement(resolver, address(registry), escrow);
        _producer(true);
        refundSale = new StreamNativeRefundWindowSale(_deployment());
        _register(
            address(refundSale),
            keccak256("NATIVE_REFUND_WINDOW_SALE_ADAPTER"),
            type(IStreamDeferredNativeSaleBinding).interfaceId
        );
        refundId = refundSale.registerRefundSale(_refundConfig());
    }

    function testDeferredTemplateMaterializesAtFinalizeAndBothSafePayoutWalletsRemainPayable()
        public
    {
        _templateFixture();
        uint256 profiles = factory.profileCount();
        StreamSaleTemplate.Selection memory initial =
            StreamNativeSettlementSupport.rights(resolver, 1);
        require(
            !factory.profileExists(initial.profileId) && initial.wallet.code.length == 0,
            "preview does not register or deploy"
        );
        bytes32 id = _purchase(1, 1100);
        require(
            factory.profileCount() == profiles && recorder.totalOfficialSettled(address(0)) == 0,
            "purchase keeps template unmaterialized"
        );
        refundArtist.setPayout(address(secondSafe));
        _atRefundEnd(id);
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory r =
            refundSale.finalizeRefundWindow(id);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory first =
            recorder.settlementResult(r.settlementKey);
        require(
            first.escrowed && first.wallet.code.length == 0 && first.profileId != initial.profileId
                && !factory.profileExists(initial.profileId),
            "current finalization payout selected under signed ALLOW_CURRENT"
        );
        require(
            factory.profileCount() == profiles + 1
                && escrow.escrowOwed(CLASS, first.profileId, first.wallet, address(0)) == 1000,
            "exact registered template credit"
        );
        bytes32 secondId = _purchase(2, 1100);
        refundArtist.setPayout(address(firstSafe));
        _atRefundEnd(secondId);
        r = refundSale.finalizeRefundWindow(secondId);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory second =
            recorder.settlementResult(r.settlementKey);
        require(
            second.profileId == initial.profileId && second.profileId != first.profileId
                && factory.profileCount() == profiles + 2,
            "later materialization creates separate immutable rights"
        );
        _releaseSafe(first, secondSafe);
        _releaseSafe(second, firstSafe);
        require(
            address(firstSafe).balance == 900 && address(secondSafe).balance == 900
                && escrow.totalOwed(address(0)) == 0
                && recorder.totalOfficialSettled(address(0)) == 2000,
            "both actual Safe payout rights survive designation changes"
        );
    }

    function testRegistrationPurchaseAndFinalizationKeepThreeDistinctTemplatePolicyObservations()
        public
    {
        _templateFixture();
        bytes32 baseline = refundSale.refundSaleRecord(refundId).expectedPrimaryPolicyHash;
        uint256 profiles = factory.profileCount();
        refundArtist.setPayout(address(0xC0FFEE));
        bytes32 id = _purchase(1, 1100);
        bytes32 original =
            refundSale.refundPurchaseRecord(id).authorization.expectedPrimaryPolicyHash;
        require(
            original != baseline && factory.profileCount() == profiles,
            "lawful pre-purchase revision neither relabels baseline nor materializes"
        );
        refundArtist.setPayout(address(secondSafe));
        StreamSaleTemplate.Selection memory current =
            StreamNativeSettlementSupport.rights(resolver, 1);
        bytes32 currentPolicy = StreamSaleTemplate.policyHash(resolver, 1, current);
        _atRefundEnd(id);
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory r =
            refundSale.finalizeRefundWindow(id);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result =
            recorder.settlementResult(r.settlementKey);
        require(
            currentPolicy != baseline && currentPolicy != original
                && refundSale.refundSaleRecord(refundId).expectedPrimaryPolicyHash == baseline
                && refundSale.refundPurchaseRecord(id).authorization.expectedPrimaryPolicyHash
                    == original && result.profileId == current.profileId
                && result.wallet == current.wallet
                && recorder.totalOfficialSettled(address(0)) == 1000,
            "three immutable observations and current concrete rights"
        );
    }

    function testTemplateCallbackRevisionCannotRedirectAlreadyMaterializedSettlement() public {
        _templateFixture();
        RefundWindowReceiver receiver = new RefundWindowReceiver();
        receiver.configure(
            false,
            address(refundArtist),
            abi.encodeCall(RefundRuntimeArtist.setPayout, (address(secondSafe))),
            address(0)
        );
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d =
            _purchaseData(1, payer, address(receiver));
        vm.prank(payer);
        bytes32 id = refundSale.purchaseRefundWindow{ value: 1100 }(d);
        StreamSaleTemplate.Selection memory beforeMint =
            StreamNativeSettlementSupport.rights(resolver, 1);
        _atRefundEnd(id);
        IStreamNativeRefundWindowSale.RefundFinalizationResult memory r =
            refundSale.finalizeRefundWindow(id);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory settled =
            recorder.settlementResult(r.settlementKey);
        require(
            receiver.success() && refundArtist.payout() == address(secondSafe)
                && settled.profileId == beforeMint.profileId && settled.wallet == beforeMint.wallet,
            "callback cannot re-resolve this concrete payout"
        );
        require(
            StreamNativeSettlementSupport.rights(resolver, 1).profileId != settled.profileId,
            "next preview sees later lawful designation"
        );
        _releaseSafe(settled, firstSafe);
        require(
            address(firstSafe).balance == 900 && address(secondSafe).balance == 0,
            "materialization moment preserves actual Safe recipient"
        );
    }

    function _releaseSafe(
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r,
        OfficialSafe account
    ) private {
        escrow.flushEscrow(CLASS, r.profileId, r.wallet, address(0));
        uint256 nonce = account.nonce();
        require(
            executeSafe(
                account,
                keys,
                r.wallet,
                0,
                abi.encodeCall(
                    IStreamSplitWallet.release,
                    (address(0), address(account), payable(address(account)))
                ),
                0
            ),
            "actual Safe direct release"
        );
        require(
            account.nonce() == nonce + 1
                && IStreamSplitWallet(r.wallet).accountReleased(address(0), address(account))
                    == 900,
            "actual native split payout and accounting"
        );
    }
}
