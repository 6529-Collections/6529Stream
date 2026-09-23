// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../helpers/RevenueEscrowTestMocks.sol";
import "../../mocks/MockStreamPaymentToken.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueEscrow.sol";

contract EscrowProducerHarness {
    IStreamRevenueEscrow public immutable escrow;

    constructor(IStreamRevenueEscrow escrow_) {
        escrow = escrow_;
    }

    function nativeCredit(bytes32 c, bytes32 p, address w, bool templateOrigin) external payable {
        escrow.creditNative{ value: msg.value }(c, p, w, templateOrigin);
    }

    function tokenCredit(
        bytes32 c,
        bytes32 p,
        address w,
        MockStreamPaymentToken token,
        uint256 amount,
        bool templateOrigin
    ) external {
        token.approve(address(escrow), amount);
        escrow.creditERC20(c, p, w, address(token), amount, templateOrigin);
    }
}

contract EscrowGuardProbe {
    bool public sawZero;
    bool public reentered;
    bytes32 public failureHash;

    function inspect(
        IStreamRevenueEscrow escrow,
        bytes32 c,
        bytes32 p,
        address w,
        address asset,
        bytes calldata data
    ) external {
        sawZero =
            escrow.escrowOwed(c, p, w, asset) == 0 && escrow.totalOwed(asset) == 0;
        bytes memory result;
        (reentered, result) = address(escrow).call(data);
        failureHash = keccak256(result);
    }
}

contract StreamRevenueEscrowTest is RevenueV1TestBase, OfficialSafeFixture {
    event log_named_uint(string name, uint256 value);
    bytes32 private constant CLASS = keccak256("PRIMARY_SALE");
    address private constant PAYEE = address(0xA11CE);
    StreamAssetPolicyRegistry private policy;
    StreamSplitFactory private factory;
    StreamRevenueEscrow private escrow;
    EscrowProducerHarness private producer;
    MockStreamPaymentToken private token;
    bytes32 private profile;
    address private wallet;
    uint256 private actionNonce;
    OfficialSafe private safe;
    uint256[] private safeKeys;
    event SafeSelectorObserved(address indexed target, bytes4 indexed selector, uint8 result);

    function setUp() public {
        revenueAuthority = new EscrowCallbackAuthority();
        policy = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        IStreamGasParameterHost.GasParameterConfig[3] memory configs = _walletGasConfigs();
        // The fault-injection ERC20 writes counters/callback state beyond ordinary transfer cost.
        configs[2].genesisValue = 300_000;
        configs[2].floor = 100_000;
        factory = new StreamSplitFactory(policy, address(revenueAuthority), configs);
        escrow = _escrow(12_000_000);
        producer = new EscrowProducerHarness(escrow);
        _producer(address(producer), true);
        token = new MockStreamPaymentToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("standard token"), 0);
        (profile, wallet) = factory.registerProfile(_entries(1), keccak256("escrow profile"));
        vm.deal(address(this), 100 ether);
    }

    function testNativeDeferredCreditFlushAndRecipientMoney() public {
        producer.nativeCredit{ value: 2 ether }(CLASS, profile, wallet, true);
        require(
            escrow.escrowOwed(CLASS, profile, wallet, address(0)) == 2 ether
                && escrow.totalOwed(address(0)) == 2 ether && wallet.balance == 0,
            "owed is not wallet resident"
        );
        (address captured, bytes32 fHash, bytes32 wHash) =
            escrow.escrowCreditIdentity(CLASS, profile, wallet, address(0));
        require(
            captured == address(factory) && fHash == address(factory).codehash
                && wHash == factory.splitWalletRuntimeCodeHash(),
            "captured immutable destination"
        );
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        require(
            factory.splitWalletExists(profile) && wallet.balance == 2 ether
                && escrow.escrowOwed(CLASS, profile, wallet, address(0)) == 0
                && escrow.totalOwed(address(0)) == 0,
            "flush converts owed into exact wallet receipts"
        );
        IStreamSplitWallet(wallet).release(address(0), PAYEE, payable(PAYEE));
        require(PAYEE.balance == 2 ether, "actual final native recipient");
        vm.expectRevert(abi.encodeWithSelector(IStreamRevenueEscrow.NoEscrowCredit.selector));
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
    }

    function testERC20ExactProducerPullAndDeprecatedCreditFlush() public {
        token.mint(address(producer), 1300);
        producer.tokenCredit(CLASS, profile, wallet, token, 1000, true);
        require(
            token.balanceOf(address(producer)) == 300 && token.balanceOf(address(escrow)) == 1000
                && escrow.totalOwed(address(token)) == 1000,
            "producer funds exact credit"
        );
        uint64 grace = uint64(block.timestamp + 181 days);
        _setAssetPolicy(policy, address(token), 3, keccak256("deprecated"), grace);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.EscrowAssetNotActive.selector, address(token), 3
            )
        );
        producer.tokenCredit(CLASS, profile, wallet, token, 1, true);
        escrow.flushEscrow(CLASS, profile, wallet, address(token));
        require(
            token.balanceOf(wallet) == 1000 && escrow.totalOwed(address(token)) == 0,
            "deprecation cannot erase retained credit"
        );
        IStreamSplitWallet(wallet).release(address(token), PAYEE, payable(PAYEE));
        require(token.balanceOf(PAYEE) == 1000, "flush within grace becomes releasable");
    }

    function testExpiredGraceDoesNotBlockFlushButUnobservedWalletReleaseStillRejects() public {
        token.mint(address(producer), 1000);
        producer.tokenCredit(CLASS, profile, wallet, token, 1000, true);
        uint64 grace = uint64(block.timestamp + 181 days);
        _setAssetPolicy(policy, address(token), 3, keccak256("deprecated"), grace);
        vm.warp(grace);
        escrow.flushEscrow(CLASS, profile, wallet, address(token));
        require(
            token.balanceOf(wallet) == 1000 && escrow.totalOwed(address(token)) == 0,
            "credit flush remains possible"
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamSplitWallet.AssetNotActive.selector, address(token), 3)
        );
        IStreamSplitWallet(wallet).release(address(token), PAYEE, payable(PAYEE));
        require(
            !IStreamSplitWallet(wallet).assetObservationInitialized(address(token)),
            "late unobserved receipt is not retroactive permission"
        );
    }

    function testPassiveSurplusAndPrefundedWalletStaySeparateFromOwed() public {
        (bool sent,) = payable(address(escrow)).call{ value: 3 ether }("");
        require(sent, "surplus donation");
        vm.deal(wallet, 5 ether);
        token.mint(address(escrow), 77);
        producer.nativeCredit{ value: 2 ether }(CLASS, profile, wallet, true);
        token.mint(address(producer), 1000);
        producer.tokenCredit(CLASS, profile, wallet, token, 1000, true);
        require(
            escrow.surplus(address(0)) == 3 ether && escrow.surplus(address(token)) == 77,
            "donations excluded from owed"
        );
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        escrow.flushToVerifiedWalletBestEffort(CLASS, profile, wallet, address(token));
        require(
            wallet.balance == 7 ether && token.balanceOf(wallet) == 1000
                && address(escrow).balance == 3 ether && token.balanceOf(address(escrow)) == 77,
            "separate conservation"
        );
    }

    function testKeysSeparateClassProfileAndAssetAndProducerRevocationPreservesOwed() public {
        bytes32 secondClass = keccak256("AUCTION");
        (bytes32 secondProfile, address secondWallet) =
            factory.registerProfile(_entries(1), keccak256("other"));
        producer.nativeCredit{ value: 2 ether }(CLASS, profile, wallet, true);
        producer.nativeCredit{ value: 3 ether }(secondClass, profile, wallet, true);
        producer.nativeCredit{ value: 4 ether }(CLASS, secondProfile, secondWallet, true);
        _producer(address(producer), false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.InvalidEscrowProducer.selector, address(producer)
            )
        );
        producer.nativeCredit{ value: 1 }(CLASS, profile, wallet, true);
        require(escrow.totalOwed(address(0)) == 9 ether, "revocation cannot erase aggregate owed");
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        require(
            escrow.escrowOwed(secondClass, profile, wallet, address(0)) == 3 ether
                && escrow.escrowOwed(CLASS, secondProfile, secondWallet, address(0)) == 4 ether
                && escrow.totalOwed(address(0)) == 7 ether,
            "only exact key changes"
        );
    }

    function testUnapprovedEOADelegationAndProducerCodeDriftReject() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.InvalidEscrowProducer.selector, address(this)
            )
        );
        escrow.creditNative{ value: 1 }(CLASS, profile, wallet, true);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowProducer.selector, PAYEE)
        );
        escrow.creditProducerTransitionHashes(PAYEE, true);
        address delegated = address(0xD311);
        vm.etch(delegated, abi.encodePacked(hex"ef0100", address(producer)));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowProducer.selector, delegated)
        );
        escrow.creditProducerTransitionHashes(delegated, true);
        producer.nativeCredit{ value: 1 }(CLASS, profile, wallet, true);
        vm.etch(address(producer), hex"60006000fd");
        vm.deal(address(producer), 1);
        vm.prank(address(producer));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.InvalidEscrowProducer.selector, address(producer)
            )
        );
        escrow.creditNative{ value: 1 }(CLASS, profile, wallet, true);
        require(escrow.totalOwed(address(0)) == 1, "prior credit survives code drift");
    }

    function testProducerGovernanceRejectsImmediateWrongClassMalformedAndStaleContext() public {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowProducerAction.selector)
        );
        escrow.setCreditProducer(address(producer), false);
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            escrow.creditProducerTransitionHashes(address(producer), false);
        revenueAuthority.setCurrentAction(
            true, keccak256("wrong class"), 0, scope, oldState, newState
        );
        vm.prank(address(revenueAuthority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowProducerAction.selector)
        );
        escrow.setCreditProducer(address(producer), false);
        revenueAuthority.setCurrentAction(
            true, keccak256("right class"), 1, scope, oldState, newState
        );
        revenueAuthority.setResponseMode(MockGovernedParameterAuthority.ResponseMode.Oversized);
        vm.prank(address(revenueAuthority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowProducerAction.selector)
        );
        escrow.setCreditProducer(address(producer), false);
        revenueAuthority.setResponseMode(MockGovernedParameterAuthority.ResponseMode.Canonical);
        _producer(address(producer), false);
        _producer(address(producer), true);
        revenueAuthority.setCurrentAction(true, keccak256("stale"), 1, scope, oldState, newState);
        vm.prank(address(revenueAuthority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowProducerAction.selector)
        );
        escrow.setCreditProducer(address(producer), false);
        (bool enabled,, uint64 revision) = escrow.creditProducer(address(producer));
        require(enabled && revision == 3, "ABA does not revive stale authority");
    }

    function testFixedUndeployedUnknownWrongPredictionAndPoisonRejectBeforeFunds() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.EscrowFixedWalletUndeployed.selector, profile, wallet
            )
        );
        producer.nativeCredit{ value: 1 }(CLASS, profile, wallet, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.EscrowUnknownProfile.selector, bytes32(uint256(1))
            )
        );
        producer.nativeCredit{ value: 1 }(CLASS, bytes32(uint256(1)), wallet, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.EscrowWalletMismatch.selector, profile, PAYEE
            )
        );
        producer.nativeCredit{ value: 1 }(CLASS, profile, PAYEE, true);
        vm.etch(wallet, hex"60006000fd");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.WrongCodeAtWallet.selector,
                wallet,
                factory.splitWalletRuntimeCodeHash(),
                wallet.codehash
            )
        );
        producer.nativeCredit{ value: 1 }(CLASS, profile, wallet, true);
        require(
            address(escrow).balance == 0 && escrow.totalOwed(address(0)) == 0,
            "rejected admission moves no money"
        );
    }

    function testTokenFalseNoopFeeRebaseAndMalformedResultsRollBackProducerAndCredit() public {
        token.mint(address(producer), 1000);
        for (uint8 mode = 1; mode <= 9; ++mode) {
            token.configure(mode, 1);
            vm.expectRevert(_tokenFailure(mode, true));
            producer.tokenCredit(CLASS, profile, wallet, token, 100, true);
            require(
                token.rawBalance(address(producer)) == 1000
                    && token.rawBalance(address(escrow)) == 0
                    && escrow.totalOwed(address(token)) == 0
                    && token.allowance(address(producer), address(escrow)) == 0,
                "exact transfer/approval/owed rollback"
            );
        }
    }

    function testArbitraryPayerApprovalCannotBeUsedByProducer() public {
        token.mint(address(this), 1000);
        token.approve(address(escrow), 1000);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.EscrowTransferInvariantBroken.selector, address(token)
            )
        );
        producer.tokenCredit(CLASS, profile, wallet, token, 100, true);
        require(
            token.balanceOf(address(this)) == 1000
                && token.allowance(address(this), address(escrow)) == 1000,
            "only producer itself is pulled"
        );
    }

    function testPostZeroTokenFailuresPreserveCreditTotalsAndBalances() public {
        token.mint(address(producer), 1000);
        producer.tokenCredit(CLASS, profile, wallet, token, 1000, true);
        factory.deployWallet(profile);
        for (uint8 mode = 1; mode <= 6; ++mode) {
            token.configure(mode, 2);
            vm.expectRevert(_tokenFailure(mode, false));
            escrow.flushToVerifiedWalletBestEffort(CLASS, profile, wallet, address(token));
            require(
                escrow.escrowOwed(CLASS, profile, wallet, address(token)) == 1000
                    && escrow.totalOwed(address(token)) == 1000
                    && token.rawBalance(address(escrow)) == 1000 && token.rawBalance(wallet) == 0,
                "post-zero rollback is atomic"
            );
        }
    }

    function testCallbackSeesZeroOwedAndCannotReenterEitherFlushCreditOrProducerAdmin() public {
        token.mint(address(producer), 4000);
        factory.deployWallet(profile);
        EscrowGuardProbe probe = new EscrowGuardProbe();
        bytes[] memory attempts = new bytes[](6);
        attempts[0] = abi.encodeCall(
            IStreamRevenueEscrow.flushEscrow, (CLASS, profile, wallet, address(token))
        );
        attempts[1] = abi.encodeCall(
            IStreamRevenueEscrow.flushToVerifiedWalletBestEffort,
            (CLASS, profile, wallet, address(token))
        );
        attempts[2] =
            abi.encodeCall(IStreamRevenueEscrow.creditNative, (CLASS, profile, wallet, false));
        attempts[3] =
            abi.encodeCall(IStreamRevenueEscrow.setCreditProducer, (address(producer), false));
        attempts[4] = abi.encodeCall(
            IStreamRevenueEscrow.creditERC20, (CLASS, profile, wallet, address(token), 1, false)
        );
        attempts[5] = abi.encodeCall(
            IStreamGasParameterHost.raiseGasParameter,
            (keccak256("6529STREAM_GGP_FLUSH_GAS_FLOOR"), 24_000_000)
        );
        token.mint(address(producer), 2000);
        for (uint256 i; i < attempts.length; ++i) {
            producer.tokenCredit(CLASS, profile, wallet, token, 1000, false);
            token.configureCallback(
                address(probe),
                abi.encodeCall(
                    EscrowGuardProbe.inspect,
                    (escrow, CLASS, profile, wallet, address(token), attempts[i])
                ),
                2
            );
            escrow.flushToVerifiedWalletBestEffort(CLASS, profile, wallet, address(token));
            require(
                probe.sawZero() && !probe.reentered()
                    && probe.failureHash()
                        == keccak256(
                            i == 5
                                ? abi.encodeWithSelector(
                                    IStreamGasParameterHost.GasParameterNotAuthority.selector,
                                    address(probe)
                                )
                                : abi.encodeWithSelector(
                                    ReentrancyGuard.ReentrancyGuardReentrantCall.selector
                                )
                        ),
                "callback sees CEI and shared exact guard"
            );
        }
        require(
            token.balanceOf(wallet) == 6000 && escrow.totalOwed(address(token)) == 0,
            "single transfer each time"
        );
    }

    function testNormalFloorDoesNotDisableAlreadyDeployedBestEffort() public {
        producer.nativeCredit{ value: 1 ether }(CLASS, profile, wallet, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.EscrowFixedWalletUndeployed.selector, profile, wallet
            )
        );
        escrow.flushToVerifiedWalletBestEffort(CLASS, profile, wallet, address(0));
        require(
            wallet.code.length == 0 && escrow.totalOwed(address(0)) == 1 ether,
            "best effort never deploys"
        );
        factory.deployWallet(profile);
        (bool ok,) = address(escrow).call{ gas: 2_000_000 }(
            abi.encodeCall(IStreamRevenueEscrow.flushEscrow, (CLASS, profile, wallet, address(0)))
        );
        require(
            !ok && escrow.totalOwed(address(0)) == 1 ether, "normal floor rejects before effects"
        );
        (ok,) = address(escrow).call{ gas: 2_000_000 }(
            abi.encodeCall(
                IStreamRevenueEscrow.flushToVerifiedWalletBestEffort,
                (CLASS, profile, wallet, address(0))
            )
        );
        require(
            ok && wallet.balance == 1 ether && escrow.totalOwed(address(0)) == 0,
            "independent lower-cost verified path"
        );
    }

    function testMaximum64EntryDeferredWalletFlushFitsExplicitOuterBudget() public {
        (bytes32 id, address predicted) =
            factory.registerProfile(_entries(64), keccak256("max flush"));
        producer.nativeCredit{ value: 1 ether }(CLASS, id, predicted, true);
        uint256 beforeFlush = gasleft();
        (bool ok, bytes memory result) = address(escrow).call{ gas: 16_000_000 }(
            abi.encodeCall(IStreamRevenueEscrow.flushEscrow, (CLASS, id, predicted, address(0)))
        );
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        emit log_named_uint(
            "64-entry deferred flush gas (fixture warmth,16m outer call)", beforeFlush - gasleft()
        );
        require(
            factory.splitWalletExists(id) && IStreamSplitWallet(predicted).entryCount() == 64
                && predicted.balance == 1 ether && escrow.totalOwed(address(0)) == 0,
            "maximum real wallet deployment and funding"
        );
    }

    function testMaximum64EntryDeferredWalletERC20FlushFitsExplicitOuterBudget() public {
        (bytes32 id, address predicted) =
            factory.registerProfile(_entries(64), keccak256("max token flush"));
        token.mint(address(producer), 1000);
        producer.tokenCredit(CLASS, id, predicted, token, 1000, true);
        uint256 beforeFlush = gasleft();
        (bool ok, bytes memory result) = address(escrow).call{ gas: 16_000_000 }(
            abi.encodeCall(IStreamRevenueEscrow.flushEscrow, (CLASS, id, predicted, address(token)))
        );
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        emit log_named_uint(
            "64-entry token deferred flush gas (fixture warmth,16m outer call)",
            beforeFlush - gasleft()
        );
        require(
            factory.splitWalletExists(id) && IStreamSplitWallet(predicted).entryCount() == 64
                && token.balanceOf(predicted) == 1000 && escrow.totalOwed(address(token)) == 0,
            "maximum real wallet deployment and exact token funding"
        );
    }

    function testProducerEventBindsRevisionRuntimeAndExactAction() public {
        vm.recordLogs();
        _producer(address(producer), false);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(escrow)) continue;
            require(
                logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256(
                            "EscrowProducerUpdated(uint16,address,bytes32,bytes32,bool,uint64)"
                        ) && logs[i].topics[1] == bytes32(uint256(uint160(address(producer))))
                    && logs[i].topics[2] == address(producer).codehash
                    && logs[i].topics[3] == bytes32(actionNonce),
                "exact producer transition identity"
            );
            require(
                keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), false, uint64(2))),
                "revocation leaves explicit runtime and revision"
            );
            ++count;
        }
        require(count == 1, "one producer event");
    }

    function testTokenReturnRevertBombAndGasExhaustionRestorePostZeroOwed() public {
        EscrowFaultToken hostile = new EscrowFaultToken();
        _setAssetPolicy(policy, address(hostile), 1, keccak256("hostile admitted for test"), 0);
        hostile.mint(address(producer), 1000);
        producer.tokenCredit(
            CLASS, profile, wallet, MockStreamPaymentToken(address(hostile)), 1000, true
        );
        factory.deployWallet(profile);
        for (uint8 mode = 1; mode <= 3; ++mode) {
            hostile.configure(mode);
            bytes memory prefix = new bytes(mode == 3 ? 0 : 256);
            if (mode != 3) assembly ("memory-safe") { mstore(add(prefix, 32), 17) }
            bytes memory expected = abi.encodeWithSelector(
                IStreamRevenueEscrow.EscrowExternalCallFailed.selector,
                address(hostile),
                IERC20.transfer.selector,
                mode == 3 ? 0 : 65536,
                prefix
            );
            for (uint256 path; path < 2; ++path) {
                vm.expectRevert(expected);
                if (path == 0) {
                    escrow.flushEscrow(CLASS, profile, wallet, address(hostile));
                } else {
                    escrow.flushToVerifiedWalletBestEffort(CLASS, profile, wallet, address(hostile));
                }
                require(
                    escrow.totalOwed(address(hostile)) == 1000
                        && escrow.escrowOwed(CLASS, profile, wallet, address(hostile)) == 1000
                        && hostile.balanceOf(address(escrow)) == 1000
                        && hostile.balanceOf(wallet) == 0,
                    "bounded failure restores all post-zero accounting and money"
                );
            }
        }
        hostile.configure(0);
        escrow.flushToVerifiedWalletBestEffort(CLASS, profile, wallet, address(hostile));
        require(hostile.balanceOf(wallet) == 1000, "later ordinary retry remains possible");
    }

    function testNativeFailureBombAndGasExhaustionRestoreOwedAndExactDepositCap() public {
        EscrowDepositFactory seam =
            new EscrowDepositFactory(address(revenueAuthority), address(policy));
        StreamRevenueEscrow original = escrow;
        escrow = new StreamRevenueEscrow(
            IStreamSplitFactory(address(seam)),
            address(revenueAuthority),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3)
        );
        EscrowProducerHarness sender = new EscrowProducerHarness(escrow);
        _producer(address(sender), true);
        EscrowDepositWallet receiver = seam.wallet();
        bytes32 id = bytes32(uint256(1));
        sender.nativeCredit{ value: 1 ether }(CLASS, id, address(receiver), false);
        for (uint8 mode = 1; mode <= 3; mode += 2) {
            receiver.configure(mode, escrow, CLASS);
            bytes memory prefix = new bytes(mode == 3 ? 0 : 256);
            if (mode == 1) assembly ("memory-safe") { mstore(add(prefix, 32), 17) }
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamRevenueEscrow.EscrowExternalCallFailed.selector,
                    address(receiver),
                    bytes4(0),
                    mode == 3 ? 0 : 65536,
                    prefix
                )
            );
            escrow.flushToVerifiedWalletBestEffort(CLASS, id, address(receiver), address(0));
            require(
                escrow.totalOwed(address(0)) == 1 ether && address(receiver).balance == 0
                    && address(escrow).balance == 1 ether,
                "failed deposit cannot erase owed"
            );
        }
        receiver.configure(2, escrow, CLASS); // Successful native returndata is deliberately ignored.
        escrow.flushToVerifiedWalletBestEffort(CLASS, id, address(receiver), address(0));
        require(
            receiver.entryGas() <= 300_000 && receiver.entryGas() > 295_000 && receiver.sawZero()
                && address(receiver).balance == 1 ether && escrow.totalOwed(address(0)) == 0,
            "full GGP cap includes value stipend; exact destination"
        );
        escrow = original;
    }

    function testInsufficientGasForCurrentDepositCapAndActualDeploymentOOGPreserveCredit() public {
        // Deliberately unsafe governance configuration: prove post-zero rollback even when
        // the normal admission floor was configured far below real deployment requirements.
        escrow = _escrow(1);
        producer = new EscrowProducerHarness(escrow);
        _producer(address(producer), true);
        producer.nativeCredit{ value: 1 ether }(CLASS, profile, wallet, true);
        (bool ok, bytes memory result) = address(escrow).call{ gas: 2_300_000 }(
            abi.encodeCall(IStreamRevenueEscrow.flushEscrow, (CLASS, profile, wallet, address(0)))
        );
        require(
            !ok && bytes4(result) == IStreamRevenueEscrow.EscrowExternalCallFailed.selector,
            "actual bounded factory deployment exhaustion is detected"
        );
        require(
            wallet.code.length == 0 && escrow.totalOwed(address(0)) == 1 ether
                && address(escrow).balance == 1 ether && !factory.splitWalletExists(profile),
            "CREATE2 and all escrow effects roll back"
        );
        factory.deployWallet(profile);
        (ok, result) = address(escrow).call{ gas: 200_000 }(
            abi.encodeCall(
                IStreamRevenueEscrow.flushToVerifiedWalletBestEffort,
                (CLASS, profile, wallet, address(0))
            )
        );
        require(
            !ok && bytes4(result) == IStreamRevenueEscrow.InsufficientEscrowCallGas.selector
                && escrow.totalOwed(address(0)) == 1 ether && wallet.balance == 0,
            "underfunded outer call never silently underforwards live cap"
        );
        escrow.flushToVerifiedWalletBestEffort(CLASS, profile, wallet, address(0));
        require(wallet.balance == 1 ether, "adequately funded retry succeeds");
    }

    function testCreditAndFlushEventsBindExactKeyAmountsAndCapturedWalletRuntime() public {
        vm.recordLogs();
        producer.nativeCredit{ value: 2 ether }(CLASS, profile, wallet, true);
        producer.nativeCredit{ value: 3 ether }(CLASS, profile, wallet, true);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(escrow)) continue;
            require(
                logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256(
                            "EscrowCreditCreated(bytes32,bytes32,address,uint16,address,uint256,uint256,bytes32)"
                        ) && logs[i].topics[1] == CLASS && logs[i].topics[2] == profile
                    && logs[i].topics[3] == bytes32(uint256(uint160(wallet))),
                "exact credit event identity"
            );
            (uint16 schema, address asset, uint256 amount, uint256 owed, bytes32 runtime) =
                abi.decode(logs[i].data, (uint16, address, uint256, uint256, bytes32));
            require(
                schema == 1 && asset == address(0) && amount == (count == 0 ? 2 ether : 3 ether)
                    && owed == (count == 0 ? 2 ether : 5 ether)
                    && runtime == factory.splitWalletRuntimeCodeHash(),
                "event wallet commitment and cumulative key amount"
            );
            ++count;
        }
        require(count == 2, "one event per official credit");
        vm.recordLogs();
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        logs = vm.getRecordedLogs();
        count = 0;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(escrow)) continue;
            require(
                logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256(
                            "EscrowFlushed(bytes32,bytes32,address,uint16,address,uint256,uint256)"
                        ) && logs[i].topics[1] == CLASS && logs[i].topics[2] == profile
                    && logs[i].topics[3] == bytes32(uint256(uint160(wallet))),
                "exact flush event identity"
            );
            require(
                keccak256(logs[i].data)
                    == keccak256(abi.encode(uint16(1), address(0), 5 ether, uint256(0))),
                "one exact amount and zero remaining"
            );
            ++count;
        }
        require(count == 1, "one flush event");
    }

    function testActualSafeProducerCreditsAndPermissionlessFlushPayRealSafe() public {
        _setupSafe();
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] =
            IStreamSplitWallet.SplitEntry(address(safe), 1_000_000, keccak256("Safe payee"));
        (bytes32 id, address target) = factory.registerProfile(entries, keccak256("Safe escrow"));
        _safeReject(
            abi.encodeCall(IStreamRevenueEscrow.creditNative, (CLASS, id, target, true)),
            abi.encodeWithSelector(
                IStreamRevenueEscrow.InvalidEscrowProducer.selector, address(safe)
            )
        );
        _producer(address(safe), true);
        vm.deal(address(safe), 3 ether);
        _safeExec(address(escrow), 1 ether, bytes(""));
        _safeExec(
            address(escrow),
            2 ether,
            abi.encodeCall(IStreamRevenueEscrow.creditNative, (CLASS, id, target, true))
        );
        require(
            escrow.totalOwed(address(0)) == 2 ether && escrow.surplus(address(0)) == 1 ether,
            "actual Safe credits versus passive receipts"
        );
        _safeExec(
            address(escrow),
            0,
            abi.encodeCall(IStreamRevenueEscrow.flushEscrow, (CLASS, id, target, address(0)))
        );
        _safeExec(
            target,
            0,
            abi.encodeCall(
                IStreamSplitWallet.release, (address(0), address(safe), payable(address(safe)))
            )
        );
        require(
            address(safe).balance == 2 ether && escrow.totalOwed(address(0)) == 0,
            "real native payout returned to Safe"
        );
        token.mint(address(safe), 1000);
        _safeExec(
            address(token),
            0,
            abi.encodeCall(MockStreamPaymentToken.approve, (address(escrow), 1000))
        );
        _safeExec(
            address(escrow),
            0,
            abi.encodeCall(
                IStreamRevenueEscrow.creditERC20, (CLASS, id, target, address(token), 1000, false)
            )
        );
        require(
            token.balanceOf(address(safe)) == 0 && escrow.totalOwed(address(token)) == 1000,
            "actual Safe owns first allowance pull"
        );
        _safeExec(
            address(escrow),
            0,
            abi.encodeCall(
                IStreamRevenueEscrow.flushToVerifiedWalletBestEffort,
                (CLASS, id, target, address(token))
            )
        );
        _safeExec(
            target,
            0,
            abi.encodeCall(
                IStreamSplitWallet.release, (address(token), address(safe), payable(address(safe)))
            )
        );
        require(
            token.balanceOf(address(safe)) == 1000 && escrow.totalOwed(address(token)) == 0,
            "real ERC20 payout returned to Safe"
        );
    }

    function testActualSafeAll22ViewsAndIntentionalGovernanceOnlyRejections() public {
        _setupSafe();
        producer.nativeCredit{ value: 1 }(CLASS, profile, wallet, true);
        bytes32 id = keccak256("6529STREAM_GGP_FLUSH_GAS_FLOOR");
        bytes[] memory reads = new bytes[](22);
        reads[0] = abi.encodeWithSignature("FAILURE_CLASS_FAIL_CLOSED_PRECHECK()");
        reads[1] = abi.encodeWithSignature("FAILURE_CLASS_FORWARDING_CAP()");
        reads[2] = abi.encodeWithSignature("FAILURE_CLASS_MIN_GAS_GATE()");
        reads[3] = abi.encodeWithSignature("FAILURE_CLASS_NONE()");
        reads[4] = abi.encodeWithSignature("GAS_PARAMETER_SCHEMA_VERSION()");
        reads[5] = abi.encodeWithSignature("SCHEMA_VERSION()");
        reads[6] = abi.encodeWithSignature("assetPolicyRegistry()");
        reads[7] = abi.encodeCall(IStreamRevenueEscrow.creditProducer, (address(producer)));
        reads[8] = abi.encodeCall(
            IStreamRevenueEscrow.creditProducerTransitionHashes, (address(producer), false)
        );
        reads[9] = abi.encodeCall(
            IStreamRevenueEscrow.escrowCreditIdentity, (CLASS, profile, wallet, address(0))
        );
        reads[10] =
            abi.encodeCall(IStreamRevenueEscrow.escrowOwed, (CLASS, profile, wallet, address(0)));
        reads[11] = abi.encodeWithSignature("factoryCodeHash()");
        reads[12] = abi.encodeCall(IStreamGasParameterHost.gasParameter, (id));
        reads[13] = abi.encodeCall(IStreamRevenueEscrow.gasParameterFloor, (id));
        reads[14] = abi.encodeCall(IStreamGasParameterHost.gasParameterIds, ());
        reads[15] = abi.encodeCall(IStreamGasParameterHost.gasParameterInfo, (id));
        reads[16] = abi.encodeCall(IStreamGasParameterHost.governanceAuthority, ());
        reads[17] = abi.encodeWithSignature("registryCodeHash()");
        reads[18] = abi.encodeWithSignature("splitFactory()");
        reads[19] = abi.encodeCall(IStreamRevenueEscrow.surplus, (address(0)));
        reads[20] = abi.encodeCall(IStreamRevenueEscrow.totalOwed, (address(0)));
        reads[21] = abi.encodeWithSignature("walletCodeHash()");
        for (uint256 i; i < reads.length; ++i) {
            (bool ok, bytes memory baseline) = address(escrow).staticcall(reads[i]);
            vm.prank(address(safe));
            (bool safeOk, bytes memory actual) = address(escrow).staticcall(reads[i]);
            require(
                ok && safeOk && baseline.length != 0 && keccak256(actual) == keccak256(baseline),
                "every actual Safe read returns public values"
            );
            _safeExec(address(escrow), 0, reads[i]);
        }
        _safeReject(
            abi.encodeCall(IStreamRevenueEscrow.setCreditProducer, (address(producer), false)),
            abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowProducerAction.selector)
        );
        _safeReject(
            abi.encodeCall(IStreamGasParameterHost.raiseGasParameter, (id, 24_000_000)),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(safe)
            )
        );
        require(
            escrow.gasParameter(id) == 12_000_000 && escrow.totalOwed(address(0)) == 1,
            "Safe cannot bypass actual Executor authority"
        );
    }

    function testGasFloorRegistrationAndExactDelayedRaiseLeaveBestEffortUsable() public {
        bytes32 id = keccak256("6529STREAM_GGP_FLUSH_GAS_FLOOR");
        (uint256 value, uint256 floor, uint8 kind, uint64 revision) = escrow.gasParameterInfo(id);
        require(
            value == 12_000_000 && floor == value && kind == 3 && revision == 1,
            "constructor requires explicit minimum-gas parameter"
        );
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(escrow),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        revenueAuthority.setCurrentAction(
            true,
            keccak256("raise flush"),
            1,
            scope,
            keccak256(abi.encode(domain, scope, value, floor, kind, revision)),
            keccak256(abi.encode(domain, scope, uint256(24_000_000), floor, kind, uint64(2)))
        );
        vm.prank(address(revenueAuthority));
        escrow.raiseGasParameter(id, 24_000_000);
        require(
            escrow.gasParameter(id) == 24_000_000 && escrow.gasParameterFloor(id) == floor,
            "host monotonic raise keeps original floor"
        );
        producer.nativeCredit{ value: 1 ether }(CLASS, profile, wallet, true);
        factory.deployWallet(profile);
        (bool ok,) = address(escrow).call{ gas: 2_000_000 }(
            abi.encodeCall(
                IStreamRevenueEscrow.flushToVerifiedWalletBestEffort,
                (CLASS, profile, wallet, address(0))
            )
        );
        require(
            ok && wallet.balance == 1 ether, "raised normal floor cannot disable independent path"
        );
    }

    function testFuzzNativeCreditsConserveAggregateAndPassiveSurplus(uint96 first, uint96 second)
        public
    {
        uint256 a = uint256(first) + 1;
        uint256 b = uint256(second) + 1;
        vm.deal(address(this), a + b + 7);
        (bool sent,) = address(escrow).call{ value: 7 }("");
        require(sent, "donation");
        producer.nativeCredit{ value: a }(CLASS, profile, wallet, true);
        producer.nativeCredit{ value: b }(CLASS, profile, wallet, true);
        require(
            escrow.escrowOwed(CLASS, profile, wallet, address(0)) == a + b
                && escrow.totalOwed(address(0)) == a + b && escrow.surplus(address(0)) == 7,
            "credit conservation"
        );
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        require(
            wallet.balance == a + b && escrow.totalOwed(address(0)) == 0
                && address(escrow).balance == 7,
            "flush conservation"
        );
    }

    function testTokenCallbackCannotReplaceActivePolicyBeforeCreditCommit() public {
        token.mint(address(producer), 1000);
        bytes32 nextPolicy = keccak256("inactive after independently authorized callback");
        _prepareAssetPolicy(policy, address(token), 2, nextPolicy, 0);
        token.configureCallback(
            address(revenueAuthority),
            abi.encodeCall(
                EscrowCallbackAuthority.execute,
                (
                    address(policy),
                    abi.encodeCall(
                        IStreamAssetPolicyRegistry.setAssetStatus,
                        (address(token), 2, nextPolicy, uint64(0))
                    )
                )
            ),
            1
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.EscrowAssetNotActive.selector, address(token), uint256(2)
            )
        );
        producer.tokenCredit(CLASS, profile, wallet, token, 1000, true);
        require(
            policy.assetStatus(address(token)) == 1 && token.balanceOf(address(producer)) == 1000
                && token.balanceOf(address(escrow)) == 0 && escrow.totalOwed(address(token)) == 0
                && !token.callbackSucceeded(),
            "policy, transfer, callback and credit roll back together"
        );
    }

    function testInheritedScheduledRaiseDuringCallbackPreservesCachedTransferAndOwed() public {
        token.mint(address(producer), 1000);
        producer.tokenCredit(CLASS, profile, wallet, token, 1000, true);
        factory.deployWallet(profile);
        bytes32 id = keccak256("6529STREAM_GGP_FLUSH_GAS_FLOOR");
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(escrow),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        revenueAuthority.setCurrentAction(
            true,
            keccak256("scheduled callback raise"),
            1,
            scope,
            keccak256(
                abi.encode(
                    domain, scope, uint256(12_000_000), uint256(12_000_000), uint8(3), uint64(1)
                )
            ),
            keccak256(
                abi.encode(
                    domain, scope, uint256(24_000_000), uint256(12_000_000), uint8(3), uint64(2)
                )
            )
        );
        token.configureCallback(
            address(revenueAuthority),
            abi.encodeCall(
                EscrowCallbackAuthority.execute,
                (
                    address(escrow),
                    abi.encodeCall(IStreamGasParameterHost.raiseGasParameter, (id, 24_000_000))
                )
            ),
            2
        );
        escrow.flushEscrow(CLASS, profile, wallet, address(token));
        require(
            token.callbackSucceeded() && escrow.gasParameter(id) == 24_000_000
                && token.balanceOf(wallet) == 1000 && escrow.totalOwed(address(token)) == 0,
            "inherited raise is separately authorized and does not redirect or duplicate transfer"
        );
    }

    function testConstructorRejectsDelegatedFactoryAndRegistryAndMalformedGasConfig() public {
        IStreamGasParameterHost.GasParameterConfig memory config =
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", 12_000_000, 12_000_000, 3);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowConfiguration.selector)
        );
        new StreamRevenueEscrow(
            IStreamSplitFactory(address(0x123)), address(revenueAuthority), config
        );
        address delegated = address(0xD311);
        vm.etch(delegated, abi.encodePacked(hex"ef0100", address(factory)));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowConfiguration.selector)
        );
        new StreamRevenueEscrow(IStreamSplitFactory(delegated), address(revenueAuthority), config);
        bytes memory registryCode = address(policy).code;
        vm.etch(address(policy), abi.encodePacked(hex"ef0100", address(0x123)));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowConfiguration.selector)
        );
        new StreamRevenueEscrow(factory, address(revenueAuthority), config);
        vm.etch(address(policy), registryCode);
        config.failureClass = 2;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector,
                keccak256("6529STREAM_GGP_FLUSH_GAS_FLOOR")
            )
        );
        new StreamRevenueEscrow(factory, address(revenueAuthority), config);
        config.failureClass = 3;
        config.name = "OTHER_FLOOR";
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector,
                keccak256("6529STREAM_GGP_FLUSH_GAS_FLOOR")
            )
        );
        new StreamRevenueEscrow(factory, address(revenueAuthority), config);
    }

    function testCapturedFactoryOrWalletCodeDriftCannotMoveOrEraseOwed() public {
        producer.nativeCredit{ value: 1 ether }(CLASS, profile, wallet, true);
        bytes memory factoryCode = address(factory).code;
        vm.etch(address(factory), hex"60006000fd");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.EscrowFactoryCodeChanged.selector, address(factory)
            )
        );
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        require(escrow.totalOwed(address(0)) == 1 ether, "factory drift preserves owed");
        vm.etch(address(factory), factoryCode);
        vm.etch(wallet, hex"60006000fd");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.WrongCodeAtWallet.selector,
                wallet,
                escrow.walletCodeHash(),
                wallet.codehash
            )
        );
        escrow.flushEscrow(CLASS, profile, wallet, address(0));
        require(
            escrow.escrowOwed(CLASS, profile, wallet, address(0)) == 1 ether
                && escrow.totalOwed(address(0)) == 1 ether && address(escrow).balance == 1 ether
                && wallet.balance == 0,
            "poisoned destination reverts after zeroing without losing accounting"
        );
    }

    function testZeroCreditsAndRegistryCodeDriftRejectBeforeTransfers() public {
        vm.expectRevert(abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowCredit.selector));
        producer.nativeCredit(CLASS, profile, wallet, true);
        vm.expectRevert(abi.encodeWithSelector(IStreamRevenueEscrow.InvalidEscrowCredit.selector));
        producer.nativeCredit{ value: 1 }(bytes32(0), profile, wallet, true);
        token.mint(address(producer), 1000);
        vm.etch(address(policy), hex"60006000fd");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueEscrow.EscrowReadFailed.selector,
                address(policy),
                IStreamAssetPolicyRegistry.assetStatus.selector
            )
        );
        producer.tokenCredit(CLASS, profile, wallet, token, 1000, true);
        require(
            token.balanceOf(address(producer)) == 1000 && token.balanceOf(address(escrow)) == 0
                && escrow.totalOwed(address(token)) == 0,
            "code pin fails before pulling funds"
        );
    }

    function _tokenFailure(uint8 mode, bool pull) private view returns (bytes memory) {
        if (mode >= 7) {
            return abi.encodeWithSelector(
                IStreamRevenueEscrow.EscrowReadFailed.selector,
                address(token),
                IERC20.balanceOf.selector
            );
        }
        if (mode == 5) {
            return abi.encodeWithSelector(
                IStreamRevenueEscrow.EscrowExternalCallFailed.selector,
                address(token),
                pull ? IERC20.transferFrom.selector : IERC20.transfer.selector,
                uint256(0),
                bytes("")
            );
        }
        return abi.encodeWithSelector(
            IStreamRevenueEscrow.EscrowTransferInvariantBroken.selector, address(token)
        );
    }

    function _setupSafe() private {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0x101;
        owners[1] = 0x102;
        owners[2] = 0x103;
        safeKeys.push(owners[0]);
        safeKeys.push(owners[1]);
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 444);
    }

    function _safeExec(address target, uint256 value, bytes memory data) private {
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(executeSafe(safe, safeKeys, target, value, data, 0), "actual Safe call");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool success;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe) && logs[i].topics.length != 0
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) success = true;
        }
        require(success && safe.nonce() == nonce + 1, "actual Safe success event and nonce");
        emit SafeSelectorObserved(target, bytes4(data), 1);
    }

    function _safeReject(bytes memory data, bytes memory expected) private {
        vm.prank(address(safe));
        (bool ok, bytes memory reason) = address(escrow).call(data);
        require(!ok && keccak256(reason) == keccak256(expected), "exact target authorization error");
        uint256 nonce = safe.nonce();
        bytes32 digest = safe.getTransactionHash(
            address(escrow), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signature = safeThresholdSignature(safeKeys, digest);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        safe.execTransaction(
            address(escrow), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature
        );
        require(safe.nonce() == nonce, "Safe failure preserves nonce");
        emit SafeSelectorObserved(address(escrow), bytes4(data), 2);
    }

    function _escrow(uint256 floor) private returns (StreamRevenueEscrow) {
        return new StreamRevenueEscrow(
            factory,
            address(revenueAuthority),
            IStreamGasParameterHost.GasParameterConfig("FLUSH_GAS_FLOOR", floor, floor, 3)
        );
    }

    function _producer(address who, bool enabled) private {
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            escrow.creditProducerTransitionHashes(who, enabled);
        revenueAuthority.setCurrentAction(
            true, bytes32(++actionNonce), 1, scope, oldState, newState
        );
        vm.prank(address(revenueAuthority));
        escrow.setCreditProducer(who, enabled);
        revenueAuthority.setCurrentAction(false, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
    }

    function _entries(uint256 n)
        private
        pure
        returns (IStreamSplitWallet.SplitEntry[] memory entries)
    {
        entries = new IStreamSplitWallet.SplitEntry[](n);
        for (uint256 i; i < n; ++i) {
            entries[i] = IStreamSplitWallet.SplitEntry(
                n == 1 ? PAYEE : address(uint160(0x1000 + i)),
                uint32(i == n - 1 ? 1_000_000 - (n - 1) : 1),
                bytes32(i + 1)
            );
        }
    }
}
