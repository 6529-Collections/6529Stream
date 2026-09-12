// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamClearingSaleState.sol";
import "./StreamNativePriceProgram.sol";
import "./StreamClearingUnlock.sol";
import "../revenue/StreamNativeSettlementAdmission.sol";

/// @notice Typed purchase and supplemental execution, invoked through the guarded consumer's links.
/// @dev Direct CALL to mutable library functions rejects; delegatecall preserves consumer and caller.
library StreamClearingSaleExecution {
    event SalePaymentExcessCredited(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed payer, uint256 amount
    );
    event SaleConsentRecorded(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 saleConfigHash,
        bytes32 consentEvidenceHash
    );
    event ClearingPurchaseCompleted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed purchaseId,
        address indexed payer,
        IStreamNativeClearingSale.ClearingPurchaseResult result,
        bool hasPriceOverride,
        uint256 priceOverride,
        uint256 purchaseNonce
    );
    event ClearingFinancialLegCompleted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed purchaseId,
        StreamNativeSupplementalTypes.NativeSupplementalResult result
    );

    function purchase(
        StreamClearingSaleState.State storage state,
        StreamClearingSaleState.Context memory x,
        IStreamNativeClearingSale.ClearingPurchaseData calldata d
    ) public returns (IStreamNativeClearingSale.ClearingPurchaseResult memory result) {
        _requireContext(x);
        IStreamNativeClearingSale.ClearingAuthorization memory a = d.authorization;
        if (StreamClearingSaleState.isPaused(state, a.saleId)) {
            revert IStreamNativeClearingSale.ClearingEntryPaused();
        }
        if (state.authorizationUsed[a.artist][a.nonce]) {
            revert IStreamNativeClearingSale.ClearingAuthorizationUsed(a.artist, a.nonce);
        }
        if (state.executionIdByNonce[a.saleId][a.executionNonce] != 0) {
            revert IStreamNativeClearingSale.ClearingExecutionUsed(a.saleId, a.executionNonce);
        }
        StreamClearingSaleSupport.Prepared memory p = StreamClearingSaleSupport.prepare(
            x.support, state.sales[a.saleId], state.financial.sales[a.saleId], d
        );
        if (msg.sender != a.payer || msg.sender != a.executor) {
            revert IStreamNativeClearingSale.InvalidClearingSale();
        }
        uint256 fee = p.captured.reveal.revealFeePerTokenWei;
        if (msg.value < fee) {
            revert IStreamNativeClearingSale.SaleRevealFeeBelowRequired(msg.value, fee);
        }
        uint256 maximum = msg.value - fee;
        if (maximum < p.chargedPrice) {
            revert IStreamNativeClearingSale.ClearingPriceAboveMaximum(maximum, p.chargedPrice);
        }
        uint256 original = address(this).balance - msg.value;
        if (original < state.financial.totalBuyerLiability) {
            revert IStreamNativeClearingSale.ClearingAccountingMismatch();
        }
        StreamNativeSettlementAdmission.requireAdmission(x.registry, p.floor);
        uint256 revealCap = x.revealCap;
        StreamDutchSaleSupport.preflightReveal(p.captured.reveal.requestMode, revealCap);
        result.purchaseId = _purchaseId(a.saleId, a.payer, a.purchaseNonce);
        result.chargedAmount = p.chargedPrice;
        result.floorRevenue = p.floor.sale.amount;
        result.heldOverage = p.chargedPrice - result.floorRevenue;
        result.revealFeeForwarded = fee;
        result.excessCredited = maximum - p.chargedPrice;
        result.executionId = p.floor.executionBinding.executionId;
        result.operationRoot = p.floor.operationIdentityCommitment;
        result.operationId = p.floor.operationId;
        state.authorizationUsed[a.artist][a.nonce] = true;
        state.executionIdByNonce[a.saleId][a.executionNonce] = result.executionId;
        state.executionStatus[result.executionId] = 1;
        StreamClearingSaleBook.record(
            state.financial,
            StreamClearingSaleBook.PurchaseInput(
                a.saleId,
                result.purchaseId,
                a.payer,
                a.purchaseNonce,
                p.schedulePrice,
                p.chargedPrice,
                a.hasPriceOverride,
                a.priceOverride,
                result.excessCredited
            )
        );
        IStreamNativeClearingSale.ClearingSaleRecord storage sale = state.sales[a.saleId];
        if (sale.artistId == 0) {
            sale.artistId = p.captured.association.artistId;
            sale.bindingGeneration = p.captured.association.generation;
            sale.bindingHash = p.captured.association.bindingHash;
        }
        if (state.financial.sales[a.saleId].purchasedQuantity == sale.config.maxSaleQuantity) {
            sale.soldOutAt = StreamClearingClock.now64();
        }
        StreamPrimarySettlementTypes.PrimarySettlementResult memory floorResult =
            StreamNativePriceProgram.settle(x.recorder, p.floor);
        result.settlementKey = floorResult.settlementKey;
        result.escrowed = floorResult.escrowed;
        _requirePurchaseRetained(state, x, p.floor, p.captured.association);
        result.tokenId = _mint(x, p);
        _requirePurchaseRetained(state, x, p.floor, p.captured.association);
        StreamDutchSaleSupport.fundCapturedReveal(
            x.support, sale.config.collectionId, result.tokenId, p.captured.reveal, revealCap
        );
        _requirePurchaseRetained(state, x, p.floor, p.captured.association);
        state.purchases[result.purchaseId] = IStreamNativeClearingSale.ClearingPurchaseRecord(
            p.floor,
            floorResult.settlementKey,
            floorResult.candidateCommitment,
            result.tokenId,
            a.purchaseNonce,
            StreamClearingClock.now64(),
            a.hasPriceOverride,
            a.priceOverride
        );
        if (address(this).balance != original + result.heldOverage + result.excessCredited) {
            revert IStreamNativeClearingSale.ClearingAccountingMismatch();
        }
        state.executionStatus[result.executionId] = 2;
        _emitPurchase(state, a, result, p.captured.consentEvidence);
    }

    function _mint(
        StreamClearingSaleState.Context memory x,
        StreamClearingSaleSupport.Prepared memory p
    ) private returns (uint256) {
        (uint256[] memory tokens, bytes32 root, bytes32[] memory ids) =
            x.support.manager.executeSingleStepMint(p.batch, "");
        if (
            tokens.length != 1 || tokens[0] == 0 || root != p.floor.operationIdentityCommitment
                || ids.length != 1 || ids[0] != p.floor.operationId
        ) revert IStreamNativeClearingSale.ClearingMintResultInvalid();
        return tokens[0];
    }

    function _emitPurchase(
        StreamClearingSaleState.State storage state,
        IStreamNativeClearingSale.ClearingAuthorization memory a,
        IStreamNativeClearingSale.ClearingPurchaseResult memory result,
        bytes32 evidence
    ) private {
        if (result.excessCredited != 0) {
            emit SalePaymentExcessCredited(1, a.saleId, a.payer, result.excessCredited);
        }
        if (evidence != 0) {
            emit SaleConsentRecorded(
                1,
                a.saleId,
                state.sales[a.saleId].config.collectionId,
                state.sales[a.saleId].configHash,
                evidence
            );
        }
        emit ClearingPurchaseCompleted(
            1,
            a.saleId,
            result.purchaseId,
            a.payer,
            result,
            a.hasPriceOverride,
            a.priceOverride,
            a.purchaseNonce
        );
    }

    function settlePurchaseSupplement(
        StreamClearingSaleState.State storage state,
        StreamClearingSaleState.Context memory x,
        bytes32 purchaseId
    ) public returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory result) {
        if (state.supplementalResults[purchaseId].settlementKey != 0) {
            return state.supplementalResults[purchaseId];
        }
        IStreamNativeClearingSale.ClearingPurchaseRecord storage p = state.purchases[purchaseId];
        if (p.tokenId == 0) {
            revert IStreamNativeClearingSale.ClearingPurchaseUnavailable(purchaseId);
        }
        bytes32 id = p.originalFloor.sale.settlementId;
        if (StreamClearingSaleState.isPaused(state, id)) {
            revert IStreamNativeClearingSale.ClearingEntryPaused();
        }
        (,, uint64 deadline,) = StreamClearingSaleState.deadlines(state, id);
        if (block.timestamp > deadline) {
            revert IStreamNativeClearingSale.ClearingFinalizeExpired(deadline);
        }
        _requireContext(x);
        _requireFinancialAuthority(state, x, id);
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c;
        c.originalFloor = p.originalFloor;
        c.purchaseId = purchaseId;
        c.executor = msg.sender;
        c.purchase = StreamClearingSaleState.purchaseFacts(state, purchaseId);
        (c.currentRights, c.currentPrimaryPolicyHash) =
            StreamClearingSaleSupport.currentSupplementalRights(
                StreamPrimarySettlementRights.Context(
                    x.support.resolver, x.factory, x.factory.splitWalletRuntimeCodeHash()
                ),
                p.originalFloor.sale.collectionId,
                p.tokenId
            );
        uint256 beforeBalance = address(this).balance;
        if (beforeBalance < state.financial.totalBuyerLiability) {
            revert IStreamNativeClearingSale.ClearingAccountingMismatch();
        }
        uint256 amount = StreamClearingSaleBook.beginSupplement(state.financial, purchaseId);
        state.activeCandidate = StreamNativeSupplementalHash.candidateCommitment(x.recorder, c);
        result = StreamClearingSaleSupport.settleSupplement(x.recorder, c);
        _requireContext(x);
        _requireFinancialAuthority(state, x, id);
        if (address(this).balance != beforeBalance - amount) {
            revert IStreamNativeClearingSale.ClearingAccountingMismatch();
        }
        StreamClearingSaleBook.finishSupplement(state.financial, purchaseId);
        state.activeCandidate = 0;
        state.supplementalResults[purchaseId] = result;
        if (state.financial.sales[id].status == 3) {
            StreamClearingSaleState.freezeTerminalClock(state, id);
        }
        emit ClearingFinancialLegCompleted(1, id, purchaseId, result);
    }

    function _requirePurchaseRetained(
        StreamClearingSaleState.State storage state,
        StreamClearingSaleState.Context memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
        StreamDutchSaleSupport.ArtistAssociation memory association
    ) private view {
        _requireContext(x);
        StreamNativeSettlementAdmission.requireAdmission(x.registry, c);
        StreamDutchSaleSupport.requireSaleConsent(
            x.support,
            c.sale.collectionId,
            c.sale.settlementId,
            state.sales[c.sale.settlementId].configHash
        );
        StreamDutchSaleSupport.requireArtistAssociation(
            x.support,
            c.sale.collectionId,
            association.artistId,
            association.generation,
            association.bindingHash
        );
        StreamNativeSettlementSupport.requireCurrent(
            x.support.resolver,
            c.sale.collectionId,
            StreamSaleTemplate.Selection(
                c.rights.profileId,
                c.rights.wallet,
                c.rights.templateId,
                c.rights.assignmentHash,
                c.rights.entriesHash
            )
        );
    }

    function _requireFinancialAuthority(
        StreamClearingSaleState.State storage state,
        StreamClearingSaleState.Context memory x,
        bytes32 id
    ) private view {
        IStreamNativeClearingSale.ClearingSaleRecord storage sale = state.sales[id];
        StreamDutchSaleSupport.requireSaleConsent(
            x.support, sale.config.collectionId, id, sale.configHash
        );
        StreamDutchSaleSupport.requireArtistAssociation(
            x.support,
            sale.config.collectionId,
            sale.artistId,
            sale.bindingGeneration,
            sale.bindingHash
        );
    }

    function _purchaseId(bytes32 saleId, address payer, uint256 nonce)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                address(this),
                saleId,
                payer,
                nonce
            )
        );
    }

    function _requireContext(StreamClearingSaleState.Context memory x) private view {
        StreamSettlementAdmission.requireRegistry(
            x.support.core, x.coreHash, x.registry, x.registryHash
        );
        if (
            address(x.support.resolver).codehash != x.resolverHash
                || address(x.factory).codehash != x.factoryHash
                || address(x.support.manager).codehash != x.managerHash
                || x.recorder.codehash != x.recorderHash
        ) {
            revert IStreamNativeClearingSale.InvalidClearingSale();
        }
        StreamClearingUnlock.requireRecorderNotIncident(x.registry, x.recorder);
    }
    event SaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint8 saleKind,
        address asset,
        bytes32 saleConfigHash,
        bytes32 expectedPrimaryPolicyHash,
        uint8 primaryPolicyMode
    );
    event ClearingSaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 saleNonce,
        bytes32 priceScheduleHash,
        bytes32 windowPolicyHash,
        IStreamNativeClearingSale.ClearingSaleConfig config
    );
    event ClearingRefundClaimed(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed payer,
        address indexed recipient,
        uint256 amount
    );
    event DutchRebateCredited(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed payer, uint256 amount
    );

    function registerClearingSale(
        StreamClearingSaleState.State storage state,
        StreamClearingSaleState.Context memory x,
        IStreamNativeClearingSale.ClearingSaleConfig memory config,
        uint256 nonce
    ) public returns (bytes32 id) {
        _requireContext(x);
        bytes32 baseline = StreamClearingSaleSupport.validateConfig(x.support, config);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamNativeSettlementAdmission.capture(x.registry, address(this));
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(4),
                config.collectionId,
                config.phaseId,
                nonce
            )
        );
        bytes32 schedule =
            StreamDutchPricing.scheduleHash(config.schedule, block.chainid, address(this), id);
        bytes32 windows = StreamClearingSaleSupport.windowPolicyHash(config);
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLEARING_CONFIG_V1"),
                id,
                config,
                schedule,
                windows,
                baseline,
                address(0)
            )
        );
        IStreamNativeClearingSale.ClearingSaleRecord storage sale = state.sales[id];
        sale.config = config;
        sale.saleNonce = nonce;
        sale.configHash = hash;
        sale.priceScheduleHash = schedule;
        sale.windowPolicyHash = windows;
        sale.expectedPrimaryPolicyHash = baseline;
        sale.lifecycle = lifecycle;
        StreamClearingSaleBook.configure(
            state.financial,
            id,
            config.schedule.startPrice,
            config.schedule.restingPrice,
            config.maxSaleQuantity
        );
        emit SaleConfigured(
            1, id, config.collectionId, config.phaseId, 4, address(0), hash, baseline, 1
        );
        emit ClearingSaleConfigured(1, id, nonce, schedule, windows, config);
    }

    function claimRefund(StreamClearingSaleState.State storage state, bytes32 id, address recipient)
        public
        returns (uint256 amount)
    {
        if (recipient == address(0) || recipient == address(this)) {
            revert IStreamNativeClearingSale.ClearingTransferFailed(recipient);
        }
        amount = StreamClearingSaleBook.refundableBalance(state.financial, id, msg.sender);
        if (amount == 0) revert IStreamNativeClearingSale.ClearingCreditEmpty(id, msg.sender);
        uint256 beforeBalance = address(this).balance;
        if (beforeBalance < state.financial.totalBuyerLiability) {
            revert IStreamNativeClearingSale.ClearingAccountingMismatch();
        }
        announceRebate(state, id, msg.sender);
        StreamClearingSaleBook.debitClaim(state.financial, id, msg.sender, amount);
        (bool ok,) = recipient.call{ value: amount }("");
        if (!ok) revert IStreamNativeClearingSale.ClearingTransferFailed(recipient);
        if (address(this).balance != beforeBalance - amount) {
            revert IStreamNativeClearingSale.ClearingAccountingMismatch();
        }
        emit ClearingRefundClaimed(1, id, msg.sender, recipient, amount);
    }

    function announceRebate(StreamClearingSaleState.State storage state, bytes32 id, address payer)
        public
        returns (uint256 amount)
    {
        amount = StreamClearingSaleBook.announceRebate(state.financial, id, payer);
        if (amount != 0) emit DutchRebateCredited(1, id, payer, amount);
    }
}
