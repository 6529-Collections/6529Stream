// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Actual fixed typed provider consumed by the Core finality adapter's metadata reads.
/// @dev The original collectionMetadata() continues to identify the generic metadata record host.
interface IStreamCoreFinalityEvidenceBinding {
    function evidenceProvider() external view returns (address);
}
