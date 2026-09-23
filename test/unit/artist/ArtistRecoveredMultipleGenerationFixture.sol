// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistExtendedHydrationFeatures as XF
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistExtendedHydrationFeatures.sol";
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
    StreamArtistDelegationTypes as D
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
    IStreamArtistContentAuthority
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    IStreamArtistRecoveredConsentHydration as ConsentHydration
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredConsentHydration.sol";
import {
    StreamArtistRecoveredMultipleGenerationCodec as ConsentCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleGenerationCodec.sol";
import {
    StreamArtistRecoveredMultipleConsentNonces as ConsentNonces
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleConsentNonces.sol";
import {
    StreamArtistRecoveredMultipleConsentFacts as ConsentFacts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleConsentFacts.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";

import {
    StreamArtistEconomicsAssociation as EconomicsAssociation
} from "../../../smart-contracts/domains/artist/StreamArtistEconomicsAssociation.sol";

/// @notice Real seven-owner histories and Safe calls; Core/governance and immutable sale facts
/// retain the explicit inherited unit boundaries. Authored scenarios require native execution.
abstract contract ArtistRecoveredMultipleGenerationFixture is ArtistRecoveredMultipleFixture {
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
        return XF.MULTIPLE_GENERATIONS;
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

    function _maShared(bytes32 grant) internal virtual;

    function _mcSource() internal {
        _mcSource(true);
    }

    function _mcSource(bool delegated) internal {
        _multiSource(true, false);
        mcSale = new RecoveredDelegationSaleFacts(address(core));
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(mcSale),
            mcSale.streamModuleType(),
            mcSale.streamModuleInterfaceId()
        );
        bytes32 grant = delegated ? _mcGrant(7) : bytes32(0);
        _mcPolicy(1, grant, 257, true);
        _mcPolicy(2, grant, 0, false);
        if (delegated) {
            // The same delegate nonce cannot be consumed again in a different collection.
            T.PolicyConsent memory duplicate = T.PolicyConsent(
                2, keccak256("cross duplicate"), keccak256("cross duplicate policy")
            );
            T.Authorization memory retry = T.Authorization(257, type(uint64).max, "");
            retry.signature = _delegateSignature(ingress.policyConsentDigest(duplicate, retry));
            (bool ok,) = address(ingress)
                .call(
                    abi.encodeCall(
                        IStreamArtistDelegatedConsent.recordDelegatedPolicyConsent,
                        (duplicate, grant, retry)
                    )
                );
            require(
                !ok && ingress.delegationRecord(grant).uses == 2,
                "cross-collection replay preserves global uses"
            );
        }
        _mcEconomics(grant, 1);
        _mcSale(grant, 2);
        _mcContentAndFreeze();
        _mcRoyalty(grant, 3);
        _maShared(grant);
        if (delegated) {
            require(ingress.delegationRecord(grant).uses == 7, "full cross-family grant use bound");
            _mcRevoke(grant);
            _mcGrant(0);
        }
    }

    function _mcGrant(uint64 maxUses) internal returns (bytes32 record) {
        D.Grant memory g = _delegation(
            0,
            D.POLICY_CONSENT | D.ECONOMICS | D.ROYALTY_FREEZE | D.SALE_CONSENT | D.ATTEST,
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
        D.Revocation memory g =
            D.Revocation(artistId, address(delegateSafe), grant, keccak256("aggregate revocation"));
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

    function _mcRoyalties() internal view returns (T.RoyaltyFreeze[] memory terms) {
        terms = new T.RoyaltyFreeze[](1);
        terms[0] = mcRoyalty;
    }

    function _mcPrepare(Successor memory next)
        internal
        view
        returns (RH.Request memory r, Commit.Prepared memory p)
    {
        r = _multiRequest();
        for (uint256 i; i < 2; ++i) {
            AH.PolicyKey[] memory keys_ = new AH.PolicyKey[](2);
            keys_[0] = AH.PolicyKey(PHASE, multiPolicies[i]);
            keys_[1] = AH.PolicyKey(mcPolicies[i].phaseId, mcPolicies[i].policyHash);
            r.records.authority.collections[i].policies = keys_;
        }
        r.records.witnesses = new MR.CollectionWitness[](1);
        r.records.witnesses[0].collectionId = 1;
        r.records.witnesses[0].economics = new T.EconomicsConsent[](1);
        r.records.witnesses[0].economics[0] = mcEconomics;
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), r, _mcRoyalties());
        r.expectedSemanticInventory = Prepared.inventory(p);
    }

    function _mcAssert(Successor memory next, Commit.Prepared memory p) internal view {
        _multiAssert(next, p);
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        for (uint256 i; i < mcGrants.length; ++i) {
            require(
                keccak256(abi.encode(next.registry.delegationRecord(mcGrants[i])))
                    == keccak256(abi.encode(ingress.delegationRecord(mcGrants[i]))),
                "every retained grant version/use/revocation preserved"
            );
        }
        if (mcGrants.length != 0) {
            require(
                next.registry.delegationRecord(mcGrants[0]).uses == 7
                    && next.registry.delegationRecord(mcGrants[0]).revoked
                    && next.registry.delegationRecord(mcGrants[1]).uses == 0,
                "exhausted revoked and unused replacement remain distinct"
            );
        }
        for (uint256 i; i < mcRecords.length; ++i) {
            require(
                keccak256(
                        IStreamArtistIdentityOwner(target.owners[2]).signatureBundle(mcRecords[i])
                    ) == keccak256(mcSignatures[i]),
                "exact original signatures"
            );
            require(
                next.registry.recordDelegation(mcRecords[i])
                    == ingress.recordDelegation(mcRecords[i]),
                "unchanged authentic grant association"
            );
        }
        require(
            _mcSemantics(target) == _mcSemantics(suite),
            "all consent bodies, heads and associations match original owners"
        );
        if (mcGrants.length != 0) {
            for (uint256 i; i < 4; ++i) {
                (bool used,) = next.registry.delegatedNonceState(artistId, address(delegateSafe), i);
                require(used, "global original delegate nonce remains consumed");
            }
            (bool used257,) =
                next.registry.delegatedNonceState(artistId, address(delegateSafe), 257);
            require(used257, "independent high prefix remains consumed");
        }
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

    function _mcHash(Successor memory next) internal view returns (bytes32 h) {
        T.SuiteConfiguration memory s = next.coordinator.suiteConfiguration();
        h = keccak256(abi.encode(_multiDestinationHash(next), _mcSemantics(s)));
        for (uint256 i; i < mcGrants.length; ++i) {
            h = keccak256(abi.encode(h, next.registry.delegationRecord(mcGrants[i])));
        }
        for (uint256 i; i < mcRecords.length; ++i) {
            h = keccak256(
                abi.encode(
                    h,
                    next.registry.recordDelegation(mcRecords[i]),
                    IStreamArtistIdentityOwner(s.owners[2]).signatureBundle(mcRecords[i])
                )
            );
        }
    }

    function _mcBadFacts(
        M.State memory ids,
        ContentH.Bundle[] memory rows,
        bytes[] memory bindings,
        RH.Provenance memory p
    ) internal view {
        (bool ok,) = address(ConsentFacts)
            .staticcall(
                abi.encodeWithSelector(
                    ConsentFacts.validate.selector, ids.rows, ids, rows, bindings, p
                )
            );
        require(!ok, "global per-version count mismatch rejected");
    }

    function _mcBadRequest(Successor memory next, RH.Request memory r) internal {
        (bool ok,) = address(next.registry)
            .call(
                abi.encodeCall(
                    ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents,
                    (r, _mcRoyalties())
                )
            );
        require(!ok, "incomplete graph refused");
    }
}
