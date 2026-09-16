// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityRecoveryExtension.sol";

/// @notice Fixed linked construction for an explicitly bound future Identity host.
library StreamArtistRecoveryExtensionDeployment {
    function deployRecoveryWriter(
        address host,
        address registry,
        address coordinator,
        address archive,
        address core,
        address manager
    ) public returns (address) {
        return address(
            new StreamArtistIdentityRecoveryExtension(
                host, registry, coordinator, archive, core, manager
            )
        );
    }
}
