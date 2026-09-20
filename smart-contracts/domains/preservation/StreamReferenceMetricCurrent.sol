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
import {
    StreamReferenceMetricPublicationInput as EncodedInput
} from "./StreamReferenceMetricPublicationInput.sol";
import {
    StreamReferenceModeManifestAdoption as Integrity
} from "./StreamReferenceModeManifestAdoption.sol";

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
        bytes memory publicationBytes = MetricBytes.read(publication);
        EncodedInput.Decoded memory decoded = EncodedInput.read(publicationBytes);
        bytes memory raw = MetricBytes.read(evidence);
        M.Evidence memory modeEvidence = abi.decode(raw, (M.Evidence));
        if (keccak256(raw) != EncodedInput.evidenceHash(modeEvidence)) {
            revert M.InvalidModeEvidence();
        }
        R.SourceFacts memory source = Source.requireModeSourceInputs(d, decoded.source, true);
        bytes32 context = EncodedInput.contextHash(d, publicationBytes, decoded);
        M.Facts memory mode = ModeProof.requireEvidenceProjected(
            d, bindings, EncodedInput.evidenceInput(decoded, context), source, modeEvidence, true
        );
        bytes32 sourcesHash = ModeProof.sourceHash(d, bindings, source, mode);
        if (
            sourcesHash != receipt.sourcesHash
                || keccak256(abi.encode(mode)) != keccak256(abi.encode(facts))
                || Integrity.requireIntact(payload) != receipt.payloadHash
        ) revert M.InvalidModeEvidence();
        return EncodedInput.compact(decoded, modeEvidence, context);
    }
}
