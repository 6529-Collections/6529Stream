// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamEntropyProviderLifecycle,
    EntropyProviderState
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";
import {
    IStreamGovernanceExecutor
} from "../../smart-contracts/interfaces/stream/governance/IStreamGovernanceExecutor.sol";
import {
    GenesisBatch,
    GovernanceCall
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import { StreamCurrentStackPlan } from "./StreamCurrentStackPlan.sol";

/// @notice Exact provider admission and isolated delayed classifier plans for current governance.
library StreamEntropyLifecyclePlan {
    function activate(
        IStreamEntropyProviderLifecycle entropy,
        address provider,
        string memory reason
    ) internal view returns (GovernanceCall memory operation, bytes memory data) {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash,) =
            entropy.entropyProviderTransition(provider, EntropyProviderState.ACTIVE, reason);
        data = abi.encodeCall(entropy.activateEntropyProvider, (provider, reason));
        operation = StreamCurrentStackPlan.call(address(entropy), data, scope, oldHash, newHash);
    }

    /// @dev The existing Executor requires classifier writes to be isolated self-calls.
    function admitTightening(IStreamGovernanceExecutor executor, address entropy, bytes4 selector)
        internal
        view
        returns (GenesisBatch memory batch)
    {
        require(
            selector == IStreamEntropyProviderLifecycle.deprecateEntropyProvider.selector
                || selector == IStreamEntropyProviderLifecycle.revokeEntropyProvider.selector,
            "provider tightening selector"
        );
        (bool enabled,, uint64 revision, bytes32 oldHash) =
            executor.tighteningCallConfig(entropy, selector);
        require(!enabled && revision < type(uint64).max, "fresh classifier transition");
        bytes32 kind = keccak256("6529STREAM_GOVERNANCE_CONFIG_TIGHTENING_CALL");
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"),
                block.chainid,
                address(executor),
                kind,
                entropy,
                selector
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"),
                block.chainid,
                address(executor),
                kind,
                entropy,
                selector,
                true,
                entropy.codehash,
                revision + uint64(1)
            )
        );
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = abi.encodeCall(executor.setTighteningCall, (entropy, selector, true));
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(executor), batch.callDatas[0], scope, oldHash, newHash
        );
    }
}
