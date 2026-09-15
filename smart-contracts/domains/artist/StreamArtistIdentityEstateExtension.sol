// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistEstateOwnerMutation } from "./StreamArtistEstateOwnerMutation.sol";
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

/// @notice Constructor-fixed typed Identity writers, executed only in their bound owner.
/// @dev No fallback or routing table. Direct state reads/writes reject; immutable getters
///      expose only truthful construction pins. Every semantic commit remains the owner.
contract StreamArtistIdentityEstateExtension is
    StreamArtistOwner,
    StreamArtistIdentityData,
    IStreamArtistEstateEvents,
    IStreamArtistUnavailabilityEvents
{
    error ExtensionWrongHost(address actual);
    error ExpiredAuthorization(uint64 deadline);
    error InvalidRecord();
    /// @dev Retained ABI entry for the error bubbled by the linked execution mutation.
    error InvalidEstateAcceleration();
    error InvalidEstateCoverage(bytes32 coverageRecordHash);
    error DelegationUnavailable(bytes32 recordHash);
    address private immutable _host;

    constructor(
        address host_,
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    )
        StreamArtistOwner(
            registry_,
            coordinator_,
            archive_,
            keccak256("domain:identity_authority"),
            core_,
            manager_
        )
    {
        if (host_ == address(0) || host_ == address(this)) revert T.InvalidBinding();
        _host = host_;
    }

    modifier onlyHost() {
        if (address(this) != _host) revert ExtensionWrongHost(address(this));
        _;
    }

    function consumeDelegatedAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 24);
        (StreamArtistIdentityState.Mutation memory m, bytes32 outputRecord) = StreamArtistDelegatedMutation.consumeDelegatedAttestation(
            _estate,
            _succession,
            _rotations,
            _identity,
            _delegations,
            _unavailability,
            _dormancy,
            _replay,
            _ownerContext(),
            c,
            b,
            p,
            grant,
            a,
            proof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return outputRecord;
    }

    function consumeDelegatedEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        bytes32 designation,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 15);
        (StreamArtistIdentityState.Mutation memory m, bytes32 outputRecord) = StreamArtistDelegatedMutation.consumeDelegatedEconomics(
            _estate,
            _succession,
            _rotations,
            _identity,
            _delegations,
            _unavailability,
            _dormancy,
            _replay,
            _ownerContext(),
            c,
            b,
            p,
            designation,
            grant,
            a,
            proof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return outputRecord;
    }

    function consumeDelegatedRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 20);
        (StreamArtistIdentityState.Mutation memory m, bytes32 outputRecord) = StreamArtistDelegatedMutation.consumeDelegatedRoyaltyFreeze(
            _estate,
            _succession,
            _rotations,
            _identity,
            _delegations,
            _unavailability,
            _dormancy,
            _replay,
            _ownerContext(),
            c,
            b,
            p,
            grant,
            a,
            proof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return outputRecord;
    }

    function recordUnavailability(T.ActionContext calldata c, U.Input calldata p)
        external
        onlyHost
        returns (bytes32)
    {
        _check(c, 23);
        address executor = IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority();
        if (c.actor != executor) revert T.Unauthorized(c.actor);
        StreamArtistUnavailabilityState.OwnerContext memory o =
            StreamArtistUnavailabilityState.OwnerContext(
                _environment(), operationCoordinator, archiveV2, domainId, _revision
            );
        StreamArtistUnavailabilityState.Mutation memory m = StreamArtistUnavailabilityState.record(
            _unavailability, _replay, o, _identity.identities[p.terms.artistId], p
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function consumeSanction(
        T.ActionContext calldata c,
        T.Binding calldata b,
        S.Terms calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 12);
        StreamArtistDormancyReadEncoding.requireStewardCollection(
            _dormancy,
            _identity,
            _ownerContext().environment.core,
            b.artistId,
            p.scopeType,
            p.collectionId,
            p.tokenId,
            p.scopeId
        );
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.sanction(
            _identity, _replay, _ownerContext(), c, b, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function consumeRecoveryApproval(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Recovery.ApprovalTerms calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 22);
        StreamArtistDormancyReadEncoding.requireStewardCollection(
            _dormancy,
            _identity,
            _ownerContext().environment.core,
            b.artistId,
            0,
            p.collectionId,
            0,
            bytes32(0)
        );
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityRecoveryApprovalState.consume(
            _identity, _replay, _ownerContext(), c, b, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function setGuardians(
        T.ActionContext calldata c,
        R.GuardianSet calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32) {
        _check(c, 28);
        GuardianSupersession.requireHeads(
            _identityRecovery.guardianSupersession, _rotations, p.artistId
        );
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistRotationState.setGuardiansWithResolution(
                _rotations,
                _identity,
                _replay,
                _ownerContext(),
                c,
                p,
                a,
                proof,
                _currentIdentityClosure(p.artistId)
            );
        GuardianSupersession.requireHeads(
            _identityRecovery.guardianSupersession, _rotations, p.artistId
        );
        _noteLiving(_ownerContext(), _replay, p.artistId, proof.signer, c.operationId, m);
        m.state = StreamArtistGuardianAdmissionMutation.record(
            _identityRecovery, _rotations, _ownerContext(), p.artistId, m.record, m.state
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function stageRotation(
        T.ActionContext calldata c,
        R.Rotation calldata p,
        T.Authorization calldata oldAuthorization,
        T.Authorization calldata newAuthorization,
        T.SignerApproval calldata oldProof,
        T.SignerApproval calldata newProof
    ) external onlyHost returns (bytes32) {
        _check(c, 29);
        StreamArtistIdentityState.Mutation memory m = StreamArtistEstateOwnerMutation.stageRotation(
            _identity,
            _rotations,
            _resolutions,
            _estate,
            _unavailability,
            _dormancy,
            _replay,
            _ownerContext(),
            msg.data[4:]
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function approveRotation(T.ActionContext calldata c, bytes32 artistId, bytes32 expected)
        external
        onlyHost
    {
        _check(c, 30);
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.approve(
            _rotations, _identity, _replay, _ownerContext(), c, artistId, expected
        );
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function vetoRotation(
        T.ActionContext calldata c,
        bytes32 artistId,
        bytes32 expected,
        bytes32 reasonHash
    ) external onlyHost {
        _check(c, 31);
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityCauseState.veto(
            _resolutions,
            _identity,
            _rotations,
            _succession,
            _replay,
            _ownerContext(),
            c,
            artistId,
            expected,
            reasonHash
        );
        _noteCurrentAuthority(_ownerContext(), _replay, artistId, c.actor, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function executeRotation(T.ActionContext calldata c, bytes32 artistId, bytes32 expected)
        external
        onlyHost
    {
        _check(c, 32);
        bytes32 previousVesting = _rotations.latestExecution[artistId];
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.execute(
            _rotations, _identity, _replay, _ownerContext(), c, artistId, expected
        );
        _noteGuardianVesting(
            _environment(), V.Input(artistId, expected, previousVesting, _revision + 1, 32), m
        );
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function revokeStanding(
        T.ActionContext calldata c,
        R.StandingRevocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32) {
        _check(c, 51);
        (bool revoked,) = StreamArtistIdentityDismissalState.standingRevoked(
            _resolutions, _rotations, p.artistId, p.revokedAddress
        );
        if (revoked) revert R.InvalidPriorStanding(p.revokedAddress);
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.revokeStanding(
            _rotations, _identity, _replay, _ownerContext(), c, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, p.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function contestIdentity(
        T.ActionContext calldata c,
        Contest.Request calldata p,
        Contest.GovernanceWitness calldata governance
    ) external onlyHost returns (bytes32) {
        _check(c, 33);
        StreamArtistIdentityState.Mutation memory m = StreamArtistEstateOwnerMutation.contestIdentity(
            _identity,
            _rotations,
            _identityContests,
            _succession,
            _resolutions,
            _estate,
            _identityRecovery,
            _dormancy,
            _replay,
            _ownerContext(),
            msg.data[4:]
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function requestEstate(
        T.ActionContext calldata c,
        Estate.Request calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        StreamArchivalTypes.CoverageFacts calldata coverage
    ) external onlyHost returns (bytes32) {
        _check(c, 38);
        StreamArtistIdentityState.Mutation memory m = StreamArtistEstateOwnerMutation.requestEstate(
            _identity,
            _rotations,
            _succession,
            _resolutions,
            _estate,
            _dormancy,
            _replay,
            _ownerContext(),
            msg.data[4:]
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function cancelEstate(T.ActionContext calldata c, bytes32 artistId, bytes32 expected)
        external
        onlyHost
    {
        _check(c, 39);
        StreamArtistIdentityState.Mutation memory m = StreamArtistEstateState.cancel(
            _estate, _identity, _replay, _ownerContext(), c, artistId, expected
        );
        _noteCurrentAuthority(_ownerContext(), _replay, artistId, c.actor, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function executeEstate(
        T.ActionContext calldata c,
        Estate.Execution calldata p,
        StreamArchivalTypes.CoverageFacts calldata coverage,
        Contest.GovernanceWitness calldata governance
    ) external onlyHost {
        _check(c, 40);
        StreamArtistIdentityState.Mutation memory m = StreamArtistEstateExecutionMutation.execute(
            _identityRecovery,
            _identity,
            _rotations,
            _succession,
            _resolutions,
            _estate,
            _replay,
            _ownerContext(),
            c,
            p,
            coverage,
            governance
        );
        _commit(c, m.action, m.state, m.replay, m.record);
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

    function ownerStateSnapshotV2() public view override onlyHost returns (T.Snapshot memory) {
        return super.ownerStateSnapshotV2();
    }

    function replayCell(bytes32 key) public view override onlyHost returns (T.ReplayCell memory) {
        return _replay[key];
    }

    function _deadline(uint64 deadline) private view {
        if (block.timestamp > deadline) revert T.ExpiredAuthorization(deadline);
    }

    function _ownerContext() private view returns (StreamArtistIdentityState.OwnerContext memory) {
        return StreamArtistIdentityState.OwnerContext(
            _environment(), operationCoordinator, archiveV2, domainId, _revision
        );
    }

    function initiateDormancy(
        T.ActionContext calldata c,
        Dorm.Initiation calldata p,
        Contest.GovernanceWitness calldata g
    ) external onlyHost returns (bytes32) {
        _check(c, 41);
        StreamArtistIdentityState.Mutation memory m = StreamArtistDormancyState.initiate(
            _dormancy,
            _identity,
            _rotations,
            _estate,
            _resolutions,
            _replay,
            _ownerContext(),
            c,
            p,
            g,
            IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority()
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function cancelDormancy(T.ActionContext calldata c, bytes32 id, bytes32 expected, bytes32 grant)
        external
        onlyHost
    {
        _check(c, 42);
        StreamArtistIdentityState.Mutation memory m = StreamArtistDormancyCancellation.cancel(
            _dormancy,
            _identity,
            _rotations,
            _succession,
            _estate,
            _delegations,
            _replay,
            _ownerContext(),
            c,
            id,
            expected,
            grant
        );
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function completeDormancy(
        T.ActionContext calldata c,
        Dorm.Completion calldata p,
        Contest.GovernanceWitness calldata g
    ) external onlyHost returns (bytes32) {
        _check(c, 43);
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistEstateOwnerMutation.completeDormancy(
                _identity,
                _rotations,
                _succession,
                _resolutions,
                _estate,
                _identityRecovery,
                _dormancy,
                _stewardGrants,
                _replay,
                _ownerContext(),
                msg.data[4:]
            );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function recordStewardSanctionGrant(
        T.ActionContext calldata c,
        SG.Grant calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32) {
        _check(c, 19);
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistStewardSanctionState.recordWithResolution(
                _stewardGrants,
                _identity,
                _rotations,
                _replay,
                _ownerContext(),
                c,
                p,
                a,
                proof,
                _currentIdentityClosure(p.artistId)
            );
        _noteLiving(_ownerContext(), _replay, p.artistId, proof.signer, 19, m);
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function grantStewardCapabilities(
        T.ActionContext calldata c,
        SC.Grant calldata p,
        SC.Witness calldata w
    ) external onlyHost returns (bytes32) {
        _check(c, 59);
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistEstateOwnerMutation.grantStewardCapabilities(
                _identity,
                _rotations,
                _succession,
                _dormancy,
                _stewardCapabilityGrants,
                _replay,
                _ownerContext(),
                msg.data[4:]
            );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }
}
