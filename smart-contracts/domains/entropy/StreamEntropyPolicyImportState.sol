// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamEntropyPolicyContinuity as C
} from "../../interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";

/// @notice One-use import session and receipts in the calling Coordinator's separate namespace.
/// @dev A stale session needs a fresh candidate; this namespace intentionally provides no reset.
library StreamEntropyPolicyImportState {
    bytes32 private constant SLOT = keccak256("6529STREAM_ENTROPY_POLICY_IMPORT_STORAGE_V1");
    bytes32 internal constant IMPORT_DOMAIN = keccak256("6529STREAM_ENTROPY_POLICY_IMPORT_V1");

    struct ImportedPolicy {
        bytes32 importHash;
        bytes32 exportHash;
        address policyOrigin;
        bytes32 policyOriginCodeHash;
        bytes32 policyHash;
        bool routeRequired;
        bool routeConfirmed;
    }

    struct ImportedRecovery {
        bytes32 exportHash;
        address policyOrigin;
        bytes32 policyOriginCodeHash;
    }

    struct Store {
        bool everUsed;
        C.ImportReceipt receipt;
        mapping(uint256 => ImportedPolicy) policies;
        mapping(bytes32 => ImportedRecovery) recoveries;
        mapping(bytes32 => bool) actions;
    }

    function store() internal pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function requireOperational() internal view {
        C.ImportState state = store().receipt.state;
        if (state == C.ImportState.STAGING || state == C.ImportState.SEALED) {
            revert C.InvalidEntropyPolicyImport();
        }
    }

    function requireOperationalAndMarkUsed() internal {
        requireOperational();
        store().everUsed = true;
    }

    function receipt() internal view returns (C.ImportReceipt memory) {
        return store().receipt;
    }

    function imported(uint256 id)
        internal
        view
        returns (bytes32, bytes32, address, bytes32, bytes32)
    {
        Store storage s = store();
        ImportedPolicy storage p = s.policies[id];
        if (
            s.receipt.state == C.ImportState.NONE || p.importHash == 0
                || p.importHash != s.receipt.importHash || p.exportHash == 0
        ) revert C.InvalidEntropyPolicyExport(id);
        return (p.importHash, p.exportHash, p.policyOrigin, p.policyOriginCodeHash, p.policyHash);
    }

    /// @dev No source calls. Core authenticates the live header before passing these six words.
    function ready(
        address predecessor,
        bytes32 predecessorCodeHash,
        uint64 pointerRevision,
        uint256 count,
        uint64 serial,
        bytes32 idDigest
    ) internal view returns (bool) {
        C.ImportReceipt storage r = store().receipt;
        return r.state == C.ImportState.SEALED && r.importHash != 0 && r.predecessor == predecessor
            && r.predecessorCodeHash == predecessorCodeHash && r.pointerRevision == pointerRevision
            && r.count == count && r.serial == serial && r.idDigest == idDigest
            && r.nextIndex == r.count && r.requiredRelayCount == r.confirmedRelayCount;
    }
}
