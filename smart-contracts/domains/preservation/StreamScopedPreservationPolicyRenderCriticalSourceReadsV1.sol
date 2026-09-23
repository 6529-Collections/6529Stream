// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicyRenderCriticalCurrentReadsV1 as CurrentReads
} from "./StreamScopedPreservationPolicyRenderCriticalCurrentReadsV1.sol";
import {
    StreamPreservationPolicyInventoryFamilyV2 as FamilyRead
} from "./StreamPreservationPolicyInventoryFamilyV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as Family
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
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

/// @notice Full current scoped originals from fixed source producers, never a supplied descriptor.
/// @dev Dependencies use the original named roster; slots5/6 are the distinct scoped producers.
/// This worker does not by itself materialize or seal a complete inventory.
library StreamScopedPreservationPolicyRenderCriticalSourceReadsV1 {
    // Retained original error ABI; the fixed current worker still raises this selector.
    error InvalidMetadataScope();

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
        return CurrentReads.read(d, scope);
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
