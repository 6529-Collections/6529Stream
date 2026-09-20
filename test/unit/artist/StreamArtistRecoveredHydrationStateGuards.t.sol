// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistAuthorityCheckpoint as Checkpoint
} from "../../../smart-contracts/domains/artist/StreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistRecoveredHydrationState as State
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationProvenance.sol";

interface RecoveredStateGuardsVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
}

/// @dev Synthetic host with ordinary storage sentinels around the separate namespaced worker.
/// Calls the original Checkpoint's actual local-write hook; no full owner authorization.
contract RecoveredHydrationStateHarness {
    uint256 public firstSentinel = 17;
    mapping(bytes32 => T.ReplayCell) private replay;
    uint256 public secondSentinel = 29;
    uint64 public revision;
    bytes32 public constant LOCAL = keccak256("synthetic local destination environment");

    constructor(uint64 importRevision) {
        revision = importRevision;
        Checkpoint.initialize();
    }

    function install(RH.Provenance memory p, bytes32 commitment) external {
        State.installPrefix(p, 2, commitment, revision);
    }

    function prefix() external view returns (RH.OwnerProvenance memory, bytes32, uint64) {
        return (State.importedPrefix(), State.commitment(), State.importedAtRevision());
    }

    function environment(bytes32 origin) external view returns (RH.OriginEnvironment memory) {
        return State.environment(origin);
    }

    function historicalAlias(bytes32 key) external view returns (RH.ReplayAlias memory) {
        return State.historicalAlias(key);
    }

    function installArtifact(bytes32 kind, bytes32 key, RH.Point memory point) external {
        State.installArtifact(kind, key, point);
    }

    function artifact(bytes32 kind, bytes32 key) external view returns (RH.Point memory) {
        return State.artifact(kind, key);
    }

    function project(bytes32 currentKey, bytes32 sourceKey) external {
        RH.ReplayAlias memory alias_ = State.historicalAlias(sourceKey);
        replay[currentKey] = alias_.cell;
        Checkpoint.noteReplay(currentKey, replay[currentKey]);
        State.installActiveReplayPoint(currentKey, sourceKey);
    }

    function installReplayPoint(bytes32 currentKey, bytes32 sourceKey) external {
        State.installActiveReplayPoint(currentKey, sourceKey);
    }

    function localMutation(bytes32 key, bytes32 commitment) external {
        ++revision;
        replay[key] = T.ReplayCell(commitment, revision, 1, 2);
        Checkpoint.noteReplay(key, replay[key]);
    }

    function replayPoint(bytes32 key) external view returns (RH.Point memory) {
        T.ReplayCell memory cell = replay[key];
        require(cell.status != 0, "missing actual replay cell");
        return State.activeReplayPoint(
            key, cell.touchedRevision, RH.Point(LOCAL, 2, cell.touchedRevision)
        );
    }

    function cell(bytes32 key) external view returns (T.ReplayCell memory) {
        return replay[key];
    }

    function checkpoint() external view returns (CP.Checkpoint memory) {
        return Checkpoint.checkpoint();
    }
}

/// @dev Deliberately synthetic five-kind getter boundary. It checks complete transport, not the
/// semantic owner eligibility of each nonce kind. Each prefix exposes all32 distinct words.
contract RecoveredHydrationGuardBoundary {
    bytes32 private key;
    T.ReplayCell private cell;

    function setReplay(bytes32 key_, T.ReplayCell memory cell_) external {
        key = key_;
        cell = cell_;
    }

    function authorityCheckpoint() external view returns (CP.Checkpoint memory cp) {
        cp.schema = RH.CHECKPOINT;
        cp.ownerState = T.Snapshot(RH.ownerDomain(2), 8, bytes32(uint256(20)), bytes32(uint256(21)));
        cp.replayRoot = keccak256(abi.encode(key, cell));
        cp.replayCount = 1;
        cp.nonceRoot = bytes32(uint256(22));
        cp.nonceIndexCount = 5;
    }

    function authorityReplayAt(uint256 index) external view returns (bytes32, T.ReplayCell memory) {
        require(index == 0);
        return (key, cell);
    }

    function replayCell(bytes32 key_) external view returns (T.ReplayCell memory) {
        require(key_ == key);
        return cell;
    }

    function authorityNonceIndexAt(uint256 index) external pure returns (CP.NonceIndex memory) {
        require(index < 5);
        return CP.NonceIndex(uint8(index + 1), bytes32(index + 1), 2);
    }

    function authorityNonceWordAt(uint8 kind, bytes32 key_, uint256 index)
        external
        pure
        returns (uint256 prefix, uint256[32] memory words, bool exhausted)
    {
        require(kind > 0 && kind <= 5 && key_ == bytes32(uint256(kind)) && index < 2);
        prefix = 1000 + uint256(kind) * 16 + index;
        for (uint256 i; i < 32; ++i) {
            words[i] = (uint256(kind) << 248) | (index << 240) | (i + 1);
        }
        exhausted = kind == 5;
    }
}

contract RecoveredHydrationGuardHarness {
    function collect(RH.Provenance memory p, uint8 ownerIndex, AH.Origin[] memory origins)
        external
        view
        returns (AH.OwnerData memory, RH.NonceInventory[] memory)
    {
        return Guards.collect(p, ownerIndex, origins);
    }

    function nonces(address owner, CP.Checkpoint memory cp)
        external
        view
        returns (RH.NonceInventory[] memory)
    {
        return Guards.collectNonces(owner, cp);
    }

    function validateNonces(address owner, CP.Checkpoint memory cp, RH.NonceInventory[] memory n)
        external
        view
        returns (bytes32)
    {
        return Provenance.validateNonces(owner, cp, n);
    }
}

/// @notice Focused State and complete guard collector regressions; no actual op60/Safe claim.
contract StreamArtistRecoveredHydrationStateGuardsTest {
    RecoveredStateGuardsVm private constant vm =
        RecoveredStateGuardsVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant COMMITMENT = keccak256("original import commitment");
    bytes32 private constant KIND = keccak256("original semantic record");
    bytes32 private constant RECORD = keccak256("retained semantic record");
    bytes32 private constant SURFACE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant SCOPE = keccak256("exact original scope");
    bytes32 private constant CURRENT_KEY = keccak256("exact projected destination key");
    RecoveredHydrationStateHarness private state;
    RecoveredHydrationGuardBoundary private source;
    RecoveredHydrationGuardHarness private guards;

    function setUp() public {
        state = new RecoveredHydrationStateHarness(3);
        source = new RecoveredHydrationGuardBoundary();
        guards = new RecoveredHydrationGuardHarness();
    }

    function testRecoveredStateExactOwnerSliceOneUseAndUnchangedOrdinarySlots() public {
        RH.Provenance memory p = _provenance();
        state.install(p, COMMITMENT);
        (RH.OwnerProvenance memory got, bytes32 commitment, uint64 at) = state.prefix();
        require(
            keccak256(abi.encode(got)) == keccak256(abi.encode(RH.ownerProvenance(p, 2))),
            "exact owner slice"
        );
        require(
            commitment == COMMITMENT && at == 3 && state.revision() == 3, "real local import clock"
        );
        require(state.firstSentinel() == 17 && state.secondSentinel() == 29, "separate namespace");
        bytes32 before_ = keccak256(abi.encode(got, commitment, at));
        _reject(address(state), abi.encodeCall(state.install, (p, keccak256("second import"))));
        (got, commitment, at) = state.prefix();
        require(keccak256(abi.encode(got, commitment, at)) == before_, "one-use rollback");
    }

    function testRecoveredStateHistoricalEnvironmentAndAliasRoundtrip() public {
        RH.Provenance memory p = _provenance();
        state.install(p, COMMITMENT);
        for (uint256 i; i < p.origins.length; ++i) {
            require(
                keccak256(abi.encode(state.environment(p.eras[i].originHash)))
                    == keccak256(abi.encode(p.origins[i])),
                "original environment"
            );
        }
        for (uint256 i; i < p.aliases[2].length; ++i) {
            RH.ReplayAlias memory a = state.historicalAlias(p.aliases[2][i].originalKey);
            require(
                keccak256(abi.encode(a)) == keccak256(abi.encode(p.aliases[2][i])), "original alias"
            );
            require(
                a.cell.touchedRevision == 90
                    && a.admittedAt.environmentHash == p.eras[0].originHash,
                "old mutation clock preserved"
            );
        }
        _reject(
            address(state), abi.encodeCall(state.environment, (keccak256("unknown environment")))
        );
        _reject(
            address(state),
            abi.encodeCall(state.historicalAlias, (keccak256("unknown original key")))
        );
    }

    function testRecoveredStateMissingArtifactNeverFallsBackToLocalOrigin() public {
        _reject(address(state), abi.encodeCall(state.artifact, (KIND, RECORD)));
        RH.Provenance memory p = _provenance();
        state.install(p, COMMITMENT);
        _reject(address(state), abi.encodeCall(state.artifact, (KIND, RECORD)));
        _reject(address(state), abi.encodeCall(state.artifact, (bytes32(0), RECORD)));
        _reject(address(state), abi.encodeCall(state.artifact, (KIND, bytes32(0))));
    }

    function testRecoveredStateArtifactIsIdempotentButConflictingPointRejects() public {
        RH.Provenance memory p = _provenance();
        state.install(p, COMMITMENT);
        RH.Point memory point = RH.Point(p.eras[0].originHash, 2, 90);
        state.installArtifact(KIND, RECORD, point);
        state.installArtifact(KIND, RECORD, point);
        RH.Point memory conflict = RH.Point(p.eras[0].originHash, 2, 91);
        _reject(address(state), abi.encodeCall(state.installArtifact, (KIND, RECORD, conflict)));
        require(
            keccak256(abi.encode(state.artifact(KIND, RECORD))) == keccak256(abi.encode(point)),
            "first exact point retained"
        );
        // The same hash in a distinct semantic namespace has its own genuine occurrence.
        state.installArtifact(keccak256("different artifact kind"), RECORD, conflict);
    }

    function testRecoveredStateArtifactRejectsWrongOwnerUnknownEraAndOutOfBounds() public {
        RH.Provenance memory p = _provenance();
        state.install(p, COMMITMENT);
        RH.Point memory point = RH.Point(p.eras[0].originHash, 5, 90);
        _reject(address(state), abi.encodeCall(state.installArtifact, (KIND, RECORD, point)));
        point = RH.Point(keccak256("missing era"), 2, 90);
        _reject(address(state), abi.encodeCall(state.installArtifact, (KIND, RECORD, point)));
        point = RH.Point(p.eras[0].originHash, 2, 101);
        _reject(address(state), abi.encodeCall(state.installArtifact, (KIND, RECORD, point)));
        point.ownerRevision = 0;
        _reject(address(state), abi.encodeCall(state.installArtifact, (KIND, RECORD, point)));
    }

    function testRecoveredStatePreImportAuxiliaryPointRetainsLaterEra() public {
        RH.Provenance memory p = _provenance();
        state.install(p, COMMITMENT);
        RH.Point memory preparation = RH.Point(p.eras[1].originHash, 2, 2);
        require(preparation.ownerRevision < p.eras[1].lowerRevisions[2], "real55 before local60");
        state.installArtifact(KIND, RECORD, preparation);
        require(
            keccak256(abi.encode(state.artifact(KIND, RECORD)))
                == keccak256(abi.encode(preparation)),
            "auxiliary is not native suffix"
        );
    }

    function testRecoveredStateInheritedHighRevisionBecomesLowLocalPointOnlyAfterWrite() public {
        RH.Provenance memory p = _provenance();
        state.install(p, COMMITMENT);
        bytes32 original = _currentSourceKey(p);
        state.project(CURRENT_KEY, original);
        RH.Point memory imported = state.replayPoint(CURRENT_KEY);
        require(
            imported.environmentHash == p.eras[0].originHash && imported.ownerRevision == 90,
            "inherited origin override"
        );
        require(
            state.cell(CURRENT_KEY).touchedRevision == 90 && state.revision() == 3,
            "no counter floor"
        );
        bytes32 historic = keccak256(abi.encode(state.historicalAlias(original)));
        state.localMutation(CURRENT_KEY, keccak256("actual later local guard"));
        RH.Point memory local = state.replayPoint(CURRENT_KEY);
        require(
            local.environmentHash == state.LOCAL() && local.ownerRevision == 4
                && local.ownerIndex == 2,
            "actual local hook clears override"
        );
        require(
            state.cell(CURRENT_KEY).touchedRevision == 4 && state.revision() == 4,
            "actual local counter"
        );
        require(
            keccak256(abi.encode(state.historicalAlias(original))) == historic,
            "historical alias immutable"
        );
        require(
            state.checkpoint().replayCount == 1, "overwrite retains actual checkpoint key inventory"
        );
    }

    function testRecoveredStateEqualNumericRevisionStillClearsInheritedOrigin() public {
        RH.Provenance memory p = _provenance();
        RecoveredHydrationStateHarness other = new RecoveredHydrationStateHarness(89);
        other.install(p, COMMITMENT);
        other.project(CURRENT_KEY, _currentSourceKey(p));
        require(other.replayPoint(CURRENT_KEY).ownerRevision == 90, "old raw90");
        other.localMutation(CURRENT_KEY, keccak256("new local raw90"));
        RH.Point memory local = other.replayPoint(CURRENT_KEY);
        require(
            local.ownerRevision == 90 && local.environmentHash == other.LOCAL(),
            "equal raw values are different origins"
        );
    }

    function testRecoveredStateActiveReplayPointIsOneUseAndRequiresRetainedSource() public {
        RH.Provenance memory p = _provenance();
        state.install(p, COMMITMENT);
        bytes32 original = _currentSourceKey(p);
        _reject(
            address(state),
            abi.encodeCall(state.installReplayPoint, (CURRENT_KEY, keccak256("missing source key")))
        );
        _reject(address(state), abi.encodeCall(state.installReplayPoint, (bytes32(0), original)));
        state.project(CURRENT_KEY, original);
        RH.Point memory before_ = state.replayPoint(CURRENT_KEY);
        _reject(address(state), abi.encodeCall(state.installReplayPoint, (CURRENT_KEY, original)));
        require(
            keccak256(abi.encode(state.replayPoint(CURRENT_KEY))) == keccak256(abi.encode(before_)),
            "saved point unchanged"
        );
    }

    function testRecoveredGuardCollectorRetainsExactOriginsCellsAndAllNonceKinds() public {
        RH.Provenance memory p = _provenance();
        AH.Origin[] memory origins = _origins();
        (AH.OwnerData memory got, RH.NonceInventory[] memory n) = guards.collect(p, 2, origins);
        require(
            got.origins.length == 1 && got.sourceKeys.length == 1 && got.cells.length == 1,
            "complete current guards"
        );
        require(
            got.origins[0].surface == SURFACE && got.origins[0].scope == SCOPE,
            "exact witness preimage"
        );
        require(got.sourceKeys[0] == _currentSourceKey(p), "original current key");
        require(
            got.cells[0].touchedRevision == 90 && p.eras[1].checkpoints[2].ownerState.revision == 8,
            "inherited source guard clock"
        );
        _assertNonces(n);
    }

    function testRecoveredNonceCollectorIncludesEveryWordAndExhaustion() public {
        RH.NonceInventory[] memory n = guards.nonces(address(source), source.authorityCheckpoint());
        _assertNonces(n);
        require(
            guards.validateNonces(address(source), source.authorityCheckpoint(), n) != 0,
            "independent exact getter validation"
        );
    }

    function testRecoveredNonceInventoryOmissionAndAlteredAncestorsReject() public {
        CP.Checkpoint memory cp = source.authorityCheckpoint();
        RH.NonceInventory[] memory n = guards.nonces(address(source), cp);
        RH.NonceInventory[] memory short_ = new RH.NonceInventory[](4);
        for (uint256 i; i < 4; ++i) {
            short_[i] = n[i];
        }
        _reject(
            address(guards), abi.encodeCall(guards.validateNonces, (address(source), cp, short_))
        );
        n[3].words[1].words[31] ^= 1;
        _reject(address(guards), abi.encodeCall(guards.validateNonces, (address(source), cp, n)));
        n = guards.nonces(address(source), cp);
        n[4].words[1].exhausted = false;
        _reject(address(guards), abi.encodeCall(guards.validateNonces, (address(source), cp, n)));
        n = guards.nonces(address(source), cp);
        n[0].words = new AH.NonceWord[](1);
        _reject(address(guards), abi.encodeCall(guards.validateNonces, (address(source), cp, n)));
    }

    function testRecoveredNonceCollectorRejectsDuplicateActualPrefix() public {
        (uint256 prefix, uint256[32] memory words, bool exhausted) =
            source.authorityNonceWordAt(2, bytes32(uint256(2)), 0);
        vm.mockCall(
            address(source),
            abi.encodeWithSignature(
                "authorityNonceWordAt(uint8,bytes32,uint256)",
                uint8(2),
                bytes32(uint256(2)),
                uint256(1)
            ),
            abi.encode(prefix, words, exhausted)
        );
        _reject(
            address(guards),
            abi.encodeCall(guards.nonces, (address(source), source.authorityCheckpoint()))
        );
    }

    function testRecoveredNonceCollectorRejectsDuplicateActualIndex() public {
        CP.NonceIndex memory duplicate = source.authorityNonceIndexAt(3);
        vm.mockCall(
            address(source),
            abi.encodeWithSignature("authorityNonceIndexAt(uint256)", uint256(4)),
            abi.encode(duplicate)
        );
        _reject(
            address(guards),
            abi.encodeCall(guards.nonces, (address(source), source.authorityCheckpoint()))
        );
    }

    function testRecoveredNonceCollectorRejectsStaleCheckpointAndImpossibleCount() public {
        CP.Checkpoint memory cp = source.authorityCheckpoint();
        cp.nonceIndexCount = 4;
        _reject(address(guards), abi.encodeCall(guards.nonces, (address(source), cp)));
        cp.nonceIndexCount = RH.MAX_NONCE_INDICES + 1;
        _reject(address(guards), abi.encodeCall(guards.nonces, (address(source), cp)));
    }

    function testRecoveredGuardCollectorRejectsOmissionWrongPreimageAndMissingAlias() public {
        RH.Provenance memory p = _provenance();
        AH.Origin[] memory origins = new AH.Origin[](0);
        _reject(address(guards), abi.encodeCall(guards.collect, (p, uint8(2), origins)));
        origins = _origins();
        origins[0].scope = keccak256("wrong scope");
        _reject(address(guards), abi.encodeCall(guards.collect, (p, uint8(2), origins)));
        origins = _origins();
        p.aliases[2] = new RH.ReplayAlias[](0);
        _reject(address(guards), abi.encodeCall(guards.collect, (p, uint8(2), origins)));
    }

    function testRecoveredGuardCollectorRejectsChangedIndexedAndLiveCellJoin() public {
        RH.Provenance memory p = _provenance();
        AH.Origin[] memory origins = _origins();
        bytes32 key = _currentSourceKey(p);
        T.ReplayCell memory changed = T.ReplayCell(bytes32(uint256(999)), 90, 1, 2);
        vm.mockCall(
            address(source),
            abi.encodeWithSignature("replayCell(bytes32)", key),
            abi.encode(changed)
        );
        _reject(address(guards), abi.encodeCall(guards.collect, (p, uint8(2), origins)));
    }

    function _provenance() private returns (RH.Provenance memory p) {
        p.origins = new RH.OriginEnvironment[](2);
        p.eras = new RH.Era[](2);
        for (uint256 i; i < 2; ++i) {
            RH.OriginEnvironment memory o;
            o.chainId = block.chainid;
            o.registry = address(uint160(100 + i));
            o.coordinator = address(uint160(200 + i));
            o.archive = address(uint160(300 + i));
            o.core = address(400);
            o.manager = address(401);
            o.suiteConfigurationHash = bytes32(uint256(500 + i));
            for (uint8 j; j < 7; ++j) {
                o.owners[j] = address(uint160(600 + i * 10 + j));
                o.ownerCodeHashes[j] = bytes32(uint256(700 + j));
            }
            if (i == 1) {
                o.owners[2] = address(source);
                o.ownerCodeHashes[2] = address(source).codehash;
            }
            p.origins[i] = o;
            p.eras[i].originHash = RH.originHash(o);
            if (i == 1) p.eras[i].priorImportCommitment = keccak256("earlier import");
            for (uint8 j; j < 7; ++j) {
                p.eras[i].checkpoints[j] = CP.Checkpoint(
                    RH.CHECKPOINT,
                    T.Snapshot(
                        RH.ownerDomain(j),
                        i == 0 ? 100 : 8,
                        bytes32(uint256(800 + j)),
                        bytes32(uint256(900 + j))
                    ),
                    0,
                    0,
                    0,
                    0
                );
                p.eras[i].lowerRevisions[j] = i == 0 ? 0 : 3;
            }
        }
        RH.Point memory original = RH.Point(p.eras[0].originHash, 2, 90);
        p.aliases[2] = new RH.ReplayAlias[](2);
        for (uint256 i; i < 2; ++i) {
            p.aliases[2][i] = RH.ReplayAlias(
                p.eras[i].originHash,
                2,
                SURFACE,
                SCOPE,
                Guards.replayKey(p.origins[i], 2, AH.Origin(SURFACE, SCOPE)),
                T.ReplayCell(keccak256("original cell"), 90, 1, 2),
                original
            );
        }
        source.setReplay(p.aliases[2][1].originalKey, p.aliases[2][1].cell);
        p.eras[0].checkpoints[2].replayCount = 1;
        p.eras[1].checkpoints[2] = source.authorityCheckpoint();
        if (p.aliases[2][0].originalKey > p.aliases[2][1].originalKey) {
            RH.ReplayAlias memory a = p.aliases[2][0];
            p.aliases[2][0] = p.aliases[2][1];
            p.aliases[2][1] = a;
        }
        p.journals[2] = new RH.JournalEntry[](3);
        p.journals[2][0] = RH.JournalEntry(
            RH.Position(original, 0), H.Receipt(35, bytes32(uint256(1)), 0, RECORD)
        );
        p.journals[2][1] = RH.JournalEntry(
            RH.Position(original, 1),
            H.Receipt(35, bytes32(uint256(1)), 0, keccak256("secondary original"))
        );
        p.journals[2][2] = RH.JournalEntry(
            RH.Position(RH.Point(p.eras[1].originHash, 2, 5), 0),
            H.Receipt(32, bytes32(uint256(1)), 0, keccak256("later actual row"))
        );
        p.eras[0].nativeCounts[2] = 2;
        p.eras[1].nativeCounts[2] = 1;
        Provenance.validate(p);
    }

    function _origins() private pure returns (AH.Origin[] memory origins) {
        origins = new AH.Origin[](1);
        origins[0] = AH.Origin(SURFACE, SCOPE);
    }

    function _currentSourceKey(RH.Provenance memory p) private pure returns (bytes32) {
        return Guards.replayKey(p.origins[1], 2, AH.Origin(SURFACE, SCOPE));
    }

    function _assertNonces(RH.NonceInventory[] memory n) private pure {
        require(n.length == 5, "all indexed nonce kinds");
        for (uint256 i; i < 5; ++i) {
            uint8 kind = uint8(i + 1);
            require(
                n[i].index.kind == kind && n[i].index.key == bytes32(i + 1)
                    && n[i].index.prefixCount == 2 && n[i].words.length == 2,
                "exact complete index"
            );
            for (uint256 j; j < 2; ++j) {
                require(
                    n[i].words[j].prefix == 1000 + uint256(kind) * 16 + j, "exact original prefix"
                );
                require(n[i].words[j].exhausted == (kind == 5), "exact exhausted flag");
                for (uint256 k; k < 32; ++k) {
                    require(
                        n[i].words[j].words[k] == ((uint256(kind) << 248) | (j << 240) | (k + 1)),
                        "all leaf and ancestor words"
                    );
                }
            }
        }
    }

    function _reject(address target, bytes memory data) private {
        (bool ok, bytes memory error) = target.call(data);
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
                    ),
            "exact source/state rejection"
        );
    }
}
