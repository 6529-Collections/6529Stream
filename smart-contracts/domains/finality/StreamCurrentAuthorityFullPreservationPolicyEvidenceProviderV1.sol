// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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

/// @notice Current-authority provider for original static and genuine preservation graphs.
/// @dev COLLECTION/scoped catalogues are constructor-only; VIEW is one-time class2 bound. Current canonical Router profile
/// chooses the collection branch; no source receipt is cast across profiles. Prior deployment
/// identities and records are not inherited. VIEW retains its separately implemented route.
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
        returns (ViewBindingTypes.Capability memory)
    {
        return _viewBinding.capability;
    }

    /// @notice Historical admission facts remain readable if a bound runtime later drifts.
    function viewPreservationBindingReceipt()
        external
        view
        override
        returns (ViewBindingTypes.Receipt memory)
    {
        return _viewBinding.receipt;
    }

    function viewPreservationBindingTransition(
        ViewBindingTypes.Configuration calldata configuration,
        ViewDeclarationTypes.Binding calldata declaration
    ) external view override returns (ViewBindingTypes.Transition memory) {
        _validateViewPolicyFactory();
        return ViewBinding.transition(_viewBinding, _graph.original, configuration, declaration);
    }

    function bindViewPreservation(
        ViewBindingTypes.Configuration calldata configuration,
        ViewDeclarationTypes.Binding calldata declaration
    ) external override returns (bytes32 recordHash) {
        _validateViewPolicyFactory();
        ViewBindingTypes.Receipt memory r =
            ViewBinding.bind(_viewBinding, _graph.original, configuration, declaration);
        emit ViewPreservationBound(
            r.recordHash,
            r.actionId,
            r.configuration.snapshotHost,
            ViewBindingTypes.proposalHash(r),
            r.dependenciesHash
        );
        return r.recordHash;
    }

    function completeViewPreservationBindingProfile() external pure override returns (bytes32) {
        return CompleteViewBinding.PROFILE;
    }

    function completeViewPreservationBindingTransition(
        ViewBindingTypes.Configuration calldata configuration,
        ViewDeclarationTypes.Binding calldata declaration,
        IStreamViewPreservationFinalitySourcesV1.Selection calldata selected
    ) external view override returns (ViewBindingTypes.Transition memory) {
        _validateViewPolicyFactory();
        return ViewBinding.completeTransition(
            _viewBinding, _graph.original, configuration, declaration, selected
        );
    }

    function bindCompleteViewPreservation(
        ViewBindingTypes.Configuration calldata configuration,
        ViewDeclarationTypes.Binding calldata declaration,
        IStreamViewPreservationFinalitySourcesV1.Selection calldata selected
    ) external override returns (bytes32 completeRecordHash) {
        _validateViewPolicyFactory();
        (
            ViewBindingTypes.Receipt memory basic,
            IStreamViewPreservationFinalitySourcesV1.Receipt memory complete
        ) = ViewBinding.bindComplete(
            _viewBinding, _graph.original, configuration, declaration, selected
        );
        emit ViewPreservationCompleteBound(
            complete.recordHash,
            basic.recordHash,
            complete.actionId,
            CompleteViewBinding.proposalHash(basic, complete)
        );
        return complete.recordHash;
    }

    /// @notice Authenticated immutable producer selection; consumers still require current evidence.
    function viewFinalitySources()
        external
        view
        override
        returns (IStreamViewPreservationFinalitySourcesV1.Selection memory)
    {
        return ViewBinding.completeSelection(_viewBinding, _graph.original);
    }

    /// @notice Historical full admission; unavailable for pending and basic-only bindings.
    function viewFinalitySourcesReceipt()
        external
        view
        override
        returns (IStreamViewPreservationFinalitySourcesV1.Receipt memory)
    {
        return ViewBinding.completeHistory(_viewBinding, _graph.original);
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

    function _validateViewPolicyFactory() private view {
        if (_viewBinding.receipt.recordHash != 0) {
            revert ViewBindingTypes.ViewPreservationAlreadyBound();
        }
        ViewPolicyFactory.validate(
            _graph.original,
            _graph.recipe.targets[2],
            _graph.recipe.codeHashes[2],
            _graph.binding.sourceFactoryDependenciesHash
        );
    }

    function viewSourceBinding()
        external
        view
        override
        returns (ViewDeclarationTypes.Binding memory)
    {
        return ViewBinding.declaration(_viewBinding, _graph.original);
    }

    /// @notice Authenticated bound capability, not a complete snapshot currentness verdict.
    /// The fixed consumer still validates current routes, eligibility and source reciprocities.
    function viewPreservationSnapshotHost() external view override returns (address) {
        return ViewBinding.current(_viewBinding, _graph.original).snapshotHost;
    }

    function viewPreservationSnapshotCodeHash() external view override returns (bytes32) {
        return ViewBinding.current(_viewBinding, _graph.original).snapshotCodeHash;
    }

    function viewPreservationSnapshotValidationGas() external view override returns (uint256) {
        return ViewBinding.current(_viewBinding, _graph.original).validationGas;
    }

    function preservationFactorySourceProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_CURRENT_AUTHORITY_PRESERVATION_FACTORY_PROFILE_SOURCES_V1");
    }

    function finalitySourceProfile(uint8 index)
        external
        view
        override
        returns (Profiles.Profile memory)
    {
        ProfileSelection.profileHash(index);
        return _sourceSelection.profiles[index];
    }

    function finalitySourceConfigurationHash() external view override returns (bytes32) {
        return _sourceConfigurationHash;
    }

    function finalitySourcesForScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (Profiles.Sources memory)
    {
        if (GraphSelection.isPolicy(_graph, scope)) {
            return GraphSelection.sources(_graph, scope);
        }
        if (CollectionSelection.isPolicy(_collectionGraph, scope)) {
            return CollectionSelection.sources(_collectionGraph, scope);
        }
        return ProfileSelection.current(_sourceSelection, scope);
    }

    function collectionPreservationPolicyPublicationBinding()
        external
        view
        override
        returns (CollectionBinding.CollectionFactoryBinding memory)
    {
        return _collectionGraph.binding;
    }

    function latestCollectionSnapshotHash(uint256 cid) public view override returns (bytes32) {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0);
        if (!_policyScope(scope)) return super.latestCollectionSnapshotHash(cid);
        _pins();
        return PolicyComponents.snapshotHash(
            _collectionConfig(scope).source,
            cid,
            keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
        );
    }

    function finalityComponentFacts(bytes32 family, StreamFinalityScope calldata scope)
        public
        view
        override
        returns (StreamFinalityHostComponentFacts memory f)
    {
        if (GraphSelection.isPolicy(_graph, scope)) {
            ScopedPolicyReads.Config memory configured = _scopedPolicyConfig(scope);
            _pins();
            _scope(scope);
            if (family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) {
                (f.frozen, f.dataHash) = ScopedPolicyFacts.facts(
                    configured, scope, keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
                );
                f.moduleVersion = metadataModuleVersion;
                f.manifestHash = metadataModuleManifestHash;
            } else {
                componentHost(family);
                (f.frozen, f.dataHash) = ScopedPolicyStatic.facts(
                    configured, scope, family, keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
                );
                f.moduleVersion = routerModuleVersion;
                f.manifestHash = routerModuleManifestHash;
            }
            return f;
        }
        if (!_policyScope(scope)) return super.finalityComponentFacts(family, scope);
        _pins();
        _scope(scope);
        if (family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) {
            (f.frozen, f.dataHash) = PolicyComponents.facts(
                _collectionConfig(scope).source,
                scope,
                family,
                keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
            );
            f.moduleVersion = metadataModuleVersion;
            f.manifestHash = metadataModuleManifestHash;
        } else {
            componentHost(family);
            (f.frozen, f.dataHash) = PolicyComponents.facts(
                _collectionConfig(scope).source,
                scope,
                family,
                keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
            );
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
        if (GraphSelection.isPolicy(_graph, scope)) {
            return ScopedPolicyOperations.manifest(_scopedPolicyConfig(scope), scope);
        }
        if (!_policyScope(scope)) return super.inputManifestBytes(scope);
        return PolicyOperations.manifest(_collectionConfig(scope), scope);
    }

    function requireFinalityScopeInputs(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        override
        returns (StreamFinalityScopeInputs memory, bytes32, bytes32)
    {
        if (GraphSelection.isPolicy(_graph, scope)) {
            return ScopedPolicyOperations.inputs(_scopedPolicyConfig(scope), scope, manifestHash);
        }
        if (!_policyScope(scope)) return super.requireFinalityScopeInputs(scope, manifestHash);
        return PolicyOperations.inputs(_collectionConfig(scope), scope, manifestHash);
    }

    function requireSanctionReviewFacts(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        override
        returns (IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        if (GraphSelection.isPolicy(_graph, scope)) {
            return ScopedPolicyOperations.review(_scopedPolicyConfig(scope), scope, manifestHash);
        }
        if (!_policyScope(scope)) return super.requireSanctionReviewFacts(scope, manifestHash);
        return PolicyOperations.review(_collectionConfig(scope), scope, manifestHash);
    }

    function requirePreparedFinalityScopeInputs(
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    ) public view override returns (StreamFinalityScopeInputs memory, bytes32, bytes32) {
        _originalRegistry();
        if (GraphSelection.isPolicy(_graph, scope)) {
            (StreamFinalityScopeInputs memory inputs_, bytes32 schema_, bytes32 canon_,) = ScopedPolicyOperations.prepared(
                _scopedPolicyConfig(scope), scope, manifestHash, components, false
            );
            return (inputs_, schema_, canon_);
        }
        if (!_policyScope(scope)) {
            return super.requirePreparedFinalityScopeInputs(scope, manifestHash, components);
        }
        (StreamFinalityScopeInputs memory v, bytes32 schema, bytes32 canon,) = PolicyOperations.prepared(
            _collectionConfig(scope), scope, manifestHash, components, false
        );
        return (v, schema, canon);
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
        if (GraphSelection.isPolicy(_graph, scope)) {
            return ScopedPolicyOperations.prepared(
                _scopedPolicyConfig(scope), scope, manifestHash, components, true
            );
        }
        if (!_policyScope(scope)) {
            return
                super.requirePreparedFinalityScopeInputsAndReview(scope, manifestHash, components);
        }
        return PolicyOperations.prepared(
            _collectionConfig(scope), scope, manifestHash, components, true
        );
    }

    function scopedPreservationPolicyPublicationBinding()
        external
        view
        override
        returns (GraphBinding.FactoryBinding memory)
    {
        return _graph.binding;
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
        return _scopedPolicyConfig(scope).targets[8];
    }

    function scopedPreservationPolicySnapshotCodeHash(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        return _scopedPolicyConfig(scope).codeHashes[8];
    }

    function scopedPreservationPolicySnapshotValidationGas(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.TOKEN
                && scope.scopeType != StreamFinalityScopeType.RELEASE
                && scope.scopeType != StreamFinalityScopeType.SEASON
        ) revert GraphSelection.ScopedPolicyGraphConfiguration();
        StreamMetadataSubjects.scopeSubject(deploymentChainId, core, scope);
        return _graph.original.componentSourceGas;
    }

    function scopedContentRoot(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes32, uint64, bytes32)
    {
        if (!GraphSelection.isPolicy(_graph, scope)) return super.scopedContentRoot(scope);
        return ScopedPolicyMetadata.root(
            _metadataConfigV2(scope), scope, keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
        );
    }

    function scopedSnapshotHash(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes32)
    {
        if (!GraphSelection.isPolicy(_graph, scope)) {
            return super.scopedSnapshotHash(scope);
        }
        return ScopedPolicyMetadata.snapshot(
            _metadataConfigV2(scope), scope, keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
        );
    }

    function scopedManifest(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bool, bytes32)
    {
        if (!GraphSelection.isPolicy(_graph, scope)) return super.scopedManifest(scope);
        return ScopedPolicyMetadata.manifest(
            _metadataConfigV2(scope), scope, keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
        );
    }

    function _scopedPolicyConfig(StreamFinalityScope memory scope)
        private
        view
        returns (ScopedPolicyReads.Config memory c)
    {
        (c,) = GraphSelection.current(_graph, scope);
    }

    function _metadataConfigV2(StreamFinalityScope memory scope)
        private
        view
        returns (ScopedPolicyMetadata.Config memory c)
    {
        ScopedPolicyReads.Config memory s = _scopedPolicyConfig(scope);
        c.snapshots = ScopedPolicySnapshots.Dependencies(
            s.targets[0],
            s.targets[1],
            s.targets[2],
            s.targets[8],
            s.codeHashes[0],
            s.codeHashes[1],
            s.codeHashes[2],
            s.codeHashes[8],
            s.chainId,
            s.readGas,
            s.componentSourceGas
        );
        c.membership = s.targets[3];
        c.membershipCodeHash = s.codeHashes[3];
    }

    function _originalRegistry() private view {
        if (
            msg.sender != _collectionGraph.original.targets[12] || msg.sender.code.length == 0
                || msg.sender.codehash != _collectionGraph.original.codeHashes[12]
        ) {
            revert NativeProviderOriginalRegistryOnly();
        }
    }

    function _collectionConfig(StreamFinalityScope memory scope)
        private
        view
        returns (PolicyOperations.Config memory c)
    {
        CollectionGraph.Graph memory g;
        (c.source, g) = CollectionSelection.current(_collectionGraph, scope);
        c.outputManifest = g.children[2];
        c.outputManifestCodeHash = g.codeHashes[2];
    }

    function _policyScope(StreamFinalityScope memory scope) private view returns (bool) {
        return CollectionSelection.isPolicy(_collectionGraph, scope);
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
}
