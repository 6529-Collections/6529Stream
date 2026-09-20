// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityStaticComponentFacts as Static
} from "./StreamFinalityStaticComponentFacts.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderReadsV1 as Provider
} from "./StreamFinalityScopedPreservationPolicyProviderReadsV1.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderMetadataV1 as Metadata
} from "./StreamFinalityScopedPreservationPolicyProviderMetadataV1.sol";
import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as Snapshots
} from "./StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";

import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Original scoped snapshot/root authority adapter for local STATIC component facts.
/// @dev Called in the actual combined provider with constructor-only configuration. The exact
/// retained carrier and fresh original snapshot validation authenticate the private projection;
/// no complete inventory/reference/input-manifest or component callback creates a dependency cycle.
library StreamFinalityScopedPreservationPolicyStaticComponentsV1 {
    error ScopedStaticSource();

    function facts(Provider.Config memory c, StreamFinalityScope memory scope, bytes32 family)
        public
        view
        returns (bool, bytes32)
    {
        Snapshots.Dependencies memory fixed_ = Snapshots.Dependencies(
            c.targets[0],
            c.targets[1],
            c.targets[2],
            c.targets[8],
            c.codeHashes[0],
            c.codeHashes[1],
            c.codeHashes[2],
            c.codeHashes[8],
            c.chainId,
            c.readGas,
            c.componentSourceGas
        );
        if (
            abi.decode(
                        Reads.read(
                            c.targets[8],
                            abi.encodeCall(IERC165.supportsInterface, (type(Snapshot).interfaceId)),
                            32,
                            c.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        Reads.read(
                            c.targets[8],
                            abi.encodeCall(Snapshot.scopedPreservationPolicySnapshotProfile, ()),
                            32,
                            c.readGas
                        ),
                        (bytes32)
                    ) != keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1")
        ) {
            revert ScopedStaticSource();
        }
        bytes memory raw = Reads.read(
            c.targets[8], abi.encodeCall(Snapshot.currentSnapshot, (scope)), 544, c.readGas
        );
        S.Receipt memory r = abi.decode(raw, (S.Receipt));
        if (keccak256(raw) != keccak256(abi.encode(r))) revert ScopedStaticSource();
        Snapshots.requireLocked(fixed_, scope, r.recordHash, r.revision);
        Metadata.Config memory mc = Metadata.Config(fixed_, c.targets[3], c.codeHashes[3]);
        // requireLocked above authenticates the current source before this original projection.
        Metadata.RootFacts memory original = Metadata.rootFacts(mc, scope, false);
        S.Dependencies memory d = original.dependencies;
        if (keccak256(abi.encode(original.snapshot)) != keccak256(abi.encode(r))) {
            revert ScopedStaticSource();
        }
        Static.Config memory config = Static.Config(
            d.targets[0],
            d.targets[1],
            d.targets[4],
            d.targets[6],
            d.codeHashes[0],
            d.codeHashes[1],
            d.codeHashes[4],
            d.codeHashes[6],
            d.chainId,
            c.readGas,
            c.componentSourceGas
        );
        Static.AuthenticatedSelection memory selected = Static.AuthenticatedSelection(
            scope,
            r.profileHash,
            original.source.content.selectionId,
            original.source.selection.membershipHash,
            original.source.selection.selectionRoot,
            original.source.selection.tokenCount,
            original.source.artist.snapshotHash
        );
        return Static.facts(config, selected, family);
    }
}
