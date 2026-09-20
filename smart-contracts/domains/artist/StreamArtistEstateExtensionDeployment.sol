// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistCreationSource.sol";

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
        return StreamArtistCreationSource.deploy(
            2, abi.encode(host, registry, coordinator, archive, core, manager)
        );
    }
}
