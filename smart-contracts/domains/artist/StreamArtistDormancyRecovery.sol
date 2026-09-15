// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistIdentityRecoveryMutation } from "./StreamArtistIdentityRecoveryMutation.sol";
import { StreamArtistGuardianHistory as GuardianHistory } from "./StreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";

import { StreamArtistIdentityState } from "./StreamArtistIdentityState.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistIdentityResolutionState } from "./StreamArtistIdentityResolutionState.sol";
import { StreamArtistEstateState } from "./StreamArtistEstateState.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

import {
    StreamArtistIdentityRecoveryState as RecoveryState
} from "./StreamArtistIdentityRecoveryState.sol";
import { StreamArtistSuccessionState } from "./StreamArtistSuccessionState.sol";
import { StreamArtistIdentityContestState } from "./StreamArtistIdentityContestState.sol";

import "./StreamArtistDormancyState.sol";
import {
    StreamArtistRecoveryDormancyPredecessor as DormPredecessor
} from "./StreamArtistRecoveryDormancyPredecessor.sol";

import {
    StreamArtistRecoveryDormancyRotation as DormRotation
} from "./StreamArtistRecoveryDormancyRotation.sol";

/// @notice First designated dormancy recovery, retaining original recipes for all earlier profiles.
library StreamArtistDormancyRecovery {
    function context(
        RecoveryState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityContestState.State storage contests,
        StreamArtistIdentityState.OwnerContext memory o,
        Recovery.Request memory p,
        T.Authorization memory acceptance
    ) public view returns (Recovery.Context memory) {
        if (dormancy.activation[p.artistId] == 0 || s.latest[p.artistId] != 0) {
            return RecoveryState.contextWithEstate(
                s, identity, rotations, resolutions, estate, succession, contests, o, p, acceptance
            );
        }
        return _context(
            s,
            identity,
            rotations,
            resolutions,
            estate,
            dormancy,
            succession,
            contests,
            o,
            p,
            acceptance
        );
    }

    function contextEncoded(
        RecoveryState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityContestState.State storage contests,
        StreamArtistIdentityState.OwnerContext memory o,
        Recovery.Request memory p,
        T.Authorization memory acceptance
    ) public view returns (bytes memory) {
        return abi.encode(
            context(
                s,
                identity,
                rotations,
                resolutions,
                estate,
                dormancy,
                succession,
                contests,
                o,
                p,
                acceptance
            )
        );
    }

    function recover(
        RecoveryState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityContestState.State storage contests,
        mapping(bytes32 => T.ReplayCell) storage replay,
        RecoveryState.Input memory i
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        Recovery.Context memory c = context(
            s,
            identity,
            rotations,
            resolutions,
            estate,
            dormancy,
            succession,
            contests,
            i.owner,
            i.request,
            i.acceptance
        );
        return StreamArtistIdentityRecoveryMutation.recover(
            s, identity, rotations, resolutions, estate, replay, i, c
        );
    }

    function prepare(
        RecoveryState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityContestState.State storage contests,
        mapping(bytes32 => T.ReplayCell) storage replay,
        RecoveryState.PrepareInput memory i
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 associationHash) {
        if (dormancy.activation[i.request.artistId] == 0 || s.latest[i.request.artistId] != 0) {
            return RecoveryState.prepareWithEstate(
                s, identity, rotations, resolutions, estate, succession, contests, replay, i
            );
        }
        Recovery.Context memory c = context(
            s,
            identity,
            rotations,
            resolutions,
            estate,
            dormancy,
            succession,
            contests,
            i.owner,
            i.request,
            i.acceptance
        );
        (, R.GuardianRecord memory guardian) = _facts(
            s,
            dormancy,
            estate,
            rotations,
            resolutions,
            succession,
            contests,
            i.owner.environment,
            resolutions.causes[resolutions.currentCause[i.request.artistId]],
            i.request
        );
        return StreamArtistIdentityRecoveryMutation.prepareWithGuardian(
            s, rotations, replay, i, c, guardian
        );
    }

    function _facts(
        RecoveryState.State storage s,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistEstateState.State storage estate,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityContestState.State storage contests,
        StreamArtistHashes.Environment memory e,
        Dismissal.Cause memory cause,
        Recovery.Request memory p
    ) private view returns (bytes32, R.GuardianRecord memory) {
        // Both context and preparation consume the same selected origin/terminal and guardian proof.
        if (rotations.latestExecution[p.artistId] != dormancy.activation[p.artistId]) {
            return DormRotation.facts(
                s, dormancy, estate, rotations, resolutions, succession, contests, e, cause, p
            );
        }
        return DormPredecessor.facts(
            s, dormancy, estate, rotations, resolutions, succession, contests, e, cause, p
        );
    }

    function _context(
        RecoveryState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistEstateState.State storage estate,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityContestState.State storage contests,
        StreamArtistIdentityState.OwnerContext memory o,
        Recovery.Request memory p,
        T.Authorization memory acceptance
    ) private view returns (Recovery.Context memory c) {
        Dismissal.Cause memory cause = resolutions.causes[resolutions.currentCause[p.artistId]];
        T.Identity storage principal = identity.identities[p.artistId];
        if (
            p.artistId == bytes32(0) || cause.causeHash == bytes32(0)
                || cause.causeHash != p.expectedCauseHash || cause.facts.artistId != p.artistId
                || cause.facts.kind != 1 || cause.facts.referenceHash == bytes32(0)
                || cause.facts.actor == address(0) || cause.facts.incumbent == address(0)
                || principal.status != 4 || principal.authorityClass != cause.facts.authorityClass
                || principal.authorityAddress != cause.facts.incumbent
                || identity.activeIdentity[principal.authorityAddress] != p.artistId
                || resolutions.latestResolution[p.artistId] != p.expectedResolutionHash
                || cause.facts.previousResolutionHash != p.expectedResolutionHash
                || p.newAddress == address(0) || p.newAddress == principal.authorityAddress
                || p.evidenceHash == bytes32(0) || p.reasonHash == bytes32(0)
        ) revert Recovery.InvalidIdentityRecovery(p.artistId);
        if (
            p.vestedAuthorityClass != 3 || cause.facts.authorityClass != 3
                || cause.facts.priorStatus != 3 || rotations.pending[p.artistId] != bytes32(0)
                || cause.facts.pendingTransitionHash != bytes32(0)
                || s.latest[p.artistId] != bytes32(0)
        ) revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        if (p.supersededRecordHashes.length != 0) {
            revert Recovery.UnsupportedIdentityRecoveryProfile(p.artistId);
        }
        (bytes32 predecessor, R.GuardianRecord memory guardian) = _facts(
            s,
            dormancy,
            estate,
            rotations,
            resolutions,
            succession,
            contests,
            o.environment,
            cause,
            p
        );
        if (identity.activeIdentity[p.newAddress] != bytes32(0)) {
            revert T.AddressAlreadyRegistered(p.newAddress);
        }
        c.causeHash = cause.causeHash;
        c.incumbent = principal.authorityAddress;
        c.postContestSeconds = StreamArtistRotationState.rotationSeconds(rotations);
        if (guardian.terms.minContestSeconds > c.postContestSeconds) {
            c.postContestSeconds = guardian.terms.minContestSeconds;
        }
        c.standingTailSeconds = StreamArtistRotationState.standingSeconds(rotations);
        c.timingRevision = rotations.timingRevision == 0 ? 1 : rotations.timingRevision;
        c.delegationEpoch = estate.delegationEpoch[p.artistId];
        c.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_SCOPE_V2"),
                o.environment.chainId,
                o.environment.registry,
                address(this),
                p.artistId
            )
        );
        c.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_STATE_V2"),
                c.scopeHash,
                cause,
                principal,
                p.expectedResolutionHash,
                c.postContestSeconds,
                c.standingTailSeconds,
                c.timingRevision,
                c.delegationEpoch
            )
        );
        // Registration changes owner revision, but never these scheduled transition facts.
        if (guardian.recordHash != bytes32(0)) {
            c.oldValueHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_GUARDED_RECOVERY_STATE_V1"),
                    c.oldValueHash,
                    guardian,
                    s.guardianRecordsSeen[p.artistId]
                )
            );
        }
        if (guardian.recordHash != bytes32(0)) {
            GH.Head memory history = GuardianHistory.requireComplete(
                s.guardianHistory, p.artistId, s.guardianRecordsSeen[p.artistId]
            );
            c.oldValueHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_CONTEXT_V1"),
                    c.oldValueHash,
                    history
                )
            );
        }
        c.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_DORMANCY_CONTEXT_V1"),
                c.oldValueHash,
                predecessor
            )
        );
        c.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_RECOVERY_INTENT_V2"),
                c.scopeHash,
                c.oldValueHash,
                p,
                acceptance.nonce,
                acceptance.time
            )
        );
    }
}
