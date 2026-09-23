// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Self-verifying state carriers, independent of authorization and semantic record chains.
interface IStreamArtistReconstruction is IERC165 {
    error ArtistPayloadUnavailable(bytes32 payloadHash);
    error ArtistPayloadCorrupted(bytes32 expectedHash, bytes32 observedHash);
    error ArtistPayloadIndexOutOfBounds(uint256 index, uint256 count);
    event ArtistStoredPayload(
        uint16 schemaVersion,
        uint256 indexed index,
        bytes32 indexed payloadType,
        bytes32 indexed payloadHash,
        address pointer
    );
    function recordPreimageBytes(bytes32 recordHash) external view returns (bytes memory);
    function storedPayloadCount() external view returns (uint256);
    function storedPayloadAt(uint256 index)
        external
        view
        returns (address pointer, bytes32 payloadType, bytes32 payloadHash);
}

/// @notice Only the immutable Coordinator may register actual owner-carried bytes in Archive.
interface IStreamArtistPayloadArchive is IStreamArtistReconstruction {
    function registerArtistStoredPayload(address pointer, bytes32 payloadType, bytes32 payloadHash)
        external;
}
