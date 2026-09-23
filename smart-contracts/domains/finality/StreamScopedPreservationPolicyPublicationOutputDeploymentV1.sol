// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamPreservationPolicyOutputManifestV1 as Child
} from "./StreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamScopedPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamScopedPreservationPolicyPublicationRecipeV1.sol";

/// @notice Fixed delegate-host CREATE worker; callers cannot nominate implementation code.
library StreamScopedPreservationPolicyPublicationOutputDeploymentV1 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return address(
            new Child(
                r.inventory.targets[0],
                g.children[1],
                r.inventory.targets[10],
                r.targets[3],
                r.outputGas
            )
        );
    }
}
