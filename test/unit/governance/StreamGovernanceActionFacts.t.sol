// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RecoveryGovernanceIntegrationFixture.sol";

/// @notice Actual scheduled/executed action facts with a retained 2,048-byte governance URI.
contract StreamGovernanceActionFactsTest is RecoveryGovernanceIntegrationFixture {
    function _scheduleLongReason(GovernanceCall[] memory calls, bytes[] memory data)
        private
        returns (bytes32 id, uint64 ready)
    {
        StreamGovernanceExecutor executor = configuration.executor;
        executor.publishGovernanceCallData(data);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        ready = uint64(block.timestamp + executor.minimumDelay(2));
        bytes memory tail = new bytes(2041);
        for (uint256 i; i < tail.length; ++i) {
            tail[i] = 0x75;
        }
        bytes memory input = abi.encodeCall(
            executor.scheduleGovernanceBatch,
            (
                uint8(2),
                calls,
                scope,
                oldHash,
                newHash,
                ready,
                ready + 7 days,
                keccak256("reason"),
                string(abi.encodePacked("ipfs://", tail)),
                configuration.deploymentHash
            )
        );
        vm.recordLogs();
        require(
            executeSafe(governor, signers, address(executor), 0, input, 0),
            "Safe schedules long reason"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(id == 0, "one exact event");
                id = logs[i].topics[1];
            }
        }
        require(id != 0, "actual scheduled action");
    }

    function testColdLongReasonCompactFactsAndExecutedState() public {
        _initialize();
        (GovernanceCall[] memory calls, bytes[] memory data) = _recoveryBatch();
        (bytes32 id, uint64 ready) = _scheduleLongReason(calls, data);
        address executor = address(configuration.executor);
        safeVm.cool(executor);
        (bool oldOk,) = executor.staticcall{ gas: 150000 }(
            abi.encodeCall(configuration.executor.governanceAction, (id))
        );
        require(!oldOk, "long full-action cold budget diagnostic");
        safeVm.cool(executor);
        (bool ok, bytes memory output) = executor.staticcall{ gas: 150000 }(
            abi.encodeCall(configuration.executor.governanceActionFacts, (id))
        );
        require(ok && output.length == 160, "compact actual action cold150k");
        IStreamGovernanceActionFacts.ActionFacts memory facts =
            abi.decode(output, (IStreamGovernanceActionFacts.ActionFacts));
        require(
            facts.status == GovernanceActionStatus.SCHEDULED && facts.actionClass == 2
                && facts.callHash == StreamGovernanceBootstrap.governanceCallsHash(calls)
                && facts.notBefore == ready && facts.expiresAfter == ready + 7 days,
            "all five exact facts"
        );
        GovernanceAction memory full = configuration.executor.governanceAction(id);
        require(
            bytes(full.reasonURI).length == 2048 && full.callHash == facts.callHash,
            "full retained reason and call identity"
        );
        fixture.ownerObservation(id, true, ready);
        vm.warp(ready);
        this.executeFoundationBatch(id, calls, data);
        IStreamGovernanceActionFacts.ActionFacts memory afterExecution =
            configuration.executor.governanceActionFacts(id);
        require(afterExecution.status == GovernanceActionStatus.EXECUTED, "current executed state");
        afterExecution.status = GovernanceActionStatus.SCHEDULED;
        require(
            keccak256(abi.encode(afterExecution)) == keccak256(abi.encode(facts)),
            "original batch/time commitments unchanged"
        );
        require(
            executeSafe(
                governor,
                signers,
                executor,
                0,
                abi.encodeCall(configuration.executor.governanceActionFacts, (id)),
                0
            ),
            "Safe exact reader call"
        );
    }

    function testUnknownActionAndAdditiveDiscovery() public view {
        StreamGovernanceExecutor executor = configuration.executor;
        IStreamGovernanceActionFacts.ActionFacts memory unknown =
            executor.governanceActionFacts(keccak256("unknown"));
        require(
            keccak256(abi.encode(unknown)) == keccak256(new bytes(160)), "explicit absent action"
        );
        require(
            executor.supportsInterface(type(IStreamGovernanceActionFacts).interfaceId)
                && executor.supportsInterface(type(IStreamStateExportPublisher).interfaceId)
                && executor.supportsInterface(0x01ffc9a7)
                && !executor.supportsInterface(0xffffffff),
            "original and additive discovery"
        );
    }
}
