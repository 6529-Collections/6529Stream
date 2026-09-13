// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityRecoveryExtension.sol";

/// @notice Fixed third child construction; the original two Identity child nonces remain unchanged.
library StreamArtistRecoveryExtensionDeployment {
    function deployRecoveryWriter(
        address registry,
        address coordinator,
        address archive,
        address core,
        address manager
    ) public returns (address) {
        return address(
            new StreamArtistIdentityRecoveryExtension(
                address(this), registry, coordinator, archive, core, manager
            )
        );
    }
}
