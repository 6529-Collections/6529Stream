// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Permanent SSA-AUTH/OFFER/CUSTODY-ENTRY wire structs. No authority is inferred here.
library StreamPrivateSaleTypes {
    struct SaleAuthorization {
        uint256 chainId;
        address saleAdapter;
        address mintManager;
        uint256 collectionId;
        bytes32 phaseId;
        bytes32 saleId;
        uint8 saleKind;
        bytes32 revenueClass;
        bytes32 expectedPrimaryPolicyHash;
        uint8 primaryPolicyMode;
        bytes32 initialRecipientsHash;
        bytes32 beneficiariesHash;
        bytes32 tokenDataArrayHash;
        bytes32 mintCommitmentsHash;
        address payer;
        address executor;
        address asset;
        uint256 unitPrice;
        uint256 quantity;
        bytes32 contentSelectionHash;
        bytes32 policyHash;
        bytes32 nonce;
        uint64 deadline;
        uint64 finalizeBy;
    }

    struct SaleOffer {
        uint256 chainId;
        address saleAdapter;
        address core;
        uint256 collectionId;
        uint256 tokenId;
        bytes32 contentSelectionHash;
        address buyer;
        address asset;
        uint256 price;
        bytes32 nonce;
        uint64 deadline;
        uint64 finalizeBy;
    }

    struct SaleCustodyGrant {
        uint256 chainId;
        address saleAdapter;
        address core;
        uint256 tokenId;
        address owner;
        bytes32 saleRef;
        bytes32 nonce;
        uint64 deadline;
    }
}
