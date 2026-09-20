// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceModeInput as Input
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeInput.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import { ReferenceModeOriginalEncoding as Original } from "./ReferenceModeOriginalEncoding.sol";

interface ModeProjectionVm {
    function readFile(string calldata) external view returns (string memory);
    function parseJsonBytes(string calldata, string calldata) external pure returns (bytes memory);
}

contract ModeProjectionProbe {
    function encodeOriginal(bytes calldata input, bytes memory environment)
        external
        view
        returns (bytes32 context, bytes memory canonical)
    {
        (
            R.Dependencies memory d,
            R.Publication memory p,
            R.Receipt memory r,
            R.SourceFacts memory source,
            M.Evidence memory e,
            M.Facts memory f
        ) = abi.decode(
            input, (R.Dependencies, R.Publication, R.Receipt, R.SourceFacts, M.Evidence, M.Facts)
        );
        context = Original.contextHash(d, p);
        canonical = Original.payload(p, r, source, e, f, environment);
    }

    function encodeProjected(bytes calldata input, bytes memory environment)
        external
        view
        returns (bytes32 context, bytes memory canonical)
    {
        (
            R.Dependencies memory d,
            R.Publication memory p,
            R.Receipt memory r,
            R.SourceFacts memory source,
            M.Evidence memory e,
            M.Facts memory f
        ) = abi.decode(
            input, (R.Dependencies, R.Publication, R.Receipt, R.SourceFacts, M.Evidence, M.Facts)
        );
        context = Input.contextHash(d, p);
        Input.EvidenceInput memory projected = Input.project(p, context);
        require(projected.collectionId == p.collectionId && projected.effectiveAt == p.effectiveAt);
        require(projected.contextHash == context && projected.captures.length == p.captures.length);
        for (uint256 i; i < p.captures.length; ++i) {
            require(projected.captures[i].capturedAt == p.captures[i].capturedAt);
            require(projected.captures[i].repeatSha256 == p.captures[i].repeatCaptureSha256[1]);
        }
        canonical = Input.payload(p, r, source, e, f, environment);
    }
}

/// @notice Exact formatter/context/transport parity, not live-source or whole-publisher capacity proof.
contract StreamReferenceModeProjectionTest {
    ModeProjectionVm private constant vm =
        ModeProjectionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ModeProjectionProbe private probe;
    event log_named_uint(string key, uint256 value);

    function setUp() public {
        probe = new ModeProjectionProbe();
    }

    function _input(R.Publication memory p) private view returns (bytes memory) {
        R.Dependencies memory d;
        d.chainId = block.chainid;
        d.targets[0] = address(this);
        d.codeHashes[0] = keccak256("original pinned dependency");
        R.Receipt memory r;
        r.recordHash = bytes32(uint256(1));
        r.recordChainHash = bytes32(uint256(2));
        r.payloadHash = bytes32(uint256(3));
        r.payloadBytes = 777;
        r.recordedAt = 888;
        r.collectionId = p.collectionId;
        r.effectiveAt = p.effectiveAt;
        R.SourceFacts memory source;
        source.subject = keccak256("exact source subject");
        M.Evidence memory e;
        e.mode = M.Mode.PERCEPTUAL_TOLERANCE;
        e.perceptual.reportHash = keccak256("same report");
        M.Facts memory f;
        f.mode = M.Mode.PERCEPTUAL_TOLERANCE;
        f.evidenceHash = keccak256(abi.encode(e));
        return abi.encode(d, p, r, source, e, f);
    }

    function _base(bytes memory environment) private pure returns (R.Publication memory p) {
        p.collectionId = 17;
        p.referenceId = keccak256("reference");
        p.snapshotRecordHash = keccak256("snapshot");
        p.snapshotRevision = 3;
        p.effectiveAt = 99;
        p.environment.manifestHash = keccak256(environment);
        p.environment.manifestBytes = uint32(environment.length);
        p.captures = new R.Capture[](2);
        for (uint256 i; i < 2; ++i) {
            p.captures[i].tokenId = i + 1;
            p.captures[i].capturedAt = uint64(70 + i);
            p.captures[i].repeatCaptureSha256[1] = keccak256(abi.encode(i));
            p.captures[i].environmentManifestHash = p.environment.manifestHash;
        }
    }

    function _compare(R.Publication memory p, bytes memory environment, bool expected)
        private
        view
        returns (bytes32 context)
    {
        bytes memory input = _input(p);
        (bool a, bytes memory left) =
            address(probe).staticcall(abi.encodeCall(probe.encodeOriginal, (input, environment)));
        (bool b, bytes memory right) =
            address(probe).staticcall(abi.encodeCall(probe.encodeProjected, (input, environment)));
        require(
            a == expected && a == b && keccak256(left) == keccak256(right),
            "original byte/error parity"
        );
        if (a) (context,) = abi.decode(left, (bytes32, bytes));
    }

    function testFuzzOriginalContextAndPayload(bytes calldata raw, bytes32 seed, uint64 time)
        public
        view
    {
        bytes memory environment = raw.length > 4096 ? raw[:4096] : raw;
        R.Publication memory p = _base(environment);
        p.environment.engineName = string(raw);
        p.reasonHash = seed;
        p.effectiveAt = time;
        p.captures[0].repeatCaptureSha256[1] = seed;
        p.captures[1].capturedAt = time;
        _compare(p, environment, true);
    }

    function testOriginalPayloadFailuresAndNormalizedReceipt() public view {
        bytes memory environment = bytes("retained original canonical bytes");
        R.Publication memory p = _base(environment);
        _compare(p, environment, true);
        p.environment.manifestBytes += 1;
        _compare(p, environment, false);
        p.environment.manifestHash = 0;
        _compare(p, environment, false);
        p = _base(environment);
        p.captures[1].environmentManifestHash = 0;
        _compare(p, environment, false);
        environment = new bytes(524288);
        p = _base(environment);
        _compare(p, environment, false);
    }

    function testContextStillCommitsOmittedWorkerFields() public view {
        bytes memory environment = bytes("same retained environment");
        R.Publication memory p = _base(environment);
        bytes32 before = _compare(p, environment, true);
        p.environment.packageFiles = new R.PackageFile[](1);
        p.environment.packageFiles[0] = R.PackageFile("runtime/python.exe", 42, keccak256("python"));
        bytes32 afterFile = _compare(p, environment, true);
        require(before != afterFile, "full environment remains in context");
        p.captures[0].animationHTML = bytes("original full HTML is still committed");
        require(_compare(p, environment, true) != afterFile, "full capture remains in context");
    }

    function testActual1048RowsAvoidRepeatedFullTupleEncoding() public {
        string memory fixture =
            vm.readFile("test/fixtures/preservation/reference-combined-native-v1.json");
        // This transport stress vector uses the actual retained inventories and exact measured
        // canonical byte length. Zero-filled bytes are not claimed to be an admitted environment.
        bytes memory environment = new bytes(179418);
        R.Publication memory p = _base(environment);
        p.environment.packageFiles =
            abi.decode(vm.parseJsonBytes(fixture, ".packageFilesABI"), (R.PackageFile[]));
        p.environment.platformPrerequisites =
            abi.decode(vm.parseJsonBytes(fixture, ".platformPrerequisitesABI"), (R.PackageFile[]));
        require(
            p.environment.packageFiles.length == 1048
                && p.environment.platformPrerequisites.length == 102
        );
        bytes memory input = _input(p);
        uint256 before = gasleft();
        (bytes32 oldContext, bytes memory oldPayload) = probe.encodeOriginal(input, environment);
        uint256 oldGas = before - gasleft();
        before = gasleft();
        (bytes32 newContext, bytes memory newPayload) = probe.encodeProjected(input, environment);
        uint256 newGas = before - gasleft();
        require(oldContext == newContext && keccak256(oldPayload) == keccak256(newPayload));
        require(newGas < oldGas, "removed full tuple transport must save gas");
        emit log_named_uint("originalFormatterTransport", oldGas);
        emit log_named_uint("projectedFormatterTransport", newGas);
        emit log_named_uint("exactPayloadBytes", newPayload.length);
    }
}
