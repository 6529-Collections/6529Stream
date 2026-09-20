// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Complete original Metadata record bytes, independently prepared and later authority-admitted.
/// @dev For a multi-chunk record, recordPayload's address is the first chunk pointer only;
/// it does not contain or commit the entire payload. Its bytes return remains the complete
/// canonical payload. Use the accepted record hash plus these ordered chunk descriptors
/// for state-only reconstruction, and verify both segment hashes and the full payload hash.
/// Preparation is shared by content hash; it never admits a record or advances its chain.
interface IStreamCollectionRecordPayloadChunks is IERC165 {
    event RecordPayloadPrepared(
        uint16 schemaVersion, bytes32 indexed contentHash, uint32 byteLength, uint8 chunkCount
    );
    /// @dev Permissionless bytes only; no record, accepted pointer inventory or Artist authorization.
    function prepareRecordPayload(bytes calldata payload) external returns (bytes32 contentHash);
    function preparedRecordPayloadChunkCount(bytes32 contentHash) external view returns (uint256);
    function preparedRecordPayloadChunkAt(bytes32 contentHash, uint256 index)
        external
        view
        returns (address pointer, bytes32 chunkHash);
    function recordPayloadChunkCount(bytes32 recordHash) external view returns (uint256);
    function recordPayloadChunkAt(bytes32 recordHash, uint256 index)
        external
        view
        returns (address pointer, bytes32 chunkHash);
}
