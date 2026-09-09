// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/StreamGovernanceBootstrapHarness.sol";
import "../smart-contracts/interfaces/stream/IStreamGenesisInitializer.sol";
import "../script/current/StreamGenesisManifestPlan.sol";

/// @notice Isolates the one-time initializer against the existing bootstrap
///         fixture; current-stack tests separately use the actual Core/registry.
contract StreamGenesisInitializerTest is StreamGovernanceBootstrapHarness {
    SystemManifestBootstrapBinding private _binding;
    uint256 private _unboundSnapshot;

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
}
