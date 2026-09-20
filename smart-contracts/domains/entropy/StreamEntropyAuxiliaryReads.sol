// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamEntropyCoordinatorContinuity as V
} from "../../interfaces/stream/entropy/IStreamEntropyCoordinatorContinuity.sol";
import { StreamEntropyFreshRecovery } from "./StreamEntropyFreshRecovery.sol";
import {
    IStreamEntropyFreshRecovery
} from "../../interfaces/stream/entropy/IStreamEntropyFreshRecovery.sol";
import "./StreamEntropyCoordinator.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import { StreamEntropyCollectionRecovery } from "./StreamEntropyCollectionRecovery.sol";
import {
    IStreamEntropyCollectionRecovery as C
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionRecovery.sol";
import { StreamEntropyRecoveryPolicies } from "./StreamEntropyRecoveryPolicies.sol";
import {
    IStreamEntropyRecoveryPolicies as R
} from "../../interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import { StreamEntropyProviderLifecycle } from "./StreamEntropyProviderLifecycle.sol";
import { StreamEntropyIncidentParameters } from "./StreamEntropyIncidentParameters.sol";
import { StreamEntropyIncidentEvidence } from "./StreamEntropyIncidentEvidence.sol";
import {
    IStreamEntropyProviderLifecycle as L,
    EntropyProviderState
} from "../../interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";
import {
    IStreamEntropyIncidents
} from "../../interfaces/stream/entropy/IStreamEntropyIncidents.sol";
import {
    IStreamGasParameterHost as G
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Fixed terminal read encoder. Every admitted selector is a view; no authority or state mutation.
library StreamEntropyAuxiliaryReads {
    error UnknownEntropyRead(bytes4 selector);

    function read(
        IStreamCore core,
        mapping(uint256 => StreamEntropyCoordinator.CollectionConfig) storage configs,
        mapping(uint256 => uint32) storage epochs,
        bytes calldata data
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(data[:4]);
        if (selector == L.entropyProviderRecord.selector) {
            return
                abi.encode(StreamEntropyProviderLifecycle.record(abi.decode(data[4:], (address))));
        }
        if (selector == L.entropyProviderCount.selector) {
            return abi.encode(StreamEntropyProviderLifecycle.count());
        }
        if (selector == L.entropyProviderAt.selector) {
            return abi.encode(StreamEntropyProviderLifecycle.at(abi.decode(data[4:], (uint256))));
        }
        if (selector == L.entropyProviderTransition.selector) {
            (address provider, EntropyProviderState state, string memory reason) =
                abi.decode(data[4:], (address, EntropyProviderState, string));
            (bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 cls) =
                StreamEntropyProviderLifecycle.transition(provider, state, reason, false);
            return abi.encode(scope, oldHash, newHash, cls);
        }
        if (selector == L.providerRevocationTransition.selector) {
            (address provider, bool revoked) = abi.decode(data[4:], (address, bool));
            (bytes32 scope, bytes32 oldHash, bytes32 newHash,) = StreamEntropyProviderLifecycle.transition(
                provider,
                revoked ? EntropyProviderState.INCIDENT_REVOKED : EntropyProviderState.ACTIVE,
                StreamEntropyProviderLifecycle.LEGACY_REASON,
                true
            );
            return abi.encode(scope, oldHash, newHash);
        }
        if (selector == G.gasParameter.selector) {
            return
                abi.encode(StreamEntropyIncidentParameters.value(abi.decode(data[4:], (bytes32))));
        }
        if (selector == G.gasParameterInfo.selector) {
            (uint256 value, uint256 floor, uint8 direction, uint64 revision) =
                StreamEntropyIncidentParameters.info(abi.decode(data[4:], (bytes32)));
            return abi.encode(value, floor, direction, revision);
        }
        if (selector == bytes4(keccak256("gasParameterTransition(bytes32,uint256)"))) {
            (bytes32 id, uint256 next) = abi.decode(data[4:], (bytes32, uint256));
            (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
                StreamEntropyIncidentParameters.transition(id, next);
            return abi.encode(scope, oldHash, newHash);
        }
        if (selector == IStreamEntropyIncidents.entropyIncident.selector) {
            return
                abi.encode(StreamEntropyIncidentEvidence.incident(abi.decode(data[4:], (bytes32))));
        }
        if (selector == V.coordinatorReplacementTerms.selector) {
            (address successor, bytes32 hash, bytes32 policy) =
                StreamEntropyRecoveryPolicies.replacement(abi.decode(data[4:], (bytes32)));
            return abi.encode(successor, hash, policy);
        }
        if (selector == V.freshRecoveryPolicyV2Transition.selector) {
            (bytes32 id, bytes32 hash) = abi.decode(data[4:], (bytes32, bytes32));
            (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
                StreamEntropyRecoveryPolicies.transitionV2(id, hash);
            return abi.encode(scope, oldHash, newHash);
        }
        if (selector == R.freshRecoveryPolicy.selector) {
            (R.FreshRecoveryPolicy memory policy, bytes32 hash, uint64 revision, bytes32 actionId) =
                StreamEntropyRecoveryPolicies.record(abi.decode(data[4:], (bytes32)));
            return abi.encode(policy, hash, revision, actionId);
        }
        if (selector == R.freshRecoveryPolicyTransition.selector) {
            (bytes32 id, bytes32 hash, bool freezing) =
                abi.decode(data[4:], (bytes32, bytes32, bool));
            (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
                StreamEntropyRecoveryPolicies.transition(id, hash, freezing);
            return abi.encode(scope, oldHash, newHash);
        }
        if (selector == C.collectionFreshRecovery.selector) {
            return
                abi.encode(StreamEntropyCollectionRecovery.record(abi.decode(data[4:], (uint256))));
        }
        if (selector == C.collectionFreshRecoveryTransition.selector) {
            (uint256 id, uint16 attempts, bytes32 policyId) =
                abi.decode(data[4:], (uint256, uint16, bytes32));
            (bytes32 scope, bytes32 oldHash, bytes32 newHash) = StreamEntropyCollectionRecovery.transition(
                core, configs[id], epochs[id], id, attempts, policyId
            );
            return abi.encode(scope, oldHash, newHash);
        }
        if (selector == IStreamEntropyFreshRecovery.freshRecoveryReceipt.selector) {
            return abi.encode(StreamEntropyFreshRecovery.receipt(abi.decode(data[4:], (bytes32))));
        }
        if (selector == IStreamEntropyFreshRecovery.artistContentFamilyState.selector) {
            (uint256 id, bytes32 family) = abi.decode(data[4:], (uint256, bytes32));
            (bool supported, bytes32 state) =
                StreamEntropyFreshRecovery.familyState(core, id, family);
            return abi.encode(supported, state);
        }
        revert UnknownEntropyRead(selector);
    }
}
