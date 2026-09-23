// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistLivingDormancyReads as LivingDormancy
} from "./StreamArtistLivingDormancyReads.sol";

import {
    StreamArtistIdentityRecoveryState as State
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
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
    StreamArtistEstateTypes as E
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

/// @notice Original designated operation43 capability origin after an admitted operation35.
/// @dev The caller authenticates latest35, its exact current epoch and the entire later32 suffix.
/// This reads the fixed owner's immutable original records; it never reauthorizes old governance
/// or substitutes the recovered address/epoch into the original notice, plan or vesting.
library StreamArtistRecoveryDormancyOrigin {
    function requireOrigin(
        State.State storage recovery,
        StreamArtistHashes.Environment memory e,
        I.Record memory prior,
        E.AuthorityCapabilities memory capabilities
    ) public view returns (bytes32) {
        bytes32 artistId = prior.fields.artistId;
        bytes32 origin = capabilities.activationRecordHash;
        (bytes32 noticeHash, uint8 phase, bytes32 terminalHash) =
            IStreamArtistDormancyOwner(address(this)).dormancyNotice(artistId);
        (Dorm.Notice memory n, uint8 savedPhase, Dorm.Terminal memory t) =
            IStreamArtistDormancyOwner(address(this)).dormancyRecord(noticeHash);
        if (
            e.chainId != block.chainid || e.registry == address(0) || artistId == 0 || origin == 0
                || recovery.latest[artistId] != prior.recordHash || prior.recordHash == 0
                || prior.fields.vestedAuthorityClass != 3 || capabilities.authorityClass != 3
                || capabilities.status != 4 || noticeHash == 0 || phase != 3 || savedPhase != 3
                || terminalHash != origin || n.recordHash != noticeHash
                || n.terms.artistId != artistId || n.incumbent == address(0)
                || n.incumbent == t.plan.authority || n.terms.evidenceHash == 0
                || n.initiatedAt == 0 || n.actionId == 0 || n.witnessHash == 0
                || n.inactivitySeconds < 365 days || n.noticeSeconds < 180 days
                || n.timingRevision == 0
                || uint256(n.noticeEndsAt) != uint256(n.initiatedAt) + n.noticeSeconds
                || uint256(n.initiatedAt) < uint256(n.priorLivenessAt) + n.inactivitySeconds
                || n.recordHash != _noticeHash(e, n) || t.recordHash != origin
                || t.noticeHash != noticeHash || t.authorityClass != 3 || t.plan.authorityClass != 3
                || t.plan.authority == address(0) || t.appointmentBlock != 0
                || t.actor == address(0) || t.evidenceHash == 0 || t.actionId == 0
                || t.witnessHash == 0 || t.observedAt < n.noticeEndsAt
                || t.observedAt > prior.fields.recoveredAt || t.delegationEpoch == 0
                || t.delegationEpoch >= prior.delegationEpoch || t.plan.designation == 0
                || t.plan.stewardGrantRecordHash != 0 || t.plan.postSeconds < 72 hours
                || t.plan.standingTail < 30 days || t.plan.capabilities & ~uint32(4095) != 0
                || capabilities.effectiveCapabilities != t.plan.capabilities
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        (StreamArtistHashes.Environment memory completion, address completionOwner) =
            _original(e, 43, artistId, origin);
        t.recordHash = 0;
        if (
            origin
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_V1"),
                        completion.chainId,
                        completion.registry,
                        completionOwner,
                        t
                    )
                )
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        t.recordHash = origin;

        R.TransitionState memory transition =
            IStreamArtistRotationReads(address(this)).artistTransitionState(origin);
        V.Snapshot memory v = recovery.vestingHistory.snapshots[origin];
        V.Snapshot memory latestRecovery = recovery.vestingHistory.snapshots[prior.recordHash];
        if (
            transition.artistId != artistId || transition.recordHash != origin
                || transition.phase != 2 || transition.stagedAt != n.initiatedAt
                || transition.contestEndsAt != n.noticeEndsAt
                || transition.executedAt != t.observedAt
                || uint256(transition.postWindowEndsAt)
                    != uint256(t.observedAt) + t.plan.postSeconds || v.artistId != artistId
                || v.transitionRecordHash != origin || v.operationId != 43 || v.authorityClass != 3
                || v.oldAddress != n.incumbent || v.newAddress != t.plan.authority
                || v.executedAt != t.observedAt || v.ownerRevision == 0
                || (Imported.commitment() == 0 && v.ownerRevision <= v.guardians.ownerRevision)
                || v.commitment == 0 || v.commitment != _vestingHash(e, v)
                || latestRecovery.artistId != artistId
                || latestRecovery.transitionRecordHash != prior.recordHash
                || latestRecovery.operationId != 35 || latestRecovery.authorityClass != 3
                || !_before(e, v, latestRecovery)
                || latestRecovery.executedAt != prior.fields.recoveredAt
                || latestRecovery.executedAt < v.executedAt
                || latestRecovery.guardians.count < v.guardians.count
                || (Imported.commitment() == 0
                    && latestRecovery.guardians.ownerRevision < v.guardians.ownerRevision)
                || latestRecovery.commitment == 0
                || latestRecovery.commitment != _vestingHash(e, latestRecovery)
        ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        _prefix(recovery, v);
        if (v.previousTransitionRecordHash == 0) {
            if (v.previousCommitment != 0) revert I.UnsupportedIdentityRecoveryProfile(artistId);
        } else {
            // Original class1 evidence remains distinct from today's recovered class3 authority.
            V.Snapshot memory previous =
                recovery.vestingHistory.snapshots[v.previousTransitionRecordHash];
            if (
                previous.artistId != artistId
                    || previous.transitionRecordHash != v.previousTransitionRecordHash
                    || (previous.operationId != 32 && previous.operationId != 35)
                    || previous.authorityClass != 1 || previous.newAddress != v.oldAddress
                    || previous.commitment == 0 || previous.commitment != v.previousCommitment
                    || previous.commitment != _vestingHash(e, previous) || !_before(e, previous, v)
                    || previous.executedAt > n.initiatedAt
                    || previous.guardians.count > v.guardians.count
                    || (Imported.commitment() == 0
                        && previous.guardians.ownerRevision > v.guardians.ownerRevision)
            ) revert I.UnsupportedIdentityRecoveryProfile(artistId);
            _prefix(recovery, previous);
        }
        bytes32 proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_DORMANCY_ORIGIN_V1"),
                e.chainId,
                e.registry,
                address(this),
                n,
                t,
                transition,
                v,
                latestRecovery
            )
        );
        (, bytes32 livingProof) = LivingDormancy.beforeDormancy(
            address(this), e.registry, e.chainId, n, t, v, bytes32(0)
        );
        if (livingProof != 0) {
            proof = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERED_LIVING_DORMANCY_ORIGIN_V1"),
                    proof,
                    livingProof
                )
            );
        }
        return proof;
    }

    function _prefix(State.State storage recovery, V.Snapshot memory v) private view {
        GH.Head memory h = v.guardians;
        if (h.count == 0) {
            if (h.ownerRevision != 0 || h.commitment != 0) {
                revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
            }
        } else {
            bytes32 last = recovery.guardianHistory.records[v.artistId][h.count];
            GH.Entry memory entry = recovery.guardianHistory.entries[last];
            if (
                last == 0 || entry.artistId != v.artistId || entry.recordHash != last
                    || entry.index != h.count || entry.ownerRevision != h.ownerRevision
                    || entry.commitment != h.commitment || h.commitment == 0
                    || h.count > recovery.guardianRecordsSeen[v.artistId]
            ) revert I.UnsupportedIdentityRecoveryProfile(v.artistId);
        }
    }

    function _noticeHash(StreamArtistHashes.Environment memory e, Dorm.Notice memory n)
        private
        view
        returns (bytes32)
    {
        address originalOwner;
        (e, originalOwner) = _original(e, 41, n.terms.artistId, n.recordHash);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_NOTICE_V1"),
                e.chainId,
                e.registry,
                originalOwner,
                n.terms,
                n.incumbent,
                n.initiatedAt,
                n.noticeEndsAt,
                n.inactivitySeconds,
                n.noticeSeconds,
                n.timingRevision,
                n.priorLivenessAt,
                n.priorActivity,
                n.actionId,
                n.witnessHash
            )
        );
    }

    function _vestingHash(StreamArtistHashes.Environment memory e, V.Snapshot memory v)
        private
        view
        returns (bytes32)
    {
        if (Imported.commitment() != 0) {
            Recovered.vesting(Recovered.load(address(this), e.registry, e.chainId), v);
            return v.commitment;
        }
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

    function _original(
        StreamArtistHashes.Environment memory e,
        uint16 operation,
        bytes32 artistId,
        bytes32 record
    ) private view returns (StreamArtistHashes.Environment memory, address) {
        if (Imported.commitment() == 0) return (e, address(this));
        Runtime.ReceiptFact memory row = Recovered.nativeFact(
            Recovered.load(address(this), e.registry, e.chainId), operation, artistId, record
        );
        return (Recovered.hashes(row.environment), row.environment.owners[2]);
    }

    function _before(
        StreamArtistHashes.Environment memory e,
        V.Snapshot memory a,
        V.Snapshot memory b
    ) private view returns (bool) {
        if (Imported.commitment() == 0) {
            return a.ownerRevision < b.ownerRevision;
        }
        Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
        return Runtime.before(
            clock, Recovered.vesting(clock, a).point, Recovered.vesting(clock, b).point
        );
    }
}
