// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamConservationFloor.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySettlementBindings.sol";

/// @notice The permanent Core-bound floor is part of the original recorder's atomic settlement.
/// @dev Fixed-size reads and results; neither a missing binding nor malformed evidence can pass.
library StreamPrimarySaleFloorCall {
    uint256 private constant READ_GAS = 100000;
    uint256 private constant RETURN_RESERVE = 100000;
    bytes32 private constant CALL_GAS = keccak256("6529STREAM_GGP_CONSERVATION_FLOOR_CALL_GAS");

    error SaleFloorBindingUnavailable();
    error SaleFloorCallFailed(address ledger, bytes4 cause);
    error SaleFloorInsufficientGas(uint256 cap);

    function record(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory candidate,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory result
    ) public {
        (address ledger, uint256 cap) = _binding();
        bytes memory data =
            abi.encodeCall(IStreamConservationFloor.recordPrimarySale, (candidate, result));
        _call(ledger, data, cap);
    }

    function supplemental(
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory candidate,
        StreamNativeSupplementalTypes.NativeSupplementalResult memory result
    ) public view {
        (address ledger, uint256 cap) = _binding();
        bytes memory data =
            abi.encodeCall(IStreamConservationFloor.requireSupplemental, (candidate, result));
        _admit(cap);
        bytes32 returned;
        uint256 size;
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(cap, ledger, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            returned := mload(0)
        }
        if (!ok || size != 32 || returned == 0) {
            revert SaleFloorCallFailed(ledger, bytes4(returned));
        }
    }

    function _call(address ledger, bytes memory data, uint256 cap) private {
        _admit(cap);
        bytes32 returned;
        uint256 size;
        bool ok;
        assembly ("memory-safe") {
            ok := call(cap, ledger, 0, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            returned := mload(0)
        }
        if (!ok || size != 32 || returned == 0) {
            revert SaleFloorCallFailed(ledger, bytes4(returned));
        }
    }

    function _binding() private view returns (address ledger, uint256 cap) {
        uint256 coreWord =
            _word(address(this), abi.encodeCall(IStreamPrimarySettlementBindings.core, ()));
        if (coreWord == 0 || coreWord > type(uint160).max) revert SaleFloorBindingUnavailable();
        address core = address(uint160(coreWord));
        if (core.code.length == 0) revert SaleFloorBindingUnavailable();
        bytes memory data = abi.encodeWithSignature("conservationFloor()");
        bytes32[2] memory values;
        uint256 size;
        bool ok;
        if (gasleft() <= READ_GAS + READ_GAS / 63 + RETURN_RESERVE) {
            revert SaleFloorInsufficientGas(READ_GAS);
        }
        assembly ("memory-safe") {
            ok := staticcall(READ_GAS, core, add(data, 32), mload(data), values, 64)
            size := returndatasize()
        }
        if (!ok || size != 64 || uint256(values[0]) > type(uint160).max) {
            revert SaleFloorBindingUnavailable();
        }
        ledger = address(uint160(uint256(values[0])));
        if (ledger.code.length == 0 || ledger.codehash != values[1]) {
            revert SaleFloorBindingUnavailable();
        }
        cap = _word(ledger, abi.encodeCall(IStreamGasParameterHost.gasParameter, (CALL_GAS)));
        if (cap == 0 || cap > type(uint256).max / 64) revert SaleFloorBindingUnavailable();
    }

    function _word(address target, bytes memory data) private view returns (uint256 value) {
        if (gasleft() <= READ_GAS + READ_GAS / 63 + RETURN_RESERVE) {
            revert SaleFloorInsufficientGas(READ_GAS);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(READ_GAS, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            value := mload(0)
        }
        if (!ok || size != 32) revert SaleFloorBindingUnavailable();
    }

    function _admit(uint256 cap) private view {
        if (gasleft() <= cap + cap / 63 + RETURN_RESERVE + 3300) {
            revert SaleFloorInsufficientGas(cap);
        }
    }
}
