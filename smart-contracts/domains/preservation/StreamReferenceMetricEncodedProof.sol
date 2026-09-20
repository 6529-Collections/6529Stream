// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamReferenceMetricTypes as T
} from "../../interfaces/stream/preservation/StreamReferenceMetricTypes.sol";
import {
    IStreamReferenceMetricSupplement
} from "../../interfaces/stream/preservation/IStreamReferenceMetricSupplement.sol";
import {
    StreamReferenceModeTypes as M
} from "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import {
    StreamReferenceMetricDefinitions as D
} from "../records/StreamReferenceMetricDefinitions.sol";
import {
    StreamReferenceModeDefinitions as ModeD
} from "../records/StreamReferenceModeDefinitions.sol";
import {
    StreamReferenceModeDefinitionsRead as Definitions
} from "./StreamReferenceModeDefinitionsRead.sol";
import { StreamWorkRecordContext } from "../records/StreamWorkRecordContext.sol";
import { IStreamSchemaRegistry } from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import { StreamReferenceModeProof } from "./StreamReferenceModeProof.sol";
import { StreamReferenceMetricProof } from "./StreamReferenceMetricProof.sol";

/// @notice Fixed encoded supplement proof; no publication authority is granted by these codecs.
library StreamReferenceMetricEncodedProof {
    struct Guard {
        bytes32 originalRecordHash;
        bytes32 existingSupplementHash;
        address recorder;
        uint8 authorizationClass;
        uint64 grantRevision;
    }

    function prepare(
        R.Dependencies memory d,
        StreamReferenceMetricProof.CompactInput memory input,
        Guard memory g,
        bytes calldata original
    )
        public
        view
        returns (bytes32 key, bytes memory canonical, bytes32 runtimeHash, bytes32 replayHash)
    {
        T.Supplement memory s;
        (key, s) = abi.decode(original[4:], (bytes32, T.Supplement));
        if (key != g.originalRecordHash || g.existingSupplementHash != 0) {
            revert T.MetricSupplementAlreadyPublished(key);
        }
        if (
            g.recorder == address(0) || (g.authorizationClass != 3 && g.authorizationClass != 8)
                || g.grantRevision == 0 || block.timestamp > type(uint64).max
        ) revert T.InvalidMetricSupplement();
        _definitions(d);
        (runtimeHash, replayHash) = StreamReferenceMetricProof.requireCompact(input, s);
        canonical = abi.encode(s);
        if (canonical.length == 0 || canonical.length > 524288) revert T.InvalidMetricSupplement();
    }

    function requireCanonical(
        R.Dependencies memory d,
        StreamReferenceMetricProof.CompactInput memory input,
        bytes memory canonical,
        bytes32 expectedHash,
        uint32 expectedLength
    ) public view returns (bytes32 runtimeHash, bytes32 replayHash) {
        T.Supplement memory s = abi.decode(canonical, (T.Supplement));
        if (
            keccak256(abi.encode(s)) != expectedHash || keccak256(canonical) != expectedHash
                || canonical.length != expectedLength
        ) revert T.InvalidMetricSupplement();
        _definitions(d);
        return StreamReferenceMetricProof.requireCompact(input, s);
    }

    function _definitions(R.Dependencies memory d) private view {
        StreamWorkRecordContext.definition(
            Definitions.context(d),
            D.SCHEMA_ID,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            D.SCHEMA_HASH,
            D.SCHEMA_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
        StreamWorkRecordContext.definition(
            Definitions.context(d),
            D.PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            D.PROFILE_HASH,
            D.PROFILE_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
    }
}
