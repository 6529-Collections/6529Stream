// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import { StreamReferenceRenderSourceReads as Source } from "./StreamReferenceRenderSourceReads.sol";
import { StreamReferenceModeInput as Input } from "./StreamReferenceModeInput.sol";
import { StreamReferenceMetricProof as Proof } from "./StreamReferenceMetricProof.sol";

/// @notice Metric-only canonical interpretation of the host's complete immutable Publication.
/// @dev Every nested offset, scalar width and padding byte is checked. This is private transport;
/// it grants no source authority and does not replace any current Source or Mode proof.
library StreamReferenceMetricPublicationInput {
    struct Decoded {
        Source.SourceInput source;
        bytes32 referenceId;
        uint64 effectiveAt;
        bytes32 environmentManifestHash;
        uint16 viewportWidth;
        uint16 viewportHeight;
        uint8 devicePixelRatio;
        uint256 metricMemberCount;
        bytes32 metricMemberHash;
        uint256 capturesStart;
        uint256 environmentStart;
        uint256 manifestStart;
    }

    function read(bytes memory raw) internal pure returns (Decoded memory v) {
        uint256 limit = raw.length;
        if (limit == 0 || limit > 524288 || limit % 32 != 0 || _word(raw, 0, limit) != 32) {
            _invalid();
        }
        // Publication is twelve words; only slots7/8/9 are dynamic.
        if (limit < 416 || _word(raw, 256, limit) != 384) _invalid();
        _width(raw, 128, 64, limit);
        _width(raw, 192, 64, limit);
        _width(raw, 352, 64, limit);
        v.source.collectionId = _word(raw, 32, limit);
        v.referenceId = bytes32(_word(raw, 64, limit));
        v.source.snapshotRecordHash = bytes32(_word(raw, 160, limit));
        v.source.snapshotRevision = uint64(_word(raw, 192, limit));
        v.effectiveAt = uint64(_word(raw, 352, limit));
        v.capturesStart = 416;
        v.environmentStart = _offset(raw, 288, 32, limit);
        v.manifestStart = _offset(raw, 320, 32, limit);
        if (v.environmentStart < v.capturesStart || v.manifestStart < v.environmentStart) {
            _invalid();
        }
        uint256 captureBytes = v.environmentStart - v.capturesStart;
        bytes memory captures = new bytes(32 + captureBytes);
        assembly ("memory-safe") { mstore(add(captures, 32), 32) }
        _copy(raw, v.capturesStart, captures, 32, captureBytes);
        v.source.captures = abi.decode(captures, (R.Capture[]));
        // This also checks every Capture's dynamic tail, fixed fields and zero padding.
        if (keccak256(captures) != keccak256(abi.encode(v.source.captures))) _invalid();
        _environment(raw, v);
        if (_bytesEnd(raw, v.manifestStart, limit) != limit) _invalid();
    }

    function _environment(bytes memory raw, Decoded memory v) private pure {
        uint256 base = v.environmentStart;
        uint256 limit = v.manifestStart;
        if (base > limit || limit - base < 768) _invalid();
        v.source.environmentObjectHash = bytes32(_word(raw, base, limit));
        v.source.environmentCoverageHash = bytes32(_word(raw, base + 32, limit));
        v.environmentManifestHash = bytes32(_word(raw, base + 64, limit));
        _width(raw, base + 96, 32, limit);
        _width(raw, base + 544, 16, limit);
        _width(raw, base + 576, 16, limit);
        _width(raw, base + 608, 8, limit);
        _width(raw, base + 672, 1, limit);
        v.viewportWidth = uint16(_word(raw, base + 544, limit));
        v.viewportHeight = uint16(_word(raw, base + 576, limit));
        v.devicePixelRatio = uint8(_word(raw, base + 608, limit));
        uint256 cursor = base + 768;
        for (uint256 i; i < 24; ++i) {
            bool array = i == 12 || i == 13;
            bool text = i == 4 || i == 5 || i == 7 || i == 8 || i == 10 || i == 11 || i == 14
                || i == 15 || i == 16 || i == 20 || i == 23;
            if (!array && !text) continue;
            if (_offset(raw, base + i * 32, base, limit) != cursor) _invalid();
            if (array) {
                (uint256 end, uint256 count, bytes32 hash) = _files(raw, cursor, limit, i == 12);
                cursor = end;
                if (i == 12) {
                    v.metricMemberCount = count;
                    v.metricMemberHash = hash;
                }
            } else {
                cursor = _bytesEnd(raw, cursor, limit);
            }
        }
        if (cursor != limit) _invalid();
    }

    function _files(bytes memory raw, uint256 start, uint256 limit, bool fold)
        private
        pure
        returns (uint256 cursor, uint256 count, bytes32 hash)
    {
        uint256 n = _word(raw, start, limit);
        uint256 heads = start + 32;
        if (n > (limit - heads) / 32) _invalid();
        cursor = heads + n * 32;
        bytes32[4] memory frame;
        frame[0] = keccak256("6529STREAM_METRIC_COMPLETE_PREFIX_V1");
        bytes4 failure = M.InvalidModeEvidence.selector;
        // heads+n*32 is bounded above. Each iteration independently proves its complete
        // 96-byte row head, length word and padded path before reading/hash advancement.
        assembly ("memory-safe") {
            function reject(selector) {
                mstore(0, selector)
                revert(0, 4)
            }
            let data := add(raw, 32)
            let header := add(data, heads)
            let row := add(data, cursor)
            let end := add(data, limit)
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                if iszero(eq(mload(add(header, mul(i, 32))), sub(row, header))) { reject(failure) }
                if lt(sub(end, row), 128) { reject(failure) }
                if iszero(eq(mload(row), 96)) { reject(failure) }
                let size := mload(add(row, 32))
                if shr(64, size) { reject(failure) }
                let length := mload(add(row, 96))
                let path := add(row, 128)
                if gt(length, sub(end, path)) { reject(failure) }
                let padded := and(add(length, 31), not(31))
                if gt(padded, sub(end, path)) { reject(failure) }
                let remainder := and(length, 31)
                if remainder {
                    let mask := sub(shl(mul(sub(32, remainder), 8), 1), 1)
                    if and(mload(add(path, sub(length, remainder))), mask) {
                        reject(failure)
                    }
                }
                if and(fold, gt(length, 7)) {
                    if eq(shr(200, mload(path)), 0x6d65747269632f) {
                        mstore(add(frame, 32), keccak256(path, length))
                        mstore(add(frame, 64), size)
                        mstore(add(frame, 96), mload(add(row, 64)))
                        mstore(frame, keccak256(frame, 128))
                        count := add(count, 1)
                    }
                }
                row := add(path, padded)
            }
            cursor := sub(row, data)
        }
        hash = keccak256(abi.encode(frame[0], count));
    }

    /// @dev All inputs precede the temporary canonical encoding. Only its digest escapes;
    /// reclaim the dead bytes before subsequent current-source and mode reads allocate.
    function evidenceHash(M.Evidence memory evidence) internal pure returns (bytes32 result) {
        uint256 scratch;
        assembly ("memory-safe") { scratch := mload(0x40) }
        bytes memory encoded = abi.encode(evidence);
        assembly ("memory-safe") {
            result := keccak256(add(encoded, 32), mload(encoded))
            mstore(0x40, scratch)
        }
    }

    /// @dev Preserve the complete original preimage builder as the byte oracle. Its head
    /// and output are temporary here; raw, decoded and dependencies remain live below scratch.
    function contextHash(R.Dependencies memory d, bytes memory raw, Decoded memory v)
        internal
        view
        returns (bytes32 result)
    {
        uint256 scratch;
        assembly ("memory-safe") { scratch := mload(0x40) }
        bytes memory encoded = contextPreimage(d, raw, v);
        assembly ("memory-safe") {
            result := keccak256(add(encoded, 32), mload(encoded))
            mstore(0x40, scratch)
        }
    }

    function contextPreimage(R.Dependencies memory d, bytes memory raw, Decoded memory v)
        internal
        view
        returns (bytes memory out)
    {
        uint256 capturesLength = v.environmentStart - v.capturesStart;
        uint256 environmentLength = v.manifestStart - v.environmentStart;
        bytes memory head = abi.encode(
            keccak256("6529STREAM_REFERENCE_MODE_CONTEXT_V1"),
            d.chainId,
            address(this),
            d.targets,
            d.codeHashes,
            v.source.collectionId,
            v.referenceId,
            v.source.snapshotRecordHash,
            v.source.snapshotRevision,
            uint256(736),
            uint256(736 + capturesLength)
        );
        assert(head.length == 736);
        out = new bytes(736 + capturesLength + environmentLength);
        _copy(head, 0, out, 0, 736);
        _copy(raw, v.capturesStart, out, 736, capturesLength);
        _copy(raw, v.environmentStart, out, 736 + capturesLength, environmentLength);
    }

    function evidenceInput(Decoded memory v, bytes32 context)
        internal
        pure
        returns (Input.EvidenceInput memory p)
    {
        p.collectionId = v.source.collectionId;
        p.effectiveAt = v.effectiveAt;
        p.contextHash = context;
        p.captures = new Input.Capture[](v.source.captures.length);
        for (uint256 i; i < p.captures.length; ++i) {
            p.captures[i] = Input.Capture(
                v.source.captures[i].repeatCaptureSha256[1], v.source.captures[i].capturedAt
            );
        }
    }

    function compact(Decoded memory v, M.Evidence memory e, bytes32 context)
        internal
        pure
        returns (Proof.CompactInput memory p)
    {
        p.mode = e.mode;
        p.implementationHash = e.perceptual.metric.implementationHash;
        p.parametersHash = e.perceptual.metric.parametersHash;
        p.reportHash = e.perceptual.reportHash;
        p.threshold = e.perceptual.threshold;
        p.evaluatedAt = e.perceptual.evaluatedAt;
        p.context = context;
        p.environmentObjectHash = v.source.environmentObjectHash;
        p.environmentManifestHash = v.environmentManifestHash;
        p.viewportWidth = v.viewportWidth;
        p.viewportHeight = v.viewportHeight;
        p.devicePixelRatio = v.devicePixelRatio;
        p.metricMemberCount = v.metricMemberCount;
        p.metricMemberHash = v.metricMemberHash;
        p.captureCount = v.source.captures.length;
        for (uint256 i; i < p.captureCount && i < 2; ++i) {
            p.repeatCaptureSha256[i] = v.source.captures[i].repeatCaptureSha256;
        }
    }

    function _bytesEnd(bytes memory raw, uint256 start, uint256 limit)
        private
        pure
        returns (uint256 end)
    {
        uint256 length = _word(raw, start, limit);
        uint256 data = start + 32;
        if (length > limit - data) _invalid();
        uint256 padded = (length + 31) / 32 * 32;
        if (padded > limit - data) _invalid();
        end = data + padded;
        uint256 remainder = length % 32;
        if (remainder != 0) {
            uint256 word = _word(raw, data + length - remainder, limit);
            uint256 mask = (uint256(1) << ((32 - remainder) * 8)) - 1;
            if (word & mask != 0) _invalid();
        }
    }

    function _offset(bytes memory raw, uint256 at, uint256 base, uint256 limit)
        private
        pure
        returns (uint256 result)
    {
        uint256 offset = _word(raw, at, limit);
        if (base > limit || offset > limit - base || offset % 32 != 0) _invalid();
        return base + offset;
    }

    function _width(bytes memory raw, uint256 at, uint256 bits, uint256 limit) private pure {
        if (_word(raw, at, limit) >> bits != 0) _invalid();
    }

    function _word(bytes memory raw, uint256 at, uint256 limit)
        private
        pure
        returns (uint256 value)
    {
        if (limit > raw.length || at > limit || limit - at < 32) _invalid();
        assembly ("memory-safe") { value := mload(add(add(raw, 32), at)) }
    }

    function _copy(bytes memory from, uint256 start, bytes memory to, uint256 dest, uint256 size)
        private
        pure
    {
        if (
            start > from.length || size > from.length - start || dest > to.length
                || size > to.length - dest || size % 32 != 0
        ) _invalid();
        assembly ("memory-safe") {
            let src := add(add(from, 32), start)
            let target := add(add(to, 32), dest)
            for { let i := 0 } lt(i, size) { i := add(i, 32) } {
                mstore(add(target, i), mload(add(src, i)))
            }
        }
    }

    function _invalid() private pure {
        revert M.InvalidModeEvidence();
    }
}
