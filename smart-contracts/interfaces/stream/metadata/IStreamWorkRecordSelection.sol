// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./StreamWorkRecordTypes.sol";
import "../preservation/IStreamPreservationRecords.sol";
import "../artist/StreamArtistRecordPublicationTypes.sol";

/// @notice Explicit current WORK evidence, distinct from per-author append-only dossiers.
interface IStreamWorkRecordSelection is IERC165 {
    enum AdoptionMode {
        ARTIST_RECORD_ADOPTION,
        CURATOR_GRANT
    }

    struct Association {
        bytes32 artistId;
        bytes32 bindingHash;
        uint64 generation;
        bytes32 identityRecordHash;
    }

    /// @dev Entire original record and supported meaning are untrusted until hash/receipt joins.
    struct Witness {
        IStreamPreservationRecords.CollectionRecord original;
        StreamWorkRecordTypes.Description description;
    }

    struct Selection {
        bytes32 recordHash;
        bytes32 predecessor;
        bytes32 payloadHash;
        address submitter;
        AdoptionMode mode;
        uint256 grantScope;
        uint64 grantRevision;
        uint64 revision;
        uint64 recordIndex;
        bytes32 recordChainHash;
        uint64 selectedAt;
        uint8 selectorAuthorizationClass;
        address recorder;
        uint8 recorderAuthorizationClass;
        StreamWorkRecordTypes.Form form;
        StreamWorkRecordTypes.CreatorKind creatorKind;
        Association creatorAssociation;
        StreamArtistRecordPublicationTypes.Evidence artistPublication;
        bytes32 artistPublicationEvidenceHash;
        bytes32 catalogId;
        bytes32 catalogHash;
        bytes32 selectionHash;
    }

    error InvalidWorkConfiguration();
    error WorkDependencyChanged(address dependency);
    error WorkDependencyReadFailed(address dependency);
    error WorkHostNotSelected();
    error WorkDefinitionUnavailable(bytes32 documentId);
    error InvalidWorkRecord(bytes32 recordHash);
    error WorkSelectionAuthorityRequired();
    error WorkSelectionConflict();
    error WorkAssociationChanged();

    event WorkRecordSelected(
        uint256 indexed collectionId,
        bytes32 indexed subjectId,
        bytes32 indexed recordHash,
        Selection selection
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

    /// @notice Current CURATOR class3/8 grant may select an eligible artist or curator original.
    function selectCurrent(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        Witness calldata witness
    ) external returns (Selection memory);

    /// @notice Anyone may deliver a recorded artist statement advancing its exact signed predecessor.
    /// @dev This explicit adoption rule is not a fresh signature authorization. Original op24 is
    ///      already consumed; its nonce/deadline and original signer are never changed or revalidated.
    function adoptArtistRecord(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        Witness calldata witness
    ) external returns (Selection memory);

    /// @notice Durable raw current/head receipt; does not apply today's consuming eligibility.
    function currentWork(uint256 collectionId, bytes32 subjectId)
        external
        view
        returns (Selection memory);
    function workSelectionAt(uint256 collectionId, bytes32 subjectId, uint64 revision)
        external
        view
        returns (Selection memory);

    /// @notice Require exact head/revision and current definitions/deployment/association eligibility.
    function requireCurrent(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 expectedRecord,
        uint64 expectedRevision
    ) external view returns (Selection memory);
}
