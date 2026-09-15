// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistAttributionDisputeFixture.sol";

contract StreamArtistAttributionDisputesTest is ArtistAttributionDisputeFixture {
    function testDirectSafeOpeningOriginalRecordEventIdentityAndArchive() public {
        _accept();
        AD.Filing memory p = _filing(1, keccak256("direct opening"));
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, 0, "");
        T.Snapshot memory before_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        bytes32 expected = _record(p, address(artist), 1, nonce, uint64(block.timestamp));
        vm.recordLogs();
        require(
            this.executeArtistSafe(
                abi.encodeCall(
                    IStreamArtistAttributionDisputes.openAttributionDispute, (p, _standing(), a)
                )
            ),
            "direct actual Safe"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        AD.Record memory record = ingress.attributionDisputeRecord(_head().disputeRecordHash);
        require(
            record.recordHash == expected && record.signer == address(artist)
                && record.authorityClass == 1 && record.standing.artistId == artistId,
            "original complete record"
        );
        bytes32 topic = keccak256(
            "AttributionDisputeOpened(uint16,uint256,address,uint64,uint8,bytes32,bytes32,uint256,uint64,bytes32)"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[4] && logs[i].topics.length != 0
                    && logs[i].topics[0] == topic
            ) {
                ++found;
                require(
                    logs[i].topics.length == 3 && logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == bytes32(uint256(uint160(address(artist)))),
                    "original indexed event"
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
                                nonce,
                                uint64(block.timestamp),
                                expected
                            )
                        ),
                    "independent full event tuple"
                );
            }
        }
        require(found == 1, "one original opening event");
        T.Snapshot memory after_ = IStreamArtistOwner(suite.owners[2]).ownerStateSnapshotV2();
        require(
            after_.revision == before_.revision + 1
                && after_.recordChainTip == before_.recordChainTip,
            "one zero-record Identity commit"
        );
        _state(4);
        _deArchive(44, address(artist), expected);
    }

    function testRelayedThresholdCounterStatementsOriginalDigestHistoryAndNonceReplay() public {
        _accept();
        bytes32 opening = _open(keccak256("relayed opening"));
        AD.Filing memory p = _filing(3, keccak256("first counter"));
        T.Authorization memory a = _signed(p);
        require(
            ingress.attributionDisputeDigest(p, a) == _digest(p, a),
            "independent exact domain and typed payload"
        );
        bytes32 first = ingress.recordCounterStatement(p, _standing(), a);
        require(
            first == _record(p, address(artist), 1, a.nonce, uint64(block.timestamp)),
            "independent counter record"
        );
        require(
            keccak256(StreamArtistIdentityAuthority(suite.owners[2]).signatureBundle(first))
                == keccak256(a.signature),
            "full original threshold bundle retained"
        );
        bytes32 roots = _roots();
        bytes memory repeated = abi.encodeCall(
            IStreamArtistAttributionDisputes.recordCounterStatement, (p, _standing(), a)
        );
        vm.expectRevert();
        this.disputeRelay(repeated);
        require(_roots() == roots, "same nonce and tuple replay rollback");
        bytes32 second = _counter(keccak256("second counter"));
        AD.Record memory record = ingress.attributionDisputeRecord(second);
        require(
            record.previousRecordHash == first && record.disputeRecordHash == opening
                && _head().counterStatementRecordHash == second,
            "append-only counter heads"
        );
        require(ingress.attributionDisputeRecord(first).recordHash == first, "old body retained");
        _state(4);
        _deArchive(45, address(this), second);
    }

    function testNewCounterInvalidatesSavedResolutionAndExactFreshContextRestores() public {
        _accept();
        _open(keccak256("opening"));
        bytes32 first = _counter(keccak256("counter1"));
        AD.ResolutionRequest memory p = _resolution(1, keccak256("upheld evidence"));
        AD.Context memory saved = ingress.attributionDisputeResolutionContext(p);
        bytes32 second = _counter(keccak256("counter2 during staged interval"));
        bytes32 roots = _roots();
        bytes memory data =
            abi.encodeCall(IStreamArtistAttributionDisputes.resolveAttributionDispute, (p));
        vm.expectRevert();
        this.disputeGoverned(data, saved, p.reasonHash, 1);
        require(
            _roots() == roots && _head().counterStatementRecordHash == second,
            "stale staged latest-counter denial"
        );
        p.counterStatementRecordHash = second;
        AD.Context memory fresh = ingress.attributionDisputeResolutionContext(p);
        require(
            saved.oldValueHash != fresh.oldValueHash && saved.newValueHash != fresh.newValueHash,
            "new head changes both captured commitments"
        );
        bytes32 action = _resolve(p, 1);
        _state(2);
        AD.Resolution memory r = ingress.attributionDisputeResolution(action);
        require(
            r.terms.counterStatementRecordHash == second && r.actionClass == 1
                && r.restoredState == 2 && !_head().open,
            "executed resolution links latest speech"
        );
        require(
            ingress.attributionDisputeRecord(first).recordHash == first, "prior counter remains"
        );
        _deArchive(46, manager.governanceAuthority(), action);
    }

    function testTerminalRevocationAndReopenedReinstatementRequireClass2() public {
        _accept();
        bytes32 initial = _open(keccak256("first opinion"));
        AD.ResolutionRequest memory revoke_ = _resolution(2, keccak256("revoke"));
        AD.Context memory c = ingress.attributionDisputeResolutionContext(revoke_);
        require(c.requiredClass == 2, "terminal revocation class");
        vm.expectRevert(abi.encodeWithSelector(AD.DisputeGovernanceRequired.selector));
        this.disputeGoverned(
            abi.encodeCall(IStreamArtistAttributionDisputes.resolveAttributionDispute, (revoke_)),
            c,
            revoke_.reasonHash,
            1
        );
        bytes32 firstAction = _resolve(revoke_, 2);
        _state(5);
        AD.Filing memory next = _filing(1, keccak256("new forensic evidence"));
        T.Authorization memory a = _signed(next);
        bytes memory deniedArtist = abi.encodeCall(
            IStreamArtistAttributionDisputes.openAttributionDispute, (next, _standing(), a)
        );
        vm.expectRevert();
        this.disputeRelay(deniedArtist);
        AD.Standing memory empty;
        T.Authorization memory noSignature;
        _govern(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.openAttributionDispute, (next, empty, noSignature)
            ),
            ingress.attributionDisputeOpeningContext(next),
            next.reasonHash,
            1
        );
        require(
            _head().reopened && _head().restoreState == 2, "original pre-revocation state retained"
        );
        AD.ResolutionRequest memory uphold = _resolution(1, keccak256("reinstatement"));
        c = ingress.attributionDisputeResolutionContext(uphold);
        vm.expectRevert(abi.encodeWithSelector(AD.DisputeGovernanceRequired.selector));
        this.disputeGoverned(
            abi.encodeCall(IStreamArtistAttributionDisputes.resolveAttributionDispute, (uphold)),
            c,
            uphold.reasonHash,
            1
        );
        bytes32 nextAction = _resolve(uphold, 2);
        _state(2);
        require(
            ingress.attributionDisputeResolution(nextAction).previousResolutionActionId
                    == firstAction
                && ingress.attributionDisputeRecord(initial).recordHash == initial,
            "all opinions immutable"
        );
    }

    function testClaimedArbiterOpeningRestoresClaimedAndPublicCallerHasNoStanding() public {
        AD.Filing memory p = _filing(1, keccak256("claimed evidence"));
        T.Authorization memory a = _signed(p);
        bytes32 roots = _roots();
        bytes memory deniedClaimed = abi.encodeCall(
            IStreamArtistAttributionDisputes.openAttributionDispute, (p, _standing(), a)
        );
        vm.expectRevert();
        this.disputeRelay(deniedClaimed);
        require(_roots() == roots, "unaccepted identity cannot open");
        AD.Standing memory empty;
        T.Authorization memory noSignature;
        _govern(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.openAttributionDispute, (p, empty, noSignature)
            ),
            ingress.attributionDisputeOpeningContext(p),
            p.reasonHash,
            1
        );
        AD.Record memory r = ingress.attributionDisputeRecord(_head().disputeRecordHash);
        require(
            r.authorityClass == 0 && r.governanceActionId != 0 && r.nonce == 0
                && r.signer == address(artist),
            "arbiter recorder is class0 not artist"
        );
        _state(4);
        _resolve(_resolution(1, keccak256("claimed upheld")), 1);
        _state(1);
        _accept();
        _state(2);
    }

    function testAcceptedCollaboratorHasOpeningStandingButNotPrimaryCounterAuthority() public {
        _collaboratorIdentity(false);
        C.BindingAcceptance memory row = _collaborativeProposal(false);
        _collaboratorAcceptance(row, false);
        _accept();
        AD.Filing memory p = _filing(1, keccak256("collaborator evidence"));
        AD.Standing memory standing_ = AD.Standing(collaboratorId, row.generation, 0, 0);
        uint256 nonce =
            IStreamArtistIdentityOwner(suite.owners[2]).identity(collaboratorId).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, 2000, "");
        a.signature = _delegateSignature(ingress.attributionDisputeDigest(p, a));
        bytes32 record = ingress.openAttributionDispute(p, standing_, a);
        require(
            ingress.attributionDisputeRecord(record).standing.artistId == collaboratorId,
            "exact accepted collaborator identity"
        );
        p = _filing(3, keccak256("collaborator cannot speak for primary"));
        a.nonce = nonce + 1;
        a.signature = _delegateSignature(ingress.attributionDisputeDigest(p, a));
        vm.expectRevert();
        this.disputeRelay(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.recordCounterStatement, (p, standing_, a)
            )
        );
        _counter(keccak256("primary response"));
        _state(4);
    }

    function testDisputeDelegateUsesOriginalGrantNonceAndRevocationGuards() public {
        _accept();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 16, 1000, 2000, 3));
        AD.Standing memory standing_ = _standing();
        standing_.delegation = grant;
        AD.Filing memory p = _filing(1, keccak256("delegate opens"));
        T.Authorization memory a = T.Authorization(0, 2000, "");
        a.signature = _delegateSignature(ingress.attributionDisputeDigest(p, a));
        bytes32 opening = ingress.openAttributionDispute(p, standing_, a);
        require(
            ingress.attributionDisputeRecord(opening).authorityClass == 2
                && ingress.delegationRecord(grant).uses == 1,
            "actual grant one use and class2"
        );
        p = _filing(3, keccak256("delegate counters"));
        a.nonce = 1;
        a.signature = _delegateSignature(ingress.attributionDisputeDigest(p, a));
        bytes32 record = ingress.recordCounterStatement(p, standing_, a);
        require(
            ingress.attributionDisputeRecord(record).standing.delegation == grant
                && ingress.delegationRecord(grant).uses == 2,
            "immutable grant link and next original nonce"
        );
        _revoke(grant);
        p = _filing(3, keccak256("revoked delegate"));
        a.nonce = 2;
        a.signature = _delegateSignature(ingress.attributionDisputeDigest(p, a));
        bytes32 roots = _roots();
        vm.expectRevert();
        this.disputeRelay(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.recordCounterStatement, (p, standing_, a)
            )
        );
        require(
            _roots() == roots && ingress.delegationRecord(grant).uses == 2,
            "revoked grant use rolls back"
        );
        _counter(keccak256("principal still speaks"));
    }

    function testWrongDelegateCapabilityAndExhaustedGrantCannotAuthorizeDispute() public {
        _accept();
        _delegateSetup();
        bytes32 wrong = _grant(_delegation(1, 1, 1000, 2000, 1));
        AD.Filing memory p = _filing(1, keccak256("capability denial"));
        AD.Standing memory standing_ = _standing();
        standing_.delegation = wrong;
        T.Authorization memory a = T.Authorization(0, 2000, "");
        a.signature = _delegateSignature(ingress.attributionDisputeDigest(p, a));
        vm.expectRevert();
        this.disputeRelay(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.openAttributionDispute, (p, standing_, a)
            )
        );
        require(ingress.delegationRecord(wrong).uses == 0, "wrong capability has no use");
        _revoke(wrong);
        bytes32 grant = _grant(_delegation(1, 16, 1000, 2000, 1));
        standing_.delegation = grant;
        // Same original delegate nonce and signature remain usable after the failed capability check.
        ingress.openAttributionDispute(p, standing_, a);
        p = _filing(3, keccak256("exhausted"));
        a.nonce = 1;
        a.signature = _delegateSignature(ingress.attributionDisputeDigest(p, a));
        vm.expectRevert();
        this.disputeRelay(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.recordCounterStatement, (p, standing_, a)
            )
        );
        require(ingress.delegationRecord(grant).uses == 1, "exhausted grant remains immutable");
    }

    function testIdentityContestedKeepsDefensiveOpenCounterAndExistingDelegate() public {
        _accept();
        _delegateSetup();
        bytes32 grant = _grant(_delegation(1, 16, 1000, 2000, 3));
        _selfGuardian();
        require(this.executeArtistSafe(_contestData(0)), "actual guardian compromise contest");
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "actual identity contested"
        );
        _open(keccak256("defensive direct principal"));
        AD.Filing memory p = _filing(3, keccak256("defensive delegate"));
        AD.Standing memory standing_ = _standing();
        standing_.delegation = grant;
        T.Authorization memory a = T.Authorization(0, 2000, "");
        a.signature = _delegateSignature(ingress.attributionDisputeDigest(p, a));
        ingress.recordCounterStatement(p, standing_, a);
        require(
            IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).status == 4,
            "speech never dismisses compromise"
        );
        _state(4);
    }

    function testDisputedStateBlocksNewPolicyAndScopedGrantsButAllowsCounter() public {
        _accept();
        _delegateSetup();
        _open(keccak256("opening"));
        T.PolicyConsent memory policy = T.PolicyConsent(1, PHASE, POLICY);
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.policyConsentDigest(policy, a));
        vm.expectRevert();
        this.disputeRelay(abi.encodeCall(IStreamArtistOnboarding.recordPolicyConsent, (policy, a)));
        D.Grant memory grant = _delegation(1, 16, 1000, 2000, 3);
        a = _authorization(false);
        a.time = 0;
        a.signature = _signature(ingress.delegationGrantDigest(grant, a));
        vm.expectRevert();
        this.disputeRelay(abi.encodeCall(IStreamArtistDelegation.grantArtistDelegation, (grant, a)));
        require(_closed(_mintCall()), "current mint consumer stops");
        _counter(keccak256("defense remains open"));
    }

    function testCoveredDocumentParentAndCurrentStandingAreRequired() public {
        _accept();
        AD.Filing memory p = _filing(1, keccak256("evidence"));
        T.Authorization memory a = _signed(p);
        AD.Standing memory standing_ = _standing();
        standing_.artistId = keccak256("unrelated identity");
        vm.expectRevert();
        this.disputeRelay(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.openAttributionDispute, (p, standing_, a)
            )
        );
        standing_ = _standing();
        (p.evidenceHash,) = _deEvidence(keccak256("foreign dispute"), keccak256("wrong parent"));
        a = _signed(p);
        vm.expectRevert();
        this.disputeRelay(
            abi.encodeCall(
                IStreamArtistAttributionDisputes.openAttributionDispute, (p, standing_, a)
            )
        );
        _state(2);
        _open(keccak256("new exact evidence"));
    }

    function testMissingCoverageAndLateArchiveRollbackKeepExactSafeRetry() public {
        _accept();
        AD.Filing memory p = _filing(1, keccak256("retry evidence"));
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        T.Authorization memory a = T.Authorization(nonce, 0, "");
        bytes memory data = abi.encodeCall(
            IStreamArtistAttributionDisputes.openAttributionDispute, (p, _standing(), a)
        );
        bytes32 roots = _roots();
        uint256 safeNonce = artist.nonce();
        bytes32 expected = _record(p, address(artist), 1, nonce, uint64(block.timestamp));
        avm.mockCallRevert(
            address(estateCoverageProvider),
            abi.encodeCall(
                IStreamCollectionArchivalCoverage.requireCollectionEvidence, (1, p.evidenceHash)
            ),
            abi.encodeWithSelector(DisputeTestFailure.selector)
        );
        vm.expectRevert(bytes("GS013"));
        this.executeArtistSafe(data);
        require(
            _roots() == roots && artist.nonce() == safeNonce && _head().disputeRecordHash == 0,
            "missing coverage whole Safe rollback"
        );
        avm.clearMockedCalls();
        _deMetadata();
        avm.mockCallRevert(
            address(archive),
            abi.encodeWithSelector(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector),
            abi.encodeWithSelector(DisputeTestFailure.selector)
        );
        vm.expectRevert(bytes("GS013"));
        this.executeArtistSafe(data);
        require(
            _roots() == roots && artist.nonce() == safeNonce
                && ingress.attributionDisputeRecord(expected).recordHash == 0,
            "late archive rolls back record nonce state and Safe"
        );
        avm.clearMockedCalls();
        _deMetadata();
        vm.recordLogs();
        require(this.executeArtistSafe(data), "identical Safe calldata retry");
        require(
            _head().disputeRecordHash == expected && artist.nonce() == safeNonce + 1,
            "successful retry commits exactly once"
        );
        _deArchive(44, address(artist), expected);
    }

    function testOriginalOwnerAndGovernanceContextRemainRequired() public {
        _accept();
        AD.Filing memory p = _filing(1, keccak256("arbiter context"));
        AD.Context memory correct = ingress.attributionDisputeOpeningContext(p);
        AD.Context memory wrong = abi.decode(abi.encode(correct), (AD.Context));
        wrong.oldValueHash = keccak256("foreign old state");
        AD.Standing memory empty;
        T.Authorization memory noSignature;
        bytes memory data = abi.encodeCall(
            IStreamArtistAttributionDisputes.openAttributionDispute, (p, empty, noSignature)
        );
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
        this.disputeGoverned(data, wrong, p.reasonHash, 1);
        require(_roots() == roots, "wrong saved governance context cannot mutate");
        vm.expectRevert(abi.encodeWithSelector(Contest.InvalidContestGovernance.selector));
        this.disputeGoverned(data, correct, p.reasonHash, 0);
        AD.Admission memory admission;
        Contest.GovernanceWitness memory g;
        T.ActionContext memory c = T.ActionContext(
            44, address(this), IStreamArtistOwner(suite.owners[4]).ownerStateSnapshotV2()
        );
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        IStreamArtistAttributionDisputesOwner(suite.owners[4]).applyDispute(c, p, admission, 0, g);
        _govern(data, correct, p.reasonHash, 1);
        _state(4);
    }

    function testOp44RejectsReservedWithdrawalAndDirectSafeWrongNonce() public {
        _accept();
        AD.Filing memory p = _filing(1, keccak256("nonce"));
        AD.Standing memory standing_ = _standing();
        uint256 nonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        T.Authorization memory a = T.Authorization(nonce + 1, 0, "");
        bytes memory data =
            abi.encodeCall(
            IStreamArtistAttributionDisputes.openAttributionDispute, (p, standing_, a)
        );
        bytes32 roots = _roots();
        uint256 safeNonce = artist.nonce();
        vm.expectRevert(bytes("GS013"));
        this.executeArtistSafe(data);
        require(
            _roots() == roots && artist.nonce() == safeNonce,
            "direct allocator rejection keeps identical Safe nonce"
        );
        p.disputeAction = 2;
        data =
            abi.encodeCall(
            IStreamArtistAttributionDisputes.openAttributionDispute, (p, standing_, a)
        );
        vm.expectRevert(abi.encodeWithSelector(AD.InvalidAttributionDispute.selector, uint256(1)));
        this.disputeRelay(data);
        p.disputeAction = 1;
        a.nonce = nonce;
        data =
            abi.encodeCall(
            IStreamArtistAttributionDisputes.openAttributionDispute, (p, standing_, a)
        );
        require(this.executeArtistSafe(data), "exact current allocator succeeds");
        _state(4);
    }
}
