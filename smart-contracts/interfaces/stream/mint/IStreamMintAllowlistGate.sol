// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintBatchGate.sol";

/// @notice Signature-free allowlist eligibility joined to a required durable Merkle counter.
interface IStreamMintAllowlistGate is IStreamMintGate, IStreamMintBatchGate {
    error MintAllowlistGateInvalidConfiguration();
    error MintAllowlistGateFullBatchRequired();
    error MintAllowlistGateManagerMismatch(address manager);
    error MintAllowlistGatePolicyMismatch(bytes32 policy);
    error MintAllowlistGateCounterRequired(bytes32 counterId);
    error MintAllowlistGateCounterMismatch(bytes32 counterId);
    error MintAllowlistGatePayloadMismatch();
    error MintAllowlistGateAuthorizationMismatch(bytes32 expected, bytes32 supplied);

    function capRoot() external view returns (bytes32);
    function counterId() external view returns (bytes32);
    function gateConfigHash() external view returns (bytes32);

    /// @notice Validates this gate's evidence and derives the ID before filling batch.authorizationId.
    /// @dev Does not consume replay/counters or validate the proofs of other configured counters.
    function previewAuthorizationId(
        address manager,
        address executor,
        IStreamMintManager.MintBatch calldata batch,
        bytes32 nonce
    ) external view returns (bytes32);
}
