// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleDisputeAttributionProof as Proof
} from "./StreamArtistRecoveredMultipleDisputeAttributionProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";

/// @notice Canonical owner4 inventory check and full dispute attribution proof.
library StreamArtistRecoveredMultipleDisputeAttributionValidation {
    function validate(M.State memory scope, RH.OwnerProvenance memory provenance, bytes calldata raw)
        public
        view
        returns (Proof.Result memory proof)
    {
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        if (keccak256(raw) != keccak256(abi.encode(inventory))) _invalid();
        proof = Proof.validate(scope, provenance, inventory);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
