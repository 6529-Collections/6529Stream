// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityFullPreservationDispatchV1 as GraphDispatch
} from "./StreamCurrentAuthorityFullPreservationDispatchV1.sol";
import {
    StreamFinalityViewProviderBindingTransportV1 as ViewBindingTransport
} from "./StreamFinalityViewProviderBindingTransportV1.sol";
import "./StreamCurrentAuthorityScopedPolicyBaseEvidenceProviderV2.sol";
import {
    StreamFinalityPreservationPolicyProviderComponentsV1 as PolicyComponents
} from "./StreamFinalityPreservationPolicyProviderComponentsV1.sol";
import {
    StreamFinalityFactoryProfileSourceReadsV2 as ProfileSelection
} from "./StreamFinalityFactoryProfileSourceReadsV2.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamCurrentAuthorityPreservationPolicyProviderOperationsV1 as PolicyOperations
} from "./StreamCurrentAuthorityPreservationPolicyProviderOperationsV1.sol";
import {
    IStreamScopedPreservationPolicyContentRootEvidenceBindingV1
} from "../../interfaces/stream/finality/IStreamScopedPreservationPolicyContentRootEvidenceBindingV1.sol";
import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as GraphBinding
} from "../../interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1 as GraphSelection
} from "./StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderReadsV1 as ScopedPolicyReads
} from "./StreamFinalityScopedPreservationPolicyProviderReadsV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyProviderOperationsV1 as ScopedPolicyOperations
} from "./StreamCurrentAuthorityScopedPreservationPolicyProviderOperationsV1.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderMetadataV1 as ScopedPolicyMetadata
} from "./StreamFinalityScopedPreservationPolicyProviderMetadataV1.sol";
import {
    StreamFinalityScopedPreservationPolicyMetadataFactsV1 as ScopedPolicyFacts
} from "./StreamFinalityScopedPreservationPolicyMetadataFactsV1.sol";
import {
    StreamFinalityScopedPreservationPolicyStaticComponentsV1 as ScopedPolicyStatic
} from "./StreamFinalityScopedPreservationPolicyStaticComponentsV1.sol";
import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as ScopedPolicySnapshots
} from "./StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";

import {
    IStreamFinalityPreservationFactoryProfileSourcesV1 as Catalogue
} from "../../interfaces/stream/finality/IStreamFinalityPreservationFactoryProfileSourcesV1.sol";
import {
    IStreamPreservationPolicyPublicationGraphBindingV1 as CollectionBinding
} from "../../interfaces/stream/finality/IStreamPreservationPolicyPublicationGraphBindingV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyGraphSelectionV1 as CollectionSelection
} from "./StreamCurrentAuthorityPreservationPolicyGraphSelectionV1.sol";
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as CollectionGraph
} from "../../interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";

import {
    IStreamViewPreservationEvidenceBindingV1
} from "../../interfaces/stream/finality/IStreamViewPreservationEvidenceBindingV1.sol";
import {
    IStreamFinalityViewPreservationBindingV1
} from "../../interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as ViewBindingTypes
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationBindingV1 as ViewBinding
} from "./StreamFinalityViewPreservationBindingV1.sol";

import {
    IStreamViewSourceBinding
} from "../../interfaces/stream/finality/IStreamViewSourceBinding.sol";
import {
    StreamViewAdoptionTypes as ViewDeclarationTypes
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";

import {
    IStreamViewPolicySourceBindingV2
} from "../../interfaces/stream/finality/IStreamViewPolicySourceBindingV2.sol";
import {
    StreamFinalityViewPolicyFactoryBindingV1 as ViewPolicyFactory
} from "./StreamFinalityViewPolicyFactoryBindingV1.sol";

import {
    IStreamViewRouteReadBudgetV1
} from "../../interfaces/stream/finality/IStreamViewRouteReadBudgetV1.sol";
import {
    IStreamFinalityViewPreservationCompleteBindingV1
} from "../../interfaces/stream/finality/IStreamFinalityViewPreservationCompleteBindingV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1
} from "../../interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    StreamFinalityViewPreservationCompleteBindingTypesV1 as CompleteViewBinding
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationCompleteBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationConfigurationV1 as ViewConfiguration
} from "./StreamFinalityViewPreservationConfigurationV1.sol";
import {
    StreamFinalityViewPreservationComponentsV1 as ViewComponents
} from "./StreamFinalityViewPreservationComponentsV1.sol";
import {
    StreamFinalityViewPreservationMetadataV1 as ViewMetadata
} from "./StreamFinalityViewPreservationMetadataV1.sol";
import {
    StreamFinalityViewPreservationOperationsV1 as ViewOperations
} from "./StreamFinalityViewPreservationOperationsV1.sol";

/// @notice Current-authority provider for original static and genuine preservation graphs.
/// @dev COLLECTION/scoped catalogues are constructor-only; VIEW is one-time class2 bound. Current canonical Router profile
/// chooses the collection branch; no source receipt is cast across profiles. Prior deployment
/// identities and records are not inherited. VIEW uses its separately bound complete sources.
contract StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1 is
    StreamCurrentAuthorityScopedPolicyBaseEvidenceProviderV2,
    Catalogue,
    CollectionBinding,
    IStreamScopedPreservationPolicyContentRootEvidenceBindingV1,
    GraphBinding,
    IStreamViewPreservationEvidenceBindingV1,
    IStreamViewSourceBinding,
    IStreamViewPolicySourceBindingV2,
    IStreamViewRouteReadBudgetV1,
    IStreamFinalityViewPreservationBindingV1,
    IStreamFinalityViewPreservationCompleteBindingV1,
    IStreamViewPreservationFinalitySourcesV1
{
    ProfileSelection.Context private _sourceSelection;
    GraphSelection.Context private _graph;
    CollectionSelection.Context private _collectionGraph;
    // Constructor-only storage avoids reciprocal runtime hash cycles.
    bytes32 private _sourceConfigurationHash;
    ViewBinding.State private _viewBinding;

    // Retain original ABI error entries after their checks move into fixed workers.
    error ScopedPolicyGraphConfiguration();
    error ViewPreservationAlreadyBound();

    constructor(
        StreamFinalityNativeProviderReads.Config memory original,
        StreamFinalityScopedProviderReads.Config memory scoped,
        CollectionBinding.CollectionFactoryBinding memory collectionFactory,
        GraphBinding.FactoryBinding memory publicationFactory
    ) StreamCurrentAuthorityScopedPolicyBaseEvidenceProviderV2(original, scoped) {
        ViewBinding.initialize(_viewBinding, original);
        ProfileSelection.Context memory c;
        c.core = original.targets[0];
        c.router = original.targets[2];
        c.routerCodeHash = original.codeHashes[2];
        c.chainId = original.chainId;
        c.readGas = original.readGas;
        c.profiles[0] = _profile(original, 0, keccak256(abi.encode(original)));
        c.profiles[1] = Profiles.Profile(
            ProfileSelection.profileHash(1),
            scoped.targets[9],
            scoped.codeHashes[9],
            scoped.targets[8],
            scoped.codeHashes[8],
            scoped.targets[10],
            scoped.codeHashes[10],
            keccak256(abi.encode(scoped))
        );
        ProfileSelection.validate(c);
        _sourceSelection = c;
        _graph = GraphSelection.initialize(original, publicationFactory);
        _collectionGraph = CollectionSelection.initialize(original, collectionFactory);
        _sourceConfigurationHash = keccak256(
            abi.encode(
                keccak256(
                    "6529STREAM_CURRENT_AUTHORITY_PRESERVATION_FACTORY_SOURCE_CONFIGURATION_V1"
                ),
                block.chainid,
                address(this),
                original,
                scoped,
                _collectionGraph.binding,
                _graph.binding
            )
        );
    }

    function supportsInterface(bytes4 id)
        public
        pure
        virtual
        override(StreamCurrentAuthorityScopedPolicyBaseEvidenceProviderV2, IERC165)
        returns (bool)
    {
        return super.supportsInterface(id) || id == type(Catalogue).interfaceId
            || id == type(CollectionBinding).interfaceId
            || id == type(IStreamScopedPreservationPolicyContentRootEvidenceBindingV1).interfaceId
            || id == type(GraphBinding).interfaceId
            || id == type(IStreamViewPreservationEvidenceBindingV1).interfaceId
            || id == type(IStreamViewSourceBinding).interfaceId
            || id == type(IStreamViewPolicySourceBindingV2).interfaceId
            || id == type(IStreamViewRouteReadBudgetV1).interfaceId
            || id == type(IStreamFinalityViewPreservationCompleteBindingV1).interfaceId
            || id == type(IStreamViewPreservationFinalitySourcesV1).interfaceId
            || id == type(IStreamFinalityViewPreservationBindingV1).interfaceId;
    }

    function viewPreservationBindingProfile() external pure override returns (bytes32) {
        return ViewBindingTypes.PROFILE;
    }

    function viewPreservationBindingStatus() external view override returns (uint8) {
        return _viewBinding.receipt.recordHash == 0 ? 0 : 1;
    }

    function viewPreservationBindingCapability()
        external
        view
        override
        returns (ViewBindingTypes.Capability calldata)
    {
        _returnViewBinding(
            ViewBindingTransport.read(
                _viewBinding,
                _graph.original,
                _graph.recipe.targets[2],
                _graph.recipe.codeHashes[2],
                _graph.binding.sourceFactoryDependenciesHash,
                msg.data
            )
        );
    }

    /// @notice Historical admission facts remain readable if a bound runtime later drifts.
    function viewPreservationBindingReceipt()
        external
        view
        override
        returns (ViewBindingTypes.Receipt calldata)
    {
        _returnViewBinding(
            ViewBindingTransport.read(
                _viewBinding,
                _graph.original,
                _graph.recipe.targets[2],
                _graph.recipe.codeHashes[2],
                _graph.binding.sourceFactoryDependenciesHash,
                msg.data
            )
        );
    }

    function viewPreservationBindingTransition(
        ViewBindingTypes.Configuration calldata configuration,
        ViewDeclarationTypes.Binding calldata declaration
    ) external view override returns (ViewBindingTypes.Transition calldata) {
        _returnViewBinding(
            ViewBindingTransport.read(
                _viewBinding,
                _graph.original,
                _graph.recipe.targets[2],
                _graph.recipe.codeHashes[2],
                _graph.binding.sourceFactoryDependenciesHash,
                msg.data
            )
        );
    }

    function bindViewPreservation(
        ViewBindingTypes.Configuration calldata configuration,
        ViewDeclarationTypes.Binding calldata declaration
    ) external override returns (bytes32 recordHash) {
        _returnViewBinding(
            ViewBindingTransport.write(
                _viewBinding,
                _graph.original,
                _graph.recipe.targets[2],
                _graph.recipe.codeHashes[2],
                _graph.binding.sourceFactoryDependenciesHash,
                msg.data
            )
        );
    }

    function completeViewPreservationBindingProfile() external pure override returns (bytes32) {
        return CompleteViewBinding.PROFILE;
    }

    function completeViewPreservationBindingTransition(
        ViewBindingTypes.Configuration calldata configuration,
        ViewDeclarationTypes.Binding calldata declaration,
        IStreamViewPreservationFinalitySourcesV1.Selection calldata selected
    ) external view override returns (ViewBindingTypes.Transition calldata) {
        _returnViewBinding(
            ViewBindingTransport.read(
                _viewBinding,
                _graph.original,
                _graph.recipe.targets[2],
                _graph.recipe.codeHashes[2],
                _graph.binding.sourceFactoryDependenciesHash,
                msg.data
            )
        );
    }

    function bindCompleteViewPreservation(
        ViewBindingTypes.Configuration calldata configuration,
        ViewDeclarationTypes.Binding calldata declaration,
        IStreamViewPreservationFinalitySourcesV1.Selection calldata selected
    ) external override returns (bytes32 completeRecordHash) {
        _returnViewBinding(
            ViewBindingTransport.write(
                _viewBinding,
                _graph.original,
                _graph.recipe.targets[2],
                _graph.recipe.codeHashes[2],
                _graph.binding.sourceFactoryDependenciesHash,
                msg.data
            )
        );
    }

    /// @notice Authenticated immutable producer selection; consumers still require current evidence.
    function viewFinalitySources()
        external
        view
        override
        returns (IStreamViewPreservationFinalitySourcesV1.Selection calldata)
    {
        _returnViewBinding(
            ViewBindingTransport.read(
                _viewBinding,
                _graph.original,
                _graph.recipe.targets[2],
                _graph.recipe.codeHashes[2],
                _graph.binding.sourceFactoryDependenciesHash,
                msg.data
            )
        );
    }

    /// @notice Historical full admission; unavailable for pending and basic-only bindings.
    function viewFinalitySourcesReceipt()
        external
        view
        override
        returns (IStreamViewPreservationFinalitySourcesV1.Receipt calldata)
    {
        _returnViewBinding(
            ViewBindingTransport.read(
                _viewBinding,
                _graph.original,
                _graph.recipe.targets[2],
                _graph.recipe.codeHashes[2],
                _graph.binding.sourceFactoryDependenciesHash,
                msg.data
            )
        );
    }

    /// @notice Bootstrap scalar only; the route consumer pins this provider and checks profile,
    /// limits and equality to the original declaration tuple before any evidence interpretation.
    function viewRouteReadBudget()
        external
        view
        override
        returns (bytes32 profile, uint32 readGas)
    {
        if (_viewBinding.receipt.recordHash == 0) {
            revert ViewBindingTypes.ViewPreservationPending();
        }
        return (
            keccak256("6529STREAM_GOVERNED_VIEW_ROUTE_READ_BUDGET_V1"),
            _viewBinding.receipt.declaration.readGas
        );
    }

    function viewPolicySourceFactoryV2() external view override returns (address) {
        return _viewPolicyFactory();
    }

    function viewPolicySourceFactoryV2CodeHash() external view override returns (bytes32) {
        _viewPolicyFactory();
        return _graph.recipe.codeHashes[2];
    }

    // Cheap fixed runtime read: original policy consumers independently revalidate the exact
    // complete factory dependencies and current source set under their own configured cap.
    function _viewPolicyFactory() private view returns (address factory) {
        if (_viewBinding.receipt.recordHash == 0) {
            revert ViewBindingTypes.ViewPreservationPending();
        }
        if (deploymentChainId != block.chainid) {
            revert ViewBindingTypes.InvalidViewPreservationBinding();
        }
        factory = _graph.recipe.targets[2];
        if (factory.code.length == 0 || factory.codehash != _graph.recipe.codeHashes[2]) {
            revert ViewBindingTypes.ViewPreservationBindingDependency(factory);
        }
    }

    function viewSourceBinding()
        external
        view
        override
        returns (ViewDeclarationTypes.Binding calldata)
    {
        _returnViewBinding(
            ViewBindingTransport.read(
                _viewBinding,
                _graph.original,
                _graph.recipe.targets[2],
                _graph.recipe.codeHashes[2],
                _graph.binding.sourceFactoryDependenciesHash,
                msg.data
            )
        );
    }

    /// @notice Authenticated bound capability, not a complete snapshot currentness verdict.
    /// The fixed consumer still validates current routes, eligibility and source reciprocities.
    function viewPreservationSnapshotHost() external view override returns (address) {
        _returnViewBinding(
            ViewBindingTransport.read(
                _viewBinding,
                _graph.original,
                _graph.recipe.targets[2],
                _graph.recipe.codeHashes[2],
                _graph.binding.sourceFactoryDependenciesHash,
                msg.data
            )
        );
    }

    function viewPreservationSnapshotCodeHash() external view override returns (bytes32) {
        _returnViewBinding(
            ViewBindingTransport.read(
                _viewBinding,
                _graph.original,
                _graph.recipe.targets[2],
                _graph.recipe.codeHashes[2],
                _graph.binding.sourceFactoryDependenciesHash,
                msg.data
            )
        );
    }

    function viewPreservationSnapshotValidationGas() external view override returns (uint256) {
        _returnViewBinding(
            ViewBindingTransport.read(
                _viewBinding,
                _graph.original,
                _graph.recipe.targets[2],
                _graph.recipe.codeHashes[2],
                _graph.binding.sourceFactoryDependenciesHash,
                msg.data
            )
        );
    }

    function preservationFactorySourceProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_CURRENT_AUTHORITY_PRESERVATION_FACTORY_PROFILE_SOURCES_V1");
    }

    function finalitySourceProfile(uint8 index)
        external
        view
        override
        returns (Profiles.Profile calldata)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        revert();
    }

    function finalitySourceConfigurationHash() external view override returns (bytes32) {
        return _sourceConfigurationHash;
    }

    function finalitySourcesForScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (Profiles.Sources calldata)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        revert();
    }

    function collectionPreservationPolicyPublicationBinding()
        external
        view
        override
        returns (CollectionBinding.CollectionFactoryBinding calldata)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        revert();
    }

    function latestCollectionSnapshotHash(uint256 cid) public view override returns (bytes32) {
        (bool handled, bytes32 result) = GraphDispatch.latestSnapshot(_graph, _collectionGraph, cid);
        if (!handled) return super.latestCollectionSnapshotHash(cid);
        return result;
    }

    function finalityComponentFacts(bytes32 family, StreamFinalityScope calldata scope)
        public
        view
        override
        returns (StreamFinalityHostComponentFacts memory f)
    {
        (bool handled, bool frozen, bytes32 dataHash, bool metadata) =
            GraphDispatch.componentFacts(_graph, _collectionGraph, family, scope);
        if (!handled) return super.finalityComponentFacts(family, scope);
        f.frozen = frozen;
        f.dataHash = dataHash;
        if (metadata) {
            f.moduleVersion = metadataModuleVersion;
            f.manifestHash = metadataModuleManifestHash;
        } else {
            f.moduleVersion = routerModuleVersion;
            f.manifestHash = routerModuleManifestHash;
        }
    }

    function inputManifestBytes(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes memory)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        return super.inputManifestBytes(scope);
    }

    function requireFinalityScopeInputs(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        override
        returns (StreamFinalityScopeInputs memory, bytes32, bytes32)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        return super.requireFinalityScopeInputs(scope, manifestHash);
    }

    function requireSanctionReviewFacts(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        override
        returns (IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        return super.requireSanctionReviewFacts(scope, manifestHash);
    }

    function requirePreparedFinalityScopeInputs(
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    ) public view override returns (StreamFinalityScopeInputs memory, bytes32, bytes32) {
        _originalRegistry();
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        return super.requirePreparedFinalityScopeInputs(scope, manifestHash, components);
    }

    function requirePreparedFinalityScopeInputsAndReview(
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    )
        public
        view
        override
        returns (
            StreamFinalityScopeInputs memory,
            bytes32,
            bytes32,
            IStreamFinalitySanctionReview.ReviewFacts memory
        )
    {
        _originalRegistry();
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        return super.requirePreparedFinalityScopeInputsAndReview(scope, manifestHash, components);
    }

    function scopedPreservationPolicyPublicationBinding()
        external
        view
        override
        returns (GraphBinding.FactoryBinding calldata)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        revert();
    }

    function scopedPreservationPolicySnapshotProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2");
    }

    function scopedPreservationPolicySnapshotHost(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (address)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        revert();
    }

    function scopedPreservationPolicySnapshotCodeHash(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        revert();
    }

    function scopedPreservationPolicySnapshotValidationGas(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        revert();
    }

    function scopedContentRoot(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes32, uint64, bytes32)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        return super.scopedContentRoot(scope);
    }

    function scopedSnapshotHash(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes32)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        return super.scopedSnapshotHash(scope);
    }

    function scopedManifest(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bool, bytes32)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnViewBinding(encoded);
        return super.scopedManifest(scope);
    }

    function _originalRegistry() private view {
        if (
            msg.sender != _collectionGraph.original.targets[12] || msg.sender.code.length == 0
                || msg.sender.codehash != _collectionGraph.original.codeHashes[12]
        ) {
            revert NativeProviderOriginalRegistryOnly();
        }
    }

    function _profile(StreamFinalityNativeProviderReads.Config memory c, uint8 index, bytes32 hash)
        private
        pure
        returns (Profiles.Profile memory)
    {
        return Profiles.Profile(
            ProfileSelection.profileHash(index),
            c.targets[9],
            c.codeHashes[9],
            c.targets[8],
            c.codeHashes[8],
            c.targets[10],
            c.codeHashes[10],
            hash
        );
    }

    function _returnViewBinding(bytes memory result) private pure {
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}
