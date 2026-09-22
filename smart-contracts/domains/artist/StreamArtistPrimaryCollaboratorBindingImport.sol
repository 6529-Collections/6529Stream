// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorDecode as Decode
} from "./StreamArtistPrimaryCollaboratorDecode.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorCodec as Codec
} from "./StreamArtistPrimaryCollaboratorCodec.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationBindingProof as Proof
} from "./StreamArtistRecoveredMultipleGenerationBindingProof.sol";
import { StreamArtistBindingCorrectionState as CS } from "./StreamArtistBindingCorrectionState.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
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
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";

/// @notice One original Binding owner apply; every original map is checked before any selected collection is written.
library StreamArtistPrimaryCollaboratorBindingImport {
    struct Context {
        CB.Bundle[] rows;
        PC.Proof proof;
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
        mapping(uint256 => mapping(uint64 => T.CollaboratorRecord[])) storage collaborators,
        AH.Query memory anchor,
        bytes memory outer
    ) public returns (bool) {
        if (!Codec.selected(outer, 0)) return false;
        Context memory c;
        (M.State memory scope,, PC.Proof memory proof) = Decode.collect(0, anchor, outer);
        c.proof = proof;
        c.rows = proof.bindings.bindings;
        if (scope.rows.length != c.rows.length) _invalid();
        for (uint256 k; k < c.rows.length; ++k) {
            if (keccak256(scope.rows[k]) != keccak256(abi.encode(c.rows[k]))) _invalid();
        }
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
                    collaborators[id][g].length != 0
                        || keccak256(abi.encode(history[id][g]))
                            != keccak256(abi.encode(c.emptyBinding))
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
                for (uint256 j; j < c.proof.bindings.collaborators[k][i].length; ++j) {
                    collaborators[id][g].push(c.proof.bindings.collaborators[k][i][j]);
                }
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
