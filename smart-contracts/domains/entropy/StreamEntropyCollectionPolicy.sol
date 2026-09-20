// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamEntropyCoordinator.sol";
import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import { IStreamEntropyEpochs } from "../../interfaces/stream/entropy/IStreamEntropyEpochs.sol";
import { StreamEntropyCoordinatorReads } from "./StreamEntropyCoordinatorReads.sol";
import { StreamEntropyCollectionRecovery } from "./StreamEntropyCollectionRecovery.sol";
import { StreamEntropyRecoveryPolicies } from "./StreamEntropyRecoveryPolicies.sol";
import { StreamEntropyProviderLifecycle } from "./StreamEntropyProviderLifecycle.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamEntropyCollectionRecovery as C
} from "../../interfaces/stream/entropy/IStreamEntropyCollectionRecovery.sol";
import {
    IStreamRevealFeeEscrow as F
} from "../../interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";
import { StreamEntropyCollectionPolicyState as S } from "./StreamEntropyCollectionPolicyState.sol";
import {
    StreamEntropyCollectionPolicyAuthority as A
} from "./StreamEntropyCollectionPolicyAuthority.sol";

/// @notice Fixed V2 policy worker. Content commitments never include operational fees or live availability.
library StreamEntropyCollectionPolicy {
    bytes32 private constant POLICY = keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_V2");
    bytes32 private constant SCOPE = keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_SCOPE_V1");
    bytes32 private constant STATE = keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_STATE_V1");

    struct Prepared {
        StreamEntropyCoordinator.CollectionConfig config;
        F.CollectionRevealPolicy reveal;
        C.CollectionRecovery recovery;
        S.Entry entry;
        uint32 epoch;
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        bytes32 contentState;
    }
    event CollectionEntropyPolicyConfigured(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed policyHash,
        uint64 revision,
        uint32 providerEpoch,
        P.PolicyInput policy,
        bytes32 providerCodeHash,
        bytes32 providerConfigHash,
        bytes32 recoveryPolicyHash,
        bytes32 actionId,
        bytes32 artistConsentRecord
    );
    event CollectionEntropyPolicyFrozen(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed policyHash,
        uint64 revision,
        bytes32 actionId,
        bytes32 artistConsentRecord
    );

    function record(
        IStreamCore core,
        uint256 id,
        StreamEntropyCoordinator.CollectionConfig storage config,
        F.CollectionRevealPolicy storage reveal,
        uint32 epoch
    ) public view returns (P.PolicyRecord memory r) {
        S.Entry storage e = S.store().entries[id];
        r.explicitPolicy = e.revision != 0;
        r.configured = r.explicitPolicy || config.provider != address(0);
        r.frozen = config.locked;
        r.mode = r.explicitPolicy ? e.mode : P.Mode.ASYNC;
        r.securityClass = r.explicitPolicy ? e.securityClass : P.SecurityClass.HIGH_ASSURANCE;
        r.renderRequirement = r.explicitPolicy ? e.renderRequirement : P.RenderRequirement.REQUIRED;
        r.revision = e.revision;
        r.providerEpoch = epoch;
        r.lastActionId = e.lastActionId;
        r.artistConsentRecord = e.artistConsentRecord;
        if (r.explicitPolicy) {
            r.policyHash = e.policyHash;
        } else {
            (, r.policyHash,,,) =
                StreamEntropyCoordinatorReads.policy(core, id, config, reveal, epoch);
        }
        r.contentStateHash = S.contentState(r.policyHash, r.frozen);
    }

    function read(
        IStreamCore core,
        mapping(uint256 => StreamEntropyCoordinator.CollectionConfig) storage configs,
        mapping(uint256 => uint32) storage epochs,
        mapping(uint256 => F.CollectionRevealPolicy) storage reveals,
        mapping(uint256 => uint256) storage escrows,
        bytes calldata data
    ) public view returns (bytes memory) {
        bytes4 selector = bytes4(data[:4]);
        if (selector == P.collectionEntropyPolicy.selector) {
            uint256 id = abi.decode(data[4:], (uint256));
            return abi.encode(record(core, id, configs[id], reveals[id], epochs[id]));
        }
        Prepared memory p;
        if (selector == P.collectionEntropyPolicyTransition.selector) {
            (uint256 id, P.PolicyInput memory input) =
                abi.decode(data[4:], (uint256, P.PolicyInput));
            p = _prepare(core, id, configs[id], epochs[id], reveals[id], escrows[id], input);
        } else if (selector == P.freezeCollectionEntropyPolicyTransition.selector) {
            uint256 id = abi.decode(data[4:], (uint256));
            p = _freeze(core, id, configs[id], epochs[id], reveals[id]);
        } else {
            revert P.InvalidCollectionPolicy(0);
        }
        return abi.encode(p.scope, p.oldHash, p.newHash, p.contentState);
    }

    function write(
        IStreamCore core,
        address authority,
        mapping(uint256 => StreamEntropyCoordinator.CollectionConfig) storage configs,
        mapping(uint256 => uint32) storage epochs,
        mapping(uint256 => F.CollectionRevealPolicy) storage reveals,
        mapping(uint256 => uint256) storage escrows,
        bytes calldata data
    ) public {
        bytes4 selector = bytes4(data[:4]);
        if (selector == P.configureCollectionEntropyPolicy.selector) {
            configure(core, authority, configs, epochs, reveals, escrows, data[4:]);
        } else if (selector == P.freezeCollectionEntropyPolicy.selector) {
            freeze(core, authority, configs, epochs, reveals, abi.decode(data[4:], (uint256)));
        } else {
            revert P.InvalidCollectionPolicy(0);
        }
    }

    function configure(
        IStreamCore core,
        address authority,
        mapping(uint256 => StreamEntropyCoordinator.CollectionConfig) storage configs,
        mapping(uint256 => uint32) storage epochs,
        mapping(uint256 => F.CollectionRevealPolicy) storage reveals,
        mapping(uint256 => uint256) storage escrows,
        bytes calldata data
    ) private {
        (uint256 id, P.PolicyInput memory input) = abi.decode(data, (uint256, P.PolicyInput));
        Prepared memory p =
            _prepare(core, id, configs[id], epochs[id], reveals[id], escrows[id], input);
        _authorize(core, authority, id, p, 1);
        configs[id] = p.config;
        epochs[id] = p.epoch;
        reveals[id] = p.reveal;
        C.CollectionRecovery memory previous = StreamEntropyCollectionRecovery.record(id);
        if (previous.revision != p.recovery.revision) {
            StreamEntropyCollectionRecovery.applyExplicit(id, p.recovery, p.entry.lastActionId);
        }
        S.store().entries[id] = p.entry;
        emit CollectionEntropyPolicyConfigured(
            2,
            id,
            p.entry.policyHash,
            p.entry.revision,
            p.epoch,
            input,
            p.config.providerCodeHash,
            p.config.providerConfigHash,
            p.recovery.policyHash,
            p.entry.lastActionId,
            p.entry.artistConsentRecord
        );
    }

    function freeze(
        IStreamCore core,
        address authority,
        mapping(uint256 => StreamEntropyCoordinator.CollectionConfig) storage configs,
        mapping(uint256 => uint32) storage epochs,
        mapping(uint256 => F.CollectionRevealPolicy) storage reveals,
        uint256 id
    ) private {
        Prepared memory p = _freeze(core, id, configs[id], epochs[id], reveals[id]);
        _authorize(core, authority, id, p, 2);
        configs[id].locked = true;
        S.store().entries[id] = p.entry;
        emit CollectionEntropyPolicyFrozen(
            2,
            id,
            p.entry.policyHash,
            p.entry.revision,
            p.entry.lastActionId,
            p.entry.artistConsentRecord
        );
    }

    function _authorize(
        IStreamCore core,
        address authority,
        uint256 id,
        Prepared memory p,
        uint8 actionClass
    ) private {
        p.entry.lastActionId = StreamEntropyRecoveryPolicies.requireActionClass(
            authority, p.scope, p.oldHash, p.newHash, actionClass
        );
        S.Store storage s = S.store();
        if (s.actions[id][p.entry.lastActionId]) {
            revert P.CollectionPolicyReplay(p.entry.lastActionId);
        }
        A.requireGovernance(core, authority);
        p.entry.artistConsentRecord = A.evidence(core, id, p.contentState);
        if (s.consents[p.entry.artistConsentRecord]) {
            revert P.CollectionPolicyReplay(p.entry.artistConsentRecord);
        }
        s.actions[id][p.entry.lastActionId] = true;
        s.consents[p.entry.artistConsentRecord] = true;
    }

    function _mutable(
        IStreamCore core,
        uint256 id,
        StreamEntropyCoordinator.CollectionConfig storage config
    ) private view {
        if (!core.collectionExists(id)) revert P.InvalidCollectionPolicy(id);
        A.requireSelected(core);
        if (config.locked || core.collectionFreezeStatus(id) || core.collectionMintedEver(id) != 0)
        {
            revert StreamEntropyCoordinator.PolicyLocked(id);
        }
        if (S.store().entries[id].revision == type(uint64).max) {
            revert P.InvalidCollectionPolicy(id);
        }
    }

    function _prepare(
        IStreamCore core,
        uint256 id,
        StreamEntropyCoordinator.CollectionConfig storage prior,
        uint32 epoch,
        F.CollectionRevealPolicy storage reveal,
        uint256 escrow,
        P.PolicyInput memory input
    ) private view returns (Prepared memory p) {
        _mutable(core, id, prior);
        if (input.mode == P.Mode.INSTANT) revert P.UnsupportedEntropyMode(input.mode);
        p.reveal = input.reveal;
        p.config = StreamEntropyCoordinator.CollectionConfig(
            input.provider,
            input.publicRequests,
            false,
            input.timeoutBlocks,
            0,
            0,
            input.collectionSalt
        );
        if (input.mode == P.Mode.DISABLED) {
            if (
                input.renderRequirement != P.RenderRequirement.NOT_REQUIRED
                    || input.provider != address(0) || input.collectionSalt != 0
                    || input.publicRequests || input.timeoutBlocks != 0 || input.reveal.declared
                    || input.reveal.requestMode != 0 || input.reveal.revealOwnerRole != 0
                    || input.reveal.requestSLOBlocks != 0 || input.reveal.revealFeePerTokenWei != 0
                    || input.maxFreshRecoveryAttempts != 0 || input.recoveryPolicyId != 0
            ) revert P.InvalidCollectionPolicy(id);
            if (escrow != 0) revert P.CollectionPolicyEscrowOutstanding(id);
        } else {
            p.config.providerConfigHash = StreamEntropyCoordinatorReads.providerConfiguration(
                input.provider, input.timeoutBlocks
            );
            p.config.providerCodeHash = input.provider.codehash;
            StreamEntropyProviderLifecycle.requireActive(input.provider);
            if (
                !input.reveal.declared || input.reveal.requestMode > 1
                    || input.reveal.revealOwnerRole != keccak256("ROLE_ENTROPY_REVEAL_OWNER")
                    || input.reveal.requestSLOBlocks == 0
            ) revert P.InvalidCollectionPolicy(id);
            StreamEntropyCoordinatorReads.validateRevealFeeValue(
                p.config, input.reveal.revealFeePerTokenWei
            );
        }
        p.recovery = StreamEntropyCollectionRecovery.record(id);
        C.CollectionRecovery memory priorRecovery = StreamEntropyCollectionRecovery.record(id);
        (, bytes32 recoveryHash,,) = StreamEntropyRecoveryPolicies.record(input.recoveryPolicyId);
        if (input.maxFreshRecoveryAttempts == 0) recoveryHash = 0;
        bool recoveryChanged = p.recovery.policyId != input.recoveryPolicyId
            || p.recovery.policyHash != recoveryHash
            || p.recovery.maxFreshRecoveryAttempts != input.maxFreshRecoveryAttempts;
        bool changedProvider = prior.provider != input.provider
            || prior.providerConfigHash != p.config.providerConfigHash;
        p.epoch = epoch;
        if (changedProvider || recoveryChanged) {
            if (epoch == type(uint32).max) revert IStreamEntropyEpochs.ProviderEpochOverflow(id);
            p.epoch = epoch + 1;
        }
        p.recovery.policyHash = StreamEntropyCollectionRecovery.validateExplicit(
            id, input.recoveryPolicyId, input.maxFreshRecoveryAttempts, p.epoch
        );
        p.recovery.policyId = input.recoveryPolicyId;
        p.recovery.maxFreshRecoveryAttempts = input.maxFreshRecoveryAttempts;
        if (recoveryChanged) {
            if (p.recovery.revision == type(uint64).max) revert P.InvalidCollectionPolicy(id);
            ++p.recovery.revision;
        }
        S.Entry memory oldEntry = S.store().entries[id];
        p.entry = S.store().entries[id];
        p.entry.revision = oldEntry.revision + 1;
        p.entry.mode = input.mode;
        p.entry.securityClass = input.securityClass;
        p.entry.renderRequirement = input.renderRequirement;
        p.entry.policyHash = _hash(core, id, p);
        // Fees alone have their existing operational entry and never consume content consent.
        if (oldEntry.revision != 0 && oldEntry.policyHash == p.entry.policyHash) {
            revert P.InvalidCollectionPolicy(id);
        }
        p.scope = _scope(core, id, P.configureCollectionEntropyPolicy.selector);
        p.oldHash = _state(p.scope, prior, epoch, reveal, priorRecovery, oldEntry);
        p.newHash = _state(p.scope, p.config, p.epoch, p.reveal, p.recovery, p.entry);
        p.contentState = S.contentState(p.entry.policyHash, false);
    }

    function _freeze(
        IStreamCore core,
        uint256 id,
        StreamEntropyCoordinator.CollectionConfig storage config,
        uint32 epoch,
        F.CollectionRevealPolicy storage reveal
    ) private view returns (Prepared memory p) {
        _mutable(core, id, config);
        S.Entry memory previous = S.store().entries[id];
        if (previous.revision == 0) revert P.ExplicitCollectionPolicyRequired(id);
        p.entry = S.store().entries[id];
        ++p.entry.revision;
        p.config = config;
        p.reveal = reveal;
        p.epoch = epoch;
        p.recovery = StreamEntropyCollectionRecovery.record(id);
        p.scope = _scope(core, id, P.freezeCollectionEntropyPolicy.selector);
        p.oldHash = _state(p.scope, config, epoch, reveal, p.recovery, previous);
        p.config.locked = true;
        p.newHash = _state(p.scope, p.config, epoch, reveal, p.recovery, p.entry);
        p.contentState = S.contentState(p.entry.policyHash, true);
    }

    function _scope(IStreamCore core, uint256 id, bytes4 selector) private view returns (bytes32) {
        return
            keccak256(abi.encode(SCOPE, block.chainid, address(this), address(core), id, selector));
    }

    function _state(
        bytes32 scope,
        StreamEntropyCoordinator.CollectionConfig memory config,
        uint32 epoch,
        F.CollectionRevealPolicy memory reveal,
        C.CollectionRecovery memory recovery,
        S.Entry memory entry
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                STATE,
                scope,
                config,
                epoch,
                reveal,
                recovery.policyId,
                recovery.policyHash,
                recovery.maxFreshRecoveryAttempts,
                recovery.revision,
                entry.revision,
                entry.mode,
                entry.securityClass,
                entry.renderRequirement,
                entry.policyHash
            )
        );
    }

    function _hash(IStreamCore core, uint256 id, Prepared memory p) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                POLICY,
                block.chainid,
                address(this),
                address(core),
                id,
                p.entry.mode,
                p.entry.securityClass,
                p.entry.renderRequirement,
                p.config.provider,
                p.config.providerCodeHash,
                p.config.providerConfigHash,
                p.epoch,
                p.config.collectionSalt,
                p.config.publicRequests,
                p.config.timeoutBlocks,
                p.reveal.declared,
                p.reveal.requestMode,
                p.reveal.revealOwnerRole,
                p.reveal.requestSLOBlocks,
                p.recovery.policyId,
                p.recovery.policyHash,
                p.recovery.maxFreshRecoveryAttempts
            )
        );
    }
}
