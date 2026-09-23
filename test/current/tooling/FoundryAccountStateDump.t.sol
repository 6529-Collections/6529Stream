// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { FoundryAccountStateDump as Dump } from "../../helpers/FoundryAccountStateDump.sol";
import { FoundryAccountStateExport as Export } from "../../helpers/FoundryAccountStateExport.sol";

interface DumpTestVm {
    function dumpState(string calldata path) external;
    function readFile(string calldata path) external view returns (string memory);
    function createDir(string calldata path, bool recursive) external;
    function exists(string calldata path) external view returns (bool);
    function removeFile(string calldata path) external;
    function deal(address account, uint256 balance) external;
    function getNonce(address account) external view returns (uint64);
    function load(address account, bytes32 slot) external view returns (bytes32);
    function expectRevert() external;
    function expectRevert(bytes calldata reason) external;
}

contract DumpSubject {
    uint256 public scalar = 7;
    mapping(uint256 => uint256) public values;
    uint256 public cleared = 11;

    constructor() payable {
        values[3] = 19;
    }

    function clear() external {
        cleared = 0;
    }
}

contract DumpCodeLess {
    constructor() {
        assembly ("memory-safe") {
            return(0, 0)
        }
    }
}

/// @notice Source-authored native dump regression plus separate malformed-transport cases.
/// @dev The first case uses the genuine pinned vm.dumpState and actual CREATE/storage/value flows;
/// no mock supplies account JSON. Handwritten JSON below is expressly parser-boundary input.
/// Execution is still required. The runner must grant read-write ./artifacts/native-assembly (as
/// profile.current already does); the ordinary default unit profile does not grant this path.
/// This tests a small account map, not protocol setup closure, Anvil import, or deployment capacity.
contract FoundryAccountStateDumpTest {
    DumpTestVm private constant vm =
        DumpTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    string private constant ACCOUNT = "0x00000000000000000000000000000000000000ab";
    string private constant SLOT =
        "0x0000000000000000000000000000000000000000000000000000000000000000";
    string private constant ONE =
        "0x0000000000000000000000000000000000000000000000000000000000000001";

    function testActualDumpMatchesNativeReadsAndPreservesAbsentVersusCodeLess() public {
        // Funding the test caller is the sole VM state mutation; subjects use ordinary CREATE.
        vm.deal(address(this), 2 ether);
        DumpSubject subject = new DumpSubject{ value: 2 ether }();
        subject.clear();
        DumpCodeLess codeLess = new DumpCodeLess();
        address absent = address(uint160(0xfedcba123456789));
        require(absent.codehash == 0 && vm.getNonce(absent) == 0);

        string memory path = "./artifacts/native-assembly/foundry-account-state-dump-unit.json";
        vm.createDir("./artifacts/native-assembly", true);
        require(!vm.exists(path), "refuse an existing task output");
        vm.dumpState(path);
        string memory raw = vm.readFile(path);
        vm.removeFile(path);
        Export.Account[] memory accounts = Dump.parse(raw);
        uint256 subjectIndex = _index(accounts, address(subject));
        uint256 emptyCodeIndex = _index(accounts, address(codeLess));
        require(subjectIndex != type(uint256).max && emptyCodeIndex != type(uint256).max);
        require(_index(accounts, absent) == type(uint256).max, "absence is not a genesis EOA");
        require(_index(accounts, address(this)) == type(uint256).max, "native caller exclusion");

        for (uint256 i; i < accounts.length; ++i) {
            Export.Account memory a = accounts[i];
            require(a.codeHash == a.account.codehash && keccak256(a.code) == a.codeHash);
            require(a.balance == a.account.balance && a.nonce == vm.getNonce(a.account));
            for (uint256 j; j < a.slots.length; ++j) {
                require(a.slots[j].value == vm.load(a.account, a.slots[j].slot));
            }
        }
        Export.Account memory actual = accounts[subjectIndex];
        require(actual.balance == 2 ether && actual.nonce == 1 && actual.code.length != 0);
        require(_slot(actual, bytes32(0)) == bytes32(uint256(7)));
        bytes32 mapSlot = keccak256(abi.encode(uint256(3), uint256(1)));
        require(_slot(actual, mapSlot) == bytes32(uint256(19)));
        require(_slot(actual, bytes32(uint256(2))) == 0, "explicit zero storage is retained");
        require(accounts[emptyCodeIndex].code.length == 0 && accounts[emptyCodeIndex].nonce == 1);
        require(accounts[emptyCodeIndex].codeHash == keccak256(""), "present code-less account");

        (address[] memory addresses, Export.SlotSeed[] memory slots) = Dump.seeds(accounts);
        require(addresses.length == accounts.length);
        uint256 next;
        for (uint256 i; i < accounts.length; ++i) {
            require(addresses[i] == accounts[i].account);
            for (uint256 j; j < accounts[i].slots.length; ++j) {
                require(slots[next].account == accounts[i].account);
                require(slots[next++].slot == accounts[i].slots[j].slot);
            }
        }
        require(next == slots.length);
    }

    function testOptionalCodeAndEmptyMapDoNotSynthesizeAbsentAccounts() public pure {
        Export.Account[] memory a =
            Dump.parse(_wrap('{"nonce":"0x1","balance":"0x0","storage":{}}'));
        require(a.length == 1 && a[0].code.length == 0 && a[0].codeHash == keccak256(""));
        Export.Account[] memory b = Dump.parse(_wrap(_body("0x1", "0x0", "0x", "{}")));
        require(keccak256(abi.encode(a)) == keccak256(abi.encode(b)));
        a = Dump.parse("{ }");
        (address[] memory addresses, Export.SlotSeed[] memory slots) = Dump.seeds(a);
        require(a.length == 0 && addresses.length == 0 && slots.length == 0);
    }

    function testMaximumNonceAndBalanceAndFullWidthStorageAreExact() public pure {
        string memory balance = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
        string memory storageJSON = string.concat('{"', SLOT, '":"', ONE, '"}');
        Export.Account[] memory a =
            Dump.parse(_wrap(_body("0xffffffffffffffff", balance, "0x00ff", storageJSON)));
        require(a[0].nonce == type(uint64).max && a[0].balance == type(uint256).max);
        require(a[0].codeHash == keccak256(hex"00ff") && a[0].slots.length == 1);
        require(a[0].slots[0].slot == 0 && a[0].slots[0].value == bytes32(uint256(1)));
    }

    function testDuplicateAddressCannotBeCollapsedByJsonCheatcode() public {
        string memory body = _body("0x1", "0x0", "0x", "{}");
        string memory raw = string.concat('{"', ACCOUNT, '":', body, ',"', ACCOUNT, '":', body, "}");
        _reject(
            raw,
            abi.encodeWithSelector(Dump.NonCanonicalAccountOrder.selector, address(uint160(0xab)))
        );
        raw = string.concat(
            '{"', ACCOUNT, '":', body, ',"0x00000000000000000000000000000000000000AB":', body, "}"
        );
        _reject(
            raw,
            abi.encodeWithSelector(Dump.NonCanonicalAccountOrder.selector, address(uint160(0xab)))
        );
    }

    function testDuplicateFieldAndStorageKeyCannotBeCollapsed() public {
        _reject(
            _wrap('{"nonce":"0x1","nonce":"0x2","balance":"0x0","storage":{}}'),
            abi.encodeWithSelector(Dump.DuplicateField.selector)
        );
        string memory storageJSON =
            string.concat('{"', SLOT, '":"', SLOT, '","', SLOT, '":"', ONE, '"}');
        _reject(
            _wrap(_body("0x1", "0x0", "0x", storageJSON)),
            abi.encodeWithSelector(Dump.NonCanonicalSlotOrder.selector, bytes32(0))
        );
    }

    function testAddressAndStorageWordWidthsAreStrict() public {
        _invalid(string.concat('{"0xab":', _body("0x1", "0x0", "0x", "{}"), "}"));
        _invalid(_wrap(_body("0x1", "0x0", "0x", string.concat('{"0x0":"', SLOT, '"}'))));
        _invalid(_wrap(_body("0x1", "0x0", "0x", string.concat('{"', SLOT, '":"0x1"}'))));
    }

    function testQuantityWidthsAndCanonicalHexAreStrict() public {
        _invalid(_wrap(_body("0x10000000000000000", "0x0", "0x", "{}")));
        _invalid(
            _wrap(
                _body(
                    "0x1",
                    "0x10000000000000000000000000000000000000000000000000000000000000000",
                    "0x",
                    "{}"
                )
            )
        );
        _invalid(_wrap(_body("0x01", "0x0", "0x", "{}")));
        _invalid(_wrap(_body("0x1", "1", "0x", "{}")));
        _invalid(_wrap(_body("0x1", "0x0", "0x0", "{}")));
        _invalid(_wrap(_body("0x1", "0x0", "0xgg", "{}")));
    }

    function testUnknownPrivateKeyMissingFieldsAndEmptyAccountRefuse() public {
        _invalid(_wrap('{"nonce":"0x1","balance":"0x0","storage":{},"privateKey":"0x01"}'));
        _invalid(_wrap('{"nonce":"0x1","balance":"0x0","storage":{},"extra":0}'));
        _invalid(_wrap('{"nonce":"0x1","balance":"0x0"}'));
        _invalid(_wrap('{"nonce":"0x1","balance":"0x0","storage":null}'));
        _reject(
            _wrap(_body("0x0", "0x0", "0x", "{}")),
            abi.encodeWithSelector(Dump.EmptyDumpAccount.selector, address(uint160(0xab)))
        );
    }

    function testMalformedJsonAndEscapedKeyRefuse() public {
        vm.expectRevert();
        this.parse('{"unfinished":');
        vm.expectRevert();
        this.parse("[]");
        _invalid(_wrap('{"no\\u006ece":"0x1","balance":"0x0","storage":{}}'));
        vm.expectRevert();
        this.parse(string.concat(_wrap(_body("0x1", "0x0", "0x", "{}")), "false"));
    }

    function testSeedsRejectDuplicateTypedAccountsAndSlots() public {
        Export.Account[] memory a = Dump.parse(_wrap(_body("0x1", "0x0", "0x", "{}")));
        Export.Account[] memory duplicate = new Export.Account[](2);
        duplicate[0] = a[0];
        duplicate[1] = a[0];
        vm.expectRevert(
            abi.encodeWithSelector(Dump.NonCanonicalAccountOrder.selector, a[0].account)
        );
        this.seeds(duplicate);
        a[0].slots = new Export.SlotValue[](2);
        a[0].slots[0] = Export.SlotValue(bytes32(0), bytes32(uint256(1)));
        a[0].slots[1] = Export.SlotValue(bytes32(0), bytes32(uint256(2)));
        vm.expectRevert(abi.encodeWithSelector(Dump.NonCanonicalSlotOrder.selector, bytes32(0)));
        this.seeds(a);
    }

    function parse(string memory raw) external pure returns (Export.Account[] memory) {
        return Dump.parse(raw);
    }

    function seeds(Export.Account[] memory accounts)
        external
        pure
        returns (address[] memory, Export.SlotSeed[] memory)
    {
        return Dump.seeds(accounts);
    }

    function _invalid(string memory raw) private {
        _reject(raw, abi.encodeWithSelector(Dump.InvalidDump.selector));
    }

    function _reject(string memory raw, bytes memory reason) private {
        vm.expectRevert(reason);
        this.parse(raw);
    }

    function _wrap(string memory body) private pure returns (string memory) {
        return string.concat('{"', ACCOUNT, '":', body, "}");
    }

    function _body(
        string memory nonce,
        string memory balance,
        string memory code,
        string memory storageJSON
    ) private pure returns (string memory) {
        return string.concat(
            '{"nonce":"',
            nonce,
            '","balance":"',
            balance,
            '","code":"',
            code,
            '","storage":',
            storageJSON,
            "}"
        );
    }

    function _index(Export.Account[] memory accounts, address account)
        private
        pure
        returns (uint256)
    {
        for (uint256 i; i < accounts.length; ++i) {
            if (accounts[i].account == account) return i;
        }
        return type(uint256).max;
    }

    function _slot(Export.Account memory account, bytes32 slot) private pure returns (bytes32) {
        for (uint256 i; i < account.slots.length; ++i) {
            if (account.slots[i].slot == slot) return account.slots[i].value;
        }
        revert("missing actual native slot");
    }
}
