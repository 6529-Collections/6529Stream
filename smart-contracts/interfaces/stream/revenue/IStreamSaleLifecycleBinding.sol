// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrimarySettlementTypes.sol";

/// @notice Immutable, caller-insensitive sale creation binding. Unknown sales return zeroes.
interface IStreamSaleLifecycleBinding {
    function saleLifecycleBinding(bytes32 saleId)
        external
        view
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory);
}
