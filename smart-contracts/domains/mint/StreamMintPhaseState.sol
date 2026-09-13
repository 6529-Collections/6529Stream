// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamMintManager.sol";
import "./StreamMintArtistConsent.sol";
import "./StreamMintGateValidator.sol";
import "./StreamMintOperationIdentity.sol";

/// @notice Linked configuration and bookkeeping for Manager-owned phase state.
/// @dev Delegatecalls retain Manager storage, msg.sender and event emitter. Public
///      owner/reentrancy checks stay in Manager; configuration invokes full artist
///      consent before Ledger registration and every failure rolls back all writes.
library StreamMintPhaseState {
    struct PhaseState {
        bool exists;
        IStreamMintManager.MintPhaseConfig config;
    }

    struct ConfigurationContext {
        StreamMintOperationIdentity.PolicyContext policy;
        address core;
        uint256 artistGasLimit;
        uint32 maxBatchQuantity;
        uint16 maxCounters;
    }
    uint16 private constant SCHEMA_VERSION = 1;

    /// @notice Adds/removes one executor, returning false for an unchanged authorization.
    /// @dev Manager owns admission and performs consent-gated policy registration after this write.
    function setExecutor(
        mapping(address => bool) storage authorized,
        address[] storage executors,
        mapping(address => uint256) storage indexPlusOne,
        address executor,
        bool allowed,
        uint16 maxExecutors
    ) external returns (bool changed) {
        if (executor == address(0)) {
            revert IStreamMintManager.InvalidMintExecutor(executor);
        }
        if (authorized[executor] == allowed) return false;
        authorized[executor] = allowed;
        if (allowed) {
            uint256 count = executors.length;
            if (count >= maxExecutors) {
                revert IStreamMintManager.MintExecutorCountLimitExceeded(count + 1, maxExecutors);
            }
            indexPlusOne[executor] = count + 1;
            executors.push(executor);
        } else {
            uint256 position = indexPlusOne[executor];
            if (position != 0) {
                uint256 index = position - 1;
                address last = executors[executors.length - 1];
                if (index != executors.length - 1) {
                    executors[index] = last;
                    indexPlusOne[last] = position;
                }
                executors.pop();
                delete indexPlusOne[executor];
            }
        }
        return true;
    }

    event MintPhaseConfigured(
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 indexed policyHash,
        uint64 startTime,
        uint64 endTime,
        uint32 maxBatchQuantity,
        bytes32 configHash,
        bytes32 metadataHash,
        address admin
    );

    event MintCounterConfigured(
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 indexed counterId,
        IStreamMintManager.CounterKeyMode keyMode,
        IStreamMintLedger.CounterCapMode capMode,
        IStreamMintLedger.CounterDeltaMode deltaMode,
        uint64 staticCap,
        uint64 staticIncrement,
        bytes32 counterConfigHash,
        bytes32 policyHash
    );

    event MintPhaseGateConfigured(
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        address indexed gate,
        bytes32 gateConfigHash,
        bytes32 gateCodehash,
        bytes32 gateMetadataHash,
        uint32 gateSemanticVersion,
        uint32 gateGasLimit,
        bytes32 policyHash
    );

    event MintPhaseConsentRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 indexed policyHash,
        uint8 consentMode,
        bytes32 consentEvidenceHash
    );

    /// @notice Validates, stores and registers one newly admitted phase atomically.
    /// @dev Only Manager supplies storage/context after checking owner, reentrancy and phase identity.
    function configure(
        PhaseState storage phaseState,
        mapping(bytes32 => IStreamMintManager.MintGateConfig) storage storedGates,
        bytes32[] storage storedIds,
        mapping(bytes32 => IStreamMintManager.MintCounterConfig) storage storedCounters,
        address[] storage executors,
        mapping(bytes32 => bytes32) storage policyHashes,
        IStreamMintManager.MintPhaseConfig calldata config,
        IStreamMintManager.MintGateConfig calldata gateConfig,
        bytes32[] calldata counterIds,
        IStreamMintManager.MintCounterConfig[] calldata counterConfigs,
        ConfigurationContext memory context
    ) external returns (bytes32 policyHash) {
        uint256 collectionId = context.policy.collectionId;
        bytes32 phaseId = context.policy.phaseId;
        _requirePhaseConfig(collectionId, phaseId, config, context.maxBatchQuantity);
        if (counterIds.length == 0 || counterIds.length != counterConfigs.length) {
            revert IStreamMintManager.MintArrayLengthMismatch();
        }
        if (counterIds.length > context.maxCounters) {
            revert IStreamMintManager.MintCounterCountLimitExceeded(
                counterIds.length, context.maxCounters
            );
        }

        bytes32[] memory ids = _copyCounterIds(counterIds);
        IStreamMintLedger.LedgerCounterPolicy[] memory ledgerPolicies =
            new IStreamMintLedger.LedgerCounterPolicy[](counterIds.length);
        for (uint256 i = 0; i < counterIds.length; i++) {
            _requireNoDuplicateCounterId(counterIds, i);
            _requireStaticCounterConfig(counterIds[i], counterConfigs[i]);
            ledgerPolicies[i] = _ledgerPolicy(counterConfigs[i]);
        }
        IStreamMintManager.MintGateConfig memory validatedGateConfig =
            StreamMintGateValidator.validateConfiguration(
                gateConfig, IERC165(context.policy.moduleRegistry)
            );

        _replacePhaseCounters(storedIds, storedCounters, ids, counterConfigs);
        storedGates[phaseId] = validatedGateConfig;
        phaseState.exists = true;
        phaseState.config = config;

        policyHash = StreamMintOperationIdentity.computePolicyHash(
            config, validatedGateConfig, ids, counterConfigs, executors, context.policy
        );
        (uint8 mode, bytes32 evidence) = StreamMintArtistConsent.registration(
            context.core, collectionId, phaseId, policyHash, context.artistGasLimit
        );
        emit MintPhaseConsentRecorded(
            SCHEMA_VERSION, collectionId, phaseId, policyHash, mode, evidence
        );
        policyHashes[phaseId] = policyHash;
        IStreamMintLedger(context.policy.ledger)
            .registerPhasePolicy(
                address(this), collectionId, phaseId, policyHash, ids, ledgerPolicies, 0
            );

        _emitPhaseConfigured(collectionId, phaseId, config, policyHash);
        for (uint256 i = 0; i < counterIds.length; i++) {
            _emitCounterConfigured(
                collectionId, phaseId, counterIds[i], counterConfigs[i], policyHash
            );
        }
        _emitGateConfigured(collectionId, phaseId, validatedGateConfig, policyHash);
    }

    function _copyCounterIds(bytes32[] calldata counterIds)
        private
        pure
        returns (bytes32[] memory ids)
    {
        ids = new bytes32[](counterIds.length);
        for (uint256 i = 0; i < counterIds.length; i++) {
            ids[i] = counterIds[i];
        }
    }

    function _ledgerPolicy(IStreamMintManager.MintCounterConfig memory config)
        private
        pure
        returns (IStreamMintLedger.LedgerCounterPolicy memory)
    {
        return IStreamMintLedger.LedgerCounterPolicy({
            enabled: config.enabled,
            capMode: config.capMode,
            deltaMode: config.deltaMode,
            staticCap: config.staticCap,
            staticIncrement: config.staticIncrement,
            counterConfigHash: config.counterConfigHash
        });
    }

    function _requirePhaseConfig(
        uint256 collectionId,
        bytes32 phaseId,
        IStreamMintManager.MintPhaseConfig calldata config,
        uint32 maximum
    ) private pure {
        if (config.endTime != 0 && config.startTime != 0 && config.endTime < config.startTime) {
            revert IStreamMintManager.InvalidMintPhase(collectionId, phaseId);
        }
        if (config.maxBatchQuantity == 0 || config.maxBatchQuantity > maximum) {
            revert IStreamMintManager.InvalidMintBatchLimit(config.maxBatchQuantity, maximum);
        }
    }

    function _requireNoDuplicateCounterId(bytes32[] calldata counterIds, uint256 index)
        private
        pure
    {
        bytes32 counterId = counterIds[index];
        if (counterId == bytes32(0)) {
            revert IStreamMintManager.InvalidMintCounter(counterId);
        }
        for (uint256 i = 0; i < index; i++) {
            if (counterIds[i] == counterId) {
                revert IStreamMintManager.DuplicateMintCounter(counterId);
            }
        }
    }

    function _requireStaticCounterConfig(
        bytes32 counterId,
        IStreamMintManager.MintCounterConfig calldata config
    ) private pure {
        if (
            !config.enabled || config.keyMode == IStreamMintManager.CounterKeyMode.UNKNOWN
                || config.staticIncrement == 0 || config.counterConfigHash == bytes32(0)
        ) {
            revert IStreamMintManager.InvalidMintCounter(counterId);
        }
        if (
            config.deltaMode != IStreamMintLedger.CounterDeltaMode.STATIC
                || config.capMode == IStreamMintLedger.CounterCapMode.RESOLVER
        ) {
            revert IStreamMintManager.UnsupportedMintCounterMode(counterId);
        }
        if (config.capMode == IStreamMintLedger.CounterCapMode.STATIC && config.staticCap == 0) {
            revert IStreamMintManager.InvalidMintCounter(counterId);
        }
        if (config.capMode == IStreamMintLedger.CounterCapMode.NONE && config.staticCap != 0) {
            revert IStreamMintManager.InvalidMintCounter(counterId);
        }
    }

    function _emitCounterConfigured(
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 counterId,
        IStreamMintManager.MintCounterConfig calldata config,
        bytes32 policyHash
    ) private {
        emit MintCounterConfigured(
            collectionId,
            phaseId,
            counterId,
            config.keyMode,
            config.capMode,
            config.deltaMode,
            config.staticCap,
            config.staticIncrement,
            config.counterConfigHash,
            policyHash
        );
    }

    function _emitPhaseConfigured(
        uint256 collectionId,
        bytes32 phaseId,
        IStreamMintManager.MintPhaseConfig calldata config,
        bytes32 policyHash
    ) private {
        emit MintPhaseConfigured(
            collectionId,
            phaseId,
            policyHash,
            config.startTime,
            config.endTime,
            config.maxBatchQuantity,
            config.configHash,
            config.metadataHash,
            msg.sender
        );
    }

    function _emitGateConfigured(
        uint256 collectionId,
        bytes32 phaseId,
        IStreamMintManager.MintGateConfig memory gateConfig,
        bytes32 policyHash
    ) private {
        emit MintPhaseGateConfigured(
            collectionId,
            phaseId,
            gateConfig.gate,
            gateConfig.gateConfigHash,
            gateConfig.gateCodehash,
            gateConfig.gateMetadataHash,
            gateConfig.gateSemanticVersion,
            gateConfig.gateGasLimit,
            policyHash
        );
    }

    function _replacePhaseCounters(
        bytes32[] storage existing,
        mapping(bytes32 => IStreamMintManager.MintCounterConfig) storage stored,
        bytes32[] memory ids,
        IStreamMintManager.MintCounterConfig[] calldata configs
    ) private {
        for (uint256 i; i < existing.length; ++i) {
            delete stored[existing[i]];
        }
        while (existing.length != 0) existing.pop();
        for (uint256 i; i < ids.length; ++i) {
            existing.push(ids[i]);
            stored[ids[i]] = configs[i];
        }
    }

    /// @notice Hashes the exact active stored phase, counters, gate and canonical executor set.
    function computeStoredPolicyHash(
        PhaseState storage phaseState,
        IStreamMintManager.MintGateConfig storage gate,
        bytes32[] storage storedIds,
        mapping(
            bytes32 => IStreamMintManager.MintCounterConfig
        ) storage stored,
        address[] storage executors,
        StreamMintOperationIdentity.PolicyContext memory context
    ) external view returns (bytes32) {
        bytes32[] memory ids = storedIds;
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            configs[i] = stored[ids[i]];
        }
        return StreamMintOperationIdentity.computePolicyHash(
            phaseState.config, gate, ids, configs, executors, context
        );
    }
}
