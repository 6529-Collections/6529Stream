// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamERC20DutchSaleRuntime.sol";
import "../../interfaces/stream/revenue/IStreamERC20DutchSaleResolution.sol";

/// @notice Fixed canonical ABI projection. No storage writer or selectable external dependency.
library StreamERC20DutchSaleRead {
    function read(
        StreamERC20DutchSaleState.State storage state,
        StreamNativeImmediateSalesRuntime.Context memory x,
        bytes calldata raw
    ) public view returns (bytes memory encoded, address asset) {
        bytes4 selector = bytes4(raw[:4]);
        if (selector == bytes4(keccak256("executionReceipt(bytes32)"))) {
            return (abi.encode(state.common.receipts[abi.decode(raw[4:], (bytes32))]), address(0));
        }
        if (selector == D.dutchSaleRecord.selector) {
            bytes32 id = abi.decode(raw[4:], (bytes32));
            S.Record storage r = state.common.sales[id];
            if (r.saleNonce == 0) revert S.ImmediateSaleUnavailable(id);
            D.Record memory v;
            v.config = state.configurations[id];
            v.configHash = r.configHash;
            v.priceScheduleHash = state.scheduleHashes[id];
            v.saleNonce = r.saleNonce;
            v.soldQuantity = r.soldQuantity;
            v.closed = r.closed;
            v.lifecycle = state.lifecycle[id];
            v.artistId = r.artistId;
            v.artistGeneration = r.artistGeneration;
            v.artistBindingHash = r.artistBindingHash;
            return (abi.encode(v), address(0));
        }
        D.Execution memory e;
        bytes memory data;
        if (selector == D.previewDutchExecution.selector) {
            e = abi.decode(raw[4:], (D.Execution));
            data = abi.encode(e);
        } else if (selector == IStreamERC20DutchSaleResolution.resolveERC20DutchExecution.selector)
        {
            bytes32 id;
            bytes32 hash;
            address executor;
            (id, hash, executor, data) = abi.decode(raw[4:], (bytes32, bytes32, address, bytes));
            e = abi.decode(data, (D.Execution));
            if (
                e.purchase.saleId != id || e.purchase.executor != executor
                    || state.common.sales[id].saleNonce == 0
                    || state.common.sales[id].configHash != hash
                    || msg.sender != state.configurations[id].paymentAdapter
                    || keccak256(data) != keccak256(abi.encode(e))
            ) revert S.InvalidImmediateSale();
        } else {
            revert S.InvalidImmediateSale();
        }
        (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,) =
            StreamERC20DutchSaleRuntime.prepare(state, x, e);
        encoded = selector == D.previewDutchExecution.selector ? abi.encode(c, data) : abi.encode(c);
        return (encoded, c.asset);
    }

    function execution(
        StreamERC20DutchSaleState.State storage state,
        StreamNativeImmediateSalesRuntime.Context memory x,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        bytes calldata data,
        bool free
    ) public view returns (S.Purchase memory p, IStreamMintManager.MintBatch memory b) {
        D.Execution memory e = abi.decode(data, (D.Execution));
        p = e.purchase;
        if (
            msg.sender != state.configurations[p.saleId].paymentAdapter
                || keccak256(data) != keccak256(abi.encode(e))
        ) revert S.InvalidImmediateSale();
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory expected;
        (expected, b) = StreamERC20DutchSaleRuntime.prepare(state, x, e);
        if (
            keccak256(abi.encode(expected)) != keccak256(abi.encode(c))
                || (free && !state.configurations[p.saleId].declaredFree)
        ) revert S.ImmediateSaleResultMismatch();
    }
}
