// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../current/StreamCurrentMintContinuity.t.sol";
import { StreamMintFallbackPlan } from "../../script/current/StreamMintFallbackPlan.sol";
import {
    StreamMintManagerFallback
} from "../../smart-contracts/domains/mint/StreamMintManagerFallback.sol";

/// @dev Same authoritative Ledger fallback rehearsal with actual current stack and Safe governance.
/// Reuses independently reconstructed import/signature assertions from the existing continuity suite.
/// The lifetime test gate and external entropy provider remain explicit fixture boundaries.
abstract contract StreamMintFallbackFixture is StreamCurrentSafeGovernanceFixture {
    bytes32 internal constant CONTINUITY_PHASE = keccak256("current continuity phase");
    bytes32 internal constant GLOBAL_COUNTER = keccak256("global recipient lifetime");
    bytes32 internal constant COLLECTION_COUNTER = keccak256("collection lifetime");
    bytes32 internal constant CLAIM = keccak256("original lifetime claim");
    bytes32 internal constant SNAPSHOT_MANIFEST = keccak256("complete local continuity manifest");
    bytes32 internal constant MANAGER_POINTER = keccak256("MINT_MANAGER");
    bytes32 internal constant LEDGER_POINTER = keccak256("MINT_LEDGER");
    bytes32 internal constant MODULE_VERSION = keccak256("current continuity v1");
    bytes32 internal constant GATE_MANIFEST = keccak256("explicit test entitlement boundary");

    StreamMintLedger internal nextLedger;
    StreamMintManager internal successor;
    CurrentContinuityEntitlementGate internal gate;
    OfficialSafe internal continuitySafe;
    uint256[] internal signingKeys;
    bytes32 internal globalDefinition;
    bytes32 internal collectionDefinition;
    bytes32 internal paidOperation;
    bytes32 internal originalAuthorization;
    bytes32 internal originalOperation;
    IStreamMintLedgerImport.CounterImportLeaf[] internal leaves;
    bytes32[15] internal tree;
    uint64 internal snapshotBlock;

    bool internal preparedExecution;
    uint64 internal reserveActivatedAt;
    StreamMintFallbackPlan.Configuration internal reserve;
    uint256 internal pendingAuctionToken;
    address internal originalArtistManager;

    function _deployAdditionalProducts() internal virtual override {
        nextLedger = ledger;
        successor = _deployReserveManager();
        ledger.setLedgerWriter(address(successor), true);
        successor.transferOwnership(address(executor));
        gate = new CurrentContinuityEntitlementGate(
            address(core), address(manager), address(successor), CONTINUITY_PHASE
        );
    }

    function _deployReserveManager() internal virtual returns (StreamMintManager deployed) {
        deployed = StreamMintManager(
            _artistArtifactCreate(
                "smart-contracts/domains/mint/StreamMintManagerFallback.sol:StreamMintManagerFallback",
                abi.encode(core, ledger, IERC165(address(registry)))
            )
        );
        _assertDeployableProductionInstance(address(deployed));
    }

    function _additionalOperatingPolicies()
        internal
        view
        virtual
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](9);
        rows[0] = _fallbackPolicy(address(ledger), ledger.retireLedgerWriter.selector);
        rows[0].actionClass = 0;
        rows[1] = _fallbackPolicy(address(ledger), ledger.commitCounterImportRoot.selector);
        rows[2] = _fallbackPolicy(address(successor), successor.importMintState.selector);
        rows[3] = _fallbackPolicy(address(successor), successor.configurePhase.selector);
        rows[4] = _fallbackPolicy(address(successor), successor.setPhaseExecutor.selector);
        rows[5] = _fallbackPolicy(address(successor), successor.raiseGasParameter.selector);
        rows[6] = _fallbackPolicy(address(ledger), ledger.importCounterDefinitions.selector);
        rows[7] = _fallbackPolicy(address(ledger), ledger.importMintAncestors.selector);
        rows[8] = _fallbackPolicy(address(ledger), ledger.completeCounterImport.selector);
    }

    function _fallbackPolicy(address target, bytes4 selector)
        internal
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1, target, selector, target.codehash, DEPLOYMENT_HASH, 1, 0, 0, 0
        );
    }

    /// @dev Finishes reserve admission in the deployment ceremony, before operational exposure.
    function _handoffManager() internal virtual override {
        super._handoffManager();
        reserve = _reserveConfiguration();
        (GovernanceCall memory classifier, bytes memory classifierData) =
            StreamMintFallbackPlan.retirementClassificationCall(reserve);
        GovernanceActionRequest memory classifierRequest = _governanceRequest(
            1,
            classifier.target,
            classifierData,
            classifier.scopeHash,
            classifier.oldValueHash,
            classifier.newValueHash
        );
        bytes memory classified = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(executor.scheduleGovernanceAction, (classifierRequest))
        );
        vm.warp(classifierRequest.notBefore);
        executor.executeGovernanceAction(abi.decode(classified, (bytes32)), classifierData);
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](2);
        records[0] = StreamMintFallbackPlan.fallbackRegistration(reserve);
        records[1] = StreamModuleRegistration(
            address(gate),
            keccak256("6529STREAM_MINT_GATE_V1"),
            MODULE_VERSION,
            type(IStreamMintGate).interfaceId,
            300_000,
            address(gate).codehash,
            DEPLOYMENT_HASH,
            GATE_MANIFEST,
            "urn:stream:fixture:lifetime-entitlement"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        executor.publishGovernanceCallData(data);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        uint64 ready = uint64(block.timestamp + executor.minimumDelay(1));
        bytes memory result = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(
                executor.scheduleGovernanceBatch,
                (
                    uint8(1),
                    calls,
                    scope,
                    oldHash,
                    newHash,
                    ready,
                    ready + 7 days,
                    keccak256("genesis mint fallback reserve"),
                    "urn:stream:fixture:mint-fallback-reserve",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(result, (bytes32)), calls, data);
        StreamMintFallbackPlan.requireReserveReady(reserve);
        reserveActivatedAt = registry.moduleRecord(address(successor)).registeredAt;
    }

    function _reserveConfiguration()
        internal
        view
        returns (StreamMintFallbackPlan.Configuration memory c)
    {
        c.chainId = block.chainid;
        c.core = core;
        c.ledger = ledger;
        c.primary = manager;
        c.fallbackManager = successor;
        c.registry = registry;
        c.governance = address(executor);
        c.coreCodeHash = address(core).codehash;
        c.ledgerCodeHash = address(ledger).codehash;
        c.primaryCodeHash = address(manager).codehash;
        c.fallbackCodeHash = address(successor).codehash;
        c.registryCodeHash = address(registry).codehash;
        c.governanceCodeHash = address(executor).codehash;
        c.moduleVersion = MODULE_VERSION;
        c.deploymentManifestHash = DEPLOYMENT_HASH;
        c.moduleManifestHash = keccak256("genesis shared-ledger fallback Manager");
        c.moduleManifestURI = "urn:stream:fixture:genesis-mint-fallback";
        c.moduleGasLimit = 300_000;
    }

    function _executePlanned(uint8 cls, GovernanceCall memory call_, bytes memory data)
        internal
        returns (bytes32)
    {
        GovernanceActionRequest memory request = _governanceRequest(
            cls, call_.target, data, call_.scopeHash, call_.oldValueHash, call_.newValueHash
        );
        if (cls != 0) return _govern(request);
        bytes32 id = _scheduleAsGovernor(request);
        _executeAsGovernor(id, data);
        return id;
    }

    /// @dev Incident status changes require their own real class-0 manifest tail.
    function _revokePrimary() internal {
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            _statusTransition(address(manager), ModuleRegistryStatus.INCIDENT_REVOKED);
        data[0] = abi.encodeCall(
            registry.setModuleStatus,
            (
                address(manager),
                ModuleRegistryStatus.INCIDENT_REVOKED,
                keccak256("rehearsed primary incident"),
                "urn:stream:fixture:mint-incident"
            )
        );
        calls[0] = StreamCurrentStackPlan.call(address(registry), data[0], scope, oldHash, newHash);
        StreamSystemManifest.AggregateState memory aggregate =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 content) = StreamGenesisManifestPlan.writePayload(
            abi.encode(
                "actual primary incident status",
                address(manager),
                ModuleRegistryStatus.INCIDENT_REVOKED
            )
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            content,
            "urn:stream:fixture:mint-incident",
            aggregate.discovery.eventCatalogHash,
            aggregate.discovery.compatibilityMatrixHash,
            aggregate.discovery.numericIdCatalogHash,
            aggregate.discovery.schemaCatalogHash,
            aggregate.discovery.canonicalizationCatalogHash,
            aggregate.discovery.specBundleHash,
            aggregate.discovery.reconstructionClientHash
        );
        (calls[1], data[1]) =
            StreamGenesisManifestPlan.publicationCall(manifest, payload, update, aggregate.modules);
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(0, calls, data);
        require(ready == block.timestamp, "class0 tightening is immediate");
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "actual incident status batch"
        );
    }

    function _activateFallback() internal {
        StreamMintFallbackPlan.requireReserveReady(reserve);
        uint256 catalogCount = registry.moduleCount();
        bytes32 ledgerPointerBefore =
            keccak256(abi.encode(StreamCurrentStackPlan.readPointer(core, LEDGER_POINTER)));
        _revokePrimary();
        uint256 observed = block.timestamp;
        require(reserveActivatedAt < observed, "ACTIVE reserve preceded actual incident");
        _retireAndSnapshot();
        (GovernanceCall[] memory imports, bytes[] memory importData) = _importPlan();
        (bytes32 importAction, uint64 importReady) =
            _scheduleBatchAsGovernor(1, imports, importData);
        (GovernanceCall[] memory activation, bytes[] memory activationData) = _activationPlan();
        (bytes32 activationAction, uint64 ready) =
            _scheduleBatchAsGovernor(3, activation, activationData);
        require(block.timestamp <= observed + 4 hours, "standing fallback scheduled within SLA");
        require(
            ready == observed + executor.minimumDelay(3) && importReady == ready,
            "parallel ordinary delays, no emergency bypass"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                activationAction,
                ready
            )
        );
        executor.executeGovernanceBatch(activationAction, activation, activationData);
        bytes32 before_ = _baseline();
        vm.warp(ready);
        // Core rejects an admitted reserve until the exact real import completes.
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(
                executor.executeGovernanceBatch, (activationAction, activation, activationData)
            )
        );
        require(
            _baseline() == before_
                && StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER).target
                    == address(manager),
            "incomplete import leaves pointer and receipts intact"
        );
        require(
            executor.governanceAction(activationAction).status == GovernanceActionStatus.SCHEDULED,
            "exact failed scheduled action remains retryable"
        );
        // Permissionless execution uses the original real proof data at the already elapsed delay.
        executor.executeGovernanceBatch(importAction, imports, importData);
        _assertImported();
        require(
            ledger.isMintSuccessorReady(address(ledger), address(manager), address(successor)),
            "complete authoritative same-Ledger import"
        );
        executor.executeGovernanceBatch(activationAction, activation, activationData);
        require(
            block.timestamp == ready && registry.moduleCount() == catalogCount,
            "earliest allowed activation without incident registration cycle"
        );
        require(
            StreamCurrentStackPlan.readPointer(core, MANAGER_POINTER).target == address(successor),
            "actual fallback selected"
        );
        require(
            keccak256(abi.encode(StreamCurrentStackPlan.readPointer(core, LEDGER_POINTER)))
                == ledgerPointerBefore,
            "canonical Ledger pointer and revision unchanged"
        );
        StreamSystemManifest.AggregateState memory aggregate =
            StreamGenesisManifestPlan.readAggregate(manifest);
        require(
            aggregate.modules.mintManager == address(successor)
                && aggregate.modules.mintLedger == address(ledger),
            "atomic manifest tail reflects cutover"
        );
        require(
            _baseline() == before_ && !ledger.ledgerWriter(address(manager))
                && ledger.ledgerWriterRetiredAt(address(manager)) != 0,
            "old receipts, nonces and real retirement preserved"
        );
    }

    function _retireAndSnapshot() internal {
        (GovernanceCall memory call_, bytes memory data) =
            StreamMintFallbackPlan.retirementCall(reserve);
        _executePlanned(0, call_, data);
        _buildTree();
    }

    function _importPlan()
        internal
        view
        returns (GovernanceCall[] memory calls, bytes[] memory data)
    {
        calls = new GovernanceCall[](5);
        data = new bytes[](5);
        (calls[0], data[0]) = StreamMintFallbackPlan.importCommitCall(
            reserve, StreamMintFallbackPlan.Snapshot(snapshotBlock, tree[0], SNAPSHOT_MANIFEST)
        );
        (calls[1], data[1]) = StreamMintFallbackPlan.copyDefinitionsCall(reserve, tree[0], 32);
        (calls[2], data[2]) = StreamMintFallbackPlan.copyAncestorsCall(reserve, tree[0], 32);
        IStreamMintManagerImport.ImportBatch memory batch;
        batch.importRoot = tree[0];
        batch.counters = leaves;
        batch.counterProofs = new bytes32[][](leaves.length);
        for (uint256 i; i < leaves.length; ++i) {
            batch.counterProofs[i] = _proof(i);
        }
        batch.nullifiers = new bytes32[](1);
        batch.nullifiers[0] = gate.claimNullifier(CLAIM);
        batch.nullifierProofs = new bytes32[][](1);
        batch.nullifierProofs[0] = _proof(leaves.length);
        (calls[3], data[3]) = StreamMintFallbackPlan.importStateCall(reserve, batch);
        (calls[4], data[4]) = StreamMintFallbackPlan.completeImportCall(
            reserve, tree[0], uint64(leaves.length), 1, _proof(leaves.length + 1)
        );
    }

    function _activationPlan()
        internal
        returns (GovernanceCall[] memory calls, bytes[] memory data)
    {
        return _activationPlan(0, bytes32(0));
    }

    function _activationPlan(uint256 incidentToken, bytes32 incidentOperation)
        internal
        returns (GovernanceCall[] memory calls, bytes[] memory data)
    {
        StreamSystemManifest.AggregateState memory aggregate =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (address payload, bytes32 content) = StreamGenesisManifestPlan.writePayload(
            abi.encode(
                "genesis standing mint fallback activation",
                address(manager),
                address(successor),
                address(ledger)
            )
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            content,
            "urn:stream:fixture:mint-fallback-activation",
            aggregate.discovery.eventCatalogHash,
            aggregate.discovery.compatibilityMatrixHash,
            aggregate.discovery.numericIdCatalogHash,
            aggregate.discovery.schemaCatalogHash,
            aggregate.discovery.canonicalizationCatalogHash,
            aggregate.discovery.specBundleHash,
            aggregate.discovery.reconstructionClientHash
        );
        if (incidentToken == 0) {
            return StreamMintFallbackPlan.activationCalls(reserve, manifest, payload, update);
        }
        return StreamMintFallbackPlan.incidentActivationCalls(
            reserve, manifest, payload, update, incidentToken, incidentOperation
        );
    }

    function _paidMint() internal {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            IStreamFixedPriceSaleAdapter.SaleAuthorization({
                collectionId: 1,
                phaseId: PHASE,
                payer: address(this),
                recipient: BUYER,
                artist: artist,
                profileId: profile,
                expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256("paid before succession"),
                mintPolicyHash: manager.phasePolicyHash(1, PHASE),
                price: 0.01 ether,
                nonce: keccak256("paid baseline"),
                deadline: uint64(block.timestamp + 1 days),
                signerEpoch: sale.signerEpoch()
            });
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        (uint256 tokenId, bytes32 operation) = sale.buy{ value: a.price }(
            a, TOKEN_DATA, abi.encodePacked(r, s, v), _artistProof(digest)
        );
        require(
            tokenId == 1 && core.ownerOf(tokenId) == BUYER && wallet.balance == a.price,
            "real paid baseline"
        );
        paidOperation = operation;
    }

    function _phaseTerms()
        internal
        view
        returns (
            IStreamMintManager.MintPhaseConfig memory config,
            IStreamMintManager.MintGateConfig memory gateConfig,
            bytes32[] memory ids,
            IStreamMintManager.MintCounterConfig[] memory configs
        )
    {
        config = IStreamMintManager.MintPhaseConfig(
            false,
            0,
            0,
            1,
            keccak256("lifetime eligibility terms"),
            keccak256("published eligibility scope")
        );
        gateConfig = IStreamMintManager.MintGateConfig(
            address(gate),
            keccak256("test entitlement config"),
            address(gate).codehash,
            keccak256(abi.encode(MODULE_VERSION, GATE_MANIFEST)),
            0,
            300_000
        );
        ids = new bytes32[](2);
        ids[0] = GLOBAL_COUNTER;
        ids[1] = COLLECTION_COUNTER;
        configs = new IStreamMintManager.MintCounterConfig[](2);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            2,
            1,
            globalDefinition
        );
        configs[1] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            2,
            1,
            collectionDefinition
        );
    }

    function _configure(StreamMintManager target) internal {
        (
            IStreamMintManager.MintPhaseConfig memory config,
            IStreamMintManager.MintGateConfig memory gateConfig,
            bytes32[] memory ids,
            IStreamMintManager.MintCounterConfig[] memory configs
        ) = _phaseTerms();
        address[] memory enabled = new address[](0);
        _recordFixturePolicy(
            CONTINUITY_PHASE,
            target.previewPhasePolicyHash(
                1, CONTINUITY_PHASE, config, gateConfig, ids, configs, enabled
            )
        );
        _ordinary(
            address(target),
            abi.encodeCall(
                target.configurePhase, (1, CONTINUITY_PHASE, config, gateConfig, ids, configs)
            )
        );
        enabled = new address[](1);
        enabled[0] = address(continuitySafe);
        _recordFixturePolicy(
            CONTINUITY_PHASE,
            target.previewPhasePolicyHash(
                1, CONTINUITY_PHASE, config, gateConfig, ids, configs, enabled
            )
        );
        _ordinary(
            address(target),
            abi.encodeCall(
                target.setPhaseExecutor, (1, CONTINUITY_PHASE, address(continuitySafe), true)
            )
        );
    }

    function _mintRequest(StreamMintManager target, bytes32 claim, bytes32 nonce)
        internal
        view
        returns (IStreamMintManager.MintBatch memory batch, bytes memory gateData)
    {
        batch.collectionId = 1;
        batch.phaseId = CONTINUITY_PHASE;
        batch.payer = BUYER;
        batch.initialRecipients = new address[](1);
        batch.initialRecipients[0] = BUYER;
        batch.beneficiaries = new address[](1);
        batch.beneficiaries[0] = BUYER;
        batch.tokenData = new bytes[](1);
        batch.tokenData[0] = TOKEN_DATA;
        batch.mintCommitments = new bytes32[](1);
        batch.mintCommitments[0] = keccak256(abi.encode("continuity mint", nonce));
        batch.expectedPolicyHash = target.phasePolicyHash(1, CONTINUITY_PHASE);
        batch.contextHash = keccak256("original lifetime eligibility namespace");
        batch.authorizationId =
            gate.authorization(address(target), address(continuitySafe), batch, claim, nonce);
        gateData = abi.encode(claim, nonce);
    }

    function _ordinary(address target, bytes memory data) internal returns (bytes32) {
        return _govern(
            _governanceRequest(
                1, target, data, keccak256(abi.encode(target, data)), 0, keccak256(data)
            )
        );
    }

    function _runBatch(uint8 cls, GovernanceCall[] memory calls, bytes[] memory data) internal {
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(cls, calls, data);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "executed batch"
        );
    }

    function _subject(
        StreamMintLedger target,
        IStreamMintLedgerImport.CounterImportLeaf memory leaf
    ) internal view returns (bytes32) {
        if (leaf.keyMode == uint8(IStreamMintManager.CounterKeyMode.RECIPIENT)) {
            return keccak256(
                abi.encode(
                    keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                    block.chainid,
                    address(target),
                    IStreamMintManager.CounterKeyMode.RECIPIENT,
                    BUYER
                )
            );
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                block.chainid,
                address(target),
                IStreamMintManager.CounterKeyMode.CONSTANT,
                leaf.collectionId,
                leaf.phaseId,
                leaf.counterId
            )
        );
    }

    function _buildTree() internal {
        delete leaves;
        snapshotBlock = uint64(block.number);
        leaves.push(
            IStreamMintLedgerImport.CounterImportLeaf(
                1,
                PHASE,
                keccak256("supply"),
                uint8(IStreamMintManager.CounterKeyMode.CONSTANT),
                0,
                0,
                1
            )
        );
        leaves.push(
            IStreamMintLedgerImport.CounterImportLeaf(
                0,
                0,
                GLOBAL_COUNTER,
                uint8(IStreamMintManager.CounterKeyMode.RECIPIENT),
                bytes32(uint256(uint160(BUYER))),
                0,
                1
            )
        );
        leaves.push(
            IStreamMintLedgerImport.CounterImportLeaf(
                1, 0, COLLECTION_COUNTER, uint8(IStreamMintManager.CounterKeyMode.CONSTANT), 0, 0, 1
            )
        );
        if (pendingAuctionToken != 0) {
            leaves.push(
                IStreamMintLedgerImport.CounterImportLeaf(
                    1,
                    AUCTION_PHASE,
                    keccak256("supply"),
                    uint8(IStreamMintManager.CounterKeyMode.CONSTANT),
                    0,
                    0,
                    1
                )
            );
        }
        for (uint256 i; i < leaves.length; ++i) {
            leaves[i].predecessorSubjectKey = _subject(ledger, leaves[i]);
            require(
                _value(ledger, manager, leaves[i]) == 1, "snapshot reads actual predecessor counter"
            );
            tree[7 + i] = keccak256(
                bytes.concat(
                    keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_COUNTER_IMPORT_LEAF_V1"),
                            block.chainid,
                            address(ledger),
                            address(manager),
                            leaves[i]
                        )
                    )
                )
            );
        }
        tree[7 + leaves.length] = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_NULLIFIER_IMPORT_LEAF_V1"),
                        block.chainid,
                        address(ledger),
                        address(manager),
                        gate.claimNullifier(CLAIM)
                    )
                )
            )
        );
        tree[8 + leaves.length] = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MINT_IMPORT_MANIFEST_LEAF_V1"),
                        block.chainid,
                        address(nextLedger),
                        address(ledger),
                        address(manager),
                        address(successor),
                        snapshotBlock,
                        SNAPSHOT_MANIFEST,
                        uint64(leaves.length),
                        uint64(1)
                    )
                )
            )
        );
        // Explicit padding repeats the genuine count descriptor, never synthetic accounting leaves.
        for (uint256 i = 9 + leaves.length; i < 15; ++i) {
            tree[i] = tree[8 + leaves.length];
        }
        for (uint256 i = 7; i > 0; --i) {
            tree[i - 1] = _pair(tree[2 * i - 1], tree[2 * i]);
        }
    }

    function _pair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    function _proof(uint256 index) internal view returns (bytes32[] memory proof) {
        proof = new bytes32[](3);
        uint256 node = 7 + index;
        for (uint256 i; i < 3; ++i) {
            proof[i] = tree[node % 2 == 0 ? node - 1 : node + 1];
            node = (node - 1) / 2;
        }
    }

    function _value(
        StreamMintLedger target,
        StreamMintManager writer,
        IStreamMintLedgerImport.CounterImportLeaf memory leaf
    ) internal view returns (uint64) {
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                address(writer),
                leaf.collectionId,
                leaf.phaseId,
                leaf.counterId,
                _subject(target, leaf)
            )
        );
        return target.counterValue(key);
    }

    function _assertImported() internal view {
        for (uint256 i; i < leaves.length; ++i) {
            require(
                _value(nextLedger, successor, leaves[i]) == leaves[i].value, "every imported floor"
            );
            require(_value(ledger, manager, leaves[i]) == leaves[i].value, "predecessor retained");
        }
        require(
            nextLedger.isManagerNullifierUsed(address(successor), gate.claimNullifier(CLAIM)),
            "raw entitlement carried forward"
        );
        require(
            ledger.isManagerNullifierUsed(address(manager), gate.claimNullifier(CLAIM)),
            "original raw entitlement retained"
        );
        require(
            ledger.managerDefinitionCount(address(manager))
                == nextLedger.managerDefinitionCount(address(successor)),
            "complete profile inventory"
        );
        for (uint256 i; i < ledger.managerDefinitionCount(address(manager)); ++i) {
            (
                bytes32 oldHash,
                bool oldDefined,
                IStreamMintCounterPolicy.Definition memory oldDefinition
            ) = ledger.managerDefinitionAt(address(manager), i);
            (
                bytes32 newHash,
                bool newDefined,
                IStreamMintCounterPolicy.Definition memory newDefinition
            ) = nextLedger.managerDefinitionAt(address(successor), i);
            require(
                oldHash == newHash && oldDefined == newDefined
                    && keccak256(abi.encode(oldDefinition)) == keccak256(abi.encode(newDefinition)),
                "exact profile interpretations"
            );
        }
    }

    function _raiseSuccessorArtistBudget(uint256 nextValue) internal {
        bytes32 parameter = successor.GGP_ARTIST_AUTHORITY_GAS_LIMIT();
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            successor.gasParameterInfo(parameter);
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"),
                block.chainid,
                address(successor),
                parameter
            )
        );
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        _govern(
            _governanceRequest(
                1,
                address(successor),
                abi.encodeCall(successor.raiseGasParameter, (parameter, nextValue)),
                scope,
                keccak256(abi.encode(domain, scope, value, floor, failureClass, revision)),
                keccak256(abi.encode(domain, scope, nextValue, floor, failureClass, revision + 1))
            )
        );
    }

    function _literalPolicyDigest(
        T.PolicyConsent memory policy,
        T.Authorization memory auth,
        address anchor
    ) internal view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamArtistRegistry"),
                keccak256("1"),
                block.chainid,
                address(artists)
            )
        );
        bytes32 message = keccak256(
            abi.encode(
                keccak256(
                    "StreamArtistPolicyConsent(address core,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 policyHash,uint256 nonce,uint64 deadline)"
                ),
                address(core),
                anchor,
                policy.collectionId,
                policy.phaseId,
                policy.policyHash,
                auth.nonce,
                auth.time
            )
        );
        return keccak256(abi.encodePacked(hex"1901", domain, message));
    }

    function _recordSuccessorConsent(bytes32 policyHash) internal {
        T.PolicyConsent memory policy = T.PolicyConsent(1, CONTINUITY_PHASE, policyHash);
        T.Authorization memory auth = _artistAuthorization(false);
        bytes32 originalDigest = _literalPolicyDigest(policy, auth, originalArtistManager);
        require(
            artists.policyConsentDigest(policy, auth) == originalDigest
                && originalDigest != _literalPolicyDigest(policy, auth, address(successor)),
            "new policy uses exact original Artist signature domain"
        );
        auth.signature = _artistProof(originalDigest);
        artists.recordPolicyConsent(policy, auth);
        (bool accepted, bytes32 evidence) =
            artists.isPolicyConsented(1, CONTINUITY_PHASE, policyHash);
        require(accepted && evidence != 0, "actual signed successor policy receipt");
        vm.expectRevert();
        artists.recordPolicyConsent(policy, auth);
    }

    function _configureSuccessorWithFreshConsent() internal {
        require(
            artists.mintManager() == originalArtistManager
                && nextLedger.isCompletedMintDescendant(
                    address(ledger), originalArtistManager, address(successor)
                ),
            "original Artist anchor and completed actual lineage"
        );
        _raiseSuccessorArtistBudget(300_000);
        _raiseSuccessorArtistBudget(600_000);
        (
            IStreamMintManager.MintPhaseConfig memory config,
            IStreamMintManager.MintGateConfig memory gateConfig,
            bytes32[] memory ids,
            IStreamMintManager.MintCounterConfig[] memory configs
        ) = _phaseTerms();
        bytes32 originalPolicy =
            StreamMintManager(originalArtistManager).phasePolicyHash(1, CONTINUITY_PHASE);
        (bool originalAccepted, bytes32 originalEvidence) =
            artists.isPolicyConsented(1, CONTINUITY_PHASE, originalPolicy);
        require(originalAccepted && originalEvidence != 0, "predecessor policy remains consented");
        address[] memory enabled = new address[](0);
        bytes32 newPolicy = successor.previewPhasePolicyHash(
            1, CONTINUITY_PHASE, config, gateConfig, ids, configs, enabled
        );
        (bool alreadyAccepted,) = artists.isPolicyConsented(1, CONTINUITY_PHASE, newPolicy);
        require(
            !alreadyAccepted && newPolicy != originalPolicy, "lineage does not copy policy consent"
        );
        bytes memory data = abi.encodeCall(
            successor.configurePhase, (1, CONTINUITY_PHASE, config, gateConfig, ids, configs)
        );
        GovernanceActionRequest memory request = _governanceRequest(
            1,
            address(successor),
            data,
            keccak256(abi.encode(address(successor), data)),
            0,
            keccak256(data)
        );
        bytes32 action = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        require(
            !successor.hasRegisteredPhasePolicy(1)
                && successor.phasePolicyHash(1, CONTINUITY_PHASE) == 0
                && nextLedger.registeredPhasePolicyHash(address(successor), 1, CONTINUITY_PHASE)
                    == 0,
            "missing fresh consent rolls back phase and Ledger registration"
        );
        _recordSuccessorConsent(newPolicy);
        _executeAsGovernor(action, data);
        enabled = new address[](1);
        enabled[0] = address(continuitySafe);
        bytes32 executablePolicy = successor.previewPhasePolicyHash(
            1, CONTINUITY_PHASE, config, gateConfig, ids, configs, enabled
        );
        require(
            executablePolicy != newPolicy && executablePolicy != originalPolicy,
            "executor admission requires its own exact policy"
        );
        _recordSuccessorConsent(executablePolicy);
        _ordinary(
            address(successor),
            abi.encodeCall(
                successor.setPhaseExecutor, (1, CONTINUITY_PHASE, address(continuitySafe), true)
            )
        );
        (bool stillAccepted, bytes32 stillEvidence) =
            artists.isPolicyConsented(1, CONTINUITY_PHASE, originalPolicy);
        require(
            stillAccepted && stillEvidence == originalEvidence
                && successor.phasePolicyHash(1, CONTINUITY_PHASE) == executablePolicy,
            "original receipt retained alongside fresh successor policy"
        );
        _assertImported();
    }

    function _signedSuccessorCall(IStreamMintManager.MintBatch memory batch, bytes memory gateData)
        internal
        returns (bytes memory)
    {
        bytes memory data = preparedExecution
            ? abi.encodeCall(successor.executePreparedMint, (batch, gateData))
            : abi.encodeCall(successor.executeSingleStepMint, (batch, gateData));
        bytes32 digest = continuitySafe.getTransactionHash(
            address(successor), 0, data, 0, 0, 0, 0, address(0), address(0), continuitySafe.nonce()
        );
        return abi.encodeCall(
            continuitySafe.execTransaction,
            (
                address(successor),
                0,
                data,
                uint8(0),
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(signingKeys, digest)
            )
        );
    }

    function _assertSuccessorFailure(
        IStreamMintManager.MintBatch memory batch,
        bytes32 baseline,
        uint256 safeNonce,
        bytes32 unspentClaim
    ) internal view {
        require(
            _baseline() == baseline && continuitySafe.nonce() == safeNonce,
            "failed signed Safe call leaves all mint and envelope state unchanged"
        );
        require(
            !nextLedger.isManagerAuthorizationUsed(address(successor), batch.authorizationId),
            "failed successor authorization not consumed"
        );
        if (unspentClaim != 0) {
            require(
                !nextLedger.isManagerNullifierUsed(
                    address(successor), gate.claimNullifier(unspentClaim)
                ),
                "new claim remains available"
            );
        }
    }

    function _baseline() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                core.totalSupply(),
                core.collectionMintedEver(1),
                core.lastAllocatedTokenId(),
                core.ownerOf(1),
                core.ownerOf(2),
                manager.nextOperationNonce(),
                successor.nextOperationNonce(),
                wallet.balance,
                ledger.isManagerOperationRootUsed(address(manager), paidOperation),
                ledger.isManagerAuthorizationUsed(address(manager), originalAuthorization),
                ledger.isManagerOperationRootUsed(address(manager), originalOperation)
            )
        );
    }

    function _setupFallback() internal {
        vm.roll(20);
        vm.deal(address(this), 1 ether);
        signingKeys.push(0xC01101);
        signingKeys.push(0xC01102);
        continuitySafe = createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(signingKeys), 2, 651
        );
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        _assertPlannedEntropyProfile();
        originalArtistManager = address(manager);
        _installGovernorSafe(continuitySafe, signingKeys);
        _paidMint();
        globalDefinition = ledger.registerCounterDefinition(
            IStreamMintCounterPolicy.Definition(
                IStreamMintCounterPolicy.CounterScope.GLOBAL,
                IStreamMintManager.CounterKeyMode.RECIPIENT,
                0,
                keccak256("global profile")
            )
        );
        collectionDefinition = ledger.registerCounterDefinition(
            IStreamMintCounterPolicy.Definition(
                IStreamMintCounterPolicy.CounterScope.COLLECTION,
                IStreamMintManager.CounterKeyMode.CONSTANT,
                0,
                keccak256("collection profile")
            )
        );
        _configure(manager);
        (IStreamMintManager.MintBatch memory batch, bytes memory data) =
            _mintRequest(manager, CLAIM, keccak256("original authorization nonce"));
        originalAuthorization = batch.authorizationId;
        vm.recordLogs();
        this.executeCurrentGovernorCall(
            address(manager), abi.encodeCall(manager.executeSingleStepMint, (batch, data))
        );
        require(core.collectionMintedEver(1) == 2 && core.ownerOf(2) == BUYER, "actual second mint");
        require(
            ledger.isManagerNullifierUsed(address(manager), gate.claimNullifier(CLAIM)),
            "gate consumed normally"
        );
        require(
            ledger.isManagerAuthorizationUsed(address(manager), originalAuthorization),
            "original authorization consumed"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventTopic = keccak256(
            "MintLedgerOperationRootConsumed(uint16,bytes32,address,bytes32,bytes32,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(ledger) && logs[i].topics.length == 4
                    && logs[i].topics[0] == eventTopic
                    && logs[i].topics[2] == bytes32(uint256(uint160(address(manager))))
            ) {
                require(originalOperation == 0, "one operation");
                originalOperation = logs[i].topics[1];
            }
        }
        require(
            originalOperation != 0 && manager.isOperationRootUsed(originalOperation),
            "event-derived actual operation"
        );
        snapshotBlock = uint64(block.number);
    }

    /// @dev Read the actual Core value separately from its floor. Candidate calibration remains
    /// owned by the shared launch plan; this fixture neither substitutes the floor nor raises gas.
    function _assertPlannedEntropyProfile() internal view {
        bytes32 parameter = 0x51125071e3dfb233a2711689d4cc377bbda429f1356ebc09a58d763548541e17;
        StreamCore.GasParameterGenesisConfig[] memory planned =
            StreamCurrentStackPlan.gasParameters();
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            core.gasParameterInfo(parameter);
        bool found;
        for (uint256 i; i < planned.length; ++i) {
            if (planned[i].parameterId != parameter) continue;
            require(!found, "unique planned entropy parameter");
            found = true;
            require(
                value == planned[i].genesisValue && floor == planned[i].floor
                    && failureClass == planned[i].failureClass && failureClass == 2
                    && revision == 1,
                "actual entropy allowance and floor match the candidate plan"
            );
        }
        require(found, "planned entropy parameter exists");
    }

    function _storedRecordFactsHash(
        StreamModuleRecord memory record,
        ModuleRegistryStatus status,
        uint64 revision
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(status),
                record.moduleType,
                record.moduleVersion,
                record.interfaceId,
                record.moduleGasLimit,
                record.runtimeCodeHash,
                record.deploymentManifestHash,
                record.moduleManifestHash,
                keccak256(bytes(record.moduleManifestURI)),
                revision
            )
        );
    }

    function _statusTransition(address moduleAddress, ModuleRegistryStatus newStatus)
        internal
        view
        returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)
    {
        StreamModuleRecord memory record = registry.moduleRecord(moduleAddress);
        (bytes32 chainHash, uint64 recordCount) = registry.registrationChainHash();
        scopeHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_SCOPE_V1(),
                uint256(block.chainid),
                address(registry),
                moduleAddress
            )
        );
        oldValueHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scopeHash,
                _storedRecordFactsHash(record, record.status, record.revision),
                registry.moduleCount(),
                chainHash,
                recordCount
            )
        );
        newValueHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scopeHash,
                _storedRecordFactsHash(record, newStatus, record.revision + 1),
                registry.moduleCount(),
                chainHash,
                recordCount
            )
        );
    }
}
