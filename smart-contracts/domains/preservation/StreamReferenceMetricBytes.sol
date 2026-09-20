// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";

/// @notice Metric-local immutable-byte reads in the caller's memory frame.
/// @dev The compiler-typed storage reference is supplied by the fixed host. This preserves
/// the original read's complete validation and error order; it introduces no new carrier.
library StreamReferenceMetricBytes {
    function read(Bytes.Manifest storage saved) internal view returns (bytes memory payload) {
        uint256 length = saved.byteLength;
        uint256 count = saved.pointers.length;
        if (
            length == 0 || length > 524288 || count != (length + 8191) / 8192
                || saved.chunkHashes.length != count
        ) revert Bytes.InvalidSnapshotManifest();
        payload = new bytes(length);
        // A full original Store chunk plus its STOP prefix. Reuse scratch without changing
        // the range checked for a short final chunk; bytes after that range are irrelevant.
        bytes memory scratch = new bytes(8193);
        for (uint256 i; i < count; ++i) {
            uint256 offset = i * 8192;
            uint256 size = length - offset;
            if (size > 8192) size = 8192;
            address pointer = saved.pointers[i];
            if (pointer.code.length != size + 1) revert Bytes.SnapshotChunkChanged(pointer);
            bytes32 actual;
            assembly ("memory-safe") {
                extcodecopy(pointer, add(scratch, 32), 0, add(size, 1))
                actual := keccak256(add(scratch, 33), size)
            }
            if (scratch[0] != 0 || actual != saved.chunkHashes[i]) {
                revert Bytes.SnapshotChunkChanged(pointer);
            }
            assembly ("memory-safe") {
                extcodecopy(pointer, add(add(payload, 32), offset), 1, size)
            }
        }
        if (keccak256(payload) != saved.contentHash) revert Bytes.InvalidSnapshotManifest();
    }

    function requireIntact(Bytes.Manifest storage saved) internal view returns (bytes32) {
        return keccak256(read(saved));
    }
}
