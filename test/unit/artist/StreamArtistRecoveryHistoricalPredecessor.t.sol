// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveryHistoricalPredecessor as P
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryHistoricalPredecessor.sol";
import {
    StreamArtistRotationState as S
} from "../../../smart-contracts/domains/artist/StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistHashes as H
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistRotationHashes as RH
} from "../../../smart-contracts/domains/artist/StreamArtistRotationHashes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";

interface HistoricalPredecessorVm {
    function warp(uint256 time) external;
    function expectRevert() external;
}

/// @dev Supplies admitted owner-local history. Actual admission, governance and signatures are separate.
contract HistoricalPredecessorHarness {
    S.State private rotations;
    Resolution.State private resolutions;
    D.CauseFacts private cause;
    bytes32 private constant ARTIST = keccak256("historical artist");
    address private constant OLD = address(0xaaaa);
    address private constant CURRENT = address(0xbbbb);
    bytes32 private head;
    bytes32 private prior;
    bytes32 private dismissal;
    bytes32 private originalCause;

    function environment() public view returns (H.Environment memory) {
        return H.Environment(block.chainid, address(0x1234), address(0x2345), address(0x3456));
    }

    function seed(bool early, bool contested) external {
        R.RotationRecord memory r;
        r.terms = R.Rotation(ARTIST, address(0x1111), OLD, keccak256("first"), 0);
        r.effectiveWindow = 7 days;
        r.standingTail = 90 days;
        r.timingRevision = 1;
        prior = RH.rotationRecord(environment(), r.terms, 0, 1000, 1000 + 7 days);
        r.recordHash = prior;
        r.transition = R.TransitionState(
            ARTIST, prior, 1000, 1000 + 7 days, 1000 + 7 days, 1000 + 14 days, 0, 2
        );
        rotations.rotations[prior] = r;
        r.terms = R.Rotation(ARTIST, OLD, CURRENT, keccak256("second"), prior);
        r.oldNonce = 1;
        uint64 staged = 1000 + 14 days;
        uint64 executed = early ? staged : staged + 7 days;
        r.approvalThreshold = early ? 1 : 0;
        r.guardianApprovals = early ? 1 : 0;
        head = RH.rotationRecord(environment(), r.terms, 1, staged, staged + 7 days);
        r.recordHash = head;
        r.transition = R.TransitionState(
            ARTIST,
            head,
            staged,
            staged + 7 days,
            executed,
            executed + 7 days,
            contested ? executed + 1 : 0,
            2
        );
        rotations.rotations[head] = r;
        rotations.latestExecution[ARTIST] = head;
        rotations.latestTransition[ARTIST] = head;
        rotations.retirement[ARTIST][OLD] = head;
        cause.artistId = ARTIST;
        cause.incumbent = CURRENT;
        cause.authorityClass = 1;
        cause.priorStatus = 1;
        cause.executedTransitionHash = head;
        cause.enteredAt = uint64(block.timestamp);
        cause.previousResolutionHash = 0;
        delete resolutions.closures[head];
    }

    function predecessor() external view returns (bytes32) {
        return P.rotation(rotations, resolutions, environment(), cause, CURRENT);
    }

    function close() external returns (bytes32) {
        D.CauseFacts memory f = cause;
        f.kind = 1;
        f.referenceHash = keccak256("original contest");
        f.actor = OLD;
        f.reasonHash = keccak256("contest reason");
        f.evidenceHash = keccak256("contest evidence");
        f.enteredAt = rotations.rotations[head].transition.contestedAt;
        f.previousResolutionHash = 0;
        originalCause = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                block.chainid,
                environment().registry,
                address(this),
                f
            )
        );
        resolutions.causes[originalCause] = D.Cause(originalCause, f);
        D.Record memory r;
        r.terms = D.Request(
            ARTIST,
            originalCause,
            0,
            keccak256("dismiss evidence"),
            keccak256("dismiss reason"),
            false,
            0
        );
        r.executor = address(0x4321);
        r.proposer = address(0x5432);
        r.actionClass = 1;
        r.actionId = keccak256("actual fixture action");
        r.incumbent = CURRENT;
        r.authorityClass = 1;
        r.restoredStatus = 1;
        r.dismissedAt = f.enteredAt + 1;
        r.cohortHash = keccak256("original cohort");
        r.governanceWitnessHash = keccak256("original witness");
        dismissal = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_RECORD_V1"),
                block.chainid,
                environment().registry,
                address(this),
                r.terms,
                r.executor,
                r.proposer,
                r.actionClass,
                r.actionId,
                r.incumbent,
                r.authorityClass,
                r.restoredStatus,
                r.dismissedAt,
                r.cohortHash,
                r.governanceWitnessHash
            )
        );
        r.recordHash = dismissal;
        resolutions.records[dismissal] = r;
        resolutions.closures[head] = D.Closure(
            ARTIST,
            head,
            dismissal,
            rotations.rotations[head].transition.postWindowEndsAt,
            f.enteredAt,
            true
        );
        cause.previousResolutionHash = dismissal;
        return dismissal;
    }

    function mutate(uint8 field) external {
        if (field == 1) rotations.rotations[prior].terms.newAddress = CURRENT;
        if (field == 2) rotations.rotations[prior].transition.phase = 1;
        if (field == 3) rotations.retirement[ARTIST][OLD] = prior;
        if (field == 4) rotations.rotations[head].guardianApprovals = 0;
        if (field == 5) resolutions.closures[head].abandoned = false;
        if (field == 6) resolutions.closures[head].dismissalRecordHash = prior;
        if (field == 7) resolutions.closures[head].contestedAt++;
        if (field == 8) resolutions.records[dismissal].actionClass = 2;
        if (field == 9) resolutions.records[dismissal].incumbent = OLD;
        if (field == 10) resolutions.causes[originalCause].facts.executedTransitionHash = prior;
        if (field == 11) cause.enteredAt = resolutions.records[dismissal].dismissedAt - 1;
        if (field == 12) resolutions.causes[originalCause].causeHash = prior;
        if (field == 13) {
            cause.previousResolutionHash = keccak256("later independently admitted dismissal");
        }
        if (field == 14) rotations.latestTransition[ARTIST] = prior;
        if (field == 15) resolutions.closures[head].windowEndsAt++;
    }
}

contract StreamArtistRecoveryHistoricalPredecessorTest {
    HistoricalPredecessorVm private constant vm =
        HistoricalPredecessorVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    HistoricalPredecessorHarness private host;

    function setUp() public {
        vm.warp(1000 + 30 days);
        host = new HistoricalPredecessorHarness();
    }

    function testLaterOrdinaryRotationRequiresOriginalPredecessorAndRetirement() public {
        host.seed(false, false);
        require(host.predecessor() != 0, "later completed rotation");
        for (uint8 i = 1; i <= 3; ++i) {
            host.seed(false, false);
            host.mutate(i);
            vm.expectRevert();
            host.predecessor();
        }
        host.seed(false, false);
        require(host.predecessor() != 0, "healthy restore");
    }

    function testEarlyGuardianApprovedExecutionIsValidHistory() public {
        host.seed(true, false);
        require(host.predecessor() != 0, "retained original threshold authorization");
        host.mutate(4);
        vm.expectRevert();
        host.predecessor();
        host.seed(true, false);
        require(host.predecessor() != 0, "threshold restored");
    }

    function testTimeCannotReplaceActualDismissalOfEarlyContest() public {
        host.seed(false, true);
        vm.expectRevert();
        host.predecessor();
        vm.warp(1000 + 100 days);
        vm.expectRevert();
        host.predecessor();
        host.close();
        require(host.predecessor() != 0, "actual stored closure and record");
    }

    function testOriginalClosureSurvivesLaterResolutionPointer() public {
        host.seed(false, true);
        host.close();
        bytes32 before_ = host.predecessor();
        host.mutate(13);
        require(host.predecessor() == before_, "immutable original resolution independently bound");
    }

    function testRejectsMalformedClosureRecordCauseAndChronology() public {
        for (uint8 i = 5; i <= 12; ++i) {
            host.seed(false, true);
            host.close();
            host.mutate(i);
            vm.expectRevert();
            host.predecessor();
        }
        host.seed(false, true);
        host.close();
        host.mutate(15);
        vm.expectRevert();
        host.predecessor();
        host.seed(false, true);
        host.close();
        require(host.predecessor() != 0, "healthy complete original join");
    }

    function testLaterUnresolvedHeadDoesNotBecomeVestedIncumbent() public {
        host.seed(false, false);
        host.mutate(14);
        vm.expectRevert();
        host.predecessor();
        host.seed(false, false);
        require(host.predecessor() != 0, "same actual latest execution");
    }
}
