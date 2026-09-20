// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamCurrentAuthorityInventoryTypes as CurrentInventoryTypes
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamCurrentAuthorityConfiguration as OriginConfiguration
} from "./StreamCurrentAuthorityConfiguration.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import "../../interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import "./StreamFinalityCoordinatorPolicyReadsV2.sol";
import "./StreamFinalityBoundedReads.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamPolicySnapshotTypesV2 as Snapshot
} from "../../interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    IStreamPolicySnapshotPublicationV2 as Snap
} from "../../interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import {
    StreamPolicyReferenceTypesV2 as Reference
} from "../../interfaces/stream/preservation/StreamPolicyReferenceTypesV2.sol";
import {
    IStreamPolicyReferencePublicationV2 as Ref
} from "../../interfaces/stream/preservation/IStreamPolicyReferencePublicationV2.sol";
import {
    IStreamPolicyContentRootPublicationV2 as RootV2
} from "../../interfaces/stream/metadata/IStreamPolicyContentRootPublicationV2.sol";
import {
    IStreamPolicyOutputEvidenceBindingV2 as OutputBinding
} from "../../interfaces/stream/finality/IStreamPolicyOutputEvidenceBindingV2.sol";
import {
    IStreamPolicyOutputManifestV2 as Output
} from "../../interfaces/stream/finality/IStreamPolicyOutputManifestV2.sol";
import {
    IStreamPolicyContentCheckpointV2 as Checkpoint
} from "../../interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import {
    IStreamFinalityEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Entropy
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamPolicyRenderCriticalInventoryV2 as Inventory
} from "../../interfaces/stream/preservation/IStreamPolicyRenderCriticalInventoryV2.sol";
import {
    StreamPolicySnapshotDefinitionsV2 as SnapshotDefinitions
} from "../records/StreamPolicySnapshotDefinitionsV2.sol";
import {
    StreamPolicyReferenceDefinitionsV2 as ReferenceDefinitions
} from "../records/StreamPolicyReferenceDefinitionsV2.sol";
import {
    StreamPolicyOutputSchemasV2 as OutputDefinitions
} from "./StreamPolicyOutputSchemasV2.sol";
import {
    StreamPolicyContentRootSchemasV2 as RootDefinitions
} from "./StreamPolicyContentRootSchemasV2.sol";
import "./StreamFinalityPolicyInputManifestReadsV2.sol";
import "./StreamFinalityHashes.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalityAdapter.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalitySource.sol";
import "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";
import "../../interfaces/stream/metadata/IStreamCollectionSnapshots.sol";
import "../../interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";
import "../../interfaces/stream/preservation/IStreamRenderCriticalInventory.sol";
import "../../interfaces/stream/preservation/IStreamBundleArchiveCoverage.sol";
import "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";

import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as T
} from "../../interfaces/stream/finality/StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";
import {
    StreamCurrentAuthorityDeferredPolicyGovernanceV2 as Governance
} from "./StreamCurrentAuthorityDeferredPolicyGovernanceV2.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    IStreamArtistArchiveOriginInventory as OriginInventory
} from "../../interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";
import {
    IStreamCurrentAuthorityInventory as AuthorityInventory
} from "../../interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import {
    IStreamStaticSelectionCheckpoint as Static
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";

/// @notice Candidate-aware fixed validation before the host publishes its one-way binding.
/// @dev Original requirePins/snapshot kernels retain their joins. Explicit output pins replace
/// only the pending host's self-getters, avoiding provisional externally visible configuration.
library StreamCurrentAuthorityDeferredPolicyValidationV2 {
    struct Context {
        Native.Config original;
        T.Capability capability;
        O.Dependencies origin;
        D.Dependencies authority;
    }
    error NativeProviderConfiguration();
    error NativeProviderDependency(address target);
    error NativeProviderSource();

    function transition(
        Context memory c,
        Native.Config memory policy,
        address output,
        bytes32 outputHash
    ) public view returns (T.Transition memory) {
        return T.transition(block.chainid, address(this), candidate(c, policy, output, outputHash));
    }

    function bind(Context memory c, Native.Config memory policy, address output, bytes32 outputHash)
        public
        view
        returns (T.Receipt memory r)
    {
        r = candidate(c, policy, output, outputHash);
        r.actionId = Governance.requireExecution(
            c.capability, T.transition(block.chainid, address(this), r), c.original.readGas
        );
        r.bindingHash = T.receiptHash(r);
    }

    function candidate(
        Context memory c,
        Native.Config memory policy,
        address output,
        bytes32 outputHash
    ) public view returns (T.Receipt memory r) {
        _fixed(c, policy);
        Governance.pin(output, outputHash);
        Snapshot.Dependencies memory snapshot = _requirePins(policy, output, outputHash);
        _reference(policy);
        _surfaces(c, policy, snapshot, output, outputHash);
        r.capabilityHash = c.capability.capabilityHash;
        r.policy = policy;
        r.profile = T.boundProfile(
            block.chainid, address(this), r.capabilityHash, policy, output, outputHash
        );
        r.output = output;
        r.outputCodeHash = outputHash;
        r.sourceSet = snapshot.targets[10];
        r.sourceSetCodeHash = snapshot.codeHashes[10];
        _source(policy, r);
    }

    function _fixed(Context memory c, Native.Config memory policy) private view {
        if (
            c.capability.originalHash != keccak256(abi.encode(c.original))
                || c.capability.scopedHash == 0 || c.capability.graphHash == 0
                || c.capability.capabilityHash
                    != T.hashCapability(block.chainid, address(this), c.capability)
                || policy.chainId != c.original.chainId || policy.readGas != c.original.readGas
                || policy.sourceGas != c.original.sourceGas
                || policy.componentSourceGas != c.original.componentSourceGas
                || policy.inventoryDependencyHash == 0
        ) revert T.InvalidCollectionPolicyBinding();
        Governance.pin(c.capability.authority, c.capability.authorityCodeHash);
        for (uint256 i; i < 22; ++i) {
            if (policy.targets[i] == address(0) || policy.codeHashes[i] == 0) {
                revert T.InvalidCollectionPolicyBinding();
            }
            if (
                i != 8 && i != 9 && i != 10 && i != 18 && i != 19
                    && (policy.targets[i] != c.original.targets[i]
                        || policy.codeHashes[i] != c.original.codeHashes[i])
            ) revert T.InvalidCollectionPolicyBinding();
        }
        bytes memory raw =
            _read(policy, 18, abi.encodeWithSignature("originDependencies()"), 128, policy.readGas);
        if (keccak256(raw) != keccak256(abi.encode(c.origin))) {
            revert T.InvalidCollectionPolicyBinding();
        }
        raw = _read(
            policy, 18, abi.encodeWithSignature("authorityDependencies()"), 96, policy.readGas
        );
        if (keccak256(raw) != keccak256(abi.encode(c.authority))) {
            revert T.InvalidCollectionPolicyBinding();
        }
    }

    function _source(Native.Config memory p, T.Receipt memory r) private view {
        uint256 cap = p.readGas;
        bytes memory raw = _at(r.sourceSet, abi.encodeCall(Entropy.sourceScope, ()), 128, cap);
        r.scope = abi.decode(raw, (StreamFinalityScope));
        if (
            keccak256(raw) != keccak256(abi.encode(r.scope))
                || r.scope.scopeType != StreamFinalityScopeType.COLLECTION
                || r.scope.collectionId == 0 || r.scope.tokenId != 0 || r.scope.scopeId != 0
        ) revert T.InvalidCollectionPolicyBinding();
        r.inventoryPlan = _wordAt(r.sourceSet, "inventoryPlan()", cap);
        if (
            r.inventoryPlan == 0
                || abi.decode(
                        _read(
                            p,
                            10,
                            abi.encodeCall(
                                IStreamFinalityEntropySourceFactory.currentInventoryPlan, (r.scope)
                            ),
                            32,
                            p.sourceGas
                        ),
                        (bytes32)
                    ) != r.inventoryPlan
        ) revert T.InvalidCollectionPolicyBinding();
        raw = _read(
            p,
            10,
            abi.encodeCall(IStreamFinalityEntropySourceFactory.sourceSetForPlan, (r.inventoryPlan)),
            64,
            cap
        );
        if (keccak256(raw) != keccak256(abi.encode(r.sourceSet, r.sourceSetCodeHash))) {
            revert T.InvalidCollectionPolicyBinding();
        }
        raw = _read(p, 10, abi.encodeCall(Factory.dependencies, ()), 352, cap);
        StreamFinalityCoordinatorPolicyReadsV2.Dependencies memory deps =
            abi.decode(raw, (StreamFinalityCoordinatorPolicyReadsV2.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(deps))) {
            revert T.InvalidCollectionPolicyBinding();
        }
        r.sourceFactoryDependenciesHash = keccak256(raw);
        // Genuine source-set logic traverses the complete retained inventory and every frozen
        // original policy. A historical finalityState or self-asserted profile is insufficient.
        _at(r.sourceSet, abi.encodeCall(Entropy.requireCurrentSourceSet, ()), 0, p.sourceGas);
        StreamFinalityCoordinatorPolicyEvidenceV2 memory evidence =
            StreamFinalityCoordinatorPolicyReadsV2.requireCurrent(deps, r.scope, r.inventoryPlan);
        if (
            !evidence.allFrozen || evidence.policyCount == 0
                || evidence.inventoryHash != _wordAt(r.sourceSet, "originalInventoryHash()", cap)
                || evidence.policyChainHash
                    != _wordAt(r.sourceSet, "originalPolicyChainHash()", cap)
                || evidence.policyCount != uint256(_wordAt(r.sourceSet, "sourceCount()", cap))
        ) revert T.InvalidCollectionPolicyBinding();
        r.sourceSetDataHash = _wordAt(r.sourceSet, "sourceSetDataHash()", cap);
        _sourceCertificate(p, r, deps, evidence);
    }

    function _sourceCertificate(
        Native.Config memory p,
        T.Receipt memory r,
        StreamFinalityCoordinatorPolicyReadsV2.Dependencies memory deps,
        StreamFinalityCoordinatorPolicyEvidenceV2 memory evidence
    ) private view {
        uint256 cap = p.readGas;
        bytes memory raw =
            _at(r.sourceSet, abi.encodeCall(Entropy.scopeMembershipFacts, ()), 256, cap);
        StreamScopeMembershipFacts memory facts = abi.decode(raw, (StreamScopeMembershipFacts));
        if (keccak256(raw) != keccak256(abi.encode(facts))) {
            revert T.InvalidCollectionPolicyBinding();
        }
        bytes memory current = _at(
            deps.targets[2],
            abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (r.scope)),
            256,
            deps.inventoryGas
        );
        if (keccak256(raw) != keccak256(current)) revert T.InvalidCollectionPolicyBinding();
        address tokenInventory = abi.decode(
            _at(
                deps.targets[2],
                abi.encodeCall(IStreamFinalityScopeMembership.tokenInventory, ()),
                32,
                cap
            ),
            (address)
        );
        bytes32 tokenHash = _wordAt(r.sourceSet, "tokenInventoryCodeHash()", cap);
        Governance.pin(tokenInventory, tokenHash);
        _addressAt(r.sourceSet, "tokenInventory()", tokenInventory, cap);
        _addressAt(tokenInventory, "core()", p.targets[0], cap);
        _hash(r.sourceSet, "coreCodeHash()", p.codeHashes[0], cap);
        bytes32 profile = keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2");
        if (
            r.sourceSetDataHash
                    != keccak256(
                        abi.encode(
                            profile,
                            r.scope,
                            r.inventoryPlan,
                            evidence.inventoryHash,
                            evidence.policyChainHash,
                            facts,
                            tokenInventory,
                            tokenHash
                        )
                    )
                || _wordAt(r.sourceSet, "sourceSetManifestHash()", cap)
                    != keccak256(abi.encode(profile, deps, tokenInventory, tokenHash))
        ) revert T.InvalidCollectionPolicyBinding();
    }

    function _reference(Native.Config memory p) private view {
        bytes memory raw = _read(p, 9, abi.encodeCall(Ref.dependencies, ()), 608, p.readGas);
        Reference.Dependencies memory r = abi.decode(raw, (Reference.Dependencies));
        if (
            keccak256(raw) != keccak256(abi.encode(r)) || r.chainId != p.chainId
                || r.readGas < 50000 || r.sourceGas < r.readGas || r.snapshotGas < r.sourceGas
                || r.archiveGas < r.readGas
        ) revert T.InvalidCollectionPolicyBinding();
        uint256[7] memory slots = [uint256(0), 1, 4, 5, 2, 8, 21];
        for (uint256 i; i < 7; ++i) {
            if (r.targets[i] != p.targets[slots[i]] || r.codeHashes[i] != p.codeHashes[slots[i]]) {
                revert T.InvalidCollectionPolicyBinding();
            }
        }
        _address(p, 9, "core()", 0);
        _address(p, 9, "metadataHost()", 1);
        _address(p, 9, "metadataRouter()", 2);
        _address(p, 9, "snapshots()", 8);
        _address(p, 9, "archiveCoverage()", 21);
    }

    function _surfaces(
        Context memory c,
        Native.Config memory p,
        Snapshot.Dependencies memory s,
        address output,
        bytes32 outputHash
    ) private view {
        uint256 cap = p.readGas;
        _interface(p.targets[8], type(Snap).interfaceId, cap);
        _interface(p.targets[9], type(Ref).interfaceId, cap);
        _interface(p.targets[9], type(IStreamArtworkFinalityComponent).interfaceId, cap);
        _interface(p.targets[9], type(IStreamArtworkScopedFinalityComponent).interfaceId, cap);
        _interface(p.targets[10], type(Factory).interfaceId, cap);
        _interface(p.targets[10], type(IStreamFinalityCurrentEntropyRoute).interfaceId, cap);
        _interface(p.targets[10], type(IStreamFinalityEntropySourceFactory).interfaceId, cap);
        _interface(p.targets[18], type(Inventory).interfaceId, cap);
        _interface(p.targets[18], type(AuthorityInventory).interfaceId, cap);
        _interface(p.targets[18], type(OriginInventory).interfaceId, cap);
        _interface(p.targets[19], type(IStreamBundleArchiveCoverage).interfaceId, cap);
        _interface(output, type(Output).interfaceId, cap);
        _interface(s.targets[6], type(Static).interfaceId, cap);
        _interface(s.targets[7], type(Checkpoint).interfaceId, cap);
        _interface(s.targets[10], type(Entropy).interfaceId, cap);
        if (
            _wordAt(output, "outputProfile()", cap)
                    != keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2")
                || _wordAt(s.targets[7], "PROFILE()", cap)
                    != keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2")
                || _wordAt(s.targets[10], "SOURCE_SET_PROFILE()", cap)
                    != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
        ) revert T.InvalidCollectionPolicyBinding();
        _addressAt(output, "core()", p.targets[0], cap);
        _addressAt(output, "artifactCoverage()", p.targets[20], cap);
        _addressAt(output, "schemaRegistry()", p.targets[4], cap);
        _hash(output, "checkpointCodeHash()", s.codeHashes[7], cap);
        _hash(output, "coverageCodeHash()", p.codeHashes[20], cap);
        _hash(output, "schemaCodeHash()", p.codeHashes[4], cap);
        _hash(
            s.targets[6], "PROFILE()", keccak256("6529STREAM_STATIC_SELECTION_CHECKPOINT_V1"), cap
        );
        _addressAt(s.targets[6], "metadataHost()", p.targets[1], cap);
        _hash(s.targets[6], "coreCodeHash()", p.codeHashes[0], cap);
        _hash(s.targets[6], "routerCodeHash()", p.codeHashes[2], cap);
        _hash(s.targets[6], "membershipCodeHash()", p.codeHashes[3], cap);
        _hash(s.targets[6], "metadataCodeHash()", p.codeHashes[1], cap);
        _addressAt(s.targets[6], "core()", p.targets[0], cap);
        _addressAt(s.targets[6], "metadataRouter()", p.targets[2], cap);
        _addressAt(s.targets[6], "scopeMembership()", p.targets[3], cap);
        _addressAt(s.targets[7], "core()", p.targets[0], cap);
        _addressAt(s.targets[7], "metadataRouter()", p.targets[2], cap);
        _hash(s.targets[7], "selectionCodeHash()", s.codeHashes[6], cap);
        _hash(s.targets[7], "entropySourceSetCodeHash()", s.codeHashes[10], cap);
        _hash(s.targets[7], "coreCodeHash()", p.codeHashes[0], cap);
        _hash(s.targets[7], "routerCodeHash()", p.codeHashes[2], cap);
        address readiness = abi.decode(
            _at(s.targets[7], abi.encodeWithSignature("terminalReadiness()"), 32, cap), (address)
        );
        bytes32 readinessHash = _wordAt(s.targets[7], "terminalReadinessCodeHash()", cap);
        Governance.pin(readiness, readinessHash);
        _addressAt(readiness, "core()", p.targets[0], cap);
        _addressAt(readiness, "metadataRouter()", p.targets[2], cap);
        _addressAt(readiness, "entropySourceSet()", s.targets[10], cap);
        _hash(readiness, "coreCodeHash()", p.codeHashes[0], cap);
        _hash(readiness, "metadataRouterCodeHash()", p.codeHashes[2], cap);
        _hash(readiness, "entropySourceSetCodeHash()", s.codeHashes[10], cap);
        _addressAt(s.targets[6], "governanceAuthority()", c.capability.authority, cap);
        _addressAt(p.targets[8], "governanceAuthority()", c.capability.authority, cap);
        _addressAt(p.targets[9], "governanceAuthority()", c.capability.authority, cap);
        _addressAt(output, "governanceAuthority()", c.capability.authority, cap);
        _addressAt(s.targets[7], "governanceAuthority()", c.capability.authority, cap);
        _hash(p.targets[8], "authorityCodeHash()", c.capability.authorityCodeHash, cap);
        _hash(p.targets[9], "executorCodeHash()", c.capability.authorityCodeHash, cap);
        if (
            s.readGas < 50000 || s.sourceGas < s.readGas || s.inventoryGas < s.readGas
                || s.targets[8] != output || s.codeHashes[8] != outputHash
        ) revert T.InvalidCollectionPolicyBinding();
    }

    function _interface(address target, bytes4 id, uint256 cap) private view {
        if (
            abi.decode(
                        _at(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                            32,
                            cap
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        _at(target, abi.encodeCall(IERC165.supportsInterface, (id)), 32, cap),
                        (uint256)
                    ) != 1
                || abi.decode(
                        _at(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                            32,
                            cap
                        ),
                        (uint256)
                    ) != 0
        ) revert T.CollectionPolicyBindingDependency(target);
    }

    function _at(address target, bytes memory input, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory)
    {
        return StreamFinalityBoundedReads.read(target, input, length, cap);
    }

    function _wordAt(address target, string memory signature, uint256 cap)
        private
        view
        returns (bytes32)
    {
        return abi.decode(_at(target, abi.encodeWithSignature(signature), 32, cap), (bytes32));
    }

    function _addressAt(address target, string memory signature, address expected, uint256 cap)
        private
        view
    {
        _hash(target, signature, bytes32(uint256(uint160(expected))), cap);
    }

    function _hash(address target, string memory signature, bytes32 expected, uint256 cap)
        private
        view
    {
        if (_wordAt(target, signature, cap) != expected) {
            revert T.CollectionPolicyBindingDependency(target);
        }
    }

    function _requirePins(Native.Config memory c, address output, bytes32 outputHash)
        private
        view
        returns (Snapshot.Dependencies memory snapshot)
    {
        if (
            c.chainId != block.chainid || c.readGas < 50000 || c.componentSourceGas < c.readGas
                || c.componentSourceGas > type(uint32).max
                || c.sourceGas <= c.componentSourceGas + c.componentSourceGas / 63 + 100000
                || c.inventoryDependencyHash == 0
        ) revert NativeProviderConfiguration();
        for (uint256 i; i < 22; ++i) {
            if (c.targets[i].code.length == 0 || c.targets[i].codehash != c.codeHashes[i]) {
                revert NativeProviderDependency(c.targets[i]);
            }
        }
        _address(c, 8, "core()", 0);
        _address(c, 8, "metadataHost()", 1);
        _address(c, 10, "core()", 0);
        _address(c, 10, "metadataHost()", 1);
        _address(c, 10, "scopeMembershipHost()", 3);
        _address(c, 18, "core()", 0);
        _address(c, 18, "metadataHost()", 1);
        _address(c, 18, "metadataRouter()", 2);
        _address(c, 18, "snapshots()", 8);
        _address(c, 18, "referencePublisher()", 9);
        _address(c, 18, "artifactCoverage()", 20);
        _address(c, 18, "externalCoverage()", 21);
        if (_word(c, 18, abi.encodeWithSignature("dependencyHash()")) != c.inventoryDependencyHash)
        {
            revert NativeProviderDependency(c.targets[18]);
        }
        if (
            _word(c, 18, abi.encodeCall(Inventory.policyInventoryProfile, ()))
                    != CurrentInventoryTypes.POLICY_INVENTORY_PROFILE
                || _word(c, 10, abi.encodeCall(Factory.policyFactoryProfile, ()))
                    != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        ) revert NativeProviderSource();
        _inventoryConfiguration(c);
        snapshot = _snapshotConfiguration(c, output, outputHash);
        _address(c, 19, "core()", 0);
        _address(c, 19, "metadataHost()", 1);
        _address(c, 19, "renderCriticalInventory()", 18);
        _address(c, 19, "artifactCoverage()", 20);
        _address(c, 19, "externalCoverage()", 21);
        _address(c, 14, "core()", 0);
        _address(c, 14, "collectionMetadata()", 1);
        _address(c, 12, "coreReads()", 0);
        _address(c, 12, "metadataReads()", 1);
        _self(c, 12, "scopeEvidenceProvider()");
        _self(c, 13, "scopeEvidenceProvider()");
        _self(c, 14, "evidenceProvider()");
    }

    function _inventoryConfiguration(Native.Config memory c) private view {
        OriginConfiguration.read(
            c.targets,
            c.codeHashes,
            c.chainId,
            c.readGas,
            c.inventoryDependencyHash,
            CurrentInventoryTypes.POLICY_INVENTORY_PROFILE
        );
    }

    function _snapshotConfiguration(Native.Config memory c, address manifest, bytes32 manifestCode)
        private
        view
        returns (Snapshot.Dependencies memory sd)
    {
        bytes memory raw = _read(c, 8, abi.encodeCall(Snap.dependencies, ()), 832, c.readGas);
        sd = abi.decode(raw, (Snapshot.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(sd)) || sd.chainId != c.chainId) {
            revert NativeProviderSource();
        }
        uint256[6] memory indexes = [uint256(0), 1, 4, 5, 2, 3];
        for (uint256 i; i < 6; ++i) {
            if (
                sd.targets[i] != c.targets[indexes[i]]
                    || sd.codeHashes[i] != c.codeHashes[indexes[i]]
            ) revert NativeProviderDependency(c.targets[8]);
        }
        for (uint256 i; i < 11; ++i) {
            if (sd.targets[i].code.length == 0 || sd.targets[i].codehash != sd.codeHashes[i]) {
                revert NativeProviderDependency(sd.targets[i]);
            }
        }
        if (
            sd.targets[8] != manifest || sd.codeHashes[8] != manifestCode
                || sd.targets[9] != c.targets[20] || sd.codeHashes[9] != c.codeHashes[20]
                || abi.decode(
                        StreamFinalityBoundedReads.read(
                            manifest, abi.encodeCall(Output.contentCheckpoint, ()), 32, c.readGas
                        ),
                        (address)
                    ) != sd.targets[7]
                || abi.decode(
                        StreamFinalityBoundedReads.read(
                            sd.targets[7],
                            abi.encodeCall(Checkpoint.selectionCheckpoint, ()),
                            32,
                            c.readGas
                        ),
                        (address)
                    ) != sd.targets[6]
                || abi.decode(
                        StreamFinalityBoundedReads.read(
                            sd.targets[7],
                            abi.encodeCall(Checkpoint.entropySourceSet, ()),
                            32,
                            c.readGas
                        ),
                        (address)
                    ) != sd.targets[10]
        ) revert NativeProviderSource();
        raw = _read(c, 10, abi.encodeCall(Factory.dependencies, ()), 352, c.readGas);
        StreamFinalityCoordinatorPolicyReadsV2.Dependencies memory fd =
            abi.decode(raw, (StreamFinalityCoordinatorPolicyReadsV2.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(fd)) || fd.chainId != c.chainId) {
            revert NativeProviderSource();
        }
        uint256[3] memory fi = [uint256(0), 1, 3];
        for (uint256 i; i < 4; ++i) {
            if (fd.targets[i].code.length == 0 || fd.targets[i].codehash != fd.codeHashes[i]) {
                revert NativeProviderSource();
            }
            if (
                i < 3
                    && (fd.targets[i] != c.targets[fi[i]]
                        || fd.codeHashes[i] != c.codeHashes[fi[i]])
            ) {
                revert NativeProviderSource();
            }
        }
        if (
            _word(
                        c,
                        10,
                        abi.encodeCall(IStreamFinalityEntropySourceFactory.coordinatorInventory, ())
                    ) != bytes32(uint256(uint160(fd.targets[3])))
                || abi.decode(
                        StreamFinalityBoundedReads.read(
                            sd.targets[10], abi.encodeCall(Entropy.factory, ()), 32, c.readGas
                        ),
                        (address)
                    ) != c.targets[10]
                || abi.decode(
                        StreamFinalityBoundedReads.read(
                            sd.targets[10], abi.encodeWithSignature("core()"), 32, c.readGas
                        ),
                        (address)
                    ) != c.targets[0]
        ) revert NativeProviderSource();
    }

    function _read(Native.Config memory c, uint256 i, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory)
    {
        return StreamFinalityBoundedReads.read(c.targets[i], input, size, cap);
    }

    function _word(Native.Config memory c, uint256 i, bytes memory input)
        private
        view
        returns (bytes32)
    {
        return abi.decode(_read(c, i, input, 32, c.readGas), (bytes32));
    }

    function _address(Native.Config memory c, uint256 from, string memory selector, uint256 to)
        private
        view
    {
        if (
            _word(c, from, abi.encodeWithSignature(selector))
                != bytes32(uint256(uint160(c.targets[to])))
        ) {
            revert NativeProviderDependency(c.targets[from]);
        }
    }

    function _self(Native.Config memory c, uint256 from, string memory selector) private view {
        if (
            _word(c, from, abi.encodeWithSignature(selector))
                != bytes32(uint256(uint160(address(this))))
        ) {
            revert NativeProviderDependency(c.targets[from]);
        }
    }
}
