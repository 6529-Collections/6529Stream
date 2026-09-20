// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistIdentityRewindExtension } from "./StreamArtistIdentityRewindExtension.sol";

/// @notice Constructor-only creation of the fixed V3 Identity child and its pinned helpers.
library StreamArtistRewindExtensionDeployment {
    function deploy(
        address host,
        address registry,
        address coordinator,
        address archive,
        address core,
        address manager
    ) public returns (address) {
        return address(
            new StreamArtistIdentityRewindExtension(
                host, registry, coordinator, archive, core, manager
            )
        );
    }
}
