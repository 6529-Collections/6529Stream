// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    FoundryAccountStateExport as Export,
    FoundryAccountStateExportVm
} from "../../helpers/FoundryAccountStateExport.sol";

interface ExportTestVm is FoundryAccountStateExportVm {
    function deal(address account, uint256 value) external;
    function store(address account, bytes32 slot, bytes32 value) external;
    function etch(address account, bytes calldata code) external;
    function expectRevert(bytes calldata reason) external;
    function computeCreateAddress(address creator, uint256 nonce) external pure returns (address);
}

contract ExportLeaf {
    uint256 public value = 91;
}

contract ExportDelegate {
    function write(uint256 value) external {
        assembly ("memory-safe") {
            sstore(0, value)
        }
    }
}

contract ExportSubject {
    uint256 public scalar;
    mapping(uint256 => uint256) public values;
    uint256[] public numbers;
    bytes public raw;

    constructor() {
        scalar = 7;
        values[3] = 11;
        numbers.push(13);
        numbers.push(17);
        raw = new bytes(70);
        raw[0] = 0xa1;
        raw[33] = 0xb2;
        raw[69] = 0xc3;
    }

    function delegateWrite(address implementation, uint256 value) external {
        (bool ok,) = implementation.delegatecall(abi.encodeCall(ExportDelegate.write, (value)));
        require(ok);
    }

    function writeAndRevert() external {
        scalar = 999;
        values[3] = 888;
        revert("intentional nested rollback");
    }

    function createAndRevert() external {
        new ExportLeaf();
        revert("intentional create rollback");
    }
}

contract ExportDestroyed {
    function destroy(address payable recipient) external {
        selfdestruct(recipient);
    }
}

/// @notice Small genuine EVM source cases for discovery and final reads; execution remains required.
/// @dev The dump-comparison cases use explicitly typed packets, not a claimed native JSON dump.
/// Parent transport tests must parse an actual pinned-tool dump and verify serialization/import.
/// deal/store/etch here affect test sentinels only, never a protocol deployment or its authority.
contract FoundryAccountStateExportTest {
    ExportTestVm private constant vm =
        ExportTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private rootValue;

    function testConstructorMappingDynamicSlotsAndFinalDelegateStorage() public {
        Export.begin();
        ExportSubject subject = new ExportSubject();
        ExportDelegate implementation = new ExportDelegate();
        subject.delegateWrite(address(implementation), 23);
        Export.Snapshot memory saved = Export.finish(_rootSeed(), new Export.SlotSeed[](0));
        Export.Account memory a = _account(saved, address(subject));
        require(
            keccak256(a.code) == address(subject).codehash
                && a.codeHash == address(subject).codehash
        );
        require(a.nonce == 1 && a.balance == 0 && saved.accessCount != 0 && saved.accessHash != 0);
        require(_slot(a, bytes32(0)) == bytes32(uint256(23)));
        require(_slot(a, keccak256(abi.encode(uint256(3), uint256(1)))) == bytes32(uint256(11)));
        require(_slot(a, bytes32(uint256(2))) == bytes32(uint256(2)));
        bytes32 start = keccak256(abi.encode(uint256(2)));
        require(_slot(a, start) == bytes32(uint256(13)));
        require(_slot(a, bytes32(uint256(start) + 1)) == bytes32(uint256(17)));
        require(_slot(a, bytes32(uint256(3))) == bytes32(uint256(141)));
        start = keccak256(abi.encode(uint256(3)));
        for (uint256 i; i < 3; ++i) {
            bytes32 key = bytes32(uint256(start) + i);
            require(_slot(a, key) == vm.load(address(subject), key));
        }
        Export.Account memory libraryAccount = _account(saved, address(implementation));
        for (uint256 i; i < libraryAccount.slots.length; ++i) {
            require(libraryAccount.slots[i].value == 0, "delegate storage belongs to subject");
        }
        require(_created(saved, address(subject)) && _created(saved, address(implementation)));
    }

    function testRevertedWritesAndCreationUseFinalStateAndPreserveAbsence() public {
        Export.begin();
        ExportSubject subject = new ExportSubject();
        (bool ok,) = address(subject).call(abi.encodeCall(subject.writeAndRevert, ()));
        require(!ok);
        address rejected = vm.computeCreateAddress(address(subject), vm.getNonce(address(subject)));
        (ok,) = address(subject).call(abi.encodeCall(subject.createAndRevert, ()));
        require(!ok);
        Export.Snapshot memory saved = Export.finish(_rootSeed(), new Export.SlotSeed[](0));
        require(_slot(_account(saved, address(subject)), bytes32(0)) == bytes32(uint256(7)));
        require(
            _slot(_account(saved, address(subject)), keccak256(abi.encode(uint256(3), uint256(1))))
                == bytes32(uint256(11))
        );
        Export.Account memory absent = _account(saved, rejected);
        require(
            absent.codeHash == 0 && absent.code.length == 0 && absent.balance == 0
                && absent.nonce == 0
        );
        require(!_created(saved, rejected), "reverted CREATE is not an admitted creation");
        for (uint256 i; i < absent.slots.length; ++i) {
            require(absent.slots[i].value == 0);
        }
        Export.Account[] memory typedDump = _without(saved.accounts, rejected);
        Export.requireDumpParity(saved, typedDump, new address[](0));
        typedDump = abi.decode(abi.encode(saved.accounts), (Export.Account[]));
        typedDump[_index(typedDump, rejected)].codeHash = keccak256("");
        vm.expectRevert(abi.encodeWithSelector(Export.DumpAccountMismatch.selector, rejected));
        this.check(saved, typedDump, new address[](0));
    }

    function testExplicitMutationSeedsAndRootContextRecordingRereadActualValues() public {
        Export.begin();
        rootValue = 33;
        ExportLeaf sentinel = new ExportLeaf();
        vm.deal(address(sentinel), 5 ether);
        vm.store(address(sentinel), bytes32(uint256(42)), bytes32(uint256(99)));
        bytes memory actualCode = hex"60006000f3";
        vm.etch(address(sentinel), actualCode);
        Export.SlotSeed[] memory seeds = new Export.SlotSeed[](1);
        seeds[0] = Export.SlotSeed(address(sentinel), bytes32(uint256(42)));
        Export.Snapshot memory saved = Export.finish(_rootSeed(), seeds);
        Export.Account memory a = _account(saved, address(sentinel));
        require(a.balance == 5 ether && a.nonce == 1);
        require(keccak256(a.code) == keccak256(actualCode) && a.codeHash == keccak256(actualCode));
        require(_slot(a, bytes32(uint256(42))) == bytes32(uint256(99)));
        require(_slot(_account(saved, address(this)), bytes32(0)) == bytes32(uint256(33)));
    }

    function testMissingVmStoreSeedFailsExplicitDumpCoverage() public {
        Export.begin();
        ExportLeaf sentinel = new ExportLeaf();
        bytes32 key = bytes32(uint256(42));
        vm.store(address(sentinel), key, bytes32(uint256(99)));
        Export.Snapshot memory saved = Export.finish(_rootSeed(), new Export.SlotSeed[](0));
        Export.Account[] memory typedDump =
            abi.decode(abi.encode(saved.accounts), (Export.Account[]));
        uint256 index = _index(typedDump, address(sentinel));
        Export.SlotValue[] memory extra = new Export.SlotValue[](typedDump[index].slots.length + 1);
        for (uint256 i; i < typedDump[index].slots.length; ++i) {
            extra[i] = typedDump[index].slots[i];
        }
        extra[extra.length - 1] = Export.SlotValue(key, vm.load(address(sentinel), key));
        typedDump[index].slots = extra;
        vm.expectRevert(
            abi.encodeWithSelector(Export.UnknownDumpSlot.selector, address(sentinel), key)
        );
        this.check(saved, typedDump, new address[](0));
    }

    function testExplicitPrestateSeedExportsActualCodeNonceBalanceAndSlot() public {
        ExportLeaf existing = new ExportLeaf();
        vm.deal(address(existing), 17);
        Export.begin();
        address[] memory accounts = new address[](2);
        accounts[0] = address(this);
        accounts[1] = address(existing);
        Export.SlotSeed[] memory seeds = new Export.SlotSeed[](1);
        seeds[0] = Export.SlotSeed(address(existing), bytes32(0));
        Export.Snapshot memory saved = Export.finish(accounts, seeds);
        Export.Account memory a = _account(saved, address(existing));
        require(a.nonce == 1 && a.balance == 17 && a.codeHash == address(existing).codehash);
        require(_slot(a, bytes32(0)) == bytes32(uint256(91)) && !_created(saved, address(existing)));
    }

    function testTypedDumpMismatchMissingCoverageAndCreatedOmissionRefuse() public {
        Export.begin();
        ExportLeaf scenario = new ExportLeaf();
        Export.Snapshot memory saved = Export.finish(_rootSeed(), new Export.SlotSeed[](0));
        Export.Account[] memory typedDump =
            abi.decode(abi.encode(saved.accounts), (Export.Account[]));
        typedDump[_index(typedDump, address(scenario))].balance += 1;
        vm.expectRevert(
            abi.encodeWithSelector(Export.DumpAccountMismatch.selector, address(scenario))
        );
        this.check(saved, typedDump, new address[](0));
        typedDump = _without(saved.accounts, address(scenario));
        vm.expectRevert(
            abi.encodeWithSelector(Export.MissingDumpAccount.selector, address(scenario))
        );
        this.check(saved, typedDump, new address[](0));
        address[] memory omissions = new address[](1);
        omissions[0] = address(scenario);
        vm.expectRevert(
            abi.encodeWithSelector(Export.CreatedAccountOmitted.selector, address(scenario))
        );
        this.check(saved, typedDump, omissions);
        typedDump = _without(saved.accounts, address(this));
        omissions[0] = address(this);
        Export.requireDumpParity(saved, typedDump, omissions);
        Export.requireDumpParity(saved, saved.accounts, new address[](0));
    }

    function testUnsupportedSelfDestructFailsInsteadOfExportingPreFinalizationCode() public {
        Export.begin();
        ExportDestroyed subject = new ExportDestroyed();
        subject.destroy(payable(address(this)));
        vm.expectRevert(
            abi.encodeWithSelector(Export.UnsupportedSelfDestruct.selector, address(subject))
        );
        this.finish();
    }

    function finish() external returns (Export.Snapshot memory) {
        require(msg.sender == address(this));
        return Export.finish(_rootSeed(), new Export.SlotSeed[](0));
    }

    function check(
        Export.Snapshot memory saved,
        Export.Account[] memory dump,
        address[] memory omissions
    ) external view {
        require(msg.sender == address(this));
        Export.requireDumpParity(saved, dump, omissions);
    }

    function _rootSeed() private view returns (address[] memory a) {
        a = new address[](1);
        a[0] = address(this);
    }

    function _account(Export.Snapshot memory saved, address target)
        private
        pure
        returns (Export.Account memory)
    {
        return saved.accounts[_index(saved.accounts, target)];
    }

    function _index(Export.Account[] memory accounts, address target)
        private
        pure
        returns (uint256)
    {
        for (uint256 i; i < accounts.length; ++i) {
            if (accounts[i].account == target) return i;
        }
        revert("expected captured account");
    }

    function _slot(Export.Account memory a, bytes32 key) private pure returns (bytes32) {
        for (uint256 i; i < a.slots.length; ++i) {
            if (a.slots[i].slot == key) return a.slots[i].value;
        }
        revert("expected captured slot");
    }

    function _created(Export.Snapshot memory saved, address account) private pure returns (bool) {
        for (uint256 i; i < saved.createdAccounts.length; ++i) {
            if (saved.createdAccounts[i] == account) return true;
        }
        return false;
    }

    function _without(Export.Account[] memory accounts, address target)
        private
        pure
        returns (Export.Account[] memory result)
    {
        result = new Export.Account[](accounts.length - 1);
        uint256 next;
        for (uint256 i; i < accounts.length; ++i) {
            if (accounts[i].account != target) result[next++] = accounts[i];
        }
        require(next == result.length);
    }
}
