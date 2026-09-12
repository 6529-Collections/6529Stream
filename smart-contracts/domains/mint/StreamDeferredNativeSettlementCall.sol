// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamDeferredNativePrimarySaleSettlement.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../revenue/StreamDeferredNativeSettlementHash.sol";
import "../revenue/StreamPrimarySettlementHash.sol";

/// @notice Exact typed call/readback of one active deferred purchase's official settlement.
library StreamDeferredNativeSettlementCall {
    error DeferredSettlementFailed();

    function settle(
        address recorder,
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory d
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory r) {
        bytes memory data = abi.encodeCall(
            IStreamDeferredNativePrimarySaleSettlement.settleDeferredNativePrimarySaleFromAdapter,
            (d)
        );
        bytes memory response = new bytes(384);
        uint256 amount = d.execution.sale.amount;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(gas(), recorder, amount, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384) revert DeferredSettlementFailed();
        r = abi.decode(response, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c = d.execution;
        if (
            r.candidateCommitment
                    != StreamDeferredNativeSettlementHash.candidateCommitment(recorder, d)
                || r.settlementKey
                    != StreamPrimarySettlementHash.settlementKey(
                        recorder, address(this), c.executionBinding.executionId
                    ) || r.profileId != c.rights.profileId || r.wallet != c.rights.wallet
                || r.asset != address(0) || r.amount != amount || r.executor != c.executor
                || r.executionId != c.executionBinding.executionId
                || r.operationIdentityCommitment != c.operationIdentityCommitment
                || r.currentPolicyHash != c.currentPolicyHash
                || r.boundPolicyHash != c.boundPolicyHash
        ) {
            revert DeferredSettlementFailed();
        }
        data = abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (r.settlementKey));
        assembly ("memory-safe") {
            ok := staticcall(gas(), recorder, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384 || keccak256(response) != keccak256(abi.encode(r))) {
            revert DeferredSettlementFailed();
        }
    }
}
