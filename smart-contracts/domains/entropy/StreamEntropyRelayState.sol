// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import {
    IStreamEntropyOriginRelay as R
} from "../../interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import { StreamEntropyIncidentParameters } from "./StreamEntropyIncidentParameters.sol";

/// @notice Permanent origin admissions and per-request relay evidence in the calling host.
library StreamEntropyRelayState {
    bytes32 private constant SLOT = keccak256("6529STREAM_ENTROPY_ORIGIN_RELAY_STORAGE_V1");
    bytes32 internal constant RELAY_DOMAIN = keccak256("6529STREAM_ENTROPY_RELAY_V1");
    bytes32 internal constant WITNESS_DOMAIN = keccak256("6529STREAM_ENTROPY_RELAY_WITNESS_V1");

    struct Admission {
        bytes32 successorCodeHash;
        bytes32 importHash;
        bytes32 policyHash;
        bytes32 exportHash;
        C.PolicyExport policy;
        C.RecoveryExport recovery;
    }

    /// @dev Parent host exposes witnessHash only after checking its actual request/snapshot/subject.
    struct LocalRoute {
        address origin;
        bytes32 originCodeHash;
        bytes32 importHash;
        bytes32 relayId;
        bytes32 witnessHash;
    }

    struct Store {
        mapping(uint256 => mapping(address => Admission)) admissions;
        mapping(bytes32 => bool) actions;
        mapping(bytes32 => R.RelayResult) results;
        mapping(bytes32 => bytes32) requestRelays;
        mapping(address => mapping(uint256 => bytes32)) providerRelays;
        mapping(bytes32 => LocalRoute) localRoutes;
    }

    function store() internal pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function context(IStreamCore core, R.RelayInput memory input)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(
            uint16(input.scopeId == 0 ? 1 : 2),
            address(core),
            input.collectionId,
            input.tokenId,
            input.scopeId,
            input.policy.providerEpoch,
            input.policy.providerConfigHash,
            input.policy.requestAttempt,
            input.policy.inputsHash
        );
    }

    function requestKey(IStreamCore core, address successor, R.RelayInput memory input)
        internal
        view
        returns (bytes32)
    {
        if (input.scopeId == 0) {
            return keccak256(
                abi.encode(
                    keccak256("6529STREAM_ENTROPY_REQUEST_V1"),
                    block.chainid,
                    successor,
                    address(core),
                    input.collectionId,
                    input.tokenId,
                    input.policy.provider,
                    input.policy.providerEpoch,
                    input.policy.providerConfigHash,
                    input.policy.requestAttempt
                )
            );
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SCOPE_REQUEST_V1"),
                block.chainid,
                successor,
                address(core),
                input.collectionId,
                input.scopeId,
                input.policy.provider,
                input.policy.providerEpoch,
                input.policy.providerConfigHash,
                input.policy.inputsHash,
                input.policy.requestAttempt
            )
        );
    }

    function relayId(IStreamCore core, address origin, address successor, R.RelayInput memory input)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                RELAY_DOMAIN,
                block.chainid,
                origin,
                successor,
                successor.codehash,
                input.importHash,
                input.collectionId,
                input.successorRequestKey,
                keccak256(context(core, input))
            )
        );
    }

    function witnessHash(
        IStreamCore core,
        address successor,
        address origin,
        bytes32 originCodeHash,
        R.RelayInput memory input
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                WITNESS_DOMAIN,
                block.chainid,
                address(core),
                successor,
                successor.codehash,
                origin,
                originCodeHash,
                input
            )
        );
    }

    /// @notice Called only after the successor prewrites its complete actual request and snapshot.
    function prewriteLocal(
        IStreamCore core,
        address origin,
        bytes32 originCodeHash,
        R.RelayInput memory input
    ) internal returns (bytes32 id) {
        if (
            origin == address(this) || origin.code.length == 0 || origin.codehash != originCodeHash
                || originCodeHash == 0 || input.importHash == 0
                || input.successorRequestKey != requestKey(core, address(this), input)
                || store().localRoutes[input.successorRequestKey].origin != address(0)
        ) revert R.InvalidEntropyRelay();
        id = relayId(core, origin, address(this), input);
        store().localRoutes[input.successorRequestKey] = LocalRoute(
            origin,
            originCodeHash,
            input.importHash,
            id,
            witnessHash(core, address(this), origin, originCodeHash, input)
        );
    }

    /// @dev Ordinary and relayed provider-ID binding paths must both invoke this guard.
    function requireProviderIdUnused(address provider, uint256 id) internal view {
        if (store().providerRelays[provider][id] != 0) {
            revert R.EntropyRelayProviderIdCollision(provider, id);
        }
    }

    function requireRequestKeyUnused(bytes32 key) internal view {
        if (store().requestRelays[key] != 0) revert R.EntropyRelayRequestCollision(key);
    }
}

/// @notice Fixed-size/bounded authentication reads under a distinct full-cap relay envelope.
library StreamEntropyRelayReads {
    bytes32 internal constant AUTH_GAS =
        keccak256("6529STREAM_GGP_ENTROPY_RELAY_AUTH_READ_GAS_LIMIT");

    function read(address target, bytes memory data, uint256 size)
        internal
        view
        returns (bytes memory out)
    {
        out = bounded(target, data, size);
        if (out.length != size) revert R.EntropyRelayReadFailed(target);
    }

    function bounded(address target, bytes memory data, uint256 maximum)
        internal
        view
        returns (bytes memory out)
    {
        if (target.code.length == 0) revert R.EntropyRelayDependency(target);
        uint256 cap = StreamEntropyIncidentParameters.value(AUTH_GAS);
        out = new bytes(maximum);
        uint256 available = gasleft();
        if (available <= 15000 || (available - 15000) / 64 * 63 < cap) {
            revert R.EntropyRelayReadFailed(target);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(out, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) revert R.EntropyRelayReadFailed(target);
        assembly ("memory-safe") { mstore(out, size) }
    }
}
