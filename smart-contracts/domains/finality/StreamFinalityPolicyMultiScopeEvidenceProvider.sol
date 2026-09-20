// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityMultiScopeEvidenceProvider.sol";
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
    StreamFinalityPolicyProviderOperationsV2 as PolicyOperations
} from "./StreamFinalityPolicyProviderOperationsV2.sol";
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

/// @notice One selected provider for original COLLECTION, scoped STATIC and policy COLLECTION V2.
/// @dev Every source catalogue/configuration is constructor-only. Current canonical Router profile
/// chooses the collection branch; no source receipt is cast across profiles. Prior deployment
/// identities and records are not inherited. VIEW still requires its distinct adopted-view source.
contract StreamFinalityPolicyMultiScopeEvidenceProvider is
    StreamFinalityMultiScopeEvidenceProvider,
    Profiles,
    IStreamPolicyOutputEvidenceBindingV2,
    IStreamPolicyPublicationEvidenceBindingV2
{
    StreamFinalityNativeProviderReads.Config private _policy;
    Selection.Context private _sourceSelection;

    constructor(
        StreamFinalityNativeProviderReads.Config memory original,
        StreamFinalityScopedProviderReads.Config memory scoped,
        StreamFinalityNativeProviderReads.Config memory policy,
        address outputManifest,
        bytes32 outputManifestCodeHash
    ) StreamFinalityMultiScopeEvidenceProvider(original, scoped) {
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
    }

    function supportsInterface(bytes4 id) public pure virtual override returns (bool) {
        return super.supportsInterface(id) || id == type(Profiles).interfaceId
            || id == type(IStreamPolicyOutputEvidenceBindingV2).interfaceId
            || id == type(IStreamPolicyPublicationEvidenceBindingV2).interfaceId;
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
        return Selection.configurationHash(_sourceSelection);
    }

    function finalitySourcesForScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (Profiles.Sources memory)
    {
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
        if (!_policyScope(scope)) return super.inputManifestBytes(scope);
        return PolicyOperations.manifest(_policy, scope);
    }

    function requireFinalityScopeInputs(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        override
        returns (StreamFinalityScopeInputs memory, bytes32, bytes32)
    {
        if (!_policyScope(scope)) return super.requireFinalityScopeInputs(scope, manifestHash);
        return PolicyOperations.inputs(_policy, scope, manifestHash);
    }

    function requireSanctionReviewFacts(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        override
        returns (IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        if (!_policyScope(scope)) return super.requireSanctionReviewFacts(scope, manifestHash);
        return PolicyOperations.review(_policy, scope, manifestHash);
    }

    function requirePreparedFinalityScopeInputs(
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    ) public view override returns (StreamFinalityScopeInputs memory, bytes32, bytes32) {
        _originalRegistry();
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
        if (!_policyScope(scope)) {
            return
                super.requirePreparedFinalityScopeInputsAndReview(scope, manifestHash, components);
        }
        return PolicyOperations.prepared(_policy, scope, manifestHash, components, true);
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
