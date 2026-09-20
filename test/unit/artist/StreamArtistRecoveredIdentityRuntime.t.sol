// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveredRuntimeReadsTest } from "./StreamArtistRecoveredRuntimeReads.t.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Identity
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveryRewindRecordReads as Records
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryRewindRecordReads.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistIdentityRevisionTypes as Doc
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationGuards as Keys
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistRotationHashes as RotationHashes
} from "../../../smart-contracts/domains/artist/StreamArtistRotationHashes.sol";

import {
    StreamArtistRecoveryActionTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistLivingDormancyReads as LivingDormancy
} from "../../../smart-contracts/domains/artist/StreamArtistLivingDormancyReads.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDormancy.sol";

contract RecoveredIdentityRuntimeHarness {
    function livingDormancy(
        W.EnvironmentV3 memory e,
        Dorm.Notice memory n,
        Dorm.Terminal memory t,
        V.Snapshot memory v
    ) external view returns (bytes32 proof) {
        (, proof) = LivingDormancy.withInitialHistory(
            e.identityOwner, e.registry, e.chainId, n, t, v, bytes32(0)
        );
    }

    function preparation(Runtime.Context memory c, A.Association memory a)
        external
        view
        returns (Runtime.OriginFact memory)
    {
        return Identity.preparation(c, a);
    }

    function guardian(Runtime.Context memory c, GH.Entry memory entry, R.GuardianRecord memory r)
        external
        view
        returns (Runtime.OriginFact memory)
    {
        return Identity.guardian(c, entry, r);
    }

    function step(
        Runtime.Context memory c,
        GH.Entry memory entry,
        R.GuardianRecord memory r,
        uint64 previousRevision,
        bytes32 previousCommitment
    ) external view returns (Runtime.OriginFact memory) {
        return Identity.guardianStep(c, entry, r, previousRevision, previousCommitment);
    }

    function vesting(Runtime.Context memory c, V.Snapshot memory v)
        external
        view
        returns (Runtime.OriginFact memory)
    {
        return Identity.vesting(c, v);
    }

    function nativeFact(Runtime.Context memory c, uint16 operation, bytes32 artist, bytes32 key)
        external
        view
        returns (Runtime.ReceiptFact memory)
    {
        return Identity.nativeFact(c, operation, artist, key);
    }

    function revision(W.EnvironmentV3 memory e, bytes32 artist, uint256 index)
        external
        view
        returns (Records.Facts memory)
    {
        return Records.read(e, W.RecordKind.IDENTITY_REVISION, artist, index);
    }
}

/// @notice Consumer proofs at an explicitly mocked, pinned current-owner boundary.
/// @dev Reuses the twelve generic runtime controls. These cases prove original-domain and
/// cross-era reader joins; they do not claim actual operation60, Safe admission or end-to-end recovery.
contract StreamArtistRecoveredIdentityRuntimeTest is StreamArtistRecoveredRuntimeReadsTest {
    struct GuardianFixture {
        RH.OwnerProvenance old;
        Runtime.Context clock;
        GH.Entry older;
        GH.Entry newer;
        R.GuardianRecord oldRecord;
        R.GuardianRecord newRecord;
        V.Snapshot vested;
    }

    function testRecoveredIdentityGuardianUsesOriginalOwnerAndRegistry() public {
        GuardianFixture memory f = _guardians();
        RecoveredIdentityRuntimeHarness target = new RecoveredIdentityRuntimeHarness();
        Runtime.OriginFact memory origin = target.guardian(f.clock, f.older, f.oldRecord);
        require(
            origin.point.ownerRevision == 40 && origin.environment.registry != e.registry,
            "exact old record and original guardian-history domain"
        );
        f.older.commitment = Identity.guardianHash(f.clock.current, f.older);
        _rejectIdentity(target, abi.encodeCall(target.guardian, (f.clock, f.older, f.oldRecord)));
    }

    function testRecoveredIdentityGuardianOrderCrossesHighSourceToLowDestinationRevision() public {
        GuardianFixture memory f = _guardians();
        RecoveredIdentityRuntimeHarness target = new RecoveredIdentityRuntimeHarness();
        Runtime.OriginFact memory next =
            target.step(f.clock, f.newer, f.newRecord, 40, f.older.commitment);
        require(
            next.point.ownerRevision == 2
                && next.point.environmentHash == RH.originHash(f.clock.current),
            "source40 before actual destination2"
        );
        _rejectIdentity(
            target,
            abi.encodeCall(
                target.step, (f.clock, f.newer, f.newRecord, uint64(39), f.older.commitment)
            )
        );
        _rejectIdentity(
            target,
            abi.encodeCall(
                target.step, (f.clock, f.newer, f.newRecord, uint64(40), bytes32(uint256(99)))
            )
        );
    }

    function testRecoveredIdentityVestingRetainsExactHistoricalGuardianPrefix() public {
        GuardianFixture memory f = _guardians();
        RecoveredIdentityRuntimeHarness target = new RecoveredIdentityRuntimeHarness();
        Runtime.OriginFact memory point = target.vesting(f.clock, f.vested);
        require(
            point.point.ownerRevision == 50 && f.clock.checkpoint.ownerState.revision == 8,
            "source vesting does not inherit destination clock"
        );
        f.vested.guardians = GH.Head(2, 2, f.newer.commitment);
        f.vested.commitment = Identity.vestingHash(f.old.origins[0], f.vested);
        _rejectIdentity(target, abi.encodeCall(target.vesting, (f.clock, f.vested)));
    }

    function testRecoveredIdentityMissingOrRelabelledVestingOriginRejects() public {
        GuardianFixture memory f = _guardians();
        RecoveredIdentityRuntimeHarness target = new RecoveredIdentityRuntimeHarness();
        bytes memory query = abi.encodeWithSignature(
            "recoveredHydrationAuxiliaryPoint(bytes32,bytes32)",
            keccak256("identity_authority.hydration.guardian_vesting"),
            f.vested.transitionRecordHash
        );
        vm.mockCall(
            e.identityOwner, query, abi.encode(RH.Point(RH.originHash(f.clock.current), 2, 50))
        );
        (bool ok,) = address(target).call(abi.encodeCall(target.vesting, (f.clock, f.vested)));
        require(!ok, "same raw revision in wrong era rejected");
        vm.mockCallRevert(
            e.identityOwner,
            query,
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
        _rejectIdentity(target, abi.encodeCall(target.vesting, (f.clock, f.vested)));
    }

    function testRecoveredIdentityOriginal25AdmitsOriginalNonceAndChainAtLogicalIndex() public {
        (
            RecoveredIdentityRuntimeHarness target,
            Doc.Record memory r,
            RH.OwnerProvenance memory old
        ) = _revision();
        Records.Facts memory f = target.revision(e, ARTIST, 0);
        require(
            f.selected.recordHash == r.recordHash && f.selected.nativeIndex == 0
                && f.admissionRevision == 40 && f.eligible && f.valueHash == r.revisedRecordHash,
            "original25 with no invented current signature"
        );
        old.aliases[0].cell.commitment = bytes32(uint256(17));
        _prefix(2, old, IMPORT, 1);
        (bool ok,) = address(target).call(abi.encodeCall(target.revision, (e, ARTIST, uint256(0))));
        require(!ok, "wrong original nonce digest rejected");
    }

    function testRecoveredIdentityRuntimeDoesNotApplyExportJournalLimit() public {
        GuardianFixture memory f = _guardians();
        // A valid import can continue growing. Only the next export is transport bounded.
        uint256 localCount = RH.MAX_JOURNAL_ENTRIES + 1;
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("artistNativeReceiptCount()"),
            abi.encode(localCount)
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("artistNativeReceiptAt(uint256)"),
            abi.encode(H.Receipt(19, bytes32(uint256(999)), 0, bytes32(uint256(1000))))
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("artistNativeReceiptRevisionAt(uint256)"),
            abi.encode(uint64(2))
        );
        // Replace the earlier exact index0 fixture as well as the selector-wide default.
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(0)),
            abi.encode(H.Receipt(19, bytes32(uint256(999)), 0, bytes32(uint256(1000))))
        );
        f.clock = harness.load(e, 2);
        RecoveredIdentityRuntimeHarness target = new RecoveredIdentityRuntimeHarness();
        Runtime.ReceiptFact memory row = target.nativeFact(f.clock, 28, ARTIST, f.older.recordHash);
        require(
            row.position.point.ownerRevision == 40
                && Runtime.logicalCount(f.clock) > RH.MAX_JOURNAL_ENTRIES,
            "actual suffix growth is not capped by export capacity"
        );
    }

    function testRecoveredIdentityUnusedPreparationRetainsOriginalReplayAndEnvironment() public {
        RH.OwnerProvenance memory old = _fixture(2);
        old.journal = new RH.JournalEntry[](0);
        old.eras[0].nativeCount = 0;
        A.Association memory a;
        a.artistId = ARTIST;
        a.action.actionId = keccak256("unexecuted original governance action");
        a.associationHash = keccak256("original preparation commitment");
        a.ownerRevision = 90;
        bytes32 surface = keccak256("identity_authority.replay.recovery_preparation");
        old.aliases[0].surface = surface;
        old.aliases[0].scope = a.action.actionId;
        old.aliases[0].originalKey =
            Keys.replayKey(old.origins[0], 2, AH.Origin(surface, a.action.actionId));
        old.aliases[0].cell.commitment = a.associationHash;
        _prefix(2, old, IMPORT, 1);
        bytes memory query = abi.encodeWithSignature(
            "recoveredHydrationAuxiliaryPoint(bytes32,bytes32)", surface, a.action.actionId
        );
        vm.mockCall(e.identityOwner, query, abi.encode(old.aliases[0].admittedAt));
        RecoveredIdentityRuntimeHarness target = new RecoveredIdentityRuntimeHarness();
        Runtime.Context memory clock = harness.load(e, 2);
        Runtime.OriginFact memory original = target.preparation(clock, a);
        require(
            original.point.ownerRevision == 90
                && original.environment.registry == old.origins[0].registry,
            "unused original action has no fabricated native35 or current domain"
        );
        a.associationHash = keccak256("replacement action commitment");
        _rejectIdentity(target, abi.encodeCall(target.preparation, (clock, a)));
        a.associationHash = old.aliases[0].cell.commitment;
        vm.mockCall(
            e.identityOwner, query, abi.encode(RH.Point(RH.originHash(clock.current), 2, 2))
        );
        (bool ok,) = address(target).call(abi.encodeCall(target.preparation, (clock, a)));
        require(!ok, "original preparation cannot be rebound to a current point");
        vm.mockCall(e.identityOwner, query, abi.encode(old.aliases[0].admittedAt));
        require(
            target.preparation(clock, a).point.ownerRevision == 90,
            "identical original proof restored"
        );
    }

    function testRecoveredLivingDormancyUsesOriginal32BeforeCurrent43WithoutNative32() public {
        _fixture(5);
        GuardianFixture memory f = _guardians();
        RecoveredIdentityRuntimeHarness target = new RecoveredIdentityRuntimeHarness();
        R.RotationRecord memory r;
        r.terms.artistId = ARTIST;
        r.terms.oldAddress = f.vested.oldAddress;
        r.terms.newAddress = f.vested.newAddress;
        r.oldNonce = 12;
        r.effectiveWindow = 72 hours;
        r.standingTail = 30 days;
        r.timingRevision = 1;
        r.transition.artistId = ARTIST;
        r.transition.phase = 2;
        r.transition.stagedAt = 2;
        r.transition.contestEndsAt = 2 + r.effectiveWindow;
        r.transition.executedAt = r.transition.contestEndsAt;
        r.transition.postWindowEndsAt = r.transition.executedAt + r.effectiveWindow;
        r.recordHash = RotationHashes.rotationRecord(
            Identity.hashes(f.old.origins[0]),
            r.terms,
            r.oldNonce,
            r.transition.stagedAt,
            r.transition.contestEndsAt
        );
        r.transition.recordHash = r.recordHash;
        f.vested.operationId = 32;
        f.vested.transitionRecordHash = r.recordHash;
        f.vested.executedAt = r.transition.executedAt;
        f.vested.commitment = Identity.vestingHash(f.old.origins[0], f.vested);
        f.old.journal[1].receipt = H.Receipt(29, ARTIST, 0, r.recordHash);
        f.old.journal[1].position.point.ownerRevision = 45;
        _prefix(2, f.old, IMPORT, 1);
        _mockVestingPoint(f.vested.transitionRecordHash, RH.Point(f.old.eras[0].originHash, 2, 50));
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("rotationRecord(bytes32)", r.recordHash),
            abi.encode(r)
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature(
                "guardianVestingSnapshot(bytes32,bytes32)", ARTIST, r.recordHash
            ),
            abi.encode(f.vested)
        );

        Dorm.Notice memory n;
        n.terms.artistId = ARTIST;
        n.recordHash = keccak256("caller-authenticated current notice");
        n.incumbent = f.vested.newAddress;
        n.initiatedAt = r.transition.postWindowEndsAt + 1;
        Dorm.Terminal memory t;
        t.noticeHash = n.recordHash;
        t.recordHash = keccak256("caller-authenticated current completion");
        t.authorityClass = 3;
        t.plan.authorityClass = 3;
        t.plan.authority = address(74);
        t.delegationEpoch = 1;
        t.observedAt = n.initiatedAt + 1;
        V.Snapshot memory child;
        child.artistId = ARTIST;
        child.transitionRecordHash = t.recordHash;
        child.operationId = 43;
        child.ownerRevision = 3;
        child.executedAt = t.observedAt;
        child.oldAddress = n.incumbent;
        child.newAddress = t.plan.authority;
        child.authorityClass = 3;
        child.guardians = f.vested.guardians;
        child.previousTransitionRecordHash = r.recordHash;
        child.previousCommitment = f.vested.commitment;
        child.commitment = Identity.vestingHash(f.clock.current, child);
        _mockVestingPoint(
            child.transitionRecordHash, RH.Point(RH.originHash(f.clock.current), 2, 3)
        );
        bytes32 proof = target.livingDormancy(e, n, t, child);
        require(
            proof != 0 && f.vested.ownerRevision > child.ownerRevision,
            "source32 revision50 precedes destination43 revision3 via actual origins"
        );

        // The leaf receives caller-authenticated 41/43 facts. It must independently reject
        // replacing its original29 hash domain while retaining every stored body field.
        R.RotationRecord memory corrupted = abi.decode(abi.encode(r), (R.RotationRecord));
        corrupted.recordHash = RotationHashes.rotationRecord(
            Identity.hashes(f.clock.current),
            r.terms,
            r.oldNonce,
            r.transition.stagedAt,
            r.transition.contestEndsAt
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("rotationRecord(bytes32)", r.recordHash),
            abi.encode(corrupted)
        );
        (bool ok,) = address(target).call(abi.encodeCall(target.livingDormancy, (e, n, t, child)));
        require(!ok, "old32 cannot be rebound to destination domain");
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("rotationRecord(bytes32)", r.recordHash),
            abi.encode(r)
        );
        require(
            target.livingDormancy(e, n, t, child) == proof, "identical original history restores"
        );
    }

    function _mockVestingPoint(bytes32 key, RH.Point memory point) private {
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature(
                "recoveredHydrationAuxiliaryPoint(bytes32,bytes32)",
                keccak256("identity_authority.hydration.guardian_vesting"),
                key
            ),
            abi.encode(point)
        );
    }

    function _guardians() private returns (GuardianFixture memory f) {
        f.old = _fixture(2);
        Runtime.Context memory initial = harness.load(e, 2);
        f.oldRecord.terms.artistId = ARTIST;
        f.oldRecord.terms.guardians = new address[](1);
        f.oldRecord.terms.guardians[0] = address(71);
        f.oldRecord.terms.approvalThreshold = 1;
        f.oldRecord.signer = address(72);
        f.oldRecord.authorityClass = 1;
        f.oldRecord.nonce = 10;
        f.oldRecord.signedAt = 1;
        f.oldRecord.recordHash = RotationHashes.guardianRecord(
            Identity.hashes(f.old.origins[0]),
            f.oldRecord.terms,
            T.Authorization(10, 1, new bytes(0))
        );
        f.older = GH.Entry(
            ARTIST, 1, 40, f.oldRecord.recordHash, keccak256(abi.encode(f.oldRecord)), 0, 0
        );
        f.older.commitment = Identity.guardianHash(f.old.origins[0], f.older);
        f.newRecord = abi.decode(abi.encode(f.oldRecord), (R.GuardianRecord));
        f.newRecord.nonce = 11;
        f.newRecord.recordHash = RotationHashes.guardianRecord(
            Identity.hashes(initial.current),
            f.newRecord.terms,
            T.Authorization(11, 1, new bytes(0))
        );
        f.newer = GH.Entry(
            ARTIST,
            2,
            2,
            f.newRecord.recordHash,
            keccak256(abi.encode(f.newRecord)),
            f.older.commitment,
            0
        );
        f.newer.commitment = Identity.guardianHash(initial.current, f.newer);
        f.vested.artistId = ARTIST;
        f.vested.transitionRecordHash = bytes32(uint256(8100));
        f.vested.operationId = 35;
        f.vested.ownerRevision = 50;
        f.vested.executedAt = 1;
        f.vested.oldAddress = address(72);
        f.vested.newAddress = address(73);
        f.vested.authorityClass = 1;
        f.vested.guardians = GH.Head(1, 40, f.older.commitment);
        f.vested.commitment = Identity.vestingHash(f.old.origins[0], f.vested);
        f.old.journal[0].receipt = H.Receipt(28, ARTIST, 0, f.older.recordHash);
        f.old.journal[1].receipt = H.Receipt(35, ARTIST, 0, f.vested.transitionRecordHash);
        _prefix(2, f.old, IMPORT, 1);
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(0)),
            abi.encode(H.Receipt(28, ARTIST, 0, f.newer.recordHash))
        );
        GH.Snapshot memory empty;
        GH.Head memory head = GH.Head(2, 2, f.newer.commitment);
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature(
                "guardianHistoryState(bytes32,uint64,address,bytes32)",
                ARTIST,
                uint64(1),
                address(0),
                bytes32(0)
            ),
            abi.encode(head, f.older, empty, uint64(0))
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature(
                "guardianHistoryState(bytes32,uint64,address,bytes32)",
                ARTIST,
                uint64(2),
                address(0),
                bytes32(0)
            ),
            abi.encode(head, f.newer, empty, uint64(0))
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature(
                "recoveredHydrationAuxiliaryPoint(bytes32,bytes32)",
                keccak256("identity_authority.hydration.guardian_vesting"),
                f.vested.transitionRecordHash
            ),
            abi.encode(RH.Point(f.old.eras[0].originHash, 2, 50))
        );
        f.clock = harness.load(e, 2);
    }

    function _revision()
        private
        returns (
            RecoveredIdentityRuntimeHarness target,
            Doc.Record memory r,
            RH.OwnerProvenance memory old
        )
    {
        _fixture(5);
        old = _fixture(2);
        target = new RecoveredIdentityRuntimeHarness();
        bytes memory document = bytes("retained original identity document");
        r.artistId = ARTIST;
        r.previousRecordHash = bytes32(uint256(701));
        r.revisedRecordHash = keccak256(document);
        r.signer = address(72);
        r.authorityClass = 1;
        r.nonce = 7;
        r.signedAt = 1;
        r.displayName = "retained original";
        r.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_REVISION_RECORD_V1"),
                block.chainid,
                old.origins[0].registry,
                ARTIST,
                r.previousRecordHash,
                r.revisedRecordHash,
                r.signer,
                uint8(1),
                r.nonce,
                r.signedAt
            )
        );
        bytes32 digest = Hashes.typed(
            Identity.hashes(old.origins[0]),
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistIdentityRevision(bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,uint256 nonce,uint64 signedAt)"
                    ),
                    ARTIST,
                    r.previousRecordHash,
                    r.revisedRecordHash,
                    r.nonce,
                    r.signedAt
                )
            )
        );
        old.journal[0].receipt = H.Receipt(25, ARTIST, 0, r.recordHash);
        old.aliases = new RH.ReplayAlias[](2);
        bytes32 nonceSurface = keccak256("identity_authority.replay.nonce_allocator");
        bytes32 nonceScope = keccak256(abi.encode(ARTIST, r.nonce));
        bytes32 chainSurface = keccak256("identity_authority.replay.identity_revision_chain");
        bytes32 chainScope = keccak256(abi.encode(ARTIST, bytes32(0), r.previousRecordHash));
        old.aliases[0] = RH.ReplayAlias(
            old.eras[0].originHash,
            2,
            nonceSurface,
            nonceScope,
            Keys.replayKey(old.origins[0], 2, AH.Origin(nonceSurface, nonceScope)),
            T.ReplayCell(digest, 40, 1, 2),
            RH.Point(old.eras[0].originHash, 2, 40)
        );
        old.aliases[1] = RH.ReplayAlias(
            old.eras[0].originHash,
            2,
            chainSurface,
            chainScope,
            Keys.replayKey(old.origins[0], 2, AH.Origin(chainSurface, chainScope)),
            T.ReplayCell(r.recordHash, 40, 1, 2),
            RH.Point(old.eras[0].originHash, 2, 40)
        );
        old.eras[0].checkpoint.replayCount = 2;
        _prefix(2, old, IMPORT, 1);
        T.Identity memory identity;
        identity.identityRecordHash = r.previousRecordHash;
        R.ProvisionalAssociation memory empty;
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("identity(bytes32)", ARTIST),
            abi.encode(identity)
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("identityRevisionRecord(bytes32)", r.recordHash),
            abi.encode(r)
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("identityDocumentBytes(bytes32)", r.revisedRecordHash),
            abi.encode(document)
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature(
                "identityRevisionProvisionalAssociation(bytes32)", r.recordHash
            ),
            abi.encode(empty)
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature(
                "identityRevisionRecoveryContinuationV3(bytes32)", r.recordHash
            ),
            abi.encode(bytes32(0))
        );
    }

    function _rejectIdentity(RecoveredIdentityRuntimeHarness target, bytes memory input) private {
        (bool ok, bytes memory error) = address(target).call(input);
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
                    ),
            "exact original Identity provenance rejection"
        );
    }
}
