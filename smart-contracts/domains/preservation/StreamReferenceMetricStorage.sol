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

import {
    StreamReferenceMetricEncodedProof as Encoded
} from "./StreamReferenceMetricEncodedProof.sol";

/// @notice Fixed supplement storage codec. Host guards source currentness, lock and writer authority.
library StreamReferenceMetricStorage {
    struct State {
        mapping(bytes32 => Bytes.Manifest) payloads;
        mapping(bytes32 => T.Receipt) receipts;
    }

    struct Context {
        R.Dependencies dependencies;
        R.Receipt original;
        address recorder;
        uint8 authorizationClass;
        uint64 grantRevision;
    }
    event ReferenceMetricSupplementPublished(
        uint16 schemaVersion,
        bytes32 indexed referenceRecordHash,
        bytes32 indexed supplementHash,
        T.Receipt receipt
    );

    function publish(
        State storage state,
        Context memory c,
        Bytes.Manifest storage publication,
        Bytes.Manifest storage modeEvidence,
        bytes calldata original
    ) public returns (bytes32 hash) {
        (bytes32 key, T.Supplement memory s) = abi.decode(original[4:], (bytes32, T.Supplement));
        if (key != c.original.recordHash || state.receipts[key].supplementHash != 0) {
            revert T.MetricSupplementAlreadyPublished(key);
        }
        if (
            c.recorder == address(0) || (c.authorizationClass != 3 && c.authorizationClass != 8)
                || c.grantRevision == 0 || block.timestamp > type(uint64).max
        ) revert T.InvalidMetricSupplement();
        (bytes32 runtimeHash, bytes32 replayHash) =
            _proof(c.dependencies, publication, modeEvidence, s);
        bytes memory canonical = abi.encode(s);
        if (canonical.length == 0 || canonical.length > 524288) revert T.InvalidMetricSupplement();
        T.Receipt memory r;
        r.referenceRecordHash = key;
        r.payloadHash = keccak256(canonical);
        r.payloadBytes = uint32(canonical.length);
        r.runtimeHash = runtimeHash;
        r.replayHash = replayHash;
        r.schemaHash = D.SCHEMA_HASH;
        r.profileHash = D.PROFILE_HASH;
        r.canonicalizationHash = ModeD.CANON_HASH;
        r.recorder = c.recorder;
        r.authorizationClass = c.authorizationClass;
        r.grantRevision = c.grantRevision;
        r.recordedAt = uint64(block.timestamp);
        hash = _hash(c.dependencies, r);
        r.supplementHash = hash;
        Bytes.retain(state.payloads[key], c.dependencies.targets[3], canonical);
        state.receipts[key] = r;
        emit ReferenceMetricSupplementPublished(1, key, hash, r);
    }

    function publishChecked(
        State storage state,
        Context memory c,
        R.Publication memory publication,
        M.Evidence memory modeEvidence,
        bytes32 context,
        bytes calldata original
    ) internal returns (bytes32 hash) {
        (bytes32 key, T.Supplement memory s) = abi.decode(original[4:], (bytes32, T.Supplement));
        if (key != c.original.recordHash || state.receipts[key].supplementHash != 0) {
            revert T.MetricSupplementAlreadyPublished(key);
        }
        if (
            c.recorder == address(0) || (c.authorizationClass != 3 && c.authorizationClass != 8)
                || c.grantRevision == 0 || block.timestamp > type(uint64).max
        ) revert T.InvalidMetricSupplement();
        (bytes32 runtimeHash, bytes32 replayHash) =
            _proofChecked(c.dependencies, publication, modeEvidence, context, s);
        bytes memory canonical = abi.encode(s);
        if (canonical.length == 0 || canonical.length > 524288) revert T.InvalidMetricSupplement();
        T.Receipt memory r;
        r.referenceRecordHash = key;
        r.payloadHash = keccak256(canonical);
        r.payloadBytes = uint32(canonical.length);
        r.runtimeHash = runtimeHash;
        r.replayHash = replayHash;
        r.schemaHash = D.SCHEMA_HASH;
        r.profileHash = D.PROFILE_HASH;
        r.canonicalizationHash = ModeD.CANON_HASH;
        r.recorder = c.recorder;
        r.authorizationClass = c.authorizationClass;
        r.grantRevision = c.grantRevision;
        r.recordedAt = uint64(block.timestamp);
        hash = _hash(c.dependencies, r);
        r.supplementHash = hash;
        Bytes.retain(state.payloads[key], c.dependencies.targets[3], canonical);
        state.receipts[key] = r;
        emit ReferenceMetricSupplementPublished(1, key, hash, r);
    }

    function publishCompact(
        State storage state,
        Context memory c,
        StreamReferenceMetricProof.CompactInput memory input,
        bytes calldata original
    ) internal returns (bytes32 hash) {
        Encoded.Guard memory guard = Encoded.Guard(
            c.original.recordHash,
            state.receipts[c.original.recordHash].supplementHash,
            c.recorder,
            c.authorizationClass,
            c.grantRevision
        );
        (bytes32 key, bytes memory canonical, bytes32 runtimeHash, bytes32 replayHash) =
            Encoded.prepare(c.dependencies, input, guard, original);
        T.Receipt memory r;
        r.referenceRecordHash = key;
        r.payloadHash = keccak256(canonical);
        r.payloadBytes = uint32(canonical.length);
        r.runtimeHash = runtimeHash;
        r.replayHash = replayHash;
        r.schemaHash = D.SCHEMA_HASH;
        r.profileHash = D.PROFILE_HASH;
        r.canonicalizationHash = ModeD.CANON_HASH;
        r.recorder = c.recorder;
        r.authorizationClass = c.authorizationClass;
        r.grantRevision = c.grantRevision;
        r.recordedAt = uint64(block.timestamp);
        hash = _hash(c.dependencies, r);
        r.supplementHash = hash;
        Bytes.retain(state.payloads[key], c.dependencies.targets[3], canonical);
        state.receipts[key] = r;
        emit ReferenceMetricSupplementPublished(1, key, hash, r);
    }

    function requireCompact(
        State storage state,
        R.Dependencies memory d,
        bytes32 key,
        StreamReferenceMetricProof.CompactInput memory input
    ) internal view returns (T.Receipt memory r) {
        r = state.receipts[key];
        if (
            r.supplementHash == 0 || r.referenceRecordHash != key || r.schemaHash != D.SCHEMA_HASH
                || r.profileHash != D.PROFILE_HASH || r.canonicalizationHash != ModeD.CANON_HASH
                || r.supplementHash != _hash(d, r)
        ) revert T.InvalidMetricSupplement();
        bytes memory canonical = Bytes.read(state.payloads[key]);
        (bytes32 runtimeHash, bytes32 replayHash) =
            Encoded.requireCanonical(d, input, canonical, r.payloadHash, r.payloadBytes);
        if (r.runtimeHash != runtimeHash || r.replayHash != replayHash) {
            revert T.InvalidMetricSupplement();
        }
    }

    function encoded(State storage state, bytes32 key) public view returns (bytes memory) {
        if (state.receipts[key].supplementHash == 0) revert T.InvalidMetricSupplement();
        return abi.encode(Bytes.read(state.payloads[key]), state.receipts[key]);
    }

    function requireEncoded(
        State storage state,
        R.Dependencies memory d,
        bytes32 key,
        Bytes.Manifest storage publication,
        Bytes.Manifest storage modeEvidence
    ) public view returns (bytes memory) {
        return abi.encode(_require(state, d, key, publication, modeEvidence));
    }

    function requireHash(
        State storage state,
        R.Dependencies memory d,
        bytes32 key,
        Bytes.Manifest storage publication,
        Bytes.Manifest storage modeEvidence
    ) public view returns (bytes32) {
        return _require(state, d, key, publication, modeEvidence).supplementHash;
    }

    function _require(
        State storage state,
        R.Dependencies memory d,
        bytes32 key,
        Bytes.Manifest storage publication,
        Bytes.Manifest storage modeEvidence
    ) private view returns (T.Receipt memory r) {
        r = state.receipts[key];
        if (
            r.supplementHash == 0 || r.referenceRecordHash != key || r.schemaHash != D.SCHEMA_HASH
                || r.profileHash != D.PROFILE_HASH || r.canonicalizationHash != ModeD.CANON_HASH
                || r.supplementHash != _hash(d, r)
        ) revert T.InvalidMetricSupplement();
        bytes memory canonical = Bytes.read(state.payloads[key]);
        T.Supplement memory s = abi.decode(canonical, (T.Supplement));
        if (
            keccak256(abi.encode(s)) != r.payloadHash || keccak256(canonical) != r.payloadHash
                || canonical.length != r.payloadBytes
        ) revert T.InvalidMetricSupplement();
        (bytes32 runtimeHash, bytes32 replayHash) = _proof(d, publication, modeEvidence, s);
        if (r.runtimeHash != runtimeHash || r.replayHash != replayHash) {
            revert T.InvalidMetricSupplement();
        }
    }

    function requireChecked(
        State storage state,
        R.Dependencies memory d,
        bytes32 key,
        R.Publication memory publication,
        M.Evidence memory modeEvidence,
        bytes32 context
    ) internal view returns (T.Receipt memory r) {
        r = state.receipts[key];
        if (
            r.supplementHash == 0 || r.referenceRecordHash != key || r.schemaHash != D.SCHEMA_HASH
                || r.profileHash != D.PROFILE_HASH || r.canonicalizationHash != ModeD.CANON_HASH
                || r.supplementHash != _hash(d, r)
        ) revert T.InvalidMetricSupplement();
        bytes memory canonical = Bytes.read(state.payloads[key]);
        T.Supplement memory s = abi.decode(canonical, (T.Supplement));
        if (
            keccak256(abi.encode(s)) != r.payloadHash || keccak256(canonical) != r.payloadHash
                || canonical.length != r.payloadBytes
        ) revert T.InvalidMetricSupplement();
        (bytes32 runtimeHash, bytes32 replayHash) =
            _proofChecked(d, publication, modeEvidence, context, s);
        if (r.runtimeHash != runtimeHash || r.replayHash != replayHash) {
            revert T.InvalidMetricSupplement();
        }
    }

    function _proof(
        R.Dependencies memory d,
        Bytes.Manifest storage publication,
        Bytes.Manifest storage evidence,
        T.Supplement memory s
    ) private view returns (bytes32 runtimeHash, bytes32 replayHash) {
        _definitions(d);
        R.Publication memory p = abi.decode(Bytes.read(publication), (R.Publication));
        M.Evidence memory e = abi.decode(Bytes.read(evidence), (M.Evidence));
        return StreamReferenceMetricProof.requireEvidence(
            p, e, StreamReferenceModeProof.contextHash(d, p), s
        );
    }

    function _proofChecked(
        R.Dependencies memory d,
        R.Publication memory publication,
        M.Evidence memory evidence,
        bytes32 context,
        T.Supplement memory s
    ) private view returns (bytes32 runtimeHash, bytes32 replayHash) {
        _definitions(d);
        return StreamReferenceMetricProof.requireProjected(
            StreamReferenceMetricProof.project(publication, evidence, context), s
        );
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

    function _hash(R.Dependencies memory d, T.Receipt memory r) private view returns (bytes32) {
        bytes32 saved = r.supplementHash;
        r.supplementHash = 0;
        bytes32 result = keccak256(
            abi.encode(
                keccak256("6529STREAM_METRIC_SUPPLEMENT_V1"),
                d.chainId,
                address(this),
                d.targets[0],
                d.targets[1],
                r
            )
        );
        r.supplementHash = saved;
        return result;
    }
}
