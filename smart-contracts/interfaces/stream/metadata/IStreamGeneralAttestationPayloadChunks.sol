// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Ordered immutable payload chunks for General Attestations v2.
/// @dev recordPayload still returns the first chunk pointer and the complete payload.
///      Chunk positions may repeat; the collection pointer inventory deduplicates real chunks.
interface IStreamGeneralAttestationPayloadChunks is IERC165 {
    function recordPayloadInfo(bytes32 recordHash)
        external
        view
        returns (bytes32 contentHash, uint32 byteLength, uint32 chunkCount);

    function recordPayloadChunkAt(bytes32 recordHash, uint256 index)
        external
        view
        returns (bytes32 chunkHash, address pointer, uint32 length);
}
