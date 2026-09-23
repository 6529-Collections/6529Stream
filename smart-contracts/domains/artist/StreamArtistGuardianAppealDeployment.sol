// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistGuardianAppealEvidence } from "./StreamArtistGuardianAppealEvidence.sol";

library StreamArtistGuardianAppealDeployment {
    function deploy(address owner, address registry) public returns (address) {
        return address(new StreamArtistGuardianAppealEvidence(owner, registry));
    }
}
