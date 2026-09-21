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
import {
    StreamScopedPolicyRenderCriticalStageGuardV2 as Guard
} from "./StreamScopedPolicyRenderCriticalStageGuardV2.sol";

/// @notice Typed stages using the actual host storage reference.
library StreamScopedPolicyRenderCriticalRecordStagesV2 {
    function appendIntent(State.State storage state, bytes calldata input) public {
        (bytes32 id, StreamConservationRecordTypes.Intent memory witness, address originalActor) =
            abi.decode(input[4:], (bytes32, StreamConservationRecordTypes.Intent, address));
        _stage(state, id, 4);
        Scoped.Context memory c = state.contexts[id];
        if (c.conservation.record.kind != IStreamConservationRecordSelection.RecordKind.INTENT) {
            revert T.InvalidInventoryItem();
        }
        _parent(
            state,
            id,
            References.intent(
                state.dependencies.targets[1],
                c.conservation.record.recordHash,
                c.conservation.record.payloadHash,
                witness
            ),
            originalActor
        );
    }

    function appendIntentWaiver(State.State storage state, bytes calldata input) public {
        (
            bytes32 id,
            StreamConservationRecordTypes.IntentWaiver memory witness,
            address originalActor
        ) = abi.decode(input[4:], (bytes32, StreamConservationRecordTypes.IntentWaiver, address));
        _stage(state, id, 4);
        Scoped.Context memory c = state.contexts[id];
        if (
            c.conservation.record.kind
                != IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER
        ) revert T.InvalidInventoryItem();
        _parent(
            state,
            id,
            References.waiver(
                state.dependencies.targets[1],
                c.conservation.record.recordHash,
                c.conservation.record.payloadHash,
                witness
            ),
            originalActor
        );
    }

    function _parent(State.State storage state, bytes32 id, T.Item[] memory refs, address actor)
        private
    {
        Scoped.Context memory c = state.contexts[id];
        T.Item[] memory originals = Originals.items(
            state.dependencies,
            State.originalRecordContext(c),
            c.conservation.record.recordHash,
            c.conservation.record.payloadHash
        );
        originals = _with(
            originals,
            ArtistBundles.item(
                state.dependencies,
                c.conservation.record.publication,
                c.conservation.record.recordHash,
                actor
            )
        );
        _append(state, id, _join(originals, refs), c.conservation.selectionHash);
        state.plans[id].progress.completedStages = 5;
    }

    function _stage(State.State storage state, bytes32 id, uint16 stage) private view {
        Guard.stage(state, id, stage);
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
}
