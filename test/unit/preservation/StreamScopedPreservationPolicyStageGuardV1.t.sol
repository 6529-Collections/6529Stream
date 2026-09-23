// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPreservationPolicyRenderCriticalStageGuardV1 as Guard
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalStageGuardV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalStateV1 as State
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalStateV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as C
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

interface ScopedPreservationStageGuardVmV1 {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
}

/// @dev Two nonzero compiler-owned storage roots expose accidental root rebinding.
contract ScopedPreservationStageGuardHarnessV1 {
    bytes32 private prefix = keccak256("prefix");
    State.State private primary;
    State.State private secondary;
    bytes32 private suffix = keccak256("suffix");

    function _root(bool second) private view returns (State.State storage s) {
        if (second) return secondary;
        return primary;
    }

    function seed(bool second, S.Dependencies memory d, C.Context memory c, uint16 completed)
        external
        returns (bytes32 id)
    {
        State.State storage s = _root(second);
        s.dependencies = d;
        s.dependencyHash = keccak256(abi.encode(d));
        id = State.idFor(s.dependencyHash, c);
        s.contexts[id] = c;
        s.plans[id].scope = c.scope;
        s.plans[id].progress.collectionId = c.scope.collectionId;
        s.plans[id].progress.completedStages = completed;
    }

    function configure(
        bool second,
        bytes32 id,
        uint256 collectionId,
        uint16 stage,
        bytes32 evidence
    ) external {
        T.Plan storage p = _root(second).plans[id].progress;
        p.collectionId = collectionId;
        p.completedStages = stage;
        p.renderCriticalEvidenceHash = evidence;
    }

    function copyPlan(bool second, bytes32 from, bytes32 to) external {
        State.State storage s = _root(second);
        s.plans[to] = s.plans[from];
    }

    function check(bool linked, bool second, bytes32 id, uint16 expected)
        external
        view
        returns (bytes32 stateHash, bytes32 canaryHash, address caller)
    {
        State.State storage s = _root(second);
        bytes memory left = abi.encode(prefix, id, address(this), msg.sender);
        bytes memory alias_ = left;
        bytes memory right = abi.encode(suffix, expected, s.dependencyHash);
        bytes32 before_ = keccak256(abi.encode(left, right));
        if (linked) Guard.stage(s, id, expected);
        else State.stage(s, id, expected);
        canaryHash = keccak256(abi.encode(alias_, right));
        require(canaryHash == before_, "caller memory changed");
        stateHash =
            keccak256(abi.encode(prefix, suffix, s.dependencies, s.contexts[id], s.plans[id]));
        caller = msg.sender;
    }
}

/// @notice Linked/currentness guard parity against the unchanged inline implementation.
/// @dev Sources.current is a synthetic fixed-library boundary. This does not establish
/// genuine scoped source admission or complete record/token-stage execution.
contract StreamScopedPreservationPolicyStageGuardV1Test {
    ScopedPreservationStageGuardVmV1 private constant vm =
        ScopedPreservationStageGuardVmV1(address(uint160(uint256(keccak256("hevm cheat code")))));
    ScopedPreservationStageGuardHarnessV1 private host;
    S.Dependencies private d;
    C.Context private context;
    bytes32 private id;

    function setUp() public {
        host = new ScopedPreservationStageGuardHarnessV1();
        d.chainId = block.chainid;
        d.targets[1] = address(0x1234);
        d.codeHashes[1] = keccak256("source pin");
        context.scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 17, 17001, 0);
        context.subject = keccak256("subject");
        context.artistId = keccak256("artist");
        context.selectionHash = keccak256("selection");
        context.checkpointHash = keccak256("checkpoint");
        context.snapshotSource.artist.artistId = keccak256("nested original artist");
        id = host.seed(false, d, context, 4);
        _source(context);
    }

    function testFixedLinkedGuardMatchesInlineForRecordAndTokenStages() public {
        _equal(false, id, 4);
        host.configure(false, id, 17, 8, 0);
        _equal(false, id, 8);
    }

    function testSecondStorageRootAndHostCommitmentStayDistinct() public {
        C.Context memory other = context;
        other.scope.collectionId = 29;
        other.selectionHash = keccak256("other selection");
        bytes32 secondId = host.seed(true, d, other, 8);
        _source(other);
        _equal(true, secondId, 8);
        _reject(false, secondId, 8, abi.encodeWithSelector(T.InventoryIncomplete.selector));
        bytes32 foreign = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_RENDER_CRITICAL_PLAN_V1"),
                block.chainid,
                address(Guard),
                keccak256(abi.encode(d)),
                other
            )
        );
        host.copyPlan(true, secondId, foreign);
        _reject(true, foreign, 8, abi.encodeWithSelector(T.InventorySourceChanged.selector));
        _source(context);
        _equal(false, id, 4);
    }

    function testStageChecksPrecedeTheCurrentSourceRead() public {
        bytes memory failure = abi.encodeWithSignature("SyntheticSourceFailure(uint256)", 7);
        vm.mockCallRevert(address(Sources), _input(context.scope), failure);
        _reject(false, id, 8, abi.encodeWithSelector(T.InventoryIncomplete.selector));
        host.configure(false, id, 0, 4, 0);
        _reject(false, id, 4, abi.encodeWithSelector(T.InventoryIncomplete.selector));
        host.configure(false, id, 17, 4, keccak256("completed evidence"));
        _reject(false, id, 4, abi.encodeWithSelector(T.InventoryIncomplete.selector));
        host.configure(false, id, 17, 4, 0);
        _reject(false, id, 4, failure);
        vm.clearMockedCalls();
        _source(context);
        _equal(false, id, 4);
    }

    function testDeepContextMismatchRejectsThenOriginalSourceRetrySucceeds() public {
        C.Context memory changed = context;
        changed.snapshotSource.artist.artistId = keccak256("changed nested artist");
        _source(changed);
        _reject(false, id, 4, abi.encodeWithSelector(T.InventorySourceChanged.selector));
        _source(context);
        _equal(false, id, 4);
    }

    function _source(C.Context memory c) private {
        vm.mockCall(address(Sources), _input(c.scope), abi.encode(c));
    }

    function _input(StreamFinalityScope memory scope) private view returns (bytes memory) {
        return abi.encodeWithSelector(Sources.current.selector, d, scope);
    }

    function _equal(bool second, bytes32 key, uint16 expected) private view {
        (bytes32 a, bytes32 am, address ac) = host.check(false, second, key, expected);
        (bytes32 b, bytes32 bm, address bc) = host.check(true, second, key, expected);
        require(a == b && am == bm && ac == address(this) && bc == ac, "inline/linked parity");
    }

    function _reject(bool second, bytes32 key, uint16 expected, bytes memory reason) private {
        vm.expectRevert(reason);
        host.check(false, second, key, expected);
        vm.expectRevert(reason);
        host.check(true, second, key, expected);
    }
}
