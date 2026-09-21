// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
    StreamArtistRecoveredMultipleConsentCodec as Codec
} from "./StreamArtistRecoveredMultipleConsentCodec.sol";
import {
    StreamArtistRecoveredMultipleConsentCollectionRows as Rows
} from "./StreamArtistRecoveredMultipleConsentCollectionRows.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredCollectionHydration as Original
} from "./StreamArtistRecoveredCollectionHydration.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";

/// @notice Fixed typed empty-key installation inside one original whole-owner operation60 apply.
library StreamArtistRecoveredMultipleConsentCollectionImport {
    function bindings(
        mapping(uint256 => T.Binding) storage bindings_,
        mapping(uint256 => mapping(uint64 => T.Binding)) storage history,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        mapping(uint256 => mapping(uint64 => L.Terminal)) storage terminals,
        AH.Query memory anchor,
        bytes memory raw
    ) public returns (bool) {
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
        if (!Codec.selected(raw, 1)) return false;
        (M.State memory s, Payload.Payload memory p) = Codec.outer(1, anchor, raw);
        Rows.validate(1, s, p.provenance);
        return true;
    }

    function attribution(AS.State storage state, AH.Query memory anchor, bytes memory raw)
        public
        returns (bool)
    {
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

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
