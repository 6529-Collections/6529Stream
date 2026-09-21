// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveryFamilyEpisodes as Worker
} from "./StreamArtistRecoveryFamilyEpisodes.sol";

import {
    StreamArtistIdentityRecoveryState as State
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistCurrentNoticeRecoveryReads as CurrentNotice
} from "./StreamArtistCurrentNoticeRecoveryReads.sol";
import {
    StreamArtistRecoveryFamilyProfile as Profile
} from "./StreamArtistRecoveryFamilyProfile.sol";
import {
    StreamArtistCurrentCompromiseReads as Current
} from "./StreamArtistCurrentCompromiseReads.sol";
import {
    StreamArtistRecoveryStagingHistory as Stages
} from "./StreamArtistRecoveryStagingHistory.sol";
import {
    StreamArtistRecoveryFamilyAncestry as Ancestry
} from "./StreamArtistRecoveryFamilyAncestry.sol";
import {
    StreamArtistRecoveryRotationClosure as Closed
} from "./StreamArtistRecoveryRotationClosure.sol";
import {
    StreamArtistCancelledNoticeHistory as Cancelled
} from "./StreamArtistCancelledNoticeHistory.sol";
import {
    StreamArtistDormancyNoticeHistory as NoticeHistory
} from "./StreamArtistDormancyNoticeHistory.sol";
import { StreamArtistLivingRecoveryReads as Living } from "./StreamArtistLivingRecoveryReads.sol";
import {
    StreamArtistRecoveryEstateEpisode as EstateEpisode
} from "./StreamArtistRecoveryEstateEpisode.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityContestTypes as C
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistEstateOwner
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamArtistRotationReads
} from "../../interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistIdentityContestOwner
} from "../../interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistDormancyOwner,
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";

import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

import {
    StreamArtistRecoveryFamilyHistory as Original
} from "./StreamArtistRecoveryFamilyHistory.sol";

/// @notice Fixed typed historical checks at their original call positions.
library StreamArtistRecoveryFamilyEligibility {
    function _eligibleAt(
        Resolution.State storage resolutions,
        Original.Chain memory h,
        R.TransitionState memory t,
        uint64 at,
        uint64 revision,
        RH.Point memory boundary
    ) public view {
        if (t.recordHash == 0) return;
        if (at < t.executedAt) revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        if (at >= t.postWindowEndsAt && (t.contestedAt == 0 || t.contestedAt >= t.postWindowEndsAt))
        {
            return;
        }
        (bool found, uint256 index) = _first(h, t.recordHash);
        if (
            !found || h.episodes[index].dismissal.dismissedAt > at
                || resolutions.closures[t.recordHash].dismissalRecordHash
                    != h.episodes[index].dismissal.recordHash
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        }
        IStreamArtistOwner owner = IStreamArtistOwner(address(this));
        Original.Episode memory x = h.episodes[index];
        if (Imported.commitment() != 0) {
            Runtime.Context memory clock =
                Recovered.load(address(this), owner.artistRegistry(), block.chainid);
            Runtime.ReplayFact memory cell = Runtime.replay(
                clock,
                RH.originHash(clock.current),
                keccak256("identity_authority.replay.contest_resolution"),
                keccak256(abi.encode(h.artistId, x.cause.causeHash))
            );
            Runtime.ReceiptFact memory original =
                Recovered.nativeFact(clock, 58, h.artistId, x.dismissal.recordHash);
            if (
                cell.cell.commitment != x.dismissal.recordHash || cell.cell.kind != 1
                    || cell.cell.status != 2
                    || !Recovered.samePoint(cell.admission.point, original.position.point)
                    || !Runtime.before(clock, cell.admission.point, boundary)
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            return;
        }
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                owner.artistRegistry(),
                owner.operationCoordinator(),
                owner.archiveV2(),
                address(this),
                owner.domainId(),
                keccak256("identity_authority.replay.contest_resolution"),
                keccak256(abi.encode(h.artistId, x.cause.causeHash))
            )
        );
        T.ReplayCell memory cell = owner.replayCell(key);
        if (
            cell.commitment != x.dismissal.recordHash || cell.kind != 1 || cell.status != 2
                || cell.touchedRevision == 0 || cell.touchedRevision >= revision
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        }
    }

    function _first(Original.Chain memory h, bytes32 execution)
        private
        pure
        returns (bool found, uint256 index)
    {
        for (uint256 i; i < h.episodes.length; ++i) {
            if (h.episodes[i].cause.facts.executedTransitionHash == execution) {
                found = true;
                index = i;
            }
        }
    }

    function _staging(
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        Hashes.Environment memory e,
        Original.Chain memory h,
        Ancestry.Member memory m,
        Stages.Head memory stage,
        uint64 before
    ) public view returns (bytes32 proof) {
        proof = stage.proof;
        while (stage.recordHash != m.transition.recordHash) {
            if (stage.operation == 38) {
                Stages.EstateFacts memory estate = Imported.commitment() != 0
                    ? Stages.cancelledEstateAt(
                        address(this),
                        e.registry,
                        e.chainId,
                        h.artistId,
                        stage.recordHash,
                        stage.boundaryPoint
                    )
                    : Stages.cancelledEstate(
                        address(this),
                        e.registry,
                        e.chainId,
                        h.artistId,
                        stage.recordHash,
                        stage.boundaryRevision
                    );
                if (
                    estate.request.incumbent != m.incumbent
                        || estate.request.requestedAt < m.transition.executedAt
                        || estate.request.requestedAt > before
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                }
                _eligibleAt(
                    resolutions,
                    h,
                    m.transition,
                    estate.request.requestedAt,
                    estate.requestReplay.touchedRevision,
                    estate.requestPoint
                );
                proof = keccak256(
                    abi.encode(
                        proof, estate.proof, _estateClosure(resolutions, h, estate.transition)
                    )
                );
                before = estate.request.requestedAt;
                stage = Stages.beforeEstate(
                    address(this), e.registry, e.chainId, h.artistId, stage.recordHash
                );
            } else if (stage.operation == 29) {
                R.RotationRecord memory pending = rotations.rotations[stage.recordHash];
                bytes32 dismissed =
                    _pending(h, resolutions, m.transition.recordHash, stage.recordHash, before);
                if (
                    pending.terms.oldAddress != m.incumbent
                        || pending.transition.stagedAt < m.transition.executedAt
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                }
                proof = keccak256(abi.encode(proof, dismissed));
                before = pending.transition.stagedAt;
                stage = Stages.beforeRotation(
                    address(this), e.registry, e.chainId, h.artistId, stage.recordHash
                );
                _eligibleAt(
                    resolutions,
                    h,
                    m.transition,
                    before,
                    stage.boundaryRevision,
                    stage.boundaryPoint
                );
            } else {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            proof = keccak256(abi.encode(proof, stage.proof));
        }
    }

    function _pending(
        Original.Chain memory h,
        Resolution.State storage resolutions,
        bytes32 execution,
        bytes32 pending,
        uint64 before
    ) private view returns (bytes32) {
        D.Closure memory closure = resolutions.closures[pending];
        for (uint256 i; i < h.episodes.length; ++i) {
            Original.Episode memory x = h.episodes[i];
            if (h.adjudication && x.recoveryRecordHash != 0) {
                // A consumed cause has no dismissal. Its empty closure must not shadow an
                // older pending stage consumed by a different recovery in the full chain.
                if (
                    x.cause.facts.pendingTransitionHash != pending
                        || x.cause.facts.executedTransitionHash != execution
                ) continue;
                D.Closure memory empty;
                if (
                    x.cause.facts.enteredAt > before
                        || keccak256(abi.encode(closure)) != keccak256(abi.encode(empty))
                ) {
                    revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
                }
                return keccak256(abi.encode(x.proof, closure, pending, execution, before));
            }
            if (x.dismissal.recordHash != closure.dismissalRecordHash) continue;
            if (
                x.cause.facts.executedTransitionHash != execution
                    || x.cause.facts.pendingTransitionHash != pending
                    || x.dismissal.dismissedAt > before
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            return keccak256(abi.encode(x.proof, closure, pending, execution, before));
        }
        revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
    }

    function _estateClosure(
        Resolution.State storage resolutions,
        Original.Chain memory h,
        R.TransitionState memory t
    ) private view returns (bytes32) {
        D.Closure memory closure = resolutions.closures[t.recordHash];
        D.Closure memory empty;
        if (h.current.facts.pendingTransitionHash == t.recordHash) {
            if (
                h.current.facts.kind != 1 || t.contestedAt != h.current.facts.enteredAt
                    || keccak256(abi.encode(closure)) != keccak256(abi.encode(empty))
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            return 0;
        }
        for (uint256 i; i < h.episodes.length; ++i) {
            Original.Episode memory x = h.episodes[i];
            if (x.cause.facts.pendingTransitionHash != t.recordHash) continue;
            // The selected Estate episode has already authenticated this original closure.
            if (
                x.cause.facts.kind != 1 || t.contestedAt != x.cause.facts.enteredAt
                    || closure.dismissalRecordHash != x.dismissal.recordHash
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            if (
                h.adjudication && x.recoveryRecordHash != 0
                    && keccak256(abi.encode(closure)) != keccak256(abi.encode(empty))
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
            }
            return keccak256(abi.encode(x.proof, closure));
        }
        if (t.contestedAt != 0 || keccak256(abi.encode(closure)) != keccak256(abi.encode(empty))) {
            revert I.UnsupportedIdentityRecoveryProfile(h.artistId);
        }
        return 0;
    }
}
