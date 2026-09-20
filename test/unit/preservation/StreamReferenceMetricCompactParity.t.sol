// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { CompactMetricProbe, CompactVm } from "./StreamReferenceMetricCompact.t.sol";
import {
    StreamReferenceMetricProof as Proof
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricProof.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceMetricTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceMetricTypes.sol";
import {
    StreamWorkRecordContext as Definitions
} from "../../../smart-contracts/domains/records/StreamWorkRecordContext.sol";

/// @notice Differential proof/canonical transport vectors against the unchanged full proof.
/// @dev One case uses the retained complete corpus. Other cases deliberately rebuild a small
/// synthetic package and runtime together so prefix equality cannot mask member-lookup defects.
/// Schema definitions/context/report are typed boundaries. No archive, Python execution,
/// current source, writer authority or transaction-cap acceptance is inferred from these tests.
contract StreamReferenceMetricCompactParityTest {
    CompactVm private constant vm =
        CompactVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    CompactMetricProbe private probe;

    struct Fixture {
        R.Publication publication;
        M.Evidence evidence;
        T.Supplement supplement;
        bytes32 context;
    }

    function setUp() external {
        probe = new CompactMetricProbe();
        vm.warp(2000000000);
        vm.mockCall(
            address(Definitions),
            abi.encodeWithSelector(Definitions.definition.selector),
            abi.encode(bytes("registered definition boundary"))
        );
    }

    function testCompactLookupRetainedCorpusRuntimeReplayAndCanonicalParity() external view {
        Fixture memory f;
        f.supplement = abi.decode(
            vm.readFileBinary("test/fixtures/preservation/reference-metric-replay-v1.abi"),
            (T.Supplement)
        );
        string memory corpus =
            vm.readFile("test/fixtures/preservation/reference-combined-native-v1.json");
        f.publication.environment.packageFiles =
            abi.decode(vm.parseJsonBytes(corpus, ".packageFilesABI"), (R.PackageFile[]));
        f.publication.environment.platformPrerequisites =
            abi.decode(vm.parseJsonBytes(corpus, ".platformPrerequisitesABI"), (R.PackageFile[]));
        require(
            f.publication.environment.packageFiles.length == 1048
                && f.publication.environment.platformPrerequisites.length == 102,
            "exact retained complete corpus"
        );
        _inputs(f);
        _refresh(f);
        _accepted(f);
        (uint256 count,) = probe.prefix(f.publication.environment.packageFiles);
        require(count == 684, "all retained metric members");
    }

    function testCompactLookupAllSixExactTargetsRejectPairedWrongSizes() external view {
        _accepted(_small());
        for (uint256 i; i < 6; ++i) {
            Fixture memory f = _small();
            string memory target = _exactTarget(f, i);
            uint256 at = _index(f.supplement.runtime.members, target);
            R.PackageFile memory row = f.supplement.runtime.members[at];
            _pairedChange(f, target, row.byteSize + 1, row.sha256Digest);
            _refresh(f);
            _rejected(f);
        }
    }

    function testCompactLookupAllSixExactTargetsRejectPairedWrongDigests() external view {
        _accepted(_small());
        for (uint256 i; i < 6; ++i) {
            Fixture memory f = _small();
            string memory target = _exactTarget(f, i);
            uint256 at = _index(f.supplement.runtime.members, target);
            R.PackageFile memory row = f.supplement.runtime.members[at];
            bytes32 changed = row.sha256Digest ^ bytes32(uint256(1));
            require(changed != 0 && changed != row.sha256Digest);
            _pairedChange(f, target, row.byteSize, changed);
            _refresh(f);
            _rejected(f);
        }
    }

    function testCompactLookupInterpreterAndLauncherRequireBothNonzeroFields() external view {
        _accepted(_small());
        for (uint256 i; i < 2; ++i) {
            for (uint256 field; field < 2; ++field) {
                Fixture memory f = _small();
                string memory target =
                    i == 0 ? f.supplement.runtime.interpreter : f.supplement.runtime.launcher;
                R.PackageFile memory row =
                    f.supplement.runtime.members[_index(f.supplement.runtime.members, target)];
                _pairedChange(
                    f,
                    target,
                    field == 0 ? 0 : row.byteSize,
                    field == 1 ? bytes32(0) : row.sha256Digest
                );
                _refresh(f);
                _rejected(f);
            }
        }
    }

    function testCompactLookupChangedNonzeroExecutablesRetainOriginalMeaning() external view {
        for (uint256 i; i < 2; ++i) {
            Fixture memory f = _small();
            (bytes32 oldRuntime, bytes32 oldReplay) = _accepted(f);
            string memory target =
                i == 0 ? f.supplement.runtime.interpreter : f.supplement.runtime.launcher;
            _pairedChange(
                f,
                target,
                999 + uint64(i),
                keccak256(abi.encode("other nonzero executable fact", i))
            );
            _refresh(f);
            (bytes32 runtime, bytes32 replay) = _accepted(f);
            require(
                runtime != oldRuntime && replay != oldReplay,
                "rebound exact runtime/replay, not stale acceptance"
            );
        }
    }

    function testCompactLookupEveryRequiredMissingTargetAfterPrefixRebuildRefuses() external view {
        _accepted(_small());
        for (uint256 i; i < 8; ++i) {
            Fixture memory f = _small();
            string memory target = i < 6
                ? _exactTarget(f, i)
                : i == 6 ? f.supplement.runtime.interpreter : f.supplement.runtime.launcher;
            f.supplement.runtime.members = _without(f.supplement.runtime.members, target);
            f.publication.environment.packageFiles =
                _without(f.publication.environment.packageFiles, target);
            require(
                f.supplement.runtime.members.length == 7
                    && f.publication.environment.packageFiles.length == 7,
                "same complete missing-target prefix"
            );
            _refresh(f);
            _rejected(f);
        }
    }

    function testCompactLookupHeadMiddleTailAndWordBoundaryNeighbors() external view {
        Fixture memory f = _small();
        require(
            _index(f.supplement.runtime.members, "metric/implementation.json") == 0, "head target"
        );
        require(
            _index(f.supplement.runtime.members, "metric/source/tools/museum/canonical.py") == 4,
            "middle target"
        );
        require(
            _index(f.supplement.runtime.members, f.supplement.runtime.entrypoint) == 7,
            "tail target"
        );
        _accepted(f);
        uint256[5] memory widths = [uint256(31), 32, 33, 63, 64];
        R.PackageFile[] memory expanded = new R.PackageFile[](18);
        for (uint256 i; i < 8; ++i) {
            expanded[i] = f.supplement.runtime.members[i];
        }
        for (uint256 i; i < widths.length; ++i) {
            expanded[8 + i * 2] = R.PackageFile(
                _edge(widths[i], bytes1("b")), uint64(i + 1), keccak256(abi.encode("left", i))
            );
            expanded[9 + i * 2] = R.PackageFile(
                _edge(widths[i], bytes1("z")), uint64(i + 9), keccak256(abi.encode("right", i))
            );
        }
        _sort(expanded);
        f.supplement.runtime.members = expanded;
        f.publication.environment.packageFiles = abi.decode(abi.encode(expanded), (R.PackageFile[]));
        _refresh(f);
        _accepted(f);
        // The tail target is now an exact prefix of several longer rows. A lower-bound
        // candidate with equal prefix but wrong length must never replace that target.
        f.supplement.runtime.members = _without(expanded, f.supplement.runtime.entrypoint);
        f.publication.environment.packageFiles =
            _without(f.publication.environment.packageFiles, f.supplement.runtime.entrypoint);
        _refresh(f);
        _rejected(f);
    }

    function testCompactLookupStrictOrderingAndDuplicateRowsStillRefuse() external view {
        _accepted(_small());
        for (uint256 i; i < 2; ++i) {
            Fixture memory f = _small();
            R.PackageFile[] memory rows = f.supplement.runtime.members;
            if (i == 0) {
                rows[4] = rows[3];
            } else {
                R.PackageFile memory original =
                    R.PackageFile(rows[0].path, rows[0].byteSize, rows[0].sha256Digest);
                rows[0] = rows[7];
                rows[7] = original;
            }
            f.publication.environment.packageFiles = abi.decode(abi.encode(rows), (R.PackageFile[]));
            _refresh(f);
            _rejected(f);
        }
    }

    function testFuzzCompactPrefixHashMatchesLiteralAtWordBoundaries(bytes32 digest, uint64 size)
        external
        view
    {
        uint256[5] memory widths = [uint256(31), 32, 33, 63, 64];
        R.PackageFile[] memory rows = new R.PackageFile[](9);
        rows[0] = R.PackageFile("metric/", size, digest);
        rows[1] = R.PackageFile("Metric/a", size, digest);
        rows[2] = R.PackageFile("metricx/a", size, digest);
        rows[3] = R.PackageFile("metric/a", size, digest);
        for (uint256 i; i < widths.length; ++i) {
            rows[4 + i] = R.PackageFile(
                _edge(widths[i], bytes1("b")), size, keccak256(abi.encode(digest, i))
            );
        }
        (uint256 count, bytes32 hash) = probe.prefix(rows);
        (uint256 expectedCount, bytes32 expectedHash) = _literalPrefix(rows);
        require(
            count == 6 && count == expectedCount && hash == expectedHash,
            "four literal words and count"
        );
        rows[8].sha256Digest ^= bytes32(uint256(1));
        (, bytes32 changed) = probe.prefix(rows);
        (, bytes32 literalChanged) = _literalPrefix(rows);
        require(changed != hash && changed == literalChanged, "tail field remains committed");
    }

    function _small() private view returns (Fixture memory f) {
        T.Supplement memory s;
        for (uint256 i; i < 4; ++i) {
            s.sources[i] =
                T.SourceFile(Proof.sourcePath(i), abi.encode("synthetic fixed source", i));
        }
        s.implementationIndex = Proof.implementationIndex(s.sources);
        s.parameters = bytes("{\"synthetic\":true}");
        s.runtime.environmentObjectHash = keccak256("synthetic environment object");
        s.runtime.environmentManifestHash = keccak256("synthetic environment manifest");
        s.runtime.entrypoint = "metric/source/tools/preservation/reference_metric.py";
        s.runtime.interpreter = "metric/python/python.exe";
        s.runtime.launcher = "metric/launch.py";
        s.runtime.sourceRoot = "metric/source";
        s.runtime.argv = new string[](4);
        s.runtime.argv[0] = "-I";
        s.runtime.argv[1] = "-S";
        s.runtime.argv[2] = "-B";
        s.runtime.argv[3] = "metric/launch.py";
        s.runtime.members = new R.PackageFile[](8);
        for (uint256 i; i < 4; ++i) {
            s.runtime.members[i] = R.PackageFile(
                string.concat("metric/source/", s.sources[i].path),
                uint64(s.sources[i].content.length),
                sha256(s.sources[i].content)
            );
        }
        s.runtime.members[4] = R.PackageFile(
            "metric/implementation.json",
            uint64(s.implementationIndex.length),
            sha256(s.implementationIndex)
        );
        s.runtime.members[5] = R.PackageFile(
            "metric/parameters.json", uint64(s.parameters.length), sha256(s.parameters)
        );
        s.runtime.members[6] =
            R.PackageFile(s.runtime.interpreter, 100, keccak256("synthetic interpreter bytes"));
        s.runtime.members[7] =
            R.PackageFile(s.runtime.launcher, 50, keccak256("synthetic launcher bytes"));
        _sort(s.runtime.members);
        s.replay.executedAt = 100;
        f.supplement = s;
        f.publication.environment.packageFiles =
            abi.decode(abi.encode(s.runtime.members), (R.PackageFile[]));
        _inputs(f);
        _refresh(f);
    }

    function _inputs(Fixture memory f) private pure {
        f.publication.environment.objectHash = f.supplement.runtime.environmentObjectHash;
        f.publication.environment.manifestHash = f.supplement.runtime.environmentManifestHash;
        f.publication.environment.viewportWidth = 16;
        f.publication.environment.viewportHeight = 16;
        f.publication.environment.devicePixelRatio = 1;
        f.publication.captures = new R.Capture[](1);
        f.publication.captures[0].repeatCaptureSha256 =
            [keccak256("first synthetic PNG"), keccak256("repeat synthetic PNG")];
        f.evidence.mode = M.Mode.PERCEPTUAL_TOLERANCE;
        f.evidence.perceptual.metric.implementationHash =
            keccak256(f.supplement.implementationIndex);
        f.evidence.perceptual.metric.parametersHash = keccak256(f.supplement.parameters);
        f.evidence.perceptual.reportHash = keccak256("synthetic original report");
        f.evidence.perceptual.threshold = 990000000;
        f.evidence.perceptual.evaluatedAt = 1;
        f.context = keccak256("explicit metric-proof test context");
    }

    function _refresh(Fixture memory f) private view {
        T.Replay memory r = f.supplement.replay;
        r.runtimeHash =
            keccak256(abi.encode(keccak256("6529STREAM_METRIC_RUNTIME_V1"), f.supplement.runtime));
        r.contextHash = f.context;
        r.reportHash = f.evidence.perceptual.reportHash;
        r.inputManifest = Proof.inputManifest(f.publication, f.evidence.perceptual, f.context);
        r.inputsHash = keccak256(r.inputManifest);
        r.exitCode = 0;
        bytes memory diagnostic = bytes("explicit synthetic diagnostic");
        if (r.transcript.length != 0) {
            (,,,,,,, diagnostic) = abi.decode(
                r.transcript, (bytes32, bytes32, bytes32, bytes32, bytes32, uint64, uint32, bytes)
            );
        }
        r.transcript = abi.encode(
            keccak256("6529STREAM_METRIC_TRANSCRIPT_V1"),
            r.runtimeHash,
            r.contextHash,
            r.reportHash,
            r.inputsHash,
            r.executedAt,
            r.exitCode,
            diagnostic
        );
        f.supplement.replay = r;
    }

    function _accepted(Fixture memory f) private view returns (bytes32 runtime, bytes32 replay) {
        _prefixEqual(f);
        (runtime, replay) = probe.compare(f.publication, f.evidence, f.context, f.supplement);
        require(
            runtime
                == keccak256(
                    abi.encode(keccak256("6529STREAM_METRIC_RUNTIME_V1"), f.supplement.runtime)
                ),
            "literal runtime preimage"
        );
        require(
            replay
                == keccak256(
                    abi.encode(keccak256("6529STREAM_METRIC_REPLAY_V1"), f.supplement.replay)
                ),
            "literal replay preimage"
        );
        bytes memory canonical = abi.encode(f.supplement);
        (bytes32 a, bytes32 b) = probe.stored(
            f.publication,
            f.evidence,
            f.context,
            canonical,
            keccak256(canonical),
            uint32(canonical.length)
        );
        require(a == runtime && b == replay, "canonical full supplement matches both proof outputs");
    }

    function _rejected(Fixture memory f) private view {
        // BOTH carriers and the recorded runtime/replay hash are internally consistent;
        // these negatives reach semantic validation, not an unrelated old prefix mismatch.
        _prefixEqual(f);
        require(
            f.supplement.replay.runtimeHash
                == keccak256(
                    abi.encode(keccak256("6529STREAM_METRIC_RUNTIME_V1"), f.supplement.runtime)
                )
        );
        (bool a, bytes memory x) = address(probe)
            .staticcall(
                abi.encodeCall(probe.full, (f.publication, f.evidence, f.context, f.supplement))
            );
        (bool b, bytes memory y) = address(probe)
            .staticcall(
                abi.encodeCall(probe.compact, (f.publication, f.evidence, f.context, f.supplement))
            );
        bytes32 expected = keccak256(abi.encodeWithSelector(T.InvalidMetricSupplement.selector));
        require(
            !a && !b && keccak256(x) == expected && keccak256(y) == expected,
            "same exact original refusal"
        );
    }

    function _prefixEqual(Fixture memory f) private view {
        (uint256 n, bytes32 h) = probe.prefix(f.publication.environment.packageFiles);
        (uint256 a, bytes32 b) = _literalPrefix(f.publication.environment.packageFiles);
        (uint256 c, bytes32 d) = _literalPrefix(f.supplement.runtime.members);
        require(
            n == a && a == c && c == f.supplement.runtime.members.length && h == b && b == d,
            "complete equal prefix before lookup"
        );
    }

    function _pairedChange(Fixture memory f, string memory target, uint64 size, bytes32 digest)
        private
        pure
    {
        uint256 a = _index(f.supplement.runtime.members, target);
        uint256 b = _index(f.publication.environment.packageFiles, target);
        f.supplement.runtime.members[a].byteSize = size;
        f.supplement.runtime.members[a].sha256Digest = digest;
        f.publication.environment.packageFiles[b].byteSize = size;
        f.publication.environment.packageFiles[b].sha256Digest = digest;
    }

    function _exactTarget(Fixture memory f, uint256 i) private pure returns (string memory) {
        if (i < 4) return string.concat("metric/source/", f.supplement.sources[i].path);
        if (i == 4) return "metric/implementation.json";
        require(i == 5);
        return "metric/parameters.json";
    }

    function _index(R.PackageFile[] memory rows, string memory target)
        private
        pure
        returns (uint256)
    {
        bytes32 hash = keccak256(bytes(target));
        for (uint256 i; i < rows.length; ++i) {
            if (keccak256(bytes(rows[i].path)) == hash) return i;
        }
        revert("fixture target absent");
    }

    function _without(R.PackageFile[] memory rows, string memory target)
        private
        pure
        returns (R.PackageFile[] memory out)
    {
        uint256 at = _index(rows, target);
        out = new R.PackageFile[](rows.length - 1);
        uint256 cursor;
        for (uint256 i; i < rows.length; ++i) {
            if (i != at) out[cursor++] = rows[i];
        }
    }

    function _edge(uint256 length, bytes1 tail) private pure returns (string memory) {
        bytes memory source = bytes("metric/source/tools/preservation/reference_metric.py");
        bytes memory out = new bytes(length);
        for (uint256 i; i < length; ++i) {
            out[i] = i < source.length ? source[i] : bytes1("a");
        }
        out[length - 1] = tail;
        return string(out);
    }

    function _sort(R.PackageFile[] memory rows) private pure {
        for (uint256 i = 1; i < rows.length; ++i) {
            R.PackageFile memory value =
                R.PackageFile(rows[i].path, rows[i].byteSize, rows[i].sha256Digest);
            uint256 j = i;
            while (j != 0 && _less(bytes(value.path), bytes(rows[j - 1].path))) {
                rows[j] = rows[j - 1];
                --j;
            }
            rows[j] = value;
        }
    }

    function _less(bytes memory a, bytes memory b) private pure returns (bool) {
        uint256 count = a.length < b.length ? a.length : b.length;
        for (uint256 i; i < count; ++i) {
            if (a[i] != b[i]) return uint8(a[i]) < uint8(b[i]);
        }
        return a.length < b.length;
    }

    function _literalPrefix(R.PackageFile[] memory rows)
        private
        pure
        returns (uint256 count, bytes32 hash)
    {
        hash = keccak256("6529STREAM_METRIC_COMPLETE_PREFIX_V1");
        bytes memory prefix = bytes("metric/");
        for (uint256 i; i < rows.length; ++i) {
            bytes memory path = bytes(rows[i].path);
            bool included = path.length > prefix.length;
            for (uint256 j; j < prefix.length && included; ++j) {
                if (path[j] != prefix[j]) included = false;
            }
            if (!included) continue;
            hash = keccak256(
                abi.encode(hash, keccak256(path), rows[i].byteSize, rows[i].sha256Digest)
            );
            ++count;
        }
        hash = keccak256(abi.encode(hash, count));
    }
}
