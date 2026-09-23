// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistIdentityAdjudicationExtension
} from "./StreamArtistIdentityAdjudicationExtension.sol";

/// @notice Constructor-only creation of the fixed V2 Identity child and its pinned helpers.
library StreamArtistAdjudicationExtensionDeployment {
    function deploy(
        address host,
        address registry,
        address coordinator,
        address archive,
        address core,
        address manager
    ) public returns (address) {
        return address(
            new StreamArtistIdentityAdjudicationExtension(
                host, registry, coordinator, archive, core, manager
            )
        );
    }
}
