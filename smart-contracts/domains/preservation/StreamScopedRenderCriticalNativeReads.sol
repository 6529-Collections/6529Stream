// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedRenderCriticalTypes as Scoped
} from "../../interfaces/stream/preservation/StreamScopedRenderCriticalTypes.sol";
import {
    StreamScopedReferenceTypes as R
} from "../../interfaces/stream/preservation/StreamScopedReferenceTypes.sol";
import {
    StreamScopedSnapshotTypes as Snapshot
} from "../../interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
import {
    IStreamScopedSnapshotPublication as Snap
} from "../../interfaces/stream/metadata/IStreamScopedSnapshotPublication.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamScopedRenderCriticalState as State } from "./StreamScopedRenderCriticalState.sol";
import {
    StreamScopedRenderCriticalSourceReads as Sources
} from "./StreamScopedRenderCriticalSourceReads.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import {
    StreamScopedSnapshotDefinitions as Definitions
} from "../records/StreamScopedSnapshotDefinitions.sol";

/// @notice Complete original scoped source/receipt/runtime inventory in bounded ordered segments.
/// @dev Output manifest rows are hash inventory, explicitly separate from per-token full-byte rows.
library StreamScopedRenderCriticalNativeReads {
    function appendNative(State.State storage state, bytes32 id, uint64 maximum) public {
        State.stage(state, id, 0);
        Scoped.Plan storage p = state.plans[id];
        (T.Item[] memory rows, uint64 total) =
            items(state.dependencies, state.contexts[id], p.nativeCursor, maximum);
        if (p.nativeCursor != 0 && p.nativeCount != total) revert T.InventorySourceChanged();
        p.nativeCount = total;
        State.append(
            state,
            id,
            rows,
            keccak256(abi.encode(p.progress.sourceContextHash, p.nativeCursor, total))
        );
        p.nativeCursor += uint64(rows.length);
        if (p.nativeCursor == total) p.progress.completedStages = 1;
    }

    function items(S.Dependencies memory d, Scoped.Context memory c, uint64 start, uint64 maximum)
        public
        view
        returns (T.Item[] memory rows, uint64 total)
    {
        if (maximum == 0 || maximum > 64) revert T.InvalidInventorySegment();
        Snapshot.Dependencies memory sd = Sources.snapshotBindings(d);
        R.SourceFacts memory f = Sources.sourceFacts(d, c);
        uint256 count = 38 + f.snapshotSource.entropy.policies.length * 2;
        if (
            count > type(uint64).max || start >= count || !f.snapshotSource.entropy.allFrozen
                || f.snapshotSource.entropy.policyCount != f.snapshotSource.entropy.policies.length
        ) revert T.InventorySourceChanged();
        total = uint64(count);
        uint256 length = count - start;
        if (length > maximum) length = maximum;
        rows = new T.Item[](length);
        bytes32 original = c.snapshot.recordHash;
        for (uint256 i; i < length; ++i) {
            uint256 at = start + i;
            if (at == 0) {
                bytes memory raw = IO.read(
                    d.targets[5],
                    abi.encodeCall(Snap.snapshotRecord, (original)),
                    16384,
                    d.sourceGas
                );
                (Snapshot.Publication memory p, Snapshot.Receipt memory saved) =
                    abi.decode(raw, (Snapshot.Publication, Snapshot.Receipt));
                IO.canonical(d.targets[5], raw, abi.encode(p, saved));
                if (
                    keccak256(abi.encode(saved)) != keccak256(abi.encode(c.snapshot))
                        || keccak256(abi.encode(p.scope)) != keccak256(abi.encode(c.scope))
                ) revert T.InventorySourceChanged();
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_SCOPED_SNAPSHOT_RECORD"),
                    d.targets[5],
                    original,
                    0,
                    raw
                );
            } else if (at == 1) {
                bytes memory raw = IO.read(
                    d.targets[5],
                    abi.encodeCall(Snap.snapshotPayload, (original)),
                    524352,
                    d.sourceGas
                );
                bytes memory payload = abi.decode(raw, (bytes));
                IO.canonical(d.targets[5], raw, abi.encode(payload));
                if (
                    payload.length != c.snapshot.manifestBytes
                        || keccak256(payload) != c.snapshot.manifestHash
                ) revert T.InventorySourceChanged();
                rows[i] = Items.bytesItem(
                    T.Kind.ORIGINAL_PAYLOAD,
                    keccak256("SCOPED_SNAPSHOT_MANIFEST"),
                    d.targets[5],
                    original,
                    0,
                    payload
                );
                rows[i].schemaId = Definitions.SCHEMA_ID;
                rows[i].canonicalizationId = Definitions.CANON_ID;
            } else if (at == 2) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("SCOPED_NATIVE_SOURCE_FACTS"),
                    d.targets[5],
                    original,
                    0,
                    abi.encode(f.snapshotSource)
                );
            } else if (at == 3) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_SCOPED_CONTENT_ROOT"),
                    d.targets[4],
                    c.rootRecordHash,
                    0,
                    abi.encode(f.contentRoot)
                );
            } else if (at == 4) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("STATIC_SELECTION_PLAN"),
                    sd.targets[6],
                    c.selectionId,
                    0,
                    abi.encode(f.snapshotSource.selection)
                );
            } else if (at == 5) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("STATIC_CONTENT_PLAN"),
                    sd.targets[7],
                    c.checkpointHash,
                    0,
                    abi.encode(f.snapshotSource.content)
                );
            } else if (at == 6) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("STATIC_OUTPUT_MANIFEST"),
                    sd.targets[8],
                    c.outputManifestRecord,
                    0,
                    abi.encode(f.snapshotSource.outputs)
                );
            } else if (at == 7) {
                rows[i].kind = T.Kind.ONCHAIN_OBJECT;
                rows[i].role = keccak256("COMPLETE_STATIC_OUTPUT_HASH_ROWS");
                rows[i].source = sd.targets[8];
                rows[i].sourceRecord = c.outputManifestRecord;
                rows[i].algorithm = 1;
                rows[i].canonicalizationId = keccak256("STREAM_ABI_STATIC_OUTPUT_MANIFEST_V1");
                rows[i].digest = abi.encodePacked(f.snapshotSource.outputs.manifestHash);
                rows[i].byteSize = f.snapshotSource.outputs.byteLength;
                rows[i].schemaId = keccak256("STREAM_STATIC_OUTPUT_MANIFEST_V1");
                rows[i].objectHash = f.snapshotSource.outputs.artifactHash;
                rows[i].originalCoverageHash = f.snapshotSource.outputs.coverageHash;
            } else if (at == 8) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_COORDINATOR_POLICIES"),
                    sd.targets[10],
                    original,
                    0,
                    abi.encode(f.snapshotSource.entropy)
                );
            } else if (at < 21) {
                rows[i] = Items.runtime(
                    keccak256("SCOPED_INVENTORY_DEPENDENCY_RUNTIME"),
                    d.targets[at - 9],
                    original,
                    at - 9
                );
            } else if (at < 32) {
                IO.pin(sd.targets[at - 21], sd.codeHashes[at - 21]);
                rows[i] = Items.runtime(
                    keccak256("SCOPED_SNAPSHOT_DEPENDENCY_RUNTIME"),
                    sd.targets[at - 21],
                    original,
                    at - 21
                );
            } else if (at < 37) {
                rows[i] = Items.runtime(
                    keccak256("ORIGINAL_ARTIST_DEPENDENCY_RUNTIME"),
                    d.artistTargets[at - 32],
                    original,
                    at - 32
                );
            } else if (at == 37) {
                rows[i] = Items.runtime(
                    keccak256("ORIGINAL_ARTIST_CONTENT_OWNER_RUNTIME"),
                    d.artistContentOwner,
                    original,
                    0
                );
            } else {
                uint256 index = (at - 38) / 2;
                address coordinator = f.snapshotSource.entropy.policies[index].coordinator;
                if ((at - 38) % 2 == 0) {
                    rows[i] = Items.runtime(
                        keccak256("ORIGINAL_COORDINATOR_RUNTIME"), coordinator, original, index
                    );
                } else {
                    rows[i] = Items.bytesItem(
                        T.Kind.NATIVE_BYTES,
                        keccak256("ORIGINAL_COORDINATOR_POLICY"),
                        coordinator,
                        original,
                        index,
                        abi.encode(f.snapshotSource.entropy.policies[index])
                    );
                }
            }
        }
    }
}
