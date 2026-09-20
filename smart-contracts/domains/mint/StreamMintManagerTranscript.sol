// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamMintTranscriptTypes.sol";
import "./StreamMintPhaseState.sol";
import "./StreamMintManagerAccounting.sol";
import "./StreamMintArtistConsent.sol";

/// @notice Original operation-transcript body through one fixed linked boundary.
/// @dev Manager first authenticates the executable phase and supplies its exact storage refs.
/// Delegatecall retains original Manager, executor, chain, errors and hash domains.
library StreamMintManagerTranscript {
    struct Context {
        address core;
        StreamMintOperationIdentity.PolicyContext policy;
        bytes32 registeredPolicyHash;
        uint256 firstOperationNonce;
        uint256 artistGas;
    }

    function build(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 executionPath,
        StreamMintPhaseState.PhaseState storage phaseState,
        IStreamMintManager.MintGateConfig storage gate,
        bytes32[] storage counterIds,
        mapping(bytes32 => IStreamMintManager.MintCounterConfig) storage counters,
        address[] storage executors,
        Context memory x
    ) public view returns (StreamMintTranscriptTypes.OperationTranscript memory transcript) {
        transcript.quantity = validateMintBatch(batch, phaseState.config);
        transcript.currentPolicyHash = StreamMintPhaseState.computeStoredPolicyHash(
            phaseState, gate, counterIds, counters, executors, x.policy
        );
        if (transcript.currentPolicyHash != x.registeredPolicyHash) {
            revert IStreamMintManager.MintPolicyHashMismatch(
                x.registeredPolicyHash, transcript.currentPolicyHash
            );
        }
        transcript.boundPolicyHash = requireBoundPolicyHash(
            batch, transcript.currentPolicyHash, IStreamMintLedger(x.policy.ledger)
        );
        StreamMintArtistConsent.mint(
            x.core, batch.collectionId, batch.phaseId, transcript.currentPolicyHash, x.artistGas
        );
        transcript.authorization = StreamMintGateValidator.validateAuthorization(
            batch,
            gateData,
            transcript.quantity,
            transcript.boundPolicyHash,
            gate,
            IERC165(x.policy.moduleRegistry),
            msg.sender
        );
        transcript.consumptions = StreamMintManagerAccounting.counterConsumptions(
            batch,
            transcript.quantity,
            transcript.authorization.authorizer,
            x.policy.ledger,
            counterIds,
            counters
        );
        transcript.firstOperationNonce = x.firstOperationNonce;
        if (type(uint256).max - transcript.firstOperationNonce < transcript.quantity) {
            revert IStreamMintManager.MintOperationNonceOverflow(
                transcript.firstOperationNonce, transcript.quantity
            );
        }
        StreamMintOperationIdentity.TranscriptContext memory context =
            StreamMintOperationIdentity.TranscriptContext({
                chainId: block.chainid,
                manager: address(this),
                coreAddress: x.core,
                ledgerAddress: x.policy.ledger,
                gate: gate.gate,
                executor: msg.sender,
                executionPath: executionPath,
                currentPolicyHash: transcript.currentPolicyHash,
                boundPolicyHash: transcript.boundPolicyHash,
                firstOperationNonce: transcript.firstOperationNonce,
                quantity: transcript.quantity
            });
        (transcript.operationRoot, transcript.operationIds) = StreamMintOperationIdentity.derive(
            batch, transcript.authorization, transcript.consumptions, context
        );
    }

    function validateMintBatch(
        IStreamMintManager.MintBatch calldata request,
        IStreamMintManager.MintPhaseConfig memory config
    ) internal pure returns (uint256 quantity) {
        quantity = request.initialRecipients.length;
        if (
            quantity == 0 || quantity != request.beneficiaries.length
                || quantity != request.tokenData.length
                || quantity != request.mintCommitments.length
        ) revert IStreamMintManager.MintArrayLengthMismatch();
        if (quantity > config.maxBatchQuantity) {
            revert IStreamMintManager.MintBatchQuantityLimitExceeded(
                quantity, config.maxBatchQuantity
            );
        }
        for (uint256 i = 0; i < quantity; i++) {
            if (
                request.initialRecipients[i] == address(0) || request.beneficiaries[i] == address(0)
            ) {
                revert IStreamMintManager.InvalidMintRecipient(
                    i, request.initialRecipients[i], request.beneficiaries[i]
                );
            }
        }
    }

    function requireBoundPolicyHash(
        IStreamMintManager.MintBatch calldata batch,
        bytes32 currentPolicyHash,
        IStreamMintLedger ledger
    ) internal view returns (bytes32 boundPolicyHash) {
        boundPolicyHash = batch.expectedPolicyHash;
        if (boundPolicyHash == bytes32(0)) {
            revert IStreamMintManager.MintPolicyHashRequired(batch.collectionId, batch.phaseId);
        }
        if (boundPolicyHash == currentPolicyHash) return boundPolicyHash;
        (bytes32 previousPolicyHash,, uint64 graceUntil) =
            ledger.policyGrace(address(this), batch.collectionId, batch.phaseId);
        if (boundPolicyHash != previousPolicyHash || block.timestamp > graceUntil) {
            revert IStreamMintManager.MintPolicyHashMismatch(boundPolicyHash, currentPolicyHash);
        }
    }
}
