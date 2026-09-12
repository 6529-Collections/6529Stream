// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";

/// @notice Exercise catalog evolution with the real current Core and SystemManifest.
contract StreamCurrentStackCatalogTest is StreamCurrentStackFixture {
    function setUp() public {
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
    }

    function testReplacementTargetRequiresCatalogAndPublishesRealManifestRevisionTwo() public {
        StreamEntropyCoordinator replacement = _replacement();
        (GovernanceCall[] memory calls, bytes[] memory data) = _configuration(replacement);
        executor.publishGovernanceCallData(data);
        bytes memory unknownTargetRequest = _scheduleData(calls, 1);
        vm.expectRevert();
        governanceRoot.execute(address(executor), 0, unknownTargetRequest);

        (, bytes32 initialCatalog, uint256 initialCount,) = executor.governanceActionPolicyState();
        address initialPayload = manifest.streamSystemManifestPointer();
        (calls, data) = _extension(replacement);
        executor.publishGovernanceCallData(data);
        bytes32 id = _schedule(calls, 3);
        vm.expectRevert();
        executor.executeGovernanceBatch(id, calls, data);
        vm.warp(block.timestamp + 48 hours);
        executor.executeGovernanceBatch(id, calls, data);

        (, bytes32 nextCatalog, uint256 nextCount, uint64 catalogRevision) =
            executor.governanceActionPolicyState();
        require(nextCatalog != initialCatalog && nextCount == initialCount + 1, "catalog append");
        require(catalogRevision == 1, "catalog revision");
        StreamSystemManifest.AggregateState memory state =
            StreamGenesisManifestPlan.readAggregate(manifest);
        require(
            state.revision == 2 && manifest.streamSystemManifestPointerCount() == 2,
            "real publication"
        );
        require(manifest.streamSystemManifestPointer() != initialPayload, "new payload");
        require(
            state.modules.entropyCoordinator == address(entropy),
            "admission does not install pointer"
        );
        require(state.modules.artistRegistry == address(artists), "aggregate preserves artist");

        (calls, data) = _configuration(replacement);
        executor.publishGovernanceCallData(data);
        id = _schedule(calls, 1);
        vm.warp(block.timestamp + 48 hours);
        executor.executeGovernanceBatch(id, calls, data);
        require(replacement.requesters(BUYER), "replacement configured through real governance");
        require(!entropy.requesters(BUYER), "original independent configuration");
    }

    function testInvalidRealManifestTailRollsBackCatalogExtension() public {
        StreamEntropyCoordinator replacement = _replacement();
        (, bytes32 initialCatalog, uint256 initialCount,) = executor.governanceActionPolicyState();
        (GovernanceCall[] memory calls, bytes[] memory data) = _extension(replacement);
        calls[1].oldValueHash = keccak256("stale manifest revision");
        executor.publishGovernanceCallData(data);
        bytes32 id = _schedule(calls, 3);
        vm.warp(block.timestamp + 48 hours);
        vm.expectRevert();
        executor.executeGovernanceBatch(id, calls, data);
        (, bytes32 catalog, uint256 count, uint64 revision) = executor.governanceActionPolicyState();
        require(
            catalog == initialCatalog && count == initialCount && revision == 0, "catalog rollback"
        );
        require(manifest.streamSystemManifestPointerCount() == 1, "publication rollback");
    }

    function _replacement() private returns (StreamEntropyCoordinator) {
        return new StreamEntropyCoordinator(
            address(core),
            address(executor),
            address(roles),
            DEPLOYMENT_HASH,
            "urn:6529stream:fixture:replacement-entropy",
            keccak256("replacement entropy module")
        );
    }

    function _configuration(StreamEntropyCoordinator target)
        private
        view
        returns (GovernanceCall[] memory calls, bytes[] memory data)
    {
        calls = new GovernanceCall[](1);
        data = new bytes[](1);
        data[0] = abi.encodeCall(target.setRequester, (BUYER, true));
        calls[0] = StreamCurrentStackPlan.call(
            address(target),
            data[0],
            keccak256("replacement requester"),
            bytes32(0),
            keccak256(data[0])
        );
    }

    function _extension(StreamEntropyCoordinator replacement)
        private
        returns (GovernanceCall[] memory calls, bytes[] memory data)
    {
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](1);
        additions[0] = GovernanceActionPolicyEntry(
            1,
            address(replacement),
            replacement.setRequester.selector,
            address(replacement).codehash,
            keccak256("replacement entropy"),
            1,
            0,
            0,
            bytes32(0)
        );
        (bytes32 candidate, bytes32 oldCatalog, uint256 count, uint64 revision) =
            executor.governanceActionPolicyState();
        (bytes32 nextCatalog, bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceActionPolicy.extensionTransition(
            address(executor), candidate, oldCatalog, count, revision, additions
        );
        calls = new GovernanceCall[](2);
        data = new bytes[](2);
        data[0] = abi.encodeCall(
            executor.extendGovernanceActionPolicy, (revision, oldCatalog, nextCatalog, additions)
        );
        calls[0] = StreamCurrentStackPlan.call(address(executor), data[0], scope, oldHash, newHash);
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 payloadHash) = StreamGenesisManifestPlan.writePayload(
            abi.encodePacked(
                "{\"version\":2,\"catalog\":\"",
                Strings.toHexString(uint256(nextCatalog), 32),
                "\"}"
            )
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            payloadHash,
            "urn:6529stream:current-stack:catalog-revision-1",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (calls[1], data[1]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, current.modules);
    }

    function _schedule(GovernanceCall[] memory calls, uint8 actionClass) private returns (bytes32) {
        bytes memory request = _scheduleData(calls, actionClass);
        return abi.decode(governanceRoot.execute(address(executor), 0, request), (bytes32));
    }

    function _scheduleData(GovernanceCall[] memory calls, uint8 actionClass)
        private
        view
        returns (bytes memory)
    {
        bytes32 callsHash = StreamGovernanceBootstrap.governanceCallsHash(calls);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            StreamGovernanceBootstrap.deriveBatchTransitionHashes(calls, callsHash);
        uint64 notBefore = uint64(block.timestamp + 48 hours);
        return abi.encodeCall(
            executor.scheduleGovernanceBatch,
            (
                actionClass,
                calls,
                scope,
                oldHash,
                newHash,
                notBefore,
                notBefore + 7 days,
                keccak256("current-stack catalog extension"),
                "urn:6529stream:test:catalog",
                StreamGenesisManifestPlan.readAggregate(manifest).manifestHash
            )
        );
    }
}
