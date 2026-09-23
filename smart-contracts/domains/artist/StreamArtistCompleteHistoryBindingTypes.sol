// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";

/// @notice Common binding inventory joins for the complete-history profile.
/// @dev The existing PC nominal carrier is retained. A collection query names its latest
/// head; every original row names its own principal, including a former principal.
library StreamArtistCompleteHistoryBindingTypes {
    function rowQuery(AH.Query memory latest, G.Row memory historical)
        internal
        pure
        returns (AH.Query memory q)
    {
        if (historical.item.artistId == 0 || historical.item.bindingHash == 0) _invalid();
        q.artistId = historical.item.artistId;
        q.collectionId = latest.collectionId;
        q.bindingHash = historical.item.bindingHash;
        q.policies = latest.policies;
        q.records = latest.records;
    }

    function principalIndex(M.State memory scope, bytes32 artistId)
        internal
        pure
        returns (uint256 index)
    {
        if (artistId == 0) _invalid();
        bool found;
        for (uint256 i; i < scope.artists.length; ++i) {
            if (scope.artists[i].artistId != artistId) continue;
            if (found) _invalid();
            found = true;
            index = i;
        }
        if (!found) _invalid();
    }

    function validate(
        M.State memory scope,
        PC.BindingInventory memory inventory,
        bytes32 provenance
    ) public pure {
        uint256 n = scope.collections.length;
        if (
            inventory.bindings.length != n || inventory.generations.length != n
                || inventory.collaborators.length != n
        ) _invalid();
        for (uint256 k; k < n; ++k) {
            AH.Query memory q = scope.collections[k];
            for (uint256 j; j < k; ++j) {
                if (scope.collections[j].collectionId == q.collectionId) _invalid();
            }
            CB.Bundle memory b = inventory.bindings[k];
            uint256 m = b.bindings.rows.length;
            if (
                m > 128 || inventory.generations[k].length != m || b.corrections.length != m
                    || inventory.collaborators[k].length != m
                    || b.bindings.provenanceCommitment != provenance
                    || b.bindings.artistId != q.artistId
                    || b.bindings.collectionId != q.collectionId
                    || b.bindings.bindingHash != q.bindingHash || b.bindings.current.generation != m
                    || b.bindings.current.artistId != q.artistId
                    || b.bindings.current.bindingHash != q.bindingHash
            ) _invalid();
            if (m == 0) {
                T.Binding memory empty;
                if (
                    q.artistId != 0 || q.bindingHash != 0
                        || keccak256(abi.encode(b.bindings.current)) != keccak256(abi.encode(empty))
                ) {
                    _invalid();
                }
                continue;
            }
            if (
                q.artistId == 0 || q.bindingHash == 0
                    || keccak256(abi.encode(b.bindings.current))
                        != keccak256(abi.encode(b.bindings.rows[m - 1].item))
            ) _invalid();
            for (uint256 g; g < m; ++g) {
                G.Row memory row = b.bindings.rows[g];
                principalIndex(scope, row.item.artistId);
                if (
                    row.item.generation != g + 1 || row.item.bindingHash == 0
                        || inventory.generations[k][g].generation != g + 1
                        || inventory.generations[k][g].bindingHash != row.item.bindingHash
                        || inventory.generations[k][g].accepted != row.item.accepted
                ) _invalid();
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
