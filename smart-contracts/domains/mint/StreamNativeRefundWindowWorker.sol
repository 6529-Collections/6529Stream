// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRefundWindowBookStore.sol";
import "./StreamRefundWindowSupport.sol";
import "../revenue/StreamDeferredNativeSettlementAdmission.sol";

/// @notice Fixed registration and purchase capture in the guarded refund consumer's context.
/// @dev The host supplies its typed book and immutable bindings after its context checks.
///      No independent owner, custody or arbitrary call target is introduced.
library StreamNativeRefundWindowWorker {
    function registerSale(
        StreamRefundWindowBookStore.State storage book,
        StreamRefundWindowSupport.Context memory context,
        address registry,
        IStreamNativeRefundWindowSale.RefundSaleConfig memory config,
        IStreamNativeAllowlistRefundWindowSale.AllowlistPricePolicy memory policy,
        uint256 nonce
    ) public returns (bytes32 id) {
        if (policy.counterId != 0) {
            StreamMintSaleAllowlist.validatePolicy(
                address(context.manager), config.collectionId, config.phaseId, policy.counterId
            );
        }
        bytes32 baseline = StreamRefundWindowSupport.validateConfig(context, config);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamDeferredNativeSettlementAdmission.capture(registry, address(this));
        // No dependency callbacks follow capture; the host advances its nonce on return.
        bytes32 window = StreamRefundWindowSupport.windowPolicyHash(config);
        if (policy.counterId == 0) {
            return StreamRefundWindowBookStore.configure(
                book, config, lifecycle, nonce, window, baseline
            );
        }
        return StreamRefundWindowBookStore.configureAllowlist(
            book, config, lifecycle, nonce, window, baseline, policy
        );
    }

    function purchase(
        StreamRefundWindowBookStore.State storage book,
        StreamRefundWindowSupport.Context memory context,
        address registry,
        IStreamNativeRefundWindowSale.RefundPurchaseData calldata data,
        bytes memory resolverData
    ) public returns (bytes32 id) {
        bytes32 saleId = data.authorization.saleId;
        IStreamNativeRefundWindowSale.RefundSaleRecord storage sale = book._refundSales[saleId];
        if (sale.saleNonce == 0) {
            revert IStreamNativeRefundWindowSale.RefundSaleUnavailable(saleId);
        }
        if (book._globalPause.paused || book._salePause[saleId].paused) {
            revert IStreamNativeRefundWindowSale.SaleEntryPaused();
        }
        StreamRefundWindowSupport.requireSaleConsent(
            context, sale.config.collectionId, saleId, sale.configHash
        );
        // New deposits retain ACTIVE admission; saved finalization has its original rules.
        StreamDeferredNativeSettlementAdmission.capture(registry, address(this));
        bool priced = StreamRefundWindowPriceStore.policy(saleId).counterId != 0;
        bytes32 digest;
        StreamRefundWindowSupport.ArtistAssociation memory association;
        uint256 fee;
        uint256 charge;
        if (priced) {
            (digest, association, fee, charge) = StreamRefundWindowSupport.validateAllowlistPurchase(
                context, sale, data, resolverData
            );
        } else {
            (digest, association, fee) =
                StreamRefundWindowSupport.validatePurchase(context, sale, data);
        }
        IStreamNativeRefundWindowSale.PurchaseCapture memory facts =
            IStreamNativeRefundWindowSale.PurchaseCapture(
                fee,
                association.artistId,
                association.generation,
                association.bindingHash,
                IStreamMintReads(address(context.manager))
                .phaseGate(sale.config.collectionId, sale.config.phaseId)
                .gate
            );
        if (priced) {
            return StreamRefundWindowBookStore.captureAllowlistPurchase(
                book, data, digest, facts, charge, resolverData
            );
        }
        return StreamRefundWindowBookStore._capturePurchase(book, data, digest, facts);
    }
}
