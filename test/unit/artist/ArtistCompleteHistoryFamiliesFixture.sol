// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistCompleteHistorySanctionRatificationFixture.sol";
import {
    StreamArtistDelegationTypes as CHFDelegation
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    IStreamArtistDelegation as CHFDelegations
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegation.sol";
import {
    IStreamArtistDelegatedConsent as CHFDelegatedConsent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsent.sol";
import {
    StreamArtistAttributionDisputeTypes as CHFDispute,
    IStreamArtistAttributionDisputesOwner as CHFDisputes
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    IStreamArtistDisputeWithdrawal as CHFWithdrawal,
    IStreamArtistDisputeWithdrawalOwner as CHFWithdrawalOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import {
    StreamArtistC2PATypes as CHFC2PA,
    IStreamArtistC2PAReads as CHFCredentials
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    IStreamArtistAuthenticatedAttestationOwner as CHFAssociations
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    StreamArtistReadinessHydrationTypes as CHFReady,
    IStreamArtistReadinessAttributionOwner as CHFClasses
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistMultipleRecordsTypes as CHFRecords
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    IStreamArtistPayoutOwner as CHFPayout
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    StreamSchemaDocumentStore as CHFDocuments
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamCollectionMetadataV1 as CHFMetadata
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamCollectionArchivalCoverage as CHFCoverage
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCollectionArchivalCoverage.sol";
import {
    StreamArchivalTypes as CHFArchival
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";

/// @notice Original payout, Consent, op24, sanction and dispute producers in one complete graph.
/// @dev Only inherited Core/governance/Finality and documentary coverage are unit boundaries.
/// Identity, owner journals, delegation uses, signatures and Archive records are original writes.
abstract contract ArtistCompleteHistoryFamiliesFixture is
    ArtistCompleteHistorySanctionRatificationFixture
{
    bytes32[] internal chPayouts;
    bytes32 internal chGrant;
    bytes32 internal chOpening;
    bytes32 internal chWithdrawal;
    T.PolicyConsent internal chPolicy;
    bytes32 internal chPolicyRecord;
    CHFReady.AttestationInput[] internal chAttestationInputs;
    bytes32[] internal chAttestations;
    CHFDocuments internal chDocuments;

    function _chMixedFamilies() internal {
        _chPayout(address(0xC101));
        _chPayout(address(0xC102));
        _pcPayout();
        CHFDelegation.Grant memory terms = _delegation(
            1,
            CHFDelegation.POLICY_CONSENT | CHFDelegation.ATTEST | CHFDelegation.DISPUTE,
            uint64(block.timestamp),
            uint64(block.timestamp + 365 days),
            4
        );
        T.Authorization memory a = _chAuthorization(false);
        a.time = 0;
        bytes32 digest = ingress.delegationGrantDigest(terms, a);
        a.signature = _signature(digest);
        chGrant = ingress.grantArtistDelegation(terms, a);
        require(chGrant == _grantRecord(terms, a.nonce), "original grant preimage");
        _pcRemember(artistId, chGrant, digest, a);
        _rhCandidate(2, "identity_authority.replay.delegation_key", chGrant);
        _chPolicy();
        bytes32 first = _chCredential(0, true);
        _chCredential(first, false);
        _chSanctionRatification();
        chOpening = _chDelegatedDispute(1, 5);
        chWithdrawal = _chDelegatedDispute(2, 6);
        require(ingress.delegationRecord(chGrant).uses == 4, "one Consent plus op24 plus44 and61");
        CHFDelegation.Revocation memory revoke = CHFDelegation.Revocation(
            artistId, address(delegateSafe), chGrant, keccak256("mixed history retained grant")
        );
        a = _chAuthorization(false);
        digest = ingress.delegationRevocationDigest(revoke, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.revokeArtistDelegation(revoke, a);
        _pcRemember(artistId, record, digest, a);
        _rhCandidate(2, "identity_authority.replay.one_way_delegation_revocation", chGrant);
        require(
            ingress.delegationRecord(chGrant).revoked, "original exhausted grant retained revoked"
        );
    }

    function _chAuthorization(bool signedAt) internal view returns (T.Authorization memory) {
        return T.Authorization(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint,
            uint64(signedAt ? block.timestamp : block.timestamp + 1 days),
            ""
        );
    }

    function _chPayout(address account) internal returns (bytes32 record) {
        (, bytes32 previous) = ingress.artistPayoutAccount(artistId);
        T.PayoutDesignation memory terms = T.PayoutDesignation(artistId, account, previous);
        T.Authorization memory a = _chAuthorization(true);
        bytes32 digest = ingress.payoutDesignationDigest(terms, a);
        a.signature = _signature(digest);
        record = ingress.recordPayoutDesignation(terms, a);
        _pcRemember(artistId, record, digest, a);
        _rhCandidate(
            5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(artistId))
        );
        chPayouts.push(record);
        require(
            CHFPayout(suite.owners[5]).designationRecord(record).previousDesignationRecordHash
                == previous,
            "authentic linked payout history"
        );
    }

    function _chPolicy() private {
        chPolicy = T.PolicyConsent(
            1, keccak256("mixed delegated phase"), keccak256("mixed delegated policy")
        );
        T.Authorization memory a = T.Authorization(257, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.policyConsentDigest(chPolicy, a);
        a.signature = _delegateSignature(digest);
        chPolicyRecord = CHFDelegatedConsent(address(ingress))
            .recordDelegatedPolicyConsent(chPolicy, chGrant, a);
        _chRememberDelegated(chPolicyRecord, digest, a);
        _rhCandidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(chPolicy.collectionId, chPolicy.phaseId, chPolicy.policyHash))
        );
    }

    function _chCredential(bytes32 previous, bool delegated) internal returns (bytes32 record) {
        CHFC2PA.Credential[] memory credentials = new CHFC2PA.Credential[](1);
        credentials[0] =
            CHFC2PA.Credential(1, keccak256("mixed SPKI"), keccak256("mixed identity key"), 1, 0);
        bytes memory statement = abi.encode(
            CHFC2PA.Payload(
                1, artistId, ingress.operativeIdentityRecord(artistId), previous, credentials
            )
        );
        T.Attestation memory terms = T.Attestation(
            1,
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1"),
            keccak256(statement),
            "urn:complete:mixed:credential"
        );
        T.Authorization memory a =
            delegated ? T.Authorization(4, uint64(block.timestamp), "") : _chAuthorization(true);
        bytes32 digest = ingress.attestationDigest(terms, a);
        a.signature = delegated ? _delegateSignature(digest) : _signature(digest);
        record = delegated
            ? ingress.recordDelegatedArtistAttestation(terms, chGrant, a, statement)
            : ingress.recordArtistAttestation(terms, a, statement);
        if (delegated) {
            _chRememberDelegated(record, digest, a);
        } else {
            _pcRemember(artistId, record, digest, a);
            _rhCandidate(
                2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record))
            );
        }
        chAttestationInputs.push(CHFReady.AttestationInput(terms, a.nonce));
        chAttestations.push(record);
        require(
            CHFCredentials(suite.owners[4]).c2paCredentialHead(artistId).recordHash == record,
            "actual global credential head advances"
        );
    }

    function _chRememberDelegated(bytes32 record, bytes32 digest, T.Authorization memory a)
        private
    {
        bytes32 lane = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                artistId,
                address(delegateSafe)
            )
        );
        _rhCandidate(
            2, "identity_authority.replay.delegated_nonce", keccak256(abi.encode(lane, a.nonce))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        pcRecords.push(record);
        pcDigests.push(digest);
        pcSignatures.push(a.signature);
        require(
            keccak256(IStreamArtistIdentityOwner(suite.owners[2]).signatureBundle(record))
                == keccak256(a.signature),
            "original delegated signature bytes"
        );
    }

    function _chDelegatedDispute(uint8 action, uint256 nonce) private returns (bytes32 record) {
        T.Binding memory binding = Binding(suite.owners[0]).binding(1);
        bytes32 opening = ingress.attributionDispute(1, binding.generation).disputeRecordHash;
        bytes32 evidence =
            _chDisputeEvidence(opening, keccak256(abi.encode("mixed delegated dispute", action)));
        CHFDispute.Filing memory terms =
            CHFDispute.Filing(1, binding.generation, action, evidence, evidence);
        CHFDispute.Standing memory standing =
            CHFDispute.Standing(artistId, binding.generation, 0, chGrant);
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.attributionDisputeDigest(terms, a);
        a.signature = _delegateSignature(digest);
        uint256 count = Native(suite.owners[2]).artistNativeReceiptCount();
        record = action == 1
            ? ingress.openAttributionDispute(terms, standing, a)
            : CHFWithdrawal(address(ingress)).withdrawAttributionDispute(terms, standing, a);
        _chRememberDelegated(record, digest, a);
        _rhCandidate(
            4,
            action == 1
                ? "attribution_lifecycle.replay.dispute_key"
                : "attribution_lifecycle.replay.dispute_withdrawal_key",
            action == 1
                ? keccak256(
                    abi.encode(
                        uint256(1),
                        binding.generation,
                        bytes32(0),
                        address(delegateSafe),
                        evidence,
                        evidence
                    )
                )
                : opening
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == count,
            "original44 and61 consume authority without synthetic Identity native receipts"
        );
    }

    function _chDisputeEvidence(bytes32 parent, bytes32 narrative) private returns (bytes32 hash) {
        if (address(chDocuments) == address(0)) chDocuments = new CHFDocuments();
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        (hash,) = chDocuments.publishChunk(
            abi.encode(CHFDispute.Evidence(1, 1, b.generation, b.bindingHash, parent, narrative))
        );
        avm.mockCall(
            address(metadata), abi.encodeCall(CHFMetadata.core, ()), abi.encode(address(core))
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(CHFMetadata.chunkStore, ()),
            abi.encode(address(chDocuments))
        );
        CHFArchival.CoverageFacts memory facts;
        facts.coverageRecordHash = keccak256(abi.encode("mixed documentary coverage", hash));
        facts.envelopeHash = keccak256(abi.encode("mixed documentary envelope", hash));
        facts.evidenceHash = hash;
        avm.mockCall(
            address(estateCoverageProvider),
            abi.encodeCall(CHFCoverage.requireCollectionEvidence, (uint256(1), hash)),
            abi.encode(facts)
        );
    }

    function _chFamilyWitnesses(RH.Request memory request) internal view {
        request.records.authority.collections[0].policies = new AH.PolicyKey[](1);
        request.records.authority.collections[0].policies[0] =
            AH.PolicyKey(chPolicy.phaseId, chPolicy.policyHash);
        request.records.witnesses = new CHFRecords.CollectionWitness[](1);
        request.records.witnesses[0].collectionId = 1;
        request.records.witnesses[0].economics = new T.EconomicsConsent[](0);
        request.records.witnesses[0].attestations = chAttestationInputs;
    }

    function _chFamiliesHash(T.SuiteConfiguration memory target) internal view returns (bytes32 h) {
        h = keccak256(
            abi.encode(
                _chSanctionRatificationHash(target),
                CHFDelegations(target.owners[2]).delegationRecord(chGrant),
                Consent(target.owners[6]).policyRecord(1, chPolicy.phaseId, chPolicy.policyHash),
                CHFDisputes(target.owners[4]).attributionDisputeRecord(chOpening),
                CHFDisputes(target.owners[4]).attributionDisputeRecord(chWithdrawal),
                CHFDisputes(target.owners[4]).attributionDispute(1, 1),
                CHFWithdrawalOwner(target.owners[4]).attributionDisputeWithdrawal(chOpening),
                CHFCredentials(target.owners[4]).c2paCredentialHead(artistId)
            )
        );
        for (uint256 i; i < chPayouts.length; ++i) {
            h = keccak256(
                abi.encode(h, CHFPayout(target.owners[5]).designationRecord(chPayouts[i]))
            );
        }
        for (uint256 i; i < chAttestations.length; ++i) {
            bytes32 record = chAttestations[i];
            T.Attestation memory terms = chAttestationInputs[i].terms;
            h = keccak256(
                abi.encode(
                    h,
                    Attribution(target.owners[4]).attestationRecord(record),
                    Attribution(target.owners[4]).statementBytes(terms.statementHash),
                    Attribution(target.owners[4])
                        .attestation(terms.collectionId, terms.subjectKind, terms.subjectId),
                    CHFClasses(target.owners[4]).attestationAuthorityClass(record),
                    CHFAssociations(target.owners[4]).attestationAssociation(record),
                    CHFCredentials(target.owners[4]).c2paCredentialRecord(record)
                )
            );
        }
        h = keccak256(
            abi.encode(h, CHFDelegations(target.owners[6]).recordDelegation(chPolicyRecord))
        );
    }

    function _chAssertFamilies(T.SuiteConfiguration memory target) internal view {
        require(
            _chFamiliesHash(target) == _chFamiliesHash(suite),
            "all original nonempty family maps retained"
        );
        CHFDelegation.Record memory grant =
            CHFDelegations(target.owners[2]).delegationRecord(chGrant);
        require(
            grant.revoked && grant.uses == 4,
            "exact revoked grant count across three consuming families"
        );
        require(
            chPayouts.length >= 2 && chAttestations.length >= 2 && chPolicyRecord != 0
                && chOpening != 0 && chWithdrawal != 0,
            "fixture actually exercises each claimed family"
        );
        _chAssertSanctionRatification(target);
    }
}
