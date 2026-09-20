// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as R
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    IStreamScopedPreservationPolicyReferencePublicationV1 as Reference
} from "../../interfaces/stream/preservation/IStreamScopedPreservationPolicyReferencePublicationV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicyReferenceSourceReadsV1 as ScopedOriginal
} from "./StreamScopedPreservationPolicyReferenceSourceReadsV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamRenderCriticalSourceReads as Original } from "./StreamRenderCriticalSourceReads.sol";
import {
    StreamFinalityScopedPreservationPolicyReferenceReadsV1 as References
} from "../finality/StreamFinalityScopedPreservationPolicyReferenceReadsV1.sol";
import {
    StreamFinalityDescriptionReads as Descriptions
} from "../finality/StreamFinalityDescriptionReads.sol";
import {
    StreamFinalityConservationReads as Conservation
} from "../finality/StreamFinalityConservationReads.sol";
import {
    StreamFinalityConservationEvidence
} from "../../interfaces/stream/finality/StreamFinalityConservationTypes.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamMultiOriginInventoryCalls as OriginCalls
} from "./StreamMultiOriginInventoryCalls.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalSourceReadsV1 as Previous
} from "./StreamScopedPreservationPolicyRenderCriticalSourceReadsV1.sol";

/// @notice Original source selection plus bounded authenticated Artist lineage.
library StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalSourceReadsV1 {
    function current(
        S.Dependencies memory d,
        O.Dependencies memory od,
        StreamFinalityScope memory scope
    )
        public
        view
        returns (
            Scoped.Context memory c,
            O.Origin memory currentOrigin,
            O.Origin memory presentedOrigin,
            bytes32 lineageHash
        )
    {
        if (
            scope.scopeType != StreamFinalityScopeType.TOKEN
                && scope.scopeType != StreamFinalityScopeType.RELEASE
                && scope.scopeType != StreamFinalityScopeType.SEASON
        ) revert T.InventorySourceChanged();
        // This original method checks the immutable named pins and common Core/archive getters;
        // it neither reads nor accepts a COLLECTION snapshot/reference record.
        Original.bindings(d);
        Previous.snapshotBindings(d);
        c.scope = scope;
        c.subject = StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
        bytes memory raw = IO.fixedRead(
            d.targets[6], abi.encodeCall(Reference.currentReference, (scope)), 672, d.readGas
        );
        c.referenceRender = abi.decode(raw, (R.Receipt));
        IO.canonical(d.targets[6], raw, abi.encode(c.referenceRender));
        References.requireCurrent(
            Previous.referenceDependencies(d),
            scope,
            c.referenceRender.observation.recordHash,
            c.referenceRender.observation.revision
        );
        // The original current producer has just checked the complete snapshot, authoritative
        // membership, selected source, scoped Artist root, environment and observations.
        // Read the same retained source and independently bind its entire original hash.
        R.Dependencies memory rd = Previous.referenceBindings(d);
        raw = IO.read(
            d.targets[6],
            abi.encodeCall(Reference.referenceSource, (c.referenceRender.observation.recordHash)),
            524288,
            d.referenceGas
        );
        R.SourceFacts memory f = abi.decode(raw, (R.SourceFacts));
        IO.canonical(d.targets[6], raw, abi.encode(f));
        if (
            keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V1"),
                            d.chainId,
                            d.targets[6],
                            rd.targets,
                            rd.codeHashes,
                            f
                        )
                    ) != c.referenceRender.observation.sourcesHash || f.scopeSubject != c.subject
                || c.referenceRender.scopeSubject != c.subject
                || keccak256(abi.encode(f.snapshotSource.scope)) != keccak256(abi.encode(scope))
                || f.snapshot.scopeSubject != c.subject
                || f.snapshot.recordHash != c.referenceRender.observation.snapshotRecordHash
                || f.snapshot.revision != c.referenceRender.observation.snapshotRevision
        ) revert T.InventorySourceChanged();
        c.snapshot = f.snapshot;
        c.snapshotSource = f.snapshotSource;
        c.outputManifestRecord = _snapshotOutput(d, c);
        c.descriptions = Descriptions.requireCurrent(Previous.descriptionDependencies(d), scope);
        StreamFinalityConservationEvidence memory conservation =
            Conservation.requireCurrent(Previous.conservationDependencies(d), scope);
        c.conservation = conservation.selected;
        c.interviewEvidenceHash = conservation.interviewEvidenceHash;
        (currentOrigin, presentedOrigin, lineageHash) = OriginCalls.lineage(
            d, od, scope.collectionId, f.snapshotSource.artist, c.conservation.association
        );
        c.artistId = f.snapshotSource.artist.artistId;
        c.nativeHash = keccak256(abi.encode(f.snapshotSource));
        c.rootRecordHash = f.contentRootRecordHash;
        c.tokenInventoryHash = f.snapshotSource.membership.membershipHash;
        c.checkpointHash = f.snapshotSource.outputs.checkpointHash;
        c.selectionId = f.snapshotSource.content.selectionId;
        c.selectionHash = f.snapshotSource.content.selectionHash;
        uint256 count = f.snapshotSource.membership.tokenCount;
        if (
            count == 0 || count > type(uint64).max || c.rootRecordHash == 0
                || c.subject != c.descriptions.scopeSubject
                || c.subject != conservation.scopeSubject
                || c.subject != f.snapshotSource.membership.scopeSubject
                || c.artistId != c.conservation.association.artistId
                || f.snapshotSource.content.tokenCount != count
                || f.snapshotSource.selection.tokenCount != count
                || f.snapshotSource.outputs.tokenCount != count
        ) revert T.InventorySourceChanged();
        c.tokenCount = uint64(count);
    }

    function _snapshotOutput(S.Dependencies memory d, Scoped.Context memory c)
        private
        view
        returns (bytes32)
    {
        bytes memory raw = IO.read(
            d.targets[5],
            abi.encodeCall(
                IStreamScopedPreservationPolicySnapshotPublicationV1.snapshotRecord,
                (c.snapshot.recordHash)
            ),
            16384,
            d.sourceGas
        );
        (
            StreamScopedPreservationPolicySnapshotTypesV1.Publication memory p,
            StreamScopedPreservationPolicySnapshotTypesV1.Receipt memory receipt
        ) = abi.decode(
            raw,
            (
                StreamScopedPreservationPolicySnapshotTypesV1.Publication,
                StreamScopedPreservationPolicySnapshotTypesV1.Receipt
            )
        );
        IO.canonical(d.targets[5], raw, abi.encode(p, receipt));
        if (
            keccak256(abi.encode(receipt)) != keccak256(abi.encode(c.snapshot))
                || keccak256(abi.encode(p.scope)) != keccak256(abi.encode(c.scope))
                || p.outputManifestRecord == 0
        ) revert T.InventorySourceChanged();
        return p.outputManifestRecord;
    }
}
