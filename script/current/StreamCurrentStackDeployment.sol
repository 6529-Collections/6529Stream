// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/core/StreamCore.sol";
import "../../smart-contracts/domains/artist/StreamCollectionArtistRegistry.sol";
import "../../smart-contracts/domains/governance/StreamGovernanceExecutor.sol";
import "../../smart-contracts/domains/governance/StreamGovernanceActor.sol";
import "../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import "../../smart-contracts/domains/governance/StreamSystemManifest.sol";
import "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol";
import "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "./StreamCurrentStackPlan.sol";
import "./StreamGenesisManifestPlan.sol";
import "./DevelopmentEntropyProvider.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol";

/// @notice Reusable development/testnet genesis assembly for the actual current stack.
abstract contract StreamCurrentStackDeployment {
    bytes32 internal constant PHASE = keccak256("current-stack fixed price");
    bytes32 internal constant AUCTION_PHASE = keccak256("current-stack auction");
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
    StreamEnglishAuctionHouse internal auction;
    StreamSplitFactory internal factory;
    StreamAssetPolicyRegistry internal assetPolicy;
    StreamRoyaltyResolver internal royalty;
    StreamCollectionArtistRegistry internal artistRegistry;
    StreamEntropyCoordinator internal entropy;
    StreamMetadataRouter internal router;
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
        assetPolicy = new StreamAssetPolicyRegistry();
        factory = new StreamSplitFactory(assetPolicy);
        royalty = new StreamRoyaltyResolver(core, factory, address(executor));
        artistRegistry = new StreamCollectionArtistRegistry(
            address(core),
            address(executor),
            DEPLOYMENT_HASH,
            "urn:6529stream:development:artist",
            keccak256("development artist module")
        );
        sale = new StreamFixedPriceSaleAdapter(manager, factory, platform, artistRegistry);
        auction = new StreamEnglishAuctionHouse(core, manager, factory, platform, artistRegistry);
        entropy = new StreamEntropyCoordinator(
            address(core),
            address(executor),
            DEPLOYMENT_HASH,
            "urn:6529stream:development:entropy",
            keccak256("development entropy module")
        );
        // Keep the broadcast initcode identical to the named compiler artifact.
        // A specialized `new` expression can otherwise defeat Forge's constructor decoder.
        bytes memory routerInitcode = bytes.concat(
            type(StreamMetadataRouter).creationCode,
            abi.encode(
                address(core), address(executor), DEPLOYMENT_HASH,
                "urn:6529stream:development:metadata",
                keccak256("development metadata module"), artistRegistry
            )
        );
        address deployedRouter;
        assembly ("memory-safe") {
            deployedRouter := create(0, add(routerInitcode, 32), mload(routerInitcode))
        }
        require(deployedRouter != address(0), "metadata deployment failed");
        router = StreamMetadataRouter(deployedRouter);
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
        _configureMintPhase(PHASE, address(sale));
        _configureMintPhase(AUCTION_PHASE, address(auction));
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(protocol, 100_000, keccak256("protocol"));
        (profile, wallet) = factory.createProfile(entries, keccak256("development split"));
        ledger.transferOwnership(address(executor));
        manager.transferOwnership(address(executor));
        sale.transferOwnership(address(executor));
        auction.transferOwnership(address(executor));
        assetPolicy.transferOwnership(address(executor));
        _initializeProductGenesis();
        if (artist == deployer) {
            IStreamCollectionArtistRegistry.Attribution memory item = artistRegistry.attribution(1);
            artistRegistry.acceptArtist(
                1,
                item.nominationHash,
                artistRegistry.acceptanceNonces(artist),
                uint64(block.timestamp + 1 days),
                ""
            );
        }
    }

    function _configureMintPhase(bytes32 phase, address phaseExecutor) private {
        bytes32[] memory counters = new bytes32[](1);
        counters[0] = keccak256("supply");
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](1);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        manager.configurePhase(
            1,
            phase,
            IStreamMintManager.MintPhaseConfig(
                false, 0, 0, 1, keccak256("phase"), keccak256("metadata")
            ),
            gate,
            counters,
            configs
        );
        manager.setPhaseExecutor(1, phase, phaseExecutor, true);
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
        GenesisBatch[] memory batches = new GenesisBatch[](4);
        batches[0].actionClass = 1;
        (GovernanceCall[] memory registrations, bytes[] memory registrationData) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        batches[0].calls = new GovernanceCall[](records.length + 6);
        batches[0].callDatas = new bytes[](records.length + 6);
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
        data = abi.encodeCall(
            router.setCollectionMetadata,
            (1, "Stream Genesis", "Current stack development deployment", "", "")
        );
        batches[0].callDatas[records.length + 2] = data;
        batches[0].calls[records.length + 2] = _configurationCall(address(router), data);
        data = abi.encodeCall(royalty.configureCollectionRoyalty, (1, profile, uint16(690)));
        batches[0].callDatas[records.length + 3] = data;
        batches[0].calls[records.length + 3] = _configurationCall(address(royalty), data);
        data = abi.encodeCall(
            router.setCollectionScript,
            (
                1,
                "const c=document.createElement('canvas');c.width=c.height=800;document.body.style.margin='0';document.body.append(c);const x=c.getContext('2d');x.fillStyle='#101217';x.fillRect(0,0,800,800);for(let i=0;i<32;i++){x.fillStyle='#'+tokenHash.slice(2+i,8+i);x.fillRect(30+i*23,80+(i%4)*140,18,420)}x.fillStyle='white';x.font='32px monospace';x.fillText('STREAM #'+tokenId,40,740);"
            )
        );
        batches[0].callDatas[records.length + 4] = data;
        batches[0].calls[records.length + 4] = _configurationCall(address(router), data);
        data = abi.encodeCall(
            artistRegistry.nominateArtist, (1, artist, keccak256("development artist attribution"))
        );
        batches[0].callDatas[records.length + 5] = data;
        batches[0].calls[records.length + 5] = _configurationCall(address(artistRegistry), data);

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
        batches[2].actionClass = 2;
        batches[2].calls = new GovernanceCall[](1);
        batches[2].callDatas = new bytes[](1);
        (batches[2].calls[0], batches[2].callDatas[0]) =
            StreamCurrentStackPlan.freezeManifestCall(core, registry, records[1]);
        _sealProductPlan(batches, pointerTypes, pointerRecords, records);
    }

    function _moduleRecords() private view returns (StreamModuleRegistration[] memory records) {
        records = new StreamModuleRegistration[](8);
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
            type(IStreamCollectionArtistRegistry).interfaceId,
            keccak256("development artist module")
        );
    }

    function _pointerType(bytes32 moduleType) private pure returns (bytes32) {
        if (moduleType == 0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6) {
            return keccak256("SYSTEM_MANIFEST");
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
        batches[3].actionClass = 3;
        batches[3].calls = new GovernanceCall[](2);
        batches[3].callDatas = new bytes[](2);
        batches[3].calls[0].target = address(executor);
        batches[3].calls[0].selector = executor.sealSystemManifestBootstrap.selector;
        batches[3].calls[1].target = address(manifest);
        batches[3].calls[1].selector = manifest.publishStreamSystemManifest.selector;
        binding.actionPolicies = _actionPolicies(batches);
        binding.expectedActionPolicyCatalogHash = StreamGovernanceActionPolicy.expectedCatalogHash(
            address(executor), binding.actionPolicyCandidateProfileHash, binding.actionPolicies
        );
        (batches[3].calls[0], batches[3].callDatas[0]) =
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
        (batches[3].calls[1], batches[3].callDatas[1]) =
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
        rows = new GovernanceActionPolicyEntry[](localDevelopment ? 52 : 53);
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
        // Artist nomination and metadata/entropy configuration are also collected from genesis.
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
