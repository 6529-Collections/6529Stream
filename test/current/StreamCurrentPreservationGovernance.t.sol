// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../../script/current/StreamFullV1PreservationPlan.sol";
import "../../script/current/StreamGovernanceStagePlan.sol";

/// @notice Authored actual-current Core/Executor/family/preservation composition.
/// @dev Only inherited upstream entropy is a service double. Safe is the pinned official
/// 1.4.1 singleton/proxy, with two real signatures. Native execution remains a separately
/// recorded acceptance step; these cases are not complete generic museum payload coverage.
contract StreamCurrentPreservationGovernanceTest is StreamCurrentStackFixture, OfficialSafeFixture {
    bytes32 private constant ARCHIVE_TYPE = keccak256("genesis PREMIS archive event");
    bytes32 private constant INDEPENDENT_TYPE = keccak256("genesis independent preservation note");
    StreamFullV1PreservationPlan.Products private preservation;
    OfficialSafe private governor;
    OfficialSafe private otherSafe;
    uint256[] private keys;

    function setUp() public {
        keys.push(0x652901);
        keys.push(0x652902);
        SafeComponents memory safe = deploySafeComponents("1.4.1");
        governor = createOfficialSafe(safe, safeOwnerAddresses(keys), 2, 3727);
        otherSafe = createOfficialSafe(safe, safeOwnerAddresses(keys), 2, 3728);
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        _installGovernor();
        _executeStage(_registrationWithTail(), keccak256("original preservation products"));
        _executeStage(
            StreamFullV1PreservationPlan.bind(preservation),
            keccak256("bind original metadata hosts")
        );
        _executeStage(
            StreamFullV1PreservationPlan.admitRecordType(
                preservation, ARCHIVE_TYPE, preservation.families.FAMILY_ARCHIVE(), uint16(1 << 6)
            ),
            keccak256("archive family admission")
        );
        _executeStage(
            StreamFullV1PreservationPlan.admitRecordType(
                preservation,
                INDEPENDENT_TYPE,
                preservation.families.FAMILY_INDEPENDENT(),
                uint16(1 << 5)
            ),
            keccak256("independent family admission")
        );
    }

    function _deployAdditionalProducts() internal override {
        preservation = StreamFullV1PreservationPlan.deploy(address(core), address(executor));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return StreamFullV1PreservationPlan.operatingPolicies(preservation, DEPLOYMENT_HASH);
    }

    function testOriginalHostsPinSameCurrentCoreAndExecutorWithoutTemporaryAdmin() public view {
        require(
            preservation.families.configurationAuthority() == address(executor),
            "canonical stored authority"
        );
        require(preservation.admins.owner() == address(executor), "compatibility owner is Executor");
        require(
            preservation.families.streamCore() == address(core)
                && preservation.records.streamCore() == address(core),
            "same original Core"
        );
        require(
            preservation.records.recordFamilyRegistry() == address(preservation.families),
            "same family registry"
        );
        require(
            preservation.admins.familyRegistryCodeHash() == address(preservation.families).codehash,
            "bound family runtime"
        );
        require(
            preservation.admins.preservationRecordsCodeHash()
                == address(preservation.records).codehash,
            "bound preservation runtime"
        );
        require(
            !preservation.admins.retrieveGlobalAdmin(address(executor))
                && !preservation.admins.retrieveGlobalAdmin(address(governor)),
            "no global bypass"
        );
        require(
            !preservation.admins.retrieveCollectionAdmin(address(governor), 1),
            "no collection authority"
        );
        require(preservation.admins.emergencyRecipient() == address(0), "no invented recipient");
        require(!preservation.admins.isPaused(StreamPauseDomains.MINT), "unsupported domains false");
        require(
            address(assemblyMetadata) != address(preservation.families),
            "role24 remains original V1 host"
        );
        StreamModuleRegistration[] memory rows = _registrations();
        for (uint256 i; i < rows.length; ++i) {
            StreamModuleRecord memory row = registry.moduleRecord(rows[i].module);
            require(
                row.status == ModuleRegistryStatus.ACTIVE
                    && row.runtimeCodeHash == rows[i].expectedRuntimeCodeHash
                    && row.interfaceId == rows[i].interfaceId,
                "actual ERC165 admission"
            );
        }
    }

    function testRealSafeGovernedWriterGrantStoresExactPayloadAndEvent() public {
        bytes memory grant = abi.encodeCall(
            preservation.families.setRecordFamilyGrant,
            (preservation.families.FAMILY_ARCHIVE(), uint8(6), address(governor), true)
        );
        _expectSafeFailure(address(preservation.families), grant);
        bytes32 archiveFamily = preservation.families.FAMILY_ARCHIVE();
        vm.expectRevert();
        vm.prank(vm.addr(keys[0]));
        preservation.families.setRecordFamilyGrant(archiveFamily, 6, address(governor), true);
        IStreamPreservationRecords.CollectionRecord memory record =
            _record(ARCHIVE_TYPE, "ipfs://premis-original");
        _expectSafeFailure(
            address(preservation.records),
            abi.encodeCall(preservation.records.recordCollectionRecord, (uint256(1), record))
        );
        _grantWriter(true);
        vm.recordLogs();
        _write(governor, record);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 expected =
            preservation.records.deriveCollectionRecordHashFor(address(governor), 1, record);
        require(
            preservation.records
                .latestCollectionRecordHashFor(1, ARCHIVE_TYPE, record.subjectId, address(governor))
            == expected,
            "Safe latest record"
        );
        IStreamPreservationRecords.CollectionRecordSummary memory summary =
            preservation.records.collectionRecordSummary(expected);
        require(
            summary.recorder == address(governor) && summary.authorizationClass == 6,
            "actual Safe family principal"
        );
        require(
            keccak256(abi.encode(preservation.records.collectionRecord(expected)))
                == keccak256(abi.encode(record)),
            "exact stored full payload"
        );
        bool seen;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(preservation.records)) {
                require(!seen && logs[i].topics.length == 4, "single preservation event");
                require(
                    logs[i].topics[0]
                        == keccak256(
                            "CollectionRecordRecorded(uint256,bytes32,bytes32,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),bytes32,address,uint8)"
                        ),
                    "record event signature"
                );
                require(
                    logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == ARCHIVE_TYPE
                        && logs[i].topics[3] == record.subjectId,
                    "record event topics"
                );
                (
                    IStreamPreservationRecords.CollectionRecord memory emitted,
                    bytes32 hash,
                    address recorder,
                    uint8 auth
                ) = abi.decode(
                    logs[i].data,
                    (IStreamPreservationRecords.CollectionRecord, bytes32, address, uint8)
                );
                require(
                    keccak256(abi.encode(emitted)) == keccak256(abi.encode(record))
                        && hash == expected && recorder == address(governor) && auth == 6,
                    "record event payload"
                );
                seen = true;
            }
        }
        require(seen, "preservation event found");
        vm.expectRevert();
        this.safeCall(
            otherSafe,
            address(preservation.records),
            abi.encodeCall(preservation.records.recordCollectionRecord, (uint256(1), record))
        );
        _grantWriter(false);
        record.uri = "ipfs://after-revocation";
        _expectSafeFailure(
            address(preservation.records),
            abi.encodeCall(preservation.records.recordCollectionRecord, (uint256(1), record))
        );
    }

    function testGovernedPauseBlocksBothMetadataHostsButIndependentRecordsRemainAvailable() public {
        _grantWriter(true);
        _executeStage(
            StreamFullV1PreservationPlan.pauseClassification(preservation),
            keccak256("pause classifier")
        );
        IStreamCollectionMetadata.CollectionMetadataRecord memory metadataRecord =
            IStreamCollectionMetadata.CollectionMetadataRecord(
                ARCHIVE_TYPE,
                keccak256("metadata schema"),
                "ipfs://archive-metadata",
                keccak256("content"),
                bytes32(0),
                uint64(block.timestamp)
            );
        require(
            executeSafe(
                governor,
                keys,
                address(preservation.families),
                0,
                abi.encodeCall(
                    preservation.families.setCollectionRecord, (uint256(1), metadataRecord)
                ),
                0
            ),
            "actual Core freeze API compatible"
        );
        _expectSafeFailure(
            address(preservation.admins), abi.encodeCall(preservation.admins.pauseMetadata, ())
        );
        vm.recordLogs();
        _executeStage(
            StreamFullV1PreservationPlan.pause(preservation, true), keccak256("pause metadata")
        );
        _assertPauseEvent(vm.getRecordedLogs(), true, 1);
        require(
            preservation.admins.isPaused(StreamPauseDomains.METADATA_MUTATION), "metadata paused"
        );
        require(!preservation.admins.isPaused(StreamPauseDomains.MINT), "pause limited to metadata");
        IStreamPreservationRecords.CollectionRecord memory record =
            _record(ARCHIVE_TYPE, "ipfs://paused-archive");
        _expectSafeFailure(
            address(preservation.records),
            abi.encodeCall(preservation.records.recordCollectionRecord, (uint256(1), record))
        );
        _expectSafeFailure(
            address(preservation.families),
            abi.encodeCall(
                preservation.families.setCollectionRecordWithRevision,
                (uint256(1), metadataRecord, uint64(1))
            )
        );
        record.recordType = INDEPENDENT_TYPE;
        _write(otherSafe, record);
        require(
            preservation.records
            .collectionRecordSummary(
                preservation.records.deriveCollectionRecordHashFor(address(otherSafe), 1, record)
            )
            .authorizationClass == 5,
            "independent exemption retained"
        );
        _expectSafeFailure(
            address(preservation.admins), abi.encodeCall(preservation.admins.resumeMetadata, ())
        );
        _executeStage(
            StreamFullV1PreservationPlan.pause(preservation, false), keccak256("delayed resume")
        );
        require(
            !preservation.admins.metadataPaused() && preservation.admins.pauseRevision() == 2,
            "exact delayed resume"
        );
        record.recordType = ARCHIVE_TYPE;
        _write(governor, record);
    }

    function testPauseRequiresClassifierAndExactCurrentTransition() public {
        GenesisBatch memory pauseBatch = StreamFullV1PreservationPlan.pause(preservation, true);
        vm.expectRevert();
        this.runStage(pauseBatch, keccak256("missing classifier"));
        _executeStage(
            StreamFullV1PreservationPlan.pauseClassification(preservation),
            keccak256("classify pause")
        );
        GenesisBatch memory wrong = StreamFullV1PreservationPlan.pause(preservation, true);
        wrong.calls[0].oldValueHash = keccak256("wrong old state");
        vm.expectRevert();
        this.runStage(wrong, keccak256("wrong pause commitment"));
        require(
            !preservation.admins.metadataPaused() && preservation.admins.pauseRevision() == 0,
            "failed transition rolls back"
        );
        _executeStage(pauseBatch, keccak256("valid pause"));
        _executeStage(
            StreamFullV1PreservationPlan.pause(preservation, false), keccak256("resume for ABA")
        );
        vm.expectRevert();
        this.runStage(pauseBatch, keccak256("stale pause after ABA"));
        require(
            !preservation.admins.metadataPaused() && preservation.admins.pauseRevision() == 2,
            "revision rejects stale preimage"
        );
    }

    function testScopedLegacyAdminAcceptsOnlyActualExecutorWithMatchingTargetSelector() public {
        bytes memory data = abi.encodeCall(
            preservation.records.updateAdminContract, (address(preservation.admins))
        );
        _expectSafeFailure(address(preservation.records), data);
        require(
            !preservation.admins
                .retrieveFunctionAdmin(
                    address(executor),
                    address(preservation.records),
                    preservation.records.updateAdminContract.selector
                ),
            "idle Executor not admin"
        );
        GenesisBatch memory batch;
        batch.actionClass = 3;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = data;
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(preservation.records),
            data,
            preservation.admins
                .functionScope(
                    address(preservation.families),
                    preservation.records.updateAdminContract.selector
                ),
            keccak256(abi.encode(address(preservation.admins))),
            keccak256(abi.encode(address(preservation.admins)))
        );
        vm.expectRevert();
        this.runStage(batch, keccak256("wrong metadata target scope"));
        batch.calls[0].scopeHash = preservation.admins
            .functionScope(
                address(preservation.records), preservation.admins.pauseMetadata.selector
            );
        vm.expectRevert();
        this.runStage(batch, keccak256("wrong metadata selector scope"));
        batch.calls[0].scopeHash = preservation.admins
            .functionScope(
                address(preservation.records), preservation.records.updateAdminContract.selector
            );
        _executeStage(batch, keccak256("actual scoped legacy admin"));
        require(
            preservation.records.adminsContract() == address(preservation.admins),
            "governed original admin retained"
        );
        vm.prank(address(preservation.records));
        require(
            !preservation.admins
                .retrieveFunctionAdmin(
                    address(executor),
                    address(preservation.records),
                    preservation.records.updateAdminContract.selector
                ),
            "post-call context cleared"
        );
    }

    function testMetadataHostBindingIsOneWayAndExecutorRuntimeDriftFailsClosed() public {
        bytes memory data = abi.encodeCall(
            preservation.admins.bindMetadataHosts,
            (address(preservation.families), address(preservation.records))
        );
        _expectSafeFailure(address(preservation.admins), data);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataGovernanceAdapter.MetadataHostsAlreadyBound.selector
            )
        );
        vm.prank(address(executor));
        preservation.admins
            .bindMetadataHosts(address(preservation.families), address(preservation.records));
        vm.etch(address(executor), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataGovernanceAdapter.MetadataGovernanceContextRequired.selector
            )
        );
        vm.prank(address(executor));
        preservation.admins.pauseMetadata();
        vm.prank(address(preservation.records));
        require(
            !preservation.admins
                .retrieveFunctionAdmin(
                    address(executor),
                    address(preservation.records),
                    preservation.records.updateAdminContract.selector
                ),
            "changed Executor denied"
        );
    }

    function testReservedMetadataLockUsesActualExecutorTerminalAction() public {
        bytes32 reserved = bytes32("METADATA_ALL");
        bytes memory data =
            abi.encodeCall(preservation.families.lockCollectionRecord, (uint256(1), reserved));
        _expectSafeFailure(address(preservation.families), data);
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = data;
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(preservation.families),
            data,
            preservation.admins
                .functionScope(
                    address(preservation.families),
                    preservation.families.lockCollectionRecord.selector
                ),
            keccak256(abi.encode(false)),
            keccak256(abi.encode(true))
        );
        _executeStage(batch, keccak256("actual terminal metadata lock"));
        require(preservation.families.isLocked(1, reserved), "reserved metadata lock executed");
        require(
            preservation.families.collectionRecord(1, reserved).authorizationClass == 7,
            "scoped function admin, no global bypass"
        );
    }

    function _grantWriter(bool enabled) private {
        GenesisBatch memory batch = StreamFullV1PreservationPlan.grantWriter(
            preservation, preservation.families.FAMILY_ARCHIVE(), 6, address(governor), enabled
        );
        bytes32 expected = batch.calls[0].newValueHash;
        _executeStage(batch, keccak256(abi.encode("Safe archive writer", enabled)));
        require(
            preservation.families.configurationHash() == expected,
            "exact family configuration chain"
        );
    }

    function _write(OfficialSafe writer, IStreamPreservationRecords.CollectionRecord memory record)
        private
    {
        require(
            executeSafe(
                writer,
                keys,
                address(preservation.records),
                0,
                abi.encodeCall(preservation.records.recordCollectionRecord, (uint256(1), record)),
                0
            ),
            "actual Safe record write"
        );
    }

    function _expectSafeFailure(address target, bytes memory data) private {
        uint256 nonce = governor.nonce();
        vm.expectRevert();
        this.safeCall(governor, target, data);
        require(governor.nonce() == nonce, "failed inner call rolls back Safe nonce");
    }

    function safeCall(OfficialSafe account, address target, bytes memory data)
        external
        returns (bool)
    {
        return executeSafe(account, keys, target, 0, data, 0);
    }

    function _record(bytes32 recordType, string memory uri)
        private
        view
        returns (IStreamPreservationRecords.CollectionRecord memory)
    {
        return IStreamPreservationRecords.CollectionRecord(
            recordType,
            keccak256("collection:1"),
            IStreamPreservationRecords.HashRef(
                2, abi.encode(keccak256("original archival payload")), keccak256("RFC8785_JCS")
            ),
            uri,
            keccak256("premis.v3.json"),
            bytes32(0),
            IStreamPreservationRecords.HashRef(0, bytes(""), bytes32(0)),
            uint64(block.timestamp)
        );
    }

    function _assertPauseEvent(Vm.Log[] memory logs, bool paused, uint64 revision) private view {
        bool seen;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(preservation.admins)
                    && logs[i].topics[0] == keccak256("MetadataPauseUpdated(bool,uint64,bytes32)")
            ) {
                (bool actual, uint64 actualRevision) = abi.decode(logs[i].data, (bool, uint64));
                require(
                    !seen && actual == paused && actualRevision == revision
                        && logs[i].topics[1] != 0,
                    "exact pause event"
                );
                seen = true;
            }
        }
        require(seen, "pause event observed");
    }

    function _registrations() private view returns (StreamModuleRegistration[] memory) {
        return StreamFullV1PreservationPlan.registrations(
            preservation,
            DEPLOYMENT_HASH,
            keccak256("original preservation fixture"),
            "urn:6529stream:genesis:preservation",
            500000
        );
    }

    function _registrationWithTail() private returns (GenesisBatch memory batch) {
        (GovernanceCall[] memory calls, bytes[] memory datas) =
            StreamCurrentStackPlan.registrationCalls(registry, _registrations());
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](calls.length + 1);
        batch.callDatas = new bytes[](batch.calls.length);
        for (uint256 i; i < calls.length; ++i) {
            batch.calls[i] = calls[i];
            batch.callDatas[i] = datas[i];
        }
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"purpose\":\"original preservation hosts\",\"completeGenesis\":false}")
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:6529stream:genesis:preservation",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (batch.calls[calls.length], batch.callDatas[calls.length]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, current.modules);
    }

    function runStage(GenesisBatch memory batch, bytes32 stage) external {
        _executeStage(batch, stage);
    }

    function _installGovernor() private {
        (address prior, bytes32 hash, uint64 revision) = executor.governanceRootState();
        bytes memory data = abi.encodeCall(
            executor.rotateGovernanceRoot, (address(governor), address(governor).codehash)
        );
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(3));
        GovernanceActionRequest memory request = GovernanceActionRequest(
            3,
            address(executor),
            0,
            executor.rotateGovernanceRoot.selector,
            data,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_GOVERNANCE_ROOT_SCOPE_V1"),
                    block.chainid,
                    address(executor)
                )
            ),
            _rootState(prior, hash, revision),
            _rootState(address(governor), address(governor).codehash, revision + 1),
            ready,
            ready + 7 days,
            keccak256("full-v1 actual Safe root"),
            "urn:6529stream:genesis:Safe-root",
            DEPLOYMENT_HASH
        );
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(ready);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
    }

    function _rootState(address root, bytes32 hash, uint64 revision)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_STATE_V1"),
                block.chainid,
                address(executor),
                root,
                hash,
                revision
            )
        );
    }

    function _executeStage(GenesisBatch memory batch, bytes32 stage) private {
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(batch.actionClass));
        StreamGovernanceStagePlan.Plan memory plan = StreamGovernanceStagePlan.build(
            executor,
            stage,
            batch,
            ready,
            ready + 7 days,
            stage,
            "urn:6529stream:genesis:composed-stage",
            DEPLOYMENT_HASH
        );
        bytes32 saved = StreamGovernanceStagePlan.planHash(plan);
        executor.publishGovernanceCallData(batch.callDatas);
        StreamGovernanceStagePlan.NextCall memory next =
            StreamGovernanceStagePlan.scheduling(plan, saved);
        vm.recordLogs();
        require(
            executeSafe(governor, keys, next.target, next.value, next.data, 0),
            "real Safe schedules"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        bytes32 action;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(action == 0, "one observed action");
                action = logs[i].topics[1];
            }
        }
        require(action != 0, "actual receipt action ID");
        if (ready > block.timestamp) {
            vm.expectRevert();
            this.executeSaved(plan, action, saved);
            vm.warp(ready);
        }
        require(
            StreamGovernanceStagePlan.execute(plan, action, saved),
            "permissionless delayed execution"
        );
    }

    function executeSaved(StreamGovernanceStagePlan.Plan memory plan, bytes32 action, bytes32 saved)
        external
        returns (bool)
    {
        return StreamGovernanceStagePlan.execute(plan, action, saved);
    }
}
