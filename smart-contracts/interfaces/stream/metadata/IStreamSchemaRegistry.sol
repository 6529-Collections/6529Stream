// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Immutable interpretation documents and explicit, irreversible retirement status.
/// @dev IDs hash exact versioned names. Canonicalization references resolve an immutable
///      definition, never a mutable latest-version head. Retired definitions remain readable
///      but cannot canonicalize new document registrations. RAW_BYTES is a permanent bootstrap.
interface IStreamSchemaRegistry is IERC165 {
    enum DocumentKind {
        SCHEMA,
        CANONICALIZATION,
        CATALOG,
        DEPENDENCY
    }
    enum DocumentStatus {
        ACTIVE,
        DEPRECATED,
        ARCHIVED
    }

    struct DocumentSpec {
        string name;
        DocumentKind kind;
        bytes32 contentHash;
        bytes32 canonicalizationId;
        bytes32 supersedesId;
        string uri;
        uint32 totalBytes;
    }

    struct DocumentView {
        bool exists;
        DocumentStatus status;
        bytes32 declarationHash;
        DocumentSpec specification;
        bytes32[] chunkHashes;
    }

    error InvalidDocument();
    error DocumentAlreadyRegistered(bytes32 documentId);
    error DocumentUnknown(bytes32 documentId);
    error DocumentHashMismatch(bytes32 expected, bytes32 actual);
    error InvalidCanonicalization(bytes32 canonicalizationId);
    error InvalidDocumentPredecessor(bytes32 predecessor);
    error InvalidDocumentStatus();
    error UnauthorizedDocumentGovernance();
    error InvalidDocumentScope(uint256 scopeKey);

    event DocumentRegistered(
        uint16 schemaVersion,
        bytes32 indexed documentId,
        bytes32 indexed contentHash,
        bytes32 indexed actionId,
        bytes32 declarationHash,
        DocumentSpec specification,
        bytes32[] chunkHashes
    );
    event DocumentStatusChanged(
        uint16 schemaVersion,
        bytes32 indexed documentId,
        DocumentStatus previous,
        DocumentStatus next,
        bytes32 indexed actionId
    );

    function governanceAuthority() external view returns (address);
    function chunkStore() external view returns (address);
    function registerDocument(DocumentSpec calldata specification, bytes32[] calldata chunkHashes)
        external
        returns (bytes32 documentId);
    function setDocumentStatus(bytes32 documentId, DocumentStatus next) external;
    function document(bytes32 documentId) external view returns (DocumentView memory);
    function documentBytes(bytes32 documentId) external view returns (bytes memory);
    function documentCount() external view returns (uint256);
    function documentIdAt(uint256 index) external view returns (bytes32);
    function payloadPointerCount(uint256 scopeKey) external view returns (uint256);
    /// @dev Global scopeKey=0; accepted chunks deduplicate by (document kind, chunk hash).
    ///      Per-document chunkHashes preserve ordering and repetitions for reconstruction.
    function payloadPointerAt(uint256 scopeKey, uint256 index)
        external
        view
        returns (address pointer, bytes32 payloadFamily, bytes32 contentHash);
    function registrationTransition(
        DocumentSpec calldata specification,
        bytes32[] calldata chunkHashes
    ) external view returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash);
    function statusTransition(bytes32 documentId, DocumentStatus next)
        external
        view
        returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash);
}
