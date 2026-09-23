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
    StreamArtistContentTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamArtistSaleTypes as Sale
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    IStreamArtistSaleConsentOwner as Sales
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleOwner.sol";
import {
    IStreamArtistContentAuthority
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    IStreamArtistContentRecordsOwner as Content
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistEconomicsEvidence as Economics
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredConsentHydration as Recovered
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredConsentHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistNativeReceipts as Native
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
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
    StreamArtistRecoveredGenerationConsents as Generation
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredGenerationConsents.sol";

interface GenerationConsentVm {
    function expectCall(address, bytes calldata, uint64) external;
}

/// @notice Actual original generation2/3 producers and seven-owner/Safe op60 composition.
/// @dev Core, governance, Metadata and sale facts are explicit inherited typed boundaries.
/// Actual Artist owners, Registry, Coordinator, Archive, resolvers and threshold Safe execute.
/// This is authored source, not full-current or maximum carrier/runtime acceptance.
contract StreamArtistRecoveredGenerationConsentsActualTest is
    StreamArtistRecoveredGenerationAttestationsActualTest
{
    GenerationConsentVm private constant gcv =
        GenerationConsentVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    C.Consent[] private contents;
    C.Freeze[] private freezes;
    bytes32[] private contentRecords;
    bytes32[] private freezeRecords;
    T.Authorization[] private contentAuth;
    T.EconomicsConsent[] private economicTerms;
    bytes32[] private economicRecords;
    T.RoyaltyFreeze[] private royaltyTerms;
    bytes32[] private royaltyRecords;
    T.PolicyConsent private policy;
    bytes32 private policyRecord;
    Sale.Consent private sale;
    bytes32 private saleRecord;

    function testGenerationConsentCompleteMixedThirdGenerationHeadsAndLiteralCodec() external {
        _gcBaseline(2);
        T.SuiteConfiguration memory source = suite;
        bytes32 oldHash = _gcHash(source, contents.length, freezes.length);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory prepared) = _gcPrepare(next);
        (, Payload.Payload memory p) = Payload.decode(prepared.data[6].typedState, 6);
        (ContentH.Bundle memory b, uint64 generation) =
            Generation.decode(prepared.query, p.provenance, p.semanticState);
        require(
            generation == 3 && b.consents.length == 2 && b.freezes.length == 2,
            "complete actual mixed source"
        );
        require(
            keccak256(p.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_GENERATION_CONTENT_CONSENTS_V1"),
                        uint16(1),
                        uint64(3),
                        b
                    )
                ),
            "independent literal new codec"
        );
        bytes32 value = Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(request, royaltyTerms);
        _rhImported(next, prepared, value);
        _gcAssert(next.coordinator.suiteConfiguration(), contents.length, freezes.length);
        require(
            _gcHash(source, contents.length, freezes.length) == oldHash,
            "source exact original maps unchanged"
        );
    }

    function testGenerationConsentRepeatedImportRetainsOriginalDomainsAndFreshHeads() external {
        _gcBaseline(1);
        T.SuiteConfiguration memory first = suite;
        uint256 originalContents = contents.length;
        uint256 originalFreezes = freezes.length;
        bytes32 firstHash = _gcHash(first, originalContents, originalFreezes);
        Successor memory middle = _rhCutover();
        _gcTransfer(middle);
        _rhAdopt(middle);
        _gcContent(keccak256("same repeated content"), true);
        metadata.setContent(keccak256("fresh B external Metadata state"));
        _gcFreeze();
        T.SuiteConfiguration memory second = suite;
        bytes32 secondHash = _gcHash(second, contents.length, freezes.length);
        Successor memory last = _rhCutover();
        (, Commit.Prepared memory prepared) = _gcPrepare(last);
        require(prepared.admission.provenance.eras.length == 2, "actual A and B history");
        _gcTransfer(last);
        _gcAssert(last.coordinator.suiteConfiguration(), contents.length, freezes.length);
        require(
            _gcHash(first, originalContents, originalFreezes) == firstHash, "A retained verbatim"
        );
        require(
            _gcHash(second, contents.length, freezes.length) == secondHash, "B retained verbatim"
        );
    }

    function testGenerationConsentCompleteWitnessCapabilityAndSourceRefusals() external {
        _gcBaseline(1);
        Successor memory next = _rhCutover();
        (RH.Request memory request,) = _gcPrepare(next);
        bytes32 before_ = _rhDestinationHash(next);
        RH.Request memory bad = abi.decode(abi.encode(request), (RH.Request));
        bad.records.witnesses[0].economics = new T.EconomicsConsent[](0);
        avm.expectRevert(T.UnsupportedProfile.selector);
        Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(bad, royaltyTerms);
        bad = abi.decode(abi.encode(request), (RH.Request));
        bad.records.witnesses[0].economics[0].assignmentHash =
            keccak256("foreign original assignment");
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(bad, royaltyTerms);
        T.RoyaltyFreeze[] memory wrong = royaltyTerms;
        wrong[0].expectedAssignmentHash = keccak256("foreign original20 key");
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(request, wrong);
        bad = abi.decode(abi.encode(request), (RH.Request));
        bad.expectedCapabilities[6].supportedFeatures &= ~uint256(512);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(bad, royaltyTerms);
        bad = abi.decode(abi.encode(request), (RH.Request));
        ++bad.records.authority.expectedSource[6].ownerState.revision;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(bad, royaltyTerms);
        require(_rhDestinationHash(next) == before_, "all failed imports atomic");
        Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(request, royaltyTerms);
        _gcAssert(next.coordinator.suiteConfiguration(), contents.length, freezes.length);
    }

    function testGenerationConsentWrongGenerationTagDuplicateAndGrantCannotRelabel() external {
        _gcBaseline(1);
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory prepared) = _gcPrepare(next);
        (, Payload.Payload memory p) = Payload.decode(prepared.data[6].typedState, 6);
        (ContentH.Bundle memory original, uint64 generation) =
            Generation.decode(prepared.query, p.provenance, p.semanticState);
        vm.expectRevert();
        this.gcOldDecode(prepared.query, p.provenance, p.semanticState);
        ContentH.Bundle memory b = abi.decode(abi.encode(original), (ContentH.Bundle));
        b.consents[0].bindingGeneration = 1;
        _gcReject(b, prepared.query, p.provenance, generation);
        b = abi.decode(abi.encode(original), (ContentH.Bundle));
        b.original.economics[0].item.association.bindingGeneration = 1;
        _gcReject(b, prepared.query, p.provenance, generation);
        b = abi.decode(abi.encode(original), (ContentH.Bundle));
        b.original.policies[0].grant = keccak256("unproved historical grant");
        _gcReject(b, prepared.query, p.provenance, generation);
        b = abi.decode(abi.encode(original), (ContentH.Bundle));
        b.consents[1] = b.consents[0];
        _gcReject(b, prepared.query, p.provenance, generation);
        bytes memory alternate = abi.encode(keccak256("wrong tag"), uint16(1), generation, original);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gcDecode(prepared.query, p.provenance, alternate);
        this.gcDecode(prepared.query, p.provenance, p.semanticState);
        require(
            Content(next.coordinator.suiteConfiguration().owners[6])
            .contentConsentAt(contents[0], finalGeneration)
            .recordHash == 0,
            "validation alone never imports"
        );
    }

    function testGenerationConsentLateArchiveFailureTwoCallsAndIdenticalSafeRetry() external {
        _gcBaseline(1);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _gcPrepare(next);
        bytes32 before_ = _rhDestinationHash(next);
        uint256 nonce = rotationSafe.nonce();
        bytes memory call_ = abi.encodeCall(
            Recovered.hydrateRecoveredArtistAuthorityWithConsents, (request, royaltyTerms)
        );
        gcv.expectCall(
            next.coordinator.suiteConfiguration().archive, _gaFirstPage(next, request, p), 2
        );
        uint256 height = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        require(
            _rhDestinationHash(next) == before_ && rotationSafe.nonce() == nonce,
            "seven owners and Safe nonce roll back"
        );
        address owner = next.coordinator.suiteConfiguration().owners[6];
        require(
            Content(owner).contentConsentAt(contents[0], finalGeneration).recordHash == 0,
            "new generation head rolled back"
        );
        require(
            Consent(owner)
                .royaltyFreezeRecord(royaltyTerms[0], artistId, finalGeneration)
                .recordHash == 0,
            "royalty head rolled back"
        );
        vm.roll(height);
        require(this.rhExecuteNewSafe(address(next.registry), call_), "identical Safe retry");
        require(rotationSafe.nonce() == nonce + 1, "one successful Safe commit");
        _gcAssert(next.coordinator.suiteConfiguration(), contents.length, freezes.length);
    }

    function testGenerationConsentStaleDomainSpentNonceAndFreshOriginal17() external {
        _gcBaseline(1);
        Successor memory next = _rhCutover();
        _gcTransfer(next);
        _rhAdopt(next);
        T.Authorization memory old = contentAuth[0];
        bytes32 before_ = _rhDestinationHash(next);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordContentConsent(contents[0], old);
        old.signature = _signature(ingress.contentConsentDigest(contents[0], old));
        require(
            Identity(suite.owners[2]).nonceUsed(artistId, old.nonce),
            "old nonce retained before retry"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                T.Replay.selector,
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                        block.chainid,
                        address(ingress),
                        address(coordinator),
                        address(archive),
                        suite.owners[2],
                        keccak256("domain:identity_authority"),
                        keccak256("identity_authority.replay.nonce_allocator"),
                        keccak256(abi.encode(artistId, old.nonce))
                    )
                )
            )
        );
        ingress.recordContentConsent(contents[0], old);
        require(_rhDestinationHash(next) == before_, "both failures preserve all roots");
        _gcContent(keccak256("same repeated content"), false);
        _gcAssert(suite, contents.length, freezes.length);
    }

    function testGenerationConsentUnusedGrantUsesExplicitCompositionWithoutDroppingContent()
        external
    {
        _gcBaseline(1);
        bytes32 grant = _raGrant();
        bytes32 original = keccak256(abi.encode(ingress.delegationRecord(grant)));
        Successor memory next = _rhCutover();
        RH.Request memory request = _gcRequest();
        Commit.Prepared memory p =
            this.gcPrepare(next.coordinator.suiteConfiguration(), request, royaltyTerms);
        (RH.ExportHeader memory h, Payload.Payload memory payload) =
            Payload.decode(p.data[6].typedState, 6);
        require(
            (h.requiredFeatures & 320) == 320
                && abi.decode(payload.semanticState, (bytes32))
                    == keccak256("6529STREAM_ARTIST_RECOVERED_GENERATION_DELEGATED_CONSENTS_V1"),
            "complete grant and content tag"
        );
        request.expectedSemanticInventory = Prepared.inventory(p);
        // The fixed content recipe carries the exhaustive original20 witness set.
        Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(request, royaltyTerms);
        _gcAssert(next.coordinator.suiteConfiguration(), contents.length, freezes.length);
        require(
            keccak256(abi.encode(next.registry.delegationRecord(grant))) == original,
            "exact unused grant retained beside content"
        );
    }

    function gcPrepare(
        T.SuiteConfiguration memory target,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory terms
    ) external view returns (Commit.Prepared memory) {
        return Prepared.prepare(target, request, terms);
    }

    function gcDecode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        Generation.decode(q, p, raw);
    }

    function gcOldDecode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        ContentH.decode(q, p, raw);
    }

    function gcValidate(
        ContentH.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        uint64 generation
    ) external pure {
        Generation.validate(b, q, p, generation);
    }

    function _gcReject(
        ContentH.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        uint64 generation
    ) private {
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gcValidate(b, q, p, generation);
    }

    function _gcBaseline(uint8 transitions) private {
        _gaBaseline(transitions);
        _gaRecords();
        T.PayoutDesignation memory payout = T.PayoutDesignation(artistId, address(artist), 0);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.payoutDesignationDigest(payout, a);
        a.signature = _signature(digest);
        ingress.recordPayoutDesignation(payout, a);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(artistId))
        );
        policy = T.PolicyConsent(1, keccak256("generation phase"), keccak256("generation policy"));
        a = _authorization(false);
        digest = ingress.policyConsentDigest(policy, a);
        a.signature = _signature(digest);
        policyRecord = ingress.recordPolicyConsent(policy, a);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(policy.collectionId, policy.phaseId, policy.policyHash))
        );
        (T.AssignmentFact memory one, T.AssignmentFact memory two) =
            coordinator.reads().currentAssignments(1);
        _gcEconomics(one);
        _gcContent(keccak256("same repeated content"), false);
        _gcEconomics(two);
        _gcFreeze();
        RecoveredDelegationSaleFacts facts = new RecoveredDelegationSaleFacts(address(core));
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(facts),
            facts.streamModuleType(),
            facts.streamModuleInterfaceId()
        );
        sale = Sale.Consent(1, address(facts), facts.ID(), facts.CONFIG());
        a = _authorization(false);
        digest = ingress.saleConsentDigest(sale, a);
        a.signature = _signature(digest);
        saleRecord = ingress.recordSaleConsent(sale, a);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            6,
            "consent_finality.replay.sale_consent_key",
            keccak256(
                abi.encode(sale, finalGeneration, Binding(suite.owners[0]).binding(1).bindingHash)
            )
        );
        _gcContent(keccak256("same repeated content"), true);
        metadata.setContent(keccak256("changed external Metadata before freeze2"));
        _gcFreeze();
        T.RoyaltyFreeze memory terms = _freezePayload();
        a = _authorization(false);
        digest = ingress.royaltyFreezeDigest(terms, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.authorizeArtistRoyaltyFreeze(terms, a);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(abi.encode(terms, artistId, finalGeneration))
        );
        royaltyTerms.push(terms);
        royaltyRecords.push(record);
    }

    function _gcEconomics(T.AssignmentFact memory fact) private {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.economicsConsentDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.recordEconomicsConsent(p, a);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(6, "consent_finality.replay.consent_key", keccak256(abi.encode(p)));
        economicTerms.push(p);
        economicRecords.push(record);
    }

    function _gcContent(bytes32 candidate, bool direct) private {
        C.Consent memory p = _contentProposal(candidate);
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentConsentDigest(p, a);
        bytes32 record;
        if (direct) {
            require(
                this.rhExecuteNewSafe(
                    address(ingress),
                    abi.encodeCall(IStreamArtistContentAuthority.recordContentConsent, (p, a))
                ),
                "actual direct Safe17"
            );
            record = Content(suite.owners[6]).contentConsentAt(p, finalGeneration).recordHash;
        } else {
            a.signature = _signature(digest);
            record = ingress.recordContentConsent(p, a);
        }
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_CONTENT_CONSENT_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(metadata),
                        address(core),
                        uint256(1),
                        p.familyId,
                        p.newStateHash,
                        artistId,
                        address(artist),
                        uint8(1),
                        a.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal original17 preimage"
        );
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            6,
            "consent_finality.replay.content_consent_key",
            keccak256(abi.encode(keccak256(abi.encode(p, finalGeneration)), record))
        );
        contents.push(p);
        contentRecords.push(record);
        contentAuth.push(a);
    }

    function _gcFreeze() private {
        C.Freeze memory p = _contentFreezeProposal();
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.contentFreezeDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.authorizeArtistContentFreeze(p, a);
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_CONTENT_FREEZE_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(metadata),
                        address(core),
                        uint256(1),
                        p.lockClasses,
                        p.expectedStateHash,
                        artistId,
                        address(artist),
                        uint8(1),
                        a.nonce,
                        uint64(block.timestamp)
                    )
                ),
            "literal original21 preimage"
        );
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            6,
            "consent_finality.replay.freeze_key",
            keccak256(abi.encode(keccak256("CONTENT"), uint256(1), finalGeneration, record))
        );
        freezes.push(p);
        freezeRecords.push(record);
    }

    function _gcRequest() private view returns (RH.Request memory p) {
        p = _raRequest();
        p.records.witnesses[0].economics = economicTerms;
        p.records.authority.collections[0].policies = new AH.PolicyKey[](1);
        p.records.authority.collections[0].policies[0] =
            AH.PolicyKey(policy.phaseId, policy.policyHash);
    }

    function _gcPrepare(Successor memory next)
        private
        view
        returns (RH.Request memory request, Commit.Prepared memory p)
    {
        request = _gcRequest();
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), request, royaltyTerms);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & uint256(928)) == 928,
                "all seven generation/content/attestation/economics bits"
            );
        }
        request.expectedSemanticInventory = Prepared.inventory(p);
    }

    function _gcTransfer(Successor memory next) private {
        (RH.Request memory request, Commit.Prepared memory p) = _gcPrepare(next);
        bytes32 value = Recovered(address(next.registry))
            .hydrateRecoveredArtistAuthorityWithConsents(request, royaltyTerms);
        _rhImported(next, p, value);
        _gcAssert(next.coordinator.suiteConfiguration(), contents.length, freezes.length);
    }

    function _gcAssert(T.SuiteConfiguration memory target, uint256 count, uint256 freezeCount)
        private
        view
    {
        _gaBinding(target);
        _raAssert(target, raRows.length);
        address owner = target.owners[6];
        require(
            Consent(owner).policyRecord(1, policy.phaseId, policy.policyHash) == policyRecord,
            "original policy retained"
        );
        for (uint256 i; i < economicTerms.length; ++i) {
            require(
                Consent(owner).economicsRecord(economicTerms[i]) == economicRecords[i],
                "original economics map"
            );
            require(
                Economics(owner)
                    .economicsRecordForBinding(
                        economicTerms[i],
                        artistId,
                        finalGeneration,
                        Binding(target.owners[0]).binding(1).bindingHash
                    ) == economicRecords[i],
                "original generation association key"
            );
        }
        require(
            Sales(owner).saleConsentRecord(saleRecord).bindingGeneration == finalGeneration,
            "original16 generation retained"
        );
        for (uint256 i; i < count; ++i) {
            require(
                Content(owner).contentConsentRecord(contentRecords[i]).bindingGeneration
                    == finalGeneration,
                "every original17 generation"
            );
            require(
                Content(owner).contentConsentAt(contents[i], finalGeneration).recordHash
                    == contentRecords[count - 1],
                "latest repeated17 exact scope"
            );
            require(
                Content(owner).contentConsentAt(contents[i], 1).recordHash == 0,
                "no generation1 alias"
            );
            require(
                Identity(target.owners[2]).nonceUsed(artistId, contentAuth[i].nonce),
                "all original principal nonce guards"
            );
        }
        for (uint256 i; i < freezeCount; ++i) {
            require(
                Content(owner).contentFreezeRecord(freezeRecords[i]).bindingGeneration
                    == finalGeneration,
                "every original21 row"
            );
        }
        require(
            Content(owner)
            .contentFreezeAt(1, finalGeneration, address(metadata), freezes[0].lockClasses[0])
            .recordHash == freezeRecords[freezeCount - 1],
            "latest overlapping lock head"
        );
        require(
            Consent(owner)
                .royaltyFreezeRecord(royaltyTerms[0], artistId, finalGeneration)
                .recordHash == royaltyRecords[0],
            "original20 scope key"
        );
    }

    function _gcHash(T.SuiteConfiguration memory target, uint256 count, uint256 freezeCount)
        private
        view
        returns (bytes32 h)
    {
        for (uint256 i; i < count; ++i) {
            h = keccak256(
                abi.encode(h, Content(target.owners[6]).contentConsentRecord(contentRecords[i]))
            );
        }
        for (uint256 i; i < freezeCount; ++i) {
            h = keccak256(
                abi.encode(h, Content(target.owners[6]).contentFreezeRecord(freezeRecords[i]))
            );
        }
        for (uint256 i; i < economicTerms.length; ++i) {
            h = keccak256(
                abi.encode(
                    h, Economics(target.owners[6]).economicsRecordAssociation(economicRecords[i])
                )
            );
        }
        return keccak256(
            abi.encode(
                h,
                Consent(target.owners[6])
                    .royaltyFreezeRecord(royaltyTerms[0], artistId, finalGeneration),
                Sales(target.owners[6]).saleConsentRecord(saleRecord)
            )
        );
    }
}
