// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamGovernanceExecutor.sol";

/// @notice Exact asset admission request for real current-stack governance scenarios.
library StreamCurrentAssetPolicy {
    function activationRequest(
        StreamAssetPolicyRegistry registry,
        address asset,
        bytes32 policyHash,
        bytes32 manifestHash
    ) internal view returns (GovernanceActionRequest memory request) {
        (bytes32 scope, bytes32 oldState, bytes32 nextState) =
            registry.assetPolicyTransitionHashes(asset, 1, policyHash, 0);
        request = GovernanceActionRequest({
            actionClass: 1,
            target: address(registry),
            value: 0,
            selector: registry.setAssetStatus.selector,
            callData: abi.encodeCall(
                registry.setAssetStatus, (asset, uint8(1), policyHash, uint64(0))
            ),
            scopeHash: scope,
            oldValueHash: oldState,
            newValueHash: nextState,
            notBefore: uint64(block.timestamp + 48 hours),
            expiresAfter: uint64(block.timestamp + 9 days),
            reasonHash: keccak256("current-stack test asset admission"),
            reasonURI: "urn:6529stream:fixture:asset-admission",
            manifestHash: manifestHash
        });
    }
}
