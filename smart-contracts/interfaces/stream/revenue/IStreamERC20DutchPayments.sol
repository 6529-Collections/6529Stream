// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrimarySettlementTypes.sol";

/// @notice Additive standard Dutch payment entries; original fixed candidate entries are unchanged.
interface IStreamERC20DutchPayments {
    struct Request {
        address saleAdapter;
        bytes32 saleAdapterCodeHash;
        bytes32 saleId;
        bytes32 saleConfigHash;
        uint256 maxAmount;
        bytes executionData;
    }

    /// @dev The signed permit value is a ceiling, independently of the actual transfer amount.
    struct EIP2612Maximum {
        uint256 permittedAmount;
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization authorization;
    }

    /// @dev Permit2 TokenPermissions.amount is the maximum; requestedAmount is the current price.
    struct Permit2Maximum {
        uint256 permittedAmount;
        StreamPrimarySettlementTypes.Permit2TransferAuthorization authorization;
    }

    struct Result {
        uint8 revenueOutcome; // FREE=1, PAID=2.
        bytes32 executionId;
        // All-zero for FREE: an amount-zero official settlement never exists.
        StreamPrimarySettlementTypes.PrimarySettlementResult settlement;
    }

    error InvalidDutchPaymentRequest();
    error DutchPaymentResolutionFailed(address saleAdapter);
    error DutchPaymentResolutionMalformed(uint256 length);
    error DutchPaymentMaximumExceeded(uint256 maximum, uint256 currentAmount);
    error DutchFreeExecutionInvalid();

    function settleERC20DutchSaleByPayer(Request calldata request)
        external
        payable
        returns (Result memory);
    function settleERC20DutchSaleWithIntent(
        Request calldata request,
        StreamPrimarySettlementTypes.PaymentIntent calldata intent,
        bytes calldata signature
    ) external payable returns (Result memory);
    function settleERC20DutchSaleWithEIP2612Permit(
        Request calldata request,
        EIP2612Maximum calldata permit
    ) external payable returns (Result memory);
    function settleERC20DutchSaleWithPermit2(
        Request calldata request,
        Permit2Maximum calldata permit
    ) external payable returns (Result memory);
}
