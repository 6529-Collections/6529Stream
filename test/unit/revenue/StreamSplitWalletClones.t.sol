// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../helpers/SplitWalletInitializationHarness.sol";
import "../../mocks/MockStreamPaymentToken.sol";

contract SplitStipendSender {
    function send(address payable recipient) external payable {
        recipient.transfer(msg.value);
    }
}

/// @dev Actual Factory/Wallet/AssetPolicy; governance is the original typed target-action fixture.
/// The retained Wallet/Authorization suites cover native/ERC20 callback rollback and real Safes.
contract SplitCloneRecipient {
    bool public reject = true;

    function accept() external {
        reject = false;
    }

    receive() external payable {
        require(!reject, "reject native");
    }
}

contract StreamSplitWalletClonesTest is RevenueV1TestBase, OfficialSafeFixture {
    StreamAssetPolicyRegistry private policy;
    StreamSplitFactory private factory;
    address private constant ACCOUNT = address(0xa11ce);
    bytes32 private constant META = keccak256("clone-v4");

    function setUp() public {
        policy = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        factory = new StreamSplitFactory(policy, address(revenueAuthority), _walletGasConfigs());
        vm.deal(address(this), 10 ether);
    }

    function testSingletonIsPinnedLockedAndNotAUserWallet() public {
        address implementation = factory.splitWalletImplementation();
        require(implementation.code.length > 52, "actual implementation");
        require(implementation.codehash == factory.splitWalletImplementationCodeHash(), "pin");
        require(
            factory.supportsInterface(type(IStreamSplitWalletImplementation).interfaceId),
            "capability"
        );
        IStreamSplitWallet target = IStreamSplitWallet(implementation);
        require(target.initialized() && target.factory() == address(factory), "locked origin");
        require(target.profileId() == 0 && !factory.splitWalletExists(0), "not a registered wallet");
        (
            IStreamSplitWallet.SplitEntry[] memory entries,
            address[] memory accounts,
            uint32[] memory shares
        ) = _inputs();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.UnauthorizedInitializer.selector, address(this)
            )
        );
        target.initialize(0, 0, META, entries, accounts, shares);
        vm.prank(address(factory));
        vm.expectRevert(abi.encodeWithSelector(IStreamSplitWallet.AlreadyInitialized.selector));
        target.initialize(0, 0, META, entries, accounts, shares);
    }

    function testConstructorEventAndFullVersionFourIdentity() public {
        vm.recordLogs();
        StreamSplitFactory other =
            new StreamSplitFactory(policy, address(revenueAuthority), _walletGasConfigs());
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256(
            "SplitWalletImplementationPinned(uint16,address,bytes32,uint16,bytes32,bytes32)"
        );
        uint256 found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(other) || logs[i].topics[0] != topic) continue;
            ++found;
            require(
                logs[i].topics[1] == bytes32(uint256(uint160(other.splitWalletImplementation()))),
                "event implementation"
            );
            require(logs[i].topics[2] == other.splitWalletImplementationCodeHash(), "event runtime");
            (uint16 schema, uint16 version, bytes32 initHash, bytes32 runtimeHash) =
                abi.decode(logs[i].data, (uint16, uint16, bytes32, bytes32));
            require(
                schema == 1 && version == 4 && initHash == other.splitWalletInitCodeHash()
                    && runtimeHash == other.splitWalletRuntimeCodeHash(),
                "event identity"
            );
        }
        require(
            found == 1 && other.splitWalletImplementation() != factory.splitWalletImplementation(),
            "one per factory"
        );
        (IStreamSplitWallet.SplitEntry[] memory entries,,) = _inputs();
        bytes32 profile = factory.profileIdFor(entries, META);
        bytes32 entriesHash = keccak256(abi.encode(entries));
        bytes32 manual = keccak256(
            abi.encode(
                factory.PROFILE_DOMAIN(),
                block.chainid,
                address(factory),
                uint16(1),
                uint16(4),
                factory.splitWalletInitCodeHash(),
                factory.splitWalletRuntimeCodeHash(),
                address(policy),
                entriesHash,
                META
            )
        );
        require(
            profile == manual && factory.WALLET_VERSION() == 4, "original domain with new version"
        );
        bytes32 oldVersion = keccak256(
            abi.encode(
                factory.PROFILE_DOMAIN(),
                block.chainid,
                address(factory),
                uint16(1),
                uint16(3),
                factory.splitWalletInitCodeHash(),
                factory.splitWalletRuntimeCodeHash(),
                address(policy),
                entriesHash,
                META
            )
        );
        require(
            oldVersion != profile && other.profileIdFor(entries, META) != profile,
            "no identity alias"
        );
    }

    function testExactRuntimeInitHashCreate2AndAtomicProfilePublication() public {
        (IStreamSplitWallet.SplitEntry[] memory entries,,) = _inputs();
        (bytes32 profile, address predicted) = factory.registerProfile(entries, META);
        require(
            predicted.code.length == 0 && !factory.splitWalletExists(profile), "registration alone"
        );
        bytes memory runtime = abi.encodePacked(
            hex"3615603257363d3d373d3d3d363d73",
            factory.splitWalletImplementation(),
            hex"5af43d82803e903d91603057fd5bf35b00"
        );
        require(
            runtime.length == 52 && keccak256(runtime) == factory.splitWalletRuntimeCodeHash(),
            "literal runtime"
        );
        bytes32 initHash = keccak256(bytes.concat(hex"3d603480600a3d3981f3", runtime));
        require(initHash == factory.splitWalletInitCodeHash(), "literal init code");
        address expected = address(
            uint160(
                uint256(
                    keccak256(abi.encodePacked(bytes1(0xff), address(factory), profile, initHash))
                )
            )
        );
        require(
            expected == predicted && factory.deployWallet(profile) == predicted, "actual CREATE2"
        );
        require(
            keccak256(predicted.code) == keccak256(runtime) && factory.splitWalletExists(profile),
            "published only initialized"
        );
        require(
            IStreamSplitWallet(predicted).factory() == address(factory)
                && IStreamSplitWallet(predicted).profileId() == profile,
            "clone storage"
        );
        require(
            factory.deployWallet(profile) == predicted && factory.profileCount() == 1, "idempotent"
        );
    }

    function testPassiveReceiveUsesStipendAndNoObservationWrites() public {
        IStreamSplitWallet wallet = _wallet();
        SplitStipendSender sender = new SplitStipendSender();
        address implementation = factory.splitWalletImplementation();
        safeVm.cool(address(wallet));
        safeVm.cool(address(factory));
        safeVm.cool(implementation);
        sender.send{ value: 1 ether }(payable(address(wallet)));
        require(
            address(wallet).balance == 1 ether && !wallet.assetObservationInitialized(address(0)),
            "passive stipend"
        );
        require(
            wallet.release(address(0), ACCOUNT, payable(ACCOUNT)) == 1 ether,
            "first zero guard release"
        );
        require(
            wallet.totalReleased(address(0)) == 1 ether && ACCOUNT.balance == 1 ether,
            "original ledger"
        );
    }

    function testNativeAndERC20CounterfactualBalancesSurviveDeployment() public {
        (IStreamSplitWallet.SplitEntry[] memory entries,,) = _inputs();
        (bytes32 profile, address predicted) = factory.registerProfile(entries, META);
        MockStreamPaymentToken token = new MockStreamPaymentToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("standard"), 0);
        (bool sent,) = payable(predicted).call{ value: 2 ether }("");
        require(sent, "counterfactual native");
        token.mint(predicted, 1234);
        require(factory.deployWallet(profile) == predicted, "deploy prefunded");
        IStreamSplitWallet wallet = IStreamSplitWallet(predicted);
        require(
            wallet.release(address(0), ACCOUNT, payable(ACCOUNT)) == 2 ether, "native entitlement"
        );
        require(
            wallet.release(address(token), ACCOUNT, payable(ACCOUNT)) == 1234, "token entitlement"
        );
        require(ACCOUNT.balance == 2 ether && token.balanceOf(ACCOUNT) == 1234, "exact releases");
    }

    function testNonemptyReturnAndRevertBytesRemainExact() public {
        IStreamSplitWallet wallet = _wallet();
        (bool ok, bytes memory result) =
            address(wallet).staticcall(abi.encodeCall(IStreamSplitWallet.factory, ()));
        require(ok && keccak256(result) == keccak256(abi.encode(address(factory))), "return bytes");
        (ok, result) = address(wallet)
            .call(
                abi.encodeCall(IStreamSplitWallet.release, (address(0), ACCOUNT, payable(ACCOUNT)))
            );
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamSplitWallet.NoReleasableFunds.selector, address(0), ACCOUNT
                        )
                    ),
            "custom error bubbles"
        );
        (ok, result) = address(wallet).call(hex"ffffffff");
        require(!ok && result.length == 0, "unknown selector original empty revert");
        (ok, result) =
            address(wallet).call{ value: 1 }(abi.encodeCall(IStreamSplitWallet.factory, ()));
        require(
            !ok && result.length == 0 && address(wallet).balance == 0, "nonpayable value rejection"
        );
    }

    function testInitializationFailureRollsBackCreationAndCanRetrySamePrediction() public {
        SplitWalletInitializationHarness h = new SplitWalletInitializationHarness();
        bytes32 profile = keccak256("atomic initializer");
        address predicted = h.walletFor(profile);
        (bool funded,) = payable(predicted).call{ value: 1 ether }("");
        require(funded, "prefund");
        (
            IStreamSplitWallet.SplitEntry[] memory entries,
            address[] memory accounts,
            uint32[] memory shares
        ) = _inputs();
        vm.expectRevert(
            abi.encodeWithSelector(IStreamSplitWallet.InvalidInitializationInput.selector)
        );
        h.deployAndInitialize(profile, keccak256("wrong"), META, entries, accounts, shares);
        require(
            !h.profileExists(profile) && predicted.code.length == 0 && predicted.balance == 1 ether,
            "full transaction rollback"
        );
        IStreamSplitWallet wallet = h.deployAndInitialize(
            profile, keccak256(abi.encode(entries)), META, entries, accounts, shares
        );
        require(
            address(wallet) == predicted && wallet.initialized() && wallet.factory() == address(h),
            "same init retry"
        );
        vm.expectRevert(abi.encodeWithSelector(IStreamSplitWallet.AlreadyInitialized.selector));
        h.initializeClone(
            wallet, profile, keccak256(abi.encode(entries)), META, entries, accounts, shares
        );
    }

    function testUninitializedCloneRejectsFirstCallerAndUnregisteredOrWrongAddress() public {
        SplitWalletInitializationHarness h = new SplitWalletInitializationHarness();
        bytes32 profile = keccak256("initialization proof");
        IStreamSplitWallet wallet = h.deployUninitialized(profile, false, profile);
        (
            IStreamSplitWallet.SplitEntry[] memory entries,
            address[] memory accounts,
            uint32[] memory shares
        ) = _inputs();
        bytes32 entriesHash = keccak256(abi.encode(entries));
        require(
            !wallet.initialized() && wallet.factory() == address(0), "clone storage starts empty"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWallet.UnauthorizedInitializer.selector, address(this)
            )
        );
        wallet.initialize(profile, entriesHash, META, entries, accounts, shares);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamSplitWallet.InvalidInitializationInput.selector)
        );
        h.initializeClone(wallet, profile, entriesHash, META, entries, accounts, shares);
        IStreamSplitWallet wrong = h.deployUninitialized(profile, true, keccak256("wrong salt"));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamSplitWallet.InvalidInitializationInput.selector)
        );
        h.initializeClone(wrong, profile, entriesHash, META, entries, accounts, shares);
        require(!wallet.initialized() && !wrong.initialized(), "failed admission no storage");
        h.initializeClone(wallet, profile, entriesHash, META, entries, accounts, shares);
        require(wallet.initialized(), "original proof sufficient");
    }

    function testFactoryPinRefusesChangedImplementationBeforePublishingProfile() public {
        IStreamSplitWallet wallet = _wallet();
        bytes32 originalProfile = wallet.profileId();
        address implementation = factory.splitWalletImplementation();
        bytes32 pin = factory.splitWalletImplementationCodeHash();
        bytes memory original = implementation.code;
        vm.etch(implementation, hex"00");
        require(!factory.splitWalletExists(originalProfile), "pin fail closed");
        (IStreamSplitWallet.SplitEntry[] memory entries,,) = _inputs();
        bytes32 absent = factory.profileIdFor(entries, keccak256("new profile"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitWalletImplementation.SplitWalletImplementationChanged.selector,
                implementation,
                pin,
                keccak256(hex"00")
            )
        );
        factory.createProfile(entries, keccak256("new profile"));
        require(
            !factory.profileExists(absent) && factory.profileCount() == 1
                && factory.walletFor(absent).code.length == 0,
            "no partial publication"
        );
        vm.etch(implementation, original);
        require(
            factory.splitWalletExists(originalProfile), "restored exact runtime negative control"
        );
    }

    function testExactSignedSafeCallRetriesAfterRecipientRejection() public {
        SafeComponents memory c = deploySafeComponents("1.4.1");
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x101;
        keys[1] = 0x102;
        OfficialSafe safe = createOfficialSafe(c, safeOwnerAddresses(keys), 2, 444);
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(address(safe), 1_000_000, META);
        (, address deployed) = factory.createProfile(entries, META);
        IStreamSplitWallet wallet = IStreamSplitWallet(deployed);
        SplitCloneRecipient recipient = new SplitCloneRecipient();
        (bool funded,) = payable(deployed).call{ value: 1 ether }("");
        require(funded, "fund clone");
        bytes memory data = abi.encodeCall(
            IStreamSplitWallet.release, (address(0), address(safe), payable(address(recipient)))
        );
        uint256 nonce = safe.nonce();
        bytes memory signature = safeThresholdSignature(
            keys,
            safe.getTransactionHash(deployed, 0, data, 0, 0, 0, 0, address(0), address(0), nonce)
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        safe.execTransaction(
            deployed, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature
        );
        require(
            safe.nonce() == nonce && deployed.balance == 1 ether && address(recipient).balance == 0,
            "Safe and value rollback"
        );
        require(
            !wallet.assetObservationInitialized(address(0))
                && wallet.totalReleased(address(0)) == 0,
            "clone accounting rollback"
        );
        recipient.accept();
        require(
            safe.execTransaction(
                deployed, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature
            ),
            "identical signed CALL retry"
        );
        require(
            safe.nonce() == nonce + 1 && address(recipient).balance == 1 ether
                && deployed.balance == 0,
            "exact execution"
        );
        require(
            wallet.accountReleased(address(0), address(safe)) == 1 ether,
            "original entitlement owner"
        );
    }

    function _wallet() private returns (IStreamSplitWallet wallet) {
        (IStreamSplitWallet.SplitEntry[] memory entries,,) = _inputs();
        (, address deployed) = factory.createProfile(entries, META);
        wallet = IStreamSplitWallet(deployed);
    }

    function _inputs()
        private
        pure
        returns (
            IStreamSplitWallet.SplitEntry[] memory entries,
            address[] memory accounts,
            uint32[] memory shares
        )
    {
        entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(ACCOUNT, 1_000_000, keccak256("artist"));
        accounts = new address[](1);
        accounts[0] = ACCOUNT;
        shares = new uint32[](1);
        shares[0] = 1_000_000;
    }
}
