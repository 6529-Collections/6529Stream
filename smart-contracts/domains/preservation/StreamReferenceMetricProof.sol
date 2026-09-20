// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceMetricTypes as T
} from "../../interfaces/stream/preservation/StreamReferenceMetricTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import { StreamRecordJson as J } from "../records/StreamRecordJson.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";

/// @notice Exact source-byte, original package and replay-input joins for the closed metric profile.
/// @dev This validates the recorded execution claim and its bytes, not execution of Python by EVM.
library StreamReferenceMetricProof {
    /// @dev Closed internal transport of every field used by this proof. The original full
    /// Publication/Evidence and their context have already passed same-call source admission.
    struct EvidenceInput {
        M.Mode mode;
        bytes32 implementationHash;
        bytes32 parametersHash;
        bytes32 reportHash;
        int64 threshold;
        uint64 evaluatedAt;
        bytes32 context;
        bytes32 environmentObjectHash;
        bytes32 environmentManifestHash;
        uint16 viewportWidth;
        uint16 viewportHeight;
        uint8 devicePixelRatio;
        R.PackageFile[] packageFiles;
        bytes32[2][] repeatCaptureSha256;
    }

    function project(R.Publication memory p, M.Evidence memory e, bytes32 context)
        internal
        pure
        returns (EvidenceInput memory input)
    {
        input.mode = e.mode;
        input.implementationHash = e.perceptual.metric.implementationHash;
        input.parametersHash = e.perceptual.metric.parametersHash;
        input.reportHash = e.perceptual.reportHash;
        input.threshold = e.perceptual.threshold;
        input.evaluatedAt = e.perceptual.evaluatedAt;
        input.context = context;
        input.environmentObjectHash = p.environment.objectHash;
        input.environmentManifestHash = p.environment.manifestHash;
        input.viewportWidth = p.environment.viewportWidth;
        input.viewportHeight = p.environment.viewportHeight;
        input.devicePixelRatio = p.environment.devicePixelRatio;
        input.packageFiles = p.environment.packageFiles;
        input.repeatCaptureSha256 = new bytes32[2][](p.captures.length);
        for (uint256 i; i < p.captures.length; ++i) {
            input.repeatCaptureSha256[i] = p.captures[i].repeatCaptureSha256;
        }
    }

    function requireProjected(EvidenceInput memory input, T.Supplement memory s)
        public
        view
        returns (bytes32 runtimeHash, bytes32 replayHash)
    {
        R.Publication memory p;
        M.Evidence memory e;
        e.mode = input.mode;
        e.perceptual.metric.implementationHash = input.implementationHash;
        e.perceptual.metric.parametersHash = input.parametersHash;
        e.perceptual.reportHash = input.reportHash;
        e.perceptual.threshold = input.threshold;
        e.perceptual.evaluatedAt = input.evaluatedAt;
        p.environment.objectHash = input.environmentObjectHash;
        p.environment.manifestHash = input.environmentManifestHash;
        p.environment.viewportWidth = input.viewportWidth;
        p.environment.viewportHeight = input.viewportHeight;
        p.environment.devicePixelRatio = input.devicePixelRatio;
        p.environment.packageFiles = input.packageFiles;
        p.captures = new R.Capture[](input.repeatCaptureSha256.length);
        for (uint256 i; i < p.captures.length; ++i) {
            p.captures[i].repeatCaptureSha256 = input.repeatCaptureSha256[i];
        }
        // Internal call to the byte-identical original complete-input proof below. No
        // source admission is inferred by this stateless projection entry itself.
        return requireEvidence(p, e, input.context, s);
    }

    function requireEvidence(
        R.Publication memory p,
        M.Evidence memory e,
        bytes32 context,
        T.Supplement memory s
    ) public view returns (bytes32 runtimeHash, bytes32 replayHash) {
        if (e.mode != M.Mode.PERCEPTUAL_TOLERANCE) {
            revert T.InvalidMetricSupplement();
        }
        bytes memory index = implementationIndex(s.sources);
        if (
            keccak256(index) != e.perceptual.metric.implementationHash
                || keccak256(index) != keccak256(s.implementationIndex) || s.parameters.length == 0
                || s.parameters.length > 65536
                || keccak256(s.parameters) != e.perceptual.metric.parametersHash
        ) {
            revert T.InvalidMetricSupplement();
        }
        runtimeHash = _runtime(p.environment, s);
        T.Replay memory r = s.replay;
        bytes memory input = inputManifest(p, e.perceptual, context);
        if (
            r.runtimeHash != runtimeHash || r.contextHash != context
                || r.reportHash != e.perceptual.reportHash || r.exitCode != 0
                || r.executedAt < e.perceptual.evaluatedAt || r.executedAt > block.timestamp
                || r.transcript.length == 0 || r.transcript.length > 65536
                || r.inputManifest.length > 65536 || r.inputsHash != keccak256(input)
                || keccak256(r.inputManifest) != r.inputsHash
        ) revert T.InvalidMetricSupplement();
        _transcript(r);
        replayHash = keccak256(abi.encode(keccak256("6529STREAM_METRIC_REPLAY_V1"), r));
    }

    function _transcript(T.Replay memory r) private pure {
        (
            bytes32 domain,
            bytes32 runtime,
            bytes32 context,
            bytes32 report,
            bytes32 inputs,
            uint64 executedAt,
            uint32 exitCode,
            bytes memory diagnostic
        ) = abi.decode(
            r.transcript, (bytes32, bytes32, bytes32, bytes32, bytes32, uint64, uint32, bytes)
        );
        if (
            domain != keccak256("6529STREAM_METRIC_TRANSCRIPT_V1") || runtime != r.runtimeHash
                || context != r.contextHash || report != r.reportHash || inputs != r.inputsHash
                || executedAt != r.executedAt || exitCode != r.exitCode || diagnostic.length == 0
                || keccak256(r.transcript)
                    != keccak256(
                        abi.encode(
                            domain,
                            runtime,
                            context,
                            report,
                            inputs,
                            executedAt,
                            exitCode,
                            diagnostic
                        )
                    )
        ) revert T.InvalidMetricSupplement();
        // Diagnostic JSON carries the independently verified actual-run observations.
        // Matching this envelope establishes attribution/binding, not execution by EVM.
    }

    function implementationIndex(T.SourceFile[4] memory sources)
        public
        pure
        returns (bytes memory)
    {
        bytes memory out = bytes("{");
        for (uint256 i; i < 4; ++i) {
            string memory expected = sourcePath(i);
            if (
                keccak256(bytes(sources[i].path)) != keccak256(bytes(expected))
                    || sources[i].content.length == 0 || sources[i].content.length > 131072
            ) {
                revert T.InvalidMetricSupplement();
            }
            out = abi.encodePacked(
                out, i == 0 ? "" : ",", '"', expected, '":"', _hex(sha256(sources[i].content)), '"'
            );
        }
        return abi.encodePacked(out, "}");
    }

    function sourcePath(uint256 i) public pure returns (string memory) {
        if (i == 0) return "tools/museum/canonical.py";
        if (i == 1) return "tools/museum/chain_abi.py";
        if (i == 2) return "tools/preservation/reference_manifest.py";
        if (i == 3) return "tools/preservation/reference_metric.py";
        revert T.InvalidMetricSupplement();
    }

    function inputManifest(R.Publication memory p, M.Perceptual memory m, bytes32 context)
        public
        pure
        returns (bytes memory)
    {
        if (
            p.captures.length == 0 || p.captures.length > 2 || p.environment.devicePixelRatio != 1
                || m.threshold < 0
        ) revert T.InvalidMetricSupplement();
        bytes memory out = bytes('{"captures":[');
        for (uint256 i; i < p.captures.length; ++i) {
            out = abi.encodePacked(
                out,
                i == 0 ? "" : ",",
                '{"firstSha256":',
                J.hexValue(p.captures[i].repeatCaptureSha256[0]),
                ',"height":',
                Strings.toString(p.environment.viewportHeight),
                ',"secondSha256":',
                J.hexValue(p.captures[i].repeatCaptureSha256[1]),
                ',"width":',
                Strings.toString(p.environment.viewportWidth),
                "}"
            );
        }
        return abi.encodePacked(
            out,
            '],"contextHash":',
            J.hexValue(context),
            ',"environmentHash":',
            J.hexValue(p.environment.manifestHash),
            ',"evaluatedAt":',
            Strings.toString(m.evaluatedAt),
            ',"threshold":',
            Strings.toString(uint64(m.threshold)),
            "}"
        );
    }

    function _runtime(R.Environment memory environment, T.Supplement memory s)
        private
        pure
        returns (bytes32)
    {
        T.Runtime memory r = s.runtime;
        if (
            r.environmentObjectHash != environment.objectHash
                || r.environmentManifestHash != environment.manifestHash
                || keccak256(bytes(r.entrypoint))
                    != keccak256("metric/source/tools/preservation/reference_metric.py")
                || keccak256(bytes(r.interpreter)) != keccak256("metric/python/python.exe")
                || keccak256(bytes(r.launcher)) != keccak256("metric/launch.py")
                || keccak256(bytes(r.sourceRoot)) != keccak256("metric/source")
                || r.argv.length != 4 || keccak256(bytes(r.argv[0])) != keccak256("-I")
                || keccak256(bytes(r.argv[1])) != keccak256("-S")
                || keccak256(bytes(r.argv[2])) != keccak256("-B")
                || keccak256(bytes(r.argv[3])) != keccak256("metric/launch.py")
                || r.members.length == 0 || r.members.length > 2048
        ) revert T.InvalidMetricSupplement();
        // Exact complete prefix inventory, derived from the same original environment package.
        // No caller-selected subset may silently omit a launcher, DLL, module, license or index.
        uint256 cursor;
        for (uint256 i; i < environment.packageFiles.length; ++i) {
            R.PackageFile memory row = environment.packageFiles[i];
            if (!_metric(bytes(row.path))) continue;
            if (cursor == r.members.length) revert T.InvalidMetricSupplement();
            R.PackageFile memory declared = r.members[cursor];
            // PackageFile has exactly these three fields. Compare the same complete row
            // without allocating two temporary ABI buffers for every archived member.
            if (
                row.byteSize != declared.byteSize || row.sha256Digest != declared.sha256Digest
                    || keccak256(bytes(row.path)) != keccak256(bytes(declared.path))
            ) revert T.InvalidMetricSupplement();
            if (cursor != 0 && !pathLess(bytes(r.members[cursor - 1].path), bytes(row.path))) {
                revert T.InvalidMetricSupplement();
            }
            ++cursor;
        }
        if (cursor != r.members.length) revert T.InvalidMetricSupplement();
        for (uint256 i; i < 4; ++i) {
            _member(
                r.members,
                string.concat("metric/source/", s.sources[i].path),
                uint64(s.sources[i].content.length),
                sha256(s.sources[i].content),
                true
            );
        }
        _member(
            r.members,
            "metric/implementation.json",
            uint64(s.implementationIndex.length),
            sha256(s.implementationIndex),
            true
        );
        _member(
            r.members,
            "metric/parameters.json",
            uint64(s.parameters.length),
            sha256(s.parameters),
            true
        );
        _member(r.members, r.interpreter, 0, 0, false);
        _member(r.members, r.launcher, 0, 0, false);
        return keccak256(abi.encode(keccak256("6529STREAM_METRIC_RUNTIME_V1"), r));
    }

    function _member(
        R.PackageFile[] memory rows,
        string memory path,
        uint64 length,
        bytes32 digest,
        bool exact
    ) private pure {
        bytes32 key = keccak256(bytes(path));
        for (uint256 i; i < rows.length; ++i) {
            if (keccak256(bytes(rows[i].path)) != key) continue;
            if (
                rows[i].byteSize == 0 || rows[i].sha256Digest == 0
                    || (exact && (rows[i].byteSize != length || rows[i].sha256Digest != digest))
            ) {
                revert T.InvalidMetricSupplement();
            }
            return;
        }
        revert T.InvalidMetricSupplement();
    }

    function _metric(bytes memory path) private pure returns (bool) {
        return path.length > 7 && path[0] == "m" && path[1] == "e" && path[2] == "t"
            && path[3] == "r" && path[4] == "i" && path[5] == "c" && path[6] == "/";
    }

    /// @dev Big-endian word comparison is lexicographic byte comparison. Mask the final
    /// partial word so ABI padding or adjacent memory cannot affect a shorter path.
    function pathLess(bytes memory a, bytes memory b) internal pure returns (bool) {
        uint256 length = a.length < b.length ? a.length : b.length;
        uint256 offset;
        while (length - offset >= 32) {
            uint256 x;
            uint256 y;
            assembly ("memory-safe") {
                x := mload(add(add(a, 32), offset))
                y := mload(add(add(b, 32), offset))
            }
            if (x != y) return x < y;
            offset += 32;
        }
        if (offset != length) {
            uint256 shift = (32 - (length - offset)) * 8;
            uint256 x;
            uint256 y;
            assembly ("memory-safe") {
                x := shr(shift, mload(add(add(a, 32), offset)))
                y := shr(shift, mload(add(add(b, 32), offset)))
            }
            if (x != y) return x < y;
        }
        return a.length < b.length;
    }

    function _hex(bytes32 value) private pure returns (bytes memory out) {
        out = new bytes(64);
        bytes memory alphabet = "0123456789abcdef";
        for (uint256 i; i < 32; ++i) {
            out[2 * i] = alphabet[uint8(value[i]) >> 4];
            out[2 * i + 1] = alphabet[uint8(value[i]) & 15];
        }
    }
}
