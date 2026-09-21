// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    StreamScopedPreservationPolicyRenderCriticalStateV1 as State
} from "./StreamScopedPreservationPolicyRenderCriticalStateV1.sol";

import {
    StreamScopedPreservationPolicyRenderCriticalStageGuardV1 as StageGuard
} from "./StreamScopedPreservationPolicyRenderCriticalStageGuardV1.sol";

/// @notice Typed stages using the actual host storage reference.
library StreamScopedPreservationPolicyRenderCriticalDescriptionStagesV1 {
    // Retain the original error ABI after moving the fixed currentness guard.
    error InventoryIncomplete();

    function appendWork(State.State storage state, bytes calldata input) public {
        (bytes32 id, StreamWorkRecordTypes.Description memory witness, address originalActor) =
            abi.decode(input[4:], (bytes32, StreamWorkRecordTypes.Description, address));
        _stage(state, id, 2);
        Scoped.Context memory c = state.contexts[id];
        T.Item[] memory refs = References.work(
            state.dependencies.targets[1],
            c.descriptions.workDescriptionRecordHash,
            c.descriptions.workPayloadHash,
            witness
        );
        Documents.authenticateCatalogs(state.dependencies, refs);
        T.Item[] memory originals = Originals.items(
            state.dependencies,
            State.originalRecordContext(c),
            c.descriptions.workDescriptionRecordHash,
            c.descriptions.workPayloadHash
        );
        bytes memory raw = IO.read(
            state.dependencies.targets[7],
            abi.encodeCall(
                IStreamWorkRecordSelection.workSelectionAt,
                (c.scope.collectionId, c.subject, c.descriptions.workRevision)
            ),
            4096,
            state.dependencies.readGas
        );
        IStreamWorkRecordSelection.Selection memory selected =
            abi.decode(raw, (IStreamWorkRecordSelection.Selection));
        IO.canonical(state.dependencies.targets[7], raw, abi.encode(selected));
        if (
            selected.recordHash != c.descriptions.workDescriptionRecordHash
                || selected.selectionHash != c.descriptions.workSelectionHash
        ) revert T.InventorySourceChanged();
        if (selected.artistPublication.attestationRecordHash != 0) {
            originals = _with(
                originals,
                ArtistBundles.item(
                    state.dependencies,
                    selected.artistPublication,
                    selected.recordHash,
                    originalActor
                )
            );
        } else if (originalActor != address(0)) {
            revert T.InvalidInventoryItem();
        }
        _append(state, id, _join(originals, refs), c.descriptions.workSelectionHash);
        state.plans[id].progress.completedStages = 3;
    }

    function appendRights(State.State storage state, bytes calldata input) public {
        (bytes32 id, StreamRightsRecordTypes.Statement memory witness) =
            abi.decode(input[4:], (bytes32, StreamRightsRecordTypes.Statement));
        _stage(state, id, 3);
        Scoped.Context memory c = state.contexts[id];
        T.Item[] memory refs = References.rights(
            state.dependencies.targets[1],
            c.descriptions.rightsStatementRecordHash,
            c.descriptions.rightsPayloadHash,
            witness
        );
        _append(
            state,
            id,
            _join(
                Originals.items(
                    state.dependencies,
                    State.originalRecordContext(c),
                    c.descriptions.rightsStatementRecordHash,
                    c.descriptions.rightsPayloadHash
                ),
                refs
            ),
            c.descriptions.rightsSelectionHash
        );
        state.plans[id].progress.completedStages = 4;
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
}
