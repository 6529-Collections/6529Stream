// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    IStreamReferenceModePublication as Host
} from "../../interfaces/stream/preservation/IStreamReferenceModePublication.sol";
import {
    IStreamCollectionAttestations as Attestations
} from "../../interfaces/stream/metadata/IStreamCollectionAttestations.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";
import { StreamReferenceModeDefinitions as D } from "../records/StreamReferenceModeDefinitions.sol";

/// @notice Interpretation, second capture and signed-condition closure for the new mode profile.
/// @dev The parent current-context reader authenticates the producer before this inventory stage.
library StreamReferenceModeInventory {
    function evidence(S.Dependencies memory d, S.Context memory c)
        public
        view
        returns (M.Evidence memory e, M.Facts memory facts)
    {
        bytes memory raw = IO.read(
            d.targets[6],
            abi.encodeCall(Host.referenceModeEvidence, (c.referenceRender.recordHash)),
            1048576,
            d.referenceGas
        );
        (e, facts) = abi.decode(raw, (M.Evidence, M.Facts));
        IO.canonical(d.targets[6], raw, abi.encode(e, facts));
        if (
            facts.evidenceHash != keccak256(abi.encode(e)) || facts.mode != e.mode
                || facts.repeats.length != e.repeats.length
        ) {
            revert T.InventorySourceChanged();
        }
    }

    function items(
        S.Dependencies memory d,
        S.Context memory c,
        M.Evidence memory e,
        M.Facts memory facts
    ) public view returns (T.Item[] memory rows) {
        bool curated = e.mode == M.Mode.CURATED_EQUIVALENCE;
        if (!curated && e.mode != M.Mode.PERCEPTUAL_TOLERANCE) revert T.InventorySourceChanged();
        // Every added registered interpretation document is retained, not just its hash.
        rows = new T.Item[](curated ? 12 : 7);
        bytes32[5] memory ids =
            [D.SCHEMA_ID, D.PROFILE_ID, D.CONDITION_ID, D.PROPERTIES_ID, D.CANON_ID];
        bytes32[5] memory hashes =
            [D.SCHEMA_HASH, D.PROFILE_HASH, D.CONDITION_HASH, D.PROPERTIES_HASH, D.CANON_HASH];
        for (uint256 i; i < 5; ++i) {
            rows[i] = Documents.item(d, ids[i], hashes[i]);
        }
        rows[5] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("REFERENCE_MODE_EVIDENCE"),
            d.targets[6],
            c.referenceRender.recordHash,
            0,
            abi.encode(e, facts)
        );
        if (!curated) {
            rows[6] = Documents.item(d, e.perceptual.metric.metricId, facts.interpretationHash);
            return rows;
        }
        bytes memory raw =
            IO.fixedRead(d.targets[6], abi.encodeCall(Host.modeDependencies, ()), 128, d.readGas);
        M.Dependencies memory bindings = abi.decode(raw, (M.Dependencies));
        IO.canonical(d.targets[6], raw, abi.encode(bindings));
        if (
            bindings.conservation != d.targets[9]
                || bindings.conservationCodeHash != d.codeHashes[9]
                || c.conservation.selectionHash != facts.intentSelectionHash
                || c.conservation.record.recordHash != e.curated.intentRecordHash
        ) {
            revert T.InventorySourceChanged();
        }
        IO.pin(bindings.attestations, bindings.attestationsCodeHash);
        rows[6] = Items.runtime(
            keccak256("CURATED_CONDITION_ORIGINAL_HOST"),
            bindings.attestations,
            e.curated.conditionRecordHash,
            0
        );
        rows[7] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("REFERENCE_MODE_DEPENDENCIES"),
            d.targets[6],
            c.referenceRender.recordHash,
            0,
            raw
        );
        raw = IO.read(
            bindings.attestations,
            abi.encodeCall(Attestations.collectionRecord, (e.curated.conditionRecordHash)),
            16384,
            d.sourceGas
        );
        rows[8] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("CURATED_CONDITION_ORIGINAL_RECORD_RECEIPT"),
            bindings.attestations,
            e.curated.conditionRecordHash,
            0,
            raw
        );
        raw = IO.read(
            bindings.attestations,
            abi.encodeCall(Attestations.recordPayload, (e.curated.conditionRecordHash)),
            8320,
            d.sourceGas
        );
        (address pointer, bytes memory payload) = abi.decode(raw, (address, bytes));
        IO.canonical(bindings.attestations, raw, abi.encode(pointer, payload));
        if (
            pointer.code.length == 0
                || keccak256(payload) != keccak256(abi.encode(e.curated.condition))
        ) revert T.InventorySourceChanged();
        rows[9] = Items.bytesItem(
            T.Kind.ORIGINAL_PAYLOAD,
            keccak256("CURATED_CONDITION_ORIGINAL_PAYLOAD"),
            bindings.attestations,
            e.curated.conditionRecordHash,
            0,
            payload
        );
        rows[9].schemaId = D.CONDITION_ID;
        rows[9].canonicalizationId = D.CANON_ID;
        raw = IO.read(
            bindings.attestations,
            abi.encodeCall(Attestations.recordSignatureBundle, (e.curated.conditionRecordHash)),
            8320,
            d.sourceGas
        );
        (pointer, payload) = abi.decode(raw, (address, bytes));
        IO.canonical(bindings.attestations, raw, abi.encode(pointer, payload));
        if (pointer.code.length == 0) revert T.InventorySourceChanged();
        rows[10] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("CURATED_CONDITION_ORIGINAL_SIGNATURE"),
            bindings.attestations,
            e.curated.conditionRecordHash,
            0,
            payload
        );
        rows[11] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("COMPLETE_SIGNIFICANT_PROPERTIES"),
            d.targets[6],
            c.referenceRender.recordHash,
            0,
            abi.encode(e.curated.properties)
        );
        rows[11].schemaId = D.PROPERTIES_ID;
        rows[11].canonicalizationId = D.CANON_ID;
    }
}
