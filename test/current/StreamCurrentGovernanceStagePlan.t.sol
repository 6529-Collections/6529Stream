// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentGovernanceBootstrap.t.sol";
import "../../script/current/StreamGovernanceStagePlan.sol";

/// @notice Saved operator actions execute through a real threshold Safe and actual Executor.
contract StreamCurrentGovernanceStagePlanTest is StreamCurrentGovernanceBootstrapTest {
    mapping(bytes32 => bytes32) private savedPlanHashes;
    function testSavedStageSafeScheduleEarlyFailureExecutionAndResume() public {
        _initialize();
        StreamGovernanceStagePlan.Plan memory p = _collectionPlan();
        bytes32 id = _schedule(p);
        require(p.proposer == address(governor), "Safe is explicit caller");
        require(!configuration.core.collectionExists(1), "schedule is not activation");
        vm.expectRevert();
        this.executeSaved(p, id);
        require(!configuration.core.collectionExists(1), "early execution rolled back");
        vm.warp(p.notBefore);
        require(this.executeSaved(p, id), "execute saved bytes");
        require(configuration.core.collectionExists(1), "actual target readback");
        require(configuration.core.collectionMaxSupply(1) == 10, "exact configured result");
        require(!this.executeSaved(p, id), "already executed resumes without new transaction");
        require(configuration.core.lastAllocatedCollectionId() == 1, "no duplicate collection");
        p.stage = keccak256("false completed stage");
        vm.expectRevert(abi.encodeWithSelector(StreamGovernanceStagePlan.StageJournalMismatch.selector));
        this.executeSaved(p, id);
    }

    function testSavedStageRejectsChangedReasonPayloadProposerAndChain() public {
        _initialize();
        StreamGovernanceStagePlan.Plan memory p = _collectionPlan();
        bytes32 id = _schedule(p);
        bytes memory saved = abi.encode(p);
        p.reasonURI = "urn:changed";
        vm.expectRevert(abi.encodeWithSelector(StreamGovernanceStagePlan.StageJournalMismatch.selector));
        this.verifySaved(p, id);
        p = abi.decode(saved, (StreamGovernanceStagePlan.Plan));
        p.proposer = address(this);
        vm.expectRevert(abi.encodeWithSelector(StreamGovernanceStagePlan.StageJournalMismatch.selector));
        this.verifySaved(p, id);
        p = abi.decode(saved, (StreamGovernanceStagePlan.Plan));
        p.chainId += 1;
        vm.expectRevert(abi.encodeWithSelector(StreamGovernanceStagePlan.StageJournalMismatch.selector));
        this.verifySaved(p, id);
        p = abi.decode(saved, (StreamGovernanceStagePlan.Plan));
        p.batch.callDatas[0] = abi.encodeCall(
            configuration.core.createCollection, (uint8(0), true, uint256(11), uint8(0))
        );
        vm.expectRevert(abi.encodeWithSelector(StreamGovernanceStagePlan.StageJournalMismatch.selector));
        this.verifySaved(p, id);
        require(!configuration.core.collectionExists(1), "changed plan never executed");
    }

    function testSavedStageRequiresFreshScheduleAfterCatalogExtension() public {
        _initialize();
        StreamGovernanceStagePlan.Plan memory stale = _collectionPlan();
        bytes32 staleId = _schedule(stale);
        StreamGovernanceStagePlan.Plan memory extension = _catalogPlan();
        bytes32 extensionId = _schedule(extension);
        vm.warp(extension.notBefore);
        require(this.executeSaved(extension, extensionId), "extension executed");
        vm.expectRevert(abi.encodeWithSelector(StreamGovernanceStagePlan.StageStateChanged.selector));
        this.executeSaved(stale, staleId);
        require(!configuration.core.collectionExists(1), "old epoch cannot mutate target");
        require(
            this.verifySaved(stale, staleId) == GovernanceActionStatus.SCHEDULED,
            "retain stale action as its own attempt"
        );
        StreamGovernanceStagePlan.Plan memory fresh = _collectionPlan();
        require(fresh.catalogRevision == stale.catalogRevision + 1, "fresh observed epoch");
        bytes32 freshId = _schedule(fresh);
        require(freshId != staleId, "new receipt action identity");
        vm.warp(fresh.notBefore);
        require(this.executeSaved(fresh, freshId), "fresh delayed plan executes");
        require(configuration.core.collectionMaxSupply(1) == 10, "target postcondition");
        require(!this.executeSaved(extension, extensionId), "historical executed catalog resumes");
    }

    function testSavedStageSubmissionHeadroomCannotBypassActualDelay() public {
        _initialize();
        StreamGovernanceStagePlan.Plan memory p = _collectionPlan();
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert(abi.encodeWithSelector(StreamGovernanceStagePlan.InvalidStagePlan.selector));
        this.scheduleCall(p);
        require(!configuration.core.collectionExists(1), "expired submission window is not ready");
        StreamGovernanceStagePlan.Plan memory fresh = _collectionPlan();
        require(fresh.notBefore > p.notBefore, "replanning preserves delay");
        require(configuration.executor.minimumDelay(1) == 48 hours, "ordinary floor");
        require(configuration.executor.minimumDelay(3) == 48 hours, "catalog floor");
        require(configuration.executor.minimumDelay(2) == 72 hours, "terminal floor");
    }

    function testDeploymentStageRejectsNativeValueBeforeAnyPublication() public {
        _initialize();
        vm.expectRevert(abi.encodeWithSelector(StreamGovernanceStagePlan.InvalidStagePlan.selector));
        this.buildValuePlan();
        require(!configuration.core.collectionExists(1), "unsupported funds stage rejected");
    }

    function buildValuePlan() external view returns (StreamGovernanceStagePlan.Plan memory) {
        StreamGovernanceStagePlan.Plan memory p = _collectionPlan();
        p.batch.calls[0].value = 1;
        return _build(p.stage, p.batch);
    }

    function executeSaved(StreamGovernanceStagePlan.Plan memory p, bytes32 id)
        external returns (bool)
    {
        return StreamGovernanceStagePlan.execute(p, id, savedPlanHashes[id]);
    }

    function verifySaved(StreamGovernanceStagePlan.Plan memory p, bytes32 id)
        external view returns (GovernanceActionStatus)
    {
        return StreamGovernanceStagePlan.verifyAction(p, id, savedPlanHashes[id]);
    }

    function scheduleCall(StreamGovernanceStagePlan.Plan memory p)
        external view returns (StreamGovernanceStagePlan.NextCall memory)
    {
        return StreamGovernanceStagePlan.scheduling(p, StreamGovernanceStagePlan.planHash(p));
    }

    function _initialize() private {
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) = _plan();
        configuration.executor.commitGenesisPlan(configuration.executor.hashGenesisPlan(binding, batches));
        configuration.executor.initializeGenesis(binding, batches);
    }

    function _collectionPlan() private view returns (StreamGovernanceStagePlan.Plan memory) {
        GenesisBatch memory batch;
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        (batch.calls[0], batch.callDatas[0]) =
            StreamCurrentStackPlan.createCollectionCall(configuration.core, 1, 10);
        return _build(keccak256("CREATE_COLLECTION"), batch);
    }

    function _build(bytes32 stage, GenesisBatch memory batch)
        private view returns (StreamGovernanceStagePlan.Plan memory)
    {
        uint64 ready = uint64(block.timestamp + configuration.executor.minimumDelay(batch.actionClass) + 1 hours);
        return StreamGovernanceStagePlan.build(
            configuration.executor, stage, batch, ready, ready + 7 days,
            keccak256("saved stage fixture"), "urn:stream:fixture:saved-stage", configuration.deploymentHash
        );
    }

    function _schedule(StreamGovernanceStagePlan.Plan memory p) private returns (bytes32 id) {
        StreamGovernanceStagePlan.NextCall memory publication = StreamGovernanceStagePlan.publication(p, StreamGovernanceStagePlan.planHash(p));
        require(publication.caller == address(0), "publication is permissionless");
        require(executeSafe(governor, signers, publication.target, publication.value, publication.data, 0), "Safe publication");
        StreamGovernanceStagePlan.NextCall memory call_ = StreamGovernanceStagePlan.scheduling(p, StreamGovernanceStagePlan.planHash(p));
        vm.recordLogs();
        require(executeSafe(governor, signers, call_.target, call_.value, call_.data, 0), "Safe scheduling");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == p.executor && logs[i].topics.length == 4 && logs[i].topics[0] == topic) {
                require(id == bytes32(0), "one actual schedule event");
                id = logs[i].topics[1];
            }
        }
        savedPlanHashes[id] = StreamGovernanceStagePlan.planHash(p);
        require(StreamGovernanceStagePlan.verifyAction(p, id, savedPlanHashes[id]) == GovernanceActionStatus.SCHEDULED, "exact receipt readback");
    }

    function _catalogPlan() private returns (StreamGovernanceStagePlan.Plan memory) {
        StreamGovernanceExecutor executor = configuration.executor;
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1, address(configuration.core), configuration.core.setCollectionMaxSupply.selector,
            address(configuration.core).codehash,
            keccak256(abi.encode(configuration.deploymentHash, address(configuration.core))),
            1, 0, 0, bytes32(0)
        );
        (bytes32 candidate, bytes32 catalog, uint256 count, uint64 revision) = executor.governanceActionPolicyState();
        (bytes32 next, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            StreamGovernanceActionPolicy.extensionTransition(address(executor), candidate, catalog, count, revision, rows);
        GenesisBatch memory batch;
        batch.actionClass = 3;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        batch.callDatas[0] = abi.encodeCall(executor.extendGovernanceActionPolicy, (revision, catalog, next, rows));
        batch.calls[0] = StreamCurrentStackPlan.call(address(executor), batch.callDatas[0], scope, oldHash, newHash);
        StreamSystemManifest.AggregateState memory current = StreamGenesisManifestPlan.readAggregate(configuration.manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(bytes("{\"purpose\":\"saved stage catalog test\"}"));
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash, "urn:stream:fixture:saved-stage-catalog", current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash, current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash, current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash, current.discovery.reconstructionClientHash
        );
        (batch.calls[1], batch.callDatas[1]) = StreamGenesisManifestPlan.publicationCall(configuration.manifest, payload, update, current.modules);
        return _build(keccak256("CATALOG_EXTENSION"), batch);
    }
}
