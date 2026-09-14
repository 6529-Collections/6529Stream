// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityEstateExtension.sol";

/// @notice Fixed linked construction for an explicitly bound future Identity host.
library StreamArtistEstateExtensionDeployment {
    function deployEstateWriter(
        address host,
        address registry,
        address coordinator,
        address archive,
        address core,
        address manager
    ) public returns (address) {
        return address(
            new StreamArtistIdentityEstateExtension(
                host, registry, coordinator, archive, core, manager
            )
        );
    }
}
