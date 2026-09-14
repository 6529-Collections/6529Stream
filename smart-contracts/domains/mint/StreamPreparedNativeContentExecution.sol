// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamPreparedNativeMint.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "./StreamPreparedNativeMintExecution.sol";
import "../revenue/StreamPreparedNativeContentValidation.sol";

/// @notice Typed paid preparation in Manager's storage/caller context, never an arbitrary hook.
library StreamPreparedNativeContentExecution {
    struct State {
        StreamPreparedNativeContentTypes.Facts active;
        bytes32 admissionHash;
    }

    function admit(
        State storage contentState,
        address registry,
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 hash
    ) public {
        if (contentState.admissionHash != 0 || contentState.active.operationRoot != 0) revert IStreamPreparedNativeMint.InvalidPreparedNativeMint();
        address recorder = StreamPreparedNativeContentValidation.addressWord(
            msg.sender, "primarySaleSettlement()"
        );
        StreamPreparedNativeSettlementTypes.Intent memory i =
            StreamPreparedNativeContentValidation.readIntent(msg.sender, recorder, hash);
        StreamPreparedNativeContentTypes.Facts memory c =
            StreamPreparedNativeContentReads.requireBatch(registry, batch, gateData, hash, i.saleId);
        if (i.contentSelectionHash != c.contentLeaf) {
            revert IStreamPreparedNativeMint.InvalidPreparedNativeMint();
        }
        contentState.admissionHash =
            StreamPreparedNativeContentHash.admissionHash(msg.sender, hash, c);
        _storeContent(contentState.active, c);
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

    function execute(
        StreamPreparedNativeMintExecution.State storage state,
        State storage contentState,
        bytes calldata gateData,
        IStreamMintManager.MintBatch calldata batch,
        StreamPreparedNativeMintExecution.Operation memory op
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
        ) {
            revert IStreamPreparedNativeMint.InvalidPreparedNativeMint();
        }
        StreamPreparedNativeSettlementAdmission.requireModule(op.registry, msg.sender);
        StreamPreparedNativeSettlementTypes.Facts memory f;
        f.saleAdapter = msg.sender;
        f.mintManager = address(this);
        f.recorder = StreamPreparedNativeContentValidation.addressWord(
            msg.sender, "primarySaleSettlement()"
        );
        f.recorderCodeHash =
            StreamPreparedNativeContentValidation.word(msg.sender, "settlementCodeHash()");
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
            StreamPreparedNativeContentValidation.readIntent(msg.sender, f.recorder, f.intentHash);
        StreamPreparedNativeSettlementAdmission.requireAdmission(
            op.registry, msg.sender, intent.saleId
        );
        StreamPreparedNativeContentValidation.requireBindings(
            address(op.core), op.registry, address(this), msg.sender, f.recorder, f.recorderCodeHash
        );
        StreamPreparedNativeContentValidation.requireIntentFields(f, intent);
        StreamPreparedNativeContentTypes.Facts memory content =
            StreamPreparedNativeContentReads.requireBatch(
                op.registry, batch, gateData, op.intentHash, intent.saleId
            );
        if (content.contentLeaf != intent.contentSelectionHash) {
            revert IStreamPreparedNativeMint.InvalidPreparedNativeMint();
        }
        if (
            contentState.admissionHash
                    != StreamPreparedNativeContentHash.admissionHash(
                        msg.sender, op.intentHash, content
                    )
                || keccak256(abi.encode(contentState.active)) != keccak256(abi.encode(content))
        ) revert IStreamPreparedNativeMint.InvalidPreparedNativeMint();
        content.operationRoot = f.operationRoot;
        (f.tokenId, f.collectionSerial) = op.core
            .prepareMintFromManager(
                batch.collectionId, batch.tokenData[0], f.tokenDataHash, f.operationId
            );
        state.active = f;
        if (
            contentState.admissionHash
                != StreamPreparedNativeContentHash.admissionHash(
                    msg.sender, op.intentHash, contentState.active
                )
        ) revert IStreamPreparedNativeMint.InvalidPreparedNativeMint();
        _storeContent(contentState.active, content);
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
        StreamPreparedNativeContentValidation.requireActive(
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
        StreamPreparedNativeContentValidation.requireBindings(
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
        StreamPreparedNativeContentTypes.Facts memory empty;
        _storeContent(contentState.active, empty);
        delete contentState.admissionHash;
    }

    function _callback(StreamPreparedNativeSettlementTypes.Facts memory facts, uint256 cap)
        private
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result)
    {
        bytes memory data = abi.encodeCall(
            IStreamPreparedNativeContentSale.onPreparedNativeContentMint, (facts)
        );
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
                sale, IStreamPreparedNativeContentSale.onPreparedNativeContentMint.selector
            );
        }
        bytes4 magic;
        (magic, result) =
            abi.decode(raw, (bytes4, StreamPrimarySettlementTypes.PrimarySettlementResult));
        if (
            magic != IStreamPreparedNativeContentSale.onPreparedNativeContentMint.selector
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
        bytes memory raw = StreamPreparedNativeContentValidation.read(
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
        raw = StreamPreparedNativeContentValidation.read(
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
        StreamPreparedNativeContentTypes.Facts memory content =
            IStreamPreparedNativeContentMint(address(this)).activePreparedNativeContent();
        if (
            IStreamPreparedNativeContentSettlement(f.recorder)
                    .preparedNativeContentHash(result.settlementKey)
                != StreamPreparedNativeContentHash.factsHash(content)
        ) revert IStreamPreparedNativeMint.PreparedNativeResultMismatch();
        raw = StreamPreparedNativeContentValidation.read(
            f.recorder,
            abi.encodeCall(IStreamPrimarySaleSettlement.settlementConsumed, (result.settlementKey)),
            32
        );
        if (abi.decode(raw, (uint256)) != 1) {
            revert IStreamPreparedNativeMint.PreparedNativeResultMismatch();
        }
    }

    function _storeContent(
        StreamPreparedNativeContentTypes.Facts storage a,
        StreamPreparedNativeContentTypes.Facts memory b
    ) private {
        a.operationRoot = b.operationRoot;
        a.gate = b.gate;
        a.gateCodeHash = b.gateCodeHash;
        a.gateConfigHash = b.gateConfigHash;
        a.manifestRoot = b.manifestRoot;
        a.manifestHash = b.manifestHash;
        a.counterId = b.counterId;
        a.contentId = b.contentId;
        a.tokenDataHash = b.tokenDataHash;
        a.contentLeaf = b.contentLeaf;
        a.contextHash = b.contextHash;
    }
}
