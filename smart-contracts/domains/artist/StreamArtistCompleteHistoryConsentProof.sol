// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistCompleteHistoryDecode as Decode
} from "./StreamArtistCompleteHistoryDecode.sol";
import {
    StreamArtistCompleteHistoryConsentSource as Source
} from "./StreamArtistCompleteHistoryConsentSource.sol";
import {
    StreamArtistCompleteHistoryConsentValidation as Validation
} from "./StreamArtistCompleteHistoryConsentValidation.sol";
import {
    StreamArtistCompleteHistorySanctionSource as SanctionSource
} from "./StreamArtistCompleteHistorySanctionSource.sol";
import {
    StreamArtistRecoveredAggregateSanctionLocalProof as SanctionProof
} from "./StreamArtistRecoveredAggregateSanctionLocalProof.sol";
import {
    StreamArtistRecoveredAggregateRatificationRows as Rows
} from "./StreamArtistRecoveredAggregateRatificationRows.sol";
import {
    StreamArtistAggregateConsentSupplementTypes as Supplement
} from "./StreamArtistAggregateConsentSupplementTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice One canonical owner6 family proof shared by the original base and supplement hooks.
/// @dev Full shared inventory is re-observed before any source row comparison. Identity signature
/// and grant conservation remain mandatory in the enclosing seven-owner proof.
library StreamArtistCompleteHistoryConsentProof {
    struct Result {
        M.State scope;
        CT.Inventory inventory;
        G.Consents[] original;
        T.RatificationRecord[][] ratifications;
        H.Inventory sanctions;
    }

    function collect(AH.Query memory anchor, bytes memory outer)
        public
        view
        returns (Result memory r)
    {
        (r.scope,, r.inventory,) = Decode.collect(6, anchor, outer);
        uint256 n = r.scope.collections.length;
        if (r.scope.rows.length != n || n == 0 || n > 128) _invalid();
        r.original = new G.Consents[](n);
        r.ratifications = new T.RatificationRecord[][](n);
        Source.Context memory source;
        source.scope = r.scope;
        source.inventory = r.inventory;
        source.source =
            r.inventory.provenance.origins[r.inventory.provenance.origins.length - 1].owners[6];
        source.economics = new T.EconomicsConsent[][](n);
        source.royalties = new T.RoyaltyFreeze[][](n);
        bytes memory sanctionInventory;
        for (uint256 k; k < n; ++k) {
            Supplement.Bundle memory row = Rows.decodeSupplement(r.scope.rows[k]);
            r.original[k] = row.original;
            r.ratifications[k] = row.ratifications;
            if (k == 0) sanctionInventory = row.sanctionInventory;
            else if (row.sanctionInventory.length != 0) _invalid();
            source.economics[k] =
                new T.EconomicsConsent[](row.original.rows.original.economics.length);
            for (uint256 i; i < source.economics[k].length; ++i) {
                source.economics[k][i] = row.original.rows.original.economics[i].item.terms;
            }
            source.royalties[k] = new T.RoyaltyFreeze[](row.original.rows.royalties.length);
            for (uint256 i; i < source.royalties[k].length; ++i) {
                source.royalties[k][i] = row.original.rows.royalties[i].terms;
            }
        }
        Validation.validate(r.original, r.ratifications, r.scope, r.inventory, sanctionInventory);
        Source.requireCurrent(source, r.scope.rows);
        // The complete original sanction catalogue is joined to CT's whole Archive, including
        // zero-native op13. Empty bytes are permitted only after both authentic histories agree.
        r.sanctions = SanctionSource.collect(r.scope, r.inventory);
        if (r.sanctions.sanctions.length == 0) {
            if (sanctionInventory.length != 0) _invalid();
        } else {
            if (keccak256(sanctionInventory) != keccak256(abi.encode(r.sanctions))) _invalid();
            SanctionProof.validate(
                RH.ownerProvenance(r.inventory.provenance, 6), 6, r.scope.collections, r.sanctions
            );
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
