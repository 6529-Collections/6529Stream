// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentDelegatedMintGraceFixture.sol";

interface DelegatedGraceVm {
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @notice Mode2 original Artist records reach Manager registration, grace and actual Safe minting.
contract StreamCurrentDelegatedMintGraceTest is CurrentDelegatedMintGraceFixture {
    struct SavedMint {
        IStreamMintManager.MintBatch batch;
        bytes proof;
        bytes data;
        bytes signature;
    }

    function _save(uint256 nonce) private returns (SavedMint memory s) {
        StreamMintTicketTypes.MintTicket memory ticket;
        (s.batch, ticket) = _graceRequest(nonce, graceMintSafe);
        s.proof = _graceProof(ticket);
        s.data = _graceMintCall(s.batch, s.proof, false);
        s.signature = _graceSafeSignature(graceMintSafe, address(manager), s.data);
    }

    function _mintSaved(SavedMint memory s) private {
        _graceMint(s.batch, s.proof, false, graceMintSafe, s.signature);
        require(core.ownerOf(1) == address(graceMintSafe), "actual original NFT delivered");
        require(
            artists.delegationRecord(graceConsentGrant).uses == 3
                && delegatedConsentSafe.nonce() == 0,
            "registration and mint never consume another delegated signature use"
        );
    }

    function _consentEvent(Vm.Log[] memory logs, bytes32 policy) private view {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(manager) && logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256(
                            "MintPhaseConsentRecorded(uint16,uint256,bytes32,bytes32,uint8,bytes32)"
                        )
            ) {
                ++count;
                require(
                    uint256(logs[i].topics[1]) == 1 && logs[i].topics[2] == GRACE_PHASE
                        && logs[i].topics[3] == policy
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(uint16(1), uint8(2), delegatedPolicyRecords[policy])
                            ),
                    "original Manager event retains exact mode2 Artist record"
                );
            }
        }
        require(count == 1, "one exact mode2 registration receipt");
    }

    function _applyRecordedRotation(bytes32 policy, uint64 deadline) private {
        GovernanceActionRequest memory r = _rotationRequest(address(graceNextSafe), true, deadline);
        bytes32 action = _scheduleAsGovernor(r);
        vm.warp(r.notBefore);
        bytes memory data = abi.encodeCall(executor.executeGovernanceAction, (action, r.callData));
        bytes memory signature = _graceSafeSignature(governorSafe, address(executor), data);
        vm.recordLogs();
        require(
            _graceSafeCall(governorSafe, address(executor), data, signature),
            "real Governor rotation"
        );
        _consentEvent(vm.getRecordedLogs(), policy);
        require(
            manager.phasePolicyHash(1, GRACE_PHASE) == policy, "registered exact recorded policy"
        );
        artists.requireMintConsent(1, GRACE_PHASE, policy);
    }

    function testActualDelegatedPolicyRegistrationGraceAndOriginalTicketMint() public {
        SavedMint memory s = _save(4201);
        require(artists.consentMode(1) == 2, "actual accepted mode2 binding");
        require(
            delegatedPolicyRecords[s.batch.expectedPolicyHash] != 0
                && artists.delegationRecord(graceConsentGrant).uses == 2,
            "initial configure and executor registration consumed actual delegated records"
        );
        bytes32 next = _gracePolicy(_graceExecutors(2));
        _recordGracePolicy(next);
        uint64 deadline = uint64(block.timestamp + 7 days);
        _applyRecordedRotation(next, deadline);
        _assertGrace(s.batch.expectedPolicyHash, 2, deadline);
        require(next != s.batch.expectedPolicyHash, "original ticket keeps predecessor policy");
        _mintSaved(s);
        require(ledger.counterValue(_graceCounterKey(graceMintSafe)) == 1, "original cap debit");
    }

    function testGrantRevokedAfterRecordingStillRegistersGraceAndMintsButCannotRecordAnotherPolicy()
        public
    {
        SavedMint memory s = _save(4202);
        bytes32 next = _gracePolicy(_graceExecutors(2));
        _recordGracePolicy(next);
        bytes32 originalRecord = delegatedPolicyRecords[next];
        _revokeGraceGrant();
        bytes32 forbidden = _gracePolicy(_graceExecutors(3));
        T.Authorization memory a = _delegatedPolicyAuthorization(forbidden);
        vm.expectRevert(abi.encodeWithSelector(D.DelegationUnavailable.selector, graceConsentGrant));
        IStreamArtistDelegatedConsent(address(artists))
            .recordDelegatedPolicyConsent(
                T.PolicyConsent(1, GRACE_PHASE, forbidden), graceConsentGrant, a
            );
        (bool absent, bytes32 missing) = artists.isPolicyConsented(1, GRACE_PHASE, forbidden);
        require(!absent && missing == 0, "revoked grant creates no new exact record");
        uint64 deadline = uint64(block.timestamp + 7 days);
        _applyRecordedRotation(next, deadline);
        _assertGrace(s.batch.expectedPolicyHash, 2, deadline);
        (bool consented, bytes32 record) = artists.isPolicyConsented(1, GRACE_PHASE, next);
        require(
            consented && record == originalRecord,
            "recorded consent remains durable after revocation"
        );
        _mintSaved(s);
    }

    function testStaleDelegatedPolicyRollsBackGovernorActionAndExactSignedRetryNeedsNewRecord()
        public
    {
        bytes32 previous = manager.phasePolicyHash(1, GRACE_PHASE);
        bytes32 wrong = _gracePolicy(_graceExecutors(3));
        _recordGracePolicy(wrong);
        bytes32 next = _gracePolicy(_graceExecutors(2));
        require(wrong != next, "different real executor policy is not consent for requested policy");
        (bool consented, bytes32 evidence) = artists.isPolicyConsented(1, GRACE_PHASE, next);
        require(!consented && evidence == 0, "no exact new policy record");
        uint64 deadline = uint64(block.timestamp + 7 days);
        GovernanceActionRequest memory r = _rotationRequest(address(graceNextSafe), true, deadline);
        bytes32 action = _scheduleAsGovernor(r);
        vm.warp(r.notBefore);
        bytes memory data = abi.encodeCall(executor.executeGovernanceAction, (action, r.callData));
        bytes memory signature = _graceSafeSignature(governorSafe, address(executor), data);
        // Failed registration, exact-record readback after repair, and successful retry.
        DelegatedGraceVm(address(vm))
            .expectCall(
                address(artists),
                abi.encodeCall(artists.isPolicyConsented, (1, GRACE_PHASE, next)),
                3
            );
        _graceSafeFailure(governorSafe, address(executor), data, signature);
        require(
            manager.phasePolicyHash(1, GRACE_PHASE) == previous
                && !manager.phaseExecutor(1, GRACE_PHASE, address(graceNextSafe))
                && ledger.registeredPhasePolicyHash(address(manager), 1, GRACE_PHASE) == previous
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED
                && core.totalSupply() == 0 && manager.nextOperationNonce() == 0
                && artists.delegationRecord(graceConsentGrant).uses == 3,
            "stale consent changes no Manager, Ledger, governance, Core or grant state"
        );
        (bytes32 old, uint64 revision, uint64 until) =
            ledger.policyGrace(address(manager), 1, GRACE_PHASE);
        require(
            old == 0 && revision == 1 && until == 0, "failed rotation creates no grace revision"
        );
        _recordGracePolicy(next);
        vm.recordLogs();
        require(
            _graceSafeCall(governorSafe, address(executor), data, signature),
            "identical signed retry"
        );
        _consentEvent(vm.getRecordedLogs(), next);
        _assertGrace(previous, 2, deadline);
        require(
            artists.delegationRecord(graceConsentGrant).uses == 4,
            "only original Artist writes consume uses"
        );
    }

    function testDelegatedGraceLatePreparedDeliveryRollsBackAndExactSignedSafeBatchRetries()
        public
    {
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
        DelegatedGraceVm(address(vm))
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
        require(
            artists.delegationRecord(graceConsentGrant).uses == 3,
            "failed mint never rewrites delegated consent"
        );
        _assertGrace(batch.expectedPolicyHash, 2, deadline);
        _revokeGraceGrant();
        recipient.accept();
        bytes32 root = _graceMint(batch, proof, true, graceMintSafe, signature);
        require(
            root == preview && core.ownerOf(1) == address(graceMintSafe)
                && core.ownerOf(2) == address(recipient) && manager.nextOperationNonce() == 2
                && graceMintSafe.nonce() == 1
                && ledger.counterValue(_graceCounterKey(graceMintSafe)) == 2
                && keccak256(core.tokenData(2)) == keccak256(batch.tokenData[1]),
            "original signed Safe batch retries with durable consent after external repair and grant revocation"
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
}
