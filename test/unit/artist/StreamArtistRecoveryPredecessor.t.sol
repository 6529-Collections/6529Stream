// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveryPredecessor as P
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryPredecessor.sol";
import {
    StreamArtistRotationState as S
} from "../../../smart-contracts/domains/artist/StreamArtistRotationState.sol";
import {
    StreamArtistGuardianHistory as H
} from "../../../smart-contracts/domains/artist/StreamArtistGuardianHistory.sol";
import {
    StreamArtistHashes as Hashes
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
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

interface RecoveryPredecessorVm {
    function warp(uint256 time) external;
    function expectRevert() external;
}

/// @dev Supplies owner-admitted records and history; actual admission/signature/governance are separate tests.
contract RecoveryPredecessorHarness {
    S.State private rotations;
    H.State private history;
    D.CauseFacts private cause;
    bytes32 private constant ARTIST = keccak256("artist");
    address private constant OLD = address(0xaaaa);
    address private constant CURRENT = address(0xbbbb);
    bytes32 private head;
    uint64 private count;

    function environment() public view returns (Hashes.Environment memory) {
        return Hashes.Environment(block.chainid, address(0x1234), address(0x2345), address(0x3456));
    }

    function seed() external returns (bytes32) {
        R.RotationRecord memory r;
        r.terms = R.Rotation(ARTIST, OLD, CURRENT, keccak256("rotation reason"), 0);
        r.oldNonce = 1;
        r.newNonce = 0;
        r.effectiveWindow = 7 days;
        r.standingTail = 90 days;
        r.timingRevision = 1;
        head = RH.rotationRecord(environment(), r.terms, 1, 1000, 1000 + 7 days);
        r.recordHash = head;
        r.transition = R.TransitionState(
            ARTIST, head, 1000, 1000 + 7 days, 1000 + 7 days, 1000 + 14 days, 0, 2
        );
        rotations.rotations[head] = r;
        rotations.latestExecution[ARTIST] = head;
        rotations.latestTransition[ARTIST] = head;
        rotations.pending[ARTIST] = 0;
        rotations.retirement[ARTIST][OLD] = head;
        cause.artistId = ARTIST;
        cause.incumbent = CURRENT;
        cause.executedTransitionHash = head;
        cause.pendingTransitionHash = 0;
        cause.enteredAt = uint64(block.timestamp);
        return head;
    }

    function predecessor() external view returns (bytes32) {
        return P.firstRotation(rotations, environment(), cause, CURRENT);
    }

    function change(uint8 field) external {
        R.RotationRecord storage r = rotations.rotations[head];
        if (field == 1) r.recordHash = bytes32(uint256(1));
        if (field == 2) rotations.retirement[ARTIST][OLD] = bytes32(uint256(1));
        if (field == 3) cause.executedTransitionHash = bytes32(uint256(1));
        if (field == 4) r.terms.artistId = bytes32(uint256(1));
        if (field == 5) r.terms.newAddress = OLD;
        if (field == 6) rotations.pending[ARTIST] = head;
        if (field == 7) r.terms.expectedPreviousTransitionRecordHash = head;
        if (field == 8) r.transition.contestedAt = r.transition.postWindowEndsAt - 1;
        if (field == 9) r.transition.postWindowEndsAt++;
        if (field == 10) r.oldNonce++;
        if (field == 11) r.transition.phase = 1;
        if (field == 12) cause.enteredAt = r.transition.postWindowEndsAt - 1;
        if (field == 13) rotations.latestTransition[ARTIST] = bytes32(uint256(1));
        if (field == 14) r.transition.contestedAt = r.transition.postWindowEndsAt;
    }

    function addGuardian(bool provisional, bool empty) external returns (bytes32) {
        R.GuardianSet memory terms;
        terms.artistId = ARTIST;
        terms.guardians = new address[](empty ? 0 : 1);
        if (!empty) terms.guardians[0] = address(0xcccc);
        terms.approvalThreshold = empty ? 0 : 1;
        terms.minContestSeconds = 20 days;
        T.Authorization memory a = T.Authorization(4, 1000, "");
        bytes32 hash = RH.guardianRecord(environment(), terms, a);
        R.ProvisionalAssociation memory association;
        if (provisional) association = R.ProvisionalAssociation(head, 1000 + 14 days);
        R.GuardianRecord memory g = R.GuardianRecord(hash, terms, OLD, 1, 4, 1000, 0, association);
        rotations.guardians[hash] = g;
        H.append(history, environment(), g, ++count, 9);
        if (provisional) rotations.provisionalGuardian[ARTIST] = hash;
        else rotations.stableGuardian[ARTIST] = hash;
        return hash;
    }

    function selected() external view returns (R.GuardianRecord memory) {
        return P.guardian(history, rotations, environment(), ARTIST, count);
    }

    function changeGuardian(bytes32 hash, bool restore) external {
        rotations.guardians[hash].signer = restore ? OLD : CURRENT;
    }

    function fakeCount() external {
        count = 1;
    }
}

contract StreamArtistRecoveryPredecessorTest {
    RecoveryPredecessorVm private constant vm =
        RecoveryPredecessorVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RecoveryPredecessorHarness private host;
    uint256 private constant END = 1000 + 14 days;

    function setUp() public {
        vm.warp(END);
        host = new RecoveryPredecessorHarness();
        host.seed();
    }

    function testExactWindowAndLateContestRemainMature() public {
        bytes32 original = host.predecessor();
        require(original != 0, "canonical exact equality");
        vm.warp(END - 1);
        vm.expectRevert();
        host.predecessor();
        vm.warp(END);
        host.change(14);
        require(
            host.predecessor() != 0 && host.predecessor() != original,
            "late first contest bound in proof"
        );
    }

    function testRejectsWrongStoredPredecessorCauseAndRetirement() public {
        for (uint8 i = 1; i <= 7; ++i) {
            host.seed();
            host.change(i);
            vm.expectRevert();
            host.predecessor();
        }
        host.seed();
        require(host.predecessor() != 0, "healthy restore");
    }

    function testRejectsWithinWindowMalformedAndLaterCohort() public {
        for (uint8 i = 8; i <= 13; ++i) {
            host.seed();
            host.change(i);
            vm.expectRevert();
            host.predecessor();
        }
        host.seed();
        require(host.predecessor() != 0, "healthy restore");
    }

    function testOldKeyRecordRequiresExactAdmittedProvenance() public {
        bytes32 hash = host.addGuardian(false, false);
        require(
            host.selected().recordHash == hash && host.selected().signer == address(0xaaaa),
            "old key retained"
        );
        host.changeGuardian(hash, false);
        vm.expectRevert();
        host.selected();
        host.changeGuardian(hash, true);
        require(host.selected().recordHash == hash, "original admitted bytes restored");
    }

    function testMatureProvisionalSelectionWithoutCheckpointWrite() public {
        bytes32 hash = host.addGuardian(true, false);
        vm.warp(END - 1);
        vm.expectRevert();
        host.selected();
        vm.warp(END);
        require(
            host.selected().recordHash == hash
                && host.selected().provisional.transitionRecordHash != 0,
            "read only maturation"
        );
        host.change(14);
        require(host.selected().recordHash == hash, "late contest preserves eligibility");
        host.change(8);
        vm.expectRevert();
        host.selected();
    }

    function testEmptySelectedSetAndMissingHistoryRemainDistinct() public {
        require(host.selected().recordHash == 0, "never guarded");
        bytes32 hash = host.addGuardian(false, true);
        require(
            host.selected().recordHash == hash && host.selected().terms.guardians.length == 0,
            "admitted empty set"
        );
        RecoveryPredecessorHarness missing = new RecoveryPredecessorHarness();
        missing.seed();
        missing.fakeCount();
        vm.expectRevert();
        missing.selected();
    }
}
