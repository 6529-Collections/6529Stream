// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCustodyRightsState.sol";
import "./StreamNativeEnglishAuctionCustodyReads.sol";
import "../revenue/StreamCustodyRightsValidation.sol";
import "../revenue/StreamTokenProfileCustodyHash.sol";

library StreamCustodyRightsActivation {
    event CustodyRightsActivated(
        uint16 schemaVersion,
        bytes32 indexed auctionId,
        uint256 indexed tokenId,
        bytes32 indexed authorizationDigest,
        StreamCustodyRightsTypes.Activation activation
    );

    function activate(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamCustodyRightsState.State storage rights,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        StreamCustodyRightsTypes.Authorization calldata q,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) public {
        StreamTokenProfileCustodyHash.requireLegacy(address(this), q.auctionId);
        IStreamNativeEnglishAuction.Auction storage a =
            StreamNativeEnglishAuctionState.requireAuction(s, q.auctionId);
        StreamNativeCustodySettlementTypes.Origin memory o = custody.origins[q.auctionId];
        (uint64 end,,,) = StreamNativeEnglishAuctionState.deadlines(s, q.auctionId);
        if (
            a.config.mintAtSettlement || a.status != 1 || a.winner.bidIndex != 0
                || a.winner.amount != 0 || StreamNativeEnglishAuctionState.paused(s, a.saleId)
                || (end != 0 && block.timestamp >= end) || msg.sender != a.config.poster
                || rights.activations[q.auctionId].authorizationDigest != 0
                || q.baseConfigHash != a.configHash || q.originHash != keccak256(abi.encode(o))
                || q.tokenId != a.tokenId || q.tokenId == 0 || q.primaryPolicyMode != 1
                || q.rightsMode < 1 || q.rightsMode > 4 || a.config.primaryPolicyMode != 1
                || q.assignmentHash == 0 || q.primaryPolicyHash == 0 || q.artist == address(0)
                || q.nonce == 0 || q.deadline < block.timestamp
                || rights.nonceUsed[q.artist][q.nonce]
        ) {
            revert IStreamCustodyRightsAuction.InvalidCustodyRights();
        }
        StreamNativeEnglishAuctionCustodyReads.requireCustody(x, a, o);
        StreamPrimarySettlementRights.Context memory context = StreamPrimarySettlementRights.Context(
            x.base.resolver, x.factory, x.factory.splitWalletRuntimeCodeHash()
        );
        (StreamSaleTemplate.Selection memory selected, bytes32 policy, bytes32 witness) = StreamCustodyRightsValidation.selection(
            context, a.config.collectionId, a.tokenId, q.rightsMode, a.config.poster
        );
        if (
            selected.assignmentHash != q.assignmentHash || policy != q.primaryPolicyHash
                || _acceptedArtist(x, a.config.collectionId) != q.artist
        ) {
            revert IStreamCustodyRightsAuction.InvalidCustodyRights();
        }
        StreamCustodyRightsTypes.Activation memory activation;
        activation.authorization = q;
        activation.authorizationDigest = StreamCustodyRightsHash.digest(address(this), q);
        uint256 cap = StreamNativeEnglishAuctionRuntime.gasParameter(
            StreamNativeEnglishAuctionRuntime.SIGNATURE_GAS
        );
        StreamNativeEnglishAuctionSupport.requireSignature(
            x.base.platform, activation.authorizationDigest, platformSignature, cap
        );
        StreamNativeEnglishAuctionSupport.requireSignature(
            q.artist, activation.authorizationDigest, artistSignature, cap
        );
        // Signature validation is static, nevertheless re-read the exact selected terms before storage.
        (StreamSaleTemplate.Selection memory after_, bytes32 afterPolicy, bytes32 afterWitness) = StreamCustodyRightsValidation.selection(
            context, a.config.collectionId, a.tokenId, q.rightsMode, a.config.poster
        );
        if (
            keccak256(abi.encode(selected)) != keccak256(abi.encode(after_))
                || policy != afterPolicy || witness != afterWitness
        ) {
            revert IStreamCustodyRightsAuction.InvalidCustodyRights();
        }
        StreamNativeEnglishAuctionCustodyReads.requireCustody(x, a, o);
        activation.effectiveConfigHash =
            StreamCustodyRightsHash.configuration(address(this), activation);
        rights.nonceUsed[q.artist][q.nonce] = true;
        rights.activations[q.auctionId] = activation;
        emit CustodyRightsActivated(
            1, q.auctionId, q.tokenId, activation.authorizationDigest, activation
        );
    }

    function _acceptedArtist(StreamNativeEnglishAuctionRuntime.Context memory x, uint256 collection)
        private
        view
        returns (address)
    {
        uint256 cap = StreamNativeEnglishAuctionRuntime.gasParameter(
            StreamNativeEnglishAuctionRuntime.ARTIST_GAS
        );
        StreamNativeEnglishAuctionRuntime.admitDelivery(cap);
        bytes memory data = abi.encodeCall(IStreamArtistAttribution.acceptedArtist, (collection));
        address target = address(x.base.artists);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32 || word > type(uint160).max) {
            revert IStreamCustodyRightsAuction.InvalidCustodyRights();
        }
        return address(uint160(word));
    }
}
