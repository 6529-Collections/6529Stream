// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistSuiteFixture.sol";
import "../../smart-contracts/core/StreamCore.sol";
import "../../smart-contracts/domains/governance/StreamGovernanceExecutor.sol";
import "../../smart-contracts/domains/governance/StreamGovernanceActor.sol";
import "../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import "../../smart-contracts/domains/governance/StreamSystemManifest.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamStateExportPublisher.sol";
import "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol";
import "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../script/current/StreamCurrentStackPlan.sol";
import "../../script/current/StreamArtistActivationPlan.sol";
import "../../script/current/StreamGenesisManifestPlan.sol";
import "../mocks/MockStreamEntropyProvider.sol";

/// @notice One real current-stack topology. Only the external entropy service is a test double.
abstract contract StreamCurrentStackFixture is StreamArtistSuiteFixture {
    uint256 internal constant ARTIST_KEY = 0xA47157;
    uint256 internal constant PLATFORM_KEY = 0x6529;
    address internal constant BUYER = address(0xB0B);
    address internal constant SECOND_OWNER = address(0xCAFE);
    address internal constant PROTOCOL = address(0xFEE);
    bytes32 internal constant PHASE = keccak256("current-stack fixed price");
    bytes32 internal constant AUCTION_PHASE = keccak256("current-stack auction");
    bytes internal constant TOKEN_DATA = "current-stack artwork";
    bytes32 internal constant DEPLOYMENT_HASH = keccak256("current-stack integration fixture v1");
    bytes32 internal constant REGISTRY_HASH = keccak256("current-stack fixture registry v1");

    StreamCore internal core;
    StreamGovernanceExecutor internal executor;
    StreamGovernanceActor internal governanceRoot;
    StreamRoleRegistry internal roles;
    StreamModuleRegistry internal registry;
    StreamSystemManifest internal manifest;
    StreamMintManager internal manager;
    StreamMintLedger internal ledger;
    StreamFixedPriceSaleAdapter internal sale;
    StreamEnglishAuctionHouse internal auction;
    StreamSplitFactory internal factory;
    StreamAssetPolicyRegistry internal assetPolicy;
    StreamRevenueEscrow internal revenueEscrow;
    StreamEntropyCoordinator internal entropy;
    MockStreamEntropyProvider internal provider;
    address internal artist;
    address internal wallet;
    bytes32 internal profile;
    address[] internal guardians;

    function _deployCurrentStack(address artist_, address platform) internal {
        artist = artist_;
        executor = new StreamGovernanceExecutor(address(this));
        governanceRoot = new StreamGovernanceActor(address(this));
        guardians = new address[](2);
        guardians[0] = address(new StreamGovernanceActor(address(this)));
        guardians[1] = address(new StreamGovernanceActor(address(this)));
        if (guardians[0] > guardians[1]) {
            (guardians[0], guardians[1]) = (guardians[1], guardians[0]);
        }
        roles = new StreamRoleRegistry(address(executor));
        registry =
            new StreamModuleRegistry(executor, REGISTRY_HASH, "urn:6529stream:fixture:registry");
        core = new StreamCore(
            "6529 Stream",
            "STREAM",
            address(executor),
            StreamCore.GenesisModuleRegistryConfig(
                address(registry), address(registry).codehash, REGISTRY_HASH, DEPLOYMENT_HASH
            ),
            StreamCurrentStackPlan.gasParameters()
        );
        manifest = new StreamSystemManifest(address(core), address(executor));
        ledger = new StreamMintLedger();
        manager = new StreamMintManager(core, ledger, IERC165(address(registry)));
        ledger.setLedgerWriter(address(manager), true);
        assetPolicy = new StreamAssetPolicyRegistry(address(executor));
        factory = new StreamSplitFactory(assetPolicy, address(executor), _walletGasConfigs());
        _deployArtistSuite(
            address(core),
            address(manager),
            address(roles),
            factory,
            address(executor),
            DEPLOYMENT_HASH
        );
        IStreamArtistAttribution attribution = IStreamArtistAttribution(address(artists));
        revenueEscrow = new StreamRevenueEscrow(
            factory,
            address(executor),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3)
        );
        sale = new StreamFixedPriceSaleAdapter(
            manager, primaryResolver, platform, attribution, revenueEscrow
        );
        auction = new StreamEnglishAuctionHouse(
            core, manager, primaryResolver, platform, attribution, revenueEscrow
        );
        entropy = new StreamEntropyCoordinator(
            address(core),
            address(executor),
            DEPLOYMENT_HASH,
            "urn:6529stream:fixture:entropy",
            keccak256("fixture entropy module")
        );
        provider = new MockStreamEntropyProvider(address(entropy));
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(PROTOCOL, 100_000, keccak256("protocol"));
        (profile, wallet) = factory.createProfile(entries, keccak256("fixture split"));
        _deployAdditionalProducts();
        ledger.transferOwnership(address(executor));
        sale.transferOwnership(address(executor));
        auction.transferOwnership(address(executor));
        _assertDeployableProductionContracts();
        _initializeProductGenesis();
        _activateArtistAuthority();
        _prepareArtistOnboarding();
        _onboardFixtureArtist(artist);
        _configureMintPhase(PHASE, address(sale));
        _configureMintPhase(AUCTION_PHASE, address(auction));
        _configureAdditionalProducts();
        _handoffManager();
    }

    /// @dev Operator scenarios can retain their real initial owner until setup completes.
    function _handoffManager() internal virtual {
        manager.transferOwnership(address(executor));
    }

    function _artistProof(bytes32 digest) internal virtual override returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ARTIST_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _walletGasConfigs()
        internal
        pure
        returns (IStreamGasParameterHost.GasParameterConfig[3] memory rows)
    {
        rows[0] = IStreamGasParameterHost.GasParameterConfig(
            "ERC_1271_GAS_LIMIT", 400_000, 350_000, 2
        );
        rows[1] =
            IStreamGasParameterHost.GasParameterConfig("ASSET_POLICY_GAS_LIMIT", 30_000, 15_000, 2);
        // Planning value covers the instrumented token's cold transfer storage writes.
        // It is not acceptance of every asset or the complete cold-wallet deployment envelope.
        rows[2] = IStreamGasParameterHost.GasParameterConfig(
            "WALLET_DEPOSIT_GAS_LIMIT", 200_000, 25_000, 2
        );
    }

    /// @dev Deploy additional products before the immutable genesis action catalog is committed.
    function _deployAdditionalProducts() internal virtual { }

    /// @dev Scenarios may configure actual unbound economics through governance before artist acceptance.
    function _prepareArtistOnboarding() internal virtual { }

    function _additionalEscrowProducers() internal view virtual returns (address[] memory) {
        return new address[](0);
    }

    function _nativePrimaryPolicyHash() internal view returns (bytes32 hash) {
        (hash,,) = sale.primaryPolicy(1);
    }

    /// @dev Configure additional products after real artist onboarding and genesis selection.
    ///      Manager remains temporarily deployer-owned until this hook returns.
    function _configureAdditionalProducts() internal virtual { }

    /// @dev Additional exact-target operating selectors are included in the committed genesis catalog.
    function _additionalOperatingPolicies()
        internal
        view
        virtual
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return new GovernanceActionPolicyEntry[](0);
    }

    /// @dev Ordinary examples retain ten tokens; stateful campaigns can raise this test-only limit.
    function _fixtureSupplyLimit() internal pure virtual returns (uint64) {
        return 10;
    }

    function _configureMintPhase(bytes32 phase, address phaseExecutor) internal {
        bytes32[] memory counters = new bytes32[](1);
        counters[0] = keccak256("supply");
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](1);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            _fixtureSupplyLimit(),
            1,
            keccak256("counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, keccak256("phase"), keccak256("metadata")
        );
        address[] memory executors = new address[](0);
        _recordFixturePolicy(
            phase,
            manager.previewPhasePolicyHash(1, phase, config, gate, counters, configs, executors)
        );
        manager.configurePhase(1, phase, config, gate, counters, configs);
        executors = new address[](1);
        executors[0] = phaseExecutor;
        _recordFixturePolicy(
            phase,
            manager.previewPhasePolicyHash(1, phase, config, gate, counters, configs, executors)
        );
        manager.setPhaseExecutor(1, phase, phaseExecutor, true);
    }

    /// @dev One real post-genesis batch activates the artist role and required read budget.
    ///      The deployment planner returns these same calls for persistent operator resumption.
    function _activateArtistAuthority() private {
        StreamArtistActivationPlan.Plan memory plan =
            StreamArtistActivationPlan.build(roles, manager, address(this));
        uint64 notBefore = uint64(block.timestamp + 49 hours);
        // Queued broadcast reaches a later block; the retained time still meets the delay floor.
        vm.warp(block.timestamp + 10 minutes);
        uint256 nonceBefore = executor.governanceNonce();
        bytes32 publicationKey =
            keccak256(abi.encodePacked(plan.calls[0].callDataHash, plan.calls[1].callDataHash));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.CallDataNotPublished.selector, publicationKey
            )
        );
        this.scheduleArtistActivationForTest(plan, notBefore);
        require(executor.governanceNonce() == nonceBefore, "unpublished plan consumed nonce");
        executor.publishGovernanceCallData(plan.callDatas);
        bytes32 canonicalScope = plan.scopeHash;
        plan.scopeHash = keccak256("incorrect aggregate");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.BatchScopeHashMismatch.selector,
                canonicalScope,
                plan.scopeHash
            )
        );
        this.scheduleArtistActivationForTest(plan, notBefore);
        require(executor.governanceNonce() == nonceBefore, "wrong aggregate consumed nonce");
        plan.scopeHash = canonicalScope;
        bytes32 actionId = _scheduleFixtureActivation(plan, notBefore);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                actionId,
                notBefore
            )
        );
        this.executeSavedArtistActivation(plan, actionId, address(this));
        require(
            !roles.hasRole(keccak256("ROLE_ARTIST_REGISTRY_ADMIN"), address(this)),
            "role still inactive"
        );
        require(
            manager.gasParameter(manager.GGP_ARTIST_AUTHORITY_GAS_LIMIT()) == 150_000,
            "read budget unchanged"
        );
        vm.warp(notBefore);
        StreamArtistActivationPlan.execute(executor, roles, manager, address(this), actionId, plan);
        // A resumed completed action reuses the saved identity without creating another action.
        StreamArtistActivationPlan.execute(executor, roles, manager, address(this), actionId, plan);
        require(executor.governanceNonce() == nonceBefore + 1, "activation rescheduled on retry");
        vm.expectRevert(
            abi.encodeWithSelector(StreamArtistActivationPlan.InvalidActivationPlan.selector)
        );
        this.executeSavedArtistActivation(plan, actionId, address(0xBAD));
        // A completed action must still authenticate its saved calldata when execution is skipped.
        plan.callDatas[0] = abi.encodeCall(
            roles.grantRole, (keccak256("ROLE_ARTIST_REGISTRY_ADMIN"), address(0xBAD))
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamArtistActivationPlan.InvalidActivationPlan.selector)
        );
        this.executeSavedArtistActivation(plan, actionId, address(0xBAD));
        require(
            roles.hasRole(keccak256("ROLE_ARTIST_REGISTRY_ADMIN"), address(this)),
            "real artist administrator grant"
        );
        require(
            manager.gasParameter(manager.GGP_ARTIST_AUTHORITY_GAS_LIMIT()) == 300_000,
            "real artist read budget raise"
        );
    }

    function _scheduleFixtureActivation(
        StreamArtistActivationPlan.Plan memory plan,
        uint64 notBefore
    ) private returns (bytes32) {
        bytes memory result = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(
                executor.scheduleGovernanceBatch,
                (
                    1,
                    plan.calls,
                    plan.scopeHash,
                    plan.oldValueHash,
                    plan.newValueHash,
                    notBefore,
                    notBefore + 7 days,
                    keccak256("current artist activation"),
                    "urn:6529stream:fixture:artist-activation",
                    DEPLOYMENT_HASH
                )
            )
        );
        return abi.decode(result, (bytes32));
    }

    /// @dev Keep the expected revert outside the dynamic return decoding in the scheduling helper.
    function scheduleArtistActivationForTest(
        StreamArtistActivationPlan.Plan calldata plan,
        uint64 notBefore
    ) external {
        _scheduleFixtureActivation(plan, notBefore);
    }

    /// @dev External boundary lets the test observe the same revert as the resumable script.
    function executeSavedArtistActivation(
        StreamArtistActivationPlan.Plan calldata plan,
        bytes32 actionId,
        address administrator
    ) external {
        StreamArtistActivationPlan.execute(executor, roles, manager, administrator, actionId, plan);
    }

    /// @dev Check the base topology's production instances despite Foundry's test-harness
    ///      allowance. Derived fixtures check added products with the same helper; linked
    ///      libraries also require the compiler-artifact size check at release acceptance.
    function _assertDeployableProductionContracts() private view {
        address[23] memory instances = [
            address(core),
            address(executor),
            address(governanceRoot),
            address(roles),
            address(registry),
            address(manifest),
            address(manager),
            address(ledger),
            address(sale),
            address(auction),
            address(factory),
            address(assetPolicy),
            address(revenueEscrow),
            address(royalties),
            address(artists),
            address(entropy),
            address(router),
            address(primaryResolver),
            address(artistCoordinator),
            artistSuite.archive,
            artistSuite.validator,
            address(artistCoordinator.reads()),
            wallet
        ];
        for (uint256 i; i < instances.length; ++i) {
            _assertDeployableProductionInstance(instances[i]);
        }
        for (uint256 i; i < artistSuite.owners.length; ++i) {
            _assertDeployableProductionInstance(artistSuite.owners[i]);
        }
    }

    function _assertDeployableProductionInstance(address instance) internal view {
        require(
            instance.code.length != 0 && instance.code.length <= 24_576,
            "production runtime exceeds EIP-170"
        );
    }

    function _initializeProductGenesis() private {
        StreamModuleRegistration[] memory records = _moduleRecords();
        bytes32[] memory pointerTypes = new bytes32[](records.length);
        StreamModuleRegistration[] memory pointerRecords =
            new StreamModuleRegistration[](records.length);
        for (uint256 i; i < records.length; ++i) {
            pointerRecords[i] = records[i];
            pointerTypes[i] = _pointerType(records[i].moduleType);
        }
        for (uint256 i = 1; i < pointerTypes.length; ++i) {
            for (uint256 j = i; j > 0 && pointerTypes[j - 1] > pointerTypes[j]; --j) {
                (pointerTypes[j - 1], pointerTypes[j]) = (pointerTypes[j], pointerTypes[j - 1]);
                (pointerRecords[j - 1], pointerRecords[j]) =
                (pointerRecords[j], pointerRecords[j - 1]);
            }
        }
        GenesisBatch[] memory batches = new GenesisBatch[](5);
        batches[0].actionClass = 1;
        (GovernanceCall[] memory registrations, bytes[] memory registrationData) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        batches[0].calls = new GovernanceCall[](records.length + 2);
        batches[0].callDatas = new bytes[](records.length + 2);
        for (uint256 i; i < records.length; ++i) {
            batches[0].calls[i] = registrations[i];
            batches[0].callDatas[i] = registrationData[i];
        }
        (batches[0].calls[records.length], batches[0].callDatas[records.length]) =
            StreamCurrentStackPlan.createCollectionCall(core, 1, _fixtureSupplyLimit());
        bytes memory data = abi.encodeCall(
            entropy.configureCollection,
            (1, address(provider), keccak256("collection salt"), true, uint64(100))
        );
        batches[0].callDatas[records.length + 1] = data;
        batches[0].calls[records.length + 1] = _configurationCall(address(entropy), data);
        batches[2].actionClass = 1;
        address[] memory extraProducers = _additionalEscrowProducers();
        batches[2].calls = new GovernanceCall[](6 + extraProducers.length);
        batches[2].callDatas = new bytes[](6 + extraProducers.length);
        data = abi.encodeCall(
            router.setCollectionMetadata,
            (
                1,
                "Stream Genesis",
                "Current stack integration",
                "ipfs://image",
                "https://example.invalid/art/"
            )
        );
        batches[2].callDatas[0] = data;
        batches[2].calls[0] = _configurationCall(address(router), data);
        data =
            abi.encodeCall(router.setCollectionScript, (1, "document.body.textContent=tokenHash;"));
        batches[2].callDatas[1] = data;
        batches[2].calls[1] = _configurationCall(address(router), data);
        data = abi.encodeCall(royalties.configureCollectionRoyalty, (1, profile, uint16(690)));
        batches[2].callDatas[2] = data;
        batches[2].calls[2] = _configurationCall(address(royalties), data);
        data = abi.encodeCall(
            primaryResolver.setPrimaryProfileAssignment,
            (PRIMARY_REVENUE_CLASS, uint8(1), 1, profile, bytes32(0))
        );
        batches[2].callDatas[3] = data;
        batches[2].calls[3] = _configurationCall(address(primaryResolver), data);
        (batches[2].calls[4], batches[2].callDatas[4]) = _escrowProducerCall(address(sale));
        (batches[2].calls[5], batches[2].callDatas[5]) = _escrowProducerCall(address(auction));
        for (uint256 i; i < extraProducers.length; ++i) {
            (batches[2].calls[6 + i], batches[2].callDatas[6 + i]) =
                _escrowProducerCall(extraProducers[i]);
        }

        bytes32[] memory installTypes = new bytes32[](records.length - 1);
        StreamModuleRegistration[] memory installs =
            new StreamModuleRegistration[](records.length - 1);
        for (uint256 i = 1; i < records.length; ++i) {
            installs[i - 1] = records[i];
            installTypes[i - 1] = _pointerType(records[i].moduleType);
        }
        batches[1].actionClass = 3;
        (batches[1].calls, batches[1].callDatas) =
            StreamCurrentStackPlan.pointerCalls(core, registry, installTypes, installs);
        batches[3].actionClass = 2;
        batches[3].calls = new GovernanceCall[](1);
        batches[3].callDatas = new bytes[](1);
        (batches[3].calls[0], batches[3].callDatas[0]) =
            StreamCurrentStackPlan.freezeManifestCall(core, registry, records[1]);
        _sealProductPlan(batches, pointerTypes, pointerRecords, records);
    }

    function _escrowProducerCall(address producer)
        private
        view
        returns (GovernanceCall memory call_, bytes memory data)
    {
        (bytes32 scope, bytes32 oldState, bytes32 nextState) =
            revenueEscrow.creditProducerTransitionHashes(producer, true);
        data = abi.encodeCall(revenueEscrow.setCreditProducer, (producer, true));
        call_ =
            StreamCurrentStackPlan.call(address(revenueEscrow), data, scope, oldState, nextState);
    }

    function _moduleRecords() private view returns (StreamModuleRegistration[] memory records) {
        records = new StreamModuleRegistration[](9);
        records[0] = _record(
            address(registry),
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            REGISTRY_HASH
        );
        records[1] = _record(
            address(manifest),
            0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6,
            type(IStreamSystemManifest).interfaceId,
            keccak256("fixture system manifest")
        );
        records[2] = _record(
            address(manager),
            keccak256("MINT_MANAGER"),
            type(IStreamMintManager).interfaceId,
            keccak256("fixture mint manager")
        );
        records[3] = _record(
            address(ledger),
            keccak256("MINT_LEDGER"),
            type(IStreamMintLedger).interfaceId,
            keccak256("fixture mint ledger")
        );
        records[4] = _record(
            address(entropy),
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId,
            keccak256("fixture entropy module")
        );
        records[5] = _record(
            address(router),
            keccak256("METADATA_ROUTER"),
            type(IStreamMetadataRouter).interfaceId,
            keccak256("fixture metadata module")
        );
        records[6] = _record(
            address(royalties),
            keccak256("REVENUE_RESOLVER"),
            type(IStreamRoyaltyResolver).interfaceId,
            keccak256("fixture royalty module")
        );
        records[7] = _record(
            address(artists),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            keccak256("fixture artist module")
        );
        records[8] = _record(
            address(executor),
            keccak256("GOVERNANCE_LAYER"),
            type(IStreamStateExportPublisher).interfaceId,
            keccak256("fixture state export publisher")
        );
    }

    function _pointerType(bytes32 moduleType) private pure returns (bytes32) {
        if (moduleType == 0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6) {
            return keccak256("SYSTEM_MANIFEST");
        }
        if (moduleType == keccak256("REVENUE_RESOLVER")) return keccak256("ROYALTY_RESOLVER");
        if (moduleType == keccak256("GOVERNANCE_LAYER")) {
            return keccak256("STATE_EXPORT_PUBLISHER");
        }
        return moduleType;
    }

    function _record(address module, bytes32 moduleType, bytes4 interfaceId, bytes32 moduleHash)
        private
        view
        returns (StreamModuleRegistration memory)
    {
        return StreamModuleRegistration(
            module,
            moduleType,
            keccak256("fixture v1"),
            interfaceId,
            500_000,
            module.codehash,
            DEPLOYMENT_HASH,
            moduleHash,
            "urn:6529stream:fixture:module"
        );
    }

    function _configurationCall(address target, bytes memory data)
        private
        pure
        returns (GovernanceCall memory)
    {
        return StreamCurrentStackPlan.call(
            target, data, keccak256(abi.encode(target, data)), bytes32(0), keccak256(data)
        );
    }

    function _sealProductPlan(
        GenesisBatch[] memory batches,
        bytes32[] memory pointerTypes,
        StreamModuleRegistration[] memory pointerRecords,
        StreamModuleRegistration[] memory records
    ) private {
        // Final binding and publication are assembled below from the exact deployed objects.
        SystemManifestBootstrapBinding memory binding;
        binding.roleRegistry = address(roles);
        binding.governanceRoot = address(governanceRoot);
        binding.governanceRootCodeHash = address(governanceRoot).codehash;
        binding.initialTerminalFreezeVetoGuardians = guardians;
        binding.core = address(core);
        binding.systemManifestSatellite = address(manifest);
        binding.pointerTypes = pointerTypes;
        binding.registries = new address[](1);
        binding.registries[0] = address(registry);
        (binding.expectedInventoryStateRoot, binding.expectedInventoryLeafCount) =
            StreamCurrentStackPlan.finalInventory(
                address(executor), core, registry, pointerTypes, pointerRecords, records
            );
        _completeGenesisPlan(binding, batches);
    }

    function _completeGenesisPlan(
        SystemManifestBootstrapBinding memory binding,
        GenesisBatch[] memory batches
    ) internal {
        (address payload, bytes32 payloadHash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"purpose\":\"current-stack integration test\",\"version\":1}")
        );
        binding.expectedManifestHash = payloadHash;
        binding.expectedTriggers = new SystemManifestBootstrapTriggerExpectation[](2);
        binding.expectedTriggers[0] = SystemManifestBootstrapTriggerExpectation(
            address(core), core.updateSatellitePointer.selector, address(core).codehash, 8
        );
        binding.expectedTriggers[1] = SystemManifestBootstrapTriggerExpectation(
            address(registry), registry.setModuleStatus.selector, address(registry).codehash, 3
        );
        if (uint160(address(core)) > uint160(address(registry))) {
            (binding.expectedTriggers[0], binding.expectedTriggers[1]) =
            (binding.expectedTriggers[1], binding.expectedTriggers[0]);
        }
        binding.actionPolicyCandidateProfileHash = DEPLOYMENT_HASH;
        batches[batches.length - 1].actionClass = 3;
        batches[batches.length - 1].calls = new GovernanceCall[](2);
        batches[batches.length - 1].callDatas = new bytes[](2);
        batches[batches.length - 1].calls[0].target = address(executor);
        batches[batches.length - 1].calls[0].selector =
        executor.sealSystemManifestBootstrap.selector;
        batches[batches.length - 1].calls[1].target = address(manifest);
        batches[batches.length - 1].calls[1].selector =
        manifest.publishStreamSystemManifest.selector;
        binding.actionPolicies = _actionPolicies(batches);
        binding.expectedActionPolicyCatalogHash = StreamGovernanceActionPolicy.expectedCatalogHash(
            address(executor), binding.actionPolicyCandidateProfileHash, binding.actionPolicies
        );
        (batches[batches.length - 1].calls[0], batches[batches.length - 1].callDatas[0]) =
            StreamGenesisManifestPlan.sealCall(executor, address(this), binding, payload);
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate({
            manifestHash: payloadHash,
            manifestURI: "urn:6529stream:current-stack:fixture",
            eventCatalogHash: keccak256("fixture events"),
            compatibilityMatrixHash: keccak256("fixture compatibility"),
            numericIdCatalogHash: keccak256("fixture numeric ids"),
            schemaCatalogHash: keccak256("fixture schema"),
            canonicalizationCatalogHash: keccak256("fixture canonicalization"),
            specBundleHash: keccak256("fixture spec"),
            reconstructionClientHash: keccak256("fixture client")
        });
        StreamSystemManifest.ModuleAddresses memory modules;
        modules.artistRegistry = address(artists);
        modules.revenueResolver = address(royalties);
        modules.metadataRouter = address(router);
        modules.entropyCoordinator = address(entropy);
        modules.mintManager = address(manager);
        modules.mintLedger = address(ledger);
        modules.streamAdminsOrGovernance = address(executor);
        modules.moduleRegistry = address(registry);
        modules.stateExportPublisher = address(executor);
        (batches[batches.length - 1].calls[1], batches[batches.length - 1].callDatas[1]) =
            StreamGenesisManifestPlan.firstPublicationCall(manifest, payload, update, modules);
        executor.commitGenesisPlan(executor.hashGenesisPlan(binding, batches));
        executor.prepareGenesis(binding, batches);
        executor.initializeGenesis(binding, batches);
    }

    function _actionPolicies(GenesisBatch[] memory batches)
        private
        view
        returns (GovernanceActionPolicyEntry[] memory policies)
    {
        GovernanceActionPolicyEntry[] memory operating = _operatingPolicies();
        uint256 capacity = operating.length;
        for (uint256 i; i < batches.length; ++i) {
            capacity += batches[i].calls.length;
        }
        GovernanceActionPolicyEntry[] memory candidates =
            new GovernanceActionPolicyEntry[](capacity);
        uint256 count = operating.length;
        for (uint256 i; i < count; ++i) {
            candidates[i] = operating[i];
        }
        for (uint256 i; i < batches.length; ++i) {
            for (uint256 j; j < batches[i].calls.length; ++j) {
                GovernanceCall memory operation = batches[i].calls[j];
                bytes32 key = keccak256(
                    abi.encode(batches[i].actionClass, operation.target, operation.selector)
                );
                bool duplicate;
                for (uint256 k; k < count; ++k) {
                    if (
                        keccak256(
                                abi.encode(
                                    candidates[k].actionClass,
                                    candidates[k].target,
                                    candidates[k].selector
                                )
                            ) == key
                    ) duplicate = true;
                }
                if (!duplicate) {
                    candidates[count++] = GovernanceActionPolicyEntry(
                        batches[i].actionClass,
                        operation.target,
                        operation.selector,
                        operation.target.codehash,
                        keccak256(abi.encode(DEPLOYMENT_HASH, operation.target)),
                        1,
                        0,
                        0,
                        bytes32(0)
                    );
                }
            }
        }
        policies = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            policies[i] = candidates[i];
        }
        for (uint256 i = 1; i < count; ++i) {
            for (
                uint256 j = i; j > 0 && _policyKey(policies[j - 1]) > _policyKey(policies[j]); --j) {
                (policies[j - 1], policies[j]) = (policies[j], policies[j - 1]);
            }
        }
    }

    function _policyKey(GovernanceActionPolicyEntry memory policy) private pure returns (bytes32) {
        return keccak256(abi.encode(policy.actionClass, policy.target, policy.selector));
    }

    function _operatingPolicies() private view returns (GovernanceActionPolicyEntry[] memory rows) {
        GovernanceActionPolicyEntry[] memory additional = _additionalOperatingPolicies();
        rows = new GovernanceActionPolicyEntry[](61 + additional.length);
        rows[0] = _operatingPolicy(address(manager), manager.configurePhase.selector);
        rows[1] = _operatingPolicy(address(manager), manager.setPhaseExecutor.selector);
        rows[2] = _operatingPolicy(address(manager), manager.setPhasePaused.selector);
        rows[3] = _operatingPolicy(address(ledger), ledger.setLedgerWriter.selector);
        rows[4] = _operatingPolicy(address(sale), sale.setPlatformSigner.selector);
        rows[5] = _operatingPolicy(address(sale), sale.setPaused.selector);
        rows[6] = _operatingPolicy(address(auction), auction.setPlatformSigner.selector);
        rows[7] = _operatingPolicy(address(auction), auction.setPaused.selector);
        rows[8] = _operatingPolicy(address(entropy), entropy.setRequester.selector);
        rows[9] = _operatingPolicy(address(entropy), entropy.setProviderRevoked.selector);
        rows[10] = _operatingPolicy(address(entropy), entropy.markRequestStale.selector);
        rows[11] = _operatingPolicy(address(entropy), entropy.markRequestFailed.selector);
        rows[12] = _operatingPolicy(address(router), router.setCollectionScript.selector);
        rows[13] = _operatingPolicy(address(router), router.setContractMetadataURI.selector);
        rows[14] = _operatingPolicy(address(assetPolicy), assetPolicy.setAssetStatus.selector);
        rows[15] = _operatingPolicy(address(core), core.raiseGasParameter.selector);
        rows[16] = _operatingPolicy(address(core), core.setCollectionMaxSupply.selector);
        rows[17] = _operatingPolicy(address(royalties), royalties.configureDefaultRoyalty.selector);
        rows[18] =
            _operatingPolicy(address(royalties), royalties.configureCollectionRoyalty.selector);
        rows[19] = _operatingPolicy(address(royalties), royalties.freezeDefaultRoyalty.selector);
        rows[19].actionClass = 2;
        rows[20] = _operatingPolicy(address(royalties), royalties.freezeCollectionRoyalty.selector);
        rows[20].actionClass = 2;
        uint256 i = 21;
        rows[i++] = _operatingPolicy(3, address(executor), executor.rotateGovernanceRoot.selector);
        rows[i++] = _operatingPolicy(
            3, address(executor), executor.extendGovernanceActionPolicy.selector
        );
        rows[i++] = _operatingPolicy(0, address(executor), executor.registerProposer.selector);
        rows[i++] = _operatingPolicy(1, address(executor), executor.registerProposer.selector);
        rows[i++] = _operatingPolicy(0, address(executor), executor.registerCanceller.selector);
        rows[i++] = _operatingPolicy(1, address(executor), executor.registerCanceller.selector);
        rows[i++] =
            _operatingPolicy(0, address(executor), executor.setApprovedNativeReceiver.selector);
        rows[i++] =
            _operatingPolicy(1, address(executor), executor.setApprovedNativeReceiver.selector);
        rows[i++] = _operatingPolicy(0, address(executor), executor.setTighteningCall.selector);
        rows[i++] = _operatingPolicy(1, address(executor), executor.setTighteningCall.selector);
        rows[i++] = _operatingPolicy(0, address(executor), executor.registerFreezeSelector.selector);
        rows[i++] = _operatingPolicy(1, address(executor), executor.registerFreezeSelector.selector);
        rows[i++] = _operatingPolicy(
            2, address(executor), executor.registerSystemManifestTailTrigger.selector
        );
        rows[i++] = _operatingPolicy(1, address(roles), roles.grantRole.selector);
        rows[i++] = _operatingPolicy(1, address(roles), roles.revokeRole.selector);
        rows[i++] = _operatingPolicy(1, address(roles), roles.grantScopedRole.selector);
        rows[i++] = _operatingPolicy(1, address(roles), roles.revokeScopedRole.selector);
        rows[i++] = _operatingPolicy(0, address(roles), roles.registerRoleManager.selector);
        rows[i++] = _operatingPolicy(1, address(roles), roles.registerRoleManager.selector);
        rows[i++] = _operatingPolicy(0, address(registry), registry.setModuleStatus.selector);
        rows[i++] = _operatingPolicy(1, address(registry), registry.setModuleStatus.selector);
        rows[i++] =
            _operatingPolicy(1, address(registry), registry.setModuleRegistryManifest.selector);
        rows[i++] = _operatingPolicy(0, address(core), core.setCollectionStatus.selector);
        rows[i++] = _operatingPolicy(1, address(core), core.setCollectionStatus.selector);
        rows[i++] = _operatingPolicy(2, address(core), core.setCollectionStatus.selector);
        rows[i++] = _operatingPolicy(0, address(core), core.setCollectionMaxSupply.selector);
        rows[i++] = _operatingPolicy(2, address(core), core.blockCollectionBurns.selector);
        rows[i++] = _operatingPolicy(2, address(core), core.freezeCollection.selector);
        rows[i++] =
            _operatingPolicy(0, address(manifest), manifest.publishStreamSystemManifest.selector);
        rows[i++] =
            _operatingPolicy(1, address(manifest), manifest.publishStreamSystemManifest.selector);
        rows[i++] =
            _operatingPolicy(2, address(manifest), manifest.publishStreamSystemManifest.selector);
        rows[i++] = _operatingPolicy(address(manager), manager.raiseGasParameter.selector);
        rows[i++] = _operatingPolicy(address(factory), factory.raiseGasParameter.selector);
        rows[i++] = _operatingPolicy(address(artists), artists.raiseGasParameter.selector);
        rows[i++] =
            _operatingPolicy(address(revenueEscrow), revenueEscrow.setCreditProducer.selector);
        rows[i++] =
            _operatingPolicy(address(revenueEscrow), revenueEscrow.raiseGasParameter.selector);
        rows[i++] =
            _operatingPolicy(address(primaryResolver), primaryResolver.raiseGasParameter.selector);
        rows[i++] = _operatingPolicy(
            address(primaryResolver), primaryResolver.createPrimaryTemplate.selector
        );
        rows[i++] =
            _operatingPolicy(address(assetPolicy), assetPolicy.setAssetPermitPolicy.selector);
        rows[i++] = _operatingPolicy(
            address(primaryResolver), primaryResolver.setPrimaryTemplateAssignment.selector
        );
        // Metadata, economics and entropy configuration are also collected from genesis.
        for (uint256 j; j < additional.length; ++j) {
            rows[i++] = additional[j];
        }
        assert(i == rows.length);
    }

    function _operatingPolicy(uint8 actionClass, address target, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory row)
    {
        row = _operatingPolicy(target, selector);
        row.actionClass = actionClass;
    }

    function _operatingPolicy(address target, bytes4 selector)
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
            bytes32(0)
        );
    }
}
