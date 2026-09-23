// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import "../../interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";

/// @notice New prepared-native preimages; no existing operation or settlement preimage is changed.
library StreamPreparedNativeSettlementHash {
    function intentHash(
        address sale,
        address recorder,
        StreamPreparedNativeSettlementTypes.Intent memory intent
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_INTENT_V1"),
                block.chainid,
                sale,
                recorder,
                intent
            )
        );
    }

    function mintContext(address manager, address sale, bytes32 intent)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_MINT_CONTEXT_V1"),
                block.chainid,
                manager,
                sale,
                intent
            )
        );
    }

    function factsHash(StreamPreparedNativeSettlementTypes.Facts memory facts)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(keccak256("6529STREAM_PREPARED_NATIVE_FACTS_V1"), block.chainid, facts)
        );
    }

    function executionId(
        StreamPreparedNativeSettlementTypes.Facts memory facts,
        StreamPreparedNativeSettlementTypes.Intent memory intent
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_EXECUTION_V1"),
                block.chainid,
                facts.saleAdapter,
                facts.intentHash,
                intent.executionNonce,
                facts.currentPolicyHash,
                facts.boundPolicyHash,
                facts.operationRoot,
                facts.operationId
            )
        );
    }

    function saleKey(address recorder, address sale, bytes32 id, uint256 nonce)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_SALE_KEY_V1"),
                block.chainid,
                recorder,
                sale,
                id,
                nonce
            )
        );
    }

    function candidateCommitment(
        StreamPreparedNativeSettlementTypes.Facts memory facts,
        StreamPreparedNativeSettlementTypes.Intent memory intent,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory accounting
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_CANDIDATE_V1"),
                block.chainid,
                facts.recorder,
                facts,
                intent,
                accounting
            )
        );
    }
}
