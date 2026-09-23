// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredSimpleHydrationTypes as S
} from "../../interfaces/stream/artist/StreamArtistRecoveredSimpleHydrationTypes.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredMultipleConsentGrantRows as Grants
} from "./StreamArtistRecoveredMultipleConsentGrantRows.sol";
import {
    StreamArtistRecoveredMultipleConsentContentRows as Content
} from "./StreamArtistRecoveredMultipleConsentContentRows.sol";

import {
    StreamArtistRecoveredMultipleAttestationConsentUses as Consents
} from "./StreamArtistRecoveredMultipleAttestationConsentUses.sol";
import {
    StreamArtistRecoveredMultipleAttestationFacts as Attestations
} from "./StreamArtistRecoveredMultipleAttestationFacts.sol";
import {
    StreamArtistRecoveredMultipleAttestationQueries as Queries
} from "./StreamArtistRecoveredMultipleAttestationQueries.sol";

/// @notice One final conservation equality per retained grant version across all selected families.
library StreamArtistRecoveredMultipleAttestationConservation {
    function validate(
        bytes[] calldata identities,
        M.State calldata scope,
        ContentH.Bundle[] calldata consents,
        bytes[] calldata bindings,
        bytes[] calldata attestations,
        RH.Provenance calldata p
    ) public pure {
        uint256[][] memory before_ = Consents.validate(
            Consents.Context(identities, scope, consents, bindings, p)
        );
        uint256[][] memory after_ = Attestations.validate(
            identities, Queries.project(scope, RH.ownerProvenance(p, 4)), attestations, p
        );
        if (before_.length != identities.length || after_.length != identities.length) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        for (uint256 a; a < identities.length; ++a) {
            IH.Bundle calldata b = Frame.bundle(identities[a]);
            if (
                before_[a].length != b.delegations.length
                    || after_[a].length != b.delegations.length
            ) {
                revert RH.InvalidRecoveredHydrationProfile();
            }
            for (uint256 g; g < b.delegations.length; ++g) {
                if (before_[a][g] + after_[a][g] != b.delegations[g].record.uses) {
                    revert RH.InvalidRecoveredHydrationProfile();
                }
            }
        }
    }
}
