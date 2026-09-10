// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGovernanceTypes.sol";

/// @notice Action, authority, execution-context, manifest, and terminal-veto discovery.
/// @dev Caller ABI for the same Executor address. Discovery continues to use
///      IStreamGovernanceExecutor; this caller subset is not a new ERC165 claim.
interface IStreamGovernanceReads {
    /// @notice Returns the stored action; while `SCHEDULED` and past
    ///         `expiresAfter`, the returned status is virtually `EXPIRED`.
    function governanceAction(bytes32 actionId) external view returns (GovernanceAction memory);

    /// @notice Returns the next nonce consumed by scheduling.
    function governanceNonce() external view returns (uint256);

    /// @notice Returns whether the address currently has explicit proposer admission.
    function isProposer(address account) external view returns (bool);

    /// @notice Returns whether the address currently has explicit canceller admission.
    function isCanceller(address account) external view returns (bool);

    /// @notice Returns whether the receiver is admitted for native transfers.
    function isApprovedNativeReceiver(address receiver) external view returns (bool);

    /// @notice Returns whether the target selector is registered as tightening.
    function isTighteningCall(address target, bytes4 selector) external view returns (bool);

    /// @notice Returns whether the target selector is registered as terminal freeze.
    function isFreezeSelector(address target, bytes4 selector) external view returns (bool);

    /// @notice Returns proposer admission, its revision, and committed state hash.
    function proposerConfig(address account)
        external
        view
        returns (bool enabled, uint64 revision, bytes32 stateHash);

    /// @notice Returns canceller admission, its revision, and committed state hash.
    function cancellerConfig(address account)
        external
        view
        returns (bool enabled, uint64 revision, bytes32 stateHash);

    /// @notice Returns receiver admission, its revision, and committed state hash.
    function approvedNativeReceiverConfig(address receiver)
        external
        view
        returns (bool approved, uint64 revision, bytes32 stateHash);

    /// @notice Returns the target selector classification and pinned code/state commitments.
    function tighteningCallConfig(address target, bytes4 selector)
        external
        view
        returns (bool tightening, bytes32 targetCodeHash, uint64 revision, bytes32 stateHash);

    /// @notice Returns terminal-freeze classification and pinned code/state commitments.
    function freezeSelectorConfig(address target, bytes4 selector)
        external
        view
        returns (bool freeze, bytes32 targetCodeHash, uint64 revision, bytes32 stateHash);

    /// @notice Returns the current root, its pinned runtime hash, and authority revision.
    function governanceRootState()
        external
        view
        returns (address governanceRoot, bytes32 codeHash, uint64 revision);

    /// @notice Returns the guardian-set commitment captured for a scheduled action.
    function terminalFreezeGuardianConfigCommitment(bytes32 actionId)
        external
        view
        returns (bytes32 commitment);

    /// @notice Returns the launch-pinned minimum delay for `actionClass`.
    function minimumDelay(uint8 actionClass) external pure returns (uint64);

    /// @notice Returns the published SSTORE2 pointer for a calldata key, or
    ///         the zero address when unpublished.
    function publishedCallData(bytes32 callDataKey) external view returns (address pointer);

    /// @notice Returns a target-transition scope's sole effective veto guardian
    ///         and the deadline of its EARLIEST live terminal-freeze action.
    /// @dev Terminal-freeze batches are indexed once under every distinct
    ///     `GovernanceCall.scopeHash`, never under the V2 action aggregate.
    ///     Per-scope and global holders are additive veto authorities. The
    ///     address is nonzero only when their deduplicated union has exactly one
    ///     member; otherwise `guardian` is the zero-address sentinel. Use
    ///     `terminalFreezeVetoGuardianSet` plus RoleRegistry enumeration for the
    ///     complete set. `vetoDeadline` is zero when the scope has no
    ///     live (scheduled, pre-`notBefore`) terminal-freeze action. Because a
    ///     scope may have several live actions, use
    ///     `liveTerminalFreezeActionCount`/`liveTerminalFreezeActionAt` to
    ///     enumerate them all; this read never hides a live action behind a
    ///     later-scheduled decoy.
    function terminalFreezeVetoGuardian(bytes32 scopeHash)
        external
        view
        returns (address guardian, uint64 vetoDeadline);

    /// @notice Returns the exact RoleRegistry enumeration recipe for every
    ///         additive veto guardian effective for a scope.
    function terminalFreezeVetoGuardianSet(bytes32 scopeHash)
        external
        view
        returns (
            address roleRegistryAddress,
            bytes32 scopedRole,
            uint256 scopedHolderCount,
            bytes32 globalRole,
            uint256 globalHolderCount,
            uint64 vetoDeadline
        );

    /// @notice Returns the total, shared non-root, and per-non-root-proposer
    ///         caps for open terminal-freeze memberships in one scope.
    function terminalFreezeLiveActionCaps()
        external
        pure
        returns (uint256 totalCap, uint256 nonRootCap, uint256 perNonRootProposerCap);

    /// @notice Returns raw capacity usage for one scope and non-root proposer.
    /// @dev Usage includes elapsed memberships until bounded pruning runs.
    function terminalFreezeLiveActionUsage(bytes32 scopeHash, address proposer)
        external
        view
        returns (uint256 totalMemberships, uint256 nonRootMemberships, uint256 proposerMemberships);

    /// @notice Returns one bounded page of raw veto-discovery memberships.
    /// @dev Entries may be elapsed until permissionless pruning runs; compare
    ///      each deadline with the current block timestamp.
    function terminalFreezeActionPage(bytes32 scopeHash, uint256 cursor, uint256 limit)
        external
        view
        returns (bytes32[] memory actionIds, uint64[] memory vetoDeadlines, uint256 nextCursor);

    /// @notice Returns the number of live (scheduled, pre-`notBefore`)
    ///         terminal-freeze actions affecting target scope `scopeHash`.
    /// @dev Actions remain in the O(1) mutation index until a terminal state
    ///      transition, but this view excludes them as soon as their veto deadline
    ///      is reached.
    function liveTerminalFreezeActionCount(bytes32 scopeHash) external view returns (uint256);

    /// @notice Returns the `index`-th live terminal-freeze action for
    ///         `scopeHash` and its veto deadline (`notBefore`).
    /// @dev Indices densely enumerate only pre-deadline actions in the backing
    ///      set's deterministic order; elapsed entries are skipped without a
    ///      state mutation.
    function liveTerminalFreezeActionAt(bytes32 scopeHash, uint256 index)
        external
        view
        returns (bytes32 actionId, uint64 vetoDeadline);

    /// @notice Per-scope veto role constant:
    ///         `keccak256(abi.encode(ROLE_TERMINAL_FREEZE_VETO, scopeHash))`.
    function terminalFreezeVetoRole(bytes32 scopeHash) external pure returns (bytes32);

    /// @notice Returns the in-flight action context during batch execution so
    ///         governed targets can verify the executing action class.
    function currentAction()
        external
        view
        returns (
            bool executing,
            bytes32 actionId,
            uint8 actionClass,
            bytes32 scopeHash,
            bytes32 oldValueHash,
            bytes32 newValueHash
        );

    /// @notice Returns the SSTORE2 pointer holding the scheduled calldata
    ///         preimages for `actionId` ([LTA-PAYLOAD-DISCOVERY] typed pointer).
    function scheduledCallDataPointer(bytes32 actionId) external view returns (address);

    /// @notice Reads back the exact scheduled calldata preimages for `actionId`.
    function scheduledCallData(bytes32 actionId) external view returns (bytes[] memory);

    /// @notice Returns the exact publication-tail requirement for a target selector.
    function systemManifestBatchTailRule(address triggerTarget, bytes4 triggerSelector)
        external
        view
        returns (
            bool registered,
            bytes32 triggerCodeHash,
            uint8 allowedActionClassMask,
            address tailTarget,
            bytes4 tailSelector,
            bytes32 tailCodeHash
        );

    /// @notice Returns the number of registered manifest publication triggers.
    function systemManifestTailTriggerCount() external view returns (uint256);

    /// @notice Returns the manifest trigger at a zero-based registry index.
    function systemManifestTailTriggerAt(uint256 index)
        external
        view
        returns (
            address triggerTarget,
            bytes4 triggerSelector,
            bytes32 triggerCodeHash,
            uint8 allowedActionClassMask
        );

    /// @notice Returns the append-only trigger commitment and number of committed records.
    function systemManifestTailTriggerChainHash()
        external
        view
        returns (bytes32 chainHash, uint64 recordCount);

    /// @notice Returns the number of actions still stored as scheduled.
    function pendingScheduledActionCount() external view returns (uint256);

    /// @notice Returns bootstrap identity, seal status, inventory, and current catalog commitments.
    function systemManifestBootstrapState()
        external
        view
        returns (
            bool bound,
            bool isSealed,
            address roleRegistry,
            bytes32 roleRegistryCodeHash,
            address governanceRoot,
            bytes32 governanceRootCodeHash,
            uint64 governanceRootRevision,
            bytes32 initialGuardianSetHash,
            uint256 initialGuardianCount,
            bytes32 terminalFreezeVetoMutationChain,
            uint64 terminalFreezeVetoMutationRevision,
            address core,
            bytes32 coreCodeHash,
            address systemManifestSatellite,
            bytes32 systemManifestSatelliteCodeHash,
            bytes32 triggerSetHash,
            uint256 triggerCount,
            bytes32 expectedTriggerSetHash,
            uint256 expectedTriggerCount,
            bytes32 expectedManifestHash,
            bytes32 expectedInventoryStateRoot,
            uint256 expectedInventoryLeafCount,
            bytes32 inventoryStateRoot,
            uint256 inventoryLeafCount,
            address genesisBootstrapAuthority,
            address sealedPayloadPointer,
            bytes32 actionPolicyCandidateProfileHash,
            bytes32 actionPolicyCatalogHash,
            uint256 actionPolicyEntryCount
        );
}
