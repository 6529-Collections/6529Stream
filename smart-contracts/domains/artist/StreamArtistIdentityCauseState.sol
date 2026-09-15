// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityDismissalState.sol";
import "./StreamArtistIdentityContestState.sol";

/// @notice Typed linked cause composition; the Identity checks and commits once around it.
library StreamArtistIdentityCauseState {
    function file(
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityContestState.State storage contests,
        StreamArtistSuccessionState.State storage succession,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Contest.Request memory p,
        Contest.GovernanceWitness memory governance,
        address executor
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        Dismissal.CauseFacts memory cause =
            StreamArtistIdentityDismissalState.causeFacts(
                resolutions,
                identity,
                rotations,
                p.artistId,
                1,
                bytes32(0),
                c.actor,
                p.reasonHash,
                p.evidenceHash
            );
        bytes32 successorRecord =
            StreamArtistSuccessionState.operativeDesignation(succession, rotations, p.artistId);
        m = StreamArtistIdentityContestState.fileWithResolution(
            contests,
            identity,
            rotations,
            replay,
            o,
            c,
            p,
            governance,
            executor,
            succession.designations[successorRecord].terms.successor,
            successorRecord,
            _facts(resolutions, rotations, p.artistId, p.subjectRecordHash),
            resolutions.standingJudgments[p.artistId][c.actor]
        );
        cause.referenceHash = m.record;
        bytes32 causeHash =
            StreamArtistIdentityDismissalState.capture(resolutions, o.environment, cause);
        m.state = keccak256(abi.encode(m.state, causeHash));
    }

    function context(
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityContestState.State storage contests,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityState.OwnerContext memory o,
        Contest.Request memory p
    ) public view returns (bytes32, bytes32, bytes32) {
        bytes32 successorRecord =
            StreamArtistSuccessionState.operativeDesignation(succession, rotations, p.artistId);
        return StreamArtistIdentityContestState.contextWithResolution(
            contests,
            identity,
            rotations,
            o,
            p,
            succession.designations[successorRecord].terms.successor,
            successorRecord,
            _facts(resolutions, rotations, p.artistId, p.subjectRecordHash)
        );
    }

    function veto(
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistSuccessionState.State storage succession,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        bytes32 artistId,
        bytes32 expected,
        bytes32 reasonHash
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        Dismissal.CauseFacts memory cause =
            StreamArtistIdentityDismissalState.causeFacts(
                resolutions,
                identity,
                rotations,
                artistId,
                2,
                expected,
                c.actor,
                reasonHash,
                bytes32(0)
            );
        bytes32 successorRecord =
            StreamArtistSuccessionState.operativeDesignation(succession, rotations, artistId);
        m = StreamArtistRotationState.vetoWithResolution(
            rotations,
            identity,
            replay,
            o,
            c,
            artistId,
            expected,
            reasonHash,
            succession.designations[successorRecord].terms.successor,
            resolutions.standingJudgments[artistId][c.actor]
        );
        bytes32 causeHash =
            StreamArtistIdentityDismissalState.capture(resolutions, o.environment, cause);
        m.state = keccak256(abi.encode(m.state, causeHash));
    }

    function _facts(
        StreamArtistIdentityResolutionState.State storage s,
        StreamArtistRotationState.State storage r,
        bytes32 artistId,
        bytes32 subject
    ) private view returns (Dismissal.ContestResolutionFacts memory facts) {
        facts.subjectClosure = s.closures[subject];
        facts.executedClosure = s.closures[r.latestExecution[artistId]];
        facts.currentCauseHash = s.currentCause[artistId];
        facts.currentResolutionHash = s.latestResolution[artistId];
    }
}
