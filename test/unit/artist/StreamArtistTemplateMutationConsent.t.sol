// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistTemplateMutationAuthority.sol";
import {
    IStreamDynamicPrimaryTemplates as MutationDynamic
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";

interface TemplateMutationCalls {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @notice Real Artist/Safe/Resolver mutation; the original unit Core and governance boundary remain explicit.
contract StreamArtistTemplateMutationConsentTest is ArtistOnboardingFixture {
    TemplateMutationCalls private constant calls =
        TemplateMutationCalls(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _template(bytes32 metadata) private returns (bytes32) {
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
        return primary.createPrimaryTemplate(e, metadata);
    }

    function _terms(bytes32 tid, uint8 scope, uint256 id, bool frozen)
        private
        view
        returns (T.EconomicsConsent memory)
    {
        T.AssignmentFact memory f =
            primary.previewArtistScopedPrimaryTemplateAssignment(1, scope, id, tid, 0, frozen);
        return T.EconomicsConsent(1, address(primary), PRIMARY, scope, id, f.assignmentHash);
    }

    function _approve(T.EconomicsConsent memory p, bytes32 tid) private {
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        _artistCall(
            abi.encodeCall(
                IStreamArtistTemplateEconomicsAuthority.recordProspectiveTemplateEconomicsConsent,
                (p, tid, a)
            )
        );
    }

    function _install(bytes32 tid, uint8 scope, uint256 id) private returns (bytes32) {
        address owner = primary.owner();
        vm.prank(owner);
        return primary.setPrimaryTemplateAssignment(PRIMARY, scope, id, tid, 0);
    }

    function _freeze(T.EconomicsConsent memory p) private returns (bytes32) {
        address owner = primary.owner();
        vm.prank(owner);
        return primary.freezePrimaryAssignment(PRIMARY, p.scope, p.scopeId);
    }

    function _approveFreeze(T.EconomicsConsent memory p)
        private
        returns (T.Authorization memory a)
    {
        a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        _artistCall(
            abi.encodeCall(
                IStreamArtistTemplateMutationAuthority.recordProspectiveTemplateFreezeConsent,
                (p, a)
            )
        );
    }

    function _record(T.EconomicsConsent memory p) private view returns (bytes32) {
        T.Binding memory b = coordinator.reads().acceptedBinding(p.collectionId);
        return IStreamArtistEconomicsEvidence(suite.owners[6])
            .economicsRecordForBinding(p, b.artistId, b.generation, b.bindingHash);
    }

    function _assertFreezeArchive(
        T.EconomicsConsent memory p,
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory current,
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
        T.AssignmentFact memory previous = primary.previewArtistScopedPrimaryTemplateAssignment(
            p.collectionId, p.scope, p.scopeId, current.templateId, 0, false
        );
        T.AssignmentFact memory next = primary.previewArtistScopedPrimaryTemplateAssignment(
            p.collectionId, p.scope, p.scopeId, current.templateId, 0, true
        );
        (bytes32 entries, bytes32 metadata, uint32 share) =
            primary.primaryTemplateConsentFacts(current.templateId);
        T.SignerApproval memory proof =
            T.SignerApproval(address(artist), ingress.economicsConsentDigest(p, a), true);
        bytes memory evidence = abi.encode(
            keccak256("6529STREAM_PROSPECTIVE_TEMPLATE_FREEZE_EVIDENCE_V1"),
            current,
            previous,
            next,
            false,
            entries,
            metadata,
            share,
            bytes32(0)
        );
        require(
            schema == 1 && config == coordinator.configurationHash() && op == 15
                && actor == address(artist) && saved == record
                && keccak256(payload)
                    == keccak256(abi.encode(binding_, p, payout, a, proof, evidence, association)),
            "unchanged full original Archive payload and direct threshold-Safe actor"
        );
    }

    function testCollectionTemplateFreezeRequiresExactNewHashAndKeepsOriginalArchive() public {
        directArtistCalls = true;
        _accept();
        _payout();
        bytes32 tid = _template(keccak256("freeze collection"));
        T.EconomicsConsent memory mutableTerms = _terms(tid, 1, 1, false);
        _approve(mutableTerms, tid);
        _install(tid, 1, 1);
        T.EconomicsConsent memory frozen = _terms(tid, 1, 1, true);
        require(
            frozen.assignmentHash != mutableTerms.assignmentHash,
            "frozen bit is signed in canonical hash"
        );
        address owner = primary.owner();
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        vm.prank(owner);
        primary.freezePrimaryAssignment(PRIMARY, 1, 1);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory before_ =
            primary.primaryEconomicsFacts(1, 1, 1);
        T.Authorization memory a = _approveFreeze(frozen);
        _assertFreezeArchive(frozen, before_, a, _record(frozen));
        require(
            _freeze(frozen) == frozen.assignmentHash
                && primary.resolvePrimaryAssignment(1, 0, PRIMARY).frozen,
            "exact approved template freeze"
        );
        bytes memory error_ = abi.encodeWithSelector(
            IStreamRevenueResolver.PrimaryAssignmentFrozen.selector, PRIMARY, uint8(1), uint256(1)
        );
        vm.expectRevert(error_);
        vm.prank(owner);
        primary.clearPrimaryAssignment(PRIMARY, 1, 1);
        vm.expectRevert(error_);
        vm.prank(owner);
        primary.setPrimaryTemplateAssignment(PRIMARY, 1, 1, tid, 0);
        vm.expectRevert(error_);
        vm.prank(owner);
        primary.freezePrimaryAssignment(PRIMARY, 1, 1);
    }

    function testTokenTemplateDriftRejectsThenIdenticalSignedSafeFreezeApprovalRetries() public {
        directArtistCalls = true;
        _accept();
        _payout();
        core.setTokenCollection(41, 1);
        core.setTokenCollection(42, 1);
        bytes32 first = _template(keccak256("token first"));
        bytes32 second = _template(keccak256("token second"));
        _approve(_terms(first, 2, 41, false), first);
        _approve(_terms(second, 2, 41, false), second);
        _install(first, 2, 41);
        _approve(_terms(first, 2, 42, false), first);
        _install(first, 2, 42);
        T.EconomicsConsent memory p = _terms(first, 2, 41, true);
        T.Authorization memory a = _authorization(false);
        bytes memory data = abi.encodeCall(
            IStreamArtistTemplateMutationAuthority.recordProspectiveTemplateFreezeConsent, (p, a)
        );
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
        _install(second, 2, 41);
        calls.expectCall(address(ingress), 0, data, 2);
        bytes32 roots = _roots();
        (bool ok,) = address(artist).call(original);
        require(
            !ok && artist.nonce() == nonce && _record(p) == 0 && roots == _roots(),
            "source drift cannot consume approval or Safe nonce"
        );
        _install(first, 2, 41);
        bytes memory out;
        (ok, out) = address(artist).call(original);
        require(
            ok && abi.decode(out, (bool)) && artist.nonce() == nonce + 1
                && _freeze(p) == p.assignmentHash,
            "identical complete signed Safe retry approves exact current source"
        );
        require(
            _terms(first, 2, 42, true).assignmentHash != p.assignmentHash
                && _record(_terms(first, 2, 42, true)) == 0
                && !primary.primaryEconomicsFacts(1, 2, 42).frozen,
            "token41 frozen consent cannot cover token42 or collection"
        );
        address owner = primary.owner();
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        vm.prank(owner);
        primary.freezePrimaryAssignment(PRIMARY, 2, 42);
        bytes32 saved = _roots();
        nonce = artist.nonce();
        (ok,) = address(artist).call(original);
        require(
            !ok && artist.nonce() == nonce && _roots() == saved, "full Safe replay remains consumed"
        );
    }

    function testDynamicTemplateClearRevealsCollectionAndFreezeKeepsTypedRows() public {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory row = _collaborativeProposal(true);
        _accept();
        _collaboratorAcceptance(row, false);
        _payout();
        _collaboratorPayout(address(0xC011AB));
        core.setTokenCollection(41, 1);
        MutationDynamic.CollaboratorReference[] memory refs =
            new MutationDynamic.CollaboratorReference[](1);
        refs[0] = MutationDynamic.CollaboratorReference(row.account, row.role, row.shareLabelId);
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
            primary.createDynamicPrimaryTemplate(e, keccak256("mutable dynamic source"), refs);
        T.EconomicsConsent memory collectionTerms = _terms(tid, 1, 1, false);
        T.EconomicsConsent memory tokenTerms = _terms(tid, 2, 41, false);
        _approve(collectionTerms, tid);
        _install(tid, 1, 1);
        _approve(tokenTerms, tid);
        _install(tid, 2, 41);
        (T.AssignmentFact memory cleared, bytes32 previous) =
            primary.previewArtistPrimaryClear(1, 2, 41);
        require(
            cleared.assignmentHash == 0 && previous == tokenTerms.assignmentHash,
            "clear signs absence and retains prior canonical source"
        );
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        vm.prank(owner);
        primary.clearPrimaryAssignment(PRIMARY, 2, 41);
        T.EconomicsConsent memory p = T.EconomicsConsent(1, address(primary), PRIMARY, 2, 41, 0);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        ingress.recordProspectiveEconomicsConsent(p, T.FixedEconomicsCandidate(0, 0, 0, false), a);
        vm.prank(owner);
        primary.clearPrimaryAssignment(PRIMARY, 2, 41);
        require(
            !primary.primaryEconomicsFacts(1, 2, 41).exists
                && primary.resolvePrimaryAssignment(1, 41, PRIMARY).assignmentHash
                    == collectionTerms.assignmentHash,
            "cleared exact token key restores real collection precedence"
        );
        T.EconomicsConsent memory frozen = _terms(tid, 1, 1, true);
        _approveFreeze(frozen);
        _freeze(frozen);
        _collaboratorPayout(address(0xC022AB));
        (bytes32 profile, address wallet_,,) =
            primary.materializeDynamicCollectionPrimaryProfile(tid, 1, address(this), false);
        require(
            primary.resolvePrimaryAssignment(1, 41, PRIMARY).assignmentHash == frozen.assignmentHash
                && wallet_ == IStreamSplitFactory(factory).walletFor(profile),
            "freeze pins template terms while typed payout remains current"
        );
        uint256 found;
        for (uint256 i; i < IStreamSplitFactory(factory).profileEntryCount(profile); ++i) {
            (address account, uint32 share, bytes32 label) =
                IStreamSplitFactory(factory).profileEntry(profile, i);
            if (label == row.shareLabelId) {
                require(
                    account == address(0xC022AB) && share == 600000,
                    "retained paid row resolves current payout"
                );
                ++found;
            }
        }
        require(found == 1, "exact paid row");
    }
}
