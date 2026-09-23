// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHistoryOrder as Order
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHistoryOrder.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";

import { StreamArtistRecoveredRuntimeReadsTest } from "./StreamArtistRecoveredRuntimeReads.t.sol";
import {
    StreamArtistRecoveredContinuationWrites as Writes
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContinuationWrites.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationGuards as Keys
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";

contract RecoveredContinuationWriterHarness {
    function historyBefore(Hashes.Environment memory e, V.Snapshot memory a, V.Snapshot memory b)
        external
        view
        returns (bool)
    {
        return Order.before(e, a, b);
    }

    function revision(
        Hashes.Environment memory e,
        uint64 currentRevision,
        W.RevisionContinuationV3 memory r
    ) external view {
        Writes.revision(e, currentRevision, r);
    }

    function standing(
        Hashes.Environment memory e,
        uint64 currentRevision,
        W.StandingContinuationV3 memory r
    ) external view {
        Writes.standing(e, currentRevision, r);
    }

    function later(
        Hashes.Environment memory e,
        uint64 currentRevision,
        D.RevisionContinuation memory legacy,
        D.Record memory dismissed,
        W.RevisionContinuationV3 memory recovery,
        T.ReplayCell memory consumed
    ) external view returns (bool) {
        return Writes.laterDismissal(e, currentRevision, legacy, dismissed, recovery, consumed);
    }
}

/// @notice Writer prerequisites against explicitly mocked fixed-owner state and provenance.
/// @dev Exercises the production point/hash joins; no actual25/51 mutation or Safe claim.
contract StreamArtistRecoveredContinuationWritesTest is StreamArtistRecoveredRuntimeReadsTest {
    struct Fixture {
        RecoveredContinuationWriterHarness target;
        Runtime.Context clock;
        RH.OwnerProvenance old;
        W.RevisionContinuationV3 revision;
        W.StandingContinuationV3 standing;
        D.RevisionContinuation legacy;
        D.Record dismissed;
        T.ReplayCell consumed;
    }

    function testRecoveredEstateHistoryOrdersOriginal40BeforeCurrent2() public {
        Fixture memory f = _writers();
        (V.Snapshot memory a, V.Snapshot memory b) = _vestings(f);
        require(
            f.target.historyBefore(_environment(), a, b),
            "original recovery precedes new estate by era"
        );
        require(!f.target.historyBefore(_environment(), b, a), "current low revision is not older");
    }

    function testRecoveredEstateHistoryRejectsRebasedSnapshot() public {
        Fixture memory f = _writers();
        (V.Snapshot memory a, V.Snapshot memory b) = _vestings(f);
        a.ownerRevision = 2;
        a.commitment = Recovered.vestingHash(f.clock.current, a);
        _rejectWriter(
            f.target,
            abi.encodeCall(f.target.historyBefore, (_environment(), a, b)),
            RH.InvalidRecoveredHydrationProvenance.selector
        );
    }

    function _vestings(Fixture memory f)
        private
        returns (V.Snapshot memory a, V.Snapshot memory b)
    {
        a.artistId = ARTIST;
        a.transitionRecordHash = f.revision.recoveryRecordHash;
        a.operationId = 35;
        a.ownerRevision = 40;
        a.executedAt = 1;
        a.oldAddress = address(91);
        a.newAddress = address(92);
        a.authorityClass = 1;
        a.commitment = Recovered.vestingHash(f.old.origins[0], a);
        b.artistId = ARTIST;
        b.transitionRecordHash = keccak256("new original estate request");
        b.operationId = 40;
        b.ownerRevision = 2;
        b.executedAt = 2;
        b.oldAddress = a.newAddress;
        b.newAddress = address(93);
        b.authorityClass = 3;
        b.previousTransitionRecordHash = a.transitionRecordHash;
        b.previousCommitment = a.commitment;
        b.commitment = Recovered.vestingHash(f.clock.current, b);
        _writerAux(
            a.transitionRecordHash, "guardian_vesting", RH.Point(f.old.eras[0].originHash, 2, 40)
        );
        _writerAux(
            b.transitionRecordHash,
            "guardian_vesting",
            RH.Point(RH.originHash(f.clock.current), 2, 2)
        );
    }

    function testRecoveredRevisionWriterAcceptsOld40AtCurrent8() public {
        Fixture memory f = _writers();
        f.target.revision(_environment(), 8, f.revision);
        require(
            f.revision.ownerRevision > f.clock.checkpoint.ownerState.revision, "distinct raw clocks"
        );
    }

    function testRecoveredStandingWriterAcceptsOriginalHashAndHighRevision() public {
        Fixture memory f = _writers();
        f.target.standing(_environment(), 8, f.standing);
        f.standing.retirementHash = keccak256("changed retirement");
        _rejectWriter(
            f.target,
            abi.encodeCall(f.target.standing, (_environment(), uint64(8), f.standing)),
            T.InvalidRecord.selector
        );
    }

    function testRecoveredRevisionWriterRejectsCurrentDomainRehash() public {
        Fixture memory f = _writers();
        f.revision.continuationHash =
            W.revisionContinuationHash(Runtime.rewindEnvironment(f.clock.current), f.revision);
        _writerAux(
            f.revision.continuationHash,
            "revision_continuation_v3",
            RH.Point(f.old.eras[0].originHash, 2, 40)
        );
        _rejectWriter(
            f.target,
            abi.encodeCall(f.target.revision, (_environment(), uint64(8), f.revision)),
            T.InvalidRecord.selector
        );
    }

    function testRecoveredRevisionWriterRequiresExactCurrentCheckpoint() public {
        Fixture memory f = _writers();
        _rejectWriter(
            f.target,
            abi.encodeCall(f.target.revision, (_environment(), uint64(9), f.revision)),
            RH.InvalidRecoveredHydrationProvenance.selector
        );
        f.target.revision(_environment(), 8, f.revision);
    }

    function testRecoveredRevisionWriterRejectsMissingOriginAndRetriesExactPoint() public {
        Fixture memory f = _writers();
        vm.mockCallRevert(
            address(f.target),
            abi.encodeWithSignature(
                "recoveredHydrationAuxiliaryPoint(bytes32,bytes32)",
                keccak256("identity_authority.hydration.revision_continuation_v3"),
                f.revision.continuationHash
            ),
            abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
        );
        _rejectWriter(
            f.target,
            abi.encodeCall(f.target.revision, (_environment(), uint64(8), f.revision)),
            RH.InvalidRecoveredHydrationProvenance.selector
        );
        _writerAux(
            f.revision.continuationHash,
            "revision_continuation_v3",
            RH.Point(f.old.eras[0].originHash, 2, 40)
        );
        f.target.revision(_environment(), 8, f.revision);
    }

    function testRecoveredLaterDismissalCurrent2WinsOverOriginal40() public {
        Fixture memory f = _writers();
        require(
            f.target.later(_environment(), 8, f.legacy, f.dismissed, f.revision, f.consumed),
            "new local58 wins by era"
        );
        f.consumed.touchedRevision = 3;
        _rejectWriter(
            f.target,
            abi.encodeCall(
                f.target.later,
                (_environment(), uint64(8), f.legacy, f.dismissed, f.revision, f.consumed)
            ),
            T.InvalidRecord.selector
        );
    }

    function testRecoveredEarlierDismissalOriginal50DoesNotShadowCurrent2() public {
        Fixture memory f = _writers();
        f.old.journal[1].receipt = H.Receipt(58, ARTIST, 0, f.dismissed.recordHash);
        _prefix(2, f.old, IMPORT, 1);
        f.revision.recoveryRecordHash = bytes32(uint256(9000));
        f.revision.ownerRevision = 2;
        f.revision.continuationHash =
            W.revisionContinuationHash(Runtime.rewindEnvironment(f.clock.current), f.revision);
        _writerAux(
            f.revision.continuationHash,
            "revision_continuation_v3",
            RH.Point(RH.originHash(f.clock.current), 2, 2)
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(0)),
            abi.encode(H.Receipt(35, ARTIST, 0, f.revision.recoveryRecordHash))
        );
        f.legacy.continuationHash = _legacyHash(f.old.origins[0], f.legacy);
        f.dismissed.revisionContinuationHead = f.legacy.continuationHash;
        f.consumed.touchedRevision = 50;
        _writerAux(
            f.legacy.continuationHash,
            "dismissal_continuation",
            RH.Point(f.old.eras[0].originHash, 2, 50)
        );
        _writerReplay(f, RH.Point(f.old.eras[0].originHash, 2, 50));
        require(
            !f.target.later(_environment(), 8, f.legacy, f.dismissed, f.revision, f.consumed),
            "older source58 cannot shadow newer destination35"
        );
    }

    function testRecoveredContinuationRequiresActualCreating35Occurrence() public {
        Fixture memory f = _writers();
        f.old.journal[0].receipt.operation = 58;
        _prefix(2, f.old, IMPORT, 1);
        _rejectWriter(
            f.target,
            abi.encodeCall(f.target.revision, (_environment(), uint64(8), f.revision)),
            RH.InvalidRecoveredHydrationProvenance.selector
        );
    }

    function _writers() private returns (Fixture memory f) {
        f.target = new RecoveredContinuationWriterHarness();
        suite.owners[2] = address(f.target);
        e.identityOwner = address(f.target);
        e.identityCodeHash = address(f.target).codehash;
        vm.mockCall(
            e.coordinator, abi.encodeWithSignature("suiteConfiguration()"), abi.encode(suite)
        );
        // Identity's fixed environment also verifies the Payout owner's immutable bindings.
        _fixture(5);
        f.old = _fixture(2);
        f.old.journal[1].receipt.recordHash = bytes32(uint256(7001));
        _prefix(2, f.old, IMPORT, 1);
        f.clock = harness.load(e, 2);
        f.revision = W.RevisionContinuationV3(
            ARTIST,
            bytes32(uint256(7000)),
            bytes32(uint256(10)),
            bytes32(uint256(11)),
            bytes32(uint256(12)),
            bytes32(uint256(13)),
            bytes32(uint256(14)),
            40,
            0
        );
        f.revision.continuationHash =
            W.revisionContinuationHash(Runtime.rewindEnvironment(f.old.origins[0]), f.revision);
        _writerAux(
            f.revision.continuationHash,
            "revision_continuation_v3",
            RH.Point(f.old.eras[0].originHash, 2, 40)
        );
        f.standing = W.StandingContinuationV3(
            ARTIST,
            address(444),
            bytes32(uint256(555)),
            f.revision.recoveryRecordHash,
            f.revision.actionId,
            f.revision.planCommitment,
            0,
            bytes32(uint256(556)),
            40,
            0
        );
        f.standing.continuationHash =
            W.standingContinuationHash(Runtime.rewindEnvironment(f.old.origins[0]), f.standing);
        _writerAux(
            f.standing.continuationHash,
            "standing_continuation_v3",
            RH.Point(f.old.eras[0].originHash, 2, 40)
        );
        f.dismissed.recordHash = keccak256("real typed dismissal boundary");
        f.dismissed.terms.artistId = ARTIST;
        f.dismissed.terms.expectedCauseHash = keccak256("original cause");
        f.legacy.artistId = ARTIST;
        f.legacy.dismissalRecordHash = f.dismissed.recordHash;
        f.legacy.stableRevisionRecordHash = f.revision.stableRevisionRecordHash;
        f.legacy.stableDocumentHash = f.revision.stableDocumentHash;
        f.legacy.abandonedRevisionRecordHash = keccak256("fresh abandoned child");
        f.legacy.continuationHash = _legacyHash(f.clock.current, f.legacy);
        f.dismissed.revisionContinuationHead = f.legacy.continuationHash;
        f.consumed = T.ReplayCell(f.dismissed.recordHash, 2, 1, 2);
        _writerAux(
            f.legacy.continuationHash,
            "dismissal_continuation",
            RH.Point(RH.originHash(f.clock.current), 2, 2)
        );
        _writerReplay(f, RH.Point(RH.originHash(f.clock.current), 2, 2));
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("artistNativeReceiptAt(uint256)", uint256(0)),
            abi.encode(H.Receipt(58, ARTIST, 0, f.dismissed.recordHash))
        );
    }

    function _writerAux(bytes32 key, string memory suffix, RH.Point memory point) private {
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature(
                "recoveredHydrationAuxiliaryPoint(bytes32,bytes32)",
                keccak256(bytes(string.concat("identity_authority.hydration.", suffix))),
                key
            ),
            abi.encode(point)
        );
    }

    function _writerReplay(Fixture memory f, RH.Point memory point) private {
        bytes32 key = Keys.replayKey(
            f.clock.current,
            2,
            AH.Origin(
                keccak256("identity_authority.replay.contest_resolution"),
                keccak256(abi.encode(ARTIST, f.dismissed.terms.expectedCauseHash))
            )
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("replayCell(bytes32)", key),
            abi.encode(f.consumed)
        );
        vm.mockCall(
            e.identityOwner,
            abi.encodeWithSignature("recoveredHydrationReplayPoint(bytes32)", key),
            abi.encode(point)
        );
    }

    function _legacyHash(RH.OriginEnvironment memory origin, D.RevisionContinuation memory c)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_REVISION_CONTINUATION_V1"),
                origin.chainId,
                origin.registry,
                origin.owners[2],
                c.artistId,
                c.dismissalRecordHash,
                c.previousContinuationHash,
                c.stableRevisionRecordHash,
                c.stableDocumentHash,
                c.abandonedRevisionRecordHash
            )
        );
    }

    function _environment() private view returns (Hashes.Environment memory) {
        return Hashes.Environment(e.chainId, e.registry, e.core, e.manager);
    }

    function _rejectWriter(
        RecoveredContinuationWriterHarness target,
        bytes memory call_,
        bytes4 error_
    ) private {
        (bool ok, bytes memory result) = address(target).call(call_);
        require(
            !ok && keccak256(result) == keccak256(abi.encodeWithSelector(error_)),
            "exact writer prerequisite rejection"
        );
    }
}
