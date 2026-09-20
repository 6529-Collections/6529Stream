// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistLivingDormancyBoundary as LivingBoundary
} from "./StreamArtistLivingDormancyBoundary.sol";

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistEstateState as EstateState } from "./StreamArtistEstateState.sol";
import {
    StreamArtistIdentityContestState as ContestState
} from "./StreamArtistIdentityContestState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistSuccessionState } from "./StreamArtistSuccessionState.sol";
import { StreamArtistSuccessionHashes } from "./StreamArtistSuccessionHashes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

import "./StreamArtistDormancyState.sol";
import {
    StreamArtistRecoveryDormancyClosure as DormClosure
} from "./StreamArtistRecoveryDormancyClosure.sol";
import {
    StreamArtistRecoveryDormancyGuardians as DormGuardians
} from "./StreamArtistRecoveryDormancyGuardians.sol";

import {
    StreamArtistRecoveryDormancyStanding as DormStanding
} from "./StreamArtistRecoveryDormancyStanding.sol";

/// @notice Immutable designated op43 origin for the first elected class3 recovery.
/// @dev Consumes admitted notice/action/vesting records; never reauthorizes historical governance.
library StreamArtistRecoveryDormancyPredecessor {
    struct Facts {
        Dorm.Notice notice;
        Dorm.Terminal terminal;
        R.TransitionState transition;
        V.Snapshot vesting;
        V.Snapshot previous;
        GH.Head guardians;
        Succ.DesignationRecord designation;
        Succ.DirectiveRecord paired;
        Succ.DirectiveRecord forbidden;
        Contest.Record contest;
    }

    function facts(
        RecoveryState.State storage recovery,
        StreamArtistDormancyState.State storage dormancy,
        EstateState.State storage estate,
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistSuccessionState.State storage succession,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Recovery.Request memory p
    ) public view returns (bytes32 proof, R.GuardianRecord memory guardian) {
        bytes32 head = dormancy.activation[p.artistId];
        Facts memory f;
        f.terminal = dormancy.terminals[head];
        f.notice = dormancy.notices[f.terminal.noticeHash];
        f.transition = dormancy.transitions[head];
        f.vesting = recovery.vestingHistory.snapshots[head];
        Dorm.Terminal memory hashTerminal = f.terminal;
        bytes32 originalRecordHash = hashTerminal.recordHash;
        hashTerminal.recordHash = 0;
        bytes32 terminalHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_V1"),
                e.chainId,
                e.registry,
                address(this),
                hashTerminal
            )
        );
        hashTerminal.recordHash = originalRecordHash;
        if (
            head == 0 || f.terminal.recordHash != head || terminalHash != head
                || f.terminal.noticeHash == 0 || f.notice.recordHash != f.terminal.noticeHash
                || f.notice.terms.artistId != p.artistId || f.notice.incumbent == address(0)
                || f.notice.incumbent == f.terminal.plan.authority
                || _noticeHash(e, f.notice) != f.notice.recordHash || f.notice.initiatedAt == 0
                || f.notice.terms.evidenceHash == 0 || f.notice.actionId == 0
                || f.notice.witnessHash == 0 || f.notice.inactivitySeconds < 365 days
                || f.notice.noticeSeconds < 180 days || f.notice.timingRevision == 0
                || uint256(f.notice.noticeEndsAt)
                    != uint256(f.notice.initiatedAt) + f.notice.noticeSeconds
                || uint256(f.notice.initiatedAt)
                    < uint256(f.notice.priorLivenessAt) + f.notice.inactivitySeconds
                || dormancy.latestNotice[p.artistId] != f.notice.recordHash
                || dormancy.phases[f.notice.recordHash] != 3
                || dormancy.terminalForNotice[f.notice.recordHash] != head
                || dormancy.activity[p.artistId] != f.notice.priorActivity
                || f.terminal.authorityClass != 3 || f.terminal.plan.authorityClass != 3
                || f.terminal.appointmentBlock != 0
                || f.terminal.plan.authority != cause.facts.incumbent
                || f.terminal.actor == address(0) || f.terminal.evidenceHash == 0
                || f.terminal.actionId == 0 || f.terminal.witnessHash == 0
                || f.terminal.observedAt < f.notice.noticeEndsAt || f.terminal.delegationEpoch == 0
                || f.terminal.delegationEpoch != estate.delegationEpoch[p.artistId]
                || f.terminal.plan.designation == 0 || f.terminal.plan.stewardGrantRecordHash != 0
                || f.terminal.plan.postSeconds < 72 hours || f.terminal.plan.standingTail < 30 days
                || estate.authorityActivation[p.artistId] != 0 || estate.pending[p.artistId] != 0
                || rotations.pending[p.artistId] != 0
                || rotations.latestExecution[p.artistId] != head
                || cause.facts.executedTransitionHash != head
                || cause.facts.pendingTransitionHash != 0 || f.transition.artistId != p.artistId
                || f.transition.recordHash != head || f.transition.phase != 2
                || f.transition.stagedAt != f.notice.initiatedAt
                || f.transition.contestEndsAt != f.notice.noticeEndsAt
                || f.transition.executedAt != f.terminal.observedAt
                || uint256(f.transition.postWindowEndsAt)
                    != uint256(f.terminal.observedAt) + f.terminal.plan.postSeconds
                || block.timestamp < cause.facts.enteredAt
                || recovery.vestingHistory.latest[p.artistId] != head
                || f.vesting.artistId != p.artistId || f.vesting.transitionRecordHash != head
                || f.vesting.operationId != 43 || f.vesting.authorityClass != 3
                || f.vesting.oldAddress != f.notice.incumbent
                || f.vesting.newAddress != f.terminal.plan.authority
                || f.vesting.executedAt != f.terminal.observedAt || f.vesting.ownerRevision == 0
                || f.vesting.ownerRevision <= f.vesting.guardians.ownerRevision
                || f.vesting.commitment == 0 || f.vesting.commitment != _vestingHash(e, f.vesting)
                || cause.causeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                            e.chainId,
                            e.registry,
                            address(this),
                            cause.facts
                        )
                    )
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        LivingBoundary.Facts memory boundary = LivingBoundary.facts(
            recovery, rotations, resolutions, e, f.notice, f.terminal, f.vesting, cause
        );
        bytes32 closureProof = rotations.latestTransition[p.artistId] == head
            ? DormClosure.proof(
                resolutions, e, f.transition, cause, boundary.cause, boundary.resolution
            )
            : DormStanding.proof(
                rotations,
                resolutions,
                contests,
                e,
                f.transition,
                cause,
                boundary.cause,
                boundary.resolution
            );
        if (recovery.latest[p.artistId] == 0) {
            _previous(recovery, rotations, e, f);
        } else {
            f.previous = recovery.vestingHistory.snapshots[f.vesting.previousTransitionRecordHash];
        }
        f.guardians = DormGuardians.prefix(
            recovery.guardianHistory,
            rotations,
            e,
            p.artistId,
            recovery.guardianRecordsSeen[p.artistId],
            f.vesting
        );
        f.contest = contests.records[cause.facts.referenceHash];
        _contest(e, cause, p, f.contest, head);
        f.designation = succession.designations[f.terminal.plan.designation];
        if (
            StreamArtistSuccessionState.operativeDesignation(succession, rotations, p.artistId)
                    != f.terminal.plan.designation
                || StreamArtistSuccessionState.operativeDirective(succession, rotations, p.artistId)
                    != f.terminal.plan.directive
                || f.designation.recordHash != f.terminal.plan.designation
                || f.designation.terms.artistId != p.artistId
                || f.designation.terms.successor != f.terminal.plan.authority
                || f.designation.authorityClass != 1 || f.designation.signer == address(0)
                || f.designation.signedAt > f.notice.initiatedAt
                || (f.vesting.previousTransitionRecordHash == 0
                    && f.designation.signer != f.notice.incumbent)
                || !_eligible(rotations, p.artistId, f.designation.provisional)
                || StreamArtistSuccessionHashes.designationRecord(
                        e,
                        f.designation.terms,
                        T.Authorization(f.designation.nonce, f.designation.signedAt, bytes(""))
                    ) != f.designation.recordHash
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        f.paired = succession.directives[f.designation.terms.directiveHash];
        f.forbidden = succession.directives[f.terminal.plan.directive];
        _directive(rotations, e, f, f.paired, f.designation.terms.directiveHash);
        _directive(rotations, e, f, f.forbidden, f.terminal.plan.directive);
        if (
            EstateState.activationCapabilities(
                    succession, f.terminal.plan.designation, f.terminal.plan.directive
                ) != f.terminal.plan.capabilities
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        guardian = DormGuardians.guardian(
            recovery.guardianHistory,
            rotations,
            e,
            p.artistId,
            recovery.guardianRecordsSeen[p.artistId],
            f.vesting,
            f.transition.postWindowEndsAt
        );
        proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_DORMANCY_FACTS_V1"),
                e.chainId,
                e.registry,
                address(this),
                f
            )
        );
        if (closureProof != 0) {
            proof = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_CLOSED_DORMANCY_FACTS_V1"),
                    proof,
                    closureProof
                )
            );
        }
        if (boundary.proof != 0) {
            proof = keccak256(
                abi.encode(
                    recovery.latest[p.artistId] == 0
                        ? keccak256("6529STREAM_ARTIST_RESOLVED_NOTICE_DORMANCY_FACTS_V1")
                        : keccak256("6529STREAM_ARTIST_RECOVERED_LIVING_DORMANCY_FACTS_V1"),
                    proof,
                    boundary.proof
                )
            );
        }
    }

    function _noticeHash(StreamArtistHashes.Environment memory e, Dorm.Notice memory n)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_NOTICE_V1"),
                e.chainId,
                e.registry,
                address(this),
                n.terms,
                n.incumbent,
                n.initiatedAt,
                n.noticeEndsAt,
                n.inactivitySeconds,
                n.noticeSeconds,
                n.timingRevision,
                n.priorLivenessAt,
                n.priorActivity,
                n.actionId,
                n.witnessHash
            )
        );
    }

    function _previous(
        RecoveryState.State storage s,
        StreamArtistRotationState.State storage r,
        StreamArtistHashes.Environment memory e,
        Facts memory f
    ) private view {
        bytes32 prior = f.vesting.previousTransitionRecordHash;
        if (prior == 0) {
            if (f.vesting.previousCommitment != 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(f.vesting.artistId);
            }
            return;
        }
        f.previous = s.vestingHistory.snapshots[prior];
        R.RotationRecord memory old = r.rotations[prior];
        if (
            f.previous.commitment == 0 || f.previous.commitment != f.vesting.previousCommitment
                || f.previous.commitment != _vestingHash(e, f.previous)
                || f.previous.artistId != f.vesting.artistId
                || f.previous.transitionRecordHash != prior || f.previous.operationId != 32
                || f.previous.authorityClass != 1 || f.previous.newAddress != f.notice.incumbent
                || f.previous.oldAddress == address(0)
                || f.previous.oldAddress == f.previous.newAddress
                || f.previous.ownerRevision >= f.vesting.ownerRevision
                || f.previous.executedAt > f.notice.initiatedAt
                || f.previous.guardians.count > f.vesting.guardians.count
                || f.previous.guardians.ownerRevision > f.vesting.guardians.ownerRevision
                || old.recordHash != prior || old.terms.artistId != f.vesting.artistId
                || old.terms.oldAddress != f.previous.oldAddress
                || old.terms.newAddress != f.previous.newAddress
                || old.transition.artistId != f.vesting.artistId
                || old.transition.recordHash != prior || old.transition.phase != 2
                || old.transition.executedAt != f.previous.executedAt
                || old.transition.postWindowEndsAt > f.notice.initiatedAt
                || (old.transition.contestedAt != 0
                    && old.transition.contestedAt < old.transition.postWindowEndsAt)
                || StreamArtistRotationHashes.rotationRecord(
                        e,
                        old.terms,
                        old.oldNonce,
                        old.transition.stagedAt,
                        old.transition.contestEndsAt
                    ) != prior
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(f.vesting.artistId);
        // The fixed producer admitted this same-artist latest-head chain once; no mutable retirement guess.
    }

    function _eligible(
        StreamArtistRotationState.State storage r,
        bytes32 id,
        R.ProvisionalAssociation memory a
    ) private view returns (bool) {
        return a.transitionRecordHash == 0
            ? a.windowEndsAt == 0
            : StreamArtistRotationState.eligible(r, id, a);
    }

    function _directive(
        StreamArtistRotationState.State storage r,
        StreamArtistHashes.Environment memory e,
        Facts memory f,
        Succ.DirectiveRecord memory d,
        bytes32 hash
    ) private view {
        if (hash == 0) {
            Succ.DirectiveRecord memory empty;
            if (keccak256(abi.encode(d)) != keccak256(abi.encode(empty))) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(f.vesting.artistId);
            }
            return;
        }
        if (
            d.recordHash != hash || d.terms.artistId != f.vesting.artistId || d.authorityClass != 1
                || d.signer == address(0)
                || (f.vesting.previousTransitionRecordHash == 0 && d.signer != f.notice.incumbent)
                || d.signedAt > f.notice.initiatedAt
                || !_eligible(r, f.vesting.artistId, d.provisional)
                || StreamArtistSuccessionHashes.directiveRecord(
                        e, d.terms, T.Authorization(d.nonce, d.signedAt, bytes(""))
                    ) != hash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(f.vesting.artistId);
    }

    function _contest(
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Recovery.Request memory p,
        Contest.Record memory c,
        bytes32 head
    ) private pure {
        if (
            cause.facts.kind != 1 || cause.facts.authorityClass != 3 || cause.facts.priorStatus != 3
                || c.recordHash == 0 || c.recordHash != cause.facts.referenceHash
                || c.terms.artistId != p.artistId || c.terms.subjectRecordHash != head
                || c.terms.evidenceHash != p.evidenceHash || c.terms.reasonHash != p.reasonHash
                || cause.facts.evidenceHash != p.evidenceHash
                || cause.facts.reasonHash != p.reasonHash || c.contester != cause.facts.actor
                || c.contestedAt != cause.facts.enteredAt || c.priorStatus != 3
                || c.pendingTransitionRecordHash != 0 || c.executedTransitionRecordHash != head
                || c.recordHash
                    != keccak256(
                        abi.encode(
                            bytes32(
                                0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb
                            ),
                            e.chainId,
                            e.registry,
                            p.artistId,
                            c.contester,
                            head,
                            p.evidenceHash,
                            p.reasonHash,
                            c.contestedAt
                        )
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
    }

    function _vestingHash(StreamArtistHashes.Environment memory e, V.Snapshot memory v)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    e.chainId,
                    e.registry,
                    address(this)
                ),
                abi.encode(
                    v.artistId,
                    v.transitionRecordHash,
                    v.operationId,
                    v.ownerRevision,
                    v.executedAt,
                    v.oldAddress,
                    v.newAddress,
                    v.authorityClass,
                    v.guardians,
                    v.previousTransitionRecordHash,
                    v.previousCommitment
                )
            )
        );
    }
}
