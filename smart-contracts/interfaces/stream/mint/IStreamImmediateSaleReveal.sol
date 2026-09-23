// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../entropy/IStreamRevealFeeEscrow.sol";

/// @notice Additive immediate-sale native reveal quote and native-funder excess custody.
/// @dev Native sales use value above their signed amount; token sales use all msg.value.
///      The account named payer here is the native funder: the bound executor for token
///      sales, which can differ from the ERC-20 payer. Amounts here are always wei.
interface IStreamImmediateSaleReveal {
    struct RevealQuote {
        address coordinator;
        bytes32 coordinatorCodeHash;
        IStreamRevealFeeEscrow.CollectionRevealPolicy policy;
    }

    error SaleRevealDependencyInvalid(address target);
    error SaleRevealFeeBelowRequired(uint256 allowance, uint256 required);
    error SaleRevealCallGasInsufficient(uint256 cap, uint256 available);
    error SaleRevealAccountingMismatch();
    error SaleRefundEmpty(bytes32 saleId, address payer);
    error SaleRefundTransferFailed(address recipient);

    event ImmediateRevealAttempt(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint256 indexed tokenId,
        bool succeeded,
        bytes32 requestKey,
        uint256 providerRequestId,
        uint256 returnDataSize,
        bytes failurePrefix
    );
    event SalePaymentExcessCredited(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed payer, uint256 amount
    );
    event SaleRefundClaimed(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed payer,
        address indexed recipient,
        uint256 amount
    );

    /// @notice Live policy, including SLO and fee. Only explicit DISABLED returns an undeclared all-zero policy.
    function saleRevealQuote(bytes32 saleId) external view returns (RevealQuote memory);
    function refundableBalance(bytes32 saleId, address payer) external view returns (uint256);
    function refundLiability() external view returns (uint256);
    /// @notice Only the credited native funder, including a Safe CALL, chooses the destination.
    function claimRefund(bytes32 saleId, address recipient) external;
    /// @notice Append-only state discovery; zero balances remain enumerable after claims.
    function refundAccountCount() external view returns (uint256);
    function refundAccountAt(uint256 index) external view returns (bytes32 saleId, address payer);
}
