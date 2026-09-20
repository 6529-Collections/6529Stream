// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    IStreamArtistGuardianHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as IdentityRecovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistIdentityRecoveryHashes as Hashes
} from "./StreamArtistIdentityRecoveryHashes.sol";

/// @notice Original admitted class-1 operation35 evidence from the fixed Identity owner.
/// @dev Callers supply their fixed owner and decide current-head, epoch and closure eligibility.
/// This reader neither reauthorizes historical governance nor consults mutable retirement state.
library StreamArtistLivingRecoveryReads {
    struct Facts {
        IdentityRecovery.Record record;
        R.TransitionState transition;
        V.Snapshot vesting;
        bytes32 proof;
    }

    struct Environment {
        address owner;
        address registry;
        uint256 chainId;
    }

    struct Admission {
        A.Association association;
        GH.Snapshot frozen;
        V.Snapshot parent;
        bytes32 guardian;
        bytes32 primary;
        bytes32 occurrence;
        bytes32 secondary;
    }

    function read(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 recordHash
    ) public view returns (Facts memory f) {
        if (
            chainId != block.chainid || owner.code.length == 0 || registry == address(0)
                || artistId == 0 || recordHash == 0
                || IStreamArtistOwner(owner).deploymentChainId() != chainId
                || IStreamArtistOwner(owner).artistRegistry() != registry
        ) revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
        Environment memory e = Environment(owner, registry, chainId);
        f.record = IStreamArtistIdentityRecoveryOwner(owner).identityRecoveryRecord(recordHash);
        f.transition = IStreamArtistRotationReads(owner).artistTransitionState(recordHash);
        f.vesting = IStreamArtistGuardianVestingHistory(owner)
            .guardianVestingSnapshot(artistId, recordHash);
        _record(e, artistId, recordHash, f);
        f.proof = _admission(e, f);
    }

    function _record(Environment memory e, bytes32 artistId, bytes32 recordHash, Facts memory f)
        private
        pure
    {
        IdentityRecovery.Record memory r = f.record;
        R.TransitionState memory t = f.transition;
        V.Snapshot memory v = f.vesting;
        if (
            r.recordHash != recordHash
                || Hashes.record(e.chainId, e.registry, r.fields) != recordHash
                || r.fields.artistId != artistId || r.fields.oldAddress == address(0)
                || r.fields.newAddress == address(0) || r.fields.oldAddress == r.fields.newAddress
                || r.fields.vestedAuthorityClass != 1 || r.fields.recoveredAt == 0
                || r.fields.governanceActionId == 0 || r.fields.evidenceHash == 0
                || r.fields.reasonHash == 0 || r.terms.artistId != artistId
                || r.terms.newAddress != r.fields.newAddress || r.terms.vestedAuthorityClass != 1
                || r.terms.expectedCauseHash == 0 || r.terms.evidenceHash != r.fields.evidenceHash
                || r.terms.reasonHash != r.fields.reasonHash
                || Hashes.supersession(r.terms.supersededRecordHashes)
                    != r.fields.supersededRecordsHash || r.executor == address(0)
                || r.proposer == address(0) || r.governanceWitnessHash == 0 || r.contextHash == 0
                || r.acceptanceDigest == 0 || r.acceptanceDeadline < r.fields.recoveredAt
                || r.postContestSeconds < 72 hours || r.standingTailSeconds < 30 days
                || r.timingRevision == 0 || r.delegationEpoch == 0 || t.artistId != artistId
                || t.recordHash != recordHash || t.phase != 2
                || t.executedAt != r.fields.recoveredAt || t.stagedAt != t.executedAt
                || t.contestEndsAt != t.executedAt
                || uint256(t.postWindowEndsAt) != uint256(t.executedAt) + r.postContestSeconds
                || (t.contestedAt != 0 && t.contestedAt < t.executedAt) || v.artistId != artistId
                || v.transitionRecordHash != recordHash || v.operationId != 35
                || v.authorityClass != 1 || v.oldAddress != r.fields.oldAddress
                || v.newAddress != r.fields.newAddress || v.executedAt != t.executedAt
                || v.ownerRevision == 0 || v.ownerRevision <= v.guardians.ownerRevision
                || v.commitment == 0 || v.commitment != _vestingHash(e, v)
        ) revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _admission(Environment memory e, Facts memory f) private view returns (bytes32) {
        bytes32 artistId = f.record.fields.artistId;
        bytes32 action = f.record.fields.governanceActionId;
        Admission memory admitted;
        bytes32 executed;
        uint64 actualCount;
        (admitted.association,, executed, actualCount) =
            IStreamArtistRecoveryActionOwner(e.owner).identityRecoveryActionState(artistId, action);
        admitted.frozen = _prefix(e, f.vesting, action, actualCount);
        admitted.parent = _parent(e, f.vesting, actualCount);
        address oldAddress;
        uint64 tail;
        (oldAddress, admitted.guardian, tail) = IStreamArtistIdentityRecoveryOwner(e.owner)
            .recoveryTransitionStanding(f.record.recordHash);
        if (oldAddress != f.record.fields.oldAddress || tail != f.record.standingTailSeconds) {
            revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        A.Association memory a = admitted.association;
        if (a.associationHash != 0) {
            if (
                executed != f.record.recordHash || a.artistId != artistId
                    || a.requestHash != keccak256(abi.encode(f.record.terms))
                    || a.contextHash != f.record.contextHash || a.action.actionId != action
                    || a.action.proposer != f.record.proposer
                    || a.action.executor != f.record.executor || a.ownerRevision == 0
                    || a.ownerRevision >= f.vesting.ownerRevision || a.preparedAt == 0
                    || a.preparedAt > f.record.fields.recoveredAt
                    || admitted.frozen.artistId != artistId
                    || admitted.frozen.associationHash != a.associationHash
                    || admitted.frozen.count != f.vesting.guardians.count
                    || admitted.frozen.historyCommitment != f.vesting.guardians.commitment
            ) revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
        } else if (executed != 0 || admitted.guardian != 0 || f.vesting.guardians.count != 0) {
            revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        // The standing getter authenticates a saved restored guardian (including zero) after
        // supersession. It need not equal the pre-recovery association's original guardian.
        (admitted.primary, admitted.occurrence, admitted.secondary) = IStreamArtistIdentityRecoveryOwner(
                e.owner
            ).identityRecoveryReceipts(f.record.recordHash);
        if (
            admitted.primary == 0 || admitted.occurrence == 0 || admitted.secondary == 0
                || admitted.primary == admitted.secondary
        ) revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(artistId);
        // Do not commit today's growing guardian head: all included evidence is original history.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ADMITTED_LIVING_RECOVERY_V1"),
                f.record,
                f.transition,
                f.vesting,
                admitted
            )
        );
    }

    function _parent(Environment memory e, V.Snapshot memory v, uint64 actualCount)
        private
        view
        returns (V.Snapshot memory parent)
    {
        if (v.previousTransitionRecordHash == 0) {
            if (v.previousCommitment != 0) {
                revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
            return parent;
        }
        parent = IStreamArtistGuardianVestingHistory(e.owner)
            .guardianVestingSnapshot(v.artistId, v.previousTransitionRecordHash);
        if (
            parent.artistId != v.artistId
                || parent.transitionRecordHash != v.previousTransitionRecordHash
                || parent.commitment == 0 || parent.commitment != v.previousCommitment
                || parent.commitment != _vestingHash(e, parent) || parent.authorityClass != 1
                || (parent.operationId != 32 && parent.operationId != 35)
                || parent.oldAddress == address(0) || parent.newAddress != v.oldAddress
                || parent.oldAddress == parent.newAddress || parent.executedAt == 0
                || parent.executedAt > v.executedAt || parent.ownerRevision == 0
                || parent.ownerRevision >= v.ownerRevision
                || parent.ownerRevision <= parent.guardians.ownerRevision
                || parent.guardians.count > v.guardians.count
                || parent.guardians.ownerRevision > v.guardians.ownerRevision
        ) revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        _prefix(e, parent, bytes32(0), actualCount);
    }

    function _prefix(Environment memory e, V.Snapshot memory v, bytes32 action, uint64 actualCount)
        private
        view
        returns (GH.Snapshot memory frozen)
    {
        GH.Head memory head;
        GH.Entry memory last;
        (head, last, frozen,) = IStreamArtistGuardianHistory(e.owner)
            .guardianHistoryState(v.artistId, v.guardians.count, address(0), action);
        // The fixed getter requires the complete current history, then selects this exact saved
        // prefix endpoint from its admitted index. Later admissions do not replace that prefix.
        if (head.count != actualCount || v.guardians.count > head.count) {
            revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
        if (v.guardians.count == 0) {
            if (v.guardians.ownerRevision != 0 || v.guardians.commitment != 0) {
                revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
        } else if (
            v.guardians.ownerRevision == 0 || v.guardians.commitment == 0
                || v.guardians.ownerRevision > head.ownerRevision || last.artistId != v.artistId
                || last.index != v.guardians.count
                || last.ownerRevision != v.guardians.ownerRevision
                || last.commitment != v.guardians.commitment || last.recordHash == 0
                || last.recordDataHash == 0
                || last.commitment
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_GUARDIAN_ADMISSION_HISTORY_V1"),
                            e.chainId,
                            e.registry,
                            e.owner,
                            last.artistId,
                            last.index,
                            last.ownerRevision,
                            last.recordHash,
                            last.recordDataHash,
                            last.previousCommitment
                        )
                    )
        ) {
            revert IdentityRecovery.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
    }

    function _vestingHash(Environment memory e, V.Snapshot memory v)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_V1"),
                    e.chainId,
                    e.registry,
                    e.owner
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
