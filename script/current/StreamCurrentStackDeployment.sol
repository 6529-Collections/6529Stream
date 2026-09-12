// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/core/StreamCore.sol";
import "./StreamArtistSuiteDeployment.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import "./StreamArtistActivationPlan.sol";
import "./StreamGovernanceGenesisPlan.sol";
import "./StreamDeploymentPlan.sol";
import "./StreamRevealActivationPlan.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../smart-contracts/domains/governance/StreamGovernanceExecutor.sol";
import "../../smart-contracts/domains/governance/StreamGovernanceActor.sol";
import "../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import "../../smart-contracts/domains/governance/StreamSystemManifest.sol";
import "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/mint/StreamERC20FixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol";
import "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "./StreamCurrentStackPlan.sol";
import "./StreamGenesisManifestPlan.sol";
import "./DevelopmentEntropyProvider.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol";

interface CurrentOperatorConfigurationVm {
    function envBytes(string calldata key) external view returns (bytes memory);
    function envOr(string calldata key, address defaultValue) external view returns (address);
    function envOr(string calldata key, uint256 defaultValue) external view returns (uint256);
}

/// @notice Reusable development/testnet genesis assembly for the actual current stack.
abstract contract StreamCurrentStackDeployment is StreamArtistSuiteDeployment {
    bytes32 internal constant PHASE = keccak256("current-stack fixed price");
    bytes32 internal constant AUCTION_PHASE = keccak256("current-stack auction");
    bytes32 internal constant ERC20_PHASE = keccak256("current-stack ERC20 fixed price");
    bytes32 internal constant DEPLOYMENT_HASH =
        keccak256("current-stack staged engineering deployment v2; unaudited; not release evidence");
    bytes32 internal constant REGISTRY_HASH = keccak256("current-stack development registry v1");
    // Script construction precedes broadcasting; this helper never consumes a deployer nonce.
    StreamDeploymentPlan internal immutable deploymentPlanner = new StreamDeploymentPlan();
    address internal deployer;
    address internal protocol;
    bool internal localDevelopment;
    StreamEntropyProviderVRF.Config internal vrfConfig;
    StreamCore internal core;
    StreamGovernanceExecutor internal executor;
    StreamGovernanceActor internal governanceRoot;
    StreamRoleRegistry internal roles;
    StreamModuleRegistry internal registry;
    StreamSystemManifest internal manifest;
    StreamMintManager internal manager;
    StreamMintLedger internal ledger;
    StreamFixedPriceSaleAdapter internal sale;
    StreamERC20FixedPriceSaleAdapter internal erc20Sale;
    StreamEnglishAuctionHouse internal auction;
    StreamSplitFactory internal factory;
    StreamAssetPolicyRegistry internal assetPolicy;
    StreamRevenueEscrow internal revenueEscrow;
    address internal configuredGovernanceRoot;
    address[] internal configuredGuardians;
    bytes internal encodedFoundationPlan;
    GovernanceActionPolicyEntry[] internal foundationPolicies;
    StreamEntropyCoordinator internal entropy;
    IStreamEntropyProvider internal provider;
    address internal artist;
    address internal wallet;
    bytes32 internal profile;
    address[] internal guardians;

    /// @dev Public configuration only; no observer private key is read or generated.
    function _loadOperatorConfiguration() internal {
        CurrentOperatorConfigurationVm configVm = CurrentOperatorConfigurationVm(
            address(uint160(uint256(keccak256("hevm cheat code"))))
        );
        configuredGovernanceRoot = configVm.envOr("STREAM_GOVERNANCE_ROOT", address(0));
        if (configuredGovernanceRoot != address(0)) {
            configuredGuardians = abi.decode(configVm.envBytes("STREAM_GOVERNANCE_GUARDIANS"), (address[]));
        } else {
            require(localDevelopment, "explicit governance root required");
        }
        StreamArchivalTypes.Observer[] memory observers = abi.decode(
            configVm.envBytes("STREAM_ARCHIVAL_OBSERVERS"), (StreamArchivalTypes.Observer[])
        );
        uint256 quorum = configVm.envOr("STREAM_ARCHIVAL_QUORUM", uint256(2));
        require(quorum >= 2 && quorum <= observers.length && observers.length <= 8, "invalid observer quorum");
        address prior;
        for (uint256 i; i < observers.length; ++i) {
            require(observers[i].account > prior && observers[i].organizationId != bytes32(0), "invalid observer set");
            for (uint256 j; j < i; ++j) {
                require(observers[i].organizationId != observers[j].organizationId, "duplicate observer organization");
            }
            archivalObservers.push(observers[i]);
            prior = observers[i].account;
        }
        archivalQuorum = uint8(quorum);
        archivalSignatureGas = configVm.envOr("STREAM_ARCHIVAL_SIGNATURE_GAS", uint256(400_000));
        archivalReadGas = configVm.envOr("STREAM_ARCHIVAL_READ_GAS", uint256(150_000));
        require(archivalSignatureGas >= 90_000 && archivalReadGas >= 50_000, "archival gas below floor");
    }

    function _deployCurrentStack(address artist_, address platform) internal {
        artist = artist_;
        executor = new StreamGovernanceExecutor(deployer);
        if (configuredGovernanceRoot == address(0)) {
            require(localDevelopment, "explicit governance root required");
            governanceRoot = new StreamGovernanceActor(deployer);
            guardians = new address[](2);
            guardians[0] = address(new StreamGovernanceActor(deployer));
            guardians[1] = address(new StreamGovernanceActor(deployer));
        } else {
            // The address may be a Safe. No development-actor method is called on it.
            governanceRoot = StreamGovernanceActor(payable(configuredGovernanceRoot));
            guardians = configuredGuardians;
            require(guardians.length >= 2, "redundant guardians required");
        }
        for (uint256 i = 1; i < guardians.length; ++i) {
            for (uint256 j = i; j > 0 && guardians[j - 1] > guardians[j]; --j) {
                (guardians[j - 1], guardians[j]) = (guardians[j], guardians[j - 1]);
            }
        }
        roles = new StreamRoleRegistry(address(executor));
        registry = new StreamModuleRegistry(
            executor, REGISTRY_HASH, "urn:6529stream:development:registry"
        );
        core = new StreamCore(
            "6529 Stream",
            "STREAM",
            address(executor),
            StreamCore.GenesisModuleRegistryConfig(
                address(registry), address(registry).codehash, REGISTRY_HASH, DEPLOYMENT_HASH
            ),
            _deploymentGasParameters()
        );
        manifest = new StreamSystemManifest(address(core), address(executor));
        _initializeGovernanceFoundation();
        ledger = new StreamMintLedger();
        manager = new StreamMintManager(core, ledger, IERC165(address(registry)));
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
        revenueEscrow = new StreamRevenueEscrow(
            factory,
            address(executor),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3)
        );
        IStreamArtistAttribution attribution = IStreamArtistAttribution(address(artistRegistry));
        sale = new StreamFixedPriceSaleAdapter(
            manager, primaryRevenue, platform, attribution, revenueEscrow
        );
        erc20Sale = new StreamERC20FixedPriceSaleAdapter(
            manager, primaryRevenue, platform, attribution, revenueEscrow
        );
        auction = new StreamEnglishAuctionHouse(
            core, manager, primaryRevenue, platform, attribution, revenueEscrow
        );
        entropy = new StreamEntropyCoordinator(StreamEntropyCoordinator.DeploymentConfig(
            address(core),
            address(executor),
            address(roles),
            StreamCurrentStackPlan.entropyTimeParameters(),
            DEPLOYMENT_HASH,
            "urn:6529stream:development:entropy",
            keccak256("development entropy module")
        ));
        if (localDevelopment) {
            provider = new DevelopmentEntropyProvider(address(entropy), deployer);
        } else {
            vrfConfig.coordinator = address(entropy);
            vrfConfig.authority = address(executor);
            provider = new StreamEntropyProviderVRF(
                vrfConfig,
                DEPLOYMENT_HASH,
                "urn:6529stream:development:vrf",
                keccak256("development VRF module")
            );
        }
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(protocol, 100_000, keccak256("protocol"));
        (profile, wallet) = factory.createProfile(entries, keccak256("development split"));
        ledger.transferOwnership(address(executor));
        sale.transferOwnership(address(executor));
        erc20Sale.transferOwnership(address(executor));
        auction.transferOwnership(address(executor));
        // Manager remains deployer-owned through artist consent and phase activation.
        // Artist onboarding and phase setup must finish before their separate ownership handoff.
        // Stop at deployed, unselected products. Ordinary catalog, registration,
        // pointer and configuration stages are separately saved and delayed.
        require(executor.genesisInitialized(), "foundation incomplete");
        require(
            StreamCurrentStackPlan.readPointer(core, keccak256("ARTIST_REGISTRY")).target == address(0),
            "products must remain unactivated"
        );
    }

    function _artistDeploymentSender() internal view override returns (address) {
        return deployer;
    }

    function _walletGasConfigs()
        private
        pure
        returns (IStreamGasParameterHost.GasParameterConfig[3] memory rows)
    {
        rows[0] = IStreamGasParameterHost.GasParameterConfig(
            "ERC_1271_GAS_LIMIT", 400_000, 350_000, 2
        );
        rows[1] =
            IStreamGasParameterHost.GasParameterConfig("ASSET_POLICY_GAS_LIMIT", 30_000, 15_000, 2);
        rows[2] = IStreamGasParameterHost.GasParameterConfig(
            "WALLET_DEPOSIT_GAS_LIMIT", 200_000, 25_000, 2
        );
    }

    function _initializeGovernanceFoundation() private {
        StreamGovernanceGenesisPlan.Configuration memory c;
        c.executor = executor;
        c.roles = roles;
        c.core = core;
        c.registry = registry;
        c.manifest = manifest;
        c.bootstrapAuthority = deployer;
        c.governanceRoot = address(governanceRoot);
        c.guardians = guardians;
        c.deploymentHash = DEPLOYMENT_HASH;
        c.manifestModuleHash = keccak256("development system manifest");
        c.moduleURI = "urn:6529stream:engineering:foundation-module";
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"purpose\":\"staged engineering foundation only\",\"version\":2}")
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash, "urn:6529stream:engineering:foundation:v2",
            keccak256("development events"), keccak256("development compatibility"),
            keccak256("development numeric ids"), keccak256("development schema"),
            keccak256("development canonicalization"), keccak256("development spec"),
            keccak256("development client")
        );
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) =
            _buildGovernanceFoundationPlan(c, payload, update);
        encodedFoundationPlan = abi.encode(binding, batches);
        for (uint256 i; i < binding.actionPolicies.length; ++i) {
            foundationPolicies.push(binding.actionPolicies[i]);
        }
        executor.commitGenesisPlan(executor.hashGenesisPlan(binding, batches));
        executor.prepareGenesis(binding, batches);
        executor.initializeGenesis(binding, batches);
    }

    /// @dev Entry points own broadcast bracketing; the shared planning hook performs only reads.
    function _buildGovernanceFoundationPlan(
        StreamGovernanceGenesisPlan.Configuration memory configuration,
        address payloadRoot,
        StreamSystemManifestUpdate memory update
    )
        internal
        virtual
        returns (SystemManifestBootstrapBinding memory, GenesisBatch[] memory)
    {
        return deploymentPlanner.buildFoundation(configuration, payloadRoot, update);
    }

    /// @notice Exact deployed product records; foundation registrations are excluded.
    function _productRegistrations() internal view returns (StreamModuleRegistration[] memory rows) {
        StreamModuleRegistration[] memory allRows = _moduleRecords();
        rows = new StreamModuleRegistration[](allRows.length - 2);
        for (uint256 i; i < rows.length; ++i) rows[i] = allRows[i + 2];
    }

    /// @notice Full initial admission intent, not one prematurely scheduled catalog batch.
    /// @dev The operator partitions at64 entries and observes each executed catalog revision
    ///      before preparing the next extension plus fresh manifest publication.
    function _productPolicyAdditions() internal view returns (GovernanceActionPolicyEntry[] memory rows) {
        GenesisBatch[] memory prototypes = new GenesisBatch[](1);
        prototypes[0] = _initialConfigurationBatch();
        return deploymentPlanner.catalogAdditions(
            prototypes, _operatingPolicies(), foundationPolicies, DEPLOYMENT_HASH
        );
    }

    /// @dev Rebuild against observed selected products before scheduling. These prototypes
    ///      collect selectors at deployment; their transition state is not a saved future plan.
    function _initialConfigurationBatch() internal view returns (GenesisBatch memory batch) {
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](9);
        batch.callDatas = new bytes[](9);
        batch.callDatas[0] = abi.encodeCall(ledger.setLedgerWriter, (address(manager), true));
        batch.callDatas[1] = abi.encodeCall(entropy.configureCollection,
            (1, address(provider), keccak256("collection salt"), true, uint64(100)));
        batch.callDatas[2] = abi.encodeCall(router.setCollectionMetadata,
            (1, "Stream Genesis", "Staged current-stack engineering deployment", "", ""));
        batch.callDatas[3] = abi.encodeCall(router.setCollectionScript,
            (1, "document.body.textContent=tokenHash;"));
        batch.callDatas[4] = abi.encodeCall(royalty.configureCollectionRoyalty, (1, profile, uint16(690)));
        batch.callDatas[5] = abi.encodeCall(primaryRevenue.setPrimaryProfileAssignment,
            (PRIMARY_REVENUE_CLASS, uint8(1), uint256(1), profile, bytes32(0)));
        address[6] memory targets = [address(ledger), address(entropy), address(router),
            address(router), address(royalty), address(primaryRevenue)];
        for (uint256 i; i < targets.length; ++i) batch.calls[i] = _configurationCall(targets[i], batch.callDatas[i]);
        (batch.calls[6], batch.callDatas[6]) = _escrowProducerCall(address(sale));
        (batch.calls[7], batch.callDatas[7]) = _escrowProducerCall(address(erc20Sale));
        (batch.calls[8], batch.callDatas[8]) = _escrowProducerCall(address(auction));
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
            keccak256("development system manifest")
        );
        records[2] = _record(
            address(manager),
            keccak256("MINT_MANAGER"),
            type(IStreamMintManager).interfaceId,
            keccak256("development mint manager")
        );
        records[3] = _record(
            address(ledger),
            keccak256("MINT_LEDGER"),
            type(IStreamMintLedger).interfaceId,
            keccak256("development mint ledger")
        );
        records[4] = _record(
            address(entropy),
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId,
            keccak256("development entropy module")
        );
        records[5] = _record(
            address(router),
            keccak256("METADATA_ROUTER"),
            type(IStreamMetadataRouter).interfaceId,
            keccak256("development metadata module")
        );
        records[6] = _record(
            address(royalty),
            keccak256("REVENUE_RESOLVER"),
            type(IStreamRoyaltyResolver).interfaceId,
            keccak256("development royalty module")
        );
        records[7] = _record(
            address(artistRegistry),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            keccak256("development artist module")
        );
        records[8] = _record(
            address(executor),
            keccak256("GOVERNANCE_LAYER"),
            type(IStreamStateExportPublisher).interfaceId,
            keccak256("development state export publisher")
        );
    }

    function _pointerType(bytes32 moduleType) private pure returns (bytes32) {
        if (moduleType == 0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6) {
            return keccak256("SYSTEM_MANIFEST");
        }
        if (moduleType == keccak256("GOVERNANCE_LAYER")) {
            return keccak256("STATE_EXPORT_PUBLISHER");
        }
        if (moduleType == keccak256("REVENUE_RESOLVER")) return keccak256("ROYALTY_RESOLVER");
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
            keccak256("development v1"),
            interfaceId,
            500_000,
            module.codehash,
            DEPLOYMENT_HASH,
            moduleHash,
            "urn:6529stream:development:module"
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

    function _operatingPolicies() private view returns (GovernanceActionPolicyEntry[] memory rows) {
        rows = new GovernanceActionPolicyEntry[](localDevelopment ? 77 : 78);
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
        rows[17] = _operatingPolicy(address(royalty), royalty.configureDefaultRoyalty.selector);
        rows[18] = _operatingPolicy(address(royalty), royalty.configureCollectionRoyalty.selector);
        rows[19] = _operatingPolicy(address(royalty), royalty.freezeDefaultRoyalty.selector);
        rows[19].actionClass = 2;
        rows[20] = _operatingPolicy(address(royalty), royalty.freezeCollectionRoyalty.selector);
        rows[20].actionClass = 2;
        uint256 i = 21;
        rows[i++] = _operatingPolicy(3, address(executor), executor.rotateGovernanceRoot.selector);
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
        // Append-only catalog evolution; existing entries remain pinned.
        rows[i++] = _operatingPolicy(3, address(executor), executor.extendGovernanceActionPolicy.selector);
        if (!localDevelopment) {
            rows[i++] = _operatingPolicy(
                1, address(provider), StreamEntropyProviderVRF.updateSubscription.selector
            );
        }
        rows[i++] = _operatingPolicy(address(erc20Sale), erc20Sale.registerSale.selector);
        rows[i++] = _operatingPolicy(address(erc20Sale), erc20Sale.cancelSale.selector);
        rows[i++] = _operatingPolicy(address(erc20Sale), erc20Sale.setPlatformSigner.selector);
        rows[i++] = _operatingPolicy(address(erc20Sale), erc20Sale.setPaused.selector);
        rows[i++] = _operatingPolicy(address(erc20Sale), erc20Sale.raiseSignatureGasLimit.selector);
        rows[i++] = _operatingPolicy(
            address(primaryRevenue), primaryRevenue.setPrimaryProfileAssignment.selector
        );
        rows[i++] = _operatingPolicy(
            2, address(primaryRevenue), primaryRevenue.freezePrimaryAssignment.selector
        );
        rows[i++] = _operatingPolicy(address(manager), manager.raiseGasParameter.selector);
        rows[i++] =
            _operatingPolicy(address(artistRegistry), artistRegistry.raiseGasParameter.selector);
        rows[i++] =
            _operatingPolicy(address(revenueEscrow), revenueEscrow.setCreditProducer.selector);
        rows[i++] = _operatingPolicy(address(factory), factory.raiseGasParameter.selector);
        rows[i++] =
            _operatingPolicy(address(revenueEscrow), revenueEscrow.raiseGasParameter.selector);
        rows[i++] =
            _operatingPolicy(address(primaryRevenue), primaryRevenue.raiseGasParameter.selector);
        rows[i++] = _operatingPolicy(
            address(primaryRevenue), primaryRevenue.createPrimaryTemplate.selector
        );
        rows[i++] =
            _operatingPolicy(address(assetPolicy), assetPolicy.setAssetPermitPolicy.selector);
        rows[i++] = _operatingPolicy(
            address(primaryRevenue), primaryRevenue.setPrimaryTemplateAssignment.selector
        );
        rows[i++] = _operatingPolicy(address(entropy), entropy.raiseTimeParameter.selector);
        rows[i++] = _operatingPolicy(1, address(artistRegistry), IStreamArtistIdentityContest.contestArtistIdentity.selector);
        rows[i++] = _operatingPolicy(2, address(artistRegistry), IStreamArtistIdentityContest.contestArtistIdentity.selector);
        rows[i++] = _operatingPolicy(1, address(artistRegistry), IStreamArtistIdentityDismissal.dismissArtistIdentityContest.selector);
        rows[i++] = _operatingPolicy(2, address(artistRegistry), IStreamArtistIdentityDismissal.dismissArtistIdentityContest.selector);
        rows[i++] = _operatingPolicy(address(archivalCheckpoint), archivalCheckpoint.raiseGasParameter.selector);
        rows[i++] = _operatingPolicy(address(archivalCoverage), archivalCoverage.raiseGasParameter.selector);
        rows[i++] = _operatingPolicy(address(archivalCoverage), archivalCoverage.admitFamily.selector);
        rows[i++] = _operatingPolicy(address(archivalCoverage), archivalCoverage.setFamilyStatus.selector);
        // Metadata/entropy configuration selectors come from the configuration prototypes.
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

    function _deploymentGasParameters()
        private
        pure
        returns (StreamCore.GasParameterGenesisConfig[] memory gas)
    {
        gas = StreamCurrentStackPlan.gasParameters();
        gas[2].genesisValue = 12_000_000;
    }
}
