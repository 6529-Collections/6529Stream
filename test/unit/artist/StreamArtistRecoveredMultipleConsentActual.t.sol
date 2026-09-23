// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistRecoveredMultipleFixture.sol";
import {
    StreamArtistContentTypes as Content
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    RecoveredDelegationSaleFacts
} from "./StreamArtistRecoveredDelegationAuthorityActual.t.sol";
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
    StreamArtistRecoveredMultipleConsentCodec as ConsentCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleConsentCodec.sol";
import {
    StreamArtistRecoveredMultipleConsentNonces as ConsentNonces
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleConsentNonces.sol";
import {
    StreamArtistRecoveredMultipleConsentFacts as ConsentFacts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredMultipleConsentFacts.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";

/// @notice Real seven-owner histories and Safe calls; Core/governance and immutable sale facts
/// retain the explicit inherited unit boundaries. Authored scenarios require native execution.
contract StreamArtistRecoveredMultipleConsentActualTest is ArtistRecoveredMultipleFixture {
    RecoveredDelegationSaleFacts private mcSale;
    bytes32[] private mcGrants;
    bytes32[] private mcRecords;
    bytes32[] private mcDigests;
    bytes[] private mcSignatures;
    T.PolicyConsent[] private mcPolicies;
    T.EconomicsConsent private mcEconomics;
    T.RoyaltyFreeze private mcRoyalty;
    Content.Consent private mcContent;
    Content.Freeze private mcFreeze;
    bytes32 private mcEconomicsRecord;
    bytes32 private mcSaleRecord;
    bytes32 private mcContentRecord;
    bytes32 private mcFreezeRecord;
    bytes32 private mcRoyaltyRecord;

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
        return RH.MULTIPLE_CONSENTS;
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

    function testMultipleConsentsAllFamiliesSharedGrantDirectImport() external {
        _mcSource();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mcPrepare(next);
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _mcRoyalties());
        _mcAssert(next, p);
    }

    function testMultipleConsentsAllDirectFamiliesWithoutRetainedGrants() external {
        _mcSource(false);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mcPrepare(next);
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _mcRoyalties());
        _mcAssert(next, p);
    }

    function testMultipleConsentsMixedClassOneClassThreeSafe() external {
        _multiSource(false, true);
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _multiPrepare(next);
        (RH.ExportHeader memory h,) = Payload.decode(p.data[2].typedState, 2);
        require(
            (h.requiredFeatures & (RH.MULTIPLE_CONSENTS | RH.CLASS_ONE | RH.CLASS_THREE))
                == (RH.MULTIPLE_CONSENTS | RH.CLASS_ONE | RH.CLASS_THREE),
            "actual mixed recovered classes"
        );
        uint256 n = rotationSafe.nonce();
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (r))
            ),
            "actual threshold Safe"
        );
        require(rotationSafe.nonce() == n + 1, "one Safe call");
        _multiAssert(next, p);
    }

    function testMultipleConsentsLateArchiveFailureRestoresEveryConsentGrantAndSafeNonce()
        external
    {
        _mcSource();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mcPrepare(next);
        bytes32 before_ = _mcHash(next);
        uint256 n = rotationSafe.nonce();
        uint256 originalBlock = block.number;
        bytes memory call_ = abi.encodeCall(
            ConsentHydration.hydrateRecoveredArtistAuthorityWithConsents, (r, _mcRoyalties())
        );
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _mcRoyalties());
        require(
            _mcHash(next) == before_,
            "all principals, original roots, signatures, grant versions and semantic maps rollback"
        );
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        require(rotationSafe.nonce() == n && _mcHash(next) == before_, "Safe atomic rollback");
        vm.roll(originalBlock);
        require(
            this.rhExecuteNewSafe(address(next.registry), call_), "same authentic aggregate retries"
        );
        _mcAssert(next, p);
    }

    function testMultipleConsentsGlobalUseEqualityRejectsPerCollectionResetAndDuplicateUse()
        external
    {
        _mcSource();
        Successor memory next = _multiCutover();
        (, Commit.Prepared memory p) = _mcPrepare(next);
        (, Payload.Payload memory ip) = Payload.decode(p.data[2].typedState, 2);
        M.State memory identities = ConsentCodec.decode(2, ip.semanticState, ip.provenance);
        (, Payload.Payload memory cp) = Payload.decode(p.data[6].typedState, 6);
        M.State memory consents = ConsentCodec.decode(6, cp.semanticState, cp.provenance);
        (, Payload.Payload memory bp) = Payload.decode(p.data[0].typedState, 0);
        M.State memory bindings = ConsentCodec.decode(0, bp.semanticState, bp.provenance);
        ContentH.Bundle[] memory rows = new ContentH.Bundle[](consents.rows.length);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = abi.decode(consents.rows[i], (ContentH.Bundle));
        }
        ConsentFacts.validate(
            identities.rows, identities, rows, bindings.rows, p.admission.provenance
        );
        bytes memory saved = identities.rows[0];
        IH.Bundle memory b = abi.decode(saved, (IH.Bundle));
        require(
            b.delegations[0].record.uses == 5,
            "one original grant shared across two collections and four delegated families"
        );
        b.delegations[0].record.uses = 4;
        identities.rows[0] = abi.encode(b);
        _mcBadFacts(identities, rows, bindings.rows, p.admission.provenance);
        b = abi.decode(saved, (IH.Bundle));
        b.delegations[0].record.uses = 6;
        identities.rows[0] = abi.encode(b);
        _mcBadFacts(identities, rows, bindings.rows, p.admission.provenance);
        identities.rows[0] = saved;
        ConsentFacts.validate(
            identities.rows, identities, rows, bindings.rows, p.admission.provenance
        );
    }

    function testMultipleConsentsRejectsOmittedCollectionWitnessAndStaleCompleteHeader() external {
        _mcSource();
        Successor memory next = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mcPrepare(next);
        bytes memory saved = abi.encode(r);
        bytes32 before_ = _mcHash(next);
        for (uint256 i; i < 7; ++i) {
            r = abi.decode(saved, (RH.Request));
            ++r.records.authority.expectedSource[i].ownerState.revision;
            _mcBadRequest(next, r);
        }
        r = abi.decode(saved, (RH.Request));
        r.expectedSourceImportCommitment = keccak256("stale prior import");
        _mcBadRequest(next, r);
        r = abi.decode(saved, (RH.Request));
        r.records.witnesses = new MR.CollectionWitness[](0);
        _mcBadRequest(next, r);
        r = abi.decode(saved, (RH.Request));
        r.records.authority.collections = new MH.Collection[](1);
        r.records.authority.collections[0] = MH.Collection(artistId, 1, new AH.PolicyKey[](0));
        _mcBadRequest(next, r);
        r = abi.decode(saved, (RH.Request));
        r.expectedSemanticInventory = bytes32(uint256(r.expectedSemanticInventory) ^ 1);
        _mcBadRequest(next, r);
        require(_mcHash(next) == before_, "partial declarations never write any owner");
        r = abi.decode(saved, (RH.Request));
        ConsentHydration(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _mcRoyalties());
        _mcAssert(next, p);
    }

    function testMultipleConsentsRepeatedImportRetainsOriginalDomainsAndGrantExhaustion() external {
        _mcSource();
        Successor memory first = _multiCutover();
        (RH.Request memory r, Commit.Prepared memory p) = _mcPrepare(first);
        ConsentHydration(address(first.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _mcRoyalties());
        _mcAssert(first, p);
        bytes32 journal = keccak256(abi.encode(p.admission.provenance.journals[6]));
        _rhAdopt(first);
        Successor memory second = _multiCutover();
        (r, p) = _mcPrepare(second);
        require(
            p.admission.provenance.eras.length == 2
                && keccak256(abi.encode(p.admission.provenance.journals[6])) == journal,
            "full original consent coordinates survive second import"
        );
        ConsentHydration(address(second.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(r, _mcRoyalties());
        _mcAssert(second, p);
    }

    function _mcSource() private {
        _mcSource(true);
    }

    function _mcSource(bool delegated) private {
        _multiSource(true, false);
        mcSale = new RecoveredDelegationSaleFacts(address(core));
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(mcSale),
            mcSale.streamModuleType(),
            mcSale.streamModuleInterfaceId()
        );
        bytes32 grant = delegated ? _mcGrant(5) : bytes32(0);
        _mcPolicy(1, grant, 257, true);
        _mcPolicy(2, grant, 0, false);
        if (delegated) {
            // The same delegate nonce cannot be consumed again in a different collection.
            T.PolicyConsent memory duplicate =
                T.PolicyConsent(
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
        if (delegated) {
            require(ingress.delegationRecord(grant).uses == 5, "full cross-family grant use bound");
            _mcRevoke(grant);
            _mcGrant(0);
        }
    }

    function _mcGrant(uint64 maxUses) private returns (bytes32 record) {
        D.Grant memory g = _delegation(
            0,
            D.POLICY_CONSENT | D.ECONOMICS | D.ROYALTY_FREEZE | D.SALE_CONSENT,
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

    function _mcRevoke(bytes32 grant) private {
        D.Revocation memory g =
            D.Revocation(artistId, address(delegateSafe), grant, keccak256("aggregate revocation"));
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.delegationRevocationDigest(g, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.revokeArtistDelegation(g, a);
        _mcRemember(record, digest, a, false);
        _rhCandidate(2, "identity_authority.replay.one_way_delegation_revocation", grant);
    }

    function _mcPolicy(uint256 collection, bytes32 grant, uint256 nonce, bool safe) private {
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

    function _mcEconomics(bytes32 grant, uint256 nonce) private {
        mcEconomics = _currentEconomics(address(primary));
        T.Authorization memory a =
            grant == 0 ? _authorization(false) : T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.economicsConsentDigest(mcEconomics, a);
        a.signature = grant == 0 ? _signature(digest) : _delegateSignature(digest);
        mcEconomicsRecord = grant == 0
            ? ingress.recordEconomicsConsent(mcEconomics, a)
            : ingress.recordDelegatedEconomicsConsent(mcEconomics, grant, a);
        _mcRemember(mcEconomicsRecord, digest, a, grant != 0);
        _rhCandidate(6, "consent_finality.replay.consent_key", keccak256(abi.encode(mcEconomics)));
    }

    function _mcSale(bytes32 grant, uint256 nonce) private {
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

    function _mcContentAndFreeze() private {
        mcContent = _contentProposal(keccak256("aggregate content"));
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentConsentDigest(mcContent, a);
        a.signature = _signature(digest);
        mcContentRecord = ingress.recordContentConsent(mcContent, a);
        _mcRemember(mcContentRecord, digest, a, false);
        _rhCandidate(
            6,
            "consent_finality.replay.content_consent_key",
            keccak256(abi.encode(keccak256(abi.encode(mcContent, uint64(1))), mcContentRecord))
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
            keccak256(abi.encode(keccak256("CONTENT"), uint256(1), uint64(1), mcFreezeRecord))
        );
    }

    function _mcRoyalty(bytes32 grant, uint256 nonce) private {
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
            keccak256(abi.encode(mcRoyalty, artistId, uint64(1)))
        );
    }

    function _mcRemember(bytes32 record, bytes32 digest, T.Authorization memory a, bool delegated)
        private
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

    function _mcRoyalties() private view returns (T.RoyaltyFreeze[] memory terms) {
        terms = new T.RoyaltyFreeze[](1);
        terms[0] = mcRoyalty;
    }

    function _mcPrepare(Successor memory next)
        private
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

    function _mcAssert(Successor memory next, Commit.Prepared memory p) private view {
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
                next.registry.delegationRecord(mcGrants[0]).uses == 5
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

    function _mcSemantics(T.SuiteConfiguration memory s) private view returns (bytes32 h) {
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

    function _mcHash(Successor memory next) private view returns (bytes32 h) {
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
    ) private view {
        (bool ok,) = address(ConsentFacts)
            .staticcall(
                abi.encodeWithSelector(
                    ConsentFacts.validate.selector, ids.rows, ids, rows, bindings, p
                )
            );
        require(!ok, "global per-version count mismatch rejected");
    }

    function _mcBadRequest(Successor memory next, RH.Request memory r) private {
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
