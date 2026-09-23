// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredMultipleDisputeBindingDecode as Decode
} from "./StreamArtistRecoveredMultipleDisputeBindingDecode.sol";
import {
    StreamArtistRecoveredMultipleDisputeCodec as Codec
} from "./StreamArtistRecoveredMultipleDisputeCodec.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import { StreamArtistBindingCorrectionState as CS } from "./StreamArtistBindingCorrectionState.sol";
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

/// @notice One original Binding owner apply; every original map is checked before any selected collection is written.
library StreamArtistRecoveredMultipleDisputeBindingImport {
    struct Context {
        CB.Bundle[] rows;
        T.Binding emptyBinding;
        C.BindingTerms emptyTerms;
        L.Terminal emptyTerminal;
        CS.Correction emptyCorrection;
    }

    function applyState(
        mapping(uint256 => T.Binding) storage bindings,
        mapping(uint256 => mapping(uint64 => T.Binding)) storage history,
        mapping(uint256 => mapping(uint64 => C.BindingTerms)) storage terms,
        mapping(uint256 => mapping(uint64 => L.Terminal)) storage terminals,
        mapping(bytes32 => CS.Correction) storage corrections,
        AH.Query memory anchor,
        bytes memory outer
    ) public returns (bool) {
        if (!Codec.selected(outer, 0)) return false;
        Context memory c;
        c.rows = Decode.collect(anchor, outer);
        for (uint256 k; k < c.rows.length; ++k) {
            uint256 id = c.rows[k].bindings.collectionId;
            CB.Bundle memory b = c.rows[k];
            if (keccak256(abi.encode(bindings[id])) != keccak256(abi.encode(c.emptyBinding))) {
                _invalid();
            }
            for (uint256 i; i < b.bindings.rows.length; ++i) {
                uint64 g = uint64(i + 1);
                bytes32 hash = b.bindings.rows[i].item.bindingHash;
                if (
                    keccak256(abi.encode(history[id][g])) != keccak256(abi.encode(c.emptyBinding))
                        || keccak256(abi.encode(terms[id][g]))
                            != keccak256(abi.encode(c.emptyTerms))
                        || keccak256(abi.encode(terminals[id][g]))
                            != keccak256(abi.encode(c.emptyTerminal))
                        || keccak256(abi.encode(corrections[hash]))
                            != keccak256(abi.encode(c.emptyCorrection))
                ) _invalid();
            }
        }
        for (uint256 k; k < c.rows.length; ++k) {
            uint256 id = c.rows[k].bindings.collectionId;
            CB.Bundle memory b = c.rows[k];
            bindings[id] = b.bindings.current;
            for (uint256 i; i < b.bindings.rows.length; ++i) {
                uint64 g = uint64(i + 1);
                history[id][g] = b.bindings.rows[i].item;
                terms[id][g] = b.bindings.rows[i].terms;
                terminals[id][g] = b.bindings.rows[i].terminal;
                if (b.corrections[i].recordHash != 0) {
                    corrections[b.bindings.rows[i].item.bindingHash] = b.corrections[i];
                }
            }
        }
        return true;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
