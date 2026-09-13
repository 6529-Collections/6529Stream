// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/IStreamFinalityGovernanceBindings.sol";
import "../../interfaces/stream/finality/StreamFinalityGovernanceTypes.sol";
import "../../interfaces/stream/governance/IStreamGovernanceReads.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";

/// @notice Canonical Executor-only finality witness with bounded fixed/header reads.
/// @dev Called by the compiler-linked target with its own constructor-pinned identities.
library StreamFinalityGovernanceWitness {
    error FinalityExecutorOnly(address actor);
    error FinalityGovernancePinChanged(address target);
    error FinalityGovernanceContextInvalid();
    error FinalityProposerRoleMissing(address proposer);
    error FinalityGovernanceReadFailed(address target);
    error FinalityGovernanceParentGas(uint256 available, uint256 required);

    struct Pins {
        address executor;
        bytes32 executorCodeHash;
        address roles;
        bytes32 rolesCodeHash;
    }

    function requireExecution(
        Pins memory pins,
        StreamFinalityExecutionContext memory expected,
        uint256 readGas
    ) public view returns (StreamFinalityExecutionWitness memory witness) {
        if (msg.sender != pins.executor) revert FinalityExecutorOnly(msg.sender);
        _pins(pins, readGas);
        bytes memory context = _fixed(
            pins.executor, abi.encodeCall(IStreamGovernanceReads.currentAction, ()), 192, readGas
        );
        witness.actionId = bytes32(_word(context, 1));
        if (
            _word(context, 0) != 1 || witness.actionId == bytes32(0)
                || _word(context, 2) != uint256(StreamGovernanceActionClasses.TERMINAL_FREEZE)
                || bytes32(_word(context, 3)) != expected.scopeHash
                || bytes32(_word(context, 4)) != expected.oldValueHash
                || bytes32(_word(context, 5)) != expected.newValueHash
        ) revert FinalityGovernanceContextInvalid();

        // GovernanceAction is an outer dynamic tuple: copy its fixed head and URI length only.
        (bytes memory header, uint256 size) = _read(
            pins.executor,
            abi.encodeCall(IStreamGovernanceReads.governanceAction, (witness.actionId)),
            640,
            readGas
        );
        uint256 uriLength = _word(header, 19);
        if (
            _word(header, 0) != 32 || _word(header, 17) != 576 || uriLength > size - 640
                || size % 32 != 0 || size - 640 - uriLength > 31
                || _word(header, 1) != uint256(GovernanceActionStatus.EXECUTED)
                || _word(header, 2) != uint256(StreamGovernanceActionClasses.TERMINAL_FREEZE)
                || _word(header, 3) >> 160 != 0 || _word(header, 5) << 32 != 0
                || _word(header, 10) > type(uint64).max || _word(header, 11) > type(uint64).max
                || _word(header, 12) >> 160 != 0 || _word(header, 13) >> 160 != 0
                || _word(header, 14) >> 160 != 0 || _word(header, 15) >> 160 != 0
        ) revert FinalityGovernanceContextInvalid();
        // The stored batch's target/selector/scope are deliberately not compared with this call.
        witness.proposer = address(uint160(_word(header, 12)));
        witness.reasonHash = bytes32(_word(header, 16));
        bytes32 role = keccak256("ROLE_COLLECTION_FINALITY_ADMIN");
        if (
            witness.proposer == address(0)
                || _word(
                        _fixed(
                            pins.roles,
                            abi.encodeCall(IStreamRoleRegistry.hasRole, (role, witness.proposer)),
                            32,
                            readGas
                        ),
                        0
                    ) != 1
        ) revert FinalityProposerRoleMissing(witness.proposer);
        bytes memory mutation = _fixed(
            pins.roles, abi.encodeCall(IStreamRoleRegistry.roleMutationState, (role)), 64, readGas
        );
        witness.roleMutationHash = bytes32(_word(mutation, 0));
        uint256 revision = _word(mutation, 1);
        if (witness.roleMutationHash == bytes32(0) || revision == 0 || revision > type(uint64).max)
        {
            revert FinalityGovernanceContextInvalid();
        }
        witness.roleRevision = uint64(revision);
    }

    function _pins(Pins memory p, uint256 cap) private view {
        if (p.executor.code.length == 0 || p.executor.codehash != p.executorCodeHash) {
            revert FinalityGovernancePinChanged(p.executor);
        }
        if (p.roles.code.length == 0 || p.roles.codehash != p.rolesCodeHash) {
            revert FinalityGovernancePinChanged(p.roles);
        }
        if (
            _word(
                        _fixed(
                            p.executor,
                            abi.encodeCall(IStreamFinalityGovernanceBindings.roleRegistry, ()),
                            32,
                            cap
                        ),
                        0
                    ) != uint256(uint160(p.roles))
                || _word(
                        _fixed(
                            p.roles,
                            abi.encodeCall(IStreamFinalityGovernanceBindings.owner, ()),
                            32,
                            cap
                        ),
                        0
                    ) != uint256(uint160(p.executor))
        ) revert FinalityGovernanceContextInvalid();
    }

    function _fixed(address target, bytes memory data, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory result)
    {
        uint256 size;
        (result, size) = _read(target, data, length, cap);
        if (size != length) revert FinalityGovernanceReadFailed(target);
    }

    function _read(address target, bytes memory data, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory result, uint256 size)
    {
        uint256 available = gasleft();
        // Bound the arithmetic before addition; the target's constructor accepts measured finite caps.
        if (cap == 0 || cap > type(uint256).max / 2) {
            revert FinalityGovernanceParentGas(available, type(uint256).max);
        }
        uint256 required = cap + (cap + 62) / 63 + 100_000;
        if (available <= required) revert FinalityGovernanceParentGas(available, required);
        result = new bytes(length);
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(result, 32), length)
            size := returndatasize()
        }
        if (!ok || size < length) revert FinalityGovernanceReadFailed(target);
    }

    function _word(bytes memory data, uint256 index) private pure returns (uint256 word) {
        assembly ("memory-safe") { word := mload(add(add(data, 32), mul(index, 32))) }
    }
}
