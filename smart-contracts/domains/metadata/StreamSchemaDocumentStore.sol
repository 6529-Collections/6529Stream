// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../libraries/SSTORE2.sol";

/// @notice Permissionless byte publication, with no schema or record authority.
/// @dev Registry acceptance is separate. Unregistered uploads do not enter its document index.
contract StreamSchemaDocumentStore {
    uint256 public constant MAX_CHUNK_BYTES = 8192;

    struct Chunk {
        address pointer;
        uint32 length;
    }
    mapping(bytes32 => Chunk) public chunk;
    error InvalidChunkLength(uint256 length);
    error UnknownChunk(bytes32 hash);
    error ChangedChunk(bytes32 hash);
    event ChunkPublished(bytes32 indexed hash, address indexed pointer, uint32 length);

    function publishChunk(bytes calldata payload) external returns (bytes32 hash, address pointer) {
        if (payload.length == 0 || payload.length > MAX_CHUNK_BYTES) {
            revert InvalidChunkLength(payload.length);
        }
        hash = keccak256(payload);
        pointer = chunk[hash].pointer;
        if (pointer != address(0)) return (hash, pointer);
        pointer = SSTORE2.write(payload);
        chunk[hash] = Chunk(pointer, uint32(payload.length));
        emit ChunkPublished(hash, pointer, uint32(payload.length));
    }

    function readChunk(bytes32 hash) external view returns (bytes memory payload) {
        Chunk memory row = chunk[hash];
        if (row.pointer == address(0)) revert UnknownChunk(hash);
        payload = SSTORE2.read(row.pointer);
        if (payload.length != row.length || keccak256(payload) != hash) revert ChangedChunk(hash);
    }
}
