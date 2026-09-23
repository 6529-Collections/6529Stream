// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredBindingGenerations as G
} from "./StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredHistoryContentTypes as HC
} from "./StreamArtistRecoveredHistoryContentTypes.sol";
import {
    StreamArtistRecoveredHistoryContentSource as Source
} from "./StreamArtistRecoveredHistoryContentSource.sol";
import {
    StreamArtistRecoveredHistoryContentCodec as Codec
} from "./StreamArtistRecoveredHistoryContentCodec.sol";

/// @notice Fixed collect, complete validation, source heads and canonical encoding in original order.
library StreamArtistRecoveredHistoryContentCollection {
    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        G.Bundle memory bindings,
        H.Inventory memory sanctions
    ) public view returns (bytes memory) {
        HC.Bundle memory b = Source.collect(source, q, p, economics, royalties, bindings, sanctions);
        Codec.validate(b, q, p);
        Source.requireHeads(source, b);
        return abi.encode(HC.SCHEMA, RH.VERSION, b);
    }
}
