// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/ScopeMembershipPublicationFixture.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../helpers/EntropyFinalityEvidenceFixture.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import "../entropy/EntropyCollectionPolicyFixtures.sol";
import {
    StreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityEntropyPolicySourceFactoryV2 as CollectionFactory
} from "../../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as PolicyReads
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamFinalityEntropyPolicySourceSet as SourceSet
} from "../../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Source
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamEntropyCollectionPolicy as Policy
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    StreamFinalityCoordinatorPolicyV2
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityCoordinatorPolicyTypesV2.sol";
import "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceFactoryV2.sol";

interface ScopedPolicyFactoryVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
}

/// @notice Actual factory/CREATE source sets, complete inventories, native Coordinators and
/// Metadata/Schema/Store/sealed membership. Core mint identity, Artist consent, module admission
/// and governance execution remain explicit typed boundaries; no combined finality ceremony.
contract StreamFinalityScopedEntropyPolicySourceFactoryV2Test is
    ScopeMembershipPublicationFixture,
    EntropyTimeAuthorityFixture
{
    ScopedPolicyFactoryVm private constant cheat =
        ScopedPolicyFactoryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");
    bytes32 private constant METADATA = keccak256("COLLECTION_METADATA");

    struct Fixture {
        StreamEntropyCoordinator terminal;
        StreamEntropyCoordinator random;
        StreamFinalityCoordinatorInventory sources;
        EntropyFinalityModuleBoundary modules;
        Factory factory;
        uint256[] ids;
        bytes32 finalizedSeed;
    }

    function testEveryNonCollectionScopeUsesActualFactoryAndCompleteOriginalPolicySet() public {
        Fixture memory f = _fixture(true);
        for (uint8 kind = 1; kind <= 4; ++kind) {
            StreamFinalityScope memory scope = _scope(f, kind);
            bytes32 plan = _complete(f, scope);
            address created = f.factory.prepareSourceSet(scope);
            SourceSet source = SourceSet(created);
            (address saved, bytes32 runtime) = f.factory.sourceSetForPlan(plan);
            require(saved == created && runtime == created.codehash);
            require(source.factory() == address(f.factory) && source.core() == address(core));
            require(source.inventoryPlan() == plan);
            require(keccak256(abi.encode(source.sourceScope())) == keccak256(abi.encode(scope)));
            require(source.sourceCount() == (kind == 1 ? 1 : 2));
            StreamFinalityCurrentComponentRoute memory route = f.factory.requireCurrentRoute(scope);
            StreamFinalityComponentExpectation memory component =
                f.factory.requireCurrentComponent(scope);
            require(route.component == created && route.codeHash == runtime);
            require(route.interfaceId == type(IStreamArtworkScopedFinalityComponent).interfaceId);
            require(component.dataHash == source.finalityStateForScope(scope).dataHash);
            require(component.interfaceId == route.interfaceId);
            require(source.tokenEntropyReadiness(f.ids[0]).terminal);
            vm.expectRevert(abi.encodeWithSelector(SourceSet.SourceSetScope.selector));
            source.finalityState(1);
        }
    }

    function testSameNumericScopeIdCannotCrossReleaseSeasonOrView() public {
        Fixture memory f = _fixture(true);
        StreamFinalityScope memory release_ = _scope(f, 2);
        bytes32 plan = _complete(f, release_);
        address created = f.factory.prepareSourceSet(release_);
        bytes32 releaseSubject =
            StreamMetadataSubjects.scopeSubject(block.chainid, address(core), release_);
        for (uint8 kind = 3; kind <= 4; ++kind) {
            StreamFinalityScope memory other =
                StreamFinalityScope(StreamFinalityScopeType(kind), 1, 0, release_.scopeId);
            require(
                StreamMetadataSubjects.scopeSubject(block.chainid, address(core), other)
                    != releaseSubject
            );
            vm.expectRevert();
            f.factory.currentInventoryPlan(other);
            vm.expectRevert();
            f.factory.prepareSourceSet(other);
            vm.expectRevert(abi.encodeWithSelector(SourceSet.SourceSetScope.selector));
            SourceSet(created).finalityStateForScope(other);
            StreamFinalityScope memory actual = _scope(f, kind);
            bytes32 actualPlan = _complete(f, actual);
            require(actualPlan != plan && actual.scopeId != release_.scopeId);
            require(f.factory.prepareSourceSet(actual) != created);
        }
    }

    function testFullExplicitPolicyAndFinalizedSeedAreDistinctAndBoundToOriginalAtMint() public {
        Fixture memory f = _fixture(true);
        StreamFinalityScope memory scope = _scope(f, 4);
        _complete(f, scope);
        SourceSet source = SourceSet(f.factory.prepareSourceSet(scope));
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(f.random));
        Source.TokenReadiness memory terminal = source.tokenEntropyReadiness(f.ids[0]);
        Source.TokenReadiness memory finalized = source.tokenEntropyReadiness(f.ids[1]);
        require(terminal.coordinator == address(f.terminal) && terminal.status == 1);
        require(terminal.terminal && !terminal.finalized && terminal.seed == 0);
        require(finalized.coordinator == address(f.random) && finalized.status == 5);
        require(
            !finalized.terminal && finalized.finalized && finalized.seed == f.finalizedSeed
                && finalized.seed != 0
        );
        Policy.PolicyRecord memory p = Policy(address(f.terminal)).collectionEntropyPolicy(1);
        StreamFinalityCoordinatorPolicyV2 memory saved = source.sourcePolicyAt(0);
        require(keccak256(abi.encode(saved.collectionPolicy)) == keccak256(abi.encode(p)));
        require(
            saved.componentDataHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V2"),
                        block.chainid,
                        address(core),
                        address(f.terminal),
                        scope,
                        p
                    )
                )
        );
        (bool ok,) = address(source)
            .staticcall(abi.encodeWithSignature("tokenSeedForFinality(uint256)", f.ids[0]));
        require(!ok, "terminal cannot masquerade as original finalized-seed API");
    }

    function testBurnedMembersRetainRealSeedsAndPreparedIdentityCannotPass() public {
        Fixture memory f = _fixture(true);
        StreamFinalityScope memory scope = _scope(f, 4);
        _complete(f, scope);
        SourceSet source = SourceSet(f.factory.prepareSourceSet(scope));
        core.setToken(f.ids[0], 1, 1, 3);
        core.setToken(f.ids[1], 1, 2, 3);
        require(source.tokenEntropyReadiness(f.ids[0]).terminal);
        require(source.tokenEntropyReadiness(f.ids[1]).seed == f.finalizedSeed);
        core.setToken(f.ids[1], 1, 2, 1);
        vm.expectRevert(abi.encodeWithSelector(SourceSet.SourceSetToken.selector, f.ids[1]));
        source.tokenEntropyReadiness(f.ids[1]);
        core.setToken(f.ids[1], 1, 2, 3);
        require(source.tokenEntropyReadiness(f.ids[1]).finalized);
    }

    function testPendingActualTokenNeverBecomesFinalizedFromFrozenPolicy() public {
        Fixture memory f = _fixture(false);
        StreamFinalityScope memory scope = _scope(f, 3);
        _complete(f, scope);
        SourceSet source = SourceSet(f.factory.prepareSourceSet(scope));
        Source.TokenReadiness memory pending = source.tokenEntropyReadiness(f.ids[1]);
        require(!pending.finalized && !pending.terminal && pending.seed == 0 && pending.status != 5);
        // Policy-source completeness is not output readiness. A later output checkpoint must
        // reject this row until actual token finalization or an explicitly permitted terminal.
        require(source.finalityStateForScope(scope).frozen);
    }

    function testIncompleteInventoryCannotPublishAndExactContinuationRetries() public {
        Fixture memory f = _fixture(true);
        StreamFinalityScope memory scope = _scope(f, 2);
        bytes32 plan = f.sources.beginInventory(scope);
        f.sources.appendInventory(plan, 1);
        vm.expectRevert();
        f.factory.prepareSourceSet(scope);
        (address absent, bytes32 hash) = f.factory.sourceSetForPlan(plan);
        require(absent == address(0) && hash == 0);
        f.sources.appendInventory(plan, 1);
        require(f.factory.prepareSourceSet(scope) != address(0));
    }

    function testFactoryAndRuntimeSubstitutionRefuseWithoutChangingRetainedPlan() public {
        Fixture memory f = _fixture(true);
        StreamFinalityScope memory scope = _scope(f, 2);
        bytes32 plan = _complete(f, scope);
        address source = f.factory.prepareSourceSet(scope);
        cheat.mockCall(source, abi.encodeCall(Source.factory, ()), abi.encode(address(this)));
        vm.expectRevert(abi.encodeWithSelector(Factory.EntropySourceSetChanged.selector, source));
        f.factory.requireCurrentRoute(scope);
        cheat.mockCall(source, abi.encodeCall(Source.factory, ()), abi.encode(address(f.factory)));
        f.factory.requireCurrentRoute(scope);
        bytes memory original = source.code;
        vm.etch(source, hex"00");
        vm.expectRevert(abi.encodeWithSelector(Factory.EntropySourceSetChanged.selector, source));
        f.factory.prepareSourceSet(scope);
        vm.etch(source, original);
        (address retained, bytes32 runtime) = f.factory.sourceSetForPlan(plan);
        require(retained == source && runtime == source.codehash);
        require(f.factory.prepareSourceSet(scope) == source);
    }

    function testCurrentMetadataSelectionAndRevocationInvalidateRouteButPreserveHistory() public {
        Fixture memory f = _fixture(true);
        StreamFinalityScope memory scope = _scope(f, 4);
        _complete(f, scope);
        SourceSet source = SourceSet(f.factory.prepareSourceSet(scope));
        bytes32 before = source.finalityStateForScope(scope).dataHash;
        _selected(f.modules, address(artist), 1);
        vm.expectRevert();
        f.factory.requireCurrentRoute(scope);
        _selected(f.modules, address(metadata), 3);
        vm.expectRevert();
        f.factory.requireCurrentComponent(scope);
        _selected(f.modules, address(metadata), 1);
        f.modules.setEligible(false);
        vm.expectRevert();
        f.factory.requireCurrentRoute(scope);
        require(
            source.finalityStateForScope(scope).dataHash == before,
            "immutable observation differs from new admission"
        );
        f.modules.setEligible(true);
        require(f.factory.requireCurrentComponent(scope).dataHash == before);
    }

    function testChangedFullPolicyRefusesCurrentReadAndExactRestoreRetries() public {
        Fixture memory f = _fixture(true);
        StreamFinalityScope memory scope = _scope(f, 4);
        _complete(f, scope);
        address source = f.factory.prepareSourceSet(scope);
        Policy.PolicyRecord memory p = Policy(address(f.terminal)).collectionEntropyPolicy(1);
        bytes memory original = abi.encode(p);
        p.lastActionId = keccak256("foreign policy action");
        cheat.mockCall(
            address(f.terminal),
            abi.encodeCall(Policy.collectionEntropyPolicy, (uint256(1))),
            abi.encode(p)
        );
        vm.expectRevert();
        f.factory.requireCurrentRoute(scope);
        vm.expectRevert();
        f.factory.prepareSourceSet(scope);
        cheat.mockCall(
            address(f.terminal),
            abi.encodeCall(Policy.collectionEntropyPolicy, (uint256(1))),
            original
        );
        require(f.factory.prepareSourceSet(scope) == source);
    }

    function testDistinctCapabilityAndOriginalCollectionFactoryRemainClosed() public {
        Fixture memory f = _fixture(true);
        require(
            f.factory.scopedPolicyFactoryProfile()
                == keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        );
        require(
            f.factory
                .supportsInterface(
                    type(IStreamFinalityScopedEntropyPolicySourceFactoryV2).interfaceId
                )
        );
        require(
            !f.factory
                .supportsInterface(type(IStreamFinalityEntropyPolicySourceFactoryV2).interfaceId)
        );
        require(
            keccak256(abi.encode(f.factory.dependencies()))
                == keccak256(abi.encode(_dependencies(f.sources)))
        );
        CollectionFactory collection = new CollectionFactory(_dependencies(f.sources));
        StreamFinalityScope memory old =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        _complete(f, old);
        require(collection.prepareSourceSet(old) != address(0));
        vm.expectRevert(abi.encodeWithSelector(Factory.EntropyPolicyFactoryScope.selector));
        f.factory.prepareSourceSet(old);
        StreamFinalityScope memory token = _scope(f, 1);
        vm.expectRevert(
            abi.encodeWithSelector(CollectionFactory.EntropyPolicyFactoryScope.selector)
        );
        collection.prepareSourceSet(token);
        token.scopeId = bytes32(uint256(token.tokenId));
        vm.expectRevert(abi.encodeWithSelector(Factory.EntropyPolicyFactoryScope.selector));
        f.factory.currentInventoryPlan(token);
        token = StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(Factory.EntropyPolicyFactoryScope.selector));
        f.factory.currentInventoryPlan(token);
    }

    function testEmptySealedScopeNeverInventsFrozenSourceAndWrongPinsRefuse() public {
        Fixture memory f = _fixture(true);
        uint256[] memory none = new uint256[](0);
        StreamFinalityScope memory scope = _seal(4, none, "ipfs://empty-policy-scope");
        bytes32 plan = f.sources.beginInventory(scope);
        vm.expectRevert(abi.encodeWithSelector(SourceSet.SourceSetEvidence.selector));
        f.factory.prepareSourceSet(scope);
        (address absent,) = f.factory.sourceSetForPlan(plan);
        require(absent == address(0));
        PolicyReads.Dependencies memory d = _dependencies(f.sources);
        d.codeHashes[3] ^= bytes32(uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(PolicyReads.PolicyDependency.selector, address(f.sources))
        );
        new Factory(d);
    }

    function testIdempotentPreparationEmitsOneActualFactoryEventAndChainChangeRefuses() public {
        Fixture memory f = _fixture(true);
        StreamFinalityScope memory scope = _scope(f, 4);
        bytes32 plan = _complete(f, scope);
        vm.recordLogs();
        address source = f.factory.prepareSourceSet(scope);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(f.factory));
        require(
            logs[0].topics[0]
                == keccak256("EntropySourceSetPrepared(bytes32,address,bytes32,bytes32,bytes32)")
        );
        require(logs[0].topics[1] == plan && logs[0].topics[2] == bytes32(uint256(uint160(source))));
        require(logs[0].topics[3] == membership.requireScopeMembership(scope).scopeSubject);
        require(
            keccak256(logs[0].data)
                == keccak256(abi.encode(source.codehash, SourceSet(source).sourceSetDataHash()))
        );
        vm.recordLogs();
        require(f.factory.prepareSourceSet(scope) == source);
        require(vm.getRecordedLogs().length == 0);
        uint256 originalChain = block.chainid;
        vm.chainId(originalChain + 1);
        vm.expectRevert(abi.encodeWithSelector(PolicyReads.PolicyConfiguration.selector));
        f.factory.requireCurrentRoute(scope);
        vm.chainId(originalChain);
        f.factory.requireCurrentRoute(scope);
    }

    function _fixture(bool finalize) private returns (Fixture memory f) {
        MockEntropyRoleRegistry roles = new MockEntropyRoleRegistry(address(this));
        f.modules = new EntropyFinalityModuleBoundary(address(this));
        core.setPointer(keccak256("MODULE_REGISTRY"), address(f.modules));
        cheat.mockCall(
            address(core),
            abi.encodeWithSignature("collectionFreezeStatus(uint256)", 1),
            abi.encode(false)
        );
        f.terminal = _native(roles);
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(f.terminal));
        EntropyCollectionPolicyArtistFixture policyArtist =
            new EntropyCollectionPolicyArtistFixture(address(core));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(policyArtist));
        Policy.PolicyInput memory input;
        input.renderRequirement = Policy.RenderRequirement.NOT_REQUIRED;
        (bytes32 subject, bytes32 before, bytes32 after_, bytes32 content) =
            Policy(address(f.terminal)).collectionEntropyPolicyTransition(1, input);
        policyArtist.approve(
            1, address(f.terminal), FAMILY, content, keccak256("typed original consent")
        );
        this.setCurrentAction(true, keccak256("typed policy action"), 1, subject, before, after_);
        Policy(address(f.terminal)).configureCollectionEntropyPolicy(1, input);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
        f.random = _native(roles);
        f.ids = _tokens(2);
        _index(f.ids, 0, 2);
        for (uint256 i; i < 2; ++i) {
            StreamEntropyCoordinator original = i == 0 ? f.terminal : f.random;
            core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(original));
            cheat.mockCall(
                address(core),
                abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (f.ids[i])),
                abi.encode(address(original))
            );
            vm.prank(address(core));
            original.onTokenMinted(
                1, f.ids[i], address(this), keccak256(abi.encode("scoped native token", i))
            );
        }
        if (finalize) {
            (, uint256 requestId) = f.random.requestEntropy(f.ids[1]);
            (,, address provider,,) = f.random.entropyPolicyFrozen(1);
            require(
                MockStreamEntropyProvider(provider)
                    .fulfill(requestId, keccak256("actual finalized random bytes")) == 0
            );
            bool done;
            (f.finalizedSeed, done) = f.random.tokenSeed(f.ids[1]);
            require(done && f.finalizedSeed != 0);
        }
        f.sources = new StreamFinalityCoordinatorInventory(
            address(core), address(membership), 100000, 2000000
        );
        _selected(f.modules, address(metadata), 1);
        f.factory = new Factory(_dependencies(f.sources));
    }

    function _native(MockEntropyRoleRegistry roles) private returns (StreamEntropyCoordinator n) {
        n = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roles),
                EntropyTimeTestConfigs.parameters(),
                keccak256("deployment"),
                "ipfs://native-policy",
                keccak256("native manifest")
            )
        );
        MockStreamEntropyProvider provider = new MockStreamEntropyProvider(address(n));
        _admitEntropyProvider(address(n), address(provider));
        n.configureCollection(1, address(provider), keccak256("salt"), true, 10);
        n.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
    }

    function _selected(EntropyFinalityModuleBoundary registry, address host, uint8 status) private {
        StreamMetadataRecoveryRoutes.Pointer memory pointer = StreamMetadataRecoveryRoutes.Pointer(
            host,
            host.codehash,
            false,
            METADATA,
            type(IStreamCollectionMetadataV1).interfaceId,
            address(registry),
            status,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            1
        );
        cheat.mockCall(
            address(core),
            abi.encodeWithSignature("getSatellitePointer(bytes32)", METADATA),
            abi.encode(pointer)
        );
    }

    function _scope(Fixture memory f, uint8 kind) private returns (StreamFinalityScope memory) {
        if (kind == 1) return StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, f.ids[0], 0);
        return _seal(kind, f.ids, "ipfs://scoped-policy");
    }

    function _complete(Fixture memory f, StreamFinalityScope memory scope)
        private
        returns (bytes32 plan)
    {
        plan = f.sources.beginInventory(scope);
        f.sources.appendInventory(plan, 256);
    }

    function _dependencies(StreamFinalityCoordinatorInventory sources)
        private
        view
        returns (PolicyReads.Dependencies memory d)
    {
        d.targets = [address(core), address(metadata), address(membership), address(sources)];
        for (uint256 i; i < 4; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.inventoryGas = 3000000;
    }
}
