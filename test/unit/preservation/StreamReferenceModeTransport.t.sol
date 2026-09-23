// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceModeStateReads as Reads
} from "../../../smart-contracts/domains/preservation/StreamReferenceModeStateReads.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol";

interface ModeTransportVm {
    function readFile(string calldata) external view returns (string memory);
    function parseJsonBytes(string calldata, string calldata) external pure returns (bytes memory);
}

contract ModeTransportProbe {
    mapping(uint256 => mapping(bytes32 => bool)) private ids;
    mapping(uint256 => bytes32[]) private history;
    mapping(uint256 => R.Lock) private locks;

    function used(uint256 cid, bytes32 id, bool value) external {
        ids[cid][id] = value;
    }

    function append(uint256 cid, bytes32 hash) external {
        history[cid].push(hash);
    }

    function lock(uint256 cid, bytes32 action) external {
        locks[cid].actionId = action;
    }

    function originalCandidate(R.Publication calldata p) external view {
        Reads.candidate(p, ids, history, locks);
    }

    function projectedCandidate(R.Publication calldata p) external view {
        Reads.candidateHeader(
            Reads.Candidate(
                p.collectionId,
                p.referenceId,
                p.reasonHash,
                p.effectiveAt,
                p.expectedRevision,
                p.expectedHead,
                p.manifestURI
            ),
            ids,
            history,
            locks
        );
    }

    function recordMemory(R.Publication memory p, R.Receipt memory r)
        external
        view
        returns (bytes memory)
    {
        return abi.encode(
            keccak256("6529STREAM_REFERENCE_MODE_RECORD_V1"),
            block.chainid,
            address(this),
            address(1),
            address(2),
            p,
            r
        );
    }

    function recordCalldata(R.Publication calldata p, R.Receipt memory r)
        external
        view
        returns (bytes memory)
    {
        return abi.encode(
            keccak256("6529STREAM_REFERENCE_MODE_RECORD_V1"),
            block.chainid,
            address(this),
            address(1),
            address(2),
            p,
            r
        );
    }

    function originalPair(R.Publication memory p, bytes calldata original)
        external
        pure
        returns (bytes memory)
    {
        (, M.Evidence memory evidence) = abi.decode(original[4:], (R.Publication, M.Evidence));
        return abi.encode(p, evidence);
    }

    function decodedPair(bytes calldata original) external pure returns (bytes memory) {
        (R.Publication memory p, M.Evidence memory evidence) =
            abi.decode(original[4:], (R.Publication, M.Evidence));
        return abi.encode(p, evidence);
    }
}

/// @notice Transport/candidate parity only; actual publisher source/authority and gas acceptance is separate.
contract StreamReferenceModeTransportTest {
    ModeTransportVm private constant vm =
        ModeTransportVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    ModeTransportProbe private probe;
    event log_named_uint(string key, uint256 value);

    function setUp() public {
        probe = new ModeTransportProbe();
    }

    function _base() private view returns (R.Publication memory p) {
        p.collectionId = 1;
        p.referenceId = bytes32(uint256(1));
        p.reasonHash = bytes32(uint256(2));
        p.effectiveAt = uint64(block.timestamp);
    }

    function _compare(R.Publication memory p, bool success) private view {
        (bool a, bytes memory left) =
            address(probe).staticcall(abi.encodeCall(probe.originalCandidate, (p)));
        (bool b, bytes memory right) =
            address(probe).staticcall(abi.encodeCall(probe.projectedCandidate, (p)));
        require(
            a == success && a == b && keccak256(left) == keccak256(right),
            "candidate acceptance/error parity"
        );
    }

    function testCandidateOriginalErrorsAndOrdering() public {
        R.Publication memory p = _base();
        _compare(p, true);
        p.collectionId = 0;
        _compare(p, false);
        p.collectionId = 1;
        p.referenceId = 0;
        _compare(p, false);
        p.referenceId = bytes32(uint256(1));
        p.reasonHash = 0;
        _compare(p, false);
        p.reasonHash = bytes32(uint256(2));
        p.effectiveAt = uint64(block.timestamp + 1);
        _compare(p, false);
        p.effectiveAt = uint64(block.timestamp);
        p.expectedRevision = type(uint64).max;
        _compare(p, false);
        p.expectedRevision = 0;
        probe.used(1, p.referenceId, true);
        _compare(p, false);
        probe.used(1, p.referenceId, false);
        probe.append(1, bytes32(uint256(3)));
        _compare(p, false);
        p.expectedRevision = 1;
        p.expectedHead = bytes32(uint256(3));
        _compare(p, true);
        probe.lock(1, bytes32(uint256(4)));
        _compare(p, false);
        probe.lock(1, 0);
        p.manifestURI = "javascript:invalid";
        _compare(p, false);
    }

    function testFuzzHeaderFields(
        uint256 cid,
        bytes32 id,
        bytes32 reason,
        uint64 time,
        uint64 revision,
        bytes32 head
    ) public view {
        R.Publication memory p = _base();
        p.collectionId = cid;
        p.referenceId = id;
        p.reasonHash = reason;
        p.effectiveAt = time;
        p.expectedRevision = revision;
        p.expectedHead = head;
        (bool a, bytes memory left) =
            address(probe).staticcall(abi.encodeCall(probe.originalCandidate, (p)));
        (bool b, bytes memory right) =
            address(probe).staticcall(abi.encodeCall(probe.projectedCandidate, (p)));
        require(a == b && keccak256(left) == keccak256(right));
    }

    function testActual1048RowsHeaderGasAndOriginalTupleBytes() public {
        string memory fixture =
            vm.readFile("test/fixtures/preservation/reference-combined-native-v1.json");
        R.Publication memory p = _base();
        p.environment.packageFiles =
            abi.decode(vm.parseJsonBytes(fixture, ".packageFilesABI"), (R.PackageFile[]));
        p.environment.platformPrerequisites =
            abi.decode(vm.parseJsonBytes(fixture, ".platformPrerequisitesABI"), (R.PackageFile[]));
        bytes memory oldInput = abi.encodeCall(probe.originalCandidate, (p));
        bytes memory newInput = abi.encodeCall(probe.projectedCandidate, (p));
        uint256 before = gasleft();
        (bool a,) = address(probe).staticcall(oldInput);
        uint256 oldGas = before - gasleft();
        before = gasleft();
        (bool b,) = address(probe).staticcall(newInput);
        uint256 newGas = before - gasleft();
        require(a && b && newGas < oldGas);
        emit log_named_uint("originalCandidate", oldGas);
        emit log_named_uint("projectedCandidate", newGas);
        R.Receipt memory r;
        r.collectionId = 1;
        r.recorder = address(this);
        r.sourcesHash = bytes32(uint256(8));
        require(
            keccak256(probe.recordMemory(p, r)) == keccak256(probe.recordCalldata(p, r)),
            "exact original record preimage"
        );
        M.Evidence memory e;
        e.mode = M.Mode.PERCEPTUAL_TOLERANCE;
        e.perceptual.reportHash = bytes32(uint256(9));
        bytes memory original = abi.encodePacked(bytes4(keccak256("pair")), abi.encode(p, e));
        require(
            keccak256(probe.originalPair(p, original)) == keccak256(probe.decodedPair(original)),
            "same original complete tuple"
        );
    }
}
