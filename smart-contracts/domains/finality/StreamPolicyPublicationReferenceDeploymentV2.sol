// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPolicyPublicationGraphTypesV2 as T
} from "../../interfaces/stream/finality/StreamPolicyPublicationGraphTypesV2.sol";
import {
    StreamPolicyPublicationReferenceConstructorV2 as Constructor
} from "./StreamPolicyPublicationReferenceConstructorV2.sol";
import { StreamPolicyPublicationRecipeV2 as Recipe } from "./StreamPolicyPublicationRecipeV2.sol";

/// @notice Fixed delegate-host CREATE worker; callers cannot nominate implementation code.
library StreamPolicyPublicationReferenceDeploymentV2 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return Constructor.deploy(Recipe.referenceDependencies(r, g), r.targets[3], r.referenceGas);
    }
}
