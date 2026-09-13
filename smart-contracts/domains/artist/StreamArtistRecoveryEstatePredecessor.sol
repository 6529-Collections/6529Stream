// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistEstateState as EstateState } from "./StreamArtistEstateState.sol";
import { StreamArtistEstateHashes } from "./StreamArtistEstateHashes.sol";
import {
    StreamArtistIdentityContestState as ContestState
} from "./StreamArtistIdentityContestState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistGuardianHistory as History } from "./StreamArtistGuardianHistory.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistSuccessionState } from "./StreamArtistSuccessionState.sol";
import { StreamArtistSuccessionHashes } from "./StreamArtistSuccessionHashes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
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

/// @notice First nonaccelerated estate vesting with its original authority plan and guardian prefix.
/// @dev Reads admitted owner storage; it never reauthorizes historical coverage or rewrites a designation.
library StreamArtistRecoveryEstatePredecessor {
    struct Facts {
        Estate.RequestRecord request;
        Estate.ExecutionFacts execution;
        R.TransitionState transition;
        V.Snapshot vesting;
        GH.Head guardians;
        Succ.DesignationRecord designation;
        Succ.DirectiveRecord paired;
        Succ.DirectiveRecord forbidden;
        Contest.Record contest;
        uint32 capabilities;
    }

    function firstEstate(
        RecoveryState.State storage recovery,
        EstateState.State storage estate,
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistSuccessionState.State storage succession,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Recovery.Request memory p
    ) public view returns (bytes32) {
        bytes32 head = estate.authorityActivation[p.artistId];
        Facts memory f;
        f.request = estate.requests[head];
        f.execution = estate.executions[head];
        f.transition = estate.transitions[head];
        f.vesting = recovery.vestingHistory.snapshots[head];
        if (
            head == 0 || f.request.recordHash != head || f.request.terms.artistId != p.artistId
                || f.request.incumbent == address(0)
                || f.request.incumbent == f.request.terms.successor
                || f.request.terms.successor != cause.facts.incumbent
                || f.request.terms.evidenceHash == 0 || f.request.terms.selectedCoverageHash == 0
                || f.request.envelopeHash == 0 || f.request.requestedAt == 0
                || f.request.noticeRevision == 0 || f.request.rotationTimingRevision == 0
                || uint256(f.request.noticeEndsAt)
                    != uint256(f.request.requestedAt) + f.request.noticeSeconds
                || f.request.postContestSeconds < 72 hours
                || f.request.standingTailSeconds < 30 days
                || StreamArtistEstateHashes.record(
                        e,
                        f.request.terms,
                        f.request.authorization.nonce,
                        f.request.requestedAt,
                        f.request.noticeEndsAt
                    ) != head || estate.phases[head] != 2 || estate.pending[p.artistId] != 0
                || rotations.pending[p.artistId] != 0
                || rotations.latestExecution[p.artistId] != head
                || rotations.latestTransition[p.artistId] != head
                || rotations.retirement[p.artistId][f.request.incumbent] != head
                || cause.facts.executedTransitionHash != head
                || cause.facts.pendingTransitionHash != 0
                || f.execution.activationRecordHash != head || f.execution.coverageRecordHash == 0
                || f.execution.executedAt < f.request.noticeEndsAt
                || f.execution.delegationEpoch == 0 || f.execution.governanceActionId != 0
                || f.execution.governanceWitnessHash != 0 || f.transition.recordHash != head
                || f.transition.artistId != p.artistId || f.transition.phase != 2
                || f.transition.stagedAt != f.request.requestedAt
                || f.transition.contestEndsAt != f.request.noticeEndsAt
                || f.transition.executedAt != f.execution.executedAt
                || uint256(f.transition.postWindowEndsAt)
                    != uint256(f.execution.executedAt) + f.request.postContestSeconds
                || cause.facts.enteredAt < f.transition.postWindowEndsAt
                || block.timestamp < cause.facts.enteredAt
                || (f.transition.contestedAt != 0
                    && f.transition.contestedAt < f.transition.postWindowEndsAt)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        Dismissal.Closure memory empty;
        if (keccak256(abi.encode(resolutions.closures[head])) != keccak256(abi.encode(empty))) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        f.guardians = History.requireComplete(
            recovery.guardianHistory, p.artistId, recovery.guardianRecordsSeen[p.artistId]
        );
        if (
            recovery.vestingHistory.latest[p.artistId] != head || f.vesting.artistId != p.artistId
                || f.vesting.transitionRecordHash != head || f.vesting.operationId != 40
                || f.vesting.authorityClass != 3 || f.vesting.oldAddress != f.request.incumbent
                || f.vesting.newAddress != cause.facts.incumbent
                || f.vesting.executedAt != f.execution.executedAt || f.vesting.ownerRevision == 0
                || f.vesting.ownerRevision <= f.guardians.ownerRevision
                || f.vesting.previousTransitionRecordHash != 0 || f.vesting.previousCommitment != 0
                || f.vesting.commitment == 0 || f.vesting.commitment != _vestingHash(e, f.vesting)
                || keccak256(abi.encode(f.guardians)) != keccak256(abi.encode(f.vesting.guardians))
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        if (
            cause.causeHash
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
        f.contest = contests.records[cause.facts.referenceHash];
        _contest(e, cause, p, f.contest, head);
        f.designation = succession.designations[f.request.designationRecordHash];
        if (
            f.request.designationRecordHash == 0
                || f.request.terms.expectedDesignationRecordHash != f.request.designationRecordHash
                || StreamArtistSuccessionState.operativeDesignation(
                        succession, rotations, p.artistId
                    ) != f.request.designationRecordHash
                || StreamArtistSuccessionState.operativeDirective(succession, rotations, p.artistId)
                    != f.request.forbiddenDirectiveRecordHash
                || f.designation.recordHash != f.request.designationRecordHash
                || f.designation.terms.artistId != p.artistId
                || f.designation.terms.successor != f.request.terms.successor
                || f.designation.terms.directiveHash != f.request.pairedDirectiveRecordHash
                || f.designation.authorityClass != 1 || f.designation.signer != f.request.incumbent
                || f.designation.signedAt > f.request.requestedAt
                || f.designation.provisional.transitionRecordHash != 0
                || f.designation.provisional.windowEndsAt != 0
                || StreamArtistSuccessionHashes.designationRecord(
                        e,
                        f.designation.terms,
                        T.Authorization(f.designation.nonce, f.designation.signedAt, bytes(""))
                    ) != f.designation.recordHash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        f.paired = succession.directives[f.request.pairedDirectiveRecordHash];
        f.forbidden = succession.directives[f.request.forbiddenDirectiveRecordHash];
        _directive(e, f.request, f.paired, f.request.pairedDirectiveRecordHash);
        _directive(e, f.request, f.forbidden, f.request.forbiddenDirectiveRecordHash);
        f.capabilities = EstateState.activationCapabilities(
            succession, f.request.designationRecordHash, f.request.forbiddenDirectiveRecordHash
        );
        if (
            f.capabilities != f.execution.effectiveCapabilities
                || f.capabilities & ~uint32(4095) != 0
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ESTATE_FACTS_V1"),
                e.chainId,
                e.registry,
                address(this),
                f
            )
        );
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

    function _directive(
        StreamArtistHashes.Environment memory e,
        Estate.RequestRecord memory request,
        Succ.DirectiveRecord memory d,
        bytes32 hash
    ) private view {
        if (hash == 0) {
            Succ.DirectiveRecord memory empty;
            if (keccak256(abi.encode(d)) != keccak256(abi.encode(empty))) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(request.terms.artistId);
            }
            return;
        }
        if (
            d.recordHash != hash || d.terms.artistId != request.terms.artistId
                || d.authorityClass != 1 || d.signer != request.incumbent
                || d.signedAt > request.requestedAt || d.provisional.transitionRecordHash != 0
                || d.provisional.windowEndsAt != 0
                || StreamArtistSuccessionHashes.directiveRecord(
                        e, d.terms, T.Authorization(d.nonce, d.signedAt, bytes(""))
                    ) != hash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(request.terms.artistId);
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
