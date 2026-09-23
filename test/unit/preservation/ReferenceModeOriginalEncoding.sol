// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceModeTypes as M
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../../smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol";

/// @dev Exact public context/payload bodies retained from fef35eaaa2333f780690f6433f5c8564e735abf5.
/// Kept independent of the optimized worker so differential tests do not share its implementation.
library ReferenceModeOriginalEncoding {
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
