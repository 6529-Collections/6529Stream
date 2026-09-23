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

interface ModeEncodedRecordVm {
    function readFile(string calldata) external view returns (string memory);
    function parseJsonBytes(string calldata, string calldata) external pure returns (bytes memory);
    function warp(uint256) external;
}

contract ModeEncodedRecordPreimageProbe {
    function compare(bytes calldata input)
        external
        view
        returns (bytes32 expected, bytes32 actual, uint256 oldGas, uint256 newGas)
    {
        (
            R.Dependencies memory d,
            R.Publication memory p,
            R.Receipt memory r,
            Writer.Prepared memory prepared
        ) = abi.decode(input, (R.Dependencies, R.Publication, R.Receipt, Writer.Prepared));
        // Independent original host completion, before calling the unchanged old codec.
        R.Receipt memory completed = abi.decode(abi.encode(r), (R.Receipt));
        completed.sourcesHash = prepared.sourcesHash;
        completed.payloadHash = prepared.selected.payloadId == 0
            ? keccak256(prepared.canonical)
            : prepared.selected.payloadHash;
        completed.payloadBytes = prepared.selected.payloadId == 0
            ? uint32(prepared.canonical.length)
            : prepared.selected.payloadBytes;
        completed.recordedAt = uint64(block.timestamp);
        bytes memory literalBytes = abi.encode(
            keccak256("6529STREAM_REFERENCE_MODE_RECORD_V1"),
            d.chainId,
            address(this),
            d.targets[0],
            d.targets[1],
            p,
            completed
        );
        bytes32 literal = keccak256(literalBytes);
        M.Evidence memory evidence;
        bytes memory original =
            abi.encodeCall(IStreamReferenceModePublication.publishModeReference, (p, evidence));
        require(
            Legacy.recordHash(d.chainId, d.targets[0], d.targets[1], completed, original) == literal
        );
        // This encoding already exists in the real Writer before either measured operation.
        bytes memory encoded = abi.encode(p);
        bytes32 originalEncoding = keccak256(encoded);
        uint256 before = gasleft();
        expected = Writer.completedRecordHash(d, p, r, prepared);
        oldGas = before - gasleft();
        before = gasleft();
        actual = Writer.completedEncodedRecordHash(d, encoded, r, prepared);
        newGas = before - gasleft();
        require(expected == literal && actual == literal, "original record preimage mismatch");
        bytes memory actualBytes = Writer.recordPreimageEncoded(d, encoded, completed);
        require(actualBytes.length == literalBytes.length && keccak256(actualBytes) == literal);
        require(keccak256(encoded) == originalEncoding, "source bytes mutated");
    }

    /// @dev Each call starts a fresh memory frame with the identical common decoded input
    /// and canonical Publication encoding. Returning its digest prevents unused-code removal.
    /// No external calls occur within either measured internal hash operation.
    function measure(bytes calldata input, bool useEncoded)
        external
        view
        returns (bytes32 result, uint256 used, bytes32 publicationHash)
    {
        (
            R.Dependencies memory d,
            R.Publication memory p,
            R.Receipt memory r,
            Writer.Prepared memory prepared
        ) = abi.decode(input, (R.Dependencies, R.Publication, R.Receipt, Writer.Prepared));
        bytes memory encoded = abi.encode(p);
        publicationHash = keccak256(encoded);
        uint256 before = gasleft();
        if (useEncoded) result = Writer.completedEncodedRecordHash(d, encoded, r, prepared);
        else result = Writer.completedRecordHash(d, p, r, prepared);
        used = before - gasleft();
    }

    function encodedPreimage(bytes calldata encoded) external view returns (bytes memory) {
        R.Dependencies memory d;
        R.Receipt memory r;
        return Writer.recordPreimageEncoded(d, encoded, r);
    }
}

/// @notice Exact legacy-byte parity and isolated avoided-encoding cost, not full publisher acceptance.
contract StreamReferenceModeEncodedPreimageTest {
    ModeEncodedRecordVm private constant vm =
        ModeEncodedRecordVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ModeEncodedRecordPreimageProbe private probe;
    event log_named_uint(string label, uint256 value);

    function setUp() public {
        probe = new ModeEncodedRecordPreimageProbe();
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

    function testActual1048MemberCorpusReusesCanonicalBytes() public {
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
        (bytes32 oldHash, uint256 oldGas, bytes32 oldPublication) = probe.measure(input, false);
        (bytes32 newHash, uint256 newGas, bytes32 newPublication) = probe.measure(input, true);
        require(oldHash == newHash && oldPublication == newPublication, "different measured inputs");
        emit log_named_uint("freshFrameOldDecodedPublicationReencodingGas", oldGas);
        emit log_named_uint("freshFrameExistingCanonicalPublicationCopyGas", newGas);
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
            address(probe).staticcall(abi.encodeCall(probe.encodedPreimage, (encoded)));
        require(
            !ok
                && keccak256(reason)
                    == keccak256(abi.encodeWithSelector(M.InvalidModeEvidence.selector))
        );
    }

    function testRejectsMalformedOuterOffsetsBeforeCopy() public view {
        bytes memory encoded = abi.encode(_publication(true));
        uint256[5] memory offsets =
            [uint256(0), uint256(31), uint256(64), uint256(832), type(uint256).max];
        for (uint256 i; i < offsets.length; ++i) {
            uint256 offset = offsets[i];
            assembly ("memory-safe") { mstore(add(encoded, 32), offset) }
            _reject(encoded);
        }
    }

    function testRejectsTruncatedUnalignedAndOversizeEnvelope() public view {
        uint256[9] memory lengths = [
            uint256(0),
            uint256(31),
            uint256(32),
            uint256(384),
            uint256(415),
            uint256(417),
            uint256(524287),
            uint256(524289),
            uint256(524320)
        ];
        for (uint256 i; i < lengths.length; ++i) {
            bytes memory encoded = new bytes(lengths[i]);
            if (encoded.length >= 32) {
                assembly ("memory-safe") { mstore(add(encoded, 32), 32) }
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
