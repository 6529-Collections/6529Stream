// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
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
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { StreamMetadataRecoveryRoutes } from "../metadata/StreamMetadataRecoveryRoutes.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../finality/StreamFinalityRouterEvidence.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Entropy
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as ProducerProfiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

/// @notice Fixed dependency and family checks for COLLECTION preservation sources.
library StreamPreservationPolicySnapshotSourceBindingsV1 {
    function bindings(S.Dependencies memory d, bytes32 family) public view {
        bool v2 = _version2(family);
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.inventoryGas < d.readGas || d.readGas > type(uint32).max
                || d.inventoryGas > type(uint32).max || d.sourceGas > type(uint32).max
        ) revert S.InvalidPolicySnapshot();
        for (uint256 i; i < d.targets.length; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert S.PolicySnapshotDependency(d.targets[i]);
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
        ) revert S.PolicySnapshotDependency(d.targets[1]);
        _address(d, 7, "entropySourceSet()", 10);
        _address(d, 10, "core()", 0);
        if (_word(d, 10, "coreCodeHash()") != d.codeHashes[0]) revert S.InvalidPolicySnapshot();
        _supports(d.targets[7], type(Content).interfaceId, d.readGas);
        _supports(d.targets[8], type(Outputs).interfaceId, d.readGas);
        _supports(d.targets[10], type(Entropy).interfaceId, d.readGas);
        if (
            _word(d, 7, "preservationPolicyProfile()")
                    != (v2
                            ? ProducerProfiles.COLLECTION_CHECKPOINT_PROFILE
                            : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1"))
                || _word(d, 8, "outputProfile()")
                    != (v2
                            ? ProducerProfiles.OUTPUT_MANIFEST_PROFILE
                            : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1"))
                || _word(d, 7, "preservationOutputProfile()") != family
                || _word(d, 10, "SOURCE_SET_PROFILE()")
                    != keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
                || _word(d, 7, "entropySourceSetCodeHash()") != d.codeHashes[10]
        ) revert S.InvalidPolicySnapshot();
    }

    function _version2(bytes32 family) private pure returns (bool) {
        if (family == ProducerProfiles.ORIGINAL_PROFILE) return false;
        if (family == ProducerProfiles.FAMILY_PROFILE) return true;
        revert S.InvalidPolicySnapshot();
    }

    function _supports(address target, bytes4 capability, uint256 cap) private view {
        bytes memory raw =
            Reads.read(target, abi.encodeCall(IERC165.supportsInterface, (capability)), 32, cap);
        if (keccak256(raw) != keccak256(abi.encode(true))) {
            revert S.PolicySnapshotDependency(target);
        }
    }

    function _address(S.Dependencies memory d, uint256 at, string memory selector, uint256 expected)
        private
        view
    {
        if (uint256(_word(d, at, selector)) != uint256(uint160(d.targets[expected]))) {
            revert S.PolicySnapshotDependency(d.targets[at]);
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
}
