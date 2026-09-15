// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/StreamNativeSettlementTypes.sol";

library StreamNativeSettlementHash {
    function candidateCommitment(
        address recorder,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SETTLEMENT_CANDIDATE_V1"), block.chainid, recorder, c
            )
        );
    }

    function executionId(StreamNativeSettlementTypes.NativeSettlementCandidate memory c)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_SALE_EXECUTION_V1"),
                block.chainid,
                c.saleAdapter,
                c.sale.settlementId,
                c.sale.payer,
                c.executor,
                c.executionBinding.executionNonce,
                c.executionBinding.authorityMode,
                c.executionBinding.saleAuthorizationDigest,
                c.currentPolicyHash,
                c.boundPolicyHash,
                c.operationIdentityCommitment
            )
        );
    }

    /// @dev Internal reuse of recorder accounting/rights fields, never an ERC20 admission.
    ///      The native wire tuple cannot supply an asset or payment adapter.
    function accountingContext(StreamNativeSettlementTypes.NativeSettlementCandidate memory n)
        internal
        pure
        returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
    {
        c.saleAdapter = n.saleAdapter;
        c.executor = n.executor;
        c.sale = n.sale;
        c.executionBinding = n.executionBinding;
        c.orchestrationOrder = n.orchestrationOrder;
        c.mintManager = n.mintManager;
        c.operationIdentityCommitment = n.operationIdentityCommitment;
        c.operationId = n.operationId;
        c.currentPolicyHash = n.currentPolicyHash;
        c.boundPolicyHash = n.boundPolicyHash;
        c.rights = n.rights;
        c.saleExecutionHash = n.saleExecutionHash;
    }
}
