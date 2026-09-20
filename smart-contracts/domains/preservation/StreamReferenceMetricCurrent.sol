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
import { StreamReferenceMetricBytes as MetricBytes } from "./StreamReferenceMetricBytes.sol";
import { StreamReferenceModeInput as Input } from "./StreamReferenceModeInput.sol";
import { StreamReferenceModeProof as ModeProof } from "./StreamReferenceModeProof.sol";
import { StreamReferenceRenderSourceReads as Source } from "./StreamReferenceRenderSourceReads.sol";

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
        // Literal original currentness sequence, with only the immutable-byte transport
        // kept in this frame. The public full Preparation path remains the parity oracle.
        Preparation.CurrentDecoded memory decoded;
        decoded.publication = abi.decode(MetricBytes.read(publication), (R.Publication));
        bytes memory raw = MetricBytes.read(evidence);
        decoded.evidence = abi.decode(raw, (M.Evidence));
        if (keccak256(raw) != keccak256(abi.encode(decoded.evidence))) {
            revert M.InvalidModeEvidence();
        }
        R.SourceFacts memory source =
            Source.requireModeSourceInputs(d, Source.project(decoded.publication), true);
        decoded.context = Input.contextHash(d, decoded.publication);
        M.Facts memory mode = ModeProof.requireEvidenceProjected(
            d,
            bindings,
            Input.project(decoded.publication, decoded.context),
            source,
            decoded.evidence,
            true
        );
        bytes32 sourcesHash = ModeProof.sourceHash(d, bindings, source, mode);
        if (
            sourcesHash != receipt.sourcesHash
                || keccak256(abi.encode(mode)) != keccak256(abi.encode(facts))
                || MetricBytes.requireIntact(payload) != receipt.payloadHash
        ) revert M.InvalidModeEvidence();
        return Proof.compact(decoded.publication, decoded.evidence, decoded.context);
    }
}
