// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistIdentityRecoveryReceipts as NativeRecoveryReceipts
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryReceipts.sol";
import {
    StreamArtistIdentityRecoveryTypes as NativeRecoveryTypes
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryTypes.sol";
import {
    StreamArtistAuthorityCheckpoint as Checkpoint
} from "../../../smart-contracts/domains/artist/StreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistDormancyState as Dormancy
} from "../../../smart-contracts/domains/artist/StreamArtistDormancyState.sol";
import {
    StreamArtistIdentityState as Identity
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityState.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

/// @dev Real common owner/native/checkpoint writers behind synthetic admission boundaries.
/// No test claims accepted35, accepted41, complete hydration, or governance/Safe admission.
contract RecoveredNativeInstrumentationOwner is StreamArtistOwner {
    bytes32 public constant ARTIST = bytes32(uint256(42));
    Identity.State private _identities;
    Dormancy.State private _dormancy;
    NativeRecoveryReceipts.State private _recoveryReceipts;
    bool private _lateFailure;

    error InstrumentationLateFailure();

    constructor(address coordinator)
        StreamArtistOwner(
            address(1),
            coordinator,
            address(2),
            keccak256("domain:identity_authority"),
            address(3),
            address(4)
        )
    { }

    function failAfterCommit(bool value) external {
        require(msg.sender == operationCoordinator);
        _lateFailure = value;
    }

    /// @dev Uses the actual original guarded owner methods; the test wrapper is not an op19 producer.
    function append(T.ActionContext calldata c, bytes32[] calldata hashes) external {
        _check(c, 19);
        _commit(c, keccak256(abi.encode(hashes)), keccak256("native fixture state"), 0, 0);
        for (uint256 i; i < hashes.length; ++i) {
            _native(19, hashes[i], ARTIST, 0);
        }
        _finish();
    }

    /// @dev Real common two-receipt35 writer with a synthetic admission boundary. This does not
    /// authenticate an original governance/guardian/Safe recovery and is not an accepted35 test.
    function appendRecoveryPair(T.ActionContext calldata c, bytes32 reason)
        external
        returns (bytes32 primary, bytes32 secondary)
    {
        NativeRecoveryTypes.RecordFields memory fields;
        fields.artistId = ARTIST;
        fields.oldAddress = address(1001);
        fields.newAddress = address(1002);
        fields.vestedAuthorityClass = 1;
        fields.evidenceHash = keccak256("synthetic admitted recovery evidence");
        fields.reasonHash = reason;
        fields.governanceActionId = keccak256(abi.encode(reason));
        fields.recoveredAt = _now();
        bytes32[] memory exclusions = new bytes32[](0);
        fields.supersededRecordsHash = keccak256(
            abi.encode(
                bytes32(0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae),
                exclusions
            )
        );
        NativeRecoveryReceipts.Pair memory pair = _commitIdentityRecovery(
            _recoveryReceipts, c, reason, keccak256(abi.encode(fields)), 0, fields, exclusions
        );
        _finish();
        return (pair.primaryHash, pair.secondaryHash);
    }

    /// @dev Synthetic notice/identity prerequisites. Cancellation below is the real activity writer.
    function seedNotice(bytes32 notice, address incumbent) external {
        require(msg.sender == operationCoordinator && _dormancy.latestNotice[ARTIST] == 0);
        _identities.identities[ARTIST].authorityAddress = incumbent;
        _identities.identities[ARTIST].authorityClass = 1;
        _identities.identities[ARTIST].status = 2;
        _identities.activeIdentity[incumbent] = ARTIST;
        _dormancy.latestNotice[ARTIST] = notice;
        _dormancy.phases[notice] = 1;
        _dormancy.notices[notice].recordHash = notice;
        _dormancy.notices[notice].terms.artistId = ARTIST;
        _dormancy.notices[notice].incumbent = incumbent;
    }

    function cancelByActivity(T.ActionContext calldata c, address signer) external {
        _check(c, 19);
        Identity.OwnerContext memory o;
        o.environment = _environment();
        o.coordinator = operationCoordinator;
        o.archive = archiveV2;
        o.domain = domainId;
        o.revision = _revision;
        (bytes32 stateDelta, bytes32 replayDelta) =
            Dormancy.activity(_dormancy, _identities, _replay, o, ARTIST, signer, 1);
        _commit(c, keccak256("activity fixture"), stateDelta, replayDelta, 0);
        _finish();
    }

    function noticeState(bytes32 notice)
        external
        view
        returns (uint8 phase, uint256 activity, uint8 identityStatus, Dorm.Terminal memory terminal)
    {
        phase = _dormancy.phases[notice];
        activity = _dormancy.activity[ARTIST];
        identityStatus = _identities.identities[ARTIST].status;
        terminal = _dormancy.terminals[_dormancy.terminalForNotice[notice]];
    }

    /// @dev Synthetic source certificate; exercises actual prefix/override installation, not op60 admission.
    function seedCopiedReplay(T.ActionContext calldata c, RH.OwnerProvenance calldata prefix)
        external
        returns (bytes32 key)
    {
        _check(c, 60);
        RH.ReplayAlias memory original = prefix.aliases[0];
        key = _replayKey(original.surface, original.scope);
        _replay[key] = original.cell;
        Checkpoint.noteReplay(key, _replay[key]);
        bytes32 commitment = keccak256(abi.encode(prefix));
        Imported.installOwnerPrefix(prefix, 2, commitment, _revision + 1);
        Imported.installActiveReplayPoint(key, original.originalKey);
        _commit(c, commitment, commitment, 0, 0);
        _finish();
    }

    function overwriteReplay(T.ActionContext calldata c, bytes32 key, bytes32 value) external {
        _check(c, 19);
        _replay[key] = T.ReplayCell(value, _revision + 1, 1, 2);
        // The regression requires this real producer hook, never a direct noteLocalReplay call.
        Checkpoint.noteReplay(key, _replay[key]);
        _commit(c, value, keccak256(abi.encode(key, _replay[key])), key, 0);
        _finish();
    }

    function mutationPoint(bytes32 key) external view returns (RH.Point memory) {
        require(_replay[key].status != 0);
        uint64 revision = _replay[key].touchedRevision;
        return
            Imported.activeReplayPoint(key, revision, RH.Point(currentFixtureOrigin(), 2, revision));
    }

    /// @dev Isolated current-environment sentinel, not a complete governed-suite certificate.
    function currentFixtureOrigin() public view returns (bytes32) {
        return keccak256(
            abi.encode("INSTRUMENTATION_FIXTURE_CURRENT_ORIGIN", block.chainid, address(this))
        );
    }

    function _finish() private view {
        if (_lateFailure) revert InstrumentationLateFailure();
    }
}

contract StreamArtistRecoveredNativeInstrumentationTest {
    function testActualCommonRecoveryPairWriterRecordsNextRevisionBeforeCommitAndRetainsOccurrences()
        external
    {
        RecoveredNativeInstrumentationOwner owner =
            new RecoveredNativeInstrumentationOwner(address(this));
        (bytes32 primary, bytes32 secondary) =
            owner.appendRecoveryPair(_context(owner, 35), keccak256("pair one"));
        assert(owner.ownerStateSnapshotV2().revision == 1 && owner.artistNativeReceiptCount() == 2);
        assert(
            owner.artistNativeReceiptAt(0).operation == 35
                && owner.artistNativeReceiptAt(0).recordHash == primary
        );
        assert(owner.artistNativeReceiptAt(1).recordHash == secondary);
        assert(
            owner.artistNativeReceiptRevisionAt(0) == 1
                && owner.artistNativeReceiptRevisionAt(1) == 1
        );
        T.ActionContext memory c = _context(owner, 35);
        bytes memory request = abi.encodeCall(owner.appendRecoveryPair, (c, keccak256("pair two")));
        owner.failAfterCommit(true);
        _late(address(owner), request);
        assert(owner.artistNativeReceiptCount() == 2);
        assert(
            keccak256(abi.encode(owner.ownerStateSnapshotV2())) == keccak256(abi.encode(c.expected))
        );
        owner.failAfterCommit(false);
        (bool ok, bytes memory output) = address(owner).call(request);
        assert(ok);
        (bytes32 nextPrimary, bytes32 nextSecondary) = abi.decode(output, (bytes32, bytes32));
        assert(nextPrimary != primary && nextSecondary == secondary);
        assert(owner.artistNativeReceiptCount() == 4 && owner.ownerStateSnapshotV2().revision == 2);
        assert(
            owner.artistNativeReceiptAt(1).recordHash == owner.artistNativeReceiptAt(3).recordHash
        );
        assert(
            owner.artistNativeReceiptRevisionAt(1) == 1
                && owner.artistNativeReceiptRevisionAt(3) == 2
        );
    }

    function testNativeOccurrencesShareActualCommitRevisionAndDuplicateHashesKeepIndices()
        external
    {
        RecoveredNativeInstrumentationOwner owner =
            new RecoveredNativeInstrumentationOwner(address(this));
        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = keccak256("duplicate native hash");
        hashes[1] = hashes[0];
        T.ActionContext memory first = _context(owner, 19);
        owner.append(first, hashes);
        assert(owner.ownerStateSnapshotV2().revision == first.expected.revision + 1);
        assert(owner.artistNativeReceiptCount() == 2);
        assert(
            owner.artistNativeReceiptRevisionAt(0) == 1
                && owner.artistNativeReceiptRevisionAt(1) == 1
        );
        H.Receipt memory a = owner.artistNativeReceiptAt(0);
        H.Receipt memory b = owner.artistNativeReceiptAt(1);
        assert(a.operation == 19 && a.artistId == owner.ARTIST() && a.collectionId == 0);
        assert(a.recordHash == hashes[0] && keccak256(abi.encode(a)) == keccak256(abi.encode(b)));
        bytes32[] memory next = new bytes32[](1);
        next[0] = keccak256("next native hash");
        owner.append(_context(owner, 19), next);
        assert(owner.artistNativeReceiptCount() == 3 && owner.artistNativeReceiptRevisionAt(2) == 2);
        assert(
            owner.artistNativeReceiptRevisionAt(0) == 1
                && owner.artistNativeReceiptRevisionAt(1) == 1
        );
    }

    function testNativeZeroHashDoesNotAppendAReceiptOrRevisionSlot() external {
        RecoveredNativeInstrumentationOwner owner =
            new RecoveredNativeInstrumentationOwner(address(this));
        bytes32[] memory hashes = new bytes32[](3);
        hashes[1] = keccak256("one nonzero");
        owner.append(_context(owner, 19), hashes);
        assert(owner.artistNativeReceiptCount() == 1 && owner.artistNativeReceiptRevisionAt(0) == 1);
        assert(owner.artistNativeReceiptAt(0).recordHash == hashes[1]);
        hashes = new bytes32[](1);
        owner.append(_context(owner, 19), hashes);
        assert(owner.ownerStateSnapshotV2().revision == 2);
        assert(owner.artistNativeReceiptCount() == 1 && owner.artistNativeReceiptRevisionAt(0) == 1);
    }

    function testNativeLateFailureRestoresRowsRevisionsAndOwnerCommitForIdenticalRetry() external {
        RecoveredNativeInstrumentationOwner owner =
            new RecoveredNativeInstrumentationOwner(address(this));
        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = keccak256("late first");
        hashes[1] = keccak256("late second");
        T.ActionContext memory c = _context(owner, 19);
        bytes memory request = abi.encodeCall(owner.append, (c, hashes));
        owner.failAfterCommit(true);
        _late(address(owner), request);
        assert(owner.artistNativeReceiptCount() == 0);
        assert(
            keccak256(abi.encode(owner.ownerStateSnapshotV2())) == keccak256(abi.encode(c.expected))
        );
        owner.failAfterCommit(false);
        (bool ok,) = address(owner).call(request);
        assert(ok && owner.artistNativeReceiptCount() == 2);
        assert(
            owner.artistNativeReceiptRevisionAt(0) == 1
                && owner.artistNativeReceiptRevisionAt(1) == 1
        );
        assert(owner.ownerStateSnapshotV2().revision == 1);
    }

    function testRealDormancyActivity42UsesOriginalOwnerNextRevisionAndCancellationHash() external {
        RecoveredNativeInstrumentationOwner owner =
            new RecoveredNativeInstrumentationOwner(address(this));
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = keccak256("earlier owner commit");
        owner.append(_context(owner, 19), hashes);
        bytes32 notice = keccak256("synthetic active notice");
        address incumbent = address(123);
        owner.seedNotice(notice, incumbent);
        T.ActionContext memory c = _context(owner, 19);
        bytes32 expected = _cancellation(owner, notice, incumbent);
        owner.cancelByActivity(c, incumbent);
        _assertCancellation(owner, notice, expected);
        H.Receipt memory receipt = owner.artistNativeReceiptAt(1);
        assert(
            receipt.operation == 42 && receipt.recordHash == expected
                && receipt.artistId == owner.ARTIST()
        );
        assert(owner.artistNativeReceiptRevisionAt(1) == c.expected.revision + 1);
        assert(owner.ownerStateSnapshotV2().revision == 2);
    }

    function testRealDormancyActivity42LateFailureRestoresTerminalNativeAndCheckpointThenRetries()
        external
    {
        RecoveredNativeInstrumentationOwner owner =
            new RecoveredNativeInstrumentationOwner(address(this));
        bytes32 notice = keccak256("synthetic rollback notice");
        address incumbent = address(124);
        owner.seedNotice(notice, incumbent);
        CP.Checkpoint memory before_ = owner.authorityCheckpoint();
        T.ActionContext memory c = _context(owner, 19);
        bytes memory request = abi.encodeCall(owner.cancelByActivity, (c, incumbent));
        bytes32 expected = _cancellation(owner, notice, incumbent);
        owner.failAfterCommit(true);
        _late(address(owner), request);
        assert(owner.artistNativeReceiptCount() == 0);
        assert(keccak256(abi.encode(owner.authorityCheckpoint())) == keccak256(abi.encode(before_)));
        (uint8 phase, uint256 activity, uint8 status, Dorm.Terminal memory t) =
            owner.noticeState(notice);
        assert(phase == 1 && activity == 0 && status == 2 && t.recordHash == 0);
        owner.failAfterCommit(false);
        (bool ok,) = address(owner).call(request);
        assert(ok);
        _assertCancellation(owner, notice, expected);
        assert(
            owner.artistNativeReceiptAt(0).operation == 42
                && owner.artistNativeReceiptRevisionAt(0) == 1
        );
    }

    function testActualCheckpointNoteReplayClearsCopiedPointAndPreservesRollingRoot() external {
        RecoveredNativeInstrumentationOwner owner =
            new RecoveredNativeInstrumentationOwner(address(this));
        RH.OwnerProvenance memory prefix = _prefix();
        bytes32 key = owner.seedCopiedReplay(_context(owner, 60), prefix);
        RH.Point memory old = owner.mutationPoint(key);
        assert(
            old.environmentHash == prefix.eras[0].originHash && old.ownerIndex == 2
                && old.ownerRevision == 90
        );
        CP.Checkpoint memory before_ = owner.authorityCheckpoint();
        bytes32 value = keccak256("new local guard write");
        owner.overwriteReplay(_context(owner, 19), key, value);
        RH.Point memory current = owner.mutationPoint(key);
        assert(
            current.environmentHash == owner.currentFixtureOrigin() && current.ownerIndex == 2
                && current.ownerRevision == 2
        );
        T.ReplayCell memory cell = owner.replayCell(key);
        assert(cell.commitment == value && cell.touchedRevision == 2);
        CP.Checkpoint memory after_ = owner.authorityCheckpoint();
        assert(after_.replayCount == 1 && before_.replayCount == 1);
        assert(
            after_.replayRoot == keccak256(abi.encode(RH.CHECKPOINT, before_.replayRoot, key, cell))
        );
    }

    function testActualCheckpointHookLateFailureRestoresCopiedOverrideAndIdenticalRetry() external {
        RecoveredNativeInstrumentationOwner owner =
            new RecoveredNativeInstrumentationOwner(address(this));
        RH.OwnerProvenance memory prefix = _prefix();
        bytes32 key = owner.seedCopiedReplay(_context(owner, 60), prefix);
        CP.Checkpoint memory before_ = owner.authorityCheckpoint();
        T.ReplayCell memory oldCell = owner.replayCell(key);
        RH.Point memory oldPoint = owner.mutationPoint(key);
        T.ActionContext memory c = _context(owner, 19);
        bytes memory request =
            abi.encodeCall(owner.overwriteReplay, (c, key, keccak256("retry local guard")));
        owner.failAfterCommit(true);
        _late(address(owner), request);
        assert(keccak256(abi.encode(owner.authorityCheckpoint())) == keccak256(abi.encode(before_)));
        assert(keccak256(abi.encode(owner.replayCell(key))) == keccak256(abi.encode(oldCell)));
        assert(keccak256(abi.encode(owner.mutationPoint(key))) == keccak256(abi.encode(oldPoint)));
        owner.failAfterCommit(false);
        (bool ok,) = address(owner).call(request);
        assert(ok && owner.mutationPoint(key).environmentHash == owner.currentFixtureOrigin());
        assert(owner.mutationPoint(key).ownerRevision == 2);
    }

    function _context(RecoveredNativeInstrumentationOwner owner, uint16 operation)
        private
        view
        returns (T.ActionContext memory)
    {
        return T.ActionContext(operation, address(this), owner.ownerStateSnapshotV2());
    }

    function _late(address owner, bytes memory request) private {
        (bool ok, bytes memory reason) = owner.call(request);
        assert(!ok);
        assert(
            keccak256(reason)
                == keccak256(
                    abi.encodeWithSelector(
                        RecoveredNativeInstrumentationOwner.InstrumentationLateFailure.selector
                    )
                )
        );
    }

    function _cancellation(
        RecoveredNativeInstrumentationOwner owner,
        bytes32 notice,
        address incumbent
    ) private view returns (bytes32) {
        Dorm.Terminal memory t;
        t.noticeHash = notice;
        t.actor = incumbent;
        t.authorityClass = 1;
        t.observedAt = uint64(block.timestamp);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"),
                block.chainid,
                owner.artistRegistry(),
                address(owner),
                t,
                uint256(1)
            )
        );
    }

    function _assertCancellation(
        RecoveredNativeInstrumentationOwner owner,
        bytes32 notice,
        bytes32 expected
    ) private view {
        (uint8 phase, uint256 activity, uint8 status, Dorm.Terminal memory t) =
            owner.noticeState(notice);
        assert(phase == 2 && activity == 1 && status == 1 && t.recordHash == expected);
        assert(t.noticeHash == notice && t.authorityClass == 1 && t.observedAt == block.timestamp);
    }

    function _prefix() private pure returns (RH.OwnerProvenance memory p) {
        p.origins = new RH.OriginEnvironment[](1);
        RH.OriginEnvironment memory o;
        o.chainId = 1;
        o.registry = address(500);
        o.coordinator = address(501);
        o.archive = address(502);
        o.core = address(503);
        o.manager = address(504);
        o.suiteConfigurationHash = bytes32(uint256(505));
        for (uint8 i; i < 7; ++i) {
            o.owners[i] = address(uint160(600) + i);
            o.ownerCodeHashes[i] = bytes32(uint256(700) + i);
        }
        p.origins[0] = o;
        p.eras = new RH.OwnerEra[](1);
        p.eras[0].originHash = RH.originHash(o);
        p.eras[0].checkpoint.schema = RH.CHECKPOINT;
        p.eras[0].checkpoint.ownerState =
            T.Snapshot(RH.ownerDomain(2), 100, bytes32(uint256(800)), bytes32(uint256(801)));
        p.eras[0].checkpoint.replayCount = 1;
        p.aliases = new RH.ReplayAlias[](1);
        RH.ReplayAlias memory a;
        a.originHash = RH.originHash(o);
        a.ownerIndex = 2;
        a.surface = keccak256("synthetic.copied.mutable.guard");
        a.scope = bytes32(uint256(900));
        a.originalKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.chainId,
                o.registry,
                o.coordinator,
                o.archive,
                o.owners[2],
                RH.ownerDomain(2),
                a.surface,
                a.scope
            )
        );
        a.cell = T.ReplayCell(bytes32(uint256(901)), 90, 1, 2);
        a.admittedAt = RH.Point(RH.originHash(o), 2, 90);
        p.aliases[0] = a;
    }
}
