// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryEvidence } from "./StreamArtistRecoveryEvidence.sol";

/// @notice Fixed compiler-linked creation for the future Identity owner's evidence publisher.
library StreamArtistRecoveryEvidenceDeployment {
    function deploy(
        address host,
        address registry,
        address coordinator,
        address archive,
        address core,
        address manager
    ) public returns (address) {
        return address(
            new StreamArtistRecoveryEvidence(host, registry, coordinator, archive, core, manager)
        );
    }
}
