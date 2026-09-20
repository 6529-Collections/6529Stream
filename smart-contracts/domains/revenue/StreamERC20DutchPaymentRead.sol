// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamSettlementAdmission.sol";
import "./StreamPrimarySettlementHash.sol";
import {
    IStreamERC20DutchPayments as D
} from "../../interfaces/stream/revenue/IStreamERC20DutchPayments.sol";
import "../../interfaces/stream/revenue/IStreamERC20DutchFreeExecution.sol";

/// @notice Closed, code-admitted current-price resolution. The host locks before entering.
library StreamERC20DutchPaymentRead {
    error InvalidPaymentCandidate();
    error PaymentCallbackFailed();
    error PaymentCallbackMalformed(uint256 length);

    struct Plan {
        StreamPrimarySettlementTypes.ERC20SettlementCandidate candidate;
        bytes executionData;
        uint8 mode;
        bytes permitInput;
        StreamPrimarySettlementTypes.PaymentIntent intent;
        bytes signature;
        uint256 deadline;
        uint256 permittedAmount;
    }

    function prepare(address registry, address recorder, bytes calldata raw)
        public
        view
        returns (Plan memory p)
    {
        bytes4 selector = bytes4(raw[:4]);
        D.Request memory request;
        if (selector == D.settleERC20DutchSaleByPayer.selector) {
            request = abi.decode(raw[4:], (D.Request));
        } else if (selector == D.settleERC20DutchSaleWithIntent.selector) {
            (request, p.intent, p.signature) =
                abi.decode(raw[4:], (D.Request, StreamPrimarySettlementTypes.PaymentIntent, bytes));
            p.mode = 1;
        } else if (selector == D.settleERC20DutchSaleWithEIP2612Permit.selector) {
            D.EIP2612Maximum memory permit;
            (request, permit) = abi.decode(raw[4:], (D.Request, D.EIP2612Maximum));
            p.mode = 4;
            p.permitInput = abi.encode(permit);
            p.deadline = permit.authorization.deadline;
            p.permittedAmount = permit.permittedAmount;
        } else if (selector == D.settleERC20DutchSaleWithPermit2.selector) {
            D.Permit2Maximum memory permit;
            (request, permit) = abi.decode(raw[4:], (D.Request, D.Permit2Maximum));
            p.mode = 5;
            p.permitInput = abi.encode(permit);
            p.deadline = permit.authorization.deadline;
            p.permittedAmount = permit.permittedAmount;
        } else {
            revert D.InvalidDutchPaymentRequest();
        }
        p.candidate = _resolve(registry, recorder, request);
        p.executionData = request.executionData;
    }

    function _resolve(address registry, address recorder, D.Request memory request)
        private
        view
        returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c)
    {
        if (
            request.saleAdapterCodeHash == 0
                || request.saleAdapter.codehash != request.saleAdapterCodeHash
                || request.saleId == 0 || request.saleConfigHash == 0
        ) revert D.InvalidDutchPaymentRequest();
        StreamSettlementAdmission.requireDutchResolver(registry, request.saleAdapter);
        bytes memory data = abi.encodeCall(
            IStreamERC20DutchSaleResolution.resolveERC20DutchExecution,
            (request.saleId, request.saleConfigHash, msg.sender, request.executionData)
        );
        bytes memory raw = new bytes(1088);
        address target = request.saleAdapter;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), add(raw, 32), 1088)
            size := returndatasize()
        }
        if (!ok) revert D.DutchPaymentResolutionFailed(target);
        if (size != 1088) revert D.DutchPaymentResolutionMalformed(size);
        c = abi.decode(raw, (StreamPrimarySettlementTypes.ERC20SettlementCandidate));
        if (keccak256(raw) != keccak256(abi.encode(c))) {
            revert D.DutchPaymentResolutionMalformed(size);
        }
        if (c.sale.amount > request.maxAmount) {
            revert D.DutchPaymentMaximumExceeded(request.maxAmount, c.sale.amount);
        }
        if (
            c.saleAdapter != target || c.sale.settlementId != request.saleId
                || c.executor != msg.sender || c.lifecycleBinding.paymentAdapter != address(this)
                || c.sale.payer == address(0) || c.sale.payer == address(this)
                || c.sale.payer == recorder || c.sale.expectedPrimaryPolicyHash == 0
                || c.saleExecutionHash != keccak256(request.executionData)
                || c.orchestrationOrder != 1 || c.operationIdentityCommitment == 0
                || c.operationId == 0
                || (c.executionBinding.authorityMode == 1
                        ? c.executionBinding.saleAuthorizationDigest == 0
                        : c.executionBinding.authorityMode != 2
                        || c.executionBinding.saleAuthorizationDigest != 0)
                || c.executionBinding.executionId != StreamPrimarySettlementHash.executionId(c)
        ) revert InvalidPaymentCandidate();
        StreamSettlementAdmission.requireDutchAdmission(registry, address(this), c);
    }

    /// @dev No funding return can run: the host remains AUTHENTICATED, never SALE_CALLBACK.
    function executeFree(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        bytes memory executionData
    ) public returns (bytes32 id) {
        bytes memory data = abi.encodeCall(
            IStreamERC20DutchFreeExecution.executeERC20DutchFreeMint, (c, executionData)
        );
        address target = c.saleAdapter;
        uint256[2] memory words;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(gas(), target, callvalue(), add(data, 32), mload(data), words, 64)
            size := returndatasize()
        }
        if (!ok) revert PaymentCallbackFailed();
        if (size != 64) revert PaymentCallbackMalformed(size);
        if (
            words[0]
                    != uint256(
                            uint32(
                                IStreamERC20DutchFreeExecution.executeERC20DutchFreeMint.selector
                            )
                        ) << 224 || bytes32(words[1]) != c.executionBinding.executionId
        ) revert D.DutchFreeExecutionInvalid();
        return bytes32(words[1]);
    }
}
