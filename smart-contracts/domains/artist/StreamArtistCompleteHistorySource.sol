// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistCollaboratorRecordsOwner as Collaborator
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorRecordsOwner.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as PCClocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import { StreamArtistCompleteHistoryTypes as C } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistCompleteHistoryCatalogue as Catalogue
} from "./StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistCompleteHistoryBindingSource as Bindings
} from "./StreamArtistCompleteHistoryBindingSource.sol";
import {
    StreamArtistCompleteHistoryBindingProof as BindingProof
} from "./StreamArtistCompleteHistoryBindingProof.sol";
import {
    StreamArtistCompleteHistoryCollaborators as Collaborators
} from "./StreamArtistCompleteHistoryCollaborators.sol";
import {
    StreamArtistCompleteHistoryPlatformSource as Platform
} from "./StreamArtistCompleteHistoryPlatformSource.sol";
import {
    StreamArtistCompleteHistoryClocks as Clocks
} from "./StreamArtistCompleteHistoryClocks.sol";
import {
    StreamArtistCompleteHistoryAcceptance as Acceptance
} from "./StreamArtistCompleteHistoryAcceptance.sol";
import { StreamArtistCompleteHistoryScope as Scope } from "./StreamArtistCompleteHistoryScope.sol";
import {
    StreamArtistPrimaryCollaboratorAccountNonces as Accounts
} from "./StreamArtistPrimaryCollaboratorAccountNonces.sol";

/// @notice Shared binding/collaborator/Platform inventory and original acceptance chronology.
/// @dev This is a source phase. Identity, Payout, disputes, consents, attestations and full
/// owner4 accounting must also complete before any seven-owner import can be constructed.
library StreamArtistCompleteHistorySource {
    function collect(M.State memory scope, RH.Provenance memory p)
        public
        view
        returns (C.Inventory memory inventory, PCClocks.Result memory clocks)
    {
        if (p.origins.length == 0) _invalid();
        RH.OriginEnvironment memory source = p.origins[p.origins.length - 1];
        inventory.provenance = p;
        inventory.bindings = Bindings.collect(source.owners[0], scope, RH.ownerProvenance(p, 0));
        (inventory.archive.catalogues, inventory.archive.operations) = Catalogue.collect(p);
        inventory.archive =
            Collaborators.collect(p, inventory.archive.catalogues, inventory.archive.operations);
        inventory.platforms = Platform.collect(
            source.owners[4],
            scope,
            RH.ownerProvenance(p, 4),
            inventory.archive.catalogues,
            inventory.archive.operations
        );
        clocks =
            Clocks.validate(scope, p, inventory.bindings, inventory.archive, inventory.platforms);
        BindingProof.validate(
            scope, RH.ownerProvenance(p, 0), inventory.bindings, inventory.archive, clocks
        );
        inventory.accepted = Acceptance.collect(
            source.owners[3], scope, p, inventory.bindings, inventory.archive, clocks
        );
        inventory.accounts = Accounts.collect(p, inventory.archive);
        for (uint256 i; i < inventory.archive.proposals.length; ++i) {
            bytes32 id = inventory.archive.proposals[i].state.acceptedArtistId;
            if (id != 0) Scope.artist(scope, id);
        }
        for (uint256 i; i < inventory.archive.accepted.length; ++i) {
            Scope.artist(scope, inventory.archive.accepted[i].join.artistId);
        }
        for (uint256 k; k < inventory.bindings.bindings.length; ++k) {
            for (uint256 g; g < inventory.bindings.generations[k].length; ++g) {
                bytes32 binding = inventory.bindings.generations[k][g].bindingHash;
                uint256 count;
                for (uint256 i; i < inventory.archive.accepted.length; ++i) {
                    if (inventory.archive.accepted[i].acceptance.bindingHash == binding) ++count;
                }
                if (Collaborator(source.owners[1]).acceptedCount(binding) != count) _invalid();
            }
        }
    }

    function requireCurrent(M.State memory scope, C.Inventory memory expected)
        public
        view
        returns (PCClocks.Result memory clocks)
    {
        C.Inventory memory actual;
        (actual, clocks) = collect(scope, expected.provenance);
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(expected))) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
