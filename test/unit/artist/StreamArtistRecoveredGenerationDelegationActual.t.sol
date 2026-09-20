// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredGenerationAttestationsActualTest
} from "./StreamArtistRecoveredGenerationAttestationsActual.t.sol";
import {
    RecoveredDelegationSaleFacts
} from "./StreamArtistRecoveredDelegationAuthorityActual.t.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    IStreamArtistDelegatedConsent as Delegated
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDelegatedConsent.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistSaleConsentOwner as Sales
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleOwner.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistRecoveredConsentHydration as RecoveredConsent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredConsentHydration.sol";
import {
    IStreamArtistRecoveredHydration as Recovered
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
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
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredGenerationDelegatedConsents as Codec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredGenerationDelegatedConsents.sol";
import {
    StreamArtistRecoveredGenerationDelegatedConsentFacts as Facts
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredGenerationDelegatedConsentFacts.sol";
import {
    StreamArtistRecoveredBindingGenerations as Generations
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerations.sol";
import {
    StreamArtistRecoveredBindingGenerationModes as Modes
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredBindingGenerationModes.sol";
import {
    StreamArtistRecoveredIdentityHydrationSource as IdentitySource
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredIdentityHydrationSource.sol";
import {
    StreamArtistPublicationHydrationTypes as PH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";

interface GenerationDelegationVm {
    function expectCall(address, bytes calldata, uint64) external;
}

/// @notice Actual original Artist/Safe grants, pending generations and seven-owner migration.
/// @dev Core, governance, Metadata and sale facts are inherited typed boundaries. No runtime,
/// full-current, maximum carrier or transaction-cap acceptance is implied by authored cases.
contract StreamArtistRecoveredGenerationDelegationActualTest is
    StreamArtistRecoveredGenerationAttestationsActualTest
{
    GenerationDelegationVm private constant gdv =
        GenerationDelegationVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    T.PolicyConsent[] private policyTerms;
    bytes32[] private policyRecords;
    bytes32[] private grants;
    bytes32[] private grantSnapshots;
    Sale.Record[] private saleRecords;
    T.Binding[] private bindings;

    function testGenerationModeTwoWithoutGrantRetainsEmptyConsentAndExactModeTags() external {
        _baseline(2, false);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        (, Payload.Payload memory owner0) = Payload.decode(p.data[0].typedState, 0);
        Generations.Bundle memory b =
            Generations.decode(p.query, owner0.provenance, owner0.semanticState);
        require(
            keccak256(owner0.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_BINDING_GENERATION_MODES_V1"),
                        uint16(1),
                        b
                    )
                ),
            "literal mode binding codec"
        );
        (, Payload.Payload memory owner6) = Payload.decode(p.data[6].typedState, 6);
        (ContentH.Bundle memory consent, uint64 generation, uint8 mode) =
            Codec.decode(p.query, owner6.provenance, owner6.semanticState);
        require(
            generation == 2 && mode == 2 && consent.original.policies.length == 0
                && consent.original.sales.length == 0,
            "no invented consent/grant"
        );
        _literal(owner6.semanticState, consent, generation, mode);
        _import(next, request, p);
    }

    function testGenerationModeTwoUsesOriginalDelegatePolicySaleAndFullNonceLane() external {
        _baseline(2, false);
        bytes32 grant = _grantFor(1031, 2);
        _policy(grant, 257, 1);
        _sale(grant, 0);
        require(ingress.delegationRecord(grant).uses == 2, "two original uses");
        _snapshotGrants();
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        _import(next, request, p);
        (bool zero,) = next.registry.delegatedNonceState(artistId, address(delegateSafe), 0);
        (bool sparse,) = next.registry.delegatedNonceState(artistId, address(delegateSafe), 257);
        require(zero && sparse, "both complete original nonce words");
        _rhAdopt(next);
        vm.expectRevert();
        this.gdFreshPolicy(grant, 1, 9);
        require(
            ingress.delegationRecord(grant).uses == 2,
            "exhausted grant cannot authorize fresh record"
        );
    }

    function testGenerationGrantReplacementRevocationExpiryRemainHistoricalAfterImport() external {
        _baseline(2, true);
        bytes32 old = _grantFor(1031, 0);
        _policy(old, 0, 1);
        bytes32 current = _grantFor(1031, 0);
        _sale(current, 1);
        _raRevoke(current);
        bytes32 unused = _grantFor(1031, 0);
        vm.warp(ingress.delegationRecord(unused).grant.expiresAt);
        _snapshotGrants();
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        _import(next, request, p);
        require(
            next.registry.delegationRecord(old).uses == 1
                && next.registry.delegationRecord(current).revoked
                && next.registry.delegationRecord(unused).uses == 0,
            "all historical versions conserved"
        );
        _rhAdopt(next);
        vm.expectRevert();
        this.gdFreshPolicy(old, 2, 90);
        vm.expectRevert();
        this.gdFreshPolicy(current, 2, 91);
        vm.expectRevert();
        this.gdFreshPolicy(unused, 2, 92);
        require(
            Consent(suite.owners[6])
                    .policyRecord(1, policyTerms[0].phaseId, policyTerms[0].policyHash)
                == policyRecords[0],
            "durable old consent remains"
        );
    }

    function testGenerationSharedGrantCountsPolicySaleAndDelegatedAttestationExactly() external {
        _baseline(2, false);
        bytes32 grant = _grantFor(1031, 3);
        _policy(grant, 0, 1);
        _sale(grant, 1);
        _raPrimary(grant, 2);
        require(ingress.delegationRecord(grant).uses == 3, "original14+16+24 exact total");
        _snapshotGrants();
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        _import(next, request, p);
        _raAssert(next.coordinator.suiteConfiguration(), raRows.length);
    }

    function testGenerationOneGrantAcrossPolicySaleRoyaltyAndAttestationKeepsAllFourUses()
        external
    {
        _baseline(2, false);
        bytes32 grant = _grantFor(1063, 4);
        _policy(grant, 0, 1);
        _sale(grant, 1);
        _raPrimary(grant, 2);
        T.RoyaltyFreeze memory terms = _freezePayload();
        T.Authorization memory authorization = T.Authorization(3, type(uint64).max, "");
        bytes32 digest = ingress.royaltyFreezeDigest(terms, authorization);
        authorization.signature = _delegateSignature(digest);
        bytes32 record = ingress.authorizeDelegatedRoyaltyFreeze(terms, grant, authorization);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_ROYALTY_FREEZE_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(royalty),
                        uint256(1),
                        terms.revenueClass,
                        terms.expectedAssignmentHash,
                        artistId,
                        address(delegateSafe),
                        uint8(2),
                        uint256(3),
                        uint64(block.timestamp)
                    )
                ),
            "literal original delegated20 hash"
        );
        _delegatedNonce(digest, 3);
        _rhCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(abi.encode(terms, artistId, finalGeneration))
        );
        bytes32 original = keccak256(
            abi.encode(
                Consent(suite.owners[6]).royaltyFreezeRecord(terms, artistId, finalGeneration)
            )
        );
        require(ingress.delegationRecord(grant).uses == 4, "14+16+20+24 exact shared total");
        _snapshotGrants();
        Successor memory next = _rhCutover();
        RH.Request memory request = _request();
        T.RoyaltyFreeze[] memory witnesses = new T.RoyaltyFreeze[](1);
        witnesses[0] = terms;
        Commit.Prepared memory p =
            Prepared.prepare(next.coordinator.suiteConfiguration(), request, witnesses);
        request.expectedSemanticInventory = Prepared.inventory(p);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & 960) == 960,
                "all seven generation/delegation/content/attestation bits"
            );
        }
        bytes32 value = RecoveredConsent(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(request, witnesses);
        _rhImported(next, p, value);
        _assertImported(next.coordinator.suiteConfiguration());
        _raAssert(next.coordinator.suiteConfiguration(), raRows.length);
        require(
            keccak256(
                abi.encode(
                    Consent(next.coordinator.suiteConfiguration().owners[6])
                        .royaltyFreezeRecord(terms, artistId, finalGeneration)
                )
            ) == original,
            "original class2 royalty body and same grant retained"
        );
        require(
            next.registry.recordDelegation(record) == grant, "original royalty grant association"
        );
    }

    function testGenerationEarlierModeTwoThenFinalModeOneRetainsBothButNoDelegatePolicyPower()
        external
    {
        _baseline(1, true);
        bytes32 grant = _grantFor(1031, 0);
        _snapshotGrants();
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        _import(next, request, p);
        require(
            Binding(next.coordinator.suiteConfiguration().owners[0]).bindingAt(1, 2).consentMode
                    == 2
                && Binding(next.coordinator.suiteConfiguration().owners[0]).binding(1).consentMode
                == 1,
            "pending mode is not present consent mode"
        );
        _rhAdopt(next);
        vm.expectRevert();
        this.gdFreshPolicy(grant, 0, 1);
        require(
            ingress.delegationRecord(grant).uses == 0,
            "mode1 forbids policy despite valid capability"
        );
    }

    function testGenerationFreshSuccessorGrantUsesPersistentLaneWithoutRevivingOldRecord()
        external
    {
        _baseline(2, false);
        bytes32 old = _grantFor(1031, 0);
        _policy(old, 0, 1);
        _raRevoke(old);
        _snapshotGrants();
        Successor memory middle = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(middle);
        _import(middle, request, p);
        _rhAdopt(middle);
        bytes32 fresh = _grantFor(1031, 0);
        vm.expectRevert();
        this.gdFreshPolicy(fresh, 0, 2);
        _policy(fresh, 1, 2);
        _snapshotGrants();
        Successor memory last = _rhCutover();
        (request, p) = _prepare(last);
        require(p.admission.provenance.eras.length == 2, "complete actual A/B lineage");
        _import(last, request, p);
        require(
            last.registry.delegationRecord(old).revoked
                && last.registry.delegationRecord(fresh).uses == 1,
            "old state and new grant remain distinct"
        );
    }

    function testGenerationMissingGrantReplayInventoryRefusesBeforeAnyImportThenExactRetry()
        external
    {
        _baseline(2, false);
        bytes32 grant = _grantFor(1031, 0);
        _sale(grant, 0);
        _snapshotGrants();
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        RH.Request memory bad = abi.decode(abi.encode(request), (RH.Request));
        bad.records.authority.replayOrigins[2] = new AH.Origin[](0);
        bytes32 before_ = _rhDestinationHash(next);
        vm.expectRevert();
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(bad);
        require(_rhDestinationHash(next) == before_, "complete inventory required before writes");
        _import(next, request, p);
    }

    function testGenerationWrongTagModeGenerationAndHistoricalGrantCannotBeReinterpreted()
        external
    {
        _baseline(2, false);
        bytes32 grant = _grantFor(1031, 0);
        _policy(grant, 0, 1);
        _sale(grant, 1);
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _prepare(next);
        (, Payload.Payload memory payload) = Payload.decode(p.data[6].typedState, 6);
        (ContentH.Bundle memory b, uint64 generation, uint8 mode) =
            Codec.decode(p.query, payload.provenance, payload.semanticState);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gdDecode(
            p.query,
            payload.provenance,
            abi.encode(keccak256("wrong tag"), uint16(1), generation, mode, b)
        );
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gdDecode(
            p.query,
            payload.provenance,
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_GENERATION_DELEGATED_CONSENTS_V1"),
                uint16(1),
                generation,
                uint8(1),
                b
            )
        );
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gdDecode(
            p.query,
            payload.provenance,
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_GENERATION_DELEGATED_CONSENTS_V1"),
                uint16(1),
                generation + 1,
                mode,
                b
            )
        );
        IH.Bundle memory identity = IdentitySource.collect(
            suite.owners[2], p.query, RH.ownerProvenance(p.admission.provenance, 2)
        );
        ContentH.Bundle memory wrong = abi.decode(abi.encode(b), (ContentH.Bundle));
        wrong.original.sales[0].grant = keccak256("foreign actual-grant identity");
        bytes memory raw = Codec.encode(wrong, p.query, payload.provenance, generation, mode);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gdFacts(identity, raw, p.query, p.admission.provenance, mode);
        identity.delegations[0].record.uses = 0;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gdFacts(identity, payload.semanticState, p.query, p.admission.provenance, mode);
    }

    function testGenerationLateArchiveFailureHasTwoExactAttemptsAndRestoresAllOwners() external {
        _baseline(2, false);
        bytes32 grant = _grantFor(1031, 0);
        _policy(grant, 0, 1);
        _sale(grant, 1);
        _snapshotGrants();
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _prepare(next);
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request));
        gdv.expectCall(
            next.coordinator.suiteConfiguration().archive, _gaFirstPage(next, request, p), 2
        );
        uint256 height = block.number;
        uint256 nonce = rotationSafe.nonce();
        bytes32 before_ = _rhDestinationHash(next);
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        require(
            rotationSafe.nonce() == nonce && _rhDestinationHash(next) == before_,
            "seven owner roots and Safe nonce rolled back"
        );
        require(
            next.registry.delegationRecord(grant).grant.artistId == 0, "no partial grant import"
        );
        vm.roll(height);
        require(
            this.rhExecuteNewSafe(address(next.registry), call_), "identical original Safe retry"
        );
        require(rotationSafe.nonce() == nonce + 1, "one committed Safe nonce");
        _assertImported(next.coordinator.suiteConfiguration());
    }

    function gdDecode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        Codec.decode(q, p, raw);
    }

    function gdFacts(
        IH.Bundle calldata identity,
        bytes calldata raw,
        AH.Query calldata q,
        RH.Provenance calldata p,
        uint8 mode
    ) external pure {
        Facts.validate(identity, raw, q, p, mode, new PH.Row[](0));
    }

    function gdFreshPolicy(bytes32 grant, uint256 nonce, uint256 salt) external {
        _policy(grant, nonce, salt);
    }

    function _baseline(uint8 finalMode, bool third) private {
        uint256 transitions = third ? 2 : 1;
        for (uint256 i; i < transitions; ++i) {
            T.Binding memory b = Binding(suite.owners[0]).binding(1);
            bindings.push(b);
            _rhCandidate(
                0,
                "binding_lifecycle.replay.proposal_key",
                keccak256(abi.encode(uint256(1), b.generation))
            );
            L.Termination memory terms = _termination(1);
            if (i == 0) {
                T.Authorization memory a = _authorization(false);
                bytes32 digest = ingress.bindingRefusalDigest(terms, a);
                a.signature = _signature(digest);
                ingress.refuseArtistBinding(terms, a);
                _rhAuthorization(digest, a.nonce);
                _rhCandidate(
                    0,
                    "binding_lifecycle.replay.refusal_uniqueness",
                    keccak256(abi.encode(uint256(1), b.generation))
                );
            } else {
                ingress.withdrawArtistBinding(terms);
                _rhCandidate(
                    0,
                    "binding_lifecycle.replay.proposal_terminal_transition_key",
                    keccak256(abi.encode(uint256(1), b.generation))
                );
            }
            T.BindingProposal memory proposed = _proposal(artistId);
            proposed.consentMode = i + 1 == transitions ? finalMode : 2;
            proposed.saleConsentScope = 1;
            ingress.proposeArtistBinding(
                1, proposed, bytes("unit identity document"), "Artist Safe"
            );
        }
        finalGeneration = Binding(suite.owners[0]).binding(1).generation;
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_key",
            keccak256(abi.encode(uint256(1), finalGeneration))
        );
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), finalGeneration, uint8(1), address(artist)))
        );
        _raBaseline();
        bindings.push(Binding(suite.owners[0]).binding(1));
    }

    function _grantFor(uint32 capabilities, uint64 maxUses) private returns (bytes32 record) {
        D.Grant memory terms = _delegation(
            1, capabilities, uint64(block.timestamp), uint64(block.timestamp + 365 days), maxUses
        );
        T.Authorization memory a = T.Authorization(nextNonce, 0, "");
        bytes32 digest = ingress.delegationGrantDigest(terms, a);
        record = _grant(terms);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(2, "identity_authority.replay.delegation_key", record);
        grants.push(record);
    }

    function _policy(bytes32 grant, uint256 nonce, uint256 salt) private {
        T.PolicyConsent memory terms = T.PolicyConsent(
            1,
            keccak256(abi.encode("generation phase", salt)),
            keccak256(abi.encode("generation policy", salt))
        );
        T.Authorization memory a = T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.policyConsentDigest(terms, a);
        a.signature = _delegateSignature(digest);
        bytes32 record = Delegated(address(ingress)).recordDelegatedPolicyConsent(terms, grant, a);
        _delegatedNonce(digest, nonce);
        _rhCandidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(uint256(1), terms.phaseId, terms.policyHash))
        );
        policyTerms.push(terms);
        policyRecords.push(record);
    }

    function _sale(bytes32 grant, uint256 nonce) private {
        RecoveredDelegationSaleFacts facts = new RecoveredDelegationSaleFacts(address(core));
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(facts),
            facts.streamModuleType(),
            facts.streamModuleInterfaceId()
        );
        Sale.Consent memory terms = Sale.Consent(1, address(facts), facts.ID(), facts.CONFIG());
        T.Authorization memory a = T.Authorization(nonce, type(uint64).max, "");
        bytes32 digest = ingress.saleConsentDigest(terms, a);
        a.signature = _delegateSignature(digest);
        bytes32 record = Delegated(address(ingress)).recordDelegatedSaleConsent(terms, grant, a);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(facts),
                        address(core),
                        uint256(1),
                        terms.saleId,
                        terms.saleConfigHash,
                        artistId,
                        address(delegateSafe),
                        uint8(2),
                        nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal original sale preimage"
        );
        _delegatedNonce(digest, nonce);
        _rhCandidate(
            6,
            "consent_finality.replay.sale_consent_key",
            keccak256(
                abi.encode(terms, finalGeneration, Binding(suite.owners[0]).binding(1).bindingHash)
            )
        );
        saleRecords.push(Sales(suite.owners[6]).saleConsentRecord(record));
    }

    function _delegatedNonce(bytes32 digest, uint256 nonce) private {
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
    }

    function _snapshotGrants() private {
        delete grantSnapshots;
        for (uint256 i; i < grants.length; ++i) {
            grantSnapshots.push(keccak256(abi.encode(ingress.delegationRecord(grants[i]))));
        }
    }

    function _request() private view returns (RH.Request memory request) {
        request = raRows.length == 0 ? _rhRequest() : _raRequest();
        request.records.authority.collections[0].policies = new AH.PolicyKey[](policyTerms.length);
        for (uint256 i; i < policyTerms.length; ++i) {
            request.records.authority.collections[0].policies[i] =
                AH.PolicyKey(policyTerms[i].phaseId, policyTerms[i].policyHash);
        }
    }

    function _prepare(Successor memory next)
        private
        view
        returns (RH.Request memory request, Commit.Prepared memory p)
    {
        request = _request();
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(p);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & 576) == 576 && (h.requiredFeatures & 256) == 0,
                "seven matching generation/delegation headers without content"
            );
        }
    }

    function _import(Successor memory next, RH.Request memory request, Commit.Prepared memory p)
        private
    {
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(next, p, value);
        _assertImported(next.coordinator.suiteConfiguration());
    }

    function _assertImported(T.SuiteConfiguration memory target) private view {
        for (uint256 i; i < bindings.length; ++i) {
            require(
                keccak256(abi.encode(Binding(target.owners[0]).bindingAt(1, uint64(i + 1))))
                    == keccak256(abi.encode(bindings[i])),
                "all original binding modes and hashes"
            );
        }
        for (uint256 i; i < grantSnapshots.length; ++i) {
            require(
                keccak256(abi.encode(ingressAt(target.registry).delegationRecord(grants[i])))
                    == grantSnapshots[i],
                "all complete historical grant bytes"
            );
        }
        for (uint256 i; i < policyTerms.length; ++i) {
            require(
                Consent(target.owners[6])
                    .policyRecord(1, policyTerms[i].phaseId, policyTerms[i].policyHash)
                == policyRecords[i],
                "all original policy heads"
            );
        }
        for (uint256 i; i < saleRecords.length; ++i) {
            require(
                keccak256(
                    abi.encode(Sales(target.owners[6]).saleConsentRecord(saleRecords[i].recordHash))
                ) == keccak256(abi.encode(saleRecords[i])),
                "all original sale bodies"
            );
        }
    }

    function ingressAt(address target) private pure returns (GenerationDelegationReader) {
        return GenerationDelegationReader(target);
    }

    function _literal(bytes memory raw, ContentH.Bundle memory b, uint64 generation, uint8 mode)
        private
        pure
    {
        require(
            keccak256(raw)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_GENERATION_DELEGATED_CONSENTS_V1"),
                        uint16(1),
                        generation,
                        mode,
                        b
                    )
                ),
            "independent literal delegated generation envelope"
        );
    }
}

interface GenerationDelegationReader {
    function delegationRecord(bytes32) external view returns (D.Record memory);
}
