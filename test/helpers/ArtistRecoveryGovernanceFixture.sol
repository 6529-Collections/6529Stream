// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../current/StreamCurrentGovernanceBootstrap.t.sol";
import "../../smart-contracts/vendor/openzeppelin/Strings.sol";

/// @dev Exact accepted foundation scheduling/publication helpers without unrelated recovery-companion setup.
abstract contract ArtistRecoveryGovernanceFixture is StreamCurrentGovernanceBootstrapTest {
    function _entry(uint8 class_, address target, bytes4 selector)
        internal
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            class_,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(target, configuration.deploymentHash)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function _key(GovernanceActionPolicyEntry memory e) internal pure returns (bytes32) {
        return keccak256(abi.encode(e.actionClass, e.target, e.selector));
    }

    function _publication(StreamSystemManifest.ModuleAddresses memory modules, bytes32 reason)
        internal
        returns (GovernanceCall memory call_, bytes memory data)
    {
        StreamSystemManifest manifest = configuration.manifest;
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            abi.encodePacked(
                "{\"purpose\":\"staged activation\",\"commitment\":\"",
                Strings.toHexString(uint256(reason), 32),
                "\"}"
            )
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:6529stream:fixture:staged-activation",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        return StreamGenesisManifestPlan.publicationCall(manifest, payload, update, modules);
    }

    function _runBatch(uint8 actionClass, GovernanceCall[] memory calls, bytes[] memory data)
        internal
    {
        (bytes32 id, uint64 ready) = this.scheduleFoundationBatch(actionClass, calls, data);
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        vm.warp(ready);
        this.executeFoundationBatch(id, calls, data);
        GovernanceAction memory action = configuration.executor.governanceAction(id);
        require(
            action.status == GovernanceActionStatus.EXECUTED && action.proposer == address(governor)
                && action.executor == address(governor),
            "real delayed Safe action executed"
        );
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
    }

    function scheduleFoundationBatch(
        uint8 actionClass,
        GovernanceCall[] calldata calls,
        bytes[] calldata data
    ) external returns (bytes32 id, uint64 ready) {
        require(msg.sender == address(this), "test only");
        StreamGovernanceExecutor executor = configuration.executor;
        executor.publishGovernanceCallData(data);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        ready = uint64(block.timestamp + executor.minimumDelay(actionClass));
        vm.recordLogs();
        require(
            executeSafe(
                governor,
                signers,
                address(executor),
                0,
                abi.encodeCall(
                    executor.scheduleGovernanceBatch,
                    (
                        actionClass,
                        calls,
                        scope,
                        oldHash,
                        newHash,
                        ready,
                        ready + 7 days,
                        keccak256("staged products"),
                        "urn:stream:fixture:staged",
                        configuration.deploymentHash
                    )
                ),
                0
            ),
            "Safe schedules actual batch"
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
                require(id == bytes32(0), "one scheduled action");
                id = logs[i].topics[1];
            }
        }
        require(id != bytes32(0), "actual scheduled event");
    }

    function executeFoundationBatch(
        bytes32 id,
        GovernanceCall[] calldata calls,
        bytes[] calldata data
    ) external {
        require(msg.sender == address(this), "test only");
        StreamGovernanceExecutor executor = configuration.executor;
        require(
            executeSafe(
                governor,
                signers,
                address(executor),
                0,
                abi.encodeCall(executor.executeGovernanceBatch, (id, calls, data)),
                0
            ),
            "Safe executes actual batch"
        );
    }
}
