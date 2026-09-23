// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformParts as Parts
} from "./StreamArtistRecoveredPlatformParts.sol";
import {
    StreamArtistRecoveredPlatformCatalogue as Catalogue
} from "./StreamArtistRecoveredPlatformCatalogue.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

/// @notice Recheck the exhaustive original catalogue after complete semantic validation.
library StreamArtistRecoveredPlatformCurrent {
    function requireCurrent(RH.Provenance memory p, bytes memory raw) public view {
        bytes[4] memory parts = Parts.members(raw);
        P.Platform memory platform = abi.decode(parts[2], (P.Platform));
        if (keccak256(parts[2]) != keccak256(abi.encode(platform))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        Catalogue.requireCurrent(p, platform.catalogues, platform.operations);
    }
}
