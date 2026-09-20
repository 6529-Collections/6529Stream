// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamNativeClaimSales as C
} from "../../interfaces/stream/mint/IStreamNativeClaimSales.sol";
import {
    IStreamNativeImmediateSales as S
} from "../../interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import { StreamNativeClaimSalesState } from "./StreamNativeClaimSalesState.sol";
import "./StreamNativeImmediateSalesRuntime.sol";
import "./StreamCanonicalSaleAuthorization.sol";

/// @notice Fixed typed pricing and mint preparation for canonical free and chosen-price claims.
/// @dev Zero outcomes retain mint authority but do not enter any paid settlement boundary.
library StreamNativeClaimSalesRuntime {
    event ClaimSaleRegistered(
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        uint256 saleNonce,
        C.Configuration config
    );

    event ImmediateSalePause(
        bytes32 indexed saleId, bool paused, address actor, bytes32 reasonHash
    );

    function setGlobalPause(
        StreamNativeImmediateSalesState.State storage state,
        address roles,
        bytes32 rolesCodeHash,
        address authority,
        bool value,
        bytes32 reason
    ) public {
        requirePauseRole(roles, rolesCodeHash, authority, value, reason);
        StreamNativeCuratedClock.setGlobal(state.clocks, value);
        emit ImmediateSalePause(0, value, msg.sender, reason);
    }

    function setSalePause(
        StreamNativeImmediateSalesState.State storage state,
        address roles,
        bytes32 rolesCodeHash,
        address authority,
        bytes32 id,
        bool value,
        bytes32 reason
    ) public {
        requirePauseRole(roles, rolesCodeHash, authority, value, reason);
        S.Record storage sale = state.sales[id];
        if (sale.saleNonce == 0) revert S.ImmediateSaleUnavailable(id);
        StreamNativeCuratedClock.setSale(state.clocks, id, sale.config.collectionId, value);
        emit ImmediateSalePause(id, value, msg.sender, reason);
    }

    /// @dev Fixed delegatecall preserves the guarded host's caller and original role-check order.
    function requirePauseRole(
        address roles,
        bytes32 rolesCodeHash,
        address authority,
        bool value,
        bytes32 reason
    ) public view {
        if (reason == 0) revert S.InvalidImmediateSale();
        StreamRefundWindowSupport.requireRole(
            roles,
            rolesCodeHash,
            authority,
            value ? keccak256("ROLE_PAUSE_GUARDIAN") : keccak256("ROLE_UNPAUSE")
        );
    }

    function configurationHash(C.Configuration memory config) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLAIM_SALES_CONFIG_V1"),
                block.chainid,
                address(this),
                config
            )
        );
    }

    function saleId(uint256 collection, bytes32 phase, uint256 nonce)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLAIM_SALES_ID_V1"),
                block.chainid,
                address(this),
                collection,
                phase,
                nonce
            )
        );
    }

    function register(
        StreamNativeClaimSalesState.State storage state,
        StreamNativeImmediateSalesRuntime.Context memory x,
        C.Configuration memory config
    ) public returns (bytes32 id) {
        S.Configuration memory c = config.sale;
        if (
            c.collectionId == 0 || c.phaseId == 0 || c.mintPolicyHash == 0
                || (c.saleKind != 12 && c.saleKind != 13) || c.saleSupplyLimit == 0
                || c.primaryPolicyMode != 0
                || (c.manualClose ? c.endsAt != 0 : c.endsAt <= c.startsAt)
        ) {
            revert C.InvalidClaimSale();
        }
        if (c.saleKind == 12) {
            if (c.unitPrice != 0 || config.maxUnitPrice != 0 || c.expectedPrimaryPolicyHash != 0) {
                revert C.InvalidClaimSale();
            }
        } else {
            if (
                config.maxUnitPrice == 0 || config.maxUnitPrice < c.unitPrice
                    || c.expectedPrimaryPolicyHash == 0
            ) revert C.InvalidClaimSale();
            StreamSaleTemplate.Selection memory rights =
                StreamNativeSettlementSupport.rights(x.artist.resolver, c.collectionId);
            if (
                StreamSaleTemplate.policyHash(x.artist.resolver, c.collectionId, rights)
                    != c.expectedPrimaryPolicyHash
            ) revert C.InvalidClaimSale();
        }
        StreamNativeImmediateSalesRuntime.requireSigner(state.common, c);
        StreamNativeImmediateSalesRuntime.requirePhase(x, c);
        if (x.artist.manager.phasePolicyHash(c.collectionId, c.phaseId) != c.mintPolicyHash) {
            revert C.InvalidClaimSale();
        }
        _pricePolicy(x, c);
        StreamRefundWindowSupport.ArtistAssociation memory a =
            StreamNativeCuratedSaleSupport.association(x.artist, c.collectionId);
        id = saleId(c.collectionId, c.phaseId, state.common.nextSaleNonce);
        (bool paused,, bool stopped) =
            StreamNativeCuratedClock.stops(state.common.clocks, id, c.collectionId);
        uint8 contest = StreamNativeCuratedSaleSupport.contestState(x.artist, c.collectionId);
        if (paused || stopped || contest == 1 || contest == 3) {
            revert S.ImmediateSaleUnavailable(id);
        }
        S.Record storage r = state.common.sales[id];
        if (r.saleNonce != 0) revert C.InvalidClaimSale();
        r.config = c;
        r.configHash = configurationHash(config);
        r.saleNonce = state.common.nextSaleNonce++;
        r.lifecycle = StreamNativeSettlementAdmission.capture(x.artist.registry, address(this));
        r.artistId = a.artistId;
        r.artistGeneration = a.generation;
        r.artistBindingHash = a.bindingHash;
        state.maxUnitPrices[id] = config.maxUnitPrice;
        emit ClaimSaleRegistered(id, r.configHash, r.saleNonce, config);
    }

    function _pricePolicy(
        StreamNativeImmediateSalesRuntime.Context memory x,
        S.Configuration memory c
    ) private view {
        if (c.priceCounterId != 0) {
            StreamMintSaleAllowlist.validatePolicy(
                address(x.artist.manager), c.collectionId, c.phaseId, c.priceCounterId
            );
        } else {
            bytes32[] memory ids = x.artist.manager.phaseCounterIds(c.collectionId, c.phaseId);
            if (ids.length > 16) revert C.InvalidClaimSale();
            for (uint256 i; i < ids.length; ++i) {
                if (
                    x.artist.manager.counterConfig(c.collectionId, c.phaseId, ids[i]).capMode
                        == IStreamMintLedger.CounterCapMode.MERKLE_STATIC
                ) revert C.InvalidClaimSale();
            }
        }
    }

    function prepare(
        StreamNativeClaimSalesState.State storage state,
        StreamNativeImmediateSalesRuntime.Context memory x,
        C.Purchase memory purchase,
        StreamPrivateSaleTypes.SaleAuthorization memory authorization,
        IStreamPrivateSaleAdapter.Signature memory proof,
        uint8 mode
    )
        public
        view
        returns (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory c,
            IStreamMintManager.MintBatch memory batch
        )
    {
        S.Purchase memory p = purchase.mint;
        StreamNativeImmediateSalesRuntime.requireReady(state.common, x, p.saleId, true);
        S.Record memory r = state.common.sales[p.saleId];
        uint256 next = state.common.executionNonces[p.saleId][p.payer] + 1;
        if (p.executionNonce != next) revert S.ImmediateSaleNonceInvalid(next, p.executionNonce);
        if (
            r.config.authorityMode != mode || (mode != 1 && mode != 2) || p.payer == address(0)
                || p.payer != p.executor || p.payer == address(this)
                || p.initialRecipient == address(0) || p.initialRecipient == address(this)
                || p.beneficiary == address(0) || p.mintCommitment == 0 || p.tokenData.length > 8192
        ) {
            revert C.InvalidClaimSale();
        }
        bytes32 request = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLAIM_SALES_REQUEST_V1"),
                block.chainid,
                address(this),
                r.configHash,
                purchase
            )
        );
        batch = _batch(r.config, p, request);
        bytes32 digest;
        if (mode == 1) {
            StreamPrivateSaleTypes.SaleAuthorization memory expected =
                _expected(r.config, p, batch, address(x.artist.manager), authorization.unitPrice);
            digest = StreamCanonicalSaleAuthorization.verify(
                r.config.signer.authorizer,
                r.config.signer.kind,
                expected,
                authorization,
                proof,
                x.signatureGas
            );
            batch.authorizationId = StreamMintTicketHash.authorizationId(digest);
        } else {
            batch.authorizationId = keccak256(
                abi.encode(
                    keccak256("6529STREAM_NATIVE_PUBLIC_CLAIM_MINT_AUTHORIZATION_V1"),
                    block.chainid,
                    address(this),
                    address(x.artist.manager),
                    r.configHash,
                    request
                )
            );
        }
        _price(x, r.config, purchase, authorization.unitPrice, mode, state.maxUnitPrices[p.saleId]);
        c.saleAdapter = address(this);
        c.executor = p.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            p.saleId,
            keccak256("PRIMARY_SALE"),
            0,
            r.config.collectionId,
            0,
            r.saleNonce,
            p.payer,
            address(0),
            p.beneficiary,
            purchase.chosenUnitPrice,
            r.config.expectedPrimaryPolicyHash
        );
        c.lifecycleBinding = r.lifecycle;
        c.executionBinding =
            StreamPrimarySettlementTypes.SaleExecutionBinding(0, p.executionNonce, mode, digest);
        c.orchestrationOrder = 1;
        c.mintManager = address(x.artist.manager);
        c.currentPolicyHash =
            x.artist.manager.phasePolicyHash(r.config.collectionId, r.config.phaseId);
        c.boundPolicyHash = r.config.mintPolicyHash;
        if (purchase.chosenUnitPrice != 0) {
            StreamSaleTemplate.Selection memory rights =
                StreamNativeSettlementSupport.rights(x.artist.resolver, r.config.collectionId);
            if (
                StreamSaleTemplate.policyHash(x.artist.resolver, r.config.collectionId, rights)
                    != r.config.expectedPrimaryPolicyHash
            ) revert C.InvalidClaimSale();
            c.rights = StreamPrimarySettlementTypes.PrimaryRights(
                rights.profileId,
                rights.wallet,
                rights.templateId,
                rights.assignmentHash,
                rights.entriesHash
            );
        }
        c.saleExecutionHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLAIM_SALES_EXECUTION_V1"),
                request,
                digest,
                batch.authorizationId
            )
        );
        bytes32[] memory ids;
        (c.operationIdentityCommitment, ids) =
            IStreamMintReads(address(x.artist.manager)).previewSingleStepMintOperation(batch, "");
        if (c.operationIdentityCommitment == 0 || ids.length != 1 || ids[0] == 0) {
            revert S.ImmediateSaleResultMismatch();
        }
        c.operationId = ids[0];
        c.executionBinding.executionId = StreamNativeSettlementHash.executionId(c);
        StreamNativeSettlementAdmission.requireAdmission(x.artist.registry, c);
    }

    function _price(
        StreamNativeImmediateSalesRuntime.Context memory x,
        S.Configuration memory config,
        C.Purchase memory purchase,
        uint256 signedMinimum,
        uint8 mode,
        uint256 maximum
    ) private view {
        S.Purchase memory p = purchase.mint;
        bool override_;
        uint256 proven;
        if (config.priceCounterId != 0) {
            (override_, proven) = StreamMintSaleAllowlist.price(
                address(x.artist.manager),
                config.collectionId,
                config.phaseId,
                p.payer,
                p.beneficiary,
                p.resolverData,
                config.priceCounterId
            );
        } else if (p.resolverData.length != 0) {
            revert C.InvalidClaimSale();
        }
        if (config.saleKind == 12) {
            if (
                purchase.chosenUnitPrice != 0 || (mode == 1 && signedMinimum != 0)
                    || (override_ && proven != 0)
            ) revert C.InvalidClaimSale();
            return;
        }
        if (config.saleKind != 13) revert C.InvalidClaimSale();
        uint256 minimum = override_ ? proven : mode == 1 ? signedMinimum : config.unitPrice;
        if (minimum < config.unitPrice) minimum = config.unitPrice;
        if (purchase.chosenUnitPrice < minimum || purchase.chosenUnitPrice > maximum) {
            revert C.ClaimPriceInvalid(purchase.chosenUnitPrice, minimum, maximum);
        }
    }

    function _batch(S.Configuration memory config, S.Purchase memory p, bytes32 context)
        private
        pure
        returns (IStreamMintManager.MintBatch memory b)
    {
        b.collectionId = config.collectionId;
        b.phaseId = config.phaseId;
        b.payer = p.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = p.initialRecipient;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = p.beneficiary;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = p.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = p.mintCommitment;
        b.expectedPolicyHash = config.mintPolicyHash;
        b.contextHash = context;
        b.resolverData = p.resolverData;
    }

    function _expected(
        S.Configuration memory config,
        S.Purchase memory p,
        IStreamMintManager.MintBatch memory b,
        address manager,
        uint256 minimum
    ) private view returns (StreamPrivateSaleTypes.SaleAuthorization memory a) {
        a.chainId = block.chainid;
        a.saleAdapter = address(this);
        a.mintManager = manager;
        a.collectionId = config.collectionId;
        a.phaseId = config.phaseId;
        a.saleId = p.saleId;
        a.saleKind = config.saleKind;
        a.revenueClass = keccak256("PRIMARY_SALE");
        a.expectedPrimaryPolicyHash = config.expectedPrimaryPolicyHash;
        a.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients)
        );
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries)
        );
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData));
        a.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments)
        );
        a.payer = p.payer;
        a.executor = p.executor;
        a.unitPrice = minimum;
        a.quantity = 1;
        a.policyHash = config.mintPolicyHash;
        // STRICT/native/no selected content/no deferred finalization. Verifier handles nonce/deadline.
    }

    function retained(
        StreamNativeClaimSalesState.State storage state,
        StreamNativeImmediateSalesRuntime.Context memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) public view {
        StreamNativeImmediateSalesRuntime.requireReady(state.common, x, c.sale.settlementId, false);
        StreamNativeSettlementAdmission.requireAdmission(x.artist.registry, c);
        S.Configuration memory config = state.common.sales[c.sale.settlementId].config;
        if (
            x.artist.manager.phasePolicyHash(config.collectionId, config.phaseId)
                != c.currentPolicyHash
        ) {
            revert C.InvalidClaimSale();
        }
        if (c.sale.amount != 0) {
            StreamNativeSettlementSupport.requireCurrent(
                x.artist.resolver,
                config.collectionId,
                StreamSaleTemplate.Selection(
                    c.rights.profileId,
                    c.rights.wallet,
                    c.rights.templateId,
                    c.rights.assignmentHash,
                    c.rights.entriesHash
                )
            );
        }
    }
}
