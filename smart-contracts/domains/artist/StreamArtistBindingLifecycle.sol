// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOwner.sol";
import "./StreamArtistBindingOperations.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of collection binding generations and their immutable proposal terms.
contract StreamArtistBindingLifecycle is StreamArtistOwner {
    mapping(uint256 => T.Binding) private _bindings;
    mapping(uint256 => mapping(uint64 => T.Binding)) private _history;
    mapping(uint256 => mapping(uint64 => L.Terminal)) private _terminals;
    event ArtistBindingProposed(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed artistId,
        address indexed artistAddress,
        uint64 bindingGeneration,
        bytes32 bindingHash,
        uint8 consentMode,
        uint8 saleConsentScope,
        uint8 registryImmutabilityElection,
        uint8 collabPolicyMode,
        uint32 collabThreshold,
        bytes32 collaboratorSetHash,
        bytes32 capabilityPolicySetHash,
        address proposer,
        bytes32 reasonHash,
        string reasonURI
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
            keccak256("domain:binding_lifecycle"),
            core_,
            manager_
        )
    { }

    function binding(uint256 collectionId) external view returns (T.Binding memory) {
        return _bindings[collectionId];
    }

    function bindingAt(uint256 collectionId, uint64 generation)
        external
        view
        returns (T.Binding memory)
    {
        return _history[collectionId][generation];
    }

    function bindingTermination(uint256 collectionId, uint64 generation)
        external
        view
        returns (L.Terminal memory)
    {
        return _terminals[collectionId][generation];
    }

    function propose(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 artistId,
        T.BindingProposal calldata p
    ) external returns (T.Binding memory item) {
        _check(c, 1);
        if (
            collectionId == 0 || artistId == bytes32(0) || p.artistAddress == address(0)
                || p.identityRecordHash == bytes32(0)
        ) revert T.InvalidRecord();
        T.Binding storage previous = _bindings[collectionId];
        if (
            previous.generation != 0
                && (previous.accepted || _terminals[collectionId][previous.generation].kind == 0)
        ) revert T.InvalidAttribution(collectionId);
        uint64 generation = previous.generation + 1;
        if (
            p.consentMode != 1 || p.saleConsentScope != 0 || p.registryImmutabilityElection > 1
                || p.collabPolicyMode != 0 || p.collabThreshold != 0 || p.collaborators.length != 0
                || p.capabilityPolicyOverrides.length != 0
        ) revert T.UnsupportedProfile();
        if (bytes(p.reasonURI).length > 2048) {
            revert T.BoundExceeded(bytes(p.reasonURI).length, 2048);
        }
        item = T.Binding(
            artistId,
            p.artistAddress,
            p.identityRecordHash,
            bytes32(0),
            generation,
            p.consentMode,
            p.saleConsentScope,
            p.registryImmutabilityElection,
            c.actor,
            false
        );
        item.bindingHash = StreamArtistHashes.binding(_environment(), collectionId, item);
        _bindings[collectionId] = item;
        _history[collectionId][item.generation] = item;
        bytes32 key = _consume(
            keccak256("binding_lifecycle.replay.proposal_key"),
            keccak256(abi.encode(collectionId, item.generation)),
            item.bindingHash
        );
        _commit(
            c,
            keccak256(abi.encode(collectionId, artistId, p)),
            keccak256(abi.encode(collectionId, item)),
            keccak256(abi.encode(key, item.bindingHash)),
            item.bindingHash
        );
        emit ArtistBindingProposed(
            1,
            collectionId,
            artistId,
            item.artistAddress,
            item.generation,
            item.bindingHash,
            item.consentMode,
            item.saleConsentScope,
            item.registryImmutabilityElection,
            0,
            0,
            StreamArtistHashes.emptyCollaborators(),
            StreamArtistHashes.emptyCapabilities(),
            c.actor,
            p.reasonHash,
            p.reasonURI
        );
    }

    function accept(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 bindingHash,
        bytes32 acceptanceRecord
    ) external {
        _check(c, 2);
        T.Binding storage item = _bindings[collectionId];
        if (
            item.generation == 0 || item.accepted || item.bindingHash != bindingHash
                || _terminals[collectionId][item.generation].kind != 0
                || acceptanceRecord == bytes32(0)
        ) {
            revert T.InvalidAttribution(collectionId);
        }
        item.accepted = true;
        _history[collectionId][item.generation].accepted = true;
        _commit(
            c,
            keccak256(abi.encode(collectionId, bindingHash, acceptanceRecord)),
            keccak256(abi.encode(collectionId, item)),
            bytes32(0),
            bytes32(0)
        );
    }

    function refuse(
        T.ActionContext calldata c,
        L.Termination calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        _check(c, 3);
        T.Binding memory b = _pending(p);
        if (signer != b.artistAddress) revert T.InvalidSignature();
        record = StreamArtistBindingOperations.refusalRecord(
            _environment(), p, b.artistId, signer, nonce, _now()
        );
        bytes32 key = _consume(
            keccak256("binding_lifecycle.replay.refusal_uniqueness"),
            keccak256(abi.encode(p.collectionId, p.generation)),
            record
        );
        _terminals[p.collectionId][p.generation] = L.Terminal(1, p.reasonHash, record);
        _commit(
            c,
            keccak256(abi.encode(b, p, signer, nonce)),
            keccak256(
                abi.encode(p.collectionId, p.generation, _terminals[p.collectionId][p.generation])
            ),
            keccak256(abi.encode(key, record)),
            record
        );
    }

    function withdraw(T.ActionContext calldata c, L.Termination calldata p) external {
        _check(c, 4);
        T.Binding memory b = _pending(p);
        if (c.actor != b.proposer) revert T.Unauthorized(c.actor);
        bytes32 key = _consume(
            keccak256("binding_lifecycle.replay.proposal_terminal_transition_key"),
            keccak256(abi.encode(p.collectionId, p.generation)),
            b.bindingHash
        );
        _terminals[p.collectionId][p.generation] = L.Terminal(2, p.reasonHash, bytes32(0));
        _commit(
            c,
            keccak256(abi.encode(b, p)),
            keccak256(
                abi.encode(p.collectionId, p.generation, _terminals[p.collectionId][p.generation])
            ),
            keccak256(abi.encode(key, b.bindingHash)),
            bytes32(0)
        );
    }

    function _pending(L.Termination calldata p) private view returns (T.Binding memory b) {
        b = _bindings[p.collectionId];
        if (
            b.generation == 0 || b.accepted || p.generation != b.generation
                || p.bindingHash != b.bindingHash
                || _terminals[p.collectionId][p.generation].kind != 0
        ) revert T.InvalidAttribution(p.collectionId);
        if (p.reasonHash == bytes32(0)) revert T.InvalidRecord();
        if (bytes(p.reasonURI).length > 2048) revert T.BoundExceeded(
            bytes(p.reasonURI).length, 2048
        );
    }
}
