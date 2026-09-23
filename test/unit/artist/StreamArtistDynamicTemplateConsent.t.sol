// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistOnboardingFixture.sol";
import {
    IStreamDynamicPrimaryTemplates as DynamicTemplates
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";
import {
    IStreamArtistDynamicPrimaryTemplateFacts as DynamicFacts
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistDynamicPrimaryTemplateFacts.sol";

/// @notice Actual Artist/Safe/Collaborator/Resolver/Archive, with the existing typed Core/governance.
contract StreamArtistDynamicTemplateConsentTest is ArtistOnboardingFixture {
    error DynamicProviderUnavailable();

    function _prepare(bool designation) private returns (C.BindingAcceptance memory row) {
        _collaboratorIdentity(false);
        row = _collaborativeProposal(true);
        _accept();
        _collaboratorAcceptance(row, false);
        _payout();
        if (designation) _collaboratorPayout(address(0xC011AB));
    }

    function _template(C.BindingAcceptance memory row) private returns (bytes32 id) {
        DynamicTemplates.CollaboratorReference[] memory refs =
            new DynamicTemplates.CollaboratorReference[](1);
        refs[0] = DynamicTemplates.CollaboratorReference(row.account, row.role, row.shareLabelId);
        bytes32 source = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_COLLABORATOR_SOURCE_V1"),
                row.account,
                row.role,
                row.shareLabelId
            )
        );
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](4);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 100000, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), source, 600000, row.shareLabelId
        );
        entries[2] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("SALE_POSTER"), 200000, keccak256("poster")
        );
        entries[3] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0xFEE), 0, 100000, keccak256("protocol")
        );
        address owner = primary.owner();
        vm.prank(owner);
        return primary.createDynamicPrimaryTemplate(
            entries, keccak256("actual accepted collaborator terms"), refs
        );
    }

    function _terms(bytes32 id) private view returns (T.EconomicsConsent memory) {
        return T.EconomicsConsent(
            1,
            address(primary),
            PRIMARY,
            1,
            1,
            primary.primaryAssignmentHash(PRIMARY, 1, 1, 2, 0, id, 0, false)
        );
    }

    function _signed(T.EconomicsConsent memory p) private returns (T.Authorization memory a) {
        a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
    }

    function _install(bytes32 id) private {
        address owner = primary.owner();
        vm.prank(owner);
        primary.setPrimaryTemplateAssignment(PRIMARY, 1, 1, id, 0);
    }

    function testDynamicActualArtistOp15PreservesRecordAssociationArchiveAndMintRead() public {
        C.BindingAcceptance memory row = _prepare(true);
        _policy();
        bytes32 id = _template(row);
        T.EconomicsConsent memory p = _terms(id);
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
        bytes32 beforeAssignment = primary.primaryEconomicsFacts(1, 1, 1).assignmentHash;
        bytes32 record = ingress.recordProspectiveTemplateEconomicsConsent(p, id, a);
        require(
            record == expected
                && primary.primaryEconomicsFacts(1, 1, 1).assignmentHash == beforeAssignment,
            "original op15 records consent without selecting rights"
        );
        _archive(p, id, a, binding_, payout, record);
        _install(id);
        require(
            primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash == p.assignmentHash,
            "exact bound assignment setter"
        );
        coordinator.reads().requireCurrentArtistEconomics(1, address(primary), address(artist));
        // A full current mint read also needs independently approved collaborator-bearing royalties.
        (T.EconomicsConsent memory royaltyTerms, T.FixedEconomicsCandidate memory candidate) =
            _collaboratorCandidate(address(royalty), address(0xC011AB));
        ingress.recordProspectiveEconomicsConsent(royaltyTerms, candidate, _signed(royaltyTerms));
        address owner = royalty.owner();
        vm.prank(owner);
        royalty.configureCollectionRoyalty(1, candidate.profileHash, 500);
        _ratify();
        _attestations();
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(
            ingress.collaboratorAt(1, row.generation, 0).acceptanceRecordHash != 0,
            "real individual acceptance retained"
        );
    }

    function _archive(
        T.EconomicsConsent memory p,
        bytes32 templateId,
        T.Authorization memory a,
        T.Binding memory binding_,
        T.Payout memory payout,
        bytes32 record
    ) private view {
        IStreamArtistEconomicsEvidence.Association memory association =
            IStreamArtistEconomicsEvidence(suite.owners[6]).economicsRecordAssociation(record);
        require(
            association.artistId == binding_.artistId
                && association.bindingGeneration == binding_.generation
                && association.bindingHash == binding_.bindingHash
                && association.payloadHash == keccak256(abi.encode(p))
                && association.originalRecord == record,
            "all original association coordinates"
        );
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
            "full original Archive envelope"
        );
        (bytes32 entries, bytes32 metadata, uint32 share, bytes32 beneficiaries) =
            primary.dynamicPrimaryTemplateFacts(1, templateId);
        T.AssignmentFact memory fact =
            primary.previewArtistDynamicPrimaryTemplateAssignment(1, templateId, 0, false);
        require(
            share == 100000 && fact.assignmentHash == p.assignmentHash,
            "arbitrary collaborator label is not artist share"
        );
        bytes memory evidence = abi.encode(
            keccak256("6529STREAM_PROSPECTIVE_DYNAMIC_PRIMARY_TEMPLATE_EVIDENCE_V1"),
            templateId,
            entries,
            metadata,
            share,
            beneficiaries,
            fact
        );
        T.SignerApproval memory proof =
            T.SignerApproval(address(artist), ingress.economicsConsentDigest(p, a), false);
        require(
            keccak256(payload)
                == keccak256(abi.encode(binding_, p, payout, a, proof, evidence, association)),
            "exact original payload plus symbolic poster and actual collaborator evidence"
        );
    }

    function testDynamicMissingCollaboratorPayoutKeepsIdenticalThresholdSafeConsentRetry() public {
        C.BindingAcceptance memory row = _prepare(false);
        bytes32 id = _template(row);
        T.EconomicsConsent memory p = _terms(id);
        T.Authorization memory a = _authorization(false);
        bytes memory data = abi.encodeCall(
            IStreamArtistTemplateEconomicsAuthority.recordProspectiveTemplateEconomicsConsent,
            (p, id, a)
        );
        uint256 nonce = artist.nonce();
        bytes32 digest = artist.getTransactionHash(
            address(ingress), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory call_ = abi.encodeCall(
            artist.execTransaction,
            (
                address(ingress),
                0,
                data,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                safeThresholdSignature(keys, digest)
            )
        );
        bytes32 before_ = _roots();
        (bool ok,) = address(artist).call(call_);
        require(
            !ok && artist.nonce() == nonce && _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "missing operative collaborator cannot consume either replay lane"
        );
        _collaboratorPayout(address(0xC011AB));
        bytes memory out;
        (ok, out) = address(artist).call(call_);
        require(
            ok && abi.decode(out, (bool)) && artist.nonce() == nonce + 1,
            "identical complete signed Safe bytes retry after real designation"
        );
        _install(id);
        coordinator.reads().requireCurrentArtistEconomics(1, address(primary), address(artist));
    }

    function testDynamicActualCollaboratorPayoutRotationPreservesConsentAndOriginalSource() public {
        C.BindingAcceptance memory row = _prepare(true);
        bytes32 id = _template(row);
        T.EconomicsConsent memory p = _terms(id);
        bytes32 record = ingress.recordProspectiveTemplateEconomicsConsent(p, id, _signed(p));
        _install(id);
        (bytes32 firstProfile,, bytes32 firstEntries, bytes32 firstWitness) =
            primary.previewDynamicCollectionPrimaryProfile(id, 1, address(this));
        _collaboratorPayout(address(0xC022AB));
        (bytes32 nextProfile, address nextWallet, bytes32 nextEntries, bytes32 nextWitness) =
            primary.materializeDynamicCollectionPrimaryProfile(id, 1, address(this), false);
        require(
            firstProfile != nextProfile && firstEntries != nextEntries
                && firstWitness != nextWitness
                && primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash
                    == p.assignmentHash
                && IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) == record,
            "new artist-signed payout changes concrete profile without new source or consent"
        );
        require(
            nextWallet == IStreamSplitFactory(factory).walletFor(nextProfile),
            "current concrete deterministic wallet"
        );
        coordinator.reads().requireCurrentArtistEconomics(1, address(primary), address(artist));
        uint256 found;
        for (uint256 i; i < IStreamSplitFactory(factory).profileEntryCount(nextProfile); ++i) {
            (address account, uint32 share, bytes32 label) =
                IStreamSplitFactory(factory).profileEntry(nextProfile, i);
            if (label == row.shareLabelId) {
                require(
                    account == address(0xC022AB) && share == 600000,
                    "typed collaborator payout rather than signing Safe"
                );
                ++found;
            }
        }
        require(found == 1, "paid original row remains represented");
    }

    function testDynamicAdvertisedFailureNoFallbackAndUnconsentedBoundSetRejects() public {
        C.BindingAcceptance memory row = _prepare(true);
        bytes32 id = _template(row);
        T.EconomicsConsent memory p = _terms(id);
        T.Authorization memory a = _signed(p);
        address owner = primary.owner();
        vm.prank(owner);
        (bool ok,) = address(primary)
            .call(abi.encodeCall(primary.setPrimaryTemplateAssignment, (PRIMARY, 1, 1, id, 0)));
        require(!ok, "structural facts grant no assignment authority");
        bytes32 before_ = _roots();
        avm.mockCallRevert(
            address(primary),
            abi.encodeCall(DynamicFacts.dynamicPrimaryTemplateFacts, (1, id)),
            abi.encodeWithSelector(DynamicProviderUnavailable.selector)
        );
        avm.expectRevert(DynamicProviderUnavailable.selector);
        ingress.recordProspectiveTemplateEconomicsConsent(p, id, a);
        require(
            _roots() == before_
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "advertised failure is terminal before original nonce consume"
        );
        avm.clearMockedCalls();
        ingress.recordProspectiveTemplateEconomicsConsent(p, id, a);
        _install(id);
        StreamArtistOnboardingReads reads = coordinator.reads();
        avm.mockCallRevert(
            address(primary),
            abi.encodeCall(DynamicFacts.dynamicPrimaryTemplateFacts, (1, id)),
            abi.encodeWithSelector(DynamicProviderUnavailable.selector)
        );
        avm.expectRevert(DynamicProviderUnavailable.selector);
        reads.requireCurrentArtistEconomics(1, address(primary), address(artist));
        avm.clearMockedCalls();
        reads.requireCurrentArtistEconomics(1, address(primary), address(artist));
    }
}
