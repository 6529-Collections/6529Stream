// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceMetricProof as Proof
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricProof.sol";
import {
    StreamReferenceMetricEncodedProof as Encoded
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricEncodedProof.sol";
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
import {
    IStreamReferenceMetricSupplement as I
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamReferenceMetricSupplement.sol";

interface CompactVm {
    function readFileBinary(string calldata) external view returns (bytes memory);
    function readFile(string calldata) external view returns (string memory);
    function parseJsonBytes(string calldata, string calldata) external pure returns (bytes memory);
    function warp(uint256) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
}

contract CompactMetricProbe {
    function compare(
        R.Publication memory p,
        M.Evidence memory e,
        bytes32 context,
        T.Supplement memory s
    ) external view returns (bytes32 runtime, bytes32 replay) {
        (runtime, replay) = Proof.requireEvidence(p, e, context, s);
        (bytes32 a, bytes32 b) = Proof.requireProjected(Proof.project(p, e, context), s);
        (bytes32 c, bytes32 d) = Proof.requireCompact(Proof.compact(p, e, context), s);
        require(runtime == a && runtime == c && replay == b && replay == d);
    }

    function full(
        R.Publication memory p,
        M.Evidence memory e,
        bytes32 context,
        T.Supplement memory s
    ) external view returns (bytes32, bytes32) {
        return Proof.requireEvidence(p, e, context, s);
    }

    function compact(
        R.Publication memory p,
        M.Evidence memory e,
        bytes32 context,
        T.Supplement memory s
    ) external view returns (bytes32, bytes32) {
        return Proof.requireCompact(Proof.compact(p, e, context), s);
    }

    function prefix(R.PackageFile[] memory rows) external pure returns (uint256, bytes32) {
        return Proof.prefixCommitment(rows);
    }

    function prepare(
        R.Publication memory p,
        M.Evidence memory e,
        bytes32 context,
        Encoded.Guard memory g,
        bytes calldata raw
    ) external view returns (bytes32, bytes memory, bytes32, bytes32) {
        R.Dependencies memory d;
        return Encoded.prepare(d, Proof.compact(p, e, context), g, raw);
    }

    function stored(
        R.Publication memory p,
        M.Evidence memory e,
        bytes32 context,
        bytes memory raw,
        bytes32 hash,
        uint32 length
    ) external view returns (bytes32, bytes32) {
        R.Dependencies memory d;
        return Encoded.requireCanonical(d, Proof.compact(p, e, context), raw, hash, length);
    }
}

/// @dev Complete retained corpus, explicit synthetic context/report, mocked registered definitions.
/// This exercises byte/proof transport, not actual current-source or writer admission.
contract StreamReferenceMetricCompactTest {
    CompactVm constant vm = CompactVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    CompactMetricProbe private probe;
    R.Publication private publication;
    M.Evidence private evidence;
    T.Supplement private supplement;
    bytes32 private context;
    bytes32 constant KEY = keccak256("original reference");

    function setUp() public {
        probe = new CompactMetricProbe();
        T.Supplement memory s = abi.decode(
            vm.readFileBinary("test/fixtures/preservation/reference-metric-replay-v1.abi"),
            (T.Supplement)
        );
        vm.warp(s.replay.executedAt);
        R.Publication memory p;
        string memory corpus =
            vm.readFile("test/fixtures/preservation/reference-combined-native-v1.json");
        p.environment.packageFiles =
            abi.decode(vm.parseJsonBytes(corpus, ".packageFilesABI"), (R.PackageFile[]));
        p.environment.platformPrerequisites =
            abi.decode(vm.parseJsonBytes(corpus, ".platformPrerequisitesABI"), (R.PackageFile[]));
        require(
            p.environment.packageFiles.length == 1048
                && p.environment.platformPrerequisites.length == 102
        );
        p.environment.objectHash = s.runtime.environmentObjectHash;
        p.environment.manifestHash = s.runtime.environmentManifestHash;
        p.environment.viewportWidth = 16;
        p.environment.viewportHeight = 16;
        p.environment.devicePixelRatio = 1;
        p.captures = new R.Capture[](1);
        p.captures[0].repeatCaptureSha256 = [keccak256("first PNG"), keccak256("repeat PNG")];
        M.Evidence memory e;
        e.mode = M.Mode.PERCEPTUAL_TOLERANCE;
        e.perceptual.metric.implementationHash = keccak256(s.implementationIndex);
        e.perceptual.metric.parametersHash = keccak256(s.parameters);
        e.perceptual.reportHash = keccak256("synthetic report");
        e.perceptual.threshold = 990000000;
        e.perceptual.evaluatedAt = 1;
        context = keccak256(abi.encode("explicit complete synthetic context", p, e));
        _replay(p, e, s);
        publication = p;
        evidence = e;
        supplement = s;
        vm.mockCall(
            address(Definitions),
            abi.encodeWithSelector(Definitions.definition.selector),
            abi.encode(bytes("registered definition boundary"))
        );
    }

    function _replay(R.Publication memory p, M.Evidence memory e, T.Supplement memory s)
        private
        view
    {
        s.replay.contextHash = context;
        s.replay.reportHash = e.perceptual.reportHash;
        s.replay.inputManifest = Proof.inputManifest(p, e.perceptual, context);
        s.replay.inputsHash = keccak256(s.replay.inputManifest);
        (,,,,,,, bytes memory diagnostic) = abi.decode(
            s.replay.transcript,
            (bytes32, bytes32, bytes32, bytes32, bytes32, uint64, uint32, bytes)
        );
        s.replay.transcript = abi.encode(
            keccak256("6529STREAM_METRIC_TRANSCRIPT_V1"),
            s.replay.runtimeHash,
            context,
            s.replay.reportHash,
            s.replay.inputsHash,
            s.replay.executedAt,
            s.replay.exitCode,
            diagnostic
        );
    }

    function _guard() private view returns (Encoded.Guard memory) {
        return Encoded.Guard(KEY, 0, address(this), 3, 1);
    }

    function testFullCorpusOriginalProjectedCompactAndEncodedParity() public view {
        (bytes32 a, bytes32 b) = probe.compare(publication, evidence, context, supplement);
        require(
            a
                == keccak256(
                    abi.encode(keccak256("6529STREAM_METRIC_RUNTIME_V1"), supplement.runtime)
                )
        );
        require(
            b == keccak256(abi.encode(keccak256("6529STREAM_METRIC_REPLAY_V1"), supplement.replay))
        );
        bytes memory canonical = abi.encode(supplement);
        bytes memory callData = abi.encodeCall(I.publishMetricSupplement, (KEY, supplement));
        (bytes32 key, bytes memory result, bytes32 c, bytes32 d) =
            probe.prepare(publication, evidence, context, _guard(), callData);
        require(key == KEY && keccak256(result) == keccak256(canonical) && a == c && b == d);
        (c, d) = probe.stored(
            publication,
            evidence,
            context,
            canonical,
            keccak256(canonical),
            uint32(canonical.length)
        );
        require(a == c && b == d);
    }

    function testCompletePrefixLiteralAndBoundaryPredicate() public view {
        R.PackageFile[] memory rows = publication.environment.packageFiles;
        (uint256 n, bytes32 h) = probe.prefix(rows);
        (uint256 expected, bytes32 literal) = _literal(rows);
        require(n == 684 && n == expected && h == literal);
        R.PackageFile[] memory small = new R.PackageFile[](5);
        small[0] = R.PackageFile("metric/", 1, bytes32(uint256(1)));
        small[1] = R.PackageFile("metric/a", type(uint64).max, bytes32(uint256(2)));
        small[2] = R.PackageFile("Metric/a", 1, bytes32(uint256(3)));
        small[3] = R.PackageFile("metricx/a", 1, bytes32(uint256(4)));
        small[4] = R.PackageFile("metric//", 2, bytes32(uint256(5)));
        (n, h) = probe.prefix(small);
        (expected, literal) = _literal(small);
        require(n == 2 && expected == n && h == literal);
    }

    function testFuzzAllRowFieldsAndOrderCommit(bytes32 digest, uint64 size) public view {
        R.PackageFile[] memory rows = new R.PackageFile[](2);
        rows[0] = R.PackageFile("metric/a", size, digest);
        rows[1] = R.PackageFile("metric/b", 7, bytes32(uint256(9)));
        (uint256 n, bytes32 h) = probe.prefix(rows);
        (uint256 expected, bytes32 literal) = _literal(rows);
        require(n == expected && h == literal);
        R.PackageFile memory saved = rows[0];
        rows[0] = rows[1];
        rows[1] = saved;
        (, bytes32 reverse) = probe.prefix(rows);
        require(h != reverse);
    }

    function testMissingExtraDuplicateAndChangedMembersMatchOriginal() public {
        T.Supplement memory s = supplement;
        s.runtime.members[20].byteSize += 1;
        _both(publication, s);
        s = supplement;
        s.runtime.members[20].sha256Digest ^= bytes32(uint256(1));
        _both(publication, s);
        s = supplement;
        s.runtime.members[20].path = "metric/changed";
        _both(publication, s);
        s = supplement;
        s.runtime.members[20] = s.runtime.members[19];
        _both(publication, s);
        s = supplement;
        R.PackageFile memory row = s.runtime.members[19];
        s.runtime.members[19] = s.runtime.members[20];
        s.runtime.members[20] = row;
        _both(publication, s);
        s = supplement;
        R.PackageFile[] memory shorter = new R.PackageFile[](s.runtime.members.length - 1);
        for (uint256 i; i < shorter.length; ++i) {
            shorter[i] = s.runtime.members[i];
        }
        s.runtime.members = shorter;
        _both(publication, s);
        s = supplement;
        R.PackageFile[] memory longer = new R.PackageFile[](s.runtime.members.length + 1);
        for (uint256 i; i < s.runtime.members.length; ++i) {
            longer[i] = s.runtime.members[i];
        }
        longer[longer.length - 1] = R.PackageFile("metric/zz-extra", 1, bytes32(uint256(1)));
        s.runtime.members = longer;
        _both(publication, s);
    }

    function testSourcePrefixCannotOmitOrSubstituteRows() public {
        R.Publication memory p = publication;
        uint256 index;
        while (
            keccak256(bytes(p.environment.packageFiles[index].path))
                != keccak256(bytes(supplement.runtime.members[20].path))
        ) ++index;
        p.environment.packageFiles[index].path = "notmetric/omitted";
        _both(p, supplement);
        p = publication;
        p.environment.packageFiles[index].byteSize += 1;
        _both(p, supplement);
        p = publication;
        p.environment.packageFiles[index].sha256Digest ^= bytes32(uint256(1));
        _both(p, supplement);
    }

    function testCaptureZeroThreeAndTwoHaveOriginalMeaning() public {
        R.Publication memory p = publication;
        p.captures = new R.Capture[](0);
        _both(p, supplement);
        p = publication;
        p.captures = new R.Capture[](3);
        _both(p, supplement);
        p = publication;
        p.captures = new R.Capture[](2);
        p.captures[0].repeatCaptureSha256 = publication.captures[0].repeatCaptureSha256;
        p.captures[1].repeatCaptureSha256 = [keccak256("second first"), keccak256("second repeat")];
        T.Supplement memory s = supplement;
        _replay(p, evidence, s);
        probe.compare(p, evidence, context, s);
    }

    function testMalformedRawAndCanonicalByteMismatchRefuse() public {
        bytes memory canonical = abi.encode(supplement);
        (bool ok,) = address(probe)
            .staticcall(
                abi.encodeCall(
                    probe.prepare, (publication, evidence, context, _guard(), hex"010203")
                )
            );
        require(!ok);
        (ok,) = address(probe)
            .staticcall(
                abi.encodeCall(
                    probe.stored,
                    (
                        publication,
                        evidence,
                        context,
                        abi.encodePacked(canonical, bytes32(0)),
                        keccak256(canonical),
                        uint32(canonical.length)
                    )
                )
            );
        require(!ok);
        (ok,) = address(probe)
            .staticcall(
                abi.encodeCall(
                    probe.stored,
                    (
                        publication,
                        evidence,
                        context,
                        canonical,
                        keccak256(canonical),
                        uint32(canonical.length - 1)
                    )
                )
            );
        require(!ok);
    }

    function testDuplicateAndAuthorityPrecedeDefinitionAndProof() public {
        bytes memory reason = abi.encodeWithSignature("MissingDefinition()");
        vm.mockCallRevert(
            address(Definitions), abi.encodeWithSelector(Definitions.definition.selector), reason
        );
        T.Supplement memory s = supplement;
        s.parameters = hex"00";
        bytes memory raw = abi.encodeCall(I.publishMetricSupplement, (KEY, s));
        Encoded.Guard memory g = _guard();
        g.existingSupplementHash = bytes32(uint256(1));
        _prepareFailure(
            g, raw, abi.encodeWithSelector(T.MetricSupplementAlreadyPublished.selector, KEY)
        );
        g = _guard();
        g.recorder = address(0);
        _prepareFailure(g, raw, abi.encodeWithSelector(T.InvalidMetricSupplement.selector));
        _prepareFailure(_guard(), raw, reason);
    }

    function _prepareFailure(Encoded.Guard memory g, bytes memory raw, bytes memory expected)
        private
    {
        (bool ok, bytes memory result) = address(probe)
            .staticcall(abi.encodeCall(probe.prepare, (publication, evidence, context, g, raw)));
        require(!ok && keccak256(result) == keccak256(expected));
    }

    function _both(R.Publication memory p, T.Supplement memory s) private {
        (bool a, bytes memory x) =
            address(probe).staticcall(abi.encodeCall(probe.full, (p, evidence, context, s)));
        (bool b, bytes memory y) =
            address(probe).staticcall(abi.encodeCall(probe.compact, (p, evidence, context, s)));
        require(!a && !b && keccak256(x) == keccak256(y));
    }

    function _literal(R.PackageFile[] memory rows)
        private
        pure
        returns (uint256 count, bytes32 hash)
    {
        hash = keccak256("6529STREAM_METRIC_COMPLETE_PREFIX_V1");
        for (uint256 i; i < rows.length; ++i) {
            bytes memory p = bytes(rows[i].path);
            bool matches = p.length > 7;
            bytes memory prefix = bytes("metric/");
            for (uint256 j; j < 7 && matches; ++j) {
                if (p[j] != prefix[j]) matches = false;
            }
            if (!matches) continue;
            hash = keccak256(abi.encode(hash, keccak256(p), rows[i].byteSize, rows[i].sha256Digest));
            ++count;
        }
        hash = keccak256(abi.encode(hash, count));
    }
}
