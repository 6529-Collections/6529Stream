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
import { StreamReferenceModeInput as Input } from "./StreamReferenceModeInput.sol";
import {
    StreamReferenceModePayloadPreparation as Payload
} from "./StreamReferenceModePayloadPreparation.sol";

/// @notice Fixed mode tuple decoding; the host retains candidate/authority checks and all writes.
library StreamReferenceModePreparation {
    struct Prepared {
        bytes32 sourcesHash;
        M.Facts mode;
        bytes canonical;
        bytes evidence;
    }

    /// @dev Same-call memory only. Never a persisted or externally supplied admission token.
    struct CurrentDecoded {
        R.Publication publication;
        M.Evidence evidence;
        bytes32 context;
    }

    function prepare(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        R.Receipt memory receipt,
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        bytes calldata original,
        bool writing
    ) public view returns (Prepared memory result) {
        R.Publication memory p;
        M.Evidence memory evidence;
        R.SourceFacts memory source;
        (result, p, evidence, source) = _validate(d, bindings, receipt, original, writing);
        result.canonical = StreamReferenceModeProof.payload(
            p, receipt, source, evidence, result.mode, _environment(inventories, p.environment)
        );
    }

    function prepareStaged(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        R.Receipt memory receipt,
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        Payload.State storage preparedPayloads,
        bytes calldata original,
        bool writing
    ) public view returns (Prepared memory result) {
        R.Publication memory p;
        M.Evidence memory evidence;
        R.SourceFacts memory source;
        (result, p, evidence, source) = _validate(d, bindings, receipt, original, writing);
        bytes memory encoded = abi.encode(p);
        if (encoded.length > 524288) revert M.InvalidModeEvidence();
        result.canonical = Payload.lookup(
            preparedPayloads,
            inventories,
            keccak256(encoded),
            uint32(encoded.length),
            receipt,
            source,
            evidence,
            result.mode
        );
        if (result.canonical.length == 0) {
            result.canonical = StreamReferenceModeProof.payload(
                p, receipt, source, evidence, result.mode, _environment(inventories, p.environment)
            );
        }
    }

    function _validate(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        R.Receipt memory receipt,
        bytes calldata original,
        bool writing
    )
        private
        view
        returns (
            Prepared memory result,
            R.Publication memory p,
            M.Evidence memory evidence,
            R.SourceFacts memory source
        )
    {
        // Both original mode write/preview selectors begin with this exact pair. Preview's
        // trailing recorder is consumed by the host before this fixed decoder is called.
        (p, evidence) = abi.decode(original[4:], (R.Publication, M.Evidence));
        source = StreamReferenceRenderSourceReads.requireModeSourceInputs(
            d, StreamReferenceRenderSourceReads.project(p), false
        );
        result.mode = StreamReferenceModeProof.requireEvidenceProjected(
            d, bindings, Input.project(p, Input.contextHash(d, p)), source, evidence, false
        );
        result.sourcesHash = StreamReferenceModeProof.sourceHash(d, bindings, source, result.mode);
        if (writing && (p.expectedSourcesHash == 0 || p.expectedSourcesHash != result.sourcesHash))
        {
            revert R.InvalidReferenceRender();
        }
        p.expectedSourcesHash = result.sourcesHash;
        receipt.sourcesHash = result.sourcesHash;
        result.evidence = abi.encode(evidence);
    }

    /// @dev Derive the complete typed input's exact preparation identity here. Transporting
    /// that large input to another worker solely to derive this same key is unnecessary.
    /// The only reused value is the immutable, self-verified canonical environment bytes.
    function _environment(
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        R.Environment memory e
    ) private view returns (bytes memory) {
        bytes32 id = StreamReferenceRenderPreparation.environmentIdInternal(e);
        if (inventories[id].contentHash != 0) return Bytes.read(inventories[id]);
        return StreamReferenceRenderPreparation.environment(inventories, e);
    }

    function current(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        Bytes.Manifest storage publication,
        Bytes.Manifest storage saved
    ) public view returns (bytes32 sourcesHash, M.Facts memory facts) {
        (sourcesHash, facts,) = currentDecoded(d, bindings, publication, saved);
    }

    function currentDecoded(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        Bytes.Manifest storage publication,
        Bytes.Manifest storage saved
    )
        internal
        view
        returns (bytes32 sourcesHash, M.Facts memory facts, CurrentDecoded memory decoded)
    {
        decoded.publication = abi.decode(Bytes.read(publication), (R.Publication));
        decoded.evidence = _evidence(saved);
        R.SourceFacts memory source = StreamReferenceRenderSourceReads.requireModeSourceInputs(
            d, StreamReferenceRenderSourceReads.project(decoded.publication), true
        );
        decoded.context = Input.contextHash(d, decoded.publication);
        facts = StreamReferenceModeProof.requireEvidenceProjected(
            d,
            bindings,
            Input.project(decoded.publication, decoded.context),
            source,
            decoded.evidence,
            true
        );
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
        requireCurrentDecoded(d, bindings, publication, evidence, savedFacts, payload, receipt);
    }

    function requireCurrentDecoded(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        Bytes.Manifest storage publication,
        Bytes.Manifest storage evidence,
        M.Facts storage savedFacts,
        Bytes.Manifest storage payload,
        R.Receipt storage receipt
    ) internal view returns (CurrentDecoded memory decoded) {
        bytes32 sourcesHash;
        M.Facts memory mode;
        (sourcesHash, mode, decoded) = currentDecoded(d, bindings, publication, evidence);
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
