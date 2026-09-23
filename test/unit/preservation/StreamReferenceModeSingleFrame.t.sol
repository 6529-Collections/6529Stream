// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceModeWritePreparation as Writer
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeWritePreparation.sol";
import {
    StreamReferenceModeStateReads as Legacy
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeStateReads.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    IStreamReferenceModePublication
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamReferenceModePublication.sol";

interface ModeSingleFrameVm {
    function readFile(string calldata) external view returns (string memory);
    function parseJsonBytes(string calldata, string calldata) external pure returns (bytes memory);
    function warp(uint256) external;
}

contract ModeSingleFrameProbe {
    function compare(bytes calldata input)
        external
        view
        returns (bytes32 expected, bytes32 actual, uint256, uint256)
    {
        (
            R.Dependencies memory d,
            R.Publication memory p,
            R.Receipt memory r,
            Writer.Prepared memory prepared
        ) = abi.decode(input, (R.Dependencies, R.Publication, R.Receipt, Writer.Prepared));
        R.Receipt memory completed = abi.decode(abi.encode(r), (R.Receipt));
        completed.sourcesHash = prepared.sourcesHash;
        completed.payloadHash = prepared.selected.payloadId == 0
            ? keccak256(prepared.canonical)
            : prepared.selected.payloadHash;
        completed.payloadBytes = prepared.selected.payloadId == 0
            ? uint32(prepared.canonical.length)
            : prepared.selected.payloadBytes;
        completed.recordedAt = uint64(block.timestamp);
        bytes memory publication = abi.encode(p);
        bytes memory initial = abi.encode(
            keccak256("6529STREAM_REFERENCE_MODE_RECORD_V1"),
            d.chainId,
            address(this),
            d.targets[0],
            d.targets[1],
            p,
            r
        );
        bytes memory literal = abi.encode(
            keccak256("6529STREAM_REFERENCE_MODE_RECORD_V1"),
            d.chainId,
            address(this),
            d.targets[0],
            d.targets[1],
            p,
            completed
        );
        bytes memory left =
            abi.encode(bytes32(uint256(0xaabb)), bytes32(type(uint256).max), keccak256(input));
        bytes32 leftHash = keccak256(left);
        bytes memory frame = Writer.recordFrame(d, p, r);
        bytes memory aliasFrame = frame;
        bytes memory right =
            abi.encode(keccak256(input), bytes32(uint256(0xccdd)), bytes32(type(uint256).max));
        bytes32 rightHash = keccak256(right);
        require(
            frame.length == initial.length && keccak256(frame) == keccak256(initial),
            "initial original frame"
        );
        for (uint256 i; i < 2; ++i) {
            (bytes32 hash, uint32 size) = Writer.framePublication(frame);
            require(
                hash == keccak256(publication) && size == publication.length,
                "original publication bytes"
            );
            require(keccak256(aliasFrame) == keccak256(initial), "temporary word not restored");
            require(
                keccak256(left) == leftHash && keccak256(right) == rightHash, "neighbor corruption"
            );
        }
        actual = Writer.completedFrameRecordHash(frame, r, prepared);
        expected = keccak256(literal);
        require(
            actual == expected && frame.length == literal.length
                && keccak256(aliasFrame) == expected,
            "literal complete frame"
        );
        M.Evidence memory evidence;
        bytes memory original =
            abi.encodeCall(IStreamReferenceModePublication.publishModeReference, (p, evidence));
        require(
            Legacy.recordHash(d.chainId, d.targets[0], d.targets[1], completed, original)
                == expected,
            "legacy record codec"
        );
        require(Writer.completedRecordHash(d, p, r, prepared) == expected, "prior decoded codec");
        for (uint256 i; i < 26; ++i) {
            bytes32 prior;
            bytes32 afterWord;
            assembly ("memory-safe") {
                prior := mload(add(add(initial, 32), mul(i, 32)))
                afterWord := mload(add(add(frame, 32), mul(i, 32)))
            }
            if (i != 12 && i != 13 && i != 14 && i != 21) {
                require(prior == afterWord, "unrelated head patch");
            }
        }
        (bytes32 finalPublication, uint32 finalSize) = Writer.framePublication(frame);
        require(
            finalPublication == keccak256(publication) && finalSize == publication.length,
            "patched publication tail"
        );
        require(
            keccak256(frame) == expected && keccak256(left) == leftHash
                && keccak256(right) == rightHash,
            "alias or canary changed"
        );
    }

    /// @dev Fresh identical decoded inputs; the measured sequence includes every encoding
    /// and hash needed for both commitments, not an operation after different allocations.
    function measure(bytes calldata input, bool useFrame)
        external
        view
        returns (bytes32 result, uint256 used, bytes32 publicationHash, uint32 publicationBytes)
    {
        (
            R.Dependencies memory d,
            R.Publication memory p,
            R.Receipt memory r,
            Writer.Prepared memory prepared
        ) = abi.decode(input, (R.Dependencies, R.Publication, R.Receipt, Writer.Prepared));
        uint256 before = gasleft();
        if (useFrame) {
            bytes memory frame = Writer.recordFrame(d, p, r);
            (publicationHash, publicationBytes) = Writer.framePublication(frame);
            result = Writer.completedFrameRecordHash(frame, r, prepared);
        } else {
            bytes memory encoded = abi.encode(p);
            publicationHash = keccak256(encoded);
            publicationBytes = uint32(encoded.length);
            result = Writer.completedEncodedRecordHash(d, encoded, r, prepared);
        }
        used = before - gasleft();
    }

    function frameCommitment(bytes calldata encoded) external pure returns (bytes32, uint32) {
        return Writer.framePublication(encoded);
    }
}

/// @notice Exact one-frame byte/restoration parity and bounded sequence cost, not full publisher acceptance.
contract StreamReferenceModeSingleFrameTest {
    ModeSingleFrameVm private constant vm =
        ModeSingleFrameVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ModeSingleFrameProbe private probe;
    event log_named_uint(string label, uint256 value);

    function setUp() public {
        probe = new ModeSingleFrameProbe();
        vm.warp(1234567);
    }

    function _publication(bool populated) private pure returns (R.Publication memory p) {
        p.collectionId = 7;
        p.referenceId = keccak256("id");
        p.expectedHead = keccak256("prior");
        p.expectedRevision = 3;
        p.snapshotRecordHash = keccak256("snapshot");
        p.snapshotRevision = 4;
        p.expectedSourcesHash = keccak256("source");
        p.effectiveAt = 123;
        p.reasonHash = keccak256("reason");
        p.captures = new R.Capture[](populated ? 2 : 0);
        p.environment.packageFiles = new R.PackageFile[](populated ? 2 : 0);
        p.environment.platformPrerequisites = new R.PackageFile[](populated ? 1 : 0);
        if (populated) {
            p.manifestURI = "ipfs://original";
            p.environment.engineName = "original engine";
            p.environment.engineVersion = "1";
            p.environment.toolchainName = "tool";
            p.environment.licenseNote = "unqualified original assertion";
            p.environment.packageFiles[0] = R.PackageFile("a", 1, keccak256("a"));
            p.environment.packageFiles[1] = R.PackageFile("b", 2, keccak256("b"));
            p.environment.platformPrerequisites[0] =
                R.PackageFile("C:/Windows/a.dll", 3, keccak256("c"));
            p.captures[0].animationHTML = hex"000180ff";
            p.captures[1].animationHTML = bytes("<canvas></canvas>");
            p.captures[0].tokenId = 200;
            p.captures[1].tokenId = 999;
        }
    }

    function _input(R.Publication memory p, R.Receipt memory receipt, bool selected)
        private
        view
        returns (bytes memory)
    {
        R.Dependencies memory d;
        d.chainId = block.chainid;
        d.targets[0] = address(0x1234);
        d.targets[1] = address(0x4567);
        Writer.Prepared memory prepared;
        prepared.sourcesHash = p.expectedSourcesHash;
        prepared.canonical = hex"0001ff807f";
        if (selected) {
            prepared.selected.payloadId = keccak256("actual selection");
            prepared.selected.payloadHash = keccak256("original payload");
            prepared.selected.payloadBytes = 443648;
        }
        return abi.encode(d, p, receipt, prepared);
    }

    function testEmptyAndNonemptyOriginalPublicationBothRetentionBranches() public view {
        R.Receipt memory r;
        for (uint256 i; i < 4; ++i) {
            probe.compare(_input(_publication(i % 2 == 1), r, i >= 2));
        }
    }

    function testEveryReceiptWordMatchesOriginalCompletion() public view {
        R.Receipt memory r;
        bytes memory raw = abi.encode(r);
        R.Publication memory p = _publication(true);
        (bytes32 baseline,,,) = probe.compare(_input(p, r, true));
        for (uint256 i; i < 20; ++i) {
            // All selected values fit every original narrow uint/address field.
            assembly ("memory-safe") { mstore(add(add(raw, 32), mul(i, 32)), add(i, 1)) }
            R.Receipt memory changed = abi.decode(raw, (R.Receipt));
            (bytes32 actual,,,) = probe.compare(_input(p, changed, true));
            bool completed = i == 6 || i == 7 || i == 8 || i == 15;
            require(
                completed ? actual == baseline : actual != baseline,
                "receipt word omitted or spuriously retained"
            );
            assembly ("memory-safe") { mstore(add(add(raw, 32), mul(i, 32)), 0) }
        }
    }

    function testActual1048MemberCorpusEliminatesSecondFullAllocation() public {
        R.Publication memory p = _publication(true);
        string memory fixture =
            vm.readFile("test/fixtures/preservation/reference-combined-native-v1.json");
        p.environment.packageFiles =
            abi.decode(vm.parseJsonBytes(fixture, ".packageFilesABI"), (R.PackageFile[]));
        p.environment.platformPrerequisites =
            abi.decode(vm.parseJsonBytes(fixture, ".platformPrerequisitesABI"), (R.PackageFile[]));
        require(
            p.environment.packageFiles.length == 1048
                && p.environment.platformPrerequisites.length == 102
        );
        R.Receipt memory r;
        bytes memory input = _input(p, r, true);
        probe.compare(input);
        (bytes32 oldHash, uint256 oldGas, bytes32 oldPublication, uint32 oldSize) =
            probe.measure(input, false);
        (bytes32 newHash, uint256 newGas, bytes32 newPublication, uint32 newSize) =
            probe.measure(input, true);
        require(
            oldHash == newHash && oldPublication == newPublication && oldSize == newSize,
            "different measured inputs"
        );
        emit log_named_uint("freshFrameTwoAllocationCommitmentSequenceGas", oldGas);
        emit log_named_uint("freshFrameOneAllocationCommitmentSequenceGas", newGas);
        require(newGas < oldGas, "no measured copy reduction");
    }

    function testFuzzOriginalPreimageBytesAndReceiptFields(
        bytes calldata data,
        bytes32 seed,
        uint64 revision,
        bool selected
    ) public view {
        if (data.length > 4096) return;
        R.Publication memory p = _publication(true);
        p.manifestURI = string(data);
        p.captures[0].animationHTML = data;
        p.environment.licenseNote = string(data);
        p.environment.packageFiles[0].sha256Digest = seed;
        p.expectedRevision = revision;
        p.expectedSourcesHash = seed;
        R.Receipt memory r;
        r.recordHash = seed;
        r.recordChainHash = keccak256(abi.encode(seed));
        r.collectionId = uint256(seed);
        r.referenceId = seed;
        r.predecessor = seed;
        r.revision = revision;
        r.payloadHash = seed;
        r.payloadBytes = uint32(revision);
        r.sourcesHash = seed;
        r.snapshotRecordHash = seed;
        r.snapshotRevision = revision;
        r.recorder = address(uint160(uint256(seed)));
        r.authorizationClass = uint8(revision);
        r.grantRevision = revision;
        r.effectiveAt = revision;
        r.recordedAt = revision;
        r.reasonHash = seed;
        r.schemaHash = seed;
        r.profileHash = seed;
        r.canonicalizationHash = seed;
        probe.compare(_input(p, r, selected));
    }

    function testFullDomainAndCompletedFieldMutationsChangeOriginalHash() public view {
        R.Receipt memory r;
        bytes memory input = _input(_publication(true), r, true);
        (bytes32 original,,,) = probe.compare(input);
        (
            R.Dependencies memory d,
            R.Publication memory p,
            R.Receipt memory receipt,
            Writer.Prepared memory prepared
        ) = abi.decode(input, (R.Dependencies, R.Publication, R.Receipt, Writer.Prepared));
        d.chainId += 1;
        (bytes32 changed,,,) = probe.compare(abi.encode(d, p, receipt, prepared));
        require(changed != original);
        d.chainId -= 1;
        d.targets[0] = address(0x11);
        (changed,,,) = probe.compare(abi.encode(d, p, receipt, prepared));
        require(changed != original);
        d.targets[0] = address(0x1234);
        d.targets[1] = address(0x22);
        (changed,,,) = probe.compare(abi.encode(d, p, receipt, prepared));
        require(changed != original);
        d.targets[1] = address(0x4567);
        prepared.sourcesHash = keccak256("different source");
        (changed,,,) = probe.compare(abi.encode(d, p, receipt, prepared));
        require(changed != original);
        prepared.sourcesHash = p.expectedSourcesHash;
        prepared.selected.payloadHash = keccak256("different payload");
        (changed,,,) = probe.compare(abi.encode(d, p, receipt, prepared));
        require(changed != original);
        prepared.selected.payloadHash = keccak256("original payload");
        prepared.selected.payloadBytes += 1;
        (changed,,,) = probe.compare(abi.encode(d, p, receipt, prepared));
        require(changed != original);
    }

    function _reject(bytes memory encoded) private view {
        (bool ok, bytes memory reason) =
            address(probe).staticcall(abi.encodeCall(probe.frameCommitment, (encoded)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(M.InvalidModeEvidence.selector))
        );
    }

    function testRejectsMalformedFrameOffsetsBeforeTemporaryWrite() public view {
        R.Dependencies memory d;
        R.Receipt memory r;
        bytes memory encoded = Writer.recordFrame(d, _publication(true), r);
        uint256[5] memory offsets =
            [uint256(0), uint256(31), uint256(64), uint256(864), type(uint256).max];
        for (uint256 i; i < offsets.length; ++i) {
            uint256 offset = offsets[i];
            assembly ("memory-safe") { mstore(add(encoded, 192), offset) }
            _reject(encoded);
        }
    }

    function testRejectsTruncatedUnalignedAndOversizeFrame() public view {
        uint256[9] memory lengths = [
            uint256(0),
            uint256(31),
            uint256(32),
            uint256(1184),
            uint256(1215),
            uint256(1217),
            uint256(525087),
            uint256(525089),
            uint256(525120)
        ];
        for (uint256 i; i < lengths.length; ++i) {
            bytes memory encoded = new bytes(lengths[i]);
            if (encoded.length >= 192) {
                assembly ("memory-safe") { mstore(add(encoded, 192), 832) }
            }
            _reject(encoded);
        }
    }

    function testMaximumCanonicalPublicationBoundKeepsExactOriginalBytes() public view {
        R.Publication memory p = _publication(false);
        uint256 base = abi.encode(p).length;
        p.manifestURI = string(new bytes(524288 - base));
        require(abi.encode(p).length == 524288);
        R.Receipt memory r;
        probe.compare(_input(p, r, true));
    }
}
