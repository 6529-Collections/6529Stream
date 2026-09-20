// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamPreservationPolicyContentCheckpointV2 as Child
} from "./StreamPreservationPolicyContentCheckpointV2.sol";
import {
    StreamPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamPreservationPolicyPublicationRecipeV1.sol";

/// @notice Fixed family V2 CREATE worker; callers cannot nominate code or a producer family.
library StreamPreservationPolicyPublicationCheckpointDeploymentV2 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return address(
            new Child(
                r.targets[1],
                g.sourceSet,
                g.children[0],
                r.targets[3],
                r.checkpointGas[0],
                r.checkpointGas[1]
            )
        );
    }
}
