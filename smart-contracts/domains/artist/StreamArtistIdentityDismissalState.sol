// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistIdentityResolutionState.sol";
import "./StreamArtistIdentityRevisionState.sol";
import "./StreamArtistSuccessionState.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";

/// @notice Linked adjudication mechanics over the sole Identity owner's storage.
library StreamArtistIdentityDismissalState {
    event ArtistIdentityContestCauseCaptured(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed causeHash,
        uint8 kind,
        bytes32 referenceHash,
        address actor,
        bytes32 reasonHash,
        bytes32 evidenceHash,
        uint64 enteredAt,
        address incumbent,
        uint8 authorityClass,
        uint8 priorStatus,
        bytes32 pendingTransitionHash,
        bytes32 executedTransitionHash,
        bytes32 previousCauseHash,
        bytes32 previousResolutionHash,
        bytes32 actorRetirementHash
    );
    event ArtistIdentityContestDismissed(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed causeHash,
        bytes32 indexed dismissalRecordHash,
        bytes32 previousDismissalRecordHash,
        address executor,
        address proposer,
        uint8 actionClass,
        bytes32 actionId,
        address incumbent,
        uint8 authorityClass,
        uint8 restoredStatus,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        bool removePriorStanding,
        bytes32 retiredTransitionRecordHash,
        uint64 dismissedAt,
        bytes32 cohortHash,
        bytes32 governanceWitnessHash,
        bytes32 revisionContinuationHead
    );

    function causeFacts(
        StreamArtistIdentityResolutionState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId,
        uint8 kind,
        bytes32 referenceHash,
        address actor,
        bytes32 reasonHash,
        bytes32 evidenceHash
    ) public view returns (Dismissal.CauseFacts memory f) {
        T.Identity storage principal = identity.identities[artistId];
        f = Dismissal.CauseFacts(
            artistId,
            kind,
            referenceHash,
            actor,
            reasonHash,
            evidenceHash,
            uint64(block.timestamp),
            principal.authorityAddress,
            principal.authorityClass,
            principal.status,
            StreamArtistRotationState.pendingTransition(rotations, artistId),
            rotations.latestExecution[artistId],
            s.currentCause[artistId],
            s.latestResolution[artistId],
            rotations.retirement[artistId][actor]
        );
    }

    function capture(
        StreamArtistIdentityResolutionState.State storage s,
        StreamArtistHashes.Environment memory e,
        Dismissal.CauseFacts memory f
    ) public returns (bytes32 hash) {
        if (
            f.referenceHash == bytes32(0)
                || !((f.priorStatus == 1 && f.authorityClass == 1)
                    || (f.priorStatus == 3 && f.authorityClass == 3)) || f.incumbent == address(0)
                || (f.kind != 1 && f.kind != 2) || f.actor == address(0) || block.timestamp == 0
                || block.timestamp > type(uint64).max || f.enteredAt != block.timestamp
                || f.previousCauseHash != s.currentCause[f.artistId]
                || f.previousResolutionHash != s.latestResolution[f.artistId]
        ) {
            revert Dismissal.InvalidContestCause(f.referenceHash);
        }
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                e.chainId,
                e.registry,
                address(this),
                f
            )
        );
        if (s.causes[hash].causeHash != bytes32(0)) revert Dismissal.InvalidContestCause(hash);
        s.causes[hash] = Dismissal.Cause(hash, f);
        s.currentCause[f.artistId] = hash;
        emit ArtistIdentityContestCauseCaptured(
            1,
            f.artistId,
            hash,
            f.kind,
            f.referenceHash,
            f.actor,
            f.reasonHash,
            f.evidenceHash,
            f.enteredAt,
            f.incumbent,
            f.authorityClass,
            f.priorStatus,
            f.pendingTransitionHash,
            f.executedTransitionHash,
            f.previousCauseHash,
            f.previousResolutionHash,
            f.actorRetirementHash
        );
    }

    function snapshot(
        StreamArtistIdentityResolutionState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistSuccessionState.State storage succession,
        Dismissal.Cause memory cause
    ) public view returns (Dismissal.CohortSnapshot memory v) {
        bytes32 id = cause.facts.artistId;
        v.pendingTransition =
            StreamArtistRotationState.transitionState(rotations, cause.facts.pendingTransitionHash);
        v.executedTransition = StreamArtistRotationState.transitionState(
            rotations, cause.facts.executedTransitionHash
        );
        v.stableRevisionRecord = revisions.latestRecord[id];
        v.pendingRevisionRecord = revisions.pendingRecord[id];
        v.operativeRevisionRecord = v.pendingRevisionRecord != bytes32(0)
            && StreamArtistRotationState.eligible(
                rotations, id, revisions.associations[v.pendingRevisionRecord]
            )
            ? v.pendingRevisionRecord
            : v.stableRevisionRecord;
        v.operativeDocumentHash =
            StreamArtistIdentityRevisionState.operative(revisions, identity, rotations, id);
        v.stableGuardianRecord = rotations.stableGuardian[id];
        v.candidateGuardianRecord = rotations.provisionalGuardian[id];
        v.operativeGuardianRecord = StreamArtistRotationState.operativeGuardian(rotations, id);
        v.stableDesignationRecord = succession.stableDesignation[id];
        v.candidateDesignationRecord = succession.candidateDesignation[id];
        v.operativeDesignationRecord =
            StreamArtistSuccessionState.operativeDesignation(succession, rotations, id);
        v.stableDirectiveRecord = succession.stableDirective[id];
        v.candidateDirectiveRecord = succession.candidateDirective[id];
        v.operativeDirectiveRecord =
            StreamArtistSuccessionState.operativeDirective(succession, rotations, id);
        v.revisionContinuationHead = s.continuationHead[id];
        v.pendingClosure = s.closures[cause.facts.pendingTransitionHash];
        v.executedClosure = s.closures[cause.facts.executedTransitionHash];
    }

    function context(
        StreamArtistIdentityResolutionState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistHashes.Environment memory e,
        Dismissal.Request memory p
    ) public view returns (Dismissal.Context memory x) {
        Dismissal.Cause memory cause = s.causes[s.currentCause[p.artistId]];
        T.Identity storage principal = identity.identities[p.artistId];
        if (
            p.artistId == bytes32(0) || cause.causeHash == bytes32(0)
                || p.expectedCauseHash != cause.causeHash || cause.facts.artistId != p.artistId
                || (cause.facts.kind != 1 && cause.facts.kind != 2)
                || cause.facts.referenceHash == bytes32(0) || cause.facts.actor == address(0)
                || principal.status != 4 || principal.authorityAddress != cause.facts.incumbent
                || principal.authorityClass != cause.facts.authorityClass
                || !((cause.facts.priorStatus == 1 && cause.facts.authorityClass == 1)
                    || (cause.facts.priorStatus == 3 && cause.facts.authorityClass == 3))
                || p.expectedResolutionHash != s.latestResolution[p.artistId]
                || cause.facts.previousResolutionHash != p.expectedResolutionHash
                || p.evidenceHash == bytes32(0) || p.reasonHash == bytes32(0)
                || (cause.facts.pendingTransitionHash != bytes32(0)
                    && cause.facts.pendingTransitionHash == cause.facts.executedTransitionHash)
        ) {
            revert Dismissal.InvalidDismissal(p.artistId);
        }
        if (p.removePriorStanding) {
            (bool revoked,) = standingRevoked(s, rotations, p.artistId, cause.facts.actor);
            if (
                p.expectedRetirementHash == bytes32(0)
                    || p.expectedRetirementHash != cause.facts.actorRetirementHash
                    || p.expectedRetirementHash
                        != rotations.retirement[p.artistId][cause.facts.actor] || revoked
            ) revert Dismissal.InvalidDismissal(p.artistId);
        } else if (p.expectedRetirementHash != bytes32(0)) {
            revert Dismissal.InvalidDismissal(p.artistId);
        }
        Dismissal.CohortSnapshot memory v =
            snapshot(s, identity, rotations, revisions, succession, cause);
        _validateTransition(p.artistId, cause.facts.pendingTransitionHash, v.pendingTransition);
        _validateTransition(p.artistId, cause.facts.executedTransitionHash, v.executedTransition);
        x.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_SCOPE_V1"),
                e.chainId,
                e.registry,
                address(this),
                p.artistId
            )
        );
        x.causeHash = cause.causeHash;
        x.cohortHash = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_COHORT_V1"), p.artistId, v)
        );
        x.revisionContinuationHead = v.revisionContinuationHead;
        x.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_STATE_V1"),
                x.scopeHash,
                cause,
                principal.authorityAddress,
                principal.authorityClass,
                principal.status,
                s.latestResolution[p.artistId],
                x.cohortHash
            )
        );
        x.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_INTENT_V1"),
                x.scopeHash,
                x.oldValueHash,
                p
            )
        );
    }

    function dismiss(
        StreamArtistIdentityResolutionState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityRevisionState.State storage revisions,
        StreamArtistSuccessionState.State storage succession,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Dismissal.Request memory p,
        Contest.GovernanceWitness memory g,
        address executor
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        Dismissal.Context memory x = context(
            s, identity, rotations, revisions, succession, o.environment, p
        );
        if (
            c.actor != executor || g.actionId == bytes32(0) || g.proposer == address(0)
                || (g.actionClass != 1 && g.actionClass != 2) || g.roleRevision == 0
                || g.roleMutationHash == bytes32(0) || g.scopeHash != x.scopeHash
                || g.oldValueHash != x.oldValueHash || g.newValueHash != x.newValueHash
                || block.timestamp == 0 || block.timestamp > type(uint64).max
        ) {
            revert Dismissal.InvalidDismissalGovernance();
        }
        Dismissal.Cause memory cause = s.causes[x.causeHash];
        Dismissal.CohortSnapshot memory v =
            snapshot(s, identity, rotations, revisions, succession, cause);
        Dismissal.Record memory item;
        item.terms = p;
        item.executor = executor;
        item.proposer = g.proposer;
        item.actionClass = g.actionClass;
        item.actionId = g.actionId;
        item.incumbent = cause.facts.incumbent;
        item.authorityClass = cause.facts.authorityClass;
        item.restoredStatus = cause.facts.priorStatus;
        item.dismissedAt = uint64(block.timestamp);
        item.cohortHash = x.cohortHash;
        item.governanceWitnessHash = keccak256(abi.encode(g));
        item.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_RECORD_V1"),
                o.environment.chainId,
                o.environment.registry,
                address(this),
                p,
                executor,
                g.proposer,
                g.actionClass,
                g.actionId,
                item.incumbent,
                item.authorityClass,
                item.restoredStatus,
                item.dismissedAt,
                item.cohortHash,
                item.governanceWitnessHash
            )
        );
        if (s.records[item.recordHash].recordHash != bytes32(0)) {
            revert Dismissal.InvalidDismissal(p.artistId);
        }
        bytes32 causeKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.contest_resolution"),
            keccak256(abi.encode(p.artistId, x.causeHash)),
            item.recordHash
        );
        bytes32 actionKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.dismissal_action"),
            keccak256(abi.encode(g.actionId, x.scopeHash, x.oldValueHash, x.newValueHash)),
            item.recordHash
        );
        _close(s, p.artistId, v.pendingTransition, item.recordHash);
        _close(s, p.artistId, v.executedTransition, item.recordHash);
        _clearable(
            s,
            rotations,
            p.artistId,
            rotations.guardians[v.candidateGuardianRecord].provisional,
            item.recordHash
        );
        _clearable(
            s,
            rotations,
            p.artistId,
            succession.designations[v.candidateDesignationRecord].provisional,
            item.recordHash
        );
        _clearable(
            s,
            rotations,
            p.artistId,
            succession.directives[v.candidateDirectiveRecord].provisional,
            item.recordHash
        );
        // Checkpoint already-mature heads. In-window contested children are not selected.
        rotations.stableGuardian[p.artistId] = v.operativeGuardianRecord;
        succession.stableDesignation[p.artistId] = v.operativeDesignationRecord;
        succession.stableDirective[p.artistId] = v.operativeDirectiveRecord;
        revisions.latestRecord[p.artistId] = v.operativeRevisionRecord;
        delete rotations.provisionalGuardian[p.artistId];
        delete succession.candidateDesignation[p.artistId];
        delete succession.candidateDirective[p.artistId];
        item.revisionContinuationHead = s.continuationHead[p.artistId];
        if (
            v.pendingRevisionRecord != bytes32(0)
                && v.pendingRevisionRecord != v.operativeRevisionRecord
        ) {
            R.ProvisionalAssociation memory a = revisions.associations[v.pendingRevisionRecord];
            Dismissal.Closure memory closure_ = s.closures[a.transitionRecordHash];
            if (
                !closure_.abandoned || closure_.artistId != p.artistId
                    || closure_.dismissalRecordHash != item.recordHash
                    || closure_.windowEndsAt != a.windowEndsAt
            ) {
                revert Dismissal.InvalidClosure(a.transitionRecordHash);
            }
            Dismissal.RevisionContinuation memory next;
            next.artistId = p.artistId;
            next.dismissalRecordHash = item.recordHash;
            next.previousContinuationHash = item.revisionContinuationHead;
            next.stableRevisionRecordHash = v.operativeRevisionRecord;
            next.stableDocumentHash = v.operativeDocumentHash;
            next.abandonedRevisionRecordHash = v.pendingRevisionRecord;
            next.continuationHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_IDENTITY_REVISION_CONTINUATION_V1"),
                    o.environment.chainId,
                    o.environment.registry,
                    address(this),
                    p.artistId,
                    item.recordHash,
                    next.previousContinuationHash,
                    next.stableRevisionRecordHash,
                    next.stableDocumentHash,
                    next.abandonedRevisionRecordHash
                )
            );
            s.continuations[next.continuationHash] = next;
            s.continuationHead[p.artistId] = next.continuationHash;
            item.revisionContinuationHead = next.continuationHash;
            delete revisions.pendingRecord[p.artistId];
        }
        if (v.pendingRevisionRecord == v.operativeRevisionRecord) {
            delete revisions.pendingRecord[p.artistId];
        }
        if (p.removePriorStanding) {
            s.standingJudgments[p.artistId][cause.facts.actor] =
                Dismissal.StandingJudgment(p.expectedRetirementHash, item.recordHash);
        }
        identity.identities[p.artistId].status = item.restoredStatus;
        s.records[item.recordHash] = item;
        s.latestResolution[p.artistId] = item.recordHash;
        m.record = item.recordHash;
        m.action = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_REGISTRY_WRITE_DISMISS_ARTIST_IDENTITY_CONTEST_V1"),
                p,
                g,
                x
            )
        );
        m.state = keccak256(
            abi.encode(
                item,
                cause,
                identity.identities[p.artistId],
                s.closures[cause.facts.pendingTransitionHash],
                s.closures[cause.facts.executedTransitionHash],
                s.continuations[item.revisionContinuationHead],
                s.standingJudgments[p.artistId][cause.facts.actor]
            )
        );
        m.state = keccak256(
            abi.encode(
                m.state,
                v,
                revisions.latestRecord[p.artistId],
                revisions.pendingRecord[p.artistId],
                rotations.stableGuardian[p.artistId],
                rotations.provisionalGuardian[p.artistId],
                succession.stableDesignation[p.artistId],
                succession.candidateDesignation[p.artistId],
                succession.stableDirective[p.artistId],
                succession.candidateDirective[p.artistId]
            )
        );
        m.replay = keccak256(abi.encode(causeKey, actionKey, item.recordHash));
        emit ArtistIdentityContestDismissed(
            1,
            p.artistId,
            x.causeHash,
            item.recordHash,
            p.expectedResolutionHash,
            executor,
            g.proposer,
            g.actionClass,
            g.actionId,
            item.incumbent,
            item.authorityClass,
            item.restoredStatus,
            p.evidenceHash,
            p.reasonHash,
            p.removePriorStanding,
            p.expectedRetirementHash,
            item.dismissedAt,
            item.cohortHash,
            item.governanceWitnessHash,
            item.revisionContinuationHead
        );
    }

    function standingRevoked(
        StreamArtistIdentityResolutionState.State storage s,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId,
        address actor
    ) public view returns (bool revoked, bytes32 record) {
        (revoked, record) = StreamArtistRotationState.standingRevoked(rotations, artistId, actor);
        if (revoked) return (revoked, record);
        Dismissal.StandingJudgment memory judgment = s.standingJudgments[artistId][actor];
        if (
            judgment.dismissalRecordHash != bytes32(0)
                && judgment.retirementHash == rotations.retirement[artistId][actor]
        ) {
            return (true, judgment.dismissalRecordHash);
        }
    }

    function _validateTransition(
        bytes32 artistId,
        bytes32 referenceHash,
        R.TransitionState memory t
    ) private pure {
        if (referenceHash == bytes32(0)) {
            R.TransitionState memory empty;
            if (keccak256(abi.encode(t)) != keccak256(abi.encode(empty))) {
                revert Dismissal.InvalidClosure(referenceHash);
            }
        } else if (
            t.recordHash != referenceHash || t.artistId != artistId
                || (t.phase != 2 && t.phase != 3)
        ) {
            revert Dismissal.InvalidClosure(referenceHash);
        }
    }

    function _clearable(
        StreamArtistIdentityResolutionState.State storage s,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId,
        R.ProvisionalAssociation memory association_,
        bytes32 currentDismissal
    ) private view {
        if (StreamArtistRotationState.eligible(rotations, artistId, association_)) return;
        Dismissal.Closure memory closure_ = s.closures[association_.transitionRecordHash];
        if (
            !closure_.abandoned || closure_.artistId != artistId
                || closure_.windowEndsAt != association_.windowEndsAt
                || closure_.dismissalRecordHash != currentDismissal
        ) revert Dismissal.InvalidClosure(association_.transitionRecordHash);
    }

    function _close(
        StreamArtistIdentityResolutionState.State storage s,
        bytes32 artistId,
        R.TransitionState memory t,
        bytes32 record
    ) private {
        if (t.recordHash == bytes32(0)) return;
        Dismissal.Closure memory old = s.closures[t.recordHash];
        bool abandoned = t.phase == 3
            || (t.phase == 2 && t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt);
        uint64 ends = t.phase == 2 ? t.postWindowEndsAt : t.contestEndsAt;
        if (
            ends == 0 || (t.phase == 2 && t.executedAt == 0)
                || (!abandoned && block.timestamp < ends)
        ) {
            revert Dismissal.InvalidClosure(t.recordHash);
        }
        if (old.dismissalRecordHash != bytes32(0)) {
            if (
                old.artistId != artistId || old.transitionRecordHash != t.recordHash
                    || old.windowEndsAt != ends || old.contestedAt != t.contestedAt
                    || old.abandoned != abandoned
            ) {
                revert Dismissal.InvalidClosure(t.recordHash);
            }
            return;
        }
        s.closures[t.recordHash] =
            Dismissal.Closure(artistId, t.recordHash, record, ends, t.contestedAt, abandoned);
    }

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 surface,
        bytes32 scope,
        bytes32 record
    ) private returns (bytes32 key) {
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                surface,
                scope
            )
        );
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(record, o.revision + 1, 1, 2);
    }
}
