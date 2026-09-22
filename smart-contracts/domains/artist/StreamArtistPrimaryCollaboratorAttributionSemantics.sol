// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
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
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";

import {
    StreamArtistPrimaryCollaboratorAttributionRows as Rows
} from "./StreamArtistPrimaryCollaboratorAttributionRows.sol";
import {
    StreamArtistPrimaryCollaboratorCurrentClocks as CurrentClocks
} from "./StreamArtistPrimaryCollaboratorCurrentClocks.sol";

/// @notice Original revocation and attestation checks after complete current-source equality.
library StreamArtistPrimaryCollaboratorAttributionSemantics {
    struct Context {
        M.State scope;
        RH.OwnerProvenance provenance;
        G.Inventory generations;
        Clocks.Result clocks;
        A.AttributionBundle[] histories;
        bytes[] rows;
        H.Inventory sanctions;
    }

    function validate(Context calldata x) public pure returns (Original.Bundle[] memory) {
        M.State memory attested = M.State(x.scope.artists, x.scope.collections, x.rows);
        Revocations.validate(
            x.histories, x.scope, x.provenance, x.generations, x.clocks, x.sanctions.confirmations
        );
        return Validation.validate(
            attested, x.provenance, x.generations, x.clocks, x.sanctions.sanctions.length != 0
        );
    }
}
