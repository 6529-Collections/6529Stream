// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSimpleHydrationTypes as S
} from "../../interfaces/stream/artist/StreamArtistRecoveredSimpleHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistCollaboratorHashes as Collaborators
} from "./StreamArtistCollaboratorHashes.sol";

/// @notice Fixed storage adapters for the singleton accepted generation1, no-collaborator profile.
/// @dev Every original owner era is accounted for, including non-native acceptance and imports.
/// Unknown maps cannot be inferred empty from a zero native count. Source checks read only this
/// semantic owner plus immutable suite bindings. Destination decoding makes no source call.
library StreamArtistRecoveredSimpleHydration {
    function exportBinding(
        mapping(uint256 => T.Binding) storage bindings,
        mapping(uint256 => mapping(uint64 => T.Binding)) storage history,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        mapping(uint256 => mapping(uint64 => L.Terminal)) storage terminals,
        AH.Query memory q,
        RH.OwnerProvenance memory local
    ) public view returns (bytes memory) {
        Provenance.validateOwnerSource(local, 0, address(this));
        S.Binding memory b;
        b.scope = scope(q);
        b.provenanceCommitment = RH.ownerProvenanceHash(local, 0);
        b.item = bindings[q.collectionId];
        b.history = history[q.collectionId][1];
        b.terms = terms[q.collectionId][1];
        b.terminal = terminals[q.collectionId][1];
        validateBinding(q, local, b);
        return abi.encode(S.BINDING, RH.VERSION, b);
    }

    function importBinding(
        mapping(uint256 => T.Binding) storage bindings,
        mapping(uint256 => mapping(uint64 => T.Binding)) storage history,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        mapping(uint256 => mapping(uint64 => L.Terminal)) storage terminals,
        AH.Query memory q,
        bytes memory raw
    ) public {
        (RH.ExportHeader memory header, Payload.Payload memory p) = Payload.decode(raw, 0);
        S.Binding memory b = decodeBinding(q, p.provenance, p.semanticState);
        if (b.item.consentMode == 2 && (header.requiredFeatures & RH.DELEGATED_CONSENT) == 0) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        T.Binding memory emptyBinding;
        C.BindingTerms memory emptyTerms;
        L.Terminal memory emptyTerminal;
        if (
            keccak256(abi.encode(bindings[q.collectionId])) != keccak256(abi.encode(emptyBinding))
                || keccak256(abi.encode(history[q.collectionId][1]))
                    != keccak256(abi.encode(emptyBinding))
                || keccak256(abi.encode(terms[q.collectionId][1]))
                    != keccak256(abi.encode(emptyTerms))
                || keccak256(abi.encode(terminals[q.collectionId][1]))
                    != keccak256(abi.encode(emptyTerminal))
        ) revert T.InvalidRecord();
        bindings[q.collectionId] = b.item;
        history[q.collectionId][1] = b.history;
        terms[q.collectionId][1] = b.terms;
        terminals[q.collectionId][1] = b.terminal;
    }

    function exportAcceptance(
        mapping(bytes32 => bytes32) storage records,
        mapping(bytes32 => uint64) storage times,
        AH.Query memory q,
        RH.OwnerProvenance memory local
    ) public view returns (bytes memory) {
        Provenance.validateOwnerSource(local, 3, address(this));
        S.Acceptance memory a = S.Acceptance(
            scope(q), RH.ownerProvenanceHash(local, 3), records[q.bindingHash], times[q.bindingHash]
        );
        validateAcceptance(q, local, a);
        return abi.encode(S.ACCEPTANCE, RH.VERSION, a);
    }

    function importAcceptance(
        mapping(bytes32 => bytes32) storage records,
        mapping(bytes32 => uint64) storage times,
        AH.Query memory q,
        bytes memory raw
    ) public {
        (, Payload.Payload memory p) = Payload.decode(raw, 3);
        S.Acceptance memory a = decodeAcceptance(q, p.provenance, p.semanticState);
        if (records[q.bindingHash] != 0 || times[q.bindingHash] != 0) revert T.InvalidRecord();
        records[q.bindingHash] = a.record;
        times[q.bindingHash] = a.acceptedAt;
    }

    function exportCollaborator(AH.Query memory q, RH.OwnerProvenance memory local)
        public
        view
        returns (bytes memory)
    {
        Provenance.validateOwnerSource(local, 1, address(this));
        S.EmptyCollaborator memory c =
            S.EmptyCollaborator(scope(q), RH.ownerProvenanceHash(local, 1));
        validateCollaborator(q, local, c);
        return abi.encode(S.COLLABORATOR, RH.VERSION, c);
    }

    function importCollaborator(AH.Query memory q, bytes memory raw) public pure {
        (, Payload.Payload memory p) = Payload.decode(raw, 1);
        decodeCollaborator(q, p.provenance, p.semanticState);
        // The exact zero-history certificate has no semantic map entry to install.
    }

    function decodeBinding(AH.Query memory q, RH.OwnerProvenance memory local, bytes memory raw)
        public
        pure
        returns (S.Binding memory b)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, b) = abi.decode(raw, (bytes32, uint16, S.Binding));
        _canonical(raw, tag, S.BINDING, version, abi.encode(tag, version, b));
        validateBinding(q, local, b);
    }

    function decodeAcceptance(AH.Query memory q, RH.OwnerProvenance memory local, bytes memory raw)
        public
        pure
        returns (S.Acceptance memory a)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, a) = abi.decode(raw, (bytes32, uint16, S.Acceptance));
        _canonical(raw, tag, S.ACCEPTANCE, version, abi.encode(tag, version, a));
        validateAcceptance(q, local, a);
    }

    function decodeCollaborator(
        AH.Query memory q,
        RH.OwnerProvenance memory local,
        bytes memory raw
    ) public pure returns (S.EmptyCollaborator memory c) {
        bytes32 tag;
        uint16 version;
        (tag, version, c) = abi.decode(raw, (bytes32, uint16, S.EmptyCollaborator));
        _canonical(raw, tag, S.COLLABORATOR, version, abi.encode(tag, version, c));
        validateCollaborator(q, local, c);
    }

    function validateBinding(AH.Query memory q, RH.OwnerProvenance memory local, S.Binding memory b)
        public
        pure
    {
        _scope(q, b.scope);
        _history(local, 0, b.provenanceCommitment);
        RH.JournalEntry memory row = local.journal[0];
        L.Terminal memory emptyTerminal;
        if (
            b.item.artistId != q.artistId || b.item.bindingHash != q.bindingHash
                || b.item.artistAddress == address(0) || b.item.identityRecordHash == 0
                || b.item.proposer == address(0) || b.item.generation != 1 || !b.item.accepted
                || (b.item.consentMode != 1 && b.item.consentMode != 2)
                || b.item.saleConsentScope > 1 || b.item.registryImmutabilityElection > 1
                || keccak256(abi.encode(b.item)) != keccak256(abi.encode(b.history))
                || keccak256(abi.encode(b.terminal)) != keccak256(abi.encode(emptyTerminal))
                || b.terms.count != 0 || b.terms.mode != 0 || b.terms.threshold != 0
                || b.terms.collaboratorSetHash != Hashes.emptyCollaborators()
                || b.terms.capabilityPolicySetHash != Hashes.emptyCapabilities()
                || row.receipt.artistId != q.artistId || row.receipt.collectionId != q.collectionId
                || row.receipt.recordHash != q.bindingHash
        ) revert T.UnsupportedProfile();
        RH.OriginEnvironment memory origin = local.origins[0];
        if (
            Collaborators.binding(
                    Hashes.Environment(
                        origin.chainId, origin.registry, origin.core, origin.manager
                    ),
                    q.collectionId,
                    b.item,
                    new T.CollaboratorRecord[](0)
                ) != q.bindingHash
        ) revert T.InvalidRecord();
        _guards(
            local,
            0,
            keccak256("binding_lifecycle.replay.proposal_key"),
            keccak256(abi.encode(q.collectionId, uint64(1))),
            q.bindingHash
        );
    }

    function validateAcceptance(
        AH.Query memory q,
        RH.OwnerProvenance memory local,
        S.Acceptance memory a
    ) public pure {
        _scope(q, a.scope);
        _history(local, 3, a.provenanceCommitment);
        RH.JournalEntry memory row = local.journal[0];
        if (
            a.record == 0 || a.acceptedAt == 0 || row.receipt.artistId != q.artistId
                || row.receipt.collectionId != q.collectionId || row.receipt.recordHash != a.record
        ) revert T.UnsupportedProfile();
        // The original mapping stores record/time, not signer/nonce. The actual owner export
        // authenticates those unchanged fields; a guessed acceptance preimage is not substituted.
        _guards(local, 3, keccak256("acceptance_lifecycle.replay.record_uniqueness"), 0, a.record);
    }

    function validateCollaborator(
        AH.Query memory q,
        RH.OwnerProvenance memory local,
        S.EmptyCollaborator memory c
    ) public pure {
        _scope(q, c.scope);
        _history(local, 1, c.provenanceCommitment);
        if (local.aliases.length != 0) revert T.UnsupportedProfile();
        RH.OriginEnvironment memory origin = local.origins[0];
        T.Snapshot memory initial = local.eras[0].checkpoint.ownerState;
        if (
            initial.stateRoot
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_OWNER_STATE_GENESIS_V2"),
                            origin.chainId,
                            origin.registry,
                            origin.coordinator,
                            origin.archive,
                            origin.owners[1],
                            RH.ownerDomain(1)
                        )
                    )
                || initial.recordChainTip
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_OWNER_RECORD_GENESIS_V2"),
                            origin.chainId,
                            origin.registry,
                            origin.coordinator,
                            origin.archive,
                            origin.owners[1],
                            RH.ownerDomain(1)
                        )
                    )
        ) revert T.UnsupportedProfile();
    }

    function scope(AH.Query memory q) public pure returns (S.Scope memory result) {
        if (q.artistId == 0 || q.collectionId == 0 || q.bindingHash == 0) {
            revert T.UnsupportedProfile();
        }
        return S.Scope(q.artistId, q.collectionId, q.bindingHash);
    }

    function _scope(AH.Query memory q, S.Scope memory actual) private pure {
        if (keccak256(abi.encode(scope(q))) != keccak256(abi.encode(actual))) {
            revert T.InvalidRecord();
        }
    }

    function _history(RH.OwnerProvenance memory local, uint8 ownerIndex, bytes32 commitment)
        private
        pure
    {
        if (Provenance.validateOwner(local, ownerIndex) != commitment) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        bool empty = ownerIndex == 1;
        if (local.journal.length != (empty ? 0 : 1)) revert T.UnsupportedProfile();
        for (uint256 i; i < local.eras.length; ++i) {
            RH.OwnerEra memory era = local.eras[i];
            uint256 nativeCount = i == 0 && !empty ? 1 : 0;
            uint64 expectedRevision = i == 0 ? (empty ? 0 : (ownerIndex == 0 ? 2 : 1)) : 1;
            if (
                era.nativeCount != nativeCount || era.lowerRevision != (i == 0 ? 0 : 1)
                    || era.checkpoint.ownerState.revision != expectedRevision
                    || era.checkpoint.nonceIndexCount != 0 || era.checkpoint.nonceRoot != 0
                    || era.checkpoint.replayCount != (empty ? 0 : 1)
                    || (empty && era.checkpoint.replayRoot != 0)
            ) revert T.UnsupportedProfile();
        }
        if (!empty) {
            RH.JournalEntry memory row = local.journal[0];
            if (
                row.position.point.environmentHash != local.eras[0].originHash
                    || row.position.point.ownerRevision != 1
                    || row.receipt.operation != (ownerIndex == 0 ? 1 : 2)
            ) revert T.UnsupportedProfile();
        }
    }

    function _guards(
        RH.OwnerProvenance memory local,
        uint8 ownerIndex,
        bytes32 surface,
        bytes32 exactScope,
        bytes32 record
    ) private pure {
        if (local.aliases.length != local.eras.length) {
            revert T.UnsupportedProfile();
        }
        for (uint256 i; i < local.aliases.length; ++i) {
            RH.ReplayAlias memory a = local.aliases[i];
            if (
                a.ownerIndex != ownerIndex || a.surface != surface || a.scope == 0
                    || (exactScope != 0 && a.scope != exactScope) || a.cell.commitment != record
                    || a.cell.kind != 1 || a.cell.status != 2
                    || keccak256(abi.encode(a.admittedAt))
                        != keccak256(abi.encode(local.journal[0].position.point))
            ) revert T.UnsupportedProfile();
        }
    }

    function _canonical(
        bytes memory raw,
        bytes32 actual,
        bytes32 expected,
        uint16 version,
        bytes memory canonical
    ) private pure {
        if (actual != expected || version != RH.VERSION || keccak256(raw) != keccak256(canonical)) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
    }
}
