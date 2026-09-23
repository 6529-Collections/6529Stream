// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import { StreamSchemaDocumentStore as Store } from "../metadata/StreamSchemaDocumentStore.sol";

/// @notice Exact immutable-carrier verification and adoption in the original delegate host.
/// @dev No arbitrary external manifest is accepted. The host supplies compiler-owned storage
/// selected from its freshly authenticated input. Shared byte readers and public getters are unchanged.
library StreamReferenceModeManifestAdoption {
    function requireIntact(Bytes.Manifest storage saved) public view returns (bytes32) {
        return _verify(saved, address(0));
    }

    /// @notice Authenticate the same original Store relation without duplicating storage arrays.
    function requireStoreIntact(Bytes.Manifest storage saved, address store)
        public
        view
        returns (bytes32)
    {
        return _verify(saved, store);
    }

    function adopt(
        Bytes.Manifest storage destination,
        Bytes.Manifest storage original,
        address store
    ) public {
        if (destination.byteLength != 0) {
            revert Bytes.InvalidSnapshotManifest();
        }
        bytes32 hash = _verify(original, store);
        // The original Store is immutable and read-only. Copy only after every original carrier
        // and whole-byte commitment has passed. A later failure rolls both manifests back.
        for (uint256 i; i < original.pointers.length; ++i) {
            destination.pointers.push(original.pointers[i]);
            destination.chunkHashes.push(original.chunkHashes[i]);
        }
        destination.contentHash = hash;
        destination.byteLength = original.byteLength;
    }

    function _verify(Bytes.Manifest storage saved, address store)
        private
        view
        returns (bytes32 hash)
    {
        uint256 length = saved.byteLength;
        uint256 count = saved.pointers.length;
        if (
            length == 0 || length > 524288 || count != (length + 8191) / 8192
                || saved.chunkHashes.length != count
        ) revert Bytes.InvalidSnapshotManifest();
        bytes memory whole = new bytes(length);
        bytes memory prefix = new bytes(1);
        for (uint256 i; i < count; ++i) {
            uint256 offset = i * 8192;
            uint256 size = length - offset;
            if (size > 8192) size = 8192;
            address pointer = saved.pointers[i];
            bytes32 expected = saved.chunkHashes[i];
            if (store != address(0)) {
                (address registered, uint32 registeredLength) = Store(store).chunk(expected);
                if (registered == address(0) || registeredLength != size) {
                    revert Bytes.SnapshotChunkUnavailable(expected);
                }
                // Original retain takes this pointer from the immutable Store. Adopting a saved
                // pointer must establish the same relation, not merely equal content elsewhere.
                if (registered != pointer) revert Bytes.SnapshotChunkChanged(pointer);
            }
            if (pointer.code.length != size + 1) revert Bytes.SnapshotChunkChanged(pointer);
            bytes32 actual;
            assembly ("memory-safe") {
                extcodecopy(pointer, add(prefix, 32), 0, 1)
                let dest := add(add(whole, 32), offset)
                extcodecopy(pointer, dest, 1, size)
                actual := keccak256(dest, size)
            }
            if (prefix[0] != 0 || actual != expected) revert Bytes.SnapshotChunkChanged(pointer);
        }
        hash = keccak256(whole);
        if (hash != saved.contentHash) revert Bytes.InvalidSnapshotManifest();
    }
}
