// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistCompleteHistorySource as Source
} from "./StreamArtistCompleteHistorySource.sol";
import {
    StreamArtistCompleteHistoryDisputeSource as Disputes
} from "./StreamArtistCompleteHistoryDisputeSource.sol";
import {
    StreamArtistCompleteHistoryDisputeArchive as DisputeArchive
} from "./StreamArtistCompleteHistoryDisputeArchive.sol";
import {
    StreamArtistCompleteHistoryAttestationSource as Attestations
} from "./StreamArtistCompleteHistoryAttestationSource.sol";
import {
    StreamArtistCompleteHistoryAccounting as Accounting
} from "./StreamArtistCompleteHistoryAccounting.sol";
import {
    StreamArtistCompleteHistorySanctionSource as Sanctions
} from "./StreamArtistCompleteHistorySanctionSource.sol";
import {
    StreamArtistCompleteHistorySanctionCurrent as Current
} from "./StreamArtistCompleteHistorySanctionCurrent.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";

/// @notice Exact original owner4 dispute, Platform and attestation family rows and clocks.
/// @dev This is a family proof, not a complete import authorization. The enclosing proof must
/// also join authenticated Identity uses. Current status always joins the complete original
/// fixed Burn inventory; no absent sanction inventory is interpreted as an empty history.
library StreamArtistCompleteHistoryAttributionProof {
    struct Result {
        D.Bundle[] histories;
        Original.Bundle[] all;
    }

    function validate(
        M.State memory scope,
        RH.OwnerProvenance memory p,
        CT.Inventory memory inventory
    ) public view returns (Result memory) {
        return validateAdmitted(scope, p, inventory, Source.requireCurrent(scope, inventory));
    }

    /// @dev Clocks must be the freshly authenticated output of CompleteHistoryDecode.collect
    /// or CompleteHistorySource.requireCurrent for this exact scope and inventory.
    function validateAdmitted(
        M.State memory scope,
        RH.OwnerProvenance memory p,
        CT.Inventory memory inventory,
        Clocks.Result memory clocks
    ) public view returns (Result memory result) {
        if (
            scope.rows.length != scope.collections.length
                || inventory.provenance.origins.length == 0
                || keccak256(abi.encode(p))
                    != keccak256(abi.encode(RH.ownerProvenance(inventory.provenance, 4)))
        ) _invalid();
        result.histories = new D.Bundle[](scope.rows.length);
        result.all = new Original.Bundle[](scope.rows.length);
        ReadinessH.AttestationInput[][] memory inputs =
            new ReadinessH.AttestationInput[][](scope.rows.length);
        for (uint256 k; k < scope.rows.length; ++k) {
            MD.Attribution memory row = abi.decode(scope.rows[k], (MD.Attribution));
            if (
                keccak256(scope.rows[k]) != keccak256(abi.encode(row))
                    || keccak256(abi.encode(row.history.current))
                        != keccak256(abi.encode(row.records.item))
            ) _invalid();
            result.histories[k] = row.history;
            result.all[k] = row.records;
            inputs[k] = new ReadinessH.AttestationInput[](row.records.records.length);
            for (uint256 i; i < inputs[k].length; ++i) {
                inputs[k][i] = row.records.records[i].attestation.input;
            }
        }
        address source =
            inventory.provenance.origins[inventory.provenance.origins.length - 1].owners[4];
        D.Bundle[] memory histories = Disputes.collect(
            source, scope, inventory.provenance, inventory.bindings, inventory.archive, clocks
        );
        if (keccak256(abi.encode(histories)) != keccak256(abi.encode(result.histories))) {
            _invalid();
        }
        // The source adapter runs the original semantic leaves, generation intervals and
        // all per-record/latest C2PA, personhood, publication and statement getter checks.
        bytes[] memory records = Attestations.collect(source, scope, inventory, clocks, inputs);
        for (uint256 k; k < records.length; ++k) {
            if (keccak256(records[k]) != keccak256(abi.encode(result.all[k]))) _invalid();
        }
        DisputeArchive.validate(histories, p, inventory, clocks);
        Accounting.validate(inventory, clocks, histories);
        Current.validate(
            Sanctions.collect(scope, inventory), histories, inventory.bindings, clocks, p
        );
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
