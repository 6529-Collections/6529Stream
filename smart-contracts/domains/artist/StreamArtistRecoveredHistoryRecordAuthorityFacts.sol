// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHistoryRecordFacts as Original
} from "./StreamArtistRecoveredHistoryRecordFacts.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredDisputeBindingFacts as BindingFacts
} from "./StreamArtistRecoveredDisputeBindingFacts.sol";
import {
    StreamArtistRecoveredDisputeIdentityFacts as DisputeFacts
} from "./StreamArtistRecoveredDisputeIdentityFacts.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Original complete binding/signature and dispute/grant facts in their original order.
/// @dev Only the fixed Facts caller supplies the unchanged full typed frame; no source fields are projected.
library StreamArtistRecoveredHistoryRecordAuthorityFacts {
    function validate(IH.Bundle calldata identity, Original.Context calldata x)
        public
        view
        returns (uint256[] memory uses)
    {
        G.Bundle calldata bindings = x.bindings;
        D.Bundle calldata attribution = x.attribution;
        AH.Query calldata q = x.query;
        RH.Provenance calldata p = x.provenance;
        BindingFacts.validateRows(
            BindingFacts.IdentityRows(identity.artistId, identity.documents, identity.signatures),
            bindings,
            BindingFacts.Scope(q.artistId, q.collectionId, q.bindingHash),
            p
        );
        uses = DisputeFacts.validate(
            DisputeFacts.IdentityRows(
                identity.artistId,
                identity.signatures,
                identity.nonces,
                identity.delegations,
                identity.contests,
                identity.causes,
                identity.guardians
            ),
            attribution,
            q,
            p
        );
    }
}
