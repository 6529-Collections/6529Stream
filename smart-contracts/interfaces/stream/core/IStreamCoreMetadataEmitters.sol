// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Authorized metadata invalidation events emitted from Core.
interface IStreamCoreMetadataEmitters {
    event MetadataUpdate(uint256 tokenId);
    event BatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId);

    event StreamMetadataRefresh(
        uint16 schemaVersion,
        bytes32 indexed reasonHash,
        uint256 indexed fromTokenId,
        uint256 indexed toTokenId
    );

    /// @notice Emits a token metadata invalidation from an authorized metadata component.
    function emitMetadataUpdate(uint256 tokenId, bytes32 reasonHash) external;

    /// @notice Emits metadata invalidation for an inclusive token identifier range.
    function emitBatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId, bytes32 reasonHash)
        external;

    /// @notice Emits the collection-level ERC-7572 invalidation from an authorized component.
    function emitContractURIUpdated() external;
}
