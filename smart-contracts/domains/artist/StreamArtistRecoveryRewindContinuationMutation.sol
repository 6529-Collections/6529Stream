// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryRewindState as Rewind } from "./StreamArtistRecoveryRewindState.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistIdentityRevisionState as Revisions
} from "./StreamArtistIdentityRevisionState.sol";
import {
    StreamArtistIdentityRevisionTypes as Revision
} from "../../interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import { StreamArtistIdentityState as Identity } from "./StreamArtistIdentityState.sol";
import { StreamArtistRotationState as Rotations } from "./StreamArtistRotationState.sol";
import {
    StreamArtistIdentityResolutionState as Resolutions
} from "./StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistIdentityDismissalState as DismissalState
} from "./StreamArtistIdentityDismissalState.sol";
import {
    StreamArtistEstateEntryMutation as OriginalEntry
} from "./StreamArtistEstateEntryMutation.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";

/// @notice Fresh original25/51 writes after an authenticated recovery rewind.
/// @dev Never clears an original replay cell or replaces a historical record. The fixed
/// owner selects these stored continuations; no caller supplies a branch-opening witness.
library StreamArtistRecoveryRewindContinuationMutation {
    function reviseEncoded(
        Rewind.State storage rewind,
        Revisions.State storage revisions,
        Identity.State storage identity,
        Rotations.State storage rotations,
        Resolutions.State storage resolutions,
        mapping(bytes32 => T.ReplayCell) storage replay,
        Identity.OwnerContext memory o,
        bytes calldata data
    ) public returns (Identity.Mutation memory m) {
        (
            T.ActionContext memory c,
            Revision.Revision memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof,
            bytes memory document,
            string memory displayName
        ) = abi.decode(
            data[4:],
            (T.ActionContext, Revision.Revision, T.Authorization, T.SignerApproval, bytes, string)
        );
        D.RevisionContinuation memory legacy =
            resolutions.continuations[resolutions.continuationHead[p.artistId]];
        W.RevisionContinuationV3 memory recovery =
            rewind.revisionContinuations[rewind.revisionHead[p.artistId]];
        // An actual later dismissal can resolve a fresh child authored after this recovery.
        // Its new original continuation then wins for that same predecessor; the spent
        // recovery key cannot shadow the later original adjudication.
        if (
            recovery.continuationHash != 0 && legacy.continuationHash != 0
                && legacy.stableRevisionRecordHash == recovery.stableRevisionRecordHash
                && legacy.stableDocumentHash == recovery.stableDocumentHash
        ) {
            D.Record memory dismissed = resolutions.records[legacy.dismissalRecordHash];
            bytes32 key = _key(
                o,
                keccak256("identity_authority.replay.contest_resolution"),
                keccak256(abi.encode(p.artistId, dismissed.terms.expectedCauseHash))
            );
            T.ReplayCell memory consumed = replay[key];
            if (
                dismissed.recordHash != legacy.dismissalRecordHash
                    || dismissed.terms.artistId != p.artistId
                    || consumed.commitment != dismissed.recordHash || consumed.kind != 1
                    || consumed.status != 2 || consumed.touchedRevision == 0
                    || consumed.touchedRevision > o.revision
            ) revert T.InvalidRecord();
            if (consumed.touchedRevision > recovery.ownerRevision) delete recovery;
        }
        m = Revisions.reviseWithRecoveryResolution(
            revisions,
            identity,
            rotations,
            replay,
            o,
            c,
            p,
            a,
            proof,
            document,
            displayName,
            resolutions.closures[rotations.latestExecution[p.artistId]],
            legacy,
            recovery
        );
        if (recovery.continuationHash != 0) {
            Revision.Record memory item = revisions.records[m.record];
            bytes32 key = _key(
                o,
                keccak256("identity_authority.replay.identity_revision_recovery_continuation"),
                keccak256(
                    abi.encode(
                        p.artistId,
                        item.previousRevisionRecord,
                        p.previousRecordHash,
                        recovery.continuationHash
                    )
                )
            );
            T.ReplayCell memory used = replay[key];
            if (
                used.commitment == m.record && used.touchedRevision == o.revision + 1
                    && used.kind == 1 && used.status == 2
            ) {
                if (rewind.revisionRecordContinuations[m.record] != 0) {
                    revert T.InvalidRecord();
                }
                rewind.revisionRecordContinuations[m.record] = recovery.continuationHash;
                m.state = keccak256(abi.encode(m.state, m.record, recovery.continuationHash));
            }
        }
    }

    function revokeEncoded(
        Rewind.State storage rewind,
        Resolutions.State storage resolutions,
        Rotations.State storage rotations,
        Identity.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        Identity.OwnerContext memory o,
        bytes calldata encoded
    ) public returns (Identity.Mutation memory m) {
        (
            T.ActionContext memory c,
            R.StandingRevocation memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof
        ) = abi.decode(
            encoded, (T.ActionContext, R.StandingRevocation, T.Authorization, T.SignerApproval)
        );
        bytes32 scope =
            Rewind.standingScope(p.artistId, p.revokedAddress, p.retiredTransitionRecordHash);
        bytes32 hash = rewind.standingHeads[scope];
        if (hash == 0) {
            return
                OriginalEntry.revokeStanding(resolutions, rotations, identity, replay, o, encoded);
        }
        W.StandingContinuationV3 memory continuation = rewind.standingContinuations[hash];
        if (
            continuation.continuationHash != hash || continuation.artistId != p.artistId
                || continuation.priorAddress != p.revokedAddress
                || continuation.retirementHash != p.retiredTransitionRecordHash
                || continuation.retirementHash != rotations.retirement[p.artistId][p.revokedAddress]
                || continuation.recoveryRecordHash == 0 || continuation.ownerRevision == 0
                || continuation.ownerRevision > o.revision
        ) revert T.InvalidRecord();
        (bool revoked,) =
            DismissalState.standingRevoked(resolutions, rotations, p.artistId, p.revokedAddress);
        if (revoked) revert R.InvalidPriorStanding(p.revokedAddress);
        m = Rotations.revokeStandingWithRecovery(
            rotations, identity, replay, o, c, p, a, proof, hash
        );
        if (rewind.standingRecordContinuations[m.record] != 0) revert T.InvalidRecord();
        rewind.standingRecordContinuations[m.record] = hash;
        m.state = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_STANDING_RECOVERY_CONTINUATION_WRITE_V3"),
                m.state,
                m.record,
                hash
            )
        );
    }

    function _key(Identity.OwnerContext memory o, bytes32 surface, bytes32 scope)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                surface,
                scope
            )
        );
    }
}
