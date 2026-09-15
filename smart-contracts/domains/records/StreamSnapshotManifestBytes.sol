// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Exact immutable snapshot bytes in the existing permissionless chunk store.
/// @dev Uploading bytes confers no snapshot authority. The fixed host supplies its assembled
///      canonical payload; the caller cannot choose a different chunk inventory.
library StreamSnapshotManifestBytes {
    uint256 internal constant SEGMENT_BYTES = 8192;
    uint256 internal constant MAX_MANIFEST_BYTES = 524288;

    struct Manifest {
        bytes32 contentHash;
        uint32 byteLength;
        address[] pointers;
        bytes32[] chunkHashes;
    }

    error InvalidSnapshotManifest();
    error SnapshotChunkUnavailable(bytes32 chunkHash);
    error SnapshotChunkChanged(address pointer);

    function retain(Manifest storage saved, address store, bytes memory canonical)
        public
        returns (bytes32 hash)
    {
        return retainBounded(saved, store, canonical, MAX_MANIFEST_BYTES);
    }

    function retainBounded(
        Manifest storage saved,
        address store,
        bytes memory canonical,
        uint256 maximum
    ) public returns (bytes32 hash) {
        uint256 length = canonical.length;
        if (saved.byteLength != 0 || maximum > 3000000 || length == 0 || length > maximum) {
            revert InvalidSnapshotManifest();
        }
        hash = keccak256(canonical);
        for (uint256 offset; offset < length; offset += SEGMENT_BYTES) {
            uint256 size = length - offset;
            if (size > SEGMENT_BYTES) size = SEGMENT_BYTES;
            bytes32 chunkHash;
            assembly ("memory-safe") {
                chunkHash := keccak256(add(add(canonical, 32), offset), size)
            }
            (address pointer, uint32 storedLength) =
                StreamSchemaDocumentStore(store).chunk(chunkHash);
            if (pointer == address(0) || storedLength != size) {
                revert SnapshotChunkUnavailable(chunkHash);
            }
            _chunk(pointer, chunkHash, size);
            saved.pointers.push(pointer);
            saved.chunkHashes.push(chunkHash);
        }
        saved.contentHash = hash;
        saved.byteLength = uint32(length);
    }

    function read(Manifest storage saved) public view returns (bytes memory payload) {
        return readBounded(saved, MAX_MANIFEST_BYTES);
    }

    function readBounded(Manifest storage saved, uint256 maximum)
        public
        view
        returns (bytes memory payload)
    {
        uint256 length = saved.byteLength;
        uint256 count = saved.pointers.length;
        if (
            maximum > 3000000 || length == 0 || length > maximum || count != (length + 8191) / 8192
                || saved.chunkHashes.length != count
        ) revert InvalidSnapshotManifest();
        payload = new bytes(length);
        for (uint256 i; i < count; ++i) {
            uint256 offset = i * SEGMENT_BYTES;
            uint256 size = length - offset;
            if (size > SEGMENT_BYTES) size = SEGMENT_BYTES;
            address pointer = saved.pointers[i];
            _chunk(pointer, saved.chunkHashes[i], size);
            assembly ("memory-safe") {
                extcodecopy(pointer, add(add(payload, 32), offset), 1, size)
            }
        }
        if (keccak256(payload) != saved.contentHash) revert InvalidSnapshotManifest();
    }

    function requireIntact(Manifest storage saved) public view returns (bytes32) {
        return keccak256(read(saved));
    }

    function requireIntactBounded(Manifest storage saved, uint256 maximum)
        public
        view
        returns (bytes32)
    {
        return keccak256(readBounded(saved, maximum));
    }

    function _chunk(address pointer, bytes32 hash, uint256 length) private view {
        if (pointer.code.length != length + 1) revert SnapshotChunkChanged(pointer);
        bytes memory raw = new bytes(length + 1);
        assembly ("memory-safe") { extcodecopy(pointer, add(raw, 32), 0, add(length, 1)) }
        bytes32 actual;
        assembly ("memory-safe") { actual := keccak256(add(raw, 33), length) }
        if (raw[0] != 0 || actual != hash) revert SnapshotChunkChanged(pointer);
    }
}
