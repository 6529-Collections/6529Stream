// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamArtistRecordPublicationTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import { StreamMultiOriginInventoryState as Origins } from "./StreamMultiOriginInventoryState.sol";
import {
    StreamMultiOriginInventoryCalls as OriginCalls
} from "./StreamMultiOriginInventoryCalls.sol";

import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "./StreamPreservationInventoryChains.sol";
import {
    StreamPreservationTypedReferences as References
} from "./StreamPreservationTypedReferences.sol";
import {
    StreamPreservationDocumentReads as Documents
} from "./StreamPreservationDocumentReads.sol";
import {
    StreamPreservationOriginalReads as Originals
} from "./StreamPreservationOriginalReads.sol";
import { StreamRenderCriticalSourceReads as Sources } from "./StreamRenderCriticalSourceReads.sol";
import { StreamReferenceInventoryReads as Reference } from "./StreamReferenceInventoryReads.sol";
import "../../interfaces/stream/preservation/IStreamRenderCriticalInventory.sol";
import "../../interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import "../../interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../../interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";

import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStateV1.sol";

import {
    StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStageGuardV1 as StageGuard
} from "./StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalStageGuardV1.sol";

/// @notice Typed stages using the actual host storage reference.
library StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInterviewStageV1 {
    // Retain the original error ABI after moving the fixed currentness guard.
    error InventoryIncomplete();
    error InventorySourceChanged();

    function appendInterview(State.State storage state, bytes calldata input) public {
        (
            bytes32 id,
            StreamConservationRecordTypes.Interview memory witness,
            address originalActor,
            O.ReceiptWitness memory receipt
        ) = abi.decode(
            input[4:], (bytes32, StreamConservationRecordTypes.Interview, address, O.ReceiptWitness)
        );
        _stage(state, id, 5);
        Scoped.Context memory c = state.contexts[id];
        if (c.conservation.interviewStatus != StreamConservationRecordTypes.InterviewStatus.PRESENT)
        {
            revert T.InvalidInventoryItem();
        }
        T.Item[] memory refs = References.interview(
            state.dependencies.targets[1],
            c.conservation.interview.recordHash,
            c.conservation.interview.payloadHash,
            witness
        );
        Documents.authenticateCatalogs(state.dependencies, refs);
        T.Item[] memory originals = Originals.items(
            state.dependencies,
            State.originalRecordContext(c),
            c.conservation.interview.recordHash,
            c.conservation.interview.payloadHash
        );
        originals = _with(
            originals,
            _publication(
                state,
                id,
                receipt,
                state.dependencies,
                c.conservation.interview.publication,
                c.conservation.interview.recordHash,
                originalActor
            )
        );
        _append(state, id, _join(originals, refs), c.interviewEvidenceHash);
        state.plans[id].progress.completedStages = 6;
    }

    function _stage(State.State storage state, bytes32 id, uint16 stage) private view {
        StageGuard.stage(state, id, stage);
    }

    function _append(
        State.State storage state,
        bytes32 id,
        T.Item[] memory rows,
        bytes32 witnessHash
    ) private {
        State.append(state, id, rows, witnessHash);
    }

    function _with(T.Item[] memory a, T.Item memory item)
        private
        pure
        returns (T.Item[] memory result)
    {
        result = new T.Item[](a.length + 1);
        for (uint256 i; i < a.length; ++i) {
            result[i] = a[i];
        }
        result[a.length] = item;
    }

    function _join(T.Item[] memory a, T.Item[] memory b)
        private
        pure
        returns (T.Item[] memory result)
    {
        result = new T.Item[](a.length + b.length);
        for (uint256 i; i < a.length; ++i) {
            result[i] = a[i];
        }
        for (uint256 i; i < b.length; ++i) {
            result[a.length + i] = b[i];
        }
    }

    function appendInterviewWaiver(State.State storage state, bytes32 id) public {
        _stage(state, id, 5);
        Scoped.Context memory c = state.contexts[id];
        if (
            c.conservation.interviewStatus != StreamConservationRecordTypes.InterviewStatus.WAIVED
                || c.conservation.interview.recordHash != 0
        ) revert T.InvalidInventoryItem();
        T.Item[] memory rows = new T.Item[](1);
        rows[0] = Items.absent(
            keccak256("INTERVIEW_ORIGINAL_EXPLICITLY_WAIVED"),
            state.dependencies.targets[1],
            c.conservation.record.recordHash,
            0
        );
        rows[0].provenanceHash = c.interviewEvidenceHash;
        _append(state, id, rows, c.interviewEvidenceHash);
        state.plans[id].progress.completedStages = 6;
    }

    function _publication(
        State.State storage state,
        bytes32 id,
        O.ReceiptWitness memory receipt,
        S.Dependencies memory d,
        P.Evidence memory expected,
        bytes32 record,
        address actor
    ) private returns (T.Item memory item) {
        O.RecordOrigin memory original;
        (item, original) = OriginCalls.publication(
            d,
            state.origins.dependencies,
            expected,
            record,
            actor,
            state.plans[id].progress.sourceContextHash,
            receipt
        );
        Origins.remember(
            state.origins,
            id,
            state.plans[id].progress.sourceContextHash,
            item,
            original,
            expected.attestationRecordHash,
            actor,
            keccak256("ORIGINAL_ARTIST_PUBLICATION_AUTHORIZATION")
        );
    }
}
