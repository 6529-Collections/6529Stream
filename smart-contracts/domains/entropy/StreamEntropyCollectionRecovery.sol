// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamEntropyCoordinator.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import {
    IStreamEntropyCollectionRecovery as C
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionRecovery.sol";
import {
    IStreamEntropyRecoveryPolicies as R
} from "../../interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import {
    IStreamEntropyEpochs as E
} from "../../interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import { StreamEntropyRecoveryPolicies } from "./StreamEntropyRecoveryPolicies.sol";
import { StreamEntropyProviderLifecycle } from "./StreamEntropyProviderLifecycle.sol";

/// @notice Fixed binding worker; namespace is separate from original collection storage.
library StreamEntropyCollectionRecovery {
    bytes32 private constant SLOT = keccak256("6529STREAM_ENTROPY_COLLECTION_RECOVERY_STORAGE_V1");
    bytes32 private constant SCOPE = keccak256("6529STREAM_ENTROPY_COLLECTION_RECOVERY_SCOPE_V1");
    bytes32 private constant STATE = keccak256("6529STREAM_ENTROPY_COLLECTION_RECOVERY_STATE_V1");

    struct Store {
        mapping(uint256 => C.CollectionRecovery) bindings;
        mapping(uint256 => mapping(bytes32 => bool)) consumed;
    }
    event CollectionFreshRecoveryConfigured(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed policyId,
        bytes32 policyHash,
        uint16 maxFreshRecoveryAttempts,
        uint32 providerEpoch,
        uint64 revision,
        bytes32 actionId
    );
    event CollectionEntropyEpochConfigured(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed provider,
        uint32 providerEpoch,
        bytes32 providerConfigHash
    );

    function store() private pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function record(uint256 id) public view returns (C.CollectionRecovery memory) {
        return store().bindings[id];
    }

    function validateEpoch(uint256 id, uint32 epoch) public view {
        C.CollectionRecovery storage b = store().bindings[id];
        if (b.maxFreshRecoveryAttempts != 0) {
            _policy(id, b.policyId, b.maxFreshRecoveryAttempts, epoch, false);
        }
    }

    function _policy(uint256 id, bytes32 policyId, uint16 attempts, uint32 epoch, bool active)
        private
        view
        returns (bytes32 hash)
    {
        if (attempts == 0) {
            if (policyId != 0) revert C.InvalidCollectionRecovery(id);
            return bytes32(0);
        }
        (R.FreshRecoveryPolicy memory p, bytes32 saved,,) =
            StreamEntropyRecoveryPolicies.record(policyId);
        if (
            !p.exists || !p.frozen || attempts > p.maxFreshRecoveryAttempts
                || attempts > p.steps.length || saved == 0
        ) {
            revert C.InvalidCollectionRecovery(id);
        }
        for (uint256 i; i < attempts; ++i) {
            if (p.steps[i].providerEpoch <= epoch) revert C.InvalidCollectionRecovery(id);
            epoch = p.steps[i].providerEpoch;
            if (active) StreamEntropyProviderLifecycle.requireActive(p.steps[i].provider);
        }
        return saved;
    }

    function transition(
        IStreamCore core,
        StreamEntropyCoordinator.CollectionConfig storage config,
        uint32 epoch,
        uint256 id,
        uint16 attempts,
        bytes32 policyId
    ) public view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash) {
        if (!core.collectionExists(id) || config.provider == address(0)) {
            revert C.InvalidCollectionRecovery(id);
        }
        if (config.locked || core.collectionFreezeStatus(id)) {
            revert StreamEntropyCoordinator.PolicyLocked(id);
        }
        C.CollectionRecovery storage b = store().bindings[id];
        if (epoch == type(uint32).max) revert E.ProviderEpochOverflow(id);
        bytes32 hash = _policy(id, policyId, attempts, epoch + 1, true);
        if (
            b.revision == type(uint64).max
                || (b.policyId == policyId
                    && b.policyHash == hash
                    && b.maxFreshRecoveryAttempts == attempts)
        ) {
            revert C.InvalidCollectionRecovery(id);
        }
        scope = keccak256(
            abi.encode(
                SCOPE, block.chainid, address(this), id, C.configureCollectionFreshRecovery.selector
            )
        );
        oldHash = keccak256(
            abi.encode(
                STATE,
                scope,
                config,
                epoch,
                b.policyId,
                b.policyHash,
                b.maxFreshRecoveryAttempts,
                b.revision
            )
        );
        newHash = keccak256(
            abi.encode(STATE, scope, config, epoch + 1, policyId, hash, attempts, b.revision + 1)
        );
    }

    function configure(
        address authority,
        IStreamCore core,
        mapping(uint256 => StreamEntropyCoordinator.CollectionConfig) storage configs,
        mapping(uint256 => uint32) storage epochs,
        uint256 id,
        uint16 attempts,
        bytes32 policyId
    ) public {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            transition(core, configs[id], epochs[id], id, attempts, policyId);
        bytes32 actionId =
            StreamEntropyRecoveryPolicies.requireAction(authority, scope, oldHash, newHash);
        Store storage s = store();
        if (s.consumed[id][actionId]) revert C.CollectionRecoveryReplay(id, actionId);
        s.consumed[id][actionId] = true;
        C.CollectionRecovery storage b = s.bindings[id];
        (, bytes32 hash,,) = StreamEntropyRecoveryPolicies.record(policyId);
        b.policyId = policyId;
        b.policyHash = attempts == 0 ? bytes32(0) : hash;
        b.maxFreshRecoveryAttempts = attempts;
        ++b.revision;
        b.lastActionId = actionId;
        uint32 epoch = ++epochs[id];
        emit CollectionFreshRecoveryConfigured(
            1, id, policyId, b.policyHash, attempts, epoch, b.revision, actionId
        );
        emit CollectionEntropyEpochConfigured(
            1, id, configs[id].provider, epoch, configs[id].providerConfigHash
        );
    }
}
