// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistConsentStorage.sol";

/// @notice Fixed implementation of the Consent owner's explicit mutations.
/// @dev All semantic callbacks reject direct calls before reading authority or snapshots.
contract StreamArtistConsentWriterExtension is StreamArtistConsentStorage {
    error ExtensionWrongHost(address actual);
    address private immutable _host;

    constructor(
        address host_,
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    ) StreamArtistConsentStorage(registry_, coordinator_, archive_, core_, manager_) {
        if (host_ == address(0) || host_ == address(this)) revert T.InvalidBinding();
        _host = host_;
    }
    modifier onlyHost() {
        if (address(this) != _host) revert ExtensionWrongHost(address(this));
        _;
    }

    function recordSanction(
        T.ActionContext calldata c,
        T.Binding calldata b,
        S.Record calldata r,
        R.AuthorityFact calldata authority,
        address finalityRegistry,
        bytes calldata ceremony,
        bytes calldata signature
    ) external onlyHost returns (bytes32) {
        _check(c, 12);
        StreamArtistConsentState.Mutation memory m = StreamArtistSanctionState.recordEncoded(
            _sanctions, _replay, _consentContext(), msg.data
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function recordSaleConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Sale.Consent calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external onlyHost returns (bytes32 record) {
        _check(c, 16);
        StreamArtistCurrentAuthorityFacts.requireAccepted(b, signer, authority, false);
        StreamArtistConsentState.Mutation memory m = StreamArtistConsentState.saleConsentForAuthority(
            _saleRecords,
            _latestSaleConsents,
            _replay,
            _consentContext(),
            b,
            p,
            signer,
            authority.authorityClass,
            nonce
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
    }

    function recordPolicy(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        address signer,
        uint256 nonce
    ) external onlyHost returns (bytes32 record) {
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
    ) external onlyHost returns (bytes32 record) {
        return _currentRecordPolicy(c, b, p, signer, nonce, authority);
    }

    function recordEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        T.Payout calldata designation,
        address signer,
        uint256 nonce
    ) external onlyHost returns (bytes32 record) {
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
    ) external onlyHost returns (bytes32 record) {
        return _currentRecordEconomics(c, b, p, designation, signer, nonce, authority);
    }

    function recordDelegatedEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        T.Payout calldata designation,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) external onlyHost returns (bytes32) {
        _check(c, 15);
        _requireDelegated(b, signer, grant);
        return _recordEconomics(c, b, p, designation, signer, nonce, grant, 2);
    }

    function recordRatification(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        address signer,
        uint256 nonce
    ) external onlyHost returns (bytes32 record) {
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
    ) external onlyHost returns (bytes32 record) {
        return _currentRecordRatification(c, b, p, signer, nonce, authority);
    }

    function authorizeRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        address signer,
        uint256 nonce
    ) external onlyHost returns (bytes32 record) {
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
    ) external onlyHost returns (bytes32 record) {
        return _currentAuthorizeRoyaltyFreeze(c, b, p, signer, nonce, authority);
    }

    function authorizeDelegatedRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) external onlyHost returns (bytes32) {
        _check(c, 20);
        _requireDelegated(b, signer, grant);
        return _authorizeRoyaltyFreeze(c, b, p, signer, nonce, grant, 2);
    }

    function recordContentConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Consent calldata p,
        address signer,
        uint256 nonce
    ) external onlyHost returns (bytes32 record) {
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
    ) external onlyHost returns (bytes32 record) {
        return _currentRecordContentConsent(c, b, p, signer, nonce, authority);
    }

    function authorizeContentFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Freeze calldata p,
        address signer,
        uint256 nonce
    ) external onlyHost returns (bytes32 record) {
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
    ) external onlyHost returns (bytes32 record) {
        return _currentAuthorizeContentFreeze(c, b, p, signer, nonce, authority);
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
        StreamArtistConsentState.Mutation memory m = StreamArtistConsentState.policyForAuthority(
            _policies, _replay, _consentContext(), b, p, signer, authority.authorityClass, nonce
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
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
        return _recordEconomics(
            c, b, p, designation, signer, nonce, bytes32(0), authority.authorityClass
        );
    }

    function _recordEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        T.Payout calldata designation,
        address signer,
        uint256 nonce,
        bytes32 grant,
        uint8 principalClass
    ) private returns (bytes32 record) {
        StreamArtistConsentState.Mutation memory m =
            StreamArtistConsentState.economicsAssociatedForAuthority(
                _economics,
                _recordDelegation,
                _replay,
                _economicsAssociations,
                _associatedEconomicsRecords,
                _consentContext(),
                b,
                p,
                designation,
                signer,
                principalClass,
                nonce,
                grant
            );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
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
        StreamArtistConsentState.Mutation memory m =
            StreamArtistConsentState.ratificationForAuthority(
                _ratifications,
                _ratificationRecords,
                _replay,
                _consentContext(),
                b,
                p,
                signer,
                authority.authorityClass,
                nonce
            );
        _commit(c, m.action, m.state, m.replay, m.record);
        return m.record;
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
        return _authorizeRoyaltyFreeze(c, b, p, signer, nonce, bytes32(0), authority.authorityClass);
    }

    function _authorizeRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        address signer,
        uint256 nonce,
        bytes32 grant,
        uint8 principalClass
    ) private returns (bytes32 record) {
        if (
            p.resolver == address(0) || p.collectionId == 0
                || p.revenueClass != keccak256("ROYALTY_ERC2981")
                || p.expectedAssignmentHash == bytes32(0)
        ) {
            revert T.InvalidRecord();
        }
        uint8 authorityClass = grant == bytes32(0) ? principalClass : 2;
        record = StreamArtistEconomicsHashes.royaltyFreezeRecordForAuthority(
            _environment(), p, b.artistId, signer, authorityClass, nonce, _now()
        );
        bytes32 scope = keccak256(abi.encode(p, b.artistId, b.generation));
        bytes32 key = _consume(keccak256("consent_finality.replay.freeze_key"), scope, record);
        T.RoyaltyFreezeRecord memory authorization =
            T.RoyaltyFreezeRecord(record, b.artistId, b.generation);
        _royaltyFreezes[scope] = authorization;
        if (grant != bytes32(0)) _recordDelegation[record] = grant;
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
            _environment(), p, b.artistId, signer, authority.authorityClass, nonce, _now()
        );
        bytes32 scope = keccak256(abi.encode(p, b.generation));
        bytes32 key = _consume(
            keccak256("consent_finality.replay.content_consent_key"),
            keccak256(abi.encode(scope, record)),
            record
        );
        IStreamArtistContentRecordsOwner.ConsentRecord memory item =
            IStreamArtistContentRecordsOwner.ConsentRecord(
                record, b.artistId, b.generation, p, authority.authorityClass
            );
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
            1,
            p.collectionId,
            p.familyId,
            signer,
            p.newStateHash,
            authority.authorityClass,
            nonce,
            _now(),
            record
        );
        emit ArtistContentRecordContext(1, record, p.metadataContract, b.artistId);
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
            _environment(), p, b.artistId, signer, authority.authorityClass, nonce, _now()
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
            authority.authorityClass
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
            1,
            p.collectionId,
            signer,
            p.lockClasses,
            p.expectedStateHash,
            authority.authorityClass,
            nonce,
            _now(),
            record
        );
        emit ArtistContentRecordContext(1, record, p.metadataContract, b.artistId);
    }

    function _consentContext() private view returns (StreamArtistConsentState.Context memory) {
        return StreamArtistConsentState.Context(
            _environment(), operationCoordinator, archiveV2, domainId, _revision, _now()
        );
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
