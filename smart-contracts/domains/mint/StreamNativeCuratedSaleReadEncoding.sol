// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeCuratedSaleState } from "./StreamNativeCuratedSaleState.sol";
import { StreamImmediateSaleReveal } from "./StreamImmediateSaleReveal.sol";

/// @notice Fixed typed read encoder; each host wrapper retains its original external return ABI.
library StreamNativeCuratedSaleReadEncoding {
    error CuratedSaleUnavailable(bytes32 saleId);
    error CuratedCallbackInvalid();

    function read(StreamNativeCuratedSaleState.State storage state, uint8 kind, bytes32 id)
        public
        view
        returns (bytes memory)
    {
        if (kind == 0) return abi.encode(state.sales[id]);
        if (kind == 1) return abi.encode(state.executions[id]);
        if (kind == 4) {
            if (state.sales[id].status == 0) revert CuratedSaleUnavailable(id);
            return abi.encode(state.sales[id].lifecycle);
        }
        if (id == 0 || state.active.intentHash != id) revert CuratedCallbackInvalid();
        if (kind == 2) return abi.encode(state.active.intent);
        if (kind == 3) return abi.encode(state.active.purchase);
        revert CuratedCallbackInvalid();
    }

    function privateDomain() public view returns (bytes memory) {
        return abi.encode(
            bytes1(0x0f),
            "6529Stream Sales",
            "1",
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    function quote(StreamNativeCuratedSaleState.State storage state, address core, bytes32 id)
        public
        view
        returns (bytes memory)
    {
        if (state.sales[id].status == 0) revert CuratedSaleUnavailable(id);
        return
            abi.encode(StreamImmediateSaleReveal.quote(core, state.sales[id].config.collectionId));
    }
}
