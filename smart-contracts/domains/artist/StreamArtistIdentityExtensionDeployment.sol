// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityWriterExtension.sol";

/// @notice Linked construction only; the Identity remains child CREATE creator.
library StreamArtistIdentityExtensionDeployment {
    function deployWriter(
        address registry,
        address coordinator,
        address archive,
        address core,
        address manager
    ) public returns (address) {
        return address(
            new StreamArtistIdentityWriterExtension(
                address(this), registry, coordinator, archive, core, manager
            )
        );
    }
}
