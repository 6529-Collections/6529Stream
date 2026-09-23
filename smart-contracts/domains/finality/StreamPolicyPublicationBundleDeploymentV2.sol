// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPolicyPublicationGraphTypesV2 as T
} from "../../interfaces/stream/finality/StreamPolicyPublicationGraphTypesV2.sol";
import {
    StreamBundleArchiveCoverage as Child
} from "../preservation/StreamBundleArchiveCoverage.sol";
import { StreamPolicyPublicationRecipeV2 as Recipe } from "./StreamPolicyPublicationRecipeV2.sol";

/// @notice Fixed delegate-host CREATE worker; callers cannot nominate implementation code.
library StreamPolicyPublicationBundleDeploymentV2 {
    function deploy(T.Recipe memory r, T.Graph memory g) public returns (address) {
        return address(new Child(Recipe.bundle(r, g)));
    }
}
