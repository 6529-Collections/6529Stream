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

/// @notice Fixed typed recovery read worker; preserves the original host context and checks.
library StreamArtistRecoveryEstateClosure {
    function _closure(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory current,
        R.TransitionState memory t
    ) public view returns (bytes32) {
        Dismissal.Closure memory closed = resolutions.closures[t.recordHash];
        Dismissal.Closure memory empty;
        if (keccak256(abi.encode(closed)) == keccak256(abi.encode(empty))) {
            if (
                current.facts.enteredAt < t.postWindowEndsAt
                    || (t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt)
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
            }
            return 0;
        }
        bool abandoned = t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt;
        if (
            closed.artistId != current.facts.artistId || closed.transitionRecordHash != t.recordHash
                || closed.dismissalRecordHash == 0 || closed.windowEndsAt != t.postWindowEndsAt
                || closed.contestedAt != t.contestedAt
                || (closed.contestedAt != 0 && closed.contestedAt < t.executedAt)
                || closed.abandoned != abandoned || current.facts.previousResolutionHash == 0
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
        }
        Dismissal.Record memory original = resolutions.records[closed.dismissalRecordHash];
        bytes32 originalProof = _dismissed(
            rotations,
            resolutions,
            contests,
            e,
            current.facts,
            t,
            original,
            closed.dismissalRecordHash
        );
        Dismissal.Cause memory firstCause = resolutions.causes[original.terms.expectedCauseHash];
        if (
            (firstCause.facts.kind == 1
                        ? firstCause.facts.enteredAt != closed.contestedAt
                        : closed.contestedAt != 0 || abandoned
                        || firstCause.facts.enteredAt < t.postWindowEndsAt)
                || (!abandoned && original.dismissedAt < t.postWindowEndsAt)
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
        }
        // The closure never moves. Today's latest admitted dismissal may be a later episode.
        Dismissal.Record memory latest = resolutions.records[current.facts.previousResolutionHash];
        bytes32 latestProof = _dismissed(
            rotations,
            resolutions,
            contests,
            e,
            current.facts,
            t,
            latest,
            current.facts.previousResolutionHash
        );
        if (
            latest.dismissedAt < original.dismissedAt
                || current.facts.previousCauseHash != latest.terms.expectedCauseHash
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
        }
        return keccak256(abi.encode(closed, originalProof, latestProof));
    }

    function _dismissed(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.CauseFacts memory current,
        R.TransitionState memory t,
        Dismissal.Record memory r,
        bytes32 expected
    ) private view returns (bytes32) {
        Dismissal.Cause memory cause = resolutions.causes[r.terms.expectedCauseHash];
        if (
            expected == 0 || r.recordHash != expected || r.terms.artistId != current.artistId
                || r.terms.evidenceHash == 0 || r.terms.reasonHash == 0 || r.executor == address(0)
                || r.proposer == address(0) || (r.actionClass != 1 && r.actionClass != 2)
                || r.actionId == 0 || r.incumbent != current.incumbent || r.authorityClass != 3
                || r.restoredStatus != 3 || r.dismissedAt == 0 || r.dismissedAt > current.enteredAt
                || r.cohortHash == 0 || r.governanceWitnessHash == 0
                || r.recordHash != Evidence._dismissalHash(e, r) || cause.causeHash == 0
                || cause.causeHash != r.terms.expectedCauseHash
                || cause.causeHash != Evidence._causeHash(e, cause)
                || cause.facts.artistId != current.artistId
                || cause.facts.executedTransitionHash != t.recordHash
                || cause.facts.incumbent != current.incumbent || cause.facts.actor == address(0)
                || cause.facts.referenceHash == 0 || cause.facts.enteredAt < t.executedAt
                || cause.facts.enteredAt > r.dismissedAt
                || cause.facts.previousResolutionHash != r.terms.expectedResolutionHash
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.artistId);
        }
        if (cause.facts.kind == 2) {
            return EstateHistory.standing(rotations, resolutions, e, cause, r, t);
        }
        if (
            cause.facts.pendingTransitionHash != 0 || cause.facts.evidenceHash == 0
                || cause.facts.reasonHash == 0
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.artistId);
        }
        Recovery.Request memory historical;
        historical.artistId = current.artistId;
        historical.evidenceHash = cause.facts.evidenceHash;
        historical.reasonHash = cause.facts.reasonHash;
        Contest.Record memory contest = contests.records[cause.facts.referenceHash];
        Evidence._contest(e, cause, historical, contest, t.recordHash);
        return keccak256(abi.encode(r, cause, contest));
    }

    function _lastVeto(
        StreamArtistRotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory current,
        R.TransitionState memory t
    ) public view returns (bytes32) {
        bytes32 latest = rotations.latestTransition[current.facts.artistId];
        if (latest == t.recordHash) return 0;
        Dismissal.Closure memory closed = resolutions.closures[latest];
        Dismissal.Record memory r = resolutions.records[closed.dismissalRecordHash];
        Dismissal.Cause memory cause = resolutions.causes[r.terms.expectedCauseHash];
        if (
            latest == 0 || closed.transitionRecordHash != latest || cause.facts.kind != 2
                || cause.facts.referenceHash != latest
                || r.dismissedAt
                    > resolutions.records[current.facts.previousResolutionHash].dismissedAt
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
        }
        return _dismissed(
            rotations, resolutions, contests, e, current.facts, t, r, closed.dismissalRecordHash
        );
    }
}
