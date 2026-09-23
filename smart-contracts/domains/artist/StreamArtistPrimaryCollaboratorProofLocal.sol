// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorTypes as G
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Exact RH.ownerProvenance field projection from an already fully decoded calldata Proof.
library StreamArtistPrimaryCollaboratorProofLocal {
    function encoded(RH.Provenance calldata p, uint8 index) public pure returns (bytes memory) {
        if (index >= 7) revert RH.InvalidRecoveredHydrationProfile();
        RH.OwnerProvenance memory result;
        result.origins = p.origins;
        result.eras = new RH.OwnerEra[](p.eras.length);
        for (uint256 i; i < p.eras.length; ++i) {
            result.eras[i] = RH.OwnerEra(
                p.eras[i].originHash,
                p.eras[i].checkpoints[index],
                p.eras[i].nativeCounts[index],
                p.eras[i].lowerRevisions[index],
                p.eras[i].priorImportCommitment
            );
        }
        result.journal = p.journals[index];
        result.aliases = p.aliases[index];
        return abi.encode(result);
    }
}
