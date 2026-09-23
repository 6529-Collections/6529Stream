// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Original Core-owned declarations survive replacement of every metadata satellite.
/// @dev Zero denotes no explicit declaration, not a conservation waiver or an effective tier.
interface IStreamCoreConservationTier {
    error ConservationTierAuthorityRequired();
    error InvalidConservationTier(bytes32 tier);
    error ConservationTierAlreadyDeclared(uint256 collectionId);
    error ConservationTierAfterFirstMint(uint256 collectionId);

    function recordConservationTier(uint256 collectionId, bytes32 tier) external;
    function declaredConservationTier(uint256 collectionId) external view returns (bytes32);
}
