// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyRenderCriticalTypesV1 as V
} from "../../interfaces/stream/preservation/StreamPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as Snap
} from "../../interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    StreamPreservationPolicyReferenceTypesV1 as Ref
} from "../../interfaces/stream/preservation/StreamPreservationPolicyReferenceTypesV1.sol";
import {
    IStreamPreservationPolicyReferencePublicationV1 as Reference
} from "../../interfaces/stream/preservation/IStreamPreservationPolicyReferencePublicationV1.sol";
import {
    IStreamPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../interfaces/stream/metadata/IStreamPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamFinalityPreservationPolicyReferenceReadsV1 as ReferenceReads
} from "../finality/StreamFinalityPreservationPolicyReferenceReadsV1.sol";
import {
    StreamFinalityPreservationPolicySnapshotReadsV1 as SnapshotReads
} from "../finality/StreamFinalityPreservationPolicySnapshotReadsV1.sol";
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

/// @notice Actual current preservation receipt/policy/output joins plus unchanged common record selection.
library StreamPreservationPolicyRenderCriticalSourceReadsV1 {
    function bindings(S.Dependencies memory d)
        public
        view
        returns (Snap.Dependencies memory sd, Ref.Dependencies memory rd)
    {
        // This original helper checks only pins/chain/caps and coverage reciprocity. It does
        // not read, decode or accept an original snapshot/reference receipt.
        Original.bindings(d);
        bytes memory raw =
            IO.fixedRead(d.targets[5], abi.encodeCall(Snapshot.dependencies, ()), 832, d.readGas);
        sd = abi.decode(raw, (Snap.Dependencies));
        IO.canonical(d.targets[5], raw, abi.encode(sd));
        raw = IO.fixedRead(d.targets[6], abi.encodeCall(Reference.dependencies, ()), 608, d.readGas);
        rd = abi.decode(raw, (Ref.Dependencies));
        IO.canonical(d.targets[6], raw, abi.encode(rd));
        if (sd.chainId != d.chainId || rd.chainId != d.chainId) revert T.InventorySourceChanged();
        for (uint256 i; i < 5; ++i) {
            if (
                sd.targets[i] != d.targets[i] || sd.codeHashes[i] != d.codeHashes[i]
                    || rd.targets[i] != d.targets[i] || rd.codeHashes[i] != d.codeHashes[i]
            ) revert T.InventorySourceChanged();
        }
        if (
            sd.targets[9] != d.targets[10] || sd.codeHashes[9] != d.codeHashes[10]
                || rd.targets[5] != d.targets[5] || rd.codeHashes[5] != d.codeHashes[5]
                || rd.targets[6] != d.targets[11] || rd.codeHashes[6] != d.codeHashes[11]
        ) revert T.InventorySourceChanged();
    }

    function current(S.Dependencies memory d, uint256 cid)
        public
        view
        returns (V.Context memory c)
    {
        (, Ref.Dependencies memory rd) = bindings(d);
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
                keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_SOURCES_V1"),
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
        Original.requireSameArtistAssociation(
            d.artistTargets[0],
            d.artistCodeHashes[0],
            c.source.artist,
            common.conservation.association
        );
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
        // The two original receipt slots are never populated or consulted by preservation readers.
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
