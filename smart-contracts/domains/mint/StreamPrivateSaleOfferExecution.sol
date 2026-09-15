// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPrivateSaleAccounting.sol";
import "./StreamPrivateSaleCustody.sol";
import { StreamNativeAuctionDelegation as D } from "../auctions/StreamNativeAuctionDelegation.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

interface IPrivateOfferHost {
    function paused() external view returns (bool);
}

/// @notice Fixed original/delegated offer execution in the guarded adapter's caller/storage context.
/// @dev Original buyer supplies native funds and receives the token. Delegation changes only who
/// signs the original offer digest. It never supplies an owner grant or a payment authorization.
library StreamPrivateSaleOfferExecution {
    struct Runtime {
        StreamPrivateSaleSupport.Context context;
        address platformSigner;
        D.Configuration delegation;
    }

    struct Request {
        StreamPrivateSaleTypes.SaleAuthorization authorization;
        P.Signature sellerProof;
        StreamPrivateSaleTypes.SaleOffer offer;
        P.Signature buyerProof;
        StreamPrivateSaleTypes.SaleCustodyGrant grant;
        uint8 ownerKind;
        bytes ownerSignature;
        D.Witness witness;
    }
    event OfferAccepted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 offerDigest,
        uint256 price,
        address asset
    );
    event SaleAuthorizationConsumed(
        uint16 schemaVersion, bytes32 indexed saleId, bytes32 indexed digest, address authorizer
    );
    event PrivateSaleNftDelivery(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address indexed receiver,
        bool delivered
    );
    event ConsignmentSettled(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price,
        uint256 royaltyAmount,
        address royaltyReceiver,
        address consignor
    );

    function execute(
        mapping(bytes32 => P.Sale) storage sales,
        StreamPrivateSaleAccounting.State storage money,
        mapping(bytes32 => bool) storage consumed,
        mapping(bytes32 => bytes32) storage custodySale,
        mapping(bytes32 => bool) storage salePaused,
        Runtime memory x,
        bool delegated,
        bytes calldata data
    ) public {
        Request memory q;
        if (delegated) {
            (
                q.authorization,
                q.sellerProof,
                q.offer,
                q.buyerProof,
                q.grant,
                q.ownerKind,
                q.ownerSignature,
                q.witness
            ) =
                abi.decode(
                    data[4:],
                    (
                        StreamPrivateSaleTypes.SaleAuthorization,
                        P.Signature,
                        StreamPrivateSaleTypes.SaleOffer,
                        P.Signature,
                        StreamPrivateSaleTypes.SaleCustodyGrant,
                        uint8,
                        bytes,
                        D.Witness
                    )
                );
        } else {
            (
                q.authorization,
                q.sellerProof,
                q.offer,
                q.buyerProof,
                q.grant,
                q.ownerKind,
                q.ownerSignature
            ) =
                abi.decode(
                    data[4:],
                    (
                        StreamPrivateSaleTypes.SaleAuthorization,
                        P.Signature,
                        StreamPrivateSaleTypes.SaleOffer,
                        P.Signature,
                        StreamPrivateSaleTypes.SaleCustodyGrant,
                        uint8,
                        bytes
                    )
                );
        }
        bytes32 id = q.authorization.saleId;
        P.Sale storage sale = sales[id];
        if (sale.saleNonce == 0 || sale.config.saleKind != 6 || sale.status != 1) {
            revert P.PrivateSaleUnavailable(id);
        }
        _purchaseAdmission(money, salePaused, x.context, id, sale);
        uint256 signatureGas = _gas(keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT"));
        bytes32 authDigest = StreamPrivateSaleSupport.authorizationProof(
            sale.config, q.authorization, q.sellerProof, x.platformSigner, signatureGas
        );
        bytes32 buyerDigest = delegated
            ? _delegatedProof(x, sale.config, q, signatureGas)
            : StreamPrivateSaleSupport.offerProof(
                sale.config, x.context.core, q.offer, q.buyerProof, signatureGas
            );
        _consume(consumed, id, authDigest, q.sellerProof.authorizer);
        _consume(consumed, id, buyerDigest, q.buyerProof.authorizer);
        StreamPrivateSaleCustody.enter(
            x.context,
            sale,
            consumed,
            custodySale,
            id,
            q.grant,
            q.ownerKind,
            q.ownerSignature,
            signatureGas
        );
        if (delegated) _delegation(x.delegation, q);
        _settle(money, salePaused, x, sale, id, authDigest, q, delegated);
        emit OfferAccepted(1, id, sale.config.buyer, buyerDigest, sale.config.price, address(0));
    }

    function _delegatedProof(
        Runtime memory x,
        P.SaleConfig memory config,
        Request memory q,
        uint256 cap
    ) private view returns (bytes32 digest) {
        StreamPrivateSaleTypes.SaleOffer memory offer = q.offer;
        digest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.offerBody(offer)
        );
        if (
            offer.chainId != block.chainid || offer.saleAdapter != address(this)
                || offer.core != x.context.core || offer.collectionId != config.collectionId
                || offer.tokenId != config.tokenId || offer.contentSelectionHash != 0
                || offer.buyer != config.buyer || offer.asset != address(0)
                || offer.price != config.price || offer.deadline < block.timestamp
                || offer.deadline > config.deadline || offer.finalizeBy != 0
                || digest != config.offerDigest
        ) revert P.InvalidPrivateSale();
        _delegation(x.delegation, q);
        if (!StreamPrivateSaleSupport.validSignature(
                q.buyerProof.authorizer, q.buyerProof.kind, digest, q.buyerProof.signature, cap
            )) {
            revert P.PrivateSaleAuthorityInvalid(q.buyerProof.authorizer);
        }
        _delegation(x.delegation, q);
    }

    function _delegation(D.Configuration memory c, Request memory q) private view {
        uint256 cap = _gas(D.GAS_PARAMETER);
        D.requireManifest(c, cap);
        D.requireDelegated(c, q.offer.buyer, q.buyerProof.authorizer, q.witness, cap);
    }

    function _settle(
        StreamPrivateSaleAccounting.State storage money,
        mapping(bytes32 => bool) storage salePaused,
        Runtime memory x,
        P.Sale storage sale,
        bytes32 id,
        bytes32 digest,
        Request memory q,
        bool delegated
    ) private {
        StreamPrivateSaleSupport.Context memory context = x.context;
        uint256 royaltyGas = _gas(keccak256("6529STREAM_GGP_SALE_ROYALTY_DELIVERY_GAS_LIMIT"));
        uint256 nftGas = _gas(keccak256("6529STREAM_GGP_SALE_NFT_DELIVERY_GAS_LIMIT"));
        StreamPrivateSaleSupport.requireGas(royaltyGas);
        StreamPrivateSaleSupport.requireGas(nftGas);
        _admit(salePaused, context, sale);
        StreamPrivateSaleSupport.requireToken(
            context, sale.config.collectionId, sale.config.tokenId
        );
        if (StreamPrivateSaleSupport.ownerOf(context, sale.config.tokenId) != address(this)) {
            revert P.CustodyGrantInvalid();
        }
        uint256 oldSurplus = address(this).balance - msg.value - money.totalLiabilities;
        sale.status = 3;
        sale.authorizationDigest = digest;
        sale.nftClaim = 1;
        StreamPrivateSaleAccounting.settleRoyalty(money, context, sale, id, royaltyGas);
        _admit(salePaused, context, sale);
        if (delegated) _delegation(x.delegation, q);
        bool deliveredNft = StreamPrivateSaleSupport.deliverNft(
            context, sale.config.tokenId, sale.config.buyer, nftGas
        );
        if (deliveredNft) sale.nftClaim = 0;
        emit PrivateSaleNftDelivery(1, id, sale.config.tokenId, sale.config.buyer, deliveredNft);
        _admit(salePaused, context, sale);
        if (delegated) _delegation(x.delegation, q);
        if (address(this).balance != money.totalLiabilities + oldSurplus) {
            revert P.PrivateSaleBalanceMismatch();
        }
        emit ConsignmentSettled(
            1,
            id,
            sale.config.tokenId,
            sale.config.buyer,
            sale.config.price,
            sale.royaltyAmount,
            sale.royaltyReceiver,
            sale.config.consignor
        );
    }

    function _purchaseAdmission(
        StreamPrivateSaleAccounting.State storage money,
        mapping(bytes32 => bool) storage salePaused,
        StreamPrivateSaleSupport.Context memory context,
        bytes32 id,
        P.Sale storage sale
    ) private view {
        _unpaused(salePaused, id);
        if (msg.sender != sale.config.buyer) revert P.PrivateSaleNotBuyer(msg.sender);
        if (block.timestamp < sale.config.startTime || block.timestamp > sale.config.deadline) {
            revert P.PrivateSaleUnavailable(id);
        }
        if (msg.value < sale.config.price) {
            revert P.PrivateSalePaymentTooSmall(sale.config.price, msg.value);
        }
        if (address(this).balance - msg.value < money.totalLiabilities) {
            revert P.PrivateSaleBalanceMismatch();
        }
        _admit(salePaused, context, sale);
    }

    function _admit(
        mapping(bytes32 => bool) storage salePaused,
        StreamPrivateSaleSupport.Context memory context,
        P.Sale storage sale
    ) private view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                sale.config.saleKind,
                sale.config.collectionId,
                bytes32(0),
                sale.saleNonce
            )
        );
        _unpaused(salePaused, id);
        StreamPrivateSaleSupport.requireAdmission(context, sale.createdAt, sale.registryRevision);
    }

    function _unpaused(mapping(bytes32 => bool) storage salePaused, bytes32 id) private view {
        if (IPrivateOfferHost(address(this)).paused() || salePaused[id]) {
            revert P.PrivateSalePaused(id);
        }
    }

    function _gas(bytes32 id) private view returns (uint256) {
        return IStreamGasParameterHost(address(this)).gasParameter(id);
    }

    function _consume(
        mapping(bytes32 => bool) storage consumed,
        bytes32 id,
        bytes32 digest,
        address authorizer
    ) private {
        if (consumed[digest]) revert P.PrivateSaleDigestConsumed(digest);
        consumed[digest] = true;
        emit SaleAuthorizationConsumed(1, id, digest, authorizer);
    }
}
