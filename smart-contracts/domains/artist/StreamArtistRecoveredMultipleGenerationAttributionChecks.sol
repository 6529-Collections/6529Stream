// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationRevocations as Revocations
} from "./StreamArtistRecoveredMultipleGenerationRevocations.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationValidation as Validation
} from "./StreamArtistRecoveredMultipleGenerationAttestationValidation.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";

/// @notice Clock, revocation, then attestation checks on the original owner4 rows.
library StreamArtistRecoveredMultipleGenerationAttributionChecks {
    struct Context {
        A.AttributionBundle[] histories;
        M.State scope;
        RH.OwnerProvenance provenance;
        G.Inventory inventory;
        M.State attested;
        H.ConfirmationRow[] confirmations;
        bool sanctioned;
    }

    function validate(Context memory c) public view returns (Original.Bundle[] memory all) {
        Clocks.Result memory clocks = Clocks.validateLocal(c.scope, c.provenance, c.inventory);
        Revocations.validate(
            c.histories, c.scope, c.provenance, c.inventory, clocks, c.confirmations
        );
        all = Validation.validate(
            c.attested, c.provenance, c.inventory, clocks, c.sanctioned
        );
    }
}
