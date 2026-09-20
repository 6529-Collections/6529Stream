// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityScopedPolicyPublicationTypesV2 as AuthorityGraphTypes
} from "../../interfaces/stream/finality/StreamCurrentAuthorityScopedPolicyPublicationTypesV2.sol";
import "./StreamCurrentAuthorityScopedPolicyBaseEvidenceProviderV2.sol";
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
    StreamFinalityProfileSourceReads as Selection
} from "./StreamFinalityProfileSourceReads.sol";
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

/// @notice Current-authority provider for original three source profiles and genuine per-scope full-policy V2 graphs.
/// @dev Every source catalogue/configuration is constructor-only. Current canonical Router profile
/// chooses the collection branch; no source receipt is cast across profiles. Prior deployment
/// identities and records are not inherited. VIEW retains its separately implemented route.
contract StreamCurrentAuthorityScopedPolicyEvidenceProviderV2 is
    StreamCurrentAuthorityScopedPolicyBaseEvidenceProviderV2,
    Profiles,
    IStreamPolicyOutputEvidenceBindingV2,
    IStreamPolicyPublicationEvidenceBindingV2,
    IStreamScopedPolicyContentRootEvidenceBindingV2,
    GraphBinding
{
    StreamFinalityNativeProviderReads.Config private _policy;
    Selection.Context private _sourceSelection;
    GraphSelection.Context private _graph;

    constructor(
        StreamFinalityNativeProviderReads.Config memory original,
        StreamFinalityScopedProviderReads.Config memory scoped,
        StreamFinalityNativeProviderReads.Config memory policy,
        address outputManifest,
        bytes32 outputManifestCodeHash,
        GraphBinding.FactoryBinding memory publicationFactory
    ) StreamCurrentAuthorityScopedPolicyBaseEvidenceProviderV2(original, scoped) {
        if (
            policy.chainId != original.chainId || policy.readGas != original.readGas
                || policy.sourceGas != original.sourceGas
                || policy.componentSourceGas != original.componentSourceGas
                || policy.inventoryDependencyHash == 0
        ) revert Selection.InvalidFinalitySourceProfile();
        for (uint256 i; i < 22; ++i) {
            if (policy.targets[i] == address(0) || policy.codeHashes[i] == 0) {
                revert Selection.InvalidFinalitySourceProfile();
            }
            // V2 has its own factory as well as snapshot/reference/inventory/bundle. The old
            // leaf/checkpoint roles6/7 remain original; V2 output comes from the separate pin.
            if (i != 8 && i != 9 && i != 10 && i != 18 && i != 19) {
                if (
                    policy.targets[i] != original.targets[i]
                        || policy.codeHashes[i] != original.codeHashes[i]
                ) {
                    revert Selection.InvalidFinalitySourceProfile();
                }
            }
        }
        _policy = policy;
        Selection.Context memory c;
        c.core = original.targets[0];
        c.router = original.targets[2];
        c.routerCodeHash = original.codeHashes[2];
        c.chainId = original.chainId;
        c.readGas = original.readGas;
        c.policyOutput = outputManifest;
        c.policyOutputCodeHash = outputManifestCodeHash;
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
        c.profiles[2] = _profile(policy, 2, keccak256(abi.encode(policy)));
        Selection.validate(c);
        _sourceSelection.core = c.core;
        _sourceSelection.router = c.router;
        _sourceSelection.routerCodeHash = c.routerCodeHash;
        _sourceSelection.chainId = c.chainId;
        _sourceSelection.readGas = c.readGas;
        _sourceSelection.policyOutput = c.policyOutput;
        _sourceSelection.policyOutputCodeHash = c.policyOutputCodeHash;
        for (uint256 i; i < 3; ++i) {
            _sourceSelection.profiles[i] = c.profiles[i];
        }
        _graph = GraphSelection.initialize(original, publicationFactory);
    }

    function supportsInterface(bytes4 id) public pure virtual override returns (bool) {
        return super.supportsInterface(id) || id == type(Profiles).interfaceId
            || id == type(IStreamPolicyOutputEvidenceBindingV2).interfaceId
            || id == type(IStreamPolicyPublicationEvidenceBindingV2).interfaceId
            || id == type(IStreamScopedPolicyContentRootEvidenceBindingV2).interfaceId
            || id == type(GraphBinding).interfaceId;
    }

    function policyConfiguration()
        external
        view
        returns (StreamFinalityNativeProviderReads.Config memory)
    {
        return _policy;
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
        return keccak256(
            abi.encode(
                AuthorityGraphTypes.SOURCE_CONFIGURATION_DOMAIN,
                Selection.configurationHash(_sourceSelection),
                _graph.binding
            )
        );
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
        return Selection.current(_sourceSelection, scope);
    }

    function policyOutputManifestV2() external view override returns (address) {
        return _sourceSelection.policyOutput;
    }

    function policyOutputManifestV2CodeHash() external view override returns (bytes32) {
        return _sourceSelection.policyOutputCodeHash;
    }

    function policySnapshotPublicationV2() external view override returns (address) {
        return _policy.targets[8];
    }

    function policySnapshotPublicationV2CodeHash() external view override returns (bytes32) {
        return _policy.codeHashes[8];
    }

    function policyReferencePublicationV2() external view override returns (address) {
        return _policy.targets[9];
    }

    function policyReferencePublicationV2CodeHash() external view override returns (bytes32) {
        return _policy.codeHashes[9];
    }

    function latestCollectionSnapshotHash(uint256 cid) public view override returns (bytes32) {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0);
        if (!_policyScope(scope)) return super.latestCollectionSnapshotHash(cid);
        _pins();
        return PolicyComponents.snapshotHash(_policy, cid);
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
            (f.frozen, f.dataHash) = PolicyComponents.facts(_policy, scope, family);
            f.moduleVersion = metadataModuleVersion;
            f.manifestHash = metadataModuleManifestHash;
        } else {
            componentHost(family);
            (f.frozen, f.dataHash) = PolicyComponents.facts(_policy, scope, family);
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
        return PolicyOperations.manifest(_policy, scope);
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
        return PolicyOperations.inputs(_policy, scope, manifestHash);
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
        return PolicyOperations.review(_policy, scope, manifestHash);
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
        (StreamFinalityScopeInputs memory v, bytes32 schema, bytes32 canon,) =
            PolicyOperations.prepared(_policy, scope, manifestHash, components, false);
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
        return PolicyOperations.prepared(_policy, scope, manifestHash, components, true);
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
        return _scopedPolicyConfig(scope).targets[8];
    }

    function scopedPolicySnapshotCodeHash(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        return _scopedPolicyConfig(scope).codeHashes[8];
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
            msg.sender != _policy.targets[12] || msg.sender.code.length == 0
                || msg.sender.codehash != _policy.codeHashes[12]
        ) {
            revert NativeProviderOriginalRegistryOnly();
        }
    }

    function _policyScope(StreamFinalityScope memory scope) private view returns (bool) {
        if (scope.scopeType != StreamFinalityScopeType.COLLECTION) return false;
        Profiles.Sources memory s = Selection.current(_sourceSelection, scope);
        return s.profile.profileHash == Selection.profileHash(2);
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
