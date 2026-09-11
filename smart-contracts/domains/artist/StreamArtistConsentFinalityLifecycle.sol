// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of the onboarding policy/economics/content-ratification records.
/// @dev Does not advertise sanction or recovery operations. Reads return records, not readiness assertions.
contract StreamArtistConsentFinalityLifecycle is StreamArtistOwner {
    mapping(bytes32 => bytes32) private _policies;
    mapping(bytes32 => bytes32) private _economics;
    mapping(uint256 => T.RatificationRecord) private _ratifications;
    mapping(bytes32 => T.RatificationRecord) private _ratificationRecords;
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

    function policyRecord(uint256 collectionId, bytes32 phaseId, bytes32 policyHash)
        external
        view
        returns (bytes32)
    {
        return _policies[keccak256(abi.encode(collectionId, phaseId, policyHash))];
    }

    function economicsRecord(T.EconomicsConsent calldata p) external view returns (bytes32) {
        return _economics[keccak256(abi.encode(p))];
    }

    function firstReleaseRatification(uint256 collectionId)
        external
        view
        returns (T.RatificationRecord memory)
    {
        return _ratifications[collectionId];
    }

    function ratificationRecord(bytes32 record)
        external
        view
        returns (T.RatificationRecord memory)
    {
        return _ratificationRecords[record];
    }

    function recordPolicy(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        _check(c, 14);
        _requireAccepted(b, signer);
        if (p.phaseId == bytes32(0) || p.policyHash == bytes32(0)) revert T.InvalidRecord();
        record =
            StreamArtistHashes.policyRecord(_environment(), p, b.artistId, signer, nonce, _now());
        bytes32 scope = keccak256(abi.encode(p.collectionId, p.phaseId, p.policyHash));
        bytes32 key =
            _consume(keccak256("consent_finality.replay.policy_consent_key"), scope, record);
        _policies[scope] = record;
        _commit(
            c,
            keccak256(abi.encode(b, p, signer, nonce)),
            keccak256(abi.encode(scope, record)),
            keccak256(abi.encode(key, record)),
            record
        );
        emit ArtistPolicyConsentRecorded(
            1, p.collectionId, p.policyHash, signer, p.phaseId, 1, nonce, _now(), record
        );
    }

    function recordEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        T.Payout calldata designation,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        _check(c, 15);
        _requireAccepted(b, signer);
        if (
            designation.account == address(0) || designation.recordHash == bytes32(0)
                || p.resolver == address(0) || p.assignmentHash == bytes32(0)
                || p.revenueClass == bytes32(0) || p.scope != 1 || p.scopeId != p.collectionId
        ) {
            revert T.InvalidRecord();
        }
        record = StreamArtistHashes.economicsRecord(
            _environment(), p, designation.recordHash, b.artistId, signer, nonce, _now()
        );
        bytes32 scope = keccak256(abi.encode(p));
        bytes32 key = _consume(keccak256("consent_finality.replay.consent_key"), scope, record);
        _economics[scope] = record;
        _commit(
            c,
            keccak256(abi.encode(b, p, designation, signer, nonce)),
            keccak256(abi.encode(scope, record)),
            keccak256(abi.encode(key, record)),
            record
        );
        emit ArtistEconomicsConsentRecorded(
            1,
            p.collectionId,
            p.assignmentHash,
            signer,
            p.revenueClass,
            p.scope,
            p.scopeId,
            designation.recordHash,
            1,
            nonce,
            _now(),
            record
        );
    }

    function recordRatification(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        _check(c, 52);
        _requireAccepted(b, signer);
        if (p.metadataContract == address(0) || p.contentStateHash == bytes32(0)) {
            revert T.InvalidRecord();
        }
        T.RatificationRecord storage prior = _ratifications[p.collectionId];
        if (
            prior.contentStateHash == p.contentStateHash
                && prior.metadataContract == p.metadataContract
        ) revert T.InvalidRecord();
        record = StreamArtistHashes.ratificationRecord(
            _environment(), p, b.artistId, signer, nonce, _now()
        );
        bytes32 key = _consume(
            keccak256("consent_finality.replay.ratification_key"),
            keccak256(abi.encode(p.collectionId, record)),
            record
        );
        T.RatificationRecord memory item =
            T.RatificationRecord(record, p.contentStateHash, p.metadataContract);
        _ratifications[p.collectionId] = item;
        _ratificationRecords[record] = item;
        _commit(
            c,
            keccak256(abi.encode(b, p, signer, nonce)),
            keccak256(abi.encode(p.collectionId, item)),
            keccak256(abi.encode(key, record)),
            record
        );
        emit ArtistContentRatificationRecorded(
            1, p.collectionId, p.contentStateHash, signer, 1, nonce, _now(), record
        );
    }

    function _requireAccepted(T.Binding calldata b, address signer) private pure {
        if (
            !b.accepted || b.consentMode != 1 || b.artistId == bytes32(0)
                || signer != b.artistAddress
        ) revert T.InvalidRecord();
    }
}
