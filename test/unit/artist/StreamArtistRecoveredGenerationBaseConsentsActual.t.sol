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
    StreamArtistSaleTypes as Sale
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSaleTypes.sol";
import {
    IStreamArtistSaleAuthority
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleAuthority.sol";
import {
    IStreamArtistSaleConsentOwner as Sales
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleOwner.sol";
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
    IStreamArtistRecoveredHydration as Recovered
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
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
    StreamArtistRecoveredDelegatedConsentHydration as BaseH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredCollectionHydration as CollectionH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredCollectionHydration.sol";
import {
    StreamArtistRecoveredGenerationBaseConsents as BaseCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredGenerationBaseConsents.sol";
import {
    StreamArtistRecoveredGenerationConsents as ContentCodec
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredGenerationConsents.sol";

interface GenerationBaseVm {
    function expectCall(address, bytes calldata, uint64) external;
}

/// @notice Original Artist generation2/3 producers, full seven-owner imports and actual Safe/Archive.
/// @dev Core, governance, Metadata and sale facts are explicit inherited typed boundaries.
/// Authored tests do not establish full-current, gas or maximum carrier acceptance.
contract StreamArtistRecoveredGenerationBaseConsentsActualTest is
    StreamArtistRecoveredGenerationAttestationsActualTest
{
    GenerationBaseVm private constant gbv =
        GenerationBaseVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    T.PolicyConsent[] private policies;
    bytes32[] private policyRecords;
    T.EconomicsConsent[] private economics;
    bytes32[] private economicRecords;
    Sale.Consent[] private sales;
    Sale.Record[] private saleRows;
    T.Authorization[] private saleAuthorizations;

    function testGenerationBaseEconomicsOnlyHasExactTagAndNoInventedContentOrSaleBit() external {
        _gaBaseline(1);
        _gbPolicy();
        (T.AssignmentFact memory first, T.AssignmentFact memory second) =
            coordinator.reads().currentAssignments(1);
        _gbEconomics(first);
        _gbEconomics(second);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _gbPrepare(next);
        (RH.ExportHeader memory h, Payload.Payload memory payload) =
            Payload.decode(p.data[6].typedState, 6);
        require(
            (h.requiredFeatures & uint256(512 | 32)) == 544
                && (h.requiredFeatures & uint256(64 | 128 | 256)) == 0,
            "only actual generation and15 capabilities"
        );
        (ContentH.Bundle memory b, uint64 generation) =
            BaseCodec.decode(p.query, payload.provenance, payload.semanticState);
        require(
            generation == 2 && b.original.economics.length == 2 && b.original.sales.length == 0,
            "complete15 inventory"
        );
        require(
            keccak256(payload.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_GENERATION_BASE_CONSENTS_V1"),
                        uint16(1),
                        uint64(2),
                        b
                    )
                ),
            "independent literal codec"
        );
        require(
            b.consents.length + b.royalties.length + b.freezes.length == 0,
            "no fabricated content rows"
        );
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(next, p, value);
        _gbAssert(next.coordinator.suiteConfiguration());
    }

    function testGenerationBaseSaleOnlyUsesOriginalDirectSafeAndNeedsNoWitness() external {
        _gaBaseline(1);
        _gbSale(true);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _gbPrepare(next);
        require(request.records.witnesses.length == 0, "original16 contains its full preimage");
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & uint256(512 | 64)) == 576
                    && (h.requiredFeatures & uint256(32 | 128 | 256)) == 0,
                "seven headers exact sale capability without content"
            );
        }
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(next, p, value);
        _gbAssert(next.coordinator.suiteConfiguration());
    }

    function testGenerationBaseMixedThirdGenerationAndFullOriginalAttestations() external {
        _gbMixed(true);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _gbPrepare(next);
        (RH.ExportHeader memory h,) = Payload.decode(p.data[6].typedState, 6);
        require(
            (h.requiredFeatures & uint256(512 | 32 | 64 | 128)) == 736
                && (h.requiredFeatures & 256) == 0,
            "complete mixed direct/record profile"
        );
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(next, p, value);
        _gbAssert(next.coordinator.suiteConfiguration());
        _raAssert(next.coordinator.suiteConfiguration(), raRows.length);
    }

    function testGenerationBaseRepeatedImportPreservesOriginalAndFreshDomains() external {
        _gbMixed(false);
        T.SuiteConfiguration memory original = suite;
        bytes32 originalSale = keccak256(
            abi.encode(Sales(original.owners[6]).saleConsentRecord(saleRows[0].recordHash))
        );
        Successor memory middle = _rhCutover();
        _gbTransfer(middle);
        _rhAdopt(middle);
        _gbPolicy();
        _gbSale(true);
        Successor memory last = _rhCutover();
        (, Commit.Prepared memory p) = _gbPrepare(last);
        require(p.admission.provenance.eras.length == 2, "complete A/B provenance");
        _gbTransfer(last);
        require(
            keccak256(
                abi.encode(Sales(original.owners[6]).saleConsentRecord(saleRows[0].recordHash))
            ) == originalSale,
            "original A immutable"
        );
        _gbAssert(last.coordinator.suiteConfiguration());
    }

    function testGenerationBaseRefusesMissingForeignWitnessCapabilityAndSourceThenRetry() external {
        _gbMixed(false);
        Successor memory next = _rhCutover();
        (RH.Request memory request,) = _gbPrepare(next);
        bytes32 before_ = _rhDestinationHash(next);
        RH.Request memory bad = abi.decode(abi.encode(request), (RH.Request));
        bad.records.witnesses[0].economics = new T.EconomicsConsent[](0);
        avm.expectRevert(T.UnsupportedProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(bad);
        bad = abi.decode(abi.encode(request), (RH.Request));
        bad.records.witnesses[0].economics[0].assignmentHash = keccak256("wrong original15 witness");
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(bad);
        bad = abi.decode(abi.encode(request), (RH.Request));
        bad.expectedCapabilities[6].supportedFeatures &= ~uint256(512);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(bad);
        bad = abi.decode(abi.encode(request), (RH.Request));
        ++bad.records.authority.expectedSource[6].ownerState.revision;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(bad);
        require(_rhDestinationHash(next) == before_, "all failed imports unchanged");
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _gbAssert(next.coordinator.suiteConfiguration());
    }

    function testGenerationBaseClosedCodecRejectsForeignGenerationGrantOmissionAndContent()
        external
    {
        _gbMixed(false);
        Successor memory next = _rhCutover();
        (, Commit.Prepared memory p) = _gbPrepare(next);
        (, Payload.Payload memory payload) = Payload.decode(p.data[6].typedState, 6);
        (ContentH.Bundle memory original, uint64 generation) =
            BaseCodec.decode(p.query, payload.provenance, payload.semanticState);
        ContentH.Bundle memory bad = abi.decode(abi.encode(original), (ContentH.Bundle));
        bad.original.economics[0].item.association.bindingGeneration = 1;
        _gbReject(bad, p.query, payload.provenance, generation);
        bad = abi.decode(abi.encode(original), (ContentH.Bundle));
        bad.original.sales[0].item.bindingGeneration = 1;
        _gbReject(bad, p.query, payload.provenance, generation);
        bad = abi.decode(abi.encode(original), (ContentH.Bundle));
        bad.original.policies[0].grant = keccak256("missing original grant");
        _gbReject(bad, p.query, payload.provenance, generation);
        bad = abi.decode(abi.encode(original), (ContentH.Bundle));
        bad.original.economics = new BaseH.Economics[](0);
        _gbReject(bad, p.query, payload.provenance, generation);
        vm.expectRevert();
        this.gbContentDecode(p.query, payload.provenance, payload.semanticState);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gbDecode(
            p.query,
            payload.provenance,
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_GENERATION_CONTENT_CONSENTS_V1"),
                uint16(1),
                generation,
                original
            )
        );
        // Relabeling the exact empty bundle as content is refused by its genuine content predicate.
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gbContentDecode(
            p.query,
            payload.provenance,
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_GENERATION_CONTENT_CONSENTS_V1"),
                uint16(1),
                generation,
                original
            )
        );
        this.gbDecode(p.query, payload.provenance, payload.semanticState);
        require(
            Consent(next.coordinator.suiteConfiguration().owners[6]).economicsRecord(economics[0])
                == 0,
            "validation does not import"
        );
    }

    function testGenerationBaseLateArchiveTwoCallsRollbackAndIdenticalSafeRetry() external {
        _gbMixed(false);
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _gbPrepare(next);
        bytes32 before_ = _rhDestinationHash(next);
        uint256 nonce = rotationSafe.nonce();
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request));
        gbv.expectCall(
            next.coordinator.suiteConfiguration().archive, _gaFirstPage(next, request, p), 2
        );
        uint256 height = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        require(
            _rhDestinationHash(next) == before_ && rotationSafe.nonce() == nonce,
            "seven owners and Safe rollback"
        );
        require(
            Consent(next.coordinator.suiteConfiguration().owners[6]).economicsRecord(economics[0])
                == 0,
            "economics write rolled back"
        );
        require(
            Sales(next.coordinator.suiteConfiguration().owners[6])
                .saleConsentAt(1, sales[0].saleId, sales[0].saleConfigHash) == 0,
            "sale head rolled back"
        );
        vm.roll(height);
        require(this.rhExecuteNewSafe(address(next.registry), call_), "identical Safe retry");
        require(rotationSafe.nonce() == nonce + 1, "one committed Safe nonce");
        _gbAssert(next.coordinator.suiteConfiguration());
    }

    function testGenerationBaseUnusedGrantSelectsExplicitCompleteComposition() external {
        _gbMixed(false);
        bytes32 grant = _raGrant();
        bytes32 original = keccak256(abi.encode(ingress.delegationRecord(grant)));
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _gbPrepare(next);
        (RH.ExportHeader memory h, Payload.Payload memory payload) =
            Payload.decode(p.data[6].typedState, 6);
        require(
            (h.requiredFeatures & 64) != 0
                && abi.decode(payload.semanticState, (bytes32))
                    == keccak256("6529STREAM_ARTIST_RECOVERED_GENERATION_DELEGATED_CONSENTS_V1"),
            "complete unused grant selects explicit new tag"
        );
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gbDecode(p.query, payload.provenance, payload.semanticState);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _gbAssert(next.coordinator.suiteConfiguration());
        require(
            keccak256(abi.encode(next.registry.delegationRecord(grant))) == original,
            "unused grant retained, never projected out"
        );
    }

    function testGenerationOnlyPolicyAndAttestationsRetainOriginalCodecBytes() external {
        _gaBaseline(1);
        _gaRecords();
        _gbPolicy();
        Successor memory next = _rhCutover();
        (RH.Request memory request, Commit.Prepared memory p) = _gbPrepare(next);
        (RH.ExportHeader memory h, Payload.Payload memory payload) =
            Payload.decode(p.data[6].typedState, 6);
        require((h.requiredFeatures & uint256(32 | 64 | 256)) == 0, "no newly invented feature");
        CollectionH.PolicyBundle memory expected = CollectionH.PolicyBundle(
            RH.ownerProvenanceHash(payload.provenance, 6),
            artistId,
            1,
            p.query.policies,
            policyRecords
        );
        require(
            keccak256(payload.semanticState)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_RECOVERED_DIRECT_POLICIES_V1"), expected
                    )
                ),
            "literal original14 codec unchanged"
        );
        require(
            !ContentH.selected(p.data[6].typedState), "old policy codec keeps original import route"
        );
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _gbAssert(next.coordinator.suiteConfiguration());
        _raAssert(next.coordinator.suiteConfiguration(), raRows.length);
    }

    function gbPrepare(T.SuiteConfiguration memory target, RH.Request memory request)
        external
        view
        returns (Commit.Prepared memory)
    {
        return Prepared.prepare(target, request);
    }

    function gbDecode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        BaseCodec.decode(q, p, raw);
    }

    function gbContentDecode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        external
        pure
    {
        ContentCodec.decode(q, p, raw);
    }

    function gbValidate(
        ContentH.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        uint64 generation
    ) external pure {
        BaseCodec.validate(b, q, p, generation);
    }

    function _gbReject(
        ContentH.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        uint64 generation
    ) private {
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.gbValidate(b, q, p, generation);
    }

    function _gbMixed(bool records) private {
        _gaBaseline(2);
        if (records) _gaRecords();
        _gbPolicy();
        (T.AssignmentFact memory first, T.AssignmentFact memory second) =
            coordinator.reads().currentAssignments(1);
        _gbEconomics(first);
        _gbSale(false);
        _gbEconomics(second);
    }

    function _gbPolicy() private {
        T.PolicyConsent memory p = T.PolicyConsent(
            1,
            keccak256(abi.encode("base phase", policies.length)),
            keccak256(abi.encode("base policy", policies.length))
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.policyConsentDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.recordPolicyConsent(p, a);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(p.collectionId, p.phaseId, p.policyHash))
        );
        policies.push(p);
        policyRecords.push(record);
    }

    function _gbEconomics(T.AssignmentFact memory fact) private {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.economicsConsentDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.recordEconomicsConsent(p, a);
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(6, "consent_finality.replay.consent_key", keccak256(abi.encode(p)));
        economics.push(p);
        economicRecords.push(record);
    }

    function _gbSale(bool direct) private {
        RecoveredDelegationSaleFacts facts = new RecoveredDelegationSaleFacts(address(core));
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(facts),
            facts.streamModuleType(),
            facts.streamModuleInterfaceId()
        );
        Sale.Consent memory p = Sale.Consent(1, address(facts), facts.ID(), facts.CONFIG());
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.saleConsentDigest(p, a);
        bytes32 record;
        if (direct) {
            require(
                this.rhExecuteNewSafe(
                    address(ingress),
                    abi.encodeCall(IStreamArtistSaleAuthority.recordSaleConsent, (p, a))
                ),
                "original direct Safe16"
            );
            record = Sales(suite.owners[6]).saleConsentAt(1, p.saleId, p.saleConfigHash);
        } else {
            a.signature = _signature(digest);
            record = ingress.recordSaleConsent(p, a);
        }
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            6,
            "consent_finality.replay.sale_consent_key",
            keccak256(
                abi.encode(p, finalGeneration, Binding(suite.owners[0]).binding(1).bindingHash)
            )
        );
        sales.push(p);
        saleRows.push(Sales(suite.owners[6]).saleConsentRecord(record));
        saleAuthorizations.push(a);
    }

    function _gbRequest() private view returns (RH.Request memory p) {
        p = economics.length != 0 || raRows.length != 0 ? _raRequest() : _rhRequest();
        if (economics.length != 0) p.records.witnesses[0].economics = economics;
        p.records.authority.collections[0].policies = new AH.PolicyKey[](policies.length);
        for (uint256 i; i < policies.length; ++i) {
            p.records.authority.collections[0].policies[i] =
                AH.PolicyKey(policies[i].phaseId, policies[i].policyHash);
        }
    }

    function _gbPrepare(Successor memory next)
        private
        view
        returns (RH.Request memory request, Commit.Prepared memory p)
    {
        request = _gbRequest();
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(p);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(p.data[i].typedState, i);
            require(
                (h.requiredFeatures & 512) != 0 && (h.requiredFeatures & 256) == 0,
                "complete generation with no content capability"
            );
        }
    }

    function _gbTransfer(Successor memory next) private {
        (RH.Request memory request, Commit.Prepared memory p) = _gbPrepare(next);
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(next, p, value);
        _gbAssert(next.coordinator.suiteConfiguration());
    }

    function _gbAssert(T.SuiteConfiguration memory target) private view {
        _gaBinding(target);
        address owner = target.owners[6];
        for (uint256 i; i < policies.length; ++i) {
            require(
                Consent(owner).policyRecord(1, policies[i].phaseId, policies[i].policyHash)
                    == policyRecords[i],
                "all original14 maps"
            );
        }
        for (uint256 i; i < economics.length; ++i) {
            require(
                Consent(owner).economicsRecord(economics[i]) == economicRecords[i],
                "all original15 maps"
            );
            require(
                Economics(owner)
                    .economicsRecordForBinding(
                        economics[i],
                        artistId,
                        finalGeneration,
                        Binding(target.owners[0]).binding(1).bindingHash
                    ) == economicRecords[i],
                "exact current generation association"
            );
            require(
                Economics(owner)
                    .economicsRecordForBinding(
                        economics[i], artistId, 1, Binding(target.owners[0]).binding(1).bindingHash
                    ) == 0,
                "no generation1 alias"
            );
        }
        for (uint256 i; i < sales.length; ++i) {
            require(
                keccak256(abi.encode(Sales(owner).saleConsentRecord(saleRows[i].recordHash)))
                    == keccak256(abi.encode(saleRows[i])),
                "original16 full body/domain retained"
            );
            require(
                Identity(target.owners[2]).nonceUsed(artistId, saleAuthorizations[i].nonce),
                "original16 nonce retained"
            );
            require(
                Sales(owner).saleConsentAt(1, sales[i].saleId, sales[i].saleConfigHash)
                    == saleRows[saleRows.length - 1].recordHash,
                "exact latest repeated sale lookup"
            );
        }
    }
}
