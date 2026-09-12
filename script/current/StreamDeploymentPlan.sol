// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGovernanceGenesisPlan.sol";

/// @notice Stateless local planning boundary for the current deployment scripts.
/// @dev Construct before broadcasting and call outside broadcast windows. This helper is
///      never a protocol dependency, catalog target, release module or planned transaction.
contract StreamDeploymentPlan {
    function buildFoundation(
        StreamGovernanceGenesisPlan.Configuration memory configuration,
        address payloadRoot,
        StreamSystemManifestUpdate memory update
    ) external view returns (SystemManifestBootstrapBinding memory, GenesisBatch[] memory) {
        return StreamGovernanceGenesisPlan.build(configuration, payloadRoot, update);
    }

    function catalogAdditions(
        GenesisBatch[] memory prototypes,
        GovernanceActionPolicyEntry[] memory operating,
        GovernanceActionPolicyEntry[] memory foundationPolicies,
        bytes32 deploymentHash
    ) external view returns (GovernanceActionPolicyEntry[] memory rows) {
        GovernanceActionPolicyEntry[] memory allRows =
            _actionPolicies(prototypes, operating, deploymentHash);
        uint256 count;
        for (uint256 i; i < allRows.length; ++i) {
            bool exists;
            for (uint256 j; j < foundationPolicies.length; ++j) {
                if (_policyKey(allRows[i]) != _policyKey(foundationPolicies[j])) continue;
                require(
                    keccak256(abi.encode(allRows[i]))
                        == keccak256(abi.encode(foundationPolicies[j])),
                    "foundation policy cannot be rewritten"
                );
                exists = true;
                break;
            }
            if (!exists) allRows[count++] = allRows[i];
        }
        rows = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            rows[i] = allRows[i];
        }
    }

    function _actionPolicies(
        GenesisBatch[] memory batches,
        GovernanceActionPolicyEntry[] memory operating,
        bytes32 deploymentHash
    ) private view returns (GovernanceActionPolicyEntry[] memory policies) {
        uint256 capacity = operating.length;
        for (uint256 i; i < batches.length; ++i) {
            capacity += batches[i].calls.length;
        }
        GovernanceActionPolicyEntry[] memory candidates =
            new GovernanceActionPolicyEntry[](capacity);
        uint256 count = operating.length;
        for (uint256 i; i < count; ++i) {
            candidates[i] = operating[i];
        }
        for (uint256 i; i < batches.length; ++i) {
            for (uint256 j; j < batches[i].calls.length; ++j) {
                GovernanceCall memory operation = batches[i].calls[j];
                bytes32 key = keccak256(
                    abi.encode(batches[i].actionClass, operation.target, operation.selector)
                );
                bool duplicate;
                for (uint256 k; k < count; ++k) {
                    if (
                        keccak256(
                                abi.encode(
                                    candidates[k].actionClass,
                                    candidates[k].target,
                                    candidates[k].selector
                                )
                            ) == key
                    ) duplicate = true;
                }
                if (!duplicate) {
                    candidates[count++] = GovernanceActionPolicyEntry(
                        batches[i].actionClass,
                        operation.target,
                        operation.selector,
                        operation.target.codehash,
                        keccak256(abi.encode(deploymentHash, operation.target)),
                        1,
                        0,
                        0,
                        bytes32(0)
                    );
                }
            }
        }
        policies = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            policies[i] = candidates[i];
        }
        for (uint256 i = 1; i < count; ++i) {
            for (
                uint256 j = i; j > 0 && _policyKey(policies[j - 1]) > _policyKey(policies[j]); --j) {
                (policies[j - 1], policies[j]) = (policies[j], policies[j - 1]);
            }
        }
    }

    function _policyKey(GovernanceActionPolicyEntry memory policy) private pure returns (bytes32) {
        return keccak256(abi.encode(policy.actionClass, policy.target, policy.selector));
    }
}
