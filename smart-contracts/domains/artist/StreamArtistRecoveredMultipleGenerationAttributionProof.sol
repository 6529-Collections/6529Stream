// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";

import {
    StreamArtistRecoveredAggregateSanctionAttributionTransport as SanctionTransport
} from "./StreamArtistRecoveredAggregateSanctionAttributionTransport.sol";

import {
    StreamArtistRecoveredAggregateSanctionLocalProof as SanctionLocal
} from "./StreamArtistRecoveredAggregateSanctionLocalProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttributionRows as Rows
} from "./StreamArtistRecoveredMultipleGenerationAttributionRows.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttributionChecks as Checks
} from "./StreamArtistRecoveredMultipleGenerationAttributionChecks.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttributionSanctions as Sanctions
} from "./StreamArtistRecoveredMultipleGenerationAttributionSanctions.sol";

/// @notice Complete canonical owner4 rows, original clocks, revocations and attestations.
/// @dev Keeps the original semantic rows for clock/revocation validation and a fresh
/// attestation row view. Neither validation consumes or alters the original row bytes.
library StreamArtistRecoveredMultipleGenerationAttributionProof {
    error InvalidRecoveredHydrationProfile();

    struct Result {
        A.AttributionBundle[] histories;
        Original.Bundle[] all;
    }

    function validate(
        M.State memory scope,
        RH.OwnerProvenance memory provenance,
        G.Inventory memory inventory
    ) public view returns (Result memory result) {
        H.ConfirmationRow[] memory confirmations;
        bool sanctioned;
        (scope, confirmations, sanctioned) = Sanctions.validate(scope, provenance);
        result.histories = new A.AttributionBundle[](scope.rows.length);
        M.State memory attested =
            M.State(scope.artists, scope.collections, new bytes[](scope.rows.length));
        for (uint256 k; k < scope.rows.length; ++k) {
            (bytes memory history, bytes memory records) = Rows.validateRow(scope.rows[k]);
            result.histories[k] = abi.decode(history, (A.AttributionBundle));
            attested.rows[k] = records;
        }
        result.all = Checks.validate(
            Checks.Context(
                result.histories,
                scope,
                provenance,
                inventory,
                attested,
                confirmations,
                sanctioned
            )
        );
    }

    /// @dev Same complete proof with no unused external return-data decoding at the final currentness call.
    function requireValid(
        M.State memory scope,
        RH.OwnerProvenance memory provenance,
        G.Inventory memory inventory
    ) public view {
        validate(scope, provenance, inventory);
    }

}
