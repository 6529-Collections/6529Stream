// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamPreservationPolicyPublicationOutputConstructorV2 as Constructor
} from "./StreamPreservationPolicyPublicationOutputConstructorV2.sol";
import {
    StreamPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamPreservationPolicyPublicationRecipeV1.sol";

/// @notice Fixed family V2 CREATE worker; callers cannot nominate code or a producer family.
library StreamPreservationPolicyPublicationOutputDeploymentV2 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return Constructor.deploy(
            r.inventory.targets[0],
            g.children[1],
            r.inventory.targets[10],
            r.targets[3],
            r.outputGas
        );
    }
}
