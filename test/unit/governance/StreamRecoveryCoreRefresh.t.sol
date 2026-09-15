// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RecoveryGovernanceIntegrationFixture.sol";
import "../../helpers/RecoveryCoreMintBoundaries.sol";

/// @notice Actual Core nonempty recovery refresh and cutover gate after completed token mints.
/// @dev Mint admission/entropy, original finality, artist and owner evidence remain explicit boundaries.
contract StreamRecoveryCoreRefreshTest is RecoveryGovernanceIntegrationFixture {
    function _mintActualTokens() private {
        RecoveryCoreMintBoundary manager = new RecoveryCoreMintBoundary();
        RecoveryCoreEntropyBoundary entropy =
            new RecoveryCoreEntropyBoundary(address(configuration.core));
        StreamModuleRegistration[] memory registrations = new StreamModuleRegistration[](2);
        registrations[0] = StreamModuleRegistration(
            address(manager),
            keccak256("MINT_MANAGER"),
            keccak256("mint boundary"),
            type(IStreamMintManager).interfaceId,
            500000,
            address(manager).codehash,
            configuration.deploymentHash,
            keccak256("mint boundary manifest"),
            "urn:recovery:mint-boundary"
        );
        registrations[1] = StreamModuleRegistration(
            address(entropy),
            keccak256("ENTROPY_COORDINATOR"),
            keccak256("entropy boundary"),
            type(IStreamEntropyCoordinator).interfaceId,
            500000,
            address(entropy).codehash,
            configuration.deploymentHash,
            keccak256("entropy boundary manifest"),
            "urn:recovery:entropy-boundary"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(configuration.registry, registrations);
        _runBatch(1, calls, data);
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = keccak256("MINT_MANAGER");
        keys[1] = keccak256("ENTROPY_COORDINATOR");
        (GovernanceCall[] memory ptrs, bytes[] memory ptrdata) = StreamCurrentStackPlan.pointerCalls(
            configuration.core, configuration.registry, keys, registrations
        );
        calls = new GovernanceCall[](3);
        data = new bytes[](3);
        calls[0] = ptrs[0];
        calls[1] = ptrs[1];
        data[0] = ptrdata[0];
        data[1] = ptrdata[1];
        StreamSystemManifest.ModuleAddresses memory selected =
        StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules;
        selected.mintManager = address(manager);
        selected.entropyCoordinator = address(entropy);
        (calls[2], data[2]) = _publication(selected, keccak256("actual Core mint prerequisites"));
        _runBatch(3, calls, data);
        calls = new GovernanceCall[](7);
        data = new bytes[](7);
        for (uint256 i; i < 7; ++i) {
            (calls[i], data[i]) =
                StreamCurrentStackPlan.createCollectionCall(configuration.core, i + 1, 2);
        }
        _runBatch(1, calls, data);
        require(
            manager.mint(address(configuration.core), 7, address(0xBEEF)) == 1
                && manager.mint(address(configuration.core), 7, address(0xBEEF)) == 2,
            "actual completed Core mint IDs"
        );
        require(
            configuration.core.lastAllocatedTokenId() == 2 && entropy.callbacks() == 2
                && configuration.core.tokenLifecycle(1) == 2
                && configuration.core.tokenLifecycle(2) == 2
                && configuration.core.ownerOf(1) == address(0xBEEF)
                && configuration.core.ownerOf(2) == address(0xBEEF),
            "actual identity/ownership/lifecycle/highwater"
        );
    }

    function _assertRefreshLogs(Vm.Log[] memory logs, bytes32 id, bytes32 manifest) private view {
        uint256 batchCount;
        uint256 reasonCount;
        uint256 progressCount;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory item = logs[i];
            if (
                item.emitter == address(configuration.core)
                    && item.topics[0] == keccak256("BatchMetadataUpdate(uint256,uint256)")
            ) {
                require(
                    item.topics.length == 1
                        && keccak256(item.data) == keccak256(abi.encode(uint256(1), uint256(2))),
                    "exact actual Core inclusive range"
                );
                ++batchCount;
            }
            if (
                item.emitter == address(configuration.core)
                    && item.topics[0]
                        == keccak256("StreamMetadataRefresh(uint16,bytes32,uint256,uint256)")
            ) {
                require(
                    item.topics.length == 4 && item.topics[1] == manifest
                        && item.topics[2] == bytes32(uint256(1))
                        && item.topics[3] == bytes32(uint256(2))
                        && keccak256(item.data) == keccak256(abi.encode(uint16(1))),
                    "exact actual Core reason/schema/indexes"
                );
                ++reasonCount;
            }
            if (
                item.emitter == address(first)
                    && item.topics[0]
                        == keccak256(
                            "FinalityRecoveryRefreshProgress(uint16,uint256,bytes32,bytes32,uint256,uint256,uint256,uint256,bool)"
                        )
            ) {
                require(
                    item.topics.length == 4 && item.topics[1] == bytes32(uint256(7))
                        && item.topics[2] == id && item.topics[3] == manifest
                        && keccak256(item.data)
                            == keccak256(
                                abi.encode(
                                    uint16(1), uint256(1), uint256(2), uint256(2), uint256(1), true
                                )
                            ),
                    "exact companion progress and indexes"
                );
                ++progressCount;
            }
        }
        require(
            batchCount == 1 && reasonCount == 1 && progressCount == 1,
            "one actual Core range and one companion progress"
        );
    }

    function testActualRecoveryNonemptyCoreRefreshAndIncompleteCutoverRetry() public {
        _initialize();
        _mintActualTokens();
        (GovernanceCall[] memory calls, bytes[] memory data) = _recoveryBatch();
        (bytes32 id, uint64 ready) = this.scheduleFoundationBatch(2, calls, data);
        fixture.ownerObservation(id, true, ready);
        vm.warp(ready);
        this.executeFoundationBatch(id, calls, data);
        StreamFinalityRecoveryRequest memory request = fixture.requestFacts();
        StreamFinalityRecoveryRefreshPlan memory plan = first.finalityRecoveryRefreshPlan(id);
        require(
            plan.exists && !plan.complete && !plan.superseded
                && plan.lastAllocatedTokenIdAtExecution == 2 && plan.rangeStart == 1
                && plan.rangeEnd == 2 && plan.processedThrough == 0 && plan.chunksEmitted == 0
                && first.incompleteFinalityRecoveryRefreshPlanCount() == 1,
            "actual nonempty plan snapshot"
        );
        StreamFinalityScope memory tokenScope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 7, 1, 0);
        (bool pinned, bool matches,, bytes32 inheritedId) =
            first.finalityRecoveryRouteStatus(request.replacementRoute.componentType, tokenScope);
        require(
            pinned && matches && inheritedId == id,
            "actual completed token inherits recovered collection route"
        );
        (calls, data) = _selection(address(second), address(first));
        (bytes32 cutoverId, uint64 cutoverReady) = this.scheduleFoundationBatch(3, calls, data);
        vm.warp(cutoverReady);
        uint256 nonce = governor.nonce();
        vm.expectRevert();
        this.executeFoundationBatch(cutoverId, calls, data);
        require(
            _selected() == address(first) && governor.nonce() == nonce
                && configuration.executor.governanceAction(cutoverId).status
                    == GovernanceActionStatus.SCHEDULED
                && first.incompleteFinalityRecoveryRefreshPlanCount() == 1,
            "actual incomplete assertion rolls Safe/action/pointer back"
        );
        vm.expectRevert();
        configuration.core.emitBatchMetadataUpdate(1, 2, request.recoveryManifest.contentHash);
        vm.recordLogs();
        require(
            executeSafe(
                governor,
                signers,
                address(first),
                0,
                abi.encodeCall(first.continueFinalityRecoveryRefresh, (request.scope, id)),
                0
            ),
            "permissionless actual Safe continuation"
        );
        _assertRefreshLogs(vm.getRecordedLogs(), id, request.recoveryManifest.contentHash);
        plan = first.finalityRecoveryRefreshPlan(id);
        require(
            plan.complete && plan.processedThrough == 2 && plan.chunksEmitted == 1
                && first.incompleteFinalityRecoveryRefreshPlanCount() == 0,
            "actual Core refresh completes count/cursor"
        );
        this.executeFoundationBatch(cutoverId, calls, data);
        require(
            _selected() == address(second)
                && configuration.executor.governanceAction(cutoverId).status
                    == GovernanceActionStatus.EXECUTED && first.finalityRecoveryRecord(id).executed,
            "same cutover action succeeds after actual refresh"
        );
    }
}
