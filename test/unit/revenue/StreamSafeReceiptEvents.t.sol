// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/OfficialSafeFixture.sol";

interface SafeReceiptVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function deal(address account, uint256 balance) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract SafeReceiptReceiver {
    uint256 public calls;
    address public sender;

    function record(bool fail) external payable {
        ++calls;
        sender = msg.sender;
        require(!fail, "Target rejected call");
    }
}

/// @notice Receipt layout and failure semantics of the pinned, unmodified upstream Safes.
/// @dev A successful outer transaction does not prove that its Safe CALL succeeded.
contract StreamSafeReceiptEventsTest is OfficialSafeFixture {
    SafeReceiptVm private constant vm =
        SafeReceiptVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant TARGET_GAS = 100_000;
    uint256 private constant VALUE = 0.2 ether;

    function testSafe130SuccessAndFailedCallReceipt() public {
        _exercise("1.3.0", false);
    }

    function testSafe141SuccessAndFailedCallReceipt() public {
        _exercise("1.4.1", true);
    }

    function testSafe150SuccessAndFailedCallReceipt() public {
        _exercise("1.5.0", true);
    }

    function _exercise(string memory version, bool indexedHash) private {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA1101;
        keys[1] = 0xA1102;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents(version), safeOwnerAddresses(keys), 2, 1);
        require(keccak256(bytes(account.VERSION())) == keccak256(bytes(version)), "version");
        SafeReceiptReceiver receiver = new SafeReceiptReceiver();
        vm.deal(address(account), 1 ether);

        _call(account, keys, receiver, false, indexedHash);
        require(receiver.calls() == 1 && receiver.sender() == address(account), "CALL sender");
        require(address(receiver).balance == VALUE, "CALL value");

        _call(account, keys, receiver, true, indexedHash);
        require(receiver.calls() == 1 && receiver.sender() == address(account), "failed state");
        require(address(receiver).balance == VALUE, "failed value rollback");
        require(address(account).balance == 1 ether - VALUE, "Safe balance");
    }

    function _call(
        OfficialSafe account,
        uint256[] memory keys,
        SafeReceiptReceiver receiver,
        bool fail,
        bool indexedHash
    ) private {
        uint256 nonce = account.nonce();
        bytes memory data = abi.encodeCall(receiver.record, (fail));
        bytes32 digest = account.getTransactionHash(
            address(receiver), VALUE, data, 0, TARGET_GAS, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        vm.recordLogs();
        // A nonzero safeTxGas allows a failed target to return false and emit ExecutionFailure.
        bool success = account.execTransaction(
            address(receiver),
            VALUE,
            data,
            0,
            TARGET_GAS,
            0,
            0,
            address(0),
            payable(address(0)),
            signatures
        );
        require(success != fail, "actual target result");
        require(account.nonce() == nonce + 1, "Safe consumes nonce for either result");
        SafeReceiptVm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = fail
            ? keccak256("ExecutionFailure(bytes32,uint256)")
            : keccak256("ExecutionSuccess(bytes32,uint256)");
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(account)) continue;
            require(logs[i].topics[0] == topic, "event result");
            ++matches;
            if (indexedHash) {
                require(logs[i].topics.length == 2 && logs[i].topics[1] == digest, "indexed hash");
                require(logs[i].data.length == 32, "indexed event size");
                require(abi.decode(logs[i].data, (uint256)) == 0, "indexed payment");
            } else {
                require(
                    logs[i].topics.length == 1 && logs[i].data.length == 64, "legacy event size"
                );
                (bytes32 eventHash, uint256 payment) = abi.decode(logs[i].data, (bytes32, uint256));
                require(eventHash == digest && payment == 0, "legacy hash and payment");
            }
        }
        require(matches == 1, "one exact Safe execution event");
    }
}
