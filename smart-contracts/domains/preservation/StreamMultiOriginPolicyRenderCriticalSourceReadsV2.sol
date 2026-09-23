// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPolicyRenderCriticalTypesV2 as V
} from "../../interfaces/stream/preservation/StreamPolicyRenderCriticalTypesV2.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPolicySnapshotTypesV2 as Snap
} from "../../interfaces/stream/metadata/StreamPolicySnapshotTypesV2.sol";
import {
    StreamPolicyReferenceTypesV2 as Ref
} from "../../interfaces/stream/preservation/StreamPolicyReferenceTypesV2.sol";
import {
    IStreamPolicyReferencePublicationV2 as Reference
} from "../../interfaces/stream/preservation/IStreamPolicyReferencePublicationV2.sol";
import {
    IStreamPolicySnapshotPublicationV2 as Snapshot
} from "../../interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import {
    StreamFinalityPolicyReferenceReadsV2 as ReferenceReads
} from "../finality/StreamFinalityPolicyReferenceReadsV2.sol";
import {
    StreamFinalityPolicySnapshotReadsV2 as SnapshotReads
} from "../finality/StreamFinalityPolicySnapshotReadsV2.sol";
import {
    StreamFinalityDescriptionReads as Description
} from "../finality/StreamFinalityDescriptionReads.sol";
import {
    StreamFinalityConservationReads as Conservation
} from "../finality/StreamFinalityConservationReads.sol";
import { StreamRenderCriticalSourceReads as Original } from "./StreamRenderCriticalSourceReads.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityConservationEvidence
} from "../../interfaces/stream/finality/StreamFinalityConservationTypes.sol";

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamMultiOriginInventoryCalls as OriginCalls
} from "./StreamMultiOriginInventoryCalls.sol";
import {
    StreamPolicyRenderCriticalSourceReadsV2 as Previous
} from "./StreamPolicyRenderCriticalSourceReadsV2.sol";

/// @notice Original source selection plus bounded authenticated Artist lineage.
library StreamMultiOriginPolicyRenderCriticalSourceReadsV2 {
    function current(S.Dependencies memory d, O.Dependencies memory od, uint256 cid)
        public
        view
        returns (
            V.Context memory c,
            O.Origin memory currentOrigin,
            O.Origin memory presentedOrigin,
            bytes32 lineageHash
        )
    {
        (, Ref.Dependencies memory rd) = Previous.bindings(d);
        if (cid == 0) revert T.InventorySourceChanged();
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0);
        bytes memory raw = IO.fixedRead(
            d.targets[6], abi.encodeCall(Reference.currentReference, (scope)), 672, d.readGas
        );
        c.referenceRender = abi.decode(raw, (Ref.Receipt));
        IO.canonical(d.targets[6], raw, abi.encode(c.referenceRender));
        ReferenceReads.requireCurrent(
            _reference(d),
            scope,
            c.referenceRender.observation.recordHash,
            c.referenceRender.observation.revision
        );
        raw = IO.fixedRead(
            d.targets[5], abi.encodeCall(Snapshot.currentSnapshot, (scope)), 544, d.readGas
        );
        c.snapshot = abi.decode(raw, (Snap.Receipt));
        IO.canonical(d.targets[5], raw, abi.encode(c.snapshot));
        SnapshotReads.Evidence memory evidence = SnapshotReads.requireCurrent(
            _snapshot(d), scope, c.snapshot.recordHash, c.snapshot.revision
        );
        if (
            c.referenceRender.observation.snapshotRecordHash != c.snapshot.recordHash
                || c.referenceRender.observation.snapshotRevision != c.snapshot.revision
        ) revert T.InventorySourceChanged();
        raw = IO.read(
            d.targets[6],
            abi.encodeCall(Reference.referenceSource, (c.referenceRender.observation.recordHash)),
            524352,
            d.sourceGas
        );
        Ref.SourceFacts memory facts = abi.decode(raw, (Ref.SourceFacts));
        IO.canonical(d.targets[6], raw, abi.encode(facts));
        c.referenceSourceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_REFERENCE_SOURCES_V2"),
                d.chainId,
                d.targets[6],
                rd.targets,
                rd.codeHashes,
                facts
            )
        );
        if (
            c.referenceSourceHash != c.referenceRender.observation.sourcesHash
                || keccak256(abi.encode(facts.snapshot)) != keccak256(abi.encode(c.snapshot))
                || facts.contentRootRecordHash != evidence.contentRootRecord
        ) revert T.InventorySourceChanged();
        c.source = facts.snapshotSource;
        S.Context memory common;
        common.collectionId = cid;
        common.descriptions = Description.requireCurrent(_descriptions(d), scope);
        StreamFinalityConservationEvidence memory conservation =
            Conservation.requireCurrent(_conservation(d), scope);
        common.conservation = conservation.selected;
        common.interviewEvidenceHash = conservation.interviewEvidenceHash;
        (currentOrigin, presentedOrigin, lineageHash) =
            OriginCalls.lineage(d, od, cid, c.source.artist, common.conservation.association);
        common.subject = c.snapshot.scopeSubject;
        common.artistId = c.source.artist.artistId;
        common.nativeHash = keccak256(abi.encode(c.source));
        common.rootRecordHash = facts.contentRootRecordHash;
        common.tokenInventoryHash = c.source.content.inventoryHash;
        common.checkpointHash = c.source.outputs.checkpointHash;
        common.tokenCount = c.source.content.tokenCount;
        if (
            common.subject != facts.scopeSubject
                || common.subject != common.descriptions.scopeSubject
                || common.subject != conservation.scopeSubject
                || common.artistId != common.conservation.association.artistId
                || common.tokenCount == 0 || c.source.membership.tokenCount != common.tokenCount
        ) revert T.InventorySourceChanged();
        // The two original receipt slots are never populated or consulted by V2 readers.
        c.records = common;
    }

    function _reference(S.Dependencies memory d)
        private
        pure
        returns (ReferenceReads.Dependencies memory r)
    {
        r.targets = [d.targets[0], d.targets[1], d.targets[4], d.targets[5], d.targets[6]];
        r.codeHashes =
            [d.codeHashes[0], d.codeHashes[1], d.codeHashes[4], d.codeHashes[5], d.codeHashes[6]];
        r.chainId = d.chainId;
        r.readGas = d.readGas;
        r.sourceGas = d.referenceGas;
    }

    function _snapshot(S.Dependencies memory d)
        private
        pure
        returns (SnapshotReads.Dependencies memory)
    {
        return SnapshotReads.Dependencies(
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
        returns (Description.Dependencies memory p)
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
        returns (Conservation.Dependencies memory p)
    {
        p.targets = [d.targets[0], d.targets[1], d.targets[2], d.targets[3], d.targets[9]];
        p.codeHashes =
            [d.codeHashes[0], d.codeHashes[1], d.codeHashes[2], d.codeHashes[3], d.codeHashes[9]];
        p.chainId = d.chainId;
        p.readGas = d.readGas;
        p.selectionGas = d.selectionGas;
    }
}
