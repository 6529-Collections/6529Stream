// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistOnboardingFixture.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistTemplateEconomicsAuthority.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPrimaryTemplateConsentFacts.sol";

/// @dev Real Safe, Artist owners/Coordinator/Archive and primary Resolver. Core/governance
///      remain the explicitly typed unit boundaries in ArtistOnboardingFixture.
contract StreamArtistTemplateConsentTest is ArtistOnboardingFixture {
    error ProviderUnavailable();

    function testProspectiveLowTakeUsesOriginalSafeDigestRecordAssociationAndArchive() public {
        _accept();
        _payout();
        bytes32 templateId = _template(125_000, keccak256("approved low take"));
        T.EconomicsConsent memory p = _terms(templateId, false);
        T.Authorization memory a = _signed(p);
        T.Binding memory binding_ = coordinator.reads().acceptedBinding(1);
        T.Payout memory payout;
        (payout.account, payout.recordHash) = ingress.artistPayoutAccount(artistId);
        bytes32 expected = StreamArtistEconomicsHashes.economicsRecord(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), suite.core, suite.mintManager
            ),
            p,
            payout.recordHash,
            artistId,
            address(artist),
            a.nonce,
            uint64(block.timestamp)
        );
        bytes32 beforeHash = primary.primaryEconomicsFacts(1, 1, 1).assignmentHash;
        vm.recordLogs();
        bytes32 record = ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            record == expected && beforeHash != p.assignmentHash,
            "original canonical op15 before selection"
        );
        require(
            primary.primaryEconomicsFacts(1, 1, 1).assignmentHash == beforeHash,
            "consent does not install rights"
        );
        _assertAssociation(p, binding_, record);
        _assertAssociationEvent(logs, p, binding_, record);
        _assertArchive(p, templateId, a, binding_, payout, record);
        _install(templateId);
        require(
            primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash == p.assignmentHash,
            "actual bound setter consumes exact consent"
        );
        coordinator.reads().requireCurrentArtistEconomics(1, address(primary), address(artist));
    }

    function testDirectSafeTemplateConsentAndOriginalCurrentReplayLane() public {
        _accept();
        _payout();
        bytes32 templateId = _template(1, keccak256("positive minimum"));
        T.EconomicsConsent memory p = _terms(templateId, false);
        T.Authorization memory a = _authorization(false);
        uint256 safeNonce = artist.nonce();
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistTemplateEconomicsAuthority.recordProspectiveTemplateEconomicsConsent,
                    (p, templateId, a)
                ),
                0
            ),
            "actual direct Safe"
        );
        require(artist.nonce() == safeNonce + 1, "one Safe action");
        _install(templateId);
        bytes32 before_ = _roots();
        a = _signed(p);
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordEconomicsConsent(p, a);
        require(
            _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "old current transport shares replay and rolls back identity"
        );
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, a);
        require(_roots() == before_, "new transport shares original replay");
    }

    function testUnconsentedPreconfiguredLowTakeNeedsProspectiveApproval() public {
        _freshTemplateFixture(4);
        _accept();
        _payout();
        StreamArtistOnboardingReads reads = coordinator.reads();
        T.EconomicsConsent memory p = _terms(templateFixtureId, false);
        T.Authorization memory a = _signed(p);
        bytes32 before_ = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        reads.requireCurrentArtistEconomics(1, address(primary), address(artist));
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        ingress.recordEconomicsConsent(p, a);
        require(_roots() == before_, "current low take cannot self-authorize");
        ingress.recordProspectiveTemplateEconomicsConsent(p, templateFixtureId, a);
        require(
            primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash == p.assignmentHash,
            "approved preconfigured low take"
        );
        reads.requireCurrentArtistEconomics(1, address(primary), address(artist));
    }

    function testAdvertisedProviderFailureRollsBackAndIdenticalSignedRetrySucceeds() public {
        _accept();
        _payout();
        StreamArtistOnboardingReads reads = coordinator.reads();
        bytes32 templateId = _template(200_000, keccak256("retry"));
        T.EconomicsConsent memory p = _terms(templateId, false);
        T.Authorization memory a = _signed(p);
        bytes32 before_ = _roots();
        bytes memory callData = abi.encodeCall(
            IStreamArtistPrimaryTemplateConsentFacts.primaryTemplateConsentFacts, (templateId)
        );
        avm.mockCallRevert(
            address(primary), callData, abi.encodeWithSelector(ProviderUnavailable.selector)
        );
        avm.expectRevert(ProviderUnavailable.selector);
        ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, a);
        require(
            _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "failed new capability has no fallback or partial consume"
        );
        avm.clearMockedCalls();
        bytes32 record = ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, a);
        require(record != 0, "identical signed input retry");
        _install(templateId);
        avm.mockCallRevert(
            address(primary), callData, abi.encodeWithSelector(ProviderUnavailable.selector)
        );
        avm.expectRevert(ProviderUnavailable.selector);
        reads.requireCurrentArtistEconomics(1, address(primary), address(artist));
        avm.clearMockedCalls();
        reads.requireCurrentArtistEconomics(1, address(primary), address(artist));
    }

    function testWrongTemplateMetadataHashAndFreezeCandidateDoNotConsumeNonce() public {
        _accept();
        _payout();
        bytes32 templateId = _template(300_000, keccak256("first terms"));
        bytes32 other = _template(300_000, keccak256("different retained metadata"));
        T.EconomicsConsent memory p = _terms(templateId, false);
        T.Authorization memory a = _signed(p);
        bytes32 before_ = _roots();
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordProspectiveTemplateEconomicsConsent(p, other, a);
        require(_roots() == before_, "signed assignment authenticates actual metadata");
        T.EconomicsConsent memory frozen = _terms(templateId, true);
        T.Authorization memory frozenAuth = _signed(frozen);
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordProspectiveTemplateEconomicsConsent(frozen, templateId, frozenAuth);
        require(
            _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2])
                    .nonceUsed(artistId, frozenAuth.nonce),
            "set-only ingress cannot approve freeze"
        );
        ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, a);
        _install(templateId);
        address owner = primary.owner();
        bytes memory reason = abi.encodeWithSelector(
            IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, uint256(1)
        );
        vm.expectRevert(reason);
        vm.prank(owner);
        primary.freezePrimaryAssignment(PRIMARY, 1, 1);
        vm.expectRevert(reason);
        vm.prank(owner);
        primary.clearPrimaryAssignment(PRIMARY, 1, 1);
        require(
            primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash == p.assignmentHash,
            "freeze/clear stay explicitly closed"
        );
    }

    function testWrongResolverClassScopeZeroAndForeignCallerStayClosed() public {
        _accept();
        _payout();
        bytes32 templateId = _template(100_000, keccak256("bounded key"));
        T.EconomicsConsent memory original = _terms(templateId, false);
        for (uint8 i; i < 6; ++i) {
            T.EconomicsConsent memory p = _terms(templateId, false);
            if (i == 0) p.resolver = address(royalty);
            if (i == 1) p.revenueClass = keccak256("ROYALTY_ERC2981");
            if (i == 2) p.scope = 2;
            if (i == 3) p.scopeId = 2;
            if (i == 4) p.assignmentHash = 0;
            T.Authorization memory a = _signed(p);
            bytes32 before_ = _roots();
            avm.expectRevert(T.UnsupportedProfile.selector);
            ingress.recordProspectiveTemplateEconomicsConsent(
                p, i == 5 ? bytes32(0) : templateId, a
            );
            require(_roots() == before_, "unsupported candidate has no state");
        }
        T.Authorization memory unsigned = _authorization(false);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordProspectiveTemplateEconomicsConsent(original, templateId, unsigned);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        coordinator.coordinateRecordProspectiveTemplateEconomicsConsent(
            address(artist), original, templateId, unsigned
        );
    }

    function testMissingPayoutThenSameSignatureWorksAfterActualDesignation() public {
        _accept();
        bytes32 templateId = _template(250_000, keccak256("payout required"));
        T.EconomicsConsent memory p = _terms(templateId, false);
        T.Authorization memory a = _signed(p);
        bytes32 before_ = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("payout"))
        );
        ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, a);
        require(_roots() == before_, "missing payout failed before consume");
        _payout();
        ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, a);
        _install(templateId);
    }

    function testPaidCollaboratorCannotDisappearIntoStaticRows() public {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory row = _collaborativeProposal(true);
        _accept();
        _collaboratorAcceptance(row, false);
        _payout();
        bytes32 templateId = _template(100_000, keccak256("no paid collaborator support"));
        T.EconomicsConsent memory p = _terms(templateId, false);
        T.Authorization memory a = _signed(p);
        bytes32 before_ = _roots();
        avm.expectRevert(T.UnsupportedProfile.selector);
        ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, a);
        require(
            _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "paid collaborator not erased"
        );
    }

    function testTypedBindingReplacementNeedsNewAssociationPreservesOriginal() public {
        _accept();
        _payout();
        StreamArtistOnboardingReads reads = coordinator.reads();
        bytes32 templateId = _template(100_000, keccak256("current association"));
        T.EconomicsConsent memory p = _terms(templateId, false);
        T.Binding memory oldBinding = reads.acceptedBinding(1);
        bytes32 original =
            ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, _signed(p));
        _install(templateId);
        // Only authoritative Binding/Attribution are a labelled replacement boundary.
        // Both artists, Safe signatures, Identity, Consent and Archive are actual.
        T.Binding memory next = _correctEconomicsBinding(address(0xCAFE));
        bytes memory reason =
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"));
        vm.expectRevert(reason);
        reads.requireCurrentArtistEconomics(1, address(primary), address(0xCAFE));
        vm.expectRevert(reason);
        primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        bytes32 fresh = ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, _signed(p));
        require(fresh != original, "new binding distinct original op15 record");
        IStreamArtistEconomicsEvidence owner = IStreamArtistEconomicsEvidence(suite.owners[6]);
        require(
            owner.economicsRecordForBinding(
                p, oldBinding.artistId, oldBinding.generation, oldBinding.bindingHash
            ) == original,
            "historic association unchanged"
        );
        require(
            owner.economicsRecordForBinding(p, next.artistId, next.generation, next.bindingHash)
                == fresh,
            "exact current association"
        );
        require(
            owner.economicsRecordAssociation(fresh).originalRecord == original,
            "continuation anchors original"
        );
        reads.requireCurrentArtistEconomics(1, address(primary), address(0xCAFE));
        require(
            primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash == p.assignmentHash,
            "fresh approval restores current resolution"
        );
    }

    function testCurrentPayoutRevisionChangesMaterializationPreservesConsent() public {
        _accept();
        _payout();
        StreamArtistOnboardingReads reads = coordinator.reads();
        bytes32 templateId = _template(100_000, keccak256("operative payout"));
        T.EconomicsConsent memory p = _terms(templateId, false);
        bytes32 record =
            ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, _signed(p));
        _install(templateId);
        (, address oldWallet,) =
            primary.materializeCollectionPrimaryProfile(templateId, 1, address(0), true);
        (, bytes32 previous) = ingress.artistPayoutAccount(artistId);
        T.PayoutDesignation memory designation =
            T.PayoutDesignation(artistId, address(0xCAFE), previous);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(designation, a));
        ingress.recordPayoutDesignation(designation, a);
        reads.requireCurrentArtistEconomics(1, address(primary), address(0xCAFE));
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("payout"))
        );
        reads.requireCurrentArtistEconomics(1, address(primary), address(artist));
        (, address newWallet,) =
            primary.materializeCollectionPrimaryProfile(templateId, 1, address(0), true);
        require(
            newWallet != oldWallet
                && IStreamSplitWallet(oldWallet).aggregateSharePpm(address(artist)) == 100_000
                && IStreamSplitWallet(newWallet).aggregateSharePpm(address(0xCAFE)) == 100_000,
            "actual current payout and immutable old wallet"
        );
        require(
            IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) == record,
            "original designation stays in immutable consent"
        );
    }

    function testOldInitialFactsAndFixedProspectiveRouteStayBounded() public {
        _accept();
        _payout();
        bytes32 templateId = _template(499_999, keccak256("old floor"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistPrimaryTemplateFacts.UnsupportedArtistPrimaryTemplate.selector,
                templateId
            )
        );
        primary.primaryTemplateEconomicsFacts(templateId);
        T.EconomicsConsent memory p = _terms(templateId, false);
        T.FixedEconomicsCandidate memory candidate =
            T.FixedEconomicsCandidate(templateId, 0, 0, false);
        T.Authorization memory a = _signed(p);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.UnverifiedSplitProfile.selector, templateId
            )
        );
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        require(
            type(IStreamArtistEconomicsAuthority).interfaceId == 0x9417a96b
                && type(IStreamArtistPrimaryTemplateFacts).interfaceId == 0x2753a98b,
            "unchanged original interface IDs"
        );
        require(
            ingress.supportsInterface(type(IStreamArtistEconomicsAuthority).interfaceId)
                && ingress.supportsInterface(
                    type(IStreamArtistTemplateEconomicsAuthority).interfaceId
                ) && primary.supportsInterface(type(IStreamArtistPrimaryTemplateFacts).interfaceId)
                && primary.supportsInterface(
                    type(IStreamArtistPrimaryTemplateConsentFacts).interfaceId
                ),
            "additive capabilities"
        );
    }

    function testZeroArtistShareAndUnsupportedSourcesCannotObtainConsent() public {
        _accept();
        _payout();
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](1);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0xFEE), 0, 1_000_000, keccak256("protocol")
        );
        vm.prank(primary.owner());
        bytes32 templateId = primary.createPrimaryTemplate(entries, keccak256("no artist"));
        bytes memory reason = abi.encodeWithSelector(
            IStreamArtistPrimaryTemplateFacts.UnsupportedArtistPrimaryTemplate.selector, templateId
        );
        vm.expectRevert(reason);
        IStreamArtistPrimaryTemplateConsentFacts(address(primary))
            .primaryTemplateConsentFacts(templateId);
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, address(primary), PRIMARY, 1, 1, keccak256("cannot fabricate approval")
        );
        T.Authorization memory a = _signed(p);
        bytes32 before_ = _roots();
        vm.expectRevert(reason);
        ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, a);
        require(_roots() == before_, "no zero-artist authorization");
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("SALE_POSTER"), 1_000_000, keccak256("artist")
        );
        vm.prank(primary.owner());
        templateId = primary.createPrimaryTemplate(entries, keccak256("poster is not artist"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistPrimaryTemplateFacts.UnsupportedArtistPrimaryTemplate.selector,
                templateId
            )
        );
        ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, a);
        require(_roots() == before_, "no poster substitution");
    }

    function testInitialMajorityCurrentConsentKeepsOriginalEvidenceAndSelection() public {
        _freshTemplateFixture(1);
        _accept();
        _payout();
        T.EconomicsConsent memory p = _terms(templateFixtureId, false);
        bytes memory beforeEvidence =
            coordinator.reads().requireCurrentArtistEconomics(1, address(primary), address(artist));
        T.Authorization memory a = _signed(p);
        bytes32 record = ingress.recordEconomicsConsent(p, a);
        _install(templateFixtureId);
        require(
            record != 0
                && primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash
                    == p.assignmentHash,
            "original current consent authorizes exact existing majority template"
        );
        require(
            keccak256(beforeEvidence)
                == keccak256(
                    coordinator.reads()
                        .requireCurrentArtistEconomics(1, address(primary), address(artist))
                ),
            "unchanged initial template supplementary evidence"
        );
    }

    function testActualFacadeMintReadUsesApprovedLowTakeAndOriginalPrerequisites() public {
        _accept();
        _policy();
        _payout();
        bytes32 templateId = _template(100_000, keccak256("complete artist mint read"));
        T.EconomicsConsent memory p = _terms(templateId, false);
        ingress.recordProspectiveTemplateEconomicsConsent(p, templateId, _signed(p));
        _install(templateId);
        (, T.AssignmentFact memory royaltyFact) = coordinator.reads().currentAssignments(1);
        _economicsRecord(royaltyFact);
        _ratify();
        _attestations();
        // Real facade -> current Resolver -> binding-specific consent, then every
        // original policy/payout/royalty/content/attestation floor. Core is still unit-typed.
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(
            primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash == p.assignmentHash,
            "mint read consumes the approved low-take assignment"
        );
    }

    function testChangedArtistProductsRemainWithinRuntimeLimit() public view {
        require(
            address(ingress).code.length <= 24_576 && address(coordinator).code.length <= 24_576
                && address(coordinator.reads()).code.length <= 24_576
                && address(primary).code.length <= 24_576
                && address(StreamArtistOnboardingReadDeployment).code.length <= 24_576
                && address(StreamArtistTemplateEconomicsReads).code.length <= 24_576,
            "actual changed runtime EIP170"
        );
    }

    function _template(uint32 share, bytes32 metadata) private returns (bytes32) {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), share, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0xFEE), 0, 1_000_000 - share, keccak256("protocol")
        );
        vm.prank(primary.owner());
        return primary.createPrimaryTemplate(entries, metadata);
    }

    function _terms(bytes32 templateId, bool frozen)
        private
        view
        returns (T.EconomicsConsent memory)
    {
        T.AssignmentFact memory fact = IStreamArtistPrimaryTemplateConsentFacts(address(primary))
            .previewArtistPrimaryTemplateConsentAssignment(1, templateId, 0, frozen);
        return T.EconomicsConsent(1, address(primary), PRIMARY, 1, 1, fact.assignmentHash);
    }

    function _signed(T.EconomicsConsent memory p) private returns (T.Authorization memory a) {
        a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
    }

    function _install(bytes32 templateId) private {
        vm.prank(primary.owner());
        primary.setPrimaryTemplateAssignment(PRIMARY, 1, 1, templateId, 0);
    }

    function _assertAssociation(T.EconomicsConsent memory p, T.Binding memory b, bytes32 record)
        private
        view
    {
        IStreamArtistEconomicsEvidence.Association memory association =
            IStreamArtistEconomicsEvidence(suite.owners[6]).economicsRecordAssociation(record);
        require(
            association.artistId == b.artistId && association.bindingGeneration == b.generation
                && association.bindingHash == b.bindingHash
                && association.payloadHash == keccak256(abi.encode(p))
                && association.originalRecord == record,
            "full original binding association"
        );
    }

    function _assertAssociationEvent(
        Vm.Log[] memory logs,
        T.EconomicsConsent memory p,
        T.Binding memory b,
        bytes32 record
    ) private view {
        bytes32 topic = keccak256(
            "ArtistEconomicsConsentAssociated(uint16,bytes32,bytes32,bytes32,uint64,bytes32,bytes32)"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != suite.owners[6] || logs[i].topics.length == 0
                    || logs[i].topics[0] != topic
            ) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == record
                    && logs[i].topics[2] == b.artistId && logs[i].topics[3] == b.bindingHash
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(uint16(1), b.generation, keccak256(abi.encode(p)), record)
                        ),
                "full original association event"
            );
            ++found;
        }
        require(found == 1, "one original owner event");
    }

    function _assertArchive(
        T.EconomicsConsent memory p,
        bytes32 templateId,
        T.Authorization memory a,
        T.Binding memory binding_,
        T.Payout memory payout,
        bytes32 record
    ) private view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(15),
                address(this),
                record
            )
        );
        (
            uint16 schema,
            bytes32 config,
            uint16 op,
            address actor,
            bytes32 saved,,,
            bytes memory payload
        ) = abi.decode(
            archive.artistEvidenceBytesV2(id, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            schema == 1 && config == coordinator.configurationHash() && op == 15
                && actor == address(this) && saved == record,
            "original archive envelope"
        );
        (bytes32 entries, bytes32 metadata, uint32 share) = IStreamArtistPrimaryTemplateConsentFacts(
                address(primary)
            ).primaryTemplateConsentFacts(templateId);
        T.AssignmentFact memory fact = IStreamArtistPrimaryTemplateConsentFacts(address(primary))
            .previewArtistPrimaryTemplateConsentAssignment(1, templateId, 0, false);
        bytes memory evidence = abi.encode(
            keccak256("6529STREAM_PROSPECTIVE_PRIMARY_TEMPLATE_ECONOMICS_EVIDENCE_V1"),
            templateId,
            entries,
            metadata,
            share,
            fact
        );
        T.SignerApproval memory proof =
            T.SignerApproval(address(artist), ingress.economicsConsentDigest(p, a), false);
        IStreamArtistEconomicsEvidence.Association memory association =
            IStreamArtistEconomicsEvidence(suite.owners[6]).economicsRecordAssociation(record);
        require(
            keccak256(payload)
                == keccak256(abi.encode(binding_, p, payout, a, proof, evidence, association)),
            "all original op15 payload and exact retained template evidence"
        );
    }
}
