// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistPayoutOwner
} from "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    IStreamArtistRecoveryPayoutOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";
import { StreamArtistLivingRecoveryReads as Living } from "./StreamArtistLivingRecoveryReads.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    IStreamArtistRecoveredPayoutHydration
} from "../../interfaces/stream/artist/IStreamArtistRecoveredPayoutHydration.sol";

/// @notice Fixed original and recovered Payout continuation admission.
/// @dev Complete literal reader bodies retain separate Identity/Payout clocks, original
/// replay consumption and proof bytes. This library owns no state or routing choice.
library StreamArtistRecoveryRewindPayoutContinuations {
    function payoutAt(
        W.EnvironmentV3 memory e,
        W.PayoutOriginalV3 memory r,
        Runtime.ReplayFact memory nonce,
        Runtime.ReceiptFact memory occurrence
    ) public view returns (bytes32) {
        IStreamArtistRecoveryPayoutOwnerV3 owner = IStreamArtistRecoveryPayoutOwnerV3(e.payoutOwner);
        bytes32 head = owner.payoutDesignationRecoveryContinuationV3(r.recordHash);
        if (head == 0) return 0;
        Runtime.Context memory payoutClock = Runtime.load(e, 5);
        Runtime.Context memory identityClock = Runtime.load(e, 2);
        Runtime.ReceiptFact memory actual = Runtime.receiptAt(payoutClock, occurrence.logicalIndex);
        if (
            keccak256(abi.encode(actual)) != keccak256(abi.encode(occurrence))
                || occurrence.receipt.operation != 18
                || occurrence.receipt.artistId != r.terms.artistId
                || occurrence.receipt.recordHash != r.recordHash
        ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        Runtime.OriginFact memory origin = Runtime.auxiliary(
            payoutClock, keccak256("payout_lifecycle.hydration.continuation_v3"), head
        );
        W.PayoutContinuationV3 memory c = owner.payoutRecoveryContinuationV3(head);
        T.Payout memory empty;
        if (
            c.artistId != r.terms.artistId || c.continuationHash != head || c.manifestHash == 0
                || c.payoutOwnerRevision != origin.point.ownerRevision
                || W.payoutContinuationHash(Runtime.rewindEnvironment(origin.environment), c)
                    != head || c.stable.recordHash != r.terms.previousDesignationRecordHash
                || c.stable.account == r.terms.payoutAccount
                || keccak256(abi.encode(c.candidate)) != keccak256(abi.encode(empty))
                || !Runtime.before(payoutClock, origin.point, occurrence.position.point)
        ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        if (c.stable.recordHash == 0) {
            if (c.stable.account != address(0)) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        } else {
            T.PayoutDesignation memory stable =
                IStreamArtistPayoutOwner(e.payoutOwner).designationRecord(c.stable.recordHash);
            if (
                stable.artistId != c.artistId || stable.payoutAccount == address(0)
                    || stable.payoutAccount != c.stable.account
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        }
        Runtime.ReceiptFact memory creation =
            Recovered.nativeFact(identityClock, 35, c.artistId, c.recoveryRecordHash);
        if (
            creation.position.point.environmentHash != origin.point.environmentHash
                || creation.position.point.ownerRevision != c.identityOwnerRevision
                || !Runtime.before(identityClock, creation.position.point, nonce.admission.point)
        ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        bytes32 recovered = _recovery(
            e,
            c.artistId,
            c.recoveryRecordHash,
            c.actionId,
            c.planCommitment,
            c.identityOwnerRevision
        );
        W.EvidenceStateV3 memory evidence = IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner)
            .identityRecoveryEvidenceStateV3(c.artistId, c.actionId);
        Runtime.ReplayFact memory applied = Runtime.replay(
            payoutClock,
            origin.point.environmentHash,
            keccak256("payout_lifecycle.replay.recovery_rewind"),
            c.recoveryRecordHash
        );
        Runtime.ReplayFact memory admitted = Runtime.replay(
            payoutClock,
            occurrence.position.point.environmentHash,
            keccak256("payout_lifecycle.replay.recovery_continuation"),
            keccak256(abi.encode(c.artistId, head, r.terms.previousDesignationRecordHash))
        );
        if (
            evidence.manifestHash != c.manifestHash || applied.cell.kind != 1
                || applied.cell.status != 2 || applied.cell.commitment != c.planCommitment
                || !Recovered.samePoint(applied.admission.point, origin.point)
                || IStreamArtistRecoveredPayoutHydration(e.payoutOwner)
                        .payoutRecoveryAppliedCommitmentV3(c.recoveryRecordHash) == 0
                || admitted.cell.kind != 1 || admitted.cell.status != 2
                || admitted.cell.commitment != r.recordHash
                || !Recovered.samePoint(admitted.admission.point, occurrence.position.point)
        ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_PAYOUT_CONTINUATION_V1"),
                c,
                recovered,
                evidence,
                origin,
                applied,
                admitted,
                occurrence
            )
        );
    }

    function payout(
        W.EnvironmentV3 memory e,
        W.PayoutOriginalV3 memory r,
        T.ReplayCell memory nonce
    ) public view returns (bytes32) {
        IStreamArtistRecoveryPayoutOwnerV3 owner = IStreamArtistRecoveryPayoutOwnerV3(e.payoutOwner);
        bytes32 head = owner.payoutDesignationRecoveryContinuationV3(r.recordHash);
        if (head == 0) return 0;
        W.PayoutContinuationV3 memory c = owner.payoutRecoveryContinuationV3(head);
        T.Payout memory empty;
        if (
            c.artistId != r.terms.artistId || c.continuationHash != head
                || W.payoutContinuationHash(e, c) != head || c.manifestHash == 0
                || c.stable.recordHash != r.terms.previousDesignationRecordHash
                || c.stable.account == r.terms.payoutAccount
                || keccak256(abi.encode(c.candidate)) != keccak256(abi.encode(empty))
                || c.identityOwnerRevision >= nonce.touchedRevision || c.payoutOwnerRevision == 0
        ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        if (c.stable.recordHash == 0) {
            if (c.stable.account != address(0)) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        } else {
            T.PayoutDesignation memory stable =
                IStreamArtistPayoutOwner(e.payoutOwner).designationRecord(c.stable.recordHash);
            if (
                stable.artistId != c.artistId || stable.payoutAccount == address(0)
                    || stable.payoutAccount != c.stable.account
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        }
        bytes32 recovered = _recovery(
            e,
            c.artistId,
            c.recoveryRecordHash,
            c.actionId,
            c.planCommitment,
            c.identityOwnerRevision
        );
        W.EvidenceStateV3 memory evidence = IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner)
            .identityRecoveryEvidenceStateV3(c.artistId, c.actionId);
        if (evidence.manifestHash != c.manifestHash) {
            revert W.InvalidRecoveryRewindRecord(r.recordHash);
        }
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                e.coordinator,
                e.archive,
                e.payoutOwner,
                keccak256("domain:payout_lifecycle"),
                keccak256("payout_lifecycle.replay.recovery_continuation"),
                keccak256(abi.encode(c.artistId, head, r.terms.previousDesignationRecordHash))
            )
        );
        T.ReplayCell memory admitted = IStreamArtistOwner(e.payoutOwner).replayCell(key);
        if (
            admitted.commitment != r.recordHash || admitted.status != 2 || admitted.kind != 1
                || admitted.touchedRevision <= c.payoutOwnerRevision
                || admitted.touchedRevision
                    > IStreamArtistOwner(e.payoutOwner).ownerStateSnapshotV2().revision
        ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
        return keccak256(abi.encode(c, recovered, evidence, key, admitted));
    }

    function _recovery(
        W.EnvironmentV3 memory e,
        bytes32 artistId,
        bytes32 record,
        bytes32 action,
        bytes32 plan,
        uint64 revision
    ) private view returns (bytes32) {
        Living.Facts memory r = Living.readFamily(
            e.identityOwner, e.registry, e.chainId, artistId, record
        );
        W.EvidenceStateV3 memory evidence = IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner)
            .identityRecoveryEvidenceStateV3(artistId, action);
        if (
            action == 0 || plan == 0 || revision == 0
                || r.record.fields.governanceActionId != action
                || r.vesting.ownerRevision != revision || evidence.manifestHash == 0
                || evidence.associationHash == 0 || evidence.selectionCommitment != plan
                || evidence.sourceKey == 0 || evidence.sourceCommitment == 0
        ) revert W.InvalidRecoveryRewindRecord(record);
        return keccak256(abi.encode(r.proof, evidence));
    }
}
