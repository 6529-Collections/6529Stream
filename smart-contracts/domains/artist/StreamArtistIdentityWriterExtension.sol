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

/// @notice Constructor-fixed typed Identity writers, executed only in their bound owner.
/// @dev No fallback or routing table. Direct state reads/writes reject; immutable getters
///      expose only truthful construction pins. Every semantic commit remains the owner.
contract StreamArtistIdentityWriterExtension is StreamArtistOwner, StreamArtistIdentityData {
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
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityRevisionState.revise(
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
            displayName
        );
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
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
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
        record = StreamArtistCollaboratorHashes.acceptanceRecord(_environment(), p, a.nonce, _now());
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
        _check(c, 15);
        _deadline(a.time);
        if (designation == bytes32(0)) revert T.InvalidRecord();
        record = StreamArtistEconomicsHashes.economicsRecordForAuthority(
            _environment(), p, designation, b.artistId, proof.signer, 2, a.nonce, _now()
        );
        _authorizeDelegate(
            c,
            b,
            p.collectionId,
            D.ECONOMICS,
            grant,
            a,
            proof,
            StreamArtistEconomicsHashes.economicsDigest(_environment(), p, a.nonce, a.time),
            record
        );
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
        _deadline(a.time);
        record = StreamArtistEconomicsHashes.royaltyFreezeRecordForAuthority(
            _environment(), p, b.artistId, proof.signer, 2, a.nonce, _now()
        );
        _authorizeDelegate(
            c,
            b,
            p.collectionId,
            D.ROYALTY_FREEZE,
            grant,
            a,
            proof,
            StreamArtistEconomicsHashes.royaltyFreezeDigest(_environment(), p, a.nonce, a.time),
            record
        );
    }

    function _authorizeDelegate(
        T.ActionContext calldata c,
        T.Binding calldata b,
        uint256 collectionId,
        uint32 capability,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        bytes32 digest,
        bytes32 record
    ) private {
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistIdentityState.authorizeDelegate(
                _identity,
                _replay,
                _delegations,
                _ownerContext(),
                c,
                b,
                collectionId,
                capability,
                grant,
                a,
                proof,
                digest,
                record
            );
        _commit(c, m.action, m.state, m.replay, m.record);
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
        _deadline(a.time);
        if (
            b.accepted || b.generation != p.generation || b.bindingHash != p.bindingHash
                || proof.signer != _identity.identities[b.artistId].authorityAddress
        ) revert T.InvalidRecord();
        record = StreamArtistBindingOperations.refusalRecord(
            _environment(), p, b.artistId, proof.signer, a.nonce, _now()
        );
        _authorize(
            c,
            b.artistId,
            a,
            proof,
            StreamArtistBindingOperations.refusalDigest(_environment(), p, a),
            record
        );
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
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function consumePayout(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 18);
        _signedAt(a.time);
        bytes32 digest;
        (record, digest) = StreamArtistIdentityState.payoutProof(_environment(), p, proof.signer, a);
        _authorize(c, p.artistId, a, proof, digest, record);
    }

    function consumeAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 24);
        _signedAt(a.time);
        bytes32 digest;
        (record, digest) =
            StreamArtistIdentityState.attestationProof(_environment(), b, p, proof.signer, a);
        _authorize(c, b.artistId, a, proof, digest, record);
    }

    function consumeRatification(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external onlyHost returns (bytes32 record) {
        _check(c, 52);
        _deadline(a.time);
        bytes32 digest;
        (record, digest) = StreamArtistIdentityState.ratificationProof(
            _environment(), b, p, proof.signer, a, _now()
        );
        _authorize(c, b.artistId, a, proof, digest, record);
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
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function _deadline(uint64 deadline) private view {
        if (block.timestamp > deadline) revert T.ExpiredAuthorization(deadline);
    }

    function _signedAt(uint64 time) private view {
        if (time == 0 || time > block.timestamp) revert T.InvalidTimestamp(time);
    }
}
