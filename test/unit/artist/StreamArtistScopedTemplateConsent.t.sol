// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistOnboardingFixture.sol";
import {
    IStreamDynamicPrimaryTemplates as ScopedDynamic
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";
import {
    IStreamArtistScopedPrimaryTemplateFacts
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistScopedPrimaryTemplateFacts.sol";

interface ScopedArtistCalls {
    function expectCall(address target, uint256 value, bytes calldata data, uint64 count) external;
}

/// @notice Actual Artist/Safe/Resolver scope2 TEMPLATE authority; unit Core and owner remain explicit.
contract StreamArtistScopedTemplateConsentTest is ArtistOnboardingFixture {
    ScopedArtistCalls private constant calls =
        ScopedArtistCalls(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _tokenSetup(bool payout) private returns (bytes32 tid) {
        directArtistCalls = true;
        _accept();
        if (payout) _payout();
        core.setTokenCollection(41, 1);
        core.setTokenCollection(42, 1);
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory e =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        e[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 1, keccak256("artist")
        );
        e[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0xFEE), 0, 999999, keccak256("protocol")
        );
        address owner = primary.owner();
        vm.prank(owner);
        tid = primary.createPrimaryTemplate(e, keccak256("scoped one ppm"));
    }

    function _terms(bytes32 tid, uint256 token) private view returns (T.EconomicsConsent memory) {
        T.AssignmentFact memory f =
            primary.previewArtistScopedPrimaryTemplateAssignment(1, 2, token, tid, 0, false);
        return T.EconomicsConsent(1, address(primary), PRIMARY, 2, token, f.assignmentHash);
    }

    function _install(bytes32 tid, uint256 token) private returns (bytes32) {
        address owner = primary.owner();
        vm.prank(owner);
        return primary.setPrimaryTemplateAssignment(PRIMARY, 2, token, tid, 0);
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
        T.AssignmentFact memory fact = primary.previewArtistScopedPrimaryTemplateAssignment(
            p.collectionId, p.scope, p.scopeId, templateId, 0, false
        );
        (bytes32 entries, bytes32 metadata, uint32 share) =
            primary.primaryTemplateConsentFacts(templateId);
        T.SignerApproval memory proof =
            T.SignerApproval(address(artist), ingress.economicsConsentDigest(p, a), true);
        bytes memory evidence = abi.encode(
            keccak256("6529STREAM_PROSPECTIVE_SCOPED_TEMPLATE_EVIDENCE_V1"),
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

    function testScopedTemplateActualSafeOriginalOp15ArchiveAndTokenIsolation() public {
        bytes32 tid = _tokenSetup(true);
        T.EconomicsConsent memory p = _terms(tid, 41);
        T.Authorization memory a = _authorization(false);
        bytes memory data = abi.encodeCall(
            IStreamArtistTemplateEconomicsAuthority.recordProspectiveTemplateEconomicsConsent,
            (p, tid, a)
        );
        address owner = primary.owner();
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        vm.prank(owner);
        primary.setPrimaryTemplateAssignment(PRIMARY, 2, 41, tid, 0);
        require(this.executeArtistSafe(data), "actual Safe scoped template consent");
        bytes32 record = _record(p);
        _assertOriginalArchive(p, tid, a, record);
        require(
            _install(tid, 41) == p.assignmentHash
                && primary.resolvePrimaryAssignment(1, 41, PRIMARY).assignmentHash
                    == p.assignmentHash,
            "exact token TEMPLATE selected"
        );
        T.EconomicsConsent memory other = _terms(tid, 42);
        require(
            other.assignmentHash != p.assignmentHash && _record(other) == 0,
            "no token or collection alias"
        );
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        vm.prank(owner);
        primary.setPrimaryTemplateAssignment(PRIMARY, 2, 42, tid, 0);
        bytes32 beforeRoots = _roots();
        uint256 nonce = artist.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeArtistSafe(data);
        require(
            beforeRoots == _roots() && artist.nonce() == nonce,
            "replay preserves all authority state"
        );
    }

    function testScopedTemplateMissingPayoutKeepsIdenticalSignedSafeRetry() public {
        bytes32 tid = _tokenSetup(false);
        T.EconomicsConsent memory p = _terms(tid, 41);
        T.Authorization memory a = _authorization(false);
        bytes memory data = abi.encodeCall(
            IStreamArtistTemplateEconomicsAuthority.recordProspectiveTemplateEconomicsConsent,
            (p, tid, a)
        );
        uint256 nonce = artist.nonce();
        bytes32 digest =
            artist.getTransactionHash(
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
        calls.expectCall(address(ingress), 0, data, 2);
        bytes32 roots = _roots();
        (bool failed,) = address(artist).call(call_);
        require(
            !failed && artist.nonce() == nonce && _record(p) == 0 && _roots() == roots,
            "missing payout rollback"
        );
        directArtistCalls = false;
        _payout();
        directArtistCalls = true;
        require(
            artist.nonce() == nonce, "relayed designation does not consume Safe transaction nonce"
        );
        (bool ok, bytes memory result) = address(artist).call(call_);
        require(
            ok && abi.decode(result, (bool)) && artist.nonce() == nonce + 1
                && _install(tid, 41) == p.assignmentHash,
            "byte-identical Safe retry"
        );
    }

    function testDefaultProfileCurrentApprovalIsCollectionSpecificOriginalOp15() public {
        _accept();
        _payout();
        bytes32 profile = primary.primaryEconomicsFacts(1, 1, 1).profileId;
        address owner = primary.owner();
        vm.prank(owner);
        primary.setPrimaryProfileAssignment(PRIMARY, 0, 0, profile, 0);
        require(primary.primaryEconomicsFacts(1, 0, 0).exists, "configured default source");
        T.AssignmentFact memory f =
            primary.previewArtistPrimaryAssignmentForScope(1, 0, 0, profile, 0, false);
        T.EconomicsConsent memory p =
            T.EconomicsConsent(1, address(primary), PRIMARY, 0, 0, f.assignmentHash);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
        ingress.recordEconomicsConsent(p, a);
        require(_record(p) != 0, "actual collection-specific default approval");
        T.FixedEconomicsCandidate memory clear_ = T.FixedEconomicsCandidate(0, 0, 0, false);
        (T.AssignmentFact memory cleared,) = primary.previewArtistPrimaryClear(1, 1, 1);
        T.EconomicsConsent memory cp =
            T.EconomicsConsent(1, address(primary), PRIMARY, 1, 1, cleared.assignmentHash);
        a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(cp, a));
        ingress.recordProspectiveEconomicsConsent(cp, clear_, a);
        vm.prank(owner);
        primary.clearPrimaryAssignment(PRIMARY, 1, 1);
        require(
            primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash == f.assignmentHash,
            "default use retains raw scope0 hash"
        );
    }

    function testScopedDynamicActualArtistConsentUsesOriginalRowsAndRotatedTypedPayout() public {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory row = _collaborativeProposal(true);
        _accept();
        _collaboratorAcceptance(row, false);
        _payout();
        _collaboratorPayout(address(0xC011AB));
        core.setTokenCollection(41, 1);
        ScopedDynamic.CollaboratorReference[] memory refs =
            new ScopedDynamic.CollaboratorReference[](1);
        refs[0] = ScopedDynamic.CollaboratorReference(row.account, row.role, row.shareLabelId);
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
            primary.createDynamicPrimaryTemplate(e, keccak256("actual token dynamic"), refs);
        T.EconomicsConsent memory p = _terms(tid, 41);
        T.Authorization memory a = _authorization(false);
        bytes memory data = abi.encodeCall(
            IStreamArtistTemplateEconomicsAuthority.recordProspectiveTemplateEconomicsConsent,
            (p, tid, a)
        );
        require(this.executeArtistSafe(data), "actual threshold Safe op15 dynamic token terms");
        bytes32 record = _record(p);
        require(record != 0 && _install(tid, 41) == p.assignmentHash, "exact token installation");
        (bytes32 first,, bytes32 entries, bytes32 witness) =
            primary.previewDynamicCollectionPrimaryProfile(tid, 1, address(this));
        _collaboratorPayout(address(0xC022AB));
        (bytes32 next, address wallet_, bytes32 changedEntries, bytes32 changedWitness) =
            primary.materializeDynamicCollectionPrimaryProfile(tid, 1, address(this), false);
        require(
            first != next && entries != changedEntries && witness != changedWitness
                && _record(p) == record
                && primary.resolvePrimaryAssignment(1, 41, PRIMARY).assignmentHash
                    == p.assignmentHash,
            "payout rotation preserves signed original scope2 source"
        );
        require(
            wallet_ == IStreamSplitFactory(factory).walletFor(next),
            "actual deterministic materialization"
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
        require(found == 1, "exact accepted row retained");
    }
}
