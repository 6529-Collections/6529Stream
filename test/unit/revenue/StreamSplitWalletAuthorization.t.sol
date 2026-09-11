// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../mocks/MockStreamPaymentToken.sol";
import "../../../smart-contracts/domains/revenue/StreamClaimRouter.sol";

contract ReleaseSignatureAccount {
    bytes32 public acceptedDigest;
    uint8 public mode;
    uint256 public work;

    function configure(bytes32 digest, uint8 mode_, uint256 work_) external {
        acceptedDigest = digest;
        mode = mode_;
        work = work_;
    }

    function isValidSignature(bytes32 digest, bytes calldata) external view returns (bytes4) {
        if (mode == 1) revert("signature rejected");
        if (mode == 2) assembly { invalid() }
        if (mode == 3) {
            assembly ("memory-safe") {
                mstore(0, shl(224, 0x1626ba7e))
                return(0, 4)
            }
        }
        if (mode == 4) {
            assembly ("memory-safe") {
                mstore(0, shl(224, 0x1626ba7e))
                return(0, 64)
            }
        }
        if (mode == 5) return 0xffffffff;
        if (mode == 6) {
            assembly ("memory-safe") {
                mstore(0, or(shl(224, 0x1626ba7e), 1))
                return(0, 32)
            }
        }
        uint256 start = gasleft();
        while (start - gasleft() < work) { }
        return digest == acceptedDigest ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
    receive() external payable { }
}

contract ReleaseRejectingRecipient {
    receive() external payable {
        revert("no ETH");
    }
}

contract StreamSplitWalletAuthorizationTest is RevenueV1TestBase, OfficialSafeFixture {
    event log_named_uint(string key, uint256 value);
    uint256 private constant ACCOUNT_KEY = 0xA11CE;
    uint256 private constant OTHER_KEY = 0xB0B;
    address private constant RECIPIENT = address(0xCAFE);
    bytes32 private constant SIGNATURE_GAS = keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT");
    bytes32 private constant POLICY_GAS = keccak256("6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT");
    StreamAssetPolicyRegistry private policy;
    StreamSplitFactory private factory;
    MockStreamPaymentToken private token;
    address private account;
    IStreamSplitWallet private wallet;

    function setUp() public {
        account = vm.addr(ACCOUNT_KEY);
        policy = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        factory = new StreamSplitFactory(policy, address(revenueAuthority), _walletGasConfigs());
        token = new MockStreamPaymentToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("standard"), 0);
        wallet = _wallet(account, 1);
    }

    function testWalletFactoryCREATE2AndLinkedCodeIdentity() public view {
        require(wallet.factory() == address(factory), "constructor factory identity");
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(factory),
                wallet.profileId(),
                factory.splitWalletInitCodeHash()
            )
        );
        require(address(uint160(uint256(hash))) == address(wallet), "CREATE2 origin/salt");
        require(factory.walletFor(wallet.profileId()) == address(wallet), "prediction");
        require(
            address(wallet).codehash == factory.splitWalletRuntimeCodeHash(), "runtime identity"
        );
        require(factory.splitWalletExists(wallet.profileId()), "profile binding");
        require(factory.WALLET_VERSION() == 3, "new wallet version");
    }

    function testPinnedTypehashesAndERC5267Domain() public view {
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(wallet, account, 2 ether, bytes32(uint256(1)));
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529StreamSplitWallet"),
                keccak256("1"),
                block.chainid,
                address(wallet)
            )
        );
        require(wallet.domainSeparator() == domain, "domain");
        bytes32 releaseType = 0x6d1a151c75313442dbdc6436c69f78a6976bd8aa729b510f6e538487f3b93109;
        require(
            wallet.releaseAuthorizationDigest(a)
                == keccak256(
                    abi.encodePacked(hex"1901", domain, keccak256(abi.encode(releaseType, a)))
                ),
            "release golden"
        );
        bytes32 revokeType = 0xb4240d33db7140e28e850f33c2d22b71ae26cea8a0a8dafdce603a056c81e295;
        require(
            wallet.releaseRevocationDigest(account, a.nonce, a.deadline)
                == keccak256(
                    abi.encodePacked(
                        hex"1901",
                        domain,
                        keccak256(abi.encode(revokeType, account, a.nonce, a.deadline))
                    )
                ),
            "revocation golden"
        );
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chain,
            address verifier,
            bytes32 salt,
            uint256[] memory extensions
        ) = wallet.eip712Domain();
        require(
            fields == 0x0f && keccak256(bytes(name)) == keccak256("6529StreamSplitWallet")
                && keccak256(bytes(version)) == keccak256("1"),
            "domain labels"
        );
        require(
            chain == block.chainid && verifier == address(wallet) && salt == bytes32(0)
                && extensions.length == 0,
            "domain fields"
        );
    }

    function testSignedNativeReleaseExactAmountAndReplay() public {
        vm.deal(address(wallet), 2 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(wallet, account, 2 ether, bytes32(uint256(1)));
        bytes memory signature = _sign(wallet, a, ACCOUNT_KEY);
        require(wallet.releaseWithAuthorization(a, signature) == 2 ether, "full release");
        require(
            RECIPIENT.balance == 2 ether
                && wallet.isReleaseAuthorizationNonceUsed(account, a.nonce),
            "payment and nonce"
        );
        vm.deal(address(wallet), 2 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.ReleaseAuthorizationNonceUsed.selector, account, a.nonce
            )
        );
        wallet.releaseWithAuthorization(a, signature);
        require(
            address(wallet).balance == 2 ether && wallet.totalReleased(address(0)) == 2 ether,
            "replay no effects"
        );
    }

    function testSignedERC20ReleaseAndTransferFailureRollback() public {
        token.mint(address(wallet), 1000);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(wallet, account, 1000, bytes32(uint256(1)));
        a.asset = address(token);
        bytes memory signature = _sign(wallet, a, ACCOUNT_KEY);
        token.configure(1, 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.ERC20TransferFailed.selector, address(token), RECIPIENT, 1000
            )
        );
        wallet.releaseWithAuthorization(a, signature);
        require(
            !wallet.isReleaseAuthorizationNonceUsed(account, a.nonce)
                && token.rawBalance(address(wallet)) == 1000,
            "nonce and token rollback"
        );
        require(!wallet.assetObservationInitialized(address(token)), "observation rollback");
        token.configure(0, 0);
        require(
            wallet.releaseWithAuthorization(a, signature) == 1000,
            "same signature retry after atomic rollback"
        );
        require(
            token.balanceOf(RECIPIENT) == 1000
                && wallet.accountReleased(address(token), account) == 1000,
            "exact token payout"
        );
    }

    function testNativeRecipientRejectionRollsBackNonceAndObservation() public {
        vm.deal(address(wallet), 1 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(wallet, account, 1 ether, bytes32(uint256(1)));
        a.recipient = address(new ReleaseRejectingRecipient());
        bytes memory signature = _sign(wallet, a, ACCOUNT_KEY);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.NativeTransferFailed.selector, a.recipient, 1 ether
            )
        );
        wallet.releaseWithAuthorization(a, signature);
        require(
            !wallet.isReleaseAuthorizationNonceUsed(account, a.nonce)
                && !wallet.assetObservationInitialized(address(0)),
            "all state rolled back"
        );
    }

    function testAddedReceiptInvalidatesSnapshotWithoutConsumingNonce() public {
        vm.deal(address(wallet), 1 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(wallet, account, 1 ether, bytes32(uint256(1)));
        bytes memory signature = _sign(wallet, a, ACCOUNT_KEY);
        vm.deal(address(wallet), 2 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.ReleaseSnapshotMismatch.selector, 1 ether, 2 ether
            )
        );
        wallet.releaseWithAuthorization(a, signature);
        require(
            !wallet.isReleaseAuthorizationNonceUsed(account, a.nonce) && RECIPIENT.balance == 0,
            "no partial release"
        );
    }

    function testReleaseToSelfInterveningReceiptInvalidatesOldSnapshot() public {
        vm.deal(address(wallet), 1 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(wallet, account, 1 ether, bytes32(uint256(1)));
        bytes memory signature = _sign(wallet, a, ACCOUNT_KEY);
        wallet.release(address(0), account, payable(account));
        vm.deal(address(wallet), 2 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.ReleaseSnapshotMismatch.selector, 1 ether, 2 ether
            )
        );
        wallet.releaseWithAuthorization(a, signature);
        require(account.balance == 1 ether && RECIPIENT.balance == 0, "keeper payment only");
    }

    function testExpiredAuthorizationAndExactDeadlineBoundary() public {
        vm.deal(address(wallet), 1 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(wallet, account, 1 ether, bytes32(uint256(1)));
        bytes memory signature = _sign(wallet, a, ACCOUNT_KEY);
        vm.warp(uint256(a.deadline) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.ReleaseAuthorizationExpired.selector, a.deadline
            )
        );
        wallet.releaseWithAuthorization(a, signature);
        vm.warp(a.deadline);
        require(wallet.releaseWithAuthorization(a, signature) == 1 ether, "deadline is inclusive");
    }

    function testChangedRecipientAssetWalletAndChainReject() public {
        vm.deal(address(wallet), 1 ether);
        token.mint(address(wallet), 1 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(wallet, account, 1 ether, bytes32(uint256(1)));
        bytes memory signature = _sign(wallet, a, ACCOUNT_KEY);
        a.recipient = account;
        _expectInvalid(wallet, a, signature);
        a.recipient = RECIPIENT;
        a.asset = address(token);
        _expectInvalid(wallet, a, signature);
        a.asset = address(0);
        IStreamSplitWallet other = _wallet(account, 2);
        vm.deal(address(other), 1 ether);
        _expectInvalid(other, a, signature);
        uint256 oldChain = block.chainid;
        vm.chainId(oldChain + 1);
        _expectInvalid(wallet, a, signature);
        vm.chainId(oldChain);
        require(
            !wallet.isReleaseAuthorizationNonceUsed(account, a.nonce), "wrong domains leave nonce"
        );
    }

    function testChangedEntitledAccountRejectsWithoutTransferringOrConsumingEitherNonce() public {
        address other = vm.addr(OTHER_KEY);
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(account, 500_000, bytes32(uint256(1)));
        entries[1] = IStreamSplitWallet.SplitEntry(other, 500_000, bytes32(uint256(2)));
        (, address target) = factory.createProfile(entries, bytes32(uint256(55)));
        IStreamSplitWallet shared = IStreamSplitWallet(target);
        vm.deal(target, 2 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(shared, account, 1 ether, bytes32(uint256(55)));
        bytes memory signature = _sign(shared, a, ACCOUNT_KEY);
        a.account = other;
        _expectInvalid(shared, a, signature);
        require(
            !shared.isReleaseAuthorizationNonceUsed(account, a.nonce)
                && !shared.isReleaseAuthorizationNonceUsed(other, a.nonce)
                && target.balance == 2 ether && RECIPIENT.balance == 0,
            "account substitution atomic"
        );
    }

    function testCanonicalEOANegativesForReleaseAndRevocation() public {
        vm.deal(address(wallet), 1 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(wallet, account, 1 ether, bytes32(uint256(1)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ACCOUNT_KEY, wallet.releaseAuthorizationDigest(a));
        _expectInvalid(wallet, a, abi.encodePacked(r, s, uint8(0)));
        _expectInvalid(wallet, a, abi.encodePacked(r, bytes32(type(uint256).max), v));
        _expectInvalid(wallet, a, abi.encodePacked(bytes32(0), bytes32(0), uint8(27)));
        _expectInvalid(wallet, a, bytes(""));
        _expectInvalid(wallet, a, _sign(wallet, a, OTHER_KEY));
        bytes32 digest = wallet.releaseRevocationDigest(account, a.nonce, a.deadline);
        (v, r, s) = vm.sign(ACCOUNT_KEY, digest);
        _expectInvalidRevocation(a, abi.encodePacked(r, s, uint8(1)));
        _expectInvalidRevocation(a, abi.encodePacked(r, bytes32(type(uint256).max), v));
        _expectInvalidRevocation(a, abi.encodePacked(bytes32(0), bytes32(0), uint8(27)));
        require(
            !wallet.isReleaseAuthorizationNonceUsed(account, a.nonce), "all golden negatives atomic"
        );
    }

    function testCompactEOASignatureAndDelegatedOwnKeyRemainValid() public {
        vm.deal(address(wallet), 1 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(wallet, account, 1 ether, bytes32(uint256(1)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ACCOUNT_KEY, wallet.releaseAuthorizationDigest(a));
        bytes32 vs = s | bytes32(uint256(v - 27) << 255);
        vm.etch(account, abi.encodePacked(hex"ef0100", address(0x7702)));
        require(
            wallet.releaseWithAuthorization(a, abi.encodePacked(r, vs)) == 1 ether,
            "delegated EOA own-key compact signature"
        );
    }

    function testDirectAndSignedRevocationAreSignerScopedAndPermanent() public {
        bytes32 nonce = bytes32(uint256(9));
        vm.prank(vm.addr(OTHER_KEY));
        wallet.revokeReleaseAuthorization(nonce);
        require(
            !wallet.isReleaseAuthorizationNonceUsed(account, nonce), "other signer cannot revoke"
        );
        uint64 deadline = uint64(block.timestamp + 100);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(ACCOUNT_KEY, wallet.releaseRevocationDigest(account, nonce, deadline));
        vm.recordLogs();
        wallet.revokeReleaseAuthorizationBySignature(
            account, nonce, deadline, abi.encodePacked(r, s, v)
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(wallet), "one revocation event");
        require(
            logs[0].topics[0] == keccak256("ReleaseAuthorizationRevoked(address,bytes32,uint16)")
                && logs[0].topics[1] == bytes32(uint256(uint160(account)))
                && logs[0].topics[2] == nonce,
            "revocation identity"
        );
        require(abi.decode(logs[0].data, (uint16)) == 1, "schema");
        vm.warp(uint256(deadline) + 1);
        require(
            wallet.isReleaseAuthorizationNonceUsed(account, nonce),
            "expiry cannot restore revoked nonce"
        );
        vm.prank(account);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.ReleaseAuthorizationNonceUsed.selector, account, nonce
            )
        );
        wallet.revokeReleaseAuthorization(nonce);
    }

    function testExpiredSignedRevocationDoesNotConsumeNonce() public {
        uint64 deadline = uint64(block.timestamp + 1);
        bytes32 nonce = bytes32(uint256(1));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(ACCOUNT_KEY, wallet.releaseRevocationDigest(account, nonce, deadline));
        vm.warp(uint256(deadline) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.ReleaseAuthorizationExpired.selector, deadline
            )
        );
        wallet.revokeReleaseAuthorizationBySignature(
            account, nonce, deadline, abi.encodePacked(r, s, v)
        );
        require(
            !wallet.isReleaseAuthorizationNonceUsed(account, nonce),
            "expired revocation not consumed"
        );
    }

    function testERC1271FailuresAndHeavyValidAccountUseCurrentFactoryBudget() public {
        ReleaseSignatureAccount signer = new ReleaseSignatureAccount();
        IStreamSplitWallet contractWallet = _wallet(address(signer), 2);
        vm.deal(address(contractWallet), 1 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(contractWallet, address(signer), 1 ether, bytes32(uint256(1)));
        for (uint8 mode = 1; mode <= 6; ++mode) {
            signer.configure(contractWallet.releaseAuthorizationDigest(a), mode, 0);
            _expectInvalid(contractWallet, a, hex"01020304");
        }
        signer.configure(contractWallet.releaseAuthorizationDigest(a), 0, 320_000);
        require(
            contractWallet.releaseWithAuthorization(a, hex"01020304") == 1 ether,
            "heavy contract with arbitrary-length signature"
        );
        vm.deal(address(contractWallet), 1 ether);
        a.nonce = bytes32(uint256(2));
        signer.configure(contractWallet.releaseAuthorizationDigest(a), 0, 450_000);
        _expectInvalid(contractWallet, a, hex"01");
        _raise(SIGNATURE_GAS, 800_000);
        require(
            contractWallet.releaseWithAuthorization(a, hex"01") == 1 ether,
            "live raised factory budget"
        );
    }

    function testERC1271RevocationFailuresAndArbitraryLengthSuccess() public {
        ReleaseSignatureAccount signer = new ReleaseSignatureAccount();
        IStreamSplitWallet target = _wallet(address(signer), 7);
        bytes32 nonce = keccak256("contract revocation");
        uint64 deadline = uint64(block.timestamp + 1 days);
        bytes32 digest = target.releaseRevocationDigest(address(signer), nonce, deadline);
        for (uint8 mode = 1; mode <= 6; ++mode) {
            signer.configure(digest, mode, 0);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamSplitWallet.InvalidReleaseSignature.selector, address(signer)
                )
            );
            target.revokeReleaseAuthorizationBySignature(
                address(signer), nonce, deadline, hex"010203"
            );
            require(
                !target.isReleaseAuthorizationNonceUsed(address(signer), nonce),
                "failed proof leaves nonce"
            );
        }
        signer.configure(digest, 0, 320_000);
        target.revokeReleaseAuthorizationBySignature(address(signer), nonce, deadline, hex"010203");
        require(
            target.isReleaseAuthorizationNonceUsed(address(signer), nonce),
            "heavy revocation accepted"
        );
    }

    function testInsufficientOuterGasFailsBeforeUnderforwardingSignatureBudget() public {
        ReleaseSignatureAccount signer = new ReleaseSignatureAccount();
        IStreamSplitWallet target = _wallet(address(signer), 8);
        vm.deal(address(target), 1 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(target, address(signer), 1 ether, bytes32(uint256(8)));
        signer.configure(target.releaseAuthorizationDigest(a), 0, 0);
        (bool ok, bytes memory reason) = address(target).call{ gas: 300_000 }(
            abi.encodeCall(IStreamSplitWallet.releaseWithAuthorization, (a, hex"01"))
        );
        bytes memory expected =
            abi.encodeWithSelector(IStreamSplitWallet.InsufficientWalletCallGas.selector, 400_000);
        require(!ok && keccak256(reason) == keccak256(expected), "explicit precheck error");
        require(
            !target.isReleaseAuthorizationNonceUsed(address(signer), a.nonce)
                && !target.assetObservationInitialized(address(0))
                && address(target).balance == 1 ether,
            "underfunded call is atomic"
        );
        signer.configure(target.releaseRevocationDigest(address(signer), a.nonce, a.deadline), 0, 0);
        (ok, reason) = address(target).call{ gas: 300_000 }(
            abi.encodeCall(
                IStreamSplitWallet.revokeReleaseAuthorizationBySignature,
                (address(signer), a.nonce, a.deadline, hex"01")
            )
        );
        require(
            !ok && keccak256(reason) == keccak256(expected)
                && !target.isReleaseAuthorizationNonceUsed(address(signer), a.nonce),
            "revoke precheck atomic"
        );
    }

    function testDeprecatedUnobservedStrictGraceBoundaryAndObservedZeroForever() public {
        IStreamSplitWallet observedZero = _wallet(account, 2);
        observedZero.syncAsset(address(token));
        require(
            observedZero.assetObservationInitialized(address(token)),
            "zero is initialized observation"
        );
        uint64 grace = uint64(block.timestamp + 180 days);
        _setAssetPolicy(policy, address(token), 3, keccak256("retired"), grace);
        require(!policy.isAssetActive(address(token)), "new payments remain disabled");
        vm.warp(uint256(grace) - 1);
        token.mint(address(wallet), 10);
        require(
            wallet.release(address(token), account, payable(account)) == 10,
            "unobserved before grace"
        );
        IStreamSplitWallet unobserved = _wallet(account, 3);
        token.mint(address(unobserved), 20);
        vm.warp(grace);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.AssetNotActive.selector, address(token), uint8(3)
            )
        );
        unobserved.syncAsset(address(token));
        vm.warp(uint256(grace) + 365 days);
        token.mint(address(observedZero), 30);
        require(
            observedZero.release(address(token), account, payable(account)) == 30,
            "observed-at-zero forever"
        );
        token.mint(address(wallet), 40);
        require(
            wallet.release(address(token), account, payable(account)) == 40,
            "initialized during grace remains eligible"
        );
        require(token.balanceOf(address(unobserved)) == 20, "expired wallet funds intact");
    }

    function testInactiveUnsupportedAndUnknownFreezeOnlyTheirAsset() public {
        token.mint(address(wallet), 10);
        wallet.syncAsset(address(token));
        for (uint8 status = 2; status <= 4; ++status) {
            if (status == 3) continue;
            _setAssetPolicy(policy, address(token), status, bytes32(uint256(status)), 0);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamSplitWallet.AssetNotActive.selector, address(token), status
                )
            );
            wallet.release(address(token), account, payable(account));
            vm.deal(address(wallet), 1 ether);
            require(
                wallet.release(address(0), account, payable(account)) == 1 ether,
                "native independent"
            );
        }
        _setAssetPolicy(policy, address(token), 0, bytes32(0), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.AssetNotActive.selector, address(token), uint8(0)
            )
        );
        wallet.syncAsset(address(token));
    }

    function testGraceCannotShortenOrResetAcrossStatuses() public {
        uint64 grace = uint64(block.timestamp + 200 days);
        _setAssetPolicy(policy, address(token), 3, keccak256("retired"), grace);
        _setAssetPolicy(policy, address(token), 1, keccak256("active again"), grace);
        _prepareAssetPolicy(policy, address(token), 3, keccak256("retired again"), grace - 1);
        vm.prank(address(revenueAuthority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamAssetPolicyRegistry.InvalidAssetReleaseGrace.selector, grace, grace - 1
            )
        );
        policy.setAssetStatus(address(token), 3, keccak256("retired again"), grace - 1);
        require(policy.assetReleaseGraceUntil(address(token)) == grace, "historical grace retained");
        _prepareAssetPolicy(policy, address(token), 2, keccak256("inactive"), 0);
        vm.prank(address(revenueAuthority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamAssetPolicyRegistry.InvalidAssetReleaseGrace.selector, grace, uint64(0)
            )
        );
        policy.setAssetStatus(address(token), 2, keccak256("inactive"), 0);
    }

    function testPolicyRejectsUnstagedWrongClassAndMismatchedState() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamAssetPolicyRegistry.AssetPolicyNotAuthority.selector, address(this)
            )
        );
        policy.setAssetStatus(address(token), 2, keccak256("inactive"), 0);
        vm.prank(address(revenueAuthority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamAssetPolicyRegistry.InvalidAssetPolicyAction.selector)
        );
        policy.setAssetStatus(address(token), 2, keccak256("inactive"), 0);
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            policy.assetPolicyTransitionHashes(address(token), 2, keccak256("inactive"), 0);
        revenueAuthority.setCurrentAction(true, bytes32(uint256(99)), 0, scope, oldState, newState);
        vm.prank(address(revenueAuthority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamAssetPolicyRegistry.InvalidAssetPolicyAction.selector)
        );
        policy.setAssetStatus(address(token), 2, keccak256("inactive"), 0);
        revenueAuthority.setCurrentAction(
            true, bytes32(uint256(99)), 1, scope, oldState, bytes32(0)
        );
        vm.prank(address(revenueAuthority));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamAssetPolicyRegistry.InvalidAssetPolicyAction.selector)
        );
        policy.setAssetStatus(address(token), 2, keccak256("inactive"), 0);
        require(policy.assetStatus(address(token)) == 1, "bad actions no changes");
    }

    function testFactoryRejectsMissingAuthorityWrongRowsAndImmediateRaise() public {
        IStreamGasParameterHost.GasParameterConfig[2] memory configs = _walletGasConfigs();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidAuthority.selector, address(0)
            )
        );
        new StreamSplitFactory(policy, address(0), configs);
        configs[0].name = "WRONG";
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector,
                keccak256("ERC_1271_GAS_LIMIT")
            )
        );
        new StreamSplitFactory(policy, address(revenueAuthority), configs);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(this)
            )
        );
        factory.raiseGasParameter(POLICY_GAS, 60_000);
        require(
            factory.gasParameter(SIGNATURE_GAS) == 400_000
                && factory.gasParameterFloor(SIGNATURE_GAS) == 350_000,
            "actual budget/floor"
        );
        _raise(POLICY_GAS, 60_000);
        require(factory.gasParameter(POLICY_GAS) == 60_000, "governed policy raise");
    }

    function testOfficialSafe130ReleaseRevocationAndDirectPayout() public {
        _safeFlows("1.3.0");
    }

    function testOfficialSafe141ReleaseRevocationAndDirectPayout() public {
        _safeFlows("1.4.1");
    }

    function testOfficialSafe150ReleaseRevocationAndDirectPayout() public {
        _safeFlows("1.5.0");
    }

    function _safeFlows(string memory version) private {
        SafeComponents memory c = deploySafeComponents(version);
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0x101;
        owners[1] = 0x102;
        owners[2] = 0x103;
        uint256[] memory keys = new uint256[](2);
        keys[0] = owners[0];
        keys[1] = owners[1];
        OfficialSafe safe = createOfficialSafe(c, safeOwnerAddresses(owners), 2, 1);
        IStreamSplitWallet safeWallet = _wallet(address(safe), 4);
        vm.deal(address(safeWallet), 1 ether);
        token.mint(address(safeWallet), 100);
        require(
            safeWallet.release(address(0), address(safe), payable(address(safe))) == 1 ether,
            "native paid into real Safe"
        );
        require(
            safeWallet.release(address(token), address(safe), payable(address(safe))) == 100,
            "ERC20 paid into real Safe"
        );
        require(
            address(safe).balance == 1 ether && token.balanceOf(address(safe)) == 100,
            "real Safe balances"
        );
        _safeThresholdRelease(safe, keys, safeWallet, version);
        _safeRevocationAndDirectRelease(safe, keys, safeWallet);
        _safePreapprovedEmptySignatures(safe, keys, c.signMessage, safeWallet);
    }

    function _safeThresholdRelease(
        OfficialSafe safe,
        uint256[] memory keys,
        IStreamSplitWallet safeWallet,
        string memory version
    ) private {
        vm.deal(address(safeWallet), 2 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(safeWallet, address(safe), 2 ether, bytes32(uint256(1)));
        bytes32 streamDigest = safeWallet.releaseAuthorizationDigest(a);
        bytes memory proof =
            safeThresholdSignature(keys, safeMessageDigest(safe, abi.encode(streamDigest)));
        _expectInvalid(safeWallet, a, safeThresholdSignature(keys, streamDigest));
        uint256[] memory oneKey = new uint256[](1);
        oneKey[0] = keys[0];
        _expectInvalid(
            safeWallet,
            a,
            safeThresholdSignature(oneKey, safeMessageDigest(safe, abi.encode(streamDigest)))
        );
        a.recipient = account;
        _expectInvalid(safeWallet, a, proof);
        a.recipient = RECIPIENT;
        uint256 beforeCall = gasleft();
        require(
            safeWallet.releaseWithAuthorization(a, proof) == 2 ether,
            "real handler threshold release"
        );
        emit log_named_uint(
            string.concat("Safe ", version, " signed release fixture gas"), beforeCall - gasleft()
        );
        require(
            RECIPIENT.balance == 2 ether
                && safeWallet.isReleaseAuthorizationNonceUsed(address(safe), a.nonce),
            "actual protocol payment and nonce"
        );
    }

    function _safeRevocationAndDirectRelease(
        OfficialSafe safe,
        uint256[] memory keys,
        IStreamSplitWallet safeWallet
    ) private {
        vm.deal(address(safeWallet), 3 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(safeWallet, address(safe), 3 ether, bytes32(uint256(2)));
        bytes32 revokeDigest =
            safeWallet.releaseRevocationDigest(address(safe), a.nonce, a.deadline);
        safeWallet.revokeReleaseAuthorizationBySignature(
            address(safe),
            a.nonce,
            a.deadline,
            safeThresholdSignature(keys, safeMessageDigest(safe, abi.encode(revokeDigest)))
        );
        require(
            safeWallet.isReleaseAuthorizationNonceUsed(address(safe), a.nonce), "Safe revocation"
        );
        bytes memory releaseProof = safeThresholdSignature(
            keys, safeMessageDigest(safe, abi.encode(safeWallet.releaseAuthorizationDigest(a)))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.ReleaseAuthorizationNonceUsed.selector, address(safe), a.nonce
            )
        );
        safeWallet.releaseWithAuthorization(a, releaseProof);
        uint256 oldNonce = safe.nonce();
        vm.recordLogs();
        require(
            executeSafe(
                safe,
                keys,
                address(safeWallet),
                0,
                abi.encodeCall(
                    IStreamSplitWallet.release, (address(0), address(safe), payable(RECIPIENT))
                ),
                0
            ),
            "Safe executes direct cap-independent redirect"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool executionSuccess;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe)
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) executionSuccess = true;
        }
        require(
            executionSuccess && safe.nonce() == oldNonce + 1 && RECIPIENT.balance == 5 ether,
            "Safe outer and actual inner success"
        );
        require(safeWallet.totalReleased(address(0)) == 6 ether, "all wallet payouts accounted");
    }

    function _safePreapprovedEmptySignatures(
        OfficialSafe safe,
        uint256[] memory keys,
        address signMessage,
        IStreamSplitWallet target
    ) private {
        vm.deal(address(target), 1 ether);
        IStreamSplitWallet.ReleaseAuthorization memory a =
            _authorization(target, address(safe), 1 ether, keccak256("empty approved release"));
        _expectInvalid(target, a, bytes(""));
        require(
            executeSafe(
                safe,
                keys,
                signMessage,
                0,
                abi.encodeWithSignature(
                    "signMessage(bytes)", abi.encode(target.releaseAuthorizationDigest(a))
                ),
                1
            ),
            "Safe delegate-executes official SignMessageLib"
        );
        require(
            target.releaseWithAuthorization(a, bytes("")) == 1 ether
                && target.isReleaseAuthorizationNonceUsed(address(safe), a.nonce)
                && RECIPIENT.balance == 6 ether,
            "preapproved empty release real effects"
        );
        bytes32 nonce = keccak256("empty approved revocation");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.InvalidReleaseSignature.selector, address(safe)
            )
        );
        target.revokeReleaseAuthorizationBySignature(address(safe), nonce, a.deadline, bytes(""));
        require(
            !target.isReleaseAuthorizationNonceUsed(address(safe), nonce),
            "unapproved revoke atomic"
        );
        require(
            executeSafe(
                safe,
                keys,
                signMessage,
                0,
                abi.encodeWithSignature(
                    "signMessage(bytes)",
                    abi.encode(target.releaseRevocationDigest(address(safe), nonce, a.deadline))
                ),
                1
            ),
            "Safe approves exact revocation digest"
        );
        target.revokeReleaseAuthorizationBySignature(address(safe), nonce, a.deadline, bytes(""));
        require(
            target.isReleaseAuthorizationNonceUsed(address(safe), nonce), "preapproved empty revoke"
        );
    }

    function _wallet(address recipient, uint256 id) private returns (IStreamSplitWallet result) {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(recipient, 1_000_000, bytes32(id));
        (, address target) = factory.createProfile(entries, bytes32(id));
        return IStreamSplitWallet(target);
    }

    function _authorization(IStreamSplitWallet, address signer, uint256 snapshot, bytes32 nonce)
        private
        view
        returns (IStreamSplitWallet.ReleaseAuthorization memory)
    {
        return IStreamSplitWallet.ReleaseAuthorization(
            address(0), signer, RECIPIENT, snapshot, nonce, uint64(block.timestamp + 1 days)
        );
    }

    function _sign(
        IStreamSplitWallet target,
        IStreamSplitWallet.ReleaseAuthorization memory a,
        uint256 key
    ) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, target.releaseAuthorizationDigest(a));
        return abi.encodePacked(r, s, v);
    }

    function _expectInvalid(
        IStreamSplitWallet target,
        IStreamSplitWallet.ReleaseAuthorization memory a,
        bytes memory signature
    ) private {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamSplitWallet.InvalidReleaseSignature.selector, a.account)
        );
        target.releaseWithAuthorization(a, signature);
    }

    function _expectInvalidRevocation(
        IStreamSplitWallet.ReleaseAuthorization memory a,
        bytes memory signature
    ) private {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamSplitWallet.InvalidReleaseSignature.selector, a.account)
        );
        wallet.revokeReleaseAuthorizationBySignature(a.account, a.nonce, a.deadline, signature);
    }

    function _raise(bytes32 id, uint256 value) private {
        (uint256 oldValue, uint256 floor, uint8 failureClass, uint64 revision) =
            factory.gasParameterInfo(id);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(factory),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        bytes32 oldState =
            keccak256(abi.encode(domain, scope, oldValue, floor, failureClass, revision));
        bytes32 newState =
            keccak256(abi.encode(domain, scope, value, floor, failureClass, revision + 1));
        revenueAuthority.setCurrentAction(
            true, keccak256(abi.encode(id, value)), 1, scope, oldState, newState
        );
        vm.prank(address(revenueAuthority));
        factory.raiseGasParameter(id, value);
        revenueAuthority.setCurrentAction(false, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
    }
}
