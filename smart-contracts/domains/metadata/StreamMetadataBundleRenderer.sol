// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScriptBundles as B,
    IStreamScriptBundleSelection
} from "../../interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    IStreamMetadataServingFacts as F
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamMetadataRenderTypes as T
} from "../../interfaces/stream/metadata/StreamMetadataRenderTypes.sol";
import {
    StreamMetadataDisplayParameters as BundleGas
} from "./StreamMetadataDisplayParameters.sol";
import { StreamMetadataTokenRenderer } from "./StreamMetadataTokenRenderer.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import { Base64 } from "../../vendor/openzeppelin/Base64.sol";
import { StreamMetadataCitation as Citation } from "./StreamMetadataCitation.sol";

/// @notice Explicit large-output views over finalized immutable bundles, with a compact default.
/// @dev libraryURI is provenance only. Only locally verified, pinned library bytes execute.
library StreamMetadataBundleRenderer {
    using Strings for uint256;
    bytes32 public constant PROFILE = keccak256("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1");
    error InvalidBundleRendering();
    error DefaultMetadataTooLarge();

    function renderingProfile() public pure returns (bytes32, bytes32, bytes32) {
        return (
            PROFILE,
            keccak256("6529STREAM_CHUNKED_RENDER_CONTEXT_V1"),
            keccak256("6529STREAM_PINNED_BUNDLE_DEPENDENCIES_V1")
        );
    }

    /// @notice Scalar projection after all original capability, runtime and bounded-read checks.
    function selectedBundleId(M.Selection memory manifest) public view returns (bytes32) {
        return selection(manifest).bundleId;
    }

    function selection(M.Selection memory manifest) public view returns (B.Selection memory s) {
        if (manifest.manifestHash == 0) return s;
        if (manifest.host.code.length == 0 || manifest.host.codehash != manifest.codeHash) {
            revert InvalidBundleRendering();
        }
        // The original metadata host already has ERC165. Exact absence retains its stable
        // profile; a malformed or failing capability read never selects guessed legacy bytes.
        uint256 supported = abi.decode(
            _read(
                manifest.host,
                abi.encodeWithSelector(bytes4(0x01ffc9a7), type(B).interfaceId),
                32,
                BundleGas.value(BundleGas.BUNDLE_READ_GAS)
            ),
            (uint256)
        );
        if (supported > 1) revert InvalidBundleRendering();
        if (supported == 0) return s;
        bytes32 bundle = abi.decode(
            _read(
                manifest.host,
                abi.encodeCall(B.recordedScriptBundle, (manifest.manifestHash)),
                32,
                BundleGas.value(BundleGas.BUNDLE_READ_GAS)
            ),
            (bytes32)
        );
        if (bundle == 0) return s;
        return B.Selection(manifest.host, manifest.codeHash, bundle, manifest.manifestHash);
    }

    function requireLive(B.Selection memory s, address core) public view {
        (address h, bytes32 code,,,,, uint8 status,,, uint64 revision) =
            IStreamCorePointers(core).getSatellitePointer(keccak256("COLLECTION_METADATA"));
        if (h != s.host || code != s.codeHash || status != 1 || revision == 0) {
            revert InvalidBundleRendering();
        }
        (h, code,,,,, status,,, revision) =
            IStreamCorePointers(core).getSatellitePointer(keccak256("METADATA_ROUTER"));
        if (h != address(this) || code != address(this).codehash || status != 1 || revision == 0) {
            revert InvalidBundleRendering();
        }
    }

    function facts(B.Selection memory s) public view returns (B.Facts memory) {
        return _selectionFacts(s, BundleGas.value(BundleGas.BUNDLE_READ_GAS));
    }

    function _selectionFacts(B.Selection memory s, uint256 cap)
        private
        view
        returns (B.Facts memory f)
    {
        if (
            s.host.code.length == 0 || s.host.codehash != s.codeHash || s.bundleId == 0
                || s.manifestHash == 0
                || abi.decode(
                        _read(
                            s.host,
                            abi.encodeCall(B.recordedScriptBundle, (s.manifestHash)),
                            32,
                            cap
                        ),
                        (bytes32)
                    ) != s.bundleId
        ) revert InvalidBundleRendering();
        f = _facts(s.host, s.bundleId, cap);
        if (f.libraryOnly) revert InvalidBundleRendering();
    }

    function _facts(address host, bytes32 id, uint256 cap) private view returns (B.Facts memory f) {
        bytes memory raw = _read(host, abi.encodeCall(B.scriptBundle, (id)), 224, cap);
        f = abi.decode(raw, (B.Facts));
        if (
            keccak256(raw) != keccak256(abi.encode(f)) || !f.finalized || f.chunkCount == 0
                || f.chunkCount > 32 || f.totalBytes == 0 || f.totalBytes > 786432
                || (f.sourceType != M.PayloadSourceType.INLINE_CHUNKS
                    && f.sourceType != M.PayloadSourceType.SSTORE2
                    && !(f.libraryOnly && f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY))
        ) revert InvalidBundleRendering();
    }

    function payload(address host, bytes32 id, uint256 cap)
        private
        view
        returns (bytes memory out)
    {
        B.Facts memory f = _facts(host, id, cap);
        out = new bytes(f.totalBytes);
        uint256 offset;
        uint256 max = f.sourceType == M.PayloadSourceType.SSTORE2 ? 24576 : 8192;
        for (uint256 i; i < f.chunkCount; ++i) {
            bytes memory raw =
                _read(host, abi.encodeCall(B.scriptBundleChunk, (id, i)), max + 64, cap);
            bytes memory part = abi.decode(raw, (bytes));
            if (
                part.length == 0 || part.length > max || part.length > out.length - offset
                    || keccak256(raw) != keccak256(abi.encode(part))
            ) revert InvalidBundleRendering();
            uint256 n = part.length & ~uint256(31);
            assembly ("memory-safe") {
                let dst := add(add(out, 32), offset)
                for { let j := 0 } lt(j, n) { j := add(j, 32) } {
                    mstore(add(dst, j), mload(add(add(part, 32), j)))
                }
            }
            for (uint256 j = n; j < part.length; ++j) {
                out[offset + j] = part[j];
            }
            offset += part.length;
        }
        if (offset != out.length || keccak256(out) != f.payloadHash) {
            revert InvalidBundleRendering();
        }
    }

    /// @param mode 0 compact JSON; 1 compact data URI; 2 full token JSON; 3 full HTML.
    function render(
        uint8 mode,
        T.Token memory token,
        F.ServingSource memory metadata,
        bytes memory artist,
        B.Selection memory s,
        address viewHost,
        uint256 chainId
    ) public view returns (string memory) {
        return _render(
            mode,
            token,
            metadata,
            artist,
            s,
            viewHost,
            chainId,
            BundleGas.value(BundleGas.BUNDLE_READ_GAS),
            address(0),
            false
        );
    }

    function renderCurrent(
        uint8 mode,
        T.Token memory token,
        F.ServingSource memory metadata,
        bytes memory artist,
        bool nestedArtist,
        B.Selection memory s,
        address viewHost,
        uint256 originalChainId,
        address originalCore
    ) public view returns (string memory) {
        if (originalCore == address(0)) revert InvalidBundleRendering();
        return _render(
            mode,
            token,
            metadata,
            artist,
            s,
            viewHost,
            originalChainId,
            BundleGas.value(BundleGas.BUNDLE_READ_GAS),
            originalCore,
            nestedArtist
        );
    }

    function _render(
        uint8 mode,
        T.Token memory token,
        F.ServingSource memory metadata,
        bytes memory artist,
        B.Selection memory s,
        address viewHost,
        uint256 chainId,
        uint256 cap,
        address originalCore,
        bool nestedArtist
    ) private view returns (string memory) {
        if (mode > 3) revert InvalidBundleRendering();
        B.Facts memory f = _selectionFacts(s, cap);
        if (mode < 2) {
            return _compact(
                mode == 1,
                token,
                metadata,
                artist,
                s,
                f,
                viewHost,
                chainId,
                originalCore == address(0)
                    ? ""
                    : Citation.work(chainId, originalCore, token.tokenId),
                nestedArtist
            );
        }
        if (!token.finalized) revert InvalidBundleRendering();
        bytes memory script = payload(s.host, s.bundleId, cap);
        if (f.libraryBundle != 0) {
            B.Facts memory lib = _facts(s.host, f.libraryBundle, cap);
            if (!lib.libraryOnly || lib.libraryBundle != 0) revert InvalidBundleRendering();
            script = bytes.concat(payload(s.host, f.libraryBundle, cap), bytes("\n;\n"), script);
        }
        // Escape after complete reconstruction, including boundaries across chunks/libraries.
        metadata.script = StreamMetadataTokenRenderer.prepareScript(string(script));
        if (mode == 3) return StreamMetadataTokenRenderer.html(token, metadata);
        if (originalCore != address(0)) {
            return StreamMetadataTokenRenderer.renderCurrent(
                2, token, metadata, artist, nestedArtist, chainId, originalCore
            );
        }
        return StreamMetadataTokenRenderer.fullJSON(token, metadata, artist);
    }

    function renderBundleForFinality(uint8 mode, bytes memory input)
        public
        view
        returns (string memory)
    {
        (
            T.Token memory token,
            F.ServingSource memory metadata,
            bytes memory artist,
            B.Selection memory s,
            address viewHost,
            uint256 chainId,
            uint256 cap
        ) = abi.decode(
            input, (T.Token, F.ServingSource, bytes, B.Selection, address, uint256, uint256)
        );
        if (
            keccak256(input)
                != keccak256(abi.encode(token, metadata, artist, s, viewHost, chainId, cap))
        ) {
            revert InvalidBundleRendering();
        }
        return _render(mode, token, metadata, artist, s, viewHost, chainId, cap, address(0), false);
    }

    function _compact(
        bool asURI,
        T.Token memory t,
        F.ServingSource memory m,
        bytes memory artist,
        B.Selection memory s,
        B.Facts memory f,
        address host,
        uint256 chainId,
        string memory citation,
        bool nestedArtist
    ) private pure returns (string memory) {
        string memory prefix = string(
            abi.encodePacked(
                "web3://", uint256(uint160(host)).toHexString(20), ":", chainId.toString()
            )
        );
        string memory suffix = string(abi.encodePacked("/", t.tokenId.toString()));
        bytes memory json = _compactJSON(t, m, artist, s, f, prefix, suffix, citation, nestedArtist);
        // Large live attribution remains available in the full view; do not mislabel it unavailable.
        if (json.length > 18000) {
            json = _compactJSON(t, m, bytes(""), s, f, prefix, suffix, citation, false);
        }
        if (json.length > 18000) {
            m.name = "6529 Stream";
            m.imageURI = "";
            json = _compactJSON(t, m, bytes(""), s, f, prefix, suffix, citation, false);
        }
        if (json.length > 18000) revert DefaultMetadataTooLarge();
        return asURI ? StreamMetadataTokenRenderer.dataURI(string(json)) : string(json);
    }

    function _compactJSON(
        T.Token memory t,
        F.ServingSource memory m,
        bytes memory artist,
        B.Selection memory s,
        B.Facts memory f,
        string memory prefix,
        string memory suffix,
        string memory citation,
        bool nestedArtist
    ) private pure returns (bytes memory) {
        return abi.encodePacked(
            '{"name":"',
            m.name,
            " #",
            t.serial.toString(),
            '","image":"',
            m.imageURI,
            '","metadata_schema_version":"6529stream-v1","metadata_state":"',
            t.state,
            '","token_id":',
            t.tokenId.toString(),
            ',"collection_id":',
            t.collectionId.toString(),
            ',"hash":"',
            uint256(t.seed).toHexString(32),
            '","token_data_location":"tokenJSON:token_data_base64","properties":{"render_mode":"compact","display_fields_location":"tokenJSON","stream":{"render_state":"',
            t.state,
            '"',
            bytes(citation).length == 0
                ? bytes("")
                : abi.encodePacked(',"citation":"', citation, '"'),
            '},"views":{"tokenHTML":"',
            prefix,
            "/tokenHTML",
            suffix,
            '","tokenJSON":"',
            prefix,
            "/tokenJSON",
            suffix,
            '"},"script_bundle":"',
            uint256(s.bundleId).toHexString(32),
            '","script_hash":"',
            uint256(f.payloadHash).toHexString(32),
            '","script_chunks":',
            uint256(f.chunkCount).toString(),
            ',"manifest_host":"',
            uint256(uint160(s.host)).toHexString(20),
            '","manifest_hash":"',
            uint256(s.manifestHash).toHexString(32),
            '"',
            nestedArtist
                ? abi.encodePacked(',"provenance":{"attribution":', artist, "}")
                : bytes(""),
            "}",
            nestedArtist ? bytes("") : artist,
            "}"
        );
    }

    function _read(address host, bytes memory data, uint256 max, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        bool ok;
        uint256 size;
        // Bounded each-read profile; full views intentionally permit many individually bounded reads.
        uint256 available = gasleft();
        if (cap == 0 || available <= 150000) revert InvalidBundleRendering();
        // A view cap is a maximum. Preserve a return reserve in nested finality source reads.
        available -= 100000;
        if (cap > available - available / 64) cap = available - available / 64;
        assembly ("memory-safe") {
            ok := staticcall(cap, host, add(data, 32), mload(data), 0, 0)
            size := returndatasize()
        }
        if (!ok || size > max || size < 32) revert InvalidBundleRendering();
        raw = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(raw, 32), 0, size) }
    }
}
