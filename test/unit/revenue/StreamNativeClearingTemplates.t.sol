// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

contract ClearingPayoutReceiver is IERC721Receiver {
    RefundRuntimeArtist private immutable artists;
    address private immutable payout;

    constructor(RefundRuntimeArtist a, address p) {
        artists = a;
        payout = p;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        artists.setPayout(payout);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract StreamNativeClearingTemplatesTest is ClearingSaleTestBase {
    uint256[] private keys;
    OfficialSafe private first;
    OfficialSafe private second;

    function _template() private {
        keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0xB0B;
        SafeComponents memory components = deploySafeComponents("1.4.1");
        first = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 9971);
        second = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 9972);
        refundArtist = new DutchRuntimeArtist(address(core));
        artists = refundArtist;
        refundCore.setPointer(keccak256("ARTIST_REGISTRY"), address(artists));
        resolver = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(revenueAuthority),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200000, 50000, 2
            )
        );
        vm.prank(address(revenueAuthority));
        resolver.transferOwnership(address(this));
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 900000, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            vm.addr(PLATFORM_KEY), 0, 100000, keccak256("platform")
        );
        bytes32 tid = resolver.createPrimaryTemplate(entries, keccak256("clearing template terms"));
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, tid, 0);
        artists.accept(artist);
        refundArtist.setPayout(address(first));
        recorder = new StreamPrimarySaleSettlement(resolver, address(registry), escrow);
        _producer(true);
        clearingSale = new StreamNativeClearingSale(_clearingDeployment());
        _register(
            address(clearingSale),
            keccak256("NATIVE_PRIMARY_SALE_ADAPTER"),
            type(IStreamNativeSaleBinding).interfaceId
        );
        clearingId = clearingSale.registerClearingSale(_clearingConfig());
    }

    function _flushAndRelease(bytes32 id, address target, OfficialSafe safe, uint256 expected)
        private
    {
        escrow.flushEscrow(CLASS, id, target, address(0));
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(
            executeSafe(
                safe,
                keys,
                target,
                0,
                abi.encodeCall(
                    IStreamSplitWallet.release, (address(0), address(safe), payable(address(safe)))
                ),
                0
            ),
            "actual Safe wallet release"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++count;
        }
        require(
            count == 1 && safe.nonce() == nonce + 1
                && IStreamSplitWallet(target).accountReleased(address(0), address(safe))
                    == expected,
            "actual payout/event/accounting"
        );
    }

    function _templatePolicy() private view returns (bytes32) {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory assignment =
            resolver.resolvePrimaryAssignment(1, 0, CLASS);
        (bytes32 concreteProfile, address concreteWallet,) =
            resolver.previewCollectionPrimaryProfile(assignment.templateId, 1, address(0));
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                CLASS,
                uint256(1),
                uint256(0),
                assignment.templateId,
                concreteProfile,
                concreteWallet,
                assignment.assignmentHash
            )
        );
    }

    function testTemplateRegistrationOriginalFloorAndCurrentTokenFinancialRightsStayDistinct()
        external
    {
        _template();
        bytes32 baseline = clearingSale.saleRecord(clearingId).expectedPrimaryPolicyHash;
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        require(_templatePolicy() == baseline, "independent actual template baseline");
        d.authorization.expectedPrimaryPolicyHash = baseline;
        _signClearing(d);
        refundArtist.setPayout(address(second));
        bytes32 purchasePolicy = _templatePolicy();
        require(purchasePolicy != baseline, "new explicit designation changes concrete preview");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamNativeClearingSale.InvalidClearingSale.selector)
        );
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        d.authorization.expectedPrimaryPolicyHash = purchasePolicy;
        ClearingPayoutReceiver receiver = new ClearingPayoutReceiver(refundArtist, address(first));
        d.authorization.recipient = address(receiver);
        _signClearing(d);
        vm.prank(payer);
        IStreamNativeClearingSale.ClearingPurchaseResult memory p =
            clearingSale.purchase{ value: 1020 }(d);
        StreamPrimarySettlementTypes.PrimarySettlementResult memory floor =
            recorder.settlementResult(p.settlementKey);
        require(
            p.escrowed && escrow.escrowOwed(CLASS, floor.profileId, floor.wallet, address(0)) == 100
                && refundArtist.payout() == address(first),
            "floor retains materialization before NFT designation callback"
        );
        require(
            clearingSale.saleRecord(clearingId).expectedPrimaryPolicyHash == baseline
                && clearingSale.purchaseRecord(p.purchaseId).originalFloor.sale
                        .expectedPrimaryPolicyHash == purchasePolicy,
            "immutable baseline and original proof distinct"
        );
        vm.warp(1040);
        clearingSale.closeSale(clearingId);
        clearingSale.fixClearingPrice(clearingId);
        StreamNativeSupplementalTypes.NativeSupplementalResult memory leg =
            clearingSale.settlePurchaseSupplement(p.purchaseId);
        require(
            leg.escrowed && leg.profileId != floor.profileId && leg.wallet != floor.wallet
                && leg.originalExpectedPrimaryPolicyHash == purchasePolicy
                && leg.currentPrimaryPolicyHash != purchasePolicy && leg.policyDrift
                && leg.tokenId == p.tokenId && leg.originalOperationId == p.operationId
                && leg.amount == 540,
            "ALLOW_CURRENT token policy and old association preserved"
        );
        _flushAndRelease(floor.profileId, floor.wallet, second, 90);
        _flushAndRelease(leg.profileId, leg.wallet, first, 486);
        require(
            address(second).balance == 90 && address(first).balance == 486
                && escrow.totalOwed(address(0)) == 0 && clearingManager.nonce() == 1,
            "both historical and current immutable Safe rights payable, no second mint"
        );
        vm.prank(payer);
        clearingSale.claimRefund(clearingId, payer);
        require(
            clearingSale.totalBuyerLiabilities() == 0, "buyer rebate independent of payout revision"
        );
    }
}
