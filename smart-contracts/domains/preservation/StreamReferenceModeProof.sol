// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceModeTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import { StreamReferenceRenderSourceReads } from "./StreamReferenceRenderSourceReads.sol";
import {
    StreamExternalArtifactTypes as E
} from "../../interfaces/stream/preservation/StreamExternalArtifactTypes.sol";
import { StreamMetadataRenderer } from "../metadata/StreamMetadataRenderer.sol";
import { StreamReferenceModeDefinitions } from "../records/StreamReferenceModeDefinitions.sol";
import { StreamReferenceModeCurated } from "./StreamReferenceModeCurated.sol";
import { StreamReferenceModeDefinitionsRead } from "./StreamReferenceModeDefinitionsRead.sol";

/// @notice Complete source-bound evidence for the two explicit non-byte-exact acceptance modes.
/// @dev The EVM validates original evidence and thresholds, not offchain browser/metric execution.
library StreamReferenceModeProof {
    function contextHash(R.Dependencies memory d, R.Publication memory p)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_MODE_CONTEXT_V1"),
                d.chainId,
                address(this),
                d.targets,
                d.codeHashes,
                p.collectionId,
                p.referenceId,
                p.snapshotRecordHash,
                p.snapshotRevision,
                p.captures,
                p.environment
            )
        );
    }

    function requireEvidence(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        R.Publication memory p,
        R.SourceFacts memory source,
        M.Evidence memory w,
        bool current
    ) public view returns (M.Facts memory f) {
        StreamReferenceModeDefinitionsRead.requireDefinitions(d);
        if (
            (w.mode != M.Mode.PERCEPTUAL_TOLERANCE && w.mode != M.Mode.CURATED_EQUIVALENCE)
                || w.repeats.length != p.captures.length || w.repeats.length == 0
                || w.repeats.length > 2
        ) {
            revert M.InvalidModeEvidence();
        }
        f.mode = w.mode;
        f.evidenceHash = keccak256(abi.encode(w));
        f.repeats = new E.Coverage[](w.repeats.length);
        for (uint256 i; i < w.repeats.length; ++i) {
            f.repeats[i] = StreamReferenceRenderSourceReads.coverage(
                d, w.repeats[i].coverageHash, source.artistId, w.repeats[i].objectHash, current
            );
            StreamReferenceRenderSourceReads.requireCaptureObject(d, f.repeats[i]);
            if (f.repeats[i].sha256Digest != p.captures[i].repeatCaptureSha256[1]) {
                revert M.InvalidModeEvidence();
            }
        }
        bytes32 context = contextHash(d, p);
        if (w.mode == M.Mode.PERCEPTUAL_TOLERANCE) {
            M.Curated memory empty;
            if (keccak256(abi.encode(w.curated)) != keccak256(abi.encode(empty))) {
                revert M.InvalidModeEvidence();
            }
            f.interpretationHash = StreamReferenceModeDefinitionsRead.metric(d, w.perceptual.metric);
            M.Perceptual memory m = w.perceptual;
            if (
                m.threshold < 0 || m.threshold > 1000000000 || m.scores.length != p.captures.length
                    || m.evaluatedAt == 0 || m.evaluatedAt > p.effectiveAt || m.reportHash == 0
            ) {
                revert M.InvalidModeEvidence();
            }
            StreamMetadataRenderer.requireValidUtf8ContentUri(
                "metricReportURI", m.reportURI, 2048, true
            );
            for (uint256 i; i < m.scores.length; ++i) {
                if (
                    m.scores[i] < m.threshold || m.scores[i] > 1000000000
                        || m.evaluatedAt < p.captures[i].capturedAt
                ) {
                    revert M.InvalidModeEvidence();
                }
            }
            // Full reproducible report preimage is retained in Evidence, including exact source context.
            if (
                m.reportHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PERCEPTUAL_REPORT_V1"),
                            context,
                            m.metric,
                            m.threshold,
                            m.scores,
                            m.evaluatedAt
                        )
                    )
            ) revert M.InvalidModeEvidence();
        } else {
            M.Perceptual memory empty;
            if (keccak256(abi.encode(w.perceptual)) != keccak256(abi.encode(empty))) {
                revert M.InvalidModeEvidence();
            }
            (f.intentSelectionHash, f.conditionReceiptHash) =
                StreamReferenceModeCurated.requireEvidence(
                    d, bindings, p, source, w.curated, context
                );
            f.conditionRecordHash = w.curated.conditionRecordHash;
            f.interpretationHash = keccak256(
                abi.encode(
                    StreamReferenceModeDefinitions.CONDITION_HASH,
                    StreamReferenceModeDefinitions.PROPERTIES_HASH,
                    StreamReferenceModeDefinitions.CANON_HASH
                )
            );
        }
    }

    function sourceHash(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        R.SourceFacts memory source,
        M.Facts memory mode
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_MODE_SOURCES_V1"),
                d.chainId,
                address(this),
                d.targets,
                d.codeHashes,
                d.rendererCatalogId,
                d.rendererCatalogHash,
                bindings,
                source,
                mode
            )
        );
    }

    function payload(
        R.Publication memory p,
        R.Receipt memory receipt,
        R.SourceFacts memory source,
        M.Evidence memory evidence,
        M.Facts memory facts,
        bytes memory environment
    ) public pure returns (bytes memory out) {
        if (
            keccak256(environment) != p.environment.manifestHash
                || environment.length != p.environment.manifestBytes
        ) {
            revert M.InvalidModeEvidence();
        }
        for (uint256 i; i < p.captures.length; ++i) {
            if (p.captures[i].environmentManifestHash != p.environment.manifestHash) {
                revert M.InvalidModeEvidence();
            }
        }
        receipt.recordHash = 0;
        receipt.recordChainHash = 0;
        receipt.payloadHash = 0;
        receipt.payloadBytes = 0;
        receipt.recordedAt = 0;
        out = abi.encode(
            keccak256("6529STREAM_REFERENCE_MODE_PAYLOAD_V1"),
            p,
            receipt,
            source,
            evidence,
            facts,
            environment
        );
        if (out.length == 0 || out.length > 524288) revert M.InvalidModeEvidence();
    }
}
