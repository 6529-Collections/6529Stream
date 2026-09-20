// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Original fixed-price and custody-auction paid receipts, distinct from universal settlement.
library StreamDirectPrimarySaleTypes {
    bytes32 internal constant MODULE_TYPE = keccak256("DIRECT_PRIMARY_SALE_ADAPTER");
    bytes32 internal constant MODULE_VERSION = keccak256("6529STREAM_DIRECT_PRIMARY_SALE_V1");
    bytes32 internal constant NATIVE_FIXED_PRICE =
        keccak256("6529STREAM_DIRECT_NATIVE_FIXED_PRICE_V1");
    bytes32 internal constant ERC20_FIXED_PRICE =
        keccak256("6529STREAM_DIRECT_ERC20_FIXED_PRICE_V1");
    bytes32 internal constant ENGLISH_AUCTION = keccak256("6529STREAM_DIRECT_ENGLISH_AUCTION_V1");

    /// @notice Immutable deployment identity of the original product that retains the receipt.
    struct Bindings {
        address core;
        bytes32 coreCodeHash;
        address mintManager;
        bytes32 mintManagerCodeHash;
        uint256 deploymentChainId;
        bytes32 productKind;
    }

    /// @notice Complete actual paid outcome keyed by the product's original authorizationId.
    /// @dev The authorization digest retains its original native, ERC20 or auction EIP-712 domain.
    /// For an auction, mint identities and admission time/revision are retained from creation;
    /// payer, beneficiary, amount and escrowed describe its later successful paid settlement.
    /// Unknown, unpaid, no-bid, cancelled and refunded operations return the all-zero tuple.
    /// The sixteen-word ABI occupies thirteen storage words through address/uint64/bool packing.
    struct Receipt {
        bytes32 authorizationDigest;
        uint256 collectionId;
        uint256 tokenId;
        bytes32 operationRoot;
        bytes32 operationId;
        bytes32 boundMintPolicyHash;
        bytes32 expectedPrimaryPolicyHash;
        bytes32 profileId;
        address wallet;
        uint64 createdAt;
        bool escrowed;
        address payer;
        uint64 registryRevision;
        address beneficiary;
        address asset;
        uint256 amount;
    }
}
