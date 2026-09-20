// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryState as State
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolution
} from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import { StreamArtistLivingRecoveryReads as Living } from "./StreamArtistLivingRecoveryReads.sol";
import { StreamArtistLivingDormancyReads as Ancestry } from "./StreamArtistLivingDormancyReads.sol";
import {
    StreamArtistRecoveryRotationClosure as Closed
} from "./StreamArtistRecoveryRotationClosure.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistGuardianVestingTypes as V
} from "../../interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as I
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Actual living35 history carried across a later designated dormancy boundary.
/// @dev Operations32/35/43 retain the saved cause/resolution heads. Only actual cause captures
/// and dismissals change them. Read those immutable links; never fabricate an empty boundary.
library StreamArtistLivingDormancyBoundary {
    struct Facts {
        bytes32 proof;
        bytes32 cause;
        bytes32 resolution;
    }

    function facts(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dorm.Notice memory notice,
        Dorm.Terminal memory terminal,
        V.Snapshot memory origin,
        D.Cause memory current
    ) public view returns (Facts memory f) {
        bytes32 latest = recovery.latest[origin.artistId];
        if (latest == 0) return f;
        (Living.Facts memory living, bytes32 ancestry) = Ancestry.beforeDormancy(
            address(this), e.registry, e.chainId, notice, terminal, origin, latest
        );
        if (ancestry == 0) revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
        D.Cause memory first = _first(resolutions, e, terminal, current);
        f.cause = first.facts.previousCauseHash;
        f.resolution = first.facts.previousResolutionHash;
        bytes32 episodes = _episodes(recovery, rotations, resolutions, e, notice, origin, living, f);
        bytes32 closures =
            _closures(recovery, rotations, resolutions, e, notice, origin, living, f.resolution);
        f.proof = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_LIVING_DORMANCY_BOUNDARY_V1"),
                ancestry,
                closures,
                episodes,
                f.cause,
                f.resolution
            )
        );
    }

    function _first(
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dorm.Terminal memory terminal,
        D.Cause memory current
    ) private view returns (D.Cause memory first) {
        first = current;
        while (true) {
            _cause(e, first, current.facts.artistId);
            if (
                first.facts.authorityClass != 3 || first.facts.priorStatus != 3
                    || first.facts.enteredAt < terminal.observedAt
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
            }
            D.Cause memory previous = resolutions.causes[first.facts.previousCauseHash];
            if (previous.facts.authorityClass != 3) return first;
            if (
                previous.causeHash != first.facts.previousCauseHash
                    || previous.facts.enteredAt > first.facts.enteredAt
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(current.facts.artistId);
            }
            // Canonical hash-linked immutable causes cannot form a cycle.
            first = previous;
        }
    }

    function _closures(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dorm.Notice memory notice,
        V.Snapshot memory origin,
        Living.Facts memory living,
        bytes32 boundaryResolution
    ) private view returns (bytes32 proof) {
        bytes32 cursor = origin.previousTransitionRecordHash;
        uint64 nextAt = notice.initiatedAt;
        bytes32 stagedPrevious;
        while (true) {
            V.Snapshot memory v = recovery.vestingHistory.snapshots[cursor];
            R.TransitionState memory t = cursor == living.record.recordHash
                ? recovery.transitions[cursor]
                : rotations.rotations[cursor].transition;
            bytes32 closure =
                Closed.beforeNext(rotations, resolutions, e, t, v.newAddress, nextAt, 1);
            if (closure != 0) {
                bytes32 selected = boundaryResolution;
                bytes32 first = resolutions.closures[cursor].dismissalRecordHash;
                // _episodes already authenticated every selected link. Each original closure
                // must appear on that chain, including independently closed intermediate32s.
                while (
                    selected != first && selected != living.record.terms.expectedResolutionHash
                ) {
                    selected = resolutions.records[selected].terms.expectedResolutionHash;
                }
                if (selected != first) {
                    revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
                }
            }
            bytes32 pendingProof;
            if (stagedPrevious != 0 && stagedPrevious != cursor) {
                pendingProof = Closed.pendingBeforeNext(
                    rotations, resolutions, e, t, stagedPrevious, v.newAddress, nextAt, 1
                );
                if (closure == 0) revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
            }
            proof = keccak256(abi.encode(proof, cursor, closure, pendingProof));
            if (cursor == living.record.recordHash) return proof;
            stagedPrevious = rotations.rotations[cursor].terms.expectedPreviousTransitionRecordHash;
            if (stagedPrevious == 0) revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
            nextAt = t.stagedAt;
            cursor = v.previousTransitionRecordHash;
        }
    }

    function _episodes(
        State.State storage recovery,
        Rotations.State storage rotations,
        Resolution.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dorm.Notice memory notice,
        V.Snapshot memory origin,
        Living.Facts memory living,
        Facts memory boundary
    ) private view returns (bytes32 proof) {
        bytes32 causeHash = boundary.cause;
        bytes32 resolutionHash = boundary.resolution;
        uint64 nextAt = notice.initiatedAt;
        while (causeHash != living.record.terms.expectedCauseHash) {
            D.Cause memory cause = resolutions.causes[causeHash];
            _cause(e, cause, origin.artistId);
            if (
                cause.causeHash != causeHash || cause.facts.authorityClass != 1
                    || cause.facts.priorStatus != 1
                    || cause.facts.enteredAt < living.record.fields.recoveredAt
                    || cause.facts.enteredAt > nextAt
            ) {
                revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
            }
            V.Snapshot memory v = _member(
                recovery, origin, living.record.recordHash, cause.facts.executedTransitionHash
            );
            R.TransitionState memory t = v.transitionRecordHash == living.record.recordHash
                ? living.transition
                : rotations.rotations[v.transitionRecordHash].transition;
            bytes32 episode = Closed.resolvedBeforeNext(
                rotations, resolutions, e, t, v.newAddress, nextAt, causeHash, resolutionHash
            );
            proof = keccak256(abi.encode(proof, episode));
            nextAt = cause.facts.enteredAt;
            causeHash = cause.facts.previousCauseHash;
            resolutionHash = cause.facts.previousResolutionHash;
        }
        if (resolutionHash != living.record.terms.expectedResolutionHash) {
            revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
        }
    }

    function _member(
        State.State storage recovery,
        V.Snapshot memory origin,
        bytes32 living,
        bytes32 hash
    ) private view returns (V.Snapshot memory v) {
        bytes32 cursor = origin.previousTransitionRecordHash;
        while (true) {
            v = recovery.vestingHistory.snapshots[cursor];
            if (cursor == hash) return v;
            if (cursor == living) revert I.UnsupportedIdentityRecoveryProfile(origin.artistId);
            cursor = v.previousTransitionRecordHash;
        }
    }

    function _cause(StreamArtistHashes.Environment memory e, D.Cause memory c, bytes32 artistId)
        private
        view
    {
        if (
            c.causeHash == 0 || c.facts.artistId != artistId
                || c.causeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                            e.chainId,
                            e.registry,
                            address(this),
                            c.facts
                        )
                    )
        ) {
            revert I.UnsupportedIdentityRecoveryProfile(artistId);
        }
    }
}
