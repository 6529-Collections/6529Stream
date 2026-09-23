// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamCurrentFinalityGraph } from "../../script/current/StreamCurrentFinalityGraph.sol";
import { StreamDeploymentSlot } from "../../script/current/StreamDeploymentSlot.sol";
import {
    StreamArtistOnboardingRegistry
} from "../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";

import { StreamArtistSuiteFixture } from "../helpers/StreamArtistSuiteFixture.sol";
import {
    StreamCurrentFinalityArtifacts
} from "../../script/current/StreamCurrentFinalityArtifacts.sol";

import "./StreamCurrentFullV1Activation.t.sol";
import {
    StreamCurrentFullPreservationPolicyGraph
} from "../../script/current/StreamCurrentFullPreservationPolicyGraph.sol";
import {
    StreamCurrentFullPreservationPolicyCreation as PreservationCreation
} from "../../script/current/StreamCurrentFullPreservationPolicyCreation.sol";
import {
    StreamNativeFullPreservationPolicyCreation as NativePreservationCreation
} from "../helpers/StreamNativeFullPreservationPolicyCreation.sol";
import {
    StreamFinalityDiscoveryTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";
import {
    StreamFinalityFullPreservationPolicyEvidenceProviderV1 as FullProvider
} from "../../smart-contracts/domains/finality/StreamFinalityFullPreservationPolicyEvidenceProviderV1.sol";
import {
    IStreamFinalityPreservationFactoryProfileSourcesV1 as Catalogue
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityPreservationFactoryProfileSourcesV1.sol";
import {
    IStreamFinalityProfileSources as OldCatalogue
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamPolicyOutputEvidenceBindingV2 as OldOutput
} from "../../smart-contracts/interfaces/stream/finality/IStreamPolicyOutputEvidenceBindingV2.sol";
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as CollectionGraph
} from "../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as ScopedGraph
} from "../../smart-contracts/interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    IStreamPreservationPolicyPublicationFactoryV1 as CurrentCollectionFactory
} from "../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationFactoryV1.sol";
import {
    IStreamPreservationPolicyPublicationGraphBindingV1
} from "../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationGraphBindingV1.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as CurrentContent
} from "../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as CurrentOutput
} from "../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    IStreamFinalityFactoryProfileSourcesV2 as OriginalFactoryCatalogue
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityFactoryProfileSourcesV2.sol";
import {
    IStreamViewPreservationEvidenceBindingV1 as ViewEvidence
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationEvidenceBindingV1.sol";
import {
    IStreamFinalityViewPreservationBindingV1 as ViewBinding
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as ViewTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";

import {
    IStreamViewSourceBinding as ViewDeclaration
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewSourceBinding.sol";
import {
    IStreamViewPolicySourceBindingV2 as ViewPolicy
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewPolicySourceBindingV2.sol";
import {
    IStreamViewRouteReadBudgetV1 as ViewBudget
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewRouteReadBudgetV1.sol";

/// @notice The original 37-role construction and eleven Safe activation scenarios use the
/// preservation factory provider from genesis. Six additional cases exercise genuine first-mint graphs.
/// @dev External randomness/VRF/ARRNG/delegation services retain the original explicit doubles.
/// Finality, Artifact, Core, Metadata, Artist, Safe and every graph product are actual contracts.
/// This proves no completed output archive, authoritative root, snapshot or finality ceremony.
contract StreamCurrentFullPreservationPolicyConstructionTest is
    StreamCurrentFullV1ActivationTest,
    StreamCurrentFullPreservationPolicyGraph
{
    // Resolve the existing test/script diamond to the fixed test slot worker.
    function _slot()
        internal
        virtual
        override(StreamCurrentFinalityGraph, StreamArtistSuiteFixture)
        returns (StreamDeploymentSlot slot, address expected)
    {
        return StreamArtistSuiteFixture._slot();
    }

    function _deploySlot(
        StreamDeploymentSlot slot,
        address expected,
        bytes memory creation,
        bytes memory args,
        bytes memory runtime
    )
        internal
        virtual
        override(StreamCurrentFinalityGraph, StreamArtistSuiteFixture)
        returns (address product)
    {
        return StreamArtistSuiteFixture._deploySlot(slot, expected, creation, args, runtime);
    }

    function _deploySplitArtistFacade(
        bytes memory creation,
        address operator_,
        address factory_,
        address[5] memory p,
        bytes32 deploymentHash,
        string memory uri,
        bytes32 manifestHash
    )
        internal
        virtual
        override(StreamCurrentFinalityGraph, StreamArtistSuiteFixture)
        returns (StreamArtistOnboardingRegistry)
    {
        return StreamArtistSuiteFixture._deploySplitArtistFacade(
            creation, operator_, factory_, p, deploymentHash, uri, manifestHash
        );
    }

    function _deploySplitArtistIdentity(
        bytes memory creation,
        address operator_,
        address factory_,
        address[5] memory p
    )
        internal
        virtual
        override(StreamCurrentFinalityGraph, StreamArtistSuiteFixture)
        returns (address host)
    {
        return StreamArtistSuiteFixture._deploySplitArtistIdentity(creation, operator_, factory_, p);
    }

    // Select the test verifier explicitly where the test and script graph bases join.
    function _runtime(
        string memory artifactPath,
        string[] memory declarationArtifacts,
        bytes memory linkedCreation,
        RuntimeValue[] memory values
    )
        internal
        view
        virtual
        override(StreamCurrentFinalityArtifacts, StreamArtistSuiteFixture)
        returns (bytes memory)
    {
        return StreamArtistSuiteFixture._runtime(
            artifactPath, declarationArtifacts, linkedCreation, values
        );
    }

    function _linkRuntime(string memory artifact, bytes memory linkedCreation)
        internal
        view
        virtual
        override(StreamCurrentFinalityArtifacts, StreamArtistSuiteFixture)
        returns (bytes memory, bytes memory)
    {
        return StreamArtistSuiteFixture._linkRuntime(artifact, linkedCreation);
    }

    function _preservationGraphCreation(PreservationCreation.Kind kind)
        internal
        view
        override
        returns (bytes memory)
    {
        return NativePreservationCreation.creation(NativePreservationCreation.Kind(uint256(kind)));
    }

    function testActualFull37HasAcyclicFactoryProviderAndOriginalFinalityArtistPins() public view {
        FullPolicyCompanionState memory companions = _fullPolicyCompanionState();
        _requireFullPolicyCompanionsUnchanged(companions);
        StreamFullV1Candidate.Inventory memory all =
            StreamFullV1Candidate.capture(foundation, configuration, products);
        require(
            all.roles.length == 37 && savedInventoryHash == StreamFullV1Candidate.inventoryHash(all)
        );
        require(artistCoordinator.finalityRegistry() == address(assemblyFinality));
        require(assemblyFinality.scopeEvidenceProvider() == address(assemblyProvider));
        require(assemblyFinality.artifactCoverage() == address(assemblyArtifact));
        FullProvider full = FullProvider(address(assemblyProvider));
        require(full.supportsInterface(type(ViewEvidence).interfaceId));
        require(full.supportsInterface(type(ViewBinding).interfaceId));
        require(
            full.supportsInterface(type(ViewDeclaration).interfaceId)
                && full.supportsInterface(type(ViewPolicy).interfaceId)
                && full.supportsInterface(type(ViewBudget).interfaceId)
        );
        require(full.viewPreservationBindingStatus() == 0);
        require(full.viewPreservationBindingReceipt().recordHash == 0);
        bytes4[7] memory viewGetters = [
            ViewEvidence.viewPreservationSnapshotHost.selector,
            ViewEvidence.viewPreservationSnapshotCodeHash.selector,
            ViewEvidence.viewPreservationSnapshotValidationGas.selector,
            ViewDeclaration.viewSourceBinding.selector,
            ViewPolicy.viewPolicySourceFactoryV2.selector,
            ViewPolicy.viewPolicySourceFactoryV2CodeHash.selector,
            ViewBudget.viewRouteReadBudget.selector
        ];
        for (uint256 i; i < viewGetters.length; ++i) {
            (bool ok, bytes memory failure) =
                address(full).staticcall(abi.encodeWithSelector(viewGetters[i]));
            require(
                !ok
                    && keccak256(failure)
                        == keccak256(
                            abi.encodeWithSelector(ViewTypes.ViewPreservationPending.selector)
                        )
            );
        }
        require(full.supportsInterface(type(Catalogue).interfaceId));
        require(!full.supportsInterface(type(OriginalFactoryCatalogue).interfaceId));
        require(
            full.preservationFactorySourceProfile()
                == keccak256("6529STREAM_FINALITY_PRESERVATION_FACTORY_PROFILE_SOURCES_V1")
        );
        require(!full.supportsInterface(type(OldCatalogue).interfaceId));
        require(!full.supportsInterface(type(OldOutput).interfaceId));
        require(
            full.collectionPreservationPolicyPublicationBinding().factory
                == address(fullPolicyCollectionFactory)
        );
        require(
            full.scopedPreservationPolicyPublicationBinding().factory
                == address(fullPolicyScopedFactory)
        );
        require(core.collectionMintedEver(1) == 0, "factories precede first real mint");
        StreamFinalityNativeProviderReads.Config memory native = full.nativeConfiguration();
        for (uint256 i; i < 22; ++i) {
            require(native.targets[i].code.length != 0 && native.targets[i].code.length <= 24576);
            require(native.targets[i].codehash == native.codeHashes[i]);
        }
    }

    function testActualEmptyCollectionCannotBecomePolicyEvidence() public {
        StreamFinalityScope memory scope = _collectionScope();
        assemblyTokens.scanCollectionTokens(1, 256);
        bytes32 plan = assemblyCoordinators.beginInventory(scope);
        require(assemblyCoordinators.requireCompleteInventory(plan).complete);
        vm.expectRevert();
        fullPolicyCollectionSources.prepareSourceSet(scope);
        vm.expectRevert();
        fullPolicyCollectionFactory.prepareGraph(scope, 7);
        require(fullPolicyCollectionFactory.graphForPlan(plan).preparedChildren == 0);
    }

    function testGenuinePaidMintAllowsBoundedLateChildrenAndRootFreeOutputResolution() public {
        _fullPolicyMint(1);
        StreamFinalityScope memory scope = _collectionScope();
        bytes32 plan = _fullPolicyIndex(scope);
        address source = fullPolicyCollectionSources.prepareSourceSet(scope);
        CollectionGraph.Graph memory g = fullPolicyCollectionFactory.prepareGraph(scope, 2);
        require(g.preparedChildren == 2 && g.inventoryPlan == plan && g.sourceSet == source);
        vm.expectRevert();
        fullPolicyCollectionFactory.requireCurrentGraph(scope);
        g = fullPolicyCollectionFactory.prepareGraph(scope, 5);
        require(g.preparedChildren == 7 && g.inventoryPlan == plan);
        bytes32 saved = keccak256(abi.encode(g));
        require(keccak256(abi.encode(fullPolicyCollectionFactory.prepareGraph(scope, 7))) == saved);
        require(
            keccak256(abi.encode(fullPolicyCollectionFactory.requireCurrentGraph(scope))) == saved
        );
        for (uint256 i; i < 7; ++i) {
            require(g.children[i].code.length != 0 && g.children[i].code.length <= 24576);
            require(g.children[i].codehash == g.codeHashes[i]);
        }
        require(router.collectionContentRootHead(1) == 0, "first root not invented");
        // Construction-only root-free identity resolution. Actual root publication and its
        // consent/archive checks belong to the separate preservation ceremony host.
        IStreamPreservationPolicyPublicationGraphBindingV1.CollectionFactoryBinding memory b =
            FullProvider(address(assemblyProvider)).collectionPreservationPolicyPublicationBinding();
        require(
            b.factory == address(fullPolicyCollectionFactory)
                && b.factory.codehash == b.factoryCodeHash && b.configurationHash != 0
        );
        CollectionGraph.Graph memory selected =
            CurrentCollectionFactory(b.factory).requireCurrentGraph(scope);
        require(keccak256(abi.encode(selected)) == saved);
        CurrentOutput output = CurrentOutput(selected.children[2]);
        CurrentContent checkpoint = CurrentContent(selected.children[1]);
        require(address(output).codehash == selected.codeHashes[2]);
        require(
            output.contentCheckpoint() == address(checkpoint)
                && output.artifactCoverage() == address(assemblyArtifact)
        );
        require(
            output.outputProfile() == keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1")
                && checkpoint.preservationPolicyProfile() == output.outputProfile()
        );
        require(
            checkpoint.entropySourceSet() == selected.sourceSet
                && checkpoint.terminalReadiness() == selected.children[0]
        );
        require(
            FullProvider(address(assemblyProvider)).finalitySourcesForScope(scope).profile.snapshots
                == address(assemblySnapshots),
            "publication selects profile; construction does not"
        );
    }

    function testGenuineNewMembershipRequiresNewGraphAndRetainsOriginalPlan() public {
        _fullPolicyMint(1);
        StreamFinalityScope memory scope = _collectionScope();
        bytes32 oldPlan = _fullPolicyIndex(scope);
        fullPolicyCollectionSources.prepareSourceSet(scope);
        CollectionGraph.Graph memory oldGraph = fullPolicyCollectionFactory.prepareGraph(scope, 7);
        _fullPolicyMint(2);
        vm.expectRevert();
        fullPolicyCollectionFactory.requireCurrentGraph(scope);
        bytes32 nextPlan = _fullPolicyIndex(scope);
        require(nextPlan != oldPlan);
        fullPolicyCollectionSources.prepareSourceSet(scope);
        CollectionGraph.Graph memory next = fullPolicyCollectionFactory.prepareGraph(scope, 7);
        require(next.graphId != oldGraph.graphId && next.sourceSet != oldGraph.sourceSet);
        for (uint256 i; i < 7; ++i) {
            require(next.children[i] != oldGraph.children[i]);
        }
        require(
            keccak256(abi.encode(fullPolicyCollectionFactory.graphForPlan(oldPlan)))
                == keccak256(abi.encode(oldGraph)),
            "retained original graph unchanged"
        );
    }

    function testGenuineTokenGraphUsesDistinctScopedProducts() public {
        uint256 tokenId = _fullPolicyMint(1);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, tokenId, 0);
        _fullPolicyIndex(scope);
        fullPolicyScopedSources.prepareSourceSet(scope);
        ScopedGraph.Graph memory g = fullPolicyScopedFactory.prepareGraph(scope, 7);
        require(g.preparedChildren == 7 && g.scope.tokenId == tokenId);
        require(
            keccak256(abi.encode(fullPolicyScopedFactory.requireCurrentGraph(scope)))
                == keccak256(abi.encode(g))
        );
        vm.expectRevert();
        fullPolicyCollectionFactory.prepareGraph(scope, 7);
        vm.expectRevert();
        fullPolicyScopedFactory.prepareGraph(_collectionScope(), 7);
    }

    function testFactoryCatalogueDoesNotInventStaticCollectionPolicyHost() public {
        FullProvider full = FullProvider(address(assemblyProvider));
        require(full.finalitySourceProfile(0).snapshots == address(assemblySnapshots));
        require(full.finalitySourceProfile(1).snapshots == address(fullPolicyScopedSnapshots));
        vm.expectRevert();
        full.finalitySourceProfile(2);
        vm.expectRevert();
        fullPolicyCollectionFactory.requireCurrentGraph(_collectionScope());
    }

    function _fullPolicyMint(uint256 nonce) private returns (uint256 tokenId) {
        vm.deal(address(this), 1 ether);
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            IStreamFixedPriceSaleAdapter.SaleAuthorization({
                collectionId: 1,
                phaseId: PHASE,
                payer: address(this),
                recipient: BUYER,
                artist: artist,
                profileId: profile,
                expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256(abi.encode("full-preservation-policy", nonce)),
                mintPolicyHash: manager.phasePolicyHash(1, PHASE),
                price: 0.01 ether,
                nonce: keccak256(abi.encode("full-preservation-policy-sale", nonce)),
                deadline: uint64(block.timestamp + 1 days),
                signerEpoch: sale.signerEpoch()
            });
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        bytes memory platformSignature = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(ARTIST_KEY, digest);
        (tokenId,) =
            sale.buy{ value: a.price }(a, TOKEN_DATA, platformSignature, abi.encodePacked(r, s, v));
        require(
            core.ownerOf(tokenId) == BUYER && core.coordinatorAtMint(tokenId) == address(entropy)
        );
        (, uint256 request) = entropy.requestEntropy(tokenId);
        provider.fulfill(request, keccak256(abi.encode("full-preservation-policy-entropy", nonce)));
        require(entropy.tokenEntropyStatus(tokenId) == StreamEntropyStatus.FINALIZED);
    }

    function _fullPolicyIndex(StreamFinalityScope memory scope) private returns (bytes32 plan) {
        assemblyTokens.scanCollectionTokens(scope.collectionId, 256);
        plan = assemblyCoordinators.beginInventory(scope);
        assemblyCoordinators.appendInventory(plan, 256);
        require(assemblyCoordinators.requireCompleteInventory(plan).complete);
    }

    function _collectionScope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _assemblyProviderName()
        internal
        pure
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (string memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyProviderName();
    }

    function _assemblyProviderParents()
        internal
        pure
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (string[] memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyProviderParents();
    }

    function _assemblyProviderCreation()
        internal
        view
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (bytes memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyProviderCreation();
    }

    function _assemblyProviderArguments(StreamFinalityNativeProviderReads.Config memory c)
        internal
        view
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (bytes memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyProviderArguments(c);
    }

    function _assemblyDiscoveryName()
        internal
        pure
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (string memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyDiscoveryName();
    }

    function _assemblyDiscoveryCreation()
        internal
        view
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (bytes memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyDiscoveryCreation();
    }

    function _assemblyDiscoveryArguments(StreamFinalityDiscoveryTypes.Configuration memory d)
        internal
        view
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (bytes memory)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyDiscoveryArguments(d);
    }

    function _assemblyComponentSourceGas()
        internal
        pure
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (uint256)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyComponentSourceGas();
    }

    function _assemblyManifestSourceGas()
        internal
        pure
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
        returns (uint256)
    {
        return StreamCurrentFullPreservationPolicyGraph._assemblyManifestSourceGas();
    }

    function _prepareAssemblyProviderCompanions()
        internal
        override(StreamCurrentFinalityGraph, StreamCurrentFullPreservationPolicyGraph)
    {
        StreamCurrentFullPreservationPolicyGraph._prepareAssemblyProviderCompanions();
    }
}
