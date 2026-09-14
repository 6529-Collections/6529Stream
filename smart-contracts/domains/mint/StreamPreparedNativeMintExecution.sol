// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamPreparedNativeMint.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../revenue/StreamPreparedNativeSettlementValidation.sol";

/// @notice Typed paid preparation in Manager's storage/caller context, never an arbitrary hook.
library StreamPreparedNativeMintExecution {
    struct State {
        StreamPreparedNativeSettlementTypes.Facts active;
        address recorder;
        bytes32 recorderCodeHash;
        uint64 boundAt;
        uint64 moduleRevision;
    }

    struct Operation {
        IStreamCore core;
        address registry;
        bytes32 intentHash;
        bytes32 operationRoot;
        bytes32 operationId;
        bytes32 currentPolicyHash;
        bytes32 boundPolicyHash;
        uint256 callbackGas;
    }

    event PreparedMintStarted(
        uint16 schemaVersion,
        bytes32 indexed operationId,
        uint256 indexed tokenId,
        uint256 indexed collectionId,
        bytes32 operationRoot,
        uint256 collectionSerial,
        address beneficiary,
        bytes32 tokenDataHash,
        bytes32 mintCommitment
    );
    event PreparedMintCompleted(
        uint16 schemaVersion,
        bytes32 indexed operationId,
        uint256 indexed tokenId,
        uint256 indexed collectionId,
        bytes32 operationRoot,
        address initialRecipient
    );

    function bindRecorder(State storage state, address core, address registry, address recorder)
        public
    {
        if (state.recorder != address(0)) {
            revert IStreamPreparedNativeMint.PreparedNativeRecorderAlreadyBound();
        }
        (uint64 boundAt, uint64 revision) =
            StreamPreparedNativeSettlementAdmission.captureRecorder(registry, recorder);
        if (
            StreamPreparedNativeSettlementValidation.addressWord(recorder, "core()") != core
                || StreamPreparedNativeSettlementValidation.addressWord(
                        recorder, "moduleRegistry()"
                    ) != registry
                || StreamPreparedNativeSettlementValidation.word(recorder, "coreCodeHash()")
                    != core.codehash
                || StreamPreparedNativeSettlementValidation.word(
                        recorder, "moduleRegistryCodeHash()"
                    ) != registry.codehash
        ) {
            revert IStreamPreparedNativeMint.InvalidPreparedNativeMint();
        }
        StreamSettlementAdmission.requireRegistry(core, core.codehash, registry, registry.codehash);
        state.recorder = recorder;
        state.recorderCodeHash = recorder.codehash;
        state.boundAt = boundAt;
        state.moduleRevision = revision;
    }

    function execute(
        State storage state,
        IStreamMintManager.MintBatch calldata batch,
        Operation memory op
    )
        public
        returns (
            uint256 tokenId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        )
    {
        if (
            state.recorder == address(0) || state.active.operationRoot != 0
                || batch.initialRecipients.length != 1 || batch.initialRecipients[0] != msg.sender
                || batch.tokenData[0].length > 8192 || op.intentHash == 0
                || batch.contextHash
                    != StreamPreparedNativeSettlementHash.mintContext(
                        address(this), msg.sender, op.intentHash
                    )
        ) {
            revert IStreamPreparedNativeMint.InvalidPreparedNativeMint();
        }
        StreamPreparedNativeSettlementAdmission.requireModule(op.registry, msg.sender);
        StreamPreparedNativeSettlementTypes.Facts memory f;
        f.saleAdapter = msg.sender;
        f.mintManager = address(this);
        f.recorder = StreamPreparedNativeSettlementValidation.addressWord(
            msg.sender, "primarySaleSettlement()"
        );
        f.recorderCodeHash =
            StreamPreparedNativeSettlementValidation.word(msg.sender, "settlementCodeHash()");
        f.collectionId = batch.collectionId;
        f.phaseId = batch.phaseId;
        f.intentHash = op.intentHash;
        f.operationRoot = op.operationRoot;
        f.operationId = op.operationId;
        f.payer = batch.payer;
        f.initialRecipient = batch.initialRecipients[0];
        f.beneficiary = batch.beneficiaries[0];
        f.tokenDataHash = keccak256(batch.tokenData[0]);
        f.mintCommitment = batch.mintCommitments[0];
        f.currentPolicyHash = op.currentPolicyHash;
        f.boundPolicyHash = op.boundPolicyHash;
        StreamPreparedNativeSettlementTypes.Intent memory intent =
            StreamPreparedNativeSettlementValidation.readIntent(
                msg.sender, f.recorder, f.intentHash
            );
        StreamPreparedNativeSettlementAdmission.requireAdmission(
            op.registry, msg.sender, intent.saleId
        );
        StreamPreparedNativeSettlementValidation.requireBindings(
            address(op.core), op.registry, address(this), msg.sender, f.recorder, f.recorderCodeHash
        );
        StreamPreparedNativeSettlementValidation.requireIntentFields(f, intent);
        (f.tokenId, f.collectionSerial) = op.core
            .prepareMintFromManager(
                batch.collectionId, batch.tokenData[0], f.tokenDataHash, f.operationId
            );
        state.active = f;
        emit PreparedMintStarted(
            1,
            f.operationId,
            f.tokenId,
            f.collectionId,
            f.operationRoot,
            f.collectionSerial,
            f.beneficiary,
            f.tokenDataHash,
            f.mintCommitment
        );
        result = _callback(f, op.callbackGas);
        _requireResult(f, intent, result);
        StreamPreparedNativeSettlementValidation.requireActive(
            address(op.core), op.registry, f, intent
        );
        op.core
            .completePreparedMintFromManager(
                f.tokenId, f.initialRecipient, f.operationId, f.mintCommitment
            );
        _requireResult(f, intent, result);
        StreamPreparedNativeSettlementAdmission.requireAdmission(
            op.registry, msg.sender, intent.saleId
        );
        StreamPreparedNativeSettlementValidation.requireBindings(
            address(op.core), op.registry, address(this), msg.sender, f.recorder, f.recorderCodeHash
        );
        if (
            op.core.ownerOf(f.tokenId) != f.initialRecipient
                || op.core.pendingPreparedMintTokenId() != 0
                || op.core.tokenLifecycle(f.tokenId) != 2
        ) {
            revert IStreamPreparedNativeMint.PreparedNativeResultMismatch();
        }
        emit PreparedMintCompleted(
            1, f.operationId, f.tokenId, f.collectionId, f.operationRoot, f.initialRecipient
        );
        tokenId = f.tokenId;
        delete state.active;
    }

    function _callback(StreamPreparedNativeSettlementTypes.Facts memory facts, uint256 cap)
        private
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        bytes memory data =
            abi.encodeCall(IStreamPreparedNativeSaleBinding.onPreparedNativeMint, (facts));
        bytes memory raw = new bytes(416);
        uint256 available = gasleft();
        if (cap == 0 || cap > type(uint64).max) {
            revert IStreamPreparedNativeMint.InvalidPreparedNativeMint();
        }
        uint256 required = cap + cap / 63 + 1_000_000;
        if (available <= required) {
            revert IStreamPreparedNativeMint.InsufficientPreparedNativeGas(available, required);
        }
        address sale = facts.saleAdapter;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(cap, sale, 0, add(data, 32), mload(data), add(raw, 32), 416)
            size := returndatasize()
        }
        if (!ok || size != 416) {
            revert IStreamPreparedNativeMint.PreparedNativeCallFailed(
                sale, IStreamPreparedNativeSaleBinding.onPreparedNativeMint.selector
            );
        }
        bytes4 magic;
        (magic, result) =
            abi.decode(raw, (bytes4, StreamPrimarySettlementTypes.PrimarySettlementResult));
        if (
            magic != IStreamPreparedNativeSaleBinding.onPreparedNativeMint.selector
                || keccak256(raw) != keccak256(abi.encode(magic, result))
        ) {
            revert IStreamPreparedNativeMint.PreparedNativeResultMismatch();
        }
    }

    function _requireResult(
        StreamPreparedNativeSettlementTypes.Facts memory f,
        StreamPreparedNativeSettlementTypes.Intent memory intent,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result
    ) private view {
        if (f.recorder.codehash != f.recorderCodeHash) {
            revert IStreamPreparedNativeMint.PreparedNativeResultMismatch();
        }
        bytes memory raw = StreamPreparedNativeSettlementValidation.read(
            f.recorder,
            abi.encodeCall(IStreamPrimarySaleSettlement.settlementResult, (result.settlementKey)),
            384
        );
        if (
            keccak256(raw) != keccak256(abi.encode(result)) || result.candidateCommitment == 0
                || result.settlementKey == 0 || result.profileId == 0 || result.wallet == address(0)
                || result.asset != address(0) || result.amount != intent.amount
                || result.executor != intent.executor
                || result.executionId != StreamPreparedNativeSettlementHash.executionId(f, intent)
                || result.operationIdentityCommitment != f.operationRoot
                || result.currentPolicyHash != f.currentPolicyHash
                || result.boundPolicyHash != f.boundPolicyHash
        ) {
            revert IStreamPreparedNativeMint.PreparedNativeResultMismatch();
        }
        raw = StreamPreparedNativeSettlementValidation.read(
            f.recorder,
            abi.encodeCall(
                IStreamPreparedNativePrimarySaleSettlement.preparedNativeFactsHash,
                (result.settlementKey)
            ),
            32
        );
        if (abi.decode(raw, (bytes32)) != StreamPreparedNativeSettlementHash.factsHash(f)) {
            revert IStreamPreparedNativeMint.PreparedNativeResultMismatch();
        }
        raw = StreamPreparedNativeSettlementValidation.read(
            f.recorder,
            abi.encodeCall(IStreamPrimarySaleSettlement.settlementConsumed, (result.settlementKey)),
            32
        );
        if (abi.decode(raw, (uint256)) != 1) {
            revert IStreamPreparedNativeMint.PreparedNativeResultMismatch();
        }
    }
}
