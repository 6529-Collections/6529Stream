// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import { StreamArtistCompleteHistoryScope as Scope } from "./StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationRows as Rows
} from "./StreamArtistRecoveredMultipleGenerationAttestationRows.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistCompleteHistoryAttestationQueries as Queries
} from "./StreamArtistCompleteHistoryAttestationQueries.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Original op24 Identity/nonces/grant increments across every collection and generation.
/// @dev Complete semantic binding/Archive/credential validation precedes this fixed worker.
/// The enclosing composition joins these increments with all Consent families exactly once.

library StreamArtistCompleteHistoryAttestationUses {
    struct Context {
        bytes[] identities;
        M.State scope;
        bytes[] attestations;
        CT.Inventory inventory;
    }

    function validate(Context calldata x) public pure returns (uint256[][] memory uses) {
        if (
            x.identities.length != x.scope.artists.length
                || x.attestations.length != x.scope.collections.length
                || x.inventory.bindings.bindings.length != x.scope.collections.length
        ) _invalid();
        Rows.IdentityRows[] memory identities = new Rows.IdentityRows[](x.identities.length);
        uses = new uint256[][](identities.length);
        for (uint256 a; a < identities.length; ++a) {
            identities[a] = Rows.identity(x.identities[a], x.scope.artists[a].artistId);
            uses[a] = new uint256[](identities[a].delegations.length);
        }
        Original.Bundle[] memory all = new Original.Bundle[](x.attestations.length);
        for (uint256 k; k < all.length; ++k) {
            all[k] = abi.decode(x.attestations[k], (Original.Bundle));
            if (keccak256(x.attestations[k]) != keccak256(abi.encode(all[k]))) _invalid();
        }
        uint256[] memory cursors = new uint256[](all.length);
        for (uint256 i; i < x.inventory.provenance.journals[4].length; ++i) {
            RH.JournalEntry memory native_ = x.inventory.provenance.journals[4][i];
            if (Queries.other(native_.receipt)) continue;
            if (native_.receipt.operation != 24) _invalid();
            uint256 k = Scope.collection(x.scope, native_.receipt.collectionId);
            uint256 a = Scope.artist(x.scope, native_.receipt.artistId);
            if (cursors[k] >= all[k].records.length) _invalid();
            uint256 at = cursors[k]++;
            uint64 generation = all[k].records[at].attestation.record.generation;
            if (
                generation == 0
                    || generation > x.inventory.bindings.bindings[k].bindings.rows.length
            ) {
                _invalid();
            }
            T.Binding memory historical =
            x.inventory.bindings.bindings[k].bindings.rows[generation - 1].item;
            if (historical.artistId != native_.receipt.artistId) _invalid();
            uint256 grant = Rows.validate(
                identities[a],
                all[k].records[at].attestation,
                Rows.Scope(
                    historical.artistId, x.scope.collections[k].collectionId, historical.bindingHash
                ),
                x.inventory.provenance,
                native_
            );
            if (grant != type(uint256).max) ++uses[a][grant];
        }
        for (uint256 k; k < all.length; ++k) {
            if (cursors[k] != all[k].records.length) _invalid();
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
