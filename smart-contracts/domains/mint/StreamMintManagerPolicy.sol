// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintPhaseState.sol";
import "./StreamMintManagerAccounting.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Original consent-gated policy refresh through a fixed linked boundary.
/// @dev Manager retains owner/reentrancy and configured-phase admission.
/// Delegatecall keeps its storage, identity and event emitter; the artist cap is
/// read from the actual Manager at the original post-hash consent phase.
library StreamMintManagerPolicy {
    struct Context {
        StreamMintOperationIdentity.PolicyContext policy;
        address core;
    }

    struct ExecutorUpdate {
        Context context;
        address executor;
        bool allowed;
        uint64 graceUntil;
        uint16 maxExecutors;
    }

    uint16 private constant SCHEMA_VERSION = 1;
    bytes32 private constant GGP_ARTIST_AUTHORITY_GAS_LIMIT =
        keccak256("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT");

    event MintPhaseConsentRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 indexed policyHash,
        uint8 consentMode,
        bytes32 consentEvidenceHash
    );

    event MintPhaseExecutorUpdated(
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        address indexed executor,
        bool allowed,
        bytes32 policyHash,
        address admin
    );

    event MintPhasePausedEvent(
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bool paused,
        bytes32 policyHash,
        address admin
    );

    /// @dev The guarded facade admits an existing phase; no policy hash or grace changes here.
    function pause(
        StreamMintPhaseState.PhaseState storage phase,
        uint256 collectionId,
        bytes32 phaseId,
        bool paused,
        bytes32 policyHash
    ) external {
        if (phase.config.paused == paused) return;
        phase.config.paused = paused;
        emit MintPhasePausedEvent(collectionId, phaseId, paused, policyHash, msg.sender);
    }

    /// @notice Applies one original executor mutation and consented policy refresh atomically.
    /// @dev All storage references and the maximum originate at the guarded Manager entrypoint.
    function updateExecutor(
        StreamMintPhaseState.PhaseState storage phaseState,
        IStreamMintManager.MintGateConfig storage gate,
        bytes32[] storage counterIds,
        mapping(bytes32 => IStreamMintManager.MintCounterConfig) storage counters,
        mapping(address => bool) storage authorized,
        address[] storage executors,
        mapping(address => uint256) storage indexPlusOne,
        mapping(bytes32 => bytes32) storage policyHashes,
        ExecutorUpdate memory update
    ) external {
        if (update.executor == address(0)) {
            revert IStreamMintManager.InvalidMintExecutor(update.executor);
        }
        if (
            update.allowed && !authorized[update.executor]
                && StreamMintPhaseFreezeControl.frozen(
                    update.context.policy.ledger,
                    address(this),
                    update.context.policy.collectionId,
                    update.context.policy.phaseId
                )
        ) {
            revert IStreamMintPhaseFreeze.MintPhaseFrozenExecutor(
                update.context.policy.collectionId, update.context.policy.phaseId, update.executor
            );
        }
        if (!StreamMintPhaseState.setExecutor(
                authorized,
                executors,
                indexPlusOne,
                update.executor,
                update.allowed,
                update.maxExecutors
            )) {
            if (update.graceUntil != 0) {
                revert IStreamMintLedger.InvalidPolicyGrace(update.graceUntil);
            }
            return;
        }
        bytes32 policyHash = _refresh(
            phaseState,
            gate,
            counterIds,
            counters,
            executors,
            policyHashes,
            update.context,
            update.graceUntil
        );
        emit MintPhaseExecutorUpdated(
            update.context.policy.collectionId,
            update.context.policy.phaseId,
            update.executor,
            update.allowed,
            policyHash,
            msg.sender
        );
    }

    function _refresh(
        StreamMintPhaseState.PhaseState storage phaseState,
        IStreamMintManager.MintGateConfig storage gate,
        bytes32[] storage counterIds,
        mapping(bytes32 => IStreamMintManager.MintCounterConfig) storage counters,
        address[] storage executors,
        mapping(bytes32 => bytes32) storage policyHashes,
        Context memory x,
        uint64 graceUntil
    ) private returns (bytes32 policyHash) {
        uint256 collectionId = x.policy.collectionId;
        bytes32 phaseId = x.policy.phaseId;
        (bytes32[] memory ids, IStreamMintLedger.LedgerCounterPolicy[] memory ledgerPolicies) =
            StreamMintManagerAccounting.ledgerPolicies(counterIds, counters);
        policyHash = _computePolicyHash(phaseState, gate, counterIds, counters, executors, x);
        _recordArtistConsent(collectionId, phaseId, policyHash, x);
        policyHashes[phaseId] = policyHash;
        IStreamMintLedger(x.policy.ledger)
            .registerPhasePolicy(
                address(this), collectionId, phaseId, policyHash, ids, ledgerPolicies, graceUntil
            );
    }

    function _recordArtistConsent(
        uint256 collectionId,
        bytes32 phaseId,
        bytes32 policyHash,
        Context memory x
    ) private {
        (uint8 mode, bytes32 evidence) = StreamMintArtistConsent.registration(
            x.core,
            collectionId,
            phaseId,
            policyHash,
            IStreamGasParameterHost(address(this)).gasParameter(GGP_ARTIST_AUTHORITY_GAS_LIMIT)
        );
        emit MintPhaseConsentRecorded(
            SCHEMA_VERSION, collectionId, phaseId, policyHash, mode, evidence
        );
    }

    function _computePolicyHash(
        StreamMintPhaseState.PhaseState storage phaseState,
        IStreamMintManager.MintGateConfig storage gate,
        bytes32[] storage counterIds,
        mapping(bytes32 => IStreamMintManager.MintCounterConfig) storage counters,
        address[] storage executors,
        Context memory x
    ) private view returns (bytes32) {
        return StreamMintPhaseState.computeStoredPolicyHash(
            phaseState, gate, counterIds, counters, executors, x.policy
        );
    }
}
