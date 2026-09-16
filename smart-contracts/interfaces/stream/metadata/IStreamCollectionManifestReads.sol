// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamCollectionManifestTypes as M } from "./StreamCollectionManifestTypes.sol";

/// @notice Current selected typed facts from Core's COLLECTION_METADATA owner.
/// @dev Artist subjects 2/3 use bytes32(collectionId). A zero hash means no selected manifest;
///      the hash commits the full typed record, not a URI or raw script family hash.
interface IStreamCollectionManifestReads {
    function core() external view returns (address);
    function scriptManifestHash(uint256 collectionId) external view returns (bytes32);
    function mediaManifestHash(uint256 collectionId) external view returns (bytes32);
    function scriptManifest(uint256 collectionId) external view returns (M.ScriptManifest memory);
    function mediaManifest(uint256 collectionId) external view returns (M.MediaManifest memory);
    function scriptChunk(uint256 collectionId, uint256 index) external view returns (bytes memory);
}
