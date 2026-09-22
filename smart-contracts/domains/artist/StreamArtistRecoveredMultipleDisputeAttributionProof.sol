// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleDisputeAttestationValidation as Validation
} from "./StreamArtistRecoveredMultipleDisputeAttestationValidation.sol";
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
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeClocks as ClockProof
} from "./StreamArtistRecoveredMultipleDisputeClocks.sol";
import {
    StreamArtistRecoveredMultipleDisputeRows as Rows
} from "./StreamArtistRecoveredMultipleDisputeRows.sol";
import {
    StreamArtistRecoveredMultipleDisputeGuards as Guards
} from "./StreamArtistRecoveredMultipleDisputeGuards.sol";
import {
    StreamArtistRecoveredMultipleDisputeTimeline as Timeline
} from "./StreamArtistRecoveredMultipleDisputeTimeline.sol";
import {
    StreamArtistRecoveredMultipleDisputeArchive as Archive
} from "./StreamArtistRecoveredMultipleDisputeArchive.sol";

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
    StreamArtistRecoveredAggregateSanctionAttributionFacts as SanctionFacts
} from "./StreamArtistRecoveredAggregateSanctionAttributionFacts.sol";

/// @notice Complete canonical owner4 rows, original clocks, revocations and attestations.
/// @dev Keeps the original semantic rows for clock/revocation validation and a fresh
/// attestation row view. Neither validation consumes or alters the original row bytes.

library StreamArtistRecoveredMultipleDisputeAttributionProof {
    struct Result {
        D.Bundle[] histories;
        Original.Bundle[] all;
    }

    function validate(
        M.State memory scope,
        RH.OwnerProvenance memory provenance,
        G.Inventory memory inventory
    ) public view returns (Result memory result) {
        H.Inventory memory sanctions;
        (scope, sanctions) = SanctionTransport.decode(scope);
        if (sanctions.sanctions.length != 0) {
            SanctionLocal.validate(provenance, 4, scope.collections, sanctions);
        }
        result.histories = new D.Bundle[](scope.rows.length);
        M.State memory attested =
            M.State(scope.artists, scope.collections, new bytes[](scope.rows.length));
        for (uint256 k; k < scope.rows.length; ++k) {
            MD.Attribution memory row = abi.decode(scope.rows[k], (MD.Attribution));
            if (keccak256(scope.rows[k]) != keccak256(abi.encode(row))) _invalid();
            if (
                keccak256(abi.encode(row.history.current))
                    != keccak256(abi.encode(row.records.item))
            ) _invalid();
            result.histories[k] = row.history;
            attested.rows[k] = abi.encode(row.records);
        }
        Clocks.Result memory clocks = ClockProof.validateLocal(scope, provenance, inventory);
        validateHistory(
            result.histories, scope, provenance, inventory, clocks, sanctions.confirmations
        );
        result.all = Validation.validate(
            attested, provenance, inventory, clocks, sanctions.sanctions.length != 0
        );
    }

    function validateHistory(
        D.Bundle[] memory histories,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory,
        Clocks.Result memory clocks
    ) public view {
        validateHistory(histories, scope, p, inventory, clocks, new H.ConfirmationRow[](0));
    }

    function validateHistory(
        D.Bundle[] memory histories,
        M.State memory scope,
        RH.OwnerProvenance memory p,
        G.Inventory memory inventory,
        Clocks.Result memory clocks,
        H.ConfirmationRow[] memory confirmations
    ) public view {
        Rows.validate(histories, scope, p, inventory, confirmations.length != 0);
        Guards.validate(histories, p, clocks, confirmations);
        Timeline.validate(histories, p, inventory, clocks);
        Archive.validate(histories, p, inventory);
        if (confirmations.length != 0) SanctionFacts.disputes(histories, p, clocks, confirmations);
    }

    /// @dev Same complete proof with no unused external return-data decoding at the final currentness call.
    function requireValid(
        M.State memory scope,
        RH.OwnerProvenance memory provenance,
        G.Inventory memory inventory
    ) public view {
        validate(scope, provenance, inventory);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
