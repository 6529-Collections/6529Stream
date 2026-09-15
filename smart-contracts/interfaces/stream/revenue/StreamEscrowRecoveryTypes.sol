// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Original RSR-ESCROW-RECOVERY wire types and preimage constants.
/// @dev These declarations do not grant recovery authority or assert notice delivery.
library StreamEscrowRecoveryTypes {
    bytes32 internal constant RECOVERY_DOMAIN = keccak256("6529STREAM_ESCROW_RECOVERY_V1");
    bytes32 internal constant CONSENT_TYPEHASH = keccak256(
        "StreamEscrowRecoveryConsent(address account,bytes32 recoveryId,bytes32 nonce,uint64 deadline)"
    );

    enum EscrowRecoveryStatus {
        NONE,
        SCHEDULED,
        CANCELLED,
        EXECUTED
    }

    struct EscrowCreditKey {
        bytes32 revenueClass;
        bytes32 profileId;
        address wallet;
        address asset;
    }

    struct EscrowRecoveryManifestRef {
        string uri;
        bytes32 uriHash;
        bytes32 contentHash;
        bytes32 schemaId;
        bytes32 canonicalizationHash;
    }

    struct EscrowRecoveryRecord {
        EscrowRecoveryStatus status;
        EscrowCreditKey creditKey;
        address storedFactory;
        address successorWallet;
        bytes32 successorProfileId;
        bytes32 successorRuntimeCodeHash;
        uint256 expectedAmount;
        EscrowRecoveryManifestRef recoveryManifest;
        uint64 executeAfter;
        bytes32 reasonHash;
        string reasonURI;
    }
}
