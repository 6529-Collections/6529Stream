// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredAggregateSanctionAttributionTransport as SanctionTransport
} from "./StreamArtistRecoveredAggregateSanctionAttributionTransport.sol";
import {
    StreamArtistRecoveredAggregateSanctionLocalProof as SanctionLocal
} from "./StreamArtistRecoveredAggregateSanctionLocalProof.sol";

/// @notice The original sanction envelope is checked before owner4 row validation.
library StreamArtistRecoveredMultipleGenerationAttributionSanctions {
    function validate(M.State memory scope, RH.OwnerProvenance memory provenance)
        public
        view
        returns (M.State memory stripped, H.ConfirmationRow[] memory confirmations, bool sanctioned)
    {
        H.Inventory memory sanctions;
        (stripped, sanctions) = SanctionTransport.decode(scope);
        sanctioned = sanctions.sanctions.length != 0;
        if (sanctioned) {
            SanctionLocal.validate(provenance, 4, stripped.collections, sanctions);
        }
        confirmations = sanctions.confirmations;
    }
}
