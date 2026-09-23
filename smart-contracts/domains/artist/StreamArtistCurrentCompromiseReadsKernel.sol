// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistRotationHashes } from "./StreamArtistRotationHashes.sol";
import {
    StreamArtistRecoveryStagingHistory as Stages
} from "./StreamArtistRecoveryStagingHistory.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";

import {
    StreamArtistCurrentCompromiseReads as Shape
} from "./StreamArtistCurrentCompromiseReads.sol";

/// @notice Fixed current-compromise read implementations with the unchanged complete typed frame.
import {
    StreamArtistCurrentEstateCompromiseReads as Tail
} from "./StreamArtistCurrentEstateCompromiseReads.sol";

library StreamArtistCurrentCompromiseReadsKernel {
    function readOriginal(
        address owner,
        address registry,
        uint256 chainId,
        D.Cause memory current,
        R.TransitionState memory executed
    ) public view returns (Shape.Facts memory f) {
        bytes32 artistId = current.facts.artistId;
        if (
            owner.code.length == 0 || registry == address(0) || chainId != block.chainid
                || IStreamArtistOwner(owner).deploymentChainId() != chainId
                || IStreamArtistOwner(owner).artistRegistry() != registry
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        Shape.Environment memory e = Shape.Environment(owner, registry, chainId);
        bytes32 living = _living(e, artistId);
        _cause(e, current, executed);
        f.contest = IStreamArtistIdentityContestOwner(owner)
            .identityContestRecord(current.facts.referenceHash);
        bytes32 subject = _contest(e, current, f.contest);
        if (current.facts.pendingTransitionHash != 0) {
            f.pending = _pending(e, current, executed, f.contest);
        }
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CURRENT_COMPROMISE_FACTS_V1"),
                chainId,
                registry,
                owner,
                living,
                current,
                executed,
                f.contest,
                f.pending,
                subject
            )
        );
    }

    function readFamily(
        address owner,
        address registry,
        uint256 chainId,
        D.Cause memory current,
        R.TransitionState memory executed,
        bool live,
        bool notice
    ) public view returns (Shape.Facts memory f) {
        bytes32 artistId = current.facts.artistId;
        if (
            owner.code.length == 0 || registry == address(0) || chainId != block.chainid
                || IStreamArtistOwner(owner).deploymentChainId() != chainId
                || IStreamArtistOwner(owner).artistRegistry() != registry
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        Shape.Environment memory e = Shape.Environment(owner, registry, chainId);
        _familyCause(e, current, executed, live, notice);
        bytes32 subject;
        bytes32 standing;
        bytes32 estateProof;
        if (current.facts.kind == 1) {
            f.contest = IStreamArtistIdentityContestOwner(owner)
                .identityContestRecord(current.facts.referenceHash);
            subject =
                _contestClass(e, current, f.contest, notice ? 2 : current.facts.authorityClass);
        } else {
            standing = _standing(e, current);
        }
        if (current.facts.pendingTransitionHash != 0) {
            if (
                IStreamArtistRotationReads(owner)
                    .rotationRecord(current.facts.pendingTransitionHash)
                    .recordHash != 0
            ) {
                f.pending = _pendingRecord(
                    e, current, executed, f.contest, current.facts.kind == 1, live
                );
            } else {
                estateProof = Tail.pendingEstate(e, current, executed, f.contest, live);
            }
        }
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_CURRENT_CAUSE_FAMILY_FACTS_V1"),
                chainId,
                registry,
                owner,
                current,
                executed,
                f.contest,
                f.pending,
                subject,
                standing
            )
        );
        // Only this new estate profile adds a wrapper. Existing family and original read()
        // commitments retain their exact original encoding; S is never a RotationRecord.
        if (estateProof != 0) {
            f.proof = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_CURRENT_ESTATE_COMPROMISE_FACTS_V1"),
                    f.proof,
                    estateProof
                )
            );
        }
        if (notice) {
            f.proof = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_CURRENT_NOTICE_COMPROMISE_FACTS_V1"), f.proof
                )
            );
        }
    }

    function _familyCause(
        Shape.Environment memory e,
        D.Cause memory current,
        R.TransitionState memory executed,
        bool live,
        bool notice
    ) private view {
        D.CauseFacts memory c = current.facts;
        if (
            c.artistId == 0 || current.causeHash == 0 || (c.kind != 1 && c.kind != 2)
                || (c.authorityClass != 1 && c.authorityClass != 3)
                || (notice
                        ? c.kind != 1 || c.authorityClass != 1 || c.priorStatus != 2
                        || c.pendingTransitionHash != 0
                        : c.priorStatus != c.authorityClass) || c.incumbent == address(0)
                || c.actor == address(0) || c.referenceHash == 0
                || (c.kind == 1
                        ? c.evidenceHash == 0 || c.reasonHash == 0
                        : c.evidenceHash != 0 || c.referenceHash != c.pendingTransitionHash)
                || c.enteredAt == 0 || c.enteredAt > block.timestamp
                || c.executedTransitionHash != executed.recordHash
                || current.causeHash != _causeHash(e, current)
                || (live
                    && keccak256(abi.encode(current))
                        != keccak256(
                            abi.encode(
                                IStreamArtistIdentityDismissalOwner(e.owner)
                                    .currentIdentityContestCause(c.artistId)
                            )
                        ))
                || keccak256(abi.encode(current))
                    != keccak256(
                        abi.encode(
                            IStreamArtistIdentityDismissalOwner(e.owner)
                                .identityContestCause(current.causeHash)
                        )
                    )
                || keccak256(abi.encode(executed))
                    != keccak256(
                        abi.encode(
                            IStreamArtistRotationReads(e.owner)
                                .artistTransitionState(executed.recordHash)
                        )
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(c.artistId);
        if (executed.recordHash == 0) {
            R.TransitionState memory empty;
            if (
                c.authorityClass != 1
                    || keccak256(abi.encode(executed)) != keccak256(abi.encode(empty))
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(c.artistId);
            }
        } else if (
            executed.artistId != c.artistId || executed.phase != 2 || executed.executedAt == 0
                || executed.executedAt > c.enteredAt
        ) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(c.artistId);
        }
    }

    function _standing(Shape.Environment memory e, D.Cause memory current)
        private
        view
        returns (bytes32)
    {
        IStreamArtistOwner owner = IStreamArtistOwner(e.owner);
        if (Recovered.active(e.owner)) {
            Runtime.Context memory clock = Recovered.load(e.owner, e.registry, e.chainId);
            Runtime.ReceiptFact memory cause = _causeOrigin(e, current);
            Runtime.ReplayFact memory replay = Runtime.replay(
                clock,
                cause.position.point.environmentHash,
                keccak256("identity_authority.replay.rotation_veto_key"),
                current.facts.pendingTransitionHash
            );
            if (
                replay.cell.commitment != current.facts.pendingTransitionHash
                    || replay.cell.kind != 1 || replay.cell.status != 2
                    || !Recovered.samePoint(replay.admission.point, cause.position.point)
            ) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
            }
            return keccak256(abi.encode(replay, cause));
        }
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                owner.operationCoordinator(),
                owner.archiveV2(),
                e.owner,
                owner.domainId(),
                keccak256("identity_authority.replay.rotation_veto_key"),
                current.facts.pendingTransitionHash
            )
        );
        T.ReplayCell memory cell = owner.replayCell(key);
        if (
            cell.commitment != current.facts.pendingTransitionHash || cell.kind != 1
                || cell.status != 2 || cell.touchedRevision == 0
                || cell.touchedRevision > owner.ownerStateSnapshotV2().revision
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
        // The fixed-owner canonical Cause authenticates the original actor and optional reason.
        // The veto key commits P, not an independently stored Contest or a fresh role decision.
        return keccak256(abi.encode(key, cell));
    }

    function _causeOrigin(Shape.Environment memory e, D.Cause memory current)
        private
        view
        returns (Runtime.ReceiptFact memory)
    {
        Runtime.Context memory clock = Recovered.load(e.owner, e.registry, e.chainId);
        return Recovered.nativeFact(
            clock, current.facts.kind == 1 ? 33 : 31, current.facts.artistId, current.causeHash
        );
    }

    function _causeHash(Shape.Environment memory e, D.Cause memory current)
        private
        view
        returns (bytes32)
    {
        address owner = e.owner;
        address registry = e.registry;
        uint256 chainId = e.chainId;
        if (Recovered.active(e.owner)) {
            Runtime.ReceiptFact memory origin = _causeOrigin(e, current);
            owner = origin.environment.owners[2];
            registry = origin.environment.registry;
            chainId = origin.environment.chainId;
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                chainId,
                registry,
                owner,
                current.facts
            )
        );
    }

    function _living(Shape.Environment memory e, bytes32 artistId)
        private
        view
        returns (bytes32 hash)
    {
        hash = IStreamArtistIdentityRecoveryOwner(e.owner).latestIdentityRecovery(artistId);
        Recovery.Record memory prior =
            IStreamArtistIdentityRecoveryOwner(e.owner).identityRecoveryRecord(hash);
        if (
            hash == 0 || prior.recordHash != hash || prior.fields.artistId != artistId
                || prior.fields.vestedAuthorityClass != 1
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }

    function _cause(
        Shape.Environment memory e,
        D.Cause memory current,
        R.TransitionState memory executed
    ) private view {
        D.CauseFacts memory c = current.facts;
        if (
            c.artistId == 0 || current.causeHash == 0 || c.kind != 1 || c.authorityClass != 1
                || c.priorStatus != 1 || c.incumbent == address(0) || c.actor == address(0)
                || c.referenceHash == 0 || c.evidenceHash == 0 || c.reasonHash == 0
                || c.enteredAt == 0 || c.enteredAt > block.timestamp || executed.recordHash == 0
                || executed.artistId != c.artistId || executed.phase != 2
                || executed.executedAt == 0 || executed.executedAt > c.enteredAt
                || c.executedTransitionHash != executed.recordHash
                || current.causeHash != _causeHash(e, current)
                || keccak256(abi.encode(current))
                    != keccak256(
                        abi.encode(
                            IStreamArtistIdentityDismissalOwner(e.owner)
                                .currentIdentityContestCause(c.artistId)
                        )
                    )
                || keccak256(abi.encode(current))
                    != keccak256(
                        abi.encode(
                            IStreamArtistIdentityDismissalOwner(e.owner)
                                .identityContestCause(current.causeHash)
                        )
                    )
                || keccak256(abi.encode(executed))
                    != keccak256(
                        abi.encode(
                            IStreamArtistRotationReads(e.owner)
                                .artistTransitionState(executed.recordHash)
                        )
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(c.artistId);
    }

    function _contest(Shape.Environment memory e, D.Cause memory current, C.Record memory c)
        private
        view
        returns (bytes32)
    {
        return _contestClass(e, current, c, 1);
    }

    function _contestClass(
        Shape.Environment memory e,
        D.Cause memory current,
        C.Record memory c,
        uint8 authorityClass
    ) private view returns (bytes32) {
        D.CauseFacts memory f = current.facts;
        StreamArtistHashes.Environment memory original;
        original.chainId = e.chainId;
        original.registry = e.registry;
        if (Recovered.active(e.owner)) {
            Runtime.Context memory clock = Recovered.load(e.owner, e.registry, e.chainId);
            Runtime.ReceiptFact memory row =
                Recovered.nativeFact(clock, 33, f.artistId, c.recordHash);
            original = Recovered.hashes(row.environment);
        }
        if (
            c.recordHash != f.referenceHash || c.terms.artistId != f.artistId
                || c.terms.evidenceHash != f.evidenceHash || c.terms.reasonHash != f.reasonHash
                || c.contester != f.actor || c.contestedAt != f.enteredAt
                || c.priorStatus != authorityClass
                || c.pendingTransitionRecordHash != f.pendingTransitionHash
                || c.executedTransitionRecordHash != f.executedTransitionHash
                || c.recordHash
                    != keccak256(
                        abi.encode(
                            bytes32(
                                0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb
                            ),
                            original.chainId,
                            original.registry,
                            c.terms.artistId,
                            c.contester,
                            c.terms.subjectRecordHash,
                            c.terms.evidenceHash,
                            c.terms.reasonHash,
                            c.contestedAt
                        )
                    )
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(f.artistId);
        if (c.terms.subjectRecordHash == 0) return 0;
        R.TransitionState memory subject =
            IStreamArtistRotationReads(e.owner).artistTransitionState(c.terms.subjectRecordHash);
        if (
            subject.recordHash != c.terms.subjectRecordHash || subject.artistId != f.artistId
                || (subject.phase != 2 && subject.phase != 3) || subject.stagedAt == 0
                || subject.stagedAt > f.enteredAt
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(f.artistId);
        return _subject(e, current, subject);
    }

    function _subject(
        Shape.Environment memory e,
        D.Cause memory current,
        R.TransitionState memory subject
    ) private view returns (bytes32) {
        R.RotationRecord memory rotation = IStreamArtistRotationReads(e.owner)
            .rotationRecord(subject.recordHash);
        if (rotation.recordHash != subject.recordHash) {
            Recovery.Record memory recovered = IStreamArtistIdentityRecoveryOwner(e.owner)
                .identityRecoveryRecord(subject.recordHash);
            // Other original transition kinds have their own marker writers.
            if (recovered.recordHash != subject.recordHash) return keccak256(abi.encode(subject));
        }
        if (subject.contestedAt > current.facts.enteredAt) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
        }
        D.Closure memory closed = IStreamArtistIdentityDismissalOwner(e.owner)
            .identityTransitionClosure(subject.artistId, subject.recordHash);
        D.Closure memory empty;
        if (keccak256(abi.encode(closed)) == keccak256(abi.encode(empty))) {
            if (subject.contestedAt == 0) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
            }
            return keccak256(abi.encode(subject, closed));
        }
        D.Record memory dismissal = IStreamArtistIdentityDismissalOwner(e.owner)
            .identityContestDismissalRecord(closed.dismissalRecordHash);
        uint64 ends = subject.phase == 2 ? subject.postWindowEndsAt : subject.contestEndsAt;
        bool abandoned = subject.phase == 3
            || (subject.phase == 2
                && subject.contestedAt != 0
                && subject.contestedAt < subject.postWindowEndsAt);
        if (
            closed.dismissalRecordHash == 0 || closed.artistId != subject.artistId
                || closed.transitionRecordHash != subject.recordHash || closed.windowEndsAt != ends
                || closed.contestedAt != subject.contestedAt || closed.abandoned != abandoned
                || dismissal.recordHash != closed.dismissalRecordHash
                || dismissal.terms.artistId != subject.artistId
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
        return keccak256(abi.encode(subject, closed, dismissal));
    }

    function _pending(
        Shape.Environment memory e,
        D.Cause memory current,
        R.TransitionState memory executed,
        C.Record memory contest
    ) private view returns (R.RotationRecord memory r) {
        return _pendingRecord(e, current, executed, contest, true, true);
    }

    function _pendingRecord(
        Shape.Environment memory e,
        D.Cause memory current,
        R.TransitionState memory executed,
        C.Record memory contest,
        bool hasContest,
        bool live
    ) private view returns (R.RotationRecord memory r) {
        bytes32 hash = current.facts.pendingTransitionHash;
        bytes32 artistId = current.facts.artistId;
        r = IStreamArtistRotationReads(e.owner).rotationRecord(hash);
        (address old_, address new_, uint64 ends, uint32 approvals, bytes32 pending) =
            IStreamArtistRotationReads(e.owner).pendingRotation(artistId);
        D.Closure memory closed =
            IStreamArtistIdentityDismissalOwner(e.owner).identityTransitionClosure(artistId, hash);
        D.Closure memory empty;
        StreamArtistHashes.Environment memory original;
        original.chainId = e.chainId;
        original.registry = e.registry;
        if (Recovered.active(e.owner)) {
            Runtime.Context memory clock = Recovered.load(e.owner, e.registry, e.chainId);
            Runtime.ReceiptFact memory staged = Recovered.nativeFact(clock, 29, artistId, hash);
            Runtime.ReceiptFact memory cause = _causeOrigin(e, current);
            if (!Runtime.before(clock, staged.position.point, cause.position.point)) {
                revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
            }
            original = Recovered.hashes(staged.environment);
        }
        if (
            hash == executed.recordHash || r.recordHash != hash || r.terms.artistId != artistId
                || (live
                    && (IStreamArtistRotationReads(e.owner).lastArtistTransition(artistId) != hash
                        || old_ != address(0)
                        || new_ != address(0)
                        || ends != 0
                        || approvals != 0
                        || pending != 0)) || r.terms.oldAddress != current.facts.incumbent
                || r.terms.newAddress == address(0) || r.terms.oldAddress == r.terms.newAddress
                || r.transition.artistId != artistId || r.transition.recordHash != hash
                || r.transition.phase != 3 || r.transition.executedAt != 0
                || r.transition.postWindowEndsAt != 0 || r.transition.stagedAt == 0
                || r.transition.stagedAt < executed.executedAt
                || r.transition.stagedAt > current.facts.enteredAt
                || r.transition.contestedAt != current.facts.enteredAt
                || r.effectiveWindow < 72 hours || r.standingTail < 30 days || r.timingRevision == 0
                || uint256(r.transition.contestEndsAt)
                    != uint256(r.transition.stagedAt) + r.effectiveWindow
                || StreamArtistRotationHashes.rotationRecord(
                        original,
                        r.terms,
                        r.oldNonce,
                        r.transition.stagedAt,
                        r.transition.contestEndsAt
                    ) != hash
                || keccak256(abi.encode(r.transition))
                    != keccak256(
                        abi.encode(IStreamArtistRotationReads(e.owner).artistTransitionState(hash))
                    )
                || (hasContest && contest.capturedGuardianSetRecordHash != r.guardianSetRecordHash)
                || keccak256(abi.encode(closed)) != keccak256(abi.encode(empty))
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
    }
}
