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

import {
    StreamScopedPolicyRenderCriticalCurrentReadsV2 as Current
} from "./StreamScopedPolicyRenderCriticalCurrentReadsV2.sol";

/// @notice Full current scoped originals from fixed source producers, never a supplied descriptor.
/// @dev Dependencies use the original named roster; slots5/6 are the distinct scoped producers.
/// This worker does not by itself materialize or seal a complete inventory.
library StreamScopedPolicyRenderCriticalSourceReadsV2 {
    // Preserve errors previously inferred from the complete inlined read body.
    error InvalidMetadataScope();

    function snapshotBindings(S.Dependencies memory d)
        public
        view
        returns (StreamScopedPolicySnapshotTypesV2.Dependencies memory sd)
    {
        sd = ScopedOriginal.bindings(referenceBindings(d));
        if (sd.targets[9] != d.targets[10] || sd.codeHashes[9] != d.codeHashes[10]) {
            revert T.InventorySourceChanged();
        }
    }

    function sourceFacts(S.Dependencies memory d, Scoped.Context memory c)
        public
        view
        returns (R.SourceFacts memory f)
    {
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
                            keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_SOURCES_V2"),
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
        return Current.current(d, scope);
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
