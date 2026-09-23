// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamGeneralAttestations.sol";
import "../records/StreamSnapshotManifestBytes.sol";

/// @notice Full General payloads using the existing 8192-byte immutable chunk store.
/// @dev Only an admitted host write retains a carrier. Historical reads use retained pointers,
///      never the live Store or schema registry. Small payloads keep their original carrier.
library StreamGeneralAttestationPayloads {
    uint256 internal constant SEGMENT_BYTES = 8192;
    uint256 internal constant MAX_PAYLOAD_BYTES = 24576;

    struct Carrier {
        bool chunked;
        StreamSnapshotManifestBytes.Manifest manifest;
    }

    error InvalidGeneralPayloadCarrier();
    error GeneralPayloadChunkIndexOutOfBounds(uint256 index);

    function retain(Carrier storage saved, address store, bytes calldata payload)
        public
        returns (address firstPointer)
    {
        if (
            saved.chunked || payload.length <= SEGMENT_BYTES || payload.length > MAX_PAYLOAD_BYTES
        ) {
            revert InvalidGeneralPayloadCarrier();
        }
        _empty(saved.manifest);
        for (uint256 offset; offset < payload.length; offset += SEGMENT_BYTES) {
            uint256 end = offset + SEGMENT_BYTES;
            if (end > payload.length) end = payload.length;
            bytes calldata part = payload[offset:end];
            (bytes32 hash, address pointer) = StreamSchemaDocumentStore(store).publishChunk(part);
            if (
                hash != keccak256(part)
                    || pointer.codehash != keccak256(bytes.concat(hex"00", part))
            ) revert InvalidGeneralPayloadCarrier();
        }
        StreamSnapshotManifestBytes.retainBounded(
            saved.manifest, store, payload, MAX_PAYLOAD_BYTES
        );
        saved.chunked = true;
        return saved.manifest.pointers[0];
    }

    function read(Carrier storage saved, address firstPointer, bytes32 expectedHash)
        public
        view
        returns (bytes memory payload)
    {
        if (!saved.chunked) {
            // Never reinterpret an incomplete or malformed retained manifest as a small payload.
            _empty(saved.manifest);
            if (firstPointer.code.length == 0 || firstPointer.code.length > SEGMENT_BYTES + 1) {
                revert IStreamGeneralAttestations.GeneralDependencyChanged(firstPointer);
            }
            payload = SSTORE2.read(firstPointer);
            if (
                keccak256(payload) != expectedHash
                    || firstPointer.codehash != keccak256(bytes.concat(hex"00", payload))
            ) revert IStreamGeneralAttestations.GeneralDependencyChanged(firstPointer);
            return payload;
        }
        if (
            saved.manifest.byteLength <= SEGMENT_BYTES || saved.manifest.contentHash != expectedHash
                || saved.manifest.pointers.length == 0 || saved.manifest.pointers[0] != firstPointer
        ) revert InvalidGeneralPayloadCarrier();
        return StreamSnapshotManifestBytes.readBounded(saved.manifest, MAX_PAYLOAD_BYTES);
    }

    function info(Carrier storage saved, address firstPointer, bytes32 expectedHash)
        public
        view
        returns (bytes32 contentHash, uint32 byteLength, uint32 chunkCount)
    {
        bytes memory payload = read(saved, firstPointer, expectedHash);
        return (
            expectedHash,
            uint32(payload.length),
            uint32((payload.length + 8191) / SEGMENT_BYTES)
        );
    }

    function chunkAt(Carrier storage saved, address firstPointer, bytes32 expectedHash, uint256 index)
        public
        view
        returns (bytes32 chunkHash, address pointer, uint32 length)
    {
        (, uint32 byteLength, uint32 count) = info(saved, firstPointer, expectedHash);
        if (index >= count) revert GeneralPayloadChunkIndexOutOfBounds(index);
        if (!saved.chunked) return (expectedHash, firstPointer, byteLength);
        uint256 size = uint256(byteLength) - index * SEGMENT_BYTES;
        if (size > SEGMENT_BYTES) size = SEGMENT_BYTES;
        return (saved.manifest.chunkHashes[index], saved.manifest.pointers[index], uint32(size));
    }

    function _empty(StreamSnapshotManifestBytes.Manifest storage saved) private view {
        if (
            saved.contentHash != 0 || saved.byteLength != 0 || saved.pointers.length != 0
                || saved.chunkHashes.length != 0
        ) revert InvalidGeneralPayloadCarrier();
    }
}
