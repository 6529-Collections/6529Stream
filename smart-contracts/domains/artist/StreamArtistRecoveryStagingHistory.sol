// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveryStagingHeadHistory as Fixed } from "./StreamArtistRecoveryStagingHeadHistory.sol";
import { StreamArtistRecoveryStagingEstateHistory as Worker } from "./StreamArtistRecoveryStagingEstateHistory.sol";

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
        H.Receipt memory selected = Fixed._select(e, artistId, targetRotationHash, 29);
        h = Fixed._head(e, artistId, selected);
        (R.RotationRecord memory target, T.ReplayCell memory cell, bytes32 proof) =
            Fixed._rotation(e, artistId, targetRotationHash);
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
        h = Fixed._head(e, artistId, Fixed._select(e, artistId, requestHash, 38));
        (Estate.RequestRecord memory r,,) =
            IStreamArtistEstateOwner(owner).estateActivationRecord(requestHash);
        Fixed._request(e, artistId, requestHash, r);
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
        h = Fixed._head(e, artistId, Fixed._select(e, artistId, noticeHash, 41));
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
        h = Fixed._head(e, artistId, Fixed._select(e, artistId, 0, 0));
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
        h = Fixed._head(e, artistId, Fixed._select(e, artistId, recoveryHash, 35));
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
        return Worker._cancelledEstate(owner, registry, chainId, artistId, requestHash, boundaryRevision, boundary);
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
