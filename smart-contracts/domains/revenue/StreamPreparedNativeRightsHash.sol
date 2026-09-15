// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/StreamPreparedNativeRightsTypes.sol";
import "../../interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";

/// @notice New entry preimages; original mint transcript and original sale replay keys are retained.
library StreamPreparedNativeRightsHash {
    function intentHash(
        address sale,
        address recorder,
        StreamPreparedNativeRightsTypes.Intent memory intent
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_RIGHTS_INTENT_V1"),
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
                keccak256("6529STREAM_PREPARED_NATIVE_RIGHTS_MINT_CONTEXT_V1"),
                block.chainid,
                manager,
                sale,
                intent
            )
        );
    }

    function factsHash(StreamPreparedNativeRightsTypes.Facts memory facts)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_RIGHTS_FACTS_V1"), block.chainid, facts
            )
        );
    }

    function executionId(
        StreamPreparedNativeRightsTypes.Facts memory facts,
        StreamPreparedNativeRightsTypes.Intent memory intent
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_RIGHTS_EXECUTION_V1"),
                block.chainid,
                facts.mint.saleAdapter,
                facts.mint.intentHash,
                intent.sale.executionNonce,
                facts.mint.currentPolicyHash,
                facts.mint.boundPolicyHash,
                facts.mint.operationRoot,
                facts.mint.operationId
            )
        );
    }

    function candidateCommitment(
        StreamPreparedNativeRightsTypes.Facts memory facts,
        StreamPreparedNativeRightsTypes.Intent memory intent,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory accounting
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_RIGHTS_CANDIDATE_V1"),
                block.chainid,
                facts.mint.recorder,
                facts,
                intent,
                accounting
            )
        );
    }
}
