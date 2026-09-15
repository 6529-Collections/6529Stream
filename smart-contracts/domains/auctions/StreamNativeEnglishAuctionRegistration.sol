// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../revenue/StreamPlatformCustodyValidation.sol";
import "./StreamNativeEnglishAuctionRuntime.sol";
import "./StreamNativeEnglishAuctionCustodyReads.sol";
import "../revenue/StreamTokenProfileCustodyValidation.sol";
import "../revenue/StreamCustodyRightsValidation.sol";
import "../revenue/StreamPreparedNativeRightsProjection.sol";
import {
    IStreamNativeEnglishAuction as A
} from "../../interfaces/stream/auctions/IStreamNativeEnglishAuction.sol";

/// @notice Original registration and bid admission executed in the fixed house context.
library StreamNativeEnglishAuctionRegistration {
    event NativeAuctionCreated(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        A.Configuration config,
        bytes32 creationDigest
    );

    function registerAuction(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        A.Configuration calldata c,
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
        (bytes32 digest, StreamRefundWindowSupport.ArtistAssociation memory association) = StreamNativeEnglishAuctionSupport.validateCreation(
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
        s.creationUsed[authorization.artist][authorization.nonce] = true;
        emit NativeAuctionCreated(id, saleId, a.configHash, c, digest);
    }

    function bidPublic(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        uint8 rightsMode,
        bytes32 id,
        address deliverTo,
        StreamNativeAuctionDelegation.Witness memory witness,
        bool allowNew
    ) public {
        bidPublicForConfiguration(
            s, x, rightsMode, id, deliverTo, witness, allowNew, s.auctions[id].configHash, false
        );
    }

    function bidPublicForConfiguration(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        uint8 rightsMode,
        bytes32 id,
        address deliverTo,
        StreamNativeAuctionDelegation.Witness memory witness,
        bool allowNew,
        bytes32 effectiveConfigHash,
        bool tokenProfile
    ) public {
        A.Auction storage a = StreamNativeEnglishAuctionState.requireAuction(s, id);
        uint256 fee = tokenProfile ? _tokenProfileBidPrecheck(x, a) : _bidPrecheck(x, a, rightsMode);
        if (msg.sender == address(this) || msg.value <= fee) revert A.InvalidNativeAuction();
        address recipient = _delivery(s, x, id, msg.sender, deliverTo, witness, allowNew);
        bytes32 digest = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_ENGLISH_PUBLIC_BID_V1"),
                block.chainid,
                address(this),
                id,
                effectiveConfigHash,
                msg.sender,
                recipient,
                msg.value - fee,
                fee,
                a.winner.bidIndex + 1
            )
        );
        StreamNativeEnglishAuctionState.placeBid(
            s,
            id,
            A.WinningBid(
                msg.sender, msg.sender, recipient, msg.value - fee, fee, 0, digest, 0, false
            )
        );
    }

    function bidSigned(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        uint8 rightsMode,
        A.BidAuthorization calldata authorization,
        bytes calldata signature,
        StreamNativeAuctionDelegation.Witness memory witness,
        bool allowNew
    ) public {
        bidSignedForConfiguration(
            s,
            x,
            rightsMode,
            authorization,
            signature,
            witness,
            allowNew,
            s.auctions[authorization.auctionId].configHash,
            false
        );
    }

    function bidSignedForConfiguration(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        uint8 rightsMode,
        A.BidAuthorization calldata authorization,
        bytes calldata signature,
        StreamNativeAuctionDelegation.Witness memory witness,
        bool allowNew,
        bytes32 effectiveConfigHash,
        bool tokenProfile
    ) public {
        A.Auction storage a = StreamNativeEnglishAuctionState.requireAuction(
            s, authorization.auctionId
        );
        uint256 fee = tokenProfile ? _tokenProfileBidPrecheck(x, a) : _bidPrecheck(x, a, rightsMode);
        if (
            authorization.payer == address(0) || authorization.payer == address(this)
                || authorization.executor != msg.sender
                || authorization.configHash != effectiveConfigHash || authorization.amount == 0
                || authorization.nonce == 0 || authorization.deadline < block.timestamp
                || fee > authorization.maxRevealFee || msg.value != authorization.amount + fee
        ) revert A.InvalidNativeAuction();
        if (s.bidUsed[authorization.payer][authorization.nonce]) {
            revert A.NativeAuctionAuthorizationUsed(authorization.payer, authorization.nonce);
        }
        bytes32 digest = StreamNativeEnglishAuctionSupport.bidDigest(authorization);
        StreamNativeEnglishAuctionSupport.requireSignature(
            authorization.payer,
            digest,
            signature,
            StreamNativeEnglishAuctionRuntime.gasParameter(
                StreamNativeEnglishAuctionRuntime.SIGNATURE_GAS
            )
        );
        s.bidUsed[authorization.payer][authorization.nonce] = true;
        StreamNativeEnglishAuctionState.placeBid(
            s,
            authorization.auctionId,
            A.WinningBid(
                authorization.payer,
                msg.sender,
                _delivery(
                    s,
                    x,
                    authorization.auctionId,
                    authorization.payer,
                    authorization.deliverTo,
                    witness,
                    allowNew
                ),
                authorization.amount,
                fee,
                0,
                digest,
                authorization.finalizeBy,
                true
            )
        );
    }

    function _delivery(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes32 id,
        address payer,
        address target,
        StreamNativeAuctionDelegation.Witness memory witness,
        bool allowNew
    ) private view returns (address) {
        bool newDelegate = s.delivery[id][payer] == address(0) && target != address(0)
            && target != payer;
        if (newDelegate && (!allowNew || x.delegation.delegateRegistry == address(0))) {
            revert A.UnsupportedNativeAuctionProfile();
        }
        return StreamNativeAuctionDelegation.resolveDelivery(
            s.delivery,
            x.delegation,
            id,
            payer,
            target,
            witness,
            newDelegate
                ? StreamNativeEnglishAuctionRuntime.gasParameter(
                    StreamNativeAuctionDelegation.GAS_PARAMETER
                )
                : 0
        );
    }

    function _bidPrecheck(
        StreamNativeEnglishAuctionRuntime.Context memory x,
        A.Auction storage a,
        uint8 rightsMode
    ) private view returns (uint256 fee) {
        if (!a.config.mintAtSettlement) {
            bytes32 id = keccak256(
                abi.encode(
                    keccak256("6529STREAM_AUCTION_V1"),
                    block.chainid,
                    address(this),
                    a.config.collectionId,
                    a.auctionNonce,
                    a.config.tokenId,
                    false
                )
            );
            StreamNativeCustodySettlementTypes.Origin memory origin =
                IStreamNativeCustodyAuction(address(this)).custodyOrigin(id);
            if (rightsMode >= 8 && rightsMode <= 11) {
                StreamNativeEnglishAuctionCustodyReads.requireCustody(x, a, origin);
                StreamPlatformCustodyValidation.derive(
                    StreamPrimarySettlementRights.Context(
                        x.base.resolver, x.factory, x.factory.splitWalletRuntimeCodeHash()
                    ),
                    StreamNativeCustodySettlementTypes.Facts(id, a, origin),
                    address(this),
                    x.recorder
                );
            } else {
                StreamNativeEnglishAuctionCustodyReads.requireCurrent(x, a, origin);
            }
            StreamPreparedNativeSettlementAdmission.capture(x.registry, address(this));
            return 0;
        }
        StreamNativeEnglishAuctionRuntime.requireNativeContext(x);
        StreamNativeEnglishAuctionRuntime.requireRetained(x, a);
        StreamPreparedNativeSettlementAdmission.capture(x.registry, address(this));
        StreamNativeEnglishAuctionSupport.requirePhase(
            StreamNativeEnglishAuctionRuntime.support(x), a.config, true
        );
        if (rightsMode == 0) {
            StreamNativeEnglishAuctionSupport.profilePolicy(x.base.resolver, a.config.collectionId);
        } else if (
            rightsMode == StreamPreparedNativeRightsTypes.COLLECTION_TEMPLATE
                || rightsMode == StreamPreparedNativeRightsTypes.CONSENTED_COLLECTION_TEMPLATE
                || rightsMode == StreamPreparedNativeRightsTypes.DYNAMIC_COLLECTION_TEMPLATE
                || rightsMode == StreamPreparedNativeRightsTypes.DEFAULT_PROFILE
                || rightsMode == StreamPreparedNativeRightsTypes.DEFAULT_TEMPLATE
                || rightsMode == StreamPreparedNativeRightsTypes.CONSENTED_DEFAULT_TEMPLATE
                || rightsMode == StreamPreparedNativeRightsTypes.DYNAMIC_DEFAULT_TEMPLATE
                || rightsMode == StreamPreparedNativeRightsTypes.PLATFORM_COLLECTION_TEMPLATE
                || rightsMode == StreamPreparedNativeRightsTypes.PLATFORM_DEFAULT_TEMPLATE
                || rightsMode == StreamPreparedNativeRightsTypes.PLATFORM_COLLECTION_PROFILE
                || rightsMode == StreamPreparedNativeRightsTypes.PLATFORM_DEFAULT_PROFILE
        ) {
            StreamPreparedNativeRightsProjection.collectionTemplateForPoster(
                x.base.resolver, a.config.collectionId, rightsMode, a.config.poster
            );
        } else {
            revert A.UnsupportedNativeAuctionProfile();
        }
        fee =
        StreamRefundWindowSupport.revealPolicy(
            StreamNativeEnglishAuctionRuntime.support(x), a.config.collectionId
        )
        .revealFeePerTokenWei;
    }

    function _tokenProfileBidPrecheck(
        StreamNativeEnglishAuctionRuntime.Context memory x,
        A.Auction storage a
    ) private view returns (uint256) {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_AUCTION_V1"),
                block.chainid,
                address(this),
                a.config.collectionId,
                a.auctionNonce,
                a.config.tokenId,
                false
            )
        );
        StreamNativeCustodySettlementTypes.Origin memory o =
            IStreamNativeCustodyAuction(address(this)).custodyOrigin(id);
        StreamNativeEnglishAuctionCustodyReads.requireCustody(x, a, o);
        StreamNativeCustodySettlementTypes.Facts memory f =
            StreamNativeCustodySettlementTypes.Facts(id, a, o);
        StreamCustodyRightsTypes.Activation memory extra =
            StreamCustodyRightsHash.readOptional(address(this), id);
        if (extra.authorizationDigest != 0) {
            StreamCustodyRightsValidation.activation(address(this), f);
            StreamCustodyRightsValidation.selection(
                StreamPrimarySettlementRights.Context(
                    x.base.resolver, x.factory, x.factory.splitWalletRuntimeCodeHash()
                ),
                a.config.collectionId,
                a.tokenId,
                extra.authorization.rightsMode,
                a.config.poster
            );
        } else {
            StreamTokenProfileCustodyValidation.activation(address(this), f);
            StreamTokenProfileCustodyValidation.selection(
                StreamPrimarySettlementRights.Context(
                    x.base.resolver, x.factory, x.factory.splitWalletRuntimeCodeHash()
                ),
                a.config.collectionId,
                a.tokenId
            );
        }
        StreamPreparedNativeSettlementAdmission.capture(x.registry, address(this));
        return 0;
    }
}
