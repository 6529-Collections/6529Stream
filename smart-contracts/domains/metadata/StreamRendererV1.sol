// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import {
    IStreamStaticMetadataSource as Raw
} from "../../interfaces/stream/metadata/IStreamStaticMetadataSource.sol";
import {
    IStreamScriptBundles as B
} from "../../interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import { IStreamCoreMint as Mint } from "../../interfaces/stream/core/IStreamCoreMint.sol";
import {
    IStreamStaticEntropySource as StaticEntropy
} from "../../interfaces/stream/metadata/IStreamStaticEntropySource.sol";
import { StreamRendererCalls as Calls } from "./StreamRendererCalls.sol";
import { StreamRenderContextV1 as Context } from "./StreamRenderContextV1.sol";
import { StreamStaticText as Text } from "./StreamStaticText.sol";
import {
    StreamStaticAttributionCompanion as Attribution
} from "./StreamStaticAttributionCompanion.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";
import { StreamStaticRenderEncoding as Encoding } from "./StreamStaticRenderEncoding.sol";

/// @notice Versioned STATIC rendering API and full executable reads from exact pinned sources.
/// @dev RenderRequest is an input, not a claim of token existence. The actual Router builds it
/// from Core/original entropy and its selected immutable config. Registration golden vectors
/// may use the explicit zero-config/zero-token empty source before a collection or token exists.
contract StreamRendererV1 is R, StreamGasParameterHost {
    using Strings for uint256;
    bytes32 public constant ID = keccak256("6529STREAM_RENDERER_V1");
    bytes32 public constant VERSION = keccak256("6529STREAM_STATIC_RENDERER_V1");
    bytes32 public constant CONTEXT = keccak256("STREAM_CONTEXT_V1");
    bytes32 public constant READ_GAS = keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    bytes32 public constant ATTRIBUTION_GAS = keccak256("6529STREAM_GGP_STATIC_ATTRIBUTION_GAS");
    uint256 public constant MAX_DEFAULT_URI_BYTES = 24576;
    // Structural envelope above worst-case sixfold JSON escaping of both full 32 x 24,576
    // payloads, duplicated library context, HTML base64 and bounded token/metadata/AA fields.
    // This leaves the declared payload limits intact; execution is still subject to node/GGP gas.
    uint256 public constant MAX_FULL_BYTES = 16777216;

    struct Sources {
        address core;
        address router;
        address metadata;
        address entropy;
        address dependencyRegistry;
        address attribution;
    }

    struct Deployment {
        Sources sources;
        address executor;
        GasParameterConfig readGas;
        GasParameterConfig attributionGas;
        RendererManifest manifest;
    }

    Sources private _sources;
    bytes32[6] private _codeHashes;
    RendererManifest private _manifest;
    bytes32 private immutable _encodingCodeHash;

    function encodingBinding() external view returns (address, bytes32) {
        return (address(Encoding), _encodingCodeHash);
    }

    function _encodingPin() private view {
        if (address(Encoding).code.length == 0 || address(Encoding).codehash != _encodingCodeHash) {
            revert InvalidStaticRender();
        }
    }
    error InvalidStaticRender();
    error InvalidRenderContext(); // Original pure-context error remains in the Renderer ABI.
    error StaticOutputTooLarge();

    constructor(Deployment memory d) StreamGasParameterHost(d.executor) {
        if (
            d.sources.core.code.length == 0 || d.sources.router.code.length == 0
                || d.sources.metadata.code.length == 0 || d.sources.entropy.code.length == 0
                || d.sources.attribution.code.length == 0 || d.manifest.rendererId != ID
                || d.manifest.rendererVersion != VERSION || d.manifest.contextVersion != CONTEXT
                || d.manifest.rendererClass != keccak256("STATIC") || d.manifest.deprecated
                || d.manifest.schemaHash == 0 || d.manifest.manifestHash == 0
                || d.manifest.maxJSONBytes != MAX_FULL_BYTES
                || d.manifest.maxHTMLBytes != MAX_FULL_BYTES || d.readGas.failureClass != 2
                || d.attributionGas.failureClass != 1
                || _registerGasParameter(d.readGas) != READ_GAS
                || _registerGasParameter(d.attributionGas) != ATTRIBUTION_GAS
        ) revert InvalidStaticRender();
        if (
            Attribution(d.sources.attribution).core() != d.sources.core
                || Attribution(d.sources.attribution).router() != d.sources.router
        ) revert InvalidStaticRender();
        if (address(Encoding).code.length == 0) revert InvalidStaticRender();
        _encodingCodeHash = address(Encoding).codehash;
        _sources = d.sources;
        address[6] memory a = [
            d.sources.core,
            d.sources.router,
            d.sources.metadata,
            d.sources.entropy,
            d.sources.dependencyRegistry,
            d.sources.attribution
        ];
        for (uint256 i; i < 6; ++i) {
            _codeHashes[i] = a[i].codehash;
        }
        _manifest = d.manifest;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(R).interfaceId || id == 0x01ffc9a7;
    }

    function rendererVersion() external pure override returns (bytes32) {
        return VERSION;
    }

    function renderContextVersion() external pure override returns (bytes32) {
        return CONTEXT;
    }

    function rendererManifest() external view override returns (RendererManifest memory) {
        return _manifest;
    }

    function sourceBindings() external view returns (Sources memory, bytes32[6] memory) {
        return (_sources, _codeHashes);
    }

    function tokenURI(RenderRequest calldata r) external view override returns (string memory) {
        return _render(r, 1);
    }

    /// @param mode 0 compact JSON, 1 marketplace URI, 2 full JSON, 3 full executable HTML.
    function renderView(RenderRequest calldata r, uint8 mode)
        external
        view
        returns (string memory)
    {
        return _render(r, mode);
    }

    function _render(RenderRequest memory r, uint8 mode) private view returns (string memory) {
        if (mode > 3 || r.core != _sources.core || r.viewId != 0 || r.viewManifestHash != 0) {
            revert InvalidStaticRender();
        }
        Encoding.Prepared memory p = _prepare(r);
        if (mode == 1 && p.config.mode == MetadataMode.OFFCHAIN) {
            if (
                r.state == TokenRenderState.PENDING_RANDOMNESS
                    && bytes(p.config.pendingURI).length != 0
            ) return p.config.pendingURI;
            return string.concat(
                p.config.baseURI,
                (p.config.offchainURIIdMode == OffchainURIIdMode.TOKEN_ID
                        ? r.tokenId
                        : r.collectionSerial)
                .toString()
            );
        }
        if (mode == 3 && r.state == TokenRenderState.PENDING_RANDOMNESS) {
            revert InvalidStaticRender();
        }
        bool full = mode >= 2;
        string memory script = p.source.script;
        if (p.bundle != 0 && full) {
            script = string(_payload(p.bundle, p.bundleFacts));
            if (p.bundleFacts.libraryBundle != 0) {
                B.Facts memory libraryFacts = _bundleFacts(p.bundleFacts.libraryBundle);
                if (!libraryFacts.libraryOnly || libraryFacts.libraryBundle != 0) {
                    revert InvalidStaticRender();
                }
                p.facts.dependencyScript =
                    string(_payload(p.bundleFacts.libraryBundle, libraryFacts));
            }
        }
        _encodingPin();
        bytes memory input =
            abi.encodeWithSelector(Encoding.render.selector, r, p, script, _sources.router, mode);
        uint256 maximum = mode == 1 ? MAX_DEFAULT_URI_BYTES : mode == 0 ? 18000 : MAX_FULL_BYTES;
        bytes memory raw =
            Calls.fixedCode(address(Encoding), input, 64 + ((maximum + 31) / 32) * 32, gasleft());
        return Calls.stringResult(raw, maximum);
    }

    function _prepare(RenderRequest memory r) private view returns (Encoding.Prepared memory p) {
        _pin(0, _sources.core);
        _pin(1, _sources.router);
        bytes memory raw = _read(
            _sources.router,
            abi.encodeCall(S.staticRenderSourceForConfig, (r.collectionId, r.metadataSnapshotHash)),
            20736,
            false
        );
        (p.source, p.config) = abi.decode(raw, (S.RawSource, MetadataConfig));
        if (
            keccak256(raw) != keccak256(abi.encode(p.source, p.config)) || p.config.mode != r.mode
                || (r.metadataSnapshotHash != 0 && p.config.renderer != address(this))
        ) revert InvalidStaticRender();
        if (!p.source.configured && (r.metadataSnapshotHash != 0 || r.tokenId != 0)) {
            revert InvalidStaticRender();
        }
        p.facts.chainId = p.source.chainId;
        p.facts.viewName = "MARKETPLACE";
        if (r.tokenId != 0) {
            bytes memory tokenRaw =
                _read(_sources.core, abi.encodeCall(Mint.tokenData, (r.tokenId)), 16448, false);
            p.facts.tokenData = abi.decode(tokenRaw, (bytes));
            if (
                p.facts.tokenData.length > 16384
                    || keccak256(tokenRaw) != keccak256(abi.encode(p.facts.tokenData))
            ) revert InvalidStaticRender();
            _pin(3, _sources.entropy);
            (uint8 status,, address provider) = abi.decode(
                _read(
                    _sources.entropy,
                    abi.encodeCall(StaticEntropy.staticTokenRenderFacts, (r.tokenId)),
                    96,
                    true
                ),
                (uint8, bytes32, address)
            );
            if (status > 7) revert InvalidStaticRender();
            p.facts.entropyStatus = status;
            p.facts.entropyProvider = provider;
        }
        p.facts.scriptHash = keccak256(bytes(p.source.script));
        M.Selection memory selected = p.source.scriptManifest;
        if (selected.manifestHash != 0) {
            _manifestPin(selected);
            bytes memory manifestRaw = _read(
                selected.host,
                abi.encodeCall(Raw.staticScriptManifest, (selected.manifestHash)),
                9504,
                false
            );
            M.ScriptManifest memory m;
            uint256 collectionId;
            address router;
            (m, p.bundle, collectionId, router) =
                abi.decode(manifestRaw, (M.ScriptManifest, bytes32, uint256, address));
            if (
                keccak256(manifestRaw) != keccak256(abi.encode(m, p.bundle, collectionId, router))
                    || collectionId != r.collectionId || router != _sources.router
            ) revert InvalidStaticRender();
            if (
                !m.executable || keccak256(bytes(m.mimeType)) != keccak256("application/javascript")
            ) revert InvalidStaticRender();
            if (p.bundle != 0) {
                p.bundleFacts = _bundleFacts(p.bundle);
                if (
                    p.bundleFacts.libraryOnly || p.bundleFacts.payloadHash != m.scriptHash
                        || p.bundleFacts.chunkCount != m.chunkCount
                ) revert InvalidStaticRender();
                p.facts.scriptHash = p.bundleFacts.payloadHash;
                if (p.bundleFacts.libraryBundle != 0) {
                    B.Facts memory libraryFacts = _bundleFacts(p.bundleFacts.libraryBundle);
                    if (!libraryFacts.libraryOnly || libraryFacts.libraryBundle != 0) {
                        revert InvalidStaticRender();
                    }
                    p.facts.dependencyHash = libraryFacts.payloadHash;
                }
            } else if (
                m.scriptHash != p.facts.scriptHash || m.chunkCount != 1
                    || m.sourceType != M.PayloadSourceType.INLINE_CHUNKS
            ) {
                revert InvalidStaticRender();
            }
        }
        selected = p.source.mediaManifest;
        if (selected.manifestHash != 0) {
            _manifestPin(selected);
            p.facts.mediaManifestHash = selected.manifestHash;
        }
        p.artist = _attribution(r.collectionId, r.tokenId);
    }

    function _bundleFacts(bytes32 id) private view returns (B.Facts memory f) {
        _pin(2, _sources.metadata);
        (f,) = abi.decode(
            _read(_sources.metadata, abi.encodeCall(Raw.staticBundle, (id)), 416, true),
            (B.Facts, B.RegistrySource)
        );
        if (
            !f.finalized || f.chunkCount == 0 || f.chunkCount > 32 || f.totalBytes == 0
                || f.totalBytes > 786432 || f.payloadHash == 0
                || (f.sourceType != M.PayloadSourceType.INLINE_CHUNKS
                    && f.sourceType != M.PayloadSourceType.SSTORE2
                    && !(f.libraryOnly && f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY))
        ) revert InvalidStaticRender();
    }

    /// @notice Exact bounded reconstruction read; the same routine supplies assembled HTML/JSON.
    /// @dev bundleId is the immutable selected manifest's script or library bundle. A page proves
    /// its saved chunk hash; clients must still check the full ordered payload hash from facts.
    function scriptBundleChunk(bytes32 bundleId, uint256 index)
        external
        view
        returns (bytes memory)
    {
        B.Facts memory f = _bundleFacts(bundleId);
        if (index >= f.chunkCount) revert InvalidStaticRender();
        Raw.Chunk memory c = abi.decode(
            _read(
                _sources.metadata,
                abi.encodeCall(Raw.staticBundleChunk, (bundleId, index)),
                128,
                true
            ),
            (Raw.Chunk)
        );
        uint256 maximum = f.sourceType == M.PayloadSourceType.SSTORE2 ? 24576 : 8192;
        if (c.length == 0 || c.length > maximum || c.hash == 0) revert InvalidStaticRender();
        B.RegistrySource memory source;
        if (f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY) {
            (, source) = abi.decode(
                _read(_sources.metadata, abi.encodeCall(Raw.staticBundle, (bundleId)), 416, true),
                (B.Facts, B.RegistrySource)
            );
            if (source.registry != _sources.dependencyRegistry || source.codeHash != _codeHashes[4])
            {
                revert InvalidStaticRender();
            }
            _pin(4, source.registry);
            if (
                abi.decode(
                        _read(
                            source.registry,
                            abi.encodeWithSignature(
                                "getDependencyScriptContentHashAtVersion(bytes32,uint256)",
                                source.dependencyId,
                                source.version
                            ),
                            32,
                            true
                        ),
                        (bytes32)
                    ) != source.contentHash
            ) revert InvalidStaticRender();
        }
        bytes memory part = _chunkPayload(f, source, c, index);
        if (part.length != c.length || keccak256(part) != c.hash) revert InvalidStaticRender();
        return part;
    }

    function scriptBundleFacts(bytes32 bundleId) external view returns (B.Facts memory) {
        return _bundleFacts(bundleId);
    }

    function _chunkPayload(
        B.Facts memory f,
        B.RegistrySource memory source,
        Raw.Chunk memory c,
        uint256 index
    ) private view returns (bytes memory part) {
        if (f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY) {
            if (c.first != address(0) || c.tail != address(0)) revert InvalidStaticRender();
            bytes memory raw = _read(
                source.registry,
                abi.encodeWithSignature(
                    "getDependencyScriptAtVersion(bytes32,uint256,uint256)",
                    source.dependencyId,
                    source.version,
                    index
                ),
                8256,
                false
            );
            string memory value = abi.decode(raw, (string));
            if (keccak256(raw) != keccak256(abi.encode(value))) revert InvalidStaticRender();
            return bytes(value);
        }
        uint256 firstLength = c.length > 24575 ? 24575 : c.length;
        if (
            c.first.code.length != firstLength + 1
                || (c.length > 24575 ? c.tail.code.length != 2 : c.tail != address(0))
        ) revert InvalidStaticRender();
        part = new bytes(c.length);
        address first = c.first;
        address tail = c.tail;
        assembly ("memory-safe") { extcodecopy(first, add(part, 32), 1, firstLength) }
        if (tail != address(0)) {
            assembly ("memory-safe") { extcodecopy(tail, add(add(part, 32), firstLength), 1, 1) }
        }
    }

    function _payload(bytes32 id, B.Facts memory f) private view returns (bytes memory out) {
        B.RegistrySource memory source;
        if (f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY) {
            (, source) = abi.decode(
                _read(_sources.metadata, abi.encodeCall(Raw.staticBundle, (id)), 416, true),
                (B.Facts, B.RegistrySource)
            );
            if (source.registry != _sources.dependencyRegistry || source.codeHash != _codeHashes[4])
            {
                revert InvalidStaticRender();
            }
            _pin(4, source.registry);
        }
        out = new bytes(f.totalBytes);
        uint256 offset;
        bytes32 sequence;
        uint256 maximum = f.sourceType == M.PayloadSourceType.SSTORE2 ? 24576 : 8192;
        for (uint256 i; i < f.chunkCount; ++i) {
            Raw.Chunk memory c = abi.decode(
                _read(_sources.metadata, abi.encodeCall(Raw.staticBundleChunk, (id, i)), 128, true),
                (Raw.Chunk)
            );
            if (
                c.length == 0 || c.length > maximum || c.hash == 0 || c.length > out.length - offset
            ) {
                revert InvalidStaticRender();
            }
            bytes memory part = _chunkPayload(f, source, c, i);
            if (f.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY) {
                bytes32 typed = keccak256(
                    abi.encode(
                        keccak256(
                            "6529StreamDependencyScriptChunk(uint256 index,bytes32 chunkHash,uint256 byteLength)"
                        ),
                        i,
                        c.hash,
                        uint256(c.length)
                    )
                );
                sequence = keccak256(abi.encode(sequence, typed));
            }
            if (part.length != c.length || keccak256(part) != c.hash) revert InvalidStaticRender();
            uint256 words = part.length & ~uint256(31);
            assembly ("memory-safe") {
                for { let j := 0 } lt(j, words) { j := add(j, 32) } {
                    mstore(add(add(out, 32), add(offset, j)), mload(add(add(part, 32), j)))
                }
            }
            for (uint256 j = words; j < part.length; ++j) {
                out[offset + j] = part[j];
            }
            offset += part.length;
        }
        if (source.registry != address(0)) {
            bytes32 content = keccak256(
                abi.encode(
                    keccak256(
                        "6529StreamDependencyScript(bytes32 dependencyNameAndVersion,uint256 chunkCount,bytes32 chunksHash)"
                    ),
                    source.dependencyId,
                    uint256(f.chunkCount),
                    sequence
                )
            );
            if (
                content != source.contentHash
                    || abi.decode(
                            _read(
                                source.registry,
                                abi.encodeWithSignature(
                                    "getDependencyScriptContentHashAtVersion(bytes32,uint256)",
                                    source.dependencyId,
                                    source.version
                                ),
                                32,
                                true
                            ),
                            (bytes32)
                        ) != content
            ) revert InvalidStaticRender();
        }
        if (
            offset != out.length || keccak256(out) != f.payloadHash
                || !Text.isValidUtf8(string(out))
        ) {
            revert InvalidStaticRender();
        }
    }

    function _attribution(uint256 id, uint256 token) private view returns (bytes memory value) {
        address a = _sources.attribution;
        if (a.code.length == 0 || a.codehash != _codeHashes[5]) {
            return '{"state":"attribution_unavailable"}';
        }
        uint256 cap = _gasParameterValue(ATTRIBUTION_GAS);
        uint256 available = gasleft();
        if (available <= cap + cap / 63 + 200000) return '{"state":"attribution_unavailable"}';
        bytes memory input = abi.encodeCall(Attribution.attribution, (id, token));
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, a, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size < 64 || size > 32832) return '{"state":"attribution_unavailable"}';
        bytes memory raw = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(raw, 32), 0, size) }
        uint256 start;
        uint256 length;
        assembly ("memory-safe") {
            start := mload(add(raw, 32))
            length := mload(add(raw, 64))
        }
        if (start != 32 || length > 32768 || size != 64 + ((length + 31) / 32) * 32) {
            return '{"state":"attribution_unavailable"}';
        }
        value = abi.decode(raw, (bytes));
        if (keccak256(raw) != keccak256(abi.encode(value))) {
            return '{"state":"attribution_unavailable"}';
        }
    }

    function _manifestPin(M.Selection memory s) private view {
        if (s.host != _sources.metadata || s.codeHash != _codeHashes[2]) {
            revert InvalidStaticRender();
        }
        _pin(2, s.host);
    }

    function _pin(uint256 i, address a) private view {
        if (a.code.length == 0 || a.codehash != _codeHashes[i]) revert InvalidStaticRender();
    }

    function _read(address a, bytes memory input, uint256 maximum, bool exact)
        private
        view
        returns (bytes memory)
    {
        return Calls.read(a, input, maximum, exact, _gasParameterValue(READ_GAS));
    }
}
