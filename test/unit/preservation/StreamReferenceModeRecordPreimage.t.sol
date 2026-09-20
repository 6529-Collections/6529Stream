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

interface ModeRecordVm {
    function readFile(string calldata) external view returns (string memory);
    function parseJsonBytes(string calldata, string calldata) external pure returns (bytes memory);
    function warp(uint256) external;
}

contract ModeRecordPreimageProbe {
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
        bytes32 literal = keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_MODE_RECORD_V1"),
                d.chainId,
                address(this),
                d.targets[0],
                d.targets[1],
                p,
                completed
            )
        );
        M.Evidence memory evidence;
        bytes memory original =
            abi.encodeCall(IStreamReferenceModePublication.publishModeReference, (p, evidence));
        uint256 before = gasleft();
        expected = Legacy.recordHash(d.chainId, d.targets[0], d.targets[1], completed, original);
        oldGas = before - gasleft();
        before = gasleft();
        actual = Writer.completedRecordHash(d, p, r, prepared);
        newGas = before - gasleft();
        require(expected == literal && actual == literal, "original record preimage mismatch");
    }
}

/// @notice Literal original hash/codec parity and isolated eliminated-copy cost, not publisher acceptance.
contract StreamReferenceModeRecordPreimageTest {
    ModeRecordVm private constant vm =
        ModeRecordVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ModeRecordPreimageProbe private probe;
    event log_named_uint(string label, uint256 value);

    function setUp() public {
        probe = new ModeRecordPreimageProbe();
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

    function testActual1048MemberCorpusEliminatesRedundantDecodeCost() public {
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
        (,, uint256 oldGas, uint256 newGas) = probe.compare(_input(p, r, true));
        emit log_named_uint("oldRepeatedRecordCodecGas", oldGas);
        emit log_named_uint("alreadyDecodedRecordHashGas", newGas);
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
}
