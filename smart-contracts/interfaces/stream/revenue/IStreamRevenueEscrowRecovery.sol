// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamEscrowRecoveryTypes.sol";

/// @notice Additive original RSR-ESCROW-RECOVERY API for captured owed credit.
/// @dev Resident split-wallet funds are outside this interface's authority.
interface IStreamRevenueEscrowRecovery {
    event EscrowRecoveryScheduled(
        uint16 schemaVersion,
        bytes32 indexed recoveryId,
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        address wallet,
        address asset,
        address successorWallet,
        bytes32 successorProfileId,
        uint256 expectedAmount,
        bytes32 recoveryManifestContentHash,
        uint64 executeAfter,
        bytes32 reasonHash,
        string reasonURI
    );

    event EscrowRecoveryCancelled(
        uint16 schemaVersion,
        bytes32 indexed recoveryId,
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        bytes32 reasonHash,
        string reasonURI
    );

    event EscrowRecoveryExecuted(
        uint16 schemaVersion,
        bytes32 indexed recoveryId,
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        address oldWallet,
        address successorWallet,
        uint256 movedAmount,
        bytes32 recoveryManifestContentHash,
        bytes32 reasonHash,
        string reasonURI
    );

    event EscrowRecoveryConsentRecorded(
        uint16 schemaVersion, bytes32 indexed recoveryId, address indexed account, bytes32 nonce
    );

    event EscrowRecoveryConsentRevoked(
        uint16 schemaVersion, bytes32 indexed recoveryId, address indexed account
    );

    function scheduleEscrowRecovery(
        StreamEscrowRecoveryTypes.EscrowCreditKey calldata creditKey,
        address successorWallet,
        bytes32 successorProfileId,
        bytes32 successorRuntimeCodeHash,
        uint256 expectedAmount,
        StreamEscrowRecoveryTypes.EscrowRecoveryManifestRef calldata recoveryManifest,
        uint64 executeAfter,
        bytes32 reasonHash,
        string calldata reasonURI
    ) external returns (bytes32 recoveryId);

    function cancelEscrowRecovery(bytes32 recoveryId, bytes32 reasonHash, string calldata reasonURI)
        external;

    function executeEscrowRecovery(bytes32 recoveryId) external;

    function escrowRecoveryRecord(bytes32 recoveryId)
        external
        view
        returns (StreamEscrowRecoveryTypes.EscrowRecoveryRecord memory);

    /// @notice Records an affected account's original EIP-712 consent.
    /// @dev Consume the account's nonce before writing the consent; use the original
    ///      revenue escrow domain, deadline and ERC-1271/ECDSA verification rules.
    function submitEscrowRecoveryConsent(
        address account,
        bytes32 recoveryId,
        bytes32 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external;

    /// @notice Direct, signature-free consent by the affected account itself.
    function recordEscrowRecoveryConsent(bytes32 recoveryId, bytes32 nonce) external;

    /// @notice The consenting account may revoke unused consent until execution.
    function revokeEscrowRecoveryConsent(bytes32 recoveryId) external;

    function escrowRecoveryConsentRecorded(bytes32 recoveryId, address account)
        external
        view
        returns (bool);

    function isEscrowRecoveryConsentNonceUsed(address account, bytes32 nonce)
        external
        view
        returns (bool);
}
