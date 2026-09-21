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

/// @notice Exact original complete read proof in the unchanged library caller context.
library StreamArtistCurrentEstateCompromiseReads {
    function pendingEstate(
        Shape.Environment memory e,
        D.Cause memory current,
        R.TransitionState memory executed,
        C.Record memory contest,
        bool live
    ) public view returns (bytes32) {
        bytes32 artistId = current.facts.artistId;
        bytes32 hash = current.facts.pendingTransitionHash;
        if (current.facts.kind != 1 || current.facts.authorityClass != 1 || hash == 0) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        }
        uint64 revision = Stages.compromiseRevision(
            e.owner, e.registry, e.chainId, artistId, contest.recordHash
        );
        Stages.EstateFacts memory estate = Recovered.active(e.owner)
            ? Stages.cancelledEstateAt(
                e.owner,
                e.registry,
                e.chainId,
                artistId,
                hash,
                Stages.compromisePoint(e.owner, e.registry, e.chainId, artistId, contest.recordHash)
            )
            : Stages.cancelledEstate(e.owner, e.registry, e.chainId, artistId, hash, revision);
        (address successor, uint64 noticeEndsAt, bytes32 activation) =
            IStreamArtistEstateOwner(e.owner).estateActivationState(artistId);
        (address old_, address new_, uint64 ends, uint32 approvals, bytes32 pending) =
            IStreamArtistRotationReads(e.owner).pendingRotation(artistId);
        D.Closure memory closed =
            IStreamArtistIdentityDismissalOwner(e.owner).identityTransitionClosure(artistId, hash);
        D.Closure memory emptyClosure;
        R.RotationRecord memory emptyRotation;
        if (
            hash == executed.recordHash
                || (live
                    && IStreamArtistRotationReads(e.owner).lastArtistTransition(artistId) != hash)
                || estate.request.incumbent != current.facts.incumbent
                || estate.request.requestedAt < executed.executedAt
                || estate.request.requestedAt > current.facts.enteredAt
                || estate.transition.contestedAt != current.facts.enteredAt
                || estate.cancellationReplay.touchedRevision != revision
                || contest.capturedGuardianSetRecordHash != estate.request.guardianRecordHash
                || (live
                    && (successor != address(0)
                        || noticeEndsAt != 0
                        || activation != 0
                        || old_ != address(0)
                        || new_ != address(0)
                        || ends != 0
                        || approvals != 0
                        || pending != 0))
                || keccak256(abi.encode(closed)) != keccak256(abi.encode(emptyClosure))
                || keccak256(abi.encode(IStreamArtistRotationReads(e.owner).rotationRecord(hash)))
                    != keccak256(abi.encode(emptyRotation))
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(artistId);
        return keccak256(abi.encode(estate.proof, revision, closed));
    }
}
