// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredSimpleHydrationTypes as S
} from "../../interfaces/stream/artist/StreamArtistRecoveredSimpleHydrationTypes.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredMultipleConsentGrantRows as Grants
} from "./StreamArtistRecoveredMultipleConsentGrantRows.sol";
import {
    StreamArtistRecoveredMultipleConsentContentRows as Content
} from "./StreamArtistRecoveredMultipleConsentContentRows.sol";

/// @notice One complete grant-use equality per original Artist after all collection/family increments.
/// @dev Identity rows and collection rows are already source-authenticated and globally complete.
library StreamArtistRecoveredMultipleConsentFacts {
    function validate(
        bytes[] calldata identities,
        M.State calldata scope,
        ContentH.Bundle[] calldata consents,
        bytes[] calldata bindings,
        RH.Provenance calldata p
    ) public pure {
        if (
            identities.length != scope.artists.length || consents.length != scope.collections.length
                || bindings.length != consents.length
        ) _invalid();
        for (uint256 a; a < identities.length; ++a) {
            IH.Bundle calldata identity = Frame.bundle(identities[a]);
            if (identity.artistId != scope.artists[a].artistId) _invalid();
            uint256[] memory total = new uint256[](identity.delegations.length);
            for (uint256 c; c < consents.length; ++c) {
                AH.Query calldata q = scope.collections[c];
                if (q.artistId != identity.artistId) continue;
                ContentH.Bundle calldata row = consents[c];
                S.Binding memory binding = abi.decode(bindings[c], (S.Binding));
                if (
                    binding.item.artistId != q.artistId || binding.item.bindingHash != q.bindingHash
                ) _invalid();
                uint256[] memory uses = Content.validateRows(
                    Content.IdentityRows(
                        identity.artistId, identity.signatures, identity.delegations
                    ),
                    Content.ConsentRows(
                        row.original.artistId,
                        row.original.collectionId,
                        row.original.bindingHash,
                        row.consents,
                        row.royalties,
                        row.freezes
                    ),
                    Content.Scope(q.artistId, q.collectionId, q.bindingHash),
                    p
                );
                uses = Grants.validateRows(
                    Grants.IdentityRows(identity.artistId, identity.delegations),
                    Grants.ConsentRows(
                        row.original.artistId,
                        row.original.collectionId,
                        row.original.bindingHash,
                        row.original.policies,
                        row.original.economics,
                        row.original.sales
                    ),
                    Grants.Scope(q.artistId, q.collectionId, q.bindingHash),
                    p,
                    binding.item.consentMode,
                    uses
                );
                if (uses.length != total.length) _invalid();
                for (uint256 g; g < uses.length; ++g) {
                    total[g] += uses[g];
                }
            }
            for (uint256 g; g < total.length; ++g) {
                if (total[g] != identity.delegations[g].record.uses) _invalid();
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
