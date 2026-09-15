// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "./StreamArtistIdentityDismissalTypes.sol";
import "./IStreamArtistIdentityContest.sol";

/// @notice Events emitted by the sole Identity owner.
interface IStreamArtistIdentityDismissalEvents {
    event ArtistIdentityContestCauseCaptured(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed causeHash,
        uint8 kind,
        bytes32 referenceHash,
        address actor,
        bytes32 reasonHash,
        bytes32 evidenceHash,
        uint64 enteredAt,
        address incumbent,
        uint8 authorityClass,
        uint8 priorStatus,
        bytes32 pendingTransitionHash,
        bytes32 executedTransitionHash,
        bytes32 previousCauseHash,
        bytes32 previousResolutionHash,
        bytes32 actorRetirementHash
    );
    event ArtistIdentityContestDismissed(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed causeHash,
        bytes32 indexed dismissalRecordHash,
        bytes32 previousDismissalRecordHash,
        address executor,
        address proposer,
        uint8 actionClass,
        bytes32 actionId,
        address incumbent,
        uint8 authorityClass,
        uint8 restoredStatus,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        bool removePriorStanding,
        bytes32 retiredTransitionRecordHash,
        uint64 dismissedAt,
        bytes32 cohortHash,
        bytes32 governanceWitnessHash,
        bytes32 revisionContinuationHead
    );
}

/// @notice Governed resolution of an actual Identity-owned compromise or veto cause.
interface IStreamArtistIdentityDismissal is IStreamArtistIdentityDismissalEvents {
    function dismissArtistIdentityContest(Dismissal.Request calldata request)
        external
        returns (bytes32);
    function identityContestDismissalContext(Dismissal.Request calldata request)
        external
        view
        returns (Dismissal.Context memory);
    function currentIdentityContestCause(bytes32 artistId)
        external
        view
        returns (Dismissal.Cause memory);
    function identityContestCause(bytes32 causeHash) external view returns (Dismissal.Cause memory);
    function identityContestDismissalRecord(bytes32 recordHash)
        external
        view
        returns (Dismissal.Record memory);
    function latestIdentityContestDismissal(bytes32 artistId) external view returns (bytes32);
    function identityTransitionClosure(bytes32 artistId, bytes32 transitionRecordHash)
        external
        view
        returns (Dismissal.Closure memory);
    function identityRevisionContinuation(bytes32 continuationHash)
        external
        view
        returns (Dismissal.RevisionContinuation memory);
}

interface IStreamArtistIdentityDismissalOwner {
    function identityContestDismissalContext(Dismissal.Request calldata p)
        external
        view
        returns (Dismissal.Context memory);
    function currentIdentityContestCause(bytes32 artistId)
        external
        view
        returns (Dismissal.Cause memory);
    function identityContestCause(bytes32 causeHash) external view returns (Dismissal.Cause memory);
    function identityContestDismissalRecord(bytes32 recordHash)
        external
        view
        returns (Dismissal.Record memory);
    function latestIdentityContestDismissal(bytes32 artistId) external view returns (bytes32);
    function identityTransitionClosure(bytes32 artistId, bytes32 transitionRecordHash)
        external
        view
        returns (Dismissal.Closure memory);
    function identityRevisionContinuation(bytes32 continuationHash)
        external
        view
        returns (Dismissal.RevisionContinuation memory);
    function dismissIdentityContest(
        T.ActionContext calldata c,
        Dismissal.Request calldata p,
        Contest.GovernanceWitness calldata governance
    ) external returns (bytes32);
}

interface IStreamArtistIdentityDismissalCoordinator {
    function coordinateDismissArtistIdentityContest(address actor, Dismissal.Request calldata p)
        external
        returns (bytes32);
}
