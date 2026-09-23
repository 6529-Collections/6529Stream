// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../finality/StreamArtworkFinalityTypes.sol";
import { StreamViewAdoptionTypes as V } from "./StreamViewAdoptionTypes.sol";

interface IStreamViewAdoptionRouter {
    event ViewAdopted(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        V.Record record
    );
    function previewViewAdoption(V.Input calldata input, address actor)
        external
        view
        returns (bytes32 familyStateHash, bytes32 sourceHash);
    function adoptView(V.Input calldata input) external returns (bytes32 recordHash);
    function viewAdoptionHead(StreamFinalityScope calldata scope) external view returns (bytes32);
    /// @notice Complete original canonical abi.encode(Record); no current-source assertion.
    function viewAdoptionEncoded(bytes32 recordHash) external view returns (bytes memory);
    /// @notice Direct immutable original record carrier for STATIC consumers. Complete bytes
    /// must still pass code length, STOP, content digest and canonical Record verification.
    function viewAdoptionCarrier(bytes32 recordHash)
        external
        view
        returns (address pointer, bytes32 contentHash, uint32 byteSize);
    function viewAdoptionAggregate(uint256 collectionId) external view returns (V.Aggregate memory);
    function tokenJSONForView(uint256 tokenId, bytes32 scopeId)
        external
        view
        returns (string memory);
    function tokenHTMLForView(uint256 tokenId, bytes32 scopeId)
        external
        view
        returns (string memory);
    function historicalTokenJSONForView(uint256 tokenId, bytes32 recordHash)
        external
        view
        returns (string memory);
    function historicalTokenHTMLForView(uint256 tokenId, bytes32 recordHash)
        external
        view
        returns (string memory);
}
