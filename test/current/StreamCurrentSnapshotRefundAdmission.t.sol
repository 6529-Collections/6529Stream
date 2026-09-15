// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/NativeRoyaltySnapshotFixture.sol";
import { StreamNativeRefundWindowSale } from "../../smart-contracts/domains/mint/StreamNativeRefundWindowSale.sol";
import { IStreamNativeRefundWindowSale } from "../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundWindowSale.sol";
import { IStreamDeferredNativeSaleBinding } from "../../smart-contracts/interfaces/stream/revenue/IStreamDeferredNativeSaleBinding.sol";

/// @dev Actual deposit consumer/Core/Manager/Registry/Resolver; Artist, entropy and governance
/// retain the explicit semantic boundaries of NativeRoyaltySnapshotFixture.
contract StreamCurrentSnapshotRefundAdmissionTest is NativeRoyaltySnapshotFixture {
    function testSnapshotRefundDepositRejectsBeforeLiabilityAndConfiguredPhaseCannotDowngrade() public {
        StreamNativeRefundWindowSale sale = _refundConsumer();
        bytes32 phaseId = keccak256("snapshot refund admission phase");
        _snapshotPhase(phaseId, 1, address(sale));
        bytes32 id = _refundListing(sale, phaseId);
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _refundAuthorization(sale, id);
        bytes memory originalCall = abi.encodeCall(sale.purchaseRefundWindow, (d));
        uint256 originalBalance = payer.balance;
        uint256 fee = entropy.collectionRevealPolicy(1).revealFeePerTokenWei;
        vm.prank(payer);
        (bool ok, bytes memory reason) = address(sale).call{value: 1000 + fee}(originalCall);
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(
            IStreamMintRoyaltyPolicy.PreparedRoyaltySnapshotRequired.selector, uint256(1))),
            "actual snapshot mode rejected before refund capture");
        _noRefundDeposit(sale, id, d, originalBalance);

        _selectLiveRoyalty();
        vm.prank(payer);
        (ok, reason) = address(sale).call{value: 1000 + fee}(originalCall);
        require(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(
            IStreamMintRoyaltyPolicy.InvalidMintRoyaltyPolicy.selector)),
            "original configured phase cannot downgrade through live replacement");
        _noRefundDeposit(sale, id, d, originalBalance);
    }

    function testLiveUnconfiguredRefundPhaseAcceptsDepositAndSnapshotSelectionCannotBlockExit() public {
        StreamNativeRefundWindowSale sale = _refundConsumer();
        _selectLiveRoyalty();
        manager.setPhaseExecutor(1, PHASE, address(sale), true);
        bytes32 id = _refundListing(sale, PHASE);
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _refundAuthorization(sale, id);
        bytes memory originalCall = abi.encodeCall(sale.purchaseRefundWindow, (d));
        uint256 originalBalance = payer.balance;
        uint256 fee = entropy.collectionRevealPolicy(1).revealFeePerTokenWei;
        vm.prank(payer);
        (bool ok, bytes memory returned) = address(sale).call{value: 1000 + fee}(originalCall);
        require(ok && returned.length == 32, "actual live unconfigured phase accepts original purchase");
        bytes32 purchase = abi.decode(returned, (bytes32));
        require(sale.refundPurchaseRecord(purchase).status == 1 && sale.totalBuyerLiabilities() == 1000 + fee
            && sale.totalPendingDeposits() == 1000 + fee && sale.nextPurchaseNonce(id, payer) == 2
            && sale.purchaseAuthorizationUsed(d.authorization.artist, d.authorization.nonce),
            "original deposit and replay accounting preserved");
        _pointer(keccak256("ROYALTY_RESOLVER"), address(royalty));
        snapshotArtist.setConsent(false);
        vm.prank(payer);
        sale.refundPurchase(purchase);
        require(sale.refundPurchaseRecord(purchase).status == 3 && sale.totalPendingDeposits() == 0
            && sale.refundableBalance(id, payer) == 1000 + fee, "refund ignores changed royalty and consent");
        vm.prank(payer);
        uint256 claimed = sale.claimRefund(id, payable(payer));
        require(claimed == 1000 + fee && payer.balance == originalBalance && address(sale).balance == 0
            && sale.totalBuyerLiabilities() == 0 && sale.nextPurchaseNonce(id, payer) == 2,
            "permanent pull exit preserves value and original nonce");
    }

    function _refundConsumer() private returns (StreamNativeRefundWindowSale sale) {
        StreamNativeRefundWindowSale.DeploymentConfig memory d;
        d.manager = manager; d.recorder = recorder; d.platform = vm.addr(AUCTION_PLATFORM_KEY);
        d.artists = artists; d.entropy = entropy; d.roles = auctionRoles; d.authority = address(revenueAuthority);
        d.parameters[0] = IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2);
        d.parameters[1] = IStreamGasParameterHost.GasParameterConfig("SALE_ARTIST_AUTHORITY_GAS_LIMIT", 300000, 50000, 2);
        d.parameters[2] = IStreamGasParameterHost.GasParameterConfig("REVEAL_ATTEMPT_GAS_LIMIT", 200000, 50000, 2);
        sale = new StreamNativeRefundWindowSale(d);
        _register(address(sale), keccak256("NATIVE_REFUND_WINDOW_SALE_ADAPTER"),
            type(IStreamDeferredNativeSaleBinding).interfaceId, keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"));
        require(address(sale).code.length <= 24576, "actual refund consumer fits EIP170");
    }

    function _refundListing(StreamNativeRefundWindowSale sale, bytes32 phaseId) private returns (bytes32) {
        uint64 observed = this.snapshotTime();
        return sale.registerRefundSale(IStreamNativeRefundWindowSale.RefundSaleConfig(
            1, phaseId, 1000, 10, observed, observed + 10000, 3600, 86400, 1, manager.phasePolicyHash(1, phaseId)));
    }

    function _refundAuthorization(StreamNativeRefundWindowSale sale, bytes32 id)
        private returns (IStreamNativeRefundWindowSale.RefundPurchaseData memory d)
    {
        IStreamNativeRefundWindowSale.RefundSaleRecord memory record = sale.refundSaleRecord(id);
        uint64 observed = this.snapshotTime();
        d.tokenData = bytes("snapshot incompatible refund artwork");
        d.authorization = IStreamNativeRefundWindowSale.RefundPurchaseAuthorization(
            id, record.configHash, payer, payer, vm.addr(SIGNER_KEY), keccak256(d.tokenData),
            keccak256("refund original mint commitment"), sale.nextPurchaseNonce(id, payer),
            keccak256("refund original commercial nonce"), 1000, observed + 3600, record.windowPolicyHash,
            observed + 90000, observed + 100000, StreamNativeEnglishAuctionSupport.profilePolicy(resolver, 1));
        bytes32 digest = sale.refundPurchaseAuthorizationDigest(d.authorization);
        d.platformSignature = _sig(AUCTION_PLATFORM_KEY, digest);
        d.artistSignature = _sig(SIGNER_KEY, digest);
    }

    function _selectLiveRoyalty() private {
        StreamRoyaltyResolver live = new StreamRoyaltyResolver(core, factory, address(revenueAuthority), artists);
        _register(address(live), keccak256("REVENUE_RESOLVER"), type(IStreamRoyaltyResolver).interfaceId, MANIFEST);
        _pointer(keccak256("ROYALTY_RESOLVER"), address(live));
    }

    function _noRefundDeposit(StreamNativeRefundWindowSale sale, bytes32 id,
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d, uint256 originalBalance) private view
    {
        require(payer.balance == originalBalance && address(sale).balance == 0 && sale.totalBuyerLiabilities() == 0
            && sale.totalPendingDeposits() == 0 && sale.refundSaleRecord(id).purchasedQuantity == 0
            && sale.nextPurchaseNonce(id, payer) == d.authorization.purchaseNonce
            && !sale.purchaseAuthorizationUsed(d.authorization.artist, d.authorization.nonce)
            && core.lastAllocatedTokenId() == 0 && manager.nextOperationNonce() == 0,
            "predeposit refusal leaves payment mint and both replay coordinates untouched");
    }
}
