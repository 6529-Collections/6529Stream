// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationCodec as Codec
} from "./StreamArtistRecoveredMultipleGenerationCodec.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationRevocations as Revocations
} from "./StreamArtistRecoveredMultipleGenerationRevocations.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationValidation as Attestations
} from "./StreamArtistRecoveredMultipleGenerationAttestationValidation.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredPlatformCatalogue as Catalogue
} from "./StreamArtistRecoveredPlatformCatalogue.sol";
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

/// @notice Post-write revalidation of the complete generation envelope and all seven original Archive cutoffs.
library StreamArtistRecoveredMultipleGenerationCurrent {
    function requireCurrent(RH.Provenance memory full, AH.Query memory anchor, bytes memory outer)
        public
        view
    {
        (M.State memory scope, Payload.Payload memory p) = Codec.outer(4, anchor, outer);
        if (
            keccak256(abi.encode(p.provenance))
                != keccak256(abi.encode(RH.ownerProvenance(full, 4)))
        ) _invalid();
        (, bytes memory raw) = Codec.decodeAuxiliary(4, p.semanticState, p.provenance);
        G.Inventory memory inventory = abi.decode(raw, (G.Inventory));
        if (keccak256(raw) != keccak256(abi.encode(inventory))) _invalid();
        A.AttributionBundle[] memory history = new A.AttributionBundle[](scope.rows.length);
        for (uint256 k; k < history.length; ++k) {
            G.Attribution memory row = abi.decode(scope.rows[k], (G.Attribution));
            if (keccak256(scope.rows[k]) != keccak256(abi.encode(row))) _invalid();
            history[k] = row.history;
            scope.rows[k] = abi.encode(row.records);
        }
        Clocks.Result memory clocks = Clocks.validateLocal(scope, p.provenance, inventory);
        Revocations.validate(history, scope, p.provenance, inventory, clocks);
        Attestations.validate(scope, p.provenance, inventory, clocks);
        Catalogue.requireCurrent(full, inventory.catalogues, inventory.operations);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
