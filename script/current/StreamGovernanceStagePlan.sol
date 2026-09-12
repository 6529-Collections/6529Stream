// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGovernanceGenesisPlan.sol";

/// @notice Immutable offchain plans for delayed deployment stages and exact resumption.
/// @dev The journal must retain abi.encode(plan) before signing. This library supplies the
///      same Executor call for a Safe or another authorized root, without casting the root
///      to a development actor. This initial deployment planner permits zero-value calls
///      only. Action completion still requires stage-specific readbacks.
library StreamGovernanceStagePlan {
    error InvalidStagePlan();
    error StageStateChanged();
    error StageActionMismatch();
    error StageJournalMismatch();
    error StageNotExecutable(GovernanceActionStatus status);

    struct Plan {
        uint16 schemaVersion;
        bytes32 stage;
        uint256 chainId;
        address executor;
        bytes32 executorCodeHash;
        address proposer;
        bytes32 proposerCodeHash;
        uint64 proposerRevision;
        bytes32 catalogHash;
        uint64 catalogRevision;
        GenesisBatch batch;
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
        uint64 notBefore;
        uint64 expiresAfter;
        bytes32 reasonHash;
        string reasonURI;
        bytes32 manifestHash;
    }

    struct NextCall {
        address caller;
        address target;
        uint256 value;
        bytes data;
    }

    function build(
        StreamGovernanceExecutor executor,
        bytes32 stage,
        GenesisBatch memory batch,
        uint64 notBefore,
        uint64 expiresAfter,
        bytes32 reasonHash,
        string memory reasonURI,
        bytes32 manifestHash
    ) internal view returns (Plan memory p) {
        p.schemaVersion = 2;
        p.stage = stage;
        p.chainId = block.chainid;
        p.executor = address(executor);
        p.executorCodeHash = address(executor).codehash;
        (p.proposer, p.proposerCodeHash, p.proposerRevision) = executor.governanceRootState();
        (, p.catalogHash,, p.catalogRevision) = executor.governanceActionPolicyState();
        p.batch = batch;
        (p.scopeHash, p.oldValueHash, p.newValueHash) =
            StreamGovernanceBootstrap.deriveBatchTransitionHashes(
                batch.calls, StreamGovernanceBootstrap.governanceCallsHash(batch.calls)
            );
        p.notBefore = notBefore;
        p.expiresAfter = expiresAfter;
        p.reasonHash = reasonHash;
        p.reasonURI = reasonURI;
        p.manifestHash = manifestHash;
        _validate(p);
        _requireCurrentState(p);
        _requireSubmissionWindow(p);
    }

    /// @notice Permissionless publication of the exact calldata comes before root scheduling.
    function planHash(Plan memory p) internal pure returns (bytes32) {
        return keccak256(abi.encode(p));
    }

    function publication(Plan memory p, bytes32 savedHash) internal view returns (NextCall memory) {
        _requireJournal(p, savedHash);
        _validate(p);
        _requireCurrentState(p);
        return NextCall(
            address(0), p.executor, 0,
            abi.encodeCall(IStreamGovernanceExecutor.publishGovernanceCallData, (p.batch.callDatas))
        );
    }

    /// @notice Submit this target/value/data from caller, including through Safe.execTransaction.
    /// @dev The real Executor additionally checks catalog admission and target transitions.
    function scheduling(Plan memory p, bytes32 savedHash) internal view returns (NextCall memory) {
        _requireJournal(p, savedHash);
        _validate(p);
        _requireCurrentState(p);
        _requireSubmissionWindow(p);
        return NextCall(
            p.proposer, p.executor, 0,
            abi.encodeCall(
                IStreamGovernanceExecutor.scheduleGovernanceBatch,
                (p.batch.actionClass, p.batch.calls, p.scopeHash, p.oldValueHash, p.newValueHash,
                    p.notBefore, p.expiresAfter, p.reasonHash, p.reasonURI, p.manifestHash)
            )
        );
    }

    /// @notice Compare the confirmed action to every saved scheduling field.
    /// @dev actionId comes from the receipt, never a guessed global Executor nonce.
    function verifyAction(Plan memory p, bytes32 actionId, bytes32 savedHash)
        internal view returns (GovernanceActionStatus status)
    {
        _requireJournal(p, savedHash);
        _validate(p);
        GovernanceAction memory a = IStreamGovernanceExecutor(p.executor).governanceAction(actionId);
        uint256 value;
        for (uint256 i; i < p.batch.calls.length; ++i) value += p.batch.calls[i].value;
        if (
            actionId == bytes32(0) || a.status == GovernanceActionStatus.NONE
                || a.actionClass != p.batch.actionClass || a.proposer != p.proposer
                || a.target != p.batch.calls[0].target || a.selector != p.batch.calls[0].selector
                || a.value != value
                || a.callHash != StreamGovernanceBootstrap.governanceCallsHash(p.batch.calls)
                || a.scopeHash != p.scopeHash || a.oldValueHash != p.oldValueHash
                || a.newValueHash != p.newValueHash || a.notBefore != p.notBefore
                || a.expiresAfter != p.expiresAfter || a.reasonHash != p.reasonHash
                || keccak256(bytes(a.reasonURI)) != keccak256(bytes(p.reasonURI))
                || a.manifestHash != p.manifestHash
        ) revert StageActionMismatch();
        return a.status;
    }

    /// @notice An already executed saved action is a no-op; changed plans are always rejected.
    function execute(Plan memory p, bytes32 actionId, bytes32 savedHash) internal returns (bool executedNow) {
        GovernanceActionStatus status = verifyAction(p, actionId, savedHash);
        if (status == GovernanceActionStatus.EXECUTED) return false;
        if (status != GovernanceActionStatus.SCHEDULED) revert StageNotExecutable(status);
        _requireCurrentState(p);
        IStreamGovernanceExecutor(p.executor).executeGovernanceBatch(
            actionId, p.batch.calls, p.batch.callDatas
        );
        if (verifyAction(p, actionId, savedHash) != GovernanceActionStatus.EXECUTED) {
            revert StageActionMismatch();
        }
        return true;
    }

    function _validate(Plan memory p) private view {
        if (
            p.schemaVersion != 2 || p.stage == bytes32(0) || p.chainId != block.chainid
                || p.executor.code.length == 0 || p.executor.codehash != p.executorCodeHash
                || p.proposer == address(0) || p.proposerRevision == 0
                || p.catalogHash == bytes32(0) || p.batch.calls.length == 0
                || p.batch.calls.length != p.batch.callDatas.length
                || p.notBefore >= p.expiresAfter || p.reasonHash == bytes32(0)
                || p.manifestHash == bytes32(0)
        ) revert InvalidStagePlan();
        for (uint256 i; i < p.batch.calls.length; ++i) {
            bytes memory data = p.batch.callDatas[i];
            if (p.batch.calls[i].value != 0 || data.length < 4 || keccak256(data) != p.batch.calls[i].callDataHash) {
                revert InvalidStagePlan();
            }
            bytes4 selector;
            assembly ("memory-safe") { selector := mload(add(data, 32)) }
            if (selector != p.batch.calls[i].selector) revert InvalidStagePlan();
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            StreamGovernanceBootstrap.deriveBatchTransitionHashes(
                p.batch.calls, StreamGovernanceBootstrap.governanceCallsHash(p.batch.calls)
            );
        if (scope != p.scopeHash || oldHash != p.oldValueHash || newHash != p.newValueHash) {
            revert InvalidStagePlan();
        }
    }

    function _requireCurrentState(Plan memory p) private view {
        StreamGovernanceExecutor executor = StreamGovernanceExecutor(payable(p.executor));
        (address root, bytes32 rootHash, uint64 rootRevision) = executor.governanceRootState();
        (, bytes32 catalog,, uint64 revision) = executor.governanceActionPolicyState();
        if (
            root != p.proposer || rootHash != p.proposerCodeHash || rootRevision != p.proposerRevision
                || root.codehash != rootHash || catalog != p.catalogHash || revision != p.catalogRevision
        ) revert StageStateChanged();
    }

    /// @dev savedHash belongs to the original journal/receipt association, not a fresh
    ///      hash of untrusted replacement input. The action binds its scheduling fields;
    ///      this independent commitment additionally binds stage and source-state metadata.
    function _requireJournal(Plan memory p, bytes32 savedHash) private pure {
        if (savedHash == bytes32(0) || planHash(p) != savedHash) revert StageJournalMismatch();
    }

    function _requireSubmissionWindow(Plan memory p) private view {
        if (
            uint256(p.notBefore) < block.timestamp
                + IStreamGovernanceExecutor(p.executor).minimumDelay(p.batch.actionClass)
        ) revert InvalidStagePlan();
    }
}
