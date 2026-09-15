// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamNativeSurplus as S } from "../../interfaces/stream/mint/IStreamNativeSurplus.sol";
import {
    IStreamGovernedParameterAuthority
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";
import { IStreamRoleRegistry } from "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import { StreamSettlementAdmission } from "../revenue/StreamSettlementAdmission.sol";

/// @notice Fixed delegatecall worker. Context comes exclusively from host deployment immutables.
library StreamNativeSurplus {
    bytes32 private constant _STORAGE = keccak256("6529STREAM_NATIVE_SURPLUS_STORAGE_V1");
    bytes32 private constant _SCOPE = keccak256("6529STREAM_NATIVE_SURPLUS_SCOPE_V1");
    bytes32 private constant _STATE = keccak256("6529STREAM_NATIVE_SURPLUS_STATE_V1");
    bytes32 private constant _REQUEST = keccak256("6529STREAM_NATIVE_SURPLUS_REQUEST_V1");
    bytes32 private constant _ROLE = keccak256("ROLE_EMERGENCY_RECIPIENT");

    struct Context {
        address core;
        bytes32 coreCodeHash;
        address registry;
        bytes32 registryCodeHash;
        address authority;
    }

    struct State {
        uint64 revision;
        uint256 cumulativeSwept;
        bytes32 lastActionId;
        mapping(bytes32 => bool) used;
    }
    event AdapterSurplusSwept(
        uint16 schemaVersion, address indexed to, address asset, uint256 amount, bytes32 actionId
    );
    event NativeSurplusSweepRecorded(
        uint16 schemaVersion,
        address indexed adapter,
        address indexed actor,
        bytes32 indexed actionId,
        address recipient,
        bytes32 domain,
        bytes32 reasonHash,
        uint256 amount,
        uint256 resultingSurplus,
        uint64 revision,
        uint256 cumulativeSwept
    );

    function _state() private pure returns (State storage s) {
        bytes32 slot = _STORAGE;
        assembly ("memory-safe") { s.slot := slot }
    }

    function read(bool privateRegistry, uint256 owed, bytes calldata data)
        public
        view
        returns (bytes memory)
    {
        bytes4 selector = bytes4(data[:4]);
        if (selector == S.nativeSurplusState.selector) return abi.encode(_snapshot(owed));
        if (selector == S.nativeSurplusActionUsed.selector) {
            return abi.encode(_state().used[abi.decode(data[4:], (bytes32))]);
        }
        if (selector != S.nativeSurplusQuote.selector) revert S.NativeSurplusRequestInvalid();
        (uint256 amount, bytes32 reason) = abi.decode(data[4:], (uint256, bytes32));
        return abi.encode(_quote(_context(privateRegistry), owed, amount, reason));
    }

    /// @dev Exact self-reads target the actual host's original immutable public getters.
    /// Neither the caller nor the new entrypoint supplies a graph address or hash.
    function _context(bool privateRegistry) private view returns (Context memory x) {
        x.core = _selfAddress(bytes4(keccak256("core()")));
        x.coreCodeHash = bytes32(_word(address(this), abi.encodeWithSignature("coreCodeHash()")));
        x.registry = _selfAddress(bytes4(keccak256("moduleRegistry()")));
        x.registryCodeHash = bytes32(
            _word(
                address(this),
                abi.encodeWithSelector(
                    privateRegistry
                        ? bytes4(keccak256("registryCodeHash()"))
                        : bytes4(keccak256("moduleRegistryCodeHash()"))
                )
            )
        );
        x.authority = _selfAddress(bytes4(keccak256("governanceAuthority()")));
    }

    function _selfAddress(bytes4 selector) private view returns (address) {
        uint256 word = _word(address(this), abi.encodeWithSelector(selector));
        if (word == 0 || word > type(uint160).max) {
            revert S.NativeSurplusAuthorityInvalid(address(this));
        }
        return address(uint160(word));
    }

    function sweep(bool privateRegistry, uint256 owed, uint256 amount, bytes32 reason)
        public
        returns (uint256)
    {
        Context memory x = _context(privateRegistry);
        if (msg.sender != x.authority || x.authority == address(0)) {
            revert S.NativeSurplusAuthorityInvalid(msg.sender);
        }
        S.NativeSurplusQuote memory q = _quote(x, owed, amount, reason);
        bytes32 actionId = _action(q);
        State storage s = _state();
        if (s.used[actionId]) revert S.NativeSurplusActionUsed(actionId);
        s.used[actionId] = true;
        s.revision = q.state.revision + 1;
        s.cumulativeSwept = q.state.cumulativeSwept + amount;
        s.lastActionId = actionId;

        address recipient = q.authority.recipient;
        bool ok;
        // No returndata allocation. The exact governance-resolved recipient controls its callback.
        assembly ("memory-safe") { ok := call(gas(), recipient, amount, 0, 0, 0, 0) }
        if (!ok) revert S.NativeSurplusTransferFailed();
        if (address(this).balance < q.state.balance - amount || address(this).balance < owed) {
            revert S.AdapterSurplusUnderfunded(address(0));
        }
        if (
            keccak256(abi.encode(_authority(x))) != keccak256(abi.encode(q.authority))
                || _action(q) != actionId || s.revision != q.state.revision + 1
                || s.cumulativeSwept != q.state.cumulativeSwept + amount
                || s.lastActionId != actionId || !s.used[actionId]
        ) revert S.NativeSurplusCallbackChanged();
        emit AdapterSurplusSwept(1, recipient, address(0), amount, actionId);
        emit NativeSurplusSweepRecorded(
            1,
            address(this),
            msg.sender,
            actionId,
            recipient,
            _SCOPE,
            reason,
            amount,
            address(this).balance - owed,
            s.revision,
            s.cumulativeSwept
        );
        return amount;
    }

    function _snapshot(uint256 owed) private view returns (S.NativeSurplusState memory r) {
        State storage s = _state();
        r = S.NativeSurplusState(
            address(this).balance,
            owed,
            address(this).balance >= owed ? address(this).balance - owed : 0,
            s.revision,
            s.cumulativeSwept,
            s.lastActionId
        );
    }

    function _quote(Context memory x, uint256 owed, uint256 amount, bytes32 reason)
        private
        view
        returns (S.NativeSurplusQuote memory q)
    {
        if (amount == 0 || reason == bytes32(0)) revert S.NativeSurplusRequestInvalid();
        q.state = _snapshot(owed);
        if (q.state.balance < owed || amount > q.state.available) {
            revert S.AdapterSurplusUnderfunded(address(0));
        }
        if (q.state.revision == type(uint64).max) revert S.NativeSurplusRequestInvalid();
        q.authority = _authority(x);
        q.amount = amount;
        q.reasonHash = reason;
        q.scopeHash = keccak256(abi.encode(_SCOPE, block.chainid, address(this), x));
        bytes32 request = keccak256(abi.encode(_REQUEST, amount, reason, q.authority));
        q.oldValueHash = keccak256(
            abi.encode(
                _STATE, q.scopeHash, request, owed, q.state.revision, q.state.cumulativeSwept
            )
        );
        q.newValueHash = keccak256(
            abi.encode(
                _STATE,
                q.scopeHash,
                request,
                owed,
                q.state.revision + 1,
                q.state.cumulativeSwept + amount
            )
        );
    }

    function _authority(Context memory x) private view returns (S.NativeSurplusAuthority memory a) {
        StreamSettlementAdmission.requireRegistry(
            x.core, x.coreCodeHash, x.registry, x.registryCodeHash
        );
        if (
            !StreamSettlementAdmission.isContract(x.authority)
                || _word(x.registry, abi.encodeWithSignature("governanceExecutor()"))
                    != uint256(uint160(x.authority))
                || _word(
                        x.authority,
                        abi.encodeCall(
                            IStreamGovernedParameterAuthority.isStreamGovernedParameterAuthority, ()
                        )
                    ) != 1
        ) revert S.NativeSurplusAuthorityInvalid(x.authority);
        uint256 roles = _word(x.authority, abi.encodeWithSignature("roleRegistry()"));
        if (roles == 0 || roles > type(uint160).max) {
            revert S.NativeSurplusAuthorityInvalid(x.authority);
        }
        a.executor = x.authority;
        a.executorCodeHash = x.authority.codehash;
        a.roleRegistry = address(uint160(roles));
        a.roleRegistryCodeHash = a.roleRegistry.codehash;
        if (
            !StreamSettlementAdmission.isContract(a.roleRegistry)
                || _word(a.roleRegistry, abi.encodeWithSignature("owner()"))
                    != uint256(uint160(x.authority))
                || _word(
                        a.roleRegistry,
                        abi.encodeCall(
                            IStreamRoleRegistry.supportsInterface,
                            (type(IStreamRoleRegistry).interfaceId)
                        )
                    ) != 1
        ) revert S.NativeSurplusAuthorityInvalid(a.roleRegistry);
        uint256 recipient =
            _word(a.roleRegistry, abi.encodeCall(IStreamRoleRegistry.resolveRole, (_ROLE)));
        if (
            recipient == 0 || recipient > type(uint160).max
                || recipient == uint256(uint160(address(this)))
        ) {
            revert S.NativeSurplusAuthorityInvalid(a.roleRegistry);
        }
        a.recipient = address(uint160(recipient));
        bytes memory data = abi.encodeCall(IStreamRoleRegistry.roleMutationState, (_ROLE));
        uint256[2] memory words;
        bool ok;
        uint256 size;
        address target = a.roleRegistry;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), words, 64)
            size := returndatasize()
        }
        if (!ok || size != 64 || words[0] == 0 || words[1] == 0 || words[1] > type(uint64).max) {
            revert S.NativeSurplusAuthorityInvalid(target);
        }
        a.roleChainHash = bytes32(words[0]);
        a.roleRevision = uint64(words[1]);
    }

    function _word(address target, bytes memory data) private view returns (uint256 word) {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            let p := mload(0x40)
            ok := staticcall(gas(), target, add(data, 32), mload(data), p, 32)
            size := returndatasize()
            word := mload(p)
        }
        if (!ok || size != 32) revert S.NativeSurplusAuthorityInvalid(target);
    }

    function _action(S.NativeSurplusQuote memory q) private view returns (bytes32 id) {
        bytes memory data = abi.encodeCall(IStreamGovernedParameterAuthority.currentAction, ());
        uint256[6] memory w;
        uint256 size;
        bool ok;
        address target = q.authority.executor;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), w, 192)
            size := returndatasize()
        }
        if (
            !ok || size != 192 || w[0] != 1 || w[1] == 0 || w[2] != 1
                || bytes32(w[3]) != q.scopeHash || bytes32(w[4]) != q.oldValueHash
                || bytes32(w[5]) != q.newValueHash
        ) revert S.NativeSurplusActionInvalid();
        return bytes32(w[1]);
    }
}
