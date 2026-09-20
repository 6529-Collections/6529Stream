// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import { StreamSchemaDocumentStore as Store } from "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Metric-local transport of facts derived from the complete validated canonical bytes.
/// @dev Only the fixed proof worker derives this call-local payload. The host never accepts
/// caller-selected descriptors; the original immutable bytes and manifest layout are retained.
library StreamReferenceMetricRetention {
    struct Payload {
        bytes32 contentHash;
        uint32 byteLength;
        bytes32[] chunkHashes;
    }

    function describe(bytes memory canonical) internal pure returns (Payload memory payload) {
        uint256 length = canonical.length;
        if (length == 0 || length > 524288) revert Bytes.InvalidSnapshotManifest();
        payload.contentHash = keccak256(canonical);
        payload.byteLength = uint32(length);
        payload.chunkHashes = new bytes32[]((length + 8191) / 8192);
        for (uint256 i; i < payload.chunkHashes.length; ++i) {
            uint256 offset = i * 8192;
            uint256 size = length - offset;
            if (size > 8192) size = 8192;
            bytes32 chunkHash;
            assembly ("memory-safe") {
                chunkHash := keccak256(add(add(canonical, 32), offset), size)
            }
            payload.chunkHashes[i] = chunkHash;
        }
    }

    /// @dev This compiler-typed storage reference and payload come from the fixed host and
    /// its same-call proof, after the original receipt hash is assembled. No new admission
    /// authority is conferred by a descriptor or by permissionless Store publication.
    function retain(Bytes.Manifest storage saved, address store, Payload memory payload)
        public
        returns (bytes32 hash)
    {
        uint256 length = payload.byteLength;
        if (saved.byteLength != 0 || length == 0 || length > 524288) {
            revert Bytes.InvalidSnapshotManifest();
        }
        if (payload.chunkHashes.length != (length + 8191) / 8192) {
            revert Bytes.InvalidSnapshotManifest();
        }
        hash = payload.contentHash;
        // One owned chunk plus its STOP prefix. Short final chunks never hash stale tail bytes.
        bytes memory scratch = new bytes(8193);
        for (uint256 i; i < payload.chunkHashes.length; ++i) {
            uint256 size = length - i * 8192;
            if (size > 8192) size = 8192;
            bytes32 chunkHash = payload.chunkHashes[i];
            (address pointer, uint32 storedLength) = Store(store).chunk(chunkHash);
            if (pointer == address(0) || storedLength != size) {
                revert Bytes.SnapshotChunkUnavailable(chunkHash);
            }
            if (pointer.code.length != size + 1) revert Bytes.SnapshotChunkChanged(pointer);
            bytes32 actual;
            assembly ("memory-safe") {
                extcodecopy(pointer, add(scratch, 32), 0, add(size, 1))
                actual := keccak256(add(scratch, 33), size)
            }
            if (scratch[0] != 0 || actual != chunkHash) {
                revert Bytes.SnapshotChunkChanged(pointer);
            }
            saved.pointers.push(pointer);
            saved.chunkHashes.push(chunkHash);
        }
        saved.contentHash = hash;
        saved.byteLength = uint32(length);
    }
}
