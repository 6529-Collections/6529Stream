// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";

import {
    StreamMultiOriginScopedPreservationPolicyRootAuthorizationV1 as RootAuthorization
} from "./StreamMultiOriginScopedPreservationPolicyRootAuthorizationV1.sol";

import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

import {
    IStreamScopedContentRootPublication as Root
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";

import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1.sol";

import {
    StreamScopedPreservationPolicyReferenceInventoryReadsV1 as Reference
} from "./StreamScopedPreservationPolicyReferenceInventoryReadsV1.sol";

/// @notice Fixed linked original reference and root-authorization stages.
library StreamCurrentAuthorityScopedPreservationPolicyInventoryStagesV1 {
    function appendReference(State.State storage state_, bytes32 id, uint64 maximum) public {
        State.stage(state_, id, 1);
        Scoped.Context storage c = state_.contexts[id];
        Scoped.Plan storage p = state_.plans[id];
        Reference.Context memory context =
            Reference.Context(c.scope, c.subject, c.artistId, c.snapshot, c.referenceRender);
        (T.Item[] memory rows, uint64 total) = Reference.items(
            state_.dependencies, context, p.referenceCursor, maximum, Family.FAMILY_PROFILE
        );
        if (p.referenceCursor != 0 && p.referenceCount != total) revert T.InventorySourceChanged();
        p.referenceCount = total;
        State.append(
            state_,
            id,
            rows,
            keccak256(abi.encode(p.progress.sourceContextHash, p.referenceCursor, total))
        );
        p.referenceCursor += uint64(rows.length);
        if (p.referenceCursor == total) p.progress.completedStages = 2;
    }

    function appendRootAuthorization(
        State.State storage state_,
        bytes32 id,
        address actor,
        uint64 observedAt,
        Root.Aggregate calldata originalAggregate,
        bytes32 originalLegacyFamilyHash,
        O.ReceiptWitness calldata receipt
    ) public {
        State.stage(state_, id, 6);
        T.Item[] memory rows = new T.Item[](1);
        O.RecordOrigin memory original;
        (rows[0], original) = RootAuthorization.contentItem(
            state_.dependencies,
            state_.contexts[id],
            actor,
            observedAt,
            originalAggregate,
            originalLegacyFamilyHash,
            state_.plans[id].progress.sourceContextHash,
            receipt
        );
        Origins.remember(
            state_.origins,
            id,
            state_.plans[id].progress.sourceContextHash,
            rows[0],
            original,
            bytes32(0),
            actor,
            keccak256("ORIGINAL_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_AUTHORIZATION_V1")
        );
        State.append(state_, id, rows, state_.contexts[id].rootRecordHash);
        state_.plans[id].progress.completedStages = 7;
    }
}
