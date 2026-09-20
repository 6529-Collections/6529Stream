// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationTokenProducerProfilesV1 as Producers
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicySnapshotFamiliesV2 as SnapshotFamilies
} from "../records/StreamPreservationPolicySnapshotFamiliesV2.sol";
import {
    StreamPreservationPolicyRootFamiliesV2 as RootFamilies
} from "./StreamPreservationPolicyRootFamiliesV2.sol";

import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityPreservationPolicyMetadataFactsV1 as Metadata
} from "./StreamFinalityPreservationPolicyMetadataFactsV1.sol";
import {
    StreamFinalityPreservationPolicyStaticComponentsV1 as Static
} from "./StreamFinalityPreservationPolicyStaticComponentsV1.sol";
import {
    StreamFinalityPreservationPolicySnapshotReadsV1 as Snapshots
} from "./StreamFinalityPreservationPolicySnapshotReadsV1.sol";
import {
    StreamFinalityPreservationPolicyStaticSourceV1 as Source
} from "./StreamFinalityPreservationPolicyStaticSourceV1.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../interfaces/stream/metadata/IStreamPreservationPolicySnapshotPublicationV1.sol";
import "./StreamFinalityBoundedReads.sol";

/// @notice Fixed new-profile source/component tuple work for the constructor-owned provider.
/// @dev No original V1 operation is routed here. The host selects the profile and checks its
/// original pins/scope before passing its own immutable configuration. No user endpoint accepts it.
library StreamFinalityPreservationPolicyProviderComponentsV1 {
    error InvalidPolicyProviderSnapshot();

    function snapshotHash(Native.Config memory c, uint256 cid) public view returns (bytes32) {
        return snapshotHash(c, cid, Producers.ORIGINAL_PROFILE);
    }

    function snapshotHash(Native.Config memory c, uint256 cid, bytes32 preservationFamily)
        public
        view
        returns (bytes32)
    {
        SnapshotFamilies.version2(preservationFamily);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0);
        Source.Projection memory p = Source.current(
            _dependencies(c), c.targets[2], c.codeHashes[2], scope, preservationFamily
        );
        bytes memory raw = StreamFinalityBoundedReads.read(
            c.targets[8], abi.encodeCall(Snapshot.currentSnapshot, (scope)), 544, c.readGas
        );
        S.Receipt memory r = abi.decode(raw, (S.Receipt));
        if (keccak256(raw) != keccak256(abi.encode(r)) || r.recordHash != p.snapshotRecordHash) {
            revert InvalidPolicyProviderSnapshot();
        }
        return r.manifestHash;
    }

    function facts(Native.Config memory c, StreamFinalityScope memory scope, bytes32 family)
        public
        view
        returns (bool, bytes32)
    {
        return facts(c, scope, family, Producers.ORIGINAL_PROFILE);
    }

    function facts(
        Native.Config memory c,
        StreamFinalityScope memory scope,
        bytes32 family,
        bytes32 preservationFamily
    ) public view returns (bool, bytes32) {
        SnapshotFamilies.version2(preservationFamily);
        if (family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) {
            return Metadata.facts(c, scope, preservationFamily);
        }
        return Static.facts(
            _dependencies(c), c.targets[2], c.codeHashes[2], scope, family, preservationFamily
        );
    }

    function _dependencies(Native.Config memory c)
        private
        pure
        returns (Snapshots.Dependencies memory)
    {
        return Snapshots.Dependencies(
            c.targets[0],
            c.targets[1],
            c.targets[8],
            c.codeHashes[0],
            c.codeHashes[1],
            c.codeHashes[8],
            c.chainId,
            c.readGas,
            c.componentSourceGas
        );
    }
}
