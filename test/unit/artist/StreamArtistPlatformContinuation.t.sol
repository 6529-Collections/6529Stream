// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistPlatformWorks.t.sol";
import {
    StreamArtistBindingCorrectionAdmission as CorrectionAdmission
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionAdmission.sol";
import {
    StreamArtistBindingCorrectionTypes as BC,
    IStreamArtistBindingCorrection,
    IStreamArtistBindingCorrectionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL,
    IStreamArtistPlatformCorrectionLineage as Lineage
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    IStreamStaticArtistSource
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamStaticArtistSource.sol";
import {
    StreamArtistRepudiationTypes as RP,
    IStreamArtistAttributionRepudiation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";

interface PlatformContinuationVm {
    function expectCall(address, bytes calldata, uint64) external;
}

/// @notice Actual original op53, seven owners, Coordinator/Archive and threshold Safe writes.
/// @dev Core, selected metadata reads, and governance action admission remain the original typed
/// fixture boundaries. Original platform cohort is inherited; no current-stack/native claim.
contract StreamArtistPlatformContinuationTest is StreamArtistPlatformWorksTest {
    PlatformContinuationVm private constant cvm =
        PlatformContinuationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _lineage() private view returns (Lineage) {
        return Lineage(suite.owners[4]);
    }

    function _binding2() private view returns (T.Binding memory) {
        return IStreamArtistBindingOwner(suite.owners[0]).binding(2);
    }

    function _first() private returns (PW.State memory) {
        bytes32 claim_ = _pwClaim();
        _pwResolve(1, claim_, false, 1);
        _pwResolve(3, claim_, false, 1);
        _pwResolve(3, claim_, true, 2);
        ingress.proposeArtistBinding(
            2, _proposal(artistId), bytes("unit identity document"), "Artist Safe"
        );
        return ingress.platformWorksState(2);
    }

    function _refuse2() private returns (bytes32) {
        L.Termination memory p = _termination(2);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.bindingRefusalDigest(p, a));
        return ingress.refuseArtistBinding(p, a);
    }

    function _accept2() private returns (bytes32) {
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.acceptanceDigest(2, a));
        return ingress.acceptArtistBinding(2, a);
    }

    function _revoke2() private returns (bytes32 record) {
        T.Binding memory b = _binding2();
        AD.Filing memory p =
            AD.Filing(2, b.generation, 4, 0, keccak256("platform author repudiation"));
        T.Authorization memory a = _authorization(false);
        a.signature = "";
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistAttributionRepudiation.revokeAttribution, (p, a)),
                0
            ),
            "original47 actual Safe"
        );
        (, uint64 executable, bytes32 hash) = ingress.pendingRepudiation(2);
        vm.warp(executable);
        ingress.executeAttributionRepudiation(2, hash);
        require(ingress.attributionRepudiationTerminal(hash).phase == 4, "executed original50");
        return hash;
    }

    function _terms2() private view returns (T.BindingProposal memory p) {
        p = _proposal(artistId);
        p.reasonHash = keccak256("fresh platform continuation authority");
    }

    function _context2(T.BindingProposal memory p, bytes32 witness)
        private
        view
        returns (BC.Context memory c)
    {
        (c,) = CorrectionAdmission.context(
            suite, 2, p, bytes("unit identity document"), "Artist Safe", witness
        );
    }

    function _govern2(T.BindingProposal memory p, bytes32 witness, uint8 cls)
        private
        returns (bytes32 action)
    {
        BC.Context memory c = _context2(p, witness);
        action = keccak256(abi.encode("fresh class2 Platform continuation", c));
        _execute2(p, witness, cls, c, action);
    }

    function _execute2(
        T.BindingProposal memory p,
        bytes32 witness,
        uint8 cls,
        BC.Context memory c,
        bytes32 action
    ) private {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        ArtistUnitRoles(suite.roleRegistry).setAdmin(address(authority), true);
        authority.configureContestReads(
            suite.roleRegistry, address(artist), p.reasonHash, "urn:platform:continuation"
        );
        avm.mockCall(
            address(authority),
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, action, cls, c.scopeHash, c.oldValueHash, c.newValueHash)
        );
        bytes memory data = abi.encodeCall(
            IStreamArtistBindingCorrection.proposeArtistBindingAfterRevocation,
            (uint256(2), p, bytes("unit identity document"), "Artist Safe", witness)
        );
        require(
            executeSafe(
                artist,
                keys,
                address(authority),
                0,
                abi.encodeCall(
                    authority.executeModuleContext,
                    (address(ingress), data, cls, c.scopeHash, c.oldValueHash, c.newValueHash)
                ),
                0
            ),
            "actual Safe / canonical unit Executor / original op1"
        );
        avm.mockCall(
            address(authority),
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0))
        );
    }

    function continuationExecute(
        T.BindingProposal calldata p,
        bytes32 witness,
        uint8 cls,
        BC.Context calldata c,
        bytes32 action
    ) external {
        require(msg.sender == address(this));
        _execute2(p, witness, cls, c, action);
    }

    function continuationGovern(T.BindingProposal calldata p, bytes32 witness, uint8 cls) external {
        require(msg.sender == address(this));
        _govern2(p, witness, cls);
    }

    function continuationContext(T.BindingProposal calldata p, bytes32 witness)
        external
        view
        returns (BC.Context memory)
    {
        return _context2(p, witness);
    }

    function continuationSafeAccept(T.Authorization calldata a) external {
        require(msg.sender == address(this));
        T.Binding memory b = _binding2();
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(
                    IStreamArtistBindingLifecycle.acceptArtistBindingExpected,
                    (uint256(2), b.generation, b.bindingHash, a)
                ),
                0
            ),
            "actual Safe acceptance with original generation pin"
        );
    }

    function _assertHistorical(PW.State memory original) private view {
        require(
            keccak256(abi.encode(ingress.platformWorksState(2))) == keccak256(abi.encode(original)),
            "all original20 words/op53 approval/consumed generation remain exact"
        );
        bytes memory raw = IStreamStaticArtistSource(address(ingress))
            .staticDisplayRead(
                abi.encodeCall(IStreamArtistPlatformWorks.platformWorksState, (uint256(2)))
            );
        require(
            raw.length == 640 && keccak256(raw) == keccak256(abi.encode(original)),
            "original STATIC20 exact"
        );
    }

    function _assertLineage(bytes32 action, uint64 expectedCount)
        private
        view
        returns (PL.Record memory r)
    {
        PL.Status memory h = _lineage().platformCorrectionStatus(2);
        r = _lineage().platformCorrectionLineage(h.latestLineageRecord);
        T.Binding memory b = _binding2();
        (BC.Approval memory a, bytes32 approval) =
            IStreamArtistBindingCorrectionOwner(suite.owners[0]).bindingCorrection(b.bindingHash);
        require(
            h.count == expectedCount && h.generation == b.generation && r.collectionId == 2
                && r.bindingHash == b.bindingHash && r.governanceActionId == action
                && r.approvalHash == approval,
            "exact latest identity and immutable correction approval"
        );
        (bytes32 tag, PL.Witness memory w) = abi.decode(a.causeData, (bytes32, PL.Witness));
        require(
            tag == keccak256("6529STREAM_PLATFORM_BINDING_CONTINUATION_WITNESS_V1")
                && w.prior.count + 1 == h.count
                && w.platform.correction.recordHash == h.originalCorrectionRecord,
            "canonical explicit whole prior lineage witness"
        );
        bytes32 hash = r.recordHash;
        r.recordHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PLATFORM_BINDING_CONTINUATION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        address(manager),
                        suite.owners[4],
                        r
                    )
                ),
            "independent original environment/full row hash"
        );
        r.recordHash = hash;
        bytes32 archiveId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(1),
                manager.governanceAuthority(),
                b.bindingHash
            )
        );
        (
            uint16 version,
            bytes32 configuration,
            uint16 operation,
            address actor,
            bytes32 saved,
            T.Snapshot[7] memory before_,
            T.Snapshot[7] memory after_,
            bytes memory detail
        ) = abi.decode(
            archive.artistEvidenceBytesV2(archiveId, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            version == 1 && configuration == coordinator.configurationHash() && operation == 1
                && actor == manager.governanceAuthority() && saved == b.bindingHash,
            "original operation/domain/header"
        );
        require(
            after_[0].revision == before_[0].revision + 1
                && after_[4].revision == before_[4].revision + 1,
            "original two changed owner revisions"
        );
        (bytes32 roleHash, uint64 roleRevision) = IStreamRoleRegistry(suite.roleRegistry)
            .roleMutationState(keccak256("ROLE_ARTIST_REGISTRY_ADMIN"));
        T.BindingProposal memory proposal = _terms2();
        BC.Context memory c = BC.Context(
            a.governance.scopeHash, a.governance.oldValueHash, a.governance.newValueHash
        );
        bytes memory expected = abi.encode(
            keccak256("6529STREAM_ARTIST_BINDING_CORRECTION_EVIDENCE_V1"),
            uint16(1),
            uint256(2),
            proposal,
            bytes("unit identity document"),
            "Artist Safe",
            true,
            roleHash,
            roleRevision,
            a.cause == 3 ? a.causeRecord : bytes32(0),
            c,
            a
        );
        require(
            keccak256(detail) == keccak256(expected),
            "full original op1 tagged Archive payload retains exact Platform witness"
        );
        bytes memory raw = IStreamStaticArtistSource(address(ingress))
            .staticDisplayRead(abi.encodeCall(Lineage.platformCorrectionStatus, (uint256(2))));
        require(
            raw.length == 192 && keccak256(raw) == keccak256(abi.encode(h)),
            "direct STATIC supplemental6 words"
        );
    }

    function _assertAccepted(PL.Record memory r, bytes32 originalAcceptance) private view {
        PL.Acceptance memory a = _lineage().platformCorrectionAcceptance(r.recordHash);
        PL.Status memory h = _lineage().platformCorrectionStatus(2);
        bytes32 hash = a.recordHash;
        a.recordHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PLATFORM_BINDING_CONTINUATION_ACCEPTANCE_V1"),
                        block.chainid,
                        suite.owners[4],
                        uint256(2),
                        r.generation,
                        a
                    )
                ),
            "independent original op2 derivative receipt"
        );
        require(
            a.acceptanceRecord == originalAcceptance && a.lineageRecord == r.recordHash
                && h.latestAcceptanceRecord == hash && h.effectiveAccepted,
            "exact op2 not governance acceptance"
        );
        require(
            IStreamArtistPlatformOwner(suite.owners[4]).platformWorksAdmission(2).corrected
                && ingress.consentMode(2) == 1 && ingress.acceptedArtist(2) == address(artist),
            "effective current admission"
        );
        require(
            ingress.finalityState(2).componentType == keccak256("ARTIST_SANCTION"),
            "current sanction source after accepted continuation"
        );
    }

    function _events(Vm.Log[] memory logs, PL.Record memory r) private view {
        uint256 found;
        bytes32 sig = keccak256(
            "PlatformCorrectionContinued(uint16,uint256,uint64,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == suite.owners[4] && logs[i].topics[0] == sig) {
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(2))
                        && logs[i].topics[2] == bytes32(uint256(r.generation))
                        && logs[i].topics[3] == r.recordHash,
                    "exact indexed lineage event"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                r.originalCorrectionRecord,
                                r.previousLineageRecord,
                                r.bindingHash,
                                r.approvalHash,
                                r.governanceActionId
                            )
                        ),
                    "exact event tuple"
                );
                ++found;
            }
        }
        require(found == 1, "one append event");
    }

    function _acceptanceEvent(Vm.Log[] memory logs, PL.Record memory r, bytes32 accepted)
        private
        view
    {
        PL.Acceptance memory a = _lineage().platformCorrectionAcceptance(r.recordHash);
        bytes32 signature = keccak256(
            "PlatformCorrectionAccepted(uint16,uint256,uint64,bytes32,bytes32,bytes32,uint64)"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != suite.owners[4] || logs[i].topics[0] != signature) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(2))
                    && logs[i].topics[2] == bytes32(uint256(r.generation))
                    && logs[i].topics[3] == r.recordHash,
                "exact indexed independent acceptance"
            );
            require(
                keccak256(logs[i].data)
                    == keccak256(abi.encode(uint16(1), accepted, a.recordHash, a.acceptedAt)),
                "exact derivative acceptance event"
            );
            ++found;
        }
        require(found == 1, "one original-op2 derivative event");
    }

    function testRefusedOriginalCorrectionFreshApprovalThenSafeAcceptance() public {
        PW.State memory original = _first();
        bytes32 refusal = _refuse2();
        vm.recordLogs();
        bytes32 action = _govern2(_terms2(), 0, 2);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        PL.Record memory r = _assertLineage(action, 1);
        _events(logs, r);
        require(
            !_lineage().platformCorrectionStatus(2).effectiveAccepted
                && ingress.consentMode(2) == 3,
            "proposal remains unaccepted"
        );
        (BC.Approval memory a,) =
            IStreamArtistBindingCorrectionOwner(suite.owners[0]).bindingCorrection(r.bindingHash);
        (, PL.Witness memory w) = abi.decode(a.causeData, (bytes32, PL.Witness));
        (L.Terminal memory terminal,) = abi.decode(w.originalCauseData, (L.Terminal, AD.Head));
        require(
            a.cause == 1 && terminal.recordHash == refusal, "original exact refusal inside wrapper"
        );
        vm.recordLogs();
        bytes32 accepted = _accept2();
        _acceptanceEvent(vm.getRecordedLogs(), r, accepted);
        _assertAccepted(r, accepted);
        _assertHistorical(original);
    }

    function testWithdrawnOriginalCorrectionLaterAcceptanceDoesNotRewriteOriginalFlag() public {
        PW.State memory original = _first();
        ingress.withdrawArtistBinding(_termination(2));
        bytes32 action = _govern2(_terms2(), 0, 2);
        PL.Record memory r = _assertLineage(action, 1);
        _assertAccepted(r, _accept2());
        _assertHistorical(original);
        require(
            !original.correction.accepted && ingress.platformWorksState(2).contestState == 3,
            "historical unaccepted and permanent contest"
        );
    }

    function testPreviouslyAcceptedOriginalAndExecutedRepudiationRemainHistorical() public {
        _first();
        _accept2();
        PW.State memory original = ingress.platformWorksState(2);
        bytes32 witness = _revoke2();
        bytes32 action = _govern2(_terms2(), witness, 2);
        PL.Record memory r = _assertLineage(action, 1);
        require(
            _lineage().platformCorrectionStatus(2).effectiveAccepted,
            "already accepted lineage never reverts to platform"
        );
        _assertAccepted(r, _accept2());
        _assertHistorical(original);
        require(ingress.attributionRepudiationTerminal(witness).phase == 4, "immutable prior cause");
    }

    function testRefusedContinuationAppendsThirdGenerationWithoutReusingOriginalApproval() public {
        PW.State memory original = _first();
        _refuse2();
        bytes32 first = _govern2(_terms2(), 0, 2);
        PL.Record memory previous = _assertLineage(first, 1);
        _refuse2();
        bytes32 second = _govern2(_terms2(), 0, 2);
        PL.Record memory r = _assertLineage(second, 2);
        require(
            first != second && r.previousLineageRecord == previous.recordHash
                && r.previousBindingHash == previous.bindingHash,
            "fresh action and exact previous generation"
        );
        require(
            keccak256(abi.encode(_lineage().platformCorrectionLineage(previous.recordHash)))
                == keccak256(abi.encode(previous)),
            "immutable prior line"
        );
        _assertAccepted(r, _accept2());
        _assertHistorical(original);
    }

    function testAcceptedContinuationRemainsEffectiveAcrossLaterRevocationAndPendingGeneration()
        public
    {
        PW.State memory original = _first();
        _refuse2();
        bytes32 action = _govern2(_terms2(), 0, 2);
        PL.Record memory previous = _assertLineage(action, 1);
        bytes32 accepted = _accept2();
        _assertAccepted(previous, accepted);
        PL.Acceptance memory receipt = _lineage().platformCorrectionAcceptance(previous.recordHash);
        bytes32 witness = _revoke2();
        action = _govern2(_terms2(), witness, 2);
        PL.Record memory current = _assertLineage(action, 2);
        PL.Status memory status = _lineage().platformCorrectionStatus(2);
        require(
            status.effectiveAccepted && status.latestAcceptanceRecord == receipt.recordHash
                && _lineage().platformCorrectionAcceptance(current.recordHash).recordHash == 0,
            "lineage classification survives; pending generation is not accepted"
        );
        require(
            !_binding2().accepted && ingress.acceptedArtist(2) == address(0),
            "no current Artist acceptance manufactured"
        );
        require(
            keccak256(abi.encode(_lineage().platformCorrectionAcceptance(previous.recordHash)))
                == keccak256(abi.encode(receipt)),
            "prior op2 derivative immutable"
        );
        _assertHistorical(original);
    }

    function testOriginalExecutedDeclarationComponentSurvivesAcceptedContinuation() public {
        PW.State memory original = _first();
        _refuse2();
        _govern2(_terms2(), 0, 2);
        _accept2();
        address f = ingress.finalityRegistry();
        StreamCollectionFinalityRecord memory saved;
        saved.finalized = true;
        saved.finalityRecordHash = keccak256("prior immutable Platform finality");
        StreamFinalityComponentExpectation[] memory rows =
            new StreamFinalityComponentExpectation[](1);
        rows[0].component = address(ingress);
        rows[0].componentType = keccak256("PLATFORM_WORKS_DECLARATION");
        rows[0].dataHash = original.declaration.recordHash;
        avm.mockCall(
            f,
            abi.encodeCall(IStreamArtworkFinalityRegistry.collectionFinalityRecord, (uint256(2))),
            abi.encode(saved)
        );
        avm.mockCall(
            f,
            abi.encodeCall(IStreamArtworkFinalityRegistry.finalityComponentCount, (uint256(2))),
            abi.encode(uint256(1))
        );
        avm.mockCall(
            f,
            abi.encodeCall(
                IStreamArtworkFinalityRegistry.finalityComponents,
                (uint256(2), uint256(0), uint256(1))
            ),
            abi.encode(rows)
        );
        StreamFinalityComponentState memory component = ingress.finalityState(2);
        require(
            component.frozen && component.componentType == keccak256("PLATFORM_WORKS_DECLARATION")
                && component.dataHash == original.declaration.recordHash,
            "executed declaration never replaced by Artist sanction"
        );
        _assertHistorical(original);
    }

    function testClassOneAndForeignOwnerCannotContinue() public {
        _first();
        _refuse2();
        bytes32 roots = _roots();
        vm.expectRevert();
        this.continuationGovern(_terms2(), 0, 1);
        T.ActionContext memory c = T.ActionContext(
            1, address(this), IStreamArtistOwner(suite.owners[4]).ownerStateSnapshotV2()
        );
        BC.Approval memory a;
        T.Binding memory b = _binding2();
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        _lineage().claimPlatformContinuation(c, 2, b, bytes32(uint256(1)), "", a);
        require(
            _roots() == roots && _lineage().platformCorrectionStatus(2).count == 0,
            "no authority promotion or mutation"
        );
    }

    function testUnrelatedClaimDoesNotChangeContinuationGovernanceContext() public {
        _first();
        _refuse2();
        T.BindingProposal memory p = _terms2();
        BC.Context memory before_ = _context2(p, 0);
        (bytes32 e,) = _pwEvidence(address(0), 0, keccak256("unrelated after original consumed"));
        vm.prank(address(0xCAFE));
        ingress.filePlatformWorksClaim(2, e, e, "urn:unrelated");
        require(
            keccak256(abi.encode(before_)) == keccak256(abi.encode(_context2(p, 0))),
            "permissionless append cannot grief exact approval"
        );
        _execute2(p, 0, 2, before_, keccak256("pre-staged continuation"));
        require(
            _lineage().platformCorrectionStatus(2).count == 1, "original scheduled context succeeds"
        );
    }

    function testStaleGenerationAndSubstitutedProposalCannotReuseGovernance() public {
        _first();
        _refuse2();
        T.BindingProposal memory p = _terms2();
        BC.Context memory c = _context2(p, 0);
        bytes32 roots = _roots();
        T.BindingProposal memory changed = _terms2();
        changed.saleConsentScope = 0;
        vm.expectRevert();
        this.continuationExecute(changed, 0, 2, c, keccak256("stale proposal"));
        require(_roots() == roots, "proposal substitution atomic refusal");
        bytes32 action = keccak256("exact action");
        _execute2(p, 0, 2, c, action);
        _refuse2();
        roots = _roots();
        vm.expectRevert();
        this.continuationExecute(p, 0, 2, c, action);
        require(
            _roots() == roots && _lineage().platformCorrectionStatus(2).count == 1,
            "old generation/action cannot append again"
        );
    }

    function testForeignSupplementalHeadCannotPassActualOwnerEquality() public {
        _first();
        _refuse2();
        PL.Status memory fake = _lineage().platformCorrectionStatus(2);
        fake.latestLineageRecord = keccak256("foreign head");
        fake.count = 1;
        fake.generation = 2;
        avm.mockCall(
            suite.owners[4],
            abi.encodeCall(Lineage.platformCorrectionStatus, (uint256(2))),
            abi.encode(fake)
        );
        bytes32 roots = _roots();
        vm.expectRevert();
        this.continuationGovern(_terms2(), 0, 2);
        require(
            _roots() == roots, "actual stored original namespace refuses caller-observed false head"
        );
        avm.clearMockedCalls();
        _pwMetadata();
        require(_lineage().platformCorrectionStatus(2).count == 0, "no hidden lineage mutation");
    }

    function testLateArchiveContinuationRollbackAndIdenticalSafeActionRetry() public {
        PW.State memory original = _first();
        _refuse2();
        T.BindingProposal memory p = _terms2();
        BC.Context memory c = _context2(p, 0);
        bytes32 action = keccak256("identical failed and retried Platform action");
        bytes32 roots = _roots();
        uint256 nonce = artist.nonce();
        bytes memory append =
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector);
        cvm.expectCall(address(archive), append, uint64(2));
        avm.mockCallRevert(
            address(archive), append, abi.encodeWithSelector(PlatformTestFailure.selector)
        );
        vm.expectRevert();
        this.continuationExecute(p, 0, 2, c, action);
        require(
            _roots() == roots && artist.nonce() == nonce && _binding2().generation == 1
                && _lineage().platformCorrectionStatus(2).count == 0,
            "all roots/lineage/approval/replay/Safe rolled back"
        );
        avm.clearMockedCalls();
        _pwMetadata();
        _execute2(p, 0, 2, c, action);
        require(artist.nonce() == nonce + 1, "same Safe nonce retry");
        _assertLineage(action, 1);
        _assertHistorical(original);
    }

    function testLateArchiveAcceptanceRollbackAndSameSafeCalldataRetry() public {
        PW.State memory original = _first();
        _refuse2();
        bytes32 action = _govern2(_terms2(), 0, 2);
        PL.Record memory r = _assertLineage(action, 1);
        T.Authorization memory a = _authorization(false);
        a.signature = "";
        bytes32 roots = _roots();
        uint256 nonce = artist.nonce();
        bytes memory append =
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector);
        cvm.expectCall(address(archive), append, uint64(2));
        avm.mockCallRevert(
            address(archive), append, abi.encodeWithSelector(PlatformTestFailure.selector)
        );
        vm.expectRevert();
        this.continuationSafeAccept(a);
        require(
            _roots() == roots && artist.nonce() == nonce && !_binding2().accepted
                && !_lineage().platformCorrectionStatus(2).effectiveAccepted
                && _lineage().platformCorrectionAcceptance(r.recordHash).recordHash == 0,
            "original op2 and derivative receipt roll back together"
        );
        avm.clearMockedCalls();
        _pwMetadata();
        this.continuationSafeAccept(a);
        bytes32 accepted =
            IStreamArtistAcceptanceOwner(suite.owners[3]).acceptanceRecord(r.bindingHash);
        _assertAccepted(r, accepted);
        _assertHistorical(original);
        require(artist.nonce() == nonce + 1, "same original op2 Safe retry");
    }
}
