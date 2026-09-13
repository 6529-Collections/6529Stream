// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "../preservation/IStreamPreservationRecords.sol";

/// @notice Permanent, permissionless, signer-attributed independent preservation records.
/// @dev No record is an operator endorsement or a renderer input. All scope keys are collection
///      IDs, including zero for deployment-wide records. Revocation consumes a nonce, not a record.
interface IStreamCollectionAttestations is IERC165 {
    enum SubjectKind {
        COLLECTION,
        TOKEN,
        MEDIA
    }

    struct Subject {
        SubjectKind kind;
        uint256 collectionId;
        uint256 tokenId;
        bytes32 objectId;
    }

    /// @dev Exact permanent StreamIndependentPreservationRecord EIP-712 field order.
    struct IndependentRecord {
        address attestor;
        uint256 scopeKey;
        bytes32 subjectId;
        bytes32 recordType;
        bytes32 schemaId;
        uint16 algorithmId;
        bytes digest;
        bytes32 canonicalizationId;
        string uri;
        bytes payload;
        uint64 effectiveAt;
        uint256 nonce;
        uint64 deadline;
    }

    struct Receipt {
        uint256 scopeKey;
        address attestor;
        uint8 authorizationClass;
        uint64 recordedAt;
        uint64 recordIndex;
        bytes32 recordChainHash;
        bytes32 authorizationDigest;
        uint256 nonce;
        uint64 deadline;
        bytes32 schemaDefinitionHash;
        bytes32 canonicalizationDefinitionHash;
    }

    error InvalidAttestationConfiguration();
    error InvalidIndependentRecord();
    error InvalidIndependentSubject();
    error IndependentNonceUsed(address attestor, uint256 nonce);
    error IndependentDeadlineExpired(uint64 deadline);
    error InvalidIndependentSignature(address attestor);
    error IndependentParentGas(uint256 available, uint256 required);
    error IndependentDependencyChanged(address target);
    error IndependentReadFailed(address target);
    error IndependentDefinitionUnavailable(bytes32 id);
    error IndependentRecordUnknown(bytes32 hash);
    error IndependentRecordExists(bytes32 hash);

    event IndependentPreservationRecordRecorded(
        uint256 indexed scopeKey,
        bytes32 indexed recordType,
        bytes32 indexed subjectId,
        IStreamPreservationRecords.CollectionRecord record,
        bytes32 recordHash,
        bytes32 recordChainHash,
        address attestor,
        bytes32 authorizationClass,
        uint16 schemaVersion
    );
    event IndependentAttestorNonceRevoked(
        address indexed attestor,
        uint256 indexed nonce,
        address indexed relayer,
        uint16 schemaVersion
    );

    function core() external view returns (address);
    function schemaRegistry() external view returns (address);
    function chunkStore() external view returns (address);
    function isIndependentRecordType(bytes32 recordType) external pure returns (bool);
    function deriveSubject(Subject calldata subject) external view returns (bytes32);
    function independentRecordDigest(IndependentRecord calldata record)
        external
        view
        returns (bytes32);
    function independentRevocationDigest(address attestor, uint256 nonce, uint64 deadline)
        external
        view
        returns (bytes32);
    function recordIndependentPreservation(
        Subject calldata subject,
        IndependentRecord calldata record,
        bytes calldata signature
    ) external returns (bytes32 recordHash);
    function revokeIndependentAttestorNonce(uint256 nonce) external;
    function revokeIndependentAttestorNonceFor(
        address attestor,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external;
    function isIndependentAttestorNonceUsed(address attestor, uint256 nonce)
        external
        view
        returns (bool);
    function collectionRecord(bytes32 recordHash)
        external
        view
        returns (IStreamPreservationRecords.CollectionRecord memory record, Receipt memory receipt);
    function recordSubject(bytes32 recordHash) external view returns (Subject memory);
    function recordPayload(bytes32 recordHash)
        external
        view
        returns (address pointer, bytes memory payload);
    function recordSignatureBundle(bytes32 recordHash)
        external
        view
        returns (address pointer, bytes memory bundle);
    function collectionRecordPayload(uint256 scopeKey, bytes32 recordType, bytes32 subjectId)
        external
        view
        returns (address pointer, bytes memory payload);
    function latestCollectionRecordHashFor(
        uint256 scopeKey,
        bytes32 recordType,
        bytes32 subjectId,
        address recorder
    ) external view returns (bytes32);
    function recordChainHash(uint256 scopeKey, bytes32 recordType)
        external
        view
        returns (bytes32, uint64);
    function recordHashAt(uint256 scopeKey, bytes32 recordType, uint256 index)
        external
        view
        returns (bytes32);
    function payloadPointerCount(uint256 scopeKey) external view returns (uint256);
    function payloadPointerAt(uint256 scopeKey, uint256 index)
        external
        view
        returns (address, bytes32, bytes32);
}
