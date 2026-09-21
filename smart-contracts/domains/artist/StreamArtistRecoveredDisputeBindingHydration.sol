// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredDisputeHistoryTypes as A
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeBindingValidation as V
} from "./StreamArtistRecoveredDisputeBindingValidation.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import { StreamArtistBindingCorrectionState as CS } from "./StreamArtistBindingCorrectionState.sol";
import {
    IStreamArtistBindingCorrectionOwner as Correction
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    IStreamArtistBindingLifecycle as Lifecycle
} from "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

/// @notice Fixed-owner complete accepted generation export/import under original guarded op60.
library StreamArtistRecoveredDisputeBindingHydration {
    function collect(address source, AH.Query memory q, RH.OwnerProvenance memory p)
        public
        view
        returns (CB.Bundle memory b)
    {
        P.validateOwnerSource(p, 0, source);
        b.bindings.artistId = q.artistId;
        b.bindings.collectionId = q.collectionId;
        b.bindings.bindingHash = q.bindingHash;
        b.bindings.provenanceCommitment = RH.ownerProvenanceHash(p, 0);
        b.bindings.current = Binding(source).binding(q.collectionId);
        uint256 n = b.bindings.current.generation;
        if (n == 0 || n > 128) revert T.UnsupportedProfile();
        b.bindings.rows = new G.Row[](n);
        b.corrections = new CS.Correction[](n);
        for (uint256 i; i < n; ++i) {
            b.bindings.rows[i] = G.Row(
                Binding(source).bindingAt(q.collectionId, uint64(i + 1)),
                Terms(source).bindingTerms(q.collectionId, uint64(i + 1)),
                Lifecycle(source).bindingTermination(q.collectionId, uint64(i + 1))
            );
            (b.corrections[i].approval, b.corrections[i].recordHash) =
                Correction(source).bindingCorrection(b.bindings.rows[i].item.bindingHash);
        }
        V.validate(b, q, p);
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
            tag != A.BINDING || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, b))
        ) revert RH.InvalidRecoveredHydrationProfile();
        V.validate(b, q, p);
    }

    function encodeCollected(
        address source,
        bytes memory original,
        AH.Query memory q,
        RH.OwnerProvenance memory p
    ) public view returns (bytes memory) {
        CB.Bundle memory b = collect(source, q, p);
        if (keccak256(original) != keccak256(abi.encode(b.bindings))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        return abi.encode(A.BINDING, RH.VERSION, b);
    }

    function importIfSelected(
        mapping(uint256 => T.Binding) storage bindings,
        mapping(uint256 => mapping(uint64 => T.Binding)) storage history,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        mapping(uint256 => mapping(uint64 => L.Terminal)) storage terminals,
        mapping(bytes32 => CS.Correction) storage corrections,
        AH.Query memory q,
        bytes memory outer
    ) public returns (bool) {
        (RH.ExportHeader memory h, Payload.Payload memory p) = Payload.decode(outer, 0);
        if ((h.requiredFeatures & RH.DISPUTE_HISTORY) == 0) return false;
        if (p.nonces.length != 0) revert RH.InvalidRecoveredHydrationProfile();
        CB.Bundle memory b = decode(q, p.provenance, p.semanticState);
        if (b.bindings.current.consentMode == 2 && (h.requiredFeatures & RH.DELEGATED_CONSENT) == 0)
        {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        T.Binding memory emptyBinding;
        C.BindingTerms memory emptyTerms;
        L.Terminal memory emptyTerminal;
        CS.Correction memory emptyCorrection;
        if (keccak256(abi.encode(bindings[q.collectionId])) != keccak256(abi.encode(emptyBinding)))
        {
            revert T.InvalidRecord();
        }
        for (uint256 i; i < b.bindings.rows.length; ++i) {
            uint64 g = uint64(i + 1);
            bytes32 hash = b.bindings.rows[i].item.bindingHash;
            if (
                keccak256(abi.encode(history[q.collectionId][g]))
                        != keccak256(abi.encode(emptyBinding))
                    || keccak256(abi.encode(terms[q.collectionId][g]))
                        != keccak256(abi.encode(emptyTerms))
                    || keccak256(abi.encode(terminals[q.collectionId][g]))
                        != keccak256(abi.encode(emptyTerminal))
                    || keccak256(abi.encode(corrections[hash]))
                        != keccak256(abi.encode(emptyCorrection))
            ) revert T.InvalidRecord();
        }
        bindings[q.collectionId] = b.bindings.current;
        for (uint256 i; i < b.bindings.rows.length; ++i) {
            uint64 g = uint64(i + 1);
            history[q.collectionId][g] = b.bindings.rows[i].item;
            terms[q.collectionId][g] = b.bindings.rows[i].terms;
            terminals[q.collectionId][g] = b.bindings.rows[i].terminal;
            if (b.corrections[i].recordHash != 0) {
                corrections[b.bindings.rows[i].item.bindingHash] = b.corrections[i];
            }
        }
        return true;
    }
}
