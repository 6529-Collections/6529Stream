// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable publication inputs of the typed finality provider.
/// @dev This narrow read does not require a published root or scope readiness.
interface IStreamContentRootEvidenceBinding {
    function contentLeafManifest() external view returns (address);
    function contentLeafManifestCodeHash() external view returns (bytes32);
    function schemaRegistry() external view returns (address);
    function schemaRegistryCodeHash() external view returns (bytes32);
    function metadataHostCodeHash() external view returns (bytes32);
}
