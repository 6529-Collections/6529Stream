// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamCurrentSafeGovernanceFixture.sol";
import { StreamFullV1ArtifactProducts } from "./StreamFullV1ArtifactProducts.sol";
import {
    StreamGenesisManifestTailFixture as TailFixture
} from "./StreamGenesisManifestTailFixture.sol";
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
import { CurrentARRNGService } from "../current/StreamCurrentARRNG.t.sol";
import {
    GenesisDelegationServiceDouble
} from "../current/StreamCurrentFullV1GenesisProducts.t.sol";
import {
    IStreamRenderer as Render
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as Versions
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    StreamSplitWalletDeployment
} from "../../smart-contracts/domains/revenue/StreamSplitWalletDeployment.sol";

/// @notice Original construction recipe retained from the 4f479a3c candidate cohort.
/// @dev Kept in a new owned fixture while root integrates that batch. External services
/// remain doubles; fixtures/manifests and read budgets are explicitly non-release inputs.
abstract contract StreamFullV1ActivationFixture is StreamCurrentSafeGovernanceFixture {
    StreamFullV1Candidate.Foundation internal foundation;
    StreamFullV1Candidate.Configuration internal configuration;
    StreamFullV1Candidate.Products internal products;
    MockVRFCoordinatorV2Plus internal vrfService;
    bytes32 internal savedInventoryHash;

    function _constructActivationCandidate() internal {
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
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x65293701;
        keys[1] = 0x65293702;
        SafeComponents memory components = deploySafeComponents("1.4.1");
        OfficialSafe governor = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 3737);
        _installGovernorSafe(governor, keys);
        _installAdmissionTailTrigger(address(registry), registry.registerModule.selector);
        _installAdmissionTailTrigger(
            address(assemblySchemas), assemblySchemas.registerDocument.selector
        );
    }

    function _installAdmissionTailTrigger(address target, bytes4 selector) private {
        TailFixture.Plan memory p = TailFixture.plan(executor, target, selector);
        (bytes32 action, uint64 ready) =
            _scheduleBatchAsGovernor(p.batch.actionClass, p.batch.calls, p.batch.callDatas);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector, action, ready
            )
        );
        executor.executeGovernanceBatch(action, p.batch.calls, p.batch.callDatas);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(
                executor.executeGovernanceBatch, (action, p.batch.calls, p.batch.callDatas)
            )
        );
        GovernanceAction memory receipt = executor.governanceAction(action);
        require(
            receipt.status == GovernanceActionStatus.EXECUTED
                && receipt.proposer == address(governorSafe)
                && receipt.executor == address(governorSafe),
            "actual Safe installs the isolated admission tail rule"
        );
        TailFixture.assertInstalled(executor, p, address(manifest));
    }

    function _foundation() internal {
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

    function _commerce() internal {
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
        products.commerce = StreamFullV1ArtifactProducts.deployCommerce(c);
    }

    function _independent() internal {
        StreamFullV1GenesisProducts.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.metadata = address(assemblyMetadata);
        c.schemas = address(assemblySchemas);
        c.ticketSigner = vm.addr(PLATFORM_KEY);
        c.ticketSignerKind = 1;
        c.delegateRegistry = address(
            _artistArtifactCreate(
                "test/current/StreamCurrentFullV1GenesisProducts.t.sol:GenesisDelegationServiceDouble",
                abi.encode()
            )
        );
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
        products.independent = StreamFullV1ArtifactProducts.deployGenesis(c);
    }

    function _records() internal {
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
        products.records = StreamFullV1ArtifactProducts.deployRecords(c);
    }

    function _providers() internal {
        vrfService = MockVRFCoordinatorV2Plus(
            _artistArtifactCreate(
                "test/mocks/MockVRFCoordinatorV2Plus.sol:MockVRFCoordinatorV2Plus", abi.encode()
            )
        );
        CurrentARRNGService service = CurrentARRNGService(
            _artistArtifactCreate(
                "test/current/StreamCurrentARRNG.t.sol:CurrentARRNGService",
                abi.encode(address(governanceRoot), vm.addr(PLATFORM_KEY))
            )
        );
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
        (products.vrf, products.arrng) = StreamFullV1ArtifactProducts.deployProviders(foundation, c);
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

    function _continuity() internal {
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
        products.continuity = StreamFullV1ArtifactProducts.deployContinuity(c);
    }

    function _rendering() internal {
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
        products.rendering = StreamFullV1ArtifactProducts.deployRenderer(configuration.rendering);
        products.rendering = StreamFullV1ArtifactProducts.deployRendererRegistry(
            configuration.rendering, products.rendering, _targets()
        );
    }

    /// @dev Partial direct fixture inventory, deliberately not a transitive analysis report.
    function _targets() internal view returns (Versions.Target[] memory targets) {
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
