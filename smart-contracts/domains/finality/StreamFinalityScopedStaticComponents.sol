// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityStaticComponentFacts as Static
} from "./StreamFinalityStaticComponentFacts.sol";
import {
    StreamFinalityScopedProviderReads as Provider
} from "./StreamFinalityScopedProviderReads.sol";
import {
    StreamFinalityScopedProviderMetadata as Metadata
} from "./StreamFinalityScopedProviderMetadata.sol";
import {
    StreamFinalityScopedSnapshotReads as Snapshots
} from "./StreamFinalityScopedSnapshotReads.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";
import {
    IStreamScopedSnapshotPublication as Snapshot
} from "../../interfaces/stream/metadata/IStreamScopedSnapshotPublication.sol";
import {
    StreamScopedSnapshotTypes as S
} from "../../interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";

/// @notice Original scoped snapshot/root authority adapter for local STATIC component facts.
/// @dev Called in the actual combined provider with constructor-only configuration. The exact
/// retained carrier and fresh original snapshot validation authenticate the private projection;
/// no complete inventory/reference/input-manifest or component callback creates a dependency cycle.
library StreamFinalityScopedStaticComponents {
    struct Carrier {
        bytes32 domain;
        uint256 chainId;
        address host;
        address[11] targets;
        bytes32[11] codeHashes;
        S.Publication publication;
        S.Receipt receipt;
        S.Source source;
    }
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
        bytes memory raw = Reads.read(
            c.targets[8], abi.encodeCall(Snapshot.currentSnapshot, (scope)), 544, c.readGas
        );
        S.Receipt memory r = abi.decode(raw, (S.Receipt));
        if (keccak256(raw) != keccak256(abi.encode(r))) revert ScopedStaticSource();
        Snapshots.requireLocked(fixed_, scope, r.recordHash, r.revision);
        Metadata.Config memory mc = Metadata.Config(fixed_, c.targets[3], c.codeHashes[3]);
        Metadata.root(mc, scope);
        raw = Reads.read(c.targets[8], abi.encodeCall(Snapshot.dependencies, ()), 832, c.readGas);
        S.Dependencies memory d = abi.decode(raw, (S.Dependencies));
        if (keccak256(raw) != keccak256(abi.encode(d))) revert ScopedStaticSource();
        Carrier memory original = _payload(c, d, r);
        if (keccak256(abi.encode(original.source.scope)) != keccak256(abi.encode(scope))) {
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

    function _payload(Provider.Config memory c, S.Dependencies memory d, S.Receipt memory r)
        private
        view
        returns (Carrier memory value)
    {
        bytes memory wrapped = Reads.dynamicRead(
            c.targets[8],
            abi.encodeCall(Snapshot.snapshotPayload, (r.recordHash)),
            524352,
            c.componentSourceGas
        );
        bytes memory raw = abi.decode(wrapped, (bytes));
        if (
            keccak256(wrapped) != keccak256(abi.encode(raw)) || raw.length != r.manifestBytes
                || keccak256(raw) != r.manifestHash
        ) revert ScopedStaticSource();
        (
            value.domain,
            value.chainId,
            value.host,
            value.targets,
            value.codeHashes,
            value.publication,
            value.receipt,
            value.source
        ) =
            abi.decode(
                raw,
                (
                    bytes32,
                    uint256,
                    address,
                    address[11],
                    bytes32[11],
                    S.Publication,
                    S.Receipt,
                    S.Source
                )
            );
        if (
            keccak256(raw)
                    != keccak256(
                        abi.encode(
                            value.domain,
                            value.chainId,
                            value.host,
                            value.targets,
                            value.codeHashes,
                            value.publication,
                            value.receipt,
                            value.source
                        )
                    ) || value.domain != keccak256("6529STREAM_SCOPED_SNAPSHOT_PAYLOAD_V1")
                || value.chainId != c.chainId || value.host != c.targets[8]
                || keccak256(abi.encode(value.targets, value.codeHashes))
                    != keccak256(abi.encode(d.targets, d.codeHashes))
        ) revert ScopedStaticSource();
        (S.Publication memory p, S.Receipt memory original) = Snapshots.original(
            Snapshots.Dependencies(
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
            ),
            value.source.scope,
            r.recordHash,
            r.revision
        );
        if (keccak256(abi.encode(original)) != keccak256(abi.encode(r))) {
            revert ScopedStaticSource();
        }
        p.expectedSourceHash = 0;
        original.recordHash = 0;
        original.chainHash = 0;
        original.manifestHash = 0;
        original.manifestBytes = 0;
        original.recordedAt = 0;
        if (
            keccak256(abi.encode(p, original))
                    != keccak256(abi.encode(value.publication, value.receipt))
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SCOPED_STATIC_SNAPSHOT_SOURCES_V1"),
                            c.chainId,
                            c.targets[8],
                            d.targets,
                            d.codeHashes,
                            value.source
                        )
                    ) != r.sourceHash
        ) revert ScopedStaticSource();
    }
}
