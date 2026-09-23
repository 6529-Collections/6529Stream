// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice One-way pre-first-mint conservation election and original Core-backed reads.
interface IStreamConservationTier is IERC165 {
    event CollectionConservationTierDeclared(
        uint256 indexed collectionId, bytes32 indexed tier, uint16 schemaVersion
    );

    function declareConservationTier(uint256 collectionId, bytes32 tier) external;

    /// @notice An undeclared collection returns zero until its first completed mint, then lite.
    /// @dev `declared` is always read from Core; allocation and burnable supply are irrelevant.
    function conservationTier(uint256 collectionId)
        external
        view
        returns (bytes32 declared, bytes32 effective);
}
