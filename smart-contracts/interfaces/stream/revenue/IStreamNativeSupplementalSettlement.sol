// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeSupplementalTypes.sol";

/// @notice Native financial capability on the official recorder; no mint or generic callback.
interface IStreamNativeSupplementalSettlement {
    error InvalidNativeSupplementalSettlement();
    error SupplementalPurchaseAlreadyConsumed(bytes32 purchaseKey);
    error SupplementalFloorAlreadyConsumed(bytes32 floorKey);
    error SupplementalFactsReadFailed(address adapter, uint256 size);
    error SupplementalRightsMismatch();
    error SupplementalPolicyMismatch();

    event NativeSupplementalRevenueSettled(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed purchaseId,
        address indexed buyer,
        StreamNativeSupplementalTypes.NativeSupplementalResult result
    );

    function settleNativeSupplementalRevenueFromAdapter(
        StreamNativeSupplementalTypes.NativeSupplementalCandidate calldata candidate
    ) external payable returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory);

    function nativeSupplementalResult(bytes32 settlementKey)
        external
        view
        returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory);
}
