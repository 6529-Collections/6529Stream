// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPolicyPublicationGraphTypesV2 as T
} from "../../interfaces/stream/finality/StreamPolicyPublicationGraphTypesV2.sol";
import {
    StreamPolicyPublicationSnapshotConstructorV2 as Constructor
} from "./StreamPolicyPublicationSnapshotConstructorV2.sol";
import { StreamPolicyPublicationRecipeV2 as Recipe } from "./StreamPolicyPublicationRecipeV2.sol";

/// @notice Fixed delegate-host CREATE worker; callers cannot nominate implementation code.
library StreamPolicyPublicationSnapshotDeploymentV2 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return Constructor.deploy(Recipe.snapshot(r, g), r.targets[3], r.snapshotGas);
    }
}
