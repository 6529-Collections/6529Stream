// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistAttributionDisputeFixture.sol";
import {
    StreamArtistBindingCorrectionAdmission as Admission
} from "../../../smart-contracts/domains/artist/StreamArtistBindingCorrectionAdmission.sol";
import {
    StreamArtistBindingCorrectionTypes as BC,
    IStreamArtistBindingCorrection,
    IStreamArtistBindingCorrectionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingCorrection.sol";

/// @notice Actual seven Artist owners, Coordinator, Archive and threshold Safe; typed Core/Executor/roles boundary.
/// @dev The separate current suite exercises real sealed/delayed governance and its new selector catalog.
contract StreamArtistBindingCorrectionTest is ArtistAttributionDisputeFixture {
    function _data(T.BindingProposal memory p, bytes32 repudiation)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            IStreamArtistBindingCorrection.proposeArtistBindingAfterRevocation,
            (uint256(1), p, bytes("unit identity document"), "Artist Safe", repudiation)
        );
    }

    function _terms() private view returns (T.BindingProposal memory p) {
        p = _proposal(artistId);
        p.reasonHash = keccak256("exact governed correction");
    }

    function _context(T.BindingProposal memory p, bytes32 repudiation)
        private
        view
        returns (BC.Context memory c)
    {
        (c,) = Admission.context(
            suite, 1, p, bytes("unit identity document"), "Artist Safe", repudiation
        );
    }

    function _approve(T.BindingProposal memory p, bytes32 repudiation, uint8 cls)
        private
        returns (bytes32)
    {
        BC.Context memory c = _context(p, repudiation);
        ArtistUnitRoles(suite.roleRegistry).setAdmin(manager.governanceAuthority(), true);
        return _govern(
            _data(p, repudiation),
            AD.Context(c.scopeHash, c.oldValueHash, c.newValueHash, 2, 0),
            p.reasonHash,
            cls
        );
    }

    function correctionApprove(T.BindingProposal calldata p, bytes32 witness, uint8 cls)
        external
        returns (bytes32)
    {
        require(msg.sender == address(this));
        return _approve(p, witness, cls);
    }

    function correctionContext(T.BindingProposal calldata p, bytes32 witness)
        external
        view
        returns (BC.Context memory)
    {
        return _context(p, witness);
    }

    function testPendingWithdrawalRequiresExplicitArbiterAndPreservesOriginalHistory() public {
        T.Binding memory prior = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        ingress.withdrawArtistBinding(_termination(1));
        T.BindingProposal memory p = _terms();
        bytes32 roots = _roots();
        vm.expectRevert();
        this.disputeRelay(
            abi.encodeCall(
                IStreamArtistOnboarding.proposeArtistBinding,
                (uint256(1), p, bytes("unit identity document"), "Artist Safe")
            )
        );
        vm.expectRevert();
        this.disputeRelay(_data(p, 0));
        require(_roots() == roots, "both ungoverned paths unchanged");
        vm.recordLogs();
        bytes32 action = _approve(p, 0, 2);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        require(
            b.generation == 2 && !b.accepted && b.proposer == manager.governanceAuthority(),
            "governance only proposes"
        );
        require(
            keccak256(abi.encode(IStreamArtistBindingOwner(suite.owners[0]).bindingAt(1, 1)))
                == keccak256(abi.encode(prior)),
            "historical proposal exact"
        );
        (BC.Approval memory a, bytes32 hash) =
            IStreamArtistBindingCorrectionOwner(suite.owners[0]).bindingCorrection(b.bindingHash);
        require(
            a.cause == 2 && a.causeRecord == prior.bindingHash && a.governance.actionId == action,
            "exact immutable terminal and action"
        );
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_BINDING_CORRECTION_RECORD_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        address(manager),
                        uint256(1),
                        b.bindingHash,
                        a
                    )
                ),
            "independent full approval preimage"
        );
        _assertCorrectionEvent(logs, b.bindingHash, hash, a);
        _assertCorrectionArchive(p, b.bindingHash, a);
        _state(1);
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        require(
            this.executeArtistSafe(
                abi.encodeCall(
                    IStreamArtistBindingLifecycle.acceptArtistBindingExpected,
                    (uint256(1), uint64(2), b.bindingHash, T.Authorization(nonce, 0, ""))
                )
            ),
            "original direct Safe acceptance"
        );
        _state(2);
        _deArchive(1, manager.governanceAuthority(), b.bindingHash);
    }

    function _assertCorrectionEvent(
        Vm.Log[] memory logs,
        bytes32 bindingHash,
        bytes32 record,
        BC.Approval memory a
    ) private view {
        bytes32 topic = keccak256(
            "ArtistBindingCorrectionApproved(uint16,uint256,bytes32,bytes32,uint64,bytes32,uint8,bytes32,bytes32)"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != suite.owners[0] || logs[i].topics.length != 4
                    || logs[i].topics[0] != topic
            ) continue;
            require(
                logs[i].topics[1] == bytes32(uint256(1)) && logs[i].topics[2] == bindingHash
                    && logs[i].topics[3] == record,
                "exact correction event indexes"
            );
            require(
                keccak256(logs[i].data)
                    == keccak256(
                        abi.encode(
                            uint16(1),
                            a.previous.generation,
                            a.previous.bindingHash,
                            a.cause,
                            a.causeRecord,
                            a.governance.actionId
                        )
                    ),
                "exact original/new/cause event words"
            );
            ++found;
        }
        require(found == 1, "one correction approval event");
    }

    function _assertCorrectionArchive(
        T.BindingProposal memory p,
        bytes32 bindingHash,
        BC.Approval memory a
    ) private view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(1),
                manager.governanceAuthority(),
                bindingHash
            )
        );
        (,,,,,,, bytes memory detail) = abi.decode(
            archive.artistEvidenceBytesV2(id, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_BINDING_CORRECTION_SCOPE_V1"),
                block.chainid,
                address(ingress),
                address(core),
                address(manager),
                uint256(1),
                a.previous.generation
            )
        );
        bytes32 oldHash =
            keccak256(abi.encode(a.previous, uint8(5), a.cause, a.causeRecord, a.causeData));
        BC.Context memory context = BC.Context(
            scope,
            oldHash,
            keccak256(
                abi.encode(scope, oldHash, a.proposalHash, a.proposedArtistId, a.registrationNonce)
            )
        );
        (bytes32 roleHash, uint64 revision) = IStreamRoleRegistry(suite.roleRegistry)
            .roleMutationState(keccak256("ROLE_ARTIST_REGISTRY_ADMIN"));
        bytes memory expected = abi.encode(
            keccak256("6529STREAM_ARTIST_BINDING_CORRECTION_EVIDENCE_V1"),
            uint16(1),
            uint256(1),
            p,
            bytes("unit identity document"),
            "Artist Safe",
            true,
            roleHash,
            revision,
            bytes32(0),
            context,
            a
        );
        require(
            keccak256(detail) == keccak256(expected),
            "literal full tagged correction Archive detail"
        );
    }

    function testPendingRefusalRetainsOriginalRecordAndZeroWitnessRule() public {
        L.Termination memory t = _termination(1);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.bindingRefusalDigest(t, a));
        bytes32 refused = ingress.refuseArtistBinding(t, a);
        T.BindingProposal memory p = _terms();
        vm.expectRevert();
        this.correctionContext(p, keccak256("foreign repudiation"));
        _approve(p, 0, 2);
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        (BC.Approval memory saved,) =
            IStreamArtistBindingCorrectionOwner(suite.owners[0]).bindingCorrection(b.bindingHash);
        require(
            saved.cause == 1 && saved.causeRecord == refused
                && ingress.bindingTermination(1, 1).recordHash == refused,
            "original refusal remains"
        );
    }

    function testLiveAcceptedAndPendingBindingsCannotBeCorrected() public {
        T.BindingProposal memory p = _terms();
        vm.expectRevert();
        this.correctionContext(p, 0);
        _accept();
        bytes32 roots = _roots();
        vm.expectRevert();
        this.correctionApprove(p, 0, 2);
        require(_roots() == roots, "no mutation without actual revocation");
    }

    function testClass1AndForeignScopeRefuseBeforeProposal() public {
        ingress.withdrawArtistBinding(_termination(1));
        T.BindingProposal memory p = _terms();
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(BC.InvalidBindingCorrection.selector, uint256(1)));
        this.correctionApprove(p, 0, 1);
        ArtistUnitRoles(suite.roleRegistry).setAdmin(manager.governanceAuthority(), true);
        BC.Context memory c = _context(p, 0);
        c.scopeHash = keccak256("foreign scope");
        vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
        this.disputeGoverned(
            _data(p, 0),
            AD.Context(c.scopeHash, c.oldValueHash, c.newValueHash, 2, 0),
            p.reasonHash,
            2
        );
        require(_roots() == roots, "authority failures leave all owners unchanged");
    }

    function testStagedProposalCannotSubstituteModeOrDocument() public {
        ingress.withdrawArtistBinding(_termination(1));
        T.BindingProposal memory p = _terms();
        BC.Context memory c = _context(p, 0);
        ArtistUnitRoles(suite.roleRegistry).setAdmin(manager.governanceAuthority(), true);
        p.consentMode = 2;
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
        this.disputeGoverned(
            _data(p, 0),
            AD.Context(c.scopeHash, c.oldValueHash, c.newValueHash, 2, 0),
            p.reasonHash,
            2
        );
        require(_roots() == roots, "full proposal commitment");
    }

    function testNewIdentityAllocationChangesCapturedGovernanceCommitment() public {
        ingress.withdrawArtistBinding(_termination(1));
        T.BindingProposal memory p = _terms();
        p.artistId = 0;
        BC.Context memory first = _context(p, 0);
        ingress.proposeArtistBinding(
            2, _proposal(0), bytes("unit identity document"), "Artist Safe"
        );
        BC.Context memory next = _context(p, 0);
        require(
            first.oldValueHash == next.oldValueHash && first.newValueHash != next.newValueHash,
            "original global allocator independently bound"
        );
        ArtistUnitRoles(suite.roleRegistry).setAdmin(manager.governanceAuthority(), true);
        vm.expectRevert();
        this.disputeGoverned(
            _data(p, 0),
            AD.Context(first.scopeHash, first.oldValueHash, first.newValueHash, 2, 0),
            p.reasonHash,
            2
        );
    }

    function testUnknownCorrectionReadIsEmptyAndOwnerEntryRejectsForeignCaller() public {
        (BC.Approval memory a, bytes32 hash) = IStreamArtistBindingCorrectionOwner(suite.owners[0])
            .bindingCorrection(keccak256("unknown"));
        require(a.cause == 0 && hash == 0, "no inferred approval");
        T.ActionContext memory c = T.ActionContext(
            1, address(this), IStreamArtistOwner(suite.owners[0]).ownerStateSnapshotV2()
        );
        T.BindingProposal memory p = _terms();
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        IStreamArtistBindingCorrectionOwner(suite.owners[0])
            .proposeAfterRevocation(c, 1, artistId, p, a);
    }

    function testActualArbiterRevocationCauseAndFreshCorrectionRetainClosedOriginalResolution()
        public
    {
        _accept();
        T.Binding memory previous = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        (bytes32 evidence,) = _correctionEvidence(0, keccak256("correction opening"));
        AD.Filing memory opening = AD.Filing(1, previous.generation, 1, evidence, evidence);
        bytes32 record = ingress.openAttributionDispute(opening, _standing(), _signed(opening));
        (evidence,) = _correctionEvidence(record, keccak256("correction revoke evidence"));
        AD.ResolutionRequest memory resolution =
            AD.ResolutionRequest(1, previous.generation, record, 2, evidence, evidence, 0);
        bytes32 action = _resolve(resolution, 2);
        T.BindingProposal memory p = _terms();
        vm.expectRevert();
        this.correctionContext(p, keccak256("unrelated repudiation"));
        _approve(p, 0, 2);
        T.Binding memory next = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        (BC.Approval memory a,) =
            IStreamArtistBindingCorrectionOwner(suite.owners[0]).bindingCorrection(next.bindingHash);
        require(
            a.cause == 4 && a.causeRecord == action && a.previous.accepted,
            "original revoked accepted generation"
        );
        (
            L.Terminal memory terminal,
            AD.Head memory head,
            AD.Record memory savedOpening,
            AD.Resolution memory savedResolution
        ) = abi.decode(a.causeData, (L.Terminal, AD.Head, AD.Record, AD.Resolution));
        require(
            terminal.kind == 0 && !head.open && head.revocationReason == 4
                && head.resolutionActionId == action,
            "exact terminal cause"
        );
        require(
            savedOpening.recordHash == record
                && keccak256(abi.encode(savedResolution.terms))
                    == keccak256(abi.encode(resolution)),
            "full immutable documentary cause"
        );
        require(
            ingress.attributionDispute(1, 1).resolutionActionId == action
                && ingress.attributionDisputeResolution(action).actionId == action,
            "old source reads retained"
        );
        _state(1);
    }

    function testCorrectionStagedBeforeReopenCannotOverrideCurrentDispute() public {
        _accept();
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        (bytes32 e,) = _correctionEvidence(0, keccak256("initial opening"));
        AD.Filing memory p = AD.Filing(1, b.generation, 1, e, e);
        bytes32 opening = ingress.openAttributionDispute(p, _standing(), _signed(p));
        (e,) = _correctionEvidence(opening, keccak256("terminal cause"));
        _resolve(AD.ResolutionRequest(1, b.generation, opening, 2, e, e, 0), 2);
        T.BindingProposal memory proposal = _terms();
        BC.Context memory c = _context(proposal, 0);
        (e,) = _correctionEvidence(opening, keccak256("fresh forensic reopening"));
        p = AD.Filing(1, b.generation, 1, e, e);
        AD.Standing memory empty;
        T.Authorization memory noSignature;
        _govern(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.openAttributionDispute, (p, empty, noSignature)
            ),
            ingress.attributionDisputeOpeningContext(p),
            e,
            1
        );
        ArtistUnitRoles(suite.roleRegistry).setAdmin(manager.governanceAuthority(), true);
        bytes32 before_ = _roots();
        vm.expectRevert(abi.encodeWithSelector(BC.InvalidBindingCorrection.selector, uint256(1)));
        this.disputeGoverned(
            _data(proposal, 0),
            AD.Context(c.scopeHash, c.oldValueHash, c.newValueHash, 2, 0),
            proposal.reasonHash,
            2
        );
        require(
            _roots() == before_ && ingress.attributionDispute(1, 1).open,
            "staged old correction cannot overwrite reopened dispute"
        );
    }

    function _correctionEvidence(bytes32 parent, bytes32 narrative)
        internal
        returns (bytes32 evidence, bytes32 coverage)
    {
        _deMetadata();
        if (_deFirst == 0) {
            _deGrantFixity();
            _deFirst = _deFamily(true);
            _deSecond = _deFamily(false);
        }
        T.Binding memory binding_ = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        bytes memory payload = abi.encode(
            AD.Evidence(1, 1, binding_.generation, binding_.bindingHash, parent, narrative)
        );
        (evidence,) = _deStore.publishChunk(payload);
        A.Envelope memory e = A.Envelope(
            0,
            evidence,
            keccak256("6529STREAM_PLATFORM_WORKS_EVIDENCE_V1"),
            keccak256("BINARY_EXACT_V1"),
            2,
            sha256(payload),
            uint64(payload.length),
            1,
            0
        );
        bytes32 env = estateCoverageProvider.recordCollectionEnvelope(1, e, payload);
        A.Checkpoint memory c;
        c.networkId = estateCheckpointVerifier.networkId();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1500000;
        c.dataSize = uint64(payload.length);
        c.blockDataSize = payload.length;
        c.dataRoot = _deLeaf(sha256(payload), payload.length);
        c.transactionRoot = _deLeaf(c.dataRoot, payload.length);
        c.transactionId = keccak256(abi.encode("synthetic dispute transaction", evidence));
        c.transactionEnd = payload.length;
        c.observedAt = uint64(block.timestamp);
        c.configurationHash = estateCheckpointVerifier.configurationHash();
        bytes32 digest = estateCheckpointVerifier.checkpointDigest(c);
        A.ObserverProof[] memory cert = new A.ObserverProof[](2);
        cert[0] = A.ObserverProof(safeVm.addr(0xE5701), _deSign(0xE5701, digest));
        cert[1] = A.ObserverProof(safeVm.addr(0xE5702), _deSign(0xE5702, digest));
        if (cert[0].account > cert[1].account) (cert[0], cert[1]) = (cert[1], cert[0]);
        bytes32 checkpoint = estateCheckpointVerifier.recordCheckpoint(
            c,
            abi.encodePacked(c.dataRoot, uint256(payload.length)),
            abi.encodePacked(sha256(payload), uint256(payload.length)),
            payload,
            cert
        );
        bytes32 first =
            _deReceipt(env, _deFirst, checkpoint, abi.encodePacked(c.transactionId), 0xE5703, true);
        bytes32 second = _deReceipt(
            env, _deSecond, 0, abi.encodePacked(bytes4(0x01551220), e.payloadDigest), 0xE5704, false
        );
        _deFixity(first, e, _deNonce++);
        _deFixity(second, e, _deNonce++);
        coverage = estateCoverageProvider.recordCoverage(first, second);
        require(
            estateCoverageProvider.requireCollectionEvidence(1, evidence).coverageRecordHash
                == coverage,
            "actual two independent families and exact native checkpoint"
        );
    }
}
