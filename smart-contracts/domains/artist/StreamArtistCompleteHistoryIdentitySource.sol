// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistPrimaryCollaboratorIdentitySource as Identity
} from "./StreamArtistPrimaryCollaboratorIdentitySource.sol";
import {
    StreamArtistCompleteHistoryIdentityFacts as Facts
} from "./StreamArtistCompleteHistoryIdentityFacts.sol";
import {
    StreamArtistPrimaryCollaboratorAccountNonces as Accounts
} from "./StreamArtistPrimaryCollaboratorAccountNonces.sol";
import {
    StreamArtistPrimaryCollaboratorNonceUnion as Nonces
} from "./StreamArtistPrimaryCollaboratorNonceUnion.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";

/// @notice Fixed canonical Identity collection and complete-history joins before owner payloads.
/// @dev Empty all-unbound histories use their separate EmptyIdentity stage. Extended authority
/// families use validateCollected only after their fixed actual-state collectors authenticate
/// the same canonical bundles; this phase does not grant a caller-supplied bundle authority.
library StreamArtistCompleteHistoryIdentitySource {
    function collect(
        M.State memory scope,
        CT.Inventory memory inventory,
        Clocks.Result memory clocks,
        RH.NonceInventory[] memory globalNonces
    ) public view returns (bytes[] memory identities) {
        RH.OwnerProvenance memory p = RH.ownerProvenance(inventory.provenance, 2);
        if (scope.artists.length == 0 || p.origins.length == 0) _invalid();
        identities = new bytes[](scope.artists.length);
        for (uint256 i; i < identities.length; ++i) {
            (bool ok, bytes memory raw) = address(Identity)
                .staticcall(
                    abi.encodeWithSelector(
                        Identity.collect.selector,
                        p.origins[p.origins.length - 1].owners[2],
                        scope.artists[i],
                        p
                    )
                );
            identities[i] = Tuple.result(ok, raw);
            Tuple.requireSingle(identities[i]);
        }
        validateCollected(scope, inventory, clocks, identities, globalNonces);
    }

    function validateCollected(
        M.State memory scope,
        CT.Inventory memory inventory,
        Clocks.Result memory clocks,
        bytes[] memory identities,
        RH.NonceInventory[] memory globalNonces
    ) public view {
        if (scope.artists.length == 0 || identities.length != scope.artists.length) _invalid();
        RH.OwnerProvenance memory p = RH.ownerProvenance(inventory.provenance, 2);
        if (p.origins.length == 0 || p.eras.length != p.origins.length) _invalid();
        address source = p.origins[p.origins.length - 1].owners[2];
        Provenance.validateOwnerSource(p, 2, source);
        Provenance.validateNonces(source, p.eras[p.eras.length - 1].checkpoint, globalNonces);
        if (
            keccak256(abi.encode(Accounts.collect(inventory.provenance, inventory.archive)))
                != keccak256(abi.encode(inventory.accounts))
        ) _invalid();
        scope.rows = identities;
        Nonces.ordered(scope, globalNonces, inventory.accounts);
        Facts.validate(Facts.Context(identities, scope, inventory, clocks));
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
