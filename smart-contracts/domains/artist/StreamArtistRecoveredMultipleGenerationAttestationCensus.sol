// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentUses as Consents
} from "./StreamArtistRecoveredMultipleGenerationConsentUses.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationUses as Attestations
} from "./StreamArtistRecoveredMultipleGenerationAttestationUses.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationQueries as Queries
} from "./StreamArtistRecoveredMultipleGenerationAttestationQueries.sol";

/// @notice Fixed attestation-use census over the complete original provenance.
library StreamArtistRecoveredMultipleGenerationAttestationCensus {
    struct Context {
        bytes[] identities;
        M.State scope;
        bytes[] attestations;
        G.Inventory inventory;
        RH.Provenance provenance;
    }

    function validate(Context memory x) public pure returns (uint256[][] memory) {
        return Attestations.validate(
            Attestations.Context(
                x.identities,
                Queries.project(x.scope, RH.ownerProvenance(x.provenance, 4)),
                x.attestations,
                x.inventory,
                x.provenance
            )
        );
    }
}
