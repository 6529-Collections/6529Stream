// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOwner.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of collection attribution state and state-bound artist attestations.
contract StreamArtistAttributionLifecycle is StreamArtistOwner {
    struct Attribution {
        uint8 state;
        uint64 generation;
    }
    mapping(uint256 => Attribution) private _attributions;
    mapping(bytes32 => T.AttestationRecord) private _attestations;
    mapping(bytes32 => T.AttestationRecord) private _records;
    mapping(bytes32 => bytes) private _statements;
    /// @notice Additional context reconstructing a refusal's exact normative record from events.
    event ArtistBindingTerminationContext(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint64 indexed bindingGeneration,
        bytes32 indexed recordReference,
        bytes32 bindingHash,
        bytes32 artistId,
        address signer,
        uint256 nonce,
        uint64 signedAt
    );
    event ArtistAttributionStateChanged(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 indexed newState,
        uint64 bindingGeneration,
        uint8 oldState,
        address actor,
        uint8 authorityClass,
        bytes32 recordHash,
        bytes32 reasonHash,
        string reasonURI
    );
    event ArtistAttestationRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 indexed subjectKind,
        address indexed signer,
        bytes32 subjectId,
        bytes32 subjectStateHash,
        bytes32 schemaId,
        bytes32 statementHash,
        bytes32 statementURIHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 attestationRecordHash
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
            keccak256("domain:attribution_lifecycle"),
            core_,
            manager_
        )
    { }

    function attributionState(uint256 collectionId) external view returns (uint8, uint64) {
        Attribution storage a = _attributions[collectionId];
        return (a.state, a.generation);
    }

    function attestation(uint256 collectionId, uint8 kind, bytes32 subjectId)
        external
        view
        returns (T.AttestationRecord memory)
    {
        return _attestations[keccak256(abi.encode(collectionId, kind, subjectId))];
    }

    function attestationRecord(bytes32 record) external view returns (T.AttestationRecord memory) {
        return _records[record];
    }

    function statementBytes(bytes32 hash) external view returns (bytes memory) {
        return _statements[hash];
    }

    function claim(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external {
        _check(c, 1);
        Attribution memory prior = _attributions[collectionId];
        if (
            (prior.state != 0 && prior.state != 5) || b.generation != prior.generation + 1
                || b.bindingHash == bytes32(0)
        ) revert T.InvalidAttribution(collectionId);
        _attributions[collectionId] = Attribution(1, b.generation);
        _commit(
            c,
            keccak256(abi.encode(collectionId, b, reasonHash, reasonURI)),
            keccak256(abi.encode(collectionId, uint8(1), b.generation)),
            bytes32(0),
            bytes32(0)
        );
        emit ArtistAttributionStateChanged(
            1,
            collectionId,
            1,
            b.generation,
            prior.state,
            c.actor,
            0,
            b.bindingHash,
            reasonHash,
            reasonURI
        );
    }

    function recordRefusal(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p,
        address signer,
        uint256 nonce,
        bytes32 record
    ) external {
        _check(c, 3);
        if (signer != b.artistAddress || record == bytes32(0)) revert T.InvalidRecord();
        _terminate(c, b, p, signer, 1, nonce, record);
    }

    function recordWithdrawal(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p
    ) external {
        _check(c, 4);
        if (c.actor != b.proposer) revert T.Unauthorized(c.actor);
        _terminate(c, b, p, c.actor, 0, 0, b.bindingHash);
    }

    function _terminate(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p,
        address signer,
        uint8 authority,
        uint256 nonce,
        bytes32 recordReference
    ) private {
        Attribution storage item = _attributions[p.collectionId];
        if (
            item.state != 1 || item.generation != b.generation || b.accepted
                || p.generation != b.generation || p.bindingHash != b.bindingHash
        ) revert T.InvalidAttribution(p.collectionId);
        item.state = 5;
        _commit(
            c,
            keccak256(abi.encode(b, p, signer, authority, nonce, recordReference)),
            keccak256(abi.encode(p.collectionId, item)),
            bytes32(0),
            bytes32(0)
        );
        emit ArtistAttributionStateChanged(
            1,
            p.collectionId,
            5,
            b.generation,
            1,
            c.actor,
            authority,
            recordReference,
            p.reasonHash,
            p.reasonURI
        );
        emit ArtistBindingTerminationContext(
            1,
            p.collectionId,
            b.generation,
            recordReference,
            b.bindingHash,
            b.artistId,
            signer,
            nonce,
            _now()
        );
    }

    function accept(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        bytes32 record
    ) external {
        _check(c, 2);
        Attribution storage a = _attributions[collectionId];
        if (a.state != 1 || a.generation != b.generation || record == bytes32(0)) {
            revert T.InvalidAttribution(collectionId);
        }
        a.state = 2;
        _commit(
            c,
            keccak256(abi.encode(collectionId, b, record)),
            keccak256(abi.encode(collectionId, a)),
            bytes32(0),
            bytes32(0)
        );
        emit ArtistAttributionStateChanged(
            1, collectionId, 2, b.generation, 1, b.artistAddress, 1, record, bytes32(0), ""
        );
    }

    function recordAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        bytes calldata statement
    ) external returns (bytes32 record) {
        _check(c, 24);
        Attribution storage attr = _attributions[p.collectionId];
        if (attr.state != 2 || attr.generation != b.generation || signer != b.artistAddress) {
            revert T.InvalidAttribution(p.collectionId);
        }
        if (
            statement.length == 0 || p.statementHash == bytes32(0)
                || keccak256(statement) != p.statementHash
        ) revert T.InvalidRecord();
        if (statement.length > 8192) revert T.BoundExceeded(statement.length, 8192);
        if (bytes(p.statementURI).length > 2048) {
            revert T.BoundExceeded(bytes(p.statementURI).length, 2048);
        }
        if (p.subjectKind == 9) {
            if (
                p.subjectId != bytes32(uint256(uint160(core)))
                    || p.subjectStateHash
                        != StreamArtistHashes.deploymentFacts(_environment(), p.collectionId, b)
                    || p.schemaId != keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
            ) revert T.InvalidRecord();
        } else if (p.subjectKind == 10) {
            if (
                p.subjectId != b.artistId || p.subjectStateHash != b.identityRecordHash
                    || (p.schemaId != keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
                        && p.schemaId != keccak256("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1"))
            ) revert T.InvalidRecord();
        } else {
            revert T.UnsupportedProfile();
        }
        record = StreamArtistHashes.attestationRecord(
            _environment(), p, b.artistId, signer, nonce, signedAt
        );
        if (_records[record].recordHash != bytes32(0)) revert T.InvalidRecord();
        T.AttestationRecord memory item = T.AttestationRecord(
            record, p.subjectStateHash, p.schemaId, p.statementHash, b.generation, signedAt, signer
        );
        _records[record] = item;
        _attestations[keccak256(abi.encode(p.collectionId, p.subjectKind, p.subjectId))] = item;
        if (_statements[p.statementHash].length == 0) _statements[p.statementHash] = statement;
        _commit(
            c,
            keccak256(abi.encode(b, p, signer, nonce, signedAt, keccak256(statement))),
            keccak256(abi.encode(p.collectionId, p.subjectKind, p.subjectId, item)),
            bytes32(0),
            record
        );
        emit ArtistAttestationRecorded(
            1,
            p.collectionId,
            p.subjectKind,
            signer,
            p.subjectId,
            p.subjectStateHash,
            p.schemaId,
            p.statementHash,
            keccak256(bytes(p.statementURI)),
            1,
            nonce,
            signedAt,
            record
        );
    }
}
