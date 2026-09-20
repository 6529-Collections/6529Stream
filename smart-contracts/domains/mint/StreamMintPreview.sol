// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamMintPreview.sol";
import "../../interfaces/stream/mint/IStreamMintReads.sol";
import "../../interfaces/stream/mint/IStreamMintPhaseFreeze.sol";
import "../../interfaces/stream/mint/IStreamMintLedgerContinuity.sol";
import "../../interfaces/stream/mint/IStreamMintLedgerImport.sol";
import "./StreamMintManagerTranscript.sol";
import "./StreamMintRoyaltyPolicy.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Fixed linked implementation of the Manager's advisory read capability.
/// @dev The bounded self-STATICCALL catches failure without changing the gate's actual caller.
/// The self-call branch evaluates once; it never dispatches another self-call. All executor
/// semantics use the explicit argument. No result is an execution authorization or identity.
library StreamMintPreview {
    uint256 private constant MAX_ROWS = 160; // Original 16 counters times 10 tokens.
    uint256 private constant MAX_RESULT_BYTES = 256 + MAX_ROWS * 288;
    uint256 private constant RETURN_GAS_RESERVE = 100_000;
    bytes32 private constant ARTIST_GAS = keccak256("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT");

    struct Phase {
        IStreamMintManager.MintPhaseConfig config;
        IStreamMintManager.MintGateConfig gate;
        bytes32[] ids;
        IStreamMintManager.MintCounterConfig[] counters;
    }

    function read(
        IStreamMintManager.MintBatch calldata batch,
        address executor,
        bytes calldata gateData
    ) external view returns (bytes memory encoded) {
        if (msg.sender == address(this)) {
            return abi.encode(_evaluate(batch, executor, gateData));
        }

        IStreamMintPreview.MintPreview memory failure;
        failure.quantity = batch.initialRecipients.length;
        failure.reason = IStreamMintPreview.MintPreviewUnavailable.selector;
        failure.counters = new IStreamMintPreview.CounterPreview[](0);
        // A typed library DELEGATECALL has the library selector, not the facade selector.
        bytes memory payload =
            abi.encodeCall(IStreamMintPreview.canMint, (batch, executor, gateData));
        uint256 available = gasleft();
        if (available <= RETURN_GAS_RESERVE + 10_000) return abi.encode(failure);
        uint256 forwarded = available - RETURN_GAS_RESERVE;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(forwarded, address(), add(payload, 32), mload(payload), 0, 0)
            size := returndatasize()
        }
        if (!ok) {
            // Never allocate or copy a dependency's arbitrary revert payload.
            if (size >= 4 && size <= MAX_RESULT_BYTES) {
                bytes4 reason;
                assembly ("memory-safe") {
                    returndatacopy(0, 0, 4)
                    reason := mload(0)
                }
                if (reason != bytes4(0)) failure.reason = reason;
            }
            return abi.encode(failure);
        }
        if (size < 256 || size > MAX_RESULT_BYTES) return abi.encode(failure);
        encoded = new bytes(size);
        assembly ("memory-safe") {
            returndatacopy(add(encoded, 32), 0, size)
        }
        uint256 outerOffset;
        uint256 allowed;
        uint256 rowsOffset;
        uint256 count;
        assembly ("memory-safe") {
            outerOffset := mload(add(encoded, 32))
            allowed := mload(add(encoded, 64))
            rowsOffset := mload(add(encoded, 224))
            count := mload(add(encoded, 256))
        }
        if (
            outerOffset != 32 || allowed > 1 || rowsOffset != 192 || count > MAX_ROWS
                || size != 256 + count * 288
        ) return abi.encode(failure);
    }

    function _evaluate(
        IStreamMintManager.MintBatch calldata batch,
        address executor,
        bytes calldata gateData
    ) private view returns (IStreamMintPreview.MintPreview memory result) {
        IStreamMintReads host = IStreamMintReads(address(this));
        IStreamMintLedger ledger = host.mintLedger();
        address core = address(host.core());
        IERC165 registry = host.moduleRegistry();
        Phase memory p = _phase(host, batch, executor);
        StreamMintRoyaltyPolicy.requireCurrent(
            IStreamMintRoyaltyPolicy(address(this))
                .phaseRoyaltyPolicy(batch.collectionId, batch.phaseId),
            StreamMintRoyaltyPolicy.Context(core, address(registry)),
            batch.collectionId,
            batch.phaseId,
            p.config.configHash,
            false
        );
        result.quantity = StreamMintManagerTranscript.validateMintBatch(batch, p.config);
        result.policyHash = StreamMintOperationIdentity.computePolicyHash(
            p.config,
            p.gate,
            p.ids,
            p.counters,
            IStreamMintPhaseFreeze(address(this)).phaseExecutors(batch.collectionId, batch.phaseId),
            StreamMintOperationIdentity.PolicyContext(
                block.chainid,
                address(this),
                address(ledger),
                address(registry),
                1,
                batch.collectionId,
                batch.phaseId
            )
        );
        bytes32 registered = host.phasePolicyHash(batch.collectionId, batch.phaseId);
        if (registered != result.policyHash) {
            revert IStreamMintManager.MintPolicyHashMismatch(registered, result.policyHash);
        }
        bytes32 bound =
            StreamMintManagerTranscript.requireBoundPolicyHash(batch, result.policyHash, ledger);
        StreamMintArtistConsent.mint(
            core,
            batch.collectionId,
            batch.phaseId,
            result.policyHash,
            IStreamGasParameterHost(address(this)).gasParameter(ARTIST_GAS)
        );
        StreamMintOperationIdentity.MintAuthorization memory authorization =
            StreamMintGateValidator.validateAuthorization(
                batch, gateData, result.quantity, bound, p.gate, registry, executor
            );
        result.gateHash = authorization.gateHash;
        IStreamMintLedger.CounterConsumption[] memory rows = StreamMintCounterPreparation.preview(
            batch,
            result.quantity,
            p.ids,
            p.counters,
            StreamMintOperationIdentity.CounterContext(
                block.chainid, address(this), address(ledger), executor, authorization.authorizer
            )
        );
        (result.counters, result.allowed) = _counters(ledger, rows);
        if (!result.allowed) {
            result.reason = IStreamMintLedger.CounterCapExceeded.selector;
            return result;
        }
        uint256 nonce = host.nextOperationNonce();
        if (type(uint256).max - nonce < result.quantity) {
            revert IStreamMintManager.MintOperationNonceOverflow(nonce, result.quantity);
        }
        _ledgerState(ledger, batch, p, result.policyHash, authorization);
    }

    function _phase(
        IStreamMintReads host,
        IStreamMintManager.MintBatch calldata batch,
        address executor
    ) private view returns (Phase memory p) {
        if (batch.collectionId == 0 || batch.phaseId == bytes32(0)) {
            revert IStreamMintManager.InvalidMintPhase(batch.collectionId, batch.phaseId);
        }
        bool exists;
        (exists, p.config) = host.phase(batch.collectionId, batch.phaseId);
        if (!exists) {
            revert IStreamMintManager.MintPhaseDoesNotExist(batch.collectionId, batch.phaseId);
        }
        if (p.config.paused) {
            revert IStreamMintManager.MintPhasePaused(batch.collectionId, batch.phaseId);
        }
        if (p.config.startTime != 0 && block.timestamp < p.config.startTime) {
            revert IStreamMintManager.MintPhaseNotStarted(
                batch.collectionId, batch.phaseId, block.timestamp
            );
        }
        if (p.config.endTime != 0 && block.timestamp > p.config.endTime) {
            revert IStreamMintManager.MintPhaseEnded(
                batch.collectionId, batch.phaseId, block.timestamp
            );
        }
        if (!host.phaseExecutor(batch.collectionId, batch.phaseId, executor)) {
            revert IStreamMintManager.UnauthorizedMintExecutor(
                batch.collectionId, batch.phaseId, executor
            );
        }
        p.gate = host.phaseGate(batch.collectionId, batch.phaseId);
        p.ids = host.phaseCounterIds(batch.collectionId, batch.phaseId);
        if (p.ids.length > 16) revert IStreamMintPreview.MintPreviewUnavailable();
        p.counters = new IStreamMintManager.MintCounterConfig[](p.ids.length);
        for (uint256 i; i < p.ids.length; ++i) {
            p.counters[i] = host.counterConfig(batch.collectionId, batch.phaseId, p.ids[i]);
        }
    }

    function _counters(IStreamMintLedger ledger, IStreamMintLedger.CounterConsumption[] memory rows)
        private
        view
        returns (IStreamMintPreview.CounterPreview[] memory previews, bool allowed)
    {
        if (rows.length > MAX_ROWS) revert IStreamMintPreview.MintPreviewUnavailable();
        previews = new IStreamMintPreview.CounterPreview[](rows.length);
        allowed = true;
        for (uint256 i; i < rows.length; ++i) {
            uint64 current = ledger.counterValue(rows[i].valueKey);
            uint256 projected = current;
            for (uint256 j; j < rows.length; ++j) {
                if (rows[i].valueKey == rows[j].valueKey) projected += rows[j].increment;
            }
            if (projected > type(uint64).max) {
                revert IStreamMintLedger.CounterValueOverflow(rows[i].valueKey);
            }
            bool rowAllowed = rows[i].cap == 0 || projected <= rows[i].cap;
            if (!rowAllowed) allowed = false;
            previews[i] = IStreamMintPreview.CounterPreview(
                rows[i].counterId,
                rows[i].subjectKey,
                rows[i].valueKey,
                current,
                rows[i].increment,
                uint64(projected),
                rows[i].cap,
                rowAllowed,
                rows[i].resolutionHash
            );
        }
    }

    function _ledgerState(
        IStreamMintLedger ledger,
        IStreamMintManager.MintBatch calldata batch,
        Phase memory p,
        bytes32 currentPolicy,
        StreamMintOperationIdentity.MintAuthorization memory authorization
    ) private view {
        if (!ledger.ledgerWriter(address(this))) {
            revert IStreamMintLedger.UnauthorizedLedgerWriter(address(this));
        }
        IStreamMintLedgerContinuity continuity = IStreamMintLedgerContinuity(address(ledger));
        if (continuity.mintAncestorCount(address(this)) != 0) {
            (address ancestorLedger, address ancestor) = continuity.mintAncestorAt(address(this), 0);
            if (!continuity.isCompletedMintDescendant(ancestorLedger, ancestor, address(this))) {
                revert IStreamMintLedgerImport.MintImportNotReady(address(this));
            }
        }
        if (
            ledger.registeredPhasePolicyHash(address(this), batch.collectionId, batch.phaseId)
                != currentPolicy
        ) {
            revert IStreamMintLedger.InvalidPhasePolicy(
                address(this), batch.collectionId, batch.phaseId
            );
        }
        if (ledger.isManagerAuthorizationUsed(address(this), authorization.authorizationId)) {
            revert IStreamMintLedger.AuthorizationAlreadyConsumed(authorization.authorizationId);
        }
        for (uint256 i; i < authorization.nullifiers.length; ++i) {
            if (ledger.isManagerNullifierUsed(address(this), authorization.nullifiers[i])) {
                revert IStreamMintLedger.NullifierAlreadyConsumed(authorization.nullifiers[i]);
            }
        }
        for (uint256 i; i < p.ids.length; ++i) {
            IStreamMintLedger.LedgerCounterPolicy memory registered = ledger.registeredCounterPolicy(
                address(this), batch.collectionId, batch.phaseId, p.ids[i]
            );
            IStreamMintManager.MintCounterConfig memory c = p.counters[i];
            if (!registered.enabled) {
                revert IStreamMintLedger.CounterPolicyNotRegistered(
                    address(this), batch.collectionId, batch.phaseId, p.ids[i]
                );
            }
            if (
                registered.enabled != c.enabled || registered.capMode != c.capMode
                    || registered.deltaMode != c.deltaMode || registered.staticCap != c.staticCap
                    || registered.staticIncrement != c.staticIncrement
                    || registered.counterConfigHash != c.counterConfigHash
            ) revert IStreamMintLedger.CounterPolicyMismatch(p.ids[i]);
        }
    }
}
