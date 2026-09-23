// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamStaticMetadataRouter as Router
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { IStreamRenderer as Renderer } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamStaticMetadataSource as Raw
} from "../../interfaces/stream/metadata/IStreamStaticMetadataSource.sol";
import {
    IStreamScriptBundles as B
} from "../../interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTokenReadsV1 as Tokens
} from "./StreamScopedPreservationPolicyRenderCriticalTokenReadsV1.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";

/// @notice Every ordered script/library chunk from the immutable selected manifest and renderer.
/// @dev URI strings remain declarations in the original manifest. They do not replace the actual
/// executable bytes. Each logical chunk and the complete ordered payload are independently hashed.
library StreamScopedPreservationPolicyRenderCriticalScriptReadsV1 {
    struct Selected {
        uint256 token;
        address renderer;
        bytes32 manifestHash;
        bytes manifest;
        bytes32 bundle;
        B.Facts facts;
    }

    function items(
        S.Dependencies memory d,
        Scoped.Context memory c,
        uint64 ordinal,
        bool libraryOnly
    ) public view returns (T.Item[] memory rows) {
        (uint256 token, Tokens.Original memory original) = Tokens.sourceAt(d, c, ordinal);
        (Router.RawSource memory source,) =
            abi.decode(original.source, (Router.RawSource, Renderer.MetadataConfig));
        if (source.scriptManifest.manifestHash == 0) {
            rows = new T.Item[](1);
            rows[0] = libraryOnly
                ? Items.absent(
                    keccak256("EXECUTABLE_LIBRARY"),
                    d.targets[4],
                    original.selection.configRecordHash,
                    token
                )
                : _row(
                    "INLINE_EXECUTABLE_SCRIPT",
                    d.targets[4],
                    original.selection.configRecordHash,
                    token,
                    bytes(source.script)
                );
            return rows;
        }
        Selected memory s = _selected(d, c, original, source, token);
        if (s.bundle == 0) {
            rows = new T.Item[](libraryOnly ? 1 : 2);
            rows[0] = libraryOnly
                ? Items.absent(keccak256("EXECUTABLE_LIBRARY"), d.targets[1], s.manifestHash, token)
                : _row("ORIGINAL_SCRIPT_MANIFEST", d.targets[1], s.manifestHash, token, s.manifest);
            if (!libraryOnly) {
                rows[1] = _row(
                    "INLINE_EXECUTABLE_SCRIPT",
                    d.targets[4],
                    s.manifestHash,
                    token,
                    bytes(source.script)
                );
            }
            return rows;
        }
        if (libraryOnly) {
            s.bundle = s.facts.libraryBundle;
            if (s.bundle == 0) {
                rows = new T.Item[](1);
                rows[0] = Items.absent(
                    keccak256("EXECUTABLE_LIBRARY"), d.targets[1], s.manifestHash, token
                );
                return rows;
            }
            (s.facts,) = _facts(d, s.bundle);
            if (!s.facts.libraryOnly || s.facts.libraryBundle != 0) {
                revert T.InvalidInventoryItem();
            }
        }
        (B.Facts memory saved, B.RegistrySource memory registry) = _facts(d, s.bundle);
        if (keccak256(abi.encode(saved)) != keccak256(abi.encode(s.facts))) {
            revert T.InventorySourceChanged();
        }
        rows = new T.Item[](uint256(s.facts.chunkCount) + (libraryOnly ? 4 : 3));
        rows[0] = _row("ORIGINAL_SCRIPT_MANIFEST", d.targets[1], s.manifestHash, token, s.manifest);
        rows[1] = _row(
            libraryOnly ? "ORIGINAL_LIBRARY_FACTS" : "ORIGINAL_SCRIPT_FACTS",
            d.targets[1],
            s.bundle,
            token,
            abi.encode(s.facts, registry)
        );
        uint256 first = 2;
        if (libraryOnly) {
            bytes memory declaration = IO.read(
                d.targets[1], abi.encodeCall(B.dependencyManifest, (s.bundle)), 10000, d.sourceGas
            );
            M.DependencyManifest memory dependency = abi.decode(declaration, (M.DependencyManifest));
            IO.canonical(d.targets[1], declaration, abi.encode(dependency));
            if (
                dependency.dependencyHash != s.facts.payloadHash
                    || dependency.sourceType != s.facts.sourceType
                    || dependency.useDependencyRegistry
                        != (s.facts.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY)
            ) {
                revert T.InvalidInventoryItem();
            }
            rows[2] =
                _row("ORIGINAL_DEPENDENCY_MANIFEST", d.targets[1], s.bundle, token, declaration);
            first = 3;
        }
        bytes memory complete = new bytes(s.facts.totalBytes);
        uint256 offset;
        for (uint256 i; i < s.facts.chunkCount; ++i) {
            bytes memory raw = IO.fixedRead(
                d.targets[1], abi.encodeCall(Raw.staticBundleChunk, (s.bundle, i)), 128, d.readGas
            );
            Raw.Chunk memory chunk = abi.decode(raw, (Raw.Chunk));
            IO.canonical(d.targets[1], raw, abi.encode(chunk));
            uint256 maximum = s.facts.sourceType == M.PayloadSourceType.SSTORE2 ? 24576 : 8192;
            if (
                chunk.length == 0 || chunk.length > maximum || chunk.hash == 0
                    || chunk.length > complete.length - offset
            ) {
                revert T.InvalidInventoryItem();
            }
            // The original selected renderer resolves the exact saved registry version/physical split.
            raw = IO.read(
                s.renderer,
                abi.encodeWithSignature("scriptBundleChunk(bytes32,uint256)", s.bundle, i),
                maximum + 64,
                d.sourceGas
            );
            bytes memory part = abi.decode(raw, (bytes));
            IO.canonical(s.renderer, raw, abi.encode(part));
            if (part.length != chunk.length || keccak256(part) != chunk.hash) {
                revert T.InvalidInventoryItem();
            }
            _copy(complete, offset, part);
            offset += part.length;
            rows[first + i] = _row(
                libraryOnly ? "EXECUTABLE_LIBRARY_CHUNK" : "EXECUTABLE_SCRIPT_CHUNK",
                s.renderer,
                s.bundle,
                i,
                part
            );
            rows[first + i].provenanceHash = keccak256(abi.encode(d.targets[1], chunk, registry));
        }
        if (offset != complete.length || keccak256(complete) != s.facts.payloadHash) {
            revert T.InvalidInventoryItem();
        }
        rows[rows.length - 1] = _row(
            libraryOnly ? "COMPLETE_EXECUTABLE_LIBRARY" : "COMPLETE_EXECUTABLE_SCRIPT",
            s.renderer,
            s.bundle,
            token,
            complete
        );
    }

    function _selected(
        S.Dependencies memory d,
        Scoped.Context memory c,
        Tokens.Original memory o,
        Router.RawSource memory source,
        uint256 token
    ) private view returns (Selected memory s) {
        if (
            source.scriptManifest.host != d.targets[1]
                || source.scriptManifest.codeHash != d.codeHashes[1]
        ) revert T.InventorySourceChanged();
        IO.pin(d.targets[1], d.codeHashes[1]);
        s.renderer = o.selection.selection.renderer;
        IO.pin(s.renderer, o.selection.selection.rendererCodeHash);
        s.token = token;
        s.manifestHash = source.scriptManifest.manifestHash;
        s.manifest = IO.read(
            d.targets[1],
            abi.encodeCall(Raw.staticScriptManifest, (s.manifestHash)),
            9504,
            d.sourceGas
        );
        (M.ScriptManifest memory manifest, bytes32 bundle, uint256 cid, address router) =
            abi.decode(s.manifest, (M.ScriptManifest, bytes32, uint256, address));
        IO.canonical(d.targets[1], s.manifest, abi.encode(manifest, bundle, cid, router));
        if (
            cid != c.scope.collectionId || router != d.targets[4] || !manifest.executable
                || keccak256(bytes(manifest.mimeType)) != keccak256("application/javascript")
        ) revert T.InvalidInventoryItem();
        s.bundle = bundle;
        bytes32 original;
        if (bundle == 0) {
            bytes32 hash = keccak256(bytes(source.script));
            if (
                manifest.scriptHash != hash || manifest.chunkCount != 1
                    || manifest.sourceType != M.PayloadSourceType.INLINE_CHUNKS
            ) {
                revert T.InvalidInventoryItem();
            }
            original = keccak256(
                abi.encode(
                    keccak256("6529STREAM_CURRENT_SCRIPT_MANIFEST_V1"),
                    d.chainId,
                    d.targets[0],
                    d.targets[1],
                    router,
                    router.codehash,
                    cid,
                    hash,
                    manifest
                )
            );
        } else {
            (s.facts,) = _facts(d, bundle);
            if (
                s.facts.libraryOnly || s.facts.payloadHash != manifest.scriptHash
                    || s.facts.chunkCount != manifest.chunkCount
                    || s.facts.sourceType != manifest.sourceType
            ) revert T.InvalidInventoryItem();
            original = keccak256(
                abi.encode(
                    keccak256("6529STREAM_CHUNKED_SCRIPT_MANIFEST_V1"),
                    d.chainId,
                    d.targets[0],
                    d.targets[1],
                    router,
                    router.codehash,
                    cid,
                    bundle,
                    s.facts,
                    manifest
                )
            );
        }
        if (original != s.manifestHash) revert T.InventorySourceChanged();
    }

    function _facts(S.Dependencies memory d, bytes32 id)
        private
        view
        returns (B.Facts memory f, B.RegistrySource memory registry)
    {
        bytes memory raw =
            IO.fixedRead(d.targets[1], abi.encodeCall(Raw.staticBundle, (id)), 384, d.readGas);
        (f, registry) = abi.decode(raw, (B.Facts, B.RegistrySource));
        IO.canonical(d.targets[1], raw, abi.encode(f, registry));
        if (
            !f.finalized || f.chunkCount == 0 || f.chunkCount > 32 || f.totalBytes == 0
                || f.totalBytes > 786432 || f.payloadHash == 0
                || (f.sourceType != M.PayloadSourceType.INLINE_CHUNKS
                    && f.sourceType != M.PayloadSourceType.SSTORE2
                    && !(f.libraryOnly && f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY))
        ) revert T.InvalidInventoryItem();
        if (f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY) {
            IO.pin(registry.registry, registry.codeHash);
        }
    }

    function _copy(bytes memory destination, uint256 offset, bytes memory part) private pure {
        uint256 words = part.length & ~uint256(31);
        assembly ("memory-safe") {
            for { let j := 0 } lt(j, words) { j := add(j, 32) } {
                mstore(add(add(destination, 32), add(offset, j)), mload(add(add(part, 32), j)))
            }
        }
        for (uint256 i = words; i < part.length; ++i) {
            destination[offset + i] = part[i];
        }
    }

    function _row(
        string memory role,
        address host,
        bytes32 record,
        uint256 index,
        bytes memory value
    ) private pure returns (T.Item memory) {
        return Items.bytesItem(
            T.Kind.NATIVE_BYTES, keccak256(bytes(role)), host, record, index, value
        );
    }
}
