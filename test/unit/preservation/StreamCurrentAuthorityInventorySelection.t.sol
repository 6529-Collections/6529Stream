// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityInventorySelection as Selection
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityInventorySelection.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    IStreamArtistCurrentAuthorityResolver as Resolver
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamArtistCurrentAuthorityResolver.sol";
import {
    IStreamRecordCurrentAuthority as Selector
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamRecordCurrentAuthority.sol";
import {
    StreamCurrentAuthorityInventoryGuard as CollectionGuard
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityInventoryGuard.sol";
import {
    StreamCurrentAuthorityPolicyInventoryGuardV2 as PolicyGuard
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityPolicyInventoryGuardV2.sol";
import {
    StreamRenderCriticalInventoryState as CollectionState
} from "../../../smart-contracts/domains/preservation/StreamRenderCriticalInventoryState.sol";
import {
    StreamPolicyRenderCriticalStateV2 as PolicyState
} from "../../../smart-contracts/domains/preservation/StreamPolicyRenderCriticalStateV2.sol";
import {
    StreamCurrentAuthorityScopedRenderCriticalState as ScopedState
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedRenderCriticalState.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2 as ScopedPolicyState
} from "../../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2.sol";
import {
    StreamMultiOriginInventoryState as Origins
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginInventoryState.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

interface CurrentInventoryVm {
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function etch(address, bytes calldata) external;
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
}

contract CurrentInventoryRuntimeFixture {
    function value() external pure returns (uint256) {
        return 1;
    }
}

/// @dev Synthetic fixed resolver boundary. No Metadata ancestry or op55/60 claim.
contract CurrentInventoryResolverFixture {
    C.Anchors private _anchors;
    C.Selection private _selection;

    function set(C.Anchors memory a, O.Origin memory o, bytes32 completion) external {
        _anchors = a;
        _selection = C.Selection(o, completion, C.hashSelection(a, o, completion));
    }

    function currentAuthorityProfile() external pure returns (bytes32) {
        return C.PROFILE;
    }

    function anchors() external view returns (C.Anchors memory) {
        return _anchors;
    }

    function currentSelection() external view returns (C.Selection memory) {
        return _selection;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(Resolver).interfaceId;
    }
}

/// @dev Real canonical typed getters with synthetic selected facts; no selector history admission.
contract CurrentInventorySelectorFixture {
    bytes32 private _profile;
    address[5] private _targets;
    bytes32[5] private _hashes;

    function set(bytes32 profile, O.Origin memory o) external {
        _profile = profile;
        _targets = [
            o.environment.registry,
            o.environment.coordinator,
            o.environment.owners[2],
            o.environment.owners[0],
            o.environment.owners[4]
        ];
        _hashes = [
            o.registryCodeHash,
            o.coordinatorCodeHash,
            o.environment.ownerCodeHashes[2],
            o.environment.ownerCodeHashes[0],
            o.environment.ownerCodeHashes[4]
        ];
    }

    function currentAuthorityProfile() external view returns (bytes32) {
        return _profile;
    }

    function currentArtistContext() external view returns (address[5] memory, bytes32[5] memory) {
        return (_targets, _hashes);
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(Selector).interfaceId;
    }
}

/// @dev Exercises actual capture/storage and the four actual guard kernels. Stale-selection
/// tests reject before source reads; they do not admit a full inventory or simulate migration.
contract CurrentInventorySelectionHarness {
    mapping(bytes32 => Selection.State) private _selections;
    mapping(bytes32 => CollectionState.State) private _collection;
    mapping(bytes32 => PolicyState.State) private _policy;
    mapping(bytes32 => ScopedState.State) private _scoped;
    mapping(bytes32 => ScopedPolicyState.State) private _scopedPolicy;
    Origins.State private _origins;
    mapping(bytes32 => uint256) public writes;

    function resolve(Selection.Config memory config) external view returns (D.Capture memory) {
        return Selection.resolve(config);
    }

    function remember(bytes32 id, Selection.Config memory config) external {
        D.Capture memory c = Selection.resolve(config);
        Selection.remember(_selections[id], config, c);
        Selection.remember(_scoped[id].authority, config, c);
        Selection.remember(_scopedPolicy[id].authority, config, c);
        _collection[id].dependencies = c.dependencies;
        _policy[id].records.dependencies = c.dependencies;
        _scoped[id].dependencies = c.dependencies;
        _scopedPolicy[id].dependencies = c.dependencies;
    }

    function captured(bytes32 id) external view returns (D.Capture memory) {
        return _selections[id].capture;
    }

    function guardedWrite(bytes32 id) external {
        Selection.requireCurrent(_selections[id]);
        ++writes[id];
    }

    function writeThenGuard(bytes32 id) external {
        ++writes[id];
        Selection.requireCurrent(_selections[id]);
    }

    function guard(bytes32 id, uint256 profile) external view {
        if (profile == 0) {
            CollectionGuard.requireCurrent(_collection[id], _origins, _selections[id], id);
        } else if (profile == 1) {
            PolicyGuard.requireCurrent(_policy[id], _origins, _selections[id], id);
        } else if (profile == 2) {
            ScopedState.requireCurrent(_scoped[id], id);
        } else {
            ScopedPolicyState.requireCurrent(_scopedPolicy[id], id);
        }
    }

    function contextHash(D.Capture memory c, bytes32 context_, bytes32 lineage)
        external
        pure
        returns (bytes32)
    {
        return D.contextHash(c, context_, lineage);
    }

    function planId(bytes32 profile, bytes32 dependenciesHash, bytes32 context_)
        external
        view
        returns (bytes32)
    {
        return D.planId(profile, dependenciesHash, context_);
    }
}

contract StreamCurrentAuthorityInventorySelectionTest {
    CurrentInventoryVm private constant vm =
        CurrentInventoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant WORK = keccak256("6529STREAM_CURRENT_AUTHORITY_WORK_SELECTION_V1");
    bytes32 private constant CONSERVATION =
        keccak256("6529STREAM_CURRENT_AUTHORITY_CONSERVATION_SELECTION_V1");
    bytes32 private constant ID = keccak256("plan B");
    CurrentInventorySelectionHarness private harness;
    CurrentInventoryResolverFixture private resolver;
    CurrentInventorySelectorFixture private work;
    CurrentInventorySelectorFixture private conservation;
    Selection.Config private config;
    C.Anchors private anchors_;
    O.Origin private original;
    O.Origin private selected;

    function setUp() public {
        harness = new CurrentInventorySelectionHarness();
        resolver = new CurrentInventoryResolverFixture();
        work = new CurrentInventorySelectorFixture();
        conservation = new CurrentInventorySelectorFixture();
        S.Dependencies memory d;
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = address(new CurrentInventoryRuntimeFixture());
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.targets[7] = address(work);
        d.codeHashes[7] = address(work).codehash;
        d.targets[9] = address(conservation);
        d.codeHashes[9] = address(conservation).codehash;
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 500000;
        d.selectionGas = 500000;
        d.snapshotGas = 500000;
        d.referenceGas = 500000;
        original = _origin(d.targets[0]);
        selected = _origin(d.targets[0]);
        O.Origin memory o = original;
        d.artistTargets = [
            o.environment.registry,
            o.environment.coordinator,
            o.environment.owners[2],
            o.environment.owners[4],
            o.environment.archive
        ];
        d.artistCodeHashes = [
            o.registryCodeHash,
            o.coordinatorCodeHash,
            o.environment.ownerCodeHashes[2],
            o.environment.ownerCodeHashes[4],
            o.archiveCodeHash
        ];
        d.artistContentOwner = o.environment.owners[6];
        d.artistContentOwnerCodeHash = o.environment.ownerCodeHashes[6];
        address provider = address(new CurrentInventoryRuntimeFixture());
        anchors_ = C.Anchors(
            [d.targets[0], d.targets[1], d.targets[4], o.environment.registry, provider],
            [
                d.codeHashes[0],
                d.codeHashes[1],
                d.codeHashes[4],
                o.registryCodeHash,
                provider.codehash
            ],
            address(0xFA),
            block.chainid,
            500000
        );
        config = Selection.Config(
            d, D.Dependencies(address(resolver), address(resolver).codehash, 500000)
        );
        _select(selected, keccak256("complete B"));
    }

    function testSelectedProjectionPreservesEveryOriginalDependencyAndAnchor() public view {
        D.Capture memory c = harness.resolve(config);
        S.Dependencies memory expected = config.originalAnchor;
        O.Origin memory o = selected;
        expected.artistTargets = [
            o.environment.registry,
            o.environment.coordinator,
            o.environment.owners[2],
            o.environment.owners[4],
            o.environment.archive
        ];
        expected.artistCodeHashes = [
            o.registryCodeHash,
            o.coordinatorCodeHash,
            o.environment.ownerCodeHashes[2],
            o.environment.ownerCodeHashes[4],
            o.archiveCodeHash
        ];
        expected.artistContentOwner = o.environment.owners[6];
        expected.artistContentOwnerCodeHash = o.environment.ownerCodeHashes[6];
        require(
            keccak256(abi.encode(c.dependencies)) == keccak256(abi.encode(expected)), "projection"
        );
        require(
            config.originalAnchor.artistTargets[0] == original.environment.registry,
            "original anchor changed"
        );
        require(
            c.selection.selectionHash == C.hashSelection(anchors_, o, keccak256("complete B")),
            "selection"
        );
    }

    function testOriginalSelectionAcceptsZeroCompletion() public {
        _select(original, bytes32(0));
        D.Capture memory c = harness.resolve(config);
        require(
            c.selection.completion == 0
                && c.selection.origin.environment.registry == original.environment.registry,
            "original"
        );
    }

    function testUnpredictedSuccessorStalesOldPlanAndPreservesHistoricalCapture() public {
        harness.remember(ID, config);
        harness.guardedWrite(ID);
        bytes32 before_ = keccak256(abi.encode(harness.captured(ID)));
        O.Origin memory next = _origin(config.originalAnchor.targets[0]);
        _select(next, keccak256("complete C"));
        vm.expectRevert(C.CurrentAuthorityChanged.selector);
        harness.guardedWrite(ID);
        require(
            harness.writes(ID) == 1 && keccak256(abi.encode(harness.captured(ID))) == before_,
            "history"
        );
        bytes32 nextId = keccak256("unpredicted C plan");
        harness.remember(nextId, config);
        harness.guardedWrite(nextId);
        require(
            harness.captured(nextId).selection.origin.environment.registry
                == next.environment.registry,
            "new capture"
        );
        vm.expectRevert(C.CurrentAuthorityChanged.selector);
        harness.guardedWrite(ID);
    }

    function testAllFourProfileGuardsRejectChangedSelectionBeforeSourceReads() public {
        harness.remember(ID, config);
        _select(_origin(config.originalAnchor.targets[0]), keccak256("complete C"));
        for (uint256 i; i < 4; ++i) {
            vm.expectRevert(C.CurrentAuthorityChanged.selector);
            harness.guard(ID, i);
        }
    }

    function testFailedGuardRollsBackWritesAndIdenticalRetrySucceeds() public {
        harness.remember(ID, config);
        _select(_origin(config.originalAnchor.targets[0]), keccak256("complete C"));
        vm.expectRevert(C.CurrentAuthorityChanged.selector);
        harness.writeThenGuard(ID);
        require(harness.writes(ID) == 0, "rollback");
        _select(selected, keccak256("complete B"));
        harness.writeThenGuard(ID);
        require(harness.writes(ID) == 1, "retry");
    }

    function testCapturedSelectionCannotBeOverwritten() public {
        harness.remember(ID, config);
        vm.expectRevert(C.InvalidCurrentAuthority.selector);
        harness.remember(ID, config);
    }

    function testEverySharedOriginalAnchorCoordinateMustMatch() public {
        for (uint256 i; i < 4; ++i) {
            C.Anchors memory bad = anchors_;
            bad.targets[i] = address(0xBADD);
            resolver.set(bad, selected, keccak256("complete B"));
            vm.expectRevert(C.InvalidCurrentAuthority.selector);
            harness.resolve(config);
            bad = anchors_;
            bad.codeHashes[i] = keccak256("wrong runtime");
            resolver.set(bad, selected, keccak256("complete B"));
            vm.expectRevert(C.InvalidCurrentAuthority.selector);
            harness.resolve(config);
        }
    }

    function testResolverRuntimeAndProfileArePinned() public {
        vm.mockCall(
            address(resolver),
            abi.encodeCall(Resolver.currentAuthorityProfile, ()),
            abi.encode(bytes32(0))
        );
        vm.expectRevert(C.InvalidCurrentAuthority.selector);
        harness.resolve(config);
        vm.clearMockedCalls();
        vm.etch(address(resolver), hex"60006000f3");
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(resolver)));
        harness.resolve(config);
    }

    function testResolverReturnLengthAndSelectionHashAreStrict() public {
        C.Selection memory c = resolver.currentSelection();
        vm.mockCall(
            address(resolver),
            abi.encodeCall(Resolver.currentSelection, ()),
            abi.encodePacked(abi.encode(c), bytes32(0))
        );
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(resolver)));
        harness.resolve(config);
        vm.clearMockedCalls();
        c.completion = keccak256("changed completion under stale hash");
        vm.mockCall(address(resolver), abi.encodeCall(Resolver.currentSelection, ()), abi.encode(c));
        vm.expectRevert(C.InvalidCurrentAuthority.selector);
        harness.resolve(config);
    }

    function testBothOriginalSelectorsRequireTheirCapabilityProfile() public {
        work.set(CONSERVATION, selected);
        vm.expectRevert(C.InvalidCurrentAuthority.selector);
        harness.resolve(config);
        work.set(WORK, selected);
        conservation.set(WORK, selected);
        vm.expectRevert(C.InvalidCurrentAuthority.selector);
        harness.resolve(config);
    }

    function testSelectorOwnerOrderAndRuntimeMustMatchSelectedOrigin() public {
        O.Origin memory bad = selected;
        bad.environment.owners[2] = bad.environment.owners[0];
        work.set(WORK, bad);
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(work)));
        harness.resolve(config);
        work.set(WORK, selected);
        bad = selected;
        bad.environment.ownerCodeHashes[4] = keccak256("different runtime");
        conservation.set(CONSERVATION, bad);
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, address(conservation)));
        harness.resolve(config);
    }

    function testCurrentOwnerRuntimeMustRemainPinned() public {
        address content = selected.environment.owners[6];
        vm.etch(content, hex"60006000f3");
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, content));
        harness.resolve(config);
    }

    function testOriginalArchiveRuntimeRemainsPinnedAfterSelectingSuccessor() public {
        harness.remember(ID, config);
        address archive = original.environment.archive;
        vm.etch(archive, hex"60006000f3");
        vm.expectRevert(abi.encodeWithSelector(T.InventoryRead.selector, archive));
        harness.guardedWrite(ID);
    }

    function testResolverAndSelectorsRequireExactERC165CapabilityResponses() public {
        address[3] memory targets = [address(resolver), address(work), address(conservation)];
        for (uint256 i; i < 3; ++i) {
            vm.mockCall(
                targets[i],
                abi.encodeCall(IERC165.supportsInterface, (bytes4(0x01ffc9a7))),
                abi.encode(uint256(2))
            );
            vm.expectRevert(C.InvalidCurrentAuthority.selector);
            harness.resolve(config);
            vm.clearMockedCalls();
            bytes4 capability = i == 0 ? type(Resolver).interfaceId : type(Selector).interfaceId;
            vm.mockCall(
                targets[i],
                abi.encodeCall(IERC165.supportsInterface, (capability)),
                abi.encode(false)
            );
            vm.expectRevert(C.InvalidCurrentAuthority.selector);
            harness.resolve(config);
            vm.clearMockedCalls();
            vm.mockCall(
                targets[i],
                abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                abi.encode(true)
            );
            vm.expectRevert(C.InvalidCurrentAuthority.selector);
            harness.resolve(config);
            vm.clearMockedCalls();
        }
    }

    function testSelectionDependenciesLineageContextAndAllProfilesBindPlanId() public view {
        D.Capture memory c = harness.resolve(config);
        bytes32 context_ = keccak256("full typed context");
        bytes32 lineage = keccak256("locked A lineage");
        bytes32 h = harness.contextHash(c, context_, lineage);
        require(h != harness.contextHash(c, keccak256("changed context"), lineage), "context");
        require(h != harness.contextHash(c, context_, keccak256("changed lineage")), "lineage");
        c.dependencies.referenceGas += 1;
        require(h != harness.contextHash(c, context_, lineage), "dependencies");
        c = harness.resolve(config);
        c.selection.selectionHash = keccak256("changed selection");
        require(h != harness.contextHash(c, context_, lineage), "selection");
        bytes32[4] memory profiles = [
            D.INVENTORY_PROFILE,
            D.SCOPED_INVENTORY_PROFILE,
            D.POLICY_INVENTORY_PROFILE,
            D.SCOPED_POLICY_INVENTORY_PROFILE
        ];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                require(
                    harness.planId(profiles[i], bytes32(uint256(1)), h)
                        != harness.planId(profiles[j], bytes32(uint256(1)), h),
                    "profile"
                );
            }
        }
    }

    function _select(O.Origin memory o, bytes32 completion) private {
        resolver.set(anchors_, o, completion);
        work.set(WORK, o);
        conservation.set(CONSERVATION, o);
    }

    function _origin(address core) private returns (O.Origin memory o) {
        o.environment.chainId = block.chainid;
        o.environment.core = core;
        o.environment.registry = address(new CurrentInventoryRuntimeFixture());
        o.environment.coordinator = address(new CurrentInventoryRuntimeFixture());
        o.environment.archive = address(new CurrentInventoryRuntimeFixture());
        o.environment.manager = address(0xCAFE);
        o.environment.suiteConfigurationHash = keccak256("synthetic suite");
        o.registryCodeHash = o.environment.registry.codehash;
        o.coordinatorCodeHash = o.environment.coordinator.codehash;
        o.archiveCodeHash = o.environment.archive.codehash;
        for (uint256 i; i < 7; ++i) {
            o.environment.owners[i] = address(new CurrentInventoryRuntimeFixture());
            o.environment.ownerCodeHashes[i] = o.environment.owners[i].codehash;
        }
    }
}
