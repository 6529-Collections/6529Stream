// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityFullPolicyBaseEvidenceProviderV2.sol";
import {
    StreamFinalityPreservationPolicyProviderComponentsV1 as PolicyComponents
} from "./StreamFinalityPreservationPolicyProviderComponentsV1.sol";
import {
    StreamFinalityFactoryProfileSourceReadsV2 as Selection
} from "./StreamFinalityFactoryProfileSourceReadsV2.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamFinalityFactoryPreservationPolicyProviderOperationsV1 as PolicyOperations
} from "./StreamFinalityFactoryPreservationPolicyProviderOperationsV1.sol";
import {
    IStreamScopedPreservationPolicyContentRootEvidenceBindingV1
} from "../../interfaces/stream/finality/IStreamScopedPreservationPolicyContentRootEvidenceBindingV1.sol";
import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as GraphBinding
} from "../../interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    StreamFinalityScopedPreservationPolicyGraphSelectionV1 as GraphSelection
} from "./StreamFinalityScopedPreservationPolicyGraphSelectionV1.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderReadsV1 as ScopedPolicyReads
} from "./StreamFinalityScopedPreservationPolicyProviderReadsV1.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderOperationsV1 as ScopedPolicyOperations
} from "./StreamFinalityScopedPreservationPolicyProviderOperationsV1.sol";
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
    StreamFinalityPreservationPolicyGraphSelectionV1 as CollectionSelection
} from "./StreamFinalityPreservationPolicyGraphSelectionV1.sol";
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as CollectionGraph
} from "../../interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";

/// @notice Fixed provider for original two static profiles and genuine per-scope preservation graphs.
/// @dev Every source catalogue/configuration is constructor-only. Current canonical Router profile
/// chooses the collection branch; no source receipt is cast across profiles. Prior deployment
/// identities and records are not inherited. VIEW retains its separately implemented route.
contract StreamFinalityFullPreservationPolicyEvidenceProviderV1 is
    StreamFinalityFullPolicyBaseEvidenceProviderV2,
    Catalogue,
    CollectionBinding,
    IStreamScopedPreservationPolicyContentRootEvidenceBindingV1,
    GraphBinding
{
    Selection.Context private _sourceSelection;
    GraphSelection.Context private _graph;
    CollectionSelection.Context private _collectionGraph;
    // Constructor-only storage avoids reciprocal runtime hash cycles.
    bytes32 private _sourceConfigurationHash;

    constructor(
        StreamFinalityNativeProviderReads.Config memory original,
        StreamFinalityScopedProviderReads.Config memory scoped,
        CollectionBinding.CollectionFactoryBinding memory collectionFactory,
        GraphBinding.FactoryBinding memory publicationFactory
    ) StreamFinalityFullPolicyBaseEvidenceProviderV2(original, scoped) {
        Selection.Context memory c;
        c.core = original.targets[0];
        c.router = original.targets[2];
        c.routerCodeHash = original.codeHashes[2];
        c.chainId = original.chainId;
        c.readGas = original.readGas;
        c.profiles[0] = _profile(original, 0, keccak256(abi.encode(original)));
        c.profiles[1] = Profiles.Profile(
            Selection.profileHash(1),
            scoped.targets[9],
            scoped.codeHashes[9],
            scoped.targets[8],
            scoped.codeHashes[8],
            scoped.targets[10],
            scoped.codeHashes[10],
            keccak256(abi.encode(scoped))
        );
        Selection.validate(c);
        _sourceSelection = c;
        _graph = GraphSelection.initialize(original, publicationFactory);
        _collectionGraph = CollectionSelection.initialize(original, collectionFactory);
        _sourceConfigurationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_PRESERVATION_FACTORY_SOURCE_CONFIGURATION_V1"),
                block.chainid,
                address(this),
                original,
                scoped,
                _collectionGraph.binding,
                _graph.binding
            )
        );
    }

    function supportsInterface(bytes4 id) public pure virtual override returns (bool) {
        return super.supportsInterface(id) || id == type(Catalogue).interfaceId
            || id == type(CollectionBinding).interfaceId
            || id == type(IStreamScopedPreservationPolicyContentRootEvidenceBindingV1).interfaceId
            || id == type(GraphBinding).interfaceId;
    }

    function preservationFactorySourceProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_FINALITY_PRESERVATION_FACTORY_PROFILE_SOURCES_V1");
    }

    function finalitySourceProfile(uint8 index)
        external
        view
        override
        returns (Profiles.Profile memory)
    {
        Selection.profileHash(index);
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
        return Selection.current(_sourceSelection, scope);
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
        return PolicyComponents.snapshotHash(_collectionConfig(scope).source, cid);
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
                (f.frozen, f.dataHash) = ScopedPolicyFacts.facts(configured, scope);
                f.moduleVersion = metadataModuleVersion;
                f.manifestHash = metadataModuleManifestHash;
            } else {
                componentHost(family);
                (f.frozen, f.dataHash) = ScopedPolicyStatic.facts(configured, scope, family);
                f.moduleVersion = routerModuleVersion;
                f.manifestHash = routerModuleManifestHash;
            }
            return f;
        }
        if (!_policyScope(scope)) return super.finalityComponentFacts(family, scope);
        _pins();
        _scope(scope);
        if (family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) {
            (f.frozen, f.dataHash) =
                PolicyComponents.facts(_collectionConfig(scope).source, scope, family);
            f.moduleVersion = metadataModuleVersion;
            f.manifestHash = metadataModuleManifestHash;
        } else {
            componentHost(family);
            (f.frozen, f.dataHash) =
                PolicyComponents.facts(_collectionConfig(scope).source, scope, family);
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
        return keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1");
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
        return ScopedPolicyMetadata.root(_metadataConfigV2(scope), scope);
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
        return ScopedPolicyMetadata.snapshot(_metadataConfigV2(scope), scope);
    }

    function scopedManifest(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bool, bytes32)
    {
        if (!GraphSelection.isPolicy(_graph, scope)) return super.scopedManifest(scope);
        return ScopedPolicyMetadata.manifest(_metadataConfigV2(scope), scope);
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
            Selection.profileHash(index),
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
