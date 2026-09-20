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

/// @notice Admitted op32 continuations of an original op40 estate.
/// @dev Distinct origin/terminal proof; no historical authorization is replayed or synthesized.
library StreamArtistRecoveryEstateRotation {
    struct Origin {
        Estate.RequestRecord request;
        Estate.ExecutionFacts execution;
        R.TransitionState transition;
        V.Snapshot vesting;
        GH.Head guardians;
        Succ.DesignationRecord designation;
        Succ.DirectiveRecord paired;
        Succ.DirectiveRecord forbidden;
        uint32 capabilities;
    }

    function afterRotation(
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
        return _afterRotation(
            recovery, estate, rotations, resolutions, succession, contests, e, cause, p, bytes32(0)
        );
    }

    /// @dev The fixed caller authenticates the full current cause and executed/staged suffix.
    /// Keep the original estate source, capabilities and guardian prefix independent.
    function afterRotationWithHistory(
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
        return _afterRotation(
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

    function _afterRotation(
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
        Origin memory f;
        f.request = estate.requests[head];
        f.execution = estate.executions[head];
        f.transition = estate.transitions[head];
        f.vesting = recovery.vestingHistory.snapshots[head];
        bytes32 terminal = rotations.latestExecution[p.artistId];
        bool continued = recovery.vestingHistory.snapshots[terminal].previousTransitionRecordHash
                != head
            || rotations.rotations[terminal].terms.expectedPreviousTransitionRecordHash != head;
        if (
            head == 0 || f.request.recordHash != head || f.request.terms.artistId != p.artistId
                || f.request.incumbent == address(0)
                || f.request.incumbent == f.request.terms.successor
                || f.request.terms.successor == address(0) || f.request.terms.evidenceHash == 0
                || f.request.terms.selectedCoverageHash == 0 || f.request.envelopeHash == 0
                || f.request.requestedAt == 0 || f.request.noticeRevision == 0
                || f.request.rotationTimingRevision == 0
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
                || rotations.pending[p.artistId] != 0 || terminal == 0 || terminal == head
                || (!continued && rotations.retirement[p.artistId][f.request.incumbent] != head)
                || cause.facts.executedTransitionHash != terminal
                || (historyProof == 0 && cause.facts.pendingTransitionHash != 0)
                || f.execution.activationRecordHash != head || f.execution.coverageRecordHash == 0
                || f.execution.executedAt < f.request.requestedAt
                || f.execution.delegationEpoch == 0
                || f.execution.delegationEpoch != estate.delegationEpoch[p.artistId]
                || (historyProof == 0 && recovery.latest[p.artistId] != 0)
                || f.transition.recordHash != head || f.transition.artistId != p.artistId
                || f.transition.phase != 2 || f.transition.stagedAt != f.request.requestedAt
                || f.transition.contestEndsAt != f.request.noticeEndsAt
                || f.transition.executedAt != f.execution.executedAt
                || uint256(f.transition.postWindowEndsAt)
                    != uint256(f.execution.executedAt) + f.request.postContestSeconds
                || block.timestamp < cause.facts.enteredAt
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        if (historyProof != 0) {
            bytes32 previousRecovery = recovery.latest[p.artistId];
            if (
                previousRecovery != 0
                    && (recovery.records[previousRecovery].fields.vestedAuthorityClass != 1
                        || recovery.records[previousRecovery].delegationEpoch
                            >= f.execution.delegationEpoch)
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
        if (
            recovery.vestingHistory.latest[p.artistId] != terminal
                || f.vesting.artistId != p.artistId || f.vesting.transitionRecordHash != head
                || f.vesting.operationId != 40 || f.vesting.authorityClass != 3
                || f.vesting.oldAddress != f.request.incumbent
                || f.vesting.newAddress != f.request.terms.successor
                || f.vesting.executedAt != f.execution.executedAt || f.vesting.ownerRevision == 0
                || f.vesting.ownerRevision <= f.vesting.guardians.ownerRevision
                || f.vesting.commitment == 0 || f.vesting.commitment != _vestingHash(e, f.vesting)
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
        Contest.Record memory contest = contests.records[cause.facts.referenceHash];
        if (historyProof == 0) _contest(e, cause, p, contest, terminal);
        // Only op32 preserves this original epoch. Every authority producer appends its actual
        // preceding vesting head atomically; no supplied prefix can omit an intervening 35/40/43.
        // The original closure belongs to the original successor, independently of today's head.
        bytes32 originProof;
        bytes32 closureProof;
        bytes32 terminalProof;
        if (historyProof == 0) {
            originProof = RotationOrigin.proof(
                rotations,
                resolutions,
                contests,
                e,
                f.transition,
                f.request.terms.successor,
                rotations.rotations[terminal].transition.stagedAt
            );
            closureProof = EstateClosed.proof(
                rotations, resolutions, contests, e, cause, rotations.rotations[terminal].transition
            );
            terminalProof = continued
                ? RotationHistory.terminal(
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
                )
                : _terminal(recovery, rotations, e, cause, f, terminal, closureProof, originProof);
        }
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
                || !_planAssociation(rotations, p.artistId, f.designation.provisional, hasAncestry)
                || StreamArtistSuccessionHashes.designationRecord(
                        e,
                        f.designation.terms,
                        T.Authorization(f.designation.nonce, f.designation.signedAt, bytes(""))
                    ) != f.designation.recordHash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        f.paired = succession.directives[f.request.pairedDirectiveRecordHash];
        f.forbidden = succession.directives[f.request.forbiddenDirectiveRecordHash];
        _directive(
            rotations, e, f.request, f.paired, f.request.pairedDirectiveRecordHash, hasAncestry
        );
        _directive(
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
                keccak256("6529STREAM_ARTIST_RECOVERY_ROTATED_ESTATE_FACTS_V1"),
                e.chainId,
                e.registry,
                address(this),
                f,
                ancestry,
                terminalProof,
                contest
            )
        );
        if (closureProof != 0 || continued) {
            factsHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_CLOSED_ROTATED_ESTATE_FACTS_V1"),
                    factsHash,
                    closureProof,
                    continued
                )
            );
        }
        if (originProof != 0) {
            factsHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_CLOSED_ORIGIN_ROTATED_ESTATE_FACTS_V1"),
                    factsHash,
                    originProof
                )
            );
        }
        if (historyProof == 0) return factsHash;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_ROTATED_ESTATE_WITH_HISTORY_FACTS_V1"),
                factsHash,
                cause,
                historyProof
            )
        );
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
    ) private view returns (bytes32) {
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
                        e, r.terms, r.oldNonce, t.stagedAt, t.contestEndsAt
                    ) != head || v.artistId != artistId || v.transitionRecordHash != head
                || v.operationId != 32 || v.authorityClass != 3
                || v.oldAddress != r.terms.oldAddress || v.newAddress != r.terms.newAddress
                || v.executedAt != t.executedAt || v.ownerRevision <= origin.vesting.ownerRevision
                || v.ownerRevision <= v.guardians.ownerRevision
                || v.guardians.count < origin.vesting.guardians.count
                || v.previousTransitionRecordHash != origin.request.recordHash
                || v.previousCommitment != origin.vesting.commitment || v.commitment == 0
                || v.commitment != _vestingHash(e, v)
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
                            e, g.terms, T.Authorization(g.nonce, g.signedAt, bytes(""))
                        ) != last
            ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        return keccak256(abi.encode(r, v, retired));
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
        StreamArtistRotationState.State storage rotations,
        StreamArtistHashes.Environment memory e,
        Estate.RequestRecord memory request,
        Succ.DirectiveRecord memory d,
        bytes32 hash,
        bool hasAncestry
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
                || d.authorityClass != 1 || d.signer == address(0)
                || (!hasAncestry && d.signer != request.incumbent)
                || d.signedAt > request.requestedAt
                || !_planAssociation(rotations, request.terms.artistId, d.provisional, hasAncestry)
                || StreamArtistSuccessionHashes.directiveRecord(
                        e, d.terms, T.Authorization(d.nonce, d.signedAt, bytes(""))
                    ) != hash
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(request.terms.artistId);
    }

    function _planAssociation(
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId,
        R.ProvisionalAssociation memory a,
        bool hasAncestry
    ) private view returns (bool) {
        if (!hasAncestry) {
            return a.transitionRecordHash == 0 && a.windowEndsAt == 0;
        }
        return StreamArtistRotationState.eligible(rotations, artistId, a);
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
