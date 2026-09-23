// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamEntropyProviderLifecycle as L,
    EntropyProviderState as S
} from "../../interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";
import {
    IStreamGovernedParameterAuthority as A
} from "../../interfaces/stream/parameters/IStreamGovernedParameterAuthority.sol";
import { StreamEntropyCoordinatorReads } from "./StreamEntropyCoordinatorReads.sol";
import { StreamEntropyInstantProviderReads } from "./StreamEntropyInstantProviderReads.sol";

/// @notice Fixed library: state, enumeration and governance replay live in its calling coordinator.
library StreamEntropyProviderLifecycle {
    bytes32 private constant SLOT = keccak256("6529STREAM_ENTROPY_PROVIDER_LIFECYCLE_STORAGE_V1");
    bytes32 private constant SCOPE = keccak256("6529STREAM_ENTROPY_PROVIDER_LIFECYCLE_SCOPE_V1");
    bytes32 private constant STATE = keccak256("6529STREAM_ENTROPY_PROVIDER_LIFECYCLE_STATE_V1");
    string internal constant LEGACY_REASON = "urn:stream:governance:provider-revocation";
    bytes4 private constant LEGACY_SELECTOR = bytes4(keccak256("setProviderRevoked(address,bool)"));

    struct Store {
        mapping(address => L.ProviderRecord) records;
        address[] providers;
        bytes32 authorityCodeHash;
        mapping(address => mapping(bytes32 => bool)) consumedActions;
    }
    event EntropyProviderStateUpdated(
        uint16 schemaVersion,
        address indexed provider,
        bytes32 indexed actionId,
        S oldState,
        S newState,
        string reasonURI
    );
    event ProviderRevocationUpdated(address indexed provider, bool revoked);

    function store() private pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function initialize(address authority) internal {
        store().authorityCodeHash = authority.codehash;
    }

    function record(address provider) public view returns (L.ProviderRecord memory) {
        return store().records[provider];
    }

    function count() public view returns (uint256) {
        return store().providers.length;
    }

    function at(uint256 i) public view returns (address) {
        if (i >= store().providers.length) revert L.ProviderIndexOutOfBounds(i);
        return store().providers[i];
    }

    function requireActive(address provider) public view {
        L.ProviderRecord storage r = store().records[provider];
        if (
            r.state != S.ACTIVE || provider.code.length == 0
                || provider.codehash != r.runtimeCodeHash
        ) {
            revert L.EntropyProviderUnavailable(provider, r.state);
        }
    }

    function canFulfill(address provider, bytes32 originalCodeHash) public view returns (bool) {
        L.ProviderRecord storage r = store().records[provider];
        return (r.state == S.ACTIVE || r.state == S.DEPRECATED) && provider.code.length != 0
            && provider.codehash == r.runtimeCodeHash && r.runtimeCodeHash == originalCodeHash;
    }

    function transition(address provider, S next, string memory reasonURI, bool legacy)
        public
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 actionClass)
    {
        L.ProviderRecord storage r = store().records[provider];
        uint256 length = bytes(reasonURI).length;
        if (length == 0 || length > 2048) revert L.ProviderLifecycleInvalidReason();
        if (
            provider == address(0) || next == S.UNKNOWN || next == r.state
                || (next != S.ACTIVE && r.state == S.UNKNOWN)
                || (next == S.DEPRECATED && r.state != S.ACTIVE)
        ) revert L.InvalidProviderTransition(provider, r.state, next);
        if (r.revision == type(uint64).max) revert L.ProviderLifecycleRevisionOverflow(provider);
        bytes32 codeHash = r.runtimeCodeHash;
        if (next == S.ACTIVE) {
            if (StreamEntropyInstantProviderReads.supportsInstant(provider)) {
                StreamEntropyInstantProviderReads.configuration(provider);
            } else {
                StreamEntropyCoordinatorReads.providerConfiguration(provider, 1);
            }
            codeHash = provider.codehash;
        }
        bytes4 selector = legacy
            ? LEGACY_SELECTOR
            : next == S.ACTIVE
                ? L.activateEntropyProvider.selector
                : next == S.DEPRECATED
                    ? L.deprecateEntropyProvider.selector
                    : L.revokeEntropyProvider.selector;
        actionClass = legacy || next == S.ACTIVE ? 1 : 0;
        scope = keccak256(abi.encode(SCOPE, block.chainid, address(this), provider, selector));
        oldHash = keccak256(
            abi.encode(STATE, scope, r.state, r.runtimeCodeHash, r.revision, r.reasonHash)
        );
        newHash = keccak256(
            abi.encode(STATE, scope, next, codeHash, r.revision + 1, keccak256(bytes(reasonURI)))
        );
    }

    /// @dev Fixed host mutation selectors share one transport; original lifecycle checks run below.
    function updateEncoded(
        address authority,
        mapping(address => bool) storage revokedProviders,
        bytes calldata data
    ) public {
        bytes4 selector = bytes4(data[:4]);
        address provider;
        S next;
        string memory reason;
        bool legacy = selector == LEGACY_SELECTOR;
        if (legacy) {
            bool revoked;
            (provider, revoked) = abi.decode(data[4:], (address, bool));
            next = revoked ? S.INCIDENT_REVOKED : S.ACTIVE;
            reason = LEGACY_REASON;
        } else {
            (provider, reason) = abi.decode(data[4:], (address, string));
            if (selector == L.activateEntropyProvider.selector) next = S.ACTIVE;
            else if (selector == L.deprecateEntropyProvider.selector) next = S.DEPRECATED;
            else if (selector == L.revokeEntropyProvider.selector) next = S.INCIDENT_REVOKED;
            else revert L.ProviderLifecycleInvalidContext();
        }
        update(authority, provider, next, reason, legacy);
        bool revoked = next == S.INCIDENT_REVOKED;
        revokedProviders[provider] = revoked;
        emit ProviderRevocationUpdated(provider, revoked);
    }

    function update(
        address authority,
        address provider,
        S next,
        string memory reasonURI,
        bool legacy
    ) public {
        if (
            msg.sender != authority || authority.code.length == 0
                || authority.codehash != store().authorityCodeHash
        ) {
            revert L.ProviderLifecycleUnauthorized(msg.sender);
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 expectedClass) =
            transition(provider, next, reasonURI, legacy);
        bytes memory input = abi.encodeCall(A.currentAction, ());
        bytes memory result = new bytes(192);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), authority, add(input, 32), mload(input), add(result, 32), 192)
            size := returndatasize()
        }
        if (!ok || size != 192) revert L.ProviderLifecycleInvalidContext();
        (
            uint256 executing,
            bytes32 actionId,
            uint256 cls,
            bytes32 actualScope,
            bytes32 actualOld,
            bytes32 actualNew
        ) = abi.decode(result, (uint256, bytes32, uint256, bytes32, bytes32, bytes32));
        if (
            executing != 1 || actionId == 0 || cls > 255 || actualScope != scope
                || actualOld != oldHash || actualNew != newHash
        ) {
            revert L.ProviderLifecycleInvalidContext();
        }
        if (cls != expectedClass) revert L.ProviderLifecycleWrongClass(expectedClass, uint8(cls));
        Store storage s = store();
        L.ProviderRecord storage r = s.records[provider];
        if (s.consumedActions[provider][actionId]) {
            revert L.ProviderLifecycleReplay(provider, actionId);
        }
        s.consumedActions[provider][actionId] = true;
        S old = r.state;
        if (old == S.UNKNOWN) s.providers.push(provider);
        if (next == S.ACTIVE) r.runtimeCodeHash = provider.codehash;
        r.state = next;
        ++r.revision;
        r.reasonHash = keccak256(bytes(reasonURI));
        r.lastActionId = actionId;
        emit EntropyProviderStateUpdated(1, provider, actionId, old, next, reasonURI);
    }
}
