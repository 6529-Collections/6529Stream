// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Additive floor entry for genuine original direct-product paid receipts.
interface IStreamDirectPrimaryConservationFloor is IERC165 {
    /// @notice Independently reads and authenticates the caller's exact locally stored receipt.
    /// @dev No universal candidate, consumed result or offchain preparation is synthesized.
    function recordDirectPrimarySale(bytes32 authorizationId) external returns (bytes32 receiptHash);
}
