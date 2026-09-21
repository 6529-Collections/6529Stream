// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as R
} from "../../interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as Snapshot
} from "../../interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as Snap
} from "../../interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPolicyRenderCriticalSourceReadsV2 as Sources
} from "./StreamScopedPolicyRenderCriticalSourceReadsV2.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import {
    StreamScopedPolicySnapshotDefinitionsV2 as Definitions
} from "../records/StreamScopedPolicySnapshotDefinitionsV2.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as OutputSchemas
} from "../finality/StreamScopedPolicyOutputSchemasV2.sol";

/// @notice Fixed complete native-item read worker for the scoped V2 inventory.
/// @dev Original row order, reads, pins and full returned items are unchanged.
library StreamScopedPolicyRenderCriticalNativeItemsV2 {
    function items(S.Dependencies memory d, Scoped.Context memory c, uint64 start, uint64 maximum)
        public
        view
        returns (T.Item[] memory rows, uint64 total)
    {
        if (maximum == 0 || maximum > 64) revert T.InvalidInventorySegment();
        Snapshot.Dependencies memory sd = Sources.snapshotBindings(d);
        R.SourceFacts memory f = Sources.sourceFacts(d, c);
        // Preserve the actual factory tuple and all four constructor targets, in addition
        // to the original inventory/snapshot/Artist roster and complete policy occurrences.
        Policies.Dependencies memory factory = _factory(d, f);
        uint256 count = 44 + f.snapshotSource.entropy.policies.length * 2;
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
                    keccak256("ORIGINAL_SCOPED_POLICY_SNAPSHOT_RECORD_V2"),
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
                    keccak256("SCOPED_POLICY_SNAPSHOT_MANIFEST_V2"),
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
                    keccak256("SCOPED_POLICY_NATIVE_SOURCE_FACTS_V2"),
                    d.targets[5],
                    original,
                    0,
                    abi.encode(f.snapshotSource)
                );
            } else if (at == 3) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_SCOPED_POLICY_CONTENT_ROOT_V2"),
                    d.targets[4],
                    c.rootRecordHash,
                    0,
                    abi.encode(f.contentRoot, f.contentRootBinding)
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
                    keccak256("SCOPED_POLICY_CONTENT_PLAN_V2"),
                    sd.targets[7],
                    c.checkpointHash,
                    0,
                    abi.encode(f.snapshotSource.content)
                );
            } else if (at == 6) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("SCOPED_POLICY_OUTPUT_MANIFEST_V2"),
                    sd.targets[8],
                    c.outputManifestRecord,
                    0,
                    abi.encode(f.snapshotSource.outputs)
                );
            } else if (at == 7) {
                rows[i].kind = T.Kind.ONCHAIN_OBJECT;
                rows[i].role = keccak256("COMPLETE_SCOPED_POLICY_OUTPUT_HASH_ROWS_V2");
                rows[i].source = sd.targets[8];
                rows[i].sourceRecord = c.outputManifestRecord;
                rows[i].algorithm = 1;
                rows[i].canonicalizationId = OutputSchemas.CANON;
                rows[i].digest = abi.encodePacked(f.snapshotSource.outputs.manifestHash);
                rows[i].byteSize = f.snapshotSource.outputs.byteLength;
                rows[i].schemaId = OutputSchemas.SCHEMA;
                rows[i].objectHash = f.snapshotSource.outputs.artifactHash;
                rows[i].originalCoverageHash = f.snapshotSource.outputs.coverageHash;
            } else if (at == 8) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("ORIGINAL_COMPLETE_COORDINATOR_POLICIES_V2"),
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
            } else if (at == 38) {
                rows[i] = Items.runtime(
                    keccak256("SCOPED_POLICY_SOURCE_FACTORY_RUNTIME_V2"),
                    f.snapshotSource.sourceFactory,
                    original,
                    0
                );
            } else if (at == 39) {
                rows[i] = Items.bytesItem(
                    T.Kind.NATIVE_BYTES,
                    keccak256("SCOPED_POLICY_SOURCE_FACTORY_DEPENDENCIES_V2"),
                    f.snapshotSource.sourceFactory,
                    original,
                    0,
                    abi.encode(factory)
                );
            } else if (at < 44) {
                rows[i] = Items.runtime(
                    keccak256("SCOPED_POLICY_FACTORY_DEPENDENCY_RUNTIME_V2"),
                    factory.targets[at - 40],
                    original,
                    at - 40
                );
            } else {
                uint256 index = (at - 44) / 2;
                address coordinator = f.snapshotSource.entropy.policies[index].coordinator;
                IO.pin(coordinator, f.snapshotSource.entropy.policies[index].indexedCodeHash);
                if ((at - 44) % 2 == 0) {
                    rows[i] = Items.runtime(
                        keccak256("ORIGINAL_COORDINATOR_RUNTIME"), coordinator, original, index
                    );
                } else {
                    rows[i] = Items.bytesItem(
                        T.Kind.NATIVE_BYTES,
                        keccak256("ORIGINAL_COORDINATOR_POLICY_V2"),
                        coordinator,
                        original,
                        index,
                        abi.encode(f.snapshotSource.entropy.policies[index])
                    );
                }
            }
        }
    }

    function _factory(S.Dependencies memory d, R.SourceFacts memory f)
        private
        view
        returns (Policies.Dependencies memory saved)
    {
        address factory = f.snapshotSource.sourceFactory;
        IO.pin(factory, f.snapshotSource.sourceFactoryCodeHash);
        bytes memory raw =
            IO.fixedRead(factory, abi.encodeCall(Factory.dependencies, ()), 352, d.readGas);
        saved = abi.decode(raw, (Policies.Dependencies));
        IO.canonical(factory, raw, abi.encode(saved));
        if (keccak256(raw) != f.snapshotSource.factoryDependenciesHash) {
            revert T.InventorySourceChanged();
        }
        Policies.validateDependencies(saved);
    }
}
