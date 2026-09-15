// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";

/// @notice Actual Safe, canonical Executor, artist owners and current paid-mint recovery.
contract StreamCurrentIdentityDismissalTest is StreamCurrentSafeGovernanceFixture {
    OfficialSafe private artistSafe;
    uint256[] private keys;
    bytes32 private constant ARBITER = keccak256("ROLE_ATTRIBUTION_ARBITER");
    bytes32 private constant EVIDENCE = keccak256("current identity contest cause");
    IStreamArtistIdentityContest private contests;
    IStreamArtistIdentityDismissal private dismissals;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 221);
        OfficialSafe governor = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 222);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(governor, keys);
        contests = IStreamArtistIdentityContest(address(artists));
        dismissals = IStreamArtistIdentityDismissal(address(artists));
        vm.deal(address(governorSafe), 1 ether);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function testSafeGovernedDismissalRestoresMintAndPreservesSignedIntent() public {
        bytes32 nonce = keccak256("same signed intent after dismissal");
        bytes memory purchase = _purchaseData(nonce);
        _fileContest();
        Dismissal.Request memory terms = _terms();
        GovernanceActionRequest memory request = _request(terms, 1);
        _safeRead(abi.encodeCall(dismissals.identityContestDismissalContext, (terms)));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeCurrentPurchase(purchase);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeCurrentGovernorCall(address(artists), request.callData);
        uint256 tokenBefore = core.lastAllocatedTokenId();
        bytes32 action = _scheduleAsGovernor(request);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector,
                action,
                request.notBefore
            )
        );
        executor.executeGovernanceAction(action, request.callData);
        vm.warp(request.notBefore);
        _executeAsGovernor(action, request.callData);
        _assertDismissal(action, request, terms);
        require(
            !sale.authorizationUsed(address(artistSafe), nonce),
            "dismissal does not consume sale authorization"
        );
        this.executeCurrentPurchase(purchase);
        require(
            core.lastAllocatedTokenId() == tokenBefore + 1
                && core.ownerOf(tokenBefore + 1) == address(governorSafe)
                && wallet.balance == 0.01 ether
                && sale.authorizationUsed(address(artistSafe), nonce),
            "same current signed paid mint succeeds"
        );
    }

    function testSafeRoleGrantThenDismissalUsesSecondBatchCallContext() public {
        _fileContest();
        _setRole(ARBITER, address(governorSafe), false);
        Dismissal.Request memory terms = _terms();
        GovernanceActionRequest memory request = _request(terms, 1);
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        (calls[0], data[0]) = _roleCall(ARBITER, address(governorSafe), true);
        data[1] = request.callData;
        calls[1] = StreamCurrentStackPlan.call(
            address(artists), data[1], request.scopeHash, request.oldValueHash, request.newValueHash
        );
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(1, calls, data);
        require(
            executor.governanceAction(action).scopeHash != request.scopeHash,
            "batch header differs from actual dismissal call"
        );
        vm.warp(ready);
        vm.recordLogs();
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        _assertDismissal(action, request, terms);
        require(
            roles.hasRole(ARBITER, address(governorSafe)), "fresh preceding role grant observed"
        );
    }

    function testSafeDismissalWrongReasonAndRoleLossRollbackThenSameActionRetries() public {
        _fileContest();
        Dismissal.Request memory terms = _terms();
        uint256 snapshot = vm.snapshotState();
        GovernanceActionRequest memory request = _request(terms, 1);
        request.reasonHash = keccak256("incorrect stored governance reason");
        bytes32 action = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        _expectFailure(action, request.callData);
        require(vm.revertToState(snapshot), "restore independent role-loss scenario");
        request = _request(terms, 1);
        action = _scheduleAsGovernor(request);
        _setRole(ARBITER, address(governorSafe), false);
        _expectFailure(action, request.callData);
        _setRole(ARBITER, address(governorSafe), true);
        require(
            block.timestamp >= request.notBefore && block.timestamp <= request.expiresAfter,
            "same scheduled action stays live"
        );
        _executeAsGovernor(action, request.callData);
        _assertDismissal(action, request, terms);
    }

    function testSafeClassTwoDismissalClosesGuardianWindowAndRejectsResolvedCauseReplay() public {
        _fileContest();
        Dismissal.Request memory terms = _terms();
        GovernanceActionRequest memory request = _request(terms, 2);
        bytes32 action = _scheduleAsGovernor(request);
        require(
            executor.liveTerminalFreezeActionCount(request.scopeHash) == 1,
            "real guardian window indexed"
        );
        vm.warp(request.notBefore);
        _executeAsGovernor(action, request.callData);
        _assertDismissal(action, request, terms);
        require(
            executor.liveTerminalFreezeActionCount(request.scopeHash) == 0,
            "completed guardian window removed"
        );
        bytes32 record = dismissals.latestIdentityContestDismissal(fixtureArtistId);
        bytes32 root = _identityRoot();
        request.notBefore = uint64(block.timestamp + executor.minimumDelay(2));
        request.expiresAfter = request.notBefore + 7 days;
        bytes32 replay = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceAction, (replay, request.callData))
        );
        require(
            dismissals.latestIdentityContestDismissal(fixtureArtistId) == record
                && _identityRoot() == root
                && executor.governanceAction(replay).status == GovernanceActionStatus.SCHEDULED,
            "resolved cause cannot create another dismissal"
        );
    }

    function _fileContest() private {
        _setRole(ARBITER, address(governorSafe), true);
        (bytes32 scope, bytes32 old_, bytes32 next_) = contests.identityContestGovernanceContext(
            fixtureArtistId, 0, EVIDENCE, GOVERNANCE_REASON
        );
        _govern(
            _governanceRequest(
                1,
                address(artists),
                abi.encodeCall(
                    contests.contestArtistIdentity,
                    (fixtureArtistId, bytes32(0), EVIDENCE, GOVERNANCE_REASON)
                ),
                scope,
                old_,
                next_
            )
        );
        require(
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).status == 4,
            "actual contest entered"
        );
        Dismissal.Cause memory cause = dismissals.currentIdentityContestCause(fixtureArtistId);
        require(
            cause.facts.kind == 1
                && cause.facts.referenceHash == contests.latestIdentityContest(fixtureArtistId)
                && cause.facts.actor == address(executor)
                && cause.facts.incumbent == address(artistSafe) && cause.facts.priorStatus == 1
                && cause.facts.authorityClass == 1,
            "actual governed cause facts"
        );
        require(
            cause.causeHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_IDENTITY_CONTEST_CAUSE_V1"),
                        block.chainid,
                        address(artists),
                        artistSuite.owners[2],
                        cause.facts
                    )
                ),
            "independent actual cause commitment"
        );
    }

    function _terms() private view returns (Dismissal.Request memory) {
        return Dismissal.Request(
            fixtureArtistId,
            dismissals.currentIdentityContestCause(fixtureArtistId).causeHash,
            dismissals.latestIdentityContestDismissal(fixtureArtistId),
            keccak256("adjudicated current dismissal evidence"),
            GOVERNANCE_REASON,
            false,
            0
        );
    }

    function _request(Dismissal.Request memory terms, uint8 actionClass)
        private
        view
        returns (GovernanceActionRequest memory)
    {
        Dismissal.Context memory c = dismissals.identityContestDismissalContext(terms);
        require(
            c.scopeHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_SCOPE_V1"),
                        block.chainid,
                        address(artists),
                        artistSuite.owners[2],
                        fixtureArtistId
                    )
                ),
            "independent dismissal scope"
        );
        return _governanceRequest(
            actionClass,
            address(artists),
            abi.encodeCall(dismissals.dismissArtistIdentityContest, (terms)),
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
    }

    function _identityRoot() private view returns (bytes32) {
        return
            keccak256(abi.encode(IStreamArtistOwner(artistSuite.owners[2]).ownerStateSnapshotV2()));
    }

    function _expectFailure(bytes32 action, bytes memory data) private {
        bytes32 root = _identityRoot();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        require(
            _identityRoot() == root
                && dismissals.latestIdentityContestDismissal(fixtureArtistId) == 0
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED
                && IStreamArtistIdentityOwner(artistSuite.owners[2])
                .identity(fixtureArtistId)
                .status == 4,
            "failed dismissal preserves identity and action"
        );
    }

    function _assertDismissal(
        bytes32 action,
        GovernanceActionRequest memory request,
        Dismissal.Request memory terms
    ) private {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 record = dismissals.latestIdentityContestDismissal(fixtureArtistId);
        Dismissal.Record memory stored = dismissals.identityContestDismissalRecord(record);
        bytes32 evidenceId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(artists),
                address(artistCoordinator),
                uint16(58),
                address(executor),
                record
            )
        );
        bytes memory evidence =
            IStreamArtistArchiveV2(artistSuite.archive).artistEvidenceBytesV2(evidenceId, 1);
        (
            uint16 version,
            bytes32 configuration,
            uint16 operation,
            address actor,
            bytes32 result,
            T.Snapshot[7] memory before_,
            T.Snapshot[7] memory after_,
            bytes memory payload
        ) = abi.decode(
            evidence,
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            version == 1 && configuration == artistCoordinator.configurationHash()
                && operation == 58 && actor == address(executor) && result == record
                && after_[2].revision == before_[2].revision + 1
                && after_[2].stateRoot != before_[2].stateRoot,
            "exact archived Identity transition"
        );
        for (uint256 i; i < 7; ++i) {
            if (i != 2) {
                require(
                    before_[i].domainId == 0 && after_[i].domainId == 0,
                    "no invented other-owner snapshot"
                );
            }
        }
        (
            Dismissal.Request memory archivedTerms,
            Contest.GovernanceWitness memory witness,
            Dismissal.Cause memory cause,
            Dismissal.Context memory context,
            Dismissal.Record memory archived
        ) = abi.decode(
            payload,
            (
                Dismissal.Request,
                Contest.GovernanceWitness,
                Dismissal.Cause,
                Dismissal.Context,
                Dismissal.Record
            )
        );
        (bytes32 roleHash, uint64 roleRevision) = roles.roleMutationState(ARBITER);
        require(
            keccak256(abi.encode(archivedTerms)) == keccak256(abi.encode(terms))
                && keccak256(abi.encode(archived)) == keccak256(abi.encode(stored))
                && cause.causeHash == terms.expectedCauseHash && witness.actionId == action
                && witness.proposer == address(governorSafe)
                && witness.actionClass == request.actionClass
                && witness.roleMutationHash == roleHash && witness.roleRevision == roleRevision
                && witness.scopeHash == request.scopeHash
                && witness.oldValueHash == request.oldValueHash
                && witness.newValueHash == request.newValueHash
                && context.scopeHash == request.scopeHash
                && context.oldValueHash == request.oldValueHash
                && context.newValueHash == request.newValueHash
                && stored.governanceWitnessHash == keccak256(abi.encode(witness)),
            "exact stored current governance and per-call witness"
        );
        require(
            stored.executor == address(executor) && stored.proposer == address(governorSafe)
                && stored.actionId == action && stored.incumbent == address(artistSafe)
                && stored.authorityClass == 1 && stored.restoredStatus == 1
                && IStreamArtistIdentityOwner(artistSuite.owners[2])
                .identity(fixtureArtistId)
                .status == 1,
            "same incumbent restored by actual governor"
        );
        require(
            record
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_IDENTITY_DISMISSAL_RECORD_V1"),
                        block.chainid,
                        address(artists),
                        artistSuite.owners[2],
                        terms,
                        address(executor),
                        witness.proposer,
                        witness.actionClass,
                        witness.actionId,
                        stored.incumbent,
                        stored.authorityClass,
                        stored.restoredStatus,
                        stored.dismissedAt,
                        stored.cohortHash,
                        keccak256(abi.encode(witness))
                    )
                ),
            "independent primary dismissal record"
        );
        bytes32 topic = keccak256(
            "ArtistIdentityContestDismissed(uint16,bytes32,bytes32,bytes32,bytes32,address,address,uint8,bytes32,address,uint8,uint8,bytes32,bytes32,bool,bytes32,uint64,bytes32,bytes32,bytes32)"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == artistSuite.owners[2] && logs[i].topics.length == 4
                    && logs[i].topics[0] == topic
            ) {
                require(
                    logs[i].topics[1] == fixtureArtistId
                        && logs[i].topics[2] == terms.expectedCauseHash
                        && logs[i].topics[3] == record,
                    "exact Identity emitter and indexed dismissal fields"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                terms.expectedResolutionHash,
                                stored.executor,
                                stored.proposer,
                                stored.actionClass,
                                stored.actionId,
                                stored.incumbent,
                                stored.authorityClass,
                                stored.restoredStatus,
                                terms.evidenceHash,
                                terms.reasonHash,
                                terms.removePriorStanding,
                                terms.expectedRetirementHash,
                                stored.dismissedAt,
                                stored.cohortHash,
                                stored.governanceWitnessHash,
                                stored.revisionContinuationHead
                            )
                        ),
                    "exact dismissal event body"
                );
                ++found;
            }
        }
        require(found == 1, "one actual dismissal event");
        _safeRead(abi.encodeCall(dismissals.currentIdentityContestCause, (fixtureArtistId)));
        _safeRead(abi.encodeCall(dismissals.identityContestCause, (terms.expectedCauseHash)));
        _safeRead(abi.encodeCall(dismissals.identityContestDismissalRecord, (record)));
        _safeRead(abi.encodeCall(dismissals.latestIdentityContestDismissal, (fixtureArtistId)));
        _safeRead(
            abi.encodeCall(dismissals.identityTransitionClosure, (fixtureArtistId, bytes32(0)))
        );
        _safeRead(
            abi.encodeCall(
                dismissals.identityRevisionContinuation, (stored.revisionContinuationHead)
            )
        );
    }

    function _safeRead(bytes memory data) private {
        (bool ok, bytes memory expected) = address(artists).staticcall(data);
        vm.prank(address(governorSafe));
        (bool safeOk, bytes memory observed) = address(artists).staticcall(data);
        require(
            ok && safeOk && keccak256(expected) == keccak256(observed), "actual caller read parity"
        );
        this.executeCurrentGovernorCall(address(artists), data);
    }

    function _purchaseData(bytes32 nonce) private returns (bytes memory) {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            IStreamFixedPriceSaleAdapter.SaleAuthorization({
                collectionId: 1,
                phaseId: PHASE,
                payer: address(governorSafe),
                recipient: address(governorSafe),
                artist: address(artistSafe),
                profileId: profile,
                expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256("current dismissed artwork"),
                mintPolicyHash: manager.phasePolicyHash(1, PHASE),
                price: 0.01 ether,
                nonce: nonce,
                deadline: uint64(block.timestamp + 30 days),
                signerEpoch: sale.signerEpoch()
            });
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        return
            abi.encodeCall(
                sale.buy, (a, TOKEN_DATA, abi.encodePacked(r, s, v), _artistProof(digest))
            );
    }

    function executeCurrentPurchase(bytes calldata data) external {
        require(msg.sender == address(this), "test only");
        require(
            executeSafe(governorSafe, governorKeys, address(sale), 0.01 ether, data, 0),
            "actual Safe purchase"
        );
    }
}
