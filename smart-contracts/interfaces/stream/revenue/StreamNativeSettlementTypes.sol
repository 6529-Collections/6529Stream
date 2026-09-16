// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrimarySettlementTypes.sol";

/// @notice Native single-step transcript; no ERC20 asset or payment callback authority.
library StreamNativeSettlementTypes {
    struct SaleLifecycleBinding {
        uint64 saleCreatedAt;
        uint64 saleAdapterRegistryRevision;
    }

    struct NativeSettlementCandidate {
        address saleAdapter;
        address executor;
        StreamPrimarySettlementTypes.PrimarySale sale;
        SaleLifecycleBinding lifecycleBinding;
        StreamPrimarySettlementTypes.SaleExecutionBinding executionBinding;
        uint8 orchestrationOrder;
        address mintManager;
        bytes32 operationIdentityCommitment;
        bytes32 operationId;
        bytes32 currentPolicyHash;
        bytes32 boundPolicyHash;
        StreamPrimarySettlementTypes.PrimaryRights rights;
        bytes32 saleExecutionHash;
    }
}
