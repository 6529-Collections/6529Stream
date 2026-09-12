// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    IStreamArtistEstateEvents
{
    error ExtensionWrongHost(address actual);
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

    function consumeSanction(
        T.ActionContext calldata c,
        T.Binding calldata b,
        S.Terms calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 12);
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.sanction(
            _identity, _replay, _ownerContext(), c, b, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function setGuardians(
        T.ActionContext calldata c,
        R.GuardianSet calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32) {
        _check(c, 28);
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
        _noteLiving(_ownerContext(), _replay, p.artistId, proof.signer, m);
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
        // This authenticated living transition supersedes a pending estate request.
        // Any later old/new proof or archive failure rolls the cancellation back.
        StreamArtistIdentityState.Mutation memory cancellation;
        _noteLiving(_ownerContext(), _replay, p.artistId, oldProof.signer, cancellation);
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.stageWithResolution(
            _rotations,
            _identity,
            _replay,
            _ownerContext(),
            c,
            p,
            oldAuthorization,
            newAuthorization,
            oldProof,
            newProof,
            _currentIdentityClosure(p.artistId)
        );
        if (cancellation.state != bytes32(0)) {
            m.state = keccak256(abi.encode(m.state, cancellation.state));
        }
        if (cancellation.replay != bytes32(0)) {
            m.replay = keccak256(abi.encode(m.replay, cancellation.replay));
        }
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
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function executeRotation(T.ActionContext calldata c, bytes32 artistId, bytes32 expected)
        external
        onlyHost
    {
        _check(c, 32);
        StreamArtistIdentityState.Mutation memory m = StreamArtistRotationState.execute(
            _rotations, _identity, _replay, _ownerContext(), c, artistId, expected
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
        _noteLiving(_ownerContext(), _replay, p.artistId, proof.signer, m);
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function contestIdentity(
        T.ActionContext calldata c,
        Contest.Request calldata p,
        Contest.GovernanceWitness calldata governance
    ) external onlyHost returns (bytes32) {
        _check(c, 33);
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityCauseState.file(
            _resolutions,
            _identity,
            _rotations,
            _identityContests,
            _succession,
            _replay,
            _ownerContext(),
            c,
            p,
            governance,
            IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority()
        );
        (bytes32 estateState, bytes32 estateReplay) = StreamArtistEstateState.contest(
            _estate,
            _replay,
            _ownerContext(),
            p.artistId,
            p.subjectRecordHash,
            _rotations.latestExecution[p.artistId],
            _resolutions.closures[p.subjectRecordHash].dismissalRecordHash != bytes32(0),
            _currentIdentityClosure(p.artistId).dismissalRecordHash != bytes32(0)
        );
        if (estateState != bytes32(0)) m.state = keccak256(abi.encode(m.state, estateState));
        if (estateReplay != bytes32(0)) m.replay = keccak256(abi.encode(m.replay, estateReplay));
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
        _coverage(coverage, p.selectedCoverageHash, p.artistId, p.evidenceHash);
        Estate.RequestFacts memory facts = StreamArtistEstateReads.requestFacts(
            _estate, _identity, _rotations, _succession, _resolutions, p, coverage.envelopeHash
        );
        StreamArtistIdentityState.Mutation memory m = StreamArtistEstateState.request(
            _estate, _identity, _rotations, _replay, _ownerContext(), c, p, a, proof, facts
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
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function executeEstate(
        T.ActionContext calldata c,
        Estate.Execution calldata p,
        StreamArchivalTypes.CoverageFacts calldata coverage,
        Contest.GovernanceWitness calldata governance
    ) external onlyHost {
        _check(c, 40);
        Estate.RequestRecord storage request = _estate.requests[p.expectedActivationRecordHash];
        _coverage(coverage, p.currentCoverageHash, p.artistId, request.terms.evidenceHash);
        (uint32 capabilities, Estate.AccelerationContext memory x) = StreamArtistEstateReads.executionFacts(
            _estate,
            _identity,
            _rotations,
            _succession,
            _resolutions,
            _environment(),
            p,
            coverage.envelopeHash
        );
        bytes32 witness;
        if (governance.actionId != bytes32(0)) {
            address executor =
                IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority();
            if (
                c.actor != executor || governance.actionClass != 1
                    || governance.proposer == address(0) || governance.scopeHash != x.scopeHash
                    || governance.oldValueHash != x.oldValueHash
                    || governance.newValueHash != x.newValueHash
                    || governance.roleMutationHash != bytes32(0) || governance.roleRevision != 0
            ) revert Estate.InvalidEstateAcceleration();
            witness = keccak256(abi.encode(governance));
        } else {
            Contest.GovernanceWitness memory empty;
            if (keccak256(abi.encode(governance)) != keccak256(abi.encode(empty))) {
                revert Estate.InvalidEstateAcceleration();
            }
        }
        StreamArtistIdentityState.Mutation memory m = StreamArtistEstateState.execute(
            _estate,
            _identity,
            _rotations,
            _replay,
            _ownerContext(),
            c,
            p,
            capabilities,
            x,
            governance.actionId,
            witness
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

    function _ownerContext() private view returns (StreamArtistIdentityState.OwnerContext memory) {
        return StreamArtistIdentityState.OwnerContext(
            _environment(), operationCoordinator, archiveV2, domainId, _revision
        );
    }
}
