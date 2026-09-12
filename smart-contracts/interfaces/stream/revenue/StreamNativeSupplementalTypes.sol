// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeSettlementTypes.sol";

/// @notice Exact financial-leg wire types; not a new mint orchestration.
library StreamNativeSupplementalTypes {
    uint8 internal constant SUPPLEMENTAL_OWED = 1;

    /// @dev Fourteen ABI words; only an authenticated actual clearing consumer supplies these facts.
    struct ClearingPurchaseFacts {
        bytes32 floorSettlementKey;
        bytes32 floorCandidateCommitment;
        bytes32 originalAuthorizationDigest;
        uint256 purchaseNonce;
        uint256 tokenId;
        bytes32 originalOperationId;
        uint256 paidPrice;
        uint256 floorPrice;
        uint256 globalClearingPrice;
        bool hasPriceOverride;
        uint256 priceOverride;
        uint256 buyerUniformPrice;
        uint64 effectiveFinalizeBy;
        uint8 status;
    }

    struct NativeSupplementalCandidate {
        StreamNativeSettlementTypes.NativeSettlementCandidate originalFloor;
        bytes32 purchaseId;
        address executor;
        ClearingPurchaseFacts purchase;
        StreamPrimarySettlementTypes.PrimaryRights currentRights;
        bytes32 currentPrimaryPolicyHash;
    }

    /// @dev Sixteen ABI words. Original mint identity is referenced, never freshly allocated.
    struct NativeSupplementalResult {
        bytes32 candidateCommitment;
        bytes32 settlementKey;
        bytes32 purchaseId;
        bytes32 originalFloorSettlementKey;
        uint256 tokenId;
        bytes32 profileId;
        address wallet;
        uint256 amount;
        address executor;
        bytes32 executionId;
        bool escrowed;
        bytes32 originalOperationRoot;
        bytes32 originalOperationId;
        bytes32 originalExpectedPrimaryPolicyHash;
        bytes32 currentPrimaryPolicyHash;
        bool policyDrift;
    }
}
