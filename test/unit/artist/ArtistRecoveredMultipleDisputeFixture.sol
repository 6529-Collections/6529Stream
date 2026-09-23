// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistRecoveredMultipleFixture.sol";
import {
    StreamArtistContentTypes as Content
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    RecoveredDelegationSaleFacts
} from "../../helpers/RecoveredDelegationSaleFacts.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistDelegationTypes as Delegate
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    IStreamArtistDelegatedConsent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsent.sol";
import {
    IStreamArtistSaleConsentOwner as Sales
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleOwner.sol";
import {
    IStreamArtistEconomicsEvidence as Economics
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    IStreamArtistContentRecordsOwner as ContentOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    IStreamArtistRecoveredConsentHydration as ConsentHydration
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredConsentHydration.sol";
import {
    StreamArtistRecoveredMultipleDisputeCodec as ConsentCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleDisputeCodec.sol";
import {
    StreamArtistRecoveredMultipleConsentNonces as ConsentNonces
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleConsentNonces.sol";
import {
    StreamArtistEconomicsAssociation as EconomicsAssociation
} from "../../../smart-contracts/domains/artist/StreamArtistEconomicsAssociation.sol";
import { ArtistUnitGovernance, ArtistUnitRoles } from "./ArtistOnboardingFixture.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistOnboarding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOnboarding.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    StreamArtistBindingCorrectionTypes as BC,
    IStreamArtistBindingCorrection as Correction
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistBindingCorrectionAdmission as Admission
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionAdmission.sol";
import {
    StreamArtistAttributionDisputeTypes as AD,
    IStreamArtistAttributionDisputes as Disputes,
    IStreamArtistAttributionDisputesOwner as DisputeOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    IStreamArtistArchiveV2 as Archive
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationEvidence as Evidence
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationEvidence.sol";
import {
    StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamCollectionMetadataV1
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamCollectionArchivalCoverage
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamCollectionArchivalCoverage.sol";
import {
    StreamArchivalTypes as Archival
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArchivalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    IStreamArtistIdentityRecovery
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistHistory as History,
    StreamArtistHistoryTypes as HT
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAttributionRepudiation as Repudiation,
    IStreamArtistRepudiationOwner as RepudiationOwner,
    StreamArtistRepudiationTypes as RP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    IStreamArtistDisputeWithdrawal as Withdrawal,
    IStreamArtistDisputeWithdrawalOwner as WithdrawalOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    IStreamArtistNativeReceipts as Native
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistAttributionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    StreamArtistReadinessHydrationTypes as Ready
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistOwner as OriginalOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    StreamArtistC2PATypes as C2PA,
    IStreamArtistC2PAReads as Credentials
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistC2PA.sol";
import {
    IStreamArtistPersonhoodEvidence as Personhood
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import {
    IStreamArtistAuthenticatedAttestationOwner as Associations
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttestationWriter.sol";
import {
    IStreamArtistReadinessAttributionOwner as Classes
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistRecordPublicationOwner as AttestationPublications
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleDisputeTypes.sol";

interface MultipleDisputeTestVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @notice Actual owners, threshold Safes, signatures and Archive over a complete aggregate.
/// @dev Core, scoped governance, immutable sale facts and documentary coverage are explicit
/// unit boundaries. These authored tests are not a runtime or current-Executor acceptance claim.
abstract contract ArtistRecoveredMultipleDisputeFixture is ArtistRecoveredMultipleFixture {
    RecoveredDelegationSaleFacts internal mcSale;
    bytes32[] internal mcGrants;
    bytes32[] internal mcRecords;
    bytes32[] internal mcDigests;
    bytes[] internal mcSignatures;
    T.PolicyConsent[] internal mcPolicies;
    T.EconomicsConsent internal mcEconomics;
    T.RoyaltyFreeze internal mcRoyalty;
    Content.Consent internal mcContent;
    Content.Freeze internal mcFreeze;
    bytes32 internal mcEconomicsRecord;
    bytes32 internal mcSaleRecord;
    bytes32 internal mcContentRecord;
    bytes32 internal mcFreezeRecord;
    bytes32 internal mcRoyaltyRecord;

    MultipleDisputeTestVm internal constant dv =
        MultipleDisputeTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamSchemaDocumentStore internal documents;
    uint256 internal actionNonce;
    uint256[] internal mdFirstKeys;
    uint256[] internal mdSecondKeys;
    T.RoyaltyFreeze[] internal mdRoyalties;

    struct Saved {
        Ready.AttestationInput input;
        bytes32 record;
        bytes statement;
        T.Authorization authorization;
        uint8 authorityClass;
    }
    Saved[] internal maRows;
    bytes32 internal constant CREDENTIAL_SCHEMA =
        keccak256("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1");

    constructor() {
        actualSaleRegistryFixture = true;
    }

    function _initialBindingProposal() internal view override returns (T.BindingProposal memory p) {
        p = _proposal(0);
        p.consentMode = 2;
        p.saleConsentScope = 1;
    }

    function _multiProposal(bytes32 id)
        internal
        view
        override
        returns (T.BindingProposal memory p)
    {
        p = _proposal(id);
        p.consentMode = 2;
        p.saleConsentScope = 1;
    }

    function _multiFeature() internal pure override returns (uint256) {
        return MD.FEATURE;
    }

    function _multiDecode(Payload.Payload memory p)
        internal
        pure
        override
        returns (M.State memory)
    {
        return ConsentCodec.decode(2, p.semanticState, p.provenance);
    }

    function _multiOrdered(M.State memory s, RH.NonceInventory[] memory n)
        internal
        pure
        override
        returns (IH.NonceLane[] memory)
    {
        return ConsentNonces.ordered(s, n);
    }

    function _mcGrant(uint64 maxUses) internal returns (bytes32 record) {
        Delegate.Grant memory g = _delegation(
            0,
            Delegate.DISPUTE | Delegate.POLICY_CONSENT | Delegate.ECONOMICS
                | Delegate.ROYALTY_FREEZE | Delegate.SALE_CONSENT | Delegate.ATTEST,
            uint64(block.timestamp),
            uint64(block.timestamp + 365 days),
            maxUses
        );
        T.Authorization memory a = T.Authorization(nextNonce++, 0, "");
        bytes32 digest = ingress.delegationGrantDigest(g, a);
        a.signature = _signature(digest);
        record = ingress.grantArtistDelegation(g, a);
        require(record == _grantRecord(g, a.nonce), "literal original domain and grant preimage");
        mcGrants.push(record);
        _mcRemember(record, digest, a, false);
        _rhCandidate(2, "identity_authority.replay.delegation_key", record);
    }

    function _mcRevoke(bytes32 grant) internal {
        Delegate.Revocation memory g = Delegate.Revocation(
            artistId, address(delegateSafe), grant, keccak256("aggregate revocation")
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.delegationRevocationDigest(g, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.revokeArtistDelegation(g, a);
        _mcRemember(record, digest, a, false);
        _rhCandidate(2, "identity_authority.replay.one_way_delegation_revocation", grant);
    }

    function _mcPolicy(uint256 collection, bytes32 grant, uint256 nonce, bool safe) internal {
        T.PolicyConsent memory terms = T.PolicyConsent(
            collection,
            keccak256(abi.encode("aggregate delegated phase", collection)),
            keccak256(abi.encode("aggregate delegated policy", collection))
        );
        T.Authorization memory a =
            grant == 0 ? _authorization(false) : T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.policyConsentDigest(terms, a);
        bytes32 record;
        if (grant == 0) {
            a.signature = _signature(digest);
            record = ingress.recordPolicyConsent(terms, a);
        } else if (safe) {
            require(
                this.executeDelegate(
                    address(ingress),
                    abi.encodeCall(
                        IStreamArtistDelegatedConsent.recordDelegatedPolicyConsent,
                        (terms, grant, a)
                    )
                ),
                "original delegate threshold Safe"
            );
            record =
                Consent(suite.owners[6]).policyRecord(collection, terms.phaseId, terms.policyHash);
        } else {
            a.signature = _delegateSignature(digest);
            record = IStreamArtistDelegatedConsent(address(ingress))
                .recordDelegatedPolicyConsent(terms, grant, a);
        }
        mcPolicies.push(terms);
        _mcRemember(record, digest, a, grant != 0);
        _rhCandidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(collection, terms.phaseId, terms.policyHash))
        );
    }

    function _mcEconomics(bytes32 grant, uint256 nonce) internal {
        mcEconomics = _currentEconomics(address(primary));
        T.Authorization memory a =
            grant == 0 ? _authorization(false) : T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.economicsConsentDigest(mcEconomics, a);
        a.signature = grant == 0 ? _signature(digest) : _delegateSignature(digest);
        mcEconomicsRecord = grant == 0
            ? ingress.recordEconomicsConsent(mcEconomics, a)
            : ingress.recordDelegatedEconomicsConsent(mcEconomics, grant, a);
        _mcRemember(mcEconomicsRecord, digest, a, grant != 0);
        Economics.Association memory association =
            Economics(suite.owners[6]).economicsRecordAssociation(mcEconomicsRecord);
        bytes32 scope = association.originalRecord == mcEconomicsRecord
            ? keccak256(abi.encode(mcEconomics))
            : EconomicsAssociation.continuation(
                association.originalRecord, mcEconomics, Binding(suite.owners[0]).binding(1)
            );
        _rhCandidate(6, "consent_finality.replay.consent_key", scope);
    }

    function _mcSale(bytes32 grant, uint256 nonce) internal {
        Sale.Consent memory terms = Sale.Consent(1, address(mcSale), mcSale.ID(), mcSale.CONFIG());
        T.Authorization memory a =
            grant == 0 ? _authorization(false) : T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.saleConsentDigest(terms, a);
        a.signature = grant == 0 ? _signature(digest) : _delegateSignature(digest);
        mcSaleRecord = grant == 0
            ? ingress.recordSaleConsent(terms, a)
            : IStreamArtistDelegatedConsent(address(ingress))
                .recordDelegatedSaleConsent(terms, grant, a);
        _mcRemember(mcSaleRecord, digest, a, grant != 0);
        T.Binding memory b = Binding(suite.owners[0]).binding(1);
        _rhCandidate(
            6,
            "consent_finality.replay.sale_consent_key",
            keccak256(abi.encode(terms, b.generation, b.bindingHash))
        );
    }

    function _mcContentAndFreeze() internal {
        mcContent = _contentProposal(keccak256("aggregate content"));
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentConsentDigest(mcContent, a);
        a.signature = _signature(digest);
        mcContentRecord = ingress.recordContentConsent(mcContent, a);
        _mcRemember(mcContentRecord, digest, a, false);
        _rhCandidate(
            6,
            "consent_finality.replay.content_consent_key",
            keccak256(
                abi.encode(
                    keccak256(
                        abi.encode(mcContent, Binding(suite.owners[0]).binding(1).generation)
                    ),
                    mcContentRecord
                )
            )
        );
        mcFreeze = _contentFreezeProposal();
        a = _authorization(false);
        digest = ingress.contentFreezeDigest(mcFreeze, a);
        a.signature = _signature(digest);
        mcFreezeRecord = ingress.authorizeArtistContentFreeze(mcFreeze, a);
        _mcRemember(mcFreezeRecord, digest, a, false);
        _rhCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(
                abi.encode(
                    keccak256("CONTENT"),
                    uint256(1),
                    Binding(suite.owners[0]).binding(1).generation,
                    mcFreezeRecord
                )
            )
        );
    }

    function _mcRoyalty(bytes32 grant, uint256 nonce) internal {
        mcRoyalty = _freezePayload();
        T.Authorization memory a =
            grant == 0 ? _authorization(false) : T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.royaltyFreezeDigest(mcRoyalty, a);
        a.signature = grant == 0 ? _signature(digest) : _delegateSignature(digest);
        mcRoyaltyRecord = grant == 0
            ? ingress.authorizeArtistRoyaltyFreeze(mcRoyalty, a)
            : ingress.authorizeDelegatedRoyaltyFreeze(mcRoyalty, grant, a);
        _mcRemember(mcRoyaltyRecord, digest, a, grant != 0);
        _rhCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(
                abi.encode(mcRoyalty, artistId, Binding(suite.owners[0]).binding(1).generation)
            )
        );
    }

    function _mcRemember(bytes32 record, bytes32 digest, T.Authorization memory a, bool delegated)
        internal
    {
        if (delegated) {
            _rhCandidate(
                2,
                "identity_authority.replay.authorization_consumed_digest",
                keccak256(abi.encode(artistId, digest))
            );
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
        } else {
            _rhAuthorization(digest, a.nonce);
        }
        mcRecords.push(record);
        mcDigests.push(digest);
        mcSignatures.push(a.signature);
        require(
            keccak256(IStreamArtistIdentityOwner(suite.owners[2]).signatureBundle(record))
                == keccak256(a.signature),
            "source preserves exact original signature bytes including empty Safe call"
        );
    }

    function _mcSemantics(T.SuiteConfiguration memory s) internal view returns (bytes32 h) {
        for (uint256 i; i < mcPolicies.length; ++i) {
            h = keccak256(
                abi.encode(
                    h,
                    Consent(s.owners[6])
                        .policyRecord(
                            mcPolicies[i].collectionId,
                            mcPolicies[i].phaseId,
                            mcPolicies[i].policyHash
                        )
                )
            );
        }
        h = keccak256(
            abi.encode(
                h,
                Consent(s.owners[6]).economicsRecord(mcEconomics),
                Economics(s.owners[6]).economicsRecordAssociation(mcEconomicsRecord),
                Sales(s.owners[6]).saleConsentRecord(mcSaleRecord),
                ContentOwner(s.owners[6]).contentConsentRecord(mcContentRecord),
                ContentOwner(s.owners[6]).contentConsentAt(mcContent, 1),
                ContentOwner(s.owners[6]).contentFreezeRecord(mcFreezeRecord),
                ContentOwner(s.owners[6])
                    .contentFreezeAt(1, 1, address(metadata), keccak256("SCRIPT")),
                Consent(s.owners[6]).royaltyFreezeRecord(mcRoyalty, multiCollectionArtists[0], 1)
            )
        );
    }

    function _rhExecuteRecovery(Recovery.Request memory p, T.Authorization memory a)
        internal
        override
        returns (bytes32)
    {
        Recovery.Context memory c = ingress.identityRecoveryContext(p, a);
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.executeModuleContextWithAction(
            currentId,
            address(ingress),
            abi.encodeCall(IStreamArtistIdentityRecovery.recoverArtistIdentity, (p, a)),
            2,
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
        (bool active, bytes32 action, uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            authority.currentAction();
        require(
            !active && action == 0 && cls == 0 && scope == 0 && oldHash == 0 && newHash == 0,
            "scoped actual recovery context cleared without persistent mocks"
        );
        return ingress.latestIdentityRecovery(artistId);
    }

    function _rhCommitHistory(
        Successor memory next,
        HT.Context memory c,
        bytes32 root,
        bytes32 manifest
    ) internal override {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), manifest, "urn:history"
        );
        require(
            this.executeTargetSafe(
                address(authority),
                abi.encodeCall(
                    ArtistUnitGovernance.executeModuleContextWithAction,
                    (
                        keccak256("unit authority gas raise"),
                        address(next.registry),
                        abi.encodeCall(
                            History.commitArtistHistoryImportRoot,
                            (address(ingress), uint64(block.number), root, manifest)
                        ),
                        uint8(1),
                        c.scopeHash,
                        c.oldValueHash,
                        c.newValueHash
                    )
                )
            ),
            "actual Safe governed55 with scoped original witness"
        );
        (bool active, bytes32 action, uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            authority.currentAction();
        require(
            !active && action == 0 && cls == 0 && scope == 0 && oldHash == 0 && newHash == 0,
            "all-zero actual55 context without persistent mock"
        );
    }

    function _govern(bytes memory data, AD.Context memory c, bytes32 reason, uint8 cls)
        internal
        returns (bytes32 action)
    {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:accepted-generation:typed-governance"
        );
        action = keccak256(
            abi.encode("scoped original action", address(ingress), ++actionNonce, data, c)
        );
        authority.executeModuleContextWithAction(
            action, address(ingress), data, cls, c.scopeHash, c.oldValueHash, c.newValueHash
        );
    }

    function _mdSigned(uint256 collection, uint8 action, bytes32 label, bool direct)
        internal
        returns (bytes32 hash)
    {
        T.Binding memory b = Binding(suite.owners[0]).binding(collection);
        AD.Head memory head = ingress.attributionDispute(collection, b.generation);
        bytes32 evidence = _mdEvidence(collection, head.disputeRecordHash, label);
        AD.Filing memory filing = AD.Filing(collection, b.generation, action, evidence, evidence);
        AD.Standing memory standing = AD.Standing(artistId, b.generation, 0, 0);
        T.Authorization memory authorization = T.Authorization(
            Identity(suite.owners[2]).identity(artistId).nonceHint,
            direct ? 0 : uint64(block.timestamp + 1 days),
            ""
        );
        bytes32 digest = ingress.attributionDisputeDigest(filing, authorization);
        if (!direct) authorization.signature = _signature(digest);
        bytes memory data = action == 1
            ? abi.encodeCall(Disputes.openAttributionDispute, (filing, standing, authorization))
            : action == 3
                ? abi.encodeCall(Disputes.recordCounterStatement, (filing, standing, authorization))
                : abi.encodeCall(
                    Withdrawal.withdrawAttributionDispute, (filing, standing, authorization)
                );
        uint256 nativeBefore = Native(suite.owners[2]).artistNativeReceiptCount();
        if (direct) {
            require(this.rhExecuteNewSafe(address(ingress), data), "actual direct Safe dispute");
        } else {
            _artistCall(data);
        }
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == nativeBefore,
            "signed authorization has zero Identity native record"
        );
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DISPUTE_RECORD_V1"),
                block.chainid,
                address(ingress),
                collection,
                b.generation,
                action,
                address(artist),
                uint8(1),
                evidence,
                evidence,
                authorization.nonce,
                uint64(block.timestamp)
            )
        );
        AD.Record memory actual = ingress.attributionDisputeRecord(hash);
        require(
            actual.recordHash == hash && actual.nonce == authorization.nonce
                && actual.authorityClass == 1,
            "literal original signed record"
        );
        require(
            keccak256(Identity(suite.owners[2]).signatureBundle(hash))
                == keccak256(authorization.signature),
            "original signed or empty-direct signature"
        );
        _rhAuthorization(digest, authorization.nonce);
        _rhCandidate(
            4,
            action == 1
                ? "attribution_lifecycle.replay.dispute_key"
                : action == 3
                    ? "attribution_lifecycle.replay.counter_statement_key"
                    : "attribution_lifecycle.replay.dispute_withdrawal_key",
            action == 2
                ? head.disputeRecordHash
                : keccak256(
                    abi.encode(
                        collection,
                        b.generation,
                        action == 1 ? bytes32(0) : head.disputeRecordHash,
                        address(artist),
                        evidence,
                        evidence
                    )
                )
        );
        nextNonce = Identity(suite.owners[2]).identity(artistId).nonceHint;
    }

    function _mdStage(uint256 collection, bytes32 reason, bool direct)
        internal
        returns (RP.Record memory record)
    {
        T.Binding memory b = Binding(suite.owners[0]).binding(collection);
        AD.Filing memory filing = AD.Filing(collection, b.generation, 4, 0, reason);
        T.Authorization memory authorization = T.Authorization(
            Identity(suite.owners[2]).identity(artistId).nonceHint,
            direct ? 0 : uint64(block.timestamp + 1 days),
            ""
        );
        bytes32 digest = ingress.attributionRepudiationDigest(filing, authorization);
        if (!direct) authorization.signature = _signature(digest);
        bytes memory data = abi.encodeCall(Repudiation.revokeAttribution, (filing, authorization));
        uint256 before_ = Native(suite.owners[2]).artistNativeReceiptCount();
        if (direct) {
            require(this.rhExecuteNewSafe(address(ingress), data), "actual Safe repudiation");
        } else {
            _artistCall(data);
        }
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == before_,
            "47 has zero Identity native occurrence"
        );
        bytes32 hash = RepudiationOwner(suite.owners[4]).rawPendingRepudiation(collection);
        record = ingress.attributionRepudiationRecord(hash);
        require(
            record.recordHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ATTRIBUTION_REPUDIATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        collection,
                        b.generation,
                        artistId,
                        address(artist),
                        uint8(1),
                        filing.evidenceHash,
                        reason,
                        authorization.nonce,
                        uint64(block.timestamp),
                        record.executableAt
                    )
                ),
            "literal original repudiation"
        );
        _rhAuthorization(digest, authorization.nonce);
        _rhCandidate(4, "attribution_lifecycle.replay.repudiation_key", hash);
        nextNonce = Identity(suite.owners[2]).identity(artistId).nonceHint;
    }

    function _mdCancel(uint256 collection, RP.Record memory record) internal {
        require(
            this.rhExecuteNewSafe(
                address(ingress),
                abi.encodeCall(
                    Repudiation.cancelAttributionRepudiation, (collection, record.recordHash)
                )
            ),
            "actual signer cancel"
        );
        _rhCandidate(
            4, "attribution_lifecycle.replay.repudiation_cancellation_key", record.recordHash
        );
    }

    function _mdExecute(uint256 collection, RP.Record memory record) internal {
        vm.warp(record.executableAt);
        ingress.executeAttributionRepudiation(collection, record.recordHash);
        _rhCandidate(4, "attribution_lifecycle.replay.repudiation_execution_key", record.recordHash);
    }

    function _mdResolve(uint256 collection, uint8 choice, uint8 cls)
        internal
        returns (bytes32 action)
    {
        T.Binding memory b = Binding(suite.owners[0]).binding(collection);
        AD.Head memory h = ingress.attributionDispute(collection, b.generation);
        bytes32 evidence = _mdEvidence(
            collection, h.disputeRecordHash, keccak256(abi.encode("resolution", ++actionNonce))
        );
        AD.ResolutionRequest memory resolution = AD.ResolutionRequest(
            collection,
            b.generation,
            h.disputeRecordHash,
            choice,
            evidence,
            evidence,
            h.counterStatementRecordHash
        );
        action = _govern(
            abi.encodeCall(Disputes.resolveAttributionDispute, (resolution)),
            ingress.attributionDisputeResolutionContext(resolution),
            evidence,
            cls
        );
        _rhCandidate(4, "attribution_lifecycle.replay.dispute_resolution_key", h.disputeRecordHash);
        _rhCandidate(4, "attribution_lifecycle.replay.governance_action", action);
    }

    function _mdCorrect(uint256 collection, bytes32 witness) internal {
        _mdCorrectWithAcceptance(collection, witness, true);
    }

    function _mdCorrectWithAcceptance(uint256 collection, bytes32 witness, bool acceptNew)
        internal
    {
        T.Binding memory previous = Binding(suite.owners[0]).binding(collection);
        T.Identity memory identity = Identity(suite.owners[2]).identity(artistId);
        T.BindingProposal memory proposal = _proposal(artistId);
        proposal.identityRecordHash = identity.identityRecordHash;
        proposal.reasonHash = keccak256(abi.encode("fresh exact corrective1", previous.generation));
        bytes memory document =
            Identity(suite.owners[2]).identityDocumentBytes(identity.identityRecordHash);
        (BC.Context memory c,) =
            Admission.context(suite, collection, proposal, document, identity.displayName, witness);
        ArtistUnitRoles(suite.roleRegistry).setAdmin(manager.governanceAuthority(), true);
        bytes32 action = _govern(
            abi.encodeCall(
                Correction.proposeArtistBindingAfterRevocation,
                (collection, proposal, document, identity.displayName, witness)
            ),
            AD.Context(c.scopeHash, c.oldValueHash, c.newValueHash, 2, 0),
            proposal.reasonHash,
            2
        );
        _rhCandidate(0, "binding_lifecycle.replay.correction_action", action);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_key",
            keccak256(abi.encode(collection, previous.generation + 1))
        );
        if (!acceptNew) return;
        T.Authorization memory authorization = _authorization(false);
        bytes32 digest = ingress.acceptanceDigest(collection, authorization);
        authorization.signature = _signature(digest);
        _rhAuthorization(digest, authorization.nonce);
        _artistCall(
            abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (collection, authorization))
        );
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(collection, previous.generation + 1, uint8(1), address(artist)))
        );
    }

    function _mdVeto(uint256 collection, RP.Record memory staged)
        internal
        returns (bytes32 contest)
    {
        bytes32 reason = keccak256("guardian veto after recovered original authority");
        uint256 before_ = Native(suite.owners[2]).artistNativeReceiptCount();
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(
                    Repudiation.vetoAttributionRepudiation, (collection, staged.recordHash, reason)
                ),
                0
            ),
            "actual guardian Safe48"
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == before_ + 2,
            "exact paired48 native receipts"
        );
        contest = ingress.currentIdentityContestCause(artistId).facts.referenceHash;
        require(
            Native(suite.owners[2]).artistNativeReceiptAt(before_).operation == 48
                && Native(suite.owners[2]).artistNativeReceiptAt(before_).recordHash == contest
                && Native(suite.owners[2]).artistNativeReceiptAt(before_ + 1).operation == 48
                && Native(suite.owners[2]).artistNativeReceiptAt(before_ + 1).recordHash
                    == ingress.currentIdentityContestCause(artistId).causeHash,
            "original Contest then Cause pair"
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(
                abi.encode(keccak256("subject"), artistId, bytes32(0), staged.recordHash, reason)
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(abi.encode(keccak256("record"), contest))
        );
        _rhCandidate(4, "attribution_lifecycle.replay.repudiation_veto_key", staged.recordHash);
    }

    function _mdDelegated(uint256 collection, uint8 action, bytes32 grant, uint256 nonce)
        internal
        returns (bytes32 record)
    {
        T.Binding memory binding = Binding(suite.owners[0]).binding(collection);
        bytes32 opening =
            ingress.attributionDispute(collection, binding.generation).disputeRecordHash;
        bytes32 evidence =
            _mdEvidence(collection, opening, keccak256(abi.encode("delegate", action, nonce)));
        AD.Filing memory filing =
            AD.Filing(collection, binding.generation, action, evidence, evidence);
        AD.Standing memory standing = AD.Standing(artistId, binding.generation, 0, grant);
        T.Authorization memory a = T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.attributionDisputeDigest(filing, a);
        a.signature = _delegateSignature(digest);
        if (action == 1) {
            record = ingress.openAttributionDispute(filing, standing, a);
        } else {
            record = Withdrawal(address(ingress)).withdrawAttributionDispute(filing, standing, a);
        }
        bytes32 lane = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                artistId,
                address(delegateSafe)
            )
        );
        _rhCandidate(
            2, "identity_authority.replay.delegated_nonce", keccak256(abi.encode(lane, nonce))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _rhCandidate(
            4,
            action == 1
                ? "attribution_lifecycle.replay.dispute_key"
                : "attribution_lifecycle.replay.dispute_withdrawal_key",
            action == 1
                ? keccak256(
                    abi.encode(
                        collection,
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
            ingress.attributionDisputeRecord(record).standing.delegation == grant,
            "saved historical grant"
        );
    }

    function _mdAssertHistory(
        uint256 collection,
        T.SuiteConfiguration memory target,
        D.Bundle memory b
    ) internal view {
        (uint8 state, uint64 generation) = IStreamArtistAttributionOwner(target.owners[4])
            .attributionState(collection);
        require(
            state == b.current.state && generation == b.current.generation,
            "exact current open/revoked/accepted state"
        );
        for (uint256 i; i < b.heads.length; ++i) {
            require(
                keccak256(
                    abi.encode(
                        DisputeOwner(target.owners[4]).attributionDispute(collection, uint64(i + 1))
                    )
                ) == keccak256(abi.encode(b.heads[i])),
                "full original head"
            );
        }
        for (uint256 i; i < b.disputes.length; ++i) {
            AD.Record memory row = b.disputes[i].record;
            require(
                keccak256(
                    abi.encode(
                        DisputeOwner(target.owners[4]).attributionDisputeRecord(row.recordHash)
                    )
                ) == keccak256(abi.encode(row)),
                "original full dispute row"
            );
            require(
                keccak256(
                    abi.encode(
                        WithdrawalOwner(target.owners[4])
                            .attributionDisputeWithdrawal(row.recordHash)
                    )
                ) == keccak256(abi.encode(b.disputes[i].withdrawal)),
                "original immutable withdrawal"
            );
            if (row.governanceActionId == 0) {
                require(
                    keccak256(Identity(target.owners[2]).signatureBundle(row.recordHash))
                        == keccak256(Identity(suite.owners[2]).signatureBundle(row.recordHash)),
                    "full original signature"
                );
            }
        }
        for (uint256 i; i < b.resolutions.length; ++i) {
            require(
                keccak256(
                    abi.encode(
                        DisputeOwner(target.owners[4])
                            .attributionDisputeResolution(b.resolutions[i].record.actionId)
                    )
                ) == keccak256(abi.encode(b.resolutions[i].record)),
                "immutable original resolution action"
            );
        }
        for (uint256 i; i < b.repudiations.length; ++i) {
            RP.Record memory row = b.repudiations[i].record;
            require(
                keccak256(
                    abi.encode(
                        RepudiationOwner(target.owners[4])
                            .attributionRepudiationRecord(row.recordHash)
                    )
                ) == keccak256(abi.encode(row)),
                "complete original staged authority head"
            );
            require(
                keccak256(
                    abi.encode(
                        RepudiationOwner(target.owners[4])
                            .attributionRepudiationTerminal(row.recordHash)
                    )
                ) == keccak256(abi.encode(b.repudiations[i].terminal)),
                "original terminal"
            );
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(row.recordHash))
                    == keccak256(Identity(suite.owners[2]).signatureBundle(row.recordHash)),
                "original repudiation signature"
            );
        }
        require(
            RepudiationOwner(target.owners[4]).rawPendingRepudiation(collection) == b.pending,
            "original pending pointer"
        );
    }

    function _mdEvidence(uint256 collection, bytes32 parent, bytes32 narrative)
        internal
        returns (bytes32 hash)
    {
        if (address(documents) == address(0)) {
            documents = StreamSchemaDocumentStore(
                payable(_artistArtifactCreate(
                        "smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol:StreamSchemaDocumentStore",
                        abi.encode()
                    ))
            );
        }
        T.Binding memory b = Binding(suite.owners[0]).binding(collection);
        bytes memory data =
            abi.encode(AD.Evidence(1, collection, b.generation, b.bindingHash, parent, narrative));
        (hash,) = documents.publishChunk(data);
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionMetadataV1.core, ()),
            abi.encode(address(core))
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamCollectionMetadataV1.chunkStore, ()),
            abi.encode(address(documents))
        );
        Archival.CoverageFacts memory f;
        f.coverageRecordHash = keccak256(abi.encode("typed original coverage", hash));
        f.envelopeHash = keccak256(abi.encode("typed original envelope", hash));
        f.evidenceHash = hash;
        avm.mockCall(
            address(estateCoverageProvider),
            abi.encodeCall(
                IStreamCollectionArchivalCoverage.requireCollectionEvidence, (collection, hash)
            ),
            abi.encode(f)
        );
    }

    function _maCredential(
        uint256 collection,
        bytes32 previous,
        bytes32 grant,
        uint256 nonce,
        bool safe
    ) internal returns (bytes32) {
        C2PA.Credential[] memory items = new C2PA.Credential[](1);
        items[0] = C2PA.Credential(1, keccak256("aggregate SPKI"), keccak256("aggregate key"), 1, 0);
        bytes memory statement = abi.encode(
            C2PA.Payload(1, artistId, ingress.operativeIdentityRecord(artistId), previous, items)
        );
        T.Attestation memory terms = T.Attestation(
            collection,
            10,
            artistId,
            ingress.operativeIdentityRecord(artistId),
            CREDENTIAL_SCHEMA,
            keccak256(statement),
            "urn:aggregate:credential"
        );
        return _maWrite(terms, statement, grant, nonce, safe);
    }

    function _maWrite(
        T.Attestation memory terms,
        bytes memory statement,
        bytes32 grant,
        uint256 nonce,
        bool safe
    ) internal returns (bytes32 record) {
        T.Authorization memory a = grant == 0
            ? _authorization(true)
            : T.Authorization(nonce, uint64(block.timestamp), "");
        bytes32 digest = ingress.attestationDigest(terms, a);
        address signer = grant == 0 ? address(artist) : address(delegateSafe);
        uint8 class_ = grant == 0
            ? IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).authorityClass
            : 2;
        record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"),
                block.chainid,
                address(ingress),
                address(core),
                terms.collectionId,
                terms.subjectKind,
                terms.subjectId,
                terms.subjectStateHash,
                terms.schemaId,
                terms.statementHash,
                keccak256(bytes(terms.statementURI)),
                artistId,
                signer,
                class_,
                a.nonce,
                a.time
            )
        );
        if (safe) {
            require(grant == 0, "direct original Safe fixture");
            require(
                executeSafe(
                    artist,
                    keys,
                    address(ingress),
                    0,
                    abi.encodeCall(
                        IStreamArtistOnboarding.recordArtistAttestation, (terms, a, statement)
                    ),
                    0
                ),
                "original op24 Safe"
            );
        } else {
            a.signature = grant == 0 ? _signature(digest) : _delegateSignature(digest);
            bytes32 actual = grant == 0
                ? ingress.recordArtistAttestation(terms, a, statement)
                : ingress.recordDelegatedArtistAttestation(terms, grant, a, statement);
            require(actual == record, "literal original24 domain/preimage");
        }
        require(
            Attribution(suite.owners[4]).attestationRecord(record).recordHash == record,
            "actual native record"
        );
        _mcRemember(record, digest, a, grant != 0);
        if (grant == 0) {
            _rhCandidate(
                2, "identity_authority.replay.attestation_key", keccak256(abi.encode(record))
            );
        }
        maRows.push(Saved(Ready.AttestationInput(terms, a.nonce), record, statement, a, class_));
    }

    function _maSemantics(T.SuiteConfiguration memory s) internal view returns (bytes32 h) {
        for (uint256 i; i < maRows.length; ++i) {
            bytes32 record = maRows[i].record;
            T.Attestation memory terms = maRows[i].input.terms;
            h = keccak256(
                abi.encode(
                    h,
                    Attribution(s.owners[4]).attestationRecord(record),
                    Classes(s.owners[4]).attestationAuthorityClass(record),
                    Associations(s.owners[4]).attestationAssociation(record),
                    Attribution(s.owners[4]).statementBytes(terms.statementHash),
                    AttestationPublications(s.owners[4]).publicationAttestation(record),
                    Credentials(s.owners[4]).c2paCredentialRecord(record),
                    Personhood(s.owners[4]).personhoodProofSummary(record),
                    Personhood(s.owners[4]).personhoodProofSummaryHash(record),
                    Attribution(s.owners[4])
                        .attestation(terms.collectionId, terms.subjectKind, terms.subjectId)
                )
            );
        }
        for (uint256 a; a < multiArtists.length; ++a) {
            h = keccak256(
                abi.encode(h, Credentials(s.owners[4]).c2paCredentialHead(multiArtists[a]))
            );
        }
        for (uint256 k; k < 2; ++k) {
            h = keccak256(
                abi.encode(
                    h,
                    Credentials(s.owners[4]).personhoodAttestation(k + 1, multiCollectionArtists[k])
                )
            );
        }
    }

    function _mdSource(bool shared) internal {
        _multiSource(shared, false);
        if (!shared) {
            _adoptRotatedSafe();
            vm.warp(ingress.artistTransitionState(multiRecovery[1]).postWindowEndsAt);
        }
        mdSecondKeys = keys;
        mdFirstKeys = new uint256[](2);
        mdFirstKeys[0] = 0xCA1100 + 36001;
        mdFirstKeys[1] = 0xCA2200 + 36001;
        _mdSelect(1);
    }

    function _mdSelect(uint256 collection) internal {
        artistId = multiCollectionArtists[collection - 1];
        artist = OfficialSafe(multiAuthorities[collection - 1]);
        keys = collection == 1 ? mdFirstKeys : mdSecondKeys;
        rotationSafe = artist;
        rotationKeys = keys;
        nextNonce = Identity(suite.owners[2]).identity(artistId).nonceHint;
    }

    function _mdFamilies(bytes32 grant) internal {
        mcSale = new RecoveredDelegationSaleFacts(address(core));
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(mcSale),
            mcSale.streamModuleType(),
            mcSale.streamModuleInterfaceId()
        );
        _mcPolicy(1, grant, 257, true);
        _mcPolicy(2, grant, 0, false);
        _mcEconomics(grant, 1);
        _mcSale(grant, 2);
        _mcContentAndFreeze();
        _mcRoyalty(grant, 3);
        mdRoyalties.push(mcRoyalty);
    }

    function _mdPrepare(Successor memory next)
        internal
        view
        returns (RH.Request memory r, Commit.Prepared memory p)
    {
        r = _multiRequest();
        MR.CollectionWitness[] memory pending = new MR.CollectionWitness[](2);
        uint256 witnessCount;
        for (uint256 k; k < 2; ++k) {
            uint256 n = 1;
            for (uint256 j; j < mcPolicies.length; ++j) {
                if (mcPolicies[j].collectionId == k + 1) ++n;
            }
            AH.PolicyKey[] memory selected = new AH.PolicyKey[](n);
            selected[0] = AH.PolicyKey(PHASE, multiPolicies[k]);
            n = 1;
            for (uint256 j; j < mcPolicies.length; ++j) {
                if (mcPolicies[j].collectionId == k + 1) {
                    selected[n++] = AH.PolicyKey(mcPolicies[j].phaseId, mcPolicies[j].policyHash);
                }
            }
            r.records.authority.collections[k].policies = selected;
            MR.CollectionWitness memory w;
            w.collectionId = k + 1;
            w.economics = new T.EconomicsConsent[](k == 0 && mcEconomicsRecord != 0 ? 1 : 0);
            if (w.economics.length != 0) w.economics[0] = mcEconomics;
            n = 0;
            for (uint256 j; j < maRows.length; ++j) {
                if (maRows[j].input.terms.collectionId == k + 1) ++n;
            }
            w.attestations = new Ready.AttestationInput[](n);
            n = 0;
            for (uint256 j; j < maRows.length; ++j) {
                if (maRows[j].input.terms.collectionId == k + 1) {
                    w.attestations[n++] = maRows[j].input;
                }
            }
            if (w.attestations.length != 0 || w.economics.length != 0) pending[witnessCount++] = w;
        }
        r.records.witnesses = new MR.CollectionWitness[](witnessCount);
        for (uint256 j; j < witnessCount; ++j) {
            r.records.witnesses[j] = pending[j];
        }
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), r, mdRoyalties);
        r.expectedSemanticInventory = Prepared.inventory(p);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h, Payload.Payload memory local) =
                Payload.decode(p.data[i].typedState, i);
            require((h.requiredFeatures & MD.FEATURE) != 0, "seven owner new feature");
            (M.State memory scope, bytes memory auxiliary) =
                ConsentCodec.decodeAuxiliary(i, local.semanticState, local.provenance);
            require(
                keccak256(local.semanticState)
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_MULTIPLE_DISPUTE_HISTORY_V1"),
                            uint16(1),
                            i,
                            scope,
                            auxiliary
                        )
                    ),
                "literal new canonical tag/version"
            );
        }
    }

    function _mdHistory(Commit.Prepared memory p) internal pure returns (D.Bundle[] memory all) {
        (, Payload.Payload memory local) = Payload.decode(p.data[4].typedState, 4);
        M.State memory scope = ConsentCodec.decode(4, local.semanticState, local.provenance);
        all = new D.Bundle[](scope.rows.length);
        for (uint256 k; k < all.length; ++k) {
            all[k] = abi.decode(scope.rows[k], (MD.Attribution)).history;
        }
    }

    function _mdImport(Successor memory next, RH.Request memory r, Commit.Prepared memory p)
        internal
    {
        dv.recordLogs();
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(
                    ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, mdRoyalties)
                )
            ),
            "actual Safe whole-owner op60"
        );
        _multiAssert(next, p);
        _mdAssertArchive(next, r, p, dv.getRecordedLogs());
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        D.Bundle[] memory all = _mdHistory(p);
        for (uint256 k; k < all.length; ++k) {
            _mdAssertHistory(k + 1, target, all[k]);
        }
        require(
            _maSemantics(target) == _maSemantics(suite),
            "original op24 bodies and per-Artist C2PA order"
        );
        require(_mcSemantics(target) == _mcSemantics(suite), "complete consent family records");
        for (uint256 j; j < mcGrants.length; ++j) {
            require(
                keccak256(abi.encode(next.registry.delegationRecord(mcGrants[j])))
                    == keccak256(abi.encode(ingress.delegationRecord(mcGrants[j]))),
                "global historical grant uses"
            );
        }
    }

    function _mdState(Successor memory next, Commit.Prepared memory p)
        internal
        view
        returns (bytes32 h)
    {
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        h = keccak256(
            abi.encode(_multiDestinationHash(next), _maSemantics(target), _mcSemantics(target))
        );
        D.Bundle[] memory all = _mdHistory(p);
        for (uint256 k; k < all.length; ++k) {
            D.Bundle memory b = all[k];
            (uint8 state, uint64 generation) =
                IStreamArtistAttributionOwner(target.owners[4]).attributionState(k + 1);
            h = keccak256(
                abi.encode(
                    h,
                    state,
                    generation,
                    RepudiationOwner(target.owners[4]).rawPendingRepudiation(k + 1)
                )
            );
            for (uint256 j; j < b.heads.length; ++j) {
                h = keccak256(
                    abi.encode(
                        h, DisputeOwner(target.owners[4]).attributionDispute(k + 1, uint64(j + 1))
                    )
                );
            }
            for (uint256 j; j < b.disputes.length; ++j) {
                h = keccak256(
                    abi.encode(
                        h,
                        DisputeOwner(target.owners[4])
                            .attributionDisputeRecord(b.disputes[j].record.recordHash),
                        WithdrawalOwner(target.owners[4])
                            .attributionDisputeWithdrawal(b.disputes[j].record.recordHash)
                    )
                );
            }
            for (uint256 j; j < b.resolutions.length; ++j) {
                h = keccak256(
                    abi.encode(
                        h,
                        DisputeOwner(target.owners[4])
                            .attributionDisputeResolution(b.resolutions[j].record.actionId)
                    )
                );
            }
            for (uint256 j; j < b.repudiations.length; ++j) {
                h = keccak256(
                    abi.encode(
                        h,
                        RepudiationOwner(target.owners[4])
                            .attributionRepudiationRecord(b.repudiations[j].record.recordHash),
                        RepudiationOwner(target.owners[4])
                            .attributionRepudiationTerminal(b.repudiations[j].record.recordHash)
                    )
                );
            }
        }
        for (uint256 j; j < mcGrants.length; ++j) {
            h = keccak256(abi.encode(h, next.registry.delegationRecord(mcGrants[j])));
        }
    }

    function _mdAssertArchive(
        Successor memory next,
        RH.Request memory r,
        Commit.Prepared memory p,
        MultipleDisputeTestVm.Log[] memory logs
    ) private view {
        bytes32 value = keccak256(
            abi.encode(
                RH.PROFILE,
                uint16(1),
                block.chainid,
                address(next.registry),
                address(next.coordinator),
                p.admission.prior,
                p.admission.sourceCoordinator,
                r,
                p.admission.artists,
                p.admission.collections,
                p.query,
                p.data,
                p.timing,
                p.externalGuards,
                p.admission.before_
            )
        );
        require(
            HydrationOwner(next.identity).authorityHydrationCommitment() == value,
            "independent complete original op60 value"
        );
        bytes memory profile = abi.encode(
            RH.PROFILE,
            uint16(1),
            p.admission.prior,
            p.admission.sourceCoordinator,
            r,
            p.admission.artists,
            p.admission.collections,
            p.query,
            p.data,
            p.timing,
            p.externalGuards
        );
        Evidence.Descriptor memory descriptor = Evidence.describe(profile);
        T.Snapshot[7] memory after_;
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        for (uint8 i; i < 7; ++i) {
            after_[i] = OriginalOwner(target.owners[i]).ownerStateSnapshotV2();
        }
        bytes memory expected = abi.encode(
            uint16(1),
            next.coordinator.configurationHash(),
            uint16(60),
            address(rotationSafe),
            value,
            p.admission.before_,
            after_,
            abi.encode(RH.PROFILE, descriptor)
        );
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(next.registry),
                address(next.coordinator),
                uint16(60),
                address(rotationSafe),
                value
            )
        );
        require(
            keccak256(Archive(target.archive).artistEvidenceBytesV2(id, 1)) == keccak256(expected),
            "exact owner snapshots and original evidence carrier"
        );
        require(
            keccak256(
                Evidence.read(
                    target.archive,
                    address(next.registry),
                    address(next.coordinator),
                    value,
                    descriptor
                )
            ) == keccak256(profile),
            "all original profile bytes retained in Archive"
        );
        uint256 seen;
        for (uint256 i; i < logs.length; ++i) {
            MultipleDisputeTestVm.Log memory item = logs[i];
            if (
                item.emitter != address(next.coordinator) || item.topics.length != 4
                    || item.topics[0]
                        != keccak256(
                            "RecoveredArtistAuthorityHydrated(uint16,address,bytes32,bytes32,bytes32)"
                        )
            ) continue;
            require(
                item.topics[1] == bytes32(uint256(uint160(p.admission.prior)))
                    && item.topics[2] == value && item.topics[3] == r.expectedSemanticInventory
                    && keccak256(item.data) == keccak256(abi.encode(uint16(1), keccak256(profile))),
                "literal original hydration event"
            );
            ++seen;
        }
        require(seen == 1, "one original op60 event after complete Archive append");
    }
}
