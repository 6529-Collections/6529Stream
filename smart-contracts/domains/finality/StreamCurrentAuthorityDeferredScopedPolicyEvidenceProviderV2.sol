// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as DeferredTypes
} from "../../interfaces/stream/finality/StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";
import {
    IStreamCurrentAuthorityDeferredPolicyBindingV2 as DeferredBinding
} from "../../interfaces/stream/finality/IStreamCurrentAuthorityDeferredPolicyBindingV2.sol";
import {
    StreamCurrentAuthorityDeferredPolicyGovernanceV2 as DeferredGovernance
} from "./StreamCurrentAuthorityDeferredPolicyGovernanceV2.sol";
import {
    StreamCurrentAuthorityDeferredPolicyValidationV2 as DeferredValidation
} from "./StreamCurrentAuthorityDeferredPolicyValidationV2.sol";
import "./StreamCurrentAuthorityDeferredScopedPolicyBaseEvidenceProviderV2.sol";
import {
    StreamFinalityPolicyProviderComponentsV2 as PolicyComponents
} from "./StreamFinalityPolicyProviderComponentsV2.sol";
import {
    StreamPolicySnapshotTypesV2
} from "../../interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    IStreamPolicySnapshotPublicationV2 as PolicySnapshotHost
} from "../../interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import {
    StreamFinalityDeferredProfileSourceReadsV2 as Selection
} from "./StreamFinalityDeferredProfileSourceReadsV2.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamCurrentAuthorityPolicyProviderOperationsV2 as PolicyOperations
} from "./StreamCurrentAuthorityPolicyProviderOperationsV2.sol";
import {
    StreamFinalityPolicyMetadataFactsV2 as PolicyMetadata
} from "./StreamFinalityPolicyMetadataFactsV2.sol";
import {
    StreamFinalityPolicyStaticComponentsV2 as PolicyStatic
} from "./StreamFinalityPolicyStaticComponentsV2.sol";
import {
    StreamFinalityPolicySnapshotReadsV2 as PolicySnapshots
} from "./StreamFinalityPolicySnapshotReadsV2.sol";
import {
    StreamFinalityPolicyStaticSourceV2 as PolicySource
} from "./StreamFinalityPolicyStaticSourceV2.sol";
import {
    IStreamPolicyOutputEvidenceBindingV2
} from "../../interfaces/stream/finality/IStreamPolicyOutputEvidenceBindingV2.sol";
import {
    IStreamPolicyPublicationEvidenceBindingV2
} from "../../interfaces/stream/finality/IStreamPolicyPublicationEvidenceBindingV2.sol";
import {
    IStreamScopedPolicyContentRootEvidenceBindingV2
} from "../../interfaces/stream/finality/IStreamScopedPolicyContentRootEvidenceBindingV2.sol";
import {
    IStreamScopedPolicyPublicationEvidenceBindingV2 as GraphBinding
} from "../../interfaces/stream/finality/IStreamScopedPolicyPublicationEvidenceBindingV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyGraphSelectionV2 as GraphSelection
} from "./StreamCurrentAuthorityScopedPolicyGraphSelectionV2.sol";
import {
    StreamFinalityScopedPolicyProviderReadsV2 as ScopedPolicyReads
} from "./StreamFinalityScopedPolicyProviderReadsV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyProviderOperationsV2 as ScopedPolicyOperations
} from "./StreamCurrentAuthorityScopedPolicyProviderOperationsV2.sol";
import {
    StreamFinalityScopedPolicyProviderMetadataV2 as ScopedPolicyMetadata
} from "./StreamFinalityScopedPolicyProviderMetadataV2.sol";
import {
    StreamFinalityScopedPolicyMetadataFactsV2 as ScopedPolicyFacts
} from "./StreamFinalityScopedPolicyMetadataFactsV2.sol";
import {
    StreamFinalityScopedPolicyStaticComponentsV2 as ScopedPolicyStatic
} from "./StreamFinalityScopedPolicyStaticComponentsV2.sol";
import {
    StreamFinalityScopedPolicySnapshotReadsV2 as ScopedPolicySnapshots
} from "./StreamFinalityScopedPolicySnapshotReadsV2.sol";

import {
    StreamCurrentAuthorityDeferredScopedPolicyBindingWorkerV2 as BindingWorker
} from "./StreamCurrentAuthorityDeferredScopedPolicyBindingWorkerV2.sol";
import {
    StreamCurrentAuthorityDeferredScopedPolicyGraphWorkerV2 as GraphWorker
} from "./StreamCurrentAuthorityDeferredScopedPolicyGraphWorkerV2.sol";

/// @notice Original source profiles with one governed collection-policy binding after deployment.
/// @dev Native, scoped and per-scope full-policy graphs retain their fixed original anchors.
/// Only this distinct capability may add collection-policy sources, once, after full validation.
contract StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2 is
    StreamCurrentAuthorityDeferredScopedPolicyBaseEvidenceProviderV2,
    Profiles,
    IStreamPolicyOutputEvidenceBindingV2,
    IStreamPolicyPublicationEvidenceBindingV2,
    IStreamScopedPolicyContentRootEvidenceBindingV2,
    GraphBinding,
    DeferredBinding
{
    // Preserve the original compiler-propagated error in the host ABI after worker dispatch.
    error NativeProviderSource();

    StreamFinalityNativeProviderReads.Config private _policy;
    Selection.Context private _sourceSelection;
    GraphSelection.Context private _graph;
    DeferredTypes.Capability private _policyCapability;
    DeferredTypes.Receipt private _policyReceipt;
    bytes32 private _sourceConfigurationHash;
    bool private _bindingInProgress;

    constructor(
        StreamFinalityNativeProviderReads.Config memory original,
        StreamFinalityScopedProviderReads.Config memory scoped,
        GraphBinding.FactoryBinding memory publicationFactory
    ) StreamCurrentAuthorityDeferredScopedPolicyBaseEvidenceProviderV2(original, scoped) {
        _sourceConfigurationHash = BindingWorker.initialize(
            _sourceSelection, _graph, _policyCapability, original, scoped, publicationFactory
        );
    }

    function supportsInterface(bytes4 id)
        public
        pure
        virtual
        override(StreamCurrentAuthorityDeferredScopedPolicyBaseEvidenceProviderV2, IERC165)
        returns (bool)
    {
        return super.supportsInterface(id) || id == type(Profiles).interfaceId
            || id == type(IStreamPolicyOutputEvidenceBindingV2).interfaceId
            || id == type(IStreamPolicyPublicationEvidenceBindingV2).interfaceId
            || id == type(IStreamScopedPolicyContentRootEvidenceBindingV2).interfaceId
            || id == type(GraphBinding).interfaceId || id == type(DeferredBinding).interfaceId;
    }

    function deferredPolicyBindingProfile() external pure override returns (bytes32) {
        return DeferredTypes.PROFILE;
    }

    function policyBindingCapability()
        external
        view
        override
        returns (DeferredTypes.Capability memory)
    {
        return _policyCapability;
    }

    function policyBindingHash() external view override returns (bytes32) {
        return _policyReceipt.bindingHash;
    }

    function requirePolicyBinding() external view override returns (DeferredTypes.Receipt memory) {
        _requirePolicy();
        return _policyReceipt;
    }

    function bindingTransition(
        StreamFinalityNativeProviderReads.Config calldata policy,
        address output,
        bytes32 outputHash
    ) external view override returns (DeferredTypes.Transition memory) {
        _requireUnbound();
        return BindingWorker.transition(_graph, _policyCapability, policy, output, outputHash);
    }

    function bindCollectionPolicy(
        StreamFinalityNativeProviderReads.Config calldata policy,
        address output,
        bytes32 outputHash
    ) external override {
        _requireUnbound();
        _bindingInProgress = true;
        (bytes32 capabilityHash, bytes32 bindingHash, bytes32 actionId, bytes32 proposalHash) = BindingWorker.bind(
            _policy,
            _sourceSelection,
            _graph,
            _policyCapability,
            _policyReceipt,
            policy,
            output,
            outputHash
        );
        _bindingInProgress = false;
        emit CollectionPolicyBound(capabilityHash, bindingHash, actionId, proposalHash);
    }

    function _requireUnbound() private view {
        if (_policyReceipt.bindingHash != 0 || _sourceSelection.policyBound || _bindingInProgress) {
            revert DeferredTypes.CollectionPolicyAlreadyBound();
        }
    }

    function _requirePolicy() private view {
        if (_policyReceipt.bindingHash == 0 || !_sourceSelection.policyBound) {
            revert DeferredTypes.CollectionPolicyPending();
        }
    }

    function policyConfiguration()
        external
        view
        returns (StreamFinalityNativeProviderReads.Config memory)
    {
        _requirePolicy();
        return _policy;
    }

    function finalitySourceProfile(uint8 index)
        external
        view
        override
        returns (Profiles.Profile memory)
    {
        Selection.profileHash(index);
        if (index == 2) _requirePolicy();
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
        if (GraphWorker.isPolicy(_graph, scope)) {
            return GraphWorker.sources(_graph, scope);
        }
        return GraphWorker.selectedSources(_sourceSelection, scope);
    }

    function policyOutputManifestV2() external view override returns (address) {
        _requirePolicy();
        return _sourceSelection.policyOutput;
    }

    function policyOutputManifestV2CodeHash() external view override returns (bytes32) {
        _requirePolicy();
        return _sourceSelection.policyOutputCodeHash;
    }

    function policySnapshotPublicationV2() external view override returns (address) {
        _requirePolicy();
        return _policy.targets[8];
    }

    function policySnapshotPublicationV2CodeHash() external view override returns (bytes32) {
        _requirePolicy();
        return _policy.codeHashes[8];
    }

    function policyReferencePublicationV2() external view override returns (address) {
        _requirePolicy();
        return _policy.targets[9];
    }

    function policyReferencePublicationV2CodeHash() external view override returns (bytes32) {
        _requirePolicy();
        return _policy.codeHashes[9];
    }

    function latestCollectionSnapshotHash(uint256 cid) public view override returns (bytes32) {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0);
        if (!_policyScope(scope)) return super.latestCollectionSnapshotHash(cid);
        _pins();
        return GraphWorker.policySnapshot(_policy, cid);
    }

    function finalityComponentFacts(bytes32 family, StreamFinalityScope calldata scope)
        public
        view
        override
        returns (StreamFinalityHostComponentFacts memory f)
    {
        if (GraphWorker.isPolicy(_graph, scope)) {
            return GraphWorker.componentFacts(
                _graph,
                GraphWorker.ModuleIdentity(
                    metadataModuleVersion,
                    metadataModuleManifestHash,
                    routerModuleVersion,
                    routerModuleManifestHash
                ),
                family,
                scope
            );
        }
        if (!_policyScope(scope)) return super.finalityComponentFacts(family, scope);
        return GraphWorker.collectionComponentFacts(
            _graph.original,
            _policy,
            GraphWorker.ModuleIdentity(
                metadataModuleVersion,
                metadataModuleManifestHash,
                routerModuleVersion,
                routerModuleManifestHash
            ),
            family,
            scope
        );
    }

    function inputManifestBytes(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes memory)
    {
        if (GraphWorker.isPolicy(_graph, scope)) {
            return GraphWorker.manifest(_graph, scope);
        }
        if (!_policyScope(scope)) {
            return super.inputManifestBytes(scope);
        }
        return GraphWorker.policyManifest(_policy, scope);
    }

    function requireFinalityScopeInputs(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        override
        returns (StreamFinalityScopeInputs memory, bytes32, bytes32)
    {
        if (GraphWorker.isPolicy(_graph, scope)) {
            return GraphWorker.inputs(_graph, scope, manifestHash);
        }
        if (!_policyScope(scope)) {
            return super.requireFinalityScopeInputs(scope, manifestHash);
        }
        return GraphWorker.policyInputs(_policy, scope, manifestHash);
    }

    function requireSanctionReviewFacts(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        override
        returns (IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        if (GraphWorker.isPolicy(_graph, scope)) {
            return GraphWorker.review(_graph, scope, manifestHash);
        }
        if (!_policyScope(scope)) {
            return super.requireSanctionReviewFacts(scope, manifestHash);
        }
        return GraphWorker.policyReview(_policy, scope, manifestHash);
    }

    function requirePreparedFinalityScopeInputs(
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    ) public view override returns (StreamFinalityScopeInputs memory, bytes32, bytes32) {
        _originalRegistry();
        if (GraphWorker.isPolicy(_graph, scope)) {
            (StreamFinalityScopeInputs memory inputs_, bytes32 schema_, bytes32 canon_,) =
                GraphWorker.prepared(_graph, scope, manifestHash, components, false);
            return (inputs_, schema_, canon_);
        }
        if (!_policyScope(scope)) {
            return super.requirePreparedFinalityScopeInputs(scope, manifestHash, components);
        }
        (StreamFinalityScopeInputs memory v, bytes32 schema, bytes32 canon,) =
            GraphWorker.policyPrepared(_policy, scope, manifestHash, components, false);
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
        if (GraphWorker.isPolicy(_graph, scope)) {
            return GraphWorker.prepared(_graph, scope, manifestHash, components, true);
        }
        if (!_policyScope(scope)) {
            return
                super.requirePreparedFinalityScopeInputsAndReview(scope, manifestHash, components);
        }
        return GraphWorker.policyPrepared(_policy, scope, manifestHash, components, true);
    }

    function scopedPolicyPublicationBinding()
        external
        view
        override
        returns (GraphBinding.FactoryBinding memory)
    {
        return _graph.binding;
    }

    function scopedPolicySnapshotProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2");
    }

    function scopedPolicySnapshotHost(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (address)
    {
        return GraphWorker.snapshotHost(_graph, scope);
    }

    function scopedPolicySnapshotCodeHash(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        return GraphWorker.snapshotCodeHash(_graph, scope);
    }

    function scopedPolicySnapshotValidationGas(StreamFinalityScope calldata scope)
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
        if (!GraphWorker.isPolicy(_graph, scope)) return super.scopedContentRoot(scope);
        return GraphWorker.root(_graph, scope);
    }

    function scopedSnapshotHash(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes32)
    {
        if (!GraphWorker.isPolicy(_graph, scope)) {
            return super.scopedSnapshotHash(scope);
        }
        return GraphWorker.snapshot(_graph, scope);
    }

    function scopedManifest(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bool, bytes32)
    {
        if (!GraphWorker.isPolicy(_graph, scope)) return super.scopedManifest(scope);
        return GraphWorker.scopeManifest(_graph, scope);
    }

    function _originalRegistry() private view {
        if (
            msg.sender != _graph.original.targets[12] || msg.sender.code.length == 0
                || msg.sender.codehash != _graph.original.codeHashes[12]
        ) {
            revert NativeProviderOriginalRegistryOnly();
        }
    }

    function _policyScope(StreamFinalityScope memory scope) private view returns (bool) {
        return GraphWorker.isCollectionPolicy(_sourceSelection, scope);
    }

    function _deferredOriginal()
        internal
        view
        override
        returns (StreamFinalityNativeProviderReads.Config storage)
    {
        return _graph.original;
    }
}
