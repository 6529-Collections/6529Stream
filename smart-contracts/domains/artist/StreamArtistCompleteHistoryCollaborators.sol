// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistCompleteHistoryCatalogue as Catalogue
} from "./StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistPrimaryCollaboratorRecords as Original
} from "./StreamArtistPrimaryCollaboratorRecords.sol";

/// @notice Reuses the complete original owner1 proof and restores common Archive coordinates.
/// @dev Only operation selectors are projected. The original proof independently rescans the
/// authentic Archive and consumes the unchanged full seven-owner provenance and nonce history.
library StreamArtistCompleteHistoryCollaborators {
    function collect(
        RH.Provenance memory p,
        P.Catalogue[] memory catalogues,
        H.OperationEvidence[] memory operations
    ) public view returns (PC.Inventory memory result) {
        Catalogue.requireCurrent(p, catalogues, operations);
        H.OperationEvidence[] memory selected = new H.OperationEvidence[](operations.length);
        uint256[] memory indices = new uint256[](operations.length);
        uint256 count;
        for (uint256 i; i < operations.length; ++i) {
            if (operations[i].operation >= 1 && operations[i].operation <= 7) {
                selected[count] = operations[i];
                indices[count++] = i;
            }
        }
        assembly ("memory-safe") { mstore(selected, count) }
        result = Original.collect(p, catalogues, selected);
        for (uint256 i; i < result.proposals.length; ++i) {
            PC.Proposal memory r = result.proposals[i];
            if (r.proposalOperation >= count) _invalid();
            result.proposals[i].proposalOperation = indices[r.proposalOperation];
            if (r.identityOperationPlusOne != 0) {
                if (r.identityOperationPlusOne > count) _invalid();
                result.proposals[i].identityOperationPlusOne =
                    indices[r.identityOperationPlusOne - 1] + 1;
            }
        }
        for (uint256 i; i < result.accepted.length; ++i) {
            uint256 at = result.accepted[i].operationIndex;
            if (at >= count) _invalid();
            result.accepted[i].operationIndex = indices[at];
        }
        result.operations = operations;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
