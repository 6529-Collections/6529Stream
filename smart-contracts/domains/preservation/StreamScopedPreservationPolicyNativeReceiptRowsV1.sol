// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV2 as DefinitionsV2
} from "../records/StreamScopedPreservationPolicySnapshotDefinitionsV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as Snap
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV1 as Definitions
} from "../records/StreamScopedPreservationPolicySnapshotDefinitionsV1.sol";

import {
    StreamFinalityScope
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Fixed original receipt and payload items after source validation.
library StreamScopedPreservationPolicyNativeReceiptRowsV1 {
    function record(
        address target,
        Snapshot.Receipt memory snapshot,
        StreamFinalityScope memory scope,
        uint256 sourceGas
    ) public view returns (T.Item memory row) {
        bytes32 original = snapshot.recordHash;
        bytes memory raw =
            IO.read(target, abi.encodeCall(Snap.snapshotRecord, (original)), 16384, sourceGas);
        (Snapshot.Publication memory p, Snapshot.Receipt memory saved) =
            abi.decode(raw, (Snapshot.Publication, Snapshot.Receipt));
        IO.canonical(target, raw, abi.encode(p, saved));
        if (
            keccak256(abi.encode(saved)) != keccak256(abi.encode(snapshot))
                || keccak256(abi.encode(p.scope)) != keccak256(abi.encode(scope))
        ) revert T.InventorySourceChanged();
        row = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_SCOPED_PRESERVATION_POLICY_SNAPSHOT_RECORD_V1"),
            target,
            original,
            0,
            raw
        );
    }

    function payload(
        address target,
        Snapshot.Receipt memory snapshot,
        uint256 sourceGas,
        bytes32 family
    ) public view returns (T.Item memory row) {
        bytes32 original = snapshot.recordHash;
        bytes memory raw =
            IO.read(target, abi.encodeCall(Snap.snapshotPayload, (original)), 524352, sourceGas);
        bytes memory payload = abi.decode(raw, (bytes));
        IO.canonical(target, raw, abi.encode(payload));
        if (payload.length != snapshot.manifestBytes || keccak256(payload) != snapshot.manifestHash)
        {
            revert T.InventorySourceChanged();
        }
        row = Items.bytesItem(
            T.Kind.ORIGINAL_PAYLOAD,
            keccak256("SCOPED_POLICY_SNAPSHOT_MANIFEST_V2"),
            target,
            original,
            0,
            payload
        );
        row.schemaId =
        (family == Family.FAMILY_PROFILE ? DefinitionsV2.SCHEMA_ID : Definitions.SCHEMA_ID);
        row.canonicalizationId =
        (family == Family.FAMILY_PROFILE ? DefinitionsV2.CANON_ID : Definitions.CANON_ID);
    }
}
