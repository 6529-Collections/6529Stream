// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamScopedPolicyReferenceInventoryReadsV2 as Reference
} from "./StreamScopedPolicyReferenceInventoryReadsV2.sol";

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";

import { StreamMultiOriginRootCalls as RootCalls } from "./StreamMultiOriginRootCalls.sol";

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";

import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2 as State
} from "./StreamCurrentAuthorityScopedPolicyRenderCriticalStateV2.sol";

/// @notice Fixed linked operations retain the original host storage and domains.
library StreamCurrentAuthorityScopedPolicyInventoryStagesV2 {
    function appendRootAuthorization(
        mapping(bytes32 => State.State) storage _states,
        bytes32 id,
        address actor,
        uint64 observedAt,
        Root.Aggregate calldata originalAggregate,
        bytes32 originalLegacyFamilyHash,
        O.ReceiptWitness calldata receipt
    ) public {
        State.stage(_states[id], id, 6);
        T.Item[] memory rows = new T.Item[](1);
        O.RecordOrigin memory original;
        (rows[0], original) = RootCalls.scopedPolicyContentItem(
            _states[id].dependencies,
            _states[id].origins.dependencies,
            _states[id].contexts[id],
            actor,
            observedAt,
            originalAggregate,
            originalLegacyFamilyHash,
            _states[id].plans[id].progress.sourceContextHash,
            receipt
        );
        Origins.remember(
            _states[id].origins,
            id,
            _states[id].plans[id].progress.sourceContextHash,
            rows[0],
            original,
            bytes32(0),
            actor,
            keccak256("ORIGINAL_SCOPED_POLICY_CONTENT_ROOT_AUTHORIZATION_V2")
        );
        State.append(_states[id], id, rows, _states[id].contexts[id].rootRecordHash);
        _states[id].plans[id].progress.completedStages = 7;
    }

    function appendReference(
        mapping(bytes32 => State.State) storage _states,
        bytes32 id,
        uint64 maximum
    ) public {
        State.stage(_states[id], id, 1);
        Scoped.Context storage c = _states[id].contexts[id];
        Scoped.Plan storage p = _states[id].plans[id];
        Reference.Context memory context =
            Reference.Context(c.scope, c.subject, c.artistId, c.snapshot, c.referenceRender);
        (T.Item[] memory rows, uint64 total) =
            Reference.items(_states[id].dependencies, context, p.referenceCursor, maximum);
        if (p.referenceCursor != 0 && p.referenceCount != total) revert T.InventorySourceChanged();
        p.referenceCount = total;
        State.append(
            _states[id],
            id,
            rows,
            keccak256(abi.encode(p.progress.sourceContextHash, p.referenceCursor, total))
        );
        p.referenceCursor += uint64(rows.length);
        if (p.referenceCursor == total) p.progress.completedStages = 2;
    }
}
