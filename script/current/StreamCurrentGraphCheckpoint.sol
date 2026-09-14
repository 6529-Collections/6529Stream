// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable public checkpoint for a resumable current-stack deployment.
/// @dev This records the creating operator and exact ABI payload bytes, never protocol authority.
/// Payload chunks are existing STOP-prefixed immutable byte contracts. Constructor arguments
/// contain only their addresses, avoiding a large argument-inclusive CREATE payload. Consumers
/// must verify this exact runtime, operator, chain, payload hash and every live deployment edge.
contract StreamCurrentGraphCheckpoint {
    uint16 public constant SCHEMA_VERSION = 3;
    uint256 public constant MAX_PAYLOAD_BYTES = 524288;
    address public operator;
    uint256 public deploymentChainId;
    bytes32 public payloadHash;
    uint256 public payloadBytes;
    address[] private _chunks;
    bytes32[] private _chunkHashes;

    error InvalidCheckpoint();
    error CheckpointChunkChanged(uint256 index);

    constructor(address[] memory chunks, bytes32 expectedHash, uint256 expectedBytes) {
        if (
            chunks.length == 0 || chunks.length > 64 || expectedHash == 0 || expectedBytes == 0
                || expectedBytes > MAX_PAYLOAD_BYTES
        ) revert InvalidCheckpoint();
        operator = msg.sender;
        deploymentChainId = block.chainid;
        payloadHash = expectedHash;
        payloadBytes = expectedBytes;
        uint256 total;
        for (uint256 i; i < chunks.length; ++i) {
            bytes memory code = chunks[i].code;
            if (code.length <= 1 || code.length > 8193 || code[0] != 0) revert InvalidCheckpoint();
            total += code.length - 1;
            _chunks.push(chunks[i]);
            _chunkHashes.push(keccak256(code));
        }
        if (total != expectedBytes || keccak256(_read()) != expectedHash) {
            revert InvalidCheckpoint();
        }
    }

    function payload() external view returns (bytes memory) {
        bytes memory result = _read();
        if (keccak256(result) != payloadHash) revert InvalidCheckpoint();
        return result;
    }

    function chunks() external view returns (address[] memory, bytes32[] memory) {
        return (_chunks, _chunkHashes);
    }

    function _read() private view returns (bytes memory result) {
        result = new bytes(payloadBytes);
        uint256 cursor;
        for (uint256 i; i < _chunks.length; ++i) {
            address chunk = _chunks[i];
            bytes memory code = chunk.code;
            if (keccak256(code) != _chunkHashes[i] || code.length <= 1) {
                revert CheckpointChunkChanged(i);
            }
            uint256 length = code.length - 1;
            if (cursor > result.length || length > result.length - cursor) {
                revert InvalidCheckpoint();
            }
            assembly ("memory-safe") { extcodecopy(chunk, add(add(result, 32), cursor), 1, length) }
            cursor += length;
        }
        if (cursor != result.length) revert InvalidCheckpoint();
    }
}
