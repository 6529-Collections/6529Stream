// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPolicyPublicationGraphTypesV2 as T
} from "../../interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamScopedPolicyPublicationSnapshotConstructorV2 as Constructor
} from "./StreamScopedPolicyPublicationSnapshotConstructorV2.sol";
import {
    StreamScopedPolicyPublicationRecipeV2 as Recipe
} from "./StreamScopedPolicyPublicationRecipeV2.sol";

/// @notice Fixed delegate-host CREATE worker; callers cannot nominate implementation code.
library StreamScopedPolicyPublicationSnapshotDeploymentV2 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return Constructor.deploy(Recipe.snapshot(r, g), r.targets[3], r.snapshotGas);
    }
}
