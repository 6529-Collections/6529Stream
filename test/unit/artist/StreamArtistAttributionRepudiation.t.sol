// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistAttributionDisputeFixture.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReconstruction.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

/// @notice Actual Artist/Archive/Safe47–50. Core, Metadata facts and governed actions remain typed unit boundaries.
contract StreamArtistAttributionRepudiationTest is ArtistAttributionDisputeFixture {
    bytes32 private constant WINDOW = keccak256("ARTIST_REPUDIATION_CONTEST_SECONDS");
    address private constant GUARDIAN_A = address(0xAA1100);
    address private constant GUARDIAN_B = address(0xBB2200);

    function testDirectSafeStageHasOriginalDigestPreimageEventAndNoInstantRevocation() public {
        _accept();
        AD.Filing memory p = _terms();
        T.Authorization memory a = _rpAuthorization(p, true);
        require(
            ingress.attributionRepudiationDigest(p, a) == _digest(p, a),
            "independent original typed schema and registry domain"
        );
        T.Snapshot memory before_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        vm.recordLogs();
        require(
            this.executeArtistSafe(
                abi.encodeCall(IStreamArtistAttributionRepudiation.revokeAttribution, (p, a))
            ),
            "actual threshold Safe stage"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        RP.Record memory r = _pending();
        require(
            r.stagedAt == block.timestamp && r.executableAt == r.stagedAt + 7 days
                && r.windowRevision == 1 && r.terms.evidenceHash == 0,
            "full captured default window with optional evidence"
        );
        bytes memory original = _preimage(r);
        require(keccak256(original) == r.recordHash, "independent canonical record");
        require(
            keccak256(
                    IStreamArtistReconstruction(address(ingress)).recordPreimageBytes(r.recordHash)
                ) == keccak256(original),
            "permanent Archive carrier"
        );
        bytes32 topic = keccak256(
            "AttributionRepudiationStaged(uint16,uint256,bytes32,address,uint64,uint8,bytes32,bytes32,uint256,uint64,uint64,bytes32)"
        );
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[4] && logs[i].topics.length != 0
                    && logs[i].topics[0] == topic
            ) {
                ++count;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == artistId
                        && logs[i].topics[3] == bytes32(uint256(uint160(address(artist)))),
                    "actual original indexed event"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                p.bindingGeneration,
                                uint8(1),
                                p.evidenceHash,
                                p.reasonHash,
                                a.nonce,
                                r.stagedAt,
                                r.executableAt,
                                r.recordHash
                            )
                        ),
                    "independent complete original event tuple"
                );
            }
        }
        require(
            count == 1 && ingress.activeRepudiationCount(artistId) == 1,
            "one staged event and current pending count"
        );
        T.Snapshot memory after_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        require(
            after_.revision == before_.revision + 1
                && after_.recordChainTip == before_.recordChainTip,
            "original zero-record Identity authorization commit"
        );
        _state(2);
        _deArchive(47, address(artist), r.recordHash);
    }

    function testFullWindowWithoutGuardiansThenPermissionlessPermanentExit() public {
        _accept();
        RP.Record memory r = this.stageRepudiationFresh(false);
        bytes32 roots = _roots();
        this.advanceRepudiationTime(r.executableAt - 1);
        vm.expectRevert(abi.encodeWithSelector(RP.RepudiationNotExecutable.selector, r.recordHash));
        this.disputeRelay(
            abi.encodeCall(
                IStreamArtistAttributionRepudiation.executeAttributionRepudiation,
                (uint256(1), r.recordHash)
            )
        );
        require(_roots() == roots, "one second early has no mutation");
        this.advanceRepudiationTime(r.executableAt);
        ingress.executeAttributionRepudiation(1, r.recordHash);
        _state(5);
        require(
            ingress.attributionRepudiationTerminal(r.recordHash).phase == 4
                && _head().revocationReason == 3,
            "permanent explicit repudiation reason"
        );
        require(ingress.activeRepudiationCount(artistId) == 0, "no pending exit after execution");
        _deArchive(50, address(this), r.recordHash);
        bytes memory saved = _preimage(r);
        require(
            keccak256(
                    IStreamArtistReconstruction(address(ingress)).recordPreimageBytes(r.recordHash)
                ) == keccak256(saved),
            "history retained after exit"
        );
        vm.expectRevert();
        this.disputeRelay(
            abi.encodeCall(
                IStreamArtistAttributionRepudiation.executeAttributionRepudiation,
                (uint256(1), r.recordHash)
            )
        );
    }

    function testCapturedGuardianVetoCreatesCanonicalCauseAndDismissalNeverRevivesExit() public {
        _accept();
        _guardians(GUARDIAN_A);
        RP.Record memory r = this.stageRepudiationFresh(false);
        _guardians(GUARDIAN_B);
        uint256 count = IStreamArtistNativeReceipts(suite.owners[2]).artistNativeReceiptCount();
        vm.recordLogs();
        this.vetoRepudiationAs(
            GUARDIAN_A, r.recordHash, keccak256("captured guardian theft warning")
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        Contest.Record memory contest = ingress.identityContestRecord(cause.facts.referenceHash);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_RECORD_V1"),
                block.chainid,
                address(ingress),
                artistId,
                GUARDIAN_A,
                bytes32(0),
                r.recordHash,
                keccak256("captured guardian theft warning"),
                uint64(block.timestamp)
            )
        );
        require(
            contest.recordHash == expected && contest.terms.evidenceHash == r.recordHash
                && contest.contester == GUARDIAN_A,
            "independent original canonical compromise preimage"
        );
        require(
            cause.facts.kind == 1 && cause.facts.referenceHash == expected
                && cause.facts.incumbent == address(artist)
                && cause.facts.evidenceHash == r.recordHash,
            "actual kind1 cause retains prior authority and exact47 evidence"
        );
        _assertDismissalCauseEvent(logs, cause);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4
                && ingress.attributionRepudiationTerminal(r.recordHash).phase == 2,
            "actual identity contested and exit vetoed"
        );
        require(
            IStreamArtistNativeReceipts(suite.owners[2]).artistNativeReceiptCount() == count + 2,
            "two actual auxiliary records"
        );
        StreamArtistHistoryTypes.Receipt memory first =
            IStreamArtistNativeReceipts(suite.owners[2]).artistNativeReceiptAt(count);
        StreamArtistHistoryTypes.Receipt memory second =
            IStreamArtistNativeReceipts(suite.owners[2]).artistNativeReceiptAt(count + 1);
        require(
            first.operation == 48 && first.recordHash == expected && second.operation == 48
                && second.recordHash == cause.causeHash,
            "ordered actual48 record then cause receipts"
        );
        _deArchive(48, GUARDIAN_A, r.recordHash);
        _state(2);
        this.executeGovernedDismissal(_dismissalRequest(), 1, 0);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 1,
            "original58 resolution restores authority"
        );
        this.advanceRepudiationTime(r.executableAt + 1);
        vm.expectRevert();
        this.disputeRelay(
            abi.encodeCall(
                IStreamArtistAttributionRepudiation.executeAttributionRepudiation,
                (uint256(1), r.recordHash)
            )
        );
        require(
            ingress.attributionRepudiationTerminal(r.recordHash).phase == 2,
            "later dismissal cannot resurrect vetoed exit"
        );
    }

    function testNewCurrentGuardianAlsoHasVetoAndForeignActorDoesNot() public {
        _accept();
        _guardians(GUARDIAN_A);
        RP.Record memory r = this.stageRepudiationFresh(false);
        _guardians(GUARDIAN_B);
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(0xBAD)));
        this.vetoRepudiationAs(address(0xBAD), r.recordHash, keccak256("foreign veto"));
        require(_roots() == roots, "no foreign identity or collection mutation");
        this.vetoRepudiationAs(GUARDIAN_B, r.recordHash, keccak256("new current guardian"));
        require(
            ingress.attributionRepudiationTerminal(r.recordHash).actor == GUARDIAN_B,
            "current cohort veto admitted independently of captured cohort"
        );
    }

    function testStagingRotationVoidsPendingExitBeforeRotationExecutes() public {
        _accept();
        RP.Record memory r = this.stageRepudiationFresh(false);
        _newRotationSafe(4747);
        bytes32 rotation = _stageRotation(0);
        require(
            ingress.rotationRecord(rotation).transition.phase == 1,
            "actual pending29 before any execution"
        );
        (,, bytes32 pending) = ingress.pendingRepudiation(1);
        require(
            pending == 0 && ingress.activeRepudiationCount(artistId) == 0,
            "changed immutable authority history voids pending exit"
        );
        this.advanceRepudiationTime(r.executableAt + 1);
        vm.expectRevert();
        this.disputeRelay(
            abi.encodeCall(
                IStreamArtistAttributionRepudiation.executeAttributionRepudiation,
                (uint256(1), r.recordHash)
            )
        );
        _state(2);
        require(
            ingress.attributionRepudiationRecord(r.recordHash).recordHash == r.recordHash,
            "prior exit remains historical"
        );
    }

    function testOrdinaryIdentityContestAndAttributionDisputeVoidTheirPendingExits() public {
        _accept();
        _guardians(GUARDIAN_A);
        RP.Record memory first = this.stageRepudiationFresh(false);
        vm.prank(GUARDIAN_A);
        ingress.contestArtistIdentity(
            artistId, 0, keccak256("ordinary identity evidence"), keccak256("ordinary reason")
        );
        (,, bytes32 live) = ingress.pendingRepudiation(1);
        require(live == 0, "actual original33 makes exit unavailable");
        vm.expectRevert();
        this.stageRepudiationFresh(false);
        this.executeGovernedDismissal(_dismissalRequest(), 1, 0);
        RP.Record memory second = this.stageRepudiationFresh(false);
        require(
            second.recordHash != first.recordHash
                && ingress.attributionRepudiationTerminal(first.recordHash).phase == 5,
            "fresh head lazily terminates immutable old exit"
        );
        bytes32 dispute = _open(keccak256("current attribution complaint"));
        require(
            ingress.attributionRepudiationTerminal(second.recordHash).phase == 5,
            "original44 explicitly invalidates pending47"
        );
        vm.expectRevert();
        this.stageRepudiationFresh(false);
        _resolve(_resolution(1, keccak256("upheld complaint")), 1);
        vm.expectRevert();
        this.disputeRelay(
            abi.encodeCall(
                IStreamArtistAttributionRepudiation.executeAttributionRepudiation,
                (uint256(1), second.recordHash)
            )
        );
        require(
            ingress.attributionDisputeRecord(dispute).recordHash == dispute,
            "independent dispute history retained"
        );
    }

    function testStillCurrentStagingSafeCancellationHasNoNewAuthorizationNonceAndRecordsActivity()
        public
    {
        _accept();
        RP.Record memory r = this.stageRepudiationFresh(false);
        this.advanceRepudiationTime(r.stagedAt + 11);
        T.Identity memory before_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        bytes memory data = abi.encodeCall(
            IStreamArtistAttributionRepudiation.cancelAttributionRepudiation,
            (uint256(1), r.recordHash)
        );
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        this.disputeRelay(data);
        require(this.executeArtistSafe(data), "actual staging Safe cancellation");
        T.Identity memory after_ = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId);
        require(
            after_.nonceHint == before_.nonceHint
                && after_.lastAuthorityActionAt == r.stagedAt + 11,
            "direct cancellation updates activity without invented signed nonce"
        );
        require(
            ingress.attributionRepudiationTerminal(r.recordHash).phase == 3,
            "immutable cancel terminal"
        );
        _deArchive(49, address(artist), r.recordHash);
        _state(2);
    }

    function testCancellationInvalidatesAnActualUnavailabilityFinding() public {
        (Recovery.FindingRequest memory request, U.Target memory target) = _unavailabilityFixture();
        RP.Record memory r = this.stageRepudiationFresh(false);
        bytes32 finding = _recordUnavailability(request, target);
        T.Binding memory binding_ = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        require(
            IStreamArtistUnavailabilityOwner(suite.owners[2])
                .unavailabilityFindingLive(finding, binding_),
            "genuine current finding before activity"
        );
        this.advanceRepudiationTime(r.stagedAt + 2);
        vm.recordLogs();
        require(
            this.executeArtistSafe(
                abi.encodeCall(
                    IStreamArtistAttributionRepudiation.cancelAttributionRepudiation,
                    (uint256(1), r.recordHash)
                )
            ),
            "actual cancellation"
        );
        _unavailabilityActivityEvent(vm.getRecordedLogs(), address(artist), 1, 49);
        require(
            !IStreamArtistUnavailabilityOwner(suite.owners[2])
                .unavailabilityFindingLive(finding, binding_),
            "existing activity epoch invalidates unexecuted finding"
        );
        (Recovery.FindingRecord memory original,) =
            IStreamArtistUnavailabilityOwner(suite.owners[2]).unavailabilityFindingRecord(finding);
        require(original.recordHash == finding, "finding history is not erased");
    }

    function testWindowFloorGovernanceContextAndExistingCapturedDeadlineStayExact() public {
        _accept();
        RP.Record memory r = this.stageRepudiationFresh(false);
        (uint64 value, uint64 floor, uint64 revision) = ingress.artistWindowInfo(WINDOW);
        require(
            value == 7 days && floor == 3 days && revision == 1,
            "original parameter genesis and floor"
        );
        vm.expectRevert(abi.encodeWithSelector(R.InvalidArtistWindow.selector, WINDOW));
        this.configureRepudiationWindow(3 days - 1, 1, 1, false);
        vm.expectRevert(abi.encodeWithSelector(R.InvalidArtistWindowContext.selector));
        this.configureRepudiationWindow(3 days, 1, 0, false);
        vm.expectRevert(abi.encodeWithSelector(R.InvalidArtistWindowContext.selector));
        this.configureRepudiationWindow(3 days, 1, 1, true);
        this.configureRepudiationWindow(3 days, 1, 1, false);
        require(
            ingress.attributionRepudiationRecord(r.recordHash).executableAt == r.executableAt,
            "captured47 deadline never follows later parameter decrease"
        );
        require(
            this.executeArtistSafe(
                abi.encodeCall(
                    IStreamArtistAttributionRepudiation.cancelAttributionRepudiation,
                    (uint256(1), r.recordHash)
                )
            ),
            "cancel old stage"
        );
        RP.Record memory next = this.stageRepudiationFresh(false);
        require(
            next.executableAt == next.stagedAt + 3 days && next.windowRevision == 2,
            "new stage captures exact new parameter revision"
        );
    }

    function testRepudiationCannotReopenEvenAfterEarlierArbiterRevokeAndReinstatement() public {
        _accept();
        _open(keccak256("first arbiter history"));
        _resolve(_resolution(2, keccak256("initial revoke")), 2);
        AD.Filing memory appeal = _filing(1, keccak256("fresh appellate evidence"));
        AD.Standing memory empty;
        T.Authorization memory noSignature;
        _govern(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.openAttributionDispute,
                (appeal, empty, noSignature)
            ),
            ingress.attributionDisputeOpeningContext(appeal),
            appeal.reasonHash,
            1
        );
        _resolve(_resolution(1, keccak256("reinstatement")), 2);
        _state(2);
        RP.Record memory r = this.stageRepudiationFresh(false);
        this.advanceRepudiationTime(r.executableAt);
        ingress.executeAttributionRepudiation(1, r.recordHash);
        require(
            _head().revocationReason == 3, "new terminal cause replaces reopenable arbiter reason"
        );
        AD.Filing memory denied = _filing(1, keccak256("third opinion cannot override chosen exit"));
        vm.expectRevert();
        ingress.attributionDisputeOpeningContext(denied);
        _state(5);
    }

    function testDelegationAndWrongActionCannotReplaceNondelegableCurrentAuthority() public {
        _accept();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 16, 0, 0, 3));
        AD.Filing memory p = _terms();
        T.Authorization memory a = _rpAuthorization(p, false);
        a.signature = _delegateSignature(ingress.attributionRepudiationDigest(p, a));
        bytes32 roots = _roots();
        vm.expectRevert();
        this.disputeRelay(
            abi.encodeCall(IStreamArtistAttributionRepudiation.revokeAttribution, (p, a))
        );
        require(_roots() == roots, "CAP_DISPUTE grant cannot sign unilateral irreversible exit");
        require(
            ingress.delegationRecord(grant).grant.capabilities == 16, "delegation history unchanged"
        );
        a = _rpAuthorization(p, true);
        a.nonce += 1;
        vm.expectRevert(bytes("GS013"));
        this.executeArtistSafe(
            abi.encodeCall(IStreamArtistAttributionRepudiation.revokeAttribution, (p, a))
        );
        p.disputeAction = 2;
        vm.expectRevert(abi.encodeWithSelector(RP.InvalidRepudiation.selector, bytes32(0)));
        this.disputeRelay(
            abi.encodeCall(IStreamArtistAttributionRepudiation.revokeAttribution, (p, a))
        );
        RP.Record memory r = this.stageRepudiationFresh(false);
        require(r.authorityClass == 1, "actual current authority remains able to stage");
        roots = _roots();
        p = _terms();
        a = _rpAuthorization(p, false);
        vm.expectRevert(abi.encodeWithSelector(RP.ActiveRepudiation.selector, artistId));
        this.disputeRelay(
            abi.encodeCall(IStreamArtistAttributionRepudiation.revokeAttribution, (p, a))
        );
        require(_roots() == roots, "at most one current pending exit");
    }

    function testLateArchiveFailureRollsBackStageAndIdenticalSafeRetry() public {
        _accept();
        AD.Filing memory p = _terms();
        T.Authorization memory a = _rpAuthorization(p, true);
        bytes memory data =
            abi.encodeCall(IStreamArtistAttributionRepudiation.revokeAttribution, (p, a));
        bytes32 roots = _roots();
        uint256 nonce = artist.nonce();
        uint256 payloads = IStreamArtistReconstruction(address(ingress)).storedPayloadCount();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(DisputeTestFailure.selector)
        );
        vm.expectRevert(bytes("GS013"));
        this.executeArtistSafe(data);
        (,, bytes32 pending) = ingress.pendingRepudiation(1);
        require(
            pending == 0 && ingress.activeRepudiationCount(artistId) == 0 && _roots() == roots
                && artist.nonce() == nonce
                && IStreamArtistReconstruction(address(ingress)).storedPayloadCount() == payloads,
            "late Archive rolls back state replay carrier and Safe nonce"
        );
        avm.clearMockedCalls();
        require(this.executeArtistSafe(data), "identical calldata and Safe nonce retry");
        RP.Record memory r = _pending();
        _deArchive(47, address(artist), r.recordHash);
    }

    function testLateArchiveFailureRollsBackGuardianVetoAndCanonicalCauseThenRetries() public {
        _accept();
        _guardians(GUARDIAN_A);
        RP.Record memory r = this.stageRepudiationFresh(false);
        bytes32 roots = _roots();
        uint256 count = IStreamArtistNativeReceipts(suite.owners[2]).artistNativeReceiptCount();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(DisputeTestFailure.selector)
        );
        vm.expectRevert(abi.encodeWithSelector(DisputeTestFailure.selector));
        this.vetoRepudiationAs(GUARDIAN_A, r.recordHash, keccak256("same veto"));
        require(
            _roots() == roots && ingress.attributionRepudiationTerminal(r.recordHash).phase == 1
                && ingress.currentIdentityContestCause(artistId).causeHash == 0
                && IStreamArtistNativeReceipts(suite.owners[2]).artistNativeReceiptCount() == count,
            "whole canonical compromise composition rolls back"
        );
        avm.clearMockedCalls();
        this.vetoRepudiationAs(GUARDIAN_A, r.recordHash, keccak256("same veto"));
        require(
            ingress.attributionRepudiationTerminal(r.recordHash).phase == 2,
            "identical original direct guardian call succeeds"
        );
    }

    function testExecutedSuccessorRequiresItsOriginalDisputeCapability() public {
        _accept();
        this.activateRepudiationEstate(0);
        AD.Filing memory p = _terms();
        T.Authorization memory a = _rpAuthorization(p, false);
        bytes32 roots = _roots();
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.EstateCapabilityUnavailable.selector, artistId, uint32(16)
            )
        );
        this.disputeRelay(
            abi.encodeCall(IStreamArtistAttributionRepudiation.revokeAttribution, (p, a))
        );
        require(_roots() == roots, "zero-mask successor cannot repudiate");
    }

    function testCapableExecutedSuccessorStagesAndCompletesAsClass3() public {
        _accept();
        this.activateRepudiationEstate(16);
        RP.Record memory r = this.stageRepudiationFresh(false);
        require(
            r.authorityClass == 3 && r.signer == address(artist),
            "exact actual op40 principal and capability origin"
        );
        this.advanceRepudiationTime(r.executableAt);
        ingress.executeAttributionRepudiation(1, r.recordHash);
        _state(5);
    }

    function testPriorStandingCannotBeRevokedWhileARepudiationRemainsPending() public {
        _accept();
        address prior = address(artist);
        _newRotationSafe(4751);
        bytes32 rotation = _stageRotation(0);
        R.RotationRecord memory staged = ingress.rotationRecord(rotation);
        this.advanceRepudiationTime(staged.transition.contestEndsAt);
        ingress.executeArtistRotation(artistId, rotation);
        _adoptRotatedSafe();
        R.RotationRecord memory executed = ingress.rotationRecord(rotation);
        this.advanceRepudiationTime(
            uint256(executed.transition.postWindowEndsAt) + executed.standingTail
        );
        RP.Record memory r = this.stageRepudiationFresh(false);
        R.StandingRevocation memory p =
            R.StandingRevocation(artistId, prior, keccak256("standing revocation"), rotation);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.standingRevocationDigest(p, a));
        bytes memory data = abi.encodeCall(IStreamArtistRotation.revokePriorAddressStanding, (p, a));
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(R.InvalidPriorStanding.selector, prior));
        this.disputeRelay(data);
        require(_roots() == roots, "pending current47 preserves lifetime defense");
        require(
            this.executeArtistSafe(
                abi.encodeCall(
                    IStreamArtistAttributionRepudiation.cancelAttributionRepudiation,
                    (uint256(1), r.recordHash)
                )
            ),
            "staging authority cancels without consuming signed nonce"
        );
        this.disputeRelay(data);
        (bool revoked,) = ingress.priorAddressStandingRevoked(artistId, prior);
        require(
            revoked, "identical prior-standing authorization succeeds only after pending exit ends"
        );
    }

    function stageRepudiationFresh(bool direct) external returns (RP.Record memory r) {
        require(msg.sender == address(this));
        AD.Filing memory p = _terms();
        T.Authorization memory a = _rpAuthorization(p, direct);
        if (direct) {
            require(
                this.executeArtistSafe(
                    abi.encodeCall(IStreamArtistAttributionRepudiation.revokeAttribution, (p, a))
                ),
                "actual Safe"
            );
        } else {
            ingress.revokeAttribution(p, a);
        }
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        return _pending();
    }

    function advanceRepudiationTime(uint256 at) external {
        require(msg.sender == address(this));
        vm.warp(at);
    }

    function activateRepudiationEstate(uint32 caps) external {
        require(msg.sender == address(this));
        _estateActivateAndAdopt(caps);
    }

    function vetoRepudiationAs(address actor, bytes32 hash, bytes32 reason) external {
        require(msg.sender == address(this));
        vm.prank(actor);
        ingress.vetoAttributionRepudiation(1, hash, reason);
    }

    function configureRepudiationWindow(uint64 value, uint64 revision, uint8 class_, bool wrong)
        external
    {
        require(msg.sender == address(this));
        ArtistUnitGovernance(manager.governanceAuthority())
            .configureWindow(
                IStreamArtistWindows(address(ingress)), WINDOW, value, revision, class_, wrong
            );
    }

    function _terms() private view returns (AD.Filing memory) {
        T.Binding memory b = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        return AD.Filing(1, b.generation, 4, 0, keccak256("voluntary artist repudiation reason"));
    }

    function _rpAuthorization(AD.Filing memory p, bool direct)
        private
        returns (T.Authorization memory a)
    {
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        a = T.Authorization(nonce, direct ? 0 : uint64(block.timestamp + 1 days), "");
        if (!direct) a.signature = _signature(ingress.attributionRepudiationDigest(p, a));
    }

    function _pending() private view returns (RP.Record memory r) {
        (uint64 gen, uint64 at, bytes32 hash) = ingress.pendingRepudiation(1);
        r = ingress.attributionRepudiationRecord(hash);
        require(
            hash != 0 && r.recordHash == hash && r.terms.bindingGeneration == gen
                && r.executableAt == at,
            "actual fixed pending read"
        );
    }

    function _guardians(address guardian) private {
        address[] memory members = new address[](1);
        members[0] = guardian;
        _guardianRecord(
            members,
            1,
            3 days,
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint
        );
    }

    function _preimage(RP.Record memory r) private view returns (bytes memory) {
        return abi.encode(
            keccak256("6529STREAM_ARTIST_ATTRIBUTION_REPUDIATION_RECORD_V1"),
            block.chainid,
            address(ingress),
            r.terms.collectionId,
            r.terms.bindingGeneration,
            r.artistId,
            r.signer,
            r.authorityClass,
            r.terms.evidenceHash,
            r.terms.reasonHash,
            r.nonce,
            r.stagedAt,
            r.executableAt
        );
    }
}
