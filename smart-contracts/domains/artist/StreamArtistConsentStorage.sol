// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistConsentState.sol";
import {
    IStreamArtistEconomicsEvidence
} from "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import "./StreamArtistCurrentAuthorityFacts.sol";
import "./StreamArtistContentHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";

import "./StreamArtistOwner.sol";
import "./StreamArtistSanctionState.sol";
import "./StreamArtistConsentReadEncoding.sol";
import "./StreamArtistRecoveryApprovalState.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Exact common storage owned by Consent and addressed by its fixed writer.
abstract contract StreamArtistConsentStorage is
    StreamArtistOwner,
    IStreamArtistSanctionEvents,
    IStreamArtistRecoveryApprovalEvents
{
    mapping(bytes32 => bytes32) internal _policies;
    mapping(bytes32 => bytes32) internal _economics;
    mapping(uint256 => T.RatificationRecord) internal _ratifications;
    mapping(bytes32 => T.RatificationRecord) internal _ratificationRecords;
    mapping(bytes32 => T.RoyaltyFreezeRecord) internal _royaltyFreezes;
    mapping(bytes32 => bytes32) internal _recordDelegation;
    mapping(bytes32 => IStreamArtistContentRecordsOwner.ConsentRecord) internal _contentConsents;
    mapping(bytes32 => bytes32) internal _latestContentConsent;
    mapping(bytes32 => Content.FreezeRecord) internal _contentFreezes;
    mapping(bytes32 => bytes32) internal _latestContentFreeze;
    mapping(bytes32 => Sale.Record) internal _saleRecords;
    mapping(bytes32 => bytes32) internal _latestSaleConsents;
    mapping(bytes32 => IStreamArtistEconomicsEvidence.Association) internal _economicsAssociations;
    mapping(bytes32 => bytes32) internal _associatedEconomicsRecords;
    StreamArtistSanctionState.State internal _sanctions;
    StreamArtistRecoveryApprovalState.State internal _recoveryApprovals;

    event ArtistSaleConsentRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed saleConfigHash,
        address indexed signer,
        bytes32 saleId,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 consentRecordHash
    );

    event ArtistContentConsentRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed familyId,
        address indexed signer,
        bytes32 newStateHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 consentRecordHash
    );

    event ArtistContentFreezeAuthorized(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed signer,
        bytes32[] lockClasses,
        bytes32 expectedStateHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 freezeRecordHash
    );

    event ArtistContentRecordContext(
        uint16 schemaVersion, bytes32 indexed recordHash, address metadataContract, bytes32 artistId
    );

    event ArtistRecordDelegation(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        bytes32 indexed delegationRecordHash,
        bytes32 indexed artistId,
        address resolver,
        bytes32 revenueClass,
        uint8 authorityClass
    );

    event ArtistRoyaltyFreezeAuthorized(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed expectedAssignmentHash,
        address indexed signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 freezeRecordHash
    );

    event ArtistPolicyConsentRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed policyHash,
        address indexed signer,
        bytes32 phaseId,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 consentRecordHash
    );

    event ArtistEconomicsConsentRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed assignmentHash,
        address indexed signer,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 payoutDesignationRecordHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 consentRecordHash
    );

    event ArtistContentRatificationRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed contentStateHash,
        address indexed signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 ratificationRecordHash
    );
    constructor(
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    )
        StreamArtistOwner(
            registry_, coordinator_, archive_, keccak256("domain:consent_finality"), core_, manager_
        )
    { }
}
