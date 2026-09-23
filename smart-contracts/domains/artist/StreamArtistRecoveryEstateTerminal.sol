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

import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import {
    StreamArtistRecoveryEstateClosed as EstateClosed
} from "./StreamArtistRecoveryEstateClosed.sol";
import {
    StreamArtistRecoveryEstateRotationHistory as RotationHistory
} from "./StreamArtistRecoveryEstateRotationHistory.sol";
import {
    StreamArtistRecoveryEstateRotationOrigin as RotationOrigin
} from "./StreamArtistRecoveryEstateRotationOrigin.sol";

import {
    StreamArtistRecoveryEstateEvidence as Evidence
} from "./StreamArtistRecoveryEstateEvidence.sol";

/// @notice Fixed typed recovery read worker; preserves the original host context and checks.
library StreamArtistRecoveryEstateTerminal {
    struct Origin {
        Estate.RequestRecord request;
        R.TransitionState transition;
        V.Snapshot vesting;
        GH.Head guardians;
    }

    function _terminal(
        RecoveryState.State storage recovery,
        StreamArtistRotationState.State storage rotations,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Origin memory origin,
        bytes32 head,
        bytes32 closureProof,
        bytes32 originProof
    ) public view returns (bytes32) {
        bytes32 artistId = cause.facts.artistId;
        R.RotationRecord memory r = rotations.rotations[head];
        R.TransitionState memory t = r.transition;
        V.Snapshot memory v = recovery.vestingHistory.snapshots[head];
        bytes32 retired = rotations.retirement[artistId][origin.request.terms.successor];
        if (
            r.recordHash != head || r.terms.artistId != artistId
                || r.terms.oldAddress != origin.request.terms.successor
                || r.terms.newAddress != cause.facts.incumbent || r.terms.newAddress == address(0)
                || r.terms.newAddress == r.terms.oldAddress
                || r.terms.expectedPreviousTransitionRecordHash != origin.request.recordHash
                || (closureProof == 0 && rotations.latestTransition[artistId] != head)
                || retired != head || t.artistId != artistId || t.recordHash != head || t.phase != 2
                || t.stagedAt < origin.transition.executedAt
                || (originProof == 0 && t.stagedAt < origin.transition.postWindowEndsAt)
                || t.contestEndsAt < t.stagedAt || t.executedAt < t.stagedAt || t.executedAt == 0
                || r.effectiveWindow < 72 hours || r.standingTail < 30 days || r.timingRevision == 0
                || (t.executedAt < t.contestEndsAt
                    && (r.approvalThreshold == 0 || r.guardianApprovals < r.approvalThreshold))
                || uint256(t.postWindowEndsAt) != uint256(t.executedAt) + r.effectiveWindow
                || (closureProof == 0
                    && (cause.facts.enteredAt < t.postWindowEndsAt
                        || t.contestedAt != cause.facts.enteredAt))
                || StreamArtistRotationHashes.rotationRecord(
                        Evidence._recordEnvironment(e, 29, r.terms.artistId, r.recordHash),
                        r.terms,
                        r.oldNonce,
                        t.stagedAt,
                        t.contestEndsAt
                    ) != head || v.artistId != artistId || v.transitionRecordHash != head
                || v.operationId != 32 || v.authorityClass != 3
                || v.oldAddress != r.terms.oldAddress || v.newAddress != r.terms.newAddress
                || v.executedAt != t.executedAt || !Evidence._before(e, origin.vesting, v)
                || (Imported.commitment() == 0 && v.ownerRevision <= v.guardians.ownerRevision)
                || v.guardians.count < origin.vesting.guardians.count
                || v.previousTransitionRecordHash != origin.request.recordHash
                || v.previousCommitment != origin.vesting.commitment || v.commitment == 0
                || v.commitment != Evidence._vestingHash(e, v)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        // Each producer saved the complete original prefix. Keep both, including lower-nonce veto members.
        GH.Head memory h = v.guardians;
        if (h.count == 0) {
            if (h.ownerRevision != 0 || h.commitment != 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        } else {
            bytes32 last = recovery.guardianHistory.records[artistId][h.count];
            GH.Entry memory entry = recovery.guardianHistory.entries[last];
            R.GuardianRecord memory g = rotations.guardians[last];
            if (
                h.count > origin.guardians.count || last == 0 || entry.artistId != artistId
                    || entry.recordHash != last || entry.index != h.count
                    || entry.ownerRevision != h.ownerRevision || entry.commitment != h.commitment
                    || h.commitment == 0 || g.recordHash != last
                    || entry.recordDataHash != keccak256(abi.encode(g))
                    || StreamArtistRotationHashes.guardianRecord(
                            Evidence._recordEnvironment(e, 28, g.terms.artistId, g.recordHash),
                            g.terms,
                            T.Authorization(g.nonce, g.signedAt, bytes(""))
                        ) != last
            ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        return keccak256(abi.encode(r, v, retired));
    }
}
