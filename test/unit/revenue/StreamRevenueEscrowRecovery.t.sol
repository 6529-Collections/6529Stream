// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../helpers/RevenueEscrowTestMocks.sol";
import "../../mocks/MockStreamPaymentToken.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueRuntimeRegistry.sol";

interface RecoveryTestCalls {
    function expectCall(address target, bytes calldata data, uint64 count) external;
}

/// @dev Explicit optional-capability transport fault; never an admitted factory.
contract RecoveryCapabilityReply {
    uint256 private immutable replyLength;
    uint256 private immutable replyWord;

    constructor(uint256 length, uint256 word) {
        replyLength = length;
        replyWord = word;
    }

    fallback() external {
        uint256 length = replyLength;
        uint256 word = replyWord;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, word)
            mstore(add(ptr, 32), 0)
            return(ptr, length)
        }
    }
}

/// @notice Actual Factory/Escrow/Wallet/threshold Safe; target-side governance context only.
/// @dev Actual delayed Executor coverage is authored separately. No current Core mint claim.
contract StreamRevenueEscrowRecoveryTest is RevenueV1TestBase, OfficialSafeFixture {
    StreamAssetPolicyRegistry private policy;
    StreamSplitFactory private original;
    StreamSplitFactory private successor;
    StreamRevenueEscrow private escrow;
    StreamRevenueRuntimeRegistry private lifecycle;
    EscrowCallbackAuthority private authority;
    MockStreamPaymentToken private token;
    OfficialSafe private account;
    uint256[] private keys;
    uint256 private actionNonce;
    bytes32 private profile;
    address private wallet;
    bytes32 private constant CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant META = keccak256("original entries metadata");
    bytes32 private constant INCIDENT = keccak256("retained incident report");
    bytes32 private constant REASON = keccak256("incident escrow successor");
    string private constant URI = "urn:stream:test:escrow-recovery";

    function setUp() public {
        vm.warp(1_000_000);
        vm.roll(100);
        authority = new EscrowCallbackAuthority();
        revenueAuthority = authority;
        policy = new StreamAssetPolicyRegistry(address(authority));
        original = _factory();
        successor = _factory();
        escrow = new StreamRevenueEscrow(
            original,
            address(authority),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 100_000, 3)
        );
        lifecycle = new StreamRevenueRuntimeRegistry(
            address(authority),
            address(policy),
            IStreamGasParameterHost.GasParameterConfig(
                "REVENUE_RUNTIME_READ_GAS", 150_000, 100_000, 2
            )
        );
        keys.push(0xEA11);
        keys.push(0xEA22);
        account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 0xEA33);
        _status(original, 1);
        _status(successor, 1);
        _bind(address(original));
        _bind(address(successor));
        _bind(address(escrow));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            escrow.creditProducerTransitionHashes(address(this), true);
        _act(
            address(escrow),
            abi.encodeCall(escrow.setCreditProducer, (address(this), true)),
            1,
            scope,
            oldHash,
            newHash
        );
        (profile, wallet) = original.registerProfile(_entries(address(account)), META);
        token = new MockStreamPaymentToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("standard token"), 0);
        vm.deal(address(this), 100 ether);
    }

    function testBoundRegistryIsOnceOnlyAndUnboundConstructorCompatibilityRemains() public {
        require(escrow.revenueRuntimeRegistry() == address(lifecycle), "explicit selected registry");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueRuntimeBinding.RevenueRuntimeAlreadyBound.selector)
        );
        escrow.revenueRuntimeBindingTransitionHashes(address(lifecycle));
        StreamSplitFactory unbound = _factory();
        (bytes32 p,) = unbound.registerProfile(_entries(address(account)), META);
        require(
            p != 0 && unbound.revenueRuntimeRegistry() == address(0),
            "original constructor compatibility"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding.selector
            )
        );
        unbound.initializeRevenueRuntimeRegistry(address(lifecycle));
        require(unbound.revenueRuntimeRegistry() == address(0), "no caller opt-in authority");
    }

    function testDeprecatedFactoryBlocksNewUseButFlushAndReleasePreserveOldOwed() public {
        _credit(address(0), 2 ether);
        _status(original, 2);
        vm.expectRevert();
        original.registerProfile(_entries(address(account)), keccak256("new use"));
        vm.expectRevert();
        escrow.creditNative{ value: 1 }(CLASS, profile, wallet, true);
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        IStreamSplitWallet(wallet).release(address(0), address(account), payable(address(account)));
        require(
            address(account).balance == 2 ether && escrow.totalOwed(address(0)) == 0,
            "old rights survive deprecation"
        );
    }

    function testIncidentToDeprecatedRequiresDelayedRelaxationClass() public {
        _credit(address(0), 1 ether);
        _status(original, 3);
        (uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            lifecycle.factoryTransitionHashes(address(original), 2, REASON, URI, 0);
        require(cls == 1, "flush restoration is relaxation");
        _context(0, scope, oldHash, newHash);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueRuntimeRegistry.InvalidRevenueRuntimeAction.selector
            )
        );
        authority.execute(
            address(lifecycle),
            abi.encodeCall(
                lifecycle.setFactoryStatus, (address(original), uint8(2), REASON, URI, bytes32(0))
            )
        );
        _status(original, 2);
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        require(wallet.balance == 1 ether, "restored flush after delayed-context transition");
    }

    function testIdenticalRecoveryMovesOnlyExactOwedAndEventsOriginalIdentity() public {
        original.deployWallet(profile);
        (bool paid,) = payable(wallet).call{ value: 3 ether }("");
        require(paid, "original wallet resident money");
        _credit(address(0), 2 ether);
        (paid,) = payable(address(escrow)).call{ value: 5 ether }("");
        require(paid, "surplus");
        _status(original, 3);
        (
            IStreamRevenueEscrowRecoveryManifest.ManifestDocument memory d,
            R.EscrowRecoveryRecord memory p,
            bytes32 id
        ) = _prepare(0, address(0), address(account));
        _schedule(p);
        vm.warp(p.executeAfter);
        vm.recordLogs();
        escrow.executeEscrowRecovery(id);
        require(
            wallet.balance == 3 ether && d.successorWallet.balance == 2 ether,
            "resident original untouched"
        );
        require(
            address(escrow).balance == 5 ether && escrow.totalOwed(address(0)) == 0,
            "surplus is not recovery amount"
        );
        require(
            escrow.escrowRecoveryRecord(id).status == R.EscrowRecoveryStatus.EXECUTED,
            "exact final record"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(escrow)) {
                require(
                    logs[i].topics[0]
                        == keccak256(
                            "EscrowRecoveryExecuted(uint16,bytes32,bytes32,bytes32,address,address,uint256,bytes32,bytes32,string)"
                        ),
                    "original event type"
                );
                require(
                    logs[i].topics[1] == id && logs[i].topics[2] == CLASS
                        && logs[i].topics[3] == profile,
                    "original indexed credit"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(1),
                                wallet,
                                d.successorWallet,
                                uint256(2 ether),
                                p.recoveryManifest.contentHash,
                                REASON,
                                URI
                            )
                        ),
                    "original event payload"
                );
                ++found;
            }
        }
        require(found == 1, "one recovery event");
        vm.expectRevert(
            abi.encodeWithSelector(RecoveryState.InvalidEscrowRecoveryState.selector, id)
        );
        escrow.executeEscrowRecovery(id);
    }

    function testAffectedSafeConsentRevocationAndIdenticalSignedTransactionRetry() public {
        _credit(address(0), 2 ether);
        _status(original, 3);
        (, R.EscrowRecoveryRecord memory p, bytes32 id) = _prepare(1, address(0), address(0xB0B));
        require(
            escrow.escrowRecoveryAffectedAccountCount(p.recoveryManifest.contentHash) == 1
                && escrow.escrowRecoveryAffectedAccountAt(p.recoveryManifest.contentHash, 0)
                    == address(account),
            "onchain affected account"
        );
        _safeConsent(id, bytes32(uint256(1)));
        _schedule(p);
        require(
            executeSafe(
                account,
                keys,
                address(escrow),
                0,
                abi.encodeCall(escrow.revokeEscrowRecoveryConsent, (id)),
                0
            ),
            "direct Safe revocation"
        );
        vm.warp(p.executeAfter);
        bytes memory callData = abi.encodeCall(escrow.executeEscrowRecovery, (id));
        uint256 nonce = account.nonce();
        bytes memory signed = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(escrow), 0, callData, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        RecoveryTestCalls(address(vm)).expectCall(address(escrow), callData, 2);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        _savedSafe(callData, signed);
        require(
            account.nonce() == nonce && escrow.totalOwed(address(0)) == 2 ether,
            "complete failed Safe and ledger rollback"
        );
        // A relayed Safe-message signature restores consent without consuming the Safe transaction nonce.
        _safeConsent(id, bytes32(uint256(2)));
        require(_savedSafe(callData, signed), "saved Safe CALL");
        require(
            account.nonce() == nonce + 1 && escrow.totalOwed(address(0)) == 0,
            "byte-identical signed retry"
        );
    }

    function testDirectConsentNeedsNo1271AndWrongDomainDeadlineAndNonceReject() public {
        _credit(address(0), 10);
        _status(original, 3);
        (, R.EscrowRecoveryRecord memory p, bytes32 id) = _prepare(1, address(0), address(0xB0B));
        uint64 deadline = uint64(block.timestamp + 30 days);
        bytes32 nonce = keccak256("consent nonce");
        bytes memory wrong = safeThresholdSignature(
            keys, safeMessageDigest(account, abi.encode(keccak256("wrong escrow domain")))
        );
        vm.expectRevert(abi.encodeWithSelector(RecoveryState.EscrowRecoveryConsentInvalid.selector));
        escrow.submitEscrowRecoveryConsent(address(account), id, nonce, deadline, wrong);
        require(
            !escrow.isEscrowRecoveryConsentNonceUsed(address(account), nonce),
            "failure does not consume"
        );
        require(
            executeSafe(
                account,
                keys,
                address(escrow),
                0,
                abi.encodeCall(escrow.recordEscrowRecoveryConsent, (id, nonce)),
                0
            ),
            "actual account direct path"
        );
        require(
            escrow.isEscrowRecoveryConsentNonceUsed(address(account), nonce),
            "direct nonce is same domain"
        );
        vm.expectRevert(abi.encodeWithSelector(RecoveryState.EscrowRecoveryConsentInvalid.selector));
        escrow.submitEscrowRecoveryConsent(address(account), id, nonce, deadline, wrong);
        vm.expectRevert(abi.encodeWithSelector(RecoveryState.EscrowRecoveryConsentInvalid.selector));
        escrow.submitEscrowRecoveryConsent(
            address(account), id, bytes32(uint256(99)), uint64(block.timestamp - 1), wrong
        );
        _schedule(p);
    }

    function testTerminalRequiresBothActualNoticeFloorsAndDistinctActionClasses() public {
        _credit(address(0), 2 ether);
        _status(original, 3);
        (, R.EscrowRecoveryRecord memory p, bytes32 id) = _prepare(2, address(0), address(0xB0B));
        (bytes32 actual, bytes32 scope, bytes32 oldHash, bytes32 newHash) = _transition(p);
        require(actual == id, "same original preimage");
        _context(4, scope, oldHash, newHash);
        vm.expectRevert();
        authority.execute(address(escrow), _scheduleData(p));
        _schedule(p);
        (scope, oldHash, newHash) = escrow.escrowRecoveryTerminalHashes(id);
        _context(2, scope, oldHash, newHash);
        vm.expectRevert();
        authority.execute(
            address(escrow), abi.encodeCall(escrow.authorizeTerminalEscrowRecovery, (id))
        );
        vm.warp(p.executeAfter);
        vm.expectRevert(abi.encodeWithSelector(RecoveryState.InvalidEscrowRecoveryAction.selector));
        escrow.executeEscrowRecovery(id);
        _act(
            address(escrow),
            abi.encodeCall(escrow.authorizeTerminalEscrowRecovery, (id)),
            2,
            scope,
            oldHash,
            newHash
        );
        escrow.executeEscrowRecovery(id);
        require(
            escrow.totalOwed(address(0)) == 0, "terminal evidence and separate class 2 completed"
        );
    }

    function testManifestCannotHideAffectedAccountOrSwapNoticeBytes() public {
        _credit(address(0), 9);
        _status(original, 3);
        (
            IStreamRevenueEscrowRecoveryManifest.ManifestDocument memory d,
            R.EscrowRecoveryRecord memory p,
        ) = _prepare(2, address(0), address(0xB0B));
        d.recipientNotices = new IStreamRevenueEscrowRecoveryManifest.RecipientNotice[](0);
        p.recoveryManifest.contentHash = _manifestHash(d);
        vm.expectRevert(
            abi.encodeWithSelector(RecoveryState.InvalidEscrowRecoveryManifest.selector)
        );
        escrow.publishEscrowRecoveryManifest(d, p.recoveryManifest);
        d.recipientNotices = new IStreamRevenueEscrowRecoveryManifest.RecipientNotice[](1);
        d.recipientNotices[0] = IStreamRevenueEscrowRecoveryManifest.RecipientNotice(
            address(account), REASON, uint64(block.timestamp + 1)
        );
        p.recoveryManifest.contentHash = _manifestHash(d);
        vm.expectRevert(
            abi.encodeWithSelector(RecoveryState.InvalidEscrowRecoveryManifest.selector)
        );
        escrow.publishEscrowRecoveryManifest(d, p.recoveryManifest);
    }

    function testExactTokenDeltaLateFailureRollsBackDeploymentAndSafeNonceThenRetries() public {
        _credit(address(token), 1000);
        _status(original, 3);
        (
            IStreamRevenueEscrowRecoveryManifest.ManifestDocument memory d,
            R.EscrowRecoveryRecord memory p,
            bytes32 id
        ) = _prepare(0, address(token), address(account));
        _schedule(p);
        vm.warp(p.executeAfter);
        bytes memory data = abi.encodeCall(escrow.executeEscrowRecovery, (id));
        uint256 nonce = account.nonce();
        bytes memory signature = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(escrow), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        RecoveryTestCalls(address(vm))
            .expectCall(
                address(token),
                abi.encodeCall(token.transfer, (d.successorWallet, uint256(1000))),
                2
            );
        token.configure(3, 2);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        _savedSafe(data, signature);
        require(
            account.nonce() == nonce && d.successorWallet.code.length == 0,
            "late error restores create and nonce"
        );
        require(
            token.rawBalance(address(escrow)) == 1000 && escrow.totalOwed(address(token)) == 1000,
            "exact original credit restored"
        );
        token.configure(0, 0);
        require(_savedSafe(data, signature), "saved Safe CALL");
        require(
            token.rawBalance(d.successorWallet) == 1000 && escrow.totalOwed(address(token)) == 0,
            "identical Safe retry exact token movement"
        );
    }

    function testCurrentAmountOrSuccessorIncidentDriftCannotConsumeRecovery() public {
        _credit(address(0), 10);
        _status(original, 3);
        (, R.EscrowRecoveryRecord memory p, bytes32 id) = _prepare(0, address(0), address(account));
        _schedule(p);
        vm.warp(p.executeAfter);
        _status(successor, 3);
        vm.expectRevert();
        escrow.executeEscrowRecovery(id);
        require(
            escrow.escrowRecoveryRecord(id).status == R.EscrowRecoveryStatus.SCHEDULED,
            "current successor refusal"
        );
        _status(successor, 1);
        _status(original, 1);
        _credit(address(0), 1);
        _status(original, 3);
        vm.expectRevert(
            abi.encodeWithSelector(RecoveryState.InvalidEscrowRecoveryManifest.selector)
        );
        escrow.executeEscrowRecovery(id);
        require(
            escrow.totalOwed(address(0)) == 11,
            "new amount is not silently folded into signed recovery"
        );
    }

    function testCancellationIsExactGovernedAndKeepsOwedAvailableForNewPlan() public {
        _credit(address(0), 10);
        _status(original, 3);
        (, R.EscrowRecoveryRecord memory p, bytes32 id) = _prepare(0, address(0), address(account));
        _schedule(p);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            escrow.escrowRecoveryCancellationHashes(id, REASON, URI);
        _act(
            address(escrow),
            abi.encodeCall(escrow.cancelEscrowRecovery, (id, REASON, URI)),
            0,
            scope,
            oldHash,
            newHash
        );
        require(
            escrow.escrowRecoveryRecord(id).status == R.EscrowRecoveryStatus.CANCELLED
                && escrow.totalOwed(address(0)) == 10,
            "cancellation is not payment"
        );
        vm.expectRevert(
            abi.encodeWithSelector(RecoveryState.InvalidEscrowRecoveryState.selector, id)
        );
        escrow.executeEscrowRecovery(id);
    }

    function testSharedRuntimeIncidentBlocksBothFactoriesButResidentReleaseAndRestorationSurvive()
        public
    {
        original.deployWallet(profile);
        (bool ok,) = payable(wallet).call{ value: 3 ether }("");
        require(ok, "old wallet resident");
        _credit(address(0), 2 ether);
        _runtimeStatus(3);
        vm.expectRevert();
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        vm.expectRevert();
        successor.registerProfile(_entries(address(account)), keccak256("shared revoked runtime"));
        IStreamSplitWallet(wallet).release(address(0), address(account), payable(address(account)));
        require(
            address(account).balance == 3 ether && escrow.totalOwed(address(0)) == 2 ether,
            "incident cannot seize resident money"
        );
        _runtimeStatus(1);
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        require(
            wallet.balance == 2 ether
                && lifecycle.runtimeRecord(original.splitWalletRuntimeCodeHash()).revision == 3,
            "reasoned reenable restores normal flush"
        );
    }

    function testUnavailableOriginalFactoryUsesCapturedProfilePreimageAndIndependentGas() public {
        _credit(address(0), 2 ether);
        _status(original, 3);
        (, R.EscrowRecoveryRecord memory p, bytes32 id) = _prepare(0, address(0), address(account));
        // Explicit code-loss adversary, not a replacement implementation accepted as original.
        vm.etch(address(original), hex"60006000fd");
        _schedule(p);
        vm.warp(p.executeAfter);
        escrow.executeEscrowRecovery(id);
        require(
            p.successorWallet.balance == 2 ether && escrow.totalOwed(address(0)) == 0,
            "captured origin and common incident remain sufficient"
        );
    }

    function _runtimeStatus(uint8 status) private {
        bytes32 runtime = original.splitWalletRuntimeCodeHash();
        bytes32 incident = status == 3 ? INCIDENT : bytes32(0);
        (uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            lifecycle.runtimeTransitionHashes(runtime, status, REASON, URI, incident);
        _act(
            address(lifecycle),
            abi.encodeCall(lifecycle.setRuntimeStatus, (runtime, status, REASON, URI, incident)),
            cls,
            scope,
            oldHash,
            newHash
        );
    }

    function testLateTokenCallbackRevocationRestoresAllStateThenIdenticalSafeRetry() public {
        _credit(address(token), 1000);
        _status(original, 3);
        (
            IStreamRevenueEscrowRecoveryManifest.ManifestDocument memory d,
            R.EscrowRecoveryRecord memory p,
            bytes32 id
        ) = _prepare(0, address(token), address(account));
        _schedule(p);
        vm.warp(p.executeAfter);
        (uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            lifecycle.factoryTransitionHashes(address(successor), 3, REASON, URI, INCIDENT);
        _context(cls, scope, oldHash, newHash);
        bytes memory mutation = abi.encodeCall(
            lifecycle.setFactoryStatus, (address(successor), uint8(3), REASON, URI, INCIDENT)
        );
        token.configureCallback(
            address(authority), abi.encodeCall(authority.execute, (address(lifecycle), mutation)), 2
        );
        bytes memory data = abi.encodeCall(escrow.executeEscrowRecovery, (id));
        uint256 nonce = account.nonce();
        bytes memory signature = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(escrow), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        RecoveryTestCalls(address(vm)).expectCall(address(lifecycle), mutation, 1);
        RecoveryTestCalls(address(vm))
            .expectCall(
                address(token),
                abi.encodeCall(token.transfer, (d.successorWallet, uint256(1000))),
                2
            );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        _savedSafe(data, signature);
        require(
            lifecycle.factoryRecord(address(successor)).status == 1
                && d.successorWallet.code.length == 0,
            "callback lifecycle and deployment rollback"
        );
        require(
            account.nonce() == nonce && token.rawBalance(address(escrow)) == 1000
                && escrow.totalOwed(address(token)) == 1000,
            "Safe and original ledger rollback"
        );
        token.configureCallback(address(0), bytes(""), 0);
        require(_savedSafe(data, signature), "saved Safe CALL");
        require(
            token.rawBalance(d.successorWallet) == 1000 && escrow.totalOwed(address(token)) == 0,
            "exact original signed transaction after callback repair"
        );
    }

    function testOptionalCapabilityRejectsSuccessfulMalformedNonemptyReplies() public {
        uint256[4] memory sizes = [uint256(1), uint256(31), uint256(33), uint256(64)];
        for (uint256 i; i < sizes.length; ++i) {
            address target = address(new RecoveryCapabilityReply(sizes[i], 1));
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding.selector
                )
            );
            RuntimeBinding.factoryBinding(target);
        }
        address invalidBoolean = address(new RecoveryCapabilityReply(32, 2));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding.selector
            )
        );
        RuntimeBinding.factoryBinding(invalidBoolean);
        (address none, bytes32 hash) =
            RuntimeBinding.factoryBinding(address(new RecoveryCapabilityReply(0, 0)));
        require(none == address(0) && hash == 0, "original absent-selector compatibility");
        (none, hash) = RuntimeBinding.factoryBinding(address(new RecoveryCapabilityReply(32, 0)));
        require(none == address(0) && hash == 0, "exact false capability compatibility");
    }

    function testRecoveryGasInventoryIsFixedBeforeOnceOnlyBinding() public {
        StreamRevenueEscrow fresh = new StreamRevenueEscrow(
            original,
            address(authority),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 100_000, 3)
        );
        bytes32 beforeIds = keccak256(abi.encode(fresh.gasParameterIds()));
        require(
            fresh.gasParameterIds().length == 4 && fresh.revenueRuntimeRegistry() == address(0),
            "all GGP registration occurs in constructor"
        );
        _bind(address(fresh));
        require(
            keccak256(abi.encode(fresh.gasParameterIds())) == beforeIds,
            "opt-in cannot change fixed inventory"
        );
    }

    function testPermissionlessContentPublicationCannotPinGovernanceReferenceURI() public {
        _credit(address(0), 2 ether);
        _status(original, 3);
        (
            IStreamRevenueEscrowRecoveryManifest.ManifestDocument memory d,
            R.EscrowRecoveryRecord memory p,
            bytes32 id
        ) = _prepare(0, address(0), address(account));
        (, uint64 published) = escrow.escrowRecoveryManifest(p.recoveryManifest.contentHash);
        (,,, bytes32 firstCommitment) = _transition(p);
        p.recoveryManifest.uri = "urn:stream:operator:independent-exact-reference";
        p.recoveryManifest.uriHash = keccak256(bytes(p.recoveryManifest.uri));
        (bytes32 sameId,,, bytes32 nextCommitment) = _transition(p);
        require(
            sameId == id && nextCommitment != firstCommitment,
            "original content-bound ID, full reference in governed commitment"
        );
        vm.warp(block.timestamp + 1 hours);
        escrow.publishEscrowRecoveryManifest(d, p.recoveryManifest);
        (, uint64 unchanged) = escrow.escrowRecoveryManifest(p.recoveryManifest.contentHash);
        require(unchanged == published, "URI cannot restart original content notice clock");
        p.recoveryManifest.uriHash = 0;
        vm.expectRevert(
            abi.encodeWithSelector(RecoveryState.InvalidEscrowRecoveryManifest.selector)
        );
        this.transitionForTest(p);
        p.recoveryManifest.uriHash = keccak256(bytes(p.recoveryManifest.uri));
        _schedule(p);
        vm.warp(p.executeAfter);
        escrow.executeEscrowRecovery(id);
        require(
            keccak256(bytes(escrow.escrowRecoveryRecord(id).recoveryManifest.uri))
                == keccak256(bytes(p.recoveryManifest.uri)),
            "exact authorized reference retained"
        );
    }

    function transitionForTest(R.EscrowRecoveryRecord memory p) external view {
        _transition(p);
    }

    function _factory() private returns (StreamSplitFactory) {
        IStreamGasParameterHost.GasParameterConfig[3] memory gas = _walletGasConfigs();
        gas[1].genesisValue = 150_000;
        gas[1].floor = 100_000;
        gas[2].genesisValue = 500_000;
        gas[2].floor = 100_000;
        return new StreamSplitFactory(policy, address(authority), gas);
    }

    function _entries(address recipient)
        private
        pure
        returns (IStreamSplitWallet.SplitEntry[] memory e)
    {
        e = new IStreamSplitWallet.SplitEntry[](1);
        e[0] = IStreamSplitWallet.SplitEntry(recipient, 1_000_000, keccak256("artist"));
    }

    function _status(StreamSplitFactory f, uint8 status) private {
        bytes32 incident = status == 3 ? INCIDENT : bytes32(0);
        (uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            lifecycle.factoryTransitionHashes(address(f), status, REASON, URI, incident);
        _act(
            address(lifecycle),
            abi.encodeCall(lifecycle.setFactoryStatus, (address(f), status, REASON, URI, incident)),
            cls,
            scope,
            oldHash,
            newHash
        );
    }

    function _bind(address host) private {
        IStreamRevenueRuntimeBinding b = IStreamRevenueRuntimeBinding(host);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            b.revenueRuntimeBindingTransitionHashes(address(lifecycle));
        _act(
            host,
            abi.encodeCall(b.initializeRevenueRuntimeRegistry, (address(lifecycle))),
            1,
            scope,
            oldHash,
            newHash
        );
    }

    function _context(uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) private {
        authority.setCurrentAction(true, bytes32(++actionNonce), cls, scope, oldHash, newHash);
    }

    function _act(
        address target,
        bytes memory data,
        uint8 cls,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private {
        _context(cls, scope, oldHash, newHash);
        authority.execute(target, data);
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _credit(address asset, uint256 amount) private {
        if (asset == address(0)) {
            escrow.creditNative{ value: amount }(CLASS, profile, wallet, true);
        } else {
            token.mint(address(this), amount);
            token.approve(address(escrow), amount);
            escrow.creditERC20(CLASS, profile, wallet, asset, amount, true);
        }
    }

    function _prepare(uint8 route, address asset, address payee)
        private
        returns (
            IStreamRevenueEscrowRecoveryManifest.ManifestDocument memory d,
            R.EscrowRecoveryRecord memory p,
            bytes32 id
        )
    {
        (bytes32 next, address target) =
            successor.registerProfile(_entries(payee), keccak256("successor metadata"));
        d.creditKey = R.EscrowCreditKey(CLASS, profile, wallet, asset);
        d.successorFactory = address(successor);
        d.successorWallet = target;
        d.successorProfileId = next;
        d.successorRuntimeCodeHash = successor.splitWalletRuntimeCodeHash();
        d.expectedAmount = escrow.escrowOwed(CLASS, profile, wallet, asset);
        d.route = route;
        d.oldEntries = _entries(address(account));
        d.oldMetadataURIHash = META;
        d.successorEntries = _entries(payee);
        d.incidentEvidenceHash = INCIDENT;
        if (route == 2) {
            d.coverageStatementHash = keccak256(
                "governance assertion of complete historical credit citations and notice delivery"
            );
            d.recipientNotices = new IStreamRevenueEscrowRecoveryManifest.RecipientNotice[](1);
            d.recipientNotices[0] = IStreamRevenueEscrowRecoveryManifest.RecipientNotice(
                address(account), keccak256("recipient notice"), uint64(block.timestamp)
            );
            d.collectionNotices = new IStreamRevenueEscrowRecoveryManifest.CollectionNotice[](1);
            d.collectionNotices[0] = IStreamRevenueEscrowRecoveryManifest.CollectionNotice(
                address(0xC0E),
                1,
                true,
                address(account),
                keccak256("Artist notice"),
                uint64(block.timestamp)
            );
            d.sourceCredits = new IStreamRevenueEscrowRecoveryManifest.SourceCredit[](1);
            d.sourceCredits[0] = IStreamRevenueEscrowRecoveryManifest.SourceCredit(
                address(this),
                keccak256("source credit transaction citation"),
                keccak256("source credit block citation"),
                1,
                0,
                0
            );
        }
        R.EscrowRecoveryManifestRef memory ref = R.EscrowRecoveryManifestRef(
            URI,
            keccak256(bytes(URI)),
            _manifestHash(d),
            keccak256("STREAM_ESCROW_RECOVERY_MANIFEST_V1"),
            keccak256("6529STREAM_ESCROW_RECOVERY_ABI_V1")
        );
        escrow.publishEscrowRecoveryManifest(d, ref);
        p = R.EscrowRecoveryRecord(
            R.EscrowRecoveryStatus.SCHEDULED,
            d.creditKey,
            address(original),
            target,
            next,
            d.successorRuntimeCodeHash,
            d.expectedAmount,
            ref,
            uint64(block.timestamp + 14 days + (route == 2 ? 72 hours : 0)),
            REASON,
            URI
        );
        id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ESCROW_RECOVERY_V1"),
                block.chainid,
                address(escrow),
                CLASS,
                profile,
                wallet,
                asset,
                target,
                next,
                d.successorRuntimeCodeHash,
                d.expectedAmount,
                ref.contentHash,
                p.executeAfter,
                REASON
            )
        );
    }

    function _manifestHash(IStreamRevenueEscrowRecoveryManifest.ManifestDocument memory d)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ESCROW_RECOVERY_MANIFEST_V1"),
                block.chainid,
                address(escrow),
                d
            )
        );
    }

    function _transition(R.EscrowRecoveryRecord memory p)
        private
        view
        returns (bytes32, bytes32, bytes32, bytes32)
    {
        return escrow.escrowRecoveryTransitionHashes(
            p.creditKey,
            p.successorWallet,
            p.successorProfileId,
            p.successorRuntimeCodeHash,
            p.expectedAmount,
            p.recoveryManifest,
            p.executeAfter,
            p.reasonHash,
            p.reasonURI
        );
    }

    function _scheduleData(R.EscrowRecoveryRecord memory p) private view returns (bytes memory) {
        return abi.encodeCall(
            escrow.scheduleEscrowRecovery,
            (
                p.creditKey,
                p.successorWallet,
                p.successorProfileId,
                p.successorRuntimeCodeHash,
                p.expectedAmount,
                p.recoveryManifest,
                p.executeAfter,
                p.reasonHash,
                p.reasonURI
            )
        );
    }

    function _schedule(R.EscrowRecoveryRecord memory p) private {
        (, uint64 published) = escrow.escrowRecoveryManifest(p.recoveryManifest.contentHash);
        vm.warp(uint256(published) + 14 days);
        (, bytes32 scope, bytes32 oldHash, bytes32 newHash) = _transition(p);
        _act(address(escrow), _scheduleData(p), 4, scope, oldHash, newHash);
    }

    function _safeConsent(bytes32 id, bytes32 nonce) private {
        uint64 deadline = uint64(block.timestamp + 30 days);
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamRevenueEscrow"),
                keccak256("1"),
                block.chainid,
                address(escrow)
            )
        );
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                domain,
                keccak256(
                    abi.encode(
                        keccak256(
                            "StreamEscrowRecoveryConsent(address account,bytes32 recoveryId,bytes32 nonce,uint64 deadline)"
                        ),
                        address(account),
                        id,
                        nonce,
                        deadline
                    )
                )
            )
        );
        require(
            hash == escrow.escrowRecoveryConsentDigest(address(account), id, nonce, deadline),
            "independent original digest"
        );
        escrow.submitEscrowRecoveryConsent(
            address(account),
            id,
            nonce,
            deadline,
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(hash)))
        );
    }

    // expectRevert consumes the exact failed Safe call and supplies a dummy return value.
    // Assert the returned success only on the later byte-identical successful retry.
    function _savedSafe(bytes memory data, bytes memory signature) private returns (bool) {
        return account.execTransaction(
            address(escrow), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature
        );
    }
}
