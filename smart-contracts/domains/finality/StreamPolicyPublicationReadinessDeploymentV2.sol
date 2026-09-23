// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPolicyPublicationGraphTypesV2 as T
} from "../../interfaces/stream/finality/StreamPolicyPublicationGraphTypesV2.sol";
import { StreamTerminalEntropyReadiness as Child } from "./StreamTerminalEntropyReadiness.sol";
import { StreamPolicyPublicationRecipeV2 as Recipe } from "./StreamPolicyPublicationRecipeV2.sol";

/// @notice Fixed delegate-host CREATE worker; callers cannot nominate implementation code.
library StreamPolicyPublicationReadinessDeploymentV2 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return address(
            new Child(
                r.inventory.targets[0],
                r.inventory.targets[4],
                g.sourceSet,
                r.readinessReadGas,
                r.readinessSourceGas
            )
        );
    }
}
