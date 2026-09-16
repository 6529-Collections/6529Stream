// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamRevenueRuntimeRegistry.sol";
import "../../interfaces/stream/revenue/IStreamRevenueRuntimeBinding.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";

/// @notice Fixed binding/admission worker; each host retains its own once-only pointer.
/// @dev Old unbound factories preserve their initial admission. Deployment activation must
///      separately require opt-in; a selected/advertised malformed registry never falls back.
library StreamRevenueRuntimeBinding {
    bytes32 private constant SLOT = keccak256("6529STREAM_REVENUE_RUNTIME_BINDING_STORAGE_V1");
    bytes32 private constant DOMAIN = keccak256("6529STREAM_REVENUE_RUNTIME_BINDING_V1");
    bytes32 private constant READ_GAS = keccak256("6529STREAM_GGP_REVENUE_RUNTIME_READ_GAS");
    bytes4 private constant ERC165 = 0x01ffc9a7;

    struct State {
        address registry;
        bytes32 codeHash;
    }

    struct Context {
        address factory;
        address authority;
        address assetRegistry;
        bytes32 initializationHash;
    }

    struct Action {
        uint256 executing;
        bytes32 id;
        uint256 actionClass;
        bytes32 scope;
        bytes32 oldState;
        bytes32 newState;
    }

    event RevenueRuntimeRegistryBound(
        uint16 schemaVersion,
        address indexed registry,
        bytes32 indexed actionId,
        bytes32 registryCodeHash,
        address indexed factory
    );

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function current() public view returns (address registry, bytes32 codeHash) {
        State storage s = state();
        return (s.registry, s.codeHash);
    }

    function transition(Context memory c, address registry)
        public
        view
        returns (bytes32 scope, bytes32 oldValue, bytes32 newValue)
    {
        if (state().registry != address(0)) {
            revert IStreamRevenueRuntimeBinding.RevenueRuntimeAlreadyBound();
        }
        _candidate(c, registry);
        scope = keccak256(abi.encode(DOMAIN, block.chainid, address(this), c));
        oldValue = keccak256(abi.encode(scope, address(0), bytes32(0)));
        newValue = keccak256(abi.encode(scope, registry, registry.codehash));
    }

    function initialize(Context memory c, address registry) public {
        if (msg.sender != c.authority) {
            revert IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding();
        }
        (bytes32 scope, bytes32 oldValue, bytes32 newValue) = transition(c, registry);
        bytes memory output = _read(
            c.authority,
            abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ()),
            192,
            _budget(registry)
        );
        Action memory a = abi.decode(output, (Action));
        if (
            a.executing != 1 || a.id == 0 || a.actionClass != 1 || a.scope != scope
                || a.oldState != oldValue || a.newState != newValue
        ) revert IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding();
        State storage s = state();
        s.registry = registry;
        s.codeHash = registry.codehash;
        emit RevenueRuntimeRegistryBound(1, registry, a.id, s.codeHash, c.factory);
    }

    /// @notice Mutation admission only; stored policy hashes/disclosures do not call this.
    function requireActive(address factory) public view {
        (address registry, bytes32 codeHash) = factoryBinding(factory);
        if (registry == address(0)) return;
        requireState(factory, registry, codeHash, true);
    }

    function requireState(address factory, address registry, bytes32 codeHash, bool active)
        public
        view
    {
        if (registry.codehash != codeHash || codeHash == 0) {
            revert IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding();
        }
        uint256 cap = _budget(registry);
        IStreamRevenueRuntimeRegistry.FactoryRecord memory f = abi.decode(
            _read(
                registry,
                abi.encodeCall(IStreamRevenueRuntimeRegistry.factoryRecord, (factory)),
                192,
                cap
            ),
            (IStreamRevenueRuntimeRegistry.FactoryRecord)
        );
        IStreamRevenueRuntimeRegistry.RuntimeRecord memory r = abi.decode(
            _read(
                registry,
                abi.encodeCall(IStreamRevenueRuntimeRegistry.runtimeRecord, (f.runtimeCodeHash)),
                128,
                cap
            ),
            (IStreamRevenueRuntimeRegistry.RuntimeRecord)
        );
        if (
            f.codeHash != factory.codehash || f.codeHash == 0 || f.revision == 0 || r.revision == 0
                || f.runtimeCodeHash == 0
                || (active
                        ? f.status != 1 || r.status != 1
                        : (f.status != 1 && f.status != 2) || (r.status != 1 && r.status != 2))
        ) {
            revert IStreamRevenueRuntimeRegistry.RevenueRuntimeUnavailable(
                factory, f.runtimeCodeHash, r.status
            );
        }
    }

    /// @notice Optional old-factory capability probe; successful malformed replies fail closed.
    function advertises(address factory) public view returns (bool) {
        bytes memory query =
            abi.encodeWithSelector(ERC165, type(IStreamRevenueRuntimeBinding).interfaceId);
        uint256 advertised;
        uint256 size;
        bool ok;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            ok := staticcall(30000, factory, add(query, 32), mload(query), ptr, 32)
            size := returndatasize()
            advertised := mload(ptr)
        }
        // Original factories without this selector may revert or return no bytes.
        if (!ok || size == 0) return false;
        if (size != 32 || advertised > 1) {
            revert IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding();
        }
        return advertised == 1;
    }

    function factoryBinding(address factory)
        public
        view
        returns (address registry, bytes32 codeHash)
    {
        if (!advertises(factory)) return (address(0), 0);
        uint256 raw = _word(
            factory, abi.encodeCall(IStreamRevenueRuntimeBinding.revenueRuntimeRegistry, ()), 30000
        );
        if (raw > type(uint160).max) {
            revert IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding();
        }
        registry = address(uint160(raw));
        codeHash = bytes32(
            _word(
                factory,
                abi.encodeCall(IStreamRevenueRuntimeBinding.revenueRuntimeRegistryCodeHash, ()),
                30000
            )
        );
        if ((registry == address(0)) != (codeHash == 0)) {
            revert IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding();
        }
        if (registry != address(0) && registry.codehash != codeHash) {
            revert IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding();
        }
    }

    function _candidate(Context memory c, address registry) private view {
        if (
            registry.code.length == 0 || c.factory.code.length == 0 || _delegated(registry)
                || _delegated(c.factory) || _delegated(c.authority)
        ) {
            revert IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding();
        }
        uint256 cap = _budget(registry);
        if (
            _word(
                        registry,
                        abi.encodeCall(
                            IStreamRevenueRuntimeRegistry.isStreamRevenueRuntimeRegistry, ()
                        ),
                        cap
                    ) != 1
                || _word(
                        registry,
                        abi.encodeCall(IStreamGasParameterHost.governanceAuthority, ()),
                        cap
                    ) != uint256(uint160(c.authority))
                || bytes32(
                        _word(
                            registry,
                            abi.encodeCall(IStreamRevenueRuntimeRegistry.authorityCodeHash, ()),
                            cap
                        )
                    ) != c.authority.codehash
                || _word(
                        registry,
                        abi.encodeCall(IStreamRevenueRuntimeRegistry.assetPolicyRegistry, ()),
                        cap
                    ) != uint256(uint160(c.assetRegistry))
        ) revert IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding();
        requireState(c.factory, registry, registry.codehash, true);
        if (address(this) != c.factory) {
            (address selected, bytes32 codeHash) = factoryBinding(c.factory);
            if (selected != registry || codeHash != registry.codehash) {
                revert IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding();
            }
        }
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

    function _budget(address registry) private view returns (uint256 cap) {
        cap = _word(
            registry, abi.encodeCall(IStreamGasParameterHost.gasParameter, (READ_GAS)), 30000
        );
        if (cap == 0) revert IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding();
    }

    function _word(address target, bytes memory data, uint256 cap) private view returns (uint256) {
        return abi.decode(_read(target, data, 32, cap), (uint256));
    }

    function _read(address target, bytes memory data, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory output)
    {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + 1 + 15000) {
            revert IStreamRevenueRuntimeBinding.InvalidRevenueRuntimeBinding();
        }
        output = new bytes(length);
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(output, 32), length)
            ok := and(ok, eq(returndatasize(), length))
        }
        if (!ok) {
            revert IStreamRevenueRuntimeRegistry.RevenueRuntimeReadFailed(target, bytes4(data));
        }
    }
}
