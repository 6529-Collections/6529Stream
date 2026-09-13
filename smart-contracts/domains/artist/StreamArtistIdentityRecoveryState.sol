// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

/// @notice Identity recovery for an initial living authority with no admitted transition/guardian history.
/// @dev Owner calls this only after pinned governance/signature observations and commits both receipts once.
library StreamArtistIdentityRecoveryState {
    struct State {
        mapping(bytes32 => Recovery.Record) records;
        mapping(bytes32 => R.TransitionState) transitions;
        mapping(bytes32 => bytes32) latest;
        Receipts.State receipts;
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
                || cause.facts.priorStatus != 1 || p.supersededRecordHashes.length != 0
                || rotations.latestExecution[p.artistId] != bytes32(0)
                || rotations.latestTransition[p.artistId] != bytes32(0)
                || rotations.pending[p.artistId] != bytes32(0)
                || rotations.stableGuardian[p.artistId] != bytes32(0)
                || rotations.provisionalGuardian[p.artistId] != bytes32(0)
                || cause.facts.pendingTransitionHash != bytes32(0)
                || cause.facts.executedTransitionHash != bytes32(0)
                || s.latest[p.artistId] != bytes32(0)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        if (identity.activeIdentity[p.newAddress] != bytes32(0)) {
            revert T.AddressAlreadyRegistered(p.newAddress);
        }
        c.causeHash = cause.causeHash;
        c.incumbent = principal.authorityAddress;
        c.postContestSeconds = StreamArtistRotationState.rotationSeconds(rotations);
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
            1,
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
        principal.authorityClass = 1;
        principal.status = 1;
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

    function _stateHash(
        State storage s,
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
    }
}
