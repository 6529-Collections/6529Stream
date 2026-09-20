// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import "../records/StreamSnapshotSourceReads.sol";
import "../finality/StreamFinalityDescriptionReads.sol";
import "../finality/StreamFinalityConservationReads.sol";
import "../finality/StreamFinalityReferenceReads.sol";
import "../finality/StreamFinalitySnapshotReads.sol";
import "../finality/StreamFinalityCoordinatorPolicyReads.sol";
import "../finality/StreamOnchainContentBytes.sol";
import "../../interfaces/stream/core/IStreamCoreMint.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import "../../interfaces/stream/finality/IStreamCollectionTokenInventory.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/metadata/IStreamConservationRecordSelection.sol";

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamMultiOriginInventoryCalls as OriginCalls
} from "./StreamMultiOriginInventoryCalls.sol";
import { StreamRenderCriticalSourceReads as Sources } from "./StreamRenderCriticalSourceReads.sol";

/// @notice Current native source selection with separately authenticated historical presentation.
library StreamMultiOriginSourceReads {
    function current(S.Dependencies memory d, O.Dependencies memory od, uint256 cid)
        public
        view
        returns (
            S.Context memory c,
            O.Origin memory currentOrigin,
            O.Origin memory presentedOrigin,
            bytes32 lineageHash
        )
    {
        Sources.bindings(d);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0);
        if (cid == 0) revert T.InventorySourceChanged();
        c.collectionId = cid;
        bytes memory raw = IO.fixedRead(
            d.targets[6],
            abi.encodeCall(IStreamReferenceRenderPublication.currentReference, (cid)),
            640,
            d.readGas
        );
        c.referenceRender = abi.decode(raw, (StreamReferenceRenderTypes.Receipt));
        IO.canonical(d.targets[6], raw, abi.encode(c.referenceRender));
        StreamFinalityReferenceReads.requireCurrent(
            _reference(d), scope, c.referenceRender.recordHash, c.referenceRender.revision
        );
        raw = IO.fixedRead(
            d.targets[5],
            abi.encodeCall(IStreamCollectionSnapshots.currentSnapshot, (cid)),
            672,
            d.readGas
        );
        c.snapshot = abi.decode(raw, (StreamSnapshotTypes.Receipt));
        IO.canonical(d.targets[5], raw, abi.encode(c.snapshot));
        StreamFinalitySnapshotReads.requireCurrent(
            _snapshot(d), scope, c.snapshot.recordHash, c.snapshot.revision
        );
        if (
            c.referenceRender.snapshotRecordHash != c.snapshot.recordHash
                || c.referenceRender.snapshotRevision != c.snapshot.revision
        ) {
            revert T.InventorySourceChanged();
        }
        c.descriptions = StreamFinalityDescriptionReads.requireCurrent(_descriptions(d), scope);
        StreamFinalityConservationEvidence memory conservation =
            StreamFinalityConservationReads.requireCurrent(_conservation(d), scope);
        c.conservation = conservation.selected;
        c.interviewEvidenceHash = conservation.interviewEvidenceHash;
        StreamSnapshotTypes.NativeFacts memory native =
            StreamSnapshotSourceReads.requireCurrent(Sources.snapshotDependencies(d), cid);
        (currentOrigin, presentedOrigin, lineageHash) =
            OriginCalls.lineage(d, od, cid, native.artist, c.conservation.association);
        c.subject = native.subject;
        c.artistId = native.artist.artistId;
        c.nativeHash = keccak256(abi.encode(native));
        c.rootRecordHash = native.contentRootRecordHash;
        c.tokenInventoryHash = native.checkpoint.inventoryHash;
        c.checkpointHash = native.leafManifest.checkpointHash;
        c.tokenCount = native.checkpoint.tokenCount;
        if (
            c.subject != c.descriptions.scopeSubject || c.subject != conservation.scopeSubject
                || c.artistId != c.conservation.association.artistId || c.tokenCount == 0
        ) revert T.InventorySourceChanged();
    }

    function _reference(S.Dependencies memory d)
        private
        pure
        returns (StreamFinalityReferenceReads.Dependencies memory)
    {
        return StreamFinalityReferenceReads.Dependencies(
            d.targets[0],
            d.targets[1],
            d.targets[6],
            d.targets[4],
            d.targets[5],
            d.codeHashes[0],
            d.codeHashes[1],
            d.codeHashes[6],
            d.codeHashes[4],
            d.codeHashes[5],
            d.chainId,
            d.readGas,
            d.referenceGas
        );
    }

    function _snapshot(S.Dependencies memory d)
        private
        pure
        returns (StreamFinalitySnapshotReads.Dependencies memory)
    {
        return StreamFinalitySnapshotReads.Dependencies(
            d.targets[0],
            d.targets[1],
            d.targets[5],
            d.codeHashes[0],
            d.codeHashes[1],
            d.codeHashes[5],
            d.chainId,
            d.readGas,
            d.snapshotGas
        );
    }

    function _descriptions(S.Dependencies memory d)
        private
        pure
        returns (StreamFinalityDescriptionReads.Dependencies memory p)
    {
        p.targets = [
            d.targets[0], d.targets[1], d.targets[2], d.targets[3], d.targets[7], d.targets[8]
        ];
        p.codeHashes = [
            d.codeHashes[0],
            d.codeHashes[1],
            d.codeHashes[2],
            d.codeHashes[3],
            d.codeHashes[7],
            d.codeHashes[8]
        ];
        p.chainId = d.chainId;
        p.readGas = d.readGas;
        p.selectionGas = d.selectionGas;
    }

    function _conservation(S.Dependencies memory d)
        private
        pure
        returns (StreamFinalityConservationReads.Dependencies memory p)
    {
        p.targets = [d.targets[0], d.targets[1], d.targets[2], d.targets[3], d.targets[9]];
        p.codeHashes =
            [d.codeHashes[0], d.codeHashes[1], d.codeHashes[2], d.codeHashes[3], d.codeHashes[9]];
        p.chainId = d.chainId;
        p.readGas = d.readGas;
        p.selectionGas = d.selectionGas;
    }
}
