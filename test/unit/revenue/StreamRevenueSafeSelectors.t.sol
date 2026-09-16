// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../mocks/MockStreamPaymentToken.sol";
import "../../../smart-contracts/domains/revenue/StreamClaimRouter.sol";

/// @dev Actual 2-of-3 Safe execution for every selector in this revenue slice.
///      Governance target rejection is tested here; accepted Safe -> Executor timelock
///      execution is the current-stack integration suite, not this target-side fixture.
contract StreamRevenueSafeSelectorsTest is RevenueV1TestBase, OfficialSafeFixture {
    event SafeSelectorObserved(address indexed target, bytes4 indexed selector, uint8 result);
    StreamAssetPolicyRegistry private policy;
    StreamSplitFactory private factory;
    StreamClaimRouter private router;
    IStreamSplitWallet private wallet;
    MockStreamPaymentToken private token;
    OfficialSafe private safe;
    uint256[] private keys;
    bytes32 private profile;
    address private constant RECIPIENT = address(0xCAFE);
    bytes32 private constant GAS_ID = keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT");

    function setUp() public {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0x101;
        owners[1] = 0x102;
        owners[2] = 0x103;
        keys.push(owners[0]);
        keys.push(owners[1]);
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 111);
        policy = new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        factory = new StreamSplitFactory(policy, address(revenueAuthority), _walletGasConfigs());
        router = new StreamClaimRouter();
        token = new MockStreamPaymentToken();
        _setAssetPolicy(policy, address(token), 1, keccak256("standard token"), 0);
        address target;
        (profile, target) = factory.createProfile(_entries(), bytes32(uint256(111)));
        wallet = IStreamSplitWallet(target);
    }

    function testSafeExecutesAllPermissionlessAndPayeeWrites() public {
        IStreamSplitWallet.SplitEntry[] memory entries = _entries();
        bytes32 secondProfile = factory.profileIdFor(entries, bytes32(uint256(222)));
        _exec(
            address(factory),
            0,
            abi.encodeCall(IStreamSplitFactory.createProfile, (entries, bytes32(uint256(222))))
        );
        IStreamSplitWallet second = IStreamSplitWallet(factory.walletFor(secondProfile));
        require(
            second.initialized() && second.factory() == address(factory),
            "factory-only initialization succeeded"
        );
        _exec(
            address(factory), 0, abi.encodeCall(IStreamSplitFactory.deployWallet, (secondProfile))
        );
        require(factory.splitWalletExists(secondProfile), "Safe deploy/reuse binding");

        token.mint(address(wallet), 100);
        _exec(address(wallet), 0, abi.encodeCall(IStreamSplitWallet.syncAsset, (address(token))));
        require(wallet.assetObservationInitialized(address(token)), "Safe sync recorded");
        _exec(
            address(wallet),
            0,
            abi.encodeCall(
                IStreamSplitWallet.release, (address(token), address(safe), payable(RECIPIENT))
            )
        );
        require(
            token.balanceOf(RECIPIENT) == 100
                && wallet.accountReleased(address(token), address(safe)) == 100,
            "Safe directs its ERC20 payout"
        );

        vm.deal(address(safe), 2 ether);
        _exec(address(wallet), 2 ether, bytes(""));
        require(address(wallet).balance == 2 ether, "Safe native receive transfer");
        IStreamSplitWallet.ReleaseAuthorization memory a = _authorization();
        a.releasableSnapshot = 2 ether;
        bytes memory signature = safeThresholdSignature(
            keys, safeMessageDigest(safe, abi.encode(wallet.releaseAuthorizationDigest(a)))
        );
        _exec(
            address(wallet),
            0,
            abi.encodeCall(IStreamSplitWallet.releaseWithAuthorization, (a, signature))
        );
        require(
            RECIPIENT.balance == 2 ether
                && wallet.isReleaseAuthorizationNonceUsed(address(safe), a.nonce),
            "Safe submits valid signed release"
        );
        bytes32 nonce = keccak256("direct Safe revoke");
        _exec(
            address(wallet),
            0,
            abi.encodeCall(IStreamSplitWallet.revokeReleaseAuthorization, (nonce))
        );
        require(
            wallet.isReleaseAuthorizationNonceUsed(address(safe), nonce),
            "actual Safe owns revocation"
        );
        nonce = keccak256("signed Safe revoke");
        signature = safeThresholdSignature(
            keys,
            safeMessageDigest(
                safe, abi.encode(wallet.releaseRevocationDigest(address(safe), nonce, a.deadline))
            )
        );
        _exec(
            address(wallet),
            0,
            abi.encodeCall(
                IStreamSplitWallet.revokeReleaseAuthorizationBySignature,
                (address(safe), nonce, a.deadline, signature)
            )
        );
        require(
            wallet.isReleaseAuthorizationNonceUsed(address(safe), nonce),
            "Safe submits signed revoke"
        );

        vm.deal(address(second), 1 ether);
        IStreamClaimRouter.ClaimCall[] memory claims = new IStreamClaimRouter.ClaimCall[](1);
        claims[0] = IStreamClaimRouter.ClaimCall(address(second), address(0), address(safe));
        _exec(address(router), 0, abi.encodeCall(IStreamClaimRouter.claimMany, (claims, false)));
        require(
            address(safe).balance == 1 ether && second.totalReleased(address(0)) == 1 ether,
            "router pays actual Safe"
        );
        token.mint(address(second), 50);
        claims[0].asset = address(token);
        _exec(
            address(router), 0, abi.encodeCall(IStreamClaimRouter.syncAndClaimMany, (claims, false))
        );
        require(
            token.balanceOf(address(safe)) == 50 && second.totalReleased(address(token)) == 50,
            "router sync and token payout"
        );
    }

    function testSafeCannotDirectlyExerciseFactoryOrGovernanceOnlyWrites() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(safe);
        uint32[] memory shares = new uint32[](1);
        shares[0] = 1_000_000;
        _reject(
            address(wallet),
            abi.encodeCall(
                IStreamSplitWallet.initialize,
                (profile, wallet.entriesHash(), bytes32(uint256(111)), _entries(), accounts, shares)
            ),
            abi.encodeWithSelector(
                IStreamSplitWallet.UnauthorizedInitializer.selector, address(safe)
            )
        );
        _reject(
            address(factory),
            abi.encodeCall(IStreamGasParameterHost.raiseGasParameter, (GAS_ID, 800_000)),
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(safe)
            )
        );
        _reject(
            address(policy),
            abi.encodeCall(
                IStreamAssetPolicyRegistry.setAssetStatus,
                (address(token), uint8(2), keccak256("inactive"), uint64(0))
            ),
            abi.encodeWithSelector(
                IStreamAssetPolicyRegistry.AssetPolicyNotAuthority.selector, address(safe)
            )
        );
        require(
            wallet.initialized() && factory.gasParameter(GAS_ID) == 400_000
                && policy.assetStatus(address(token)) == 1,
            "roles retained after Safe rejection"
        );
    }

    function testSafeCanReadDeploymentLibraryButCannotInvokeItsDelegatecallOnlyCreate() public {
        address libraryAddress = address(StreamSplitWalletDeployment);
        _read(libraryAddress, abi.encodeWithSignature("initCodeHash()"));
        _read(libraryAddress, abi.encodeWithSignature("runtimeCodeHash()"));
        _reject(
            libraryAddress,
            abi.encodeWithSignature("deploy(bytes32)", bytes32(uint256(999))),
            bytes("")
        );
        require(
            wallet.factory() == address(factory) && factory.splitWalletExists(profile),
            "normal factory delegatecall route remains initialized and bound"
        );
    }

    function testSafeExecutesEveryStreamSplitWalletRead() public {
        _read(
            address(wallet), abi.encodeWithSignature("RELEASE_AUTHORIZATION_REVOCATION_TYPEHASH()")
        );
        _read(address(wallet), abi.encodeWithSignature("RELEASE_AUTHORIZATION_TYPEHASH()"));
        _read(address(wallet), abi.encodeWithSignature("SHARE_DENOMINATOR_PPM()"));
        _read(
            address(wallet),
            abi.encodeWithSignature(
                "accountReleased(address,address)", address(token), address(safe)
            )
        );
        _read(address(wallet), abi.encodeWithSignature("aggregateSharePpm(address)", address(safe)));
        _read(
            address(wallet),
            abi.encodeWithSignature("assetObservationInitialized(address)", address(token))
        );
        _read(address(wallet), abi.encodeWithSignature("assetPolicyRegistry()"));
        _read(address(wallet), abi.encodeWithSignature("domainSeparator()"));
        _read(address(wallet), abi.encodeWithSignature("eip712Domain()"));
        _read(address(wallet), abi.encodeWithSignature("entriesHash()"));
        _read(address(wallet), abi.encodeWithSignature("entry(uint256)", uint256(0)));
        _read(address(wallet), abi.encodeWithSignature("entryCount()"));
        _read(address(wallet), abi.encodeWithSignature("factory()"));
        _read(address(wallet), abi.encodeWithSignature("initialized()"));
        _read(
            address(wallet),
            abi.encodeWithSignature(
                "isReleaseAuthorizationNonceUsed(address,bytes32)", address(safe), bytes32(0)
            )
        );
        _read(
            address(wallet),
            abi.encodeWithSignature("lastObservedReceived(address)", address(token))
        );
        _read(address(wallet), abi.encodeWithSignature("metadataURIHash()"));
        _read(address(wallet), abi.encodeWithSignature("observedReceived(address)", address(token)));
        _read(address(wallet), abi.encodeWithSignature("profileId()"));
        _read(
            address(wallet),
            abi.encodeWithSignature("releasable(address,address)", address(token), address(safe))
        );
        _read(
            address(wallet),
            abi.encodeWithSignature(
                "releaseAuthorizationDigest((address,address,address,uint256,bytes32,uint64))",
                _authorization()
            )
        );
        _read(
            address(wallet),
            abi.encodeWithSignature(
                "releaseRevocationDigest(address,bytes32,uint64)",
                address(safe),
                bytes32(0),
                uint64(block.timestamp + 1 days)
            )
        );
        _read(address(wallet), abi.encodeWithSignature("roundingDust(address)", address(token)));
        _read(address(wallet), abi.encodeWithSignature("totalReleased(address)", address(token)));
        _read(address(wallet), abi.encodeWithSignature("uniqueAccount(uint256)", uint256(0)));
        _read(address(wallet), abi.encodeWithSignature("uniqueAccountCount()"));
    }

    function testSafeExecutesEveryStreamSplitFactoryRead() public {
        _read(address(factory), abi.encodeWithSignature("FAILURE_CLASS_FAIL_CLOSED_PRECHECK()"));
        _read(address(factory), abi.encodeWithSignature("FAILURE_CLASS_FORWARDING_CAP()"));
        _read(address(factory), abi.encodeWithSignature("FAILURE_CLASS_MIN_GAS_GATE()"));
        _read(address(factory), abi.encodeWithSignature("FAILURE_CLASS_NONE()"));
        _read(address(factory), abi.encodeWithSignature("GAS_PARAMETER_SCHEMA_VERSION()"));
        _read(address(factory), abi.encodeWithSignature("MAX_ENTRIES()"));
        _read(address(factory), abi.encodeWithSignature("MAX_UNIQUE_ACCOUNTS()"));
        _read(address(factory), abi.encodeWithSignature("PROFILE_DOMAIN()"));
        _read(address(factory), abi.encodeWithSignature("SCHEMA_VERSION()"));
        _read(address(factory), abi.encodeWithSignature("SHARE_DENOMINATOR_PPM()"));
        _read(address(factory), abi.encodeWithSignature("WALLET_VERSION()"));
        _read(address(factory), abi.encodeWithSignature("assetPolicyRegistry()"));
        _read(address(factory), abi.encodeWithSignature("gasParameter(bytes32)", GAS_ID));
        _read(address(factory), abi.encodeWithSignature("gasParameterFloor(bytes32)", GAS_ID));
        _read(address(factory), abi.encodeWithSignature("gasParameterIds()"));
        _read(address(factory), abi.encodeWithSignature("gasParameterInfo(bytes32)", GAS_ID));
        _read(address(factory), abi.encodeWithSignature("governanceAuthority()"));
        _read(address(factory), abi.encodeWithSignature("profileEntriesHash(bytes32)", profile));
        _read(
            address(factory),
            abi.encodeWithSignature("profileEntry(bytes32,uint256)", profile, uint256(0))
        );
        _read(address(factory), abi.encodeWithSignature("profileEntryCount(bytes32)", profile));
        _read(address(factory), abi.encodeWithSignature("profileExists(bytes32)", profile));
        _read(
            address(factory),
            abi.encodeWithSignature(
                "profileIdFor((address,uint32,bytes32)[],bytes32)",
                _entries(),
                bytes32(uint256(111))
            )
        );
        _read(address(factory), abi.encodeWithSignature("profileMetadataURIHash(bytes32)", profile));
        _read(
            address(factory),
            abi.encodeWithSignature("profileUniqueAccount(bytes32,uint256)", profile, uint256(0))
        );
        _read(
            address(factory), abi.encodeWithSignature("profileUniqueAccountCount(bytes32)", profile)
        );
        _read(address(factory), abi.encodeWithSignature("splitWalletExists(bytes32)", profile));
        _read(address(factory), abi.encodeWithSignature("splitWalletInitCodeHash()"));
        _read(address(factory), abi.encodeWithSignature("splitWalletRuntimeCodeHash()"));
        _read(address(factory), abi.encodeWithSignature("walletFor(bytes32)", profile));
    }

    function testSafeExecutesEveryStreamAssetPolicyRegistryRead() public {
        _read(address(policy), abi.encodeWithSignature("ASSET_STATUS_ACTIVE()"));
        _read(address(policy), abi.encodeWithSignature("ASSET_STATUS_DEPRECATED()"));
        _read(address(policy), abi.encodeWithSignature("ASSET_STATUS_INACTIVE()"));
        _read(address(policy), abi.encodeWithSignature("ASSET_STATUS_UNKNOWN()"));
        _read(address(policy), abi.encodeWithSignature("ASSET_STATUS_UNSUPPORTED()"));
        _read(address(policy), abi.encodeWithSignature("assetPolicy(address)", address(token)));
        _read(
            address(policy),
            abi.encodeWithSignature("assetPolicyEffectiveAt(address)", address(token))
        );
        _read(address(policy), abi.encodeWithSignature("assetPolicyHash(address)", address(token)));
        _read(
            address(policy), abi.encodeWithSignature("assetPolicyRevision(address)", address(token))
        );
        _read(
            address(policy),
            abi.encodeWithSignature(
                "assetPolicyTransitionHashes(address,uint8,bytes32,uint64)",
                address(token),
                uint8(2),
                keccak256("inactive"),
                uint64(0)
            )
        );
        _read(
            address(policy),
            abi.encodeWithSignature("assetReleaseGraceUntil(address)", address(token))
        );
        _read(address(policy), abi.encodeWithSignature("assetStatus(address)", address(token)));
        _read(address(policy), abi.encodeWithSignature("governanceAuthority()"));
        _read(address(policy), abi.encodeWithSignature("isAssetActive(address)", address(token)));
        _read(address(policy), abi.encodeWithSignature("isStreamAssetPolicyRegistry()"));
    }

    function _entries() private view returns (IStreamSplitWallet.SplitEntry[] memory entries) {
        entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] =
            IStreamSplitWallet.SplitEntry(address(safe), 1_000_000, keccak256("Safe payee"));
    }

    function _authorization()
        private
        view
        returns (IStreamSplitWallet.ReleaseAuthorization memory)
    {
        return IStreamSplitWallet.ReleaseAuthorization(
                address(0),
                address(safe),
                RECIPIENT,
                0,
                keccak256("Safe release"),
                uint64(block.timestamp + 1 days)
            );
    }

    function _read(address target, bytes memory data) private {
        (bool baselineOk, bytes memory expected) = target.staticcall(data);
        vm.prank(address(safe));
        (bool safeOk, bytes memory actual) = target.staticcall(data);
        require(
            baselineOk && safeOk && expected.length != 0
                && keccak256(actual) == keccak256(expected),
            "Safe read result matches public result"
        );
        // Safe.execTransaction does not return inner returndata. The static read above
        // checks values; this execution separately proves the real Safe call succeeds.
        _exec(target, 0, data);
    }

    function _exec(address target, uint256 value, bytes memory data) private {
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(executeSafe(safe, keys, target, value, data, 0), "actual Safe call failed");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool success;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe) && logs[i].topics.length != 0
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) success = true;
        }
        require(success && safe.nonce() == nonce + 1, "Safe success event and nonce");
        emit SafeSelectorObserved(target, bytes4(data), 1);
    }

    function _reject(address target, bytes memory data, bytes memory expected) private {
        vm.prank(address(safe));
        (bool ok, bytes memory reason) = target.call(data);
        require(!ok && keccak256(reason) == keccak256(expected), "exact protocol role rejection");
        uint256 nonce = safe.nonce();
        bytes32 digest =
            safe.getTransactionHash(target, 0, data, 0, 0, 0, 0, address(0), address(0), nonce);
        bytes memory signature = safeThresholdSignature(keys, digest);
        // Safe with safeTxGas=0 reverts GS013 on inner failure. This is not success.
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        safe.execTransaction(
            target, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature
        );
        require(safe.nonce() == nonce, "failed Safe call preserves nonce");
        emit SafeSelectorObserved(target, bytes4(data), 2);
    }
}
