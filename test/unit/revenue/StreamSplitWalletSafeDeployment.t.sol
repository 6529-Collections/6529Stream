// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamSplitFactory
} from "../../../smart-contracts/domains/revenue/StreamSplitFactory.sol";
import {
    StreamAssetPolicyRegistry
} from "../../../smart-contracts/domains/revenue/StreamAssetPolicyRegistry.sol";
import {
    IStreamSplitFactory
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamSplitFactory.sol";
import {
    IStreamSplitWallet
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamSplitWallet.sol";
import {
    IStreamGasParameterHost
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { MockGovernedParameterAuthority } from "../../helpers/GovernedParameterTestMocks.sol";
import { OfficialSafe, OfficialSafeFixture } from "../../helpers/OfficialSafeFixture.sol";

interface SplitSafeDeploymentVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function deal(address account, uint256 balance) external;
    function prank(address caller) external;
    function load(address target, bytes32 slot) external view returns (bytes32);
    function expectCall(address target, bytes calldata data, uint64 count) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @notice Real factory/clone deployment and initialization boundaries through upstream 2-of-3 Safes.
/// @dev MockGovernedParameterAuthority supplies the constructor authority marker only; this is not
///      an actual Governor or full-current-stack test. The optional revenue runtime registry stays
///      unbound. Gas settings copy RevenueV1TestBase and are local, non-cold fixture limits, not
///      release capacity evidence. All signing keys are public deterministic test fixtures.
contract StreamSplitWalletSafeDeploymentTest is OfficialSafeFixture {
    SplitSafeDeploymentVm private constant vm =
        SplitSafeDeploymentVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant META = keccak256("Safe split deployment metadata");
    bytes32 private constant LABEL = keccak256("artist");
    bytes32 private constant DEPLOYED =
        keccak256("SplitWalletDeployed(bytes32,address,uint16,uint16,bytes32,bytes32)");
    bytes32 private constant EXECUTION_SUCCESS = keccak256("ExecutionSuccess(bytes32,uint256)");
    bytes32 private constant EXECUTION_FAILURE = keccak256("ExecutionFailure(bytes32,uint256)");
    uint256 private constant FAILURE_CALL_GAS = 100_000;
    uint256 private constant WALLET_BALANCE = 12345;

    StreamSplitFactory private factory;
    StreamAssetPolicyRegistry private policy;
    OfficialSafe private account;
    uint256[] private signerKeys;
    bool private indexedExecutionHash;
    bool private bubblesTargetRevert;

    struct Attempt {
        uint256 nonceBefore;
        bytes32 transactionHash;
        bytes envelope;
        bool outerSuccess;
        bool callSuccess;
        bytes result;
    }

    event SafeDeploymentFixture(
        string version,
        address indexed safe,
        bytes32 safeRuntimeHash,
        address singleton,
        bytes32 singletonRuntimeHash,
        address handler,
        bytes32 handlerRuntimeHash,
        address[] owners,
        uint256 threshold
    );
    event SplitDeploymentFixture(
        address indexed factory,
        bytes32 factoryRuntimeHash,
        address assetPolicy,
        address implementation,
        bytes32 implementationRuntimeHash,
        bytes32 cloneInitCodeHash,
        bytes32 cloneRuntimeHash
    );
    event SafeCallEvidence(
        address indexed safe,
        address indexed target,
        bytes data,
        uint256 safeTxGas,
        bytes32 transactionHash,
        bytes32 envelopeHash,
        uint256 nonceBefore,
        uint256 nonceAfter,
        bool outerSuccess,
        bool callSuccess,
        bytes result
    );
    event CallerBoundaryEvidence(
        address indexed caller, address indexed target, bytes data, bool success, bytes result
    );

    function testSafe130FactoryDeploymentAndInitializationBoundaries() public {
        _exercise("1.3.0", false, false);
    }

    function testSafe141FactoryDeploymentAndInitializationBoundaries() public {
        _exercise("1.4.1", true, false);
    }

    function testSafe150FactoryDeploymentAndInitializationBoundaries() public {
        _exercise("1.5.0", true, true);
    }

    function _exercise(string memory version, bool indexedHash, bool bubblesRevert) private {
        _setup(version, indexedHash, bubblesRevert);
        IStreamSplitWallet.SplitEntry[] memory entries = _entries();
        (bytes32 profile, address predicted) = factory.registerProfile(entries, META);
        require(factory.profileCount() == 1 && factory.profileExists(profile), "registered profile");
        require(
            predicted.code.length == 0 && !factory.splitWalletExists(profile), "not deployed yet"
        );
        vm.deal(address(this), WALLET_BALANCE);
        (bool funded,) = payable(predicted).call{ value: WALLET_BALANCE }("");
        require(funded && predicted.balance == WALLET_BALANCE, "actual counterfactual funding");

        bytes memory deployData = abi.encodeCall(IStreamSplitFactory.deployWallet, (profile));
        // Register the aggregate once; each signed attempt retains its own trace identity.
        vm.expectCall(address(factory), deployData, 2);
        _deploymentEvent(
            _safeCall(address(factory), deployData, 0, true, bytes("")), profile, predicted, 1
        );
        _walletState(profile, predicted, META);
        _deploymentEvent(
            _safeCall(address(factory), deployData, 0, true, bytes("")), profile, predicted, 0
        );
        _walletState(profile, predicted, META);
        require(factory.profileCount() == 1, "idempotent deployment preserves profile count");

        _unknownProfile();
        _initializerRefusals(profile, predicted);
        _permissionlessDeployment(safeVm.addr(0xA1101), keccak256("owner deployment"));
        address nonowner = address(0xB0B);
        address[] memory owners = account.getOwners();
        for (uint256 i; i < owners.length; ++i) {
            require(owners[i] != nonowner, "nonowner control");
        }
        _permissionlessDeployment(nonowner, keccak256("nonowner deployment"));
        _walletState(profile, predicted, META);
        require(factory.profileCount() == 3, "three independently deployed profiles");
    }

    function _setup(string memory version, bool indexedHash, bool bubblesRevert) private {
        MockGovernedParameterAuthority authority = new MockGovernedParameterAuthority(true);
        policy = new StreamAssetPolicyRegistry(address(authority));
        factory = new StreamSplitFactory(policy, address(authority), _walletGasConfigs());
        require(factory.revenueRuntimeRegistry() == address(0), "explicit unbound runtime seam");
        require(factory.WALLET_VERSION() == 4 && factory.SCHEMA_VERSION() == 1, "wallet version");
        indexedExecutionHash = indexedHash;
        bubblesTargetRevert = bubblesRevert;
        uint256[] memory ownerKeys = new uint256[](3);
        ownerKeys[0] = 0xA1101;
        ownerKeys[1] = 0xA1102;
        ownerKeys[2] = 0xA1103;
        signerKeys.push(ownerKeys[0]);
        signerKeys.push(ownerKeys[1]);
        address[] memory owners = safeOwnerAddresses(ownerKeys);
        SafeComponents memory c = deploySafeComponents(version);
        account = createOfficialSafe(c, owners, 2, 6529);
        require(
            keccak256(bytes(account.VERSION())) == keccak256(bytes(version)), "official version"
        );
        require(
            account.getThreshold() == 2 && account.nonce() == 0, "initial Safe threshold and nonce"
        );
        address[] memory actualOwners = account.getOwners();
        require(actualOwners.length == 3, "three owners");
        for (uint256 i; i < 3; ++i) {
            require(actualOwners[i] == owners[i], "exact owner list");
        }
        // Read-only inspection of the official Safe singleton and fallback-manager storage slots.
        require(
            address(uint160(uint256(vm.load(address(account), bytes32(0))))) == c.singleton,
            "singleton slot"
        );
        require(
            vm.load(address(account), keccak256("fallback_manager.handler.address"))
                == bytes32(uint256(uint160(c.handler))),
            "installed official compatibility handler"
        );
        require(
            c.handler.code.length != 0 && c.singleton.code.length != 0, "pinned upstream components"
        );
        emit SafeDeploymentFixture(
            version,
            address(account),
            address(account).codehash,
            c.singleton,
            c.singleton.codehash,
            c.handler,
            c.handler.codehash,
            owners,
            2
        );
        emit SplitDeploymentFixture(
            address(factory),
            address(factory).codehash,
            address(policy),
            factory.splitWalletImplementation(),
            factory.splitWalletImplementationCodeHash(),
            factory.splitWalletInitCodeHash(),
            factory.splitWalletRuntimeCodeHash()
        );
    }

    function _unknownProfile() private {
        bytes32 absent = keccak256("unregistered Safe profile");
        bytes memory data = abi.encodeCall(IStreamSplitFactory.deployWallet, (absent));
        bytes memory expectedRevert =
            abi.encodeWithSelector(IStreamSplitFactory.UnknownProfile.selector, absent);
        (bool ok, bytes memory result) = address(factory).call(data);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(IStreamSplitFactory.UnknownProfile.selector, absent)
                    ),
            "exact unknown-profile control"
        );
        // Count only the two Safe attempts; the direct error control above is already complete.
        vm.expectCall(address(factory), data, 2);
        _safeCall(address(factory), data, 0, false, expectedRevert);
        // A nonzero safeTxGas returns false and emits ExecutionFailure, consuming the nonce.
        _safeCall(address(factory), data, FAILURE_CALL_GAS, false, expectedRevert);
        require(
            !factory.profileExists(absent) && factory.walletFor(absent).code.length == 0,
            "unknown profile remains absent"
        );
        require(factory.profileCount() == 1, "failed calls create no profile");
    }

    function _initializerRefusals(bytes32 profile, address wallet) private {
        IStreamSplitWallet.SplitEntry[] memory entries = _entries();
        address[] memory accounts = new address[](1);
        accounts[0] = address(account);
        uint32[] memory shares = new uint32[](1);
        shares[0] = 1_000_000;
        bytes memory data = abi.encodeCall(
            IStreamSplitWallet.initialize,
            (profile, keccak256(abi.encode(entries)), META, entries, accounts, shares)
        );
        bytes memory expectedRevert = abi.encodeWithSelector(
            IStreamSplitWallet.UnauthorizedInitializer.selector, address(account)
        );
        uint256 nonce = account.nonce();
        // One aggregate expectation covers two Safe attempts and the owner EOA refusal.
        vm.expectCall(wallet, data, 3);
        _safeCall(wallet, data, 0, false, expectedRevert);
        _walletState(profile, wallet, META);
        // The failed outer calls preserve the Safe nonce; identical target/data therefore also
        // produce the identical transaction hash and deterministic signed envelope on this retry.
        _safeCall(wallet, data, 0, false, expectedRevert);
        require(account.nonce() == nonce, "repeated initializer preserves Safe nonce");
        _walletState(profile, wallet, META);
        address owner = safeVm.addr(0xA1101);
        // Explicit unit caller boundary: an owner EOA is not the initializing factory either.
        vm.prank(owner);
        (bool ok, bytes memory result) = wallet.call(data);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamSplitWallet.UnauthorizedInitializer.selector, owner
                        )
                    ),
            "owner initializer exact refusal"
        );
        emit CallerBoundaryEvidence(owner, wallet, data, ok, result);
        _walletState(profile, wallet, META);
    }

    function _permissionlessDeployment(address caller, bytes32 metadata) private {
        (bytes32 profile, address predicted) = factory.registerProfile(_entries(), metadata);
        require(predicted.code.length == 0, "fresh EOA control profile");
        bytes memory data = abi.encodeCall(IStreamSplitFactory.deployWallet, (profile));
        vm.recordLogs();
        // Unit caller substitution, not an EOA signature or a claim of owner-only deployment.
        vm.prank(caller);
        (bool ok, bytes memory result) = address(factory).call(data);
        require(
            ok && result.length == 32 && abi.decode(result, (address)) == predicted,
            "permissionless owner or nonowner deployment"
        );
        _deploymentEvent(vm.getRecordedLogs(), profile, predicted, 1);
        emit CallerBoundaryEvidence(caller, address(factory), data, ok, result);
        _walletState(profile, predicted, metadata);
    }

    function _safeCall(
        address target,
        bytes memory data,
        uint256 safeTxGas,
        bool expectedSuccess,
        bytes memory expectedInnerRevert
    ) private returns (SplitSafeDeploymentVm.Log[] memory logs) {
        Attempt memory a;
        a.nonceBefore = account.nonce();
        a.transactionHash = account.getTransactionHash(
            target, 0, data, 0, safeTxGas, 0, 0, address(0), address(0), a.nonceBefore
        );
        bytes memory signatures = safeThresholdSignature(signerKeys, a.transactionHash);
        require(signatures.length == 130, "exactly two real owner signatures");
        a.envelope = abi.encodeCall(
            OfficialSafe.execTransaction,
            (target, 0, data, 0, safeTxGas, 0, 0, address(0), payable(address(0)), signatures)
        );
        vm.recordLogs();
        (a.outerSuccess, a.result) = address(account).call(a.envelope);
        logs = vm.getRecordedLogs();
        if (!expectedSuccess && safeTxGas == 0) {
            // Safe 1.3.0/1.4.1 wrap a failed zero-gas-price estimation call in GS013;
            // Safe 1.5.0 instead bubbles the exact target revert bytes. Both roll back the nonce.
            require(expectedInnerRevert.length >= 4, "explicit target refusal oracle");
            bytes memory expectedOuterRevert = bubblesTargetRevert
                ? expectedInnerRevert
                : abi.encodeWithSignature("Error(string)", "GS013");
            require(
                !a.outerSuccess && keccak256(a.result) == keccak256(expectedOuterRevert),
                "exact version-specific outer rollback"
            );
            require(account.nonce() == a.nonceBefore, "failed outer call nonce rollback");
            _executionEvent(logs, a.transactionHash, false, 0);
        } else {
            require(a.outerSuccess && a.result.length == 32, "Safe outer returned bool");
            a.callSuccess = abi.decode(a.result, (bool));
            require(a.callSuccess == expectedSuccess, "actual Safe target outcome");
            require(account.nonce() == a.nonceBefore + 1, "completed Safe consumes one nonce");
            _executionEvent(logs, a.transactionHash, expectedSuccess, 1);
        }
        emit SafeCallEvidence(
            address(account),
            target,
            data,
            safeTxGas,
            a.transactionHash,
            keccak256(a.envelope),
            a.nonceBefore,
            account.nonce(),
            a.outerSuccess,
            a.callSuccess,
            a.result
        );
    }

    function _executionEvent(
        SplitSafeDeploymentVm.Log[] memory logs,
        bytes32 digest,
        bool success,
        uint256 expected
    ) private view {
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(account) || logs[i].topics.length == 0) continue;
            bytes32 topic = logs[i].topics[0];
            if (topic != EXECUTION_SUCCESS && topic != EXECUTION_FAILURE) continue;
            ++matches;
            require(
                topic == (success ? EXECUTION_SUCCESS : EXECUTION_FAILURE), "Safe event outcome"
            );
            if (indexedExecutionHash) {
                require(
                    logs[i].topics.length == 2 && logs[i].topics[1] == digest,
                    "indexed transaction hash"
                );
                require(
                    logs[i].data.length == 32 && abi.decode(logs[i].data, (uint256)) == 0,
                    "indexed zero payment"
                );
            } else {
                require(
                    logs[i].topics.length == 1 && logs[i].data.length == 64, "legacy event shape"
                );
                (bytes32 eventHash, uint256 payment) = abi.decode(logs[i].data, (bytes32, uint256));
                require(
                    eventHash == digest && payment == 0, "legacy transaction hash and zero payment"
                );
            }
        }
        require(matches == expected, "exact Safe execution event count");
    }

    function _deploymentEvent(
        SplitSafeDeploymentVm.Log[] memory logs,
        bytes32 profile,
        address wallet,
        uint256 expected
    ) private view {
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(factory) || logs[i].topics.length == 0
                    || logs[i].topics[0] != DEPLOYED
            ) continue;
            ++matches;
            require(
                logs[i].topics.length == 4 && logs[i].topics[1] == profile
                    && logs[i].topics[2] == bytes32(uint256(uint160(wallet)))
                    && logs[i].topics[3] == bytes32(uint256(4)),
                "exact deployed topics"
            );
            require(logs[i].data.length == 96, "exact deployed data length");
            (uint16 schema, bytes32 initHash, bytes32 runtimeHash) =
                abi.decode(logs[i].data, (uint16, bytes32, bytes32));
            require(
                schema == 1 && initHash == factory.splitWalletInitCodeHash()
                    && runtimeHash == factory.splitWalletRuntimeCodeHash(),
                "exact deployed data"
            );
        }
        require(matches == expected, "exact deployment event count");
    }

    function _walletState(bytes32 profile, address walletAddress, bytes32 metadata) private view {
        IStreamSplitWallet wallet = IStreamSplitWallet(walletAddress);
        bytes memory runtime = abi.encodePacked(
            hex"3615603257363d3d373d3d3d363d73",
            factory.splitWalletImplementation(),
            hex"5af43d82803e903d91603057fd5bf35b00"
        );
        require(
            runtime.length == 52 && keccak256(walletAddress.code) == keccak256(runtime),
            "actual exact clone code"
        );
        require(
            walletAddress.codehash == factory.splitWalletRuntimeCodeHash(), "factory runtime pin"
        );
        require(
            factory.splitWalletImplementation().codehash
                == factory.splitWalletImplementationCodeHash(),
            "implementation pin"
        );
        require(
            factory.splitWalletInitCodeHash()
                == keccak256(bytes.concat(hex"3d603480600a3d3981f3", runtime)),
            "exact creation code pin"
        );
        require(
            factory.walletFor(profile) == walletAddress && factory.splitWalletExists(profile),
            "factory verifies clone"
        );
        require(
            wallet.initialized() && wallet.factory() == address(factory),
            "initialized factory binding"
        );
        require(wallet.assetPolicyRegistry() == address(policy), "actual asset policy binding");
        require(
            wallet.profileId() == profile
                && wallet.entriesHash() == keccak256(abi.encode(_entries()))
                && wallet.metadataURIHash() == metadata,
            "immutable wallet profile"
        );
        require(
            factory.profileEntriesHash(profile) == wallet.entriesHash()
                && factory.profileMetadataURIHash(profile) == metadata,
            "factory profile unchanged"
        );
        require(
            wallet.entryCount() == 1 && wallet.uniqueAccountCount() == 1, "entry counts unchanged"
        );
        (address recipient, uint32 share, bytes32 label) = wallet.entry(0);
        require(
            recipient == address(account) && share == 1_000_000 && label == LABEL,
            "exact entry unchanged"
        );
        (address aggregate, uint32 aggregateShare) = wallet.uniqueAccount(0);
        require(
            aggregate == address(account) && aggregateShare == 1_000_000
                && wallet.aggregateSharePpm(address(account)) == 1_000_000,
            "aggregate unchanged"
        );
        require(
            walletAddress.balance == (metadata == META ? WALLET_BALANCE : 0),
            "wallet balance unchanged"
        );
        require(
            wallet.totalReleased(address(0)) == 0
                && wallet.accountReleased(address(0), address(account)) == 0
                && !wallet.assetObservationInitialized(address(0))
                && wallet.lastObservedReceived(address(0)) == 0,
            "initial accounting remains untouched"
        );
    }

    function _entries() private view returns (IStreamSplitWallet.SplitEntry[] memory entries) {
        entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(address(account), 1_000_000, LABEL);
    }

    function _walletGasConfigs()
        private
        pure
        returns (IStreamGasParameterHost.GasParameterConfig[3] memory configs)
    {
        configs[0] = IStreamGasParameterHost.GasParameterConfig(
            "ERC_1271_GAS_LIMIT", 400_000, 350_000, 2
        );
        configs[1] =
            IStreamGasParameterHost.GasParameterConfig("ASSET_POLICY_GAS_LIMIT", 30_000, 15_000, 2);
        configs[2] = IStreamGasParameterHost.GasParameterConfig(
            "WALLET_DEPOSIT_GAS_LIMIT", 50_000, 25_000, 2
        );
    }
}
