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
import {
    StreamArtistCurrentNoticeCauseReads as CauseReads
} from "./StreamArtistCurrentNoticeCauseReads.sol";

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
        return CauseReads.readCause(e, cause);
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
