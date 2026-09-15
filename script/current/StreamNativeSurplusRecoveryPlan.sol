// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGovernanceCatalogStagePlan.sol";
import {
    IStreamNativeSurplus as NS
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeSurplus.sol";

/// @notice Saved operator plans over the original native surplus capability. No money is moved here.
library StreamNativeSurplusRecoveryPlan {
    bytes32 private constant STAGE = keccak256("6529STREAM_NATIVE_SURPLUS_RECOVERY_STAGE_V1");
    bytes32 private constant SCOPE = keccak256("6529STREAM_NATIVE_SURPLUS_SCOPE_V1");
    bytes32 private constant STATE = keccak256("6529STREAM_NATIVE_SURPLUS_STATE_V1");
    bytes32 private constant REQUEST = keccak256("6529STREAM_NATIVE_SURPLUS_REQUEST_V1");

    struct Pins {
        address adapter;
        bytes32 adapterCodeHash;
        address core;
        bytes32 coreCodeHash;
        address registry;
        bytes32 registryCodeHash;
        address executor;
        bytes32 executorCodeHash;
    }

    struct Parameters {
        uint256 amount;
        uint64 notBefore;
        uint64 expiresAfter;
        bytes32 reasonHash;
        string reasonURI;
        bytes32 manifestHash;
    }

    struct Saved {
        uint16 schemaVersion;
        Pins pins;
        NS.NativeSurplusQuote quote;
        StreamGovernanceStagePlan.Plan plan;
    }

    struct Prepared {
        bytes encodedRecovery;
        bytes32 savedRecoveryHash;
        bytes encodedPlan;
        bytes32 savedPlanHash;
        StreamGovernanceStagePlan.NextCall publication;
        StreamGovernanceStagePlan.NextCall scheduling;
    }

    struct Completion {
        address recipient;
        uint256 amount;
        bool latestSweep;
        bool solvent;
        NS.NativeSurplusState current;
    }
    error InvalidSurplusRecoveryPins();
    error InvalidSurplusRecoveryJournal();
    error SurplusRecoveryStateChanged();
    error SurplusRecoveryNotCompleted();

    /// @dev Explicit pins are operator-selected source evidence, not provenance inferred from a getter.
    function prepare(Pins memory pins, Parameters memory parameters)
        public
        view
        returns (Prepared memory result)
    {
        NS.NativeSurplusQuote memory q = quote(pins, parameters.amount, parameters.reasonHash);
        GenesisBatch memory batch = _batch(pins.adapter, q);
        Saved memory s;
        s.schemaVersion = 1;
        s.pins = pins;
        s.quote = q;
        s.plan = StreamGovernanceStagePlan.build(
            StreamGovernanceExecutor(payable(pins.executor)),
            _stage(pins, q),
            batch,
            parameters.notBefore,
            parameters.expiresAfter,
            parameters.reasonHash,
            parameters.reasonURI,
            parameters.manifestHash
        );
        result.encodedRecovery = abi.encode(s);
        result.savedRecoveryHash = keccak256(result.encodedRecovery);
        result.encodedPlan = abi.encode(s.plan);
        result.savedPlanHash = StreamGovernanceStagePlan.planHash(s.plan);
        result.publication = StreamGovernanceStagePlan.publication(s.plan, result.savedPlanHash);
        result.scheduling = StreamGovernanceStagePlan.scheduling(s.plan, result.savedPlanHash);
    }

    /// @notice One exact class-1, zero-value CALL admission. It grants no recipient selection.
    /// @dev Admission presence is verified from the retained catalog history, which has no
    /// enumerable onchain entry getter. A duplicate/conflicting row is rejected by the Executor.
    function admission(Pins memory pins, bytes32 targetProfileHash)
        public
        view
        returns (StreamGovernanceCatalogStagePlan.Inventory memory saved, bytes32 savedHash)
    {
        _pins(pins);
        if (targetProfileHash == 0) revert InvalidSurplusRecoveryPins();
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](1);
        rows[0] = GovernanceActionPolicyEntry(
            1,
            pins.adapter,
            NS.sweepNativeSurplus.selector,
            pins.adapterCodeHash,
            targetProfileHash,
            1,
            0,
            0,
            bytes32(0)
        );
        saved = StreamGovernanceCatalogStagePlan.inventory(
            StreamGovernanceExecutor(payable(pins.executor)), rows
        );
        savedHash = StreamGovernanceCatalogStagePlan.inventoryHash(saved);
    }

    /// @notice Prepare an exact permissionless Executor CALL after confirming the schedule receipt.
    /// @return alreadyExecuted True means no further transaction is needed; validate completion separately.
    function execution(Saved memory s, bytes32 savedHash, bytes32 actionId)
        public
        view
        returns (bool alreadyExecuted, StreamGovernanceStagePlan.NextCall memory next)
    {
        _journal(s, savedHash);
        GovernanceActionStatus status = StreamGovernanceStagePlan.verifyAction(
            s.plan, actionId, StreamGovernanceStagePlan.planHash(s.plan)
        );
        if (status == GovernanceActionStatus.EXECUTED) {
            _completion(s, actionId);
            return (true, next);
        }
        if (status != GovernanceActionStatus.SCHEDULED) revert SurplusRecoveryNotCompleted();
        // Preserve the original root/catalog/runtime guard without imposing the old submission window.
        StreamGovernanceStagePlan.publication(s.plan, StreamGovernanceStagePlan.planHash(s.plan));
        NS.NativeSurplusQuote memory current = quote(s.pins, s.quote.amount, s.quote.reasonHash);
        if (
            current.scopeHash != s.quote.scopeHash || current.oldValueHash != s.quote.oldValueHash
                || current.newValueHash != s.quote.newValueHash
        ) revert SurplusRecoveryStateChanged();
        next = StreamGovernanceStagePlan.NextCall(
            address(0),
            s.pins.executor,
            0,
            abi.encodeCall(
                IStreamGovernanceExecutor.executeGovernanceBatch,
                (actionId, s.plan.batch.calls, s.plan.batch.callDatas)
            )
        );
    }

    /// @notice Historical completion stays readable after claims, donations and later sweeps.
    /// @dev This joins the exact executed action and host replay record; it does not reconstruct logs.
    function completion(Saved memory s, bytes32 savedHash, bytes32 actionId)
        public
        view
        returns (Completion memory)
    {
        _journal(s, savedHash);
        if (
            StreamGovernanceStagePlan.verifyAction(
                    s.plan, actionId, StreamGovernanceStagePlan.planHash(s.plan)
                ) != GovernanceActionStatus.EXECUTED
        ) revert SurplusRecoveryNotCompleted();
        return _completion(s, actionId);
    }

    function quote(Pins memory pins, uint256 amount, bytes32 reason)
        public
        view
        returns (NS.NativeSurplusQuote memory q)
    {
        _pins(pins);
        q = NS(pins.adapter).nativeSurplusQuote(amount, reason);
        NS.NativeSurplusState memory state = NS(pins.adapter).nativeSurplusState();
        if (
            keccak256(abi.encode(q.state)) != keccak256(abi.encode(state))
                || state.balance != pins.adapter.balance || state.balance < state.liabilities
                || state.available != state.balance - state.liabilities || amount == 0
                || amount > state.available || reason == 0 || q.amount != amount
                || q.reasonHash != reason || q.authority.executor != pins.executor
                || q.authority.executorCodeHash != pins.executorCodeHash
                || q.authority.recipient == address(0) || q.authority.recipient == pins.adapter
        ) {
            revert InvalidSurplusRecoveryPins();
        }
        if (!_canonical(pins, q)) revert InvalidSurplusRecoveryPins();
    }

    /// @dev Recheck the historical recipient/request association without requiring live role state.
    function _canonical(Pins memory pins, NS.NativeSurplusQuote memory q)
        private
        view
        returns (bool)
    {
        if (
            q.amount == 0 || q.reasonHash == 0 || q.state.revision == type(uint64).max
                || q.state.cumulativeSwept > type(uint256).max - q.amount
                || q.authority.executor != pins.executor
                || q.authority.executorCodeHash != pins.executorCodeHash
                || q.authority.recipient == address(0) || q.authority.recipient == pins.adapter
        ) return false;
        // The tuple exactly matches the original static Context encoding.
        bytes32 scope = keccak256(
            abi.encode(
                SCOPE,
                block.chainid,
                pins.adapter,
                pins.core,
                pins.coreCodeHash,
                pins.registry,
                pins.registryCodeHash,
                pins.executor
            )
        );
        bytes32 request = keccak256(abi.encode(REQUEST, q.amount, q.reasonHash, q.authority));
        return q.scopeHash == scope
            && q.oldValueHash
                == keccak256(
                abi.encode(
                STATE,
                scope,
                request,
                q.state.liabilities,
                q.state.revision,
                q.state.cumulativeSwept
            )
            )
            && q.newValueHash
                == keccak256(
                abi.encode(
                STATE,
                scope,
                request,
                q.state.liabilities,
                q.state.revision + 1,
                q.state.cumulativeSwept + q.amount
            )
            );
    }

    function _completion(Saved memory s, bytes32 actionId)
        private
        view
        returns (Completion memory r)
    {
        _pins(s.pins);
        r.current = NS(s.pins.adapter).nativeSurplusState();
        uint64 expectedRevision = s.quote.state.revision + 1;
        uint256 expectedSwept = s.quote.state.cumulativeSwept + s.quote.amount;
        if (
            !NS(s.pins.adapter).nativeSurplusActionUsed(actionId)
                || r.current.revision < expectedRevision
                || r.current.cumulativeSwept < expectedSwept
                || r.current.balance != s.pins.adapter.balance
        ) revert SurplusRecoveryNotCompleted();
        r.latestSweep = r.current.revision == expectedRevision;
        if (
            r.latestSweep
                && (r.current.lastActionId != actionId
                    || r.current.cumulativeSwept != expectedSwept)
        ) {
            revert SurplusRecoveryNotCompleted();
        }
        r.recipient = s.quote.authority.recipient;
        r.amount = s.quote.amount;
        r.solvent = r.current.balance >= r.current.liabilities;
    }

    function _journal(Saved memory s, bytes32 savedHash) private view {
        if (
            savedHash == 0 || savedHash != keccak256(abi.encode(s)) || s.schemaVersion != 1
                || !_canonical(s.pins, s.quote) || s.plan.executor != s.pins.executor
                || s.plan.executorCodeHash != s.pins.executorCodeHash
                || s.plan.reasonHash != s.quote.reasonHash
                || s.plan.stage != _stage(s.pins, s.quote)
                || keccak256(abi.encode(s.plan.batch))
                    != keccak256(abi.encode(_batch(s.pins.adapter, s.quote)))
        ) {
            revert InvalidSurplusRecoveryJournal();
        }
    }

    function _stage(Pins memory pins, NS.NativeSurplusQuote memory q)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(STAGE, pins, q.scopeHash, q.oldValueHash, q.newValueHash));
    }

    function _batch(address adapter, NS.NativeSurplusQuote memory q)
        private
        pure
        returns (GenesisBatch memory b)
    {
        b.actionClass = 1;
        b.calls = new GovernanceCall[](1);
        b.callDatas = new bytes[](1);
        b.callDatas[0] = abi.encodeCall(NS.sweepNativeSurplus, (q.amount, q.reasonHash));
        b.calls[0] = StreamCurrentStackPlan.call(
            adapter, b.callDatas[0], q.scopeHash, q.oldValueHash, q.newValueHash
        );
    }

    function _pins(Pins memory p) private view {
        if (
            !_code(p.adapter, p.adapterCodeHash) || !_code(p.core, p.coreCodeHash)
                || !_code(p.registry, p.registryCodeHash) || !_code(p.executor, p.executorCodeHash)
                || _word(p.adapter, bytes4(keccak256("core()"))) != uint256(uint160(p.core))
                || bytes32(_word(p.adapter, bytes4(keccak256("coreCodeHash()")))) != p.coreCodeHash
                || _word(p.adapter, bytes4(keccak256("moduleRegistry()")))
                    != uint256(uint160(p.registry))
                || _word(p.adapter, bytes4(keccak256("governanceAuthority()")))
                    != uint256(uint160(p.executor))
        ) {
            revert InvalidSurplusRecoveryPins();
        }
    }

    function _code(address target, bytes32 expected) private view returns (bool) {
        return target.code.length != 0 && expected != 0 && target.codehash == expected;
    }

    function _word(address target, bytes4 selector) private view returns (uint256 result) {
        bytes memory data = abi.encodeWithSelector(selector);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            let p := mload(0x40)
            ok := staticcall(100000, target, add(data, 32), 4, p, 32)
            size := returndatasize()
            result := mload(p)
        }
        if (!ok || size != 32) revert InvalidSurplusRecoveryPins();
    }
}
