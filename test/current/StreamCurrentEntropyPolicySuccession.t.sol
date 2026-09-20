// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentGovernanceStagePlan.t.sol";
import "../../script/current/StreamEntropyFallbackPlan.sol";
import "../../script/current/StreamEntropyPolicySuccessionPlan.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import "../../script/current/StreamRevealActivationPlan.sol";
import "../mocks/MockStreamEntropyProvider.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyOriginRelay as O
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";

interface EntropySuccessionFaultVm {
    function mockCallRevert(address target, bytes calldata data, bytes calldata reason) external;
    function clearMockedCalls() external;
    function expectCall(address target, bytes calldata data) external;
}

/// @notice Actual Core, Executor, Registry, SystemManifest, Coordinators and two-of-three Safe.
/// @dev Foundation-only LEGACY policy succession; no Artist, paid mint or renderer graph claim.
/// The original-bound provider is a test double. Only named fault cases inject a transient failure.
contract StreamCurrentEntropyPolicySuccessionTest is StreamCurrentGovernanceStagePlanTest {
    bytes32 private constant ENTROPY = keccak256("ENTROPY_COORDINATOR");
    bytes32 private constant IMPORT_MANIFEST = keccak256("current entropy import inventory");
    bytes32 private constant REASON = keccak256("current entropy policy succession");
    StreamEntropyCoordinator private source;
    StreamEntropyCoordinator private successor;
    MockStreamEntropyProvider private originalProvider;

    struct BeforeCutover {
        bytes32 pointerHash;
        bytes32 receiptHash;
        bytes32 manifestHash;
        uint256 manifestCount;
        uint256 safeNonce;
    }

    function testPolicySuccessionEmptyInventoryStillNeedsSealThenAtomicSafeCutover() public {
        _start();
        (uint256 count, uint64 serial, bytes32 digest) = C(address(source)).entropyPolicyInventory();
        require(count == 0 && serial == 0 && digest != 0, "actual empty inventory commitment");
        require(!_ready(), "fresh candidate is not ready even for empty source");
        _assertPointerRefused();
        bytes32 beginId = _begin();
        require(!_ready(), "STAGING is not SEALED");
        _assertPointerRefused();
        bytes32 sealId = _seal();
        require(_ready(), "complete empty SEALED receipt");
        C.ImportReceipt memory sealedReceipt = C(address(successor)).entropyPolicyImport();
        require(
            sealedReceipt.beginActionId == beginId && sealedReceipt.sealActionId == sealId,
            "real receipts"
        );
        (StreamGovernanceStagePlan.Plan memory plan,) = _cutover();
        _assertCutoverPlan(plan);
        bytes32 id = _schedule(plan);
        BeforeCutover memory before_ = _before();
        bytes memory signed = _signedExecution(plan, id);
        vm.expectRevert();
        this.submitSigned(signed);
        _assertUnchanged(before_, id);
        vm.warp(plan.notBefore);
        vm.recordLogs();
        require(this.submitSigned(signed), "same pre-signed Safe execution after delay");
        _assertActivated(sealedReceipt, id, before_);
        _assertActivationEvents(vm.getRecordedLogs(), id, sealedReceipt.importHash);
        vm.expectRevert();
        this.submitSigned(signed);
        require(governor.nonce() == before_.safeNonce + 1, "successful Safe nonce consumed once");
    }

    function testPolicySuccessionCopiesEveryConfiguredIdAndRetainsLegacyDeclaredAndH0() public {
        _start();
        _twoPolicies();
        C.PolicyExport memory first = C(address(source)).exportEntropyPolicy(1);
        C.PolicyExport memory third = C(address(source)).exportEntropyPolicy(3);
        require(first.record.policyHash != 0 && third.record.policyHash == 0, "distinct originals");
        _begin();
        C(address(successor)).importNextEntropyPolicy(0);
        _assertExport(1, first);
        require(C(address(successor)).entropyPolicyImport().nextIndex == 1, "ordered prefix");
        vm.expectRevert(abi.encodeWithSelector(C.EntropyPolicyImportIndex.selector, 0, 1));
        C(address(successor)).importNextEntropyPolicy(0);
        vm.expectRevert();
        C(address(successor)).entropyPolicyImportSealTransition();
        _assertPointerRefused();
        C(address(successor)).importNextEntropyPolicy(1);
        _assertExport(3, third);
        require(C(address(successor)).entropyPolicyCollectionAt(0) == 1, "first configured ID");
        require(C(address(successor)).entropyPolicyCollectionAt(1) == 3, "skip unconfigured ID2");
        (uint256 imported,,) = C(address(successor)).entropyPolicyInventory();
        require(
            imported == 2 && configuration.core.collectionExists(2), "inventory is configured set"
        );
        vm.expectRevert(abi.encodeWithSelector(C.InvalidEntropyPolicyExport.selector, 2));
        C(address(successor)).importedEntropyPolicy(2);
        _route(1);
        _route(3);
        _seal();
        C.ImportReceipt memory sealedReceipt = C(address(successor)).entropyPolicyImport();
        require(
            sealedReceipt.count == 2 && sealedReceipt.nextIndex == 2
                && sealedReceipt.requiredRelayCount == 2 && sealedReceipt.confirmedRelayCount == 2,
            "complete collection and route counts"
        );
        (StreamGovernanceStagePlan.Plan memory plan,) = _cutover();
        bytes32 id = _schedule(plan);
        BeforeCutover memory before_ = _before();
        vm.warp(plan.notBefore);
        require(this.submitSigned(_signedExecution(plan, id)), "all configured cutover");
        _assertActivated(sealedReceipt, id, before_);
        _assertExport(1, first);
        _assertExport(3, third);
    }

    function testPolicySuccessionUnconfirmedOriginRouteCannotSealOrPassCoreGate() public {
        _start();
        _twoPolicies();
        _begin();
        C(address(successor)).importNextEntropyPolicy(0);
        C(address(successor)).importNextEntropyPolicy(1);
        _route(1);
        C.ImportReceipt memory before_ = C(address(successor)).entropyPolicyImport();
        require(
            before_.requiredRelayCount == 2 && before_.confirmedRelayCount == 1, "missing route"
        );
        vm.expectRevert();
        C(address(successor)).confirmEntropyRelayRoute(3);
        vm.expectRevert();
        C(address(successor)).entropyPolicyImportSealTransition();
        require(
            keccak256(abi.encode(C(address(successor)).entropyPolicyImport()))
                == keccak256(abi.encode(before_)),
            "refusals preserve exact staging receipt"
        );
        _assertPointerRefused();
        _route(3);
        _seal();
        require(_ready(), "only authenticated complete routes unlock seal");
    }

    function testPolicySuccessionSourceMutationBeforeCopyPreservesUnusedImportIndex() public {
        _start();
        _twoPolicies();
        _begin();
        C.ImportReceipt memory before_ = C(address(successor)).entropyPolicyImport();
        bytes32 originalHash = C(address(source)).exportEntropyPolicy(1).record.policyHash;
        _retuneSourceFee(1);
        require(
            C(address(source)).exportEntropyPolicy(1).record.policyHash == originalHash,
            "fee drift does not rewrite original policy identity"
        );
        vm.expectRevert(
            abi.encodeWithSelector(C.EntropyPolicyImportSourceChanged.selector, address(source))
        );
        C(address(successor)).importNextEntropyPolicy(0);
        require(
            keccak256(abi.encode(C(address(successor)).entropyPolicyImport()))
                == keccak256(abi.encode(before_)),
            "failed copy leaves exact receipt and index"
        );
        (uint256 count,,) = C(address(successor)).entropyPolicyInventory();
        require(count == 0, "no partial policy installation");
        vm.expectRevert(abi.encodeWithSelector(C.EntropyPolicyImportNotFresh.selector));
        C(address(successor)).entropyPolicyImportTransition(address(source), IMPORT_MANIFEST);
    }

    function testPolicySuccessionSourceMutationAfterSealBlocksQueuedCutoverAtomically() public {
        _start();
        _twoPolicies();
        _completeImport();
        (StreamGovernanceStagePlan.Plan memory plan,) = _cutover();
        bytes32 id = _schedule(plan);
        _retuneSourceFee(1);
        require(!_ready(), "live source header no longer matches sealed receipt");
        BeforeCutover memory before_ = _before();
        vm.warp(plan.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.InvalidSatellitePointer.selector, ENTROPY, address(successor)
            )
        );
        configuration.executor.executeGovernanceBatch(id, plan.batch.calls, plan.batch.callDatas);
        bytes memory signed = _signedExecution(plan, id);
        vm.expectRevert();
        this.submitSigned(signed);
        _assertUnchanged(before_, id);
        require(
            C(address(successor)).entropyPolicyImport().state == C.ImportState.SEALED,
            "stale session remains sealed; it is not reset for an impossible retry"
        );
    }

    function testPolicySuccessionWrongRevisionAndActivationBeforePointerAreRefused() public {
        _start();
        _begin();
        _seal();
        C.ImportReceipt memory receipt = C(address(successor)).entropyPolicyImport();
        require(
            !C(address(successor))
                .entropyPolicyImportReady(
                    address(source),
                    address(source).codehash,
                    receipt.pointerRevision + 1,
                    receipt.count,
                    receipt.serial,
                    receipt.idDigest
                ),
            "readiness binds the actual original pointer revision"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            C(address(successor)).entropyPolicyImportActivationTransition();
        bytes memory data = abi.encodeCall(C.activateEntropyPolicyImport, ());
        StreamGovernanceStagePlan.Plan memory early = _build(
            REASON,
            _one(
                3,
                StreamCurrentStackPlan.call(address(successor), data, scope, oldHash, newHash),
                data
            )
        );
        bytes32 earlyId = _schedule(early);
        BeforeCutover memory before_ = _before();
        vm.warp(early.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(C.EntropyPolicyImportSourceChanged.selector, address(source))
        );
        configuration.executor
            .executeGovernanceBatch(earlyId, early.batch.calls, early.batch.callDatas);
        bytes memory signed = _signedExecution(early, earlyId);
        vm.expectRevert();
        this.submitSigned(signed);
        _assertUnchanged(before_, earlyId);
        (StreamGovernanceStagePlan.Plan memory proper,) = _cutover();
        _run(proper);
        require(
            C(address(successor)).entropyPolicyImport().state == C.ImportState.ACTIVE,
            "later exact pointer then activation succeeds"
        );
    }

    function testPolicySuccessionMissingManifestTailCannotBeScheduled() public {
        _start();
        _begin();
        _seal();
        (StreamGovernanceStagePlan.Plan memory complete,) = _cutover();
        GenesisBatch memory missing;
        missing.actionClass = 3;
        missing.calls = new GovernanceCall[](2);
        missing.callDatas = new bytes[](2);
        for (uint256 i; i < 2; ++i) {
            missing.calls[i] = complete.batch.calls[i];
            missing.callDatas[i] = complete.batch.callDatas[i];
        }
        StreamGovernanceStagePlan.Plan memory invalid = _build(REASON, missing);
        StreamGovernanceStagePlan.NextCall memory publication = StreamGovernanceStagePlan.publication(
            invalid, StreamGovernanceStagePlan.planHash(invalid)
        );
        require(executeSafe(governor, signers, publication.target, 0, publication.data, 0));
        StreamGovernanceStagePlan.NextCall memory scheduling = StreamGovernanceStagePlan.scheduling(
            invalid, StreamGovernanceStagePlan.planHash(invalid)
        );
        BeforeCutover memory before_ = _before();
        vm.expectRevert();
        this.safeCall(scheduling.target, scheduling.data);
        require(
            governor.nonce() == before_.safeNonce && _pointerHash() == before_.pointerHash
                && _manifestHash() == before_.manifestHash,
            "unschedulable tail omission has no effects"
        );
    }

    function testPolicySuccessionActivationFaultRollsBackWholeBatchAndIdenticalSignedRetry()
        public
    {
        _start();
        _begin();
        _seal();
        (StreamGovernanceStagePlan.Plan memory plan,) = _cutover();
        bytes32 id = _schedule(plan);
        C.ImportReceipt memory sealedReceipt = C(address(successor)).entropyPolicyImport();
        BeforeCutover memory before_ = _before();
        bytes memory signed = _signedExecution(plan, id);
        EntropySuccessionFaultVm fault = EntropySuccessionFaultVm(address(vm));
        fault.mockCallRevert(
            address(successor), abi.encodeCall(C.activateEntropyPolicyImport, ()), bytes("")
        );
        vm.warp(plan.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.GovernanceCallFailed.selector, id, 1)
        );
        configuration.executor.executeGovernanceBatch(id, plan.batch.calls, plan.batch.callDatas);
        vm.expectRevert();
        this.submitSigned(signed);
        _assertUnchanged(before_, id);
        fault.clearMockedCalls();
        require(this.submitSigned(signed), "identical Safe packet after activation fault clears");
        _assertActivated(sealedReceipt, id, before_);
    }

    function testPolicySuccessionManifestFaultRollsBackActivationAndIdenticalSignedRetry() public {
        _start();
        _twoPolicies();
        _completeImport();
        (StreamGovernanceStagePlan.Plan memory plan, address payload) = _cutover();
        bytes32 id = _schedule(plan);
        C.ImportReceipt memory sealedReceipt = C(address(successor)).entropyPolicyImport();
        BeforeCutover memory before_ = _before();
        bytes memory signed = _signedExecution(plan, id);
        bytes memory originalCode = payload.code;
        vm.etch(payload, hex"00");
        vm.warp(plan.notBefore);
        // This ordinary payload error bubbles from the actual final publication leaf.
        EntropySuccessionFaultVm(address(vm))
            .expectCall(address(configuration.manifest), plan.batch.callDatas[2]);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.InvalidManifestTail.selector)
        );
        configuration.executor.executeGovernanceBatch(id, plan.batch.calls, plan.batch.callDatas);
        vm.expectRevert();
        this.submitSigned(signed);
        _assertUnchanged(before_, id);
        vm.etch(payload, originalCode);
        require(this.submitSigned(signed), "identical Safe packet and original payload retry");
        _assertActivated(sealedReceipt, id, before_);
    }

    function _start() private {
        _initialize();
        source = _deployCoordinator("urn:fixture:entropy-source");
        successor = _deployCoordinator("urn:fixture:entropy-successor");
        originalProvider = new MockStreamEntropyProvider(address(source));
        require(
            address(source).code.length <= 24576 && address(successor).code.length <= 24576,
            "actual deployable Coordinator runtimes"
        );
        _admitCatalog();
        _register(source);
        _register(successor);
        GenesisBatch memory select;
        select.actionClass = 3;
        bytes32[] memory kinds = new bytes32[](1);
        kinds[0] = ENTROPY;
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamEntropyFallbackPlan.record(source, 500000);
        (select.calls, select.callDatas) = StreamCurrentStackPlan.pointerCalls(
            configuration.core, configuration.registry, kinds, records
        );
        _run(_build(REASON, _withTail(select)));
        (GovernanceCall memory call_, bytes memory data) = StreamEntropyLifecyclePlan.activate(
            source, address(originalProvider), "urn:original-provider"
        );
        _run(_build(REASON, _one(1, call_, data)));
        (call_, data) = StreamEntropyLifecyclePlan.activate(
            successor, address(originalProvider), "urn:original-provider"
        );
        _run(_build(REASON, _one(1, call_, data)));
    }

    function _deployCoordinator(string memory uri) private returns (StreamEntropyCoordinator) {
        return new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(configuration.core),
                address(configuration.executor),
                address(configuration.roles),
                StreamCurrentStackPlan.entropyTimeParameters(),
                configuration.deploymentHash,
                uri,
                keccak256(bytes(uri))
            )
        );
    }

    function _register(StreamEntropyCoordinator target) private {
        GenesisBatch memory batch;
        batch.actionClass = 1;
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamEntropyFallbackPlan.record(target, 500000);
        (batch.calls, batch.callDatas) =
            StreamCurrentStackPlan.registrationCalls(configuration.registry, records);
        // The five-leaf foundation has no registerModule tail trigger. An unsolicited
        // class-1 publication is invalid; initial pointer selection publishes the new host.
        _run(_build(REASON, batch));
    }

    function _admitCatalog() private {
        StreamEntropyCoordinator[] memory origins = new StreamEntropyCoordinator[](1);
        origins[0] = source;
        GovernanceActionPolicyEntry[] memory succession =
            StreamEntropyPolicySuccessionPlan.catalogRows(
                successor, origins, configuration.deploymentHash
            );
        require(succession.length == 4, "three candidate rows and one exact origin");
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](7);
        rows[0] = _row(1, address(source), source.activateEntropyProvider.selector);
        rows[1] = _row(1, address(successor), successor.activateEntropyProvider.selector);
        rows[2] = _row(1, address(source), source.configureCollection.selector);
        for (uint256 i; i < succession.length; ++i) {
            rows[3 + i] = succession[i];
        }
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(configuration.executor, rows);
        (address payload, StreamSystemManifestUpdate memory update) = _publication();
        (GenesisBatch memory batch, uint256 count) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            configuration.manifest,
            payload,
            update
        );
        require(count == 7, "exact finite catalog additions");
        _run(_build(REASON, batch));
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
            0
        );
    }

    function _key(GovernanceActionPolicyEntry memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }

    function _twoPolicies() private {
        for (uint256 id = 1; id <= 3; ++id) {
            (GovernanceCall memory call_, bytes memory data) =
                StreamCurrentStackPlan.createCollectionCall(configuration.core, id, 10);
            _run(_build(REASON, _one(1, call_, data)));
        }
        _configure(1);
        _configure(3);
        StreamArtistActivationPlan.Plan memory grants = StreamRevealActivationPlan.build(
            configuration.roles,
            StreamRevealActivationPlan.Principals(
                address(governor), address(governor), address(governor)
            )
        );
        GenesisBatch memory grantBatch = GenesisBatch(1, grants.calls, grants.callDatas);
        _run(_build(REASON, grantBatch));
        require(
            this.safeCall(
                address(source),
                abi.encodeCall(
                    source.configureCollectionRevealPolicy,
                    (1, uint8(0), keccak256("ROLE_ENTROPY_REVEAL_OWNER"), uint64(100), uint256(0))
                )
            ),
            "actual granted Safe configures declared reveal"
        );
    }

    function _configure(uint256 id) private {
        StreamEntropyFallbackPlan.Collection memory row = StreamEntropyFallbackPlan.Collection(
            id,
            address(originalProvider),
            keccak256(abi.encode(id)),
            true,
            100,
            0,
            keccak256("ROLE_ENTROPY_REVEAL_OWNER"),
            100,
            0
        );
        (GovernanceCall memory call_, bytes memory data) =
            StreamEntropyFallbackPlan.configureCollection(source, row);
        _run(_build(REASON, _one(1, call_, data)));
    }

    function _retuneSourceFee(uint256 amount) private {
        require(
            this.safeCall(
                address(source), abi.encodeCall(source.updateRevealFeePerToken, (1, amount))
            ),
            "real entropy administrator retunes fee"
        );
    }

    function _begin() private returns (bytes32) {
        return _run(
            _build(
                REASON, StreamEntropyPolicySuccessionPlan.begin(source, successor, IMPORT_MANIFEST)
            )
        );
    }

    function _seal() private returns (bytes32) {
        return _run(_build(REASON, StreamEntropyPolicySuccessionPlan.seal(successor)));
    }

    function _route(uint256 id) private {
        _run(_build(REASON, StreamEntropyPolicySuccessionPlan.admitRoute(source, successor, id)));
        C(address(successor)).confirmEntropyRelayRoute(id);
    }

    function _completeImport() private {
        _begin();
        C(address(successor)).importNextEntropyPolicy(0);
        C(address(successor)).importNextEntropyPolicy(1);
        _route(1);
        _route(3);
        _seal();
    }

    function _cutover()
        private
        returns (StreamGovernanceStagePlan.Plan memory plan, address payload)
    {
        StreamSystemManifestUpdate memory update;
        (payload, update) = _publication();
        GenesisBatch memory batch = StreamEntropyPolicySuccessionPlan.cutover(
            configuration.core,
            configuration.registry,
            source,
            successor,
            configuration.manifest,
            payload,
            update
        );
        plan = _build(REASON, batch);
    }

    function _withTail(GenesisBatch memory batch) private returns (GenesisBatch memory) {
        (address payload, StreamSystemManifestUpdate memory update) = _publication();
        return StreamEntropyFallbackPlan.withManifestTail(
            batch, configuration.manifest, payload, update
        );
    }

    function _publication()
        private
        returns (address payload, StreamSystemManifestUpdate memory update)
    {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(configuration.manifest);
        bytes32 hash;
        (payload, hash) = StreamGenesisManifestPlan.writePayload(
            bytes('{"purpose":"current entropy policy succession","scope":"governance foundation"}')
        );
        update = StreamSystemManifestUpdate(
            hash,
            "urn:fixture:entropy-policy-succession",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
    }

    function _one(uint8 cls, GovernanceCall memory call_, bytes memory data)
        private
        pure
        returns (GenesisBatch memory batch)
    {
        batch.actionClass = cls;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.calls[0] = call_;
        batch.callDatas[0] = data;
    }

    function _run(StreamGovernanceStagePlan.Plan memory plan) private returns (bytes32 id) {
        id = _schedule(plan);
        vm.warp(plan.notBefore);
        require(this.submitSigned(_signedExecution(plan, id)), "delayed actual Safe batch");
        require(
            configuration.executor.governanceAction(id).status == GovernanceActionStatus.EXECUTED
        );
    }

    function _signedExecution(StreamGovernanceStagePlan.Plan memory plan, bytes32 id)
        private
        returns (bytes memory)
    {
        bytes memory data = abi.encodeCall(
            configuration.executor.executeGovernanceBatch,
            (id, plan.batch.calls, plan.batch.callDatas)
        );
        bytes32 digest = governor.getTransactionHash(
            address(configuration.executor),
            0,
            data,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            governor.nonce()
        );
        return abi.encodeCall(
            governor.execTransaction,
            (
                address(configuration.executor),
                0,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(signers, digest)
            )
        );
    }

    function submitSigned(bytes calldata signed) external returns (bool) {
        require(msg.sender == address(this));
        (bool ok, bytes memory result) = address(governor).call(signed);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        return abi.decode(result, (bool));
    }

    function safeCall(address target, bytes calldata data) external returns (bool) {
        require(msg.sender == address(this));
        return executeSafe(governor, signers, target, 0, data, 0);
    }

    function _ready() private view returns (bool) {
        (uint256 count, uint64 serial, bytes32 digest) = C(address(source)).entropyPolicyInventory();
        return C(address(successor))
            .entropyPolicyImportReady(
                address(source),
                address(source).codehash,
                StreamCurrentStackPlan.readPointer(configuration.core, ENTROPY).revision,
                count,
                serial,
                digest
            );
    }

    function _before() private view returns (BeforeCutover memory) {
        return BeforeCutover(
            _pointerHash(),
            keccak256(abi.encode(C(address(successor)).entropyPolicyImport())),
            _manifestHash(),
            configuration.manifest.streamSystemManifestPointerCount(),
            governor.nonce()
        );
    }

    function _pointerHash() private view returns (bytes32) {
        return
            keccak256(abi.encode(StreamCurrentStackPlan.readPointer(configuration.core, ENTROPY)));
    }

    function _manifestHash() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                StreamGenesisManifestPlan.readAggregate(configuration.manifest),
                configuration.manifest.streamSystemManifestPointer()
            )
        );
    }

    function _assertUnchanged(BeforeCutover memory before_, bytes32 id) private view {
        require(
            _pointerHash() == before_.pointerHash && _manifestHash() == before_.manifestHash,
            "Core pointer and complete manifest rolled back"
        );
        require(
            keccak256(abi.encode(C(address(successor)).entropyPolicyImport()))
                == before_.receiptHash,
            "complete receipt and activation action ID rolled back"
        );
        require(
            configuration.manifest.streamSystemManifestPointerCount() == before_.manifestCount
                && governor.nonce() == before_.safeNonce,
            "manifest history and Safe nonce unchanged"
        );
        require(
            configuration.executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED,
            "original queued action remains retryable"
        );
    }

    function _assertActivated(
        C.ImportReceipt memory sealedReceipt,
        bytes32 id,
        BeforeCutover memory before_
    ) private view {
        C.ImportReceipt memory active = C(address(successor)).entropyPolicyImport();
        sealedReceipt.state = C.ImportState.ACTIVE;
        sealedReceipt.activationActionId = id;
        require(
            keccak256(abi.encode(active)) == keccak256(abi.encode(sealedReceipt)),
            "exact latched activation receipt"
        );
        StreamCorePointerState memory pointer =
            StreamCurrentStackPlan.readPointer(configuration.core, ENTROPY);
        require(
            pointer.target == address(successor) && pointer.codeHash == address(successor).codehash
                && pointer.revision == sealedReceipt.pointerRevision + 1,
            "exact next current pointer"
        );
        require(
            StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules
                    .entropyCoordinator == address(successor),
            "manifest names actual selected successor"
        );
        require(
            configuration.manifest.streamSystemManifestPointerCount() == before_.manifestCount + 1
                && governor.nonce() == before_.safeNonce + 1,
            "one publication and one Safe execution"
        );
        require(
            configuration.executor.governanceAction(id).status == GovernanceActionStatus.EXECUTED,
            "exact original action completed"
        );
        require(
            !C(address(successor))
                .entropyPolicyImportReady(
                    sealedReceipt.predecessor,
                    sealedReceipt.predecessorCodeHash,
                    sealedReceipt.pointerRevision,
                    sealedReceipt.count,
                    sealedReceipt.serial,
                    sealedReceipt.idDigest
                ),
            "ACTIVE refuses readiness even with all six original matching coordinates"
        );
    }

    function _assertExport(uint256 id, C.PolicyExport memory original) private view {
        require(
            keccak256(abi.encode(C(address(successor)).exportEntropyPolicy(id)))
                == keccak256(abi.encode(original)),
            "byte-exact full policy export"
        );
        (bytes32 imported, bytes32 exported, address origin, bytes32 pin, bytes32 hash) =
            C(address(successor)).importedEntropyPolicy(id);
        require(
            imported == C(address(successor)).entropyPolicyImport().importHash
                && exported == keccak256(abi.encode(original)) && origin == address(source)
                && pin == address(source).codehash && hash == original.record.policyHash,
            "exact import witness"
        );
        require(
            original.record.artistConsentRecord == 0 && original.record.lastActionId == 0,
            "LEGACY import invents no Artist or explicit action receipt"
        );
    }

    function _assertPointerRefused() private {
        GenesisBatch memory pointer = StreamEntropyFallbackPlan.selection(
            configuration.core, configuration.registry, source, successor
        );
        StreamGovernanceStagePlan.Plan memory plan = _build(REASON, _withTail(pointer));
        bytes32 id = _schedule(plan);
        BeforeCutover memory before_ = _before();
        vm.warp(plan.notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.InvalidSatellitePointer.selector, ENTROPY, address(successor)
            )
        );
        configuration.executor.executeGovernanceBatch(id, plan.batch.calls, plan.batch.callDatas);
        bytes memory signed = _signedExecution(plan, id);
        vm.expectRevert();
        this.submitSigned(signed);
        _assertUnchanged(before_, id);
    }

    function _assertCutoverPlan(StreamGovernanceStagePlan.Plan memory plan) private view {
        require(
            plan.batch.actionClass == 3 && plan.batch.calls.length == 3, "one exact class3 batch"
        );
        require(
            plan.batch.calls[0].target == address(configuration.core)
                && plan.batch.calls[0].selector
                    == configuration.core.updateSatellitePointer.selector
                && plan.batch.calls[1].target == address(successor)
                && plan.batch.calls[1].selector == C.activateEntropyPolicyImport.selector
                && plan.batch.calls[2].target == address(configuration.manifest)
                && plan.batch.calls[2].selector
                    == configuration.manifest.publishStreamSystemManifest.selector,
            "pointer then activation then required manifest tail"
        );
    }

    function _assertActivationEvents(Vm.Log[] memory logs, bytes32 id, bytes32 importHash)
        private
        view
    {
        uint256 pointers;
        uint256 activations;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(configuration.core) && logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256(
                            "CoreSatellitePointerUpdated(uint16,bytes32,bytes32,address,address)"
                        )
            ) {
                require(
                    logs[i].topics[1] == ENTROPY && logs[i].topics[2] == id
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(successor)))),
                    "exact pointer event"
                );
                ++pointers;
            }
            if (
                logs[i].emitter == address(successor) && logs[i].topics.length == 2
                    && logs[i].topics[0]
                        == keccak256("EntropyPolicyImportActivated(uint16,bytes32,bytes32)")
            ) {
                (uint16 schema, bytes32 action) = abi.decode(logs[i].data, (uint16, bytes32));
                require(
                    schema == 1 && action == id && logs[i].topics[1] == importHash,
                    "exact activation event"
                );
                ++activations;
            }
        }
        require(pointers == 1 && activations == 1, "one actual pointer and activation event");
    }
}
