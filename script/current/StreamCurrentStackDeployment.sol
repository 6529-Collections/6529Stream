// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/core/StreamCore.sol";
import "./StreamArtistSuiteDeployment.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import "./StreamArtistActivationPlan.sol";
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

/// @notice Reusable development/testnet genesis assembly for the actual current stack.
abstract contract StreamCurrentStackDeployment is StreamArtistSuiteDeployment {
    bytes32 internal constant PHASE = keccak256("current-stack fixed price");
    bytes32 internal constant AUCTION_PHASE = keccak256("current-stack auction");
    bytes32 internal constant ERC20_PHASE = keccak256("current-stack ERC20 fixed price");
    bytes32 internal constant DEPLOYMENT_HASH =
        keccak256("current-stack development deployment v1; unaudited; not release evidence");
    bytes32 internal constant REGISTRY_HASH = keccak256("current-stack development registry v1");
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
    bytes32 internal artistActivationId;
    uint64 internal artistActivationNotBefore;
    bytes internal encodedArtistActivationPlan;
    StreamEntropyCoordinator internal entropy;
    IStreamEntropyProvider internal provider;
    address internal artist;
    address internal wallet;
    bytes32 internal profile;
    address[] internal guardians;

    function _deployCurrentStack(address artist_, address platform) internal {
        artist = artist_;
        executor = new StreamGovernanceExecutor(deployer);
        governanceRoot = new StreamGovernanceActor(deployer);
        guardians = new address[](2);
        guardians[0] = address(new StreamGovernanceActor(deployer));
        guardians[1] = address(new StreamGovernanceActor(deployer));
        if (guardians[0] > guardians[1]) {
            (guardians[0], guardians[1]) = (guardians[1], guardians[0]);
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
        _initializeProductGenesis();
        _scheduleArtistActivation();
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

    /// @dev One hour of submission headroom beyond the onchain 48-hour minimum.
    ///      Live runners pin this value before simulation and retain the scheduled result.
    function _artistActivationTimestamp() internal view virtual returns (uint64) {
        return uint64(block.timestamp + 49 hours);
    }

    function _scheduleArtistActivation() private {
        StreamArtistActivationPlan.Plan memory plan = StreamRevealActivationPlan.buildWithArtist(
            roles,
            manager,
            deployer,
            StreamRevealActivationPlan.Principals(
                address(governanceRoot), address(governanceRoot), address(governanceRoot)
            )
        );
        artistActivationNotBefore = _artistActivationTimestamp();
        require(
            artistActivationNotBefore >= block.timestamp + 48 hours,
            "activation submission window elapsed"
        );
        encodedArtistActivationPlan = abi.encode(plan);
        executor.publishGovernanceCallData(plan.callDatas);
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
                    artistActivationNotBefore,
                    artistActivationNotBefore + 7 days,
                    keccak256("current artist activation"),
                    "urn:6529stream:development:artist-activation",
                    DEPLOYMENT_HASH
                )
            )
        );
        artistActivationId = abi.decode(result, (bytes32));
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
            StreamCurrentStackPlan.createCollectionCall(core, 1, 10);
        bytes memory data = abi.encodeCall(
            entropy.configureCollection,
            (1, address(provider), keccak256("collection salt"), true, uint64(100))
        );
        batches[0].callDatas[records.length + 1] = data;
        batches[0].calls[records.length + 1] = _configurationCall(address(entropy), data);
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
        batches[2].actionClass = 1;
        batches[2].calls = new GovernanceCall[](7);
        batches[2].callDatas = new bytes[](7);
        data = abi.encodeCall(
            router.setCollectionMetadata,
            (1, "Stream Genesis", "Current stack development deployment", "", "")
        );
        batches[2].callDatas[0] = data;
        batches[2].calls[0] = _configurationCall(address(router), data);
        data = abi.encodeCall(royalty.configureCollectionRoyalty, (1, profile, uint16(690)));
        batches[2].callDatas[1] = data;
        batches[2].calls[1] = _configurationCall(address(royalty), data);
        data = abi.encodeCall(
            router.setCollectionScript,
            (
                1,
                "const c=document.createElement('canvas');c.width=c.height=800;document.body.style.margin='0';document.body.append(c);const x=c.getContext('2d');x.fillStyle='#101217';x.fillRect(0,0,800,800);for(let i=0;i<32;i++){x.fillStyle='#'+tokenHash.slice(2+i,8+i);x.fillRect(30+i*23,80+(i%4)*140,18,420)}x.fillStyle='white';x.font='32px monospace';x.fillText('STREAM #'+tokenId,40,740);"
            )
        );
        batches[2].callDatas[2] = data;
        batches[2].calls[2] = _configurationCall(address(router), data);
        data = abi.encodeCall(
            primaryRevenue.setPrimaryProfileAssignment,
            (PRIMARY_REVENUE_CLASS, uint8(1), uint256(1), profile, bytes32(0))
        );
        batches[2].callDatas[3] = data;
        batches[2].calls[3] = _configurationCall(address(primaryRevenue), data);
        (batches[2].calls[4], batches[2].callDatas[4]) = _escrowProducerCall(address(sale));
        (batches[2].calls[5], batches[2].callDatas[5]) = _escrowProducerCall(address(erc20Sale));
        (batches[2].calls[6], batches[2].callDatas[6]) = _escrowProducerCall(address(auction));
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
            bytes(
                "{\"purpose\":\"current-stack development deployment; not release evidence\",\"version\":1}"
            )
        );
        binding.expectedManifestHash = payloadHash;
        binding.expectedTriggers = new SystemManifestBootstrapTriggerExpectation[](2);
        binding.expectedTriggers[0] = SystemManifestBootstrapTriggerExpectation(
            address(core), core.updateSatellitePointer.selector, address(core).codehash, 8
        );
        binding.expectedTriggers[1] = SystemManifestBootstrapTriggerExpectation(
            address(registry), registry.setModuleStatus.selector, address(registry).codehash, 3
        );
        if (address(core) > address(registry)) {
            (binding.expectedTriggers[0], binding.expectedTriggers[1]) =
            (binding.expectedTriggers[1], binding.expectedTriggers[0]);
        }
        binding.actionPolicyCandidateProfileHash = DEPLOYMENT_HASH;
        batches[4].actionClass = 3;
        batches[4].calls = new GovernanceCall[](2);
        batches[4].callDatas = new bytes[](2);
        batches[4].calls[0].target = address(executor);
        batches[4].calls[0].selector = executor.sealSystemManifestBootstrap.selector;
        batches[4].calls[1].target = address(manifest);
        batches[4].calls[1].selector = manifest.publishStreamSystemManifest.selector;
        binding.actionPolicies = _actionPolicies(batches);
        binding.expectedActionPolicyCatalogHash = StreamGovernanceActionPolicy.expectedCatalogHash(
            address(executor), binding.actionPolicyCandidateProfileHash, binding.actionPolicies
        );
        (batches[4].calls[0], batches[4].callDatas[0]) =
            StreamGenesisManifestPlan.sealCall(executor, deployer, binding, payload);
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate({
            manifestHash: payloadHash,
            manifestURI: "urn:6529stream:current-stack:development",
            eventCatalogHash: keccak256("development events"),
            compatibilityMatrixHash: keccak256("development compatibility"),
            numericIdCatalogHash: keccak256("development numeric ids"),
            schemaCatalogHash: keccak256("development schema"),
            canonicalizationCatalogHash: keccak256("development canonicalization"),
            specBundleHash: keccak256("development spec"),
            reconstructionClientHash: keccak256("development client")
        });
        StreamSystemManifest.ModuleAddresses memory modules;
        modules.revenueResolver = address(royalty);
        modules.artistRegistry = address(artistRegistry);
        modules.metadataRouter = address(router);
        modules.entropyCoordinator = address(entropy);
        modules.mintManager = address(manager);
        modules.mintLedger = address(ledger);
        modules.streamAdminsOrGovernance = address(executor);
        modules.moduleRegistry = address(registry);
        modules.stateExportPublisher = address(executor);
        (batches[4].calls[1], batches[4].callDatas[1]) =
            StreamGenesisManifestPlan.firstPublicationCall(manifest, payload, update, modules);
        executor.commitGenesisPlan(executor.hashGenesisPlan(binding, batches));
        // Bind the committed catalog in its own transaction so product activation
        // and the final seal remain atomic within the chain's transaction gas cap.
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
        rows = new GovernanceActionPolicyEntry[](localDevelopment ? 73 : 74);
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
        rows[i++] = _operatingPolicy(3, address(executor), bytes4(0x9ad52a32));
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
        // Metadata/entropy configuration is also collected from genesis.
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
