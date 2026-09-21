// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/StreamCurrentStackFixture.sol";
import { StreamFullV1Candidate } from "../../script/current/StreamFullV1Candidate.sol";
import { StreamFullV1GenesisProducts } from "../../script/current/StreamFullV1GenesisProducts.sol";
import { StreamFullV1RecordProducts } from "../../script/current/StreamFullV1RecordProducts.sol";
import {
    StreamFullV1StaticRendererPlan
} from "../../script/current/StreamFullV1StaticRendererPlan.sol";
import {
    StreamFullV1CommerceProducts
} from "../../script/current/StreamFullV1CommerceProducts.sol";
import {
    StreamFullV1ContinuityProducts
} from "../../script/current/StreamFullV1ContinuityProducts.sol";
import { StreamMintFallbackPlan } from "../../script/current/StreamMintFallbackPlan.sol";
import { StreamEntropyFallbackPlan } from "../../script/current/StreamEntropyFallbackPlan.sol";
import {
    StreamEntropyProviderVRF
} from "../../smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol";
import {
    StreamEntropyProviderARRNG
} from "../../smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol";
import { StreamBurnMintGate } from "../../smart-contracts/domains/mint/StreamBurnMintGate.sol";
import "../mocks/MockVRFCoordinatorV2Plus.sol";
import { CurrentARRNGService } from "./StreamCurrentARRNG.t.sol";
import { GenesisDelegationServiceDouble } from "./StreamCurrentFullV1GenesisProducts.t.sol";
import {
    IStreamRenderer as Render
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as Versions
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    StreamSplitWalletDeployment
} from "../../smart-contracts/domains/revenue/StreamSplitWalletDeployment.sol";

/// @notice All37 original role products are constructed on the same actual current graph.
/// @dev This is a construction cohort. It does not claim full37 activation, canonical schema
/// publication, renderer analysis, native execution, final gas/size acceptance or readiness.
/// Inherited upstream entropy, external VRF/ARRNG and delegation services are explicit doubles;
/// the role31/32/34 adapter/Coordinator products themselves are the original contracts.
contract StreamCurrentFullV1CandidateTest is StreamCurrentStackFixture {
    StreamFullV1Candidate.Foundation private foundation;
    StreamFullV1Candidate.Configuration private configuration;
    StreamFullV1Candidate.Products private products;
    MockVRFCoordinatorV2Plus private vrfService;
    bytes32 private savedInventoryHash;

    function setUp() public {
        _deployCurrentStack(vm.addr(ARTIST_KEY), vm.addr(PLATFORM_KEY));
        _foundation();
        _commerce();
        _independent();
        _records();
        _rendering();
        _providers();
        _continuity();
        savedInventoryHash = StreamFullV1Candidate.inventoryHash(
            StreamFullV1Candidate.capture(foundation, configuration, products)
        );
    }

    function testAll37OriginalRolesAndMandatoryCompanionsArePresent() public view {
        StreamFullV1Candidate.Inventory memory actual =
            StreamFullV1Candidate.capture(foundation, configuration, products);
        require(
            actual.schemaVersion == 1 && actual.chainId == block.chainid
                && actual.deploymentHash == DEPLOYMENT_HASH,
            "current chain and original deployment"
        );
        require(
            actual.constructionHash == keccak256(abi.encode(foundation, configuration, products)),
            "complete saved construction tuple"
        );
        for (uint256 i; i < 37; ++i) {
            require(
                actual.roles[i].code.length != 0
                    && actual.runtimeHashes[i] == actual.roles[i].codehash,
                "real original role bytes"
            );
        }
        require(
            actual.roles[8] == address(products.commerce.native.recorder)
                && actual.roles[13] == address(products.commerce.fixedSale)
                && actual.roles[15] == address(products.commerce.dutch)
                && actual.roles[26] == address(products.records.preservation)
                && actual.roles[27] == address(products.independent.attestations),
            "actual semantic product mapping"
        );
        require(
            actual.support.length == 25
                && actual.support[15].target == address(products.records.general)
                && actual.support[9].target == artistSuite.owners[4]
                && actual.support[16].target == address(products.continuity.provider),
            "required physical companions"
        );
        StreamFullV1Candidate.requireUnchanged(
            foundation, configuration, products, savedInventoryHash
        );
    }

    function testRole6IsLockedFactoryImplementationAndActualProfileUsesItsClone() public {
        address singleton = factory.splitWalletImplementation();
        require(
            products.continuity.walletImplementation == singleton && wallet != singleton
                && factory.WALLET_VERSION() == 4
                && singleton.codehash == factory.splitWalletImplementationCodeHash(),
            "actual implementation getter not unused template"
        );
        require(
            wallet.code.length == 52
                && wallet.codehash == StreamSplitWalletDeployment.runtimeCodeHash(singleton)
                && factory.walletFor(profile) == wallet
                && IStreamSplitWallet(wallet).profileId() == profile,
            "original deterministic clone uses recorded implementation"
        );
        vm.prank(address(factory));
        vm.expectRevert(abi.encodeWithSelector(IStreamSplitWallet.AlreadyInitialized.selector));
        IStreamSplitWallet(singleton)
            .initialize(
                0, 0, 0, new IStreamSplitWallet.SplitEntry[](0), new address[](0), new uint32[](0)
            );
    }

    function testFallbackConstructionRetainsSameLedgerAndOwnProviderWithoutClaimingActivation()
        public
    {
        StreamMintFallbackPlan.Configuration memory mint =
            StreamFullV1ContinuityProducts.mintConfiguration(
                configuration.continuity, products.continuity
            );
        StreamMintFallbackPlan.validate(mint);
        require(
            address(products.continuity.manager) != address(manager)
                && address(products.continuity.manager.mintLedger()) == address(ledger)
                && products.continuity.manager.owner() == address(executor),
            "ordinary original backup Manager"
        );
        require(
            address(products.continuity.entropy) != address(entropy)
                && products.continuity.provider.coordinator()
                    == address(products.continuity.entropy)
                && products.vrf.coordinator() == address(entropy),
            "separate real Coordinator/provider pairs"
        );
        StreamModuleRegistration[] memory rows = StreamFullV1ContinuityProducts.registrations(
            configuration.continuity, products.continuity
        );
        require(
            rows[0].moduleType == keccak256("MINT_MANAGER")
                && rows[1].moduleType == keccak256("ENTROPY_COORDINATOR")
                && rows[2].module == address(products.continuity.provider),
            "original module kinds, no invented pointers"
        );
        require(
            !ledger.ledgerWriter(address(products.continuity.manager)),
            "constructor did not grant writer authority"
        );
        vm.expectRevert();
        this.requireReserve();
    }

    function testMissingProviderAndReusedPrimaryCoordinatorRejectCompleteInventory() public {
        StreamFullV1Candidate.Products memory changed = products;
        changed.arrng = StreamEntropyProviderARRNG(payable(address(0)));
        vm.expectRevert();
        this.capture(changed);
        changed = products;
        changed.continuity.entropy = entropy;
        changed.continuity.entropyCodeHash = address(entropy).codehash;
        vm.expectRevert();
        this.capture(changed);
        StreamFullV1Candidate.requireUnchanged(
            foundation, configuration, products, savedInventoryHash
        );
    }

    function testRecordedSingletonCannotBeReplacedByProfileWalletAndRuntimeDriftFails() public {
        StreamFullV1Candidate.Products memory changed = products;
        changed.continuity.walletImplementation = wallet;
        changed.continuity.walletImplementationCodeHash = wallet.codehash;
        vm.expectRevert();
        this.capture(changed);
        vm.etch(address(products.independent.claims), hex"00");
        vm.expectRevert();
        this.capture(products);
    }

    function capture(StreamFullV1Candidate.Products memory p) external view {
        StreamFullV1Candidate.capture(foundation, configuration, p);
    }

    function testChangedAdmissionMetadataCannotReuseRetainedConstructionHash() public {
        StreamFullV1Candidate.Configuration memory changed = configuration;
        StreamFullV1Candidate.Products memory p = products;
        changed.continuity.mintVersion = keccak256("different proposed admission version");
        p.continuity.configurationHash = keccak256(abi.encode(changed.continuity));
        StreamFullV1Candidate.Inventory memory next =
            StreamFullV1Candidate.capture(foundation, changed, p);
        require(
            next.roles[34] == address(products.continuity.manager)
                && next.runtimeHashes[34] == address(products.continuity.manager).codehash
                && StreamFullV1Candidate.inventoryHash(next) != savedInventoryHash,
            "same runtime cannot silently change retained admission metadata"
        );
        vm.expectRevert();
        this.checkRetained(changed, p);
    }

    function checkRetained(
        StreamFullV1Candidate.Configuration memory c,
        StreamFullV1Candidate.Products memory p
    ) external view {
        StreamFullV1Candidate.requireUnchanged(foundation, c, p, savedInventoryHash);
    }

    function requireReserve() external view {
        StreamEntropyFallbackPlan.Collection[] memory rows =
            new StreamEntropyFallbackPlan.Collection[](1);
        rows[0].id = 1;
        rows[0].provider = address(products.continuity.provider);
        StreamFullV1ContinuityProducts.configuredReserveCheckpoint(
            configuration.continuity,
            products.continuity,
            rows,
            keccak256("fixture subjects only; not a completeness proof")
        );
    }

    function _foundation() private {
        foundation = StreamFullV1Candidate.Foundation(
            core,
            executor,
            registry,
            primaryResolver,
            royalties,
            factory,
            revenueEscrow,
            assetPolicy,
            manager,
            ledger,
            artists,
            router,
            assemblyMetadata,
            assemblySchemas,
            entropy,
            assemblyFinality,
            manifest,
            assemblyCoreAdapter
        );
    }

    function _commerce() private {
        StreamFullV1CommerceProducts.Configuration memory c;
        c.resolver = primaryResolver;
        c.registry = registry;
        c.escrow = revenueEscrow;
        c.deploymentHash = DEPLOYMENT_HASH;
        c.commerceManifestHash = keccak256("full37 construction commerce fixture");
        c.auction.manager = manager;
        c.auction.platform = vm.addr(PLATFORM_KEY);
        c.auction.artists = IStreamArtistAttribution(address(artists));
        c.auction.entropy = IStreamRevealFeeEscrow(address(entropy));
        c.auction.roles = roles;
        c.auction.authority = address(executor);
        c.auction.parameters[0] = _gas("SALE_ERC1271_GAS_LIMIT", 1000000, 350000, 2);
        c.auction.parameters[1] = _gas("SALE_ARTIST_AUTHORITY_GAS_LIMIT", 2000000, 50000, 2);
        c.auction.parameters[2] = _gas("REVEAL_ATTEMPT_GAS_LIMIT", 4000000, 50000, 2);
        c.auction.parameters[3] = _gas("SALE_NFT_DELIVERY_GAS_LIMIT", 300000, 100000, 2);
        c.dutch.manager = c.auction.manager;
        c.dutch.platform = c.auction.platform;
        c.dutch.artists = c.auction.artists;
        c.dutch.entropy = c.auction.entropy;
        c.dutch.roles = c.auction.roles;
        c.dutch.authority = c.auction.authority;
        for (uint256 i; i < 3; ++i) {
            c.dutch.parameters[i] = c.auction.parameters[i];
        }
        c.fixedRevealGas = c.auction.parameters[2];
        c.privateSale.core = address(core);
        c.privateSale.moduleRegistry = address(registry);
        c.privateSale.platformSigner = c.auction.platform;
        c.privateSale.configurationOwner = address(executor);
        c.privateSale.governanceAuthority = address(executor);
        c.privateSale.roleRegistry = address(roles);
        c.privateSale.parameters[0] = c.auction.parameters[0];
        c.privateSale.parameters[1] = c.auction.parameters[3];
        c.privateSale.parameters[2] = _gas("SALE_ROYALTY_DELIVERY_GAS_LIMIT", 300000, 100000, 2);
        c.burn = StreamBurnMintGate.Configuration(
            address(core),
            address(registry),
            address(executor),
            address(executor),
            DEPLOYMENT_HASH,
            keccak256("full37 burn fixture"),
            "urn:fixture:full37:burn",
            _gas("BURN_DEPENDENCY_READ_GAS", 300000, 100000, 2),
            _gas("BURN_EXECUTION_GAS", 2000000, 200000, 2),
            c.fixedRevealGas
        );
        configuration.commerce = c;
        products.commerce = StreamFullV1CommerceProducts.deploy(c);
    }

    function _independent() private {
        StreamFullV1GenesisProducts.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.metadata = address(assemblyMetadata);
        c.schemas = address(assemblySchemas);
        c.ticketSigner = vm.addr(PLATFORM_KEY);
        c.ticketSignerKind = 1;
        c.delegateRegistry = address(new GenesisDelegationServiceDouble());
        c.delegationUsecase = keccak256("full37 fixture");
        c.deploymentHash = DEPLOYMENT_HASH;
        c.ticket = StreamFullV1GenesisProducts.Manifest(
            keccak256("ticket fixture"), "urn:fixture:full37:ticket"
        );
        // Raw CIDs identify the exact fixture manifest strings; availability is not asserted.
        c.owner = StreamFullV1GenesisProducts.Manifest(
            keccak256("owner fixture"),
            "ipfs://bafkreia5pk3hpooi3ez6hj3swrciqmuu7rjtfqlyrzpb5u7oircdfb6cs4"
        );
        c.attestation = StreamFullV1GenesisProducts.Manifest(
            keccak256("independent fixture"),
            "ipfs://bafkreigynzqrd6gr6mudzcjouddws6ktpipeaiebfprpg7oy65thb4732q"
        );
        c.views = StreamFullV1GenesisProducts.Manifest(
            keccak256("views fixture"),
            "ipfs://bafkreibhptvt3f6daic2eoaue5ll5yybx7qdaqmscprtnmbjxlctb2bdyq"
        );
        c.delegateManifestURI = "urn:fixture:full37:delegate";
        c.signatureGas = _gas("METADATA_ERC1271_VERIFY_GAS", 400000, 90000, 2);
        c.dependencyReadGas = _gas("METADATA_DEPENDENCY_READ_GAS", 1000000, 100000, 2);
        configuration.independent = c;
        products.independent = StreamFullV1GenesisProducts.deploy(c);
    }

    function _records() private {
        StreamFullV1RecordProducts.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.metadata = address(assemblyMetadata);
        c.schemas = address(assemblySchemas);
        c.artistRegistry = address(artists);
        c.artistAttribution = artistSuite.owners[4];
        c.deploymentHash = DEPLOYMENT_HASH;
        // Raw CIDs identify the exact fixture manifest strings; availability is not asserted.
        c.preservation = StreamFullV1RecordProducts.Manifest(
            keccak256("preservation fixture"),
            "ipfs://bafkreihxue4twi4fl2qk633elezaie53r6zyhxxrv4padp5gufellkwj3q"
        );
        c.general = StreamFullV1RecordProducts.Manifest(
            keccak256("general fixture"),
            "ipfs://bafkreifsiudnavzt2ubxgnrfs2aajcxxeqf3gqqhlzbvzwrbld3smjvki4"
        );
        c.signatureGas = configuration.independent.signatureGas;
        c.dependencyReadGas = configuration.independent.dependencyReadGas;
        configuration.records = c;
        products.records = StreamFullV1RecordProducts.deploy(c);
    }

    function _providers() private {
        vrfService = new MockVRFCoordinatorV2Plus();
        CurrentARRNGService service =
            new CurrentARRNGService(address(governanceRoot), vm.addr(PLATFORM_KEY));
        StreamFullV1Candidate.ProviderConfiguration memory c;
        c.vrf = _vrf(address(entropy));
        c.arrng = StreamEntropyProviderARRNG.Config(
            address(entropy),
            address(executor),
            address(service),
            address(service).codehash,
            address(governanceRoot),
            vm.addr(PLATFORM_KEY),
            address(governanceRoot),
            100,
            2000000
        );
        c.deploymentHash = DEPLOYMENT_HASH;
        c.vrfManifestURI = "urn:fixture:full37:vrf";
        c.vrfManifestHash = keccak256("full37 VRF fixture");
        c.arrngManifestURI = "urn:fixture:full37:arrng";
        c.arrngManifestHash = keccak256("full37 ARRNG fixture");
        (products.vrf, products.arrng) = StreamFullV1Candidate.deployProviders(foundation, c);
    }

    function _vrf(address coordinator)
        private
        view
        returns (StreamEntropyProviderVRF.Config memory)
    {
        return StreamEntropyProviderVRF.Config(
            coordinator,
            address(executor),
            address(vrfService),
            1,
            keccak256("fixture VRF key"),
            1,
            2000000,
            2500000,
            false
        );
    }

    function _continuity() private {
        StreamFullV1ContinuityProducts.Configuration memory c;
        c.core = core;
        c.executor = executor;
        c.registry = registry;
        c.ledger = ledger;
        c.manager = manager;
        c.factory = factory;
        c.entropy = entropy;
        c.recorder = address(products.commerce.native.recorder);
        c.deploymentHash = DEPLOYMENT_HASH;
        c.mintVersion = keccak256("full37 actual fallback Manager fixture");
        c.mint = StreamFullV1ContinuityProducts.Manifest(
            keccak256("fallback mint fixture"), "urn:fixture:full37:mint-backup"
        );
        c.entropyBackup = StreamFullV1ContinuityProducts.Manifest(
            keccak256("backup entropy fixture"), "urn:fixture:full37:entropy-backup"
        );
        c.provider = StreamFullV1ContinuityProducts.Manifest(
            keccak256("backup VRF fixture"), "urn:fixture:full37:backup-vrf"
        );
        c.moduleGas = 500000;
        c.entropyTimes = StreamCurrentStackPlan.entropyTimeParameters();
        c.backupVRF = _vrf(address(0));
        configuration.continuity = c;
        products.continuity = StreamFullV1ContinuityProducts.deploy(c);
    }

    function _rendering() private {
        configuration.rendering.core = address(core);
        configuration.rendering.executor = address(executor);
        configuration.rendering.router = address(router);
        configuration.rendering.metadata = address(assemblyMetadata);
        configuration.rendering.schemas = address(assemblySchemas);
        configuration.rendering.entropy = address(entropy);
        configuration.rendering.artist = address(artists);
        configuration.rendering.finality = address(assemblyFinality);
        configuration.rendering.deploymentHash = DEPLOYMENT_HASH;
        configuration.rendering.registryManifestURI = "urn:fixture:original-renderer-registry";
        configuration.rendering.registryManifestHash =
            keccak256("fixture renderer registry manifest");
        configuration.rendering.rendererManifest = Render.RendererManifest(
            keccak256("6529STREAM_RENDERER_V1"),
            keccak256("6529STREAM_STATIC_RENDERER_V1"),
            keccak256("STREAM_CONTEXT_V1"),
            keccak256("STATIC"),
            keccak256("explicit fixture schema bytes"),
            "urn:fixture:renderer-output-schema",
            "urn:fixture:renderer-manifest",
            keccak256("explicit fixture renderer manifest bytes"),
            16777216,
            16777216,
            false
        );
        configuration.rendering.readGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 2000000, 100000, 2
        );
        configuration.rendering.attributionGas = IStreamGasParameterHost.GasParameterConfig(
            "STATIC_ATTRIBUTION_GAS", 8000000, 8000000, 1
        );
        configuration.rendering.goldenGas = IStreamGasParameterHost.GasParameterConfig(
            "RENDERER_GOLDEN_VECTOR_GAS", 20000000, 100000, 2
        );
        products.rendering = StreamFullV1StaticRendererPlan.deployRenderer(configuration.rendering);
        products.rendering = StreamFullV1StaticRendererPlan.deployRegistry(
            configuration.rendering, products.rendering, _targets()
        );
    }

    /// @dev Partial direct fixture inventory, deliberately not a transitive analysis report.
    function _targets() private view returns (Versions.Target[] memory targets) {
        (address encoding,) = products.rendering.renderer.encodingBinding();
        targets = new Versions.Target[](6);
        targets[0] = Versions.Target(address(core), address(core).codehash, keccak256("CORE"));
        targets[1] = Versions.Target(
            address(assemblyMetadata),
            address(assemblyMetadata).codehash,
            keccak256("COLLECTION_METADATA")
        );
        targets[2] = Versions.Target(
            address(router), address(router).codehash, keccak256("METADATA_COMPANION")
        );
        targets[3] = Versions.Target(
            address(entropy), address(entropy).codehash, keccak256("ENTROPY_COORDINATOR")
        );
        targets[4] = Versions.Target(
            address(products.rendering.attribution),
            address(products.rendering.attribution).codehash,
            keccak256("METADATA_COMPANION")
        );
        targets[5] = Versions.Target(encoding, encoding.codehash, keccak256("METADATA_COMPANION"));
        for (uint256 i = 1; i < targets.length; ++i) {
            for (uint256 j = i; j > 0 && targets[j - 1].target > targets[j].target; --j) {
                (targets[j - 1], targets[j]) = (targets[j], targets[j - 1]);
            }
        }
    }
}
