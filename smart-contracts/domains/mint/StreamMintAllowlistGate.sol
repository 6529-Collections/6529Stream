// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamMintAllowlistGate.sol";
import "./StreamMintCounterPolicy.sol";
import {
    IStreamAllowlistManagerLedger
} from "../../interfaces/stream/mint/IStreamAllowlistManagerLedger.sol";

/// @notice Immutable allowlist gate that requires matching Manager/Ledger cap accounting.
/// @dev Holds no allowance or replay state. All supplied Merkle caps are still reverified
/// by Manager and consumed atomically in Ledger before the actual Core mint.
contract StreamMintAllowlistGate is IStreamMintAllowlistGate {
    bytes32 public constant CONFIG_DOMAIN = keccak256("6529STREAM_MINT_ALLOWLIST_GATE_CONFIG_V1");
    bytes32 private constant AUTHORIZATION_DOMAIN =
        keccak256("6529STREAM_MINT_ALLOWLIST_GATE_AUTHORIZATION_V1");
    bytes32 private constant NULLIFIER_DOMAIN =
        keccak256("6529STREAM_MINT_ALLOWLIST_GATE_NONCE_V1");
    bytes32 private constant RESULT_DOMAIN = keccak256("6529STREAM_MINT_ALLOWLIST_GATE_RESULT_V1");
    bytes32 private constant LEAVES_DOMAIN = keccak256("6529STREAM_MINT_ALLOWLIST_GATE_LEAVES_V1");
    bytes32 private constant PROOF_VALUES_DOMAIN =
        keccak256("6529STREAM_MINT_ALLOWLIST_GATE_PROOF_VALUES_V1");
    bytes32 private constant RECIPIENTS_DOMAIN = keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1");
    bytes32 private constant BENEFICIARIES_DOMAIN =
        keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1");
    bytes32 private constant TOKEN_DATA_DOMAIN = keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1");
    bytes32 private constant COMMITMENTS_DOMAIN = keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1");

    bytes32 public immutable override capRoot;
    bytes32 public immutable override counterId;
    bytes32 public immutable override gateConfigHash;

    struct CounterBinding {
        address ledger;
        uint256 proofIndex;
        uint256 merkleCount;
        bytes32[] merkleIds;
        IStreamMintManager.MintCounterConfig config;
    }

    struct AuthorizationBinding {
        address manager;
        address ledger;
        address executor;
        uint256 collectionId;
        bytes32 phaseId;
        address payer;
        bytes32 expectedPolicyHash;
        bytes32 contextHash;
        bytes32 initialRecipientsHash;
        bytes32 beneficiariesHash;
        bytes32 tokenDataHash;
        bytes32 mintCommitmentsHash;
        bytes32 proofValuesHash;
        bytes32 nonce;
    }

    constructor(bytes32 root, bytes32 requiredCounterId) {
        if (root == bytes32(0) || requiredCounterId == bytes32(0)) {
            revert MintAllowlistGateInvalidConfiguration();
        }
        capRoot = root;
        counterId = requiredCounterId;
        gateConfigHash = keccak256(abi.encode(CONFIG_DOMAIN, root, requiredCounterId));
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamMintGate).interfaceId
            || id == type(IStreamMintBatchGate).interfaceId
            || id == type(IStreamMintAllowlistGate).interfaceId;
    }

    /// @notice The retained narrow ABI cannot bind the full request and fails closed.
    function validateMint(
        address,
        address,
        uint256,
        bytes32,
        address,
        address,
        address[] memory,
        address[] memory,
        bytes32,
        bytes32,
        bytes memory
    ) public pure override returns (GateResult memory) {
        revert MintAllowlistGateFullBatchRequired();
    }

    /// @param gateData Exactly abi.encode(bytes32 nonce); proofs are in batch.resolverData.
    function validateMintBatch(
        address manager,
        address executor,
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData
    ) external view override returns (GateResult memory result) {
        if (msg.sender != manager) {
            revert MintAllowlistGateManagerMismatch(manager);
        }
        if (gateData.length != 32) revert MintAllowlistGatePayloadMismatch();
        result = _validate(manager, executor, batch, abi.decode(gateData, (bytes32)));
        if (batch.authorizationId != result.authorizationId) {
            revert MintAllowlistGateAuthorizationMismatch(
                result.authorizationId, batch.authorizationId
            );
        }
    }

    function previewAuthorizationId(
        address manager,
        address executor,
        IStreamMintManager.MintBatch calldata batch,
        bytes32 nonce
    ) external view override returns (bytes32) {
        return _validate(manager, executor, batch, nonce).authorizationId;
    }

    function _validate(
        address manager,
        address executor,
        IStreamMintManager.MintBatch calldata batch,
        bytes32 nonce
    ) private view returns (GateResult memory result) {
        _requireBatch(executor, batch);
        CounterBinding memory binding = _counter(manager, batch);
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs =
            abi.decode(batch.resolverData, (IStreamMintCounterPolicy.AllowlistProof[][]));
        if (proofs.length != binding.merkleCount) {
            revert IStreamMintCounterPolicy.MintAllowlistProofCountMismatch(
                proofs.length, binding.merkleCount
            );
        }
        bytes32[] memory leaves =
            _acceptedLeaves(manager, batch, binding.config, proofs[binding.proofIndex]);
        result.authorizationId = _authorizationId(manager, executor, batch, binding, proofs, nonce);
        result.nullifiers = new bytes32[](1);
        result.nullifiers[0] = keccak256(
            abi.encode(
                NULLIFIER_DOMAIN,
                block.chainid,
                address(this),
                manager,
                binding.ledger,
                batch.collectionId,
                batch.phaseId,
                batch.payer,
                nonce
            )
        );
        result.authorizer = address(0);
        result.authorizerKind = uint8(IStreamMintManager.AuthorizerKind.NONE);
        result.maxQuantity = uint64(batch.initialRecipients.length);
        result.gateHash = keccak256(
            abi.encode(
                RESULT_DOMAIN,
                gateConfigHash,
                result.authorizationId,
                keccak256(abi.encode(LEAVES_DOMAIN, leaves))
            )
        );
    }

    function _requireBatch(address executor, IStreamMintManager.MintBatch calldata batch)
        private
        pure
    {
        uint256 count = batch.initialRecipients.length;
        if (
            count == 0 || count > type(uint64).max || batch.authorizer != address(0)
                || executor == address(0) || batch.payer == address(0) || batch.collectionId == 0
                || batch.phaseId == 0 || count != batch.beneficiaries.length
                || count != batch.tokenData.length || count != batch.mintCommitments.length
        ) revert MintAllowlistGatePayloadMismatch();
        for (uint256 i; i < count; ++i) {
            if (batch.initialRecipients[i] == address(0) || batch.beneficiaries[i] == address(0)) {
                revert MintAllowlistGatePayloadMismatch();
            }
        }
    }

    function _counter(address manager, IStreamMintManager.MintBatch calldata batch)
        private
        view
        returns (CounterBinding memory binding)
    {
        if (manager.code.length == 0) revert MintAllowlistGateManagerMismatch(manager);
        IStreamMintManager source = IStreamMintManager(manager);
        IStreamMintManager.MintGateConfig memory gate =
            source.phaseGate(batch.collectionId, batch.phaseId);
        if (
            gate.gate != address(this) || gate.gateConfigHash != gateConfigHash
                || gate.gateCodehash != address(this).codehash
        ) revert MintAllowlistGateInvalidConfiguration();
        bytes32 policy = batch.expectedPolicyHash;
        if (policy == bytes32(0)) revert MintAllowlistGatePolicyMismatch(policy);
        if (source.phasePolicyHash(batch.collectionId, batch.phaseId) != policy) {
            (bytes32 previous, uint64 until) =
                source.phasePolicyGrace(batch.collectionId, batch.phaseId);
            if (policy != previous || block.timestamp > until) {
                revert MintAllowlistGatePolicyMismatch(policy);
            }
        }
        binding.ledger = IStreamAllowlistManagerLedger(manager).mintLedger();
        if (binding.ledger.code.length == 0) revert MintAllowlistGateManagerMismatch(manager);
        bytes32[] memory ids = source.phaseCounterIds(batch.collectionId, batch.phaseId);
        binding.merkleIds = new bytes32[](ids.length);
        bool found;
        for (uint256 i; i < ids.length; ++i) {
            IStreamMintManager.MintCounterConfig memory config =
                source.counterConfig(batch.collectionId, batch.phaseId, ids[i]);
            if (ids[i] == counterId) {
                if (found) revert MintAllowlistGateCounterMismatch(counterId);
                found = true;
                binding.config = config;
                binding.proofIndex = binding.merkleCount;
            }
            if (config.capMode == IStreamMintLedger.CounterCapMode.MERKLE_STATIC) {
                binding.merkleIds[binding.merkleCount++] = ids[i];
            }
        }
        if (!found) revert MintAllowlistGateCounterRequired(counterId);
        _requireCounter(manager, batch, binding);
    }

    function _requireCounter(
        address manager,
        IStreamMintManager.MintBatch calldata batch,
        CounterBinding memory binding
    ) private view {
        IStreamMintManager.MintCounterConfig memory config = binding.config;
        if (
            !config.enabled || config.capMode != IStreamMintLedger.CounterCapMode.MERKLE_STATIC
                || config.deltaMode != IStreamMintLedger.CounterDeltaMode.STATIC
                || config.staticCap == 0 || config.staticIncrement == 0
                || (config.keyMode != IStreamMintManager.CounterKeyMode.RECIPIENT
                    && config.keyMode != IStreamMintManager.CounterKeyMode.PAYER)
        ) revert MintAllowlistGateCounterMismatch(counterId);
        (bool exists, IStreamMintCounterPolicy.Definition memory definition) = IStreamMintCounterPolicy(
                binding.ledger
            ).counterDefinitionForManager(manager, config.counterConfigHash);
        if (
            !exists || definition.capRoot != capRoot || definition.keyMode != config.keyMode
                || definition.scope == IStreamMintCounterPolicy.CounterScope.GLOBAL
                || StreamMintCounterPolicy.definitionHash(definition) != config.counterConfigHash
        ) {
            revert MintAllowlistGateCounterMismatch(counterId);
        }
        IStreamMintLedger.LedgerCounterPolicy memory registered = IStreamMintLedger(binding.ledger)
            .registeredCounterPolicy(manager, batch.collectionId, batch.phaseId, counterId);
        if (
            !registered.enabled || registered.capMode != config.capMode
                || registered.deltaMode != config.deltaMode
                || registered.staticCap != config.staticCap
                || registered.staticIncrement != config.staticIncrement
                || registered.counterConfigHash != config.counterConfigHash
        ) revert MintAllowlistGateCounterMismatch(counterId);
    }

    function _acceptedLeaves(
        address manager,
        IStreamMintManager.MintBatch calldata batch,
        IStreamMintManager.MintCounterConfig memory config,
        IStreamMintCounterPolicy.AllowlistProof[] memory proofs
    ) private view returns (bytes32[] memory leaves) {
        bool payer = config.keyMode == IStreamMintManager.CounterKeyMode.PAYER;
        uint256 count = payer ? 1 : batch.beneficiaries.length;
        if (proofs.length != count) {
            revert IStreamMintCounterPolicy.MintAllowlistProofCountMismatch(proofs.length, count);
        }
        leaves = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            address account = payer ? batch.payer : batch.beneficiaries[i];
            StreamMintCounterPolicy.validateSupportedPrice(counterId, account, proofs[i]);
            bytes32 leaf = StreamMintCounterPolicy.allowlistLeaf(
                manager, batch.collectionId, batch.phaseId, counterId, account, proofs[i]
            );
            if (
                proofs[i].maxCount == 0 || proofs[i].maxCount > config.staticCap
                    || !StreamMintCounterPolicy.verify(capRoot, leaf, proofs[i].proof)
            ) {
                revert IStreamMintCounterPolicy.MintAllowlistProofInvalid(counterId, account);
            }
            leaves[i] = leaf;
        }
    }

    function _authorizationId(
        address manager,
        address executor,
        IStreamMintManager.MintBatch calldata batch,
        CounterBinding memory counter,
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs,
        bytes32 nonce
    ) private view returns (bytes32) {
        AuthorizationBinding memory binding;
        binding.manager = manager;
        binding.ledger = counter.ledger;
        binding.executor = executor;
        binding.collectionId = batch.collectionId;
        binding.phaseId = batch.phaseId;
        binding.payer = batch.payer;
        binding.expectedPolicyHash = batch.expectedPolicyHash;
        binding.contextHash = batch.contextHash;
        binding.initialRecipientsHash =
            keccak256(abi.encode(RECIPIENTS_DOMAIN, batch.initialRecipients));
        binding.beneficiariesHash = keccak256(abi.encode(BENEFICIARIES_DOMAIN, batch.beneficiaries));
        binding.tokenDataHash = keccak256(abi.encode(TOKEN_DATA_DOMAIN, batch.tokenData));
        binding.mintCommitmentsHash =
            keccak256(abi.encode(COMMITMENTS_DOMAIN, batch.mintCommitments));
        binding.proofValuesHash = _proofValuesHash(counter.merkleIds, proofs);
        binding.nonce = nonce;
        return keccak256(
            abi.encode(AUTHORIZATION_DOMAIN, block.chainid, address(this), gateConfigHash, binding)
        );
    }

    function _proofValuesHash(
        bytes32[] memory ids,
        IStreamMintCounterPolicy.AllowlistProof[][] memory proofs
    ) private pure returns (bytes32) {
        bytes32[] memory groups = new bytes32[](proofs.length);
        for (uint256 i; i < proofs.length; ++i) {
            bytes32[] memory values = new bytes32[](proofs[i].length);
            for (uint256 j; j < values.length; ++j) {
                IStreamMintCounterPolicy.AllowlistProof memory proof = proofs[i][j];
                values[j] = keccak256(
                    abi.encode(proof.maxCount, proof.hasPriceOverride, proof.priceOverride)
                );
            }
            groups[i] = keccak256(abi.encode(ids[i], values));
        }
        return keccak256(abi.encode(PROOF_VALUES_DOMAIN, groups));
    }
}
