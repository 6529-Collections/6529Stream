// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAuthorityCheckpoint.sol";
import { StreamArtistIdentityRecoveryMutation } from "./StreamArtistIdentityRecoveryMutation.sol";
import { StreamArtistIdentityRecoveryContext } from "./StreamArtistIdentityRecoveryContext.sol";
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

/// @notice Living recovery from initial authority or authenticated ordinary-rotation history.
/// @dev Owner calls this only after pinned governance/signature observations and commits both receipts once.
library StreamArtistIdentityRecoveryState {
    // Preserve the error ABI exposed before the fixed context-library extraction.
    error AddressAlreadyRegistered(address authority);
    error InvalidIdentityRecoveryGovernance();
    error RecoveryActionStillLive(bytes32 actionId);
    error RecoveryActionVetoed(bytes32 actionId);
    error UnsupportedIdentityRecoveryProfile(bytes32 artistId);

    struct State {
        mapping(bytes32 => Recovery.Record) records;
        mapping(bytes32 => R.TransitionState) transitions;
        mapping(bytes32 => bytes32) latest;
        Receipts.State receipts;
        mapping(bytes32 => uint64) guardianRecordsSeen;
        mapping(bytes32 => A.Association) actions;
        mapping(bytes32 => bytes32) pendingAction;
        mapping(bytes32 => A.Veto) vetoes;
        mapping(bytes32 => bytes32) actionExecutions;
        mapping(bytes32 => bytes32) recoveryGuardians;
        GuardianHistory.State guardianHistory;
        StreamArtistGuardianVestingHistory.State vestingHistory;
        GuardianSupersession.State guardianSupersession;
    }

    struct Input {
        StreamArtistIdentityState.OwnerContext owner;
        T.ActionContext action;
        Recovery.Request request;
        T.Authorization acceptance;
        T.SignerApproval approval;
        Contest.GovernanceWitness governance;
        address executor;
    }

    struct PrepareInput {
        StreamArtistIdentityState.OwnerContext owner;
        T.ActionContext action;
        Recovery.Request request;
        T.Authorization acceptance;
        A.Witness witness;
        bytes32 previousAssociation;
        bool previousTerminal;
    }

    function context(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        StreamArtistIdentityState.OwnerContext memory o,
        Recovery.Request memory p,
        T.Authorization memory acceptance
    ) public view returns (Recovery.Context memory c) {
        return StreamArtistIdentityRecoveryContext.context(
            s, identity, rotations, resolutions, estate, o, p, acceptance
        );
    }

    function contextWithEstate(
        State storage s,
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
        return StreamArtistIdentityRecoveryContext.contextWithEstate(
            s, identity, rotations, resolutions, estate, succession, contests, o, p, acceptance
        );
    }

    function recover(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        mapping(bytes32 => T.ReplayCell) storage replay,
        Input memory i
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        Recovery.Context memory c = context(
            s, identity, rotations, resolutions, estate, i.owner, i.request, i.acceptance
        );
        return StreamArtistIdentityRecoveryMutation.recover(
            s, identity, rotations, resolutions, estate, replay, i, c
        );
    }

    function recoverWithEstate(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityContestState.State storage contests,
        mapping(bytes32 => T.ReplayCell) storage replay,
        Input memory i
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        Recovery.Context memory c = contextWithEstate(
            s,
            identity,
            rotations,
            resolutions,
            estate,
            succession,
            contests,
            i.owner,
            i.request,
            i.acceptance
        );
        return StreamArtistIdentityRecoveryMutation.recover(
            s, identity, rotations, resolutions, estate, replay, i, c
        );
    }

    function prepare(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        mapping(bytes32 => T.ReplayCell) storage replay,
        PrepareInput memory i
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 associationHash) {
        Recovery.Context memory c =
            context(s, identity, rotations, resolutions, estate, i.owner, i.request, i.acceptance);
        return StreamArtistIdentityRecoveryMutation.prepare(
            s, identity, rotations, resolutions, estate, replay, i, c
        );
    }

    function prepareWithEstate(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityContestState.State storage contests,
        mapping(bytes32 => T.ReplayCell) storage replay,
        PrepareInput memory i
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 associationHash) {
        Recovery.Context memory c = contextWithEstate(
            s,
            identity,
            rotations,
            resolutions,
            estate,
            succession,
            contests,
            i.owner,
            i.request,
            i.acceptance
        );
        return StreamArtistIdentityRecoveryMutation.prepare(
            s, identity, rotations, resolutions, estate, replay, i, c
        );
    }

    function veto(
        State storage s,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        bytes32 artistId,
        bytes32 expectedAction,
        bytes32 reason,
        bool scheduled
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        A.Association storage a = s.actions[s.pendingAction[artistId]];
        if (
            c.operationId != 34 || a.associationHash == bytes32(0) || a.artistId != artistId
                || a.action.actionId != expectedAction || !scheduled || reason == bytes32(0)
                || s.vetoes[expectedAction].vetoer != address(0)
                || s.actionExecutions[expectedAction] != bytes32(0) || block.timestamp == 0
                || block.timestamp > type(uint64).max
        ) revert A.InvalidRecoveryAction(expectedAction);
        bool eligible = s.guardianSupersession.plans[expectedAction].associationHash == 0
            ? GuardianHistory.member(
                s.guardianHistory, expectedAction, a.associationHash, artistId, c.actor
            )
            : GuardianSupersession.member(
                s.guardianSupersession,
                s.guardianHistory,
                artistId,
                expectedAction,
                a.associationHash,
                c.actor
            );
        if (!eligible) {
            revert A.InvalidRecoveryGuardian(c.actor);
        }
        s.vetoes[expectedAction] = A.Veto(c.actor, reason, uint64(block.timestamp));
        m.action = keccak256(abi.encode(artistId, expectedAction, c.actor, reason));
        m.state = keccak256(
            abi.encode(
                a.associationHash,
                s.vetoes[expectedAction],
                s.guardianHistory.snapshots[expectedAction],
                s.guardianHistory.firstMembership[artistId][c.actor]
            )
        );
        m.replay = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.recovery_veto_key"),
            expectedAction,
            m.action
        );
    }

    /// @notice Marks retained recovery transitions after the same owner's successful operation33 admission.
    /// @dev The authenticated subject/current closures preserve resolved history. No extra revision or replay lane is added.
    function contest(
        State storage s,
        bytes32 artistId,
        bytes32 subject,
        bytes32 executed,
        bool subjectClosed,
        bool executedClosed
    ) public returns (bytes32 stateDelta) {
        bool changed = _markContest(s, artistId, subject, subjectClosed);
        changed = _markContest(s, artistId, executed, executedClosed) || changed;
        if (changed) {
            stateDelta =
                keccak256(abi.encode(artistId, s.transitions[subject], s.transitions[executed]));
        }
    }

    function _markContest(State storage s, bytes32 artistId, bytes32 record, bool closed)
        private
        returns (bool)
    {
        if (record == bytes32(0) || s.records[record].recordHash == bytes32(0) || closed) {
            return false;
        }
        Recovery.Record storage item = s.records[record];
        R.TransitionState storage t = s.transitions[record];
        if (
            item.recordHash != record || item.fields.artistId != artistId || t.artistId != artistId
                || t.recordHash != record || t.phase != 2 || t.executedAt == 0
        ) {
            revert Recovery.InvalidIdentityRecovery(artistId);
        }
        if (t.contestedAt != 0) return false;
        if (block.timestamp == 0 || block.timestamp > type(uint64).max) {
            revert Recovery.InvalidIdentityRecovery(artistId);
        }
        t.contestedAt = uint64(block.timestamp);
        return true;
    }

    function receiptCommitments(State storage s, bytes32 record)
        public
        view
        returns (bytes32 primaryCommitment, bytes32 occurrence, bytes32 secondaryCommitment)
    {
        Recovery.Record storage item = s.records[record];
        if (record == bytes32(0) || item.recordHash != record || item.fields.artistId == bytes32(0))
        {
            revert T.InvalidRecord();
        }
        occurrence = Receipts.occurrenceKey(record, item.fields.supersededRecordsHash);
        primaryCommitment = s.receipts.receipts[Receipts.PRIMARY][record];
        secondaryCommitment = s.receipts.secondaryOccurrences[occurrence];
        if (primaryCommitment == bytes32(0) || secondaryCommitment == bytes32(0)) {
            revert T.InvalidRecord();
        }
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
