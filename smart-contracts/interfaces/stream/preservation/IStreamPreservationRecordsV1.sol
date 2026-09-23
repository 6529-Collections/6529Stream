// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";
import { IStreamPreservationRecords as P } from "./IStreamPreservationRecords.sol";

/// @notice Attributed, full-byte preservation records. No typed archival/finality assertion is inferred.
interface IStreamPreservationRecordsV1 is IERC165 {
    struct Receipt {
        uint256 collectionId;
        address recorder;
        uint8 authorizationClass;
        bytes32 family;
        uint256 grantCollectionId;
        uint64 grantRevision;
        bytes32 schemaDefinitionHash;
        bytes32 canonicalizationDefinitionHash;
        uint64 recordedAt;
        uint64 recordIndex;
        bytes32 recordChainHash;
    }
    error InvalidPreservationConfiguration();
    error InvalidPreservationRecord();
    error PreservationAuthorityRequired();
    error PreservationHostNotSelected();
    error PreservationDependencyChanged(address target);
    error PreservationReadFailed(address target);
    error UnknownPreservationSubject(bytes32 subject);
    error UnknownPreservationRecord(bytes32 recordHash);
    error DuplicatePreservationRecord(bytes32 recordHash);
    error PreservationIndexOutOfBounds();
    event CollectionRecordRecorded(
        uint256 indexed collectionId,
        bytes32 indexed recordType,
        bytes32 indexed subjectId,
        P.CollectionRecord record,
        bytes32 recordHash,
        bytes32 recordChainHash,
        address recorder,
        bytes32 authorizationClass,
        uint16 schemaVersion
    );
    event PreservationSubjectRegistered(
        uint16 schemaVersion,
        bytes32 indexed subjectId,
        uint256 indexed collectionId,
        uint8 kind,
        uint256 tokenId,
        bytes32 objectId
    );
    function core() external view returns (address);
    function metadataHost() external view returns (address);
    function schemaRegistry() external view returns (address);
    function chunkStore() external view returns (address);
    function registerTokenSubject(uint256 tokenId) external returns (bytes32);
    /// @dev Declares only canonical media identity; it does not prove existence, custody or fixity.
    function registerMediaSubject(uint256 collectionId, bytes32 objectId) external returns (bytes32);
    function subjectIdentity(bytes32 subject)
        external
        view
        returns (uint256 collectionId, uint8 kind, uint256 tokenId, bytes32 objectId);
    function recordCollectionRecordWithPayload(
        uint256 collectionId,
        P.CollectionRecord calldata record,
        bytes calldata payload
    ) external returns (bytes32);
    function deriveCollectionRecordHashFor(
        address recorder,
        uint256 collectionId,
        P.CollectionRecord calldata record
    ) external view returns (bytes32);
    function collectionRecord(bytes32 hash)
        external
        view
        returns (P.CollectionRecord memory, Receipt memory);
    function latestCollectionRecordHashFor(
        uint256 collectionId,
        bytes32 recordType,
        bytes32 subjectId,
        address recorder
    ) external view returns (bytes32);
    function collectionRecordPayload(uint256 collectionId, bytes32 recordType, bytes32 subjectId)
        external
        view
        returns (address pointer, bytes memory payload);
    /// @dev Pointer is the first exact chunk; full payload is reconstructed and hash checked.
    function recordPayload(bytes32 hash)
        external
        view
        returns (address pointer, bytes memory payload);
    function recordPayloadChunkCount(bytes32 hash) external view returns (uint256);
    function recordPayloadChunkAt(bytes32 hash, uint256 index)
        external
        view
        returns (address pointer, bytes32 chunkHash);
    function recordChainHash(uint256 collectionId, bytes32 recordType)
        external
        view
        returns (bytes32, uint64);
    function recordHashAt(uint256 collectionId, bytes32 recordType, uint256 index)
        external
        view
        returns (bytes32);
    function payloadPointerCount(uint256 collectionId) external view returns (uint256);
    /// @dev One accepted exact byte chunk per row; recordPayloadChunkAt retains whole-payload order.
    function payloadPointerAt(uint256 collectionId, uint256 index)
        external
        view
        returns (address pointer, bytes32 family, bytes32 contentHash);
}
