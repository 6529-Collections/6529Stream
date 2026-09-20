// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityHistoryMutation as Mutation
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityHistoryMutation.sol";
import {
    StreamArtistIdentityState as IdentityState
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityState.sol";
import {
    StreamArtistHistoryState as HistoryState
} from "../../../smart-contracts/domains/artist/StreamArtistHistoryState.sol";
import {
    StreamArtistHistoryProof as HistoryProof
} from "../../../smart-contracts/domains/artist/StreamArtistHistoryProof.sol";
import {
    StreamArtistAuthorityCheckpoint as Checkpoint
} from "../../../smart-contracts/domains/artist/StreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistNativeReceipts as Native
} from "../../../smart-contracts/domains/artist/StreamArtistNativeReceipts.sol";
import {
    StreamArtistRecoveredHydrationApplyGuards as Apply
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationApplyGuards.sol";
import {
    StreamArtistRecoveredHydrationGuards as Keys
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistHydrationGuards as OriginalGuards
} from "../../../smart-contracts/domains/artist/StreamArtistHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistHistory,
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";

interface RecoveredHistory56Vm {
    function roll(uint256 number) external;
}

contract RecoveredHistory56Core {
    address private target;

    function setTarget(address value) external {
        target = value;
    }

    function getSatellitePointer(bytes32)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        return (
            target,
            target.codehash,
            false,
            bytes32(0),
            bytes4(0),
            address(0),
            0,
            bytes32(0),
            bytes32(0),
            1
        );
    }
}

contract RecoveredHistory56Governance {
    bytes32 private action;
    H.Context private context_;

    function setAction(bytes32 value, H.Context memory facts) external {
        action = value;
        context_ = facts;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (true, action, 1, context_.scopeHash, context_.oldValueHash, context_.newValueHash);
    }
}

/// @dev Typed Core/governance/predecessor boundaries surround the unchanged history mutation.
/// The oldest predecessor's one leaf is an explicit fixture; subsequent registries forward actual
/// HistoryState reads. This is not a full seven-owner or Archive/Safe hydration fixture.
contract RecoveredHistory56Registry {
    address public immutable core;
    RecoveredHistory56Owner public owner;
    H.Leaf private original;

    constructor(address core_, H.Leaf memory leaf_) {
        core = core_;
        original = leaf_;
    }

    function setOwner(RecoveredHistory56Owner value) external {
        owner = value;
    }

    function gasParameterInfo(bytes32) external pure returns (uint256, uint256, uint8, uint64) {
        return (2_000_000, 100_000, 2, 1);
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistHistory).interfaceId;
    }

    function artistHistoryLane(uint8 kind, bytes32 key) public view returns (bytes32, uint64) {
        if (address(owner) != address(0)) return owner.lane(kind, key);
        require(kind == original.laneKind && key == original.laneKey);
        return (original.recordChainHash, original.sequence + 1);
    }

    function artistRecordChainHash(bytes32 key) external view returns (bytes32 tip) {
        (tip,) = artistHistoryLane(1, key);
    }

    function collectionRecordChainHash(uint256 key) external view returns (bytes32 tip) {
        (tip,) = artistHistoryLane(2, bytes32(key));
    }

    function artistHistoryRecordAt(uint8 kind, bytes32 key, uint64 index)
        external
        view
        returns (bytes32, bytes32)
    {
        if (address(owner) != address(0)) return owner.recordAt(kind, key, index);
        require(kind == original.laneKind && key == original.laneKey && index == original.sequence);
        return (original.recordHash, original.recordChainHash);
    }
}

contract RecoveredHistory56Owner {
    mapping(bytes32 => T.ReplayCell) private replay;
    address public immutable registry;
    address public immutable core;
    address public immutable governance;
    address public immutable coordinator;
    address public immutable archive;
    uint64 public revision;

    constructor(
        address registry_,
        address core_,
        address governance_,
        address coordinator_,
        address archive_
    ) {
        registry = registry_;
        core = core_;
        governance = governance_;
        coordinator = coordinator_;
        archive = archive_;
        Checkpoint.initialize();
    }

    function context(H.Binding memory b) external view returns (H.Context memory) {
        return HistoryState.context(registry, b);
    }

    function importHistory(H.Binding memory b, bytes32 action) external {
        Mutation.applyArtistHistoryImport(
            replay, _owner(), governance, _context(55, governance), b, action
        );
        ++revision;
    }

    function verifyLane(H.Leaf memory leaf) external {
        Mutation.applyArtistHistoryLaneVerification(
            replay, _owner(), governance, _context(56, msg.sender), 0, leaf, new bytes32[](0)
        );
        ++revision;
    }

    function cutover() external {
        Mutation.applyArtistRegistryCutover(replay, _owner(), governance, _context(57, msg.sender));
        ++revision;
    }

    function hydrate(RH.Provenance memory p, AH.OwnerData memory source, bytes32 commitment)
        external
        returns (bytes32 result)
    {
        Imported.installPrefix(p, 2, commitment, revision + 1);
        result = Apply.applyGuards(replay, environment(), 2, source, commitment);
        ++revision;
    }

    function environment() public view returns (RH.OriginEnvironment memory o) {
        o.chainId = block.chainid;
        o.registry = registry;
        o.coordinator = coordinator;
        o.archive = archive;
        o.core = core;
        o.manager = address(0xABCD);
        o.suiteConfigurationHash = keccak256(abi.encode(registry, address(this)));
        for (uint8 i; i < 7; ++i) {
            o.owners[i] = address(uint160(uint256(10000) + i));
            o.ownerCodeHashes[i] = bytes32(uint256(100 + i));
        }
        o.owners[2] = address(this);
        o.ownerCodeHashes[2] = address(this).codehash;
    }

    function authorityCheckpoint() external view returns (CP.Checkpoint memory cp) {
        cp = Checkpoint.checkpoint();
        cp.ownerState = _context(0, address(0)).expected;
    }

    function replayKeyAt(uint256 index) external view returns (bytes32) {
        return Checkpoint.replayKeyAt(index);
    }

    function replayCell(bytes32 key) external view returns (T.ReplayCell memory) {
        return replay[key];
    }

    function key(bytes32 surface, bytes32 scope) external view returns (bytes32) {
        return Keys.replayKey(environment(), 2, AH.Origin(surface, scope));
    }

    function lane(uint8 kind, bytes32 key_) external view returns (bytes32, uint64) {
        return HistoryState.lane(kind, key_);
    }

    function recordAt(uint8 kind, bytes32 key_, uint64 index)
        external
        view
        returns (bytes32, bytes32)
    {
        return HistoryState.at(core, registry, kind, key_, index, 2_000_000);
    }

    function verified(uint8 kind, bytes32 key_) external view returns (bool, bytes32, uint64) {
        return HistoryState.verified(kind, key_);
    }

    function nativeCount() external view returns (uint256) {
        return Native.count();
    }

    function imports() external view returns (bytes32, bytes32, uint64) {
        return (Imported.commitment(), OriginalGuards.commitment(), Imported.importedAtRevision());
    }

    function historical(bytes32 key_) external view returns (RH.ReplayAlias memory) {
        return Imported.historicalAlias(key_);
    }

    function replayPoint(bytes32 key_) external view returns (RH.Point memory) {
        T.ReplayCell memory cell = replay[key_];
        require(cell.status != 0);
        return Imported.activeReplayPoint(
            key_,
            cell.touchedRevision,
            RH.Point(RH.originHash(environment()), 2, cell.touchedRevision)
        );
    }

    /// @dev Explicit post-producer negative control. It is never used to create a successful lane.
    function corruptStatus(bytes32 key_, uint8 status) external {
        replay[key_].status = status;
    }

    function _owner() private view returns (IdentityState.OwnerContext memory) {
        return IdentityState.OwnerContext(
            Hashes.Environment(block.chainid, registry, core, address(0xABCD)),
            coordinator,
            archive,
            RH.ownerDomain(2),
            revision
        );
    }

    function _context(uint16 op, address actor) private view returns (T.ActionContext memory) {
        return T.ActionContext(
            op,
            actor,
            T.Snapshot(
                RH.ownerDomain(2), revision, HistoryState.commitment(), keccak256("no record55-57")
            )
        );
    }
}

/// @notice Actual original55/56/57 replay producers versus recovered guard projection.
/// @dev Exercises the unchanged linked mutations and real history proof checks; host admission,
/// peer-owner suite authorization and final operation60 Archive/Safe behavior are separate tests.
contract StreamArtistRecoveredHistory56GuardsTest {
    RecoveredHistory56Vm private constant vm =
        RecoveredHistory56Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant LANE = keccak256("identity_authority.replay.verified_lane_key");
    bytes32 private constant BOUND = keccak256("identity_authority.replay.import_binding");
    bytes32 private constant CUTOVER = keccak256("identity_authority.replay.one_way_cutover_latch");
    bytes32 private constant IMPORT = keccak256("recovered hydration commitment");
    bytes32 private constant SOURCE_ACTION = keccak256("source governed55");
    bytes32 private constant TARGET_ACTION = keccak256("target governed55");
    RecoveredHistory56Core private core;
    RecoveredHistory56Governance private governance;
    RecoveredHistory56Registry private ancestor;
    RecoveredHistory56Registry private sourceRegistry;
    RecoveredHistory56Registry private destinationRegistry;
    RecoveredHistory56Owner private source;
    RecoveredHistory56Owner private destination;
    H.Leaf private leaf;
    H.Binding private sourceBinding;
    H.Binding private targetBinding;
    H.Context private sourceActionContext;

    function setUp() public {
        vm.roll(10);
        core = new RecoveredHistory56Core();
        governance = new RecoveredHistory56Governance();
        leaf = H.Leaf(
            1,
            bytes32(uint256(1)),
            0,
            keccak256("retained original record"),
            keccak256("original predecessor tip")
        );
        ancestor = new RecoveredHistory56Registry(address(core), leaf);
        sourceRegistry = new RecoveredHistory56Registry(address(core), leaf);
        destinationRegistry = new RecoveredHistory56Registry(address(core), leaf);
        source = new RecoveredHistory56Owner(
            address(sourceRegistry),
            address(core),
            address(governance),
            address(this),
            address(0xAAA1)
        );
        destination = new RecoveredHistory56Owner(
            address(destinationRegistry),
            address(core),
            address(governance),
            address(this),
            address(0xAAA2)
        );
        sourceRegistry.setOwner(source);
        destinationRegistry.setOwner(destination);
        core.setTarget(address(sourceRegistry));
        sourceBinding = H.Binding(
            address(ancestor),
            10,
            HistoryProof.leaf(address(ancestor), leaf),
            keccak256("source manifest")
        );
        sourceActionContext = source.context(sourceBinding);
        governance.setAction(SOURCE_ACTION, sourceActionContext);
        source.importHistory(sourceBinding, SOURCE_ACTION);
        source.verifyLane(leaf);
        core.setTarget(address(destinationRegistry));
        source.cutover();
        targetBinding = H.Binding(
            address(sourceRegistry),
            10,
            HistoryProof.leaf(address(sourceRegistry), leaf),
            keccak256("target manifest")
        );
        governance.setAction(TARGET_ACTION, destination.context(targetBinding));
        destination.importHistory(targetBinding, TARGET_ACTION);
    }

    function testOriginalHistory56ProducesKindOneStatusTwoAndNoNativeRecord() public {
        destination.verifyLane(leaf);
        (bytes32 laneKey, bytes32 boundKey) = _targetKeys();
        _cell(destination.replayCell(laneKey), leaf.recordChainHash, 2);
        _cell(destination.replayCell(boundKey), targetBinding.importRoot, 2);
        require(source.revision() == 3 && destination.revision() == 2, "actual mutation counters");
        require(
            source.nativeCount() == 0 && destination.nativeCount() == 0, "no invented native55-57"
        );
        (bool done, bytes32 tip, uint64 count) = destination.verified(leaf.laneKind, leaf.laneKey);
        require(done && tip == leaf.recordChainHash && count == 1, "actual lane verification");
        bytes32 before_ = keccak256(abi.encode(destination.authorityCheckpoint()));
        (bool ok, bytes memory error) =
            address(destination).call(abi.encodeCall(destination.verifyLane, (leaf)));
        require(
            !ok
                && keccak256(error)
                    == keccak256(abi.encodeWithSelector(T.Replay.selector, laneKey)),
            "original56 remains one-use"
        );
        require(
            keccak256(abi.encode(destination.authorityCheckpoint())) == before_, "failed56 rollback"
        );
    }

    function testRecoveredGuardsPreserveActualDestination56AndOriginalSourceCells() public {
        destination.verifyLane(leaf);
        (RH.Provenance memory p, AH.OwnerData memory data) = _sourceCertificate();
        (bytes32 laneKey, bytes32 boundKey) = _targetKeys();
        bytes32 before_ = keccak256(
            abi.encode(destination.replayCell(laneKey), destination.replayCell(boundKey))
        );
        bytes32 sourceBefore = keccak256(abi.encode(source.authorityCheckpoint(), data.cells));
        require(destination.hydrate(p, data, IMPORT) != 0, "actual status2 accepted");
        require(
            keccak256(abi.encode(destination.replayCell(laneKey), destination.replayCell(boundKey)))
                == before_,
            "target56 never overwritten"
        );
        _cell(destination.replayCell(boundKey), targetBinding.importRoot, 2);
        require(
            sourceBinding.importRoot != targetBinding.importRoot,
            "source binding cannot replace target proof"
        );
        for (uint256 i; i < data.sourceKeys.length; ++i) {
            require(
                keccak256(abi.encode(destination.historical(data.sourceKeys[i]).cell))
                    == keccak256(abi.encode(data.cells[i])),
                "all original source cells retained"
            );
            if (i < 2) {
                bytes32 projected = Keys.replayKey(destination.environment(), 2, data.origins[i]);
                require(
                    keccak256(abi.encode(destination.replayCell(projected)))
                        == keccak256(abi.encode(data.cells[i])),
                    "old55 remains spent"
                );
                require(
                    destination.replayPoint(projected).environmentHash == p.eras[0].originHash,
                    "old55 exact origin"
                );
            }
        }
        (bytes32 a, bytes32 b, uint64 at) = destination.imports();
        require(a == IMPORT && b == IMPORT && at == 3, "atomic guard markers");
        require(
            destination.authorityCheckpoint().replayCount == 6,
            "four actual target keys plus two projected55 keys"
        );
        require(destination.nativeCount() == 0, "hydration appends no old native receipt");
        require(
            keccak256(abi.encode(source.authorityCheckpoint(), data.cells)) == sourceBefore,
            "source unchanged"
        );
    }

    function testRecoveredGuardsMissingDestination56RollsBackThenExactRetry() public {
        (RH.Provenance memory p, AH.OwnerData memory data) = _sourceCertificate();
        bytes32 before_ = keccak256(abi.encode(destination.authorityCheckpoint()));
        _rejectHydrate(p, data);
        (bytes32 a, bytes32 b, uint64 at) = destination.imports();
        require(a == 0 && b == 0 && at == 0, "failed prefix and guards roll back");
        require(
            destination.revision() == 1
                && keccak256(abi.encode(destination.authorityCheckpoint())) == before_,
            "actual target55 intact"
        );
        destination.verifyLane(leaf);
        require(destination.hydrate(p, data, IMPORT) != 0, "same source certificate healthy retry");
    }

    function testRecoveredGuardsRejectStaleDraftStatusOneAfterActual56() public {
        destination.verifyLane(leaf);
        (RH.Provenance memory p, AH.OwnerData memory data) = _sourceCertificate();
        (bytes32 laneKey,) = _targetKeys();
        _cell(destination.replayCell(laneKey), leaf.recordChainHash, 2);
        destination.corruptStatus(laneKey, 1);
        _rejectHydrate(p, data);
        (bytes32 a, bytes32 b, uint64 at) = destination.imports();
        require(a == 0 && b == 0 && at == 0, "counterfeit status1 cannot install");
        destination.corruptStatus(laneKey, 2);
        require(destination.hydrate(p, data, IMPORT) != 0, "actual original status restored");
    }

    function testRecoveredGuardsPreserveUnusedTarget57ForActualLaterCutover() public {
        destination.verifyLane(leaf);
        (RH.Provenance memory p, AH.OwnerData memory data) = _sourceCertificate();
        destination.hydrate(p, data, IMPORT);
        bytes32 targetKey = destination.key(CUTOVER, 0);
        require(destination.replayCell(targetKey).status == 0, "old source57 is historical only");
        core.setTarget(address(ancestor));
        destination.cutover();
        _cell(destination.replayCell(targetKey), keccak256(abi.encode(block.number)), 4);
        RH.Point memory point = destination.replayPoint(targetKey);
        require(
            point.environmentHash == RH.originHash(destination.environment())
                && point.ownerRevision == 4,
            "actual local57 origin"
        );
    }

    function _sourceCertificate()
        private
        view
        returns (RH.Provenance memory p, AH.OwnerData memory data)
    {
        p.origins = new RH.OriginEnvironment[](1);
        p.origins[0] = source.environment();
        p.eras = new RH.Era[](1);
        p.eras[0].originHash = RH.originHash(p.origins[0]);
        for (uint8 i; i < 7; ++i) {
            p.eras[0].checkpoints[i] = CP.Checkpoint(
                RH.CHECKPOINT,
                T.Snapshot(
                    RH.ownerDomain(i), 0, bytes32(uint256(10 + i)), bytes32(uint256(20 + i))
                ),
                0,
                0,
                0,
                0
            );
        }
        p.eras[0].checkpoints[2] = source.authorityCheckpoint();
        data.origins = new AH.Origin[](5);
        data.sourceKeys = new bytes32[](5);
        data.cells = new T.ReplayCell[](5);
        data.origins[0] = AH.Origin(
            keccak256("identity_authority.replay.governance_action"),
            keccak256(
                abi.encode(
                    SOURCE_ACTION,
                    sourceActionContext.scopeHash,
                    sourceActionContext.oldValueHash,
                    sourceActionContext.newValueHash
                )
            )
        );
        data.origins[1] = AH.Origin(
            keccak256("identity_authority.replay.import_binding_key"),
            keccak256(abi.encode(sourceBinding))
        );
        data.origins[2] = AH.Origin(LANE, keccak256(abi.encode(leaf.laneKind, leaf.laneKey)));
        data.origins[3] =
            AH.Origin(BOUND, keccak256(abi.encode(uint256(0), leaf.laneKind, leaf.laneKey)));
        data.origins[4] = AH.Origin(CUTOVER, bytes32(0));
        p.aliases[2] = new RH.ReplayAlias[](5);
        for (uint256 i; i < 5; ++i) {
            bytes32 key = source.key(data.origins[i].surface, data.origins[i].scope);
            require(source.replayKeyAt(i) == key, "every original indexed source guard");
            T.ReplayCell memory cell = source.replayCell(key);
            require(cell.kind == 1 && cell.status == 2, "original55-57 actual consumed shape");
            data.sourceKeys[i] = key;
            data.cells[i] = cell;
            p.aliases[2][i] = RH.ReplayAlias(
                p.eras[0].originHash,
                2,
                data.origins[i].surface,
                data.origins[i].scope,
                key,
                cell,
                RH.Point(p.eras[0].originHash, 2, cell.touchedRevision)
            );
        }
        for (uint256 i = 1; i < 5; ++i) {
            RH.ReplayAlias memory row = p.aliases[2][i];
            uint256 j = i;
            while (j != 0 && p.aliases[2][j - 1].originalKey > row.originalKey) {
                p.aliases[2][j] = p.aliases[2][j - 1];
                --j;
            }
            p.aliases[2][j] = row;
        }
        Provenance.validate(p);
    }

    function _targetKeys() private view returns (bytes32, bytes32) {
        return (
            destination.key(LANE, keccak256(abi.encode(leaf.laneKind, leaf.laneKey))),
            destination.key(BOUND, keccak256(abi.encode(uint256(0), leaf.laneKind, leaf.laneKey)))
        );
    }

    function _cell(T.ReplayCell memory cell, bytes32 commitment, uint64 revision) private pure {
        require(
            cell.commitment == commitment && cell.touchedRevision == revision && cell.kind == 1
                && cell.status == 2,
            "literal original consumed cell"
        );
    }

    function _rejectHydrate(RH.Provenance memory p, AH.OwnerData memory data) private {
        (bool ok, bytes memory error) =
            address(destination).call(abi.encodeCall(destination.hydrate, (p, data, IMPORT)));
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
                    ),
            "exact recovered guard rejection"
        );
    }
}
