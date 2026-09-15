// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPlatformTokenCustodyState.sol";
import "./StreamNativeEnglishAuctionCustodyReads.sol";
import "../revenue/StreamPlatformTokenCustodyValidation.sol";
import "../revenue/StreamTokenProfileCustodyHash.sol";
import "../revenue/StreamCustodyRightsHash.sol";
import "../../interfaces/stream/revenue/IStreamPlatformTokenCustodySettlement.sol";

library StreamPlatformTokenCustodyActivation {
    event PlatformTokenCustodyActivated(
        uint16 schemaVersion,
        bytes32 indexed auctionId,
        uint256 indexed tokenId,
        bytes32 indexed authorizationDigest,
        StreamPlatformTokenCustodyTypes.Activation activation
    );

    function fromCalldata(
        StreamNativeEnglishAuctionState.State storage s,
        StreamNativeEnglishAuctionCustodyState.State storage custody,
        StreamPlatformTokenCustodyState.State storage rights,
        StreamNativeEnglishAuctionRuntime.Context memory x,
        bytes calldata data
    ) public {
        if (
            bytes4(data[:4])
                != IStreamPlatformTokenCustodyAuction.activatePlatformTokenCustody.selector
        ) revert IStreamPlatformTokenCustodyAuction.InvalidPlatformTokenCustody();
        (StreamPlatformTokenCustodyTypes.Authorization memory q, bytes memory signature) =
            abi.decode(data[4:], (StreamPlatformTokenCustodyTypes.Authorization, bytes));
        StreamTokenProfileCustodyHash.requireLegacy(address(this), q.auctionId);
        StreamCustodyRightsHash.requireLegacy(address(this), q.auctionId);
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
                || a.config.primaryPolicyMode != 1 || (q.rightsMode != 12 && q.rightsMode != 13)
                || q.assignmentHash == 0 || q.primaryPolicyHash == 0 || q.declarationHash == 0
                || q.nonce == 0 || q.deadline < block.timestamp || rights.nonceUsed[q.nonce]
        ) revert IStreamPlatformTokenCustodyAuction.InvalidPlatformTokenCustody();
        if (
            !IERC165(x.recorder)
                    .supportsInterface(type(IStreamPlatformTokenCustodySettlement).interfaceId)
                || !IStreamPlatformTokenCustodySettlement(x.recorder)
                    .isStreamPlatformTokenCustodySettlement()
        ) revert IStreamPlatformTokenCustodyAuction.InvalidPlatformTokenCustody();
        StreamNativeEnglishAuctionCustodyReads.requireCustody(x, a, o);
        StreamNativeCustodySettlementTypes.Facts memory f =
            StreamNativeCustodySettlementTypes.Facts(q.auctionId, a, o);
        (bytes32 declaration, StreamPreparedNativeRightsTypes.OriginalPolicy memory original) =
            StreamPlatformCustodyValidation.binding(x.base.resolver, address(this), f);
        if (declaration != q.declarationHash) {
            revert IStreamPlatformTokenCustodyAuction.InvalidPlatformTokenCustody();
        }
        (StreamSaleTemplate.Selection memory selected, bytes32 witness) = StreamPlatformTokenPrimary.resolve(
            x.base.resolver, a.config.collectionId, a.tokenId, q.rightsMode, a.config.poster
        );
        if (
            selected.assignmentHash != q.assignmentHash
                || StreamPreparedNativeRightsProjection.policyHash(
                        x.base.resolver, a.config.collectionId, a.tokenId, selected
                    ) != q.primaryPolicyHash
        ) revert IStreamPlatformTokenCustodyAuction.InvalidPlatformTokenCustody();
        StreamPlatformTokenCustodyTypes.Activation memory appended;
        appended.authorization = q;
        appended.authorizationDigest = StreamPlatformTokenCustodyHash.digest(address(this), q);
        StreamNativeEnglishAuctionSupport.requireSignature(
            x.base.platform,
            appended.authorizationDigest,
            signature,
            StreamNativeEnglishAuctionRuntime.gasParameter(
                StreamNativeEnglishAuctionRuntime.SIGNATURE_GAS
            )
        );
        (StreamSaleTemplate.Selection memory current, bytes32 afterWitness) = StreamPlatformTokenPrimary.resolve(
            x.base.resolver, a.config.collectionId, a.tokenId, q.rightsMode, a.config.poster
        );
        (
            bytes32 afterDeclaration,
            StreamPreparedNativeRightsTypes.OriginalPolicy memory afterOriginal
        ) = StreamPlatformCustodyValidation.binding(x.base.resolver, address(this), f);
        if (
            keccak256(abi.encode(selected)) != keccak256(abi.encode(current))
                || witness != afterWitness || declaration != afterDeclaration
                || keccak256(abi.encode(original)) != keccak256(abi.encode(afterOriginal))
        ) revert IStreamPlatformTokenCustodyAuction.InvalidPlatformTokenCustody();
        StreamNativeEnglishAuctionCustodyReads.requireCustody(x, a, o);
        appended.effectiveConfigHash =
            StreamPlatformTokenCustodyHash.configuration(address(this), appended);
        rights.nonceUsed[q.nonce] = true;
        rights.activations[q.auctionId] = appended;
        emit PlatformTokenCustodyActivated(
            1, q.auctionId, q.tokenId, appended.authorizationDigest, appended
        );
    }

    function read(StreamPlatformTokenCustodyState.State storage s, uint8 kind, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        if (
            kind == 1
                && bytes4(data[:4])
                    == IStreamPlatformTokenCustodyAuction.platformTokenCustodyDigest.selector
        ) {
            return abi.encode(
                StreamPlatformTokenCustodyHash.digest(
                    address(this),
                    abi.decode(data[4:], (StreamPlatformTokenCustodyTypes.Authorization))
                )
            );
        }
        bytes32 key = abi.decode(data[4:], (bytes32));
        if (
            kind == 2
                && bytes4(data[:4])
                    == IStreamPlatformTokenCustodyAuction.platformTokenCustodyActivation.selector
        ) return abi.encode(s.activations[key]);
        if (
            kind == 3
                && bytes4(data[:4])
                    == IStreamPlatformTokenCustodyAuction.platformTokenCustodyConfigurationHash
                    .selector
        ) return abi.encode(s.activations[key].effectiveConfigHash);
        if (
            kind == 4
                && bytes4(data[:4])
                    == IStreamPlatformTokenCustodyAuction.platformTokenCustodyNonceUsed.selector
        ) return abi.encode(s.nonceUsed[key]);
        revert IStreamPlatformTokenCustodyAuction.InvalidPlatformTokenCustody();
    }

    function effective(StreamPlatformTokenCustodyState.State storage s, bytes32 id)
        public
        view
        returns (uint8, bytes32)
    {
        StreamPlatformTokenCustodyTypes.Activation storage a = s.activations[id];
        if (a.authorizationDigest == 0) {
            revert IStreamPlatformTokenCustodyAuction.InvalidPlatformTokenCustody();
        }
        return (a.authorization.rightsMode, a.effectiveConfigHash);
    }
}
