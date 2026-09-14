// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamMintArtistConsent
} from "../../smart-contracts/domains/mint/StreamMintArtistConsent.sol";
import {
    IStreamArtistContentRatification
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentRatification.sol";
import {
    StreamArtistEstateCoverage
} from "../../smart-contracts/domains/artist/StreamArtistEstateCoverage.sol";
import {
    StreamArtistTimingState
} from "../../smart-contracts/domains/artist/StreamArtistTimingState.sol";
import {
    StreamArtistExtensionFactory
} from "../../smart-contracts/domains/artist/StreamArtistExtensionFactory.sol";
import "../../script/current/StreamDeploymentSlot.sol";

import { StreamNativeAssemblyCreation } from "./StreamNativeAssemblyCreation.sol";

import "./OfficialSafeFixture.sol";
import "../../script/current/StreamGovernanceGenesisPlan.sol";
import "../../script/current/StreamRevealActivationPlan.sol";
import "../../smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../mocks/MockStreamEntropyProvider.sol";
import {
    StreamArchivalTypes as OcA
} from "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";
import {
    StreamFinalityArtifactTypes as OcF
} from "../../smart-contracts/interfaces/stream/preservation/StreamFinalityArtifactTypes.sol";
import {
    StreamArtistContentTypes as AssemblyContent
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamArtistRecordPublicationTypes as AssemblyPublication
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    IStreamArtistRecordPublicationOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";
import "../../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";
import "../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import "../../smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol";
import "../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";
import "../../smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol";
import "../../smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol";
import "../../smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol";
import {
    StreamMetadataRouter
} from "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import "../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import "../../smart-contracts/domains/preservation/StreamArchivalCoverage.sol";
import "../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import "../../smart-contracts/domains/preservation/StreamArweaveObjectCheckpointVerifier.sol";
import "../../smart-contracts/domains/preservation/StreamExternalArtifactCoverage.sol";
import "../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import "../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import "../../smart-contracts/domains/finality/StreamOnchainContentCheckpoint.sol";
import "../../smart-contracts/domains/finality/StreamContentLeafManifest.sol";
import "../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import "../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import "../../smart-contracts/domains/finality/StreamFinalityEntropySourceFactory.sol";
import "../../smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol";
import "../../smart-contracts/domains/finality/StreamFinalityCurrentDiscovery.sol";
import "../../smart-contracts/domains/finality/StreamCoreFinalityAdapter.sol";
import "../../smart-contracts/domains/finality/StreamArtworkFinalityRegistry.sol";
import "../../smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol";
import "../../smart-contracts/domains/metadata/StreamCollectionSnapshots.sol";
import "../../smart-contracts/domains/metadata/StreamWorkRecordSelection.sol";
import "../../smart-contracts/domains/metadata/StreamRightsRecordSelection.sol";
import "../../smart-contracts/domains/metadata/StreamConservationRecordSelection.sol";
import "../../smart-contracts/domains/preservation/StreamReferenceRenderPublication.sol";
import {
    StreamRenderCriticalInventory
} from "../../smart-contracts/domains/preservation/StreamRenderCriticalInventory.sol";
import {
    StreamBundleArchiveCoverage
} from "../../smart-contracts/domains/preservation/StreamBundleArchiveCoverage.sol";
import "../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationDocumentReads
} from "../../smart-contracts/domains/preservation/StreamPreservationDocumentReads.sol";
import {
    StreamPreservationInventoryChains
} from "../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamPreservationInventoryTypes as AssemblyInventory
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamExternalArtifactTypes as AxE
} from "../../smart-contracts/interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import {
    StreamArchivalTypes as AxA
} from "../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";

import {
    StreamFinalityInputManifestSchemas
} from "../../smart-contracts/domains/finality/StreamFinalityInputManifestSchemas.sol";
import {
    StreamFinalitySanctionSchemas
} from "../../smart-contracts/domains/finality/StreamFinalitySanctionSchemas.sol";
import {
    StreamArtistSanctionHashes
} from "../../smart-contracts/domains/artist/StreamArtistSanctionHashes.sol";
import {
    StreamArtistSanctionTypes as AssemblySanction
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistSanctionRequestTypes as AssemblySanctionRequest
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionRequestTypes.sol";

interface NativeAssemblyVm {
    function envOr(string calldata key, bool defaultValue) external view returns (bool);
    function skip(bool condition) external;

    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function readFile(string calldata path) external view returns (string memory);
    function parseJson(string calldata json, string calldata path)
        external
        pure
        returns (bytes memory);
    function parseJsonKeys(string calldata json, string calldata path)
        external
        pure
        returns (string[] memory);
    function parseJsonString(string calldata json, string calldata path)
        external
        pure
        returns (string memory);
    function parseJsonUint(string calldata json, string calldata path)
        external
        pure
        returns (uint256);
    function parseJsonUintArray(string calldata json, string calldata path)
        external
        pure
        returns (uint256[] memory);
    function keyExistsJson(string calldata json, string calldata path) external pure returns (bool);
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
    function warp(uint256 timestamp) external;
    function deal(address account, uint256 value) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function createDir(string calldata path, bool recursive) external;
    function writeFile(string calldata path, string calldata contents) external;
}

/// @dev One actual CREATE coordinate, independent of product initcode. Never protocol authority.
contract NativeFinalityAssemblySlot {
    address private immutable operator;
    bool private used;

    constructor() {
        operator = msg.sender;
    }

    function deploy(bytes memory initcode, address expected, bytes32 expectedRuntime)
        external
        returns (address product)
    {
        require(msg.sender == operator && !used, "assembly slot consumed or wrong operator");
        require(initcode.length != 0 && initcode.length <= 49152, "product initcode fits EIP-3860");
        used = true;
        assembly ("memory-safe") { product := create(0, add(initcode, 32), mload(initcode)) }
        require(product == expected && product.code.length != 0, "actual CREATE address");
        require(product.code.length <= 24576, "product runtime fits EIP-170");
        require(product.codehash == expectedRuntime, "actual CREATE runtime");
    }
}

/// @dev Deployment proof helpers for the real native assembly. Artifact templates come from the
/// exact current compiler output. No runtime installation, storage injection or authority mock.
abstract contract StreamNativeFinalityAssemblyFixture is OfficialSafeFixture {
    NativeAssemblyVm internal constant assemblyVm =
        NativeAssemblyVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 internal constant ASSEMBLY_DEPLOYMENT = keccak256("native finality actual assembly v1");
    bytes32 internal constant ASSEMBLY_REGISTRY =
        keccak256("native finality actual module registry v1");
    StreamGovernanceExecutor internal assemblyExecutor;
    StreamRoleRegistry internal assemblyRoles;
    StreamModuleRegistry internal assemblyModules;
    StreamCore internal assemblyCore;
    StreamSystemManifest internal assemblyManifest;
    OfficialSafe internal assemblyRoot;
    OfficialSafe internal assemblyArtist;
    uint256[] internal assemblyRootKeys;
    uint256[] internal assemblyArtistKeys;
    address[] internal assemblyGuardians;
    GovernanceActionPolicyEntry[] private assemblyPolicies;
    NativeFinalityAssemblySlot internal assemblyCoordinatorSlot;
    address internal assemblyCoordinatorAddress;
    bytes internal assemblyCoordinatorRuntime;
    StreamMintLedger internal assemblyLedger;
    StreamMintManager internal assemblyManager;
    StreamAssetPolicyRegistry internal assemblyAssetPolicy;
    StreamSplitFactory internal assemblySplits;
    StreamArtistOnboardingRegistry internal assemblyArtists;
    StreamArtistExtensionFactory internal assemblyArtistExtensions;
    bool internal assemblyRequireColdPhaseFailure;
    bool internal assemblyColdPhaseFailureObserved;
    bytes32 internal assemblyColdPhaseCalldataHash;
    StreamArtistOnboardingCoordinator internal assemblyCoordinator;
    T.SuiteConfiguration internal assemblySuite;
    StreamMetadataRouter internal assemblyRouter;
    StreamRevenueResolver internal assemblyPrimary;
    StreamRoyaltyResolver internal assemblyRoyalties;
    StreamArweaveCheckpointVerifier internal assemblyCheckpointVerifier;
    StreamArchivalCoverage internal assemblyArchive;
    StreamSchemaRegistry internal assemblySchemas;
    StreamSchemaDocumentStore internal assemblyStore;
    StreamCollectionMetadataV1 internal assemblyMetadata;
    enum Late {
        PROVIDER,
        CORE_ADAPTER,
        DISCOVERY,
        REGISTRY,
        WORK,
        RIGHTS,
        CONSERVATION,
        INVENTORY,
        BUNDLE
    }
    NativeFinalityAssemblySlot[9] internal assemblySlots;
    address[9] internal assemblyLate;
    bytes[9] internal assemblyRuntimes;
    StreamCollectionTokenInventory internal assemblyTokens;
    StreamFinalityScopeMembership internal assemblyMembership;
    StreamFinalityCoordinatorInventory internal assemblyCoordinators;
    StreamFinalityEntropySourceFactory internal assemblyEntropyFactory;
    StreamOnchainContentCheckpoint internal assemblyContentCheckpoint;
    StreamContentLeafManifest internal assemblyLeaves;
    StreamFinalityArtifactCoverage internal assemblyArtifact;
    StreamArweaveObjectCheckpointVerifier internal assemblyObjectVerifier;
    StreamExternalArtifactCoverage internal assemblyExternal;
    StreamCollectionSnapshots internal assemblySnapshots;
    StreamReferenceRenderPublication internal assemblyReference;
    StreamFinalityNativeEvidenceProvider internal assemblyProvider;
    StreamCoreFinalityAdapter internal assemblyCoreAdapter;
    StreamFinalityCurrentDiscovery internal assemblyDiscovery;
    StreamArtworkFinalityRegistry internal assemblyFinality;
    StreamWorkRecordSelection internal assemblyWork;
    StreamRightsRecordSelection internal assemblyRights;
    StreamConservationRecordSelection internal assemblyConservation;
    StreamRenderCriticalInventory internal assemblyInventory;
    StreamBundleArchiveCoverage internal assemblyBundle;
    address[6] internal assemblyRouterAdapters;
    address internal assemblyMetadataAdapter;
    StreamRevenueEscrow internal assemblyEscrow;
    StreamFixedPriceSaleAdapter internal assemblySale;
    StreamEntropyCoordinator internal assemblyEntropy;
    // The sole controllable service supplies external randomness to the real coordinator.
    MockStreamEntropyProvider internal assemblyOracle;
    bytes32 internal assemblySplitProfile;
    address internal assemblySplitWallet;
    bytes32 internal assemblyArtistId;
    uint256 internal assemblyArtistNonce = 1;
    uint256 internal constant ASSEMBLY_PLATFORM_KEY = 0x65295401;
    bytes32 internal constant ASSEMBLY_PHASE = keccak256("native assembly original sale");
    address internal constant ASSEMBLY_BUYER = address(0x65295402);
    string internal constant ASSEMBLY_SCRIPT =
        "document.body.style.margin='0';const c=document.createElement('canvas');c.width=64;c.height=64;document.body.appendChild(c);const x=c.getContext('2d');x.fillStyle='#123456';x.fillRect(0,0,64,64);x.fillStyle=tokenId===1?'#ff0000':'#00ff00';x.fillRect(8,8,16,16);";
    bytes32 internal assemblyOriginalContentRoot;
    bytes32 internal assemblyWorkRecord;
    bytes32 internal assemblyRightsRecord;
    bytes32 internal assemblyWaiverRecord;
    bytes32 internal assemblyWaiverAuthorization;
    StreamWorkRecordTypes.Description internal assemblyWorkDescription;
    StreamRightsRecordTypes.Statement internal assemblyRightsStatement;
    StreamConservationRecordTypes.IntentWaiver internal assemblyIntentWaiver;
    bytes32 internal assemblyCoordinatorInventoryPlan;
    bytes32 internal assemblySnapshotRecord;
    address internal assemblyEntropySourceSet;

    function _activateAssemblyArtwork() internal {
        _deployAssemblyMintProducts();
        _installAssemblyProductPointers();
        _configureAssemblyProducts();
        StreamArtistActivationPlan.Plan memory plan = StreamRevealActivationPlan.buildWithArtist(
            assemblyRoles,
            IStreamGasParameterHost(address(assemblyManager)),
            address(this),
            StreamRevealActivationPlan.Principals(
                address(this), address(assemblyRoot), address(assemblyRoot)
            )
        );
        GenesisBatch memory activation = GenesisBatch(1, plan.calls, plan.callDatas);
        _admitAssemblyBatch(activation);
        _assemblyGovernance(
            activation, "https://fixtures.example.invalid/native-assembly/artist-reveal-activation"
        );
        require(
            assemblyRoles.hasRole(keccak256("ROLE_ARTIST_REGISTRY_ADMIN"), address(this)),
            "actual artist administrator"
        );
        assemblyEntropy.configureCollectionRevealPolicy(
            1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, 0
        );
        _onboardAssemblyArtist();
        _configureAssemblyMintPhase();
        assemblyManager.transferOwnership(address(assemblyExecutor));
        assemblyVm.deal(address(this), 1 ether);
        _mintAssemblyToken(1);
        _mintAssemblyToken(2);
        require(
            assemblyCore.collectionMintedEver(1) == 2 && assemblyCore.totalSupply() == 2,
            "actual complete minted collection"
        );
    }

    function _deployAssemblyMintProducts() private {
        assemblyEscrow = StreamRevenueEscrow(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamRevenueEscrow,
                    abi.encode(
                        assemblySplits,
                        address(assemblyExecutor),
                        _gas("FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3)
                    )
                ))
        );
        assemblySale = StreamFixedPriceSaleAdapter(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamFixedPriceSaleAdapter,
                    abi.encode(
                        assemblyManager,
                        assemblyPrimary,
                        safeVm.addr(ASSEMBLY_PLATFORM_KEY),
                        IStreamArtistAttribution(address(assemblyArtists)),
                        assemblyEscrow
                    )
                ))
        );
        assemblyEntropy = StreamEntropyCoordinator(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamEntropyCoordinator,
                    abi.encode(
                        StreamEntropyCoordinator.DeploymentConfig(
                            address(assemblyCore),
                            address(assemblyExecutor),
                            address(assemblyRoles),
                            StreamCurrentStackPlan.entropyTimeParameters(),
                            ASSEMBLY_DEPLOYMENT,
                            "https://fixtures.example.invalid/native-assembly/entropy",
                            keccak256("native assembly entropy module")
                        )
                    )
                ))
        );
        assemblyOracle = new MockStreamEntropyProvider(address(assemblyEntropy));
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] =
            IStreamSplitWallet.SplitEntry(address(assemblyArtist), 900_000, keccak256("artist"));
        entries[1] =
            IStreamSplitWallet.SplitEntry(address(0x65295403), 100_000, keccak256("protocol"));
        (assemblySplitProfile, assemblySplitWallet) =
            assemblySplits.createProfile(entries, keccak256("native assembly split"));
        assemblyLedger.transferOwnership(address(assemblyExecutor));
        assemblySale.transferOwnership(address(assemblyExecutor));
        require(
            address(assemblySale).code.length <= 24576
                && address(assemblyEntropy).code.length <= 24576
                && address(assemblyEscrow).code.length <= 24576,
            "actual mint products fit"
        );
    }

    function _installAssemblyProductPointers() private {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](6);
        records[0] = _assemblyProductModule(
            address(assemblyManager),
            keccak256("MINT_MANAGER"),
            type(IStreamMintManager).interfaceId,
            keccak256("native assembly mint manager")
        );
        records[1] = _assemblyProductModule(
            address(assemblyLedger),
            keccak256("MINT_LEDGER"),
            type(IStreamMintLedger).interfaceId,
            keccak256("native assembly mint ledger")
        );
        records[2] = _assemblyModule(
            address(assemblyEntropy),
            keccak256("ENTROPY_COORDINATOR"),
            type(IStreamEntropyCoordinator).interfaceId,
            keccak256("native assembly entropy module")
        );
        records[3] = _assemblyProductModule(
            address(assemblyRoyalties),
            keccak256("REVENUE_RESOLVER"),
            type(IStreamRoyaltyResolver).interfaceId,
            keccak256("native assembly royalty module")
        );
        records[4] = _assemblyProductModule(
            address(assemblyExecutor),
            keccak256("GOVERNANCE_LAYER"),
            type(IStreamStateExportPublisher).interfaceId,
            keccak256("native assembly state export")
        );
        records[5] = _assemblyModule(
            address(assemblyFinality),
            keccak256("ARTWORK_FINALITY_REGISTRY"),
            type(IStreamArtworkFinalityRegistry).interfaceId,
            keccak256("native assembly finality")
        );
        GenesisBatch memory batch;
        batch.actionClass = 1;
        (batch.calls, batch.callDatas) =
            StreamCurrentStackPlan.registrationCalls(assemblyModules, records);
        _admitAssemblyBatch(batch);
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/register-products"
        );
        bytes32[] memory pointerTypes = new bytes32[](records.length);
        for (uint256 i; i < records.length; ++i) {
            pointerTypes[i] = records[i].moduleType;
        }
        pointerTypes[3] = keccak256("ROYALTY_RESOLVER");
        pointerTypes[4] = keccak256("STATE_EXPORT_PUBLISHER");
        batch.actionClass = 3;
        (batch.calls, batch.callDatas) = StreamCurrentStackPlan.pointerCalls(
            assemblyCore, assemblyModules, pointerTypes, records
        );
        // Admit new target policies before capturing the publication's current manifest revision.
        _admitAssemblyBatch(batch);
        GovernanceCall[] memory calls = new GovernanceCall[](records.length + 1);
        bytes[] memory datas = new bytes[](records.length + 1);
        for (uint256 i; i < records.length; ++i) {
            calls[i] = batch.calls[i];
            datas[i] = batch.callDatas[i];
        }
        StreamSystemManifest.ModuleAddresses memory modules =
        StreamGenesisManifestPlan.readAggregate(assemblyManifest).modules;
        modules.revenueResolver = address(assemblyRoyalties);
        modules.entropyCoordinator = address(assemblyEntropy);
        modules.mintManager = address(assemblyManager);
        modules.mintLedger = address(assemblyLedger);
        modules.streamAdminsOrGovernance = address(assemblyExecutor);
        modules.stateExportPublisher = address(assemblyExecutor);
        modules.artworkFinalityRegistry = address(assemblyFinality);
        (calls[records.length], datas[records.length]) =
            _assemblyPublication(modules, keccak256("native assembly product pointers"));
        batch.calls = calls;
        batch.callDatas = datas;
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/select-products"
        );
    }

    function _installAssemblyArtistPointer() private {
        // WORK authenticates this selected original facade during its constructor.
        // The actual Coordinator must exist before the original facade can be selected.
        uint64[9] memory slotNonces;
        for (uint256 i; i < 9; ++i) {
            slotNonces[i] = assemblyVm.getNonce(address(assemblySlots[i]));
        }
        uint64 coordinatorSlotNonce = assemblyVm.getNonce(address(assemblyCoordinatorSlot));
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = _assemblyModule(
            address(assemblyArtists),
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            keccak256("native assembly artist")
        );
        GenesisBatch memory batch;
        batch.actionClass = 1;
        (batch.calls, batch.callDatas) =
            StreamCurrentStackPlan.registrationCalls(assemblyModules, records);
        _admitAssemblyBatch(batch);
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/register-original-artist"
        );
        bytes32[] memory pointerTypes = new bytes32[](1);
        pointerTypes[0] = keccak256("ARTIST_REGISTRY");
        batch.actionClass = 3;
        (batch.calls, batch.callDatas) = StreamCurrentStackPlan.pointerCalls(
            assemblyCore, assemblyModules, pointerTypes, records
        );
        _admitAssemblyBatch(batch);
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory datas = new bytes[](2);
        calls[0] = batch.calls[0];
        datas[0] = batch.callDatas[0];
        StreamSystemManifest.ModuleAddresses memory modules =
        StreamGenesisManifestPlan.readAggregate(assemblyManifest).modules;
        modules.artistRegistry = address(assemblyArtists);
        (calls[1], datas[1]) =
            _assemblyPublication(modules, keccak256("native assembly original artist pointer"));
        batch.calls = calls;
        batch.callDatas = datas;
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/select-original-artist"
        );
        (
            address selected,
            bytes32 selectedCode,
            bool frozen,
            bytes32 selectedType,
            bytes4 selectedInterface,
            address selectedRegistry,
            uint8 selectedStatus,
            bytes32 selectedManifest,
            bytes32 selectedDeployment,
            uint64 selectedRevision
        ) = assemblyCore.getSatellitePointer(keccak256("ARTIST_REGISTRY"));
        require(
            selected == address(assemblyArtists)
                && selectedCode == address(assemblyArtists).codehash && !frozen
                && selectedType == records[0].moduleType
                && selectedInterface == records[0].interfaceId
                && selectedRegistry == address(assemblyModules) && selectedStatus == 1
                && selectedManifest == records[0].moduleManifestHash
                && selectedDeployment == ASSEMBLY_DEPLOYMENT && selectedRevision == 1,
            "exact original Artist pointer before WORK construction"
        );
        for (uint256 i; i < 9; ++i) {
            require(
                assemblyVm.getNonce(address(assemblySlots[i])) == slotNonces[i],
                "artist selection preserves every planned CREATE slot"
            );
        }
        require(
            assemblyVm.getNonce(address(assemblyCoordinatorSlot)) == coordinatorSlotNonce,
            "artist selection preserves original Coordinator slot"
        );
    }

    function _assemblyProductModule(
        address module,
        bytes32 moduleType,
        bytes4 interfaceId,
        bytes32 moduleHash
    ) private view returns (StreamModuleRegistration memory) {
        // These products expose their native ERC165 API, without the optional IStreamModule API.
        // The actual Registry authenticates the explicit version plus original runtime/interface.
        return StreamModuleRegistration(
            module,
            moduleType,
            keccak256("native assembly original product v1"),
            interfaceId,
            500000,
            module.codehash,
            ASSEMBLY_DEPLOYMENT,
            moduleHash,
            "https://fixtures.example.invalid/native-assembly/product"
        );
    }

    function _configureAssemblyProducts() private {
        GenesisBatch memory batch;
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](6);
        batch.callDatas = new bytes[](6);
        address[5] memory targets = [
            address(assemblyEntropy),
            address(assemblyRouter),
            address(assemblyRouter),
            address(assemblyRoyalties),
            address(assemblyPrimary)
        ];
        batch.callDatas[0] = abi.encodeCall(
            assemblyEntropy.configureCollection,
            (
                1,
                address(assemblyOracle),
                keccak256("native assembly collection salt"),
                true,
                uint64(100)
            )
        );
        batch.callDatas[1] = abi.encodeCall(
            assemblyRouter.setCollectionMetadata,
            (1, "Native Assembly", "Original current-stack artwork", "", "")
        );
        batch.callDatas[2] =
            abi.encodeCall(assemblyRouter.setCollectionScript, (1, ASSEMBLY_SCRIPT));
        batch.callDatas[3] = abi.encodeCall(
            assemblyRoyalties.configureCollectionRoyalty, (1, assemblySplitProfile, uint16(690))
        );
        batch.callDatas[4] = abi.encodeCall(
            assemblyPrimary.setPrimaryProfileAssignment,
            (keccak256("PRIMARY_SALE"), uint8(1), 1, assemblySplitProfile, bytes32(0))
        );
        for (uint256 i; i < targets.length; ++i) {
            batch.calls[i] = StreamCurrentStackPlan.call(
                targets[i],
                batch.callDatas[i],
                keccak256(abi.encode(targets[i], batch.callDatas[i])),
                bytes32(0),
                keccak256(batch.callDatas[i])
            );
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            assemblyEscrow.creditProducerTransitionHashes(address(assemblySale), true);
        batch.callDatas[5] =
            abi.encodeCall(assemblyEscrow.setCreditProducer, (address(assemblySale), true));
        batch.calls[5] = StreamCurrentStackPlan.call(
            address(assemblyEscrow), batch.callDatas[5], scope, oldHash, newHash
        );
        _admitAssemblyBatch(batch);
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/configure-products"
        );
    }

    function _assemblyAuthorization(bool signedAt) internal returns (T.Authorization memory) {
        return T.Authorization(
            assemblyArtistNonce++, uint64(signedAt ? block.timestamp : block.timestamp + 1 days), ""
        );
    }

    function _assemblyArtistProof(bytes32 digest) internal returns (bytes memory) {
        return safeThresholdSignature(
            assemblyArtistKeys, safeMessageDigest(assemblyArtist, abi.encode(digest))
        );
    }

    function _onboardAssemblyArtist() private {
        bytes memory document = bytes("Native assembly original artist identity");
        T.BindingProposal memory proposal;
        proposal.artistAddress = address(assemblyArtist);
        proposal.identityRecordHash = keccak256(document);
        proposal.identityRecordURI =
        "https://fixtures.example.invalid/native-assembly/artist-identity";
        proposal.consentMode = 1;
        proposal.collaborators = new T.CollaboratorRecord[](0);
        proposal.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](0);
        (assemblyArtistId,) =
            assemblyArtists.proposeArtistBinding(1, proposal, document, "Native Assembly Artist");
        T.Authorization memory authorization = _assemblyAuthorization(false);
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.acceptanceDigest(1, authorization));
        assemblyArtists.acceptArtistBinding(1, authorization);
        T.PayoutDesignation memory payout =
            T.PayoutDesignation(assemblyArtistId, address(assemblyArtist), bytes32(0));
        authorization = _assemblyAuthorization(true);
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.payoutDesignationDigest(payout, authorization));
        assemblyArtists.recordPayoutDesignation(payout, authorization);
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            assemblyCoordinator.reads().currentAssignments(1);
        _assemblyEconomicsConsent(primary);
        _assemblyEconomicsConsent(royalty);
        (, bytes32 contentState) = assemblyRouter.currentArtistContentState(1);
        T.Ratification memory ratification =
            T.Ratification(1, address(assemblyRouter), contentState);
        authorization = _assemblyAuthorization(false);
        authorization.signature = _assemblyArtistProof(
            assemblyArtists.contentRatificationDigest(ratification, authorization)
        );
        assemblyArtists.recordContentRatification(ratification, authorization);
        T.Binding memory binding_ = IStreamArtistBindingOwner(assemblySuite.owners[0]).binding(1);
        bytes32 facts = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid,
                address(assemblyArtists),
                address(assemblyCore),
                address(assemblyManager)
            ),
            1,
            binding_
        );
        _assemblyAttestation(
            9,
            bytes32(uint256(uint160(address(assemblyCore)))),
            facts,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
        _assemblyAttestation(
            10,
            assemblyArtistId,
            binding_.identityRecordHash,
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
        require(
            assemblyArtists.acceptedArtist(1) == address(assemblyArtist),
            "actual Safe artist acceptance"
        );
    }

    function _assemblyEconomicsConsent(T.AssignmentFact memory fact) private {
        T.EconomicsConsent memory consent = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory authorization = _assemblyAuthorization(false);
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.economicsConsentDigest(consent, authorization));
        assemblyArtists.recordEconomicsConsent(consent, authorization);
    }

    function _assemblyAttestation(uint8 kind, bytes32 subject, bytes32 state, bytes32 schema)
        internal
        returns (bytes32)
    {
        bytes memory statement = abi.encode(kind, subject, state, schema);
        T.Attestation memory attestation = T.Attestation(
            1,
            kind,
            subject,
            state,
            schema,
            keccak256(statement),
            "https://fixtures.example.invalid/native-assembly/statement"
        );
        T.Authorization memory authorization = _assemblyAuthorization(true);
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.attestationDigest(attestation, authorization));
        return assemblyArtists.recordArtistAttestation(attestation, authorization, statement);
    }

    function _assemblyPolicyConsent(bytes32 policyHash) private {
        T.PolicyConsent memory consent = T.PolicyConsent(1, ASSEMBLY_PHASE, policyHash);
        T.Authorization memory authorization = _assemblyAuthorization(false);
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.policyConsentDigest(consent, authorization));
        assemblyArtists.recordPolicyConsent(consent, authorization);
    }

    function _configureAssemblyMintPhase() private {
        bytes32[] memory counters = new bytes32[](1);
        counters[0] = keccak256("supply");
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](1);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            2,
            1,
            keccak256("counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false,
            0,
            0,
            1,
            keccak256("native assembly phase"),
            keccak256("native assembly metadata")
        );
        address[] memory executors = new address[](0);
        _assemblyPolicyConsent(
            assemblyManager.previewPhasePolicyHash(
                1, ASSEMBLY_PHASE, config, gate, counters, configs, executors
            )
        );
        bytes memory originalCall = abi.encodeCall(
            assemblyManager.configurePhase, (1, ASSEMBLY_PHASE, config, gate, counters, configs)
        );
        bytes32 originalPolicy = assemblyManager.previewPhasePolicyHash(
            1, ASSEMBLY_PHASE, config, gate, counters, configs, executors
        );
        if (assemblyRequireColdPhaseFailure) {
            (bool existed, IStreamMintManager.MintPhaseConfig memory beforeConfig) =
                assemblyManager.phase(1, ASSEMBLY_PHASE);
            require(
                !existed && assemblyManager.phasePolicyHash(1, ASSEMBLY_PHASE) == 0,
                "unregistered original phase"
            );
            (bool premature, bytes memory failure) = address(assemblyManager).call(originalCall);
            require(
                !premature
                    && keccak256(failure)
                        == keccak256(
                            abi.encodeWithSelector(
                                StreamMintArtistConsent.ArtistAuthorityReadFailed.selector,
                                address(assemblyArtists),
                                IStreamArtistMintConsent.requireMintConsent.selector
                            )
                        ),
                "exact original cold 300k failure"
            );
            (bool existsAfter, IStreamMintManager.MintPhaseConfig memory afterConfig) =
                assemblyManager.phase(1, ASSEMBLY_PHASE);
            require(
                !existsAfter
                    && keccak256(abi.encode(beforeConfig)) == keccak256(abi.encode(afterConfig))
                    && assemblyManager.phasePolicyHash(1, ASSEMBLY_PHASE) == 0
                    && assemblyManager.phaseCounterIds(1, ASSEMBLY_PHASE).length == 0,
                "failed cold registration rolls back phase and counters"
            );
            assemblyColdPhaseFailureObserved = true;
            assemblyColdPhaseCalldataHash = keccak256(originalCall);
        }
        StreamArtistActivationPlan.Plan memory expansion =
            StreamArtistActivationPlan.buildReadBudgetExpansion(
                IStreamGasParameterHost(address(assemblyManager))
            );
        GenesisBatch memory expansionBatch = GenesisBatch(1, expansion.calls, expansion.callDatas);
        _admitAssemblyBatch(expansionBatch);
        _assemblyGovernance(
            expansionBatch, "https://fixtures.example.invalid/native-assembly/artist-read-expansion"
        );
        (uint256 expanded,,, uint64 revision) =
            assemblyManager.gasParameterInfo(assemblyManager.GGP_ARTIST_AUTHORITY_GAS_LIMIT());
        require(expanded == 600_000 && revision == 3, "exact original second governed doubling");
        (bool registered, bytes memory registrationResult) =
            address(assemblyManager).call(originalCall);
        if (!registered) {
            assembly ("memory-safe") { revert(
                add(registrationResult, 32),
                mload(registrationResult)
            ) }
        }
        require(
            registrationResult.length == 32
                && abi.decode(registrationResult, (bytes32)) == originalPolicy,
            "identical original phase calldata registration"
        );
        if (assemblyRequireColdPhaseFailure) {
            require(
                keccak256(originalCall) == assemblyColdPhaseCalldataHash,
                "identical failure/retry bytes"
            );
        }
        executors = new address[](1);
        executors[0] = address(assemblySale);
        _assemblyPolicyConsent(
            assemblyManager.previewPhasePolicyHash(
                1, ASSEMBLY_PHASE, config, gate, counters, configs, executors
            )
        );
        assemblyManager.setPhaseExecutor(1, ASSEMBLY_PHASE, address(assemblySale), true);
    }

    function _mintAssemblyToken(uint256 serial) private {
        bytes memory tokenData = abi.encode("native assembly artwork", serial);
        (bytes32 policyHash,,) = assemblySale.primaryPolicy(1);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory authorization =
            IStreamFixedPriceSaleAdapter.SaleAuthorization(
                1,
                ASSEMBLY_PHASE,
                address(this),
                ASSEMBLY_BUYER,
                address(assemblyArtist),
                assemblySplitProfile,
                policyHash,
                keccak256(tokenData),
                keccak256(abi.encode("native assembly commitment", serial)),
                assemblyManager.phasePolicyHash(1, ASSEMBLY_PHASE),
                0.01 ether,
                keccak256(abi.encode("native assembly sale", serial)),
                uint64(block.timestamp + 1 days),
                assemblySale.signerEpoch()
            );
        bytes32 digest = assemblySale.authorizationDigest(authorization);
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(ASSEMBLY_PLATFORM_KEY, digest);
        (uint256 tokenId, bytes32 operationRoot) = assemblySale.buy{ value: authorization.price }(
            authorization, tokenData, abi.encodePacked(r, s, v), _assemblyArtistProof(digest)
        );
        require(
            assemblyCore.ownerOf(tokenId) == ASSEMBLY_BUYER
                && assemblyCore.coordinatorAtMint(tokenId) == address(assemblyEntropy)
                && assemblyManager.isOperationRootUsed(operationRoot),
            "actual paid mint and original coordinator"
        );
        (, uint256 requestId) = assemblyEntropy.requestEntropy(tokenId);
        assemblyOracle.fulfill(
            requestId, keccak256(abi.encode("external fixture randomness", tokenId))
        );
        (bytes32 seed, bool finalized) = assemblyEntropy.tokenSeed(tokenId);
        require(
            finalized && seed != bytes32(0)
                && assemblyEntropy.tokenEntropyStatus(tokenId) == StreamEntropyStatus.FINALIZED,
            "actual coordinator retained final seed"
        );
        require(
            keccak256(bytes(assemblyCore.tokenURI(tokenId)))
                == keccak256(bytes(assemblyRouter.tokenURI(address(assemblyCore), tokenId))),
            "actual Core serves original Router"
        );
    }

    // Original full-byte archive recipe copied from the reviewed B helper. Authority here
    // is this fixture's actual canonical Executor/RoleRegistry; observations are local fixtures.
    uint256 private constant OC_OBSERVER_A = 0xE5701;
    uint256 private constant OC_OBSERVER_B = 0xE5702;
    uint256 private constant OC_FIRST_WRITER = 0x652983;
    uint256 private constant OC_SECOND_WRITER = 0x652984;
    uint256 private constant OC_FIXITY_OPERATOR = 0x652985;
    uint256 private constant OC_CHUNK_BYTES = 8192;
    bytes32 private ocFirstFamily;
    bytes32 private ocSecondFamily;
    uint256 private ocSerial;

    struct OcCoveredArtifact {
        bytes32 artifactHash;
        bytes32 completionHash;
    }
    mapping(bytes32 => bytes32) private ocChunkCoverage;
    mapping(bytes32 => OcCoveredArtifact) private ocCoveredArtifacts;

    function _assemblySetupArchiveAdmissions() internal {
        _ocGrantFixity(safeVm.addr(OC_FIXITY_OPERATOR));
        ocFirstFamily = _ocAdmit("native-assembly-arweave", true, safeVm.addr(OC_FIRST_WRITER));
        ocSecondFamily = _ocAdmit("native-assembly-ipfs", false, safeVm.addr(OC_SECOND_WRITER));
        _assemblySetupExternalFamilies();
    }

    function _assemblyGovernanceCall(
        uint8 actionClass,
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) internal returns (bytes32 actionId) {
        GenesisBatch memory batch;
        batch.actionClass = actionClass;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.calls[0] = StreamCurrentStackPlan.call(target, data, scope, oldHash, newHash);
        batch.callDatas[0] = data;
        _admitAssemblyBatch(batch);
        return _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/governed-transition"
        );
    }

    function _ocCover(bytes memory raw, bytes32 schema_, bytes32 canon_)
        internal
        returns (bytes32 artifactHash, bytes32 completionHash)
    {
        require(address(assemblyArtifact) != address(0), "oc artifact missing");
        require(raw.length != 0 && raw.length <= 64 * OC_CHUNK_BYTES, "oc artifact length");
        require(schema_ != 0 && canon_ != 0, "oc artifact schema");
        require(assemblyArtists.core() == address(assemblyCore), "oc facade core");
        require(assemblyArtists.archivalCoverage() == address(assemblyArchive), "oc facade archive");
        bytes32 artistId = assemblyArtistId;
        require(artistId != 0, "oc artist missing");
        bytes32 cacheKey =
            keccak256(abi.encode(artistId, schema_, canon_, keccak256(raw), raw.length));
        OcCoveredArtifact memory cached = ocCoveredArtifacts[cacheKey];
        if (cached.artifactHash != 0) {
            assemblyArtifact.requireArtifactCoverage(
                cached.completionHash, artistId, cached.artifactHash
            );
            return (cached.artifactHash, cached.completionHash);
        }
        uint256 count = (raw.length + OC_CHUNK_BYTES - 1) / OC_CHUNK_BYTES;
        OcF.Artifact memory a;
        a.artistId = artistId;
        a.schemaId = schema_;
        a.canonicalizationId = canon_;
        a.hashAlgorithm = 1;
        a.contentHash = keccak256(raw);
        a.byteLength = uint64(raw.length);
        a.chunkHashes = new bytes32[](count);
        a.chunkLengths = new uint32[](count);
        bytes32[] memory originalCoverage = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            uint256 offset = i * OC_CHUNK_BYTES;
            uint256 length = raw.length - offset;
            if (length > OC_CHUNK_BYTES) length = OC_CHUNK_BYTES;
            bytes memory part = _ocSlice(raw, offset, length);
            a.chunkHashes[i] = keccak256(part);
            a.chunkLengths[i] = uint32(length);
            originalCoverage[i] = _ocCoverChunk(artistId, part);
        }
        artifactHash = assemblyArtifact.recordArtifact(a);
        bytes32 plan = assemblyArtifact.beginCoverage(artifactHash, ocFirstFamily, ocSecondFamily);
        for (uint32 i; i < count; ++i) {
            completionHash = assemblyArtifact.coverNextChunk(plan, i, originalCoverage[i]);
        }
        require(completionHash != 0, "oc completion missing");
        assemblyArtifact.requireArtifactCoverage(completionHash, artistId, artifactHash);
        ocCoveredArtifacts[cacheKey] = OcCoveredArtifact(artifactHash, completionHash);
    }

    function _ocCoverChunk(bytes32 artistId, bytes memory raw) private returns (bytes32 covered) {
        bytes32 key = keccak256(abi.encode(artistId, keccak256(raw)));
        covered = ocChunkCoverage[key];
        if (covered != 0) {
            assemblyArchive.requireCoverage(covered, artistId, keccak256(raw));
            return covered;
        }
        (bytes32 chunkHash, address pointer) = assemblyStore.publishChunk(raw);
        require(
            chunkHash == keccak256(raw) && pointer.code.length == raw.length + 1,
            "oc exact STOP chunk"
        );
        OcA.Envelope memory e = OcA.Envelope(
            artistId,
            chunkHash,
            keccak256("6529STREAM_FINALITY_ARTIFACT_CHUNK_V1"),
            keccak256("BINARY_EXACT_V1"),
            2,
            sha256(raw),
            uint64(raw.length),
            1,
            0
        );
        bytes32 envelopeHash = assemblyArchive.recordChunkEnvelope(e, pointer);
        uint256 serial = ++ocSerial;
        (bytes32 checkpointHash, bytes32 transactionId) = _ocCheckpoint(raw, serial);
        bytes32 first = _ocReceipt(e, envelopeHash, true, checkpointHash, transactionId, serial);
        bytes32 second = _ocReceipt(e, envelopeHash, false, checkpointHash, transactionId, serial);
        _ocFixity(e, first, serial);
        _ocFixity(e, second, serial);
        covered = assemblyArchive.recordCoverage(first, second);
        assemblyArchive.requireCoverage(covered, artistId, chunkHash);
        ocChunkCoverage[key] = covered;
    }

    function _ocCheckpoint(bytes memory raw, uint256 serial)
        private
        returns (bytes32 hash, bytes32 transactionId)
    {
        OcA.Checkpoint memory c;
        c.networkId = assemblyCheckpointVerifier.networkId();
        c.blockHash = abi.encodePacked(
            keccak256(abi.encode("oc synthetic block", serial)), bytes16(uint128(serial))
        );
        c.blockHeight = 1500000 + uint64(serial);
        c.dataRoot = _ocNativeLeaf(sha256(raw), raw.length);
        c.transactionRoot = _ocNativeLeaf(c.dataRoot, raw.length);
        c.blockDataSize = raw.length;
        c.transactionId = keccak256(
            abi.encode(
                "oc synthetic transaction",
                address(assemblyCheckpointVerifier),
                serial,
                keccak256(raw)
            )
        );
        c.dataSize = uint64(raw.length);
        c.transactionEnd = raw.length;
        c.observedAt = uint64(block.timestamp);
        c.configurationHash = assemblyCheckpointVerifier.configurationHash();
        bytes32 digest = assemblyCheckpointVerifier.checkpointDigest(c);
        OcA.ObserverProof[] memory proofs = new OcA.ObserverProof[](2);
        proofs[0] = OcA.ObserverProof(safeVm.addr(OC_OBSERVER_A), _ocSign(OC_OBSERVER_A, digest));
        proofs[1] = OcA.ObserverProof(safeVm.addr(OC_OBSERVER_B), _ocSign(OC_OBSERVER_B, digest));
        if (proofs[0].account > proofs[1].account) (proofs[0], proofs[1]) = (proofs[1], proofs[0]);
        hash = assemblyCheckpointVerifier.recordCheckpoint(
            c,
            abi.encodePacked(c.dataRoot, uint256(raw.length)),
            abi.encodePacked(sha256(raw), uint256(raw.length)),
            raw,
            proofs
        );
        return (hash, c.transactionId);
    }

    function _ocReceipt(
        OcA.Envelope memory e,
        bytes32 envelopeHash,
        bool endowed,
        bytes32 checkpointHash,
        bytes32 transactionId,
        uint256 serial
    ) private returns (bytes32 hash) {
        uint256 writerKey = endowed ? OC_FIRST_WRITER : OC_SECOND_WRITER;
        bytes memory locator = endowed
            ? abi.encodePacked(transactionId)
            : abi.encodePacked(bytes4(0x01551220), e.payloadDigest);
        OcA.ReceiptTerms memory r = OcA.ReceiptTerms(
            envelopeHash,
            endowed ? ocFirstFamily : ocSecondFamily,
            keccak256(locator),
            keccak256(bytes(endowed ? "CONTENT_ADDRESSED_INCLUSION" : "ATTESTED_POSSESSION")),
            endowed
                ? assemblyCheckpointVerifier.profileHash()
                : assemblyArchive.POSSESSION_PROFILE(),
            endowed ? checkpointHash : bytes32(0),
            safeVm.addr(writerKey),
            uint64(block.timestamp),
            serial,
            uint64(block.timestamp + 1 days)
        );
        if (!endowed) {
            r.proofRecordHash = assemblyArchive.possessionHash(
                OcA.Possession(
                    r.envelopeHash,
                    r.familyRecordHash,
                    r.storageIdentifierHash,
                    r.writer,
                    r.observedAt
                )
            );
        }
        hash = assemblyArchive.recordReceipt(
            r, locator, _ocSign(writerKey, assemblyArchive.receiptDigest(r))
        );
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARCHIVAL_RECEIPT_RECORD_V1"),
                        block.chainid,
                        address(assemblyArchive),
                        r
                    )
                ),
            "oc receipt hash"
        );
        (OcA.ReceiptTerms memory saved, bytes memory savedLocator, bytes memory signature) =
            assemblyArchive.receipt(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(r))
                && keccak256(savedLocator) == keccak256(locator) && signature.length == 65,
            "oc original receipt"
        );
    }

    function _ocFixity(OcA.Envelope memory e, bytes32 receiptHash, uint256 serial) private {
        (OcA.ReceiptTerms memory r,,) = assemblyArchive.receipt(receiptHash);
        OcA.FixityTerms memory f = OcA.FixityTerms(
            receiptHash,
            r.envelopeHash,
            r.familyRecordHash,
            e.payloadDigest,
            e.payloadDigest,
            e.byteSize,
            uint64(block.timestamp),
            1,
            keccak256(
                abi.encode(
                    "oc independent full-byte fixity", receiptHash, e.payloadDigest, e.byteSize
                )
            ),
            bytes32(0),
            bytes32(0),
            safeVm.addr(OC_FIXITY_OPERATOR),
            serial,
            uint64(block.timestamp + 1 days)
        );
        bytes32 hash = assemblyArchive.recordFixity(
            f, _ocSign(OC_FIXITY_OPERATOR, assemblyArchive.fixityDigest(f))
        );
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARCHIVAL_FIXITY_RECORD_V1"),
                        block.chainid,
                        address(assemblyArchive),
                        f
                    )
                ),
            "oc fixity hash"
        );
        require(assemblyArchive.latestFixity(receiptHash) == hash, "oc original fixity");
    }

    function _ocAdmit(string memory name, bool endowed, address writer)
        private
        returns (bytes32 hash)
    {
        bytes memory salt = bytes(endowed ? "oc-one" : "oc-two");
        OcA.Family memory f = OcA.Family(
            keccak256(bytes(name)),
            endowed ? assemblyCheckpointVerifier.networkId() : keccak256("IPFS"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256("same jurisdiction allowed"),
            endowed ? 1 : 2,
            writer,
            endowed
                ? assemblyCheckpointVerifier.profileHash()
                : assemblyArchive.POSSESSION_PROFILE()
        );
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = assemblyArchive.familyRegistrationContext(name, f);
        _assemblyGovernanceCall(
            1,
            address(assemblyArchive),
            abi.encodeCall(assemblyArchive.admitFamily, (name, f)),
            scope,
            oldHash,
            newHash
        );
        (OcA.Family memory saved, uint8 status) = assemblyArchive.family(hash);
        require(
            status == 1 && keccak256(abi.encode(saved)) == keccak256(abi.encode(f)),
            "oc family admitted"
        );
    }

    function _ocGrantFixity(address holder) private {
        bytes32 role = keccak256("ROLE_FIXITY_OPERATOR");
        (bytes32 chain, uint64 revision) = assemblyRoles.roleMutationState(role);
        (bytes32 globalChain, uint64 globalRevision) = assemblyRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(assemblyRoles),
                role,
                holder
            )
        );
        bytes32 nextChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(assemblyRoles),
                role,
                holder,
                true,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(assemblyRoles),
                role,
                holder,
                true,
                globalRevision + 1
            )
        );
        bytes32 oldHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(assemblyRoles),
                scope,
                false,
                chain,
                revision,
                globalChain,
                globalRevision
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(assemblyRoles),
                scope,
                true,
                nextChain,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        _assemblyGovernanceCall(
            1,
            address(assemblyRoles),
            abi.encodeCall(assemblyRoles.grantRole, (role, holder)),
            scope,
            oldHash,
            newHash
        );
        require(assemblyRoles.hasRole(role, holder), "oc actual fixity role");
    }

    function _ocSign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _ocNativeLeaf(bytes32 data, uint256 end) private pure returns (bytes32) {
        return
            sha256(abi.encodePacked(sha256(abi.encodePacked(data)), sha256(abi.encodePacked(end))));
    }

    function _ocSlice(bytes memory raw, uint256 offset, uint256 length)
        private
        pure
        returns (bytes memory part)
    {
        require(offset <= raw.length && length <= raw.length - offset, "oc slice bounds");
        part = new bytes(length);
        assembly ("memory-safe") {
            let source := add(add(raw, 32), offset)
            let target := add(part, 32)
            for { let i := 0 } lt(i, length) { i := add(i, 32) } {
                mstore(add(target, i), mload(add(source, i)))
            }
        }
    }

    function _deployAssemblyGraph() internal {
        _deployAssemblyFoundation();
        _deployAssemblyEarlyArtist();
        GenesisBatch memory creation;
        creation.actionClass = 1;
        creation.calls = new GovernanceCall[](1);
        creation.callDatas = new bytes[](1);
        (creation.calls[0], creation.callDatas[0]) =
            StreamCurrentStackPlan.createCollectionCall(assemblyCore, 1, 2);
        _assemblyGovernance(
            creation, "https://fixtures.example.invalid/native-assembly/create-collection"
        );
        _deployAssemblyEarlySources(_assemblyRendererCatalog());
        _deployAssemblyFinalityGraph();
    }

    function _assemblyRegisterDocument(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory raw,
        bytes32 canonicalization
    ) internal returns (bytes32 documentHash) {
        bytes32[] memory chunks = _assemblyUpload(raw);
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, keccak256(raw), canonicalization, bytes32(0), "", uint32(raw.length)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            assemblySchemas.registrationTransition(spec, chunks);
        _assemblyGovernanceCall(
            1,
            address(assemblySchemas),
            abi.encodeCall(assemblySchemas.registerDocument, (spec, chunks)),
            scope,
            oldHash,
            newHash
        );
        return keccak256(bytes(name));
    }

    function _assemblyUpload(bytes memory raw) internal returns (bytes32[] memory chunks) {
        require(raw.length != 0, "nonempty retained document");
        chunks = new bytes32[]((raw.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            uint256 length = raw.length - i * 8192;
            if (length > 8192) length = 8192;
            bytes memory part = _ocSlice(raw, i * 8192, length);
            address pointer;
            (chunks[i], pointer) = assemblyStore.publishChunk(part);
            require(
                chunks[i] == keccak256(part) && pointer.code.length == length + 1,
                "exact retained original chunk"
            );
        }
    }

    function _assemblyGrantFamily(bytes32 family, uint8 authorizationClass, address actor)
        internal
    {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = assemblyMetadata.familyWriterTransition(
            1, family, authorizationClass, actor, true
        );
        _assemblyGovernanceCall(
            1,
            address(assemblyMetadata),
            abi.encodeCall(
                assemblyMetadata.setFamilyWriter, (1, family, authorizationClass, actor, true)
            ),
            scope,
            oldHash,
            newHash
        );
    }

    function _assemblyPrepareDescriptionDefinitions() internal {
        _assemblyEnsureRawDefinition();
        string[14] memory names = [
            "STREAM_WORK_DESCRIPTION_V1",
            "STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1",
            "STREAM_WORK_FORMAT_CATALOG_V1",
            "STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1",
            "STREAM_RIGHTS_V1",
            "STREAM_RIGHTS_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTENT_V1",
            "STREAM_ARTIST_INTENT_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTENT_WAIVER_V1",
            "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTERVIEW_V1",
            "STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1"
        ];
        _assemblyRegisterDocument(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(assemblyVm.readFile("schemas/museum/account-profile/RFC8785_JCS.json")),
            assemblySchemas.RAW_BYTES()
        );
        // Each document has an independent immutable identifier; all share one actual delayed action.
        GenesisBatch memory definitions;
        definitions.actionClass = 1;
        definitions.calls = new GovernanceCall[](names.length);
        definitions.callDatas = new bytes[](names.length);
        for (uint256 i; i < names.length; ++i) {
            bytes memory raw =
                bytes(assemblyVm.readFile(string.concat("schemas/records/", names[i], ".json")));
            bytes32[] memory chunks = _assemblyUpload(raw);
            IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
                names[i],
                i % 2 == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CATALOG,
                keccak256(raw),
                assemblySchemas.RAW_BYTES(),
                bytes32(0),
                "",
                uint32(raw.length)
            );
            (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
                assemblySchemas.registrationTransition(spec, chunks);
            definitions.callDatas[i] =
                abi.encodeCall(assemblySchemas.registerDocument, (spec, chunks));
            definitions.calls[i] = StreamCurrentStackPlan.call(
                address(assemblySchemas), definitions.callDatas[i], scope, oldHash, newHash
            );
        }
        _admitAssemblyBatch(definitions);
        _assemblyGovernance(
            definitions, "https://fixtures.example.invalid/native-assembly/description-definitions"
        );
        _assemblyAdmitRecordType(
            keccak256("WORK_DESCRIPTION"), StreamRecordFamilies.CURATOR, 0x010a
        );
        _assemblyAdmitRecordType(keccak256("RIGHTS_STATEMENT"), StreamRecordFamilies.RIGHTS, 0x0180);
        _assemblyAdmitRecordType(keccak256("ARTIST_INTENT"), StreamRecordFamilies.ARTIST, 2);
        _assemblyAdmitRecordType(keccak256("ARTIST_INTENT_WAIVER"), StreamRecordFamilies.ARTIST, 2);
        _assemblyAdmitRecordType(keccak256("ARTIST_STATEMENT"), StreamRecordFamilies.ARTIST, 2);
        _assemblyGrantFamily(StreamRecordFamilies.CURATOR, 3, address(this));
        _assemblyGrantFamily(StreamRecordFamilies.RIGHTS, 7, address(this));
        _assemblyGrantFamily(StreamRecordFamilies.IDENTITY, 7, address(this));
        _assemblyRaisePublicationReadBudget();
    }

    function _assemblyRaisePublicationReadBudget() private {
        IStreamGasParameterHost host = IStreamGasParameterHost(address(assemblyArtists));
        bytes32 id = keccak256("6529STREAM_GGP_ARTIST_RECORD_PUBLICATION_READ_GAS");
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) = host.gasParameterInfo(id);
        require(
            value == 400000 && floor == 150000 && failure == 2 && revision == 1,
            "original publication read budget"
        );
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, address(host), id
            )
        );
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        uint256 next = 800000;
        bytes32 oldHash = keccak256(abi.encode(domain, scope, value, floor, failure, revision));
        bytes32 newHash = keccak256(abi.encode(domain, scope, next, floor, failure, revision + 1));
        _assemblyGovernanceCall(
            1,
            address(host),
            abi.encodeCall(host.raiseGasParameter, (id, next)),
            scope,
            oldHash,
            newHash
        );
        (uint256 saved, uint256 savedFloor, uint8 savedFailure, uint64 savedRevision) =
            host.gasParameterInfo(id);
        require(
            saved == next && savedFloor == floor && savedFailure == failure
                && savedRevision == revision + 1,
            "actual governed publication cap and revision"
        );
    }

    function _assemblyAdmitRecordType(bytes32 kind, bytes32 family, uint16 mask) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            assemblyMetadata.recordTypeTransition(kind, family, mask);
        _assemblyGovernanceCall(
            1,
            address(assemblyMetadata),
            abi.encodeCall(assemblyMetadata.admitRecordType, (kind, family, mask)),
            scope,
            oldHash,
            newHash
        );
    }

    function _assemblySubject() internal view returns (bytes32) {
        return StreamMetadataSubjects.scopeSubject(
            block.chainid, address(assemblyCore), _assemblyScope()
        );
    }

    function _assemblyOriginalRecord(bytes32 kind, bytes32 schema, bytes memory raw)
        private
        view
        returns (IStreamPreservationRecords.CollectionRecord memory record)
    {
        record.recordType = kind;
        record.subjectId = _assemblySubject();
        record.schemaId = schema;
        record.effectiveAt = uint64(block.timestamp);
        record.uri = "https://fixtures.example.invalid/native-assembly/original-preservation-record";
        record.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encodePacked(keccak256(raw)), keccak256("RFC8785_JCS")
        );
    }

    function _assemblySelectDescriptionsAndWaiver() internal {
        T.Binding memory binding_ = IStreamArtistBindingOwner(assemblySuite.owners[0]).binding(1);
        assemblyWorkDescription.subjectId = _assemblySubject();
        assemblyWorkDescription.profileHash = StreamWorkRecordDefinitions.PROFILE_HASH;
        assemblyWorkDescription.full.title = "Native current-stack original artwork";
        assemblyWorkDescription.full.creator.kind = StreamWorkRecordTypes.CreatorKind.ARTIST;
        assemblyWorkDescription.full.creator.artistId = binding_.artistId;
        assemblyWorkDescription.full.creator.bindingGeneration = binding_.generation;
        assemblyWorkDescription.full.creator.bindingHash = binding_.bindingHash;
        assemblyWorkDescription.full.creation.start = 20240229;
        assemblyWorkDescription.full.medium = "Generative instructions";
        assemblyWorkDescription.full.measurements.kind =
        StreamWorkRecordTypes.MeasurementKind.DIMENSIONLESS_GENERATIVE;
        assemblyWorkDescription.full.creditLine = "Original actual Artist/Safe record";
        bytes memory raw = StreamWorkRecordJson.serialize(assemblyWorkDescription);
        IStreamPreservationRecords.CollectionRecord memory record = _assemblyOriginalRecord(
            keccak256("WORK_DESCRIPTION"), StreamWorkRecordDefinitions.SCHEMA_ID, raw
        );
        assemblyWorkRecord = assemblyMetadata.recordCollectionRecordWithPayload(1, record, raw);
        assemblyWork.selectCurrent(
            1,
            _assemblySubject(),
            assemblyWorkRecord,
            0,
            0,
            IStreamWorkRecordSelection.Witness(record, assemblyWorkDescription)
        );
        assemblyRightsStatement.subjectId = _assemblySubject();
        assemblyRightsStatement.profileHash = StreamRightsRecordDefinitions.PROFILE_HASH;
        assemblyRightsStatement.licensor.kind = StreamRightsRecordTypes.LicensorKind.ACCOUNT;
        assemblyRightsStatement.licensor.account = address(this);
        assemblyRightsStatement.startDate = 20240229;
        assemblyRightsStatement.openEnd = true;
        raw = StreamRightsRecordJson.serialize(assemblyRightsStatement);
        record = _assemblyOriginalRecord(
            keccak256("RIGHTS_STATEMENT"), StreamRightsRecordDefinitions.SCHEMA_ID, raw
        );
        assemblyRightsRecord = assemblyMetadata.recordCollectionRecordWithPayload(1, record, raw);
        assemblyRights.selectCurrent(
            1, _assemblySubject(), assemblyRightsRecord, 0, 0, assemblyRightsStatement
        );
        assemblyIntentWaiver.subjectId = _assemblySubject();
        assemblyIntentWaiver.profileHash = StreamConservationDefinitions.WAIVER_PROFILE_HASH;
        assemblyIntentWaiver.artist = StreamConservationRecordTypes.ArtistClaim(
            binding_.artistId,
            binding_.generation,
            binding_.bindingHash,
            StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
        );
        assemblyIntentWaiver.waiverStatement = _assemblyStatementReference(
            "https://fixtures.example.invalid/native-assembly/explicit-intent-waiver"
        );
        assemblyIntentWaiver.interview.status = StreamConservationRecordTypes.InterviewStatus.WAIVED;
        assemblyIntentWaiver.interview.waiverStatement = _assemblyStatementReference(
            "https://fixtures.example.invalid/native-assembly/explicit-interview-waiver"
        );
        raw = StreamArtistIntentWaiverJson.serialize(assemblyIntentWaiver);
        record = _assemblyOriginalRecord(
            keccak256("ARTIST_INTENT_WAIVER"), StreamConservationDefinitions.WAIVER_SCHEMA_ID, raw
        );
        assemblyWaiverRecord = _assemblyPublishArtistRecord(record, raw);
        IStreamConservationRecordSelection.WaiverWitness memory witness;
        witness.original = record;
        witness.waiver = assemblyIntentWaiver;
        assemblyConservation.adoptWaiver(1, _assemblySubject(), assemblyWaiverRecord, 0, 0, witness);
        _assemblySealDescriptions();
        uint256 safeNonce = assemblyArtist.nonce();
        require(
            executeSafe(
                assemblyArtist,
                assemblyArtistKeys,
                address(assemblyConservation),
                0,
                abi.encodeCall(
                    assemblyConservation.lockArtistIntent,
                    (1, _assemblySubject(), assemblyWaiverRecord, uint64(1))
                ),
                0
            ),
            "actual original Artist Safe seals intent"
        );
        IStreamConservationRecordSelection.IntentLock memory locked =
            assemblyConservation.intentLock(1, _assemblySubject());
        require(
            assemblyArtist.nonce() == safeNonce + 1 && locked.locked
                && locked.locker == address(assemblyArtist) && locked.artistId == binding_.artistId
                && locked.identityRecordHash == binding_.identityRecordHash
                && locked.bindingHash == binding_.bindingHash
                && locked.bindingGeneration == binding_.generation
                && locked.recordHash == assemblyWaiverRecord && locked.revision == 1
                && locked.lockedAt == block.timestamp,
            "original intent selection and Safe authority retained"
        );
    }

    function _assemblyStatementReference(string memory uri)
        private
        pure
        returns (StreamConservationRecordTypes.Reference memory result)
    {
        result.algorithm = 1;
        result.canonicalizationId = keccak256("RAW_BYTES");
        result.digest = abi.encodePacked(keccak256(bytes(uri)));
        result.uri = uri;
    }

    function _assemblyPublishArtistRecord(
        IStreamPreservationRecords.CollectionRecord memory record,
        bytes memory raw
    ) private returns (bytes32 recordHash) {
        (bytes32 payloadHash, address payloadPointer) = assemblyStore.publishChunk(raw);
        (address savedPointer, uint32 savedLength) = assemblyStore.chunk(payloadHash);
        bytes memory savedRaw = assemblyStore.readChunk(payloadHash);
        require(
            payloadHash == keccak256(raw) && payloadPointer != address(0)
                && savedPointer == payloadPointer && savedLength == raw.length
                && savedRaw.length == raw.length && keccak256(savedRaw) == keccak256(raw),
            "exact permissionless original waiver payload before candidate admission"
        );
        AssemblyPublication.Publication memory publication;
        publication.metadataHost = address(assemblyMetadata);
        publication.recorder = address(assemblyArtist);
        publication.collectionId = 1;
        publication.subjectId = _assemblySubject();
        publication.recordType = record.recordType;
        publication.schemaId = record.schemaId;
        publication.canonicalizationId = record.contentHash.canonicalizationId;
        publication.payloadAlgorithm = 1;
        publication.payloadHash = keccak256(raw);
        publication.uriHash = keccak256(bytes(record.uri));
        publication.effectiveAt = record.effectiveAt;
        publication.candidateRecordHash =
            assemblyMetadata.deriveCollectionRecordHashFor(address(assemblyArtist), 1, record);
        bytes memory statement = abi.encode(uint16(1), publication);
        T.Attestation memory attestation = T.Attestation(
            1,
            7,
            _assemblySubject(),
            publication.candidateRecordHash,
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(statement),
            record.uri
        );
        T.Authorization memory authorization = _assemblyAuthorization(true);
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.attestationDigest(attestation, authorization));
        assemblyWaiverAuthorization =
            assemblyArtists.recordArtistAttestation(attestation, authorization, statement);
        AssemblyPublication.Evidence memory evidence =
            assemblyArtists.requireRecordPublication(assemblyWaiverAuthorization, publication);
        require(
            evidence.attestationRecordHash == assemblyWaiverAuthorization
                && evidence.artistId == assemblyArtistId
                && evidence.signer == address(assemblyArtist) && evidence.authorityClass == 1
                && evidence.requiredCapability == 64 && evidence.signedAt == authorization.time
                && evidence.publicationHash == keccak256(abi.encode(publication)),
            "actual op24 original Safe publication evidence"
        );
        IStreamArtistRecordPublicationOwner.Record memory savedPublication = IStreamArtistRecordPublicationOwner(
                assemblySuite.owners[4]
            ).publicationAttestation(assemblyWaiverAuthorization);
        require(
            keccak256(abi.encode(savedPublication.publication))
                    == keccak256(abi.encode(publication))
                && keccak256(abi.encode(savedPublication.evidence))
                    == keccak256(abi.encode(evidence))
                && savedPublication.metadataHostCodeHash == address(assemblyMetadata).codehash,
            "exact original owner publication and authority evidence"
        );
        recordHash = assemblyMetadata.recordArtistCollectionRecordWithPayload(
            address(assemblyArtist), 1, record, raw, assemblyWaiverAuthorization
        );
        require(
            recordHash == publication.candidateRecordHash, "exact original artist record candidate"
        );
        (
            IStreamPreservationRecords.CollectionRecord memory savedRecord,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(recordHash);
        require(
            keccak256(abi.encode(savedRecord)) == keccak256(abi.encode(record))
                && receipt.collectionId == 1 && receipt.recorder == address(assemblyArtist)
                && receipt.authorizationClass == 1
                && receipt.artistAuthorization == assemblyWaiverAuthorization
                && receipt.recordIndex == 0 && receipt.recordChainHash != 0
                && assemblyMetadata.consumedArtistAuthorization(assemblyWaiverAuthorization)
                && assemblyMetadata.latestCollectionRecordHashFor(
                    1, record.recordType, record.subjectId, address(assemblyArtist)
                ) == recordHash,
            "original Safe recorder, class1 lane and consumed authorization backlink"
        );
    }

    function _assemblySealDescriptions() private {
        IStreamRecordSelectionLock[2] memory selectors = [
            IStreamRecordSelectionLock(address(assemblyWork)),
            IStreamRecordSelectionLock(address(assemblyRights))
        ];
        bytes32[2] memory records = [assemblyWorkRecord, assemblyRightsRecord];
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        for (uint256 i; i < 2; ++i) {
            (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
                selectors[i].selectionLockTransition(1, _assemblySubject(), records[i], 1);
            batch.callDatas[i] = abi.encodeCall(
                selectors[i].lockSelection, (1, _assemblySubject(), records[i], uint64(1))
            );
            batch.calls[i] = StreamCurrentStackPlan.call(
                address(selectors[i]), batch.callDatas[i], scope, oldHash, newHash
            );
        }
        _admitAssemblyBatch(batch);
        bytes32 action = _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/seal-original-work-rights"
        );
        for (uint256 i; i < 2; ++i) {
            IStreamRecordSelectionLock.SelectionLock memory seal =
                selectors[i].selectionLock(1, _assemblySubject());
            require(
                seal.locked && seal.recordHash == records[i] && seal.revision == 1
                    && seal.actionId == action && seal.executor == address(assemblyExecutor)
                    && seal.governanceRoot == address(assemblyRoot),
                "actual class2 original selected-head seal"
            );
        }
    }

    function _assemblyPublishOriginalRoot() internal {
        _assemblySetupArchiveAdmissions();
        _assemblyEnsureRawDefinition();
        string[4] memory names = [
            "STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1",
            "STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1",
            "STREAM_TOKEN_CONTENT_ROOT_RECORD_V1",
            "STREAM_ABI_TOKEN_CONTENT_ROOT_RECORD_V1"
        ];
        for (uint256 i; i < names.length; ++i) {
            _assemblyRegisterDocument(
                names[i],
                i % 2 == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                StreamContentRootSchemas.document(keccak256(bytes(names[i]))),
                assemblySchemas.RAW_BYTES()
            );
        }
        _assemblyGrantFamily(StreamRecordFamilies.SNAPSHOT, 7, address(this));
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        assemblyTokens.appendCollectionTokens(1, ids);
        bytes32 inventory = assemblyCoordinators.beginInventory(_assemblyScope());
        assemblyCoordinators.appendInventory(inventory, 2);
        assemblyCoordinatorInventoryPlan = inventory;
        _assemblyLockContent();
        bytes32 checkpoint = assemblyContentCheckpoint.beginCollectionCheckpoint(1);
        IStreamOnchainContentCheckpoint.TokenPayload[] memory payloads =
            new IStreamOnchainContentCheckpoint.TokenPayload[](2);
        for (uint256 i; i < 2; ++i) {
            payloads[i] = IStreamOnchainContentCheckpoint.TokenPayload(
                i + 1, bytes(""), _assemblyHTML(i + 1)
            );
        }
        assemblyContentCheckpoint.appendCheckpointTokens(checkpoint, payloads);
        IStreamOnchainContentCheckpoint.Plan memory plan =
            assemblyContentCheckpoint.requireCurrentCheckpoint(checkpoint);
        StreamTokenContentLeaf[] memory rows = new StreamTokenContentLeaf[](2);
        rows[0] = assemblyContentCheckpoint.checkpointLeaf(checkpoint, 0);
        rows[1] = assemblyContentCheckpoint.checkpointLeaf(checkpoint, 1);
        bytes memory raw = abi.encode(
            StreamContentRootSchemas.LEAF_SCHEMA,
            block.chainid,
            address(assemblyCore),
            address(assemblyContentCheckpoint),
            checkpoint,
            uint256(1),
            plan.contentRoot,
            plan.tokenCount,
            rows
        );
        (bytes32 artifact, bytes32 coverage) =
            _ocCover(raw, StreamContentRootSchemas.LEAF_SCHEMA, StreamContentRootSchemas.LEAF_CANON);
        bytes32 leafPlan =
            assemblyLeaves.beginManifest(checkpoint, artifact, coverage, assemblyArtistId);
        bytes32 leafManifest = assemblyLeaves.verifyNextLeaves(leafPlan, 2);
        IStreamContentRootPublication.Publication memory publication =
            IStreamContentRootPublication.Publication(
                1,
                bytes32(0),
                leafManifest,
                "https://fixtures.example.invalid/native-assembly/original-leaf-manifest"
            );
        bytes32 state = assemblyRouter.previewContentRootPublication(publication, address(this));
        AssemblyContent.Consent memory consent =
            AssemblyContent.Consent(1, address(assemblyRouter), keccak256("CONTENT_ROOT"), state);
        T.Authorization memory authorization = _assemblyAuthorization(false);
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.contentConsentDigest(consent, authorization));
        assemblyRootConsentObservedAt = uint64(block.timestamp);
        bytes32 originalConsent = assemblyArtists.recordContentConsent(consent, authorization);
        assemblyOriginalContentRoot = assemblyRouter.publishVerifiedTokenContentRoot(publication);
        IStreamContentRootPublication.Record memory record =
            assemblyRouter.contentRootRecord(assemblyOriginalContentRoot);
        require(
            record.artistConsent == originalConsent && record.artistId == assemblyArtistId
                && record.publisher == address(this) && record.stateHash == state,
            "original op17 joined to actual Router root"
        );
        require(
            assemblyRouter.collectionContentRootHead(1) == assemblyOriginalContentRoot
                && assemblyRouter.consumedArtistContentConsent(originalConsent),
            "original consent consumed once"
        );
    }

    function _assemblyEnsureRawDefinition() private {
        if (!assemblySchemas.document(assemblySchemas.RAW_BYTES()).exists) {
            _assemblyRegisterDocument(
                "RAW_BYTES",
                IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                bytes(assemblySchemas.RAW_BYTES_DEFINITION()),
                assemblySchemas.RAW_BYTES()
            );
        }
    }

    function _assemblyPublishAndLockSnapshot() internal {
        string[2] memory names =
            ["STREAM_NATIVE_ONCHAIN_SNAPSHOT_V1", "STREAM_NATIVE_ONCHAIN_SNAPSHOT_JSON_PROFILE_V1"];
        for (uint256 i; i < names.length; ++i) {
            _assemblyRegisterDocument(
                names[i],
                i == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CATALOG,
                bytes(assemblyVm.readFile(string.concat("schemas/records/", names[i], ".json"))),
                assemblySchemas.RAW_BYTES()
            );
        }
        StreamSnapshotTypes.Publication memory publication = StreamSnapshotTypes.Publication(
            1,
            keccak256("native assembly original source snapshot"),
            bytes32(0),
            0,
            bytes32(0),
            assemblyCoordinatorInventoryPlan,
            "https://fixtures.example.invalid/native-assembly/source-snapshot",
            uint64(block.timestamp),
            keccak256("retain actual original source graph")
        );
        bytes memory canonical;
        (publication.expectedSourceHash, canonical) =
            assemblySnapshots.previewSnapshot(publication, address(this));
        _assemblyUpload(canonical);
        assemblySnapshotRecord = assemblySnapshots.publishSnapshot(publication);
        StreamSnapshotTypes.Receipt memory receipt = assemblySnapshots.currentSnapshot(1);
        require(
            receipt.recordHash == assemblySnapshotRecord && receipt.revision == 1,
            "actual original source snapshot"
        );
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](3);
        batch.callDatas = new bytes[](3);
        bytes32[3] memory lockIds = [
            assemblySnapshots.SNAPSHOTS(),
            assemblySnapshots.METADATA_ALL(),
            assemblySnapshots.RECORD_TYPE()
        ];
        for (uint256 i; i < lockIds.length; ++i) {
            (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
                assemblySnapshots.lockTransition(1, lockIds[i]);
            batch.callDatas[i] = abi.encodeCall(assemblySnapshots.lockSnapshots, (1, lockIds[i]));
            batch.calls[i] = StreamCurrentStackPlan.call(
                address(assemblySnapshots), batch.callDatas[i], scope, oldHash, newHash
            );
        }
        _admitAssemblyBatch(batch);
        bytes32 action = _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/seal-original-source-snapshot"
        );
        for (uint256 i; i < lockIds.length; ++i) {
            StreamSnapshotTypes.Lock memory saved = assemblySnapshots.snapshotLock(1, lockIds[i]);
            require(
                saved.recordHash == assemblySnapshotRecord && saved.revision == 1
                    && saved.actionId == action,
                "actual three local snapshot seals"
            );
        }
        assemblyEntropySourceSet = assemblyEntropyFactory.prepareSourceSet(_assemblyScope());
        require(
            assemblyEntropySourceSet.code.length != 0
                && assemblyEntropySourceSet.code.length <= 24576,
            "actual complete original coordinator source set"
        );
        IStreamFinalityEntropySourceSet(assemblyEntropySourceSet).requireCurrentSourceSet();
    }

    function _assemblyScope() internal pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, bytes32(0));
    }

    function _assemblyHTML(uint256 tokenId) internal view returns (bytes memory) {
        (bytes32 seed, bool finalized) = assemblyEntropy.tokenSeed(tokenId);
        require(finalized, "original finalized token");
        return abi.encodePacked(
            "<html><head></head><body><script>const tokenId=",
            Strings.toString(tokenId),
            ";const tokenHash='",
            Strings.toHexString(uint256(seed), 32),
            "';const tokenDataBase64='",
            Base64.encode(assemblyCore.tokenData(tokenId)),
            "';",
            ASSEMBLY_SCRIPT,
            "</script></body></html>"
        );
    }

    function _assemblyExportOriginalSources() internal {
        // Output-only evidence for the real browser capture successor, never an authority input.
        // Every file comes from the actual successful mint/entropy/Router/owner execution above.
        assemblyVm.createDir("artifacts/native-assembly", true);
        for (uint256 tokenId = 1; tokenId <= 2; ++tokenId) {
            string memory prefix =
                string.concat("artifacts/native-assembly/token-", Strings.toString(tokenId));
            bytes memory html = _assemblyHTML(tokenId);
            string memory metadata =
                assemblyRouter.historicalTokenMetadataJSON(address(assemblyCore), tokenId);
            require(
                StreamOnchainContentBytes.matchesAnimation(bytes(metadata), html),
                "export exact original served HTML"
            );
            assemblyVm.writeFile(string.concat(prefix, ".html"), string(html));
            assemblyVm.writeFile(string.concat(prefix, ".json"), metadata);
        }
        assemblyVm.writeFile(
            "artifacts/native-assembly/source-records.txt",
            string.concat(
                "core=",
                Strings.toHexString(uint160(address(assemblyCore)), 20),
                "\nrouter=",
                Strings.toHexString(uint160(address(assemblyRouter)), 20),
                "\nartist=",
                Strings.toHexString(uint256(assemblyArtistId), 32),
                "\nroot=",
                Strings.toHexString(uint256(assemblyOriginalContentRoot), 32),
                "\nsnapshot=",
                Strings.toHexString(uint256(assemblySnapshotRecord), 32),
                "\n"
            )
        );
    }

    function _assemblyLockContent() private {
        GenesisBatch memory locks;
        locks.actionClass = 1;
        locks.calls = new GovernanceCall[](2);
        locks.callDatas = new bytes[](2);
        locks.callDatas[0] = abi.encodeCall(assemblyRouter.lockDisplayMetadata, (1));
        locks.callDatas[1] = abi.encodeCall(assemblyRouter.lockArtistIdentity, (1));
        for (uint256 i; i < 2; ++i) {
            locks.calls[i] = StreamCurrentStackPlan.call(
                address(assemblyRouter),
                locks.callDatas[i],
                keccak256(abi.encode(address(assemblyRouter), locks.callDatas[i])),
                bytes32(0),
                keccak256(locks.callDatas[i])
            );
        }
        _admitAssemblyBatch(locks);
        _assemblyGovernance(
            locks, "https://fixtures.example.invalid/native-assembly/original-presentation-locks"
        );
        bytes32[] memory classes = new bytes32[](3);
        classes[0] = keccak256("SCRIPT");
        classes[1] = keccak256("MEDIA_MANIFEST");
        classes[2] = keccak256("BASE_URI");
        for (uint256 i; i < classes.length; ++i) {
            for (uint256 j = i + 1; j < classes.length; ++j) {
                if (classes[j] < classes[i]) (classes[i], classes[j]) = (classes[j], classes[i]);
            }
        }
        AssemblyContent.Freeze memory freeze = AssemblyContent.Freeze(
            1, address(assemblyRouter), classes, assemblyRouter.artistContentFreezeState(1)
        );
        T.Authorization memory authorization = _assemblyAuthorization(false);
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.contentFreezeDigest(freeze, authorization));
        bytes32 originalFreeze = assemblyArtists.authorizeArtistContentFreeze(freeze, authorization);
        assemblyRouter.applyArtistContentFreeze(1, originalFreeze);
        IStreamMetadataServingFacts.ServingFacts memory serving =
            assemblyRouter.collectionServingFacts(1);
        require(
            serving.scriptLocked && serving.mediaLocked && serving.baseURILocked
                && serving.dependenciesLocked && serving.artistIdentityLocked
                && serving.displayMetadataLocked,
            "all original serving locks applied"
        );
    }

    function _assemblyRendererCatalog() private view returns (bytes memory) {
        // Raw serving facts expose the immutable linked renderer before artwork publication.
        // Only its fixed identity/profile enter this catalog; configured/locked readiness does not.
        IStreamMetadataServingFacts.ServingFacts memory f = assemblyRouter.collectionServingFacts(1);
        (bytes32 presentation, bytes32 context, bytes32 dependencies) =
            assemblyRouter.renderingProfile();
        (string memory uri, bytes32 manifest) = assemblyRouter.streamModuleManifest();
        require(
            bytes(uri).length != 0 && f.renderer.code.length != 0
                && f.renderer.codehash == f.rendererCodeHash,
            "actual original linked renderer"
        );
        return StreamReferenceRendererCatalog.declarationJSON(
            StreamReferenceRenderTypes.RendererDeclaration(
                f.renderer,
                f.rendererCodeHash,
                assemblyRouter.streamModuleVersion(),
                manifest,
                presentation,
                context,
                dependencies,
                keccak256("STATIC")
            )
        );
    }

    function _deployAssemblyFoundation() internal {
        assemblyVm.warp(1000);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        assemblyRootKeys = new uint256[](2);
        assemblyRootKeys[0] = 0x65295101;
        assemblyRootKeys[1] = 0x65295102;
        assemblyArtistKeys = new uint256[](2);
        assemblyArtistKeys[0] = 0x65295201;
        assemblyArtistKeys[1] = 0x65295202;
        assemblyRoot =
            createOfficialSafe(components, safeOwnerAddresses(assemblyRootKeys), 2, 31001);
        assemblyArtist =
            createOfficialSafe(components, safeOwnerAddresses(assemblyArtistKeys), 2, 31002);
        assemblyGuardians = new address[](2);
        for (uint256 i; i < 2; ++i) {
            uint256[] memory keys = new uint256[](1);
            keys[0] = 0x65295301 + i;
            assemblyGuardians[i] =
                address(createOfficialSafe(components, safeOwnerAddresses(keys), 1, 31003 + i));
        }
        if (assemblyGuardians[0] > assemblyGuardians[1]) {
            (assemblyGuardians[0], assemblyGuardians[1]) =
            (assemblyGuardians[1], assemblyGuardians[0]);
        }
        // Foundation Ownable/initial bootstrap authority is the actual test deployer. Late
        // slots are used only for products with explicit constructor authority arguments.
        assemblyExecutor = StreamGovernanceExecutor(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamGovernanceExecutor,
                    abi.encode(address(this))
                ))
        );
        assemblyRoles = StreamRoleRegistry(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamRoleRegistry,
                    abi.encode(address(assemblyExecutor))
                ))
        );
        assemblyModules = StreamModuleRegistry(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamModuleRegistry,
                    abi.encode(
                        assemblyExecutor,
                        ASSEMBLY_REGISTRY,
                        "https://fixtures.example.invalid/native-assembly/modules"
                    )
                ))
        );
        assemblyCore = StreamCore(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamCore,
                    abi.encode(
                        "Native Assembly",
                        "ASSEMBLY",
                        address(assemblyExecutor),
                        StreamCore.GenesisModuleRegistryConfig(
                            address(assemblyModules),
                            address(assemblyModules).codehash,
                            ASSEMBLY_REGISTRY,
                            ASSEMBLY_DEPLOYMENT
                        ),
                        StreamCurrentStackPlan.gasParameters()
                    )
                ))
        );
        assemblyManifest = StreamSystemManifest(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamSystemManifest,
                    abi.encode(address(assemblyCore), address(assemblyExecutor))
                ))
        );
        StreamGovernanceGenesisPlan.Configuration memory c;
        c.executor = assemblyExecutor;
        c.roles = assemblyRoles;
        c.core = assemblyCore;
        c.registry = assemblyModules;
        c.manifest = assemblyManifest;
        c.bootstrapAuthority = address(this);
        c.governanceRoot = address(assemblyRoot);
        c.guardians = assemblyGuardians;
        c.deploymentHash = ASSEMBLY_DEPLOYMENT;
        c.manifestModuleHash = keccak256("native assembly system manifest");
        c.moduleURI = "https://fixtures.example.invalid/native-assembly/foundation";
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes('{"purpose":"native finality assembly foundation","version":1}')
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "https://fixtures.example.invalid/native-assembly/foundation",
            keccak256("events"),
            keccak256("compatibility"),
            keccak256("ids"),
            keccak256("schemas"),
            keccak256("canonicalization"),
            keccak256("specification"),
            keccak256("client")
        );
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) =
            StreamGovernanceGenesisPlan.build(c, payload, update);
        for (uint256 i; i < binding.actionPolicies.length; ++i) {
            assemblyPolicies.push(binding.actionPolicies[i]);
        }
        assemblyExecutor.commitGenesisPlan(assemblyExecutor.hashGenesisPlan(binding, batches));
        assemblyExecutor.prepareGenesis(binding, batches);
        assemblyExecutor.initializeGenesis(binding, batches);
        require(
            address(assemblyExecutor.roleRegistry()) == address(assemblyRoles)
                && assemblyRoles.owner() == address(assemblyExecutor)
                && assemblyExecutor.owner() == address(assemblyRoot),
            "actual sealed foundation authorities"
        );
        require(
            address(assemblyModules.governanceExecutor()) == address(assemblyExecutor),
            "actual canonical modules"
        );
    }

    function _assemblyGovernance(GenesisBatch memory batch, string memory reasonURI)
        internal
        returns (bytes32 actionId)
    {
        assemblyExecutor.publishGovernanceCallData(batch.callDatas);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            batch.calls, StreamGovernanceBootstrap.governanceCallsHash(batch.calls)
        );
        uint64 at = uint64(block.timestamp + assemblyExecutor.minimumDelay(batch.actionClass));
        bytes memory data = abi.encodeCall(
            assemblyExecutor.scheduleGovernanceBatch,
            (
                batch.actionClass,
                batch.calls,
                scope,
                oldHash,
                newHash,
                at,
                at + 7 days,
                keccak256(bytes(reasonURI)),
                reasonURI,
                ASSEMBLY_DEPLOYMENT
            )
        );
        uint256 nonce = assemblyRoot.nonce();
        assemblyVm.recordLogs();
        require(
            executeSafe(assemblyRoot, assemblyRootKeys, address(assemblyExecutor), 0, data, 0),
            "actual root Safe schedules"
        );
        require(assemblyRoot.nonce() == nonce + 1, "root Safe consumed its transaction");
        NativeAssemblyVm.Log[] memory logs = assemblyVm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(assemblyExecutor) || logs[i].topics.length != 4
                    || logs[i].topics[0]
                        != keccak256(
                            "GovernanceActionScheduled(uint16,bytes32,uint8,address,uint256,bytes4,bytes32,bytes32,bytes32,bytes32,uint64,uint64,uint256,address,bytes32,string,bytes32)"
                        )
            ) continue;
            GovernanceAction memory candidate = assemblyExecutor.governanceAction(logs[i].topics[1]);
            if (
                candidate.status != GovernanceActionStatus.SCHEDULED
                    || candidate.proposer != address(assemblyRoot) || candidate.scopeHash != scope
                    || candidate.oldValueHash != oldHash || candidate.newValueHash != newHash
                    || candidate.notBefore != at
                    || candidate.reasonHash != keccak256(bytes(reasonURI))
            ) continue;
            require(actionId == 0 || actionId == logs[i].topics[1], "one exact scheduled action");
            actionId = logs[i].topics[1];
        }
        require(actionId != 0, "actual saved action identified");
        assemblyVm.warp(at);
        assemblyExecutor.executeGovernanceBatch(actionId, batch.calls, batch.callDatas);
        require(
            assemblyExecutor.governanceAction(actionId).status == GovernanceActionStatus.EXECUTED,
            "actual delayed action executed"
        );
    }

    /// @dev These are real original owners. Only the future Coordinator address is unresolved;
    /// its dedicated CREATE slot is already deployed and cannot be used by another caller.
    function _deployAssemblyEarlyArtist() internal {
        (assemblyCoordinatorSlot, assemblyCoordinatorAddress) = _slot();
        assemblyLedger = StreamMintLedger(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamMintLedger, abi.encode()
                ))
        );
        assemblyManager = StreamMintManager(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamMintManager,
                    abi.encode(assemblyCore, assemblyLedger, IERC165(address(assemblyModules)))
                ))
        );
        assemblyLedger.setLedgerWriter(address(assemblyManager), true);
        assemblyAssetPolicy = StreamAssetPolicyRegistry(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamAssetPolicyRegistry,
                    abi.encode(address(assemblyExecutor))
                ))
        );
        IStreamGasParameterHost.GasParameterConfig[3] memory walletGas;
        walletGas[0] = _gas("ERC_1271_GAS_LIMIT", 400000, 350000, 2);
        walletGas[1] = _gas("ASSET_POLICY_GAS_LIMIT", 30000, 15000, 2);
        walletGas[2] = _gas("WALLET_DEPOSIT_GAS_LIMIT", 200000, 25000, 2);
        assemblySplits = StreamSplitFactory(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamSplitFactory,
                    abi.encode(assemblyAssetPolicy, address(assemblyExecutor), walletGas)
                ))
        );
        _deployAssemblyArchive();
        T.SuiteConfiguration memory s;
        s.core = address(assemblyCore);
        s.mintManager = address(assemblyManager);
        s.roleRegistry = address(assemblyRoles);
        s.validator = address(
            StreamArtistRegistryValidatorBase(
                payable(_assemblyCreate(
                        StreamNativeAssemblyCreation.Kind.StreamArtistRegistryValidatorBase,
                        abi.encode()
                    ))
            )
        );
        s.primaryRevenueClass = keccak256("PRIMARY_SALE");
        assemblyArtistExtensions = new StreamArtistExtensionFactory();
        assemblyArtists = _deploySplitArtistFacade(
            StreamNativeAssemblyCreation.creation(
                StreamNativeAssemblyCreation.Kind.StreamArtistOnboardingRegistry
            ),
            address(this),
            address(assemblyArtistExtensions),
            [
                s.core,
                s.mintManager,
                assemblyCoordinatorAddress,
                address(assemblyExecutor),
                address(assemblyArchive)
            ],
            ASSEMBLY_DEPLOYMENT,
            "https://fixtures.example.invalid/native-assembly/artist",
            keccak256("native assembly artist")
        );
        s.registry = address(assemblyArtists);
        s.archive = address(
            StreamArtistArchiveV2(
                payable(_assemblyCreate(
                        StreamNativeAssemblyCreation.Kind.StreamArtistArchiveV2,
                        abi.encode(s.registry, assemblyCoordinatorAddress)
                    ))
            )
        );
        s.owners[0] = address(
            StreamArtistBindingLifecycle(
                payable(_assemblyCreate(
                        StreamNativeAssemblyCreation.Kind.StreamArtistBindingLifecycle,
                        abi.encode(
                            s.registry, assemblyCoordinatorAddress, s.archive, s.core, s.mintManager
                        )
                    ))
            )
        );
        s.owners[1] = address(
            StreamArtistCollaboratorLifecycle(
                payable(_assemblyCreate(
                        StreamNativeAssemblyCreation.Kind.StreamArtistCollaboratorLifecycle,
                        abi.encode(
                            s.registry, assemblyCoordinatorAddress, s.archive, s.core, s.mintManager
                        )
                    ))
            )
        );
        s.owners[2] = _deploySplitArtistIdentity(
            StreamNativeAssemblyCreation.creation(
                StreamNativeAssemblyCreation.Kind.StreamArtistIdentityAuthority
            ),
            address(this),
            address(assemblyArtistExtensions),
            [s.registry, assemblyCoordinatorAddress, s.archive, s.core, s.mintManager]
        );
        s.owners[3] = address(
            StreamArtistAcceptanceLifecycle(
                payable(_assemblyCreate(
                        StreamNativeAssemblyCreation.Kind.StreamArtistAcceptanceLifecycle,
                        abi.encode(
                            s.registry, assemblyCoordinatorAddress, s.archive, s.core, s.mintManager
                        )
                    ))
            )
        );
        s.owners[4] = address(
            StreamArtistAttributionLifecycle(
                payable(_assemblyCreate(
                        StreamNativeAssemblyCreation.Kind.StreamArtistAttributionLifecycle,
                        abi.encode(
                            s.registry, assemblyCoordinatorAddress, s.archive, s.core, s.mintManager
                        )
                    ))
            )
        );
        s.owners[5] = address(
            StreamArtistPayoutLifecycle(
                payable(_assemblyCreate(
                        StreamNativeAssemblyCreation.Kind.StreamArtistPayoutLifecycle,
                        abi.encode(
                            s.registry, assemblyCoordinatorAddress, s.archive, s.core, s.mintManager
                        )
                    ))
            )
        );
        s.owners[6] = address(
            StreamArtistConsentFinalityLifecycle(
                payable(_assemblyCreate(
                        StreamNativeAssemblyCreation.Kind.StreamArtistConsentFinalityLifecycle,
                        abi.encode(
                            s.registry, assemblyCoordinatorAddress, s.archive, s.core, s.mintManager
                        )
                    ))
            )
        );
        IStreamArtistAttribution attribution = IStreamArtistAttribution(s.registry);
        assemblyRouter = StreamMetadataRouter(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamMetadataRouter,
                    abi.encode(
                        s.core,
                        address(assemblyExecutor),
                        ASSEMBLY_DEPLOYMENT,
                        "https://fixtures.example.invalid/native-assembly/router",
                        keccak256("native assembly router"),
                        attribution
                    )
                ))
        );
        assemblyPrimary = StreamRevenueResolver(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamRevenueResolver,
                    abi.encode(
                        IStreamCore(s.core),
                        assemblySplits,
                        address(assemblyExecutor),
                        attribution,
                        _gas("ARTIST_BENEFICIARY_READ_GAS", 200000, 50000, 2)
                    )
                ))
        );
        assemblyRoyalties = StreamRoyaltyResolver(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamRoyaltyResolver,
                    abi.encode(
                        IStreamCore(s.core), assemblySplits, address(assemblyExecutor), attribution
                    )
                ))
        );
        s.metadata = address(assemblyRouter);
        s.primaryResolver = address(assemblyPrimary);
        s.royaltyResolver = address(assemblyRoyalties);
        assemblySuite = s;
        assemblySchemas = StreamSchemaRegistry(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamSchemaRegistry,
                    abi.encode(address(assemblyExecutor))
                ))
        );
        assemblyStore = StreamSchemaDocumentStore(assemblySchemas.chunkStore());
        assemblyMetadata = StreamCollectionMetadataV1(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamCollectionMetadataV1,
                    abi.encode(
                        StreamCollectionMetadataV1.Configuration(
                            s.core,
                            address(assemblyExecutor),
                            address(assemblySchemas),
                            s.registry,
                            ASSEMBLY_DEPLOYMENT,
                            "https://fixtures.example.invalid/native-assembly/metadata",
                            keccak256("native assembly metadata"),
                            _gas("METADATA_DEPENDENCY_READ_GAS", 400000, 50000, 1),
                            _gas("METADATA_ARTIST_READ_GAS", 12000000, 50000, 1)
                        )
                    )
                ))
        );
        require(
            assemblyCoordinatorAddress.code.length == 0,
            "Coordinator remains a future actual CREATE"
        );
        require(
            assemblyArtists.operationCoordinator() == assemblyCoordinatorAddress
                && assemblyArtists.core() == address(assemblyCore),
            "actual early facade binding"
        );
    }

    function _deployAssemblyArchive() private {
        StreamArchivalTypes.Observer[] memory observers = new StreamArchivalTypes.Observer[](2);
        observers[0] = StreamArchivalTypes.Observer(
            safeVm.addr(0xE5701), keccak256("assembly archival organization one")
        );
        observers[1] = StreamArchivalTypes.Observer(
            safeVm.addr(0xE5702), keccak256("assembly archival organization two")
        );
        if (observers[0].account > observers[1].account) {
            (observers[0], observers[1]) = (observers[1], observers[0]);
        }
        IStreamGasParameterHost.GasParameterConfig memory signatureGas =
            _gas("ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2);
        assemblyCheckpointVerifier = StreamArweaveCheckpointVerifier(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamArweaveCheckpointVerifier,
                    abi.encode(address(assemblyExecutor), observers, 2, signatureGas)
                ))
        );
        assemblyArchive = StreamArchivalCoverage(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamArchivalCoverage,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyExecutor),
                        address(assemblyRoles),
                        address(assemblyCheckpointVerifier),
                        signatureGas,
                        _gas("ARCHIVAL_DEPENDENCY_READ_GAS", 150000, 50000, 2)
                    )
                ))
        );
    }

    function _gas(string memory name, uint256 value, uint256 floor, uint8 failure)
        internal
        pure
        returns (IStreamGasParameterHost.GasParameterConfig memory)
    {
        return IStreamGasParameterHost.GasParameterConfig(name, value, floor, failure);
    }

    function _admitAssemblyPolicies(GovernanceActionPolicyEntry[] memory candidates) internal {
        uint256 count;
        for (uint256 i; i < candidates.length; ++i) {
            bool existing;
            for (uint256 j; j < assemblyPolicies.length; ++j) {
                if (_policyKey(candidates[i]) != _policyKey(assemblyPolicies[j])) continue;
                require(
                    keccak256(abi.encode(candidates[i]))
                        == keccak256(abi.encode(assemblyPolicies[j])),
                    "original exact policy retained"
                );
                existing = true;
            }
            if (!existing) candidates[count++] = candidates[i];
        }
        if (count == 0) return;
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            additions[i] = candidates[i];
        }
        for (uint256 i = 1; i < count; ++i) {
            for (
                uint256 j = i;
                j > 0 && _policyKey(additions[j - 1]) > _policyKey(additions[j]);
                --j
            ) {
                (additions[j - 1], additions[j]) = (additions[j], additions[j - 1]);
            }
        }
        (bytes32 candidate, bytes32 catalog, uint256 oldCount, uint64 revision) =
            assemblyExecutor.governanceActionPolicyState();
        require(oldCount == assemblyPolicies.length, "actual complete policy catalog");
        (bytes32 next, bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamGovernanceActionPolicy.extensionTransition(
            address(assemblyExecutor), candidate, catalog, oldCount, revision, additions
        );
        GenesisBatch memory batch;
        batch.actionClass = 3;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        batch.callDatas[0] = abi.encodeCall(
            assemblyExecutor.extendGovernanceActionPolicy, (revision, catalog, next, additions)
        );
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(assemblyExecutor), batch.callDatas[0], scope, oldHash, newHash
        );
        (batch.calls[1], batch.callDatas[1]) = _assemblyPublication(
            StreamGenesisManifestPlan.readAggregate(assemblyManifest).modules, next
        );
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/policy-extension"
        );
        for (uint256 i; i < count; ++i) {
            assemblyPolicies.push(additions[i]);
        }
    }

    function _assemblyPublication(
        StreamSystemManifest.ModuleAddresses memory modules,
        bytes32 reason
    ) internal returns (GovernanceCall memory call_, bytes memory data) {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(assemblyManifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            abi.encodePacked(
                '{"purpose":"native finality assembly","commitment":"',
                Strings.toHexString(uint256(reason), 32),
                '"}'
            )
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "https://fixtures.example.invalid/native-assembly/manifest",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        return StreamGenesisManifestPlan.publicationCall(assemblyManifest, payload, update, modules);
    }

    function _policyKey(GovernanceActionPolicyEntry memory p) private pure returns (bytes32) {
        return keccak256(abi.encode(p.actionClass, p.target, p.selector));
    }

    function _deployAssemblyEarlySources(bytes memory rendererCatalog) internal {
        for (uint256 i; i < 9; ++i) {
            (assemblySlots[i], assemblyLate[i]) = _slot();
        }
        assemblyTokens = StreamCollectionTokenInventory(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamCollectionTokenInventory,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyExecutor),
                        _gas("TOKEN_INVENTORY_CORE_READ_GAS", 150000, 50000, 1)
                    )
                ))
        );
        assemblyMembership = StreamFinalityScopeMembership(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamFinalityScopeMembership,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyMetadata),
                        address(assemblyTokens),
                        address(assemblyExecutor),
                        _gas("SCOPE_MEMBERSHIP_READ_GAS", 500000, 50000, 1)
                    )
                ))
        );
        assemblyCoordinators = StreamFinalityCoordinatorInventory(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamFinalityCoordinatorInventory,
                    abi.encode(address(assemblyCore), address(assemblyMembership), 150000, 2000000)
                ))
        );
        StreamFinalityCoordinatorPolicyReads.Dependencies memory entropyDependencies;
        entropyDependencies.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyMembership),
            address(assemblyCoordinators)
        ];
        for (uint256 i; i < 4; ++i) {
            entropyDependencies.codeHashes[i] = entropyDependencies.targets[i].codehash;
        }
        entropyDependencies.chainId = block.chainid;
        entropyDependencies.readGas = 150000;
        entropyDependencies.inventoryGas = 3000000;
        assemblyEntropyFactory = StreamFinalityEntropySourceFactory(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamFinalityEntropySourceFactory,
                    abi.encode(entropyDependencies)
                ))
        );
        assemblyContentCheckpoint = StreamOnchainContentCheckpoint(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamOnchainContentCheckpoint,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyRouter),
                        address(assemblyTokens),
                        address(assemblyExecutor),
                        _gas("CONTENT_CHECKPOINT_READ_GAS", 500000, 50000, 1),
                        _gas("CONTENT_CHECKPOINT_RENDER_GAS", 3000000, 50000, 1)
                    )
                ))
        );
        assemblyArtifact = StreamFinalityArtifactCoverage(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamFinalityArtifactCoverage,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyArchive),
                        address(assemblySchemas),
                        address(assemblyStore),
                        assemblyLate[uint256(Late.REGISTRY)],
                        address(assemblyExecutor),
                        _gas("FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 500000, 300000, 2)
                    )
                ))
        );
        assemblyLeaves = StreamContentLeafManifest(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamContentLeafManifest,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyContentCheckpoint),
                        address(assemblyArtifact),
                        address(assemblyExecutor),
                        _gas("CONTENT_LEAF_MANIFEST_READ_GAS", 1000000, 50000, 2)
                    )
                ))
        );
        StreamArchivalTypes.Observer[] memory observers = assemblyCheckpointVerifier.observers();
        assemblyObjectVerifier = StreamArweaveObjectCheckpointVerifier(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamArweaveObjectCheckpointVerifier,
                    abi.encode(
                        address(assemblyExecutor),
                        observers,
                        2,
                        _gas("ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2)
                    )
                ))
        );
        assemblyExternal = StreamExternalArtifactCoverage(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamExternalArtifactCoverage,
                    abi.encode(
                        address(assemblyCore),
                        address(assemblyExecutor),
                        address(assemblyRoles),
                        address(assemblyObjectVerifier),
                        _gas("EXTERNAL_ARCHIVE_READ_GAS", 500000, 150000, 2),
                        _gas("EXTERNAL_ARCHIVE_SIGNATURE_GAS", 400000, 90000, 2)
                    )
                ))
        );
        _installAssemblyMetadataPointers();
        StreamSnapshotTypes.Dependencies memory d;
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            address(assemblyLeaves),
            address(assemblyContentCheckpoint),
            address(assemblyMembership),
            address(assemblyCoordinators)
        ];
        for (uint256 i; i < 9; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 2000000;
        d.evidenceGas = 2000000;
        d.inventoryGas = 3000000;
        IStreamGasParameterHost.GasParameterConfig[4] memory configs;
        configs[0] = _gas("SNAPSHOT_READ_GAS", d.readGas, 50000, 1);
        configs[1] = _gas("SNAPSHOT_SOURCE_GAS", d.sourceGas, 50000, 1);
        configs[2] = _gas("SNAPSHOT_EVIDENCE_GAS", d.evidenceGas, 50000, 1);
        configs[3] = _gas("SNAPSHOT_INVENTORY_GAS", d.inventoryGas, 50000, 1);
        assemblySnapshots = StreamCollectionSnapshots(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamCollectionSnapshots,
                    abi.encode(d, address(assemblyExecutor), configs)
                ))
        );
        _deployAssemblyReference(rendererCatalog);
    }

    function _deployAssemblyReference(bytes memory catalog) private {
        // The caller derives these exact catalog bytes from the configured original renderer.
        // They are admitted by schema governance before publication, without placeholder data.
        require(catalog.length != 0, "actual renderer catalog bytes");
        StreamReferenceRenderTypes.Dependencies memory d;
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            address(assemblySnapshots),
            address(assemblyExternal)
        ];
        for (uint256 i; i < 7; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.rendererCatalogId = keccak256("STREAM_REFERENCE_RENDERER_CLASS_FIXTURE_V1");
        d.rendererCatalogHash = keccak256(catalog);
        d.rendererCatalogBytes = uint32(catalog.length);
        d.readGas = 500000;
        d.sourceGas = 4000000;
        d.snapshotGas = 6000000;
        d.archiveGas = 2000000;
        IStreamGasParameterHost.GasParameterConfig[4] memory configs;
        configs[0] = _gas("REFERENCE_READ_GAS", d.readGas, 50000, 1);
        configs[1] = _gas("REFERENCE_SOURCE_GAS", d.sourceGas, 50000, 1);
        configs[2] = _gas("REFERENCE_SNAPSHOT_GAS", d.snapshotGas, 50000, 1);
        configs[3] = _gas("REFERENCE_ARCHIVE_GAS", d.archiveGas, 50000, 1);
        assemblyReference = StreamReferenceRenderPublication(
            payable(_assemblyCreate(
                    StreamNativeAssemblyCreation.Kind.StreamReferenceRenderPublication,
                    abi.encode(d, address(assemblyExecutor), configs)
                ))
        );
    }

    function _installAssemblyMetadataPointers() private {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](2);
        records[0] = _assemblyModule(
            address(assemblyRouter),
            keccak256("METADATA_ROUTER"),
            type(IStreamMetadataRouter).interfaceId,
            keccak256("native assembly router")
        );
        records[1] = _assemblyModule(
            address(assemblyMetadata),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId,
            keccak256("native assembly metadata")
        );
        GenesisBatch memory batch;
        batch.actionClass = 1;
        (batch.calls, batch.callDatas) =
            StreamCurrentStackPlan.registrationCalls(assemblyModules, records);
        _admitAssemblyBatch(batch);
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/metadata-registration"
        );
        bytes32[] memory pointerTypes = new bytes32[](2);
        pointerTypes[0] = keccak256("METADATA_ROUTER");
        pointerTypes[1] = keccak256("COLLECTION_METADATA");
        (GovernanceCall[] memory calls, bytes[] memory data) = StreamCurrentStackPlan.pointerCalls(
            assemblyCore, assemblyModules, pointerTypes, records
        );
        batch.actionClass = 3;
        batch.calls = new GovernanceCall[](3);
        batch.callDatas = new bytes[](3);
        for (uint256 i; i < 2; ++i) {
            batch.calls[i] = calls[i];
            batch.callDatas[i] = data[i];
        }
        StreamSystemManifest.ModuleAddresses memory modules =
        StreamGenesisManifestPlan.readAggregate(assemblyManifest).modules;
        modules.metadataRouter = address(assemblyRouter);
        modules.collectionMetadata = address(assemblyMetadata);
        (batch.calls[2], batch.callDatas[2]) =
            _assemblyPublication(modules, keccak256(abi.encode(records)));
        _admitAssemblyBatch(batch);
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/metadata-selection"
        );
    }

    function _assemblyModule(
        address module,
        bytes32 moduleType,
        bytes4 interfaceId,
        bytes32 moduleHash
    ) private view returns (StreamModuleRegistration memory) {
        return StreamModuleRegistration(
            module,
            moduleType,
            IStreamModule(module).streamModuleVersion(),
            interfaceId,
            500000,
            module.codehash,
            ASSEMBLY_DEPLOYMENT,
            moduleHash,
            "https://fixtures.example.invalid/native-assembly/module"
        );
    }

    function _admitAssemblyBatch(GenesisBatch memory batch) internal {
        GovernanceActionPolicyEntry[] memory rows =
            new GovernanceActionPolicyEntry[](batch.calls.length);
        uint256 count;
        for (uint256 i; i < batch.calls.length; ++i) {
            GovernanceCall memory c = batch.calls[i];
            GovernanceActionPolicyEntry memory row = GovernanceActionPolicyEntry(
                batch.actionClass,
                c.target,
                c.selector,
                c.target.codehash,
                keccak256(abi.encode(ASSEMBLY_DEPLOYMENT, c.target)),
                1,
                0,
                0,
                0
            );
            bool duplicate;
            for (uint256 j; j < count; ++j) {
                if (_policyKey(row) == _policyKey(rows[j])) duplicate = true;
            }
            if (!duplicate) rows[count++] = row;
        }
        GovernanceActionPolicyEntry[] memory unique = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) {
            unique[i] = rows[i];
        }
        _admitAssemblyPolicies(unique);
    }

    function _predictAssemblyLateRuntimes() internal {
        RuntimeValue[] memory v = new RuntimeValue[](15);
        string memory base = "StreamFinalityRouterEvidenceProvider";
        v[0] = _finalityValue(base, "core", _addressWord(address(assemblyCore)));
        v[1] = _finalityValue(base, "coreCodeHash", address(assemblyCore).codehash);
        v[2] = _finalityValue(base, "metadataHost", _addressWord(address(assemblyMetadata)));
        v[3] = _finalityValue(base, "metadataHostCodeHash", address(assemblyMetadata).codehash);
        v[4] = _finalityValue(base, "metadataRouter", _addressWord(address(assemblyRouter)));
        v[5] = _finalityValue(base, "metadataRouterCodeHash", address(assemblyRouter).codehash);
        v[6] =
            _finalityValue(base, "scopeMembershipHost", _addressWord(address(assemblyMembership)));
        v[7] = _finalityValue(
            base, "scopeMembershipHostCodeHash", address(assemblyMembership).codehash
        );
        v[8] = _finalityValue(base, "deploymentChainId", bytes32(block.chainid));
        v[9] = _finalityValue(base, "readGas", bytes32(uint256(500000)));
        v[10] = _finalityValue(base, "sourceGas", bytes32(uint256(4000000)));
        v[11] = _finalityValue(base, "routerModuleVersion", assemblyRouter.streamModuleVersion());
        (, bytes32 routerManifest) = assemblyRouter.streamModuleManifest();
        (, bytes32 metadataManifest) = assemblyMetadata.streamModuleManifest();
        v[12] = _finalityValue(base, "routerModuleManifestHash", routerManifest);
        v[13] = _finalityValue(
            "StreamFinalityNativeEvidenceProvider",
            "metadataModuleVersion",
            assemblyMetadata.streamModuleVersion()
        );
        v[14] = _finalityValue(
            "StreamFinalityNativeEvidenceProvider", "metadataModuleManifestHash", metadataManifest
        );
        string[] memory parents = new string[](1);
        parents[0] = base;
        assemblyRuntimes[uint256(Late.PROVIDER)] = _productRuntime(
            "StreamFinalityNativeEvidenceProvider",
            parents,
            StreamNativeAssemblyCreation.creation(
                StreamNativeAssemblyCreation.Kind.StreamFinalityNativeEvidenceProvider
            ),
            v
        );
        v = new RuntimeValue[](6);
        base = "StreamCoreFinalityAdapter";
        v[0] = _finalityValue(base, "core", _addressWord(address(assemblyCore)));
        v[1] = _finalityValue(base, "collectionMetadata", _addressWord(address(assemblyMetadata)));
        v[2] = _finalityValue(
            base, "evidenceProvider", _addressWord(assemblyLate[uint256(Late.PROVIDER)])
        );
        v[3] = _finalityValue(base, "_coreCodeHash", address(assemblyCore).codehash);
        v[4] = _finalityValue(base, "_metadataCodeHash", address(assemblyMetadata).codehash);
        v[5] = _finalityValue(
            base, "_providerCodeHash", keccak256(assemblyRuntimes[uint256(Late.PROVIDER)])
        );
        assemblyRuntimes[uint256(Late.CORE_ADAPTER)] = _productRuntime(
            base,
            new string[](0),
            StreamNativeAssemblyCreation.creation(
                StreamNativeAssemblyCreation.Kind.StreamCoreFinalityAdapter
            ),
            v
        );
        base = "StreamFinalityCurrentDiscovery";
        v = new RuntimeValue[](4);
        v[0] = _finalityValue(base, "core", _addressWord(address(assemblyCore)));
        v[1] = _finalityValue(base, "metadataHost", _addressWord(address(assemblyMetadata)));
        v[2] = _finalityValue(
            base, "scopeEvidenceProvider", _addressWord(assemblyLate[uint256(Late.PROVIDER)])
        );
        v[3] = _finalityValue(base, "deploymentChainId", bytes32(block.chainid));
        assemblyRuntimes[uint256(Late.DISCOVERY)] = _productRuntime(
            base,
            new string[](0),
            StreamNativeAssemblyCreation.creation(
                StreamNativeAssemblyCreation.Kind.StreamFinalityCurrentDiscovery
            ),
            v
        );
        _predictAssemblyRegistryRuntime();
        _predictAssemblyCoordinatorRuntime();
        assemblyRuntimes[uint256(Late.WORK)] = _selectorRuntime(
            "StreamWorkRecordSelection",
            StreamNativeAssemblyCreation.creation(
                StreamNativeAssemblyCreation.Kind.StreamWorkRecordSelection
            )
        );
        assemblyRuntimes[uint256(Late.RIGHTS)] = _selectorRuntime(
            "StreamRightsRecordSelection",
            StreamNativeAssemblyCreation.creation(
                StreamNativeAssemblyCreation.Kind.StreamRightsRecordSelection
            )
        );
        assemblyRuntimes[uint256(Late.CONSERVATION)] = _selectorRuntime(
            "StreamConservationRecordSelection",
            StreamNativeAssemblyCreation.creation(
                StreamNativeAssemblyCreation.Kind.StreamConservationRecordSelection
            )
        );
        assemblyRuntimes[uint256(Late.INVENTORY)] = _productRuntime(
            "StreamRenderCriticalInventory",
            new string[](0),
            StreamNativeAssemblyCreation.creation(
                StreamNativeAssemblyCreation.Kind.StreamRenderCriticalInventory
            ),
            new RuntimeValue[](0)
        );
        assemblyRuntimes[uint256(Late.BUNDLE)] = _productRuntime(
            "StreamBundleArchiveCoverage",
            new string[](0),
            StreamNativeAssemblyCreation.creation(
                StreamNativeAssemblyCreation.Kind.StreamBundleArchiveCoverage
            ),
            new RuntimeValue[](0)
        );
    }

    function _predictAssemblyRegistryRuntime() private {
        string memory name = "StreamArtworkFinalityRegistry";
        RuntimeValue[] memory v = new RuntimeValue[](21);
        v[0] = _finalityValue(name, "coreReads", _addressWord(address(assemblyCore)));
        v[1] = _finalityValue(
            name, "coreFinalityAdapter", _addressWord(assemblyLate[uint256(Late.CORE_ADAPTER)])
        );
        v[2] = _finalityValue(name, "metadataReads", _addressWord(address(assemblyMetadata)));
        v[3] = _finalityValue(
            name, "scopeEvidenceProvider", _addressWord(assemblyLate[uint256(Late.PROVIDER)])
        );
        v[4] = _finalityValue(name, "artifactCoverage", _addressWord(address(assemblyArtifact)));
        v[5] = _finalityValue(name, "_artifactCodeHash", address(assemblyArtifact).codehash);
        v[6] = _finalityValue(name, "sanctionReads", _addressWord(address(assemblyArtists)));
        v[7] = _finalityValue(name, "finalityRoleRegistry", _addressWord(address(assemblyRoles)));
        v[8] = _finalityValue(name, "_executorCodeHash", address(assemblyExecutor).codehash);
        v[9] = _finalityValue(name, "_rolesCodeHash", address(assemblyRoles).codehash);
        v[10] = _finalityValue(name, "_coreCodeHash", address(assemblyCore).codehash);
        v[11] = _finalityValue(name, "_metadataCodeHash", address(assemblyMetadata).codehash);
        v[12] = _finalityValue(
            name, "_providerCodeHash", keccak256(assemblyRuntimes[uint256(Late.PROVIDER)])
        );
        v[13] = _finalityValue(
            name, "_adapterCodeHash", keccak256(assemblyRuntimes[uint256(Late.CORE_ADAPTER)])
        );
        v[14] = _finalityValue(
            name, "_discoveryCodeHash", keccak256(assemblyRuntimes[uint256(Late.DISCOVERY)])
        );
        v[15] = _finalityValue(
            name, "finalityDiscovery", _addressWord(assemblyLate[uint256(Late.DISCOVERY)])
        );
        v[16] = _runtimeValue(
            "parameters",
            "StreamGasParameterHost",
            "governanceAuthority",
            _addressWord(address(assemblyExecutor))
        );
        v[17] = _runtimeValue(
            "modules",
            "StreamModuleBase",
            "_schemaHash",
            keccak256("6529stream.canonical-artwork-finality.schema.v1")
        );
        v[18] = _runtimeValue("modules", "StreamModuleBase", "_supersedes", 0);
        v[19] = _runtimeValue(
            "modules", "StreamModuleBase", "_deploymentManifestHash", ASSEMBLY_DEPLOYMENT
        );
        v[20] = _runtimeValue(
            "modules", "StreamModuleBase", "_manifestHash", keccak256("native assembly finality")
        );
        string[] memory parents = new string[](2);
        parents[0] = "StreamGasParameterHost";
        parents[1] = "StreamModuleBase";
        assemblyRuntimes[uint256(Late.REGISTRY)] = _productRuntime(
            name,
            parents,
            StreamNativeAssemblyCreation.creation(
                StreamNativeAssemblyCreation.Kind.StreamArtworkFinalityRegistry
            ),
            v
        );
    }

    function _predictAssemblyCoordinatorRuntime() private {
        string memory name = "StreamArtistOnboardingCoordinator";
        RuntimeValue[] memory v = new RuntimeValue[](7);
        v[0] = _runtimeValue("artist", name, "deploymentChainId", bytes32(block.chainid));
        v[1] = _runtimeValue(
            "artist", name, "configurationHash", _assemblyCoordinatorConfigurationHash()
        );
        v[2] = _runtimeValue(
            "artist",
            name,
            "reads",
            _addressWord(assemblyVm.computeCreateAddress(assemblyCoordinatorAddress, 1))
        );
        v[3] = _runtimeValue(
            "artist", name, "finalityRegistry", _addressWord(assemblyLate[uint256(Late.REGISTRY)])
        );
        v[4] = _runtimeValue(
            "artist",
            name,
            "finalityRegistryCodeHash",
            keccak256(assemblyRuntimes[uint256(Late.REGISTRY)])
        );
        v[5] = _runtimeValue(
            "artist",
            name,
            "finalityEvidenceProvider",
            _addressWord(assemblyLate[uint256(Late.PROVIDER)])
        );
        v[6] = _runtimeValue(
            "artist",
            name,
            "finalityEvidenceProviderCodeHash",
            keccak256(assemblyRuntimes[uint256(Late.PROVIDER)])
        );
        assemblyCoordinatorRuntime = _productRuntime(
            name,
            new string[](0),
            StreamNativeAssemblyCreation.creation(
                StreamNativeAssemblyCreation.Kind.StreamArtistOnboardingCoordinator
            ),
            v
        );
    }

    function _assemblyCoordinatorConfigurationHash() private view returns (bytes32) {
        T.SuiteConfiguration memory suite = assemblySuite;
        bytes32[16] memory hashes;
        for (uint256 i; i < 7; ++i) {
            hashes[i] = suite.owners[i].codehash;
        }
        address[9] memory tail = [
            suite.registry,
            suite.archive,
            suite.core,
            suite.mintManager,
            suite.roleRegistry,
            suite.metadata,
            suite.primaryResolver,
            suite.royaltyResolver,
            suite.validator
        ];
        for (uint256 i; i < 9; ++i) {
            hashes[i + 7] = tail[i].codehash;
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_CONFIGURATION_V1"),
                block.chainid,
                assemblyCoordinatorAddress,
                suite,
                hashes,
                assemblyLate[uint256(Late.REGISTRY)],
                keccak256(assemblyRuntimes[uint256(Late.REGISTRY)]),
                assemblyLate[uint256(Late.PROVIDER)],
                keccak256(assemblyRuntimes[uint256(Late.PROVIDER)]),
                uint16(1),
                uint16(2),
                uint16(3),
                uint16(4),
                uint16(5),
                uint16(6),
                uint16(7),
                uint16(12),
                uint16(13),
                uint16(14),
                uint16(15),
                uint16(16),
                uint16(17),
                uint16(18),
                uint16(20),
                uint16(21),
                uint16(22),
                uint16(23),
                uint16(24),
                uint16(25),
                uint16(26),
                uint16(27),
                uint16(28),
                uint16(29),
                uint16(30),
                uint16(31),
                uint16(32),
                uint16(33),
                uint16(34),
                uint16(35),
                uint16(36),
                uint16(37),
                uint16(38),
                uint16(39),
                uint16(40),
                uint16(51),
                uint16(52),
                uint16(54),
                uint16(58),
                uint16(65534),
                keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_SUPERSESSION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_HEAD_SELECTION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_ROOT_APPEAL_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_FIRST_ESTATE_RECOVERY_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_ESTATE_SUCCESSOR_GUARDIAN_RECOVERY_PROFILE_V1")
            )
        );
    }

    function _selectorRuntime(string memory name, bytes memory creation)
        private
        view
        returns (bytes memory)
    {
        RuntimeValue[] memory v = new RuntimeValue[](9);
        v[0] = _runtimeValue("metadata", name, "core", _addressWord(address(assemblyCore)));
        v[1] = _runtimeValue("metadata", name, "metadata", _addressWord(address(assemblyMetadata)));
        v[2] = _runtimeValue(
            "metadata", name, "schemaRegistry", _addressWord(address(assemblySchemas))
        );
        v[3] = _runtimeValue("metadata", name, "chunkStore", _addressWord(address(assemblyStore)));
        v[4] = _runtimeValue("metadata", name, "deploymentChainId", bytes32(block.chainid));
        v[5] = _runtimeValue("metadata", name, "coreCodeHash", address(assemblyCore).codehash);
        v[6] =
            _runtimeValue("metadata", name, "metadataCodeHash", address(assemblyMetadata).codehash);
        v[7] = _runtimeValue(
            "metadata", name, "schemaRegistryCodeHash", address(assemblySchemas).codehash
        );
        v[8] =
            _runtimeValue("metadata", name, "chunkStoreCodeHash", address(assemblyStore).codehash);
        return _productRuntime(name, new string[](0), creation, v);
    }

    function _productRuntime(
        string memory name,
        string[] memory parents,
        bytes memory creation,
        RuntimeValue[] memory values
    ) private view returns (bytes memory) {
        string[] memory declarations = new string[](parents.length + 1);
        declarations[0] = _artifact(name);
        for (uint256 i; i < parents.length; ++i) {
            declarations[i + 1] = _artifact(parents[i]);
        }
        return _runtime(declarations[0], declarations, creation, values);
    }

    function _artifact(string memory name) internal pure returns (string memory) {
        return string.concat("artifacts/native-assembly/compiled/", name, ".json");
    }

    function _finalityValue(string memory name, string memory variable, bytes32 value)
        private
        pure
        returns (RuntimeValue memory)
    {
        return _runtimeValue("finality", name, variable, value);
    }

    function _runtimeValue(
        string memory domain,
        string memory name,
        string memory variable,
        bytes32 value
    ) private pure returns (RuntimeValue memory) {
        return RuntimeValue(
            string.concat("smart-contracts/domains/", domain, "/", name, ".sol"),
            name,
            variable,
            value
        );
    }

    function _addressWord(address value) private pure returns (bytes32) {
        return bytes32(uint256(uint160(value)));
    }

    function _assemblyInventoryDependencies()
        internal
        view
        returns (StreamRenderCriticalSourceTypes.Dependencies memory d)
    {
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            address(assemblySnapshots),
            address(assemblyReference),
            assemblyLate[uint256(Late.WORK)],
            assemblyLate[uint256(Late.RIGHTS)],
            assemblyLate[uint256(Late.CONSERVATION)],
            address(assemblyArtifact),
            address(assemblyExternal)
        ];
        for (uint256 i; i < 12; ++i) {
            d.codeHashes[i] = _assemblyKnownCodeHash(d.targets[i]);
        }
        d.artistTargets = [
            address(assemblyArtists),
            assemblyCoordinatorAddress,
            assemblySuite.owners[2],
            assemblySuite.owners[4],
            assemblySuite.archive
        ];
        for (uint256 i; i < 5; ++i) {
            d.artistCodeHashes[i] = _assemblyKnownCodeHash(d.artistTargets[i]);
        }
        d.artistContentOwner = assemblySuite.owners[6];
        d.artistContentOwnerCodeHash = d.artistContentOwner.codehash;
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.sourceGas = 4000000;
        d.selectionGas = 4000000;
        d.snapshotGas = 6000000;
        d.referenceGas = 12000000;
    }

    function _assemblyKnownCodeHash(address target) private view returns (bytes32 hash) {
        require(target != address(0), "no zero assembly dependency");
        if (target == assemblyCoordinatorAddress) {
            require(assemblyCoordinatorRuntime.length != 0, "Coordinator runtime already derived");
            hash = keccak256(assemblyCoordinatorRuntime);
        } else {
            for (uint256 i; i < 9; ++i) {
                if (assemblyLate[i] != target) continue;
                require(assemblyRuntimes[i].length != 0, "late runtime already derived");
                hash = keccak256(assemblyRuntimes[i]);
                break;
            }
        }
        if (hash == 0) {
            require(target.code.length != 0, "early dependency is deployed");
            hash = target.codehash;
        } else if (target.code.length != 0) {
            require(target.codehash == hash, "deployed dependency equals prediction");
        }
    }

    function _assemblyProviderConfiguration()
        private
        view
        returns (StreamFinalityNativeProviderReads.Config memory c)
    {
        c.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyRouter),
            address(assemblyMembership),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyLeaves),
            address(assemblyContentCheckpoint),
            address(assemblySnapshots),
            address(assemblyReference),
            address(assemblyEntropyFactory),
            address(assemblyArtists),
            assemblyLate[uint256(Late.REGISTRY)],
            assemblyLate[uint256(Late.DISCOVERY)],
            assemblyLate[uint256(Late.CORE_ADAPTER)],
            assemblyLate[uint256(Late.WORK)],
            assemblyLate[uint256(Late.RIGHTS)],
            assemblyLate[uint256(Late.CONSERVATION)],
            assemblyLate[uint256(Late.INVENTORY)],
            assemblyLate[uint256(Late.BUNDLE)],
            address(assemblyArtifact),
            address(assemblyExternal)
        ];
        for (uint256 i; i < 22; ++i) {
            c.codeHashes[i] = _assemblyKnownCodeHash(c.targets[i]);
        }
        c.chainId = block.chainid;
        c.readGas = 500000;
        c.sourceGas = 16000000;
        c.componentSourceGas = 4000000;
        c.inventoryDependencyHash = keccak256(abi.encode(_assemblyInventoryDependencies()));
    }

    function _deployAssemblyFinalityGraph() internal {
        _predictAssemblyLateRuntimes();
        StreamFinalityNativeProviderReads.Config memory c = _assemblyProviderConfiguration();
        assemblyProvider = StreamFinalityNativeEvidenceProvider(
            _deployAssemblyLate(
                Late.PROVIDER,
                StreamNativeAssemblyCreation.creation(
                    StreamNativeAssemblyCreation.Kind.StreamFinalityNativeEvidenceProvider
                ),
                abi.encode(c)
            )
        );
        assemblyCoreAdapter = StreamCoreFinalityAdapter(
            _deployAssemblyLate(
                Late.CORE_ADAPTER,
                StreamNativeAssemblyCreation.creation(
                    StreamNativeAssemblyCreation.Kind.StreamCoreFinalityAdapter
                ),
                abi.encode(
                    address(assemblyCore), address(assemblyMetadata), address(assemblyProvider)
                )
            )
        );
        bytes32[6] memory families = [
            StreamFinalityDomains.COMPONENT_METADATA_ROUTER,
            StreamFinalityDomains.COMPONENT_RENDERER,
            StreamFinalityDomains.COMPONENT_RENDER_CONTEXT,
            StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST,
            StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE,
            StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE
        ];
        for (uint256 i; i < 6; ++i) {
            assemblyRouterAdapters[i] = address(
                StreamFinalityServingHostAdapter(
                    payable(_assemblyCreate(
                            StreamNativeAssemblyCreation.Kind.StreamFinalityServingHostAdapter,
                            abi.encode(
                                address(assemblyCore),
                                address(assemblyRouter),
                                address(assemblyProvider),
                                families[i]
                            )
                        ))
                )
            );
        }
        assemblyMetadataAdapter = address(
            StreamFinalityServingHostAdapter(
                payable(_assemblyCreate(
                        StreamNativeAssemblyCreation.Kind.StreamFinalityServingHostAdapter,
                        abi.encode(
                            address(assemblyCore),
                            address(assemblyMetadata),
                            address(assemblyProvider),
                            StreamFinalityDomains.COMPONENT_COLLECTION_METADATA
                        )
                    ))
            )
        );
        StreamFinalityDiscoveryTypes.Configuration memory d;
        d.core = address(assemblyCore);
        d.metadata = address(assemblyMetadata);
        d.router = address(assemblyRouter);
        d.provider = address(assemblyProvider);
        d.membership = address(assemblyMembership);
        d.entropyFactory = address(assemblyEntropyFactory);
        d.metadataAdapter = assemblyMetadataAdapter;
        d.referenceRender = address(assemblyReference);
        d.artist = address(assemblyArtists);
        d.finalityRegistry = assemblyLate[uint256(Late.REGISTRY)];
        d.finalityRegistryCodeHash = keccak256(assemblyRuntimes[uint256(Late.REGISTRY)]);
        d.routerAdapters = assemblyRouterAdapters;
        d.readGas = 500000;
        d.componentGas = 12000000;
        d.entropyGas = 8000000;
        assemblyDiscovery = StreamFinalityCurrentDiscovery(
            _deployAssemblyLate(
                Late.DISCOVERY,
                StreamNativeAssemblyCreation.creation(
                    StreamNativeAssemblyCreation.Kind.StreamFinalityCurrentDiscovery
                ),
                abi.encode(d)
            )
        );
        StreamFinalityDeploymentConfiguration memory deployment =
            StreamFinalityDeploymentConfiguration(
                address(assemblyArtifact),
                ASSEMBLY_DEPLOYMENT,
                "https://fixtures.example.invalid/native-assembly/finality",
                keccak256("native assembly finality")
            );
        assemblyFinality = StreamArtworkFinalityRegistry(
            _deployAssemblyLate(
                Late.REGISTRY,
                StreamNativeAssemblyCreation.creation(
                    StreamNativeAssemblyCreation.Kind.StreamArtworkFinalityRegistry
                ),
                abi.encode(
                    address(assemblyCore),
                    address(assemblyMetadata),
                    address(assemblyCoreAdapter),
                    address(assemblyArtists),
                    address(assemblyExecutor),
                    address(assemblyDiscovery),
                    _gas("FINALITY_COMPONENT_READ_GAS", 30000000, 50000, 2),
                    deployment
                )
            )
        );
        assemblyCoordinator = StreamArtistOnboardingCoordinator(
            _deploySlot(
                assemblyCoordinatorSlot,
                assemblyCoordinatorAddress,
                StreamNativeAssemblyCreation.creation(
                    StreamNativeAssemblyCreation.Kind.StreamArtistOnboardingCoordinator
                ),
                abi.encode(assemblySuite, address(assemblyFinality)),
                assemblyCoordinatorRuntime
            )
        );
        require(
            assemblyVm.getNonce(assemblyCoordinatorAddress) == 2,
            "one original Coordinator reader CREATE"
        );
        require(
            address(assemblyCoordinator.reads())
                == assemblyVm.computeCreateAddress(assemblyCoordinatorAddress, 1),
            "actual original reader address"
        );
        _installAssemblyArtistPointer();
        bytes memory selectorArgs =
            abi.encode(address(assemblyCore), address(assemblyMetadata), address(assemblySchemas));
        assemblyWork = StreamWorkRecordSelection(
            _deployAssemblyLate(
                Late.WORK,
                StreamNativeAssemblyCreation.creation(
                    StreamNativeAssemblyCreation.Kind.StreamWorkRecordSelection
                ),
                selectorArgs
            )
        );
        assemblyRights = StreamRightsRecordSelection(
            _deployAssemblyLate(
                Late.RIGHTS,
                StreamNativeAssemblyCreation.creation(
                    StreamNativeAssemblyCreation.Kind.StreamRightsRecordSelection
                ),
                selectorArgs
            )
        );
        assemblyConservation = StreamConservationRecordSelection(
            _deployAssemblyLate(
                Late.CONSERVATION,
                StreamNativeAssemblyCreation.creation(
                    StreamNativeAssemblyCreation.Kind.StreamConservationRecordSelection
                ),
                selectorArgs
            )
        );
        assemblyInventory = StreamRenderCriticalInventory(
            _deployAssemblyLate(
                Late.INVENTORY,
                StreamNativeAssemblyCreation.creation(
                    StreamNativeAssemblyCreation.Kind.StreamRenderCriticalInventory
                ),
                abi.encode(_assemblyInventoryDependencies())
            )
        );
        StreamBundleArchiveTypes.Dependencies memory b;
        b.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyInventory),
            address(assemblyArtifact),
            address(assemblyExternal),
            assemblySuite.archive
        ];
        for (uint256 i; i < 6; ++i) {
            b.codeHashes[i] = b.targets[i].codehash;
        }
        b.chainId = block.chainid;
        b.readGas = 500000;
        b.archiveGas = 2000000;
        assemblyBundle = StreamBundleArchiveCoverage(
            _deployAssemblyLate(
                Late.BUNDLE,
                StreamNativeAssemblyCreation.creation(
                    StreamNativeAssemblyCreation.Kind.StreamBundleArchiveCoverage
                ),
                abi.encode(b)
            )
        );
        require(
            assemblyInventory.dependencyHash() == c.inventoryDependencyHash,
            "same exact inventory configuration before and after actual CREATE"
        );
        require(
            keccak256(abi.encode(c))
                == keccak256(abi.encode(assemblyProvider.nativeConfiguration())),
            "unchanged complete provider constructor pins"
        );
        for (uint256 i; i < 22; ++i) {
            require(
                c.targets[i].code.length != 0 && c.targets[i].code.length <= 24576
                    && c.targets[i].codehash == c.codeHashes[i],
                "all actual provider dependencies deployed and fit"
            );
        }
    }

    // The linked fixture library retains literal production creation templates separately,
    // so changing orchestration does not regenerate the entire embedded deployment graph.
    // CREATE still executes here with the same host, value, constructor ABI and nonce order.
    mapping(StreamNativeAssemblyCreation.Kind => bool) private assemblyVerifiedTemplates;

    function _assemblyCreate(StreamNativeAssemblyCreation.Kind kind, bytes memory args)
        private
        returns (address product)
    {
        bytes memory creation = StreamNativeAssemblyCreation.creation(kind);
        if (!assemblyVerifiedTemplates[kind]) {
            _linkRuntime(
                assemblyVm.readFile(_artifact(StreamNativeAssemblyCreation.name(kind))), creation
            );
            assemblyVerifiedTemplates[kind] = true;
        }
        bytes memory initcode = bytes.concat(creation, args);
        require(initcode.length <= 49152, "actual original product initcode fits");
        assembly ("memory-safe") {
            product := create(0, add(initcode, 32), mload(initcode))
            if iszero(product) {
                let errorData := mload(0x40)
                returndatacopy(errorData, 0, returndatasize())
                revert(errorData, returndatasize())
            }
        }
        require(
            product.code.length != 0 && product.code.length <= 24576,
            "actual original product runtime fits"
        );
    }

    function _deployAssemblyLate(Late id, bytes memory creation, bytes memory args)
        private
        returns (address)
    {
        uint256 index = uint256(id);
        return _deploySlot(
            assemblySlots[index], assemblyLate[index], creation, args, assemblyRuntimes[index]
        );
    }

    // parseJson encodes object members in lexical key order: length, then start.
    struct RuntimeRange {
        uint256 length;
        uint256 start;
    }

    struct RuntimeValue {
        string source;
        string contractName;
        string variable;
        bytes32 value;
    }

    function _slot() internal returns (NativeFinalityAssemblySlot slot, address expected) {
        slot = new NativeFinalityAssemblySlot();
        require(assemblyVm.getNonce(address(slot)) == 1, "fresh CREATE coordinate");
        expected = assemblyVm.computeCreateAddress(address(slot), 1);
    }

    function _deploySlot(
        NativeFinalityAssemblySlot slot,
        address expected,
        bytes memory linkedCreation,
        bytes memory args,
        bytes memory runtime
    ) internal returns (address product) {
        require(assemblyVm.getNonce(address(slot)) == 1, "only first CREATE admitted");
        product = slot.deploy(bytes.concat(linkedCreation, args), expected, keccak256(runtime));
        require(assemblyVm.getNonce(address(slot)) == 2, "one actual product CREATE");
        require(keccak256(product.code) == keccak256(runtime), "full actual runtime bytes");
    }

    function _runtime(
        string memory artifactPath,
        string[] memory declarationArtifacts,
        bytes memory linkedCreation,
        RuntimeValue[] memory values
    ) internal view returns (bytes memory runtime) {
        string memory artifact = assemblyVm.readFile(artifactPath);
        bytes memory patched;
        (runtime, patched) = _linkRuntime(artifact, linkedCreation);
        string[] memory ids =
            assemblyVm.parseJsonKeys(artifact, ".deployedBytecode.immutableReferences");
        string[] memory declarationContents = new string[](declarationArtifacts.length);
        if (ids.length != 0) {
            for (uint256 i; i < declarationArtifacts.length; ++i) {
                declarationContents[i] = _equal(declarationArtifacts[i], artifactPath)
                    ? artifact
                    : assemblyVm.readFile(declarationArtifacts[i]);
            }
        }
        for (uint256 i; i < values.length; ++i) {
            for (uint256 j; j < i; ++j) {
                require(
                    !_equal(values[i].source, values[j].source)
                        || !_equal(values[i].contractName, values[j].contractName)
                        || !_equal(values[i].variable, values[j].variable),
                    "unique constructor value declarations"
                );
            }
        }
        for (uint256 i; i < ids.length; ++i) {
            RuntimeValue memory declaration = _declaration(declarationContents, _decimal(ids[i]));
            bool found;
            bytes32 value;
            for (uint256 j; j < values.length; ++j) {
                if (
                    _equal(values[j].source, declaration.source)
                        && _equal(values[j].contractName, declaration.contractName)
                        && _equal(values[j].variable, declaration.variable)
                ) {
                    require(!found, "duplicate immutable value");
                    found = true;
                    value = values[j].value;
                }
            }
            require(found, "missing constructor-derived immutable");
            RuntimeRange[] memory sites = abi.decode(
                assemblyVm.parseJson(
                    artifact, string.concat('.deployedBytecode.immutableReferences["', ids[i], '"]')
                ),
                (RuntimeRange[])
            );
            require(sites.length != 0, "empty immutable reference");
            for (uint256 j; j < sites.length; ++j) {
                RuntimeRange memory site = sites[j];
                require(site.length == 32 && site.start + 32 <= runtime.length, "immutable range");
                for (uint256 k; k < 32; ++k) {
                    require(patched[site.start + k] == 0, "duplicate or overlapping runtime site");
                    patched[site.start + k] = 0x01;
                    require(runtime[site.start + k] == 0, "unpatched immutable template");
                    runtime[site.start + k] = value[k];
                }
            }
        }
    }

    function _linkRuntime(string memory artifact, bytes memory linkedCreation)
        private
        view
        returns (bytes memory, bytes memory)
    {
        bytes memory creationHex = bytes(assemblyVm.parseJsonString(artifact, ".bytecode.object"));
        bytes memory runtimeHex =
            bytes(assemblyVm.parseJsonString(artifact, ".deployedBytecode.object"));
        bytes memory creationPatched = new bytes(linkedCreation.length);
        uint256 runtimePrefix =
            runtimeHex.length >= 2 && runtimeHex[0] == "0" && runtimeHex[1] == "x" ? 2 : 0;
        bytes memory runtimePatched = new bytes((runtimeHex.length - runtimePrefix) / 2);
        string[] memory sources = assemblyVm.parseJsonKeys(artifact, ".bytecode.linkReferences");
        for (uint256 i; i < sources.length; ++i) {
            string memory sourcePath = string.concat('.bytecode.linkReferences["', sources[i], '"]');
            string[] memory libraries = assemblyVm.parseJsonKeys(artifact, sourcePath);
            for (uint256 j; j < libraries.length; ++j) {
                RuntimeRange[] memory sites = abi.decode(
                    assemblyVm.parseJson(
                        artifact, string.concat(sourcePath, '["', libraries[j], '"]')
                    ),
                    (RuntimeRange[])
                );
                require(
                    sites.length != 0 && sites[0].length == 20
                        && sites[0].start + 20 <= linkedCreation.length,
                    "creation library reference"
                );
                bytes memory addressBytes = new bytes(20);
                for (uint256 k; k < 20; ++k) {
                    addressBytes[k] = linkedCreation[sites[0].start + k];
                }
                address libraryAddress;
                assembly ("memory-safe") { libraryAddress := shr(96, mload(add(addressBytes, 32))) }
                require(
                    libraryAddress.code.length != 0 && libraryAddress.code.length <= 24576,
                    "actual deployable linked library"
                );
                for (uint256 k; k < sites.length; ++k) {
                    require(
                        sites[k].length == 20 && sites[k].start + 20 <= linkedCreation.length,
                        "creation library range"
                    );
                    for (uint256 z; z < 20; ++z) {
                        require(
                            linkedCreation[sites[k].start + z] == addressBytes[z],
                            "consistent actual library links"
                        );
                    }
                    _patchHex(creationHex, sites[k].start, addressBytes, creationPatched);
                }
                string memory runtimePath = string.concat(
                    '.deployedBytecode.linkReferences["', sources[i], '"]["', libraries[j], '"]'
                );
                if (assemblyVm.keyExistsJson(artifact, runtimePath)) {
                    RuntimeRange[] memory runtimeSites =
                        abi.decode(assemblyVm.parseJson(artifact, runtimePath), (RuntimeRange[]));
                    for (uint256 k; k < runtimeSites.length; ++k) {
                        require(runtimeSites[k].length == 20, "runtime library width");
                        _patchHex(runtimeHex, runtimeSites[k].start, addressBytes, runtimePatched);
                    }
                }
            }
        }
        require(
            keccak256(_decodeHex(creationHex)) == keccak256(linkedCreation),
            "exact original linked creation template"
        );
        // Any unaccounted library placeholder fails hex decoding instead of receiving a default.
        return (_decodeHex(runtimeHex), runtimePatched);
    }

    function _declaration(string[] memory artifacts, uint256 id)
        private
        view
        returns (RuntimeValue memory result)
    {
        bool found;
        string memory compilationHash = assemblyVm.parseJsonString(artifacts[0], ".compilationHash");
        for (uint256 i; i < artifacts.length; ++i) {
            string memory artifact = artifacts[i];
            require(
                _equal(compilationHash, assemblyVm.parseJsonString(artifact, ".compilationHash")),
                "same exact native compilation for immutable declarations"
            );
            string memory field = string.concat('.immutableDeclarations["', _uintString(id), '"]');
            if (!assemblyVm.keyExistsJson(artifact, field)) continue;
            require(
                !found && assemblyVm.parseJsonUint(artifact, string.concat(field, ".id")) == id
                    && _equal(
                        compilationHash,
                        assemblyVm.parseJsonString(
                            artifact, string.concat(field, ".compilationHash")
                        )
                    )
                    && _equal(
                        assemblyVm.parseJsonString(artifact, string.concat(field, ".nodeType")),
                        "VariableDeclaration"
                    )
                    && _equal(
                        assemblyVm.parseJsonString(artifact, string.concat(field, ".mutability")),
                        "immutable"
                    ),
                "exact immutable AST declaration"
            );
            found = true;
            result.source = assemblyVm.parseJsonString(artifact, string.concat(field, ".source"));
            result.contractName =
                assemblyVm.parseJsonString(artifact, string.concat(field, ".contractName"));
            result.variable =
                assemblyVm.parseJsonString(artifact, string.concat(field, ".variable"));
        }
        require(found, "unknown immutable AST id");
    }

    function _patchHex(bytes memory text, uint256 offset, bytes memory value, bytes memory patched)
        private
        pure
    {
        uint256 prefix = text.length >= 2 && text[0] == "0" && text[1] == "x" ? 2 : 0;
        require(prefix + 2 * (offset + value.length) <= text.length, "hex patch range");
        bytes16 digits = "0123456789abcdef";
        for (uint256 i; i < value.length; ++i) {
            require(patched[offset + i] == 0, "duplicate or overlapping library site");
            patched[offset + i] = 0x01;
            text[prefix + (offset + i) * 2] = digits[uint8(value[i]) >> 4];
            text[prefix + (offset + i) * 2 + 1] = digits[uint8(value[i]) & 15];
        }
    }

    function _decodeHex(bytes memory text) private pure returns (bytes memory result) {
        uint256 prefix = text.length >= 2 && text[0] == "0" && text[1] == "x" ? 2 : 0;
        require((text.length - prefix) % 2 == 0, "hex length");
        result = new bytes((text.length - prefix) / 2);
        for (uint256 i; i < result.length; ++i) {
            result[i] =
                bytes1(_nibble(text[prefix + i * 2]) * 16 + _nibble(text[prefix + i * 2 + 1]));
        }
    }

    function _nibble(bytes1 c) private pure returns (uint8) {
        uint8 n = uint8(c);
        if (n >= 48 && n <= 57) return n - 48;
        if (n >= 97 && n <= 102) return n - 87;
        if (n >= 65 && n <= 70) return n - 55;
        revert("unlinked or invalid hex");
    }

    function _decimal(string memory text) private pure returns (uint256 value) {
        bytes memory data = bytes(text);
        require(data.length != 0, "empty numeric AST id");
        for (uint256 i; i < data.length; ++i) {
            require(data[i] >= "0" && data[i] <= "9", "invalid numeric AST id");
            value = value * 10 + uint8(data[i]) - 48;
        }
    }

    function _uintString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint256 n = value;
        uint256 length;
        while (n != 0) {
            ++length;
            n /= 10;
        }
        bytes memory result = new bytes(length);
        while (value != 0) {
            result[--length] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(result);
    }

    function _equal(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
    // Class-body fragment. Import StreamExternalArtifactTypes as AxE and
    // StreamArchivalTypes as AxA from interfaces/stream/preservation.
    // These locally signed checkpoint/fixity observations are fixture evidence,
    // not public network publication or independent human retrieval attestations.
    uint256 internal constant AX_OBSERVER_A = 0xE5701;
    uint256 internal constant AX_OBSERVER_B = 0xE5702;
    uint256 internal constant AX_WRITER_A = 0x652983;
    uint256 internal constant AX_WRITER_B = 0x652984;
    uint256 internal constant AX_FIXITY = 0x652985;
    bytes32 internal axFirstFamily;
    bytes32 internal axSecondFamily;
    mapping(bytes32 => bytes32) internal axOriginalCoverage;

    function _assemblySetupExternalFamilies() internal {
        // The actual old-Archive setup already admitted this role. Do not repeat
        // a false-to-true role transition after it has become true.
        require(
            assemblyRoles.hasRole(keccak256("ROLE_FIXITY_OPERATOR"), safeVm.addr(AX_FIXITY)),
            "ax actual fixity role missing"
        );
        require(axFirstFamily == 0 && axSecondFamily == 0, "ax already initialized");
        axFirstFamily = _axAdmitFamily("assembly-external-endowed", true, AX_WRITER_A);
        axSecondFamily = _axAdmitFamily("assembly-external-institution", false, AX_WRITER_B);
    }

    function _axAdmitFamily(string memory name, bool endowed, uint256 key)
        internal
        returns (bytes32 hash)
    {
        bytes memory salt = bytes(endowed ? "assembly-one" : "assembly-two");
        AxA.Family memory f = AxA.Family(
            keccak256(bytes(name)),
            endowed ? assemblyObjectVerifier.networkId() : keccak256("INSTITUTIONAL_ARCHIVE"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256("same jurisdiction allowed"),
            endowed ? 1 : 2,
            safeVm.addr(key),
            endowed ? assemblyObjectVerifier.profileHash() : assemblyExternal.POSSESSION_PROFILE()
        );
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = assemblyExternal.familyRegistrationContext(name, f);
        _assemblyGovernanceCall(
            1,
            address(assemblyExternal),
            abi.encodeCall(assemblyExternal.admitFamily, (name, f)),
            scope,
            oldHash,
            newHash
        );
        (AxA.Family memory saved, uint8 status, uint64 revision) = assemblyExternal.family(hash);
        require(
            status == 1 && revision == 1
                && keccak256(abi.encode(saved)) == keccak256(abi.encode(f)),
            "ax actual family admission"
        );
    }

    function _assemblyCoverExternal(
        AxE.ObjectIdentity memory object,
        bytes memory firstPath,
        bytes memory lastPath,
        bytes memory firstChunk,
        bytes memory lastChunk
    ) internal returns (AxE.Coverage memory result) {
        require(axFirstFamily != 0 && axSecondFamily != 0, "ax families missing");
        require(object.artistId == assemblyArtistId && assemblyArtistId != 0, "ax original artist");
        require(object.byteSize != 0, "ax empty object");
        bytes32 objectHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_EXTERNAL_OBJECT_V1"),
                block.chainid,
                address(assemblyExternal),
                address(assemblyCore),
                object
            )
        );
        bytes32 known = axOriginalCoverage[objectHash];
        if (known != 0) return _axOriginalCurrentCoverage(known, objectHash);
        // Verify endpoint bytes against the exact native leaf intervals. The real
        // verifier below independently verifies every supplied path and its root.
        _axEndpointBytes(firstPath, firstChunk, object.byteSize, 0);
        _axEndpointBytes(lastPath, lastChunk, object.byteSize, object.byteSize - 1);
        if (firstChunk.length == object.byteSize) {
            // Only this one-leaf case has the complete object bytes on this call.
            require(
                keccak256(firstChunk) == object.contentHash
                    && sha256(firstChunk) == object.sha256Digest,
                "ax full small object hashes"
            );
        }
        require(assemblyExternal.recordObject(object) == objectHash, "ax original object hash");
        (bytes32 checkpointHash, bytes32 transactionId) =
            _axCheckpoint(object, objectHash, firstPath, lastPath, firstChunk, lastChunk);
        bytes32 first =
            _axReceipt(objectHash, object.sha256Digest, checkpointHash, transactionId, true);
        bytes32 second =
            _axReceipt(objectHash, object.sha256Digest, checkpointHash, transactionId, false);
        _assemblyExternalFixity(first, 1, bytes32(0));
        _assemblyExternalFixity(second, 1, bytes32(0));
        bytes32 coverageHash = assemblyExternal.recordCoverage(first, second);
        result = assemblyExternal.requireCoverage(coverageHash, assemblyArtistId, objectHash);
        axOriginalCoverage[objectHash] = coverageHash;
    }

    function _axCheckpoint(
        AxE.ObjectIdentity memory object,
        bytes32 objectHash,
        bytes memory firstPath,
        bytes memory lastPath,
        bytes memory firstChunk,
        bytes memory lastChunk
    ) internal returns (bytes32 checkpointHash, bytes32 transactionId) {
        AxA.Checkpoint memory c;
        c.networkId = assemblyObjectVerifier.networkId();
        c.configurationHash = assemblyObjectVerifier.configurationHash();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1;
        c.transactionId =
            keccak256(abi.encode("explicit local assembly external checkpoint", objectHash));
        c.dataRoot = object.arweaveDataRoot;
        c.dataSize = object.byteSize;
        c.transactionRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(c.dataRoot)), sha256(abi.encode(uint256(c.dataSize)))
            )
        );
        c.transactionEnd = c.dataSize;
        c.blockDataSize = c.dataSize;
        c.observedAt = uint64(block.timestamp);
        bytes32 digest = assemblyObjectVerifier.checkpointDigest(c);
        AxA.ObserverProof[] memory proofs = new AxA.ObserverProof[](2);
        proofs[0] = AxA.ObserverProof(safeVm.addr(AX_OBSERVER_A), _axSign(AX_OBSERVER_A, digest));
        proofs[1] = AxA.ObserverProof(safeVm.addr(AX_OBSERVER_B), _axSign(AX_OBSERVER_B, digest));
        if (proofs[0].account > proofs[1].account) (proofs[0], proofs[1]) = (proofs[1], proofs[0]);
        checkpointHash = assemblyObjectVerifier.recordCheckpoint(
            c, abi.encode(c.dataRoot, uint256(c.dataSize)), firstPath, lastPath, proofs
        );
        AxE.NativeFacts memory facts = assemblyObjectVerifier.checkpointFacts(checkpointHash);
        require(
            facts.recordHash == checkpointHash && facts.dataRoot == object.arweaveDataRoot
                && facts.dataSize == object.byteSize && facts.transactionId == c.transactionId
                && facts.firstChunkDigest == sha256(firstChunk)
                && facts.lastChunkDigest == sha256(lastChunk),
            "ax actual native endpoint facts"
        );
        return (checkpointHash, c.transactionId);
    }

    function _axReceipt(
        bytes32 objectHash,
        bytes32 shaDigest,
        bytes32 checkpointHash,
        bytes32 transactionId,
        bool first
    ) internal returns (bytes32) {
        bytes memory locator = first
            ? abi.encodePacked(transactionId)
            : bytes(
                string.concat(
                    "https://institution.example.invalid/objects/sha256/",
                    Strings.toHexString(uint256(shaDigest), 32)
                )
            );
        uint256 key = first ? AX_WRITER_A : AX_WRITER_B;
        AxE.Receipt memory r = AxE.Receipt(
            objectHash,
            first ? axFirstFamily : axSecondFamily,
            keccak256(locator),
            keccak256(bytes(first ? "CONTENT_ADDRESSED_INCLUSION" : "ATTESTED_POSSESSION")),
            first ? assemblyObjectVerifier.profileHash() : assemblyExternal.POSSESSION_PROFILE(),
            first ? checkpointHash : bytes32(0),
            safeVm.addr(key),
            uint64(block.timestamp),
            uint256(objectHash),
            uint64(block.timestamp + 1 days)
        );
        if (!first) r.proofRecordHash = assemblyExternal.possessionHash(r);
        return assemblyExternal.recordReceipt(
            r, locator, _axSign(key, assemblyExternal.receiptDigest(r))
        );
    }

    function _assemblyExternalFixity(bytes32 receiptHash, uint8 outcome, bytes32 repairReport)
        internal
        returns (bytes32)
    {
        (AxE.Receipt memory receipt,,) = assemblyExternal.receipt(receiptHash);
        AxE.ObjectIdentity memory object = assemblyExternal.objectIdentity(receipt.objectHash);
        AxE.Fixity memory f;
        f.receiptHash = receiptHash;
        f.objectHash = receipt.objectHash;
        f.familyRecordHash = receipt.familyRecordHash;
        f.storageIdentifierHash = receipt.storageIdentifierHash;
        f.profileHash = assemblyExternal.FIXITY_PROFILE();
        f.expectedSha256 = object.sha256Digest;
        f.expectedKeccak256 = object.contentHash;
        f.expectedArweaveRoot = object.arweaveDataRoot;
        f.expectedSize = object.byteSize;
        if (outcome == 1) {
            f.observedSha256 = object.sha256Digest;
            f.observedKeccak256 = object.contentHash;
            f.observedArweaveRoot = object.arweaveDataRoot;
            f.observedSize = object.byteSize;
        }
        f.checkedAt = uint64(block.timestamp);
        f.outcome = outcome;
        f.reportHash = keccak256(
            abi.encode(
                "local full retrieval declaration fixture", receiptHash, receipt, object, outcome
            )
        );
        f.previousFixityHash = assemblyExternal.latestFixity(receiptHash);
        f.repairReportHash = repairReport;
        f.verifier = safeVm.addr(AX_FIXITY);
        f.nonce = uint256(f.previousFixityHash);
        f.deadline = uint64(block.timestamp + 1 days);
        return
            assemblyExternal.recordFixity(f, _axSign(AX_FIXITY, assemblyExternal.fixityDigest(f)));
    }

    function _axOriginalCurrentCoverage(bytes32 coverageHash, bytes32 objectHash)
        internal
        view
        returns (AxE.Coverage memory original)
    {
        original = assemblyExternal.coverage(coverageHash);
        require(
            original.coverageHash == coverageHash && original.objectHash == objectHash
                && original.artistId == assemblyArtistId,
            "ax original coverage"
        );
        AxE.CurrentPair memory current = assemblyExternal.currentReceiptPair(
            original.firstReceiptHash,
            original.secondReceiptHash,
            original.artistId,
            original.objectHash
        );
        // Preserve all twelve stable identities. Today's two passing fixity heads
        // gate availability; they never replace the original coverage preimage.
        require(
            current.objectHash == original.objectHash && current.artistId == original.artistId
                && current.contentHash == original.contentHash
                && current.sha256Digest == original.sha256Digest
                && current.arweaveDataRoot == original.arweaveDataRoot
                && current.byteSize == original.byteSize
                && current.firstFamilyRecordHash == original.firstFamilyRecordHash
                && current.secondFamilyRecordHash == original.secondFamilyRecordHash
                && current.firstReceiptHash == original.firstReceiptHash
                && current.secondReceiptHash == original.secondReceiptHash
                && current.checkpointHash == original.checkpointHash
                && current.profileHash == original.profileHash && current.firstFixityHash != 0
                && current.secondFixityHash != 0,
            "ax original pair liveness"
        );
    }

    function _axEndpointBytes(bytes memory path, bytes memory raw, uint256 size, uint256 offset)
        internal
        pure
    {
        require(
            size != 0 && offset < size && path.length >= 64 && path.length <= 6208
                && (path.length - 64) % 96 == 0 && raw.length != 0 && raw.length <= 262144,
            "ax endpoint shape"
        );
        uint256 left;
        uint256 right = size;
        uint256 cursor;
        while (cursor + 64 < path.length) {
            uint256 split = uint256(_axPathWord(path, cursor + 64));
            if (offset < split) {
                if (split < right) {
                    right = split;
                }
            } else {
                if (split > left) {
                    left = split;
                }
            }
            cursor += 96;
        }
        uint256 end = uint256(_axPathWord(path, cursor + 32));
        require(
            left < right && end > left && end <= right && offset >= left && offset < end
                && end - left == raw.length && _axPathWord(path, cursor) == sha256(raw),
            "ax endpoint bytes"
        );
    }

    function _axPathWord(bytes memory data, uint256 at) internal pure returns (bytes32 word) {
        require(at + 32 <= data.length, "ax path word");
        assembly ("memory-safe") { word := mload(add(add(data, 32), at)) }
    }

    function _axSign(uint256 key, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    bytes32 internal assemblyReferenceRecord;
    StreamReferenceRenderTypes.Publication internal assemblyReferencePublication;
    bytes32[3] internal assemblyReferenceFirstReceipts;
    bytes32[3] internal assemblyReferenceSecondReceipts;

    function _assemblyPrepareReferenceDefinitions() internal {
        string[8] memory names = [
            "STREAM_NATIVE_REFERENCE_RENDER_V1",
            "STREAM_NATIVE_REFERENCE_RENDER_JSON_PROFILE_V1",
            "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1",
            "STREAM_REFERENCE_PNG_OBJECT_V1",
            "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1",
            "STREAM_REFERENCE_NATIVE_FORMATS_V1",
            "STREAM_RENDERER_CLASS_DECLARATION_V1",
            "STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1"
        ];
        for (uint256 i; i < names.length; ++i) {
            _assemblyRegisterDocument(
                names[i],
                (i == 1 || i == 5 || i == 7)
                    ? IStreamSchemaRegistry.DocumentKind.CATALOG
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                bytes(assemblyVm.readFile(string.concat("schemas/records/", names[i], ".json"))),
                assemblySchemas.RAW_BYTES()
            );
        }
        bytes memory catalog = _assemblyRendererCatalog();
        StreamReferenceRenderTypes.Dependencies memory d = assemblyReference.dependencies();
        require(
            d.rendererCatalogHash == keccak256(catalog) && d.rendererCatalogBytes == catalog.length,
            "same constructor-pinned original renderer catalog"
        );
        _assemblyRegisterDocument(
            "STREAM_REFERENCE_RENDERER_CLASS_FIXTURE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            catalog,
            assemblySchemas.RAW_BYTES()
        );
    }

    function _assemblyReferenceObject(string memory json, string memory prefix, bool runtime)
        private
        returns (AxE.Coverage memory)
    {
        AxE.ObjectIdentity memory object = AxE.ObjectIdentity(
            assemblyArtistId,
            runtime
                ? StreamReferenceRenderDefinitions.ZIP_SCHEMA_ID
                : StreamReferenceRenderDefinitions.PNG_SCHEMA_ID,
            assemblySchemas.RAW_BYTES(),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".contentHash"))),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".sha256Digest"))),
            bytes32(safeVm.parseJsonBytes(json, string.concat(prefix, ".arweaveDataRoot"))),
            uint64(assemblyVm.parseJsonUint(json, string.concat(prefix, ".byteSize"))),
            runtime ? keccak256("IANA:application/zip") : keccak256("IANA:image/png"),
            StreamReferenceRenderDefinitions.FORMAT_CATALOG_ID,
            StreamReferenceRenderDefinitions.FORMAT_CATALOG_HASH
        );
        return _assemblyCoverExternal(
            object,
            safeVm.parseJsonBytes(json, string.concat(prefix, ".firstDataPath")),
            safeVm.parseJsonBytes(json, string.concat(prefix, ".lastDataPath")),
            safeVm.parseJsonBytes(json, string.concat(prefix, ".firstChunkRaw")),
            safeVm.parseJsonBytes(json, string.concat(prefix, ".lastChunkRaw"))
        );
    }

    // The environment describes the retained original package. Capture bytes must be freshly
    // exported from this actual graph and independently rendered by that exact package.
    function _assemblyPublishReference(
        string memory environmentJson,
        string memory browserJson,
        string memory capturesJson
    ) internal {
        require(assemblySnapshotRecord != 0, "original actual snapshot precedes reference");
        StreamReferenceRenderTypes.Environment memory env;
        AxE.Coverage memory cover = _assemblyReferenceObject(browserJson, "", true);
        env.objectHash = cover.objectHash;
        env.coverageHash = cover.coverageHash;
        assemblyReferenceFirstReceipts[0] = cover.firstReceiptHash;
        assemblyReferenceSecondReceipts[0] = cover.secondReceiptHash;
        env.engineName = "Google Chrome";
        env.engineVersion = "152.0.7977.83";
        env.engineExecutableSha256 =
            bytes32(safeVm.parseJsonBytes(environmentJson, ".engineExecutableSha256"));
        env.engineExecutablePath = "engine/chrome.exe";
        env.toolchainName = "reference_capture.py; Python; websockets";
        env.toolchainVersion = "STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1; 3.12.10; 15.0.1";
        env.toolchainSha256 = bytes32(safeVm.parseJsonBytes(environmentJson, ".toolchainSha256"));
        env.toolchainPath = "tool/reference_capture.py";
        env.packageFiles = abi.decode(
            safeVm.parseJsonBytes(environmentJson, ".packageFilesABI"),
            (StreamReferenceRenderTypes.PackageFile[])
        );
        env.platformPrerequisites = abi.decode(
            safeVm.parseJsonBytes(capturesJson, ".platformPrerequisitesABI"),
            (StreamReferenceRenderTypes.PackageFile[])
        );
        env.operatingSystem = "Windows";
        env.operatingSystemVersion =
            assemblyVm.parseJsonString(capturesJson, ".operatingSystemVersion");
        env.architecture = "AMD64";
        env.viewportWidth = 64;
        env.viewportHeight = 64;
        env.devicePixelRatio = 1;
        env.colorSpace = "srgb";
        env.softwareRasterization = true;
        env.captureProfile = keccak256("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1");
        env.licenseNote = assemblyVm.parseJsonString(environmentJson, ".licenseNote");
        bytes memory manifest = StreamReferenceEnvironmentJson.manifest(env);
        env.manifestHash = keccak256(manifest);
        env.manifestBytes = uint32(manifest.length);
        StreamReferenceRenderTypes.Publication memory p;
        p.collectionId = 1;
        p.referenceId = keccak256("native actual assembly first and last reference");
        p.snapshotRecordHash = assemblySnapshotRecord;
        p.snapshotRevision = 1;
        p.environment = env;
        p.reasonHash = keccak256("actual original source export and repeated package capture");
        p.effectiveAt = uint64(block.timestamp);
        p.manifestURI = "https://fixtures.example.invalid/native-assembly/reference";
        p.captures = new StreamReferenceRenderTypes.Capture[](2);
        for (uint256 i; i < 2; ++i) {
            string memory prefix = i == 0 ? ".capture1" : ".capture2";
            StreamReferenceRenderTypes.Capture memory c;
            c.tokenId = i + 1;
            c.collectionSerial = i + 1;
            c.animationHTML = safeVm.parseJsonBytes(capturesJson, string.concat(prefix, ".html"));
            require(
                keccak256(c.animationHTML) == keccak256(_assemblyHTML(i + 1)),
                "fresh actual capture HTML"
            );
            bytes memory metadataJSON =
                safeVm.parseJsonBytes(capturesJson, string.concat(prefix, ".metadataJSON"));
            require(
                keccak256(metadataJSON)
                    == keccak256(
                        bytes(
                            assemblyRouter.historicalTokenMetadataJSON(address(assemblyCore), i + 1)
                        )
                    ),
                "fresh actual capture metadata"
            );
            c.metadataJSONHash = keccak256(metadataJSON);
            c.htmlHash = keccak256(c.animationHTML);
            c.htmlBytes = uint32(c.animationHTML.length);
            c.sourceSha256 = sha256(c.animationHTML);
            cover = _assemblyReferenceObject(capturesJson, prefix, false);
            c.objectHash = cover.objectHash;
            c.coverageHash = cover.coverageHash;
            c.repeatCaptureSha256 = [
                bytes32(
                    safeVm.parseJsonBytes(
                        capturesJson, string.concat(prefix, ".repeatCapture0Sha256")
                    )
                ),
                bytes32(
                    safeVm.parseJsonBytes(
                        capturesJson, string.concat(prefix, ".repeatCapture1Sha256")
                    )
                )
            ];
            require(
                c.repeatCaptureSha256[0] == cover.sha256Digest
                    && c.repeatCaptureSha256[1] == cover.sha256Digest,
                "both fresh capture outputs equal the original PNG object"
            );
            c.environmentManifestHash = env.manifestHash;
            // Fixture EVM observation time; real capture wall time remains in the retained report.
            c.capturedAt = uint64(block.timestamp);
            p.captures[i] = c;
            assemblyReferenceFirstReceipts[i + 1] = cover.firstReceiptHash;
            assemblyReferenceSecondReceipts[i + 1] = cover.secondReceiptHash;
        }
        _assemblyUpload(bytes(StreamReferenceEnvironmentJson.files(env.packageFiles, true)));
        _assemblyUpload(
            bytes(StreamReferenceEnvironmentJson.files(env.platformPrerequisites, false))
        );
        assemblyReference.prepareFileInventory(env.packageFiles, true);
        assemblyReference.prepareFileInventory(env.platformPrerequisites, false);
        (p.expectedSourcesHash,) = assemblyReference.previewReference(p, address(this));
        (, bytes memory canonical) = assemblyReference.previewReference(p, address(this));
        _assemblyUpload(canonical);
        _assemblyUpload(abi.encode(p));
        assemblyReferenceRecord = assemblyReference.publishReference(p);
        (
            StreamReferenceRenderTypes.Publication memory retained,
            StreamReferenceRenderTypes.Receipt memory receipt
        ) = assemblyReference.referenceRecord(assemblyReferenceRecord);
        require(
            keccak256(abi.encode(retained)) == keccak256(abi.encode(p))
                && receipt.recordHash == assemblyReferenceRecord && receipt.revision == 1
                && receipt.recorder == address(this) && receipt.sourcesHash == p.expectedSourcesHash
                && receipt.payloadHash == keccak256(canonical),
            "actual complete original reference retention"
        );
        assemblyReferencePublication = p;
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = assemblyReference.lockTransition(1);
        bytes32 action = _assemblyGovernanceCall(
            2,
            address(assemblyReference),
            abi.encodeCall(assemblyReference.lockReference, (1)),
            scope,
            oldHash,
            newHash
        );
        StreamReferenceRenderTypes.Lock memory locked = assemblyReference.referenceLock(1);
        require(
            locked.actionId == action && locked.recordHash == assemblyReferenceRecord
                && locked.revision == 1,
            "real terminal reference lock"
        );
    }
    uint64 internal assemblyRootConsentObservedAt;
    bytes32 internal assemblyRenderInventoryPlan;
    AssemblyInventory.Evidence internal assemblyRenderInventoryEvidence;

    function _assemblyMaterializeInventory()
        internal
        returns (AssemblyInventory.Item[][] memory rows)
    {
        require(
            assemblyReferenceRecord != 0 && assemblyRootConsentObservedAt != 0,
            "all original producers precede inventory"
        );
        bytes32 id = assemblyInventory.beginInventory(1);
        assemblyVm.recordLogs();
        assemblyInventory.appendNative(id);
        assemblyInventory.appendReference(id);
        assemblyInventory.appendWork(id, assemblyWorkDescription, address(0));
        assemblyInventory.appendRights(id, assemblyRightsStatement);
        assemblyInventory.appendIntentWaiver(id, assemblyIntentWaiver, address(this));
        assemblyInventory.appendInterviewWaiver(id);
        assemblyInventory.appendRootAuthorization(id, address(this), assemblyRootConsentObservedAt);
        for (uint256 i; i < 31; ++i) {
            assemblyInventory.appendDefinition(id);
        }
        assemblyInventory.appendToken(id, _assemblyOriginalTokenPayload(1));
        assemblyInventory.appendToken(id, _assemblyOriginalTokenPayload(2));
        NativeAssemblyVm.Log[] memory logs = assemblyVm.getRecordedLogs();
        rows = new AssemblyInventory.Item[][](40);
        uint256 index;
        uint256 itemCount;
        bytes32 eventSignature = keccak256(
            "InventorySegmentRecorded(bytes32,uint64,(bytes32,uint64,bytes32,bytes32),(uint8,bytes32,address,bytes32,uint256,uint16,bytes32,bytes,string,uint64,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)[])"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(assemblyInventory)) continue;
            require(
                index < rows.length && logs[i].topics.length == 3
                    && logs[i].topics[0] == eventSignature && logs[i].topics[1] == id
                    && uint256(logs[i].topics[2]) == index,
                "actual original stage event identity/order"
            );
            (AssemblyInventory.Segment memory segment, AssemblyInventory.Item[] memory items) =
                abi.decode(logs[i].data, (AssemblyInventory.Segment, AssemblyInventory.Item[]));
            require(
                keccak256(abi.encode(segment))
                        == keccak256(
                            abi.encode(assemblyInventory.inventorySegment(id, uint64(index)))
                        ) && items.length == segment.itemCount,
                "complete retained segment event"
            );
            itemCount += items.length;
            rows[index++] = items;
        }
        require(index == 40, "all required source stages and both original token rows");
        AssemblyInventory.Evidence memory evidence = assemblyInventory.sealInventory(id);
        require(
            evidence.itemCount == itemCount && evidence.segmentCount == index
                && evidence.tokenCount == 2 && evidence.planId == id
                && evidence.artistId == assemblyArtistId
                && evidence.renderCriticalEvidenceHash != 0,
            "actual complete inventory totals"
        );
        require(
            evidence.originals.rootRecordHash == assemblyOriginalContentRoot
                && evidence.originals.snapshotRecordHash == assemblySnapshotRecord
                && evidence.originals.referenceRenderRecordHash == assemblyReferenceRecord
                && evidence.originals.intentRecordHash == 0
                && evidence.originals.intentWaiverRecordHash == assemblyWaiverRecord
                && evidence.originals.workDescriptionRecordHash == assemblyWorkRecord
                && evidence.originals.rightsStatementRecordHash == assemblyRightsRecord
                && evidence.originals.interviewEvidenceHash != 0,
            "eight actual original producer joins"
        );
        assemblyRenderInventoryPlan = id;
        assemblyRenderInventoryEvidence = evidence;
    }

    function _assemblyOriginalTokenPayload(uint256 tokenId)
        internal
        view
        returns (IStreamOnchainContentCheckpoint.TokenPayload memory)
    {
        return IStreamOnchainContentCheckpoint.TokenPayload(
            tokenId, bytes(""), _assemblyHTML(tokenId)
        );
    }
    mapping(bytes32 => bytes) private assemblySourceBytes;

    function _assemblyRemember(bytes memory raw) private {
        if (raw.length != 0) assemblySourceBytes[keccak256(raw)] = raw;
    }

    function _assemblyRetainSourceBytes(bytes32 id) private {
        StreamRenderCriticalSourceTypes.Context memory c = assemblyInventory.sourceContext(id);
        StreamSnapshotTypes.NativeFacts memory n =
            StreamSnapshotSourceReads.requireCurrent(assemblySnapshots.dependencies(), 1);
        _assemblyRemember(bytes(n.source.script));
        _assemblyRemember(bytes(n.source.name));
        _assemblyRemember(bytes(n.source.description));
        _assemblyRemember(bytes(n.source.imageURI));
        _assemblyRemember(bytes(n.source.animationBaseURI));
        _assemblyRemember(abi.encode(n));
        _assemblyRemember(n.serving.renderer.code);
        _assemblyRemember(address(assemblyRouter).code);
        _assemblyRemember(address(assemblyCore).code);
        _assemblyRemember(assemblySnapshots.snapshotManifestBytes(c.snapshot.recordHash));
        _assemblyRemember(abi.encode(n.contentRoot));
        _assemblyRemember(abi.encode(n.leafManifest));
        StreamFinalityCoordinatorPolicyReads.Dependencies memory pd;
        pd.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyMembership),
            address(assemblyCoordinators)
        ];
        for (uint256 i; i < 4; ++i) {
            pd.codeHashes[i] = pd.targets[i].codehash;
        }
        pd.chainId = block.chainid;
        pd.readGas = 500000;
        pd.inventoryGas = 3000000;
        StreamFinalityCoordinatorPolicyEvidence memory policies =
            StreamFinalityCoordinatorPolicyReads.requireCurrent(
                pd, _assemblyScope(), c.snapshot.inventoryPlan
            );
        _assemblyRemember(abi.encode(policies));
        for (uint256 i; i < policies.policies.length; ++i) {
            _assemblyRemember(policies.policies[i].coordinator.code);
            _assemblyRemember(abi.encode(policies.policies[i]));
        }
        _assemblyRemember(assemblyReference.referencePayload(c.referenceRender.recordHash));
        _assemblyRemember(abi.encode(assemblyReferencePublication.environment));
        for (uint256 i; i < assemblyReferencePublication.captures.length; ++i) {
            _assemblyRemember(abi.encode(assemblyReferencePublication.captures[i]));
        }
        bytes32[3] memory originals =
            [assemblyWorkRecord, assemblyRightsRecord, assemblyWaiverRecord];
        for (uint256 i; i < 3; ++i) {
            (
                IStreamPreservationRecords.CollectionRecord memory r,
                IStreamCollectionMetadataV1.RecordReceipt memory receipt
            ) = assemblyMetadata.collectionRecord(originals[i]);
            _assemblyRemember(abi.encode(r, receipt));
            (, bytes memory payload) = assemblyMetadata.recordPayload(originals[i]);
            _assemblyRemember(payload);
        }
        _assemblyRemember(bytes(assemblyIntentWaiver.waiverStatement.uri));
        _assemblyRemember(bytes(assemblyIntentWaiver.interview.waiverStatement.uri));
        for (uint64 i; i < 31; ++i) {
            bytes32 document = i < 30
                ? StreamPreservationDocumentReads.fixedId(i)
                : keccak256("STREAM_REFERENCE_RENDERER_CLASS_FIXTURE_V1");
            IStreamSchemaDocumentFacts.DocumentFacts memory f =
                assemblySchemas.documentFacts(document);
            bytes memory raw;
            for (uint256 j; j < f.chunkCount; ++j) {
                raw = bytes.concat(
                    raw, assemblyStore.readChunk(assemblySchemas.documentChunkHashAt(document, j))
                );
            }
            _assemblyRemember(raw);
        }
        for (uint256 i = 1; i <= 2; ++i) {
            _assemblyRemember(assemblyCore.tokenData(i));
            _assemblyRemember(
                bytes(assemblyRouter.historicalTokenMetadataJSON(address(assemblyCore), i))
            );
            _assemblyRemember(_assemblyOriginalTokenPayload(i).animation);
        }
    }

    AssemblyInventory.BundleEvidence internal assemblyCompleteBundle;

    function _assemblyInventoryExternalProof(
        AssemblyInventory.Item memory item,
        AxE.ObjectIdentity memory object,
        bytes memory firstPath,
        bytes memory lastPath,
        bytes memory firstRaw,
        bytes memory lastRaw
    ) private returns (StreamBundleArchiveTypes.Proof memory) {
        object.artistId = assemblyArtistId;
        object.schemaId = item.schemaId != 0
            ? item.schemaId
            : keccak256("PRESERVATION_ORIGINAL_BYTES_DECLARATION");
        object.canonicalizationId = item.canonicalizationId;
        object.formatId =
            item.formatId != 0 ? item.formatId : keccak256("DECLARED_APPLICATION_OCTET_STREAM");
        object.formatCatalogId = item.kind != AssemblyInventory.Kind.REGISTERED_DOCUMENT
            && item.catalogId != 0
            ? item.catalogId
            : keccak256("PRESERVATION_BYTE_OBJECT_DECLARATION");
        object.formatCatalogHash = item.kind != AssemblyInventory.Kind.REGISTERED_DOCUMENT
            && item.catalogHash != 0
            ? item.catalogHash
            : keccak256(
                "declared object metadata; interpretation comes from actual original source"
            );
        AxE.Coverage memory cover =
            _assemblyCoverExternal(object, firstPath, lastPath, firstRaw, lastRaw);
        return StreamBundleArchiveTypes.Proof(1, cover.coverageHash, cover.objectHash);
    }

    // An actual external fixture frame releases each member's endpoint buffers before the
    // next member. No whole253MB ZIP or cumulative raw member set enters EVM memory.
    function coverAssemblyPackageMember(AssemblyInventory.Item calldata item)
        external
        returns (StreamBundleArchiveTypes.Proof memory)
    {
        require(
            msg.sender == address(this) && item.kind == AssemblyInventory.Kind.EXTERNAL_REFERENCE
                && item.role == keccak256("RUNNABLE_PACKAGE_MEMBER"),
            "fixture-only current member"
        );
        StreamReferenceRenderTypes.PackageFile memory member =
            assemblyReferencePublication.environment.packageFiles[item.sourceIndex];
        string memory json = assemblyVm.readFile(
            string.concat(
                "test/fixtures/native-assembly/members/",
                Strings.toString(item.sourceIndex),
                ".json"
            )
        );
        AxE.ObjectIdentity memory object;
        object.contentHash = bytes32(safeVm.parseJsonBytes(json, ".contentHash"));
        object.sha256Digest = bytes32(safeVm.parseJsonBytes(json, ".sha256Digest"));
        object.arweaveDataRoot = bytes32(safeVm.parseJsonBytes(json, ".arweaveDataRoot"));
        object.byteSize = uint64(assemblyVm.parseJsonUint(json, ".byteSize"));
        string memory path = assemblyVm.parseJsonString(json, ".path");
        require(
            object.byteSize != 0 && object.byteSize == item.byteSize
                && member.byteSize == item.byteSize && object.sha256Digest == member.sha256Digest
                && keccak256(abi.encodePacked(object.sha256Digest)) == keccak256(item.digest)
                && keccak256(bytes(path)) == keccak256(bytes(item.uri))
                && keccak256(bytes(member.path)) == keccak256(bytes(path)),
            "exact ordered uncompressed original package member"
        );
        return _assemblyInventoryExternalProof(
            item,
            object,
            safeVm.parseJsonBytes(json, ".firstDataPath"),
            safeVm.parseJsonBytes(json, ".lastDataPath"),
            safeVm.parseJsonBytes(json, ".firstChunkRaw"),
            safeVm.parseJsonBytes(json, ".lastChunkRaw")
        );
    }

    function coverAssemblySourceBytes(AssemblyInventory.Item calldata item)
        external
        returns (StreamBundleArchiveTypes.Proof memory)
    {
        require(msg.sender == address(this), "fixture-only exact original bytes");
        bytes32 digest = abi.decode(item.digest, (bytes32));
        bytes memory raw = assemblySourceBytes[digest];
        require(
            raw.length != 0 && keccak256(raw) == digest && raw.length < 262144,
            "exact independently retained single-leaf source bytes"
        );
        AxE.ObjectIdentity memory object;
        object.contentHash = digest;
        object.sha256Digest = sha256(raw);
        object.byteSize = uint64(raw.length);
        object.arweaveDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(object.sha256Digest)),
                sha256(abi.encode(uint256(raw.length)))
            )
        );
        bytes memory path = abi.encode(object.sha256Digest, uint256(raw.length));
        return _assemblyInventoryExternalProof(item, object, path, path, raw, raw);
    }

    function _assemblyCoverCompleteBundle(AssemblyInventory.Item[][] memory rows) internal {
        bytes32 id = assemblyRenderInventoryPlan;
        AssemblyInventory.Evidence memory e = assemblyRenderInventoryEvidence;
        _assemblyRetainSourceBytes(id);
        StreamBundleArchiveTypes.Proof[][] memory proofs =
            new StreamBundleArchiveTypes.Proof[][](rows.length);
        uint256 emptyMembers;
        uint256 externalMembers;
        uint256 stateBundles;
        for (uint256 i; i < rows.length; ++i) {
            proofs[i] = new StreamBundleArchiveTypes.Proof[](rows[i].length);
            for (uint256 j; j < rows[i].length; ++j) {
                AssemblyInventory.Item memory item = rows[i][j];
                if (item.kind == AssemblyInventory.Kind.EMPTY_PACKAGE_MEMBER) {
                    ++emptyMembers;
                    StreamReferenceRenderTypes.PackageFile memory member =
                        assemblyReferencePublication.environment.packageFiles[item.sourceIndex];
                    require(
                        member.byteSize == 0 && member.sha256Digest == sha256(bytes(""))
                            && keccak256(bytes(member.path)) == keccak256(bytes(item.uri)),
                        "original empty member identity"
                    );
                } else if (item.kind == AssemblyInventory.Kind.STATE_BUNDLE) {
                    ++stateBundles;
                } else if (
                    item.kind == AssemblyInventory.Kind.EXTERNAL_REFERENCE
                        && item.role == keccak256("RUNNABLE_PACKAGE_MEMBER")
                ) {
                    ++externalMembers;
                    proofs[i][j] = this.coverAssemblyPackageMember(item);
                } else if (item.kind == AssemblyInventory.Kind.EXTERNAL_OBJECT) {
                    proofs[i][j] = StreamBundleArchiveTypes.Proof(
                        1, item.originalCoverageHash, item.objectHash
                    );
                } else if (item.kind == AssemblyInventory.Kind.ONCHAIN_OBJECT) {
                    proofs[i][j] = StreamBundleArchiveTypes.Proof(
                        2, item.originalCoverageHash, item.objectHash
                    );
                } else if (
                    item.kind != AssemblyInventory.Kind.ABSENT
                        && item.kind != AssemblyInventory.Kind.EMPTY_BYTES
                        && item.kind != AssemblyInventory.Kind.NATIVE_OS_PREREQUISITE
                ) {
                    proofs[i][j] = this.coverAssemblySourceBytes(item);
                }
            }
        }
        require(
            emptyMembers == 3 && externalMembers == 361 && stateBundles == 2,
            "complete original package and both actual original authorizations"
        );
        // Every receipt/fixity admission precedes this one frozen archive environment.
        assemblyBundle.beginCoverage(id);
        uint256 processed;
        for (uint64 i; i < rows.length; ++i) {
            AssemblyInventory.Segment memory segment = assemblyInventory.inventorySegment(id, i);
            bytes32[] memory next = new bytes32[](rows[i].length);
            bytes32 chain;
            for (uint256 j = rows[i].length; j > 0; --j) {
                next[j - 1] = chain;
                chain = StreamPreservationInventoryChains.link(
                    segment.key, segment.itemCount, uint64(j - 1), rows[i][j - 1], chain
                );
            }
            require(chain == segment.firstLink, "complete actual original segment witness");
            if (rows[i].length == 0) assemblyBundle.coverEmptySegment(id);
            for (uint256 j; j < rows[i].length; ++j) {
                if (processed == 0) {
                    (bool ok,) = address(assemblyBundle)
                        .call(
                            abi.encodeCall(
                                assemblyBundle.coverNext,
                                (id, rows[i][j], next[j], StreamBundleArchiveTypes.Proof(0, 0, 0))
                            )
                        );
                    require(
                        !ok && assemblyBundle.progress(id).itemCount == 0,
                        "actual nonempty source cannot skip coverage"
                    );
                }
                assemblyBundle.coverNext(id, rows[i][j], next[j], proofs[i][j]);
                ++processed;
            }
        }
        require(
            processed == e.itemCount && assemblyBundle.progress(id).complete,
            "every actual occurrence covered"
        );
        AssemblyInventory.BundleEvidence memory covered =
            assemblyBundle.requireCoverage(id, e.renderCriticalEvidenceHash);
        require(
            covered.itemCount == e.itemCount && covered.bundleCoverageHash != 0
                && covered.bundleCoverageHash != e.renderCriticalEvidenceHash,
            "independent actual full bundle"
        );
        require(
            keccak256(abi.encode(assemblyBundle.requireFullCurrentCoverage(id)))
                == keccak256(abi.encode(covered)),
            "complete original per-entry diagnostic agrees"
        );
        assemblyCompleteBundle = covered;
    }
    bytes32 internal assemblySanctionRecord;
    bytes32 internal assemblyFinalityRecord;

    function _assemblyPrepareCeremonyDefinitions() internal {
        string[2] memory names =
            ["6529STREAM_FINALITY_INPUT_MANIFEST_V1", "6529STREAM_FINALITY_INPUT_MANIFEST_ABI_V1"];
        for (uint256 i; i < names.length; ++i) {
            _assemblyRegisterDocument(
                names[i],
                i == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                StreamFinalityInputManifestSchemas.document(keccak256(bytes(names[i]))),
                assemblySchemas.RAW_BYTES()
            );
        }
        string[4] memory ids = [
            "6529STREAM_ARTIST_SANCTION_ARCHIVE_V1",
            "6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1",
            "6529STREAM_ARTIST_SANCTION_CEREMONY_V1",
            "6529STREAM_ARTIST_SANCTION_CEREMONY_JCS_V1"
        ];
        string[4] memory files = [
            "sanction-archive-v1.schema.json",
            "sanction-archive-abi-v1.json",
            "sanction-ceremony-v1.schema.json",
            "sanction-ceremony-jcs-v1.json"
        ];
        for (uint256 i; i < ids.length; ++i) {
            _assemblyRegisterDocument(
                ids[i],
                i % 2 == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                bytes(assemblyVm.readFile(string.concat("docs/schemas/finality/", files[i]))),
                assemblySchemas.RAW_BYTES()
            );
        }
        // The additional registered CATALOG extends producer applicability only; the four
        // original schema/canonicalization documents and permanent archive bytes stay exact.
        bytes memory profile = bytes(
            assemblyVm.readFile("docs/schemas/finality/sanction-native-captures-v1.profile.json")
        );
        bytes32 profileId = _assemblyRegisterDocument(
            "6529STREAM_ARTIST_SANCTION_NATIVE_CAPTURES_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            profile,
            assemblySchemas.RAW_BYTES()
        );
        IStreamSchemaDocumentFacts.DocumentFacts memory profileFacts =
            assemblySchemas.documentFacts(profileId);
        require(
            profileFacts.exists && profileFacts.kind == IStreamSchemaRegistry.DocumentKind.CATALOG
                && profileFacts.status == IStreamSchemaRegistry.DocumentStatus.ACTIVE
                && profileFacts.contentHash == keccak256(profile)
                && profileFacts.canonicalizationId == assemblySchemas.RAW_BYTES()
                && profileFacts.supersedesId == 0 && profileFacts.chunkCount == 1
                && profileFacts.totalBytes == profile.length && profileFacts.declarationHash != 0
                && keccak256(assemblySchemas.documentBytes(profileId)) == keccak256(profile)
                && keccak256(assemblyStore.readChunk(keccak256(profile))) == keccak256(profile),
            "actual registered exact composite interpretation and original bytes"
        );
        StreamFinalitySanctionSchemas.requireDefinitions(address(assemblyArtifact), 500_000);
        _assemblyGrantFinalityRole();
        _assemblyRaiseSanctionReadBudget();
    }

    function _assemblyGrantFinalityRole() private {
        bytes32 role = keccak256("ROLE_COLLECTION_FINALITY_ADMIN");
        address holder = address(assemblyRoot);
        require(!assemblyRoles.hasRole(role, holder), "fresh explicit finality role");
        (bytes32 chain, uint64 revision) = assemblyRoles.roleMutationState(role);
        (bytes32 globalChain, uint64 globalRevision) = assemblyRoles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(assemblyRoles),
                role,
                holder
            )
        );
        bytes32 nextChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(assemblyRoles),
                role,
                holder,
                true,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(assemblyRoles),
                role,
                holder,
                true,
                globalRevision + 1
            )
        );
        bytes32 domain = keccak256("6529STREAM_ROLE_MUTATION_STATE_V1");
        bytes32 oldHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(assemblyRoles),
                scope,
                false,
                chain,
                revision,
                globalChain,
                globalRevision
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                domain,
                block.chainid,
                address(assemblyRoles),
                scope,
                true,
                nextChain,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        _assemblyGovernanceCall(
            1,
            address(assemblyRoles),
            abi.encodeCall(assemblyRoles.grantRole, (role, holder)),
            scope,
            oldHash,
            newHash
        );
        require(assemblyRoles.hasRole(role, holder), "actual root finality role admission");
    }

    function _assemblyRaiseSanctionReadBudget() private {
        IStreamGasParameterHost host = IStreamGasParameterHost(address(assemblyArtists));
        bytes32 id = keccak256("6529STREAM_GGP_ARTIST_FINALITY_READ_GAS");
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, address(host), id
            )
        );
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        uint256 target = 40_000_000;
        for (uint256 i; i < 5; ++i) {
            (uint256 value, uint256 floor, uint8 failure, uint64 revision) =
                host.gasParameterInfo(id);
            require(
                value == (uint256(2_000_000) << i) && floor == 500_000 && failure == 2
                    && revision == i + 1,
                "original sanction read budget revision"
            );
            uint256 next = value * 2;
            if (next > target) next = target;
            bytes32 oldHash = keccak256(abi.encode(domain, scope, value, floor, failure, revision));
            bytes32 newHash =
                keccak256(abi.encode(domain, scope, next, floor, failure, revision + 1));
            _assemblyGovernanceCall(
                1,
                address(host),
                abi.encodeCall(host.raiseGasParameter, (id, next)),
                scope,
                oldHash,
                newHash
            );
            (uint256 saved, uint256 savedFloor, uint8 savedFailure, uint64 savedRevision) =
                host.gasParameterInfo(id);
            require(
                saved == next && savedFloor == floor && savedFailure == failure
                    && savedRevision == revision + 1,
                "separate governed doubling with exact readback"
            );
        }
        require(host.gasParameter(id) == target, "explicit composed callback cap, not measured gas");
    }

    function _assemblyCloseAndFreezeCore() internal {
        require(
            !assemblyCore.collectionFreezeStatus(1) && !assemblyCore.collectionBurnsBlocked(1)
                && assemblyCore.collectionStatus(1) == 0
                && assemblyCore.collectionMintedEver(1) == 2,
            "original completed live collection before terminal sealing"
        );
        bytes32 scope = _assemblySubject();
        bytes32 configDomain = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
        bytes32 burnsDomain = 0x0a834b49bdbe94b7d08a85a25431e3405b397e5f84bf90a90107edb2a58013ec;
        bytes32 freezeDomain = 0xa54d2564d797e7eec4b1cd68d067d7c297bfae640f401ff3b8fde47441079692;
        uint8 supply = assemblyCore.collectionSupplyMode(1);
        bool capped = assemblyCore.collectionHasMaxSupply(1);
        uint256 maximum = assemblyCore.collectionMaxSupply(1);
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](3);
        batch.callDatas = new bytes[](3);
        batch.callDatas[0] = abi.encodeCall(assemblyCore.setCollectionStatus, (1, uint8(2)));
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(assemblyCore),
            batch.callDatas[0],
            scope,
            keccak256(abi.encode(configDomain, scope, true, supply, uint8(0), capped, maximum)),
            keccak256(abi.encode(configDomain, scope, true, supply, uint8(2), capped, maximum))
        );
        batch.callDatas[1] = abi.encodeCall(assemblyCore.blockCollectionBurns, (1));
        batch.calls[1] = StreamCurrentStackPlan.call(
            address(assemblyCore),
            batch.callDatas[1],
            scope,
            keccak256(abi.encode(burnsDomain, scope, false)),
            keccak256(abi.encode(burnsDomain, scope, true))
        );
        batch.callDatas[2] = abi.encodeCall(assemblyCore.freezeCollection, (1));
        batch.calls[2] = StreamCurrentStackPlan.call(
            address(assemblyCore),
            batch.callDatas[2],
            scope,
            keccak256(abi.encode(freezeDomain, scope, false)),
            keccak256(abi.encode(freezeDomain, scope, true))
        );
        _admitAssemblyBatch(batch);
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/close-burn-seal-freeze"
        );
        require(
            assemblyCore.collectionStatus(1) == 2 && assemblyCore.collectionBurnsBlocked(1)
                && assemblyCore.collectionFreezeStatus(1),
            "three original Core terminal transitions"
        );
    }

    function _assemblyPerformSanctionAndFinality() internal {
        require(
            assemblyCompleteBundle.bundleCoverageHash != 0,
            "complete original bundle before sanction"
        );
        StreamFinalityScope memory scope = _assemblyScope();
        bytes memory raw = assemblyProvider.inputManifestBytes(scope);
        require(raw.length != 0 && raw.length <= 8192, "actual independent complete input manifest");
        bytes32[] memory chunks = _assemblyUpload(raw);
        require(
            chunks.length == 1 && chunks[0] == keccak256(raw)
                && assemblyFinality.stageFinalityManifest(raw) == chunks[0],
            "same complete original two-store manifest"
        );
        StreamFinalityManifestRef memory manifest = StreamFinalityManifestRef(
            "https://fixtures.example.invalid/native-assembly/finality-input-manifest",
            keccak256(
                bytes("https://fixtures.example.invalid/native-assembly/finality-input-manifest")
            ),
            chunks[0],
            keccak256("6529STREAM_FINALITY_INPUT_MANIFEST_V1"),
            keccak256("6529STREAM_FINALITY_INPUT_MANIFEST_ABI_V1")
        );
        (uint256 count, bytes32 independentHash) =
            assemblyDiscovery.nonSanctionDiscoveryFacts(scope);
        require(count == 9, "actual independent nine-family discovery");
        AssemblySanctionRequest.Request memory request;
        request.nonSanctionComponents = new StreamFinalityComponentExpectation[](count);
        for (uint256 i; i < count; ++i) {
            request.nonSanctionComponents[i] = assemblyDiscovery.nonSanctionComponentAt(scope, i);
        }
        require(
            assemblyFinality.computeComponentsHash(request.nonSanctionComponents)
                == independentHash,
            "exact discovery ordering"
        );
        request.manifest = manifest;
        request.terms.collectionId = 1;
        request.statement =
            "I approve these exact original onchain artworks, reference renders and preservation records for this fixture's finality ceremony.";
        request.signingToolName = "Native actual Safe fixture";
        request.signingToolVersion = "1";
        AssemblySanctionRequest.Prepared memory prepared =
            assemblyArtists.prepareArtistSanction(request);
        request.terms.sanctionSubjectHash = StreamArtistSanctionHashes.subject(prepared.subject);
        request.terms.statementHash = keccak256(prepared.ceremony);
        AssemblySanctionRequest.Prepared memory repeated =
            assemblyArtists.prepareArtistSanction(request);
        require(
            keccak256(abi.encode(prepared)) == keccak256(abi.encode(repeated)),
            "acyclic exact original ceremony"
        );
        T.Authorization memory authorization = _assemblyAuthorization(false);
        bytes32 digest = assemblyArtists.sanctionDigest(request.terms, authorization);
        authorization.signature = _assemblyArtistProof(digest);
        assemblySanctionRecord = assemblyArtists.recordArtistSanction(request, authorization);
        AssemblySanction.Record memory saved =
            assemblyArtists.sanctionRecord(assemblySanctionRecord);
        require(
            saved.recordHash == assemblySanctionRecord && saved.artistId == assemblyArtistId
                && saved.signer == address(assemblyArtist) && saved.authorityClass == 1
                && saved.nonce == authorization.nonce && saved.digest == digest
                && keccak256(abi.encode(saved.terms)) == keccak256(abi.encode(request.terms)),
            "actual nonce-backed original Safe sanction"
        );
        raw = assemblyArtists.sanctionArchiveBytes(assemblySanctionRecord);
        (bytes32 artifact, bytes32 completion) = _ocCover(
            raw,
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1"),
            keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1")
        );
        StreamFinalitySanctionArchiveProof memory proof =
            StreamFinalitySanctionArchiveProof(assemblySanctionRecord, artifact, completion);
        require(
            assemblyDiscovery.finalityComponentCountForScope(scope) == 10,
            "actual complete ten-family discovery"
        );
        StreamFinalityComponentExpectation[] memory components =
            new StreamFinalityComponentExpectation[](10);
        for (uint256 i; i < components.length; ++i) {
            components[i] = assemblyDiscovery.finalityComponentAtForScope(scope, i);
        }
        bytes32 componentHash = assemblyFinality.computeComponentsHash(components);
        require(
            componentHash == assemblyDiscovery.finalityDiscoveryHashForScope(scope),
            "complete actual discovery commitment"
        );
        bytes32 coreHash = assemblyFinality.computeCollectionCoreFactsHash(1);
        assemblyFinalityRecord =
            assemblyFinality.computeFinalityRecordHash(scope, coreHash, componentHash, manifest);
        StreamFinalityExecutionContext memory execution =
            assemblyFinality.finalityExecutionContextWithArchive(
                scope, components, assemblyFinalityRecord, manifest, proof
            );
        bytes32 action = _assemblyGovernanceCall(
            2,
            address(assemblyFinality),
            abi.encodeCall(
                assemblyFinality.finalizeCollectionArtworkWithArchive,
                (1, components, assemblyFinalityRecord, manifest, proof)
            ),
            execution.scopeHash,
            execution.oldValueHash,
            execution.newValueHash
        );
        StreamCollectionFinalityRecord memory finalized =
            assemblyFinality.collectionFinalityRecord(1);
        StreamFinalityExecutionWitness memory witness =
            assemblyFinality.finalityExecutionWitness(assemblyFinalityRecord);
        StreamFinalitySanctionArchiveWitness memory archived =
            assemblyFinality.finalitySanctionArchiveWitness(assemblyFinalityRecord);
        require(
            finalized.finalized && finalized.finalityRecordHash == assemblyFinalityRecord
                && finalized.manifestContentHash == manifest.contentHash
                && finalized.componentsHash == componentHash && witness.actionId == action
                && witness.proposer == address(assemblyRoot) && witness.roleRevision != 0
                && archived.evidenceHash != 0
                && keccak256(abi.encode(archived.proof)) == keccak256(abi.encode(proof)),
            "actual canonical class2 finality with original sanction archive"
        );
    }

    // Each factory call is a separate broadcast transaction; only the original slot creates the host.
    function _deploySplitArtistFacade(
        bytes memory creation,
        address operator_,
        address factory_,
        address[5] memory p,
        bytes32 deploymentHash,
        string memory uri,
        bytes32 manifestHash
    ) internal returns (StreamArtistOnboardingRegistry) {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(operator_);
        address[3] memory children;
        for (uint8 i; i < 3; ++i) {
            children[i] =
                StreamArtistExtensionFactory(factory_).deployRegistry(i + 4, slot.product(), p[2]);
        }
        RuntimeValue[] memory v = new RuntimeValue[](14);
        string memory name = "StreamArtistOnboardingRegistry";
        v[0] = _runtimeValue("artist", name, "core", _addressWord(p[0]));
        v[1] = _runtimeValue("artist", name, "mintManager", _addressWord(p[1]));
        v[2] = _runtimeValue("artist", name, "operationCoordinator", _addressWord(p[2]));
        v[3] = _runtimeValue("artist", name, "registryWriterExtension", _addressWord(children[0]));
        v[4] = _runtimeValue("artist", name, "registryReadExtension", _addressWord(children[1]));
        v[5] = _runtimeValue(
            "artist", name, "registryFinalityReadExtension", _addressWord(children[2])
        );
        v[6] = _runtimeValue("artist", name, "archivalCoverage", _addressWord(p[4]));
        v[7] = _runtimeValue("artist", name, "archivalCoverageCodeHash", p[4].codehash);
        v[8] = _runtimeValue(
            "artist",
            name,
            "archivalCoverageConfigurationHash",
            StreamArtistEstateCoverage.admit(p[0], p[1], p[3], p[4])
        );
        v[9] = _runtimeValue(
            "parameters", "StreamGasParameterHost", "governanceAuthority", _addressWord(p[3])
        );
        v[10] = _runtimeValue(
            "modules",
            "StreamModuleBase",
            "_schemaHash",
            keccak256("6529stream.artist-onboarding.v1")
        );
        v[11] = _runtimeValue("modules", "StreamModuleBase", "_supersedes", bytes32(0));
        v[12] =
            _runtimeValue("modules", "StreamModuleBase", "_deploymentManifestHash", deploymentHash);
        v[13] = _runtimeValue("modules", "StreamModuleBase", "_manifestHash", manifestHash);
        string[] memory parents = new string[](2);
        parents[0] = "StreamGasParameterHost";
        parents[1] = "StreamModuleBase";
        bytes memory runtime = _productRuntime(name, parents, creation, v);
        address host = slot.deploy(
            bytes.concat(
                creation,
                abi.encode(
                    p[0],
                    p[1],
                    p[2],
                    p[3],
                    p[4],
                    deploymentHash,
                    uri,
                    manifestHash,
                    factory_,
                    children
                )
            ),
            keccak256(runtime)
        );
        require(
            host == slot.product() && keccak256(host.code) == keccak256(runtime),
            "complete split facade runtime"
        );
        return StreamArtistOnboardingRegistry(payable(host));
    }

    function _deploySplitArtistIdentity(
        bytes memory creation,
        address operator_,
        address factory_,
        address[5] memory p
    ) internal returns (address host) {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(operator_);
        address[3] memory children;
        address[6] memory pins = [slot.product(), p[0], p[1], p[2], p[3], p[4]];
        for (uint8 i; i < 3; ++i) {
            children[i] = StreamArtistExtensionFactory(factory_).deployIdentity(i + 1, pins);
        }
        RuntimeValue[] memory v = new RuntimeValue[](11);
        string memory name = "StreamArtistIdentityAuthority";
        v[0] = _runtimeValue("artist", "StreamArtistOwner", "artistRegistry", _addressWord(p[0]));
        v[1] = _runtimeValue(
            "artist", "StreamArtistOwner", "operationCoordinator", _addressWord(p[1])
        );
        v[2] = _runtimeValue("artist", "StreamArtistOwner", "archiveV2", _addressWord(p[2]));
        v[3] = _runtimeValue("artist", "StreamArtistOwner", "core", _addressWord(p[3]));
        v[4] = _runtimeValue("artist", "StreamArtistOwner", "mintManager", _addressWord(p[4]));
        v[5] = _runtimeValue(
            "artist", "StreamArtistOwner", "deploymentChainId", bytes32(block.chainid)
        );
        v[6] = _runtimeValue(
            "artist", "StreamArtistOwner", "domainId", keccak256("domain:identity_authority")
        );
        v[7] = _runtimeValue(
            "artist",
            name,
            "artistWindowAuthority",
            _addressWord(StreamArtistTimingState.canonicalAuthority(p[3], p[4]))
        );
        v[8] = _runtimeValue("artist", name, "identityWriterExtension", _addressWord(children[0]));
        v[9] = _runtimeValue("artist", name, "identityEstateExtension", _addressWord(children[1]));
        v[10] =
            _runtimeValue("artist", name, "identityRecoveryExtension", _addressWord(children[2]));
        string[] memory parents = new string[](1);
        parents[0] = "StreamArtistOwner";
        bytes memory runtime = _productRuntime(name, parents, creation, v);
        host = slot.deploy(
            bytes.concat(creation, abi.encode(p[0], p[1], p[2], p[3], p[4], factory_, children)),
            keccak256(runtime)
        );
        require(
            host == slot.product() && keccak256(host.code) == keccak256(runtime),
            "complete split Identity runtime"
        );
    }
}
