// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScriptBundles as B
} from "../../interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    IStreamGasParameterHost as BundleGasHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";
import { SSTORE2 } from "../../libraries/SSTORE2.sol";
import { StreamMetadataRenderer } from "./StreamMetadataRenderer.sol";

/// @notice Write-once logical chunks; a full 24,576-byte chunk uses two physical STOP blobs.
library StreamScriptBundles {
    bytes32 public constant PROFILE = keccak256("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1");

    struct Chunk {
        bytes32 hash;
        uint32 length;
        address first;
        address tail;
    }

    struct Bundle {
        B.Facts facts;
        Chunk[] chunks;
        uint8 nextChunk;
        uint8 utf8Remaining;
        uint8 utf8Min;
        uint8 utf8Max;
    }

    struct State {
        mapping(bytes32 => Bundle) bundles;
        mapping(bytes32 => bytes32) manifests;
        mapping(bytes32 => B.RegistrySource) registrySources;
    }
    event ScriptBundleBegun(
        uint16 schemaVersion,
        bytes32 indexed bundleId,
        bytes32 payloadHash,
        bytes32 libraryBundle,
        uint32 totalBytes,
        uint8 chunks,
        bool libraryOnly
    );
    event ScriptBundleChunkStored(
        uint16 schemaVersion,
        bytes32 indexed bundleId,
        uint256 indexed index,
        bytes32 payloadHash,
        address first,
        address tail
    );
    event ScriptBundleFinalized(
        uint16 schemaVersion, bytes32 indexed bundleId, bytes32 payloadHash
    );

    function write(State storage s, bytes calldata data) public returns (bytes memory) {
        bytes4 selector = bytes4(data);
        if (selector == B.beginScriptBundle.selector) {
            return abi.encode(begin(s, abi.decode(data[4:], (B.Plan))));
        }
        if (selector == B.beginRegistryLibrary.selector) {
            (B.Plan memory p, B.RegistrySource memory source) =
                abi.decode(data[4:], (B.Plan, B.RegistrySource));
            return abi.encode(beginRegistry(s, p, source));
        }
        if (selector == B.appendScriptBundle.selector) {
            (bytes32 id, uint256 index, bytes memory payload) =
                abi.decode(data[4:], (bytes32, uint256, bytes));
            append(s, id, index, payload);
            return "";
        }
        if (selector == B.finalizeScriptBundle.selector) {
            finish(s, abi.decode(data[4:], (bytes32)));
            return "";
        }
        revert B.InvalidScriptBundle(0);
    }

    function read(State storage s, bytes calldata data) public view returns (bytes memory) {
        bytes4 selector = bytes4(data);
        if (selector == B.scriptBundle.selector) {
            return abi.encode(facts(s, abi.decode(data[4:], (bytes32))));
        }
        if (selector == B.dependencyManifest.selector) {
            return abi.encode(dependencyManifest(s, abi.decode(data[4:], (bytes32))));
        }
        if (selector == B.scriptBundleRegistry.selector) {
            return abi.encode(registry(s, abi.decode(data[4:], (bytes32))));
        }
        if (selector == B.recordedScriptBundle.selector) {
            return abi.encode(s.manifests[abi.decode(data[4:], (bytes32))]);
        }
        if (selector == B.scriptBundleChunk.selector || selector == B.dependencyChunk.selector) {
            (bytes32 id, uint256 index) = abi.decode(data[4:], (bytes32, uint256));
            return abi.encode(
                selector == B.dependencyChunk.selector
                    ? dependency(s, id, index)
                    : chunk(s, id, index)
            );
        }
        if (selector == B.scriptBundleChunks.selector) {
            (bytes32 id, uint256 start, uint256 count) =
                abi.decode(data[4:], (bytes32, uint256, uint256));
            return abi.encode(page(s, id, start, count));
        }
        revert B.InvalidScriptBundle(0);
    }

    function begin(State storage s, B.Plan memory p) public returns (bytes32) {
        if (p.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY) {
            revert B.InvalidScriptBundle(0);
        }
        return _begin(s, p, 0);
    }

    function _begin(State storage s, B.Plan memory p, bytes32 sourceHash)
        private
        returns (bytes32 id)
    {
        uint256 count = p.chunkHashes.length;
        if (
            count == 0 || count > 32 || p.chunkLengths.length != count || p.payloadHash == 0
                || (p.sourceType != M.PayloadSourceType.INLINE_CHUNKS
                    && p.sourceType != M.PayloadSourceType.SSTORE2
                    && !(p.libraryOnly && p.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY))
                || (p.libraryOnly && p.libraryBundle != 0)
        ) revert B.InvalidScriptBundle(0);
        if (p.libraryBundle != 0) {
            B.Facts memory lib = facts(s, p.libraryBundle);
            if (!lib.finalized || !lib.libraryOnly) revert B.InvalidScriptBundle(p.libraryBundle);
        }
        uint32 total;
        uint256 cap = p.sourceType == M.PayloadSourceType.SSTORE2 ? 24576 : 8192;
        for (uint256 i; i < count; ++i) {
            if (p.chunkLengths[i] == 0 || p.chunkLengths[i] > cap || p.chunkHashes[i] == 0) {
                revert B.InvalidScriptBundle(0);
            }
            total += p.chunkLengths[i];
        }
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_IMMUTABLE_SCRIPT_BUNDLE_V1"),
                block.chainid,
                address(this),
                p,
                sourceHash
            )
        );
        Bundle storage b = s.bundles[id];
        if (b.facts.chunkCount != 0) return id;
        b.facts = B.Facts(
            p.payloadHash, p.libraryBundle, total, uint8(count), p.sourceType, p.libraryOnly, false
        );
        for (uint256 i; i < count; ++i) {
            b.chunks.push(Chunk(p.chunkHashes[i], p.chunkLengths[i], address(0), address(0)));
        }
        emit ScriptBundleBegun(
            1, id, p.payloadHash, p.libraryBundle, total, uint8(count), p.libraryOnly
        );
    }

    function beginRegistry(State storage s, B.Plan memory p, B.RegistrySource memory source)
        public
        returns (bytes32 id)
    {
        if (
            !p.libraryOnly || p.libraryBundle != 0
                || p.sourceType != M.PayloadSourceType.DEPENDENCY_REGISTRY
                || source.registry.code.length == 0 || source.registry.codehash != source.codeHash
                || source.version == 0 || source.dependencyId == 0
        ) revert B.InvalidScriptBundle(0);
        uint256 count = abi.decode(
            _registryRead(
                source,
                abi.encodeWithSignature(
                    "getDependencyScriptCountAtVersion(bytes32,uint256)",
                    source.dependencyId,
                    source.version
                ),
                32
            ),
            (uint256)
        );
        if (
            count == 0 || count > 32 || count != p.chunkHashes.length
                || count != p.chunkLengths.length
        ) {
            revert B.InvalidScriptBundle(0);
        }
        bytes32[] memory typedHashes = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            typedHashes[i] = keccak256(
                abi.encode(
                    keccak256(
                        "6529StreamDependencyScriptChunk(uint256 index,bytes32 chunkHash,uint256 byteLength)"
                    ),
                    i,
                    p.chunkHashes[i],
                    uint256(p.chunkLengths[i])
                )
            );
            if (
                abi.decode(
                        _registryRead(
                            source,
                            abi.encodeWithSignature(
                                "getDependencyScriptChunkHashAtVersion(bytes32,uint256,uint256)",
                                source.dependencyId,
                                source.version,
                                i
                            ),
                            32
                        ),
                        (bytes32)
                    ) != typedHashes[i]
            ) revert B.InvalidScriptBundle(0);
        }
        bytes32 sequence;
        for (uint256 i; i < count; ++i) {
            sequence = keccak256(abi.encode(sequence, typedHashes[i]));
        }
        bytes32 content = keccak256(
            abi.encode(
                keccak256(
                    "6529StreamDependencyScript(bytes32 dependencyNameAndVersion,uint256 chunkCount,bytes32 chunksHash)"
                ),
                source.dependencyId,
                count,
                sequence
            )
        );
        if (
            content != source.contentHash
                || abi.decode(
                        _registryRead(
                            source,
                            abi.encodeWithSignature(
                                "getDependencyScriptContentHashAtVersion(bytes32,uint256)",
                                source.dependencyId,
                                source.version
                            ),
                            32
                        ),
                        (bytes32)
                    ) != content
        ) revert B.InvalidScriptBundle(0);
        id = _begin(s, p, keccak256(abi.encode(source)));
        s.registrySources[id] = source;
    }

    function registry(State storage s, bytes32 id) public view returns (B.RegistrySource memory) {
        facts(s, id);
        return s.registrySources[id];
    }

    function dependencyManifest(State storage s, bytes32 id)
        public
        view
        returns (M.DependencyManifest memory m)
    {
        B.Facts memory f = facts(s, id);
        if (!f.finalized || !f.libraryOnly) revert B.InvalidScriptBundle(id);
        B.RegistrySource memory source = s.registrySources[id];
        m.dependencyId = id;
        m.dependencyHash = f.payloadHash;
        m.sourceType = f.sourceType;
        m.sourcePointer = Strings.toHexString(uint256(id), 32);
        m.mimeType = "application/javascript";
        if (source.registry != address(0)) {
            m.version = Strings.toString(source.version);
            m.useDependencyRegistry = true;
        }
    }

    function dependency(State storage s, bytes32 id, uint256 index)
        public
        view
        returns (bytes memory)
    {
        B.Facts memory f = facts(s, id);
        if (!f.finalized || !f.libraryOnly) revert B.InvalidScriptBundle(id);
        return chunk(s, id, index);
    }

    function _registryRead(B.RegistrySource memory source, bytes memory data, uint256 max)
        private
        view
        returns (bytes memory raw)
    {
        if (source.registry.codehash != source.codeHash || source.registry.code.length == 0) {
            revert B.InvalidScriptBundle(0);
        }
        bool ok;
        uint256 size;
        address target = source.registry;
        uint256 cap = BundleGasHost(address(this))
            .gasParameter(keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS"));
        if (gasleft() <= cap + cap / 63 + 100000) revert B.InvalidScriptBundle(0);
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 0)
            size := returndatasize()
        }
        if (!ok || size > max || size < 32) revert B.InvalidScriptBundle(0);
        raw = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(raw, 32), 0, size) }
    }

    function append(State storage s, bytes32 id, uint256 index, bytes memory payload) public {
        Bundle storage b = s.bundles[id];
        if (index >= b.chunks.length) revert B.InvalidScriptBundle(id);
        Chunk storage c = b.chunks[index];
        if (payload.length != c.length || keccak256(payload) != c.hash) {
            revert B.InvalidScriptBundle(id);
        }
        if (index < b.nextChunk) {
            chunk(s, id, index);
            return;
        }
        if (b.facts.finalized || index != b.nextChunk) revert B.InvalidScriptBundle(id);
        _utf8(b, payload, id);
        ++b.nextChunk;
        if (b.facts.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY) {
            // Pin reads to the originally authenticated version; no latest-version lookup.
            if (keccak256(chunk(s, id, index)) != c.hash) revert B.InvalidScriptBundle(id);
            emit ScriptBundleChunkStored(1, id, index, c.hash, address(0), address(0));
            return;
        }
        if (payload.length <= 24575) {
            c.first = SSTORE2.write(payload);
        } else {
            bytes memory first = new bytes(24575);
            _copy(payload, first, 0, 24575);
            c.first = SSTORE2.write(first);
            bytes memory tail = new bytes(1);
            tail[0] = payload[24575];
            c.tail = SSTORE2.write(tail);
        }
        emit ScriptBundleChunkStored(1, id, index, c.hash, c.first, c.tail);
    }

    function finish(State storage s, bytes32 id) public {
        B.Facts memory f = facts(s, id);
        Bundle storage b = s.bundles[id];
        if (b.nextChunk != f.chunkCount || b.utf8Remaining != 0) revert B.InvalidScriptBundle(id);
        bytes memory payload = assembled(s, id);
        if (keccak256(payload) != f.payloadHash) revert B.InvalidScriptBundle(id);
        if (f.finalized) return;
        s.bundles[id].facts.finalized = true;
        emit ScriptBundleFinalized(1, id, f.payloadHash);
    }

    /// @dev Streaming canonical UTF-8, including a code point crossing logical chunk boundaries.
    /// Validation work is bounded per append; finalize only reconstructs and hashes once.
    function _utf8(Bundle storage b, bytes memory raw, bytes32 id) private {
        uint8 remaining = b.utf8Remaining;
        uint8 lo = b.utf8Min;
        uint8 hi = b.utf8Max;
        for (uint256 i; i < raw.length; ++i) {
            uint8 c = uint8(raw[i]);
            if (remaining != 0) {
                if (c < lo || c > hi) revert B.InvalidScriptBundle(id);
                --remaining;
                lo = 0x80;
                hi = 0xbf;
                continue;
            }
            if (c < 0x80) continue;
            lo = 0x80;
            hi = 0xbf;
            if (c >= 0xc2 && c <= 0xdf) {
                remaining = 1;
            } else if (c >= 0xe0 && c <= 0xef) {
                remaining = 2;
                if (c == 0xe0) lo = 0xa0;
                else if (c == 0xed) hi = 0x9f;
            } else if (c >= 0xf0 && c <= 0xf4) {
                remaining = 3;
                if (c == 0xf0) lo = 0x90;
                else if (c == 0xf4) hi = 0x8f;
            } else {
                revert B.InvalidScriptBundle(id);
            }
        }
        b.utf8Remaining = remaining;
        b.utf8Min = lo;
        b.utf8Max = hi;
    }

    function facts(State storage s, bytes32 id) public view returns (B.Facts memory f) {
        f = s.bundles[id].facts;
        if (f.chunkCount == 0) revert B.InvalidScriptBundle(id);
    }

    function chunk(State storage s, bytes32 id, uint256 index)
        public
        view
        returns (bytes memory payload)
    {
        Bundle storage b = s.bundles[id];
        if (index >= b.chunks.length) revert B.InvalidScriptBundle(id);
        Chunk storage c = b.chunks[index];
        if (b.facts.sourceType == M.PayloadSourceType.DEPENDENCY_REGISTRY) {
            B.RegistrySource memory source = s.registrySources[id];
            bytes memory raw = _registryRead(
                source,
                abi.encodeWithSignature(
                    "getDependencyScriptAtVersion(bytes32,uint256,uint256)",
                    source.dependencyId,
                    source.version,
                    index
                ),
                8256
            );
            string memory text = abi.decode(raw, (string));
            payload = bytes(text);
            if (
                keccak256(raw) != keccak256(abi.encode(text)) || payload.length != c.length
                    || keccak256(payload) != c.hash
            ) revert B.InvalidScriptBundle(id);
            return payload;
        }
        if (
            c.first.code.length != (c.length > 24575 ? 24576 : uint256(c.length) + 1)
                || (c.length > 24575 ? c.tail.code.length != 2 : c.tail != address(0))
        ) revert B.InvalidScriptBundle(id);
        payload = SSTORE2.read(c.first);
        if (c.tail != address(0)) payload = bytes.concat(payload, SSTORE2.read(c.tail));
        if (payload.length != c.length || keccak256(payload) != c.hash) {
            revert B.InvalidScriptBundle(id);
        }
    }

    function page(State storage s, bytes32 id, uint256 start, uint256 count)
        public
        view
        returns (bytes[] memory result)
    {
        uint256 total = facts(s, id).chunkCount;
        // At most four logical chunks per page; callers can reconstruct all 32 in bounded reads.
        if (count > 4 || start > total || count > total - start) revert B.InvalidScriptBundle(id);
        result = new bytes[](count);
        for (uint256 i; i < count; ++i) {
            result[i] = chunk(s, id, start + i);
        }
    }

    function assembled(State storage s, bytes32 id) public view returns (bytes memory payload) {
        B.Facts memory f = facts(s, id);
        payload = new bytes(f.totalBytes);
        uint256 offset;
        for (uint256 i; i < f.chunkCount; ++i) {
            bytes memory part = chunk(s, id, i);
            _copy(part, payload, offset, part.length);
            offset += part.length;
        }
    }

    function _copy(bytes memory src, bytes memory dst, uint256 offset, uint256 length)
        private
        pure
    {
        // Byte tail avoids clobbering a following part or writing past the allocated buffer.
        uint256 n = length & ~uint256(31);
        assembly ("memory-safe") {
            let out := add(add(dst, 32), offset)
            let input := add(src, 32)
            for { let i := 0 } lt(i, n) { i := add(i, 32) } {
                mstore(add(out, i), mload(add(input, i)))
            }
        }
        for (uint256 i = n; i < length; ++i) {
            dst[offset + i] = src[i];
        }
    }

    function pointer(string memory text) public pure returns (bytes32 id) {
        bytes memory raw = bytes(text);
        if (raw.length != 66 || raw[0] != "0" || raw[1] != "x") revert B.InvalidScriptBundle(0);
        uint256 value;
        for (uint256 i = 2; i < 66; ++i) {
            uint8 c = uint8(raw[i]);
            uint8 v;
            if (c >= 48 && c <= 57) v = c - 48;
            else if (c >= 97 && c <= 102) v = c - 87;
            else revert B.InvalidScriptBundle(0);
            value = (value << 4) | v;
        }
        id = bytes32(value);
    }

    function manifest(
        State storage s,
        address core,
        address router,
        uint256 collectionId,
        M.ScriptManifest memory m
    ) public view returns (bytes32 hash, bytes32 id) {
        id = pointer(m.sourcePointer);
        B.Facts memory f = facts(s, id);
        if (
            !f.finalized || f.libraryOnly || !m.executable || m.rendererCompatibility != PROFILE
                || m.scriptHash != f.payloadHash || m.chunkCount != f.chunkCount
                || m.sourceType != f.sourceType
                || keccak256(bytes(m.mimeType)) != keccak256("application/javascript")
        ) revert B.InvalidScriptBundle(id);
        StreamMetadataRenderer.requireValidUtf8ContentUri("scriptURI", m.scriptURI, 2048, true);
        StreamMetadataRenderer.requireValidUtf8ContentUri("libraryURI", m.libraryURI, 2048, true);
        if (f.libraryBundle == 0 && bytes(m.libraryURI).length != 0) {
            revert B.InvalidScriptBundle(id);
        }
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CHUNKED_SCRIPT_MANIFEST_V1"),
                block.chainid,
                core,
                address(this),
                router,
                router.codehash,
                collectionId,
                id,
                f,
                m
            )
        );
    }
}
