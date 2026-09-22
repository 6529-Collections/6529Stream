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
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";

/// @notice Complete canonical owner4 rows, original clocks, revocations and attestations.
/// @dev Keeps the original semantic rows for clock/revocation validation and a fresh
/// attestation row view. Neither validation consumes or alters the original row bytes.
library StreamArtistPrimaryCollaboratorAttributionProof {
    struct Result {
        A.AttributionBundle[] histories;
        Original.Bundle[] all;
    }

    function validate(
        M.State memory scope,
        RH.OwnerProvenance memory provenance,
        PC.Proof memory inventory
    ) public view returns (Result memory result) {
        result.histories = new A.AttributionBundle[](scope.rows.length);
        M.State memory attested =
            M.State(scope.artists, scope.collections, new bytes[](scope.rows.length));
        for (uint256 k; k < scope.rows.length; ++k) {
            G.Attribution memory row = abi.decode(scope.rows[k], (G.Attribution));
            if (keccak256(scope.rows[k]) != keccak256(abi.encode(row))) _invalid();
            result.histories[k] = row.history;
            attested.rows[k] = abi.encode(row.records);
        }
        if (
            keccak256(abi.encode(provenance))
                != keccak256(abi.encode(RH.ownerProvenance(inventory.provenance, 4)))
        ) _invalid();
        Source.Result memory source = Source.requireCurrent(scope, inventory);
        Revocations.validate(
            result.histories, scope, provenance, source.generations, source.clocks.clocks
        );
        result.all =
            Validation.validate(attested, provenance, source.generations, source.clocks.clocks);
    }

    /// @dev Same complete proof with no unused external return-data decoding at the final currentness call.
    function requireValid(
        M.State memory scope,
        RH.OwnerProvenance memory provenance,
        PC.Proof memory inventory
    ) public view {
        validate(scope, provenance, inventory);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
