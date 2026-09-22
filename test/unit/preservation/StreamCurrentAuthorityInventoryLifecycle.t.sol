// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityInventoryLifecycle as Collection
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityInventoryLifecycle.sol";
import {
    StreamCurrentAuthorityScopedInventoryLifecycle as ScopedLife
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedInventoryLifecycle.sol";
import {
    StreamCurrentAuthorityPolicyInventoryLifecycleV2 as PolicyLife
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityPolicyInventoryLifecycleV2.sol";
import {
    StreamCurrentAuthorityPolicyInventoryRootStagesV2 as PolicyRoot
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityPolicyInventoryRootStagesV2.sol";
import {
    StreamRenderCriticalInventoryState as CS
} from "../../../smart-contracts/domains/preservation/StreamRenderCriticalInventoryState.sol";
import {
    StreamCurrentAuthorityScopedRenderCriticalState as SS
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedRenderCriticalState.sol";
import {
    StreamPolicyRenderCriticalStateV2 as PS
} from "../../../smart-contracts/domains/preservation/StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamCurrentAuthorityInventoryGuard as CG
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityInventoryGuard.sol";
import {
    StreamCurrentAuthorityPolicyInventoryGuardV2 as PG
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityPolicyInventoryGuardV2.sol";
import {
    StreamCurrentAuthorityInventorySelection as Authority
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityInventorySelection.sol";
import {
    StreamMultiOriginInventoryState as Origins
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginInventoryState.sol";
import {
    StreamRenderCriticalDefinitionStages as CD
} from "../../../smart-contracts/domains/preservation/StreamRenderCriticalDefinitionStages.sol";
import {
    StreamCurrentAuthorityScopedRenderCriticalDefinitionStages as SD
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedRenderCriticalDefinitionStages.sol";
import {
    StreamPolicyRenderCriticalDefinitionStagesV2 as PD
} from "../../../smart-contracts/domains/preservation/StreamPolicyRenderCriticalDefinitionStagesV2.sol";
import {
    StreamMultiOriginScopedRenderCriticalSourceReads as ScopedSource
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginScopedRenderCriticalSourceReads.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamPolicyRenderCriticalTypesV2 as Policy
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamConservationRecordSelection as Conservation
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import {
    IStreamScopedContentRootPublication as Aggregate
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";

/// @dev Explicit typed source/currentness/definition double. No actual source admission claim.
interface InventoryLifecycleVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function etch(address, bytes calldata) external;
    function expectRevert(bytes4) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract InventoryLifecycleReplies {
    struct Reply {
        bool configured;
        bool refuse;
        bytes output;
    }
    mapping(bytes32 => Reply) private replies;
    error BoundaryRefused();

    function set(
        address host,
        address caller,
        bytes calldata input,
        bytes calldata output,
        bool refuse
    ) external {
        replies[keccak256(abi.encode(host, caller, input))] = Reply(true, refuse, output);
    }

    function read(address host, address caller, bytes calldata input)
        external
        view
        returns (bytes memory)
    {
        require(msg.sender == host, "actual delegate host");
        Reply storage r = replies[keccak256(abi.encode(host, caller, input))];
        require(r.configured, "exact caller and typed frame");
        if (r.refuse) revert BoundaryRefused();
        return r.output;
    }
}

contract InventoryLifecycleBoundary {
    InventoryLifecycleReplies private immutable replies;

    constructor(InventoryLifecycleReplies r) {
        replies = r;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        return replies.read(address(this), msg.sender, input);
    }
}

contract InventoryLifecyclePin {
    function value() external pure returns (uint256) {
        return 9;
    }
}

contract CollectionLifecycleHarness {
    bytes32 private left = keccak256("left");
    mapping(bytes32 => CS.State) private states;
    Origins.State private origins;
    mapping(bytes32 => Authority.State) private authorities;
    bytes32 private right = keccak256("right");

    function seed(bytes32 id, S.Context calldata c, O.Origin calldata o) external {
        states[id].dependencyHash = keccak256("dependencies");
        states[id].contexts[id] = c;
        T.Plan storage p = states[id].plans[id];
        p.collectionId = c.collectionId;
        p.completedStages = 8;
        p.tokenCount = c.tokenCount;
        p.nextToken = c.tokenCount;
        p.segmentCount = 17;
        p.itemCount = 29;
        p.segmentChainHash = keccak256("segments");
        p.sourceContextHash = keccak256("context");
        authorities[id].capture.selection.selectionHash = keccak256("selection");
        origins.lineage[id] = keccak256("lineage");
        origins.chain[id] = keccak256("origins");
        origins.origins[id].push(o);
        origins.runtimeCursor[id] = 1;
    }

    function stage(bytes32 id, uint16 expected) external view {
        Collection.stage(states, origins, authorities, id, expected);
    }

    function seal(bytes32 id) external returns (T.Evidence memory) {
        return Collection.sealInventory(states, origins, authorities, id);
    }

    function full(bytes32 id) external view {
        Collection.requireFullDefinitionBytes(states, origins, authorities, id);
    }

    function frame(bytes32 id, uint8 which, bool full_) external view returns (bytes memory) {
        CS.State storage s = states[id];
        Authority.State storage a = authorities[id];
        uint256 x;
        uint256 y;
        uint256 z;
        assembly ("memory-safe") {
            x := s.slot
            y := origins.slot
            z := a.slot
        }
        if (which == 0) return abi.encodeWithSelector(CG.requireCurrent.selector, x, y, z, id);
        return abi.encodeWithSelector(CD.requireDefinitions.selector, x, id, full_);
    }

    function stored(bytes32 id) external view returns (T.Evidence memory, bytes32, bytes32) {
        return
            (states[id].completed[id], origins.sealedRoot[id], keccak256(abi.encode(left, right)));
    }
}

contract ScopedLifecycleHarness {
    bytes32 private left = keccak256("left");
    mapping(bytes32 => SS.State) private states;
    bytes32 private right = keccak256("right");

    function seed(Scoped.Context calldata c, O.Origin calldata o) external returns (bytes32 id) {
        D.Capture memory captured;
        captured.selection.selectionHash = keccak256("selection");
        id = SS.idFor(keccak256("dependencies"), captured, c, keccak256("lineage"));
        SS.State storage s = states[id];
        s.authority.capture = captured;
        s.dependencyHash = keccak256("dependencies");
        s.contexts[id] = c;
        s.plans[id].scope = c.scope;
        T.Plan storage p = s.plans[id].progress;
        p.collectionId = c.scope.collectionId;
        p.completedStages = 8;
        p.tokenCount = c.tokenCount;
        p.nextToken = c.tokenCount;
        p.segmentCount = 17;
        p.itemCount = 29;
        p.segmentChainHash = keccak256("segments");
        p.sourceContextHash =
            D.contextHash(captured, keccak256(abi.encode(c)), keccak256("lineage"));
        s.origins.lineage[id] = keccak256("lineage");
        s.origins.chain[id] = keccak256("origins");
        s.origins.origins[id].push(o);
        s.origins.runtimeCursor[id] = 1;
    }

    function seal(bytes32 id) external returns (Scoped.Evidence memory) {
        return ScopedLife.sealInventory(states, id);
    }

    function full(bytes32 id) external view {
        ScopedLife.requireFullDefinitionBytes(states, id);
    }

    function frame(bytes32 id, uint8 which, bool full_) external view returns (bytes memory) {
        SS.State storage s = states[id];
        Authority.State storage a = s.authority;
        uint256 x;
        uint256 y;
        assembly ("memory-safe") {
            x := s.slot
            y := a.slot
        }
        if (which == 0) return abi.encodeWithSelector(Authority.requireCurrent.selector, y);
        if (which == 1) {
            return abi.encodeWithSelector(
                ScopedSource.current.selector,
                s.dependencies,
                s.origins.dependencies,
                s.plans[id].scope
            );
        }
        return abi.encodeWithSelector(SD.requireDefinitions.selector, x, id, full_);
    }

    function stored(bytes32 id) external view returns (Scoped.Evidence memory, bytes32, bytes32) {
        return (
            states[id].completed[id],
            states[id].origins.sealedRoot[id],
            keccak256(abi.encode(left, right))
        );
    }
}

contract PolicyLifecycleHarness {
    mapping(bytes32 => PS.State) private states;
    Origins.State private origins;
    mapping(bytes32 => Authority.State) private authorities;

    function markComplete(bytes32 id) external {
        states[id].records.completed[id].renderCriticalEvidenceHash = keccak256("complete");
    }

    function current(bytes32 id) external view {
        PolicyLife.requirePlanCurrent(states, origins, authorities, id);
    }

    function full(bytes32 id) external view {
        PolicyLife.requireFullDefinitionBytes(states, origins, authorities, id);
    }

    function root(bytes32 id) external {
        Aggregate.Aggregate memory a;
        O.ReceiptWitness memory r;
        PolicyRoot.appendRootAuthorization(states, origins, authorities, id, address(this), 7, a, r);
    }

    function runtime(bytes32 id) external {
        PolicyRoot.appendOriginRuntime(states, origins, authorities, id);
    }

    function frame(bytes32 id, bool definition) external view returns (bytes memory) {
        PS.State storage s = states[id];
        Authority.State storage a = authorities[id];
        uint256 x;
        uint256 y;
        uint256 z;
        assembly ("memory-safe") {
            x := s.slot
            y := origins.slot
            z := a.slot
        }
        if (definition) return abi.encodeWithSelector(PD.requireDefinitions.selector, x, id, true);
        return abi.encodeWithSelector(PG.requireCurrent.selector, x, y, z, id);
    }
}

/// @notice Actual four linked workers and original state/seal logic; source readers are explicit doubles.
contract StreamCurrentAuthorityInventoryLifecycleTest {
    InventoryLifecycleVm private constant vm =
        InventoryLifecycleVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    InventoryLifecycleReplies private replies;
    bytes32 private constant ID = keccak256("plan");

    function setUp() public {
        replies = new InventoryLifecycleReplies();
        InventoryLifecycleBoundary b = new InventoryLifecycleBoundary(replies);
        vm.etch(address(CG), address(b).code);
        vm.etch(address(PG), address(b).code);
        vm.etch(address(CD), address(b).code);
        vm.etch(address(PD), address(b).code);
        vm.etch(address(SD), address(b).code);
        vm.etch(address(Authority), address(b).code);
        vm.etch(address(ScopedSource), address(b).code);
    }

    function testCollectionLiteralEvidenceHashEventAndHostDomain() public {
        bytes32 previous;
        for (uint8 kind; kind < 2; ++kind) {
            CollectionLifecycleHarness h = new CollectionLifecycleHarness();
            S.Context memory c = _collection(kind);
            h.seed(ID, c, _origin());
            _collectionReplies(h, c, false);
            T.Evidence memory expected = _literal(ID, kind, keccak256("context"));
            expected.renderCriticalEvidenceHash = _hash(address(h), expected);
            vm.recordLogs();
            T.Evidence memory got = h.seal(ID);
            InventoryLifecycleVm.Log[] memory logs = vm.getRecordedLogs();
            assertEq(abi.encode(got), abi.encode(expected));
            assertEq(logs.length, 1);
            assertEq(logs[0].emitter, address(h));
            assertEq(
                logs[0].topics[0],
                keccak256(
                    "InventoryCompleted(bytes32,bytes32,(bytes32,uint256,bytes32,bytes32,(bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),bytes32,bytes32,uint64,uint64,uint64,bytes32,bytes32))"
                )
            );
            assertEq(logs[0].topics[1], ID);
            assertEq(logs[0].topics[2], expected.renderCriticalEvidenceHash);
            assertEq(logs[0].data, abi.encode(expected));
            (T.Evidence memory saved, bytes32 root, bytes32 canaries) = h.stored(ID);
            assertEq(abi.encode(saved), abi.encode(expected));
            assertEq(root, _originRoot());
            assertEq(canaries, _canaries());
            assertTrue(previous != got.renderCriticalEvidenceHash);
            previous = got.renderCriticalEvidenceHash;
        }
    }

    function testCollectionLateDefinitionRollbackIdenticalRetryAndReplay() public {
        CollectionLifecycleHarness h = new CollectionLifecycleHarness();
        S.Context memory c = _collection(0);
        h.seed(ID, c, _origin());
        _collectionReplies(h, c, true);
        vm.expectRevert(InventoryLifecycleReplies.BoundaryRefused.selector);
        h.seal(ID);
        (T.Evidence memory saved, bytes32 root, bytes32 canaries) = h.stored(ID);
        assertEq(saved.renderCriticalEvidenceHash, bytes32(0));
        assertEq(root, bytes32(0));
        assertEq(canaries, _canaries());
        _collectionReplies(h, c, false);
        T.Evidence memory got = h.seal(ID);
        assertEq(
            got.renderCriticalEvidenceHash, _hash(address(h), _literal(ID, 0, keccak256("context")))
        );
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.seal(ID);
    }

    function testFuzzCollectionStagePrecedesCurrentness(uint16 expected) public {
        CollectionLifecycleHarness h = new CollectionLifecycleHarness();
        S.Context memory c = _collection(0);
        h.seed(ID, c, _origin());
        replies.set(address(h), address(this), h.frame(ID, 0, false), "", true);
        vm.expectRevert(
            expected == 8
                ? InventoryLifecycleReplies.BoundaryRefused.selector
                : T.InventoryIncomplete.selector
        );
        h.stage(ID, expected);
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.stage(keccak256("missing"), 8);
    }

    function testPolicyVoidCurrentFullContextAndStrictFailure() public {
        PolicyLifecycleHarness h = new PolicyLifecycleHarness();
        Policy.Context memory c;
        c.records = _collection(0);
        replies.set(address(h), address(this), h.frame(ID, false), abi.encode(c), false);
        h.current(ID);
        replies.set(address(h), address(this), h.frame(ID, false), "", true);
        vm.expectRevert(InventoryLifecycleReplies.BoundaryRefused.selector);
        h.current(ID);
        replies.set(address(h), address(this), h.frame(ID, false), abi.encode(c), false);
        h.current(ID);
    }

    function testPolicyCompletionBeforeFullDefinitionAndExactTrueFlag() public {
        PolicyLifecycleHarness h = new PolicyLifecycleHarness();
        Policy.Context memory c;
        replies.set(address(h), address(this), h.frame(ID, false), "", true);
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.full(ID);
        h.markComplete(ID);
        vm.expectRevert(InventoryLifecycleReplies.BoundaryRefused.selector);
        h.full(ID);
        replies.set(address(h), address(this), h.frame(ID, false), abi.encode(c), false);
        replies.set(address(h), address(this), h.frame(ID, true), "", false);
        h.full(ID);
    }

    function testPolicyRootAndRuntimeRetainDifferentFirstGuard() public {
        PolicyLifecycleHarness h = new PolicyLifecycleHarness();
        Policy.Context memory c;
        replies.set(address(h), address(this), h.frame(ID, false), "", true);
        vm.expectRevert(InventoryLifecycleReplies.BoundaryRefused.selector);
        h.root(ID);
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.runtime(ID);
        replies.set(address(h), address(this), h.frame(ID, false), abi.encode(c), false);
        vm.expectRevert(T.InventoryIncomplete.selector);
        h.root(ID);
    }

    function testScopedLiteralReceiptFullScopeHashAndStorage() public {
        ScopedLifecycleHarness h = new ScopedLifecycleHarness();
        Scoped.Context memory c = _scoped();
        bytes32 id = h.seed(c, _origin());
        _scopedReplies(h, id, c, false);
        Scoped.Evidence memory expected;
        expected.scope = c.scope;
        bytes32 contextHash = _scopedContext(c);
        expected.inventory = _literal(id, 1, contextHash);
        expected.inventory.renderCriticalEvidenceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_AUTHORITY_SCOPED_RENDER_CRITICAL_INVENTORY_V1"),
                block.chainid,
                address(h),
                keccak256("dependencies"),
                keccak256("selection"),
                expected,
                _originRoot(),
                uint256(1)
            )
        );
        assertEq(
            id,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_CURRENT_AUTHORITY_SCOPED_RENDER_CRITICAL_INVENTORY_V1"),
                    block.chainid,
                    address(h),
                    keccak256("dependencies"),
                    contextHash
                )
            )
        );
        vm.recordLogs();
        Scoped.Evidence memory got = h.seal(id);
        InventoryLifecycleVm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(abi.encode(got), abi.encode(expected));
        assertEq(logs.length, 1);
        assertEq(logs[0].emitter, address(h));
        assertEq(logs[0].topics[1], id);
        assertEq(logs[0].topics[2], got.inventory.renderCriticalEvidenceHash);
        assertEq(logs[0].data, abi.encode(uint16(1), expected));
        (Scoped.Evidence memory saved, bytes32 root, bytes32 canaries) = h.stored(id);
        assertEq(abi.encode(saved), abi.encode(expected));
        assertEq(root, _originRoot());
        assertEq(canaries, _canaries());
    }

    function testScopedSourceDriftAndLateDefinitionRefusalRestore() public {
        ScopedLifecycleHarness h = new ScopedLifecycleHarness();
        Scoped.Context memory c = _scoped();
        bytes32 id = h.seed(c, _origin());
        Scoped.Context memory changed = abi.decode(abi.encode(c), (Scoped.Context));
        changed.artistId = keccak256("different");
        _scopedReplies(h, id, changed, false);
        vm.expectRevert(T.InventorySourceChanged.selector);
        h.seal(id);
        _scopedReplies(h, id, c, true);
        vm.expectRevert(InventoryLifecycleReplies.BoundaryRefused.selector);
        h.seal(id);
        (Scoped.Evidence memory saved, bytes32 root, bytes32 canaries) = h.stored(id);
        assertEq(saved.inventory.renderCriticalEvidenceHash, bytes32(0));
        assertEq(root, bytes32(0));
        assertEq(canaries, _canaries());
        _scopedReplies(h, id, c, false);
        assertTrue(h.seal(id).inventory.renderCriticalEvidenceHash != 0);
        replies.set(address(h), address(this), h.frame(id, 2, true), "", false);
        h.full(id);
    }

    function _collectionReplies(CollectionLifecycleHarness h, S.Context memory c, bool refuse)
        private
    {
        replies.set(address(h), address(this), h.frame(ID, 0, false), abi.encode(c), false);
        replies.set(address(h), address(this), h.frame(ID, 1, false), "", refuse);
    }

    function _scopedReplies(
        ScopedLifecycleHarness h,
        bytes32 id,
        Scoped.Context memory c,
        bool refuse
    ) private {
        O.Origin memory a;
        O.Origin memory b;
        replies.set(address(h), address(this), h.frame(id, 0, false), "", false);
        replies.set(
            address(h),
            address(this),
            h.frame(id, 1, false),
            abi.encode(c, a, b, keccak256("lineage")),
            false
        );
        replies.set(address(h), address(this), h.frame(id, 2, false), "", refuse);
    }

    function _origin() private returns (O.Origin memory o) {
        InventoryLifecyclePin p = new InventoryLifecyclePin();
        o.environment.chainId = block.chainid;
        o.environment.core = address(1);
        o.environment.manager = address(2);
        o.environment.suiteConfigurationHash = keccak256("suite");
        o.environment.registry = address(p);
        o.environment.coordinator = address(p);
        o.environment.archive = address(p);
        o.registryCodeHash = address(p).codehash;
        o.coordinatorCodeHash = address(p).codehash;
        o.archiveCodeHash = address(p).codehash;
        for (uint256 i; i < 7; ++i) {
            o.environment.owners[i] = address(p);
            o.environment.ownerCodeHashes[i] = address(p).codehash;
        }
    }

    function _collection(uint8 kind) private pure returns (S.Context memory c) {
        c.collectionId = 91;
        c.subject = keccak256("subject");
        c.artistId = keccak256("artist");
        c.rootRecordHash = keccak256("root");
        c.snapshot.recordHash = keccak256("snapshot");
        c.referenceRender.recordHash = keccak256("reference");
        c.conservation.record.kind =
            kind == 0 ? Conservation.RecordKind.INTENT : Conservation.RecordKind.INTENT_WAIVER;
        c.conservation.record.recordHash = keccak256("conservation");
        c.interviewEvidenceHash = keccak256("interview");
        c.descriptions.rightsStatementRecordHash = keccak256("rights");
        c.descriptions.workDescriptionRecordHash = keccak256("work");
        c.tokenInventoryHash = keccak256("tokens");
        c.tokenCount = 3;
    }

    function _scoped() private pure returns (Scoped.Context memory c) {
        S.Context memory a = _collection(1);
        c.scope = StreamFinalityScope(StreamFinalityScopeType.RELEASE, 91, 0, keccak256("release"));
        c.subject = a.subject;
        c.artistId = a.artistId;
        c.rootRecordHash = a.rootRecordHash;
        c.snapshot.recordHash = a.snapshot.recordHash;
        c.referenceRender.observation.recordHash = a.referenceRender.recordHash;
        c.conservation = a.conservation;
        c.interviewEvidenceHash = a.interviewEvidenceHash;
        c.descriptions = a.descriptions;
        c.tokenInventoryHash = a.tokenInventoryHash;
        c.tokenCount = 3;
    }

    function _literal(bytes32 id, uint8 kind, bytes32 contextHash)
        private
        pure
        returns (T.Evidence memory e)
    {
        e.planId = id;
        e.collectionId = 91;
        e.scopeSubject = keccak256("subject");
        e.artistId = keccak256("artist");
        e.originals = T.OriginalInputs(
            keccak256("root"),
            keccak256("snapshot"),
            keccak256("reference"),
            kind == 0 ? keccak256("conservation") : bytes32(0),
            kind == 1 ? keccak256("conservation") : bytes32(0),
            keccak256("interview"),
            keccak256("rights"),
            keccak256("work")
        );
        e.sourceContextHash = contextHash;
        e.tokenInventoryHash = keccak256("tokens");
        e.tokenCount = 3;
        e.segmentCount = 17;
        e.itemCount = 29;
        e.segmentChainHash = keccak256("segments");
    }

    function _hash(address h, T.Evidence memory e) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_AUTHORITY_RENDER_CRITICAL_INVENTORY_V1"),
                block.chainid,
                h,
                keccak256("dependencies"),
                keccak256("selection"),
                e,
                _originRoot(),
                uint256(1)
            )
        );
    }

    function _originRoot() private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ARCHIVE_ORIGIN_SET_V1"),
                uint256(1),
                keccak256("origins")
            )
        );
    }

    function _canaries() private pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("left"), keccak256("right")));
    }

    function _scopedContext(Scoped.Context memory c) private pure returns (bytes32) {
        S.Dependencies memory d;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_AUTHORITY_INVENTORY_CONTEXT_V1"),
                keccak256("selection"),
                keccak256(abi.encode(d)),
                keccak256(abi.encode(c)),
                keccak256("lineage")
            )
        );
    }

    function assertEq(bytes memory a, bytes memory b) private pure {
        require(keccak256(a) == keccak256(b), "bytes equality");
    }

    function assertEq(bytes32 a, bytes32 b) private pure {
        require(a == b, "word equality");
    }

    function assertEq(uint256 a, uint256 b) private pure {
        require(a == b, "number equality");
    }

    function assertEq(address a, address b) private pure {
        require(a == b, "address equality");
    }

    function assertTrue(bool a) private pure {
        require(a, "expected true");
    }
}
