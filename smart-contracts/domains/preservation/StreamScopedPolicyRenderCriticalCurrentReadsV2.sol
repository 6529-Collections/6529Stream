// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPolicyRenderCriticalTypesV2 as Scoped
} from "../../interfaces/stream/preservation/StreamScopedPolicyRenderCriticalTypesV2.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPolicyReferenceTypesV2 as R
} from "../../interfaces/stream/preservation/StreamScopedPolicyReferenceTypesV2.sol";
import {
    IStreamScopedPolicyReferencePublicationV2 as Reference
} from "../../interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2
} from "../../interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    StreamScopedPolicyReferenceSourceReadsV2 as ScopedOriginal
} from "./StreamScopedPolicyReferenceSourceReadsV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2
} from "../../interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamRenderCriticalSourceReads as Original } from "./StreamRenderCriticalSourceReads.sol";
import {
    StreamFinalityScopedPolicyReferenceReadsV2 as References
} from "../finality/StreamFinalityScopedPolicyReferenceReadsV2.sol";
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

/// @notice Complete original current-source read in the inventory host's delegate context.
/// @dev Private dependency helpers retain the original read order without calling back into
/// the public facade. All original guards, source bytes and the full Context return remain.
library StreamScopedPolicyRenderCriticalCurrentReadsV2 {
    function current(S.Dependencies memory d, StreamFinalityScope memory scope)
        public
        view
        returns (Scoped.Context memory c)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.TOKEN
                && scope.scopeType != StreamFinalityScopeType.RELEASE
                && scope.scopeType != StreamFinalityScopeType.SEASON
        ) revert T.InventorySourceChanged();
        // This original method checks the immutable named pins and common Core/archive getters;
        // it neither reads nor accepts a COLLECTION snapshot/reference record.
        Original.bindings(d);
        snapshotBindings(d);
        c.scope = scope;
        c.subject = StreamMetadataSubjects.scopeSubject(d.chainId, d.targets[0], scope);
        bytes memory raw = IO.fixedRead(
            d.targets[6], abi.encodeCall(Reference.currentReference, (scope)), 672, d.readGas
        );
        c.referenceRender = abi.decode(raw, (R.Receipt));
        IO.canonical(d.targets[6], raw, abi.encode(c.referenceRender));
        References.requireCurrent(
            referenceDependencies(d),
            scope,
            c.referenceRender.observation.recordHash,
            c.referenceRender.observation.revision
        );
        // The original current producer has just checked the complete snapshot, authoritative
        // membership, selected source, scoped Artist root, environment and observations.
        // Read the same retained source and independently bind its entire original hash.
        R.Dependencies memory rd = referenceBindings(d);
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
                            keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_SOURCES_V2"),
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
        c.descriptions = Descriptions.requireCurrent(descriptionDependencies(d), scope);
        StreamFinalityConservationEvidence memory conservation =
            Conservation.requireCurrent(conservationDependencies(d), scope);
        c.conservation = conservation.selected;
        c.interviewEvidenceHash = conservation.interviewEvidenceHash;
        Original.requireSameArtistAssociation(
            d.artistTargets[0],
            d.artistCodeHashes[0],
            f.snapshotSource.artist,
            c.conservation.association
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
                IStreamScopedPolicySnapshotPublicationV2.snapshotRecord, (c.snapshot.recordHash)
            ),
            16384,
            d.sourceGas
        );
        (
            StreamScopedPolicySnapshotTypesV2.Publication memory p,
            StreamScopedPolicySnapshotTypesV2.Receipt memory receipt
        ) = abi.decode(
            raw,
            (
                StreamScopedPolicySnapshotTypesV2.Publication,
                StreamScopedPolicySnapshotTypesV2.Receipt
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

    function snapshotBindings(S.Dependencies memory d)
        private
        view
        returns (StreamScopedPolicySnapshotTypesV2.Dependencies memory sd)
    {
        sd = ScopedOriginal.bindings(referenceBindings(d));
        if (sd.targets[9] != d.targets[10] || sd.codeHashes[9] != d.codeHashes[10]) {
            revert T.InventorySourceChanged();
        }
    }

    function referenceBindings(S.Dependencies memory d)
        private
        view
        returns (R.Dependencies memory rd)
    {
        bytes memory raw = IO.fixedRead(
            d.targets[6], abi.encodeCall(Reference.dependencies, ()), 608, d.readGas
        );
        rd = abi.decode(raw, (R.Dependencies));
        IO.canonical(d.targets[6], raw, abi.encode(rd));
        uint256[7] memory roles = [uint256(0), 1, 2, 3, 4, 5, 11];
        if (rd.chainId != d.chainId) revert T.InventorySourceChanged();
        for (uint256 i; i < 7; ++i) {
            if (rd.targets[i] != d.targets[roles[i]] || rd.codeHashes[i] != d.codeHashes[roles[i]])
            {
                revert T.InventorySourceChanged();
            }
        }
    }

    function referenceDependencies(S.Dependencies memory d)
        private
        pure
        returns (References.Dependencies memory p)
    {
        p.targets = [d.targets[0], d.targets[1], d.targets[4], d.targets[5], d.targets[6]];
        p.codeHashes =
            [d.codeHashes[0], d.codeHashes[1], d.codeHashes[4], d.codeHashes[5], d.codeHashes[6]];
        p.chainId = d.chainId;
        p.readGas = d.readGas;
        p.sourceGas = d.referenceGas;
    }

    function descriptionDependencies(S.Dependencies memory d)
        private
        pure
        returns (Descriptions.Dependencies memory p)
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

    function conservationDependencies(S.Dependencies memory d)
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
