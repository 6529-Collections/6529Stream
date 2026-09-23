// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as View
} from "../../interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as R
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    IStreamViewPreservationSnapshotPublicationV1 as Snap
} from "../../interfaces/stream/metadata/IStreamViewPreservationSnapshotPublicationV1.sol";
import {
    IStreamViewPreservationOutputManifestV1 as Manifest
} from "../../interfaces/stream/finality/IStreamViewPreservationOutputManifestV1.sol";
import {
    StreamViewPreservationManifestTypesV1 as M
} from "../../interfaces/stream/finality/StreamViewPreservationManifestTypesV1.sol";
import {
    StreamViewPreservationOutputSchemasV1 as OutputDefinitions
} from "../finality/StreamViewPreservationOutputSchemasV1.sol";
import {
    StreamViewPreservationSnapshotDefinitionsV1 as Definitions
} from "../records/StreamViewPreservationSnapshotDefinitionsV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamViewPreservationRenderCriticalStateV1 as State
} from "./StreamViewPreservationRenderCriticalStateV1.sol";
import {
    StreamViewPreservationRenderCriticalSourceReadsV1 as Sources
} from "./StreamViewPreservationRenderCriticalSourceReadsV1.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";

import {
    StreamViewPreservationRenderCriticalRetainedReadsV1 as Retained
} from "./StreamViewPreservationRenderCriticalRetainedReadsV1.sol";

/// @notice Ordered complete VIEW source, policy and every covered manifest-part inventory.
/// @dev Hash-row carriers remain separate from the mandatory later full per-token byte stage.
library StreamViewPreservationRenderCriticalNativeReadsV1 {
    function items(S.Dependencies memory d, View.Context memory c, uint64 start, uint64 maximum)
        public
        view
        returns (T.Item[] memory rows, uint64 total)
    {
        if (maximum == 0 || maximum > 64) revert T.InvalidInventorySegment();
        Snapshot.Dependencies memory sd = Sources.snapshotBindings(d);
        R.SourceFacts memory f = Retained.sourceFacts(d, c);
        uint256 policies = f.snapshotSource.entropy.policies.length;
        uint256 parts = f.snapshotSource.outputs.partCount;
        uint256 policiesEnd = 41 + policies * 2;
        uint256 count = policiesEnd + parts * 2;
        if (
            count > type(uint64).max || start >= count || !f.snapshotSource.entropy.allFrozen
                || f.snapshotSource.entropy.policyCount != policies || parts == 0
                || parts != (uint256(c.tokenCount) + 63) / 64
                || f.snapshotSource.outputs.nextPart != parts
                || f.snapshotSource.outputs.nextRow != c.tokenCount
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
                    keccak256("ORIGINAL_VIEW_PRESERVATION_SNAPSHOT_RECORD"),
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
                    keccak256("VIEW_PRESERVATION_SNAPSHOT_MANIFEST"),
                    d.targets[5],
                    original,
                    0,
                    payload
                );
                rows[i].schemaId = Definitions.SCHEMA_ID;
                // The schema remains original; correspondence commits the whole retained bytes.
            } else if (at == 2) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("VIEW_PRESERVATION_NATIVE_SOURCE_FACTS"),
                    d.targets[5],
                    original,
                    0,
                    abi.encode(f.snapshotSource)
                );
            } else if (at == 3) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_VIEW_CONTENT_ROOT"),
                    d.targets[4],
                    c.rootRecordHash,
                    0,
                    abi.encode(f.contentRoot)
                );
            } else if (at == 4) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_VIEW_CONTENT_BINDING"),
                    d.targets[4],
                    c.rootRecordHash,
                    0,
                    abi.encode(f.contentBinding)
                );
            } else if (at == 5) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_POLICY_VIEW_ADOPTION"),
                    d.targets[4],
                    c.adoptionRecord,
                    0,
                    abi.encode(f.snapshotSource.adoption.adoption)
                );
            } else if (at == 6) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_VIEW_POLICY_BINDING"),
                    d.targets[4],
                    c.adoptionRecord,
                    0,
                    abi.encode(f.snapshotSource.adoption.policy)
                );
            } else if (at == 7) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("VIEW_PRESERVATION_PRODUCER_BINDING"),
                    f.contentBinding.preservationRenderer,
                    c.adoptionRecord,
                    0,
                    abi.encode(f.snapshotSource.adoption.preservation)
                );
            } else if (at == 8) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("VIEW_PRESERVATION_GOVERNED_ADMISSION"),
                    f.snapshotSource.adoption.admission.registry,
                    c.adoptionRecord,
                    0,
                    abi.encode(f.snapshotSource.adoption.admission)
                );
            } else if (at == 9) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("VIEW_PRESERVATION_CONTENT_PLAN"),
                    sd.targets[6],
                    c.checkpointHash,
                    0,
                    abi.encode(f.snapshotSource.checkpoint)
                );
            } else if (at == 10) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("VIEW_PRESERVATION_OUTPUT_MANIFEST"),
                    sd.targets[7],
                    c.outputManifestRecord,
                    0,
                    abi.encode(f.snapshotSource.outputs)
                );
            } else if (at == 11) {
                M.Carrier memory carrier = f.snapshotSource.outputs.carrier;
                rows[i] = _object(
                    sd.targets[7],
                    c.outputManifestRecord,
                    0,
                    carrier.artifactHash,
                    carrier.coverageHash,
                    carrier.contentHash,
                    carrier.byteLength,
                    false
                );
            } else if (at == 12) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_VIEW_COORDINATOR_POLICIES"),
                    f.snapshotSource.adoption.policy.sourceSet,
                    original,
                    0,
                    abi.encode(f.snapshotSource.entropy)
                );
            } else if (at < 25) {
                rows[i] = Items.runtime(
                    keccak256("VIEW_INVENTORY_DEPENDENCY_RUNTIME"),
                    d.targets[at - 13],
                    original,
                    at - 13
                );
            } else if (at < 35) {
                IO.pin(sd.targets[at - 25], sd.codeHashes[at - 25]);
                rows[i] = Items.runtime(
                    keccak256("VIEW_SNAPSHOT_DEPENDENCY_RUNTIME"),
                    sd.targets[at - 25],
                    original,
                    at - 25
                );
            } else if (at < 40) {
                rows[i] = Items.runtime(
                    keccak256("ORIGINAL_ARTIST_DEPENDENCY_RUNTIME"),
                    d.artistTargets[at - 35],
                    original,
                    at - 35
                );
            } else if (at == 40) {
                rows[i] = Items.runtime(
                    keccak256("ORIGINAL_ARTIST_CONTENT_OWNER_RUNTIME"),
                    d.artistContentOwner,
                    original,
                    0
                );
            } else if (at < policiesEnd) {
                uint256 index = (at - 41) / 2;
                address coordinator = f.snapshotSource.entropy.policies[index].coordinator;
                rows[i] = (at - 41) % 2 == 0
                    ? Items.runtime(
                        keccak256("ORIGINAL_COORDINATOR_RUNTIME"), coordinator, original, index
                    )
                    : Items.bytesItem(
                        T.Kind.NATIVE_BYTES,
                        keccak256("ORIGINAL_COORDINATOR_FULL_POLICY"),
                        coordinator,
                        original,
                        index,
                        abi.encode(f.snapshotSource.entropy.policies[index])
                    );
            } else {
                uint256 index = (at - policiesEnd) / 2;
                bytes memory raw = IO.fixedRead(
                    sd.targets[7],
                    abi.encodeCall(Manifest.manifestPart, (c.outputManifestRecord, index)),
                    288,
                    d.sourceGas
                );
                M.Descriptor memory part = abi.decode(raw, (M.Descriptor));
                IO.canonical(sd.targets[7], raw, abi.encode(part));
                uint256 remaining = uint256(c.tokenCount) - index * 64;
                uint256 expected = remaining > 64 ? 64 : remaining;
                if (
                    part.recordHash == 0 || part.artifactHash == 0 || part.coverageHash == 0
                        || part.contentHash == 0 || part.first != index * 64
                        || part.count != expected || part.byteLength != 672 + 992 * expected
                        || part.firstToken == 0 || part.lastToken < part.firstToken
                ) revert T.InventorySourceChanged();
                rows[i] = (at - policiesEnd) % 2 == 0
                    ? Items.bytesItem(
                        T.Kind.NATIVE_BYTES,
                        keccak256("VIEW_PRESERVATION_COMPLETE_PART_DESCRIPTOR"),
                        sd.targets[7],
                        c.outputManifestRecord,
                        index,
                        raw
                    )
                    : _object(
                        sd.targets[7],
                        part.recordHash,
                        index,
                        part.artifactHash,
                        part.coverageHash,
                        part.contentHash,
                        part.byteLength,
                        true
                    );
            }
        }
    }

    function _object(
        address source,
        bytes32 record,
        uint256 index,
        bytes32 artifact,
        bytes32 coverage,
        bytes32 hash,
        uint64 size,
        bool part
    ) private pure returns (T.Item memory row) {
        row.kind = T.Kind.ONCHAIN_OBJECT;
        row.role =
            part ? keccak256("COMPLETE_VIEW_OUTPUT_PART") : keccak256("COMPLETE_VIEW_OUTPUT_INDEX");
        row.source = source;
        row.sourceRecord = record;
        row.sourceIndex = index;
        row.algorithm = 1;
        row.canonicalizationId = part ? OutputDefinitions.PART_CANON : OutputDefinitions.INDEX_CANON;
        row.schemaId = part ? OutputDefinitions.PART : OutputDefinitions.INDEX;
        row.digest = abi.encodePacked(hash);
        row.byteSize = size;
        row.objectHash = artifact;
        row.originalCoverageHash = coverage;
    }
}
