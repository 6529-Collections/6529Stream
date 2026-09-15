// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Additive marker for collection/default static and SALE_POSTER custody templates.
/// @dev Does not change the original fixed-profile custody capability ID.
interface IStreamPlatformTemplateCustodySettlement {
    function isStreamPlatformTemplateCustodySettlement() external pure returns (bool);
}
