// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistCurrentAuthorityFacts.sol";
import "./StreamArtistContentHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistContentOwner.sol";

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
    mapping(bytes32 => T.RoyaltyFreezeRecord) private _royaltyFreezes;
    mapping(bytes32 => bytes32) public recordDelegation;
    mapping(bytes32 => IStreamArtistContentRecordsOwner.ConsentRecord) private _contentConsents;
    mapping(bytes32 => bytes32) private _latestContentConsent;
    mapping(bytes32 => Content.FreezeRecord) private _contentFreezes;
    mapping(bytes32 => bytes32) private _latestContentFreeze;

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
    /// @notice Context omitted by the permanent normative event, needed to reconstruct its exact record.
    event ArtistContentRecordContext(
        uint16 schemaVersion, bytes32 indexed recordHash, address metadataContract, bytes32 artistId
    );
    /// @notice Permanent grant witness and missing contextual preimage fields for a delegated canonical record.
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
        return _currentRecordPolicy(
            c, b, p, signer, nonce, R.AuthorityFact(b.artistId, b.artistAddress, 1, 1)
        );
    }

    function recordPolicyWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32 record) {
        return _currentRecordPolicy(c, b, p, signer, nonce, authority);
    }

    function _currentRecordPolicy(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact memory authority
    ) private returns (bytes32 record) {
        _check(c, 14);
        StreamArtistCurrentAuthorityFacts.requireAccepted(b, signer, authority, false);
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
        return _currentRecordEconomics(
            c, b, p, designation, signer, nonce, R.AuthorityFact(b.artistId, b.artistAddress, 1, 1)
        );
    }

    function recordEconomicsWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        T.Payout calldata designation,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32 record) {
        return _currentRecordEconomics(c, b, p, designation, signer, nonce, authority);
    }

    function _currentRecordEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        T.Payout calldata designation,
        address signer,
        uint256 nonce,
        R.AuthorityFact memory authority
    ) private returns (bytes32 record) {
        _check(c, 15);
        StreamArtistCurrentAuthorityFacts.requireAccepted(b, signer, authority, false);
        return _recordEconomics(c, b, p, designation, signer, nonce, bytes32(0));
    }

    function recordDelegatedEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        T.Payout calldata designation,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) external returns (bytes32) {
        _check(c, 15);
        _requireDelegated(b, signer, grant);
        return _recordEconomics(c, b, p, designation, signer, nonce, grant);
    }

    function _recordEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        T.Payout calldata designation,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) private returns (bytes32 record) {
        if (
            designation.account == address(0) || designation.recordHash == bytes32(0)
                || p.resolver == address(0) || p.assignmentHash == bytes32(0)
                || p.revenueClass == bytes32(0) || p.scope != 1 || p.scopeId != p.collectionId
        ) {
            revert T.InvalidRecord();
        }
        uint8 authorityClass = grant == bytes32(0) ? 1 : 2;
        record = StreamArtistEconomicsHashes.economicsRecordForAuthority(
            _environment(),
            p,
            designation.recordHash,
            b.artistId,
            signer,
            authorityClass,
            nonce,
            _now()
        );
        bytes32 scope = keccak256(abi.encode(p));
        bytes32 key = _consume(keccak256("consent_finality.replay.consent_key"), scope, record);
        _economics[scope] = record;
        if (grant != bytes32(0)) recordDelegation[record] = grant;
        _commit(
            c,
            grant == bytes32(0)
                ? keccak256(abi.encode(b, p, designation, signer, nonce))
                : keccak256(abi.encode(b, p, designation, signer, nonce, grant)),
            grant == bytes32(0)
                ? keccak256(abi.encode(scope, record))
                : keccak256(abi.encode(scope, record, grant)),
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
            authorityClass,
            nonce,
            _now(),
            record
        );
        if (grant != bytes32(0)) {
            emit ArtistRecordDelegation(1, record, grant, b.artistId, p.resolver, p.revenueClass, 2);
        }
    }

    function recordRatification(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        return _currentRecordRatification(
            c, b, p, signer, nonce, R.AuthorityFact(b.artistId, b.artistAddress, 1, 1)
        );
    }

    function recordRatificationWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32 record) {
        return _currentRecordRatification(c, b, p, signer, nonce, authority);
    }

    function _currentRecordRatification(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact memory authority
    ) private returns (bytes32 record) {
        _check(c, 52);
        StreamArtistCurrentAuthorityFacts.requireAccepted(b, signer, authority, false);
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

    function royaltyFreezeRecord(T.RoyaltyFreeze calldata p, bytes32 artistId, uint64 generation)
        external
        view
        returns (T.RoyaltyFreezeRecord memory)
    {
        return _royaltyFreezes[keccak256(abi.encode(p, artistId, generation))];
    }

    function authorizeRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        return _currentAuthorizeRoyaltyFreeze(
            c, b, p, signer, nonce, R.AuthorityFact(b.artistId, b.artistAddress, 1, 1)
        );
    }

    function authorizeRoyaltyFreezeWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32 record) {
        return _currentAuthorizeRoyaltyFreeze(c, b, p, signer, nonce, authority);
    }

    function _currentAuthorizeRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact memory authority
    ) private returns (bytes32 record) {
        _check(c, 20);
        StreamArtistCurrentAuthorityFacts.requireAccepted(b, signer, authority, true);
        return _authorizeRoyaltyFreeze(c, b, p, signer, nonce, bytes32(0));
    }

    function authorizeDelegatedRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) external returns (bytes32) {
        _check(c, 20);
        _requireDelegated(b, signer, grant);
        return _authorizeRoyaltyFreeze(c, b, p, signer, nonce, grant);
    }

    function _authorizeRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) private returns (bytes32 record) {
        if (
            p.resolver == address(0) || p.collectionId == 0
                || p.revenueClass != keccak256("ROYALTY_ERC2981")
                || p.expectedAssignmentHash == bytes32(0)
        ) {
            revert T.InvalidRecord();
        }
        uint8 authorityClass = grant == bytes32(0) ? 1 : 2;
        record = StreamArtistEconomicsHashes.royaltyFreezeRecordForAuthority(
            _environment(), p, b.artistId, signer, authorityClass, nonce, _now()
        );
        bytes32 scope = keccak256(abi.encode(p, b.artistId, b.generation));
        bytes32 key = _consume(keccak256("consent_finality.replay.freeze_key"), scope, record);
        T.RoyaltyFreezeRecord memory authorization =
            T.RoyaltyFreezeRecord(record, b.artistId, b.generation);
        _royaltyFreezes[scope] = authorization;
        if (grant != bytes32(0)) recordDelegation[record] = grant;
        _commit(
            c,
            grant == bytes32(0)
                ? keccak256(abi.encode(b, p, signer, nonce))
                : keccak256(abi.encode(b, p, signer, nonce, grant)),
            grant == bytes32(0)
                ? keccak256(abi.encode(scope, authorization))
                : keccak256(abi.encode(scope, authorization, grant)),
            keccak256(abi.encode(key, record)),
            record
        );
        emit ArtistRoyaltyFreezeAuthorized(
            1,
            p.collectionId,
            p.expectedAssignmentHash,
            signer,
            authorityClass,
            nonce,
            _now(),
            record
        );
        if (grant != bytes32(0)) {
            emit ArtistRecordDelegation(1, record, grant, b.artistId, p.resolver, p.revenueClass, 2);
        }
    }

    function contentConsentRecord(bytes32 recordHash)
        external
        view
        returns (IStreamArtistContentRecordsOwner.ConsentRecord memory)
    {
        return _contentConsents[recordHash];
    }

    function contentConsentAt(Content.Consent calldata p, uint64 generation)
        external
        view
        returns (IStreamArtistContentRecordsOwner.ConsentRecord memory)
    {
        return _contentConsents[_latestContentConsent[keccak256(abi.encode(p, generation))]];
    }

    function contentFreezeRecord(bytes32 recordHash)
        external
        view
        returns (Content.FreezeRecord memory)
    {
        return _contentFreezes[recordHash];
    }

    function contentFreezeAt(
        uint256 collectionId,
        uint64 generation,
        address metadata,
        bytes32 lockClass
    ) external view returns (Content.FreezeRecord memory) {
        return _contentFreezes[
            _latestContentFreeze[
                keccak256(abi.encode(collectionId, generation, metadata, lockClass))
            ]
        ];
    }

    function recordContentConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Consent calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        return _currentRecordContentConsent(
            c, b, p, signer, nonce, R.AuthorityFact(b.artistId, b.artistAddress, 1, 1)
        );
    }

    function recordContentConsentWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Consent calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32 record) {
        return _currentRecordContentConsent(c, b, p, signer, nonce, authority);
    }

    function _currentRecordContentConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Consent calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact memory authority
    ) private returns (bytes32 record) {
        _check(c, 17);
        StreamArtistCurrentAuthorityFacts.requireAccepted(b, signer, authority, false);
        StreamArtistContentHashes.validateConsent(p);
        record = StreamArtistContentHashes.consentRecord(
            _environment(), p, b.artistId, signer, 1, nonce, _now()
        );
        bytes32 scope = keccak256(abi.encode(p, b.generation));
        bytes32 key = _consume(
            keccak256("consent_finality.replay.content_consent_key"),
            keccak256(abi.encode(scope, record)),
            record
        );
        IStreamArtistContentRecordsOwner.ConsentRecord memory item =
            IStreamArtistContentRecordsOwner.ConsentRecord(record, b.artistId, b.generation, p, 1);
        _contentConsents[record] = item;
        _latestContentConsent[scope] = record;
        _commit(
            c,
            keccak256(abi.encode(b, p, signer, nonce)),
            keccak256(abi.encode(scope, item)),
            keccak256(abi.encode(key, record)),
            record
        );
        emit ArtistContentConsentRecorded(
            1, p.collectionId, p.familyId, signer, p.newStateHash, 1, nonce, _now(), record
        );
        emit ArtistContentRecordContext(1, record, p.metadataContract, b.artistId);
    }

    function authorizeContentFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Freeze calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        return _currentAuthorizeContentFreeze(
            c, b, p, signer, nonce, R.AuthorityFact(b.artistId, b.artistAddress, 1, 1)
        );
    }

    function authorizeContentFreezeWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Freeze calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32 record) {
        return _currentAuthorizeContentFreeze(c, b, p, signer, nonce, authority);
    }

    function _currentAuthorizeContentFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Freeze calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact memory authority
    ) private returns (bytes32 record) {
        _check(c, 21);
        StreamArtistCurrentAuthorityFacts.requireAccepted(b, signer, authority, true);
        StreamArtistContentHashes.validateFreeze(p);
        record = StreamArtistContentHashes.freezeRecord(
            _environment(), p, b.artistId, signer, 1, nonce, _now()
        );
        bytes32 key = _consume(
            keccak256("consent_finality.replay.freeze_key"),
            keccak256(abi.encode(keccak256("CONTENT"), p.collectionId, b.generation, record)),
            record
        );
        Content.FreezeRecord memory item = Content.FreezeRecord(
            record,
            b.artistId,
            b.generation,
            p.metadataContract,
            p.lockClasses,
            p.expectedStateHash,
            1
        );
        _contentFreezes[record] = item;
        for (uint256 i; i < p.lockClasses.length; ++i) {
            _latestContentFreeze[
                keccak256(
                    abi.encode(p.collectionId, b.generation, p.metadataContract, p.lockClasses[i])
                )
            ] = record;
        }
        _commit(
            c,
            keccak256(abi.encode(b, p, signer, nonce)),
            keccak256(abi.encode(p.collectionId, item)),
            keccak256(abi.encode(key, record)),
            record
        );
        emit ArtistContentFreezeAuthorized(
            1, p.collectionId, signer, p.lockClasses, p.expectedStateHash, 1, nonce, _now(), record
        );
        emit ArtistContentRecordContext(1, record, p.metadataContract, b.artistId);
    }

    function _requireDelegated(T.Binding calldata b, address signer, bytes32 grant) private pure {
        if (
            !b.accepted || b.consentMode != 1 || b.artistId == bytes32(0) || signer == address(0)
                || grant == bytes32(0)
        ) revert T.InvalidRecord();
    }

    function _requireAccepted(T.Binding calldata b, address signer) private pure {
        if (
            !b.accepted || b.consentMode != 1 || b.artistId == bytes32(0)
                || signer != b.artistAddress
        ) revert T.InvalidRecord();
    }
}
