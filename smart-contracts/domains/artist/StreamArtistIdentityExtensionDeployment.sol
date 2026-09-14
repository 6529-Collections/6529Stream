// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityWriterExtension.sol";

/// @notice Fixed linked construction for an explicitly bound future Identity host.
library StreamArtistIdentityExtensionDeployment {
    function deployWriter(
        address host,
        address registry,
        address coordinator,
        address archive,
        address core,
        address manager
    ) public returns (address) {
        return address(
            new StreamArtistIdentityWriterExtension(
                host, registry, coordinator, archive, core, manager
            )
        );
    }
}
