// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationCodec as Codec
} from "./StreamArtistRecoveredMultipleGenerationCodec.sol";
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

/// @notice Complete original owner0 decoding and proof before any Binding target-map check.
/// @dev Returns only the already-authenticated binding rows; full Archive/provenance validation
/// remains here in its original order and no calldata field is bypassed.
library StreamArtistRecoveredMultipleGenerationBindingDecode {
    struct Context {
        M.State scope;
        Payload.Payload payload;
        G.Inventory inventory;
    }

    function collect(AH.Query memory anchor, bytes memory outer)
        public
        view
        returns (CB.Bundle[] memory)
    {
        Context memory c;
        (c.scope, c.payload) = Codec.outer(0, anchor, outer);
        (, bytes memory raw) =
            Codec.decodeAuxiliary(0, c.payload.semanticState, c.payload.provenance);
        c.inventory = abi.decode(raw, (G.Inventory));
        if (
            keccak256(raw) != keccak256(abi.encode(c.inventory))
                || c.scope.rows.length != c.inventory.bindings.length
        ) _invalid();
        for (uint256 k; k < c.scope.rows.length; ++k) {
            if (keccak256(c.scope.rows[k]) != keccak256(abi.encode(c.inventory.bindings[k]))) {
                _invalid();
            }
        }
        Proof.validate(c.scope, c.payload.provenance, c.inventory);
        return c.inventory.bindings;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
