// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityBoundedReads.sol";
import "./StreamScopedFinalityInputManifestReads.sol";
import "./StreamFinalityHashes.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalityAdapter.sol";
import "../../interfaces/stream/finality/IStreamCoreFinalitySource.sol";
import {
    IStreamScopedPolicyRenderCriticalInventoryV2
} from "../../interfaces/stream/preservation/IStreamScopedPolicyRenderCriticalInventoryV2.sol";
import {
    IStreamScopedPolicyBundleArchiveCoverageV2
} from "../../interfaces/stream/preservation/IStreamScopedPolicyBundleArchiveCoverageV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2
} from "../../interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    IStreamScopedContentRootPublication
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPolicyReferencePublicationV2
} from "../../interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
import "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamReferenceRenderTypes
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";

import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamFinalityScopedPolicyProviderMetadataV2 as Metadata
} from "./StreamFinalityScopedPolicyProviderMetadataV2.sol";
import {
    StreamFinalityScopedPolicySnapshotReadsV2 as Snapshots
} from "./StreamFinalityScopedPolicySnapshotReadsV2.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as Checkpoint
} from "../../interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicyOutputManifestV2 as Outputs
} from "../../interfaces/stream/finality/IStreamScopedPolicyOutputManifestV2.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as SourceSet
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "./StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamScopedPolicyBundleArchiveTypesV2 as Bundle
} from "../../interfaces/stream/preservation/StreamScopedPolicyBundleArchiveTypesV2.sol";
import {
    StreamBundleArchiveTypes as Archive
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as OutputSchemas
} from "./StreamScopedPolicyOutputSchemasV2.sol";

import {
    StreamFinalityScopedPolicyProviderReadsV2 as R
} from "./StreamFinalityScopedPolicyProviderReadsV2.sol";

/// @notice Original complete configuration checks in the calling provider's delegate context.
library StreamFinalityScopedPolicyProviderPinsV2 {
    function requirePins(R.Config memory c) public view {
        if (
            c.chainId != block.chainid || c.readGas < 50000 || c.componentSourceGas < c.readGas
                || c.componentSourceGas > type(uint32).max
                || c.sourceGas <= c.componentSourceGas + c.componentSourceGas / 63 + 100000
                || c.inventoryDependencyHash == 0
        ) revert R.NativeProviderConfiguration();
        for (uint256 i; i < 22; ++i) {
            if (c.targets[i].code.length == 0 || c.targets[i].codehash != c.codeHashes[i]) {
                revert R.NativeProviderDependency(c.targets[i]);
            }
        }
        _profile(
            c,
            6,
            type(Outputs).interfaceId,
            "scopedOutputProfile()",
            keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")
        );
        _profile(
            c,
            7,
            type(Checkpoint).interfaceId,
            "scopedPolicyProfile()",
            keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")
        );
        _profile(
            c,
            8,
            type(IStreamScopedPolicySnapshotPublicationV2).interfaceId,
            "scopedPolicySnapshotProfile()",
            keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2")
        );
        _profile(
            c,
            9,
            type(IStreamScopedPolicyReferencePublicationV2).interfaceId,
            "scopedPolicyReferenceProfile()",
            keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_V2")
        );
        _profile(
            c,
            10,
            type(Factory).interfaceId,
            "scopedPolicyFactoryProfile()",
            keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        );
        _profile(
            c,
            18,
            type(IStreamScopedPolicyRenderCriticalInventoryV2).interfaceId,
            "scopedPolicyInventoryProfile()",
            keccak256("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_V2")
        );
        _profile(
            c,
            19,
            type(IStreamScopedPolicyBundleArchiveCoverageV2).interfaceId,
            "scopedPolicyBundleArchiveProfile()",
            Bundle.PROFILE
        );
        _address(c, 6, "core()", 0);
        _address(c, 6, "contentCheckpoint()", 7);
        _address(c, 6, "artifactCoverage()", 20);
        _address(c, 7, "core()", 0);
        _address(c, 7, "metadataRouter()", 2);
        _address(c, 7, "sourceFactory()", 10);
        _address(c, 18, "core()", 0);
        _address(c, 18, "metadataHost()", 1);
        _address(c, 18, "metadataRouter()", 2);
        _address(c, 18, "snapshots()", 8);
        _address(c, 18, "referencePublisher()", 9);
        _address(c, 18, "artifactCoverage()", 20);
        _address(c, 18, "externalCoverage()", 21);
        if (_word(c, 18, abi.encodeWithSignature("dependencyHash()")) != c.inventoryDependencyHash)
        {
            revert R.NativeProviderDependency(c.targets[18]);
        }
        _inventoryConfiguration(c);
        _snapshotConfiguration(c);
        _referenceConfiguration(c);
        _address(c, 19, "core()", 0);
        _address(c, 19, "metadataHost()", 1);
        _address(c, 19, "renderCriticalInventory()", 18);
        _address(c, 19, "artifactCoverage()", 20);
        _address(c, 19, "externalCoverage()", 21);
        _address(c, 14, "core()", 0);
        _address(c, 14, "collectionMetadata()", 1);
        _address(c, 12, "coreReads()", 0);
        _address(c, 12, "metadataReads()", 1);
        _address(c, 12, "coreFinalityAdapter()", 14);
        _address(c, 13, "core()", 0);
        _address(c, 13, "metadataHost()", 1);
        _self(c, 12, "scopeEvidenceProvider()");
        _self(c, 13, "scopeEvidenceProvider()");
        _self(c, 14, "evidenceProvider()");
    }

    function _inventoryConfiguration(R.Config memory c) private view {
        bytes memory raw = _read(c, 18, abi.encodeWithSignature("dependencies()"), 1344, c.readGas);
        StreamRenderCriticalSourceTypes.Dependencies memory d =
            abi.decode(raw, (StreamRenderCriticalSourceTypes.Dependencies));
        if (
            keccak256(raw) != keccak256(abi.encode(d))
                || keccak256(raw) != c.inventoryDependencyHash || d.chainId != c.chainId
                || d.artistTargets[0] != c.targets[11] || d.artistCodeHashes[0] != c.codeHashes[11]
        ) {
            revert R.NativeProviderDependency(c.targets[18]);
        }
        uint256[12] memory index = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            if (d.targets[i] != c.targets[index[i]] || d.codeHashes[i] != c.codeHashes[index[i]]) {
                revert R.NativeProviderDependency(c.targets[18]);
            }
        }
        _bundleConfiguration(c, d);
    }

    function _bundleConfiguration(
        R.Config memory c,
        StreamRenderCriticalSourceTypes.Dependencies memory inventory
    ) private view {
        bytes memory raw = _read(c, 19, abi.encodeWithSignature("dependencies()"), 480, c.readGas);
        Archive.Dependencies memory d = abi.decode(raw, (Archive.Dependencies));
        if (
            keccak256(raw) != keccak256(abi.encode(d)) || d.chainId != c.chainId
                || d.targets[5] != inventory.artistTargets[4]
                || d.codeHashes[5] != inventory.artistCodeHashes[4]
                || _word(c, 19, abi.encodeWithSignature("dependencyHash()")) != keccak256(raw)
        ) {
            revert R.NativeProviderDependency(c.targets[19]);
        }
        uint256[5] memory indexes = [uint256(0), 1, 18, 20, 21];
        for (uint256 i; i < 5; ++i) {
            if (
                d.targets[i] != c.targets[indexes[i]] || d.codeHashes[i] != c.codeHashes[indexes[i]]
            ) {
                revert R.NativeProviderDependency(c.targets[19]);
            }
        }
    }

    function _referenceConfiguration(R.Config memory c) private view {
        bytes memory raw = _read(
            c,
            9,
            abi.encodeCall(IStreamScopedPolicyReferencePublicationV2.dependencies, ()),
            608,
            c.readGas
        );
        StreamScopedPolicyReferenceTypesV2.Dependencies memory d =
            abi.decode(raw, (StreamScopedPolicyReferenceTypesV2.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(d)) || d.chainId != c.chainId) {
            revert R.NativeProviderDependency(c.targets[9]);
        }
        uint256[7] memory indexes = [uint256(0), 1, 4, 5, 2, 8, 21];
        for (uint256 i; i < 7; ++i) {
            if (
                d.targets[i] != c.targets[indexes[i]] || d.codeHashes[i] != c.codeHashes[indexes[i]]
            ) {
                revert R.NativeProviderDependency(c.targets[9]);
            }
        }
    }

    function _snapshotConfiguration(R.Config memory c) private view {
        bytes memory raw = _read(
            c,
            8,
            abi.encodeCall(IStreamScopedPolicySnapshotPublicationV2.dependencies, ()),
            832,
            c.readGas
        );
        StreamScopedPolicySnapshotTypesV2.Dependencies memory d =
            abi.decode(raw, (StreamScopedPolicySnapshotTypesV2.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(d)) || d.chainId != c.chainId) {
            revert R.NativeProviderDependency(c.targets[8]);
        }
        uint256[9] memory from = [uint256(0), 1, 2, 3, 4, 5, 7, 8, 9];
        uint256[9] memory to = [uint256(0), 1, 4, 5, 2, 3, 7, 6, 20];
        for (uint256 i; i < from.length; ++i) {
            if (
                d.targets[from[i]] != c.targets[to[i]]
                    || d.codeHashes[from[i]] != c.codeHashes[to[i]]
            ) {
                revert R.NativeProviderDependency(c.targets[8]);
            }
        }
        if (
            _word(c, 7, abi.encodeWithSignature("selectionCheckpoint()"))
                    != bytes32(uint256(uint160(d.targets[6]))) || d.targets[6].code.length == 0
                || d.targets[6].codehash != d.codeHashes[6]
                || _word(c, 7, abi.encodeWithSignature("entropySourceSet()"))
                    != bytes32(uint256(uint160(d.targets[10]))) || d.targets[10].code.length == 0
                || d.targets[10].codehash != d.codeHashes[10]
        ) revert R.NativeProviderDependency(c.targets[8]);
        address sourceSet = d.targets[10];
        if (
            abi.decode(
                        StreamFinalityBoundedReads.read(
                            sourceSet,
                            abi.encodeCall(
                                IERC165.supportsInterface, (type(SourceSet).interfaceId)
                            ),
                            32,
                            c.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        StreamFinalityBoundedReads.read(
                            sourceSet,
                            abi.encodeWithSignature("SOURCE_SET_PROFILE()"),
                            32,
                            c.readGas
                        ),
                        (bytes32)
                    ) != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
                || abi.decode(
                        StreamFinalityBoundedReads.read(
                            sourceSet, abi.encodeCall(SourceSet.factory, ()), 32, c.readGas
                        ),
                        (address)
                    ) != c.targets[10]
                || abi.decode(
                        StreamFinalityBoundedReads.read(
                            sourceSet, abi.encodeWithSignature("core()"), 32, c.readGas
                        ),
                        (address)
                    ) != c.targets[0]
        ) {
            revert R.NativeProviderDependency(sourceSet);
        }
        raw = _read(c, 10, abi.encodeCall(Factory.dependencies, ()), 352, c.readGas);
        Policies.Dependencies memory policies = abi.decode(raw, (Policies.Dependencies));
        if (
            keccak256(raw) != keccak256(abi.encode(policies)) || policies.chainId != c.chainId
                || _word(c, 7, abi.encodeWithSignature("factoryDependenciesHash()"))
                    != keccak256(raw)
                || _word(c, 7, abi.encodeWithSignature("sourceFactoryCodeHash()"))
                    != c.codeHashes[10]
        ) {
            revert R.NativeProviderDependency(c.targets[10]);
        }
        uint256[3] memory indexes = [uint256(0), 1, 3];
        for (uint256 i; i < 3; ++i) {
            if (
                policies.targets[i] != c.targets[indexes[i]]
                    || policies.codeHashes[i] != c.codeHashes[indexes[i]]
            ) {
                revert R.NativeProviderDependency(c.targets[10]);
            }
        }
        if (
            policies.targets[3].code.length == 0
                || policies.targets[3].codehash != policies.codeHashes[3]
        ) {
            revert R.NativeProviderDependency(policies.targets[3]);
        }
    }

    function _profile(
        R.Config memory c,
        uint256 index,
        bytes4 interfaceId,
        string memory selector,
        bytes32 profile
    ) private view {
        if (
            _word(c, index, abi.encodeCall(IERC165.supportsInterface, (interfaceId)))
                    != bytes32(uint256(1))
                || _word(c, index, abi.encodeWithSignature(selector)) != profile
        ) {
            revert R.NativeProviderDependency(c.targets[index]);
        }
    }

    function _read(R.Config memory c, uint256 i, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory)
    {
        return StreamFinalityBoundedReads.read(c.targets[i], input, size, cap);
    }

    function _word(R.Config memory c, uint256 i, bytes memory input)
        private
        view
        returns (bytes32)
    {
        return abi.decode(_read(c, i, input, 32, c.readGas), (bytes32));
    }

    function _address(R.Config memory c, uint256 from, string memory selector, uint256 to)
        private
        view
    {
        if (
            _word(c, from, abi.encodeWithSignature(selector))
                != bytes32(uint256(uint160(c.targets[to])))
        ) {
            revert R.NativeProviderDependency(c.targets[from]);
        }
    }

    function _self(R.Config memory c, uint256 from, string memory selector) private view {
        if (
            _word(c, from, abi.encodeWithSignature(selector))
                != bytes32(uint256(uint160(address(this))))
        ) {
            revert R.NativeProviderDependency(c.targets[from]);
        }
    }
}

import {
    StreamScopedPolicyRenderCriticalTypesV2
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";

import {
    StreamScopedPolicyReferenceTypesV2
} from "../../interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";

import {
    StreamScopedPolicySnapshotTypesV2
} from "../../interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
