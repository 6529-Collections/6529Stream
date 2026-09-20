// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamEntropyCoordinator.sol";
import { StreamEntropyCollectionRecovery } from "./StreamEntropyCollectionRecovery.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import { StreamEntropyCoordinatorReads } from "./StreamEntropyCoordinatorReads.sol";
import { StreamEntropyProviderLifecycle } from "./StreamEntropyProviderLifecycle.sol";
import {
    StreamEntropyCollectionPolicyState as PolicyState
} from "./StreamEntropyCollectionPolicyState.sol";

/// @notice Fixed collection configuration worker; retains host storage, validation order and events.
library StreamEntropyCollectionConfiguration {
    event CollectionEntropyConfigured(
        uint256 indexed collectionId,
        address indexed provider,
        bytes32 configHash,
        bytes32 collectionSalt,
        bool publicRequests,
        uint64 timeoutBlocks
    );
    event CollectionEntropyEpochConfigured(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed provider,
        uint32 providerEpoch,
        bytes32 providerConfigHash
    );

    function configure(
        IStreamCore core,
        mapping(
            uint256 => StreamEntropyCoordinator.CollectionConfig
        ) storage collectionEntropyConfig,
        mapping(uint256 => uint32) storage collectionProviderEpoch,
        mapping(uint256 => IStreamRevealFeeEscrow.CollectionRevealPolicy) storage revealPolicies,
        uint256 collectionId,
        address provider,
        bytes32 collectionSalt,
        bool publicRequests,
        uint64 timeoutBlocks
    ) public {
        PolicyState.requireLegacy(collectionId);
        if (!core.collectionExists(collectionId)) {
            revert StreamEntropyCoordinator.InvalidCollection(collectionId);
        }
        if (
            collectionEntropyConfig[collectionId].locked
                || core.collectionFreezeStatus(collectionId)
        ) revert StreamEntropyCoordinator.PolicyLocked(collectionId);
        bytes32 configHash =
            StreamEntropyCoordinatorReads.providerConfiguration(provider, timeoutBlocks);
        StreamEntropyProviderLifecycle.requireActive(provider);
        StreamEntropyCoordinator.CollectionConfig storage prior =
            collectionEntropyConfig[collectionId];
        uint32 epoch = collectionProviderEpoch[collectionId];
        if (prior.provider != provider || prior.providerConfigHash != configHash) {
            if (epoch == type(uint32).max) {
                revert IStreamEntropyEpochs.ProviderEpochOverflow(collectionId);
            }
            collectionProviderEpoch[collectionId] = ++epoch;
        }
        StreamEntropyCollectionRecovery.validateEpoch(collectionId, epoch);
        collectionEntropyConfig[collectionId] = StreamEntropyCoordinator.CollectionConfig(
            provider,
            publicRequests,
            false,
            timeoutBlocks,
            configHash,
            provider.codehash,
            collectionSalt
        );
        if (revealPolicies[collectionId].declared) {
            StreamEntropyCoordinatorReads.validateRevealFee(
                collectionEntropyConfig[collectionId],
                revealPolicies[collectionId].revealFeePerTokenWei
            );
        }
        emit CollectionEntropyConfigured(
            collectionId, provider, configHash, collectionSalt, publicRequests, timeoutBlocks
        );
        emit CollectionEntropyEpochConfigured(1, collectionId, provider, epoch, configHash);
    }

    event RevealPolicyConfigured(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 requestMode,
        bytes32 revealOwnerRole,
        uint64 requestSLOBlocks,
        uint256 revealFeePerTokenWei
    );
    event RevealFeePerTokenUpdated(
        uint16 schemaVersion, uint256 indexed collectionId, uint256 oldFee, uint256 newFee
    );

    function configureReveal(
        IStreamCore core,
        mapping(
            uint256 => StreamEntropyCoordinator.CollectionConfig
        ) storage collectionEntropyConfig,
        mapping(
            uint256 => IStreamRevealFeeEscrow.CollectionRevealPolicy
        ) storage _revealPolicies,
        bytes calldata data
    ) public {
        (
            uint256 collectionId,
            uint8 requestMode,
            bytes32 revealOwnerRole,
            uint64 requestSLOBlocks,
            uint256 revealFeePerTokenWei
        ) = abi.decode(data, (uint256, uint8, bytes32, uint64, uint256));
        PolicyState.requireLegacy(collectionId);
        if (
            !core.collectionExists(collectionId)
                || collectionEntropyConfig[collectionId].provider == address(0)
        ) {
            revert StreamEntropyCoordinator.InvalidCollection(collectionId);
        }
        if (
            collectionEntropyConfig[collectionId].locked
                || core.collectionFreezeStatus(collectionId)
        ) {
            revert StreamEntropyCoordinator.PolicyLocked(collectionId);
        }
        if (
            requestMode > 1 || revealOwnerRole != keccak256("ROLE_ENTROPY_REVEAL_OWNER")
                || requestSLOBlocks == 0
        ) {
            revert StreamEntropyCoordinator.InvalidRevealPolicy(collectionId);
        }
        StreamEntropyCoordinatorReads.validateRevealFee(
            collectionEntropyConfig[collectionId], revealFeePerTokenWei
        );
        _revealPolicies[collectionId] = IStreamRevealFeeEscrow.CollectionRevealPolicy(
            true, requestMode, revealOwnerRole, requestSLOBlocks, revealFeePerTokenWei
        );
        emit RevealPolicyConfigured(
            1, collectionId, requestMode, revealOwnerRole, requestSLOBlocks, revealFeePerTokenWei
        );
    }

    function updateFee(
        mapping(
            uint256 => StreamEntropyCoordinator.CollectionConfig
        ) storage collectionEntropyConfig,
        mapping(
            uint256 => IStreamRevealFeeEscrow.CollectionRevealPolicy
        ) storage _revealPolicies,
        uint256 collectionId,
        uint256 next
    ) public {
        IStreamRevealFeeEscrow.CollectionRevealPolicy storage policy = _revealPolicies[collectionId];
        if (!policy.declared) revert StreamEntropyCoordinator.RevealPolicyUndeclared(collectionId);
        StreamEntropyCoordinatorReads.validateRevealFee(collectionEntropyConfig[collectionId], next);
        uint256 previous = policy.revealFeePerTokenWei;
        policy.revealFeePerTokenWei = next;
        emit RevealFeePerTokenUpdated(1, collectionId, previous, next);
    }
}
