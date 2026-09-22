// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeIdentityFacts as Original
} from "./StreamArtistRecoveredDisputeIdentityFacts.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredIdentitySourceCanonical as Canonical
} from "./StreamArtistRecoveredIdentitySourceCanonical.sol";
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import { StreamArtistCompleteHistoryScope as Scope } from "./StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
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
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Original dispute authorizations routed by each original standing principal.
/// @dev Fixed Identity collectors and dispute-family facts precede this adapter. The global
/// signature map is transported under the native receipt's bound Artist; the actual author
/// supplies nonce/grant authority. No source scope or historical record is rewritten.
/// Returned increments join consent/op24 uses before the enclosing complete grant equality.
library StreamArtistCompleteHistoryDisputeIdentityUses {
    struct Context {
        bytes[] identities;
        M.State scope;
        CT.Inventory inventory;
        D.Bundle[] histories;
    }

    function validate(Context calldata x) public pure returns (uint256[][] memory uses) {
        if (
            x.identities.length != x.scope.artists.length
                || x.histories.length != x.scope.collections.length
                || x.inventory.bindings.bindings.length != x.histories.length
        ) _invalid();
        RH.Provenance memory p = x.inventory.provenance;
        Provenance.validate(p);
        uses = new uint256[][](x.identities.length);
        Original.IdentityRows[] memory identities = new Original.IdentityRows[](x.identities.length);
        for (uint256 a; a < x.identities.length; ++a) {
            if (
                keccak256(x.identities[a]) != keccak256(Canonical.canonical(x.identities[a], false))
            ) {
                _invalid();
            }
            IH.Bundle calldata b = Frame.bundle(x.identities[a]);
            if (
                b.artistId == 0 || b.artistId != x.scope.artists[a].artistId
                    || (a != 0 && b.artistId <= x.scope.artists[a - 1].artistId)
                    || keccak256(abi.encode(b.sourceSnapshot))
                        != keccak256(
                            abi.encode(p.eras[p.eras.length - 1].checkpoints[2].ownerState)
                        )
            ) _invalid();
            identities[a] = Original.IdentityRows(
                b.artistId, b.signatures, b.nonces, b.delegations, b.contests, b.causes, b.guardians
            );
            uses[a] = new uint256[](b.delegations.length);
        }
        uint256 vetoes;
        bytes32 owner4 = RH.ownerProvenanceHash(RH.ownerProvenance(p, 4), 4);
        for (uint256 k; k < x.histories.length; ++k) {
            D.Bundle calldata b = x.histories[k];
            if (
                b.provenance != owner4 || b.collectionId != x.scope.collections[k].collectionId
                    || b.artistId != x.scope.collections[k].artistId
                    || b.bindingHash != x.scope.collections[k].bindingHash
                    || b.generations.length != x.inventory.bindings.bindings[k].bindings.rows.length
            ) _invalid();
            for (uint256 i; i < b.disputes.length; ++i) {
                D.DisputeRow calldata row = b.disputes[i];
                _binding(
                    x,
                    k,
                    row.record.terms.bindingGeneration,
                    row.record.artistId,
                    row.record.bindingHash
                );
                if (row.record.governanceActionId != 0) continue;
                uint256 author = Scope.artist(x.scope, row.record.standing.artistId);
                uint256 carrier = Scope.artist(x.scope, row.record.artistId);
                uint256 grant = Original.disputeUse(
                    identities[author], identities[carrier].signatures, row, p
                );
                if (grant != 0) {
                    if (grant > uses[author].length) _invalid();
                    ++uses[author][grant - 1];
                }
            }
            for (uint256 i; i < b.repudiations.length; ++i) {
                D.RepudiationRow calldata row = b.repudiations[i];
                _binding(
                    x,
                    k,
                    row.record.terms.bindingGeneration,
                    row.record.artistId,
                    row.record.bindingHash
                );
                Original.repudiationUse(
                    identities[Scope.artist(x.scope, row.record.artistId)], row, p
                );
                if (row.terminal.phase == 2) ++vetoes;
            }
        }
        uint256 nativeVetoes;
        for (uint256 i; i < p.journals[2].length; ++i) {
            uint16 operation = p.journals[2][i].receipt.operation;
            if (operation == 48) ++nativeVetoes;
            // These original activity commits append no Identity native receipt.
            if (
                operation == 44 || operation == 45 || operation == 47 || operation == 49
                    || operation == 50 || operation == 61
            ) _invalid();
        }
        if (nativeVetoes != 2 * vetoes) _invalid();
    }

    function _binding(
        Context calldata x,
        uint256 collection,
        uint64 generation,
        bytes32 artist,
        bytes32 hash
    ) private pure {
        if (
            generation == 0
                || generation > x.inventory.bindings.bindings[collection].bindings.rows.length
        ) {
            _invalid();
        }
        T.Binding calldata b =
        x.inventory.bindings.bindings[collection].bindings.rows[generation - 1].item;
        if (artist != b.artistId || hash != b.bindingHash) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
