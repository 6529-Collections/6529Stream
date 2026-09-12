// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrivateSaleSupport.sol";
import "./StreamPrivateSaleHash.sol";

/// @notice Typed custody entry and NFT claim delivery for the private-sale consumer.
/// @dev The guarded consumer supplies its actual storage and pinned Core context through
///      compiler-generated links. Direct CALL rejects; the helper has no independent authority.
library StreamPrivateSaleCustody {
    event SaleAuthorizationConsumed(
        uint16 schemaVersion, bytes32 indexed saleId, bytes32 indexed digest, address authorizer
    );
    event SaleCustodyDeposited(
        uint16 schemaVersion, bytes32 indexed saleId, uint256 indexed tokenId, address indexed owner
    );
    event PrivateSaleNftDelivery(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address indexed receiver,
        bool delivered
    );
    event SaleCustodyReleased(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address receiver,
        bytes32 reasonHash
    );

    function enter(
        StreamPrivateSaleSupport.Context memory context,
        P.Sale storage sale,
        mapping(bytes32 => bool) storage consumed,
        mapping(bytes32 => bytes32) storage custodySale,
        bytes32 id,
        StreamPrivateSaleTypes.SaleCustodyGrant calldata grant,
        uint8 kind,
        bytes calldata signature,
        uint256 cap
    ) public {
        if (
            grant.chainId != block.chainid || grant.saleAdapter != address(this)
                || grant.core != context.core || grant.owner == address(0) || grant.tokenId == 0
                || grant.saleRef == 0
        ) revert P.CustodyGrantInvalid();
        if (
            grant.owner != sale.config.consignor || grant.tokenId != sale.config.tokenId
                || grant.saleRef != (sale.config.saleKind == 6 ? sale.config.offerDigest : id)
                || grant.deadline < block.timestamp
        ) revert P.CustodyGrantInvalid();
        StreamPrivateSaleSupport.requireToken(context, sale.config.collectionId, grant.tokenId);
        if (StreamPrivateSaleSupport.ownerOf(context, grant.tokenId) != grant.owner) {
            revert P.CustodyGrantInvalid();
        }
        bytes32 digest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.custodyGrantBody(grant)
        );
        StreamPrivateSaleSupport.directOrSignature(grant.owner, kind, digest, signature, cap);
        if (consumed[digest]) revert P.PrivateSaleDigestConsumed(digest);
        consumed[digest] = true;
        emit SaleAuthorizationConsumed(1, id, digest, grant.owner);
        sale.status = 2;
        sale.custodyGrantDigest = digest;
        custodySale[digest] = id;
        StreamPrivateSaleSupport.takeCustody(context, grant.owner, grant.tokenId);
        emit SaleCustodyDeposited(1, id, grant.tokenId, grant.owner);
    }

    function deliverClaim(
        StreamPrivateSaleSupport.Context memory context,
        P.Sale storage sale,
        mapping(bytes32 => bool) storage revoked,
        bytes32 id,
        address receiver,
        uint256 cap
    ) public returns (bool ok) {
        uint8 claimKind = sale.nftClaim;
        if (claimKind == 0) revert P.PrivateSaleClaimUnavailable();
        sale.nftClaim = 0;
        ok = StreamPrivateSaleSupport.deliverNft(context, sale.config.tokenId, receiver, cap);
        if (!ok) sale.nftClaim = claimKind;
        emit PrivateSaleNftDelivery(1, id, sale.config.tokenId, receiver, ok);
        if (ok && claimKind == 2) {
            emit SaleCustodyReleased(
                1,
                id,
                sale.config.tokenId,
                receiver,
                sale.status == 5
                    ? keccak256("PRIVATE_SALE_EXPIRED")
                    : (revoked[sale.custodyGrantDigest]
                            ? keccak256("CUSTODY_GRANT_REVOKED")
                            : keccak256("PRIVATE_SALE_CANCELLED"))
            );
        }
    }
}
