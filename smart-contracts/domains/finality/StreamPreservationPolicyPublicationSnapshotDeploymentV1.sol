// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamPreservationPolicySnapshotPublicationV1 as Child
} from "../metadata/StreamPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamPreservationPolicyPublicationRecipeV1 as Recipe
} from "./StreamPreservationPolicyPublicationRecipeV1.sol";

/// @notice Fixed delegate-host CREATE worker; callers cannot nominate implementation code.
library StreamPreservationPolicyPublicationSnapshotDeploymentV1 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return address(new Child(Recipe.snapshot(r, g), r.targets[3], r.snapshotGas));
    }
}
