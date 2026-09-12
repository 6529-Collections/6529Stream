// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/mint/StreamPrivateSaleTypes.sol";

/// @notice Canonical six SSA signature families. Validation and durable replay belong to consumers.
library StreamPrivateSaleHash {
    bytes32 internal constant AUTHORIZATION_TYPEHASH = keccak256(
        "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
    );
    bytes32 internal constant OFFER_TYPEHASH = keccak256(
        "SaleOffer(uint256 chainId,address saleAdapter,address core,uint256 collectionId,uint256 tokenId,bytes32 contentSelectionHash,address buyer,address asset,uint256 price,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
    );
    bytes32 internal constant CUSTODY_GRANT_TYPEHASH = keccak256(
        "SaleCustodyGrant(uint256 chainId,address saleAdapter,address core,uint256 tokenId,address owner,bytes32 saleRef,bytes32 nonce,uint64 deadline)"
    );
    bytes32 internal constant OFFER_REVOCATION_TYPEHASH =
        keccak256("SaleOfferRevocation(uint256 chainId,address saleAdapter,bytes32 offerDigest)");
    bytes32 internal constant AUTHORIZATION_REVOCATION_TYPEHASH = keccak256(
        "SaleAuthorizationRevocation(uint256 chainId,address saleAdapter,address authorizer,bytes32 authorizationDigest)"
    );
    bytes32 internal constant CUSTODY_GRANT_REVOCATION_TYPEHASH = keccak256(
        "SaleCustodyGrantRevocation(uint256 chainId,address saleAdapter,address owner,bytes32 grantDigest)"
    );

    function domain(uint256 chainId, address adapter) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                chainId,
                adapter
            )
        );
    }

    function digest(uint256 chainId, address adapter, bytes32 body)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(hex"1901", domain(chainId, adapter), body));
    }

    function authorizationBody(StreamPrivateSaleTypes.SaleAuthorization memory a)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(AUTHORIZATION_TYPEHASH, a));
    }

    function offerBody(StreamPrivateSaleTypes.SaleOffer memory offer)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(OFFER_TYPEHASH, offer));
    }

    function custodyGrantBody(StreamPrivateSaleTypes.SaleCustodyGrant memory grant)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(CUSTODY_GRANT_TYPEHASH, grant));
    }

    function offerRevocationBody(uint256 chainId, address adapter, bytes32 offerDigest)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(OFFER_REVOCATION_TYPEHASH, chainId, adapter, offerDigest));
    }

    function authorizationRevocationBody(
        uint256 chainId,
        address adapter,
        address authorizer,
        bytes32 authorizationDigest
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                AUTHORIZATION_REVOCATION_TYPEHASH, chainId, adapter, authorizer, authorizationDigest
            )
        );
    }

    function custodyGrantRevocationBody(
        uint256 chainId,
        address adapter,
        address owner,
        bytes32 grantDigest
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(CUSTODY_GRANT_REVOCATION_TYPEHASH, chainId, adapter, owner, grantDigest)
        );
    }
}
