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
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredMultipleConsentGrantRows as Grants
} from "./StreamArtistRecoveredMultipleConsentGrantRows.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentRows as Content
} from "./StreamArtistRecoveredMultipleGenerationConsentRows.sol";

/// @notice Per-Artist/per-retained-grant increments for complete generation-aware Consent rows.
/// @dev The caller authenticates the canonical Identity frames, original bindings and complete
/// owner journals, then validates Consent rows. Other families, full nonce inventories and the
/// one final grant-use equality belong to the enclosing aggregate profile.
library StreamArtistRecoveredMultipleGenerationConsentUses {
    struct Context {
        bytes[] identities;
        M.State scope;
        G.Consents[] consents;
        RH.Provenance provenance;
    }

    function validate(Context calldata x) public pure returns (uint256[][] memory totals) {
        return _validate(x, false);
    }

    /// @dev Original52 facts must already be authenticated by the enclosing aggregate.
    function validateRatified(Context calldata x) public pure returns (uint256[][] memory totals) {
        return _validate(x, true);
    }

    function _validate(Context calldata x, bool allowRatifications)
        private
        pure
        returns (uint256[][] memory totals)
    {
        if (
            x.identities.length == 0 || x.identities.length > 128
                || x.identities.length != x.scope.artists.length || x.consents.length == 0
                || x.consents.length > 128 || x.consents.length != x.scope.collections.length
        ) _invalid();
        totals = new uint256[][](x.identities.length);
        for (uint256 a; a < x.identities.length; ++a) {
            IH.Bundle calldata identity = Frame.bundle(x.identities[a]);
            if (identity.artistId == 0 || identity.artistId != x.scope.artists[a].artistId) {
                _invalid();
            }
            for (uint256 earlier; earlier < a; ++earlier) {
                if (x.scope.artists[earlier].artistId == identity.artistId) _invalid();
            }
            totals[a] = new uint256[](identity.delegations.length);
        }
        for (uint256 c; c < x.consents.length; ++c) {
            AH.Query calldata q = x.scope.collections[c];
            G.Consents calldata row = x.consents[c];
            if (
                q.artistId == 0 || q.collectionId == 0 || q.bindingHash == 0
                    || row.rows.original.artistId != q.artistId
                    || row.rows.original.collectionId != q.collectionId
                    || row.rows.original.bindingHash != q.bindingHash
            ) _invalid();
            for (uint256 earlier; earlier < c; ++earlier) {
                if (x.scope.collections[earlier].collectionId == q.collectionId) _invalid();
            }
            uint256 selected = type(uint256).max;
            for (uint256 a; a < x.scope.artists.length; ++a) {
                if (x.scope.artists[a].artistId == q.artistId) selected = a;
            }
            if (selected == type(uint256).max) _invalid();
            IH.Bundle calldata identity = Frame.bundle(x.identities[selected]);
            uint8 historicalMode = _bindings(row.bindings, q);
            Content.IdentityRows memory contentIdentity =
                Content.IdentityRows(identity.artistId, identity.signatures, identity.delegations);
            Content.ConsentRows memory contentRows = Content.ConsentRows(
                row.rows.original.artistId,
                row.rows.original.collectionId,
                row.rows.original.bindingHash,
                row.rows.consents,
                row.rows.royalties,
                row.rows.freezes,
                row.bindings
            );
            Content.Scope memory contentScope =
                Content.Scope(q.artistId, q.collectionId, q.bindingHash);
            uint256[] memory uses = allowRatifications
                ? Content.validateRatifiedRows(
                    contentIdentity, contentRows, contentScope, x.provenance
                )
                : Content.validateRows(contentIdentity, contentRows, contentScope, x.provenance);
            // Original14 has no saved generation. An accepted historical mode2 binding is
            // necessary for retained delegated14, without assigning it to that generation.
            // Each original16 instead carries its own exact accepted mode2 binding, checked
            // by GenerationConsentValidation before this original grant/nonce reconciliation.
            uses = Grants.validateRows(
                Grants.IdentityRows(identity.artistId, identity.delegations),
                Grants.ConsentRows(
                    row.rows.original.artistId,
                    row.rows.original.collectionId,
                    row.rows.original.bindingHash,
                    row.rows.original.policies,
                    row.rows.original.economics,
                    row.rows.original.sales
                ),
                Grants.Scope(q.artistId, q.collectionId, q.bindingHash),
                x.provenance,
                historicalMode,
                uses
            );
            if (uses.length != totals[selected].length) _invalid();
            for (uint256 g; g < uses.length; ++g) {
                totals[selected][g] += uses[g];
            }
        }
    }

    function _bindings(T.Binding[] calldata bindings, AH.Query calldata q)
        private
        pure
        returns (uint8 historicalMode)
    {
        if (
            bindings.length == 0 || bindings.length > 128
                || bindings[bindings.length - 1].bindingHash != q.bindingHash
                || !bindings[bindings.length - 1].accepted
        ) _invalid();
        historicalMode = 1;
        for (uint256 i; i < bindings.length; ++i) {
            T.Binding calldata row = bindings[i];
            if (
                row.generation != i + 1 || row.artistId != q.artistId || row.bindingHash == 0
                    || (row.consentMode != 1 && row.consentMode != 2)
            ) _invalid();
            if (row.accepted && row.consentMode == 2) historicalMode = 2;
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
