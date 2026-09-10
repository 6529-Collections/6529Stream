// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Permanent token-to-collection identity and lifecycle reads.
interface IStreamCoreIdentity {
    /// @notice Returns the permanent collection mapping, serial, and burn flag for a token.
    function tokenCollectionIdentity(uint256 tokenId)
        external
        view
        returns (bool mappingExists, uint256 collectionId, uint256 collectionSerial, bool burned);

    /// @notice Returns UNKNOWN=0, PREPARED_INCOMPLETE=1, MINTED=2, or BURNED=3.
    function tokenLifecycle(uint256 tokenId) external view returns (uint8 lifecycle);

    /// @notice Returns the entropy coordinator bound at mint completion, or zero before completion.
    function coordinatorAtMint(uint256 tokenId) external view returns (address);
}
