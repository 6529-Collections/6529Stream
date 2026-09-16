// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamMintTranscriptTypes.sol";
import "./StreamMintPhaseState.sol";
import "./StreamMintManagerAccounting.sol";
import "./StreamMintArtistConsent.sol";
import "./StreamERC20OfferReads.sol";
import "./StreamERC20OfferSignatures.sol";
import "./StreamERC20OfferGateValidation.sol";
import "./StreamImmediateSaleReveal.sol";

/// @notice Full-payload ERC20 offer transcript, preserving original single-step identity domains.
/// @dev The original no-gate path stays unchanged; this path authenticates its retained buyer signer.
library StreamMintManagerERC20OfferTranscript {
    error InvalidERC20OfferNativeFee();
    error InvalidERC20OfferArguments();

    struct Context {
        address core;
        StreamMintOperationIdentity.PolicyContext policy;
        bytes32 registeredPolicyHash;
        uint256 firstOperationNonce;
        uint256 artistGas;
    }

    function build(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata arguments,
        bytes32 executionPath,
        StreamMintPhaseState.PhaseState storage phaseState,
        IStreamMintManager.MintGateConfig storage gate,
        bytes32[] storage counterIds,
        mapping(bytes32 => IStreamMintManager.MintCounterConfig) storage counters,
        address[] storage executors,
        Context memory x
    ) public view returns (StreamMintTranscriptTypes.OperationTranscript memory transcript) {
        (
            IStreamMintManager.MintBatch memory decodedBatch,
            StreamERC20OfferMintTypes.GateData memory offerData
        ) = abi.decode(
            arguments, (IStreamMintManager.MintBatch, StreamERC20OfferMintTypes.GateData)
        );
        if (keccak256(abi.encode(decodedBatch)) != keccak256(abi.encode(batch))) {
            revert InvalidERC20OfferArguments();
        }
        transcript.quantity = validateMintBatch(batch, phaseState.config);
        StreamERC20OfferSignatures.validate(address(this), msg.sender, batch, offerData);
        StreamERC20OfferReads.requireBatch(
            address(this), x.policy.moduleRegistry, msg.sender, batch, offerData
        );
        if (
            StreamImmediateSaleReveal.quote(x.core, batch.collectionId).policy.revealFeePerTokenWei
                != 0
        ) {
            revert InvalidERC20OfferNativeFee();
        }
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
        transcript.authorization = StreamERC20OfferGateValidation.validate(
            batch, offerData, gate, x.policy.moduleRegistry
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
    ) private pure returns (uint256 quantity) {
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
    ) private view returns (bytes32 boundPolicyHash) {
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
