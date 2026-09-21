// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    FoundryAccountStateExport as Export,
    FoundryAccountStateExportVm
} from "../../helpers/FoundryAccountStateExport.sol";
import {
    FoundryAccountStatePostRecording as PostRecording
} from "../../helpers/FoundryAccountStatePostRecording.sol";

interface PostRecordingTestVm is FoundryAccountStateExportVm {
    function expectRevert(bytes calldata reason) external;
    function computeCreateAddress(address creator, uint256 nonce) external pure returns (address);
}

contract PostRecordingLeaf {
    uint256 public value = 91;
}

contract PostRecordingDelegate {
    function write(uint256 value) external {
        assembly ("memory-safe") {
            sstore(0, value)
        }
    }
}

contract PostRecordingSubject {
    uint256 public scalar = 7;
    mapping(uint256 => uint256) public values;
    uint256[] public numbers;

    constructor() payable {
        values[3] = 11;
        numbers.push(13);
        numbers.push(17);
    }

    function delegateWrite(address implementation, uint256 value) external {
        (bool ok,) =
            implementation.delegatecall(abi.encodeCall(PostRecordingDelegate.write, (value)));
        require(ok);
    }

    function writeAndRevert() external {
        scalar = 999;
        values[3] = 888;
        revert("intentional nested rollback");
    }

    function createAndRevert() external {
        new PostRecordingLeaf();
        revert("intentional create rollback");
    }
}

contract PostRecordingDestroyed {
    function destroy(address payable recipient) external {
        selfdestruct(recipient);
    }
}

/// @notice Genuine local CREATE/read controls for the fixed post-recording library boundary.
/// @dev Parity inputs here are typed snapshots, not claimed native dumps or admitted protocol state.
contract FoundryAccountStatePostRecordingTest {
    PostRecordingTestVm private constant vm =
        PostRecordingTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private rootValue;

    function testCapturedReadsKeepHostContextAndOriginalAccessDigest() public {
        address[] memory seeds = _seeds();
        Export.begin();
        rootValue = 33;
        PostRecordingSubject subject = new PostRecordingSubject{ value: 7 }();
        PostRecordingDelegate implementation = new PostRecordingDelegate();
        subject.delegateWrite(address(implementation), 23);
        (bool ok,) = address(subject).call(abi.encodeCall(subject.writeAndRevert, ()));
        require(!ok);
        address rejected = vm.computeCreateAddress(address(subject), vm.getNonce(address(subject)));
        (ok,) = address(subject).call(abi.encodeCall(subject.createAndRevert, ()));
        require(!ok);
        FoundryAccountStateExportVm.AccountAccess[] memory diff = vm.stopAndReturnStateDiff();
        vm.stopRecord();
        bytes32 expectedHash = keccak256(abi.encode(diff));
        for (uint256 i; i < diff.length; ++i) {
            require(diff[i].account != address(PostRecording), "worker is outside recording");
            require(diff[i].accessor != address(PostRecording), "no recorded worker frame");
        }
        Export.Snapshot memory saved =
            PostRecording.finishCaptured(diff, seeds, new Export.SlotSeed[](0));
        require(saved.accessHash == expectedHash && saved.accessCount == diff.length);
        Export.Account memory a = saved.accounts[_index(saved.accounts, address(subject))];
        require(a.nonce == 1 && a.balance == 7 && a.codeHash == address(subject).codehash);
        require(keccak256(a.code) == address(subject).codehash);
        require(_slot(a, bytes32(0)) == bytes32(uint256(23)));
        require(_slot(a, keccak256(abi.encode(uint256(3), uint256(1)))) == bytes32(uint256(11)));
        require(_slot(a, bytes32(uint256(2))) == bytes32(uint256(2)));
        bytes32 start = keccak256(abi.encode(uint256(2)));
        require(_slot(a, start) == bytes32(uint256(13)));
        require(_slot(a, bytes32(uint256(start) + 1)) == bytes32(uint256(17)));
        require(
            _slot(saved.accounts[_index(saved.accounts, address(this))], bytes32(0))
                == bytes32(uint256(33))
        );
        Export.Account memory absent = saved.accounts[_index(saved.accounts, rejected)];
        require(
            absent.codeHash == 0 && absent.code.length == 0 && absent.balance == 0
                && absent.nonce == 0
        );
        require(!_created(saved, rejected));
        require(_created(saved, address(subject)) && _created(saved, address(implementation)));
        Export.Account memory worker =
            saved.accounts[_index(saved.accounts, address(PostRecording))];
        require(worker.codeHash == address(PostRecording).codehash && worker.code.length != 0);
        require(!_created(saved, address(PostRecording)), "linked worker is explicit prestate");
        PostRecording.requireDumpParity(saved, _without(saved.accounts, rejected), new address[](0));
    }

    function testCapturedRejectsForkAndChainMismatch() public {
        FoundryAccountStateExportVm.AccountAccess[] memory diff =
            new FoundryAccountStateExportVm.AccountAccess[](1);
        diff[0].chainInfo = FoundryAccountStateExportVm.ChainInfo(1, block.chainid);
        vm.expectRevert(
            abi.encodeWithSelector(Export.UnsupportedForkOrChain.selector, 1, block.chainid)
        );
        PostRecording.finishCaptured(diff, new address[](0), new Export.SlotSeed[](0));
        diff[0].chainInfo = FoundryAccountStateExportVm.ChainInfo(0, block.chainid + 1);
        vm.expectRevert(
            abi.encodeWithSelector(Export.UnsupportedForkOrChain.selector, 0, block.chainid + 1)
        );
        PostRecording.finishCaptured(diff, new address[](0), new Export.SlotSeed[](0));
    }

    function testCapturedRejectsGenuineSelfDestruct() public {
        address[] memory seeds = _seeds();
        Export.begin();
        PostRecordingDestroyed subject = new PostRecordingDestroyed();
        subject.destroy(payable(address(this)));
        FoundryAccountStateExportVm.AccountAccess[] memory diff = vm.stopAndReturnStateDiff();
        vm.stopRecord();
        vm.expectRevert(
            abi.encodeWithSelector(Export.UnsupportedSelfDestruct.selector, address(subject))
        );
        PostRecording.finishCaptured(diff, seeds, new Export.SlotSeed[](0));
    }

    function testParityKeepsHostOmissionRulesAndMismatchErrors() public {
        address[] memory seeds = _seeds();
        Export.begin();
        PostRecordingLeaf leaf = new PostRecordingLeaf();
        FoundryAccountStateExportVm.AccountAccess[] memory diff = vm.stopAndReturnStateDiff();
        vm.stopRecord();
        Export.Snapshot memory saved =
            PostRecording.finishCaptured(diff, seeds, new Export.SlotSeed[](0));
        PostRecording.requireDumpParity(saved, saved.accounts, new address[](0));
        address[] memory omissions = new address[](1);
        omissions[0] = address(this);
        PostRecording.requireDumpParity(saved, _without(saved.accounts, address(this)), omissions);
        Export.Account[] memory changed = abi.decode(abi.encode(saved.accounts), (Export.Account[]));
        changed[_index(changed, address(leaf))].balance += 1;
        vm.expectRevert(abi.encodeWithSelector(Export.DumpAccountMismatch.selector, address(leaf)));
        PostRecording.requireDumpParity(saved, changed, new address[](0));
        omissions[0] = address(leaf);
        Export.Account[] memory missing = _without(saved.accounts, address(leaf));
        vm.expectRevert(
            abi.encodeWithSelector(Export.CreatedAccountOmitted.selector, address(leaf))
        );
        PostRecording.requireDumpParity(saved, missing, omissions);
        vm.expectRevert(abi.encodeWithSelector(Export.MissingDumpAccount.selector, address(leaf)));
        PostRecording.requireDumpParity(saved, missing, new address[](0));
    }

    function _seeds() private view returns (address[] memory seeds) {
        require(address(PostRecording).code.length != 0, "genuine linked native worker");
        seeds = new address[](2);
        seeds[0] = address(this);
        seeds[1] = address(PostRecording);
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
