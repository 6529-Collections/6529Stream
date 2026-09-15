// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistIdentityActivityMutation } from "./StreamArtistIdentityActivityMutation.sol";
import "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";
import {
    StreamArtistStewardCapabilityTypes as SC
} from "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";
import "./StreamArtistDelegatedMutation.sol";
import "./StreamArtistDormancyCancellation.sol";
import "./StreamArtistDormancyReadEncoding.sol";
import { StreamArtistDormancyVestingAdmission } from "./StreamArtistDormancyVestingAdmission.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistStewardSanctionGrant as SG
} from "../../interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import { StreamArtistGuardianAdmissionMutation } from "./StreamArtistGuardianAdmissionMutation.sol";
import {
    StreamArtistGuardianSupersession as GuardianSupersession
} from "./StreamArtistGuardianSupersession.sol";
import { StreamArtistEstateExecutionMutation } from "./StreamArtistEstateExecutionMutation.sol";
import { StreamArtistGuardianHistory } from "./StreamArtistGuardianHistory.sol";
import "./StreamArtistIdentityRecoveryApprovalState.sol";
import "../../interfaces/stream/artist/IStreamArtistUnavailability.sol";

import "./StreamArtistContentHashes.sol";

import "./StreamArtistEconomicsHashes.sol";

import "./StreamArtistOwner.sol";
import "./StreamArtistNonceAvailability.sol";
import "./StreamArtistDelegationState.sol";
import "./StreamArtistIdentityState.sol";
import "./StreamArtistBindingOperations.sol";
import "./StreamArtistCollaboratorIdentityState.sol";
import "./StreamArtistAuthorizationState.sol";
import "./StreamArtistIdentityRevisionState.sol";
import "./StreamArtistIdentityConsentState.sol";
import "./StreamArtistRotationState.sol";
import "./StreamArtistTimingState.sol";
import "../../interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

import "./StreamArtistIdentityData.sol";
import "./StreamArtistIdentityDismissalState.sol";
import "./StreamArtistIdentityCauseState.sol";
import "./StreamArtistEstateReads.sol";
import "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import "./StreamArtistTimingState.sol";

/// @notice Original admitted estate/dormancy mechanics; host retains check and single commit.
library StreamArtistEstateOwnerMutation {
    function stageRotation(
        StreamArtistIdentityState.State storage _identity,
        StreamArtistRotationState.State storage _rotations,
        StreamArtistIdentityResolutionState.State storage _resolutions,
        StreamArtistEstateState.State storage _estate,
        StreamArtistUnavailabilityState.State storage _unavailability,
        StreamArtistDormancyState.State storage _dormancy,
        mapping(bytes32 => T.ReplayCell) storage _replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata args
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            R.Rotation memory p,
            T.Authorization memory oldAuthorization,
            T.Authorization memory newAuthorization,
            T.SignerApproval memory oldProof,
            T.SignerApproval memory newProof
        ) = abi.decode(
            args,
            (
                T.ActionContext,
                R.Rotation,
                T.Authorization,
                T.Authorization,
                T.SignerApproval,
                T.SignerApproval
            )
        );
        // This authenticated living transition supersedes a pending estate request.
        // Any later old/new proof or archive failure rolls the cancellation back.
        StreamArtistIdentityState.Mutation memory cancellation;
        (cancellation.state, cancellation.replay) = StreamArtistIdentityActivityMutation.noteLiving(
            _estate,
            _identity,
            _unavailability,
            _dormancy,
            o,
            _replay,
            p.artistId,
            oldProof.signer,
            c.operationId,
            cancellation
        );
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.stageWithResolution(
            _rotations,
            _identity,
            _replay,
            o,
            c,
            p,
            oldAuthorization,
            newAuthorization,
            oldProof,
            newProof,
            _resolutions.closures[_rotations.latestExecution[p.artistId]]
        );
        if (cancellation.state != bytes32(0)) {
            m.state = keccak256(abi.encode(m.state, cancellation.state));
        }
        if (cancellation.replay != bytes32(0)) {
            m.replay = keccak256(abi.encode(m.replay, cancellation.replay));
        }

        return m;
    }

    function contestIdentity(
        StreamArtistIdentityState.State storage _identity,
        StreamArtistRotationState.State storage _rotations,
        StreamArtistIdentityContestState.State storage _identityContests,
        StreamArtistSuccessionState.State storage _succession,
        StreamArtistIdentityResolutionState.State storage _resolutions,
        StreamArtistEstateState.State storage _estate,
        StreamArtistIdentityRecoveryState.State storage _identityRecovery,
        StreamArtistDormancyState.State storage _dormancy,
        mapping(bytes32 => T.ReplayCell) storage _replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata args
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            Contest.Request memory p,
            Contest.GovernanceWitness memory governance
        ) = abi.decode(args, (T.ActionContext, Contest.Request, Contest.GovernanceWitness));
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityCauseState.file(
            _resolutions,
            _identity,
            _rotations,
            _identityContests,
            _succession,
            _replay,
            o,
            c,
            p,
            governance,
            IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority()
        );
        (bytes32 estateState, bytes32 estateReplay) = StreamArtistEstateState.contest(
            _estate,
            _replay,
            o,
            p.artistId,
            p.subjectRecordHash,
            _rotations.latestExecution[p.artistId],
            _resolutions.closures[p.subjectRecordHash].dismissalRecordHash != bytes32(0),
            _resolutions.closures[_rotations.latestExecution[p.artistId]].dismissalRecordHash
                != bytes32(0)
        );
        if (estateState != bytes32(0)) m.state = keccak256(abi.encode(m.state, estateState));
        if (estateReplay != bytes32(0)) m.replay = keccak256(abi.encode(m.replay, estateReplay));
        bytes32 recoveryState = StreamArtistIdentityRecoveryState.contest(
            _identityRecovery,
            p.artistId,
            p.subjectRecordHash,
            _rotations.latestExecution[p.artistId],
            _resolutions.closures[p.subjectRecordHash].dismissalRecordHash != bytes32(0),
            _resolutions.closures[_rotations.latestExecution[p.artistId]].dismissalRecordHash
                != bytes32(0)
        );
        if (recoveryState != bytes32(0)) m.state = keccak256(abi.encode(m.state, recoveryState));
        bytes32 dormancyDelta = StreamArtistDormancyState.contest(
            _dormancy, _resolutions, p.artistId, _rotations.latestExecution[p.artistId]
        );
        if (dormancyDelta != 0) m.state = keccak256(abi.encode(m.state, dormancyDelta));

        return m;
    }

    function requestEstate(
        StreamArtistIdentityState.State storage _identity,
        StreamArtistRotationState.State storage _rotations,
        StreamArtistSuccessionState.State storage _succession,
        StreamArtistIdentityResolutionState.State storage _resolutions,
        StreamArtistEstateState.State storage _estate,
        StreamArtistDormancyState.State storage _dormancy,
        mapping(bytes32 => T.ReplayCell) storage _replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata args
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (
            T.ActionContext memory c,
            Estate.Request memory p,
            T.Authorization memory a,
            T.SignerApproval memory proof,
            StreamArchivalTypes.CoverageFacts memory coverage
        ) = abi.decode(
            args,
            (
                T.ActionContext,
                Estate.Request,
                T.Authorization,
                T.SignerApproval,
                StreamArchivalTypes.CoverageFacts
            )
        );
        _coverage(coverage, p.selectedCoverageHash, p.artistId, p.evidenceHash);
        Estate.RequestFacts memory facts = StreamArtistEstateReads.requestFacts(
            _estate, _identity, _rotations, _succession, _resolutions, p, coverage.envelopeHash
        );
        StreamArtistIdentityState.Mutation memory m = StreamArtistEstateState.request(
            _estate, _identity, _rotations, _replay, o, c, p, a, proof, facts
        );
        (m.state, m.replay) = StreamArtistIdentityActivityMutation.noteDormancy(
            _dormancy, _identity, o, _replay, p.artistId, proof.signer, 3, m
        );

        return m;
    }

    function completeDormancy(
        StreamArtistIdentityState.State storage _identity,
        StreamArtistRotationState.State storage _rotations,
        StreamArtistSuccessionState.State storage _succession,
        StreamArtistIdentityResolutionState.State storage _resolutions,
        StreamArtistEstateState.State storage _estate,
        StreamArtistIdentityRecoveryState.State storage _identityRecovery,
        StreamArtistDormancyState.State storage _dormancy,
        StreamArtistStewardSanctionState.State storage _stewardGrants,
        mapping(bytes32 => T.ReplayCell) storage _replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata args
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (T.ActionContext memory c, Dorm.Completion memory p, Contest.GovernanceWitness memory g) =
            abi.decode(args, (T.ActionContext, Dorm.Completion, Contest.GovernanceWitness));
        bytes32 previous = _rotations.latestExecution[p.artistId];
        StreamArtistIdentityState.Mutation memory m = StreamArtistDormancyState.complete(
            _dormancy,
            _stewardGrants,
            _identity,
            _rotations,
            _estate,
            _succession,
            _resolutions,
            _replay,
            o,
            c,
            p,
            g,
            IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority()
        );
        bytes32 history = StreamArtistDormancyVestingAdmission.record(
            _dormancy,
            _identityRecovery,
            _identity,
            _rotations,
            _estate,
            o.environment,
            V.Input(p.artistId, m.record, previous, o.revision + 1, 43)
        );
        m.state = keccak256(abi.encode(m.state, history));

        return m;
    }

    function _coverage(
        StreamArchivalTypes.CoverageFacts memory f,
        bytes32 record,
        bytes32 artistId,
        bytes32 evidence
    ) private pure {
        if (
            record == bytes32(0) || f.coverageRecordHash != record || f.artistId != artistId
                || f.evidenceHash != evidence || evidence == bytes32(0)
                || f.envelopeHash == bytes32(0)
        ) {
            revert Estate.InvalidEstateCoverage(record);
        }
    }

    function grantStewardCapabilities(
        StreamArtistIdentityState.State storage _identity,
        StreamArtistRotationState.State storage _rotations,
        StreamArtistSuccessionState.State storage _succession,
        StreamArtistDormancyState.State storage _dormancy,
        StreamArtistStewardCapabilityState.State storage _stewardCapabilityGrants,
        mapping(bytes32 => T.ReplayCell) storage _replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes calldata args
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        (T.ActionContext memory c, SC.Grant memory p, SC.Witness memory w) =
            abi.decode(args, (T.ActionContext, SC.Grant, SC.Witness));

        StreamArtistIdentityState.Mutation memory m = StreamArtistStewardCapabilityState.grant(
            _stewardCapabilityGrants,
            _dormancy,
            _identity,
            _rotations,
            _succession,
            _replay,
            o,
            c,
            p,
            w,
            IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority()
        );

        return m;
    }
}
