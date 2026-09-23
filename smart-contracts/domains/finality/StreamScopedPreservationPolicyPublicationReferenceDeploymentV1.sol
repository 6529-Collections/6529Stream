// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamScopedPreservationPolicyReferencePublicationV1 as Child
} from "../preservation/StreamScopedPreservationPolicyReferencePublicationV1.sol";
import {
    StreamScopedPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamScopedPreservationPolicyPublicationRecipeV1.sol";

/// @notice Fixed delegate-host CREATE worker; callers cannot nominate implementation code.
library StreamScopedPreservationPolicyPublicationReferenceDeploymentV1 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return address(new Child(Recipe.referenceDependencies(r, g), r.targets[3], r.referenceGas));
    }
}
