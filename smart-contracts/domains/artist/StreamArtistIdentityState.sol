// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistDelegationState.sol";
import "./StreamArtistAuthorityPolicy.sol";

/// @notice Linked mechanics over Identity's original storage prefix and replay map.
/// @dev Typed owner guards and one semantic commit remain in Identity. This library owns no separate state.
library StreamArtistIdentityState {
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;

    struct State {
        uint256 nextRegistrationNonce;
        mapping(bytes32 => T.Identity) identities;
        mapping(address => bytes32) activeIdentity;
        mapping(bytes32 => bytes) documents;
        mapping(bytes32 => bytes) signatures;
        mapping(bytes32 => StreamArtistNonceAvailability.Index) nonceAvailability;
    }

    struct OwnerContext {
        StreamArtistHashes.Environment environment;
        address coordinator;
        address archive;
        bytes32 domain;
        uint64 revision;
    }

    struct Mutation {
        bytes32 record;
        bytes32 action;
        bytes32 state;
        bytes32 replay;
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

    function grantDelegation(
        State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistDelegationState.State storage delegations,
        OwnerContext memory o,
        T.ActionContext memory c,
        D.Grant memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (Mutation memory m) {
        (bytes32 record, bytes32 delta) = StreamArtistDelegationState.grant(
            delegations, o.environment, p, proof.signer, a.nonce
        );
        bytes32 digest = StreamArtistDelegationState.grantDigest(o.environment, p, a.nonce);
        Mutation memory authorization = authorize(
            identity,
            replay,
            o,
            c,
            p.artistId,
            a,
            proof,
            digest,
            record,
            identity.identities[p.artistId].authorityAddress
        );
        bytes32 key = _consume(
            replay, o, keccak256("identity_authority.replay.delegation_key"), record, record
        );
        m = Mutation(
            record,
            keccak256(abi.encode(p, a, proof)),
            keccak256(abi.encode(delta, identity.identities[p.artistId])),
            keccak256(abi.encode(authorization.replay, key, record))
        );
        emit ArtistDelegationGranted(
            1,
            p.artistId,
            p.delegate,
            p.collectionId,
            p.capabilities,
            p.notBefore,
            p.expiresAt,
            p.maxUses,
            p.constraintsHash,
            a.nonce,
            record
        );
    }

    function revokeDelegation(
        State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistDelegationState.State storage delegations,
        OwnerContext memory o,
        T.ActionContext memory c,
        D.Revocation memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (Mutation memory m) {
        address grantor = delegations.records[p.delegationRecordHash].grantor;
        (bytes32 record, bytes32 delta) = StreamArtistDelegationState.revoke(
            delegations, o.environment, p, proof.signer, a.nonce, _now()
        );
        bytes32 digest = StreamArtistDelegationState.revokeDigest(o.environment, p, a.nonce, a.time);
        Mutation memory authorization =
            authorize(identity, replay, o, c, p.artistId, a, proof, digest, record, grantor);
        bytes32 key = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.one_way_delegation_revocation"),
            p.delegationRecordHash,
            record
        );
        m = Mutation(
            record,
            keccak256(abi.encode(p, a, proof)),
            keccak256(abi.encode(delta, identity.identities[p.artistId])),
            keccak256(abi.encode(authorization.replay, key, record))
        );
        emit ArtistDelegationRevoked(
            1,
            p.artistId,
            p.delegate,
            p.delegationRecordHash,
            p.reasonHash,
            proof.signer,
            1,
            a.nonce,
            _now()
        );
    }
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

    function payoutProof(
        StreamArtistHashes.Environment memory e,
        T.PayoutDesignation memory p,
        address signer,
        T.Authorization memory a
    ) public pure returns (bytes32 record, bytes32 digest) {
        return (
            StreamArtistHashes.payoutRecord(e, p, signer, a.nonce, a.time),
            StreamArtistHashes.payoutDigest(e, p, a)
        );
    }

    function attestationProof(
        StreamArtistHashes.Environment memory e,
        T.Binding memory b,
        T.Attestation memory p,
        address signer,
        T.Authorization memory a
    ) public pure returns (bytes32 record, bytes32 digest) {
        return (
            StreamArtistHashes.attestationRecord(e, p, b.artistId, signer, a.nonce, a.time),
            StreamArtistHashes.attestationDigest(e, p, a)
        );
    }

    function ratificationProof(
        StreamArtistHashes.Environment memory e,
        T.Binding memory b,
        T.Ratification memory p,
        address signer,
        T.Authorization memory a,
        uint64 observed
    ) public pure returns (bytes32 record, bytes32 digest) {
        return (
            StreamArtistHashes.ratificationRecord(e, p, b.artistId, signer, a.nonce, observed),
            StreamArtistHashes.ratificationDigest(e, p, a)
        );
    }

    function register(
        State storage state,
        mapping(bytes32 => T.ReplayCell) storage replay,
        OwnerContext memory o,
        address artist,
        bytes32 documentHash,
        string memory uri,
        bytes memory document,
        string memory displayName
    ) public returns (Mutation memory) {
        if (
            artist == address(0) || documentHash == bytes32(0) || document.length == 0
                || keccak256(document) != documentHash || bytes(displayName).length == 0
        ) revert T.InvalidRecord();
        if (document.length > 8192) revert T.BoundExceeded(document.length, 8192);
        if (bytes(uri).length > 2048) revert T.BoundExceeded(bytes(uri).length, 2048);
        if (bytes(displayName).length > 256) {
            revert T.BoundExceeded(bytes(displayName).length, 256);
        }
        if (state.activeIdentity[artist] != bytes32(0)) revert T.AddressAlreadyRegistered(artist);
        uint256 registrationNonce = state.nextRegistrationNonce++;
        bytes32 artistId =
            StreamArtistHashes.identity(o.environment, artist, documentHash, registrationNonce);
        uint64 now_ = _now();
        state.identities[artistId] =
            T.Identity(artist, 1, 1, now_, now_, documentHash, uri, displayName, 0);
        state.activeIdentity[artist] = artistId;
        if (state.documents[documentHash].length == 0) state.documents[documentHash] = document;
        // Zero identity namespaces registration allocation; actual artist IDs are nonzero.
        if (artistId == bytes32(0)) revert T.InvalidIdentity(artistId);
        bytes32 key = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.nonce_allocator"),
            keccak256(abi.encode(bytes32(0), registrationNonce)),
            artistId
        );
        Mutation memory mutation = Mutation(
            artistId,
            keccak256(abi.encode(artist, documentHash, uri, displayName, registrationNonce)),
            keccak256(
                abi.encode(artistId, state.identities[artistId], state.nextRegistrationNonce)
            ),
            keccak256(abi.encode(key, artistId))
        );
        emit ArtistIdentityRegistered(1, artistId, artist, documentHash, uri, registrationNonce);
        emit ArtistIdentityDisplayNameStored(artistId, documentHash, displayName);

        return mutation;
    }

    function authorize(
        State storage state,
        mapping(bytes32 => T.ReplayCell) storage replay,
        OwnerContext memory o,
        T.ActionContext memory c,
        bytes32 artistId,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes32 digest,
        bytes32 record,
        address expectedSigner
    ) public returns (Mutation memory) {
        T.Identity storage item = state.identities[artistId];
        StreamArtistAuthorityPolicy.requireOperation(item, artistId, c.operationId);
        if (
            proof.signer != expectedSigner || expectedSigner == address(0) || proof.digest != digest
                || (proof.direct && (c.actor != proof.signer || a.signature.length != 0))
                || (!proof.direct && a.signature.length == 0 && proof.signer.code.length == 0)
        ) revert T.InvalidSignature();
        if (
            proof.direct
                && (a.nonce != item.nonceHint
                    || ((c.operationId == 18 || c.operationId == 24) && a.time != _now()))
        ) revert T.InvalidRecord();
        if (a.signature.length > 4096) revert T.BoundExceeded(a.signature.length, 4096);
        bytes32 digestKey = _key(
            o,
            keccak256("identity_authority.replay.digest_revocation"),
            keccak256(abi.encode(artistId, digest))
        );
        if (replay[digestKey].status != 0) revert T.Replay(digestKey);
        bytes32 observation = _observeDigest(replay, o, artistId, digest);
        bytes32 nonceKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.nonce_allocator"),
            keccak256(abi.encode(artistId, a.nonce)),
            digest
        );
        bytes32 availabilityDelta = state.nonceAvailability[artistId].consume(a.nonce);
        bytes32 attestationKey;
        if (c.operationId == 24) {
            attestationKey = _consume(
                replay,
                o,
                keccak256("identity_authority.replay.attestation_key"),
                keccak256(abi.encode(record)),
                record
            );
        }
        if (proof.signer == item.authorityAddress) item.lastAuthorityActionAt = _now();
        // Relayed nonce validity is independent of the allocator. Updating the hint
        // uses a fixed-depth index, never a scan across earlier signed submissions.
        if (a.nonce == item.nonceHint) {
            (, item.nonceHint) = state.nonceAvailability[artistId].firstUnused();
        }
        state.signatures[record] = a.signature;
        bytes32 replayDelta = keccak256(
            abi.encode(
                nonceKey,
                digest,
                availabilityDelta,
                attestationKey,
                attestationKey == bytes32(0) ? bytes32(0) : record,
                observation
            )
        );

        return Mutation(
            bytes32(0),
            keccak256(abi.encode(artistId, digest, a, proof, record)),
            keccak256(abi.encode(artistId, item, record, keccak256(a.signature))),
            replayDelta
        );
    }

    function authorizeDelegate(
        State storage state,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistDelegationState.State storage delegations,
        OwnerContext memory o,
        T.ActionContext memory c,
        T.Binding memory b,
        uint256 collectionId,
        uint32 capability,
        bytes32 grant,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes32 digest,
        bytes32 record
    ) public returns (Mutation memory) {
        T.Identity storage item = state.identities[b.artistId];
        if (
            !b.accepted || b.consentMode != 1
                || (item.status != 1 && !(c.operationId == 20 && item.status == 4))
                || item.authorityClass != 1 || item.authorityAddress == address(0)
        ) revert T.InvalidIdentity(b.artistId);
        bytes32 lane = StreamArtistDelegationState.lane(b.artistId, proof.signer);
        bytes32 identityDeny = _key(
            o,
            keccak256("identity_authority.replay.digest_revocation"),
            keccak256(abi.encode(b.artistId, digest))
        );
        if (replay[identityDeny].status != 0) revert T.Replay(identityDeny);
        bytes32 observation = _observeDigest(replay, o, b.artistId, digest);
        bytes32 digestKey = _key(
            o,
            keccak256("identity_authority.replay.delegated_digest_revocation"),
            keccak256(abi.encode(lane, digest))
        );
        if (replay[digestKey].status != 0) revert T.Replay(digestKey);
        bytes32 key = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.delegated_nonce"),
            keccak256(abi.encode(lane, a.nonce)),
            digest
        );
        (, bytes32 delta) = StreamArtistDelegationState.consume(
            delegations, grant, b.artistId, collectionId, capability, a, proof, c.actor, digest
        );
        state.signatures[record] = a.signature;
        return Mutation(
            bytes32(0),
            keccak256(abi.encode(b, grant, a, proof, record)),
            keccak256(abi.encode(delta, record, keccak256(a.signature))),
            keccak256(abi.encode(key, digest, delta, observation))
        );
    }

    // Observation is distinct from revocation: two existing delegate lanes may
    // execute the same digest, but a previously executed digest cannot be revoked.
    function _observeDigest(
        mapping(bytes32 => T.ReplayCell) storage replay,
        OwnerContext memory o,
        bytes32 artistId,
        bytes32 digest
    ) private returns (bytes32) {
        bytes32 key = _key(
            o,
            keccak256("identity_authority.replay.authorization_consumed_digest"),
            keccak256(abi.encode(artistId, digest))
        );
        if (replay[key].status == 0) replay[key] = T.ReplayCell(digest, o.revision + 1, 1, 2);
        return keccak256(abi.encode(key, replay[key]));
    }

    function _key(OwnerContext memory o, bytes32 surface, bytes32 scope)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                surface,
                scope
            )
        );
    }

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        OwnerContext memory o,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment
    ) private returns (bytes32 key) {
        key = _key(o, surface, scope);
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(commitment, o.revision + 1, 1, 2);
    }

    function _now() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
        return uint64(block.timestamp);
    }
}
