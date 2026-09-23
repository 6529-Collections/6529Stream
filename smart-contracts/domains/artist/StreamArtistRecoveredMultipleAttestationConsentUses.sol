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

/// @notice Complete consent increments for the aggregate attestation join; no per-family grant equality.
/// @dev Identity rows and collection rows are already source-authenticated and globally complete.
library StreamArtistRecoveredMultipleAttestationConsentUses {
    struct Context {
        bytes[] identities;
        M.State scope;
        ContentH.Bundle[] consents;
        bytes[] bindings;
        RH.Provenance provenance;
    }

    function validate(Context calldata x) public pure returns (uint256[][] memory totals) {
        if (
            x.identities.length != x.scope.artists.length
                || x.consents.length != x.scope.collections.length
                || x.bindings.length != x.consents.length
        ) _invalid();
        totals = new uint256[][](x.identities.length);
        for (uint256 a; a < x.identities.length; ++a) {
            IH.Bundle calldata identity = Frame.bundle(x.identities[a]);
            if (identity.artistId != x.scope.artists[a].artistId) _invalid();
            uint256[] memory total = new uint256[](identity.delegations.length);
            for (uint256 c; c < x.consents.length; ++c) {
                AH.Query calldata q = x.scope.collections[c];
                if (q.artistId != identity.artistId) continue;
                ContentH.Bundle calldata row = x.consents[c];
                S.Binding memory binding = abi.decode(x.bindings[c], (S.Binding));
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
                    x.provenance
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
                    x.provenance,
                    binding.item.consentMode,
                    uses
                );
                if (uses.length != total.length) _invalid();
                for (uint256 g; g < uses.length; ++g) {
                    total[g] += uses[g];
                }
            }
            totals[a] = total;
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
