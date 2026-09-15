// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArchivalTypes as A } from "./StreamArchivalTypes.sol";

interface IStreamArchivalCoverage {
    event ArchivalEnvelopeRecorded(
        uint16 schemaVersion, bytes32 indexed envelopeHash, A.Envelope envelope
    );
    event ArchivalFamilyRecorded(
        uint16 schemaVersion,
        bytes32 indexed familyRecordHash,
        bytes32 indexed actionId,
        string name,
        A.Family family
    );
    event ArchivalFamilyStatusChanged(
        uint16 schemaVersion,
        bytes32 indexed familyRecordHash,
        bytes32 indexed actionId,
        uint8 oldStatus,
        uint8 newStatus,
        uint64 revision
    );
    event ArchivalReceiptRecorded(
        uint16 schemaVersion,
        bytes32 indexed receiptRecordHash,
        bytes32 indexed envelopeHash,
        bytes32 indexed familyRecordHash,
        A.ReceiptTerms terms
    );
    event ArchivalFixityRecorded(
        uint16 schemaVersion,
        bytes32 indexed fixityRecordHash,
        bytes32 indexed receiptRecordHash,
        A.FixityTerms terms
    );
    event ArchivalCoverageRecorded(
        uint16 schemaVersion,
        bytes32 indexed coverageRecordHash,
        bytes32 indexed envelopeHash,
        A.CoverageFacts facts
    );

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function core() external view returns (address);
    function roleRegistry() external view returns (address);
    function checkpointVerifier() external view returns (address);
    function profileHash() external view returns (bytes32);
    function familyRevision(bytes32 familyRecordHash) external view returns (uint64);
    function recordEnvelope(A.Envelope calldata envelope, bytes calldata payload)
        external
        returns (bytes32);
    function envelope(bytes32 envelopeHash) external view returns (A.Envelope memory, bytes memory);
    function familyRegistrationContext(string calldata name, A.Family calldata family)
        external
        view
        returns (bytes32 recordHash, bytes32 scopeHash, bytes32 oldHash, bytes32 newHash);
    function admitFamily(string calldata name, A.Family calldata family) external returns (bytes32);
    function familyStatusContext(bytes32 familyRecordHash, uint8 newStatus)
        external
        view
        returns (bytes32 scopeHash, bytes32 oldHash, bytes32 newHash);
    function setFamilyStatus(bytes32 familyRecordHash, uint8 newStatus) external;
    function family(bytes32 familyRecordHash) external view returns (A.Family memory, uint8 status);
    function possessionHash(A.Possession calldata possession) external view returns (bytes32);
    function receiptDigest(A.ReceiptTerms calldata terms) external view returns (bytes32);
    function recordReceipt(
        A.ReceiptTerms calldata terms,
        bytes calldata storageIdentifier,
        bytes calldata signature
    ) external returns (bytes32);
    function receipt(bytes32 receiptRecordHash)
        external
        view
        returns (A.ReceiptTerms memory, bytes memory storageIdentifier, bytes memory signature);
    function fixityDigest(A.FixityTerms calldata terms) external view returns (bytes32);
    function recordFixity(A.FixityTerms calldata terms, bytes calldata signature)
        external
        returns (bytes32);
    function fixity(bytes32 fixityRecordHash)
        external
        view
        returns (A.FixityTerms memory, bytes memory signature);
    function latestFixity(bytes32 receiptRecordHash) external view returns (bytes32);
    function recordCoverage(bytes32 firstReceipt, bytes32 secondReceipt) external returns (bytes32);
    function coverage(bytes32 coverageRecordHash) external view returns (A.CoverageFacts memory);
    /// @notice Validates the current taxonomy, exact receipt/fixity heads and reciprocal artist binding.
    /// @dev This is a validating fixed12-word accessor; zero or stale facts never signal readiness.
    function requireCoverage(bytes32 coverageRecordHash, bytes32 artistId, bytes32 evidenceHash)
        external
        view
        returns (A.CoverageFacts memory);
    function nonceUsed(bytes32 replayKey) external view returns (bool);
}
