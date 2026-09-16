// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeCuratedSaleRegistration.sol";
import "./StreamNativeCuratedSaleRuntime.sol";
import "../../interfaces/stream/mint/StreamNativePrimaryOfferTypes.sol";
import "./StreamPreparedNativeContentHash.sol";
import "./StreamPreparedNativeOfferReads.sol";
import "../../vendor/openzeppelin/MerkleProof.sol";

/// @notice Offer-only admission. Collection offers do not manufacture content identities or counters.
library StreamNativePrimaryOfferSupport {
    error InvalidPrimaryOffer();
    event CuratedSaleConfigured(
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        uint8 saleKind,
        uint256 saleNonce,
        Curated.Configuration config
    );

    function configurationHash(StreamNativePrimaryOfferTypes.Configuration memory c)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_PRIMARY_OFFER_CONFIG_V1"),
                block.chainid,
                address(this),
                c
            )
        );
    }

    function register(
        StreamNativeCuratedSaleState.State storage state,
        StreamNativeCuratedSaleSupport.Context memory x,
        StreamNativePrimaryOfferTypes.Configuration memory terms,
        bytes32[] memory proof
    ) public returns (bytes32 id) {
        Curated.Configuration memory c = terms.sale;
        if (
            c.collectionId == 0 || c.phaseId == 0 || c.price == 0 || c.poster == address(0)
                || c.poster == address(this) || c.startsAt <= block.timestamp
                || c.endsAt <= c.startsAt || c.mintPolicyHash == 0
                || c.expectedPrimaryPolicyHash == 0 || c.primaryPolicyMode != 0
                || terms.buyer == address(0) || terms.buyer == address(this)
                || terms.offerDigest == 0
        ) {
            revert InvalidPrimaryOffer();
        }
        id = StreamNativeCuratedSaleHash.saleId(6, c.collectionId, c.phaseId, state.nextSaleNonce);
        if (state.sales[id].status != 0) revert InvalidPrimaryOffer();
        (bool globalPause,, bool collectionStop) =
            StreamNativeCuratedClock.stops(state.clocks, id, c.collectionId);
        if (globalPause || collectionStop) revert InvalidPrimaryOffer();
        StreamRefundWindowSupport.ArtistAssociation memory artist =
            StreamNativeCuratedSaleSupport.association(x, c.collectionId);
        IStreamMintManager.MintGateConfig memory gate;
        Content.Publication memory publication;
        if (c.contentManifestRoot != 0) {
            (gate, publication) = StreamPreparedNativeOfferReads.requirePublication(
                address(x.manager),
                x.registry,
                address(this),
                c.collectionId,
                c.phaseId,
                id,
                c.contentManifestRoot
            );
            _phase(x, c, true);
            if (
                terms.tokenDataHash == 0
                    || !MerkleProof.verify(
                        proof,
                        c.contentManifestRoot,
                        StreamPreparedNativeContentHash.leaf(
                            block.chainid, address(this), id, terms.contentId, terms.tokenDataHash
                        )
                    )
            ) revert InvalidPrimaryOffer();
        } else {
            if (terms.contentId != 0 || terms.tokenDataHash != 0 || proof.length != 0) {
                revert InvalidPrimaryOffer();
            }
            gate = x.manager.phaseGate(c.collectionId, c.phaseId);
            // No arbitrary eligibility proof is silently discarded on the collection route.
            _requireNoGate(gate);
            _phase(x, c, true);
        }
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            x.resolver.resolvePrimaryAssignment(c.collectionId, 0, keccak256("PRIMARY_SALE"));
        if (
            !a.exists || a.scope != 1 || a.scopeId != c.collectionId || a.assignmentType != 1
                || a.profileId == 0 || a.templateId != 0 || a.assignmentHash == 0
                || a.policyHash != 0
                || StreamSaleTemplate.policyHash(
                        x.resolver,
                        c.collectionId,
                        StreamNativeSettlementSupport.rights(x.resolver, c.collectionId)
                    ) != c.expectedPrimaryPolicyHash
        ) {
            revert InvalidPrimaryOffer();
        }
        Curated.SaleRecord storage s = state.sales[id];
        s.config = c;
        s.saleNonce = state.nextSaleNonce++;
        s.saleKind = 6;
        s.configHash = configurationHash(terms);
        s.lifecycle = StreamPreparedNativeSettlementAdmission.capture(x.registry, address(this));
        s.artistId = artist.artistId;
        s.bindingGeneration = artist.generation;
        s.bindingHash = artist.bindingHash;
        s.gate = gate.gate;
        s.gateCodeHash = gate.gateCodehash;
        s.gateConfigHash = gate.gateConfigHash;
        s.manifestHash = publication.manifestHash;
        s.contentCounterId = publication.counterId;
        if (publication.counterId != 0) {
            s.contentCounterConfigHash =
            x.manager
            .counterConfig(c.collectionId, c.phaseId, publication.counterId)
            .counterConfigHash;
        }
        s.status = 1;
        emit CuratedSaleConfigured(id, s.configHash, 6, s.saleNonce, c);
    }

    function requireSale(
        StreamNativeCuratedSaleState.State storage state,
        StreamNativeCuratedSaleRuntime.Context memory x,
        bytes32 id
    ) public view {
        StreamNativeCuratedSaleRuntime.requireContext(x);
        Curated.SaleRecord storage s = state.sales[id];
        if (s.saleKind != 6 || s.status != 1 || s.configHash == 0) revert InvalidPrimaryOffer();
        (bool g, bool l, bool c) =
            StreamNativeCuratedClock.stops(state.clocks, id, s.config.collectionId);
        if (g || l || c) revert InvalidPrimaryOffer();
        StreamNativeCuratedSaleSupport.Context memory support =
            StreamNativeCuratedSaleRuntime.support(x);
        StreamPreparedNativeSettlementAdmission.requireAdmission(
            support.registry, address(this), id
        );
        StreamRefundWindowSupport.Context memory artistContext;
        artistContext.core = support.core;
        artistContext.manager = support.manager;
        artistContext.resolver = support.resolver;
        artistContext.artists = support.artists;
        artistContext.artistHash = support.artistsHash;
        artistContext.artistGas = support.artistGas;
        StreamRefundWindowSupport.requireSaleConsent(
            artistContext, s.config.collectionId, id, s.configHash
        );
        StreamRefundWindowSupport.requireArtistAssociation(
            artistContext, s.config.collectionId, s.artistId, s.bindingGeneration, s.bindingHash
        );
        if (s.config.contentManifestRoot != 0) {
            IStreamMintManager.MintGateConfig memory gate =
                support.manager.phaseGate(s.config.collectionId, s.config.phaseId);
            IStreamMintManager.MintCounterConfig memory counter = support.manager
                .counterConfig(s.config.collectionId, s.config.phaseId, s.contentCounterId);
            bytes32[] memory ids =
                support.manager.phaseCounterIds(s.config.collectionId, s.config.phaseId);
            if (ids.length > 16) revert InvalidPrimaryOffer();
            bool found;
            for (uint256 n; n < ids.length; ++n) {
                if (ids[n] == s.contentCounterId) found = true;
            }
            if (
                gate.gate != s.gate || gate.gateCodehash != s.gateCodeHash
                    || gate.gate.codehash != s.gateCodeHash
                    || gate.gateConfigHash != s.gateConfigHash || !found || !counter.enabled
                    || counter.keyMode != IStreamMintManager.CounterKeyMode.CONTEXT
                    || counter.capMode != IStreamMintLedger.CounterCapMode.STATIC
                    || counter.deltaMode != IStreamMintLedger.CounterDeltaMode.STATIC
                    || counter.staticCap != 1 || counter.staticIncrement != 1
                    || counter.counterConfigHash != s.contentCounterConfigHash
            ) revert InvalidPrimaryOffer();
        } else {
            IStreamMintManager.MintGateConfig memory gate =
                support.manager.phaseGate(s.config.collectionId, s.config.phaseId);
            _requireNoGate(gate);
        }
        _phase(support, s.config, false);
    }

    function _phase(
        StreamNativeCuratedSaleSupport.Context memory x,
        Curated.Configuration memory c,
        bool registration
    ) private view {
        (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
            x.manager.phase(c.collectionId, c.phaseId);
        if (
            !exists || phase.paused || phase.maxBatchQuantity != 1
                || !x.manager.phaseExecutor(c.collectionId, c.phaseId, address(this))
        ) revert InvalidPrimaryOffer();
        if (registration) {
            if (
                phase.startTime > c.startsAt || (phase.endTime != 0 && phase.endTime < c.endsAt)
                    || x.manager.phasePolicyHash(c.collectionId, c.phaseId) != c.mintPolicyHash
            ) revert InvalidPrimaryOffer();
        } else {
            if (
                block.timestamp < phase.startTime
                    || (phase.endTime != 0 && block.timestamp > phase.endTime)
            ) revert InvalidPrimaryOffer();
            if (x.manager.phasePolicyHash(c.collectionId, c.phaseId) != c.mintPolicyHash) {
                (bytes32 previous, uint64 until) =
                    x.manager.phasePolicyGrace(c.collectionId, c.phaseId);
                if (previous != c.mintPolicyHash || block.timestamp > until) {
                    revert InvalidPrimaryOffer();
                }
            }
        }
    }

    function _requireNoGate(IStreamMintManager.MintGateConfig memory gate) private pure {
        IStreamMintManager.MintGateConfig memory empty;
        if (keccak256(abi.encode(gate)) != keccak256(abi.encode(empty))) {
            revert InvalidPrimaryOffer();
        }
    }

    function selection(bytes32 id, Curated.SaleRecord memory sale, Curated.Selection memory chosen)
        public
        view
        returns (bytes32 leaf, bytes32 context)
    {
        if (sale.config.contentManifestRoot != 0) {
            return StreamNativeCuratedSaleSupport.selection(id, sale, chosen);
        }
        if (
            chosen.content.contentId != 0 || chosen.content.tokenDataHash != 0
                || chosen.content.proof.length != 0 || chosen.recipient == address(0)
                || chosen.recipient == address(this) || chosen.purchaseNonce == 0
                || chosen.mintCommitment == 0 || chosen.tokenData.length > 8192
        ) revert InvalidPrimaryOffer();
        return (0, 0);
    }
}
