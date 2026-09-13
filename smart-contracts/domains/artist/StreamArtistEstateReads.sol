// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEstateState.sol";
import "./StreamArtistIdentityResolutionState.sol";

/// @notice Selection from actual Identity storage before its estate mutations.
library StreamArtistEstateReads {
    function requestFacts(
        StreamArtistEstateState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityResolutionState.State storage resolutions,
        Estate.Request memory p,
        bytes32 envelopeHash
    ) public view returns (Estate.RequestFacts memory f) {
        _living(identity, p.artistId);
        if (envelopeHash == bytes32(0) || p.selectedCoverageHash == bytes32(0)) {
            revert Estate.InvalidEstateCoverage(p.selectedCoverageHash);
        }
        if (s.pending[p.artistId] != bytes32(0)) {
            revert Estate.EstateActivationPending(s.pending[p.artistId]);
        }
        (bytes32 active, uint64 end,) = StreamArtistRotationState.activeWindowWithResolution(
            rotations, p.artistId, resolutions.closures[rotations.latestExecution[p.artistId]]
        );
        if (active != bytes32(0)) revert R.ActiveAuthorityWindow(active, end);
        f.designationRecordHash =
            StreamArtistSuccessionState.operativeDesignation(succession, rotations, p.artistId);
        Succ.DesignationRecord storage designation =
            succession.designations[f.designationRecordHash];
        if (
            f.designationRecordHash == bytes32(0)
                || f.designationRecordHash != p.expectedDesignationRecordHash
                || designation.terms.successor != p.successor
                || designation.terms.artistId != p.artistId
        ) {
            revert Succ.InvalidSuccessor();
        }
        f.pairedDirectiveRecordHash = designation.terms.directiveHash;
        f.forbiddenDirectiveRecordHash =
            StreamArtistSuccessionState.operativeDirective(succession, rotations, p.artistId);
        StreamArtistEstateState.activationCapabilities(
            succession, f.designationRecordHash, f.forbiddenDirectiveRecordHash
        );
        f.guardianRecordHash = StreamArtistRotationState.operativeGuardian(rotations, p.artistId);
        f.envelopeHash = envelopeHash;
        (f.noticeSeconds,, f.noticeRevision) = StreamArtistEstateState.timing(s);
        f.postContestSeconds = StreamArtistRotationState.rotationSeconds(rotations);
        uint64 guardianFloor = rotations.guardians[f.guardianRecordHash].terms.minContestSeconds;
        if (guardianFloor > f.postContestSeconds) f.postContestSeconds = guardianFloor;
        f.standingTailSeconds = StreamArtistRotationState.standingSeconds(rotations);
        f.rotationTimingRevision = rotations.timingRevision == 0 ? 1 : rotations.timingRevision;
    }

    function executionFacts(
        StreamArtistEstateState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Estate.Execution memory p,
        bytes32 envelopeHash
    ) public view returns (uint32 capabilities, Estate.AccelerationContext memory x) {
        _living(identity, p.artistId);
        Estate.RequestRecord storage item = s.requests[p.expectedActivationRecordHash];
        if (
            p.expectedActivationRecordHash == bytes32(0)
                || s.pending[p.artistId] != p.expectedActivationRecordHash
                || s.phases[p.expectedActivationRecordHash] != 1
                || item.terms.artistId != p.artistId
                || s.transitions[p.expectedActivationRecordHash].contestedAt != 0
                || item.incumbent != identity.identities[p.artistId].authorityAddress
                || s.livingActivity[p.artistId] != item.livingActivity
                || rotations.pending[p.artistId] != bytes32(0)
        ) {
            revert Estate.InvalidEstateActivation(p.expectedActivationRecordHash);
        }
        if (
            p.currentCoverageHash == bytes32(0) || envelopeHash == bytes32(0)
                || envelopeHash != item.envelopeHash
        ) {
            revert Estate.InvalidEstateCoverage(p.currentCoverageHash);
        }
        // Request-time admission required no prior active cohort. Recheck its actual execution
        // and immutable closure directly; the current pending request itself is not this prior cohort.
        bytes32 previous = rotations.latestExecution[p.artistId];
        if (previous != bytes32(0)) {
            R.TransitionState memory prior =
                StreamArtistRotationState.transitionState(rotations, previous);
            if (prior.artistId != p.artistId) revert T.InvalidIdentity(p.artistId);
            Dismissal.Closure memory closed = resolutions.closures[previous];
            if (
                closed.dismissalRecordHash == bytes32(0)
                    && (block.timestamp < prior.postWindowEndsAt
                        || (prior.contestedAt != 0 && prior.contestedAt < prior.postWindowEndsAt))
            ) {
                revert R.ActiveAuthorityWindow(previous, prior.postWindowEndsAt);
            }
        }
        bytes32 designation =
            StreamArtistSuccessionState.operativeDesignation(succession, rotations, p.artistId);
        if (
            designation != item.designationRecordHash || designation == bytes32(0)
                || succession.designations[designation].terms.successor != item.terms.successor
        ) revert Succ.InvalidSuccessor();
        bytes32 forbidden =
            StreamArtistSuccessionState.operativeDirective(succession, rotations, p.artistId);
        capabilities =
            StreamArtistEstateState.activationCapabilities(succession, designation, forbidden);
        x.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ESTATE_ACCELERATION_SCOPE_V1"),
                e.chainId,
                e.registry,
                address(this),
                p.artistId,
                p.expectedActivationRecordHash
            )
        );
        x.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ESTATE_ACCELERATION_STATE_V1"),
                x.scopeHash,
                item,
                identity.identities[p.artistId],
                s.livingActivity[p.artistId],
                designation,
                forbidden,
                p.currentCoverageHash,
                envelopeHash,
                capabilities
            )
        );
        x.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ESTATE_ACCELERATION_INTENT_V1"),
                x.scopeHash,
                x.oldValueHash,
                p,
                capabilities
            )
        );
        x.evidenceHash = item.terms.evidenceHash;
        x.effectiveCapabilities = capabilities;
    }

    function authority(
        StreamArtistEstateState.State storage s,
        StreamArtistIdentityState.State storage identity,
        bytes32 artistId
    ) public view returns (Estate.AuthorityCapabilities memory f) {
        T.Identity storage p = identity.identities[artistId];
        if (p.authorityAddress == address(0)) revert T.InvalidIdentity(artistId);
        f.authorityAddress = p.authorityAddress;
        f.authorityClass = p.authorityClass;
        f.status = p.status;
        if (p.authorityClass == 1 && (p.status == 1 || p.status == 4)) {
            f.effectiveCapabilities = 4095;
        } else if (p.authorityClass == 3 && (p.status == 3 || p.status == 4)) {
            bytes32 activation = s.authorityActivation[artistId];
            if (
                activation == bytes32(0) || s.phases[activation] != 2
                    || s.requests[activation].terms.artistId != artistId
            ) revert T.InvalidIdentity(artistId);
            f.effectiveCapabilities = s.executions[activation].effectiveCapabilities;
            f.activationRecordHash = activation;
        } else {
            revert T.InvalidIdentity(artistId);
        }
    }

    function _living(StreamArtistIdentityState.State storage identity, bytes32 artistId)
        private
        view
    {
        T.Identity storage p = identity.identities[artistId];
        if (
            p.authorityClass != 1 || p.status != 1 || p.authorityAddress == address(0)
                || identity.activeIdentity[p.authorityAddress] != artistId
        ) revert T.InvalidIdentity(artistId);
    }
}
