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
    StreamArtistRecoveryDormancyGuardians as DormGuardians
} from "./StreamArtistRecoveryDormancyGuardians.sol";
import { StreamArtistRecoveryEstateClosed as Closed } from "./StreamArtistRecoveryEstateClosed.sol";
import {
    StreamArtistRecoveryEstateRotationHistory as RotationHistory
} from "./StreamArtistRecoveryEstateRotationHistory.sol";

import {
    StreamArtistRecoveryDormancyRotationOrigin as RotationOrigin
} from "./StreamArtistRecoveryDormancyRotationOrigin.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

import {
    StreamArtistRecoveryDormancyEvidence as Evidence
} from "./StreamArtistRecoveryDormancyEvidence.sol";
import { StreamArtistRecoveryDormancyPlan as Plan } from "./StreamArtistRecoveryDormancyPlan.sol";

/// @notice Designated op43 authority followed by admitted class3 rotations and first recovery.
/// @dev Original appointment remains the capability origin; terminal op32 supplies current authority.
/// Original op43 and intermediate/terminal op32 closures use their respective original principals
/// and canonical immutable dismissal/cause records, never historical reauthorization.
/// @dev Consumes admitted notice/action/vesting records; never reauthorizes historical governance.
library StreamArtistRecoveryDormancyRotation {
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
        return _facts(
            recovery,
            dormancy,
            estate,
            rotations,
            resolutions,
            succession,
            contests,
            e,
            cause,
            p,
            bytes32(0)
        );
    }

    /// @dev The fixed caller authenticates the complete current cause and post-origin history.
    /// Original notice, appointment, capabilities and guardian prefix remain local.
    function factsWithHistory(
        RecoveryState.State storage recovery,
        StreamArtistDormancyState.State storage dormancy,
        EstateState.State storage estate,
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistSuccessionState.State storage succession,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Recovery.Request memory p,
        bytes32 historyProof
    ) public view returns (bytes32 proof, R.GuardianRecord memory guardian) {
        if (historyProof == 0) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        return _facts(
            recovery,
            dormancy,
            estate,
            rotations,
            resolutions,
            succession,
            contests,
            e,
            cause,
            p,
            historyProof
        );
    }

    function _facts(
        RecoveryState.State storage recovery,
        StreamArtistDormancyState.State storage dormancy,
        EstateState.State storage estate,
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistSuccessionState.State storage succession,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Recovery.Request memory p,
        bytes32 historyProof
    ) private view returns (bytes32 proof, R.GuardianRecord memory guardian) {
        bytes32 head = dormancy.activation[p.artistId];
        bytes32 terminal = rotations.latestExecution[p.artistId];
        Facts memory f;
        f.terminal = dormancy.terminals[head];
        f.notice = dormancy.notices[f.terminal.noticeHash];
        f.transition = dormancy.transitions[head];
        f.vesting = recovery.vestingHistory.snapshots[head];
        Dorm.Terminal memory hashTerminal = f.terminal;
        bytes32 originalRecordHash = hashTerminal.recordHash;
        hashTerminal.recordHash = 0;
        (StreamArtistHashes.Environment memory completion, address completionOwner) =
            Evidence._original(e, 43, p.artistId, head);
        bytes32 terminalHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_V1"),
                completion.chainId,
                completion.registry,
                completionOwner,
                hashTerminal
            )
        );
        hashTerminal.recordHash = originalRecordHash;
        if (
            head == 0 || f.terminal.recordHash != head || terminalHash != head
                || f.terminal.noticeHash == 0 || f.notice.recordHash != f.terminal.noticeHash
                || f.notice.terms.artistId != p.artistId || f.notice.incumbent == address(0)
                || f.notice.incumbent == f.terminal.plan.authority
                || Evidence._noticeHash(e, f.notice) != f.notice.recordHash
                || f.notice.initiatedAt == 0 || f.notice.terms.evidenceHash == 0
                || f.notice.actionId == 0 || f.notice.witnessHash == 0
                || f.notice.inactivitySeconds < 365 days || f.notice.noticeSeconds < 180 days
                || f.notice.timingRevision == 0
                || uint256(f.notice.noticeEndsAt)
                    != uint256(f.notice.initiatedAt) + f.notice.noticeSeconds
                || uint256(f.notice.initiatedAt)
                    < uint256(f.notice.priorLivenessAt) + f.notice.inactivitySeconds
                || dormancy.latestNotice[p.artistId] != f.notice.recordHash
                || dormancy.phases[f.notice.recordHash] != 3
                || dormancy.terminalForNotice[f.notice.recordHash] != head
                || dormancy.activity[p.artistId] != f.notice.priorActivity
                || f.terminal.authorityClass != 3 || f.terminal.plan.authorityClass != 3
                || f.terminal.appointmentBlock != 0 || f.terminal.plan.authority == address(0)
                || f.terminal.actor == address(0) || f.terminal.evidenceHash == 0
                || f.terminal.actionId == 0 || f.terminal.witnessHash == 0
                || f.terminal.observedAt < f.notice.noticeEndsAt || f.terminal.delegationEpoch == 0
                || f.terminal.delegationEpoch != estate.delegationEpoch[p.artistId]
                || f.terminal.plan.designation == 0 || f.terminal.plan.stewardGrantRecordHash != 0
                || f.terminal.plan.postSeconds < 72 hours || f.terminal.plan.standingTail < 30 days
                || estate.authorityActivation[p.artistId] != 0 || estate.pending[p.artistId] != 0
                || rotations.pending[p.artistId] != 0 || terminal == 0 || terminal == head
                || cause.facts.executedTransitionHash != terminal
                || (historyProof == 0 && cause.facts.pendingTransitionHash != 0)
                || f.transition.artistId != p.artistId || f.transition.recordHash != head
                || f.transition.phase != 2 || f.transition.stagedAt != f.notice.initiatedAt
                || f.transition.contestEndsAt != f.notice.noticeEndsAt
                || f.transition.executedAt != f.terminal.observedAt
                || uint256(f.transition.postWindowEndsAt)
                    != uint256(f.terminal.observedAt) + f.terminal.plan.postSeconds
                || block.timestamp < cause.facts.enteredAt
                || recovery.vestingHistory.latest[p.artistId] != terminal
                || f.vesting.artistId != p.artistId || f.vesting.transitionRecordHash != head
                || f.vesting.operationId != 43 || f.vesting.authorityClass != 3
                || f.vesting.oldAddress != f.notice.incumbent
                || f.vesting.newAddress != f.terminal.plan.authority
                || f.vesting.executedAt != f.terminal.observedAt || f.vesting.ownerRevision == 0
                || (Imported.commitment() == 0
                    && f.vesting.ownerRevision <= f.vesting.guardians.ownerRevision)
                || f.vesting.commitment == 0
                || f.vesting.commitment != Evidence._vestingHash(e, f.vesting)
                || cause.causeHash != Evidence._causeHash(e, cause)
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        LivingBoundary.Facts memory boundary;
        bytes32 originProof;
        bytes32 closureProof;
        bytes32 terminalProof;
        if (historyProof == 0) {
            boundary = LivingBoundary.facts(
                recovery, rotations, resolutions, e, f.notice, f.terminal, f.vesting, cause
            );
            originProof = RotationOrigin.proof(
                rotations,
                resolutions,
                contests,
                e,
                f.transition,
                f.terminal.plan.authority,
                rotations.rotations[terminal].transition.stagedAt,
                boundary.cause,
                boundary.resolution
            );
            closureProof = Closed.proof(
                rotations, resolutions, contests, e, cause, rotations.rotations[terminal].transition
            );
            terminalProof = RotationHistory.terminal(
                recovery,
                rotations,
                resolutions,
                contests,
                e,
                f.vesting,
                f.transition,
                cause,
                terminal,
                closureProof
            );
        }
        if (historyProof == 0 && recovery.latest[p.artistId] == 0) {
            f.previous = Plan._previous(
                recovery, rotations, e, f.notice, f.vesting, f.previous, boundary.proof != 0
            );
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
        if (historyProof == 0) Evidence._contest(e, cause, p, f.contest, terminal);
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
                || !Plan._eligible(rotations, p.artistId, f.designation.provisional)
                || StreamArtistSuccessionHashes.designationRecord(
                        Evidence._recordEnvironment(e, 36, p.artistId, f.designation.recordHash),
                        f.designation.terms,
                        T.Authorization(f.designation.nonce, f.designation.signedAt, bytes(""))
                    ) != f.designation.recordHash
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        f.paired = succession.directives[f.designation.terms.directiveHash];
        f.forbidden = succession.directives[f.terminal.plan.directive];
        Plan._directive(
            rotations, e, f.notice, f.vesting, f.paired, f.designation.terms.directiveHash
        );
        Plan._directive(rotations, e, f.notice, f.vesting, f.forbidden, f.terminal.plan.directive);
        if (
            EstateState.activationCapabilities(
                    succession, f.terminal.plan.designation, f.terminal.plan.directive
                ) != f.terminal.plan.capabilities
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        guardian = DormGuardians.afterRotation(
            recovery.guardianHistory,
            rotations,
            e,
            p.artistId,
            recovery.guardianRecordsSeen[p.artistId],
            f.vesting,
            f.transition.postWindowEndsAt,
            recovery.vestingHistory.snapshots[terminal],
            rotations.rotations[terminal].transition.postWindowEndsAt
        );
        proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_ROTATED_DORMANCY_FACTS_V1"),
                e.chainId,
                e.registry,
                address(this),
                f,
                terminalProof
            )
        );
        if (closureProof != 0) {
            proof = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_CLOSED_ROTATED_DORMANCY_FACTS_V1"),
                    proof,
                    closureProof
                )
            );
        }
        if (originProof != 0) {
            proof = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_CLOSED_ORIGIN_ROTATED_DORMANCY_FACTS_V1"),
                    proof,
                    originProof
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
        if (historyProof != 0) {
            proof = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_ROTATED_DORMANCY_WITH_HISTORY_FACTS_V1"),
                    proof,
                    cause,
                    historyProof
                )
            );
        }
    }
}
