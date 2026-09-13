// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveryEstateGuardians as EstateGuardians
} from "./StreamArtistRecoveryEstateGuardians.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import { StreamArtistGuardianAppealReads } from "./StreamArtistGuardianAppealReads.sol";
import {
    StreamArtistGuardianSupersession as GuardianSupersession
} from "./StreamArtistGuardianSupersession.sol";
import { StreamArtistGuardianVestingHistory } from "./StreamArtistGuardianVestingHistory.sol";
import {
    StreamArtistRecoveryHistoricalPredecessor as HistoricalPredecessor
} from "./StreamArtistRecoveryHistoricalPredecessor.sol";
import {
    StreamArtistRecoveryPredecessor as Predecessor
} from "./StreamArtistRecoveryPredecessor.sol";
import { StreamArtistGuardianHistory as GuardianHistory } from "./StreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";

import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistIdentityState } from "./StreamArtistIdentityState.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistIdentityResolutionState } from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistEstateState } from "./StreamArtistEstateState.sol";
import {
    StreamArtistIdentityRecoveryReceipts as Receipts
} from "./StreamArtistIdentityRecoveryReceipts.sol";
import { StreamArtistIdentityRecoveryHashes as H } from "./StreamArtistIdentityRecoveryHashes.sol";
import {
    StreamArtistIdentityRecoveryTypes as Permanent
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRecoveryEstatePredecessor } from "./StreamArtistRecoveryEstatePredecessor.sol";
import { StreamArtistSuccessionState } from "./StreamArtistSuccessionState.sol";
import { StreamArtistIdentityContestState } from "./StreamArtistIdentityContestState.sol";

/// @notice One-way delegated recovery context; State is imported only for its storage type.
library StreamArtistIdentityRecoveryContext {
    function context(
        RecoveryState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        StreamArtistIdentityState.OwnerContext memory o,
        Recovery.Request memory p,
        T.Authorization memory acceptance
    ) public view returns (Recovery.Context memory c) {
        Dismissal.Cause memory cause = resolutions.causes[resolutions.currentCause[p.artistId]];
        T.Identity storage principal = identity.identities[p.artistId];
        if (
            p.artistId == bytes32(0) || cause.causeHash == bytes32(0)
                || cause.causeHash != p.expectedCauseHash || cause.facts.artistId != p.artistId
                || (cause.facts.kind != 1 && cause.facts.kind != 2)
                || cause.facts.referenceHash == bytes32(0) || cause.facts.actor == address(0)
                || cause.facts.incumbent == address(0) || principal.status != 4
                || principal.authorityClass != cause.facts.authorityClass
                || principal.authorityAddress != cause.facts.incumbent
                || identity.activeIdentity[principal.authorityAddress] != p.artistId
                || resolutions.latestResolution[p.artistId] != p.expectedResolutionHash
                || cause.facts.previousResolutionHash != p.expectedResolutionHash
                || p.newAddress == address(0) || p.newAddress == principal.authorityAddress
                || p.evidenceHash == bytes32(0) || p.reasonHash == bytes32(0)
        ) revert Recovery.InvalidIdentityRecovery(p.artistId);
        if (
            p.vestedAuthorityClass != 1 || cause.facts.authorityClass != 1
                || cause.facts.priorStatus != 1 || rotations.pending[p.artistId] != bytes32(0)
                || cause.facts.pendingTransitionHash != bytes32(0)
                || s.latest[p.artistId] != bytes32(0)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        bytes32 predecessor;
        bool historicalPredecessor;
        if (rotations.latestExecution[p.artistId] == bytes32(0)) {
            if (
                rotations.latestTransition[p.artistId] != bytes32(0)
                    || rotations.provisionalGuardian[p.artistId] != bytes32(0)
                    || cause.facts.executedTransitionHash != bytes32(0)
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
            }
        } else {
            R.RotationRecord storage previous =
                rotations.rotations[rotations.latestExecution[p.artistId]];
            historicalPredecessor = previous.terms.expectedPreviousTransitionRecordHash != 0
                || (previous.transition.contestedAt != 0
                    && previous.transition.contestedAt < previous.transition.postWindowEndsAt);
            predecessor = historicalPredecessor
                ? HistoricalPredecessor.rotation(
                    rotations, resolutions, o.environment, cause.facts, principal.authorityAddress
                )
                : Predecessor.firstRotation(
                    rotations, o.environment, cause.facts, principal.authorityAddress
                );
        }
        if (identity.activeIdentity[p.newAddress] != bytes32(0)) {
            revert T.AddressAlreadyRegistered(p.newAddress);
        }
        c.causeHash = cause.causeHash;
        c.incumbent = principal.authorityAddress;
        c.postContestSeconds = StreamArtistRotationState.rotationSeconds(rotations);
        R.GuardianRecord memory guardian = _guardian(s, rotations, o, p.artistId, c.incumbent);
        bytes32 supersessionContext;
        if (p.supersededRecordHashes.length != 0) {
            (supersessionContext, c.postContestSeconds) = GuardianSupersession.contextAndWindow(
                s.guardianSupersession,
                s.guardianHistory,
                s.vestingHistory,
                rotations,
                o.environment,
                cause,
                p,
                s.guardianRecordsSeen[p.artistId],
                c.postContestSeconds
            );
        } else if (guardian.terms.minContestSeconds > c.postContestSeconds) {
            c.postContestSeconds = guardian.terms.minContestSeconds;
        }
        c.standingTailSeconds = StreamArtistRotationState.standingSeconds(rotations);
        c.timingRevision = rotations.timingRevision == 0 ? 1 : rotations.timingRevision;
        c.delegationEpoch = estate.delegationEpoch[p.artistId];
        c.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_SCOPE_V2"),
                o.environment.chainId,
                o.environment.registry,
                address(this),
                p.artistId
            )
        );
        c.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_STATE_V2"),
                c.scopeHash,
                cause,
                principal,
                p.expectedResolutionHash,
                c.postContestSeconds,
                c.standingTailSeconds,
                c.timingRevision,
                c.delegationEpoch
            )
        );
        // Registration changes owner revision, but never these scheduled transition facts.
        if (guardian.recordHash != bytes32(0)) {
            c.oldValueHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDED_RECOVERY_STATE_V1"),
                    c.oldValueHash,
                    guardian,
                    s.guardianRecordsSeen[p.artistId]
                )
            );
        }
        if (guardian.recordHash != bytes32(0)) {
            GH.Head memory history = GuardianHistory.requireComplete(
                s.guardianHistory, p.artistId, s.guardianRecordsSeen[p.artistId]
            );
            c.oldValueHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_CONTEXT_V1"),
                    c.oldValueHash,
                    history
                )
            );
        }
        if (predecessor != bytes32(0)) {
            c.oldValueHash = keccak256(
                abi.encode(
                    historicalPredecessor
                        ? keccak256("6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_CONTEXT_V1")
                        : keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_CONTEXT_V1"),
                    c.oldValueHash,
                    predecessor
                )
            );
        }
        if (p.supersededRecordHashes.length != 0) {
            c.oldValueHash = keccak256(abi.encode(c.oldValueHash, supersessionContext));
        }
        c.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_INTENT_V2"),
                c.scopeHash,
                c.oldValueHash,
                p,
                acceptance.nonce,
                acceptance.time
            )
        );
    }

    function contextWithEstate(
        RecoveryState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityContestState.State storage contests,
        StreamArtistIdentityState.OwnerContext memory o,
        Recovery.Request memory p,
        T.Authorization memory acceptance
    ) public view returns (Recovery.Context memory c) {
        if (p.vestedAuthorityClass != 3) {
            return context(s, identity, rotations, resolutions, estate, o, p, acceptance);
        }
        Dismissal.Cause memory cause = resolutions.causes[resolutions.currentCause[p.artistId]];
        T.Identity storage principal = identity.identities[p.artistId];
        if (
            p.artistId == bytes32(0) || cause.causeHash == bytes32(0)
                || cause.causeHash != p.expectedCauseHash || cause.facts.artistId != p.artistId
                || cause.facts.kind != 1 || cause.facts.referenceHash == bytes32(0)
                || cause.facts.actor == address(0) || cause.facts.incumbent == address(0)
                || principal.status != 4 || principal.authorityClass != cause.facts.authorityClass
                || principal.authorityAddress != cause.facts.incumbent
                || identity.activeIdentity[principal.authorityAddress] != p.artistId
                || resolutions.latestResolution[p.artistId] != p.expectedResolutionHash
                || cause.facts.previousResolutionHash != p.expectedResolutionHash
                || p.newAddress == address(0) || p.newAddress == principal.authorityAddress
                || p.evidenceHash == bytes32(0) || p.reasonHash == bytes32(0)
        ) revert Recovery.InvalidIdentityRecovery(p.artistId);
        if (
            p.vestedAuthorityClass != 3 || cause.facts.authorityClass != 3
                || cause.facts.priorStatus != 3 || rotations.pending[p.artistId] != bytes32(0)
                || cause.facts.pendingTransitionHash != bytes32(0)
                || s.latest[p.artistId] != bytes32(0) || p.supersededRecordHashes.length != 0
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        bytes32 predecessor = StreamArtistRecoveryEstatePredecessor.firstEstate(
            s, estate, rotations, resolutions, succession, contests, o.environment, cause, p
        );
        if (identity.activeIdentity[p.newAddress] != bytes32(0)) {
            revert T.AddressAlreadyRegistered(p.newAddress);
        }
        c.causeHash = cause.causeHash;
        c.incumbent = principal.authorityAddress;
        c.postContestSeconds = StreamArtistRotationState.rotationSeconds(rotations);
        bytes32 activation = estate.authorityActivation[p.artistId];
        R.GuardianRecord memory guardian = EstateGuardians.guardian(
            s.guardianHistory,
            rotations,
            o.environment,
            p.artistId,
            s.guardianRecordsSeen[p.artistId],
            s.vestingHistory.snapshots[activation],
            estate.transitions[activation].postWindowEndsAt
        );
        if (guardian.terms.minContestSeconds > c.postContestSeconds) {
            c.postContestSeconds = guardian.terms.minContestSeconds;
        }
        c.standingTailSeconds = StreamArtistRotationState.standingSeconds(rotations);
        c.timingRevision = rotations.timingRevision == 0 ? 1 : rotations.timingRevision;
        c.delegationEpoch = estate.delegationEpoch[p.artistId];
        c.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_SCOPE_V2"),
                o.environment.chainId,
                o.environment.registry,
                address(this),
                p.artistId
            )
        );
        c.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_STATE_V2"),
                c.scopeHash,
                cause,
                principal,
                p.expectedResolutionHash,
                c.postContestSeconds,
                c.standingTailSeconds,
                c.timingRevision,
                c.delegationEpoch
            )
        );
        // Registration changes owner revision, but never these scheduled transition facts.
        if (guardian.recordHash != bytes32(0)) {
            c.oldValueHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDED_RECOVERY_STATE_V1"),
                    c.oldValueHash,
                    guardian,
                    s.guardianRecordsSeen[p.artistId]
                )
            );
        }
        if (guardian.recordHash != bytes32(0)) {
            GH.Head memory history = GuardianHistory.requireComplete(
                s.guardianHistory, p.artistId, s.guardianRecordsSeen[p.artistId]
            );
            c.oldValueHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_CONTEXT_V1"),
                    c.oldValueHash,
                    history
                )
            );
        }
        c.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ESTATE_CONTEXT_V1"),
                c.oldValueHash,
                predecessor
            )
        );
        c.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_INTENT_V2"),
                c.scopeHash,
                c.oldValueHash,
                p,
                acceptance.nonce,
                acceptance.time
            )
        );
    }

    function _guardian(
        RecoveryState.State storage s,
        StreamArtistRotationState.State storage r,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        address incumbent
    ) private view returns (R.GuardianRecord memory g) {
        if (r.latestExecution[artistId] != bytes32(0)) {
            return Predecessor.guardian(
                s.guardianHistory, r, o.environment, artistId, s.guardianRecordsSeen[artistId]
            );
        }
        bytes32 head = r.stableGuardian[artistId];
        uint64 count = s.guardianRecordsSeen[artistId];
        if (head == bytes32(0)) {
            if (count != 0) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            return g;
        }
        GuardianHistory.requireComplete(s.guardianHistory, artistId, count);
        g = r.guardians[head];
        if (
            count == 0 || g.recordHash != head || g.terms.artistId != artistId
                || g.authorityClass != 1 || g.signer != incumbent
                || g.provisional.transitionRecordHash != bytes32(0)
                || g.provisional.windowEndsAt != 0 || g.terms.guardians.length > 8
                || g.terms.minContestSeconds > 30 days
                || StreamArtistRotationHashes.guardianRecord(
                        o.environment, g.terms, T.Authorization(g.nonce, g.signedAt, bytes(""))
                    ) != head
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }
}
