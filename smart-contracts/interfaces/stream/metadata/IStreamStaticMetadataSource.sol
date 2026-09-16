// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamCollectionManifestTypes as M } from "./StreamCollectionManifestTypes.sol";
import { IStreamScriptBundles as B } from "./IStreamScriptBundles.sol";

/// @notice Direct raw reads over the original authoritative manifest/bundle storage.
/// @dev These getters call no library/external host. Consumers verify each physical blob or
/// exact saved dependency version and reconstruct the original logical chunk/full-payload hash.
interface IStreamStaticMetadataSource {
    struct Chunk {
        bytes32 hash;
        uint32 length;
        address first;
        address tail;
    }
    function staticScriptManifest(bytes32 hash)
        external
        view
        returns (
            M.ScriptManifest memory manifest,
            bytes32 bundleId,
            uint256 collectionId,
            address router
        );
    function staticBundle(bytes32 bundleId)
        external
        view
        returns (B.Facts memory facts, B.RegistrySource memory source);
    function staticBundleChunk(bytes32 bundleId, uint256 index) external view returns (Chunk memory);
}
