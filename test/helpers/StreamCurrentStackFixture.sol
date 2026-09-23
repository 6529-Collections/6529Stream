// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistSuiteFixture.sol";
import "./ArtistArtifactCreate.sol";
import { StreamCurrentTestProductActivation } from "./StreamCurrentTestProductActivation.sol";
import { StreamCurrentTestSetupPlans } from "./StreamCurrentTestSetupPlans.sol";
import {
    StreamCurrentTestAuthorityPlans as CurrentAuthorityPlans
} from "./StreamCurrentTestAuthorityPlans.sol";
import {
    IStreamSetupPlansMintManager,
    IStreamSetupPlansMintLedger,
    IStreamSetupPlansFixedPriceSaleAdapter,
    IStreamSetupPlansEnglishAuctionHouse,
    IStreamSetupPlansEntropyCoordinator,
    IStreamSetupPlansMetadataRouter,
    IStreamSetupPlansAssetPolicyRegistry,
    IStreamSetupPlansCore,
    IStreamSetupPlansRoyaltyResolver,
    IStreamSetupPlansGovernanceExecutor,
    IStreamSetupPlansRoleRegistry,
    IStreamSetupPlansModuleRegistry,
    IStreamSetupPlansSystemManifest,
    IStreamSetupPlansSplitFactory,
    IStreamSetupPlansArtistOnboardingRegistry,
    IStreamSetupPlansRevenueEscrow,
    IStreamSetupPlansRevenueResolver
} from "./StreamCurrentTestSetupPlanTargets.sol";
import {
    IStreamCollectionMetadataV1
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamArtworkFinalityRegistry
} from "../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import "../../smart-contracts/core/StreamCore.sol";
import "../../smart-contracts/domains/governance/StreamGovernanceExecutor.sol";
import "../../smart-contracts/domains/governance/StreamGovernanceActor.sol";
import "../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import "../../smart-contracts/domains/governance/StreamSystemManifest.sol";
import "../../smart-contracts/interfaces/stream/governance/IStreamStateExportPublisher.sol";
import { StreamMintManager } from "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol";
import "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import { StreamRevenueEscrow } from "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import {
    StreamMetadataRouter
} from "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../script/current/StreamCurrentStackPlan.sol";
import { StreamEntropyLifecyclePlan } from "../../script/current/StreamEntropyLifecyclePlan.sol";
import "../../script/current/StreamArtistActivationPlan.sol";
import "../../script/current/StreamRevealActivationPlan.sol";
import "../../script/current/StreamGenesisManifestPlan.sol";
import "../../script/current/StreamGovernanceGenesisPlan.sol";
import "../mocks/MockStreamEntropyProvider.sol";

/// @notice One real current-stack topology. Only the external entropy service is a test double.
abstract contract StreamCurrentStackFixture is StreamArtistSuiteFixture, ArtistArtifactCreate {
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
    GovernanceActionPolicyEntry[] private _foundationPolicies;
    uint64 private _fixtureCatalogRevision;

    /// @dev Exact retained admission rows for additive current-stack ceremony fixtures.
    /// The Executor exposes only their aggregate commitment; this does not reconstruct policy.
    function _retainedFoundationPolicies()
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return _foundationPolicies;
    }

    function _deployCurrentStack(address artist_, address platform) internal virtual {
        _deployCurrentStackFoundation(artist_);
        _deployCurrentStackProducts(platform);
        _activateCurrentStack();
    }

    function _deployCurrentStackFoundation(address artist_) internal {
        artist = artist_;
        executor = StreamGovernanceExecutor(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/governance/StreamGovernanceExecutor.sol:StreamGovernanceExecutor",
                    abi.encode(address(this))
                ))
        );
        governanceRoot = StreamGovernanceActor(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/governance/StreamGovernanceActor.sol:StreamGovernanceActor",
                    abi.encode(address(this))
                ))
        );
        guardians = new address[](2);
        guardians[0] = address(
            StreamGovernanceActor(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/governance/StreamGovernanceActor.sol:StreamGovernanceActor",
                        abi.encode(address(this))
                    ))
            )
        );
        guardians[1] = address(
            StreamGovernanceActor(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/governance/StreamGovernanceActor.sol:StreamGovernanceActor",
                        abi.encode(address(this))
                    ))
            )
        );
        if (guardians[0] > guardians[1]) {
            (guardians[0], guardians[1]) = (guardians[1], guardians[0]);
        }
        roles = StreamRoleRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/governance/StreamRoleRegistry.sol:StreamRoleRegistry",
                    abi.encode(address(executor))
                ))
        );
        registry = StreamModuleRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/modules/StreamModuleRegistry.sol:StreamModuleRegistry",
                    abi.encode(executor, REGISTRY_HASH, "urn:6529stream:fixture:registry")
                ))
        );
        core = StreamCore(
            payable(_artistArtifactCreate(
                    "smart-contracts/core/StreamCore.sol:StreamCore",
                    abi.encode(
                        "6529 Stream",
                        "STREAM",
                        address(executor),
                        StreamCore.GenesisModuleRegistryConfig(
                            address(registry),
                            address(registry).codehash,
                            REGISTRY_HASH,
                            DEPLOYMENT_HASH
                        ),
                        StreamCurrentStackPlan.gasParameters()
                    )
                ))
        );
        manifest = StreamSystemManifest(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/governance/StreamSystemManifest.sol:StreamSystemManifest",
                    abi.encode(address(core), address(executor))
                ))
        );
        _initializeGovernanceFoundation();
        ledger = StreamMintLedger(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamMintLedger.sol:StreamMintLedger",
                    abi.encode()
                ))
        );
        manager = StreamMintManager(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamMintManager.sol:StreamMintManager",
                    abi.encode(core, ledger, IERC165(address(registry)))
                ))
        );
        ledger.setLedgerWriter(address(manager), true);
        assetPolicy = StreamAssetPolicyRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol:StreamAssetPolicyRegistry",
                    abi.encode(address(executor))
                ))
        );
        factory = StreamSplitFactory(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamSplitFactory.sol:StreamSplitFactory",
                    abi.encode(assetPolicy, address(executor), _walletGasConfigs())
                ))
        );
    }

    function _deployCurrentStackProducts(address platform) internal {
        _deployArtistSuite(
            address(core),
            address(manager),
            address(roles),
            factory,
            address(executor),
            DEPLOYMENT_HASH
        );
        IStreamArtistAttribution attribution = IStreamArtistAttribution(address(artists));
        revenueEscrow = StreamRevenueEscrow(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/revenue/StreamRevenueEscrow.sol:StreamRevenueEscrow",
                    abi.encode(
                        factory,
                        address(executor),
                        IStreamGasParameterHost.GasParameterConfig(
                            "FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3
                        )
                    )
                ))
        );
        sale = StreamFixedPriceSaleAdapter(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol:StreamFixedPriceSaleAdapter",
                    abi.encode(manager, primaryResolver, platform, attribution, revenueEscrow)
                ))
        );
        auction = StreamEnglishAuctionHouse(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol:StreamEnglishAuctionHouse",
                    abi.encode(core, manager, primaryResolver, platform, attribution, revenueEscrow)
                ))
        );
        entropy = StreamEntropyCoordinator(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator",
                    abi.encode(
                        StreamEntropyCoordinator.DeploymentConfig(
                            address(core),
                            address(executor),
                            address(roles),
                            StreamCurrentStackPlan.entropyTimeParameters(),
                            DEPLOYMENT_HASH,
                            "urn:6529stream:fixture:entropy",
                            keccak256("fixture entropy module")
                        )
                    )
                ))
        );
        provider = MockStreamEntropyProvider(
            payable(_artistArtifactCreate(
                    "test/mocks/MockStreamEntropyProvider.sol:MockStreamEntropyProvider",
                    abi.encode(address(entropy))
                ))
        );
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(artist, 900_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(PROTOCOL, 100_000, keccak256("protocol"));
        (profile, wallet) = factory.createProfile(entries, keccak256("fixture split"));
        _deployAdditionalProducts();
    }

    function _activateCurrentStack() internal {
        ledger.transferOwnership(address(executor));
        sale.transferOwnership(address(executor));
        auction.transferOwnership(address(executor));
        _activateFixtureGraphPrerequisites();
        _completeFixtureArtistSuite(_currentGraphRendererCatalog(1));
        _assertDeployableProductionContracts();
        _activateInitialProducts();
        _activateArtistAuthority();
        _activateRevealAuthority();
        _prepareArtistOnboarding();
        _onboardFixtureArtist(artist);
        _expandArtistReadBudget();
        _configureMintPhase(PHASE, address(sale));
        _configureMintPhase(AUCTION_PHASE, address(auction));
        _configureAdditionalProducts();
        _handoffManager();
    }

    function _fixtureModuleRegistry() internal view override returns (address) {
        return address(registry);
    }

    function _fixtureSystemManifest() internal view override returns (address) {
        return address(manifest);
    }

    function _activateFixtureGraphPrerequisites() internal {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](3);
        records[0] = _record(
            address(router),
            keccak256("METADATA_ROUTER"),
            type(IStreamMetadataRouter).interfaceId,
            keccak256("fixture metadata module")
        );
        records[1] = _record(
            address(artists),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            keccak256("fixture artist module")
        );
        records[2] = _record(
            address(assemblyMetadata),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId,
            keccak256("current-stack collection metadata module v1")
        );
        GenesisBatch[] memory batches = new GenesisBatch[](2);
        batches[0].actionClass = 1;
        (GovernanceCall[] memory registrations, bytes[] memory registrationData) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        batches[0].calls = new GovernanceCall[](4);
        batches[0].callDatas = new bytes[](4);
        for (uint256 i; i < 3; ++i) {
            batches[0].calls[i] = registrations[i];
            batches[0].callDatas[i] = registrationData[i];
        }
        (batches[0].calls[3], batches[0].callDatas[3]) =
            StreamCurrentStackPlan.createCollectionCall(core, 1, _fixtureSupplyLimit());
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = keccak256("METADATA_ROUTER");
        keys[1] = keccak256("ARTIST_REGISTRY");
        keys[2] = keccak256("COLLECTION_METADATA");
        batches[1].actionClass = 3;
        (batches[1].calls, batches[1].callDatas) =
            StreamCurrentStackPlan.pointerCalls(core, registry, keys, records);
        _admitInitialProductPolicies(batches);
        _executeInitialBatch(batches[0]);
        GovernanceCall[] memory calls = new GovernanceCall[](4);
        bytes[] memory datas = new bytes[](4);
        for (uint256 i; i < 3; ++i) {
            calls[i] = batches[1].calls[i];
            datas[i] = batches[1].callDatas[i];
        }
        StreamSystemManifest.ModuleAddresses memory modules =
        StreamGenesisManifestPlan.readAggregate(manifest).modules;
        modules.artistRegistry = address(artists);
        modules.metadataRouter = address(router);
        modules.collectionMetadata = address(assemblyMetadata);
        (calls[3], datas[3]) =
            _initialPublication(modules, keccak256("actual early graph selection"));
        batches[1].calls = calls;
        batches[1].callDatas = datas;
        _executeInitialBatch(batches[1]);
        _requireCurrentGraphSelections();
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

    /// @dev Deploy additional products before their exact governance policies are admitted.
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

    /// @dev Additional exact-target operating selectors join the governed product catalog extension.
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

    function _expandArtistReadBudget() internal {
        StreamArtistActivationPlan.Plan memory plan =
            CurrentAuthorityPlans.buildReadBudgetExpansion(manager);
        _executeInitialBatch(GenesisBatch(1, plan.calls, plan.callDatas));
        (uint256 value,,, uint64 revision) =
            manager.gasParameterInfo(manager.GGP_ARTIST_AUTHORITY_GAS_LIMIT());
        require(value == 600_000 && revision == 3, "actual second governed artist read expansion");
    }

    function _configureMintPhase(bytes32 phase, address phaseExecutor) internal virtual {
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

    function _revealPrincipals()
        internal
        view
        virtual
        returns (StreamRevealActivationPlan.Principals memory)
    {
        return StreamRevealActivationPlan.Principals(
            address(this), address(governanceRoot), address(governanceRoot)
        );
    }

    function _configureInitialRevealPolicy() internal virtual {
        entropy.configureCollectionRevealPolicy(
            1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, 0
        );
    }

    /// @dev Existing fixture deployments exercise the three-call post-artist activation route.
    ///      New operator deployments combine these grants into the original activation batch.
    function _activateRevealAuthority() internal virtual {
        StreamRevealActivationPlan.Principals memory principals = _revealPrincipals();
        StreamArtistActivationPlan.Plan memory plan =
            CurrentAuthorityPlans.buildReveal(roles, principals);
        executor.publishGovernanceCallData(plan.callDatas);
        uint64 notBefore = uint64(block.timestamp + 49 hours);
        bytes32 actionId = _scheduleFixtureActivation(plan, notBefore);
        vm.warp(notBefore);
        CurrentAuthorityPlans.executeReveal(
            executor,
            roles,
            IStreamGasParameterHost(address(0)),
            address(0),
            principals,
            actionId,
            plan
        );
        CurrentAuthorityPlans.executeReveal(
            executor,
            roles,
            IStreamGasParameterHost(address(0)),
            address(0),
            principals,
            actionId,
            plan
        );
        _configureInitialRevealPolicy();
    }

    /// @dev One real post-genesis batch activates the artist role and required read budget.
    ///      The deployment planner returns these same calls for persistent operator resumption.
    function _activateArtistAuthority() internal virtual {
        StreamArtistActivationPlan.Plan memory plan =
            CurrentAuthorityPlans.buildArtist(roles, manager, address(this));
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
        CurrentAuthorityPlans.executeArtist(executor, roles, manager, address(this), actionId, plan);
        // A resumed completed action reuses the saved identity without creating another action.
        CurrentAuthorityPlans.executeArtist(executor, roles, manager, address(this), actionId, plan);
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
    ) internal returns (bytes32) {
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
    ) external virtual {
        _scheduleFixtureActivation(plan, notBefore);
    }

    /// @dev External boundary lets the test observe the same revert as the resumable script.
    function executeSavedArtistActivation(
        StreamArtistActivationPlan.Plan calldata plan,
        bytes32 actionId,
        address administrator
    ) external virtual {
        CurrentAuthorityPlans.executeArtist(executor, roles, manager, administrator, actionId, plan);
    }

    /// @dev Check the base topology's production instances despite Foundry's test-harness
    ///      allowance. Derived fixtures check added products with the same helper; linked
    ///      libraries also require the compiler-artifact size check at release acceptance.
    function _assertDeployableProductionContracts() internal view {
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

    /// @dev Closed snapshot of existing fixture identities for linked activation operations.
    function _productActivationContext()
        private
        view
        returns (StreamCurrentTestProductActivation.Context memory c)
    {
        c.executor = executor;
        c.governanceRoot = governanceRoot;
        c.core = core;
        c.registry = registry;
        c.manifest = manifest;
        c.manager = manager;
        c.ledger = ledger;
        c.entropy = entropy;
        c.provider = address(provider);
        c.router = router;
        c.royalties = royalties;
        c.artists = IStreamArtistMintConsent(address(artists));
        c.finality = address(assemblyFinality);
        c.primaryResolver = primaryResolver;
        c.revenueEscrow = revenueEscrow;
        c.sale = sale;
        c.auction = auction;
        c.profile = profile;
        c.deploymentHash = DEPLOYMENT_HASH;
        c.registryHash = REGISTRY_HASH;
        c.finalityManifestHash = graphFinalityManifestHash;
        c.primaryRevenueClass = PRIMARY_REVENUE_CLASS;
    }

    /// @dev New products use ordinary delayed governance after the foundation seal.
    function _activateInitialProducts() internal {
        GenesisBatch[] memory batches = new GenesisBatch[](3);
        StreamModuleRegistration[] memory records;
        (records, batches[0]) =
            StreamCurrentTestProductActivation.registrations(_productActivationContext());
        address[] memory extraProducers = _additionalEscrowProducers();
        (batches[1], batches[2]) = StreamCurrentTestProductActivation.pointersAndConfiguration(
            _productActivationContext(), records, extraProducers
        );
        _admitInitialProductPolicies(batches);
        _executeInitialBatch(batches[0]);
        GovernanceCall[] memory pointerCalls = new GovernanceCall[](records.length + 1);
        bytes[] memory pointerData = new bytes[](records.length + 1);
        for (uint256 i; i < records.length; ++i) {
            pointerCalls[i] = batches[1].calls[i];
            pointerData[i] = batches[1].callDatas[i];
        }
        (pointerCalls[records.length], pointerData[records.length]) =
            StreamCurrentTestProductActivation.initialProductPublication(
                _productActivationContext(), keccak256("initial product selection")
            );
        batches[1].calls = pointerCalls;
        batches[1].callDatas = pointerData;
        _executeInitialBatch(batches[1]);
        _executeInitialBatch(batches[2]);
        _executeInitialBatch(
            StreamEntropyLifecyclePlan.admitTightening(
                executor, address(entropy), entropy.deprecateEntropyProvider.selector
            )
        );
        _executeInitialBatch(
            StreamEntropyLifecyclePlan.admitTightening(
                executor, address(entropy), entropy.revokeEntropyProvider.selector
            )
        );
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

    function _initializeGovernanceFoundation() private {
        StreamGovernanceGenesisPlan.Configuration memory c;
        c.executor = executor;
        c.roles = roles;
        c.core = core;
        c.registry = registry;
        c.manifest = manifest;
        c.bootstrapAuthority = address(this);
        c.governanceRoot = address(governanceRoot);
        c.guardians = guardians;
        c.deploymentHash = DEPLOYMENT_HASH;
        c.manifestModuleHash = keccak256("fixture system manifest");
        c.moduleURI = "urn:6529stream:fixture:module";
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"purpose\":\"current-stack governance foundation\",\"version\":1}")
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:6529stream:current-stack:foundation",
            keccak256("fixture events"),
            keccak256("fixture compatibility"),
            keccak256("fixture numeric ids"),
            keccak256("fixture schema"),
            keccak256("fixture canonicalization"),
            keccak256("fixture spec"),
            keccak256("fixture client")
        );
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) =
            StreamCurrentTestSetupPlans.foundationPlan(c, payload, update);
        for (uint256 i; i < binding.actionPolicies.length; ++i) {
            _foundationPolicies.push(binding.actionPolicies[i]);
        }
        executor.commitGenesisPlan(executor.hashGenesisPlan(binding, batches));
        executor.prepareGenesis(binding, batches);
        executor.initializeGenesis(binding, batches);
    }

    function _admitInitialProductPolicies(GenesisBatch[] memory batches) private {
        // Preserve the original hook before observing retained policy state.
        GovernanceActionPolicyEntry[] memory operating = _operatingPolicies();
        GovernanceActionPolicyEntry[] memory retained = _foundationPolicies;
        (GovernanceActionPolicyEntry[] memory additions, uint64 appliedRevision) =
            StreamCurrentTestProductActivation.admitPolicies(
                _productActivationContext(), retained, _fixtureCatalogRevision, operating, batches
            );
        if (additions.length == 0) return;
        _fixtureCatalogRevision = appliedRevision;
        for (uint256 i; i < additions.length; ++i) {
            _foundationPolicies.push(additions[i]);
        }
    }

    function _initialPublication(
        StreamSystemManifest.ModuleAddresses memory modules,
        bytes32 reason
    ) private returns (GovernanceCall memory call_, bytes memory data) {
        return StreamCurrentTestProductActivation.publication(_productActivationContext(), modules, reason);
    }

    function _executeInitialBatch(GenesisBatch memory batch) private {
        StreamCurrentTestProductActivation.executeBatch(_productActivationContext(), batch);
    }

    function _operatingPolicies() private view returns (GovernanceActionPolicyEntry[] memory rows) {
        GovernanceActionPolicyEntry[] memory additional = _additionalOperatingPolicies();
        StreamCurrentTestSetupPlans.Targets memory targets;
        targets.manager = IStreamSetupPlansMintManager(address(manager));
        targets.ledger = IStreamSetupPlansMintLedger(address(ledger));
        targets.sale = IStreamSetupPlansFixedPriceSaleAdapter(address(sale));
        targets.auction = IStreamSetupPlansEnglishAuctionHouse(address(auction));
        targets.entropy = IStreamSetupPlansEntropyCoordinator(address(entropy));
        targets.router = IStreamSetupPlansMetadataRouter(address(router));
        targets.assetPolicy = IStreamSetupPlansAssetPolicyRegistry(address(assetPolicy));
        targets.core = IStreamSetupPlansCore(address(core));
        targets.royalties = IStreamSetupPlansRoyaltyResolver(address(royalties));
        targets.executor = IStreamSetupPlansGovernanceExecutor(address(executor));
        targets.roles = IStreamSetupPlansRoleRegistry(address(roles));
        targets.registry = IStreamSetupPlansModuleRegistry(address(registry));
        targets.manifest = IStreamSetupPlansSystemManifest(address(manifest));
        targets.factory = IStreamSetupPlansSplitFactory(address(factory));
        targets.artists = IStreamSetupPlansArtistOnboardingRegistry(address(artists));
        targets.revenueEscrow = IStreamSetupPlansRevenueEscrow(address(revenueEscrow));
        targets.primaryResolver = IStreamSetupPlansRevenueResolver(address(primaryResolver));
        return StreamCurrentTestSetupPlans.operatingPolicies(targets, DEPLOYMENT_HASH, additional);
    }
}
