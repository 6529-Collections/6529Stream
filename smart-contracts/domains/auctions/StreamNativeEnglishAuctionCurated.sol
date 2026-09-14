// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeEnglishAuctionRuntime.sol";
import "./StreamNativeAuctionContent.sol";
import "../mint/StreamPreparedNativeContentReads.sol";
import {
    IStreamNativeEnglishAuction as A
} from "../../interfaces/stream/auctions/IStreamNativeEnglishAuction.sol";

/// @notice Complete published leaf admission and retained proof in the original house context.
library StreamNativeEnglishAuctionCurated {
    event NativeAuctionCreated(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        A.Configuration config,
        bytes32 creationDigest
    );
    event CuratedAuctionBound(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        bytes32 indexed root,
        address gate,
        bytes32 manifestHash,
        bytes32 contentId,
        bytes32 contentLeaf,
        bytes32 tokenDataHash
    );

    function registerCuratedAuction(
        StreamNativeEnglishAuctionState.State storage s,
        mapping(bytes32 => StreamPreparedNativeContentTypes.Selection) storage selections,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        A.Configuration calldata c,
        bytes calldata artwork,
        StreamPreparedNativeContentTypes.Selection calldata selection,
        uint256 expectedSaleNonce,
        A.CreationAuthorization calldata authorization,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) public returns (bytes32 id) {
        StreamNativeEnglishAuctionRuntime.requireNativeContext(x);
        if (s.globalPause.paused || msg.sender != c.poster) revert A.InvalidNativeAuction();
        if (s.creationUsed[authorization.artist][authorization.nonce]) {
            revert A.NativeAuctionAuthorizationUsed(authorization.artist, authorization.nonce);
        }
        (bytes32 digest, StreamRefundWindowSupport.ArtistAssociation memory association) = validateCreation(
            StreamNativeEnglishAuctionRuntime.support(x),
            c,
            artwork,
            authorization,
            platformSignature,
            artistSignature
        );
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamPreparedNativeSettlementAdmission.capture(x.registry, address(this));
        uint256 nonce = ++s.nextNonce;
        if (nonce != expectedSaleNonce) revert A.InvalidNativeAuction();
        bytes32 saleId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                uint8(2),
                c.collectionId,
                c.phaseId,
                nonce
            )
        );
        StreamNativeAuctionContent.requireArtwork(
            saleId,
            c.artworkCommitment,
            c.contentManifestRoot,
            artwork,
            StreamNativeAuctionContent.Selection(
                selection.contentId, selection.tokenDataHash, selection.proof
            )
        );
        (
            IStreamMintManager.MintGateConfig memory gate,
            StreamPreparedNativeContentTypes.Publication memory publication
        ) = StreamPreparedNativeContentReads.requirePublication(
            address(x.base.manager),
            x.registry,
            address(this),
            c.collectionId,
            c.phaseId,
            saleId,
            c.contentManifestRoot
        );
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_AUCTION_V1"),
                block.chainid,
                address(this),
                c.collectionId,
                nonce,
                uint256(0),
                false
            )
        );
        A.Auction storage a = s.auctions[id];
        if (a.status != 0 || s.auctionBySale[saleId] != 0) revert A.InvalidNativeAuction();
        a.config = c;
        a.configHash = authorization.configHash;
        a.saleId = saleId;
        a.saleNonce = nonce;
        a.auctionNonce = nonce;
        a.status = 1;
        a.clock = StreamEnglishAuctionClock.initialize(
            c.clock, c.reservePrice, StreamRefundClock.now64()
        );
        a.pauseBaseline = StreamRefundClock.unionTotal(s.globalPause, s.salePause[saleId]);
        a.bindingGeneration = association.generation;
        a.artistId = association.artistId;
        a.bindingHash = association.bindingHash;
        a.creationDigest = digest;
        a.lifecycle = lifecycle;
        s.auctionBySale[saleId] = id;
        s.artwork[id] = artwork;
        selections[id] = selection;
        s.creationUsed[authorization.artist][authorization.nonce] = true;
        emit NativeAuctionCreated(id, saleId, a.configHash, c, digest);
        emit CuratedAuctionBound(
            id,
            saleId,
            c.contentManifestRoot,
            gate.gate,
            publication.manifestHash,
            selection.contentId,
            c.artworkCommitment,
            selection.tokenDataHash
        );
    }

    function validateCreation(
        StreamRefundWindowSupport.Context memory x,
        IStreamNativeEnglishAuction.Configuration memory c,
        bytes memory artwork,
        IStreamNativeEnglishAuction.CreationAuthorization memory authorization,
        bytes memory platformSignature,
        bytes memory artistSignature
    )
        private
        view
        returns (bytes32 hash, StreamRefundWindowSupport.ArtistAssociation memory association)
    {
        if (!c.mintAtSettlement || c.tokenId != 0 || c.contentManifestRoot == 0) {
            revert IStreamNativeEnglishAuction.UnsupportedNativeAuctionProfile();
        }
        if (
            c.collectionId == 0 || c.phaseId == 0 || c.poster == address(0)
                || c.poster == address(this) || c.artworkCommitment == 0 || artwork.length > 8192
                || c.mintCommitment == 0 || c.primaryPolicyMode != 1
                || c.expectedPrimaryPolicyHash == 0 || c.settlementWindow < 86400
                || c.settlementWindow > 7776000 || c.mintPolicyHash == 0 || authorization.nonce == 0
                || authorization.deadline < block.timestamp || authorization.artist == address(0)
                || authorization.configHash != StreamNativeEnglishAuctionSupport.configHash(c)
        ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        StreamEnglishAuctionClock.initialize(c.clock, c.reservePrice, StreamRefundClock.now64());
        StreamEnglishAuctionClock.minimumBid(
            0, c.reservePrice, c.minIncrementBps, c.incrementFloorWaived
        );
        StreamNativeEnglishAuctionSupport.requirePhase(x, c, false);
        if (
            StreamNativeEnglishAuctionSupport.profilePolicy(x.resolver, c.collectionId)
                != c.expectedPrimaryPolicyHash
        ) {
            revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        }
        StreamRefundWindowSupport.revealPolicy(x, c.collectionId);
        association = StreamRefundWindowSupport.artistAssociation(x, c.collectionId);
        if (
            association.state != 2 || association.authorityStatus != 1 || association.artistId == 0
                || association.generation == 0 || association.bindingHash == 0
                || acceptedArtist(x, c.collectionId) != authorization.artist
        ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        hash = StreamNativeEnglishAuctionSupport.creationDigest(authorization);
        StreamNativeEnglishAuctionSupport.requireSignature(
            x.platform, hash, platformSignature, x.signatureGas
        );
        StreamNativeEnglishAuctionSupport.requireSignature(
            authorization.artist, hash, artistSignature, x.signatureGas
        );
    }

    function acceptedArtist(StreamRefundWindowSupport.Context memory x, uint256 collectionId)
        private
        view
        returns (address artist)
    {
        uint256 cap = x.artistGas;
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 30000) {
            revert IStreamNativeEnglishAuction.NativeAuctionDeliveryGas(available, cap);
        }
        bytes memory data = abi.encodeCall(IStreamArtistAttribution.acceptedArtist, (collectionId));
        address target = address(x.artists);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32 || word > type(uint160).max) {
            revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        }
        return address(uint160(word));
    }

    function batch(
        address manager,
        address recorder,
        StreamPreparedNativeSettlementTypes.Intent memory i,
        bytes memory artwork,
        StreamPreparedNativeContentTypes.Selection memory selection
    )
        public
        view
        returns (IStreamMintManager.MintBatch memory b, bytes32 hash, bytes memory gateData)
    {
        if (
            keccak256(artwork) != selection.tokenDataHash
                || StreamPreparedNativeContentHash.leaf(
                        block.chainid,
                        address(this),
                        i.saleId,
                        selection.contentId,
                        selection.tokenDataHash
                    ) != i.contentSelectionHash
        ) {
            revert IStreamNativeEnglishAuction.NativeAuctionArtworkMismatch();
        }
        hash = StreamPreparedNativeContentHash.intentHash(address(this), recorder, i);
        b.collectionId = i.collectionId;
        b.phaseId = i.phaseId;
        b.payer = i.payer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = address(this);
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = i.beneficiary;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = artwork;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = i.mintCommitment;
        b.expectedPolicyHash = i.boundMintPolicyHash;
        b.authorizationId = hash;
        b.contextHash = StreamPreparedNativeContentHash.context(
            block.chainid, address(this), i.saleId, selection.contentId
        );
        gateData = abi.encode(StreamPreparedNativeContentTypes.GateData(hash, selection));
        manager; // The active installed Manager is independently bound at execution.
    }
}
