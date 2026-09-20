// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistConsentTransport } from "./StreamArtistConsentTransport.sol";
import "../../interfaces/stream/artist/IStreamArtistSanctionConfirmation.sol";
import "./StreamArtistConsentStorage.sol";
import "./StreamArtistSanctionConfirmationState.sol";

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

    function recordRecoveryApproval(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Recovery.ApprovalRecord calldata r,
        R.AuthorityFact calldata authority,
        Approval.Admission calldata admission
    ) external onlyHost returns (bytes32) {
        _check(c, 22);
        StreamArtistRecoveryApprovalState.Mutation memory m =
            StreamArtistRecoveryApprovalState.recordEncoded(
                _recoveryApprovals,
                _replay,
                StreamArtistRecoveryApprovalState.OwnerContext(
                    _environment(), operationCoordinator, archiveV2, domainId, _revision, _now()
                ),
                msg.data
            );
        _commit(c, m.action, m.state, m.replay, m.record);
        _native(c.operationId, m.record, b.artistId, r.terms.collectionId);
        return m.record;
    }

    function consumeSanctionFinalization(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Confirmation.Transition calldata p
    ) external onlyHost returns (bytes32 replayKey) {
        _check(c, 13);
        StreamArtistConsentState.Mutation memory m;
        (m, replayKey) = StreamArtistSanctionConfirmationState.consumeEncoded(
            _sanctions,
            _replay,
            StreamArtistConsentState.Context(
                _environment(), operationCoordinator, archiveV2, domainId, _revision, 0
            ),
            msg.data
        );
        _commit(c, m.action, m.state, m.replay, m.record);
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
        _native(c.operationId, m.record, b.artistId, r.terms.collectionId);
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
        StreamArtistConsentState.Mutation memory m = StreamArtistConsentTransport.saleEncoded(
            _saleRecords,
            _latestSaleConsents,
            _replay,
            _consentContext(),
            msg.data,
            authority.authorityClass
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        _native(c.operationId, m.record, b.artistId, p.collectionId);
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

    function recordDelegatedPolicyConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) external onlyHost returns (bytes32) {
        _check(c, 14);
        _requireDelegated(b, signer, grant);
        if (b.consentMode != 2) revert T.InvalidRecord();
        StreamArtistConsentState.Mutation memory m = StreamArtistConsentTransport.policyEncoded(
            _policies, _replay, _consentContext(), msg.data, 2
        );
        m = StreamArtistConsentTransport.noteDelegation(
            _recordDelegation, m, grant, b.artistId, c.operationId
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        _native(c.operationId, m.record, b.artistId, p.collectionId);
        return m.record;
    }

    function recordDelegatedSaleConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Sale.Consent calldata p,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) external onlyHost returns (bytes32) {
        _check(c, 16);
        _requireDelegated(b, signer, grant);
        if (b.consentMode != 2) revert T.InvalidRecord();
        StreamArtistConsentState.Mutation memory m = StreamArtistConsentTransport.saleEncoded(
            _saleRecords, _latestSaleConsents, _replay, _consentContext(), msg.data, 2
        );
        m = StreamArtistConsentTransport.noteDelegation(
            _recordDelegation, m, grant, b.artistId, c.operationId
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        _native(c.operationId, m.record, b.artistId, p.collectionId);
        return m.record;
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
        StreamArtistConsentState.Mutation memory m = StreamArtistConsentTransport.policyEncoded(
            _policies, _replay, _consentContext(), msg.data, authority.authorityClass
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        _native(c.operationId, m.record, b.artistId, p.collectionId);
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
            StreamArtistConsentTransport.economicsEncoded(
                _economics,
                _recordDelegation,
                _replay,
                _economicsAssociations,
                _associatedEconomicsRecords,
                _consentContext(),
                msg.data,
                principalClass,
                grant
            );
        _commit(c, m.action, m.state, m.replay, m.record);
        _native(c.operationId, m.record, b.artistId, p.collectionId);
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
        StreamArtistConsentState.Mutation memory m = StreamArtistConsentTransport.ratificationEncoded(
            _ratifications,
            _ratificationRecords,
            _replay,
            _consentContext(),
            msg.data,
            authority.authorityClass
        );
        _commit(c, m.action, m.state, m.replay, m.record);
        _native(c.operationId, m.record, b.artistId, p.collectionId);
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
        _native(c.operationId, record, b.artistId, p.collectionId);
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
        StreamArtistConsentState.Mutation memory m =
            StreamArtistConsentTransport.contentConsentEncoded(
                _contentConsents,
                _latestContentConsent,
                _replay,
                _consentContext(),
                msg.data,
                authority.authorityClass
            );
        record = m.record;
        _commit(c, m.action, m.state, m.replay, record);
        _native(c.operationId, record, b.artistId, p.collectionId);
        StreamArtistConsentTransport.emitContentConsentEncoded(
            msg.data, record, authority.authorityClass, _now()
        );
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
        StreamArtistConsentState.Mutation memory m =
            StreamArtistConsentTransport.contentFreezeEncoded(
                _contentFreezes,
                _latestContentFreeze,
                _replay,
                _consentContext(),
                msg.data,
                authority.authorityClass
            );
        record = m.record;
        _commit(c, m.action, m.state, m.replay, record);
        _native(c.operationId, record, b.artistId, p.collectionId);
        StreamArtistConsentTransport.emitContentFreezeEncoded(
            msg.data, record, authority.authorityClass, _now()
        );
    }

    function _consentContext() private view returns (StreamArtistConsentState.Context memory) {
        return StreamArtistConsentState.Context(
            _environment(), operationCoordinator, archiveV2, domainId, _revision, _now()
        );
    }

    function _requireDelegated(T.Binding calldata b, address signer, bytes32 grant) private pure {
        if (
            !b.accepted || (b.consentMode != 1 && b.consentMode != 2) || b.artistId == bytes32(0)
                || signer == address(0) || grant == bytes32(0)
        ) revert T.InvalidRecord();
    }

    function _requireAccepted(T.Binding calldata b, address signer) private pure {
        if (
            !b.accepted || (b.consentMode != 1 && b.consentMode != 2) || b.artistId == bytes32(0)
                || signer != b.artistAddress
        ) revert T.InvalidRecord();
    }
}
