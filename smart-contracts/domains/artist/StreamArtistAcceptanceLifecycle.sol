// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOwner.sol";
import "./StreamArtistCollaboratorHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of acceptance records and acceptance-domain events.
contract StreamArtistAcceptanceLifecycle is StreamArtistOwner {
    mapping(bytes32 => bytes32) public acceptanceRecord;
    mapping(bytes32 => uint64) public acceptedAt;
    mapping(bytes32 => bytes32) private _collaboratorRecords;
    event CollaboratorAccepted(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed collaborator,
        bytes32 indexed collaboratorArtistId,
        uint64 bindingGeneration,
        bytes32 role,
        bytes32 shareLabelId,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 acceptanceRecordHash,
        bytes32 bindingHash
    );
    event ArtistBindingAccepted(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed artistId,
        address indexed signer,
        uint64 bindingGeneration,
        bytes32 bindingHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 acceptanceRecordHash
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
            keccak256("domain:acceptance_lifecycle"),
            core_,
            manager_
        )
    { }

    function recordAcceptance(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        _check(c, 2);
        if (b.accepted || b.bindingHash == bytes32(0) || signer != b.artistAddress) {
            revert T.InvalidRecord();
        }
        record = StreamArtistHashes.acceptanceRecord(
            _environment(), collectionId, b, signer, nonce, _now()
        );
        bytes32 key = _consume(
            keccak256("acceptance_lifecycle.replay.record_uniqueness"),
            keccak256(abi.encode(collectionId, b.generation, uint8(1), signer)),
            record
        );
        acceptanceRecord[b.bindingHash] = record;
        acceptedAt[b.bindingHash] = _now();
        _commit(
            c,
            keccak256(abi.encode(collectionId, b, signer, nonce)),
            keccak256(abi.encode(b.bindingHash, record)),
            keccak256(abi.encode(key, record)),
            record
        );
        emit ArtistBindingAccepted(
            1,
            collectionId,
            b.artistId,
            signer,
            b.generation,
            b.bindingHash,
            1,
            nonce,
            _now(),
            record
        );
    }

    function collaboratorAcceptanceRecord(
        bytes32 bindingHash,
        address account,
        bytes32 role,
        bytes32 shareLabelId
    ) external view returns (bytes32) {
        return _collaboratorRecords[
            StreamArtistCollaboratorHashes.rowKey(bindingHash, account, role, shareLabelId)
        ];
    }

    function recordCollaboratorAcceptance(
        T.ActionContext calldata c,
        C.BindingAcceptance calldata p,
        bytes32 artistId,
        uint256 nonce
    ) external returns (bytes32 record) {
        _check(c, 7);
        if (
            p.collectionId == 0 || p.generation == 0 || p.bindingHash == bytes32(0)
                || p.account == address(0) || artistId == bytes32(0)
        ) revert T.InvalidRecord();
        record = StreamArtistCollaboratorHashes.acceptanceRecord(_environment(), p, nonce, _now());
        bytes32 row =
            StreamArtistCollaboratorHashes.rowKey(p.bindingHash, p.account, p.role, p.shareLabelId);
        bytes32 key = _consume(
            keccak256("acceptance_lifecycle.replay.record_uniqueness"),
            keccak256(
                abi.encode(
                    p.collectionId, p.generation, uint8(2), p.account, p.role, p.shareLabelId
                )
            ),
            record
        );
        _collaboratorRecords[row] = record;
        _commit(
            c,
            keccak256(abi.encode(p, artistId, nonce)),
            keccak256(abi.encode(row, artistId, record)),
            keccak256(abi.encode(key, record)),
            record
        );
        emit CollaboratorAccepted(
            1,
            p.collectionId,
            p.account,
            artistId,
            p.generation,
            p.role,
            p.shareLabelId,
            1,
            nonce,
            _now(),
            record,
            p.bindingHash
        );
    }
}
