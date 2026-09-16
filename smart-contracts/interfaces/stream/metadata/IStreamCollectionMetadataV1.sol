// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "../preservation/IStreamPreservationRecords.sol";

/// @notice Current collection record bytes, attributed history and governed family admission.
/// @dev The generic record tuple and hash preimage are shared with preservation records.
///      Payload publication alone confers no record authority or JSON-schema validation.
interface IStreamCollectionMetadataV1 is IERC165 {
    struct RecordPolicy {
        bytes32 family;
        uint16 authorizationMask;
        bool admitted;
    }

    struct RecordReceipt {
        uint256 collectionId;
        address recorder;
        uint8 authorizationClass;
        uint64 recordedAt;
        uint64 recordIndex;
        bytes32 recordChainHash;
        bytes32 schemaDefinitionHash;
        bytes32 canonicalizationDefinitionHash;
        bytes32 artistAuthorization;
    }

    error InvalidMetadataConfiguration();
    error InvalidMetadataRecord();
    error UnknownMetadataSubject(bytes32 subjectId);
    error UnknownMetadataRecord(bytes32 recordHash);
    error DuplicateMetadataRecord(bytes32 recordHash);
    error MetadataSchemaUnavailable(bytes32 schemaId);
    error MetadataAuthorityRequired();
    error MetadataHostNotSelected();
    error MetadataDependencyChanged(address dependency);
    error MetadataReadFailed(address target);
    error MetadataAuthorizationConsumed(bytes32 authorization);

    /// @dev authorizationClass is the zero-extended existing numeric class (1 through 8).
    event CollectionRecordRecorded(
        uint256 indexed collectionId,
        bytes32 indexed recordType,
        bytes32 indexed subjectId,
        IStreamPreservationRecords.CollectionRecord record,
        bytes32 recordHash,
        bytes32 recordChainHash,
        address recorder,
        bytes32 authorizationClass,
        uint16 schemaVersion
    );
    event MetadataRecordTypeAdmitted(
        bytes32 indexed recordType, RecordPolicy policy, bytes32 indexed actionId
    );
    event MetadataFamilyWriterChanged(
        uint256 indexed collectionId,
        bytes32 indexed family,
        address indexed account,
        uint8 authorizationClass,
        bool enabled,
        uint64 revision,
        bytes32 actionId
    );
    event ArtistRecordAuthorizationConsumed(
        bytes32 indexed authorization,
        bytes32 indexed recordHash,
        address indexed recorder,
        address relayer
    );

    function core() external view returns (address);
    function schemaRegistry() external view returns (address);
    function chunkStore() external view returns (address);
    function recordPolicy(bytes32 recordType) external view returns (RecordPolicy memory);
    function recordTypeCount() external view returns (uint256);
    function recordTypeAt(uint256 index) external view returns (bytes32);
    function admitRecordType(bytes32 recordType, bytes32 family, uint16 authorizationMask) external;
    function recordTypeTransition(bytes32 recordType, bytes32 family, uint16 authorizationMask)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function setFamilyWriter(
        uint256 collectionId,
        bytes32 family,
        uint8 authorizationClass,
        address account,
        bool enabled
    ) external;
    function familyWriter(
        uint256 collectionId,
        bytes32 family,
        uint8 authorizationClass,
        address account
    ) external view returns (bool enabled, uint64 revision);
    function familyWriterTransition(
        uint256 collectionId,
        bytes32 family,
        uint8 authorizationClass,
        address account,
        bool enabled
    ) external view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    /// @notice Index a minted or burned token's canonical subject; this grants no write authority.
    function registerTokenSubject(uint256 tokenId) external returns (bytes32 subjectId);
    function recordCollectionRecordWithPayload(
        uint256 collectionId,
        IStreamPreservationRecords.CollectionRecord calldata record,
        bytes calldata payload
    ) external returns (bytes32);
    function recordArtistCollectionRecordWithPayload(
        address recorder,
        uint256 collectionId,
        IStreamPreservationRecords.CollectionRecord calldata record,
        bytes calldata payload,
        bytes32 authorization
    ) external returns (bytes32);
    function deriveCollectionRecordHashFor(
        address recorder,
        uint256 collectionId,
        IStreamPreservationRecords.CollectionRecord calldata record
    ) external view returns (bytes32);
    function collectionRecord(bytes32 recordHash)
        external
        view
        returns (
            IStreamPreservationRecords.CollectionRecord memory record,
            RecordReceipt memory receipt
        );
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
    function recordPayload(bytes32 recordHash)
        external
        view
        returns (address pointer, bytes memory payload);
    function recordChainHash(uint256 collectionId, bytes32 recordType)
        external
        view
        returns (bytes32 chainHash, uint64 recordCount);
    function recordHashAt(uint256 collectionId, bytes32 recordType, uint256 index)
        external
        view
        returns (bytes32);
    function payloadPointerCount(uint256 collectionId) external view returns (uint256);
    function payloadPointerAt(uint256 collectionId, uint256 index)
        external
        view
        returns (address pointer, bytes32 payloadFamily, bytes32 contentHash);
}
