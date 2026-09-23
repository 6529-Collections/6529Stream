// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityRuntime as Identity
} from "./StreamArtistRecoveredIdentityRuntime.sol";
import {
    StreamArtistRecoveredRuntimeReads as Runtime
} from "./StreamArtistRecoveredRuntimeReads.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as D
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Original continuation prerequisites for fresh operation25/51 after recovered import.
/// @dev The fixed writer supplies its own stored continuation and actual current revision.
/// Hashes and mutation points prove original creation; authorization remains in the current writer.
library StreamArtistRecoveredContinuationWrites {
    function revision(
        Hashes.Environment memory e,
        uint64 currentRevision,
        W.RevisionContinuationV3 memory r
    ) public view {
        _revision(_current(e, currentRevision), r);
    }

    function standing(
        Hashes.Environment memory e,
        uint64 currentRevision,
        W.StandingContinuationV3 memory r
    ) public view {
        Runtime.Context memory c = _current(e, currentRevision);
        Runtime.OriginFact memory original = Runtime.auxiliary(
            c,
            keccak256("identity_authority.hydration.standing_continuation_v3"),
            r.continuationHash
        );
        if (
            r.ownerRevision != original.point.ownerRevision
                || W.standingContinuationHash(Runtime.rewindEnvironment(original.environment), r)
                    != r.continuationHash
        ) revert T.InvalidRecord();
        _producer(c, r.artistId, r.recoveryRecordHash, original.point);
    }

    function laterDismissal(
        Hashes.Environment memory e,
        uint64 currentRevision,
        D.RevisionContinuation memory legacy,
        D.Record memory dismissed,
        W.RevisionContinuationV3 memory recovery,
        T.ReplayCell memory consumed
    ) public view returns (bool) {
        Runtime.Context memory c = _current(e, currentRevision);
        RH.Point memory first = _revision(c, recovery);
        Runtime.OriginFact memory last = Runtime.auxiliary(
            c,
            keccak256("identity_authority.hydration.dismissal_continuation"),
            legacy.continuationHash
        );
        Runtime.ReceiptFact memory receipt =
            Identity.nativeFact(c, 58, legacy.artistId, legacy.dismissalRecordHash);
        Runtime.ReplayFact memory replay = Runtime.replay(
            c,
            RH.originHash(c.current),
            keccak256("identity_authority.replay.contest_resolution"),
            keccak256(abi.encode(legacy.artistId, dismissed.terms.expectedCauseHash))
        );
        if (
            legacy.artistId != recovery.artistId
                || dismissed.recordHash != legacy.dismissalRecordHash
                || dismissed.revisionContinuationHead != legacy.continuationHash
                || !Identity.samePoint(last.point, receipt.position.point)
                || !Identity.samePoint(last.point, replay.admission.point)
                || keccak256(abi.encode(consumed)) != keccak256(abi.encode(replay.cell))
                || replay.cell.kind != 1 || replay.cell.status != 2
                || replay.cell.commitment != dismissed.recordHash
                || legacy.continuationHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_IDENTITY_REVISION_CONTINUATION_V1"),
                            last.environment.chainId,
                            last.environment.registry,
                            last.environment.owners[2],
                            legacy.artistId,
                            legacy.dismissalRecordHash,
                            legacy.previousContinuationHash,
                            legacy.stableRevisionRecordHash,
                            legacy.stableDocumentHash,
                            legacy.abandonedRevisionRecordHash
                        )
                    )
        ) revert T.InvalidRecord();
        return Runtime.before(c, first, last.point);
    }

    function _revision(Runtime.Context memory c, W.RevisionContinuationV3 memory r)
        private
        view
        returns (RH.Point memory)
    {
        Runtime.OriginFact memory original = Runtime.auxiliary(
            c,
            keccak256("identity_authority.hydration.revision_continuation_v3"),
            r.continuationHash
        );
        if (
            r.ownerRevision != original.point.ownerRevision
                || W.revisionContinuationHash(Runtime.rewindEnvironment(original.environment), r)
                    != r.continuationHash
        ) revert T.InvalidRecord();
        _producer(c, r.artistId, r.recoveryRecordHash, original.point);
        return original.point;
    }

    function _producer(
        Runtime.Context memory c,
        bytes32 artistId,
        bytes32 recovery,
        RH.Point memory point
    ) private view {
        Runtime.ReceiptFact memory created = Identity.nativeFact(c, 35, artistId, recovery);
        if (!Identity.samePoint(created.position.point, point)) revert T.InvalidRecord();
    }

    function _current(Hashes.Environment memory e, uint64 revision_)
        private
        view
        returns (Runtime.Context memory c)
    {
        c = Identity.load(address(this), e.registry, e.chainId);
        if (
            c.importCommitment == 0 || c.current.core != e.core || c.current.manager != e.manager
                || c.checkpoint.ownerState.revision != revision_
        ) revert RH.InvalidRecoveredHydrationProvenance();
    }
}
