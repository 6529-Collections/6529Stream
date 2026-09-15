// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/mint/IStreamNativeInventorySale.sol";

library StreamNativeInventoryState {
    struct State {
        mapping(bytes32 => IStreamNativeInventorySale.Inventory) inventories;
        mapping(bytes32 => mapping(uint256 => IStreamPrivateSaleAdapter.Sale)) tokens;
        mapping(bytes32 => mapping(address => uint256)) purchases;
        mapping(bytes32 => bytes32) grantSale;
    }
}
