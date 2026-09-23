// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../current/StreamCurrentGovernanceBootstrap.t.sol";
import "../../../smart-contracts/domains/governance/StreamGovernanceRecoveryPolicy.sol";
import "../../../smart-contracts/vendor/openzeppelin/Strings.sol";
import {
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @dev Explicit companion boundary: this checks real per-call governance context,
///      but does not implement original-finality, artist, owner notice or route admission.
contract RecoveryCurrentTargetBoundary {
    address public immutable core;
    address public immutable governanceAuthority;
    bool public incomplete;
    uint256 public executionCount;
    bytes32 public executedAction;
    bytes32 public executedRequest;

    constructor(address c, address e) {
        core = c;
        governanceAuthority = e;
    }

    function setIncomplete(bool value) external {
        incomplete = value;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("STREAM_ARTWORK_FINALITY_RECOVERY");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return 0x83685f5c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == 0x83685f5c;
    }

    function assertNoIncompleteFinalityRecoveryRefreshPlans() external view {
        require(!incomplete, "incomplete refresh");
    }

    function executeFinalityRecovery(StreamFinalityRecoveryRequest calldata r) external {
        require(msg.sender == governanceAuthority, "actual Executor only");
        (bool active, bytes32 id, uint8 class_, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            IStreamGovernanceExecutor(governanceAuthority).currentAction();
        bytes32 expected = keccak256(abi.encode(r));
        require(
            active && id != 0 && class_ == 2 && scope == expected
                && oldHash == keccak256("old route")
                && newHash == keccak256(abi.encode(expected, address(this))),
            "exact per-call context"
        );
        require(
            IStreamGovernanceExecutor(governanceAuthority).governanceAction(id).status
                == GovernanceActionStatus.EXECUTED,
            "canonical status at target"
        );
        ++executionCount;
        executedAction = id;
        executedRequest = expected;
    }
}

/// @notice Real Core/Executor/Registry/Manifest/Safe policy composition with explicit companion boundary.
/// @dev Includes both unchanged inherited foundation tests. Recovery route/artist/notice behavior is separate.
contract StreamGovernanceRecoveryCurrentTest is StreamCurrentGovernanceBootstrapTest {
    RecoveryCurrentTargetBoundary private first;
    RecoveryCurrentTargetBoundary private second;
    RecoveryCurrentTargetBoundary private third;
    bytes32 private constant KEY = keccak256("ARTWORK_FINALITY_RECOVERY");

    function _initialize() private {
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) = _plan();
        configuration.executor
            .commitGenesisPlan(configuration.executor.hashGenesisPlan(binding, batches));
        configuration.executor.initializeGenesis(binding, batches);
        first = new RecoveryCurrentTargetBoundary(
            address(configuration.core), address(configuration.executor)
        );
        second = new RecoveryCurrentTargetBoundary(
            address(configuration.core), address(configuration.executor)
        );
        third = new RecoveryCurrentTargetBoundary(
            address(configuration.core), address(configuration.executor)
        );
        _catalog();
        StreamModuleRegistration[] memory registrations = new StreamModuleRegistration[](3);
        registrations[0] = _record(address(first));
        registrations[1] = _record(address(second));
        registrations[2] = _record(address(third));
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(configuration.registry, registrations);
        _runBatch(1, calls, data);
        require(
            address(configuration.executor).code.length <= 24576
                && address(configuration.core).code.length <= 24576,
            "actual production sizes"
        );
    }

    function _record(address target) private view returns (StreamModuleRegistration memory) {
        return StreamModuleRegistration(
            target,
            keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
            keccak256("explicit companion boundary"),
            0x83685f5c,
            500000,
            target.codehash,
            configuration.deploymentHash,
            keccak256(abi.encode(target)),
            "urn:recovery:boundary"
        );
    }

    function _catalog() private {
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](9);
        address[3] memory targets = [address(first), address(second), address(third)];
        for (uint256 i; i < 3; ++i) {
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
        data[0] =
            abi.encodeCall(
            executor.extendGovernanceActionPolicy, (revision, catalog, next, additions)
        );
        calls[0] = StreamCurrentStackPlan.call(address(executor), data[0], scope, oldHash, newHash);
        (calls[1], data[1]) = _publication(
            StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules, next
        );
        _runBatch(3, calls, data);
    }

    function _entry(uint8 class_, address target, bytes4 selector)
        private
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

    function _key(GovernanceActionPolicyEntry memory e) private pure returns (bytes32) {
        return keccak256(abi.encode(e.actionClass, e.target, e.selector));
    }

    function _recovery(address target, uint256 collectionId)
        private
        view
        returns (GovernanceCall memory c, bytes memory data)
    {
        StreamFinalityRecoveryRequest memory r;
        r.scope.scopeType = StreamFinalityScopeType.COLLECTION;
        r.scope.collectionId = collectionId;
        r.expectedOriginalFinalityRecordHash = keccak256("original");
        r.expectedOldRouteHash = keccak256("old route");
        r.replacementRoute.component = target;
        r.recoveryManifest.uri = "urn:recovery:exact-intent";
        r.recoveryManifest.uriHash = keccak256(bytes(r.recoveryManifest.uri));
        r.recoveryManifest.contentHash = keccak256("proof-free staged intent");
        r.reasonURI = "urn:reason";
        bytes32 scope = keccak256(abi.encode(r));
        data = abi.encodeCall(IStreamArtworkFinalityRecovery.executeFinalityRecovery, (r));
        c = StreamCurrentStackPlan.call(
            target, data, scope, keccak256("old route"), keccak256(abi.encode(scope, target))
        );
    }

    function _assertCall(address target)
        private
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
        private
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

    function _selected() private view returns (address) {
        return StreamCurrentStackPlan.readPointer(configuration.core, KEY).target;
    }

    function testCurrentRecoveryPublishedBatchCardinalityAndExactExecutionBytes() public {
        _initialize();
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        (calls[0], data[0]) = _recovery(address(first), 7);
        (calls[1], data[1]) = _recovery(address(second), 8);
        vm.expectRevert();
        this.scheduleFoundationBatch(2, calls, data);
        require(
            first.executionCount() == 0 && second.executionCount() == 0,
            "rejected full batch no target effects"
        );
        (calls[0], data[0]) = _assertCall(address(first));
        bytes memory original = data[1];
        data[1] = bytes.concat(original, hex"00");
        calls[1].callDataHash = keccak256(data[1]);
        vm.expectRevert();
        this.scheduleFoundationBatch(2, calls, data);
        data[1] = original;
        calls[1].callDataHash = keccak256(original);
        (bytes32 id, uint64 ready) = this.scheduleFoundationBatch(2, calls, data);
        require(
            keccak256(abi.encode(configuration.executor.scheduledCallData(id)))
                == keccak256(abi.encode(data)),
            "actual published preimages retained"
        );
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        vm.warp(ready);
        data[1] = bytes.concat(original, hex"00");
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        data[1] = original;
        bytes memory code = address(second).code;
        vm.etch(address(second), hex"00");
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        vm.etch(address(second), code);
        this.executeFoundationBatch(id, calls, data);
        require(
            second.executionCount() == 1 && first.executionCount() == 0
                && second.executedAction() == id && second.executedRequest() == calls[1].scopeHash,
            "second call receives its own actual context"
        );
        require(
            configuration.executor.governanceAction(id).target == address(first),
            "indexing first target is distinct"
        );
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
    }

    function testCurrentRecoveryCutoverRequiresActualAdjacentHealthyPredecessor() public {
        _initialize();
        (GovernanceCall[] memory calls, bytes[] memory data) =
            _selection(address(first), address(0));
        _runBatch(3, calls, data);
        require(_selected() == address(first), "real initial zero installation");
        (calls, data) = _selection(address(second), address(0));
        vm.expectRevert();
        this.scheduleFoundationBatch(3, calls, data);
        (calls, data) = _selection(address(second), address(first));
        (bytes32 id, uint64 ready) = this.scheduleFoundationBatch(3, calls, data);
        vm.warp(ready);
        uint256 nonce = governor.nonce();
        first.setIncomplete(true);
        vm.expectRevert();
        this.executeFoundationBatch(id, calls, data);
        require(
            _selected() == address(first) && governor.nonce() == nonce
                && configuration.executor.governanceAction(id).status
                    == GovernanceActionStatus.SCHEDULED,
            "target assertion failure rolls whole action back"
        );
        first.setIncomplete(false);
        this.executeFoundationBatch(id, calls, data);
        require(
            _selected() == address(second)
                && configuration.executor.governanceAction(id).status
                    == GovernanceActionStatus.EXECUTED,
            "same published bytes healthy retry"
        );
    }

    function testCurrentRecoveryCutoverRevalidatesChangedPredecessorAfterScheduling() public {
        _initialize();
        (GovernanceCall[] memory initial, bytes[] memory initialData) =
            _selection(address(first), address(0));
        _runBatch(3, initial, initialData);
        (GovernanceCall[] memory stale, bytes[] memory staleData) =
            _selection(address(second), address(first));
        (bytes32 staleId,) = this.scheduleFoundationBatch(3, stale, staleData);
        (GovernanceCall[] memory current, bytes[] memory currentData) =
            _selection(address(third), address(first));
        _runBatch(3, current, currentData);
        require(_selected() == address(third), "different legitimate predecessor now selected");
        uint256 nonce = governor.nonce();
        vm.expectRevert();
        this.executeFoundationBatch(staleId, stale, staleData);
        require(
            _selected() == address(third) && governor.nonce() == nonce
                && configuration.executor.governanceAction(staleId).status
                    == GovernanceActionStatus.SCHEDULED,
            "stale action cannot substitute current predecessor"
        );
        (current, currentData) = _selection(address(second), address(third));
        _runBatch(3, current, currentData);
        require(_selected() == address(second), "fresh exact current predecessor control");
    }

    function _publication(StreamSystemManifest.ModuleAddresses memory modules, bytes32 reason)
        private
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
        private
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
