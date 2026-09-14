// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/auctions/IStreamNativeEnglishAuction.sol";
import "../mint/StreamRefundWindowSupport.sol";
import "../mint/StreamRefundClock.sol";
import "../revenue/StreamPreparedNativeSettlementHash.sol";
import "../../interfaces/stream/mint/IStreamPreparedNativeMint.sol";

/// @notice Original creation/bid authorization and exact prepared-mint projection.
/// @dev New versioned entry domains leave historical auction and mint preimages unchanged.
library StreamNativeEnglishAuctionSupport {
    bytes32 private constant CREATION = keccak256(
        "NativeAuctionCreation(bytes32 configHash,address artist,bytes32 nonce,uint64 deadline)"
    );
    bytes32 private constant BID = keccak256(
        "NativeAuctionBid(bytes32 auctionId,bytes32 configHash,address payer,address executor,address deliverTo,uint256 amount,uint256 maxRevealFee,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
    );

    function configHash(IStreamNativeEnglishAuction.Configuration memory c)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_ENGLISH_AUCTION_CONFIG_V1"),
                block.chainid,
                address(this),
                c
            )
        );
    }

    function creationDigest(IStreamNativeEnglishAuction.CreationAuthorization memory a)
        public
        view
        returns (bytes32)
    {
        return digest(keccak256(abi.encode(CREATION, a)));
    }

    function bidDigest(IStreamNativeEnglishAuction.BidAuthorization memory a)
        public
        view
        returns (bytes32)
    {
        return digest(keccak256(abi.encode(BID, a)));
    }

    function digest(bytes32 body) private view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamNativeEnglishAuction"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, body));
    }

    function validateCreation(
        StreamRefundWindowSupport.Context memory x,
        IStreamNativeEnglishAuction.Configuration memory c,
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
                || authorization.configHash != configHash(c)
        ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        StreamEnglishAuctionClock.initialize(c.clock, c.reservePrice, StreamRefundClock.now64());
        StreamEnglishAuctionClock.minimumBid(
            0, c.reservePrice, c.minIncrementBps, c.incrementFloorWaived
        );
        requirePhase(x, c, false);
        if (profilePolicy(x.resolver, c.collectionId) != c.expectedPrimaryPolicyHash) {
            revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        }
        StreamRefundWindowSupport.revealPolicy(x, c.collectionId);
        association = StreamRefundWindowSupport.artistAssociation(x, c.collectionId);
        if (
            association.state != 2 || association.authorityStatus != 1 || association.artistId == 0
                || association.generation == 0 || association.bindingHash == 0
                || acceptedArtist(x, c.collectionId) != authorization.artist
        ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
        hash = creationDigest(authorization);
        requireSignature(x.platform, hash, platformSignature, x.signatureGas);
        requireSignature(authorization.artist, hash, artistSignature, x.signatureGas);
    }

    function requireSignature(address signer, bytes32 hash, bytes memory signature, uint256 cap)
        public
        view
    {
        if (!StreamNativeSettlementSupport.validSignature(signer, hash, signature, cap)) {
            revert IStreamNativeEnglishAuction.NativeAuctionAuthorizationInvalid(signer);
        }
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

    function requirePhase(
        StreamRefundWindowSupport.Context memory x,
        IStreamNativeEnglishAuction.Configuration memory c,
        bool live
    ) public view {
        IStreamMintReads manager = IStreamMintReads(address(x.manager));
        (bool exists, IStreamMintManager.MintPhaseConfig memory phase) =
            manager.phase(c.collectionId, c.phaseId);
        if (
            !exists || phase.paused
                || !manager.phaseExecutor(c.collectionId, c.phaseId, address(this))
                || manager.phaseGate(c.collectionId, c.phaseId).gate != address(0)
        ) revert IStreamNativeEnglishAuction.UnsupportedNativeAuctionProfile();
        bytes32 current = manager.phasePolicyHash(c.collectionId, c.phaseId);
        if (current != c.mintPolicyHash) {
            (bytes32 prior, uint64 until) = manager.phasePolicyGrace(c.collectionId, c.phaseId);
            if (!live || prior != c.mintPolicyHash || block.timestamp > until) {
                revert IStreamNativeEnglishAuction.InvalidNativeAuction();
            }
        }
        if (
            live
                && (block.timestamp < phase.startTime
                    || (phase.endTime != 0 && block.timestamp > phase.endTime))
        ) revert IStreamNativeEnglishAuction.InvalidNativeAuction();
    }

    function profilePolicy(IStreamRevenueResolver resolver, uint256 collectionId)
        public
        view
        returns (bytes32)
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(collectionId, 0, keccak256("PRIMARY_SALE"));
        if (
            !a.exists || a.assignmentType != 1 || a.scope != 1 || a.scopeId != collectionId
                || a.profileId == 0 || a.templateId != 0 || a.assignmentHash == 0
                || a.policyHash != 0
        ) revert IStreamNativeEnglishAuction.UnsupportedNativeAuctionProfile();
        return StreamSaleTemplate.policyHash(
            resolver, collectionId, StreamNativeSettlementSupport.rights(resolver, collectionId)
        );
    }

    function intent(IStreamNativeEnglishAuction.Auction memory a)
        public
        view
        returns (StreamPreparedNativeSettlementTypes.Intent memory i)
    {
        i.collectionId = a.config.collectionId;
        i.phaseId = a.config.phaseId;
        i.saleId = a.saleId;
        i.saleNonce = a.saleNonce;
        i.executor = a.winner.executor;
        i.payer = a.winner.payer;
        i.poster = a.config.poster;
        i.beneficiary = a.winner.deliverTo;
        i.amount = a.winner.amount;
        i.primaryPolicyMode = a.config.primaryPolicyMode;
        i.originalPrimaryPolicyHash = a.config.expectedPrimaryPolicyHash;
        i.executionNonce = a.winner.bidIndex;
        i.authorityMode = a.winner.signed ? 1 : 2;
        i.saleAuthorizationDigest = a.winner.authorizationDigest;
        i.saleExecutionHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_ENGLISH_AUCTION_EXECUTION_V1"),
                block.chainid,
                address(this),
                a.configHash,
                a.creationDigest,
                a.saleId,
                a.winner
            )
        );
        i.contentSelectionHash = a.config.artworkCommitment;
        i.mintCommitment = a.config.mintCommitment;
        i.boundMintPolicyHash = a.config.mintPolicyHash;
    }

    function batch(
        address manager,
        address recorder,
        StreamPreparedNativeSettlementTypes.Intent memory i,
        bytes memory artwork
    ) public view returns (IStreamMintManager.MintBatch memory b, bytes32 hash) {
        if (keccak256(artwork) != i.contentSelectionHash) {
            revert IStreamNativeEnglishAuction.NativeAuctionArtworkMismatch();
        }
        hash = StreamPreparedNativeSettlementHash.intentHash(address(this), recorder, i);
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
        b.contextHash = StreamPreparedNativeSettlementHash.mintContext(manager, address(this), hash);
    }
}
