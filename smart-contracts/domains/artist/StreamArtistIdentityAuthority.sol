// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEconomicsHashes.sol";

import "./StreamArtistOwner.sol";
import "./StreamArtistNonceAvailability.sol";
import "./StreamArtistDelegationState.sol";
import "./StreamArtistIdentityState.sol";
import "./StreamArtistBindingOperations.sol";
import "./StreamArtistCollaboratorIdentityState.sol";
import "./StreamArtistAuthorizationState.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of artist identities, authorization replay, liveness and signature bytes.
/// @dev Delegation is restricted to economics and exact royalty freezes; rotation/recovery remain unsupported.
contract StreamArtistIdentityAuthority is StreamArtistOwner {
    // Retain the owner ABI for errors propagated by the linked mechanics.
    error NonceAvailabilityAlreadyUsed(uint256 nonce);
    error NonceAvailabilityInconsistent(uint8 level, uint256 prefix);
    error BoundExceeded(uint256 actual, uint256 maximum);
    error AddressAlreadyRegistered(address authority);
    error InvalidSignature();
    error InvalidIdentity(bytes32 artistId);
    error Replay(bytes32 replayKey);
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;
    // Struct members preserve the exact six preexisting physical slots in declaration order.
    StreamArtistIdentityState.State private _identity;
    StreamArtistDelegationState.State private _delegations;
    StreamArtistCollaboratorIdentityState.State private _collaboratorAccounts;

    event ArtistAuthorizationRevoked(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 revokedDigest,
        uint256 revokedNonce,
        uint256 nonce,
        uint64 revokedAt,
        bytes32 revocationRecordHash
    );

    function revokeAuthorization(
        T.ActionContext calldata c,
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _check(c, 54);
        StreamArtistIdentityState.Mutation memory m = StreamArtistAuthorizationState.revoke(
            _identity, _replay, _ownerContext(), c, p, a, proof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function artistAuthorizationState(bytes32 artistId, bytes32 digest, uint256 nonce)
        external
        view
        returns (StreamArtistAuthorizationTypes.State memory)
    {
        return StreamArtistAuthorizationState.authorizationState(
            _identity, _replay, _ownerContext(), artistId, digest, nonce
        );
    }

    event ArtistDelegationGranted(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed delegate,
        uint256 indexed collectionId,
        uint32 capabilities,
        uint64 notBefore,
        uint64 expiresAt,
        uint64 maxUses,
        bytes32 constraintsHash,
        uint256 nonce,
        bytes32 delegationRecordHash
    );
    event ArtistDelegationRevoked(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed delegate,
        bytes32 indexed delegationRecordHash,
        bytes32 reasonHash,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt
    );

    event ArtistIdentityRegistered(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed authorityAddress,
        bytes32 identityRecordHash,
        string identityRecordURI,
        uint256 registrationNonce
    );
    /// @notice Supplementary mirror evidence; the canonical identity document remains authoritative.
    event ArtistIdentityDisplayNameStored(
        bytes32 indexed artistId, bytes32 indexed identityRecordHash, string displayName
    );

    constructor(
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
    { }

    function nextRegistrationNonce() external view returns (uint256) {
        return _identity.nextRegistrationNonce;
    }

    function activeIdentity(address account) external view returns (bytes32) {
        return _identity.activeIdentity[account];
    }

    function _ownerContext() private view returns (StreamArtistIdentityState.OwnerContext memory) {
        return StreamArtistIdentityState.OwnerContext(
            _environment(), operationCoordinator, archiveV2, domainId, _revision
        );
    }

    function identity(bytes32 artistId) external view returns (T.Identity memory) {
        return _identity.identities[artistId];
    }

    /// @notice Fixed-size authority facts; avoids copying URI/display strings on capped mint reads.
    function authorityState(bytes32 artistId)
        external
        view
        returns (
            address authorityAddress,
            uint8 authorityClass,
            uint8 status,
            bytes32 identityRecordHash
        )
    {
        T.Identity storage item = _identity.identities[artistId];
        return (item.authorityAddress, item.authorityClass, item.status, item.identityRecordHash);
    }

    function identityDocumentBytes(bytes32 documentHash) external view returns (bytes memory) {
        return _identity.documents[documentHash];
    }

    function signatureBundle(bytes32 recordHash) external view returns (bytes memory) {
        return _identity.signatures[recordHash];
    }

    function nonceUsed(bytes32 artistId, uint256 nonce) public view returns (bool) {
        return _replay[_replayKey(
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(artistId, nonce))
            )].status != 0;
    }

    function delegationRecord(bytes32 grant) external view returns (D.Record memory) {
        return _delegations.records[grant];
    }

    function collaboratorRegistrationNonceState(address account, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        return StreamArtistCollaboratorIdentityState.nonceState(
            _collaboratorAccounts, _replay, _ownerContext(), account, nonce
        );
    }

    function registerCollaboratorIdentity(
        T.ActionContext calldata c,
        C.IdentityProposal calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32) {
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
    ) external returns (bytes32 record) {
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

    function delegatedNonceState(bytes32 artistId, address delegate, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        bytes32 lane = StreamArtistDelegationState.lane(artistId, delegate);
        return (
            _replay[_replayKey(
                        keccak256("identity_authority.replay.delegated_nonce"),
                        keccak256(abi.encode(lane, nonce))
                    )].status != 0,
            _delegations.hints[lane]
        );
    }

    function grantDelegation(
        T.ActionContext calldata c,
        D.Grant calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _check(c, 26);
        if (a.time != 0) revert T.InvalidRecord();
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityState.grantDelegation(
            _identity, _replay, _delegations, _ownerContext(), c, p, a, proof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function revokeDelegation(
        T.ActionContext calldata c,
        D.Revocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _check(c, 27);
        _deadline(a.time);
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityState.revokeDelegation(
            _identity, _replay, _delegations, _ownerContext(), c, p, a, proof
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function consumeDelegatedEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        bytes32 designation,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
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
    ) external returns (bytes32 record) {
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

    function registerIdentity(
        T.ActionContext calldata c,
        address artist,
        bytes32 documentHash,
        string calldata uri,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32) {
        _check(c, 1);
        StreamArtistIdentityState.Mutation memory m = StreamArtistIdentityState.register(
            _identity, _replay, _ownerContext(), artist, documentHash, uri, document, displayName
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function consumeAcceptance(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _check(c, 2);
        _deadline(a.time);
        record = StreamArtistHashes.acceptanceRecord(
            _environment(), collectionId, b, proof.signer, a.nonce, _now()
        );
        _authorize(
            c,
            b.artistId,
            a,
            proof,
            StreamArtistHashes.acceptanceDigest(_environment(), collectionId, b, a),
            record
        );
    }

    function consumeRefusal(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _check(c, 3);
        _deadline(a.time);
        if (
            b.accepted || b.generation != p.generation || b.bindingHash != p.bindingHash
                || proof.signer != b.artistAddress
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

    function consumePolicy(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _check(c, 14);
        _deadline(a.time);
        record = StreamArtistHashes.policyRecord(
            _environment(), p, b.artistId, proof.signer, a.nonce, _now()
        );
        _authorize(
            c, b.artistId, a, proof, StreamArtistHashes.policyDigest(_environment(), p, a), record
        );
    }

    function consumeEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        bytes32 designation,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _check(c, 15);
        _deadline(a.time);
        if (designation == bytes32(0)) revert T.InvalidRecord();
        record = StreamArtistEconomicsHashes.economicsRecord(
            _environment(), p, designation, b.artistId, proof.signer, a.nonce, _now()
        );
        _authorize(
            c,
            b.artistId,
            a,
            proof,
            StreamArtistEconomicsHashes.economicsDigest(_environment(), p, a.nonce, a.time),
            record
        );
    }

    function consumePayout(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
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
    ) external returns (bytes32 record) {
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
    ) external returns (bytes32 record) {
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
    ) external returns (bytes32 record) {
        _check(c, 20);
        _deadline(a.time);
        record = StreamArtistEconomicsHashes.royaltyFreezeRecord(
            _environment(), p, b.artistId, proof.signer, a.nonce, _now()
        );
        _authorize(
            c,
            b.artistId,
            a,
            proof,
            StreamArtistEconomicsHashes.royaltyFreezeDigest(_environment(), p, a.nonce, a.time),
            record
        );
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
