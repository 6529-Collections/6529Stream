// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistUnavailability.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityEstateWriterHost.sol";

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
import "./StreamArtistEstateReads.sol";
import "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import "./StreamArtistTimingState.sol";

/// @notice Constructor-fixed typed Identity writers, executed only in their bound owner.
/// @dev No fallback or routing table. Direct state reads/writes reject; immutable getters
///      expose only truthful construction pins. Every semantic commit remains the owner.
contract StreamArtistIdentityWriterExtension is
    StreamArtistOwner,
    StreamArtistIdentityData,
    IStreamArtistIdentityDismissalEvents,
    IStreamArtistEstateEvents,
    IStreamArtistUnavailabilityEvents
{
    error InvalidTimestamp(uint64 timestamp);
    error ExtensionWrongHost(address actual);
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

    function registerIdentity(
        T.ActionContext calldata c,
        address artist,
        bytes32 documentHash,
        string calldata uri,
        bytes calldata document,
        string calldata displayName
    ) external onlyHost returns (bytes32) {
        _check(c, 1);
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityState.register(
            _identity, _replay, _ownerContext(), artist, documentHash, uri, document, displayName
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function revokeDelegation(
        T.ActionContext calldata c,
        D.Revocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 27);
        _deadline(a.time);
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityState.revokeDelegation(
            _identity, _replay, _delegations, _ownerContext(), c, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, p.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function dismissIdentityContest(
        T.ActionContext calldata c,
        Dismissal.Request calldata p,
        Contest.GovernanceWitness calldata governance
    ) external onlyHost returns (bytes32) {
        _check(c, 58);
        address executor = IStreamArtistIdentityContestOwner(address(this)).artistWindowAuthority();
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityDismissalState.dismiss(
            _resolutions,
            _identity,
            _rotations,
            _identityRevisions,
            _succession,
            _replay,
            _ownerContext(),
            c,
            p,
            governance,
            executor
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function grantDelegation(
        T.ActionContext calldata c,
        D.Grant calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 26);
        StreamArtistSuccessionState.requireAllowed(
            _succession, _rotations, p.artistId, p.capabilities
        );
        if (a.time != 0) revert T.InvalidRecord();
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityState.grantDelegation(
            _identity, _replay, _delegations, _ownerContext(), c, p, a, proof
        );
        _estate.grantEpoch[m.record] = _estate.delegationEpoch[p.artistId];
        _noteLiving(_ownerContext(), _replay, p.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function recordSuccessorDesignation(
        T.ActionContext calldata c,
        Succ.Designation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32) {
        _check(c, 36);
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistSuccessionState.designateWithResolution(
                _succession,
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
        _noteLiving(_ownerContext(), _replay, p.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function recordEstateDirective(
        T.ActionContext calldata c,
        Succ.Directive calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        Succ.PublicDocument calldata document
    ) external onlyHost returns (bytes32) {
        _check(c, 37);
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistSuccessionState.directiveWithResolution(
                _succession,
                _identity,
                _rotations,
                _replay,
                _ownerContext(),
                c,
                p,
                a,
                proof,
                document,
                _currentIdentityClosure(p.artistId)
            );
        _noteLiving(_ownerContext(), _replay, p.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function ownerStateSnapshotV2() public view override onlyHost returns (T.Snapshot memory) {
        return super.ownerStateSnapshotV2();
    }

    function replayCell(bytes32 key) public view override onlyHost returns (T.ReplayCell memory) {
        return _replay[key];
    }

    function recordIdentityRevision(
        T.ActionContext calldata c,
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        bytes calldata document,
        string calldata displayName
    ) external onlyHost returns (bytes32) {
        _check(c, 25);
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistIdentityRevisionState.reviseWithResolution(
                _identityRevisions,
                _identity,
                _rotations,
                _replay,
                _ownerContext(),
                c,
                p,
                a,
                proof,
                document,
                displayName,
                _currentIdentityClosure(p.artistId),
                _resolutions.continuations[_resolutions.continuationHead[p.artistId]]
            );
        _noteLiving(_ownerContext(), _replay, p.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function revokeAuthorization(
        T.ActionContext calldata c,
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32) {
        _check(c, 54);
        StreamArtistIdentityState.Mutation memory m = StreamArtistAuthorizationState.revoke(
            _identity, _replay, _ownerContext(), c, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, p.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function _forwardEstateWriterCompatibility() private {
        address target =
            IStreamArtistIdentityEstateWriterHost(address(this)).identityEstateExtension();
        assembly ("memory-safe") {
            let pointer := mload(0x40)
            calldatacopy(pointer, 0, calldatasize())
            let success := delegatecall(gas(), target, pointer, calldatasize(), 0, 0)
            returndatacopy(pointer, 0, returndatasize())
            if iszero(success) { revert(pointer, returndatasize()) }
            return(pointer, returndatasize())
        }
    }

    function _ownerContext() private view returns (StreamArtistIdentityState.OwnerContext memory) {
        return StreamArtistIdentityState.OwnerContext(
            _environment(), operationCoordinator, archiveV2, domainId, _revision
        );
    }

    function registerCollaboratorIdentity(
        T.ActionContext calldata c,
        C.IdentityProposal calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        bytes calldata document,
        string calldata displayName
    ) external onlyHost returns (bytes32) {
        _check(c, 6);
        _deadline(a.time);
        StreamArtistIdentityState.Mutation memory m = StreamArtistCollaboratorIdentityState.register(
            _identity,
            _collaboratorAccounts,
            _replay,
            _ownerContext(),
            c,
            p,
            a,
            proof,
            document,
            displayName
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function consumeCollaboratorAcceptance(
        T.ActionContext calldata c,
        C.BindingAcceptance calldata p,
        bytes32 artistId,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 7);
        _deadline(a.time);
        if (proof.signer != p.account) revert T.InvalidSignature();
        record = StreamArtistCollaboratorHashes.acceptanceRecordForAuthority(
            _environment(), p, _identity.identities[artistId].authorityClass, a.nonce, _now()
        );
        _authorize(
            c,
            artistId,
            a,
            proof,
            StreamArtistCollaboratorHashes.acceptanceDigest(_environment(), p, a),
            record
        );
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
        _forwardEstateWriterCompatibility();
    }

    function consumeDelegatedRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _forwardEstateWriterCompatibility();
    }

    function consumeAcceptance(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 2);
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.acceptance(
            _identity, _replay, _ownerContext(), c, collectionId, b, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function consumeRefusal(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 3);
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.refusal(
            _identity, _replay, _ownerContext(), c, b, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function consumeSaleConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Sale.Consent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 16);
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.saleConsent(
            _identity, _replay, _ownerContext(), c, b, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function consumePolicy(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 14);
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.policy(
            _identity, _replay, _ownerContext(), c, b, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function consumeEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        bytes32 designation,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 15);
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.economics(
            _identity, _replay, _ownerContext(), c, b, p, designation, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function consumePayout(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 18);
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.payout(
            _identity, _replay, _ownerContext(), c, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, p.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function consumeAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 24);
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.attestation(
            _identity, _replay, _ownerContext(), c, b, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function consumeRatification(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 52);
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.ratification(
            _identity, _replay, _ownerContext(), c, b, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function consumeRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 20);
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.royaltyFreeze(
            _identity, _replay, _ownerContext(), c, b, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function consumeContentConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Consent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 17);
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.contentConsent(
            _identity, _replay, _ownerContext(), c, b, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function consumeContentFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Freeze calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 21);
        StreamArtistIdentityState.Mutation memory m;
        (m, record) = StreamArtistIdentityConsentState.contentFreeze(
            _identity, _replay, _ownerContext(), c, b, p, a, proof
        );
        _noteLiving(_ownerContext(), _replay, b.artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function _authorize(
        T.ActionContext calldata c,
        bytes32 artistId,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        bytes32 digest,
        bytes32 record
    ) private {
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistIdentityState.authorize(
                _identity,
                _replay,
                _ownerContext(),
                c,
                artistId,
                a,
                proof,
                digest,
                record,
                _identity.identities[artistId].authorityAddress
            );
        _noteLiving(_ownerContext(), _replay, artistId, proof.signer, c.operationId, m);
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function _deadline(uint64 deadline) private view {
        if (block.timestamp > deadline) revert T.ExpiredAuthorization(deadline);
    }

    function _signedAt(uint64 time) private view {
        if (time == 0 || time > block.timestamp) revert T.InvalidTimestamp(time);
    }
}
