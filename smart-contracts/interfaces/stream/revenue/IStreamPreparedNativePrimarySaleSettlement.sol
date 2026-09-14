// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreparedNativeSettlementTypes.sol";
import "./StreamPrimarySettlementTypes.sol";

/// @notice Official singleton prepared-native settlement, after actual Core and ledger preparation.
interface IStreamPreparedNativePrimarySaleSettlement {
    error InvalidPreparedNativeSettlement();
    error PreparedNativeSaleAlreadySettled(bytes32 saleKey);
    error UnsupportedPreparedNativeRights();

    event PreparedNativeRevenueRecorded(
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed factsHash,
        StreamPreparedNativeSettlementTypes.Facts facts,
        StreamPreparedNativeSettlementTypes.Intent intent
    );

    function settlePreparedNativePrimarySale(
        StreamPreparedNativeSettlementTypes.Facts calldata facts,
        StreamPreparedNativeSettlementTypes.Intent calldata intent
    ) external payable returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);

    /// @notice Original official evidence; later mint completion clears only Manager/Core activity.
    function preparedNativeFactsHash(bytes32 settlementKey) external view returns (bytes32);
    function preparedNativeSaleConsumed(bytes32 saleKey) external view returns (bool);
    function preparedNativeSaleKey(address saleAdapter, bytes32 saleId, uint256 saleNonce)
        external
        view
        returns (bytes32);
}
