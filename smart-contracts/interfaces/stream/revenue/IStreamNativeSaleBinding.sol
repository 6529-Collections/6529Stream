// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeSettlementTypes.sol";

/// @notice Native-only registry capability: exact deployment and immutable sale facts.
interface IStreamNativeSaleBinding {
    function core() external view returns (address);
    function mintManager() external view returns (address);
    function primarySaleSettlement() external view returns (address);
    function nativeSaleLifecycleBinding(bytes32 saleId)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory);
}
