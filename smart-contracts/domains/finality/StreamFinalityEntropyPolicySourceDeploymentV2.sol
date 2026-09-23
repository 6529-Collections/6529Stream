// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityEntropyPolicySourceSet.sol";

/// @notice Fixed creation worker; delegate-host CREATE preserves the actual factory identity.
library StreamFinalityEntropyPolicySourceDeploymentV2 {
    function deploy(
        StreamFinalityCoordinatorPolicyReadsV2.Dependencies memory dependencies,
        StreamFinalityScope memory scope,
        bytes32 plan
    ) public returns (address) {
        return address(new StreamFinalityEntropyPolicySourceSet(dependencies, scope, plan));
    }
}
