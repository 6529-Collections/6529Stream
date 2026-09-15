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
import { Strings } from "../../vendor/openzeppelin/Strings.sol";

/// @notice Actual saved chunk-profile sources for component evidence and explicit content checkpoints.
/// @dev Reads fixed Router selection and immutable manifest/bundle facts, never current replacement pointers.
library StreamChunkedContentEvidence {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1");

    struct Evidence {
        B.Selection selection;
        B.Facts script;
        B.Facts libraryFacts;
        B.RegistrySource registry;
        bytes32 scriptCommitment;
        bytes32 dependencyCommitment;
    }
    error InvalidChunkedEvidence(address target);
    error ChunkedEvidenceGas(uint256 available, uint256 required);

    function selected(address router, uint256 collectionId, uint256 cap)
        public
        view
        returns (bool)
    {
        uint256 capability = abi.decode(
            read(
                router,
                abi.encodeWithSelector(
                    bytes4(0x01ffc9a7), type(IStreamScriptBundleSelection).interfaceId
                ),
                32,
                cap
            ),
            (uint256)
        );
        if (capability > 1) revert InvalidChunkedEvidence(router);
        if (capability == 0) return false;
        B.Selection memory s = abi.decode(
            read(
                router,
                abi.encodeCall(IStreamScriptBundleSelection.collectionScriptBundle, (collectionId)),
                128,
                cap
            ),
            (B.Selection)
        );
        return s.bundleId != 0;
    }

    function source(
        address core,
        address router,
        uint256 chainId,
        uint256 collectionId,
        F.ServingFacts memory f,
        uint256 cap,
        bool includeDependencies
    ) public view returns (Evidence memory e) {
        if (
            chainId != block.chainid || f.presentationProfile != PROFILE || !f.configured
                || f.mode != keccak256("ONCHAIN") || f.scriptBytes == 0 || f.scriptBytes > 786432
                || f.scriptHash == 0
        ) revert InvalidChunkedEvidence(router);
        e.selection = abi.decode(
            read(
                router,
                abi.encodeCall(IStreamScriptBundleSelection.collectionScriptBundle, (collectionId)),
                128,
                cap
            ),
            (B.Selection)
        );
        B.Selection memory s = e.selection;
        if (
            s.bundleId == 0 || s.manifestHash == 0 || s.host.code.length == 0
                || s.host.codehash != s.codeHash
                || abi.decode(read(s.host, abi.encodeWithSignature("core()"), 32, cap), (address))
                    != core
                || abi.decode(
                        read(
                            s.host,
                            abi.encodeCall(B.recordedScriptBundle, (s.manifestHash)),
                            32,
                            cap
                        ),
                        (bytes32)
                    ) != s.bundleId
        ) revert InvalidChunkedEvidence(s.host);
        e.script = _facts(s.host, s.bundleId, cap);
        if (
            e.script.libraryOnly || e.script.payloadHash != f.scriptHash
                || e.script.totalBytes != f.scriptBytes
        ) revert InvalidChunkedEvidence(s.host);
        bytes memory raw = dynamicRead(
            s.host,
            abi.encodeWithSignature("recordedScriptManifest(bytes32)", s.manifestHash),
            8192,
            cap
        );
        M.ScriptManifest memory m = abi.decode(raw, (M.ScriptManifest));
        if (
            keccak256(raw) != keccak256(abi.encode(m)) || m.rendererCompatibility != PROFILE
                || !m.executable || m.scriptHash != e.script.payloadHash
                || m.sourceType != e.script.sourceType || m.chunkCount != e.script.chunkCount
                || bytes(m.libraryURI).length > 2048 || bytes(m.scriptURI).length > 2048
                || keccak256(bytes(m.mimeType)) != keccak256("application/javascript")
                || keccak256(bytes(m.sourcePointer))
                    != keccak256(bytes(Strings.toHexString(uint256(s.bundleId), 32)))
                || s.manifestHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CHUNKED_SCRIPT_MANIFEST_V1"),
                            chainId,
                            core,
                            s.host,
                            router,
                            router.codehash,
                            collectionId,
                            s.bundleId,
                            e.script,
                            m
                        )
                    )
        ) revert InvalidChunkedEvidence(s.host);
        if (includeDependencies && e.script.libraryBundle != 0) {
            e.libraryFacts = _facts(s.host, e.script.libraryBundle, cap);
            if (!e.libraryFacts.libraryOnly || e.libraryFacts.libraryBundle != 0) {
                revert InvalidChunkedEvidence(s.host);
            }
            e.registry = abi.decode(
                read(
                    s.host,
                    abi.encodeCall(B.scriptBundleRegistry, (e.script.libraryBundle)),
                    160,
                    cap
                ),
                (B.RegistrySource)
            );
            if (e.libraryFacts.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY) {
                B.RegistrySource memory g = e.registry;
                if (
                    g.registry.code.length == 0 || g.registry.codehash != g.codeHash
                        || g.version == 0 || g.dependencyId == 0 || g.contentHash == 0
                        || abi.decode(
                                read(
                                    g.registry,
                                    abi.encodeWithSignature(
                                        "getDependencyScriptContentHashAtVersion(bytes32,uint256)",
                                        g.dependencyId,
                                        g.version
                                    ),
                                    32,
                                    cap
                                ),
                                (bytes32)
                            ) != g.contentHash
                ) revert InvalidChunkedEvidence(g.registry);
            } else if (
                keccak256(abi.encode(e.registry))
                    != keccak256(abi.encode(B.RegistrySource(address(0), 0, 0, 0, 0)))
            ) {
                revert InvalidChunkedEvidence(s.host);
            }
        } else if (e.script.libraryBundle == 0 && bytes(m.libraryURI).length != 0) {
            revert InvalidChunkedEvidence(s.host);
        }
        e.scriptCommitment = keccak256(abi.encode(s, e.script, m));
        if (includeDependencies) {
            e.dependencyCommitment = keccak256(
                abi.encode(s.host, s.codeHash, e.script.libraryBundle, e.libraryFacts, e.registry)
            );
        }
    }

    function renderer(F.ServingFacts memory f, uint256 cap)
        public
        view
        returns (bytes32 context, bytes32 dependencies)
    {
        if (f.renderer.code.length == 0 || f.renderer.codehash != f.rendererCodeHash) {
            revert InvalidChunkedEvidence(f.renderer);
        }
        bytes memory raw = read(f.renderer, abi.encodeWithSignature("renderingProfile()"), 96, cap);
        context = keccak256("6529STREAM_CHUNKED_RENDER_CONTEXT_V1");
        dependencies = keccak256("6529STREAM_PINNED_BUNDLE_DEPENDENCIES_V1");
        if (keccak256(raw) != keccak256(abi.encode(PROFILE, context, dependencies))) {
            revert InvalidChunkedEvidence(f.renderer);
        }
    }

    function _facts(address host, bytes32 id, uint256 cap) private view returns (B.Facts memory f) {
        bytes memory raw = read(host, abi.encodeCall(B.scriptBundle, (id)), 224, cap);
        f = abi.decode(raw, (B.Facts));
        if (
            keccak256(raw) != keccak256(abi.encode(f)) || !f.finalized || f.payloadHash == 0
                || f.chunkCount == 0 || f.chunkCount > 32 || f.totalBytes == 0
                || f.totalBytes > 786432
                || (f.sourceType != M.PayloadSourceType.INLINE_CHUNKS
                    && f.sourceType != M.PayloadSourceType.SSTORE2
                    && !(f.libraryOnly && f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY))
        ) revert InvalidChunkedEvidence(host);
    }

    function read(address target, bytes memory data, uint256 size, uint256 cap)
        internal
        view
        returns (bytes memory raw)
    {
        raw = dynamicRead(target, data, size, cap);
        if (raw.length != size) revert InvalidChunkedEvidence(target);
    }

    function dynamicRead(address target, bytes memory data, uint256 maximum, uint256 cap)
        internal
        view
        returns (bytes memory raw)
    {
        uint256 pointer;
        assembly ("memory-safe") { pointer := mload(0x40) }
        uint256 words = (pointer + 32 + maximum + 31) / 32;
        // Reserve the full envelope memory expansion/copy before forwarding. Allocation
        // still uses only actual returndata. This bound is not a measured execution floor.
        uint256 required = cap + cap / 63 + 100000 + 9 * words + words * words / 512;
        if (cap == 0 || gasleft() <= required) revert ChunkedEvidenceGas(gasleft(), required);
        bool ok;
        uint256 length;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 0)
            length := returndatasize()
        }
        if (!ok || length > maximum) revert InvalidChunkedEvidence(target);
        raw = new bytes(length);
        assembly ("memory-safe") { returndatacopy(add(raw, 32), 0, length) }
    }
}
