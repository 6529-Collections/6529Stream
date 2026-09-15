// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrimarySettlementTypes.sol";
import "./IStreamPrimarySettlementBindings.sol";

/// @notice Contract 20: sole payer authorization and allowance-pulling boundary.
interface IStreamERC20PrimarySettlementAdapter is IStreamPrimarySettlementBindings {
    event PaymentIntentConsumed(
        address indexed payer,
        bytes32 indexed saleRef,
        bytes32 indexed nonce,
        uint16 schemaVersion,
        address asset,
        uint256 amount
    );
    event PaymentIntentRevoked(address indexed payer, bytes32 indexed nonce, uint16 schemaVersion);

    function isStreamERC20PrimarySettlementAdapter() external pure returns (bool);
    function primarySaleSettlement() external view returns (address);

    function settleERC20PrimarySaleByPayer(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        bytes calldata saleExecutionData
    ) external returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);

    function settleERC20PrimarySaleWithIntent(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        StreamPrimarySettlementTypes.PaymentIntent calldata intent,
        bytes calldata signature,
        bytes calldata saleExecutionData
    ) external returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);

    function settleERC20PrimarySaleWithEIP2612Permit(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization calldata permit,
        bytes calldata saleExecutionData
    ) external returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);

    function settleERC20PrimarySaleWithPermit2(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate calldata candidate,
        StreamPrimarySettlementTypes.Permit2TransferAuthorization calldata permit,
        bytes calldata saleExecutionData
    ) external returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);

    /// @notice Only the immutable recorder may enter once, during its exact active callback.
    function fundERC20PrimarySale(
        bytes32 candidateCommitment,
        bytes32 settlementKey,
        address asset,
        uint256 amount
    ) external;

    function paymentIntentDigest(StreamPrimarySettlementTypes.PaymentIntent calldata intent)
        external
        view
        returns (bytes32);
    function paymentIntentRevocationDigest(
        StreamPrimarySettlementTypes.PaymentIntentRevocation calldata revocation
    ) external view returns (bytes32);
    function isPaymentIntentNonceUsed(address payer, bytes32 nonce) external view returns (bool);
    function revokePaymentIntent(bytes32 nonce) external;
    function revokePaymentIntentWithSignature(
        StreamPrimarySettlementTypes.PaymentIntentRevocation calldata revocation,
        bytes calldata signature
    ) external;
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
}
