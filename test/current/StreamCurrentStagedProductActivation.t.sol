// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentGovernanceBootstrap.t.sol";
import "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../smart-contracts/vendor/openzeppelin/Strings.sol";

/// @notice Deploys actual mint products after the foundation and activates them through a real Safe.
/// @dev Artist/estate and a first mint are separate integration steps.
contract StreamCurrentStagedProductActivationTest is StreamCurrentGovernanceBootstrapTest {
    StreamMintManager private manager;
    StreamMintLedger private ledger;

    function testCurrentSafeActivatesNewProductsWithCatalogAndManifestTails() public {
        StreamGovernanceGenesisPlan.Configuration memory c = configuration;
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) = _plan();
        c.executor.commitGenesisPlan(c.executor.hashGenesisPlan(binding, batches));
        c.executor.initializeGenesis(binding, batches);
        ledger = new StreamMintLedger();
        manager = new StreamMintManager(c.core, ledger, IERC165(address(c.registry)));
        ledger.transferOwnership(address(c.executor));
        require(!ledger.ledgerWriter(address(manager)), "not activated at construction");
        require(
            StreamCurrentStackPlan.readPointer(c.core, keccak256("MINT_MANAGER")).target
                == address(0),
            "product remains unselected"
        );
        (GovernanceCall memory writer, bytes memory writerData) = _writerCall();
        GovernanceCall[] memory beforeAdmission = new GovernanceCall[](1);
        bytes[] memory beforeData = new bytes[](1);
        beforeAdmission[0] = writer;
        beforeData[0] = writerData;
        vm.expectRevert();
        this.scheduleFoundationBatch(1, beforeAdmission, beforeData);
        require(!ledger.ledgerWriter(address(manager)), "unadmitted target cannot gain authority");
        _admitWriter();
        StreamModuleRegistration[] memory records = _productRecords();
        (GovernanceCall[] memory registrations, bytes[] memory registrationData) =
            StreamCurrentStackPlan.registrationCalls(c.registry, records);
        GovernanceCall[] memory writes = new GovernanceCall[](3);
        bytes[] memory data = new bytes[](3);
        writes[0] = registrations[0];
        writes[1] = registrations[1];
        writes[2] = writer;
        data[0] = registrationData[0];
        data[1] = registrationData[1];
        data[2] = writerData;
        _runBatch(1, writes, data);
        require(
            c.registry.moduleCount() == 4 && ledger.ledgerWriter(address(manager)),
            "real product registration and governed writer authority"
        );

        bytes32[] memory types = new bytes32[](2);
        types[0] = keccak256("MINT_MANAGER");
        types[1] = keccak256("MINT_LEDGER");
        (GovernanceCall[] memory pointers, bytes[] memory pointerData) =
            StreamCurrentStackPlan.pointerCalls(c.core, c.registry, types, records);
        vm.expectRevert();
        this.scheduleFoundationBatch(3, pointers, pointerData);
        require(
            StreamCurrentStackPlan.readPointer(c.core, types[0]).target == address(0),
            "missing manifest tail cannot select products"
        );
        writes[0] = pointers[0];
        writes[1] = pointers[1];
        data[0] = pointerData[0];
        data[1] = pointerData[1];
        StreamSystemManifest.ModuleAddresses memory modules =
        StreamGenesisManifestPlan.readAggregate(c.manifest).modules;
        modules.mintManager = address(manager);
        modules.mintLedger = address(ledger);
        (writes[2], data[2]) = _publication(modules, keccak256("activated mint products"));
        _runBatch(3, writes, data);
        StreamSystemManifest.AggregateState memory aggregate =
            StreamGenesisManifestPlan.readAggregate(c.manifest);
        require(
            aggregate.modules.mintManager == address(manager)
                && aggregate.modules.mintLedger == address(ledger),
            "current manifest exposes actual products"
        );
        require(
            aggregate.modules.artistRegistry == address(0), "artist activation remains explicit"
        );
        require(
            c.manifest.streamSystemManifestPointerCount() == 3,
            "foundation, catalog and selection publications"
        );
        require(
            StreamCurrentStackPlan.readPointer(c.core, types[0]).target == address(manager)
                && StreamCurrentStackPlan.readPointer(c.core, types[1]).target == address(ledger),
            "actual Core selection"
        );
        (bool ok, bytes memory raw) = address(c.executor)
            .staticcall(abi.encodeCall(c.executor.systemManifestBootstrapState, ()));
        require(ok, "bootstrap read");
        StreamGovernanceManifest.BootstrapStateView memory state =
            abi.decode(raw, (StreamGovernanceManifest.BootstrapStateView));
        require(
            state.inventoryLeafCount == 5
                && state.inventoryStateRoot == binding.expectedInventoryStateRoot,
            "historical foundation inventory remains unchanged"
        );
        require(
            address(manager).code.length <= 24576 && address(ledger).code.length <= 24576,
            "actual deployed product sizes"
        );
    }

    function _productRecords() private view returns (StreamModuleRegistration[] memory records) {
        records = new StreamModuleRegistration[](2);
        records[0] = _record(
            address(manager), keccak256("MINT_MANAGER"), type(IStreamMintManager).interfaceId
        );
        records[1] =
            _record(address(ledger), keccak256("MINT_LEDGER"), type(IStreamMintLedger).interfaceId);
    }

    function _record(address target, bytes32 kind, bytes4 id)
        private
        view
        returns (StreamModuleRegistration memory)
    {
        return StreamModuleRegistration(
            target,
            kind,
            keccak256("staged product fixture"),
            id,
            500000,
            target.codehash,
            configuration.deploymentHash,
            keccak256(abi.encode(kind, target)),
            "urn:6529stream:fixture:staged-product"
        );
    }

    function _writerCall() private view returns (GovernanceCall memory call_, bytes memory data) {
        data = abi.encodeCall(ledger.setLedgerWriter, (address(manager), true));
        call_ = StreamCurrentStackPlan.call(
            address(ledger),
            data,
            keccak256(abi.encode(address(ledger), data)),
            bytes32(0),
            keccak256(data)
        );
    }

    function _admitWriter() private {
        StreamGovernanceExecutor executor = configuration.executor;
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](1);
        additions[0] = GovernanceActionPolicyEntry(
            1,
            address(ledger),
            ledger.setLedgerWriter.selector,
            address(ledger).codehash,
            keccak256(abi.encode(configuration.deploymentHash, address(ledger))),
            1,
            0,
            0,
            bytes32(0)
        );
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
        (, bytes32 actual, uint256 actualCount, uint64 actualRevision) =
            executor.governanceActionPolicyState();
        require(
            actual == next && actualCount == count + 1 && actualRevision == revision + 1,
            "exact deployed writer target admitted"
        );
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
