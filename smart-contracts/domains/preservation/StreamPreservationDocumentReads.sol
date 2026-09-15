// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";
import "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import "../metadata/StreamSchemaDocumentStore.sol";
import { StreamWorkRecordDefinitions as W } from "../records/StreamWorkRecordDefinitions.sol";
import { StreamRightsRecordDefinitions as R } from "../records/StreamRightsRecordDefinitions.sol";
import { StreamConservationDefinitions as C } from "../records/StreamConservationDefinitions.sol";
import { StreamSnapshotDefinitions as Snap } from "../records/StreamSnapshotDefinitions.sol";
import {
    StreamReferenceRenderDefinitions as Ref
} from "../records/StreamReferenceRenderDefinitions.sol";
import "../finality/StreamContentRootSchemas.sol";

/// @notice Complete ordered registered interpretation bytes, including repeated chunks.
library StreamPreservationDocumentReads {
    uint64 internal constant FIXED_COUNT = 30;

    function fixedHash(uint64 index) public pure returns (bytes32) {
        if (index >= FIXED_COUNT) revert T.InvalidInventoryItem();
        if (index >= 26) return StreamContentRootSchemas.definitionHash(fixedId(index));
        if (index == 25) {
            return keccak256(
                bytes(
                    '{"name":"RAW_BYTES","rule":"Do not transform the supplied bytes.","version":1}'
                )
            );
        }
        bytes32[25] memory hashes = [
            W.SCHEMA_HASH,
            W.PROFILE_HASH,
            W.CATALOG_SCHEMA_HASH,
            W.CATALOG_PROFILE_HASH,
            R.SCHEMA_HASH,
            R.PROFILE_HASH,
            C.INTENT_SCHEMA_HASH,
            C.INTENT_PROFILE_HASH,
            C.WAIVER_SCHEMA_HASH,
            C.WAIVER_PROFILE_HASH,
            C.INTERVIEW_SCHEMA_HASH,
            C.INTERVIEW_PROFILE_HASH,
            C.CATALOG_SCHEMA_HASH,
            C.CATALOG_PROFILE_HASH,
            Snap.SCHEMA_HASH,
            Snap.PROFILE_HASH,
            Ref.RENDERER_SCHEMA_HASH,
            Ref.RENDERER_PROFILE_HASH,
            Ref.SCHEMA_HASH,
            Ref.PROFILE_HASH,
            Ref.ENVIRONMENT_SCHEMA_HASH,
            Ref.PNG_SCHEMA_HASH,
            Ref.ZIP_SCHEMA_HASH,
            Ref.FORMAT_CATALOG_HASH,
            Snap.CANON_HASH
        ];
        return hashes[index];
    }

    function currentFactsHash(S.Dependencies memory d, bytes32 id) public view returns (bytes32) {
        IO.pin(d.targets[2], d.codeHashes[2]);
        IO.pin(d.targets[3], d.codeHashes[3]);
        bytes memory raw = IO.fixedRead(
            d.targets[2],
            abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (id)),
            288,
            d.readGas
        );
        IStreamSchemaDocumentFacts.DocumentFacts memory facts =
            abi.decode(raw, (IStreamSchemaDocumentFacts.DocumentFacts));
        IO.canonical(d.targets[2], raw, abi.encode(facts));
        if (!facts.exists || facts.status != IStreamSchemaRegistry.DocumentStatus.ACTIVE) {
            revert T.InvalidInventoryItem();
        }
        return keccak256(raw);
    }

    function fixedId(uint64 index) public pure returns (bytes32) {
        if (index >= FIXED_COUNT) revert T.InvalidInventoryItem();
        string[30] memory names = [
            "STREAM_WORK_DESCRIPTION_V1",
            "STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1",
            "STREAM_WORK_FORMAT_CATALOG_V1",
            "STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1",
            "STREAM_RIGHTS_V1",
            "STREAM_RIGHTS_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTENT_V1",
            "STREAM_ARTIST_INTENT_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTENT_WAIVER_V1",
            "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTERVIEW_V1",
            "STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1",
            "STREAM_NATIVE_ONCHAIN_SNAPSHOT_V1",
            "STREAM_NATIVE_ONCHAIN_SNAPSHOT_JSON_PROFILE_V1",
            "STREAM_RENDERER_CLASS_DECLARATION_V1",
            "STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1",
            "STREAM_NATIVE_REFERENCE_RENDER_V1",
            "STREAM_NATIVE_REFERENCE_RENDER_JSON_PROFILE_V1",
            "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1",
            "STREAM_REFERENCE_PNG_OBJECT_V1",
            "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1",
            "STREAM_REFERENCE_NATIVE_FORMATS_V1",
            "RFC8785_JCS",
            "RAW_BYTES",
            "STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1",
            "STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1",
            "STREAM_TOKEN_CONTENT_ROOT_RECORD_V1",
            "STREAM_ABI_TOKEN_CONTENT_ROOT_RECORD_V1"
        ];
        return keccak256(bytes(names[index]));
    }

    function item(S.Dependencies memory d, bytes32 id, bytes32 expectedHash)
        public
        view
        returns (T.Item memory result)
    {
        IO.pin(d.targets[2], d.codeHashes[2]);
        IO.pin(d.targets[3], d.codeHashes[3]);
        bytes memory raw = IO.fixedRead(
            d.targets[2],
            abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (id)),
            288,
            d.readGas
        );
        IStreamSchemaDocumentFacts.DocumentFacts memory facts =
            abi.decode(raw, (IStreamSchemaDocumentFacts.DocumentFacts));
        IO.canonical(d.targets[2], raw, abi.encode(facts));
        if (
            !facts.exists || facts.status != IStreamSchemaRegistry.DocumentStatus.ACTIVE
                || facts.contentHash == 0 || facts.totalBytes == 0 || facts.chunkCount == 0
                || facts.chunkCount > 64 || (expectedHash != 0 && facts.contentHash != expectedHash)
        ) revert T.InvalidInventoryItem();
        bytes memory complete;
        for (uint256 i; i < facts.chunkCount; ++i) {
            bytes32 hash = IO.word(
                d.targets[2],
                abi.encodeCall(IStreamSchemaDocumentFacts.documentChunkHashAt, (id, i)),
                d.readGas
            );
            raw = IO.read(
                d.targets[3],
                abi.encodeCall(StreamSchemaDocumentStore.readChunk, (hash)),
                8352,
                d.readGas
            );
            bytes memory chunk = abi.decode(raw, (bytes));
            IO.canonical(d.targets[3], raw, abi.encode(chunk));
            if (
                chunk.length == 0 || chunk.length > 8192 || keccak256(chunk) != hash
                    || complete.length + chunk.length > facts.totalBytes
            ) revert T.InvalidInventoryItem();
            complete = bytes.concat(complete, chunk);
        }
        if (complete.length != facts.totalBytes || keccak256(complete) != facts.contentHash) {
            revert T.InvalidInventoryItem();
        }
        result = Items.bytesItem(
            T.Kind.REGISTERED_DOCUMENT,
            keccak256("REGISTERED_INTERPRETATION_DOCUMENT"),
            d.targets[2],
            id,
            0,
            complete
        );
        // The archive object contains these exact bytes; interpreting them is already bound by
        // the original fixed producer. The declaration preimage omits registration URI/name here.
        result.catalogId = id;
        result.catalogHash = facts.contentHash;
        result.provenanceHash = keccak256(abi.encode(facts));
    }

    function authenticateCatalogs(S.Dependencies memory d, T.Item[] memory items) public view {
        for (uint256 i; i < items.length; ++i) {
            if (items[i].kind != T.Kind.REGISTERED_DOCUMENT) continue;
            T.Item memory actual = item(d, items[i].catalogId, items[i].catalogHash);
            if (
                actual.byteSize != items[i].byteSize
                    || keccak256(actual.digest) != keccak256(items[i].digest)
            ) {
                revert T.InvalidInventoryItem();
            }
        }
    }
}
