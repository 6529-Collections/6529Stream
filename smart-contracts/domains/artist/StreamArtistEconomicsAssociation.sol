// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Additive economics binding scopes; original consent_key(payload) is never rewritten.
library StreamArtistEconomicsAssociation {
    function key(
        T.EconomicsConsent memory p,
        bytes32 artistId,
        uint64 generation,
        bytes32 bindingHash
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ECONOMICS_BINDING_ASSOCIATION_V1"),
                p,
                artistId,
                generation,
                bindingHash
            )
        );
    }

    function continuation(bytes32 original, T.EconomicsConsent memory p, T.Binding memory b)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ECONOMICS_BINDING_CONTINUATION_V1"),
                original,
                p,
                b.artistId,
                b.generation,
                b.bindingHash
            )
        );
    }
}
