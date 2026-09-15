// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamCollectionManifestTypes as M } from "./StreamCollectionManifestTypes.sol";

/// @notice Storage admission only from the selected Router after its content authorization.
interface IStreamCollectionManifestWriter {
    error InvalidCollectionManifest();
    error UnsupportedCollectionManifest();
    error UnknownCollectionManifest(bytes32 hash);
    event CollectionManifestStored(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 indexed kind,
        bytes32 indexed manifestHash,
        address router,
        bytes32 servingSourceHash
    );
    function previewScriptManifest(uint256 collectionId, M.ScriptManifest calldata value)
        external
        view
        returns (bytes32);
    function previewMediaManifest(uint256 collectionId, M.MediaManifest calldata value)
        external
        view
        returns (bytes32);
    function storeScriptManifest(uint256 collectionId, M.ScriptManifest calldata value)
        external
        returns (bytes32);
    function storeMediaManifest(uint256 collectionId, M.MediaManifest calldata value)
        external
        returns (bytes32);
}

interface IStreamMetadataManifestSelection {
    function selectedCollectionManifest(uint256 collectionId, uint8 kind)
        external
        view
        returns (M.Selection memory);
}
