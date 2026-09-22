// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredMultipleGenerationAttributionImport as GenerationAttribution } from "./StreamArtistRecoveredMultipleGenerationAttributionImport.sol";
import { StreamArtistRecoveredMultipleGenerationCollectionImport as Generations } from "./StreamArtistRecoveredMultipleGenerationCollectionImport.sol";
import { StreamArtistRecoveredMultipleAttestationCollectionImport as Attestations } from "./StreamArtistRecoveredMultipleAttestationCollectionImport.sol";
import { StreamArtistRecoveredMultipleConsentCollectionImport as Next } from "./StreamArtistRecoveredMultipleConsentCollectionImport.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredSimpleHydrationTypes as S
} from "../../interfaces/stream/artist/StreamArtistRecoveredSimpleHydrationTypes.sol";
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
    StreamArtistRecoveredMultipleCodec as Codec
} from "./StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as Rows
} from "./StreamArtistRecoveredMultipleCollectionRows.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredCollectionHydration as Original
} from "./StreamArtistRecoveredCollectionHydration.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";

/// @notice Fixed typed empty-key installation inside one original whole-owner operation60 apply.
library StreamArtistRecoveredMultipleCollectionImport {
    function bindings(
        mapping(uint256 => T.Binding) storage bindings_,
        mapping(uint256 => mapping(uint64 => T.Binding)) storage history,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        mapping(uint256 => mapping(uint64 => L.Terminal)) storage terminals,
        AH.Query memory anchor,
        bytes memory raw
    ) public returns (bool) {
        if (Attestations.bindings(bindings_, history, terms, terminals, anchor, raw)) return true;
        if (Next.bindings(bindings_, history, terms, terminals, anchor, raw)) return true;
        if (!Codec.selected(raw, 0)) return false;
        (M.State memory s, Payload.Payload memory p) = Codec.outer(0, anchor, raw);
        Rows.validate(0, s, p.provenance);
        T.Binding memory empty;
        C.BindingTerms memory emptyTerms;
        L.Terminal memory emptyTerminal;
        for (uint256 i; i < s.rows.length; ++i) {
            uint256 id = s.collections[i].collectionId;
            if (
                keccak256(abi.encode(bindings_[id])) != keccak256(abi.encode(empty))
                    || keccak256(abi.encode(history[id][1])) != keccak256(abi.encode(empty))
                    || keccak256(abi.encode(terms[id][1])) != keccak256(abi.encode(emptyTerms))
                    || keccak256(abi.encode(terminals[id][1]))
                        != keccak256(abi.encode(emptyTerminal))
            ) _invalid();
        }
        for (uint256 i; i < s.rows.length; ++i) {
            uint256 id = s.collections[i].collectionId;
            S.Binding memory b = abi.decode(s.rows[i], (S.Binding));
            bindings_[id] = b.item;
            history[id][1] = b.history;
            terms[id][1] = b.terms;
            terminals[id][1] = b.terminal;
        }
        return true;
    }

    function acceptances(
        mapping(bytes32 => bytes32) storage records,
        mapping(bytes32 => uint64) storage times,
        AH.Query memory anchor,
        bytes memory raw
    ) public returns (bool) {
        if (Generations.acceptances(records, times, anchor, raw)) return true;
        if (Attestations.acceptances(records, times, anchor, raw)) return true;
        if (Next.acceptances(records, times, anchor, raw)) return true;
        if (!Codec.selected(raw, 3)) return false;
        (M.State memory s, Payload.Payload memory p) = Codec.outer(3, anchor, raw);
        Rows.validate(3, s, p.provenance);
        for (uint256 i; i < s.rows.length; ++i) {
            if (
                records[s.collections[i].bindingHash] != 0
                    || times[s.collections[i].bindingHash] != 0
            ) _invalid();
        }
        for (uint256 i; i < s.rows.length; ++i) {
            S.Acceptance memory b = abi.decode(s.rows[i], (S.Acceptance));
            records[s.collections[i].bindingHash] = b.record;
            times[s.collections[i].bindingHash] = b.acceptedAt;
        }
        return true;
    }

    function collaborator(AH.Query memory anchor, bytes memory raw) public pure returns (bool) {
        if (Generations.collaborator(anchor, raw)) return true;
        if (Attestations.collaborator(anchor, raw)) return true;
        if (Next.collaborator(anchor, raw)) return true;
        if (!Codec.selected(raw, 1)) return false;
        (M.State memory s, Payload.Payload memory p) = Codec.outer(1, anchor, raw);
        Rows.validate(1, s, p.provenance);
        return true;
    }

    function attribution(AS.State storage state, AH.Query memory anchor, bytes memory raw)
        public
        returns (bool)
    {
        if (GenerationAttribution.applyState(state, anchor, raw)) return true;
        if (Attestations.attribution(state, anchor, raw)) return true;
        if (Next.attribution(state, anchor, raw)) return true;
        if (!Codec.selected(raw, 4)) return false;
        (M.State memory s, Payload.Payload memory p) = Codec.outer(4, anchor, raw);
        Rows.validate(4, s, p.provenance);
        for (uint256 i; i < s.rows.length; ++i) {
            AS.Attribution memory current = state.attributions[s.collections[i].collectionId];
            if (current.state != 0 || current.generation != 0) _invalid();
        }
        for (uint256 i; i < s.rows.length; ++i) {
            Rows.AttributionRow memory b = abi.decode(s.rows[i], (Rows.AttributionRow));
            state.attributions[s.collections[i].collectionId] = b.state.item;
        }
        return true;
    }

    function policies(
        mapping(bytes32 => bytes32) storage policies_,
        mapping(bytes32 => bytes32) storage delegations,
        AH.Query memory anchor,
        bytes memory raw
    ) public returns (bool) {
        if (!Codec.selected(raw, 6)) return false;
        (M.State memory s, Payload.Payload memory p) = Codec.outer(6, anchor, raw);
        Rows.validate(6, s, p.provenance);
        for (uint256 i; i < s.rows.length; ++i) {
            Original.PolicyBundle memory b = abi.decode(s.rows[i], (Original.PolicyBundle));
            for (uint256 j; j < b.records.length; ++j) {
                if (
                    policies_[_scope(b.collectionId, b.policies[j])] != 0
                        || delegations[b.records[j]] != 0
                ) _invalid();
            }
        }
        for (uint256 i; i < s.rows.length; ++i) {
            Original.PolicyBundle memory b = abi.decode(s.rows[i], (Original.PolicyBundle));
            for (uint256 j; j < b.records.length; ++j) {
                policies_[_scope(b.collectionId, b.policies[j])] = b.records[j];
            }
        }
        return true;
    }

    function _scope(uint256 id, AH.PolicyKey memory key) private pure returns (bytes32) {
        return keccak256(abi.encode(id, key.phaseId, key.policyHash));
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
