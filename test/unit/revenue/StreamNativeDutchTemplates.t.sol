// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/DutchSaleTestBase.sol";

contract DutchPayoutReceiver {
    RefundRuntimeArtist public artists;
    address public next;

    constructor(RefundRuntimeArtist a, address n) {
        artists = a;
        next = n;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        artists.setPayout(next);
        return 0x150b7a02;
    }
}

contract StreamNativeDutchTemplatesTest is DutchSaleTestBase {
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
        refundArtist = new DutchRuntimeArtist(address(core));
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
        dutchSale = new StreamNativeDutchSale(_deployment());
        _register(
            address(dutchSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId
        );
        dutchId = dutchSale.registerDutchSale(_dutchConfig());
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

    function testTemplatePolicyBaselineIsHistoryAndFreshSignedPreviewControlsExecution() public {
        _templateFixture();
        bytes32 baseline = dutchSale.saleRecord(dutchId).expectedPrimaryPolicyHash;
        bytes32 assignment = dutchSale.saleRecord(dutchId).primaryAssignmentHash;
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, payer);
        refundArtist.setPayout(address(secondSafe));
        bytes32 current = StreamSaleTemplate.policyHash(
            resolver, 1, StreamNativeSettlementSupport.rights(resolver, 1)
        );
        require(
            current != baseline
                && resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash == assignment,
            "same template assignment but new explicit payout"
        );
        vm.expectRevert(abi.encodeWithSelector(IStreamNativeDutchSale.InvalidDutchSale.selector));
        vm.prank(payer);
        dutchSale.purchase{ value: 1100 }(d);
        require(recorder.totalOfficialSettled(address(0)) == 0, "old concrete proof cannot float");
        d.authorization.expectedPrimaryPolicyHash = current;
        _signDutch(d);
        vm.prank(payer);
        IStreamNativeDutchSale.DutchPurchaseResult memory r = dutchSale.purchase{ value: 1100 }(d);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory settled =
            recorder.settlementResult(r.settlementKey);
        require(
            r.escrowed && dutchSale.saleRecord(dutchId).expectedPrimaryPolicyHash == baseline
                && d.authorization.expectedPrimaryPolicyHash != baseline,
            "baseline not relabeled as execution policy"
        );
        _releaseSafe(settled, secondSafe);
        require(
            address(secondSafe).balance == 900 && address(firstSafe).balance == 0,
            "freshly authorized current Safe payout"
        );
    }

    function testPostMaterializationPayoutCallbackKeepsOriginalSafeRightsAndFutureNewWallet()
        public
    {
        _templateFixture();
        StreamSaleTemplate.Selection memory beforeMint =
            StreamNativeSettlementSupport.rights(resolver, 1);
        DutchPayoutReceiver receiver = new DutchPayoutReceiver(refundArtist, address(secondSafe));
        IStreamNativeDutchSale.DutchPurchaseData memory d = _dutchData(1, payer, address(receiver));
        vm.prank(payer);
        IStreamNativeDutchSale.DutchPurchaseResult memory r = dutchSale.purchase{ value: 1100 }(d);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory settled =
            recorder.settlementResult(r.settlementKey);
        require(
            settled.profileId == beforeMint.profileId && settled.wallet == beforeMint.wallet
                && refundArtist.payout() == address(secondSafe),
            "callback does not redirect execution"
        );
        _releaseSafe(settled, firstSafe);
        d = _dutchData(2, payer, payer);
        vm.prank(payer);
        r = dutchSale.purchase{ value: 1100 }(d);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory second =
            recorder.settlementResult(r.settlementKey);
        require(
            second.profileId != settled.profileId && second.wallet != settled.wallet,
            "next execution observes new designation"
        );
        _releaseSafe(second, secondSafe);
        require(
            address(firstSafe).balance == 900 && address(secondSafe).balance == 900
                && recorder.totalOfficialSettled(address(0)) == 2000
                && escrow.totalOwed(address(0)) == 0,
            "both immutable real Safe payouts remain payable"
        );
    }
}
