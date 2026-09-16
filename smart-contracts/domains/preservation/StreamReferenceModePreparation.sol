// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceModeTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import { StreamReferenceModeProof } from "./StreamReferenceModeProof.sol";
import { StreamReferenceRenderSourceReads } from "./StreamReferenceRenderSourceReads.sol";
import { StreamReferenceRenderPreparation } from "./StreamReferenceRenderPreparation.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";

/// @notice Fixed mode tuple decoding; the host retains candidate/authority checks and all writes.
library StreamReferenceModePreparation {
    struct Prepared {
        bytes32 sourcesHash;
        M.Facts mode;
        bytes canonical;
        bytes evidence;
    }

    function prepare(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        R.Publication memory p,
        R.Receipt memory receipt,
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        bytes calldata original,
        bool writing
    ) public view returns (Prepared memory result) {
        // Both original mode write/preview selectors begin with this exact pair. Preview's
        // trailing recorder is consumed by the host before this fixed decoder is called.
        (, M.Evidence memory evidence) = abi.decode(original[4:], (R.Publication, M.Evidence));
        R.SourceFacts memory source = StreamReferenceRenderSourceReads.requireModeSourceInputs(
            d, StreamReferenceRenderSourceReads.project(p), false
        );
        result.mode =
            StreamReferenceModeProof.requireEvidence(d, bindings, p, source, evidence, false);
        result.sourcesHash = StreamReferenceModeProof.sourceHash(d, bindings, source, result.mode);
        if (writing && (p.expectedSourcesHash == 0 || p.expectedSourcesHash != result.sourcesHash))
        {
            revert R.InvalidReferenceRender();
        }
        p.expectedSourcesHash = result.sourcesHash;
        receipt.sourcesHash = result.sourcesHash;
        result.canonical = StreamReferenceModeProof.payload(
            p,
            receipt,
            source,
            evidence,
            result.mode,
            StreamReferenceRenderPreparation.environment(inventories, p.environment)
        );
        result.evidence = abi.encode(evidence);
    }

    function current(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        Bytes.Manifest storage publication,
        Bytes.Manifest storage saved
    ) public view returns (bytes32 sourcesHash, M.Facts memory facts) {
        R.Publication memory p = abi.decode(Bytes.read(publication), (R.Publication));
        M.Evidence memory evidence = _evidence(saved);
        R.SourceFacts memory source = StreamReferenceRenderSourceReads.requireModeSourceInputs(
            d, StreamReferenceRenderSourceReads.project(p), true
        );
        facts = StreamReferenceModeProof.requireEvidence(d, bindings, p, source, evidence, true);
        sourcesHash = StreamReferenceModeProof.sourceHash(d, bindings, source, facts);
    }

    function evidenceEncoded(Bytes.Manifest storage saved, M.Facts storage facts)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(_evidence(saved), facts);
    }

    /// @dev Original current-source comparison, in the same order, without transporting the
    /// large Facts tuple back through the host solely to encode and compare it again.
    function requireCurrent(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        Bytes.Manifest storage publication,
        Bytes.Manifest storage evidence,
        M.Facts storage savedFacts,
        Bytes.Manifest storage payload,
        R.Receipt storage receipt
    ) public view {
        (bytes32 sourcesHash, M.Facts memory mode) = current(d, bindings, publication, evidence);
        if (
            sourcesHash != receipt.sourcesHash
                || keccak256(abi.encode(mode)) != keccak256(abi.encode(savedFacts))
                || Bytes.requireIntact(payload) != receipt.payloadHash
        ) revert M.InvalidModeEvidence();
    }

    function _evidence(Bytes.Manifest storage saved) private view returns (M.Evidence memory e) {
        bytes memory raw = Bytes.read(saved);
        e = abi.decode(raw, (M.Evidence));
        if (keccak256(raw) != keccak256(abi.encode(e))) revert M.InvalidModeEvidence();
    }
}
