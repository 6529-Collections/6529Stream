// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeIdentityFacts as Original
} from "./StreamArtistRecoveredDisputeIdentityFacts.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredMultipleCodec as Scope
} from "./StreamArtistRecoveredMultipleCodec.sol";

/// @notice All original dispute/repudiation authorization facts and one complete veto inventory.
/// @dev Returns increments only; the caller sums consent and op24 uses before the single grant equality.
library StreamArtistRecoveredMultipleDisputeUses {
    struct Context {
        bytes[] identities;
        M.State scope;
        D.Bundle[] histories;
        RH.Provenance provenance;
    }

    function validate(Context calldata x) public pure returns (uint256[][] memory uses) {
        if (
            x.identities.length != x.scope.artists.length
                || x.histories.length != x.scope.collections.length
        ) _invalid();
        uses = new uint256[][](x.identities.length);
        uint256 vetoes;
        for (uint256 a; a < x.identities.length; ++a) {
            IH.Bundle calldata b = Frame.bundle(x.identities[a]);
            if (b.artistId != x.scope.artists[a].artistId) _invalid();
            uses[a] = new uint256[](b.delegations.length);
            Original.IdentityRows memory identity = Original.IdentityRows(
                b.artistId, b.signatures, b.nonces, b.delegations, b.contests, b.causes, b.guardians
            );
            for (uint256 k; k < x.histories.length; ++k) {
                if (x.scope.collections[k].artistId != b.artistId) continue;
                uint256[] memory increments = Original.validateRows(
                    identity, x.histories[k], x.scope.collections[k], x.provenance
                );
                for (uint256 g; g < increments.length; ++g) {
                    uses[a][g] += increments[g];
                }
                for (uint256 r; r < x.histories[k].repudiations.length; ++r) {
                    if (x.histories[k].repudiations[r].terminal.phase == 2) ++vetoes;
                }
            }
        }
        for (uint256 k; k < x.scope.collections.length; ++k) {
            Scope.artist(x.scope, x.scope.collections[k].artistId);
        }
        uint256 nativeVetoes;
        for (uint256 i; i < x.provenance.journals[2].length; ++i) {
            uint16 op = x.provenance.journals[2][i].receipt.operation;
            if (op == 48) ++nativeVetoes;
            // These original authorization/activity commits append no Identity native row.
            if (op == 44 || op == 45 || op == 47 || op == 49 || op == 50 || op == 61) _invalid();
        }
        if (nativeVetoes != 2 * vetoes) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
