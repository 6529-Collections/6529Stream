// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeSettlementTypes.sol";

/// @notice Separate deferred purchase transcript; never reinterprets an immediate native call.
library StreamDeferredNativeSettlementTypes {
    struct DeferredNativeCandidate {
        StreamNativeSettlementTypes.NativeSettlementCandidate execution;
        bytes32 purchaseId;
        bytes32 purchaseRecordHash;
        bytes32 originalPrimaryPolicyHash;
        uint64 nominalRefundDeadline;
        uint64 nominalFinalizeBy;
        uint64 maximumNominalFinalizeBy;
        uint64 absoluteEscapeDeadline;
        uint64 effectiveRefundDeadline;
        uint64 effectiveFinalizeBy;
        uint64 pauseToll;
    }
}
