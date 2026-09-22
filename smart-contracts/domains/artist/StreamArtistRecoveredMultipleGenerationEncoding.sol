// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleGenerationComposition as Composition
} from "./StreamArtistRecoveredMultipleGenerationComposition.sol";
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

/// @notice Original aggregate row encoding and feature calculation after all conservation checks.
/// @dev This pure linked worker receives the complete already-validated rows. The
/// original Composition.Result nominal tuple and feature/encoding order are retained.
library StreamArtistRecoveredMultipleGenerationEncoding {
    struct Context {
        uint256 collectionCount;
        uint256 features;
        G.Inventory inventory;
        A.AcceptanceBundle[] accepted;
        G.Consents[] consents;
        bytes[] attestations;
        A.AttributionBundle[] history;
    }

    function encode(Context memory c) public pure returns (Composition.Result memory result) {
        uint256 n = c.collectionCount;
        result.bindings = new bytes[](n);
        result.accepted = new bytes[](n);
        result.consents = new bytes[](n);
        result.attribution = new bytes[](n);
        result.features = c.features | G.FEATURE | RH.BINDING_GENERATIONS;
        for (uint256 k; k < n; ++k) {
            result.bindings[k] = abi.encode(c.inventory.bindings[k]);
            result.accepted[k] = abi.encode(c.accepted[k]);
            result.consents[k] = abi.encode(c.consents[k]);
            Records.Bundle memory records = abi.decode(c.attestations[k], (Records.Bundle));
            result.attribution[k] = abi.encode(G.Attribution(c.history[k], records));
            if (records.records.length != 0) {
                result.features |= RH.ATTESTATIONS | RH.HISTORY_RECORDS;
            }
            if (c.history[k].revocations.length != 0) {
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
