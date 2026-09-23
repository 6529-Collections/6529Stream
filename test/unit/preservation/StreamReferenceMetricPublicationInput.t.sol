// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceMetricPublicationInput as Encoded
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricPublicationInput.sol";
import {
    StreamReferenceMetricProof as Proof
} from "../../../smart-contracts/domains/preservation/StreamReferenceMetricProof.sol";
import {
    StreamReferenceModeInput as Input
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeInput.sol";
import {
    StreamReferenceRenderSourceReads as Source
} from "../../../smart-contracts/domains/preservation/StreamReferenceRenderSourceReads.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol";

interface PublicationInputVm {
    function readFile(string calldata) external view returns (string memory);
    function parseJsonBytes(string calldata, string calldata) external pure returns (bytes memory);
}

contract MetricPublicationInputProbe {
    struct Result {
        bytes32 source;
        bytes32 evidence;
        bytes32 compact;
        bytes32 context;
        bytes32 preimage;
        uint256 decodeGas;
        uint256 contextGas;
        uint256 foldGas;
        uint256 reservedMemory;
    }

    function old(bytes memory raw, R.Dependencies memory d, M.Evidence memory e)
        external
        view
        returns (Result memory r)
    {
        uint256 g = gasleft();
        R.Publication memory p = abi.decode(raw, (R.Publication));
        r.decodeGas = g - gasleft();
        g = gasleft();
        bytes memory literal = abi.encode(
            keccak256("6529STREAM_REFERENCE_MODE_CONTEXT_V1"),
            d.chainId,
            address(this),
            d.targets,
            d.codeHashes,
            p.collectionId,
            p.referenceId,
            p.snapshotRecordHash,
            p.snapshotRevision,
            p.captures,
            p.environment
        );
        r.context = keccak256(literal);
        r.preimage = keccak256(literal);
        r.contextGas = g - gasleft();
        g = gasleft();
        r.compact = keccak256(abi.encode(Proof.compact(p, e, r.context)));
        r.foldGas = g - gasleft();
        r.source = keccak256(abi.encode(Source.project(p)));
        r.evidence = keccak256(abi.encode(Input.project(p, r.context)));
        assembly ("memory-safe") { mstore(add(r, 256), mload(64)) }
    }

    function originalContext(bytes memory raw, R.Dependencies memory d)
        external
        view
        returns (bytes32)
    {
        return Input.contextHash(d, abi.decode(raw, (R.Publication)));
    }

    function scratchReuse(
        bytes memory raw,
        R.Dependencies memory d,
        M.Evidence memory e,
        uint8 rounds
    ) external view returns (bytes32 context, bytes32 evidence) {
        require(rounds > 0 && rounds <= 4);
        Encoded.Decoded memory decoded = Encoded.read(raw);
        bytes32 live = keccak256(abi.encode(raw, d, e, decoded));
        bytes32 expectedContext = keccak256(Encoded.contextPreimage(d, raw, decoded));
        bytes32 expectedEvidence = keccak256(abi.encode(e));
        uint256 overwriteSize = raw.length + abi.encode(e).length + 2048;
        for (uint256 i; i < rounds; ++i) {
            uint256 before;
            uint256 afterHash;
            assembly ("memory-safe") { before := mload(0x40) }
            evidence = Encoded.evidenceHash(e);
            context = Encoded.contextHash(d, raw, decoded);
            assembly ("memory-safe") { afterHash := mload(0x40) }
            require(before == afterHash, "temporary allocation escaped");
            require(
                context == expectedContext && evidence == expectedEvidence, "literal hash drift"
            );
            bytes memory overwrite = new bytes(overwriteSize);
            for (uint256 j; j < overwrite.length; j += 32) {
                assembly ("memory-safe") { mstore(add(add(overwrite, 32), j), not(add(i, j))) }
            }
            require(keccak256(overwrite) != 0, "overwrite retained");
            require(keccak256(abi.encode(raw, d, e, decoded)) == live, "live input overwritten");
        }
    }

    function prefixed(bytes memory original, R.Dependencies memory d, uint8 rounds)
        external
        view
        returns (bytes32 result, uint256 cost)
    {
        require(rounds > 0 && rounds <= 4);
        bytes memory backing = new bytes(original.length + 320);
        bytes memory raw;
        assembly ("memory-safe") {
            raw := add(backing, 320)
            mstore(raw, mload(original))
            for { let i := 0 } lt(i, mload(original)) { i := add(i, 32) } {
                mstore(add(add(raw, 32), i), mload(add(add(original, 32), i)))
            }
        }
        Encoded.Decoded memory decoded = Encoded.read(raw);
        bytes32 live = keccak256(abi.encode(backing, raw, d, decoded));
        bytes32 expected = Input.contextHash(d, abi.decode(original, (R.Publication)));
        for (uint256 i; i < rounds; ++i) {
            uint256 g = gasleft();
            result = Encoded.contextHashPrefixed(d, backing, raw, decoded);
            cost = g - gasleft();
            require(result == expected, "original context mismatch");
            bytes memory canary = new bytes(1024);
            for (uint256 j; j < canary.length; j += 32) {
                assembly ("memory-safe") { mstore(add(add(canary, 32), j), not(add(i, j))) }
            }
            require(keccak256(canary) != 0, "fresh allocation canary");
            require(
                keccak256(abi.encode(backing, raw, d, decoded)) == live, "borrowed bytes changed"
            );
        }
    }

    /// @dev Measure the first borrowed-header hash before full-preimage or parity allocations.
    /// Calldata decoding and test backing construction are outside this diagnostic span.
    function prefixedCost(bytes memory original, R.Dependencies memory d)
        external
        view
        returns (bytes32 result, uint256 cost)
    {
        bytes memory backing = new bytes(original.length + 320);
        bytes memory raw;
        assembly ("memory-safe") {
            raw := add(backing, 320)
            mstore(raw, mload(original))
            for { let i := 0 } lt(i, mload(original)) { i := add(i, 32) } {
                mstore(add(add(raw, 32), i), mload(add(add(original, 32), i)))
            }
        }
        Encoded.Decoded memory decoded = Encoded.read(raw);
        uint256 g = gasleft();
        result = Encoded.contextHashPrefixed(d, backing, raw, decoded);
        cost = g - gasleft();
        require(keccak256(raw) == keccak256(original), "first hash changed bytes");
        require(
            result == Input.contextHash(d, abi.decode(original, (R.Publication))),
            "first original context"
        );
    }

    function badPrefix(bytes memory original, R.Dependencies memory d, uint8 kind)
        external
        view
        returns (bytes32)
    {
        bytes memory backing = new bytes(original.length + 320);
        bytes memory raw;
        assembly ("memory-safe") {
            raw := add(backing, 320)
            mstore(raw, mload(original))
            for { let i := 0 } lt(i, mload(original)) { i := add(i, 32) } {
                mstore(add(add(raw, 32), i), mload(add(add(original, 32), i)))
            }
        }
        Encoded.Decoded memory decoded = Encoded.read(raw);
        if (kind == 0) backing = new bytes(backing.length);
        if (kind == 1) assembly ("memory-safe") { mstore(backing, sub(mload(backing), 1)) }
        if (kind == 2) decoded.capturesStart = 384;
        if (kind == 3) decoded.environmentStart = 384;
        if (kind == 4) decoded.manifestStart = decoded.environmentStart - 1;
        if (kind == 5) decoded.manifestStart = raw.length + 32;
        return Encoded.contextHashPrefixed(d, backing, raw, decoded);
    }

    function fresh(bytes memory raw, R.Dependencies memory d, M.Evidence memory e)
        external
        view
        returns (Result memory r)
    {
        uint256 g = gasleft();
        Encoded.Decoded memory p = Encoded.read(raw);
        r.decodeGas = g - gasleft();
        g = gasleft();
        r.context = Encoded.contextHash(d, raw, p);
        r.contextGas = g - gasleft();
        r.preimage = keccak256(Encoded.contextPreimage(d, raw, p));
        require(Encoded.evidenceHash(e) == keccak256(abi.encode(e)));
        g = gasleft();
        r.compact = keccak256(abi.encode(Encoded.compact(p, e, r.context)));
        r.foldGas = g - gasleft();
        r.source = keccak256(abi.encode(p.source));
        r.evidence = keccak256(abi.encode(Encoded.evidenceInput(p, r.context)));
        assembly ("memory-safe") { mstore(add(r, 256), mload(64)) }
    }
}

/// @dev Full ABI/corpus transport oracle. No live source/authority/transaction capacity claim.
contract StreamReferenceMetricPublicationInputTest {
    PublicationInputVm constant vm =
        PublicationInputVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    MetricPublicationInputProbe private probe;
    event InputCost(
        uint256 oldDecode,
        uint256 oldContext,
        uint256 oldFold,
        uint256 newDecode,
        uint256 newContext,
        uint256 newFold,
        uint256 oldMemory,
        uint256 newMemory
    );

    function setUp() public {
        probe = new MetricPublicationInputProbe();
    }

    function _dependencies() private pure returns (R.Dependencies memory d) {
        d.chainId = 31337;
        for (uint256 i; i < 7; ++i) {
            d.targets[i] = address(uint160(100 + i));
            d.codeHashes[i] = keccak256(abi.encode(i));
        }
    }

    function _evidence() private pure returns (M.Evidence memory e) {
        e.mode = M.Mode.PERCEPTUAL_TOLERANCE;
        e.perceptual.metric.implementationHash = keccak256("implementation");
        e.perceptual.metric.parametersHash = keccak256("parameters");
        e.perceptual.reportHash = keccak256("report");
        e.perceptual.threshold = 123;
        e.perceptual.evaluatedAt = 456;
    }

    function _base() private pure returns (R.Publication memory p) {
        p.collectionId = 3;
        p.referenceId = keccak256("reference");
        p.expectedHead = keccak256("head");
        p.expectedRevision = 8;
        p.snapshotRecordHash = keccak256("snapshot");
        p.snapshotRevision = 9;
        p.expectedSourcesHash = keccak256("sources");
        p.manifestURI = "ipfs://retained";
        p.effectiveAt = 999;
        p.reasonHash = keccak256("reason");
        p.captures = new R.Capture[](2);
        for (uint256 i; i < 2; ++i) {
            R.Capture memory c;
            c.tokenId = i + 10;
            c.collectionSerial = i + 20;
            c.metadataJSONHash = keccak256(abi.encode(i, "JSON"));
            c.htmlHash = keccak256(abi.encode(i, "HTML"));
            c.htmlBytes = 7;
            c.animationHTML = abi.encode(i, "actual arbitrary bytes");
            c.objectHash = keccak256(abi.encode(i, "object"));
            c.coverageHash = keccak256(abi.encode(i, "coverage"));
            c.sourceSha256 = keccak256(abi.encode(i, "source"));
            c.repeatCaptureSha256 =
                [keccak256(abi.encode(i, "first")), keccak256(abi.encode(i, "repeat"))];
            c.environmentManifestHash = keccak256("environment");
            c.capturedAt = 200 + uint64(i);
            p.captures[i] = c;
        }
        R.Environment memory e;
        e.objectHash = keccak256("object");
        e.coverageHash = keccak256("coverage");
        e.manifestHash = keccak256("environment");
        e.manifestBytes = 12000;
        e.engineName = "engine";
        e.engineVersion = "version";
        e.engineExecutableSha256 = keccak256("engineSha");
        e.toolchainName = "tools";
        e.toolchainVersion = "toolsVersion";
        e.toolchainSha256 = keccak256("toolsha");
        e.engineExecutablePath = "engine/exe";
        e.toolchainPath = "tool/main";
        e.operatingSystem = "Windows";
        e.operatingSystemVersion = "2022";
        e.architecture = "AMD64";
        e.viewportWidth = 16;
        e.viewportHeight = 20;
        e.devicePixelRatio = 1;
        e.colorSpace = "sRGB";
        e.softwareRasterization = true;
        e.captureProfile = keccak256("profile");
        e.licenseNote = "explicit license";
        e.packageFiles = new R.PackageFile[](3);
        e.packageFiles[0] = R.PackageFile("metric/", 1, keccak256("excluded exact prefix"));
        e.packageFiles[1] = R.PackageFile("metric/a", type(uint64).max, keccak256("a"));
        e.packageFiles[2] = R.PackageFile("other/b", 5, keccak256("b"));
        e.platformPrerequisites = new R.PackageFile[](1);
        e.platformPrerequisites[0] = R.PackageFile("C:/system.dll", 6, keccak256("dll"));
        p.environment = e;
    }

    function _compare(R.Publication memory p)
        private
        view
        returns (
            MetricPublicationInputProbe.Result memory a,
            MetricPublicationInputProbe.Result memory b
        )
    {
        bytes memory raw = abi.encode(p);
        a = probe.old(raw, _dependencies(), _evidence());
        b = probe.fresh(raw, _dependencies(), _evidence());
        require(
            a.source == b.source && a.evidence == b.evidence && a.compact == b.compact
                && a.context == b.context && a.preimage == b.preimage
        );
        require(a.context == probe.originalContext(raw, _dependencies()));
    }

    function testLiteralAllFieldsAndCompleteSourceProjection() public view {
        _compare(_base());
    }

    function testEmptyArraysAndStringsRemainCanonicalInputs() public view {
        R.Publication memory p;
        _compare(p);
    }

    function testComplete1048Package102PlatformLiteralAndCost() public {
        R.Publication memory p = _base();
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
        (MetricPublicationInputProbe.Result memory a, MetricPublicationInputProbe.Result memory b) =
            _compare(p);
        emit InputCost(
            a.decodeGas,
            a.contextGas,
            a.foldGas,
            b.decodeGas,
            b.contextGas,
            b.foldGas,
            a.reservedMemory,
            b.reservedMemory
        );
    }

    event PrefixedContextCost(uint256 gasUsed);

    function testPrefixedCompleteCorpusRestoresBackingAndOriginalContext() public {
        R.Publication memory p = _base();
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
        (bytes32 actual,) = probe.prefixed(abi.encode(p), _dependencies(), 4);
        require(actual == probe.originalContext(abi.encode(p), _dependencies()));
        (bytes32 first, uint256 cost) = probe.prefixedCost(abi.encode(p), _dependencies());
        require(first == actual);
        emit PrefixedContextCost(cost);
    }

    function testFuzzPrefixedContextRestoresEveryInput(bytes32 changed, uint8 count) public view {
        R.Publication memory p = _base();
        p.environment.licenseNote = string(abi.encodePacked(changed));
        p.manifestURI = string(abi.encodePacked(changed, count));
        R.Dependencies memory d = _dependencies();
        d.codeHashes[0] = changed;
        (bytes32 actual,) = probe.prefixed(abi.encode(p), d, uint8(uint256(count) % 4 + 1));
        require(actual == probe.originalContext(abi.encode(p), d));
    }

    function testPrefixedCodecRejectsWrongAliasLengthAndBounds() public view {
        bytes memory raw = abi.encode(_base());
        for (uint8 kind; kind < 6; ++kind) {
            (bool ok, bytes memory reason) = address(probe)
                .staticcall(abi.encodeCall(probe.badPrefix, (raw, _dependencies(), kind)));
            require(
                !ok
                    && keccak256(reason)
                        == keccak256(abi.encodeWithSelector(M.InvalidModeEvidence.selector))
            );
        }
    }

    function testCompleteCorpusScratchReusePreservesLiveInputs() public view {
        R.Publication memory p = _base();
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
        bytes memory raw = abi.encode(p);
        (bytes32 context, bytes32 evidence) =
            probe.scratchReuse(raw, _dependencies(), _evidence(), 4);
        require(context == probe.originalContext(raw, _dependencies()));
        require(evidence == keccak256(abi.encode(_evidence())));
    }

    function testFuzzScratchReuseRetainsEvidenceAndContext(bytes32 changed, uint8 rounds)
        public
        view
    {
        R.Publication memory p = _base();
        p.environment.licenseNote = string(abi.encodePacked(changed));
        M.Evidence memory e = _evidence();
        e.perceptual.reportHash = changed;
        bytes memory raw = abi.encode(p);
        (bytes32 context, bytes32 evidence) =
            probe.scratchReuse(raw, _dependencies(), e, uint8(uint256(rounds) % 4 + 1));
        require(context == probe.originalContext(raw, _dependencies()));
        require(evidence == keccak256(abi.encode(e)));
    }

    function testFuzzCanonicalPathsAndAllRowFields(
        bytes32 digest,
        uint64 size,
        bytes32 pathSeed,
        uint8 count
    ) public view {
        R.Publication memory p = _base();
        p.environment.packageFiles = new R.PackageFile[](uint256(count) % 20);
        for (uint256 i; i < p.environment.packageFiles.length; ++i) {
            p.environment.packageFiles[i] = R.PackageFile(
                string(abi.encodePacked(i % 2 == 0 ? "metric/" : "else/", pathSeed, i)),
                size,
                keccak256(abi.encode(digest, i))
            );
        }
        _compare(p);
    }

    function testEveryEnvironmentFieldAndCaptureMutationMatchesLiteral() public view {
        R.Publication memory p = _base();
        _compare(p);
        p.environment.objectHash = keccak256("changed object");
        p.environment.coverageHash = keccak256("changed coverage");
        p.environment.manifestHash = keccak256("changed manifest");
        p.environment.manifestBytes = 123;
        p.environment.engineName = "another engine";
        p.environment.engineVersion = "another version";
        p.environment.engineExecutableSha256 = keccak256("exe");
        p.environment.toolchainName = "other tools";
        p.environment.toolchainVersion = "v2";
        p.environment.toolchainSha256 = keccak256("sha");
        p.environment.engineExecutablePath = "new/exe";
        p.environment.toolchainPath = "new/tool";
        p.environment.packageFiles[0].path = "metric/included";
        p.environment.platformPrerequisites[0].sha256Digest = keccak256("new platform");
        p.environment.operatingSystem = "Linux";
        p.environment.operatingSystemVersion = "v3";
        p.environment.architecture = "ARM";
        p.environment.viewportWidth = 255;
        p.environment.viewportHeight = 256;
        p.environment.devicePixelRatio = 2;
        p.environment.colorSpace = "P3";
        p.environment.softwareRasterization = false;
        p.environment.captureProfile = keccak256("other profile");
        p.environment.licenseNote = "other note";
        p.captures[0].repeatCaptureSha256[1] = keccak256("new PNG");
        p.captures[1].animationHTML = hex"00abcdef";
        _compare(p);
    }

    function testOutOfContextFieldsKeepOriginalContextMeaning() public view {
        R.Publication memory p = _base();
        (MetricPublicationInputProbe.Result memory a,) = _compare(p);
        p.expectedHead = keccak256("other head");
        p.expectedRevision = 44;
        p.expectedSourcesHash = keccak256("other source");
        p.manifestURI = "ipfs://changed";
        p.effectiveAt = 1234;
        p.reasonHash = keccak256("other reason");
        (MetricPublicationInputProbe.Result memory b,) = _compare(p);
        require(a.context == b.context && a.evidence != b.evidence);
    }

    function _put(bytes memory raw, uint256 at, uint256 value) private pure {
        require(at + 32 <= raw.length);
        assembly ("memory-safe") { mstore(add(add(raw, 32), at), value) }
    }

    function _word(bytes memory raw, uint256 at) private pure returns (uint256 v) {
        require(at + 32 <= raw.length);
        assembly ("memory-safe") { v := mload(add(add(raw, 32), at)) }
    }

    function _refuses(bytes memory raw) private view {
        (bool ok,) = address(probe)
            .staticcall(abi.encodeCall(probe.fresh, (raw, _dependencies(), _evidence())));
        require(!ok);
    }

    function testOuterOffsetsTruncationAndOverflowRefuse() public view {
        bytes memory raw = abi.encode(_base());
        _put(raw, 0, 64);
        _refuses(raw);
        raw = abi.encode(_base());
        _put(raw, 256, 416);
        _refuses(raw);
        raw = abi.encode(_base());
        _put(raw, 288, type(uint256).max);
        _refuses(raw);
        raw = abi.encode(_base());
        assembly ("memory-safe") { mstore(raw, sub(mload(raw), 32)) }
        _refuses(raw);
    }

    function testNestedEnvironmentOffsetsScalarsAndPaddingRefuse() public view {
        bytes memory raw = abi.encode(_base());
        uint256 env = 32 + _word(raw, 288);
        _put(raw, env + 128, 800);
        _refuses(raw);
        raw = abi.encode(_base());
        _put(raw, env + 672, 2);
        _refuses(raw);
        raw = abi.encode(_base());
        _put(raw, env + 544, 65536);
        _refuses(raw);
        raw = abi.encode(_base());
        uint256 str = env + _word(raw, env + 128);
        uint256 len = _word(raw, str);
        raw[str + 32 + len] = bytes1(uint8(1));
        _refuses(raw);
    }

    function testPackageOffsetsCountSizeAndPaddingRefuse() public view {
        bytes memory original = abi.encode(_base());
        uint256 env = 32 + _word(original, 288);
        uint256 array = env + _word(original, env + 384);
        uint256 heads = array + 32;
        uint256 row = heads + _word(original, heads);
        bytes memory raw = abi.encode(_base());
        _put(raw, array, type(uint256).max);
        _refuses(raw);
        raw = abi.encode(_base());
        _put(raw, heads, 32);
        _refuses(raw);
        raw = abi.encode(_base());
        _put(raw, row, 128);
        _refuses(raw);
        raw = abi.encode(_base());
        _put(raw, row + 32, uint256(type(uint64).max) + 1);
        _refuses(raw);
        raw = abi.encode(_base());
        raw[row + 128 + 7] = bytes1(uint8(1));
        _refuses(raw);
    }

    function testOriginalMaximumPublicationAndOversizeCanonicalRefusal() public view {
        R.Publication memory p;
        uint256 empty = abi.encode(p).length;
        p.manifestURI = string(new bytes(524288 - empty));
        require(abi.encode(p).length == 524288);
        _compare(p);
        p.manifestURI = string(new bytes(524288 - empty + 32));
        require(abi.encode(p).length == 524320);
        _refuses(abi.encode(p));
    }

    function testPublicationUint64WidthsAndMisalignedEnvironmentRefuse() public view {
        uint256[3] memory at = [uint256(128), 192, 352];
        for (uint256 i; i < 3; ++i) {
            bytes memory raw = abi.encode(_base());
            _put(raw, at[i], uint256(type(uint64).max) + 1);
            _refuses(raw);
        }
        bytes memory raw = abi.encode(_base());
        _put(raw, 288, _word(raw, 288) + 1);
        _refuses(raw);
    }

    function testPlatformRowsAreFullyCheckedAndAssemblyErrorIsExact() public view {
        bytes memory raw = abi.encode(_base());
        uint256 env = 32 + _word(raw, 288);
        uint256 array = env + _word(raw, env + 416);
        uint256 heads = array + 32;
        uint256 row = heads + _word(raw, heads);
        _put(raw, row + 32, uint256(type(uint64).max) + 1);
        (bool ok, bytes memory reason) = address(probe)
            .staticcall(abi.encodeCall(probe.fresh, (raw, _dependencies(), _evidence())));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(M.InvalidModeEvidence.selector))
        );
        raw = abi.encode(_base());
        uint256 path = row + 96;
        uint256 size = _word(raw, path);
        raw[path + 32 + size] = bytes1(uint8(1));
        _refuses(raw);
    }
}
