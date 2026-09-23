// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Sale-facing reveal policy and collection fee custody from EC-REVEAL.
/// @dev A missing or undeclared policy is not a declared zero-fee policy.
///      Request modes are AT_MINT=0 and OWNER_WINDOW=1. Funding never requests randomness.
interface IStreamRevealFeeEscrow is IERC165 {
    struct CollectionRevealPolicy {
        bool declared;
        uint8 requestMode;
        bytes32 revealOwnerRole;
        uint64 requestSLOBlocks;
        uint256 revealFeePerTokenWei;
    }

    function core() external view returns (address);
    function collectionRevealPolicy(uint256 collectionId)
        external
        view
        returns (CollectionRevealPolicy memory);
    function revealFeeEscrow(uint256 collectionId) external view returns (uint256);
    /// @notice Permissionless top-up, credited exactly to the selected collection.
    function fundRevealFeeEscrow(uint256 collectionId) external payable;
}
