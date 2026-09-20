// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryState as State
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistEstateState as EstateState } from "./StreamArtistEstateState.sol";
import { StreamArtistGuardianHistory as History } from "./StreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianSupersession as Supersession
} from "./StreamArtistGuardianSupersession.sol";
import {
    StreamArtistGuardianSupersessionCutoff as Cutoff
} from "./StreamArtistGuardianSupersessionCutoff.sol";
import {
    StreamArtistIdentityRecoveryHashes as Hashes
} from "./StreamArtistIdentityRecoveryHashes.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveryClosedContinuation as Closed
} from "./StreamArtistRecoveryClosedContinuation.sol";
import {
    StreamArtistLivingRecoveryHistory as LivingHistory
} from "./StreamArtistLivingRecoveryHistory.sol";
import {
    StreamArtistRecoveryRotationContinuation as Rotated
} from "./StreamArtistRecoveryRotationContinuation.sol";
import {
    StreamArtistRecoveryDormancyOrigin as DormancyOrigin
} from "./StreamArtistRecoveryDormancyOrigin.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistEstateTypes as E
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";

/// @notice Fresh compromise and independently registered recovery of an already recovered principal.
/// @dev Consumes immutable admitted operation35 evidence; never reauthorizes historical governance.
library StreamArtistRecoveryContinuation {
    function context(
        State.State storage s,
        Identity.State storage identity,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        EstateState.State storage estate,
        Identity.OwnerContext memory o,
        I.Request memory p,
        T.Authorization memory acceptance
    ) public view returns (I.Context memory c) {
        D.Cause memory cause = resolutions.causes[resolutions.currentCause[p.artistId]];
        T.Identity memory principal = identity.identities[p.artistId];
        bytes32 previous = s.latest[p.artistId];
        bytes32 executed = rotations.latestExecution[p.artistId];
        bool rotated = executed != previous;
        I.Record memory prior = s.records[previous];
        R.TransitionState memory transition = s.transitions[previous];
        if (
            p.artistId == 0 || previous == 0 || prior.recordHash != previous
                || p.expectedCauseHash != cause.causeHash || cause.causeHash == 0
                || cause.facts.artistId != p.artistId || cause.facts.kind != 1
                || cause.facts.executedTransitionHash != executed
                || (cause.facts.pendingTransitionHash != 0 && cause.facts.authorityClass != 1)
                || cause.facts.incumbent != principal.authorityAddress
                || cause.facts.actor == address(0) || principal.status != 4
                || principal.authorityClass != cause.facts.authorityClass
                || (!rotated && prior.fields.newAddress != principal.authorityAddress)
                || identity.activeIdentity[principal.authorityAddress] != p.artistId
                || p.vestedAuthorityClass != principal.authorityClass
                || !((p.vestedAuthorityClass == 1 && cause.facts.priorStatus == 1)
                    || (p.vestedAuthorityClass == 3 && cause.facts.priorStatus == 3))
                || p.newAddress == address(0) || p.newAddress == principal.authorityAddress
                || p.evidenceHash == 0 || p.reasonHash == 0
                || resolutions.latestResolution[p.artistId] != p.expectedResolutionHash
                || cause.facts.previousResolutionHash != p.expectedResolutionHash
        ) {
            revert I.InvalidIdentityRecovery(p.artistId);
        }
        if (
            rotations.pending[p.artistId] != 0 || estate.pending[p.artistId] != 0
                || transition.artistId != p.artistId || transition.recordHash != previous
                || transition.phase != 2 || transition.executedAt != prior.fields.recoveredAt
                || transition.stagedAt != transition.executedAt
                || transition.contestEndsAt != transition.executedAt
                || uint256(transition.postWindowEndsAt)
                    != uint256(transition.executedAt) + prior.postContestSeconds
                || block.timestamp < cause.facts.enteredAt
                || prior.delegationEpoch != estate.delegationEpoch[p.artistId]
                || prior.terms.expectedCauseHash == 0
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        bytes32 rotationProof;
        bytes32 closureProof;
        bytes32 livingHistory;
        if (principal.authorityClass == 1) {
            LivingHistory.Facts memory history =
                LivingHistory.read(s, rotations, resolutions, o.environment, prior, cause);
            if (!history.legacyCompatible) livingHistory = history.proof;
        }
        if (livingHistory == 0) {
            // Retain the original readers and exact wrappers for their supported shapes.
            if (rotated) {
                rotationProof = Rotated.proof(
                    s, rotations, resolutions, estate, o.environment, prior, transition, cause
                );
            } else {
                if (rotations.latestTransition[p.artistId] != previous) {
                    revert I.UnsupportedIdentityRecoveryProfile(p.artistId);
                }
                closureProof = Closed.proof(resolutions, o.environment, prior, transition, cause);
            }
        }
        if (identity.activeIdentity[p.newAddress] != 0) {
            revert T.AddressAlreadyRegistered(p.newAddress);
        }
        GH.Head memory head = History.requireComplete(
            s.guardianHistory, p.artistId, s.guardianRecordsSeen[p.artistId]
        );
        V.Snapshot memory cutoff =
            Cutoff.current(s.vestingHistory, s.guardianHistory, rotations, p.artistId, head);
        if (
            cutoff.operationId != (rotated ? 32 : 35)
                || cutoff.newAddress != principal.authorityAddress
                || cutoff.authorityClass != principal.authorityClass
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        bytes32 predecessor = _prior(
            s,
            rotations,
            o.environment,
            prior,
            rotated ? s.vestingHistory.snapshots[previous] : cutoff,
            !rotated && livingHistory == 0
        );
        C.Record memory contest = IStreamArtistIdentityContestOwner(address(this))
            .identityContestRecord(cause.facts.referenceHash);
        if (
            contest.recordHash == 0 || contest.recordHash != cause.facts.referenceHash
                || contest.terms.artistId != p.artistId
                || (livingHistory == 0 && contest.terms.subjectRecordHash != executed)
                || contest.terms.evidenceHash != cause.facts.evidenceHash
                || contest.terms.reasonHash != cause.facts.reasonHash
                || contest.contester != cause.facts.actor
                || contest.priorStatus != cause.facts.priorStatus
                || contest.contestedAt != cause.facts.enteredAt
                || contest.pendingTransitionRecordHash != cause.facts.pendingTransitionHash
                || contest.executedTransitionRecordHash != executed
                || contest.recordHash
                    != keccak256(
                        abi.encode(
                            bytes32(
                                0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb
                            ),
                            o.environment.chainId,
                            o.environment.registry,
                            p.artistId,
                            contest.contester,
                            contest.terms.subjectRecordHash,
                            contest.terms.evidenceHash,
                            contest.terms.reasonHash,
                            contest.contestedAt
                        )
                    )
                || cause.causeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                            o.environment.chainId,
                            o.environment.registry,
                            address(this),
                            cause.facts
                        )
                    )
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        E.AuthorityCapabilities memory capabilities =
            IStreamArtistEstateOwner(address(this)).currentAuthorityCapabilities(p.artistId);
        if (
            capabilities.authorityAddress != principal.authorityAddress
                || capabilities.authorityClass != principal.authorityClass
                || capabilities.status != 4
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        bytes32 dormancyOrigin;
        if (principal.authorityClass == 3) {
            if (estate.authorityActivation[p.artistId] == 0) {
                dormancyOrigin = DormancyOrigin.requireOrigin(s, o.environment, prior, capabilities);
            } else if (
                capabilities.activationRecordHash == 0
                    || capabilities.activationRecordHash != estate.authorityActivation[p.artistId]
                    || estate.phases[capabilities.activationRecordHash] != 2
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(p.artistId);
            }
        }
        R.GuardianRecord memory g =
            guardian(s, rotations, o.environment, p.artistId, principal.authorityClass);
        c.causeHash = cause.causeHash;
        c.incumbent = principal.authorityAddress;
        c.postContestSeconds = Rotations.rotationSeconds(rotations);
        bytes32 supersession;
        if (p.supersededRecordHashes.length != 0) {
            (supersession, c.postContestSeconds) = Supersession.contextAndWindow(
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
        } else if (g.terms.minContestSeconds > c.postContestSeconds) {
            c.postContestSeconds = g.terms.minContestSeconds;
        }
        c.standingTailSeconds = Rotations.standingSeconds(rotations);
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
                keccak256("6529STREAM_ARTIST_REPEAT_RECOVERY_STATE_V1"),
                c.scopeHash,
                cause,
                contest,
                principal,
                predecessor,
                transition,
                head,
                g,
                capabilities,
                p.expectedResolutionHash,
                c.postContestSeconds,
                c.standingTailSeconds,
                c.timingRevision,
                c.delegationEpoch,
                supersession
            )
        );
        if (closureProof != 0) {
            c.oldValueHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_CLOSED_REPEAT_RECOVERY_STATE_V1"),
                    c.oldValueHash,
                    closureProof
                )
            );
        }
        if (livingHistory != 0) {
            c.oldValueHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RESOLVED_LIVING_REPEAT_RECOVERY_STATE_V1"),
                    c.oldValueHash,
                    livingHistory
                )
            );
        }
        if (rotationProof != 0) {
            c.oldValueHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_ROTATED_REPEAT_RECOVERY_STATE_V1"),
                    c.oldValueHash,
                    rotationProof
                )
            );
        }
        if (dormancyOrigin != 0) {
            c.oldValueHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_DORMANCY_REPEAT_RECOVERY_STATE_V1"),
                    c.oldValueHash,
                    dormancyOrigin
                )
            );
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

    function _prior(
        State.State storage s,
        Rotations.State storage rotations,
        StreamArtistHashes.Environment memory e,
        I.Record memory r,
        V.Snapshot memory v,
        bool currentRetirement
    ) private view returns (bytes32) {
        if (
            Hashes.record(e.chainId, e.registry, r.fields) != r.recordHash
                || r.fields.artistId != v.artistId || r.fields.oldAddress != v.oldAddress
                || r.fields.newAddress != v.newAddress
                || r.fields.vestedAuthorityClass != v.authorityClass
                || r.fields.recoveredAt != v.executedAt || r.fields.governanceActionId == 0
                || r.fields.evidenceHash == 0 || r.fields.reasonHash == 0
                || r.terms.artistId != r.fields.artistId
                || r.terms.newAddress != r.fields.newAddress
                || r.terms.vestedAuthorityClass != r.fields.vestedAuthorityClass
                || r.terms.evidenceHash != r.fields.evidenceHash
                || r.terms.reasonHash != r.fields.reasonHash
                || Hashes.supersession(r.terms.supersededRecordHashes)
                    != r.fields.supersededRecordsHash || r.executor == address(0)
                || r.proposer == address(0) || r.governanceWitnessHash == 0 || r.contextHash == 0
                || r.acceptanceDigest == 0 || r.acceptanceDeadline < r.fields.recoveredAt
                || r.postContestSeconds < 72 hours || r.standingTailSeconds < 30 days
                || r.timingRevision == 0 || r.delegationEpoch == 0
                || (currentRetirement
                    && rotations.retirement[v.artistId][v.oldAddress] != r.recordHash)
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        bytes32 action = r.fields.governanceActionId;
        A.Association memory association = s.actions[action];
        if (association.associationHash != 0) {
            GH.Snapshot memory history = s.guardianHistory.snapshots[action];
            if (
                s.actionExecutions[action] != r.recordHash || association.artistId != v.artistId
                    || association.requestHash != keccak256(abi.encode(r.terms))
                    || association.contextHash != r.contextHash
                    || association.action.actionId != action
                    || association.action.proposer != r.proposer
                    || association.ownerRevision >= v.ownerRevision
                    || association.preparedAt > r.fields.recoveredAt
                    || history.artistId != v.artistId
                    || history.associationHash != association.associationHash
                    || history.count != v.guardians.count
                    || history.historyCommitment != v.guardians.commitment
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
        } else if (
            s.actionExecutions[action] != 0 || s.recoveryGuardians[r.recordHash] != 0
                || v.guardians.count != 0
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(address(this)).identityRecoveryReceipts(r.recordHash);
        if (primary == 0 || occurrence == 0 || secondary == 0 || primary == secondary) {
            revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ADMITTED_PRIOR_RECOVERY_V1"),
                r,
                v,
                association,
                s.recoveryGuardians[r.recordHash],
                primary,
                occurrence,
                secondary
            )
        );
    }

    function guardian(
        State.State storage s,
        Rotations.State storage rotations,
        StreamArtistHashes.Environment memory e,
        bytes32 artistId,
        uint8 authorityClass
    ) public view returns (R.GuardianRecord memory g) {
        Supersession.requireHeads(s.guardianSupersession, rotations, artistId);
        GH.Head memory head =
            History.requireComplete(s.guardianHistory, artistId, s.guardianRecordsSeen[artistId]);
        bytes32 selected = Rotations.operativeGuardian(rotations, artistId);
        if (selected == 0) {
            if (
                head.count != 0 || rotations.stableGuardian[artistId] != 0
                    || rotations.provisionalGuardian[artistId] != 0
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(artistId);
            }
            return g;
        }
        g = rotations.guardians[selected];
        GH.Entry memory entry = s.guardianHistory.entries[selected];
        if (
            g.recordHash != selected || g.terms.artistId != artistId || g.signer == address(0)
                || !((g.authorityClass == 1) || (authorityClass == 3 && g.authorityClass == 3))
                || g.terms.guardians.length > 8 || g.terms.minContestSeconds > 30 days
                || !Rotations.eligible(rotations, artistId, g.provisional)
                || entry.artistId != artistId || entry.recordHash != selected || entry.index == 0
                || entry.index > head.count || entry.ownerRevision == 0
                || entry.ownerRevision > head.ownerRevision || entry.commitment == 0
                || entry.recordDataHash != keccak256(abi.encode(g))
                || s.guardianHistory.records[artistId][entry.index] != selected
                || s.guardianSupersession.statuses[selected].recoveryRecordHash != 0
                || StreamArtistRotationHashes.guardianRecord(
                        e, g.terms, T.Authorization(g.nonce, g.signedAt, "")
                    ) != selected
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }
}
