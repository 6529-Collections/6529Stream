// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamNativeImmediateSales as S
} from "../../interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import "./StreamNativeImmediateSalesState.sol";
import "./StreamNativeCuratedSaleSupport.sol";
import "./StreamMintSaleAllowlist.sol";
import "./StreamMintTicketHash.sol";
import "./StreamPrivateSaleSupport.sol";
import { StreamCanonicalSaleAuthorization } from "./StreamCanonicalSaleAuthorization.sol";
import "./StreamSaleConsent.sol";
import "../revenue/StreamNativeSettlementSupport.sol";
import "../revenue/StreamNativeSettlementAdmission.sol";
import "../revenue/StreamNativeSettlementHash.sol";
import "../revenue/StreamPrimarySettlementHash.sol";
import "../../interfaces/stream/revenue/IStreamNativePrimarySaleSettlement.sol";
import "../../interfaces/stream/revenue/IStreamNativePublicPrimarySaleSettlement.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";

/// @notice Fixed typed checks for canonical immediate sales in the guarded adapter's context.
library StreamNativeImmediateSalesRuntime {
    event ImmediateSaleRegistered(
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        uint256 saleNonce,
        S.Configuration config
    );

    struct Context {
        StreamNativeCuratedSaleSupport.Context artist;
        address recorder;
        bytes32 recorderHash;
        bytes32 managerHash;
        uint256 signatureGas;
    }

    function configurationHash(S.Configuration memory config) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_IMMEDIATE_SALES_CONFIG_V1"),
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
                keccak256("6529STREAM_NATIVE_IMMEDIATE_SALES_ID_V1"),
                block.chainid,
                address(this),
                collection,
                phase,
                nonce
            )
        );
    }

    function requireSigner(
        StreamNativeImmediateSalesState.State storage state,
        S.Configuration memory config
    ) public view {
        if (config.authorityMode == 2) {
            if (
                keccak256(abi.encode(config.signer))
                    != keccak256(abi.encode(S.SignerBinding(address(0), 0, 0, 0, address(0))))
            ) revert S.InvalidImmediateSale();
            return;
        }
        S.SignerBinding memory b = config.signer;
        StreamNativeImmediateSalesState.Signer storage live =
            state.signers[config.collectionId][b.authorizer][b.kind];
        if (
            config.authorityMode != 1 || b.authorizer == address(0) || (b.kind != 1 && b.kind != 2)
                || b.revision == 0 || b.evidenceHash == 0 || b.installingAuthority == address(0)
                || !live.enabled || keccak256(abi.encode(live.binding)) != keccak256(abi.encode(b))
        ) {
            revert S.ImmediateSaleSignerUnavailable(b.authorizer, b.kind);
        }
    }

    function register(
        StreamNativeImmediateSalesState.State storage state,
        Context memory x,
        S.Configuration memory config
    ) public returns (bytes32 id) {
        if (
            config.collectionId == 0 || config.phaseId == 0 || config.saleKind > 1
                || config.unitPrice == 0 || config.mintPolicyHash == 0
                || config.expectedPrimaryPolicyHash == 0 || config.primaryPolicyMode != 0
                || (config.saleKind == 0
                        ? config.saleSupplyLimit == 0
                        : config.saleSupplyLimit != 0)
                || (config.manualClose ? config.endsAt != 0 : config.endsAt <= config.startsAt)
        ) revert S.InvalidImmediateSale();
        requireSigner(state, config);
        requirePhase(x, config);
        if (
            x.artist.manager.phasePolicyHash(config.collectionId, config.phaseId)
                != config.mintPolicyHash
        ) revert S.InvalidImmediateSale();
        _pricePolicy(x, config);
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(x.artist.resolver, config.collectionId);
        if (
            StreamSaleTemplate.policyHash(x.artist.resolver, config.collectionId, rights)
                != config.expectedPrimaryPolicyHash
        ) revert S.InvalidImmediateSale();
        StreamRefundWindowSupport.ArtistAssociation memory a =
            StreamNativeCuratedSaleSupport.association(x.artist, config.collectionId);
        id = saleId(config.collectionId, config.phaseId, state.nextSaleNonce);
        (bool globalPause,, bool stopped) =
            StreamNativeCuratedClock.stops(state.clocks, id, config.collectionId);
        uint8 contest = StreamNativeCuratedSaleSupport.contestState(x.artist, config.collectionId);
        if (globalPause || stopped || contest == 1 || contest == 3) {
            revert S.ImmediateSaleUnavailable(id);
        }
        S.Record storage r = state.sales[id];
        if (r.saleNonce != 0) revert S.InvalidImmediateSale();
        r.config = config;
        r.configHash = configurationHash(config);
        r.saleNonce = state.nextSaleNonce++;
        r.lifecycle = StreamNativeSettlementAdmission.capture(x.artist.registry, address(this));
        r.artistId = a.artistId;
        r.artistGeneration = a.generation;
        r.artistBindingHash = a.bindingHash;
        // Consent is recorded against these immutable facts after registration and required on use.
        emit ImmediateSaleRegistered(id, r.configHash, r.saleNonce, config);
    }

    function requirePhase(Context memory x, S.Configuration memory config) public view {
        if (
            address(x.artist.manager).codehash != x.managerHash
                || x.recorder.codehash != x.recorderHash
        ) revert S.InvalidImmediateSale();
        (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
            x.artist.manager.phase(config.collectionId, config.phaseId);
        if (
            !exists || phase.paused || phase.maxBatchQuantity == 0
                || !x.artist.manager
                .phaseExecutor(config.collectionId, config.phaseId, address(this))
                || x.artist.manager.phaseGate(config.collectionId, config.phaseId).gate
                    != address(0)
        ) revert S.InvalidImmediateSale();
    }

    function _pricePolicy(Context memory x, S.Configuration memory config) private view {
        if (config.priceCounterId != 0) {
            StreamMintSaleAllowlist.validatePolicy(
                address(x.artist.manager),
                config.collectionId,
                config.phaseId,
                config.priceCounterId
            );
        } else {
            bytes32[] memory ids =
                x.artist.manager.phaseCounterIds(config.collectionId, config.phaseId);
            if (ids.length > 16) revert S.InvalidImmediateSale();
            for (uint256 i; i < ids.length; ++i) {
                if (
                    x.artist
                        .manager
                        .counterConfig(config.collectionId, config.phaseId, ids[i])
                        .capMode == IStreamMintLedger.CounterCapMode.MERKLE_STATIC
                ) revert S.InvalidImmediateSale();
            }
        }
    }

    function requireReady(
        StreamNativeImmediateSalesState.State storage state,
        Context memory x,
        bytes32 id,
        bool beforePurchase
    ) public view {
        S.Record memory r = state.sales[id];
        if (
            r.saleNonce == 0 || r.closed
                || (beforePurchase
                    && r.config.saleSupplyLimit != 0
                    && r.soldQuantity >= r.config.saleSupplyLimit)
        ) revert S.ImmediateSaleUnavailable(id);
        (bool globalPause, bool localPause, bool stopped) =
            StreamNativeCuratedClock.stops(state.clocks, id, r.config.collectionId);
        if (globalPause || localPause || stopped || block.timestamp < r.config.startsAt) {
            revert S.ImmediateSaleUnavailable(id);
        }
        if (!r.config.manualClose) {
            uint64 now_ = StreamNativeCuratedClock.now64();
            uint64 toll = StreamNativeCuratedClock.unionAt(
                state.clocks, id, r.config.collectionId, now_
            )
            - StreamNativeCuratedClock.unionAt(
                state.clocks, id, r.config.collectionId, r.config.startsAt
            );
            if (block.timestamp - r.config.startsAt - toll >= r.config.endsAt - r.config.startsAt) {
                revert S.ImmediateSaleUnavailable(id);
            }
        }
        requireSigner(state, r.config);
        requirePhase(x, r.config);
        _pricePolicy(x, r.config);
        StreamSaleConsent.requireConsent(
            x.artist.core,
            address(x.artist.artists),
            x.artist.artistsHash,
            r.config.collectionId,
            id,
            r.configHash
        );
        StreamRefundWindowSupport.Context memory artist;
        artist.core = x.artist.core;
        artist.artists = x.artist.artists;
        artist.artistHash = x.artist.artistsHash;
        artist.artistGas = x.artist.artistGas;
        StreamRefundWindowSupport.requireArtistAssociation(
            artist, r.config.collectionId, r.artistId, r.artistGeneration, r.artistBindingHash
        );
    }

    function prepare(
        StreamNativeImmediateSalesState.State storage state,
        Context memory x,
        S.Purchase memory p,
        StreamPrivateSaleTypes.SaleAuthorization memory a,
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
        requireReady(state, x, p.saleId, true);
        S.Record memory r = state.sales[p.saleId];
        uint256 next = state.executionNonces[p.saleId][p.payer] + 1;
        if (p.executionNonce != next) revert S.ImmediateSaleNonceInvalid(next, p.executionNonce);
        if (
            r.config.authorityMode != mode || p.payer == address(0) || p.payer != p.executor
                || p.payer == address(this) || p.initialRecipient == address(0)
                || p.initialRecipient == address(this) || p.beneficiary == address(0)
                || p.mintCommitment == 0 || p.tokenData.length > 8192
        ) revert S.InvalidImmediateSale();
        bytes32 requestHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_IMMEDIATE_SALES_REQUEST_V1"),
                block.chainid,
                address(this),
                r.configHash,
                p
            )
        );
        bytes32 digest;
        batch = _batch(r.config, p, requestHash);
        if (mode == 1) {
            digest =
                _signed(r.config, p, a, proof, batch, address(x.artist.manager), x.signatureGas);
            batch.authorizationId = StreamMintTicketHash.authorizationId(digest);
        } else if (mode == 2) {
            batch.authorizationId = keccak256(
                abi.encode(
                    keccak256("6529STREAM_NATIVE_PUBLIC_MINT_AUTHORIZATION_V1"),
                    block.chainid,
                    address(this),
                    address(x.artist.manager),
                    r.configHash,
                    requestHash
                )
            );
        } else {
            revert S.InvalidImmediateSale();
        }
        uint256 price = r.config.unitPrice;
        if (r.config.priceCounterId != 0) {
            (bool override_, uint256 proven) = StreamMintSaleAllowlist.price(
                address(x.artist.manager),
                r.config.collectionId,
                r.config.phaseId,
                p.payer,
                p.beneficiary,
                p.resolverData,
                r.config.priceCounterId
            );
            if (override_) price = proven;
        } else if (p.resolverData.length != 0) {
            revert S.InvalidImmediateSale();
        }
        if (price == 0) revert S.InvalidImmediateSale();
        StreamSaleTemplate.Selection memory rights =
            StreamNativeSettlementSupport.rights(x.artist.resolver, r.config.collectionId);
        if (
            StreamSaleTemplate.policyHash(x.artist.resolver, r.config.collectionId, rights)
                != r.config.expectedPrimaryPolicyHash
        ) revert S.InvalidImmediateSale();
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
            price,
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
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            rights.profileId,
            rights.wallet,
            rights.templateId,
            rights.assignmentHash,
            rights.entriesHash
        );
        c.saleExecutionHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_IMMEDIATE_SALES_EXECUTION_V1"),
                requestHash,
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
        // Ungated Manager normalization is NONE/zero, independently of the sale signer.
    }

    function _signed(
        S.Configuration memory config,
        S.Purchase memory p,
        StreamPrivateSaleTypes.SaleAuthorization memory a,
        IStreamPrivateSaleAdapter.Signature memory proof,
        IStreamMintManager.MintBatch memory b,
        address manager,
        uint256 gasCap
    ) private view returns (bytes32 digest) {
        StreamPrivateSaleTypes.SaleAuthorization memory expected;
        expected.chainId = block.chainid;
        expected.saleAdapter = address(this);
        expected.mintManager = manager;
        expected.collectionId = config.collectionId;
        expected.phaseId = config.phaseId;
        expected.saleId = p.saleId;
        expected.saleKind = config.saleKind;
        expected.revenueClass = keccak256("PRIMARY_SALE");
        expected.expectedPrimaryPolicyHash = config.expectedPrimaryPolicyHash;
        expected.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients)
        );
        expected.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries)
        );
        expected.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData));
        expected.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments)
        );
        expected.payer = p.payer;
        expected.executor = p.executor;
        expected.unitPrice = config.unitPrice;
        expected.quantity = 1;
        expected.policyHash = config.mintPolicyHash;
        // Original zero requirements: primaryPolicyMode, asset, contentSelectionHash, finalizeBy.
        return StreamCanonicalSaleAuthorization.verify(
            config.signer.authorizer, config.signer.kind, expected, a, proof, gasCap
        );
    }

    function retained(
        StreamNativeImmediateSalesState.State storage state,
        Context memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) public view {
        requireReady(state, x, c.sale.settlementId, false);
        StreamNativeSettlementAdmission.requireAdmission(x.artist.registry, c);
        S.Configuration memory config = state.sales[c.sale.settlementId].config;
        if (
            x.artist.manager.phasePolicyHash(config.collectionId, config.phaseId)
                != c.currentPolicyHash
        ) revert S.InvalidImmediateSale();
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

    function settle(
        Context memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory r) {
        bytes memory data = c.executionBinding.authorityMode == 1
            ? abi.encodeCall(
                IStreamNativePrimarySaleSettlement.settleNativePrimarySaleFromAdapter, (c)
            )
            : abi.encodeCall(
                IStreamNativePublicPrimarySaleSettlement.settleNativePublicPrimarySaleFromAdapter,
                (c)
            );
        bytes memory response = new bytes(384);
        bool ok;
        uint256 size;
        address target = x.recorder;
        uint256 amount = c.sale.amount;
        assembly ("memory-safe") {
            ok := call(gas(), target, amount, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384) revert S.ImmediateSaleResultMismatch();
        r = abi.decode(response, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        if (
            r.candidateCommitment != StreamNativeSettlementHash.candidateCommitment(target, c)
                || r.settlementKey
                    != StreamPrimarySettlementHash.settlementKey(
                        target, address(this), c.executionBinding.executionId
                    ) || r.profileId != c.rights.profileId || r.wallet != c.rights.wallet
                || r.asset != address(0) || r.amount != c.sale.amount || r.executor != c.executor
                || r.executionId != c.executionBinding.executionId
                || r.operationIdentityCommitment != c.operationIdentityCommitment
                || r.currentPolicyHash != c.currentPolicyHash
                || r.boundPolicyHash != c.boundPolicyHash
        ) revert S.ImmediateSaleResultMismatch();
        data = abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (r.settlementKey));
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384 || keccak256(response) != keccak256(abi.encode(r))) {
            revert S.ImmediateSaleResultMismatch();
        }
    }
}
