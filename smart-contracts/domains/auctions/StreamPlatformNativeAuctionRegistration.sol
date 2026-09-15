// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeEnglishAuctionRuntime.sol";
import "../revenue/StreamPreparedNativeRightsProjection.sol";
import "../mint/StreamPlatformSaleTemplate.sol";
import "../../interfaces/stream/revenue/IStreamPlatformNativePrimarySettlement.sol";
import {
    IStreamPlatformNativeRightsAuction as P
} from "../../interfaces/stream/auctions/IStreamPlatformNativeRightsAuction.sol";
import {
    IStreamNativeEnglishAuction as A
} from "../../interfaces/stream/auctions/IStreamNativeEnglishAuction.sol";

/// @notice New explicit platform-only creation authority; original auction allocation and replay.
library StreamPlatformNativeAuctionRegistration {
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
    event PlatformNativeAuctionBound(
        uint16 schemaVersion,
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        bytes32 indexed declarationHash,
        uint8 mode,
        bytes32 configHash,
        bytes32 creationDigest
    );

    function configHash(
        A.Configuration memory c,
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original,
        bytes32 declarationHash
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PLATFORM_NATIVE_RIGHTS_CONFIG_V1"),
                block.chainid,
                address(this),
                c,
                original,
                declarationHash
            )
        );
    }

    function creationDigest(P.PlatformCreationAuthorization memory a)
        public
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamPlatformNativeRightsAuction"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
        return keccak256(
            abi.encodePacked(
                hex"1901",
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "PlatformNativeAuctionCreation(bytes32 configHash,bytes32 declarationHash,bytes32 nonce,uint64 deadline)"
                        ),
                        a
                    )
                )
            )
        );
    }

    function configHashFromCalldata(bytes calldata input) public view returns (bytes32) {
        if (bytes4(input[:4]) != P.platformRightsConfigurationHash.selector) {
            revert A.InvalidNativeAuction();
        }
        (
            A.Configuration memory c,
            StreamPreparedNativeRightsTypes.OriginalPolicy memory original,
            bytes32 declarationHash
        ) = abi.decode(
            input[4:], (A.Configuration, StreamPreparedNativeRightsTypes.OriginalPolicy, bytes32)
        );
        return configHash(c, original, declarationHash);
    }

    function registerCalldata(
        StreamNativeEnglishAuctionState.State storage s,
        mapping(bytes32 => StreamPreparedNativeRightsTypes.OriginalPolicy) storage policies,
        mapping(bytes32 => bytes32) storage declarations,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes calldata input
    ) public returns (bytes32) {
        if (bytes4(input[:4]) != P.registerPlatformRightsAuction.selector) {
            revert A.InvalidNativeAuction();
        }
        (
            A.Configuration memory c,
            StreamPreparedNativeRightsTypes.OriginalPolicy memory original,
            bytes memory artwork,
            P.PlatformCreationAuthorization memory authorization,
            bytes memory signature
        ) = abi.decode(
            input[4:],
            (
                A.Configuration,
                StreamPreparedNativeRightsTypes.OriginalPolicy,
                bytes,
                P.PlatformCreationAuthorization,
                bytes
            )
        );
        return
            _register(s, policies, declarations, x, c, original, artwork, authorization, signature);
    }

    function _register(
        StreamNativeEnglishAuctionState.State storage s,
        mapping(bytes32 => StreamPreparedNativeRightsTypes.OriginalPolicy) storage policies,
        mapping(bytes32 => bytes32) storage declarations,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        A.Configuration memory c,
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original,
        bytes memory artwork,
        P.PlatformCreationAuthorization memory authorization,
        bytes memory platformSignature
    ) private returns (bytes32 id) {
        StreamNativeEnglishAuctionRuntime.requireNativeContext(x);
        if (
            !IERC165(x.recorder)
                    .supportsInterface(type(IStreamPlatformNativePrimarySettlement).interfaceId)
                || !IStreamPlatformNativePrimarySettlement(x.recorder)
                    .isStreamPlatformNativePrimarySettlement()
        ) {
            revert A.UnsupportedNativeAuctionProfile();
        }
        if (s.globalPause.paused || msg.sender != c.poster) revert A.InvalidNativeAuction();
        if (s.creationUsed[x.base.platform][authorization.nonce]) {
            revert A.NativeAuctionAuthorizationUsed(x.base.platform, authorization.nonce);
        }
        bytes32 digest = validate(
            StreamNativeEnglishAuctionRuntime.support(x),
            c,
            original,
            artwork,
            authorization,
            platformSignature
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
        a.creationDigest = digest;
        a.lifecycle = lifecycle;
        s.auctionBySale[saleId] = id;
        s.artwork[id] = artwork;
        policies[id] = original;
        s.creationUsed[x.base.platform][authorization.nonce] = true;
        emit NativeAuctionCreated(id, saleId, a.configHash, c, digest);
        declarations[saleId] = authorization.declarationHash;
        emit NativeAuctionRightsBound(
            id, saleId, original.mode, original.assignmentHash, original.templateId
        );
        emit PlatformNativeAuctionBound(
            1, id, saleId, authorization.declarationHash, original.mode, a.configHash, digest
        );
    }

    function validate(
        StreamRefundWindowSupport.Context memory x,
        A.Configuration memory c,
        StreamPreparedNativeRightsTypes.OriginalPolicy memory original,
        bytes memory artwork,
        P.PlatformCreationAuthorization memory authorization,
        bytes memory platformSignature
    ) private view returns (bytes32 digest) {
        if (!c.mintAtSettlement || c.tokenId != 0 || c.contentManifestRoot != 0) {
            revert A.UnsupportedNativeAuctionProfile();
        }
        if (
            c.collectionId == 0 || c.phaseId == 0 || c.poster == address(0)
                || c.poster == address(this) || c.artworkCommitment == 0
                || c.artworkCommitment != keccak256(artwork) || artwork.length > 8192
                || c.mintCommitment == 0 || c.primaryPolicyMode != 1
                || c.expectedPrimaryPolicyHash == 0 || c.settlementWindow < 86400
                || c.settlementWindow > 7776000 || c.mintPolicyHash == 0 || authorization.nonce == 0
                || authorization.deadline < block.timestamp || authorization.declarationHash == 0
                || (original.mode != 8 && original.mode != 9)
                || authorization.configHash
                    != configHash(c, original, authorization.declarationHash)
        ) {
            revert A.InvalidNativeAuction();
        }
        StreamEnglishAuctionClock.initialize(c.clock, c.reservePrice, StreamRefundClock.now64());
        StreamEnglishAuctionClock.minimumBid(
            0, c.reservePrice, c.minIncrementBps, c.incrementFloorWaived
        );
        StreamNativeEnglishAuctionSupport.requirePhase(x, c, false);
        (StreamSaleTemplate.Selection memory selected,) = StreamPlatformSaleTemplate.resolve(
            x.resolver, c.collectionId, 0, original.mode, c.poster
        );
        if (
            original.assignmentHash != selected.assignmentHash
                || original.templateId != selected.templateId
                || StreamPreparedNativeRightsProjection.policyHash(
                        x.resolver, c.collectionId, 0, selected
                    ) != c.expectedPrimaryPolicyHash
                || StreamPlatformSaleTemplate.declaration(x.resolver, c.collectionId)
                    != authorization.declarationHash
        ) {
            revert A.InvalidNativeAuction();
        }
        StreamRefundWindowSupport.revealPolicy(x, c.collectionId);
        digest = creationDigest(authorization);
        StreamNativeEnglishAuctionSupport.requireSignature(
            x.platform, digest, platformSignature, x.signatureGas
        );
        if (
            StreamPlatformSaleTemplate.declaration(x.resolver, c.collectionId)
                != authorization.declarationHash
        ) {
            revert A.InvalidNativeAuction();
        }
    }
}
