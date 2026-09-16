// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrivateSaleTypes.sol";
import "./IStreamPrivateSaleAdapter.sol";
import "./IStreamNativeRefundDelegatedClaims.sol";
import "./StreamPreparedNativeContentTypes.sol";
import "../revenue/StreamPrimarySettlementTypes.sol";

/// @notice Atomic primary offers paid through the existing sole ERC20 puller.
library StreamERC20PrimaryOfferTypes {
    struct Configuration {
        uint256 collectionId;
        bytes32 phaseId;
        address asset;
        address paymentAdapter;
        uint256 price;
        address poster;
        uint64 startsAt;
        uint64 endsAt;
        bytes32 mintPolicyHash;
        bytes32 expectedPrimaryPolicyHash;
        uint8 primaryPolicyMode;
        bytes32 contentManifestRoot;
        address buyer;
        bytes32 offerDigest;
        bytes32 contentId;
        bytes32 tokenDataHash;
        address signer;
        uint8 signerKind;
        bytes32 signerEvidenceHash;
        uint64 signerRevision;
        address signerAuthority;
    }

    struct CollectionSigner {
        bytes32 evidenceHash;
        uint64 revision;
        bool enabled;
        address authority;
    }

    struct SaleRecord {
        Configuration config;
        uint256 saleNonce;
        bytes32 configHash;
        StreamPrimarySettlementTypes.SaleLifecycleBinding lifecycle;
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        address gate;
        bytes32 gateCodeHash;
        bytes32 gateConfigHash;
        bytes32 manifestHash;
        bytes32 contentCounterId;
        bytes32 contentCounterConfigHash;
        uint8 status; // 0 absent, 1 active, 2 cancelled, 3 expired, 4 completed.
    }

    struct Selection {
        StreamPreparedNativeContentTypes.Selection content;
        bytes tokenData;
        bytes32 mintCommitment;
        uint256 executionNonce;
    }

    struct Acceptance {
        StreamPrivateSaleTypes.SaleOffer offer;
        IStreamPrivateSaleAdapter.Signature buyerProof;
        StreamPrivateSaleTypes.SaleAuthorization authorization;
        IStreamPrivateSaleAdapter.Signature sellerProof;
        Selection selection;
        IStreamNativeRefundDelegatedClaims.DelegationWitness signerDelegation;
        IStreamNativeRefundDelegatedClaims.DelegationWitness executorDelegation;
    }

    struct ExecutionRecord {
        bytes32 saleId;
        address buyer;
        address executor;
        uint256 executionNonce;
        bytes32 offerDigest;
        bytes32 authorizationDigest;
        bytes32 authorizationId;
        bytes32 contentLeaf;
        bytes32 tokenDataHash;
        uint256 tokenId;
        bytes32 settlementKey;
        bytes32 operationRoot;
        bytes32 operationId;
    }
}
