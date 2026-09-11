// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Typed universal primary settlement transcript. Numeric modes are explicit,
///         and implementations must reject modes they do not implement.
library StreamPrimarySettlementTypes {
    uint8 internal constant PRE_REVENUE_SINGLE_STEP = 1;
    uint8 internal constant AUTHORITY_SIGNED = 1;

    struct PrimarySale {
        bytes32 settlementId;
        bytes32 revenueClass;
        uint8 policyMode;
        uint256 collectionId;
        uint256 tokenId;
        uint256 saleNonce;
        address payer;
        address poster;
        address beneficiary;
        uint256 amount;
        bytes32 expectedPrimaryPolicyHash;
    }

    struct SaleLifecycleBinding {
        address paymentAdapter;
        uint64 saleCreatedAt;
        uint64 saleAdapterRegistryRevision;
        uint64 paymentAdapterRegistryRevision;
    }

    struct SaleExecutionBinding {
        bytes32 executionId;
        uint256 executionNonce;
        uint8 authorityMode;
        bytes32 saleAuthorizationDigest;
    }

    /// @dev These are resolver-derived concrete rights, not a caller-selected destination.
    struct PrimaryRights {
        bytes32 profileId;
        address wallet;
        bytes32 templateId;
        bytes32 assignmentHash;
        bytes32 entriesHash;
    }

    struct ERC20SettlementCandidate {
        address saleAdapter;
        address executor;
        PrimarySale sale;
        SaleLifecycleBinding lifecycleBinding;
        SaleExecutionBinding executionBinding;
        address asset;
        uint8 orchestrationOrder;
        address mintManager;
        bytes32 operationIdentityCommitment;
        bytes32 operationId;
        bytes32 currentPolicyHash;
        bytes32 boundPolicyHash;
        PrimaryRights rights;
        bytes32 saleExecutionHash;
    }

    /// @dev Exactly twelve ABI words (384 bytes). The sale callback adds a magic word,
    ///      for an exact 416-byte response. The single operation ID stays candidate-bound.
    struct PrimarySettlementResult {
        bytes32 candidateCommitment;
        bytes32 settlementKey;
        bytes32 profileId;
        address wallet;
        address asset;
        uint256 amount;
        address executor;
        bytes32 executionId;
        bool escrowed;
        bytes32 operationIdentityCommitment;
        bytes32 currentPolicyHash;
        bytes32 boundPolicyHash;
    }

    struct PaymentIntent {
        address payer;
        address asset;
        uint256 maxAmount;
        bytes32 saleRef;
        bytes32 expectedPrimaryPolicyHash;
        bytes32 nonce;
        uint64 deadline;
    }

    struct PaymentIntentRevocation {
        address payer;
        bytes32 nonce;
        uint64 deadline;
    }

    struct EIP2612PermitAuthorization {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct Permit2TransferAuthorization {
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }
}
