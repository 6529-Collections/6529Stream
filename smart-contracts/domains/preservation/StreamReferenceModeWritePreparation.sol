// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceModeTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import { StreamReferenceModeProof as Proof } from "./StreamReferenceModeProof.sol";
import { StreamReferenceModeInput as Input } from "./StreamReferenceModeInput.sol";
import {
    StreamReferenceRenderSourceReads as Sources
} from "./StreamReferenceRenderSourceReads.sol";
import {
    StreamReferenceRenderPreparation as Environment
} from "./StreamReferenceRenderPreparation.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import {
    StreamReferenceModePayloadPreparation as Payload
} from "./StreamReferenceModePayloadPreparation.sol";

/// @notice Original write admission followed by an internally selected immutable-carrier descriptor.
/// @dev Separate fixed output codec keeps the unchanged complete-byte preview/current workers bounded.
library StreamReferenceModeWritePreparation {
    struct Prepared {
        bytes32 sourcesHash;
        M.Facts mode;
        bytes canonical;
        bytes evidence;
        Payload.Selection selected;
    }

    function prepare(
        R.Dependencies memory d,
        M.Dependencies memory bindings,
        R.Receipt memory receipt,
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        Payload.State storage preparedPayloads,
        bytes calldata original
    ) public view returns (Prepared memory result) {
        // Exact original _validate write sequence. The caller still owns candidate, writer,
        // selected dependency definitions, receipt construction, record hashes and all mutations.
        (R.Publication memory p, M.Evidence memory evidence) =
            abi.decode(original[4:], (R.Publication, M.Evidence));
        R.SourceFacts memory source = Sources.requireModeSourceInputs(d, Sources.project(p), false);
        result.mode = Proof.requireEvidenceProjected(
            d, bindings, Input.project(p, Input.contextHash(d, p)), source, evidence, false
        );
        result.sourcesHash = Proof.sourceHash(d, bindings, source, result.mode);
        if (p.expectedSourcesHash == 0 || p.expectedSourcesHash != result.sourcesHash) {
            revert R.InvalidReferenceRender();
        }
        p.expectedSourcesHash = result.sourcesHash;
        receipt.sourcesHash = result.sourcesHash;
        result.evidence = abi.encode(evidence);
        bytes memory encoded = abi.encode(p);
        if (encoded.length > 524288) revert M.InvalidModeEvidence();
        result.selected = Payload.selectForWrite(
            preparedPayloads,
            keccak256(encoded),
            uint32(encoded.length),
            receipt,
            source,
            evidence,
            result.mode
        );
        if (result.selected.payloadId == 0) {
            result.canonical = Proof.payload(
                p, receipt, source, evidence, result.mode, _environment(inventories, p.environment)
            );
        }
    }

    function _environment(
        mapping(bytes32 => Bytes.Manifest) storage inventories,
        R.Environment memory e
    ) private view returns (bytes memory) {
        bytes32 id = Environment.environmentIdInternal(e);
        if (inventories[id].contentHash != 0) return Bytes.read(inventories[id]);
        return Environment.environment(inventories, e);
    }
}
