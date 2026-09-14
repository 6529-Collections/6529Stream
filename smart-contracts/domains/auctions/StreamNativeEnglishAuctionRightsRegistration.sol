// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeEnglishAuctionRuntime.sol";
import "../revenue/StreamPreparedNativeRightsProjection.sol";
import "../../interfaces/stream/auctions/IStreamNativeRightsAuction.sol";
import {
    IStreamNativeEnglishAuction as A
} from "../../interfaces/stream/auctions/IStreamNativeEnglishAuction.sol";

/// @notice New rights configuration authorization with original sale/auction nonce domains.
library StreamNativeEnglishAuctionRightsRegistration {
    event NativeAuctionCreated(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        A.Configuration config,
        bytes32 creationDigest
    );
    event NativeAuctionRightsBound(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint8 mode,
        bytes32 originalAssignmentHash,
        bytes32 originalTemplateId
    );

    function configHash(
        A.Configuration memory config,
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_ENGLISH_RIGHTS_CONFIG_V1"),
                block.chainid,
                address(this),
                config,
                original
            )
        );
    }

    function registerRightsAuction(
        StreamNativeEnglishAuctionState.State storage s,
        mapping(bytes32 => StreamPreparedNativeRightsTypes.OriginalPolicy) storage policies,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        A.Configuration calldata c,
        StreamPreparedNativeRightsTypes.OriginalPolicy calldata original,
        bytes calldata artwork,
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
            original,
            artwork,
            authorization,
            platformSignature,
            artistSignature
        );
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle =
            StreamPreparedNativeSettlementAdmission.capture(x.registry, address(this));
        uint256 nonce = ++s.nextNonce;
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
        policies[id] = original;
        s.creationUsed[authorization.artist][authorization.nonce] = true;
        emit NativeAuctionCreated(id, saleId, a.configHash, c, digest);
        emit NativeAuctionRightsBound(
            id, saleId, original.mode, original.assignmentHash, original.templateId
        );
    }

    function validateCreation(
        StreamRefundWindowSupport.Context memory x,
        IStreamNativeEnglishAuction.Configuration memory c,
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original,
        bytes memory artwork,
        IStreamNativeEnglishAuction.CreationAuthorization memory authorization,
        bytes memory platformSignature,
        bytes memory artistSignature
    )
        public
        view
        returns (bytes32 hash, StreamRefundWindowSupport.ArtistAssociation memory association)
    {
        if (!c.mintAtSettlement || c.tokenId != 0 || c.contentManifestRoot != 0) {
            revert IStreamNativeEnglishAuction.UnsupportedNativeAuctionProfile();
        }
        if (
            c.collectionId == 0 || c.phaseId == 0 || c.poster == address(0)
                || c.poster == address(this) || c.artworkCommitment == 0
                || c.artworkCommitment != keccak256(artwork) || artwork.length > 8192
                || c.mintCommitment == 0 || c.primaryPolicyMode != 1
                || c.expectedPrimaryPolicyHash == 0 || c.settlementWindow < 86400
                || c.settlementWindow > 7776000 || c.mintPolicyHash == 0 || authorization.nonce == 0
                || authorization.deadline < block.timestamp || authorization.artist == address(0)
                || authorization.configHash != configHash(c, original)
        ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        StreamEnglishAuctionClock.initialize(c.clock, c.reservePrice, StreamRefundClock.now64());
        StreamEnglishAuctionClock.minimumBid(
            0, c.reservePrice, c.minIncrementBps, c.incrementFloorWaived
        );
        StreamNativeEnglishAuctionSupport.requirePhase(x, c, false);
        StreamSaleTemplate.Selection memory selection =
            StreamPreparedNativeRightsProjection.collectionTemplateForPoster(
                x.resolver, c.collectionId, original.mode, c.poster
            );
        if (
            (original.mode != StreamPreparedNativeRightsTypes.COLLECTION_TEMPLATE
                    && original.mode
                        != StreamPreparedNativeRightsTypes.CONSENTED_COLLECTION_TEMPLATE
                    && original.mode != StreamPreparedNativeRightsTypes.DYNAMIC_COLLECTION_TEMPLATE)
                || original.assignmentHash != selection.assignmentHash
                || original.templateId != selection.templateId
                || StreamPreparedNativeRightsProjection.policyHash(
                        x.resolver, c.collectionId, 0, selection
                    ) != c.expectedPrimaryPolicyHash
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
}
