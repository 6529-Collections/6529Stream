// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCoreConservationFloor.sol";
import "../../interfaces/stream/metadata/IStreamDirectPrimaryConservationFloor.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Fixed original floor call after genuine DIRECT payment and mint/transfer completion.
library StreamDirectPrimarySaleFloorCall {
    uint256 private constant READ_GAS = 100000;
    uint256 private constant RETURN_RESERVE = 100000;
    bytes32 private constant CALL_GAS = keccak256("6529STREAM_GGP_CONSERVATION_FLOOR_CALL_GAS");

    error DirectSaleFloorBindingUnavailable();
    error DirectSaleFloorCallFailed(address ledger, bytes4 cause);
    error DirectSaleFloorInsufficientGas(uint256 cap);

    function record(address core, bytes32 authorizationId) public {
        _admit(READ_GAS);
        bytes memory data = abi.encodeCall(IStreamCoreConservationFloor.conservationFloor, ());
        uint256[2] memory binding;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(READ_GAS, core, add(data, 32), mload(data), binding, 64)
            size := returndatasize()
        }
        if (!ok || size != 64 || binding[0] == 0 || binding[0] > type(uint160).max) {
            revert DirectSaleFloorBindingUnavailable();
        }
        address ledger = address(uint160(binding[0]));
        if (ledger.code.length == 0 || ledger.codehash != bytes32(binding[1])) {
            revert DirectSaleFloorBindingUnavailable();
        }
        _admit(READ_GAS);
        data = abi.encodeCall(IStreamGasParameterHost.gasParameter, (CALL_GAS));
        uint256 cap;
        assembly ("memory-safe") {
            ok := staticcall(READ_GAS, ledger, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            cap := mload(0)
        }
        if (!ok || size != 32 || cap == 0 || cap > type(uint256).max / 64) {
            revert DirectSaleFloorBindingUnavailable();
        }
        data = abi.encodeCall(
            IStreamDirectPrimaryConservationFloor.recordDirectPrimarySale, (authorizationId)
        );
        _admit(cap);
        bytes32 returned;
        assembly ("memory-safe") {
            ok := call(cap, ledger, 0, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            returned := mload(0)
        }
        if (!ok || size != 32 || returned == 0) {
            revert DirectSaleFloorCallFailed(ledger, bytes4(returned));
        }
    }

    function _admit(uint256 cap) private view {
        if (gasleft() <= cap + cap / 63 + RETURN_RESERVE + 3300) {
            revert DirectSaleFloorInsufficientGas(cap);
        }
    }
}
