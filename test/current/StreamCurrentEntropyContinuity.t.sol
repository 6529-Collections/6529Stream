// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../../script/current/StreamEntropyFallbackPlan.sol";
import {
    IStreamEntropyRecoveryPolicies as EntropyRecoveryPolicyTypes
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";

/// @notice Actual Core/Manager/Ledger/Artist/Registry/Executor/Safe continuity and paid mint recipes.
/// @dev Only upstream randomness uses MockStreamEntropyProvider. No typed Core or governance bypass.
contract StreamCurrentEntropyContinuityTest is StreamCurrentStackFixture, OfficialSafeFixture {
    StreamEntropyCoordinator private backup;
    MockStreamEntropyProvider private backupProvider;
    OfficialSafe private buyerSafe;
    uint256[] private keys;
    uint256 private purchaseNonce;
    uint256 private stageNonce;
    mapping(bytes32 => bytes32) private saved;
    bytes32 private constant ENTROPY = keccak256("ENTROPY_COORDINATOR");
    bytes32 private constant REASON = keccak256("entropy continuity fixture");

    function setUp() public {
        keys.push(0xEE001);
        keys.push(0xEE002);
        buyerSafe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 0xEE003);
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        vm.deal(address(buyerSafe), 20 ether);
        _installSafeGovernor();
        _execute(_plan(StreamEntropyFallbackPlan.registration(registry, entropy, backup, 500000)));
        (GovernanceCall memory call_, bytes memory data) = StreamEntropyLifecyclePlan.activate(
            backup, address(backupProvider), "urn:backup-provider"
        );
        _one(1, call_, data);
        (call_, data) = StreamEntropyFallbackPlan.configureCollection(backup, _collection());
        _one(1, call_, data);
        StreamGovernanceStagePlan.NextCall memory reveal =
            StreamEntropyFallbackPlan.revealConfiguration(backup, _collection(), address(this));
        (bool ok,) = reveal.target.call(reveal.data);
        require(ok, "real current role configures reveal");
        _generic(address(entropy), abi.encodeCall(entropy.setRequester, (address(this), true)));
        _generic(address(backup), abi.encodeCall(backup.setRequester, (address(this), true)));
    }

    function _deployAdditionalProducts() internal override {
        StreamEntropyCoordinator.DeploymentConfig memory c =
            StreamEntropyFallbackPlan.deploymentConfig(
                entropy,
                StreamCurrentStackPlan.entropyTimeParameters(),
                DEPLOYMENT_HASH,
                "urn:fixture:ordinary-backup",
                keccak256("ordinary backup module")
            );
        backup = StreamEntropyCoordinator(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator",
                    abi.encode(c)
                ))
        );
        backupProvider = MockStreamEntropyProvider(
            payable(_artistArtifactCreate(
                    "test/mocks/MockStreamEntropyProvider.sol:MockStreamEntropyProvider",
                    abi.encode(address(backup))
                ))
        );
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](6);
        rows[0] = _row(address(backup), backup.activateEntropyProvider.selector);
        rows[1] = _row(address(backup), backup.configureCollection.selector);
        rows[2] = _row(address(backup), backup.setRequester.selector);
        rows[3] = _row(address(entropy), entropy.configureFreshRecoveryPolicyV2.selector);
        rows[4] = _row(address(entropy), entropy.freezeFreshRecoveryPolicy.selector);
        rows[5] = _row(address(entropy), entropy.configureCollectionFreshRecovery.selector);
    }

    function _row(address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1,
            target,
            selector,
            target.codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, target)),
            1,
            0,
            0,
            0
        );
    }

    function _collection() private view returns (StreamEntropyFallbackPlan.Collection memory) {
        return StreamEntropyFallbackPlan.Collection(
            1,
            address(backupProvider),
            keccak256("backup salt"),
            true,
            100,
            0,
            keccak256("ROLE_ENTROPY_REVEAL_OWNER"),
            100,
            0
        );
    }

    function _plan(GenesisBatch memory batch)
        private
        returns (StreamGovernanceStagePlan.Plan memory)
    {
        if (
            batch.calls[0].selector == core.updateSatellitePointer.selector
                || batch.calls[0].selector == registry.registerModule.selector
        ) {
            StreamSystemManifest.AggregateState memory current =
                StreamGenesisManifestPlan.readAggregate(manifest);
            (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
                bytes("{\"purpose\":\"entropy continuity fixture; supplied inventory only\"}")
            );
            StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
                hash,
                "urn:fixture:entropy-continuity",
                current.discovery.eventCatalogHash,
                current.discovery.compatibilityMatrixHash,
                current.discovery.numericIdCatalogHash,
                current.discovery.schemaCatalogHash,
                current.discovery.canonicalizationCatalogHash,
                current.discovery.specBundleHash,
                current.discovery.reconstructionClientHash
            );
            batch = StreamEntropyFallbackPlan.withManifestTail(batch, manifest, payload, update);
        }
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(batch.actionClass) + 1 hours);
        return StreamGovernanceStagePlan.build(
            executor,
            keccak256(abi.encode(REASON, ++stageNonce)),
            batch,
            ready,
            ready + 7 days,
            REASON,
            "urn:fixture:entropy-continuity",
            DEPLOYMENT_HASH
        );
    }

    function _one(uint8 cls, GovernanceCall memory call_, bytes memory data) private {
        GenesisBatch memory batch;
        batch.actionClass = cls;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.calls[0] = call_;
        batch.callDatas[0] = data;
        _execute(_plan(batch));
    }

    function _generic(address target, bytes memory data) private {
        _one(
            1,
            StreamCurrentStackPlan.call(
                target, data, keccak256(abi.encode(target, data)), 0, keccak256(data)
            ),
            data
        );
    }

    function _schedule(StreamGovernanceStagePlan.Plan memory p) private returns (bytes32 id) {
        bytes32 hash = StreamGovernanceStagePlan.planHash(p);
        StreamGovernanceStagePlan.NextCall memory c = StreamGovernanceStagePlan.publication(p, hash);
        require(executeSafe(buyerSafe, keys, c.target, c.value, c.data, 0));
        c = StreamGovernanceStagePlan.scheduling(p, hash);
        vm.recordLogs();
        require(executeSafe(buyerSafe, keys, c.target, c.value, c.data, 0));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(executor) && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(id == 0);
                id = logs[i].topics[1];
            }
        }
        require(id != 0);
        saved[id] = hash;
    }

    function _execute(StreamGovernanceStagePlan.Plan memory p) private {
        bytes32 id = _schedule(p);
        vm.expectRevert();
        this.executeSaved(p, id);
        vm.warp(p.notBefore);
        require(this.executeSaved(p, id));
    }

    function executeSaved(StreamGovernanceStagePlan.Plan memory p, bytes32 id)
        external
        returns (bool)
    {
        return StreamGovernanceStagePlan.execute(p, id, saved[id]);
    }

    function _buy() private returns (uint256 token) {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            IStreamFixedPriceSaleAdapter.SaleAuthorization(
                1,
                PHASE,
                address(buyerSafe),
                address(buyerSafe),
                artist,
                profile,
                _nativePrimaryPolicyHash(),
                keccak256(TOKEN_DATA),
                REASON,
                manager.phasePolicyHash(1, PHASE),
                0.01 ether,
                bytes32(++purchaseNonce),
                uint64(block.timestamp + 1 days),
                sale.signerEpoch()
            );
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 rr, bytes32 ss) = vm.sign(PLATFORM_KEY, digest);
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(sale),
                a.price,
                abi.encodeCall(
                    sale.buy, (a, TOKEN_DATA, abi.encodePacked(rr, ss, v), _artistProof(digest))
                ),
                0
            )
        );
        token = core.lastAllocatedTokenId();
        require(core.ownerOf(token) == address(buyerSafe));
    }

    function _bindV2() private {
        bytes32 id = keccak256("current frozen continuity");
        EntropyRecoveryPolicyTypes.FreshRecoveryStep[] memory steps =
            new EntropyRecoveryPolicyTypes.FreshRecoveryStep[](1);
        steps[0] = EntropyRecoveryPolicyTypes.FreshRecoveryStep(
            address(provider), 3, provider.streamEntropyProviderConfigHash(), 100, true
        );
        bytes32 oldHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1"),
                block.chainid,
                address(entropy),
                id,
                uint16(1),
                keccak256("ROLE_ENTROPY_INCIDENT_DECLARER"),
                REASON,
                REASON,
                keccak256(
                    abi.encode(keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1"), steps)
                )
            )
        );
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V2"),
                block.chainid,
                address(entropy),
                address(core),
                id,
                oldHash,
                address(backup),
                address(backup).codehash
            )
        );
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            entropy.freshRecoveryPolicyV2Transition(id, hash);
        bytes memory data = abi.encodeCall(
            entropy.configureFreshRecoveryPolicyV2,
            (
                id,
                1,
                keccak256("ROLE_ENTROPY_INCIDENT_DECLARER"),
                REASON,
                REASON,
                steps,
                address(backup),
                address(backup).codehash
            )
        );
        _one(1, StreamCurrentStackPlan.call(address(entropy), data, scope, before_, after_), data);
        (scope, before_, after_) = entropy.freshRecoveryPolicyTransition(id, hash, true);
        data = abi.encodeCall(entropy.freezeFreshRecoveryPolicy, (id));
        _one(1, StreamCurrentStackPlan.call(address(entropy), data, scope, before_, after_), data);
        (scope, before_, after_) = entropy.collectionFreshRecoveryTransition(1, 1, id);
        data = abi.encodeCall(entropy.configureCollectionFreshRecovery, (1, 1, id));
        _one(1, StreamCurrentStackPlan.call(address(entropy), data, scope, before_, after_), data);
    }

    function testActualSafeFallbackWithCoveredTokenAndScopePreservesOldFulfillmentAndNewMints()
        public
    {
        _bindV2();
        uint256 old = _buy();
        (, uint256 requestId) = entropy.requestEntropy(old);
        bytes32 scope = entropy.registerEntropyScope(1, 1, REASON);
        (, uint256 scopeId) = entropy.requestScopeEntropy(scope, REASON);
        require(
            entropy.pendingRequestCount() == 2
                && entropy.uncoveredPendingRequestCount(address(backup), address(backup).codehash)
                    == 0
        );
        StreamEntropyFallbackPlan.Collection[] memory rows =
            new StreamEntropyFallbackPlan.Collection[](1);
        rows[0] = _collection();
        StreamEntropyFallbackPlan.Checkpoint memory cp = StreamEntropyFallbackPlan.checkpoint(
            entropy, backup, rows, keccak256(abi.encode(old, scope, address(entropy)))
        );
        require(
            cp.primary == address(entropy) && cp.backup == address(backup)
                && cp.primary != cp.backup
        );
        _execute(_plan(StreamEntropyFallbackPlan.selection(core, registry, entropy, backup)));
        uint256 next = _buy();
        require(
            core.coordinatorAtMint(old) == address(entropy)
                && core.coordinatorAtMint(next) == address(backup)
        );
        require(
            backup.tokenEntropyStatus(next) == StreamEntropyStatus.REGISTERED
                && entropy.tokenEntropyStatus(next) == StreamEntropyStatus.NONE
        );
        require(
            provider.fulfill(requestId, REASON) == 0
                && provider.fulfill(scopeId, keccak256("scope output")) == 0
        );
        (bytes32 seed, bool final_) = entropy.tokenSeed(old);
        require(final_ && seed != 0);
        require(
            !entropy.metadataNotificationPending(old),
            "old route remains actual Core refresh authority"
        );
        bytes32 uri = keccak256(bytes(core.tokenURI(old)));
        vm.expectRevert();
        backup.requestEntropy(old);
        vm.expectRevert();
        entropy.registerEntropyScope(1, 1, keccak256("new old-host scope"));
        _execute(_plan(StreamEntropyFallbackPlan.selection(core, registry, backup, entropy)));
        require(
            core.coordinatorAtMint(next) == address(backup)
                && keccak256(bytes(core.tokenURI(old))) == uri
        );
        uint256 third = _buy();
        require(core.coordinatorAtMint(third) == address(entropy));
    }

    function testRequestAfterSchedulingBlocksExecutionUntilOriginalFulfillmentThenExactPlanRetries()
        public
    {
        uint256 token = _buy();
        StreamGovernanceStagePlan.Plan memory plan =
            _plan(StreamEntropyFallbackPlan.selection(core, registry, entropy, backup));
        bytes32 id = _schedule(plan);
        (, uint256 requestId) = entropy.requestEntropy(token);
        require(
            entropy.uncoveredPendingRequestCount(address(backup), address(backup).codehash) == 1
        );
        vm.warp(plan.notBefore);
        uint256 nonce = buyerSafe.nonce();
        vm.expectRevert();
        this.executeSafeSaved(plan, id);
        require(
            buyerSafe.nonce() == nonce
                && StreamCurrentStackPlan.readPointer(core, ENTROPY).target == address(entropy)
        );
        require(executor.governanceAction(id).status == GovernanceActionStatus.SCHEDULED);
        require(provider.fulfill(requestId, REASON) == 0);
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(executor),
                0,
                abi.encodeCall(
                    executor.executeGovernanceBatch, (id, plan.batch.calls, plan.batch.callDatas)
                ),
                0
            )
        );
        require(StreamCurrentStackPlan.readPointer(core, ENTROPY).target == address(backup));
    }

    function testFallbackPlanRuntimeDriftRefusesWithoutChangingHistoricalEntropy() public {
        uint256 token = _buy();
        (, uint256 requestId) = entropy.requestEntropy(token);
        require(provider.fulfill(requestId, REASON) == 0);
        (bytes32 seed,) = entropy.tokenSeed(token);
        StreamGovernanceStagePlan.Plan memory plan =
            _plan(StreamEntropyFallbackPlan.selection(core, registry, entropy, backup));
        bytes32 id = _schedule(plan);
        bytes memory runtime = address(backup).code;
        vm.etch(address(backup), hex"60006000fd");
        vm.warp(plan.notBefore);
        vm.expectRevert();
        this.executeSaved(plan, id);
        require(StreamCurrentStackPlan.readPointer(core, ENTROPY).target == address(entropy));
        (bytes32 retained,) = entropy.tokenSeed(token);
        require(retained == seed);
        vm.etch(address(backup), runtime);
        require(this.executeSaved(plan, id));
    }

    function executeSafeSaved(StreamGovernanceStagePlan.Plan memory plan, bytes32 id)
        external
        returns (bool)
    {
        require(msg.sender == address(this));
        return executeSafe(
            buyerSafe,
            keys,
            address(executor),
            0,
            abi.encodeCall(
                executor.executeGovernanceBatch, (id, plan.batch.calls, plan.batch.callDatas)
            ),
            0
        );
    }

    function _installSafeGovernor() private {
        (address previous, bytes32 hash, uint64 revision) = executor.governanceRootState();
        bytes memory data = abi.encodeCall(
            executor.rotateGovernanceRoot, (address(buyerSafe), address(buyerSafe).codehash)
        );
        GovernanceActionRequest memory request = _request(address(executor), data);
        request.actionClass = 3;
        request.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_GOVERNANCE_ROOT_SCOPE_V1"), block.chainid, address(executor)
            )
        );
        request.oldValueHash = _rootState(previous, hash, revision);
        request.newValueHash =
            _rootState(address(buyerSafe), address(buyerSafe).codehash, revision + 1);
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(abi.decode(result, (bytes32)), data);
        (address root,,) = executor.governanceRootState();
        require(root == address(buyerSafe), "actual canonical Safe governor");
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

    function _request(address target, bytes memory data)
        private
        view
        returns (GovernanceActionRequest memory)
    {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        return GovernanceActionRequest(
            1,
            target,
            0,
            selector,
            data,
            0,
            0,
            0,
            uint64(block.timestamp + 48 hours),
            uint64(block.timestamp + 9 days),
            keccak256("entropy continuity governance"),
            "urn:stream:fixture:entropy-continuity",
            DEPLOYMENT_HASH
        );
    }
}
