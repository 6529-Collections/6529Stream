// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalInventoryState as Original
} from "./StreamRenderCriticalInventoryState.sol";
import {
    StreamPreservationPolicyRenderCriticalTypesV1 as C
} from "../../interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "./StreamPreservationInventoryChains.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";
import {
    StreamPreservationPolicyRenderCriticalSourceReadsV1 as Sources
} from "./StreamPreservationPolicyRenderCriticalSourceReadsV1.sol";

/// @dev Original storage is a private common-record transport only. Its V1 receipts remain zero.
library StreamPreservationPolicyRenderCriticalStateV1 {
    struct Progress {
        uint8 phase;
        uint64 row;
        uint64 count;
    }

    struct State {
        Original.State records;
        mapping(bytes32 => C.Context) contexts;
        mapping(bytes32 => Progress) progress;
        mapping(bytes32 => mapping(bytes32 => bytes32)) documentFacts;
    }
    event InventorySegmentRecorded(
        bytes32 indexed planId, uint64 indexed index, T.Segment segment, T.Item[] items
    );

    function stage(State storage s, bytes32 id, uint16 expected) internal view {
        T.Plan storage p = s.records.plans[id];
        if (
            p.collectionId == 0 || p.completedStages != expected
                || p.renderCriticalEvidenceHash != 0
        ) {
            revert T.InventoryIncomplete();
        }
        Sources.bindings(s.records.dependencies);
    }

    function planId(State storage s, C.Context memory c) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_POLICY_RENDER_CRITICAL_PLAN_V1"),
                block.chainid,
                address(this),
                s.records.dependencyHash,
                c
            )
        );
    }

    function append(State storage s, bytes32 id, T.Item[] memory rows, bytes32 witness) internal {
        pinDocuments(s, id, rows);
        T.Plan storage p = s.records.plans[id];
        uint64 i = p.segmentCount;
        bytes32 key =
            keccak256(abi.encode(keccak256("6529STREAM_RENDER_CRITICAL_SEGMENT_V1"), id, i));
        T.Segment memory segment = Chains.segment(key, witness, rows);
        s.records.segments[id][i] = segment;
        p.segmentChainHash = Chains.append(p.segmentChainHash, i, segment);
        p.segmentCount = i + 1;
        p.itemCount += segment.itemCount;
        emit InventorySegmentRecorded(id, i, segment, rows);
    }

    function pinDocuments(State storage s, bytes32 id, T.Item[] memory rows) internal {
        for (uint256 i; i < rows.length; ++i) {
            if (rows[i].kind != T.Kind.REGISTERED_DOCUMENT) continue;
            T.Item memory actual =
                Documents.item(s.records.dependencies, rows[i].catalogId, rows[i].catalogHash);
            if (
                actual.byteSize != rows[i].byteSize
                    || keccak256(actual.digest) != keccak256(rows[i].digest)
            ) revert T.InventorySourceChanged();
            bytes32 previous = s.documentFacts[id][rows[i].catalogId];
            if (previous != 0 && previous != actual.provenanceHash) {
                revert T.InventorySourceChanged();
            }
            if (previous == 0) {
                s.documentFacts[id][rows[i].catalogId] = actual.provenanceHash;
                s.records
                .documents[id].push(Original.DocumentPin(rows[i].catalogId, actual.provenanceHash));
            }
        }
    }

    function requireDocuments(State storage s, bytes32 id, bool full) internal view {
        if (s.records.documents[id].length == 0) revert T.InventoryIncomplete();
        for (uint256 i; i < s.records.documents[id].length; ++i) {
            Original.DocumentPin storage p = s.records.documents[id][i];
            bytes32 actual = full
                ? Documents.item(s.records.dependencies, p.id, 0).provenanceHash
                : Documents.currentFactsHash(s.records.dependencies, p.id);
            if (actual != p.factsHash) revert T.InventorySourceChanged();
        }
    }
}
