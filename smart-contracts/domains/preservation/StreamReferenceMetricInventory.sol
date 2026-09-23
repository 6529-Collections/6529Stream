// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceMetricTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceMetricTypes.sol";
import {
    IStreamReferenceMetricSupplement as Host
} from "../../interfaces/stream/preservation/IStreamReferenceMetricSupplement.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";
import {
    StreamReferenceMetricDefinitions as D
} from "../records/StreamReferenceMetricDefinitions.sol";
import {
    StreamReferenceModeDefinitions as ModeD
} from "../records/StreamReferenceModeDefinitions.sol";

/// @notice Full supplement bytes; package members remain exact original environment obligations.
/// @dev The parent current-input gate authenticates admission. This grants no new authority.
library StreamReferenceMetricInventory {
    function items(S.Dependencies memory d, bytes32 original)
        public
        view
        returns (T.Item[] memory rows)
    {
        bytes memory encoded = IO.read(
            d.targets[6], abi.encodeCall(Host.metricSupplement, (original)), 524800, d.referenceGas
        );
        (bytes memory canonical, M.Receipt memory receipt) = abi.decode(encoded, (bytes, M.Receipt));
        IO.canonical(d.targets[6], encoded, abi.encode(canonical, receipt));
        M.Supplement memory s = abi.decode(canonical, (M.Supplement));
        if (
            receipt.referenceRecordHash != original || receipt.supplementHash == 0
                || receipt.payloadHash != keccak256(canonical)
                || canonical.length != receipt.payloadBytes
                || keccak256(abi.encode(s)) != receipt.payloadHash
                || receipt.schemaHash != D.SCHEMA_HASH || receipt.profileHash != D.PROFILE_HASH
                || receipt.canonicalizationHash != ModeD.CANON_HASH
        ) {
            revert T.InventorySourceChanged();
        }
        rows = new T.Item[](14);
        rows[0] = Documents.item(d, D.SCHEMA_ID, D.SCHEMA_HASH);
        rows[1] = Documents.item(d, D.PROFILE_ID, D.PROFILE_HASH);
        rows[2] = _item(
            d,
            receipt.supplementHash,
            keccak256("METRIC_SUPPLEMENT_RECEIPT"),
            0,
            abi.encode(receipt)
        );
        rows[3] =
            _item(d, receipt.supplementHash, keccak256("METRIC_SUPPLEMENT_PAYLOAD"), 0, canonical);
        rows[3].schemaId = D.SCHEMA_ID;
        rows[3].canonicalizationId = ModeD.CANON_ID;
        rows[4] = _item(
            d,
            receipt.supplementHash,
            keccak256("METRIC_IMPLEMENTATION_INDEX"),
            0,
            s.implementationIndex
        );
        rows[5] = _item(d, receipt.supplementHash, keccak256("METRIC_PARAMETERS"), 0, s.parameters);
        for (uint256 i; i < 4; ++i) {
            rows[6 + i] = _item(
                d, receipt.supplementHash, keccak256("METRIC_SOURCE_FILE"), i, s.sources[i].content
            );
            rows[6 + i].provenanceHash = keccak256(bytes(s.sources[i].path));
        }
        rows[10] = _item(
            d,
            receipt.supplementHash,
            keccak256("METRIC_RUNTIME_DECLARATION"),
            0,
            abi.encode(s.runtime)
        );
        rows[11] = _item(
            d, receipt.supplementHash, keccak256("METRIC_REPLAY_INPUTS"), 0, s.replay.inputManifest
        );
        rows[12] = _item(
            d, receipt.supplementHash, keccak256("METRIC_REPLAY_TRANSCRIPT"), 0, s.replay.transcript
        );
        rows[13] = _item(
            d, receipt.supplementHash, keccak256("METRIC_REPLAY_RECEIPT"), 0, abi.encode(s.replay)
        );
    }

    function _item(
        S.Dependencies memory d,
        bytes32 source,
        bytes32 role,
        uint256 index,
        bytes memory raw
    ) private pure returns (T.Item memory) {
        return Items.bytesItem(T.Kind.NATIVE_BYTES, role, d.targets[6], source, index, raw);
    }
}
