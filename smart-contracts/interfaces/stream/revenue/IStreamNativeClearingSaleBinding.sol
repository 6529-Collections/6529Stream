// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeSupplementalTypes.sol";

/// @notice Additional capability; existing NativeSaleBinding remains independently required.
interface IStreamNativeClearingSaleBinding {
    function clearingPurchaseFacts(bytes32 purchaseId)
        external
        view
        returns (StreamNativeSupplementalTypes.ClearingPurchaseFacts memory);

    /// @notice Exact candidate commitment during the consumer's guarded supplemental call.
    function activeNativeSupplementalSettlement(bytes32 purchaseId) external view returns (bytes32);
}
