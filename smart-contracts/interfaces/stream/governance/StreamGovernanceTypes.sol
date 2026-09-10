// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Scheduled governance action lifecycle states pinned by ADR 0004
///         (`docs/adr/0004-admin-governance.md`, Scheduled Action State).
enum GovernanceActionStatus {
    NONE,
    SCHEDULED,
    CANCELLED,
    EXECUTED,
    EXPIRED,
    VETOED
}

/// @notice One call inside a governance action batch ([GOV-ACTION-ID]).
struct GovernanceCall {
    address target;
    uint256 value;
    bytes4 selector;
    bytes32 callDataHash; // keccak256(callData)
    bytes32 scopeHash; // target-specific transition scope
    bytes32 oldValueHash; // target-specific pre-state commitment
    bytes32 newValueHash; // target-specific post-state commitment
}

/// @notice Stored governance action record pinned by ADR 0004.
/// @dev For batches, `callHash` stores the [GOV-ACTION-ID] `callsHash` and
///     `target`/`selector` are those of the first call for indexing; `value`
///     is the batch value sum ([GOV-BATCH] rule 3).
struct GovernanceAction {
    GovernanceActionStatus status;
    uint8 actionClass;
    address target;
    uint256 value;
    bytes4 selector;
    bytes32 callHash;
    bytes32 scopeHash;
    bytes32 oldValueHash;
    bytes32 newValueHash;
    uint64 notBefore;
    uint64 expiresAfter;
    address proposer;
    address executor;
    address canceller;
    address vetoer;
    bytes32 reasonHash;
    string reasonURI;
    bytes32 manifestHash;
}

/// @notice Single-call scheduling request pinned by ADR 0004; the wrapper must
///         produce a byte-identical action ID to the equivalent one-call batch.
struct GovernanceActionRequest {
    uint8 actionClass;
    address target;
    uint256 value;
    bytes4 selector;
    bytes callData;
    bytes32 scopeHash;
    bytes32 oldValueHash;
    bytes32 newValueHash;
    uint64 notBefore;
    uint64 expiresAfter;
    bytes32 reasonHash;
    string reasonURI;
    bytes32 manifestHash;
}

/// @notice One closed-world governance call policy bound during the one-way
///         system-manifest bootstrap.
/// @dev Entries are keyed by the exact `(actionClass, target, selector)` tuple.
///      `callType` is `1` for a direct selector-bearing contract call and `2`
///      for an empty-calldata native transfer. `valuePolicy` is `0` for
///      zero-only, `1` for an exact nonzero value, and `2` for a bounded
///      nonzero value. Nonzero policies must carry the canonical value
///      semantics hash defined by the implementation.
struct GovernanceActionPolicyEntry {
    uint8 actionClass;
    address target;
    bytes4 selector;
    bytes32 targetCodeHash;
    bytes32 targetProfileHash;
    uint8 callType;
    uint8 valuePolicy;
    uint256 valueLimit;
    bytes32 valueSemanticsHash;
}

/// @notice Launch-v1 governance action classes as rebaselined by ADR 0017.
/// @dev Numeric IDs are append-only. ID 6 is retired pre-genesis, forbidden,
///      and must never be reassigned.
library StreamGovernanceActionClasses {
    uint8 internal constant IMMEDIATE_TIGHTENING = 0;
    uint8 internal constant DELAYED_LOOSENING = 1;
    uint8 internal constant TERMINAL_FREEZE = 2;
    uint8 internal constant POINTER_REPLACEMENT = 3;
    uint8 internal constant FUNDS_RECOVERY = 4;
    uint8 internal constant SUCCESSOR_DECLARATION = 5;
}

/// @notice One immutable manifest-tail trigger rule.
struct ManifestTailTriggerRule {
    bytes32 triggerCodeHash;
    uint8 allowedActionClassMask;
}

/// @notice One append-only manifest-tail trigger key.
struct ManifestTailTriggerEntry {
    address triggerTarget;
    bytes4 triggerSelector;
}

/// @notice One expected genesis manifest-tail trigger.
struct SystemManifestBootstrapTriggerExpectation {
    address triggerTarget;
    bytes4 triggerSelector;
    bytes32 triggerCodeHash;
    uint8 allowedActionClassMask;
}

/// @notice Irreversible downstream binding supplied after executor-first deployment.
struct SystemManifestBootstrapBinding {
    address roleRegistry;
    address governanceRoot;
    bytes32 governanceRootCodeHash;
    address[] initialTerminalFreezeVetoGuardians;
    address core;
    address systemManifestSatellite;
    bytes32 expectedManifestHash;
    bytes32 expectedInventoryStateRoot;
    uint64 expectedInventoryLeafCount;
    SystemManifestBootstrapTriggerExpectation[] expectedTriggers;
    bytes32[] pointerTypes;
    address[] registries;
    bytes32 actionPolicyCandidateProfileHash;
    bytes32 expectedActionPolicyCatalogHash;
    GovernanceActionPolicyEntry[] actionPolicies;
}
