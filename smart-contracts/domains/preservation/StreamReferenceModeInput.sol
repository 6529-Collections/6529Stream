// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";

import {
    StreamReferenceModeTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";

/// @notice Fixed evidence-worker inputs derived from the original complete publication.
/// @dev The caller computes the original context hash over every capture and Environment field.
/// This projection is internal transport, not an independently admissible publication or proof.
library StreamReferenceModeInput {
    struct Capture {
        bytes32 repeatSha256;
        uint64 capturedAt;
    }

    struct EvidenceInput {
        uint256 collectionId;
        uint64 effectiveAt;
        bytes32 contextHash;
        Capture[] captures;
    }

    function project(R.Publication memory p, bytes32 context)
        internal
        pure
        returns (EvidenceInput memory input)
    {
        input.collectionId = p.collectionId;
        input.effectiveAt = p.effectiveAt;
        input.contextHash = context;
        input.captures = new Capture[](p.captures.length);
        for (uint256 i; i < p.captures.length; ++i) {
            input.captures[i] =
                Capture(p.captures[i].repeatCaptureSha256[1], p.captures[i].capturedAt);
        }
    }

    function contextHash(R.Dependencies memory d, R.Publication memory p)
        internal
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

    function payload(
        R.Publication memory p,
        R.Receipt memory receipt,
        R.SourceFacts memory source,
        M.Evidence memory evidence,
        M.Facts memory facts,
        bytes memory environment
    ) internal pure returns (bytes memory out) {
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
