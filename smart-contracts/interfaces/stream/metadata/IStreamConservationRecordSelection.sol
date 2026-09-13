// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./StreamConservationRecordTypes.sol";
import "../preservation/IStreamPreservationRecords.sol";
import "../artist/StreamArtistRecordPublicationTypes.sol";

/// @notice Explicit conservation heads; original artist voice and estate additions stay separate.
interface IStreamConservationRecordSelection is IERC165 {
    enum RecordKind {
        INTENT,
        INTENT_WAIVER,
        INTERVIEW
    }
    enum PayloadCorrespondence {
        UNVERIFIED_REFERENCE,
        EXACT_JCS_KECCAK256,
        EXACT_JCS_SHA256
    }

    struct Association {
        bytes32 artistId;
        bytes32 bindingHash;
        uint64 generation;
        bytes32 identityRecordHash;
    }

    struct InterviewWitness {
        IStreamPreservationRecords.CollectionRecord original;
        StreamConservationRecordTypes.Interview interview;
    }

    struct IntentWitness {
        IStreamPreservationRecords.CollectionRecord original;
        StreamConservationRecordTypes.Intent intent;
        // Canonically empty for WAIVED. PRESENT authenticates the exact referenced original.
        InterviewWitness interview;
    }

    struct WaiverWitness {
        IStreamPreservationRecords.CollectionRecord original;
        StreamConservationRecordTypes.IntentWaiver waiver;
        InterviewWitness interview;
    }

    struct RecordEvidence {
        bytes32 recordHash;
        RecordKind kind;
        bytes32 payloadHash;
        address recorder;
        uint64 recordedAt;
        uint64 recordIndex;
        bytes32 recordChainHash;
        bytes32 receiptHash;
        StreamArtistRecordPublicationTypes.Evidence publication;
        bytes32 publicationEvidenceHash;
    }

    struct CatalogPin {
        bytes32 documentId;
        bytes32 contentHash;
        uint256 totalBytes;
    }

    struct Selection {
        RecordEvidence record;
        Association association;
        StreamConservationRecordTypes.StatementOrigin origin;
        StreamConservationRecordTypes.InterviewStatus interviewStatus;
        RecordEvidence interview;
        // Commits every full Reference field; its bytes remain in the original parent payload.
        bytes32 interviewArchiveReferenceHash;
        PayloadCorrespondence interviewPayloadCorrespondence;
        bytes32 predecessor;
        address submitter;
        uint64 revision;
        uint64 selectedAt;
        bytes32 catalogsHash;
        bytes32 selectionHash;
    }

    /// @notice Immutable validation of one original interview; this is never a selected head.
    struct PreparedInterview {
        uint256 collectionId;
        bytes32 subjectId;
        Association association;
        RecordEvidence record;
        CatalogPin[] catalogs;
        bytes32 preparationHash;
    }

    struct IntentLock {
        bool locked;
        address locker;
        bytes32 artistId;
        bytes32 identityRecordHash;
        bytes32 bindingHash;
        uint64 bindingGeneration;
        bytes32 recordHash;
        uint64 revision;
        uint64 lockedAt;
    }

    error InvalidConservationConfiguration();
    error ConservationDependencyChanged(address dependency);
    error ConservationDependencyReadFailed(address dependency);
    error ConservationHostNotSelected();
    error ConservationDefinitionUnavailable(bytes32 documentId);
    error InvalidConservationRecord(bytes32 recordHash);
    error ConservationSelectionAuthorityRequired();
    error ConservationSelectionConflict();
    error ConservationAssociationChanged();
    error ConservationHeadLocked();

    event ConservationRecordSelected(
        uint256 indexed collectionId,
        bytes32 indexed subjectId,
        bytes32 indexed recordHash,
        Selection selection
    );
    event ConservationIntentLocked(
        uint256 indexed collectionId, bytes32 indexed subjectId, IntentLock intentLock
    );
    event ConservationInterviewPrepared(
        bytes32 indexed recordHash, address indexed preparer, bytes32 indexed preparationHash
    );

    function core() external view returns (address);
    function metadata() external view returns (address);
    function schemaRegistry() external view returns (address);
    function chunkStore() external view returns (address);
    function deploymentChainId() external view returns (uint256);
    function coreCodeHash() external view returns (bytes32);
    function metadataCodeHash() external view returns (bytes32);
    function schemaRegistryCodeHash() external view returns (bytes32);
    function chunkStoreCodeHash() external view returns (bytes32);

    /// @notice Permissionless adoption of an original op24 statement's exact predecessor.
    /// @dev This never replays a signature or infers new authority from the submitter.
    function adoptIntent(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        IntentWitness calldata witness
    ) external returns (Selection memory);
    function adoptWaiver(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        WaiverWitness calldata witness
    ) external returns (Selection memory);

    function prepareInterview(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        InterviewWitness calldata witness
    ) external returns (PreparedInterview memory);
    function preparedInterview(bytes32 recordHash) external view returns (PreparedInterview memory);
    /// @dev The nested witness.interview must be canonical empty; the signed locator chooses
    /// the exact immutable preparation. Parent CAS, lock and current eligibility still apply.
    function adoptIntentWithPreparedInterview(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        IntentWitness calldata witness
    ) external returns (Selection memory);
    function adoptWaiverWithPreparedInterview(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        WaiverWitness calldata witness
    ) external returns (Selection memory);

    /// @notice Current original artist principal may seal the exact original-voice head once.
    /// @dev Direct-call authorization, including Safe CALL; no relayed signature lane or key freeze.
    function lockArtistIntent(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 expectedHead,
        uint64 expectedRevision
    ) external;
    function intentLock(uint256 collectionId, bytes32 subjectId)
        external
        view
        returns (IntentLock memory);

    /// @notice Local durable receipts do not apply today's dependency or definition eligibility.
    function currentConservation(
        uint256 collectionId,
        bytes32 subjectId,
        StreamConservationRecordTypes.StatementOrigin origin
    ) external view returns (Selection memory);
    function conservationSelectionAt(
        uint256 collectionId,
        bytes32 subjectId,
        StreamConservationRecordTypes.StatementOrigin origin,
        uint64 revision
    ) external view returns (Selection memory);
    function selectionCatalogAt(
        uint256 collectionId,
        bytes32 subjectId,
        StreamConservationRecordTypes.StatementOrigin origin,
        uint64 revision,
        uint256 index
    ) external view returns (CatalogPin memory);
    function selectionCatalogCount(
        uint256 collectionId,
        bytes32 subjectId,
        StreamConservationRecordTypes.StatementOrigin origin,
        uint64 revision
    ) external view returns (uint256);

    /// @notice Exact current head plus current immutable graph/definitions/association eligibility.
    /// @dev Does not reauthorize the original signer or prove archive delivery/participant identity.
    function requireCurrent(
        uint256 collectionId,
        bytes32 subjectId,
        StreamConservationRecordTypes.StatementOrigin origin,
        bytes32 expectedHead,
        uint64 expectedRevision
    ) external view returns (Selection memory);
}
