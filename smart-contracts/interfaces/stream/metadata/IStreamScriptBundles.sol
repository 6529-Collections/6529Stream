// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamCollectionManifestTypes as M } from "./StreamCollectionManifestTypes.sol";

/// @notice Immutable executable payloads. Publication is permissionless; selection is not.
interface IStreamScriptBundles {
    struct Plan {
        bytes32 payloadHash;
        M.PayloadSourceType sourceType;
        bytes32[] chunkHashes;
        uint32[] chunkLengths;
        bytes32 libraryBundle;
        bool libraryOnly;
    }

    struct RegistrySource {
        address registry;
        bytes32 codeHash;
        bytes32 dependencyId;
        uint256 version;
        bytes32 contentHash;
    }

    struct Facts {
        bytes32 payloadHash;
        bytes32 libraryBundle;
        uint32 totalBytes;
        uint8 chunkCount;
        M.PayloadSourceType sourceType;
        bool libraryOnly;
        bool finalized;
    }

    struct Selection {
        address host;
        bytes32 codeHash;
        bytes32 bundleId;
        bytes32 manifestHash;
    }
    error InvalidScriptBundle(bytes32 bundleId);
    function beginRegistryLibrary(Plan calldata plan, RegistrySource calldata source)
        external
        returns (bytes32);
    function scriptBundleRegistry(bytes32 bundleId) external view returns (RegistrySource memory);
    function dependencyManifest(bytes32 bundleId)
        external
        view
        returns (M.DependencyManifest memory);
    function dependencyChunk(bytes32 bundleId, uint256 index) external view returns (bytes memory);
    function beginScriptBundle(Plan calldata plan) external returns (bytes32);
    function appendScriptBundle(bytes32 bundleId, uint256 index, bytes calldata payload) external;
    function finalizeScriptBundle(bytes32 bundleId) external;
    function scriptChunkCount(uint256 collectionId) external view returns (uint256);
    function scriptBundle(bytes32 bundleId) external view returns (Facts memory);
    function scriptBundleChunk(bytes32 bundleId, uint256 index) external view returns (bytes memory);
    function scriptBundleChunks(bytes32 bundleId, uint256 start, uint256 count)
        external
        view
        returns (bytes[] memory);
    function recordedScriptBundle(bytes32 manifestHash) external view returns (bytes32);
}

interface IStreamScriptBundleSelection {
    /// @dev Raw saved selection: independent of current Core pointers, for selected finality hosts.
    function collectionScriptBundle(uint256 collectionId)
        external
        view
        returns (IStreamScriptBundles.Selection memory);
}
