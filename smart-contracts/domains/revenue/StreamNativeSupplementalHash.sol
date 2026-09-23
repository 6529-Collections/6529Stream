// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/revenue/StreamNativeSupplementalTypes.sol";

library StreamNativeSupplementalHash {
    function purchaseId(StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                c.originalFloor.saleAdapter,
                c.originalFloor.sale.settlementId,
                c.originalFloor.sale.payer,
                c.purchase.purchaseNonce
            )
        );
    }

    function purchaseKey(address recorder, address adapter, bytes32 id)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLEARING_SUPPLEMENT_LANE_V1"),
                block.chainid,
                recorder,
                adapter,
                id
            )
        );
    }

    function floorKey(address recorder, bytes32 key) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLEARING_FLOOR_LANE_V1"), block.chainid, recorder, key
            )
        );
    }

    function candidateCommitment(
        address recorder,
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLEARING_SUPPLEMENT_CANDIDATE_V1"),
                block.chainid,
                recorder,
                c
            )
        );
    }

    function executionId(
        address recorder,
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CLEARING_SUPPLEMENT_EXECUTION_V1"),
                block.chainid,
                recorder,
                c.originalFloor.saleAdapter,
                c.purchaseId,
                c.purchase.floorSettlementKey,
                c.executor,
                c.purchase,
                c.currentRights,
                c.currentPrimaryPolicyHash
            )
        );
    }
}
