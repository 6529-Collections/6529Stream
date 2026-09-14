// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";

library StreamPreparedNativeContentHash {
    // These two original SSA-CONTENT domains and word orders are intentionally unchanged.
    function leaf(
        uint256 chainId,
        address house,
        bytes32 saleId,
        bytes32 contentId,
        bytes32 dataHash
    ) internal pure returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_LEAF_V1"),
                        chainId,
                        house,
                        saleId,
                        contentId,
                        dataHash
                    )
                )
            )
        );
    }

    function context(uint256 chainId, address house, bytes32 saleId, bytes32 contentId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_CONTEXT_V1"), chainId, house, saleId, contentId
            )
        );
    }

    function intentHash(
        address house,
        address recorder,
        StreamPreparedNativeSettlementTypes.Intent memory intent
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_INTENT_V1"),
                block.chainid,
                house,
                recorder,
                intent
            )
        );
    }

    function factsHash(StreamPreparedNativeContentTypes.Facts memory facts)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_FACTS_V1"), block.chainid, facts
            )
        );
    }

    function admissionHash(
        address house,
        bytes32 intent,
        StreamPreparedNativeContentTypes.Facts memory content
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_ADMISSION_V1"),
                block.chainid,
                house,
                intent,
                content
            )
        );
    }
}
