// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamEscrowRecoveryTypes as R
} from "../../interfaces/stream/revenue/StreamEscrowRecoveryTypes.sol";
import {
    IStreamRevenueEscrowRecoveryManifest as M
} from "../../interfaces/stream/revenue/IStreamRevenueEscrowRecoveryManifest.sol";

/// @notice Additive recovery records only; original escrow credits remain the sole owed ledger.
library StreamEscrowRecoveryState {
    bytes32 internal constant SLOT = keccak256("6529STREAM_ESCROW_RECOVERY_STORAGE_V1");
    bytes32 internal constant MANIFEST_DOMAIN = keccak256("6529STREAM_ESCROW_RECOVERY_MANIFEST_V1");
    bytes32 internal constant MANIFEST_SCHEMA = keccak256("STREAM_ESCROW_RECOVERY_MANIFEST_V1");
    bytes32 internal constant CANONICALIZATION = keccak256("6529STREAM_ESCROW_RECOVERY_ABI_V1");
    bytes32 internal constant TRANSITION_DOMAIN =
        keccak256("6529STREAM_ESCROW_RECOVERY_TRANSITION_V1");

    struct Context {
        address factory;
        address authority;
        address assetRegistry;
        bytes32 factoryCodeHash;
        bytes32 walletCodeHash;
        bytes32 originalInitCodeHash;
        bytes32 originalProfileDomain;
        uint16 originalSchemaVersion;
        uint16 originalWalletVersion;
        address runtimeRegistry;
        bytes32 runtimeRegistryCodeHash;
    }

    struct Origin {
        bytes32 authorityCodeHash;
        bytes32 profileDomain;
        bytes32 initCodeHash;
        uint16 schemaVersion;
        uint16 walletVersion;
    }

    struct Manifest {
        bytes canonicalDocument;
        bytes32 oldEntriesHash;
        bytes32 successorEntriesHash;
        address[] affectedAccounts;
        uint64 publishedAt;
    }

    struct Recovery {
        R.EscrowRecoveryRecord record;
        bytes32 scheduledActionId;
        bytes32 cancelledActionId;
        bytes32 terminalActionId;
        uint64 scheduledAt;
        uint64 terminalAuthorizedAt;
    }

    struct State {
        Origin origin;
        mapping(bytes32 => Manifest) manifests;
        mapping(bytes32 => Recovery) recoveries;
        mapping(address => mapping(bytes32 => bool)) usedConsentNonces;
        mapping(bytes32 => mapping(address => bool)) consents;
    }

    error InvalidEscrowRecoveryManifest();
    error InvalidEscrowRecoveryState(bytes32 recoveryId);
    error InvalidEscrowRecoveryAction();
    error EscrowRecoveryConsentMissing(bytes32 recoveryId, address account);
    error EscrowRecoveryConsentInvalid();
    error EscrowRecoveryReadFailed(address target, bytes4 selector);
    error EscrowRecoveryDelayNotElapsed(uint256 earliest);
    error EscrowRecoveryIncidentRequired();

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function keyHash(R.EscrowCreditKey memory key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key.revenueClass, key.profileId, key.wallet, key.asset));
    }

    function requireReference(R.EscrowRecoveryManifestRef memory ref) internal pure {
        if (
            ref.contentHash == 0 || ref.schemaId != MANIFEST_SCHEMA
                || ref.canonicalizationHash != CANONICALIZATION || bytes(ref.uri).length == 0
                || bytes(ref.uri).length > 2048 || ref.uriHash != keccak256(bytes(ref.uri))
        ) revert InvalidEscrowRecoveryManifest();
    }

    function document(Manifest storage item) internal view returns (M.ManifestDocument memory) {
        return abi.decode(item.canonicalDocument, (M.ManifestDocument));
    }
}
