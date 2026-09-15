// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamRevenueRuntimeRegistry.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";

/// @notice Governed common factory/runtime lifecycle; it never holds or transfers revenue.
/// @dev ACTIVE=1, DEPRECATED=2, INCIDENT_REVOKED=3. A first approved factory also
///      explicitly approves its previously unknown runtime in the same committed action.
contract StreamRevenueRuntimeRegistry is
    IStreamRevenueRuntimeRegistry,
    StreamGasParameterHost,
    ReentrancyGuard
{
    bytes32 private constant READ_GAS = keccak256("6529STREAM_GGP_REVENUE_RUNTIME_READ_GAS");
    bytes32 private constant FACTORY_SCOPE = keccak256("6529STREAM_REVENUE_FACTORY_LIFECYCLE_V1");
    bytes32 private constant RUNTIME_SCOPE = keccak256("6529STREAM_REVENUE_RUNTIME_LIFECYCLE_V1");
    address public immutable override assetPolicyRegistry;
    bytes32 public immutable override authorityCodeHash;
    bytes32 public immutable assetPolicyCodeHash;
    mapping(address => FactoryRecord) private _factories;
    mapping(bytes32 => RuntimeRecord) private _runtimes;

    struct Action {
        uint256 executing;
        bytes32 id;
        uint256 actionClass;
        bytes32 scope;
        bytes32 oldState;
        bytes32 newState;
    }

    constructor(address authority, address assetRegistry, GasParameterConfig memory readConfig)
        StreamGasParameterHost(authority)
    {
        if (
            authority.code.length == 0 || assetRegistry.code.length == 0 || _delegated(authority)
                || _delegated(assetRegistry)
                || IStreamAssetPolicyRegistry(assetRegistry).governanceAuthority() != authority
                || !IStreamAssetPolicyRegistry(assetRegistry).isStreamAssetPolicyRegistry()
                || keccak256(bytes(readConfig.name)) != keccak256("REVENUE_RUNTIME_READ_GAS")
                || readConfig.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
        ) revert InvalidRevenueRuntimeConfiguration();
        assetPolicyRegistry = assetRegistry;
        authorityCodeHash = authority.codehash;
        assetPolicyCodeHash = assetRegistry.codehash;
        _registerGasParameter(readConfig);
    }

    function gasParameterFloor(bytes32 parameterId) external view returns (uint256) {
        gasParameter(parameterId);
        return _gasParameters[parameterId].floor;
    }

    function isStreamRevenueRuntimeRegistry() external pure override returns (bool) {
        return true;
    }

    function factoryRecord(address factory) external view override returns (FactoryRecord memory) {
        return _factories[factory];
    }

    function runtimeRecord(bytes32 codeHash) external view override returns (RuntimeRecord memory) {
        return _runtimes[codeHash];
    }

    function factoryTransitionHashes(
        address factory,
        uint8 status,
        bytes32 reasonHash,
        string calldata reasonURI,
        bytes32 incidentManifestHash
    )
        public
        view
        override
        returns (uint8 actionClass, bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash)
    {
        _reason(status, reasonHash, reasonURI, incidentManifestHash);
        FactoryRecord memory prior = _factories[factory];
        (bytes32 codeHash, bytes32 runtime) = _nextFactory(factory, status, prior);
        RuntimeRecord memory runtimeState = _runtimes[runtime];
        actionClass = prior.revision == 0 || status < prior.status ? 1 : 0;
        scopeHash = keccak256(abi.encode(FACTORY_SCOPE, block.chainid, address(this), factory));
        oldStateHash = keccak256(abi.encode(scopeHash, prior, runtimeState));
        newStateHash = keccak256(
            abi.encode(
                scopeHash,
                codeHash,
                runtime,
                status,
                prior.revision + 1,
                runtimeState,
                reasonHash,
                keccak256(bytes(reasonURI)),
                incidentManifestHash
            )
        );
    }

    function runtimeTransitionHashes(
        bytes32 runtime,
        uint8 status,
        bytes32 reasonHash,
        string calldata reasonURI,
        bytes32 incidentManifestHash
    )
        public
        view
        override
        returns (uint8 actionClass, bytes32 scopeHash, bytes32 oldStateHash, bytes32 newStateHash)
    {
        _reason(status, reasonHash, reasonURI, incidentManifestHash);
        RuntimeRecord memory prior = _runtimes[runtime];
        if (prior.revision == 0 || prior.revision == type(uint64).max || status == prior.status) {
            revert InvalidRevenueRuntimeTransition();
        }
        actionClass = prior.revision == 0 || status < prior.status ? 1 : 0;
        scopeHash = keccak256(abi.encode(RUNTIME_SCOPE, block.chainid, address(this), runtime));
        oldStateHash = keccak256(abi.encode(scopeHash, prior));
        newStateHash = keccak256(
            abi.encode(
                scopeHash,
                status,
                prior.revision + 1,
                reasonHash,
                keccak256(bytes(reasonURI)),
                incidentManifestHash
            )
        );
    }

    function setFactoryStatus(
        address factory,
        uint8 status,
        bytes32 reasonHash,
        string calldata reasonURI,
        bytes32 incidentManifestHash
    ) external override nonReentrant {
        (uint8 cls, bytes32 scope, bytes32 oldState, bytes32 newState) =
            factoryTransitionHashes(factory, status, reasonHash, reasonURI, incidentManifestHash);
        FactoryRecord storage item = _factories[factory];
        Action memory action = _requireAction(cls, scope, oldState, newState, item.lastActionId);
        (bytes32 codeHash, bytes32 runtime) = _nextFactory(factory, status, item);
        RuntimeRecord storage runtimeState = _runtimes[runtime];
        if (runtimeState.revision == 0) {
            runtimeState.status = 1;
            runtimeState.revision = 1;
            runtimeState.lastActionId = action.id;
            emit RevenueRuntimeStatusChanged(1, runtime, action.id, 1, 1, reasonHash, reasonURI, 0);
        }
        item.status = status;
        item.codeHash = codeHash;
        item.runtimeCodeHash = runtime;
        item.incidentManifestHash = incidentManifestHash;
        ++item.revision;
        item.lastActionId = action.id;
        emit RevenueFactoryStatusChanged(
            1,
            factory,
            runtime,
            action.id,
            codeHash,
            status,
            item.revision,
            reasonHash,
            reasonURI,
            incidentManifestHash
        );
    }

    function setRuntimeStatus(
        bytes32 runtime,
        uint8 status,
        bytes32 reasonHash,
        string calldata reasonURI,
        bytes32 incidentManifestHash
    ) external override nonReentrant {
        (uint8 cls, bytes32 scope, bytes32 oldState, bytes32 newState) =
            runtimeTransitionHashes(runtime, status, reasonHash, reasonURI, incidentManifestHash);
        RuntimeRecord storage item = _runtimes[runtime];
        Action memory action = _requireAction(cls, scope, oldState, newState, item.lastActionId);
        item.status = status;
        ++item.revision;
        item.incidentManifestHash = incidentManifestHash;
        item.lastActionId = action.id;
        emit RevenueRuntimeStatusChanged(
            1,
            runtime,
            action.id,
            status,
            item.revision,
            reasonHash,
            reasonURI,
            incidentManifestHash
        );
    }

    function _nextFactory(address factory, uint8 status, FactoryRecord memory prior)
        private
        view
        returns (bytes32 codeHash, bytes32 runtime)
    {
        if (
            factory == address(0) || prior.revision == type(uint64).max || prior.status == status
                || (prior.revision == 0 && status != 1)
        ) revert InvalidRevenueRuntimeTransition();
        if (status != 1) return (prior.codeHash, prior.runtimeCodeHash);
        codeHash = factory.codehash;
        if (
            factory.code.length == 0 || _delegated(factory)
                || (prior.revision != 0 && prior.codeHash != codeHash)
                || assetPolicyRegistry.codehash != assetPolicyCodeHash
        ) revert InvalidRevenueRuntimeConfiguration();
        if (
            _word(factory, abi.encodeCall(IStreamGasParameterHost.governanceAuthority, ()))
                    != uint256(uint160(governanceAuthority))
                || _word(factory, abi.encodeCall(IStreamSplitFactory.assetPolicyRegistry, ()))
                    != uint256(uint160(assetPolicyRegistry))
        ) revert InvalidRevenueRuntimeConfiguration();
        runtime = bytes32(
            _word(factory, abi.encodeCall(IStreamSplitFactory.splitWalletRuntimeCodeHash, ()))
        );
        if (
            runtime == 0
                || _word(factory, abi.encodeCall(IStreamSplitFactory.splitWalletInitCodeHash, ()))
                    == 0 || (prior.revision != 0 && prior.runtimeCodeHash != runtime)
                || (_runtimes[runtime].revision != 0 && _runtimes[runtime].status != 1)
        ) revert InvalidRevenueRuntimeConfiguration();
    }

    function _reason(uint8 status, bytes32 reasonHash, string calldata uri, bytes32 manifest)
        private
        pure
    {
        if (
            status < 1 || status > 3 || reasonHash == 0 || bytes(uri).length == 0
                || bytes(uri).length > 2048 || (status == 3 && manifest == 0)
        ) revert InvalidRevenueRuntimeTransition();
    }

    function _requireAction(
        uint8 cls,
        bytes32 scope,
        bytes32 oldState,
        bytes32 newState,
        bytes32 last
    ) private view returns (Action memory action) {
        if (msg.sender != governanceAuthority || governanceAuthority.codehash != authorityCodeHash)
        {
            revert InvalidRevenueRuntimeAction();
        }
        address target = governanceAuthority;
        bytes memory data = abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ());
        bool ok;
        uint256 cap = gasParameter(READ_GAS);
        _gas(cap);
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), action, 192)
            ok := and(ok, eq(returndatasize(), 192))
        }
        if (
            !ok || action.executing != 1 || action.id == 0 || action.id == last
                || action.actionClass != cls || action.scope != scope || action.oldState != oldState
                || action.newState != newState
        ) revert InvalidRevenueRuntimeAction();
    }

    function _word(address target, bytes memory data) private view returns (uint256 result) {
        uint256 cap = gasParameter(READ_GAS);
        _gas(cap);
        bool ok;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            ok := staticcall(cap, target, add(data, 32), mload(data), ptr, 32)
            ok := and(ok, eq(returndatasize(), 32))
            result := mload(ptr)
        }
        if (!ok) revert RevenueRuntimeReadFailed(target, bytes4(data));
    }

    function _delegated(address target) private view returns (bool) {
        if (target.code.length != 23) return false;
        uint256 prefix;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            extcodecopy(target, ptr, 0, 3)
            prefix := shr(232, mload(ptr))
        }
        return prefix == 0xef0100;
    }

    function _gas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + 1 + 15_000) {
            revert InvalidRevenueRuntimeConfiguration();
        }
    }
}
