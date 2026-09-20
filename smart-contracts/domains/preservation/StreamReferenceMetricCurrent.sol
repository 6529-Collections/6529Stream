// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceModePreparation as Preparation
} from "./StreamReferenceModePreparation.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    StreamReferenceModeTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceMetricTypes as T
} from "../../interfaces/stream/preservation/StreamReferenceMetricTypes.sol";

import { StreamReferenceMetricProof as Proof } from "./StreamReferenceMetricProof.sol";

/// @notice Fixed fresh-currentness frame. Only its complete checked inputs derive the projection.
library StreamReferenceMetricCurrent {
    function requireInput(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        Bytes.Manifest storage publication,
        Bytes.Manifest storage evidence,
        M.Facts storage facts,
        Bytes.Manifest storage payload,
        R.Receipt storage receipt
    ) public view returns (Proof.CompactInput memory) {
        Preparation.CurrentDecoded memory decoded =
            Preparation.requireCurrentDecoded(
                d, bindings, publication, evidence, facts, payload, receipt
            );
        return Proof.compact(decoded.publication, decoded.evidence, decoded.context);
    }
}
