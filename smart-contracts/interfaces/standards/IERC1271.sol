// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice ERC-1271 signature validation for contract signers.
interface IERC1271 {
    /// @notice Returns 0x1626ba7e only when this contract accepts the digest and signature.
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4);
}
