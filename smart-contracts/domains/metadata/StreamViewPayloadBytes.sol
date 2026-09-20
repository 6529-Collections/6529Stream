// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamSchemaDocumentStore as Store } from "./StreamSchemaDocumentStore.sol";

/// @notice Internal immutable payload carrier validation, with no linked/delegated serving calls.
library StreamViewPayloadBytes {
    function capture(address store, bytes memory raw, V.Source memory s) internal view {
        if (raw.length == 0 || raw.length > V.MAX_PAYLOAD) revert V.InvalidViewAdoption();
        s.payloadHash = keccak256(raw);
        s.payloadBytes = uint32(raw.length);
        uint256 count = (raw.length + 8191) / 8192;
        for (uint256 i; i < count; ++i) {
            uint256 start = i * 8192;
            uint256 n = raw.length - start;
            if (n > 8192) n = 8192;
            bytes32 hash;
            assembly ("memory-safe") { hash := keccak256(add(add(raw, 32), start), n) }
            (address pointer, uint32 size) = Store(store).chunk(hash);
            if (pointer == address(0) || size != n) revert V.ViewAdoptionChunk(pointer);
            verify(pointer, hash, n);
            s.payloadPointers[i] = pointer;
            s.payloadChunkHashes[i] = hash;
        }
    }

    function read(V.Source memory s) internal view returns (bytes memory raw) {
        uint256 length = s.payloadBytes;
        if (length == 0 || length > V.MAX_PAYLOAD || s.payloadHash == 0) revert V.InvalidViewAdoption();
        uint256 count = (length + 8191) / 8192;
        raw = new bytes(length);
        for (uint256 i; i < 5; ++i) {
            if (i >= count) {
                if (s.payloadPointers[i] != address(0) || s.payloadChunkHashes[i] != 0) {
                    revert V.InvalidViewAdoption();
                }
                continue;
            }
            uint256 start = i * 8192;
            uint256 n = length - start;
            if (n > 8192) n = 8192;
            address pointer = s.payloadPointers[i];
            verify(pointer, s.payloadChunkHashes[i], n);
            assembly ("memory-safe") { extcodecopy(pointer, add(add(raw, 32), start), 1, n) }
        }
        if (keccak256(raw) != s.payloadHash) revert V.InvalidViewAdoption();
    }

    function verify(address pointer, bytes32 hash, uint256 size) internal view {
        if (size == 0 || size > 8192 || hash == 0 || pointer.code.length != size + 1) {
            revert V.ViewAdoptionChunk(pointer);
        }
        bytes memory chunk = new bytes(size + 1);
        bytes32 actual;
        assembly ("memory-safe") {
            extcodecopy(pointer, add(chunk, 32), 0, add(size, 1))
            actual := keccak256(add(chunk, 33), size)
        }
        if (chunk[0] != 0 || actual != hash) revert V.ViewAdoptionChunk(pointer);
    }
}
