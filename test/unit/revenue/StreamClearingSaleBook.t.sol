// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/domains/mint/StreamClearingSaleBook.sol";

/// @dev Accounting harness only: it does not authenticate a sale or execute official revenue.
contract ClearingSaleBookHarness {
    using StreamClearingSaleBook for StreamClearingSaleBook.State;
    StreamClearingSaleBook.State private book;

    function configure(bytes32 id, uint96 start, uint96 floor, uint64 maximum) external {
        book.configure(id, start, floor, maximum);
    }

    function record(StreamClearingSaleBook.PurchaseInput calldata input) external {
        book.record(input);
    }

    function recordAndFail(StreamClearingSaleBook.PurchaseInput calldata input) external {
        book.record(input);
        revert("late mint failure");
    }

    function fixPrice(bytes32 id, uint256 price) external {
        book.fixPrice(id, price);
    }

    function supplement(bytes32 purchaseId, bool fail) external returns (uint256 amount) {
        amount = book.beginSupplement(purchaseId);
        if (fail) revert("official settlement failed");
        book.finishSupplement(purchaseId);
    }

    function unlock(bytes32 id) external {
        book.unlock(id);
    }

    function claim(bytes32 id, address buyer, uint256 amount, bool fail) external {
        book.debitClaim(id, buyer, amount);
        if (fail) revert("refund recipient failed");
    }

    function credit(bytes32 id, address buyer) external view returns (uint256) {
        return book.refundableBalance(id, buyer);
    }

    function sale(bytes32 id) external view returns (StreamClearingSaleBook.Sale memory) {
        return book.sales[id];
    }

    function purchase(bytes32 id) external view returns (StreamClearingSaleBook.Purchase memory) {
        return book.purchases[id];
    }

    function nextNonce(bytes32 id, address buyer) external view returns (uint256) {
        return book.buyers[id][buyer].lastPurchaseNonce + 1;
    }

    function liability() external view returns (uint256) {
        return book.totalBuyerLiability;
    }

    function active() external view returns (bytes32) {
        return book.activePurchase;
    }

    function announce(bytes32 id, address buyer) external returns (uint256) {
        return book.announceRebate(id, buyer);
    }
}

contract StreamClearingSaleBookTest is CharacterizationTestBase {
    ClearingSaleBookHarness private h;
    bytes32 private constant SALE = bytes32(uint256(1));
    bytes32 private constant OTHER = bytes32(uint256(2));
    address private constant BUYER = address(10);
    address private constant SECOND = address(20);

    function setUp() external {
        h = new ClearingSaleBookHarness();
        h.configure(SALE, 100, 20, 10);
        h.configure(OTHER, 100, 20, 10);
    }

    function _record(
        uint256 id,
        address buyer,
        uint256 nonce,
        uint256 schedule,
        bool overridden,
        uint256 cap,
        uint256 excess
    ) private returns (StreamClearingSaleBook.PurchaseInput memory p) {
        uint256 paid = overridden && cap < schedule ? cap : schedule;
        p = StreamClearingSaleBook.PurchaseInput(
            SALE, bytes32(id), buyer, nonce, schedule, paid, overridden, cap, excess
        );
        h.record(p);
    }

    function testOpenExcessThenImmediateRebatesPartialClaimSettlementAndUnlockConserve() external {
        _record(11, BUYER, 1, 100, false, 0, 7); // overage80, excess7
        _record(12, BUYER, 2, 90, true, 65, 3); // overage45, excess3
        _record(13, SECOND, 1, 80, true, 20, 5); // no overage, excess5
        require(h.liability() == 140 && h.credit(SALE, BUYER) == 10, "OPEN only excess");
        h.claim(SALE, BUYER, 4, false);
        require(h.liability() == 136 && h.credit(SALE, BUYER) == 6, "partial excess");
        h.fixPrice(SALE, 70);
        require(h.sale(SALE).scheduledSupplement == 95, "global exact sum50+45+0");
        // Buyer prices70,65; rebates30,0. Third buyer price20, no leg.
        require(h.credit(SALE, BUYER) == 36 && h.credit(SALE, SECOND) == 5, "immediate formula");
        h.claim(SALE, BUYER, 16, false); // remaining6 excess and10 rebate
        require(h.credit(SALE, BUYER) == 20 && h.liability() == 120, "partial rebate remains");
        require(h.supplement(bytes32(uint256(11)), false) == 50, "first supplement");
        require(h.liability() == 70 && h.credit(SALE, BUYER) == 20, "payment cannot reduce rebate");
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "official settlement failed"));
        h.supplement(bytes32(uint256(12)), true);
        require(h.liability() == 70 && h.active() == 0, "failed leg restored");
        require(!h.purchase(bytes32(uint256(12))).supplementalSettled, "still owed");
        h.unlock(SALE);
        // Total buyer overage125 - settled50 - already claimed rebate10 =65.
        require(
            h.credit(SALE, BUYER) == 65 && h.credit(SALE, SECOND) == 5,
            "only unsettled becomes refund"
        );
        h.claim(SALE, BUYER, 65, false);
        h.claim(SALE, SECOND, 5, false);
        require(h.liability() == 0, "140 custody =20 early claims+50 revenue+70 final claims");
        require(h.nextNonce(SALE, BUYER) == 3, "terminal does not rewind nonce");
    }

    function testRevertingClaimsAndSettlementsRestoreEveryCounterAndHealthyRetry() external {
        _record(11, BUYER, 1, 100, false, 0, 9);
        h.fixPrice(SALE, 60);
        bytes32 saleBefore = keccak256(abi.encode(h.sale(SALE)));
        bytes32 purchaseBefore = keccak256(abi.encode(h.purchase(bytes32(uint256(11)))));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "refund recipient failed"));
        h.claim(SALE, BUYER, 49, true);
        require(h.credit(SALE, BUYER) == 49 && h.liability() == 89, "claim restored");
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "official settlement failed"));
        h.supplement(bytes32(uint256(11)), true);
        require(keccak256(abi.encode(h.sale(SALE))) == saleBefore, "sale exact restored");
        require(
            keccak256(abi.encode(h.purchase(bytes32(uint256(11))))) == purchaseBefore,
            "purchase restored"
        );
        require(h.supplement(bytes32(uint256(11)), false) == 40, "exact retry");
        h.claim(SALE, BUYER, 49, false);
        require(h.liability() == 0 && h.sale(SALE).status == 3, "all terminal exact sum");
    }

    function testNumericNonceGapsFailuresAndIndependentBuyerSaleLanes() external {
        StreamClearingSaleBook.PurchaseInput memory p = StreamClearingSaleBook.PurchaseInput(
            SALE, bytes32(uint256(11)), BUYER, 2, 100, 100, false, 0, 0
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamClearingSaleBook.ClearingBookNonceInvalid.selector, 1, 2)
        );
        h.record(p);
        p.nonce = 1;
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "late mint failure"));
        h.recordAndFail(p);
        require(h.nextNonce(SALE, BUYER) == 1 && h.liability() == 0, "failed mint consumes nothing");
        h.record(p);
        p.purchaseId = bytes32(uint256(12));
        p.buyer = SECOND;
        h.record(p);
        p.purchaseId = bytes32(uint256(13));
        p.buyer = BUYER;
        p.saleId = OTHER;
        h.record(p);
        require(
            h.nextNonce(SALE, BUYER) == 2 && h.nextNonce(SALE, SECOND) == 2
                && h.nextNonce(OTHER, BUYER) == 2,
            "independent lanes"
        );
        h.unlock(SALE);
        h.claim(SALE, BUYER, 80, false);
        require(
            h.credit(SALE, SECOND) == 80 && h.credit(OTHER, BUYER) == 0, "sale and buyer isolation"
        );
    }

    function testGlobalQuantityBoundCannotBeBypassedWithManyBuyers() external {
        bytes32 limited = bytes32(uint256(3));
        h.configure(limited, 100, 20, 2);
        StreamClearingSaleBook.PurchaseInput memory p = StreamClearingSaleBook.PurchaseInput(
            limited, bytes32(uint256(11)), BUYER, 1, 100, 100, false, 0, 0
        );
        h.record(p);
        p.purchaseId = bytes32(uint256(12));
        p.buyer = SECOND;
        h.record(p);
        p.purchaseId = bytes32(uint256(13));
        p.buyer = address(30);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamClearingSaleBook.ClearingBookSaleUnavailable.selector, limited
            )
        );
        h.record(p);
        require(
            h.sale(limited).purchasedQuantity == 2 && h.nextNonce(limited, address(30)) == 1,
            "global bound"
        );
    }

    function testZeroSupplementsAndAllTerminalKeepClaimsAvailableWithoutReceipts() external {
        _record(11, BUYER, 1, 100, true, 20, 3);
        _record(12, SECOND, 1, 80, false, 0, 0);
        h.fixPrice(SALE, 20);
        require(h.sale(SALE).status == 3 && h.sale(SALE).positiveLegs == 0, "no processing loop");
        require(h.credit(SALE, BUYER) == 3 && h.credit(SALE, SECOND) == 60, "all floor rebates");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamClearingSaleBook.ClearingBookSaleUnavailable.selector, SALE
            )
        );
        h.supplement(bytes32(uint256(11)), false);
        h.claim(SALE, BUYER, 3, false);
        h.claim(SALE, SECOND, 60, false);
        require(
            h.liability() == 0 && h.sale(SALE).settledSupplement == 0, "no zero official receipt"
        );
    }

    function testTerminalUnlockCannotReopenOrRefundAlreadySettledRevenue() external {
        _record(11, BUYER, 1, 100, false, 0, 0);
        _record(12, BUYER, 2, 80, false, 0, 0);
        h.fixPrice(SALE, 60);
        h.supplement(bytes32(uint256(11)), false);
        h.unlock(SALE);
        require(h.credit(SALE, BUYER) == 100, "overage140 minus official40");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamClearingSaleBook.ClearingBookSaleUnavailable.selector, SALE
            )
        );
        h.supplement(bytes32(uint256(12)), false);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamClearingSaleBook.ClearingBookSaleUnavailable.selector, SALE
            )
        );
        h.fixPrice(SALE, 20);
        h.claim(SALE, BUYER, 100, false);
        vm.expectRevert(
            abi.encodeWithSelector(StreamClearingSaleBook.ClearingBookCreditExceeded.selector, 0, 1)
        );
        h.claim(SALE, BUYER, 1, false);
    }

    function testFullWidthSignedOverrideIsNormalizedOnlyForAggregate() external {
        _record(11, BUYER, 1, 100, true, type(uint256).max, 0);
        require(h.purchase(bytes32(uint256(11))).normalizedCeiling == 100, "cap index clamped");
        h.fixPrice(SALE, 70);
        require(
            h.credit(SALE, BUYER) == 30 && h.supplement(bytes32(uint256(11)), false) == 50,
            "exact min equivalence"
        );
    }

    function testRebateEventMaterializationNeverGatesClaimsAndIsIdempotentAfterUnlock() external {
        _record(11, BUYER, 1, 100, false, 0, 0);
        require(h.announce(SALE, BUYER) == 0, "OPEN no rebate");
        h.fixPrice(SALE, 60);
        require(h.credit(SALE, BUYER) == 40, "available before event");
        h.claim(SALE, BUYER, 40, false);
        require(h.announce(SALE, BUYER) == 40, "event identifies already claimed entitlement");
        require(h.announce(SALE, BUYER) == 0, "idempotent");
        h.unlock(SALE);
        require(h.credit(SALE, BUYER) == 40, "additional unsettled refund");
        require(h.announce(SALE, BUYER) == 0, "unlock does not relabel supplement as rebate");
    }

    function testFuzzAggregateClaimSettlementUnlockConservation(
        uint96 rawPrice,
        uint96 rawCap,
        uint96 rawClearing,
        uint96 rawExcess
    ) external {
        uint256 price = 20 + uint256(rawPrice) % 81;
        uint256 cap = 20 + uint256(rawCap) % 81;
        uint256 clearing = 20 + uint256(rawClearing) % (price - 19);
        uint256 paid = price < cap ? price : cap;
        uint256 uniform = clearing < cap ? clearing : cap;
        uint256 excess = rawExcess;
        _record(11, BUYER, 1, price, true, cap, excess);
        uint256 initial = paid - 20 + excess;
        h.fixPrice(SALE, clearing);
        uint256 first = paid - uniform + excess;
        require(h.credit(SALE, BUYER) == first, "independent min rebate");
        if (first != 0) h.claim(SALE, BUYER, first, false);
        uint256 supplement = uniform - 20;
        if (supplement != 0) {
            if ((rawPrice & 1) == 0) {
                require(h.supplement(bytes32(uint256(11)), false) == supplement, "settled");
            } else {
                h.unlock(SALE);
                require(h.credit(SALE, BUYER) == supplement, "unsettled refunds");
                h.claim(SALE, BUYER, supplement, false);
            }
        }
        require(h.liability() == 0 && initial == first + supplement, "conservation");
    }
}
