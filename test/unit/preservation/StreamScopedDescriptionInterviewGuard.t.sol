// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPolicyRenderCriticalDescriptionStagesV2 as Description
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalDescriptionStagesV2.sol";
import {
    StreamScopedPolicyRenderCriticalInterviewStageV2 as Interview
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalInterviewStageV2.sol";
import {
    StreamScopedPolicyRenderCriticalStateV2 as State
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalStateV2.sol";
import {
    StreamScopedPolicyRenderCriticalSourceReadsV2 as Sources
} from "../../../smart-contracts/domains/preservation/StreamScopedPolicyRenderCriticalSourceReadsV2.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamWorkRecordTypes as W
} from "../../../smart-contracts/interfaces/stream/metadata/StreamWorkRecordTypes.sol";
import {
    StreamRightsRecordTypes as R
} from "../../../smart-contracts/interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import {
    StreamConservationRecordTypes as C
} from "../../../smart-contracts/interfaces/stream/metadata/StreamConservationRecordTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface ScopedDescriptionInterviewVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function expectRevert(bytes calldata data) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Actual original host layout, stage guard and append code. Only the complete
/// Sources.current reply is mocked; this is not a full admitted scoped source graph.
contract ScopedDescriptionInterviewHarness {
    bytes32 public beforeCanary = keccak256("before scoped state");
    State.State private state;
    bytes32 public afterCanary = keccak256("after scoped state");

    function seed(
        S.Dependencies memory d,
        bytes32 dependencyHash,
        Scoped.Context memory c,
        bytes32 id,
        uint16 phase
    ) external {
        state.dependencies = d;
        state.dependencyHash = dependencyHash;
        state.contexts[id] = c;
        state.plans[id].scope = c.scope;
        state.plans[id].progress.collectionId = c.scope.collectionId;
        state.plans[id].progress.completedStages = phase;
    }

    function phase(bytes32 id, uint16 value) external {
        state.plans[id].progress.completedStages = value;
    }

    function completed(bytes32 id, bytes32 value) external {
        state.plans[id].progress.renderCriticalEvidenceHash = value;
    }

    function count(bytes32 id, uint64 value) external {
        state.plans[id].progress.segmentCount = value;
    }

    function progress(bytes32 id) external view returns (T.Plan memory) {
        return state.plans[id].progress;
    }

    function segment(bytes32 id, uint64 index) external view returns (T.Segment memory) {
        return state.segments[id][index];
    }

    function work(bytes calldata input) external {
        Description.appendWork(state, input);
    }

    function rights(bytes calldata input) external {
        Description.appendRights(state, input);
    }

    function interview(bytes calldata input) external {
        Interview.appendInterview(state, input);
    }

    function waiver(bytes32 id) external {
        Interview.appendInterviewWaiver(state, id);
    }
}

contract StreamScopedDescriptionInterviewGuardTest {
    ScopedDescriptionInterviewVm private constant vm =
        ScopedDescriptionInterviewVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant DEPENDENCY = keccak256("original constructor dependencies");

    function _context(uint8 kind) private pure returns (Scoped.Context memory c) {
        c.scope = StreamFinalityScope(
            StreamFinalityScopeType(kind),
            17,
            kind == 1 ? 301 : 0,
            kind == 1 ? bytes32(0) : keccak256("scope")
        );
        c.subject = keccak256("complete scoped subject");
        c.artistId = keccak256("actual typed artist");
        c.interviewEvidenceHash = keccak256("original explicit waiver evidence");
        c.conservation.interviewStatus = C.InterviewStatus.WAIVED;
        c.conservation.record.recordHash = keccak256("original conservation record");
        c.tokenCount = 3;
    }

    function _dependencies() private view returns (S.Dependencies memory d) {
        d.chainId = block.chainid;
        d.targets[1] = address(0x1234);
        d.readGas = 250_000;
        d.sourceGas = 1_000_000;
    }

    function _id(address host, Scoped.Context memory c) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_PLAN_V2"),
                block.chainid,
                host,
                DEPENDENCY,
                c
            )
        );
    }

    function _reply(Scoped.Context memory c) private {
        vm.mockCall(
            address(Sources),
            abi.encodeWithSelector(Sources.current.selector, _dependencies(), c.scope),
            abi.encode(c)
        );
    }

    function _seed(Scoped.Context memory c, uint16 phase)
        private
        returns (ScopedDescriptionInterviewHarness h, bytes32 id)
    {
        h = new ScopedDescriptionInterviewHarness();
        id = _id(address(h), c);
        h.seed(_dependencies(), DEPENDENCY, c, id, phase);
        _reply(c);
    }

    function _work(bytes32 id) private pure returns (bytes memory) {
        W.Description memory witness;
        return abi.encodePacked(bytes4(0x01020304), abi.encode(id, witness, address(0)));
    }

    function _rights(bytes32 id) private pure returns (bytes memory) {
        R.Statement memory witness;
        return abi.encodePacked(bytes4(0x05060708), abi.encode(id, witness));
    }

    function _interview(bytes32 id) private pure returns (bytes memory) {
        C.Interview memory witness;
        return abi.encodePacked(bytes4(0x090a0b0c), abi.encode(id, witness, address(0)));
    }

    function _unchanged(ScopedDescriptionInterviewHarness h, bytes32 id, uint16 phase)
        private
        view
    {
        T.Plan memory p = h.progress(id);
        require(
            p.completedStages == phase && p.segmentCount == 0 && p.itemCount == 0
                && p.segmentChainHash == 0,
            "unexpected write"
        );
        require(
            h.beforeCanary() == keccak256("before scoped state")
                && h.afterCanary() == keccak256("after scoped state"),
            "storage canary"
        );
    }

    function testAllFourEntriesRejectWrongStageBeforeAnySourceRead() external {
        ScopedDescriptionInterviewHarness h = new ScopedDescriptionInterviewHarness();
        bytes32 id = keccak256("uninitialized");
        bytes memory w = _work(id);
        bytes memory r = _rights(id);
        bytes memory i = _interview(id);
        vm.expectRevert(abi.encodeWithSelector(T.InventoryIncomplete.selector));
        h.work(w);
        vm.expectRevert(abi.encodeWithSelector(T.InventoryIncomplete.selector));
        h.rights(r);
        vm.expectRevert(abi.encodeWithSelector(T.InventoryIncomplete.selector));
        h.interview(i);
        vm.expectRevert(abi.encodeWithSelector(T.InventoryIncomplete.selector));
        h.waiver(id);
        _unchanged(h, id, 0);
    }

    function testOriginalDecodersStillRunBeforeGuard() external {
        ScopedDescriptionInterviewHarness h = new ScopedDescriptionInterviewHarness();
        (bool ok, bytes memory reason) = address(h).call(abi.encodeCall(h.work, (hex"01020304")));
        require(!ok && reason.length == 0, "work decoder order");
        (ok, reason) = address(h).call(abi.encodeCall(h.rights, (hex"01020304")));
        require(!ok && reason.length == 0, "rights decoder order");
        (ok, reason) = address(h).call(abi.encodeCall(h.interview, (hex"01020304")));
        require(!ok && reason.length == 0, "interview decoder order");
    }

    function testAllFourEntriesRecheckFullCurrentContextBeforeWitnesses() external {
        Scoped.Context memory c = _context(2);
        (ScopedDescriptionInterviewHarness h, bytes32 id) = _seed(c, 2);
        // Independent copy: the saved request remains intact for exact restoration.
        Scoped.Context memory changed = abi.decode(abi.encode(c), (Scoped.Context));
        changed.selectionHash = keccak256("changed current selection");
        _reply(changed);
        bytes memory w = _work(id);
        bytes memory r = _rights(id);
        bytes memory i = _interview(id);
        vm.expectRevert(abi.encodeWithSelector(T.InventorySourceChanged.selector));
        h.work(w);
        _unchanged(h, id, 2);
        h.phase(id, 3);
        vm.expectRevert(abi.encodeWithSelector(T.InventorySourceChanged.selector));
        h.rights(r);
        _unchanged(h, id, 3);
        h.phase(id, 5);
        vm.expectRevert(abi.encodeWithSelector(T.InventorySourceChanged.selector));
        h.interview(i);
        vm.expectRevert(abi.encodeWithSelector(T.InventorySourceChanged.selector));
        h.waiver(id);
        _unchanged(h, id, 5);
        _reply(c);
        // Correct currentness reaches the unchanged PRESENT predicate after the guard.
        vm.expectRevert(abi.encodeWithSelector(T.InvalidInventoryItem.selector));
        h.interview(i);
        h.waiver(id);
        require(h.progress(id).completedStages == 6, "same request retry");
    }

    function testWaiverLiteralItemSegmentEventAndTwoHostDomains() external {
        Scoped.Context memory c = _context(3);
        (ScopedDescriptionInterviewHarness a, bytes32 aId) = _seed(c, 5);
        (ScopedDescriptionInterviewHarness b, bytes32 bId) = _seed(c, 5);
        require(aId != bId, "host not in domain");
        _waiver(a, aId, c);
        _unchanged(b, bId, 5);
        _waiver(b, bId, c);
    }

    function _waiver(ScopedDescriptionInterviewHarness h, bytes32 id, Scoped.Context memory c)
        private
    {
        T.Item[] memory rows = new T.Item[](1);
        rows[0].kind = T.Kind.ABSENT;
        rows[0].role = keccak256("INTERVIEW_ORIGINAL_EXPLICITLY_WAIVED");
        rows[0].source = address(0x1234);
        rows[0].sourceRecord = c.conservation.record.recordHash;
        rows[0].provenanceHash = c.interviewEvidenceHash;
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_SEGMENT_V2"), id, uint64(0)
            )
        );
        bytes32 itemHash =
            keccak256(abi.encode(keccak256("6529STREAM_PRESERVATION_ITEM_V1"), rows[0]));
        bytes32 link = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_ITEM_LINK_V1"),
                key,
                uint64(1),
                uint64(0),
                itemHash,
                bytes32(0)
            )
        );
        T.Segment memory expected = T.Segment(key, 1, link, c.interviewEvidenceHash);
        bytes32 chain = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_SEGMENT_V1"), bytes32(0), uint64(0), expected
            )
        );
        vm.recordLogs();
        h.waiver(id);
        ScopedDescriptionInterviewVm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(h), "host event");
        require(
            logs[0].topics.length == 3 && logs[0].topics[1] == id && logs[0].topics[2] == 0,
            "event coordinates"
        );
        require(
            logs[0].topics[0]
                == keccak256(
                    "ScopedInventorySegmentRecorded(uint16,bytes32,uint64,(bytes32,uint64,bytes32,bytes32),(uint8,bytes32,address,bytes32,uint256,uint16,bytes32,bytes,string,uint64,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)[])"
                ),
            "event signature"
        );
        require(
            keccak256(logs[0].data) == keccak256(abi.encode(uint16(2), expected, rows)),
            "complete event bytes"
        );
        require(
            keccak256(abi.encode(h.segment(id, 0))) == keccak256(abi.encode(expected)),
            "stored segment"
        );
        T.Plan memory p = h.progress(id);
        require(
            p.completedStages == 6 && p.segmentCount == 1 && p.itemCount == 1
                && p.segmentChainHash == chain,
            "literal chain"
        );
        require(
            h.beforeCanary() == keccak256("before scoped state")
                && h.afterCanary() == keccak256("after scoped state"),
            "storage canary"
        );
    }

    function testLateCounterOverflowRollsBackSegmentThenIdenticalWaiverRetries() external {
        Scoped.Context memory c = _context(1);
        (ScopedDescriptionInterviewHarness h, bytes32 id) = _seed(c, 5);
        h.count(id, type(uint64).max);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
        h.waiver(id);
        require(h.segment(id, type(uint64).max).key == 0, "tentative segment survived");
        T.Plan memory p = h.progress(id);
        require(
            p.completedStages == 5 && p.segmentCount == type(uint64).max && p.segmentChainHash == 0
                && p.itemCount == 0,
            "late rollback"
        );
        h.count(id, 0);
        _waiver(h, id, c);
    }

    function testCompletedEvidenceCannotReenterEarlierStage() external {
        Scoped.Context memory c = _context(2);
        (ScopedDescriptionInterviewHarness h, bytes32 id) = _seed(c, 5);
        h.completed(id, keccak256("already complete"));
        vm.expectRevert(abi.encodeWithSelector(T.InventoryIncomplete.selector));
        h.waiver(id);
        _unchanged(h, id, 5);
        h.completed(id, 0);
        _waiver(h, id, c);
    }

    function testFuzzCompleteContextHashAndWaiver(
        uint8 scopeKind,
        bytes32 subject,
        bytes32 selection
    ) external {
        Scoped.Context memory c = _context(1 + scopeKind % 3);
        c.subject = subject;
        c.selectionHash = selection;
        (ScopedDescriptionInterviewHarness h, bytes32 id) = _seed(c, 5);
        _waiver(h, id, c);
    }
}
