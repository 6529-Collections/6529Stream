// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMintGateValidator.sol";
import "../../interfaces/stream/mint/IStreamERC20OfferGate.sol";

/// @notice Dedicated, bounded offer-gate dispatch with a canonical quantity-one result.
library StreamERC20OfferGateValidation {
    error InvalidERC20OfferGate();

    function validate(
        IStreamMintManager.MintBatch calldata batch,
        StreamERC20OfferMintTypes.GateData memory d,
        IStreamMintManager.MintGateConfig memory gate,
        address registry
    ) public view returns (StreamMintOperationIdentity.MintAuthorization memory a) {
        IStreamMintManager.MintGateConfig memory actual =
            StreamMintGateValidator.validateConfiguration(gate, IERC165(registry));
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(gate))) {
            revert InvalidERC20OfferGate();
        }
        a.authorizationId = batch.authorizationId;
        a.authorizer = batch.authorizer;
        a.authorizerKind = IStreamMintManager.AuthorizerKind(d.buyerSignature.kind);
        a.maxQuantity = 1;
        a.nullifiers = new bytes32[](0);
        if (gate.gate == address(0)) return a;

        bytes memory input = abi.encodeCall(
            IStreamERC20OfferGate.validateERC20OfferBatch, (address(this), msg.sender, batch, d)
        );
        uint256 cap = IStreamGasParameterHost(address(this))
            .gasParameter(keccak256("6529STREAM_GGP_MINT_GATE_GAS_LIMIT"));
        if (gate.gateGasLimit > cap) cap = gate.gateGasLimit;
        uint256 required = cap + (cap + 62) / 63 + 40_000;
        if (gasleft() < required) {
            revert StreamMintGateValidator.MintGateInsufficientGas(gasleft(), required);
        }
        // Empty nullifiers make the full dynamic GateResult exactly eight words.
        bytes memory raw = new bytes(256);
        bool ok;
        uint256 size;
        address target = gate.gate;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(raw, 32), 256)
            size := returndatasize()
        }
        if (!ok || size != 256) revert InvalidERC20OfferGate();
        uint256 outerOffset;
        uint256 nullifierOffset;
        uint256 count;
        assembly ("memory-safe") {
            outerOffset := mload(add(raw, 32))
            nullifierOffset := mload(add(raw, 96))
            count := mload(add(raw, 256))
        }
        if (outerOffset != 32 || nullifierOffset != 192 || count != 0) {
            revert InvalidERC20OfferGate();
        }
        IStreamMintGate.GateResult memory result = abi.decode(raw, (IStreamMintGate.GateResult));
        if (
            keccak256(raw) != keccak256(abi.encode(result))
                || result.authorizationId != a.authorizationId || result.authorizer != a.authorizer
                || result.authorizerKind != uint8(a.authorizerKind) || result.maxQuantity != 1
                || result.gateHash == 0
        ) revert InvalidERC20OfferGate();
        a.gateHash = result.gateHash;
    }
}
