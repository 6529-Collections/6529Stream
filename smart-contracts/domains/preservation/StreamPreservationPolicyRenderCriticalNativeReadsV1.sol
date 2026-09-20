// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationPolicyRenderCriticalTypesV1 as C
} from "../../interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "./StreamPreservationPolicyRenderCriticalSourceReadsV1.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamPreservationPolicySnapshotPublicationV1 as P
} from "../../interfaces/stream/metadata/IStreamPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamPreservationPolicySnapshotDefinitionsV1 as D
} from "../records/StreamPreservationPolicySnapshotDefinitionsV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as Output
} from "../finality/StreamPreservationPolicyOutputSchemasV1.sol";

/// @notice Complete source/policy declarations and every constructor-pinned dependency runtime.
/// @dev Per-token full output, script/library, renderer and current-profile stages remain mandatory.
library StreamPreservationPolicyRenderCriticalNativeReadsV1 {
    function items(S.Dependencies memory d, C.Context memory c)
        public
        view
        returns (T.Item[] memory rows)
    {
        (Snapshot.Dependencies memory sd,) = Sources.bindings(d);
        bytes memory raw = IO.read(
            d.targets[5],
            abi.encodeCall(P.snapshotPayload, (c.snapshot.recordHash)),
            524352,
            d.sourceGas
        );
        bytes memory payload = abi.decode(raw, (bytes));
        IO.canonical(d.targets[5], raw, abi.encode(payload));
        if (
            payload.length != c.snapshot.manifestBytes
                || keccak256(payload) != c.snapshot.manifestHash
        ) revert T.InventorySourceChanged();
        uint256 policies = c.source.entropy.policies.length;
        if (!c.source.entropy.allFrozen || policies != c.source.entropy.policyCount) {
            revert T.InventorySourceChanged();
        }
        rows = new T.Item[](6 + 12 + 11 + 5 + 1 + policies * 2);
        uint256 next;
        rows[next++] = Items.bytesItem(
            T.Kind.ORIGINAL_PAYLOAD,
            keccak256("POLICY_SNAPSHOT_MANIFEST_V2"),
            d.targets[5],
            c.snapshot.recordHash,
            0,
            payload
        );
        rows[0].schemaId = D.SCHEMA_ID;
        rows[0].canonicalizationId = D.CANON_ID;
        rows[next++] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("POLICY_SNAPSHOT_SOURCE_V2"),
            d.targets[5],
            c.snapshot.recordHash,
            0,
            abi.encode(c.source)
        );
        rows[next++] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"),
            d.targets[4],
            c.records.rootRecordHash,
            0,
            abi.encode(c.source.root, c.source.rootBinding)
        );
        rows[next++] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("COMPLETE_ORIGINAL_COORDINATOR_POLICIES_V2"),
            sd.targets[10],
            c.source.entropy.planId,
            0,
            abi.encode(c.source.entropy)
        );
        rows[next++] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("COMPLETE_POLICY_OUTPUT_MANIFEST_RECORD_V2"),
            sd.targets[8],
            c.source.root.publication.verifiedManifestRecordHash,
            0,
            abi.encode(c.source.outputs)
        );
        T.Item memory manifest;
        manifest.kind = T.Kind.ONCHAIN_OBJECT;
        manifest.role = keccak256("COMPLETE_POLICY_OUTPUT_MANIFEST_BYTES_V2");
        manifest.source = sd.targets[8];
        manifest.sourceRecord = c.source.root.publication.verifiedManifestRecordHash;
        manifest.algorithm = 1;
        manifest.canonicalizationId = Output.CANON;
        manifest.schemaId = Output.SCHEMA;
        manifest.digest = abi.encodePacked(c.source.outputs.manifestHash);
        manifest.byteSize = c.source.outputs.byteLength;
        manifest.objectHash = c.source.outputs.artifactHash;
        manifest.originalCoverageHash = c.source.outputs.coverageHash;
        rows[next++] = manifest;
        for (uint256 i; i < 12; ++i) {
            rows[next++] = Items.runtime(
                keccak256(abi.encode("POLICY_INVENTORY_DEPENDENCY_V2", i)),
                d.targets[i],
                c.snapshot.recordHash,
                i
            );
        }
        for (uint256 i; i < 11; ++i) {
            IO.pin(sd.targets[i], sd.codeHashes[i]);
            rows[next++] = Items.runtime(
                keccak256(abi.encode("POLICY_SNAPSHOT_DEPENDENCY_V2", i)),
                sd.targets[i],
                c.snapshot.recordHash,
                i
            );
        }
        for (uint256 i; i < 5; ++i) {
            rows[next++] = Items.runtime(
                keccak256(abi.encode("ORIGINAL_ARTIST_DEPENDENCY_V2", i)),
                d.artistTargets[i],
                c.records.rootRecordHash,
                i
            );
        }
        rows[next++] = Items.runtime(
            keccak256("ORIGINAL_ARTIST_CONTENT_OWNER"),
            d.artistContentOwner,
            c.records.rootRecordHash,
            0
        );
        for (uint256 i; i < policies; ++i) {
            IO.pin(
                c.source.entropy.policies[i].coordinator,
                c.source.entropy.policies[i].indexedCodeHash
            );
            rows[next++] = Items.runtime(
                keccak256("ORIGINAL_COORDINATOR_RUNTIME"),
                c.source.entropy.policies[i].coordinator,
                c.source.entropy.planId,
                i
            );
            rows[next++] = Items.bytesItem(
                T.Kind.NATIVE_BYTES,
                keccak256("ORIGINAL_COORDINATOR_POLICY_V2"),
                c.source.entropy.policies[i].coordinator,
                c.source.entropy.planId,
                i,
                abi.encode(c.source.entropy.policies[i])
            );
        }
        if (next != rows.length) revert T.InvalidInventoryItem();
    }
}
