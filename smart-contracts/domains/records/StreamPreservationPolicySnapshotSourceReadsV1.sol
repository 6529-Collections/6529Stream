// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as ProducerProfiles
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicySnapshotSourceBindingsV1 as SourceBindings
} from "./StreamPreservationPolicySnapshotSourceBindingsV1.sol";
import {
    StreamPreservationPolicySnapshotCurrentSourcesV1 as CurrentSources
} from "./StreamPreservationPolicySnapshotCurrentSourcesV1.sol";

/// @notice Complete admitted COLLECTION preservation output, canonical Router root and original-source policy joins.
/// @dev A complete output-row archive authenticates hashes, not full rendered byte preservation or
/// Artist root-publication authority. The consumer must retain those separate finality obligations.
/// @dev Fixed workers retain the historical entry points and source-hash domains.
library StreamPreservationPolicySnapshotSourceReadsV1 {
    // Retain the historical ABI for errors bubbled from the fixed workers.
    error InvalidMetadataScope();
    error InvalidPolicySnapshot();
    error PolicySnapshotDependency(address target);
    error RouterEvidenceGas(uint256 available, uint256 required);
    error RouterEvidenceRead(address target, bytes4 selector);

    function scopeSubject(S.Dependencies memory d, StreamFinalityScope memory scope)
        internal
        pure
        returns (bytes32)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0
        ) revert S.InvalidPolicySnapshot();
        return StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
    }

    /// @dev Historical entry point remains fixed to the original producer profile.
    function bindings(S.Dependencies memory d) public view {
        bindings(d, ProducerProfiles.ORIGINAL_PROFILE);
    }

    /// @dev Only a fixed caller configuration selects the closed family; no host autodetection.
    function bindings(S.Dependencies memory d, bytes32 family) public view {
        SourceBindings.bindings(d, family);
    }

    function current(S.Dependencies memory d, S.Publication memory p)
        public
        view
        returns (S.Source memory)
    {
        return current(d, p, ProducerProfiles.ORIGINAL_PROFILE);
    }

    function current(S.Dependencies memory d, S.Publication memory p, bytes32 family)
        public
        view
        returns (S.Source memory f)
    {
        return CurrentSources.current(d, p, family);
    }

    function sourceHash(S.Dependencies memory d, S.Source memory f)
        internal
        view
        returns (bytes32)
    {
        return sourceHash(d, f, ProducerProfiles.ORIGINAL_PROFILE);
    }

    function sourceHash(S.Dependencies memory d, S.Source memory f, bytes32 family)
        internal
        view
        returns (bytes32)
    {
        bool v2 = _version2(family);
        return keccak256(
            abi.encode(
                (v2
                        ? keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2")
                        : keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1")),
                d.chainId,
                address(this),
                d.targets,
                d.codeHashes,
                f
            )
        );
    }

    function _version2(bytes32 family) private pure returns (bool) {
        if (family == ProducerProfiles.ORIGINAL_PROFILE) return false;
        if (family == ProducerProfiles.FAMILY_PROFILE) return true;
        revert S.InvalidPolicySnapshot();
    }
}
