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
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";

/// @notice Original full generic record, original receipt and exact STOP-retained payload.
/// @dev The selected record hash comes only from the fixed current original-record consumer.
library StreamPreservationOriginalReads {
    function items(
        S.Dependencies memory d,
        S.Context memory c,
        bytes32 hash,
        bytes32 expectedPayload
    ) public view returns (T.Item[] memory result) {
        IO.pin(d.targets[1], d.codeHashes[1]);
        bytes memory raw = IO.read(
            d.targets[1],
            abi.encodeCall(IStreamCollectionMetadataV1.collectionRecord, (hash)),
            16384,
            d.sourceGas
        );
        (
            IStreamPreservationRecords.CollectionRecord memory record,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = abi.decode(
            raw,
            (IStreamPreservationRecords.CollectionRecord, IStreamCollectionMetadataV1.RecordReceipt)
        );
        IO.canonical(d.targets[1], raw, abi.encode(record, receipt));
        if (
            receipt.collectionId != c.collectionId || record.subjectId != c.subject
                || receipt.recorder == address(0) || receipt.recordedAt == 0
                || receipt.recordChainHash == 0 || record.contentHash.algorithm != 1
                || record.contentHash.canonicalizationId != keccak256("RFC8785_JCS")
                || keccak256(record.contentHash.digest)
                    != keccak256(abi.encodePacked(expectedPayload))
        ) revert T.InvalidInventoryItem();
        if (
            IO.word(
                        d.targets[1],
                        abi.encodeCall(
                            IStreamCollectionMetadataV1.deriveCollectionRecordHashFor,
                            (receipt.recorder, c.collectionId, record)
                        ),
                        d.sourceGas
                    ) != hash
                || IO.word(
                        d.targets[1],
                        abi.encodeCall(
                            IStreamCollectionMetadataV1.recordHashAt,
                            (c.collectionId, record.recordType, receipt.recordIndex)
                        ),
                        d.readGas
                    ) != hash
        ) revert T.InvalidInventoryItem();
        // Supported original selected publishers have no opaque detached generic signature.
        // Their op24 authorization is separately recovered from the Artist Archive; a future
        // signature-bearing generic profile must provide its actual complete bundle reader.
        if (
            record.signatureScheme != 0 || record.signatureHash.algorithm != 0
                || record.signatureHash.canonicalizationId != 0
                || record.signatureHash.digest.length != 0
        ) revert T.InvalidInventoryItem();
        result = new T.Item[](2);
        result[0] = Items.bytesItem(
            T.Kind.NATIVE_BYTES,
            keccak256("ORIGINAL_METADATA_RECORD_AND_RECEIPT"),
            d.targets[1],
            hash,
            0,
            raw
        );
        result[1] = _payload(d, hash, expectedPayload);
        result[1].schemaId = record.schemaId;
    }

    function _payload(S.Dependencies memory d, bytes32 hash, bytes32 expectedPayload)
        private
        view
        returns (T.Item memory result)
    {
        bytes memory raw = IO.read(
            d.targets[1],
            abi.encodeCall(IStreamCollectionMetadataV1.recordPayload, (hash)),
            8288,
            d.sourceGas
        );
        (address pointer, bytes memory payload) = abi.decode(raw, (address, bytes));
        IO.canonical(d.targets[1], raw, abi.encode(pointer, payload));
        if (
            payload.length == 0 || payload.length > 8192 || keccak256(payload) != expectedPayload
                || pointer.code.length != payload.length + 1
        ) revert T.InvalidInventoryItem();
        bytes memory code = pointer.code;
        if (code[0] != 0 || keccak256(code) != keccak256(bytes.concat(hex"00", payload))) {
            revert T.InvalidInventoryItem();
        }
        result = Items.bytesItem(
            T.Kind.ORIGINAL_PAYLOAD,
            keccak256("ORIGINAL_TYPED_METADATA_PAYLOAD"),
            d.targets[1],
            hash,
            0,
            payload
        );
        result.canonicalizationId = keccak256("RFC8785_JCS");
        result.provenanceHash = keccak256(abi.encode(pointer, pointer.codehash));
    }
}
