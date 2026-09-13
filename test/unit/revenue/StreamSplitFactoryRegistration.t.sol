// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/RevenueResolverTestMocks.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../mocks/MockStreamPaymentToken.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";

contract StreamSplitFactoryRegistrationTest is RevenueV1TestBase, OfficialSafeFixture {
    event SafeSelectorObserved(address indexed target, bytes4 indexed selector);
    bytes32 private constant CREATED =
        keccak256("SplitProfileCreated(bytes32,bytes32,bytes32,uint16,uint16,address)");
    bytes32 private constant ENTRY =
        keccak256("SplitProfileEntry(bytes32,uint16,address,uint16,uint32,bytes32)");
    bytes32 private constant DEPLOYED =
        keccak256("SplitWalletDeployed(bytes32,address,uint16,uint16,bytes32,bytes32)");
    bytes32 private constant DEPOSIT_GAS = keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT");
    address private constant PAYEE = address(0xA11CE);
    StreamAssetPolicyRegistry private policy;
    StreamSplitFactory private factory;

    function setUp() public {
        policy = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        factory = new StreamSplitFactory(policy, address(revenueAuthority), _walletGasConfigs());
    }

    function testRegistrationCanonicalIdentityAndCreate2PreimagesAreUnchanged() public {
        IStreamSplitWallet.SplitEntry[] memory entries = _entries();
        IStreamSplitWallet.SplitEntry[] memory sorted = _entries();
        (sorted[0], sorted[1]) = (sorted[1], sorted[0]);
        bytes32 entriesHash = keccak256(abi.encode(sorted));
        bytes32 metadata = keccak256("registered canonical terms");
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_SPLIT_PROFILE_V1"),
                block.chainid,
                address(factory),
                uint16(1),
                uint16(3),
                factory.splitWalletInitCodeHash(),
                factory.splitWalletRuntimeCodeHash(),
                address(policy),
                entriesHash,
                metadata
            )
        );
        address predicted = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(factory),
                            expected,
                            factory.splitWalletInitCodeHash()
                        )
                    )
                )
            )
        );
        (bytes32 id, address wallet) = factory.registerProfile(entries, metadata);
        require(
            id == expected && wallet == predicted && factory.profileIdFor(sorted, metadata) == id,
            "canonical profile and CREATE2 identity"
        );
        require(
            factory.profileExists(id) && !factory.splitWalletExists(id) && wallet.code.length == 0,
            "registration is not deployment"
        );
        require(
            factory.profileEntriesHash(id) == entriesHash
                && factory.profileMetadataURIHash(id) == metadata,
            "immutable source terms"
        );
        (address account, uint32 share, bytes32 label) = factory.profileEntry(id, 0);
        require(
            account == sorted[0].account && share == sorted[0].sharePpm
                && label == sorted[0].labelId,
            "canonical entry persisted"
        );
    }

    function testEnumerationMatchesUniqueEventStreamAcrossDeferredAndImmediateCreation() public {
        vm.recordLogs();
        (bytes32 a,) = factory.registerProfile(_entries(), bytes32(uint256(1)));
        (bytes32 b,) = factory.createProfile(_entries(), bytes32(uint256(2)));
        IStreamSplitWallet.SplitEntry[] memory reverse = _entries();
        (reverse[0], reverse[1]) = (reverse[1], reverse[0]);
        factory.registerProfile(reverse, bytes32(uint256(1)));
        factory.createProfile(reverse, bytes32(uint256(1)));
        (bytes32 c,) = factory.registerProfile(_entries(), bytes32(uint256(3)));
        factory.deployWallet(b);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 cursor;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(factory) || logs[i].topics[0] != CREATED) continue;
            require(
                factory.profileAt(cursor) == logs[i].topics[1], "events and state have same order"
            );
            (uint16 schema, uint16 version, address wallet) =
                abi.decode(logs[i].data, (uint16, uint16, address));
            require(
                schema == 1 && version == 3 && wallet == factory.walletAt(cursor),
                "versioned wallet inventory"
            );
            require(wallet == factory.walletFor(factory.profileAt(cursor)), "state-only prediction");
            ++cursor;
        }
        require(cursor == 3 && factory.profileCount() == 3, "one index/event per canonical profile");
        require(
            factory.profileAt(0) == a && factory.profileAt(1) == b && factory.profileAt(2) == c,
            "append-only stable positions"
        );
        require(
            factory.splitWalletExists(a) && factory.splitWalletExists(b)
                && !factory.splitWalletExists(c),
            "enumeration independent of deployment state"
        );
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x32));
        factory.profileAt(3);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x32));
        factory.walletAt(type(uint256).max);
    }

    function testFactoryEventsCarryExactNormativeSchemaAndCanonicalEntries() public {
        vm.recordLogs();
        (bytes32 id, address wallet) = factory.registerProfile(_entries(), bytes32(uint256(4)));
        Vm.Log[] memory registered = vm.getRecordedLogs();
        uint256 entryCount;
        for (uint256 i; i < registered.length; ++i) {
            Vm.Log memory item = registered[i];
            if (item.emitter != address(factory)) continue;
            require(item.topics[0] != DEPLOYED, "registration cannot emit wallet deployed");
            if (item.topics[0] != ENTRY) continue;
            require(
                item.topics.length == 4 && item.topics[1] == id && item.data.length == 96,
                "exact entry event ABI"
            );
            (uint16 schema, uint32 share, bytes32 label) =
                abi.decode(item.data, (uint16, uint32, bytes32));
            (address account, uint32 actualShare, bytes32 actualLabel) =
                factory.profileEntry(id, entryCount);
            require(
                uint256(item.topics[2]) == entryCount
                    && address(uint160(uint256(item.topics[3]))) == account && schema == 1
                    && share == actualShare && label == actualLabel,
                "canonical event payload"
            );
            ++entryCount;
        }
        require(entryCount == 2, "every canonical entry event");
        vm.recordLogs();
        factory.deployWallet(id);
        Vm.Log[] memory deployed = vm.getRecordedLogs();
        uint256 count;
        for (uint256 i; i < deployed.length; ++i) {
            Vm.Log memory item = deployed[i];
            if (item.emitter != address(factory) || item.topics[0] != DEPLOYED) continue;
            require(
                item.topics.length == 4 && item.topics[1] == id
                    && address(uint160(uint256(item.topics[2]))) == wallet
                    && uint256(item.topics[3]) == 3 && item.data.length == 96,
                "exact wallet event ABI"
            );
            (uint16 schema, bytes32 initHash, bytes32 runtimeHash) =
                abi.decode(item.data, (uint16, bytes32, bytes32));
            require(
                schema == 1 && initHash == factory.splitWalletInitCodeHash()
                    && runtimeHash == wallet.codehash,
                "actual deployed identity in event"
            );
            ++count;
        }
        require(count == 1, "exactly one deployment event");
    }

    function testFirstCreateFailureRollsBackRegistrationButLaterDeployFailurePreservesIt() public {
        IStreamSplitWallet.SplitEntry[] memory entries = _entries();
        bytes32 metadata = keccak256("poisoned identity");
        bytes32 id = factory.profileIdFor(entries, metadata);
        address wallet = factory.walletFor(id);
        vm.etch(wallet, hex"60006000fd");
        bytes memory reason = abi.encodeWithSelector(
            IStreamSplitFactory.SplitWalletAddressPoisoned.selector, id, wallet
        );
        vm.expectRevert(reason);
        factory.createProfile(entries, metadata);
        require(
            factory.profileCount() == 0 && !factory.profileExists(id)
                && factory.profileEntryCount(id) == 0,
            "atomic convenience rolls registration and index back"
        );
        factory.registerProfile(entries, metadata);
        bytes32 entriesHash = factory.profileEntriesHash(id);
        vm.expectRevert(reason);
        factory.deployWallet(id);
        vm.expectRevert(reason);
        factory.createProfile(entries, metadata);
        require(
            factory.profileCount() == 1 && factory.profileAt(0) == id && factory.profileExists(id)
                && factory.profileEntriesHash(id) == entriesHash && !factory.splitWalletExists(id),
            "standalone registration persists without pretending poison is a wallet"
        );
    }

    function testPreFundedNativeAndERC20RemainReceiptsAfterDeferredDeployment() public {
        MockStreamPaymentToken token = new MockStreamPaymentToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("standard token"), 0);
        (bytes32 id, address predicted) = factory.registerProfile(_single(), bytes32(uint256(5)));
        vm.deal(address(this), 2 ether);
        (bool sent,) = payable(predicted).call{ value: 2 ether }("");
        require(sent && predicted.code.length == 0, "native prefunding of predicted account");
        token.mint(address(this), 1234);
        token.transfer(predicted, 1234);
        require(
            !factory.splitWalletExists(id),
            "prefunding is not verified deployment or official settlement"
        );
        factory.deployWallet(id);
        IStreamSplitWallet wallet = IStreamSplitWallet(predicted);
        require(
            wallet.factory() == address(factory) && wallet.profileId() == id
                && wallet.initialized(),
            "linked CREATE2 preserves factory constructor and initializer authority"
        );
        require(
            wallet.observedReceived(address(0)) == 2 ether
                && wallet.observedReceived(address(token)) == 1234,
            "all prefunded money remains observable"
        );
        require(
            wallet.release(address(0), PAYEE, payable(PAYEE)) == 2 ether, "native donation claim"
        );
        require(
            wallet.release(address(token), PAYEE, payable(PAYEE)) == 1234, "token donation claim"
        );
        require(
            PAYEE.balance == 2 ether && token.balanceOf(PAYEE) == 1234, "actual recipient balances"
        );
    }

    function testRegistrationCannotSatisfyResolversDeployedProfileRequirement() public {
        RevenueResolverCoreMock core = new RevenueResolverCoreMock();
        RevenueResolverArtistMock artist = new RevenueResolverArtistMock(address(core));
        core.selectArtist(address(artist), address(artist).codehash);
        StreamRevenueResolver resolver = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(revenueAuthority),
            artist,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        vm.prank(address(revenueAuthority));
        resolver.transferOwnership(address(this));
        (bytes32 id,) = factory.registerProfile(_single(), bytes32(uint256(6)));
        bytes32 revenueClass = keccak256("PRIMARY_SALE");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.UnverifiedSplitProfile.selector, id)
        );
        resolver.setPrimaryProfileAssignment(revenueClass, 1, 1, id, bytes32(0));
        factory.deployWallet(id);
        resolver.setPrimaryProfileAssignment(revenueClass, 1, 1, id, bytes32(0));
        require(
            resolver.resolvePrimaryAssignment(1, 0, revenueClass).profileId == id,
            "actual wallet required"
        );
    }

    function testRepeatedRegistrationNeverDeploysOrRewritesTerms() public {
        (bytes32 id, address predicted) = factory.registerProfile(_entries(), bytes32(uint256(7)));
        vm.recordLogs();
        (bytes32 repeated, address same) = factory.registerProfile(_entries(), bytes32(uint256(7)));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            id == repeated && predicted == same && predicted.code.length == 0
                && factory.profileCount() == 1 && logs.length == 0,
            "idempotent registration without side effects"
        );
        factory.createProfile(_entries(), bytes32(uint256(7)));
        require(
            factory.splitWalletExists(id) && factory.profileCount() == 1,
            "convenience deploys existing profile once"
        );
    }

    function testInvalidRegistrationAndUnknownDeployLeaveInventoryUntouched() public {
        IStreamSplitWallet.SplitEntry[] memory empty = new IStreamSplitWallet.SplitEntry[](0);
        vm.expectRevert(abi.encodeWithSelector(IStreamSplitFactory.InvalidEntryCount.selector, 0));
        factory.registerProfile(empty, bytes32(0));
        IStreamSplitWallet.SplitEntry[] memory bad = _single();
        bad[0].sharePpm = 1;
        vm.expectRevert(abi.encodeWithSelector(IStreamSplitFactory.InvalidSplitTotal.selector, 1));
        factory.registerProfile(bad, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamSplitFactory.UnknownProfile.selector, bytes32(uint256(99))
            )
        );
        factory.deployWallet(bytes32(uint256(99)));
        require(factory.profileCount() == 0, "invalid input adds no profile");
    }

    function testDepositBudgetUsesExactThirdConfigAndGovernedRaiseWithoutIdentityChange() public {
        bytes32[] memory ids = factory.gasParameterIds();
        require(
            ids.length == 3 && ids[2] == DEPOSIT_GAS && factory.gasParameter(DEPOSIT_GAS) == 50_000
                && factory.gasParameterFloor(DEPOSIT_GAS) == 25_000,
            "third explicit parameter config"
        );
        (bytes32 id, address predicted) = factory.registerProfile(_entries(), bytes32(uint256(8)));
        bytes32 entriesHash = factory.profileEntriesHash(id);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(this)
            )
        );
        factory.raiseGasParameter(DEPOSIT_GAS, 100_000);
        _raiseDeposit(100_000);
        require(
            factory.gasParameter(DEPOSIT_GAS) == 100_000
                && factory.gasParameterFloor(DEPOSIT_GAS) == 25_000
                && factory.profileIdFor(_entries(), bytes32(uint256(8))) == id
                && factory.walletFor(id) == predicted
                && factory.profileEntriesHash(id) == entriesHash,
            "operational raise cannot change economic identity"
        );
        vm.prank(address(revenueAuthority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotARaise.selector, DEPOSIT_GAS, 100_000, 50_000
            )
        );
        factory.raiseGasParameter(DEPOSIT_GAS, 50_000);
        vm.prank(address(revenueAuthority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterRaiseBoundExceeded.selector,
                DEPOSIT_GAS,
                100_000,
                200_001
            )
        );
        factory.raiseGasParameter(DEPOSIT_GAS, 200_001);
    }

    function testMissingMisclassifiedOrMisnamedDepositConfigIsRejected() public {
        IStreamGasParameterHost.GasParameterConfig[3] memory configs = _walletGasConfigs();
        configs[2].name = "ASSET_POLICY_GAS_LIMIT";
        bytes memory error = abi.encodeWithSelector(
            IStreamGasParameterHost.GasParameterInvalidConfig.selector,
            keccak256("WALLET_DEPOSIT_GAS_LIMIT")
        );
        vm.expectRevert(error);
        new StreamSplitFactory(policy, address(revenueAuthority), configs);
        configs = _walletGasConfigs();
        configs[2].failureClass = 1;
        vm.expectRevert(error);
        new StreamSplitFactory(policy, address(revenueAuthority), configs);
        configs = _walletGasConfigs();
        configs[2].floor = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterInvalidConfig.selector, DEPOSIT_GAS
            )
        );
        new StreamSplitFactory(policy, address(revenueAuthority), configs);
    }

    function testActualSafeRegistersReadsDeploysAndReusesAllNewSelectors() public {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0x101;
        owners[1] = 0x102;
        owners[2] = 0x103;
        uint256[] memory keys = new uint256[](2);
        keys[0] = owners[0];
        keys[1] = owners[1];
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 133);
        bytes32 id = factory.profileIdFor(_single(), bytes32(uint256(9)));
        _safeExec(
            safe,
            keys,
            abi.encodeCall(IStreamSplitFactory.registerProfile, (_single(), bytes32(uint256(9))))
        );
        require(
            factory.profileExists(id) && !factory.splitWalletExists(id),
            "actual Safe registered only"
        );
        _safeRead(safe, keys, abi.encodeCall(IStreamSplitFactory.profileCount, ()));
        _safeRead(safe, keys, abi.encodeCall(IStreamSplitFactory.profileAt, (0)));
        _safeRead(safe, keys, abi.encodeCall(IStreamSplitFactory.walletAt, (0)));
        _safeExec(safe, keys, abi.encodeCall(IStreamSplitFactory.deployWallet, (id)));
        require(factory.splitWalletExists(id), "actual Safe deployed matching wallet");
        _safeExec(
            safe,
            keys,
            abi.encodeCall(IStreamSplitFactory.createProfile, (_single(), bytes32(uint256(9))))
        );
        require(factory.profileCount() == 1, "actual Safe reuse preserves index");
    }

    function _safeRead(OfficialSafe safe, uint256[] memory keys, bytes memory data) private {
        (bool ok, bytes memory baseline) = address(factory).staticcall(data);
        vm.prank(address(safe));
        (bool safeOk, bytes memory actual) = address(factory).staticcall(data);
        require(
            ok && safeOk && baseline.length == 32 && keccak256(actual) == keccak256(baseline),
            "exact Safe read values"
        );
        _safeExec(safe, keys, data);
    }

    function _safeExec(OfficialSafe safe, uint256[] memory keys, bytes memory data) private {
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(executeSafe(safe, keys, address(factory), 0, data, 0), "actual Safe execution");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool success;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe) && logs[i].topics.length != 0
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) success = true;
        }
        require(success && safe.nonce() == nonce + 1, "actual Safe success event and nonce");
        emit SafeSelectorObserved(address(factory), bytes4(data));
    }

    function _raiseDeposit(uint256 value) private {
        (uint256 oldValue, uint256 floor, uint8 kind, uint64 revision) =
            factory.gasParameterInfo(DEPOSIT_GAS);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(factory),
                DEPOSIT_GAS
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        revenueAuthority.setCurrentAction(
            true,
            keccak256("deposit raise"),
            1,
            scope,
            keccak256(abi.encode(domain, scope, oldValue, floor, kind, revision)),
            keccak256(abi.encode(domain, scope, value, floor, kind, revision + 1))
        );
        vm.prank(address(revenueAuthority));
        factory.raiseGasParameter(DEPOSIT_GAS, value);
        revenueAuthority.setCurrentAction(false, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
    }

    function _entries() private pure returns (IStreamSplitWallet.SplitEntry[] memory entries) {
        entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] = IStreamSplitWallet.SplitEntry(PAYEE, 600_000, bytes32(uint256(1)));
        entries[1] = IStreamSplitWallet.SplitEntry(address(0xB0B), 400_000, bytes32(uint256(2)));
    }

    function _single() private pure returns (IStreamSplitWallet.SplitEntry[] memory entries) {
        entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(PAYEE, 1_000_000, bytes32(uint256(1)));
    }
}
