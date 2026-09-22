// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAggregateRatificationSource as Ratifications
} from "./StreamArtistRecoveredAggregateRatificationSource.sol";
import {
    StreamArtistRecoveredMultipleGenerationEncoding as Encoding
} from "./StreamArtistRecoveredMultipleGenerationEncoding.sol";
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
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Records
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredMultipleGenerationBindingSource as Bindings
} from "./StreamArtistRecoveredMultipleGenerationBindingSource.sol";
import {
    StreamArtistRecoveredMultipleGenerationBindingProof as BindingProof
} from "./StreamArtistRecoveredMultipleGenerationBindingProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationAcceptance as Acceptance
} from "./StreamArtistRecoveredMultipleGenerationAcceptance.sol";
import {
    StreamArtistRecoveredMultipleGenerationRevocations as Revocations
} from "./StreamArtistRecoveredMultipleGenerationRevocations.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentSource as Reads
} from "./StreamArtistRecoveredMultipleGenerationConsentSource.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentValidation as Validation
} from "./StreamArtistRecoveredMultipleGenerationConsentValidation.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationQueries as Queries
} from "./StreamArtistRecoveredMultipleGenerationAttestationQueries.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationSource as Attestations
} from "./StreamArtistRecoveredMultipleGenerationAttestationSource.sol";
import {
    StreamArtistRecoveredMultipleGenerationIdentityFacts as IdentityFacts
} from "./StreamArtistRecoveredMultipleGenerationIdentityFacts.sol";
import {
    StreamArtistRecoveredMultipleGenerationConservation as Conservation
} from "./StreamArtistRecoveredMultipleGenerationConservation.sol";

import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";

/// @notice Original complete consent-row collection, global owner6 proof and current heads.
/// @dev Preserves the full provenance and the original read/validation order inside this phase.
library StreamArtistRecoveredMultipleGenerationConsentCollection {
    struct Context {
        address source;
        RH.Provenance provenance;
        M.State scope;
        T.EconomicsConsent[][] economics;
        T.RoyaltyFreeze[][] freezes;
    }

    function collect(Context memory c, CB.Bundle[] memory bindings)
        public
        view
        returns (G.Consents[] memory rows)
    {
        T.RatificationRecord[][] memory empty =
            new T.RatificationRecord[][](c.scope.collections.length);
        for (uint256 i; i < empty.length; ++i) {
            empty[i] = new T.RatificationRecord[](0);
        }
        return _collect(c, bindings, empty, false);
    }

    function collectRatified(Context memory c, CB.Bundle[] memory bindings)
        public
        view
        returns (G.Consents[] memory rows, T.RatificationRecord[][] memory ratifications)
    {
        RH.OwnerProvenance memory p = RH.ownerProvenance(c.provenance, 6);
        bool required;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.operation == 52) required = true;
        }
        // Keep the original no52 collector and its error order unchanged.
        if (!required) {
            rows = collect(c, bindings);
            ratifications = new T.RatificationRecord[][](rows.length);
            for (uint256 i; i < rows.length; ++i) {
                ratifications[i] = new T.RatificationRecord[](0);
            }
            return (rows, ratifications);
        }
        ratifications = Ratifications.collect(c.source, c.scope.collections, p);
        rows = _collect(c, bindings, ratifications, true);
    }

    function _collect(
        Context memory c,
        CB.Bundle[] memory bindings,
        T.RatificationRecord[][] memory ratifications,
        bool allowRatifications
    ) private view returns (G.Consents[] memory rows) {
        uint256 n = c.scope.collections.length;
        rows = new G.Consents[](n);
        if (c.economics.length != n || c.freezes.length != n) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        for (uint256 k; k < n; ++k) {
            uint256 count = bindings[k].bindings.rows.length;
            rows[k].bindings = new T.Binding[](count);
            for (uint256 g; g < count; ++g) {
                rows[k].bindings[g] = bindings[k].bindings.rows[g].item;
            }
            if (allowRatifications) {
                rows[k].rows = Reads.collectRatifiedRows(
                    c.source,
                    c.scope.collections[k],
                    RH.ownerProvenance(c.provenance, 6),
                    c.economics[k],
                    c.freezes[k],
                    rows[k].bindings
                );
            } else {
                rows[k].rows = Reads.collectRows(
                    c.source,
                    c.scope.collections[k],
                    RH.ownerProvenance(c.provenance, 6),
                    c.economics[k],
                    c.freezes[k],
                    rows[k].bindings
                );
            }
        }
        if (allowRatifications) {
            Validation.validate(
                rows, ratifications, c.scope.collections, RH.ownerProvenance(c.provenance, 6)
            );
        } else {
            Validation.validate(rows, c.scope.collections, RH.ownerProvenance(c.provenance, 6));
        }
        for (uint256 k; k < n; ++k) {
            Reads.requireHeads(c.source, rows[k].rows);
        }
    }
}
