// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredBindingGenerationModes as Modes
} from "./StreamArtistRecoveredBindingGenerationModes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionValidation as Validation
} from "./StreamArtistRecoveredBindingCorrectionValidation.sol";
import {
    StreamArtistRecoveredBindingGenerations as Original
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistBindingCorrectionState as State
} from "./StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
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
    IStreamArtistBindingCorrectionOwner as Corrections
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";

/// @notice Retains full immutable class2 correction approvals alongside original generation maps.
/// @dev No new authority: source collection authenticates original fixed owner maps and complete
/// checkpoint journals/aliases. Import executes only beneath the original guarded operation60.
library StreamArtistRecoveredBindingCorrectionHydration {
    function selected(RH.OwnerProvenance memory p) public pure returns (bool) {
        for (uint256 i; i < p.aliases.length; ++i) {
            if (p.aliases[i].surface == CB.ACTION) return true;
        }
        return false;
    }

    function collect(address source, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        view
        returns (CB.Bundle memory corrected)
    {
        Provenance.validateOwnerSource(p, 0, source);
        Original.Bundle memory b;
        b.artistId = q.artistId;
        b.collectionId = q.collectionId;
        b.bindingHash = q.bindingHash;
        b.provenanceCommitment = RH.ownerProvenanceHash(p, 0);
        b.current = Binding(source).binding(q.collectionId);
        uint256 count = b.current.generation;
        if (count < 2 || count > 128) revert T.UnsupportedProfile();
        b.rows = new Original.Row[](count);
        corrected.corrections = new State.Correction[](count);
        for (uint256 i; i < count; ++i) {
            uint64 generation = uint64(i + 1);
            b.rows[i] = Original.Row(
                Binding(source).bindingAt(q.collectionId, generation),
                Terms(source).bindingTerms(q.collectionId, generation),
                Lifecycle(source).bindingTermination(q.collectionId, generation)
            );
            (corrected.corrections[i].approval, corrected.corrections[i].recordHash) =
                Corrections(source).bindingCorrection(b.rows[i].item.bindingHash);
        }
        corrected.bindings = b;
        Validation.validate(corrected, q, p);
    }

    /// @dev Internal preparation keeps its original nominal Bundle. Only owner0's authenticated
    /// semantic envelope carries additional approval rows; consent/ratification callers stay exact.
    function collectBindings(address source, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        view
        returns (Original.Bundle memory)
    {
        if (!selected(p)) return Modes.collect(source, q, p);
        return collect(source, q, p).bindings;
    }

    function encodeCollected(
        address source,
        bytes memory original,
        AH.Query memory q,
        RH.OwnerProvenance memory p
    ) public view returns (bytes memory) {
        CB.Bundle memory b = collect(source, q, p);
        if (keccak256(original) != keccak256(abi.encode(b.bindings))) _invalid();
        return abi.encode(CB.SCHEMA, RH.VERSION, b);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        pure
        returns (CB.Bundle memory b)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, b) = abi.decode(raw, (bytes32, uint16, CB.Bundle));
        if (
            tag != CB.SCHEMA || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, b))
        ) _invalid();
        Validation.validate(b, q, p);
    }

    function importIfSelected(
        mapping(uint256 => T.Binding) storage bindings,
        mapping(uint256 => mapping(uint64 => T.Binding)) storage history,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        mapping(uint256 => mapping(uint64 => L.Terminal)) storage terminals,
        mapping(bytes32 => State.Correction) storage corrections,
        AH.Query memory q,
        bytes memory outer
    ) public returns (bool) {
        (RH.ExportHeader memory h,) = Payload.decode(outer, 0);
        if ((h.requiredFeatures & RH.BINDING_CORRECTIONS) == 0) return false;
        importState(bindings, history, terms, terminals, corrections, q, outer);
        return true;
    }

    function importState(
        mapping(uint256 => T.Binding) storage bindings,
        mapping(uint256 => mapping(uint64 => T.Binding)) storage history,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        mapping(uint256 => mapping(uint64 => L.Terminal)) storage terminals,
        mapping(bytes32 => State.Correction) storage corrections,
        AH.Query memory q,
        bytes memory outer
    ) public {
        (RH.ExportHeader memory h, Payload.Payload memory p) = Payload.decode(outer, 0);
        if (
            (h.requiredFeatures & (RH.BINDING_GENERATIONS | RH.BINDING_CORRECTIONS))
                    != (RH.BINDING_GENERATIONS | RH.BINDING_CORRECTIONS) || p.nonces.length != 0
        ) _invalid();
        CB.Bundle memory b = decode(q, p.provenance, p.semanticState);
        if (b.bindings.current.consentMode == 2 && (h.requiredFeatures & RH.DELEGATED_CONSENT) == 0)
        {
            _invalid();
        }
        T.Binding memory emptyBinding;
        C.BindingTerms memory emptyTerms;
        L.Terminal memory emptyTerminal;
        State.Correction memory emptyCorrection;
        if (keccak256(abi.encode(bindings[q.collectionId])) != keccak256(abi.encode(emptyBinding)))
        {
            revert T.InvalidRecord();
        }
        for (uint256 i; i < b.bindings.rows.length; ++i) {
            uint64 generation = uint64(i + 1);
            bytes32 hash = b.bindings.rows[i].item.bindingHash;
            if (
                keccak256(abi.encode(history[q.collectionId][generation]))
                        != keccak256(abi.encode(emptyBinding))
                    || keccak256(abi.encode(terms[q.collectionId][generation]))
                        != keccak256(abi.encode(emptyTerms))
                    || keccak256(abi.encode(terminals[q.collectionId][generation]))
                        != keccak256(abi.encode(emptyTerminal))
                    || keccak256(abi.encode(corrections[hash]))
                        != keccak256(abi.encode(emptyCorrection))
            ) revert T.InvalidRecord();
        }
        bindings[q.collectionId] = b.bindings.current;
        for (uint256 i; i < b.bindings.rows.length; ++i) {
            uint64 generation = uint64(i + 1);
            history[q.collectionId][generation] = b.bindings.rows[i].item;
            terms[q.collectionId][generation] = b.bindings.rows[i].terms;
            terminals[q.collectionId][generation] = b.bindings.rows[i].terminal;
            if (b.corrections[i].recordHash != 0) {
                corrections[b.bindings.rows[i].item.bindingHash] = b.corrections[i];
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
