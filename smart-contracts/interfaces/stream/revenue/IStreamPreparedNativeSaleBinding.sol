// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreparedNativeSettlementTypes.sol";
import "./StreamPrimarySettlementTypes.sol";
import "./StreamNativeSettlementTypes.sol";

/// @notice Explicit registered native prepared-sale receiver; it does not accept arbitrary hooks.
interface IStreamPreparedNativeSaleBinding {
    function core() external view returns (address);
    function moduleRegistry() external view returns (address);
    function mintManager() external view returns (address);
    function revenueResolver() external view returns (address);
    function primarySaleSettlement() external view returns (address);
    function settlementCodeHash() external view returns (bytes32);

    function preparedNativeSaleLifecycle(bytes32 saleId)
        external
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory);

    /// @notice Complete authenticated original intent only while its settlement operation is active.
    function activePreparedNativeIntent(bytes32 intentHash)
        external
        view
        returns (StreamPreparedNativeSettlementTypes.Intent memory);

    /// @notice Only the sale's fixed installed Manager may call, during its exact active operation.
    /// @return magic This selector encoded as an ABI bytes4, followed by exactly twelve result words.
    function onPreparedNativeMint(StreamPreparedNativeSettlementTypes.Facts calldata facts)
        external
        returns (bytes4 magic, StreamPrimarySettlementTypes.PrimarySettlementResult memory result);
}
