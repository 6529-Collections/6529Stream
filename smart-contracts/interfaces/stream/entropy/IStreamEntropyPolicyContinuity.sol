// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC165 } from "../../../vendor/openzeppelin/IERC165.sol";
import { IStreamEntropyCollectionPolicy as P } from "./IStreamEntropyCollectionPolicy.sol";
import { IStreamEntropyCollectionRecovery as C } from "./IStreamEntropyCollectionRecovery.sol";
import { IStreamEntropyRecoveryPolicies as R } from "./IStreamEntropyRecoveryPolicies.sol";

/// @notice Exact legacy or explicit policy import, retaining the ultimate origin.
/// @dev Additive interface. Existing policy and recovery tuples are
/// unchanged. Imports do not transfer subjects, escrow, credits, or original action ownership.
interface IStreamEntropyPolicyContinuity is IERC165 {
    enum PolicyProfile {
        LEGACY,
        EXPLICIT
    }

    enum ImportState {
        NONE,
        STAGING,
        SEALED,
        ACTIVE
    }

    /// @dev The twelve record words and both nested inputs are copied without rewriting receipts.
    /// policyHash is recomputed using policyOrigin, never the importing Coordinator.
    /// LEGACY retains ASYNC/HIGH_ASSURANCE/REQUIRED and zero explicit revision/action/Artist receipt.
    /// Its original policy and salt hashes are preserved; an undeclared reveal retains policyHash
    /// zero and never becomes an invented declared zero-fee policy.
    struct PolicyExport {
        uint256 collectionId;
        PolicyProfile profile;
        address policyOrigin;
        bytes32 policyOriginCodeHash;
        P.PolicyRecord record;
        P.PolicyInput policy;
        bytes32 providerCodeHash;
        bytes32 providerConfigHash;
        C.CollectionRecovery recovery;
    }

    /// @dev Complete frozen definition, including at most 32 original ordered recovery steps.
    /// Original revision, action, and replacement terms remain distinct from import authorization.
    struct RecoveryExport {
        bytes32 policyId;
        R.FreshRecoveryPolicy policy;
        bytes32 policyHash;
        uint64 revision;
        bytes32 lastActionId;
        address policyOrigin;
        bytes32 policyOriginCodeHash;
        address successor;
        bytes32 successorCodeHash;
    }

    /// @dev count, serial, idDigest retain the inventory header's canonical order. importHash is
    /// fixed at begin; seal separately commits exportDigest. ACTIVE is a latched receipt, so later
    /// source operational fees and balances cannot invalidate its historical evidence.
    struct ImportReceipt {
        ImportState state;
        uint64 nonce;
        address predecessor;
        bytes32 predecessorCodeHash;
        uint64 pointerRevision;
        uint256 count;
        uint64 serial;
        bytes32 idDigest;
        bytes32 manifestHash;
        uint256 nextIndex;
        bytes32 exportDigest;
        uint256 requiredRelayCount;
        uint256 confirmedRelayCount;
        bytes32 importHash;
        bytes32 beginActionId;
        bytes32 sealActionId;
        bytes32 activationActionId;
    }

    error InvalidEntropyPolicyImport();
    error EntropyPolicyImportState(ImportState expected, ImportState actual);
    error EntropyPolicyImportNotFresh();
    error EntropyPolicyImportDependency(address target);
    error EntropyPolicyImportSourceChanged(address predecessor);
    error EntropyPolicyImportIndex(uint256 expectedIndex, uint256 nextIndex);
    error EntropyPolicyImportReplay(bytes32 actionId);
    error InvalidEntropyPolicyExport(uint256 collectionId);
    error InvalidEntropyRecoveryExport(bytes32 policyId);
    error EntropyPolicyRelayUnconfirmed(uint256 collectionId);

    event EntropyPolicyImportBegun(
        uint16 schemaVersion,
        bytes32 indexed importHash,
        address indexed predecessor,
        uint64 nonce,
        bytes32 predecessorCodeHash,
        uint64 pointerRevision,
        uint256 count,
        uint64 serial,
        bytes32 idDigest,
        bytes32 manifestHash,
        bytes32 actionId
    );
    event EntropyPolicyImported(
        uint16 schemaVersion,
        bytes32 indexed importHash,
        uint256 indexed collectionId,
        address indexed policyOrigin,
        uint256 index,
        bytes32 policyOriginCodeHash,
        bytes32 policyHash,
        bytes32 exportDigest
    );
    event EntropyRecoveryPolicyImported(
        uint16 schemaVersion,
        bytes32 indexed importHash,
        bytes32 indexed policyId,
        address indexed policyOrigin,
        bytes32 policyOriginCodeHash,
        bytes32 policyHash
    );
    event EntropyRelayRouteConfirmed(
        uint16 schemaVersion,
        bytes32 indexed importHash,
        uint256 indexed collectionId,
        address indexed policyOrigin,
        bytes32 policyHash
    );
    event EntropyPolicyImportSealed(
        uint16 schemaVersion,
        bytes32 indexed importHash,
        bytes32 exportDigest,
        uint256 count,
        uint256 confirmedRelayCount,
        bytes32 actionId
    );
    event EntropyPolicyImportActivated(
        uint16 schemaVersion, bytes32 indexed importHash, bytes32 actionId
    );

    /// @notice Direct local header; its digest commits to ordered IDs, not policy contents.
    function entropyPolicyInventory()
        external
        view
        returns (uint256 count, uint64 serial, bytes32 idDigest);
    function entropyPolicyCollectionAt(uint256 index) external view returns (uint256 collectionId);
    /// @notice Direct local export preserving the ultimate origin and original policy receipts.
    function exportEntropyPolicy(uint256 collectionId) external view returns (PolicyExport memory);
    function exportEntropyRecovery(bytes32 policyId) external view returns (RecoveryExport memory);
    function entropyPolicyImport() external view returns (ImportReceipt memory);
    /// @notice Direct receipt proving this exact authoritative collection was already copied.
    /// @dev Reverts for zero or unimported evidence and authenticates the exact staged generation.
    /// exportHash is computed from the copied export, never supplied by the importing caller.
    function importedEntropyPolicy(uint256 collectionId)
        external
        view
        returns (
            bytes32 importHash,
            bytes32 exportHash,
            address policyOrigin,
            bytes32 policyOriginCodeHash,
            bytes32 policyHash
        );
    /// @notice STATIC-safe admission evidence for the exact source pointer and inventory header.
    /// @dev This read never activates storage. Source authenticity is checked by the admitting host.
    function entropyPolicyImportReady(
        address predecessor,
        bytes32 predecessorCodeHash,
        uint64 pointerRevision,
        uint256 count,
        uint64 serial,
        bytes32 idDigest
    ) external view returns (bool);

    /// @notice Starts an exact class-1 governed session on an irreversibly unused candidate.
    function beginEntropyPolicyImport(address predecessor, bytes32 manifestHash) external;
    /// @notice Permissionless next-index copy from the pinned source; no caller-supplied contents.
    function importNextEntropyPolicy(uint256 expectedIndex) external;
    /// @notice Records an origin admission for an imported collection, counted at most once.
    function confirmEntropyRelayRoute(uint256 collectionId) external;
    /// @notice Exact class-1 seal after all exports and required routes have been authenticated.
    function sealEntropyPolicyImport() external;
    /// @notice Exact class-3 activation in the same atomic batch as Core pointer replacement.
    function activateEntropyPolicyImport() external;
    function entropyPolicyImportTransition(address predecessor, bytes32 manifestHash)
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function entropyPolicyImportSealTransition()
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
    function entropyPolicyImportActivationTransition()
        external
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash);
}
