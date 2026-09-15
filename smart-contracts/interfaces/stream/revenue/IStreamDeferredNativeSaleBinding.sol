// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamNativeSaleBinding.sol";

/// @notice Distinct module admission for a native refund adapter's single active finalization.
interface IStreamDeferredNativeSaleBinding is IStreamNativeSaleBinding {
    /// @dev Returns only the exact candidate commitment already bound to the active stored
    ///      purchase. Missing, pending-but-inactive and terminal purchases revert.
    function activeDeferredNativeSettlement(bytes32 purchaseId) external view returns (bytes32);
}
