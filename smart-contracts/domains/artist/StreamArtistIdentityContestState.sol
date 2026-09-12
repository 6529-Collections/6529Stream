// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRotationState.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";

/// @notice Linked compromise mechanics over the sole Identity owner's append-only state.
library StreamArtistIdentityContestState {
    struct State {
        mapping(bytes32 => Contest.Record) records;
        mapping(bytes32 => bytes32) latest;
    }

    event ArtistIdentityContested(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed contester,
        bytes32 subjectRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        uint64 contestedAt,
        bytes32 contestRecordHash
    );

    function context(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.OwnerContext memory o,
        Contest.Request memory p
    ) public view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash) {
        _validate(identity, rotations, p);
        bytes32 pending = rotations.pending[p.artistId];
        bytes32 executed = rotations.latestExecution[p.artistId];
        scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_SCOPE_V1"),
                o.environment.chainId,
                o.environment.registry,
                address(this),
                p.artistId
            )
        );
        T.Identity storage principal = identity.identities[p.artistId];
        oldHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_STATE_V1"),
                scope,
                principal.authorityAddress,
                principal.authorityClass,
                principal.status,
                rotations.latestTransition[p.artistId],
                pending,
                executed,
                rotations.rotations[pending].transition,
                rotations.rotations[executed].transition,
                StreamArtistRotationState.operativeGuardian(rotations, p.artistId),
                rotations.rotations[pending].guardianSetRecordHash,
                s.latest[p.artistId]
            )
        );
        newHash = keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_INTENT_V1"), scope, oldHash, p)
        );
    }

    function contextWithSuccessor(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.OwnerContext memory o,
        Contest.Request memory p,
        address successor,
        bytes32 successorRecord
    ) public view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash) {
        (scope, oldHash, newHash) = context(s, identity, rotations, o, p);
        if (successorRecord != bytes32(0)) {
            oldHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_CONTEST_SUCCESSOR_STATE_V1"),
                    oldHash,
                    successor,
                    successorRecord
                )
            );
            newHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_INTENT_V1"), scope, oldHash, p
                )
            );
        }
    }

    function file(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Contest.Request memory p,
        Contest.GovernanceWitness memory governance,
        address governanceAuthority
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        return fileWithSuccessor(
            s,
            identity,
            rotations,
            replay,
            o,
            c,
            p,
            governance,
            governanceAuthority,
            address(0),
            bytes32(0)
        );
    }

    function fileWithSuccessor(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Contest.Request memory p,
        Contest.GovernanceWitness memory governance,
        address governanceAuthority,
        address successor,
        bytes32 successorRecord
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        Dismissal.ContestResolutionFacts memory empty;
        Dismissal.StandingJudgment memory none;
        return _file(
            s,
            identity,
            rotations,
            replay,
            o,
            c,
            p,
            governance,
            governanceAuthority,
            successor,
            successorRecord,
            empty,
            none
        );
    }

    function fileWithResolution(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Contest.Request memory p,
        Contest.GovernanceWitness memory governance,
        address governanceAuthority,
        address successor,
        bytes32 successorRecord,
        Dismissal.ContestResolutionFacts memory resolution,
        Dismissal.StandingJudgment memory judgment
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        return _file(
            s,
            identity,
            rotations,
            replay,
            o,
            c,
            p,
            governance,
            governanceAuthority,
            successor,
            successorRecord,
            resolution,
            judgment
        );
    }

    function _file(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Contest.Request memory p,
        Contest.GovernanceWitness memory governance,
        address governanceAuthority,
        address successor,
        bytes32 successorRecord,
        Dismissal.ContestResolutionFacts memory resolution,
        Dismissal.StandingJudgment memory judgment
    ) private returns (StreamArtistIdentityState.Mutation memory m) {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = contextWithResolution(
            s, identity, rotations, o, p, successor, successorRecord, resolution
        );
        bytes32 pending = rotations.pending[p.artistId];
        bytes32 executed = rotations.latestExecution[p.artistId];
        bytes32 guardians = StreamArtistRotationState.operativeGuardian(rotations, p.artistId);
        bytes32 captured = rotations.rotations[pending].guardianSetRecordHash;
        if (governance.actionId != bytes32(0)) {
            if (
                c.actor != governanceAuthority || governance.proposer == address(0)
                    || (governance.actionClass != 1 && governance.actionClass != 2)
                    || governance.roleRevision == 0 || governance.roleMutationHash == bytes32(0)
                    || governance.scopeHash != scope || governance.oldValueHash != oldHash
                    || governance.newValueHash != newHash
            ) revert Contest.InvalidContestGovernance();
        } else {
            Contest.GovernanceWitness memory empty;
            if (keccak256(abi.encode(governance)) != keccak256(abi.encode(empty))) {
                revert Contest.InvalidContestGovernance();
            }
            (bool revoked,) =
                StreamArtistRotationState.standingRevoked(rotations, p.artistId, c.actor);
            if (
                judgment.dismissalRecordHash != bytes32(0)
                    && judgment.retirementHash == rotations.retirement[p.artistId][c.actor]
            ) revoked = true;
            if (
                c.actor != successor && !_member(rotations, guardians, c.actor)
                    && !_member(rotations, captured, c.actor)
                    && (rotations.retirement[p.artistId][c.actor] == bytes32(0) || revoked)
            ) {
                revert T.Unauthorized(c.actor);
            }
        }
        if (block.timestamp == 0 || block.timestamp > type(uint64).max) revert T.InvalidRecord();
        uint64 observed = uint64(block.timestamp);
        bytes32 record = keccak256(
            abi.encode(
                bytes32(0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb),
                o.environment.chainId,
                o.environment.registry,
                p.artistId,
                c.actor,
                p.subjectRecordHash,
                p.evidenceHash,
                p.reasonHash,
                observed
            )
        );
        bytes32 subjectKey = _consume(
            replay,
            o,
            keccak256(
                abi.encode(
                    keccak256("subject"),
                    p.artistId,
                    p.subjectRecordHash,
                    p.evidenceHash,
                    p.reasonHash
                )
            ),
            record
        );
        bytes32 recordKey =
            _consume(replay, o, keccak256(abi.encode(keccak256("record"), record)), record);
        Contest.Record memory item = Contest.Record(
            record,
            p,
            c.actor,
            observed,
            identity.identities[p.artistId].status,
            guardians,
            captured,
            pending,
            executed,
            keccak256(abi.encode(governance))
        );
        s.records[record] = item;
        s.latest[p.artistId] = record;
        // The named historical subject cannot let a current provisional cohort escape the filing.
        _markWithResolution(rotations, p.subjectRecordHash, observed, resolution.subjectClosure);
        _markWithResolution(rotations, executed, observed, resolution.executedClosure);
        if (pending != bytes32(0)) {
            _mark(rotations, pending, observed);
            rotations.rotations[pending].transition.phase = 3;
            delete rotations.pending[p.artistId];
        }
        identity.identities[p.artistId].status = 4;
        m = StreamArtistIdentityState.Mutation(
            record,
            keccak256(abi.encode(p, governance)),
            keccak256(
                abi.encode(
                    item,
                    identity.identities[p.artistId],
                    rotations.rotations[p.subjectRecordHash].transition,
                    rotations.rotations[pending].transition,
                    rotations.rotations[executed].transition
                )
            ),
            keccak256(abi.encode(subjectKey, recordKey, record))
        );
        emit ArtistIdentityContested(
            1,
            p.artistId,
            c.actor,
            p.subjectRecordHash,
            p.evidenceHash,
            p.reasonHash,
            observed,
            record
        );

        if (
            resolution.currentCauseHash != bytes32(0)
                || resolution.currentResolutionHash != bytes32(0)
                || judgment.dismissalRecordHash != bytes32(0)
        ) {
            m.state = keccak256(abi.encode(m.state, resolution, judgment));
        }
    }

    function contextWithResolution(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.OwnerContext memory o,
        Contest.Request memory p,
        address successor,
        bytes32 successorRecord,
        Dismissal.ContestResolutionFacts memory resolution
    ) public view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash) {
        (scope, oldHash, newHash) =
            contextWithSuccessor(s, identity, rotations, o, p, successor, successorRecord);
        _validateClosed(rotations, p.subjectRecordHash, resolution.subjectClosure);
        _validateClosed(
            rotations, rotations.latestExecution[p.artistId], resolution.executedClosure
        );
        if (
            resolution.currentCauseHash != bytes32(0)
                || resolution.currentResolutionHash != bytes32(0)
                || resolution.subjectClosure.dismissalRecordHash != bytes32(0)
                || resolution.executedClosure.dismissalRecordHash != bytes32(0)
        ) {
            oldHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_RESOLUTION_STATE_V1"),
                    oldHash,
                    resolution
                )
            );
            newHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_INTENT_V1"), scope, oldHash, p
                )
            );
        }
    }

    function _validateClosed(
        StreamArtistRotationState.State storage rotations,
        bytes32 record,
        Dismissal.Closure memory closure_
    ) private view {
        if (closure_.dismissalRecordHash == bytes32(0)) {
            Dismissal.Closure memory empty;
            if (keccak256(abi.encode(closure_)) != keccak256(abi.encode(empty))) {
                revert Dismissal.InvalidClosure(record);
            }
            return;
        }
        R.TransitionState storage t = rotations.rotations[record].transition;
        uint64 ends = t.phase == 2 ? t.postWindowEndsAt : t.contestEndsAt;
        bool abandoned = t.phase == 3
            || (t.phase == 2 && t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt);
        if (
            record == bytes32(0) || closure_.transitionRecordHash != record
                || t.artistId != closure_.artistId || (t.phase != 2 && t.phase != 3)
                || closure_.windowEndsAt != ends || closure_.contestedAt != t.contestedAt
                || closure_.abandoned != abandoned
        ) revert Dismissal.InvalidClosure(record);
    }

    function _markWithResolution(
        StreamArtistRotationState.State storage rotations,
        bytes32 record,
        uint64 observed,
        Dismissal.Closure memory closure_
    ) private {
        _validateClosed(rotations, record, closure_);
        if (closure_.dismissalRecordHash == bytes32(0)) _mark(rotations, record, observed);
    }

    function _validate(
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        Contest.Request memory p
    ) private view {
        T.Identity storage principal = identity.identities[p.artistId];
        if (
            p.artistId == bytes32(0) || principal.status != 1 || principal.authorityClass != 1
                || principal.authorityAddress == address(0) || p.evidenceHash == bytes32(0)
                || p.reasonHash == bytes32(0)
        ) {
            revert Contest.InvalidIdentityContest(p.artistId);
        }
        if (p.subjectRecordHash != bytes32(0)) {
            R.TransitionState storage t = rotations.rotations[p.subjectRecordHash].transition;
            if (
                t.artistId != p.artistId || t.recordHash != p.subjectRecordHash
                    || (t.phase != 1 && t.phase != 2)
            ) {
                revert Contest.InvalidContestSubject(p.subjectRecordHash);
            }
        }
    }

    function _mark(
        StreamArtistRotationState.State storage rotations,
        bytes32 record,
        uint64 observed
    ) private {
        if (record != bytes32(0) && rotations.rotations[record].transition.contestedAt == 0) {
            rotations.rotations[record].transition.contestedAt = observed;
        }
    }

    function _member(
        StreamArtistRotationState.State storage rotations,
        bytes32 record,
        address account
    ) private view returns (bool) {
        address[] storage guardians = rotations.guardians[record].terms.guardians;
        for (uint256 i; i < guardians.length; ++i) {
            if (guardians[i] == account) return true;
        }
        return false;
    }

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
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
                keccak256("identity_authority.replay.contest_record_hash_and_subject_key"),
                scope
            )
        );
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(record, o.revision + 1, 1, 2);
    }
}
