// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of acceptance records and acceptance-domain events.
contract StreamArtistAcceptanceLifecycle is StreamArtistOwner {
    mapping(bytes32 => bytes32) public acceptanceRecord;
    mapping(bytes32 => uint64) public acceptedAt;
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
}
