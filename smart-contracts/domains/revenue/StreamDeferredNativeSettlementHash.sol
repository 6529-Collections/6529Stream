// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/StreamDeferredNativeSettlementTypes.sol";

/// @notice Distinct deferred identity domains; the existing official settlement key is unchanged.
library StreamDeferredNativeSettlementHash {
    function candidateCommitment(
        address recorder,
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory c
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_DEFERRED_NATIVE_SETTLEMENT_CANDIDATE_V1"),
                block.chainid,
                recorder,
                c
            )
        );
    }

    /// @dev Immutable purchase record commits payer, price, original authorization and envelope.
    ///      The recorder must also consume purchaseKey: recomputing an execution identity with
    ///      another finalizer or current policy never permits paying one purchase twice.
    function executionId(StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory c)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_DEFERRED_NATIVE_SALE_EXECUTION_V1"),
                block.chainid,
                c.execution.saleAdapter,
                c.purchaseId,
                c.purchaseRecordHash,
                c.execution.executor,
                c.execution.executionBinding.saleAuthorizationDigest,
                c.execution.currentPolicyHash,
                c.execution.boundPolicyHash,
                c.execution.operationIdentityCommitment
            )
        );
    }

    function purchaseKey(address recorder, address saleAdapter, bytes32 purchaseId)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_DEFERRED_PURCHASE_SETTLEMENT_V1"),
                block.chainid,
                recorder,
                saleAdapter,
                purchaseId
            )
        );
    }
}
