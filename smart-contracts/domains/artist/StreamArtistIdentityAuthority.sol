// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of artist identities, authorization replay, liveness and signature bytes.
/// @dev Supports the onboarding operation subset; no rotation, delegation or recovery is implied.
contract StreamArtistIdentityAuthority is StreamArtistOwner {
    uint256 public nextRegistrationNonce;
    mapping(bytes32 => T.Identity) private _identities;
    mapping(address => bytes32) public activeIdentity;
    mapping(bytes32 => bytes) private _documents;
    mapping(bytes32 => bytes) private _signatures;

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

    function identity(bytes32 artistId) external view returns (T.Identity memory) {
        return _identities[artistId];
    }

    function identityDocumentBytes(bytes32 documentHash) external view returns (bytes memory) {
        return _documents[documentHash];
    }

    function signatureBundle(bytes32 recordHash) external view returns (bytes memory) {
        return _signatures[recordHash];
    }

    function nonceUsed(bytes32 artistId, uint256 nonce) public view returns (bool) {
        return _replay[_replayKey(
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(artistId, nonce))
            )].status != 0;
    }

    function registerIdentity(
        T.ActionContext calldata c,
        address artist,
        bytes32 documentHash,
        string calldata uri,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32 artistId) {
        _check(c, 1);
        if (
            artist == address(0) || documentHash == bytes32(0) || document.length == 0
                || keccak256(document) != documentHash || bytes(displayName).length == 0
        ) revert T.InvalidRecord();
        if (document.length > 8192) revert T.BoundExceeded(document.length, 8192);
        if (bytes(uri).length > 2048) revert T.BoundExceeded(bytes(uri).length, 2048);
        if (bytes(displayName).length > 256) {
            revert T.BoundExceeded(bytes(displayName).length, 256);
        }
        if (activeIdentity[artist] != bytes32(0)) revert T.AddressAlreadyRegistered(artist);
        uint256 registrationNonce = nextRegistrationNonce++;
        artistId =
            StreamArtistHashes.identity(_environment(), artist, documentHash, registrationNonce);
        uint64 now_ = _now();
        _identities[artistId] =
            T.Identity(artist, 1, 1, now_, now_, documentHash, uri, displayName, 0);
        activeIdentity[artist] = artistId;
        if (_documents[documentHash].length == 0) _documents[documentHash] = document;
        // Zero identity namespaces registration allocation; actual artist IDs are nonzero.
        if (artistId == bytes32(0)) revert T.InvalidIdentity(artistId);
        bytes32 key = _consume(
            keccak256("identity_authority.replay.nonce_allocator"),
            keccak256(abi.encode(bytes32(0), registrationNonce)),
            artistId
        );
        _commit(
            c,
            keccak256(abi.encode(artist, documentHash, uri, displayName, registrationNonce)),
            keccak256(abi.encode(artistId, _identities[artistId], nextRegistrationNonce)),
            keccak256(abi.encode(key, artistId)),
            artistId
        );
        emit ArtistIdentityRegistered(1, artistId, artist, documentHash, uri, registrationNonce);
        emit ArtistIdentityDisplayNameStored(artistId, documentHash, displayName);
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
        record = StreamArtistHashes.economicsRecord(
            _environment(), p, designation, b.artistId, proof.signer, a.nonce, _now()
        );
        _authorize(
            c,
            b.artistId,
            a,
            proof,
            StreamArtistHashes.economicsDigest(_environment(), p, a),
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
        record = StreamArtistHashes.payoutRecord(_environment(), p, proof.signer, a.nonce, a.time);
        _authorize(
            c, p.artistId, a, proof, StreamArtistHashes.payoutDigest(_environment(), p, a), record
        );
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
        record = StreamArtistHashes.attestationRecord(
            _environment(), p, b.artistId, proof.signer, a.nonce, a.time
        );
        _authorize(
            c,
            b.artistId,
            a,
            proof,
            StreamArtistHashes.attestationDigest(_environment(), p, a),
            record
        );
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
        record = StreamArtistHashes.ratificationRecord(
            _environment(), p, b.artistId, proof.signer, a.nonce, _now()
        );
        _authorize(
            c,
            b.artistId,
            a,
            proof,
            StreamArtistHashes.ratificationDigest(_environment(), p, a),
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
        T.Identity storage item = _identities[artistId];
        if (item.status != 1 || item.authorityClass != 1 || item.authorityAddress == address(0)) {
            revert T.InvalidIdentity(artistId);
        }
        if (
            proof.signer != item.authorityAddress || proof.digest != digest
                || (proof.direct && (c.actor != proof.signer || a.signature.length != 0))
                || (!proof.direct && a.signature.length == 0 && proof.signer.code.length == 0)
        ) revert T.InvalidSignature();
        if (
            proof.direct
                && (a.nonce != item.nonceHint
                    || ((c.operationId == 18 || c.operationId == 24) && a.time != _now()))
        ) revert T.InvalidRecord();
        if (a.signature.length > 4096) revert T.BoundExceeded(a.signature.length, 4096);
        bytes32 digestKey = _replayKey(
            keccak256("identity_authority.replay.digest_revocation"),
            keccak256(abi.encode(artistId, digest))
        );
        if (_replay[digestKey].status != 0) revert T.Replay(digestKey);
        bytes32 nonceKey = _consume(
            keccak256("identity_authority.replay.nonce_allocator"),
            keccak256(abi.encode(artistId, a.nonce)),
            digest
        );
        bytes32 attestationKey;
        if (c.operationId == 24) {
            attestationKey = _consume(
                keccak256("identity_authority.replay.attestation_key"),
                keccak256(abi.encode(record)),
                record
            );
        }
        item.lastAuthorityActionAt = _now();
        // Relayed nonces remain unordered. Advance the direct-call allocator only when
        // its value was consumed; each previously consumed slot is skipped at most once.
        if (a.nonce == item.nonceHint) {
            uint256 candidate = a.nonce;
            do {
                unchecked {
                    ++candidate;
                }
            } while (nonceUsed(artistId, candidate));
            item.nonceHint = candidate;
        }
        _signatures[record] = a.signature;
        _commit(
            c,
            keccak256(abi.encode(artistId, digest, a, proof, record)),
            keccak256(abi.encode(artistId, item, record, keccak256(a.signature))),
            keccak256(
                abi.encode(
                    nonceKey,
                    digest,
                    attestationKey,
                    attestationKey == bytes32(0) ? bytes32(0) : record
                )
            ),
            bytes32(0)
        );
    }

    function _deadline(uint64 deadline) private view {
        if (block.timestamp > deadline) revert T.ExpiredAuthorization(deadline);
    }

    function _signedAt(uint64 time) private view {
        if (time == 0 || time > block.timestamp) revert T.InvalidTimestamp(time);
    }
}
