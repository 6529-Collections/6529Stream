// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// Frozen differential reference: ea4cf6b0a2cfa7bba529284a3cfe46bb19b6604b.
// All function bodies and local types are literal originals. Only the library name
// and relative import paths changed. Imported producer/read libraries remain live;
// this fixture isolates the two capacity extractions, not their shared dependencies.

import {
    StreamPreservationPolicyInventoryFamilyV2 as FamilyRead
} from "../../smart-contracts/domains/preservation/StreamPreservationPolicyInventoryFamilyV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPreservationPolicyRenderCriticalTypesV1 as Scoped
} from "../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as R
} from "../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    IStreamScopedPreservationPolicyReferencePublicationV1 as Reference
} from "../../smart-contracts/interfaces/stream/preservation/IStreamScopedPreservationPolicyReferencePublicationV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1
} from "../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicyReferenceSourceReadsV1 as ScopedOriginal
} from "../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferenceSourceReadsV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../../smart-contracts/domains/preservation/StreamPreservationInventoryIO.sol";
import {
    StreamRenderCriticalSourceReads as Original
} from "../../smart-contracts/domains/preservation/StreamRenderCriticalSourceReads.sol";
import {
    StreamFinalityScopedPreservationPolicyReferenceReadsV1 as References
} from "../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicyReferenceReadsV1.sol";
import {
    StreamFinalityDescriptionReads as Descriptions
} from "../../smart-contracts/domains/finality/StreamFinalityDescriptionReads.sol";
import {
    StreamFinalityConservationReads as Conservation
} from "../../smart-contracts/domains/finality/StreamFinalityConservationReads.sol";
import {
    StreamFinalityConservationEvidence
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityConservationTypes.sol";
import {
    StreamMetadataSubjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Full current scoped originals from fixed source producers, never a supplied descriptor.
/// @dev Dependencies use the original named roster; slots5/6 are the distinct scoped producers.
/// This worker does not by itself materialize or seal a complete inventory.
library FrozenScopedRenderCriticalSourcesEa4 {
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

    function snapshotBindings(S.Dependencies memory d)
        public
        view
        returns (StreamScopedPreservationPolicySnapshotTypesV1.Dependencies memory sd)
    {
        return snapshotBindings(d, Family.ORIGINAL_PROFILE);
    }

    function snapshotBindings(S.Dependencies memory d, bytes32 family)
        public
        view
        returns (StreamScopedPreservationPolicySnapshotTypesV1.Dependencies memory sd)
    {
        if (!FamilyRead.valid(family)) revert T.InventorySourceChanged();
        sd = ScopedOriginal.bindings(referenceBindings(d), family);
        if (sd.targets[9] != d.targets[10] || sd.codeHashes[9] != d.codeHashes[10]) {
            revert T.InventorySourceChanged();
        }
    }

    function sourceFacts(S.Dependencies memory d, Scoped.Context memory c)
        public
        view
        returns (R.SourceFacts memory f)
    {
        return sourceFacts(d, c, Family.ORIGINAL_PROFILE);
    }

    function sourceFacts(S.Dependencies memory d, Scoped.Context memory c, bytes32 family)
        public
        view
        returns (R.SourceFacts memory f)
    {
        if (
            !FamilyRead.valid(family)
                || (family == Family.FAMILY_PROFILE
                    && (c.snapshotSource.content.preservationProfile != family
                        || c.snapshotSource.outputs.preservationProfile != family))
        ) revert T.InventorySourceChanged();
        R.Dependencies memory rd = referenceBindings(d);
        bytes memory raw = IO.read(
            d.targets[6],
            abi.encodeCall(Reference.referenceSource, (c.referenceRender.observation.recordHash)),
            524288,
            d.referenceGas
        );
        f = abi.decode(raw, (R.SourceFacts));
        IO.canonical(d.targets[6], raw, abi.encode(f));
        if (
            keccak256(
                        abi.encode(
                            (family == Family.FAMILY_PROFILE
                                    ? keccak256(
                                        "6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V2"
                                    )
                                    : keccak256(
                                        "6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V1"
                                    )),
                            d.chainId,
                            d.targets[6],
                            rd.targets,
                            rd.codeHashes,
                            f
                        )
                    ) != c.referenceRender.observation.sourcesHash
                || keccak256(abi.encode(f.snapshotSource)) != c.nativeHash
                || keccak256(abi.encode(f.snapshotSource))
                    != keccak256(abi.encode(c.snapshotSource))
                || keccak256(abi.encode(f.snapshot)) != keccak256(abi.encode(c.snapshot))
                || f.contentRootRecordHash != c.rootRecordHash || f.scopeSubject != c.subject
        ) revert T.InventorySourceChanged();
    }

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

    function referenceBindings(S.Dependencies memory d)
        public
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
        internal
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
        internal
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
        internal
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
