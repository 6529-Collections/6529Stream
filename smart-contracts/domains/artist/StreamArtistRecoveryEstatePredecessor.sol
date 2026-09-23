// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredHistoryOrder as Order
} from "./StreamArtistRecoveredHistoryOrder.sol";

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
import {
    StreamArtistRecoveryEstateGuardians as EstateGuardians
} from "./StreamArtistRecoveryEstateGuardians.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveryEstateHistory as EstateHistory
} from "./StreamArtistRecoveryEstateHistory.sol";
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

import {
    StreamArtistRecoveryEstateEvidence as Evidence
} from "./StreamArtistRecoveryEstateEvidence.sol";
import { StreamArtistRecoveryEstatePlan as Plan } from "./StreamArtistRecoveryEstatePlan.sol";
import {
    StreamArtistRecoveryEstateClosure as Closure
} from "./StreamArtistRecoveryEstateClosure.sol";

/// @notice First admitted estate vesting with its original authority plan and guardian prefix.
/// @dev Reads admitted owner storage; it never reauthorizes historical coverage or rewrites a designation.
library StreamArtistRecoveryEstatePredecessor {
    // Retain the original error ABI after moving its throwing helper to a fixed worker.
    error InvalidRecoveredHydrationProvenance();

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
        return _firstEstate(
            recovery, estate, rotations, resolutions, succession, contests, e, cause, p, bytes32(0)
        );
    }

    /// @dev The fixed caller supplies its complete authenticated current-cause/staging history.
    /// The original estate request, capabilities, vesting and guardian prefix remain local.
    function firstEstateWithHistory(
        RecoveryState.State storage recovery,
        EstateState.State storage estate,
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistSuccessionState.State storage succession,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Recovery.Request memory p,
        bytes32 historyProof
    ) public view returns (bytes32) {
        if (historyProof == 0) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        return _firstEstate(
            recovery,
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

    function _firstEstate(
        RecoveryState.State storage recovery,
        EstateState.State storage estate,
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistSuccessionState.State storage succession,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Recovery.Request memory p,
        bytes32 historyProof
    ) private view returns (bytes32) {
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
                        Evidence._recordEnvironment(e, 38, p.artistId, head),
                        f.request.terms,
                        f.request.authorization.nonce,
                        f.request.requestedAt,
                        f.request.noticeEndsAt
                    ) != head || estate.phases[head] != 2 || estate.pending[p.artistId] != 0
                || rotations.pending[p.artistId] != 0
                || rotations.latestExecution[p.artistId] != head
                || rotations.retirement[p.artistId][f.request.incumbent] != head
                || cause.facts.executedTransitionHash != head
                || (historyProof == 0 && cause.facts.pendingTransitionHash != 0)
                || f.execution.activationRecordHash != head || f.execution.coverageRecordHash == 0
                || f.execution.executedAt < f.request.requestedAt
                || f.execution.delegationEpoch == 0 || f.transition.recordHash != head
                || f.transition.artistId != p.artistId || f.transition.phase != 2
                || f.transition.stagedAt != f.request.requestedAt
                || f.transition.contestEndsAt != f.request.noticeEndsAt
                || f.transition.executedAt != f.execution.executedAt
                || uint256(f.transition.postWindowEndsAt)
                    != uint256(f.execution.executedAt) + f.request.postContestSeconds
                || block.timestamp < cause.facts.enteredAt
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        if (historyProof != 0) {
            bytes32 previousRecovery = recovery.latest[p.artistId];
            if (
                f.execution.delegationEpoch != estate.delegationEpoch[p.artistId]
                    || (previousRecovery != 0
                        && (recovery.records[previousRecovery].fields.vestedAuthorityClass != 1
                            || recovery.records[previousRecovery].delegationEpoch
                                >= f.execution.delegationEpoch))
            ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        // Original operation40 already authenticated and consumed the historical accelerator.
        // Preserve its exact timing/witness shape without reauthorizing old governance or coverage.
        if (f.execution.executedAt < f.request.noticeEndsAt) {
            if (f.execution.governanceActionId == 0 || f.execution.governanceWitnessHash == 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
            }
        } else if (f.execution.governanceActionId != 0 || f.execution.governanceWitnessHash != 0) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        bytes32 closureProof;
        bytes32 laterProof;
        if (historyProof == 0) {
            closureProof =
                Closure._closure(rotations, resolutions, contests, e, cause, f.transition);
            laterProof = Closure._lastVeto(rotations, resolutions, contests, e, cause, f.transition);
            if (laterProof != 0 && closureProof == 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
            }
        }
        if (
            recovery.vestingHistory.latest[p.artistId] != head || f.vesting.artistId != p.artistId
                || f.vesting.transitionRecordHash != head || f.vesting.operationId != 40
                || f.vesting.authorityClass != 3 || f.vesting.oldAddress != f.request.incumbent
                || f.vesting.newAddress != cause.facts.incumbent
                || f.vesting.executedAt != f.execution.executedAt || f.vesting.ownerRevision == 0
                || (Imported.commitment() == 0
                    && f.vesting.ownerRevision <= f.vesting.guardians.ownerRevision)
                || f.vesting.commitment == 0
                || f.vesting.commitment != Evidence._vestingHash(e, f.vesting)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        bytes32 ancestry;
        if (historyProof == 0) {
            ancestry = EstateHistory.previous(recovery, rotations, e, f.request, f.vesting);
        }
        bool hasAncestry =
            historyProof == 0 ? ancestry != 0 : f.vesting.previousTransitionRecordHash != 0;
        f.guardians = EstateGuardians.prefix(
            recovery.guardianHistory,
            rotations,
            e,
            p.artistId,
            recovery.guardianRecordsSeen[p.artistId],
            f.vesting
        );
        if (cause.causeHash != Evidence._causeHash(e, cause)) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        f.contest = contests.records[cause.facts.referenceHash];
        if (historyProof == 0) Evidence._contest(e, cause, p, f.contest, head);
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
                || f.designation.authorityClass != 1 || f.designation.signer == address(0)
                || (!hasAncestry && f.designation.signer != f.request.incumbent)
                || f.designation.signedAt > f.request.requestedAt
                || !Plan._planAssociation(
                    rotations, p.artistId, f.designation.provisional, hasAncestry
                )
                || StreamArtistSuccessionHashes.designationRecord(
                        Evidence._recordEnvironment(e, 36, p.artistId, f.designation.recordHash),
                        f.designation.terms,
                        T.Authorization(f.designation.nonce, f.designation.signedAt, bytes(""))
                    ) != f.designation.recordHash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        f.paired = succession.directives[f.request.pairedDirectiveRecordHash];
        f.forbidden = succession.directives[f.request.forbiddenDirectiveRecordHash];
        Plan._directive(
            rotations, e, f.request, f.paired, f.request.pairedDirectiveRecordHash, hasAncestry
        );
        Plan._directive(
            rotations,
            e,
            f.request,
            f.forbidden,
            f.request.forbiddenDirectiveRecordHash,
            hasAncestry
        );
        f.capabilities = EstateState.activationCapabilities(
            succession, f.request.designationRecordHash, f.request.forbiddenDirectiveRecordHash
        );
        if (
            f.capabilities != f.execution.effectiveCapabilities
                || f.capabilities & ~uint32(4095) != 0
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        bytes32 factsHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ESTATE_FACTS_V1"),
                e.chainId,
                e.registry,
                address(this),
                f
            )
        );
        if (closureProof != 0) {
            factsHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_CLOSED_FIRST_ESTATE_FACTS_V1"),
                    factsHash,
                    closureProof
                )
            );
        }
        if (ancestry != 0 || laterProof != 0) {
            factsHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_ESTATE_CONTINUATION_FACTS_V1"),
                    factsHash,
                    ancestry,
                    laterProof
                )
            );
        }
        if (historyProof == 0) return factsHash;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ESTATE_WITH_HISTORY_FACTS_V1"),
                factsHash,
                cause,
                historyProof
            )
        );
    }

    // Consume authenticated immutable owner records, not a fresh historical governance decision.
    // Original immutable causes distinguish compromise from a pending-rotation standing veto.
}
