// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentitySourceCanonical as Canonical
} from "./StreamArtistRecoveredIdentitySourceCanonical.sol";
import {
    StreamArtistRecoveredMultipleIdentityValidation as Validation
} from "./StreamArtistRecoveredMultipleIdentityValidation.sol";

/// @notice The aggregate's fixed Identity row is exactly abi.encode(IH.Bundle), with full provenance.
library StreamArtistRecoveredMultipleIdentityCodec {
    function transport(bytes calldata raw) public pure returns (bytes memory) {
        return Canonical.canonical(raw, false);
    }

    function decode(bytes calldata raw, RH.OwnerProvenance calldata p)
        public
        pure
        returns (bytes memory canonical)
    {
        canonical = Canonical.canonical(raw, false);
        if (keccak256(raw) != keccak256(canonical)) revert RH.InvalidRecoveredHydrationProfile();
        Validation.validateEncoded(canonical, p);
    }
}
