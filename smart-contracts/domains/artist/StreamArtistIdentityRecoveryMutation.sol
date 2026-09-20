// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAuthorityCheckpoint.sol";
import { StreamArtistAuthorityPreimages } from "./StreamArtistAuthorityPreimages.sol";
import {
    StreamArtistRecoveryEstateGuardians as EstateGuardians
} from "./StreamArtistRecoveryEstateGuardians.sol";
import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistSuccessionState } from "./StreamArtistSuccessionState.sol";
import { StreamArtistIdentityContestState } from "./StreamArtistIdentityContestState.sol";
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
    StreamArtistRecoveryContinuation as Continuation
} from "./StreamArtistRecoveryContinuation.sol";

/// @notice Same-owner recovery mutations after the fixed State wrapper derives the full context.
/// @dev The supplied context is internal linked-call evidence, not an external owner admission surface.
library StreamArtistIdentityRecoveryMutation {
    function recover(
        RecoveryState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        mapping(bytes32 => T.ReplayCell) storage replay,
        RecoveryState.Input memory i,
        Recovery.Context memory c
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        _governance(i, c);
        _requireAppealWitness(
            s,
            rotations,
            i.owner,
            i.request,
            i.governance.proposer,
            i.governance.roleMutationHash,
            i.governance.roleRevision
        );
        bytes32 guardian = _requirePrepared(s, rotations, i, c);
        return _recover(s, identity, rotations, estate, replay, i, c, guardian, false);
    }

    /// @dev The fixed V2 admission library has authenticated its manifest, role, exact prepared
    /// action and complete election. Share only original operation35 writes and semantic hashes.
    function recoverAdjudicated(
        RecoveryState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        mapping(bytes32 => T.ReplayCell) storage replay,
        RecoveryState.Input memory i,
        Recovery.Context memory c,
        bytes32 guardian
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        _governance(i, c);
        return _recover(s, identity, rotations, estate, replay, i, c, guardian, true);
    }

    function _governance(RecoveryState.Input memory i, Recovery.Context memory c) private view {
        if (
            i.action.operationId != 35 || i.action.actor != i.executor || i.executor == address(0)
                || i.governance.actionClass != 2 || i.governance.actionId == bytes32(0)
                || i.governance.proposer == address(0) || i.governance.roleRevision == 0
                || i.governance.roleMutationHash == bytes32(0)
                || i.governance.scopeHash != c.scopeHash
                || i.governance.oldValueHash != c.oldValueHash
                || i.governance.newValueHash != c.newValueHash || block.timestamp == 0
                || block.timestamp > type(uint64).max
        ) revert Recovery.InvalidIdentityRecoveryGovernance();
    }

    function _recover(
        RecoveryState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        mapping(bytes32 => T.ReplayCell) storage replay,
        RecoveryState.Input memory i,
        Recovery.Context memory c,
        bytes32 guardian,
        bool adjudicated
    ) private returns (StreamArtistIdentityState.Mutation memory m) {
        uint64 now_ = uint64(block.timestamp);
        uint64 postEnds = now_ + c.postContestSeconds;
        if (c.postContestSeconds < 72 hours || c.standingTailSeconds < 30 days) {
            revert Recovery.InvalidIdentityRecovery(i.request.artistId);
        }
        Recovery.Record memory item;
        item.fields = Permanent.RecordFields(
            i.request.artistId,
            c.incumbent,
            i.request.newAddress,
            i.request.vestedAuthorityClass,
            i.request.evidenceHash,
            i.request.reasonHash,
            H.supersession(i.request.supersededRecordHashes),
            i.governance.actionId,
            now_
        );
        item.recordHash =
            H.record(i.owner.environment.chainId, i.owner.environment.registry, item.fields);
        if (s.records[item.recordHash].recordHash != bytes32(0)) revert T.InvalidRecord();
        item.terms = i.request;
        item.executor = i.executor;
        item.proposer = i.governance.proposer;
        item.governanceWitnessHash = keccak256(abi.encode(i.governance));
        item.contextHash = keccak256(abi.encode(c));
        item.acceptanceDigest = i.approval.digest;
        item.acceptanceNonce = i.acceptance.nonce;
        item.acceptanceDeadline = i.acceptance.time;
        item.postContestSeconds = c.postContestSeconds;
        item.standingTailSeconds = c.standingTailSeconds;
        item.timingRevision = c.timingRevision;
        {
            bytes32 acceptanceDelta = StreamArtistRotationState.acceptIdentityRecovery(
                rotations,
                replay,
                i.owner,
                i.action,
                R.Rotation(
                    i.request.artistId,
                    c.incumbent,
                    i.request.newAddress,
                    i.request.reasonHash,
                    bytes32(0)
                ),
                i.acceptance,
                i.approval,
                item.recordHash
            );
            bytes32 causeKey = _consume(
                replay,
                i.owner,
                keccak256("identity_authority.replay.contest_resolution"),
                keccak256(abi.encode(i.request.artistId, c.causeHash)),
                item.recordHash
            );
            bytes32 actionKey = _consume(
                replay,
                i.owner,
                keccak256("identity_authority.replay.recovery_action"),
                keccak256(
                    abi.encode(i.governance.actionId, c.scopeHash, c.oldValueHash, c.newValueHash)
                ),
                item.recordHash
            );
            bytes32 retirementKey = _consume(
                replay,
                i.owner,
                keccak256("identity_authority.replay.standing_retirement"),
                keccak256(abi.encode(i.request.artistId, c.incumbent, item.recordHash)),
                item.recordHash
            );
            m.replay = keccak256(abi.encode(acceptanceDelta, causeKey, actionKey, retirementKey));
        }
        item.delegationEpoch = ++estate.delegationEpoch[i.request.artistId];
        s.records[item.recordHash] = item;
        StreamArtistAuthorityPreimages.recovery(
            i.owner.environment.chainId, i.owner.environment.registry, item.recordHash, item.fields
        );
        s.latest[i.request.artistId] = item.recordHash;
        s.transitions[item.recordHash] = R.TransitionState(
            i.request.artistId, item.recordHash, now_, now_, now_, postEnds, 0, 2
        );
        rotations.latestExecution[i.request.artistId] = item.recordHash;
        rotations.latestTransition[i.request.artistId] = item.recordHash;
        rotations.retirement[i.request.artistId][c.incumbent] = item.recordHash;
        delete identity.activeIdentity[c.incumbent];
        identity.activeIdentity[i.request.newAddress] = i.request.artistId;
        T.Identity storage principal = identity.identities[i.request.artistId];
        principal.authorityAddress = i.request.newAddress;
        principal.authorityClass = i.request.vestedAuthorityClass;
        principal.status = i.request.vestedAuthorityClass == 3 ? 3 : 1;
        m.record = item.recordHash;
        m.action = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_REGISTRY_WRITE_RECOVER_ARTIST_IDENTITY_V1"),
                i.request,
                i.acceptance,
                i.approval,
                i.governance,
                c
            )
        );
        m.state = _stateHash(s, identity, rotations, item);
        if (guardian != bytes32(0) || adjudicated) {
            s.actionExecutions[i.governance.actionId] = item.recordHash;
            s.recoveryGuardians[item.recordHash] = guardian;
            m.state = keccak256(
                abi.encode(
                    m.state,
                    s.actions[i.governance.actionId].associationHash,
                    i.governance.actionId,
                    item.recordHash,
                    guardian
                )
            );
        }
        if (i.request.supersededRecordHashes.length != 0 || adjudicated) {
            m.state = keccak256(
                abi.encode(
                    m.state,
                    GuardianSupersession.applyWithSelection(
                        s.guardianSupersession,
                        rotations,
                        s.recoveryGuardians,
                        i.request.artistId,
                        i.governance.actionId,
                        s.actions[i.governance.actionId].associationHash,
                        item.recordHash,
                        item.contextHash,
                        i.request.supersededRecordHashes
                    )
                )
            );
        }
    }

    function prepare(
        RecoveryState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        mapping(bytes32 => T.ReplayCell) storage replay,
        RecoveryState.PrepareInput memory i,
        Recovery.Context memory c
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 associationHash) {
        R.GuardianRecord memory guardian;
        if (s.latest[i.request.artistId] != 0) {
            guardian = Continuation.guardian(
                s,
                rotations,
                i.owner.environment,
                i.request.artistId,
                i.request.vestedAuthorityClass
            );
        } else if (i.request.vestedAuthorityClass == 3) {
            bytes32 activation = estate.authorityActivation[i.request.artistId];
            bytes32 terminal = rotations.latestExecution[i.request.artistId];
            guardian = terminal != activation
                ? EstateGuardians.afterRotation(
                    s.guardianHistory,
                    rotations,
                    i.owner.environment,
                    i.request.artistId,
                    s.guardianRecordsSeen[i.request.artistId],
                    s.vestingHistory.snapshots[activation],
                    estate.transitions[activation].postWindowEndsAt,
                    s.vestingHistory.snapshots[terminal],
                    rotations.rotations[terminal].transition.postWindowEndsAt
                )
                : EstateGuardians.guardian(
                    s.guardianHistory,
                    rotations,
                    i.owner.environment,
                    i.request.artistId,
                    s.guardianRecordsSeen[i.request.artistId],
                    s.vestingHistory.snapshots[activation],
                    estate.transitions[activation].postWindowEndsAt
                );
        } else {
            guardian = _guardian(s, rotations, i.owner, i.request.artistId, c.incumbent);
        }
        return prepareWithGuardian(s, rotations, replay, i, c, guardian);
    }

    /// @dev Fixed callers derive this guardian from the same authenticated context; not an external owner admission.
    function prepareWithGuardian(
        RecoveryState.State storage s,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        RecoveryState.PrepareInput memory i,
        Recovery.Context memory c,
        R.GuardianRecord memory guardian
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 associationHash) {
        A.Witness memory w = i.witness;
        _requireAppealWitness(
            s, rotations, i.owner, i.request, w.proposer, w.roleMutationHash, w.roleRevision
        );
        if (
            i.action.operationId != A.PREPARE_OPERATION || i.action.actor == address(0)
                || guardian.recordHash == bytes32(0) || w.actionId == bytes32(0)
                || w.executor == address(0) || w.executorCodeHash == bytes32(0)
                || w.callsHash == bytes32(0) || w.proposer == address(0)
                || w.roleMutationHash == bytes32(0) || w.roleRevision == 0
                || w.minimumDelay < 72 hours || block.timestamp == 0
                || block.timestamp > type(uint64).max
                || block.timestamp + w.minimumDelay > w.notBefore || w.notBefore > w.expiresAfter
                || i.acceptance.time < w.notBefore
                || s.actions[w.actionId].associationHash != bytes32(0)
        ) {
            revert A.InvalidRecoveryAction(w.actionId);
        }
        bytes32 previous = s.pendingAction[i.request.artistId];
        if (s.actions[previous].associationHash != i.previousAssociation) {
            revert A.InvalidRecoveryAction(previous);
        }
        if (previous != bytes32(0) && !i.previousTerminal) {
            revert A.RecoveryActionStillLive(previous);
        }
        A.Association memory a;
        a.artistId = i.request.artistId;
        a.requestHash = keccak256(abi.encode(i.request));
        a.acceptanceHash = keccak256(abi.encode(i.acceptance));
        a.contextHash = keccak256(abi.encode(c));
        a.action = w;
        a.guardian = guardian;
        a.preparedBy = i.action.actor;
        a.preparedAt = uint64(block.timestamp);
        a.ownerRevision = i.owner.revision + 1;
        associationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_V1"),
                i.owner.environment.chainId,
                i.owner.environment.registry,
                address(this),
                i.owner.coordinator,
                i.owner.archive,
                previous,
                a
            )
        );
        a.associationHash = associationHash;
        s.actions[w.actionId] = a;
        s.pendingAction[a.artistId] = w.actionId;
        m.action = keccak256(abi.encode(A.PREPARE_OPERATION, a, previous));
        GH.Snapshot memory history = GuardianHistory.freeze(
            s.guardianHistory,
            w.actionId,
            associationHash,
            a.artistId,
            s.guardianRecordsSeen[a.artistId]
        );
        m.state = keccak256(abi.encode(a, s.pendingAction[a.artistId], history));
        if (i.request.supersededRecordHashes.length != 0) {
            m.state = keccak256(
                abi.encode(
                    m.state,
                    GuardianSupersession.freezeWithSelection(
                        s.guardianSupersession,
                        s.guardianHistory,
                        rotations,
                        i.owner.environment,
                        i.request,
                        s.guardianRecordsSeen[a.artistId],
                        w.actionId,
                        associationHash,
                        a.contextHash
                    )
                )
            );
        }
        m.replay = _consume(
            replay,
            i.owner,
            keccak256("identity_authority.replay.recovery_preparation"),
            w.actionId,
            associationHash
        );
        // No semantic primary, sequence append, signature consumption or authority mutation.
    }

    function _requireAppealWitness(
        RecoveryState.State storage s,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.OwnerContext memory o,
        Recovery.Request memory p,
        address proposer,
        bytes32 mutation,
        uint64 revision
    ) private view {
        if (
            p.supersededRecordHashes.length != 0
                && GuardianSupersession.authorityRole(
                        s.guardianSupersession,
                        s.guardianHistory,
                        s.vestingHistory,
                        rotations,
                        p.artistId,
                        p.supersededRecordHashes,
                        s.guardianRecordsSeen[p.artistId]
                    ) == Appeal.APPEAL
        ) {
            StreamArtistGuardianAppealReads.requireWitness(
                o.environment, proposer, mutation, revision
            );
        }
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

    function _requirePrepared(
        RecoveryState.State storage s,
        StreamArtistRotationState.State storage rotations,
        RecoveryState.Input memory i,
        Recovery.Context memory c
    ) private view returns (bytes32 guardian) {
        guardian = rotations.latestExecution[i.request.artistId] == bytes32(0)
            ? rotations.stableGuardian[i.request.artistId]
            : StreamArtistRotationState.operativeGuardian(rotations, i.request.artistId);
        if (guardian == bytes32(0)) return guardian;
        A.Association storage a = s.actions[i.governance.actionId];
        if (
            a.associationHash == bytes32(0) || a.artistId != i.request.artistId
                || s.pendingAction[a.artistId] != i.governance.actionId
                || a.action.executor != i.executor || a.action.proposer != i.governance.proposer
                || a.requestHash != keccak256(abi.encode(i.request))
                || a.acceptanceHash != keccak256(abi.encode(i.acceptance))
                || a.contextHash != keccak256(abi.encode(c)) || a.guardian.recordHash != guardian
                || keccak256(abi.encode(a.guardian))
                    != keccak256(abi.encode(rotations.guardians[guardian]))
                || s.actionExecutions[i.governance.actionId] != bytes32(0)
        ) revert A.InvalidRecoveryAction(i.governance.actionId);
        GH.Head memory history = GuardianHistory.requireComplete(
            s.guardianHistory, a.artistId, s.guardianRecordsSeen[a.artistId]
        );
        GH.Snapshot storage snapshot = s.guardianHistory.snapshots[i.governance.actionId];
        if (
            snapshot.artistId != a.artistId || snapshot.associationHash != a.associationHash
                || snapshot.count != history.count
                || snapshot.historyCommitment != history.commitment
        ) {
            revert A.InvalidRecoveryAction(i.governance.actionId);
        }
        if (s.vetoes[i.governance.actionId].vetoer != address(0)) {
            revert A.RecoveryActionVetoed(i.governance.actionId);
        }
    }

    function _stateHash(
        RecoveryState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        Recovery.Record memory item
    ) private view returns (bytes32) {
        bytes32 artistId = item.fields.artistId;
        return keccak256(
            abi.encode(
                item,
                s.transitions[item.recordHash],
                identity.identities[artistId],
                identity.activeIdentity[item.fields.oldAddress],
                identity.activeIdentity[item.fields.newAddress],
                rotations.latestExecution[artistId],
                rotations.latestTransition[artistId],
                rotations.retirement[artistId][item.fields.oldAddress]
            )
        );
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
        StreamArtistAuthorityCheckpoint.noteReplay(key, replay[key]);
    }
}
