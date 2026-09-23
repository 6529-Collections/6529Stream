// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamPreservationPolicyPublicationSnapshotConstructorV2 as Constructor
} from "./StreamPreservationPolicyPublicationSnapshotConstructorV2.sol";
import {
    StreamPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamPreservationPolicyPublicationRecipeV1.sol";

/// @notice Fixed family V2 CREATE worker; callers cannot nominate code or a producer family.
library StreamPreservationPolicyPublicationSnapshotDeploymentV2 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return Constructor.deploy(Recipe.snapshot(r, g), r.targets[3], r.snapshotGas);
    }
}
