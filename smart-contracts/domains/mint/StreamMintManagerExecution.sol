// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintCoreExecutor.sol";
import "./StreamMintTranscriptTypes.sol";
import "./StreamPreparedNativeMintExecution.sol";
import "./StreamPreparedNativeContentExecution.sol";
import "./StreamPreparedNativeContentPurchaseExecution.sol";
import "./StreamPreparedNativeOfferExecution.sol";
import "./StreamPreparedNativeRightsExecution.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Original post-reservation Manager execution through a fixed compiler link.
/// @dev The Manager retains its external guard, admission, transcript and nonce reservation.
/// Actual storage refs and immutable context preserve identity, caller, events and rollback.
/// The callback gas parameter is read from this same host at its original execution phase.
library StreamMintManagerExecution {
    struct Context {
        IStreamCore core;
        IStreamMintLedger ledger;
        address registry;
    }

    uint16 private constant SCHEMA_VERSION = 1;
    bytes32 private constant GGP_PREPARED_NATIVE_CALLBACK_GAS_LIMIT =
        keccak256("6529STREAM_GGP_PREPARED_NATIVE_CALLBACK_GAS_LIMIT");

    event MintGateValidated(
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        address indexed gate,
        bytes32 authorizationId,
        address authorizer,
        uint256 quantity,
        bytes32 contextHash,
        bytes32 gateHash,
        bytes32 policyHash
    );
    event MintAuthorizationConsumed(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        bytes32 indexed authorizationId,
        bytes32 boundPolicyHash,
        bytes32 operationRoot
    );
    event MintBatchExecuted(
        uint16 schemaVersion,
        bytes32 indexed operationRoot,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        address executor,
        address payer,
        address authorizer,
        uint256 firstTokenId,
        uint256 quantity,
        bytes32 contextHash,
        bytes32 gateHash,
        bytes32 currentPolicyHash,
        bytes32 boundPolicyHash
    );

    function singleStep(
        Context memory x,
        IStreamMintManager.MintGateConfig storage gate,
        IStreamMintManager.MintBatch calldata batch,
        StreamMintTranscriptTypes.OperationTranscript memory transcript
    )
        public
        returns (uint256[] memory tokenIds, bytes32 operationRoot, bytes32[] memory operationIds)
    {
        _consumeOperation(x, batch, transcript);
        _emitGateValidation(gate, batch, transcript);

        tokenIds = new uint256[](transcript.quantity);
        for (uint256 i = 0; i < transcript.quantity; i++) {
            tokenIds[i] = StreamMintCoreExecutor.executeSingleStep(
                x.core,
                batch,
                i,
                transcript.operationRoot,
                transcript.operationIds[i],
                SCHEMA_VERSION
            );
        }

        _emitOperationCompletion(batch, transcript, tokenIds[0]);
        return (tokenIds, transcript.operationRoot, transcript.operationIds);
    }

    function prepared(
        Context memory x,
        IStreamMintManager.MintGateConfig storage gate,
        IStreamMintManager.MintBatch calldata batch,
        StreamMintTranscriptTypes.OperationTranscript memory transcript
    )
        public
        returns (uint256[] memory tokenIds, bytes32 operationRoot, bytes32[] memory operationIds)
    {
        _consumeOperation(x, batch, transcript);
        _emitGateValidation(gate, batch, transcript);

        tokenIds = new uint256[](transcript.quantity);
        for (uint256 i = 0; i < transcript.quantity; i++) {
            tokenIds[i] = StreamMintCoreExecutor.executePrepared(
                x.core,
                batch,
                i,
                transcript.operationRoot,
                transcript.operationIds[i],
                SCHEMA_VERSION
            );
        }

        _emitOperationCompletion(batch, transcript, tokenIds[0]);
        return (tokenIds, transcript.operationRoot, transcript.operationIds);
    }

    function paid(
        Context memory x,
        IStreamMintManager.MintGateConfig storage gate,
        StreamPreparedNativeMintExecution.State storage prepared,
        IStreamMintManager.MintBatch calldata batch,
        bytes32 intentHash,
        StreamMintTranscriptTypes.OperationTranscript memory transcript
    )
        public
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        )
    {
        _consumeOperation(x, batch, transcript);
        _emitGateValidation(gate, batch, transcript);
        StreamPreparedNativeMintExecution.Operation memory op;
        op.core = x.core;
        op.registry = x.registry;
        op.intentHash = intentHash;
        op.operationRoot = transcript.operationRoot;
        op.operationId = transcript.operationIds[0];
        op.currentPolicyHash = transcript.currentPolicyHash;
        op.boundPolicyHash = transcript.boundPolicyHash;
        op.callbackGas = IStreamGasParameterHost(address(this))
            .gasParameter(GGP_PREPARED_NATIVE_CALLBACK_GAS_LIMIT);
        (tokenId, result) = StreamPreparedNativeMintExecution.execute(prepared, batch, op);
        _emitOperationCompletion(batch, transcript, tokenId);
        return (tokenId, transcript.operationRoot, transcript.operationIds[0], result);
    }

    function rightsPaid(
        Context memory x,
        IStreamMintManager.MintGateConfig storage gate,
        StreamPreparedNativeMintExecution.State storage prepared,
        StreamPreparedNativeRightsExecution.State storage rights,
        IStreamMintManager.MintBatch calldata batch,
        bytes32 intentHash,
        StreamMintTranscriptTypes.OperationTranscript memory transcript
    )
        public
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        )
    {
        _consumeOperation(x, batch, transcript);
        _emitGateValidation(gate, batch, transcript);
        StreamPreparedNativeRightsExecution.Operation memory op;
        op.core = x.core;
        op.registry = x.registry;
        op.intentHash = intentHash;
        op.operationRoot = transcript.operationRoot;
        op.operationId = transcript.operationIds[0];
        op.currentPolicyHash = transcript.currentPolicyHash;
        op.boundPolicyHash = transcript.boundPolicyHash;
        op.callbackGas = IStreamGasParameterHost(address(this))
            .gasParameter(GGP_PREPARED_NATIVE_CALLBACK_GAS_LIMIT);
        (tokenId, result) = StreamPreparedNativeRightsExecution.execute(rights, prepared, batch, op);
        _emitOperationCompletion(batch, transcript, tokenId);
        return (tokenId, transcript.operationRoot, transcript.operationIds[0], result);
    }

    function contentPaid(
        Context memory x,
        IStreamMintManager.MintGateConfig storage gate,
        StreamPreparedNativeMintExecution.State storage prepared,
        StreamPreparedNativeContentExecution.State storage content,
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 intentHash,
        StreamMintTranscriptTypes.OperationTranscript memory transcript
    )
        public
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        )
    {
        _consumeOperation(x, batch, transcript);
        _emitGateValidation(gate, batch, transcript);
        StreamPreparedNativeMintExecution.Operation memory op;
        op.core = x.core;
        op.registry = x.registry;
        op.intentHash = intentHash;
        op.operationRoot = transcript.operationRoot;
        op.operationId = transcript.operationIds[0];
        op.currentPolicyHash = transcript.currentPolicyHash;
        op.boundPolicyHash = transcript.boundPolicyHash;
        op.callbackGas = IStreamGasParameterHost(address(this))
            .gasParameter(GGP_PREPARED_NATIVE_CALLBACK_GAS_LIMIT);
        (tokenId, result) =
            StreamPreparedNativeContentExecution.execute(prepared, content, gateData, batch, op);
        _emitOperationCompletion(batch, transcript, tokenId);
        return (tokenId, transcript.operationRoot, transcript.operationIds[0], result);
    }

    function contentPurchasePaid(
        Context memory x,
        IStreamMintManager.MintGateConfig storage gate,
        StreamPreparedNativeMintExecution.State storage prepared,
        StreamPreparedNativeContentExecution.State storage content,
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 intentHash,
        StreamMintTranscriptTypes.OperationTranscript memory transcript
    )
        public
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        )
    {
        _consumeOperation(x, batch, transcript);
        _emitGateValidation(gate, batch, transcript);
        StreamPreparedNativeMintExecution.Operation memory op;
        op.core = x.core;
        op.registry = x.registry;
        op.intentHash = intentHash;
        op.operationRoot = transcript.operationRoot;
        op.operationId = transcript.operationIds[0];
        op.currentPolicyHash = transcript.currentPolicyHash;
        op.boundPolicyHash = transcript.boundPolicyHash;
        op.callbackGas = IStreamGasParameterHost(address(this))
            .gasParameter(GGP_PREPARED_NATIVE_CALLBACK_GAS_LIMIT);
        (tokenId, result) =
            StreamPreparedNativeContentPurchaseExecution.execute(prepared, content, gateData, batch, op);
        _emitOperationCompletion(batch, transcript, tokenId);
        return (tokenId, transcript.operationRoot, transcript.operationIds[0], result);
    }

    function offerPaid(
        Context memory x,
        IStreamMintManager.MintGateConfig storage gate,
        StreamPreparedNativeMintExecution.State storage prepared,
        StreamPreparedNativeContentExecution.State storage content,
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 intentHash,
        StreamMintTranscriptTypes.OperationTranscript memory transcript
    )
        public
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        )
    {
        _consumeOperation(x, batch, transcript);
        _emitGateValidation(gate, batch, transcript);
        StreamPreparedNativeMintExecution.Operation memory op;
        op.core = x.core;
        op.registry = x.registry;
        op.intentHash = intentHash;
        op.operationRoot = transcript.operationRoot;
        op.operationId = transcript.operationIds[0];
        op.currentPolicyHash = transcript.currentPolicyHash;
        op.boundPolicyHash = transcript.boundPolicyHash;
        op.callbackGas = IStreamGasParameterHost(address(this))
            .gasParameter(GGP_PREPARED_NATIVE_CALLBACK_GAS_LIMIT);
        (tokenId, result) =
            StreamPreparedNativeOfferExecution.execute(prepared, content, gateData, batch, op);
        _emitOperationCompletion(batch, transcript, tokenId);
        return (tokenId, transcript.operationRoot, transcript.operationIds[0], result);
    }

    function _consumeOperation(
        Context memory x,
        IStreamMintManager.MintBatch calldata batch,
        StreamMintTranscriptTypes.OperationTranscript memory transcript
    ) private {
        x.ledger
            .consume(
                batch.collectionId,
                batch.phaseId,
                transcript.consumptions,
                batch.authorizationId,
                transcript.authorization.nullifiers,
                transcript.boundPolicyHash,
                transcript.operationRoot
            );
    }

    function _emitGateValidation(
        IStreamMintManager.MintGateConfig storage gateState,
        IStreamMintManager.MintBatch calldata batch,
        StreamMintTranscriptTypes.OperationTranscript memory transcript
    ) private {
        address gate = gateState.gate;
        if (gate == address(0)) {
            return;
        }
        emit MintGateValidated(
            batch.collectionId,
            batch.phaseId,
            gate,
            batch.authorizationId,
            transcript.authorization.authorizer,
            transcript.quantity,
            batch.contextHash,
            transcript.authorization.gateHash,
            transcript.boundPolicyHash
        );
    }

    function _emitOperationCompletion(
        IStreamMintManager.MintBatch calldata batch,
        StreamMintTranscriptTypes.OperationTranscript memory transcript,
        uint256 firstTokenId
    ) private {
        emit MintAuthorizationConsumed(
            SCHEMA_VERSION,
            batch.collectionId,
            batch.phaseId,
            batch.authorizationId,
            transcript.boundPolicyHash,
            transcript.operationRoot
        );
        emit MintBatchExecuted(
            SCHEMA_VERSION,
            transcript.operationRoot,
            batch.collectionId,
            batch.phaseId,
            msg.sender,
            batch.payer,
            transcript.authorization.authorizer,
            firstTokenId,
            transcript.quantity,
            batch.contextHash,
            transcript.authorization.gateHash,
            transcript.currentPolicyHash,
            transcript.boundPolicyHash
        );
    }
}
