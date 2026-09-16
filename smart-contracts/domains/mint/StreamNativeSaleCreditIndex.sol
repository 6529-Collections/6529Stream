// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamNativeSaleCredits as C
} from "../../interfaces/stream/mint/IStreamNativeSaleCredits.sol";

/// @notice Identities only. All amounts remain exclusively in the original producer ledgers.
library StreamNativeSaleCreditIndex {
    bytes32 private constant SLOT = keccak256("6529STREAM_NATIVE_SALE_CREDIT_INDEX_V1");

    struct Key {
        bytes32 saleId;
        address account;
    }

    struct State {
        Key[] keys;
        mapping(bytes32 => mapping(address => bool)) seen;
    }
    event NativeSaleCreditAccountIndexed(
        uint16 schemaVersion, uint256 indexed index, bytes32 indexed saleId, address indexed account
    );

    function state() private pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function touch(bytes32 saleId, address account) internal {
        State storage s = state();
        if (s.seen[saleId][account]) return;
        if (saleId == 0 || account == address(0)) revert C.NativeSaleCreditPageInvalid();
        s.seen[saleId][account] = true;
        uint256 index = s.keys.length;
        s.keys.push(Key(saleId, account));
        emit NativeSaleCreditAccountIndexed(1, index, saleId, account);
    }

    function count() internal view returns (uint256) {
        return state().keys.length;
    }

    function key(uint256 index) internal view returns (bytes32 saleId, address account) {
        State storage s = state();
        if (index >= s.keys.length) revert C.NativeSaleCreditPageInvalid();
        Key storage k = s.keys[index];
        return (k.saleId, k.account);
    }
}
