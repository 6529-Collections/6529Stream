// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import {
    IStreamDynamicPrimaryTemplates as DefaultDynamic
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";

interface DefaultArtistCalls {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @notice Actual Artist/Safe/Resolver default authority; Core and governance remain unit-typed.
contract StreamArtistDefaultTemplateConsentTest is ArtistOnboardingFixture {
    DefaultArtistCalls private constant calls =
        DefaultArtistCalls(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _template() private returns (bytes32) {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory e =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        e[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 1, keccak256("artist")
        );
        e[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0xFEE), 0, 999999, keccak256("community")
        );
        address owner = primary.owner();
        vm.prank(owner);
        return primary.createPrimaryTemplate(e, keccak256("default one ppm"));
    }

    function _terms(bytes32 tid, bool frozen) private view returns (T.EconomicsConsent memory) {
        T.AssignmentFact memory f =
            primary.previewArtistDefaultPrimaryTemplateAssignment(1, tid, 0, frozen);
        return T.EconomicsConsent(1, address(primary), PRIMARY, 0, 0, f.assignmentHash);
    }

    function _install(bytes32 tid) private returns (bytes32) {
        address owner = primary.owner();
        vm.prank(owner);
        return primary.setPrimaryTemplateAssignment(PRIMARY, 0, 0, tid, 0);
    }

    function _clearCollection() private {
        (T.AssignmentFact memory f,) = primary.previewArtistPrimaryClear(1, 1, 1);
        T.EconomicsConsent memory p =
            T.EconomicsConsent(1, address(primary), PRIMARY, 1, 1, f.assignmentHash);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        _artistCall(
            abi.encodeCall(
                IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent,
                (p, T.FixedEconomicsCandidate(0, 0, 0, false), a)
            )
        );
        address owner = primary.owner();
        vm.prank(owner);
        primary.clearPrimaryAssignment(PRIMARY, 1, 1);
    }

    function _record(T.EconomicsConsent memory p) private view returns (bytes32) {
        T.Binding memory b = coordinator.reads().acceptedBinding(p.collectionId);
        return IStreamArtistEconomicsEvidence(suite.owners[6])
            .economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash);
    }

    function _assertOriginalArchive(
        T.EconomicsConsent memory p,
        bytes32 templateId,
        T.Authorization memory a,
        bytes32 record
    ) private view {
        T.Binding memory binding_ = coordinator.reads().acceptedBinding(p.collectionId);
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
        IStreamArtistEconomicsEvidence.Association memory association =
            IStreamArtistEconomicsEvidence(suite.owners[6]).economicsRecordAssociation(record);
        require(
            record == expected && association.artistId == binding_.artistId
                && association.bindingGeneration == binding_.generation
                && association.bindingHash == binding_.bindingHash
                && association.payloadHash == keccak256(abi.encode(p))
                && association.originalRecord == record,
            "exact original op15 record and all retained binding association coordinates"
        );
        bytes32 evidenceId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(15),
                address(artist),
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
            archive.artistEvidenceBytesV2(evidenceId, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        T.AssignmentFact memory fact = primary.previewArtistDefaultPrimaryTemplateAssignment(
            p.collectionId, templateId, 0, false
        );
        (bytes32 entries, bytes32 metadata, uint32 share) =
            primary.primaryTemplateConsentFacts(templateId);
        T.SignerApproval memory proof =
            T.SignerApproval(address(artist), ingress.economicsConsentDigest(p, a), true);
        bytes memory evidence = abi.encode(
            keccak256("6529STREAM_PROSPECTIVE_DEFAULT_TEMPLATE_EVIDENCE_V1"),
            templateId,
            false,
            entries,
            metadata,
            share,
            bytes32(0),
            fact
        );
        require(
            schema == 1 && config == coordinator.configurationHash() && op == 15
                && actor == address(artist) && saved == record
                && keccak256(payload)
                    == keccak256(abi.encode(binding_, p, payout, a, proof, evidence, association)),
            "unchanged full original Archive payload and direct threshold-Safe actor"
        );
    }

    function testDefaultTemplateOriginalSafeOp15ArchiveAndCompleteMintRead() public {
        directArtistCalls = true;
        _accept();
        _policy();
        _payout();
        bytes32 tid = _template();
        _clearCollection();
        T.EconomicsConsent memory p = _terms(tid, false);
        require(
            _install(tid) == p.assignmentHash, "owner installs the raw global source independently"
        );
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        T.Authorization memory a = _authorization(false);
        bytes memory data = abi.encodeCall(
            IStreamArtistTemplateEconomicsAuthority.recordProspectiveTemplateEconomicsConsent,
            (p, tid, a)
        );
        require(
            this.executeArtistSafe(data),
            "actual threshold Safe approves collection-specific default use"
        );
        bytes32 record = _record(p);
        _assertOriginalArchive(p, tid, a, record);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory selected =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        require(
            selected.scope == 0 && selected.scopeId == 0
                && selected.assignmentHash == p.assignmentHash,
            "default stays scope zero"
        );
        (, T.AssignmentFact memory royaltyFact) = coordinator.reads().currentAssignments(1);
        _economicsRecord(royaltyFact);
        _ratify();
        _attestations();
        ingress.requireMintConsent(1, PHASE, POLICY);
        uint256 nonce = artist.nonce();
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(data);
        require(
            artist.nonce() == nonce && _roots() == roots && _record(p) == record,
            "original op15 replay is atomic"
        );
    }

    function testFrozenDefaultFirstApprovalUsesRawCurrentFactsAndIdenticalSafeRetry() public {
        directArtistCalls = true;
        _accept();
        bytes32 tid = _template();
        _install(tid);
        address owner = primary.owner();
        vm.prank(owner);
        primary.freezePrimaryAssignment(PRIMARY, 0, 0);
        T.EconomicsConsent memory p = _terms(tid, true);
        T.EconomicsConsent memory mutableTerms = _terms(tid, false);
        require(
            p.assignmentHash != mutableTerms.assignmentHash && _record(p) == 0,
            "unapproved frozen source has its own nonzero preimage"
        );
        T.Authorization memory a = _authorization(false);
        bytes memory data = abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a));
        uint256 nonce = artist.nonce();
        bytes32 digest =
            artist.getTransactionHash(
            address(ingress), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory original = abi.encodeCall(
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
        calls.expectCall(address(ingress), 0, data, 2);
        bytes32 roots = _roots();
        (bool ok,) = address(artist).call(original);
        require(
            !ok && artist.nonce() == nonce && _record(p) == 0 && _roots() == roots,
            "missing payout cannot approve global default use"
        );
        directArtistCalls = false;
        _payout();
        directArtistCalls = true;
        require(
            artist.nonce() == nonce,
            "actual relayed payout keeps complete Safe transaction reusable"
        );
        bytes memory out;
        (ok, out) = address(artist).call(original);
        require(
            ok && abi.decode(out, (bool)) && artist.nonce() == nonce + 1 && _record(p) != 0
                && _record(mutableTerms) == 0,
            "first frozen approval does not require itself or alias mutable terms"
        );
        _clearCollection();
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory selected =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        require(
            selected.scope == 0 && selected.frozen && selected.assignmentHash == p.assignmentHash,
            "configured frozen default selected only after collection clear"
        );
        bytes memory evidence =
            coordinator.reads().requireCurrentArtistEconomics(1, address(primary), address(artist));
        (
            bytes32 domain,
            bytes32 saved,
            bool dynamic_,
            bytes32 entries,
            bytes32 metadata,
            uint32 share,
            bytes32 witness,
            T.AssignmentFact memory fact
        ) = abi.decode(
            evidence, (bytes32, bytes32, bool, bytes32, bytes32, uint32, bytes32, T.AssignmentFact)
        );
        (bytes32 actualEntries, bytes32 actualMetadata, uint32 actualShare) =
            primary.primaryTemplateConsentFacts(tid);
        require(
            domain == keccak256("6529STREAM_CURRENT_DEFAULT_TEMPLATE_EVIDENCE_V1") && saved == tid
                && !dynamic_ && entries == actualEntries && metadata == actualMetadata
                && share == actualShare && witness == 0
                && keccak256(abi.encode(fact))
                    == keccak256(
                        abi.encode(
                            primary.previewArtistDefaultPrimaryTemplateAssignment(1, tid, 0, true)
                        )
                    ),
            "full current source evidence keeps canonical frozen tuple"
        );
    }

    function testDefaultDynamicOriginalRowsKeepConsentAcrossTypedPayoutRotation() public {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory row = _collaborativeProposal(true);
        _accept();
        _collaboratorAcceptance(row, false);
        _payout();
        _collaboratorPayout(address(0xC011AB));
        DefaultDynamic.CollaboratorReference[] memory refs =
            new DefaultDynamic.CollaboratorReference[](1);
        refs[0] = DefaultDynamic.CollaboratorReference(row.account, row.role, row.shareLabelId);
        bytes32 source = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_COLLABORATOR_SOURCE_V1"),
                row.account,
                row.role,
                row.shareLabelId
            )
        );
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory e =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](3);
        e[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 100000, keccak256("artist")
        );
        e[1] =
            IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), source, 600000, row.shareLabelId
        );
        e[2] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("SALE_POSTER"), 300000, keccak256("poster")
        );
        address owner = primary.owner();
        vm.prank(owner);
        bytes32 tid =
            primary.createDynamicPrimaryTemplate(e, keccak256("actual dynamic default"), refs);
        T.EconomicsConsent memory p = _terms(tid, false);
        T.Authorization memory a = _authorization(false);
        require(
            this.executeArtistSafe(
                abi.encodeCall(
                    IStreamArtistTemplateEconomicsAuthority.recordProspectiveTemplateEconomicsConsent,
                    (p, tid, a)
                )
            ),
            "original threshold Safe approves symbolic default template"
        );
        bytes32 record = _record(p);
        require(record != 0 && _install(tid) == p.assignmentHash, "exact raw default installation");
        _clearCollection();
        (bytes32 first,, bytes32 entries, bytes32 witness) =
            primary.previewDynamicCollectionPrimaryProfile(tid, 1, address(this));
        _collaboratorPayout(address(0xC022AB));
        (bytes32 next, address wallet_, bytes32 changedEntries, bytes32 changedWitness) =
            primary.materializeDynamicCollectionPrimaryProfile(tid, 1, address(this), false);
        require(
            first != next && entries != changedEntries && witness != changedWitness
                && _record(p) == record
                && primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash
                    == p.assignmentHash,
            "current typed payout changes materialization without rewriting signed source"
        );
        require(
            wallet_ == IStreamSplitFactory(factory).walletFor(next),
            "actual deterministic default materialization"
        );
        uint256 found;
        for (uint256 i; i < IStreamSplitFactory(factory).profileEntryCount(next); ++i) {
            (address account, uint32 share, bytes32 label) =
                IStreamSplitFactory(factory).profileEntry(next, i);
            if (label == row.shareLabelId) {
                require(
                    account == address(0xC022AB) && share == 600000,
                    "typed collaborator destination"
                );
                ++found;
            }
        }
        require(found == 1, "exact original paid row represented once");
    }
}
