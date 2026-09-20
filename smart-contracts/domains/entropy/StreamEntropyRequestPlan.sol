// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/core/StreamCoreTypes.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import "./StreamEntropyCoordinatorReads.sol";
import "../../interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProvider.sol";
import "../../interfaces/stream/entropy/IStreamEntropyView.sol";
import "../../interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import "../../interfaces/stream/entropy/IStreamEntropyCollectionRecovery.sol";
import "../../interfaces/stream/entropy/IStreamEntropyProviderLifecycle.sol";

import "./StreamEntropyCoordinator.sol";
import "./StreamEntropyProviderLifecycle.sol";
import "./StreamEntropyInstantProviderReads.sol";
import {
    StreamEntropyCollectionPolicyState as PolicyState
} from "./StreamEntropyCollectionPolicyState.sol";

/// @notice Fixed request preimage and quote worker; submission and custody remain in the host.
library StreamEntropyRequestPlan {
    struct Authorization {
        IStreamCore core;
        address authority;
        IStreamRoleRegistry roleRegistry;
        bytes32 roleRegistryCodeHash;
        bool requester;
        uint256 liveRevealSLO;
    }

    /// @notice Original token identity, terminal and request authority checks in host context.
    function authorizeToken(
        Authorization memory a,
        StreamEntropyCoordinator.Subject storage subject,
        StreamEntropyCoordinator.CollectionConfig storage config,
        IStreamRevealFeeEscrow.CollectionRevealPolicy storage reveal,
        uint64 registeredAt,
        uint256 tokenId
    ) public view {
        if (
            a.core.tokenLifecycle(tokenId) != uint8(StreamTokenLifecycle.MINTED)
                || a.core.coordinatorAtMint(tokenId) != address(this)
        ) {
            revert StreamEntropyCoordinator.InvalidToken(tokenId);
        }
        if (
            subject.status == StreamEntropyStatus.DISABLED
                || subject.status == StreamEntropyStatus.NOT_REQUIRED
        ) {
            revert StreamEntropyCoordinator.InvalidStatus(subject.status);
        }
        bool instant =
            PolicyState.mode(subject.collectionId) == IStreamEntropyCollectionPolicy.Mode.INSTANT;
        if (instant && block.number <= registeredAt) {
            revert StreamEntropyCoordinator.InstantEntropyBeforeDelivery(tokenId);
        }
        // A matured ASYNC remedy stays independent of optional role reads; subtract without overflow.
        bool lapsed;
        if (
            !instant && subject.status == StreamEntropyStatus.REGISTERED
                && block.number > registeredAt
        ) {
            if (!reveal.declared) {
                revert StreamEntropyCoordinator.RevealPolicyUndeclared(subject.collectionId);
            }
            uint256 window = a.liveRevealSLO > reveal.requestSLOBlocks
                ? a.liveRevealSLO
                : reveal.requestSLOBlocks;
            lapsed = block.number - registeredAt > window;
        }
        if (
            !lapsed && msg.sender != a.authority && !a.requester && !config.publicRequests
                && !_role(a, keccak256("ROLE_ENTROPY_ADMIN"))
                && (instant || !_role(a, reveal.revealOwnerRole))
        ) {
            revert StreamEntropyCoordinator.Unauthorized(msg.sender);
        }
    }

    function _role(Authorization memory a, bytes32 role) private view returns (bool) {
        return StreamEntropyCoordinatorReads.hasRole(
            a.core, a.authority, a.roleRegistry, a.roleRegistryCodeHash, role, msg.sender
        );
    }

    struct Plan {
        bytes32 key;
        bytes context;
        uint256 fee;
        IStreamEntropyEpochs.RequestPolicySnapshot policy;
        bool instant;
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
                PolicyState.mode(subject.collectionId)
                    == IStreamEntropyCollectionPolicy.Mode.INSTANT
                    ? bytes32(0)
                    : subject.inputsHash,
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
        p.instant = PolicyState.mode(collectionId) == IStreamEntropyCollectionPolicy.Mode.INSTANT;
        if (
            policy.provider.codehash != policy.providerCodeHash
                || (p.instant
                            ? StreamEntropyInstantProviderReads.configHash(policy.provider)
                            : IStreamEntropyProvider(policy.provider)
                                .streamEntropyProviderConfigHash()) != policy.providerConfigHash
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
        if (!p.instant) p.fee = IStreamEntropyProvider(policy.provider).quoteRequest(p.context);
    }
}
