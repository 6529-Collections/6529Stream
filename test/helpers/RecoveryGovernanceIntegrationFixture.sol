// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../current/StreamCurrentGovernanceBootstrap.t.sol";
import "./RecoveryGovernanceCompositionFixture.sol";
import "../../smart-contracts/vendor/openzeppelin/Strings.sol";

/// @notice Actual Core/Executor/ModuleRegistry/SystemManifest/Safe plus recovery companion.
/// @dev Original finality, artist evidence and OwnerRecords notice remain explicit boundaries.
abstract contract RecoveryGovernanceIntegrationFixture is StreamCurrentGovernanceBootstrapTest {
    RecoveryGovernanceCompositionFixture internal fixture;
    StreamArtworkFinalityRecovery internal first;
    StreamArtworkFinalityRecovery internal second;
    bytes32 internal constant KEY = keccak256("ARTWORK_FINALITY_RECOVERY");

    function _initialize() internal {
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) = _plan();
        configuration.executor
            .commitGenesisPlan(configuration.executor.hashGenesisPlan(binding, batches));
        configuration.executor.initializeGenesis(binding, batches);
        fixture = new RecoveryGovernanceCompositionFixture();
        fixture.initialize(
            address(configuration.core),
            address(configuration.executor),
            address(configuration.roles)
        );
        first = fixture.recovery();
        second = fixture.sibling();
        _catalog();
        StreamModuleRegistration[] memory registrations = new StreamModuleRegistration[](3);
        registrations[0] = _record(address(first));
        registrations[1] = _record(address(second));
        registrations[2] = _record(fixture.artistTarget());
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(configuration.registry, registrations);
        _runBatch(1, calls, data);
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = keccak256("ARTIST_REGISTRY");
        StreamModuleRegistration[] memory artistRecord = new StreamModuleRegistration[](1);
        artistRecord[0] = registrations[2];
        (GovernanceCall[] memory ptrs, bytes[] memory ptrdata) = StreamCurrentStackPlan.pointerCalls(
            configuration.core, configuration.registry, keys, artistRecord
        );
        calls = new GovernanceCall[](2);
        data = new bytes[](2);
        calls[0] = ptrs[0];
        data[0] = ptrdata[0];
        StreamSystemManifest.ModuleAddresses memory selectedModules =
        StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules;
        selectedModules.artistRegistry = fixture.artistTarget();
        (calls[1], data[1]) =
            _publication(selectedModules, keccak256("actual artist boundary installation"));
        _runBatch(3, calls, data);
        (calls, data) = _selection(address(first), address(0));
        _runBatch(3, calls, data);
        require(
            address(configuration.executor).code.length <= 24576
                && address(configuration.core).code.length <= 24576
                && address(first).code.length <= 24576 && address(second).code.length <= 24576,
            "actual production runtime sizes"
        );
    }

    function _record(address target) internal view returns (StreamModuleRegistration memory) {
        bool a = target == fixture.artistTarget();
        return StreamModuleRegistration(
            target,
            a ? keccak256("ARTIST_REGISTRY") : first.streamModuleType(),
            a ? keccak256("explicit artist boundary") : first.streamModuleVersion(),
            a ? type(IStreamArtistMintConsent).interfaceId : first.streamModuleInterfaceId(),
            500000,
            target.codehash,
            configuration.deploymentHash,
            a ? keccak256("artist boundary manifest") : keccak256("module bytes"),
            "urn:recovery:composition"
        );
    }

    function _recoveryBatch()
        internal
        view
        returns (GovernanceCall[] memory calls, bytes[] memory data)
    {
        StreamFinalityRecoveryRequest memory r = fixture.requestFacts();
        IStreamArtistRecoveryIntent.Facts memory f = first.requireArtistRecoveryIntent(
            r.scope, r.expectedOriginalFinalityRecordHash, r.recoveryManifest.contentHash
        );
        calls = new GovernanceCall[](2);
        data = new bytes[](2);
        (calls[0], data[0]) = _assertCall(address(first));
        data[1] = abi.encodeCall(first.executeFinalityRecovery, (r));
        calls[1] = StreamCurrentStackPlan.call(
            address(first), data[1], f.scopeHash, f.oldValueHash, f.newValueHash
        );
    }

    function _catalog() internal {
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](6);
        address[2] memory targets = [address(first), address(second)];
        for (uint256 i; i < 2; ++i) {
            additions[i * 3] = _entry(
                2, targets[i], IStreamArtworkFinalityRecovery.executeFinalityRecovery.selector
            );
            additions[i * 3 + 1] = _entry(
                2,
                targets[i],
                IStreamArtworkFinalityRecovery.assertNoIncompleteFinalityRecoveryRefreshPlans
                    .selector
            );
            additions[i * 3 + 2] = _entry(
                3,
                targets[i],
                IStreamArtworkFinalityRecovery.assertNoIncompleteFinalityRecoveryRefreshPlans
                    .selector
            );
        }
        for (uint256 i = 1; i < additions.length; ++i) {
            for (
                uint256 j = i;
                j > 0 && uint256(_key(additions[j])) < uint256(_key(additions[j - 1]));
                --j
            ) {
                (additions[j], additions[j - 1]) = (additions[j - 1], additions[j]);
            }
        }
        StreamGovernanceExecutor executor = configuration.executor;
        (bytes32 candidate, bytes32 catalog, uint256 count, uint64 revision) =
            executor.governanceActionPolicyState();
        (bytes32 next, bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceActionPolicy.extensionTransition(
            address(executor), candidate, catalog, count, revision, additions
        );
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(
            executor.extendGovernanceActionPolicy, (revision, catalog, next, additions)
        );
        calls[0] = StreamCurrentStackPlan.call(address(executor), data[0], scope, oldHash, newHash);
        (calls[1], data[1]) = _publication(
            StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules, next
        );
        _runBatch(3, calls, data);
    }

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

    function _assertCall(address target)
        internal
        pure
        returns (GovernanceCall memory c, bytes memory data)
    {
        data = abi.encodeCall(
            IStreamArtworkFinalityRecovery.assertNoIncompleteFinalityRecoveryRefreshPlans, ()
        );
        c = StreamCurrentStackPlan.call(
            target, data, keccak256(abi.encode(target)), bytes32(0), keccak256(data)
        );
    }

    function _selection(address target, address old)
        internal
        returns (GovernanceCall[] memory calls, bytes[] memory data)
    {
        bytes32[] memory types = new bytes32[](1);
        types[0] = KEY;
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = _record(target);
        (GovernanceCall[] memory ptrs, bytes[] memory ptrdata) = StreamCurrentStackPlan.pointerCalls(
            configuration.core, configuration.registry, types, records
        );
        uint256 offset = old == address(0) ? 0 : 1;
        calls = new GovernanceCall[](offset + 2);
        data = new bytes[](offset + 2);
        if (offset == 1) (calls[0], data[0]) = _assertCall(old);
        calls[offset] = ptrs[0];
        data[offset] = ptrdata[0];
        (calls[offset + 1], data[offset + 1]) = _publication(
            StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules,
            keccak256(abi.encode(target, old))
        );
    }

    function _selected() internal view returns (address) {
        return StreamCurrentStackPlan.readPointer(configuration.core, KEY).target;
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
