// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamOwnerNoticeDefinitions.sol";
import "./StreamWorkRecordDefinitions.sol";
import "./StreamStewardDesignationJson.sol";
import "../metadata/StreamOwnerRecordReads.sol";
import "../metadata/StreamSchemaDocumentStore.sol";
import "../../interfaces/stream/metadata/IStreamOwnerStewardRecords.sol";

/// @notice Exact registered interpretation bytes for owner-authored notice records.
/// @dev Retirement cannot lock owner documentation. Immutable definitions remain readable.
library StreamOwnerNoticeAdmission {
    struct Configuration {
        address schemas;
        bytes32 schemasCodeHash;
        address store;
        bytes32 storeCodeHash;
        uint256 readGas;
    }

    function requireSteward(
        Configuration memory c,
        IStreamOwnerRecords.OwnerRecord memory r,
        StreamOwnerNoticeTypes.Designation memory d
    ) public view {
        if (
            r.recordType != keccak256("STEWARD_DESIGNATION")
                || r.schemaId != StreamOwnerNoticeDefinitions.STEWARD_SCHEMA_ID
                || r.contentHash.canonicalizationId != StreamWorkRecordDefinitions.CANON_ID
                || d.subjectId != r.subjectId
                || d.profileHash != StreamOwnerNoticeDefinitions.STEWARD_PROFILE_HASH
        ) {
            revert IStreamOwnerStewardRecords.InvalidOwnerNoticeRecord();
        }
        StreamStewardDesignationJson.requireExact(d, r.payload);
        StreamOwnerRecordReads.requireCode(c.schemas, c.schemasCodeHash);
        StreamOwnerRecordReads.requireCode(c.store, c.storeCodeHash);
        _definition(
            c,
            StreamOwnerNoticeDefinitions.STEWARD_SCHEMA_ID,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamOwnerNoticeDefinitions.STEWARD_SCHEMA_HASH,
            StreamOwnerNoticeDefinitions.STEWARD_SCHEMA_BYTES
        );
        _definition(
            c,
            StreamOwnerNoticeDefinitions.STEWARD_PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            StreamOwnerNoticeDefinitions.STEWARD_PROFILE_HASH,
            StreamOwnerNoticeDefinitions.STEWARD_PROFILE_BYTES
        );
        _definition(
            c,
            StreamWorkRecordDefinitions.CANON_ID,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            StreamWorkRecordDefinitions.CANON_HASH,
            StreamWorkRecordDefinitions.CANON_BYTES
        );
    }

    function requireGeneric(IStreamOwnerRecords.OwnerRecord memory r) internal pure {
        if (
            r.schemaId == StreamOwnerNoticeDefinitions.STEWARD_SCHEMA_ID
                && r.recordType == keccak256("STEWARD_DESIGNATION")
        ) {
            revert IStreamOwnerStewardRecords.TypedOwnerRecordRequired();
        }
    }

    function _definition(
        Configuration memory c,
        bytes32 id,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes32 expectedHash,
        uint256 expectedLength
    ) private view {
        bytes memory raw = StreamOwnerRecordReads.bounded(
            c.schemas,
            abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (id)),
            288,
            c.readGas
        );
        if (raw.length != 288) revert IStreamOwnerRecords.OwnerRecordReadFailed(c.schemas);
        IStreamSchemaDocumentFacts.DocumentFacts memory facts =
            abi.decode(raw, (IStreamSchemaDocumentFacts.DocumentFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(facts)) || !facts.exists || facts.kind != kind
                || facts.contentHash != expectedHash || facts.totalBytes != expectedLength
                || facts.canonicalizationId != keccak256("RAW_BYTES") || facts.supersedesId != 0
                || facts.declarationHash == 0 || facts.chunkCount == 0 || facts.chunkCount > 64
        ) revert IStreamOwnerStewardRecords.OwnerNoticeDefinitionUnavailable(id);
        bytes memory payload;
        for (uint256 i; i < facts.chunkCount; ++i) {
            raw = StreamOwnerRecordReads.bounded(
                c.schemas,
                abi.encodeCall(IStreamSchemaDocumentFacts.documentChunkHashAt, (id, i)),
                32,
                c.readGas
            );
            if (raw.length != 32) revert IStreamOwnerRecords.OwnerRecordReadFailed(c.schemas);
            bytes32 chunkHash = abi.decode(raw, (bytes32));
            raw = StreamOwnerRecordReads.bounded(
                c.store,
                abi.encodeCall(StreamSchemaDocumentStore.readChunk, (chunkHash)),
                8256,
                c.readGas
            );
            bytes memory chunk = abi.decode(raw, (bytes));
            if (
                keccak256(raw) != keccak256(abi.encode(chunk)) || keccak256(chunk) != chunkHash
                    || chunk.length == 0 || chunk.length > 8192
                    || (i + 1 < facts.chunkCount && chunk.length != 8192)
                    || payload.length + chunk.length > expectedLength
            ) revert IStreamOwnerStewardRecords.OwnerNoticeDefinitionUnavailable(id);
            payload = bytes.concat(payload, chunk);
        }
        if (payload.length != expectedLength || keccak256(payload) != expectedHash) {
            revert IStreamOwnerStewardRecords.OwnerNoticeDefinitionUnavailable(id);
        }
    }
}
