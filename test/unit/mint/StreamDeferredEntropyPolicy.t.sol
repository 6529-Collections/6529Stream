// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamImmediateSaleEntropyPolicy.t.sol";
import {
    StreamDutchSaleSupport as Dutch
} from "../../../smart-contracts/domains/mint/StreamDutchSaleSupport.sol";
import {
    StreamRefundWindowSupport as Deferred
} from "../../../smart-contracts/domains/mint/StreamRefundWindowSupport.sol";

/// @dev Actual linked helpers, typed Core/Coordinator; this is not a full sale/auction fixture.
contract DeferredEntropyHarness {
    address public immutable core;
    address public immutable entropy;
    uint256 public credits;
    uint256 public executions;

    constructor(address c, address e) {
        core = c;
        entropy = e;
    }

    function _dutch() private view returns (Dutch.Context memory x) {
        x.core = core;
        x.entropy = F(entropy);
        x.entropyHash = entropy.codehash;
    }

    function _deferred() private view returns (Deferred.Context memory x) {
        x.core = core;
        x.entropy = F(entropy);
        x.entropyHash = entropy.codehash;
    }

    function quoteDutch() external view returns (F.CollectionRevealPolicy memory) {
        return Dutch.revealPolicy(_dutch(), 7);
    }

    function quoteDeferred() external view returns (F.CollectionRevealPolicy memory) {
        return Deferred.revealPolicy(_deferred(), 7);
    }

    function executeDutch(uint256 cap) external payable {
        F.CollectionRevealPolicy memory q = Dutch.revealPolicy(_dutch(), 7);
        Dutch.preflightReveal(q, cap);
        require(msg.value >= q.revealFeePerTokenWei);
        credits += msg.value - q.revealFeePerTokenWei;
        ++executions;
        Dutch.fundCapturedReveal(_dutch(), 7, 42, q, cap);
    }

    function finishDutch(F.CollectionRevealPolicy calldata q, uint256 cap) external payable {
        Dutch.fundCapturedReveal(_dutch(), 7, 42, q, cap);
    }

    function executeDeferred(uint256 cap)
        external
        payable
        returns (uint256 forwarded, uint256 remainder)
    {
        Deferred.preflightReveal(_deferred(), 7, cap);
        ++executions;
        (forwarded, remainder) = Deferred.fundRevealAndAttempt(_deferred(), 7, 42, msg.value, cap);
        credits += remainder;
    }
}

contract StreamDeferredEntropyPolicyTest is CharacterizationTestBase {
    TerminalSaleCoreFixture private core;
    TerminalSaleCoordinatorFixture private entropy;
    DeferredEntropyHarness private sale;

    function setUp() public {
        core = new TerminalSaleCoreFixture();
        entropy = new TerminalSaleCoordinatorFixture(address(core));
        core.set(address(entropy));
        sale = new DeferredEntropyHarness(address(core), address(entropy));
        vm.deal(address(this), 100 ether);
    }

    function testDutchDisabledAndBothInstantModesHaveNoFeeRequestOrUnusedGasRequirement() public {
        for (uint8 i; i < 3; ++i) {
            uint8 kind = i == 0 ? 0 : i + 2;
            entropy.configure(kind, 0);
            require(!sale.quoteDutch().declared);
            vm.recordLogs();
            sale.executeDutch{ value: 19 }(type(uint256).max);
            require(entropy.revealFeeEscrow(7) == 0 && entropy.requests() == 0);
            require(vm.getRecordedLogs().length == 0);
        }
        require(sale.credits() == 57 && sale.executions() == 3);
    }

    function testDeferredDisabledAndBothInstantModesRefundSavedFeeWithoutRequest() public {
        for (uint8 i; i < 3; ++i) {
            entropy.configure(i == 0 ? 0 : i + 2, 0);
            require(!sale.quoteDeferred().declared);
            vm.recordLogs();
            (uint256 paid, uint256 rest) = sale.executeDeferred{ value: 19 }(type(uint256).max);
            require(
                paid == 0 && rest == 19 && entropy.revealFeeEscrow(7) == 0
                    && entropy.requests() == 0
            );
            require(vm.getRecordedLogs().length == 0);
        }
        require(sale.credits() == 57 && sale.executions() == 3);
    }

    function testDutchAsyncNotRequiredRetainsCapturedFeeAndExcess() public {
        entropy.configure(1, 9);
        vm.recordLogs();
        sale.executeDutch{ value: 12 }(100000);
        require(entropy.revealFeeEscrow(7) == 9 && sale.credits() == 3 && entropy.requests() == 0);
        require(vm.getRecordedLogs().length == 0);
    }

    function testDeferredAsyncNotRequiredPreservesLiveFeeReconciliation() public {
        entropy.configure(1, 9);
        (uint256 a, uint256 b) = sale.executeDeferred{ value: 12 }(100000);
        require(a == 9 && b == 3 && entropy.requests() == 0);
        entropy.configure(1, 15);
        (a, b) = sale.executeDeferred{ value: 12 }(100000);
        require(a == 12 && b == 0 && entropy.revealFeeEscrow(7) == 21 && sale.credits() == 3);
    }

    function testOriginalRequiredAsyncStillRequestsInBothWorkers() public {
        entropy.configure(2, 9);
        entropy.setCapability(false);
        sale.executeDutch{ value: 12 }(100000);
        sale.executeDeferred{ value: 12 }(100000);
        require(entropy.requests() == 2 && entropy.revealFeeEscrow(7) == 18 && sale.credits() == 6);
    }

    function testUndeclaredLegacyStillRejectsBothWorkers() public {
        entropy.setCapability(false);
        vm.expectRevert();
        sale.executeDutch(100000);
        vm.expectRevert();
        sale.executeDeferred(100000);
        require(sale.executions() == 0);
    }

    function testMalformedZeroPolicyAndAdvertisedCapabilityRejectBothWorkers() public {
        entropy.configure(3, 0);
        entropy.setReveal(F.CollectionRevealPolicy(false, 0, 0, 0, 1));
        vm.expectRevert();
        sale.quoteDutch();
        vm.expectRevert();
        sale.quoteDeferred();
        entropy.configure(3, 0);
        entropy.setFault(10);
        vm.expectRevert();
        sale.quoteDutch();
        vm.expectRevert();
        sale.quoteDeferred();
    }

    function testCapturedDutchInstantCannotBypassNewAsyncObligations() public {
        entropy.configure(3, 0);
        F.CollectionRevealPolicy memory q = sale.quoteDutch();
        entropy.configure(1, 9);
        vm.expectRevert();
        sale.finishDutch(q, 100000);
        require(entropy.revealFeeEscrow(7) == 0 && entropy.requests() == 0);
    }

    function testInstantForeignIdentityAndSeedFailuresRollbackBothWorkersThenRetry() public {
        entropy.configure(3, 0);
        core.setOriginal(address(123));
        vm.expectRevert();
        sale.executeDutch{ value: 7 }(100000);
        vm.expectRevert();
        sale.executeDeferred{ value: 7 }(100000);
        core.setOriginal(address(entropy));
        entropy.setFault(6);
        vm.expectRevert();
        sale.executeDutch{ value: 7 }(100000);
        vm.expectRevert();
        sale.executeDeferred{ value: 7 }(100000);
        require(sale.executions() == 0 && sale.credits() == 0);
        entropy.setFault(0);
        sale.executeDutch{ value: 7 }(type(uint256).max);
        sale.executeDeferred{ value: 7 }(type(uint256).max);
        require(sale.executions() == 2 && sale.credits() == 14 && entropy.requests() == 0);
    }

    function testFuzzDeferredAsyncSavedAndCurrentFeeConservation(uint96 saved, uint96 current)
        public
    {
        vm.deal(address(this), saved);
        entropy.configure(1, current);
        (uint256 paid, uint256 rest) = sale.executeDeferred{ value: saved }(100000);
        uint256 expected = saved < current ? saved : current;
        require(paid == expected && rest == uint256(saved) - expected);
        require(
            entropy.revealFeeEscrow(7) == expected && sale.credits() == rest
                && address(sale).balance == rest && entropy.requests() == 0
        );
    }
}
