// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ScopedPolicyOutputModulesBoundary,
    ScopedPolicyOutputVersionsBoundary
} from "./scoped-preservation-boundaries/StreamScopedPolicyContentCheckpointV2Boundaries.sol";

import "./StaticMetadataRoutingFixture.sol";
import {
    IStreamMetadataRouter
} from "../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import "./EntropyTimeTestMocks.sol";
import "../mocks/MockEntropyRoleRegistry.sol";
import "../mocks/MockStreamEntropyProvider.sol";
import "../unit/entropy/EntropyCollectionPolicyFixtures.sol";
import {
    StreamScopedPolicyContentCheckpointV2 as Checkpoint
} from "../../smart-contracts/domains/finality/StreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as O
} from "../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamPolicyContentCheckpointV2 as CollectionO
} from "../../smart-contracts/interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    IStreamStaticContentCheckpoint as OriginalO
} from "../../smart-contracts/interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    StreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as PolicyReads
} from "../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamFinalityEntropyPolicySourceSet as SourceSet
} from "../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as E
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamEntropyCollectionPolicy as EP
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamCurrentCitationRegistry as ScopedCitation
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamCurrentCitationRenderer as CurrentRenderer
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";
import {
    StreamTerminalEntropyReadiness
} from "../../smart-contracts/domains/finality/StreamTerminalEntropyReadiness.sol";
import {
    StreamStaticSelectionCheckpoint
} from "../../smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol";
import {
    StreamFinalityScopeMembership
} from "../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import {
    StreamCollectionTokenInventory
} from "../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import {
    StreamFinalityCoordinatorInventory
} from "../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import {
    StreamTokenContentTree as Tree
} from "../../smart-contracts/domains/metadata/StreamTokenContentTree.sol";
import {
    StreamTokenContentLeaf
} from "../../smart-contracts/interfaces/stream/metadata/StreamTokenContentTypes.sol";
import {
    StreamScopeMembershipManifest
} from "../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamScopeMembershipEncoding
} from "../../smart-contracts/domains/finality/StreamScopeMembershipEncoding.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamCoreIdentity
} from "../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamCorePointers
} from "../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamRevealFeeEscrow
} from "../../smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";

/// @notice Actual native entropy policy/finalization, factory CREATE/current route, complete
/// coordinator inventory, sealed Metadata membership, STATIC selection, Renderer/Router and
/// readiness. Core identities/at-mint selection, Artist consent, governance execution and module/
/// renderer admission remain explicitly typed boundaries. No current-stack/finality ceremony claim.
abstract contract ScopedPolicyContentFixtureV2 is
    StaticMetadataRoutingFixture,
    EntropyTimeAuthorityFixture
{
    MockEntropyRoleRegistry public roleRegistry;
    StreamEntropyCoordinator internal terminalCoordinator;
    StreamEntropyCoordinator internal randomCoordinator;
    ScopedPolicyOutputVersionsBoundary internal terminalVersions;
    ScopedPolicyOutputVersionsBoundary internal randomVersions;
    ScopedPolicyOutputModulesBoundary internal scopedModules;
    StreamFinalityCoordinatorInventory internal scopedSources;
    StreamFinalityScopeMembership internal scopedMembership;
    StreamStaticSelectionCheckpoint internal scopedSelections;
    Factory internal scopedFactory;
    bytes32 internal scopedFinalizedSeed;

    function setUp() public virtual override {
        super.setUp();
        vm.warp(1000);
    }

    // Real Metadata payload reads nest its Store cap inside Membership's 500k budget.
    // Configure that dependency at genesis; checkpoint read/render caps stay unchanged.
    function _metadataDependencyReadGas() internal pure override returns (uint256) {
        return 200000;
    }

    function _scopedFixture(uint8 terminalStatus, bool finalize) internal {
        require(terminalStatus == 1 || terminalStatus == 2);
        scopedModules = ScopedPolicyOutputModulesBoundary(
            _artistArtifactCreate(
                "test/helpers/scoped-preservation-boundaries/StreamScopedPolicyContentCheckpointV2Boundaries.sol:ScopedPolicyOutputModulesBoundary",
                abi.encode(address(metadata))
            )
        );
        core.setPointer(keccak256("MODULE_REGISTRY"), address(scopedModules));
        roleRegistry = MockEntropyRoleRegistry(
            _artistArtifactCreate(
                "test/mocks/MockEntropyRoleRegistry.sol:MockEntropyRoleRegistry",
                abi.encode(address(this))
            )
        );
        terminalCoordinator = _scopedNative(roleRegistry);
        EntropyCollectionPolicyArtistFixture policyArtist = EntropyCollectionPolicyArtistFixture(
            _artistArtifactCreate(
                "test/unit/entropy/EntropyCollectionPolicyFixtures.sol:EntropyCollectionPolicyArtistFixture",
                abi.encode(address(core))
            )
        );
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(policyArtist));
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(terminalCoordinator));
        EP.PolicyInput memory policy;
        policy.renderRequirement = EP.RenderRequirement.NOT_REQUIRED;
        if (terminalStatus == 2) {
            (,, address provider,,) = terminalCoordinator.entropyPolicyFrozen(1);
            policy.mode = EP.Mode.ASYNC;
            policy.provider = provider;
            policy.collectionSalt = keccak256("scoped native salt");
            policy.publicRequests = true;
            policy.timeoutBlocks = 10;
            policy.reveal = IStreamRevealFeeEscrow.CollectionRevealPolicy(
                true, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0
            );
        }
        (bytes32 scope, bytes32 old, bytes32 next, bytes32 content) =
            EP(address(terminalCoordinator)).collectionEntropyPolicyTransition(1, policy);
        policyArtist.approve(
            1,
            address(terminalCoordinator),
            keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"),
            content,
            keccak256("original scoped entropy op17")
        );
        this.setCurrentAction(true, keccak256("original scoped policy action"), 1, scope, old, next);
        EP(address(terminalCoordinator)).configureCollectionEntropyPolicy(1, policy);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(artist));
        randomCoordinator = _scopedNative(roleRegistry);
        core.setEntropy(address(terminalCoordinator));
        (renderer, terminalVersions) = _scopedRenderer(address(terminalCoordinator));
        versions = terminalVersions;
        (StreamRendererV1 randomRenderer, ScopedPolicyOutputVersionsBoundary randomRegistry) =
            _scopedRenderer(address(randomCoordinator));
        randomVersions = randomRegistry;
        _scopedPointer(
            keccak256("COLLECTION_METADATA"),
            address(metadata),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        _scopedPointer(
            keccak256("METADATA_ROUTER"), address(router), type(IStreamMetadataRouter).interfaceId
        );
        _admin(
            abi.encodeCall(
                router.setCollectionMetadata,
                (
                    1,
                    "Scoped policy output",
                    "Original terminal and finalized policies",
                    "data:image/png;base64,iVBORw0KGgo=",
                    ""
                )
            )
        );
        _activate();
        _scopedToken(91, 1, 2, address(terminalCoordinator));
        _scopedToken(92, 2, 2, address(randomCoordinator));
        core.setMinted(2);
        vm.prank(address(core));
        terminalCoordinator.onTokenMinted(1, 91, address(this), keccak256("original terminal mint"));
        vm.prank(address(core));
        randomCoordinator.onTokenMinted(1, 92, address(this), keccak256("original random mint"));
        if (finalize) _scopedFinalize();
        S.ConfigInput memory input = _input(R.MetadataMode.ONCHAIN, true);
        input.registry = address(randomVersions);
        input.versionKey = randomVersions.key();
        input.config.renderer = address(randomRenderer);
        _approve(92, input, keccak256("original scoped random token config consent"));
        router.setTokenMetadataConfig(92, input);
        input = _input(R.MetadataMode.ONCHAIN, true);
        _approve(0, input, keccak256("original scoped collection config consent"));
        router.setCollectionMetadataConfig(1, input);
        StreamCollectionTokenInventory indexedTokens = StreamCollectionTokenInventory(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamCollectionTokenInventory.sol:StreamCollectionTokenInventory",
                abi.encode(
                    address(core),
                    address(executor),
                    _scopedGas("TOKEN_INVENTORY_CORE_READ_GAS", 100000, 1)
                )
            )
        );
        uint256[] memory ids = _scopedIds();
        indexedTokens.appendCollectionTokens(1, ids);
        _scopedDocument("RAW_BYTES", true, bytes(schemas.RAW_BYTES_DEFINITION()));
        _scopedDocument(
            "STREAM_SCOPE_MEMBERSHIP_V1",
            false,
            bytes(vm.readFile("docs/schemas/finality/scope-membership-v1.schema.json"))
        );
        _scopedDocument(
            "STREAM_SCOPE_MEMBERSHIP_ABI_V1",
            true,
            bytes(vm.readFile("docs/schemas/finality/scope-membership-abi-v1.json"))
        );
        (scope, old, next) = metadata.recordTypeTransition(
            keccak256("SCOPE_MEMBERSHIP"),
            keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1"),
            384
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.admitRecordType,
                (
                    keccak256("SCOPE_MEMBERSHIP"),
                    keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1"),
                    uint16(384)
                )
            ),
            scope,
            old,
            next
        );
        scopedMembership = StreamFinalityScopeMembership(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamFinalityScopeMembership.sol:StreamFinalityScopeMembership",
                abi.encode(
                    address(core),
                    address(metadata),
                    address(indexedTokens),
                    address(executor),
                    _scopedGas("SCOPE_MEMBERSHIP_READ_GAS", 500000, 1)
                )
            )
        );
        scopedSelections = StreamStaticSelectionCheckpoint(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol:StreamStaticSelectionCheckpoint",
                abi.encode(
                    address(core),
                    address(router),
                    address(scopedMembership),
                    address(executor),
                    _scopedGas("STATIC_CHECKPOINT_READ_GAS", 2000000, 1)
                )
            )
        );
        scopedSources = StreamFinalityCoordinatorInventory(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol:StreamFinalityCoordinatorInventory",
                abi.encode(address(core), address(scopedMembership), 100000, 2000000)
            )
        );
        scopedFactory = Factory(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol:StreamFinalityScopedEntropyPolicySourceFactoryV2",
                abi.encode(_scopedDependencies())
            )
        );
    }

    function _scopedNative(MockEntropyRoleRegistry roles)
        private
        returns (StreamEntropyCoordinator n)
    {
        n = StreamEntropyCoordinator(
            _artistArtifactCreate(
                "smart-contracts/domains/entropy/StreamEntropyCoordinator.sol:StreamEntropyCoordinator",
                abi.encode(
                    StreamEntropyCoordinator.DeploymentConfig(
                        address(core),
                        address(this),
                        address(roles),
                        EntropyTimeTestConfigs.parameters(),
                        keccak256("deployment"),
                        "ipfs://scoped-native-policy",
                        keccak256("native policy manifest")
                    )
                )
            )
        );
        MockStreamEntropyProvider provider = MockStreamEntropyProvider(
            _artistArtifactCreate(
                "test/mocks/MockStreamEntropyProvider.sol:MockStreamEntropyProvider",
                abi.encode(address(n))
            )
        );
        _admitEntropyProvider(address(n), address(provider));
        n.configureCollection(1, address(provider), keccak256("scoped native salt"), true, 10);
        n.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
    }

    function _scopedRenderer(address nativeEntropy)
        private
        returns (StreamRendererV1 r, ScopedPolicyOutputVersionsBoundary v)
    {
        StreamRendererV1.Deployment memory d;
        (d.sources,) = renderer.sourceBindings();
        d.sources.entropy = nativeEntropy;
        d.executor = address(executor);
        d.manifest = renderer.rendererManifest();
        d.readGas = _scopedGas("METADATA_DEPENDENCY_READ_GAS", 2000000, 2);
        d.attributionGas = _scopedGas("STATIC_ATTRIBUTION_GAS", 8000000, 1);
        r = StreamRendererV1(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamRendererV1.sol:StreamRendererV1",
                abi.encode(d)
            )
        );
        v = ScopedPolicyOutputVersionsBoundary(
            _artistArtifactCreate(
                "test/helpers/scoped-preservation-boundaries/StreamScopedPolicyContentCheckpointV2Boundaries.sol:ScopedPolicyOutputVersionsBoundary",
                abi.encode(address(executor), address(schemas), address(r))
            )
        );
        v.setAdmitted(true);
        scopedModules.admit(address(v));
    }

    function _scopedFinalize() internal {
        (, uint256 request) = randomCoordinator.requestEntropy(92);
        (,, address provider,,) = randomCoordinator.entropyPolicyFrozen(1);
        require(
            MockStreamEntropyProvider(provider)
                .fulfill(request, keccak256("actual scoped random bytes")) == 0
        );
        bool done;
        (scopedFinalizedSeed, done) = randomCoordinator.tokenSeed(92);
        require(done && scopedFinalizedSeed != 0);
    }

    function _scopedToken(uint256 token, uint256 serial, uint8 lifecycle, address original)
        internal
    {
        core.setToken(token, address(this), lifecycle);
        core.setPortableTokenSerial(token, serial);
        core.setPortableCoordinator(token, original);
        StaticRouteVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (token)),
                abi.encode(lifecycle != 0, uint256(1), serial, lifecycle == 3)
            );
        StaticRouteVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (token)),
                abi.encode(original)
            );
    }

    function _scopedPointer(bytes32 kind, address target, bytes4 capability) internal {
        core.setPortablePointer(kind, target, capability, address(scopedModules));
        StaticRouteVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)),
                abi.encode(
                    target,
                    target.codehash,
                    false,
                    kind,
                    capability,
                    address(scopedModules),
                    uint8(1),
                    keccak256("typed module manifest"),
                    keccak256("typed deployment"),
                    uint64(1)
                )
            );
    }

    function _scopedDependencies() internal view returns (PolicyReads.Dependencies memory d) {
        d.targets =
            [address(core), address(metadata), address(scopedMembership), address(scopedSources)];
        for (uint256 i; i < 4; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.inventoryGas = 3000000;
    }

    function _scopedScope(uint8 kind) internal returns (StreamFinalityScope memory scope) {
        if (kind == 1) return StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 91, 0);
        bytes memory tokenBytes = abi.encode(uint256(91), uint256(92));
        StreamSchemaDocumentStore store = StreamSchemaDocumentStore(schemas.chunkStore());
        (bytes32 part,) = store.publishChunk(tokenBytes);
        bytes32[] memory parts = new bytes32[](1);
        parts[0] = part;
        StreamScopeMembershipManifest memory m = StreamScopeMembershipManifest(
            1, block.chainid, address(core), 1, kind, 2, keccak256(tokenBytes), parts
        );
        bytes memory payload = StreamScopeMembershipEncoding.encode(m);
        IStreamPreservationRecords.CollectionRecord memory record;
        record.recordType = keccak256("SCOPE_MEMBERSHIP");
        record.subjectId = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        record.schemaId = keccak256("STREAM_SCOPE_MEMBERSHIP_V1");
        record.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(payload)), keccak256("STREAM_SCOPE_MEMBERSHIP_ABI_V1")
        );
        record.uri = "ipfs://scoped-policy-membership";
        record.effectiveAt = 1000;
        bytes32 saved = metadata.recordCollectionRecordWithPayload(1, record, payload);
        scope = scopedMembership.beginScopeMembership(saved);
        scopedMembership.continueScopeMembership(scope, 64);
    }

    function _scopedCapture(StreamFinalityScope memory scope)
        internal
        returns (Checkpoint host, bytes32 selection)
    {
        bytes32 plan = scopedSources.beginInventory(scope);
        if (!scopedSources.inventoryProgress(plan).complete) {
            scopedSources.appendInventory(plan, 256);
        }
        scopedSources.requireCompleteInventory(plan);
        address set = scopedFactory.prepareSourceSet(scope);
        selection = scopedSelections.begin(scope);
        if (
            scopedSelections.checkpoint(selection).nextIndex
                < scopedSelections.checkpoint(selection).tokenCount
        ) {
            scopedSelections.append(selection, 16);
        }
        scopedSelections.requireCurrentCheckpoint(selection);
        StreamTerminalEntropyReadiness readiness = StreamTerminalEntropyReadiness(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamTerminalEntropyReadiness.sol:StreamTerminalEntropyReadiness",
                abi.encode(address(core), address(router), set, 2000000, 6000000)
            )
        );
        host = _scopedCheckpoint(set, address(readiness));
    }

    function _scopedCheckpoint(address set, address readiness) internal returns (Checkpoint) {
        return Checkpoint(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamScopedPolicyContentCheckpointV2.sol:StreamScopedPolicyContentCheckpointV2",
                abi.encode(
                    address(scopedSelections),
                    set,
                    readiness,
                    address(executor),
                    _scopedGas("STATIC_CONTENT_READ_GAS", 8000000, 2),
                    _scopedGas("STATIC_CONTENT_RENDER_GAS", 16000000, 2)
                )
            )
        );
    }

    function _scopedPayload(StreamFinalityScope memory scope)
        internal
        view
        returns (O.Payload[] memory p)
    {
        uint256 count = scopedMembership.requireScopeMembership(scope).tokenCount;
        p = new O.Payload[](count);
        for (uint256 i; i < count; ++i) {
            uint256 token = scopedMembership.scopeTokenAt(scope, i);
            p[i] = O.Payload(token, hex"89504e470d0a1a0a", bytes(router.tokenHTML(token)));
        }
    }

    function _scopedDocument(string memory name, bool canonicalization, bytes memory raw) internal {
        StreamSchemaDocumentStore store = StreamSchemaDocumentStore(schemas.chunkStore());
        (bytes32 part,) = store.publishChunk(raw);
        bytes32[] memory parts = new bytes32[](1);
        parts[0] = part;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name,
            canonicalization
                ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                : IStreamSchemaRegistry.DocumentKind.SCHEMA,
            part,
            schemas.RAW_BYTES(),
            0,
            "",
            uint32(raw.length)
        );
        (bytes32 scope, bytes32 old, bytes32 next) = schemas.registrationTransition(spec, parts);
        executor.execute(
            address(schemas),
            abi.encodeCall(schemas.registerDocument, (spec, parts)),
            scope,
            old,
            next
        );
    }

    function _scopedIds() private pure returns (uint256[] memory ids) {
        ids = new uint256[](2);
        ids[0] = 91;
        ids[1] = 92;
    }

    function _scopedGas(string memory name, uint256 value, uint8 failure)
        internal
        pure
        returns (IStreamGasParameterHost.GasParameterConfig memory)
    {
        return IStreamGasParameterHost.GasParameterConfig(name, value, 50000, failure);
    }
}
