// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    IStreamCollectionManifestWriter as W
} from "../../interfaces/stream/metadata/IStreamCollectionManifestWriter.sol";
import {
    IStreamMetadataServingFacts as F
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "./StreamMetadataRenderer.sol";

/// @notice Typed current-router manifest profile, independent from generic record families.
library StreamCollectionManifests {
    struct Entry {
        uint256 collectionId;
        address router;
        bytes32 sourceHash;
        uint8 kind;
    }

    struct State {
        mapping(bytes32 => Entry) entries;
        mapping(bytes32 => M.ScriptManifest) scripts;
        mapping(bytes32 => M.MediaManifest) media;
    }

    function script(
        address core,
        address router,
        uint256 collectionId,
        M.ScriptManifest memory m,
        F.ServingSource memory source
    ) public view returns (bytes32 hash, bytes32 sourceHash) {
        // This profile describes the actual bounded executable renderer. Larger or archival
        // payloads need an explicit serving profile; they are never relabelled as executed.
        if (
            bytes(source.script).length == 0 || bytes(source.script).length > 8192
                || m.sourceType != M.PayloadSourceType.INLINE_CHUNKS || m.chunkCount != 1
                || !m.executable || bytes(m.sourcePointer).length != 0
                || bytes(m.libraryURI).length != 0
                || m.rendererCompatibility != keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1")
                || keccak256(bytes(m.mimeType)) != keccak256("application/javascript")
        ) revert W.UnsupportedCollectionManifest();
        sourceHash = keccak256(bytes(source.script));
        if (m.scriptHash != sourceHash) revert W.InvalidCollectionManifest();
        StreamMetadataRenderer.requireValidUtf8ScriptUri("scriptURI", m.scriptURI, 2048, true);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_SCRIPT_MANIFEST_V1"),
                block.chainid,
                core,
                address(this),
                router,
                router.codehash,
                collectionId,
                sourceHash,
                m
            )
        );
    }

    function media(
        address core,
        address router,
        uint256 collectionId,
        M.MediaManifest memory m,
        F.ServingSource memory source
    ) public view returns (bytes32 hash, bytes32 sourceHash) {
        if (keccak256(bytes(m.imageURI)) != keccak256(bytes(source.imageURI))) revert W.InvalidCollectionManifest();
        // An animation base URI is a token URL recipe, not a shared asset URI.
        if (bytes(source.animationBaseURI).length != 0 && bytes(m.animationURI).length != 0) {
            revert W.UnsupportedCollectionManifest();
        }
        _asset(m.imageSourceType, m.imageURI, m.imageHash, m.imageMimeType);
        _asset(m.animationSourceType, m.animationURI, m.animationHash, m.animationMimeType);
        _asset(m.contentSourceType, m.contentURI, m.contentHash, m.contentMimeType);
        _reference(m.manifestURI, m.manifestHash);
        _reference(m.alternatesURI, m.alternatesHash);
        sourceHash = keccak256(abi.encode(source.imageURI, source.animationBaseURI));
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_MEDIA_MANIFEST_V1"),
                block.chainid,
                core,
                address(this),
                router,
                router.codehash,
                collectionId,
                sourceHash,
                m
            )
        );
    }

    function _asset(M.PayloadSourceType kind, string memory uri, bytes32 digest, string memory mime)
        private
        pure
    {
        if (kind == M.PayloadSourceType.NONE) {
            if (bytes(uri).length != 0 || digest != 0 || bytes(mime).length != 0) {
                revert W.InvalidCollectionManifest();
            }
            return;
        }
        if (digest == 0 || bytes(mime).length == 0) revert W.InvalidCollectionManifest();
        StreamMetadataRenderer.requireValidUtf8Bytes("mimeType", mime, 128);
        StreamMetadataRenderer.requireValidUtf8ContentUri("assetURI", uri, 2048, false);
        bool valid = kind == M.PayloadSourceType.IPFS && _starts(uri, "ipfs://")
            || kind == M.PayloadSourceType.ARWEAVE && _starts(uri, "ar://")
            || kind == M.PayloadSourceType.HTTPS && _starts(uri, "https://");
        if (!valid) revert W.UnsupportedCollectionManifest();
    }

    function _reference(string memory uri, bytes32 digest) private pure {
        if (bytes(uri).length == 0) {
            if (digest != 0) revert W.InvalidCollectionManifest();
        } else {
            if (digest == 0) revert W.InvalidCollectionManifest();
            StreamMetadataRenderer.requireValidUtf8ContentUri("manifestReference", uri, 2048, false);
        }
    }

    function _starts(string memory value, bytes memory prefix) private pure returns (bool) {
        bytes memory raw = bytes(value);
        if (raw.length < prefix.length) return false;
        for (uint256 i; i < prefix.length; ++i) {
            if (raw[i] != prefix[i]) return false;
        }
        return true;
    }
}
