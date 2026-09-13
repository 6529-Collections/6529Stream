// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryActionTypes as A
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as R
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistIdentityRecovery
} from "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamGovernanceActionFacts
} from "../../interfaces/stream/governance/IStreamGovernanceActionFacts.sol";
import {
    IStreamGovernanceReads
} from "../../interfaces/stream/governance/IStreamGovernanceReads.sol";
import { IStreamRoleRegistry } from "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import {
    GovernanceCall,
    GovernanceActionStatus
} from "../../interfaces/stream/governance/StreamGovernanceTypes.sol";

/// @notice Complete scheduled-batch authentication for Identity's auxiliary preparation.
/// @dev The Coordinator supplies its fixed suite and the Identity child's original Executor pin.
library StreamArtistRecoveryActionReads {
    bytes32 private constant CALLS =
        0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70;

    function prepare(
        A.Environment memory e,
        bytes32 actionId,
        GovernanceCall[] memory calls,
        R.Request memory request,
        T.Authorization memory acceptance,
        R.Context memory context
    ) public view returns (A.Witness memory w) {
        _pin(e.executor, e.executorCodeHash);
        if (e.registry.code.length == 0 || e.roles.code.length == 0) {
            revert A.InvalidRecoveryAction(actionId);
        }
        bytes memory sealedState = _fixed(
            e.executor, abi.encodeCall(IStreamGovernanceReads.systemManifestBootstrapState, ()), 928
        );
        if (_word(sealedState, 0) != 1 || _word(sealedState, 1) != 1) {
            revert A.InvalidRecoveryAction(actionId);
        }
        IStreamGovernanceActionFacts.ActionFacts memory facts = _facts(e.executor, actionId);
        uint256 delay = _word(
            _fixed(e.executor, abi.encodeCall(IStreamGovernanceReads.minimumDelay, (uint8(2))), 32),
            0
        );
        if (
            facts.status != GovernanceActionStatus.SCHEDULED || facts.actionClass != 2
                || facts.notBefore > facts.expiresAfter || delay < 72 hours
                || delay > type(uint64).max || block.timestamp > type(uint64).max
                || block.timestamp + delay > facts.notBefore || acceptance.time < facts.notBefore
                || acceptance.signature.length > 4096 || request.supersededRecordHashes.length > 64
        ) revert A.InvalidRecoveryAction(actionId);
        w.actionId = actionId;
        w.callsHash = keccak256(abi.encode(CALLS, calls));
        if (w.callsHash != facts.callHash) revert A.InvalidRecoveryAction(actionId);
        bytes4 selector = IStreamArtistIdentityRecovery.recoverArtistIdentity.selector;
        w.callDataHash = keccak256(
            abi.encodeCall(
                IStreamArtistIdentityRecovery.recoverArtistIdentity, (request, acceptance)
            )
        );
        uint256 matches;
        for (uint256 i; i < calls.length; ++i) {
            GovernanceCall memory call_ = calls[i];
            if (call_.selector != selector) continue;
            if (
                call_.target != e.registry || call_.value != 0
                    || call_.callDataHash != w.callDataHash || call_.scopeHash != context.scopeHash
                    || call_.oldValueHash != context.oldValueHash
                    || call_.newValueHash != context.newValueHash
            ) revert A.InvalidRecoveryAction(actionId);
            w.callIndex = i;
            ++matches;
        }
        if (matches != 1) revert A.InvalidRecoveryAction(actionId);
        w.executor = e.executor;
        w.executorCodeHash = e.executorCodeHash;
        w.notBefore = facts.notBefore;
        w.expiresAfter = facts.expiresAfter;
        w.minimumDelay = uint64(delay);
        _proposer(e, w, request.reasonHash, facts);
    }

    /// @notice An expired SCHEDULED action cannot execute, even before its status is materialized.
    function terminal(A.Witness memory w) public view returns (bool) {
        _pin(w.executor, w.executorCodeHash);
        IStreamGovernanceActionFacts.ActionFacts memory a = _facts(w.executor, w.actionId);
        _same(w, a);
        return a.status == GovernanceActionStatus.CANCELLED
            || a.status == GovernanceActionStatus.EXECUTED
            || a.status == GovernanceActionStatus.EXPIRED
            || a.status == GovernanceActionStatus.VETOED
            || (a.status == GovernanceActionStatus.SCHEDULED && block.timestamp > a.expiresAfter);
    }

    /// @notice Registered guardian standing lasts while the actual action remains SCHEDULED.
    function requireScheduled(A.Witness memory w) public view {
        _pin(w.executor, w.executorCodeHash);
        IStreamGovernanceActionFacts.ActionFacts memory a = _facts(w.executor, w.actionId);
        _same(w, a);
        if (a.status != GovernanceActionStatus.SCHEDULED) {
            revert A.InvalidRecoveryAction(w.actionId);
        }
    }

    function requireExecuted(A.Witness memory w) public view {
        _pin(w.executor, w.executorCodeHash);
        IStreamGovernanceActionFacts.ActionFacts memory a = _facts(w.executor, w.actionId);
        _same(w, a);
        if (
            a.status != GovernanceActionStatus.EXECUTED || block.timestamp < a.notBefore
                || block.timestamp > a.expiresAfter
        ) {
            revert A.InvalidRecoveryAction(w.actionId);
        }
    }

    function _same(A.Witness memory w, IStreamGovernanceActionFacts.ActionFacts memory a)
        private
        pure
    {
        if (
            a.actionClass != 2 || a.callHash != w.callsHash || a.notBefore != w.notBefore
                || a.expiresAfter != w.expiresAfter
        ) {
            revert A.InvalidRecoveryAction(w.actionId);
        }
    }

    function _proposer(
        A.Environment memory e,
        A.Witness memory w,
        bytes32 reason,
        IStreamGovernanceActionFacts.ActionFacts memory facts
    ) private view {
        (bytes memory h, uint256 size) = _read(
            e.executor, abi.encodeCall(IStreamGovernanceReads.governanceAction, (w.actionId)), 640
        );
        uint256 uriLength = _word(h, 19);
        if (
            _word(h, 0) != 32 || _word(h, 17) != 576 || uriLength > size - 640 || size % 32 != 0
                || size - 640 - uriLength > 31
                || _word(h, 1) != uint256(GovernanceActionStatus.SCHEDULED) || _word(h, 2) != 2
                || _word(h, 3) > type(uint160).max || _word(h, 5) << 32 != 0
                || bytes32(_word(h, 6)) != facts.callHash || _word(h, 10) != facts.notBefore
                || _word(h, 11) != facts.expiresAfter || _word(h, 12) > type(uint160).max
                || _word(h, 13) != 0 || _word(h, 14) != 0 || _word(h, 15) != 0 || reason == 0
                || bytes32(_word(h, 16)) != reason
        ) revert A.InvalidRecoveryAction(w.actionId);
        w.proposer = address(uint160(_word(h, 12)));
        w.manifestHash = bytes32(_word(h, 18));
        uint256 roles = _word(_fixed(e.executor, abi.encodeWithSignature("roleRegistry()"), 32), 0);
        bytes32 role = keccak256("ROLE_ATTRIBUTION_ARBITER");
        if (
            roles != uint256(uint160(e.roles)) || w.proposer == address(0)
                || _word(
                        _fixed(
                            e.roles,
                            abi.encodeCall(IStreamRoleRegistry.hasRole, (role, w.proposer)),
                            32
                        ),
                        0
                    ) != 1
        ) {
            revert A.InvalidRecoveryAction(w.actionId);
        }
        bytes memory mutation =
            _fixed(e.roles, abi.encodeCall(IStreamRoleRegistry.roleMutationState, (role)), 64);
        uint256 revision = _word(mutation, 1);
        w.roleMutationHash = bytes32(_word(mutation, 0));
        if (w.roleMutationHash == 0 || revision == 0 || revision > type(uint64).max) {
            revert A.InvalidRecoveryAction(w.actionId);
        }
        w.roleRevision = uint64(revision);
    }

    function _facts(address executor, bytes32 actionId)
        private
        view
        returns (IStreamGovernanceActionFacts.ActionFacts memory a)
    {
        if (actionId == 0) revert A.InvalidRecoveryAction(actionId);
        bytes memory data = _fixed(
            executor,
            abi.encodeCall(IStreamGovernanceActionFacts.governanceActionFacts, (actionId)),
            160
        );
        if (
            _word(data, 0) > uint256(GovernanceActionStatus.VETOED) || _word(data, 1) > 255
                || _word(data, 2) == 0 || _word(data, 3) > type(uint64).max
                || _word(data, 4) > type(uint64).max
        ) {
            revert A.InvalidRecoveryAction(actionId);
        }
        a = abi.decode(data, (IStreamGovernanceActionFacts.ActionFacts));
    }

    function _pin(address target, bytes32 expected) private view {
        if (target.code.length == 0 || target.codehash != expected) {
            revert A.RecoveryActionDependencyChanged(target);
        }
    }

    function _word(bytes memory data, uint256 index) private pure returns (uint256 word) {
        assembly ("memory-safe") { word := mload(add(add(data, 32), mul(index, 32))) }
    }

    function _fixed(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory result)
    {
        uint256 size;
        (result, size) = _read(target, data, length);
        if (size != length) revert A.RecoveryActionDependencyChanged(target);
    }

    /// @dev Fixed authenticated governance hosts; bounded output copy also covers dynamic reason URIs.
    function _read(address target, bytes memory data, uint256 length)
        private
        view
        returns (bytes memory result, uint256 size)
    {
        result = new bytes(length);
        if (gasleft() < 20_000) revert A.RecoveryActionDependencyChanged(target);
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(
                sub(gas(), 10000),
                target,
                add(data, 32),
                mload(data),
                add(result, 32),
                length
            )
            size := returndatasize()
        }
        if (!ok || size < length) revert A.RecoveryActionDependencyChanged(target);
    }
}
