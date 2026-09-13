// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";

/// @notice Exact domain-separated, abi.encode-only universal settlement preimages.
library StreamPrimarySettlementHash {
    bytes32 internal constant CANDIDATE = keccak256("6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V2");
    bytes32 internal constant KEY = keccak256("6529STREAM_PRIMARY_SETTLEMENT_KEY_V2");
    bytes32 internal constant EXECUTION = keccak256("6529STREAM_ERC20_SALE_EXECUTION_V1");

    function candidateCommitment(
        address paymentAdapter,
        address recorder,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory candidate
    ) internal view returns (bytes32) {
        return keccak256(abi.encode(CANDIDATE, block.chainid, paymentAdapter, recorder, candidate));
    }

    /// @dev One official entry per exact sale execution, independent of alternative asset,
    ///      policy, payer or destination fields. Such alternatives cannot reopen a consumed key.
    function settlementKey(address recorder, address saleAdapter, bytes32 executionIdentity)
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(KEY, block.chainid, recorder, saleAdapter, executionIdentity));
    }

    function executionId(StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                EXECUTION,
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
}
