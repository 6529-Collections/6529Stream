// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/interfaces/stream/mint/IStreamMintPhaseFreeze.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamGovernanceExecutor.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import "./StreamCurrentStackPlan.sol";

/// @notice Exact original-governance classifier and terminal-freeze caller plans.
/// @dev Classifier registration is a separate class-0 Executor self-call. The phase
/// transition always uses class2 and the Executor's original 72-hour veto floor.
library StreamMintPhaseFreezePlan {
    error MintPhaseFreezePlanInvalid();

    function classifier(IStreamGovernanceExecutor executor, IStreamMintPhaseFreeze manager)
        internal
        view
        returns (GenesisBatch memory)
    {
        address target = address(manager);
        bytes4 selector = IStreamMintPhaseFreeze.freezePhase.selector;
        (bool enabled,, uint64 revision, bytes32 oldHash) =
            executor.freezeSelectorConfig(target, selector);
        if (enabled || revision == type(uint64).max || target.code.length == 0) {
            revert MintPhaseFreezePlanInvalid();
        }
        bytes32 kind = keccak256("6529STREAM_GOVERNANCE_CONFIG_FREEZE_SELECTOR");
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"),
                block.chainid,
                address(executor),
                kind,
                target,
                selector
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"),
                block.chainid,
                address(executor),
                kind,
                target,
                selector,
                true,
                target.codehash,
                revision + 1
            )
        );
        return _one(
            0,
            address(executor),
            abi.encodeCall(executor.registerFreezeSelector, (target, selector, true)),
            scope,
            oldHash,
            next
        );
    }

    function freeze(IStreamMintPhaseFreeze manager, uint256 collectionId, bytes32 phaseId)
        internal
        view
        returns (GenesisBatch memory)
    {
        if (manager.phaseFrozen(collectionId, phaseId)) {
            revert MintPhaseFreezePlanInvalid();
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            manager.phaseFreezeTransitionHashes(collectionId, phaseId);
        return _one(
            2,
            address(manager),
            abi.encodeCall(manager.freezePhase, (collectionId, phaseId)),
            scope,
            oldHash,
            newHash
        );
    }

    function _one(
        uint8 cls,
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private pure returns (GenesisBatch memory batch) {
        batch.actionClass = cls;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = data;
        batch.calls[0] = StreamCurrentStackPlan.call(target, data, scope, oldHash, newHash);
    }
}
