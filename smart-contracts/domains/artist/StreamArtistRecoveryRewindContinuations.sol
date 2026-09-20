// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRevisionTypes as Doc,
    IStreamArtistIdentityRevisionReads
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    IStreamArtistIdentityRecoveryOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistPayoutOwner
} from "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    IStreamArtistRecoveryPayoutOwnerV3
} from "../../interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";
import { StreamArtistLivingRecoveryReads as Living } from "./StreamArtistLivingRecoveryReads.sol";
import {
    StreamArtistRecoveryRewindAdmission as A
} from "./StreamArtistRecoveryRewindAdmission.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    IStreamArtistRecoveredPayoutHydration
} from "../../interfaces/stream/artist/IStreamArtistRecoveredPayoutHydration.sol";

/// @notice Bounded original and recovery-scoped branch admission without clearing old replay cells.
library StreamArtistRecoveryRewindContinuations {
    /// @notice Imported/current original18 consuming a positively authenticated prior V3 branch.
    /// @dev Identity and Payout order are checked separately; their raw counters are never compared.
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

    /// @notice An original18 that consumed one recovery-scoped Payout branch admission.
    /// @dev The fixed Payout owner records this mapping only when that exact scope is consumed.
    /// Original records without a supplemental mapping keep their original admission proof.
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

    function revisionAt(
        W.EnvironmentV3 memory e,
        Doc.Record memory r,
        bytes32 originalHead,
        Runtime.ReplayFact memory nonce,
        Runtime.ReceiptFact memory occurrence
    ) public view returns (bytes32 proof) {
        Runtime.Context memory clock = Runtime.load(e, 2);
        IStreamArtistIdentityRecoveryOwnerV3 owner =
            IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner);
        bytes32 current = owner.identityRevisionRecoveryContinuationV3(r.recordHash);
        bytes32 surface = keccak256("identity_authority.replay.identity_revision_chain");
        bytes32 scope =
            keccak256(abi.encode(r.artistId, r.previousRevisionRecord, r.previousRecordHash));
        if (current != 0) {
            W.RevisionContinuationV3 memory c = owner.recoveryRevisionContinuationV3(current);
            Runtime.OriginFact memory origin = Runtime.auxiliary(
                clock, keccak256("identity_authority.hydration.revision_continuation_v3"), current
            );
            if (
                c.ownerRevision != origin.point.ownerRevision || c.artistId != r.artistId
                    || c.continuationHash != current
                    || W.revisionContinuationHash(Runtime.rewindEnvironment(origin.environment), c)
                        != current || c.stableRevisionRecordHash != r.previousRevisionRecord
                    || c.stableDocumentHash != r.previousRecordHash
                    || !Runtime.before(clock, origin.point, nonce.admission.point)
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
            _recoveryOrigin(clock, c.artistId, c.recoveryRecordHash, origin);
            bytes32 recovered = _recovery(
                e, c.artistId, c.recoveryRecordHash, c.actionId, c.planCommitment, c.ownerRevision
            );
            surface = keccak256("identity_authority.replay.identity_revision_recovery_continuation");
            scope = keccak256(
                abi.encode(r.artistId, r.previousRevisionRecord, r.previousRecordHash, current)
            );
            proof = keccak256(abi.encode(c, recovered));
        } else if (originalHead != 0) {
            D.RevisionContinuation memory c = IStreamArtistIdentityDismissalOwner(e.identityOwner)
                .identityRevisionContinuation(originalHead);
            Runtime.OriginFact memory origin = Runtime.auxiliary(
                clock,
                keccak256("identity_authority.hydration.dismissal_continuation"),
                originalHead
            );
            (D.Record memory d, Runtime.ReplayFact memory resolution) =
                A.dismissalAt(e, c.dismissalRecordHash);
            if (
                c.artistId != r.artistId || c.continuationHash != originalHead
                    || c.abandonedRevisionRecordHash == 0 || c.stableDocumentHash == 0
                    || d.terms.artistId != r.artistId || d.revisionContinuationHead != originalHead
                    || !Recovered.samePoint(origin.point, resolution.admission.point)
                    || !Runtime.before(clock, resolution.admission.point, nonce.admission.point)
                    || originalHead
                        != keccak256(
                            abi.encode(
                                keccak256("6529STREAM_ARTIST_IDENTITY_REVISION_CONTINUATION_V1"),
                                origin.environment.chainId,
                                origin.environment.registry,
                                origin.environment.owners[2],
                                c.artistId,
                                c.dismissalRecordHash,
                                c.previousContinuationHash,
                                c.stableRevisionRecordHash,
                                c.stableDocumentHash,
                                c.abandonedRevisionRecordHash
                            )
                        )
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
            Doc.Record memory abandoned = IStreamArtistIdentityRevisionReads(e.identityOwner)
                .identityRevisionRecord(c.abandonedRevisionRecordHash);
            R.ProvisionalAssociation memory association = IStreamArtistRotationReads(
                    e.identityOwner
                ).identityRevisionProvisionalAssociation(c.abandonedRevisionRecordHash);
            D.Closure memory closed = IStreamArtistIdentityDismissalOwner(e.identityOwner)
                .identityTransitionClosure(r.artistId, association.transitionRecordHash);
            if (
                abandoned.recordHash != c.abandonedRevisionRecordHash
                    || abandoned.artistId != r.artistId
                    || abandoned.previousRevisionRecord != c.stableRevisionRecordHash
                    || abandoned.previousRecordHash != c.stableDocumentHash
                    || association.transitionRecordHash == 0 || !closed.abandoned
                    || closed.artistId != r.artistId
                    || closed.transitionRecordHash != association.transitionRecordHash
                    || closed.windowEndsAt != association.windowEndsAt
                    || closed.dismissalRecordHash != d.recordHash
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
            if (
                c.stableRevisionRecordHash == r.previousRevisionRecord
                    && c.stableDocumentHash == r.previousRecordHash
            ) {
                surface = keccak256("identity_authority.replay.identity_revision_continuation");
                scope = keccak256(
                    abi.encode(
                        r.artistId, r.previousRevisionRecord, r.previousRecordHash, originalHead
                    )
                );
            }
            proof = keccak256(abi.encode(c, d, resolution, abandoned, association, closed));
        }
        Runtime.ReplayFact memory admitted = A.consumedAt(
            e, occurrence.position.point.environmentHash, surface, scope, r.recordHash
        );
        if (
            !Recovered.samePoint(admitted.admission.point, nonce.admission.point)
                || !Recovered.samePoint(admitted.admission.point, occurrence.position.point)
        ) {
            revert W.InvalidRecoveryRewindRecord(r.recordHash);
        }
        return keccak256(abi.encode(proof, surface, scope, admitted));
    }

    function revision(
        W.EnvironmentV3 memory e,
        Doc.Record memory r,
        bytes32 originalHead,
        T.ReplayCell memory nonce
    ) public view returns (bytes32 proof) {
        IStreamArtistIdentityRecoveryOwnerV3 owner =
            IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner);
        bytes32 current = owner.identityRevisionRecoveryContinuationV3(r.recordHash);
        bytes32 surface = keccak256("identity_authority.replay.identity_revision_chain");
        bytes32 scope =
            keccak256(abi.encode(r.artistId, r.previousRevisionRecord, r.previousRecordHash));
        if (current != 0) {
            W.RevisionContinuationV3 memory c = owner.recoveryRevisionContinuationV3(current);
            if (
                c.artistId != r.artistId || c.continuationHash != current
                    || W.revisionContinuationHash(e, c) != current
                    || c.stableRevisionRecordHash != r.previousRevisionRecord
                    || c.stableDocumentHash != r.previousRecordHash
                    || c.ownerRevision >= nonce.touchedRevision
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
            bytes32 recovered = _recovery(
                e, c.artistId, c.recoveryRecordHash, c.actionId, c.planCommitment, c.ownerRevision
            );
            surface = keccak256("identity_authority.replay.identity_revision_recovery_continuation");
            scope = keccak256(
                abi.encode(r.artistId, r.previousRevisionRecord, r.previousRecordHash, current)
            );
            proof = keccak256(abi.encode(c, recovered));
        } else if (originalHead != 0) {
            D.RevisionContinuation memory c = IStreamArtistIdentityDismissalOwner(e.identityOwner)
                .identityRevisionContinuation(originalHead);
            (D.Record memory d, T.ReplayCell memory resolution) =
                A.dismissal(e, c.dismissalRecordHash);
            if (
                c.artistId != r.artistId || c.continuationHash != originalHead
                    || c.abandonedRevisionRecordHash == 0 || c.stableDocumentHash == 0
                    || d.terms.artistId != r.artistId || d.revisionContinuationHead != originalHead
                    || resolution.touchedRevision >= nonce.touchedRevision
                    || originalHead
                        != keccak256(
                            abi.encode(
                                keccak256("6529STREAM_ARTIST_IDENTITY_REVISION_CONTINUATION_V1"),
                                e.chainId,
                                e.registry,
                                e.identityOwner,
                                c.artistId,
                                c.dismissalRecordHash,
                                c.previousContinuationHash,
                                c.stableRevisionRecordHash,
                                c.stableDocumentHash,
                                c.abandonedRevisionRecordHash
                            )
                        )
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
            Doc.Record memory abandoned = IStreamArtistIdentityRevisionReads(e.identityOwner)
                .identityRevisionRecord(c.abandonedRevisionRecordHash);
            R.ProvisionalAssociation memory association = IStreamArtistRotationReads(
                    e.identityOwner
                ).identityRevisionProvisionalAssociation(c.abandonedRevisionRecordHash);
            D.Closure memory closed = IStreamArtistIdentityDismissalOwner(e.identityOwner)
                .identityTransitionClosure(r.artistId, association.transitionRecordHash);
            if (
                abandoned.recordHash != c.abandonedRevisionRecordHash
                    || abandoned.artistId != r.artistId
                    || abandoned.previousRevisionRecord != c.stableRevisionRecordHash
                    || abandoned.previousRecordHash != c.stableDocumentHash
                    || association.transitionRecordHash == 0 || !closed.abandoned
                    || closed.artistId != r.artistId
                    || closed.transitionRecordHash != association.transitionRecordHash
                    || closed.windowEndsAt != association.windowEndsAt
                    || closed.dismissalRecordHash != d.recordHash
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
            if (
                c.stableRevisionRecordHash == r.previousRevisionRecord
                    && c.stableDocumentHash == r.previousRecordHash
            ) {
                surface = keccak256("identity_authority.replay.identity_revision_continuation");
                scope = keccak256(
                    abi.encode(
                        r.artistId, r.previousRevisionRecord, r.previousRecordHash, originalHead
                    )
                );
            }
            proof = keccak256(abi.encode(c, d, resolution, abandoned, association, closed));
        }
        T.ReplayCell memory admitted = A.consumed(e, surface, scope, r.recordHash);
        if (admitted.touchedRevision != nonce.touchedRevision) {
            revert W.InvalidRecoveryRewindRecord(r.recordHash);
        }
        return keccak256(abi.encode(proof, surface, scope, admitted));
    }

    function standingAt(
        W.EnvironmentV3 memory e,
        R.StandingRecord memory r,
        Runtime.ReceiptFact memory occurrence
    ) public view returns (Runtime.ReplayFact memory admitted, bytes32 proof) {
        Runtime.Context memory clock = Runtime.load(e, 2);
        IStreamArtistIdentityRecoveryOwnerV3 owner =
            IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner);
        bytes32 head = owner.standingRevocationRecoveryContinuationV3(r.recordHash);
        bytes32 surface = keccak256("identity_authority.replay.standing_revocation_key");
        bytes32 scope = keccak256(
            abi.encode(
                r.terms.artistId, r.terms.revokedAddress, r.terms.retiredTransitionRecordHash
            )
        );
        if (head != 0) {
            W.StandingContinuationV3 memory c = owner.recoveryStandingContinuationV3(head);
            Runtime.OriginFact memory origin = Runtime.auxiliary(
                clock, keccak256("identity_authority.hydration.standing_continuation_v3"), head
            );
            if (
                c.ownerRevision != origin.point.ownerRevision || c.artistId != r.terms.artistId
                    || c.priorAddress != r.terms.revokedAddress
                    || c.retirementHash != r.terms.retiredTransitionRecordHash
                    || c.continuationHash != head
                    || W.standingContinuationHash(Runtime.rewindEnvironment(origin.environment), c)
                        != head || c.retainedRevocationRecordHash != 0
                    || c.supersededRevocationRecordHash == 0
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
            _recoveryOrigin(clock, c.artistId, c.recoveryRecordHash, origin);
            bytes32 recovered = _recovery(
                e, c.artistId, c.recoveryRecordHash, c.actionId, c.planCommitment, c.ownerRevision
            );
            W.StatusV3 memory status = owner.recoveryRecordStatusV3(
                W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION, c.supersededRevocationRecordHash
            );
            R.StandingRecord memory original = IStreamArtistRotationReads(e.identityOwner)
                .standingRevocationRecord(c.supersededRevocationRecordHash);
            if (
                status.artistId != c.artistId
                    || status.kind != W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION
                    || status.recoveryRecordHash != c.recoveryRecordHash
                    || status.actionId != c.actionId || status.planCommitment != c.planCommitment
                    || original.recordHash != c.supersededRevocationRecordHash
                    || original.terms.artistId != c.artistId
                    || original.terms.revokedAddress != c.priorAddress
                    || original.terms.retiredTransitionRecordHash != c.retirementHash
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
            surface =
                keccak256("identity_authority.replay.standing_revocation_recovery_continuation");
            scope = keccak256(abi.encode(c.artistId, c.priorAddress, c.retirementHash, head));
            admitted = A.consumedAt(
                e, occurrence.position.point.environmentHash, surface, scope, r.recordHash
            );
            if (!Runtime.before(clock, origin.point, admitted.admission.point)) {
                revert W.InvalidRecoveryRewindRecord(r.recordHash);
            }
            proof = keccak256(abi.encode(c, recovered, status, original));
        } else {
            admitted = A.consumedAt(
                e, occurrence.position.point.environmentHash, surface, scope, r.recordHash
            );
        }
        if (!Recovered.samePoint(admitted.admission.point, occurrence.position.point)) {
            revert W.InvalidRecoveryRewindRecord(r.recordHash);
        }
        return (admitted, keccak256(abi.encode(proof, surface, scope, admitted)));
    }

    function standing(W.EnvironmentV3 memory e, R.StandingRecord memory r)
        public
        view
        returns (T.ReplayCell memory admitted, bytes32 proof)
    {
        IStreamArtistIdentityRecoveryOwnerV3 owner =
            IStreamArtistIdentityRecoveryOwnerV3(e.identityOwner);
        bytes32 head = owner.standingRevocationRecoveryContinuationV3(r.recordHash);
        bytes32 surface = keccak256("identity_authority.replay.standing_revocation_key");
        bytes32 scope = keccak256(
            abi.encode(
                r.terms.artistId, r.terms.revokedAddress, r.terms.retiredTransitionRecordHash
            )
        );
        if (head != 0) {
            W.StandingContinuationV3 memory c = owner.recoveryStandingContinuationV3(head);
            if (
                c.artistId != r.terms.artistId || c.priorAddress != r.terms.revokedAddress
                    || c.retirementHash != r.terms.retiredTransitionRecordHash
                    || c.continuationHash != head || W.standingContinuationHash(e, c) != head
                    || c.retainedRevocationRecordHash != 0 || c.supersededRevocationRecordHash == 0
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
            bytes32 recovered = _recovery(
                e, c.artistId, c.recoveryRecordHash, c.actionId, c.planCommitment, c.ownerRevision
            );
            W.StatusV3 memory status = owner.recoveryRecordStatusV3(
                W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION, c.supersededRevocationRecordHash
            );
            R.StandingRecord memory original = IStreamArtistRotationReads(e.identityOwner)
                .standingRevocationRecord(c.supersededRevocationRecordHash);
            if (
                status.artistId != c.artistId
                    || status.kind != W.RecordKind.PRIOR_ADDRESS_STANDING_REVOCATION
                    || status.recoveryRecordHash != c.recoveryRecordHash
                    || status.actionId != c.actionId || status.planCommitment != c.planCommitment
                    || original.recordHash != c.supersededRevocationRecordHash
                    || original.terms.artistId != c.artistId
                    || original.terms.revokedAddress != c.priorAddress
                    || original.terms.retiredTransitionRecordHash != c.retirementHash
            ) revert W.InvalidRecoveryRewindRecord(r.recordHash);
            surface =
                keccak256("identity_authority.replay.standing_revocation_recovery_continuation");
            scope = keccak256(abi.encode(c.artistId, c.priorAddress, c.retirementHash, head));
            admitted = A.consumed(e, surface, scope, r.recordHash);
            if (c.ownerRevision >= admitted.touchedRevision) {
                revert W.InvalidRecoveryRewindRecord(r.recordHash);
            }
            proof = keccak256(abi.encode(c, recovered, status, original));
        } else {
            admitted = A.consumed(e, surface, scope, r.recordHash);
        }
        return (admitted, keccak256(abi.encode(proof, surface, scope, admitted)));
    }

    function _recoveryOrigin(
        Runtime.Context memory clock,
        bytes32 artistId,
        bytes32 record,
        Runtime.OriginFact memory origin
    ) private view {
        Runtime.ReceiptFact memory created = Recovered.nativeFact(clock, 35, artistId, record);
        if (!Recovered.samePoint(created.position.point, origin.point)) {
            revert W.InvalidRecoveryRewindRecord(record);
        }
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
