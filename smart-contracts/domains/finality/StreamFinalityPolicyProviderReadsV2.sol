// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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

/// @notice Current native collection inputs from one fixed, fully authenticated source inventory.
/// @dev Inventory is a semantic producer, not a caller-supplied list. Its exact constructor
/// configuration is pinned as well as runtime. Original headers only project already-validated
/// current records; component-state validation independently proves terminal locks and entropy.
library StreamFinalityPolicyProviderReadsV2 {
    error NativeProviderConfiguration();
    error NativeProviderDependency(address target);
    error NativeProviderScope();
    error NativeProviderSource();
    error NativeProviderComponent(uint256 index);
    error NativeProviderTerminal();

    function requirePins(Native.Config memory c) public view {
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
                    != keccak256("6529STREAM_POLICY_COLLECTION_RENDER_CRITICAL_V2")
                || _word(c, 10, abi.encodeCall(Factory.policyFactoryProfile, ()))
                    != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        ) revert NativeProviderSource();
        _inventoryConfiguration(c);
        _snapshotConfiguration(c);
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

    function statement(
        Native.Config memory c,
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] memory components
    ) public view returns (StreamFinalityPolicyInputManifestTypesV2.Statement memory s) {
        requirePins(c);
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0
        ) revert NativeProviderScope();
        s.scope = scope;
        s.nonSanctionComponents = components;

        s.postFreezePolicy = 1;
        s.sanctionPolicy = 1;
        // Exactly one complete current source pass. Coverage consumes the same immutable plan.
        bytes memory raw = _read(
            c,
            18,
            abi.encodeCall(IStreamRenderCriticalInventory.requireCurrent, (scope.collectionId)),
            608,
            c.sourceGas
        );
        StreamPreservationInventoryTypes.Evidence memory e =
            abi.decode(raw, (StreamPreservationInventoryTypes.Evidence));
        if (
            keccak256(raw) != keccak256(abi.encode(e)) || e.planId == 0
                || e.collectionId != scope.collectionId
                || e.scopeSubject
                    != StreamMetadataSubjects.scopeSubject(c.chainId, c.targets[0], scope)
                || e.artistId == 0 || e.sourceContextHash == 0 || e.tokenInventoryHash == 0
                || e.tokenCount == 0 || e.segmentCount == 0 || e.itemCount == 0
                || e.segmentChainHash == 0 || e.renderCriticalEvidenceHash == 0
        ) revert NativeProviderSource();
        _coverage(c, e, s);
        _headers(c, e, s);
        _core(c, s);
    }

    function manifestDependencies(Native.Config memory c)
        public
        pure
        returns (StreamFinalityPolicyInputManifestReadsV2.Dependencies memory d)
    {
        uint256[5] memory indexes = [uint256(0), 1, 4, 5, 12];
        for (uint256 i; i < 5; ++i) {
            d.targets[i] = c.targets[indexes[i]];
            d.codeHashes[i] = c.codeHashes[indexes[i]];
        }
        d.chainId = c.chainId;
        d.readGas = c.readGas;
    }

    function _inventoryConfiguration(Native.Config memory c) private view {
        bytes memory raw = _read(c, 18, abi.encodeWithSignature("dependencies()"), 1344, c.readGas);
        StreamRenderCriticalSourceTypes.Dependencies memory d =
            abi.decode(raw, (StreamRenderCriticalSourceTypes.Dependencies));
        if (
            keccak256(raw) != keccak256(abi.encode(d))
                || keccak256(raw) != c.inventoryDependencyHash || d.chainId != c.chainId
                || d.artistTargets[0] != c.targets[11] || d.artistCodeHashes[0] != c.codeHashes[11]
        ) {
            revert NativeProviderDependency(c.targets[18]);
        }
        uint256[12] memory index = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            if (d.targets[i] != c.targets[index[i]] || d.codeHashes[i] != c.codeHashes[index[i]]) {
                revert NativeProviderDependency(c.targets[18]);
            }
        }
    }

    function _snapshotConfiguration(Native.Config memory c)
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
        address manifest = abi.decode(
            StreamFinalityBoundedReads.read(
                address(this),
                abi.encodeCall(OutputBinding.policyOutputManifestV2, ()),
                32,
                c.readGas
            ),
            (address)
        );
        bytes32 manifestCode = abi.decode(
            StreamFinalityBoundedReads.read(
                address(this),
                abi.encodeCall(OutputBinding.policyOutputManifestV2CodeHash, ()),
                32,
                c.readGas
            ),
            (bytes32)
        );
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

    function _coverage(
        Native.Config memory c,
        StreamPreservationInventoryTypes.Evidence memory e,
        StreamFinalityPolicyInputManifestTypesV2.Statement memory s
    ) private view {
        bytes memory raw = _read(
            c,
            19,
            abi.encodeCall(
                IStreamBundleArchiveCoverage.requireCoverage,
                (e.planId, e.renderCriticalEvidenceHash)
            ),
            160,
            c.sourceGas
        );
        StreamPreservationInventoryTypes.BundleEvidence memory b =
            abi.decode(raw, (StreamPreservationInventoryTypes.BundleEvidence));
        if (
            keccak256(raw) != keccak256(abi.encode(b)) || b.inventoryPlan != e.planId
                || b.renderCriticalEvidenceHash != e.renderCriticalEvidenceHash
                || b.itemCount != e.itemCount || b.evidenceChainHash == 0
                || b.bundleCoverageHash == 0
        ) revert NativeProviderSource();
        StreamPreservationInventoryTypes.OriginalInputs memory o = e.originals;
        s.inputs = StreamFinalityScopeInputs(
            o.rootRecordHash,
            o.snapshotRecordHash,
            o.referenceRenderRecordHash,
            o.intentRecordHash,
            o.intentWaiverRecordHash,
            o.interviewEvidenceHash,
            o.rightsStatementRecordHash,
            o.workDescriptionRecordHash,
            e.renderCriticalEvidenceHash,
            b.bundleCoverageHash
        );
    }

    function _headers(
        Native.Config memory c,
        StreamPreservationInventoryTypes.Evidence memory e,
        StreamFinalityPolicyInputManifestTypesV2.Statement memory s
    ) private view {
        if (
            _word(
                    c,
                    2,
                    abi.encodeCall(
                        IStreamContentRootPublication.collectionContentRootHead,
                        (s.scope.collectionId)
                    )
                ) != e.originals.rootRecordHash
        ) revert NativeProviderSource();
        bytes memory raw = _read(
            c,
            2,
            abi.encodeCall(
                IStreamContentRootPublication.tokenContentRoot,
                (s.scope.collectionId, e.scopeSubject)
            ),
            96,
            c.readGas
        );
        (s.contentRoot, s.leafCount, s.contentRootSchemaId) =
            abi.decode(raw, (bytes32, uint64, bytes32));
        if (
            keccak256(raw)
                    != keccak256(abi.encode(s.contentRoot, s.leafCount, s.contentRootSchemaId))
                || s.contentRoot == 0 || s.leafCount != e.tokenCount
                || s.contentRootSchemaId != OutputDefinitions.LEAF_SCHEMA
        ) revert NativeProviderSource();
        raw = _read(c, 8, abi.encodeCall(Snap.currentSnapshot, (s.scope)), 544, c.readGas);
        Snapshot.Receipt memory snapshot = abi.decode(raw, (Snapshot.Receipt));
        if (
            keccak256(raw) != keccak256(abi.encode(snapshot))
                || snapshot.recordHash != e.originals.snapshotRecordHash
                || snapshot.scopeSubject != e.scopeSubject || snapshot.manifestHash == 0
                || snapshot.profileHash != SnapshotDefinitions.PROFILE_HASH
        ) revert NativeProviderSource();
        s.snapshotManifestHash = snapshot.manifestHash;
        raw = _read(c, 9, abi.encodeCall(Ref.currentReference, (s.scope)), 672, c.readGas);
        Reference.Receipt memory ref_ = abi.decode(raw, (Reference.Receipt));
        if (
            keccak256(raw) != keccak256(abi.encode(ref_)) || ref_.scopeSubject != e.scopeSubject
                || ref_.observation.recordHash != e.originals.referenceRenderRecordHash
                || ref_.observation.collectionId != s.scope.collectionId
                || ref_.observation.payloadHash == 0
                || ref_.observation.snapshotRecordHash != snapshot.recordHash
                || ref_.observation.snapshotRevision != snapshot.revision
                || ref_.observation.profileHash != ReferenceDefinitions.PROFILE_HASH
        ) revert NativeProviderSource();
        s.referenceRenderManifestHash = ref_.observation.payloadHash;
        _entropy(
            c, s, e.originals.rootRecordHash, snapshot.profileHash, ref_.observation.profileHash
        );
    }

    function _entropy(
        Native.Config memory c,
        StreamFinalityPolicyInputManifestTypesV2.Statement memory s,
        bytes32 root,
        bytes32 snapshotProfile,
        bytes32 refProfile
    ) private view {
        Snapshot.Dependencies memory sd = _snapshotConfiguration(c);
        bytes memory raw =
            _read(c, 2, abi.encodeCall(RootV2.policyContentRootBinding, (root)), 544, c.readGas);
        RootV2.Binding memory b = abi.decode(raw, (RootV2.Binding));
        if (
            keccak256(raw) != keccak256(abi.encode(b))
                || b.profileId != keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2")
                || b.outputManifest != sd.targets[8] || b.outputManifestCodeHash != sd.codeHashes[8]
                || b.checkpoint != sd.targets[7] || b.checkpointCodeHash != sd.codeHashes[7]
                || b.entropySourceSet != sd.targets[10]
                || b.entropySourceSetCodeHash != sd.codeHashes[10]
        ) revert NativeProviderSource();
        bytes32 plan = _word(
            c,
            10,
            abi.encodeCall(IStreamFinalityEntropySourceFactory.currentInventoryPlan, (s.scope))
        );
        raw = _read(
            c,
            10,
            abi.encodeCall(IStreamFinalityEntropySourceFactory.sourceSetForPlan, (plan)),
            64,
            c.readGas
        );
        (address set, bytes32 runtime) = abi.decode(raw, (address, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(set, runtime)) || set != sd.targets[10]
                || runtime != sd.codeHashes[10] || plan == 0
        ) revert NativeProviderSource();
        raw = _read(
            c,
            10,
            abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (s.scope)),
            128,
            c.sourceGas
        );
        StreamFinalityCurrentComponentRoute memory route =
            abi.decode(raw, (StreamFinalityCurrentComponentRoute));
        if (
            keccak256(raw) != keccak256(abi.encode(route)) || route.component != set
                || route.codeHash != runtime
                || route.componentType != StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR
                || route.interfaceId != type(IStreamArtworkFinalityComponent).interfaceId
        ) revert NativeProviderSource();
        s.entropy.sourceSet = set;
        s.entropy.sourceSetCodeHash = runtime;
        s.entropy.sourceSetProfile = abi.decode(
            StreamFinalityBoundedReads.read(
                set, abi.encodeWithSignature("SOURCE_SET_PROFILE()"), 32, c.readGas
            ),
            (bytes32)
        );
        s.entropy.inventoryPlan = plan;
        s.entropy.inventoryHash = abi.decode(
            StreamFinalityBoundedReads.read(
                set, abi.encodeCall(Entropy.originalInventoryHash, ()), 32, c.readGas
            ),
            (bytes32)
        );
        s.entropy.policyChainHash = abi.decode(
            StreamFinalityBoundedReads.read(
                set, abi.encodeCall(Entropy.originalPolicyChainHash, ()), 32, c.readGas
            ),
            (bytes32)
        );
        s.entropy.policyCount = abi.decode(
            StreamFinalityBoundedReads.read(
                set, abi.encodeCall(Entropy.sourceCount, ()), 32, c.readGas
            ),
            (uint256)
        );
        s.entropy.snapshotProfileHash = snapshotProfile;
        s.entropy.referenceProfileHash = refProfile;
        if (
            s.entropy.inventoryHash != b.inventoryHash
                || s.entropy.policyChainHash != b.policyChainHash || s.entropy.policyCount == 0
                || s.entropy.sourceSetProfile
                    != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
        ) revert NativeProviderSource();
    }

    function _core(
        Native.Config memory c,
        StreamFinalityPolicyInputManifestTypesV2.Statement memory s
    ) private view {
        bytes memory raw = _read(
            c,
            14,
            abi.encodeCall(
                IStreamCoreFinalityAdapter.coreCollectionFinalityFacts, (s.scope.collectionId)
            ),
            288,
            c.readGas
        );
        StreamCoreCollectionFinalityFacts memory f =
            abi.decode(raw, (StreamCoreCollectionFinalityFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(f)) || !f.exists
                || f.status != StreamFinalityDomains.CORE_COLLECTION_STATUS_CLOSED
                || f.supplyMode > StreamFinalityDomains.CORE_COLLECTION_SUPPLY_MODE_UNCAPPED_OPEN
                || f.mintedSupply != s.leafCount
                || _word(
                        c,
                        0,
                        abi.encodeCall(
                            IStreamCoreFinalitySource.collectionBurnsBlocked, (s.scope.collectionId)
                        )
                    ) != bytes32(uint256(1))
                || _word(
                        c,
                        0,
                        abi.encodeCall(
                            IStreamCoreFinalitySource.collectionFreezeStatus, (s.scope.collectionId)
                        )
                    ) != bytes32(uint256(1))
        ) {
            revert NativeProviderTerminal();
        }
        s.coreFactsHash =
            StreamFinalityHashes.coreCollectionFactsHash(c.targets[0], s.scope.collectionId, f);
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
