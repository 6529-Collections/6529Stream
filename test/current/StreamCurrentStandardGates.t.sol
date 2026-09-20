// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentStandardGateFixture.sol";

/// @notice Authored current-stack joins for original eligibility gates and Merkle counter resolution.
/// @dev No receipt-only Core/Manager replacement; native execution remains a separate gate.
contract StreamCurrentStandardGatesTest is CurrentStandardGateFixture {
    function setUp() public {
        _constructStandardGates();
    }

    function testOriginalGatesAndMerkleDefinitionsShareCurrentManagerLedgerAndSafeConsent()
        public
        view
    {
        require(
            address(manager.core()) == address(core)
                && address(manager.mintLedger()) == address(ledger)
                && manager.owner() == address(executor) && ledger.ledgerWriter(address(manager)),
            "actual canonical mint graph"
        );
        for (uint8 i; i < 3; ++i) {
            IStreamMintManager.MintGateConfig memory gate = manager.phaseGate(1, _gatePhase(i));
            require(
                gate.gate == _gate(i) && gate.gateCodehash == _gate(i).codehash
                    && gate.gateMetadataHash
                        == keccak256(abi.encode(_gateVersion(i), _gateManifest(i))),
                "actual admitted gate pin"
            );
            (bool exists, IStreamMintCounterPolicy.Definition memory definition) =
                ledger.counterDefinitionForManager(address(manager), definitionHashes[i]);
            require(
                exists && definition.capRoot == _root(i)
                    && definition.scope == IStreamMintCounterPolicy.CounterScope.PHASE
                    && definition.keyMode == IStreamMintManager.CounterKeyMode.RECIPIENT,
                "actual retained counter definition"
            );
            IStreamMintLedger.LedgerCounterPolicy memory policy =
                ledger.registeredCounterPolicy(address(manager), 1, _gatePhase(i), ALLOCATION);
            require(
                policy.enabled && policy.capMode == IStreamMintLedger.CounterCapMode.MERKLE_STATIC
                    && policy.staticCap == 3 && policy.counterConfigHash == definitionHashes[i],
                "actual Ledger cap policy"
            );
            artists.requireMintConsent(1, _gatePhase(i), manager.phasePolicyHash(1, _gatePhase(i)));
        }
    }

    function testAllowlistDebitsEachBeneficiarySeparatelyFromDeliveryPayerAndExecutor() public {
        IStreamMintManager.MintBatch memory b =
            _gateBatch(ALLOW, 1, address(gateVault), address(gateVault), 2);
        b.initialRecipients[1] = address(gateCaller);
        b.beneficiaries[1] = address(faultyRecipient);
        b.resolverData = _resolver(ALLOW, b.beneficiaries);
        (bytes memory proof, bytes32 nullifier) = _authorizeGate(ALLOW, b, bytes32(uint256(1)));
        _mintAndCheck(ALLOW, b, proof, nullifier, false);
        require(
            core.ownerOf(1) == address(gateVault) && core.ownerOf(2) == address(gateCaller)
                && ledger.counterValue(_gateValueKey(b, address(gateVault))) == 1
                && ledger.counterValue(_gateValueKey(b, address(faultyRecipient))) == 1
                && ledger.counterValue(_gateValueKey(b, BUYER)) == 0
                && ledger.counterValue(_gateValueKey(b, address(gateCaller))) == 0,
            "delivery never replaces allowlist accounting subject"
        );
    }

    function testAllowlistWrongProofWalletAndPhaseLeaveOriginalRequestUsable() public {
        IStreamMintManager.MintBatch memory b =
            _gateBatch(ALLOW, 2, address(gateVault), address(gateVault), 1);
        (bytes memory proof, bytes32 nullifier) = _authorizeGate(ALLOW, b, bytes32(uint256(2)));
        IStreamMintManager.MintBatch memory bad = _copy(b);
        bad.resolverData = _brokenProof(b.resolverData);
        _fail(bad, proof, false);
        _assertGateUnused(b, nullifier);
        bad = _copy(b);
        bad.beneficiaries[0] = BUYER;
        _fail(bad, proof, false);
        _assertGateUnused(b, nullifier);
        bad = _copy(b);
        bad.phaseId = _gatePhase(DELEGATE);
        _fail(bad, proof, false);
        _assertGateUnused(b, nullifier);
        _mintAndCheck(ALLOW, b, proof, nullifier, false);
    }

    function testAllowlistAuthorizationAndNonceReplaysFailInOriginalLedger() public {
        _replay(ALLOW);
    }

    function testAllowlistRepeatedSubjectCannotExceedAggregateProofCap() public {
        IStreamMintManager.MintBatch memory first =
            _gateBatch(ALLOW, 3, address(gateVault), address(gateVault), 2);
        (bytes memory proof, bytes32 nullifier) = _authorizeGate(ALLOW, first, bytes32(uint256(3)));
        _mintAndCheck(ALLOW, first, proof, nullifier, false);
        IStreamMintManager.MintBatch memory second =
            _gateBatch(ALLOW, 4, address(gateVault), address(gateVault), 2);
        (proof, nullifier) = _authorizeGate(ALLOW, second, bytes32(uint256(4)));
        bytes32 key = _gateValueKey(second, address(gateVault));
        vm.prank(address(gateCaller));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.CounterCapExceeded.selector, key, uint256(4), uint256(3)
            )
        );
        manager.executeSingleStepMint(second, proof);
        _fail(second, proof, false);
        require(
            ledger.counterValue(key) == 2 && core.totalSupply() == 2 && gateCaller.nonce() == 1
                && !manager.isAuthorizationUsed(second.authorizationId)
                && !manager.isNullifierUsed(nullifier),
            "projected cap rejection commits no later accounting"
        );
    }

    function testAllowlistLatePreparedReceiverFailureRestoresAllStateAndIdenticalSafeRetry()
        public
    {
        _lateFailure(ALLOW);
    }

    function testDelegateVaultSafeGrantMintsToVaultAndUsesVaultMerkleSubject() public {
        _vaultGrant(BUYER, delegateGate.collectionDelegationRights(1), true);
        IStreamMintManager.MintBatch memory b =
            _gateBatch(DELEGATE, 5, address(gateVault), address(gateVault), 1);
        (bytes memory proof, bytes32 nullifier) = _authorizeGate(DELEGATE, b, bytes32(uint256(5)));
        _mintAndCheck(DELEGATE, b, proof, nullifier, false);
        require(
            core.ownerOf(1) == address(gateVault)
                && ledger.counterValue(_gateValueKey(b, address(gateVault))) == 1
                && ledger.counterValue(_gateValueKey(b, BUYER)) == 0
                && ledger.counterValue(_gateValueKey(b, address(gateCaller))) == 0,
            "delegated payer and Safe executor never receive vault allowance"
        );
    }

    function testDelegateWrongPayerWrongRouteAndWrongCollectionRightReject() public {
        _vaultGrant(BUYER, delegateGate.collectionDelegationRights(2), true);
        IStreamMintManager.MintBatch memory b =
            _gateBatch(DELEGATE, 6, address(gateVault), address(gateVault), 1);
        (bytes memory proof, bytes32 nullifier) = _authorizeGate(DELEGATE, b, bytes32(uint256(6)));
        _fail(b, proof, false);
        _assertGateUnused(b, nullifier);
        _vaultGrant(BUYER, delegateGate.collectionDelegationRights(1), true);
        IStreamMintManager.MintBatch memory bad = _copy(b);
        bad.payer = address(gateCaller);
        (bytes memory changed,) = _authorizeGate(DELEGATE, bad, bytes32(uint256(6)));
        _fail(bad, changed, false);
        _assertGateUnused(b, nullifier);
        bad = _copy(b);
        bad.initialRecipients[0] = address(gateCaller);
        (changed,) = _authorizeGate(DELEGATE, bad, bytes32(uint256(6)));
        _fail(bad, changed, false);
        _assertGateUnused(b, nullifier);
        bad = _copy(b);
        bad.beneficiaries[0] = address(faultyRecipient);
        bad.resolverData = _resolver(DELEGATE, bad.beneficiaries);
        (changed,) = _authorizeGate(DELEGATE, bad, bytes32(uint256(6)));
        _fail(bad, changed, false);
        _assertGateUnused(b, nullifier);
        _mintAndCheck(DELEGATE, b, proof, nullifier, false);
    }

    function testDelegateRevocationBlocksSavedSafeEnvelopeAndRestoredGrantRetriesExactly() public {
        bytes32 rights = delegateGate.collectionDelegationRights(1);
        _vaultGrant(BUYER, rights, true);
        IStreamMintManager.MintBatch memory b =
            _gateBatch(DELEGATE, 7, address(gateVault), address(gateVault), 1);
        (bytes memory proof, bytes32 nullifier) = _authorizeGate(DELEGATE, b, bytes32(uint256(7)));
        bytes memory saved = _gateEnvelope(gateCaller, _mintGateCall(b, proof, false));
        _vaultGrant(BUYER, rights, false);
        _sendGateEnvelope(gateCaller, saved, false);
        _assertGateUnused(b, nullifier);
        _vaultGrant(BUYER, rights, true);
        vm.recordLogs();
        _sendGateEnvelope(gateCaller, saved, true);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        _assertCommitted(b, nullifier, _gateReceipt(b, logs));
        _counterContexts(DELEGATE, b, logs);
    }

    function testDelegateValidGrantStillRequiresActualMerkleCounterProof() public {
        _vaultGrant(BUYER, delegateGate.collectionDelegationRights(1), true);
        IStreamMintManager.MintBatch memory b =
            _gateBatch(DELEGATE, 8, address(gateVault), address(gateVault), 1);
        (bytes memory proof, bytes32 nullifier) = _authorizeGate(DELEGATE, b, bytes32(uint256(8)));
        IStreamMintManager.MintBatch memory bad = _copy(b);
        bad.resolverData = _brokenProof(b.resolverData);
        vm.prank(address(gateCaller));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintCounterPolicy.MintAllowlistProofInvalid.selector,
                ALLOCATION,
                address(gateVault)
            )
        );
        manager.executeSingleStepMint(bad, proof);
        _fail(bad, proof, false);
        _assertGateUnused(b, nullifier);
        _mintAndCheck(DELEGATE, b, proof, nullifier, false);
    }

    function testDelegateAuthorizationAndNonceReplaysFailInOriginalLedger() public {
        _replay(DELEGATE);
    }

    function testDelegateLatePreparedReceiverFailureRestoresAllStateAndIdenticalSafeRetry() public {
        _lateFailure(DELEGATE);
    }

    function testSafeSignedTicketStillRequiresOwnPhaseMerkleCounterProof() public {
        IStreamMintManager.MintBatch memory b =
            _gateBatch(TICKET, 9, address(gateVault), address(gateVault), 1);
        (bytes memory proof,) = _authorizeGate(TICKET, b, bytes32(uint256(9)));
        IStreamMintManager.MintBatch memory bad = _copy(b);
        bad.resolverData = _resolver(ALLOW, b.beneficiaries);
        vm.prank(address(gateCaller));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintCounterPolicy.MintAllowlistProofInvalid.selector,
                ALLOCATION,
                address(gateVault)
            )
        );
        manager.executeSingleStepMint(bad, proof);
        _fail(bad, proof, false);
        _assertGateUnused(b, 0);
        _mintAndCheck(TICKET, b, proof, 0, false);
        require(
            gateSigner.nonce() == 0
                && ledger.counterValue(_gateValueKey(b, address(gateVault))) == 1,
            "actual ERC1271 signature plus independent original counter proof"
        );
    }

    function testWrongThresholdSafeCannotUseOtherwiseValidGateRequest() public {
        IStreamMintManager.MintBatch memory b =
            _gateBatch(ALLOW, 10, address(gateVault), address(gateVault), 1);
        (bytes memory proof, bytes32 nullifier) = _authorizeGate(ALLOW, b, bytes32(uint256(10)));
        bytes memory data = _mintGateCall(b, proof, false);
        _sendGateEnvelope(gateSigner, _gateEnvelope(gateSigner, data), false);
        _assertGateUnused(b, nullifier);
        _mintAndCheck(ALLOW, b, proof, nullifier, false);
    }

    function _replay(uint8 kind) private {
        if (kind == DELEGATE) _vaultGrant(BUYER, delegateGate.collectionDelegationRights(1), true);
        IStreamMintManager.MintBatch memory b =
            _gateBatch(kind, 11, address(gateVault), address(gateVault), 1);
        (bytes memory proof, bytes32 nullifier) = _authorizeGate(kind, b, bytes32(uint256(11)));
        _mintAndCheck(kind, b, proof, nullifier, false);
        vm.prank(address(gateCaller));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, b.authorizationId
            )
        );
        manager.executeSingleStepMint(b, proof);
        _fail(b, proof, false);
        IStreamMintManager.MintBatch memory different =
            _gateBatch(kind, 12, address(gateVault), address(gateVault), 1);
        (bytes memory changed, bytes32 sameNonce) =
            _authorizeGate(kind, different, bytes32(uint256(11)));
        require(
            different.authorizationId != b.authorizationId && sameNonce == nullifier,
            "different request retains gate nonce identity"
        );
        vm.prank(address(gateCaller));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.NullifierAlreadyConsumed.selector, nullifier)
        );
        manager.executeSingleStepMint(different, changed);
        _fail(different, changed, false);
        require(
            core.totalSupply() == 1 && manager.nextOperationNonce() == 1 && gateCaller.nonce() == 1
                && ledger.counterValue(_gateValueKey(b, address(gateVault))) == 1
                && !manager.isAuthorizationUsed(different.authorizationId),
            "original Ledger rejects both replay forms without extra debit"
        );
    }

    function _lateFailure(uint8 kind) private {
        address first = kind == DELEGATE ? address(faultyRecipient) : address(gateVault);
        IStreamMintManager.MintBatch memory b = _gateBatch(kind, 13, first, first, 2);
        if (kind == DELEGATE) {
            faultyRecipient.grant(
                delegationService, BUYER, address(core), delegateGate.collectionDelegationRights(1)
            );
        } else {
            b.initialRecipients[1] = address(faultyRecipient);
            faultyRecipient.setRejectAt(1);
        }
        (bytes memory proof, bytes32 nullifier) = _authorizeGate(kind, b, bytes32(uint256(13)));
        bytes memory saved = _gateEnvelope(gateCaller, _mintGateCall(b, proof, true));
        vm.recordLogs();
        _sendGateEnvelope(gateCaller, saved, false);
        Vm.Log[] memory failed = vm.getRecordedLogs();
        bytes32 root = _gateReceipt(b, failed);
        require(
            _completed(failed, root) == 1,
            "first actual prepared token completed before late failure"
        );
        _assertGateUnused(b, nullifier);
        require(
            !manager.isOperationRootUsed(root)
                && !ledger.isManagerOperationRootUsed(address(manager), root)
                && faultyRecipient.callbacks() == 0 && core.pendingPreparedMintTokenId() == 0,
            "original root and recipient callback state roll back"
        );
        for (uint256 id = 1; id <= 2; ++id) {
            (bool exists,,,) = core.tokenCollectionIdentity(id);
            require(
                !exists && !core.preparedMint(id).exists && core.tokenData(id).length == 0
                    && core.coordinatorAtMint(id) == address(0),
                "no token or entropy anchor survives"
            );
        }
        faultyRecipient.setRejectAt(0);
        vm.recordLogs();
        _sendGateEnvelope(gateCaller, saved, true);
        Vm.Log[] memory committed = vm.getRecordedLogs();
        require(
            _gateReceipt(b, committed) == root && _completed(committed, root) == 2,
            "identical Safe envelope commits the same prepared root once"
        );
        _assertCommitted(b, nullifier, root);
        _counterContexts(kind, b, committed);
        require(
            ledger.counterValue(_gateValueKey(b, first)) == 2 && gateCaller.nonce() == 1
                && faultyRecipient.callbacks() == (kind == DELEGATE ? 2 : 1),
            "only successful retry debits both occurrences"
        );
    }

    function _mintAndCheck(
        uint8 kind,
        IStreamMintManager.MintBatch memory b,
        bytes memory proof,
        bytes32 nullifier,
        bool prepared
    ) private {
        vm.prank(address(gateCaller));
        (bytes32 preview,) = manager.previewSingleStepMintOperation(b, proof);
        vm.recordLogs();
        _sendGateEnvelope(
            gateCaller, _gateEnvelope(gateCaller, _mintGateCall(b, proof, prepared)), true
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 root = _gateReceipt(b, logs);
        if (!prepared) {
            require(root == preview, "original read-only transcript matches committed root");
        }
        _assertCommitted(b, nullifier, root);
        _counterContexts(kind, b, logs);
    }

    function _assertCommitted(
        IStreamMintManager.MintBatch memory b,
        bytes32 nullifier,
        bytes32 root
    ) private view {
        require(
            manager.isAuthorizationUsed(b.authorizationId)
                && ledger.isManagerAuthorizationUsed(address(manager), b.authorizationId)
                && manager.isOperationRootUsed(root)
                && ledger.isManagerOperationRootUsed(address(manager), root)
                && (nullifier == 0
                    || (manager.isNullifierUsed(nullifier)
                        && ledger.isManagerNullifierUsed(address(manager), nullifier))),
            "original Ledger stores gate replay state"
        );
        require(
            core.totalSupply() == b.initialRecipients.length
                && core.collectionMintedEver(1) == b.initialRecipients.length
                && core.lastAllocatedTokenId() == b.initialRecipients.length
                && manager.nextOperationNonce() == b.initialRecipients.length
                && core.pendingPreparedMintTokenId() == 0 && gateCaller.nonce() == 1,
            "exact original mint accounting"
        );
        for (uint256 i; i < b.initialRecipients.length; ++i) {
            require(
                core.ownerOf(i + 1) == b.initialRecipients[i]
                    && keccak256(core.tokenData(i + 1)) == keccak256(b.tokenData[i])
                    && !core.preparedMint(i + 1).exists,
                "actual original token delivery and content"
            );
        }
    }

    function _counterContexts(
        uint8 kind,
        IStreamMintManager.MintBatch memory b,
        Vm.Log[] memory logs
    ) private view {
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(ledger) || logs[i].topics.length != 4
                    || logs[i].topics[0]
                        != keccak256(
                            "MintLedgerCounterConsumptionContext(uint16,bytes32,bytes32,bytes32,address,address,address,address,address,bytes32,bytes32)"
                        )
            ) continue;
            require(found < b.beneficiaries.length, "bounded original counter occurrences");
            address subjectAddress = b.beneficiaries[found];
            bytes32 subject = keccak256(
                abi.encode(
                    keccak256("6529STREAM_MINT_COUNTER_SUBJECT_V1"),
                    block.chainid,
                    address(ledger),
                    IStreamMintManager.CounterKeyMode.RECIPIENT,
                    subjectAddress
                )
            );
            bytes32 key = keccak256(
                abi.encode(
                    keccak256("6529STREAM_MINT_COUNTER_VALUE_KEY_V1"),
                    address(manager),
                    b.collectionId,
                    b.phaseId,
                    ALLOCATION,
                    subject
                )
            );
            bytes32 initial = keccak256(
                abi.encode(
                    keccak256("6529STREAM_MINT_COUNTER_RESOLUTION_V1"),
                    block.chainid,
                    address(manager),
                    address(ledger),
                    b.collectionId,
                    b.phaseId,
                    ALLOCATION,
                    subject,
                    found,
                    definitionHashes[kind]
                )
            );
            bytes32 leaf = gateLeaves[kind][subjectAddress == address(gateVault) ? 0 : 1];
            bytes32 resolution = keccak256(
                abi.encode(keccak256("6529STREAM_MINT_ALLOWLIST_RESOLUTION_V1"), initial, leaf)
            );
            require(
                logs[i].topics[1] == key && logs[i].topics[2] == ALLOCATION
                    && logs[i].topics[3] == subject
                    && keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                address(manager),
                                b.payer,
                                subjectAddress,
                                b.authorizer,
                                address(gateCaller),
                                b.contextHash,
                                resolution
                            )
                        ),
                "exact per-token subject and proof resolution receipt"
            );
            ++found;
        }
        require(found == b.beneficiaries.length, "all original proof resolution occurrences");
    }

    function _completed(Vm.Log[] memory logs, bytes32 root) private view returns (uint256 count) {
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(manager) || logs[i].topics.length != 4
                    || logs[i].topics[0]
                        != keccak256(
                            "PreparedMintCompleted(uint16,bytes32,uint256,uint256,bytes32,address)"
                        )
            ) continue;
            (uint16 version, bytes32 actual,) = abi.decode(logs[i].data, (uint16, bytes32, address));
            require(
                version == 1 && actual == root && uint256(logs[i].topics[2]) == count + 1
                    && uint256(logs[i].topics[3]) == 1,
                "ordered original prepared completion trace"
            );
            ++count;
        }
    }

    function _fail(IStreamMintManager.MintBatch memory b, bytes memory proof, bool prepared)
        private
    {
        _sendGateEnvelope(
            gateCaller, _gateEnvelope(gateCaller, _mintGateCall(b, proof, prepared)), false
        );
    }

    function _copy(IStreamMintManager.MintBatch memory b)
        private
        pure
        returns (IStreamMintManager.MintBatch memory)
    {
        return abi.decode(abi.encode(b), (IStreamMintManager.MintBatch));
    }

    function _brokenProof(bytes memory data) private pure returns (bytes memory) {
        IStreamMintCounterPolicy.AllowlistProof[][] memory p =
            abi.decode(data, (IStreamMintCounterPolicy.AllowlistProof[][]));
        p[0][0].proof[0] = bytes32(uint256(p[0][0].proof[0]) ^ 1);
        return abi.encode(p);
    }
}
