// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamRevenueEscrow.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../../interfaces/standards/IERC20.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import { StreamRevenueRuntimeBinding as RuntimeBinding } from "./StreamRevenueRuntimeBinding.sol";
import {
    StreamEscrowRecoveryGovernance as RecoveryGovernance
} from "./StreamEscrowRecoveryGovernance.sol";
import {
    StreamEscrowRecoveryManifest as RecoveryManifest
} from "./StreamEscrowRecoveryManifest.sol";
import { StreamEscrowRecoveryConsent as RecoveryConsent } from "./StreamEscrowRecoveryConsent.sol";
import {
    StreamEscrowRecoveryExecution as RecoveryExecution
} from "./StreamEscrowRecoveryExecution.sol";
import {
    StreamEscrowRecoveryTypes as R
} from "../../interfaces/stream/revenue/StreamEscrowRecoveryTypes.sol";
import "../../interfaces/stream/revenue/IStreamRevenueEscrowRecovery.sol";
import "../../interfaces/stream/revenue/IStreamRevenueEscrowRecoveryManifest.sol";
import { StreamEscrowRecoveryState as RecoveryState } from "./StreamEscrowRecoveryState.sol";
import "../../interfaces/stream/revenue/IStreamRevenueRuntimeBinding.sol";

/// @notice Captured owed revenue with explicit governed runtime admission and incident recovery.
/// @dev Recovery operates only on this escrow ledger; resident old-wallet funds remain untouched.
///      Producer authorization does not independently prove the sale assignment kind.
contract StreamRevenueEscrow is
    IStreamRevenueEscrow,
    StreamGasParameterHost,
    ReentrancyGuard,
    IStreamRevenueRuntimeBinding,
    IStreamRevenueEscrowRecovery,
    IStreamRevenueEscrowRecoveryManifest
{
    uint16 public constant SCHEMA_VERSION = 1;
    bytes32 public constant ESCROW_RECOVERY_DOMAIN = R.RECOVERY_DOMAIN;
    bytes32 public constant ESCROW_RECOVERY_CONSENT_TYPEHASH = R.CONSENT_TYPEHASH;
    bytes32 private constant _FLUSH_GAS = keccak256("6529STREAM_GGP_FLUSH_GAS_FLOOR");
    bytes32 private constant _DEPOSIT_GAS = keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT");
    bytes32 private constant _POLICY_GAS = keccak256("6529STREAM_GGP_ASSET_POLICY_GAS_LIMIT");
    bytes32 private constant _PRODUCER_SCOPE = keccak256("6529STREAM_ESCROW_PRODUCER_SCOPE_V1");
    bytes32 private constant _PRODUCER_STATE = keccak256("6529STREAM_ESCROW_PRODUCER_STATE_V1");
    uint256 private constant _CALL_RESERVE = 30_000;

    IStreamSplitFactory public immutable splitFactory;
    IStreamAssetPolicyRegistry public immutable assetPolicyRegistry;
    bytes32 public immutable factoryCodeHash;
    bytes32 public immutable walletCodeHash;
    bytes32 public immutable registryCodeHash;

    struct Producer {
        bool enabled;
        bytes32 codeHash;
        uint64 revision;
        bytes32 lastActionId;
    }

    struct Credit {
        uint256 amount;
        address factory;
        bytes32 factoryHash;
        bytes32 runtimeHash;
    }

    struct Key {
        bytes32 revenueClass;
        bytes32 profileId;
        address wallet;
        address asset;
    }

    struct Action {
        uint256 executing;
        bytes32 id;
        uint256 actionClass;
        bytes32 scope;
        bytes32 oldState;
        bytes32 newState;
    }

    mapping(address => Producer) private _producers;
    mapping(bytes32 => Credit) private _credits;
    mapping(address => uint256) public override totalOwed;

    constructor(
        IStreamSplitFactory factory_,
        address authority,
        GasParameterConfig memory flushConfig
    ) StreamGasParameterHost(authority) {
        if (
            authority == address(0) || address(factory_).code.length == 0
                || _isDelegatedCode(address(factory_))
                || factory_.governanceAuthority() != authority
        ) revert InvalidEscrowConfiguration();
        IStreamAssetPolicyRegistry registry = factory_.assetPolicyRegistry();
        if (
            address(registry).code.length == 0 || _isDelegatedCode(address(registry))
                || registry.governanceAuthority() != authority
                || !registry.isStreamAssetPolicyRegistry()
        ) revert InvalidEscrowConfiguration();
        bytes32 runtime = factory_.splitWalletRuntimeCodeHash();
        if (
            runtime == bytes32(0) || factory_.splitWalletInitCodeHash() == bytes32(0)
                || factory_.gasParameter(_DEPOSIT_GAS) == 0
                || factory_.gasParameter(_POLICY_GAS) == 0
        ) {
            revert InvalidEscrowConfiguration();
        }
        if (
            keccak256(bytes(flushConfig.name)) != keccak256("FLUSH_GAS_FLOOR")
                || flushConfig.failureClass != FAILURE_CLASS_MIN_GAS_GATE
        ) {
            revert GasParameterInvalidConfig(_FLUSH_GAS);
        }
        _registerGasParameter(flushConfig);
        splitFactory = factory_;
        assetPolicyRegistry = registry;
        factoryCodeHash = address(factory_).codehash;
        walletCodeHash = runtime;
        registryCodeHash = address(registry).codehash;
        // Recovery gas inventory is fixed at construction. Old nonadvertising factory
        // fixtures retain their original constructor behavior and cannot opt into recovery.
        if (RuntimeBinding.advertises(address(factory_))) {
            _registerRecoveryGas(factory_, "ERC_1271_GAS_LIMIT");
            _registerRecoveryGas(factory_, "WALLET_DEPOSIT_GAS_LIMIT");
            _registerRecoveryGas(factory_, "ASSET_POLICY_GAS_LIMIT");
        }
    }

    /// @notice Additive opt-in; original captured-credit storage and constructor stay unchanged.
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7
            || interfaceId == type(IStreamRevenueRuntimeBinding).interfaceId
            || interfaceId == type(IStreamRevenueEscrow).interfaceId
            || interfaceId == type(IStreamRevenueEscrowRecovery).interfaceId
            || interfaceId == type(IStreamRevenueEscrowRecoveryManifest).interfaceId;
    }

    function revenueRuntimeRegistry() external view override returns (address registry) {
        (registry,) = RuntimeBinding.current();
    }

    function revenueRuntimeRegistryCodeHash() external view override returns (bytes32 codeHash) {
        (, codeHash) = RuntimeBinding.current();
    }

    function revenueRuntimeBindingTransitionHashes(address registry)
        external
        view
        override
        returns (bytes32, bytes32, bytes32)
    {
        return RuntimeBinding.transition(
            RuntimeBinding.Context(
                address(splitFactory),
                governanceAuthority,
                address(assetPolicyRegistry),
                _recoveryInitializationHash()
            ),
            registry
        );
    }

    function initializeRevenueRuntimeRegistry(address registry) external override nonReentrant {
        _requireFactory();
        RuntimeBinding.initialize(
            RuntimeBinding.Context(
                address(splitFactory),
                governanceAuthority,
                address(assetPolicyRegistry),
                _recoveryInitializationHash()
            ),
            registry
        );
        RecoveryState.state().origin = RecoveryState.Origin(
            governanceAuthority.codehash,
            splitFactory.PROFILE_DOMAIN(),
            splitFactory.splitWalletInitCodeHash(),
            splitFactory.SCHEMA_VERSION(),
            splitFactory.WALLET_VERSION()
        );
    }

    function _recoveryInitializationHash() private view returns (bytes32) {
        _requireFactory();
        bytes32 signatureGas = keccak256("6529STREAM_GGP_ERC_1271_GAS_LIMIT");
        return keccak256(
            abi.encode(
                governanceAuthority.codehash,
                splitFactory.PROFILE_DOMAIN(),
                splitFactory.splitWalletInitCodeHash(),
                splitFactory.SCHEMA_VERSION(),
                splitFactory.WALLET_VERSION(),
                signatureGas,
                gasParameter(signatureGas),
                _gasParameters[signatureGas].floor,
                _DEPOSIT_GAS,
                gasParameter(_DEPOSIT_GAS),
                _gasParameters[_DEPOSIT_GAS].floor,
                _POLICY_GAS,
                gasParameter(_POLICY_GAS),
                _gasParameters[_POLICY_GAS].floor
            )
        );
    }

    function _registerRecoveryGas(IStreamSplitFactory factory_, string memory name) private {
        bytes32 key = keccak256(abi.encodePacked("6529STREAM_GGP_", name));
        _registerGasParameter(
            GasParameterConfig(
                name,
                factory_.gasParameter(key),
                factory_.gasParameterFloor(key),
                FAILURE_CLASS_FAIL_CLOSED_PRECHECK
            )
        );
    }

    function _recoveryContext() private view returns (RecoveryState.Context memory c) {
        (address registry, bytes32 codeHash) = RuntimeBinding.current();
        if (registry == address(0) || registry.codehash != codeHash) {
            revert InvalidRevenueRuntimeBinding();
        }
        RecoveryState.Origin storage origin = RecoveryState.state().origin;
        if (governanceAuthority.codehash != origin.authorityCodeHash) {
            revert InvalidRevenueRuntimeBinding();
        }
        c = RecoveryState.Context(
            address(splitFactory),
            governanceAuthority,
            address(assetPolicyRegistry),
            factoryCodeHash,
            walletCodeHash,
            origin.initCodeHash,
            origin.profileDomain,
            origin.schemaVersion,
            origin.walletVersion,
            registry,
            codeHash
        );
    }

    function publishEscrowRecoveryManifest(
        ManifestDocument calldata document,
        R.EscrowRecoveryManifestRef calldata manifest
    ) external override nonReentrant returns (bytes32 contentHash) {
        return RecoveryManifest.publish(_recoveryContext(), document, manifest);
    }

    function escrowRecoveryManifest(bytes32 contentHash)
        external
        view
        override
        returns (bytes memory canonicalDocument, uint64 publishedAt)
    {
        return RecoveryManifest.encoded(contentHash);
    }

    function escrowRecoveryAffectedAccountCount(bytes32 contentHash)
        external
        view
        override
        returns (uint256)
    {
        return RecoveryManifest.count(contentHash);
    }

    function escrowRecoveryAffectedAccountAt(bytes32 contentHash, uint256 index)
        external
        view
        override
        returns (address)
    {
        return RecoveryManifest.accountAt(contentHash, index);
    }

    function scheduleEscrowRecovery(
        R.EscrowCreditKey calldata creditKey,
        address successorWallet,
        bytes32 successorProfileId,
        bytes32 successorRuntimeCodeHash,
        uint256 expectedAmount,
        R.EscrowRecoveryManifestRef calldata recoveryManifest,
        uint64 executeAfter,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external override nonReentrant returns (bytes32 recoveryId) {
        return RecoveryGovernance.schedule(
            _recoveryContext(),
            R.EscrowRecoveryRecord(
                R.EscrowRecoveryStatus.SCHEDULED,
                creditKey,
                address(splitFactory),
                successorWallet,
                successorProfileId,
                successorRuntimeCodeHash,
                expectedAmount,
                recoveryManifest,
                executeAfter,
                reasonHash,
                reasonURI
            )
        );
    }

    function escrowRecoveryTransitionHashes(
        R.EscrowCreditKey calldata creditKey,
        address successorWallet,
        bytes32 successorProfileId,
        bytes32 successorRuntimeCodeHash,
        uint256 expectedAmount,
        R.EscrowRecoveryManifestRef calldata recoveryManifest,
        uint64 executeAfter,
        bytes32 reasonHash,
        string calldata reasonURI
    )
        external
        view
        override
        returns (bytes32 recoveryId, bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash)
    {
        return RecoveryGovernance.transition(
            _recoveryContext(),
            R.EscrowRecoveryRecord(
                R.EscrowRecoveryStatus.SCHEDULED,
                creditKey,
                address(splitFactory),
                successorWallet,
                successorProfileId,
                successorRuntimeCodeHash,
                expectedAmount,
                recoveryManifest,
                executeAfter,
                reasonHash,
                reasonURI
            )
        );
    }

    function cancelEscrowRecovery(bytes32 recoveryId, bytes32 reasonHash, string calldata reasonURI)
        external
        override
        nonReentrant
    {
        // Cancellation remains possible independently of live successor or registry admission.
        RecoveryGovernance.cancel(governanceAuthority, recoveryId, reasonHash, reasonURI);
    }

    function escrowRecoveryCancellationHashes(
        bytes32 recoveryId,
        bytes32 reasonHash,
        string calldata reasonURI
    )
        external
        view
        override
        returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash)
    {
        return RecoveryGovernance.cancellation(recoveryId, reasonHash, reasonURI);
    }

    function authorizeTerminalEscrowRecovery(bytes32 recoveryId) external override nonReentrant {
        RecoveryGovernance.terminal(_recoveryContext(), recoveryId);
    }

    function escrowRecoveryTerminalHashes(bytes32 recoveryId)
        external
        view
        override
        returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash)
    {
        return RecoveryGovernance.terminalHashes(recoveryId);
    }

    function executeEscrowRecovery(bytes32 recoveryId) external override nonReentrant {
        RecoveryExecution.execute(_credits, totalOwed, _recoveryContext(), recoveryId);
    }

    function escrowRecoveryRecord(bytes32 recoveryId)
        external
        view
        override
        returns (R.EscrowRecoveryRecord memory)
    {
        return RecoveryState.state().recoveries[recoveryId].record;
    }

    function submitEscrowRecoveryConsent(
        address account,
        bytes32 recoveryId,
        bytes32 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external override nonReentrant {
        RecoveryConsent.submit(account, recoveryId, nonce, deadline, signature);
    }

    function recordEscrowRecoveryConsent(bytes32 recoveryId, bytes32 nonce)
        external
        override
        nonReentrant
    {
        RecoveryConsent.record(recoveryId, nonce);
    }

    function revokeEscrowRecoveryConsent(bytes32 recoveryId) external override nonReentrant {
        RecoveryConsent.revoke(recoveryId);
    }

    function escrowRecoveryConsentRecorded(bytes32 recoveryId, address account)
        external
        view
        override
        returns (bool)
    {
        return RecoveryConsent.recorded(recoveryId, account);
    }

    function isEscrowRecoveryConsentNonceUsed(address account, bytes32 nonce)
        external
        view
        override
        returns (bool)
    {
        return RecoveryConsent.nonceUsed(account, nonce);
    }

    function escrowRecoveryDomainSeparator() external view returns (bytes32) {
        return RecoveryConsent.domainSeparator();
    }

    function escrowRecoveryConsentDigest(
        address account,
        bytes32 recoveryId,
        bytes32 nonce,
        uint64 deadline
    ) external view returns (bytes32) {
        return RecoveryConsent.digest(account, recoveryId, nonce, deadline);
    }

    function _requireRuntime(bool active) private view {
        (address registry, bytes32 codeHash) = RuntimeBinding.current();
        if (registry == address(0)) {
            (registry, codeHash) = RuntimeBinding.factoryBinding(address(splitFactory));
        }
        if (registry != address(0)) {
            RuntimeBinding.requireState(address(splitFactory), registry, codeHash, active);
        }
    }

    /// @notice Passive native receipts are surplus; only creditNative records owed funds.
    receive() external payable { }

    function gasParameterFloor(bytes32 parameterId) external view override returns (uint256) {
        gasParameter(parameterId);
        return _gasParameters[parameterId].floor;
    }

    function creditProducer(address producer)
        external
        view
        override
        returns (bool enabled, bytes32 codeHash, uint64 revision)
    {
        Producer storage item = _producers[producer];
        return (item.enabled, item.codeHash, item.revision);
    }

    function creditProducerTransitionHashes(address producer, bool enabled)
        public
        view
        override
        returns (bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash)
    {
        Producer storage item = _producers[producer];
        bytes32 nextHash = enabled ? _admissibleProducerCode(producer) : item.codeHash;
        if (
            item.revision == type(uint64).max
                || (item.enabled == enabled && item.codeHash == nextHash)
        ) {
            revert InvalidEscrowProducer(producer);
        }
        scopeHash = keccak256(abi.encode(_PRODUCER_SCOPE, block.chainid, address(this), producer));
        oldStateHash = keccak256(
            abi.encode(_PRODUCER_STATE, scopeHash, item.enabled, item.codeHash, item.revision)
        );
        newStateHash =
            keccak256(abi.encode(_PRODUCER_STATE, scopeHash, enabled, nextHash, item.revision + 1));
    }

    function setCreditProducer(address producer, bool enabled) external override nonReentrant {
        if (msg.sender != governanceAuthority) revert InvalidEscrowProducerAction();
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            creditProducerTransitionHashes(producer, enabled);
        Action memory action = _action();
        Producer storage item = _producers[producer];
        if (
            action.executing != 1 || action.id == bytes32(0) || action.actionClass != 1
                || action.scope != scope || action.oldState != oldState
                || action.newState != newState || item.lastActionId == action.id
        ) revert InvalidEscrowProducerAction();
        if (enabled) item.codeHash = _admissibleProducerCode(producer);
        item.enabled = enabled;
        ++item.revision;
        item.lastActionId = action.id;
        emit EscrowProducerUpdated(
            SCHEMA_VERSION, producer, item.codeHash, action.id, enabled, item.revision
        );
    }

    function creditNative(
        bytes32 revenueClass,
        bytes32 profileId,
        address wallet,
        bool templateOrigin
    ) external payable override nonReentrant {
        _requireProducer();
        Key memory key = Key(revenueClass, profileId, wallet, address(0));
        _requireCredit(key, msg.value, templateOrigin);
        _requireSolvent(address(0), address(this).balance - msg.value);
        _recordCredit(key, msg.value);
    }

    function creditERC20(
        bytes32 revenueClass,
        bytes32 profileId,
        address wallet,
        address asset,
        uint256 amount,
        bool templateOrigin
    ) external override nonReentrant {
        _requireProducer();
        if (asset == address(0) || asset.code.length == 0) revert InvalidEscrowCredit();
        Key memory key = Key(revenueClass, profileId, wallet, asset);
        _requireCredit(key, amount, templateOrigin);
        _requireActive(asset);
        uint256 cap = _factoryGas(_DEPOSIT_GAS);
        _moveToken(asset, msg.sender, address(this), amount, cap, true);
        // A token callback cannot bypass the current policy check or the shared guard.
        _requireActive(asset);
        _requireRuntime(true);
        _recordCredit(key, amount);
    }

    function escrowOwed(bytes32 revenueClass, bytes32 profileId, address wallet, address asset)
        external
        view
        override
        returns (uint256)
    {
        return _credits[_keyHash(Key(revenueClass, profileId, wallet, asset))].amount;
    }

    function escrowCreditIdentity(
        bytes32 revenueClass,
        bytes32 profileId,
        address wallet,
        address asset
    ) external view override returns (address factory, bytes32 factoryHash, bytes32 runtimeHash) {
        Credit storage item = _credits[_keyHash(Key(revenueClass, profileId, wallet, asset))];
        return (item.factory, item.factoryHash, item.runtimeHash);
    }

    function surplus(address asset) external view override returns (uint256) {
        uint256 balance = asset == address(0)
            ? address(this).balance
            : _tokenBalance(asset, address(this), _factoryGas(_DEPOSIT_GAS));
        return balance > totalOwed[asset] ? balance - totalOwed[asset] : 0;
    }

    function flushEscrow(bytes32 revenueClass, bytes32 profileId, address wallet, address asset)
        external
        override
        nonReentrant
    {
        uint256 required = gasParameter(_FLUSH_GAS);
        if (gasleft() < required) revert InsufficientEscrowGas(required, gasleft());
        _flush(Key(revenueClass, profileId, wallet, asset), true);
    }

    function flushToVerifiedWalletBestEffort(
        bytes32 revenueClass,
        bytes32 profileId,
        address wallet,
        address asset
    ) external override nonReentrant {
        // Deliberately independent of the possibly unaffordable undeployed-wallet floor.
        _flush(Key(revenueClass, profileId, wallet, asset), false);
    }

    function _flush(Key memory key, bool mayDeploy) private {
        _requireFactory();
        _requireRuntime(false);
        Credit storage credit = _credits[_keyHash(key)];
        uint256 amount = credit.amount;
        if (amount == 0) revert NoEscrowCredit();
        if (
            credit.factory != address(splitFactory) || credit.factoryHash != factoryCodeHash
                || credit.runtimeHash != walletCodeHash
        ) revert InvalidEscrowConfiguration();
        uint256 cap = _factoryGas(_DEPOSIT_GAS);
        uint256 balance = key.asset == address(0)
            ? address(this).balance
            : _tokenBalance(key.asset, address(this), cap);
        _requireSolvent(key.asset, balance);
        credit.amount = 0;
        totalOwed[key.asset] -= amount;
        if (key.wallet.code.length == 0) {
            if (!mayDeploy) revert EscrowFixedWalletUndeployed(key.profileId, key.wallet);
            // Reserve several deposit/read calls and accounting work while forwarding the
            // remaining budget to trusted deployment code. This is not a fixed deployment cap.
            uint256 available = gasleft();
            if (available <= 100_000 || cap > (available - 100_000) / 6) {
                revert InsufficientEscrowCallGas(cap, available, 100_000);
            }
            uint256 reserve = cap * 6 + 100_000;
            bytes memory data = abi.encodeCall(IStreamSplitFactory.deployWallet, (key.profileId));
            uint256 deployGas = gasleft() - reserve;
            deployGas -= deployGas / 64;
            uint256 result = _callWord(address(splitFactory), data, 0, deployGas);
            if (result != uint256(uint160(key.wallet))) {
                revert EscrowWalletMismatch(key.profileId, key.wallet);
            }
        }
        _verifyWallet(key.profileId, key.wallet, false);
        if (key.asset == address(0)) {
            uint256 walletBefore = key.wallet.balance;
            _nativeDeposit(key.wallet, amount, cap);
            if (
                key.wallet.balance != walletBefore + amount
                    || address(this).balance != balance - amount
            ) {
                revert EscrowTransferInvariantBroken(address(0));
            }
        } else {
            // Retained credits do not reapply ACTIVE admission: deprecation cannot erase owed funds.
            _moveToken(key.asset, address(this), key.wallet, amount, cap, false);
        }
        _requireRuntime(false);
        emit EscrowFlushed(
            key.revenueClass, key.profileId, key.wallet, SCHEMA_VERSION, key.asset, amount, 0
        );
    }

    function _requireCredit(Key memory key, uint256 amount, bool templateOrigin) private view {
        if (key.revenueClass == bytes32(0) || amount == 0 || key.wallet == address(0)) {
            revert InvalidEscrowCredit();
        }
        _requireFactory();
        _requireRuntime(true);
        _verifyWallet(key.profileId, key.wallet, templateOrigin);
    }

    function _verifyWallet(bytes32 profileId, address wallet, bool mayBeUndeployed) private view {
        if (!splitFactory.profileExists(profileId)) revert EscrowUnknownProfile(profileId);
        if (wallet != splitFactory.walletFor(profileId)) {
            revert EscrowWalletMismatch(profileId, wallet);
        }
        if (wallet.code.length == 0) {
            if (!mayBeUndeployed) revert EscrowFixedWalletUndeployed(profileId, wallet);
        } else {
            if (wallet.codehash != walletCodeHash) {
                revert WrongCodeAtWallet(wallet, walletCodeHash, wallet.codehash);
            }
            if (
                !splitFactory.splitWalletExists(profileId)
                    || IStreamSplitWallet(wallet).factory() != address(splitFactory)
                    || IStreamSplitWallet(wallet).profileId() != profileId
            ) {
                revert EscrowWalletMismatch(profileId, wallet);
            }
        }
    }

    function _recordCredit(Key memory key, uint256 amount) private {
        Credit storage item = _credits[_keyHash(key)];
        if (item.factory == address(0)) {
            item.factory = address(splitFactory);
            item.factoryHash = factoryCodeHash;
            item.runtimeHash = walletCodeHash;
        }
        item.amount += amount;
        totalOwed[key.asset] += amount;
        emit EscrowCreditCreated(
            key.revenueClass,
            key.profileId,
            key.wallet,
            SCHEMA_VERSION,
            key.asset,
            amount,
            item.amount,
            walletCodeHash
        );
    }

    function _requireSolvent(address asset, uint256 balance) private view {
        if (balance < totalOwed[asset]) revert EscrowInsolvent(asset, balance, totalOwed[asset]);
    }

    function _requireFactory() private view {
        if (address(splitFactory).codehash != factoryCodeHash) {
            revert EscrowFactoryCodeChanged(address(splitFactory));
        }
    }

    function _requireProducer() private view {
        Producer storage item = _producers[msg.sender];
        if (!item.enabled || _admissibleProducerCode(msg.sender) != item.codeHash) {
            revert InvalidEscrowProducer(msg.sender);
        }
    }

    function _admissibleProducerCode(address producer) private view returns (bytes32) {
        if (producer.code.length == 0 || _isDelegatedCode(producer)) {
            revert InvalidEscrowProducer(producer);
        }
        return producer.codehash;
    }

    function _isDelegatedCode(address target) private view returns (bool) {
        if (target.code.length == 23) {
            uint256 prefix;
            assembly ("memory-safe") {
                let ptr := mload(0x40)
                extcodecopy(target, ptr, 0, 3)
                prefix := shr(232, mload(ptr))
            }
            return prefix == 0xef0100;
        }
        return false;
    }

    function _keyHash(Key memory key) private pure returns (bytes32) {
        return keccak256(abi.encode(key.revenueClass, key.profileId, key.wallet, key.asset));
    }

    function _requireActive(address asset) private view {
        address registry = address(assetPolicyRegistry);
        if (registry.codehash != registryCodeHash) {
            revert EscrowReadFailed(registry, IStreamAssetPolicyRegistry.assetStatus.selector);
        }
        uint256 status = _readWord(
            registry,
            abi.encodeCall(IStreamAssetPolicyRegistry.assetStatus, (asset)),
            _factoryGas(_POLICY_GAS)
        );
        if (status != 1) revert EscrowAssetNotActive(asset, status);
    }

    function _factoryGas(bytes32 parameterId) private view returns (uint256 value) {
        _requireFactory();
        address target = address(splitFactory);
        bytes memory data = abi.encodeCall(IStreamGasParameterHost.gasParameter, (parameterId));
        bool ok;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            ok := staticcall(gas(), target, add(data, 32), mload(data), ptr, 32)
            ok := and(ok, eq(returndatasize(), 32))
            value := mload(ptr)
        }
        if (!ok || value == 0) {
            revert EscrowReadFailed(target, IStreamGasParameterHost.gasParameter.selector);
        }
    }

    function _requireCallGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + _CALL_RESERVE)
        {
            revert InsufficientEscrowCallGas(cap, available, _CALL_RESERVE);
        }
    }

    function _readWord(address target, bytes memory data, uint256 cap)
        private
        view
        returns (uint256 value)
    {
        _requireCallGas(cap);
        bool ok;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            ok := staticcall(cap, target, add(data, 32), mload(data), ptr, 32)
            ok := and(ok, eq(returndatasize(), 32))
            value := mload(ptr)
        }
        // Casting to bytes4 extracts the selector from internally ABI-encoded calldata.
        // forge-lint: disable-next-line(unsafe-typecast)
        if (!ok) revert EscrowReadFailed(target, bytes4(data));
    }

    function _callWord(address target, bytes memory data, uint256 value, uint256 cap)
        private
        returns (uint256 word)
    {
        _requireCallGas(cap);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            ok := call(cap, target, value, add(data, 32), mload(data), ptr, 32)
            size := returndatasize()
            word := mload(ptr)
        }
        // Casting to bytes4 extracts the selector from internally ABI-encoded calldata.
        // forge-lint: disable-next-line(unsafe-typecast)
        if (!ok || size != 32) _failedCall(target, bytes4(data), size);
    }

    function _nativeDeposit(address wallet, uint256 amount, uint256 cap) private {
        _requireCallGas(cap);
        // CALL adds the value-transfer stipend. Keep the total callee budget at the GGP value.
        if (cap < 2300) revert InsufficientEscrowCallGas(cap, gasleft(), 2300);
        uint256 forwarded = cap - 2300;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(forwarded, wallet, amount, 0, 0, 0, 0)
            size := returndatasize()
        }
        if (!ok) _failedCall(wallet, bytes4(0), size);
    }

    function _failedCall(address target, bytes4 selector, uint256 size) private pure {
        uint256 length = size > 256 ? 256 : size;
        bytes memory prefix = new bytes(length);
        assembly ("memory-safe") { returndatacopy(add(prefix, 32), 0, length) }
        revert EscrowExternalCallFailed(target, selector, size, prefix);
    }

    function _tokenBalance(address asset, address account, uint256 cap)
        private
        view
        returns (uint256)
    {
        return _readWord(asset, abi.encodeCall(IERC20.balanceOf, (account)), cap);
    }

    function _moveToken(
        address asset,
        address from,
        address to,
        uint256 amount,
        uint256 cap,
        bool pull
    ) private {
        uint256 fromBefore = _tokenBalance(asset, from, cap);
        uint256 toBefore = _tokenBalance(asset, to, cap);
        if (pull) _requireSolvent(asset, toBefore);
        if (fromBefore < amount) revert EscrowTransferInvariantBroken(asset);
        bytes memory data = pull
            ? abi.encodeCall(IERC20.transferFrom, (from, to, amount))
            : abi.encodeCall(IERC20.transfer, (to, amount));
        if (_callWord(asset, data, 0, cap) != 1) revert EscrowTransferInvariantBroken(asset);
        if (
            _tokenBalance(asset, from, cap) != fromBefore - amount
                || _tokenBalance(asset, to, cap) != toBefore + amount
        ) {
            revert EscrowTransferInvariantBroken(asset);
        }
    }

    function _action() private view returns (Action memory action) {
        address authority = governanceAuthority;
        uint256 selector = uint32(IStreamGovernedParameterAuthority.currentAction.selector);
        bool ok;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, shl(224, selector))
            ok := staticcall(gas(), authority, ptr, 4, action, 192)
            ok := and(ok, eq(returndatasize(), 192))
        }
        if (!ok) revert InvalidEscrowProducerAction();
    }
}
