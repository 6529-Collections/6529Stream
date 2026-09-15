// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact Core auxiliary recovery interface, ERC165 ID 0xb5c73a01 (ADR0020).
interface IStreamFinalityRecoveryCore {
    function lastAllocatedTokenId() external view returns (uint256);
    function emitBatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId, bytes32 reasonHash)
        external;
}
