// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistDormancyState as Dormancy } from "./StreamArtistDormancyState.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveryStagingHistory as Stages
} from "./StreamArtistRecoveryStagingHistory.sol";
import { StreamArtistLivingRecoveryReads as Admitted } from "./StreamArtistLivingRecoveryReads.sol";
import {
    StreamArtistCurrentCompromiseReads as Current
} from "./StreamArtistCurrentCompromiseReads.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistNativeReceipts,
    StreamArtistHistoryTypes as Native
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";

/// @notice Original unresolved notice causes and their exact cancellation provenance.
/// @dev A recovered new side may cancel only through an authenticated original35 in the same
/// owner revision. Ordinary cancellation still requires the original incumbent for class1.
library StreamArtistCurrentNoticeRecoveryReads {
    struct Facts {
        Dorm.Notice notice;
        Dorm.Terminal cancellation;
        uint8 phase;
        uint256 activity;
        bytes32 proof;
    }

    function read(Dormancy.State storage s, Hashes.Environment memory e, D.Cause memory current)
        public
        view
        returns (Facts memory f)
    {
        f = readCause(e, current);
        bytes32 id = current.facts.artistId;
        if (
            s.latestNotice[id] != f.notice.recordHash
                || s.causeNotice[current.causeHash] != f.notice.recordHash
                || s.activity[id] != f.activity || s.phases[f.notice.recordHash] != f.phase
                || s.terminalForNotice[f.notice.recordHash] != f.cancellation.recordHash
                || keccak256(abi.encode(s.notices[f.notice.recordHash]))
                    != keccak256(abi.encode(f.notice))
                || keccak256(abi.encode(s.terminals[f.cancellation.recordHash]))
                    != keccak256(abi.encode(f.cancellation))
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
        (bytes32 latest, uint8 phase, bytes32 terminal) =
            IStreamArtistDormancyOwner(address(this)).dormancyNotice(id);
        if (
            latest != f.notice.recordHash || phase != f.phase
                || terminal != f.cancellation.recordHash
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
        T.Identity memory principal = IStreamArtistIdentityOwner(address(this)).identity(id);
        if (
            principal.authorityClass != 1 || principal.status != 4
                || principal.authorityAddress != f.notice.incumbent
                || (phase == 1
                        ? principal.lastAuthorityActionAt != f.notice.priorLivenessAt
                        : principal.lastAuthorityActionAt < f.cancellation.observedAt)
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
    }

    /// @dev The caller authenticates the original cause/Contest and its complete authority ancestry.
    /// Historical reads never compare a past notice's activity count with today's live counter.
    function readCause(Hashes.Environment memory e, D.Cause memory cause)
        public
        view
        returns (Facts memory f)
    {
        bytes32 id = cause.facts.artistId;
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        if (
            e.chainId != block.chainid || e.registry == address(0)
                || owner.deploymentChainId() != e.chainId || owner.artistRegistry() != e.registry
                || id == 0 || cause.causeHash == 0 || cause.facts.kind != 1
                || cause.facts.authorityClass != 1 || cause.facts.priorStatus != 2
                || cause.facts.pendingTransitionHash != 0
                || keccak256(abi.encode(cause))
                    != keccak256(
                        abi.encode(
                            IStreamArtistIdentityDismissalOwner(address(this))
                                .identityContestCause(cause.causeHash)
                        )
                    )
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
        (bytes32 noticeHash, uint8 phase, bytes32 terminal) =
            IStreamArtistDormancyOwner(address(this)).dormancyResolutionState(id, cause.causeHash);
        (f.notice, f.phase, f.cancellation) =
            IStreamArtistDormancyOwner(address(this)).dormancyRecord(noticeHash);
        Dorm.Notice memory n = f.notice;
        if (
            noticeHash == 0 || n.recordHash != noticeHash || n.terms.artistId != id
                || n.incumbent != cause.facts.incumbent || n.incumbent == address(0)
                || n.terms.evidenceHash == 0 || bytes(n.terms.reasonURI).length == 0
                || bytes(n.terms.reasonURI).length > 2048 || n.initiatedAt == 0
                || n.inactivitySeconds < 365 days || n.noticeSeconds < 180 days
                || n.timingRevision == 0 || n.actionId == 0 || n.witnessHash == 0
                || uint256(n.noticeEndsAt) != uint256(n.initiatedAt) + n.noticeSeconds
                || uint256(n.initiatedAt) < uint256(n.priorLivenessAt) + n.inactivitySeconds
                || n.recordHash != _noticeHash(e, n) || cause.facts.enteredAt < n.initiatedAt
                || cause.facts.enteredAt > block.timestamp || (phase != 1 && phase != 2)
                || f.phase != phase || f.cancellation.recordHash != terminal
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
        T.ReplayCell memory initiation = _replay(
            e,
            id,
            keccak256("identity_authority.replay.dormancy_notice_key"),
            noticeHash,
            noticeHash
        );
        (uint256 noticeIndex, bytes32 nativeNotice) = _native(id, noticeHash, 41);
        uint64 enteredRevision = Stages.compromiseRevision(
            address(this), e.registry, e.chainId, id, cause.facts.referenceHash
        );
        (uint256 causeIndex, bytes32 nativeCause) = _native(id, cause.causeHash, 33);
        if (
            (Imported.commitment() == 0 && enteredRevision <= initiation.touchedRevision)
                || causeIndex <= noticeIndex
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
        if (Imported.commitment() != 0) {
            _ordered(e, id, 41, noticeHash, 33, cause.causeHash);
            Stages.compromisePoint(
                address(this), e.registry, e.chainId, id, cause.facts.referenceHash
            );
        }
        bytes32 cancellationProof;
        f.activity = n.priorActivity;
        if (phase == 1) {
            Dorm.Terminal memory empty;
            if (keccak256(abi.encode(f.cancellation)) != keccak256(abi.encode(empty))) {
                revert I.UnsupportedIdentityRecoveryProfile(id);
            }
        } else {
            if (n.priorActivity == type(uint256).max) {
                revert I.UnsupportedIdentityRecoveryProfile(id);
            }
            f.activity = n.priorActivity + 1;
            cancellationProof = _cancellation(e, f, cause, enteredRevision, causeIndex);
        }
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_NOTICE_RECOVERY_SOURCE_V1"),
                e.chainId,
                e.registry,
                address(this),
                cause.causeHash,
                n,
                phase,
                f.cancellation,
                f.activity,
                initiation,
                nativeNotice,
                enteredRevision,
                nativeCause,
                cancellationProof
            )
        );
    }

    /// @notice Exact original ordering also distinguishes same-timestamp notice episodes.
    function dismissalProof(
        Hashes.Environment memory e,
        Facts memory f,
        D.Cause memory cause,
        D.Record memory dismissal
    ) public view returns (bytes32) {
        bytes32 id = cause.facts.artistId;
        T.ReplayCell memory resolved = _replay(
            e,
            id,
            keccak256("identity_authority.replay.contest_resolution"),
            keccak256(abi.encode(id, cause.causeHash)),
            dismissal.recordHash
        );
        T.ReplayCell memory initiated = _replay(
            e,
            id,
            keccak256("identity_authority.replay.dormancy_notice_key"),
            f.notice.recordHash,
            f.notice.recordHash
        );
        uint64 entered = Stages.compromiseRevision(
            address(this), e.registry, e.chainId, id, cause.facts.referenceHash
        );
        if (
            Imported.commitment() == 0
                && (entered <= initiated.touchedRevision || resolved.touchedRevision <= entered)
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
        if (Imported.commitment() != 0) {
            _ordered(e, id, 41, f.notice.recordHash, 33, cause.causeHash);
            _ordered(e, id, 33, cause.causeHash, 58, dismissal.recordHash);
        }
        T.ReplayCell memory cancelled;
        if (f.phase == 2) {
            cancelled = _replay(
                e,
                id,
                keccak256("identity_authority.replay.dormancy_cancellation_key"),
                f.notice.recordHash,
                f.cancellation.recordHash
            );
            if (Imported.commitment() != 0) {
                _ordered(e, id, 58, dismissal.recordHash, 42, f.cancellation.recordHash);
            }
            if (Imported.commitment() == 0 && resolved.touchedRevision >= cancelled.touchedRevision)
            {
                revert I.UnsupportedIdentityRecoveryProfile(id);
            }
        }
        return keccak256(abi.encode(initiated, entered, resolved, cancelled));
    }

    function _cancellation(
        Hashes.Environment memory e,
        Facts memory f,
        D.Cause memory cause,
        uint64 noticeRevision,
        uint256 noticeIndex
    ) private view returns (bytes32) {
        bytes32 id = cause.facts.artistId;
        Dorm.Terminal memory t = f.cancellation;
        Dorm.Terminal memory canonical;
        canonical.noticeHash = f.notice.recordHash;
        canonical.actor = t.actor;
        canonical.authorityClass = t.authorityClass;
        canonical.observedAt = t.observedAt;
        Hashes.Environment memory original;
        address originalOwner;
        (original, originalOwner) = _original(e, 42, id, t.recordHash);
        canonical.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"),
                original.chainId,
                original.registry,
                originalOwner,
                canonical,
                f.activity
            )
        );
        if (
            t.actor == address(0)
                || (t.authorityClass != 1 && t.authorityClass != 2 && t.authorityClass != 3)
                || t.observedAt < cause.facts.enteredAt || t.observedAt > block.timestamp
                || keccak256(abi.encode(t)) != keccak256(abi.encode(canonical))
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
        T.ReplayCell memory cancellation = _replay(
            e,
            id,
            keccak256("identity_authority.replay.dormancy_cancellation_key"),
            f.notice.recordHash,
            t.recordHash
        );
        (uint256 index, bytes32 nativeProof) = _native(id, t.recordHash, 42);
        if (
            (Imported.commitment() == 0 && cancellation.touchedRevision <= noticeRevision)
                || index <= noticeIndex
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
        if (Imported.commitment() != 0) _ordered(e, id, 33, cause.causeHash, 42, t.recordHash);
        bytes32 recovered;
        if (t.authorityClass == 1 && t.actor != f.notice.incumbent) {
            recovered = _recoveredCancellation(e, f, cancellation, index);
        }
        return keccak256(abi.encode(cancellation, nativeProof, recovered));
    }

    function _recoveredCancellation(
        Hashes.Environment memory e,
        Facts memory f,
        T.ReplayCell memory cancellation,
        uint256 index
    ) private view returns (bytes32) {
        bytes32 id = f.notice.terms.artistId;
        IStreamArtistNativeReceipts journal = IStreamArtistNativeReceipts(address(this));
        Runtime.Context memory clock;
        bool imported = Imported.commitment() != 0;
        if (imported) clock = Recovered.load(address(this), e.registry, e.chainId);
        if (
            index + 2
                >= (imported ? Runtime.logicalCount(clock) : journal.artistNativeReceiptCount())
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
        Native.Receipt memory primary = imported
            ? Runtime.receiptAt(clock, index + 1).receipt
            : journal.artistNativeReceiptAt(index + 1);
        Native.Receipt memory secondary = imported
            ? Runtime.receiptAt(clock, index + 2).receipt
            : journal.artistNativeReceiptAt(index + 2);
        if (imported) {
            Runtime.ReceiptFact memory cancelled = Runtime.receiptAt(clock, index);
            Runtime.ReceiptFact memory first = Runtime.receiptAt(clock, index + 1);
            Runtime.ReceiptFact memory second = Runtime.receiptAt(clock, index + 2);
            if (
                !Recovered.samePoint(cancelled.position.point, first.position.point)
                    || !Recovered.samePoint(first.position.point, second.position.point)
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(id);
            }
        }
        if (
            primary.operation != 35 || secondary.operation != 35 || primary.artistId != id
                || secondary.artistId != id || primary.collectionId != 0
                || secondary.collectionId != 0
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
        Admitted.Facts memory r =
            Admitted.readFamily(address(this), e.registry, e.chainId, id, primary.recordHash);
        D.Cause memory c = IStreamArtistIdentityDismissalOwner(address(this))
            .identityContestCause(r.record.terms.expectedCauseHash);
        Current.Facts memory capture = Current.readConsumedNotice(
            address(this),
            e.registry,
            e.chainId,
            c,
            IStreamArtistRotationReads(address(this))
                .artistTransitionState(c.facts.executedTransitionHash)
        );
        (bytes32 noticeHash, uint8 phase, bytes32 terminal) =
            IStreamArtistDormancyOwner(address(this)).dormancyResolutionState(id, c.causeHash);
        if (
            r.record.fields.oldAddress != f.notice.incumbent
                || r.record.fields.newAddress != f.cancellation.actor
                || r.record.fields.vestedAuthorityClass != 1
                || r.record.fields.recoveredAt != f.cancellation.observedAt
                || r.vesting.ownerRevision != cancellation.touchedRevision
                || secondary.recordHash != r.record.fields.supersededRecordsHash
                || c.facts.kind != 1 || c.facts.priorStatus != 2 || c.facts.authorityClass != 1
                || c.facts.pendingTransitionHash != 0 || c.facts.incumbent != f.notice.incumbent
                || c.facts.enteredAt < f.notice.initiatedAt
                || c.facts.enteredAt > f.cancellation.observedAt
                || c.facts.executedTransitionHash != r.vesting.previousTransitionRecordHash
                || c.facts.previousResolutionHash != r.record.terms.expectedResolutionHash
                || noticeHash != f.notice.recordHash || phase != 2
                || terminal != f.cancellation.recordHash
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
        T.ReplayCell memory consumed = _replay(
            e,
            id,
            keccak256("identity_authority.replay.contest_resolution"),
            keccak256(abi.encode(id, c.causeHash)),
            r.record.recordHash
        );
        if (consumed.touchedRevision != cancellation.touchedRevision) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
        return keccak256(abi.encode(r.proof, c, capture.proof, consumed, primary, secondary));
    }

    function _noticeHash(Hashes.Environment memory e, Dorm.Notice memory n)
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

    function _native(bytes32 id, bytes32 hash, uint16 operation)
        private
        view
        returns (uint256 index, bytes32 proof)
    {
        if (Imported.commitment() != 0) {
            IStreamArtistOwner source = IStreamArtistOwner(address(this));
            Runtime.ReceiptFact memory row = Recovered.nativeFact(
                Recovered.load(address(this), source.artistRegistry(), source.deploymentChainId()),
                operation,
                id,
                hash
            );
            return (row.logicalIndex, keccak256(abi.encode(row)));
        }
        IStreamArtistNativeReceipts journal = IStreamArtistNativeReceipts(address(this));
        uint256 count = journal.artistNativeReceiptCount();
        bool found;
        for (uint256 i; i < count; ++i) {
            Native.Receipt memory row = journal.artistNativeReceiptAt(i);
            if (row.artistId != id || row.recordHash != hash || row.operation != operation) {
                continue;
            }
            if (found || row.collectionId != 0) revert I.UnsupportedIdentityRecoveryProfile(id);
            found = true;
            index = i;
            proof = keccak256(abi.encode(i, row));
        }
        if (!found) revert I.UnsupportedIdentityRecoveryProfile(id);
    }

    function _replay(
        Hashes.Environment memory e,
        bytes32 id,
        bytes32 surface,
        bytes32 scope,
        bytes32 record
    ) private view returns (T.ReplayCell memory cell) {
        if (Imported.commitment() != 0) {
            Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
            Runtime.ReplayFact memory replay =
                Runtime.replay(clock, RH.originHash(clock.current), surface, scope);
            uint16 operation = surface == keccak256("identity_authority.replay.dormancy_notice_key")
                ? 41
                : surface == keccak256("identity_authority.replay.dormancy_cancellation_key")
                    ? 42
                    : IStreamArtistIdentityRecoveryOwner(address(this))
                        .identityRecoveryRecord(record)
                        .recordHash == record
                        ? 35
                        : 58;
            Runtime.ReceiptFact memory row = Recovered.nativeFact(clock, operation, id, record);
            if (
                replay.cell.commitment != record || replay.cell.status != 2 || replay.cell.kind != 1
                    || !Recovered.samePoint(replay.admission.point, row.position.point)
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(id);
            }
            return replay.cell;
        }
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                owner.operationCoordinator(),
                owner.archiveV2(),
                address(this),
                owner.domainId(),
                surface,
                scope
            )
        );
        cell = owner.replayCell(key);
        if (
            cell.commitment != record || cell.status != 2 || cell.kind != 1
                || cell.touchedRevision == 0
                || cell.touchedRevision > owner.ownerStateSnapshotV2().revision
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(id);
        }
    }

    function _original(
        Hashes.Environment memory e,
        uint16 operation,
        bytes32 artistId,
        bytes32 record
    ) private view returns (Hashes.Environment memory, address) {
        if (Imported.commitment() == 0) return (e, address(this));
        Runtime.ReceiptFact memory row = Recovered.nativeFact(
            Recovered.load(address(this), e.registry, e.chainId), operation, artistId, record
        );
        return (Recovered.hashes(row.environment), row.environment.owners[2]);
    }

    function _ordered(
        Hashes.Environment memory e,
        bytes32 artistId,
        uint16 earlierOperation,
        bytes32 earlier,
        uint16 laterOperation,
        bytes32 later
    ) private view {
        Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
        Runtime.ReceiptFact memory first =
            Recovered.nativeFact(clock, earlierOperation, artistId, earlier);
        Runtime.ReceiptFact memory second =
            Recovered.nativeFact(clock, laterOperation, artistId, later);
        if (!Runtime.before(clock, first.position.point, second.position.point)) {
            revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }
}
