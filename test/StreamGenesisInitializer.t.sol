// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/StreamGovernanceBootstrapHarness.sol";
import "../smart-contracts/interfaces/stream/IStreamGenesisInitializer.sol";
import "../script/current/StreamGenesisManifestPlan.sol";

contract GenesisConfiguredTarget {
    IStreamGovernanceExecutor private immutable executor;
    uint256 public value;

    constructor(IStreamGovernanceExecutor executor_) {
        executor = executor_;
    }

    function configure(uint256 nextValue) external {
        require(msg.sender == address(executor), "executor authority");
        (
            bool executing,
            bytes32 actionId,
            uint8 actionClass,
            bytes32 scope,
            bytes32 oldHash,
            bytes32 newHash
        ) = executor.currentAction();
        require(executing && actionId != bytes32(0) && actionClass == 1, "actual governance action");
        require(
            scope == keccak256("genesis-product") && oldHash == keccak256(abi.encode(value))
                && newHash == keccak256(abi.encode(nextValue)),
            "exact transition"
        );
        value = nextValue;
    }
}

/// @notice Isolates the one-time initializer against the existing bootstrap
///         fixture; current-stack tests separately use the actual Core/registry.
contract StreamGenesisInitializerTest is StreamGovernanceBootstrapHarness {
    SystemManifestBootstrapBinding private _binding;
    uint256 private _unboundSnapshot;
    GenesisConfiguredTarget private configuredTarget;

    function _additionalActionPolicies(BootstrapArtifacts memory artifacts)
        internal
        override
        returns (GovernanceActionPolicyEntry[] memory entries)
    {
        configuredTarget = new GenesisConfiguredTarget(artifacts.executor);
        entries = new GovernanceActionPolicyEntry[](1);
        entries[0] = _zeroPolicy(
            1,
            address(configuredTarget),
            configuredTarget.configure.selector,
            keccak256("GENESIS_PRODUCT")
        );
    }

    function _bindExecutorForFixture(
        StreamGovernanceExecutor executor,
        SystemManifestBootstrapBinding memory binding
    ) internal override {
        _binding = binding;
        _unboundSnapshot = vm.snapshotState();
        super._bindExecutorForFixture(executor, binding);
    }

    function _fixture()
        private
        returns (BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches)
    {
        artifacts = _deployBoundBootstrap(address(this));
        // Retain the reference fixture's exact binding commitments, then return
        // its actual Executor and RoleRegistry to the pre-bind deployment state.
        uint256 snapshot = _unboundSnapshot;
        require(vm.revertToState(snapshot), "restore unbound deployment");
        batches = new GenesisBatch[](1);
        (batches[0].calls, batches[0].callDatas) = _bootstrapSealCalls(artifacts);
        batches[0].actionClass = StreamGovernanceActionClasses.POINTER_REPLACEMENT;
    }

    function _commit(BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) private {
        bytes32 planHash = artifacts.executor.hashGenesisPlan(_binding, batches);
        vm.prank(artifacts.bootstrapAuthority);
        artifacts.executor.commitGenesisPlan(planHash);
    }

    function _initialize(BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches)
        private
    {
        vm.prank(artifacts.bootstrapAuthority);
        artifacts.executor.initializeGenesis(_binding, batches);
    }

    function _prepare(BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) private {
        vm.prank(artifacts.bootstrapAuthority);
        artifacts.executor.prepareGenesis(_binding, batches);
    }

    function testPreparedGenesisUsesSamePlanAndSealsWithoutOrdinaryActions() public {
        (BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) = _fixture();
        _commit(artifacts, batches);
        _prepare(artifacts, batches);
        require(!artifacts.executor.genesisInitialized(), "preparation is not initialization");
        require(artifacts.executor.governanceNonce() == 0, "no product action in preparation");
        require(artifacts.manifest.streamSystemManifestPointerCount() == 0, "not published before seal");
        vm.expectRevert(abi.encodeWithSelector(IStreamGenesisInitializer.GenesisPreparationAlreadyBound.selector));
        _prepare(artifacts, batches);
        _initialize(artifacts, batches);
        require(artifacts.executor.genesisInitialized() && artifacts.executor.owner() == address(this), "final runtime authority");
        require(artifacts.manifest.streamSystemManifestPointerCount() == 1, "sealed publication");
        vm.expectRevert(abi.encodeWithSelector(IStreamGenesisInitializer.GenesisAlreadyInitialized.selector));
        _prepare(artifacts, batches);
    }

    function testPreparationRequiresAuthorityAndExactFullCommittedPlan() public {
        (BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) = _fixture();
        _commit(artifacts, batches);
        vm.expectRevert(abi.encodeWithSelector(IStreamGovernanceExecutor.GenesisBootstrapActorRequired.selector, address(this)));
        artifacts.executor.prepareGenesis(_binding, batches);
        batches[0].callDatas[0] = abi.encodePacked(batches[0].callDatas[0], bytes1(0x01));
        bytes32 expected = artifacts.executor.genesisPlanHash();
        bytes32 actual = artifacts.executor.hashGenesisPlan(_binding, batches);
        vm.expectRevert(abi.encodeWithSelector(IStreamGenesisInitializer.GenesisPlanHashMismatch.selector, expected, actual));
        _prepare(artifacts, batches);
    }

    function testPreparedPlanCannotRunOrdinaryPreSealActions() public {
        (BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) = _fixture();
        _commit(artifacts, batches);
        _prepare(artifacts, batches);
        GovernanceActionRequest memory request = GovernanceActionRequest({
            actionClass: 1, target: address(artifacts.trigger), value: 0,
            selector: artifacts.trigger.bootstrapWrite.selector,
            callData: abi.encodeCall(artifacts.trigger.bootstrapWrite, (7)),
            scopeHash: keccak256("scope"), oldValueHash: keccak256("old"), newValueHash: keccak256("new"),
            notBefore: uint64(block.timestamp + 48 hours), expiresAfter: uint64(block.timestamp + 9 days),
            reasonHash: keccak256("test"), reasonURI: "test", manifestHash: artifacts.manifestHash
        });
        vm.expectRevert(abi.encodeWithSelector(IStreamGenesisInitializer.InvalidGenesisPlan.selector));
        vm.prank(artifacts.bootstrapAuthority);
        artifacts.executor.scheduleGovernanceAction(request);
        _initialize(artifacts, batches);
    }

    function testPreparedInitializationFailureCanRetryWithoutPartialProductState() public {
        (BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) = _fixture();
        _commit(artifacts, batches);
        _prepare(artifacts, batches);
        uint256 guardianCount = artifacts.roleRegistry.roleHolderCount(keccak256("ROLE_TERMINAL_FREEZE_VETO"));
        artifacts.manifest.setFailPublication(true);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "publication failed"));
        _initialize(artifacts, batches);
        require(!artifacts.executor.genesisInitialized() && artifacts.executor.governanceNonce() == 0, "failed setup rolled back");
        require(artifacts.manifest.streamSystemManifestPointerCount() == 0, "no partial publication");
        require(artifacts.roleRegistry.roleHolderCount(keccak256("ROLE_TERMINAL_FREEZE_VETO")) == guardianCount, "committed preparation remains");
        artifacts.manifest.setFailPublication(false);
        _initialize(artifacts, batches);
        require(artifacts.executor.genesisInitialized(), "exact plan retried");
    }

    function testInitializesAndSealsWithoutTimeWarpAndClosesInitializer() public {
        (BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) = _fixture();
        uint256 beforeTimestamp = block.timestamp;
        _commit(artifacts, batches);
        vm.recordLogs();
        _initialize(artifacts, batches);
        require(block.timestamp == beforeTimestamp, "genesis must not wait");
        require(artifacts.executor.genesisInitialized(), "initializer consumed");
        require(artifacts.executor.owner() == address(this), "final root authority");
        require(artifacts.executor.pendingScheduledActionCount() == 0, "no pending genesis action");
        require(artifacts.executor.governanceNonce() == 1, "real action nonce used");
        (bool executing, bytes32 actionId,,,,) = artifacts.executor.currentAction();
        require(!executing && actionId == bytes32(0), "context cleared");
        require(artifacts.manifest.streamSystemManifestPointerCount() == 1, "real seal publication");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool sawExecution;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(artifacts.executor)
                    && logs[i].topics[0] == keccak256("GenesisInitialized(bytes32,uint256)")
            ) sawExecution = true;
        }
        require(sawExecution, "genesis event");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGenesisInitializer.GenesisAlreadyInitialized.selector)
        );
        _initialize(artifacts, batches);
    }

    function testRejectsUnauthorizedCommitAndInitialization() public {
        (BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) = _fixture();
        bytes32 planHash = artifacts.executor.hashGenesisPlan(_binding, batches);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GenesisBootstrapActorRequired.selector, address(this)
            )
        );
        artifacts.executor.commitGenesisPlan(planHash);
        _commit(artifacts, batches);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GenesisBootstrapActorRequired.selector, address(this)
            )
        );
        artifacts.executor.initializeGenesis(_binding, batches);
    }

    function testPlanIsImmutableAndRejectsChangedCalldata() public {
        (BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) = _fixture();
        _commit(artifacts, batches);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGenesisInitializer.GenesisPlanAlreadyCommitted.selector)
        );
        vm.prank(artifacts.bootstrapAuthority);
        artifacts.executor.commitGenesisPlan(keccak256("replacement"));
        bytes32 expected = artifacts.executor.genesisPlanHash();
        batches[0].callDatas[0] = abi.encodePacked(batches[0].callDatas[0], bytes1(0x01));
        bytes32 actual = artifacts.executor.hashGenesisPlan(_binding, batches);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGenesisInitializer.GenesisPlanHashMismatch.selector, expected, actual
            )
        );
        _initialize(artifacts, batches);
        require(!artifacts.executor.genesisInitialized(), "failed plan not consumed");
    }

    function testPlanCannotEscapeThroughLegacyBootstrapBind() public {
        (BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) = _fixture();
        _commit(artifacts, batches);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGenesisInitializer.GenesisPlanAlreadyCommitted.selector)
        );
        vm.prank(artifacts.bootstrapAuthority);
        artifacts.executor.bindSystemManifestBootstrap(_binding);
    }

    function testPostSealSchedulingStillRequiresOriginalDelay() public {
        (BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) = _fixture();
        _commit(artifacts, batches);
        _initialize(artifacts, batches);
        require(artifacts.executor.minimumDelay(1) == 48 hours, "loosening delay preserved");
        require(artifacts.executor.minimumDelay(2) == 72 hours, "freeze delay preserved");
        GovernanceActionRequest memory request = GovernanceActionRequest({
            actionClass: 1,
            target: address(artifacts.trigger),
            value: 0,
            selector: artifacts.trigger.bootstrapWrite.selector,
            callData: abi.encodeCall(artifacts.trigger.bootstrapWrite, (7)),
            scopeHash: keccak256("scope"),
            oldValueHash: keccak256("old"),
            newValueHash: keccak256("new"),
            notBefore: uint64(block.timestamp),
            expiresAfter: uint64(block.timestamp + 7 days),
            reasonHash: keccak256("test"),
            reasonURI: "test",
            manifestHash: artifacts.manifestHash
        });
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.DelayBelowClassMinimum.selector,
                uint8(1),
                uint64(block.timestamp),
                uint64(block.timestamp + 48 hours)
            )
        );
        artifacts.executor.scheduleGovernanceAction(request);
    }

    function testUnsealedPlanRollsBackEveryCallAndGuardianGrant() public {
        (BootstrapArtifacts memory artifacts,) = _fixture();
        GenesisBatch[] memory batches = new GenesisBatch[](1);
        batches[0].actionClass = 1;
        batches[0].calls = new GovernanceCall[](1);
        batches[0].callDatas = new bytes[](1);
        batches[0].callDatas[0] = abi.encodeCall(artifacts.trigger.bootstrapWrite, (123));
        batches[0].calls[0] = GovernanceCall({
            target: address(artifacts.trigger),
            value: 0,
            selector: artifacts.trigger.bootstrapWrite.selector,
            callDataHash: keccak256(batches[0].callDatas[0]),
            scopeHash: keccak256("scope"),
            oldValueHash: keccak256("old"),
            newValueHash: keccak256("new")
        });
        _commit(artifacts, batches);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGenesisInitializer.GenesisDidNotSeal.selector)
        );
        _initialize(artifacts, batches);
        require(artifacts.trigger.value() == 0, "target write rolled back");
        require(artifacts.executor.governanceNonce() == 0, "action rolled back");
        require(!artifacts.executor.genesisInitialized(), "initializer rolled back");
        require(
            artifacts.roleRegistry.roleHolderCount(keccak256("ROLE_TERMINAL_FREEZE_VETO")) == 0,
            "guardian grants rolled back"
        );
    }

    function testPlannerMatchesBootstrapSealAndVerifiesWrittenPayload() public {
        (BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) = _fixture();
        (GovernanceCall memory planned, bytes memory data) = StreamGenesisManifestPlan.sealCall(
            artifacts.executor, artifacts.bootstrapAuthority, _binding, artifacts.payloadRoot
        );
        require(
            keccak256(abi.encode(planned)) == keccak256(abi.encode(batches[0].calls[0])),
            "seal plan"
        );
        require(keccak256(data) == keccak256(batches[0].callDatas[0]), "seal calldata");
        (address pointer, bytes32 manifestHash) =
            StreamGenesisManifestPlan.writePayload(bytes("{\"profile\":\"development\"}"));
        StreamGovernanceEvidence.verifyManifestPayload(pointer, manifestHash);
    }

    function testCommittedProductSetupUsesCatalogAndActualContextWithoutTailTrigger() public {
        (BootstrapArtifacts memory artifacts, GenesisBatch[] memory seal) = _fixture();
        GenesisBatch[] memory batches = new GenesisBatch[](2);
        batches[0].actionClass = 1;
        batches[0].calls = new GovernanceCall[](1);
        batches[0].callDatas = new bytes[](1);
        batches[0].callDatas[0] = abi.encodeCall(configuredTarget.configure, (77));
        batches[0].calls[0] = GovernanceCall(
            address(configuredTarget),
            0,
            configuredTarget.configure.selector,
            keccak256(batches[0].callDatas[0]),
            keccak256("genesis-product"),
            keccak256(abi.encode(uint256(0))),
            keccak256(abi.encode(uint256(77)))
        );
        batches[1] = seal[0];
        _commit(artifacts, batches);
        _initialize(artifacts, batches);
        require(configuredTarget.value() == 77, "committed product configured");
        require(
            artifacts.executor.governanceNonce() == 2
                && artifacts.executor.owner() == address(this),
            "two real actions then final root"
        );
    }

    function testOrdinaryPreSealSchedulingStillRejectsProductSetupOutsideTriggerSubset() public {
        BootstrapArtifacts memory artifacts = _deployBoundBootstrap(address(this));
        GovernanceActionRequest memory request = GovernanceActionRequest({
            actionClass: 1,
            target: address(configuredTarget),
            value: 0,
            selector: configuredTarget.configure.selector,
            callData: abi.encodeCall(configuredTarget.configure, (77)),
            scopeHash: keccak256("genesis-product"),
            oldValueHash: keccak256(abi.encode(uint256(0))),
            newValueHash: keccak256(abi.encode(uint256(77))),
            notBefore: uint64(block.timestamp + 48 hours),
            expiresAfter: uint64(block.timestamp + 9 days),
            reasonHash: keccak256("test"),
            reasonURI: "test",
            manifestHash: artifacts.manifestHash
        });
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.BootstrapActionNotPermitted.selector)
        );
        vm.prank(artifacts.bootstrapAuthority);
        artifacts.executor.scheduleGovernanceAction(request);
    }

    function testActionReadPreservesDynamicABIAndVirtualExpiry() public {
        (BootstrapArtifacts memory artifacts, GenesisBatch[] memory batches) = _fixture();
        _commit(artifacts, batches);
        _initialize(artifacts, batches);
        GovernanceActionRequest memory request = GovernanceActionRequest({
            actionClass: 1,
            target: address(configuredTarget),
            value: 0,
            selector: configuredTarget.configure.selector,
            callData: abi.encodeCall(configuredTarget.configure, (77)),
            scopeHash: keccak256("genesis-product"),
            oldValueHash: keccak256(abi.encode(uint256(0))),
            newValueHash: keccak256(abi.encode(uint256(77))),
            notBefore: uint64(block.timestamp + 48 hours),
            expiresAfter: uint64(block.timestamp + 9 days),
            reasonHash: keccak256("action-read"),
            reasonURI: "ipfs://action-read/dynamic-uri",
            manifestHash: artifacts.manifestHash
        });
        bytes32 actionId = artifacts.executor.scheduleGovernanceAction(request);
        GovernanceAction memory action = artifacts.executor.governanceAction(actionId);
        require(
            action.status == GovernanceActionStatus.SCHEDULED
                && action.target == address(configuredTarget),
            "scheduled read"
        );
        require(
            keccak256(bytes(action.reasonURI)) == keccak256(bytes(request.reasonURI))
                && action.manifestHash == request.manifestHash,
            "dynamic ABI fields"
        );
        vm.warp(uint256(request.expiresAfter) + 1);
        action = artifacts.executor.governanceAction(actionId);
        require(
            action.status == GovernanceActionStatus.EXPIRED
                && action.expiresAfter == request.expiresAfter,
            "virtual expiry"
        );
    }
}
