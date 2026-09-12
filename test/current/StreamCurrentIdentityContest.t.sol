// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityContest.sol";

/// @notice Actual Core, artist owners, Archive, roles, Executor and official Safe composition.
contract StreamCurrentIdentityContestTest is StreamCurrentSafeGovernanceFixture {
    OfficialSafe private artistSafe;
    uint256[] private keys;
    bytes32 private constant ARBITER = keccak256("ROLE_ATTRIBUTION_ARBITER");
    bytes32 private constant EVIDENCE = keccak256("current compromised identity evidence");
    IStreamArtistIdentityContest private contests;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 191);
        OfficialSafe governor = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 192);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(governor, keys);
        contests = IStreamArtistIdentityContest(address(artists));
        vm.deal(address(governorSafe), 1 ether);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function testSafeArbiterDelayedContestStopsNewMintAndPreservesHeldNFT() public {
        this.executeCurrentPurchase(_purchaseData(keccak256("first current contest mint")));
        uint256 token = core.lastAllocatedTokenId();
        require(
            core.ownerOf(token) == address(governorSafe) && wallet.balance == 0.01 ether,
            "actual paid mint before contest"
        );
        _setRole(ARBITER, address(governorSafe), true);
        bytes32 nextNonce = keccak256("blocked current contest mint");
        bytes memory nextPurchase = _purchaseData(nextNonce);
        GovernanceActionRequest memory request = _contestRequest(1);

        this.executeCurrentGovernorCall(
            address(artists),
            abi.encodeCall(
                contests.identityContestGovernanceContext,
                (fixtureArtistId, bytes32(0), EVIDENCE, GOVERNANCE_REASON)
            )
        );

        // Arbiter membership authorizes a staged proposal, never a direct facade call.
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeCurrentGovernorCall(address(artists), request.callData);
        vm.prank(vm.addr(keys[0]));
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, vm.addr(keys[0])));
        contests.contestArtistIdentity(fixtureArtistId, 0, EVIDENCE, GOVERNANCE_REASON);
        bytes32 action = _govern(request);
        _assertContest(action, request);

        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        artists.requireMintConsent(1, PHASE, request.scopeHash);
        uint256 balance = address(governorSafe).balance;
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeCurrentPurchase(nextPurchase);
        require(
            core.collectionMintedEver(1) == 1 && core.lastAllocatedTokenId() == token
                && wallet.balance == 0.01 ether && address(governorSafe).balance == balance
                && !sale.authorizationUsed(address(artistSafe), nextNonce),
            "contest denies already-signed mint with complete rollback"
        );
        this.executeCurrentGovernorCall(
            address(core),
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                address(governorSafe),
                address(artistSafe),
                token
            )
        );
        require(core.ownerOf(token) == address(artistSafe), "existing NFT remains transferable");
    }

    function testSafeContestAsSecondBatchCallUsesItsOwnContextAndFreshRole() public {
        require(!roles.hasRole(ARBITER, address(governorSafe)), "role initially absent");
        GovernanceActionRequest memory request = _contestRequest(1);
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        (calls[0], data[0]) = _roleCall(ARBITER, address(governorSafe), true);
        data[1] = request.callData;
        calls[1] = StreamCurrentStackPlan.call(
            address(artists), data[1], request.scopeHash, request.oldValueHash, request.newValueHash
        );
        (bytes32 action, uint64 ready) = _scheduleBatchAsGovernor(1, calls, data);
        GovernanceAction memory stored = executor.governanceAction(action);
        require(
            stored.target == address(roles) && stored.target != address(artists)
                && stored.scopeHash != request.scopeHash,
            "first-call header differs from contest context"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotExecutable.selector, action, ready
            )
        );
        executor.executeGovernanceBatch(action, calls, data);
        vm.warp(ready);
        this.executeCurrentGovernorCall(
            address(executor),
            abi.encodeCall(executor.executeGovernanceBatch, (action, calls, data))
        );
        require(roles.hasRole(ARBITER, address(governorSafe)), "preceding actual grant observed");
        _assertContest(action, request);
    }

    function testSafeTerminalClassContestUsesActualGuardianWindow() public {
        _setRole(ARBITER, address(governorSafe), true);
        GovernanceActionRequest memory request = _contestRequest(2);
        bytes32 action = _scheduleAsGovernor(request);
        require(
            roles.roleHolderCount(keccak256("ROLE_TERMINAL_FREEZE_VETO")) >= 2
                && executor.liveTerminalFreezeActionCount(request.scopeHash) == 1,
            "actual independent guardian window indexed"
        );
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
        _assertContest(action, request);
        require(
            executor.liveTerminalFreezeActionCount(request.scopeHash) == 0,
            "completed window pruned"
        );
    }

    function testSafeArbiterRoleLossAndWrongReasonRejectWithoutConsumingContest() public {
        _setRole(ARBITER, address(governorSafe), true);
        uint256 checkpoint = vm.snapshotState();
        GovernanceActionRequest memory request = _contestRequest(1);
        bytes32 root = _identityRoot();
        request.reasonHash = keccak256("does not match contest reason");
        bytes32 badAction = _scheduleAsGovernor(request);
        vm.warp(request.notBefore);
        _expectActionFailure(badAction, request.callData, root);
        request = _contestRequest(1);
        _assertContest(_govern(request), request);
        require(vm.revertToState(checkpoint), "restore independent negative scenario");

        request = _contestRequest(1);
        bytes32 action = _scheduleAsGovernor(request);
        root = _identityRoot();
        _setRole(ARBITER, address(governorSafe), false);
        _expectActionFailure(action, request.callData, root);
        _setRole(ARBITER, address(governorSafe), true);
        require(block.timestamp <= request.expiresAfter, "same action remains live");
        _executeAsGovernor(action, request.callData);
        _assertContest(action, request);
    }

    function _expectActionFailure(bytes32 action, bytes memory data, bytes32 root) private {
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        require(
            _identityRoot() == root && contests.latestIdentityContest(fixtureArtistId) == 0
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "failed attempt preserves owner state and scheduled action"
        );
    }

    function _contestRequest(uint8 actionClass)
        private
        view
        returns (GovernanceActionRequest memory)
    {
        (bytes32 scope, bytes32 oldState, bytes32 newState) = contests.identityContestGovernanceContext(
            fixtureArtistId, 0, EVIDENCE, GOVERNANCE_REASON
        );
        return _governanceRequest(
            actionClass,
            address(artists),
            abi.encodeCall(
                contests.contestArtistIdentity,
                (fixtureArtistId, bytes32(0), EVIDENCE, GOVERNANCE_REASON)
            ),
            scope,
            oldState,
            newState
        );
    }

    function _identityRoot() private view returns (bytes32) {
        return
            keccak256(abi.encode(IStreamArtistOwner(artistSuite.owners[2]).ownerStateSnapshotV2()));
    }

    function _assertContest(bytes32 action, GovernanceActionRequest memory request) private {
        bytes32 record = contests.latestIdentityContest(fixtureArtistId);
        _assertContestEvent(record);
        Contest.Record memory stored = contests.identityContestRecord(record);
        bytes32 expected = keccak256(
            abi.encode(
                bytes32(0x26a4221cd1625ab88b1ac279e1708a73efa176e486242b26832cdc94fe25e6bb),
                block.chainid,
                address(artists),
                fixtureArtistId,
                address(executor),
                bytes32(0),
                EVIDENCE,
                GOVERNANCE_REASON,
                uint64(block.timestamp)
            )
        );
        T.Identity memory principal =
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId);
        require(
            record == expected && stored.recordHash == record
                && stored.contester == address(executor) && stored.priorStatus == 1
                && principal.status == 4 && principal.authorityAddress == address(artistSafe),
            "exact contest and unchanged incumbent"
        );
        bytes32 evidenceId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(artists),
                address(artistCoordinator),
                uint16(33),
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
                && operation == 33 && actor == address(executor) && result == record
                && after_[2].revision == before_[2].revision + 1
                && after_[2].stateRoot != before_[2].stateRoot,
            "actual archived sole-owner transition"
        );
        (
            Contest.Request memory terms,
            Contest.GovernanceWitness memory witness,
            Contest.Record memory archived
        ) = abi.decode(payload, (Contest.Request, Contest.GovernanceWitness, Contest.Record));
        (bytes32 roleHash, uint64 roleRevision) = roles.roleMutationState(ARBITER);
        require(
            terms.artistId == fixtureArtistId && terms.subjectRecordHash == 0
                && terms.evidenceHash == EVIDENCE && terms.reasonHash == GOVERNANCE_REASON
                && keccak256(abi.encode(archived)) == keccak256(abi.encode(stored))
                && witness.actionId == action && witness.proposer == address(governorSafe)
                && witness.actionClass == request.actionClass
                && witness.scopeHash == request.scopeHash
                && witness.oldValueHash == request.oldValueHash
                && witness.newValueHash == request.newValueHash
                && witness.roleMutationHash == roleHash && witness.roleRevision == roleRevision
                && stored.governanceWitnessHash == keccak256(abi.encode(witness)),
            "archived witness binds actual proposer, current role and exact per-call commitments"
        );
        for (uint256 i; i < 7; ++i) {
            if (i != 2) {
                require(
                    before_[i].domainId == 0 && after_[i].domainId == 0,
                    "no invented other-owner snapshots"
                );
            }
        }
        this.executeCurrentGovernorCall(
            address(artists), abi.encodeCall(contests.latestIdentityContest, (fixtureArtistId))
        );
        this.executeCurrentGovernorCall(
            address(artists), abi.encodeCall(contests.identityContestRecord, (record))
        );
    }

    function _assertContestEvent(bytes32 record) private {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "ArtistIdentityContested(uint16,bytes32,address,bytes32,bytes32,bytes32,uint64,bytes32)"
        );
        uint256 observed;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == artistSuite.owners[2] && logs[i].topics.length == 3
                    && logs[i].topics[0] == topic
            ) {
                require(
                    logs[i].topics[1] == fixtureArtistId
                        && logs[i].topics[2] == bytes32(uint256(uint160(address(executor))))
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint16(1),
                                    bytes32(0),
                                    EVIDENCE,
                                    GOVERNANCE_REASON,
                                    uint64(block.timestamp),
                                    record
                                )
                            ),
                    "canonical owner event fields"
                );
                ++observed;
            }
        }
        require(observed == 1, "one actual owner contest event");
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
                mintCommitment: keccak256("current contest artwork"),
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
