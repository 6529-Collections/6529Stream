// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentMintPolicyGraceFixture.sol";

interface CurrentGraceVm {
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @notice Actual current authority and original Safe tickets through public policy-grace rotation.
/// @dev Requires the additive selector's real class-1 current deployment catalog row.
contract StreamCurrentMintPolicyGraceTest is CurrentMintPolicyGraceFixture {
    function testActualArtistConsentRepairsIdenticalGovernorTransactionAndOldSafeTicketMints()
        public
    {
        (
            IStreamMintManager.MintBatch memory batch,
            StreamMintTicketTypes.MintTicket memory ticket
        ) = _graceRequest(1, graceMintSafe);
        bytes memory proof = _graceProof(ticket);
        bytes memory mintCall = _graceMintCall(batch, proof, false);
        bytes memory mintSignature = _graceSafeSignature(graceMintSafe, address(manager), mintCall);
        bytes32 nextPolicy = _gracePolicy(_graceExecutors(2));
        uint64 deadline = uint64(block.timestamp + 7 days);
        GovernanceActionRequest memory request =
            _rotationRequest(address(graceNextSafe), true, deadline);
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
        bytes memory executeCall =
            abi.encodeCall(executor.executeGovernanceAction, (action, request.callData));
        bytes memory governorSignature =
            _graceSafeSignature(governorSafe, address(executor), executeCall);
        _graceSafeFailure(governorSafe, address(executor), executeCall, governorSignature);
        require(
            !manager.phaseExecutor(1, GRACE_PHASE, address(graceNextSafe))
                && manager.phasePolicyHash(1, GRACE_PHASE) == batch.expectedPolicyHash,
            "missing actual Artist consent rolls back executor and policy"
        );
        (bytes32 previous,, uint64 previousDeadline) =
            ledger.policyGrace(address(manager), 1, GRACE_PHASE);
        require(previous == 0 && previousDeadline == 0, "failed registration creates no grace");
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "same scheduled action can retry"
        );

        _recordFixturePolicy(GRACE_PHASE, nextPolicy);
        vm.recordLogs();
        require(
            _graceSafeCall(governorSafe, address(executor), executeCall, governorSignature),
            "identical signed Governor call succeeds after consent"
        );
        _assertGraceEvent(vm.getRecordedLogs(), batch.expectedPolicyHash, nextPolicy, deadline);
        require(
            executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "real delayed action executed"
        );
        _assertGrace(batch.expectedPolicyHash, 2, deadline);
        require(
            nextPolicy != batch.expectedPolicyHash
                && manager.phasePolicyHash(1, GRACE_PHASE) == nextPolicy,
            "caller-bound predecessor remains distinct"
        );
        vm.prank(address(graceMintSafe));
        (bytes32 preview,) = manager.previewSingleStepMintOperation(batch, proof);
        bytes32 root = _graceMint(batch, proof, false, graceMintSafe, mintSignature);
        require(
            root == preview && core.ownerOf(1) == address(graceMintSafe)
                && ledger.counterValue(_graceCounterKey(graceMintSafe)) == 1,
            "old original ticket delivers under current policy"
        );
        vm.prank(address(graceMintSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, batch.authorizationId
            )
        );
        manager.executeSingleStepMint(batch, proof);
        (, uint256 requestId) = entropy.requestEntropy(1);
        provider.fulfill(requestId, keccak256("grace ticket entropy"));
        (, bool finalized) = entropy.tokenSeed(1);
        require(finalized && bytes(core.tokenURI(1)).length != 0, "actual Coordinator reveal");
    }

    function testInclusiveDeadlineMintsAndUnchangedOldTicketRejectsAfterDeadline() public {
        (
            IStreamMintManager.MintBatch memory atDeadline,
            StreamMintTicketTypes.MintTicket memory atTicket
        ) = _graceRequest(2, graceMintSafe);
        (
            IStreamMintManager.MintBatch memory afterDeadline,
            StreamMintTicketTypes.MintTicket memory afterTicket
        ) = _graceRequest(3, graceMintSafe);
        bytes memory atProof = _graceProof(atTicket);
        bytes memory afterProof = _graceProof(afterTicket);
        bytes32 proofHash = keccak256(afterProof);
        uint64 deadline = uint64(block.timestamp + 7 days);
        bytes32 current = _rotateGrace(address(graceNextSafe), true, _graceExecutors(2), deadline);
        vm.warp(deadline);
        bytes memory atCall = _graceMintCall(atDeadline, atProof, false);
        _graceMint(
            atDeadline,
            atProof,
            false,
            graceMintSafe,
            _graceSafeSignature(graceMintSafe, address(manager), atCall)
        );
        vm.prank(address(graceMintSafe));
        manager.previewSingleStepMintOperation(afterDeadline, afterProof);
        bytes memory afterCall = _graceMintCall(afterDeadline, afterProof, false);
        bytes memory afterSignature =
            _graceSafeSignature(graceMintSafe, address(manager), afterCall);
        vm.warp(deadline + 1);
        require(block.timestamp < afterTicket.deadline, "ticket itself is still unexpired");
        vm.prank(address(graceMintSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintPolicyHashMismatch.selector,
                afterDeadline.expectedPolicyHash,
                current
            )
        );
        manager.previewSingleStepMintOperation(afterDeadline, afterProof);
        _graceSafeFailure(graceMintSafe, address(manager), afterCall, afterSignature);
        require(
            keccak256(afterProof) == proofHash
                && !manager.isAuthorizationUsed(afterDeadline.authorizationId)
                && core.totalSupply() == 1 && manager.nextOperationNonce() == 1
                && ledger.counterValue(_graceCounterKey(graceMintSafe)) == 1,
            "expired grace consumes nothing from unchanged signed ticket"
        );
        (
            IStreamMintManager.MintBatch memory currentBatch,
            StreamMintTicketTypes.MintTicket memory currentTicket
        ) = _graceRequest(4, graceMintSafe);
        bytes memory currentProof = _graceProof(currentTicket);
        bytes memory currentCall = _graceMintCall(currentBatch, currentProof, true);
        _graceMint(
            currentBatch,
            currentProof,
            true,
            graceMintSafe,
            _graceSafeSignature(graceMintSafe, address(manager), currentCall)
        );
        require(
            core.totalSupply() == 2 && ledger.counterValue(_graceCounterKey(graceMintSafe)) == 2,
            "current policy still mints after predecessor expires"
        );
    }

    function testTwoActualDelayedGovernorRotationsRetainOnlyImmediatePredecessorAndCurrentCap()
        public
    {
        (
            IStreamMintManager.MintBatch memory oldest,
            StreamMintTicketTypes.MintTicket memory oldestTicket
        ) = _graceRequest(5, graceMintSafe);
        bytes memory oldestProof = _graceProof(oldestTicket);
        uint64 firstDeadline = uint64(block.timestamp + 10 days);
        bytes32 middlePolicy =
            _rotateGrace(address(graceNextSafe), true, _graceExecutors(2), firstDeadline);
        _assertGrace(oldest.expectedPolicyHash, 2, firstDeadline);
        (
            IStreamMintManager.MintBatch memory middle,
            StreamMintTicketTypes.MintTicket memory middleTicket
        ) = _graceRequest(6, graceMintSafe);
        bytes memory middleProof = _graceProof(middleTicket);
        uint64 secondDeadline = uint64(block.timestamp + 10 days);
        bytes32 current =
            _rotateGrace(address(graceThirdSafe), true, _graceExecutors(3), secondDeadline);
        _assertGrace(middlePolicy, 3, secondDeadline);
        require(block.timestamp < firstDeadline, "oldest discarded before its former deadline");
        vm.prank(address(graceMintSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintPolicyHashMismatch.selector,
                oldest.expectedPolicyHash,
                current
            )
        );
        manager.previewSingleStepMintOperation(oldest, oldestProof);
        bytes memory middleCall = _graceMintCall(middle, middleProof, true);
        _graceMint(
            middle,
            middleProof,
            true,
            graceMintSafe,
            _graceSafeSignature(graceMintSafe, address(manager), middleCall)
        );
        (
            IStreamMintManager.MintBatch memory latest,
            StreamMintTicketTypes.MintTicket memory latestTicket
        ) = _graceRequest(7, graceMintSafe);
        bytes memory latestProof = _graceProof(latestTicket);
        bytes memory latestCall = _graceMintCall(latest, latestProof, false);
        _graceMint(
            latest,
            latestProof,
            false,
            graceMintSafe,
            _graceSafeSignature(graceMintSafe, address(manager), latestCall)
        );
        require(
            ledger.counterValue(_graceCounterKey(graceMintSafe)) == 2,
            "old and current tickets share current counter accounting"
        );
        latestTicket.nonce = bytes32(uint256(8));
        latest.authorizationId = manager.mintTicketAuthorizationId(latestTicket, address(graceGate));
        latestProof = _graceProof(latestTicket);
        latestCall = _graceMintCall(latest, latestProof, false);
        bytes32 capKey = _graceCounterKey(graceMintSafe);
        vm.prank(address(graceMintSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintCounterCapExceeded.selector, capKey, uint256(3), uint256(2)
            )
        );
        manager.previewSingleStepMintOperation(latest, latestProof);
        _graceSafeFailure(
            graceMintSafe,
            address(manager),
            latestCall,
            _graceSafeSignature(graceMintSafe, address(manager), latestCall)
        );
        require(
            core.totalSupply() == 2 && !manager.isAuthorizationUsed(latest.authorizationId),
            "third mint exceeds unchanged current cap without replay debit"
        );
    }

    function testRemovedExecutorCannotUseLivePredecessorButRemainingSafeCan() public {
        uint64 deadline = uint64(block.timestamp + 10 days);
        _rotateGrace(address(graceNextSafe), true, _graceExecutors(2), deadline);
        (
            IStreamMintManager.MintBatch memory removed,
            StreamMintTicketTypes.MintTicket memory removedTicket
        ) = _graceRequest(9, graceMintSafe);
        (
            IStreamMintManager.MintBatch memory retained,
            StreamMintTicketTypes.MintTicket memory retainedTicket
        ) = _graceRequest(10, graceNextSafe);
        bytes memory removedProof = _graceProof(removedTicket);
        bytes memory retainedProof = _graceProof(retainedTicket);
        address[] memory remaining = new address[](1);
        remaining[0] = address(graceNextSafe);
        deadline = uint64(block.timestamp + 10 days);
        _rotateGrace(address(graceMintSafe), false, remaining, deadline);
        _assertGrace(removed.expectedPolicyHash, 3, deadline);
        vm.prank(address(graceMintSafe));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.UnauthorizedMintExecutor.selector,
                uint256(1),
                GRACE_PHASE,
                address(graceMintSafe)
            )
        );
        manager.previewSingleStepMintOperation(removed, removedProof);
        bytes memory removedCall = _graceMintCall(removed, removedProof, false);
        _graceSafeFailure(
            graceMintSafe,
            address(manager),
            removedCall,
            _graceSafeSignature(graceMintSafe, address(manager), removedCall)
        );
        require(
            !manager.phaseExecutor(1, GRACE_PHASE, address(graceMintSafe))
                && !manager.isAuthorizationUsed(removed.authorizationId),
            "live predecessor does not restore removed executor"
        );
        bytes memory retainedCall = _graceMintCall(retained, retainedProof, false);
        _graceMint(
            retained,
            retainedProof,
            false,
            graceNextSafe,
            _graceSafeSignature(graceNextSafe, address(manager), retainedCall)
        );
        require(
            core.ownerOf(1) == address(graceNextSafe) && graceMintSafe.nonce() == 0
                && graceNextSafe.nonce() == 1,
            "remaining actual Safe retains its original ticket authority"
        );
    }

    function testLatePreparedDeliveryUnderGraceRollsBackAndExactSignedSafeBatchRetries() public {
        CurrentGraceRecipient recipient = new CurrentGraceRecipient();
        (IStreamMintManager.MintBatch memory batch,) = _graceRequest(11, graceMintSafe);
        batch.initialRecipients = new address[](2);
        batch.initialRecipients[0] = address(graceMintSafe);
        batch.initialRecipients[1] = address(recipient);
        batch.beneficiaries = new address[](2);
        batch.beneficiaries[0] = address(graceMintSafe);
        batch.beneficiaries[1] = address(graceMintSafe);
        batch.tokenData = new bytes[](2);
        batch.tokenData[0] = TOKEN_DATA;
        batch.tokenData[1] = bytes("second predecessor ticket artwork");
        batch.mintCommitments = new bytes32[](2);
        batch.mintCommitments[0] = keccak256("first predecessor commitment");
        batch.mintCommitments[1] = keccak256("second predecessor commitment");
        StreamMintTicketTypes.MintTicket memory ticket = _graceTicket(batch, graceMintSafe, 11);
        batch.authorizationId = manager.mintTicketAuthorizationId(ticket, address(graceGate));
        bytes memory proof = _graceProof(ticket);
        bytes memory data = _graceMintCall(batch, proof, true);
        bytes memory signature = _graceSafeSignature(graceMintSafe, address(manager), data);
        uint64 deadline = uint64(block.timestamp + 7 days);
        _rotateGrace(address(graceNextSafe), true, _graceExecutors(2), deadline);
        CurrentGraceVm(address(vm))
            .expectCall(
                address(recipient), abi.encodePacked(recipient.onERC721Received.selector), 2
            );
        vm.recordLogs();
        _graceSafeFailure(graceMintSafe, address(manager), data, signature);
        // Foundry retains reverted trace logs. This locates the failed operation, not a committed receipt.
        bytes32 preview = _failedGraceRoot(vm.getRecordedLogs());
        require(
            core.totalSupply() == 0 && core.collectionMintedEver(1) == 0
                && core.lastAllocatedTokenId() == 0 && core.pendingPreparedMintTokenId() == 0
                && !core.preparedMint(1).exists && !core.preparedMint(2).exists
                && manager.nextOperationNonce() == 0 && !manager.isOperationRootUsed(preview)
                && !manager.isAuthorizationUsed(batch.authorizationId)
                && ledger.counterValue(_graceCounterKey(graceMintSafe)) == 0,
            "second delivery restores whole first token, preparation, root, replay and cap"
        );
        _assertGrace(batch.expectedPolicyHash, 2, deadline);
        recipient.accept();
        bytes32 root = _graceMint(batch, proof, true, graceMintSafe, signature);
        require(
            root == preview && core.ownerOf(1) == address(graceMintSafe)
                && core.ownerOf(2) == address(recipient) && manager.nextOperationNonce() == 2
                && graceMintSafe.nonce() == 1
                && ledger.counterValue(_graceCounterKey(graceMintSafe)) == 2
                && keccak256(core.tokenData(2)) == keccak256(batch.tokenData[1]),
            "byte-identical original signed Safe batch succeeds after external recipient repair"
        );
    }

    function _failedGraceRoot(Vm.Log[] memory logs) private view returns (bytes32 root) {
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(ledger) && logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256(
                            "MintLedgerOperationRootConsumed(uint16,bytes32,address,bytes32,bytes32,bytes32)"
                        )
            ) {
                require(root == 0, "one attempted batch root");
                root = logs[i].topics[1];
            }
        }
        require(root != 0, "attempt reached Ledger before external receiver failure");
    }

    function _assertGraceEvent(
        Vm.Log[] memory logs,
        bytes32 oldPolicy,
        bytes32 newPolicy,
        uint64 deadline
    ) private view {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(ledger) && logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256(
                            "MintLedgerPolicyGraceSet(uint16,uint256,bytes32,address,bytes32,bytes32,uint64)"
                        )
            ) {
                ++count;
                require(
                    uint256(logs[i].topics[1]) == 1 && logs[i].topics[2] == GRACE_PHASE
                        && address(uint160(uint256(logs[i].topics[3]))) == address(manager)
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), oldPolicy, newPolicy, deadline)),
                    "complete original Ledger grace event"
                );
            }
        }
        require(count == 1, "one grace registration event");
    }
}
