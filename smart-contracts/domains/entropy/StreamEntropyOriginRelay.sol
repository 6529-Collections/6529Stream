// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import { IStreamCoreIdentity } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";
import {
    IStreamEntropyOriginRelay as R
} from "../../interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import { IStreamEntropyProvider } from "../../interfaces/stream/entropy/IStreamEntropyProvider.sol";
import { StreamEntropyCoordinator } from "./StreamEntropyCoordinator.sol";
import {
    StreamEntropyRelayState as S,
    StreamEntropyRelayReads as Read
} from "./StreamEntropyRelayState.sol";
import { StreamEntropyProviderLifecycle } from "./StreamEntropyProviderLifecycle.sol";
import { StreamEntropyInstantProviderReads } from "./StreamEntropyInstantProviderReads.sol";
import { StreamEntropyIncidentParameters } from "./StreamEntropyIncidentParameters.sol";

/// @notice Fixed execution worker for authenticated ultimate-origin provider calls and raw custody.
/// @dev Mutating host wrappers share the original nonReentrant guard. This worker never owns funds,
/// subjects, or finality; durable receipt at origin and successful successor delivery are separate.
library StreamEntropyOriginRelay {
    bytes32 private constant DELIVERY_GAS =
        keccak256("6529STREAM_GGP_ENTROPY_RELAY_DELIVERY_GAS_LIMIT");
    uint256 private constant DELIVERY_RESERVE = 50000;

    event EntropyRelaySubmitted(
        uint16 schemaVersion,
        bytes32 indexed relayId,
        bytes32 indexed successorRequestKey,
        address indexed successor,
        uint256 collectionId,
        address provider,
        uint256 providerRequestId,
        bytes32 contextHash
    );
    event EntropyRelayRawReceived(
        uint16 schemaVersion,
        bytes32 indexed relayId,
        bytes32 indexed successorRequestKey,
        bytes32 rawRandomness
    );
    event EntropyRelayDelivery(
        uint16 schemaVersion,
        bytes32 indexed relayId,
        address indexed successor,
        bool delivered,
        bool terminalStale,
        uint8 outcome
    );

    /// @dev The host forwards its fixed selector's arguments; decode the static tuple once here.
    function submitEncoded(
        IStreamCore core,
        mapping(bytes32 => StreamEntropyCoordinator.Request) storage originalRequests,
        mapping(address => mapping(uint256 => bytes32)) storage originalProviderKeys,
        bytes calldata encoded
    ) public returns (uint256) {
        return
            submit(
                core, originalRequests, originalProviderKeys, abi.decode(encoded, (R.RelayInput))
            );
    }

    function instantEncoded(IStreamCore core, bytes calldata encoded)
        public
        view
        returns (bytes32, bytes32)
    {
        return instant(core, abi.decode(encoded, (R.RelayInput)));
    }

    function submit(
        IStreamCore core,
        mapping(bytes32 => StreamEntropyCoordinator.Request) storage originalRequests,
        mapping(address => mapping(uint256 => bytes32)) storage originalProviderKeys,
        R.RelayInput memory input
    ) public returns (uint256 providerRequestId) {
        bytes memory context = _authenticate(core, input, false);
        bytes32 key = input.successorRequestKey;
        S.requireRequestKeyUnused(key);
        if (originalRequests[key].provider != address(0)) {
            revert R.EntropyRelayRequestCollision(key);
        }
        uint256 quote = abi.decode(
            Read.read(
                input.policy.provider,
                abi.encodeCall(IStreamEntropyProvider.quoteRequest, (context)),
                32
            ),
            (uint256)
        );
        if (msg.value != quote) revert R.EntropyRelayFeeMismatch(msg.value, quote);
        bytes32 id = S.relayId(core, address(this), msg.sender, input);
        S.Store storage s = S.store();
        if (id == 0 || s.results[id].successor != address(0)) {
            revert R.EntropyRelayRequestCollision(key);
        }
        s.requestRelays[key] = id;
        R.RelayResult storage r = s.results[id];
        r.successor = msg.sender;
        r.successorCodeHash = msg.sender.codehash;
        r.importHash = input.importHash;
        r.collectionId = input.collectionId;
        r.successorRequestKey = key;
        r.provider = input.policy.provider;
        r.providerCodeHash = input.policy.providerCodeHash;
        r.providerConfigHash = input.policy.providerConfigHash;
        r.relayId = id;
        r.contextHash = keccak256(context);
        r.lastOutcome = 4;
        // Host nonReentrancy prevents any provider callback until both ID directions are bound.
        providerRequestId =
            IStreamEntropyProvider(r.provider).requestEntropy{ value: quote }(key, context);
        S.requireProviderIdUnused(r.provider, providerRequestId);
        if (originalProviderKeys[r.provider][providerRequestId] != 0) {
            revert R.EntropyRelayProviderIdCollision(r.provider, providerRequestId);
        }
        s.providerRelays[r.provider][providerRequestId] = id;
        r.providerRequestId = providerRequestId;
        r.submitted = true;
        emit EntropyRelaySubmitted(
            1,
            id,
            key,
            r.successor,
            input.collectionId,
            r.provider,
            providerRequestId,
            r.contextHash
        );
    }

    function instant(IStreamCore core, R.RelayInput memory input)
        public
        view
        returns (bytes32 raw, bytes32 provenance)
    {
        bytes memory context = _authenticate(core, input, true);
        return StreamEntropyInstantProviderReads.entropy(
            input.policy.provider, input.successorRequestKey, context
        );
    }

    /// @notice Unknown ordinary keys are left to the original host's fulfillment entry.
    function capture(
        IStreamCore,
        mapping(bytes32 => StreamEntropyCoordinator.Request) storage originalRequests,
        mapping(
            address => mapping(uint256 => bytes32)
        ) storage originalProviderKeys,
        bytes32 key,
        bytes32 raw
    ) public returns (bool recognized, uint8 outcome) {
        bytes32 id = S.store().requestRelays[key];
        if (id == 0) return (false, 0);
        R.RelayResult storage r = S.store().results[id];
        _bound(originalRequests, originalProviderKeys, r, id);
        if (msg.sender != r.provider || msg.sender.codehash != r.providerCodeHash) {
            revert R.EntropyRelayUnauthorized(msg.sender);
        }
        if (r.rawReceived) {
            if (r.raw != raw) revert R.EntropyRelayRawMismatch(id);
        } else {
            r.rawReceived = true;
            r.raw = raw;
            emit EntropyRelayRawReceived(1, id, key, raw);
        }
        _deliver(r);
        // Provider ACK means this host durably captured output; it does not assert token finality.
        return (true, 0);
    }

    function retry(
        IStreamCore,
        mapping(bytes32 => StreamEntropyCoordinator.Request) storage originalRequests,
        mapping(
            address => mapping(uint256 => bytes32)
        ) storage originalProviderKeys,
        bytes32 id
    ) public returns (bool delivered, uint8 outcome) {
        R.RelayResult storage r = S.store().results[id];
        _bound(originalRequests, originalProviderKeys, r, id);
        if (!r.rawReceived) revert R.EntropyRelayResultUnavailable(id);
        _deliver(r);
        return (r.delivered, r.lastOutcome);
    }

    function _bound(
        mapping(bytes32 => StreamEntropyCoordinator.Request) storage originalRequests,
        mapping(
            address => mapping(uint256 => bytes32)
        ) storage originalProviderKeys,
        R.RelayResult storage r,
        bytes32 id
    ) private view {
        if (
            id == 0 || !r.submitted || r.relayId != id || r.successor == address(0)
                || S.store().requestRelays[r.successorRequestKey] != id
                || S.store().providerRelays[r.provider][r.providerRequestId] != id
                || originalRequests[r.successorRequestKey].provider != address(0)
                || originalProviderKeys[r.provider][r.providerRequestId] != 0
        ) revert R.EntropyRelayResultUnavailable(id);
    }

    function _authenticate(IStreamCore core, R.RelayInput memory input, bool instant_)
        private
        view
        returns (bytes memory context)
    {
        S.Admission storage a = S.store().admissions[input.collectionId][msg.sender];
        if (
            a.importHash == 0 || input.importHash != a.importHash || msg.sender.code.length == 0
                || msg.sender.codehash != a.successorCodeHash || input.successorRequestKey == 0
                || input.successorRequestKey != S.requestKey(core, msg.sender, input)
                || (input.tokenId == 0) == (input.scopeId == 0)
        ) revert R.EntropyRelayUnauthorized(msg.sender);
        C.ImportReceipt memory receipt = abi.decode(
            Read.read(msg.sender, abi.encodeCall(C.entropyPolicyImport, ()), 544), (C.ImportReceipt)
        );
        if (
            receipt.state != C.ImportState.ACTIVE || receipt.importHash != input.importHash
                || receipt.activationActionId == 0
        ) revert R.InvalidEntropyRelay();
        C.PolicyExport memory live = abi.decode(
            Read.read(
                msg.sender, abi.encodeCall(C.exportEntropyPolicy, (input.collectionId)), 1184
            ),
            (C.PolicyExport)
        );
        if (
            live.collectionId != input.collectionId || live.policyOrigin != address(this)
                || live.policyOriginCodeHash != address(this).codehash
                || live.record.policyHash != a.policyHash
                || live.policy.mode != a.policy.policy.mode
        ) revert R.InvalidEntropyRelay();
        _terms(a, input, instant_);
        StreamEntropyProviderLifecycle.requireActive(input.policy.provider);
        if (
            input.policy.provider.codehash != input.policy.providerCodeHash
                || abi.decode(
                        Read.read(
                            input.policy.provider, abi.encodeWithSignature("coordinator()"), 32
                        ),
                        (address)
                    ) != address(this)
                || abi.decode(
                        Read.read(
                            input.policy.provider,
                            abi.encodeWithSignature("streamEntropyProviderConfigHash()"),
                            32
                        ),
                        (bytes32)
                    ) != input.policy.providerConfigHash
        ) revert R.EntropyRelayDependency(input.policy.provider);
        if (input.tokenId != 0) {
            if (
                abi.decode(
                            Read.read(
                                address(core),
                                abi.encodeCall(
                                    IStreamCoreIdentity.coordinatorAtMint, (input.tokenId)
                                ),
                                32
                            ),
                            (address)
                        ) != msg.sender
                    || abi.decode(
                            Read.read(
                                address(core),
                                abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (input.tokenId)),
                                32
                            ),
                            (uint256)
                        ) != 2
            ) revert R.InvalidEntropyRelay();
            (bool exists, uint256 collectionId,, bool burned) = abi.decode(
                Read.read(
                    address(core),
                    abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (input.tokenId)),
                    128
                ),
                (bool, uint256, uint256, bool)
            );
            if (!exists || burned || collectionId != input.collectionId) {
                revert R.InvalidEntropyRelay();
            }
        }
        bytes32 witness = abi.decode(
            Read.read(
                msg.sender, abi.encodeCall(R.relayRequestWitness, (input.successorRequestKey)), 32
            ),
            (bytes32)
        );
        if (
            witness == 0
                || witness
                    != S.witnessHash(core, msg.sender, address(this), address(this).codehash, input)
        ) revert R.EntropyRelayWitnessMismatch(input.successorRequestKey);
        context = S.context(core, input);
    }

    function _terms(S.Admission storage a, R.RelayInput memory input, bool instant_) private view {
        if (
            (a.policy.policy.mode == P.Mode.INSTANT) != instant_
                || a.policy.policy.mode == P.Mode.DISABLED
                || input.policy.collectionSalt != a.policy.policy.collectionSalt
                || input.policy.requestAttempt == 0
                || (input.scopeId != 0 && a.policy.policy.mode != P.Mode.ASYNC)
                || (input.tokenId != 0
                    && a.policy.policy.renderRequirement == P.RenderRequirement.NOT_REQUIRED)
                || (instant_ && (input.policy.inputsHash != 0 || input.policy.requestAttempt != 1))
        ) revert R.InvalidEntropyRelay();
        if (input.policy.requestAttempt == 1) {
            if (
                input.policy.provider != a.policy.policy.provider
                    || input.policy.providerCodeHash != a.policy.providerCodeHash
                    || input.policy.providerConfigHash != a.policy.providerConfigHash
                    || input.policy.providerEpoch != a.policy.record.providerEpoch
            ) revert R.InvalidEntropyRelay();
        } else {
            uint256 index = uint256(input.policy.requestAttempt) - 2;
            if (
                index >= a.policy.recovery.maxFreshRecoveryAttempts
                    || index >= a.recovery.policy.steps.length
            ) revert R.InvalidEntropyRelay();
            if (
                input.policy.provider != a.recovery.policy.steps[index].provider
                    || input.policy.providerEpoch != a.recovery.policy.steps[index].providerEpoch
                    || input.policy.providerConfigHash
                        != a.recovery.policy.steps[index].providerConfigHash
                    || input.policy.providerCodeHash
                        != StreamEntropyProviderLifecycle.record(input.policy.provider)
                        .runtimeCodeHash
            ) revert R.InvalidEntropyRelay();
        }
    }

    function _deliver(R.RelayResult storage r) private {
        if (r.delivered) return;
        // A provider callback may have enough gas to persist raw output but not attempt delivery.
        // Leave its last retryable outcome unchanged and preserve enough gas for the host return.
        if (gasleft() <= DELIVERY_RESERVE) return;
        uint8 outcome = 4;
        (bool checked, bool eligible) = _lifecycle(r.provider, r.providerCodeHash);
        if (!checked) return;
        if (!eligible) {
            outcome = 5;
        } else if (r.successor.code.length != 0 && r.successor.codehash == r.successorCodeHash) {
            (uint256 cap,,, uint64 revision) = StreamEntropyIncidentParameters.info(DELIVERY_GAS);
            if (cap == 0 || revision == 0) return;
            bytes memory data =
                abi.encodeCall(R.fulfillRelayedEntropy, (r.successorRequestKey, r.relayId, r.raw));
            uint256 available = gasleft();
            if (available > DELIVERY_RESERVE && (available - DELIVERY_RESERVE) / 64 * 63 >= cap) {
                address target = r.successor;
                bool ok;
                uint256 size;
                uint256 word;
                assembly ("memory-safe") {
                    let ptr := mload(0x40)
                    mstore(ptr, 0)
                    ok := call(cap, target, 0, add(data, 32), mload(data), ptr, 32)
                    size := returndatasize()
                    word := mload(ptr)
                }
                if (ok && size == 32 && word <= 5) outcome = uint8(word);
            }
        }
        // Nonzero outcomes remain retryable: an unrelated finalization is not delivery evidence.
        if (outcome == 0) r.delivered = true;
        r.lastOutcome = outcome;
        emit EntropyRelayDelivery(1, r.relayId, r.successor, r.delivered, false, outcome);
    }

    /// @dev Fixed linked original lifecycle logic, bounded and non-bubbling after raw capture.
    function _lifecycle(address provider, bytes32 pin)
        private
        returns (bool checked, bool eligible)
    {
        (uint256 cap,,, uint64 revision) = StreamEntropyIncidentParameters.info(Read.AUTH_GAS);
        if (cap == 0 || revision == 0) return (false, false);
        bytes memory data = abi.encodeWithSelector(
            StreamEntropyProviderLifecycle.canFulfill.selector, provider, pin
        );
        uint256 available = gasleft();
        if (available <= DELIVERY_RESERVE || (available - DELIVERY_RESERVE) / 64 * 63 < cap) {
            return (false, false);
        }
        address target = address(StreamEntropyProviderLifecycle);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, 0)
            ok := delegatecall(cap, target, add(data, 32), mload(data), ptr, 32)
            size := returndatasize()
            word := mload(ptr)
        }
        if (!ok || size != 32 || word > 1) return (false, false);
        return (true, word == 1);
    }
}
