// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import { StreamSchemaDocumentStore as Store } from "./StreamSchemaDocumentStore.sol";
import { StreamRecordDocumentReads as Documents } from "../records/StreamRecordDocumentReads.sol";
import { StreamCollectionMetadataV1 as Host } from "./StreamCollectionMetadataV1.sol";
import { StreamCollectionManifestExecution } from "./StreamCollectionManifestExecution.sol";
import {
    IStreamCollectionMetadataV1 as V
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";

/// @notice Fixed original Store chunk carrier. Preparation cannot add an accepted record or inventory row.
library StreamMetadataRecordPayloads {
    uint256 internal constant MAXIMUM = 24576;

    function prepare(
        mapping(bytes32 => Bytes.Manifest) storage prepared,
        address store,
        bytes32 storeHash,
        bytes calldata payload
    ) public returns (bytes32 hash) {
        if (payload.length == 0 || payload.length > MAXIMUM) {
            revert V.InvalidMetadataRecord();
        }
        code(store, storeHash);
        if (payload.length <= 8192) {
            (hash,) = Store(store).publishChunk(payload);
            return hash;
        }
        hash = keccak256(payload);
        if (prepared[hash].byteLength != 0) {
            // A corrupt advertised manifest is terminal; never fall back to a different carrier.
            if (keccak256(Bytes.readBounded(prepared[hash], MAXIMUM)) != hash) {
                revert V.InvalidMetadataRecord();
            }
            return hash;
        }
        for (uint256 offset; offset < payload.length; offset += 8192) {
            uint256 end = offset + 8192;
            if (end > payload.length) end = payload.length;
            Store(store).publishChunk(payload[offset:end]);
        }
        Bytes.retainBounded(prepared[hash], store, payload, MAXIMUM);
    }

    function candidateBytes(
        mapping(bytes32 => Bytes.Manifest) storage prepared,
        address store,
        bytes32 hash,
        uint256 cap
    ) public view returns (bytes memory) {
        if (prepared[hash].byteLength == 0) return Documents.chunk(store, hash, cap);
        return Bytes.readBounded(prepared[hash], MAXIMUM);
    }

    function index(
        mapping(bytes32 => Bytes.Manifest) storage prepared,
        mapping(uint256 => Host.Pointer[]) storage pointers,
        mapping(uint256 => mapping(bytes32 => bool)) storage seen,
        address store,
        bytes32 storeHash,
        uint256 cid,
        bytes32 family,
        bytes calldata payload
    ) public {
        if (payload.length <= 8192) {
            // Exact original one-chunk publication, pointer key and row semantics.
            (bytes32 hash, address pointer) = Store(store).publishChunk(payload);
            add(pointers, seen, cid, family, hash, pointer);
            return;
        }
        bytes32 hash = prepare(prepared, store, storeHash, payload);
        Bytes.Manifest storage m = prepared[hash];
        for (uint256 i; i < m.pointers.length; ++i) {
            add(pointers, seen, cid, family, m.chunkHashes[i], m.pointers[i]);
        }
    }

    function add(
        mapping(uint256 => Host.Pointer[]) storage pointers,
        mapping(uint256 => mapping(bytes32 => bool)) storage seen,
        uint256 cid,
        bytes32 family,
        bytes32 hash,
        address pointer
    ) private {
        bytes32 key = keccak256(abi.encode(family, hash));
        if (!seen[cid][key]) {
            seen[cid][key] = true;
            pointers[cid].push(Host.Pointer(pointer, family, hash));
        }
    }

    function payload(
        mapping(bytes32 => Bytes.Manifest) storage prepared,
        Host.StoredRecord storage record,
        address store,
        bytes32 storeHash,
        uint256 cap
    ) public view returns (address, bytes memory) {
        bytes32 hash = bytes32(record.record.contentHash.digest);
        if (prepared[hash].byteLength == 0) {
            return StreamCollectionManifestExecution.payload(record, store, storeHash, cap);
        }
        return (prepared[hash].pointers[0], Bytes.readBounded(prepared[hash], MAXIMUM));
    }

    function count(
        mapping(bytes32 => Bytes.Manifest) storage prepared,
        address store,
        bytes32 storeHash,
        bytes32 hash
    ) public view returns (uint256) {
        if (prepared[hash].byteLength != 0) return prepared[hash].pointers.length;
        code(store, storeHash);
        (address pointer,) = Store(store).chunk(hash);
        return pointer == address(0) ? 0 : 1;
    }

    function chunk(
        mapping(bytes32 => Bytes.Manifest) storage prepared,
        address store,
        bytes32 storeHash,
        bytes32 hash,
        uint256 at
    ) public view returns (address, bytes32) {
        Bytes.Manifest storage m = prepared[hash];
        if (m.byteLength != 0) {
            if (at >= m.pointers.length) revert V.InvalidMetadataRecord();
            return (m.pointers[at], m.chunkHashes[at]);
        }
        code(store, storeHash);
        (address pointer,) = Store(store).chunk(hash);
        if (at != 0 || pointer == address(0)) revert V.InvalidMetadataRecord();
        return (pointer, hash);
    }

    function code(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert V.MetadataDependencyChanged(target);
        }
    }
}
