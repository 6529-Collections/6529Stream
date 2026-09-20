// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityPolicyMetadataFactsV2 as Metadata
} from "./StreamFinalityPolicyMetadataFactsV2.sol";
import {
    StreamFinalityPolicyStaticComponentsV2 as Static
} from "./StreamFinalityPolicyStaticComponentsV2.sol";
import {
    StreamFinalityPolicySnapshotReadsV2 as Snapshots
} from "./StreamFinalityPolicySnapshotReadsV2.sol";
import {
    StreamFinalityPolicyStaticSourceV2 as Source
} from "./StreamFinalityPolicyStaticSourceV2.sol";
import {
    StreamPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    IStreamPolicySnapshotPublicationV2 as Snapshot
} from "../../interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import "./StreamFinalityBoundedReads.sol";

/// @notice Fixed new-profile source/component tuple work for the constructor-owned provider.
/// @dev No original V1 operation is routed here. The host selects the profile and checks its
/// original pins/scope before passing its own immutable configuration. No user endpoint accepts it.
library StreamFinalityPolicyProviderComponentsV2 {
    error InvalidPolicyProviderSnapshot();

    function snapshotHash(Native.Config memory c, uint256 cid) public view returns (bytes32) {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0);
        Source.Projection memory p =
            Source.current(_dependencies(c), c.targets[2], c.codeHashes[2], scope);
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
        if (family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) {
            return Metadata.facts(c, scope);
        }
        return Static.facts(_dependencies(c), c.targets[2], c.codeHashes[2], scope, family);
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
