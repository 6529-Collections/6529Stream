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

/// @notice One equality over every original grant version after all collections and generations.
library StreamArtistRecoveredMultipleGenerationConservation {
    struct Context {
        bytes[] identities;
        M.State scope;
        G.Consents[] consents;
        bytes[] attestations;
        G.Inventory inventory;
        RH.Provenance provenance;
    }

    function validate(Context calldata x) public pure {
        uint256[][] memory consent =
            Consents.validate(Consents.Context(x.identities, x.scope, x.consents, x.provenance));
        uint256[][] memory attested = Attestations.validate(
            Attestations.Context(
                x.identities,
                Queries.project(x.scope, RH.ownerProvenance(x.provenance, 4)),
                x.attestations,
                x.inventory,
                x.provenance
            )
        );
        if (consent.length != x.identities.length || attested.length != x.identities.length) {
            _invalid();
        }
        for (uint256 a; a < x.identities.length; ++a) {
            IH.Bundle calldata b = Frame.bundle(x.identities[a]);
            if (
                consent[a].length != b.delegations.length
                    || attested[a].length != b.delegations.length
            ) _invalid();
            for (uint256 g; g < b.delegations.length; ++g) {
                if (consent[a][g] + attested[a][g] != b.delegations[g].record.uses) _invalid();
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
