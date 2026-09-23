// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../script/current/StreamCurrentStackPlan.sol";
import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import {
    IStreamGovernanceExecutor
} from "../../smart-contracts/interfaces/stream/governance/IStreamGovernanceExecutor.sol";

/// @notice Explicit fixture-only class-2 admission for class-1 genesis manifest tails.
/// @dev Callers execute the returned isolated batch through their actual delayed governor.
/// It does not change the foundation or silently install rules in unrelated commerce tests.
library StreamGenesisManifestTailFixture {
    struct Plan {
        GenesisBatch batch;
        uint64 beforeCount;
        bytes32 beforeChain;
        bytes32 nextChain;
        bytes32 historyHash;
        address target;
        bytes4 selector;
        bytes32 targetCodeHash;
    }

    function plan(IStreamGovernanceExecutor executor, address target, bytes4 selector)
        internal
        view
        returns (Plan memory p)
    {
        p.target = target;
        p.selector = selector;
        p.targetCodeHash = target.codehash;
        uint256 count = executor.systemManifestTailTriggerCount();
        require(count < type(uint64).max && target.code.length != 0, "real fresh trigger");
        p.beforeCount = uint64(count);
        uint64 recorded;
        (p.beforeChain, recorded) = executor.systemManifestTailTriggerChainHash();
        require(recorded == p.beforeCount, "original trigger count and chain");
        p.historyHash = _history(executor, count);
        (
            bool registered,
            bytes32 oldCode,
            uint8 oldMask,
            address tail,
            bytes4 tailSelector,
            bytes32 tailCode
        ) = executor.systemManifestBatchTailRule(target, selector);
        require(!registered && oldCode == 0 && oldMask == 0, "no existing trigger");
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x2c9b0dbea692b77bd1679258ca569c13c24eb261671f5a6b78b9fa59cd29c7f1),
                block.chainid,
                address(executor),
                target,
                selector
            )
        );
        bytes32 previous = keccak256(
            abi.encode(
                bytes32(0xd41313fe7ee9b51221beebf9c314d67aebec3677907eb1365fff4caa4248f493),
                scope,
                false,
                bytes32(0),
                uint8(0),
                p.beforeCount,
                p.beforeChain,
                tail,
                tailSelector,
                tailCode
            )
        );
        bytes32 recordHash = keccak256(
            abi.encode(
                bytes32(0xe52b2b6e65acb1eae2c217c4b26e893c7d0e7f32afc148867b79c133b3a134fa),
                p.beforeCount,
                target,
                selector,
                p.targetCodeHash,
                uint8(2)
            )
        );
        p.nextChain = keccak256(
            abi.encode(
                bytes32(0xdf8c3b0d7ebdd491123b988924db55f8fd11251d7e88e5d76722331928dd4951),
                block.chainid,
                address(executor),
                p.beforeChain,
                recordHash,
                p.beforeCount
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                bytes32(0xd41313fe7ee9b51221beebf9c314d67aebec3677907eb1365fff4caa4248f493),
                scope,
                true,
                p.targetCodeHash,
                uint8(2),
                p.beforeCount + 1,
                p.nextChain,
                tail,
                tailSelector,
                tailCode
            )
        );
        bytes memory data = abi.encodeCall(
            executor.registerSystemManifestTailTrigger, (target, selector, uint8(2))
        );
        p.batch.actionClass = 2;
        p.batch.calls = new GovernanceCall[](1);
        p.batch.callDatas = new bytes[](1);
        p.batch.calls[0] =
            StreamCurrentStackPlan.call(address(executor), data, scope, previous, next);
        p.batch.callDatas[0] = data;
    }

    function assertInstalled(IStreamGovernanceExecutor executor, Plan memory p, address manifest)
        internal
        view
    {
        (bytes32 chain, uint64 count) = executor.systemManifestTailTriggerChainHash();
        require(
            count == p.beforeCount + 1 && chain == p.nextChain
                && executor.systemManifestTailTriggerCount() == count
                && _history(executor, p.beforeCount) == p.historyHash,
            "one exact trigger append"
        );
        (address target, bytes4 selector, bytes32 codeHash, uint8 mask) =
            executor.systemManifestTailTriggerAt(p.beforeCount);
        require(
            target == p.target && selector == p.selector && codeHash == p.targetCodeHash
                && codeHash == target.codehash && mask == 2,
            "exact original class-1 trigger"
        );
        (
            bool registered,
            bytes32 ruleCode,
            uint8 ruleMask,
            address tail,
            bytes4 tailSelector,
            bytes32 tailCode
        ) = executor.systemManifestBatchTailRule(p.target, p.selector);
        require(
            registered && ruleCode == p.targetCodeHash && ruleMask == 2 && tail == manifest
                && tailSelector == bytes4(0x09b1b5c6) && tailCode == manifest.codehash,
            "original system manifest tail rule"
        );
    }

    function _history(IStreamGovernanceExecutor executor, uint256 count)
        private
        view
        returns (bytes32 result)
    {
        for (uint256 i; i < count; ++i) {
            (address target, bytes4 selector, bytes32 codeHash, uint8 mask) =
                executor.systemManifestTailTriggerAt(i);
            result = keccak256(abi.encode(result, i, target, selector, codeHash, mask));
        }
    }
}
