// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryRewindEvidence } from "./StreamArtistRecoveryRewindEvidence.sol";

library StreamArtistRecoveryRewindEvidenceDeployment {
    function deploy(
        address host,
        address registry,
        address coordinator,
        address archive,
        address core,
        address manager
    ) public returns (address) {
        return address(
            new StreamArtistRecoveryRewindEvidence(
                host, registry, coordinator, archive, core, manager
            )
        );
    }
}
