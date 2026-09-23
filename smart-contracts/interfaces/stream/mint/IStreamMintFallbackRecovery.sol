// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Dedicated governance incident capability, absent from the ordinary mint Manager.
interface IStreamMintFallbackRecovery {
    event MintFallbackPreparedRecovered(
        uint16 schemaVersion,
        bytes32 indexed actionId,
        uint256 indexed tokenId,
        bytes32 indexed operationId,
        uint256 collectionId
    );

    /// @notice Aborts only the exact stranded preparation after governed fallback selection.
    /// @dev Requires an exact class-3 per-call context; cannot prepare, complete or redirect a mint.
    function recoverPreparedMint(uint256 tokenId, bytes32 operationId) external;
}
