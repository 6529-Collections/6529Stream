// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistCreationSource.sol";

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
        return StreamArtistCreationSource.deploy(
            1, abi.encode(host, registry, coordinator, archive, core, manager)
        );
    }
}
