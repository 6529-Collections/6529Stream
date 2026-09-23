// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamBundleArchiveTypes as B
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityScopedBundleArchiveCoverage as Child
} from "../preservation/StreamCurrentAuthorityScopedBundleArchiveCoverage.sol";

/// @notice Fixed delegate-host CREATE from the original typed constructor arguments.
library StreamCurrentAuthorityScopedPolicyPublicationBundleConstructorV2 {
    function deploy(
        B.Dependencies memory d,
        O.Dependencies memory o,
        D.Dependencies memory a,
        bytes32 inventoryProfile_
    ) public returns (address) {
        return address(new Child(d, o, a, inventoryProfile_));
    }
}
