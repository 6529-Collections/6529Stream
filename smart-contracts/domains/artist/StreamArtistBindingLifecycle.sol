// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredAcceptedBindingHydration as RecoveredAccepted } from "./StreamArtistRecoveredAcceptedBindingHydration.sol";
import {
    StreamArtistRecoveredBindingCorrectionHydration as RecoveredCorrections
} from "./StreamArtistRecoveredBindingCorrectionHydration.sol";
import {
    StreamArtistRecoveredBindingGenerations as RecoveredGenerations
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredSimpleHydration as RecoveredSimple
} from "./StreamArtistRecoveredSimpleHydration.sol";
import {
    StreamArtistRecoveredHydrationCodec as RecoveredCodec
} from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredHydrationTypes as RecoveredRH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import "./StreamArtistMultipleDelegationCollectionHydration.sol";
import "./StreamArtistMultipleCollectionHydration.sol";
import "./StreamArtistDelegationCollectionHydration.sol";
import "./StreamArtistCurrentAuthorityFacts.sol";

import "./StreamArtistOwner.sol";
import { StreamArtistBindingCorrectionState } from "./StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistBindingCorrectionTypes as BC
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import "./StreamArtistBindingOperations.sol";
import "./StreamArtistCollaboratorHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of collection binding generations and their immutable proposal terms.
contract StreamArtistBindingLifecycle is StreamArtistOwner {
    mapping(uint256 => T.Binding) private _bindings;
    mapping(uint256 => mapping(uint64 => T.Binding)) private _history;
    mapping(uint256 => mapping(uint64 => L.Terminal)) private _terminals;
    mapping(uint256 => mapping(uint64 => C.BindingTerms)) private _terms;
    mapping(uint256 => mapping(uint64 => T.CollaboratorRecord[])) private _collaborators;

    mapping(bytes32 => StreamArtistBindingCorrectionState.Correction) private _corrections;

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
        StreamArtistBindingCorrectionState.Summary memory empty;
        return _propose(c, collectionId, artistId, p, empty);
    }

    function proposeAfterRevocation(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 artistId,
        T.BindingProposal calldata p,
        BC.Approval calldata approval
    ) external returns (T.Binding memory) {
        _check(c, 1);
        StreamArtistBindingCorrectionState.Summary memory summary =
            StreamArtistBindingCorrectionState.validateEncoded(_bindings, msg.data);
        return _propose(c, collectionId, artistId, p, summary);
    }

    function bindingCorrection(bytes32 bindingHash)
        external
        view
        returns (BC.Approval calldata approval, bytes32 approvalHash)
    {
        bytes memory encoded = StreamArtistBindingCorrectionState.encoded(_corrections, bindingHash);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function _propose(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 artistId,
        T.BindingProposal calldata p,
        StreamArtistBindingCorrectionState.Summary memory approval
    ) private returns (T.Binding memory item) {
        if (
            collectionId == 0 || artistId == bytes32(0) || p.artistAddress == address(0)
                || p.identityRecordHash == bytes32(0)
        ) revert T.InvalidRecord();
        T.Binding storage previous = _bindings[collectionId];
        if (approval.cause == 0 ? previous.generation != 0 : previous.generation == 0) {
            revert T.InvalidAttribution(collectionId);
        }
        uint64 generation = previous.generation + 1;
        if (
            (p.consentMode != 1 && p.consentMode != 2) || p.saleConsentScope > 1
                || p.registryImmutabilityElection > 1 || p.collabPolicyMode != 0
                || p.collabThreshold != 0 || p.capabilityPolicyOverrides.length != 0
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
        _storeTerms(collectionId, generation, p.collaborators);
        item.bindingHash = StreamArtistCollaboratorHashes.binding(
            _environment(), collectionId, item, p.collaborators
        );
        _bindings[collectionId] = item;
        _history[collectionId][item.generation] = item;
        bytes32 key = _consume(
            keccak256("binding_lifecycle.replay.proposal_key"),
            keccak256(abi.encode(collectionId, item.generation)),
            item.bindingHash
        );
        if (approval.cause == 0) {
            _commit(
                c,
                keccak256(abi.encode(collectionId, artistId, p)),
                keccak256(abi.encode(collectionId, item)),
                keccak256(abi.encode(key, item.bindingHash)),
                item.bindingHash
            );
        } else {
            bytes32 record = StreamArtistBindingCorrectionState.hashEncoded(
                _environment(), collectionId, item.bindingHash, msg.data
            );
            bytes32 actionKey = _consume(
                keccak256("binding_lifecycle.replay.correction_action"), approval.actionId, record
            );
            StreamArtistBindingCorrectionState.saveEncoded(
                _corrections, item.bindingHash, record, msg.data
            );
            _commit(
                c,
                keccak256(abi.encode(collectionId, artistId, p, record)),
                keccak256(abi.encode(collectionId, item, record)),
                keccak256(abi.encode(key, item.bindingHash, actionKey, record)),
                item.bindingHash
            );
            emit BC.ArtistBindingCorrectionApproved(
                1,
                collectionId,
                item.bindingHash,
                record,
                approval.previousGeneration,
                approval.previousBindingHash,
                approval.cause,
                approval.causeRecord,
                approval.actionId
            );
        }
        _native(c.operationId, item.bindingHash, artistId, collectionId);
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
            _terms[collectionId][generation].collaboratorSetHash,
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
        _complete(c, collectionId, bindingHash, acceptanceRecord);
    }

    function completeCollaboratorBinding(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 bindingHash,
        bytes32 acceptanceRecord
    ) external {
        _check(c, 7);
        _complete(c, collectionId, bindingHash, acceptanceRecord);
    }

    function _complete(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 bindingHash,
        bytes32 acceptanceRecord
    ) private {
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

    function bindingTerms(uint256 collectionId, uint64 generation)
        external
        view
        returns (C.BindingTerms memory)
    {
        return _terms[collectionId][generation];
    }

    function collaboratorTerm(uint256 collectionId, uint64 generation, uint256 index)
        external
        view
        returns (T.CollaboratorRecord memory)
    {
        return _collaborators[collectionId][generation][index];
    }

    function _storeTerms(
        uint256 collectionId,
        uint64 generation,
        T.CollaboratorRecord[] calldata rows
    ) private {
        if (rows.length > 32) revert T.BoundExceeded(rows.length, 32);
        for (uint256 i; i < rows.length; ++i) {
            T.CollaboratorRecord calldata row = rows[i];
            if (row.account == address(0)) revert T.InvalidRecord();
            if (i != 0) {
                T.CollaboratorRecord calldata prior = rows[i - 1];
                // Strict (account,role) ordering also satisfies sorted triples and excludes duplicate pairs.
                if (
                    uint160(row.account) < uint160(prior.account)
                        || (row.account == prior.account
                            && uint256(row.role) <= uint256(prior.role))
                ) revert T.InvalidRecord();
            }
            _collaborators[collectionId][generation].push(row);
        }
        _terms[collectionId][generation] = C.BindingTerms(
            StreamArtistCollaboratorHashes.collaboratorSetHash(rows),
            StreamArtistHashes.emptyCapabilities(),
            0,
            0,
            uint32(rows.length)
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
        return _refuse(c, p, b, signer, nonce, 1);
    }

    function refuseWithAuthority(
        T.ActionContext calldata c,
        L.Termination calldata p,
        R.AuthorityFact calldata authority,
        address signer,
        uint256 nonce
    ) external returns (bytes32) {
        _check(c, 3);
        T.Binding memory b = _pending(p);
        StreamArtistCurrentAuthorityFacts.requirePrincipal(b.artistId, signer, authority, false);
        return _refuse(c, p, b, signer, nonce, authority.authorityClass);
    }

    function _refuse(
        T.ActionContext calldata c,
        L.Termination calldata p,
        T.Binding memory b,
        address signer,
        uint256 nonce,
        uint8 authorityClass
    ) private returns (bytes32 record) {
        record = StreamArtistBindingOperations.refusalRecordForAuthority(
            _environment(), p, b.artistId, signer, authorityClass, nonce, _now()
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
        _native(c.operationId, record, b.artistId, p.collectionId);
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
        if (bytes(p.reasonURI).length > 2048) {
            revert T.BoundExceeded(bytes(p.reasonURI).length, 2048);
        }
    }

    function authorityDelegationHydrationState(AH.Query calldata q)
        external
        view
        returns (bytes memory)
    {
        return StreamArtistDelegationCollectionHydration.bindingState(
            _bindings, _terms, _terminals, q
        );
    }

    function authorityHydrationState(AH.Query calldata q)
        external
        view
        override
        returns (bytes memory)
    {
        T.Binding memory b = _bindings[q.collectionId];
        C.BindingTerms memory terms = _terms[q.collectionId][b.generation];
        if (
            b.artistId != q.artistId || b.bindingHash != q.bindingHash || b.generation != 1
                || !b.accepted || b.consentMode != 1 || terms.count != 0 || terms.mode != 0
                || terms.threshold != 0 || _terminals[q.collectionId][1].kind != 0
        ) revert T.UnsupportedProfile();
        return abi.encode(AH.Binding(b, terms));
    }

    function _recoveredHydrationFeatures() internal pure override returns (uint256) {
        return RecoveredRH.MULTIPLE_GENERATIONS_GRAPH_FEATURES;
    }

    function recoveredAuthorityHydrationState(
        AH.Query calldata q,
        RecoveredRH.OwnerProvenance calldata local
    ) external view override returns (bytes memory) {
        return RecoveredSimple.exportBinding(_bindings, _history, _terms, _terminals, q, local);
    }

    function _hydrateAuthority(AH.Query calldata q, AH.OwnerData calldata p) internal override {
        if (RecoveredCodec.isState(p.typedState, 0)) {
            if (_revision != 0 || p.nonces.length != 0) revert T.InvalidRecord();
            if (RecoveredAccepted.importIfSelected(_bindings, _history, _terms, _terminals, _corrections, q, p.typedState)) return;
            if (RecoveredGenerations.selected(p.typedState)) {
                RecoveredGenerations.importState(
                    _bindings, _history, _terms, _terminals, q, p.typedState
                );
                return;
            }
            RecoveredSimple.importBinding(_bindings, _history, _terms, _terminals, q, p.typedState);
            return;
        }
        if (StreamArtistDelegationHydrationCodec.tagged(p.typedState, MD.BINDING)) {
            if (p.nonces.length != 0) revert T.InvalidRecord();
            StreamArtistMultipleDelegationCollectionHydration.bindings(
                _bindings, _history, _terms, p.typedState
            );
            return;
        }
        if (StreamArtistDelegationHydrationCodec.tagged(p.typedState, DH.BINDING)) {
            if (p.nonces.length != 0) revert T.InvalidRecord();
            StreamArtistDelegationCollectionHydration.importBinding(
                _bindings, _history, _terms, q, p.typedState
            );
            return;
        }
        if (StreamArtistMultipleHydrationCodec.isState(p.typedState)) {
            if (p.nonces.length != 0) revert T.InvalidRecord();
            StreamArtistMultipleCollectionHydration.bindings(
                _bindings, _history, _terms, p.typedState
            );
            return;
        }
        AH.Binding memory b = abi.decode(p.typedState, (AH.Binding));
        if (_bindings[q.collectionId].generation != 0 || p.nonces.length != 0) {
            revert T.InvalidRecord();
        }
        _bindings[q.collectionId] = b.item;
        _history[q.collectionId][b.item.generation] = b.item;
        _terms[q.collectionId][b.item.generation] = b.terms;
    }
}
