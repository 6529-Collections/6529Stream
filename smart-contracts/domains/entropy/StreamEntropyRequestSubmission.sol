// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/entropy/IStreamInstantEntropyProviderIdentity.sol";

import "./StreamEntropyCoordinator.sol";
import "./StreamEntropyRequestPlan.sol";
import "./StreamEntropyInstantProviderReads.sol";
import "./StreamEntropyCoordinatorReads.sol";
import "./StreamEntropyContinuity.sol";
import { StreamEntropyPolicyInventory as Inventory } from "./StreamEntropyPolicyInventory.sol";
import {
    StreamEntropyPolicyImportState as ImportState
} from "./StreamEntropyPolicyImportState.sol";
import { StreamEntropyRelayState as RelayState } from "./StreamEntropyRelayState.sol";
import {
    IStreamEntropyOriginRelay as R
} from "../../interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";
import {
    IStreamEntropyPolicyContinuity as ImportTypes
} from "../../interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";

/// @notice Fixed submission worker with explicit original storage references; custody stays in the host.
library StreamEntropyRequestSubmission {
    event EntropyRequested(
        bytes32 indexed requestKey,
        uint256 indexed tokenId,
        bytes32 indexed scopeId,
        address provider,
        uint256 providerRequestId
    );
    event InstantEntropyProduced(
        uint16 schemaVersion,
        bytes32 indexed requestKey,
        uint256 indexed providerRequestId,
        bytes32 rawRandomness,
        bytes32 provenanceHash,
        IStreamInstantEntropyProviderIdentity.InstantMode mode,
        bytes32 assumptionsHash
    );

    struct Input {
        bytes32 subjectKey;
        uint256 tokenId;
        bytes32 scopeId;
        StreamEntropyRequestPlan.Plan plan;
    }

    function submit(
        IStreamCore core,
        StreamEntropyCoordinator.Subject storage subject,
        mapping(bytes32 => StreamEntropyCoordinator.Request) storage requests,
        mapping(bytes32 => IStreamEntropyEpochs.RequestPolicySnapshot) storage policies,
        mapping(address => mapping(uint256 => bytes32)) storage providerKeys,
        Input memory input
    ) public returns (uint256 providerRequestId) {
        StreamEntropyRequestPlan.Plan memory p = input.plan;
        address provider = p.policy.provider;
        RelayState.requireRequestKeyUnused(p.key);
        subject.requestKey = p.key;
        subject.status = StreamEntropyStatus.REQUESTED;
        requests[p.key] = StreamEntropyCoordinator.Request(
            input.subjectKey, input.tokenId, input.scopeId, provider, uint64(block.number), 0, 0
        );
        policies[p.key] = p.policy;
        StreamEntropyContinuity.admit(subject.collectionId, p.key);
        (address origin, bytes32 originCodeHash) = Inventory.origin(subject.collectionId);
        R.RelayInput memory relayInput;
        if (origin != address(this)) {
            ImportTypes.ImportReceipt memory imported = ImportState.receipt();
            if (imported.state != ImportTypes.ImportState.ACTIVE) {
                revert ImportTypes.InvalidEntropyPolicyImport();
            }
            relayInput = R.RelayInput(
                imported.importHash,
                subject.collectionId,
                input.tokenId,
                input.scopeId,
                p.key,
                p.policy
            );
            RelayState.prewriteLocal(core, origin, originCodeHash, relayInput);
        }
        if (p.instant) {
            providerRequestId = uint256(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_INSTANT_PROVIDER_REQUEST_V1"),
                        p.key,
                        p.policy.requestAttempt,
                        provider,
                        p.policy.providerEpoch,
                        p.policy.providerConfigHash
                    )
                )
            );
            _bind(requests[p.key], providerKeys, p.key, provider, providerRequestId);
            // Both directions and the complete request exist before any provider read below.
            (IStreamInstantEntropyProviderIdentity.InstantMode mode, bytes32 assumptions) =
                StreamEntropyInstantProviderReads.profile(provider);
            (bytes32 raw, bytes32 provenance) = origin == address(this)
                ? StreamEntropyInstantProviderReads.entropy(provider, p.key, p.context)
                : _relayInstant(origin, relayInput);
            emit EntropyRequested(p.key, input.tokenId, input.scopeId, provider, providerRequestId);
            requests[p.key].rawRandomness = raw;
            subject.seed = StreamEntropyCoordinatorReads.deriveSeed(
                core, p.key, requests[p.key], subject, policies[p.key], raw
            );
            subject.status = StreamEntropyStatus.FINALIZED;
            StreamEntropyContinuity.close(p.key);
            emit InstantEntropyProduced(
                1, p.key, providerRequestId, raw, provenance, mode, assumptions
            );
        } else {
            providerRequestId = origin == address(this)
                ? IStreamEntropyProvider(provider).requestEntropy{ value: p.fee }(p.key, p.context)
                : R(origin).relayEntropyRequest{ value: p.fee }(relayInput);
            _bind(requests[p.key], providerKeys, p.key, provider, providerRequestId);
            emit EntropyRequested(p.key, input.tokenId, input.scopeId, provider, providerRequestId);
        }
    }

    function _bind(
        StreamEntropyCoordinator.Request storage request,
        mapping(address => mapping(uint256 => bytes32)) storage providerKeys,
        bytes32 key,
        address provider,
        uint256 id
    ) private {
        RelayState.requireProviderIdUnused(provider, id);
        if (providerKeys[provider][id] != 0) {
            revert StreamEntropyCoordinator.ProviderRequestCollision(provider, id);
        }
        providerKeys[provider][id] = key;
        request.providerRequestId = id;
    }

    function _relayInstant(address target, R.RelayInput memory input)
        private
        view
        returns (bytes32 raw, bytes32 provenance)
    {
        uint256 cap = StreamEntropyIncidentParameters.value(
            keccak256("6529STREAM_GGP_ENTROPY_RELAY_INSTANT_READ_GAS_LIMIT")
        );
        bytes memory data = abi.encodeCall(R.relayInstantEntropy, (input));
        bytes memory out = new bytes(64);
        uint256 available = gasleft();
        if (available <= 15000 || (available - 15000) / 64 * 63 < cap) {
            revert R.EntropyRelayReadFailed(target);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(out, 32), 64)
            size := returndatasize()
        }
        if (!ok || size != 64) revert R.EntropyRelayReadFailed(target);
        return abi.decode(out, (bytes32, bytes32));
    }
}
