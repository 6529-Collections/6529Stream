// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/revenue/StreamClaimRouter.sol";
import "../../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import "../../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/RevenueV1TestBase.sol";

contract ClaimToken {
    mapping(address => uint256) public balanceOf;
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}

contract ClaimWalletAdversary {
    uint8 public syncMode;
    uint8 public releaseMode;
    uint256 public syncCalls;
    uint256 public releaseCalls;
    address public lastAccount;
    address public lastRecipient;
    error WalletFailure(uint256 marker);

    function configure(uint8 syncMode_, uint8 releaseMode_) external {
        syncMode = syncMode_;
        releaseMode = releaseMode_;
    }

    fallback() external {
        uint8 mode;
        if (msg.sig == IStreamSplitWallet.syncAsset.selector) {
            ++syncCalls;
            mode = syncMode;
        } else {
            require(msg.sig == IStreamSplitWallet.release.selector, "unexpected selector");
            (, lastAccount, lastRecipient) = abi.decode(msg.data[4:], (address, address, address));
            ++releaseCalls;
            mode = releaseMode;
        }
        if (mode == 1) revert WalletFailure(123);
        if (mode == 7) assembly { invalid() }
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, 77)
            switch mode
            case 2 { return(ptr, 0) }
            case 3 { return(ptr, 31) }
            case 4 { return(ptr, 64) }
            case 5 { return(ptr, 65536) }
            case 6 { revert(ptr, 65536) }
            case 8 { mstore(ptr, 0) }
            default { }
            return(ptr, 32)
        }
    }
}

contract ClaimReentrantRecipient {
    IStreamClaimRouter private immutable _router;
    address private _first;
    address private _second;
    bool private _entered;
    uint256 public nestedFirst;
    uint256 public nestedSecond;

    constructor(IStreamClaimRouter router) {
        _router = router;
    }

    function configure(address first, address second) external {
        _first = first;
        _second = second;
    }

    receive() external payable {
        if (_entered) return;
        _entered = true;
        IStreamClaimRouter.ClaimCall[] memory claims = new IStreamClaimRouter.ClaimCall[](2);
        claims[0] = IStreamClaimRouter.ClaimCall(_first, address(0), address(this));
        claims[1] = IStreamClaimRouter.ClaimCall(_second, address(0), address(this));
        uint256[] memory amounts = _router.claimMany(claims, true);
        nestedFirst = amounts[0];
        nestedSecond = amounts[1];
    }
}

contract StreamClaimRouterTest is RevenueV1TestBase {
    event log_named_uint(string key, uint256 value);
    address private constant ACCOUNT = address(0xA11CE);
    address private constant CALLER = address(0xCA11);
    bytes32 private constant CREATED =
        keccak256("SplitProfileCreated(bytes32,bytes32,bytes32,uint16,uint16,address)");
    bytes32 private constant ENTRY =
        keccak256("SplitProfileEntry(bytes32,uint16,address,uint32,bytes32)");
    bytes32 private constant TRANSFER = keccak256("Transfer(address,address,uint256)");
    bytes32 private constant FAILED =
        keccak256("ClaimFailed(address,address,address,uint16,uint256,bytes4,uint256,bytes)");

    struct Failure {
        address wallet;
        address asset;
        address account;
        uint16 schema;
        uint256 index;
        bytes4 operation;
        uint256 size;
        bytes reason;
    }

    StreamClaimRouter private router;
    StreamAssetPolicyRegistry private policy;
    StreamSplitFactory private factory;
    ClaimToken private token;

    function setUp() public {
        router = new StreamClaimRouter();
        policy = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        factory = new StreamSplitFactory(policy, address(revenueAuthority), _walletGasConfigs());
        token = new ClaimToken();
        _setAssetPolicy(
            policy, address(token), policy.ASSET_STATUS_ACTIVE(), keccak256("standard"), 0
        );
    }

    function testExactTwoSelectorsAndEmptyBatches() public {
        require(
            IStreamClaimRouter.claimMany.selector
                == bytes4(keccak256("claimMany((address,address,address)[],bool)")),
            "claim ABI"
        );
        require(
            IStreamClaimRouter.syncAndClaimMany.selector
                == bytes4(keccak256("syncAndClaimMany((address,address,address)[],bool)")),
            "sync ABI"
        );
        IStreamClaimRouter.ClaimCall[] memory empty = new IStreamClaimRouter.ClaimCall[](0);
        require(router.claimMany(empty, false).length == 0, "empty claim");
        require(router.syncAndClaimMany(empty, true).length == 0, "empty sync");
    }

    function testTwentyEventDiscoveredWalletsNativeAndDirectTokenClaims() public {
        // Inputs to claimMany come from factory events, not the creation return values.
        vm.recordLogs();
        for (uint256 i; i < 20; ++i) {
            _wallet(i, ACCOUNT);
        }
        IStreamClaimRouter.ClaimCall[] memory claims = _discover(vm.getRecordedLogs());
        require(claims.length == 20, "all entitled wallets discovered");
        for (uint256 i; i < claims.length; ++i) {
            vm.deal(claims[i].wallet, (i + 1) * 1 ether);
        }
        vm.prank(CALLER);
        uint256 beforeClaim = gasleft();
        uint256[] memory amounts = router.claimMany{ gas: 16_000_000 }(claims, false);
        emit log_named_uint(
            "20-wallet native claim subcall gas (fixture access warmth)", beforeClaim - gasleft()
        );
        require(ACCOUNT.balance == 210 ether && CALLER.balance == 0, "native recipient");
        for (uint256 i; i < 20; ++i) {
            require(amounts[i] == (i + 1) * 1 ether, "ordered amount");
            IStreamSplitWallet wallet = IStreamSplitWallet(claims[i].wallet);
            require(wallet.accountReleased(address(0), ACCOUNT) == amounts[i], "wallet accounting");
            require(claims[i].wallet.balance == 0, "wallet drained to entitled account");
        }
        // Direct ERC-20 receipt discovery and sync are a separate explicit operation.
        vm.recordLogs();
        token.mint(claims[0].wallet, 1234);
        Vm.Log[] memory transfers = vm.getRecordedLogs();
        require(transfers.length == 1 && transfers[0].emitter == address(token), "token emitter");
        require(transfers[0].topics[0] == TRANSFER, "transfer event");
        address discovered = address(uint160(uint256(transfers[0].topics[2])));
        require(discovered == claims[0].wallet, "received wallet discovered");
        require(
            !IStreamSplitWallet(discovered).assetObservationInitialized(address(token)), "unsynced"
        );
        IStreamClaimRouter.ClaimCall[] memory one = _one(discovered, address(token), ACCOUNT);
        uint256[] memory paid = router.syncAndClaimMany(one, false);
        require(paid[0] == 1234 && token.balanceOf(ACCOUNT) == 1234, "direct token claim");
        require(
            IStreamSplitWallet(discovered).assetObservationInitialized(address(token)), "synced"
        );
        require(address(router).balance == 0 && token.balanceOf(address(router)) == 0, "no custody");
    }

    function testTwentyWalletsSyncAndClaimERC20() public {
        vm.recordLogs();
        for (uint256 i; i < 20; ++i) {
            _wallet(i, ACCOUNT);
        }
        IStreamClaimRouter.ClaimCall[] memory claims = _discover(vm.getRecordedLogs());
        for (uint256 i; i < 20; ++i) {
            claims[i].asset = address(token);
            token.mint(claims[i].wallet, i + 1);
        }
        vm.prank(CALLER);
        uint256 beforeClaim = gasleft();
        uint256[] memory amounts = router.syncAndClaimMany{ gas: 16_000_000 }(claims, true);
        emit log_named_uint(
            "20-wallet ERC20 sync/claim subcall gas (fixture access warmth)",
            beforeClaim - gasleft()
        );
        require(token.balanceOf(ACCOUNT) == 210, "twenty token transfers");
        for (uint256 i; i < 20; ++i) {
            require(amounts[i] == i + 1, "token amount");
            require(
                IStreamSplitWallet(claims[i].wallet).accountReleased(address(token), ACCOUNT)
                    == i + 1,
                "token accounting"
            );
        }
    }

    function testNoArtificialTwentyItemLimit() public {
        ClaimWalletAdversary wallet = new ClaimWalletAdversary();
        IStreamClaimRouter.ClaimCall[] memory claims = new IStreamClaimRouter.ClaimCall[](33);
        for (uint256 i; i < 33; ++i) {
            claims[i] = IStreamClaimRouter.ClaimCall(address(wallet), address(0), ACCOUNT);
        }
        uint256[] memory amounts = router.claimMany(claims, false);
        require(amounts.length == 33 && wallet.releaseCalls() == 33, "no fixed batch cap");
        require(
            wallet.lastRecipient() == ACCOUNT && wallet.lastAccount() == ACCOUNT,
            "release to self only"
        );
    }

    function testPausedAssetFailureContinuesToLaterNativeClaim() public {
        address first = _wallet(1, ACCOUNT);
        address later = _wallet(2, ACCOUNT);
        token.mint(first, 500);
        vm.deal(later, 2 ether);
        _setAssetPolicy(
            policy, address(token), policy.ASSET_STATUS_INACTIVE(), keccak256("paused"), 0
        );
        IStreamClaimRouter.ClaimCall[] memory claims = _two(first, later, ACCOUNT);
        claims[0].asset = address(token);
        vm.recordLogs();
        uint256[] memory amounts = router.syncAndClaimMany(claims, true);
        require(amounts[0] == 0 && amounts[1] == 2 ether, "later claim succeeds");
        require(token.balanceOf(first) == 500 && ACCOUNT.balance == 2 ether, "real money isolated");
        Failure memory failure = _onlyFailure(vm.getRecordedLogs());
        require(
            failure.wallet == first && failure.asset == address(token)
                && failure.account == ACCOUNT,
            "failure identity"
        );
        require(
            failure.schema == 1 && failure.index == 0
                && failure.operation == IStreamSplitWallet.syncAsset.selector,
            "failed sync"
        );
        require(
            keccak256(failure.reason)
                == keccak256(
                    abi.encodeWithSelector(
                        IStreamSplitWallet.AssetNotActive.selector,
                        address(token),
                        policy.ASSET_STATUS_INACTIVE()
                    )
                ),
            "exact reason"
        );
    }

    function testAtomicLateFailureRollsBackNativeTransfersAccountingAndEvents() public {
        address first = _wallet(1, ACCOUNT);
        address empty = _wallet(2, ACCOUNT);
        vm.deal(first, 1 ether);
        IStreamClaimRouter.ClaimCall[] memory claims = _two(first, empty, ACCOUNT);
        bytes memory reason = abi.encodeWithSelector(
            IStreamSplitWallet.NoReleasableFunds.selector, address(0), ACCOUNT
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamClaimRouter.ClaimCallFailed.selector,
                1,
                empty,
                IStreamSplitWallet.release.selector,
                reason.length,
                reason
            )
        );
        router.claimMany(claims, false);
        require(first.balance == 1 ether && ACCOUNT.balance == 0, "native rollback");
        require(IStreamSplitWallet(first).totalReleased(address(0)) == 0, "accounting rollback");
        require(
            !IStreamSplitWallet(first).assetObservationInitialized(address(0)),
            "observation rollback"
        );
    }

    function testAtomicLateFailureRollsBackTokenTransfersAndSync() public {
        address first = _wallet(1, ACCOUNT);
        address empty = _wallet(2, ACCOUNT);
        token.mint(first, 900);
        IStreamClaimRouter.ClaimCall[] memory claims = _two(first, empty, ACCOUNT);
        claims[0].asset = address(token);
        claims[1].asset = address(token);
        bytes memory reason = abi.encodeWithSelector(
            IStreamSplitWallet.NoReleasableFunds.selector, address(token), ACCOUNT
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamClaimRouter.ClaimCallFailed.selector,
                1,
                empty,
                IStreamSplitWallet.release.selector,
                reason.length,
                reason
            )
        );
        router.syncAndClaimMany(claims, false);
        require(token.balanceOf(first) == 900 && token.balanceOf(ACCOUNT) == 0, "token rollback");
        require(
            IStreamSplitWallet(first).totalReleased(address(token)) == 0,
            "token accounting rollback"
        );
        require(
            !IStreamSplitWallet(first).assetObservationInitialized(address(token)),
            "first sync rollback"
        );
        require(
            !IStreamSplitWallet(empty).assetObservationInitialized(address(token)),
            "second sync rollback"
        );
    }

    function testContinueRetainsSuccessfulSyncWhenReleaseHasNoEntitlement() public {
        address wallet = _wallet(1, CALLER);
        token.mint(wallet, 500);
        vm.recordLogs();
        uint256[] memory amounts =
            router.syncAndClaimMany(_one(wallet, address(token), ACCOUNT), true);
        require(amounts[0] == 0 && token.balanceOf(wallet) == 500, "no unauthorized transfer");
        require(
            IStreamSplitWallet(wallet).assetObservationInitialized(address(token)),
            "successful sync persists"
        );
        require(
            IStreamSplitWallet(wallet).lastObservedReceived(address(token)) == 500,
            "observed amount persists"
        );
        require(
            _onlyFailure(vm.getRecordedLogs()).operation == IStreamSplitWallet.release.selector,
            "release failure recorded"
        );
    }

    function testSyncFailureSkipsReleaseAndEventsOnce() public {
        ClaimWalletAdversary wallet = new ClaimWalletAdversary();
        wallet.configure(1, 0);
        vm.recordLogs();
        uint256[] memory amounts =
            router.syncAndClaimMany(_one(address(wallet), address(0), ACCOUNT), true);
        require(amounts[0] == 0 && wallet.releaseCalls() == 0, "release skipped");
        Failure memory failure = _onlyFailure(vm.getRecordedLogs());
        require(
            failure.operation == IStreamSplitWallet.syncAsset.selector && failure.size == 36,
            "sync error"
        );
    }

    function testEOAAndZeroAddressAreFailures() public {
        IStreamClaimRouter.ClaimCall[] memory claims = _two(address(0), CALLER, ACCOUNT);
        vm.recordLogs();
        uint256[] memory amounts = router.claimMany(claims, true);
        require(amounts[0] == 0 && amounts[1] == 0, "no-code results");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2, "one failure each");
        Failure memory f = _failure(logs[1]);
        require(f.index == 1 && f.size == 0, "no-code metadata");
        require(
            keccak256(f.reason)
                == keccak256(
                    abi.encodeWithSelector(IStreamClaimRouter.ClaimTargetHasNoCode.selector, CALLER)
                ),
            "no-code reason"
        );
    }

    function testMalformedSuccessfulReturnsNeverCountAsRelease() public {
        for (uint8 mode = 2; mode <= 5; ++mode) {
            ClaimWalletAdversary wallet = new ClaimWalletAdversary();
            wallet.configure(0, mode);
            vm.recordLogs();
            uint256[] memory amounts =
                router.claimMany(_one(address(wallet), address(0), ACCOUNT), true);
            require(amounts[0] == 0, "malformed return rejected");
            Failure memory f = _onlyFailure(vm.getRecordedLogs());
            uint256 size = mode == 2 ? 0 : mode == 3 ? 31 : mode == 4 ? 64 : 65536;
            require(f.size == size, "exact original length");
            require(
                keccak256(f.reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamClaimRouter.InvalidClaimReturnData.selector, size
                        )
                    ),
                "local malformed reason"
            );
            require(
                wallet.releaseCalls() == 1, "successful arbitrary wallet side effect documented"
            );
        }
    }

    function testMalformedSyncSkipsRelease() public {
        ClaimWalletAdversary wallet = new ClaimWalletAdversary();
        wallet.configure(4, 0);
        vm.recordLogs();
        router.syncAndClaimMany(_one(address(wallet), address(0), ACCOUNT), true);
        Failure memory f = _onlyFailure(vm.getRecordedLogs());
        require(
            f.operation == IStreamSplitWallet.syncAsset.selector && wallet.releaseCalls() == 0,
            "malformed sync skips release"
        );
    }

    function testAtomicMalformedReturnRollsBackEarlierMoneyAndCalleeMutation() public {
        address first = _wallet(1, ACCOUNT);
        vm.deal(first, 1 ether);
        ClaimWalletAdversary wallet = new ClaimWalletAdversary();
        wallet.configure(0, 4);
        bytes memory reason =
            abi.encodeWithSelector(IStreamClaimRouter.InvalidClaimReturnData.selector, 64);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamClaimRouter.ClaimCallFailed.selector,
                1,
                address(wallet),
                IStreamSplitWallet.release.selector,
                64,
                reason
            )
        );
        router.claimMany(_two(first, address(wallet), ACCOUNT), false);
        require(first.balance == 1 ether && ACCOUNT.balance == 0, "money rollback");
        require(wallet.releaseCalls() == 0, "malformed callee rollback");
    }

    function testRevertBombReasonBoundedAndLaterRealClaimSucceeds() public {
        _hostileThenReal(6, false);
    }

    function testReturnBombBoundedAndLaterRealClaimSucceeds() public {
        _hostileThenReal(5, false);
    }

    function testAllGasBurnerCannotStarveLaterRealClaim() public {
        _hostileThenReal(7, false);
    }

    function testAllGasBurningSyncCannotStarveLaterRealSyncAndClaim() public {
        _hostileThenReal(7, true);
    }

    function testAtomicRevertBombHasBoundedErrorAndRollsBack() public {
        address first = _wallet(1, ACCOUNT);
        vm.deal(first, 1 ether);
        ClaimWalletAdversary wallet = new ClaimWalletAdversary();
        wallet.configure(0, 6);
        (bool ok, bytes memory data) = address(router)
            .call(
                abi.encodeCall(
                    IStreamClaimRouter.claimMany, (_two(first, address(wallet), ACCOUNT), false)
                )
            );
        require(!ok && data.length == 452, "bounded wrapper error");
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        require(selector == IStreamClaimRouter.ClaimCallFailed.selector, "atomic error identity");
        require(first.balance == 1 ether && ACCOUNT.balance == 0, "bomb atomic rollback");
    }

    function testZeroSuccessAndRepeatedRealClaimRequireFailureEventDisambiguation() public {
        ClaimWalletAdversary wallet = new ClaimWalletAdversary();
        wallet.configure(0, 8);
        vm.recordLogs();
        uint256[] memory zero = router.claimMany(_one(address(wallet), address(0), ACCOUNT), true);
        require(zero[0] == 0 && vm.getRecordedLogs().length == 0, "canonical zero is not failure");
        address real = _wallet(1, ACCOUNT);
        vm.deal(real, 1 ether);
        vm.recordLogs();
        uint256[] memory repeated = router.claimMany(_two(real, real, ACCOUNT), true);
        require(repeated[0] == 1 ether && repeated[1] == 0, "repeat does not pay twice");
        require(_onlyFailure(vm.getRecordedLogs()).index == 1, "repeat failure identifies item");
        require(ACCOUNT.balance == 1 ether, "one payout");
    }

    function testReentrantRecipientCannotDoubleClaimOrRedirectFunds() public {
        ClaimReentrantRecipient recipient = new ClaimReentrantRecipient(router);
        address first = _wallet(1, address(recipient));
        address second = _wallet(2, address(recipient));
        recipient.configure(first, second);
        vm.deal(first, 1 ether);
        vm.deal(second, 2 ether);
        uint256[] memory amounts =
            router.claimMany(_one(first, address(0), address(recipient)), false);
        require(amounts[0] == 1 ether, "outer amount");
        require(
            recipient.nestedFirst() == 0 && recipient.nestedSecond() == 2 ether,
            "wallet reentry guarded; independent entitlement allowed"
        );
        require(
            address(recipient).balance == 3 ether && address(router).balance == 0,
            "all money to account"
        );
        require(
            IStreamSplitWallet(first).totalReleased(address(0)) == 1 ether
                && IStreamSplitWallet(second).totalReleased(address(0)) == 2 ether,
            "no duplicate accounting"
        );
    }

    function testRejectsValueUnknownSelectorsAndAlternateRecipientABI() public {
        vm.deal(address(this), 1 ether);
        (bool received,) = address(router).call{ value: 1 }("");
        require(!received && address(router).balance == 0, "no receive");
        (bool owner,) = address(router).call(abi.encodeWithSignature("owner()"));
        require(!owner, "no owner");
        (bool redirect,) = address(router)
            .call(
                abi.encodeWithSignature(
                    "release(address,address,address)", address(0), ACCOUNT, CALLER
                )
            );
        require(!redirect, "no alternate recipient surface");
        IStreamClaimRouter.ClaimCall[] memory empty = new IStreamClaimRouter.ClaimCall[](0);
        (bool payableClaim,) = address(router).call{ value: 1 }(
            abi.encodeCall(IStreamClaimRouter.claimMany, (empty, false))
        );
        require(!payableClaim, "nonpayable methods");
    }

    function _hostileThenReal(uint8 mode, bool sync) private {
        ClaimWalletAdversary hostile = new ClaimWalletAdversary();
        hostile.configure(sync ? mode : 0, sync ? 0 : mode);
        address real = _wallet(1, ACCOUNT);
        vm.deal(real, 1 ether);
        IStreamClaimRouter.ClaimCall[] memory claims = _two(address(hostile), real, ACCOUNT);
        bytes memory input = sync
            ? abi.encodeCall(IStreamClaimRouter.syncAndClaimMany, (claims, true))
            : abi.encodeCall(IStreamClaimRouter.claimMany, (claims, true));
        vm.recordLogs();
        (bool success, bytes memory output) = address(router).call{ gas: 1_500_000 }(input);
        require(success, "adequately funded batch survives hostile wallet");
        uint256[] memory amounts = abi.decode(output, (uint256[]));
        require(
            amounts[0] == 0 && amounts[1] == 1 ether && ACCOUNT.balance == 1 ether,
            "later real claim paid"
        );
        Failure memory f = _onlyFailure(vm.getRecordedLogs());
        require(f.index == 0 && f.wallet == address(hostile), "failure attribution");
        require(
            f.operation
                == (sync
                        ? IStreamSplitWallet.syncAsset.selector
                        : IStreamSplitWallet.release.selector),
            "failure stage"
        );
        if (mode == 6) {
            require(f.size == 65536 && f.reason.length == 256, "bounded revert prefix/full size");
            uint256 firstWord;
            bytes memory reason = f.reason;
            assembly ("memory-safe") { firstWord := mload(add(reason, 32)) }
            require(firstWord == 77, "retained exact prefix");
        }
        if (mode == 5) {
            require(f.size == 65536 && f.reason.length == 36, "bounded success validation error");
        }
        if (mode == 7) {
            require(f.size == 0 && f.reason.length == 0, "gas exhaustion has no revert payload");
        }
    }

    function _wallet(uint256 id, address account) private returns (address wallet) {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(account, 1_000_000, bytes32(id + 1));
        (, wallet) = factory.createProfile(entries, keccak256(abi.encode("claim-router-test", id)));
    }

    function _discover(Vm.Log[] memory logs)
        private
        view
        returns (IStreamClaimRouter.ClaimCall[] memory claims)
    {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(factory) && logs[i].topics[0] == CREATED) ++count;
        }
        claims = new IStreamClaimRouter.ClaimCall[](count);
        uint256 cursor;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(factory) || logs[i].topics[0] != CREATED) continue;
            bytes32 profile = logs[i].topics[1];
            bool entitled;
            for (uint256 j; j < logs.length; ++j) {
                if (
                    logs[j].emitter == address(factory) && logs[j].topics[0] == ENTRY
                        && logs[j].topics[1] == profile
                        && address(uint160(uint256(logs[j].topics[3]))) == ACCOUNT
                ) entitled = true;
            }
            require(entitled, "event-discovered entitlement");
            (uint16 schema, uint16 version, address wallet) =
                abi.decode(logs[i].data, (uint16, uint16, address));
            require(schema == 1 && version == 3, "factory event version");
            claims[cursor++] = IStreamClaimRouter.ClaimCall(wallet, address(0), ACCOUNT);
        }
    }

    function _one(address wallet, address asset, address account)
        private
        pure
        returns (IStreamClaimRouter.ClaimCall[] memory claims)
    {
        claims = new IStreamClaimRouter.ClaimCall[](1);
        claims[0] = IStreamClaimRouter.ClaimCall(wallet, asset, account);
    }

    function _two(address first, address second, address account)
        private
        pure
        returns (IStreamClaimRouter.ClaimCall[] memory claims)
    {
        claims = new IStreamClaimRouter.ClaimCall[](2);
        claims[0] = IStreamClaimRouter.ClaimCall(first, address(0), account);
        claims[1] = IStreamClaimRouter.ClaimCall(second, address(0), account);
    }

    function _onlyFailure(Vm.Log[] memory logs) private view returns (Failure memory result) {
        uint256 count;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(router) && logs[i].topics[0] == FAILED) {
                result = _failure(logs[i]);
                ++count;
            }
        }
        require(count == 1, "exactly one router failure event");
    }

    function _failure(Vm.Log memory log) private view returns (Failure memory f) {
        require(
            log.emitter == address(router) && log.topics.length == 4 && log.topics[0] == FAILED,
            "failure event shape"
        );
        f.wallet = address(uint160(uint256(log.topics[1])));
        f.asset = address(uint160(uint256(log.topics[2])));
        f.account = address(uint160(uint256(log.topics[3])));
        (f.schema, f.index, f.operation, f.size, f.reason) =
            abi.decode(log.data, (uint16, uint256, bytes4, uint256, bytes));
    }
}
