// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as Scoped
} from "../../interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamViewPreservationReferenceTypesV1 as R
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    IStreamViewPreservationReferencePublicationV1 as Reference
} from "../../interfaces/stream/preservation/IStreamViewPreservationReferencePublicationV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamViewPreservationReferenceSourceReadsV1 as ViewOriginal
} from "./StreamViewPreservationReferenceSourceReadsV1.sol";
import {
    IStreamViewPreservationSnapshotPublicationV1
} from "../../interfaces/stream/metadata/IStreamViewPreservationSnapshotPublicationV1.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamRenderCriticalSourceReads as Original } from "./StreamRenderCriticalSourceReads.sol";
import {
    StreamFinalityViewPreservationReferenceReadsV1 as References
} from "../finality/StreamFinalityViewPreservationReferenceReadsV1.sol";
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
    StreamViewPreservationRenderCriticalSourceReadsV1 as Sources
} from "./StreamViewPreservationRenderCriticalSourceReadsV1.sol";

/// @notice Exact authenticated retained reference projection; no currentness or authority claim.
library StreamViewPreservationRenderCriticalRetainedReadsV1 {
    function sourceFacts(S.Dependencies memory d, Scoped.Context memory c)
        public
        view
        returns (R.SourceFacts memory f)
    {
        R.Dependencies memory rd = Sources.referenceBindings(d);
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
                            keccak256("6529STREAM_VIEW_PRESERVATION_REFERENCE_SOURCES_V1"),
                            d.chainId,
                            d.targets[6],
                            rd.targets,
                            rd.codeHashes,
                            f
                        )
                    ) != c.referenceRender.observation.sourcesHash
                || keccak256(abi.encode(f.snapshotSource)) != c.nativeHash
                || keccak256(abi.encode(f.snapshot)) != keccak256(abi.encode(c.snapshot))
                || f.contentRootRecordHash != c.rootRecordHash || f.scopeSubject != c.subject
        ) revert T.InventorySourceChanged();
    }
}
