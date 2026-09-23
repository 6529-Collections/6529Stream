// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistBindingLifecycle as Lifecycle
} from "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistCollaboratorHashes as Collaborators
} from "./StreamArtistCollaboratorHashes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

import {
    StreamArtistRecoveredBindingGenerationModes as Modes
} from "./StreamArtistRecoveredBindingGenerationModes.sol";

/// @notice Complete original pending binding generations followed by one accepted generation.
/// @dev All original owner0 mutations occur in the first era; accepted bindings cannot be
/// reproposed. Later eras contain only the real import mutation. Refusal maps omit signer,
/// nonce and observed time: fixed-source records/receipts authenticate them without guessed
/// preimages. The Coordinator separately authenticates Identity, Acceptance and Attribution.
library StreamArtistRecoveredBindingGenerations {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_RECOVERED_BINDING_GENERATIONS_V1");
    uint256 internal constant MAX_GENERATIONS = 128;
    bytes32 private constant PROPOSAL = keccak256("binding_lifecycle.replay.proposal_key");
    bytes32 private constant REFUSAL = keccak256("binding_lifecycle.replay.refusal_uniqueness");
    bytes32 private constant WITHDRAWAL =
        keccak256("binding_lifecycle.replay.proposal_terminal_transition_key");

    struct Row {
        T.Binding item;
        C.BindingTerms terms;
        L.Terminal terminal;
    }

    struct Bundle {
        bytes32 artistId;
        uint256 collectionId;
        bytes32 bindingHash;
        bytes32 provenanceCommitment;
        T.Binding current;
        Row[] rows;
    }

    function selected(bytes memory outer) public pure returns (bool) {
        (RH.ExportHeader memory h,) = Payload.decode(outer, 0);
        return (h.requiredFeatures & RH.BINDING_GENERATIONS) != 0;
    }

    function collect(address source, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        view
        returns (Bundle memory b)
    {
        Provenance.validateOwnerSource(p, 0, source);
        b.artistId = q.artistId;
        b.collectionId = q.collectionId;
        b.bindingHash = q.bindingHash;
        b.provenanceCommitment = RH.ownerProvenanceHash(p, 0);
        b.current = Binding(source).binding(q.collectionId);
        uint256 count = b.current.generation;
        if (count < 2 || count > MAX_GENERATIONS) revert T.UnsupportedProfile();
        b.rows = new Row[](count);
        for (uint256 i; i < count; ++i) {
            uint64 generation = uint64(i + 1);
            b.rows[i] = Row(
                Binding(source).bindingAt(q.collectionId, generation),
                Terms(source).bindingTerms(q.collectionId, generation),
                Lifecycle(source).bindingTermination(q.collectionId, generation)
            );
        }
        validate(b, q, p);
    }

    function encode(Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        pure
        returns (bytes memory)
    {
        validate(b, q, p);
        return abi.encode(SCHEMA, RH.VERSION, b);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        pure
        returns (Bundle memory b)
    {
        if (Modes.tagged(raw)) return Modes.decode(q, p, raw);
        bytes32 schema;
        uint16 version;
        (schema, version, b) = abi.decode(raw, (bytes32, uint16, Bundle));
        if (
            schema != SCHEMA || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(schema, version, b))
        ) _invalid();
        validate(b, q, p);
    }

    function validate(Bundle memory b, AH.Query memory q, RH.OwnerProvenance memory p) public pure {
        if (Provenance.validateOwner(p, 0) != b.provenanceCommitment) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        uint256 count = b.rows.length;
        if (count < 2 || count > MAX_GENERATIONS) revert T.UnsupportedProfile();
        if (
            q.artistId == 0 || q.collectionId == 0 || q.bindingHash == 0 || b.artistId != q.artistId
                || b.collectionId != q.collectionId || b.bindingHash != q.bindingHash
                || b.current.bindingHash != q.bindingHash
                || keccak256(abi.encode(b.current)) != keccak256(abi.encode(b.rows[count - 1].item))
        ) _invalid();
        uint256 cursor;
        RH.OriginEnvironment memory origin = p.origins[0];
        for (uint256 i; i < count; ++i) {
            Row memory r = b.rows[i];
            _row(r, q, uint64(i + 1), i + 1 == count, origin);
            _native(p, cursor++, q, 1, r.item.bindingHash, uint64(2 * i + 1));
            if (r.terminal.kind == 1) {
                _native(p, cursor++, q, 3, r.terminal.recordHash, uint64(2 * i + 2));
            }
        }
        if (cursor != p.journal.length) _invalid();
        uint256 guards = 2 * count - 1;
        for (uint256 i; i < p.eras.length; ++i) {
            RH.OwnerEra memory era = p.eras[i];
            if (
                era.nativeCount != (i == 0 ? cursor : 0) || era.lowerRevision != (i == 0 ? 0 : 1)
                    || era.checkpoint.ownerState.revision != (i == 0 ? 2 * count : 1)
                    || era.checkpoint.replayCount != guards || era.checkpoint.nonceIndexCount != 0
                    || era.checkpoint.nonceRoot != 0
            ) _invalid();
        }
        if (p.aliases.length != guards * p.eras.length) _invalid();
        _guards(b, p);
    }

    function importState(
        mapping(uint256 => T.Binding) storage bindings,
        mapping(uint256 => mapping(uint64 => T.Binding)) storage history,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        mapping(uint256 => mapping(uint64 => L.Terminal)) storage terminals,
        AH.Query memory q,
        bytes memory outer
    ) public {
        (RH.ExportHeader memory h, Payload.Payload memory p) = Payload.decode(outer, 0);
        if ((h.requiredFeatures & RH.BINDING_GENERATIONS) == 0 || p.nonces.length != 0) _invalid();
        Bundle memory b = decode(q, p.provenance, p.semanticState);
        if (b.current.consentMode == 2 && (h.requiredFeatures & RH.DELEGATED_CONSENT) == 0) {
            _invalid();
        }
        T.Binding memory emptyBinding;
        C.BindingTerms memory emptyTerms;
        L.Terminal memory emptyTerminal;
        if (keccak256(abi.encode(bindings[q.collectionId])) != keccak256(abi.encode(emptyBinding)))
        {
            revert T.InvalidRecord();
        }
        for (uint256 i; i < b.rows.length; ++i) {
            uint64 generation = uint64(i + 1);
            if (
                keccak256(abi.encode(history[q.collectionId][generation]))
                        != keccak256(abi.encode(emptyBinding))
                    || keccak256(abi.encode(terms[q.collectionId][generation]))
                        != keccak256(abi.encode(emptyTerms))
                    || keccak256(abi.encode(terminals[q.collectionId][generation]))
                        != keccak256(abi.encode(emptyTerminal))
            ) {
                revert T.InvalidRecord();
            }
        }
        bindings[q.collectionId] = b.current;
        for (uint256 i; i < b.rows.length; ++i) {
            uint64 generation = uint64(i + 1);
            history[q.collectionId][generation] = b.rows[i].item;
            terms[q.collectionId][generation] = b.rows[i].terms;
            terminals[q.collectionId][generation] = b.rows[i].terminal;
        }
    }

    function _row(
        Row memory r,
        AH.Query memory q,
        uint64 generation,
        bool last,
        RH.OriginEnvironment memory o
    ) private pure {
        if (
            r.item.artistId != q.artistId || r.item.artistAddress == address(0)
                || r.item.identityRecordHash == 0 || r.item.proposer == address(0)
                || r.item.generation != generation || r.item.accepted != last
                || r.item.consentMode != 1 || r.item.saleConsentScope > 1
                || r.item.registryImmutabilityElection > 1 || r.terms.count != 0
                || r.terms.mode != 0 || r.terms.threshold != 0
                || r.terms.collaboratorSetHash != Hashes.emptyCollaborators()
                || r.terms.capabilityPolicySetHash != Hashes.emptyCapabilities()
        ) _invalid();
        if (
            Collaborators.binding(
                    Hashes.Environment(o.chainId, o.registry, o.core, o.manager),
                    q.collectionId,
                    r.item,
                    new T.CollaboratorRecord[](0)
                ) != r.item.bindingHash
        ) _invalid();
        if (last) {
            L.Terminal memory empty;
            if (keccak256(abi.encode(r.terminal)) != keccak256(abi.encode(empty))) _invalid();
        } else if (
            r.terminal.reasonHash == 0 || (r.terminal.kind != 1 && r.terminal.kind != 2)
                || (r.terminal.kind == 1 && r.terminal.recordHash == 0)
                || (r.terminal.kind == 2 && r.terminal.recordHash != 0)
        ) {
            _invalid();
        }
    }

    function _native(
        RH.OwnerProvenance memory p,
        uint256 at,
        AH.Query memory q,
        uint16 operation,
        bytes32 record,
        uint64 revision
    ) private pure {
        if (at >= p.journal.length) _invalid();
        RH.JournalEntry memory row = p.journal[at];
        if (
            row.receipt.operation != operation || row.receipt.recordHash != record
                || row.receipt.artistId != q.artistId || row.receipt.collectionId != q.collectionId
                || row.position.point.environmentHash != p.eras[0].originHash
                || row.position.point.ownerRevision != revision
        ) _invalid();
        for (uint256 i; i < at; ++i) {
            if (p.journal[i].receipt.recordHash == record) _invalid();
        }
    }

    function _guards(Bundle memory b, RH.OwnerProvenance memory p) private pure {
        // Provenance validates canonical sorted unique keys and the count in EVERY era.
        // Exactly 2N-1 distinct allowed logical keys therefore cover each complete rekeyed set.
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            bool found;
            for (uint256 j; j < b.rows.length; ++j) {
                if (a.scope != keccak256(abi.encode(b.collectionId, uint64(j + 1)))) continue;
                Row memory r = b.rows[j];
                bool proposal = a.surface == PROPOSAL;
                bytes32 record = proposal ? r.item.bindingHash : r.terminal.recordHash;
                if (!proposal) {
                    if (r.terminal.kind == 1 && a.surface == REFUSAL) { } else if (
                        r.terminal.kind == 2 && a.surface == WITHDRAWAL
                    ) {
                        record = r.item.bindingHash;
                    } else {
                        _invalid();
                    }
                }
                if (
                    a.cell.kind != 1 || a.cell.status != 2 || a.cell.commitment != record
                        || a.admittedAt.environmentHash != p.eras[0].originHash
                        || a.admittedAt.ownerRevision != uint64(2 * j + (proposal ? 1 : 2))
                ) _invalid();
                found = true;
                break;
            }
            if (!found) _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
