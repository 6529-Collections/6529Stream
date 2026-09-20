// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistDormancyState as Dormancy } from "./StreamArtistDormancyState.sol";
import { StreamArtistIdentityActivityMutation } from "./StreamArtistIdentityActivityMutation.sol";

import {
    StreamArtistRecoveryAdjudicationContext as Context
} from "./StreamArtistRecoveryAdjudicationContext.sol";
import {
    StreamArtistRecoveryAdjudicationState as Supplemental
} from "./StreamArtistRecoveryAdjudicationState.sol";
import {
    StreamArtistIdentityRecoveryState as Recovery
} from "./StreamArtistIdentityRecoveryState.sol";
import {
    StreamArtistIdentityRecoveryMutation as Mutation
} from "./StreamArtistIdentityRecoveryMutation.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolutions
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistEstateState as Estate } from "./StreamArtistEstateState.sol";
import { StreamArtistGuardianAppealReads } from "./StreamArtistGuardianAppealReads.sol";
import { StreamArtistAuthorityCheckpoint } from "./StreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistRecoveryEvidenceTypes as E
} from "../../interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistGuardianSupersessionTypes as S
} from "../../interfaces/stream/artist/StreamArtistGuardianSupersessionTypes.sol";
import {
    StreamArtistGuardianAppealTypes as Appeal
} from "../../interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Fixed V2 admission around the original permanent operation35 mutation.
library StreamArtistRecoveryAdjudicationMutation {
    function prepare(
        Recovery.State storage s,
        Supplemental.State storage supplemental,
        Identity.State storage identity,
        Rotations.State storage rotations,
        Resolutions.State storage resolutions,
        Estate.State storage estate,
        Dormancy.State storage dormancy,
        mapping(bytes32 => T.ReplayCell) storage replay,
        Recovery.PrepareInput memory i,
        bytes32 manifestHash
    ) public returns (Identity.Mutation memory m, bytes32 associationHash) {
        Context.Facts memory f = Context.read(
            s,
            supplemental,
            identity,
            rotations,
            resolutions,
            estate,
            dormancy,
            i.owner,
            i.request,
            i.acceptance,
            manifestHash
        );
        A.Witness memory w = i.witness;
        _role(i.owner, f.guardians.requiredRole, w.proposer, w.roleMutationHash, w.roleRevision);
        if (
            i.action.operationId != A.PREPARE_OPERATION || i.action.actor == address(0)
                || w.actionId == 0 || w.executor == address(0) || w.executorCodeHash == 0
                || w.executor.codehash != w.executorCodeHash || w.callsHash == 0
                || w.callDataHash == 0 || w.proposer == address(0) || w.roleMutationHash == 0
                || w.roleRevision == 0 || w.minimumDelay < 72 hours || block.timestamp == 0
                || block.timestamp > type(uint64).max
                || block.timestamp + w.minimumDelay > w.notBefore || w.notBefore > w.expiresAfter
                || i.acceptance.time < w.notBefore || s.actions[w.actionId].associationHash != 0
                || supplemental.manifestActions[manifestHash] != 0
        ) revert A.InvalidRecoveryAction(w.actionId);
        bytes32 previous = s.pendingAction[i.request.artistId];
        if (s.actions[previous].associationHash != i.previousAssociation) {
            revert A.InvalidRecoveryAction(previous);
        }
        if (previous != 0 && !i.previousTerminal) revert A.RecoveryActionStillLive(previous);
        A.Association memory a;
        a.artistId = i.request.artistId;
        a.requestHash = keccak256(abi.encode(i.request));
        a.acceptanceHash = keccak256(abi.encode(i.acceptance));
        a.contextHash = keccak256(abi.encode(f.context));
        a.action = w;
        a.guardian = f.selected;
        a.preparedBy = i.action.actor;
        a.preparedAt = uint64(block.timestamp);
        a.ownerRevision = i.owner.revision + 1;
        associationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_V2"),
                i.owner.environment.chainId,
                i.owner.environment.registry,
                address(this),
                i.owner.coordinator,
                i.owner.archive,
                previous,
                manifestHash,
                f.guardians.commitment,
                f.selection,
                a
            )
        );
        a.associationHash = associationHash;
        s.actions[w.actionId] = a;
        s.pendingAction[a.artistId] = w.actionId;
        E.EvidenceStateV2 memory evidence = E.EvidenceStateV2(
            manifestHash,
            f.guardians.commitment,
            f.selection.commitment,
            f.guardians.requiredRole,
            i.owner.revision,
            associationHash
        );
        supplemental.actions[w.actionId] = evidence;
        supplemental.manifestActions[manifestHash] = w.actionId;
        _freeze(s, rotations, f, a);
        m.action = keccak256(abi.encode(A.PREPARE_OPERATION, a, previous, evidence));
        m.state = keccak256(
            abi.encode(
                a,
                evidence,
                s.guardianHistory.snapshots[w.actionId],
                s.guardianSupersession.plans[w.actionId],
                f.selection,
                f.selected
            )
        );
        m.replay = _consume(replay, i.owner, w.actionId, associationHash);
    }

    function recover(
        Recovery.State storage s,
        Supplemental.State storage supplemental,
        Identity.State storage identity,
        Rotations.State storage rotations,
        Resolutions.State storage resolutions,
        Estate.State storage estate,
        Dormancy.State storage dormancy,
        mapping(bytes32 => T.ReplayCell) storage replay,
        Recovery.Input memory i,
        bytes32 manifestHash
    ) public returns (Identity.Mutation memory m) {
        bytes32 actionId = i.governance.actionId;
        if (s.vetoes[actionId].vetoer != address(0)) revert A.RecoveryActionVetoed(actionId);
        A.Association storage a = s.actions[actionId];
        if (
            a.associationHash == 0 || a.artistId != i.request.artistId
                || s.pendingAction[a.artistId] != actionId || s.actionExecutions[actionId] != 0
        ) revert A.InvalidRecoveryAction(actionId);
        Context.Facts memory f = Context.read(
            s,
            supplemental,
            identity,
            rotations,
            resolutions,
            estate,
            dormancy,
            i.owner,
            i.request,
            i.acceptance,
            manifestHash
        );
        E.EvidenceStateV2 memory evidence = supplemental.actions[actionId];
        _role(
            i.owner,
            f.guardians.requiredRole,
            i.governance.proposer,
            i.governance.roleMutationHash,
            i.governance.roleRevision
        );
        if (
            evidence.manifestHash != manifestHash || evidence.associationHash != a.associationHash
                || evidence.basisCommitment != f.guardians.commitment
                || evidence.selectionCommitment != f.selection.commitment
                || evidence.requiredRole != f.guardians.requiredRole
                || evidence.preparedFromOwnerRevision != f.source.manifest.ownerRevision
                || a.ownerRevision != i.owner.revision || a.action.executor != i.executor
                || a.action.executor.codehash != a.action.executorCodeHash
                || a.action.proposer != i.governance.proposer
                || a.action.roleMutationHash != i.governance.roleMutationHash
                || a.action.roleRevision != i.governance.roleRevision
                || a.requestHash != keccak256(abi.encode(i.request))
                || a.acceptanceHash != keccak256(abi.encode(i.acceptance))
                || a.contextHash != keccak256(abi.encode(f.context))
                || keccak256(abi.encode(a.guardian)) != keccak256(abi.encode(f.selected))
                || keccak256(abi.encode(s.guardianSupersession.elections[actionId]))
                    != keccak256(abi.encode(f.selection))
        ) revert A.InvalidRecoveryAction(actionId);
        GH.Snapshot storage snapshot = s.guardianHistory.snapshots[actionId];
        if (
            snapshot.artistId != a.artistId || snapshot.associationHash != a.associationHash
                || snapshot.count != f.guardians.history.count
                || snapshot.historyCommitment != f.guardians.history.commitment
        ) revert A.InvalidRecoveryAction(actionId);
        m = Mutation.recoverAdjudicated(
            s, identity, rotations, estate, replay, i, f.context, f.selected.recordHash
        );
        if (f.source.notice.notice.recordHash != 0) {
            // New-side acceptance has succeeded and installed this actual living principal.
            // Original activity creates operation42 before the adjacent native operation35 pair.
            (m.state, m.replay) = StreamArtistIdentityActivityMutation.noteDormancy(
                dormancy, identity, i.owner, replay, i.request.artistId, i.request.newAddress, 1, m
            );
        }
        m.action = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_ADJUDICATION_WRITE_V2"), m.action, evidence
            )
        );
        m.state = keccak256(abi.encode(m.state, evidence));
    }

    function _freeze(
        Recovery.State storage s,
        Rotations.State storage rotations,
        Context.Facts memory f,
        A.Association memory a
    ) private {
        bytes32 actionId = a.action.actionId;
        if (
            s.guardianHistory.snapshots[actionId].associationHash != 0
                || s.guardianSupersession.plans[actionId].associationHash != 0
        ) revert A.InvalidRecoveryAction(actionId);
        // A completed V2 scan proves the zero-count case, unlike an absent V1 preparation.
        s.guardianHistory.snapshots[actionId] = GH.Snapshot(
            a.artistId, f.guardians.history.count, f.guardians.history.commitment, a.associationHash
        );
        bytes32[] memory excluded = f.source.manifest.supersededRecordHashes;
        s.guardianSupersession.plans[actionId] = S.Plan(
            a.artistId,
            a.associationHash,
            a.contextHash,
            f.guardians.history.count,
            f.guardians.history.commitment,
            excluded
        );
        for (uint256 index; index < excluded.length; ++index) {
            address[] storage guardians = rotations.guardians[excluded[index]].terms.guardians;
            for (uint256 j; j < guardians.length; ++j) {
                ++s.guardianSupersession.excludedMemberships[actionId][guardians[j]];
            }
        }
        s.guardianSupersession.elections[actionId] = f.selection;
        s.guardianSupersession.restoredGuardians[actionId] = f.selected;
    }

    function _role(
        Identity.OwnerContext memory o,
        bytes32 role,
        address proposer,
        bytes32 mutation,
        uint64 revision
    ) private view {
        if (role == Appeal.APPEAL) {
            StreamArtistGuardianAppealReads.requireWitness(
                o.environment, proposer, mutation, revision
            );
        } else if (role != Appeal.ARBITER) {
            revert E.InvalidRecoveryManifest(bytes32(0));
        }
    }

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        Identity.OwnerContext memory o,
        bytes32 actionId,
        bytes32 association
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
                keccak256("identity_authority.replay.recovery_preparation"),
                actionId
            )
        );
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(association, o.revision + 1, 1, 2);
        StreamArtistAuthorityCheckpoint.noteReplay(key, replay[key]);
    }
}
