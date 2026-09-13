// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityEstateExtension.sol";

/// @notice Fixed second Identity child construction; delegatecall retains the real Identity creator.
library StreamArtistEstateExtensionDeployment {
    function deployEstateWriter(
        address registry,
        address coordinator,
        address archive,
        address core,
        address manager
    ) public returns (address) {
        return address(
            new StreamArtistIdentityEstateExtension(
                address(this), registry, coordinator, archive, core, manager
            )
        );
    }
}
