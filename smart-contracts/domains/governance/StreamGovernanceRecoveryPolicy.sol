// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/governance/StreamGovernanceTypes.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRecovery.sol";
import "../../interfaces/stream/finality/IStreamFinalityRecoveryGovernanceBinding.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/modules/IStreamModule.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Recovery-only composition checks over the entire authenticated published batch.
/// @dev Invoked by DELEGATECALL from the canonical Executor after catalog checks,
///      at both scheduling and execution. No classifier or pending-action state.
library StreamGovernanceRecoveryPolicy {
    error GovernanceRecoveryBatchInvalid(uint256 callIndex);
    error GovernanceRecoveryCardinality(uint256 count);
    error GovernanceRecoveryTargetInvalid(address target);
    error GovernanceRecoveryCutoverInvalid(uint256 callIndex, address currentPredecessor);
    error GovernanceRecoveryParentGas(uint256 available, uint256 required);

    bytes32 private constant RECOVERY_KEY = keccak256("ARTWORK_FINALITY_RECOVERY");
    bytes32 private constant RECOVERY_TYPE = keccak256("STREAM_ARTWORK_FINALITY_RECOVERY");
    bytes4 private constant RECOVERY_INTERFACE = 0x83685f5c;
    uint256 private constant READ_GAS = 100000;

    function validate(
        address core,
        bytes32 coreCodeHash,
        uint8 actionClass,
        GovernanceCall[] memory calls,
        bytes[] memory callDatas
    ) public view {
        if (calls.length != callDatas.length) {
            revert GovernanceRecoveryBatchInvalid(0);
        }
        uint256 recoveries;
        uint256 cutovers;
        for (uint256 i; i < calls.length; ++i) {
            GovernanceCall memory c = calls[i];
            if (c.selector == IStreamArtworkFinalityRecovery.executeFinalityRecovery.selector) {
                _call(c, callDatas[i], i);
                if (c.value != 0 || actionClass != StreamGovernanceActionClasses.TERMINAL_FREEZE) {
                    revert GovernanceRecoveryBatchInvalid(i);
                }
                if (++recoveries > 1) revert GovernanceRecoveryCardinality(recoveries);
                _request(callDatas[i], i);
                _core(core, coreCodeHash);
                _recoveryTarget(c.target, core);
            }
            if (
                c.target == core
                    && c.selector == IStreamCorePointers.updateSatellitePointer.selector
            ) {
                bytes memory data = callDatas[i];
                // Other pointer families retain their existing target/catalog policy.
                if (data.length < 36) continue;
                bytes32 key;
                assembly ("memory-safe") {
                    key := mload(add(data, 36))
                }
                if (key != RECOVERY_KEY) continue;
                _call(c, data, i);
                if (data.length != 68) revert GovernanceRecoveryBatchInvalid(i);
                uint256 successor;
                assembly ("memory-safe") {
                    successor := mload(add(data, 68))
                }
                if (successor > type(uint160).max) revert GovernanceRecoveryBatchInvalid(i);
                if (c.value != 0 || ++cutovers > 1) revert GovernanceRecoveryBatchInvalid(i);
                _core(core, coreCodeHash);
                address old = _predecessor(core);
                if (old == address(0)) continue;
                if (i == 0) revert GovernanceRecoveryCutoverInvalid(i, old);
                GovernanceCall memory previous = calls[i - 1];
                bytes memory before_ = callDatas[i - 1];
                _call(previous, before_, i - 1);
                if (
                    previous.target != old || previous.value != 0 || before_.length != 4
                        || previous.selector
                            != IStreamArtworkFinalityRecovery.assertNoIncompleteFinalityRecoveryRefreshPlans
                                .selector
                ) revert GovernanceRecoveryCutoverInvalid(i, old);
            }
        }
    }

    function _call(GovernanceCall memory c, bytes memory data, uint256 index) private pure {
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(data, 32)) }
        if (data.length < 4 || selector != c.selector || keccak256(data) != c.callDataHash) {
            revert GovernanceRecoveryBatchInvalid(index);
        }
    }

    function _request(bytes memory data, uint256 index) private pure {
        bytes memory arguments = new bytes(data.length - 4);
        for (uint256 i; i < arguments.length; ++i) {
            arguments[i] = data[i + 4];
        }
        StreamFinalityRecoveryRequest memory request =
            abi.decode(arguments, (StreamFinalityRecoveryRequest));
        if (keccak256(abi.encode(request)) != keccak256(arguments)) {
            revert GovernanceRecoveryBatchInvalid(index);
        }
    }

    function _core(address core, bytes32 codeHash) private view {
        if (core.code.length == 0 || core.codehash != codeHash) {
            revert GovernanceRecoveryTargetInvalid(core);
        }
    }

    function _recoveryTarget(address target, address core) private view {
        if (
            target.code.length == 0
                || _word(target, abi.encodeCall(IStreamModule.streamModuleType, ()))
                    != uint256(RECOVERY_TYPE)
                || _word(target, abi.encodeCall(IStreamModule.streamModuleInterfaceId, ()))
                    != uint256(bytes32(RECOVERY_INTERFACE))
                || _word(target, abi.encodeCall(IStreamFinalityRecoveryGovernanceBinding.core, ()))
                    != uint256(uint160(core))
                || _word(
                        target,
                        abi.encodeCall(
                            IStreamFinalityRecoveryGovernanceBinding.governanceAuthority, ()
                        )
                    ) != uint256(uint160(address(this)))
                || _word(target, abi.encodeCall(IERC165.supportsInterface, (bytes4(0x01ffc9a7))))
                    != 1
                || _word(target, abi.encodeCall(IERC165.supportsInterface, (RECOVERY_INTERFACE)))
                    != 1
                || _word(target, abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))))
                    != 0
        ) revert GovernanceRecoveryTargetInvalid(target);
    }

    function _predecessor(address core) private view returns (address) {
        bytes memory input = abi.encodeCall(IStreamCorePointers.getSatellitePointer, (RECOVERY_KEY));
        uint256[10] memory words;
        _budget();
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(READ_GAS, core, add(input, 32), mload(input), words, 320)
            size := returndatasize()
        }
        if (
            !ok || size != 320 || words[0] > type(uint160).max || words[2] > 1
                || (words[4] & type(uint224).max) != 0 || words[5] > type(uint160).max
                || words[6] > 3 || words[9] > type(uint64).max
        ) revert GovernanceRecoveryTargetInvalid(core);
        address old = address(uint160(words[0]));
        if (
            old != address(0)
                && (old.code.length == 0
                    || old.codehash != bytes32(words[1])
                    || words[3] != uint256(RECOVERY_TYPE)
                    || words[4] != uint256(bytes32(RECOVERY_INTERFACE)))
        ) revert GovernanceRecoveryTargetInvalid(old);
        return old;
    }

    function _word(address target, bytes memory input) private view returns (uint256 value) {
        _budget();
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            let output := mload(0x40)
            ok := staticcall(READ_GAS, target, add(input, 32), mload(input), output, 32)
            size := returndatasize()
            value := mload(output)
        }
        if (!ok || size != 32) revert GovernanceRecoveryTargetInvalid(target);
    }

    function _budget() private view {
        uint256 required = READ_GAS + READ_GAS / 63 + 50000;
        if (gasleft() <= required) revert GovernanceRecoveryParentGas(gasleft(), required);
    }
}
