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

import "./StreamArtistConsentStorage.sol";
import "./StreamArtistConsentWriterExtension.sol";
import "./StreamArtistSanctionState.sol";
import "./StreamArtistConsentReadEncoding.sol";
import "../../interfaces/stream/artist/IStreamArtistSanctionConfirmation.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of the onboarding policy/economics/content-ratification records.
/// @dev State remains in this owner; the constructor-fixed writer executes its explicit callbacks.
contract StreamArtistConsentFinalityLifecycle is
    StreamArtistConsentStorage,
    IStreamArtistEconomicsEvidence,
    IStreamArtistSanctionOwner
{
    // Retain the published host error ABI after callback implementation extraction.
    error BoundExceeded(uint256 actual, uint256 maximum);
    error InvalidOperation(uint16 operationId);
    error InvalidRecord();
    error Replay(bytes32 replayKey);
    error StaleOwnerSnapshot(bytes32 domainId);
    error Unauthorized(address caller);
    address public immutable consentWriterExtension;

    function consumeSanctionFinalization(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Confirmation.Transition calldata p
    ) external returns (bytes32) {
        _forwardConsentWriter();
    }

    function recordSanction(
        T.ActionContext calldata c,
        T.Binding calldata b,
        S.Record calldata r,
        R.AuthorityFact calldata authority,
        address finalityRegistry,
        bytes calldata ceremony,
        bytes calldata signature
    ) external returns (bytes32) {
        _forwardConsentWriter();
    }

    function sanctionRecord(bytes32 recordHash) external view returns (S.Record memory) {
        _returnSanction(StreamArtistSanctionState.recordEncodedRead(_sanctions, recordHash));
    }

    function sanctionArchiveBytes(bytes32 recordHash) external view returns (bytes memory) {
        _returnSanction(StreamArtistSanctionState.archiveEncodedRead(_sanctions, recordHash));
    }

    function sanctionArchiveFacts(bytes32 recordHash)
        external
        view
        returns (IStreamArtistSanctionArchiveFacts.Facts memory)
    {
        _returnSanction(StreamArtistSanctionState.factsEncodedRead(_sanctions, recordHash));
    }

    function _returnSanction(bytes memory result) private pure {
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    function sanctionForAssociation(
        bytes32 artistId,
        uint64 generation,
        bytes32 bindingHash,
        uint8 scopeType,
        uint256 collectionId,
        uint256 tokenId,
        bytes32 scopeId
    ) external view returns (bytes32) {
        S.Terms memory p = S.Terms(scopeType, collectionId, tokenId, scopeId, 0, 0);
        return _sanctions.latest[
            StreamArtistSanctionState.associationKey(artistId, generation, bindingHash, p)
        ];
    }

    function recordSaleConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Sale.Consent calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32 record) {
        _forwardConsentWriter();
    }

    function saleConsentRecord(bytes32 recordHash) external view returns (Sale.Record memory) {
        _returnSanction(StreamArtistConsentReadEncoding.sale(_saleRecords, recordHash));
    }

    function saleConsentAt(uint256 collectionId, bytes32 saleId, bytes32 saleConfigHash)
        external
        view
        returns (bytes32)
    {
        return _latestSaleConsents[
            StreamArtistSaleHashes.lookup(collectionId, saleId, saleConfigHash)
        ];
    }

    /// @notice Context omitted by the permanent normative event, needed to reconstruct its exact record.

    /// @notice Permanent grant witness and missing contextual preimage fields for a delegated canonical record.

    constructor(
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_
    ) StreamArtistConsentStorage(registry_, coordinator_, archive_, core_, manager_) {
        consentWriterExtension = address(
            new StreamArtistConsentWriterExtension(
                address(this), registry_, coordinator_, archive_, core_, manager_
            )
        );
    }

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

    function economicsRecordForBinding(
        T.EconomicsConsent calldata p,
        bytes32 artistId,
        uint64 generation,
        bytes32 bindingHash
    ) external view override returns (bytes32 record) {
        return StreamArtistConsentReadEncoding.economicsForBinding(
            _associatedEconomicsRecords,
            _economicsAssociations,
            _economics,
            p,
            artistId,
            generation,
            bindingHash
        );
    }

    function economicsRecordAssociation(bytes32 recordHash)
        external
        view
        override
        returns (Association memory)
    {
        _returnSanction(
            StreamArtistConsentReadEncoding.association(_economicsAssociations, recordHash)
        );
    }

    function firstReleaseRatification(uint256 collectionId)
        external
        view
        returns (T.RatificationRecord memory)
    {
        _returnSanction(
            StreamArtistConsentReadEncoding.firstRatification(_ratifications, collectionId)
        );
    }

    function ratificationRecord(bytes32 record)
        external
        view
        returns (T.RatificationRecord memory)
    {
        _returnSanction(StreamArtistConsentReadEncoding.ratification(_ratificationRecords, record));
    }

    function recordPolicy(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        _forwardConsentWriter();
    }

    function recordPolicyWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32 record) {
        _forwardConsentWriter();
    }

    function recordEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        T.Payout calldata designation,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        _forwardConsentWriter();
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
        _forwardConsentWriter();
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
        _forwardConsentWriter();
    }

    function recordRatification(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        _forwardConsentWriter();
    }

    function recordRatificationWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32 record) {
        _forwardConsentWriter();
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
        _forwardConsentWriter();
    }

    function authorizeRoyaltyFreezeWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32 record) {
        _forwardConsentWriter();
    }

    function authorizeDelegatedRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        address signer,
        uint256 nonce,
        bytes32 grant
    ) external returns (bytes32) {
        _forwardConsentWriter();
    }

    function contentConsentRecord(bytes32 recordHash)
        external
        view
        returns (IStreamArtistContentRecordsOwner.ConsentRecord memory)
    {
        _returnSanction(StreamArtistConsentReadEncoding.content(_contentConsents, recordHash));
    }

    function contentConsentAt(Content.Consent calldata p, uint64 generation)
        external
        view
        returns (IStreamArtistContentRecordsOwner.ConsentRecord memory)
    {
        _returnSanction(
            StreamArtistConsentReadEncoding.contentAt(
                _contentConsents, _latestContentConsent, p, generation
            )
        );
    }

    function contentFreezeRecord(bytes32 recordHash)
        external
        view
        returns (Content.FreezeRecord memory)
    {
        _returnSanction(StreamArtistConsentReadEncoding.freeze(_contentFreezes, recordHash));
    }

    function contentFreezeAt(
        uint256 collectionId,
        uint64 generation,
        address metadata,
        bytes32 lockClass
    ) external view returns (Content.FreezeRecord memory) {
        _returnSanction(
            StreamArtistConsentReadEncoding.freezeAt(
                    _contentFreezes,
                    _latestContentFreeze,
                    collectionId,
                    generation,
                    metadata,
                    lockClass
                )
        );
    }

    function recordContentConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Consent calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        _forwardConsentWriter();
    }

    function recordContentConsentWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Consent calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32 record) {
        _forwardConsentWriter();
    }

    function authorizeContentFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Freeze calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record) {
        _forwardConsentWriter();
    }

    function authorizeContentFreezeWithAuthority(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Freeze calldata p,
        address signer,
        uint256 nonce,
        R.AuthorityFact calldata authority
    ) external returns (bytes32 record) {
        _forwardConsentWriter();
    }

    /// @notice Permanent delegation evidence; the internal mapping retains its original physical slot.
    function recordDelegation(bytes32) external view returns (bytes32) {
        bytes32 recordHash;
        assembly ("memory-safe") { recordHash := calldataload(4) }
        return _recordDelegation[recordHash];
    }

    function _forwardConsentWriter() private {
        address target = consentWriterExtension;
        assembly ("memory-safe") {
            let pointer := mload(0x40)
            calldatacopy(pointer, 0, calldatasize())
            let success := delegatecall(gas(), target, pointer, calldatasize(), 0, 0)
            returndatacopy(pointer, 0, returndatasize())
            if iszero(success) { revert(pointer, returndatasize()) }
            return(pointer, returndatasize())
        }
    }
}
