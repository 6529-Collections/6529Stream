// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScriptBundles as B
} from "../../interfaces/stream/metadata/IStreamScriptBundles.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import { StreamChunkedContentEvidence as E } from "../finality/StreamChunkedContentEvidence.sol";
import { StreamRecordJson as J } from "./StreamRecordJson.sol";
import { StreamSnapshotManifestJson as S } from "./StreamSnapshotManifestJson.sol";
import { Base64 } from "../../vendor/openzeppelin/Base64.sol";

/// @notice Complete ordered payload bytes from the authenticated immutable bundle owner.
/// @dev Base64 preserves logical chunk boundaries even when one UTF8 code point spans chunks.
library StreamChunkedSnapshotPayload {
    function json(E.Evidence memory e, uint256 cap)
        public
        view
        returns (string memory script, string memory libraryJSON)
    {
        bytes memory raw = E.dynamicRead(
            e.selection.host,
            abi.encodeWithSignature("recordedScriptManifest(bytes32)", e.selection.manifestHash),
            8192,
            cap
        );
        M.ScriptManifest memory m = abi.decode(raw, (M.ScriptManifest));
        if (keccak256(raw) != keccak256(abi.encode(m))) {
            revert E.InvalidChunkedEvidence(e.selection.host);
        }
        script = string.concat(
            '{"bundleId":',
            S._hash(e.selection.bundleId),
            ',"byteLength":',
            J.unsigned(e.script.totalBytes),
            ',"chunkCount":',
            J.unsigned(e.script.chunkCount),
            ',"chunks":',
            _chunks(e.selection.host, e.selection.bundleId, e.script, cap),
            ',"contentHash":',
            S._hash(e.script.payloadHash),
            ',"libraryBundle":',
            S._hash(e.script.libraryBundle)
        );
        script = string.concat(
            script,
            ',"manifest":',
            _manifest(m),
            ',"manifestHash":',
            S._hash(e.selection.manifestHash),
            ',"sourceType":',
            J.unsigned(uint8(e.script.sourceType)),
            "}"
        );
        libraryJSON = "null";
        if (e.script.libraryBundle != 0) {
            libraryJSON = string.concat(
                '{"bundleId":',
                S._hash(e.script.libraryBundle),
                ',"byteLength":',
                J.unsigned(e.libraryFacts.totalBytes),
                ',"chunkCount":',
                J.unsigned(e.libraryFacts.chunkCount),
                ',"chunks":',
                _chunks(e.selection.host, e.script.libraryBundle, e.libraryFacts, cap),
                ',"contentHash":',
                S._hash(e.libraryFacts.payloadHash),
                ',"registry":',
                _registry(e.registry),
                ',"sourceType":',
                J.unsigned(uint8(e.libraryFacts.sourceType)),
                "}"
            );
        }
    }

    function _chunks(address host, bytes32 id, B.Facts memory f, uint256 cap)
        private
        view
        returns (string memory out)
    {
        if (
            !f.finalized || f.totalBytes == 0 || f.totalBytes > 786432 || f.chunkCount == 0
                || f.chunkCount > 32
        ) revert B.InvalidScriptBundle(id);
        bytes memory whole = new bytes(f.totalBytes);
        uint256 offset;
        out = "[";
        for (uint256 i; i < f.chunkCount; ++i) {
            bytes memory raw =
                E.dynamicRead(host, abi.encodeCall(B.scriptBundleChunk, (id, i)), 24640, cap);
            bytes memory part = abi.decode(raw, (bytes));
            if (
                keccak256(raw) != keccak256(abi.encode(part)) || part.length == 0
                    || part.length > 24576 || part.length > whole.length - offset
            ) revert B.InvalidScriptBundle(id);
            _copy(part, whole, offset);
            offset += part.length;
            out = string.concat(
                out,
                i == 0 ? "" : ",",
                '{"byteLength":',
                J.unsigned(part.length),
                ',"contentBase64":"',
                Base64.encode(part),
                '","contentHash":',
                S._hash(keccak256(part)),
                ',"index":',
                J.unsigned(i),
                "}"
            );
        }
        if (offset != whole.length || keccak256(whole) != f.payloadHash) {
            revert B.InvalidScriptBundle(id);
        }
        return string.concat(out, "]");
    }

    function _copy(bytes memory src, bytes memory dst, uint256 offset) private pure {
        uint256 n = src.length & ~uint256(31);
        assembly ("memory-safe") {
            let a := add(src, 32)
            let b := add(add(dst, 32), offset)
            for { let i := 0 } lt(i, n) { i := add(i, 32) } { mstore(add(b, i), mload(add(a, i))) }
        }
        for (uint256 i = n; i < src.length; ++i) {
            dst[offset + i] = src[i];
        }
    }

    function _manifest(M.ScriptManifest memory m) private pure returns (string memory out) {
        out = string.concat(
            '{"chunkCount":',
            J.unsigned(m.chunkCount),
            ',"executable":',
            m.executable ? "true" : "false",
            ',"libraryURI":',
            J.quote(m.libraryURI, 2048, true),
            ',"mimeType":',
            J.quote(m.mimeType, 128, false),
            ',"rendererCompatibility":',
            S._hash(m.rendererCompatibility)
        );
        return string.concat(
            out,
            ',"scriptHash":',
            S._hash(m.scriptHash),
            ',"scriptURI":',
            J.quote(m.scriptURI, 2048, true),
            ',"sourcePointer":',
            J.quote(m.sourcePointer, 66, false),
            ',"sourceType":',
            J.unsigned(uint8(m.sourceType)),
            "}"
        );
    }

    function _registry(B.RegistrySource memory r) private pure returns (string memory) {
        if (r.registry == address(0)) return "null";
        return string.concat(
            '{"address":',
            S._account(r.registry),
            ',"contentHash":',
            S._hash(r.contentHash),
            ',"dependencyId":',
            S._hash(r.dependencyId),
            ',"runtimeHash":',
            S._hash(r.codeHash),
            ',"version":',
            J.unsigned(r.version),
            "}"
        );
    }
}
