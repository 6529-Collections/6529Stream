// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
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
import {
    StreamPreservationArtistBundleReads as ArtistBundles
} from "./StreamPreservationArtistBundleReads.sol";
import { StreamRenderCriticalSourceReads as Sources } from "./StreamRenderCriticalSourceReads.sol";
import { StreamReferenceInventoryReads as Reference } from "./StreamReferenceInventoryReads.sol";
import "../../interfaces/stream/preservation/IStreamRenderCriticalInventory.sol";
import "../../interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import "../../interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../../interfaces/stream/preservation/IStreamReferenceRenderPublication.sol";

import {
    StreamScopedPolicyRenderCriticalStateV2 as State
} from "./StreamScopedPolicyRenderCriticalStateV2.sol";

/// @notice Typed stages using the actual host storage reference.
library StreamScopedPolicyRenderCriticalInterviewStageV2 {
    function appendInterview(State.State storage state, bytes calldata input) public {
        (
            bytes32 id,
            StreamConservationRecordTypes.Interview memory witness,
            address originalActor
        ) = abi.decode(input[4:], (bytes32, StreamConservationRecordTypes.Interview, address));
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
            ArtistBundles.item(
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
        State.stage(state, id, stage);
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
}
