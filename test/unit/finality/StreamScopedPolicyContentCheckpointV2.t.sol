// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ScopedPolicyOutputModulesBoundary,
    ScopedPolicyOutputVersionsBoundary
} from "../../helpers/scoped-preservation-boundaries/StreamScopedPolicyContentCheckpointV2Boundaries.sol";

import "../metadata/StreamTerminalEntropyRouting.t.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import "../entropy/EntropyCollectionPolicyFixtures.sol";
import {
    StreamScopedPolicyContentCheckpointV2 as Checkpoint
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as O
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamPolicyContentCheckpointV2 as CollectionO
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    IStreamStaticContentCheckpoint as OriginalO
} from "../../../smart-contracts/interfaces/stream/finality/IStreamStaticContentCheckpoint.sol";
import {
    StreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as PolicyReads
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamFinalityEntropyPolicySourceSet as SourceSet
} from "../../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as E
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamEntropyCollectionPolicy as EP
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamCurrentCitationRegistry as ScopedCitation
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRegistry.sol";
import {
    IStreamCurrentCitationRenderer as CurrentRenderer
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCurrentCitationRenderer.sol";
import {
    StreamTerminalEntropyReadiness
} from "../../../smart-contracts/domains/finality/StreamTerminalEntropyReadiness.sol";
import {
    StreamStaticSelectionCheckpoint
} from "../../../smart-contracts/domains/finality/StreamStaticSelectionCheckpoint.sol";
import {
    StreamFinalityScopeMembership
} from "../../../smart-contracts/domains/finality/StreamFinalityScopeMembership.sol";
import {
    StreamCollectionTokenInventory
} from "../../../smart-contracts/domains/finality/StreamCollectionTokenInventory.sol";
import {
    StreamFinalityCoordinatorInventory
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import {
    StreamTokenContentTree as Tree
} from "../../../smart-contracts/domains/metadata/StreamTokenContentTree.sol";
import {
    StreamTokenContentLeaf
} from "../../../smart-contracts/interfaces/stream/metadata/StreamTokenContentTypes.sol";
import {
    StreamScopeMembershipManifest
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamScopeMembershipEncoding
} from "../../../smart-contracts/domains/finality/StreamScopeMembershipEncoding.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamCoreIdentity
} from "../../../smart-contracts/interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamCorePointers
} from "../../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamRevealFeeEscrow
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";

/// @notice Actual native entropy policy/finalization, factory CREATE/current route, complete
/// coordinator inventory, sealed Metadata membership, STATIC selection, Renderer/Router and
/// readiness. Core identities/at-mint selection, Artist consent, governance execution and module/
/// renderer admission remain explicitly typed boundaries. No current-stack/finality ceremony claim.
abstract contract ScopedPolicyContentFixtureV2 is
    StaticMetadataRoutingFixture,
    EntropyTimeAuthorityFixture
{
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

    function _scopedFixture(uint8 terminalStatus, bool finalize) internal {
        require(terminalStatus == 1 || terminalStatus == 2);
        scopedModules = new ScopedPolicyOutputModulesBoundary(address(metadata));
        core.setPointer(keccak256("MODULE_REGISTRY"), address(scopedModules));
        MockEntropyRoleRegistry roles = new MockEntropyRoleRegistry(address(this));
        terminalCoordinator = _scopedNative(roles);
        EntropyCollectionPolicyArtistFixture policyArtist =
            new EntropyCollectionPolicyArtistFixture(address(core));
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
        randomCoordinator = _scopedNative(roles);
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
        _approve(0, input, keccak256("original scoped collection config consent"));
        router.setCollectionMetadataConfig(1, input);
        input.registry = address(randomVersions);
        input.versionKey = randomVersions.key();
        input.config.renderer = address(randomRenderer);
        _approve(92, input, keccak256("original scoped random token config consent"));
        router.setTokenMetadataConfig(92, input);
        StreamCollectionTokenInventory indexedTokens = new StreamCollectionTokenInventory(
            address(core), address(executor), _scopedGas("TOKEN_INVENTORY_CORE_READ_GAS", 100000, 1)
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
        scopedMembership = new StreamFinalityScopeMembership(
            address(core),
            address(metadata),
            address(indexedTokens),
            address(executor),
            _scopedGas("SCOPE_MEMBERSHIP_READ_GAS", 500000, 1)
        );
        scopedSelections = new StreamStaticSelectionCheckpoint(
            address(core),
            address(router),
            address(scopedMembership),
            address(executor),
            _scopedGas("STATIC_CHECKPOINT_READ_GAS", 2000000, 1)
        );
        scopedSources = new StreamFinalityCoordinatorInventory(
            address(core), address(scopedMembership), 100000, 2000000
        );
        scopedFactory = new Factory(_scopedDependencies());
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
        MockStreamEntropyProvider provider = new MockStreamEntropyProvider(address(n));
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
        v = new ScopedPolicyOutputVersionsBoundary(address(executor), address(schemas), address(r));
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
        scopedSources.appendInventory(plan, 256);
        address set = scopedFactory.prepareSourceSet(scope);
        selection = scopedSelections.begin(scope);
        scopedSelections.append(selection, 16);
        StreamTerminalEntropyReadiness readiness = new StreamTerminalEntropyReadiness(
            address(core), address(router), set, 2000000, 6000000
        );
        host = _scopedCheckpoint(set, address(readiness));
    }

    function _scopedCheckpoint(address set, address readiness) internal returns (Checkpoint) {
        return new Checkpoint(
            address(scopedSelections),
            set,
            readiness,
            address(executor),
            _scopedGas("STATIC_CONTENT_READ_GAS", 8000000, 2),
            _scopedGas("STATIC_CONTENT_RENDER_GAS", 16000000, 2)
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

contract StreamScopedPolicyContentCheckpointV2Test is ScopedPolicyContentFixtureV2 {
    function testScopedPolicyAllThreeCanonicalScopesUseActualCreatedSourceSets() public {
        _scopedFixture(1, true);
        for (uint8 kind = 1; kind <= 3; ++kind) {
            StreamFinalityScope memory scope = _scopedScope(kind);
            (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
            bytes32 id = host.begin(selection, keccak256("same salt"));
            host.append(id, _scopedPayload(scope));
            O.Plan memory p = host.requireCurrentCheckpoint(id);
            SourceSet set = SourceSet(host.entropySourceSet());
            require(keccak256(abi.encode(p.scope)) == keccak256(abi.encode(scope)));
            require(p.tokenCount == (kind == 1 ? 1 : 2) && p.nextIndex == p.tokenCount);
            require(
                set.factory() == address(scopedFactory)
                    && host.sourceFactory() == address(scopedFactory)
            );
            require(host.factoryDependenciesHash() == keccak256(abi.encode(_scopedDependencies())));
            require(set.inventoryPlan() == scopedFactory.currentInventoryPlan(scope));
            require(scopedFactory.requireCurrentRoute(scope).component == address(set));
            require(
                p.inventoryHash == set.originalInventoryHash()
                    && p.policyChainHash == set.originalPolicyChainHash()
            );
            require(set.sourceCount() == (kind == 1 ? 1 : 2));
            _assertRoots(host, id);
            require(host.begin(selection, keccak256("same salt")) == id);
        }
    }

    function testScopedPolicyDisabledAndFinalizedRowsKeepDistinctNativeEvidence() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(2);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        O.Output memory terminal = host.outputAt(id, 0);
        O.Output memory random = host.outputAt(id, 1);
        require(terminal.entropy.coordinator == address(terminalCoordinator));
        require(
            terminal.entropy.status == 1 && terminal.entropy.mode == 0 && terminal.entropy.terminal
                && !terminal.entropy.finalized && terminal.entropy.seed == 0
                && terminal.terminalAdmissionHash != 0
        );
        require(random.entropy.coordinator == address(randomCoordinator));
        require(
            random.entropy.status == 5 && random.entropy.mode == 2 && !random.entropy.terminal
                && random.entropy.finalized && random.entropy.seed == scopedFinalizedSeed
                && random.terminalAdmissionHash == 0
        );
        EP.PolicyRecord memory policy = EP(address(terminalCoordinator)).collectionEntropyPolicy(1);
        require(
            policy.explicitPolicy && policy.frozen
                && terminal.entropy.policyHash == policy.policyHash
        );
        core.setEntropy(address(randomCoordinator));
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(randomCoordinator));
        host.requireCurrentCheckpoint(id);
        require(_has(router.tokenJSON(91), '"entropy_finalized":false'));
        require(!_has(router.tokenHTML(91), "const hash="));
    }

    function testScopedPolicyExplicitNotRequiredIsTerminalWithoutRandomSeed() public {
        _scopedFixture(2, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        O.Output memory row = host.outputAt(id, 0);
        require(
            row.entropy.status == 2 && row.entropy.mode == 2 && row.entropy.terminal
                && !row.entropy.finalized && row.entropy.seed == 0 && row.terminalAdmissionHash != 0
        );
        (bytes32 nativeSeed, bool nativeFinalized) = terminalCoordinator.tokenSeed(91);
        require(nativeSeed == 0 && !nativeFinalized);
        host.requireCurrentCheckpoint(id);
    }

    function testScopedPolicyPendingBatchRollsBackThenActualFulfillmentRetries() public {
        _scopedFixture(1, false);
        StreamFinalityScope memory scope = _scopedScope(3);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        O.Payload[] memory payload = new O.Payload[](2);
        payload[0] = O.Payload(91, hex"89504e470d0a1a0a", bytes(router.tokenHTML(91)));
        payload[1] =
            O.Payload(92, hex"89504e470d0a1a0a", bytes("nonempty pending output cannot qualify"));
        E.TokenReadiness memory pending = E(host.entropySourceSet()).tokenEntropyReadiness(92);
        require(!pending.finalized && !pending.terminal && pending.seed == 0 && pending.status != 5);
        bytes32 before = keccak256(abi.encode(host.checkpoint(id)));
        vm.expectRevert(abi.encodeWithSelector(O.StaticContentPayload.selector, uint256(92)));
        host.append(id, payload);
        require(keccak256(abi.encode(host.checkpoint(id))) == before);
        vm.expectRevert(abi.encodeWithSelector(O.StaticContentIndex.selector, uint256(0)));
        host.outputAt(id, 0);
        _scopedFinalize();
        host.append(id, _scopedPayload(scope));
        require(host.requireCurrentCheckpoint(id).nextIndex == 2);
    }

    function testScopedPolicyBurnedRetainedIdentityAndPreparedRejection() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(2);
        _scopedToken(91, 1, 3, address(terminalCoordinator));
        _scopedToken(92, 2, 3, address(randomCoordinator));
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        bytes32 retained = keccak256(abi.encode(host.outputAt(id, 1)));
        require(_has(router.tokenJSON(92), '"metadata_state":"burned"'));
        host.requireCurrentCheckpoint(id);
        _scopedToken(92, 2, 1, address(randomCoordinator));
        vm.expectRevert();
        host.requireCurrentCheckpoint(id);
        require(keccak256(abi.encode(host.outputAt(id, 1))) == retained);
        _scopedToken(92, 2, 3, address(randomCoordinator));
        host.requireCurrentCheckpoint(id);
    }

    function testScopedPolicyPayloadOrderImageAndHTMLFailuresLeaveExactRetry() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(2);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        bytes32 before = keccak256(abi.encode(host.checkpoint(id)));
        O.Payload[] memory payload = _scopedPayload(scope);
        payload[1].tokenId = 91;
        vm.expectRevert();
        host.append(id, payload);
        require(keccak256(abi.encode(host.checkpoint(id))) == before);
        payload = _scopedPayload(scope);
        payload[1].image = hex"01";
        vm.expectRevert();
        host.append(id, payload);
        require(keccak256(abi.encode(host.checkpoint(id))) == before);
        payload = _scopedPayload(scope);
        payload[1].animation = bytes("substituted HTML");
        vm.expectRevert();
        host.append(id, payload);
        require(keccak256(abi.encode(host.checkpoint(id))) == before);
        host.append(id, _scopedPayload(scope));
        _assertRoots(host, id);
    }

    function testScopedPolicyCurrentSelectionAdmissionAndFullOutputDriftPreserveHistory() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(3);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        bytes32 saved =
            keccak256(abi.encode(host.checkpoint(id), host.outputAt(id, 0), host.outputAt(id, 1)));
        scopedModules.setEnabled(false);
        vm.expectRevert();
        host.requireCurrentCheckpoint(id);
        scopedModules.setEnabled(true);
        terminalVersions.setAdmitted(false);
        vm.expectRevert();
        host.requireCurrentCheckpoint(id);
        terminalVersions.setAdmitted(true);
        attribution.setFail(true);
        vm.expectRevert();
        host.requireCurrentCheckpoint(id);
        attribution.setFail(false);
        require(
            keccak256(abi.encode(host.checkpoint(id), host.outputAt(id, 0), host.outputAt(id, 1)))
                == saved
        );
        host.requireCurrentCheckpoint(id);
    }

    function testScopedPolicyRuntimePinsCannotBeReplacedAndOriginalBytesRetry() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        bytes32 saved = keccak256(abi.encode(host.outputAt(id, 0)));
        address[3] memory targets =
            [address(scopedFactory), host.entropySourceSet(), host.terminalReadiness()];
        for (uint256 i; i < targets.length; ++i) {
            bytes memory original = targets[i].code;
            vm.etch(targets[i], hex"00");
            vm.expectRevert();
            host.requireCurrentCheckpoint(id);
            require(keccak256(abi.encode(host.outputAt(id, 0))) == saved);
            vm.etch(targets[i], original);
            host.requireCurrentCheckpoint(id);
        }
    }

    function testScopedPolicyFactoryBindingsAndCanonicalDependencyTupleRejectSubstitution() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        address set = host.entropySourceSet();
        Factory other = new Factory(_scopedDependencies());
        StaticRouteVm(address(vm))
            .mockCall(set, abi.encodeCall(E.factory, ()), abi.encode(address(other)));
        vm.expectRevert();
        host.begin(selection, 0);
        StaticRouteVm(address(vm))
            .mockCall(set, abi.encodeCall(E.factory, ()), abi.encode(address(scopedFactory)));
        PolicyReads.Dependencies memory d = _scopedDependencies();
        bytes memory canonical = abi.encode(d);
        StaticRouteVm(address(vm))
            .mockCall(
                address(scopedFactory),
                abi.encodeWithSignature("dependencies()"),
                abi.encodePacked(canonical, bytes32(0))
            );
        vm.expectRevert();
        host.begin(selection, 0);
        StaticRouteVm(address(vm))
            .mockCall(address(scopedFactory), abi.encodeWithSignature("dependencies()"), canonical);
        ++d.readGas;
        StaticRouteVm(address(vm))
            .mockCall(
                address(scopedFactory), abi.encodeWithSignature("dependencies()"), abi.encode(d)
            );
        vm.expectRevert();
        host.begin(selection, 0);
        StaticRouteVm(address(vm))
            .mockCall(address(scopedFactory), abi.encodeWithSignature("dependencies()"), canonical);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        host.requireCurrentCheckpoint(id);
    }

    function testScopedPolicyWrongScopeCannotBorrowAnotherGenuineFactorySet() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory release_ = _scopedScope(2);
        (Checkpoint host, bytes32 releaseSelection) = _scopedCapture(release_);
        StreamFinalityScope memory season = _scopedScope(3);
        (Checkpoint other, bytes32 seasonSelection) = _scopedCapture(season);
        require(host.entropySourceSet() != other.entropySourceSet());
        vm.expectRevert();
        host.begin(seasonSelection, 0);
        address source = host.entropySourceSet();
        address wrongReadiness = other.terminalReadiness();
        vm.expectRevert();
        _scopedCheckpoint(source, wrongReadiness);
        bytes32 id = host.begin(releaseSelection, 0);
        host.append(id, _scopedPayload(release_));
        host.requireCurrentCheckpoint(id);
    }

    function testScopedPolicyCollectionViewAndMalformedScopesStayOutsideProfile() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory token = _scopedScope(1);
        (Checkpoint host,) = _scopedCapture(token);
        require(host.supportsInterface(type(O).interfaceId));
        require(
            !host.supportsInterface(type(CollectionO).interfaceId)
                && !host.supportsInterface(type(OriginalO).interfaceId)
        );
        require(
            host.scopedPolicyProfile()
                == keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")
        );
        StreamFinalityScope memory collection =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        bytes32 selection = scopedSelections.begin(collection);
        scopedSelections.append(selection, 16);
        vm.expectRevert(abi.encodeWithSelector(O.InvalidStaticContentConfiguration.selector));
        host.begin(selection, 0);
        StreamFinalityScope memory view_ = _scopedScope(4);
        (Checkpoint viewHost, bytes32 viewSelection) = _scopedCapture(view_);
        vm.expectRevert(abi.encodeWithSelector(O.InvalidStaticContentConfiguration.selector));
        viewHost.begin(viewSelection, 0);
        token.scopeId = bytes32(uint256(1));
        vm.expectRevert();
        scopedSelections.begin(token);
        StreamFinalityScope memory release_ =
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 91, view_.scopeId);
        vm.expectRevert();
        scopedSelections.begin(release_);
    }

    function testScopedPolicyPartialCaptureEventsAndExactCompletion() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(3);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        O.Payload[] memory whole = _scopedPayload(scope);
        O.Payload[] memory one = new O.Payload[](1);
        one[0] = whole[0];
        bytes32 salt = keccak256("incremental capture salt");
        vm.recordLogs();
        bytes32 id = host.begin(selection, salt);
        host.append(id, one);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 2 && logs[0].emitter == address(host) && logs[1].emitter == address(host)
        );
        require(logs[0].topics[1] == id && logs[1].topics[1] == id && logs[1].topics[2] == 0);
        (uint16 startedVersion, bytes32 eventSalt, O.Plan memory initial) =
            abi.decode(logs[0].data, (uint16, bytes32, O.Plan));
        require(
            startedVersion == 2 && eventSalt == salt && initial.nextIndex == 0
                && initial.tokenCount == 2
        );
        (uint16 appendedVersion, O.Output memory first, bytes32 firstLeafHash) =
            abi.decode(logs[1].data, (uint16, O.Output, bytes32));
        require(
            appendedVersion == 2
                && keccak256(abi.encode(first)) == keccak256(abi.encode(host.outputAt(id, 0)))
        );
        require(firstLeafHash == Tree.leafHash(block.chainid, address(core), first.leaf));
        require(host.checkpoint(id).nextIndex == 1 && host.checkpoint(id).contentRoot == 0);
        vm.expectRevert(abi.encodeWithSelector(O.StaticContentIncomplete.selector, id));
        host.requireCurrentCheckpoint(id);
        one[0] = whole[1];
        vm.recordLogs();
        host.append(id, one);
        logs = vm.getRecordedLogs();
        require(
            logs.length == 2 && logs[0].emitter == address(host) && logs[1].emitter == address(host)
        );
        require(logs[0].topics[1] == id && logs[0].topics[2] == bytes32(uint256(1)));
        require(
            logs[1].topics[0]
                    == keccak256("StaticContentCompleted(uint16,bytes32,bytes32,bytes32,uint64)")
                && logs[1].topics[1] == id
        );
        (uint16 completedVersion, bytes32 contentRoot, bytes32 outputRoot, uint64 count) =
            abi.decode(logs[1].data, (uint16, bytes32, bytes32, uint64));
        O.Plan memory finalPlan = host.requireCurrentCheckpoint(id);
        require(
            completedVersion == 2 && count == 2 && contentRoot == finalPlan.contentRoot
                && outputRoot == finalPlan.outputRoot
        );
        _assertRoots(host, id);
    }

    function testScopedPolicyFullOriginalPolicyDriftRejectsDespiteSameTerminalStatus() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (Checkpoint host, bytes32 selection) = _scopedCapture(scope);
        bytes32 id = host.begin(selection, 0);
        host.append(id, _scopedPayload(scope));
        bytes32 saved = keccak256(abi.encode(host.checkpoint(id), host.outputAt(id, 0)));
        EP.PolicyRecord memory policy = EP(address(terminalCoordinator)).collectionEntropyPolicy(1);
        bytes memory original = abi.encode(policy);
        policy.artistConsentRecord =
            keccak256("different historical receipt, unchanged status/policy hash");
        // Deliberate negative read corruption of one original native getter, never a positive
        // replacement SourceSet or fabricated finalized seed.
        StaticRouteVm(address(vm))
            .mockCall(
                address(terminalCoordinator),
                abi.encodeCall(EP.collectionEntropyPolicy, (uint256(1))),
                abi.encode(policy)
            );
        vm.expectRevert();
        host.requireCurrentCheckpoint(id);
        require(keccak256(abi.encode(host.checkpoint(id), host.outputAt(id, 0))) == saved);
        StaticRouteVm(address(vm))
            .mockCall(
                address(terminalCoordinator),
                abi.encodeCall(EP.collectionEntropyPolicy, (uint256(1))),
                original
            );
        host.requireCurrentCheckpoint(id);
    }

    function _assertRoots(Checkpoint host, bytes32 id) private view {
        O.Plan memory p = host.requireCurrentCheckpoint(id);
        StreamTokenContentLeaf[] memory leaves = new StreamTokenContentLeaf[](p.tokenCount);
        bytes32 leafChain;
        bytes32 outputChain;
        for (uint256 i; i < p.tokenCount; ++i) {
            O.Output memory row = host.outputAt(id, i);
            leaves[i] = row.leaf;
            require(row.leaf.metadataHash == keccak256(bytes(router.tokenJSON(row.leaf.tokenId))));
            require(row.leaf.animationHash == keccak256(bytes(router.tokenHTML(row.leaf.tokenId))));
            require(row.leaf.imageHash == keccak256(hex"89504e470d0a1a0a"));
            require(row.leaf.tokenDataHash == keccak256(hex"00ff6529"));
            leafChain = keccak256(
                abi.encode(
                    keccak256("6529STREAM_SCOPED_POLICY_CONTENT_LEAVES_V2"),
                    leafChain,
                    i,
                    Tree.leafHash(block.chainid, address(core), row.leaf)
                )
            );
            outputChain = keccak256(
                abi.encode(
                    keccak256("6529STREAM_SCOPED_POLICY_FULL_OUTPUTS_V2"), outputChain, i, row
                )
            );
        }
        require(p.contentRoot == Tree.root(block.chainid, address(core), leaves));
        require(p.leafChainHash == leafChain && p.outputRoot == outputChain);
    }
}
