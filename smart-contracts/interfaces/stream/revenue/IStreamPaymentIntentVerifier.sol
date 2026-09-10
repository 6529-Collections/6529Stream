// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Payer consent at the contract that performs an ERC-20 allowance pull.
interface IStreamPaymentIntentVerifier {
    struct PaymentIntent {
        address payer;
        address asset;
        uint256 maxAmount;
        bytes32 saleRef;
        bytes32 expectedPrimaryPolicyHash;
        bytes32 nonce;
        uint64 deadline;
    }

    error InvalidPaymentIntent();
    error PaymentIntentExpired(uint64 deadline);
    error PaymentIntentNonceUsed(address payer, bytes32 nonce);
    error InvalidPaymentSignature(address payer);
    error InsufficientSignatureGas();
    error InvalidSignatureGasLimit();

    event PaymentIntentConsumed(
        address indexed payer,
        bytes32 indexed saleRef,
        bytes32 indexed nonce,
        uint16 schemaVersion,
        address asset,
        uint256 amount
    );
    event PaymentIntentRevoked(address indexed payer, bytes32 indexed nonce, uint16 schemaVersion);
    event SignatureGasLimitRaised(uint256 previousValue, uint256 value);

    /// @notice Returns whether a payer's nonce was consumed or permanently revoked.
    function isPaymentIntentNonceUsed(address payer, bytes32 nonce) external view returns (bool);

    /// @notice Digest of the exact RSR-PAYMENT-INTENT typed payload at this puller.
    function paymentIntentDigest(PaymentIntent calldata intent) external view returns (bytes32);

    /// @notice Digest for a relayed revocation; expiry never reverses a consumed revocation.
    function paymentIntentRevocationDigest(address payer, bytes32 nonce, uint64 deadline)
        external
        view
        returns (bytes32);

    /// @notice Permanently revokes the caller's nonce, including while purchases are paused.
    function revokePaymentIntent(bytes32 nonce) external;

    /// @notice Permanently revokes a payer's nonce after canonical EOA/ERC-1271 verification.
    function revokePaymentIntentBySignature(
        address payer,
        bytes32 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external;

    /// @notice Current bounded ERC-1271 stipend; this adapter's initial value is 400,000.
    function signatureGasLimit() external view returns (uint256);

    /// @notice Owner governance may raise, and cannot lower, the verification stipend.
    function raiseSignatureGasLimit(uint256 value) external;

    /// @notice ERC-5267 description shared by intent, revocation and adapter sale authorizations.
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
