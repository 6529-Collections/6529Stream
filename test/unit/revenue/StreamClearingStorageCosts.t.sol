// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ClearingSaleTestBase.sol";

interface ClearingStorageCheats {
    function record() external;
    function accesses(address target)
        external
        returns (bytes32[] memory reads, bytes32[] memory writes);
}

/// @dev Conservative persisted-delta census. It omits transient writes, reads, calls and logs.
contract StreamClearingStorageCostsTest is ClearingSaleTestBase {
    event log_named_uint(string key, uint256 value);
    event PersistedStorageDelta(
        address indexed target, bytes32 indexed slot, bytes32 prior, bytes32 afterValue
    );

    struct Capture {
        address target;
        bytes32[] slots;
        bytes32[] values;
    }

    function _capture(address target) private returns (Capture memory c) {
        c.target = target;
        (, c.slots) = ClearingStorageCheats(address(vm)).accesses(target);
        c.values = new bytes32[](c.slots.length);
        for (uint256 i; i < c.slots.length; ++i) {
            c.values[i] = vm.load(target, c.slots[i]);
        }
    }

    function _count(Capture memory c) private returns (uint256 fresh, uint256 changed) {
        for (uint256 i; i < c.slots.length; ++i) {
            bool duplicate;
            for (uint256 j; j < i; ++j) {
                if (c.slots[i] == c.slots[j]) duplicate = true;
            }
            if (duplicate) continue;
            bytes32 prior = vm.load(c.target, c.slots[i]);
            if (prior == c.values[i]) continue;
            if (prior == 0 && c.values[i] != 0) ++fresh;
            else ++changed;
            emit PersistedStorageDelta(c.target, c.slots[i], prior, c.values[i]);
        }
    }

    function testCountActualPersistedFreshWordsBeforeAnyGasBudgetClaim() external {
        IStreamNativeClearingSale.ClearingPurchaseData memory d = _clearingData(1, payer, payer);
        uint256 snapshot = vm.snapshotState();
        ClearingStorageCheats(address(vm)).record();
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        Capture memory consumer = _capture(address(clearingSale));
        Capture memory officialRecorder = _capture(address(recorder));
        Capture memory mint = _capture(address(clearingManager));
        Capture memory identity = _capture(address(clearingCore));
        Capture memory fee = _capture(address(refundEntropy));
        require(vm.revertToState(snapshot), "original pre-purchase values restored");
        (uint256 consumerFresh, uint256 consumerChanged) = _count(consumer);
        (uint256 recorderFresh, uint256 recorderChanged) = _count(officialRecorder);
        (uint256 managerFresh,) = _count(mint);
        (uint256 coreFresh,) = _count(identity);
        (uint256 feeFresh,) = _count(fee);
        emit log_named_uint("CONSUMER_DISTINCT_ZERO_TO_NONZERO_WORDS", consumerFresh);
        emit log_named_uint("CONSUMER_DISTINCT_OTHER_CHANGED_WORDS", consumerChanged);
        emit log_named_uint("OFFICIAL_RECORDER_DISTINCT_ZERO_TO_NONZERO_WORDS", recorderFresh);
        emit log_named_uint("OFFICIAL_RECORDER_DISTINCT_OTHER_CHANGED_WORDS", recorderChanged);
        emit log_named_uint(
            "EXPLICIT_MANAGER_CORE_FEE_DOUBLE_FRESH_WORDS", managerFresh + coreFresh + feeFresh
        );
        // Each distinct zero->nonzero word needs an SSTORE_SET of at least20k in Paris,
        // even omitting its cold surcharge and every other operation. Unit doubles excluded.
        uint256 lower = (consumerFresh + recorderFresh) * 20000;
        emit log_named_uint("PRODUCTION_CONSUMER_RECORDER_FRESH_SSTORE_ONLY_LOWER_BOUND", lower);
        require(lower > 500000, "this unchanged storage schema cannot satisfy the collector gate");
        vm.prank(payer);
        clearingSale.purchase{ value: 1020 }(d);
        require(
            wallet.balance == 100 && recorder.totalOfficialSettled(address(0)) == 100
                && clearingSale.totalBuyerLiabilities() == 900 && clearingManager.nonce() == 1,
            "same proof and actual accounting after storage census restore"
        );
    }
}
