// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import { StreamArtistEstateHashes } from "./StreamArtistEstateHashes.sol";
import { StreamArtistIdentityRecoveryHashes } from "./StreamArtistIdentityRecoveryHashes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import {
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Exact staging heads from the fixed Identity owner's original native receipt order.
/// @dev Only operations29/38/35/43 replace latestTransition. Operation35's secondary receipt is
/// not a second transition. Callers still prove executed ancestry, authority class, closures and
/// maturity; a cancelled request is never relabelled as a vesting. No writer or index is changed.
library StreamArtistRecoveryStagingHistory {
    struct Head {
        bytes32 recordHash;
        uint16 operation;
        uint64 ownerRevision;
        uint64 boundaryRevision;
        bytes32 proof;
        RH.Point point;
        RH.Point boundaryPoint;
    }

    struct EstateFacts {
        Estate.RequestRecord request;
        R.TransitionState transition;
        T.ReplayCell requestReplay;
        T.ReplayCell cancellationReplay;
        bytes32 proof;
        RH.Point requestPoint;
        RH.Point cancellationPoint;
    }

    struct Environment {
        address owner;
        address registry;
        uint256 chainId;
        address coordinator;
        address archive;
        bytes32 domain;
        uint64 revision;
        bool imported;
        Runtime.Context clock;
    }

    /// @notice The actual head immediately before this original operation29 stage.
    /// @dev The target's saved predecessor must equal the producer-derived head. The target may
    /// now be pending, aborted or executed; later mutations and unrelated receipt growth are not
    /// included in this historical proof.
    function beforeRotation(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 targetRotationHash
    ) public view returns (Head memory h) {
        Environment memory e = _environment(owner, registry, chainId, artistId);
        if (targetRotationHash == 0) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        H.Receipt memory selected = _select(e, artistId, targetRotationHash, 29);
        h = _head(e, artistId, selected);
        (R.RotationRecord memory target, T.ReplayCell memory cell, bytes32 proof) =
            _rotation(e, artistId, targetRotationHash);
        if (
            target.terms.expectedPreviousTransitionRecordHash != h.recordHash
                || (!e.imported && h.recordHash != 0 && h.ownerRevision >= cell.touchedRevision)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        h.boundaryRevision = cell.touchedRevision;
        if (e.imported) {
            h.boundaryPoint =
            Recovered.nativeFact(e.clock, 29, artistId, targetRotationHash).position.point;
            if (h.recordHash != 0 && !Runtime.before(e.clock, h.point, h.boundaryPoint)) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        }
        h.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_STAGE_PREDECESSOR_V1"),
                chainId,
                registry,
                owner,
                artistId,
                h.recordHash,
                h.operation,
                h.ownerRevision,
                h.proof,
                targetRotationHash,
                proof
            )
        );
    }

    /// @notice The actual staging head before the original estate request, without inventing a
    /// predecessor field in that request. Authority eligibility at request time remains caller-owned.
    function beforeEstate(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 requestHash
    ) public view returns (Head memory h) {
        Environment memory e = _environment(owner, registry, chainId, artistId);
        if (requestHash == 0) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        h = _head(e, artistId, _select(e, artistId, requestHash, 38));
        (Estate.RequestRecord memory r,,) =
            IStreamArtistEstateOwner(owner).estateActivationRecord(requestHash);
        _request(e, artistId, requestHash, r);
        T.ReplayCell memory cell = _replay(
            e,
            artistId,
            keccak256("identity_authority.replay.activation_request_key"),
            requestHash,
            requestHash
        );
        if (e.imported) {
            h.boundaryPoint =
            Recovered.nativeFact(e.clock, 38, artistId, requestHash).position.point;
        }
        return _boundary(
            e,
            artistId,
            h,
            cell.touchedRevision,
            keccak256("6529STREAM_ARTIST_RECOVERY_ESTATE_STAGE_PREDECESSOR_V1"),
            keccak256(abi.encode(r, cell))
        );
    }

    /// @notice The actual staging head at original notice initiation, before any notice contests
    /// or terminal. Its exact initiation revision is distinct from operation43's completion revision.
    function beforeNotice(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 noticeHash
    ) public view returns (Head memory h) {
        Environment memory e = _environment(owner, registry, chainId, artistId);
        if (noticeHash == 0) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        h = _head(e, artistId, _select(e, artistId, noticeHash, 41));
        (Dorm.Notice memory n,,) = IStreamArtistDormancyOwner(owner).dormancyRecord(noticeHash);
        if (
            n.recordHash != noticeHash || n.terms.artistId != artistId || n.incumbent == address(0)
                || n.initiatedAt == 0 || n.terms.evidenceHash == 0 || n.actionId == 0
                || n.witnessHash == 0 || n.timingRevision == 0 || n.inactivitySeconds < 365 days
                || n.noticeSeconds < 180 days
                || uint256(n.noticeEndsAt) != uint256(n.initiatedAt) + n.noticeSeconds
                || uint256(n.initiatedAt) < uint256(n.priorLivenessAt) + n.inactivitySeconds
                || noticeHash != _noticeHash(e, n)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        T.ReplayCell memory cell = _replay(
            e,
            artistId,
            keccak256("identity_authority.replay.dormancy_notice_key"),
            noticeHash,
            noticeHash
        );
        if (e.imported) {
            h.boundaryPoint = Recovered.nativeFact(e.clock, 41, artistId, noticeHash).position.point;
        }
        return _boundary(
            e,
            artistId,
            h,
            cell.touchedRevision,
            keccak256("6529STREAM_ARTIST_RECOVERY_NOTICE_STAGE_PREDECESSOR_V1"),
            keccak256(abi.encode(n, cell))
        );
    }

    /// @notice The original producer-selected head, joined to the owner's current saved head.
    /// @dev The validation ceiling is returned for optional replay bounds but never hashed.
    function current(address owner, address registry, uint256 chainId, bytes32 artistId)
        public
        view
        returns (Head memory h)
    {
        Environment memory e = _environment(owner, registry, chainId, artistId);
        h = _head(e, artistId, _select(e, artistId, 0, 0));
        if (IStreamArtistRotationReads(owner).lastArtistTransition(artistId) != h.recordHash) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        h.boundaryRevision = e.revision;
        if (e.imported) h.boundaryPoint = RH.Point(RH.originHash(e.clock.current), 2, e.revision);
        h.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_CURRENT_STAGE_V1"),
                chainId,
                registry,
                owner,
                artistId,
                h.recordHash,
                h.operation,
                h.ownerRevision,
                h.proof
            )
        );
    }

    /// @notice Exact last staging head before an admitted35, including an unresolved captured P.
    /// @dev A successful35 has two original native receipts. The caller separately proves its
    /// complete source record, consumed cause and the eligibility of each historical stage.
    function beforeRecovery(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 recoveryHash
    ) public view returns (Head memory h) {
        Environment memory e = _environment(owner, registry, chainId, artistId);
        Recovery.Record memory r =
            IStreamArtistIdentityRecoveryOwner(owner).identityRecoveryRecord(recoveryHash);
        _recovery(e, artistId, recoveryHash, r);
        V.Snapshot memory v = IStreamArtistGuardianVestingHistory(owner)
            .guardianVestingSnapshot(artistId, recoveryHash);
        if (
            v.operationId != 35 || v.transitionRecordHash != recoveryHash || v.artistId != artistId
                || v.ownerRevision == 0 || (!e.imported && v.ownerRevision > e.revision)
                || v.commitment != _vestingHash(e, v)
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        h = _head(e, artistId, _select(e, artistId, recoveryHash, 35));
        if (e.imported) {
            h.boundaryPoint =
            Recovered.nativeFact(e.clock, 35, artistId, recoveryHash).position.point;
        }
        return _boundary(
            e,
            artistId,
            h,
            v.ownerRevision,
            keccak256("6529STREAM_ARTIST_RECOVERY_ADJUDICATED_STAGE_PREDECESSOR_V2"),
            keccak256(abi.encode(r, v))
        );
    }

    /// @notice Original unexecuted request and the owner's permanent cancellation replay.
    /// @dev There is no stored estate cancellation timestamp. Cancellation may share the next
    /// rotation stage's revision because its living-action hook runs before the stage mutation.
    /// The caller supplies an authenticated boundary; changing that ceiling changes no proof.
    function cancelledEstate(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 requestHash,
        uint64 boundaryRevision
    ) public view returns (EstateFacts memory f) {
        RH.Point memory empty;
        return _cancelledEstate(
            owner, registry, chainId, artistId, requestHash, boundaryRevision, empty
        );
    }

    function cancelledEstateAt(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 requestHash,
        RH.Point memory boundary
    ) public view returns (EstateFacts memory) {
        return _cancelledEstate(
            owner, registry, chainId, artistId, requestHash, boundary.ownerRevision, boundary
        );
    }

    function _cancelledEstate(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 requestHash,
        uint64 boundaryRevision,
        RH.Point memory boundary
    ) private view returns (EstateFacts memory f) {
        Environment memory e = _environment(owner, registry, chainId, artistId);
        uint8 phase;
        Estate.ExecutionFacts memory execution;
        (f.request, phase, execution) =
            IStreamArtistEstateOwner(owner).estateActivationRecord(requestHash);
        _request(e, artistId, requestHash, f.request);
        f.transition = IStreamArtistRotationReads(owner).artistTransitionState(requestHash);
        f.requestReplay = _replay(
            e,
            artistId,
            keccak256("identity_authority.replay.activation_request_key"),
            requestHash,
            requestHash
        );
        f.cancellationReplay = _replay(
            e,
            artistId,
            keccak256("identity_authority.replay.activation_cancellation_key"),
            requestHash,
            requestHash
        );
        Estate.ExecutionFacts memory empty;
        R.TransitionState memory t = f.transition;
        if (
            phase != 3 || keccak256(abi.encode(execution)) != keccak256(abi.encode(empty))
                || t.artistId != artistId || t.recordHash != requestHash || t.phase != 3
                || t.stagedAt != f.request.requestedAt || t.contestEndsAt != f.request.noticeEndsAt
                || t.executedAt != 0 || t.postWindowEndsAt != 0
                || (t.contestedAt != 0 && t.contestedAt < t.stagedAt)
                || (!e.imported
                    && (f.requestReplay.touchedRevision >= f.cancellationReplay.touchedRevision
                        || boundaryRevision == 0
                        || boundaryRevision > e.revision
                        || f.cancellationReplay.touchedRevision > boundaryRevision))
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        if (e.imported) {
            Runtime.ReplayFact memory requested = _replayAt(
                e,
                keccak256("identity_authority.replay.activation_request_key"),
                requestHash,
                requestHash
            );
            Runtime.ReplayFact memory cancelled = _replayAt(
                e,
                keccak256("identity_authority.replay.activation_cancellation_key"),
                requestHash,
                requestHash
            );
            f.requestPoint = requested.admission.point;
            f.cancellationPoint = cancelled.admission.point;
            if (
                !Runtime.before(e.clock, f.requestPoint, f.cancellationPoint)
                    || (!Recovered.samePoint(f.cancellationPoint, boundary)
                        && !Runtime.before(e.clock, f.cancellationPoint, boundary))
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        }
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_CANCELLED_ESTATE_STAGE_V1"),
                chainId,
                registry,
                owner,
                f.request,
                t,
                f.requestReplay,
                f.cancellationReplay
            )
        );
    }

    /// @notice Immutable operation33 revision for a caller-authenticated current or saved cause.
    function compromiseRevision(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 contestHash
    ) public view returns (uint64) {
        Environment memory e = _environment(owner, registry, chainId, artistId);
        C.Record memory c =
            IStreamArtistIdentityContestOwner(owner).identityContestRecord(contestHash);
        StreamArtistHashes.Environment memory original =
            _recordEnvironment(e, artistId, 33, contestHash);
        if (
            contestHash == 0 || c.recordHash != contestHash || c.terms.artistId != artistId
                || c.contester == address(0) || c.contestedAt == 0
                || contestHash
                    != keccak256(
                        abi.encode(
                            bytes32(
                                0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb
                            ),
                            original.chainId,
                            original.registry,
                            artistId,
                            c.contester,
                            c.terms.subjectRecordHash,
                            c.terms.evidenceHash,
                            c.terms.reasonHash,
                            c.contestedAt
                        )
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        return _replay(
            e,
            artistId,
            keccak256("identity_authority.replay.contest_record_hash_and_subject_key"),
            keccak256(abi.encode(keccak256("record"), contestHash)),
            contestHash
        )
        .touchedRevision;
    }

    function compromisePoint(
        address owner,
        address registry,
        uint256 chainId,
        bytes32 artistId,
        bytes32 contestHash
    ) public view returns (RH.Point memory point) {
        Environment memory e = _environment(owner, registry, chainId, artistId);
        uint64 revision = compromiseRevision(owner, registry, chainId, artistId, contestHash);
        if (!e.imported) return point;
        point = Recovered.nativeFact(e.clock, 33, artistId, contestHash).position.point;
        Runtime.ReplayFact memory replay = _replayAt(
            e,
            keccak256("identity_authority.replay.contest_record_hash_and_subject_key"),
            keccak256(abi.encode(keccak256("record"), contestHash)),
            contestHash
        );
        if (point.ownerRevision != revision || !Recovered.samePoint(point, replay.admission.point))
        {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }

    function _select(Environment memory e, bytes32 artistId, bytes32 target, uint16 targetOperation)
        private
        view
        returns (H.Receipt memory selected)
    {
        IStreamArtistNativeReceipts source = IStreamArtistNativeReceipts(e.owner);
        uint256 count =
            e.imported ? Runtime.logicalCount(e.clock) : source.artistNativeReceiptCount();
        for (uint256 i; i < count; ++i) {
            H.Receipt memory row = _row(e, i);
            if (row.artistId != artistId) continue;
            if (target != 0 && row.operation == targetOperation && row.recordHash == target) {
                if (row.collectionId != 0) {
                    revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
                }
                return selected;
            }
            if (row.operation == 35) {
                Recovery.Record memory r = IStreamArtistIdentityRecoveryOwner(e.owner)
                    .identityRecoveryRecord(row.recordHash);
                _recovery(e, artistId, row.recordHash, r);
                if (++i >= count) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
                H.Receipt memory secondary = _row(e, i);
                if (
                    secondary.operation != 35 || secondary.artistId != artistId
                        || secondary.collectionId != 0
                        || secondary.recordHash != r.fields.supersededRecordsHash
                ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            } else if (row.operation != 29 && row.operation != 38 && row.operation != 43) {
                continue;
            }
            if (row.collectionId != 0 || row.recordHash == 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
            selected = row;
        }
        if (target != 0) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _boundary(
        Environment memory e,
        bytes32 artistId,
        Head memory h,
        uint64 revision,
        bytes32 tag,
        bytes32 targetProof
    ) private view returns (Head memory) {
        if (
            h.recordHash != 0
                && (e.imported
                        ? !Runtime.before(e.clock, h.point, h.boundaryPoint)
                        : h.ownerRevision >= revision)
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        h.boundaryRevision = revision;
        h.proof = keccak256(
            abi.encode(
                tag,
                e.chainId,
                e.registry,
                e.owner,
                artistId,
                h.recordHash,
                h.operation,
                h.ownerRevision,
                h.proof,
                targetProof
            )
        );
        return h;
    }

    function _head(Environment memory e, bytes32 artistId, H.Receipt memory row)
        private
        view
        returns (Head memory h)
    {
        h.recordHash = row.recordHash;
        h.operation = row.operation;
        if (h.recordHash == 0) return h;
        if (e.imported) {
            h.point =
            Recovered.nativeFact(e.clock, row.operation, artistId, row.recordHash).position.point;
        }
        if (row.operation == 29) {
            (, T.ReplayCell memory cell, bytes32 proof) = _rotation(e, artistId, row.recordHash);
            h.ownerRevision = cell.touchedRevision;
            h.proof = proof;
        } else if (row.operation == 38) {
            (Estate.RequestRecord memory r,,) =
                IStreamArtistEstateOwner(e.owner).estateActivationRecord(row.recordHash);
            _request(e, artistId, row.recordHash, r);
            T.ReplayCell memory cell = _replay(
                e,
                artistId,
                keccak256("identity_authority.replay.activation_request_key"),
                row.recordHash,
                row.recordHash
            );
            h.ownerRevision = cell.touchedRevision;
            h.proof = keccak256(abi.encode(row, r, cell));
        } else {
            V.Snapshot memory v = IStreamArtistGuardianVestingHistory(e.owner)
                .guardianVestingSnapshot(artistId, row.recordHash);
            if (
                (row.operation != 35 && row.operation != 43) || v.artistId != artistId
                    || v.transitionRecordHash != row.recordHash || v.operationId != row.operation
                    || v.ownerRevision == 0 || (!e.imported && v.ownerRevision > e.revision)
                    || v.executedAt == 0 || v.commitment == 0 || v.commitment != _vestingHash(e, v)
            ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            R.TransitionState memory t =
                IStreamArtistRotationReads(e.owner).artistTransitionState(row.recordHash);
            if (
                t.artistId != artistId || t.recordHash != row.recordHash || t.phase != 2
                    || t.executedAt != v.executedAt
            ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            h.ownerRevision = v.ownerRevision;
            h.proof = keccak256(abi.encode(row, v));
        }
        if (e.imported && h.point.ownerRevision != h.ownerRevision) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }

    function _rotation(Environment memory e, bytes32 artistId, bytes32 hash)
        private
        view
        returns (R.RotationRecord memory r, T.ReplayCell memory cell, bytes32 proof)
    {
        r = IStreamArtistRotationReads(e.owner).rotationRecord(hash);
        R.TransitionState memory t = r.transition;
        if (
            hash == 0 || r.recordHash != hash || r.terms.artistId != artistId
                || t.artistId != artistId || t.recordHash != hash || t.stagedAt == 0
                || r.terms.oldAddress == address(0) || r.terms.newAddress == address(0)
                || r.terms.oldAddress == r.terms.newAddress
                || uint256(t.contestEndsAt) != uint256(t.stagedAt) + r.effectiveWindow
                || hash
                    != StreamArtistRotationHashes.rotationRecord(
                        _recordEnvironment(e, artistId, 29, hash),
                        r.terms,
                        r.oldNonce,
                        t.stagedAt,
                        t.contestEndsAt
                    )
                || keccak256(abi.encode(t))
                    != keccak256(
                        abi.encode(IStreamArtistRotationReads(e.owner).artistTransitionState(hash))
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        cell = _replay(
            e,
            artistId,
            keccak256("identity_authority.replay.rotation_key"),
            keccak256(abi.encode(artistId, hash)),
            hash
        );
        if (e.imported) {
            Runtime.ReplayFact memory admitted = _replayAt(
                e,
                keccak256("identity_authority.replay.rotation_key"),
                keccak256(abi.encode(artistId, hash)),
                hash
            );
            if (!Recovered.samePoint(
                    admitted.admission.point,
                    Recovered.nativeFact(e.clock, 29, artistId, hash).position.point
                )) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
        }
        proof = keccak256(
            abi.encode(
                r.recordHash,
                r.terms,
                r.guardianSetRecordHash,
                r.approvalThreshold,
                r.oldNonce,
                r.newNonce,
                r.effectiveWindow,
                r.standingTail,
                r.timingRevision,
                t.stagedAt,
                t.contestEndsAt,
                cell
            )
        );
    }

    function _request(
        Environment memory e,
        bytes32 artistId,
        bytes32 hash,
        Estate.RequestRecord memory r
    ) private view {
        if (
            hash == 0 || r.recordHash != hash || r.terms.artistId != artistId
                || r.incumbent == address(0) || r.terms.successor == address(0)
                || r.terms.successor == r.incumbent || r.terms.evidenceHash == 0
                || r.requestedAt == 0 || r.noticeRevision == 0 || r.rotationTimingRevision == 0
                || uint256(r.noticeEndsAt) != uint256(r.requestedAt) + r.noticeSeconds
                || r.designationRecordHash == 0
                || r.terms.expectedDesignationRecordHash != r.designationRecordHash
                || r.terms.selectedCoverageHash == 0 || r.envelopeHash == 0
                || hash
                    != StreamArtistEstateHashes.record(
                        _recordEnvironment(e, artistId, 38, hash),
                        r.terms,
                        r.authorization.nonce,
                        r.requestedAt,
                        r.noticeEndsAt
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _recovery(
        Environment memory e,
        bytes32 artistId,
        bytes32 hash,
        Recovery.Record memory r
    ) private view {
        StreamArtistHashes.Environment memory original = _recordEnvironment(e, artistId, 35, hash);
        if (
            hash == 0 || r.recordHash != hash || r.fields.artistId != artistId
                || hash
                    != StreamArtistIdentityRecoveryHashes.record(
                        original.chainId, original.registry, r.fields
                    )
                || r.fields.supersededRecordsHash
                    != StreamArtistIdentityRecoveryHashes.supersession(
                        r.terms.supersededRecordHashes
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _environment(address owner, address registry, uint256 chainId, bytes32 artistId)
        private
        view
        returns (Environment memory e)
    {
        if (
            owner.code.length == 0 || registry == address(0) || artistId == 0
                || chainId != block.chainid
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        IStreamArtistOwner source = IStreamArtistOwner(owner);
        e.owner = owner;
        e.registry = registry;
        e.chainId = chainId;
        e.coordinator = source.operationCoordinator();
        e.archive = source.archiveV2();
        e.domain = source.domainId();
        e.revision = source.ownerStateSnapshotV2().revision;
        e.imported = Recovered.active(owner);
        if (e.imported) e.clock = Recovered.load(owner, registry, chainId);
        if (
            source.artistRegistry() != registry || source.deploymentChainId() != chainId
                || e.domain != keccak256("domain:identity_authority") || e.coordinator == address(0)
                || e.archive == address(0)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _replay(
        Environment memory e,
        bytes32 artistId,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment
    ) private view returns (T.ReplayCell memory cell) {
        if (e.imported) return _replayAt(e, surface, scope, commitment).cell;
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                e.coordinator,
                e.archive,
                e.owner,
                e.domain,
                surface,
                scope
            )
        );
        cell = IStreamArtistOwner(e.owner).replayCell(key);
        if (
            cell.commitment != commitment || cell.kind != 1 || cell.status != 2
                || cell.touchedRevision == 0 || cell.touchedRevision > e.revision
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _replayAt(Environment memory e, bytes32 surface, bytes32 scope, bytes32 commitment)
        private
        view
        returns (Runtime.ReplayFact memory f)
    {
        f = Runtime.replay(e.clock, RH.originHash(e.clock.current), surface, scope);
        if (
            commitment == 0 || f.cell.commitment != commitment || f.cell.kind != 1
                || f.cell.status != 2
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(commitment);
        }
    }

    function _row(Environment memory e, uint256 index) private view returns (H.Receipt memory) {
        return e.imported
            ? Runtime.receiptAt(e.clock, index).receipt
            : IStreamArtistNativeReceipts(e.owner).artistNativeReceiptAt(index);
    }

    function _recordEnvironment(
        Environment memory e,
        bytes32 artistId,
        uint16 operation,
        bytes32 record
    ) private view returns (StreamArtistHashes.Environment memory) {
        if (!e.imported) return _hashEnvironment(e);
        return
            Recovered.hashes(Recovered.nativeFact(e.clock, operation, artistId, record).environment);
    }

    function _hashEnvironment(Environment memory e)
        private
        pure
        returns (StreamArtistHashes.Environment memory)
    {
        return StreamArtistHashes.Environment(e.chainId, e.registry, address(0), address(0));
    }

    function _vestingHash(Environment memory e, V.Snapshot memory v)
        private
        view
        returns (bytes32)
    {
        if (e.imported) {
            Runtime.OriginFact memory origin = Recovered.vesting(e.clock, v);
            return Recovered.vestingHash(origin.environment, v);
        }
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

    function _noticeHash(Environment memory e, Dorm.Notice memory n)
        private
        view
        returns (bytes32)
    {
        address originalOwner = e.owner;
        StreamArtistHashes.Environment memory original = _hashEnvironment(e);
        if (e.imported) {
            Runtime.ReceiptFact memory row =
                Recovered.nativeFact(e.clock, 41, n.terms.artistId, n.recordHash);
            original = Recovered.hashes(row.environment);
            originalOwner = row.environment.owners[2];
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_NOTICE_V1"),
                original.chainId,
                original.registry,
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
}
