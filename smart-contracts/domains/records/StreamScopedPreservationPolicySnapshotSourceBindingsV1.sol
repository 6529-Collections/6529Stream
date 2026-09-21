// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamCollectionMetadataV1 as Metadata
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import { IStreamMetadataRouter } from "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import { StreamMetadataRecoveryRoutes } from "../metadata/StreamMetadataRecoveryRoutes.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Entropy
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropySourceFactory as FactoryBase
} from "../../interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityCurrentEntropyRoute,
    StreamFinalityCurrentComponentRoute
} from "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as ProducerProfiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

/// @notice Fixed dependency and family checks for scoped preservation sources.
library StreamScopedPreservationPolicySnapshotSourceBindingsV1 {
    function bindings(S.Dependencies memory d, bytes32 family) public view {
        bool v2 = _version2(family);
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.inventoryGas < d.readGas || d.readGas > type(uint32).max
                || d.inventoryGas > type(uint32).max || d.sourceGas > type(uint32).max
        ) revert S.InvalidScopedPolicySnapshot();
        for (uint256 i; i < d.targets.length; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert S.ScopedPolicySnapshotDependency(d.targets[i]);
            }
        }
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            d.targets[0],
            keccak256("COLLECTION_METADATA"),
            d.targets[1],
            keccak256("COLLECTION_METADATA"),
            type(Metadata).interfaceId
        );
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            d.targets[0],
            keccak256("METADATA_ROUTER"),
            d.targets[4],
            keccak256("METADATA_ROUTER"),
            type(IStreamMetadataRouter).interfaceId
        );
        _address(d, 1, "core()", 0);
        _address(d, 1, "schemaRegistry()", 2);
        _address(d, 1, "chunkStore()", 3);
        _address(d, 2, "chunkStore()", 3);
        _address(d, 4, "core()", 0);
        _address(d, 5, "core()", 0);
        _address(d, 5, "metadataHost()", 1);
        _address(d, 6, "core()", 0);
        _address(d, 6, "metadataHost()", 1);
        _address(d, 6, "metadataRouter()", 4);
        _address(d, 6, "scopeMembership()", 5);
        _address(d, 7, "core()", 0);
        _address(d, 7, "metadataRouter()", 4);
        _address(d, 7, "selectionCheckpoint()", 6);
        _address(d, 8, "core()", 0);
        _address(d, 8, "contentCheckpoint()", 7);
        _address(d, 8, "artifactCoverage()", 9);
        _address(d, 8, "schemaRegistry()", 2);
        _address(d, 9, "core()", 0);
        _address(d, 9, "schemaRegistry()", 2);
        _address(d, 9, "chunkStore()", 3);
        if (
            _word(d, 1, "coreCodeHash()") != d.codeHashes[0]
                || _word(d, 1, "schemaRegistryCodeHash()") != d.codeHashes[2]
                || _word(d, 1, "chunkStoreCodeHash()") != d.codeHashes[3]
        ) revert S.ScopedPolicySnapshotDependency(d.targets[1]);
        _address(d, 7, "entropySourceSet()", 10);
        _address(d, 10, "core()", 0);
        if (_word(d, 10, "coreCodeHash()") != d.codeHashes[0]) {
            revert S.InvalidScopedPolicySnapshot();
        }
        _supports(d.targets[7], type(Content).interfaceId, d.readGas);
        _supports(d.targets[8], type(Outputs).interfaceId, d.readGas);
        _supports(d.targets[10], type(Entropy).interfaceId, d.readGas);
        if (
            _word(d, 7, "preservationPolicyProfile()")
                    != (v2
                            ? ProducerProfiles.SCOPED_CHECKPOINT_PROFILE
                            : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1"))
                || _word(d, 8, "outputProfile()")
                    != (v2
                            ? ProducerProfiles.OUTPUT_MANIFEST_PROFILE
                            : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1"))
                || _word(d, 10, "SOURCE_SET_PROFILE()")
                    != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
                || _word(d, 7, "entropySourceSetCodeHash()") != d.codeHashes[10]
        ) revert S.InvalidScopedPolicySnapshot();
        if (v2 && _word(d, 7, "preservationOutputProfile()") != family) {
            revert S.InvalidScopedPolicySnapshot();
        }
        factory(d);
    }

    function _version2(bytes32 family) private pure returns (bool) {
        if (family == ProducerProfiles.ORIGINAL_PROFILE) return false;
        if (family == ProducerProfiles.FAMILY_PROFILE) return true;
        revert S.InvalidScopedPolicySnapshot();
    }

    function _supports(address target, bytes4 capability, uint256 cap) private view {
        bytes memory raw =
            Reads.read(target, abi.encodeCall(IERC165.supportsInterface, (capability)), 32, cap);
        if (keccak256(raw) != keccak256(abi.encode(true))) {
            revert S.ScopedPolicySnapshotDependency(target);
        }
    }

    function _address(S.Dependencies memory d, uint256 at, string memory selector, uint256 expected)
        private
        view
    {
        if (uint256(_word(d, at, selector)) != uint256(uint160(d.targets[expected]))) {
            revert S.ScopedPolicySnapshotDependency(d.targets[at]);
        }
    }

    function _word(S.Dependencies memory d, uint256 at, string memory selector)
        private
        view
        returns (bytes32)
    {
        return abi.decode(_read(d, at, abi.encodeWithSignature(selector), 32, d.readGas), (bytes32));
    }

    function _read(
        S.Dependencies memory d,
        uint256 at,
        bytes memory input,
        uint256 size,
        uint256 cap
    ) private view returns (bytes memory) {
        return Reads.read(d.targets[at], input, size, cap);
    }

    function factory(S.Dependencies memory d)
        public
        view
        returns (address factory, bytes32 runtime, bytes32 dependenciesHash)
    {
        factory = abi.decode(
            _read(d, 10, abi.encodeCall(Entropy.factory, ()), 32, d.readGas), (address)
        );
        if (factory.code.length == 0) revert S.ScopedPolicySnapshotDependency(factory);
        runtime = factory.codehash;
        if (
            _word(d, 7, "sourceFactory()") != bytes32(uint256(uint160(factory)))
                || _word(d, 7, "sourceFactoryCodeHash()") != runtime
        ) revert S.ScopedPolicySnapshotDependency(factory);
        _supports(factory, type(Factory).interfaceId, d.readGas);
        _supports(factory, type(IStreamFinalityCurrentEntropyRoute).interfaceId, d.readGas);
        if (
            abi.decode(
                    Reads.read(
                        factory,
                        abi.encodeCall(Factory.scopedPolicyFactoryProfile, ()),
                        32,
                        d.readGas
                    ),
                    (bytes32)
                ) != keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        ) {
            revert S.ScopedPolicySnapshotDependency(factory);
        }
        bytes memory raw =
            Reads.read(factory, abi.encodeCall(Factory.dependencies, ()), 352, d.readGas);
        Policies.Dependencies memory original = abi.decode(raw, (Policies.Dependencies));
        _canonical(raw, abi.encode(original));
        dependenciesHash = keccak256(raw);
        if (
            dependenciesHash != _word(d, 7, "factoryDependenciesHash()")
                || original.chainId != d.chainId || original.targets[0] != d.targets[0]
                || original.codeHashes[0] != d.codeHashes[0] || original.targets[1] != d.targets[1]
                || original.codeHashes[1] != d.codeHashes[1] || original.targets[2] != d.targets[5]
                || original.codeHashes[2] != d.codeHashes[5]
        ) revert S.ScopedPolicySnapshotDependency(factory);
        Policies.validateDependencies(original);
        bytes4[4] memory getters = [
            FactoryBase.core.selector,
            FactoryBase.metadataHost.selector,
            FactoryBase.scopeMembershipHost.selector,
            FactoryBase.coordinatorInventory.selector
        ];
        for (uint256 i; i < getters.length; ++i) {
            if (
                abi.decode(
                        Reads.read(factory, abi.encodeWithSelector(getters[i]), 32, d.readGas),
                        (address)
                    ) != original.targets[i]
            ) revert S.ScopedPolicySnapshotDependency(factory);
        }
    }

    function _canonical(bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) revert S.InvalidScopedPolicySnapshot();
    }
}
