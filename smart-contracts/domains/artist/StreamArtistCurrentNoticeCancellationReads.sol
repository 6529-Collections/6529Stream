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

import {
    StreamArtistCurrentNoticeRecoveryReads as Shape
} from "./StreamArtistCurrentNoticeRecoveryReads.sol";

/// @notice Exact original complete read proof in the unchanged library caller context.
library StreamArtistCurrentNoticeCancellationReads {
    function recoveredCancellation(
        Hashes.Environment memory e,
        Shape.Facts memory f,
        T.ReplayCell memory cancellation,
        uint256 index
    ) public view returns (bytes32) {
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
}
