// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityPolicyInventoryEvidenceV2 as Worker
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityPolicyInventoryEvidenceV2.sol";
import {
    StreamCurrentAuthorityPolicyInventoryGuardV2 as Guard
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityPolicyInventoryGuardV2.sol";
import {
    StreamPolicyRenderCriticalStateV2 as State
} from "../../../smart-contracts/domains/preservation/StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamMultiOriginInventoryState as Origins
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginInventoryState.sol";
import {
    StreamCurrentAuthorityInventorySelection as Authority
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityInventorySelection.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as C
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamConservationRecordSelection as Conservation
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamConservationRecordSelection.sol";

interface PolicyEvidenceVm {
    function etch(address target, bytes calldata code) external;
    function expectRevert(bytes calldata reason) external;
}

contract PolicyEvidenceReply {
    address private expectedHost;
    address private expectedCaller;
    bytes private expectedInput;
    bytes private output;
    bool private refuse;
    error GuardRefused(bytes32 reason);

    function configure(
        address host,
        address caller,
        bytes calldata input,
        bytes calldata result,
        bool reject
    ) external {
        expectedHost = host;
        expectedCaller = caller;
        expectedInput = input;
        output = result;
        refuse = reject;
    }

    function read(address host, address caller, bytes calldata input)
        external
        view
        returns (bytes memory)
    {
        require(msg.sender == expectedHost && host == expectedHost, "delegate host");
        require(caller == expectedCaller, "original caller");
        require(keccak256(input) == keccak256(expectedInput), "typed storage roots and id");
        if (refuse) revert GuardRefused(keccak256("full currentness refused"));
        return output;
    }
}

/// @dev Explicit typed full-currentness boundary, replacing only the fixed Guard during this test.
contract PolicyEvidenceGuardBoundary {
    PolicyEvidenceReply private immutable reply;

    constructor(PolicyEvidenceReply selected) {
        reply = selected;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        return reply.read(address(this), msg.sender, input);
    }
}

contract PolicyEvidenceHost {
    bytes32 private beforeRoot = keccak256("before");
    State.State private a;
    Origins.State private oa;
    Authority.State private aa;
    bytes32 private betweenRoots = keccak256("between");
    State.State private b;
    Origins.State private ob;
    Authority.State private ab;
    bytes32 private afterRoot = keccak256("after");

    constructor() {
        a.records.dependencyHash = keccak256("a");
        b.records.dependencyHash = keccak256("b");
    }

    function read(bool second, bytes32 id) external view returns (T.Evidence memory) {
        if (second) return Worker.current(b, ob, ab, id);
        return Worker.current(a, oa, aa, id);
    }

    function guardInput(bool second, bytes32 id) external pure returns (bytes memory) {
        uint256 s;
        uint256 o;
        uint256 authority;
        if (second) {
            assembly ("memory-safe") {
                s := b.slot
                o := ob.slot
                authority := ab.slot
            }
        } else {
            assembly ("memory-safe") {
                s := a.slot
                o := oa.slot
                authority := aa.slot
            }
        }
        return abi.encodeWithSelector(Guard.requireCurrent.selector, s, o, authority, id);
    }

    function fingerprint() external view returns (bytes32) {
        return keccak256(
            abi.encode(
                beforeRoot,
                betweenRoots,
                afterRoot,
                a.records.dependencyHash,
                b.records.dependencyHash
            )
        );
    }
}

/// @notice Actual fixed Evidence worker, with a typed Guard reply; no source/authority admission claim.
contract StreamCurrentAuthorityPolicyInventoryEvidenceTest {
    PolicyEvidenceVm private constant vm =
        PolicyEvidenceVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testLiteralCompleteEvidenceBothKindsAndStorageRoots() public {
        (PolicyEvidenceHost host, PolicyEvidenceReply reply) = _fixture();
        bytes32 fingerprint = host.fingerprint();
        for (uint8 kind; kind < 2; ++kind) {
            for (uint256 root; root < 2; ++root) {
                uint64 seed = uint64(100 + root + kind);
                bytes32 id = _b(seed, 99);
                C.Context memory c = _context(seed, kind);
                reply.configure(
                    address(host),
                    address(this),
                    host.guardInput(root != 0, id),
                    abi.encode(c),
                    false
                );
                require(
                    keccak256(abi.encode(host.read(root != 0, id)))
                        == keccak256(_literal(seed, kind, id)),
                    "full literal tuple"
                );
                require(host.fingerprint() == fingerprint, "storage changed");
            }
        }
        require(
            keccak256(host.guardInput(false, 0)) != keccak256(host.guardInput(true, 0)),
            "distinct roots"
        );
    }

    function testFullGuardRefusalBubblesAndIdenticalRetry() public {
        (PolicyEvidenceHost host, PolicyEvidenceReply reply) = _fixture();
        bytes32 id = keccak256("same request");
        bytes memory input = host.guardInput(false, id);
        bytes memory result = abi.encode(_context(7, 1));
        bytes32 fingerprint = host.fingerprint();
        reply.configure(address(host), address(this), input, result, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                PolicyEvidenceReply.GuardRefused.selector, keccak256("full currentness refused")
            )
        );
        host.read(false, id);
        require(host.fingerprint() == fingerprint, "refusal changed state");
        reply.configure(address(host), address(this), input, result, false);
        require(keccak256(abi.encode(host.read(false, id))) == keccak256(_literal(7, 1, id)));
    }

    function testMalformedFullContextRefusesAndRestoresWithoutProjectionFallback() public {
        (PolicyEvidenceHost host, PolicyEvidenceReply reply) = _fixture();
        bytes32 id = keccak256("malformed");
        bytes memory input = host.guardInput(true, id);
        reply.configure(address(host), address(this), input, hex"00", false);
        (bool ok,) = address(host).staticcall(abi.encodeCall(host.read, (true, id)));
        require(!ok, "malformed full context accepted");
        reply.configure(address(host), address(this), input, abi.encode(_context(33, 2)), false);
        require(keccak256(abi.encode(host.read(true, id))) == keccak256(_literal(33, 2, id)));
    }

    function testFuzzFullPrecisionProjectionAndUnusedReceiptFields(
        uint64 seed,
        bytes32 id,
        bool waiver
    ) public {
        (PolicyEvidenceHost host, PolicyEvidenceReply reply) = _fixture();
        uint8 kind = waiver ? 1 : 0;
        C.Context memory c = _context(seed, kind);
        c.records.nativeHash = keccak256(abi.encode(seed, id));
        c.snapshot.sourceHash = keccak256("unused snapshot field");
        c.referenceSourceHash = keccak256("unused reference source");
        reply.configure(
            address(host), address(this), host.guardInput(true, id), abi.encode(c), false
        );
        require(keccak256(abi.encode(host.read(true, id))) == keccak256(_literal(seed, kind, id)));
    }

    function _fixture() private returns (PolicyEvidenceHost host, PolicyEvidenceReply reply) {
        host = new PolicyEvidenceHost();
        reply = new PolicyEvidenceReply();
        PolicyEvidenceGuardBoundary boundary = new PolicyEvidenceGuardBoundary(reply);
        vm.etch(address(Guard), address(boundary).code);
    }

    function _context(uint64 seed, uint8 kind) private pure returns (C.Context memory c) {
        c.records.collectionId = uint256(seed) + 1;
        c.records.subject = _b(seed, 2);
        c.records.artistId = _b(seed, 3);
        c.records.rootRecordHash = _b(seed, 4);
        c.snapshot.recordHash = _b(seed, 5);
        c.referenceRender.observation.recordHash = _b(seed, 6);
        c.records.conservation.record.kind = Conservation.RecordKind(kind);
        c.records.conservation.record.recordHash = _b(seed, 7);
        c.records.interviewEvidenceHash = _b(seed, 8);
        c.records.descriptions.rightsStatementRecordHash = _b(seed, 9);
        c.records.descriptions.workDescriptionRecordHash = _b(seed, 10);
        c.records.tokenInventoryHash = _b(seed, 11);
        c.records.tokenCount = seed;
    }

    // Independent literal 19-word wire tuple. Plan fields remain zero until the caller seals.
    function _literal(uint64 seed, uint8 kind, bytes32 id) private pure returns (bytes memory) {
        return abi.encode(
            id,
            uint256(seed) + 1,
            _b(seed, 2),
            _b(seed, 3),
            _b(seed, 4),
            _b(seed, 5),
            _b(seed, 6),
            kind == 0 ? _b(seed, 7) : bytes32(0),
            kind == 1 ? _b(seed, 7) : bytes32(0),
            _b(seed, 8),
            _b(seed, 9),
            _b(seed, 10),
            bytes32(0),
            _b(seed, 11),
            seed,
            uint64(0),
            uint64(0),
            bytes32(0),
            bytes32(0)
        );
    }

    function _b(uint64 seed, uint256 offset) private pure returns (bytes32) {
        return bytes32(uint256(seed) + offset);
    }
}
