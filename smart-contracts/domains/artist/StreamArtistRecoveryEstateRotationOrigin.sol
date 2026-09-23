// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredIdentityRuntime as Recovered
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import { StreamArtistRotationState as RotationState } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistIdentityContestState as ContestState
} from "./StreamArtistIdentityContestState.sol";
import { StreamArtistRecoveryEstateClosed as Closed } from "./StreamArtistRecoveryEstateClosed.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Exact original estate closure, separate from subsequent successors' closures.
/// @dev The caller authenticates op40, its unchanged epoch and the admitted vesting chain. The
/// dismissal producer can first close op40 only while op40 is the actual executed head and never
/// overwrites that closure. It therefore predates the first executed op32, even for a long chain.
/// terminalStagedAt is an additional upper bound, not a claim that the terminal is the first op32.
library StreamArtistRecoveryEstateRotationOrigin {
    function proof(
        RotationState.State storage rotations,
        Resolution.State storage resolutions,
        ContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        R.TransitionState memory origin,
        address successor,
        uint64 terminalStagedAt
    ) public view returns (bytes32) {
        D.Closure memory closed = resolutions.closures[origin.recordHash];
        D.Closure memory empty;
        if (keccak256(abi.encode(closed)) == keccak256(abi.encode(empty))) {
            if (origin.contestedAt != 0) {
                revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
            }
            return 0;
        }
        D.Record memory first = resolutions.records[closed.dismissalRecordHash];
        D.Cause memory cause = resolutions.causes[first.terms.expectedCauseHash];
        if (first.terms.removePriorStanding
                ? first.terms.expectedRetirementHash == 0
                    || first.terms.expectedRetirementHash != cause.facts.actorRetirementHash
                : first.terms.expectedRetirementHash != 0) revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
        bytes32 previous = _previous(resolutions, e, cause);
        bytes32 original = Closed.beforeNext(
            rotations, resolutions, contests, e, origin, successor, terminalStagedAt
        );
        if (original == 0) revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ESTATE_ROTATION_ORIGIN_CLOSURE_V1"), original, previous
            )
        );
    }

    // Original living episodes may precede op40. Bind their actual admitted pair instead of
    // requiring zero history or replacing their incumbent with today's estate successor.
    function _previous(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        D.Cause memory cause
    ) private view returns (bytes32) {
        bytes32 previous = cause.facts.previousResolutionHash;
        if (previous == 0) {
            if (cause.facts.previousCauseHash != 0) {
                revert I.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
            }
            return 0;
        }
        D.Record memory r = resolutions.records[previous];
        D.Cause memory prior = resolutions.causes[cause.facts.previousCauseHash];
        if (
            r.recordHash != previous || r.terms.artistId != cause.facts.artistId
                || r.terms.evidenceHash == 0 || r.terms.reasonHash == 0 || r.executor == address(0)
                || r.proposer == address(0) || (r.actionClass != 1 && r.actionClass != 2)
                || r.actionId == 0 || r.cohortHash == 0 || r.governanceWitnessHash == 0
                || r.terms.expectedCauseHash != prior.causeHash || prior.causeHash == 0
                || prior.causeHash != cause.facts.previousCauseHash
                || prior.facts.artistId != cause.facts.artistId
                || (prior.facts.kind != 1 && prior.facts.kind != 2)
                || prior.facts.actor == address(0) || prior.facts.referenceHash == 0
                || prior.facts.incumbent == address(0) || prior.facts.enteredAt == 0
                || (prior.facts.kind == 1
                        ? prior.facts.evidenceHash == 0 || prior.facts.reasonHash == 0
                        : prior.facts.evidenceHash != 0)
                || r.terms.expectedResolutionHash != prior.facts.previousResolutionHash
                || r.incumbent != prior.facts.incumbent
                || r.authorityClass != prior.facts.authorityClass
                || !((r.authorityClass == 1
                        && ((prior.facts.priorStatus == 1 && r.restoredStatus == 1)
                            || (prior.facts.priorStatus == 2
                                && (r.restoredStatus == 1 || r.restoredStatus == 2))))
                    || ((r.authorityClass == 3 || r.authorityClass == 4)
                        && prior.facts.priorStatus == 3
                        && r.restoredStatus == 3))
                || (r.terms.removePriorStanding
                        ? r.terms.expectedRetirementHash == 0
                        || r.terms.expectedRetirementHash != prior.facts.actorRetirementHash
                        : r.terms.expectedRetirementHash != 0) || r.dismissedAt == 0
                || r.dismissedAt > cause.facts.enteredAt || prior.facts.enteredAt > r.dismissedAt
                || prior.causeHash != _causeHash(e, prior) || r.recordHash != _dismissalHash(e, r)
        ) revert I.UnsupportedIdentityRecoveryProfile(cause.facts.artistId);
        return keccak256(abi.encode(r, prior));
    }

    function _dismissalHash(StreamArtistHashes.Environment memory e, D.Record memory r)
        private
        view
        returns (bytes32)
    {
        address originalOwner = address(this);
        if (Imported.commitment() != 0) {
            Runtime.Context memory clock = Recovered.load(address(this), e.registry, e.chainId);
            Runtime.ReceiptFact memory row =
                Recovered.nativeFact(clock, 58, r.terms.artistId, r.recordHash);
            Runtime.ReplayFact memory replay = Runtime.replay(
                clock,
                RH.originHash(clock.current),
                keccak256("identity_authority.replay.contest_resolution"),
                keccak256(abi.encode(r.terms.artistId, r.terms.expectedCauseHash))
            );
            if (
                replay.cell.kind != 1 || replay.cell.status != 2
                    || replay.cell.commitment != r.recordHash
                    || !Recovered.samePoint(replay.admission.point, row.position.point)
            ) {
                revert RH.InvalidRecoveredHydrationProvenance();
            }
            e = Recovered.hashes(row.environment);
            originalOwner = row.environment.owners[2];
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_RECORD_V1"),
                e.chainId,
                e.registry,
                originalOwner,
                r.terms,
                r.executor,
                r.proposer,
                r.actionClass,
                r.actionId,
                r.incumbent,
                r.authorityClass,
                r.restoredStatus,
                r.dismissedAt,
                r.cohortHash,
                r.governanceWitnessHash
            )
        );
    }

    function _causeHash(StreamArtistHashes.Environment memory e, D.Cause memory cause)
        private
        view
        returns (bytes32)
    {
        address originalOwner = address(this);
        if (Imported.commitment() != 0) {
            Runtime.ReceiptFact memory row = Recovered.nativeFact(
                Recovered.load(address(this), e.registry, e.chainId),
                cause.facts.kind == 1 ? 33 : 31,
                cause.facts.artistId,
                cause.causeHash
            );
            e = Recovered.hashes(row.environment);
            originalOwner = row.environment.owners[2];
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                e.chainId,
                e.registry,
                originalOwner,
                cause.facts
            )
        );
    }
}
