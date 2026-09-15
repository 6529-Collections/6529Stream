// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentGovernanceStagePlan.t.sol";
import "../../script/current/PrepareEntropyProviderLifecycle.s.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import "../../script/current/DevelopmentEntropyProvider.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";

/// @notice Authored operator recipes over the actual foundation, Executor, coordinator and threshold Safe.
/// @dev DevelopmentEntropyProvider is an explicit Anvil adapter, not external VRF/randomness evidence.
contract StreamCurrentEntropyLifecyclePlanTest is StreamCurrentGovernanceStagePlanTest {
    PrepareEntropyProviderLifecycle private preparer;
    StreamEntropyCoordinator private lifecycle;
    DevelopmentEntropyProvider private adapter;
    string private constant REASON = "urn:stream:test:provider-stage";

    function testClassifierPlansAreSeparateDelayedSafeSelfCallsAndResumeIndependently() public {
        _initializeLifecycle();
        PrepareEntropyProviderLifecycle.PreparedStage[] memory stages =
            preparer.prepareAdmissions(configuration.executor, lifecycle, _parameters(1));
        require(
            stages.length == 2 && stages[0].savedPlanHash != stages[1].savedPlanHash,
            "two independent journals"
        );
        StreamGovernanceStagePlan.Plan memory first = _decode(stages[0]);
        StreamGovernanceStagePlan.Plan memory second = _decode(stages[1]);
        _assertClassifier(first, lifecycle.deprecateEntropyProvider.selector);
        _assertClassifier(second, lifecycle.revokeEntropyProvider.selector);
        require(
            first.stage != second.stage && first.scopeHash != second.scopeHash,
            "distinct classifier coordinates"
        );
        _assertAdmission(lifecycle.deprecateEntropyProvider.selector, false);
        _assertAdmission(lifecycle.revokeEntropyProvider.selector, false);
        bytes32 firstId = _schedule(first);
        bytes32 secondId = _schedule(second);
        require(firstId != secondId, "separate confirmed schedule receipts");
        vm.expectRevert();
        this.executeSaved(first, firstId);
        _assertAdmission(lifecycle.deprecateEntropyProvider.selector, false);
        vm.warp(first.notBefore);
        require(this.executeSaved(first, firstId), "first isolated admission");
        _assertAdmission(lifecycle.deprecateEntropyProvider.selector, true);
        _assertAdmission(lifecycle.revokeEntropyProvider.selector, false);
        PrepareEntropyProviderLifecycle.Parameters memory fresh = _parameters(1);
        vm.expectRevert();
        preparer.prepareAdmissions(configuration.executor, lifecycle, fresh);
        PrepareEntropyProviderLifecycle.PreparedStage memory pending = preparer.prepareAdmission(
            configuration.executor, lifecycle, lifecycle.revokeEntropyProvider.selector, fresh
        );
        _assertClassifier(_decode(pending), lifecycle.revokeEntropyProvider.selector);
        require(this.executeSaved(second, secondId), "retained second isolated admission");
        require(
            !this.executeSaved(first, firstId) && !this.executeSaved(second, secondId),
            "completed plans resume as no-ops"
        );
        _assertAdmission(lifecycle.revokeEntropyProvider.selector, true);
        require(lifecycle.entropyProviderCount() == 0, "classifier is not provider activation");
    }

    function testProviderPlansUseCanonicalHashesClassesAndActualLifecycleReadbacks() public {
        _initializeLifecycle();
        StreamGovernanceStagePlan.Plan memory activation = _transition(EntropyProviderState.ACTIVE);
        _assertTransition(activation, EntropyProviderState.ACTIVE, 1);
        bytes32 activeId = _schedule(activation);
        vm.expectRevert();
        this.executeSaved(activation, activeId);
        require(lifecycle.entropyProviderCount() == 0, "delay failure preserves unknown provider");
        vm.warp(activation.notBefore);
        require(this.executeSaved(activation, activeId), "actual delayed provider activation");
        _assertProvider(EntropyProviderState.ACTIVE, 1, activeId);
        PrepareEntropyProviderLifecycle.Parameters memory immediate = _parameters(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareEntropyProviderLifecycle.ProviderTighteningNotAdmitted.selector,
                lifecycle.deprecateEntropyProvider.selector
            )
        );
        preparer.prepareTransition(
            configuration.executor,
            lifecycle,
            address(adapter),
            EntropyProviderState.DEPRECATED,
            immediate
        );
        _admitClassifiers();
        bytes32 deprecatedId = _executeTransition(EntropyProviderState.DEPRECATED, 0);
        _assertProvider(EntropyProviderState.DEPRECATED, 2, deprecatedId);
        bytes32 revokedId = _executeTransition(EntropyProviderState.INCIDENT_REVOKED, 0);
        _assertProvider(EntropyProviderState.INCIDENT_REVOKED, 3, revokedId);
        bytes32 restoredId = _executeTransition(EntropyProviderState.ACTIVE, 1);
        _assertProvider(EntropyProviderState.ACTIVE, 4, restoredId);
        require(
            lifecycle.entropyProviderCount() == 1
                && lifecycle.entropyProviderAt(0) == address(adapter),
            "restoration retains original enumeration"
        );
        require(
            !lifecycle.providerRevoked(address(adapter)),
            "legacy disclosure follows current restoration"
        );
    }

    function testChangedSavedClassifierIsRejectedThenIdenticalOriginalPlanExecutes() public {
        _initializeLifecycle();
        PrepareEntropyProviderLifecycle.PreparedStage memory saved = preparer.prepareAdmission(
            configuration.executor,
            lifecycle,
            lifecycle.deprecateEntropyProvider.selector,
            _parameters(1)
        );
        StreamGovernanceStagePlan.Plan memory plan = _decode(saved);
        bytes32 id = _schedule(plan);
        plan.batch.callDatas[0] = abi.encodeCall(
            configuration.executor.setTighteningCall,
            (address(lifecycle), lifecycle.revokeEntropyProvider.selector, true)
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamGovernanceStagePlan.StageJournalMismatch.selector)
        );
        this.executeSaved(plan, id);
        _assertAdmission(lifecycle.deprecateEntropyProvider.selector, false);
        _assertAdmission(lifecycle.revokeEntropyProvider.selector, false);
        plan = _decode(saved);
        vm.warp(plan.notBefore);
        require(this.executeSaved(plan, id), "original saved hash and calldata retry");
        _assertAdmission(lifecycle.deprecateEntropyProvider.selector, true);
        _assertAdmission(lifecycle.revokeEntropyProvider.selector, false);
    }

    function testObservedProviderDriftRejectsOldStageAndRequiresFreshTransition() public {
        _initializeLifecycle();
        _executeTransition(EntropyProviderState.ACTIVE, 1);
        _admitClassifiers();
        StreamGovernanceStagePlan.Plan memory stale =
            _transition(EntropyProviderState.INCIDENT_REVOKED);
        bytes32 staleId = _schedule(stale);
        bytes32 deprecatedId = _executeTransition(EntropyProviderState.DEPRECATED, 0);
        _assertProvider(EntropyProviderState.DEPRECATED, 2, deprecatedId);
        vm.expectRevert();
        this.executeSaved(stale, staleId);
        _assertProvider(EntropyProviderState.DEPRECATED, 2, deprecatedId);
        require(
            this.verifySaved(stale, staleId) == GovernanceActionStatus.SCHEDULED,
            "failed execution keeps original attempt"
        );
        StreamGovernanceStagePlan.Plan memory fresh =
            _transition(EntropyProviderState.INCIDENT_REVOKED);
        require(
            fresh.oldValueHash != stale.oldValueHash && fresh.newValueHash != stale.newValueHash,
            "new observed provider revision"
        );
        bytes32 freshId = _schedule(fresh);
        vm.warp(fresh.notBefore);
        require(this.executeSaved(fresh, freshId), "new separately approved exact state");
        _assertProvider(EntropyProviderState.INCIDENT_REVOKED, 3, freshId);
    }

    function testPreparationRejectsForeignAuthorityUnsupportedSelectorAndConsumedTransition()
        public
    {
        _initializeLifecycle();
        PrepareEntropyProviderLifecycle.Parameters memory parameters = _parameters(1);
        StreamGovernanceExecutor foreign = new StreamGovernanceExecutor(address(this));
        vm.expectRevert(
            abi.encodeWithSelector(
                PrepareEntropyProviderLifecycle.InvalidEntropyLifecycleDependency.selector
            )
        );
        preparer.prepareAdmissions(foreign, lifecycle, parameters);
        vm.expectRevert();
        preparer.prepareAdmission(
            configuration.executor,
            lifecycle,
            lifecycle.activateEntropyProvider.selector,
            parameters
        );
        _executeTransition(EntropyProviderState.ACTIVE, 1);
        parameters = _parameters(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamEntropyProviderLifecycle.InvalidProviderTransition.selector,
                address(adapter),
                EntropyProviderState.ACTIVE,
                EntropyProviderState.ACTIVE
            )
        );
        preparer.prepareTransition(
            configuration.executor,
            lifecycle,
            address(adapter),
            EntropyProviderState.ACTIVE,
            parameters
        );
        require(
            lifecycle.entropyProviderRecord(address(adapter)).revision == 1,
            "invalid preparations have no writes"
        );
    }

    function _initializeLifecycle() private {
        _initialize();
        preparer = new PrepareEntropyProviderLifecycle();
        IStreamTimeParameterHost.TimeParameterConfig[3] memory times;
        times[0] = IStreamTimeParameterHost.TimeParameterConfig(
            "ENTROPY_REQUEST_TIMEOUT_BLOCKS", 10, 5, 60
        );
        times[1] =
            IStreamTimeParameterHost.TimeParameterConfig("ENTROPY_REVEAL_SLO_BLOCKS", 10, 5, 60);
        times[2] = IStreamTimeParameterHost.TimeParameterConfig(
            "ENTROPY_RECOVERY_STEP_DELAY_BLOCKS", 10, 5, 60
        );
        lifecycle = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(configuration.core),
                address(configuration.executor),
                address(configuration.roles),
                times,
                configuration.deploymentHash,
                REASON,
                keccak256("provider lifecycle operator fixture")
            )
        );
        adapter = new DevelopmentEntropyProvider(address(lifecycle), address(this));
        _admitCatalog();
    }

    function _parameters(uint8 actionClass)
        private
        view
        returns (PrepareEntropyProviderLifecycle.Parameters memory)
    {
        uint64 ready = uint64(
            block.timestamp + configuration.executor.minimumDelay(actionClass) + 1 hours
        );
        return PrepareEntropyProviderLifecycle.Parameters(
            ready, ready + 7 days, keccak256(bytes(REASON)), REASON, configuration.deploymentHash
        );
    }

    function _decode(PrepareEntropyProviderLifecycle.PreparedStage memory saved)
        private
        view
        returns (StreamGovernanceStagePlan.Plan memory plan)
    {
        plan = abi.decode(saved.encodedPlan, (StreamGovernanceStagePlan.Plan));
        require(
            saved.schemaVersion == 2 && saved.savedPlanHash == keccak256(saved.encodedPlan),
            "saved original encoding"
        );
        require(
            StreamGovernanceStagePlan.planHash(plan) == saved.savedPlanHash,
            "independent journal hash"
        );
        StreamGovernanceStagePlan.NextCall memory publication =
            StreamGovernanceStagePlan.publication(plan, saved.savedPlanHash);
        require(
            keccak256(abi.encode(publication)) == keccak256(abi.encode(saved.publication)),
            "publication exact"
        );
        // Encode independently without reopening a now-elapsed scheduling window.
        bytes memory expectedScheduling = abi.encodeCall(
            IStreamGovernanceExecutor.scheduleGovernanceBatch,
            (
                plan.batch.actionClass,
                plan.batch.calls,
                plan.scopeHash,
                plan.oldValueHash,
                plan.newValueHash,
                plan.notBefore,
                plan.expiresAfter,
                plan.reasonHash,
                plan.reasonURI,
                plan.manifestHash
            )
        );
        require(
            keccak256(saved.scheduling.data) == keccak256(expectedScheduling),
            "exact returned Safe scheduling calldata"
        );
        require(
            saved.scheduling.caller == address(governor)
                && saved.scheduling.target == address(configuration.executor)
                && saved.scheduling.value == 0 && saved.publication.caller == address(0),
            "actual Safe caller, zero-value CALL"
        );
    }

    function _assertClassifier(StreamGovernanceStagePlan.Plan memory plan, bytes4 selector)
        private
        view
    {
        require(
            plan.batch.actionClass == 1 && plan.batch.calls.length == 1
                && plan.batch.callDatas.length == 1,
            "isolated ordinary action"
        );
        GovernanceCall memory call_ = plan.batch.calls[0];
        require(
            call_.target == address(configuration.executor)
                && call_.selector == configuration.executor.setTighteningCall.selector
                && call_.value == 0,
            "Executor self-call only"
        );
        require(
            keccak256(plan.batch.callDatas[0])
                == keccak256(
                    abi.encodeCall(
                        configuration.executor.setTighteningCall,
                        (address(lifecycle), selector, true)
                    )
                ),
            "exact classifier calldata"
        );
        require(
            plan.notBefore >= block.timestamp + configuration.executor.minimumDelay(1),
            "ordinary admission delay"
        );
    }

    function _assertAdmission(bytes4 selector, bool expected) private view {
        (bool enabled, bytes32 hash, uint64 revision,) =
            configuration.executor.tighteningCallConfig(address(lifecycle), selector);
        require(enabled == expected, "observed classifier state");
        if (expected) {
            require(
                hash == address(lifecycle).codehash && revision == 1,
                "exact retained code and revision"
            );
        } else {
            require(revision == 0, "unmodified classifier");
        }
    }

    function _admitClassifiers() private {
        PrepareEntropyProviderLifecycle.PreparedStage[] memory stages =
            preparer.prepareAdmissions(configuration.executor, lifecycle, _parameters(1));
        StreamGovernanceStagePlan.Plan memory first = _decode(stages[0]);
        StreamGovernanceStagePlan.Plan memory second = _decode(stages[1]);
        bytes32 a = _schedule(first);
        bytes32 b = _schedule(second);
        vm.warp(first.notBefore);
        require(
            this.executeSaved(first, a) && this.executeSaved(second, b),
            "both independently delayed actions"
        );
    }

    function _transition(EntropyProviderState next)
        private
        view
        returns (StreamGovernanceStagePlan.Plan memory)
    {
        return _decode(
            preparer.prepareTransition(
                configuration.executor,
                lifecycle,
                address(adapter),
                next,
                _parameters(next == EntropyProviderState.ACTIVE ? 1 : 0)
            )
        );
    }

    function _assertTransition(
        StreamGovernanceStagePlan.Plan memory plan,
        EntropyProviderState next,
        uint8 cls
    ) private view {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 expectedClass) =
            lifecycle.entropyProviderTransition(address(adapter), next, REASON);
        require(
            cls == expectedClass && plan.batch.actionClass == cls && plan.batch.calls.length == 1,
            "canonical transition class"
        );
        GovernanceCall memory call_ = plan.batch.calls[0];
        require(
            call_.target == address(lifecycle) && call_.scopeHash == scope
                && call_.oldValueHash == oldHash && call_.newValueHash == newHash
                && plan.scopeHash == scope && plan.oldValueHash == oldHash
                && plan.newValueHash == newHash,
            "original actual provider commitments"
        );
        bytes memory data = next == EntropyProviderState.ACTIVE
            ? abi.encodeCall(lifecycle.activateEntropyProvider, (address(adapter), REASON))
            : next == EntropyProviderState.DEPRECATED
                ? abi.encodeCall(lifecycle.deprecateEntropyProvider, (address(adapter), REASON))
                : abi.encodeCall(lifecycle.revokeEntropyProvider, (address(adapter), REASON));
        require(keccak256(plan.batch.callDatas[0]) == keccak256(data), "exact provider and reason");
    }

    function _executeTransition(EntropyProviderState next, uint8 cls) private returns (bytes32 id) {
        StreamGovernanceStagePlan.Plan memory plan = _transition(next);
        _assertTransition(plan, next, cls);
        id = _schedule(plan);
        vm.warp(plan.notBefore);
        require(this.executeSaved(plan, id), "actual saved provider action executes");
    }

    function _assertProvider(EntropyProviderState state, uint64 revision, bytes32 id) private view {
        IStreamEntropyProviderLifecycle.ProviderRecord memory record =
            lifecycle.entropyProviderRecord(address(adapter));
        require(
            record.state == state && record.revision == revision
                && record.runtimeCodeHash == address(adapter).codehash && record.lastActionId == id
                && record.reasonHash == keccak256(bytes(REASON)),
            "full actual provider record"
        );
    }

    function _admitCatalog() private {
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](4);
        rows[0] = _row(
            1, address(configuration.executor), configuration.executor.setTighteningCall.selector
        );
        rows[1] = _row(1, address(lifecycle), lifecycle.activateEntropyProvider.selector);
        rows[2] = _row(0, address(lifecycle), lifecycle.deprecateEntropyProvider.selector);
        rows[3] = _row(0, address(lifecycle), lifecycle.revokeEntropyProvider.selector);
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(configuration.executor, rows);
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(configuration.manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes('{"purpose":"entropy provider operator admission"}')
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            REASON,
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (GenesisBatch memory batch, uint256 count) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            configuration.manifest,
            payload,
            update
        );
        require(count == 4, "exact added policy rows");
        StreamGovernanceStagePlan.Plan memory plan =
            _build(keccak256("ENTROPY_LIFECYCLE_CATALOG"), batch);
        bytes32 id = _schedule(plan);
        vm.warp(plan.notBefore);
        require(this.executeSaved(plan, id), "real delayed catalog and manifest publication");
    }

    function _row(uint8 cls, address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            cls,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(configuration.deploymentHash, target)),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function _key(GovernanceActionPolicyEntry memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }
}
