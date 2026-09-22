// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredAggregateRatificationRows as Ratifications
} from "./StreamArtistRecoveredAggregateRatificationRows.sol";

import {
    StreamArtistRecoveredMultipleDisputeComposition as Composition
} from "./StreamArtistRecoveredMultipleDisputeComposition.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Records
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";

/// @notice Original aggregate row encoding and feature calculation after all conservation checks.
/// @dev This pure linked worker receives the complete already-validated rows. The
/// original Composition.Result nominal tuple and feature/encoding order are retained.

library StreamArtistRecoveredMultipleDisputeEncoding {
    struct Context {
        uint256 collectionCount;
        uint256 features;
        G.Inventory inventory;
        A.AcceptanceBundle[] accepted;
        G.Consents[] consents;
        bytes[] attestations;
        D.Bundle[] history;
    }

    function encode(Context memory c) public pure returns (Composition.Result memory result) {
        T.RatificationRecord[][] memory empty = new T.RatificationRecord[][](c.collectionCount);
        for (uint256 i; i < empty.length; ++i) {
            empty[i] = new T.RatificationRecord[](0);
        }
        return encodeRatified(c, empty);
    }

    function encodeRatified(Context memory c, T.RatificationRecord[][] memory ratifications)
        public
        pure
        returns (Composition.Result memory result)
    {
        if (ratifications.length != c.collectionCount) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        uint256 n = c.collectionCount;
        result.bindings = new bytes[](n);
        result.accepted = new bytes[](n);
        result.consents = new bytes[](n);
        result.attribution = new bytes[](n);
        result.features = c.features | MD.FEATURE | RH.DISPUTE_HISTORY;
        for (uint256 k; k < n; ++k) {
            if (c.inventory.generations[k].length > 1) result.features |= RH.BINDING_GENERATIONS;
            result.bindings[k] = abi.encode(c.inventory.bindings[k]);
            result.accepted[k] = abi.encode(c.accepted[k]);
            result.consents[k] = Ratifications.encode(c.consents[k], ratifications[k]);
            if (ratifications[k].length != 0) result.features |= RH.RATIFICATIONS;
            Records.Bundle memory records = abi.decode(c.attestations[k], (Records.Bundle));
            result.attribution[k] = abi.encode(MD.Attribution(c.history[k], records));
            if (records.records.length != 0) {
                result.features |= RH.ATTESTATIONS | RH.HISTORY_RECORDS;
            }
            if (c.history[k].resolutions.length + c.history[k].repudiations.length != 0) {
                result.features |= RH.ACCEPTED_GENERATIONS | RH.DISPUTE_HISTORY;
            }
            if (c.consents[k].rows.original.economics.length != 0) {
                result.features |= RH.DIRECT_ECONOMICS;
            }
            if (c.consents[k].rows.original.sales.length != 0) {
                result.features |= RH.DELEGATED_CONSENT;
            }
            if (
                c.consents[k].rows.consents.length + c.consents[k].rows.royalties.length
                        + c.consents[k].rows.freezes.length != 0
            ) result.features |= RH.CONTENT_CONSENTS | RH.HISTORY_CONTENT;
            for (uint256 g; g < c.inventory.bindings[k].corrections.length; ++g) {
                if (c.inventory.bindings[k].corrections[g].recordHash != 0) {
                    result.features |= RH.BINDING_CORRECTIONS;
                }
                if (c.consents[k].bindings[g].consentMode == 2) {
                    result.features |= RH.DELEGATED_CONSENT;
                }
            }
        }
        result.inventory = abi.encode(c.inventory);
        result.generations = abi.encode(c.inventory.generations);
    }
}
