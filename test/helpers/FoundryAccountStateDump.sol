// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { FoundryAccountStateExport as Export } from "./FoundryAccountStateExport.sol";

interface FoundryAccountStateDumpVm {
    function parseJsonKeys(string calldata json, string calldata path)
        external
        pure
        returns (string[] memory);
}

/// @notice Strict reader for the account map written by the pinned Foundry dumpState cheatcode.
/// @dev Foundry 1.7.1, commit 4072e48705af9d93e3c0f6e29e93b5e9a40caed8:
/// crates/cheatcodes/src/evm.rs dumpStateCall and genesis_account. This is not an Anvil load-state
/// reader or a generic genesis parser. The native writer emits ordered BTreeMaps, hex quantities,
/// fixed-width addresses/slots/values, nonce and storage even when zero/empty, and optional code.
/// The raw cursor validates every key before accepting values: serde JSON duplicate-key collapse
/// cannot erase an account, field, or slot. Escaped keys and unknown/private-key fields are refused.
/// An omitted account stays omitted; every included account has keccak256(code), never codeHash 0.
/// Omitted code means empty bytes in this transport only. Final live-read parity must independently
/// reject an omitted runtime for a live contract. Parsing alone does not establish state closure.
library FoundryAccountStateDump {
    FoundryAccountStateDumpVm private constant VM =
        FoundryAccountStateDumpVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Cursor {
        bytes raw;
        uint256 at;
    }

    error InvalidDump();
    error NonCanonicalAccountOrder(address account);
    error NonCanonicalSlotOrder(bytes32 slot);
    error DuplicateField();
    error EmptyDumpAccount(address account);

    function parse(string memory raw) internal pure returns (Export.Account[] memory accounts) {
        // This supplies an allocation bound, not authority for the raw keys or their uniqueness.
        string[] memory keys = VM.parseJsonKeys(raw, ".");
        accounts = new Export.Account[](keys.length);
        Cursor memory c = Cursor(bytes(raw), 0);
        _take(c, "{");
        uint256 count;
        address previous;
        if (_peek(c) != "}") {
            while (true) {
                address account = address(uint160(_fixed(c, 40)));
                if (count != 0 && uint160(account) <= uint160(previous)) {
                    revert NonCanonicalAccountOrder(account);
                }
                if (count == accounts.length) revert InvalidDump();
                _take(c, ":");
                accounts[count++] = _account(c, account);
                previous = account;
                if (_peek(c) == "}") break;
                _take(c, ",");
            }
        }
        _take(c, "}");
        _space(c);
        if (count != accounts.length || c.at != c.raw.length) revert InvalidDump();
    }

    /// @dev Discovery seeds preserve every explicitly dumped slot, including slots whose value is
    /// zero. Inputs must retain the parser's unique numeric order; no account or slot is fabricated.
    function seeds(Export.Account[] memory accounts)
        internal
        pure
        returns (address[] memory requiredSeedAccounts, Export.SlotSeed[] memory explicitSlotSeeds)
    {
        requiredSeedAccounts = new address[](accounts.length);
        uint256 count;
        for (uint256 i; i < accounts.length; ++i) {
            count += accounts[i].slots.length;
        }
        explicitSlotSeeds = new Export.SlotSeed[](count);
        uint256 next;
        for (uint256 i; i < accounts.length; ++i) {
            Export.Account memory a = accounts[i];
            if (i != 0 && uint160(a.account) <= uint160(accounts[i - 1].account)) {
                revert NonCanonicalAccountOrder(a.account);
            }
            requiredSeedAccounts[i] = a.account;
            for (uint256 j; j < a.slots.length; ++j) {
                if (j != 0 && uint256(a.slots[j].slot) <= uint256(a.slots[j - 1].slot)) {
                    revert NonCanonicalSlotOrder(a.slots[j].slot);
                }
                explicitSlotSeeds[next++] = Export.SlotSeed(a.account, a.slots[j].slot);
            }
        }
    }

    function _account(Cursor memory c, address account)
        private
        pure
        returns (Export.Account memory a)
    {
        a.account = account;
        a.code = new bytes(0);
        _take(c, "{");
        uint256 fields;
        while (true) {
            (uint256 start, uint256 length) = _quoted(c);
            bytes32 name = keccak256(_slice(c.raw, start, length));
            uint256 flag;
            if (name == keccak256("nonce")) flag = 1;
            else if (name == keccak256("balance")) flag = 2;
            else if (name == keccak256("code")) flag = 4;
            else if (name == keccak256("storage")) flag = 8;
            else revert InvalidDump();
            if (fields & flag != 0) revert DuplicateField();
            fields |= flag;
            _take(c, ":");
            if (flag == 1) a.nonce = uint64(_quantity(c, 16));
            else if (flag == 2) a.balance = _quantity(c, 64);
            else if (flag == 4) a.code = _code(c);
            else a.slots = _storage(c);
            if (_peek(c) == "}") break;
            _take(c, ",");
        }
        _take(c, "}");
        if (fields & 11 != 11) revert InvalidDump();
        if (a.nonce == 0 && a.balance == 0 && a.code.length == 0) {
            revert EmptyDumpAccount(account);
        }
        a.codeHash = keccak256(a.code);
    }

    function _storage(Cursor memory c) private pure returns (Export.SlotValue[] memory slots) {
        // Separate cursor: assigning c directly would alias and consume the real cursor.
        Cursor memory look = Cursor(c.raw, c.at);
        _take(look, "{");
        uint256 count;
        bytes32 previous;
        if (_peek(look) != "}") {
            while (true) {
                bytes32 slot = bytes32(_fixed(look, 64));
                if (count != 0 && uint256(slot) <= uint256(previous)) {
                    revert NonCanonicalSlotOrder(slot);
                }
                _take(look, ":");
                _fixed(look, 64);
                previous = slot;
                ++count;
                if (_peek(look) == "}") break;
                _take(look, ",");
            }
        }
        _take(look, "}");
        slots = new Export.SlotValue[](count);
        _take(c, "{");
        for (uint256 i; i < count; ++i) {
            slots[i].slot = bytes32(_fixed(c, 64));
            _take(c, ":");
            slots[i].value = bytes32(_fixed(c, 64));
            if (i + 1 != count) _take(c, ",");
        }
        _take(c, "}");
    }

    function _fixed(Cursor memory c, uint256 digits) private pure returns (uint256 value) {
        (uint256 start, uint256 length) = _quoted(c);
        if (length != digits + 2) revert InvalidDump();
        return _hex(c.raw, start, length);
    }

    function _quantity(Cursor memory c, uint256 maxDigits) private pure returns (uint256 value) {
        (uint256 start, uint256 length) = _quoted(c);
        if (length < 3 || length > maxDigits + 2) revert InvalidDump();
        if (length > 3 && c.raw[start + 2] == "0") revert InvalidDump();
        return _hex(c.raw, start, length);
    }

    function _code(Cursor memory c) private pure returns (bytes memory value) {
        (uint256 start, uint256 length) = _quoted(c);
        if (length < 2 || length % 2 != 0) revert InvalidDump();
        _prefix(c.raw, start);
        value = new bytes((length - 2) / 2);
        for (uint256 i; i < value.length; ++i) {
            value[i] = bytes1(
                (_digit(c.raw[start + 2 + i * 2]) << 4) | _digit(c.raw[start + 3 + i * 2])
            );
        }
    }

    function _hex(bytes memory raw, uint256 start, uint256 length)
        private
        pure
        returns (uint256 value)
    {
        _prefix(raw, start);
        for (uint256 i = 2; i < length; ++i) {
            value = (value << 4) | _digit(raw[start + i]);
        }
    }

    function _prefix(bytes memory raw, uint256 start) private pure {
        if (raw[start] != "0" || raw[start + 1] != "x") revert InvalidDump();
    }

    function _digit(bytes1 ch) private pure returns (uint8) {
        uint8 v = uint8(ch);
        if (v >= 48 && v <= 57) return v - 48;
        if (v >= 97 && v <= 102) return v - 87;
        if (v >= 65 && v <= 70) return v - 55;
        revert InvalidDump();
    }

    function _quoted(Cursor memory c) private pure returns (uint256 start, uint256 length) {
        _take(c, '"');
        start = c.at;
        while (c.at < c.raw.length && c.raw[c.at] != '"') {
            // The dump writer has no string needing escapes; reject aliases and control bytes.
            if (c.raw[c.at] == "\\" || uint8(c.raw[c.at]) < 32) revert InvalidDump();
            ++c.at;
        }
        length = c.at - start;
        _take(c, '"');
    }

    function _slice(bytes memory raw, uint256 start, uint256 length)
        private
        pure
        returns (bytes memory result)
    {
        result = new bytes(length);
        for (uint256 i; i < length; ++i) {
            result[i] = raw[start + i];
        }
    }

    function _take(Cursor memory c, bytes1 expected) private pure {
        if (_peek(c) != expected) revert InvalidDump();
        ++c.at;
    }

    function _peek(Cursor memory c) private pure returns (bytes1) {
        _space(c);
        if (c.at == c.raw.length) revert InvalidDump();
        return c.raw[c.at];
    }

    function _space(Cursor memory c) private pure {
        while (c.at < c.raw.length) {
            bytes1 ch = c.raw[c.at];
            if (ch != " " && ch != "\n" && ch != "\r" && ch != "\t") return;
            ++c.at;
        }
    }
}
