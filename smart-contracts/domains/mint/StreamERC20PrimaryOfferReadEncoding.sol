// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamERC20PrimaryOfferState.sol";

/// @notice Fixed ABI encoding of carrier-owned historical records, shared by typed read facades.
library StreamERC20PrimaryOfferReadEncoding {
    error InvalidERC20PrimaryOfferRead();

    function read(StreamERC20PrimaryOfferState.State storage state, bytes4 selector, bytes32 id)
        public
        view
        returns (bytes memory)
    {
        if (selector == bytes4(keccak256("saleRecord(bytes32)"))) {
            return abi.encode(state.sales[id]);
        }
        if (selector == bytes4(keccak256("executionRecord(bytes32)"))) {
            return abi.encode(state.executions[id]);
        }
        if (selector == bytes4(keccak256("primaryOfferConfiguration(bytes32)"))) {
            return abi.encode(state.sales[id].config);
        }
        if (selector == bytes4(keccak256("saleLifecycleBinding(bytes32)"))) {
            return abi.encode(state.sales[id].lifecycle);
        }
        revert InvalidERC20PrimaryOfferRead();
    }
}
