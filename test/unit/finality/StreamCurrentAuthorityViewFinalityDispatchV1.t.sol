// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1 as Host
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedProviderReads as Scoped
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedProviderReads.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1 as Graph
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyGraphSelectionV1 as CollectionGraph
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityPreservationPolicyGraphSelectionV1.sol";
import {
    StreamFinalityFactoryProfileSourceReadsV2 as Profiles
} from "../../../smart-contracts/domains/finality/StreamFinalityFactoryProfileSourceReadsV2.sol";
import {
    IStreamFinalityProfileSources as Catalogue
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as GraphBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    IStreamPreservationPolicyPublicationGraphBindingV1 as CollectionBinding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyPublicationGraphBindingV1.sol";
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as GraphTypes
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderReadsV1 as Policy
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyProviderReadsV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyProviderOperationsV1 as PolicyOperations
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPreservationPolicyProviderOperationsV1.sol";
import {
    StreamCurrentAuthorityScopedProviderOperations as ScopedOperations
} from "../../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedProviderOperations.sol";
import {
    StreamFinalityViewPreservationConfigurationV1 as ViewConfiguration
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationConfigurationV1.sol";
import {
    StreamFinalityViewPreservationComponentsV1 as ViewComponents
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationComponentsV1.sol";
import {
    StreamFinalityViewPreservationMetadataV1 as ViewMetadata
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationMetadataV1.sol";
import {
    StreamFinalityViewPreservationOperationsV1 as ViewOperations
} from "../../../smart-contracts/domains/finality/StreamFinalityViewPreservationOperationsV1.sol";
import {
    StreamFinalityRouterEvidence as RouterEvidence
} from "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";
import {
    IStreamMetadataServingFacts as Serving
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamMetadataRouter as Router
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    IStreamFinalitySanctionReview as Sanction
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalitySanctionReview.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityDomains as Domains,
    StreamFinalityComponentExpectation
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityScopeInputs,
    StreamFinalityHostComponentFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

interface CurrentAuthorityViewDispatchVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function prank(address) external;
    function etch(address, bytes calldata) external;
}

/// @dev Explicit constructor read boundary; no actual source admission is claimed.
contract CurrentAuthorityViewDispatchTable {
    mapping(bytes32 => bytes) private answers;

    function set(bytes memory input, bytes memory output) external {
        answers[keccak256(input)] = output;
    }

    fallback(bytes calldata input) external returns (bytes memory) {
        bytes memory output = answers[keccak256(input)];
        require(output.length != 0, "unconfigured typed topology");
        return output;
    }
}

/// @notice Actual Host ten-surface dispatch and original Registry guards.
/// @dev Constructor graph and fixed linked worker calls are exact-calldata synthetic boundaries.
/// Every VIEW case poisons legacy graph selection, so a branch ordered after it cannot pass.
/// Host component identity/family gate and prepared caller/runtime guards execute. Actual VIEW
/// pins/scope/membership remain inside the named worker boundary, including compatibility with the
/// current-authority inventory dependency hash. This does not prove configuration, source admission,
/// evidence, signature, Safe/Governance, complete Finality, or runtime capacity. Prior one-use binding
/// tests are separate; no raw inventory-hash fallback is exercised or endorsed here.
contract StreamCurrentAuthorityViewFinalityDispatchV1Test {
    CurrentAuthorityViewDispatchVm private constant vm =
        CurrentAuthorityViewDispatchVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant MANIFEST = keccak256("exact requested VIEW manifest");
    bytes32 private constant SCHEMA = keccak256("synthetic returned manifest schema");
    bytes32 private constant CANON = keccak256("synthetic returned manifest canon");
    Native.Config private original;
    Scoped.Config private scoped;
    Graph.Context private graph;
    CollectionGraph.Context private collection;
    Host private host;
    StreamFinalityScope private viewScope;
    bytes32 private sourceHash;
    error UnexpectedBoundaryArguments();
    error LegacySelectionConsulted();
    error ViewBoundaryRejected();

    function setUp() public {
        for (uint256 i; i < 22; ++i) {
            original.targets[i] = address(new CurrentAuthorityViewDispatchTable());
            original.codeHashes[i] = original.targets[i].codehash;
        }
        original.chainId = block.chainid;
        original.readGas = 1000000;
        original.componentSourceGas = 16000000;
        original.sourceGas = 40000000;
        original.inventoryDependencyHash = keccak256("fixed original inventory");
        scoped = abi.decode(abi.encode(original), (Scoped.Config));
        address executor = address(new CurrentAuthorityViewDispatchTable());
        _set(original.targets[1], "core()", abi.encode(original.targets[0]));
        _set(original.targets[1], "governanceAuthority()", abi.encode(executor));
        _set(original.targets[1], "executorCodeHash()", abi.encode(executor.codehash));
        _set(original.targets[2], "core()", abi.encode(original.targets[0]));
        _set(original.targets[3], "core()", abi.encode(original.targets[0]));
        _set(original.targets[3], "metadataHost()", abi.encode(original.targets[1]));
        _support(original.targets[2], type(Serving).interfaceId);
        _support(original.targets[2], type(Router).interfaceId);
        for (uint256 i = 1; i < 3; ++i) {
            _set(original.targets[i], "streamModuleVersion()", abi.encode(_version(i)));
            _set(
                original.targets[i], "streamModuleManifest()", abi.encode("urn:fixture", _module(i))
            );
        }
        GraphBinding.FactoryBinding memory b;
        b.factory = address(new CurrentAuthorityViewDispatchTable());
        b.factoryCodeHash = b.factory.codehash;
        b.recipeHash = keccak256("scoped recipe");
        b.sourceFactoryDependenciesHash = keccak256("scoped factory dependencies");
        b.graphGas = 4000000;
        b.configurationHash = keccak256("admitted scoped graph");
        graph.original = original;
        graph.binding = b;
        GraphBinding.FactoryBinding memory input =
            abi.decode(abi.encode(b), (GraphBinding.FactoryBinding));
        input.configurationHash = 0;
        _allow(
            address(Graph),
            Graph.initialize.selector,
            abi.encodeWithSelector(Graph.initialize.selector, original, input),
            abi.encode(graph)
        );
        CollectionBinding.CollectionFactoryBinding memory cb;
        cb.factory = address(new CurrentAuthorityViewDispatchTable());
        cb.factoryCodeHash = cb.factory.codehash;
        cb.recipeHash = keccak256("collection recipe");
        cb.sourceFactoryDependenciesHash = keccak256("collection factory dependencies");
        cb.graphGas = 4000000;
        cb.configurationHash = keccak256("admitted collection graph");
        collection.original = original;
        collection.binding = cb;
        CollectionBinding.CollectionFactoryBinding memory ci =
            abi.decode(abi.encode(cb), (CollectionBinding.CollectionFactoryBinding));
        ci.configurationHash = 0;
        _allow(
            address(CollectionGraph),
            CollectionGraph.initialize.selector,
            abi.encodeWithSelector(CollectionGraph.initialize.selector, original, ci),
            abi.encode(collection)
        );
        host = new Host(original, scoped, ci, input);
        sourceHash = keccak256(
            abi.encode(
                keccak256(
                    "6529STREAM_CURRENT_AUTHORITY_PRESERVATION_FACTORY_SOURCE_CONFIGURATION_V1"
                ),
                block.chainid,
                address(host),
                original,
                scoped,
                cb,
                b
            )
        );
        require(host.finalitySourceConfigurationHash() == sourceHash);
        viewScope = StreamFinalityScope(
            StreamFinalityScopeType.VIEW, 7, 0, keccak256("actual tuple boundary")
        );
        _poisonLegacy();
        _poisonView();
    }

    function testViewCatalogueAndThreeMetadataSurfacesUseExactOriginalBeforeLegacy() public {
        Catalogue.Sources memory sources = _sources(viewScope);
        _allow(
            address(ViewConfiguration),
            ViewConfiguration.catalogue.selector,
            abi.encodeWithSelector(ViewConfiguration.catalogue.selector, original, viewScope),
            abi.encode(sources)
        );
        _allow(
            address(ViewMetadata),
            ViewMetadata.root.selector,
            abi.encodeWithSelector(ViewMetadata.root.selector, original, viewScope),
            abi.encode(bytes32(uint256(71)), uint64(3), SCHEMA)
        );
        _allow(
            address(ViewMetadata),
            ViewMetadata.snapshot.selector,
            abi.encodeWithSelector(ViewMetadata.snapshot.selector, original, viewScope),
            abi.encode(bytes32(uint256(72)))
        );
        _allow(
            address(ViewMetadata),
            ViewMetadata.manifest.selector,
            abi.encodeWithSelector(ViewMetadata.manifest.selector, original, viewScope),
            abi.encode(true, bytes32(uint256(73)))
        );
        _equal(
            abi.encodeCall(host.finalitySourcesForScope, (viewScope)), abi.encode(sources), false
        );
        _equal(
            abi.encodeCall(host.scopedContentRoot, (viewScope)),
            abi.encode(bytes32(uint256(71)), uint64(3), SCHEMA),
            false
        );
        _equal(
            abi.encodeCall(host.scopedSnapshotHash, (viewScope)),
            abi.encode(bytes32(uint256(72))),
            false
        );
        _equal(
            abi.encodeCall(host.scopedManifest, (viewScope)),
            abi.encode(true, bytes32(uint256(73))),
            false
        );
        require(host.finalitySourceConfigurationHash() == sourceHash);
    }

    function testViewComponentsRetainMetadataVersusRouterIdentityAndClosedFamilyGate() public {
        bytes32[7] memory families = [
            Domains.COMPONENT_COLLECTION_METADATA,
            Domains.COMPONENT_METADATA_ROUTER,
            Domains.COMPONENT_RENDERER,
            Domains.COMPONENT_RENDER_CONTEXT,
            Domains.COMPONENT_MEDIA_MANIFEST,
            Domains.COMPONENT_SCRIPT_SOURCE,
            Domains.COMPONENT_DEPENDENCY_SOURCE
        ];
        for (uint256 i; i < families.length; ++i) {
            bytes32 data = keccak256(abi.encode("VIEW facts", families[i]));
            _allow(
                address(ViewComponents),
                ViewComponents.facts.selector,
                abi.encodeWithSelector(
                    ViewComponents.facts.selector, original, viewScope, families[i]
                ),
                abi.encode(i != 3, data)
            );
            uint256 role = i == 0 ? 1 : 2;
            StreamFinalityHostComponentFacts memory expected =
                StreamFinalityHostComponentFacts(i != 3, _version(role), _module(role), data);
            _equal(
                abi.encodeCall(host.finalityComponentFacts, (families[i], viewScope)),
                abi.encode(expected),
                false
            );
        }
        bytes32 unknown = keccak256("not a supported Router component");
        // Worker dispatch is first; even an unknown family must not reach legacy selection.
        _reject(
            abi.encodeCall(host.finalityComponentFacts, (unknown, viewScope)),
            abi.encodeWithSelector(UnexpectedBoundaryArguments.selector),
            false
        );
        // Explicit synthetic worker acceptance still cannot bypass the host's Router family gate.
        _allow(
            address(ViewComponents),
            ViewComponents.facts.selector,
            abi.encodeWithSelector(ViewComponents.facts.selector, original, viewScope, unknown),
            abi.encode(true, bytes32(uint256(99)))
        );
        _reject(
            abi.encodeCall(host.finalityComponentFacts, (unknown, viewScope)),
            abi.encodeWithSelector(RouterEvidence.RouterEvidenceFamily.selector, unknown),
            false
        );
    }

    function testViewManifestInputsAndReviewPreserveEveryReturnedWordAndOccurrence() public {
        bytes memory manifest = hex"00112233445566778899aabbccddeeff";
        StreamFinalityScopeInputs memory inputs = _inputs();
        Sanction.ReviewFacts memory review = _review();
        _allow(
            address(ViewOperations),
            ViewOperations.manifest.selector,
            abi.encodeWithSelector(ViewOperations.manifest.selector, original, viewScope),
            abi.encode(manifest)
        );
        _allow(
            address(ViewOperations),
            ViewOperations.inputs.selector,
            abi.encodeWithSelector(ViewOperations.inputs.selector, original, viewScope, MANIFEST),
            abi.encode(inputs, SCHEMA, CANON)
        );
        _allow(
            address(ViewOperations),
            ViewOperations.review.selector,
            abi.encodeWithSelector(ViewOperations.review.selector, original, viewScope, MANIFEST),
            abi.encode(review)
        );
        _equal(abi.encodeCall(host.inputManifestBytes, (viewScope)), abi.encode(manifest), false);
        _equal(
            abi.encodeCall(host.requireFinalityScopeInputs, (viewScope, MANIFEST)),
            abi.encode(inputs, SCHEMA, CANON),
            false
        );
        _equal(
            abi.encodeCall(host.requireSanctionReviewFacts, (viewScope, MANIFEST)),
            abi.encode(review),
            false
        );
        _reject(
            abi.encodeCall(host.requireFinalityScopeInputs, (viewScope, bytes32(uint256(1)))),
            abi.encodeWithSelector(UnexpectedBoundaryArguments.selector),
            false
        );
    }

    function testBothPreparedPathsRequirePinnedOriginalAndKeepExactComponentsAndReviewFlag()
        public
    {
        StreamFinalityComponentExpectation[] memory components = _components();
        StreamFinalityScopeInputs memory inputs = _inputs();
        Sanction.ReviewFacts memory review = _review();
        _allow(
            address(ViewOperations),
            ViewOperations.prepared.selector,
            abi.encodeWithSelector(
                ViewOperations.prepared.selector, original, viewScope, MANIFEST, components, false
            ),
            abi.encode(inputs, SCHEMA, CANON, review)
        );
        _equal(
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputs, (viewScope, MANIFEST, components)
            ),
            abi.encode(inputs, SCHEMA, CANON),
            true
        );
        // Reject the first tuple before admitting the second so either flipped flag fails.
        vm.mockCallRevert(
            address(ViewOperations),
            abi.encodeWithSelector(
                ViewOperations.prepared.selector, original, viewScope, MANIFEST, components, false
            ),
            abi.encodeWithSelector(UnexpectedBoundaryArguments.selector)
        );
        _allow(
            address(ViewOperations),
            ViewOperations.prepared.selector,
            abi.encodeWithSelector(
                ViewOperations.prepared.selector, original, viewScope, MANIFEST, components, true
            ),
            abi.encode(inputs, SCHEMA, CANON, review)
        );
        _equal(
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputsAndReview, (viewScope, MANIFEST, components)
            ),
            abi.encode(inputs, SCHEMA, CANON, review),
            true
        );
        // The boundary accepts only the complete ordered tuple, never a selector-only prefix.
        components[1].dataHash ^= bytes32(uint256(1));
        _reject(
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputsAndReview, (viewScope, MANIFEST, components)
            ),
            abi.encodeWithSelector(UnexpectedBoundaryArguments.selector),
            true
        );
    }

    function testWrongCallerRejectedBeforeViewOrLegacyDispatchForBothPreparedPaths() public {
        StreamFinalityComponentExpectation[] memory components = _components();
        StreamFinalityScope[3] memory scopes = [
            viewScope,
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, 0),
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 7, 0, keccak256("release"))
        ];
        bytes memory reason =
            abi.encodeWithSelector(Host.NativeProviderOriginalRegistryOnly.selector);
        for (uint256 i; i < scopes.length; ++i) {
            _reject(
                abi.encodeCall(
                    host.requirePreparedFinalityScopeInputs, (scopes[i], MANIFEST, components)
                ),
                reason,
                false
            );
            _reject(
                abi.encodeCall(
                    host.requirePreparedFinalityScopeInputsAndReview,
                    (scopes[i], MANIFEST, components)
                ),
                reason,
                false
            );
        }
    }

    function testOriginalAddressWithChangedRuntimeCannotReachEitherPreparedWorker() public {
        bytes memory runtime = original.targets[12].code;
        vm.etch(original.targets[12], hex"00");
        bytes memory reason =
            abi.encodeWithSelector(Host.NativeProviderOriginalRegistryOnly.selector);
        StreamFinalityComponentExpectation[] memory components = _components();
        _reject(
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputs, (viewScope, MANIFEST, components)
            ),
            reason,
            true
        );
        _reject(
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputsAndReview, (viewScope, MANIFEST, components)
            ),
            reason,
            true
        );
        vm.etch(original.targets[12], runtime);
        // Restored original caller passes the host gate and reaches the named VIEW boundary.
        _reject(
            abi.encodeCall(
                host.requirePreparedFinalityScopeInputs, (viewScope, MANIFEST, components)
            ),
            abi.encodeWithSelector(ViewBoundaryRejected.selector),
            true
        );
    }

    function testAllTenViewFailuresPropagateWithoutLegacyFallback() public {
        bytes[] memory calls = _viewCalls();
        bytes memory reason = abi.encodeWithSelector(ViewBoundaryRejected.selector);
        for (uint256 i; i < calls.length; ++i) {
            _reject(calls[i], reason, i >= 8);
        }
        require(host.finalitySourceConfigurationHash() == sourceHash);
    }

    function testNonViewSelectedPreservationStillUsesItsExistingGraphAndWorkers() public {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 7, 0, keccak256("release"));
        _allow(
            address(Graph),
            Graph.isPolicy.selector,
            abi.encodeWithSelector(Graph.isPolicy.selector, graph, scope),
            abi.encode(true)
        );
        Catalogue.Sources memory sources = _sources(scope);
        _allow(
            address(Graph),
            Graph.sources.selector,
            abi.encodeWithSelector(Graph.sources.selector, graph, scope),
            abi.encode(sources)
        );
        Policy.Config memory selected = abi.decode(abi.encode(original), (Policy.Config));
        selected.inventoryDependencyHash = keccak256("distinct selected preservation config");
        GraphTypes.Graph memory g;
        _allow(
            address(Graph),
            Graph.current.selector,
            abi.encodeWithSelector(Graph.current.selector, graph, scope),
            abi.encode(selected, g)
        );
        bytes memory manifest = bytes("unchanged selected preservation path");
        _allow(
            address(PolicyOperations),
            PolicyOperations.manifest.selector,
            abi.encodeWithSelector(PolicyOperations.manifest.selector, selected, scope),
            abi.encode(manifest)
        );
        _equal(abi.encodeCall(host.finalitySourcesForScope, (scope)), abi.encode(sources), false);
        _equal(abi.encodeCall(host.inputManifestBytes, (scope)), abi.encode(manifest), false);
    }

    function testNonPolicyScopedAndCollectionCatalogueFallbacksNeverEnterViewWorkers() public {
        Profiles.Context memory c;
        c.core = original.targets[0];
        c.router = original.targets[2];
        c.routerCodeHash = original.codeHashes[2];
        c.chainId = block.chainid;
        c.readGas = original.readGas;
        c.profiles[0] = host.finalitySourceProfile(0);
        c.profiles[1] = host.finalitySourceProfile(1);
        for (uint8 kind; kind < 4; ++kind) {
            StreamFinalityScope memory scope = StreamFinalityScope(
                StreamFinalityScopeType(kind),
                7,
                kind == 1 ? 99 : 0,
                kind > 1 ? keccak256(abi.encode(kind)) : bytes32(0)
            );
            _allow(
                address(Graph),
                Graph.isPolicy.selector,
                abi.encodeWithSelector(Graph.isPolicy.selector, graph, scope),
                abi.encode(false)
            );
            _allow(
                address(CollectionGraph),
                CollectionGraph.isPolicy.selector,
                abi.encodeWithSelector(CollectionGraph.isPolicy.selector, collection, scope),
                abi.encode(false)
            );
            Catalogue.Sources memory sources = _sources(scope);
            _allow(
                address(Profiles),
                Profiles.current.selector,
                abi.encodeWithSelector(Profiles.current.selector, c, scope),
                abi.encode(sources)
            );
            _equal(
                abi.encodeCall(host.finalitySourcesForScope, (scope)), abi.encode(sources), false
            );
            if (kind == 0) continue;
            bytes memory manifest = abi.encode("unchanged ordinary scoped path", kind);
            _allow(
                address(ScopedOperations),
                ScopedOperations.manifest.selector,
                abi.encodeWithSelector(ScopedOperations.manifest.selector, scoped, scope),
                abi.encode(manifest)
            );
            _equal(abi.encodeCall(host.inputManifestBytes, (scope)), abi.encode(manifest), false);
        }
    }

    function _viewCalls() private view returns (bytes[] memory calls) {
        calls = new bytes[](10);
        calls[0] = abi.encodeCall(host.finalitySourcesForScope, (viewScope));
        calls[1] =
            abi.encodeCall(host.finalityComponentFacts, (Domains.COMPONENT_RENDERER, viewScope));
        calls[2] = abi.encodeCall(host.scopedContentRoot, (viewScope));
        calls[3] = abi.encodeCall(host.scopedSnapshotHash, (viewScope));
        calls[4] = abi.encodeCall(host.scopedManifest, (viewScope));
        calls[5] = abi.encodeCall(host.inputManifestBytes, (viewScope));
        calls[6] = abi.encodeCall(host.requireFinalityScopeInputs, (viewScope, MANIFEST));
        calls[7] = abi.encodeCall(host.requireSanctionReviewFacts, (viewScope, MANIFEST));
        calls[8] = abi.encodeCall(
            host.requirePreparedFinalityScopeInputs, (viewScope, MANIFEST, _components())
        );
        calls[9] = abi.encodeCall(
            host.requirePreparedFinalityScopeInputsAndReview, (viewScope, MANIFEST, _components())
        );
    }

    function _inputs() private pure returns (StreamFinalityScopeInputs memory) {
        bytes32[10] memory words;
        for (uint256 i; i < 10; ++i) {
            words[i] = bytes32(i + 100);
        }
        return abi.decode(abi.encode(words), (StreamFinalityScopeInputs));
    }

    function _review() private pure returns (Sanction.ReviewFacts memory r) {
        r.schemaVersion = 1;
        r.profile = 2;
        r.contentRoot = keccak256("returned VIEW root");
        r.mediaContentHashes = new bytes32[](0);
        r.referenceRenderContentHashes = new bytes32[](3);
        r.referenceRenderContentHashes[0] = keccak256("first occurrence");
        r.referenceRenderContentHashes[1] = keccak256("middle occurrence");
        r.referenceRenderContentHashes[2] = r.referenceRenderContentHashes[0];
    }

    function _components() private view returns (StreamFinalityComponentExpectation[] memory rows) {
        rows = new StreamFinalityComponentExpectation[](2);
        rows[0] = StreamFinalityComponentExpectation(
            bytes32(uint256(11)),
            original.targets[15],
            bytes4(0x11223344),
            original.codeHashes[15],
            bytes32(uint256(12)),
            bytes32(uint256(13)),
            bytes32(uint256(14))
        );
        rows[1] = StreamFinalityComponentExpectation(
            bytes32(uint256(21)),
            original.targets[16],
            bytes4(0x55667788),
            original.codeHashes[16],
            bytes32(uint256(22)),
            bytes32(uint256(23)),
            bytes32(uint256(24))
        );
    }

    function _sources(StreamFinalityScope memory scope)
        private
        view
        returns (Catalogue.Sources memory s)
    {
        s.scope = scope;
        s.profile = Catalogue.Profile(
            keccak256("synthetic selected profile"),
            original.targets[9],
            original.codeHashes[9],
            original.targets[8],
            original.codeHashes[8],
            original.targets[10],
            original.codeHashes[10],
            keccak256(abi.encode(scope))
        );
    }

    function _poisonLegacy() private {
        bytes memory reason = abi.encodeWithSelector(LegacySelectionConsulted.selector);
        vm.mockCallRevert(address(Graph), abi.encodePacked(Graph.isPolicy.selector), reason);
        vm.mockCallRevert(
            address(CollectionGraph), abi.encodePacked(CollectionGraph.isPolicy.selector), reason
        );
        vm.mockCallRevert(address(Profiles), abi.encodePacked(Profiles.current.selector), reason);
    }

    function _poisonView() private {
        _poison(address(ViewConfiguration), ViewConfiguration.catalogue.selector);
        _poison(address(ViewComponents), ViewComponents.facts.selector);
        _poison(address(ViewMetadata), ViewMetadata.root.selector);
        _poison(address(ViewMetadata), ViewMetadata.snapshot.selector);
        _poison(address(ViewMetadata), ViewMetadata.manifest.selector);
        _poison(address(ViewOperations), ViewOperations.manifest.selector);
        _poison(address(ViewOperations), ViewOperations.inputs.selector);
        _poison(address(ViewOperations), ViewOperations.review.selector);
        _poison(address(ViewOperations), ViewOperations.prepared.selector);
    }

    function _poison(address target, bytes4 selector) private {
        vm.mockCallRevert(
            target,
            abi.encodePacked(selector),
            abi.encodeWithSelector(ViewBoundaryRejected.selector)
        );
    }

    function _allow(address target, bytes4 selector, bytes memory input, bytes memory output)
        private
    {
        vm.mockCallRevert(
            target,
            abi.encodePacked(selector),
            abi.encodeWithSelector(UnexpectedBoundaryArguments.selector)
        );
        vm.mockCall(target, input, output);
    }

    function _equal(bytes memory input, bytes memory expected, bool originalCaller) private {
        if (originalCaller) vm.prank(original.targets[12]);
        (bool ok, bytes memory output) = address(host).staticcall(input);
        require(ok && keccak256(output) == keccak256(expected), "exact host forwarding result");
    }

    function _reject(bytes memory input, bytes memory expected, bool originalCaller) private {
        if (originalCaller) vm.prank(original.targets[12]);
        (bool ok, bytes memory output) = address(host).staticcall(input);
        require(!ok && keccak256(output) == keccak256(expected), "exact first rejection");
    }

    function _set(address target, string memory signature, bytes memory output) private {
        CurrentAuthorityViewDispatchTable(target).set(abi.encodeWithSignature(signature), output);
    }

    function _support(address target, bytes4 id) private {
        CurrentAuthorityViewDispatchTable t = CurrentAuthorityViewDispatchTable(target);
        t.set(abi.encodeCall(IERC165.supportsInterface, (id)), abi.encode(true));
        t.set(
            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)), abi.encode(true)
        );
        t.set(abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(false));
    }

    function _version(uint256 role) private pure returns (bytes32) {
        return keccak256(abi.encode("module version", role));
    }

    function _module(uint256 role) private pure returns (bytes32) {
        return keccak256(abi.encode("module manifest", role));
    }
}
