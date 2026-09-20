// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProvider.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "../../interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCollectionRecovery.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";

import "./StreamEntropyCoordinator.sol";
import "./StreamEntropyProviderLifecycle.sol";
import {
    StreamEntropyCollectionPolicyState as PolicyState
} from "./StreamEntropyCollectionPolicyState.sol";

/// @notice Fixed request preimage and quote worker; submission and custody remain in the host.
library StreamEntropyRequestPlan {
    struct Plan {
        bytes32 key;
        bytes context;
        uint256 fee;
        IStreamEntropyEpochs.RequestPolicySnapshot policy;
    }

    function initial(
        IStreamCore core,
        StreamEntropyCoordinator.Subject storage subject,
        StreamEntropyCoordinator.CollectionConfig storage config,
        uint32 epoch,
        uint256 tokenId,
        bytes32 scopeId
    ) public view returns (Plan memory p) {
        if (subject.status != StreamEntropyStatus.REGISTERED) {
            revert StreamEntropyCoordinator.InvalidStatus(subject.status);
        }
        if (scopeId != 0) PolicyState.requireAsync(subject.collectionId);
        return build(
            core,
            subject.collectionId,
            tokenId,
            scopeId,
            IStreamEntropyEpochs.RequestPolicySnapshot(
                config.provider,
                config.providerCodeHash,
                epoch,
                config.providerConfigHash,
                config.collectionSalt,
                subject.inputsHash,
                1
            )
        );
    }

    function build(
        IStreamCore core,
        uint256 collectionId,
        uint256 tokenId,
        bytes32 scopeId,
        IStreamEntropyEpochs.RequestPolicySnapshot memory policy
    ) public view returns (Plan memory p) {
        if (block.number > type(uint64).max) {
            revert StreamEntropyCoordinator.EntropyBlockNumberOverflow();
        }
        StreamEntropyProviderLifecycle.requireActive(policy.provider);
        if (
            policy.provider.codehash != policy.providerCodeHash
                || IStreamEntropyProvider(policy.provider).streamEntropyProviderConfigHash()
                    != policy.providerConfigHash
        ) {
            revert StreamEntropyCoordinator.ProviderConfigurationChanged(policy.provider);
        }
        p.policy = policy;
        p.context = abi.encode(
            uint16(scopeId == 0 ? 1 : 2),
            address(core),
            collectionId,
            tokenId,
            scopeId,
            policy.providerEpoch,
            policy.providerConfigHash,
            policy.requestAttempt,
            policy.inputsHash
        );
        if (scopeId == 0) {
            p.key = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ENTROPY_REQUEST_V1"),
                    block.chainid,
                    address(this),
                    address(core),
                    collectionId,
                    tokenId,
                    policy.provider,
                    policy.providerEpoch,
                    policy.providerConfigHash,
                    policy.requestAttempt
                )
            );
        } else {
            p.key = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ENTROPY_SCOPE_REQUEST_V1"),
                    block.chainid,
                    address(this),
                    address(core),
                    collectionId,
                    scopeId,
                    policy.provider,
                    policy.providerEpoch,
                    policy.providerConfigHash,
                    policy.inputsHash,
                    policy.requestAttempt
                )
            );
        }
        p.fee = IStreamEntropyProvider(policy.provider).quoteRequest(p.context);
    }
}
