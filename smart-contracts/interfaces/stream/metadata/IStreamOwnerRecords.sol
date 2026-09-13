// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "../preservation/IStreamPreservationRecords.sol";

/// @notice Append-only registrar statements authorized by actual current token custody.
/// @dev No operator grant, metadata lock or finality state restricts owner records.
interface IStreamOwnerRecords is IERC165 {
    struct OwnerRecord {
        bytes32 recordType;
        bytes32 subjectId;
        bytes32 schemaId;
        IStreamPreservationRecords.HashRef contentHash;
        string uri;
        bytes payload;
        uint64 effectiveAt;
    }

    struct Receipt {
        uint256 tokenId;
        address owner;
        uint64 recordedAt;
        uint64 recordIndex;
        bytes32 recordChainHash;
        bool relayed;
        bytes32 authorizationDigest;
        uint256 nonce;
        uint64 deadline;
        bytes32 schemaDefinitionHash;
        bytes32 canonicalizationDefinitionHash;
        bytes32 signatureScheme;
        bytes32 signatureBundleHash;
    }

    error InvalidOwnerRecordsConfiguration();
    error InvalidOwnerRecord();
    error OwnerRecordAuthorityRequired(address owner);
    error OwnerRecordNonceUsed(address owner, uint256 nonce);
    error OwnerRecordDeadlineExpired(uint64 deadline);
    error InvalidOwnerRecordSignature(address owner);
    error OwnerRecordParentGas(uint256 available, uint256 required);
    error OwnerRecordDependencyChanged(address target);
    error OwnerRecordReadFailed(address target);
    error OwnerRecordDefinitionUnavailable(bytes32 id);
    error OwnerRecordUnknown(bytes32 hash);
    error OwnerRecordExists(bytes32 hash);
    error OwnerRecordGovernanceRequired();

    event OwnerRecordRecorded(
        uint256 indexed tokenId,
        bytes32 indexed recordType,
        address indexed owner,
        OwnerRecord record,
        bytes32 recordHash,
        bytes32 recordChainHash,
        bool relayed,
        uint16 schemaVersion
    );
    event OwnerRecordNonceRevoked(
        address indexed owner, uint256 indexed nonce, bool relayed, uint16 schemaVersion
    );
    event OwnerRecordTypeAdmitted(
        bytes32 indexed recordType, bytes32 indexed actionId, uint16 schemaVersion
    );

    function core() external view returns (address);
    function schemaRegistry() external view returns (address);
    function chunkStore() external view returns (address);
    function deriveOwnerSubject(uint256 tokenId) external view returns (bytes32);
    function isOwnerRecordType(bytes32 recordType) external view returns (bool);
    function recordOwnerRecord(uint256 tokenId, OwnerRecord calldata record) external;
    function recordOwnerRecordFor(
        uint256 tokenId,
        OwnerRecord calldata record,
        address owner,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external;
    function ownerRecordDigest(
        uint256 tokenId,
        OwnerRecord calldata record,
        address owner,
        uint256 nonce,
        uint64 deadline
    ) external view returns (bytes32);
    function ownerRecordRevocationDigest(address owner, uint256 nonce, uint64 deadline)
        external
        view
        returns (bytes32);
    function isOwnerRecordNonceUsed(address owner, uint256 nonce) external view returns (bool);
    function revokeOwnerRecordNonce(uint256 nonce) external;
    function revokeOwnerRecordNonceFor(
        address owner,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external;
    function ownerRecord(bytes32 hash) external view returns (OwnerRecord memory, Receipt memory);
    function ownerRecordSignatureBundle(bytes32 hash) external view returns (address, bytes memory);
    function recordHashAt(uint256 tokenId, bytes32 recordType, uint256 index)
        external
        view
        returns (bytes32);
    function recordChainHash(uint256 tokenId, bytes32 recordType)
        external
        view
        returns (bytes32, uint64);
    function latestOwnerRecordHashFor(uint256 tokenId, bytes32 recordType, address owner)
        external
        view
        returns (bytes32);
    function ownerRecordTypeTransition(bytes32 recordType)
        external
        view
        returns (bytes32, bytes32, bytes32);
    function admitOwnerRecordType(bytes32 recordType) external;
}
