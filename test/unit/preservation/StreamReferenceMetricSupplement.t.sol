// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceMetricProof as Proof
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricProof.sol";
import {
    StreamReferenceMetricTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceMetricTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";

interface MetricFixtureVm {
    function readFileBinary(string calldata path) external view returns (bytes memory);
    function warp(uint256 timestamp) external;
    function expectRevert() external;
}

contract ReferenceMetricProofProbe {
    function pathLess(bytes memory a, bytes memory b) external pure returns (bool) {
        return Proof.pathLess(a, b);
    }

    function validate(
        R.Publication memory p,
        M.Evidence memory e,
        bytes32 context,
        T.Supplement memory s
    ) external view returns (bytes32, bytes32) {
        return Proof.requireEvidence(p, e, context, s);
    }
}

/// @notice Real retained source/runtime/replay bytes, with the original synthetic capture context.
/// @dev No browser, archive receipt, writer authority or current-chain publication is inferred here.
contract StreamReferenceMetricSupplementTest {
    MetricFixtureVm private constant vm =
        MetricFixtureVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant CONTEXT =
        0x1212121212121212121212121212121212121212121212121212121212121212;
    ReferenceMetricProofProbe private probe;
    T.Supplement private saved;
    R.Publication private publication;
    M.Evidence private evidence;

    function setUp() public {
        bytes memory raw =
            vm.readFileBinary("test/fixtures/preservation/reference-metric-replay-v1.abi");
        require(raw.length == 219264);
        require(
            keccak256(raw) == 0x704890c8d588fcf16f927fa6b292ed3f3198594c7a54460a535b59d45b48ef13
        );
        saved = abi.decode(raw, (T.Supplement));
        require(keccak256(abi.encode(saved)) == keccak256(raw));
        vm.warp(saved.replay.executedAt);
        publication.environment.objectHash = saved.runtime.environmentObjectHash;
        publication.environment.manifestHash = saved.runtime.environmentManifestHash;
        publication.environment.packageFiles = saved.runtime.members;
        publication.environment.viewportWidth = 16;
        publication.environment.viewportHeight = 16;
        publication.environment.devicePixelRatio = 1;
        publication.captures.push();
        publication.captures[0].repeatCaptureSha256 = [
            bytes32(0x67f5c738d0805c210ffc7294b4eb21cec527dc14d3fb028f315a0a16a078182b),
            bytes32(0xd410dd8d32b5dc55f03dde6cb0367ba31682a49a1af9a0c15308527a41c6838b)
        ];
        evidence.mode = M.Mode.PERCEPTUAL_TOLERANCE;
        evidence.perceptual.metric.implementationHash =
        0xdf70cb98b947f970bd117c6e7343c1471c9059efa9e36a8248e33c0e59b51aff;
        evidence.perceptual.metric.parametersHash =
        0x1284b35afa316cb69d790a354cefdeb19d00a37116b1ec25e2ded88a1f59add3;
        evidence.perceptual.threshold = 990000000;
        evidence.perceptual.evaluatedAt = 1;
        evidence.perceptual.reportHash =
        0x32b889d85d6f36269730d5e3c2a9b4f9cde4ba3ee51723a75a37a90300f3cdc9;
        probe = new ReferenceMetricProofProbe();
    }

    function testActualRetainedIsolatedReplaySourceAndInputByteClosure() public view {
        (bytes32 runtimeHash, bytes32 replayHash) =
            probe.validate(publication, evidence, CONTEXT, saved);
        require(runtimeHash == saved.replay.runtimeHash);
        require(
            replayHash
                == keccak256(abi.encode(keccak256("6529STREAM_METRIC_REPLAY_V1"), saved.replay))
        );
        require(saved.runtime.members.length == 684 && saved.replay.transcript.length == 28096);
    }

    function testOriginalRawTranscriptCannotMasqueradeAsBoundReplayEnvelope() public {
        T.Supplement memory raw = abi.decode(
            vm.readFileBinary("test/fixtures/preservation/reference-metric-raw-transcript-v1.abi"),
            (T.Supplement)
        );
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, raw);
    }

    function testSourceBytesOrderIndexAndParametersCannotBeSubstituted() public {
        T.Supplement memory s = saved;
        s.sources[0].content[0] ^= 0x01;
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
        s = saved;
        (s.sources[0], s.sources[1]) = (s.sources[1], s.sources[0]);
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
        s = saved;
        s.implementationIndex[0] ^= 0x01;
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
        s = saved;
        s.parameters[0] ^= 0x01;
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
    }

    function testCompleteSameEnvironmentMembershipAndFixedLaunchAreRequired() public {
        T.Supplement memory s = saved;
        s.runtime.members = new R.PackageFile[](saved.runtime.members.length - 1);
        for (uint256 i; i < s.runtime.members.length; ++i) {
            s.runtime.members[i] = saved.runtime.members[i];
        }
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
        s = saved;
        ++s.runtime.members[10].byteSize;
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
        s = saved;
        s.runtime.members[10].sha256Digest = keccak256("substituted member bytes");
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
        s = saved;
        s.runtime.members[10].path = "metric/substituted-member";
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
        s = saved;
        s.runtime.environmentObjectHash = keccak256("another archive");
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
        s = saved;
        s.runtime.argv[0] = "-s";
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
    }

    function testMissingMismatchedOrFutureReplayCannotPassAdmission() public {
        T.Supplement memory s = saved;
        delete s.replay.transcript;
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
        s = saved;
        s.replay.reportHash = keccak256("another report");
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
        s = saved;
        s.replay.inputManifest[0] ^= 0x01;
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
        s = saved;
        ++s.replay.executedAt;
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
        s = saved;
        s.replay.exitCode = 1;
        vm.expectRevert();
        probe.validate(publication, evidence, CONTEXT, s);
    }

    function testFuzzPathOrderMatchesOriginalByteComparison(bytes memory a, bytes memory b)
        public
        view
    {
        require(probe.pathLess(a, b) == _originalLess(a, b));
    }

    function testPathOrderBoundariesAndIgnoredPadding() public view {
        for (uint256 n; n < 100; ++n) {
            bytes memory a = new bytes(n);
            bytes memory b = new bytes(n + 1);
            for (uint256 i; i < n; ++i) {
                a[i] = bytes1(uint8(i));
                b[i] = a[i];
            }
            require(probe.pathLess(a, b));
            require(!probe.pathLess(b, a) && !probe.pathLess(a, a));
            if (n != 0) {
                b[n - 1] = 0xff;
                require(probe.pathLess(a, b) == _originalLess(a, b));
            }
        }
        bytes memory left = hex"0102";
        bytes memory right = hex"0103";
        assembly ("memory-safe") {
            mstore(add(left, 32), or(mload(add(left, 32)), sub(shl(240, 1), 1)))
        }
        require(Proof.pathLess(left, right));
        require(!Proof.pathLess(right, left));
        require(!Proof.pathLess(left, hex"0102"));
    }

    function _originalLess(bytes memory a, bytes memory b) private pure returns (bool) {
        uint256 length = a.length < b.length ? a.length : b.length;
        for (uint256 i; i < length; ++i) {
            if (a[i] != b[i]) return uint8(a[i]) < uint8(b[i]);
        }
        return a.length < b.length;
    }
}
