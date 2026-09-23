// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamERC20PrimaryOfferState.sol";
import { StreamERC20OfferReads } from "./StreamERC20OfferReads.sol";
import "./StreamPreparedNativeContentHash.sol";
import "./StreamRefundWindowSupport.sol";
import "./StreamUniversalSaleRights.sol";
import "../revenue/StreamSettlementAdmission.sol";
import "../../vendor/openzeppelin/MerkleProof.sol";

/// @notice Immutable offer registration and retained current phase, content and Artist checks.
library StreamERC20PrimaryOfferSupport {
    struct Context {
        address core;
        address registry;
        IStreamMintManager manager;
        IStreamRevenueResolver resolver;
        IStreamSplitFactory factory;
        IStreamArtistAttribution artists;
        bytes32 artistsHash;
        uint256 artistGas;
    }

    error InvalidERC20PrimaryOffer();
    error ERC20PrimaryOfferUnavailable(bytes32 saleId);
    error ERC20PrimaryOfferSignerUnavailable();

    function configurationHash(Offer.Configuration memory c) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ERC20_PRIMARY_OFFER_CONFIG_V1"),
                block.chainid,
                address(this),
                c
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
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(6),
                collection,
                phase,
                nonce
            )
        );
    }

    function register(
        StreamERC20PrimaryOfferState.State storage state,
        Context memory x,
        Offer.Configuration memory c,
        bytes32[] memory proof
    ) public returns (bytes32 id) {
        if (
            c.collectionId == 0 || c.phaseId == 0 || c.asset == address(0)
                || c.paymentAdapter == address(0) || c.price == 0 || c.poster == address(0)
                || c.poster == address(this) || c.startsAt <= block.timestamp
                || c.endsAt <= c.startsAt || c.mintPolicyHash == 0
                || c.expectedPrimaryPolicyHash == 0 || c.primaryPolicyMode != 0
                || c.buyer == address(0) || c.buyer == address(this) || c.offerDigest == 0
                || state.paused || state.collectionStopped[c.collectionId]
        ) revert InvalidERC20PrimaryOffer();
        requireSigner(state, c);
        id = saleId(c.collectionId, c.phaseId, state.nextSaleNonce);
        if (state.sales[id].status != 0) revert InvalidERC20PrimaryOffer();
        _phase(x, c, true);
        StreamRefundWindowSupport.ArtistAssociation memory a =
            StreamRefundWindowSupport.artistAssociation(artistContext(x), c.collectionId);
        if (
            a.state != 2 || a.authorityStatus != 1 || a.artistId == 0 || a.generation == 0
                || a.bindingHash == 0
        ) {
            revert InvalidERC20PrimaryOffer();
        }
        IStreamMintManager.MintGateConfig memory gate;
        StreamPreparedNativeContentTypes.Publication memory publication;
        if (c.contentManifestRoot != 0) {
            (gate, publication) = StreamERC20OfferReads.requirePublication(
                address(x.manager),
                x.registry,
                address(this),
                c.collectionId,
                c.phaseId,
                id,
                c.contentManifestRoot
            );
            if (
                c.tokenDataHash == 0
                    || !MerkleProof.verify(
                        proof,
                        c.contentManifestRoot,
                        StreamPreparedNativeContentHash.leaf(
                            block.chainid, address(this), id, c.contentId, c.tokenDataHash
                        )
                    )
            ) {
                revert InvalidERC20PrimaryOffer();
            }
        } else {
            if (c.contentId != 0 || c.tokenDataHash != 0 || proof.length != 0) {
                revert InvalidERC20PrimaryOffer();
            }
            gate = x.manager.phaseGate(c.collectionId, c.phaseId);
            _requireNoGate(gate);
        }
        rights(x, c);
        Offer.SaleRecord storage s = state.sales[id];
        s.config = c;
        s.saleNonce = state.nextSaleNonce++;
        s.configHash = configurationHash(c);
        s.lifecycle = StreamSettlementAdmission.capture(x.registry, address(this), c.paymentAdapter);
        s.artistId = a.artistId;
        s.bindingGeneration = a.generation;
        s.bindingHash = a.bindingHash;
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
    }

    function requireSale(
        StreamERC20PrimaryOfferState.State storage state,
        Context memory x,
        bytes32 id
    ) public view {
        Offer.SaleRecord storage s = state.sales[id];
        Offer.Configuration memory c = s.config;
        if (
            s.status != 1 || s.configHash == 0 || state.paused || state.salePaused[id]
                || state.collectionStopped[c.collectionId] || block.timestamp < c.startsAt
                || block.timestamp > c.endsAt
        ) {
            revert ERC20PrimaryOfferUnavailable(id);
        }
        requireSigner(state, c);
        StreamRefundWindowSupport.Context memory artist = artistContext(x);
        StreamRefundWindowSupport.requireSaleConsent(artist, c.collectionId, id, s.configHash);
        StreamRefundWindowSupport.requireArtistAssociation(
            artist, c.collectionId, s.artistId, s.bindingGeneration, s.bindingHash
        );
        IStreamMintManager.MintGateConfig memory gate =
            x.manager.phaseGate(c.collectionId, c.phaseId);
        if (c.contentManifestRoot == 0) {
            _requireNoGate(gate);
        } else {
            IStreamMintManager.MintCounterConfig memory counter =
                x.manager.counterConfig(c.collectionId, c.phaseId, s.contentCounterId);
            bytes32[] memory ids = x.manager.phaseCounterIds(c.collectionId, c.phaseId);
            if (ids.length > 16) revert InvalidERC20PrimaryOffer();
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
            ) revert InvalidERC20PrimaryOffer();
        }
        _phase(x, c, false);
    }

    function requireSigner(
        StreamERC20PrimaryOfferState.State storage state,
        Offer.Configuration memory c
    ) public view {
        Offer.CollectionSigner storage s = state.signers[c.collectionId][c.signer][c.signerKind];
        if (
            c.signer == address(0) || (c.signerKind != 1 && c.signerKind != 2) || !s.enabled
                || s.revision == 0 || s.revision != c.signerRevision
                || s.evidenceHash != c.signerEvidenceHash || s.authority == address(0)
                || s.authority != c.signerAuthority
        ) revert ERC20PrimaryOfferSignerUnavailable();
    }

    function selection(bytes32 id, Offer.Configuration memory c, Offer.Selection memory q)
        public
        view
        returns (bytes32 leaf, bytes32 context)
    {
        if (q.executionNonce == 0 || q.mintCommitment == 0 || q.tokenData.length > 8192) {
            revert InvalidERC20PrimaryOffer();
        }
        if (c.contentManifestRoot == 0) {
            if (
                q.content.contentId != 0 || q.content.tokenDataHash != 0
                    || q.content.proof.length != 0
            ) revert InvalidERC20PrimaryOffer();
            return (0, 0);
        }
        if (
            q.content.contentId != c.contentId || q.content.tokenDataHash != c.tokenDataHash
                || q.content.tokenDataHash != keccak256(q.tokenData)
        ) revert InvalidERC20PrimaryOffer();
        leaf = StreamPreparedNativeContentHash.leaf(
            block.chainid, address(this), id, q.content.contentId, q.content.tokenDataHash
        );
        if (!MerkleProof.verify(q.content.proof, c.contentManifestRoot, leaf)) {
            revert InvalidERC20PrimaryOffer();
        }
        context = StreamPreparedNativeContentHash.context(
            block.chainid, address(this), id, q.content.contentId
        );
    }

    function rights(Context memory x, Offer.Configuration memory c)
        public
        view
        returns (StreamPrimarySettlementTypes.PrimaryRights memory out)
    {
        StreamSaleTemplate.Selection memory r =
            StreamUniversalSaleRights.rights(x.resolver, x.factory, c.collectionId);
        if (
            StreamSaleTemplate.policyHash(x.resolver, c.collectionId, r)
                != c.expectedPrimaryPolicyHash
        ) revert InvalidERC20PrimaryOffer();
        return StreamPrimarySettlementTypes.PrimaryRights(
            r.profileId, r.wallet, r.templateId, r.assignmentHash, r.entriesHash
        );
    }

    function artistContext(Context memory x)
        internal
        pure
        returns (StreamRefundWindowSupport.Context memory c)
    {
        c.core = x.core;
        c.manager = x.manager;
        c.resolver = x.resolver;
        c.artists = x.artists;
        c.artistHash = x.artistsHash;
        c.artistGas = x.artistGas;
    }

    function _phase(Context memory x, Offer.Configuration memory c, bool registration)
        private
        view
    {
        (bool exists, IStreamMintManager.MintPhaseConfig memory p) =
            x.manager.phase(c.collectionId, c.phaseId);
        if (
            !exists || p.paused || p.maxBatchQuantity != 1
                || !x.manager.phaseExecutor(c.collectionId, c.phaseId, address(this))
        ) revert InvalidERC20PrimaryOffer();
        bytes32 current = x.manager.phasePolicyHash(c.collectionId, c.phaseId);
        if (registration) {
            if (
                p.startTime > c.startsAt || (p.endTime != 0 && p.endTime < c.endsAt)
                    || current != c.mintPolicyHash
            ) revert InvalidERC20PrimaryOffer();
        } else {
            if (block.timestamp < p.startTime || (p.endTime != 0 && block.timestamp > p.endTime)) {
                revert InvalidERC20PrimaryOffer();
            }
            if (current != c.mintPolicyHash) {
                (bytes32 previous, uint64 until) =
                    x.manager.phasePolicyGrace(c.collectionId, c.phaseId);
                if (previous != c.mintPolicyHash || block.timestamp > until) {
                    revert InvalidERC20PrimaryOffer();
                }
            }
        }
    }

    function _requireNoGate(IStreamMintManager.MintGateConfig memory gate) private pure {
        IStreamMintManager.MintGateConfig memory empty;
        if (keccak256(abi.encode(gate)) != keccak256(abi.encode(empty))) {
            revert InvalidERC20PrimaryOffer();
        }
    }
}
